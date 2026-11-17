-- Test fuer Peon + Peon_Warhorn 0.1.0 (Pruefaufbau der Gruppensuche)
-- Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
local now = 100
function GetTime() return now end
date = os.date
local combat = false
function InCombatLockdown() return combat end
function UnitAffectingCombat() return false end
function GetBuildInfo() return "1.60.1", "70888", "Nov 10 2026", 16001 end
SlashCmdList = {}
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_Warhorn = TocMeta("Peon_Warhorn") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function(n) return n ~= "Blizzard_GroupFinder" end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Warhorn" })[i] end }
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
  function m.HookScript(s, n, f) s.scripts[n] = f end
  function m.SetText(s, t) s.text = t end
  function m.SetChecked(s, v) s.checked = v end
  function m.GetChecked(s) return s.checked end
  function m.IsShown(s) return s.shown end
  function m.SetAlpha(s, a) s.alpha = a end
  function m.SetPoint(s, ...) s.points[#s.points+1] = { ... } end
  function m.ClearAllPoints(s) s.points = {} end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.RegisterUnitEvent(s, e) s.unitev[e] = true end
  function m.UnregisterAllEvents(s) s.events = {}; s.unitev = {} end
  function m.CreateFontString() return W() end
  function m.CreateTexture() return W() end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" then return function() end end end })
end
function CreateFrame(kind) local f = W(); f.kind = kind; allFrames[#allFrames+1] = f; return f end
local cats = {}
Settings = { RegisterCanvasLayoutCategory = function(p, n) local c = { name = n, subs = {}, GetID = function() return n end } cats[n] = c return c end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) table.insert(par.subs, n) return { GetID = function() return par.name .. "/" .. n end } end,
  RegisterAddOnCategory = function(c) c.registered = true end,
  OpenToCategory = function(id) print("OPEN " .. id) end }
-- Zeitgeber merken und von Hand ablaufen lassen
local timers = {}
C_Timer = { After = function(sec, fn) timers[#timers+1] = { at = now + sec, fn = fn } end }
local function advance(sec)
  now = now + sec
  local again = true
  while again do
    again = false
    for i, t in ipairs(timers) do
      if t.at <= now then table.remove(timers, i); t.fn(); again = true; break end
    end
  end
end
local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end

-- Geheime Werte: Tabelle als Marke, Vergleich oder Rechnen damit wirft einen Fehler
local SECRET = setmetatable({}, { __eq = function() error("Vergleich mit geheimem Wert") end,
  __lt = function() error("Vergleich mit geheimem Wert") end, __index = function() error("Lesen aus geheimem Wert") end })
function issecretvalue(v) return rawequal(v, SECRET) end

-- Nachbau der Gruppensuche
local searches = {}
local results = {
  [11] = { info = { searchResultID = 11, activityIDs = { 801 }, leaderName = "Thrall", name = "", comment = "BRD Run", numMembers = 2, isDelisted = false, age = 30 },
           counts = { TANK = 1, HEALER = 0, DAMAGER = 1, TANK_REMAINING = 0, HEALER_REMAINING = 1, DAMAGER_REMAINING = 2, WARRIOR = 1, MAGE = 1 },
           members = { { name = "Thrall", classFilename = "WARRIOR", level = 60, assignedRole = "TANK", lfgRoles = { tank = true }, isLeader = true },
                       { name = "Jaina", classFilename = "MAGE", level = 58, assignedRole = "DAMAGER", lfgRoles = { dps = true }, isLeader = false } } },
  [12] = { info = { searchResultID = 12, activityIDs = { 802 }, leaderName = SECRET, comment = SECRET, numMembers = 1, isDelisted = false, age = 5 },
           counts = { HEALER = 1 },
           members = { { name = SECRET, classFilename = "PRIEST", level = 60, assignedRole = "HEALER", lfgRoles = { healer = true }, isLeader = true } } },
}
local blockAuto = true
C_LFGList = {
  Search = function(cat, filter, pref, lang, cross, adv, acts) searches[#searches+1] = { cat = cat, acts = acts }
    if blockAuto and #searches == 2 then fire("ADDON_ACTION_BLOCKED", "Peon_Warhorn", "C_LFGList.Search()") end end,
  GetSearchResults = function() return 2, { 11, 12 } end,
  GetFilteredSearchResults = function() return 2, { 11, 12 } end,
  GetSearchResultInfo = function(id) return results[id].info end,
  GetSearchResultMemberCounts = function(id) return results[id].counts end,
  GetSearchResultLeaderInfo = function(id) return results[id].members[1] end,
  GetSearchResultPlayerInfo = function(id, i) return results[id].members[i] end,
  GetAvailableCategories = function() return { 2, 5 } end,
  GetAvailableActivities = function(cat) return { 801, 802 } end,
  GetLfgCategoryInfo = function(id) return { name = id == 2 and "Dungeons" or "Raids" } end,
}
C_LFGListRoles = { GetRoles = function() return { tank = false, healer = true, dps = true } end }
LFGBrowseFrame = { IsShown = function() return true end,
  CategoryDropdown = { GetValue = function() return 2 end }, ActivityDropdown = { selectedValues = {} } }
LFGParentFrame = { IsShown = function() return true end }

-- ===== Laden =====
load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
local ns = load("Peon_Warhorn", "Peon_Warhorn")
fire("ADDON_LOADED", "Peon_Warhorn")
local mod = ns.mod
check(mod.initialized and mod.page, "Modul + Optionsseite")
check(type(PeonWarhornDB.probe) == "table", "probe angelegt")
fire("PLAYER_LOGIN")
check(cats.Peon and cats.Peon.subs[1] == "Warhorn", "Seite unter Peon > Warhorn")
SlashCmdList.PEON("warhorn")
check(out[#out] == "OPEN Peon/Warhorn", "/peon warhorn oeffnet Seite")
check(ns.Probe.LastText():find("Noch keine"), "noch keine Pruefung")

-- ===== Kampf =====
combat = true
SlashCmdList.PEON("warhorn pruefen")
check(#searches == 0 and out[#out]:find("Kampf"), "im Kampf keine Suche")
combat = false

-- ===== Lauf mit Tastendruck, Blockade bei der zweiten Suche =====
SlashCmdList.PEON("warhorn pruefen")
check(#searches == 1 and searches[1].cat == 2, "erste Suche mit Kategorie aus Blizzards Auswahl")
check(#searches[1].acts == 2, "ohne Auswahl alle Aktivitaeten der Kategorie")
local p = PeonWarhornDB.probe
check(p.source == "key" and p.categoryName == "Dungeons", "Quelle und Kategorie gemerkt")
check(p.env.frames.LFGBrowseFrame == "sichtbar" and p.env.frames.PVEFrame == "fehlt", "Fenster erkannt")
check(p.env.addons.Blizzard_GroupFinder == "nicht geladen" and p.env.funcs.Search == true and p.env.funcs.ApplyToGroup == false, "Addons und Funktionen erkannt")
SlashCmdList.PEON("warhorn pruefen")
check(#searches == 1 and out[#out]:find("läuft noch"), "kein zweiter Lauf")

fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
local s1 = p.steps[1]
check(s1.answer == "Ergebnisse" and s1.total == 2 and #s1.results == 2, "Ergebnisse der ersten Suche gelesen")
local r1 = s1.results[1]
check(r1.info.leaderName == "<Text, 6 Zeichen>" and r1.info.name == "<leer>" and r1.info.comment == "<Text, 7 Zeichen>", "Namen und Texte nicht gespeichert")
check(r1.members[1].name == "<Text, 6 Zeichen>" and r1.members[2].classFilename == "MAGE", "Mitglieder ohne Namen, mit Klasse")
check(r1.members[1].lfgRoles.tank == true and r1.counts.HEALER_REMAINING == 1, "Rollen und Anzahl je Rolle")
check(r1.fields:find("numMembers"), "Feldliste")
local r2 = s1.results[2]
check(r2.info.leaderName == "<geheim>" and r2.info.comment == "<geheim>" and r2.members[1].name == "<geheim>", "geheime Werte nur markiert")
check(p.secrets >= 3, "geheime Werte gezaehlt")

advance(3)
check(#searches == 2, "zweite Suche von selbst nach Zeitgeber")
check(p.blocked and p.blocked[1].func == "C_LFGList.Search()" and p.steps[2].blocked == true, "Blockade gemerkt")
advance(8)
check(p.steps[2].answer == "keine Antwort", "ohne Antwort nach Wartezeit")
check(p.watch ~= nil, "Beobachten laeuft")
fire("LFG_LIST_SEARCH_RESULT_UPDATED", 11)
fire("LFG_LIST_SEARCH_RESULT_UPDATED", SECRET)
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check(p.watch.updates == 2 and p.watch.ids[2] == "<geheim>" and p.watch.received == 1, "Aktualisierungen gezaehlt")
advance(60)
check(p.done and p.summary and #p.summary == 4, "Zusammenfassung")
check(p.summary[1]:find("Tastendruck: 2 Ergebnisse") and p.summary[2]:find("blockiert"), "Zusammenfassung zeigt Ergebnis und Blockade")
local hasReload = false for _, l in ipairs(out) do if l:find("/reload eingeben") then hasReload = true end end
check(hasReload, "Hinweis auf /reload")
check(ns.Probe._Running() == nil and ns.Probe.LastText():find("Letzte"), "Lauf beendet, Text auf der Seite")
local okSave = pcall(function() for _ in pairs(p) do end end)
check(okSave, "Ergebnis lesbar")

-- ===== Lauf per Knopf, Suche schlaegt fehl =====
blockAuto = false
searches = {}
ns.Probe.Start("click")
local p2 = PeonWarhornDB.probe
check(p2 ~= p and p2.source == "click", "neuer Lauf ersetzt den alten")
fire("LFG_LIST_SEARCH_FAILED", "throttled")
check(p2.steps[1].answer == "fehlgeschlagen" and p2.steps[1].reason == "throttled", "Fehlschlag gemerkt")
advance(3)
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check(p2.steps[2].answer == "Ergebnisse" and p2.steps[2].blocked == nil, "zweite Suche ohne Blockade")
advance(60)
check(p2.summary[1]:find("Klick: fehlgeschlagen") and p2.summary[2]:find("von selbst: 2"), "Zusammenfassung Knopf")

-- ===== Ohne Schnittstelle =====
local saved = C_LFGList
C_LFGList = nil
ns.Probe.Start("key")
check(out[#out]:find("Schnittstelle"), "ohne C_LFGList Hinweis")
C_LFGList = saved

-- Reset behaelt das Ergebnis
mod:ResetDefaults()
check(PeonWarhornDB.probe == p2, "Standardwerte behalten das Ergebnis")

local n = 0 for _, l in ipairs(out) do if l:find("Fehler") then n = n + 1 end end
check(n == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
