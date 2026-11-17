-- Peon_Profession - Measure.lua
-- Liest beim Oeffnen des Berufsfensters die erlernten Rezepte mit Farbe und Material (je Charakter in mod.db.known)
-- und misst (accountweit, nur lokal):
--   colors[recipeID][Farbe] = { von, bis }   bei welchen Stufen das Rezept orange (0), gelb (1), gruen (2), grau (3) war
--   ups[recipeID] = { von, bis }             bei welchen Stufen dieses Rezept wirklich Punkte gab
-- /prof messungen vergleicht das mit den Routen (Konzept Abschnitt 3, Punkt 3).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local M = {}
ns.Measure = M

M.UP_WINDOW = 15   -- Sekunden: so lange gilt eine Herstellung als Ursache eines Punkts
M.SETTLE = 0.4     -- ab 0.4.1: Sekunden Ruhe im Berufsfenster, bevor die Rezepte gelesen werden
M.sig = {}         -- ab 0.4.1: [Beruf] = { sig, base } Rezept des Guides und Stufe der letzten Meldung

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function TS() return rawget(_G, "C_TradeSkillUI") end
local function Now() return GetTime and GetTime() or 0 end

local function Extend(t, k, v)
    local r = t[k]
    if type(r) ~= "table" then t[k] = { v, v }; return end
    if v < r[1] then r[1] = v end
    if v > r[2] then r[2] = v end
end

-- Offener Beruf: Schluessel (Skill-Linie), Stufe, Hoechstwert. nil bei fremden, Gilden- oder NPC-Berufen.
function M.OpenProfession()
    local ts = TS()
    if not ts then return nil end
    for _, f in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting" }) do
        if ts[f] then
            local ok, v = pcall(ts[f])
            if ok and v then return nil end
        end
    end
    -- Ab 0.2.1: jede Quelle einzeln versuchen (eine leere Angabe des Kind-Berufs verdeckte sonst den Grundberuf),
    -- als Rueckfall der Titel des Berufsfensters ("Kochkunst"). Stufe notfalls aus GetProfessions.
    local key, info, any
    for _, f in ipairs({ "GetChildProfessionInfo", "GetBaseProfessionInfo" }) do
        if not key and ts[f] then
            local ok, i = pcall(ts[f])
            if ok and type(i) == "table" then
                if not any and Num(i.skillLevel) then any = i end
                key = (ns.PROFS[i.professionID] and i.professionID) or (ns.PROFS[i.parentProfessionID] and i.parentProfessionID)
                    or ns.KeyForName(i.professionName) or ns.KeyForName(i.parentProfessionName)
                if key then info = i end
            end
        end
    end
    if not key then key = ns.KeyForName(M.WindowTitle()) end
    if not key then return nil end
    info = info or any or {}
    local skill = Num(info.skillLevel) and info.skillLevel or nil
    local max = Num(info.maxSkillLevel) and info.maxSkillLevel or nil
    if not skill or not max then
        ns.ReadProfessions()
        local cur = ns.current and ns.current[key]
        if cur then skill, max = skill or cur.skill, max or cur.max end
    end
    return key, skill, max
end

-- Titel des Berufsfensters (Name des Berufs), nil ohne Fenster
function M.WindowTitle()
    local f = rawget(_G, "ProfessionsFrame")
    local tc = type(f) == "table" and rawget(f, "TitleContainer")
    local t = type(tc) == "table" and rawget(tc, "TitleText")
    if type(t) == "table" and t.GetText then
        local ok, s = pcall(t.GetText, t)
        if ok and type(s) == "string" and not Peon.IsSecret(s) then return s end
    end
    return nil
end

-- Fuer /prof pruefen: was das Spiel zum offenen Beruf sagt
function M.ProbeLines()
    local out = {}
    local ts = TS()
    for _, f in ipairs({ "GetChildProfessionInfo", "GetBaseProfessionInfo" }) do
        local s = f .. ": fehlt"
        if ts and ts[f] then
            local ok, i = pcall(ts[f])
            if ok and type(i) == "table" then
                s = ("%s: id=%s name=%s parent=%s/%s Stufe=%s/%s"):format(f, tostring(i.professionID), tostring(i.professionName),
                    tostring(i.parentProfessionID), tostring(i.parentProfessionName), tostring(i.skillLevel), tostring(i.maxSkillLevel))
            else
                s = f .. ": nichts"
            end
        end
        out[#out + 1] = s
    end
    out[#out + 1] = "Titel: " .. tostring(M.WindowTitle())
    local key, skill, max = M.OpenProfession()
    local n = 0
    for _ in pairs(key and mod.db.known[key] or {}) do n = n + 1 end
    -- ab 0.4.1: kann das Spiel sagen, zu welchem Beruf ein Rezept gehoert?
    out[#out + 1] = ("Rezept-Pruefung: GetProfessionInfoByRecipeID %s, GetTradeSkillLineForRecipe %s, zuletzt %s fremde verworfen")
        :format(ts and ts.GetProfessionInfoByRecipeID and "da" or "fehlt", ts and ts.GetTradeSkillLineForRecipe and "da" or "fehlt",
            tostring(M.foreign or 0))
    out[#out + 1] = ("Erkannt: Beruf %s, Stufe %s/%s, gemerkte Rezepte %d"):format(tostring(key), tostring(skill), tostring(max), n)
    return out
end

-- Ein Rezept lesen: { out, n, m = { id, q, ... }, c, name } (nur Pflicht-Grundmaterial)
function M.ReadRecipe(id, info)
    local ts = TS()
    local rec = { c = info and Num(info.relativeDifficulty) and info.relativeDifficulty or nil, name = info and info.name }
    if ts and ts.GetRecipeSchematic then
        local ok, s = pcall(ts.GetRecipeSchematic, id, false)
        if ok and type(s) == "table" then
            if Num(s.outputItemID) and s.outputItemID > 0 then rec.out = s.outputItemID end
            local n = Num(s.quantityMin) and s.quantityMin > 0 and s.quantityMin or 1
            if Num(s.quantityMax) and s.quantityMax > n then n = (n + s.quantityMax) / 2 end
            rec.n = n
            local m = {}
            for _, slot in ipairs(type(s.reagentSlotSchematics) == "table" and s.reagentSlotSchematics or {}) do
                local basic = slot.reagentType == nil or slot.reagentType == 1
                    or (Enum and Enum.CraftingReagentType and slot.reagentType == Enum.CraftingReagentType.Basic)
                local r = type(slot.reagents) == "table" and slot.reagents[1]
                if slot.required ~= false and basic and r and Num(r.itemID) then
                    m[#m + 1] = r.itemID
                    m[#m + 1] = tonumber(slot.quantityRequired) or 1
                end
            end
            if #m > 0 then rec.m = m end
        end
    end
    return rec
end

-- ab 0.4.1: Gehoert das Rezept zum Beruf? Beim Wechsel im Berufsfenster (etwa von Gifte zu Kochkunst) meldet das Spiel
-- schon den neuen Beruf, die Rezeptliste ist aber noch die alte. So landeten Gifte unter Kochkunst und der Guide schlug
-- "Sofort wirkendes Gift" als Ersatz vor. Rueckgabe: true, false (sicher ein anderer Beruf) oder nil (unbekannt).
local function Matches(key, id, name)
    if Num(id) and id == key then return true end
    if type(name) == "string" and not Peon.IsSecret(name) and name ~= "" then
        if ns.KeyForName(name) == key then return true end
        local p, low = ns.PROFS[key], name:lower()
        if p and (low:find(p.de:lower(), 1, true) or low:find(p.en:lower(), 1, true)) then return true end
    end
    return false
end

function M.Belongs(recipeID, key)
    local ts = TS()
    if not ts then return nil end
    local seen = false
    if ts.GetProfessionInfoByRecipeID then
        local ok, i = pcall(ts.GetProfessionInfoByRecipeID, recipeID)
        if ok and type(i) == "table" and (Num(i.professionID) or Num(i.parentProfessionID)) then
            seen = true
            if Matches(key, i.professionID, i.professionName) or Matches(key, i.parentProfessionID, i.parentProfessionName) then
                return true
            end
        end
    end
    if ts.GetTradeSkillLineForRecipe then
        local ok, line, name, parent = pcall(ts.GetTradeSkillLineForRecipe, recipeID)
        if ok and (Num(line) or Num(parent)) then
            seen = true
            if Matches(key, line, name) or Matches(key, parent) then return true end
        end
    end
    if seen then return false end
    return nil
end

-- Alle erlernten Rezepte des offenen Berufs lesen, Farben messen
function M.ReadAll()
    local ts = TS()
    if not (ts and ts.GetAllRecipeIDs and ts.GetRecipeInfo) then return 0 end
    local key, skill, max = M.OpenProfession()
    if not key then return 0 end
    local ok, ids = pcall(ts.GetAllRecipeIDs)
    if not ok or type(ids) ~= "table" then return 0 end
    local known = mod.db.known
    known[key] = type(known[key]) == "table" and known[key] or {}
    local list, colors, n = known[key], mod.db.colors, 0
    -- ab 0.4.1: fremde Rezepte, die frueher hier gelandet sind, wieder entfernen
    M.foreign = 0
    for id in pairs(list) do
        if M.Belongs(id, key) == false then list[id] = nil; M.foreign = M.foreign + 1 end
    end
    for _, id in ipairs(ids) do
        if Num(id) and M.Belongs(id, key) == false then
            M.foreign = M.foreign + 1
            id = nil
        end
        if Num(id) then
            local oki, info = pcall(ts.GetRecipeInfo, id)
            -- ab 0.2.1 wie Broker: erlernt, solange das Spiel nicht ausdruecklich "nicht erlernt" meldet
            if oki and type(info) == "table" and info.learned ~= false and not info.isDummyRecipe and not info.isRecraft then
                local rec = M.ReadRecipe(id, info)
                list[id] = rec
                n = n + 1
                if skill and rec.c then
                    colors[id] = type(colors[id]) == "table" and colors[id] or {}
                    Extend(colors[id], rec.c, skill)
                end
            end
        end
    end
    if ns.Codex then ns.Codex.Learned(key, list) end   -- ab 0.5.0: fuer den Codex, alle Charaktere
    if ns.Friends then ns.Friends.OwnChanged() end      -- ab 0.6.0: neuer Stand fuer Freunde
    if skill then mod.char.skills[key] = skill end
    M.key, M.skill = key, skill
    mod:Dbg(("Berufe: %d Rezepte gelesen (%s, Stufe %s, %d fremde verworfen)"):format(n, tostring(key), tostring(skill), M.foreign))
    if skill then M.CheckMilestone(key, skill, max) end   -- neue Farben koennen das Rezept des Guides wechseln
    return n
end

-- ab 0.4.1: Meilensteine. Wechselt das Rezept des Guides (Schritt zu Ende, Rezept nicht mehr orange oder gelb, ein
-- Ersatz kommt) oder ist der Hoechstwert erreicht, gibt es einen Ton und eine Chatzeile (Einstellung stepSound).
-- Kennung: Schritt und aktives Rezept. Text: was jetzt kommt.
function M.GuideSig(key, skill, max)
    local G = ns.Guide
    if not (G and G.Route(key)) or not Num(skill) then return nil end
    if Num(max) and max > 0 and max < 300 and skill >= max then
        return "max" .. max, L.MILESTONE_MAX:format(ns.ProfName(key), max)
    end
    local step, i = G.CraftStepAt(key, skill)
    if not step then return "done", L.MILESTONE_DONE:format(ns.ProfName(key), skill) end
    local v = G.View(key, step, skill, i)
    if not v then return nil end
    if v.gather then
        local names = {}
        for _, id in ipairs(v.gather) do names[#names + 1] = ns.ItemName(id) or ("#" .. id) end
        return "g" .. i, L.MILESTONE_GATHER:format(table.concat(names, ", "), v.to)
    end
    local _, rid, item = G.Active(v)
    local spell = v.alt and v.alt.id or v.spell
    local name = G.RecipeName(item, spell, v.alt and v.alt.rec or v.rec)
    if not (v.item or v.spell or v.alt) then name = L.FREE_STEP end
    if v.smelt and not v.alt then name = L.SMELT_ROW:format(name) end
    return i .. ":" .. tostring(rid or item or "-"), L.MILESTONE_NEXT:format(name, v.to)
end

function M.CheckMilestone(key, skill, max)
    local ok, sig, text = pcall(M.GuideSig, key, skill, max)
    if not ok or not sig then return false end
    local old = M.sig[key]
    if not old then M.sig[key] = { sig = sig, base = skill }; return false end
    local prev = old.sig
    old.sig = sig
    if prev == sig or skill <= old.base then return false end
    old.base = skill   -- hoechstens eine Meldung je Stufe
    M.Alert(text)
    return true
end

function M.InitMilestones()
    for _, p in ipairs(ns.ReadProfessions()) do
        M.sig[p.key] = nil
        M.CheckMilestone(p.key, p.skill, p.max)
    end
end

M.SOUNDS = {
    { key = "ready", kit = "READY_CHECK", id = 8960 },   -- id = Rueckfall, falls SOUNDKIT den Namen nicht kennt
    { key = "raid", kit = "RAID_WARNING", id = 8959 },
    { key = "tell", kit = "TELL_MESSAGE", id = 3081 },
    { key = "levelup", kit = "LEVELUPSOUND", id = 888 },
}

-- Ton (Kanal "Master" wie bei Broker) und Chatzeile. force = Probe aus den Optionen
function M.Alert(text, force)
    if not force and not mod.db.stepSound then return end
    if text then mod:Print(text) end
    if not PlaySound then return end
    local key = mod.db.stepSoundKey or "ready"
    for _, s in ipairs(M.SOUNDS) do
        if s.key == key then
            local id = (SOUNDKIT and SOUNDKIT[s.kit]) or s.id
            pcall(PlaySound, id, "Master")
            return
        end
    end
end

-- ab 0.4.1: /prof vergessen: gemerkte Rezepte dieses Charakters loeschen, beim naechsten Oeffnen neu lesen
function M.Forget()
    local n = 0
    for _, list in pairs(mod.db.known) do
        if type(list) == "table" then for _ in pairs(list) do n = n + 1 end end
    end
    wipe(mod.db.known)
    if ns.Codex then ns.Codex.ForgetMe() end   -- ab 0.5.0
    mod:Print(L.FORGET_DONE:format(n))
    if ns.Window and ns.Window.IsOpen() then ns.Window.Refresh() end
    return n
end

-- Herstellung merken (Ursache fuer den naechsten Punkt)
function M.OnCast(unit, spellID)
    if unit ~= "player" or not Num(spellID) then return end
    for key, list in pairs(mod.db.known) do
        if type(list) == "table" and list[spellID] then M.last = { id = spellID, key = key, t = Now() }; return end
    end
end

-- Stufen vergleichen: Punkt bekommen kurz nach einer Herstellung -> ups[recipeID] erweitern
function M.OnSkills()
    local skills = mod.char.skills
    for _, p in ipairs(ns.ReadProfessions()) do
        local old = skills[p.key]
        if type(old) == "number" and p.skill > old and p.skill - old <= 5 then
            local l = M.last
            if l and l.key == p.key and Now() - l.t <= M.UP_WINDOW then
                Extend(mod.db.ups, l.id, old)
                Extend(mod.db.ups, l.id, p.skill - 1)
            end
        end
        if type(old) == "number" and p.skill > old then M.CheckMilestone(p.key, p.skill, p.max) end   -- ab 0.4.1
        skills[p.key] = p.skill
    end
    if ns.Window and ns.Window.IsOpen() then ns.Window.Refresh() end
    if ns.CraftBar then ns.CraftBar.Update() end
    if ns.Craft then ns.Craft.dirty = true end   -- Pfeil des Guides wandert mit der Stufe
    if ns.RefreshLauncher then ns.RefreshLauncher() end   -- Stufe in der Leiste von Peon_Panel
end

function M.OnShow()
    mod:Call("Berufsfenster lesen", M.ReadAll)
    if ns.CraftBar then ns.CraftBar.Update() end
    if ns.Window and ns.Window.IsOpen() then ns.Window.Refresh() end
end

function M.Init()
    for _, p in ipairs(ns.ReadProfessions()) do
        if mod.char.skills[p.key] == nil then mod.char.skills[p.key] = p.skill end
    end
    pcall(mod.RegisterEvent, mod, "TRADE_SKILL_SHOW", function() M.OnShow() end)
    pcall(mod.RegisterEvent, mod, "TRADE_SKILL_LIST_UPDATE", function()
        -- kommt oft hintereinander. Ab 0.4.1 erst lesen, wenn eine Weile Ruhe ist: Vorher las die Sperre "einmal je
        -- Sekunde" beim Wechsel des Berufs mitten im Umbau und verschluckte das Lesen danach.
        M.token = (M.token or 0) + 1
        local token = M.token
        local function Run() if token == M.token then M.OnShow() end end
        if C_Timer and C_Timer.After then C_Timer.After(M.SETTLE, Run) else Run() end
    end)
    -- ab 0.4.1: Meilensteine erst ab hier, gemessen an der Stufe beim Einloggen
    mod:Call("Meilensteine", M.InitMilestones)
    pcall(mod.RegisterEvent, mod, "UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID) M.OnCast(unit, spellID) end)
    pcall(mod.RegisterEvent, mod, "SKILL_LINES_CHANGED", function() mod:Call("Stufen", M.OnSkills) end)
end

-- Abweichungen der Messungen von den Routen im Chat
function M.Report()
    local lines = {}
    for _, key in ipairs(ns.ORDER) do
        local known = ns.Guide.Known(key)
        local used = {}
        for _, s in ipairs(ns.Guide.Steps(key)) do   -- ab 0.4.0 mit Verhuetten
            local id = ns.Guide.KnownFor(key, s)
            id = id or s.spell
            if id then
                used[id] = true
                -- Abweichung: im Schritt schon nicht mehr orange (gelb, gruen, grau gemessen) oder ueber das Ende hinaus orange
                local col = mod.db.colors[id]
                local name = ns.Guide.RecipeName(s.item, s.spell, known[id])
                local worse
                for c = 1, 3 do
                    local r = col and col[c]
                    if r and r[1] < s.to and r[2] >= s.from and (not worse or r[1] < worse[2]) then worse = { c, r[1] } end
                end
                if worse then
                    lines[#lines + 1] = L.MEASURE_LINE:format(ns.ProfName(key), s.from, s.to, name, L.COLOR[worse[1]], worse[2])
                end
                local o = col and col[0]
                if o and o[2] >= s.to then
                    lines[#lines + 1] = L.MEASURE_LINE:format(ns.ProfName(key), s.from, s.to, name, L.COLOR[0], o[2])
                end
            end
        end
        for id, r in pairs(mod.db.ups) do
            if known[id] and not used[id] and type(r) == "table" then
                lines[#lines + 1] = L.MEASURE_UP:format(ns.ProfName(key), ns.Guide.RecipeName(known[id].out, id, known[id]), r[1], r[2])
            end
        end
    end
    mod:Print(L.MEASURE_HDR)
    if #lines == 0 then mod:Print(L.MEASURE_NONE) end
    for _, l in ipairs(lines) do mod:Print(l) end
    return lines
end
