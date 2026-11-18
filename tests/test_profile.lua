-- Peon-Kern: Profile (Profiles.lua, API 25, ab 0.25.0).
-- Prueft: Speichern ohne keepOnReset, debug und Daten, Charakterwerte, Kopien, noProfile, Laden mit Pruefung und Grenzen,
-- RESET, Fehlerfaelle, hoechstens 20 Profile, Befehle, Hilfe, Optionsseite.
-- Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
function GetTime() return 1 end
date, time = os.date, os.time
local combat = false
function InCombatLockdown() return combat end
function UnitAffectingCombat() return false end
function GetMoney() return 1234567 end
function hooksecurefunc(t, name, fn) local old = t[name] t[name] = function(...) local r = old and old(...) fn(...) return r end end
SlashCmdList, UISpecialFrames = {}, {}

local function fail(msg) print("FEHLER: " .. msg); os.exit(1) end
local function check(c, msg) if not c then fail(msg) end end

local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function() return true end, GetNumAddOns = function() return 1 end,
  GetAddOnInfo = function(i) return ({ "Peon" })[i] end }
C_Texture = { GetAtlasInfo = function(name) return { width = 10, height = 10 } end }

-- Rahmen-Nachbau: Zustand fuer Groesse, Text, Sichtbarkeit, Skripte, Haken, Werte; alles andere tut nichts
local created = {}
local function W(kind)
  local o = { kind = kind, scripts = {}, w = 0, h = 0, shown = true, txt = "", checked = false, enabled = true, points = {} }
  local m = {}
  function m.SetSize(s, w, h) s.w, s.h = w, h end
  function m.SetWidth(s, w) s.w = w end
  function m.SetHeight(s, h) s.h = h end
  function m.GetWidth(s) return s.w end
  function m.GetHeight(s) return s.h end
  function m.GetStringWidth(s) return #(s.txt or "") * 6 end
  function m.SetText(s, t) s.txt = t end
  function m.GetText(s) return s.txt end
  function m.Show(s) s.shown = true end
  function m.Hide(s) s.shown = false end
  function m.IsShown(s) return s.shown end
  function m.SetShown(s, v) s.shown = v and true or false end
  function m.SetScript(s, n, f) s.scripts[n] = f end
  function m.GetScript(s, n) return s.scripts[n] end
  function m.HookScript(s, n, f) local old = s.scripts[n] s.scripts[n] = function(...) if old then old(...) end f(...) end end
  function m.SetChecked(s, v) s.checked = v end
  function m.GetChecked(s) return s.checked end
  function m.Disable(s) s.enabled = false end
  function m.Enable(s) s.enabled = true end
  function m.IsEnabled(s) return s.enabled end
  function m.SetPoint(s, ...) s.points[#s.points + 1] = { ... } end
  function m.ClearAllPoints(s) s.points = {} end
  function m.GetFrameLevel() return 1 end
  function m.SetTextColor(s, r, g, b) s.color = { r, g, b } end
  function m.SetVertexColor(s, r, g, b) s.vcolor = { r, g, b } end
  function m.SetAtlas(s, a) s.atlas = a end
  function m.SetTexture(s, f) s.file = f end
  function m.SetTexCoord(s, ...) s.tc = { ... } end
  function m.GetPoint(s, i) local p = s.points[i or 1] if p then return unpack(p) end end
  function m.SetMinMaxValues(s, a, b) s.min, s.max = a, b end
  function m.SetValue(s, v) s.value = v end
  function m.GetValue(s) return s.value end
  function m.CreateFontString() local f = W("FontString") return f end
  function m.CreateTexture() return W("Texture") end
  function m.CreateMaskTexture() return W("MaskTexture") end
  return setmetatable(o, { __index = function(_, k)
    if m[k] then return m[k] end
    if type(k) == "string" and k:match("^%u") and k ~= "Text" and k ~= "Bg" and k ~= "NineSlice" and k ~= "Icon" and k ~= "Low" and k ~= "High" then return function() end end
  end })
end
UIParent = W("Frame")
GameTooltip = W("GameTooltip")
function CreateFrame(kind, name, parent, tmpl)
  -- Blizzards Vorlagen fehlen im Nachbau: wie im Spiel ein Fehler, der Rueckfall muss greifen
  if tmpl and tmpl ~= "UIPanelButtonTemplate" and tmpl ~= "InputBoxTemplate" then error("Couldn't find inherited node \"" .. tmpl .. "\"") end
  local f = W(kind)
  f.name, f.parent, f.tmpl = name, parent, tmpl
  if kind == "Button" then
    -- Knopf mit eigener Schrift wie UIPanelButtonTemplate
    local fs = W("FontString")
    f.GetFontString = function() return fs end
    f.SetText = function(s, t) s.txt = t; fs.txt = t end
  end
  if name then _G[name] = f end
  created[#created + 1] = f
  return f
end
timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }

local function load(dir, files)
  local ns = {}
  for _, f in ipairs(files) do
    local chunk, err = loadfile(dir .. "/" .. f)
    if not chunk then fail(err) end
    chunk(dir, ns)
  end
  return ns
end
local ns = load("Peon", { "Locales.lua", "Core.lua", "Module.lua", "Options.lua", "UIKit.lua", "Notice.lua", "Profiles.lua", "Slash.lua" })
PeonDB = {}
PeonDB = {}
Peon.db = PeonDB
local reported = {}
Peon.ReportCoreError = function(where, err) reported[#reported + 1] = where .. ": " .. tostring(err) end
local P = ns.Profiles
check(P and Peon.Profiles == P, "Profiles.lua geladen, Peon.Profiles")
check(Peon.API >= 25, "Kern-API 25")
local toc = io.open("Peon/Peon.toc"):read("*a")
check(toc:find("Comm.lua\r?\nProfiles.lua\r?\nSlash.lua"), "Profiles.lua in der TOC nach Comm und vor Slash")

-- Zwei Testmodule: eines mit Charakterwert, Bereich, Auswahl und Daten, eines ohne Profil
TestADB, TestACharDB = { pos = { x = 5 }, data = { 1, 2, 3 } }, {}
local A = Peon:NewModule("Peon_TestA", {
  key = "testa", title = "Test A", db = "TestADB", charDB = "TestACharDB",
  charKeys = { mode = true },
  defaults = { size = 10, color = { 1, 0, 0 }, mode = "normal", corner = "TOPLEFT", pos = { x = 0 } },
  ranges = { size = { 1, 50, 1 } },
  choices = { corner = { TOPLEFT = true, TOPRIGHT = true } },
  keepOnReset = { pos = true },
})
local resets = 0
A:On("RESET", function() resets = resets + 1 end)
TestBDB = {}
local B = Peon:NewModule("Peon_TestB", { key = "testb", title = "Test B", db = "TestBDB", defaults = { on = true }, noProfile = true })
TestCDB = {}
local C = Peon:NewModule("Peon_TestC", { key = "testc", title = "Test C", db = "TestCDB", defaults = { level = 3 } })
A:_Init(); B:_Init(); C:_Init()
check(A.db.size == 10 and A.db.mode == "normal" and TestACharDB.mode == "normal", "Module mit Standardwerten")

-- Speichern
A.db.size, A.db.mode, A.db.corner = 22, "fishing", "TOPRIGHT"
A.db.color[2] = 0.5
A.db.debug = true
C.db.level = 7
local ok, n = P.Save("  Hexer |cffff0000rot|r  ")
check(ok and n == 2, "Profil gespeichert, 2 Module (TestB ausgelassen): " .. tostring(n))
local list = P.List()
check(#list == 1 and list[1].name == "Hexer rot" and list[1].mods == 2, "Name ohne Farbcodes, Liste: " .. tostring(list[1] and list[1].name))
local saved = PeonDB.profiles[list[1].name].mods
check(saved.testa.size == 22 and saved.testa.mode == "fishing" and saved.testa.corner == "TOPRIGHT", "Werte gespeichert, auch der Charakterwert")
check(saved.testa.pos == nil and saved.testa.debug == nil and saved.testa.data == nil, "keepOnReset, debug und Daten nicht im Profil")
check(saved.testb == nil and saved.testc.level == 7, "noProfile ausgelassen")
check(saved.testa.color ~= A.db.color and saved.testa.color[2] == 0.5, "Tabellen kopiert, nicht geteilt")
A.db.color[1] = 0.1
check(saved.testa.color[1] == 1, "spaetere Aenderung trifft das Profil nicht")

-- Laden auf einem "anderen Charakter": Charakterwert neu, Konto-Werte zurueck
P.Save("Basis")
A.db.size, A.db.mode, A.db.corner, A.db.pos = 3, "normal", "TOPLEFT", { x = 99 }
TestACharDB.mode = "normal"
C.db.level = 1
local r0 = resets
local ok2, mods, values = P.Load("hexer rot")
check(ok2 and mods == 2 and values == 5, "Laden: 2 Module, 5 Werte (Gross- und Kleinschreibung egal): " .. tostring(mods) .. "/" .. tostring(values))
check(A.db.size == 22 and A.db.mode == "fishing" and TestACharDB.mode == "fishing" and A.db.corner == "TOPRIGHT" and C.db.level == 7, "Werte uebernommen, Charakterwert im Charakterfach")
check(A.db.pos.x == 99, "Position (keepOnReset) bleibt")
check(A.db.color[1] == 1 and A.db.color ~= PeonDB.profiles["Hexer rot"].mods.testa.color, "Tabelle beim Laden kopiert")
check(resets == r0 + 1, "RESET danach, damit sich alles neu zeichnet")

-- Ungueltige Werte im Profil werden nicht uebernommen, Zahlen begrenzt, unbekannte Schluessel ignoriert
PeonDB.profiles.Kaputt = { t = 1, mods = { testa = { size = 999, corner = "MITTE", mode = 5, fremd = 1, pos = { x = 1 } }, weg = { a = 1 } } }
local ok3, m3, v3 = P.Load("Kaputt")
check(ok3 and m3 == 1 and v3 == 1 and A.db.size == 50, "nur gueltige Werte, Zahl auf den Bereich begrenzt: " .. tostring(v3) .. " " .. tostring(A.db.size))
check(A.db.corner == "TOPRIGHT" and A.db.mode == "fishing" and A.db.pos.x == 99 and A.db.fremd == nil, "ungueltige und fremde Werte bleiben weg")

-- Fehlerfaelle
check(select(2, P.Save("")) == "name" and select(2, P.Save(string.rep("x", 41))) == "name", "Name leer oder zu lang")
check(select(2, P.Load("Gibts nicht")) == "missing" and P.Delete("Gibts nicht") == false, "unbekanntes Profil")
for i = 1, P.MAX do P.Save("P" .. i) end
local okF, why = P.Save("Noch eins")
check(not okF and why == "full", "hoechstens " .. P.MAX .. " Profile")
check(P.Save("Basis"), "vorhandenes Profil ueberschreiben geht auch bei voller Liste")
check(P.Delete("basis") and PeonDB.profiles.Basis == nil, "Loeschen (Gross- und Kleinschreibung egal)")

-- Befehle und Ausgaben
out = {}
SlashCmdList.PEON("profil speichern Mein Profil")
check(PeonDB.profiles["Mein Profil"] and out[#out]:find("gespeichert", 1, true), "/peon profil speichern")
combat = true
SlashCmdList.PEON("profil laden Mein Profil")
check(out[#out]:find("Kampf", 1, true), "im Kampf nicht laden")
combat = false
SlashCmdList.PEON("profil laden Mein Profil")
check(out[#out]:find("geladen", 1, true) and out[#out]:find("/reload", 1, true), "/peon profil laden mit Hinweis auf /reload")
out = {}
SlashCmdList.PEON("profil")
local all = table.concat(out, "\n")
check(all:find("Mein Profil", 1, true) and all:find("/peon profil speichern", 1, true), "Liste und Hilfe")
SlashCmdList.PEON("profil loeschen Mein Profil")
check(PeonDB.profiles["Mein Profil"] == nil, "/peon profil loeschen")
out = {}
SlashCmdList.PEON("hilfe")
check(table.concat(out, "\n"):find("/peon profil", 1, true), "Hilfe von /peon nennt die Profile")

-- Optionsseite: Unterseite Profile, Knoepfe arbeiten mit dem Namen im Feld
local panel = P.CreatePanel()
check(panel and panel.name == "Profile" and P.option.box and P.option.save, "Seite Profile mit Feld und Knoepfen")
P.option.box:SetText("Seite")
P.option.save.scripts.OnClick()
check(PeonDB.profiles.Seite, "Knopf Speichern")
panel.scripts.OnShow()
check(P.option.list.txt:find("Seite", 1, true), "Liste auf der Seite")
P.option.delete.scripts.OnClick()
check(PeonDB.profiles.Seite == nil and not P.option.list.txt:find("Seite (", 1, true), "Knopf Loeschen, Liste neu")
check(#reported == 0, "keine Fehler: " .. table.concat(reported, " | "))

print("ALLE TESTS OK")
