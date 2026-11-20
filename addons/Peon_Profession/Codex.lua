-- Peon_Profession - Codex.lua
-- ab 0.5.0 (Wunsch von KarloDerBaer, 17.11.2026, Konzept docs/konzepte/profession/Peon_Profession_Codex.md):
-- Reiter "Codex" mit zwei Seiten:
--   Rezepte  je Beruf (links gewaehlt), mit Text im Suchfeld ueber alle Berufe. Quelle: Route des Guides, Lehrer und
--            Haendler, die man selbst besucht hat, erlernte Rezepte aller Charaktere.
--   Farming  alle Erze, Kraeuter und Fische mit ihren Gebieten: eigene Sammelstellen (Gather.lua), Gebiete des Guides
--            und Faenge aus Peon_Fishing (mod:CatchZones, ab Fishing 1.7.0).
-- Daten nur aus dem, was Peon schon hat, und aus eigener Sammlung im Spiel (accountweit, nur lokal):
--   recipes[Beruf][recipeID] = { out, n, m, name, by = { [Charakter] = true } }   erlernte Rezepte aller Charaktere
--   teach[Beruf][name]       = { name, skill, cost, item, npcs = { [npcID] = true } }   beim Lehrer gesehen
--   sold[Beruf][itemID]      = { name, price, npcs = { [npcID] = true } }               Rezepte beim Haendler gesehen
--   npcs[npcID]              = { name, map, x, y, f, kind }   Ort von Lehrer (t) und Haendler (v), x und y in Prozent

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local C = {}
ns.Codex = C

local GOLD, GREY, GREEN = "|cffffd100", "|cff999999", "|cff8ccf4d"
local function Num(v) return type(v) == "number" and v == v and not Peon.IsSecret(v) end
local function Str(v) return type(v) == "string" and not Peon.IsSecret(v) and v ~= "" and v or nil end
local function G() return ns.Guide end
local function P() return ns.Prices end

-- Unterklassen der Gegenstandsklasse Rezept (9) -> Beruf
C.RECIPE_CLASS = 9
C.SUBCLASS = { [1] = 165, [2] = 197, [3] = 202, [4] = 164, [5] = 185, [6] = 171, [7] = 129, [8] = 333, [9] = 356 }
-- Gruppen der Seite Farming
C.GROUPS = { { "all", 0 }, { "mining", 186 }, { "herbs", 182 }, { "fish", 356 } }

local function Tbl(t, k)
    local v = t[k]
    if type(v) ~= "table" then v = {}; t[k] = v end
    return v
end
local function DB(name) return Tbl(mod.db, name) end

-- Name ohne Vorsatz wie "Rezept: " und klein, zum Vergleichen
function C.Norm(name)
    if not Str(name) then return nil end
    local s = name:gsub("^[^:]+:%s*", "")
    return s:lower()
end

function C.Me()
    local name = rawget(_G, "UnitName") and UnitName("player")
    local realm = (Peon.RealmName and Peon.RealmName()) or (rawget(_G, "GetRealmName") and GetRealmName())   -- ab 0.7.4 mit Rueckfall
    if not Str(name) then return nil end
    return Str(realm) and (name .. "-" .. realm) or name
end

---------------------------------------------------------------------------
-- Sammeln
---------------------------------------------------------------------------

-- Erlernte Rezepte des offenen Berufs (aus Measure.ReadAll) fuer alle Charaktere merken
function C.Learned(key, list)
    local me = C.Me()
    if not (key and me and type(list) == "table") then return end
    local all = Tbl(DB("recipes"), key)
    for id, rec in pairs(list) do
        local e = Tbl(all, id)
        e.out, e.n, e.m, e.name = rec.out, rec.n, rec.m, rec.name or e.name
        Tbl(e, "by")[me] = true
    end
    for id, e in pairs(all) do   -- nicht mehr erlernt (oder frueher falsch gemerkt)
        if type(e) == "table" and type(e.by) == "table" and e.by[me] and not list[id] then
            e.by[me] = nil
            if not next(e.by) then all[id] = nil end
        end
    end
end

-- /prof vergessen: diesen Charakter aus der gemeinsamen Liste nehmen
function C.ForgetMe()
    local me = C.Me()
    if not me then return end
    for _, all in pairs(DB("recipes")) do
        if type(all) == "table" then
            for id, e in pairs(all) do
                if type(e) == "table" and type(e.by) == "table" and e.by[me] then
                    e.by[me] = nil
                    if not next(e.by) then all[id] = nil end
                end
            end
        end
    end
end

-- NPC unter der Maus oder im Gespraech: Nummer aus der GUID, Name, Ort des Spielers
function C.NpcHere(kind)
    local guid = rawget(_G, "UnitGUID") and UnitGUID("npc")
    if not Str(guid) then return nil end
    -- "Creature-0-Server-Instanz-Zone-NPC-Spawn": die sechste Stelle ist die Nummer des NPC
    local kindOf, idText = guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)")
    local id = tonumber(idText or "")
    if not id or (kindOf ~= "Creature" and kindOf ~= "Vehicle") then return nil end
    local npcs = DB("npcs")
    local e = Tbl(npcs, id)
    local name = UnitName and UnitName("npc")
    if Str(name) then e.name = name end
    local map, x, y = ns.Gather.PlayerPos()
    if map then e.map, e.x, e.y = map, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10 end
    local f = rawget(_G, "UnitFactionGroup") and UnitFactionGroup("npc")
    if Str(f) then e.f = f end
    e.kind = kind
    return id
end

-- Lehrerfenster: angebotene Rezepte mit Stufe und Preis
function C.ReadTrainer()
    local GN, GI, GR, GC, GL = rawget(_G, "GetNumTrainerServices"), rawget(_G, "GetTrainerServiceInfo"),
        rawget(_G, "GetTrainerServiceSkillReq"), rawget(_G, "GetTrainerServiceCost"), rawget(_G, "GetTrainerServiceItemLink")
    if type(GN) ~= "function" or type(GI) ~= "function" then return 0 end
    local ok, n = pcall(GN)
    if not ok or not Num(n) or n == 0 then return 0 end
    local npc = C.NpcHere("t")
    local teach, count = DB("teach"), 0
    for i = 1, n do
        local oki, name, _, cat = pcall(GI, i)
        if oki and Str(name) and cat ~= "header" then
            local key, skill
            if type(GR) == "function" then
                local okr, sname, slevel = pcall(GR, i)
                if okr then key = ns.KeyForName(Str(sname)); skill = Num(slevel) and slevel or nil end
            end
            if key and ns.PROFS[key] then
                local e = Tbl(Tbl(teach, key), name:lower())
                e.name, e.skill = name, skill or e.skill
                if type(GC) == "function" then
                    local okc, cost = pcall(GC, i)
                    if okc and Num(cost) then e.cost = cost end
                end
                if type(GL) == "function" then
                    local okl, link = pcall(GL, i)
                    local item = Str(link) and tonumber(link:match("item:(%d+)"))
                    if item then e.item = item end
                end
                if npc then Tbl(e, "npcs")[npc] = true end
                count = count + 1
            end
        end
    end
    mod:Dbg(("Codex: %d Rezepte beim Lehrer gelesen"):format(count))
    return count
end

-- Haendlerfenster: Rezepte zum Kauf mit Preis
local function MerchantItem(i)
    local id, price, name
    local GID, GLK = rawget(_G, "GetMerchantItemID"), rawget(_G, "GetMerchantItemLink")
    if type(GID) == "function" then local ok, v = pcall(GID, i); if ok and Num(v) then id = v end end
    if not id and type(GLK) == "function" then
        local ok, link = pcall(GLK, i)
        id = ok and Str(link) and tonumber(link:match("item:(%d+)")) or nil
    end
    local MF = rawget(_G, "C_MerchantFrame")
    if MF and MF.GetItemInfo then
        local ok, info = pcall(MF.GetItemInfo, i)
        if ok and type(info) == "table" then name, price = info.name, info.price end
    end
    if price == nil and type(rawget(_G, "GetMerchantItemInfo")) == "function" then
        local ok, n, _, p = pcall(GetMerchantItemInfo, i)
        if ok then name, price = n, p end
    end
    return id, Num(price) and price or nil, Str(name)
end

function C.ReadVendor()
    local GN = rawget(_G, "GetMerchantNumItems")
    local CI = rawget(_G, "C_Item")
    if type(GN) ~= "function" or not (CI and CI.GetItemInfoInstant) then return 0 end
    local ok, n = pcall(GN)
    if not ok or not Num(n) or n == 0 then return 0 end
    local npc
    local sold, count = DB("sold"), 0
    for i = 1, n do
        local id, price, name = MerchantItem(i)
        if id then
            local oki, _, _, _, _, _, class, sub = pcall(CI.GetItemInfoInstant, id)
            local key = oki and class == C.RECIPE_CLASS and C.SUBCLASS[sub]
            if key then
                npc = npc or C.NpcHere("v") or false
                local e = Tbl(Tbl(sold, key), id)
                e.name = name or ns.ItemName(id) or e.name
                e.price = price or e.price
                if npc then Tbl(e, "npcs")[npc] = true end
                count = count + 1
            end
        end
    end
    if count > 0 then mod:Dbg(("Codex: %d Rezepte beim Haendler gesehen"):format(count)) end
    return count
end

function C.Init()
    pcall(mod.RegisterEvent, mod, "TRAINER_SHOW", function() mod:Call("Lehrer lesen", C.ReadTrainer) end)
    pcall(mod.RegisterEvent, mod, "TRAINER_UPDATE", function() mod:Call("Lehrer lesen", C.ReadTrainer) end)
    pcall(mod.RegisterEvent, mod, "MERCHANT_SHOW", function() mod:Call("Haendler lesen", C.ReadVendor) end)
end

---------------------------------------------------------------------------
-- Rezepte zusammenstellen
---------------------------------------------------------------------------

-- Zeilen fuer einen Beruf: { name, norm, icon, quality, skill, item, spell, mats, route, learnSrc, teach, sold, by, mine }
function C.Recipes(key)
    local rows, byNorm = {}, {}
    local function Row(name, item, spell)
        local norm = C.Norm(name) or ("#" .. tostring(item or spell))
        local r = byNorm[norm]
        if not r then
            r = { key = key, name = name, norm = norm, by = {} }
            byNorm[norm] = r
            rows[#rows + 1] = r
        end
        r.item = r.item or item
        r.spell = r.spell or spell
        return r
    end
    local function Skill(r, v) if Num(v) and (r.skill == nil or v < r.skill) then r.skill = v end end
    -- Route des Guides und Verhuetten
    local steps = {}
    for _, s in ipairs(G().Route(key) or {}) do steps[#steps + 1] = s end
    for _, s in ipairs(ns.Smelt and ns.Smelt[key] or {}) do steps[#steps + 1] = s end
    for _, s in ipairs(steps) do
        if not s.gather and (s.item or s.spell) then
            local r = Row(G().RecipeName(s.item, s.spell), s.item, s.spell)
            r.route = true
            r.routeFrom = math.min(r.routeFrom or s.from, s.from)
            r.mats = r.mats or s.mats
            local learn = s.spell and ns.Learn and ns.Learn[s.spell]
            if learn then Skill(r, learn.skill); r.learnSrc = learn.src end
        end
    end
    -- erlernte Rezepte aller Charaktere (dieser Charakter auch aus known)
    local me = C.Me()
    local all = DB("recipes")[key]
    for id, e in pairs(type(all) == "table" and all or {}) do
        if type(e) == "table" then
            local r = Row(e.name or G().RecipeName(e.out, id), e.out, id)
            r.mats = e.m or r.mats
            for who in pairs(type(e.by) == "table" and e.by or {}) do r.by[who] = true end
        end
    end
    for id, rec in pairs(G().Known(key)) do
        local r = Row(rec.name or G().RecipeName(rec.out, id), rec.out, id)
        r.mats = rec.m or r.mats
        r.mine = true
        if me then r.by[me] = true end
    end
    -- ab 0.6.0: Rezepte von Freunden und Gilde (Friends.lua), Zeile ueber die Rezeptnummer finden
    local fr = ns.Friends and ns.Friends.ByRecipe(key) or {}
    if next(fr) then
        local bySpell = {}
        for _, r in ipairs(rows) do if r.spell then bySpell[r.spell] = r end end
        for id, names in pairs(fr) do
            local r = bySpell[id]
            if not r then
                local e = type(all) == "table" and all[id]
                local out = type(e) == "table" and e.out or nil
                r = Row((type(e) == "table" and e.name) or G().RecipeName(out, id), out, id)
                bySpell[id] = r
            end
            r.friends = r.friends or {}
            for _, n in ipairs(names) do r.friends[#r.friends + 1] = n end
        end
    end
    -- Lehrer
    local teach = DB("teach")[key]
    for _, e in pairs(type(teach) == "table" and teach or {}) do
        if type(e) == "table" and Str(e.name) then
            local r = Row(e.name, e.item)
            r.teach = e
            Skill(r, e.skill)
        end
    end
    -- Haendler
    local sold = DB("sold")[key]
    for id, e in pairs(type(sold) == "table" and sold or {}) do
        if type(e) == "table" then
            local r = Row(e.name or ns.ItemName(id) or ("#" .. id))
            r.sold, r.soldItem = e, id
        end
    end
    for _, r in ipairs(rows) do
        if me and r.by[me] then r.mine = true end
        local q
        if r.item then _, q = ns.ItemName(r.item) end
        r.quality = q
        r.icon = G().RecipeIcon(r.item, r.spell)
        if r.skill == nil and r.routeFrom then r.skill = r.routeFrom end
        if r.name and r.name:find("^#") and r.item then r.name = ns.ItemName(r.item) or r.name end
    end
    return rows
end

-- Quelle als kurzer Text
function C.SourceText(r)
    local t = {}
    if r.teach then t[#t + 1] = L.CX_SRC_TRAINER end
    if r.sold then t[#t + 1] = L.CX_SRC_VENDOR end
    if not r.teach and not r.sold then
        if r.learnSrc then t[#t + 1] = L.CX_SRC[r.learnSrc] or L.CX_SRC_ROUTE
        elseif r.route then t[#t + 1] = L.CX_SRC_ROUTE end
    end
    if #t == 0 then return GREY .. L.CX_SRC_NONE .. "|r" end
    return table.concat(t, ", ")
end

local BLUE = "|cff66bbff"
function C.KnownText(r)
    local t = {}
    if r.mine then t[#t + 1] = GREEN .. L.CX_ME .. "|r" end
    local n = 0
    for _ in pairs(r.by) do n = n + 1 end
    if r.mine then n = n - 1 end
    if n > 0 then t[#t + 1] = L.CX_ALTS:format(n) end
    local f = r.friends and #r.friends or 0   -- ab 0.6.0
    if f > 0 then t[#t + 1] = BLUE .. (f == 1 and L.CX_FRIEND or L.CX_FRIENDS:format(f)) .. "|r" end
    if #t == 0 then return GREY .. "–|r" end
    return table.concat(t, ", ")
end

-- Orte der NPCs einer Quelle (eigene Fraktion zuerst): { { name, map, x, y, kind, price } }
function C.Places(r)
    local npcs, out = DB("npcs"), {}
    local faction = rawget(_G, "UnitFactionGroup") and UnitFactionGroup("player")
    local function Add(src, kind, price)
        for id in pairs(type(src) == "table" and src.npcs or {}) do
            local n = npcs[id]
            if type(n) == "table" and Num(n.map) then
                out[#out + 1] = { name = n.name or ("#" .. id), map = n.map, x = n.x, y = n.y, kind = kind, price = price,
                    own = (n.f == nil or n.f == faction or n.f == "Neutral") }
            end
        end
    end
    Add(r.teach, "t", r.teach and r.teach.cost)
    Add(r.sold, "v", r.sold and r.sold.price)
    table.sort(out, function(a, b)
        if a.own ~= b.own then return a.own end
        return a.name < b.name
    end)
    return out
end

-- Rezepte, deren Name den Text enthaelt. Ohne only alle Berufe, sonst nur dieser (ab 0.5.0).
function C.Search(text, only)
    local q = Str(text) and text:lower()
    local out = {}
    for _, key in ipairs(only and { only } or ns.ORDER) do
        for _, r in ipairs(C.Recipes(key)) do
            if not q or (r.name or ""):lower():find(q, 1, true) then out[#out + 1] = r end
        end
    end
    return out
end

-- ab 0.5.0: gibt es fuer den Beruf Rezepte im Codex?
function C.HasRecipes(key)
    return ns.PROFS[key] ~= nil and #C.Recipes(key) > 0
end

-- ab 0.5.0: Auswahl fuer das Dropdown der Rezepte, nur Berufe mit Rezepten
function C.ProfChoices()
    local out = { { "all", L.CX_ALL_PROFS } }
    for _, key in ipairs(ns.ORDER) do
        if C.HasRecipes(key) then out[#out + 1] = { key, ns.ProfName(key) } end
    end
    return out
end

-- ab 0.5.0: Gruppe der Seite Farming zu einem Beruf, nil wenn es keine gibt
function C.GroupOf(key)
    for _, g in ipairs(C.GROUPS) do if g[2] ~= 0 and g[2] == key then return g[1] end end
    return nil
end

---------------------------------------------------------------------------
-- Farming zusammenstellen
---------------------------------------------------------------------------

local function Fishing()
    local fm = Peon.GetModule and Peon:GetModule("fishing")
    if fm and type(fm.CatchZones) == "function" then
        local ok, zones, info = pcall(fm.CatchZones, fm)
        if ok and type(zones) == "table" then return zones, info or {} end
    end
    return nil
end
C.Fishing = Fishing

-- Gebiete des Guides fuer einen Gegenstand (eigene Fraktion): { [uiMapID] = Stufe ab }
function C.GuideZones(id)
    local out = {}
    local horde = rawget(_G, "UnitFactionGroup") and UnitFactionGroup("player") == "Horde"
    for _, key in ipairs({ 186, 182, 393 }) do
        for _, s in ipairs(G().Route(key) or {}) do
            local hit = false
            for _, g in ipairs(s.gather or {}) do if g == id then hit = true end end
            if hit then
                for _, map in ipairs((horde and s.H or s.A) or {}) do
                    if out[map] == nil or s.from < out[map] then out[map] = s.from end
                end
            end
        end
    end
    return out
end

-- Zeilen der Seite Farming: { id, name, icon, quality, group, skill, zones, spots, n, price }
function C.Farm(group, text)
    local items = {}
    local function Add(id, key, skill)
        local e = items[id]
        if not e then e = { id = id, key = key }; items[id] = e end
        e.key = e.key or key
        if Num(skill) and (e.skill == nil or skill < e.skill) then e.skill = skill end
        return e
    end
    for _, key in ipairs({ 186, 182 }) do
        for _, s in ipairs(G().Route(key) or {}) do
            for _, id in ipairs(s.gather or {}) do Add(id, key, s.from) end
        end
    end
    for id, key in pairs(ns.Gather.Items()) do Add(id, key or nil) end
    local fish, info = Fishing()
    for id in pairs(fish or {}) do
        local i = info and info[id]
        if not (type(i) == "table" and i.q == 0) then
            local e = Add(id, items[id] and items[id].key or 356)
            e.fish = fish[id]
            e.fishInfo = i
        end
    end
    local q = Str(text) and text:lower()
    local want = 0
    for _, g in ipairs(C.GROUPS) do if g[1] == group then want = g[2] end end
    local rows = {}
    for id, e in pairs(items) do
        local name, quality = ns.ItemName(id)
        if not name and type(e.fishInfo) == "table" then name, quality = e.fishInfo.name, e.fishInfo.q end
        e.name, e.quality = name or ("#" .. id), quality
        if (want == 0 or e.key == want) and (not q or e.name:lower():find(q, 1, true)) then
            e.icon = ns.ItemIcon(id)
            if type(e.fishInfo) == "table" and e.fishInfo.icon and not ns.ItemName(id) then e.icon = e.fishInfo.icon end
            e.group = e.key and ns.ProfName(e.key) or ""
            local own = ns.Gather.Zones(id)
            local maps = {}
            local spots, n = 0, 0
            for _, z in ipairs(own) do maps[z.name] = true; spots = spots + z.spots; n = n + z.n end
            for _, f in ipairs(e.fish or {}) do maps[f.zone] = true; n = n + f.count end
            for map in pairs(C.GuideZones(id)) do maps[ns.Gather.ZoneName(map)] = true end
            local zones = 0
            for _ in pairs(maps) do zones = zones + 1 end
            e.zones, e.spots, e.n = zones, spots, n
            e.price = P().Unit(id)
            rows[#rows + 1] = e
        end
    end
    return rows
end

-- Gebiete eines Gegenstands fuer die untere Tabelle: { name, spots, n, pct, src, order }
function C.ZonesOf(e)
    local rows, byName = {}, {}
    local function Row(name)
        local r = byName[name]
        if not r then r = { name = name, src = {} }; byName[name] = r; rows[#rows + 1] = r end
        return r
    end
    for _, z in ipairs(ns.Gather.Zones(e.id)) do
        local r = Row(z.name)
        r.spots, r.n = z.spots, z.n
        r.src[#r.src + 1] = L.CX_FROM_OWN
    end
    for _, f in ipairs(e.fish or {}) do
        local r = Row(f.zone)
        r.n = (r.n or 0) + f.count
        r.pct = f.count / math.max(1, f.total)
        r.sub = f.sub
        r.src[#r.src + 1] = L.CX_FROM_FISH
    end
    for map, from in pairs(C.GuideZones(e.id)) do
        local r = Row(ns.Gather.ZoneName(map))
        r.guide = from
        r.src[#r.src + 1] = L.CX_FROM_GUIDE:format(from)
    end
    for _, r in ipairs(rows) do
        r.srcText = table.concat(r.src, ", ")
        r.order = -((r.spots or 0) * 1000 + (r.pct and r.pct * 100 or 0) + (r.n or 0) / 1000)
    end
    return rows
end

---------------------------------------------------------------------------
-- Reiter im Fenster
---------------------------------------------------------------------------
local W = ns.Window

local function MoneyOrDash(v) if type(v) ~= "number" then return GREY .. "–|r" end return ns.Money(v) end

function W.BuildCodex(c)
    local U = Peon.UI
    local bar = U.Panel(c, "right")
    bar:SetPoint("TOPLEFT", c, "TOPLEFT", W.x0, -U.TOP)
    bar:SetPoint("TOPRIGHT", c, "TOPRIGHT", -U.EDGE - 1, -U.TOP)
    bar:SetHeight(34)
    W.cxRecBtn = U.Button(bar, L.CX_RECIPES, 90, function() mod.db.codexMode = "recipes"; W.cxPick = nil; mod:Call("Codex", W.Refresh) end)
    W.cxRecBtn:SetPoint("LEFT", 8, 0)
    W.cxFarmBtn = U.Button(bar, L.CX_FARMING, 90, function() mod.db.codexMode = "farm"; mod:Call("Codex", W.Refresh) end)
    W.cxFarmBtn:SetPoint("LEFT", W.cxRecBtn, "RIGHT", 4, 0)
    W.cxSearch = U.SearchBox(bar, 200, function(text) W.cxText = text; W.cxPick = nil; W.Later() end)
    W.cxSearch:SetPoint("LEFT", W.cxFarmBtn, "RIGHT", 16, 0)
    local groups = {}
    for _, g in ipairs(C.GROUPS) do groups[#groups + 1] = { g[1], L.CX_GROUP[g[1]] } end
    W.cxGroup = U.Dropdown(bar, 130, groups, function() return mod.db.codexGroup end,
        function(v) mod.db.codexGroup = v; W.cxPick = nil; mod:Call("Codex", W.Refresh) end)
    W.cxGroup:SetPoint("RIGHT", -8, 0)
    -- ab 0.5.0: Rezepte mit eigener Auswahl des Berufs, "Alle Berufe" zuerst
    W.cxProf = U.Dropdown(bar, 160, C.ProfChoices, function() return W.cxProfKey or "all" end,
        function(v) W.cxProfKey = v; mod:Call("Codex", W.Refresh) end)
    W.cxProf:SetPoint("RIGHT", -8, 0)
    W.cxHint = U.Text(bar, "small", "")
    W.cxHint:SetPoint("RIGHT", -10, 0)
    W.cxBar = bar

    -- Rezepte: eine Liste ueber die ganze Hoehe
    local rp = U.Panel(c, "list", true)
    rp:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -U.GAP)
    rp:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -U.GAP)
    rp:SetPoint("BOTTOM", c, "BOTTOM", 0, U.BOTTOM)
    W.cxRecipes = U.Table(rp, { icon = true, sortKey = "skill", empty = L.CX_NO_RECIPES,
        columns = {
            { key = "name", title = L.COL_RECIPE },
            { key = "prof", title = L.CX_COL_PROF, width = 110 },
            { key = "skill", title = L.CX_COL_SKILL, width = 50, align = "RIGHT",
              format = function(v) return v and tostring(v) or (GREY .. "?|r") end },
            { key = "src", title = L.CX_COL_SRC, width = 120 },
            { key = "known", title = L.CX_COL_KNOWN, width = 80 },
        },
        onEnter = function(row, item) W.CodexRecipeTip(row, item) end,
        onClick = function(item, button)
            if button ~= "LeftButton" or not item then return end
            local p = C.Places(item.r)[1]
            if p then ns.Books.Waypoint(p) else mod:Print(L.CX_NO_PLACE) end
        end })
    W.cxRecPanel = rp

    -- Farming: oben die Gegenstaende, unten die Gebiete des gewaehlten
    local fp = U.Panel(c, "list", true)
    fp:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -U.GAP)
    fp:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -U.GAP)
    fp:SetHeight(200)
    W.cxFarm = U.Table(fp, { icon = true, sortKey = "skill", empty = L.CX_NO_FARM,
        columns = {
            { key = "name", title = L.CX_COL_ITEM },
            { key = "group", title = L.CX_COL_GROUP, width = 110 },
            { key = "skill", title = L.CX_COL_SKILL, width = 50, align = "RIGHT",
              format = function(v) return v and tostring(v) or "" end },
            { key = "zones", title = L.CX_COL_ZONES, width = 60, align = "RIGHT" },
            { key = "spots", title = L.CX_COL_SPOTS, width = 60, align = "RIGHT",
              format = function(v) return (v and v > 0) and tostring(v) or (GREY .. "–|r") end },
            { key = "price", title = L.CX_COL_PRICE, width = 100, align = "RIGHT", format = function(v) return MoneyOrDash(v) end },
        },
        onEnter = function(row, item) W.ItemTip(row, item) end,
        onClick = function(item, button)
            if button == "LeftButton" and item then W.cxPick = item.id; W.FillCodexZones() end
        end })
    W.cxFarmPanel = fp
    local zp = U.Panel(c, "list", true)
    zp:SetPoint("TOPLEFT", fp, "BOTTOMLEFT", 0, -U.GAP)
    zp:SetPoint("TOPRIGHT", fp, "BOTTOMRIGHT", 0, -U.GAP)
    zp:SetPoint("BOTTOM", c, "BOTTOM", 0, U.BOTTOM)
    W.cxZones = U.Table(zp, { sortKey = "order", empty = L.CX_PICK_ITEM,
        columns = {
            { key = "name", title = L.CX_COL_ZONE },
            { key = "spots", title = L.CX_COL_SPOTS, width = 60, align = "RIGHT",
              format = function(v) return v and tostring(v) or (GREY .. "–|r") end },
            { key = "n", title = L.CX_COL_TIMES, width = 80, align = "RIGHT",
              format = function(v) return v and tostring(v) or (GREY .. "–|r") end },
            { key = "pct", title = L.CX_COL_PCT, width = 60, align = "RIGHT",
              format = function(v) return v and ("%d %%"):format(math.floor(v * 100 + 0.5)) or "" end },
            { key = "srcText", title = L.CX_COL_SRC, width = 170 },
        },
        onEnter = function(row, item)
            if not (GameTooltip and item and item.sub) then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:AddLine(item.name, 1, 1, 1)
            GameTooltip:AddLine(L.CX_BEST_SUB:format(item.sub), 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end })
    W.cxZonesPanel = zp
end

function W.CodexRecipeTip(row, item)
    if not (GameTooltip and item and item.r) then return end
    local r = item.r
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(r.name or "?", 1, 0.82, 0)
    GameTooltip:AddLine(ns.ProfName(r.key), 0.8, 0.8, 0.8)
    local mats = G().MatsOf({ m = r.mats })
    if #mats > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.CX_TIP_MATS, 1, 1, 1)
        for _, m in ipairs(mats) do
            local unit = P().Unit(m.id)
            GameTooltip:AddDoubleLine(("%dx %s"):format(m.q, ns.ItemName(m.id) or ("#" .. m.id)),
                unit and ns.Money(unit * m.q) or "", 0.9, 0.9, 0.9, 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    if r.route then GameTooltip:AddLine(L.CX_TIP_ROUTE:format(r.routeFrom or 0), 0.55, 0.81, 0.3) end
    if r.teach then
        GameTooltip:AddLine(L.CX_TIP_TRAINER:format(r.teach.skill or 0, r.teach.cost and ns.Money(r.teach.cost) or "?"), 1, 1, 1)
    end
    if r.sold then
        GameTooltip:AddLine(L.CX_TIP_VENDOR:format(r.sold.price and ns.Money(r.sold.price) or "?"), 1, 1, 1)
    end
    for i, p in ipairs(C.Places(r)) do
        if i > 4 then break end
        GameTooltip:AddLine("  " .. ns.Books.Place(p), 0.8, 0.8, 0.8)
    end
    if not (r.route or r.teach or r.sold) then GameTooltip:AddLine(L.CX_TIP_NOSRC, 0.6, 0.6, 0.6, true) end
    local who = {}
    for name in pairs(r.by) do who[#who + 1] = name end
    table.sort(who)
    if #who > 0 then GameTooltip:AddLine(L.CX_TIP_KNOWN:format(table.concat(who, ", ")), 0.6, 0.9, 0.6, true) end
    if r.friends and #r.friends > 0 then   -- ab 0.6.0
        GameTooltip:AddLine(L.CX_TIP_FRIENDS:format(table.concat(r.friends, ", ")), 0.4, 0.73, 1, true)
    end
    if #C.Places(r) > 0 then GameTooltip:AddLine(L.CX_TIP_CLICK, 0.6, 0.6, 0.6) end
    GameTooltip:Show()
end

local function Regen(dd) if dd and dd.GenerateMenu then pcall(dd.GenerateMenu, dd) end end

-- ab 0.5.0: wechselt links der Beruf, springen beide Auswahlen mit, wenn es dafuer etwas gibt
function W.CodexFollow(prof)
    local key = prof and prof.key
    if key == W.cxLast then return end
    W.cxLast = key
    if not key then return end
    if C.HasRecipes(key) then W.cxProfKey = key end
    local group = C.GroupOf(key)
    if group then mod.db.codexGroup = group; W.cxPick = nil end
    Regen(W.cxProf)
    Regen(W.cxGroup)
end

function W.FillCodex(prof)
    W.CodexFollow(prof)
    local farm = mod.db.codexMode == "farm"
    W.cxRecBtn:SetEnabled(farm)
    W.cxFarmBtn:SetEnabled(not farm)
    W.cxRecPanel:SetShown(not farm)
    W.cxFarmPanel:SetShown(farm)
    W.cxZonesPanel:SetShown(farm)
    W.cxGroup:SetShown(farm)
    W.cxProf:SetShown(not farm)
    local text = W.cxText
    if farm then
        W.cxHint:SetText("")
        W.cxFarmRows = C.Farm(mod.db.codexGroup, text)
        W.cxFarm:SetData(W.cxFarmRows)
        W.FillCodexZones()
        local spots, maps = ns.Gather.Count()
        W.status:SetText(L.CX_STATUS_FARM:format(#W.cxFarmRows, spots, maps))
    else
        local key = W.cxProfKey
        if key ~= "all" and not ns.PROFS[key] then key = "all" end
        local list = C.Search(text, key ~= "all" and key or nil)
        local items = {}
        for _, r in ipairs(list) do
            items[#items + 1] = { r = r, name = r.name, quality = r.quality, icon = r.icon, skill = r.skill,
                prof = ns.ProfName(r.key), src = C.SourceText(r), known = C.KnownText(r) }
        end
        W.cxRecipes:SetData(items)
        W.cxHint:SetText("")
        W.status:SetText(L.CX_STATUS_REC:format(#items))
    end
    if W.status.money then W.status.money:SetAmount(0) end
end

function W.FillCodexZones()
    local e
    for _, r in ipairs(W.cxFarmRows or {}) do if r.id == W.cxPick then e = r end end
    W.cxZones:SetData(e and C.ZonesOf(e) or {})
end
