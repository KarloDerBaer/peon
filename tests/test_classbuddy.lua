-- Stub-Test fuer Peon + Peon_ClassBuddy: Pruefbefehl fuer Seelensplitter (Probe.lua)
-- Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
function GetTime() return 1 end
function GetBuildInfo() return "1.60.1", "70888" end
date = os.date
time = os.time
local combat = false
function InCombatLockdown() return combat end
function UnitAffectingCombat() return combat end
SlashCmdList = {}
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_ClassBuddy = TocMeta("Peon_ClassBuddy") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function() return true end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_ClassBuddy" })[i] end }
local allFrames = {}
local function W()
  local o = { scripts = {}, w = 0, h = 0, shown = true, events = {}, unitev = {}, points = {} }
  local m = {}
  function m.SetSize(s, w, h) s.w, s.h = w, h end
  function m.GetHeight(s) return s.h end
  function m.GetWidth(s) return s.w end
  function m.GetStringHeight() return 12 end
  function m.SetScript(s, n, f) s.scripts[n] = f end
  function m.GetScript(s, n) return s.scripts[n] end
  function m.HookScript(s, n, f) s.scripts[n] = f end
  function m.SetText(s, t) s.text = t end
  function m.GetText(s) return s.text end
  function m.IsShown(s) return s.shown end
  function m.Show(s) s.shown = true end
  function m.Hide(s) s.shown = false end
  function m.SetPoint(s, ...) s.points[#s.points+1] = { ... } end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.RegisterUnitEvent(s, e) s.unitev[e] = true end
  function m.UnregisterAllEvents(s) s.events = {}; s.unitev = {} end
  function m.CreateFontString() return W() end
  function m.CreateTexture() return W() end
  function m.Click(s) if s.scripts.OnClick then s.scripts.OnClick(s, "LeftButton") end end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Text" then return function() end end end })
end
function CreateFrame(kind, name) local f = W(); f.kind = kind; f.name = name; allFrames[#allFrames+1] = f; if name then _G[name] = f end; return f end
UIParent = W()
Settings = { RegisterCanvasLayoutCategory = function(p, n) return { name = n, subs = {}, GetID = function() return n end } end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) return { GetID = function() return n end } end,
  RegisterAddOnCategory = function() end, OpenToCategory = function() end }
local CLASS = "WARLOCK"
function UnitClass() return "Hexenmeister", CLASS end

-- Zeitgeber: gesammelt und von Hand ausgefuehrt
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers+1] = fn end, NewTicker = function() end }
local function runTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end

-- Taschen: bags[bag] = { family = n, slots = { [slot] = itemID } }, Groesse 4 Plaetze
local SHARD = 6265
local bags = {}
local function setBags(def) bags = def end
local cursor           -- { bag, slot, id }
local deleteAllowed = true
local deleted = 0
local blockedFire       -- Funktion, die ADDON_ACTION_FORBIDDEN ausloest
C_Container = {
  GetContainerNumSlots = function(b) return bags[b] and 4 or 0 end,
  GetContainerNumFreeSlots = function(b)
    if not bags[b] then return 0, 0 end
    local free = 0 for s = 1, 4 do if not bags[b].slots[s] then free = free + 1 end end
    return free, bags[b].family or 0
  end,
  GetContainerItemID = function(b, s) return bags[b] and bags[b].slots[s] or nil end,
  PickupContainerItem = function(b, s)
    local id = bags[b] and bags[b].slots[s]
    if not id then return end
    cursor = { b, s, id }
    bags[b].slots[s] = nil
  end,
}
C_Item = { GetItemFamily = function(id) return id == SHARD and 4 or 0 end }
function GetCursorInfo() if cursor then return "item", cursor[3] end end
function CursorHasItem() return cursor ~= nil end
function ClearCursor() if cursor then bags[cursor[1]].slots[cursor[2]] = cursor[3]; cursor = nil end end
function DeleteCursorItem()
  if not deleteAllowed then if blockedFire then blockedFire() end return end
  if cursor then deleted = deleted + 1; cursor = nil end
end
local hooks = {}
function hooksecurefunc(name, fn) if type(name) ~= "string" then return end local orig = _G[name]; _G[name] = function(...) local r = orig(...); fn(...); return r end; hooks[name] = true end
function UseAction() end
function CastSpellByName() end
local macros, pickedMacro = {}, nil
function GetMacroIndexByName(n) for i, m in ipairs(macros) do if m.name == n then return i end end return 0 end
function CreateMacro(n, icon, body, perChar) macros[#macros+1] = { name = n, body = body, perChar = perChar } return #macros end
function PickupMacro(i) pickedMacro = i end
-- Peon_Feedback nachgebaut: nimmt Eintraege ueber den Kern an (Kern-API 22)
local fbEntries = {}

local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end
local function count() local n = 0 for _, b in pairs(bags) do for s = 1, 4 do if b.slots[s] == SHARD then n = n + 1 end end end return n end

-- ===== Laden =====
load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
local ns = load("Peon_ClassBuddy", "Peon_ClassBuddy")
fire("ADDON_LOADED", "Peon_ClassBuddy")
fire("PLAYER_LOGIN")
local mod = ns.mod
local P = ns.Probe
local G = ns.Guide
check(Peon.API >= 22 and not Peon.CanAddFeedback(), "Kern-API 22, ohne Peon_Feedback kein Weg zum Manager")
check(mod.initialized, "Modul angemeldet")
check(type(PeonClassBuddyDB.probe) == "table", "Ergebnisse in PeonClassBuddyDB.probe")
blockedFire = function() fire("ADDON_ACTION_FORBIDDEN", "Peon_ClassBuddy", "DeleteCursorItem()") end

-- 1. Splitter finden: normale Tasche vor Seelentasche, Seelentasche wird nur ohne andere genommen
setBags({ [0] = { family = 0, slots = { [1] = 2589, [3] = SHARD } }, [1] = { family = 4, slots = { [1] = SHARD, [2] = SHARD } } })
local b, s = P.FindShard()
check(b == 0 and s == 3, "Splitter zuerst aus der normalen Tasche")
setBags({ [0] = { family = 0, slots = { [1] = 2589 } }, [1] = { family = 4, slots = { [1] = SHARD, [2] = SHARD } } })
b, s = P.FindShard()
check(b == 1 and s == 2, "sonst der letzte in der Seelentasche")
local list, total = P.ScanBags()
check(total == 2 and list[2].family == 4 and list[2].free == 2, "Uebersicht der Taschen mit Taschentyp")

-- 2. Start: Fenster, Makro-Knopf, Haken, Test ohne Tastendruck nach 1 Sekunde
setBags({ [0] = { family = 0, slots = { [1] = SHARD, [2] = SHARD, [3] = SHARD, [4] = SHARD } }, [1] = { family = 4, slots = { [1] = SHARD, [2] = SHARD } } })
runTimers()
check(G.IsShown() and not P._IsArmed(), "Hexenmeister: Fenster beim Einloggen, Pruefung noch nicht gestartet")
SlashCmdList.PEON("classbuddy pruefen start")
check(P._IsArmed(), "Pruefung scharf")
check(_G.PeonClassBuddyShard ~= nil, "Knopf fuer /click PeonClassBuddyShard")
check(hooks.UseAction and hooks.CastSpellByName, "Aktionstasten werden mitgelesen")
check(PeonClassBuddyDB.probe.info and PeonClassBuddyDB.probe.info.shards == 6, "Uebersicht gespeichert")
runTimers()          -- Zeitgeber: Test ohne Tastendruck
check(count() == 5 and deleted == 1, "ohne Tastendruck: ein Splitter vernichtet")
runTimers()          -- Nachzaehlen
local R = PeonClassBuddyDB.probe.results
check(R.event_frei and R.event_frei.ok == true, "Ergebnis event_frei: vernichtet")

-- 3. Klick auf den Makro-Knopf, zweiter Klick vernichtet nichts mehr (je Zustand nur einer)
_G.PeonClassBuddyShard:Click()
runTimers()
check(R.macro_frei and R.macro_frei.ok and count() == 4, "Makro /click: ein Splitter")
_G.PeonClassBuddyShard:Click()
runTimers()
check(count() == 4, "zweites Makro im selben Zustand vernichtet nichts")

-- 4. Aktionstaste: erster Aufruf vernichtet, weitere nicht, Haken werden gezaehlt
UseAction(1)
runTimers()
check(R.action_frei and R.action_frei.ok and R.action_frei.hook == "UseAction" and count() == 3, "Aktionstaste: ein Splitter, Aufruf UseAction")
CastSpellByName("Schattenblitz")
runTimers()
check(count() == 3 and PeonClassBuddyDB.probe.hooks.CastSpellByName == 1, "weitere Zauber nur gezaehlt")

-- 5. Im Kampf gesperrt: Splitter bleibt, liegt wieder an seinem Platz, Sperre wird genannt
combat = true
deleteAllowed = false
UseAction(1)
runTimers()
check(count() == 3 and cursor == nil, "gesperrt: Splitter zurueck, Mauszeiger leer")
check(R.action_kampf and R.action_kampf.ok == false and R.action_kampf.blocked == "DeleteCursorItem()", "Ergebnis action_kampf: gesperrt mit Name")

-- 6. Kampfbeginn startet den Test ohne Tastendruck noch einmal
fire("PLAYER_REGEN_DISABLED")
runTimers(); runTimers()
check(R.event_kampf and R.event_kampf.ok == false, "event_kampf geprueft")

-- 7. Sicherheit: belegter Mauszeiger, kein Splitter, falscher Gegenstand
deleteAllowed = true
cursor = { 0, 4, 2589 }
P.TryDelete("click")
check(R.click_kampf and R.click_kampf.ok == false and cursor and cursor[3] == 2589, "belegter Mauszeiger: nichts aufgenommen")
cursor = nil
combat = false
setBags({ [0] = { family = 0, slots = { [1] = 2589 } } })
P.TryDelete("click")
check(R.click_frei and R.click_frei.ok == false and bags[0].slots[1] == 2589 and deleted == 3, "kein Splitter: nichts vernichtet")
-- falscher Gegenstand am Zeiger (Platz wechselt zwischen Finden und Aufnehmen)
setBags({ [0] = { family = 0, slots = { [1] = SHARD } } })
local origPick = C_Container.PickupContainerItem
C_Container.PickupContainerItem = function(bb, ss) bags[bb].slots[ss] = 2589; origPick(bb, ss) end
PeonClassBuddyDB.probe.results = {}
R = PeonClassBuddyDB.probe.results
P.TryDelete("click")
C_Container.PickupContainerItem = origPick
check(R.click_frei and R.click_frei.ok == false and cursor == nil and bags[0].slots[1] == 2589 and deleted == 3, "falscher Gegenstand: zurueckgelegt, nichts vernichtet")

-- 7b. Makro anlegen: einmal, pro Charakter, haengt am Mauszeiger, im Kampf nicht
P.MakeMacro()
P.MakeMacro()
check(#macros == 1 and macros[1].body == "/click PeonClassBuddyShard" and macros[1].perChar == true and pickedMacro == 1, "Makro einmal angelegt und am Mauszeiger")
combat = true
P.MakeMacro()
check(#macros == 1, "im Kampf kein Makro")
combat = false

-- 7c. Senden: ohne Peon_Feedback nicht, mit Peon_Feedback ein Eintrag mit allen Wegen
check(P.Send() == false, "ohne Peon_Feedback wird nichts gesendet")
Peon.SetFeedbackHandler(function(e) fbEntries[#fbEntries+1] = e; return e end)
check(Peon.CanAddFeedback(), "Peon_Feedback angemeldet")
check(P.Send() == true and #fbEntries == 1, "Ergebnis an Peon_Feedback")
local fe = fbEntries[1]
check(fe.module == "Peon_ClassBuddy" and fe.area == "Prüfung" and fe.kind == "other", "Eintrag mit Modul und Bereich")
check(fe.text:find("click_frei: nein") and fe.text:find("action_kampf: nicht getestet") and fe.text:find("Taschen:") and #fe.text < 2000, "Text mit allen Wegen und Taschen, kurz genug fuer den Manager")
check(PeonClassBuddyDB.probe.sent ~= nil, "Senden gemerkt")
Peon.SetFeedbackHandler(function() error("kaputt") end)
check(P.Send() == false, "Fehler in Peon_Feedback wird abgefangen")

-- 7d. Fenster: Stand je Weg, Haken "Nicht mehr anzeigen"
G.Refresh()
check(G.IsShown(), "Fenster offen")
PeonClassBuddyDB.hideGuide = true
local shownBefore = #timers
G.OnLogin()
check(#timers == shownBefore, "abgehakt: Fenster kommt beim Einloggen nicht mehr")
PeonClassBuddyDB.hideGuide = false
CLASS = "ROGUE"
G.OnLogin()
check(#timers == shownBefore, "andere Klasse: kein Fenster")
CLASS = "WARLOCK"

-- 8. Ergebnis, leeren, aus
SlashCmdList.PEON("classbuddy pruefen ergebnis")
local seen = false for _, l in ipairs(out) do if l:find("Klick auf Knopf") then seen = true end end
check(seen, "Ergebnisse im Chat")
SlashCmdList.PEON("classbuddy pruefen leeren")
check(next(PeonClassBuddyDB.probe.results) == nil, "Ergebnisse geleert")
SlashCmdList.PEON("classbuddy pruefen aus")
check(not P._IsArmed(), "Pruefung aus")
local before = deleted
setBags({ [0] = { family = 0, slots = { [1] = SHARD } } })
UseAction(1)
runTimers()
check(deleted == before, "nach aus: Aktionstaste vernichtet nichts")

local n = 0 for _, l in ipairs(out) do if l:find("/peon fehler") then n = n + 1 end end
check(n == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
