-- Stub-Test fuer Peon + Peon_ClassBuddy als Schurke: Combo-Punkte, Gifte (Taste, Ersetzen, Erinnerung, Vorrat,
-- Panel mit Klick und Menue, Optionen), nur eigene Klasse
-- Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
local now = 100
function GetTime() return now end
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
  local o = { scripts = {}, w = 0, h = 0, shown = true, events = {}, unitev = {}, points = {}, attrs = {} }
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
  function m.SetAttribute(s, k, v) if combat and s.secure then error("SetAttribute im Kampf") end s.attrs[k] = v end
  function m.GetAttribute(s, k) return s.attrs[k] end
  function m.GetThumbTexture() return true end
  function m.GetLeft(s) return s.l end
  function m.GetBottom(s) return s.b end
  function m.GetEffectiveScale(s) return s.scale or 1 end
  function m.GetFrameStrata() return "MEDIUM" end
  function m.GetFrameLevel() return 5 end
  function m.CreateFontString() return W() end
  function m.CreateTexture() return W() end
  function m.CreateMaskTexture() return W() end
  function m.GetStatusBarTexture() return W() end
  function m.Click(s) if s.scripts.OnClick then s.scripts.OnClick(s, "LeftButton") end end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" then return function() end end end })
end
function CreateFrame(kind, name, parent, template) local f = W(); f.kind = kind; f.name = name; f.secure = template == "SecureActionButtonTemplate"; allFrames[#allFrames+1] = f; if name then _G[name] = f end; return f end
UIParent = W()
local cats = {}
Settings = { RegisterCanvasLayoutCategory = function(p, n) local c = { name = n, subs = {}, GetID = function() return n end } cats[n] = c return c end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) table.insert(par.subs, n) return { GetID = function() return par.name .. "/" .. n end } end,
  RegisterAddOnCategory = function(c) c.registered = true end,
  OpenToCategory = function(id) print("OPEN " .. id) end }
ColorPickerFrame = { SetupColorPickerAndShow = function() end, GetColorRGB = function() return 0.1, 0.2, 0.3 end, GetColorAlpha = function() return 0.5 end }
local CLASS = "ROGUE"
function UnitClass() return "x", CLASS end
function UnitPowerMax() return 5 end
function UnitExists() return false end
C_NamePlate = { GetNamePlateForUnit = function() return nil end, GetNamePlates = function() return {} end }
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers+1] = fn end, NewTicker = function() end }
local function runTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end

-- Taschen: bags[bag][slot] = { id, n }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
local bags = {}
C_Container = {
  GetContainerNumSlots = function(b) return bags[b] and 8 or 0 end,
  GetContainerNumFreeSlots = function() return 0, 0 end,
  GetContainerItemID = function(b, s) return bags[b] and bags[b][s] and bags[b][s][1] or nil end,
  GetContainerItemInfo = function(b, s) local e = bags[b] and bags[b][s]; if not e then return nil end return { itemID = e[1], stackCount = e[2], isLocked = false } end,
}
-- Waffen: Platz 16 und 17 -> itemID; classes[itemID] = { classID, subID }
local inv = { [16] = 1001, [17] = 1002 }
local classes = { [1001] = { 2, 15 }, [1002] = { 2, 15 }, [1003] = { 4, 6 }, [1004] = { 2, 20 } }
function GetInventoryItemID(_, slot) return inv[slot] end
local tooHigh = {}   -- Gifte, deren Stufe zu hoch ist
C_Item = {
  GetItemInfoInstant = function(id) local c = classes[id] or { 0, 0 } return id, "", "", "", 0, c[1], c[2] end,
  IsUsableItem = function(id) return not tooHigh[id] end,
}
-- Verzauberung: ench[16] = { sec, charges } oder nil
local ench = {}
function GetWeaponEnchantInfo()
  local a, b = ench[16], ench[17]
  return a ~= nil, a and a[1] * 1000 or nil, a and a[2] or nil, a and 1 or nil,
         b ~= nil, b and b[1] * 1000 or nil, b and b[2] or nil, b and 1 or nil
end
-- Ersetzen
local replaceAllowed, replaced, popupHidden, popupShown = true, 0, 0, 0
local blockFrame
function StaticPopup_Show(which, a, b) popupShown = popupShown + 1 end
function StaticPopup_Hide(which) if which == "REPLACE_ENCHANT" then popupHidden = popupHidden + 1 end end
C_Item.ReplaceEnchant = function()
  if replaceAllowed then replaced = replaced + 1 else blockFrame = true end
end
-- Warnungen
local warnings, sounds = {}, 0
RaidWarningFrame = W()
function RaidNotice_AddMessage(_, msg) warnings[#warnings+1] = msg end
ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.3, b = 0 } }
SOUNDKIT = { RAID_WARNING = 8959 }
function PlaySound() sounds = sounds + 1 end
local resting, instance, dead, taxi = false, false, false, false
function IsResting() return resting end
function IsInInstance() return instance end
function UnitIsDeadOrGhost() return dead end
function UnitOnTaxi() return taxi end
local hooks = {}
function hooksecurefunc(name, fn) if type(name) ~= "string" then return end local orig = _G[name]; _G[name] = function(...) local r = orig(...); fn(...); return r end; hooks[name] = true end
function UseAction() end
local macros, pickedMacro = {}, nil
function GetMacroIndexByName(n) for i, m in ipairs(macros) do if m.name == n then return i end end return 0 end
function CreateMacro(n, icon, body, perChar) macros[#macros+1] = { name = n, body = body, icon = icon, perChar = perChar } return #macros end
function PickupMacro(i) pickedMacro = i end

local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end
local function lastMsg() for i = #out, 1, -1 do if not out[i]:match("^ok  ") then return out[i] end end return "" end

-- Gifte (aus Rogue_Poisons.lua)
local INSTANT1, INSTANT5, INSTANT6, DEADLY4, DEADLY5, CRIP1 = 6947, 8927, 8928, 8985, 20844, 3775

-- Klick wie Blizzards sichere Vorlage: Druecken und Loslassen, die Aktion beim Loslassen (useOnKeyDown = false)
local applied = {}
local btn
local function press()
  for _, down in ipairs({ true, false }) do
    if btn.scripts.PreClick then btn.scripts.PreClick(btn, "LeftButton", down) end
    local acts = (down and btn.attrs.useOnKeyDown) or (not down and not btn.attrs.useOnKeyDown)
    if acts and btn.attrs.type == "item" then
      applied[#applied+1] = { item = btn.attrs.item, slot = btn.attrs["target-slot"] }
      -- liegt schon etwas auf der Waffe, fragt das Spiel nach
      if ench[btn.attrs["target-slot"]] then StaticPopup_Show("REPLACE_ENCHANT", "Alt", "Neu") end
      if blockFrame then blockFrame = nil; fire("ADDON_ACTION_BLOCKED", "Peon_ClassBuddy", "C_Item.ReplaceEnchant()") end
    end
    if btn.scripts.PostClick then btn.scripts.PostClick(btn, "LeftButton", down) end
  end
end
local function lastApplied() return applied[#applied] end

-- ===== Laden als Schurke =====
load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
PeonClassBuddyDB = { shardRule3 = true, cpImported = true, poisonMain = "quatsch", poisonRenew = 99 }
local ns = load("Peon_ClassBuddy", "Peon_ClassBuddy")
fire("ADDON_LOADED", "Peon_ClassBuddy")
local mod = ns.mod
local P = ns.Poisons
local db = PeonClassBuddyDB
check(db.poisonMain == "instant" and db.poisonOff == "deadly" and db.poisonRenew == 30, "Standard bei ungueltiger Auswahl, Minuten geklemmt")
db.poisonRenew = 10
check(not P.IsActive(), "vor dem Einloggen nicht aktiv")
bags = { [0] = { { INSTANT5, 10 }, { INSTANT6, 3 }, { DEADLY4, 20 }, { 2589, 5 } } }
fire("PLAYER_LOGIN")
btn = _G.PeonClassBuddyPoison
check(P.IsActive() and btn and btn.secure, "Schurke: Gifte aktiv, sicherer Knopf")
check(btn.attrs.useOnKeyDown == false, "Knopf wirkt beim Loslassen")
check(hooks.StaticPopup_Show, "Frage zum Ersetzen wird mitgelesen")
check(mod.page:GetTab() == "general", "Schurke: Reiter Allgemein offen")
local tabs = {}
for _, t in ipairs(mod.page.tabList or {}) do tabs[#tabs+1] = t[1] end
check(#tabs == 3 and tabs[1] == "general" and tabs[2] == "display" and tabs[3] == "advanced", "Schurke: Allgemein, Anzeige, Erweitert (ab 0.5.0)")
local keys = {}
for _, l in ipairs(Peon.GetLaunchers()) do keys[l.key] = true end
check(keys.poisons and not keys.shards and ns.shardLauncher == nil and not ns.Shards.IsActive(), "Panel: Gifte, keine Seelensplitter")

-- ===== Combo-Punkte =====
check(ns.active, "Schurke: Combo-Punkte aktiv")
mod.panel.scripts.OnShow()
local pips = {}
for _, f in ipairs(allFrames) do if f.kind == "StatusBar" then pips[#pips+1] = f end end
check(#pips == 5 and pips[1].w == 15, "Vorschau: 5 Punkte")
local slider
for _, f in ipairs(allFrames) do if f.kind == "Slider" and f.value == 15 then slider = f end end
local nTimers = #timers
slider:SetValue(20)
check(db.size == 20 and pips[1].w == 20 and #timers == nTimers + 1, "Regler -> Vorschau, Nameplates neu gezeichnet")

-- Nameplates: Gegner (nameplate1, Ziel) und ein Fass mit Soft-Interact-Nameplate (nameplate2).
-- Das Fass meldet sich hier sogar als angreifbar: nur UnitIsGameObject haelt es fern.
do
  local plates, kind = {}, { nameplate1 = "enemy", nameplate2 = "object", nameplate3 = "enemy" }
  local function plate(token) local uf = CreateFrame("Frame"); uf.healthBar = W(); local np = { UnitFrame = uf, namePlateUnitToken = token }; uf.namePlateFrame = np; plates[token] = np; return uf end
  local enemyUF, barrelUF = plate("nameplate1"), plate("nameplate2")
  local target = "nameplate1"
  local oldNP, oldExists = C_NamePlate.GetNamePlateForUnit, UnitExists
  C_NamePlate.GetNamePlateForUnit = function(u) if u == "target" then u = target end return u and plates[u] end
  UnitExists = function(u) if u == "target" then u = target end return u ~= nil and kind[u] ~= nil end
  function UnitCanAttack() return true end
  function UnitIsGameObject(u) return kind[u] == "object" end
  function UnitGUID(u) return "GUID-" .. tostring(u == "target" and target or u) end
  function UnitPower() return 2 end
  for _, f in ipairs(allFrames) do if f.unitev.UNIT_POWER_UPDATE and f.scripts.OnEvent then f.scripts.OnEvent(f, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS") end end
  runTimers()
  check(enemyUF.cpRow and enemyUF.cpRow.shown and enemyUF.cpRow.pips[1].value == 2, "Combo-Punkte am Gegner")
  fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
  runTimers()
  check(not (barrelUF.cpRow and barrelUF.cpRow.shown), "keine Combo-Punkte am Fass (Objekt-Nameplate)")
  -- Fass als Ziel des Soft Interact und als Traeger-Rahmen: trotzdem nichts
  target = "nameplate2"
  fire("PLAYER_TARGET_CHANGED")
  runTimers()
  check(not (barrelUF.cpRow and barrelUF.cpRow.shown), "kein Fass, auch wenn es als Ziel gemeldet wird")
  check(enemyUF.cpRow.shown and enemyUF.cpRow.pips[1].value == 2, "Traeger behaelt seine Punkte")
  -- Traeger-Rahmen mit altem Token, das inzwischen zu einem anderen Plate gehoert (ohne Ereignis)
  enemyUF.namePlateFrame, enemyUF.unit = nil, "nameplate1"
  plate("nameplate1")
  target = "nameplate3"
  plate("nameplate3")
  fire("PLAYER_TARGET_CHANGED")
  runTimers()
  check(not enemyUF.cpRow.shown, "Rahmen mit fremdem Token zeigt nichts")
  target = nil
  fire("PLAYER_REGEN_ENABLED")
  runTimers()
  C_NamePlate.GetNamePlateForUnit, UnitExists = oldNP, oldExists
  UnitCanAttack, UnitIsGameObject, UnitGUID, UnitPower = nil, nil, nil, nil
end

-- ===== Auswahl =====
check(P.Best("instant") == INSTANT6 and P.Count("instant") == 13, "hoechster Rang, alle Raenge gezaehlt")
tooHigh[INSTANT6] = true
check(P.Best("instant") == INSTANT5, "zu hoher Rang wird uebersprungen")
tooHigh[INSTANT6] = nil
local s = P.Next()
check(s and s.hand == 16 and s.item == INSTANT6, "nichts auf den Waffen: zuerst Haupthand")
check(btn.attrs.type == "item" and btn.attrs.item == "item:" .. INSTANT6 and btn.attrs["target-slot"] == 16, "Knopf beim Einloggen vorbereitet")

-- ===== Taste =====
press()
check(#applied == 1 and lastApplied().slot == 16 and lastApplied().item == "item:" .. INSTANT6, "Druck: Sofort wirkendes Gift auf die Haupthand")
ench[16] = { 1800, 0 }
press()
check(#applied == 2 and lastApplied().slot == 17 and lastApplied().item == "item:" .. DEADLY4, "zweiter Druck: Toedliches Gift auf die Nebenhand")
ench[17] = { 1800, 0 }
local n = #out
press()
check(#applied == 2 and out[#out - 1]:find("Haupthand %(Sofort wirkendes Gift%): noch 30 Min"), "alles frisch: nichts aufgetragen, Stand im Chat")
check(lastMsg():find("Nebenhand %(Tödliches Gift%): noch 30 Min"), "Stand fuer beide Haende")
-- bald ablaufend
ench[17] = { 300, 0 }
press()
check(#applied == 3 and lastApplied().slot == 17, "Nebenhand unter 10 Min.: wird erneuert")
check(replaced == 1 and popupHidden == 1, "Frage zum Ersetzen selbst bestaetigt")
ench[17] = { 1800, 0 }
-- Ladungen
ench[16] = { 1800, 5 }
press()
check(#applied == 4 and lastApplied().slot == 16 and replaced == 2, "unter 10 Ladungen: Haupthand erneuert")
db.poisonCharges = 0
press()
check(#applied == 4, "Ladungen aus: nichts")
db.poisonCharges = 10
ench[16] = { 1800, 0 }
-- Frage zum Ersetzen, die nicht von uns kommt (z. B. Wetzstein von Hand)
StaticPopup_Show("REPLACE_ENCHANT", "a", "b")
now = now + 10
StaticPopup_Show("REPLACE_ENCHANT", "a", "b")
check(replaced == 2, "fremde Frage zum Ersetzen bleibt unberuehrt")
-- Ersetzen ohne Nachfrage aus
db.poisonReplace = false
ench[16] = { 60, 0 }
press()
check(#applied == 5 and replaced == 2, "Ersetzen aus: Frage bleibt")
db.poisonReplace = true
-- Spiel sperrt das Ersetzen: Frage kommt wieder, kein weiterer Versuch
replaceAllowed = false
local shownBefore = popupShown
now = now + 10
press()
check(#applied == 6 and popupShown == shownBefore + 2 and lastMsg():find("Bitte selbst"), "gesperrt: Frage erscheint wieder mit Hinweis")
check(P._State().replaceBlocked, "gesperrt gemerkt")
press()
check(replaced == 2, "danach kein neuer Versuch")
ench[16] = { 1800, 0 }

-- ===== Waffen =====
inv[17] = 1003   -- Schild
ench[17] = nil
s = P.Next()
check(s == nil, "Schild in der Nebenhand: kein Gift")
inv[17] = nil
check(P.State(17) == nil, "keine Nebenhand: nichts")
inv[16] = 1004
ench[16] = nil
check(P.Next() == nil, "Angel in der Hand: kein Gift")
inv[16], inv[17] = 1001, 1002
ench[16], ench[17] = { 1800, 0 }, { 1800, 0 }
db.poisonOff = "none"
ench[17] = nil
check(P.Next() == nil, "Nebenhand ohne gewaehltes Gift: nichts")
db.poisonOff = "crippling"
check(P.Next() == nil, "kein Verkrueppelndes Gift in den Taschen: nichts aufzutragen")
P.PrintStatus()
check(lastMsg():find("fehlt, kein Verkrüppelndes Gift in den Taschen"), "Stand nennt das fehlende Gift")
db.poisonOff = "deadly"

-- ===== Kampf =====
s = P.Next()
check(s and s.hand == 17, "vor dem Kampf: Nebenhand dran")
mod:Fire("COMBAT_START")
combat = true
ench[16] = nil   -- im Kampf faellt das Gift der Haupthand weg
press()
check(lastApplied().slot == 17, "im Kampf: vorbereitete Hand, Attribute bleiben")
combat = false
mod:Fire("COMBAT_END")
check(btn.attrs["target-slot"] == 16, "nach dem Kampf neu eingestellt")
ench[16], ench[17] = { 1800, 0 }, { 1800, 0 }

-- ===== Erinnerung =====
check(#warnings == 1 and warnings[1]:find("Haupthand"), "Kampfende: fehlendes Gift wird gemeldet")
local function nWarn() return #warnings end
P.Check(false)
warnings, sounds = {}, 0
now = now + 20
P.Check(false)
check(nWarn() == 0, "alles frisch: keine Warnung")
ench[16] = { 120, 0 }
P.Check(false)
check(nWarn() == 1 and warnings[1]:find("Haupthand") and sounds == 1, "Haupthand laeuft ab: Warnung mit Ton")
P.Check(false)
check(nWarn() == 1, "nur einmal")
ench[17] = nil
P.Check(false)
check(nWarn() == 2 and warnings[2]:find("Haupthand und Nebenhand"), "neue Hand: Warnung nennt beide")
ench[16], ench[17] = { 1800, 0 }, { 1800, 0 }
P.Check(false)
ench[16] = nil
resting = true
P.Check(false)
check(nWarn() == 2, "in Stadt oder Gasthaus: keine Warnung")
resting = false
P.Check(false)
check(nWarn() == 3, "Stadt verlassen: Warnung kommt")
dead = true; ench[16] = { 1800, 0 }; P.Check(false); ench[16] = nil; P.Check(false)
check(nWarn() == 3, "tot: keine Warnung")
dead = false
combat = true; P.Check(false); combat = false
check(nWarn() == 3, "im Kampf: keine Warnung")
P.Check(false)
check(nWarn() == 4, "danach: Warnung")
now = now + 20
P.Check(true)
check(nWarn() == 5, "fester Zeitpunkt: erneut")
P.Check(true)
check(nWarn() == 5, "fester Zeitpunkt kurz danach: nicht doppelt")
now = now + 20
fire("READY_CHECK")
check(nWarn() == 6, "Bereitschaftscheck warnt")
db.poisonSound = false
now = now + 20
P.Check(true)
check(nWarn() == 7 and sounds == 6, "ohne Ton")
db.poisonSound = true
db.poisonWarn = false
now = now + 20
P.Check(true)
check(nWarn() == 7, "Erinnerung aus: still")
db.poisonWarn = true
-- kein passendes Gift in den Taschen: keine Warnung (nichts zu tun)
local saved = bags
bags = {}
db.poisonLow = 0
now = now + 20
P.Check(true)
check(nWarn() == 7, "keine Gifte in den Taschen: keine Warnung")
bags = saved
db.poisonLow = 5
ench[16] = { 1800, 0 }

-- ===== Vorrat =====
P.Check(false)
local w = nWarn()
bags[0][1] = nil   -- 10 Sofort wirkende weniger, bleiben 3
P.Check(false)
check(nWarn() == w + 1 and warnings[#warnings]:find("Nur noch 3 Sofort wirkendes Gift"), "Vorrat knapp: Warnung")
bags[0][2] = { INSTANT6, 2 }
P.Check(false)
check(nWarn() == w + 1, "nur einmal")
bags[0][2] = nil
P.Check(false)
check(nWarn() == w + 1, "aufgebraucht nach Warnung: nicht noch einmal")
bags[0][2] = { INSTANT6, 20 }
P.Check(false)
bags[0][2] = { INSTANT6, 0 }
bags[0][2] = nil
P.Check(false)
check(nWarn() == w + 2 and warnings[#warnings]:find("Kein Sofort wirkendes Gift mehr"), "nach Auffuellen wieder scharf: aufgebraucht")
db.poisonLow = 0
bags[0][2] = { INSTANT6, 20 }; P.Check(false); bags[0][2] = { INSTANT6, 1 }; P.Check(false)
check(nWarn() == w + 2, "Vorratswarnung aus")
db.poisonLow = 5

-- ===== Makro, Befehl, Panel, Optionen =====
P.MakeMacro(); P.MakeMacro()
check(#macros == 1 and macros[1].name == "PeonGift" and macros[1].body == "/click PeonClassBuddyPoison" and pickedMacro == 1, "Makro einmal angelegt")
SlashCmdList.PEON("classbuddy gifte")
check(lastMsg():find("Gifte in den Taschen: Sofort wirkendes Gift 1, Tödliches Gift 20"), "/peon classbuddy gifte")
check(ns.poisonLauncher and ns.poisonLauncher:IsAvailable(), "Eintrag fuer Peon_Panel")
check(P.ShortText() == "30 / 30", "Kurztext fuer die Leiste")
local l = ns.poisonLauncher
check(l:GetText("stock") == "1 / 20" and l:GetText("both") == "30 / 30 (1 / 20)", "Texte Vorrat und beides")

-- Panel: sicherer Knopf legt sich beim Tooltip ueber das Symbol
local ov = _G.PeonClassBuddyPoisonPanel
check(ov and ov.secure and ov.attrs.type1 == "click" and ov.attrs.clickbutton1 == btn and not ov.shown, "Panel-Knopf angelegt, klickt die Gift-Taste")
local owner = W()
owner.l, owner.b, owner.w, owner.h = 200, 700, 24, 24
local ownerClicks, ownerLeft = {}, 0
owner.scripts.OnClick = function(_, b) ownerClicks[#ownerClicks+1] = b end
owner.scripts.OnLeave = function() ownerLeft = ownerLeft + 1 end
GameTooltip = W()
function GameTooltip.SetOwner(s, o) s.owner = o end
function GameTooltip.GetOwner(s) return s.owner end
function GameTooltip.AddLine(s, t) s.lines = s.lines or {}; s.lines[#s.lines+1] = t end
GameTooltip:SetOwner(owner)
l:FillTooltip(GameTooltip)
check(ov.shown and ov.w == 24 and ov.points[1][4] == 200 and ov.points[1][5] == 700, "Tooltip: Knopf liegt ueber dem Symbol")
check(GameTooltip.lines[#GameTooltip.lines]:find("Rechtsklick") and GameTooltip.lines[#GameTooltip.lines - 1]:find("In den Taschen: Sofort wirkendes Gift %(1%), Tödliches Gift %(20%)"), "Tooltip mit Vorrat und Hinweis")
-- Linksklick: Blizzards Vorlage klickt die Gift-Taste, die traegt auf
ench[16] = nil
local nApplied = #applied
press()   -- clickbutton1:Click()
ov.scripts.PostClick(ov, "LeftButton")
check(#applied == nApplied + 1 and lastApplied().slot == 16, "Linksklick im Panel: Gift aufgetragen")
ench[16] = { 1800, 0 }
-- Rechtsklick: Menue des Symbols
ov.scripts.PostClick(ov, "RightButton")
check(ownerClicks[1] == "RightButton", "Rechtsklick: Menue des Panels")
-- Verlassen: Knopf weg
ov.scripts.OnLeave(ov)
check(not ov.shown and ownerLeft == 1, "Verlassen: Knopf verschwindet")
-- Kampf: Knopf weg, wird nicht angelegt, Klick auf das Symbol erklaert es
GameTooltip:SetOwner(owner); l:FillTooltip(GameTooltip)
mod:Fire("COMBAT_START")
check(not ov.shown, "Kampfbeginn: Knopf verschwindet")
combat = true
l:FillTooltip(GameTooltip)
check(not ov.shown, "im Kampf: nicht angelegt")
l:Click("LeftButton", owner)
check(lastMsg():find("Im Kampf lassen sich Gifte nur mit der Taste"), "im Kampf: Hinweis beim Klick")
combat = false
mod:Fire("COMBAT_END")

-- Menue: Gift je Waffe mit Vorrat
local radios, titles = {}, {}
local root = { CreateTitle = function(_, t) titles[#titles+1] = t end,
  CreateRadio = function(_, text, isSel, setSel, v) radios[#radios+1] = { text = text, isSel = isSel, setSel = setSel, v = v } end,
  CreateButton = function() end, CreateDivider = function() end }
l:FillMenu(root)
check(#titles == 2 and titles[1] == "Gift für die Haupthand" and #radios == 12, "Menue: beide Waffen, je 5 Gifte und keins")
check(radios[1].text == "Sofort wirkendes Gift (1)" and radios[2].text == "Tödliches Gift (20)" and radios[1].isSel("instant"), "Menue: Vorrat und Auswahl")
radios[9].setSel(radios[9].v)   -- Nebenhand: Verkrueppelndes Gift
check(db.poisonOff == "crippling" and db.poisonMain == "instant", "Menue: Nebenhand gewaehlt")
radios[12].setSel(radios[12].v)
check(db.poisonOff == "none" and l:GetText("stock") == "1", "Menue: Nebenhand ohne Gift")
db.poisonOff = "deadly"

db.poisonOn = false
press()
check(lastMsg():find("ausgeschaltet") and P.Next() == nil, "Gift-Taste aus")
db.poisonOn = true
mod:ResetDefaults()
check(db.poisonMain == "instant" and db.poisonLow == 5 and db.poisonOn, "Standardwerte")
runTimers()

local errs = 0 for _, l in ipairs(out) do if l:find("/peon fehler") then errs = errs + 1 end end
check(errs == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
