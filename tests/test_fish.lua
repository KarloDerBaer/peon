-- Stub-Test fuer Peon + Peon_Fishing mit echten SavedVariables
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
-- Alles Unbekannte ist ein "Any": aufrufbar, indizierbar, liefert wieder Any
local Any
local anyMT = {}
anyMT.__index = function(t, k) if k == "GetHeight" or k == "GetWidth" or k == "GetStringHeight" then return function() return 20 end end return Any end
anyMT.__call = function() return Any end
anyMT.__newindex = function() end
anyMT.__concat = function(a, b) return tostring(a == Any and "" or a) .. tostring(b == Any and "" or b) end
Any = setmetatable({}, anyMT)
local frames = {}
local function Frame()
  local f = { ev = {}, scripts = {}, h = 20 }
  return setmetatable(f, { __index = function(t, k)
    if k == "RegisterEvent" or k == "RegisterUnitEvent" then return function(s, e) s.ev[e] = true end end
    if k == "UnregisterEvent" then return function(s, e) s.ev[e] = nil end end
    if k == "SetScript" or k == "HookScript" then return function(s, n, fn) s.scripts[n] = fn end end
    if k == "GetHeight" or k == "GetWidth" or k == "GetStringHeight" then return function(s) return s.h end end
    if k == "SetHeight" then return function(s, h) s.h = h end end
    if k == "SetSize" then return function(s, w, h) s.h = h end end
    if k == "CreateFontString" or k == "CreateTexture" or k == "CreateMaskTexture" then return function() return Frame() end end
    if k == "IsVisible" or k == "IsShown" then return function() return false end end
    if k == "Low" or k == "High" or k == "Text" or k == "text" or k == "name" or k == "parent" then return nil end
    return function() return nil end
  end })
end
function CreateFrame(kind, name) local f = Frame(); f.kind = kind; frames[#frames+1] = f; if name then _G[name] = f end return f end
setmetatable(_G, { __index = function(t, k) if type(k) == "string" and not k:match("DB$") and (k:match("^%u") or k:match("^C_")) then return Any end end })
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function tinsert(t, v) t[#t+1] = v end
function GetLocale() return "deDE" end
function GetTime() return 1 end
date = os.date
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
function hooksecurefunc() end
local bindings = { NUMPAD0 = "PEON_FISHING_ACTION", PAD1 = "PEON_FISHING_ACTION", PAD4 = "PEON_FISHING_TOGGLE", NUMPADDECIMAL = "PEON_FISHING_TOGGLE", Q = "ACTIONBUTTON1" }
local saved = 0
function GetBindingKey(cmd) local r = {} for k, c in pairs(bindings) do if c == cmd then r[#r+1] = k end end table.sort(r) return unpack(r) end
function SetBinding(key, cmd) bindings[key] = cmd return true end
function SaveBindings() saved = saved + 1 end
function GetCurrentBindingSet() return 1 end
SlashCmdList = {}
C_Container = { GetContainerNumSlots = function() return 0 end }
NUM_BAG_SLOTS = 4
StaticPopupDialogs = {}
UISpecialFrames = {}
Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return 1 end }) end })
-- Metadaten (Version, Titel) direkt aus der TOC-Datei lesen, damit der Test immer die echte Version zeigt
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_Fishing = TocMeta("Peon_Fishing") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function() return false end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Fishing" })[i] end }
local cats = {}
Settings = { RegisterCanvasLayoutCategory = function(p, n) local c = { name = n, subs = {}, GetID = function() return n end } cats[n] = c return c end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) table.insert(par.subs, n) return { GetID = function() return par.name .. "/" .. n end } end,
  RegisterAddOnCategory = function(c) c.registered = true end,
  OpenToCategory = function(id) print("OPEN " .. id) end }
local function fire(e, ...) for _, f in ipairs(frames) do if f.ev[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end

-- Ausruestungssets nachgebaut (ab 1.5.2): merkt, welche Plaetze beim Speichern ignoriert waren
local eqIgnored, eqSets = {}, {}
local function CopySlots() local c = {} for s in pairs(eqIgnored) do c[s] = true end return c end
INVSLOT_MAINHAND, INVSLOT_OFFHAND = 16, 17
C_EquipmentSet = {
  GetEquipmentSetIDs = function() return {} end,
  GetItemIDs = function() return {} end,
  GetEquipmentSetID = function(name) return eqSets[name] and eqSets[name].id end,
  GetEquipmentSetInfo = function(id)
    for name, s in pairs(eqSets) do if s.id == id then return name, 1, id, false, 2, 0, 2, 0 end end
  end,
  GetIgnoredSlots = function(id) for _, s in pairs(eqSets) do if s.id == id then return s.ignored end end end,
  ClearIgnoredSlotsForSave = function() eqIgnored = {} end,
  IgnoreSlotForSave = function(slot) eqIgnored[slot] = true end,
  CreateEquipmentSet = function(name) local n = 0 for _ in pairs(eqSets) do n = n + 1 end eqSets[name] = { id = 100 + n, ignored = CopySlots() } end,
  SaveEquipmentSet = function(id) for _, s in pairs(eqSets) do if s.id == id then s.ignored = CopySlots() end end end,
  UseEquipmentSet = function() return true end,
}

load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
-- echte SavedVariables von KarloDerBaer
-- SavedVariables-Ordner des Accounts; Standard: vom AddOns-Ordner aus gesehen
-- ab 25.10.2026 feste Kopie der Beta-Einstellungen in tests/fixtures/wtf (run_tests setzt PEON_WTF)
local SV = os.getenv("PEON_WTF") or "../../WTF/Account/123456789#2"
assert(loadfile(SV .. "/SavedVariables/Peon_Fishing.lua"))()
assert(loadfile(SV .. "/70/Mirel-Dorna/SavedVariables/Peon_Fishing.lua"))()
PeonFishingDB.lure = 6529   -- gewaehlter Koeder
PeonFishingDB.soundDelay = 99   -- ausserhalb des Bereichs (wird geklemmt)
local ns = load("Peon_Fishing", "Peon_Fishing")
fire("ADDON_LOADED", "Peon_Fishing")
local mod = ns.mod
check(mod.initialized, "Modul initialisiert")
check(type(PeonFishingDB.catches) == "table" and type(PeonFishingCharDB) == "table", "SavedVariables geladen")
check(PeonFishingDB.lure == 6529, "Koeder-ID bleibt erhalten")
check(type(PeonFishingDB.interactRange) == "number" and (PeonFishingDB.clickMode == "double" or PeonFishingDB.clickMode == "off"), "Einstellungen gueltig")
check(type(PeonFishingDB.catches.zones) == "table", "Fangdatenbank vorhanden")
check(mod.db.fishingSetID == PeonFishingCharDB.fishingSetID and PeonFishingDB.fishingSetID == nil, "Charakterwerte aus PeonFishingCharDB")
check(PeonFishingDB.dbVersion == 3, "Standardwerte ergaenzt")
check(mod.panel ~= nil, "Optionsseite angemeldet")
fire("PLAYER_LOGIN")
check(saved == 0 and bindings.NUMPAD0 == "PEON_FISHING_ACTION", "Tastenbelegungen unveraendert")
check(cats.Peon.subs[1] == "Fishing", "Seite unter Peon > Fishing")
check(_G.SLASH_PEON_FISHING1 == "/fp" and rawget(_G, "SLASH_PEON_FISHING2") == nil, "Slash /fp")
check(PeonFishingDB.buttonPos == nil and PeonFishingCharDB.migrated == nil and PeonFishingDB.dbVersion == 3, "alte Schluessel entfernt")
SlashCmdList.PEON_FISHING("")
check(out[#out] == "OPEN Peon/Fishing", "/fp oeffnet Optionen")
SlashCmdList.PEON("fishing kampf fragen")
check(PeonFishingDB.afterCombat == "ask", "/peon fishing kampf fragen")
SlashCmdList.PEON_FISHING("debug")
check(PeonFishingDB.debug == true and type(PeonFishingDB.debugLog) == "table", "/fp debug -> PeonFishingDB.debugLog")
ns.Dbg("Testzeile")
check(PeonFishingDB.debugLog[#PeonFishingDB.debugLog]:find("Testzeile"), "ns.Dbg schreibt Log")
SlashCmdList.PEON_FISHING("hilfe")
check(type(PeonFishing_Toggle) == "function" and type(PeonFishing_Action) == "function", "Bindungsfunktionen global")

-- Optionsseite mit Kern-Bausteinen (ab 1.4.0)
check(Peon.API >= 6, "Kern-API 6")
check(PeonFishingDB.soundDelay == 15, "Nachlaufzeit auf Bereich geklemmt")
local page = ns.page
check(page and page.resetButton and #page.columns == 2, "Seite mit zwei Spalten und Standardwerte-Knopf")
page.panel.scripts.OnShow(page.panel)
check(true, "Seite anzeigen (Refresh + Neuanordnung) ohne Fehler")
local modeCalls = 0
table.insert(ns.onModeChanged, function() modeCalls = modeCalls + 1 end)
local checks = {}
for _, f in ipairs(frames) do if f.kind == "CheckButton" then checks[#checks + 1] = f end end
check(#checks == 11, "11 Haekchen (" .. #checks .. ")")
PeonFishingDB.clickMode = "double"
checks[1].GetChecked = function() return false end
checks[1].scripts.OnClick(checks[1])
check(PeonFishingDB.clickMode == "off" and modeCalls == 1, "Doppelklick-Haekchen schreibt \"off\" und meldet Aenderung")
checks[1].GetChecked = function() return true end
checks[1].scripts.OnClick(checks[1])
check(PeonFishingDB.clickMode == "double", "Doppelklick-Haekchen schreibt \"double\"")
local played
local oldPlay = ns.PlayLostSound
ns.PlayLostSound = function(k) played = k end
local function DD(key) for _, c in ipairs(page.controls) do if c.key == key then return c end end end
check(DD("lostSound") and DD("bobberMarker") and DD("afterCombat") and DD("fishingSet"), "Auswahllisten fuer Warnton, Markierung, Kampf, Angel-Set")
DD("lostSound").Select("alarm")
check(PeonFishingDB.lostSound == "alarm" and played == "alarm", "Warnton waehlen spielt Hoerprobe")
DD("afterCombat").Select("leave")
check(PeonFishingDB.afterCombat == "leave", "Auswahlliste nach dem Kampf")
local chosen
local oldChoose = ns.ChooseFishingSet
ns.ChooseFishingSet = function(n) chosen = n end
DD("fishingSet").Select("Angeln")
check(chosen == "Angeln", "Angel-Set-Auswahl ruft ChooseFishingSet")
ns.ChooseFishingSet = oldChoose
ns.PlayLostSound = oldPlay
local setID, catches = mod.db.fishingSetID, PeonFishingDB.catches
PeonFishingDB.soundMusic, PeonFishingDB.lure, PeonFishingCharDB.pending = 55, 6529, "leave"
page.resetButton.scripts.OnClick(page.resetButton)
check(PeonFishingDB.soundMusic == 0 and PeonFishingDB.lostSound == "raid", "Standardwerte gesetzt")
check(PeonFishingCharDB.pending == "leave" and mod.db.fishingSetID == setID and PeonFishingDB.lure == 6529
    and PeonFishingDB.catches == catches, "Zustand, Angel-Set, Koeder und Faenge bleiben erhalten")
PeonFishingCharDB.pending = ""
-- 1.5.2 (Feedback): neues Angel-Set nur mit Haupt- und Nebenhand, mit Hinweis
StaticPopupDialogs.PEON_FISHING_CONFIRM_SAVE.OnAccept(nil, "Probe-Set")
local probe = eqSets["Probe-Set"]
local slotsOff, weaponsOff = 0, false
for slot = 1, 19 do
  if probe and probe.ignored[slot] then
    slotsOff = slotsOff + 1
    if slot == 16 or slot == 17 then weaponsOff = true end
  end
end
check(probe and slotsOff == 17 and not weaponsOff and mod.db.fishingSetID == probe.id, "neues Angel-Set ignoriert alle Plaetze ausser Haupt- und Nebenhand")
local hinted = false
for _, l in ipairs(out) do if l:find("Anglerhut", 1, true) then hinted = true end end
check(hinted, "Hinweis auf weitere Angelausruestung")
-- aktiv geschalteter Platz (Kopf) bleibt beim erneuten Speichern aktiv, ignorierte bleiben ignoriert
probe.ignored[1] = nil
StaticPopupDialogs.PEON_FISHING_CONFIRM_SAVE.OnAccept(nil, "Probe-Set")
check(eqSets["Probe-Set"].ignored[1] == nil and eqSets["Probe-Set"].ignored[5] == true, "Set erneut speichern behaelt die Auswahl der Plaetze")
-- das Rueckkehr-Set bleibt vollstaendig
ns.Enter()
local ret = eqSets[PeonFishingDB.returnSetName or mod.db.returnSetName]
check(ret and next(ret.ignored) == nil, "Rueckkehr-Set ignoriert keinen Platz")
-- Starter fuer Peon_Panel (ab 1.6)
do
  local s = mod.launcher
  check(s and s.showKey == "showMinimap" and s.defaultText == "mode", "1.6: Starter neben dem eigenen Button")
  local keepMode = mod.db.mode
  mod.db.mode = "fishing"
  check(s:GetText("mode") == "An", "1.6: Text Angelmodus an: " .. tostring(s:GetText("mode")))
  mod.db.mode = "normal"
  check(s:GetText("mode") == "Aus", "1.6: Text Angelmodus aus: " .. tostring(s:GetText("mode")))
  mod.db.mode = "fishing"
  check(type(s:GetText("lure")) == "string", "1.6: Text Koeder: " .. tostring(s:GetText("lure")))
  local lines = {}
  s:FillTooltip({ AddLine = function(_, t) lines[#lines + 1] = t end })
  check(#lines == 2, "1.6: Tooltip mit Zustand und Angel-Set")
  local items = 0
  local root = {}
  function root.CreateTitle() items = items + 1 end
  function root.CreateDivider() items = items + 1 end
  function root.CreateButton() items = items + 1 end
  function root.CreateRadio() items = items + 1 end
  s:FillMenu(root)
  check(items >= 4, "1.6: Menue mit Koeder und Optionen")
  local tex = { SetDesaturated = function(t, v) t.grey = v end, SetVertexColor = function() end }
  s:ColorIcon(tex)
  check(tex.grey == false, "1.6: Symbol im Angelmodus farbig")
  mod.db.mode = "normal"
  s:ColorIcon(tex)
  check(tex.grey == true, "1.6: Symbol sonst grau")
  mod.db.mode = keepMode
end
local n = 0 for _, l in ipairs(out) do if l:find("Fehler in") then n = n + 1; io.write("!! ", l, "\n") end end
check(n == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
