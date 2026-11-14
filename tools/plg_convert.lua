-- tools/plg_convert.lua
-- Einmalige Umwandlung der Forever-Routen aus "Profession Leveling Guide" 2.7.2 (icêheal, MIT-Lizenz)
-- in die Routentabelle von Peon_Profession (nur Nummern, keine Texte).
-- Konzept: docs/konzepte/profession/Peon_Profession_Konzept.md Abschnitt 3.
--
-- Aufruf (aus dem Repo):
--   tools\lua5.1.exe tools\plg_convert.lua "<WoW-Ordner>\Interface\AddOns\ProfessionLevelingGuide" addons\Peon_Profession\Routes.lua
--
-- Danach werden die Routen nur noch von Hand gepflegt (Entscheidung KarloDerBaer 14.11.2026). Das Skript bleibt
-- zum Nachvollziehen im Repo. Die PLG-Dateien selbst kommen nicht ins Repo.

local SRC, OUT = arg[1], arg[2]
assert(SRC and OUT, "Aufruf: plg_convert.lua <PLG-Ordner> <Ausgabedatei>")

-- Kleiner Stub, damit die Datendateien von PLG laufen
function GetLocale() return "deDE" end
C_Map = {}
local function noop() end
setmetatable(_G, { __index = function(_, k) if type(k) == "string" and k:match("^%u") then return nil end end })

-- Datendateien in der Reihenfolge der TOC laden (nur Data\...)
local files = {}
for line in io.lines(SRC .. "/ProfessionLevelingGuide.toc") do
    local f = line:match("^(Data\\.-%.lua)%s*$")
    if f then files[#files + 1] = f:gsub("\\", "/") end
end
for _, f in ipairs(files) do
    local chunk = assert(loadfile(SRC .. "/" .. f))
    local ok, err = pcall(chunk, "ProfessionLevelingGuide", {})
    if not ok then io.stderr:write("Warnung: " .. f .. ": " .. tostring(err) .. "\n") end
end

-- Berufe: PLG-Name -> Schluessel in Peon_Profession (Skill-Linie des Spiels)
local PROFS = {
    { "Alchimie", 171 }, { "Schmiedekunst", 164 }, { "Verzauberkunst", 333 }, { "Ingenieurskunst", 202 },
    { "Lederverarbeitung", 165 }, { "Schneidern", 197 }, { "Kochkunst", 185 }, { "Erste Hilfe", 129 },
    { "Bergbau", 186 }, { "Kräuterkunde", 182 }, { "Kürschnerei", 393 }, { "Angeln", 356 },
}

-- Gebiete (deutsch und englisch, wie in den PLG-Texten) -> uiMapID. Den Namen liefert im Spiel C_Map.
local ZONES = {
    ["Wald von Elwynn"] = 1429, ["Elwynn Forest"] = 1429, ["Dun Morogh"] = 1426, ["Teldrassil"] = 1438,
    ["Durotar"] = 1411, ["Mulgore"] = 1412, ["Tirisfal"] = 1420, ["Tirisfal Glades"] = 1420,
    ["Westfall"] = 1436, ["Loch Modan"] = 1432, ["Brachland"] = 1413, ["The Barrens"] = 1413,
    ["Silberwald"] = 1421, ["Silverpine Forest"] = 1421, ["Rotkammgebirge"] = 1433, ["Redridge Mountains"] = 1433,
    ["Dunkelküste"] = 1439, ["Darkshore"] = 1439, ["Eschental"] = 1440, ["Ashenvale"] = 1440,
    ["Vorgebirge des Hügellands"] = 1424, ["Hillsbrad Foothills"] = 1424, ["Sumpfland"] = 1437, ["Wetlands"] = 1437,
    ["Steinkrallengebirge"] = 1442, ["Stonetalon Mountains"] = 1442, ["Dämmerwald"] = 1431, ["Duskwood"] = 1431,
    ["Tausend Nadeln"] = 1441, ["Thousand Needles"] = 1441, ["Arathihochland"] = 1417, ["Arathi Highlands"] = 1417,
    ["Desolace"] = 1443, ["Schlingendorntal"] = 1434, ["Stranglethorn Vale"] = 1434,
    ["Düstermarschen"] = 1445, ["Dustwallow Marsh"] = 1445, ["Ödland"] = 1418, ["Badlands"] = 1418,
    ["Sümpfe des Elends"] = 1435, ["Swamp of Sorrows"] = 1435, ["Alteracgebirge"] = 1416, ["Alterac Mountains"] = 1416,
    ["Feralas"] = 1444, ["Tanaris"] = 1446, ["Hinterland"] = 1425, ["The Hinterlands"] = 1425,
    ["Sengende Schlucht"] = 1427, ["Searing Gorge"] = 1427, ["Azshara"] = 1447,
    ["Verwüstete Lande"] = 1419, ["Blasted Lands"] = 1419, ["Krater von Un'Goro"] = 1449, ["Un'Goro Crater"] = 1449,
    ["Teufelswald"] = 1448, ["Felwood"] = 1448, ["Brennende Steppe"] = 1428, ["Burning Steppes"] = 1428,
    ["Westliche Pestländer"] = 1422, ["Western Plaguelands"] = 1422, ["Östliche Pestländer"] = 1423,
    ["Eastern Plaguelands"] = 1423, ["Winterquell"] = 1452, ["Winterspring"] = 1452, ["Silithus"] = 1451,
    ["Sturmwind"] = 1453, ["Stormwind"] = 1453, ["Orgrimmar"] = 1454, ["Eisenschmiede"] = 1455, ["Ironforge"] = 1455,
    ["Donnerfels"] = 1456, ["Thunder Bluff"] = 1456, ["Darnassus"] = 1457, ["Unterstadt"] = 1458, ["Undercity"] = 1458,
}

local function Klein(s) return (s:lower():gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü")) end
local function Trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- Forever-Rezepte je Name (deutsch und englisch) -> { spell, mats }
local foreverByName = {}
local foreverItemByName = {}
for id, names in pairs(BSG_ForeverItems or {}) do
    if names[1] then foreverItemByName[Klein(names[1])] = id end
    if names[2] then foreverItemByName[Klein(names[2])] = id end
end
-- Die Rezeptdateien legen ihre Tabelle ueber BSG_ForeverRezepteAnlegen an. Falls PLG sie global ablegt, nutzen,
-- sonst die Dateien noch einmal mit einer eigenen Sammelfunktion laden.
local recipes = {}
local origAnlegen = BSG_ForeverRezepteAnlegen
BSG_ForeverRezepteAnlegen = function(beruf, en, liste)
    for _, r in ipairs(liste) do
        local spell, skill, de, enName, mats, src = r[1], r[2], r[3], r[4], r[5], r[6]
        local e = { spell = spell, skill = skill, mats = mats, src = src, prof = beruf }
        recipes[spell] = e
        if de and de ~= "" then foreverByName[Klein(de)] = e end
        if enName and enName ~= "" then foreverByName[Klein(enName)] = e end
    end
end
for _, f in ipairs(files) do
    if f:match("Data/Forever/Daten_Forever_%a+%.lua$") then
        local chunk = loadfile(SRC .. "/" .. f)
        if chunk then pcall(chunk, "ProfessionLevelingGuide", {}) end
    end
end
BSG_ForeverRezepteAnlegen = origAnlegen

local missing = {}
local function Miss(kind, name) missing[kind .. ": " .. name] = true end

-- Name eines Gegenstands -> itemID
local function ItemID(name)
    name = Trim(name)
    local id = BSG_ItemDB and BSG_ItemDB[name]
    if type(id) == "number" then return id end
    local code = BSG_NamenIDs and (BSG_NamenIDs[Klein(name)] or BSG_NamenIDs[(Klein(name):gsub("^enchant ", ""))])
    id = code and tonumber(code:match("^i:(%d+)$"))
    if id then return id end
    return foreverItemByName[Klein(name)]
end

-- Namen, die PLG nirgends einer Nummer zuordnet (von Hand nachgetragen)
local EXTRA = {
    ["Elixier der schwachen Seelenstärke"] = 2458,   -- Elixir of Minor Fortitude
    ["Kleiner Seidenbeutel"] = 4245,                 -- Small Silk Pack
    ["Schwerer Rüstungssatz"] = 4265,                -- Heavy Armor Kit
}

-- Rezept eines Schritts: Ergebnis-Gegenstand und/oder Zauber
local function Recipe(name)
    name = Trim(name)
    local out = {}
    if EXTRA[name] then out.item = EXTRA[name] end
    local code = BSG_NamenIDs and (BSG_NamenIDs[Klein(name)] or BSG_NamenIDs[(Klein(name):gsub("^enchant ", ""))])
    if code then
        local art, id = code:match("^(%a):(%d+)$")
        if art == "i" then out.item = tonumber(id) elseif art == "s" then out.spell = tonumber(id) end
    end
    if not out.item and not out.spell then
        local id = BSG_ItemDB and BSG_ItemDB[name]
        if type(id) == "number" then out.item = id end
    end
    local fr = foreverByName[Klein(name)] or foreverByName[Klein("Enchant " .. name)]
    if fr then
        out.spell = out.spell or fr.spell
        out.fr = fr
    end
    return out
end

-- "1 Friedensblume, 2 Erdwurzel" -> { 2447, 1, 2449, 2 } (nil, wenn ein Teil nicht aufgeht)
local function Mats(text)
    if type(text) ~= "string" or Trim(text) == "" then return nil end
    local out = {}
    for part in text:gmatch("[^,]+") do
        local n, name = Trim(part):match("^(%d+)%s+(.+)$")
        if not n then return nil end
        local id = ItemID(name)
        if not id then Miss("Material", name); return nil end
        out[#out + 1] = id
        out[#out + 1] = tonumber(n)
    end
    return out
end

local function Zones(text, into)
    if type(text) ~= "string" then return end
    text = text:gsub("%s*%b()", "")   -- Koordinaten "(47.7, 62.5)" vor dem Trennen am Komma entfernen
    for part in text:gmatch("[^,]+") do
        local z = Trim(part):gsub("%s+%-%s+.*$", "")
        z = Trim(z)
        local id = ZONES[z]
        if id then
            local dup = false
            for _, v in ipairs(into) do if v == id then dup = true end end
            if not dup then into[#into + 1] = id end
        elseif z ~= "" then
            Miss("Gebiet", z)
        end
    end
end

local function Num(v) return string.format("%d", v) end
local function List(t)
    local s = {}
    for _, v in ipairs(t) do s[#s + 1] = Num(v) end
    return "{ " .. table.concat(s, ", ") .. " }"
end

local lines = {}
local function W(s) lines[#lines + 1] = s end
local stats = {}

W("-- Peon_Profession - Routes.lua")
W("-- Routen zum Leveln der Berufe in WoW Forever. Nur Nummern, Namen liefert das Spiel (C_Item, C_Spell, C_Map).")
W("--")
W("-- Grundlage: \"Profession Leveling Guide\" 2.7.2 von icêheal (MIT-Lizenz, Text unten), einmal umgewandelt mit")
W("-- tools/plg_convert.lua am " .. os.date("%d.%m.%Y") .. ". Seitdem von Hand gepflegt (eigene Messungen, /prof messungen).")
W("--")
W("-- Je Beruf (Schluessel = Skill-Linie des Spiels) eine Liste von Schritten:")
W("--   from, to   Stufe von bis")
W("--   n          empfohlene Anzahl Herstellungen fuer den ganzen Schritt (geschaetzt)")
W("--   item       Ergebnis-Gegenstand (itemID), spell = Rezept (Zauber-ID, bei Verzauberungen ohne Gegenstand)")
W("--   mats       Material je Herstellung { itemID, Menge, ... } (nil = nur aus dem Berufsfenster)")
W("--   gather     Sammelberufe und Angeln: was man sammelt (itemIDs), A / H = Gebiete (uiMapID) fuer Allianz / Horde")
W("--")
W("-- MIT License, Copyright (c) 2026 icêheal")
W("-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated")
W("-- documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation")
W("-- the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to")
W("-- permit persons to whom the Software is furnished to do so, subject to the following conditions:")
W("-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of")
W("-- the Software.")
W("-- THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO")
W("-- THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE")
W("-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF")
W("-- CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS")
W("-- IN THE SOFTWARE.")
W("")
W("local ADDON_NAME, ns = ...")
W("local R = {}")
W("ns.Routes = R")
W("")

local usedSpells = {}
for _, p in ipairs(PROFS) do
    local name, key = p[1], p[2]
    local steps = (BerufeGuideDB_Forever and BerufeGuideDB_Forever[name]) or (BerufeGuideDB and BerufeGuideDB[name])
    local src = (BerufeGuideDB_Forever and BerufeGuideDB_Forever[name]) and "Forever" or "Classic"
    W(("R[%d] = {   -- %s (%s)"):format(key, name, src))
    local n = 0
    for _, s in ipairs(steps or {}) do
        local from, to = tonumber(s.minSkill), tonumber(s.maxSkill)
        if from and to and to > from then
            local parts = { "from = " .. Num(from), "to = " .. Num(to) }
            if s.typ == "sammeln" then
                local gather = {}
                for part in (s.item or ""):gmatch("[^,]+") do
                    local id = ItemID(part)
                    if id then gather[#gather + 1] = id elseif Trim(part) ~= "" then Miss("Sammeln", Trim(part)) end
                end
                local A, H = {}, {}
                Zones(s.allianz, A); Zones(s.horde, H); Zones(s.beide, A); Zones(s.beide, H)
                if #gather > 0 then parts[#parts + 1] = "gather = " .. List(gather) end
                if #A > 0 then parts[#parts + 1] = "A = " .. List(A) end
                if #H > 0 then parts[#parts + 1] = "H = " .. List(H) end
            else
                local count, rest = (s.item or ""):match("^%s*[Cc][Aa]%.%s*(%d+)[xX]?%s+(.+)$")
                if not count then count, rest = (s.item or ""):match("^%s*(%d+)[xX]?%s+(.+)$") end
                rest = rest or s.item or ""
                local r = Recipe(rest)
                if not r.item and not r.spell then Miss("Rezept", rest) end
                if count then parts[#parts + 1] = "n = " .. count end
                if r.item then parts[#parts + 1] = "item = " .. Num(r.item) end
                if r.spell then parts[#parts + 1] = "spell = " .. Num(r.spell); usedSpells[r.spell] = true end
                local m = Mats(s.mats) or (r.fr and r.fr.mats)
                if m and #m > 0 then parts[#parts + 1] = "mats = " .. List(m) end
            end
            W("    { " .. table.concat(parts, ", ") .. " },")
            n = n + 1
        end
    end
    W("}")
    stats[#stats + 1] = ("%s: %d Schritte (%s)"):format(name, n, src)
end

-- Rezepte mit Lernstufe (nur Forever-Rezepte, die in Routen vorkommen)
W("")
W("-- Forever-Rezepte der Routen: Stufe zum Lernen, Quelle (t Lehrer, v Haendler, d Beute, q Quest, m Muster)")
W("ns.Learn = {")
local ids = {}
for id in pairs(usedSpells) do ids[#ids + 1] = id end
table.sort(ids)
for _, id in ipairs(ids) do
    local r = recipes[id]
    if r and (r.skill or r.src) then
        local srcCode = r.src and r.src:sub(1, 1) or nil
        W(("    [%d] = { %s%s },"):format(id, r.skill and ("skill = " .. Num(r.skill)) or "",
            srcCode and ((r.skill and ", " or "") .. ("src = %q"):format(srcCode)) or ""))
    end
end
W("}")

local f = assert(io.open(OUT, "wb"))
f:write(table.concat(lines, "\n"), "\n")
f:close()

for _, s in ipairs(stats) do print(s) end
local miss = {}
for k in pairs(missing) do miss[#miss + 1] = k end
table.sort(miss)
if #miss > 0 then
    print("Nicht aufgeloest (" .. #miss .. "):")
    for _, k in ipairs(miss) do print("  " .. k) end
end
