-- Stub-Test fuer Peon_Panel: allgemeine Eintraege (XP, Uhr, Zone usw.), mehrere Starter je Modul (API 15), Aussehen
-- Ausfuehren aus dem AddOns-Ordner (run_tests.sh).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
function GetTime() return 1 end
local now = 1000000
function time() return now end
date = function(f) return f == "%H:%M" and "07:56" or "" end
local combat = false
function InCombatLockdown() return combat end
function UnitAffectingCombat() return combat end
YES, NO, ACCEPT, CANCEL, OKAY = "Ja", "Nein", "Annehmen", "Abbrechen", "Okay"
StaticPopupDialogs = {}
function StaticPopup_Show() end
SlashCmdList = {}
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_Panel = TocMeta("Peon_Panel") }
local loadedAddons = { Peon = true, Peon_Panel = true, Peon_Multi = true }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function(a) return loadedAddons[a] == true end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Panel" })[i] end }

-- ===== Rahmen-Nachbau =====
local allFrames = {}
local function W(kind, name, parent)
  local o = { scripts = {}, w = 0, h = 0, shown = true, events = {}, points = {}, kind = kind, name = name, parent = parent, alpha = 1 }
  local m = {}
  function m.SetSize(s, w, h) s.w, s.h = w, h end
  function m.SetHeight(s, h) s.h = h end
  function m.SetWidth(s, w) s.w = w end
  function m.GetHeight(s) return s.h end
  function m.GetWidth(s) return s.w end
  function m.GetStringHeight() return 12 end
  function m.GetStringWidth(s) return #((s.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) * 6 end
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
  function m.GetAlpha(s) return s.alpha end
  function m.GetEffectiveScale() return 1 end
  function m.Enable(s) s.enabled = true end
  function m.Disable(s) s.enabled = false end
  function m.SetColorTexture(s, ...) s.color = { ... } end
  function m.SetVertexColor(s, ...) s.vertex = { ... } end
  function m.SetTexture(s, t) s.tex = t end
  function m.SetPoint(s, ...) s.points[#s.points+1] = { ... } end
  function m.ClearAllPoints(s) s.points = {} end
  function m.GetLeft(s) return s.left or 100 end
  function m.GetTop(s) return s.top or 700 end
  function m.GetCenter(s) return s.cx or 500, s.cy or 700 end
  function m.GetParent(s) return s.parent end
  function m.SetParent(s, p) s.parent = p end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.UnregisterAllEvents(s) s.events = {} end
  function m.GetThumbTexture() return true end
  function m.CreateFontString(s) return W("FontString", nil, s) end
  function m.CreateTexture(s) return W("Texture", nil, s) end
  function m.GetFont(s) return s.font or "basis.ttf", s.fontSize or 10, s.fontFlags end
  function m.SetFont(s, f, n, fl) s.font, s.fontSize, s.fontFlags = f, n, fl end
  function m.SetShadowOffset(s, x, y) s.shadow = { x, y } end
  function m.SetTextColor(s, ...) s.textColor = { ... } end
  function m.EnableMouseWheel(s, v) s.wheel = v end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" and k ~= "Center" then return function() end end end })
end
UIParent = W("Frame", "UIParent")
UIParent.h, UIParent.w = 1000, 1000
Minimap = W("Frame", "Minimap")
Minimap.w = 140
function CreateFrame(kind, name, parent, template)
  local f = W(kind, name, parent)
  f.template = template
  allFrames[#allFrames+1] = f
  if name then _G[name] = f end
  return f
end
GameTooltip = W("GameTooltip")
GameTooltip.lines = {}
function GameTooltip:AddLine(t) table.insert(self.lines, t) end
function GameTooltip:AddDoubleLine(a, b) table.insert(self.lines, tostring(a) .. "|" .. tostring(b)) end
function GameTooltip:SetOwner(o, a) self.owner, self.anchor = o, a; self.lines = {} end
Settings = { RegisterCanvasLayoutCategory = function(p, n) return { name = n, subs = {}, GetID = function() return n end } end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) return { GetID = function() return par.name .. "/" .. n end } end,
  RegisterAddOnCategory = function() end, OpenToCategory = function() end }
local tickers = {}
C_Timer = { After = function(_, fn) fn() end, NewTicker = function(sec, fn) tickers[#tickers + 1] = { sec = sec, fn = fn } end }
function GetCursorPosition() return 0, 0 end
local NewRoot
function NewRoot()
  local r = { items = {} }
  function r:CreateTitle(t) table.insert(self.items, { kind = "title", text = t }) end
  function r:CreateDivider() table.insert(self.items, { kind = "divider" }) end
  function r:CreateRadio(t, isSel, setSel, v) table.insert(self.items, { kind = "radio", text = t, isSel = isSel, setSel = setSel, value = v }) end
  function r:CreateButton(t, fn) local sub = NewRoot() table.insert(self.items, { kind = "button", text = t, fn = fn, sub = sub }) return sub end
  function r:CreateCheckbox(t, isSel, setSel) table.insert(self.items, { kind = "check", text = t, isSel = isSel, setSel = setSel }) end
  return r
end
local menuOpened
Menu = { PopulateDescription = function(gen, owner, desc) gen(owner, desc) end,
  GetManager = function() return { OpenMenu = function(_, owner, desc, anchor) menuOpened = { owner = owner, desc = desc, anchor = anchor } return {} end } end }
MenuUtil = { CreateRootMenuDescription = function() return NewRoot() end }
MenuVariants = { GetDefaultContextMenuMixin = function() return {} end }
AnchorUtil = { CreateAnchor = function(...) return { ... } end }

-- ===== Spielwerte =====
local level, xp, xpMax, atCap = 10, 100, 1000, 10000
function UnitGUID() return "Player-1" end
function UnitLevel() return level end
function UnitXP() return xp end
function UnitXPMax() return xpMax end
function GetXPExhaustion() return 500 end
GameRulesUtil = { GetEffectiveMaxLevelForPlayer = function() return atCap end }
function GetGameTime() return 9, 5 end
local zone, sub, pvp = "Westfall", "Mondbruch", "contested"
function GetZoneText() return zone end
function GetSubZoneText() return sub end
C_PvP = { GetZonePVPInfo = function() return pvp end }
local mapPos = { x = 0.286, y = 0.628 }
C_Map = { GetBestMapForUnit = function() return 52 end, GetPlayerMapPosition = function() return mapPos end }
C_DateAndTime = { GetSecondsUntilDailyReset = function() return 3 * 3600 + 120 end, GetSecondsUntilWeeklyReset = function() return 2 * 86400 + 3600 end }
local dura = { [1] = { 50, 100 }, [5] = { 10, 100 }, [8] = { 100, 100 } }
function GetInventoryItemDurability(slot) local d = dura[slot] if d then return d[1], d[2] end end
function GetInventoryItemLink(_, slot) return "item" .. slot end
function GetFramerate() return 59.6 end
function GetNetStats() return 0, 0, 12, 34 end
local cvars = { Sound_MasterVolume = "0.70", Sound_EnableAllSound = "1" }
C_CVar = { GetCVar = function(n) return cvars[n] end, SetCVar = function(n, v) cvars[n] = v end }
local friendsAsked, rosterAsked = 0, 0
C_FriendList = { ShowFriends = function() friendsAsked = friendsAsked + 1 end, GetNumOnlineFriends = function() return 2 end, GetNumFriends = function() return 3 end,
  GetFriendInfoByIndex = function(i) return ({ { name = "Anna", connected = true, area = "Dun Morogh" }, { name = "Bert", connected = false }, { name = "Cara", connected = true } })[i] end }
function BNGetNumFriends() return 2, 1 end
C_BattleNet = { GetFriendAccountInfo = function(i) return ({ { accountName = "Dora", gameAccountInfo = { isOnline = true, characterName = "Elf" } }, { accountName = "Emil", gameAccountInfo = { isOnline = false } } })[i] end }
local inGuild = false
function IsInGuild() return inGuild end
function GetNumGuildMembers() return 40, 5 end
function GetGuildInfo() return "Die Baeren" end
function GetGuildRosterInfo(i) return "Mitglied" .. i, "Rang", 1, 20, "Krieger", "Stormwind", "", "", i <= 5 end
C_GuildInfo = { GuildRoster = function() rosterAsked = rosterAsked + 1 end }
local watched
C_Reputation = { GetWatchedFactionData = function() return watched end }
FACTION_STANDING_LABEL6 = "Wohlwollend"
local opened = {}
function ToggleWorldMap() opened[#opened + 1] = "map" end
function ToggleCharacter(tab) opened[#opened + 1] = tab end
function ToggleFriendsFrame(tab) opened[#opened + 1] = "friends" .. tostring(tab) end
function ToggleTimeManager() opened[#opened + 1] = "time" end

local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function loadToc(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end

-- ===== Kern: mehrere Starter =====
loadToc("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
check(Peon.API == 15, "API 15")
PeonMultiDB = {}
local multi = Peon:NewModule("Peon_Multi", { key = "multi", title = "Multi", db = "PeonMultiDB", defaults = {} })
fire("ADDON_LOADED", "Peon_Multi")
local main = multi:NewLauncher({ icon = "a" })
local wheelDelta
local e1 = multi:AddLauncher({ key = "eins", title = "Eins", icon = "b", onWheel = function(_, d) wheelDelta = d end })
local shownFlag = true
local e2 = multi:AddLauncher({ key = "zwei", title = "Zwei", available = function() return shownFlag end })
check(main ~= e1 and e1 ~= e2 and multi.launcher == main, "weitere Starter neben dem ersten")
check(multi:AddLauncher({ key = "eins" }) == e1, "gleicher Schluessel: derselbe Starter")
check(#Peon.GetLaunchers() == 3, "alle gemeldet")
check(not pcall(multi.AddLauncher, multi, {}), "ohne Schluessel: Fehler")
check(e1:IsAvailable() and e2:IsAvailable(), "verfuegbar")
shownFlag = false
check(not e2:IsAvailable(), "nicht verfuegbar")
shownFlag = true
local broken = multi:AddLauncher({ key = "kaputt", available = function() error("x") end })
check(broken:IsAvailable(), "Fehler in der Pruefung blendet nicht aus")
broken.available = nil
if PeonDB.errors then wipe(PeonDB.errors) end
e1:Wheel(1)
check(wheelDelta == 1, "Mausrad reicht weiter")

-- ===== Panel laden =====
local ns = loadToc("Peon_Panel", "Peon_Panel")
fire("ADDON_LOADED", "Peon_Panel")
local mod = ns.mod
local bar, box = ns.surfaces.bar, ns.surfaces.box
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)
PeonPanelDB.boxShow = false
check(friendsAsked == 1, "Freundesliste beim Login angefordert")
local E = PeonPanelDB.entries
for _, key in ipairs({ "xp", "xpRate", "xpEta", "zone", "coords", "durability", "clock" }) do
  check(E[key].bar == true and E[key].box == false, key .. ": anfangs auf der Leiste")
end
for _, key in ipairs({ "perf", "playtime", "volume", "friends", "guild", "rep", "resets" }) do
  check(E[key].bar == false and E[key].box == false, key .. ": nur zum Anhaken")
end
check(ns.SideOf("xp") == "left" and ns.SideOf("zone") == "center" and ns.SideOf("clock") == "right", "Standardbereiche")
local function T(key, textKey) return ns.starters[key]:GetText(textKey) end
local function Btn(key) return bar.buttons[key] end
local function On(key) ns.SetOnSurface(ns.starters[key], "bar", true) end

-- ===== XP =====
check(T("xp", "full") == "100/1,0k (10 %)", "XP Stand und Prozent: " .. tostring(T("xp", "full")))
check(T("xp", "percent") == "10 %" and T("xp", "rest") == "900", "XP Prozent und Rest")
check(T("xpRate", "rate") == "..." and T("xpEta", "eta") == "...", "Tempo: anfangs noch keine Daten")
local X = ns.XP
now = now + 30
xp = 200
fire("PLAYER_XP_UPDATE", "player")
check(next(PeonPanelDB.xpLog.b) ~= nil, "Gewinn gemerkt")
check(X.Rate() == nil, "unter einer Minute: noch keine Rate")
now = now + 90
xp = 300
fire("PLAYER_XP_UPDATE", "player")
local rate, sum, elapsed = X.Rate()
check(sum == 200 and elapsed == 120 and rate == 6000, "Rate aus Gewinn und Dauer")
check(T("xpRate", "rate") == "6,0k XP/Std.", "Text XP pro Stunde")
check(math.abs(X.Eta() - 700 / 6000 * 3600) < 0.001 and T("xpEta", "eta") == "7 Min.", "Zeit bis Level-Up")
fire("PLAYER_XP_UPDATE", "target")
check(select(2, X.Rate()) == 200, "andere Einheit zaehlt nicht")
-- Levelaufstieg: Rest des alten Levels plus neuer Stand
xp, xpMax, level = 50, 2000, 11
now = now + 60
fire("PLAYER_LEVEL_UP")
check(select(2, X.Rate()) == 200 + 700 + 50, "Levelaufstieg zaehlt beide Teile")
-- Alte Werte fallen aus dem Fenster
now = now + 3600 + 120
xp = 60
fire("PLAYER_XP_UPDATE", "player")
check(select(2, X.Rate()) == 10 and select(3, X.Rate()) == 3600, "nur die letzten 60 Minuten zaehlen")
local minutes = 0
for _ in pairs(PeonPanelDB.xpLog.b) do minutes = minutes + 1 end
check(minutes == 1, "alte Minuten werden entfernt")
-- /reload misst weiter, neues Einloggen beginnt neu
fire("PLAYER_ENTERING_WORLD", false, true)
check(select(2, X.Rate()) == 10, "/reload: Messung bleibt")
fire("PLAYER_ENTERING_WORLD", true, false)
check(select(2, X.Rate()) == 0, "Einloggen: neue Messung")
-- anderer Charakter
PeonPanelDB.xpLog.who = "Player-2"
PeonPanelDB.xpLog.b[1] = 99
check(select(2, X.Rate()) == 0 and PeonPanelDB.xpLog.who == "Player-1", "anderer Charakter: neue Messung")
-- Menue: Messung neu starten
Btn("xp").scripts.OnClick(Btn("xp"), "RightButton")
-- sucht auch in Untermenues
local function find(list, text)
  for _, it in ipairs(list) do
    if it.text == text then return it end
    local hit = it.sub and find(it.sub.items, text)
    if hit then return hit end
  end
end
local item = find(menuOpened.desc.items, "Messung neu starten")
check(item, "Menue: Messung neu starten")
item.fn()
-- Hoechststufe
atCap = 11
check(not ns.starters.xp:IsAvailable(), "Hoechststufe: nicht verfuegbar")
ns.starters.xp:Refresh()
check(Btn("xp").shown == false, "Hoechststufe: von der Leiste verschwunden")
for _, c in ipairs(bar.cells) do check(c.key ~= "xp", "Hoechststufe: kein Platz mehr fuer XP") end
atCap = 10000
ns.starters.xp:Refresh()
check(Btn("xp").shown, "wieder da, sobald es XP gibt")
-- Tooltip
Btn("xp").scripts.OnEnter(Btn("xp"))
check(table.concat(GameTooltip.lines, "#"):find("Ausgeruht: 500", 1, true), "Tooltip nennt ausgeruhte XP")

-- ===== Beschriftung =====
check(Btn("xp").label.text:find("XP:", 1, true), "XP mit Beschriftung")
check(not Btn("xpRate").label.text:find(":", 1, true), "XP pro Stunde ohne zweites Wort")
check(Btn("xpEta").label.text:find("Level-Up:", 1, true), "Zeit bis Level-Up mit eigenem Wort")
check(not Btn("clock").label.text:find(":|r", 1, true) and Btn("clock").label.text == "07:56", "Uhr ohne Wort")

-- ===== Uhr =====
check(T("clock", "local") == "07:56" and T("clock", "server") == "09:05", "Ortszeit und Serverzeit")
Btn("clock").scripts.OnClick(Btn("clock"), "LeftButton")
check(opened[#opened] == "time", "Uhr: oeffnet die Zeitverwaltung, wenn es keinen Kalender gibt")

-- ===== Zone =====
check(T("zone", "zone") == "|cffffb300Westfall|r", "Zone in der Farbe des Gebiets: " .. tostring(T("zone", "zone")))
check(T("zone", "both"):find("Westfall: Mondbruch", 1, true) and T("zone", "sub"):find("Mondbruch", 1, true), "Unterzone")
sub = "Westfall"
check(T("zone", "both"):find("Westfall|r", 1, true) and not T("zone", "both"):find(": ", 1, true), "Unterzone gleich Zone: nur einmal")
sub = ""
check(T("zone", "sub"):find("Westfall", 1, true), "keine Unterzone: Zone")
sub, pvp = "Mondbruch", nil
check(T("zone", "zone") == "Westfall", "Gebiet ohne Art: ohne Farbe")
pvp = "contested"
zone = ""
check(T("zone", "zone") == nil, "keine Zone: kein Text")
zone = "Westfall"
Btn("zone").scripts.OnClick(Btn("zone"), "LeftButton")
check(opened[#opened] == "map", "Zone: oeffnet die Karte")
combat = true
local before = #opened
Btn("zone").scripts.OnClick(Btn("zone"), "LeftButton")
check(#opened == before, "im Kampf oeffnet sich nichts")
combat = false

-- ===== Koordinaten =====
check(T("coords", "xy") == "28,6 / 62,8", "Koordinaten: " .. tostring(T("coords", "xy")))
mapPos = nil
check(T("coords", "xy") == "-", "Instanz: keine Koordinaten")
mapPos = { x = 0, y = 0 }
check(T("coords", "xy") == "-", "Position 0/0 zaehlt nicht")
mapPos = { x = 0.286, y = 0.628 }

-- ===== Reset =====
check(T("resets", "daily") == "3 Std. 2 Min." and T("resets", "weekly") == "2 T. 1 Std.", "Reset-Zeiten")
check(ns.FormatDuration(10) == "< 1 Min." and ns.FormatDuration(720) == "12 Min.", "kurze Dauer")

-- ===== Haltbarkeit =====
local lowest, list = ns.Durability()
check(lowest == 10 and list[1].slot == 5 and #list == 3, "niedrigster Wert zuerst")
check(T("durability", "low") == "|cffff1a1a10 %|r", "unter 25 Prozent rot")
dura[5] = { 40, 100 }
check(T("durability", "low"):find("^|cffffcc00"), "unter 50 Prozent gelb")
dura = { [1] = { 90, 100 } }
check(T("durability", "low") == "|cffffffff90 %|r", "sonst weiss")
Btn("durability").scripts.OnEnter(Btn("durability"))
check(table.concat(GameTooltip.lines, "#"):find("item1|90 %", 1, true), "Tooltip je Gegenstand")
dura = {}
check(T("durability", "low") == "-", "nichts mit Haltbarkeit")
dura = { [1] = { 90, 100 } }
fire("UPDATE_INVENTORY_DURABILITY")
check(Btn("durability").label.text:find("90 %", 1, true), "Ereignis aktualisiert")

-- ===== Leistung =====
check(T("perf", "both") == "60 FPS 34 ms" and T("perf", "fps") == "60 FPS" and T("perf", "ms") == "34 ms", "Leistung")

-- ===== Spielzeit =====
local started = now
now = now + 4000
check(T("playtime", "session") == ns.FormatDuration(now - PeonPanelDB.session.start), "Sitzung zaehlt")
check(PeonPanelDB.session.who == "Player-1", "Sitzung je Charakter")
fire("PLAYER_LEVEL_UP")
check(T("playtime", "level") == "< 1 Min.", "Levelaufstieg setzt die Zeit auf dieser Stufe zurueck")
fire("PLAYER_ENTERING_WORLD", false, true)
check(T("playtime", "session") ~= "< 1 Min.", "/reload: Sitzung bleibt")
fire("PLAYER_ENTERING_WORLD", true, false)
check(T("playtime", "session") == "< 1 Min.", "Einloggen: neue Sitzung")

-- ===== Lautstaerke =====
check(T("volume", "pct") == "70 %", "Lautstaerke")
On("volume")
local vb = Btn("volume")
check(vb.wheel == true and vb.scripts.OnMouseWheel, "Mausrad aktiv")
check(not Btn("clock").wheel, "andere Eintraege ohne Mausrad")
vb.scripts.OnMouseWheel(vb, 1)
check(cvars.Sound_MasterVolume == "0.75" and vb.label.text:find("75 %", 1, true), "Mausrad hoch")
vb.scripts.OnMouseWheel(vb, -1)
vb.scripts.OnMouseWheel(vb, -1)
check(cvars.Sound_MasterVolume == "0.65", "Mausrad runter")
cvars.Sound_MasterVolume = "0.98"
vb.scripts.OnMouseWheel(vb, 1)
check(cvars.Sound_MasterVolume == "1.00", "nicht ueber 100 Prozent")
cvars.Sound_MasterVolume = "0.02"
vb.scripts.OnMouseWheel(vb, -1)
check(cvars.Sound_MasterVolume == "0.00", "nicht unter 0 Prozent")
vb.scripts.OnClick(vb, "LeftButton")
check(cvars.Sound_EnableAllSound == "0" and vb.label.text:find("Aus", 1, true), "Klick schaltet den Ton aus")
vb.scripts.OnClick(vb, "LeftButton")
check(cvars.Sound_EnableAllSound == "1", "und wieder an")

-- ===== Freunde =====
check(T("friends", "online") == "3/5", "Freunde: Spiel und Battle.net zusammen")
On("friends")
local fb = Btn("friends")
fb.scripts.OnEnter(fb)
local lines = table.concat(GameTooltip.lines, "#")
check(lines:find("Anna|Dun Morogh", 1, true) and lines:find("Cara", 1, true) and lines:find("Dora|Elf", 1, true), "Tooltip nennt, wer online ist")
check(not lines:find("Bert", 1, true) and not lines:find("Emil", 1, true), "wer offline ist, fehlt")
fb.scripts.OnClick(fb, "LeftButton")
check(opened[#opened] == "friends1", "Klick oeffnet die Freundesliste")
check(PeonPanelDB.session.Anna == nil and not tostring(PeonPanelDB.xpLog.who):find("Anna"), "Namen werden nicht gespeichert")

-- ===== Gilde =====
On("guild")
check(Btn("guild") == nil or Btn("guild").shown == false, "ohne Gilde: nicht angezeigt")
inGuild = true
ns.starters.guild:Refresh()
local gb = Btn("guild")
check(gb and gb.shown and gb.label.text:find("5/40", 1, true), "Gilde online und gesamt")
check(rosterAsked >= 1, "Liste angefordert")
local asked = rosterAsked
ns.starters.guild:Refresh()
check(rosterAsked == asked, "nicht oefter als einmal je Minute")
now = now + 61
ns.starters.guild:Refresh()
check(rosterAsked == asked + 1, "nach einer Minute wieder")
gb.scripts.OnEnter(gb)
lines = table.concat(GameTooltip.lines, "#")
check(lines:find("Die Baeren", 1, true) and lines:find("Mitglied5", 1, true) and not lines:find("Mitglied6", 1, true), "Tooltip mit Gilde und allen Online")

-- ===== Ruf =====
On("rep")
check(Btn("rep") == nil or Btn("rep").shown == false, "kein beobachteter Ruf: nicht angezeigt")
watched = { name = "Sturmwind", reaction = 6, currentReactionThreshold = 3000, nextReactionThreshold = 9000, currentStanding = 4500 }
fire("UPDATE_FACTION")
check(Btn("rep").shown and Btn("rep").label.text:find("Wohlwollend 25 %", 1, true), "Rang und Prozent")
check(T("rep", "name") == "Sturmwind 25 %" and T("rep", "value") == "1,5k/6,0k", "Fraktion und Punkte")
watched = { name = "Sturmwind", reaction = 6, currentReactionThreshold = 42000, nextReactionThreshold = 42000, currentStanding = 42000 }
check(T("rep", "standing") == "Wohlwollend" and T("rep", "value") == "-", "hoechster Rang: ohne Prozent")
watched = nil
fire("UPDATE_FACTION")
check(Btn("rep").shown == false, "kein Ruf mehr: verschwindet")

-- ===== Takt: nur Angezeigtes =====
local tickFn
for _, t in ipairs(tickers) do if t.sec == 0.5 then tickFn = t.fn end end
check(tickFn, "Takt laeuft")
local coordReads = 0
local keepPos = C_Map.GetBestMapForUnit
C_Map.GetBestMapForUnit = function() coordReads = coordReads + 1 return 52 end
for _ = 1, 4 do tickFn() end
check(coordReads == 4, "Koordinaten alle halbe Sekunde")
local perfReads = 0
local keepFps = GetFramerate
GetFramerate = function() perfReads = perfReads + 1 return 60 end
for _ = 1, 4 do tickFn() end
check(perfReads == 0, "Leistung nicht angezeigt: wird nicht gelesen")
On("perf")
perfReads = 0
for _ = 1, 4 do tickFn() end
check(perfReads == 2, "Leistung angezeigt: einmal je Sekunde")
GetFramerate = keepFps
-- Ein Eintrag im Takt liest die anderen nicht mit
coordReads = 0
local goldReads = 0
local keepGame = GetGameTime
ns.starters.perf:Refresh()
check(coordReads == 0, "Aktualisieren eines Eintrags liest die anderen nicht")
C_Map.GetBestMapForUnit = keepPos
GetGameTime = keepGame

-- ===== Aussehen =====
-- Schrift
PeonPanelDB.fontFace, PeonPanelDB.fontSize, PeonPanelDB.fontStyle = "morpheus", 14, "outline"
mod:Fire("CHANGED", "fontFace")
local lb = Btn("clock").label
check(lb.font == "Fonts\\MORPHEUS.TTF" and lb.fontSize == 14 and lb.fontFlags == "OUTLINE" and lb.shadow[1] == 0, "Schriftart, Groesse, Umriss")
PeonPanelDB.fontFace, PeonPanelDB.fontStyle = "default", "shadow"
mod:Fire("CHANGED", "fontFace")
check(lb.font == "basis.ttf" and lb.fontFlags == "" and lb.shadow[1] == 1, "Standardschrift mit Schatten")
PeonPanelDB.fontSize = 11
-- Farben
PeonPanelDB.valueColor = { 0.5, 0.5, 0.5, 1 }
PeonPanelDB.labelColor = { 1, 0, 0, 1 }
mod:Fire("CHANGED", "valueColor")
check(lb.textColor[1] == 0.5, "Farbe des Werts")
check(Btn("xp").label.text:find("|cffff0000XP:|r", 1, true), "Farbe der Beschriftung")
PeonPanelDB.valueColor = { 1, 1, 1, 1 }
PeonPanelDB.labelColor = { 0.91, 0.79, 0.373, 1 }
mod:Fire("CHANGED", "valueColor")
-- Hoehe, Abstand, Trennstriche
PeonPanelDB.barHeight = 40
mod:Fire("CHANGED", "barHeight")
check(bar.frame.h == 40 and bar.cells[1].y == 11, "Hoehe unabhaengig vom Symbol, Symbol mittig")
PeonPanelDB.barHeight = 18
PeonPanelDB.barSize = 30
mod:Fire("CHANGED", "barHeight")
check(bar.frame.h == 34, "Leiste wird nie kleiner als das Symbol")
PeonPanelDB.barHeight, PeonPanelDB.barSize = 26, 18
PeonPanelDB.barSeps = true
mod:Fire("CHANGED", "barSeps")
local seen = 0
for _, t in ipairs(bar.seps) do if t.shown then seen = seen + 1 end end
check(seen > 0, "Trennstriche sichtbar")
PeonPanelDB.barSeps = false
mod:Fire("CHANGED", "barSeps")
seen = 0
for _, t in ipairs(bar.seps) do if t.shown then seen = seen + 1 end end
check(seen == 0, "Trennstriche aus")
PeonPanelDB.barGap = 20
mod:Fire("CHANGED", "barGap")
check(Btn("xpRate").points[1][4] == Btn("xp").points[1][4] + Btn("xp").w + 20, "Abstand zwischen den Eintraegen")
PeonPanelDB.barGap = 12
-- Rahmen um Symbole, Hervorhebung
PeonPanelDB.iconBorder = true
mod:Fire("CHANGED", "iconBorder")
check(Btn("clock").iconBorder.shown, "Rahmen um Symbole")
PeonPanelDB.iconBorder = false
mod:Fire("CHANGED", "iconBorder")
check(not Btn("clock").iconBorder.shown, "Rahmen aus")
check(Btn("clock").highlight.color and Btn("clock").highlight.color[4] == 0.12, "dezente Hervorhebung als Standard")
PeonPanelDB.highlight = "glow"
mod:Fire("CHANGED", "highlight")
check(Btn("clock").highlight.tex:find("Highlight", 1, true), "Leuchten")
PeonPanelDB.highlight = "soft"

-- Beschriftung je Eintrag: auch bei Eintraegen ohne Wort davor einschaltbar
check(ns.LabelOf("clock") == false and not Btn("clock").label.text:find(":|r", 1, true), "Uhr ohne Beschriftung als Standard")
ns.SetLabel(ns.starters.clock, true)
check(Btn("clock").label.text:find(ns.LabelName(ns.starters.clock) .. ":", 1, true), "Uhr mit Beschriftung: " .. Btn("clock").label.text)
ns.SetLabel(ns.starters.clock, false)

-- Stile
check(bar.bg.used == "plain", "ohne Blizzard-Rahmen: eigene Stuecke")
local applied = {}
NineSliceUtil = { GetLayout = function(n) return n ~= "Fehlt" and {} or nil end, ApplyLayoutByName = function(c, n) c.layout = n; applied[#applied + 1] = n end }
PeonPanelDB.style = "tooltipDark"
mod:Fire("CHANGED", "style")
local nine = bar.bg.nine
check(bar.bg.used == "tooltipDark" and nine.layout == "TooltipDefaultDarkLayout" and nine.template == "NineSlicePanelTemplate", "Stil Tooltip dunkel mit Blizzards Rahmen")
check(nine.points[1][5] == 40 and bar.bg.scale == 1, "Leiste: Rahmen ragt oben aus dem Bild, Tooltip nicht verkleinert")
check(box.bg.nine.points[1][5] == 0, "Panel: Rahmen ganz sichtbar")
check(nine.fill.shown == false and bar.bg.fillRects[1].shown == false, "Tooltip bringt die Flaeche mit, eigene Stuecke aus")
local centerColor, borderColor
nine.SetCenterColor = function(_, ...) centerColor = { ... } end
nine.SetBorderColor = function(_, ...) borderColor = { ... } end
mod:Fire("CHANGED", "bgColor")
check(centerColor[1] == PeonPanelDB.bgColor[1] and borderColor[1] == PeonPanelDB.lineColor[1], "Hintergrund- und Randfarbe gelten")
PeonPanelDB.style = "metal"
mod:Fire("CHANGED", "style")
check(nine.layout == "GenericMetal" and nine.fill.shown == true and nine.fill.color[1] == PeonPanelDB.bgColor[1], "Metall: Flaeche von uns")
check(borderColor[1] == 1, "Metall: Rahmen behaelt seine Farben")
check(bar.bg.scale < 0.2 and math.abs(nine.points[1][5] * bar.bg.scale - 40) < 0.01, "Metall: Rahmen verkleinert, ragt trotzdem 40 Punkte aus dem Bild")
check(box.bg.scale > bar.bg.scale, "Metall: im Panel groesser als auf der Leiste")
nine.BottomLeftCorner = W("Texture", nil, nine)
nine.BottomLeftCorner:SetSize(70, 70)
mod:Fire("CHANGED", "style")
check(math.abs(bar.bg.scale - 14 / 70) < 0.001, "Metall: Groesse der Ecke aus dem Spiel")
nine.BottomLeftCorner = nil
PeonPanelDB.style = "dialog"
mod:Fire("CHANGED", "style")
check(nine.layout == "Dialog", "Stil Dialog")
PeonPanelDB.style = "wood"
mod:Fire("CHANGED", "style")
check(nine.layout == "WoodenNeutralFrameTemplate", "Stil Holz")
PeonPanelDB.style = "plain"
mod:Fire("CHANGED", "style")
check(bar.bg.used == "plain" and nine.shown == false and bar.bg.fillRects[1].shown == true, "Schlicht: Blizzards Rahmen weg")
PeonPanelDB.style = "tooltip"
PeonPanelDB.barBg = false
mod:Fire("CHANGED", "barBg")
check(nine.shown == false and bar.bg.fillRects[1].shown == false, "Hintergrund aus: nichts sichtbar")
PeonPanelDB.barBg = true
mod:Fire("CHANGED", "barBg")
check(nine.shown == true, "Hintergrund wieder an")
-- Rahmen fehlt im Spiel
NineSliceUtil.GetLayout = function() return nil end
mod:Fire("CHANGED", "style")
check(bar.bg.used == "plain" and bar.bg.fillRects[1].shown == true and nine.shown == false, "Rahmen fehlt: eigene Stuecke")
NineSliceUtil.GetLayout = function() error("kaputt") end
mod:Fire("CHANGED", "style")
check(bar.bg.used == "plain", "Fehler im Rahmen: eigene Stuecke")
NineSliceUtil = nil
PeonPanelDB.style = "kaputt"
mod:ResetDefaults()
check(PeonPanelDB.style == "tooltipDark" and PeonPanelDB.xpLog.who == "Player-1" and PeonPanelDB.session.who == "Player-1", "Standardwerte: Stil zurueck, Messung bleibt")

-- Fehler im Spiel-Nachbau haetten sich hier gezeigt
check(PeonDB.errors == nil or #PeonDB.errors == 0, "keine gespeicherten Fehler: " .. tostring(PeonDB.errors and PeonDB.errors[1] and PeonDB.errors[1].msg))
print("ALLE TESTS OK")
