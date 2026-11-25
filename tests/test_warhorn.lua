-- Test fuer Peon + Peon_Warhorn (ab 0.2.0 Gruppensuche mit Filtern, ab 0.3.0 Seiten Eintragen, Wer-Liste,
-- Einstellungen und Fluesterfenster, dazu der Pruefaufbau aus 0.1.0)
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
function UnitName() return "Ich" end
function UnitLevel() return 34 end
function GetRealZoneText() return "Eisenschmiede" end
function UnitGroupRolesAssigned() return "NONE" end
Enum = { SocialWhoOrigin = { Social = 1 }, LFGEntryGeneralPlaystyle = { Learning = 1, FunRelaxed = 2, FunSerious = 3, Expert = 4 } }
local chat = {}
function SendChatMessage(text, kind, lang, to) chat[#chat+1] = { text = text, kind = kind, to = to } end
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
  function m.SetFrameStrata(s, v) s.strata = v end
  function m.SetHitRectInsets(s, l, r, t, b) s.hit = { l, r, t, b } end
  function m.EnableMouse(s, v) s.mouse = v end
  function m.IsVisible(s) local x = s while x do if not x.shown then return false end x = x.parent end return true end
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
  if tmpl and tmpl ~= "UIPanelButtonTemplate" and tmpl ~= "InputBoxTemplate" and tmpl ~= "UICheckButtonTemplate" and tmpl ~= "WowStyle1FilterDropdownTemplate" and tmpl ~= "WowStyle1DropdownTemplate" then error("Couldn't find inherited node \"" .. tmpl .. "\"") end
  local f = W(kind)
  f.name, f.parent, f.tmpl = name, parent, tmpl
  if kind == "Button" then
    local fs = W("FontString")
    f.GetFontString = function() return fs end
    f.SetText = function(s, t) s.txt = t; fs.txt = t end
  end
  if kind == "DropdownButton" then
    f.Text = W("FontString")
    f.SetupMenu = function(s, gen) s.menuGen = gen end
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
local myRoles = { tank = false, healer = true, dps = false }
C_LFGListRoles = { GetRoles = function() return { tank = myRoles.tank, healer = myRoles.healer, dps = myRoles.dps } end,
  SetRoles = function(t) myRoles = t end }
-- Eintragen (ab 0.3.0)
local active, listings = nil, {}
C_LFGList.HasActiveEntryInfo = function() return active ~= nil end
C_LFGList.GetActiveEntryInfo = function() return active end
C_LFGList.CreateListing = function(d) listings[#listings+1] = { "create", d } end
C_LFGList.UpdateListing = function(d) listings[#listings+1] = { "update", d } end
C_LFGList.RemoveListing = function() listings[#listings+1] = { "remove" } end
-- Wer-Liste (ab 0.3.0)
local whos, whoResults = {}, {}
C_FriendList = { SendWho = function(text, origin, filters) whos[#whos+1] = { text = text, origin = origin } end,
  GetNumWhoResults = function() return #whoResults, #whoResults end,
  GetWhoInfo = function(i) return whoResults[i] end }
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
LFGListingFrame = CreateFrame("Frame", "LFGListingFrame", LFGParentFrame)
LFGListingFrame.shown = false
local blizzCat
LFGListingFrame.SetCategorySelection = function(self, c) blizzCat = c end
LFGListingFrame.GetCategorySelection = function() return blizzCat end
LFGListingComment = { EditBox = { GetText = function() return "Suche Heiler" end } }
LFGWhoListFrame = CreateFrame("Frame", "LFGWhoListFrame", LFGParentFrame)
LFGWhoListFrame.shown = false
LFGParentFrameTab1 = CreateFrame("Button", "LFGParentFrameTab1", LFGParentFrame)
LFGParentFrame.selectedTab = 2
local tab2Clicks = 0
function LFGParentFrameTab2_OnClick()
  tab2Clicks = tab2Clicks + 1
  LFGParentFrame.selectedTab = 2
  LFGBrowseFrame.shown, LFGListingFrame.shown, LFGWhoListFrame.shown = true, false, false
  if LFGBrowseFrame.scripts.OnShow then LFGBrowseFrame.scripts.OnShow(LFGBrowseFrame) end
end

-- ===== Laden =====
load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
local ns = load("Peon_Warhorn", "Peon_Warhorn")
fire("ADDON_LOADED", "Peon_Warhorn")
local mod = ns.mod
check(mod.initialized and mod.page, "Modul + Optionsseite")
-- ab 0.6.0 nach dem Leitfaden: Knopf Gruppensuche oeffnen, Schalter, kein Pruefknopf (bleibt /peon warhorn pruefen)
do
  local texts = {}
  for _, c in ipairs(mod.page.controls) do if c.button then texts[#texts + 1] = c.label end end
  check(#texts == 1 and texts[1] == "Gruppensuche öffnen" and mod.page.controls[3].hint, "Optionsseite ohne Pruefknopf, Hinweis als Tooltip")
end
check(type(PeonWarhornDB.probe) == "table" and PeonWarhornDB.show == true, "Standardwerte")
check(PeonWarhornCharDB.gFilter.roles.healer == true and not PeonWarhornCharDB.gFilter.roles.tank, "Gruppenfilter startet mit meinen Rollen")
fire("PLAYER_LOGIN")
local O, Win, S, F = ns.Overlay, ns.Window, ns.Search, ns.Filter
local f = PeonWarhornFrame
check(O.built and f and f.parent == LFGParentFrame, "Fenster haengt an Blizzards Gruppensuche")
check(Win.page == "search" and Win.pages.search.shown and not Win.pages.listing.shown, "Seite Suchen zu Blizzards Reiter Suchen")
local anchoredToTab = false
for _, p in ipairs(f.points) do if p[2] == LFGParentFrameTab1 then anchoredToTab = true end end
check(anchoredToTab and f.w == 800, "alter Stil: endet ueber Blizzards Reitern, 800 breit wie Ledger")
check(f.shown and not O.button.shown, "Warhorn sichtbar, Knopf an Blizzards Fenster versteckt")
check(PeonWarhornCharDB.category == 2, "Kategorie aus Blizzards Auswahl")
check(Win.statusText == "Noch nicht gesucht", "Statuszeile vor der ersten Suche")
local function Errors() local t = {} for _, e in ipairs(PeonDB.errors or {}) do t[#t+1] = tostring(e.where) .. ": " .. tostring(e.msg) end return table.concat(t, " | ") end
check(#(PeonDB.errors or {}) == 0, "keine Fehler beim Aufbau " .. Errors())

-- ===== ab 0.2.1: Schicht, Maus, Stil, Reiter rechts, Oeffnen auf "Suchen" =====
check(f.strata == "HIGH" and f.level == 300, "Fenster liegt ueber Blizzards Rahmen und Blizzards Teilen in HIGH")
check(f.mouse == true and f.hit and f.hit[3] == 24, "Fenster faengt die Maus ab, Titelleiste ausgespart")
local blockers = 0
for _, c in ipairs(created) do if c.parent == f and c.kind == "Frame" and c.mouse == true then blockers = blockers + 1 end end
check(blockers == 0, "kein eigener Rahmen faengt Klicks vor den Bedienelementen ab")
-- moderner Stil: Blizzards Reiter unten versteckt, Reiter rechts am Fenster
LFGParentFrameTab1.shown = false
local side = CreateFrame("Frame", nil, LFGParentFrame)
side:SetPoint("TOPLEFT", LFGParentFrame, "TOPRIGHT", 0, -60)
LFGParentFrame.ListingTab = side
f.shown = false
f.scripts.OnHide()
f.shown = true
f.scripts.OnShow()
check(O.style == "modern" and #f.points == 1 and f.w == 800 and f.h == 538, "moderner Stil: so gross wie Ledger (800 x 538)")
-- Blizzards Schalter gilt, auch wenn die Reiter unten beim Oeffnen noch nicht versteckt sind
LFGParentFrameTab1.shown = true
LFGVANILLA_SETTING_MODERN_STYLE = true
O.Layout()
check(O.style == "modern" and f.h == 538, "moderner Stil an Blizzards Schalter erkannt")
LFGVANILLA_SETTING_MODERN_STYLE = nil
LFGParentFrameTab1.shown = false
O.Layout()
check(side.points[1][2] == f and side.points[1][3] == "TOPRIGHT" and side.points[1][5] == -60, "Reiter rechts wandern an Warhorns Rand")
f.shown = false
f.scripts.OnHide()
check(side.points[1][2] == LFGParentFrame and side.points[1][5] == -60, "Reiter rechts zurueck, wenn Warhorn weg ist")
f.shown = true
f.scripts.OnShow()
O.SetShow(false)
check(side.points[1][2] == LFGParentFrame, "Reiter rechts zurueck beim Umschalten zu Blizzard")
O.SetShow(true)
check(side.points[1][2] == f, "Reiter rechts wieder an Warhorn")
LFGParentFrameTab1.shown = true
O.Layout()
check(O.style == "classic", "alter Stil wieder erkannt")
-- ab 0.3.0: Blizzards Reiter Eintragen zeigt Warhorns Seite Eintragen
local function OnBlizzPage(key)
  LFGBrowseFrame.shown, LFGListingFrame.shown, LFGWhoListFrame.shown = key == "search", key == "listing", key == "who"
  LFGParentFrame.selectedTab = ({ listing = 1, search = 2, who = 3 })[key]
  local fr = ({ listing = LFGListingFrame, search = LFGBrowseFrame, who = LFGWhoListFrame })[key]
  fr.scripts.OnShow(fr)
end
OnBlizzPage("listing")
check(f.shown and Win.page == "listing" and Win.pages.listing.shown and not Win.pages.search.shown, "Reiter Eintragen: Warhorns Seite Eintragen")
local openBefore = #searches
LFGParentFrame.scripts.OnShow()
check(tab2Clicks == 0 and #searches == openBefore, "Oeffnen auf Eintragen bleibt dort, keine Suche")
-- ab 0.6.1 (Fehlerbericht 71): oeffnet ein anderes Addon ueber ShowSearchForActivities, sucht Warhorn nicht selbst
OnBlizzPage("search")
local oldStack = debugstack
debugstack = function() return "[Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Browse.lua]:248: in function 'ShowSearchForActivities'" end
S.searching, S.requestedAt = false, nil
local sfaBefore = #searches
LFGParentFrame.scripts.OnShow()
check(O.OpenedForSearch() and #searches == sfaBefore, "Oeffnen ueber ShowSearchForActivities: keine eigene Suche")
debugstack = function() return "[Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_ParentFrame.lua]:108" end
LFGParentFrame.scripts.OnShow()
check(not O.OpenedForSearch() and #searches == sfaBefore + 1, "normales Oeffnen auf Suchen sucht weiter gleich")
debugstack = oldStack
searches[#searches] = nil   -- die Suche dieses Tests zaehlt fuer die folgenden nicht
S.searching, S.requestedAt = false, nil
OnBlizzPage("listing")
OnBlizzPage("who")
check(f.shown and Win.page == "who", "Reiter Wer-Liste: Warhorns Wer-Liste")
-- ab 0.3.4: Warhorn immer eine Schicht ueber Blizzards Fenster
check(O.Above("MEDIUM") == "HIGH" and O.Above("DIALOG") == "FULLSCREEN" and O.Above("TOOLTIP") == "FULLSCREEN_DIALOG", "Schicht darueber")
-- Blizzards Teile in HIGH (Suchfeld der Wer-Liste): dort zaehlt die Ebene
LFGParentFrame.strata, LFGParentFrame.level = "MEDIUM", 1
LFGListingFrame.strata, LFGListingFrame.level = "HIGH", 501
LFGParentFrame.GetFrameStrata = function(s) return s.strata end
LFGListingFrame.GetFrameStrata = function(s) return s.strata end
f.GetFrameStrata = function(s) return s.strata end
LFGParentFrame.GetChildren = function() return LFGListingFrame, f, O.buttons.who end
local refreshedBefore = O.refreshed or 0
OnBlizzPage("listing")
check(f.strata == "HIGH" and f.level == 521 and O.refreshed == refreshedBefore, "normal: HIGH ueber Blizzards Teilen, kein Neueinblenden")
-- ForeverDungeonJournal setzt Blizzards Fenster samt Warhorn in DIALOG
LFGParentFrame.strata, LFGParentFrame.level = "DIALOG", 51
LFGListingFrame.strata, f.strata = "DIALOG", "DIALOG"
O.RaiseSoon()
advance(1)
check(f.strata == "FULLSCREEN" and O.strata == "FULLSCREEN", "nach dem Journal: Warhorn in FULLSCREEN")
check(O.refreshed == refreshedBefore + 1 and f.shown and not O.refreshing, "neue Schicht: einmal neu eingeblendet")
check(O.buttons.listing.strata == "FULLSCREEN", "Knopf Warhorn geht mit")
O.Raise()
check(O.refreshed == refreshedBefore + 1, "ohne Aenderung kein neues Einblenden")
local ovSrc = io.open("Peon_Warhorn/Overlay.lua"):read("*a")
check(ovSrc:find("parent:IsShown() then O.RaiseSoon() end", 1, true), "Aufbau bei offenem Fenster stoesst die Pruefungen an")
LFGParentFrame.strata, LFGListingFrame.strata = nil, nil
LFGParentFrame.GetFrameStrata, LFGListingFrame.GetFrameStrata, LFGParentFrame.GetChildren, f.GetFrameStrata = nil, nil, nil, nil
f.strata, f.level = Win.STRATA, Win.LEVEL
OnBlizzPage("who")
check(f.strata == "HIGH" and f.level == Win.LEVEL, "ohne Anheben bleibt Warhorn in HIGH auf Ebene 300")
-- Seite auf Blizzard: Oeffnen springt auf "Suchen"
O.SetReplace("who", false)
check(not f.shown and O.buttons.who.shown and not O.buttons.search.shown, "Wer-Liste auf Blizzard: Knopf Warhorn an Blizzards Seite")
check(mod.db.replace.who == false and mod.db.replace.search == true, "nur diese Seite umgeschaltet")
LFGParentFrame.scripts.OnShow()
check(tab2Clicks == 1 and LFGParentFrame.selectedTab == 2, "Oeffnen auf Blizzards Seite springt auf Suchen")
check(#searches == openBefore + 1 and Win.page == "search", "Oeffnen auf Suchen sucht gleich (ab 0.3.2)")
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
LFGParentFrame.scripts.OnShow()
check(#searches == openBefore + 1, "nicht noch einmal innerhalb weniger Sekunden")
now = now + 6
LFGParentFrame.scripts.OnShow()
check(#searches == openBefore + 2, "spaeter wieder")
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
now = now + 6
mod.db.show = false
LFGParentFrame.scripts.OnShow()
check(tab2Clicks == 1, "Warhorn aus: Blizzards Reiter bleibt")
check(#searches == openBefore + 2, "Warhorn aus: keine Suche beim Oeffnen")
mod.db.show = true
OnBlizzPage("who")
check(not f.shown, "Blizzards Wer-Liste")
O.buttons.who.scripts.OnClick(O.buttons.who)
check(mod.db.replace.who == true and f.shown and Win.page == "who", "Knopf Warhorn an Blizzards Wer-Liste holt Warhorn zurueck")
-- Reiter Einstellungen
local st = PeonWarhornSettingsTab
check(st and st.scripts.OnMouseUp, "eigener Reiter Einstellungen")
check(st.points[1][1] == "BOTTOMLEFT" and st.points[1][2] == f and st.points[1][3] == "BOTTOMRIGHT", "Reiter Einstellungen unten am rechten Rand")
-- Klick auf Blizzards Reiter Eintragen: Blizzard zeigt die neue Seite, bevor es die alte versteckt
LFGParentFrame.selectedTab = 1
LFGListingFrame.shown = true
LFGListingFrame.scripts.OnShow(LFGListingFrame)
check(Win.page == "listing" and f.shown, "Wechsel auf Eintragen, auch wenn die alte Seite noch offen ist")
LFGWhoListFrame.shown = false
OnBlizzPage("who")
st.scripts.OnMouseUp(st, "LeftButton")
check(O.settings and f.shown and Win.page == "settings" and Win.pages.settings.shown, "Reiter Einstellungen zeigt die Seite")
O.SetReplace("who", false)
check(f.shown and Win.page == "settings", "Einstellungen bleiben, auch wenn die Seite darunter Blizzard ist")
O.SetReplace("who", true)
OnBlizzPage("search")
check(not O.settings and Win.page == "search", "anderer Blizzard-Reiter verlaesst die Einstellungen")
-- Kategorien kommen spaeter vom Server
local savedCat = mod.db.category
mod.db.category = 0
fire("LFG_LIST_AVAILABILITY_UPDATE")
check(mod.db.category == 2, "Auswahl wird nachgeholt, sobald das Spiel die Kategorien meldet")
mod.db.category = savedCat
check(#(PeonDB.errors or {}) == 0, "keine Fehler bei Stil und Reitern " .. Errors())

-- ===== Suchen per Knopf =====
-- Suchen beim Oeffnen (ab 0.3.2) oben schon geprueft: hier wieder wie vor der ersten Suche
searches = {}
ns.Search.lastSearch, ns.Search.seen, ns.Search.entries, ns.Search.list, ns.Search.searching = nil, {}, {}, {}, false
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
check(#searches == 1, "Tippen in der Stufe sucht nicht")
Win.lvlMin.scripts.OnEnterPressed(Win.lvlMin)
check(#searches == 2, "Eingabetaste in der Stufe sucht neu")
Win.roleChecks.healer:SetChecked(true)
Win.roleChecks.healer.scripts.OnClick(Win.roleChecks.healer)
check(g.roles.healer == true and Win.counts.groups == 3, "Haken Heiler an")
Win.roleChecks.healer:SetChecked(false)
Win.roleChecks.healer.scripts.OnClick(Win.roleChecks.healer)
check(not g.roles.healer and Win.counts.groups == 4, "Haken Heiler aus")
Win.roleChecks.healer:SetChecked(true)
Win.roleChecks.healer.scripts.OnClick(Win.roleChecks.healer)
check(#searches == 5, "jeder Rollen-Haken sucht gleich neu")
-- Menues: Aktivitaeten und Filter suchen gleich neu
local function MenuRoot()
  local r = { items = {} }
  local function add(kind) return function(_, t, a, b) local it = { kind = kind, text = t, a = a, b = b } r.items[#r.items+1] = it return it end end
  r.CreateTitle, r.CreateButton, r.CreateCheckbox, r.CreateRadio, r.CreateDivider = add("title"), add("button"), add("check"), add("radio"), add("div")
  return r
end
local ar = MenuRoot()
Win.actDD.menuGen(nil, ar)
local firstAct
for _, it in ipairs(ar.items) do if it.kind == "check" then firstAct = it break end end
firstAct.b()
check(#searches == 6 and #PeonWarhornCharDB.activities == 1, "Aktivitaet im Menue sucht gleich neu")
ar.items[1].a()
check(#searches == 7 and #PeonWarhornCharDB.activities == 0, "Alle Aktivitaeten sucht gleich neu")
local fr = MenuRoot()
Win.filterDD.menuGen(nil, fr)
for _, it in ipairs(fr.items) do if it.kind == "radio" and it.text:find("3") then it.b() end end
check(#searches == 8 and g.sizeMax == 3, "Filtermenue sucht gleich neu")
g.sizeMax = 0
check(Win.actDD.Text.txt == "Filter", "Knopf der Aktivitaeten heisst Filter")
combat = true
Win.roleChecks.tank:SetChecked(true)
Win.roleChecks.tank.scripts.OnClick(Win.roleChecks.tank)
check(#searches == 8 and g.roles.tank, "im Kampf nur filtern, nicht suchen")
combat = false
Win.roleChecks.tank:SetChecked(false)
Win.roleChecks.tank.scripts.OnClick(Win.roleChecks.tank)
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
searches = { searches[1] }
e11, e21, e31 = S.entries[11], S.entries[21], S.entries[31]

-- ===== Reiter Mitspieler =====
Win.tabs:Select("players")
check(PeonWarhornCharDB.tab == "players" and Win.panels.players.shown and not Win.panels.groups.shown, "Reiter Mitspieler")
check(not Win.roleChecks.healer.checked, "Haken zeigen den Filter der Mitspieler")
local p = PeonWarhornCharDB.pFilter
p.roles.healer = true
Win.Update()
check(Win.counts.players == 1 and Win.tables.players.items[1].id == 21, "Mitspieler Heiler")
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
check(Win.RolesText(e11):find("groupfinder%-icon%-role%-large%-heal:14:14|a|cff40ff400|r") and not Win.RolesText(e11):find("%+"), "Rollen ohne +n, freier Platz als gruene Zahl")
check(Win.ClassesText(e11):find("groupfinder%-icon%-class%-warrior"), "Klassensymbole")
check(Win.LevelText(e11) == "28-33" and Win.LevelText(e21) == "60", "Stufen")
Win.ShowTooltip(UIParent, S.entries[12])
local joined = table.concat(tipLines, "\n")
check(joined:find("Kloster") and joined:find("Uldaman") and joined:find("Anduin"), "Tooltip mit Aktivitaeten und Mitgliedern")
Win.ShowTooltip(UIParent, e31)
check(table.concat(tipLines, "\n"):find("geheim"), "Tooltip nennt geheime Werte")

-- ===== Aktionen =====
local Wh = ns.Whisper
Win.OnRowClick(e21, "LeftButton")
now = now + 0.2
Win.OnRowClick(e21, "LeftButton")
check(Wh.frame and Wh.frame.shown and Wh.target == "Tyrande", "Doppelklick oeffnet das Fluesterfenster")
check(Wh.edit:GetText() == "Hallo Tyrande, wir suchen noch einen Heiler für Kloster. Lust mitzukommen?", "Vorlage fuer Mitspieler, eine Rolle angegeben: {suchrolle} von selbst")
check(#chat == 0, "nichts von selbst gesendet")
Wh.sendBtn.scripts.OnClick(Wh.sendBtn)
check(#chat == 1 and chat[1].kind == "WHISPER" and chat[1].to == "Tyrande" and chat[1].text:find("Kloster"), "Senden fluestert an")
check(not Wh.frame.shown, "Fenster nach dem Senden zu")
Win.OnRowClick(e11, "LeftButton")
now = now + 0.2
Win.OnRowClick(e11, "LeftButton")
check(Wh.target == "Thrall" and Wh.edit:GetText() == "Hallo Thrall, ich würde gern als Heiler mit in Kloster kommen (Priester, Stufe 34).", "Vorlage fuer Gruppen mit Rolle, Klasse und Stufe")
Wh.UseTemplate(0)
check(Wh.edit:GetText() == "" and not Wh.sendBtn.enabled, "ohne Vorlage leer, Senden gesperrt")
Wh.edit:SetText("Eigener Text {unbekannt}")
Wh.UpdateCount()
check(Wh.sendBtn.enabled and Wh.count.txt == "24/255", "eigener Text, Zeichen gezaehlt")
Wh.frame.shown = false
Wh.target = nil
Win.OnRowClick(e11, "LeftButton")
now = now + 1
Win.OnRowClick(e11, "LeftButton")
check(Wh.target == nil, "zwei langsame Klicks sind kein Doppelklick")
-- Menue-Nachbau mit Untermenues (ab 0.5.0: Schnell anfluestern)
local function MockMenu(items)
  local function Btn(list, t, fn)
    local b = { text = t, fn = fn, enabled = true, children = {} }
    b.SetEnabled = function(s, v) s.enabled = v end
    b.CreateButton = function(s, t2, fn2) return Btn(s.children, t2, fn2) end
    list[#list + 1] = b
    return b
  end
  return { CreateTitle = function(_, t) items.title = t end, CreateButton = function(_, t, fn) return Btn(items, t, fn) end }
end
local function Menu(e)
  Win.OnRowClick(e, "RightButton")
  local items = {}
  menus[#menus](nil, MockMenu(items))
  return items
end
local items = Menu(e21)
check(items.title == "Tyrande" and items[3].enabled, "Menue: Einladen fuer Einzelspieler")
check(items[2].text == ns.L.MENU_QUICK and #items[2].children == #Wh.Templates(), "Menue: Untermenue Schnell anfluestern mit allen Vorlagen")
items[3].fn()
check(invited[1] == "Tyrande", "Einladen")
check(ns.Contacts.Get("Tyrande") and ns.Contacts.Get("Tyrande").invite, "Einladung gemerkt")
items = Menu(e11)
check(not items[3].enabled, "Gruppen kann man nicht einladen")
inGroup = true
items = Menu(e21)
check(not items[3].enabled, "in einer Gruppe ohne Anfuehrer kein Einladen")
inGroup = false
items = Menu(e31)
check(not items[1].enabled and not items[2].enabled, "geheimer Name: kein Anfluestern, auch nicht schnell")

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

-- ===== Kategorie aus der Auswahlliste (ab 0.5.3): erst suchen, dann Menue neu =====
do
  local steps, radios = {}, {}
  local root = { CreateRadio = function(_, text, get, set) radios[#radios+1] = set end }
  Win.catDD.menuGen(nil, root)
  check(#radios > 0, "Auswahlliste hat Kategorien")
  local oldSearch, oldGen = C_LFGList.Search, Win.catDD.GenerateMenu
  C_LFGList.Search = function(cat) steps[#steps+1] = "suche " .. cat end
  Win.catDD.GenerateMenu = function() steps[#steps+1] = "menue" end
  local cur = PeonWarhornCharDB.category
  local pick = cur == 2 and 5 or 2
  Win.ChangeCategory(pick)
  check(steps[1] == "suche " .. pick and steps[2] == "menue", "Kategorie: erst suchen, dann Menue neu")
  check(PeonWarhornCharDB.category == pick and #PeonWarhornCharDB.activities == 0, "Kategorie gewechselt")
  -- Das Spiel blockiert die Suche: keine haengende Suche, Hinweis auf den Knopf
  C_LFGList.Search = function() fire("ADDON_ACTION_BLOCKED", "Peon_Warhorn", "UNKNOWN()") end
  S.searching = false
  check(S.Search() == false and not S.searching and S.status == "blocked", "blockierte Suche haengt nicht")
  Win.UpdateStatus()
  check(Win.statusText:find("Suchen klicken"), "Hinweis auf den Knopf Suchen")
  fire("ADDON_ACTION_BLOCKED", "AnderesAddon", "UNKNOWN()")
  check(S.status == "blocked", "fremde Blockade aendert nichts")
  -- Blockade erst nach dem Aufruf
  C_LFGList.Search = function() end
  check(S.Search() == true and S.searching, "Suche laeuft")
  fire("ADDON_ACTION_BLOCKED", "Peon_Warhorn", "UNKNOWN()")
  check(not S.searching and S.status == "blocked", "spaete Blockade beendet die Suche")
  C_LFGList.Search, Win.catDD.GenerateMenu = oldSearch, oldGen
  S.status, S.searching = nil, false
end

-- ===== Auswahl =====
S.SetCategory(5)
check(PeonWarhornCharDB.category == 5 and #PeonWarhornCharDB.activities == 0, "andere Kategorie leert die Aktivitaeten")
S.ToggleActivity(901)
check(S.IsActivitySelected(901), "Aktivitaet gewaehlt")
Win.searchBtn.scripts.OnClick()
check(searches[#searches].cat == 5 and searches[#searches].acts[1] == 901 and #searches[#searches].acts == 1, "Suche mit gewaehlter Aktivitaet")
S.ToggleActivity(901)
check(not S.IsActivitySelected(901), "Aktivitaet abgewaehlt")

-- ===== Seite Eintragen (ab 0.3.0) =====
local Lst, Who, St = ns.Listing, ns.Who, ns.Settings
local function Click(b) b.scripts.OnClick(b, "LeftButton") end
local function Tick(cb, on) cb:SetChecked(on) cb.scripts.OnClick(cb) end
OnBlizzPage("listing")
Win.pages.listing.scripts.OnShow(Win.pages.listing)
Lst.SetCategory(2)
Lst.Update()
check(Win.page == "listing" and #Lst.table.items == 2 and Lst.table.items[1].name == "Kloster", "Eintragen: Aktivitaeten der Kategorie")
check(not Lst.postBtn.enabled and not Lst.removeBtn.enabled and Lst.statusText == "Nicht eingetragen", "ohne Auswahl kein Eintragen")
Win.specs.listing.onClick(Lst.table.items[1], "LeftButton")
check(Lst.IsSelected(801) and Lst.postBtn.enabled and Lst.table.items[1].id == 801, "Klick hakt die Aktivitaet an")
Click(Lst.postBtn)
check(listings[1][1] == "create" and listings[1][2].activityIDs[1] == 801 and listings[1][2].newPlayerFriendly == false, "Eintragen legt den Eintrag an")
check(listings[1][2].generalPlaystyle == 2, "Spielstil Entspannt als Vorgabe")
check(Lst.commentText.txt == "Kommentar: Suche Heiler", "Kommentar aus Blizzards Feld angezeigt")
check(Lst.statusText == "Warte auf das Spiel...", "Statuszeile wartet auf das Spiel")
active = { activityIDs = { 801 }, newPlayerFriendly = false, comment = SECRET }
fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check(Lst.statusText:find("Eingetragen für 1") and Lst.postBtn.txt == "Eintrag ändern" and not Lst.postBtn.enabled and Lst.removeBtn.enabled, "eingetragen: Aendern erst nach Aenderung, Austragen frei")
Win.specs.listing.onClick({ id = 802 }, "LeftButton")
Tick(Lst.newPlayer, true)
check(Lst.postBtn.enabled and Lst.statusText:find("noch nicht übernommen"), "Aenderung ist vorgemerkt")
Click(Lst.postBtn)
check(listings[2][1] == "update" and #listings[2][2].activityIDs == 2 and listings[2][2].newPlayerFriendly == true, "Eintrag aendern")
mod.db.lPlaystyle = 4
check(Lst.Playstyle() == 4 and #Lst.Playstyles() == 4, "Spielstil waehlbar")
mod.db.lPlaystyle = 99
check(Lst.Playstyle() == 2, "unbekannter Spielstil: Vorgabe")
mod.db.lPlaystyle = 0
Click(Lst.removeBtn)
check(listings[3][1] == "remove", "Austragen")
active = nil
fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check(Lst.statusText == "Nicht eingetragen" and Lst.postBtn.txt == "Eintragen", "ausgetragen")
inGroup, leader = true, false
Lst.Update()
check(not Lst.postBtn.enabled and Lst.statusText:find("Anführer"), "in der Gruppe nur der Anfuehrer")
check(Lst.Post() == false and #listings == 3, "kein Eintragen ohne Anfuehrer")
inGroup = false
combat = true
check(Lst.Post() == false and #listings == 3, "kein Eintragen im Kampf")
combat = false
Tick(Lst.roleChecks.tank, true)
check(myRoles.tank == true and myRoles.healer == true, "Rollen-Haken setzen Blizzards Rollenwahl")
Tick(Lst.roleChecks.tank, false)
fire("LFG_LIST_ENTRY_CREATION_FAILED")
check(Lst.statusText:find("abgelehnt"), "Ablehnung beim Eintragen in der Statuszeile")
-- Kommentar bei Blizzard
local commentBtn
for _, c in ipairs(created) do if c.parent == Win.pages.listing and c.txt == "Kommentar bei Blizzard" then commentBtn = c end end
Click(commentBtn)
check(not f.shown and O.buttons.listing.shown and mod.db.replace.listing ~= false, "Kommentar: Blizzards Seite fuer einen Schritt")
check(blizzCat == mod.db.lCategory, "Kommentar: Blizzards Ansicht mit dem Kommentarfeld")
check(O.buttons.listing.strata == "HIGH", "Knopf Warhorn liegt ueber Blizzards Teilen")
LFGListingFrame.scripts.OnHide(LFGListingFrame)
OnBlizzPage("listing")
check(f.shown and Win.page == "listing", "danach wieder Warhorn")

-- ===== Seite Wer-Liste (ab 0.3.0) =====
OnBlizzPage("who")
Win.pages.who.scripts.OnShow(Win.pages.who)
check(Win.page == "who" and Who.statusText == "Noch nicht gesucht", "Wer-Liste vor der ersten Suche")
Who.box:SetText("30-35")
Click(Who.searchBtn)
check(whos[1].text == "30-35" and whos[1].origin == 1 and mod.db.wText == "30-35", "Suchen schickt die Wer-Suche")
whoResults = {
  { fullName = "Arthas", fullGuildName = "", level = 34, classStr = "Krieger", filename = "WARRIOR", raceStr = "Mensch", area = "Eisenschmiede" },
  { fullName = "Ich", fullGuildName = "", level = 34, classStr = "Priester", filename = "PRIEST", raceStr = "Mensch", area = "Eisenschmiede" },
  { fullName = "Bolvar", fullGuildName = "Silberne Hand", level = 40, classStr = "Paladin", filename = "PALADIN", raceStr = "Mensch", area = "Sturmwind" },
  { fullName = SECRET, fullGuildName = "", level = 30, classStr = "Magier", filename = "MAGE", raceStr = "Gnom", area = "Dun Morogh" },
}
fire("WHO_LIST_UPDATE")
check(#Who.list == 4 and #Who.table.items == 4 and Who.statusText == "4 von 4 Spielern", "Ergebnisse gelesen")
check(Who.list[4].name == nil, "geheimer Name nicht benutzt")
mod.db.wFilter.noGuild = true
Who.Update()
check(#Who.table.items == 3, "ohne Gilde")
mod.db.wFilter.noGuild = false
mod.db.wFilter.classes.WARRIOR = true
Who.Update()
check(#Who.table.items == 1 and Who.table.items[1].name == "Arthas", "Filter Klasse")
mod.db.wFilter.classes = {}
Who.lvlMin:SetText("35")
Who.lvlMin.scripts.OnTextChanged(Who.lvlMin, true)
check(#Who.table.items == 1 and Who.table.items[1].name == "Bolvar", "Filter Stufe")
Who.lvlMin:SetText("")
Who.lvlMin.scripts.OnTextChanged(Who.lvlMin, true)
local pr = MenuRoot()
Who.presetDD.menuGen(nil, pr)
pr.items[1].a()
check(whos[2].text == "31-37" and Who.box.txt == "31-37", "Schnellsuche meine Stufe")
pr.items[2].a()
check(whos[3].text == 'z-"Eisenschmiede"', "Schnellsuche meine Zone")
combat = true
Click(Who.searchBtn)
check(#whos == 3 and Who.statusText:find("Kampf"), "keine Wer-Suche im Kampf")
combat = false
fire("WHO_LIST_UPDATE")
Who.OnRowClick(Who.list[1], "LeftButton")
now = now + 0.2
Who.OnRowClick(Who.list[1], "LeftButton")
check(Wh.target == "Arthas" and Wh.frame.shown, "Doppelklick in der Wer-Liste oeffnet das Fluesterfenster")
Wh.frame.shown = false
Who.OnRowClick(Who.list[2], "RightButton")
local wi = {}
menus[#menus](nil, MockMenu(wi))
check(not wi[1].enabled and not wi[2].enabled and not wi[3].enabled, "sich selbst weder anfluestern noch einladen")
Who.OnRowClick(Who.list[1], "RightButton")
wi = {}
menus[#menus](nil, MockMenu(wi))
wi[3].fn()
check(invited[#invited] == "Arthas", "Einladen aus der Wer-Liste")
check(ns.Contacts.Get("arthas").invite and Who.Columns()[1].format(nil, Who.list[1]):find("GossipGossipIcon", 1, true), "Wer-Liste: Einladung gemerkt und markiert")
wi[2].children[1].fn()
check(chat[#chat].to == "Arthas" and chat[#chat].kind == "WHISPER", "Wer-Liste: schnell anfluestern aus dem Untermenue")

-- ===== Seite Einstellungen (ab 0.3.0) =====
st.scripts.OnMouseUp(st, "LeftButton")
check(Win.page == "settings" and St.pageChecks.who.checked and St.pageChecks.search.checked, "Einstellungen zeigen die Seiten")
Tick(St.pageChecks.listing, false)
check(mod.db.replace.listing == false, "Seite Eintragen auf Blizzard")
Tick(St.pageChecks.listing, true)
check(mod.db.replace.listing == true, "Seite Eintragen wieder Warhorn")
local oldPanel = Win.panels.groups
Tick(St.colChecks.groups.classes, false)
check(mod.db.hideCols.groups.classes == true and #Win.tables.groups.o.columns == 5 and Win.panels.groups ~= oldPanel and not oldPanel.shown, "Spalte Klassen ausgeblendet, Liste neu aufgebaut")
check(#Win.tables.groups.items == Win.counts.groups, "neue Liste hat die Eintraege")
Tick(St.colChecks.groups.classes, true)
check(#Win.tables.groups.o.columns == 6, "Spalte Klassen wieder da")
Tick(St.colChecks.who.guild, false)
check(#Who.table.o.columns == 4 and #Who.table.items == 4, "Wer-Liste ohne Spalte Gilde")
Tick(St.colChecks.who.guild, true)
St.SetColor("new", 1, 0, 0, 0.5)
local cr, cg, cb, ca = Win.Color("new")
check(cr == 1 and cg == 0 and ca == 0.5 and select(1, Win.RowBg({ isNew = true })) == 1, "Farbe fuer neue Eintraege")
St.ResetColors()
check(select(2, Win.Color("new")) == 0.8, "Standardfarben")
check(#mod.db.whisper.templates == 2 and St.tpl == 1 and St.nameInput.txt == "Gruppe anfragen", "zwei Vorlagen, die erste gewaehlt")
St.NewTemplate()
check(#mod.db.whisper.templates == 3 and St.tpl == 3 and St.nameInput.txt == "Vorlage 3", "neue Vorlage")
St.nameInput:SetText("Kurz")
St.nameInput.scripts.OnTextChanged(St.nameInput, true)
St.textInput:SetText("Hi {name}, {rolle} hier!")
St.textInput.scripts.OnTextChanged(St.textInput, true)
check(mod.db.whisper.templates[3].name == "Kurz" and mod.db.whisper.templates[3].text == "Hi {name}, {rolle} hier!", "Vorlage bearbeitet")
mod.db.whisper.groupTpl = 3
Win.Whisper(e11)
check(Wh.edit:GetText() == "Hi Thrall, Heiler hier!", "eigene Vorlage als Standard fuer Gruppen")
Wh.frame.shown = false
St.DeleteTemplate()
check(#mod.db.whisper.templates == 2 and mod.db.whisper.groupTpl == 0 and St.tpl == 2, "Vorlage geloescht, Standard zurueckgesetzt")
mod.db.whisper.groupTpl = 1
OnBlizzPage("search")
check(Win.page == "search" and not O.settings, "zurueck zur Suche")
check(#(PeonDB.errors or {}) == 0, "keine Fehler auf den neuen Seiten " .. Errors())

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

-- ===== ab 0.4.0: Dungeon aus ForeverDungeonJournal uebernehmen =====
local J = ns.Journal
check(not J.hooked, "ohne Dungeon-Journal kein Haken")
local fdjSearches = 0
ForeverDungeonJournalDB = {}
ForeverDungeonJournal_NS = { SearchDungeonDirect = function(name)
  fdjSearches = fdjSearches + 1
  ForeverDungeonJournalDB.lfgClick = { mode = "direct", dungeon = name, activity = ({ Uldaman = 802, Kaputt = 999 })[name], ok = name ~= "Fehlt" }
end }
fire("ADDON_LOADED", "ForeverDungeonJournal")
check(J.hooked, "Haken am Dungeon-Journal nach dessen Laden")
local keepInfo = C_LFGList.GetActivityInfoTable
C_LFGList.GetActivityInfoTable = function(id) if id == 802 then return { fullName = "Uldaman", categoryID = 2 } end end
mod.db.show = true
mod.db.replace.search = true
mod.db.category, mod.db.activities = 7, { 801, 901 }
LFGParentFrame.selectedTab = 1
local clicksBefore, searchesBefore = tab2Clicks, #searches
ForeverDungeonJournal_NS.SearchDungeonDirect("Uldaman")
check(fdjSearches == 1, "Suche des Journals laeuft wie bisher")
check(mod.db.category == 2 and #mod.db.activities == 1 and mod.db.activities[1] == 802, "Auswahl auf den Dungeon des Journals")
check(tab2Clicks == clicksBefore + 1 and LFGParentFrame.selectedTab == 2, "springt auf die Seite Suchen")
check(#searches == searchesBefore and S.searching, "Warhorn sucht nicht selbst, wartet auf die Suche des Journals")
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check(not S.searching, "Ergebnisse der Journal-Suche kommen an")
-- keine Uebernahme: Suche fehlgeschlagen, unbekannte Aktivitaet, Warhorn aus
ForeverDungeonJournal_NS.SearchDungeonDirect("Fehlt")
ForeverDungeonJournal_NS.SearchDungeonDirect("Kaputt")
check(mod.db.activities[1] == 802, "fehlgeschlagene oder unbekannte Suche aendert nichts")
mod.db.show = false
mod.db.activities = { 801 }
ForeverDungeonJournal_NS.SearchDungeonDirect("Uldaman")
check(mod.db.activities[1] == 801, "Warhorn aus: keine Uebernahme")
mod.db.show = true
C_LFGList.GetActivityInfoTable = keepInfo
ForeverDungeonJournal_NS, ForeverDungeonJournalDB = nil, nil

-- ===== ab 0.5.0: Platzhalter, schnell anfluestern, Anfragen merken =====
local Ph, Ct = ns.Placeholders, ns.Contacts
mod.db.whisper.vars = { { name = "Gruss", text = "Hallo {name}" }, { name = "rolle", text = "fest" }, { name = "gruss", text = "doppelt" }, "kaputt" }
Wh.InitDefaults()
check(#Wh.Vars() == 1 and Wh.Vars()[1].name == "gruss", "eigene Platzhalter bereinigt: klein, keine festen, keine doppelten")
check(Wh.Fill("{gruss}! {Gruss}", { name = "Bob-Realm" }) == "Hallo Bob! Hallo Bob", "eigener Platzhalter mit festem Platzhalter im Text")
Ph.SetRoleWord("dps", "  DD ")
check(Wh.RoleWord("dps") == "DD" and Wh.RoleWord("tank") == ns.L.ROLE_TANK, "eigenes Wort fuer Schaden, Tank wie im Spiel")
Ph.SetRoleWord("dps", "")
check(Wh.RoleWord("dps") == "DD", "leeres Feld: wieder die Vorgabe DD")
Ph.SetRoleWord("dps", "DD")
Ph.Open()
check(Ph.frame.shown and Ph.sel == 1 and Ph.nameInput:GetText() == "gruss" and Ph.roleInputs.dps:GetText() == "DD", "Fenster Platzhalter zeigt Rollenwoerter und eigene")
Ph.NewVar()
check(#Wh.Vars() == 2 and Wh.Vars()[2].name == "eigen2" and Ph.sel == 2, "neuer Platzhalter")
check(Ph.RenameVar(2, "Grüße!") == "gre", "Name nur aus Buchstaben a-z und Ziffern")
check(Ph.RenameVar(2, "name") == "gre" and Ph.RenameVar(2, "gruss") == "gre", "feste und doppelte Namen abgelehnt")
Ph.SetVarText(2, "Viel Spass")
check(Wh.Fill("{gre}") == "Viel Spass", "Text des neuen Platzhalters")
Ph.DeleteVar()
check(#Wh.Vars() == 1 and Ph.sel == 1, "Platzhalter geloescht")
local phItems = Wh.PlaceholderItems()
check(#phItems == 7 and phItems[1][1] == "{name}" and phItems[3][1] == "{suchrolle}" and phItems[7][1] == "{gruss}", "Menue Platzhalter im Fluesterfenster")
Wh.Open("Bob", {}, "player")
Wh.edit:SetText("")
Wh.edit.Insert = function(s, t) s.txt = (s.txt or "") .. t end
Wh.InsertPlaceholder("{gruss}")
check(Wh.edit:GetText() == "{gruss}", "Platzhalter einfuegen")
Wh.frame.shown = false
-- schnell anfluestern
local chatBefore = #chat
check(Wh.QuickSend("Bob-Realm", { activity = "Uldaman", searchRoles = { dps = true } }, "player") and #chat == chatBefore + 1 and chat[#chat].to == "Bob-Realm", "schnell anfluestern sendet sofort")
check(not Wh.frame.shown and not chat[#chat].text:find("{", 1, true), "ohne Fenster, Platzhalter eingesetzt")
check(Ct.Get("bob") and Ct.Get("BOB-Andere").whisper, "Anfrage gemerkt (ohne Realm, gross und klein egal)")
local keepPlayer = mod.db.whisper.playerTpl
mod.db.whisper.playerTpl = 0
check(not Wh.QuickSend("Carl", {}, "player") and Wh.frame.shown and Wh.target == "Carl" and #chat == chatBefore + 1, "ohne Standardvorlage oeffnet sich das Fenster")
Wh.frame.shown = false
mod.db.whisper.playerTpl = keepPlayer
-- Shift + Doppelklick
local shift = true
IsShiftKeyDown = function() return shift end
lastSent = #chat
Win.OnRowClick(e21, "LeftButton")
now = now + 0.2
Win.OnRowClick(e21, "LeftButton")
check(#chat == lastSent + 1 and chat[#chat].to == "Tyrande" and not Wh.frame.shown, "Shift + Doppelklick sendet die Standardvorlage")
shift = false
IsShiftKeyDown = nil
-- Markierung und Tooltip
check(Win.PlayerColumns()[1].format(nil, e21):find("GossipGossipIcon", 1, true), "Mitspieler: Symbol vor dem Namen")
check(not Win.GroupColumns()[2].format(nil, e11):find("GossipGossipIcon", 1, true), "nicht angefragte Gruppe ohne Symbol")
fire("CHAT_MSG_WHISPER_INFORM", "hallo", e11.leaderName)
check(Win.GroupColumns()[2].format(nil, e11):find("GossipGossipIcon", 1, true), "Fluestern aus dem Chat zaehlt auch, Gruppe ueber ihren Anfuehrer")
tipLines = {}
Win.ShowTooltip(UIParent, e11)
local tipHit = false
for _, l in ipairs(tipLines) do if l:find(ns.L.TIP_WHISPERED:format(""), 1, true) then tipHit = true end end
check(tipHit, "Tooltip: angefluestert vor ...")
-- Dauer
local realTime = time
local fake = realTime()
time = function() return fake end
Ct.SetKeep(30)
check(mod.db.contactKeep == 30 and Ct.KeepMinutes() == 30, "Dauer einstellbar")
fake = fake + 31 * 60
check(Ct.Get("bob") == nil, "nach Ablauf nicht mehr markiert")
Ct.Prune()
check(mod.db.contacts.bob == nil, "alte Eintraege entfernt")
mod.db.contactKeep = 999
check(Ct.KeepMinutes() == Ct.KEEP_DEFAULT, "unbekannte Dauer: Vorgabe 2 Stunden")
mod.db.contactKeep = 120
time = realTime
check(Ct.KeepText(30) and Ct.KeepText(60) == ns.L.KEEP_HOUR and Ct.KeepText(1440) == ns.L.KEEP_DAY, "Texte der Dauer")

-- ===== ab 0.5.1: Aktivitaeten als Aufzaehlung, gesuchte Rolle, DD als Vorgabe =====
check(S.ActivityList({ 801 }) == "Kloster", "eine Aktivitaet: nur der Name")
check(S.ActivityList({ 801, 802 }) == "Kloster und Uldaman", "zwei Aktivitaeten: A und B")
check(S.ActivityList({ 801, 802, 901 }) == "Kloster, Uldaman und Geschmolzener Kern", "drei Aktivitaeten: A, B und C")
check(S.ActivityList({ 801, 802, 901, 801, 802 }) == "Kloster, Uldaman, Geschmolzener Kern und 2 weitere", "viele Aktivitaeten gekuerzt")
check(Win.WhisperCtx({ activityIDs = { 801, 802 }, activityText = "2 Aktivitäten" }).activity == "Kloster und Uldaman", "Platzhalter {aktivitaet} mit allen Namen")
mod.db.whisper.roleWords = {}
check(Wh.RoleWord("dps") == "DD" and Wh.RoleWord("healer") == "Heiler", "Vorgabe fuer Schaden ist DD")
check(Wh.AutoSearchRole({ healer = true }) == "healer" and Wh.AutoSearchRole({ tank = true, dps = true }) == nil and Wh.AutoSearchRole(nil) == nil, "Rolle von selbst nur bei genau einer")
local tplRole = #Wh.Templates() + 1
Wh.Templates()[tplRole] = { name = "Rolle", text = "Wir suchen einen {suchrolle} für {aktivitaet}" }
-- mehrere Rollen: Fenster fragt, Senden gesperrt
Wh.Open("Varian", { activity = "Uldaman", searchRoles = { tank = true, dps = true } }, "player", tplRole)
check(Wh.roleDD.shown and Wh.edit:GetText() == "Wir suchen einen {suchrolle} für Uldaman", "mehrere Rollen: {suchrolle} bleibt offen")
check(not Wh.sendBtn.enabled and Wh.hint.txt == ns.L.WHISPER_PICK_ROLE and not Wh.Send(), "Senden gesperrt, Hinweis auf die Auswahl")
Wh.SetSearchRole("dps")
check(Wh.edit:GetText() == "Wir suchen einen DD für Uldaman" and Wh.sendBtn.enabled and Wh.hint.txt == ns.L.WHISPER_HINT, "Rolle gewaehlt: eingesetzt, Senden frei")
Wh.SetSearchRole("tank")
check(Wh.edit:GetText() == "Wir suchen einen Tank für Uldaman", "Rolle umgewaehlt")
Wh.frame.shown = false
-- ohne Vorlage: nur {suchrolle} im eigenen Text ersetzen
Wh.Open("Varian", { searchRoles = {} }, "player")
Wh.UseTemplate(0)
Wh.edit:SetText("Brauchen {suchrolle}!")
Wh.UpdateCount()
check(not Wh.sendBtn.enabled, "eigener Text mit offener Rolle gesperrt")
Wh.SetSearchRole("healer")
check(Wh.edit:GetText() == "Brauchen Heiler!", "eigener Text: Rolle ersetzt")
Wh.frame.shown = false
-- Gruppen: keine Auswahl der Rolle
Wh.Open("Thrall", { activity = "Kloster" }, "group")
check(not Wh.roleDD.shown, "Anfrage an Gruppen ohne Auswahl der Rolle")
Wh.frame.shown = false
-- schnell anfluestern: offene Rolle oeffnet das Fenster, eine Rolle geht sofort
local cBefore = #chat
check(not Wh.QuickSend("Varian", { activity = "Uldaman", searchRoles = { tank = true, healer = true } }, "player", tplRole) and #chat == cBefore and Wh.frame.shown and Wh.tpl == tplRole, "schnell: offene Rolle oeffnet das Fenster mit der Vorlage")
Wh.frame.shown = false
check(Wh.QuickSend("Varian", { activity = "Uldaman", searchRoles = { tank = true } }, "player", tplRole) and chat[#chat].text == "Wir suchen einen Tank für Uldaman", "schnell: eine Rolle, sofort gesendet")
-- ab 0.5.2: Rollen im Untermenue Schnell anfluestern
local function QuickMenu(ctx, kind)
  local items = {}
  local root = MockMenu(items)
  Wh.AddQuickMenu(root, "Varian", ctx, kind, true)
  return items[1].children
end
local qm = QuickMenu({ activity = "Uldaman", searchRoles = { tank = true, dps = true } }, "player")
local roleEntry = qm[tplRole]
check(roleEntry and roleEntry.fn == nil and #roleEntry.children == 3, "Vorlage mit {suchrolle}: Ebene mit drei Rollen")
check(roleEntry.children[1].text == "Tank" and roleEntry.children[3].text == "DD", "Rollen mit eigenen Woertern")
check(roleEntry.children[1].enabled and not roleEntry.children[2].enabled and roleEntry.children[3].enabled, "nur angegebene Rollen waehlbar, Heiler grau")
check(qm[1].fn ~= nil and #qm[1].children == 0, "Vorlage ohne {suchrolle}: direkt senden")
cBefore = #chat
roleEntry.children[3].fn()
check(#chat == cBefore + 1 and chat[#chat].text == "Wir suchen einen DD für Uldaman" and not Wh.frame.shown, "Rolle im Menue gewaehlt: sofort gesendet")
roleEntry.children[1].fn()
check(chat[#chat].text == "Wir suchen einen Tank für Uldaman", "Menue-Kontext nicht veraendert, andere Rolle geht auch")
qm = QuickMenu({ activity = "Uldaman" }, "player")
check(qm[tplRole].children[1].enabled and qm[tplRole].children[2].enabled and qm[tplRole].children[3].enabled, "keine Rolle angegeben: alle waehlbar")
qm = QuickMenu({ activity = "Uldaman" }, "group")
check(qm[tplRole].fn ~= nil and #qm[tplRole].children == 0, "Anfrage an Gruppen: keine Ebene mit Rollen")
table.remove(Wh.Templates(), tplRole)

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
