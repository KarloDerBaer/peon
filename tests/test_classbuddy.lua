-- Stub-Test fuer Peon + Peon_ClassBuddy: Combo-Punkte (Schurke), Seelensplitter (Hexenmeister), Optionen, Uebernahme
-- Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
function GetTime() return 1 end
function GetBuildInfo() return "1.60.1", "70938" end
date = os.date
time = os.time
local combat = false
function InCombatLockdown() return combat end
function UnitAffectingCombat() return combat end
SlashCmdList = {}
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_ClassBuddy = TocMeta("Peon_ClassBuddy") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function(a) return a == "Peon" or a == "Peon_ClassBuddy" end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_ClassBuddy" })[i] end }
Enum = { PowerType = { ComboPoints = 4 } }
local allFrames = {}
local function W()
  local o = { scripts = {}, w = 0, h = 0, shown = true, events = {}, unitev = {}, points = {} }
  local m = {}
  function m.SetSize(s, w, h) s.w, s.h = w, h end
  function m.SetHeight(s, h) s.h = h end
  function m.SetWidth(s, w) s.w = w end
  function m.GetHeight(s) return s.h end
  function m.GetWidth(s) return s.w end
  function m.GetStringHeight() return 12 end
  function m.SetScript(s, n, f) s.scripts[n] = f end
  function m.GetScript(s, n) return s.scripts[n] end
  function m.HookScript(s, n, f) s.scripts[n] = f end
  function m.SetText(s, t) s.text = t end
  function m.GetText(s) return s.text end
  function m.SetChecked(s, v) s.checked = v end
  function m.GetChecked(s) return s.checked end
  function m.SetValue(s, v) s.value = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end
  function m.IsShown(s) return s.shown end
  function m.Show(s) s.shown = true end
  function m.Hide(s) s.shown = false end
  function m.SetShown(s, v) s.shown = v and true or false end
  function m.SetAlpha(s, a) s.alpha = a end
  function m.SetColorTexture(s, ...) s.color = { ... } end
  function m.SetStatusBarColor(s, ...) s.color = { ... } end
  function m.SetPoint(s, ...) s.points[#s.points+1] = { ... } end
  function m.ClearAllPoints(s) s.points = {} end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.RegisterUnitEvent(s, e) s.unitev[e] = true end
  function m.UnregisterAllEvents(s) s.events = {}; s.unitev = {} end
  function m.GetThumbTexture() return true end
  function m.CreateFontString() return W() end
  function m.CreateTexture() return W() end
  function m.CreateMaskTexture() return W() end
  function m.GetStatusBarTexture() return W() end
  function m.Click(s) if s.scripts.OnClick then s.scripts.OnClick(s, "LeftButton") end end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" then return function() end end end })
end
function CreateFrame(kind, name) local f = W(); f.kind = kind; f.name = name; allFrames[#allFrames+1] = f; if name then _G[name] = f end; return f end
UIParent = W()
local cats = {}
Settings = { RegisterCanvasLayoutCategory = function(p, n) local c = { name = n, subs = {}, GetID = function() return n end } cats[n] = c return c end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) table.insert(par.subs, n) return { GetID = function() return par.name .. "/" .. n end } end,
  RegisterAddOnCategory = function(c) c.registered = true end,
  OpenToCategory = function(id) print("OPEN " .. id) end }
ColorPickerFrame = { SetupColorPickerAndShow = function() end, GetColorRGB = function() return 0.1, 0.2, 0.3 end, GetColorAlpha = function() return 0.5 end }
local CLASS = "WARLOCK"
function UnitClass() return "x", CLASS end
function UnitPowerMax() return 5 end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers+1] = fn end, NewTicker = function() end }

-- Taschen: bags[bag] = { family = n, slots = { [slot] = itemID }, locked = { [slot] = true } }, je 4 Plaetze
local SHARD = 6265
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5   -- wie in Forever: Taschen 0 bis 5
local bags = {}
local cursor
local deleteAllowed = true
local deleted = 0
local targeting = false
C_Container = {
  GetContainerNumSlots = function(b) return bags[b] and 4 or 0 end,
  GetContainerNumFreeSlots = function(b)
    if not bags[b] then return 0, 0 end
    local free = 0 for s = 1, 4 do if not bags[b].slots[s] then free = free + 1 end end
    return free, bags[b].family or 0
  end,
  GetContainerItemID = function(b, s) return bags[b] and bags[b].slots[s] or nil end,
  GetContainerItemInfo = function(b, s) local id = bags[b] and bags[b].slots[s]; if not id then return nil end
    return { itemID = id, isLocked = (bags[b].locked and bags[b].locked[s]) or false } end,
  PickupContainerItem = function(b, s)
    local id = bags[b] and bags[b].slots[s]
    if not id then return end
    cursor = { b, s, id }
    bags[b].slots[s] = nil
  end,
}
function GetCursorInfo() if cursor then return "item", cursor[3] end end
function CursorHasItem() return cursor ~= nil end
function ClearCursor() if cursor then bags[cursor[1]].slots[cursor[2]] = cursor[3]; cursor = nil end end
function DeleteCursorItem() if deleteAllowed and cursor then deleted = deleted + 1; cursor = nil end end
function SpellIsTargeting() return targeting end
local hooks = {}
function hooksecurefunc(name, fn) if type(name) ~= "string" then return end local orig = _G[name]; _G[name] = function(...) local r = orig(...); fn(...); return r end; hooks[name] = true end
function UseAction() end
local macros, pickedMacro = {}, nil
function GetMacroIndexByName(n) for i, m in ipairs(macros) do if m.name == n then return i end end return 0 end
function CreateMacro(n, icon, body, perChar) macros[#macros+1] = { name = n, body = body, perChar = perChar } return #macros end
function PickupMacro(i) pickedMacro = i end

local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end
local function lastMsg() for i = #out, 1, -1 do if not out[i]:match("^ok  ") then return out[i] end end return "" end
local function okCount() local n = 0 for _, l in ipairs(out) do if not l:match("^ok  ") then n = n + 1 end end return n end
local function count() local n = 0 for _, b in pairs(bags) do for s = 1, 4 do if b.slots[s] == SHARD then n = n + 1 end end end return n end

-- ===== Laden (Hexenmeister, alte Werte aus 0.1.0 und von Peon_ComboPoints) =====
load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
PeonClassBuddyDB = { probe = { results = {} }, hideGuide = true, shardMax = 999, shardRule = "bag" }   -- Stand 0.2.0 mit altem Standard
local ns = load("Peon_ClassBuddy", "Peon_ClassBuddy")
fire("ADDON_LOADED", "Peon_ClassBuddy")
-- Peon_ComboPoints laedt alphabetisch danach: seine Werte sind erst beim Einloggen da
PeonComboPointsDB = { size = 22, gap = 99, fillColor = { 0.5, 0.5, 0.5 }, socketColor = { 2, 0, 0, 1 }, showSockets = false }
local mod = ns.mod
local S = ns.Shards
check(mod.initialized and mod.page, "Modul + Optionsseite")
check(PeonClassBuddyDB.probe == nil and PeonClassBuddyDB.hideGuide == nil, "Reste der Pruefung aus 0.1.0 entfernt")
check(PeonClassBuddyDB.shardMax == 60, "Hoechstzahl geklemmt")
check(PeonClassBuddyDB.shardRule == "free" and PeonClassBuddyDB.shardRule3 and PeonClassBuddyDB.shardOn and PeonClassBuddyDB.shardAction, "0.3.0: alter Standard wird einmal zu Seelentasche minus 1, mit Zaubern")
check(mod.page:GetTab() == "warlock", "Hexenmeister: Reiter Hexenmeister offen")
fire("PLAYER_LOGIN")
check(cats.Peon and cats.Peon.subs[1] == "Klassenbuddy", "Seite unter Peon > Klassenbuddy")

-- Uebernahme aus Peon_ComboPoints: gueltige Werte, ungueltige bleiben Standard, nur einmal
check(PeonClassBuddyDB.cpImported == true and PeonClassBuddyDB.size == 22 and PeonClassBuddyDB.showSockets == false, "Combo-Punkte: Einstellungen uebernommen")
check(PeonClassBuddyDB.gap == 16 and PeonClassBuddyDB.fillColor[1] == 0.5 and PeonClassBuddyDB.socketColor[1] == 0, "Bereich geklemmt, ungueltige Farbe bleibt Standard")
PeonComboPointsDB.size = 9
check(ns.ImportComboPoints() == false and PeonClassBuddyDB.size == 22, "Uebernahme nur einmal")
check(PeonClassBuddyDB.fillColor ~= PeonComboPointsDB.fillColor, "Farben kopiert, nicht geteilt")
check(S.IsActive() and hooks.UseAction, "Hexenmeister: Seelensplitter aktiv, Aktionstasten werden mitgelesen")
check(not ns.active, "Hexenmeister: keine Combo-Punkte")

-- ===== Seelensplitter: Regel Seelentasche voll =====
PeonClassBuddyDB.shardRule = "bag"
local function setBags(def) bags = def end
-- Seelentasche (Typ 4) noch nicht voll: nichts zu viel
setBags({ [0] = { family = 0, slots = { [1] = SHARD, [2] = 2589 } }, [5] = { family = 4, slots = { [1] = SHARD, [2] = SHARD, [3] = SHARD } } })
local list, total = S.Surplus()
check(total == 4 and #list == 0, "Seelentasche nicht voll: nichts zu viel")
-- Seelentasche voll: alle ausserhalb zu viel, von hinten
setBags({ [0] = { family = 0, slots = { [1] = SHARD, [2] = 2589, [4] = SHARD } }, [5] = { family = 4, slots = { SHARD, SHARD, SHARD, SHARD } } })
list, total = S.Surplus()
check(total == 6 and #list == 2 and list[1].bag == 0 and list[1].slot == 4 and list[2].slot == 1, "Seelentasche voll: Splitter ausserhalb zu viel, von hinten")
-- ohne Seelentasche gilt die Hoechstzahl
PeonClassBuddyDB.shardMax = 3
setBags({ [0] = { family = 0, slots = { SHARD, SHARD, SHARD, SHARD } }, [1] = { family = 0, slots = { [1] = SHARD } } })
list = S.Surplus()
check(#list == 2 and list[1].bag == 1, "ohne Seelentasche: Hoechstzahl")
-- Regel Hoechstzahl: erst ausserhalb, dann in der Seelentasche
PeonClassBuddyDB.shardRule = "max"
setBags({ [0] = { family = 0, slots = { [1] = SHARD } }, [5] = { family = 4, slots = { SHARD, SHARD, SHARD, SHARD } } })
list = S.Surplus()
check(#list == 2 and list[1].bag == 0 and list[2].bag == 5 and list[2].slot == 4, "Hoechstzahl: zuerst ausserhalb der Seelentasche")
-- Regel Seelentasche minus 1 (Standard ab 0.3.0): ein Platz der Seelentasche bleibt frei
PeonClassBuddyDB.shardRule = "free"
setBags({ [0] = { family = 0, slots = { [2] = 2589 } }, [5] = { family = 4, slots = { SHARD, SHARD, SHARD } } })
list = S.Surplus()
check(#list == 0, "Seelentasche minus 1: 3 von 4 Plaetzen belegt, nichts zu viel")
setBags({ [0] = { family = 0, slots = { [2] = 2589 } }, [5] = { family = 4, slots = { SHARD, SHARD, SHARD, SHARD } } })
local why
list, total, why = S.Surplus()
check(#list == 1 and list[1].bag == 5 and list[1].slot == 4 and why == "free", "Seelentasche minus 1: volle Tasche gibt den letzten Splitter ab")
setBags({ [0] = { family = 0, slots = { [1] = SHARD } }, [5] = { family = 4, slots = { SHARD, SHARD, SHARD, SHARD } } })
list = S.Surplus()
check(#list == 2 and list[1].bag == 0 and list[2].bag == 5, "Seelentasche minus 1: zuerst der Splitter ausserhalb")
setBags({ [0] = { family = 0, slots = { SHARD, SHARD, SHARD, SHARD } }, [1] = { family = 0, slots = { [1] = SHARD } } })
PeonClassBuddyDB.shardMax = 3
list = S.Surplus()
check(#list == 2, "Seelentasche minus 1 ohne Seelentasche: Hoechstzahl")
setBags({ [0] = { family = 0, slots = { [2] = 2589 } }, [5] = { family = 4, slots = { SHARD, SHARD, SHARD, SHARD } } })
UseAction(1)
check(deleted == 1 and bags[5].slots[4] == nil and lastMsg():find("bleibt frei"), "Aktionstaste: Seelentasche minus 1 vernichtet, Meldung")
deleted = 0
PeonClassBuddyDB.shardRule = "bag"
PeonClassBuddyDB.shardMax = 20

-- ===== Vernichten mit der Aktionstaste =====
setBags({ [0] = { family = 0, slots = { [1] = SHARD, [3] = SHARD } }, [5] = { family = 4, slots = { SHARD, SHARD, SHARD, SHARD } } })
UseAction(1)
check(deleted == 1 and count() == 5 and bags[0].slots[3] == nil, "Aktionstaste: ein Splitter vernichtet, der hinterste")
check(lastMsg():find("Seelentasche voll"), "Meldung im Chat")
-- gesperrter Platz wird uebersprungen
bags[0].locked = { [1] = true }
UseAction(1)
check(deleted == 1 and count() == 5, "gesperrter Platz: nichts vernichtet")
bags[0].locked = nil
-- belegter Mauszeiger und Zauber mit Zielsuche: nichts
cursor = { 0, 2, 2589 }
UseAction(1)
check(deleted == 1 and cursor and cursor[3] == 2589, "Mauszeiger belegt: nichts aufgenommen")
cursor = nil
targeting = true
UseAction(1)
check(deleted == 1, "Zauber sucht ein Ziel: nichts")
targeting = false
-- im Kampf geht es weiter
combat = true
UseAction(1)
check(deleted == 2 and count() == 4, "im Kampf: vernichtet")
combat = false
-- nichts mehr zu viel: kein weiterer Versuch
local nOut = okCount()
UseAction(1)
check(deleted == 2 and okCount() == nOut, "nichts zu viel: still")
-- Spiel sperrt: Splitter liegt wieder an seinem Platz, naechster Zauber versucht es erneut
bags[0].slots[2] = SHARD
deleteAllowed = false
UseAction(1)
check(deleted == 2 and bags[0].slots[2] == SHARD and cursor == nil, "gesperrt: zurueckgelegt")
deleteAllowed = true
UseAction(1)
check(deleted == 3 and bags[0].slots[2] == nil, "naechster Zauber: neuer Versuch klappt")
-- Aus: mit Zaubern abgeschaltet, Knopf geht trotzdem
bags[0].slots[2] = SHARD
PeonClassBuddyDB.shardAction = false
UseAction(1)
check(deleted == 3, "mit Zaubern aus: Aktionstaste vernichtet nichts")
_G.PeonClassBuddyShard:Click()
check(deleted == 4, "Makro / Tastenbelegung: Knopf vernichtet einen")
_G.PeonClassBuddyShard:Click()
check(deleted == 4 and lastMsg():find("Kein Seelensplitter zu viel"), "Knopf ohne Ueberschuss: Hinweis")
PeonClassBuddyDB.shardAction = true
PeonClassBuddyDB.shardOn = false
bags[0].slots[2] = SHARD
UseAction(1); _G.PeonClassBuddyShard:Click()
check(deleted == 4, "Hauptschalter aus: nichts")
PeonClassBuddyDB.shardOn = true
PeonClassBuddyDB.shardMsg = false
nOut = okCount()
UseAction(1)
check(deleted == 5 and okCount() == nOut, "ohne Meldung: still vernichtet")
PeonClassBuddyDB.shardMsg = true

-- Makro anlegen
S.MakeMacro(); S.MakeMacro()
check(#macros == 1 and macros[1].body == "/click PeonClassBuddyShard" and macros[1].perChar and pickedMacro == 1, "Makro einmal angelegt und am Mauszeiger")
-- Bericht
SlashCmdList.PEON("classbuddy splitter")
check(lastMsg():find("vernichtet: 6"), "/peon classbuddy splitter")
SlashCmdList.PEON("classbuddy")
check(lastMsg() == "OPEN Peon/Klassenbuddy", "/peon classbuddy oeffnet Seite")
-- Starter fuer Peon_Panel
check(ns.shardLauncher and ns.shardLauncher:IsAvailable(), "Eintrag fuer Peon_Panel")

-- ===== Schurke: Combo-Punkte =====
mod.panel.scripts.OnShow()
local pips = {}
for _, f in ipairs(allFrames) do if f.kind == "StatusBar" then pips[#pips+1] = f end end
check(#pips == 5 and pips[1].w == 22, "Vorschau: 5 Punkte mit uebernommener Groesse")
local slider
for _, f in ipairs(allFrames) do if f.kind == "Slider" and f.value == 22 then slider = f end end
slider:SetValue(20)
check(PeonClassBuddyDB.size == 20 and pips[1].w == 20, "Regler -> Vorschau")
local nTimers = #timers
CLASS = "ROGUE"
local cpFrame
for _, f in ipairs(allFrames) do if f.scripts.OnEvent and next(f.events) == nil and f ~= allFrames[1] then cpFrame = f end end   -- Hexenmeister: Rahmen hat sich abgemeldet
cpFrame.scripts.OnEvent(cpFrame, "PLAYER_LOGIN")
check(cpFrame.unitev.UNIT_POWER_UPDATE and ns.active, "Schurke: Combo-Punkte aktiv")
slider:SetValue(18)
check(#timers == nTimers + 1, "Schurke: Nameplates werden neu gezeichnet")
mod:ResetDefaults()
check(PeonClassBuddyDB.size == 15 and PeonClassBuddyDB.cpImported == true and PeonClassBuddyDB.shardRule == "free" and PeonClassBuddyDB.shardRule3, "Standardwerte, Uebernahme bleibt gemerkt")

local n = 0 for _, l in ipairs(out) do if l:find("/peon fehler") then n = n + 1 end end
check(n == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
