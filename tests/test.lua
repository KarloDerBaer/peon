-- Minimaler WoW-Stub, um den Peon-Kern ausserhalb des Spiels durchzuspielen
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
function GetTime() return 123.456 end
date = os.date
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
SlashCmdList = {}
local meta = { Peon = { Version = "0.1.0", Title = "Peon" }, Peon_Test = { Version = "9.9", Title = "Test" }, Peon_Off = { Version = "1.0", Title = "Aus" } }
C_AddOns = {
  GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function() return true end,
  GetNumAddOns = function() return 3 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Test", "Peon_Off" })[i] end,
}
local frames = {}
local function newObj()
  local o = {}
  return setmetatable(o, { __index = function(t, k) if k:match("^%u") then return function() return o end end end })
end
function CreateFrame()
  local f = newObj()
  local ev, script = {}, nil
  rawset(f, "RegisterEvent", function(_, e) ev[e] = true end)
  rawset(f, "SetScript", function(_, s, fn) if s == "OnEvent" then script = fn else rawset(f, "_" .. s, fn) end end)
  rawset(f, "CreateFontString", function() local fs = newObj(); rawset(fs, "SetText", function(_, t) rawset(fs, "text", t) end); return fs end)
  rawset(f, "_fire", function(e, ...) if ev[e] and script then script(f, e, ...) end end)
  frames[#frames+1] = f
  return f
end
local cats = {}
Settings = {
  RegisterCanvasLayoutCategory = function(p, n) local c = { name = n, subs = {}, GetID = function() return n end } cats[n] = c return c end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) local c = { name = n, GetID = function() return par.name .. "/" .. n end } table.insert(par.subs, n) return c end,
  RegisterAddOnCategory = function(c) c.registered = true end,
  OpenToCategory = function(id) print("OPEN " .. tostring(id)) end,
}
local function fire(e, ...) for _, f in ipairs(frames) do f._fire(e, ...) end end
local function load(dir, addon, files)
  local ns = {}
  for _, f in ipairs(files) do assert(loadfile(dir .. "/" .. f))(addon, ns) end
  return ns
end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end

-- Kern laden
load("Peon", "Peon", { "Locales.lua", "Core.lua", "Module.lua", "Options.lua", "Slash.lua" })
fire("ADDON_LOADED", "Peon")
check(type(Peon) == "table" and Peon.version == "0.1.0", "Peon global + Version")
check(PeonDB ~= nil, "PeonDB angelegt")

-- Testmodul mit vorhandenen SavedVariables (Account + Charakter)
TestDB = { fishingSetID = 3, offsetX = 999, corner = "QUATSCH", lure = 6529 }
TestCharDB = nil
local log = {}
local mod = Peon:NewModule("Peon_Test", {
  key = "test", title = "Test", db = "TestDB", charDB = "TestCharDB",
  charKeys = { fishingSetID = true, mode = true },
  defaults = { fishingSetID = -1, mode = "normal", offsetX = 20, corner = "TOPLEFT", lure = "none", list = { 1, 2 } },
  ranges = { offsetX = { -200, 200, 1 } },
  choices = { corner = { TOPLEFT = true, TOPRIGHT = true } },
  validate = { lure = function(v) return v == "auto" or v == "none" or type(v) == "number" end },
  migrate = function(m, acc, char)
    if acc.fishingSetID ~= nil and char.fishingSetID == nil then char.fishingSetID = acc.fishingSetID end
  end,
  slash = { "/tst" },
  onSlash = function(m, cmd, rest) log[#log+1] = cmd .. "|" .. rest end,
})
mod:On("INIT", function() log[#log+1] = "INIT" end)
mod:On("LOGIN", function() log[#log+1] = "LOGIN" end)
mod:On("COMBAT_END", function() log[#log+1] = "CEND" end)
mod:RegisterEvent("BAG_UPDATE", function(e, bag) log[#log+1] = e .. bag end)
mod:On("BOOM", function() error("absichtlich") end)
local panel = CreateFrame("Frame")
mod:RegisterOptions(panel)

fire("ADDON_LOADED", "Peon_Test")
check(log[1] == "INIT", "INIT nach ADDON_LOADED")
check(TestCharDB.fishingSetID == 3 and TestDB.fishingSetID == nil, "Migration acc -> char, acc bereinigt")
check(mod.db.fishingSetID == 3, "Sicht liest char")
mod.db.mode = "fishing"
check(TestCharDB.mode == "fishing" and TestDB.mode == nil, "Sicht schreibt char")
mod.db.offsetX = 50
check(TestDB.offsetX == 50, "Sicht schreibt acc")
check(TestDB.corner == "TOPLEFT", "ungueltige Auswahl -> Standard")
check(TestDB.lure == 6529, "validate: Zahl bleibt erhalten")
check(mod.db.debug == false, "debug-Standard ergaenzt")
check(type(TestDB.list) == "table" and TestDB.list ~= mod.opts.defaults.list, "Tabellen-Standard kopiert")

-- Clamp beim Laden
TestDB2 = { x = 999 }
local m2 = Peon:NewModule("Peon_Two", { db = "TestDB2", defaults = { x = 1 }, ranges = { x = { 0, 100, 5 } } })
fire("ADDON_LOADED", "Peon_Two")
check(TestDB2.x == 100, "Clamp auf Bereich")
check(m2.key == "two", "Schluessel aus Addon-Namen")

fire("PLAYER_LOGIN")
check(log[2] == "LOGIN", "LOGIN")
check(cats.Peon.registered and cats.Peon.subs[1] == "Test", "Kategorie Peon + Unterseite Test")
fire("PLAYER_REGEN_ENABLED"); check(log[3] == "CEND", "COMBAT_END")
fire("BAG_UPDATE", 2); check(log[4] == "BAG_UPDATE2", "WoW-Ereignis weitergereicht")
mod:Fire("BOOM"); mod:Fire("BOOM")
local n = 0 for _, l in ipairs(out) do if l:find("Fehler in BOOM", 1, true) then n = n + 1 end end
check(n == 1, "Fehler nur einmal gemeldet")
check(PeonDB.errors[1].msg:find("absichtlich", 1, true) and PeonDB.errors[1].n == 2, "Fehlertext im Fehlerspeicher, zweimal gezaehlt")

-- Debug
mod:Dbg("still")
check(TestDB.debugLog == nil, "kein Log ohne Debug")
SlashCmdList.PEON("debug test")
mod:Dbg("hallo")
check(TestDB.debugLog and #TestDB.debugLog == 2 and TestDB.debugLog[2]:find("hallo"), "Debug-Log geschrieben")
for i = 1, 2100 do mod:Dbg("z" .. i) end
check(#TestDB.debugLog <= 2000, "Log begrenzt (" .. #TestDB.debugLog .. ")")
SlashCmdList.PEON("debug test")
check(mod.db.debug == false, "Debug aus")

-- Slash
SlashCmdList.PEON("test foo bar baz"); check(log[5] == "foo|bar baz", "/peon test weitergereicht")
SlashCmdList.PEON_TEST("Abc x"); check(log[6] == "abc|x", "/tst eigener Befehl")
SlashCmdList.PEON("list")
SlashCmdList.PEON("gibtsnicht")
SlashCmdList.PEON("")
mod:OpenOptions()
check(out[#out] == "OPEN Peon/Test", "Modul-Optionen oeffnen")

-- Reset
mod:ResetDefaults({ fishingSetID = true })
check(mod.db.offsetX == 20 and mod.db.fishingSetID == 3, "Reset mit Ausnahme")

-- spaet angemeldete Seite
local late = Peon:NewModule("Peon_Late", {})
fire("ADDON_LOADED", "Peon_Late")
late:RegisterOptions(CreateFrame("Frame"))
check(late.category and late.category.name == "Peon_Late", "nach Login: eigener Eintrag")
local got
late:On("LOGIN", function() got = true end)
check(got, "LOGIN nachgeholt fuer spaete Anmeldung")
-- keepOnReset (API 5): bleibt bei ResetDefaults() ohne Ausnahmeliste erhalten
local keep = Peon:NewModule("Peon_Keep", { db = "PeonKeepDB", defaults = { a = 1, b = 2 }, keepOnReset = { b = true } })
fire("ADDON_LOADED", "Peon_Keep")
keep.db.a, keep.db.b = 5, 6
keep:ResetDefaults()
check(keep.db.a == 1 and keep.db.b == 6, "keepOnReset")
-- ===== Fehlerspeicher (API 12) =====
do
  check(Peon.API >= 12, "API 12")
  local clock = 1000
  time = function() return clock end
  GetBuildInfo = function() return "1.15", "60000" end
  PeonDB.errors = nil
  local before = #out
  mod.reported = {}
  mod:ReportError("Teil", "kaputt.lua:1: Fehler")
  clock = 1100
  mod:ReportError("Teil", "kaputt.lua:1: Fehler")
  local chatLines, chatLast = #out - before, out[#out]
  local e = PeonDB.errors[1]
  check(#PeonDB.errors == 1 and e.n == 2 and e.first == 1000 and e.last == 1100, "gleicher Fehler zaehlt hoch")
  check(e.addon == "Peon_Test" and e.where == "Teil" and e.version == "9.9" and e.build == "60000", "Addon, Bereich, Version, Build")
  check(chatLines == 1 and chatLast:find("Fehler in Teil", 1, true) and not chatLast:find("kaputt", 1, true), "Chat: nur einmal, kurzer Hinweis")

  local isSecret = Peon.IsSecret
  Peon.IsSecret = function(v) return v == "GEHEIMWERT" end
  mod:ReportError("Geheim", "GEHEIMWERT")
  Peon.IsSecret = isSecret
  check(PeonDB.errors[2].msg == "<geheim>", "geheimer Fehlertext wird nicht ausgewertet")

  Peon.RecordError("Peon_Test", "Lang", ("x"):rep(5000))
  check(#PeonDB.errors[3].msg == 1000, "Text wird gekuerzt")
  for i = 1, 120 do Peon.RecordError("Peon_Test", "Viele" .. i, "f") end
  check(#PeonDB.errors == 100 and PeonDB.errors[100].where == "Viele120", "hoechstens 100, aelteste fallen weg")

  PeonDB.errors = { { addon = "A", where = "alt", msg = "m", last = 500, n = 1 }, { addon = "A", where = "neu", msg = "m", last = 900, n = 3 } }
  check(Peon.ClearErrors(500) == 1 and #PeonDB.errors == 1 and PeonDB.errors[1].where == "neu", "ClearErrors bis Zeitpunkt, neuere bleiben")
  SlashCmdList.PEON("fehler")
  check(out[#out]:find("neu (3x): m", 1, true), "/peon fehler zeigt den Text")
  SlashCmdList.PEON("fehler leeren")
  check(#PeonDB.errors == 0 and out[#out]:find("1 gespeicherte", 1, true), "/peon fehler leeren")
  SlashCmdList.PEON("fehler")
  check(out[#out]:find("Keine gespeicherten", 1, true), "/peon fehler ohne Eintraege")
  PeonDB.errors = "kaputt"
  Peon.RecordError("A", "B", "C")
  check(type(PeonDB.errors) == "table" and #PeonDB.errors == 1, "kaputter Speicher wird neu angelegt")
  PeonDB.errors = nil
  check(Peon.ClearErrors() == 0, "ClearErrors ohne Speicher")
  time, GetBuildInfo = nil, nil
end

print("ALLE TESTS OK")
