-- Peon-Kern: Profile (Profiles.lua, API 25 Staende, ab API 26 laufende Profile mit Standard).
-- Prueft: Start mit Standard, Uebernahme der Staende aus 0.25.0, Benutzen mit Kopie, mehrere Charaktere nacheinander,
-- Charakterwerte und keepOnReset unberuehrt, noProfile, leer, Kopieren von, ungueltige Werte, Speichern, Loeschen,
-- Grenzen, Befehle, Hilfe, Optionsseite. Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
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
function UnitName() return CHAR end
function GetRealmName() return "Forever" end
CHAR = "Arnulf Stein"
-- Staende aus 0.25.0, die zu Profilen werden
PeonDB = { profiles = { Alt = { t = 1, mods = { testa = { size = 5, corner = "TOPRIGHT" } } }, ["|cffff0000Kaputt"] = 7 } }
PeonCharDB = nil
local ns = load("Peon", { "Locales.lua", "Core.lua", "Module.lua", "Options.lua", "UIKit.lua", "Notice.lua", "Profiles.lua", "Slash.lua" })
Peon.db = PeonDB
local reported = {}
Peon.ReportCoreError = function(where, err) reported[#reported + 1] = where .. ": " .. tostring(err) end
local P = ns.Profiles
check(P and Peon.Profiles == P and Peon.API >= 26, "Profiles.lua geladen, Kern-API 26")
local toc = io.open("Peon/Peon.toc"):read("*a")
check(toc:find("## SavedVariablesPerCharacter: PeonCharDB", 1, true), "PeonCharDB je Charakter in der TOC")
check(toc:find("Comm.lua\r?\nProfiles.lua\r?\nSlash.lua"), "Profiles.lua in der TOC nach Comm und vor Slash")
P.Init()
check(type(PeonCharDB) == "table" and P.Current() == "Standard", "ohne Wahl: Standard")
check(PeonDB.profileList.Standard and PeonDB.profileList.Alt and PeonDB.profiles == nil, "Staende aus 0.25.0 werden zu Profilen, ungueltige weg")
check(PeonDB.profileUsers["Arnulf Stein-Forever"] == "Standard", "Charakter mit Profil gemerkt")

-- Module: A mit Charakterwert und keepOnReset, B ohne Profil, C ohne Charakterfach
TestADB, TestACharDB = { size = 12, pos = { x = 5 }, data = { 1, 2 } }, {}
local A = Peon:NewModule("Peon_TestA", {
  key = "testa", title = "Test A", db = "TestADB", charDB = "TestACharDB", charKeys = { mode = true },
  defaults = { size = 10, color = { 1, 0, 0 }, mode = "normal", corner = "TOPLEFT", pos = { x = 0 } },
  ranges = { size = { 1, 50, 1 } }, choices = { corner = { TOPLEFT = true, TOPRIGHT = true } }, keepOnReset = { pos = true },
})
local resets = 0
A:On("RESET", function() resets = resets + 1 end)
TestBDB = { on = false }
local B = Peon:NewModule("Peon_TestB", { key = "testb", db = "TestBDB", defaults = { on = true }, noProfile = true })
TestCDB = {}
local C = Peon:NewModule("Peon_TestC", { key = "testc", db = "TestCDB", defaults = { level = 3 } })
A:_Init(); B:_Init(); C:_Init()
check(TestADB._profile == "Standard" and A.db.size == 12 and TestADB.size == 12, "bisherige Einstellungen sind Standard, liegen weiter direkt in der Tabelle")
check(TestADB._profiles.Alt.size == 5 and TestCDB._profiles.Alt == nil, "Stand aus 0.25.0 beim Modul angekommen")
check(TestBDB._profile == nil and TestBDB._profiles == nil and B.db.on == false, "noProfile: nichts angefasst")
local keys = table.concat(A:_ProfileKeys(), ",")
check(keys == "color,corner,size", "zum Profil gehoeren nicht pos (keepOnReset), mode (Charakter), debug: " .. keys)

-- Einloggen eines Charakters nachspielen: gleiche Konto-Tabellen, eigenes Charakterfach
local function Login(name, charProfile, charA)
  CHAR = name
  PeonCharDB = charProfile and { profile = charProfile } or {}
  TestACharDB = charA or {}
  P.Init()
  for _, m in ipairs({ A, B, C }) do m.initialized = false; m:_Init() end
end

-- Arnulf: neues Profil als Kopie, eigene Werte
A.db.mode = "fishing"
local r0 = resets
local ok, n, name = P.Use("Hexer")
check(ok and name == "Hexer" and n == 2 and PeonCharDB.profile == "Hexer", "Benutzen legt ein fehlendes Profil als Kopie an und wechselt: " .. tostring(n))
check(A.db.size == 12 and TestADB._profile == "Hexer" and TestADB._profiles.Standard.size == 12 and TestADB._profiles.Hexer == nil, "Kopie: gleiche Werte, Standard abgelegt, aktives liegt direkt in der Tabelle")
check(resets == r0 + 1, "RESET nach dem Wechsel")
A.db.size, A.db.corner, C.db.level = 30, "TOPRIGHT", 9
local arnulfChar = TestACharDB

-- Borin loggt ein: Standard
Login("Borin Stein", nil)
check(P.Current() == "Standard" and A.db.size == 12 and A.db.corner == "TOPLEFT" and C.db.level == 3, "anderer Charakter: Standard")
check(TestADB._profiles.Hexer.size == 30 and TestADB._profiles.Hexer.corner == "TOPRIGHT", "Hexer beim Wechsel abgelegt")
check(A.db.mode == "normal", "Charakterwert bleibt beim Charakter")
check(TestADB.pos.x == 5 and TestADB.data[2] == 2, "keepOnReset und Daten unberuehrt")
A.db.size = 14   -- Borin aendert Standard

-- Arnulf wieder: Hexer, Standard bleibt mit Borins Aenderung
Login("Arnulf Stein", "Hexer", arnulfChar)
check(A.db.size == 30 and A.db.mode == "fishing" and C.db.level == 9, "Arnulf bekommt sein Profil zurueck")
check(TestADB._profiles.Standard.size == 14, "Aenderung an Standard bleibt fuer alle")
local list = P.List()
check(list[1].name == "Standard" and list[1].users == 1, "Liste: Standard zuerst, ein Charakter")
local hex
for _, p in ipairs(list) do if p.name == "Hexer" then hex = p end end
check(hex and hex.current and hex.users == 1, "Liste: Hexer ist das Profil dieses Charakters")

-- Leeres Profil, Kopieren von, ungueltige Werte, fehlendes Modul
check(P.Create("Leer", true) and P.Use("leer"), "neues leeres Profil, Name ohne Gross- und Kleinschreibung")
check(A.db.size == 10 and A.db.corner == "TOPLEFT" and C.db.level == 3, "leer: Standardwerte")
local okL, mods, vals = P.Load("hexer")
check(okL and mods == 2 and A.db.size == 30 and TestADB._profiles.Hexer.size == 30, "Kopieren von Hexer ins aktuelle Profil: " .. tostring(mods) .. "/" .. tostring(vals))
TestADB._profiles.Hexer = { size = 999, corner = "MITTE", fremd = 1 }
P.Use("Hexer")
check(A.db.size == 50 and A.db.corner == "TOPLEFT" and A.db.fremd == nil, "ungueltige Werte beim Wechsel: begrenzt oder Standardwert")
TestCDB._profiles.Leer = nil
P.Use("Leer")
check(C.db.level == TestCDB._profiles.Standard.level, "fehlt ein Profil beim Modul, gilt eine Kopie von Standard")

-- Speichern ohne Wechsel (API 25)
local okS = P.Save("Abend")
check(okS and P.Current() == "Leer" and TestADB._profiles.Abend.size == A.db.size, "Speichern legt die jetzigen Werte unter einem Namen ab, ohne zu wechseln")

-- Loeschen
check(not P.Delete("Standard"), "Standard laesst sich nicht loeschen")
check(P.Delete("Leer") and P.Current() == "Standard" and TestADB._profile == "Standard" and TestADB._profiles.Leer == nil, "aktives Profil geloescht: zurueck zu Standard")
check(PeonDB.profileUsers["Arnulf Stein-Forever"] == "Standard", "Anzeige der Charaktere angepasst")
P.Delete("Hexer")
Login("Arnulf Stein", "Hexer", arnulfChar)
check(P.Current() == "Standard" and A.db.size == 14, "Profil des Charakters geloescht: Standard")
-- Ein Modul, das zuletzt ein inzwischen geloeschtes Profil aktiv hatte
TestADB._profile = "Weg"
TestADB._profiles.Standard = { size = 21 }
Login("Borin Stein", nil)
check(TestADB._profile == "Standard" and A.db.size == 21, "zuletzt aktives Profil geloescht: Standard eingesetzt")

-- Fehlerfaelle und Grenze
check(select(2, P.Create("")) == "name" and select(2, P.Create(string.rep("x", 41))) == "name", "Name leer oder zu lang")
check(select(2, P.Create("abend")) == "exists", "Name schon vergeben")
for i = 1, P.MAX do P.Create("P" .. i) end
check(select(2, P.Create("Zuviel")) == "full", "hoechstens " .. P.MAX .. " Profile")
check(P.CleanName("  Hexer |cffff0000rot|r ") == "Hexer rot", "Farbcodes und Leerzeichen entfernt")

-- Befehle
out = {}
SlashCmdList.PEON("profil benutzen Nacht Profil")
check(P.Current() == "Standard" and out[#out]:find("Es gibt schon", 1, true), "voll: kein neues Profil")
P.Delete("P1")
SlashCmdList.PEON("profil benutzen Nacht Profil")
check(P.Current() == "Nacht Profil" and out[#out]:find("nutzt jetzt", 1, true), "/peon profil benutzen")
combat = true
SlashCmdList.PEON("profil standard")
check(P.Current() == "Nacht Profil" and out[#out]:find("Kampf", 1, true), "im Kampf kein Wechsel")
combat = false
SlashCmdList.PEON("profil standard")
check(P.Current() == "Standard", "/peon profil standard")
SlashCmdList.PEON("profil loeschen Standard")
check(out[#out]:find("nicht löschen", 1, true), "Standard bleibt")
out = {}
SlashCmdList.PEON("profil")
local all = table.concat(out, "\n")
check(all:find("Dieser Charakter nutzt: Standard", 1, true) and all:find("Nacht Profil (0 Charaktere)", 1, true) and all:find("/peon profil benutzen", 1, true), "Stand, Liste und Hilfe")
out = {}
SlashCmdList.PEON("hilfe")
check(table.concat(out, "\n"):find("/peon profil", 1, true), "Hilfe von /peon nennt die Profile")

-- Optionsseite
local panel = P.CreatePanel()
check(panel and panel.name == "Profile" and P.option.use and P.option.empty and P.option.copy and P.option.delete and P.option.default, "Seite Profile mit allen Knoepfen")
panel.scripts.OnShow()
check(P.option.status.txt == "Dieser Charakter nutzt: Standard" and P.option.list.txt:find("< dieser Charakter", 1, true), "Stand und Liste auf der Seite")
P.Delete("P2")   -- Platz fuer ein neues Profil
P.option.box:SetText("Seite")
P.option.empty.scripts.OnClick()
check(P.Current() == "Seite" and A.db.size == 10, "Knopf Neu, leer")
P.option.default.scripts.OnClick()
check(P.Current() == "Standard", "Knopf Zurueck zu Standard")
P.option.delete.scripts.OnClick()
check(not P.Find("Seite"), "Knopf Loeschen")
check(#reported == 0, "keine Fehler: " .. table.concat(reported, " | "))

print("ALLE TESTS OK")
