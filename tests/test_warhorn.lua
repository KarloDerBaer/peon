-- Test fuer Peon + Peon_Warhorn (ab 0.2.0 Gruppensuche mit Filtern, dazu der Pruefaufbau aus 0.1.0)
-- Nachgebaute Rahmen ohne Blizzards Vorlagen (Rueckfall-Wege der Peon-Bausteine) und nachgebaute Gruppensuche.
-- Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
local now = 100
function GetTime() return now end
date, time = os.date, os.time
local combat = false
function InCombatLockdown() return combat end
function UnitAffectingCombat() return false end
function GetBuildInfo() return "1.60.1", "70888", "Nov 10 2026", 16001 end
function UnitClass() return "Priester", "PRIEST" end
local inGroup, leader = false, false
function IsInGroup() return inGroup end
function UnitIsGroupLeader() return leader end
function UnitIsGroupAssistant() return false end
function hooksecurefunc(t, name, fn) local old = t[name] t[name] = function(...) local r = old and old(...) fn(...) return r end end
SlashCmdList, UISpecialFrames = {}, {}
local cats = {}
Settings = { RegisterCanvasLayoutCategory = function(p, n) local c = { name = n, subs = {}, GetID = function() return n end } cats[n] = c return c end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) table.insert(par.subs, n) return { GetID = function() return par.name .. "/" .. n end } end,
  RegisterAddOnCategory = function(c) c.registered = true end,
  OpenToCategory = function(id) print("OPEN " .. id) end }
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, PRIEST = { r = 1, g = 1, b = 1 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Krieger", PRIEST = "Priester", MAGE = "Magier", PALADIN = "Paladin" }
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_Warhorn = TocMeta("Peon_Warhorn") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function(n) return n ~= "Blizzard_GroupFinder" end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Warhorn" })[i] end }
C_Texture = { GetAtlasInfo = function() return { width = 10, height = 10 } end }

-- Rahmen-Nachbau (wie test_uidemo.lua) mit Ereignissen
local created = {}
local function W(kind)
  local o = { kind = kind, scripts = {}, w = 0, h = 0, shown = true, txt = "", checked = false, enabled = true, points = {}, events = {} }
  local m = {}
  function m.SetSize(s, w, h) s.w, s.h = w, h end
  function m.SetWidth(s, w) s.w = w end
  function m.SetHeight(s, h) s.h = h end
  function m.GetWidth(s) return s.w end
  function m.GetHeight(s) return s.h end
  function m.GetStringWidth(s) return #(s.txt or "") * 6 end
  function m.GetStringHeight() return 12 end
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
  function m.GetFrameLevel(s) return s.level or 1 end
  function m.SetFrameLevel(s, l) s.level = l end
  function m.SetTextColor(s, r, g, b) s.color = { r, g, b } end
  function m.GetPoint(s, i) local p = s.points[i or 1] if p then return unpack(p) end end
  function m.SetValue(s, v) s.value = v end
  function m.GetValue(s) return s.value end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.UnregisterAllEvents(s) s.events = {} end
  function m.CreateFontString() return W("FontString") end
  function m.CreateTexture() return W("Texture") end
  function m.CreateMaskTexture() return W("MaskTexture") end
  return setmetatable(o, { __index = function(_, k)
    if m[k] then return m[k] end
    if type(k) == "string" and k:match("^%u") and k ~= "Text" and k ~= "Bg" and k ~= "NineSlice" and k ~= "Icon" and k ~= "Low" and k ~= "High" and k ~= "CloseButton" and k ~= "CategoryDropdown" and k ~= "ActivityDropdown" then return function() end end
  end })
end
UIParent = W("Frame")
GameTooltip = W("GameTooltip")
local tipLines = {}
GameTooltip.AddLine = function(_, t) tipLines[#tipLines + 1] = t end
GameTooltip.SetText = function(_, t) tipLines = { t } end
function CreateFrame(kind, name, parent, tmpl)
  if tmpl and tmpl ~= "UIPanelButtonTemplate" and tmpl ~= "InputBoxTemplate" and tmpl ~= "UICheckButtonTemplate" then error("Couldn't find inherited node \"" .. tmpl .. "\"") end
  local f = W(kind)
  f.name, f.parent, f.tmpl = name, parent, tmpl
  if kind == "Button" then
    local fs = W("FontString")
    f.GetFontString = function() return fs end
    f.SetText = function(s, t) s.txt = t; fs.txt = t end
  end
  if name then _G[name] = f end
  created[#created + 1] = f
  return f
end
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
local function fire(e, ...) for _, f in ipairs(created) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do l = l:gsub("\r", "") if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end
local function said(text) for i = #out, math.max(1, #out - 12), -1 do if out[i]:find(text, 1, true) then return true end end return false end

-- Geheime Werte: Tabelle als Marke, Vergleich oder Rechnen damit wirft einen Fehler
local SECRET = setmetatable({}, { __eq = function() error("Vergleich mit geheimem Wert") end,
  __lt = function() error("Vergleich mit geheimem Wert") end, __index = function() error("Lesen aus geheimem Wert") end })
function issecretvalue(v) return rawequal(v, SECRET) end

-- ===== Nachbau der Gruppensuche =====
local function P(name, class, level, role, roles, isLeader)
  return { name = name, classFilename = class, className = LOCALIZED_CLASS_NAMES_MALE[class], level = level, assignedRole = role, lfgRoles = roles, isLeader = isLeader }
end
local results, order
local function Group(id, acts, members, counts, extra)
  local info = { searchResultID = id, activityIDs = acts, leaderName = members[1].name, name = "", comment = "", numMembers = #members, isDelisted = false, age = 30 }
  for k, v in pairs(extra or {}) do info[k] = v end
  results[id] = { info = info, counts = counts, members = members }
end
local function Fill()
  results, order = {}, { 11, 12, 13, 21, 22, 31 }
  -- Gruppe sucht Heiler (Krieger Tank, Magier Schaden), Stufe 28 bis 33
  Group(11, { 801 }, { P("Thrall", "WARRIOR", 33, "TANK", { tank = true }, true), P("Jaina", "MAGE", 28, "DAMAGER", { dps = true }) },
    { TANK = 1, HEALER = 0, DAMAGER = 1, TANK_REMAINING = 0, HEALER_REMAINING = 1, DAMAGER_REMAINING = 2 })
  -- Gruppe mit Priester als Heiler, sucht nur Schaden, Stufe 58 bis 60
  Group(12, { 801, 802 }, { P("Anduin", "PRIEST", 60, "HEALER", { healer = true }, true), P("Varian", "WARRIOR", 58, "TANK", { tank = true }), P("Khadgar", "MAGE", 59, "DAMAGER", { dps = true }) },
    { TANK = 1, HEALER = 1, DAMAGER = 1, TANK_REMAINING = 0, HEALER_REMAINING = 0, DAMAGER_REMAINING = 2 })
  -- Gruppe mit vier Mitgliedern, sucht Heiler, Paladin dabei
  Group(13, { 802 }, { P("Uther", "PALADIN", 40, "TANK", { tank = true }, true), P("A", "MAGE", 40, "DAMAGER", {}), P("B", "MAGE", 41, "DAMAGER", {}), P("C", "ROGUE", 39, "DAMAGER", {}) },
    { TANK = 1, HEALER = 0, DAMAGER = 3, TANK_REMAINING = 0, HEALER_REMAINING = 1, DAMAGER_REMAINING = 0 })
  -- Einzelspieler: Priester Heiler 60, Magier Schaden 30
  Group(21, { 801 }, { P("Tyrande", "PRIEST", 60, "HEALER", { healer = true }, true) }, { HEALER = 1, TANK_REMAINING = 1, HEALER_REMAINING = 0, DAMAGER_REMAINING = 3 })
  Group(22, { 802 }, { P("Medivh", "MAGE", 30, "DAMAGER", { dps = true }, true) }, { DAMAGER = 1, TANK_REMAINING = 1, HEALER_REMAINING = 1, DAMAGER_REMAINING = 2 })
  -- Gruppe mit geheimem Anfuehrer
  Group(31, { 801 }, { P(SECRET, "WARRIOR", 50, "TANK", { tank = true }, true), P("D", "MAGE", 50, "DAMAGER", {}) },
    { TANK = 1, DAMAGER = 1, TANK_REMAINING = 0, HEALER_REMAINING = 1, DAMAGER_REMAINING = 2 }, { leaderName = SECRET })
end
Fill()
local searches = {}
local blockAuto = true
C_LFGList = {
  Search = function(cat, filter, pref, lang, cross, adv, acts) searches[#searches+1] = { cat = cat, acts = acts }
    if blockAuto and #searches == 2 then fire("ADDON_ACTION_BLOCKED", "Peon_Warhorn", "C_LFGList.Search()") end end,
  GetSearchResults = function() local ids = {} for _, id in ipairs(order) do if results[id] then ids[#ids+1] = id end end return #ids, ids end,
  GetFilteredSearchResults = function() return C_LFGList.GetSearchResults() end,
  GetSearchResultInfo = function(id) return results[id] and results[id].info end,
  GetSearchResultMemberCounts = function(id) return results[id] and results[id].counts end,
  GetSearchResultLeaderInfo = function(id) return results[id] and results[id].members[1] end,
  GetSearchResultPlayerInfo = function(id, i) return results[id] and results[id].members[i] end,
  GetAvailableCategories = function() return { 2, 5 } end,
  GetAvailableActivities = function(cat) return cat == 2 and { 801, 802 } or { 901 } end,
  GetLfgCategoryInfo = function(id) return { name = id == 2 and "Dungeons" or "Raids" } end,
  GetActivityInfoTable = function(id) return { fullName = ({ [801] = "Kloster", [802] = "Uldaman", [901] = "Geschmolzener Kern" })[id] } end,
}
C_LFGListRoles = { GetRoles = function() return { tank = false, healer = true, dps = false } end }
local invited, told, menus = {}, {}, {}
C_PartyInfo = { InviteUnit = function(n) invited[#invited+1] = n end }
ChatFrameUtil = { SendTell = function(n) told[#told+1] = n end }
MenuUtil = { CreateContextMenu = function(owner, gen) menus[#menus+1] = gen end }
local toggled = {}
function LFGVanilla_ToggleFrame(tab) toggled[#toggled+1] = tab end
local hidden = 0
function HideUIPanel() hidden = hidden + 1 end
-- Blizzards Fenster
LFGParentFrame = CreateFrame("Frame", "LFGParentFrame")
LFGParentFrame.h = 535
LFGBrowseFrame = CreateFrame("Frame", "LFGBrowseFrame", LFGParentFrame)
LFGBrowseFrame.CategoryDropdown = { GetValue = function() return 2 end }
LFGBrowseFrame.ActivityDropdown = { selectedValues = {} }
LFGParentFrameTab1 = CreateFrame("Button", "LFGParentFrameTab1", LFGParentFrame)

-- ===== Laden =====
load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
local ns = load("Peon_Warhorn", "Peon_Warhorn")
fire("ADDON_LOADED", "Peon_Warhorn")
local mod = ns.mod
check(mod.initialized and mod.page, "Modul + Optionsseite")
check(type(PeonWarhornDB.probe) == "table" and PeonWarhornDB.show == true, "Standardwerte")
check(PeonWarhornCharDB.gFilter.roles.healer == true and not PeonWarhornCharDB.gFilter.roles.tank, "Gruppenfilter startet mit meinen Rollen")
fire("PLAYER_LOGIN")
local O, Win, S, F = ns.Overlay, ns.Window, ns.Search, ns.Filter
local f = PeonWarhornFrame
check(O.built and f and f.parent == LFGBrowseFrame, "Flaeche haengt an Blizzards Suchseite")
local anchoredToTab = false
for _, p in ipairs(f.points) do if p[2] == LFGParentFrameTab1 then anchoredToTab = true end end
check(anchoredToTab and f.w == 680, "endet ueber Blizzards Reitern, 680 breit")
check(f.shown and not O.button.shown, "Warhorn sichtbar, Knopf an Blizzards Fenster versteckt")
check(PeonWarhornCharDB.category == 2, "Kategorie aus Blizzards Auswahl")
check(Win.statusText == "Noch nicht gesucht", "Statuszeile vor der ersten Suche")
local function Errors() local t = {} for _, e in ipairs(PeonDB.errors or {}) do t[#t+1] = tostring(e.where) .. ": " .. tostring(e.msg) end return table.concat(t, " | ") end
check(#(PeonDB.errors or {}) == 0, "keine Fehler beim Aufbau " .. Errors())

-- ===== Suchen per Knopf =====
Win.searchBtn.scripts.OnClick()
check(#searches == 1 and searches[1].cat == 2 and #searches[1].acts == 2, "Knopf sucht mit allen Aktivitaeten der Kategorie")
check(S.searching and Win.statusText == "Suche läuft...", "Suche laeuft")
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check(#S.list == 6 and not S.searching, "sechs Eintraege gelesen")
local e11, e21, e31 = S.entries[11], S.entries[21], S.entries[31]
check(e11.free.HEALER == 1 and e11.classes.WARRIOR == 1 and e11.levelMin == 28 and e11.levelMax == 33, "Gruppe: freie Plaetze, Klassen, Stufen")
check(e11.activityText == "Kloster" and S.entries[12].activityText == "2 Aktivitäten", "Name der Aktivitaet")
check(e21.isSolo and e21.playerRoles.healer and e21.leaderClass == "PRIEST", "Einzelspieler mit Rolle und Klasse")
check(e31.secret and e31.leaderName == nil, "geheimer Anfuehrer erkannt, nicht benutzt")
check(not e11.isNew, "erste Suche markiert nichts als neu")

-- Reiter Gruppen mit Heiler-Filter: 11 und 13 (freier Heilerplatz) und 31 (geheim, nie gefiltert)
check(Win.counts.groups == 3 and Win.counts.players == 2, "Zahlen an den Reitern")
check(Win.statusText:find("3 von 4 Einträgen"), "Statuszeile zeigt Treffer")
local g = PeonWarhornCharDB.gFilter
g.classes.WARRIOR = true
Win.Update()
check(Win.counts.groups == 2, "nur Gruppen mit Krieger (11 und geheim)")
g.mode = "without"
Win.Update()
check(Win.counts.groups == 2, "nur Gruppen ohne Krieger (13 und geheim)")
g.classes = {}
g.mode = "with"
g.roles = {}
Win.Update()
check(Win.counts.groups == 4, "ohne Rollenfilter alle vier Gruppen")
g.noMyClass = true
Win.Update()
check(Win.counts.groups == 3, "ohne meine Klasse blendet die Gruppe mit Priester aus")
g.noMyClass = false
g.sizeMax = 3
Win.Update()
check(Win.counts.groups == 3, "hoechstens drei Mitglieder")
g.sizeMax = 0
Win.lvlMin:SetText("50")
Win.lvlMin.scripts.OnTextChanged(Win.lvlMin, true)
check(g.levelMin == 50 and Win.counts.groups == 2, "Stufe ab 50 (12 und geheim)")
Win.lvlMin:SetText("")
Win.lvlMin.scripts.OnTextChanged(Win.lvlMin, true)
check(g.levelMin == 0, "Stufe geleert")
Win.roleChecks.healer:SetChecked(true)
Win.roleChecks.healer.scripts.OnClick(Win.roleChecks.healer)
check(g.roles.healer == true and Win.counts.groups == 3, "Haken Heiler an")
Win.roleChecks.healer:SetChecked(false)
Win.roleChecks.healer.scripts.OnClick(Win.roleChecks.healer)
check(not g.roles.healer and Win.counts.groups == 4, "Haken Heiler aus")
Win.roleChecks.healer:SetChecked(true)
Win.roleChecks.healer.scripts.OnClick(Win.roleChecks.healer)

-- ===== Reiter Mitspieler =====
Win.tabs:Select("players")
check(PeonWarhornCharDB.tab == "players" and Win.panels.players.shown and not Win.panels.groups.shown, "Reiter Mitspieler")
check(not Win.roleChecks.healer.checked, "Haken zeigen den Filter der Mitspieler")
local p = PeonWarhornCharDB.pFilter
p.roles.healer = true
Win.Update()
check(Win.counts.players == 1 and Win.tables.players.items[1] == e21, "Mitspieler Heiler")
p.roles = {}
p.classes.MAGE = true
Win.Update()
check(Win.counts.players == 1 and Win.tables.players.items[1].leaderClass == "MAGE", "Mitspieler Klasse Magier")
p.classes = {}
p.levelMax = 40
Win.Update()
check(Win.counts.players == 1, "Mitspieler bis Stufe 40")
p.levelMax = 0

-- ===== Spalten und Tooltip =====
check(Win.RolesText(e11):find("groupfinder%-icon%-role%-large%-heal:14:14|a0|cff40ff40%+1"), "Rollen mit freiem Platz in Gruen")
check(Win.ClassesText(e11):find("groupfinder%-icon%-class%-warrior"), "Klassensymbole")
check(Win.LevelText(e11) == "28-33" and Win.LevelText(e21) == "60", "Stufen")
Win.ShowTooltip(UIParent, S.entries[12])
local joined = table.concat(tipLines, "\n")
check(joined:find("Kloster") and joined:find("Uldaman") and joined:find("Anduin"), "Tooltip mit Aktivitaeten und Mitgliedern")
Win.ShowTooltip(UIParent, e31)
check(table.concat(tipLines, "\n"):find("geheim"), "Tooltip nennt geheime Werte")

-- ===== Aktionen =====
Win.OnRowClick(e21, "LeftButton")
now = now + 0.2
Win.OnRowClick(e21, "LeftButton")
check(told[1] == "Tyrande", "Doppelklick fluestert an")
Win.OnRowClick(e11, "LeftButton")
now = now + 1
Win.OnRowClick(e11, "LeftButton")
check(#told == 1, "zwei langsame Klicks sind kein Doppelklick")
local function Menu(e)
  Win.OnRowClick(e, "RightButton")
  local items = {}
  local root = { CreateTitle = function(_, t) items.title = t end,
    CreateButton = function(_, t, fn) local b = { text = t, fn = fn, enabled = true } b.SetEnabled = function(s, v) s.enabled = v end items[#items+1] = b return b end }
  menus[#menus](nil, root)
  return items
end
local items = Menu(e21)
check(items.title == "Tyrande" and items[2].enabled, "Menue: Einladen fuer Einzelspieler")
items[2].fn()
check(invited[1] == "Tyrande", "Einladen")
items = Menu(e11)
check(not items[2].enabled, "Gruppen kann man nicht einladen")
inGroup = true
items = Menu(e21)
check(not items[2].enabled, "in einer Gruppe ohne Anfuehrer kein Einladen")
inGroup = false
items = Menu(e31)
check(not items[1].enabled, "geheimer Name: kein Anfluestern")

-- ===== Aktualisierung und neue Eintraege =====
results[11].members[3] = P("Malfurion", "DRUID", 30, "HEALER", { healer = true })
results[11].info.numMembers = 3
results[11].counts.HEALER, results[11].counts.HEALER_REMAINING = 1, 0
fire("LFG_LIST_SEARCH_RESULT_UPDATED", 11)
check(S.entries[11].numMembers == 3 and S.entries[11].free.HEALER == 0, "Aenderung ohne neue Suche uebernommen")
results[12] = nil
fire("LFG_LIST_SEARCH_RESULT_UPDATED", 12)
check(S.entries[12].isDelisted, "nicht mehr lesbar: als ausgetragen markiert")
fire("LFG_LIST_SEARCH_RESULT_UPDATED", SECRET)
check(true, "geheime ID ohne Fehler")
now = now + 70
Win.UpdateStatus()
check(Win.statusText:find("|cffffd100") and Win.statusText:find("Suchen klicken"), "alte Suche gold markiert")
Fill()
Group(41, { 801 }, { P("Rexxar", "WARRIOR", 35, "TANK", { tank = true }, true) }, { TANK = 1, TANK_REMAINING = 0, HEALER_REMAINING = 1, DAMAGER_REMAINING = 3 })
order[#order+1] = 41
PeonWarhorn_Search()
check(#searches == 2, "Taste sucht")
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check(S.entries[41].isNew and not S.entries[11].isNew, "neue Eintraege markiert")
Win.searchBtn.scripts.OnClick()
fire("LFG_LIST_SEARCH_FAILED", "throttled")
check(Win.statusText:find("abgelehnt"), "Ablehnung in der Statuszeile")
combat = true
fire("PLAYER_REGEN_DISABLED")
check(not Win.searchBtn.enabled, "Suchen im Kampf gesperrt")
local before = #searches
PeonWarhorn_Search()
check(#searches == before and Win.statusText:find("Kampf"), "im Kampf keine Suche")
SlashCmdList.PEON_WARHORN("")
check(#toggled == 0 and said("Im Kampf"), "/warhorn im Kampf nicht")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(Win.searchBtn.enabled, "nach dem Kampf wieder frei")

-- ===== Auswahl =====
S.SetCategory(5)
check(PeonWarhornCharDB.category == 5 and #PeonWarhornCharDB.activities == 0, "andere Kategorie leert die Aktivitaeten")
S.ToggleActivity(901)
check(S.IsActivitySelected(901), "Aktivitaet gewaehlt")
Win.searchBtn.scripts.OnClick()
check(searches[#searches].cat == 5 and searches[#searches].acts[1] == 901 and #searches[#searches].acts == 1, "Suche mit gewaehlter Aktivitaet")
S.ToggleActivity(901)
check(not S.IsActivitySelected(901), "Aktivitaet abgewaehlt")

-- ===== Umschalten =====
Win.tabs:Select("groups")
O.SetShow(false)
check(not f.shown and O.button.shown and PeonWarhornDB.show == false, "Knopf Blizzard zeigt Blizzards Seite")
O.button.scripts.OnClick()
check(f.shown and not O.button.shown and PeonWarhornDB.show == true, "Knopf Warhorn holt Warhorn zurueck")
PeonWarhornDB.show = false
mod:Fire("CHANGED", "show")
check(not f.shown, "Haken in den Optionen schaltet um")
PeonWarhornDB.show = true
mod:Fire("CHANGED", "show")
check(f.shown, "Haken wieder an")
SlashCmdList.PEON_WARHORN("")
check(toggled[1] == 2, "/warhorn oeffnet die Gruppensuche auf dem Reiter Suchen")
SlashCmdList.PEON_WARHORN("optionen")
check(said("OPEN Peon/Warhorn"), "/warhorn optionen")
SlashCmdList.PEON("warhorn")
check(said("OPEN Peon/Warhorn") and #toggled == 1, "/peon warhorn oeffnet die Optionen")

-- Standardwerte setzen die Filter zurueck und behalten Auswahl und Pruefung
PeonWarhornCharDB.gFilter.classes.MAGE = true
mod:ResetDefaults()
check(next(PeonWarhornCharDB.gFilter.classes) == nil and PeonWarhornCharDB.gFilter.roles.healer, "Standardwerte setzen Filter zurueck")
check(PeonWarhornCharDB.category == 5, "Standardwerte behalten die Kategorie")

-- ===== Pruefaufbau aus 0.1.0 =====
searches = {}
blockAuto = true
Fill()
SlashCmdList.PEON("warhorn pruefen")
check(#searches == 1 and searches[1].cat == 2, "Pruefung: erste Suche")
local pr = PeonWarhornDB.probe
check(pr.source == "key" and pr.env.frames.LFGBrowseFrame == "sichtbar" and pr.env.frames.PVEFrame == "fehlt", "Pruefung: Fenster erkannt")
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
local s1 = pr.steps[1]
check(s1.answer == "Ergebnisse" and s1.total == 6, "Pruefung: Ergebnisse gelesen")
check(s1.results[1].info.leaderName == "<Text, 6 Zeichen>" and s1.results[1].members[1].name == "<Text, 6 Zeichen>", "Pruefung: Namen nicht gespeichert")
check(s1.results[6].info.leaderName == "<geheim>", "Pruefung: geheime Werte nur markiert")
advance(3)
check(#searches == 2 and pr.blocked and pr.steps[2].blocked, "Pruefung: zweite Suche blockiert")
advance(8)
fire("LFG_LIST_SEARCH_RESULT_UPDATED", 11)
advance(60)
check(pr.done and pr.summary[1]:find("Tastendruck: 6 Ergebnisse") and pr.summary[2]:find("blockiert") and pr.watch.updates == 1, "Pruefung: Zusammenfassung")
combat = true
ns.Probe.Start("click")
check(said("Im Kampf"), "Pruefung: nicht im Kampf")
combat = false

-- ===== Ohne Gruppensuche =====
local saved = LFGVanilla_ToggleFrame
LFGVanilla_ToggleFrame = nil
SlashCmdList.PEON_WARHORN("")
check(said("nicht verfügbar"), "ohne Blizzards Gruppensuche ein Hinweis")
LFGVanilla_ToggleFrame = saved

check(#(PeonDB.errors or {}) == 0, "keine gespeicherten Fehler " .. Errors())
local n = 0 for _, l in ipairs(out) do if l:find("Fehler") and not l:find("^ok ") then n = n + 1 end end
check(n == 0, "keine Fehlermeldungen im Chat")
print("ALLE TESTS OK")
