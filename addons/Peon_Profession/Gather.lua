-- Peon_Profession - Gather.lua
-- ab 0.5.0 (Wunsch von KarloDerBaer, 17.11.2026, Konzept docs/konzepte/profession/Peon_Profession_Codex.md):
-- Sammelstellen mitschreiben. Beim Bergbau und Kraeutersammeln merkt Profession Karte, Ort, Name des Vorkommens und
-- die Beute (accountweit in PeonProfessionDB.nodes). Daraus nennen Codex und Guide die Gebiete, in denen ein Erz oder
-- Kraut zu finden ist. Eine Anzeige auf Welt- und Minikarte gibt es mit Absicht noch nicht.
--
--   nodes[uiMapID] = { { x, y, p = Beruf, n = wie oft gesammelt, t = zuletzt (Unix-Zeit),
--                        names = { [Name des Vorkommens] = Anzahl }, items = { [itemID] = Menge } }, ... }
--   x und y als Anteil der Karte (0 bis 1, vier Stellen). Stellen naeher als MERGE_YARDS zaehlen als dieselbe.
--
-- Ablauf: UNIT_SPELLCAST_SENT (Zauber Bergbau oder Kraeutersammeln, Ziel = Name des Vorkommens), dann
-- UNIT_SPELLCAST_SUCCEEDED (Ort merken), dann LOOT_READY oder LOOT_OPENED (Beute lesen, Stelle speichern).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local A = {}
ns.Gather = A

A.MERGE_YARDS = 25     -- naeher als das: dieselbe Stelle
A.MERGE_FALLBACK = 0.004 -- ohne Kartengroesse: Abstand als Anteil der Karte
A.WINDOW = 8           -- Sekunden zwischen Zauber und Beute
A.MAX_PER_MAP = 1500   -- Obergrenze je Karte, die aeltesten fallen weg

-- Zauber der Sammelberufe (Raenge Lehrling bis Fachmann) -> Beruf
A.SPELLS = {
    [2575] = 186, [2576] = 186, [3564] = 186, [10248] = 186,     -- Bergbau
    [2366] = 182, [2368] = 182, [3570] = 182, [11993] = 182,     -- Kraeutersammeln
}

local function Num(v) return type(v) == "number" and v == v and not Peon.IsSecret(v) end
local function Str(v) return type(v) == "string" and not Peon.IsSecret(v) and v ~= "" and v or nil end
local function Now() return GetTime and GetTime() or 0 end
local function Epoch() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end

-- Beruf zu einem Zauber: ueber die Nummer, sonst ueber den Namen (Forever kann eigene Nummern haben)
A.spellNames = nil   -- Name des Zaubers -> Beruf, einmal gebaut
function A.ProfOfSpell(spellID)
    if not Num(spellID) then return nil end
    if A.SPELLS[spellID] then return A.SPELLS[spellID] end
    if not A.spellNames then
        A.spellNames = {}
        for id, key in pairs(A.SPELLS) do
            local n = ns.SpellName(id)
            if Str(n) then A.spellNames[n] = key end
        end
    end
    local n = ns.SpellName(spellID)
    return n and A.spellNames[n] or nil
end

-- Ort des Spielers: Karte, x, y (0 bis 1) oder nil (Instanz, geheime Werte)
function A.PlayerPos()
    local CM = rawget(_G, "C_Map")
    if not (CM and CM.GetBestMapForUnit and CM.GetPlayerMapPosition) then return nil end
    local ok, map = pcall(CM.GetBestMapForUnit, "player")
    if not ok or not Num(map) then return nil end
    local okp, pos = pcall(CM.GetPlayerMapPosition, map, "player")
    if not okp or type(pos) ~= "table" then return nil end
    local okx, x, y
    if pos.GetXY then okx, x, y = pcall(pos.GetXY, pos) else okx, x, y = true, pos.x, pos.y end
    if not okx or not Num(x) or not Num(y) or (x == 0 and y == 0) then return nil end
    return map, x, y
end

-- Groesse einer Karte in Metern (Breite, Hoehe), einmal je Karte, nil wenn das Spiel sie nicht nennt
A.sizes = {}
function A.MapSize(map)
    local s = A.sizes[map]
    if s ~= nil then return s and s[1], s and s[2] end
    A.sizes[map] = false
    local CM, V = rawget(_G, "C_Map"), rawget(_G, "CreateVector2D")
    if CM and CM.GetMapWorldSize then
        local ok, w, h = pcall(CM.GetMapWorldSize, map)
        if ok and Num(w) and Num(h) and w > 0 and h > 0 then A.sizes[map] = { w, h }; return w, h end
    end
    if CM and CM.GetWorldPosFromMapPos and V then
        local ok, w, h = pcall(function()
            local _, a = CM.GetWorldPosFromMapPos(map, V(0, 0))
            local _, b = CM.GetWorldPosFromMapPos(map, V(1, 1))
            local ax, ay = a:GetXY()
            local bx, by = b:GetXY()
            return math.abs(bx - ax), math.abs(by - ay)
        end)
        if ok and Num(w) and Num(h) and w > 0 and h > 0 then A.sizes[map] = { w, h }; return w, h end
    end
    return nil
end

-- Liegen zwei Orte auf derselben Karte so nah, dass sie dieselbe Stelle sind?
function A.Same(map, x1, y1, x2, y2)
    local w, h = A.MapSize(map)
    local dx, dy = x1 - x2, y1 - y2
    if w then
        dx, dy = dx * w, dy * h
        return dx * dx + dy * dy <= A.MERGE_YARDS * A.MERGE_YARDS
    end
    return dx * dx + dy * dy <= A.MERGE_FALLBACK * A.MERGE_FALLBACK
end

local function Round(v) return math.floor(v * 10000 + 0.5) / 10000 end

local function DB()
    local n = mod.db.nodes
    if type(n) ~= "table" then n = {}; mod.db.nodes = n end
    return n
end

-- Stelle speichern. items = { [itemID] = Menge }. Rueckgabe: Eintrag, neu (true) oder gefunden (false)
function A.Record(map, x, y, prof, name, items)
    if not (Num(map) and Num(x) and Num(y)) then return nil end
    local nodes = DB()
    local list = nodes[map]
    if type(list) ~= "table" then list = {}; nodes[map] = list end
    local hit
    for _, e in ipairs(list) do
        if type(e) == "table" and Num(e.x) and Num(e.y) and A.Same(map, x, y, e.x, e.y) then hit = e; break end
    end
    local fresh = hit == nil
    if fresh then
        hit = { x = Round(x), y = Round(y), p = prof, n = 0, names = {}, items = {} }
        list[#list + 1] = hit
    end
    hit.n = (hit.n or 0) + 1
    hit.t = Epoch()
    hit.p = hit.p or prof
    if Str(name) then
        hit.names = type(hit.names) == "table" and hit.names or {}
        hit.names[name] = (hit.names[name] or 0) + 1
    end
    hit.items = type(hit.items) == "table" and hit.items or {}
    for id, q in pairs(items or {}) do
        if Num(id) and Num(q) then hit.items[id] = (hit.items[id] or 0) + q end
    end
    -- Obergrenze: die am laengsten nicht besuchten Stellen fallen weg
    if #list > A.MAX_PER_MAP then
        table.sort(list, function(a, b) return (a.t or 0) > (b.t or 0) end)
        for i = #list, A.MAX_PER_MAP + 1, -1 do list[i] = nil end
    end
    if ns.Window and ns.Window.IsOpen() and ns.Window.Later then ns.Window.Later() end
    return hit, fresh
end

-- Beute des offenen Beutefensters: { [itemID] = Menge }
function A.ReadLoot()
    local items = {}
    local GN, GL, GI = rawget(_G, "GetNumLootItems"), rawget(_G, "GetLootSlotLink"), rawget(_G, "GetLootSlotInfo")
    if type(GN) ~= "function" or type(GL) ~= "function" then return items end
    local ok, n = pcall(GN)
    if not ok or not Num(n) then return items end
    for slot = 1, n do
        local okl, link = pcall(GL, slot)
        local id = Str(link) and tonumber(link:match("item:(%d+)"))
        if id then
            local q = 1
            if type(GI) == "function" then
                local oki, _, _, qty = pcall(GI, slot)
                if oki and Num(qty) and qty > 0 then q = qty end
            end
            items[id] = (items[id] or 0) + q
        end
    end
    return items
end

-- Ereignisse
function A.OnSent(unit, target, castGUID, spellID)
    if unit ~= "player" then return end
    local prof = A.ProfOfSpell(spellID)
    if not prof then return end
    A.pending = { prof = prof, name = Str(target), guid = castGUID, t = Now() }
end

function A.OnSucceeded(unit, castGUID, spellID)
    local p = A.pending
    if unit ~= "player" or not p then return end
    if p.guid ~= nil and castGUID ~= nil and p.guid ~= castGUID then return end
    local map, x, y = A.PlayerPos()
    if map then p.map, p.x, p.y = map, x, y end
    p.t = Now()
    p.done = true
end

function A.OnLoot()
    local p = A.pending
    if not p or Now() - (p.t or 0) > A.WINDOW then A.pending = nil; return end
    if not p.map then
        local map, x, y = A.PlayerPos()
        if not map then A.pending = nil; return end
        p.map, p.x, p.y = map, x, y
    end
    A.pending = nil
    local items = A.ReadLoot()
    if not next(items) then return end
    local e, fresh = A.Record(p.map, p.x, p.y, p.prof, p.name, items)
    if e then mod:Dbg(("Sammelstelle %s: Karte %d (%.3f, %.3f), %s"):format(fresh and "neu" or "bekannt", p.map, p.x, p.y, p.name or "?")) end
end

function A.Init()
    pcall(mod.RegisterEvent, mod, "UNIT_SPELLCAST_SENT", function(_, unit, target, guid, spellID) A.OnSent(unit, target, guid, spellID) end)
    pcall(mod.RegisterEvent, mod, "UNIT_SPELLCAST_SUCCEEDED", function(_, unit, guid, spellID) A.OnSucceeded(unit, guid, spellID) end)
    pcall(mod.RegisterEvent, mod, "LOOT_READY", function() A.OnLoot() end)
    pcall(mod.RegisterEvent, mod, "LOOT_OPENED", function() A.OnLoot() end)
end

---------------------------------------------------------------------------
-- Abfragen fuer Codex und Guide
---------------------------------------------------------------------------

function A.ZoneName(map)
    local CM = rawget(_G, "C_Map")
    if CM and CM.GetMapInfo then
        local ok, info = pcall(CM.GetMapInfo, map)
        if ok and type(info) == "table" and Str(info.name) then return info.name end
    end
    return "#" .. tostring(map)
end

-- Gebiete eines Gegenstands aus den eigenen Stellen: { { map, name, spots, n }, ... }, die meisten Stellen zuerst
function A.Zones(itemID)
    local out = {}
    for map, list in pairs(DB()) do
        if type(list) == "table" then
            local spots, n = 0, 0
            for _, e in ipairs(list) do
                if type(e) == "table" and type(e.items) == "table" and e.items[itemID] then
                    spots = spots + 1
                    n = n + (e.n or 1)
                end
            end
            if spots > 0 then out[#out + 1] = { map = map, name = A.ZoneName(map), spots = spots, n = n } end
        end
    end
    table.sort(out, function(a, b)
        if a.spots ~= b.spots then return a.spots > b.spots end
        return a.name < b.name
    end)
    return out
end

-- Alle Gegenstaende aus eigenen Stellen: { [itemID] = Beruf }
function A.Items()
    local out = {}
    for _, list in pairs(DB()) do
        if type(list) == "table" then
            for _, e in ipairs(list) do
                if type(e) == "table" and type(e.items) == "table" then
                    for id in pairs(e.items) do if out[id] == nil then out[id] = e.p or false end end
                end
            end
        end
    end
    return out
end

-- Zahl der Stellen und Karten
function A.Count()
    local spots, maps = 0, 0
    for _, list in pairs(DB()) do
        if type(list) == "table" and #list > 0 then maps = maps + 1; spots = spots + #list end
    end
    return spots, maps
end

-- Kurzer Text fuer den Guide: "Eigene Fundorte: Durotar (5), Brachland (2)" oder nil
function A.ZonesText(items, max)
    local byMap, order = {}, {}
    for _, id in ipairs(items or {}) do
        for _, z in ipairs(A.Zones(id)) do
            local r = byMap[z.map]
            if not r then r = { name = z.name, spots = 0 }; byMap[z.map] = r; order[#order + 1] = r end
            r.spots = math.max(r.spots, z.spots)
        end
    end
    if #order == 0 then return nil end
    table.sort(order, function(a, b) if a.spots ~= b.spots then return a.spots > b.spots end return a.name < b.name end)
    local t = {}
    for i = 1, math.min(#order, max or 4) do t[#t + 1] = ("%s (%d)"):format(order[i].name, order[i].spots) end
    return L.OWN_ZONES:format(table.concat(t, ", "))
end

-- /prof stellen
function A.Report()
    local spots, maps = A.Count()
    mod:Print(L.NODES_REPORT:format(spots, maps))
    return spots, maps
end
