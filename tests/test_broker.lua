-- Stub-Test fuer Peon + Peon_Broker (Pruefbefehl, Minimap-Button, Ereignis-Liste, Scan, Rechenmodell, Tooltip)
-- Rechenmodell: Peon_Broker_Rechenmodell.md (F1-F20); das Beispiel Kupfererz stammt von dort.
-- Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
local now = 100
function GetTime() return now end
local clock = 1790000000          -- Sekunden seit 1970 (time())
time = function(t) if t then return os.time(t) end return clock end
date = os.date
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
SlashCmdList = {}
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_Broker = TocMeta("Peon_Broker") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function(a) return a ~= "Blizzard_AuctionUI" end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Broker" })[i] end }
local UNKNOWN_EVENTS = { NEW_AUCTION_UPDATE = true, AUCTION_ITEM_LIST_UPDATE = true }
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
  function m.SetFontObject(s, f) s.fontObject = f end
  function m.GetText(s) return s.text end
  function m.SetShown(s, v) s.shown = v and true or false end
  function m.GetPoint(s, i) local p = s.points[i or 1] if p then return unpack(p) end end
  function m.Disable(s) s.disabled = true end
  function m.Enable(s) s.disabled = false end
  function m.LockHighlight(s) s.locked = true end
  function m.UnlockHighlight(s) s.locked = false end
  function m.SetChecked(s, v) s.checked = v end
  function m.GetChecked(s) return s.checked end
  function m.SetValue(s, v) s.value = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end
  function m.IsShown(s) return s.shown end
  function m.Show(s) local was = s.shown; s.shown = true; if not was and s.scripts.OnShow then s.scripts.OnShow(s) end end
  function m.Hide(s) s.shown = false end
  function m.SetMinMaxValues(s, a, b) s.min, s.max = a, b end
  function m.SetAlpha(s, a) s.alpha = a end
  function m.SetFrameLevel(s, v) s.level = v end
  function m.GetFrameLevel(s) return s.level end
  function m.SetPoint(s, ...) s.points[#s.points+1] = { ... } end
  function m.ClearAllPoints(s) s.points = {} end
  function m.RegisterEvent(s, e) if UNKNOWN_EVENTS[e] then error("Attempt to register unknown event \"" .. e .. "\"") end s.events[e] = true end
  function m.RegisterUnitEvent(s, e) s.unitev[e] = true end
  function m.UnregisterAllEvents(s) s.events = {}; s.unitev = {} end
  function m.GetThumbTexture() return true end
  function m.CreateFontString() local f = W(); allFrames[#allFrames+1] = f; return f end
  function m.CreateTexture() return W() end
  function m.CreateMaskTexture() return W() end
  function m.GetStatusBarTexture() return W() end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" then return function() end end end })
end
function CreateFrame(kind, name, parent, template) local f = W(); f.kind = kind; f.parent = parent; f.template = template; allFrames[#allFrames+1] = f; if name then _G[name] = f end return f end
UIParent = W()
UISpecialFrames = {}
tinsert = table.insert
Minimap = W(); Minimap.w = 140
local tt = { lines = {} }
GameTooltip = { SetOwner = function() tt.lines = {} end, AddLine = function(_, t) tt.lines[#tt.lines+1] = t end,
  AddDoubleLine = function(_, a, b) tt.lines[#tt.lines+1] = a .. " = " .. b end, Show = function() end, Hide = function() end,
  GetItem = function() return "x", tt.link end, SetHyperlink = function(_, l) tt.hyper = l end }
local cats = {}
Settings = { RegisterCanvasLayoutCategory = function(p, n) local c = { name = n, subs = {}, GetID = function() return n end } cats[n] = c return c end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) table.insert(par.subs, n) return { GetID = function() return par.name .. "/" .. n end } end,
  RegisterAddOnCategory = function(c) c.registered = true end,
  OpenToCategory = function(id) print("OPEN " .. id) end }
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers+1] = fn end }
local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end
local function said(pat) for i = #out, math.max(1, #out - 12), -1 do if out[i]:find(pat, 1, true) then return true end end return false end

-- ===== WoW-Welt fuer Broker =====
function GetBuildInfo() return "1.60.1", "70009", "Sep 1 2026", 16001 end
function GetRealmName() return "Classic Beta PvE" end
function GetNormalizedRealmName() return "ClassicBetaPvE" end
function UnitFactionGroup() return "Horde", "Horde" end
function UnitName() return "Mirel" end
function UnitFullName() return "Mirel", "ClassicBetaPvE" end
Enum = { ItemCommodityStatus = { Unknown = 0, Item = 1, Commodity = 2 }, AuctionHouseTimeLeftBand = { Short = 0, Medium = 1 } }
local replicateCalls = 0
C_AuctionHouse = {
  ReplicateItems = function() replicateCalls = replicateCalls + 1 end,
  GetNumReplicateItems = function() return #LISTINGS end,
  GetReplicateItemInfo = function(i) local l = LISTINGS[i + 1]
    return l[1], 1, l[3], l[4], true, 10, "REQ_LEVEL_ABBR", 0, 0, l[5], 0, nil, nil, nil, nil, 0, l[2], true end,
  GetReplicateItemTimeLeft = function(i) return LISTINGS[i + 1][7] or 3 end,
  GetReplicateItemLink = function(i) local l = LISTINGS[i + 1]; return l[6] or ("|cffffffff|Hitem:" .. l[2] .. "::::::::20:1488:::::::::|h[" .. l[1] .. "]|h|r") end,
  IsThrottledMessageSystemReady = function() return true end,
  IsSellItemValid = function(loc) return loc.slot == 2 end,
  GetItemCommodityStatus = function() return 2 end,
  CalculateCommodityDeposit = function(id, dur, qty) return math.floor((VENDOR[id] or 0) * qty * 5 / 100) * ({ 1, 4, 12 })[dur] end,
  CalculateItemDeposit = function() error("sollte nicht aufgerufen werden") end,
  PostCommodity = function() error("darf nie aufgerufen werden") end,
}
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 4 or 0 end,
  GetContainerItemInfo = function(bag, slot) if slot <= 2 then return { itemID = 2770, stackCount = 5, hyperlink = "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r" } end end }
ItemLocation = { CreateFromBagAndSlot = function(self, bag, slot) return { bag = bag, slot = slot } end }
-- Angebote im Auktionshaus: Name, itemID, Menge, Qualitaet, Sofortkauf (ganzer Stapel), Link
LISTINGS = {                                        -- Kupfererz wie im Rechenmodell, Kapitel 2
  { "Kupfererz", 2770, 10, 1, 10 * 120 },
  { "Kupfererz", 2770, 40, 1, 40 * 150 },
  { "Kupfererz", 2770, 50, 1, 50 * 160 },
  { "Kupfererz", 2770, 20, 1, 20 * 500 },         -- Mondpreis
  { "Leinenstoff", 2589, 20, 1, 20 * 3 },         -- unter Haendlerpreis
  { "Leinenstoff", 2589, 1, 1, 0 },               -- nur Gebot
  { "Schwert des Baeren", 15000, 1, 2, 5000, "|cff1eff00|Hitem:15000::::::1047::20:::::::::|h[Schwert des Baeren]|h|r" },
  { "Schwert des Affen", 15000, 1, 2, 9000, "|cff1eff00|Hitem:15000::::::1048::20:::::::::|h[Schwert des Affen]|h|r" },
}
VENDOR = { [2770] = 5, [2589] = 10, [15000] = 2000, [9999] = 7 }
GetItemInfo = nil   -- gibt es im Forever-Client nicht mehr, nur C_Item.GetItemInfo
local function ItemInfo(id)
  local n = tonumber(id) or tonumber(tostring(id):match("item:(%d+)"))
  return "Gegenstand" .. tostring(n), "[x]", 1, 10, 0, "Typ", "Untertyp", (n == 15000) and 1 or 20, "", 1, VENDOR[n] or 0
end
Enum.TooltipDataType = { Item = 0, Unit = 2 }
local ttCallback
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) if kind == 0 then ttCallback = fn end end }
local shift = false
function IsShiftKeyDown() return shift end
C_Item = { GetItemInfo = ItemInfo, GetItemLocation = function(guid) return { guid = guid } end, GetStackCount = function(loc) return loc.guid == "Stapel20" and 20 or 1 end }
local popupShown
StaticPopupDialogs = {}
local POPUPS = StaticPopupDialogs
StaticPopup_Show = function(name, text, _, data) popupShown = { name = name, text = text, data = data } end
AuctionHouseFrame = {}
local alt = false
function IsAltKeyDown() return alt end
function HandleModifiedItemClick() end
function hooksecurefunc(name, fn) local orig = _G[name]; _G[name] = function(...) orig(...); fn(...) end end

-- ===== Laden =====
load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
PeonBrokerDB = { markets = { alt = { items = { [1] = { m = 1 } } } }, tooltipSales = true, minimapShow = true }  -- Daten von 0.5
local ns = load("Peon_Broker", "Peon_Broker")
fire("ADDON_LOADED", "Peon_Broker")
local mod = ns.mod
check(mod.initialized and mod.page, "Modul + Optionsseite")
do   -- ab 0.97: Abschnitt Zahl am Reiter, eine Auswahl je Reiter
  local keys = {}
  for _, c in ipairs(mod.page.controls) do if type(c.key) == "string" and c.key:sub(1, 5) == "badge" then keys[c.key] = c end end
  check(keys.badgeBuy and keys.badgeWatch and keys.badgeRadar == nil and keys.badgeSell and keys.badgeChances, "0.97: Optionen mit Auswahl je Reiter (ab 0.105 ohne Radar)")
  keys.badgeChances.Select("all")
  check(mod.db.badgeChances == "all", "0.97: Auswahl schreibt die Einstellung")
  keys.badgeChances.Select("off")
end
check(StaticPopupDialogs == POPUPS and POPUPS.PEON_BROKER_DELETE_MARKET, "StaticPopupDialogs nicht neu zugewiesen (sonst ESC-Problem)")
check(type(PeonBrokerDB) == "table" and PeonBrokerDB.debug == false, "PeonBrokerDB angelegt")
check(PeonBrokerDB.radarSound == false and PeonBrokerDB.radarSoundOff == true, "0.95.1: Ton bei neuen Radar-Treffern einmal ausgeschaltet (Bericht 29)")
check(PeonBrokerDB.dataVersion == 2 and next(PeonBrokerDB.markets) == nil and PeonBrokerDB.tooltipSales == nil and PeonBrokerDB.minimapShow == true, "Umstellung: alte Preisdaten geloescht, Einstellungen bleiben")
local migMsg = false for _, l in ipairs(out) do if l:find("Neues Rechenmodell", 1, true) then migMsg = true end end
check(migMsg, "Hinweis im Chat: bitte neu scannen")
-- ab 0.83: Standardwerte fuer Radar und Fokus nach KarloDerBaers Einstellungen
do
  local d = mod.db
  check(d.dealMinVendor == 100 and d.buyoutMinQty == 500 and d.buyoutMinLevels == 4 and d.buyoutMinSales == 270 and d.focusRate == 90
    and d.focusFirst == 10 and d.focusSure == 60 and d.focusMore == 10 and d.radarScanMode == "mass", "0.83: neue Standardwerte fuer Radar und Fokus")
end
-- Die Tests darunter rechnen mit den Werten bis 0.82 (Zeiten und Mengen der Beispiele)
local function OldDefaults()
  local d = mod.db
  d.dealMinVendor, d.buyoutMinQty, d.buyoutMinLevels, d.buyoutMinSales, d.focusRate = 10, 200, 5, 50, 12
  d.focusFirst, d.focusSure, d.focusMore, d.radarScanMode = 30, 120, 20, "watch"
end
OldDefaults()
fire("PLAYER_LOGIN")
check(cats.Peon and cats.Peon.subs[1] == "Broker", "Seite unter Peon > Broker")
check(SlashCmdList.PEON_BROKER ~= nil and SLASH_PEON_BROKER1 == "/broker", "/broker angemeldet")
check(ns.Money(1234567) == "123g 45s 67c" and ns.Money(305) == "3s 5c" and ns.Money(7) == "7c" and ns.Money(nil) == "?", "Geldanzeige")

-- Ereignisse: ab 0.103.2 erst nach dem Pruefbefehl
check(PeonBrokerDB.probeEvents == nil, "ohne Pruefbefehl zaehlt Broker keine Ereignisse")

-- Pruefung ohne Auktionshaus
SlashCmdList.PEON_BROKER("pruefen")
local ev = PeonBrokerDB.probeEvents
check(ev.AUCTION_HOUSE_SHOW.known == true and ev.NEW_AUCTION_UPDATE.known == false, "unbekannte Ereignisse sauber abgewiesen")
local r = PeonBrokerDB.probe
check(r and r.market == "Classic Beta PvE / Horde", "Markt = Regelsatz / Fraktion")
check(r.build.interface == "16001" and r.realm == "Classic Beta PvE", "Client und Realm gespeichert")
check(#r.api == 11 and r.api[1] == "CalculateCommodityDeposit", "C_AuctionHouse-Funktionen sortiert gespeichert")
check(r.legacy.QueryAuctionItems == false and r.frames.AuctionHouseFrame == true, "alte Funktionen / Fenster erkannt")
check(r.enums.ItemCommodityStatus == "Commodity=2, Item=1, Unknown=0", "Enums gespeichert")
check(r.ahOpen == false and r.live == nil, "ohne Auktionshaus kein Gebuehren-Test")
check(said("Auktionshaus öffnen"), "Hinweis: Auktionshaus oeffnen")

-- Scan-Test ohne Auktionshaus
SlashCmdList.PEON_BROKER("pruefen scan")
check(replicateCalls == 0 and said("nur bei geöffnetem"), "Scan nur bei geoeffnetem Auktionshaus")

-- Auktionshaus oeffnen
fire("AUCTION_HOUSE_SHOW")
check(ns.Probe.ahOpen and ns.Scan.ahOpen and _G.PeonBrokerScanButton, "Auktionshaus erkannt, Scan-Knopf angelegt")
check(ev.AUCTION_HOUSE_SHOW.count == 1, "Ereignis gezaehlt")
local n0 = #out
fire("AUCTION_HOUSE_CLOSED"); fire("AUCTION_HOUSE_SHOW")
check(#out == n0, "kein Chat-Hinweis beim Oeffnen")

SlashCmdList.PEON("broker check")
r = PeonBrokerDB.probe
local fee = r.live.fee
check(fee.itemID == 2770 and fee.vendor == 5 and fee.isCommodity == true, "Gebuehren-Test: Gegenstand, Haendlerpreis, Massenware")
check(fee.deposit[1] == "0" and fee.deposit[2] == "0" and fee.deposit[3] == "0", "Einstellgebuehr je Laufzeit (1 x 5c: 5 % = 0,25c -> 0c)")
check(said("Gebühren-Test") and said("0c / 0c / 0c"), "Gebuehren im Chat")

-- Scan-Test
SlashCmdList.PEON_BROKER("pruefen scan")
check(replicateCalls == 1 and said("angefordert"), "Komplettscan angefordert")
now = now + 7
fire("REPLICATE_ITEM_LIST_UPDATE")
local scan = PeonBrokerDB.probe.scan
check(scan.count == #LISTINGS and scan.seconds == 7 and #scan.samples == 3, "Scan: Anzahl, Dauer, Beispiele")
check(scan.samples[1]:find("Kupfererz | 1 | 10", 1, true) ~= nil, "Beispiel roh gespeichert")
check(scan.samples[1]:find("|| Restzeit ", 1, true) and type(scan.timeLeftBands) == "table", "Restzeit je Angebot (GetReplicateItemTimeLeft) mitgeprueft")
check(said("8 Angebote in 7 Sekunden"), "Scan-Ergebnis im Chat")
timers[#timers]()
check(not scan.timeout, "kein Timeout nach Antwort")

-- Pruefung erneut: Scan-Ergebnis bleibt erhalten
SlashCmdList.PEON_BROKER("pruefen")
check(PeonBrokerDB.probe.scan == scan, "Scan-Ergebnis bleibt bei neuer Pruefung")

-- Scan ohne Antwort
SlashCmdList.PEON_BROKER("pruefen scan")
timers[#timers]()
check(PeonBrokerDB.probe.scan.timeout == true and said("keine Antwort"), "Timeout gemeldet")

-- Optionsseite
if mod.panel.scripts.OnShow then mod.panel.scripts.OnShow(mod.panel) end
local found
for _, f in ipairs(allFrames) do if type(f.text) == "string" and f.text:find("Classic Beta PvE / Horde", 1, true) then found = f.text end end
check(found and found:find("modern (11", 1, true) and found:find("0c / 0c / 0c", 1, true), "Optionsseite zeigt letzte Pruefung")
SlashCmdList.PEON_BROKER("optionen")
check(said("OPEN Peon/Broker"), "/broker optionen oeffnet Seite")

-- Fehlende Funktion im Client: Pruefung laeuft trotzdem durch und speichert
local savedLoc = ItemLocation
ItemLocation = {}
SlashCmdList.PEON_BROKER("pruefen")
check(PeonBrokerDB.probe.live.fee.error ~= nil and said("nicht möglich"), "Gebuehren-Test scheitert sauber, Pruefung gespeichert")
ItemLocation = savedLoc

-- Minimap-Button
local btn = _G.PeonBrokerMinimapButton
check(btn and btn.shown and mod.db.minimapAngle == 225, "Minimap-Button da, Standardwinkel 225")
btn.scripts.OnEnter(btn)
check(tt.lines[2] == "Markt: Classic Beta PvE / Horde" and tt.lines[3] == "Noch kein Scan für diesen Markt." and tt.lines[4]:find("Letzte Prüfung: 20", 1, true), "Tooltip: Markt, Scan, letzte Pruefung")
n0 = #out
btn.scripts.OnClick(btn, "RightButton")
check(out[#out] == "OPEN Peon/Broker", "Rechtsklick oeffnet Einstellungen")
btn.scripts.OnClick(btn, "LeftButton")
check(_G.PeonBrokerFrame and _G.PeonBrokerFrame.shown, "Linksklick oeffnet das Broker-Fenster")
btn.scripts.OnClick(btn, "LeftButton")
check(not _G.PeonBrokerFrame.shown, "zweiter Linksklick schliesst es")
for _, c in ipairs(mod.page.controls) do if c.key == "minimapShow" and c.Set then c.Set(false) end end
if mod.db.minimapShow ~= false then mod.db.minimapShow = false; mod:Fire("CHANGED", "minimapShow") end
check(not btn.shown, "Minimap-Button ausblendbar")

-- Ereignis-Liste auf der Optionsseite
if mod.panel.scripts.OnShow then mod.panel.scripts.OnShow(mod.panel) end
local evl
for _, c in ipairs(mod.page.controls) do if c.list then evl = c.list end end
check(evl and #evl:GetItems() == #ns.Probe.EVENTS, "Ereignis-Liste mit allen Ereignissen")
check(evl:GetItems()[1].name == "AUCTION_HOUSE_SHOW" or evl:GetItems()[1].count >= evl:GetItems()[2].count, "nach Anzahl sortiert")
local unknown
for _, it in ipairs(evl:GetItems()) do if it.name == "NEW_AUCTION_UPDATE" then unknown = it end end
check(unknown and unknown.known == false, "unbekanntes Ereignis in der Liste markiert")

local function plain(t)
  t = t:gsub("|TInterface\\MoneyFrame\\UI%-GoldIcon[^|]*|t", "g"):gsub("|TInterface\\MoneyFrame\\UI%-SilverIcon[^|]*|t", "s")
  t = t:gsub("|TInterface\\MoneyFrame\\UI%-CopperIcon[^|]*|t", "c"):gsub("|T[^|]*\\(trend_%w+)[^|]*|t", "[%1]")
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return t
end
-- ===== Rechenmodell: Formeln einzeln =====
local D, S, T = ns.Data, ns.Scan, ns.Tooltip
check(D.KeyFromLink("|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r") == 2770, "Schluessel: itemID")
check(D.KeyFromLink("|cff1eff00|Hitem:15000::::::1047::20:::::::::|h[x]|h|r") == "15000:1047", "Schluessel: itemID:Zusatz")
check(D.KeyFromLink("kein Link") == nil and D.KeyFromLink(nil) == nil, "Schluessel: ungueltig -> nil")
local mn, md, q, n = D.Summarize({ 120, 10, 150, 40, 160, 50, 500, 20 })
check(mn == 120 and md == 160 and q == 120 and n == 4, "F2-F5: Kupfererz AHmin 1s 20c, AHmedian 1s 60c, 120 Stueck, 4 Angebote")
check(select(2, D.Summarize({ 100, 1, 200, 1 })) == 150, "F5: gerade Stueckzahl -> Mittel der beiden mittleren")
check(select(2, D.Summarize({ 100, 1, 200, 2 })) == 200, "F5: ungerade Stueckzahl -> mittleres Stueck")
check(plain(T.Money(1234567)) == "123g 45s 67c" and plain(T.Money(10000)) == "1g" and plain(T.Money(0)) == "0c", "Muenzsymbole")
check(T.TrendLevel(110, 100) == 1 and T.TrendLevel(130, 100) == 2 and T.TrendLevel(102, 100) == 0
  and T.TrendLevel(90, 100) == -1 and T.TrendLevel(70, 100) == -2 and T.TrendLevel(5, 0) == 2 and T.TrendLevel(5, nil) == nil, "F11: Trend in fuenf Stufen")
local db = mod.db
check(D.Suggest(120, 160, 2770, db) == 120, "F14/F15: Massenware ohne Dumping: VP = AHmin (UBmass 0)")
local vp, basis, dump = D.Suggest(100, 160, 2770, db)
check(dump and basis == 136 and vp == 136, "F13-F15: Dumping -> Mitte zwischen Grenze 1s 12c und Median 1s 60c = 1s 36c")
check(D.Suggest(5000, 5000, "15000:1047", db) == 4999, "F15: Einzelgegenstand 1 Kupfer unterboten")
db.undercutMode, db.undercutValue = "percent", 5
check(D.Suggest(1000, 1000, "15000:1047", db) == 950, "F15: Unterbieten in Prozent")
db.undercutMode, db.undercutValue = "copper", 1
check(D.Proceeds(120, 20) == 2280, "F16: Erloes 20 x 1s 20c x 0,95 = 22s 80c")
check(D.Deposit(5, 20, db) == 20, "F18: Einstellgebuehr 20 x 5c x 20 % = 20c")
db.duration = 24
check(D.Deposit(5, 20, db) == 60, "F18: 24 Std. = 60 %")
db.duration = 8
check(D.Deposit(33, 11, db) == 72, "F18: Wollstoff 11 x 33c x 20 % = 72,6c -> 72c (abgerundet wie im Spiel)")
check(D.Deposit(25, 1, db) == 4, "F18: 25c x 5 % = 1,25c -> 1c, x 4 = 4c (Spiel)")
check(D.Deposit(2, 18, db) == 4, "F18: 18 x 2c x 5 % = 1,8c -> 1c, x 4 = 4c (Spiel)")
check(D.Deposit(15, 15, db) == 44, "F18: 15 x 15c x 5 % = 11,25c -> 11c, x 4 = 44c (Spiel)")
check(D.Deposit(375, 1, db) == 72, "F18: 375c x 5 % = 18,75c -> 18c, x 4 = 72c (Spiel)")
check(D.Deposit(15, 1, db) == 0, "F18: 15c x 5 % = 0,75c -> 0c (Spiel)")
db.duration = 2
check(D.Deposit(7, 3, db) == 1, "F18: 2 Std.: 3 x 7c x 5 % = 1,05c -> 1c")
db.duration = 24
check(D.Deposit(33, 11, db) == 216, "F18: 24 Std.: 18c x 12 = 2s 16c")
db.duration = 8
local d0 = 20000
local wk = D.Week({ d = (d0 - 8) .. ":100:100:10:1;" .. (d0 - 1) .. ":240:300:20:2;" .. d0 .. ":130:160:10:1" }, d0)
check(wk.min == 125 and wk.median == 155 and wk.days == 2, "F8: 7 Tage = Mittel der Tagesmittel (heute eingeschlossen)")
check(wk.pmin == 120 and wk.pdays == 1, "F9: 7 Tage vom Vortag (Tag -8 liegt ausserhalb)")
check(D.IsCommodity(2770) == true and D.IsCommodity("15000:1047") == false and D.IsCommodity(15000) == false, "Warenart: Faustregel stapelbar / Zusatz")

-- ===== Tooltip vor dem ersten Scan =====
local function hover(link, guid)
  tt.lines, tt.link = {}, link
  ttCallback(GameTooltip, { guid = guid })
  for i, l in ipairs(tt.lines) do tt.lines[i] = plain(l) end
  return tt.lines
end
local KUPFER = "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r"
local LEINEN = "|cffffffff|Hitem:2589::::::::20:1488:::::::::|h[Leinenstoff]|h|r"
local lines = hover(KUPFER)
check(#lines == 1 and lines[1]:find("noch kein Scan", 1, true), "Tooltip: Hinweis ohne Scan")
check(#hover("|cffffffff|Hitem:1234::::::::20:1488:::::::::|h[Quest]|h|r") == 0, "Tooltip: nichts bei Gegenstaenden ohne Haendlerpreis")

-- ===== Scan =====
fire("AUCTION_HOUSE_CLOSED")
SlashCmdList.PEON_BROKER("scan")
check(said("nur bei geöffnetem Auktionshaus"), "Scan nur bei geoeffnetem Auktionshaus")
fire("AUCTION_HOUSE_SHOW")
check(PeonBrokerDB.commodity[2770] == true, "Warenart vom Spiel gemerkt")
check(PeonBrokerDB.depositCheck == nil, "0.28: kein Abgleich der Einstellgebuehr mehr")
local sb = _G.PeonBrokerScanButton
S.UpdateButton()
check(sb.status.text == "Noch kein Scan", "Scan-Knopf: noch kein Scan")
local calls0 = replicateCalls
sb.scripts.OnClick(sb)
check(replicateCalls == calls0 + 1 and S.state and S.state.phase == "wait" and said("offen lassen"), "Knopf startet Komplettscan")
check(sb.status.text == "Warte auf Daten ...", "Status: warten")
SlashCmdList.PEON_BROKER("scan")
check(said("läuft schon"), "kein zweiter Scan gleichzeitig")
S.CHUNK, S.SUM_CHUNK = 2, 1
now = now + 3
fire("REPLICATE_ITEM_LIST_UPDATE")
check(S.state.phase == "read" and S.state.total == 8, "Daten da: Lesen beginnt")
S.Step()
check(S.state.index == 2 and sb.status.text == "Lese 25 %", "Lesen in Portionen")
local guard = 0
while S.state and guard < 100 do S.Step(); guard = guard + 1 end
check(S.state == nil and guard > 5, "Auswertung in mehreren Schritten fertig")
check(said("Scan fertig: 7 Angebote, 4 Gegenstände") and said("Classic Beta PvE / Horde"), "Scan-Ergebnis im Chat")
local market = D.Market()
local cu = market.items[2770]
check(cu.m == 120 and cu.md == 160 and cu.q == 120 and cu.n == 4 and cu.t == clock, "Kupfererz gespeichert: AHmin, AHmedian, AHmenge, AHanz, ZEIT")
check(market.items["15000:1047"].m == 5000 and market.items["15000:1048"].m == 9000 and market.items[15000] == nil, "Ausruestung getrennt nach Zusatz")
check(market.items[2589].m == 3 and market.items[2589].n == 1, "reine Gebote nicht mitgezaehlt")
check(market.lastScan == clock and market.scans == 1 and market.lastItems == 4, "Markt: letzter Scan")
check(cu.d == D.Day(clock) .. ":120:160:120:1", "F7: Tageswert (Summen und Anzahl) gespeichert")

-- Wartezeit
SlashCmdList.PEON_BROKER("scan")
check(said("Nächster Komplettscan in 15:00 möglich"), "15 Minuten Wartezeit")
S.UpdateButton()
check(sb.status.text == "Nächster Scan in 15:00", "Knopf zeigt Wartezeit")

-- ===== Tooltip (Kapitel 3, ab 0.46 aus Bausteinen, Umbau U5) =====
local TT = ns.Tooltip
check(type(PeonBrokerDB.tooltipLayout) ~= "table" or PeonBrokerDB.tooltipLayout.lines, "U5: Einstellung als Bausteine")
lines = hover(KUPFER)
check(lines[1] == "Broker = 1s 14c" and #lines == 1, "Z1 ohne Umschalt: Erloes fuer 1 Stueck, ohne (Umschalt)")
lines = hover(KUPFER, "Stapel20")
check(lines[1] == "Broker = 22s 80c (20 × 1s 20c)", "Z1: Erloes fuer den Stapel und je Stueck (KarloDerBaer)")
shift = true
lines = hover(KUPFER, "Stapel20")
check(lines[1] == "Broker = 22s 80c (20 × 1s 20c)", "Z1 mit Umschalt")
check(lines[2] == "Markt = ab 1s 20c · 120 Stück · vor 1 Min.", "U5: Markt mit Menge und Alter: " .. tostring(lines[2]))
check(lines[3] == "Einstellen = 1s 20c je Stück, Erlös 22s 80c (8 Std.)", "U5: Einstellen mit Erloes fuer den Stapel")
check(lines[4] == "Händler = 5c je Stück" and #lines == 4, "U5: Haendler je Stueck, ohne Bereich keine Zeile Ueblich, keine Hinweise")
lines = hover(LEINEN)
check(lines[1] == "Broker = Händler: 10c" and lines[3] == "Einstellen = 3c je Stück, Erlös 3c (8 Std.)", "Haendler besser")
check(lines[4] == "Händler = 10c je Stück" and lines[5] == "Wenig Angebote." and #lines == 5, "Haendler auch wenn Zeile 1 den Haendler zeigt, ein Hinweis")
lines = hover("|cff1eff00|Hitem:15000::::::1047::20:::::::::|h[x]|h|r")
check(lines[1] == "Broker = 47s 49c" and lines[3]:find("49s 99c je Stück", 1, true), "Einzelgegenstand: 1 Kupfer unterboten")
-- Schwerer Leinenverband: Markt auf Haendlerniveau
VENDOR[7777] = 20
market.items[7777] = { m = 20, md = 20, q = 2420, n = 148, t = clock, d = D.Day(clock) .. ":20:20:2420:1" }
lines = hover("|cffffffff|Hitem:7777::::::::20:1488:::::::::|h[Verband]|h|r", "Stapel20")
check(lines[1] == "Broker = Händler: 4s (20 × 20c)", "Leinenverband: 20 x 20c x 0,95 = 3s 80c < 4s -> Haendler")
market.items[7777] = nil
-- Bausteine: Wann, Format, Reihenfolge, Vorlagen
;(function()
local lay = TT.Layout()
TT.LayoutLine("vendor").when = "off"
check(#hover(KUPFER) == 3, "U5: Baustein aus")
TT.LayoutLine("vendor").when = "always"
shift = false
lines = hover(KUPFER, "Stapel20")
check(#lines == 2 and lines[2] == "Händler = 5c je Stück", "U5: Baustein immer, auch ohne Umschalt")
TT.LayoutLine("vendor").fmt = "stack"
check(hover(KUPFER, "Stapel20")[2] == "Händler = 1s", "U5: Format Haendler fuer den Stapel")
lay.value = "unit"
check(hover(KUPFER, "Stapel20")[1] == "Broker = 1s 20c je Stück", "U5: Zeile 1 nur je Stueck")
lay.value = "stack"
check(hover(KUPFER, "Stapel20")[1] == "Broker = 22s 80c", "U5: Zeile 1 nur Stapel")
lay.shifthint = "always"
check(hover(KUPFER)[1]:find("Broker (Umschalt)", 1, true), "U5: Hinweis (Umschalt) einstellbar")
shift = true
check(TT.Move("vendor", -1) and TT.Layout().lines[4].key == "vendor" and TT.Layout().lines[5].key == "sell", "U5: Reihenfolge aendern")
lines = hover(KUPFER, "Stapel20")
check(lines[2]:find("Markt", 1, true) and lines[3] == "Händler = 1s" and lines[4]:find("Einstellen", 1, true), "U5: Ausgabe in der neuen Reihenfolge")
check(not TT.Move("market", -1) and not TT.Move("hint", 1), "U5: nicht ueber den Rand verschieben")
TT.LayoutLine("market").fmt = "both"
check(hover(KUPFER)[2] == "Markt = ab 1s 20c · Median 1s 60c · 120 Stück · vor 1 Min.", "U5: Markt mit Median")
TT.SetPreset("slim")
lines = hover(KUPFER, "Stapel20")
check(#lines == 1 and lines[1] == "Broker = 22s 80c", "U5: Vorlage Schlank: nur Zeile 1, auch mit Umschalt")
TT.SetPreset("full")
shift = false
check(#hover(KUPFER) == 4, "U5: Vorlage Ausfuehrlich: alles ohne Umschalt")
TT.SetPreset("standard")
shift = true
check(#hover(KUPFER, "Stapel20") == 4 and #TT.PreviewLines(true) >= 9 and #TT.PreviewLines(false) == 1, "U5: Vorlage Standard, Vorschau mit Beispielwerten")
check(plain(TT.PreviewLines(false)[1]):find("(20 × 95c)", 1, true), "U5: Vorschau Zeile 1 mit Stapel und je Stueck")
-- Uebernahme alter Schalter beim ersten Start
PeonBrokerDB.tooltipLayout = nil
mod.db.tooltipVendor, mod.db.tooltipHint, mod.db.tooltipNeutral = false, false, "always"
check(TT.LayoutLine("vendor").when == "off" and TT.LayoutLine("hint").when == "off" and TT.LayoutLine("neutral").when == "always", "U5: alte Schalter uebernommen")
PeonBrokerDB.tooltipLayout = nil
mod.db.tooltipVendor, mod.db.tooltipHint, mod.db.tooltipNeutral = true, true, "shift"
PeonBrokerDB.tooltipLayout = { value = "quatsch", lines = { { key = "market", when = "x" }, { key = "gibtsnicht" } } }
local nl = TT.Layout()
check(nl.value == "both" and nl.lines[1].key == "market" and nl.lines[1].when == "shift" and #nl.lines == #TT.BLOCKS and nl.lines[2].when == "off", "U5: kaputte Einstellung repariert, fehlende Bausteine hinten an (aus)")
TT.SetPreset("standard")
end)()
mod.db.tooltipShow = false
check(#hover(KUPFER) == 0, "Tooltip ganz aus")
mod.db.tooltipShow = true
local refreshed = 0
GameTooltip.IsShown = function() return true end
GameTooltip.RefreshData = function() refreshed = refreshed + 1 end
tt.link = KUPFER
fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
check(refreshed == 1, "Umschalt baut den offenen Tooltip neu auf (Strg nicht)")
shift = false

-- ===== Markttrennung =====
UnitFactionGroup = function() return "Alliance", "Allianz" end
lines = hover(KUPFER)
check(#lines == 1 and lines[1]:find("noch kein Scan", 1, true), "anderer Markt: keine fremden Preise")
check(D.Market() == nil and D.Markets()["Classic Beta PvE / Horde"] ~= nil, "Daten bleiben im eigenen Markt")
UnitFactionGroup = function() return "Horde", "Horde" end

-- ===== Neutrales Auktionshaus (ab 0.40) =====
do
    local oldOpen, oldExists, oldUFG = ns.Scan.ahOpen, rawget(_G, "UnitExists"), UnitFactionGroup
    UnitExists = function(u) return u == "npc" end
    UnitFactionGroup = function(u) if u == "npc" then return nil end return "Horde", "Horde" end
    ns.Scan.ahOpen = false
    check(ns.MarketKey() == "Classic Beta PvE / Horde", "neutral: ohne offenes Auktionshaus der eigene Markt")
    ns.Scan.ahOpen = true
    check(ns.MarketKey() == "Classic Beta PvE / Neutral", "neutral: Auktionator ohne Fraktion ergibt den Markt Neutral")
    check(D.Market() == nil and D.Markets()["Classic Beta PvE / Horde"] ~= nil, "neutral: keine Preise aus dem eigenen Markt")
    UnitFactionGroup = function(u) if u == "npc" then return "Horde", "Horde" end return "Horde", "Horde" end
    check(ns.MarketKey() == "Classic Beta PvE / Horde", "neutral: Auktionator der eigenen Fraktion bleibt im eigenen Markt")
    ns.Scan.ahOpen, UnitExists, UnitFactionGroup = oldOpen, oldExists, oldUFG
end

-- ===== Umbau U1 (ab 0.42): Heimatmarkt, Zeile "Neutral" =====
;(function()
    local oldOpen, oldExists, oldUFG = ns.Scan.ahOpen, rawget(_G, "UnitExists"), UnitFactionGroup
    local home = D.Markets()["Classic Beta PvE / Horde"]
    local he = home.items[2770]
    local before = hover(KUPFER)
    local valueBefore = ns.ItemValue(2770, 10)
    check(not before[3] or not before[3]:find("Neutral", 1, true), "U1: ohne neutrale Daten keine Zeile Neutral")
    -- neutraler Markt mit doppeltem Preis
    local nm = D.Market("Classic Beta PvE / Neutral", true)
    nm.lastScan = clock
    nm.items[2770] = { m = he.m * 2, md = he.md * 2, q = 10, n = 2, t = clock }
    -- am neutralen Auktionshaus
    UnitExists = function(u) return u == "npc" end
    UnitFactionGroup = function(u) if u == "npc" then return nil end return "Horde", "Horde" end
    ns.Scan.ahOpen = true
    check(ns.MarketKey() == "Classic Beta PvE / Neutral" and ns.HomeMarketKey() == "Classic Beta PvE / Horde", "U1: am neutralen Haus zwei Maerkte")
    local at = hover(KUPFER)
    check(at[1] == before[1], "U1: Tooltip zeigt am neutralen Haus den Preis der eigenen Fraktion (" .. tostring(at[1]) .. ")")
    check(ns.ItemValue(2770, 10) == valueBefore, "U1: Wert fuer Ledger und Berufe aus dem Heimatmarkt")
    check(ns.MarketKey() == "Classic Beta PvE / Neutral", "U1: nach dem Tooltip wieder der Markt am offenen Haus")
    local function neutralLine(lines) for _, l in ipairs(lines) do if l:find("^Neutral = ") then return l end end end
    check(neutralLine(at) == nil, "U1: Standard: ohne Umschalt keine Zeile Neutral")
    shift = true
    local nl = neutralLine(hover(KUPFER))
    check(nl and nl:find("(+100 %)", 1, true), "U1: mit Umschalt Zeile Neutral mit Abstand: " .. tostring(nl))
    ns.Tooltip.LayoutLine("neutral").when = "off"
    check(neutralLine(hover(KUPFER)) == nil, "U1: Einstellung aus")
    shift = false
    ns.Tooltip.LayoutLine("neutral").when = "always"
    check(neutralLine(hover(KUPFER)) ~= nil, "U1: Einstellung immer, auch ohne Umschalt")
    nm.items[2770].gone = clock
    check(neutralLine(hover(KUPFER)) == nil, "U1: neutral zurzeit keine Angebote: keine Zeile")
    ns.Tooltip.LayoutLine("neutral").when = "shift"
    ns.Scan.ahOpen, UnitExists, UnitFactionGroup = oldOpen, oldExists, oldUFG
    D.DeleteMarket("Classic Beta PvE / Neutral")
    check(ns.WithHome(function() return ns.MarketKey() end) == "Classic Beta PvE / Horde" and ns.marketOverride == nil, "U1: WithHome setzt den Markt zurueck")
    local ok = pcall(ns.WithHome, function() error("x") end)
    check(not ok and ns.marketOverride == nil, "U1: auch nach einem Abbruch")
end)()

-- ===== Umbau U2 (ab 0.43): Anteil des Auktionshauses je Markt =====
;(function()
    local C = ns.Cut
    check(C.FactionOfSender("Auktionshaus der Allianz") == "Alliance" and C.FactionOfSender("Horde Auction House") == "Horde"
      and C.FactionOfSender("Auktionshaus der Schwarzmeerräuber") == "Neutral" and C.FactionOfSender("Mirel") == nil, "U2: Haus am Absender")
    check(D.Cut("Classic Beta PvE / Neutral") == 0.05 and not D.CutSure("Classic Beta PvE / Neutral") and D.CutSure("Classic Beta PvE / Horde"), "U2: ohne Messung 5 %, Neutral ungeprueft")
    -- Briefkasten mit drei Verkaufsrechnungen: zwei neutral (15 %), eine Allianz-Rechnung zu klein
    local mails = {
      { "Auktionshaus der Schwarzmeerräuber", "Auktion erfolgreich: A", { "seller", "A", "X", 10000, 10000, 0, 1500 } },
      { "Auktionshaus der Schwarzmeerräuber", "Auktion erfolgreich: B", { "seller", "B", "Y", 0, 20000, 0, 3000 } },
      { "Auktionshaus der Allianz", "Auktion erfolgreich: C", { "seller", "C", "Z", 1000, 1000, 0, 50 } },
      { "Auktionshaus der Allianz", "Auktion gewonnen: D", { "buyer", "D", "Z", 50000, 50000, 0, 0 } },
    }
    GetInboxNumItems = function() return #mails end
    GetInboxHeaderInfo = function(i) return nil, nil, mails[i][1], mails[i][2] end
    GetInboxInvoiceInfo = function(i) return unpack(mails[i][3]) end
    fire("MAIL_INBOX_UPDATE")
    check(PeonBrokerDB.cut.Neutral and PeonBrokerDB.cut.Neutral.n == 2 and math.abs(D.Cut("Classic Beta PvE / Neutral") - 0.15) < 1e-9, "U2: Anteil neutral aus zwei Rechnungen 15 %")
    check(D.CutSure("Classic Beta PvE / Neutral") and PeonBrokerDB.cut.Alliance == nil, "U2: kleine Verkaeufe und Kaeufe zaehlen nicht")
    fire("MAIL_INBOX_UPDATE")
    check(PeonBrokerDB.cut.Neutral.n == 2, "U2: dieselben Rechnungen zaehlen nur einmal")
    check(D.Cut("Classic Beta PvE / Horde") == 0.05, "U2: Heimatmarkt bleibt 5 %")
    -- Tooltip: Abstand nach Gebuehr (neutral doppelter Preis, 15 % statt 5 % -> +79 %)
    local he = D.Markets()["Classic Beta PvE / Horde"].items[2770]
    local nm = D.Market("Classic Beta PvE / Neutral", true)
    nm.lastScan = clock
    nm.items[2770] = { m = he.m * 2, md = he.md * 2, q = 10, n = 2, t = clock }
    local text = plain(ns.Tooltip.NeutralText(nm.items[2770], he.m))
    local expect = math.floor((he.m * 2 * 0.85 - he.m * 0.95) / (he.m * 0.95) * 100 + 0.5)
    check(text:find("(+" .. expect .. " %)", 1, true) and not text:find("?", 1, true), "U2: Abstand nach Gebuehr beider Haeuser: " .. text)
    PeonBrokerDB.cut = nil
    check(plain(ns.Tooltip.NeutralText(nm.items[2770], he.m)):find("?", 1, true), "U2: ungemessen mit Fragezeichen")
    check(ns.Cut.Report():find("Neutral noch nicht gemessen", 1, true), "U2: Bericht ohne Messung")
    D.DeleteMarket("Classic Beta PvE / Neutral")
    GetInboxNumItems, GetInboxHeaderInfo, GetInboxInvoiceInfo = nil, nil, nil
    C.seen = {}
end)()

-- ===== Zweiter Scan am selben Tag: Tageswert und Trend =====
clock = clock + 20 * 60
LISTINGS[1][5] = 10 * 130
S.Start()
fire("REPLICATE_ITEM_LIST_UPDATE")
while S.state do S.Step() end
cu = market.items[2770]
local dd = D.ParseDays(cu.d)
check(#dd == 1 and dd[1][2] == 250 and dd[1][5] == 2, "F7: zwei Scans am Tag -> Summe und Anzahl")
check(cu.pm == 120 and cu.m == 130 and cu.pmd == 160, "F6: Vorwerte gemerkt")
shift = true
lines = hover(KUPFER)
check(lines[1] == "Broker = 1s 24c [trend_up1]", "Trend Erloes gegenueber vorherigem Scan (+8 %), nur ein Pfeil")
check(lines[2] == "Markt = ab 1s 30c · 120 Stück · vor 1 Min." and not lines[2]:find("trend", 1, true), "U5: Markt ohne Pfeile")
check(lines[3] == "Absatz = etwa 720 am Tag", "U5: Absatz am Tag")

-- ===== Zweiter Tag: 7-Tage-Werte, verschwundener Gegenstand =====
clock = clock + 86400
local leinen = table.remove(LISTINGS, 5)         -- Leinenstoff ausverkauft (nur noch ein Gebot)
S.Start()
fire("REPLICATE_ITEM_LIST_UPDATE")
while S.state do S.Step() end
lines = hover(KUPFER)
check(lines[3] == "Absatz = " .. ns.L.TT_SALES_NONE, "U5: ohne beobachteten Verkauf: " .. tostring(lines[3]))
local le = market.items[2589]
check(le.q == 0 and le.gone == clock and le.m == 3, "verschwundener Gegenstand: 0 Angebote, letzte Preise bleiben")
lines = hover(LEINEN)
check(lines[1] == "Broker = Händler: 10c" and lines[2] == "Markt = zuletzt 3c · vor 24 Std.", "Tooltip: keine Angebote, zuletzt gesehen")
check(lines[#lines]:find("Zurzeit keine Angebote", 1, true), "Hinweis keine Angebote")
shift = false
table.insert(LISTINGS, 5, leinen)

-- ===== Verdichten: alte Tage -> Wochen, sehr Altes loeschen =====
market.items[9999] = { m = 7, md = 7, q = 1, n = 1, t = clock - 400 * 86400, d = (D.Day(clock) - 400) .. ":7:7:1:1" }
mod.db.dataDays = 14
clock = clock + 20 * 86400
S.Start()
fire("REPLICATE_ITEM_LIST_UPDATE")
while S.state do S.Step() end
cu = market.items[2770]
check(#D.ParseDays(cu.d) == 1 and cu.w ~= nil and #D.ParseDays(cu.w) >= 1, "Tageswerte aelter als 14 Tage -> Wochenwerte")
check(market.items[9999] == nil, "sehr alte Eintraege geloescht")
mod.db.dataDays = 30

-- ===== Abbruch und Zeitueberschreitung =====
clock = clock + 3600
S.Start()
fire("REPLICATE_ITEM_LIST_UPDATE")
S.Step()
fire("AUCTION_HOUSE_CLOSED")
check(S.state == nil and said("Scan abgebrochen"), "Schliessen waehrend des Lesens bricht ab")
check(market.scans == 4, "abgebrochener Scan zaehlt nicht")
fire("AUCTION_HOUSE_SHOW")
clock = clock + 3600
S.Start()
timers[#timers]()
check(S.state == nil and said("keine Antwort"), "Zeitueberschreitung ohne Daten")

-- ===== Broker-Fenster, Reiter "Preise" (0.7) =====
local Win, P = ns.Window, ns.Item
check(next(Win.WIP) == nil, "N6: kein Reiter mehr in Arbeit")
check(market.items[2770].nm == "Kupfererz" and market.items[2770].ql == 1, "Scan merkt Name und Qualitaet")
check(market.items["15000:1047"].nm == "Schwert des Baeren" and market.items["15000:1047"].ql == 2, "Name bei Ausruestung mit Zusatz")
check(D.LinkFromKey(2770) == "item:2770" and D.KeyFromLink(D.LinkFromKey("15000:1047")) == "15000:1047", "Link aus Schluessel und zurueck")
check(Win.Lower("ÄÖÜ Erz") == "äöü erz", "Suche: Umlaute klein")
fire("AUCTION_HOUSE_SHOW")
check(_G.PeonBrokerWindowButton == nil, "0.41.1: kein Knopf Broker mehr am Auktionshaus")
check(not (_G.PeonBrokerFrame and _G.PeonBrokerFrame.shown), "Fenster oeffnet nicht von selbst (Standard)")
Win.Open()
local wf = _G.PeonBrokerFrame
check(wf.shown and wf.points[1][2] ~= AuctionHouseFrame, "U12: Fenster oeffnet frei, ohne Andocken am Auktionshaus")
check(wf.w == 800 and wf.h == 538 and wf.template == "PortraitFrameTemplate", "N1: Fenster mit Peon.UI in der Groesse des Auktionshauses")
local escape = false
for _, n in ipairs(UISpecialFrames) do if n == "PeonBrokerFrame" then escape = true end end
check(escape, "Escape schliesst das Fenster")
local names = {}
for _, b in ipairs(Win.tabButtons) do names[#names + 1] = b.text end
check(table.concat(names, ",") == "Markt,Verkaufen,Auktionen,Einkaufen,Fokus,Beobachten,Chancen,Mehr",
  "0.105: Reiter Markt, Verkaufen, Auktionen, Einkaufen, Fokus, Beobachten, Chancen, Mehr (Radar in Chancen): " .. table.concat(names, ","))
check(Win.tabButtons[2].key == "sell" and Win.tabButtons[2].disabled, "N1: Verkaufen ist unterwegs grau")
check(Win.current == "more" and Win.more and Win.more.current == "prices", "Fenster oeffnet beim zuletzt gewaehlten Reiter (0.82: Gegenstand unter Mehr)")
check(Win.status and Win.status.text.text:find("letzter Stand, nicht live", 1, true) == nil and Win.status.text.text:find("Scan", 1, true),
  "N1: Statuszeile nennt Markt und Scan: " .. tostring(Win.status.text.text))
check(ns.Start == nil and Win.pages.start == nil, "U12: Startseite entfaellt")
Win.Select("buy")
check(Win.current == "buy" and mod.db.windowTab == "buy", "N1: Reiter Einkaufen gewaehlt und gemerkt")
Win.tabButtons[2].scripts.OnClick(Win.tabButtons[2])
check(Win.current == "buy" and Win.tabButtons[2].disabled, "N1: Klick auf Verkaufen bleibt beim bisherigen Reiter")
Win.tabButtons[8].scripts.OnClick(Win.tabButtons[8])   -- ab 0.105 ohne Radar
check(Win.current == "more" and Win.more.current == "prices" and Win.contents.more.shown and not Win.contents.buy.shown, "0.82: Mehr mit Gegenstand gewaehlt, andere Seite verborgen")
-- ===== Neuaufbau N2 (0.60): Seite Gegenstand =====
check(ns.Prices == nil and P == ns.Item and P.results and P.tiers and P.header, "N2: Seite Gegenstand mit Peon.UI ersetzt den Reiter Preise")
check(P.key == nil and P.Mode() == "results" and P.resultPanel.shown and not P.detail.shown, "N2: ohne gewaehlten Gegenstand die Suche")
check(#P.results.items == 0 and P.results.empty.text == ns.L.ITEM_SEARCH_HINT, "N2: Hinweis, was man tun kann")
check(Win.status.text.text:find("PvE Horde", 1, true) and Win.status.text.text:find("Scan", 1, true), "N1: Statuszeile mit Markt und Scan: " .. tostring(Win.status.text.text))
local function typed(text) P.search:SetText(text); P.search.scripts.OnTextChanged(P.search, true) end
typed("ERZ")
check(#P.results.items == 1 and P.results.items[1].key == 2770 and P.count.text == "1 Treffer", "Suche: Teil des Namens, Gross/klein egal")
typed("e")
check(#P.results.items == 0 and P.results.empty.text == ns.L.ITEM_SEARCH_HINT, "N2: ein Buchstabe sucht noch nicht")
typed("xyz")
check(#P.results.items == 0 and P.results.empty.text == "Nichts gefunden.", "Suche ohne Treffer")
typed("schwert")
check(#P.results.items == 2 and P.results.items[1].name == "Schwert des Affen", "Suche: zwei Schwerter, nach Name")
local row1 = P.results.list.rows[1]
check(row1.cells[1].text == "Schwert des Affen" and row1.cells[2].text ~= "", "Zeile mit Name und Preis")
row1.scripts.OnEnter(row1)
check(tt.hyper == "item:15000::::::1048", "Maus ueber Zeile zeigt Gegenstand im Tooltip")
local oldCap = P.RESULT_MAX
P.RESULT_MAX = 1
typed("schwert")
check(#P.results.items == 1 and P.count.text == "1 von 2 Treffern, genauer suchen", "N2: Trefferliste ist begrenzt, der Zaehler sagt es")
P.RESULT_MAX = oldCap
typed("kupfer")
P.results.list.rows[1].scripts.OnClick(P.results.list.rows[1], "LeftButton")
check(P.key == 2770 and mod.acc.itemKey == 2770 and P.Mode() == "detail" and P.detail.shown and not P.resultPanel.shown and (P.search.text or "") == "",
  "N2: Klick waehlt den Gegenstand, zeigt die Einzelheiten und leert die Suche")
check(P.header.name.text == "Kupfererz" and P.item.id == 2770, "N2: Kopf mit dem Namen")
local function rowsText()
  local t = {}
  for _, r in ipairs(P.shownRows) do t[#t + 1] = plain((r[1] or "") .. ": " .. (r[2] or r.head or r.hint or "")) end
  return table.concat(t, " | ")
end
local dt = rowsText()
check(dt:find("Markt: ab ", 1, true) and dt:find("Händler: 5c je Stück", 1, true) and dt:find("Art: Massenware", 1, true),
  "N2: Werte wie im Tooltip, Haendlerpreis, Art (" .. dt .. ")")
check(not dt:find("Mein Bestand", 1, true), "N2: ohne Ledger kein Abschnitt Mein Bestand")
check(P.rows[1].label.shown and P.rows[1].label.text == "Markt" and plain(P.rows[1].value.text):find("ab ", 1, true), "N2: Zeilen links gefuellt")
local tiers = P.tiers.items
check(#tiers >= 2 and tiers[1].price <= tiers[2].price and tiers[2].cum == tiers[1].qty + tiers[2].qty
  and tiers[2].cost == tiers[1].cost + tiers[2].price * tiers[2].qty, "N2: Preisstufen guenstigste zuerst, mit Summen bis hier")
do
  local e = market.items[2770]
  local today = D.Day()
  local hist = D.History(e)
  local hasWeek = false for _, h in ipairs(hist) do if h.week then hasWeek = true end end
  check(#hist >= 2 and hasWeek, "Verlauf: Tage und Wochen in der Datenbank")
  local old = { d = e.d, w = e.w }
  e.d = D.JoinDays({ { today - 1, 100, 150, 40, 1 }, { today, 240, 320, 100, 2 } })
  e.w = D.JoinDays({ { math.floor((today - 20) / 7), 90, 140, 30, 5 } })
  local mins, meds, qtys, got = P.Series(e, 7, today)
  check(got == 2 and mins[7] == 120 and meds[7] == 160 and qtys[7] == 50 and mins[6] == 100 and mins[5] == nil, "N2: Diagramm: Tageswerte, Luecken bleiben leer")
  local m30, _, _, got30 = P.Series(e, 30, today)
  local wk = math.floor((today - 20) / 7) * 7
  check(got30 == 9 and m30[30 - (today - wk)] == 90 and m30[30 - (today - wk - 6)] == 90, "N2: Diagramm: Wochenwert gilt fuer alle sieben Tage")
  P.SetPeriod(7)
  check(mod.acc.itemDays == 7 and P.periodButtons[7].disabled and not P.periodButtons[14].disabled and not P.chartEmpty.shown, "N2: Zeitraum gewaehlt, Diagramm gezeichnet")
  e.d, e.w = "", ""
  P.Refresh()
  check(P.chartEmpty.shown, "N2: ohne Verlauf ein Hinweis statt des Diagramms")
  e.d, e.w = old.d, old.w
  P.SetPeriod(14)
end
Win.Refresh()
check(P.key == 2770 and P.Mode() == "detail", "Auswahl bleibt beim Aktualisieren")
check(not P.marketButton.disabled and not P.watchButton.disabled and not P.listButton.disabled, "N3: alle drei Knoepfe aktiv, auch unterwegs")
P.watchButton.scripts.OnClick(P.watchButton)
check(ns.Watch.Is(2770) and P.watchButton.text == "Nicht beobachten", "N2: Beobachten per Knopf")
P.watchButton.scripts.OnClick(P.watchButton)
check(not ns.Watch.Is(2770) and P.watchButton.text == "Beobachten", "N2: und wieder aus")
-- Gegenstand ohne gemerkten Namen (Daten von 0.6): Name vom Spiel
market.items[2589].nm = nil; P.cache = nil
P.Show(2589)
check(P.header.name.text == "Gegenstand2589", "ohne gemerkten Namen: Name vom Spiel")
P.Show(2770)
-- ab 0.53 (U12): kein Andocken mehr; Fenster schliessen und frei oeffnen, Position wird gemerkt
fire("AUCTION_HOUSE_CLOSED")
SlashCmdList.PEON_BROKER("")
check(not wf.shown, "/broker schliesst")
SlashCmdList.PEON_BROKER("")
check(wf.shown and not Win.docked and wf.points[1][1] == "CENTER", "/broker oeffnet das Fenster frei (Mitte)")
wf.points = { { "TOPLEFT", UIParent, "TOPLEFT", 100.4, -80.6 } }
wf.scripts.OnDragStop(wf)
check(mod.db.windowPos.point == "TOPLEFT" and mod.db.windowPos.x == 100 and mod.db.windowPos.y == -81, "Position gemerkt")
SlashCmdList.PEON_BROKER("")
check(not wf.shown, "/broker schliesst das Fenster wieder")
SlashCmdList.PEON_BROKER("")
check(wf.points[1][1] == "TOPLEFT" and wf.points[1][4] == 100, "gemerkte Position beim Oeffnen")
fire("AUCTION_HOUSE_SHOW")
check(wf.shown and not Win.docked and wf.points[1][4] == 100, "U12: offenes Fenster bleibt beim Auktionshaus an seiner Stelle")
fire("AUCTION_HOUSE_CLOSED")
check(wf.shown and mod.db.windowWithAH == nil, "U12: schliesst nicht mit dem Auktionshaus, Einstellung entfaellt")
SlashCmdList.PEON_BROKER("")
-- ohne Scan im Markt: Hinweis
PeonBrokerDB.markets["Classic Beta PvE / Horde"], P.cache = nil, nil
SlashCmdList.PEON_BROKER("")
check(Win.current == "more" and Win.more.current == "prices", "zuletzt gewaehlter Reiter (0.82: Gegenstand unter Mehr)")
Win.Select("prices")
check(P.Mode() == "detail" and rowsText():find(ns.L.ITEM_NO_DATA, 1, true) and #P.tiers.items == 0, "N2: ohne Preisdaten ein Hinweis statt der Werte")
typed("ku")
check(#P.results.items == 0 and P.results.empty.text:find("Noch kein Scan", 1, true), "ohne Scan: Hinweis in der Liste")
typed("")
SlashCmdList.PEON_BROKER("")
PeonBrokerDB.markets["Classic Beta PvE / Horde"], P.cache = market, nil
fire("AUCTION_HOUSE_SHOW")

-- ===== Neuaufbau N3 (0.61): Seite Markt aus Scandaten =====
do
  local Mk = ns.Market
  C_Item.GetItemInfoInstant = function(id) return id, "Typ", "Untertyp", "", 1, (id == 15000) and 2 or 7, (id == 2770) and 7 or ((id == 2589) and 5 or 8) end
  C_Item.GetItemClassInfo = function(c) return c == 7 and "Handwerkswaren" or "Waffen" end
  C_Item.GetItemSubClassInfo = function(c, sc) return ({ [5] = "Stoff", [7] = "Metall & Stein", [8] = "Schwerter" })[sc] end
  fire("AUCTION_HOUSE_CLOSED")
  Win.Open("browse")
  check(Win.current == "browse" and Mk.list and Mk.cats and not Win.contents.browse.wipText, "N3: Markt unterwegs mit Inhalt statt WIP-Hinweis")
  local nodes = {}
  for _, n in ipairs(Mk.cats.nodes) do nodes[#nodes + 1] = n.key .. "=" .. n.text end
  check(table.concat(nodes, ",") == "c2=Waffen,c7=Handwerkswaren,c7/s5=Stoff,c7/s7=Metall & Stein", "N3: Kategorien mit Namen vom Spiel: " .. table.concat(nodes, ","))
  check(#Mk.list.items == 0 and Mk.list.empty.text == ns.L.MARKET_START_EMPTY and Mk.count.text == "", "N3: Startseite ohne Listen: Hinweis")
  ns.Watch.Add(2770, { name = "Kupfererz" })
  Mk.Refresh()
  check(#Mk.list.items == 1 and Mk.list.items[1].key == 2770 and Mk.count.text:find("1 Gegenst", 1, true), "N3: Startseite zeigt Beobachtung und Einkaufslisten")
  ns.Watch.Remove(2770)
  Mk.cats.list.o.onClick(Mk.cats.byKey["c7"])
  check(Mk.category == "c7" and #Mk.list.items == 2 and Mk.count.text == "2 Treffer", "N3: Kategorie Handwerkswaren: Kupfererz und Leinenstoff")
  Mk.cats.list.o.onClick(Mk.cats.byKey["c7/s5"])
  check(#Mk.list.items == 1 and Mk.list.items[1].key == 2589, "N3: Unterkategorie Stoff")
  Mk.cats.list.o.onClick(Mk.cats.byKey["c7/s5"])
  check(Mk.category == "c7" and #Mk.list.items == 2, "N3: nochmal klicken waehlt die Kategorie darueber")
  Mk.search:SetText("kupfer"); Mk.search.scripts.OnTextChanged(Mk.search, true)
  check(#Mk.list.items == 1 and Mk.list.items[1].name == "Kupfererz" and Mk.list.items[1].min == market.items[2770].m, "N3: Suche innerhalb der Kategorie")
  Mk.Find("Schwert")
  check(Mk.category == nil and #Mk.list.items == 2 and Mk.search.text == "Schwert", "N3: Suche ohne Kategorie ueber alles")
  local oldMax = Mk.MAX
  Mk.MAX = 1; Mk.Refresh()
  check(#Mk.list.items == 1 and Mk.count.text == "1 von 2 Treffern, genauer suchen", "N3: Liste begrenzt, Zaehler sagt es")
  Mk.MAX = oldMax; Mk.Refresh()
  check(not Mk.marketBox.shown and Mk.stand.text:find("Stand", 1, true), "N3: ein Markt: keine Auswahl, Stand der Daten")
  PeonBrokerDB.markets["Classic Beta PvE / Neutral"] = { items = { [2770] = { m = 999, md = 999, q = 3, n = 1, t = clock, nm = "Kupfererz" } }, lastScan = clock }
  Mk.Refresh()
  check(Mk.marketBox.shown and #Mk.Markets() == 2, "N3: zwei Maerkte: Auswahl sichtbar")
  Mk.marketKey = "Classic Beta PvE / Neutral"
  Mk.Find("kupfer")
  check(#Mk.list.items == 1 and Mk.list.items[1].min == 999, "N3: gewaehlter Markt bestimmt die Preise")
  Mk.marketKey = nil
  PeonBrokerDB.markets["Classic Beta PvE / Neutral"] = nil
  Mk.Find("kupfer")
  Mk.list.list.rows[1].scripts.OnClick(Mk.list.list.rows[1], "LeftButton")
  check((Win.current == "more" and Win.more.current == "prices") and P.key == 2770 and ns.Go.back == "browse" and Win.back.shown and Win.back.text == "Zurück zu Markt",
    "N3: Klick zeigt den Gegenstand, Zurueck fuehrt zum Markt")
  Win.back.scripts.OnClick(Win.back)
  check(Win.current == "browse", "N3: zurueck auf der Marktseite")
  Mk.Find("")
  Win.Select("prices")
  fire("AUCTION_HOUSE_SHOW")
end

-- ===== Reiter "Verkaufen" (0.8, ab 0.10 ueber das Verkaufsfenster des Auktionshauses) =====
local Sell = ns.Live   -- ab 0.55 nur noch die Bausteine (Live-Ergebnisse lesen)
local lvMin, lvMed, lvQty, lvOwn = D.LiveValues({ { price = 110, qty = 5, own = 5 }, { price = 115, qty = 8, own = 0 }, { price = 150, qty = 7, own = 2 } })
check(lvMin == 115 and lvOwn == 110 and lvQty == 20 and lvMed == 115, "F21/F22: Min ohne eigene, Median ueber alle")

-- Taschen und Auktionshaus fuer den Verkauf
local BAG = {
  { itemID = 2770, stackCount = 20, hyperlink = "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r", quality = 1 },
  { itemID = 2770, stackCount = 40, hyperlink = "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r", quality = 1 },
  { itemID = 2589, stackCount = 10, hyperlink = "|cffffffff|Hitem:2589::::::::20:1488:::::::::|h[Leinenstoff]|h|r", quality = 1 },
  { itemID = 15000, stackCount = 1, hyperlink = "|cff1eff00|Hitem:15000::::::1047::20:::::::::|h[Schwert des Baeren]|h|r", quality = 2 },
  { itemID = 9999, stackCount = 1, hyperlink = "|cffffffff|Hitem:9999::::::::20:::::::::|h[Seelengebunden]|h|r", quality = 1, isBound = true },
}
local savedContainer, AHs = C_Container, C_AuctionHouse
local savedValid, savedStatus, savedPostC = AHs.IsSellItemValid, AHs.GetItemCommodityStatus, AHs.PostCommodity
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and #BAG or 0 end,
  GetContainerItemInfo = function(bag, slot) if bag == 0 then return BAG[slot] end end }
AHs.IsSellItemValid = function(loc) return BAG[loc.slot] and not BAG[loc.slot].isBound end
AHs.GetItemCommodityStatus = function(loc) return BAG[loc.slot].itemID == 15000 and 1 or 2 end
AHs.GetAvailablePostCount = function(loc) local n, id = 0, BAG[loc.slot].itemID for _, b in ipairs(BAG) do if b.itemID == id then n = n + b.stackCount end end return n end
AHs.GetItemKeyFromItem = function(loc) return { itemID = BAG[loc.slot].itemID, itemLevel = 20, itemSuffix = 0 } end  -- wie im Spiel: mit Gegenstandsstufe
local query
AHs.SendSellSearchQuery = function(itemKey, sorts, separate) query = { key = itemKey, sorts = sorts, separate = separate } end
AHs.SendSearchQuery = function(itemKey, sorts, separate) query = { key = itemKey, sorts = sorts, separate = separate, normal = true } end
local LIVE = { [2770] = { { unitPrice = 115, quantity = 8 }, { unitPrice = 120, quantity = 40 }, { unitPrice = 150, quantity = 50 }, { unitPrice = 160, quantity = 20 } } }
AHs.GetNumCommoditySearchResults = function(id) return #(LIVE[id] or {}) end
AHs.GetCommoditySearchResultInfo = function(id, i) return LIVE[id][i] end
local LIVEITEM = { { buyoutAmount = 5200, quantity = 3 }, { buyoutAmount = 9000, quantity = 1 } }  -- 3 gleiche Angebote zu je 52s
AHs.GetNumItemSearchResults = function() return #LIVEITEM end
AHs.GetItemSearchResultInfo = function(_, i) return LIVEITEM[i] end
local posted, confirmNeeded = {}, false
AHs.PostCommodity = function(loc, dur, qty, price) posted[#posted + 1] = { "C", loc.slot, dur, qty, price } return confirmNeeded end
AHs.PostItem = function(loc, dur, qty, bid, price) posted[#posted + 1] = { "I", loc.slot, dur, qty, price, bid } return false end
local confirmed
AHs.ConfirmPostCommodity = function(loc, dur, qty, price) confirmed = { loc.slot, dur, qty, price } end

-- Nachgebautes Verkaufsfenster des Auktionshauses (Feldnamen wie in Blizzard_AuctionHouseSellFrame.lua)
local function SellFrameMock(kind)
  local f = { shown = false, kind = kind, clicked = 0 }
  f.PriceInput = { SetAmount = function(_, v) f.price = v end, GetAmount = function() return f.price end }
  f.QuantityInput = { SetQuantity = function(_, v) f.qty = v end, GetQuantity = function() return f.qty end }
  f.Duration = { SetDuration = function(_, i) f.dur = i end }
  f.GetDuration = function() return f.dur end
  f.IsShown = function() return f.shown end
  f.SetItem = function(_, loc) f.loc = loc end
  f.PostButton = { IsEnabled = function() return f.enabled ~= false end, Click = function()
    if f.enabled == false then return end   -- gesperrter Knopf reagiert nicht
    f.clicked = f.clicked + 1
    if kind == "C" then AHs.PostCommodity(f.loc, f.dur, f.qty, f.price) else AHs.PostItem(f.loc, f.dur, f.qty, nil, f.price) end
  end }
  return f
end
local CSF, ISF = SellFrameMock("C"), SellFrameMock("I")
local function WithBlizzard(on)
  if on then
    AuctionHouseFrame.CommoditiesSellFrame, AuctionHouseFrame.ItemSellFrame = CSF, ISF
    AuctionHouseFrame.SetPostItem = function(_, loc)
      local c = BAG[loc.slot].itemID ~= 15000
      CSF.shown, ISF.shown = c, not c
      if c then CSF.loc = loc else ISF.loc = loc end
    end
  else
    AuctionHouseFrame.CommoditiesSellFrame, AuctionHouseFrame.ItemSellFrame, AuctionHouseFrame.SetPostItem = nil, nil, nil
  end
end
WithBlizzard(true)

fire("AUCTION_HOUSE_CLOSED"); fire("AUCTION_HOUSE_SHOW")
check(PeonBrokerDB.commodity["15000:1047"] == false and PeonBrokerDB.commodity[2770] == true, "Warenart der Taschen vom Spiel")
if not wf.shown then Win.Toggle() end
-- ab 0.55 (Umbau U12): Reiter Verkaufen, Behalten und Meine Auktionen entfallen, ihre Tests mit ihnen.
-- Was weiter gilt: Rat im Verkaufsfenster (U3), Blizzards Reiter Auktionen (U9), Live.lua und Stock.lua.
local Auc, K = ns.Auctions, ns.Stock
-- Vorrat = Taschen + Bank (bis 0.54 im Behalten-Test aufgebaut, spaetere Abschnitte brauchen ihn)
local BANK = { [2770] = 5 }
C_Item.GetItemCount = function(id, bank)
  local n = 0
  for _, b in ipairs(BAG) do if b.itemID == id then n = n + b.stackCount end end
  if bank then n = n + (BANK[id] or 0) end
  return n
end
local b0, k0, t0 = K.Counts(2770)
check(b0 == 60 and k0 == 5 and t0 == 65, "U12: Vorrat zaehlen (Stock.lua): 60 Taschen, 5 Bank")
local SWLINK = "|cff1eff00|Hitem:15000::::::1047::20:::::::::|h[Schwert des Baeren]|h|r"
local KLINK = "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r"
local function ttLines(link)
  tt.lines = {}
  ns.Tooltip.AddLines(GameTooltip, link, 1)
  return tt.lines
end
check(ns.Sell == nil and ns.Keep == nil and Win.pages.sell == nil and Win.pages.keep == nil, "U12: Verkaufen und Behalten entfallen")
check(PeonBrokerCharDB.keep == nil and PeonBrokerDB.sellMem == nil, "U12: gespeicherte Behalten-Liste und Verkaufen-Gedaechtnis geloescht")
check(type(ns.Live.ReadCommodity) == "function" and type(ns.Stock.Counts) == "function" and type(Auc.StartLive) == "function", "U12: Bausteine bleiben (Live, Stock, Auktionen)")

-- ===== Reiter "Einkaufsliste" (0.13, ab 0.14 eigener Reiter) =====
local Buy = ns.Buy
-- Rechenmodell Kapitel 5
check(D.Levels({ 120, 10, 150, 40, 120, 5, 90, 1, 200, 1, 300, 1, 400, 1 }, 5) == "90:1;120:15;150:40;200:1;300:1", "LV: guenstigste 5 Stufen, gleiche Preise zusammengefasst")
check(D.LEVELS == 12 and select(2, D.Levels({ 1, 1, 2, 1, 3, 1, 4, 1, 5, 1, 6, 1, 7, 1, 8, 1, 9, 1, 10, 1, 11, 1, 12, 1, 13, 1 }):gsub(";", "")) == 11, "ab 0.17: 12 Stufen gespeichert")
local plv = D.ParseLevels("90:1;120:15")
check(#plv == 2 and plv[2].price == 120 and plv[2].qty == 15, "Preisstufen lesen")
local today = D.Day(clock)
check(D.ScanCount({ d = (today - 8) .. ":1:1:1:5;" .. (today - 3) .. ":1:1:1:4;" .. today .. ":1:1:1:3" }, 7, today) == 7, "F34: Scans in den letzten 7 Tagen")
check(D.MaxBuyPrice({ md = 1000 }, 10) == 900, "F29: Hoechstpreis 10 % unter dem Median")
local bq, bc = D.BelowLimit({ { price = 100, qty = 5, own = 2 }, { price = 120, qty = 10, own = 0 }, { price = 200, qty = 9, own = 0 } }, 120)
check(bq == 13 and bc == 1500, "F30: Menge und Kosten bis zur Grenze, ohne eigene")
local dbx = { dealMinVendor = 10, dealMinMarket = 50, dealScans = 10, dealDays = 7, dumpPct = 30, dealMargin = 20, dealDepth = 100 }
local dv = D.Deal(nil, { { price = 3, qty = 20, own = 0 } }, 10, dbx, today)
check(dv and dv.kind == "vendor" and dv.gain == 140 and dv.qty == 20 and dv.unitGain == 7 and dv.net == 10, "F31: Haendler-Schnaeppchen (10c - 3c) x 20 = 1s 40c, 7c je Stueck")
local em = { md = 1000, d = today .. ":10000:20000:400:12" }
local dm = D.Deal(em, { { price = 500, qty = 20, own = 0 } }, nil, dbx, today)
check(dm and dm.kind == "market" and dm.gain == 6150 and dm.limit == 500 and dm.ref == 850 and dm.unitGain == 307.5, "F33 (ab 0.26): ohne Bereich hoechstens 85 % vom Median: (8s 50c x 0,95 - 5s) x 20 = 61s 50c")
dbx.dealDepth = 20
check(D.Deal(em, { { price = 500, qty = 20, own = 0 } }, nil, dbx, today) == nil, "F33: hoechstens 20 % des Angebots, danach gleiches Angebot als Konkurrenz -> kein Schnaeppchen")
do -- Beispiel von KarloDerBaer (Abgefangene Kiste, 30.09.2026): viel billige Ware in kleinen Stufen, 120 Stueck zu 1g 26s treiben den Median
local kiste = { { 5000, 2 }, { 5500, 1 }, { 5700, 25 }, { 6000, 2 }, { 6400, 22 }, { 6500, 9 }, { 6879, 4 }, { 6900, 1 }, { 6965, 36 }, { 6969, 1 }, { 9999, 3 }, { 12000, 28 }, { 12498, 19 }, { 12600, 120 } }
local krows = {}
for i, k in ipairs(kiste) do krows[i] = { price = k[1], qty = k[2], own = 0 } end
local ek = { md = 12498, d = today .. ":124980:124980:2730:12" }
check(D.Deal(ek, krows, nil, dbx, today) == nil, "Kiste: kein Schnaeppchen (naechstes Angebot zu nah, hoechstens 20 %)")
dbx.dealDepth = 100
local dk = D.Deal(ek, krows, nil, dbx, today)
check(dk and dk.qty == 103 and dk.limit == 6969 and dk.ref == 8852, "Kiste ohne Hoechstmenge: bis 69s 69c, Wiederverkauf hoechstens 85 % von 1g 4s 15c = 88s 52c")
dbx.dealDepth = 20
local dd1 = D.Deal(ek, { { price = 3000, qty = 1, own = 0 }, { price = 10000, qty = 50, own = 0 } }, nil, { dealScans = 10, dealDays = 7, dumpPct = 30, dealMargin = 20, dealDepth = 20, dealMinMarket = 1 }, today)
check(dd1 and dd1.qty == 1 and dd1.ref == 8852 and dd1.gain == 5409, "echter Ausreisser: 1 Stueck zu 30s, Wiederverkauf 88s 52c -> 54s 9c Gewinn")
check(D.Deal(em, { { price = 500, qty = 20, own = 0 } }, 600, { radarKind = "market", dealScans = 10, dealDays = 7, dumpPct = 30, dealDepth = 100, dealMinMarket = 50, dealMinVendor = 10 }, today).kind == "market", "nur AH: Haendler nicht bewertet")
check(D.Deal(em, { { price = 500, qty = 20, own = 0 } }, 600, { radarKind = "vendor", dealScans = 10, dealDays = 7, dumpPct = 30, dealDepth = 100, dealMinMarket = 50, dealMinVendor = 10 }, today).kind == "vendor", "nur Haendler: Markt nicht bewertet")
local kc, kg, kl = D.CostOf(krows, 30)
check(kc == 2 * 5000 + 5500 + 25 * 5700 + 2 * 6000 and kg == 30 and kl == 6000, "Kosten der 30 guenstigsten Stueck")
end
dbx.dealDepth = 100
check(D.Deal(em, { { price = 500, qty = 10, own = 0 } }, nil, dbx, today) == nil, "Markt: unter dem Mindestgewinn (45s < 50s)")
check(D.Deal({ md = 1000, d = today .. ":10000:20000:400:5" }, { { price = 500, qty = 20, own = 0 } }, nil, dbx, today) == nil, "Markt: zu wenig Scans (5 < 10)")

-- Einkaufslisten
local bought, placed, purchaseStarted, purchaseConfirmed, purchaseCancelled, browse = {}, {}, nil, nil, 0, nil
AHs.StartCommoditiesPurchase = function(id, qty) purchaseStarted = { id, qty } end
AHs.ConfirmCommoditiesPurchase = function(id, qty) purchaseConfirmed = { id, qty } end
AHs.CancelCommoditiesPurchase = function() purchaseCancelled = purchaseCancelled + 1 end
AHs.PlaceBid = function(id, amount) placed[#placed + 1] = { id, amount } end
AuctionHouseFrame.SelectBrowseResult = function(_, r) browse = r end
if not wf.shown then Win.Open("buy") end
Win.Select("buy")
check(Win.current == "buy" and Buy.listsView.shown and Buy.itemList and Buy.listList, "Reiter Einkaufen")
Buy.newButton.scripts.OnClick(Buy.newButton)
check(#PeonBrokerDB.lists == 1 and PeonBrokerDB.lists[1].name == "Liste 1" and PeonBrokerDB.lists[1].pct == 10 and type(PeonBrokerDB.lists[1].id) == "string", "neue Liste (accountweit, 10 %, mit Nummer)")
Buy.nameBox:SetText("Erze"); Buy.nameBox.scripts.OnEditFocusLost(Buy.nameBox)
check(PeonBrokerDB.lists[1].name == "Erze" and Buy.listList:GetItems()[1].name == "Erze" and #Buy.listList:GetItems() == 1, "Liste umbenannt, 0.82: Beobachtung nicht mehr in Einkaufen")
Buy.searchBox:SetText("kupfer"); Buy.searchBox.scripts.OnEnterPressed(Buy.searchBox)
check(PeonBrokerDB.lists[1].items[2770] and said("zur Liste „Erze“ hinzugefügt"), "Suche: Kupfererz hinzugefuegt")
Buy.searchBox:SetText("gibtsnicht"); Buy.searchBox.scripts.OnEnterPressed(Buy.searchBox)
check(said("Nichts gefunden"), "Suche ohne Treffer")
alt = true
HandleModifiedItemClick(SWLINK)
alt = false
check(not PeonBrokerDB.lists[1].items["15000:1047"], "Alt+Klick fuegt nicht mehr hinzu (ab 0.27.1)")
Buy.AddFromLink(SWLINK)
check(PeonBrokerDB.lists[1].items["15000:1047"] and Win.current == "buy", "Hinzufuegen per Link zur Liste")
local rowsL = Buy.itemList:GetItems()
check(#rowsL == 2, "zwei Gegenstaende in der Liste")
local kuL for i, r in ipairs(rowsL) do if r.key == 2770 then kuL = i end end
local lim = D.MaxBuyPrice(market.items[2770], 10)
check(rowsL[kuL].limit == lim, "Hoechstpreis aus dem Median")
Buy.itemList.list.rows[kuL].scripts.OnClick(Buy.itemList.list.rows[kuL], "LeftButton")
check(query.normal and query.key.itemID == 2770 and browse == nil, "Anklicken: Live-Abfrage, Blizzards Ansicht bleibt (ab 0.64.1 kein SelectBrowseResult)")
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
check(Buy.live[2770] and #Buy.live[2770].rows >= 2, "Live-Angebote gelesen")
Buy.selected.limit = 130      -- feste Grenze fuer den Test: Stufen 1s 15c (8) und 1s 20c (40); ab 0.55 ohne eigene Angebote aus dem Verkaufen-Test
local plan = Buy.Plan(Buy.selected)
check(plan.qty == 48 and plan.cost == 5720 and plan.commodity, "Kaufplan: 48 Stueck fuer 57s 20c")
Buy.wishBox:SetText("100"); Buy.wishBox.scripts.OnEditFocusLost(Buy.wishBox)
check(PeonBrokerDB.lists[1].items[2770].wish == 100, "Wunschmenge gesetzt")
Buy.selected.limit = 130
plan = Buy.Plan(Buy.selected)
check(plan.qty == 35 and plan.cost == 8 * 115 + 27 * 120, "Wunschmenge 100 minus Vorrat 65 = 35")
Buy.UpdateView()
check(plain(Buy.selText.text):find("35 kaufen für 41s 60c", 1, true) and not Buy.buyButton.disabled, "Anzeige: was gekauft wuerde")
Buy.buyButton.scripts.OnClick(Buy.buyButton)
check(purchaseStarted and purchaseStarted[1] == 2770 and purchaseStarted[2] == 35 and Buy.buying, "Kauf gestartet (Massenware)")
popupShown = nil
fire("COMMODITY_PRICE_UPDATED", 120, 4200)
check(popupShown and popupShown.name == "PEON_BROKER_CONFIRM_BUY" and plain(popupShown.text):find("35× Kupfererz für 42s kaufen (1s 20c je Stück)?", 1, true), "Rueckfrage mit dem Preis vom Spiel")
StaticPopupDialogs.PEON_BROKER_CONFIRM_BUY.OnAccept(nil, popupShown.data)
check(purchaseConfirmed and purchaseConfirmed[2] == 35, "nach Ja: Kauf bestaetigt")
fire("COMMODITY_PURCHASE_SUCCEEDED")
local bPlain = false for i = #out, math.max(1, #out - 6), -1 do if plain(out[i]):find("Gekauft: 35× Kupfererz für 42s", 1, true) then bPlain = true end end
check(bPlain and PeonBrokerDB.bought == nil and not Buy.buying, "gekauft, fuers Buch vermerkt")
-- teurer als die Grenze: Warnung, Nein bricht ab
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
Buy.selected.limit = 130
Buy.buyButton.scripts.OnClick(Buy.buyButton)
popupShown = nil
fire("COMMODITY_PRICE_UPDATED", 200, 7000)
check(popupShown and plain(popupShown.text):find("Teurer als deine Grenze", 1, true), "Warnung, wenn das Spiel mehr verlangt")
StaticPopupDialogs.PEON_BROKER_CONFIRM_BUY.OnCancel(nil, popupShown.data)
check(purchaseCancelled == 1 and not Buy.buying, "Nein: Kauf abgebrochen")
-- Einzelgegenstand: guenstigstes passendes Angebot, je Klick eines
local savedLI = { LIVEITEM[1], LIVEITEM[2] }
LIVEITEM[1] = { buyoutAmount = 5200, quantity = 1, auctionID = 77, itemLink = SWLINK }
LIVEITEM[2] = { buyoutAmount = 9000, quantity = 1, auctionID = 78, itemLink = SWLINK }
local swE = market.items["15000:1047"]
local savedMd, savedD = swE.md, swE.d
swE.md, swE.d = 6000, nil
Buy.Refresh()
for i, r in ipairs(Buy.itemList:GetItems()) do if r.key == "15000:1047" then Buy.itemList.list.rows[i].scripts.OnClick(Buy.itemList.list.rows[i], "LeftButton") end end
fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 15000 })
plan = Buy.Plan(Buy.selected)
check(plan and plan.auctionID == 77 and plan.price == 5200 and plan.qty == 1, "Einzelgegenstand: guenstigstes Angebot unter der Grenze (54s)")
popupShown = nil
Buy.buyButton.scripts.OnClick(Buy.buyButton)
check(popupShown and plain(popupShown.text):find("Schwert des Baeren für 52s kaufen?", 1, true) and #placed == 0, "Rueckfrage vor dem Kauf")
StaticPopupDialogs.PEON_BROKER_CONFIRM_BUY.OnAccept(nil, popupShown.data)
check(#placed == 1 and placed[1][1] == 77 and placed[1][2] == 5200, "PlaceBid mit Sofortkaufpreis")
fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 77)
check(said("Gekauft: 1× Schwert des Baeren"), "Kauf gemeldet")
swE.md, swE.d = savedMd, savedD
LIVEITEM[1], LIVEITEM[2] = savedLI[1], savedLI[2]
Buy.removeButton.scripts.OnClick(Buy.removeButton)
check(PeonBrokerDB.lists[1].items["15000:1047"] == nil, "Gegenstand aus der Liste entfernt")
-- Zur Einkaufsliste aus dem Reiter Preise
Win.Select("prices")
P.Show(2589)
check(not P.listButton.disabled, "Gegenstand: Knopf 'Auf Einkaufsliste' aktiv")
do
  local keepMenu = MenuUtil
  MenuUtil = nil   -- ohne Blizzards Menue: auf die gewaehlte Liste
  P.listButton.scripts.OnClick(P.listButton)
  MenuUtil = keepMenu
end
check(PeonBrokerDB.lists[1].items[2589] ~= nil, "von der Seite Gegenstand hinzugefuegt")

-- ===== Radar: die Tests des alten Radars (0.14 bis 0.57) entfielen mit dem Neuaufbau N6, neue Tests weiter unten =====
local Rd = ns.Radar
Buy.pending = nil   -- offene Abfrage aus den Tests der Einkaufsliste

-- ===== 0.20: Teil-Ergebnisse, Eintragspreis, Blizzard-Fenster, weggefallene Treffer =====
;(function()   -- eigene Funktion: der Haupt-Abschnitt hat fast 200 lokale Variablen
    -- Teil-Ergebnisse: Median und Menge bleiben aus der Datenbank
    local savedHF = AHs.HasFullCommoditySearchResults
    AHs.HasFullCommoditySearchResults = function(id) return id ~= 4444 end
    LIVE[4444] = { { unitPrice = 50, quantity = 10 }, { unitPrice = 60, quantity = 10 } }
    local rowsP = Sell.ReadCommodity(4444)
    check(rowsP.partial == true and not Sell.ReadCommodity(2770).partial, "Teil-Ergebnis erkannt (HasFullCommoditySearchResults)")
    market.items[4444] = { m = 55, md = 200, q = 500, n = 40, t = clock }
    D.ApplyLive(4444, rowsP, clock + 1)
    check(market.items[4444].m == 50 and market.items[4444].md == 200 and market.items[4444].q == 500 and market.items[4444].lt == clock + 1,
        "Teil-Ergebnis: Minimum neu, Median und Menge bleiben")
    market.items[4444], LIVE[4444] = nil, nil
    AHs.HasFullCommoditySearchResults = savedHF
    -- ab 0.64.1 (Fehlerberichte 10 und 11): "Im Markt zeigen" ohne Blizzards Funktionen. Name ins Suchfeld (nur Text),
    -- Suche ueber die Spiel-API, kein SetDisplayMode, kein SelectBrowseResult, keine geleerte Liste.
    local modes = { Buy = {}, CommoditiesBuy = {}, ItemBuy = {}, Auctions = {}, ItemSell = {} }
    AuctionHouseFrameDisplayMode = modes
    local curMode = modes.Buy
    local setMode, selected = 0, 0
    AuctionHouseFrame.SetDisplayMode = function(_, m) setMode = setMode + 1; curMode = m end
    AuctionHouseFrame.GetDisplayMode = function() return curMode end
    AuctionHouseFrame.SelectBrowseResult = function() selected = selected + 1 end
    local boxText
    AuctionHouseFrame.SearchBar = { SearchBox = { SetText = function(_, t) boxText = t end } }
    local sentQ
    local savedSBQ = AHs.SendBrowseQuery
    AHs.SendBrowseQuery = function(q) sentQ = q end
    local errMsg
    UIErrorsFrame = { AddMessage = function(_, t) errMsg = t end }
    local wasCur = ns.AHTabs.current
    ns.AHTabs.current = nil
    local nm = Buy.SearchName(2770)
    check(type(nm) == "string" and Buy.ShowInAH({ key = 2770 }) == true and sentQ and sentQ.searchString == nm and boxText == nm
        and setMode == 0 and selected == 0 and errMsg == nil, "Im Markt zeigen: Suche über die Spiel-API, Name im Suchfeld, Blizzards Ansicht unberührt")
    curMode = modes.ItemSell
    sentQ = nil
    check(Buy.ShowInAH({ key = 2770 }) == true and sentQ and setMode == 0 and errMsg == ns.L.GO_AH_HINT, "nicht auf Markt: Hinweis statt Umschalten")
    ns.AHTabs.current = "chances"
    sentQ = nil
    check(Buy.ShowInAH({ key = 2770 }) == false and sentQ == nil, "Broker-Reiter offen: nichts tun (Go schliesst vorher die Flaeche)")
    ns.AHTabs.current = wasCur
    curMode = modes.Buy
    AuctionHouseFrame.SearchBar, UIErrorsFrame, AHs.SendBrowseQuery = nil, nil, savedSBQ
    Win.Select("chances")
    local Ch = ns.Chances
    check(Win.current == "chances" and Ch.list and Ch.checkButton and Ch.modeDrop and Ch.status and Rd.list == nil, "0.105: Radar im Reiter Chancen mit Peon.UI")

    -- Radar: weggefallen mit Grund, Pause bei Auswahl, vorhandene Ergebnisse entfernen nichts
    Rd.Halt()
    Rd.entries, Rd.gone, Rd.lastVisible = {}, {}, nil
    VENDOR[7777] = 10
    mod.db.dealMinVendor = 10
    market.items[7777] = { m = 3, md = 10, q = 20, n = 1, t = clock, lv = "3:20", nm = "Billigzeug", ql = 1 }
    Rd.entries[7777] = Rd.Evaluate(7777, { { price = 3, qty = 20, own = 0 } }, true, true)
    Rd.entries[7777].checked = now
    mod.db.chancesTab = "buyout"   -- ab 0.120 zeigt R.Refresh nur den offenen Unterreiter
    Rd.Refresh()
    -- vorhandene (evtl. alte) Ergebnisse ohne Schnaeppchen: Treffer bleibt
    Rd.Apply({ key = 7777, itemID = 7777 }, { { price = 12, qty = 20, own = 0 } }, true, true)
    check(Rd.entries[7777] and not Rd.gone[7777], "alte Ergebnisse des Spiels entfernen keinen Treffer")
    Rd.Apply({ key = 7777, itemID = 7777 }, { { price = 12, qty = 20, own = 0 } }, true)
    check(Rd.entries[7777] == nil and Rd.gone[7777] and Rd.gone[7777].goneWhy:find("günstigstes jetzt", 1, true), "Live: guenstige Angebote weg -> grau mit Grund")
    local ghostRow for i, it in ipairs(Ch.list.items) do if it.state == "gone" then ghostRow = i end end
    local gc = ghostRow and Ch.list.list.rows[ghostRow].cells
    check(gc and plain(gc[5].text) == "weg" and plain(gc[2].text) ~= "",
      "0.75/0.105/0.120: „weg“ steht unter Zustand, moeglicher Gewinn bleibt sichtbar (ohne Spalte Art)")
    now = now + 31
    Rd.Refresh()
    check(Rd.gone[7777] == nil and #Ch.list.items == 0, "nach 30 Sek. aus der Liste")
    Rd.Halt()
    -- 0.20.1: Spiel liefert erst leere Teil-Ergebnisse (laedt noch) -> weiter warten, nichts entfernen
    Rd.entries, Rd.gone, Rd.lastVisible = {}, {}, nil
    market.items[7779] = { m = 40, md = 200, q = 1, n = 1, t = clock, lv = "40:1", nm = "Altes Schwert", ql = 2 }
    VENDOR[7779] = 100
    Rd.entries[7779] = Rd.Evaluate(7779, { { price = 40, qty = 1, own = 0, ids = { 91 } } }, true, false)
    local savedLI3, savedHFI = LIVEITEM, AHs.HasFullItemSearchResults
    LIVEITEM = {}
    AHs.HasFullItemSearchResults = function() return false end
    Rd.pending = nil; Rd.Send(7779)
    fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 7779 })
    check(Rd.pending and (Rd.pending.loading or 0) >= 1 and Rd.entries[7779] and not Rd.entries[7779].emptySeen and not market.items[7779].gone,
        "leeres Teil-Ergebnis (Spiel laedt noch): weiter warten, nichts entfernt")
    LIVEITEM = { { buyoutAmount = 40, quantity = 1, auctionID = 91 } }
    AHs.HasFullItemSearchResults = function() return true end
    fire("ITEM_SEARCH_RESULTS_ADDED", { itemID = 7779 })
    check(Rd.pending == nil and Rd.entries[7779] and Rd.entries[7779].live, "weitere Ergebnisse (…_ADDED): Treffer bestaetigt")
    LIVEITEM, AHs.HasFullItemSearchResults = savedLI3, savedHFI
    -- 0.24 (Feedback #5): Gegenstand mit Zusatz - Suche mit dem Standard-Schluessel leer -> Browse-Suche findet den Schluessel des Spiels
    Rd.Halt()
    Rd.entries, Rd.gone, Rd.lastVisible, Rd.soon, Rd.keyTries = {}, {}, nil, nil, {}
    Rd.entries[7779] = Rd.Evaluate(7779, { { price = 40, qty = 1, own = 0, ids = { 91 } } }, true, false)
    local savedLI5, savedNI5 = LIVEITEM, AHs.GetNumItemSearchResults
    LIVEITEM = { { buyoutAmount = 40, quantity = 1, auctionID = 91 } }
    AHs.GetNumItemSearchResults = function(k) return (type(k) == "table" and k.itemSuffix == 1047) and #LIVEITEM or 0 end
    local browsed
    AHs.SendBrowseQuery = function(q) browsed = q end
    AHs.GetBrowseResults = function() return { { itemKey = { itemID = 1234, itemLevel = 5, itemSuffix = 0 }, minPrice = 1, totalQuantity = 5 },
        { itemKey = { itemID = 7779, itemLevel = 20, itemSuffix = 1047 }, minPrice = 40, totalQuantity = 1 } } end
    Rd.pending = nil; Rd.Send(7779)
    check((query.key.itemSuffix or 0) == 0, "erste Suche mit dem Standard-Schluessel")
    fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 7779 })
    check(Rd.entries[7779] and Rd.entries[7779].emptySeen and not browsed, "leer: erst nochmal pruefen")
    Rd.pending = nil; Rd.Send(7779)
    fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 7779 })
    check(Rd.entries[7779] and not Rd.gone[7779] and browsed and browsed.searchString == "Gegenstand7779" and Rd.pending and Rd.pending.browse,
        "zweimal leer: nicht weg, sondern Browse-Suche nach dem Grundnamen (vom Spiel)")
    fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    check(PeonBrokerDB.itemKeys[7779] == "20:1047" and Rd.pending == nil and Rd.soon and Rd.soon.key == 7779 and not Rd.entries[7779].emptySeen,
        "Schluessel des Spiels gefunden und gemerkt, gleich nochmal pruefen")
    check(PeonBrokerDB.keyLog == nil, "Schluessel-Protokoll ab 0.28 nur mit Debug")
    Rd.Send(7779)
    check(query.key.itemSuffix == 1047 and query.key.itemLevel == 20, "Suche jetzt mit dem gemerkten Schluessel")
    fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 7779, itemLevel = 20, itemSuffix = 1047 })
    check(Rd.entries[7779] and Rd.entries[7779].live and not Rd.gone[7779], "Treffer bestaetigt statt 'weg'")
    -- wirklich weg: auch die Browse-Suche findet nichts -> grau mit Grund
    LIVEITEM = {}
    Rd.keyTries = {}
    AHs.GetBrowseResults = function() return {} end
    for _ = 1, 2 do Rd.pending = nil; Rd.Send(7779); fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 7779, itemLevel = 20, itemSuffix = 1047 }) end
    check(Rd.pending and Rd.pending.browse and PeonBrokerDB.itemKeys[7779] == nil, "gemerkter Schluessel liefert nichts: vergessen, Browse-Suche")
    timers[#timers]()
    check(Rd.entries[7779] == nil and Rd.gone[7779] and Rd.gone[7779].goneWhy == "Keine Angebote mehr." and Rd.pending == nil, "auch ueber die Suche nichts: weg")
    -- N6: die graue Zeile des Gegenstands im Fokus bleibt, solange er dort steht
    Rd.Refresh()
    Rd.focus = { key = 7779, at = now + 100 }
    Rd.gone[7779].goneUntil = 0
    Rd.Refresh()
    check(Rd.gone[7779] ~= nil, "N6: graue Zeile bleibt, solange der Gegenstand im Fokus ist")
    Rd.focus = nil
    Rd.Refresh()
    check(Rd.gone[7779] == nil, "N6: ohne Fokus verschwindet sie")
    LIVEITEM, AHs.GetNumItemSearchResults, AHs.SendBrowseQuery, AHs.GetBrowseResults = savedLI5, savedNI5, nil, nil
    PeonBrokerDB.itemKeys = nil
    Rd.Halt()
    Rd.entries, Rd.gone, Rd.lastVisible, Rd.soon = {}, {}, nil, nil
    market.items[7777], market.items[7779] = nil, nil
    AuctionHouseFrame.SetDisplayMode, AuctionHouseFrame.GetDisplayMode, AHs.GetItemKeyInfo, AuctionHouseFrameDisplayMode = nil, nil, nil, nil
end)()

-- ab 0.77: Angaben links im Fokus als Text (Art, Ziel und Kaufen bis aus den Feldern, darunter die Zeilen)
local function FocusText(F)
  local parts = { "Art=" .. plain(F.kindValue.text or ""), "Ziel=" .. tostring(F.targetInput:GetAmount()), "Kaufen bis=" .. tostring(F.limitInput:GetAmount()) }
  for _, r in ipairs(F.rows) do if (r.label.text or "") ~= "" then parts[#parts + 1] = r.label.text .. "=" .. plain(r.value.text) end end
  return table.concat(parts, "|")
end

-- ===== Neuaufbau N6 (0.64): Radar schlank, Seite Fokus =====
;(function()
    local F, T, Ch = ns.Focus, ns.AHTabs, ns.Chances
    -- die letzten Timer ausfuehren (der Takt des Radars ist nicht immer der allerletzte)
    local function tick() local n = #timers; for i = math.max(1, n - 4), n do timers[i]() end end
    local keepMin, keepMoney = mod.db.dealMinVendor, GetMoney
    GetMoney = function() return 1000000 end
    mod.db.dealMinVendor = 10
    check(ns.Look == nil and Rd.Hide == nil and Rd.Prequote == nil and Rd.MuteOn == nil and Rd.SetKind == nil and Rd.SetOrder == nil,
        "N6: Ausblenden, Schnellkauf, Nur Warnton, Art- und Reihenfolge-Wahl entfallen")
    -- Chancen aus der Datenbank: nur die Art Haendler, ohne Live-Pruefung
    Rd.Halt()
    Rd.entries, Rd.gone, Rd.lastVisible, Rd.loaded = {}, {}, nil, nil
    VENDOR[7801], VENDOR[7802] = 10, 0
    market.items[7801] = { m = 3, md = 10, q = 20, n = 1, t = clock, lv = "3:20;12:50", nm = "Billigzeug", ql = 1 }
    market.items[7802] = { m = 30, md = 300, q = 5, n = 1, t = clock, lv = "30:5;300:50", nm = "Marktding", ql = 1,
        d = ("%d:30:300:5:12"):format(D.Day()) }
    mod.acc.commodity[7801], mod.acc.commodity[7802] = true, true
    local sent0 = Rd.stats.sent
    fire("AUCTION_HOUSE_CLOSED")
    Win.Open("radar")
    check(Win.current == "chances", "0.105: alter Reiter Radar oeffnet Chancen")
    check(Rd.entries[7801] and Rd.entries[7801].kind == "vendor" and Rd.entries[7802] == nil, "N6: nur Chancen der Art Haendler")
    local rows = Ch.list.items
    check(#rows == 1 and rows[1].key == 7801 and rows[1].radar and rows[1].risk == "low" and rows[1].d.checked == nil, "N6: Liste aus der Datenbank, nichts live geprueft")
    local cols = {}
    for _, c in ipairs(Ch.list.o.columns) do cols[#cols + 1] = c.title end
    check(table.concat(cols, ",") == "Gegenstand,Gewinn,Kaufen bis,Risiko,Zustand", "0.105/0.120: Spalten der Liste ohne Art: " .. table.concat(cols, ","))
    local cells = Ch.list.list.rows[1].cells
    check(cells[1].text == "Billigzeug" and plain(cells[4].text) == "gering" and plain(cells[2].text) ~= ""
        and plain(cells[5].text):find("Scan vor", 1, true), "N6/0.105: Zeile mit Gewinn, Risiko und Alter des Scans: " .. plain(cells[5].text))
    check(Rd.stats.sent == sent0 and not Rd.loop and Ch.checkButton.disabled and Ch.status.text:find(ns.L.ST_NOT_LIVE, 1, true),
        "N6: unterwegs keine Abfragen, Scan gesperrt")
    rows[1].d.seenT = clock - 4000
    check(Rd.Risk(rows[1].d) == "mid", "N6: alter, nie live gepruefter Stand: mittleres Risiko")
    rows[1].d.seenT = clock
    -- unterwegs (ab 0.70): Fokus nur am Auktionshaus. Klick merkt den Gegenstand, die Seite bleibt
    local n0 = #out
    Ch.list.list.rows[1].scripts.OnClick(Ch.list.list.rows[1], "LeftButton")
    check(Win.current == "chances" and F.key == 7801 and mod.acc.focusKey == 7801 and Rd.focus == nil and #out > n0 and out[#out]:find("Auktionshaus", 1, true),
        "0.70: unterwegs merkt der Klick im Radar den Gegenstand fuer den Fokus, die Seite bleibt")
    local focusTab
    for _, b in ipairs(Win.tabs) do if b.key == "focus" then focusTab = b end end
    check(focusTab and focusTab.disabled and Win.AH_ONLY.focus, "0.70: Reiter Fokus unterwegs grau wie Verkaufen")
    Win.Open("focus")
    check(Win.current ~= "focus", "0.70: Fokus laesst sich unterwegs nicht oeffnen")
    Win.frame:Hide()

    -- am Auktionator
    local ah = CreateFrame("Frame", "AuctionHouseFrame")
    ah.BuyTab, ah.SellTab, ah.AuctionsTab = CreateFrame("Button"), CreateFrame("Button"), CreateFrame("Button")
    ah.Tabs = { ah.BuyTab, ah.SellTab, ah.AuctionsTab }
    ah.SetDisplayMode = function() end
    T.built, T.tabs, T.page, T.current, T.status, T.back = nil, {}, nil, nil, nil, nil
    mod.acc.ahPlain = false
    fire("AUCTION_HOUSE_SHOW")
    check(T.tabs.radar == nil and T.tabs.chances, "0.105: kein Reiter Radar mehr im Auktionshaus")
    T.tabs.chances.scripts.OnClick(T.tabs.chances)
    check(T.current == "chances" and Rd.Shown() and not Ch.checkButton.disabled and Rd.stats.sent == sent0, "N6: Chancen am Auktionator, noch keine Abfrage")
    -- ab 0.71: Erneuern der gezeigten Moeglichkeiten laeuft von selbst, solange der Reiter offen ist
    check(Rd.loop and Rd.Renewing() and Ch.checkButton.text == ns.L.CH_CHECK_ALL, "0.71/0.105: Chancen offen: Erneuern laeuft ohne Knopf, Auswahl Manager-Chancen")
    LIVE[7801] = { { unitPrice = 3, quantity = 15 }, { unitPrice = 12, quantity = 50 } }
    Rd.pending, Rd.lastSend = nil, -100
    now = now + 1; tick()
    check(Rd.pending and Rd.pending.key == 7801, "0.71: Erneuern fragt die gezeigte Moeglichkeit ab")
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 7801)
    check(Rd.entries[7801].live and Rd.entries[7801].qty == 15 and Ch.list.items[1].state == "ok", "N6: Chance live bestaetigt, Menge neu")
    Rd.lastSend = -100
    now = now + 1; tick()
    check(Rd.pending == nil and Rd.renewEvery == 60, "0.71: gerade geprueft: erst nach 60 Sek. wieder")
    check(Rd.RenewInterval(200) == 120 and Rd.RenewInterval(100) > 60, "0.71: viele Moeglichkeiten: Abstand waechst, hoechstens 2 Min.")
    -- Radar-Scan sucht neue Moeglichkeiten, hier unter allen Massenwaren (ab 0.105 Auswahl im Reiter Chancen)
    Ch.SetMode("mass")
    check(Ch.checkButton.text == ns.L.RADAR_START, "0.105: Auswahl Massenware: Knopf Radar-Scan")
    Ch.checkButton.scripts.OnClick(Ch.checkButton)
    check(Rd.running and Rd.loop and Ch.checkButton.text == ns.L.RADAR_STOP and mod.db.radarScanMode == "mass" and Rd.forceMode == nil, "N6: Radar-Scan gestartet")
    Rd.lastSend = -100
    now = now + 1; tick()
    check(Rd.pending and Rd.search and Rd.search.mode == "mass" and Rd.search.done == 1 and #Rd.search.keys >= 2, "0.71: Radar-Scan fragt eine Massenware ab")
    local searched = Rd.pending.key
    check(mod.acc.commodity[searched] or D.IsCommodity(searched), "0.71: nur Massenware: " .. tostring(searched))
    Rd.pending = nil
    check(plain(Ch.status.text):find("Massenware", 1, true), "0.71: Status nennt die Auswahl: " .. plain(Ch.status.text))
    -- Anteil: faellig sind Erneuern und Suche, die Suche bekommt mindestens 20 %
    Rd.mix = { renew = 9, search = 1 }
    Rd.entries[7801].checked = nil
    local k1, kind1 = Rd.NextKey()
    Rd.mix = { renew = 1, search = 9 }
    local k2, kind2 = Rd.NextKey()
    check(kind1 == "search" and kind2 == "renew" and k2 == 7801, "0.71: Suche bekommt ihren Anteil, sonst zuerst Erneuern")
    Rd.entries[7801].checked = GetTime()
    Ch.checkButton.scripts.OnClick(Ch.checkButton)
    check(not Rd.running and Rd.Renewing(), "N6/0.71: Radar-Scan gestoppt, Erneuern laeuft weiter")
    mod.db.radarScanMode = "watch"
    Ch.SetMode("mgr")
    -- Klick: Fokus fragt nur diesen Gegenstand ab
    Ch.list.list.rows[1].scripts.OnClick(Ch.list.list.rows[1], "LeftButton")
    check(T.current == "focus" and F.Shown() and F.key == 7801 and Rd.focus and Rd.focus.key == 7801 and Rd.loop and not Rd.running and not T.back.shown
        and F.origin == "chances" and F.backButton.text == "Zurück zu Chancen",
        "N6/0.82/0.105: Fokus am Auktionator: genau dieser Gegenstand wird abgefragt, Zurueck unten fuehrt zu Chancen")
    Rd.pending, Rd.lastSend = nil, -100
    now = now + 1; tick()
    check(Rd.pending and Rd.pending.key == 7801 and Rd.focus.at > now, "N6: Abfrage fuer den Fokus, naechste nach R.FOCUS_EVERY")
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 7801)
    check(not F.buyButton.disabled and F.buyButton.text == "Kaufen 15", "N6: Kaufen bereit")
    check(F.header.name.text == "Billigzeug" and plain(F.verdict.text) == "KAUFEN" and F.stand.text:find("live", 1, true), "N6: Fokus mit Urteil, Markt live")
    check(FocusText(F) == "Art=Händler|Ziel=10|Kaufen bis=3|Üblich=unbekannt" and plain(F.buyInfo.text) == "Menge: 15    Kosten: 45c    Gewinn: +1s 5c",
        "0.77: Angaben zur Chance: " .. FocusText(F) .. " / " .. plain(F.buyInfo.text))
    check(#F.tiers.items == 2 and F.tiers.items[1].inBuy and not F.tiers.items[2].inBuy, "N6: Preisstufen aus der Live-Antwort, markiert was der Kauf nimmt")
    -- Kaufen: Preis vom Spiel, dann bestaetigen
    local started, confirmed
    local keepS, keepC = AHs.StartCommoditiesPurchase, AHs.ConfirmCommoditiesPurchase
    AHs.StartCommoditiesPurchase = function(id, qty) started = { id, qty } end
    AHs.ConfirmCommoditiesPurchase = function(id, qty) confirmed = { id, qty } end
    F.buyButton.scripts.OnClick(F.buyButton)
    check(started and started[1] == 7801 and started[2] == 15 and Rd.job and Rd.job.stage == "quote" and F.buyButton.disabled, "N6: erster Klick holt den Preis")
    fire("COMMODITY_PRICE_UPDATED", 3, 45)
    -- ab 0.91 (Fehlerbericht 24): im Fokus bestaetigt Broker selbst, sobald der Preis passt (ein Klick)
    check(confirmed and confirmed[2] == 15 and Rd.job.stage == "wait", "0.91: Preis passt: ohne zweiten Klick bestaetigt")
    fire("COMMODITY_PURCHASE_SUCCEEDED")
    check(Rd.job == nil and Rd.entries[7801] == nil and Rd.gone[7801] and plain(F.verdict.text) == "VORBEI" and F.buyButton.disabled,
        "N6: gekauft: Chance vorbei, Fokus zeigt es")
    -- Tasten: naechste Chance in den Fokus, kaufen
    market.items[7803] = { m = 2, md = 10, q = 5, n = 1, t = clock, lv = "2:5", nm = "Kleinkram", ql = 1 }
    VENDOR[7803] = 9
    mod.acc.commodity[7803] = true
    Rd.loaded = nil
    Rd.LoadIfStale()
    PeonBroker_RadarNext()
    check(F.key == 7803 and T.current == "focus", "N6: Taste naechste Chance: in den Fokus")
    started = nil
    PeonBroker_RadarBuy()
    check(started and started[1] == 7803, "N6: Taste kaufen: Chance im Fokus")
    -- ab 0.91: Gesamtpreis hoeher als erwartet: kein Kauf ohne zweiten Klick
    confirmed = nil
    fire("COMMODITY_PRICE_UPDATED", Rd.job.limit, (Rd.job.expect or 0) * 2 + 100)
    check(Rd.job and Rd.job.stage == "confirm" and Rd.job.warn and confirmed == nil, "0.91: Preiswarnung: wartet auf den zweiten Klick")
    Rd.job = nil
    Rd.buyUntil = nil
    -- ein Gegenstand ohne Chance im Fokus (ohne fruehere Live-Antwort aus anderen Tests)
    ns.Buy.live[2770] = nil
    ns.Go.Focus({ key = 2770, name = "Kupfererz" })
    check(F.key == 2770 and plain(F.verdict.text) == "WARTE" and F.buyButton.disabled and F.header.name.text == "Kupfererz" and Rd.focus.key == 2770
        and #F.tiers.items == 0, "N6/0.70: Gegenstand ohne Chance im Fokus: wird abgefragt, ohne Live-Antwort keine Preisstufen")
    check(plain(F.buyInfo.text) == "Menge: -    Kosten: -    Gewinn: -", "0.78: Zeile Menge, Kosten, Gewinn auch ohne Werte, mit Strichen")
    -- ab 0.70: ohne Chance kaufen, Ziel = zweite Preisstufe, per Klick auf eine Stufe oder von Hand
    mod.acc.commodity[2770] = true
    LIVE[2770] = { { unitPrice = 100, quantity = 10 }, { unitPrice = 150, quantity = 5 }, { unitPrice = 200, quantity = 50 } }
    Rd.pending, Rd.lastSend, Rd.focus.at = nil, -100, 0
    now = now + 1; tick()
    check(Rd.pending and Rd.pending.key == 2770 and Rd.pending.focus, "0.70: Abfrage fuer den Fokus")
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
    check(plain(F.verdict.text) == "EIGENES ZIEL" and F.buyButton.text == "Kaufen 10" and not F.buyButton.disabled and #F.tiers.items == 3,
        "0.70: ohne Chance: alles unter der zweiten Stufe kaufen: " .. plain(F.verdict.text) .. " / " .. tostring(F.buyButton.text))
    F.tiers.o.onClick(F.tiers.items[3], "RightButton")   -- ab 0.83 Rechtsklick fuer das Ziel
    check(F.ManualTarget(2770) == 200 and F.buyButton.text == "Kaufen 15" and not F.autoButton.disabled
        and FocusText(F):find("Art=Eigenes Ziel|Ziel=200|Kaufen bis=150|Üblich=", 1, true),
        "0.70: Klick auf eine Preisstufe macht sie zum Ziel: " .. FocusText(F))
    -- ab 0.99: feste Menge (Feld und Regler), bleibt bei mehr Ware im Markt
    check(F.qtySlider.shown and F.qtyInput.text == "15" and plain(F.qtyHint.text) == "alle" and F.qtySlider.peonMax == 15 and F.qtySlider.peonVal == 15,
        "0.99: Zeile Menge zeigt alle: " .. tostring(F.qtyInput.text) .. " / " .. plain(F.qtyHint.text or ""))
    F.qtyInput:SetText("12"); F.qtyInput.scripts.OnTextChanged(F.qtyInput, true)
    check(F.ManualQty(2770) == 12 and F.buyButton.text == "Kaufen 12" and plain(F.buyInfo.text) == "Menge: 12    Kosten: 13s    Gewinn: +9s 80c"
        and plain(F.qtyHint.text) == "von 15" and F.qtySlider.peonVal == 12 and #F.tiers.items == 3 and F.tiers.items[2].inBuy and not F.tiers.items[3].inBuy,
        "0.99: Menge 12 getippt: " .. tostring(F.buyButton.text) .. " / " .. plain(F.buyInfo.text))
    local d12 = F.Plan()
    check(d12.best.qty == 12 and d12.maxQty == 15 and d12.capped and (not Rd.entries[2770] or Rd.entries[2770] ~= d12), "0.99: Plan begrenzt, Kopie")
    F.OnQtySlider(5)
    check(F.ManualQty(2770) == 5 and F.buyButton.text == "Kaufen 5" and F.qtyInput.text == "5", "0.99: Regler auf 5")
    F.qtySync = true; F.OnQtySlider(9); F.qtySync = false
    check(F.ManualQty(2770) == 5, "0.99: Nachziehen durch die Anzeige zaehlt nicht als Wahl")
    F.OnQtySlider(15)
    check(F.ManualQty(2770) == nil and F.buyButton.text == "Kaufen 15" and plain(F.qtyHint.text) == "alle", "0.99: Regler ganz rechts: alle")
    F.SetQty(20)
    check(F.ManualQty(2770) == 20 and F.buyButton.text == "Kaufen 15" and F.qtyInput.text == "20" and F.qtySlider.peonVal == 15,
        "0.99: Menge ueber dem Angebot: alle kaufen, Zahl bleibt")
    F.SetQty(nil)
    F.SetTargetTyped(105)
    check(F.ManualTarget(2770) == 105 and F.buyButton.text == "Kaufen 10" and plain(F.verdict.text) == "KEIN GEWINN" and not F.buyButton.disabled,
        "0.70: Ziel von Hand, kein Gewinn, kaufen geht trotzdem")
    local keepMoney2 = GetMoney
    GetMoney = function() return 500 end
    F.Update()
    check(F.buyButton.disabled and plain(F.buyInfo.text):find("Menge: 10    Kosten: 10s", 1, true), "0.78: Knopf grau (zu wenig Gold), die Zeile bleibt: " .. plain(F.buyInfo.text))
    GetMoney = keepMoney2
    F.Update()
    F.autoButton.scripts.OnClick(F.autoButton)
    check(F.ManualTarget(2770) == nil and F.buyButton.text == "Kaufen 10" and F.autoButton.disabled, "0.70: Auto nimmt das eigene Ziel zurueck")
    -- ab 0.76: Ziel 2s (Klick), Kaufen bis 1s (Rechtsklick): nur die unterste Stufe, Kosten und Gewinn ueber dem Knopf
    F.tiers.o.onClick(F.tiers.items[3], "RightButton")   -- ab 0.83 getauscht: Rechtsklick Ziel, Linksklick Kaufen bis
    F.tiers.o.onClick(F.tiers.items[1], "LeftButton")
    check(plain(F.targetHint.text) == "Rechtsklick" and plain(F.limitHint.text) == "Linksklick", "0.83: Hinweise neben den Feldern getauscht")
    check(F.ManualTarget(2770) == 200 and F.ManualLimit(2770) == 100 and F.buyButton.text == "Kaufen 10" and F.limitInput:GetAmount() == 100
      and plain(F.buyInfo.text) == "Menge: 10    Kosten: 10s    Gewinn: +9s",
      "0.76: Rechtsklick setzt Kaufen bis, Ziel bleibt, Kosten und Gewinn ueber dem Knopf: " .. plain(F.buyInfo.text))
    check(F.tiers.items[1].inBuy and not F.tiers.items[2].inBuy and F.tiers.items[3].isTarget
      and F.tiers.o.rowBg(F.tiers.items[1]) == 0.25 and F.tiers.o.rowBg(F.tiers.items[2]) == nil and F.tiers.o.rowBg(F.tiers.items[3]) == 1,
      "0.77: gekaufte Stufen blau, Ziel gelb, dazwischen nichts")
    F.SetLimitTyped(150)
    check(F.buyButton.text == "Kaufen 15", "0.76: Kaufen bis von Hand")
    -- 0.80.1: eigener Wert bleibt im Feld stehen, auch zwischen zwei Stufen und unter dem guenstigsten Angebot
    F.SetLimitTyped(120)
    check(F.limitInput:GetAmount() == 120 and F.buyButton.text == "Kaufen 10", "0.80.1: Kaufen bis 1s 20c bleibt im Feld (vorher sprang es auf 1s)")
    F.SetLimitTyped(50)
    check(F.limitInput:GetAmount() == 50 and F.ManualLimit(2770) == 50 and F.buyButton.disabled, "0.80.1: Kaufen bis unter dem guenstigsten Angebot bleibt im Feld (vorher leer)")
    F.SetLimitTyped(150)
    F.autoButton.scripts.OnClick(F.autoButton)
    check(F.ManualTarget(2770) == nil and F.ManualLimit(2770) == nil and F.limitInput:GetAmount() == 100 and F.targetInput:GetAmount() == 150
      and F.buyButton.text == "Kaufen 10", "0.76/0.77: Auto nimmt Ziel und Kaufen bis zurueck, die Felder zeigen wieder die geltenden Werte")
    LIVE[2770] = nil
    -- Reiter verlassen: Abfragen aus
    T.tabs.buy.scripts.OnClick(T.tabs.buy)
    check(Rd.focus == nil and not Rd.loop, "N6: Fokus verlassen: keine Abfragen mehr")
    AHs.StartCommoditiesPurchase, AHs.ConfirmCommoditiesPurchase = keepS, keepC
    T.Close()
    LIVE[7801] = nil
    market.items[7801], market.items[7802], market.items[7803] = nil, nil, nil
    VENDOR[7801], VENDOR[7802], VENDOR[7803] = nil, nil, nil
    Rd.entries, Rd.gone, Rd.lastVisible, Rd.loaded = {}, {}, nil, nil
    mod.db.dealMinVendor, GetMoney = keepMin, keepMoney
    AuctionHouseFrame = {}
    T.built, T.tabs, T.page, T.current, T.status, T.back = nil, {}, nil, nil, nil, nil
    ns.Go.Clear()
end)()

-- ===== Stufe 2, H1 (0.65): Radar-Art Aufkauf =====
;(function()
    local BO, F = ns.Buyout, ns.Focus
    BO.CTX_TIME = 0   -- ab 0.69: ohne Merken, die Tests aendern den Absatz zwischendurch (eigener Test unten)
    -- ab 0.71: Grenze fuer Massenware (eigener Test unten), hier aus
    mod.db.buyoutMinQty, mod.db.buyoutMinLevels, mod.db.buyoutMinSales = 0, 2, 0
    local keepStats, keepBand, keepMoney, keepMin = ns.Sales.Stats, D.Band, GetMoney, mod.db.dealMinMarket
    local sales = { perHour = 50, level = 3 }
    local band = { trend = "calm", low = 900, high = 1600 }
    ns.Sales.Stats = function() return sales end
    D.Band = function() return band end
    GetMoney = function() return 1000000 end
    mod.db.dealMinMarket, mod.db.buyoutHours, mod.db.radarReserve = 50, 2, 0
    mod.acc.commodity[7901] = true
    local rows = D.ParseLevels("1000:50;1100:30;1500:100")
    local e = { m = 1000, md = 1500, q = 180, n = 3, t = clock, lv = "1000:50;1100:30;1500:100", nm = "Robuster Stein", ql = 1 }
    local d, why = BO.Find(e, rows, 7901, 1000000)
    check(d and d.kind == "buyout" and d.qty == 80 and d.cost == 83000 and d.limit == 1100 and d.ref == 1500 and d.gain == 31000,
        "H1: beste Stelle: 80 Stueck bis 11s, Ziel 15s (naechste Stufe), Gewinn 80 x 15s x 0,95 - 8g 30s = 3g 10s")
    check(math.abs(d.hours - 1.6) < 0.001 and d.nextQty == 100, "H1: Verkaufsdauer = Menge / Absatz je Std. (1,6 Std.)")
    local lvl, reasons = BO.Risk(d, 0, 1000000)
    check(lvl == "mid" and #reasons == 1 and reasons[1] == ns.L.RISK_W_SLOW, "H1: Risiko gelb: Verkaufsdauer nahe an der Grenze")
    check(select(1, BO.Risk(d, 8000, 100000)) == "high", "H1: Risiko rot: alter Stand und viel vom Gold im Einsatz")
    d, why = BO.Find(e, rows, 7901, 50000)
    check(d == nil and why == "gold", "H1: nicht aufkaufbar mit 5g")
    sales.perHour = 30
    d, why = BO.Find(e, rows, 7901, 1000000)
    check(d == nil and why == "slow", "H1: zu langsam: 80 Stueck bei 30 je Std. dauern ueber 2 Std.")
    mod.db.buyoutHours = 3
    check(BO.Find(e, rows, 7901, 1000000) ~= nil, "H1: hoechste Verkaufsdauer einstellbar (3 Std.)")
    mod.db.buyoutHours, sales.perHour = 2, 50
    -- ab 0.71: nur echte Massenware (Heckenschuetzen-Zielfernrohr mit 16 Stueck war ein Aufkauf)
    mod.db.buyoutMinQty, mod.db.buyoutMinLevels, mod.db.buyoutMinSales = 200, 5, 50
    local few = D.ParseLevels("320:1;399:8;600:2;898:5")
    local dm, whym = BO.Find({ q = 16 }, few, 7901, 1000000)
    check(dm == nil and whym == "mass", "0.71: 16 Stueck in 4 Stufen: kein Aufkauf (Massenware ab 200 Stueck, 5 Stufen)")
    local many = D.ParseLevels("1000:50;1100:30;1500:100;1600:100;1700:100")
    check(BO.Find({ q = 380 }, many, 7901, 1000000) ~= nil, "0.71: 380 Stueck in 5 Stufen, 1200 Absatz am Tag: Aufkauf")
    sales.perHour = 1
    check(select(2, BO.Find({ q = 380 }, many, 7901, 1000000)) == "mass", "0.71: zu wenig Absatz je Tag (24 statt 50)")
    sales.perHour = 50
    check(BO.Candidate({ lv = "1:5;2:5", q = 10 }, 7901) == false and BO.Candidate({ lv = "1:50;2:50;3:50;4:50;5:50", q = 250 }, 7901) == true,
        "0.71: Vorauswahl aus dem Scan nach Menge und Stufen")
    mod.db.buyoutMinQty, mod.db.buyoutMinLevels, mod.db.buyoutMinSales = 0, 2, 0
    band.trend = "down"
    d, why = BO.Find(e, rows, 7901, 1000000)
    check(d == nil and why == "trend", "H1: Trend nach unten schliesst aus")
    band.trend = "calm"
    ns.Sales.Stats = function() return nil end
    d, why = BO.Find(e, rows, 7901, 1000000)
    check(d == nil and why == "sales", "H1: ohne Absatz keine Aussage zur Verkaufsdauer")
    ns.Sales.Stats = function() return sales end
    mod.db.dealMinMarket = 400
    check(BO.Find(e, rows, 7901, 1000000) == nil, "H1: Mindestgewinn einstellbar (4g)")
    mod.db.dealMinMarket = 50
    mod.acc.commodity[7901] = false
    check(select(2, BO.Find(e, rows, 7901, 1000000)) == "item", "H1: nur Massenware")
    mod.acc.commodity[7901] = true
    -- im Radar
    Rd.Halt()
    Rd.entries, Rd.gone, Rd.lastVisible, Rd.loaded = {}, {}, nil, nil
    market.items[7901] = e
    Win.Open("chances")
    local Chl = ns.Chances.list
    local d1 = Rd.entries[7901]
    check(d1 and d1.kind == "buyout" and d1.gain == 31000, "H1: Aufkauf aus dem Komplettscan im Radar")
    local r1
    for i, r in ipairs(Chl.items) do if r.key == 7901 then r1 = i end end
    local cells = Chl.list.rows[r1].cells
    check(Chl.items[r1].kindText == "Aufkauf" and plain(cells[4].text) == "mittel", "H1: Zeile mit Art Aufkauf und Risiko (ab 0.120 Art nur im Tooltip)")
    -- Sortierung: rot nach unten (ab 0.105 ueber den Rang der Zeile)
    local sortFn = Chl.o.columns[2].sort
    check(sortFn({ gain = 100, rank = 0.5 }) < sortFn({ gain = 1, rank = 0 }) and sortFn({ gain = 1e6, rank = 3 }) < sortFn({ gain = 1, rank = 0.5 }),
        "H1: Gewinn absteigend, rotes Risiko unten, Weggefallenes ganz unten")
    -- weniger Gold: Chance gilt nicht mehr
    GetMoney = function() return 50000 end
    Rd.Refresh()
    local still = false
    for _, r in ipairs(Chl.items) do if r.key == 7901 and r.state ~= "gone" then still = true end end
    check(not still, "H1: mit weniger Gold faellt der Aufkauf weg")
    GetMoney = function() return 1000000 end
    -- im Fokus
    ns.Go.Focus({ key = 7901 })
    local all = FocusText(F)
    check(all:find("Art=Aufkauf|Ziel=1500|Kaufen bis=1100|Üblich=9s bis 16s|Verkauft in=etwa 1,6 Std.|Risiko=mittel", 1, true)
        and plain(F.buyInfo.text):find("Menge: 80", 1, true), "H1/0.77: Angaben im Fokus: " .. all .. " / " .. plain(F.buyInfo.text))
    local riskRow
    for _, r in ipairs(F.rows) do if r.label.text == "Risiko" then riskRow = r end end
    check(riskRow and riskRow.tip and riskRow.tip[1] == ns.L.RISK_W_SLOW, "H1: Gruende fuer das Risiko im Tooltip der Zeile")
    check(plain(F.verdict.text) == "KAUFEN" and F.buyButton.text == "Kaufen 80", "H1: Urteil und Kaufknopf im Fokus")
    Win.frame:Hide()
    market.items[7901] = nil
    Rd.entries, Rd.gone, Rd.lastVisible, Rd.loaded = {}, {}, nil, nil
    ns.Sales.Stats, D.Band, GetMoney, mod.db.dealMinMarket = keepStats, keepBand, keepMoney, keepMin
    ns.Go.Clear()
end)()

-- ===== Stufe 2, H2 (0.66): Fokus mit Messung =====
;(function()
    local M, F = ns.Measure, ns.Focus
    local function rowsOf(list, partial)
        local byP, rows = {}, { offers = {}, commodity = true, partial = partial }
        for _, o in ipairs(list) do
            rows.offers[#rows.offers + 1] = { id = o[1], q = o[2], p = o[3], secs = o[4] }
            byP[o[3]] = (byP[o[3]] or 0) + o[2]
        end
        for p, q in pairs(byP) do rows[#rows + 1] = { price = p, qty = q, own = 0 } end
        table.sort(rows, function(a, b) return a.price < b.price end)
        return rows
    end
    Rd.entries[7951] = { key = 7951, kind = "buyout", ref = 150, qty = 30, rows = {} }
    M.Start(7951)
    M.Add(7951, rowsOf({ { 1, 10, 100 }, { 2, 20, 120 }, { 3, 50, 150 } }), 0)
    check(M.cur.target == 150 and M.Values().under == 30 and select(1, M.Verdict(M.Values())) == "first", "H2: erste Abfrage: Ziel aus der Chance, 30 Stueck unter Ziel, noch kein Urteil")
    M.Add(7951, rowsOf({ { 1, 5, 100 }, { 2, 20, 120 }, { 3, 50, 150 } }), 15)
    M.Add(7951, rowsOf({ { 2, 20, 120 }, { 3, 50, 150 } }), 30)
    local v = M.Values()
    check(v.sold == 10 and math.abs(v.out - 20) < 0.01 and v.inUnder == 0 and v.underTrend == "shrink" and v.minTrend == "rise",
        "H2: 10 Stueck in 30 Sek. gekauft: Abfluss 20 je Min., Menge unter Ziel schrumpft, Preis steigt")
    local code, why, early = M.Verdict(v)
    check(code == "buy" and early and why == ns.L.MEASURE_W_BUY, "H2: Urteil Kaufen (vorlaeufig vor 2 Min.)")
    -- abgebrochen: guenstigeres Angebot bleibt stehen
    M.Add(7951, rowsOf({ { 2, 20, 120 }, { 4, 8, 140 } }), 45)
    local last = M.cur.pairs[#M.cur.pairs]
    check(last.cancelled == 50 and last.sold == 0 and last.newUnder == 8,
        "H2: Angebot weg, guenstigeres blieb: abgebrochen; neues Angebot unter Ziel zaehlt als Zufluss")
    -- abgelaufen zaehlt nicht
    local A = { t = 0, offers = { [9] = { q = 5, p = 100, secs = 3 }, [8] = { q = 5, p = 90 } }, maxP = 100 }
    local B = { t = 5, offers = { [8] = { q = 5, p = 90 } }, maxP = 90 }
    local pr = M.Compare(A, B, 150)
    check(pr.sold == 0 and pr.cancelled == 0, "H2: abgelaufenes Angebot zaehlt weder als verkauft noch als abgebrochen")
    -- Finger weg: Menge unter Ziel waechst
    M.Start(7951)
    M.Add(7951, rowsOf({ { 1, 10, 100 }, { 3, 50, 150 } }), 0)
    M.Add(7951, rowsOf({ { 1, 10, 100 }, { 5, 40, 110 }, { 3, 50, 150 } }), 20)
    M.Add(7951, rowsOf({ { 1, 10, 100 }, { 5, 40, 110 }, { 3, 50, 150 } }), 40)
    v = M.Values()
    check(v.underTrend == "grow" and select(1, M.Verdict(v)) == "away", "H2: Menge unter Ziel waechst: Finger weg")
    -- Finger weg: Preis faellt
    M.Start(7951)
    M.Add(7951, rowsOf({ { 1, 10, 100 }, { 3, 50, 150 } }), 0)
    M.Add(7951, rowsOf({ { 6, 10, 90 }, { 3, 50, 150 } }), 40)
    check(M.Values().minTrend == "fall" and select(1, M.Verdict(M.Values())) == "away", "H2: guenstigster Preis faellt: Finger weg")
    -- Abwarten: keine Bewegung
    M.Start(7951)
    M.Add(7951, rowsOf({ { 1, 10, 100 }, { 3, 50, 150 } }), 0)
    M.Add(7951, rowsOf({ { 1, 10, 100 }, { 3, 50, 150 } }), 130)
    local c2, w2, e2 = M.Verdict(M.Values())
    check(c2 == "wait" and w2 == ns.L.MEASURE_W_QUIET and not e2, "H2: keine Bewegung: Abwarten, nach 2 Min. ohne vorlaeufig")
    check(M.SellHours(30) == nil, "H2: ohne Abfluss keine gemessene Verkaufsdauer")
    -- ohne Chance: Ziel = zweite Stufe beim Beginn
    Rd.entries[7951] = nil
    M.Start(7951)
    M.Add(7951, rowsOf({ { 1, 10, 100 }, { 3, 50, 150 } }), 0)
    check(M.cur.target == 150 and M.cur.ownTarget, "H2: ohne Chance gilt die zweite Preisstufe als Ziel")
    -- gemerkt fuer unterwegs
    M.Stop()
    check(M.cur == nil and M.Saved(7951) and M.Saved(7951).under == 10 and M.Saved(9999) == nil, "H2: letzte Messung gemerkt")
    -- Einstellung und Abfrage-Abstand
    mod.db.focusRate = 30
    check(Rd.FocusEvery() == 2, "0.70: Abfragen pro Minute einstellbar (30 = alle 2 Sek.)")
    mod.db.focusRate = 12
    -- Fokus-Seite mit laufender Messung
    local keepOpen, keepStats, keepBand, keepMoney = ns.Scan.ahOpen, ns.Sales.Stats, D.Band, GetMoney
    ns.Sales.Stats = function() return { perHour = 50, level = 3 } end
    D.Band = function() return { trend = "calm", low = 900, high = 1600 } end   -- ab 0.79: ueblicher Bereich ist Pflicht
    GetMoney = function() return 1000000 end
    mod.acc.commodity[7952] = true
    market.items[7952] = { m = 1000, md = 1500, q = 180, n = 3, t = clock, lv = "1000:50;1100:30;1500:100", nm = "Messstein", ql = 1 }
    Rd.entries, Rd.gone, Rd.lastVisible, Rd.loaded = {}, {}, nil, nil
    Rd.LoadIfStale()
    check(Rd.entries[7952] and Rd.entries[7952].kind == "buyout", "H2: Aufkauf fuer den Fokus vorhanden")
    ns.Scan.ahOpen = true
    F.Set(7952)
    M.Start(7952)
    M.Add(7952, rowsOf({ { 1, 50, 1000 }, { 2, 30, 1100 }, { 3, 100, 1500 } }), 0)
    M.Add(7952, rowsOf({ { 1, 20, 1000 }, { 2, 30, 1100 }, { 3, 100, 1500 } }), 60)
    F.Update()
    check(plain(F.verdict.text) == "KAUFEN (vorläufig)" and plain(F.mRows[1].value.text) == "30 je Min." and plain(F.mRows[3].value.text) == "50, schrumpft",
        "H2: Fokus zeigt Urteil und Messwerte: " .. plain(F.verdict.text) .. " / " .. plain(F.mRows[1].value.text) .. " / " .. plain(F.mRows[3].value.text))
    check(F.mHead.text:find("Messung alle 5 Sek.", 1, true) and F.mHead.text:find("tatsächlich 60 Sek.", 1, true), "H2: Kopf mit eingestelltem und tatsaechlichem Abstand: " .. plain(F.mHead.text))
    M.Add(7952, rowsOf({ { 1, 5, 1000 }, { 2, 30, 1100 }, { 3, 100, 1500 } }), 130)
    F.Update()
    local fr = {}
    for _, r in ipairs(F.rows) do if (r.label.text or "") ~= "" then fr[#fr + 1] = r.label.text .. "=" .. plain(r.value.text) end end
    check(table.concat(fr, "|"):find("Verkauft in=", 1, true) and table.concat(fr, "|"):find("(gemessen)", 1, true), "H2: Verkaufsdauer aus dem gemessenen Abfluss: " .. table.concat(fr, "|"))
    -- Warnung vor dem zweiten Klick, wenn der Gesamtpreis hoeher ist als erwartet
    Rd.job = { key = 7952, id = 7952, qty = 80, limit = 1100, stage = "quote", expect = 83000, done = 0 }
    fire("COMMODITY_PRICE_UPDATED", 1050, 84000)
    F.Update()
    check(Rd.job.warn and plain(F.buyInfo.text):find("Achtung", 1, true), "H2: Gesamtpreis ueber dem erwarteten: Warnung vor dem Bestaetigen")
    Rd.job = nil
    -- unterwegs (ab 0.70): nichts Altes, nur der Hinweis
    M.Stop()
    ns.Scan.ahOpen = false
    F.Update()
    check(plain(F.verdict.text) == "NUR AM AUKTIONSHAUS" and #F.tiers.items == 0 and F.buyButton.disabled and plain(F.mRows[3].value.text) == "",
        "0.70: unterwegs keine alten Werte im Fokus")
    if Win.frame then Win.frame:Hide() end
    ns.Scan.ahOpen, ns.Sales.Stats, D.Band, GetMoney = keepOpen, keepStats, keepBand, keepMoney
    market.items[7952] = nil
    Rd.entries, Rd.gone, Rd.lastVisible, Rd.loaded = {}, {}, nil, nil
    mod.acc.focusMeasure = nil
    ns.Go.Clear()
end)()

-- ===== Stufe 2, H3 (0.67): Wiederverkauf-Kette =====
;(function()
    local LT, F = ns.Lots, ns.Focus
    local L = ns.L
    mod.char.lots, mod.char.lotSeq = nil, nil
    check(LT.Count() == 0 and LT.StatusPart() == nil, "H3: anfangs keine Posten")
    -- ab 0.91 (Fehlerbericht 22): Standard aus, dann wird nichts gemerkt
    mod.acc.relist = nil
    check(mod.db.relistDefault == false and not LT.Wanted(7961), "0.91: Wiedereinstellen merken ist anfangs aus")
    Rd.entries[7961] = { key = 7961, kind = "buyout", ref = 1500, qty = 80, name = "Postenstein", rows = {} }
    Rd.job = { key = 7961, id = 7961, qty = 80, limit = 1100, name = "Postenstein", stage = "wait", kind = "buyout", total = 83000, target = 1500, done = 0 }
    Rd.FinishJob(true)
    check(LT.Count() == 0, "0.91: Kauf ohne Haken wird kein Posten")
    -- je Gegenstand eingeschaltet: Aufkauf aus dem Radar wird ein Posten
    LT.SetWanted(7961, true)
    check(LT.Wanted(7961) and not LT.Wanted(7962), "0.91: Haken gilt nur fuer diesen Gegenstand")
    Rd.entries[7961] = { key = 7961, kind = "buyout", ref = 1500, qty = 80, name = "Postenstein", rows = {} }
    Rd.job = { key = 7961, id = 7961, qty = 80, limit = 1100, name = "Postenstein", stage = "wait", kind = "buyout", total = 83000, target = 1500, done = 0 }
    Rd.FinishJob(true)
    local lot = LT.List()[1]
    check(lot and lot.key == 7961 and lot.qty == 80 and lot.left == 80 and lot.cost == 83000 and lot.target == 1500 and lot.src == "radar",
        "H3: Aufkauf wird Posten (Menge, Einsatz, Ziel)")
    check(LT.Count() == 1 and Win.StatusText():find("1 Posten zum Einstellen", 1, true), "H3: Statuszeile nennt die Posten: " .. Win.StatusText())
    -- Haendler-Kaeufe werden keine Posten
    Rd.job = { key = 7962, id = 7962, qty = 5, limit = 3, name = "Billig", stage = "wait", kind = "vendor", total = 15, done = 0 }
    Rd.FinishJob(true)
    check(LT.Count() == 1, "H3: Haendler-Kauf wird kein Posten")
    -- ab 0.97.1: Kauf aus Chancen (Art spec) mit Haken wird ein Posten
    LT.SetWanted(7963, true)
    Rd.job = { key = 7963, id = 7963, qty = 1, limit = 1000, name = "Chancenkette", stage = "wait", kind = "spec", total = 1000, target = 3000, done = 0 }
    Rd.FinishJob(true)
    local specLot = LT.ForKey(7963)
    check(LT.Count() == 2 and specLot and specLot.target == 3000 and specLot.cost == 1000, "0.97.1: Kauf aus Chancen wird Posten")
    if specLot then LT.Remove(specLot.id) end
    LT.SetWanted(7963, false)
    check(LT.Count() == 1, "0.97.1: Posten wieder entfernt")
    Rd.entries = {}
    -- Liste "Zum Einstellen" im Radar
    local keepCount = C_Item.GetItemCount
    C_Item.GetItemCount = function(id) return id == 7961 and 0 or 0 end
    market.items[7961] = { m = 1400, md = 1500, q = 100, n = 2, t = clock, nm = "Postenstein", ql = 1 }
    -- ab 0.71: die Liste "Zum Einstellen" steht im Reiter Verkaufen (eigener Test unten)
    C_Item.GetItemCount = function(id) return id == 7961 and 80 or 0 end
    -- Rat beim Verkaufen: Posten, Zielpreis eintragen
    local A = ns.Advice
    local origHook = rawget(_G, "hooksecurefunc")
    hooksecurefunc = function(t, name, fn) local o = t[name]; t[name] = function(...) local x = o(...) fn(...) return x end end
    local ah = CreateFrame("Frame", "AuctionHouseFrame")
    ah.SellTab = CreateFrame("Button")
    local sf = CreateFrame("Frame"); sf.shown = true
    sf.PostButton = CreateFrame("Button")
    sf.loc = { bag = 0, slot = 1 }
    sf.price, sf.qty = 1400, 80
    sf.GetItem = function(s) return s.loc end
    sf.GetUnitPrice = function(s) return s.price end
    sf.GetQuantity = function(s) return s.qty end
    sf.UpdatePostState = function() end
    local posted = 0
    sf.PostItem = function() posted = posted + 1 end
    local setTo
    sf.PriceInput = { SetAmount = function(_, v) setTo = v; sf.price = v; sf:UpdatePostState() end }
    ah.CommoditiesSellFrame = sf
    local oldLink = C_Item.GetItemLink
    C_Item.GetItemLink = function(loc) return loc and "|cffffffff|Hitem:7961::::::::20:1488:::::::::|h[Postenstein]|h|r" end
    A.hooked, LT.hooked = nil, nil
    mod.acc.commodity[7961] = true
    fire("AUCTION_HOUSE_SHOW")
    check(plain(ah.SellTab.text) == "Verkaufen" and ah.SellTab.corner and ah.SellTab.corner.shown and ah.SellTab.corner.text.text == "1",
      "H3/0.82: Blizzards Reiter Verkaufen mit Zahl im roten Kreis")
    mod.db.badgeSell = "off"
    LT.UpdateSellTab()
    check(not ah.SellTab.corner.shown, "0.97: Zahl am Reiter Verkaufen abschaltbar")
    mod.db.badgeSell = "on"
    LT.UpdateSellTab()
    check(ah.SellTab.corner.shown, "0.97: und wieder an")
    sf:UpdatePostState()
    local box = A.boxes[sf]
    local bt = box.btn
    check(A.lot and A.lot.id == lot.id and bt.target.shown and not bt.target.disabled and plain(bt.target.text) == "Ziel  15s"
        and plain(box.lines.text):find("Posten: gekauft für 10s 38c je Stück, Ziel 15s", 1, true),
        "H3/0.99: Rat nennt Einsatz und Ziel, Knopf Ziel: " .. plain(box.lines.text) .. " / " .. plain(bt.target.text))
    check(plain(bt.cheap.text) == "Günstige  14s" and not bt.cheap.disabled and plain(bt.suggest.text):find("^Vorschlag  ") and not bt.suggest.disabled
        and plain(bt.last.text) == "Letzter" and bt.last.disabled and bt.last.shown,
        "0.99: Knoepfe Guenstige, Vorschlag, Letzter (noch grau): " .. plain(bt.cheap.text) .. " / " .. plain(bt.suggest.text) .. " / " .. plain(bt.last.text))
    check(plain(box.lines.text):find("unter dem Ziel", 1, true), "H3: Warnung: Markt liegt unter dem Ziel")
    do
      local t = plain(box.lines.text)
      check(t:find("\nErlös:  ", 1, true) and t:find("\nMöglicher Gewinn:  ", 1, true) and t:find("(Einkauf ", 1, true),
        "0.99.1: Erloes und moeglicher Gewinn in eigener Zeile, Einkauf aus dem Posten: " .. t)
      local g = A.Profit({ net = 2850, qty = 2 }, { cost = 2076, qty = 2 })
      check(g and g.cost == 2076 and g.gain == 774, "0.99.1: Gewinn = Erloes minus Einkauf")
      g = A.Profit({ net = 950.4, qty = 1 }, nil)
      check(g and g.cost == nil and g.gain == 950, "0.99.1: ohne Einkauf zaehlt der Erloes ganz")
      check(A.Profit({ qty = 1 }, nil) == nil, "0.99.1: ohne Erloes kein Gewinn")
      do   -- ab 0.100: offene Einstellgebuehren je Stueck aus Peon_Ledger
        local saved = ns.Item.OpenFee
        ns.Item.OpenFee = function() return 15 end
        g = A.Profit({ net = 2850, qty = 2, key = 2589 }, { cost = 2076, qty = 2 })
        check(g and g.fee == 30 and g.gain == 744, "0.100: Gewinn minus offene Gebuehren (2 x 15c)")
        ns.Item.OpenFee = function() return nil end
        g = A.Profit({ net = 2850, qty = 2, key = 2589 }, { cost = 2076, qty = 2 })
        check(g and g.fee == nil and g.gain == 774, "0.100: ohne offene Gebuehren wie bisher")
        ns.Item.OpenFee = saved
      end
    end
    GetTime = function() return now end
    bt.cheap.scripts.OnClick(bt.cheap)
    check(setTo == 1400 and sf.price == 1400, "0.99: Guenstige ins Preisfeld geschrieben")
    bt.target.scripts.OnClick(bt.target)
    check(setTo == 1500 and sf.price == 1500 and LT.filledAt, "H3: Zielpreis ins Preisfeld geschrieben")
    -- Einstellen: Anhang an PostItem, Ereignis bestaetigt
    sf:PostItem()
    fire("AUCTION_HOUSE_AUCTION_CREATED", 555)
    check(posted == 1 and lot.left == 0 and lot.posted and lot.posted.price == 1500 and lot.posted.qty == 80 and LT.Count() == 0,
        "H3: eingestellt: Posten erledigt, Preis gemerkt")
    check(A.LastPost(7961) == 1500, "0.99: zuletzt eingestellter Preis gemerkt")
    sf.price = 1300
    sf:UpdatePostState()
    check(plain(bt.last.text) == "Letzter  15s" and not bt.last.disabled and not bt.target.shown, "0.99: Knopf Letzter mit Preis, ohne Posten kein Ziel")
    bt.last.scripts.OnClick(bt.last)
    check(setTo == 1500, "0.99: Letzter ins Preisfeld geschrieben")
    -- Ziel aus Beobachten, wenn es keinen Posten gibt
    ns.Watch.Add(7961, { name = "Postenstein" })
    ns.Watch.SetUp(7961, 1700)
    sf:UpdatePostState()
    check(bt.target.shown and plain(bt.target.text) == "Ziel  17s" and box.prices.targetSrc == "watch", "0.99: Ziel aus Beobachten")
    ns.Watch.Store()[7961] = nil
    check(plain(ah.SellTab.text) == "Verkaufen", "H3: Zahl am Reiter Verkaufen weg")
    -- Blockade direkt nach dem Eintragen: Knopf nicht mehr anbieten
    LT.Add(7961, 10, 10000, 1500, "radar")
    LT.filledAt = now
    fire("ADDON_ACTION_FORBIDDEN", "Peon_Broker", "UNKNOWN()")
    check(type(mod.acc.targetBlocked) == "table" and not LT.CanFill(), "H3: Blockade nach dem Eintragen gemerkt")
    sf:UpdatePostState()
    check(bt.target.shown and bt.target.disabled and bt.cheap.disabled and bt.last.disabled and plain(box.lines.text):find("selbst eintippen", 1, true),
        "H3/0.99: dann Knoepfe grau, nur noch der Preis im Rat")
    mod.acc.targetBlocked = nil
    LT.filledAt = nil
    fire("ADDON_ACTION_FORBIDDEN", "Peon_Broker", "UNKNOWN()")
    check(mod.acc.targetBlocked == nil, "H3: Blockade ohne Eintragen kurz davor zaehlt nicht")
    ns.AHTabs.blocked, ns.AHTabs.offered, mod.acc.ahBlocked = {}, nil, nil   -- Spuren der nachgestellten Blockaden
    -- Fokus bewacht den eingestellten Posten
    check(ns.Measure.ChanceTarget(7961) == 1500, "H3: Messung im Fokus misst unter dem eigenen Preis")
    local keepOpen = ns.Scan.ahOpen
    ns.Scan.ahOpen = true   -- ab 0.70 zeigt der Fokus nur am Auktionshaus etwas
    ns.Buy.live[7961] = nil
    F.Set(7961)
    check(plain(F.verdict.text) == "GEKAUFT" and plain(F.why.text):find("15s", 1, true), "H3: Fokus nach dem Kauf: Posten unterwegs mit Ziel")
    for _, x in ipairs(LT.List()) do if x ~= lot then x.left = 0 end end
    F.Update()
    check(plain(F.verdict.text) == "EINGESTELLT" and F.rows[3].label.text == L.FOCUS_R_POSTED, "H3: Fokus zeigt den eingestellten Posten")
    if Win.frame then Win.frame:Hide() end
    ns.Scan.ahOpen = keepOpen
    -- Unterbotene abbrechen
    local X = ns.AuctionsAH
    local af = CreateFrame("Frame"); af.shown = true
    local list = CreateFrame("Frame")
    list.ScrollBox = { ForEachFrame = function() end }
    af.AllAuctionsList = list
    ah.AuctionsFrame = af
    X.header = nil
    X.Build()
    ns.Auctions.rows = { { id = 21, key = 2770, itemID = 2770, name = "Kupfererz", status = "under", other = 50, price = 60, qty = 20 },
                         { id = 22, key = 2589, itemID = 2589, name = "Leinen", status = "best", price = 70, qty = 5 } }
    local cancelled
    AHs.GetCancelCost = function(id) return id == 21 and 1200 or nil end
    AHs.CancelAuction = function(id) cancelled = id end
    X.Update()
    check(X.header.cancel and plain(X.header.cancel.text) == "Unterbotene abbrechen (1)" and not X.header.cancel.disabled,
        "H3 (0.69): Knopf nennt die Anzahl, die Einzahlung steht im Tooltip: " .. plain(X.header.cancel.text))
    X.header.cancel.scripts.OnClick(X.header.cancel)
    check(cancelled == 21 and LT.cancelling and X.header.cancel.disabled, "H3: ein Klick bricht die naechste unterbotene ab")
    local before = #LT.List()
    fire("AUCTION_CANCELED", 21)
    local cl = LT.List()[#LT.List()]
    check(#LT.List() == before + 1 and cl.src == "cancel" and cl.key == 2770 and cl.qty == 20 and cl.target == 50 and cl.cost == nil,
        "H3: Abgebrochenes wird Posten mit neuem Preis (guenstigstes Angebot, Massenware ohne Unterbieten)")
    -- Rechtsklick: Posten entfernen
    local opened
    MenuUtil = { CreateContextMenu = function(owner, gen)
        local node = { items = {} }
        function node:CreateTitle(t) end
        function node:CreateButton(t, fn) self.items[#self.items + 1] = { t = t, fn = fn } end
        gen(owner, node); opened = node
    end }
    LT.Menu({ lot = cl, key = 2770, name = "Kupfererz" }, CreateFrame("Frame"))
    check(opened and opened.items[1].t == L.LOTS_REMOVE, "H3: Menue mit Posten entfernen")
    opened.items[1].fn()
    check(LT.List()[#LT.List()] ~= cl, "H3: Posten entfernt")
    MenuUtil = nil
    -- Aufraeumen: eingestellte Posten nach 2 Tagen weg
    lot.posted.t = clock - 3 * 86400
    LT.Prune(clock)
    local still = false
    for _, x in ipairs(LT.List()) do if x == lot then still = true end end
    check(not still, "H3: eingestellte Posten verschwinden nach 2 Tagen")
    C_Item.GetItemLink, C_Item.GetItemCount = oldLink, keepCount
    hooksecurefunc = origHook
    AHs.GetCancelCost, AHs.CancelAuction = nil, nil
    ns.Auctions.rows = nil
    X.header = nil
    market.items[7961] = nil
    mod.char.lots = nil
    AuctionHouseFrame = {}
    ns.Go.Clear()
end)()

-- ===== Stufe 2, H4 (0.68): kleine Hilfen =====
;(function()
    local Buy, Wt, C, RS = ns.Buy, ns.Watch, ns.Craft, ns.Resale
    local keepPrice = ns.Merchant.Price
    local VP = { [7971] = { 40, "seen", "Gretta" }, [7972] = { 500, "est" } }
    ns.Merchant.Price = function(id) local v = VP[id]; if v then return v[1], v[2], v[3] end end
    -- 6.4 Haendler-Warnung in Blizzards Kaufansicht
    check(RS.VendorWarning(7971, 50) and RS.VendorWarning(7971, 50):find("Gretta", 1, true) and RS.VendorWarning(7971, 30) == nil,
        "H4: Warnung nur, wenn der Haendler guenstiger ist, mit Namen")
    check(RS.VendorWarning(7972, 900):find("geschätzt", 1, true), "H4: geschaetzter Haendlerpreis ist markiert")
    check(RS.VendorWarning(9999, 50) == nil, "H4: ohne bekannten Haendler keine Warnung")
    -- 6.4 Rat HAENDLER in Einkaufen
    check(Buy.Advice({ need = 5, cheapest = 50, hits = 5, vendorP = 40 }) == "vendor", "H4: Haendler guenstiger: Rat HAENDLER")
    check(Buy.Advice({ need = 5, vendorP = 40 }) == "vendor", "H4: nur beim Haendler zu haben: Rat HAENDLER")
    check(Buy.Advice({ need = 5, cheapest = 30, hits = 5, vendorP = 40 }) == "buy", "H4: AH guenstiger: weiter KAUFEN")
    check(Buy.Advice({ need = 0, vendorP = 40 }) == "done", "H4: nichts mehr noetig: erledigt")
    -- 6.5 Material aus dem Berufsfenster
    local before = #Buy.Lists()
    local n, list = Buy.AddMaterials({
        { id = 7971, q = 2, have = 3, vendor = 40, ah = 60 },
        { id = 7973, q = 1, have = 10, vendor = nil, ah = 100 },
        { id = 7974, q = 4, have = 0, vendor = 900, ah = 300 },
    }, 5)
    check(n == 2 and list and list.name == "Material" and #Buy.Lists() == before + 1, "H4: Liste Material angelegt, nur fehlendes Material")
    check(list.items[7971].wish == 10 and list.items[7971].v == true and list.items[7974].wish == 20 and list.items[7974].v == nil and list.items[7973] == nil,
        "H4: Ziel = Menge je Herstellung x 5, Haendlerware markiert")
    n = Buy.AddMaterials({ { id = 7971, q = 2, have = 3, vendor = 40, ah = 60 } }, 1)
    check(#Buy.Lists() == before + 1 and list.items[7971].wish == 10, "H4: gleiche Liste wiederverwendet, Ziel wird nicht kleiner")
    local rows = Buy.ListRows(list)
    local r71
    for _, r in ipairs(rows) do if r.key == 7971 then r71 = r end end
    check(r71 and r71.advice == "vendor" and r71.vendorP == 40, "H4: Material vom Haendler steht mit Rat HAENDLER in der Liste")
    -- ab 0.95: das Menue im Berufsfenster ist in Peon_Profession, es nutzt mod:AddToList mit keepMax
    local n2, list2 = mod:AddToList("Material", { { id = 7975, n = 15, v = true } }, true)
    check(n2 == 1 and list2 == list and list.items[7975].wish == 15 and list.items[7975].v == true, "0.95: AddToList mit keepMax auf die Liste Material, Haendlerware")
    mod:AddToList("Material", { { id = 7975, n = 3, v = false } }, true)
    check(list.items[7975].wish == 15 and list.items[7975].v == nil, "0.95: keepMax: Ziel wird nicht kleiner")
    for i, l in ipairs(Buy.Lists()) do if l == list then table.remove(Buy.Lists(), i) break end end
    -- 6.6 Beobachtung mit Grenze nach oben
    market.items[7976] = { m = 500, md = 520, q = 10, n = 2, t = clock, nm = "Seltenes Ding", ql = 3 }
    Wt.Add(7976, { name = "Seltenes Ding" })
    check(Wt.SetUp(7976, 600) and Wt.Store()[7976].up == 600 and not Wt.Store()[7976].upHit, "H4: Grenze nach oben gesetzt, noch nicht erreicht")
    market.items[7976].m = 650
    check(Wt.Check({ 7976 }) == 1 and Wt.Store()[7976].upHit and said("Guter Zeitpunkt zum Verkaufen"), "H4: Preis ueber der Grenze: Meldung")
    check(Wt.Check({ 7976 }) == 0, "H4: Meldung nur einmal")
    local wr
    for _, r in ipairs(ns.WatchPage.Rows()) do if r.key == 7976 then wr = r end end
    check(wr and wr.target == 600 and wr.advice == "sell", "H4/0.82: Zielpreis und Rat VERKAUFEN unter Beobachten")
    market.items[7976].m = 550
    Wt.Check({ 7976 })
    check(not Wt.Store()[7976].upHit, "H4: wieder unter der Grenze: Meldung wieder scharf")
    Wt.SetUp(7976, nil)
    check(Wt.Store()[7976].up == nil, "H4: Grenze nach oben entfernt")
    Wt.Remove(7976)
    market.items[7976] = nil
    ns.Merchant.Price = keepPrice
end)()

-- ===== 0.21: Richtwert und ueblicher Bereich (Rechenmodell Kapitel 7, Beispiele aus echten Daten 02.10.2026) =====
;(function()
    local today = D.Day()
    local function days(a, b, c) return ("%d:0:%s:0:12;%d:0:%s:0:12;%d:0:%s:0:16"):format(today - 2, a * 12, today - 1, b * 12, today, c * 16) end
    local db = { undercutMassMode = "copper", undercutMassValue = 0, undercutMode = "copper", undercutValue = 1, dumpPct = 30,
                 dealScans = 1, dealDays = 7, dealMargin = 20, dealDepth = 100, dealMinMarket = 0, dealMinVendor = 0, radarKind = "both" }
    mod.acc.commodity[8001], mod.acc.commodity[8002] = true, true
    -- Leinenstoff: ruhig, guenstigstes Angebot weit darunter -> Dumping, Vorschlag = Untergrenze
    local lein = { m = 30, md = 89, pmd = 59, pm = 30, d = days(110, 99, 79) }
    local b = D.Band(lein)
    check(b and b.days == 3 and b.trend == "calm" and b.rw == 89 and b.low == 74 and b.high == 103, "Leinenstoff: Richtwert 89c, Bereich 74c – 1s 03c, ruhig")
    local vp, _, dump = D.Suggest(30, 89, 8001, db, lein, 59)
    check(vp == 74 and dump, "Leinenstoff: Dumping, Vorschlag 74c (bisher 75c)")
    local v = D.Evaluate(lein, 8001, 20, 1, db)
    check(v.entry == 30 and v.state == "dump" and math.floor(v.erl + 0.5) == 570, "Zeile 1: guenstigstes Angebot (20 × 30c − 5 %), rot (Dumping)")
    -- Wollstoff: zwei Messungen unter dem Bereich -> faellt, Vorschlag folgt dem Markt
    local woll = { m = 68, md = 80, pmd = 78, pm = 70, d = days(283, 269, 107) }
    local bw = D.Band(woll)
    check(bw.trend == "down" and bw.rw == 80 and bw.low == 73 and bw.high == 86, "Wollstoff: faellt, Bereich um den aktuellen Median")
    local vw, _, dw = D.Suggest(68, 80, 8002, db, woll, 78)
    check(vw == 68 and not dw and D.Evaluate(woll, 8002, 1, 1, db).state == "falling", "Wollstoff: Vorschlag = guenstigstes Angebot, orange")
    check(plain(ns.Tooltip.RangeText(bw)) == "73c – 86c fällt" and ns.Tooltip.StateColor("dump") == "|cffff4040", "Anzeige: Bereich mit Marktlage, Farben")
    -- Runenstoffballen: verrueckter heutiger Tageswert wird ueberstimmt
    local rune = { m = 3700, md = 3900, pmd = 3900, d = days(2709, 2267, 15319) }
    local br = D.Band(rune)
    check(br.trend == "calm" and br.rw == 3900 and D.Evaluate(rune, "9:1", 1, 1, db).state == "good", "Runenstoffballen: Ausreisser ueberstimmt, gruen")
    -- Efeustoffschaerpe: altes hohes Niveau, zwei Scans viel tiefer -> faellt
    local efeu = { m = 1500, md = 1500, pmd = 2200, d = days(6479, 4292, 7284) }
    check(D.Band(efeu).trend == "down" and D.Band(efeu).rw == 1500, "Efeustoffschaerpe: neuer Preisstand erkannt")
    -- zu wenig Tage: kein Bereich, bisheriges Verfahren
    check(D.Band({ md = 10, d = today .. ":0:120:0:12" }) == nil, "weniger als 3 Tage: kein Bereich")
    -- 0.38 (F37a): Magicusmantel 4g, 4g, heute 1g 50s. Nach unten erst bei 25 % Schwankung gekuerzt, der Sturz zaehlt voll
    local bm = D.Band({ md = 12400, pmd = 12400, d = days(40000, 40000, 15000) })
    local w1, w2 = 0.5 ^ (2 / 3), 0.5 ^ (1 / 3)
    check(bm and math.abs(bm.lang - (40000 * (w1 + w2) + 15000) / (w1 + w2 + 1)) < 0.01 and bm.trend == "down",
        "Magicusmantel: Preissturz nicht weggekuerzt, Markt faellt")
    -- Radar: im fallenden Markt kein Markt-Schnaeppchen, im ruhigen schon
    check(D.Deal(woll, { { price = 40, qty = 5, own = 0 }, { price = 80, qty = 50, own = 0 } }, nil, db, today) == nil, "Radar: Markt faellt -> kein Markt-Schnaeppchen")
    local dl = D.Deal(lein, { { price = 30, qty = 5, own = 0 }, { price = 89, qty = 50, own = 0 } }, nil, db, today)
    check(dl and dl.kind == "market" and dl.refMedian == 74 and dl.ref == 74, "Radar (ab 0.26): ruhiger Markt, Angebot unter dem Bereich -> Wiederverkauf zur Untergrenze 74c")
    -- 0.26: Beispiel KarloDerBaer 03.10.2026 (Abgefangene Kiste, Bild): Bereich 1s 59c - 17s 66c, 55 Stueck bis 3s 50c, naechstes 4s 50c
    local kist = { m = 100, md = 500, pmd = 520, d = days(900, 400, 500), q = 323 }
    local kb = D.Band(kist)
    local krow = {}
    for i, k in ipairs({ { 100, 7 }, { 200, 2 }, { 211, 3 }, { 215, 3 }, { 225, 3 }, { 250, 28 }, { 300, 1 }, { 350, 8 }, { 450, 18 }, { 470, 27 }, { 480, 32 }, { 499, 5 } }) do
        krow[i] = { price = k[1], qty = k[2], own = 0 }
    end
    local db2 = {}
    for k, v in pairs(db) do db2[k] = v end
    db2.dealDepth, db2.dealMinMarket = 20, 0
    local d0 = D.Deal(kist, krow, nil, db2, today)
    check(kb and d0 and d0.ref <= kb.low and d0.qty < 55 and d0.salesUnknown, "Kiste 03.10.: Wiederverkauf hoechstens Untergrenze, nicht mehr 55 Stueck, Absatz unbekannt")
    db2.dealMinMarket = 10
    check(D.Deal(kist, krow, nil, db2, today) == nil, "Kiste 03.10.: unter dem Mindestgewinn 10s -> kein Schnaeppchen")
    db2.dealMinMarket = 0
    -- Absatz 0/Std. (2 Std. beobachtet, gelb) -> kein Markt-Schnaeppchen
    kist.ar = (time() - 600) .. ":7200:0:0:0"
    check(D.Deal(kist, krow, nil, db2, today) == nil, "Absatz 0/Std. (gelb) -> kein Markt-Schnaeppchen")
    -- rotes Zeichen (unter 60 Min.) zaehlt nicht: wie unbekannt
    kist.ar = (time() - 600) .. ":1800:0:0:0"
    local dr = D.Deal(kist, krow, nil, db2, today)
    check(dr and dr.salesUnknown, "Absatz unsicher (rot) -> Menge nicht begrenzt, Hinweis")
    -- Absatz begrenzt die Menge: 0,1/Std. x 48 Std. = 4 Stueck
    local big = { m = 100, md = 1000, pmd = 1000, d = days(1000, 1000, 1000), q = 400 }
    local brow = { { price = 100, qty = 4, own = 0 }, { price = 200, qty = 4, own = 0 }, { price = 1000, qty = 392, own = 0 } }
    db2.dealDepth = 100
    check(D.Deal(big, brow, nil, db2, today).qty == 8, "ohne Absatz: beide billigen Stufen (8 Stueck)")
    big.ar = (time() - 600) .. ":36000:1:0:0"
    local db3 = D.Deal(big, brow, nil, db2, today)
    check(db3 and db3.qty == 4 and db3.salesCap == 4 and db3.sales and not db3.salesUnknown, "Absatz 0,1/Std. x 48 Std. -> hoechstens 4 Stueck")
    db2.dealHold = 24
    check(D.Deal(big, brow, nil, db2, today) == nil, "Haltezeit 24 Std. -> 2 Stueck, Rest der Stufe bleibt billiger -> kein Schnaeppchen")
    -- Zeilen-Tooltip im Radar (ab 0.26): Wiederverkauf, Absatz bzw. Hinweis "unbekannt"
    db3.key, db3.scans = 7778, 12
    tt.lines = {}
    ns.Radar.RowTooltip({}, db3)
    local tj = plain(table.concat(tt.lines, "\n"))
    check(tj:find("Wiederverkauf: ", 1, true) and tj:find("höchstens Untergrenze", 1, true) and tj:find("höchstens 4 St. in 48 Std.", 1, true), "Radar-Tooltip: Wiederverkauf und Absatz-Grenze")
    tt.lines = {}
    dr.key, dr.scans = 7778, 12
    ns.Radar.RowTooltip({}, dr)
    check(plain(table.concat(tt.lines, "\n")):find("Absatz unbekannt oder unsicher", 1, true), "Radar-Tooltip: Absatz unbekannt")
    check(mod.db.dealHold == 48, "Einstellung Haltezeit: Standard 48 Std.")
end)()

-- ===== 0.21.3: Qualitaet aus Links im Forever-Format =====
;(function()
    local OWN = { { auctionID = 31, itemLink = "|cnIQ3:|Hitem:4577::::::::20:1488:::::::::|h[Kompakte Schrotflinte]|h|r", itemKey = { itemID = 4577 },
        status = 0, quantity = 1, buyoutAmount = 500, timeLeftSeconds = 3600 } }
    local sn, si = AHs.GetNumOwnedAuctions, AHs.GetOwnedAuctionInfo
    AHs.GetNumOwnedAuctions, AHs.GetOwnedAuctionInfo = function() return 1 end, function(i) return OWN[i] end
    Auc.Read()
    check(Auc.rows[1].quality == 3, "Meine Auktionen: Qualitaet aus |cnIQ3:-Link")
    AHs.GetNumOwnedAuctions, AHs.GetOwnedAuctionInfo = sn, si
end)()

-- ===== L6: Zusammenspiel mit Peon_Ledger (ab 0.22) =====
;(function()
  local val = ns.ItemValue(2770, 10)
  check(type(val) == "number" and val > 0 and mod:ItemValue(2770, 10) == val, "Wert fuer Ledger (Zeile 1 des Tooltips): " .. tostring(val))
  check(ns.ItemValue(99999999, 1) == nil, "kein Wert ohne Preis")
  -- Ledger (nachgebaut): Vorrat der Twinks, Verkaufsquote
  Peon.modules.ledger = { StockOthers = function(_, id) return id == 2770 and 20 or 0 end,
                          SellRate = function(_, id) if id == 2770 then return 0.75, 3, 1 end return nil, 0, 0 end }
  mod.db.keepAllChars = false
  local _, _, tot, oth = K.Counts(2770)
  check(tot == 65 and oth == 0, "Umschalter aus: nur dieser Charakter")
  mod.db.keepAllChars = true
  _, _, tot, oth = K.Counts(2770)
  check(tot == 85 and oth == 20, "Vorrat aller Charaktere: 65 + 20 bei Twinks")
  mod.db.keepAllChars = false
  -- 0.24: Einkaufsliste mit Spalte Vorrat und demselben Umschalter
  local savedLists, savedSel = PeonBrokerDB.lists, PeonBrokerCharDB.listSel
  PeonBrokerDB.lists, PeonBrokerCharDB.listSel = { { name = "T", pct = 10, items = { [2770] = { wish = 100, name = "Kupfererz" } } } }, 1
  Win.Select("buy"); ns.Buy.Refresh()
  local br = ns.Buy.ListRows()[1]
  check(br.stock == 65 and ns.Buy.allChars.shown ~= false and not ns.Buy.allChars.checked, "Einkaufsliste: Vorrat dieses Charakters, Umschalter sichtbar")
  ns.Buy.allChars:SetChecked(true); ns.Buy.allChars.scripts.OnClick(ns.Buy.allChars)
  br = ns.Buy.ListRows()[1]
  check(mod.db.keepAllChars == true and br.stock == 85, "Einkaufsliste: Umschalter an -> Vorrat aller Charaktere (gleiche Einstellung wie Behalten)")
  ns.Buy.allChars:SetChecked(false); ns.Buy.allChars.scripts.OnClick(ns.Buy.allChars)
  PeonBrokerDB.lists, PeonBrokerCharDB.listSel = savedLists, savedSel
  -- Tooltip mit Umschalt: eigene Verkaufsquote
  shift = true
  local lines = ttLines(KLINK)
  local found for _, l in ipairs(lines) do if l:find("Deine Verkäufe (30 T.)", 1, true) then found = l end end
  check(found and found:find("3 von 4 verkauft (75 %)", 1, true), "Tooltip: Verkaufsquote aus Ledger (" .. tostring(found) .. ")")
  shift = false
  Peon.modules.ledger = nil
  -- Felder der Suchergebnisse (Vorbereitung Absatzquote)
  ns.Probe.Field("commodity", { auctionID = 5, quantity = 10, unitPrice = 3, timeLeftSeconds = 7200, owners = { "Bob" } })
  ns.Probe.Field("item", { auctionID = 7, quantity = 1, buyoutAmount = 500, timeLeft = 2 })
  local fp = PeonBrokerDB.fieldProbe
  check(fp.commodity.keys.auctionID and fp.commodity.keys.timeLeftSeconds and fp.item.keys.timeLeft and #fp.item.samples >= 1, "Felder der Ergebnisse gezaehlt")
  SlashCmdList.PEON_BROKER("pruefen auktionen")
  check(said("Massenware:") and said("Felder: auctionID"), "/broker pruefen auktionen")
end)()

-- ===== Absatz (ab 0.23, Peon_Broker_Absatz.md) =====
;(function()
  local Sa = ns.Sales
  local t0 = 1790000000
  local function off(id, q, p, lo, hi) return { id = id, q = q, p = p, lo = lo or 0, hi = hi or 0 } end
  -- Massenware mit Nummern: Teilkauf, vorzeitig weg (billigstes), abgebrochen (billigeres stand in beiden), abgelaufen, billiger neu eingestellt
  local A = { off(1, 200, 10, t0 + 9000, t0 + 9000), off(2, 50, 12, t0 + 9000, t0 + 9000), off(3, 20, 15, t0 + 9000, t0 + 9000),
              off(4, 10, 16, t0 + 1000, t0 + 1000), off(5, 30, 20, t0 + 9000, t0 + 9000) }
  local B = { off(1, 140, 10), off(5, 30, 20), off(9, 20, 14) }   -- 2 weg (billigstes nach 1? nein: 1 stand -> abgebrochen), 3 weg + neue 9 gleiche Menge billiger
  local so, ex, ca = Sa.Compare(A, B, t0, t0 + 3600, 0, true, true, 0.1)
  check(so == 60 and ex == 10 and ca == 70, "Massenware: Teilkauf 60 verkauft, 10 abgelaufen, 50+20 abgebrochen (" .. so .. "/" .. ex .. "/" .. ca .. ")")
  -- ohne guenstigeres stehendes Angebot: vorzeitig weg = verkauft
  so, ex, ca = Sa.Compare({ off(1, 20, 10, t0 + 9000, t0 + 9000), off(2, 5, 11, t0 + 9000, t0 + 9000) }, { off(2, 5, 11) }, t0, t0 + 3600, 0, true, true, 0.1)
  check(so == 20 and ca == 0, "Massenware: billigstes Angebot weg = verkauft")
  -- Einzelgegenstaende: verkauft minus Schaetzwert, Stufe unklar = nicht gezaehlt
  so, ex, ca = Sa.Compare({ off(1, 1, 500, t0 + 43200, t0 + 172800), off(2, 1, 600, t0 + 1800, t0 + 7200), off(3, 1, 700, t0 + 43200, t0 + 172800) },
                         { off(3, 1, 700) }, t0, t0 + 3600, 0, false, true, 0.1)
  check(math.abs(so - 0.9) < 0.001 and math.abs(ca - 0.1) < 0.001 and ex == 0, "Einzelgegenstand: 0,9 verkauft, 0,1 abgebrochen, Stufe 1 unklar")
  -- nur bis zur Preisgrenze vergleichen
  so, ex, ca = Sa.Compare({ off(1, 10, 10, t0 + 9000, t0 + 9000), off(2, 10, 50, t0 + 9000, t0 + 9000) }, { off(1, 10, 10) }, t0, t0 + 3600, 30, true, true, 0.1)
  check(so == 0 and ca == 0, "teurer als die Preisgrenze: nicht verglichen")
  -- Scan ohne Nummern: gleiches Angebot = Preis+Menge, Teilkauf ueber gleichen Preis, ohne Stufe nur bis 2 Std. Abstand
  so, ex, ca = Sa.Compare({ off(0, 100, 10), off(0, 40, 11), off(0, 30, 12) }, { off(0, 70, 10), off(0, 30, 12) }, t0, t0 + 1800, 0, true, false, 0.1)
  check(so == 30 and ca == 40, "Scan: Teilkauf 30, 40 oberhalb des stehenden Angebots = abgebrochen")
  so, ex, ca = Sa.Compare({ off(0, 100, 10), off(0, 30, 12) }, { off(0, 30, 12) }, t0, t0 + 3 * 3600, 0, true, false, 0.1)
  check(so == 0 and ca == 0, "Scan ohne Restzeit, Abstand 3 Std.: unklar")
  -- ab 0.103: hoechster vermutlich verkaufter Preis, auch wenn das einzige Angebot ganz verschwindet
  local sp
  so, ex, ca, sp = Sa.Compare({ off(1, 1, 6925, t0 + 43200, t0 + 172800) }, {}, t0, t0 + 3600, 0, false, true, 0.1)
  check(sp == 6925 and so > 0, "0.103: Einzelstueck verschwunden, Verkaufspreis gemerkt")
  so, ex, ca, sp = Sa.Compare({ off(1, 1, 500, t0 + 1000, t0 + 1000) }, {}, t0, t0 + 3600, 0, false, true, 0.1)
  check(sp == nil and ex == 1, "0.103: abgelaufen ergibt keinen Verkaufspreis")
  local es = { as = { t = t0, cap = 0, s = Sa.Encode({ off(1, 1, 6925, t0 + 43200, t0 + 172800) }, t0, true) } }
  Sa.Observe(es, "as", Sa.Snapshot(t0 + 3600, {}, false, true), {}, false, true)
  local lp, lt = Sa.LastSold(es)
  check(lp == 6925 and lt == t0 + 3600, "0.103: e.sp nach dem Vergleich gesetzt")
  -- Restzeit-Stufen wie in Forever (1-4)
  check(Sa.BANDS[4] and Sa.BANDS[4][1] == 43200 and Sa.BANDS[1][2] == 1800, "Restzeit-Stufen 1-4 (Forever)")
  -- Ablauf ueber den Gegenstand: Live-Abfragen ueber Data.ApplyLive
  local key = 2770
  local e = D.Market().items[key]
  e.as, e.ss, e.ab, e.ar, e.acov = nil, nil, nil, nil, nil
  local function live(t, list, partial)
    local rows = { offers = {}, commodity = true, partial = partial }
    for _, o in ipairs(list) do rows[#rows + 1] = { price = o[3], qty = o[2], own = 0 }; rows.offers[#rows.offers + 1] = { id = o[1], q = o[2], p = o[3], secs = o[4] } end
    return D.ApplyLive(key, rows, t)
  end
  live(t0, { { 11, 100, 50, 20000 }, { 12, 40, 60, 20000 } })
  check(e.as and Sa.Stats(e, t0) == nil, "erste Beobachtung: Stand gemerkt, noch kein Wert")
  live(t0 + 30, { { 11, 95, 50, 19970 }, { 12, 40, 60, 19970 } })
  check(Sa.Stats(e, t0 + 30) == nil and e.as.t == t0, "unter 1 Min.: alter Stand bleibt")
  live(t0 + 1800, { { 11, 70, 50, 18200 }, { 12, 40, 60, 18200 } })
  local r = Sa.Stats(e, t0 + 1800)
  check(r and r.sold == 30 and r.cmp == 1 and math.abs(r.perHour - 60) < 0.01 and r.level == 1, "30 Min.: 30 verkauft -> 60/Std., rotes ≈ (wenig Daten)")
  check(r.reach and math.abs(r.reach - 110 / 60) < 0.001, "Reichweite in Stunden = Angebot ÷ Absatz je Stunde")
  local txt = Sa.TooltipText(r)
  check(txt:find("|cffff5555≈", 1, true) and txt:find("60/Std.", 1, true) and not txt:find("reicht", 1, true), "Tooltip: rotes ≈, ohne Reichweite (" .. txt .. ")")
  check(Sa.SellText(r):find("reicht 1,8 Std.", 1, true), "Verkaufen: mit Reichweite")
  -- Scan-Vergleich im gleichen Zeitraum: nicht doppelt zaehlen
  Sa.OnScan(e, key, { 50, 100, 3, 60, 40, 3 }, t0)
  Sa.OnScan(e, key, { 50, 70, 3, 60, 40, 3 }, t0 + 1200)
  r = Sa.Stats(e, t0 + 1800)
  check(r.cmp == 1 and r.sold == 30, "Scan-Zeitraum schon gezaehlt: nicht doppelt")
  -- mehr beobachtete Zeit: gelb, dann gruen; Hinweise ab gelb
  live(t0 + 5400, { { 11, 40, 50, 14600 }, { 12, 40, 60, 14600 } })
  r = Sa.Stats(e, t0 + 5400)
  check(r.level == 2 and r.minutes == 90 and Sa.TooltipText(r):find("|cffffd100≈", 1, true), "90 Min. beobachtet: gelbes ≈")
  live(t0 + 12600, { { 11, 40, 50, 7400 }, { 12, 40, 60, 7400 } })
  r = Sa.Stats(e, t0 + 12600)
  check(r.level == 3 and Sa.TooltipText(r):find("|cff60e060≈", 1, true), "3,5 Std. beobachtet: gruenes ≈ (immer mit Zeichen)")
  -- Zeitfenster: nach 7 Std. ohne neue Vergleiche faellt der aktuelle Wert weg, 14-Tage-Wert bleibt
  check(Sa.Stats(e, t0 + 12600 + 7 * 3600) == nil and Sa.Stats14(e, D.Day(t0 + 12600)).sold == 60, "aktuell nur die letzten 6 Std., 14 Tage intern")
  -- Tooltip mit Umschalt
  local savedStats = Sa.Stats
  Sa.Stats = function(x) if x == e then return savedStats(e, t0 + 12600) end return savedStats(x) end
  shift = true
  local lines = ttLines(KLINK)
  local found for _, l in ipairs(lines) do if l:find("^Absatz = ") then found = l end end
  check(found and found:find("am Tag", 1, true), "Tooltip: Zeile Absatz (" .. tostring(found) .. ")")
  shift = false
  -- Chat
  SlashCmdList.PEON_BROKER("absatz Kupfererz")
  check(said("Absatz Kupfererz") and said("letzte 6 Std.:"), "/broker absatz Kupfererz (aktuell; 14 Tage wenn vorhanden)")
  -- Preise: Spalte
  local col for _, c in ipairs(ns.Item.results.o.columns) do if c.key == "sales" then col = c end end
  check(col and col.format(Sa.Stats(e), {}):find("/Std.", 1, true), "Preise: Spalte Absatz/Std.")
  Sa.Stats = savedStats
  -- alte Daten (bis 0.23.0) werden verworfen
  local acc = { markets = { M = { items = { [1] = { ab = "x", ss = {}, as = {}, ar = "y", acov = 1, m = 5 } } } } }
  Sa.Migrate(acc)
  check(acc.salesVer == 2 and acc.markets.M.items[1].ab == nil and acc.markets.M.items[1].m == 5, "Absatz-Daten bis 0.23.0 verworfen, Preise bleiben")
  e.as, e.ss, e.ab, e.ar, e.acov = nil, nil, nil, nil, nil
end)()

-- ===== ab 0.95: Berufsfenster in Peon_Profession, bei Broker bleiben Preise und Vorrat (mod:BuyPrice, mod:AhPrice) =====
;(function()
  local Cr = ns.Craft
  check(Cr.UpdateBlock == nil and Cr.DecorateRow == nil and mod.db.craftList == nil and mod.db.craftBlock == nil,
      "0.95: Anzeige und Einstellungen des Berufsfensters nicht mehr in Broker")
  market.items[3002] = { m = 30, md = 30, q = 10, n = 2, t = clock, nm = "Faden", ql = 1 }
  check(mod:AhPrice(3002) == 30 and mod:AhPrice(4242) == nil, "0.95: AhPrice = guenstigstes Angebot")
  local p, src, ah, vp = mod:BuyPrice(3002)
  check(p == 30 and src == "ah" and ah == 30 and vp == nil, "0.95: BuyPrice mit AH-Preis")
  -- Haendlerpreise: 1. beim Besuch gesehen, 2. letzter Kauf laut Ledger, 3. geschaetzt
  local VB = {}
  local ledger = { VendorBuy = function(_, id) return VB[id] end, StockOthers = function() return 0 end }
  local savedGM = Peon.GetModule
  Peon.GetModule = function(self, k) if k == "ledger" then return ledger end return savedGM(self, k) end
  mod.acc.merchant = nil
  GetMerchantNumItems = function() return 2 end
  GetMerchantItemID = function(i) return ({ 3002, 3100 })[i] end
  GetMerchantItemInfo = function(i)
    if i == 1 then return "Faden", nil, 50, 5, -1, true, true, false end
    return "Hemd", nil, 0, 1, -1, true, true, true
  end
  local keepGUID = UnitGUID
  UnitGUID = function(u) return u == "npc" and "Creature-0-1-2-3-4711-0001" or nil end
  mod.acc.vendors = nil
  ns.Vendors.lastAt = nil
  fire("MERCHANT_SHOW")
  UnitGUID = keepGUID
  local vend = mod.acc.vendors and mod.acc.vendors[4711]
  check(vend and vend.items[3002].p == 10 and vend.items[3100] and vend.items[3100].p == nil and mod.acc.merchant == nil,
    "N5: Haendlerpreise im gemeinsamen Speicher, Preis je Stueck, ohne Gold kein Preis")
  local vsrc, vwho
  p, src, ah, vp, vsrc, vwho = mod:BuyPrice(3002)
  check(p == 10 and src == "vendor" and ah == 30 and vp == 10 and vsrc == "seen", "Faden beim Haendler guenstiger: Quelle Haendler, gesehen")
  vend.items[3002].p = 40
  p, src = mod:BuyPrice(3002)
  check(p == 30 and src == "ah", "AH guenstiger: Quelle AH")
  mod.acc.vendors = nil
  mod.acc.merchant = { [3002] = { p = 12, t = clock, w = "Alt" } }
  p, src = mod:BuyPrice(3002)
  check(p == 12 and src == "vendor", "N5: frueherer Speicher wird noch gelesen")
  mod.acc.merchant = nil
  VB[3002] = 20
  p, src, ah, vp, vsrc = mod:BuyPrice(3002)
  check(p == 20 and src == "vendor" and vsrc == "ledger", "Haendlerpreis aus Ledger")
  VB[3002] = nil
  local savedVP = ns.VendorPrice
  ns.VendorPrice = function(id) if id == 3002 then return 2 end return savedVP(id) end
  check(ns.Merchant.Price(3002) == nil, "nicht in der Liste: keine Schaetzung")
  ns.Merchant.LIST[3002] = true
  p, src, ah, vp, vsrc = mod:BuyPrice(3002)
  check(p == 8 and src == "vendor" and vsrc == "est", "geschaetzt: 4x Ankaufspreis")
  ns.Merchant.LIST[3002] = nil
  ns.VendorPrice = savedVP
  GetMerchantNumItems, GetMerchantItemID, GetMerchantItemInfo = nil, nil, nil
  -- Zeile Herstellkosten im Tooltip kommt von Peon_Profession
  Peon.GetModule = function(self, k)
    if k == "profession" then return { CraftTooltip = function(_, id) return id == 3100 and "Material 70c" or nil end } end
    return savedGM(self, k)
  end
  check(Cr.TooltipText(3100) == "Material 70c" and Cr.TooltipText(3002) == nil, "0.95: Herstellkosten im Tooltip von Peon_Profession")
  Peon.GetModule = savedGM
  check(Cr.TooltipText(3100) == nil, "0.95: ohne Peon_Profession keine Zeile")
  SlashCmdList.PEON_BROKER("pruefen beruf")
  check(said("jetzt im Modul Peon Berufe"), "0.95: /broker pruefen beruf nennt den Umzug")
  market.items[3002] = nil
end)()

-- ===== ab 0.27: Absatz so lange wie die Preise, Verlauf fuer Ledger =====
;(function()
  local Sa = ns.Sales
  local today = D.Day(clock)
  local e = { m = 50, md = 60, q = 100, n = 5, t = clock }
  market.items[4711] = e
  -- Preise: 6 Tage, Median steigt
  local d = {}
  for k = 5, 0, -1 do d[#d+1] = { today - k, 50 * 2, (60 + (5 - k)) * 2, 100 * 2, 2 } end
  e.d = D.JoinDays(d)
  e.w = D.JoinDays({ { math.floor((today - 60) / 7), 40, 55, 90, 7 } })
  -- Absatz: alter Tag (20 Tage, laenger als 14) bleibt bei dataDays 30; sehr alter (40 Tage) wird Woche
  e.ab = Sa.JoinDays({ { today - 40, 10, 1, 0, 7200, 1 }, { today - 20, 24, 0, 0, 86400, 3 }, { today - 1, 12, 2, 0, 43200, 2 }, { today, 1, 0, 0, 600, 1 } })
  mod.db.dataDays = 30
  Sa.AddDay(e, clock, 2, 0, 0, 1800)
  local ab = Sa.ParseDays(e.ab)
  check(#ab == 3 and ab[1][1] == today - 20, "Absatz-Tageswerte bleiben so lange wie die Preise (30 statt 14 Tage)")
  local abw = Sa.ParseDays(e.abw)
  check(#abw == 1 and abw[1][1] == math.floor((today - 40) / 7) and abw[1][2] == 10, "aelterer Absatz als Wochensumme")
  check(Sa.Stats14(e, today) and Sa.Stats14(e, today).sold == 12 + 3, "14-Tage-Wert zaehlt weiter nur 14 Tage")
  local h = mod:History(4711)
  check(#h == 9, "Verlauf: 6 Tage + 1 Woche Preise + 1 Absatz-Tag + 1 Absatz-Woche (" .. #h .. ")")
  check(h[1].week and h[1].median == 55 and h[1].day < h[2].day, "aelteste zuerst, Woche mit Mittag-Tag")
  local last = h[#h]
  check(last.day == today and last.median == 65 and last.scans == 2, "heute: Median aus Tagessumme")
  check(last.sales == nil, "heute unter 1 Std. beobachtet: kein Absatz")
  local y = h[#h - 1]
  check(math.abs(y.sales - 24) < 0.01, "gestern: 12 in 12 Std. = 24 je Tag")
  check(last.low and last.high and last.low < 65 and last.high > 60, "ueblicher Bereich je Tag (" .. tostring(last.low) .. "-" .. tostring(last.high) .. ")")
  local third
  for _, r in ipairs(h) do if r.day == today - 3 then third = r end end
  check(third and third.low and third.high < last.high + 1, "Bereich nur aus Tagen bis dahin")
  check(#mod:History(999999) == 0 and #mod:History(nil) == 0, "unbekannter Gegenstand: leer")
  check(mod:DayOf(clock) == today, "DayOf wie Brokers Tage")
  market.items[4711] = nil
end)()

-- ===== 0.28: Aufraeumen und Datenmenge =====
;(function()
  local acc = { dataVersion = D.VERSION, posted = { 1 }, cancelled = { 1 }, bought = { 1 }, buyMode = "x", dealMaxAge = 5, depositCheck = {},
                radarLog = { 1 }, keyLog = { 1 }, showLog = { 1 }, aucLog = { 1 }, radarStats = {} }
  D.Migrate(acc)
  check(acc.posted == nil and acc.cancelled == nil and acc.bought == nil and acc.buyMode == nil and acc.dealMaxAge == nil
        and acc.depositCheck == nil and acc.radarLog == nil and acc.keyLog == nil and acc.showLog == nil and acc.aucLog == nil
        and acc.radarStats == nil, "0.28: Altlasten und Protokolle beim Start entfernt")
  local acc2 = { dataVersion = D.VERSION, debug = true, radarLog = { 1 }, keyLog = { 1 } }
  D.Migrate(acc2)
  check(acc2.radarLog and acc2.keyLog, "0.28: mit Debug bleiben die Protokolle")
  mod.db.debug = true
  ns.Radar.Log(1, "x", "y"); ns.Buy.ShowLog("t")
  check(PeonBrokerDB.radarLog and PeonBrokerDB.showLog, "0.28: mit Debug werden Protokolle geschrieben")
  mod.db.debug = false
  PeonBrokerDB.radarLog, PeonBrokerDB.showLog, PeonBrokerDB.debugLog = nil, nil, nil
  local S = ns.Sales
  local e = {}
  local h = math.floor(clock / 3600) * 3600
  S.AddRecent(e, h + 100, 60, 1, 0, 0); S.AddRecent(e, h + 700, 600, 2, 1, 0); S.AddRecent(e, h + 3700, 60, 1, 0, 0)
  local r = S.ParseRecent(e.ar)
  check(#r == 2 and r[1][1] == h + 700 and r[1][2] == 660 and r[1][3] == 3 and r[1][4] == 1 and r[2][1] == h + 3700,
        "0.28: Vergleiche derselben Stunde zu einem Eintrag zusammengefasst")
  local old = { as = { t = clock - 90000, s = "" }, ss = { t = clock - 100, s = "" }, acov = clock - 100,
                ar = ("%d:60:1:0:0;%d:60:1:0:0"):format(clock - 90000, clock - 100) }
  S.Prune(old, clock)
  check(old.as == nil and old.ss and #S.ParseRecent(old.ar) == 1 and old.acov, "0.28: Momentaufnahmen/Vergleiche ueber 24 Std. geloescht")
  local gone = { as = { t = clock - 90000 }, ar = ("%d:60:1:0:0"):format(clock - 90000), acov = 1 }
  S.Prune(gone, clock)
  check(gone.as == nil and gone.ar == nil and gone.acov == nil, "0.28: lange nicht gesehen: alles Alte weg")
end)()

-- ===== 0.28: Ausruestung mit Zusatz (Varianten nach vollem Namen) =====
;(function()
  local AH = C_AuctionHouse
  local savedMarkets, savedKeys, savedAt = Peon.CopyTable(PeonBrokerDB.markets), PeonBrokerDB.itemKeys, mod.acc.lastScanAt
  local savedListings, savedInfo, savedNI, savedII = LISTINGS, C_Item.GetItemInfo, AH.GetNumItemSearchResults, AH.GetItemSearchResultInfo
  local ADLER = "|cff1eff00|Hitem:11996::::::::20:1488:::1:12731::::::|h[Basaltring des Adlers]|h|r"
  local AFFE  = "|cff1eff00|Hitem:11996::::::::20:1488:::1:12740::::::|h[Basaltring des Affen]|h|r"
  LISTINGS = {
    { "Basaltring des Adlers", 11996, 1, 2, 59900, ADLER },
    { "Basaltring des Adlers", 11996, 1, 2, 61000, ADLER },
    { "Basaltring des Affen", 11996, 1, 2, 29900, AFFE },
    { "Gruener Hut", 5555, 1, 2, 800, "|cff1eff00|Hitem:5555::::::::20:1488:::::::::|h[Gruener Hut]|h|r" },
    { "Blauer Hut der Eule", 5556, 1, 3, 900, "|cff0070dd|Hitem:5556::::::::20:1488:::::::::|h[Blauer Hut der Eule]|h|r" },
  }
  C_Item.GetItemInfo = function(id)
    if id == 5555 then return "Gruener Hut" end
    if id == 5556 then return nil end            -- Grundname noch nicht geladen
    if id == 11996 then return "Basaltring" end
    return savedInfo(id)
  end
  local m = D.Market()
  m.items[11996] = { m = 1, md = 1, q = 9, n = 9, t = clock - 100 }   -- alter, gemischter Eintrag
  PeonBrokerDB.itemKeys = { [11996] = "34:14332" }
  mod.acc.lastScanAt = nil
  S.ahOpen = true
  S.Start()
  fire("REPLICATE_ITEM_LIST_UPDATE")
  while S.state do S.Step() end
  local kA, kB = "11996:Basaltring des Adlers", "11996:Basaltring des Affen"
  check(m.variants and m.variants[11996] and m.items[11996] == nil and PeonBrokerDB.itemKeys[11996] == nil,
        "0.28: Varianten erkannt, alter gemischter Eintrag und Schluessel geloescht")
  check(m.items[kA] and m.items[kA].m == 59900 and m.items[kA].q == 2 and m.items[kB] and m.items[kB].m == 29900,
        "0.28: Varianten getrennt gespeichert (Adler 2 Angebote ab 5g 99s, Affe 2g 99s)")
  check(m.items[kA].lk == ADLER and D.LinkFromKey(kA) == ADLER, "0.28: Link je Variante gemerkt")
  check(m.items[5555] and m.items[5555].m == 800 and m.items["5555:Gruener Hut"] == nil and not m.variants[5555],
        "0.28: gruener Gegenstand ohne Zusatz bleibt unter der Nummer")
  check(m.items[5556] and not m.variants[5556], "0.28: Grundname unbekannt - vorerst unter der Nummer")
  check(D.KeyFromLink(ADLER) == kA and D.KeyFromLink("|cff1eff00|Hitem:5555::::::::20:1488:::::::::|h[Gruener Hut]|h|r") == 5555,
        "0.28: Schluessel aus dem Link - Variante nach Name")
  local lines = hover(AFFE)
  check(#lines >= 1 and lines[1]:find("2g 84s", 1, true), "0.28: Tooltip zeigt die Werte der eigenen Variante")
  local iv = ns.ItemValue(11996, 1)
  check(iv and iv > 28000 and iv < 30000, "0.28: Wert fuer Ledger = guenstigste Variante")
  check(not ns.Buy.KnownKey(kA) and ns.Buy.KnownKey(5555), "0.28: Suchschluessel der Variante noch unbekannt")
  -- Suchergebnisse: nur die eigene Variante, Schluessel werden gelernt
  local RES = { { buyoutAmount = 59900, quantity = 1, itemLink = ADLER, itemKey = { itemID = 11996, itemLevel = 34, itemSuffix = 14331, battlePetSpeciesID = 0 } },
                { buyoutAmount = 29900, quantity = 1, itemLink = AFFE,  itemKey = { itemID = 11996, itemLevel = 34, itemSuffix = 14340, battlePetSpeciesID = 0 } } }
  AH.GetNumItemSearchResults = function() return #RES end
  AH.GetItemSearchResultInfo = function(_, i) return RES[i] end
  local rows = ns.Live.ReadItems({ itemID = 11996 }, kA)
  check(#rows == 1 and rows[1].price == 59900 and rows.other == 1, "0.28: Verkaufen liest nur die eigene Variante")
  local rows2 = ns.Buy.ReadItemRows({ itemID = 11996 }, kB)
  check(#rows2 == 1 and rows2[1].price == 29900 and PeonBrokerDB.itemKeys[kA] == "34:14331" and PeonBrokerDB.itemKeys[kB] == "34:14340",
        "0.28: Einkaufen/Radar lesen nur die eigene Variante und lernen beide Schluessel")
  local ik = ns.Buy.ItemKeyFor(kB)
  check(ns.Buy.KnownKey(kB) and ik.itemSuffix == 14340 and ik.itemLevel == 34, "0.28: Abfrage mit dem gelernten Schluessel")
  PeonBrokerDB.itemKeys = {}
  fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 11996, itemLevel = 34, itemSuffix = 14331 })
  check(PeonBrokerDB.itemKeys[kA] == "34:14331", "0.28: Schluessel auch aus Ereignissen gelernt (Stoebern im Blizzard-Fenster)")
  ns.Data.ApplyLive(kB, rows2, clock + 5)
  check(m.items[kB].m == 29900 and m.items[kB].lt == clock + 5, "0.28: Live-Ergebnis der Variante in die Datenbank")
  -- zuruecksetzen
  LISTINGS, C_Item.GetItemInfo, AH.GetNumItemSearchResults, AH.GetItemSearchResultInfo = savedListings, savedInfo, savedNI, savedII
  PeonBrokerDB.markets, PeonBrokerDB.itemKeys, mod.acc.lastScanAt = savedMarkets, savedKeys, savedAt
  D.vIndex = nil
end)()

-- ===== Maerkte verwalten =====
D.Market("Classic Beta PvP / Alliance", true).lastScan = clock - 3 * 86400
if mod.panel.scripts.OnShow then mod.panel.scripts.OnShow(mod.panel) end
local ml
for _, c in ipairs(mod.page.controls) do if c.list and c.list.columns[1].key == "name" and c.list.columns[2].key == "items" then ml = c.list end end
check(ml and #ml:GetItems() == 2, "Marktliste mit zwei Maerkten")
check(ml:GetItems()[1].name == "Classic Beta PvE / Horde (aktuell)" and ml:GetItems()[1].items == 4, "aktueller Markt oben und markiert")
ml:Select(ml:GetItems()[2])
for _, c in ipairs(mod.page.controls) do if c.button and c.button.text == "Ausgewählten Markt löschen" then c.button.scripts.OnClick() end end
check(popupShown and popupShown.data == "Classic Beta PvP / Alliance", "Loeschen fragt nach")
StaticPopupDialogs.PEON_BROKER_DELETE_MARKET.OnAccept(nil, popupShown.data)
check(D.Markets()["Classic Beta PvP / Alliance"] == nil and #ml:GetItems() == 1 and said("gelöscht"), "Markt geloescht, Liste aktualisiert")

-- 0.29: Schnittstelle fuer Ledger: alle Gegenstaende des Markts (nur Nummern)
;(function()
local mi = mod:MarketItems()
local nNum, nOther = 0, 0
for k, v in pairs(mi) do if type(k) == "number" and type(v) == "table" then nNum = nNum + 1 else nOther = nOther + 1 end end
local m0 = D.Market()
local expect = 0
for k in pairs(m0.items) do if type(k) == "number" then expect = expect + 1 end end
check(nNum == expect and nNum > 0 and nOther == 0, "0.29: MarketItems liefert " .. nNum .. " Gegenstaende")
local anyId = next(mi)
check(mi[anyId].min == m0.items[anyId].m and mi[anyId].qty == m0.items[anyId].q, "0.29: MarketItems mit Min und Menge")
end)()

-- Einkaufslisten ab 0.34: accountweit, Abgleich mit dem Manager, eigener Hoechstpreis
;(function()
  local B = Buy
  local brokerMod = Peon:GetModule("broker")
  PeonBrokerDB.lists, PeonBrokerDB.listsGone = nil, nil
  PeonBrokerCharDB.lists = { { name = "Alt", pct = 5, items = { [2770] = { wish = 3 } } }, { name = "Zweite", pct = 7, items = {} } }
  local lists = B.Lists()
  check(#lists == 2 and PeonBrokerCharDB.lists == nil and PeonBrokerDB.lists == lists, "0.34: Listen des Charakters einmalig uebernommen")
  check(type(lists[1].id) == "string" and lists[1].id ~= lists[2].id and lists[1].items[2770].wish == 3 and lists[1].items[2770].u == clock, "0.34: mit Nummer und Zeit")
  PeonBrokerCharDB.lists = { { name = "Alt", pct = 50, items = { [2770] = { wish = 99 }, [2589] = { wish = 1 } } } }
  B.Lists()
  check(#lists == 2 and lists[1].items[2770].wish == 3 and lists[1].items[2589].wish == 1 and lists[1].pct == 5, "0.34: gleicher Name vom zweiten Charakter: in die vorhandene Liste, Eigenes bleibt")
  PeonBrokerCharDB.listSel = 1

  -- Eigener Hoechstpreis geht vor
  local rows = B.ListRows()
  local function row(k) for _, r in ipairs(B.ListRows()) do if r.key == k then return r end end end
  lists[1].items[2770].max = 7777
  check(row(2770).limit == 7777, "0.34: eigener Hoechstpreis gilt")
  lists[1].items[2770].max = nil
  check(row(2770).limit ~= 7777, "0.34: ohne eigenen wieder der Wert der Liste")
  check(rows ~= nil, "0.34: Zeilen")

  -- Loeschmarke beim Entfernen und Loeschen
  local id = lists[1].id
  B.RemoveItem(lists[1], 2589)
  check(lists[1].items[2589] == nil and PeonBrokerDB.listsGone.items[id .. "|2589"] ~= nil, "0.34: Entfernen setzt eine Loeschmarke")
  local before = lists[2].u
  B.Touch(lists[2])
  check(lists[2].u == before + 1, "0.34: Aenderung in derselben Sekunde zaehlt trotzdem als neuer")

  -- Abgleich mit dem Manager
  local later = clock + 100
  local changed = brokerMod:MergeShop({
    lists = { { id = id, name = "Neu benannt", pct = 15, u = later, items = { [2770] = { wish = 8, max = 500, u = later }, ["15000:Name des Wolfs"] = { name = "Name des Wolfs", u = later } } },
              { id = "m1_1", name = "Vom Manager", pct = 10, u = later, items = {} } },
    gone = { lists = { [lists[2].id] = later }, items = {} },
  })
  check(changed and #lists == 2, "0.34: Mischen aendert etwas")
  check(lists[1].name == "Neu benannt" and lists[1].pct == 15 and lists[1].items[2770].max == 500, "0.34: neuere Angaben aus dem Manager gelten")
  check(lists[1].items["15000:Name des Wolfs"] ~= nil and lists[2].id == "m1_1", "0.34: neuer Eintrag und neue Liste, geloeschte Liste weg")
  check(brokerMod:MergeShop({ lists = { { id = id, name = "Alt", pct = 1, u = 5, items = {} } } }) == false and lists[1].name == "Neu benannt", "0.34: aelterer Stand aendert nichts")
  check(brokerMod:MergeShop({ gone = { items = { [id .. "|2770"] = later + 1 } } }) == true and lists[1].items[2770] == nil, "0.34: Loeschmarke aus dem Manager")
  check(brokerMod:MergeShop(nil) == false, "0.34: ohne Daten nichts")
  PeonBrokerDB.listsGone.items.alt = clock - 366 * 86400
  PeonBrokerDB.listsGone.items.jung = clock - 300 * 86400
  brokerMod:MergeShop({})
  check(PeonBrokerDB.listsGone.items.alt == nil, "0.34: alte Loeschmarken verfallen (ab 0.89 nach einem Jahr)")
  check(PeonBrokerDB.listsGone.items.jung ~= nil, "0.89: Loeschmarken unter einem Jahr bleiben")
  PeonBrokerDB.listsGone.items.jung = nil

  -- ab 0.89: Abgleich je Wert
  local it = lists[1].items[2589] or lists[1].items["15000:Name des Wolfs"]
  local L1 = lists[1]
  L1.name = "Eigener Name"; B.Touch(L1, "name")
  local tName = L1.t.name
  check(tName == L1.u and type(L1.t.pct) == "number" and L1.t.pct < tName, "0.89: eigene Aenderung setzt nur die Zeit dieses Werts")
  brokerMod:MergeShop({ lists = { { id = L1.id, name = "Manager-Name", pct = 33, u = tName + 5, t = { name = tName - 1, pct = tName + 5 }, items = {} } } })
  check(L1.name == "Eigener Name" and L1.pct == 33, "0.89: Name bleibt (eigener neuer), Rabatt kommt aus dem Manager")
end)()

-- Texte fuer Peon_Panel (ab 0.35)
check(mod.launcher and mod.launcher.defaultText == "age", "0.35: Starter ueber den Minimap-Button")
check(type(mod.launcher:GetText("age")) == "string", "0.35: Text Alter des Scans: " .. tostring(mod.launcher:GetText("age")))
check(type(mod.launcher:GetText("offers")) == "string", "0.35: Text Angebote: " .. tostring(mod.launcher:GetText("offers")))
do
  local refreshed = 0
  Peon.OnLauncherRefresh(function() refreshed = refreshed + 1 end)
  mod:Fire("SCAN_DONE", "Markt")
  check(refreshed == 1, "0.35: Scan aktualisiert den Text")
end

-- ===== Einkaufsliste wieder offen (0.49.0) =====
Win.Open("buy")
check(Win.current == "buy" and not Win.contents.buy.wipText and ns.Buy.itemList ~= nil, "0.49: Reiter Einkaufsliste mit Inhalt statt WIP-Hinweis")
Win.Refresh()

-- ===== Umbau U0 (0.41.0): eigene Reiter im Auktionshaus, "Blizzard pur" =====
;(function()
  local T = ns.AHTabs
  local calls = { select = 0, deselect = 0, update = 0, reload = 0, display = 0 }
  function PanelTemplates_SelectTab() calls.select = calls.select + 1 end
  function PanelTemplates_DeselectTab() calls.deselect = calls.deselect + 1 end
  function PanelTemplates_UpdateTabs() calls.update = calls.update + 1 end
  function PanelTemplates_TabResize() end
  function ReloadUI() calls.reload = calls.reload + 1 end
  local hookedSecure = {}
  function hooksecurefunc(t, name, fn)
    local orig = t[name]; hookedSecure[name] = true
    t[name] = function(...) local r = { orig(...) } fn(...) return unpack(r) end
  end
  local touched = {}
  function issecurevariable(t, k) if type(t) == "string" then return true end if touched[k] then return false, "Peon_Broker" end return true end
  -- Nachbau von Blizzards Auktionshaus: drei Reiter, SetDisplayMode
  -- Blizzards Reiter-Vorlage traegt jeden Reiter in die Liste "Tabs" des Elternrahmens ein (parentArray) und hat
  -- Seitenteile Left/Middle/Right und LeftActive/MiddleActive/RightActive (0.41.2)
  local origCreate = CreateFrame
  CreateFrame = function(kind, name, parent, template)
    local f = origCreate(kind, name, parent, template)
    if template == "AuctionHouseFrameTabTemplate" or template == "PanelTabButtonTemplate" then
      if parent then rawset(parent, "Tabs", rawget(parent, "Tabs") or {}); table.insert(parent.Tabs, f) end
      for _, n in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive" }) do
        rawset(f, n, origCreate("Frame")); f[n].shown = not n:find("Active")
      end
    end
    return f
  end
  local ah = CreateFrame("Frame", "AuctionHouseFrame")
  ah.BuyTab, ah.SellTab, ah.AuctionsTab = CreateFrame("Button"), CreateFrame("Button"), CreateFrame("Button")
  ah.Tabs = { ah.BuyTab, ah.SellTab, ah.AuctionsTab }
  ah.SetDisplayMode = function(self, m) calls.display = calls.display + 1; self.displayMode = m end
  ah.GetFrameLevel = function() return 5 end
  AuctionHouseFrameDisplayMode = { Buy = { "BrowseResultsFrame" } }
  local modesBefore = 0 for _ in pairs(AuctionHouseFrameDisplayMode) do modesBefore = modesBefore + 1 end

  mod.acc.ahPlain = false
  Win.frame:Hide()
  fire("AUCTION_HOUSE_SHOW")
  check(T.built and T.tabs.buy and T.tabs.watch and T.tabs.chances and T.tabs.focus and T.tabs.radar == nil and T.tabs.prices == nil and T.tabs.more and T.page,
    "N1/0.105: fuenf Reiter und Flaeche angelegt, Radar steht in Chancen")
  check(_G.PeonBrokerAHPlainButton == nil and T.BuildPlainButton == nil, "0.59.1: kein Knopf Blizzard pur mehr im Auktionshaus")
  check(T.page.points[1][5] == -22 and T.page.level == 370 and T.status.level == 376,
    "0.59.1: Flaeche ab der Titelleiste, unter dem runden Bild (Ebene 400)")
  local sbt = _G.PeonBrokerScanButton
  check(sbt.points[1][1] == "TOPRIGHT" and sbt.points[1][3] == "TOPRIGHT" and sbt.points[1][4] == -34 and sbt.status,
    "0.59.1: Scan-Knopf mit Text in der Titelleiste neben dem Schliessen-Knopf")
  check(T.status and T.back and not T.back.shown, "N1: Statuszeile und Knopf Zurueck im Auktionshaus, Zurueck anfangs verborgen")
  check(T.tabs.buy.points[1][2] == ah.AuctionsTab and T.tabs.focus.points[1][2] == T.tabs.buy and T.tabs.watch.points[1][2] == T.tabs.focus
    and T.tabs.chances.points[1][2] == T.tabs.watch and T.tabs.more.points[1][2] == T.tabs.chances
    and #ah.AuctionsTab.points == 0,
    "0.105: Reihenfolge Markt, Verkaufen, Auktionen, Einkaufen, Fokus, Beobachten, Chancen, Mehr, Blizzards Auktionen bleibt an seinem Platz")
  check(ah.BuyTab.text == ns.L.AHTAB_MARKET, "0.54: Kaufen heisst Markt")
  check(T.tabs.chances.text == "Chancen" and T.tabs.buy.text == ns.L.AHTAB_SHOP and T.tabs.focus.text == "Fokus"
    and T.tabs.watch.text == "Beobachten" and T.tabs.more.text == "Mehr", "0.82: Reiter heissen Einkaufen, Fokus, Beobachten, Chancen, Mehr")
  check(#ah.Tabs == 3 and ah.numTabs == nil, "U0: Blizzards Reiterliste bleibt unberuehrt")
  check(T.tabs.chances.parent == T.tabHolder and T.tabHolder.parent == ah and #T.tabHolder.Tabs == 5, "0.41.2: Reiter haengen am eigenen Rahmen, nicht an Blizzards Liste")
  check(T.tabs.chances.points[1][4] == T.TAB_GAP and T.TAB_GAP == -15, "0.56: Grundabstand wie Blizzard (-15)")
  ;(function()
    -- 0.56: sichtbaren Abstand von Blizzards Markt/Verkaufen messen und uebernehmen
    local function geo(fr, l, r, dl, dr)
      fr.GetLeft, fr.GetRight = function() return l end, function() return r end
      if dl then
        rawset(fr, "Left", rawget(fr, "Left") or origCreate("Frame")); rawset(fr, "Right", rawget(fr, "Right") or origCreate("Frame"))
        fr.Left.GetLeft = function() return l + dl end
        fr.Right.GetRight = function() return r + dr end
      end
    end
    geo(ah.BuyTab, 0, 100, -3, 7)       -- sichtbar bis 107
    geo(ah.SellTab, 85, 185, -3, 7)     -- sichtbar ab 82: Abstand -25
    geo(ah.AuctionsTab, 170, 270, -3, 7)
    geo(T.tabs.buy, 255, 355, -10, 7)   -- ragt links weiter hinaus
    geo(T.tabs.chances, 340, 440, -3, 7)
    check(T.AlignTabs() and T.tabGap == -25, "0.56: Abstand bei Blizzard gemessen")
    local shopOff = T.tabs.buy.points[#T.tabs.buy.points][4]
    local radarOff = T.tabs.chances.points[#T.tabs.chances.points][4]
    check(shopOff == -8 and radarOff == -15 and #ah.AuctionsTab.points == 0,
      "N1: Brokers Reiter so gesetzt, dass die Grafiken denselben Abstand haben, Blizzards Reiter unberuehrt")
    for _, t in ipairs({ ah.BuyTab, ah.SellTab, T.tabs.buy, T.tabs.chances, ah.AuctionsTab }) do t.GetLeft, t.GetRight = nil, nil end
  end)()
  local modesAfter = 0 for _ in pairs(AuctionHouseFrameDisplayMode) do modesAfter = modesAfter + 1 end
  check(modesAfter == modesBefore, "U0: keine eigenen Eintraege in AuctionHouseFrameDisplayMode")
  check(hookedSecure.SetDisplayMode, "U0: sicherer Anhang an SetDisplayMode")
  check(not T.page:IsShown(), "U0: Flaeche anfangs verborgen")
  -- ab 0.64.1: Favoriten-Stern (eigene Schicht HIGH) schien durch Brokers Flaeche
  local star1, star2 = W(), W()
  star1.alpha, star2.alpha = 1, 1
  local oldCBF, oldIBF = rawget(ah, "CommoditiesBuyFrame"), rawget(ah, "ItemBuyFrame")
  ah.CommoditiesBuyFrame = {}
  ah.CommoditiesBuyFrame.BuyDisplay = { ItemDisplay = { FavoriteButton = star1 } }
  ah.ItemBuyFrame = {}
  ah.ItemBuyFrame.ItemDisplay = { FavoriteButton = star2 }

  local dsel = calls.deselect
  T.tabs.chances.scripts.OnClick(T.tabs.chances)
  check(T.current == "chances" and T.page:IsShown() and T.host.chances == "ah" and Win.contents.chances.parent == T.page and Win.contents.chances.shown,
    "N1: Klick auf Radar zeigt die Seite Radar im Auktionshaus")
  check(not wf.shown and mod.db.windowTab == "chances", "N1: am Auktionator ist das Broker-Fenster zu, der Reiter wird gemerkt")
  check(calls.display == 0, "U0: Broker ruft SetDisplayMode nie selbst auf")
  check(star1.alpha == 0 and star2.alpha == 0, "0.64.1: Favoriten-Stern unsichtbar, solange Brokers Flaeche offen ist")
  check(calls.deselect - dsel >= 4 and calls.select >= 1, "U0: nur das Aussehen der Reiter wird umgestellt")
  local rt, st = T.tabs.chances, T.tabs.buy
  check(rt.LeftActive.shown and rt.MiddleActive.shown and not rt.Left.shown and rt.disabled, "0.41.2: Radar sieht gewaehlt aus und bleibt es")
  check(not st.LeftActive.shown and st.Left.shown, "0.41.2: Einkaufen sieht nicht gewaehlt aus")
  check(T.Probe(true).vars["Tabs (Inhalt)"] == "sauber", "0.41.2: Pruefung sieht keinen Broker-Reiter in Blizzards Liste")
  table.insert(ah.Tabs, rt)
  check(T.Probe(true).vars["Tabs (Inhalt)"]:find("Peon_Broker", 1, true), "0.41.2: Pruefung meldet Broker-Reiter in Blizzards Liste")
  table.remove(ah.Tabs)
  check(T.status.text.text and T.status.text.text:find("PvE", 1, true), "N1: Statuszeile im Auktionshaus: " .. tostring(T.status.text.text))

  ah:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)   -- wie Klick auf Blizzards Reiter Kaufen
  check(T.current == nil and not T.page:IsShown() and calls.update >= 1, "U0: Blizzard wechselt die Ansicht -> Flaeche weg, Blizzards Reiter wieder richtig")
  T.page.scripts.OnHide(T.page)   -- der Nachbau ruft OnHide nicht selbst
  check(star1.alpha == 1 and star2.alpha == 1 and next(T.dimmed) == nil, "0.64.1: Stern wieder sichtbar, wenn Brokers Flaeche zu ist")
  ah.CommoditiesBuyFrame, ah.ItemBuyFrame = oldCBF, oldIBF

  touched.displayMode = true
  local r = T.Probe(true)
  check(r.vars.displayMode:find("Peon_Broker", 1, true) and r.vars.selectedTab == "sauber" and mod.acc.ahProbe == r, "U0: Pruefung meldet beruehrte Werte und merkt das Ergebnis")
  touched.displayMode = nil
  SlashCmdList.PEON_BROKER("pruefen ah")
  check(said(ns.L.AH_PROBE_BLOCKED:format(0)), "U0: /broker pruefen ah")

  -- Blockierte Aktion: nur fuer Peon_Broker, Angebot einmal je Sitzung, nur bei offenem Auktionshaus
  popupShown = nil
  fire("ADDON_ACTION_BLOCKED", "AnderesAddon", "PlaceBid()")
  check(popupShown == nil and #T.blocked == 0, "U0: fremde Blockaden werden ignoriert")
  fire("ADDON_ACTION_BLOCKED", "Peon_Broker", "PlaceBid()")
  check(popupShown and popupShown.name == "PEON_BROKER_AH_PLAIN_ON" and popupShown.text:find("PlaceBid", 1, true), "U0: Blockade durch Broker bietet Blizzard pur an")
  check(mod.acc.ahBlocked and mod.acc.ahBlocked.fn == "PlaceBid()", "U0: Blockade gemerkt")
  popupShown = nil
  fire("ADDON_ACTION_FORBIDDEN", "Peon_Broker", "StartCommoditiesPurchase()")
  check(popupShown == nil and #T.blocked == 2, "U0: nur einmal je Sitzung angeboten, aber weiter gezaehlt")

  -- Blizzard pur einschalten (Rueckfrage annehmen)
  StaticPopupDialogs.PEON_BROKER_AH_PLAIN_ON.OnAccept()
  check(mod.acc.ahPlain == true and calls.reload == 1, "U0: Blizzard pur an, Oberflaeche wird neu geladen")
  check(not ns.AHTouch() and Win.SetAHMode == nil and ns.Buy.ShowInAH({ key = 2770 }) == false, "U0: bei Blizzard pur kein Zeigen in Blizzards Fenster (SetAHMode gibt es ab 0.64.1 nicht mehr)")
  local built = T.built; T.built = nil
  check(T.Build() == false, "U0: bei Blizzard pur keine Reiter")
  T.built = built
  mod:ResetDefaults()
  check(mod.acc.ahPlain == true, "U0: Standardwerte lassen Blizzard pur stehen")
  OldDefaults()
  SlashCmdList.PEON_BROKER("pur")
  check(popupShown and popupShown.name == "PEON_BROKER_AH_PLAIN_OFF", "U0: /broker pur fragt beim Zurueckschalten nach")
  StaticPopupDialogs.PEON_BROKER_AH_PLAIN_OFF.OnAccept()
  check(mod.acc.ahPlain == false and calls.reload == 2 and ns.AHTouch(), "U0: Broker im Auktionshaus wieder an")
  AuctionHouseFrame = {}
  CreateFrame = origCreate
end)()

-- ===== Umbau U7 (0.48.0): Radar im Auktionshaus =====
;(function()
  local T, R = ns.AHTabs, ns.Radar
  local origCreate = CreateFrame
  CreateFrame = function(kind, name, parent, template)
    local f = origCreate(kind, name, parent, template)
    if template == "AuctionHouseFrameTabTemplate" or template == "PanelTabButtonTemplate" then
      if parent then rawset(parent, "Tabs", rawget(parent, "Tabs") or {}); table.insert(parent.Tabs, f) end
      for _, n in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive", "Text" }) do rawset(f, n, origCreate("Frame")) end
    end
    return f
  end
  local origHook = rawget(_G, "hooksecurefunc")
  hooksecurefunc = function(t, name, fn) local o = t[name]; t[name] = function(...) local x = o(...) fn(...) return x end end
  local ah = CreateFrame("Frame", "AuctionHouseFrame")
  ah.BuyTab, ah.SellTab, ah.AuctionsTab = CreateFrame("Button"), CreateFrame("Button"), CreateFrame("Button")
  ah.Tabs = { ah.BuyTab, ah.SellTab, ah.AuctionsTab }
  local display = 0
  ah.SetDisplayMode = function() display = display + 1 end
  ah.GetFrameLevel = function() return 5 end
  T.built, T.tabs, T.page, T.current = nil, {}, nil, nil
  mod.acc.ahPlain = false
  fire("AUCTION_HOUSE_SHOW")
  check(T.built and T.tabs.chances, "U7: Reiter da")
  -- Radar im Auktionshaus oeffnen: die Flaeche des Broker-Fensters wandert in den Reiter
  if Win.frame then Win.frame:Hide() end
  T.tabs.chances.scripts.OnClick(T.tabs.chances)
  local c = Win.contents.chances
  check(c and c.parent == T.page and c.points[1][2] == ah and T.host.chances == "ah" and c.shown, "U7: Radar-Flaeche haengt im Reiter des Auktionshauses")
  check(c.points[1][4] == 14 and c.points[1][5] == -64 and c.points[2][4] == -14 and c.points[2][5] == 30,
    "N1: Seite sitzt im Auktionshaus wie im Broker-Fenster")
  check(R.Shown(), "U7: Radar gilt als offen")
  T.tabs.buy.scripts.OnClick(T.tabs.buy)
  check(Win.contents.buy.points[1][5] == -30, "N1: Seite mit oberer Leiste (Einkaufen) beginnt neben dem Bild")
  check(T.current == "buy" and Win.contents.buy.shown and Win.contents.buy.parent == T.page and not c.shown and ns.Buy.Shown(),
    "N1: Einkaufen offen (dieselbe Seite wie im Fenster), Radar-Flaeche versteckt")
  T.tabs.watch.scripts.OnClick(T.tabs.watch)
  check(T.current == "watch" and Win.contents.watch.parent == T.page and Win.contents.watch.points[1][5] == -64 and not Win.contents.buy.shown
    and ns.WatchPage.list, "0.82: Beobachten als Reiter im Auktionshaus, unter dem Bild")
  T.tabs.focus.scripts.OnClick(T.tabs.focus)
  check(T.current == "focus" and not Win.contents.focus.wipText and Win.contents.focus.shown and ns.Focus.Shown(), "N6: Fokus als Reiter im Auktionshaus")
  T.tabs.more.scripts.OnClick(T.tabs.more)
  check(T.current == "more" and Win.more and Win.more.current == mod.acc.moreTab and Win.more.contents[mod.acc.moreTab].shown, "N1: Mehr oeffnet mit dem zuletzt gewaehlten Unterpunkt")
  local moreNames = {}
  for _, b in ipairs(Win.more.tabs) do moreNames[#moreNames + 1] = b.text end
  check(table.concat(moreNames, ",") == "Gegenstand,Händler,Neutral,Datenlage", "0.82: Unterpunkte von Mehr: " .. table.concat(moreNames, ","))
  Win.more.tabs[4].scripts.OnClick(Win.more.tabs[4])
  check(Win.more.current == "sources" and mod.acc.moreTab == "sources" and Win.more.contents.sources.shown and not (Win.more.contents.vendors and Win.more.contents.vendors.shown),
    "N1: Datenlage gewaehlt und gemerkt")
  -- am Auktionator oeffnet /broker kein zweites Fenster, sondern den Reiter
  T.Close()
  Win.Open("chances")
  check(T.current == "chances" and not (Win.frame and Win.frame.shown), "N1: Fenster oeffnen am Auktionator waehlt den Reiter im Auktionshaus")
  Win.Toggle()
  check(T.current == nil and not Win.frame.shown, "N1: nochmal schliesst den Reiter")
  Win.Toggle()
  check(T.current == "chances", "N1: und oeffnet den zuletzt gewaehlten wieder")
  -- Spruenge (Go.lua): Im Markt zeigen schliesst Brokers Flaeche und zeigt den Gegenstand in Blizzards Kaufansicht
  do
    local shown
    local oldShow = ns.Buy.ShowInAH
    ns.Buy.ShowInAH = function(row) shown = row; return true end
    check(ns.Go.Market({ key = 2770, offer = 120, qty = 10 }) and T.current == nil and shown and shown.key == 2770 and shown.offer == 120,
      "N1: Im Markt zeigen aus dem Radar: Flaeche zu, Gegenstand in Blizzards Kaufansicht")
    check(ns.Go.back == "chances" and T.back.shown and T.back.text == "Zurück zu Chancen", "N1: Knopf Zurueck zu Radar")
    check(T.backAt == "title" and T.back.points[1][1] == "TOPLEFT" and T.back.points[1][4] == 62, "0.59.1: ohne Blizzards Zurueck links in der Titelleiste")
    local bb = CreateFrame("Button")
    bb.IsVisible = function() return true end
    ah.CommoditiesBuyFrame = { BackButton = bb }
    T.OnDisplayMode()   -- Blizzard hat die Kaufansicht geoeffnet
    check(T.backAt == "blizzard" and T.back.points[1][1] == "LEFT" and T.back.points[1][2] == bb and T.back.points[1][3] == "RIGHT",
      "0.59.1: in Blizzards Kaufansicht rechts neben Blizzards Zurueck")
    ah.CommoditiesBuyFrame = nil
    T.back.scripts.OnClick(T.back)
    check(T.current == "chances" and ns.Go.back == nil and not T.back.shown, "N1: Zurueck fuehrt zum Radar, Knopf weg")
    ns.Go.Item({ id = 2770, name = "Kupfererz" })
    check(T.current == "more" and ns.Item.key == 2770 and ns.Go.back == "chances" and T.back.shown, "N1: Sprung zum Gegenstand mit Zurueck")
    T.tabs.buy.scripts.OnClick(T.tabs.buy)
    check(ns.Go.back == nil and not T.back.shown, "N1: anderer Reiter beendet den Sprung")
    shown = nil
    check(ns.Go.Market({}) == false and shown == nil and said(ns.L.GO_NONE), "N1: ohne Gegenstand kein Sprung")
    ns.Buy.ShowInAH = oldShow
  end
  -- 0.103.1: "Im Markt zeigen" bei Varianten trifft genau die Zeile dieser Variante, nicht die erste mit derselben Nummer
  do
    local oldCAH = C_AuctionHouse
    local names = { [101] = "Pfadfinderhut der Beweglichkeit", [102] = "Pfadfinderhut des Banditen" }
    C_AuctionHouse = setmetatable({ GetItemKeyInfo = function(k) return { itemName = names[k.itemSuffix] } end },
      { __index = oldCAH })
    local rows = {}
    for _, suf in ipairs({ 101, 102 }) do rows[#rows + 1] = { rowData = { itemKey = { itemID = 9999, itemLevel = 29, itemSuffix = suf } } } end
    local box = { ForEachFrame = function(self, fn) for _, r in ipairs(rows) do fn(r) end end }
    local oldAHF = rawget(_G, "AuctionHouseFrame")
    AuctionHouseFrame = { BrowseResultsFrame = { ItemList = { ScrollBox = box } } }
    check(ns.Go.BrowseRow("9999:Pfadfinderhut des Banditen") == rows[2], "0.103.1: Variante findet ihre eigene Zeile")
    check(ns.Go.BrowseRow("9999:Pfadfinderhut des Baeren") == nil, "0.103.1: fehlende Variante trifft keine fremde Zeile")
    check(ns.Go.BrowseRow(9999) == rows[1], "0.103.1: ohne Variante zaehlt weiter die Nummer")
    C_AuctionHouse = setmetatable({ GetItemKeyInfo = function() return nil end }, { __index = oldCAH })
    check(ns.Go.BrowseRow("9999:Pfadfinderhut des Banditen") == nil, "0.103.1: ohne Namen und ohne gelernten Zusatz keine Zeile")
    ns.Buy.LearnKey("9999:Pfadfinderhut des Banditen", { itemLevel = 29, itemSuffix = 102 })
    check(ns.Go.BrowseRow("9999:Pfadfinderhut des Banditen") == rows[2], "0.103.1: ohne Namen hilft der gelernte Zusatz")
    ns.Buy.ForgetKey("9999:Pfadfinderhut des Banditen")
    AuctionHouseFrame = oldAHF
    C_AuctionHouse = oldCAH
  end
  T.tabs.chances.scripts.OnClick(T.tabs.chances)
  check(c.shown and not Win.contents.buy.shown, "0.54: zurueck zum Radar, Einkaufen versteckt")
  check(ns.Buy.ShowInAH({ key = 2770 }) == false and display == 0, "U7: im Reiter schaltet Broker Blizzards Ansicht nicht um")
  -- Blizzard wechselt die Ansicht: Reiter zu, Radar haelt an
  local halted = 0
  local oldHalt = R.Halt
  R.Halt = function(...) halted = halted + 1; return oldHalt(...) end
  ah:SetDisplayMode("Buy")
  check(T.current == nil and not R.Shown() and halted >= 1, "U7: anderer Reiter -> Radar haelt an")
  -- Unterwegs holt das Broker-Fenster die Flaeche zurueck
  T.tabs.chances.scripts.OnClick(T.tabs.chances)
  ah.GetLeft, ah.GetTop = function() return 40.4 end, function() return 700.2 end
  ah.scripts.OnHide(ah)
  check(T.current == nil and mod.acc.ahPos and mod.acc.ahPos.x == 40 and mod.acc.ahPos.y == 700, "N1: Auktionshaus zu: Reiter zu, Stelle gemerkt")
  fire("AUCTION_HOUSE_CLOSED")
  local keepPos = mod.db.windowPos
  mod.db.windowPos = {}
  Win.Open("chances")
  check(T.host.chances == "window" and c.parent == Win.frame and c.points[1][2] == Win.frame and T.current == nil and R.Shown(), "U7: Broker-Fenster holt das Radar zurueck")
  check(Win.frame.points[1][1] == "TOPLEFT" and Win.frame.points[1][4] == 40 and Win.frame.points[1][5] == 700, "N1: Fenster oeffnet dort, wo das Auktionshaus stand")
  check(Win.status.text.text:find(ns.L.ST_NOT_LIVE, 1, true), "N1: unterwegs steht in der Statuszeile nicht live")
  mod.db.windowPos = keepPos
  ns.Go.Item({ id = 2770, name = "Kupfererz" })
  check((Win.current == "more" and Win.more.current == "prices") and Win.back.shown and Win.back.text == "Zurück zu Chancen", "N1: Sprung im Fenster mit Zurueck")
  check(ns.Go.Market({ key = 2589 }) and Win.current == "browse" and #ns.Market.list.items == 1
    and ns.Market.list.items[1].key == 2589 and ns.Go.back == "prices" and Win.back.text == "Zurück zu Gegenstand", "N3: Im Markt zeigen fuehrt unterwegs zur Marktseite mit genau diesem Gegenstand")
  Win.back.scripts.OnClick(Win.back)
  check((Win.current == "more" and Win.more.current == "prices") and not Win.back.shown, "N1: Zurueck im Fenster (ein Schritt)")
  Win.Select("chances")
  -- offenes Fenster wandert beim Oeffnen des Auktionshauses in den Reiter
  fire("AUCTION_HOUSE_SHOW")
  check(not Win.frame.shown and T.current == "chances" and T.host.chances == "ah", "N1: Auktionshaus oeffnet: Fenster zu, Radar als Reiter")
  T.Close()
  R.Halt = oldHalt
  -- Zahl am Reiter nach einem Komplettscan, blinkt bis zum Oeffnen (ab 0.105 am Reiter Chancen, Radar zaehlt mit)
  local oldCount, oldLoad = R.CountHits, R.LoadFromScan
  local Chb = ns.Chances
  local oldBC = Chb.BadgeCount
  Chb.BadgeCount = function() return 3 end
  R.CountHits = function() return 3 end
  R.LoadFromScan = function() end
  mod.db.badgeChances = "all"
  mod:Fire("SCAN_DONE", "Markt")
  local wWith = T.tabs.chances.w
  local cp = T.tabs.chances.corner.points and T.tabs.chances.corner.points[1]
  check(cp and cp[1] == "CENTER" and cp[2] == T.tabs.chances and cp[3] == "BOTTOMRIGHT", "0.96.2: Zahl auf der Ecke unten rechts")
  local wt
  for _, b in ipairs(ns.Window.tabs or {}) do if b.key == "chances" then wt = b end end
  check(wt and wt.corner and wt.corner.shown and wt.corner.text.text == "3" and not (wt.badge and wt.badge.shown), "0.96.2: im Broker-Fenster ebenso")
  check(T.badges.chances and T.badges.chances.n == 3 and T.badges.chances.blink and T.tabs.chances.corner.shown and T.tabs.chances.corner.text.text == "3",
    "U7/0.105: Chancen mit roter 3 nach dem Scan, blinkt")
  check(T.tabs.chances.scripts.OnUpdate ~= nil, "U7: Reiter blinkt")
  T.tabs.chances.scripts.OnClick(T.tabs.chances)
  check(T.badges.chances == nil and not T.tabs.chances.corner.shown and T.tabs.chances.scripts.OnUpdate == nil and not Chb.blink, "U7: geoeffnet -> Zahl und Blinken weg")
  T.SetBadge("chances", nil)
  check(T.tabs.chances.w == wWith, "0.96.2: Reiter mit und ohne Zahl gleich breit: " .. tostring(wWith) .. " " .. tostring(T.tabs.chances.w))
  ah:SetDisplayMode("Buy")
  R.CountHits = function() return 0 end
  Chb.BadgeCount = function() return 0 end
  mod:Fire("SCAN_DONE", "Markt")
  check(T.badges.chances == nil, "U7: ohne Treffer keine Zahl")
  -- 0.97: je Reiter einstellbar, ob und wann die Zahl kommt
  mod.db.badgeChances = nil
  check(T.BADGE_MODES.radar == nil and T.BadgeMode("chances") == "off" and T.BadgeMode("buy") == "buypart", "0.97: Standard je Reiter (ab 0.105 ohne Radar)")
  mod.db.badgeChances = "quatsch"
  check(T.BadgeMode("chances") == "off", "0.97: unbekannter Wert -> Standard")
  R.CountHits = function() return 2 end
  Chb.BadgeCount = function() return 2 end
  mod.db.badgeChances = "off"
  mod:Fire("SCAN_DONE", "Markt")
  check(T.badges.chances == nil and not T.tabs.chances.corner.shown, "0.97/0.105: Chancen aus, auch nach dem Scan keine Zahl")
  Chb.BadgeCount, Chb.blink = oldBC, false
  -- Chancen: Standard aus, ok = bestaetigt, all = alle ohne weg, Muster nur im Zeitfenster
  local Ch = ns.Chances
  local oldRows = Ch.Rows
  Ch.Rows = function() return {
    { state = "ok", mk = "s", x = {} }, { state = "new", mk = "l", x = {} }, { state = "gone", mk = "s", x = {} },
    { state = "ok", mk = "m", x = { buyWin = { mask = 127, slot = 1 } }, inWindow = false },
    { state = "new", mk = "m", x = { buyWin = { mask = 127, slot = 1 } }, inWindow = true } } end
  local wasCur = T.current
  T.current = nil
  Ch.UpdateBadge()
  check(T.badges.chances == nil, "0.97: Chancen ohne Zahl (Standard aus)")
  mod.db.badgeChances = "all"
  mod:Fire("CHANGED", "badgeChances")
  check(T.badges.chances and T.badges.chances.n == 3 and T.tabs.chances.corner.shown, "0.97: alle Chancen: 3")
  mod.db.badgeChances = "ok"
  Ch.UpdateBadge()
  check(T.badges.chances and T.badges.chances.n == 1, "0.97: nur bestaetigte: 1")
  mod.db.badgeChances = "off"
  mod:Fire("CHANGED", "badgeChances")
  check(T.badges.chances == nil and not T.tabs.chances.corner.shown, "0.97: Chancen wieder aus")
  Ch.Rows, T.current = oldRows, wasCur
  R.CountHits, R.LoadFromScan = oldCount, oldLoad
  -- Tastenbelegungen
  check(type(PeonBroker_RadarBuy) == "function" and type(PeonBroker_RadarNext) == "function", "U7: Tastenbelegungen Kaufen und Naechster")
  do   -- N6: naechste Chance nach Gewinn, am Ende wieder von vorn
    local keepE, keepV = R.entries, R.Visible
    R.entries = { [1] = { key = 1, showGain = 30 }, [2] = { key = 2, showGain = 20, cant = true }, [3] = { key = 3, showGain = 10 } }
    R.Visible = function() return true end
    check(R.NextChance(nil).key == 1 and R.NextChance(1).key == 3 and R.NextChance(3).key == 1, "N6: naechste Chance ueberspringt, was sich nicht lohnt, und beginnt von vorn")
    R.entries, R.Visible = keepE, keepV
  end
  hooksecurefunc = origHook
  CreateFrame = origCreate
  AuctionHouseFrame = {}
  T.built, T.current = nil, nil
end)()

-- ===== Umbau U8 (0.49.0): Einkaufslisten und Beobachtung =====
;(function()
  local Wt, B = ns.Watch, ns.Buy
  local mk = D.Market()
  local e = mk.items[2770]
  PeonBrokerDB.watch, PeonBrokerDB.watchGone = nil, nil
  check(not Wt.Is(2770) and Wt.Add(2770, { name = "Kupfererz" }) and Wt.Is(2770), "U8: Gegenstand beobachten")
  check(Wt.Limit(2770) == nil and Wt.Check() == 0, "U8: ohne Grenze kein Alarm")
  local sounds = 0
  local oldPlay = ns.Radar.PlayAlert
  ns.Radar.PlayAlert = function() sounds = sounds + 1 end
  mod.db.radarSound = true
  Wt.SetLimit(2770, "abs", e.m)
  check(PeonBrokerDB.watch[2770].hit and said("Preisalarm: Kupfererz") and sounds == 1, "U8: Preis auf der Grenze -> Alarm mit Ton")
  check(Wt.Check() == 0 and sounds == 1, "U8: Alarm nur einmal")
  Wt.SetLimit(2770, "abs", e.m - 1)
  check(not PeonBrokerDB.watch[2770].hit, "U8: Preis ueber der Grenze -> Alarm wieder scharf")
  Wt.SetLimit(2770, "abs", e.m + 1)
  check(sounds == 2, "U8: danach wieder ein Alarm")
  Wt.SetLimit(2770, "pct", 20)
  check(Wt.Limit(2770) == D.MaxBuyPrice(e, 20) and Wt.LimitText(2770):find("20", 1, true), "U8: Grenze in Prozent unter dem Vergleichspreis")
  -- ab 0.91 (Fehlerberichte 20 und 21): Ton und Chat je Richtung, Ton je Gegenstand
  local played
  ns.Radar.PlayAlert = function(k) sounds = sounds + 1; played = k end
  check(Wt.Sound(2770, "Down") == "raid" and Wt.Sound(2770, "Up") == "raid", "0.91: Ton wie eingestellt (Vorgabe Schlachtzugswarnung)")
  mod.db.watchSoundDown = "alarm"
  Wt.SetLimit(2770, "abs", e.m - 1); Wt.SetLimit(2770, "abs", e.m)
  check(played == "alarm" and said("Preisalarm: Kupfererz"), "0.91: eingestellter Ton fuer Kaufen bis")
  Wt.SetSound(2770, "Down", "off")
  local s0, n0 = sounds, #out
  mod.db.watchChatDown = false
  Wt.SetLimit(2770, "abs", e.m - 1); Wt.SetLimit(2770, "abs", e.m)
  check(PeonBrokerDB.watch[2770].hit and sounds == s0 and #out == n0, "0.91: Ton je Gegenstand aus, Chat aus: still")
  Wt.SetSound(2770, "Down", "tell")
  n0 = #out
  Wt.SetLimit(2770, "abs", e.m - 1); Wt.SetLimit(2770, "abs", e.m)
  check(played == "tell" and #out == n0, "0.91: eigener Ton je Gegenstand, ohne Chat")
  Wt.SetSound(2770, "Down", nil)
  mod.db.watchSoundDown, mod.db.watchChatDown = "raid", true
  -- ab 0.92: Warnung je Gegenstand aus (Symbol in der Liste)
  check(Wt.ToggleMute(2770, "Down") == true and Wt.Muted(2770, "Down") and not Wt.Muted(2770, "Up"), "0.92: Warnung bei Kaufen bis aus, Zielpreis bleibt an")
  s0, n0 = sounds, #out
  Wt.SetLimit(2770, "abs", e.m - 1); Wt.SetLimit(2770, "abs", e.m)
  check(PeonBrokerDB.watch[2770].hit and sounds == s0 and #out == n0, "0.92: ausgeschaltet: weder Ton noch Chat")
  check(Wt.ToggleMute(2770, "Down") == false and not Wt.Muted(2770, "Down") and PeonBrokerDB.watch[2770].muteDown == nil, "0.92: wieder an")
  check(Wt.Sound(2770, "Down") == "raid", "0.91: zurueck auf wie eingestellt")
  -- Menue: Ton je Gegenstand, Fenster Einstellungen Beobachten
  local S = ns.Settings
  S.Toggle("watch")
  local sf = S.frames.watch
  local choices = 0
  for _, c in ipairs(sf and sf.controls or {}) do if c.kind == "choice" then choices = choices + 1 end end
  check(sf and sf:IsShown() and #sf.controls == 4 and choices == 2, "0.91: Fenster Einstellungen Beobachten mit zwei Tonwahlen und zwei Haken")
  S.Set("watch", "watchSoundUp", "ready"); S.Apply("watch")
  check(mod.db.watchSoundUp == "ready" and not sf:IsShown(), "0.91: OK uebernimmt den Ton")
  mod.db.watchSoundUp = "raid"
  ns.Radar.PlayAlert = oldPlay
  -- ab 0.82: Beobachtung im eigenen Reiter (WatchPage.lua), nicht mehr als Liste in Einkaufen
  mod.char.listSel = "watch"
  local cur = B.CurrentList()
  check(not (cur and cur.watch), "0.82: Einkaufen kennt die Beobachtung nicht mehr als Liste")
  local wrow
  for _, r in ipairs(ns.WatchPage.Rows()) do if r.key == 2770 then wrow = r end end
  check(wrow and wrow.limit == Wt.Limit(2770), "0.82: Beobachten zeigt Kaufen bis")
  B.DeleteList("watch")
  check(Wt.Is(2770), "U8: Beobachtung laesst sich nicht als Liste loeschen")
  mod.char.listSel = 1
  -- Rat
  check(B.Advice({ need = 0 }) == "done" and B.Advice({}) == "check" and B.Advice({ cheapest = 5, hits = 0 }) == "expensive"
    and B.Advice({ cheapest = 5, hits = 3, need = 5 }) == "part" and B.Advice({ cheapest = 5, hits = 6, need = 5 }) == "buy", "U8: Rat Kaufen, Teilweise, Zu teuer, Pruefen, erledigt")
  -- Zahl am Reiter (ohne Blinken)
  local badge
  local oldT = ns.AHTabs.SetBadge
  ns.AHTabs.SetBadge = function(key, n, blink) badge = { key = key, n = n, blink = blink } end
  local wasBuilt = ns.AHTabs.built
  ns.AHTabs.built = true
  local oldCount = B.CountBuyable
  B.CountBuyable = function() return 5 end
  B.UpdateBadge()
  check(badge and badge.key == "buy" and badge.n == 5 and not badge.blink, "U8: Einkaufen (5) ohne Blinken")
  local onlyArg
  B.CountBuyable = function(only) onlyArg = only; return 2 end
  mod.db.badgeBuy = "buy"
  B.UpdateBadge()
  check(badge.n == 2 and onlyArg == true, "0.97: Einkaufen nur Kaufen")
  mod.db.badgeBuy = "off"
  B.UpdateBadge()
  check(badge.n == nil, "0.97: Einkaufen ohne Zahl")
  mod.db.badgeBuy = "buypart"
  B.CountBuyable = oldCount
  -- Beobachten: Richtung waehlbar
  local WP = ns.WatchPage
  local oldWRows = WP.Rows
  WP.Rows = function() return { { advice = "buy" }, { advice = "sell" }, { advice = "sell" }, {} } end
  check(WP.Count() == 3 and WP.Count("buy") == 1 and WP.Count("sell") == 2, "0.97: Beobachten zaehlt je Richtung")
  mod.db.badgeWatch = "sell"
  WP.UpdateBadge()
  check(badge.key == "watch" and badge.n == 2, "0.97: Beobachten nur Zielpreis")
  mod.db.badgeWatch = "off"
  WP.UpdateBadge()
  check(badge.key == "watch" and badge.n == nil, "0.97: Beobachten ohne Zahl")
  mod.db.badgeWatch = "both"
  WP.Rows = oldWRows
  check(type(B.CountBuyable()) == "number", "U8: Zaehlung ueber alle Listen und Beobachtung")
  ns.AHTabs.SetBadge, ns.AHTabs.built = oldT, wasBuilt
  -- Gegenstandsmenue und Tooltip-Zeichen
  check(ns.Tooltip.OnShopList(2770), "U8: beobachtete Gegenstaende bekommen das Zeichen in Zeile 1")
  local items = {}
  local root = { CreateButton = function(_, t, fn) local c = { text = t, fn = fn, CreateButton = function(self2, t2, f2) items[#items + 1] = t2; return {} end }; items[#items + 1] = t; return c end }
  Wt.AddMenu(root, { name = "Kupfererz" }, 2770)
  if ns.Data.IsCommodity(2770) then
    check(items[1] == "[x] " .. ns.L.MENU_WATCH_BUYOUT and items[2] == "[ ] " .. ns.L.MENU_WATCH_QUICK and items[3] == "[ ] " .. ns.L.MENU_WATCH_TRADE and items[4] == ns.L.MENU_WATCH_LIMIT,
      "U8/0.120: Menue mit Haken Aufkauf und Schnellkauf, dann Preisgrenze: " .. tostring(items[1]) .. " / " .. tostring(items[2]))
  else
    check(items[1] == ns.L.MENU_UNWATCH and items[2] == "[ ] " .. ns.L.MENU_WATCH_TRADE and items[3] == ns.L.MENU_WATCH_LIMIT, "U8: Menue Nicht mehr beobachten, Markttausch (ab 0.128) und Preisgrenze")
  end
  check(Wt.Toggle(2770) == false and not Wt.Is(2770) and PeonBrokerDB.watchGone[2770], "U8: Beobachtung entfernen mit Loeschmarke")
  -- Live-Abfrage prueft den Alarm
  Wt.Add(2770, { name = "Kupfererz" }); Wt.SetLimit(2770, "abs", 1)
  local checked = 0
  local oldCheck = Wt.Check
  Wt.Check = function(keys) checked = checked + 1; return 0 end
  D.ApplyLive(2770, { { price = 100, qty = 1 } }, clock)
  check(checked == 1, "U8: Live-Abfrage prueft den Alarm des Gegenstands")
  Wt.Check = oldCheck
  Wt.Remove(2770)
  -- Abgleich mit dem Manager (ueber Peon_Bridge 0.9.0)
  local gu = PeonBrokerDB.watchGone[2770]
  check(mod:MergeWatch({ items = { ["2770"] = gu - 5 }, gone = {} }) == false and not Wt.Is(2770), "U8: aeltere Aenderung aus dem Manager bringt Geloeschtes nicht zurueck")
  check(mod:MergeWatch({ items = { ["2770"] = gu + 5, ["2589"] = 10 }, gone = {} }) and Wt.Is(2770) and Wt.Is(2589), "U8: neuere Aenderung aus dem Manager gewinnt, Schluessel als Zahl")
  check(mod:MergeWatch({ items = {}, gone = { ["2589"] = 20 } }) and not Wt.Is(2589) and PeonBrokerDB.watchGone[2589] == 20, "U8: Loeschung aus dem Manager")
  Wt.Remove(2770)
end)()

-- ===== Umbau U9 (0.50.0): Blizzards Reiter Auktionen =====
;(function()
  local X, A = ns.AuctionsAH, ns.Auctions
  local L = ns.L
  -- Status je Auktion
  check(select(1, X.Status({ sold = true })) == "sold", "U9: verkauft")
  local k, t = X.Status({ status = "under", other = 100 })
  check(k == "under" and plain(t):find("unterboten", 1, true), "U9: unterboten mit Preis")
  check(X.Status({ status = "equal" }) == "equal", "U9: gleichauf")
  local oldEval = ns.Data.Evaluate
  ns.Data.Evaluate = function() return { band = { low = 90, high = 110, rw = 100 } } end
  check(X.Status({ status = "best", key = 2770, itemID = 2770, price = 200 }) == "high", "U9: ueber dem ueblichen Bereich -> zu teuer")
  check(X.Status({ status = "best", key = 2770, itemID = 2770, price = 100 }) == "best", "U9: sonst Guenstigstes")
  ns.Data.Evaluate = oldEval
  local n, under, value = X.Summary({ { status = "under", price = 10, qty = 2 }, { status = "best", price = 5 }, { sold = true, price = 99 } })
  check(n == 2 and under == 1 and value == 25, "U9: Kopfzeile zaehlt laufende, unterbotene und den Wert")
  -- Nachbau: Auktionshaus mit Liste der eigenen Auktionen
  local ah = CreateFrame("Frame", "AuctionHouseFrame")
  local af = CreateFrame("Frame"); af.shown = true
  local list = CreateFrame("Frame")
  local rowA, rowB = CreateFrame("Button"), CreateFrame("Button")
  rowA.rowData = { auctionID = 11 }; rowB.rowData = { auctionID = 12 }
  rowA.cells = { CreateFrame("Frame") }
  list.ScrollBox = { ForEachFrame = function(_, fn) fn(rowA); fn(rowB) end }
  af.AllAuctionsList = list
  ah.AuctionsFrame = af
  X.header = nil
  check(X.Build() and X.header and X.header.check, "U9: Kopfzeile mit Knopf Pruefen")
  A.rows = { { id = 11, key = 2770, itemID = 2770, status = "under", other = 50, price = 60 }, { id = 12, key = 2589, itemID = 2589, sold = true } }
  X.Update()
  check(plain(X.labels[rowA].text):find("unterboten", 1, true) and plain(X.labels[rowB].text) == L.AUCX_SOLD, "U9: Status je Zeile ueber auctionID")
  check(X.labels[rowA].points[1][2] == rowA.cells[1], "U9: Status rechts in der Gegenstandsspalte")
  -- 0.57: Status gehoert zum Gegenstand der Zeile, fehlende Auktion fuehrt zum Neulesen
  rowA.rowData = { auctionID = 11, itemKey = { itemID = 2589 } }   -- Zeile zeigt etwas anderes als Auktion 11
  local reads, oldRead = 0, A.Read
  A.Read = function() reads = reads + 1 end
  X.lastReread = nil
  X.Update()
  check(X.labels[rowA].text == "" and reads == 1, "0.57: falscher Gegenstand: kein Status, Liste neu gelesen")
  X.Update()
  check(reads == 1, "0.57: nicht bei jedem Takt neu lesen")
  A.Read = oldRead
  rowA.rowData = { auctionID = 11 }
  check(plain(X.header.text.text):find("1 laufen", 1, true), "U9: Kopfzeile: " .. plain(X.header.text.text))
  check(rawget(rowA, "peon") == nil and rowA.rowData.status == nil, "U9: nichts in Blizzards Zeilen geschrieben")
  local started = 0
  local oldStart = A.StartLive
  A.StartLive = function() started = started + 1 end
  X.header.check.scripts.OnClick(X.header.check)
  check(started == 1, "U9: Pruefen startet die Live-Pruefung")
  A.StartLive = oldStart
  mod.acc.ahPlain = true
  X.labels[rowA]:SetText("x")
  X.Update()
  check(X.labels[rowA].text == "x", "U9: Blizzard pur -> keine Aenderung")
  mod.acc.ahPlain = false
  A.rows = nil
  X.header = nil
  AuctionHouseFrame = {}
end)()

-- ===== Umbau U10 (0.51.0): Broker-Fenster neu =====
;(function()
  local G = ns.Pages
  check(G.MarketLabel("CAMWOW EU4 Realm 3 PvE / Alliance") == "PvE Allianz" and G.MarketLabel("Classic Beta PvE / Neutral") == "PvE Neutral", "U10: Marktname kurz")
  -- Markt: Datenstand und Vergleich
  local hm = D.Markets()["Classic Beta PvE / Horde"]
  local he = hm.items[2770]
  local nm = D.Market("Classic Beta PvE / Neutral", true)
  nm.lastScan = clock
  nm.items[2770] = { m = he.m * 2, md = he.md, q = 5, n = 1, t = clock, nm = "Kupfererz" }
  nm.items[2589] = { m = 1, md = 1, q = 5, n = 1, t = clock }
  local rows = G.CompareRows(20, false)
  local cu
  for _, r in ipairs(rows) do if r.key == 2770 then cu = r end end
  check(cu and cu.pct == 70 and cu.better == "neutral", "U10: Vergleich nach Gebuehr (Neutral angenommen 15 %), neutral besser")
  check(#G.CompareRows(500, false) == 0, "U10: Mindestabstand filtert")
  -- ab 0.127.0: Suche zeigt auch Gegenstaende ohne Unterschied und aus nur einem Markt
  nm.items[9999] = { m = 500, md = 500, q = 1, n = 1, t = clock, nm = "Nur Neutral Stein" }
  local found = G.CompareRows(500, false, "nur neutral")
  check(#found == 1 and found[1].key == 9999 and found[1].home == nil and found[1].pct == nil, "M1: Suche findet Gegenstand nur in Neutral")
  check(#G.CompareRows(500, false, "kupfer") == 1, "M1: Suche ohne Mindestabstand")
  check(#G.CompareRows(0, false, "gibtsnicht") == 0, "M1: Suche ohne Treffer leer")
  local p1, b1 = G.Spread(100, 100, 0.05, 0.15)
  local p2, b2 = G.Spread(300, 100, 0.05, 0.15)
  check(p1 < 0 and b1 == nil and b2 == "home" and p2 == 185, "M1: Richtung und Unterschied nach Gebuehr")
  nm.items[9999] = nil
  Win.Select("market")
  check(G.stand and plain(G.stand.text):find("PvE Horde", 1, true) and plain(G.stand.text):find("PvE Neutral", 1, true), "U10: Datenstand je Markt")
  check(#G.compare:GetItems() >= 1, "U10: Liste Vergleich gefuellt")
  D.DeleteMarket("Classic Beta PvE / Neutral")
  Win.Refresh()
  check(#G.compare:GetItems() == 0, "U10: ohne neutralen Markt leer")
  check(Win.pages.watch and Win.pages.watch.build == ns.WatchPage.Build and G.BuildWatch == nil, "0.82: Beobachten wieder eigene Seite (WatchPage.lua)")
  check(G.stockCheck.template == "UICheckButtonTemplate" and G.compare.list and G.minBox.text == "20", "N5: Neutral mit Peon.UI")
  -- Auktionen unterwegs: letzter bekannter Stand
  do
    local keep = mod.acc.owned
    mod.acc.owned = nil
    Win.Select("auctions")
    check(Win.current == "auctions" and not Win.contents.auctions.wipText and #G.auctions.items == 0 and G.auctions.empty.text == ns.L.AUCP_EMPTY,
      "N5: Auktionen unterwegs ohne Stand: Hinweis")
    local e = D.Lookup(2770)
    mod.acc.owned = { market = ns.MarketKey(), t = clock - 3600, rows = {
      { id = 1, key = 2770, name = "Kupfererz", qty = 20, price = e.m + 50 },
      { id = 2, key = 2589, name = "Leinenstoff", qty = 5, price = 1 },
      { id = 3, key = 9999, name = "Ding", qty = 1, price = 500, sold = true } } }
    Win.Refresh()
    local st = {}
    for _, r in ipairs(G.auctions.items) do st[r.key] = r.status end
    check(#G.auctions.items == 3 and st[2770] == "under" and st[2589] == "best" and st[9999] == "sold" and G.auctions.items[1].key == 2770,
      "N5: Auktionen bewertet mit den heutigen Preisen, unterbotene oben")
    check(plain(G.aucHead.text):find("3 Auktionen, 1 unterboten", 1, true) and plain(G.aucHead.text):find("nicht live", 1, true), "N5: Kopfzeile: " .. plain(G.aucHead.text))
    mod.acc.owned = keep
  end
  -- Quellen
  Win.Select("sources")
  local src = plain(G.sources.text)
  check(src:find("Märkte", 1, true) and src:find("Anteil", 1, true) and src:find("Einkaufslisten", 1, true), "U10: Quellen mit Maerkten, Anteil und Listen")
  -- Gegenstaende: Mein Bestand nur mit Ledger
  check(#ns.Item.StockRows(2770) == 0, "U10: ohne Ledger kein Abschnitt Mein Bestand")
  Peon.modules.ledger = { ShowItem = function() end, Cost = function() return 42 end, SellRate = function() return 0.5, 1, 1 end, StockOthers = function() return 3 end }
  local sl = ns.Item.StockRows(2770, ns.Tooltip.Context(2770, D.LinkFromKey(2770), 1))
  check(#sl == 3 and sl[1][1] == "Vorrat" and sl[2][1] == "Kosten je Stück" and plain(sl[2][2]) == "42c", "U10: Mein Bestand mit Vorrat und Kosten aus Ledger")
  ns.Item.Show(2770)
  local hasHead, hasCost = false, false
  for _, r in ipairs(ns.Item.shownRows) do if r.head == "Mein Bestand" then hasHead = true end; if r[1] == "Kosten je Stück" then hasCost = true end end
  check(hasHead and hasCost, "N2: Abschnitt Mein Bestand auf der Seite Gegenstand")
  -- 0.84: zuletzt gezahlt und zuletzt verkauft aus Ledger 0.14
  Peon.modules.ledger.LastBuy = function(_, id) return 150, os.time(), 2, "vendor" end
  Peon.modules.ledger.LastSale = function(_, id) return 190.4, os.time(), 5, "ah" end
  sl = ns.Item.StockRows(2770, ns.Tooltip.Context(2770, D.LinkFromKey(2770), 1))
  check(#sl == 5 and sl[3][1] == "Zuletzt gezahlt" and plain(sl[3][2]):find("1s 50c (2,", 1, true) and sl[4][1] == "Zuletzt verkauft" and plain(sl[4][2]):find("1s 90c (5,", 1, true),
    "0.84: Mein Bestand mit zuletzt gezahlt und verkauft (" .. plain(sl[3][2]) .. ")")
  Peon.modules.ledger = nil
  -- 0.84: mod:ShowItem fuer Ledger (Seite Gegenstand)
  P.key = nil
  check(mod:ShowItem(2770) and P.key == 2770, "0.84: mod:ShowItem oeffnet die Seite Gegenstand")
  Win.Select("prices")
end)()

-- ===== Umbau U11 (0.52.0): Haendler =====
;(function()
  local V = ns.Vendors
  check(V.NpcID("Creature-0-4170-0-12-3178-0000AB12CD") == 3178 and V.NpcID("Player-1-0ABC") == nil, "U11: NPC-Nummer aus der GUID")
  -- Nachbau eines Haendlers mit drei Angeboten: Gold, Stapel, andere Waehrung mit Voraussetzung
  local offers = {
    { id = 2770, price = 50, stack = 1, avail = -1 },
    { id = 159, price = 25, stack = 5, avail = 3 },
    { id = 15000, price = 0, stack = 1, avail = -1, ext = true },
  }
  local old = { GetMerchantNumItems, GetMerchantItemID, C_MerchantFrame, GetMerchantItemCostInfo, GetMerchantItemCostItem, C_TooltipInfo, UnitGUID, C_Map, UnitName }
  GetMerchantNumItems = function() return #offers end
  GetMerchantItemID = function(i) return offers[i].id end
  C_MerchantFrame = { GetItemInfo = function(i) local o = offers[i]; return { price = o.price, stackCount = o.stack, numAvailable = o.avail, hasExtendedCost = o.ext } end }
  GetMerchantItemCostInfo = function(i) return offers[i].ext and 1 or 0 end
  GetMerchantItemCostItem = function(i, j) return "tex", 25, nil, "Zeichen der Dämmerung" end
  C_TooltipInfo = { GetMerchantItem = function(i)
    if i ~= 3 then return { lines = { { leftText = "x" } } } end
    return { lines = { { leftText = "Wappenrock" }, { leftText = "Benötigt Argentumdämmerung - Ehrfürchtig", leftColor = { r = 1, g = 0.1, b = 0.1 } } } }
  end }
  UnitGUID = function(u) return u == "npc" and "Creature-0-1-2-3-4241-0001" or nil end
  UnitName = function(u) if u == "npc" then return "Gretta Fingerfett" end return "Mirel" end
  C_Map = { GetBestMapForUnit = function() return 87 end, GetMapInfo = function() return { name = "Eisenschmiede" } end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.25 end } end }
  PeonBrokerDB.vendors = nil
  fire("MERCHANT_SHOW")
  local v = PeonBrokerDB.vendors and PeonBrokerDB.vendors[4241]
  check(v and v.n == "Gretta Fingerfett" and v.z == "Eisenschmiede" and v.x == 50 and v.y == 25, "U11: Haendler mit Name, Zone und Ort")
  check(v.items[2770].p == 50 and v.items[159].p == 5 and v.items[159].q == 5 and v.items[159].lim == 3, "U11: Preis je Stueck, Stapel, begrenzte Menge")
  check(v.items[15000].p == nil and v.items[15000].c[1].n == 25 and v.items[15000].c[1].name == "Zeichen der Dämmerung", "U11: andere Waehrung")
  check(v.items[15000].req and v.items[15000].req:find("Ehrfürchtig", 1, true), "U11: Voraussetzung aus roter Tooltip-Zeile")
  -- hoechstens alle 2 Sek. (MERCHANT_UPDATE)
  offers[1].price = 60
  fire("MERCHANT_UPDATE")
  check(PeonBrokerDB.vendors[4241].items[2770].p == 50, "U11: kurz danach nicht neu gelesen")
  now = now + 3
  fire("MERCHANT_UPDATE")
  check(PeonBrokerDB.vendors[4241].items[2770].p == 60, "U11: nach 2 Sek. neu gelesen")
  -- Tooltip-Baustein und Liste
  check(plain(V.TooltipText(2770)) == "60c (Gretta Fingerfett, Eisenschmiede)", "U11: Beim Haendler: " .. plain(V.TooltipText(2770) or ""))
  check(plain(V.PriceText(v.items[15000])) == "25 Zeichen der Dämmerung", "U11: Preistext andere Waehrung")
  local rows = V.Rows("", false)
  check(#rows == 3, "U11: Liste je Haendler und Gegenstand")
  local cu for _, r in ipairs(rows) do if r.key == 2770 then cu = r end end
  check(cu and cu.ah and cu.profit, "U11: AH nach Anteil teurer als beim Haendler -> Gewinn")
  check(#V.Rows("gretta", true) >= 1 and #V.Rows("gibtsnicht", false) == 0, "U11: Suche und Filter")
  Win.Select("vendors")
  check(V.list and #V.list:GetItems() == 3 and plain(V.count.text):find("1 Händler", 1, true) and V.list.list and V.searchBox.template == "SearchBoxTemplate",
    "U11: Haendler unter Mehr, mit Peon.UI")
  V.searchBox:SetText("gretta"); V.searchBox.scripts.OnTextChanged(V.searchBox, true)
  check(#V.list:GetItems() == 3, "N5: Suche nach dem Haendler")
  V.searchBox:SetText("gibtsnicht"); V.searchBox.scripts.OnTextChanged(V.searchBox, true)
  check(#V.list:GetItems() == 0, "N5: Suche ohne Treffer")
  V.searchBox:SetText(""); V.searchBox.scripts.OnTextChanged(V.searchBox, true)
  check(plain(V.Summary()):find("3 Angeboten", 1, true), "U11: Zusammenfassung fuer Quellen")
  GetMerchantNumItems, GetMerchantItemID, C_MerchantFrame, GetMerchantItemCostInfo, GetMerchantItemCostItem, C_TooltipInfo, UnitGUID, C_Map, UnitName = unpack(old, 1, 9)
  Win.Select("prices")
end)()

-- ===== Umbau U3 (0.44.0): Rat im Verkaufsfenster =====
;(function()
  local A = ns.Advice
  local L = ns.L
  local oldEval = ns.Data.Evaluate
  local band = { low = 90, high = 110, trend = "calm", days = 5 }
  ns.Data.Evaluate = function() return { band = band } end
  local e = { m = 100, md = 100, q = 50 }
  local r = A.Judge(e, 2770, 100, 10, 5, mod.db)
  check(r.kind == "sell" and r.title == L.ADV_SELL and r.why == L.ADV_SELL_WHY, "U3: im ueblichen Bereich -> Verkaufen")
  check(math.abs(r.net - 100 * 10 * 0.95) < 1e-9 and r.vendor == 50, "U3: Erloes nach Anteil, Haendler fuer die Menge")
  check(A.Judge(e, 2770, 120, 1, 5, mod.db).kind == "high", "U3: ueber dem Bereich -> guter Zeitpunkt")
  check(A.Judge(e, 2770, 85, 1, 5, mod.db).why == L.ADV_LOW_OK_WHY, "U3: knapp darunter -> noch Verkaufen")
  local w = A.Judge(e, 2770, 60, 1, 5, mod.db)
  check(w.kind == "wait" and w.why == L.ADV_WAIT_WHY:format(33), "U3: 33 % unter dem Bereich -> Lieber warten")
  band.trend = "down"
  check(A.Judge(e, 2770, 85, 1, 5, mod.db).kind == "fall", "U3: Preis faellt seit Laengerem -> Verkaufen, Preis faellt")
  check(A.Judge(e, 2770, 60, 1, 5, mod.db).kind == "wait", "U3: weit darunter bleibt Lieber warten")
  band.trend = "calm"
  local v = A.Judge(e, 2770, 10, 1, 20, mod.db)
  check(v.kind == "vendor" and v.title == L.ADV_VENDOR, "U3: Haendler zahlt mehr -> Lieber zum Haendler")
  ns.Data.Evaluate = function() return {} end
  check(A.Judge(e, 2770, 100, 1, 5, mod.db).kind == "none", "U3: ohne ueblichen Bereich keine Einschaetzung")
  -- ab 0.97.1: Preis im Feld von einer anderen Variante
  do
    local vk = "12042:Kette des Baeren"
    A.var = { key = vk, other = 5, best = 38400 }
    local r = { kind = "wait", title = "x", why = "y", extra = "z" }
    A.CheckVariant(r, { key = vk, price = 6050 }, nil)
    check(r.title == L.ADV_VARIANT and r.extra == nil and r.fillPrice and r.fillPrice < 38400 and r.fillPrice > 30000
      and plain(r.why):find("3g 84s", 1, true), "0.97.1: andere Variante erkannt, Preis eintragen angeboten: " .. plain(tostring(r.why)))
    local r2 = { kind = "sell", title = "x" }
    A.CheckVariant(r2, { key = vk, price = 39000 }, nil)
    check(r2.title == "x" and r2.fillPrice == nil, "0.97.1: Preis ueber dem Angebot der Variante bleibt")
    A.var = { key = vk, other = 0, best = 38400 }
    local r3 = { kind = "wait", title = "x" }
    A.CheckVariant(r3, { key = vk, price = 6050 }, nil)
    check(r3.fillPrice == nil, "0.97.1: ohne andere Varianten kein Hinweis")
    A.var = { key = vk, other = 3 }
    local r4 = { kind = "wait", title = "x" }
    A.CheckVariant(r4, { key = vk, price = 6050 }, { m = 40000 })
    check(r4.title == L.ADV_VARIANT and r4.why == L.ADV_VARIANT_WHY_MKT:format(ns.Tooltip.Money(40000)), "0.97.1: ohne Angebot in der Liste der letzte Marktpreis")
    -- ab 0.103.1: Preis der Variante selbst eintragen, einmal je Gegenstand, nur mit Live-Angebot
    local set = {}
    local sfv = { PriceInput = { SetAmount = function(_, v) set[#set + 1] = v end } }
    local oldBlocked = mod.acc.targetBlocked
    mod.acc.targetBlocked = nil
    A.autoFilled = nil
    check(A.AutoVariant(sfv, r4, { key = vk }) == false and #set == 0, "0.103.1: nur Marktpreis der Variante: nichts selbst eintragen")
    A.var = { key = vk, other = 5, best = 38400 }
    check(A.AutoVariant(sfv, r, { key = vk }) == true and set[1] == r.fillPrice, "0.103.1: Preis der Variante selbst eingetragen")
    check(A.AutoVariant(sfv, r, { key = vk }) == false and #set == 1, "0.103.1: nur einmal, eigene Aenderung danach bleibt")
    A.autoFilled = nil
    check(A.AutoVariant(sfv, r2, { key = vk }) == false and #set == 1, "0.103.1: ohne Hinweis andere Variante nichts eintragen")
    mod.acc.targetBlocked = { t = 1 }
    check(A.AutoVariant(sfv, r, { key = vk }) == false and #set == 1, "0.103.1: nach einer Blockade nichts selbst eintragen")
    mod.acc.targetBlocked = oldBlocked
    A.autoFilled = nil
    A.var = nil
  end
  -- ab 0.103: gerade kein Angebot dieser Variante, Blizzard traegt den billigen Preis einer anderen ein
  do
    local vk = "28000:Stiefel des Kanalisierers"
    local now = time()
    local oldBand, oldClient = ns.Data.Band, ns.Sales.ClientStats
    ns.Sales.ClientStats = function() return nil end
    ns.Data.Band = function() return nil end
    A.var = { key = vk, other = 24 }
    local ev = { m = 6925, md = 6925, gone = now - 600, t = now - 2 * 86400, sp = ("%d:%d"):format(6925, now - 3 * 86400) }
    local r = A.Judge(ev, vk, 1560, 1, 1541, mod.db)
    check(r.kind == "vendor", "0.103: vorher Lieber zum Haendler")
    A.CheckVariant(r, { key = vk, price = 1560 }, ev)
    A.CheckNoOffers(r, { key = vk, price = 1560 }, ev, 1541, now)
    check(r.title == L.ADV_HIGHER and r.fillPrice == 6925 and r.why == L.ADV_HIGHER_SOLD:format(ns.Tooltip.Money(6925), L.ADV_AGO_D:format(3))
      and r.extra == nil, "0.103: zuletzt verkaufter Preis -> Hoeher ansetzen: " .. plain(tostring(r.why)))
    check(A.Prices(vk, ev, nil, r).suggest == 6925, "0.103: Vorschlag = zuletzt verkaufter Preis")
    -- Verkauf zu alt: oberer Rand des ueblichen Bereichs, Hinweis kein Verkauf erkannt
    ev.sp = ("%d:%d"):format(6925, now - 10 * 86400)
    ns.Data.Band = function() return { low = 5000, high = 7000, trend = "calm" } end
    local r2 = A.Judge(ev, vk, 1560, 1, 1541, mod.db)
    A.CheckNoOffers(r2, { key = vk, price = 1560 }, ev, 1541, now)
    check(r2.title == L.ADV_HIGHER and r2.fillPrice == 7000 and r2.extra == L.ADV_HINT_NOSALE:format(7) and r2.band,
      "0.103: oberer Rand des Bereichs, Hinweis ohne Verkauf")
    -- lange nicht gesehen: selten
    ev.t = now - 12 * 86400
    local r3 = A.Judge(ev, vk, 1560, 1, 1541, mod.db)
    A.CheckNoOffers(r3, { key = vk, price = 1560 }, ev, 1541, now)
    check(r3.extra == L.ADV_HINT_RARE:format(L.ADV_AGO_D:format(12)), "0.103: selten im Markt: " .. tostring(r3.extra))
    -- auch der Vergleichspreis bringt weniger als der Haendler: bleibt beim Haendler, mit Hinweis
    ns.Data.Band = function() return { low = 1000, high = 1500, trend = "calm" } end
    local r4 = A.Judge(ev, vk, 1200, 1, 1541, mod.db)
    A.CheckNoOffers(r4, { key = vk, price = 1200 }, ev, 1541, now)
    check(r4.kind == "vendor" and r4.fillPrice == nil and r4.extra, "0.103: Vergleichspreis unter Haendler -> Haendler bleibt")
    -- Angebot dieser Variante vorhanden: nichts aendern
    A.var = { key = vk, other = 3, best = 6000 }
    local r5 = { kind = "sell", title = "x" }
    A.CheckNoOffers(r5, { key = vk, price = 1560 }, ev, 1541, now)
    check(r5.title == "x" and r5.ref == nil, "0.103: mit Angebot dieser Variante kein Eingriff")
    -- nie gesehen
    A.var = { key = vk, other = 3 }
    local r6 = { kind = "none", title = "x" }
    ns.Data.Band = function() return nil end
    A.CheckNoOffers(r6, { key = vk, price = 1560 }, nil, 1541, now)
    check(r6.extra == L.ADV_HINT_NEVER and r6.title == "x", "0.103: nie gesehen")
    ns.Data.Band, ns.Sales.ClientStats = oldBand, oldClient
    A.var = nil
  end
  check(A.Judge(e, 2770, 0, 1, 5, mod.db).why == L.ADV_NO_PRICE, "U3: ohne Preis")
  ns.Data.Evaluate = oldEval

  -- Nachbau: Auktionshaus mit Verkaufsfenster fuer Einzelgegenstaende
  local calls = 0
  local origHook = rawget(_G, "hooksecurefunc")
  hooksecurefunc = function(t, name, fn) local o = t[name]; t[name] = function(...) local x = o(...) fn(...) return x end end
  local ah = CreateFrame("Frame", "AuctionHouseFrame")
  local sf = CreateFrame("Frame"); sf.shown = true
  sf.PostButton = CreateFrame("Button")
  sf.loc = { bag = 0, slot = 1 }
  sf.price, sf.qty = 100, 3
  sf.GetItem = function(s) return s.loc end
  sf.GetPrice = function(s) return s.price end
  sf.GetQuantity = function(s) return s.qty end
  sf.UpdatePostState = function() calls = calls + 1 end
  ah.ItemSellFrame = sf
  local oldLink = C_Item.GetItemLink
  C_Item.GetItemLink = function(loc) return loc and "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r" end
  ns.Advice.hooked = nil
  fire("AUCTION_HOUSE_SHOW")
  check(ns.Advice.hooked, "U3: Verkaufsfenster angehaengt")
  sf:UpdatePostState()
  local box = A.boxes[sf]
  check(calls == 1 and box and box.shown and box.title.text ~= nil, "U3: Kasten nach UpdatePostState sichtbar: " .. tostring(box and box.title.text))
  check(A.current and A.current.key == 2770 and A.current.price == 100 and A.current.qty == 3, "U3: Gegenstand, Preis und Menge aus Blizzards Fenster gelesen")
  check(rawget(sf, "peonAdvice") == nil and box.points[1][2] == sf.PostButton, "U3: Kasten unter Auktion erstellen, nichts an Blizzards Rahmen gespeichert")
  sf.price = 1
  sf:UpdatePostState()
  check(box.title.text == L.ADV_VENDOR, "U3: Preis von Hand geaendert -> neu gerechnet (" .. tostring(box.title.text) .. ")")
  sf.loc = nil
  sf:UpdatePostState()
  check(not box.shown and A.current == nil, "U3: Fenster leer -> Kasten weg")
  C_Item.GetItemLink = oldLink
  hooksecurefunc = origHook
  AuctionHouseFrame = {}
end)()

-- ===== Umbau U6 (0.47.0): Diagramm im Tooltip =====
;(function()
  local TT = ns.Tooltip
  local today = D.Day(clock)
  local e = { m = 100, md = 110, q = 5, n = 2, t = clock,
    d = (today - 3) .. ":90:100:5:1;" .. (today - 1) .. ":120:130:5:1;" .. today .. ":100:110:5:1" }
  local mins, got = TT.ChartSeries(e, 7, today)
  check(got == 3 and mins[7] == 100 and mins[6] == 120 and mins[5] == nil and mins[4] == 90, "U6: Tageswerte der letzten 7 Tage, Luecken bleiben leer")
  -- nachgebauter Tooltip mit Zeilen
  local tip = { lines = {}, minW = 0, hooks = {} }
  function tip:GetName() return "PeonTestTip" end
  function tip:NumLines() return #self.lines end
  function tip:AddLine(t) self.lines[#self.lines + 1] = t; _G["PeonTestTipTextLeft" .. #self.lines] = CreateFrame("Frame") end
  function tip:GetMinimumWidth() return self.minW end
  function tip:SetMinimumWidth(w) self.minW = w end
  function tip:HookScript(n, fn) self.hooks[n] = fn end
  local oldGT = GameTooltip
  GameTooltip = tip
  tip:AddLine("Kupfererz")
  local ok = TT.ChartLines(tip, { key = 2770, e = e, band = { low = 95, high = 115 } }, "d7")
  local c = TT.charts[tip]
  check(ok and c and c.frame.shown and c.frame.points[1][2] == _G.PeonTestTipTextLeft3, "U6: Diagramm unter der Ueberschrift im Tooltip")
  check(tip.lines[2]:find("7", 1, true) and #tip.lines == 2 + math.ceil(TT.CHART_H / 14), "U6: Ueberschrift und Platz in Leerzeilen")
  check(tip.minW == TT.CHART_W + 20 and c.minSet, "U6: Mindestbreite fuer das Diagramm")
  check(rawget(tip, "insertedFrames") == nil, "U6: nichts in Blizzards Tooltip geschrieben")
  local sig = c.sig
  TT.ChartLines(tip, { key = 2770, e = e, band = { low = 95, high = 115 } }, "d7")
  check(c.sig == sig, "U6: gleiche Werte, nicht neu gezeichnet")
  tip.hooks.OnTooltipCleared()
  check(not c.frame.shown and tip.minW == 0 and not c.minSet, "U6: Tooltip geleert -> Diagramm weg, Breite zurueck")
  check(not TT.ChartLines(tip, { key = 2770, e = { m = 1, d = today .. ":1:1:1:1" } }, "d7"), "U6: unter zwei Tagen kein Diagramm")
  check(not TT.ChartLines({ AddLine = function() end }, { key = 2770, e = e }, "d7"), "U6: nur im Gegenstands-Tooltip")
  GameTooltip = oldGT
  local found for _, l in ipairs(TT.PreviewLines(true)) do if l:find("14", 1, true) and l:find("[", 1, true) then found = true end end
  check(found, "U6: Vorschau zeigt den Platz des Diagramms")
end)()

-- ===== Umbau U4 (0.45.0, Peon 0.16.0): Gegenstandsmenue im Kern =====
;(function()
  check(Peon.API >= 16 and Peon.AddItemMenu and Peon.ItemMenuEntries() >= 1, "U4: Kern-API 16, Broker hat sich im Gegenstandsmenue angemeldet")
  -- Nachbau von Blizzards Menue: merkt Titel und Knoepfe (mit Untermenues)
  local function Node()
    local n = { items = {} }
    function n:CreateTitle(t) self.title = t end
    function n:CreateDivider() self.items[#self.items + 1] = { divider = true } end
    function n:CreateButton(text, fn) local c = Node(); c.text, c.fn = text, fn; self.items[#self.items + 1] = c; return c end
    return n
  end
  local opened
  MenuUtil = { CreateContextMenu = function(owner, gen) opened = Node(); gen(owner, opened) end }
  local ctrl, alt, sh = false, false, false
  IsControlKeyDown = function() return ctrl end
  local oldAlt, oldShift = IsAltKeyDown, IsShiftKeyDown
  IsAltKeyDown = function() return alt end
  IsShiftKeyDown = function() return sh end
  local link = "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r"
  local M = Peon._itemMenu or nil
  -- ab Peon 0.20.1: Druecken merkt, Loslassen oeffnet einen Bildaufbau spaeter (Fehlerbericht 15)
  local function Click(button)
    local n = #timers
    fire("GLOBAL_MOUSE_DOWN", button)
    fire("GLOBAL_MOUSE_UP", button)
    for i = n + 1, #timers do timers[i]() end
  end
  -- Klick ohne Strg: nichts
  local oldTip = GameTooltip.GetItem
  GameTooltip.IsShown = function() return true end
  GameTooltip.GetItem = function() return "Kupfererz", link end
  GameTooltip.GetOwner = function() return nil end
  Click("RightButton")
  check(opened == nil, "U4: Rechtsklick ohne Strg oeffnet kein Menue")
  ctrl = true
  Click("LeftButton")
  check(opened == nil, "U4: Strg+Linksklick oeffnet kein Menue")
  fire("GLOBAL_MOUSE_DOWN", "RightButton")
  check(opened == nil, "Peon 0.20.1: beim Druecken noch kein Menue")
  local n0 = #timers
  fire("GLOBAL_MOUSE_UP", "RightButton")
  for i = n0 + 1, #timers do timers[i]() end
  check(opened and opened.title == "Kupfererz", "U4: Strg+Rechtsklick auf einen Gegenstand oeffnet das Menue (nach dem Loslassen)")
  local goMarket, info, focus, shop = opened.items[1], opened.items[2], opened.items[3], opened.items[4]
  check(goMarket.text == "Im Markt zeigen" and info.text == "Gegenstand (Broker)" and focus.text == "In den Fokus" and shop.text == ns.L.MENU_SHOP,
    "N6: Eintraege Im Markt zeigen, Gegenstand, In den Fokus und Auf Einkaufsliste")
  local lists = ns.Buy.Lists()
  check(#shop.items == #lists + 1 and shop.items[#shop.items].text == ns.L.MENU_SHOP_NEW, "U4: Untermenue mit allen Listen und Neue Liste")
  local before = #lists
  shop.items[#shop.items].fn()
  lists = ns.Buy.Lists()
  check(#lists == before + 1 and lists[#lists].items[2770], "U4: Neue Liste mit dem Gegenstand")
  info.fn()
  check((ns.Window.current == "more" and ns.Window.more.current == "prices") and ns.Item.key == 2770, "U4: Gegenstand zeigt den Gegenstand im Broker-Fenster")
  ns.Window.Select("buy")
  goMarket.fn()
  check(ns.Window.current == "browse" and ns.Go.back == "buy", "N3: Im Markt zeigen aus dem Menue, unterwegs zur Marktseite mit Zurueck")
  ns.Go.Clear()
  -- Aktionsleiste: kein Menue
  opened = nil
  GameTooltip.GetOwner = function() return { action = 1 } end
  clock = clock + 1; now = now + 1
  Click("RightButton")
  check(opened == nil, "U4: auf Aktionsleisten kein Menue")
  -- Einstellung aus
  GameTooltip.GetOwner = function() return nil end
  PeonDB.itemMenuClick = "off"
  now = now + 1
  Click("RightButton")
  check(opened == nil, "U4: Einstellung aus")
  PeonDB.itemMenuClick = "ALT-RightButton"; ctrl, alt = false, true
  now = now + 1
  Click("RightButton")
  check(opened ~= nil, "U4: Klick einstellbar (Alt+Rechtsklick)")
  PeonDB.itemMenuClick = "CTRL-RightButton"
  -- Tastenbelegung
  opened = nil; now = now + 1
  Peon_OpenHoverItemMenu()
  check(opened ~= nil, "U4: Tastenbelegung oeffnet das Menue fuer den Gegenstand unter der Maus")
  ctrl, alt = false, false
  IsAltKeyDown, IsShiftKeyDown = oldAlt, oldShift
  GameTooltip.GetItem, GameTooltip.IsShown, GameTooltip.GetOwner = oldTip, nil, nil
  ns.Buy.DeleteList(#ns.Buy.Lists())
  MenuUtil = nil
end)()

-- 0.56: AH-Fenster fertig machen (Weiterverkauf, Blizzard-Aufbau, Radar ohne Haenger)
;(function()
  local Rs = ns.Resale
  local rows = { { price = 26, qty = 11 }, { price = 27, qty = 475 }, { price = 28, qty = 3430 } }
  local r = Rs.Calc(rows, 486, nil, 0.05)
  check(r and r.next == 28 and r.cost == 11 * 26 + 475 * 27 and r.net == math.floor(486 * 28 * 0.95) and r.profit == r.net - r.cost,
    "0.56: Weiterverkauf, 486 Stueck bis 27c kaufen, zu 28c einstellen")
  r = Rs.Calc(rows, 11, 300, 0.05)
  check(r and r.next == 27 and r.cost == 300 and r.profit == math.floor(11 * 27 * 0.95) - 300, "0.56: Gesamtpreis aus Blizzards Fenster, naechste Stufe 27c")
  r = Rs.Calc(rows, 5, nil, 0.05)
  check(r and r.next == 26, "0.56: Rest auf derselben Stufe: naechstes Angebot zum selben Preis")
  check(Rs.Calc(rows, 5000, nil, 0.05) == nil and Rs.Calc(rows, 0) == nil, "0.56: zu wenig Angebote oder keine Menge: keine Rechnung")
  -- Listen im Blizzard-Aufbau passen sich der Groesse an (Kern-API 17)
  local lst = ns.Chances.list
  check(lst.list and lst.o.icon and lst.o.sortDesc, "N6/0.105: Liste der Chancen mit Peon.UI")
  -- N4: Einkaufen mit Peon.UI
  do
    local B = ns.Buy
    local cols = {}
    for _, col in ipairs(B.itemList.o.columns) do cols[#cols + 1] = col.title end
    check(table.concat(cols, ",") == "Gegenstand,Ziel,Fehlt,Höchstpreis,Preis,Rat", "N4: Spalten der Einkaufsliste: " .. table.concat(cols, ","))
    check(B.buyButton.template == "UIPanelGoldButtonTemplate" and B.goMarketButton and B.allChars and B.nameBox.template == "LargeInputBoxTemplate",
      "N4: Gold-Knopf Kaufen, Im Markt zeigen, Bausteine aus Peon.UI")
    local jumped, menu, picked = nil, nil, 0
    local oldM, oldMenu = ns.Go.Market, ns.Go.Menu
    ns.Go.Market = function(item) jumped = item; return true end
    ns.Go.Menu = function(item) menu = item; return true end
    local row = { key = 2770, name = "Kupfererz" }
    now = now + 5
    ns.Go.Click(row, "LeftButton", nil, function() picked = picked + 1 end)
    check(picked == 1 and jumped == nil, "N4: Linksklick waehlt")
    now = now + 0.2
    ns.Go.Click(row, "LeftButton", nil, function() picked = picked + 1 end)
    check(picked == 1 and jumped == row, "N4: Doppelklick zeigt im Markt")
    now = now + 0.2
    ns.Go.Click(row, "LeftButton", nil, function() picked = picked + 1 end)
    check(picked == 2, "N4: danach wieder ein einfacher Klick")
    ns.Go.Click(row, "RightButton", nil, function() picked = picked + 1 end)
    check(menu == row and picked == 2, "N4: Rechtsklick oeffnet das Menue")
    ns.Go.Market, ns.Go.Menu = oldM, oldMenu
    now = now + 5
  end
  -- Radar laedt beim Oeffnen nur bei neuem Scan neu
  local loads, orig = 0, Rd.LoadFromScan
  Rd.LoadFromScan = function() loads = loads + 1; return orig() end
  Rd.loaded = nil
  Rd.LoadIfStale(); Rd.LoadIfStale()
  check(loads == 1, "0.56: Radar zweimal geoeffnet, Datenbank nur einmal durchsucht")
  local m = ns.Data.Market()
  if m then
    local last = m.lastScan
    m.lastScan = (last or 0) + 1
    Rd.LoadIfStale()
    check(loads == 2, "0.56: neuer Scan: Treffer neu geladen")
    m.lastScan = last
  end
  Rd.LoadFromScan = orig
  -- Rat beim Verkaufen ohne Rahmen und ohne Ueberschrift
  local sf = CreateFrame("Frame")
  ns.Advice.Show(sf, { kind = "sell", title = "Verkaufen", why = "ok" }, false)
  local box = ns.Advice.boxes[sf]
  check(box and box.head == nil and box.title.points[1][2] == box and box.title.points[1][5] == 0, "0.56: Rat ohne Rahmen und ohne Ueberschrift Broker")
end)()

-- 0.57: Radar-Tooltip, Namen nachladen, Neuladen nur nach Scan, Auktionen-Spalte
;(function()
  local TT = ns.Tooltip
  local owner = CreateFrame("Frame")
  local oldItem, oldOwner = GameTooltip.GetItem, GameTooltip.GetOwner
  GameTooltip.GetItem = function() return "Kupfererz", "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r" end
  GameTooltip.GetOwner = function() return owner end
  local ex = TT.SetExtra(owner, function(t) t:AddLine("RADAR-ZUSATZ") end)
  tt.lines = {}
  TT.OnItem(GameTooltip)
  local last = tt.lines[#tt.lines]
  local lastText = type(last) == "table" and (last[1] or last.text) or last
  check(ex.done and tostring(lastText):find("RADAR-ZUSATZ", 1, true), "0.57: Radar-Zeilen ganz unten im normalen Tooltip")
  tt.lines = {}
  TT.OnItem(GameTooltip)   -- Neuaufbau (z. B. Umschalt): Zusatz wieder da
  last = tt.lines[#tt.lines]
  lastText = type(last) == "table" and (last[1] or last.text) or last
  check(tostring(lastText):find("RADAR-ZUSATZ", 1, true), "0.57: Zusatz bleibt beim Neuaufbau")
  TT.SetExtra(nil)
  tt.lines = {}
  TT.OnItem(GameTooltip)
  local found = false
  for _, l in ipairs(tt.lines) do local x = type(l) == "table" and (l[1] or l.text) or l if tostring(x):find("RADAR-ZUSATZ", 1, true) then found = true end end
  check(not found, "0.57: nach dem Verlassen kein Zusatz")
  -- 0.96.1: Rezept: GetItem nennt das hergestellte Produkt, data.id das Rezept
  local seen
  local oldAdd = TT.AddLines
  TT.AddLines = function(_, link) seen = link; return false end
  TT.OnItem(GameTooltip, { id = 13947 })
  check(seen and ns.Data.KeyFromLink(seen) == 13947, "0.96.1: Rezept statt Produkt im Tooltip: " .. tostring(seen))
  TT.OnItem(GameTooltip, { id = 2770 })
  check(ns.Data.KeyFromLink(seen) == 2770 and seen:find("Kupfererz", 1, true), "0.96.1: gleicher Gegenstand: Link bleibt")
  TT.OnItem(GameTooltip)
  check(ns.Data.KeyFromLink(seen) == 2770, "0.96.1: ohne data wie bisher")
  TT.AddLines = oldAdd
  GameTooltip.GetItem, GameTooltip.GetOwner = oldItem, oldOwner
  -- Namen nachladen
  local saved, savedName = Rd.entries, ns.Data.ItemName
  Rd.entries = { [99991] = { key = 99991, name = "99991", noName = true } }
  Rd.nameWait = { [99991] = true }
  ns.Data.ItemName = function(key) if key == 99991 then return "Testerz" end return savedName(key) end
  Rd.OnItemInfo(99991)
  check(Rd.entries[99991].name == "Testerz" and not Rd.entries[99991].noName, "0.57: Name kommt nach, statt Nummer")
  ns.Data.ItemName, Rd.entries = savedName, saved
  -- Radar laedt ohne neuen Scan nicht nach Zeit neu
  local loads, orig = 0, Rd.LoadFromScan
  Rd.LoadFromScan = function() loads = loads + 1; return orig() end
  Rd.loaded = nil
  Rd.LoadIfStale()
  Rd.loaded.t = (Rd.loaded.t or 0) - 3600
  Rd.LoadIfStale()
  check(loads == 1, "0.57: nach einer Stunde ohne Scan kein Neuladen")
  Rd.LoadFromScan = orig
end)()

-- 0.58: dichtere Zeilen im Verkaufsfenster, Look wie Verkaufen
;(function()
  local A = ns.Advice
  local sf = CreateFrame("Frame")
  local ys = { QuantityInput = -100, PriceInput = -150, Duration = -200, Deposit = -250, TotalPrice = -300, PostButton = -350 }
  for k, y in pairs(ys) do local c = CreateFrame("Frame"); c:SetPoint("TOPLEFT", sf, "TOPLEFT", 10, y); sf[k] = c end
  local shift = A.Compact(sf)
  local function Y(k) return select(5, sf[k]:GetPoint(1)) end
  check(shift == 4 * A.GAP_CUT and Y("QuantityInput") == -100 and Y("PriceInput") == -150
    and Y("Duration") == -200 + A.GAP_CUT and Y("PostButton") == -350 + 4 * A.GAP_CUT,
    "0.58: Dauer, Einzahlen, Gesamtpreis und Knopf ruecken naeher, oben bleibt alles")
  check(#sf.Duration.points == 1 and sf.Duration.points[1][1] == "TOPLEFT" and sf.Duration.points[1][2] == sf, "0.58: nur der eigene Anker neu gesetzt")
  sf.Deposit.shown = false
  for k, y in pairs(ys) do sf[k]:ClearAllPoints(); sf[k]:SetPoint("TOPLEFT", sf, "TOPLEFT", 10, y) end
  A.Compact(sf)
  check(Y("TotalPrice") == -300 + 2 * A.GAP_CUT, "0.58: verborgene Zeile zaehlt nicht")
  mod.acc.ahPlain = true
  for k, y in pairs(ys) do sf[k]:ClearAllPoints(); sf[k]:SetPoint("TOPLEFT", sf, "TOPLEFT", 10, y) end
  check(A.Compact(sf) == 0 and Y("PostButton") == -350, "0.58: Blizzard pur: nichts verschoben")
  mod.acc.ahPlain = false
  check(ns.Look == nil, "N6: Look.lua entfaellt, alle Seiten nutzen Peon.UI")
end)()

-- ===== 0.69: Fokus fragt zuerst mit einer Suche, Merken von Absatz und Trend, Zeitmessung =====
;(function()
  local R, BO = ns.Radar, ns.Buyout
  local keepRefresh, keepSearch = AHs.RefreshCommoditySearchResults, AHs.SendSearchQuery
  local refreshed, searched = 0, 0
  AHs.RefreshCommoditySearchResults = function() refreshed = refreshed + 1 end
  AHs.SendSearchQuery = function() searched = searched + 1 end
  mod.acc.commodity[2775] = true
  R.pending = nil
  R.focus = { key = 2775, at = 0 }
  R.SendFocus()
  check(searched == 1 and refreshed == 0, "0.69: erste Abfrage im Fokus ist eine Suche (Neu laden ging ohne fruehere Suche ins Leere)")
  R.pending = nil
  R.focus.answered = true
  R.SendFocus()
  check(refreshed == 1 and searched == 1, "0.69: nach einer Antwort reicht Neu laden")
  R.pending, R.focus = nil, nil
  AHs.RefreshCommoditySearchResults, AHs.SendSearchQuery = keepRefresh, keepSearch
  -- Absatz und Trend je Gegenstand gemerkt
  local keepStats, calls = ns.Sales.Stats, 0
  ns.Sales.Stats = function() calls = calls + 1; return { perHour = 10, level = 3 } end
  BO.CTX_TIME, BO.ctx = 300, {}
  BO.Context(nil, 2775); BO.Context(nil, 2775)
  check(calls == 1, "0.69: Absatz und Trend werden je Gegenstand nur einmal gerechnet")
  BO.CTX_TIME, BO.ctx = 0, {}
  BO.Context(nil, 2775)
  check(calls == 2, "0.69: nach Ablauf neu gerechnet")
  ns.Sales.Stats = keepStats
  -- Zeitmessung
  R.perf = {}
  local keepClock, t = debugprofilestop, 0
  debugprofilestop = function() t = t + 2; return t end
  check(R.Perf("probe", function(a) return a + 1 end, 41) == 42, "0.69: Zeitmessung gibt das Ergebnis weiter")
  check(R.perf.probe and R.perf.probe.n == 1 and R.perf.probe.max == 2, "0.69: Zeit gemessen")
  local n0 = #out
  R.PerfReport()
  check(#out > n0 and next(R.perf) == nil, "0.69: Bericht zeigt und leert die Messung")
  debugprofilestop = keepClock
end)()

-- ===== 0.70: Fenster Einstellungen im Fokus, Grenzen der Messung einstellbar =====
;(function()
  local S, M = ns.Settings, ns.Measure
  S.Toggle("focus")
  local f = S.frames.focus
  check(f and f:IsShown() and #f.controls == 27, "0.70: Fenster Einstellungen des Fokus mit 7 Reglern (ab 0.122 Gelegenheiten, ab 0.120 zwei Vorgaben fuer den Schnellkauf, Kaufzone und Preissprung, ab 0.91 Haken Wiedereinstellen, ab 0.104 drei fuer den Schnellkauf, ab 0.108 vier fuer die Marktbewegung, ab 0.109 Grenze fuer Lockangebote, ab 0.115 ohne Kaufprotokoll, ab 0.111 Ton fuer Lockangebote, ab 0.113 automatisch speichern, ab 0.114 Pause der Abfragen)")
  local rate
  for _, c in ipairs(f.controls) do if c.row[2] == "focusRate" then rate = c end end
  check(rate and plain(rate.value.text) == "12 (alle 5 Sek.)", "0.70: Abfragen pro Minute mit Abstand: " .. tostring(rate and plain(rate.value.text)))
  S.Set("focus", "focusRate", 90)   -- wie ein Zug am Regler (Blizzards Regler fehlt im Nachbau)
  check(mod.db.focusRate == 12 and S.Get("focus", "focusRate") == 90, "0.74: Regler aendert erst den Entwurf")
  f.ok.scripts.OnClick(f.ok)
  check(mod.db.focusRate == 90 and not f:IsShown(), "0.74: OK uebernimmt und schliesst")
  S.Toggle("focus")
  check(plain(rate.value.text) == "90 (alle 0,7 Sek.)", "0.74: beim Oeffnen stehen die gespeicherten Werte da")
  S.Set("focus", "focusRate", 30)
  f.cancel.scripts.OnClick(f.cancel)
  check(mod.db.focusRate == 90 and not f:IsShown(), "0.74: Abbrechen verwirft")
  S.Toggle("focus")
  mod.db.focusRate = 12
  mod.db.focusWindow, mod.db.focusFirst = 3, 60
  M.Sync()
  check(M.WINDOW == 180 and M.FIRST == 60, "0.70: Grenzen der Messung aus den Einstellungen")
  mod.db.focusWindow, mod.db.focusFirst = 10, 30
  M.Sync()
  S.Toggle("focus")
  check(not f:IsShown(), "0.70: zweiter Klick schliesst das Fenster")
  -- Umzug der alten Einstellung
  local acc = { focusEvery = 10 }
  mod.opts.migrate(mod, acc)
  check(acc.focusRate == 6, "0.70: alter Abstand 10 Sek. wird 6 Abfragen pro Minute")
end)()

-- ===== 0.71: Zum Einstellen im Reiter Verkaufen mit sicherem Knopf =====
;(function()
  local LT = ns.Lots
  local keepAH, keepCC, keepCount = AuctionHouseFrame, C_Container, C_Item.GetItemCount
  local ah = CreateFrame("Frame", "AuctionHouseFrame")
  ah.CommoditiesSellFrame, ah.CommoditiesSellList = CreateFrame("Frame"), CreateFrame("Frame")
  ah.ItemSellFrame, ah.ItemSellList = CreateFrame("Frame"), CreateFrame("Frame")
  ah.ItemSellFrame.shown, ah.ItemSellList.shown = false, false
  LT.toggle, LT.panel, LT.sel = nil, nil, nil
  mod.char.lots, mod.char.lotSeq = {}, nil
  LT.Add(7971, 40, 40000, 1500, "radar")
  market.items[7971] = { m = 1400, md = 1500, q = 100, n = 2, t = clock, nm = "Kistenstein", ql = 1 }
  C_Item.GetItemCount = function(id) return id == 7971 and 40 or 0 end
  C_Container = setmetatable({ GetContainerNumSlots = function(bag) return bag == 0 and 4 or 0 end,
    GetContainerItemID = function(bag, slot) return (bag == 0 and slot == 3) and 7971 or nil end,
    GetContainerItemInfo = function() return { isLocked = false } end }, { __index = keepCC })
  PeonBagsItem1 = CreateFrame("Button"); PeonBagsItem1.peonBag, PeonBagsItem1.peonSlot = 0, 2
  PeonBagsItem2 = CreateFrame("Button"); PeonBagsItem2.peonBag, PeonBagsItem2.peonSlot = 0, 3
  fire("AUCTION_HOUSE_SHOW")
  check(LT.toggle and LT.toggle.shown and plain(LT.toggle.text) == "Zum Einstellen (1)" and not LT.panel.shown, "0.71: Knopf ueber Blizzards Liste im Verkaufen")
  local attr = {}
  LT.postButton.SetAttribute = function(_, k, v) attr[k] = v end
  LT.toggle.scripts.OnClick(LT.toggle)
  check(LT.panel.shown and #LT.list:GetItems() == 1 and plain(LT.toggle.text) == "Liste schließen" and LT.postButton.disabled,
    "0.71: Liste der Posten ueber Blizzards Liste, noch nichts gewaehlt")
  LT.list.o.onClick(LT.list:GetItems()[1], "LeftButton")
  check(attr.type == "macro" and attr.macrotext == "/click PeonBagsItem2 RightButton" and not LT.postButton.disabled and LT.postButton.text == "Ins Verkaufsfenster legen",
    "0.71: Posten gewaehlt: sicherer Knopf klickt den Taschenplatz rechts an: " .. tostring(attr.macrotext))
  C_Item.GetItemCount = function() return 0 end
  LT.RefreshPanel()
  check(LT.postButton.disabled and LT.postButton.text == "Liegt noch in der Post" and attr.type == nil, "0.71: Ware noch in der Post: Knopf gesperrt")
  ah.CommoditiesSellFrame.shown, ah.CommoditiesSellList.shown = false, false
  LT.Place()
  check(not LT.toggle.shown and not LT.panel.shown, "0.71: ausserhalb von Verkaufen nichts zu sehen")
  PeonBagsItem1, PeonBagsItem2 = nil, nil
  AuctionHouseFrame, C_Container, C_Item.GetItemCount = keepAH, keepCC, keepCount
  LT.toggle, LT.panel, LT.sel = nil, nil, nil
  mod.char.lots = {}
  market.items[7971] = nil
end)()

-- ===== 0.98: im Verkaufen nur die Angebote dieser Variante =====
;(function()
  local VS, A = ns.SellVariant, ns.Advice
  local keepAH, keepMore = AuctionHouseFrame, ns.Live.RequestMore
  local ah = CreateFrame("Frame", "AuctionHouseFrame")
  ah.ItemSellFrame, ah.ItemSellList = CreateFrame("Frame"), CreateFrame("Frame")
  ah.CommoditiesSellFrame = CreateFrame("Frame"); ah.CommoditiesSellFrame.shown = false
  local setTo
  ah.ItemSellFrame.PriceInput = { SetAmount = function(_, v) setTo = v end }
  VS.toggle, VS.panel, VS.hooked, VS.more = nil, nil, nil, nil
  local more = 0
  ns.Live.RequestMore = function() more = more + 1; return "wait" end
  local vk = "12042:Kette des Baeren"
  A.current = { key = vk }
  A.var = nil
  fire("AUCTION_HOUSE_SHOW")
  check(VS.panel and not VS.panel.shown and not VS.toggle.shown, "0.98: ohne andere Varianten keine eigene Liste")
  A.var = { key = vk, other = 4, best = 38400, partial = true, itemKey = { itemID = 12042 },
            rows = { { price = 38400, qty = 1, own = 0 }, { price = 41000, qty = 2, own = 1 } } }
  VS.Refresh()
  local items = VS.list:GetItems()
  check(VS.panel.shown and VS.toggle.shown and #items == 2 and plain(VS.toggle.text) == "Alle Varianten zeigen",
    "0.98: eigene Liste mit den Angeboten dieser Variante")
  check(plain(VS.hint.text):find("4 Angebote anderer Varianten ausgeblendet", 1, true) and more == 1, "0.98: Hinweis und Rest angefordert: " .. plain(VS.hint.text))
  VS.list.o.onClick(items[2], "LeftButton")
  check(setTo == 41000, "0.98: Klick traegt den Preis der Zeile ein")
  VS.toggle.scripts.OnClick(VS.toggle)
  check(mod.db.sellVariantOnly == false and not VS.panel.shown and VS.toggle.shown and plain(VS.toggle.text) == "Nur diese Variante",
    "0.98: Umschalten auf Blizzards Liste mit allen Varianten")
  VS.toggle.scripts.OnClick(VS.toggle)
  check(mod.db.sellVariantOnly == true and VS.panel.shown, "0.98: und zurueck")
  for _ = 1, 10 do VS.Refresh() end
  check(more == ns.Live.MORE_MAX, "0.98: Rest hoechstens MORE_MAX mal angefordert: " .. more)
  A.current = { key = "12042:Kette des Adlers" }
  VS.Refresh()
  check(not VS.panel.shown and not VS.toggle.shown, "0.98: anderer Gegenstand im Fenster, Liste weg")
  A.current = { key = vk }
  ah.ItemSellList.shown = false
  VS.Refresh()
  check(not VS.panel.shown, "0.98: ausserhalb von Verkaufen nichts zu sehen")
  AuctionHouseFrame, ns.Live.RequestMore = keepAH, keepMore
  VS.toggle, VS.panel, VS.hooked, VS.more = nil, nil, nil, nil
  A.current, A.var = nil, nil
end)()

-- ===== 0.71: Fenster Einstellungen im Radar, Arten abschaltbar (ab 0.105 im Fenster Chancen) =====
;(function()
  local S, R = ns.Settings, ns.Radar
  check(S.SPECS.radar == nil, "0.105: kein eigenes Fenster fuer das Radar")
  S.Toggle("chances")
  local f = S.frames.chances
  local reserve, notify
  for _, c in ipairs(f.controls) do
    if c.row[2] == "radarReserve" then reserve = c end
    if c.row[2] == "chancesNotify" then notify = c end
  end
  check(reserve and notify and f.h == 860, "0.105: ein Fenster fuer Chancen und Radar, etwas hoeher (ab 0.127 mit Markttausch 860)")
  local vendor, spec
  for _, c in ipairs(f.controls) do
    if c.row[2] == "radarVendorOn" then vendor = c end
    if c.row[2] == "radarSpecOn" then spec = c end
  end
  check(f:IsShown() and vendor and spec == nil, "0.71: Radar-Einstellungen mit Haendler und Aufkauf, ab 0.96 ohne Spekulation")
  vendor.frame:SetChecked(false)
  vendor.frame.scripts.OnClick(vendor.frame)
  check(S.Get("chances", "radarVendorOn") == false and mod.db.radarVendorOn ~= false, "0.74: Haken aendert erst den Entwurf")
  f.ok.scripts.OnClick(f.ok)
  check(mod.db.radarVendorOn == false, "0.74: OK uebernimmt")
  mod.db.radarVendorOn = false
  check(R.KIND_ON.vendor == false and R.KIND_ON.buyout == true, "0.71: Art Haendler abgeschaltet")
  mod.db.radarVendorOn = true
  S.Hide("chances")
end)()

-- ===== 0.72: eigene Liste der Auktionen ueber Blizzards Ansicht =====
;(function()
  local X, O = ns.AuctionsAH, ns.AuctionsOwn
  local keepAH = AuctionHouseFrame
  local ah = CreateFrame("Frame", "AuctionHouseFrame")
  ah.AuctionsFrame = CreateFrame("Frame")
  ah.AuctionsFrame.AllAuctionsList = CreateFrame("Frame")
  X.header, O.panel, O.sel, O.sig = nil, nil, nil, nil
  local keepRead = ns.Auctions.Read
  ns.Auctions.Read = function() return ns.Auctions.rows end
  ns.Auctions.rows = {
    { id = 31, key = 2770, itemID = 2770, name = "Kupfererz", status = "under", other = 40, price = 50, qty = 20, left = 7200 },
    { id = 32, key = 2589, itemID = 2589, name = "Leinen", status = "best", price = 70, qty = 5, band = 1 },
    { id = 33, key = 2592, itemID = 2592, name = "Wolle", sold = true, price = 90, qty = 1 },
  }
  fire("AUCTION_HOUSE_SHOW")
  check(O.panel and O.panel.shown and #O.list:GetItems() == 3, "0.72: Brokers Liste liegt ueber Blizzards Ansicht Auktionen")
  local cols = {}
  for _, c in ipairs(O.list.o.columns) do cols[#cols + 1] = c.title end
  check(table.concat(cols, ",") == "Gegenstand,Menge,Preis je Stück,Broker,Restzeit", "0.72: Spalte Broker als echte Spalte: " .. table.concat(cols, ","))
  check(plain(O.cancelUnder.text) == "Unterbotene abbrechen (1)" and O.cancelOne.disabled and O.market.disabled, "0.72: Knoepfe unten, ohne Auswahl gesperrt")
  O.Hidden().best, O.Hidden().sold = true, true
  O.Update(true)
  check(#O.list:GetItems() == 1 and O.list:GetItems()[1].id == 31 and plain(O.summary.text):find("2 per Filter ausgeblendet", 1, true),
    "0.72: Filter blendet Guenstigstes und Verkauft aus")
  mod.db.aucHide = {}
  O.Update(true)
  local r
  for _, x in ipairs(O.list:GetItems()) do if x.id == 32 then r = x end end
  O.list.o.onClick(r, "LeftButton")
  check(not O.cancelOne.disabled and not O.market.disabled, "0.72: Auswahl gibt Abbrechen und Im Markt zeigen frei")
  local cancelled
  local keepCancel = AHs.CancelAuction
  AHs.CancelAuction = function(id) cancelled = id end
  ns.Lots.cancelling = nil
  O.cancelOne.scripts.OnClick(O.cancelOne)
  check(cancelled == 32 and ns.Lots.cancelling and ns.Lots.cancelling.target == 70, "0.72: gewaehlte Auktion abbrechen, Ziel bleibt der eigene Preis ohne fremdes Angebot")
  ns.Lots.cancelling = nil
  AHs.CancelAuction = keepCancel
  O.blizz.scripts.OnClick(O.blizz)
  check(not O.panel.shown and X.header.own.shown and mod.db.aucOwnList == false, "0.72: Blizzard-Ansicht (Gebote), Knopf Broker-Liste fuehrt zurueck")
  X.header.own.scripts.OnClick(X.header.own)
  check(O.panel.shown and mod.db.aucOwnList == true, "0.72: zurueck zur Broker-Liste")
  ns.AHTabs.current = "buy"
  O.Place()
  check(not O.panel.shown, "0.74: Broker-Reiter offen: Liste der Auktionen weg (lag sonst ueber Einkaufen)")
  ns.AHTabs.current = nil
  O.Place()
  ah.AuctionsFrame.shown = false
  O.Place()
  check(not O.panel.shown, "0.72: nur sichtbar, solange Blizzards Ansicht Auktionen offen ist")
  ns.Auctions.Read, ns.Auctions.rows = keepRead, {}
  X.header, O.panel, O.sel = nil, nil, nil
  AuctionHouseFrame = keepAH
end)()

-- ===== 0.73: Im Markt zeigen mit sicherem Knopf =====
;(function()
  local Go = ns.Go
  local keepAH, keepAt, keepShow, keepMarket = AuctionHouseFrame, ns.Window.AtAH, ns.Buy.ShowInAH, Go.Market
  local ah = CreateFrame("Frame", "AuctionHouseFrame")
  ah.BuyTab = CreateFrame("Button")
  local rows = {}
  ah.BrowseResultsFrame = CreateFrame("Frame")
  ah.BrowseResultsFrame.ItemList = { ScrollBox = { ForEachFrame = function(_, fn) for _, r in ipairs(rows) do fn(r) end end } }
  ns.Window.AtAH = function() return true end
  local searched, jumped
  ns.Buy.ShowInAH = function(row) searched = row.key; return true end
  Go.Market = function(item) jumped = item.key; return true end
  local b = Go.MarketButton(CreateFrame("Frame"), 120, function() return { key = 2770, name = "Kupfererz" } end)
  local attr = {}
  b.SetAttribute = function(_, k, v) attr[k] = v end
  check(b.template and b.template:find("SecureActionButtonTemplate", 1, true) and b.text == "Im Markt zeigen", "0.73: Im Markt zeigen ist ein sicherer Knopf")
  b.scripts.PreClick(b, "LeftButton", true)
  check(attr.type == nil, "0.73: Druecken allein tut nichts (Aktion beim Loslassen)")
  b.scripts.PreClick(b, "LeftButton", false)
  check(attr.type == "click" and attr.clickbutton == ah.BuyTab and b.stage == "tab", "0.73: ohne Zeile klickt der Knopf Blizzards Reiter Markt")
  b.scripts.PostClick(b, "LeftButton", false)
  check(searched == 2770, "0.73: danach sucht Broker den Gegenstand im Markt")
  local row = CreateFrame("Button")
  row.rowData = { itemKey = { itemID = 2770 } }
  rows[1] = row
  b.scripts.PreClick(b, "LeftButton", false)
  check(attr.clickbutton == row and b.stage == "row", "0.73: Zeile schon da: der Knopf oeffnet die Angebote direkt")
  b.scripts.PostClick(b, "LeftButton", false)
  check(Go.TryOffer == nil and Go.WaitOffer == nil and rawget(_G, "PeonBrokerOfferButton") == nil, "0.75: kein Knopf Angebote mehr")
  ns.Window.AtAH = function() return false end
  b.scripts.PreClick(b, "LeftButton", false)
  b.scripts.PostClick(b, "LeftButton", false)
  check(attr.type == nil and jumped == 2770, "0.73: unterwegs der bisherige Weg (Markt aus Scandaten)")
  AuctionHouseFrame, ns.Window.AtAH, ns.Buy.ShowInAH, Go.Market = keepAH, keepAt, keepShow, keepMarket
end)()

-- ===== 0.74: Nachbesserungen nach dem zweiten Test =====
;(function()
  local M, R, F = ns.Measure, ns.Radar, ns.Focus
  -- Abfluss ueber Preisstufen: neue Nummern bei gleichen Stufen sind keine Verkaeufe
  local function lv(list, idBase)
    local rows = { offers = {}, commodity = true }
    for i, o in ipairs(list) do
      rows[#rows + 1] = { price = o[1], qty = o[2], own = 0 }
      rows.offers[#rows.offers + 1] = { id = idBase + i, q = o[2], p = o[1] }
    end
    return rows
  end
  R.entries[7981] = { key = 7981, kind = "buyout", ref = 150, qty = 10, rows = {} }   -- Ziel 1s 50c
  M.Start(7981)
  M.Add(7981, lv({ { 100, 10 }, { 120, 20 }, { 150, 50 } }, 100), 0)
  M.Add(7981, lv({ { 100, 10 }, { 120, 20 }, { 150, 50 } }, 200), 10)
  local pr = M.cur.pairs[#M.cur.pairs]
  check(pr.byLevels and pr.sold == 0 and pr.cancelled == 0 and pr.newAll == 0, "0.74: gleiche Stufen mit neuen Nummern: kein Abfluss, kein Zufluss")
  M.Add(7981, lv({ { 100, 4 }, { 120, 20 }, { 150, 50 } }, 300), 20)
  pr = M.cur.pairs[#M.cur.pairs]
  check(pr.sold == 6 and pr.cancelled == 0, "0.74: unterste Stufe kleiner: verkauft")
  M.Add(7981, lv({ { 100, 4 }, { 120, 20 }, { 140, 5 } }, 400), 30)
  pr = M.cur.pairs[#M.cur.pairs]
  check(pr.sold == 0 and pr.cancelled == 50 and pr.newUnder == 5, "0.74: Stufe ueber einer stehenden weg: abgebrochen, neue Stufe unter dem Ziel: Zufluss")
  M.Stop()
  R.entries[7981] = nil
  -- Pause waehrend eines Kaufs, Fehlerprotokoll
  R.buyUntil, R.job = nil, nil
  check(not ns.Buying(), "0.74: kein Kauf")
  fire("COMMODITY_PRICE_UPDATED", 10, 100)
  check(ns.Buying(), "0.74: Preis vom Spiel da: Kauf laeuft, Broker fragt nicht ab")
  fire("COMMODITY_PURCHASE_SUCCEEDED")
  check(not ns.Buying(), "0.74: Kauf fertig: Abfragen wieder frei")
  mod.acc.ahErrors = nil
  fire("AUCTION_HOUSE_SHOW_ERROR", 9)
  check(type(mod.acc.ahErrors) == "table" and #mod.acc.ahErrors == 1 and mod.acc.ahErrors[1].code == "9", "0.74: Meldung des Auktionshauses gemerkt")
  local n0 = #out
  R.ErrorReport()
  check(#out > n0 and plain(out[#out]):find("Nummer 9", 1, true), "0.74: /broker pruefen fehler zeigt die Meldung")
  -- Fokus: Stufe des Ziels gelb, ueblicher Bereich
  ns.Buy.live[7982] = { rows = { { price = 50, qty = 5, own = 0 }, { price = 80, qty = 7, own = 0 } }, t = time() + 1, commodity = true }
  local keepKey, keepOpen = F.key, ns.Scan.ahOpen
  F.key, ns.Scan.ahOpen, F.since = 7982, true, 0
  local tiers = F.Tiers(50, 80)
  check(tiers[2].isTarget and not tiers[1].isTarget and F.tiers.o.rowBg(tiers[2]) == 1 and F.tiers.o.rowBg(tiers[1]) == 0.25,
    "0.74: Stufe zum Ziel mit gelbem Hintergrund")
  check(plain(F.BandText({ band = { low = 120, high = 160 } })) == "1s 20c bis 1s 60c", "0.74: ueblicher Bereich als Text")
  check(F.refreshButton == nil, "0.74: kein Knopf Jetzt pruefen mehr")
  -- 0.75.1 (Fehlerbericht 13): Diagramm zeichnet mit wenigen Abfragen, ohne Abbruch
  check(F.CHART_SLOTS == 60, "0.75.1: Plaetze des Diagramms als feste Zahl")
  R.entries[7983] = { key = 7983, kind = "buyout", ref = 80, qty = 5, rows = {} }
  M.Start(7983)
  M.Add(7983, lv({ { 50, 5 }, { 80, 7 } }, 500), 0)
  M.Add(7983, lv({ { 50, 4 }, { 80, 7 } }, 600), 5)
  F.key, ns.Scan.ahOpen, F.chartN = 7983, true, nil
  F.UpdateMeasure(M.Values())
  check(F.chartN ~= nil and F.chart.frame.shown ~= false, "0.75.1: Diagramm gezeichnet (vorher Abbruch, weil die Zahl der Plaetze fehlte)")
  M.Stop()
  R.entries[7983] = nil
  F.key, ns.Scan.ahOpen = keepKey, keepOpen
  ns.Buy.live[7982] = nil
end)()

-- ===== 0.79: Aufkauf nur im ueblichen Bereich =====
;(function()
  local BO = ns.Buyout
  local keepStats, keepBand, keepCtx = ns.Sales.Stats, D.Band, BO.CTX_TIME
  local band = { trend = "calm", low = 7, high = 10 }
  ns.Sales.Stats = function() return { perHour = 70, level = 3 } end
  D.Band = function() return band end
  BO.CTX_TIME, BO.ctx = 0, {}
  mod.db.buyoutMinQty, mod.db.buyoutMinLevels, mod.db.buyoutMinSales, mod.db.buyoutHours, mod.db.dealMinMarket = 200, 5, 50, 24, 0
  mod.acc.commodity[7991] = true
  -- Beispiel aus dem Spiel (Langzahniger Matschschnapper): ueblich 7c bis 10c, darueber einzelne ueberteuerte Stufen
  local rows = D.ParseLevels("8:442;10:113;40:20;67:20;100:40;105:52;108:10;150:100")
  local d = BO.Find({ q = 797 }, rows, 7991, 1000000)
  check(d and d.ref <= 12 and d.limit <= 10 and d.qty == 442, "0.79: nur bis zur oberen Grenze kaufen, Ziel hoechstens 20 % darueber: "
    .. tostring(d and d.qty) .. " bis " .. tostring(d and d.limit) .. ", Ziel " .. tostring(d and d.ref))
  mod.db.dealMinMarket = 50
  local d2, why2 = BO.Find({ q = 797 }, rows, 7991, 1000000)
  check(d2 == nil and why2 == "gain", "0.79: mit Mindestgewinn 50s bleibt keine Chance (vorher Ziel 1s 8c mit 687 Stueck)")
  band = { trend = "calm" }
  local d3, why3 = BO.Find({ q = 797 }, rows, 7991, 1000000)
  check(d3 == nil and why3 == "band", "0.79: ohne ueblichen Bereich kein Aufkauf")
  band = { trend = "calm", low = 7, high = 10 }
  mod.db.buyoutTargetPct = 100
  local d4 = BO.Find({ q = 797 }, D.ParseLevels("8:442;10:113;19:300;40:20;67:20"), 7991, 1000000)
  check(d4 and d4.ref == 19 and d4.limit == 10 and d4.qty == 555, "0.79: Grenze fuer das Ziel einstellbar (100 %: Ziel 19c)")
  mod.db.buyoutTargetPct, mod.db.buyoutHours, mod.db.buyoutMinQty, mod.db.buyoutMinLevels, mod.db.buyoutMinSales = 20, 2, 0, 2, 0
  ns.Sales.Stats, D.Band, BO.CTX_TIME, BO.ctx = keepStats, keepBand, keepCtx, {}
end)()

-- ===== 0.82: Reiter Beobachten, Fokus mit Speichern und Zurueck =====
;(function()
  local F, Wt, WP = ns.Focus, ns.Watch, ns.WatchPage
  local keepOpen = ns.Scan.ahOpen
  ns.Scan.ahOpen = false
  D.Market(nil, true).items[7995] = { m = 150, md = 160, q = 300, n = 5, t = clock, nm = "Wachstein", ql = 1 }
  Wt.Add(7995, { name = "Wachstein" })
  Wt.SetLimit(7995, "abs", 100)
  Wt.SetUp(7995, 200)
  -- Klick in Beobachten: Fokus mit den gespeicherten Werten (unterwegs nur gemerkt)
  Win.Open("watch")
  check(Win.current == "watch" and WP.list, "0.82: Reiter Beobachten unterwegs")
  local row
  for _, r in ipairs(WP.list:GetItems()) do if r.key == 7995 then row = r end end
  check(row and row.price == 150 and row.limit == 100 and row.target == 200 and row.advice == nil, "0.82: Zeile mit Preis, Kaufen bis, Zielpreis")
  -- ab 0.92: Spalte mit Symbol statt Ueblich, Klick darauf schaltet die Warnung und waehlt nicht aus
  local cols = WP.list.o.columns
  check(cols[3].key == "limit" and cols[4].key == "muteDown" and cols[5].key == "target" and cols[6].key == "muteUp"
    and cols[4].format(false) == WP.BELL_ON and cols[6].format(true) == WP.BELL_OFF and row.muteDown == false and row.muteUp == false,
    "0.92: Symbol hinter Kaufen bis und hinter Zielpreis, Warnung an")
  local keepOver = WP.OverBell
  WP.OverBell = function() return "Down" end
  WP.list.o.onClick(row, "LeftButton")
  check(row.muteDown and Wt.Muted(7995, "Down") and not Wt.Muted(7995, "Up") and WP.selected ~= row, "0.92: Klick aufs Symbol bei Kaufen bis schaltet nur diese Warnung aus")
  WP.OverBell = function() return "Up" end
  WP.list.o.onClick(row, "LeftButton")
  check(row.muteUp and Wt.Muted(7995, "Up"), "0.92: Symbol beim Zielpreis schaltet die obere Warnung")
  WP.list.o.onClick(row, "LeftButton")
  WP.OverBell = function() return "Down" end
  WP.list.o.onClick(row, "LeftButton")
  check(not row.muteDown and not row.muteUp and not Wt.Muted(7995, "Down") and not Wt.Muted(7995, "Up"), "0.92: nochmal: wieder an")
  WP.OverBell = keepOver
  -- ab 0.83: einfacher Klick waehlt nur aus, Doppelklick oeffnet den Fokus
  local keyBefore = F.key
  WP.list.o.onClick(row, "LeftButton")
  check(WP.selected == row and F.key == keyBefore and not WP.removeButton.disabled and not WP.marketButton.disabled,
    "0.83: Klick waehlt aus, Knoepfe Entfernen und Im Markt zeigen gehen")
  check(WP.sellButton and WP.sellButton.disabled and WP.sellWhy == "Nur am Auktionator.", "0.83: Verkaufen unterwegs gesperrt, mit Grund")
  check(plain(WP.hint.text) == "Klick: auswählen, Doppelklick: Im Fokus öffnen", "0.83: Hinweis links oben")
  WP.list.o.onClick(row, "LeftButton")
  check(F.key == 7995 and F.ManualTarget(7995) == 200 and F.ManualLimit(7995) == 100 and F.manualSrc == "watch" and F.origin == "watch"
    and F.backButton.text == "Zurück zu Beobachten", "0.82: Klick in Beobachten: Fokus mit Kaufen bis und Zielpreis, zurueck zu Beobachten")
  check(F.KindText({ own = true }) == "Beobachten", "0.82: Art Beobachten")
  F.SetLimitTyped(90)
  check(F.KindText({ own = true }) == "Eigenes Ziel", "0.82: geaendert: Art Eigenes Ziel")
  -- Speichern uebernimmt die Werte
  check(F.Save() and Wt.Limit(7995) == 90 and Wt.Store()[7995].up == 200 and F.manualSrc == "watch", "0.82: Speichern aktualisiert Kaufen bis und Zielpreis")
  F.Set(7996)
  F.SetTarget(300)
  check(F.Save() and Wt.Is(7996) and Wt.Store()[7996].up == 300 and Wt.Limit(7996) == nil, "0.82: Speichern legt einen neuen Eintrag an")
  -- Herkunft Radar
  F.Set(7995)
  F.FromPage(7995, "radar")
  check(F.origin == "chances" and F.backButton.text == "Zurück zu Chancen" and F.ManualTarget(7995) == nil, "0.82/0.105: aus dem Radar: zurueck zu Chancen, ohne Werte der Beobachtung")
  F.FromPage(7995, "focus")
  check(F.origin == "chances", "0.82: naechste Chance aus dem Fokus heraus: Herkunft bleibt")
  F.origin = "watch"
  F.GoBack()
  check(Win.current == "watch", "0.82: Zurueck fuehrt zu Beobachten")
  -- Zahl am Reiter: Rat KAUFEN
  D.Market(nil, true).items[7995].m = 80
  check(WP.Count() >= 1, "0.82: Zahl am Reiter Beobachten zaehlt KAUFEN und VERKAUFEN")
  Wt.Remove(7995); Wt.Remove(7996)
  D.Market(nil, true).items[7995] = nil
  ns.Scan.ahOpen = keepOpen
  if Win.frame then Win.frame:Hide() end
end)()

-- ab 0.83: Beobachten am Auktionator laufend abfragen, Stand und Alarme
;(function()
  local Wt, WP, T = ns.Watch, ns.WatchPage, ns.AHTabs
  local function tick() local n = #timers; for i = math.max(1, n - 4), n do timers[i]() end end
  local keepOpen, keepCur = ns.Scan.ahOpen, T.current
  local mk = D.Market(nil, true)
  for _, k in ipairs({ 7997, 7998 }) do
    mk.items[k] = { m = 150, md = 160, q = 300, n = 5, t = clock, nm = "Wachstein " .. k, ql = 1 }
    mod.acc.commodity[k] = true
    Wt.Add(k, { name = "Wachstein " .. k })
    Wt.SetLimit(k, "abs", 100)
  end
  LIVE[7997] = { { unitPrice = 90, quantity = 5 }, { unitPrice = 150, quantity = 10 } }
  LIVE[7998] = { { unitPrice = 140, quantity = 5 } }
  ns.Scan.ahOpen = false
  Win.Open("watch")
  check(not Rd.Watching() and plain(WP.live.text) == ns.L.WATCH_OFF, "0.83: unterwegs keine Abfragen, Hinweis rechts oben")
  ns.Scan.ahOpen = true
  if not Rd.WatchShown() then T.current = "watch" end
  check(Rd.WatchShown() and Rd.Watching(), "0.83: Reiter Beobachten am Auktionator: laufend abfragen")
  Rd.pending, Rd.lastSend, Rd.focus, Rd.running = nil, -100, nil, false
  Rd.watchSent, Rd.watchAt = {}, {}
  Rd.loop = false
  WP.Refresh()
  check(Rd.loop, "0.83: Anzeigen der Seite startet die Schleife")
  local seen, before = {}, #out
  for _ = 1, 2 do
    now = now + 1; tick()
    local p = Rd.pending
    check(p and (p.key == 7997 or p.key == 7998) and not seen[p.key], "0.83: reihum der naechste beobachtete Gegenstand: " .. tostring(p and p.key))
    seen[p.key] = true
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", p.key)
    check(Rd.watchAt[p.key] and Rd.pending == nil, "0.83: Antwort gemerkt (Spalte Stand)")
    Rd.lastSend = -100
  end
  check(mk.items[7997].m == 90 and Wt.Store()[7997].hit and not Wt.Store()[7998].hit, "0.83: Preis aktualisiert, Alarm bei Kaufen bis")
  local alarm = false
  for i = before + 1, #out do if out[i]:find("Wachstein 7997", 1, true) then alarm = true end end
  check(alarm, "0.83: Alarm im Chat")
  local row
  for _, r in ipairs(WP.list:GetItems()) do if r.key == 7997 then row = r end end
  check(row and row.price == 90 and row.advice == "buy" and row.age and plain(WP.AgeText(row.age)) == "jetzt", "0.83: Zeile mit neuem Preis, Rat KAUFEN, Stand jetzt")
  check(plain(WP.AgeText(42)) == "vor 42 Sek." and plain(WP.AgeText(nil)) == "-", "0.83: Stand in Sekunden, ohne Abfrage Strich")
  check(plain(WP.live.text):match("^Aktualisiert laufend%.+$"), "0.83: rechts oben nur Aktualisiert laufend mit Punkten: " .. plain(WP.live.text))
  WP.dots = 3; WP.ticking = false; WP.Tick()
  check(plain(WP.live.text) == "Aktualisiert laufend.", "0.83: Punkte wandern von ... zurueck zu .")
  -- Verkaufen am Auktionator: sicherer Knopf klickt den Taschenplatz rechts an, vorher blendet Broker seinen Reiter aus
  do
    local keepCC, keepBuilt = C_Container, T.built
    T.built = true
    C_Container = setmetatable({ GetContainerNumSlots = function(bag) return bag == 0 and 4 or 0 end,
      GetContainerItemID = function(bag, slot) return (bag == 0 and slot == 2) and 7997 or nil end,
      GetContainerItemInfo = function() return { isLocked = false } end }, { __index = keepCC })
    PeonBagsItem1 = CreateFrame("Button"); PeonBagsItem1.peonBag, PeonBagsItem1.peonSlot = 0, 2
    local attr = {}
    WP.sellButton.SetAttribute = function(_, k, v) attr[k] = v end
    WP.list.o.onClick(row, "LeftButton")
    check(ns.Window.AtAH() and attr.type == "macro" and attr.macrotext == "/click PeonBagsItem1 RightButton" and not WP.sellButton.disabled,
      "0.83: Verkaufen: sicherer Knopf auf den Taschenplatz: " .. tostring(attr.macrotext))
    local closed = false
    local keepClose = T.Close
    T.Close = function() closed = true end
    T.current = "watch"
    WP.sellButton.scripts.PreClick(WP.sellButton)
    check(closed, "0.83: vor dem Klick blendet Broker seinen Reiter aus")
    T.Close = keepClose
    for _, r in ipairs(WP.list:GetItems()) do if r.key == 7998 then WP.list.o.onClick(r, "LeftButton") end end
    check(WP.sellButton.disabled and attr.type == nil and WP.sellWhy == "Der Gegenstand ist nicht in der Tasche.", "0.83: nicht in der Tasche: gesperrt, mit Grund")
    PeonBagsItem1, C_Container, T.built = nil, keepCC, keepBuilt
    WP.clickKey = nil
  end
  -- Rat neu KAUFEN: die Zeile leuchtet kurz auf, sonst keine Hintergrundfarbe
  check(row.flash == "buy" and WP.list.o.rowBg(row) == 0.38, "0.83: neuer Rat KAUFEN leuchtet kurz gruen")
  local other
  for _, r in ipairs(WP.list:GetItems()) do if r.key == 7998 then other = r end end
  check(other and other.flash == nil and WP.list.o.rowBg(other) == nil, "0.83: ohne neuen Rat keine Hintergrundfarbe")
  now = now + 2
  WP.Refresh()
  check(row.flash == nil and WP.list.o.rowBg(row) == nil, "0.83: nach 1,5 Sek. wieder ohne Farbe")
  -- laufende Antworten tauschen die Zeilen nicht aus (sonst geht ein Klick verloren)
  local items = WP.list:GetItems()
  local first = items[1]
  WP.Refresh()
  check(WP.list:GetItems() == items and WP.list:GetItems()[1] == first, "0.83: gleiche Zeilen werden nur neu gefuellt, nicht getauscht")
  -- Warnung aus: kein Chat (Haken unten links)
  check(WP.alarmCheck and WP.alarmCheck:GetChecked() and plain(WP.alarmCheck.label.text) == "Warnung", "0.83: Haken Warnung an")
  WP.alarmCheck:SetChecked(false); WP.alarmCheck.scripts.OnClick(WP.alarmCheck)
  check(mod.db.watchAlarm == false, "0.83: Haken aus speichert watchAlarm")
  Wt.Store()[7998].hit = nil
  mk.items[7998].m = 50
  local n0 = #out
  Wt.Check({ 7998 })
  local said = false
  for i = n0 + 1, #out do if out[i]:find("Wachstein 7998", 1, true) then said = true end end
  check(Wt.Store()[7998].hit and not said, "0.83: Warnung aus: Treffer gemerkt, aber keine Meldung im Chat")
  mod.db.watchAlarm = true
  -- Reiter verlassen: Schleife haelt an
  Rd.pending = nil
  T.current = "chances"
  if Win.frame then Win.frame:Hide() end
  now = now + 1; tick()
  check(not Rd.Watching(), "0.83: Reiter zu: keine Abfragen mehr")
  Wt.Remove(7997); Wt.Remove(7998)
  mk.items[7997], mk.items[7998] = nil, nil
  ns.Scan.ahOpen, T.current = keepOpen, keepCur
end)()

-- ===== 0.87: Paketvergleich im Tooltip =====
;(function()
  local P = ns.Pack
  local n1, s1 = P.ParseLine("- 16 Kupferrohre")
  check(n1 == 16 and s1 == "Kupferrohre", "0.87: Zeile '- 16 Kupferrohre' gelesen")
  local n2, s2 = P.ParseLine("|cffffffff- 4 Kupfermodulatoren |r")
  check(n2 == 4 and s2 == "Kupfermodulatoren", "0.87: Farbcodes und Leerzeichen am Ende stoeren nicht")
  check(P.ParseLine("Benötigt Stufe 10") == nil and P.ParseLine("- Kupferrohre") == nil and P.ParseLine("-16") == nil, "0.87: andere Zeilen zaehlen nicht")
  check(P.Parse({ "Benutzen: ...", "- 16 Kupferrohre" }) == nil, "0.87: ein Paket allein ist keine Auswahl")
  local n3, s3 = P.ParseLine("-: 20 schweres Leder")
  check(n3 == 20 and s3 == "schweres Leder", "0.103.3: Tippfehler '-:' im Spieltext gelesen")
  local pk = P.Parse({ "Liste:", "- 40 Magiestoff", "-: 20 schweres Leder" })
  check(pk and #pk == 2, "0.103.3: Textilien des Experten ergeben zwei Pakete")
  local mk = D.Market(nil, true)
  mk.items[7801] = { m = 300, md = 300, q = 50, n = 5, t = clock, nm = "Kupferrohr", ql = 1 }
  mk.items[7802] = { m = 500, md = 500, q = 50, n = 5, t = clock, nm = "Kupfermodulator", ql = 1 }
  mk.items[7803] = { m = 40, md = 40, q = 50, n = 5, t = clock, nm = "Eine Hand voll Kupferbolzen", ql = 1 }
  P.cache = nil
  check(P.Find("Kupferrohre") == 7801 and P.Find("Kupfermodulatoren") == 7802 and P.Find("Handvoll Kupferbolzen") == 7803, "0.87: Name gefunden, auch in der Mehrzahl")
  check(P.Find("Mithrilrohre") == nil, "0.87: unbekannter Name ergibt nichts")
  -- 0.87.3: Name nur in einem anderen Markt, im Heimatmarkt nur der Preis
  local other = D.Market("Anderer Markt", true)
  other.items[7805] = { m = 7788, t = clock, nm = "Großer leuchtender Splitter" }
  mk.items[7805] = { m = 3099, md = 3099, q = 5, n = 2, t = clock }
  P.cache = nil
  check(P.Find("große leuchtende Splitter") == 7805, "0.87.3: Name aus einem anderen Markt")
  -- 0.87.3: Eintrag ganz ohne Namen: das Spiel nennt ihn (Stub: 'Gegenstand7806')
  mk.items[7806] = { m = 77, md = 77, q = 5, n = 2, t = clock }
  check(P.Find("Gegenstand7806") == 7806 and mk.items[7806].nm == "Gegenstand7806", "0.87.3: Name vom Spiel nachgefragt und gemerkt")
  D.DeleteMarket("Anderer Markt")
  mk.items[7805], mk.items[7806] = nil, nil
  P.cache = nil
  local keepCount = C_Item.GetItemCount
  local BAGS = { [7801] = 10 }
  C_Item.GetItemCount = function(id) return BAGS[id] or 0 end
  -- 0.87.1: im Spiel steht die Liste mit Zeilenumbruechen in einer einzigen Tooltip-Zeile
  local KISTE_RAW = { "Abgefangene Kiste: Bauteile des Lehrlings", "Benötigt Stufe 10",
    "|cff00ff00Benutzen: Füllt die Kiste mit einem beliebigen Paket von der folgenden Liste:\n- 16 Handvoll Kupferbolzen\n- 16 Kupferrohre\n- 4 Kupfermodulatoren|r" }
  local rawData = { lines = {} }
  for i, t in ipairs(KISTE_RAW) do rawData.lines[i] = { leftText = t } end
  local KISTE = P.TooltipTexts(GameTooltip, rawData)
  check(#P.Parse(KISTE) == 3, "0.87.1: Liste in einer Tooltip-Zeile mit Zeilenumbruechen wird geteilt")
  check(P.Norm("Eine Hand voll Kupferbolzen") == P.Norm("Handvoll Kupferbolzen"), "0.87.1: 'Eine Hand voll' passt zu 'Handvoll'")
  check(P.Norm("Kleiner leuchtender Splitter") == P.Norm("kleine leuchtende Splitter"), "0.87.2: gebeugte Woerter passen (Splitter)")
  check(P.Norm("Große Astralessenz") == P.Norm("große Astralessenzen"), "0.87.2: Mehrzahl mit Adjektiv (Astralessenz)")
  check(P.Norm("Öliger Schuppen") == P.Norm("ölige Schuppen"), "0.87.2: Umlaut am Anfang")
  check(P.Norm("Kupferrohr") ~= P.Norm("Kupfermodulator") and P.Norm("Großer Splitter") ~= P.Norm("Kleiner Splitter"), "0.87.2: verschiedene Teile bleiben verschieden")
  check(not P.RightText({ cost = 5, have = 0, need = 1, best = true }):find("←", 1, true), "0.87.2: kein Pfeilzeichen mehr (Kasten im Spiel)")
  local list = P.Calc(P.Parse(KISTE))
  check(list[1].id == 7803 and list[1].cost == 640 and list[1].best, "0.87: Bolzen 16 x 40c = 6s 40c, am guenstigsten, steht oben")
  check(list[2].id == 7801 and list[2].have == 10 and list[2].need == 6 and list[2].cost == 1800, "0.87: Rohre: 10 in den Taschen, 6 x 3s fehlen")
  check(list[3].cost == 2000 and not list[3].best, "0.87: Modulatoren 4 x 5s")
  BAGS[7801] = 20
  list = P.Calc(P.Parse(KISTE))
  check(list[1].id == 7801 and list[1].cost == 0 and list[1].best, "0.87: genug Rohre in den Taschen: kostenlos und markiert")
  check(plain(P.RightText(list[1])):find("vorhanden", 1, true), "0.87: Text 'vorhanden'")
  mk.items[7802] = nil; P.cache = nil
  list = P.Calc(P.Parse(KISTE))
  check(list[3].name == "Kupfermodulatoren" and list[3].cost == nil and plain(P.RightText(list[3])):find("kein Preis", 1, true), "0.87: ohne Preis am Ende, 'kein Preis'")
  -- ganzer Tooltip ueber die Tooltip-Daten
  local data = rawData
  tt.lines, tt.link = {}, "|cff1eff00|Hitem:7800::::::::20:1488:::::::::|h[Abgefangene Kiste]|h|r"
  ttCallback(GameTooltip, data)
  local txt = {}
  for i, l in ipairs(tt.lines) do txt[i] = plain(l) end
  local head, rohr
  for i, l in ipairs(txt) do
    if l:find("Pakete (Kosten)", 1, true) then head = true end
    if l:find("16× Kupferrohre", 1, true) and tt.lines[i]:find("ReadyCheck-Ready", 1, true) then rohr = true end
  end
  check(head and rohr, "0.87: Tooltip zeigt Pakete, Rohre markiert")
  mod.db.tooltipPacks = false
  tt.lines = {}
  ttCallback(GameTooltip, data)
  local any = false
  for _, l in ipairs(tt.lines) do if plain(l):find("Pakete", 1, true) then any = true end end
  check(not any, "0.87: Schalter aus: kein Paketvergleich")
  mod.db.tooltipPacks = true
  -- 0.88: vorgeschlagenes Paket ueber das Peon-Menue auf die Liste Handelsauftrag
  BAGS[7801] = 10
  tt.lines = {}
  ttCallback(GameTooltip, data)
  local hint = false
  for _, l in ipairs(tt.lines) do if plain(l):find("Strg+Rechtsklick", 1, true) then hint = true end end
  check(hint, "0.88: Tooltip nennt das Peon-Menue")
  check(P.ForItem({ id = 7800 }) ~= nil and P.ForItem({ id = 7801 }) == nil, "0.88: Menue kennt die Pakete der zuletzt gezeigten Kiste")
  local buttons = {}
  local sub = { CreateButton = function() end, CreateRadio = function() end, CreateCheckbox = function() end, CreateDivider = function() end }
  setmetatable(sub, { __index = function() return function() return sub end end })
  local root = { CreateButton = function(_, text, fn) buttons[#buttons + 1] = { text = text, fn = fn } return sub end,
    CreateDivider = function() end, CreateTitle = function() end }
  sub.CreateButton = function() return sub end
  ns.Menu.Build(root, { id = 7800, link = tt.link, name = "Abgefangene Kiste" })
  check(buttons[1] and plain(buttons[1].text) == "Auf „Handelsauftrag“: 16× Handvoll Kupferbolzen", "0.88: erster Menuepunkt ist das guenstigste Paket")
  local lists = ns.Buy.Lists()
  local before = #lists
  buttons[1].fn()
  local hl = lists[#lists]
  check(#lists == before + 1 and hl.name == "Handelsauftrag" and hl.items[7803] and hl.items[7803].wish == 16, "0.88: Liste Handelsauftrag angelegt, 16 Bolzen gewuenscht")
  check(said("16× Gegenstand7803 auf der Liste „Handelsauftrag“"), "0.88: Meldung im Chat")
  buttons[1].fn()
  check(#lists == before + 1 and hl.items[7803].wish == 16, "0.88: zweimal: keine zweite Liste, Menge bleibt")
  local n0 = 0; for _ in pairs(hl.items) do n0 = n0 + 1 end
  check(n0 == 1, "0.88: nur das eine Paket auf der Liste")
  ns.Buy.DeleteList(#lists)
  -- alles schon da: kein Menuepunkt, kein Hinweis
  BAGS[7801], BAGS[7803] = 20, 16
  tt.lines = {}
  ttCallback(GameTooltip, data)
  buttons = {}
  ns.Menu.Build(root, { id = 7800, link = tt.link })
  check(not plain(buttons[1].text):find("Handelsauftrag", 1, true), "0.88: Paket schon vorhanden: kein Menuepunkt")
  BAGS[7803] = nil
  C_Item.GetItemCount = keepCount
  mk.items[7801], mk.items[7803] = nil, nil
  P.cache = nil
end)()

-- ===== 0.91: Chance einschaetzen (Fehlerbericht 17) =====
;(function()
  local Ra, Rd = ns.Rating, ns.Radar
  PeonBrokerDB.ratings = nil
  Rd.entries[2770] = { key = 2770, kind = "buyout", qty = 12, gain = 345, ref = 99, name = "Kupfererz", rows = { { price = 1 } } }
  check(Ra.Open({ id = 2770, name = "Kupfererz" }) and Ra.win and Ra.win:IsShown(), "0.91: Fenster Einschaetzen geht auf")
  check(Ra.win.save.disabled, "0.91: Speichern erst mit Auswahl")
  Ra.win.rate = "bad"; Ra.UpdateSave()
  Ra.win.note:SetText("  zu wenig Absatz  ")
  Ra.Save()
  local r = PeonBrokerDB.ratings and PeonBrokerDB.ratings[1]
  check(r and r.key == 2770 and r.rate == "bad" and r.note == "zu wenig Absatz" and r.radar and r.radar.kind == "buyout"
    and r.radar.gain == 345 and r.radar.rows == nil and r.data and r.data.m and r.market, "0.91: gespeichert mit Daten und Vorschlag des Radars")
  check(not Ra.win:IsShown() and said("Einschätzung gespeichert: Kupfererz, Schlecht"), "0.91: Meldung im Chat, Fenster zu")
  Rd.entries[2770] = nil
  local r2 = Ra.Add(2770, "Kupfererz", "good", "")
  check(r2.radar == nil and r2.note == nil and Ra.Last(2770) == r2, "0.91: ohne Vorschlag, leere Bemerkung")
  PeonBrokerDB.ratings = nil
end)()

-- ===== 0.93: Kandidaten vom Peon Manager (Spec.lua, Peon_Manager_Chancen.md 9.2) =====
;(function()
  local Sp, R, D = ns.Spec, ns.Radar, ns.Data
  local x = Sp.Parse("s:500:900:" .. (time() + 3600) .. ":1200:2:3")
  check(x and x.mk == "s" and x.limit == 500 and x.target == 900 and x.gain == 1200 and x.risk == "high" and x.qty == 3, "0.93: Eintrag des Managers gelesen")
  check(Sp.Parse("x:1:2:3:4:0") == nil and Sp.Parse("s:1:2:3:4:0").qty == nil, "0.93: falsche Art abgelehnt, Menge darf fehlen")
  local fake = { Chances = function(self, market)
    return 1000, { ["2770"] = "s:500:900:" .. (time() + 3600) .. ":1200:1", ["2771"] = "s:500:900:" .. (time() - 10) .. ":1200:1", ["2772"] = "b:10:12:" .. (time() + 3600) .. ":5000:0" },
      { ["2770"] = "Liegt 40 % unter dem, wofuer er zuletzt verkauft wurde." }
  end }
  local orig = Peon.GetModule
  Peon.GetModule = function(self, k) if k == "bridge" then return fake end return orig(self, k) end
  Sp.cache = nil
  local all = Sp.All()
  check(all[2770] and all[2770].say and all[2771] == nil and all[2772], "0.93: abgelaufene Eintraege ignoriert")
  check(R.KIND_ON.spec == true, "0.93: Art Spekulation an")
  local rows = { { price = 400, qty = 1 }, { price = 480, qty = 1 }, { price = 800, qty = 2 } }
  local d = Sp.Find(nil, rows, 2770)
  check(d and d.kind == "spec" and d.qty == 2 and d.limit == 480 and d.ref == 900 and d.gain == math.floor(math.floor(900 * (1 - D.Cut())) * 2 - 880), "0.93: Spekulation aus den Preisstufen")
  check(Sp.Find(nil, { { price = 600, qty = 1 } }, 2770) == nil, "0.93: nichts bis Kaufen bis: weg")
  check(Sp.Find(nil, rows, 2772) == nil, "0.93: Aufkauf prueft Broker selbst")
  local modes = {}
  for _, m in ipairs(R.MODES()) do modes[m[1]] = true end
  check(modes.mgr == nil and modes.mass and type(R.SearchKeys("mgronly")) == "table", "0.96: Radar-Scan ohne Vom Manager, Alle pruefen im Reiter Chancen")
  local txt = Sp.FocusText(2770)
  check(txt and txt:find("Liegt 40 %%") and txt:find("Vom Manager"), "0.93: Satz und Stand im Fokus")
  local snapRadar = R.entries[2770]
  R.entries[2770] = { kind = "spec", mk = "s", gain = 1, qty = 1 }
  local r = ns.Rating.Add(2770, "Kupfererz", "good", "")
  check(r.kind == "s" and r.say and r.say:find("Liegt"), "0.93: Einschaetzung mit Art und Satz")
  R.entries[2770] = snapRadar
  PeonBrokerDB.ratings = nil
  Peon.GetModule = orig
  Sp.cache = nil
  check(ns.Calendar and ns.Calendar.Time({ year = 2026, month = 11, monthDay = 20, hour = 10, minute = 0 }) == time({ year = 2026, month = 11, day = 20, hour = 10, min = 0, sec = 0 }), "0.93: Zeit aus dem Kalender")
end)()

-- ===== 0.96: Reiter Chancen (Chances.lua, Peon_Chancen_Reiter_Muster.md 3) =====
;(function()
  local Sp, R, C, S = ns.Spec, ns.Radar, ns.Chances, ns.Settings
  local now = time()
  -- Muster mit Zeitfenstern: kaufen jeden Tag 0 bis 3 Uhr, verkaufen samstags
  local m = Sp.Parse("m:700:1100:" .. (now + 3600) .. ":1600:0:4:127/0:32/-1")
  check(m and m.mk == "m" and m.qty == 4 and m.buyWin and m.buyWin.mask == 127 and m.buyWin.slot == 0 and m.sellWin.mask == 32 and m.sellWin.slot == -1,
    "0.96: Muster mit Fenstern gelesen")
  check(Sp.Parse("v:1:2:3:4:0") == nil, "0.96: Haendler kommt nicht mehr vom Manager")
  check(C.WindowText(m.buyWin) == "0 bis 3 Uhr" and C.WindowText(m.sellWin) == "Samstag", "0.96: Fenster als Text")
  local sat3 = time({ year = 2026, month = 11, day = 21, hour = 1, min = 30 })   -- Samstag 1:30
  local mon10 = time({ year = 2026, month = 11, day = 16, hour = 10, min = 0 })  -- Montag 10:00
  check(C.InWindow(m.buyWin, sat3) and not C.InWindow(m.buyWin, mon10) and C.InWindow(m.sellWin, sat3) and not C.InWindow(m.sellWin, mon10),
    "0.96: Zeit im Fenster")
  local fake = { Chances = function()
    return now - 7200, { ["2770"] = "s:500:900:" .. (now + 3600) .. ":1200:1:2", ["2771"] = "m:700:1100:" .. (now + 3600) .. ":1600:0:4:127/0:32/-1" },
      { ["2770"] = "Liegt 40 % unter dem, wofuer er zuletzt verkauft wurde." }
  end }
  local orig = Peon.GetModule
  Peon.GetModule = function(self, k) if k == "bridge" then return fake end return orig(self, k) end
  Sp.cache = nil
  local knownOrig = ns.Buy.KnownKey
  ns.Buy.KnownKey = function() return true end
  local keys = C.Keys()
  check(#keys == 2 and keys[1] == 2771, "0.96: Kandidaten, hoechster Gewinn zuerst")
  mod.db.chancesShowM = false
  check(#C.Keys() == 1, "0.96: Art Muster abschaltbar")
  mod.db.chancesShowM = true
  -- Zustand: ungeprueft, nach einer Antwort bestaetigt oder weg
  C.checked = {}
  local rows = C.Rows()
  local by = {}
  for _, r in ipairs(rows) do by[r.key] = r end
  check(by[2770] and by[2770].state == "new" and by[2771], "0.96: zuerst ungeprueft")
  C.Note(2770, { showGain = 999 }, { { price = 450, qty = 1 } })
  C.Note(2771, nil, {})
  by = {}
  for _, r in ipairs(C.Rows()) do by[r.key] = r end
  check(by[2770].state == "ok" and by[2770].gain == 999 and by[2771].state == "gone", "0.96: bestaetigt mit Live-Gewinn, sonst weg")
  check(C.StateText(by[2770]):find("bestätigt", 1, true), "0.96: Zustand als Text")
  -- Radar zeigt die Kandidaten nicht, Chancen schon
  check(R.Visible({ kind = "spec", gain = 5, qty = 1, cost = 1 }, 1e9) == false, "0.96: Radar ohne Kandidaten vom Manager")
  -- Hinweis beim Oeffnen des Auktionshauses (ab 0.101 zaehlt Verworfenes nicht mit, hier nur der Hinweis)
  PeonBrokerDB.chancesGone = nil
  local n0 = #out
  C.OnAHShow()
  check(#out == n0 + 1 and out[#out]:find("2 Chancen vom Peon Manager warten", 1, true), "0.96: Hinweis beim Oeffnen")
  mod.db.chancesAhNote = false
  local n1 = #out
  C.OnAHShow()
  check(#out == n1, "0.96: Hinweis abschaltbar: " .. tostring(out[#out]) .. " / " .. tostring(mod.db.chancesAhNote))
  mod.db.chancesAhNote = true
  -- Einstellungen
  S.Toggle("chances")
  local f = S.frames.chances
  local found = {}
  for _, c in ipairs(f.controls) do if c.row[2] then found[c.row[2]] = true end end
  check(f:IsShown() and found.chancesShowS and found.chancesShowM and found.chancesAhNote and found.chancesNotify, "0.96: Fenster Einstellungen Chancen")
  S.Hide("chances")
  C.checked = {}
  ns.Buy.KnownKey = knownOrig
  Peon.GetModule = orig
  Sp.cache = nil
end)()

-- ===== 0.101: verworfene Chancen merken (Chances.lua, Wunsch KarloDerBaer 17.11.2026) =====
;(function()
  local Sp, C = ns.Spec, ns.Chances
  local now = time()
  local stand = now - 1800
  local fake = { Chances = function()
    return stand, { ["2770"] = "s:500:900:" .. (now + 3600) .. ":1200:1:2", ["2772"] = "b:10:12:" .. (now + 3600) .. ":5000:0",
                    ["2773"] = "s:500:900:" .. (now + 3600) .. ":800:1" }, {}
  end }
  local orig = Peon.GetModule
  Peon.GetModule = function(self, k) if k == "bridge" then return fake end return orig(self, k) end
  Sp.cache = nil
  local knownOrig = ns.Buy.KnownKey
  ns.Buy.KnownKey = function() return true end
  C.checked, C.goneNow, PeonBrokerDB.chancesGone = {}, {}, nil
  local function byKey() local by = {} for _, r in ipairs(C.Rows()) do by[r.key] = r end return by end
  -- weg: gemerkt mit Stand, Zeit und Angebot, bleibt bis zum Verlassen als "weg" stehen
  C.Note(2770, nil, { { price = 650, qty = 1 } })
  local store = PeonBrokerDB.chancesGone and PeonBrokerDB.chancesGone[ns.MarketKey()]
  local g = store and C.ParseGone(store[2770])
  check(g and g.stand == stand and math.abs(g.t - now) <= 2 and g.offer == 650, "0.101: weg mit Stand, Zeit und Angebot gemerkt")
  check(byKey()[2770] and byKey()[2770].state == "gone", "0.101: gerade verworfen steht noch als weg da")
  C.Leave()
  check(byKey()[2770] == nil and byKey()[2773] ~= nil, "0.101: nach dem Verlassen ausgeblendet")
  local keys = C.Keys()
  local inKeys = false
  for _, k in ipairs(keys) do if k == 2770 then inKeys = true end end
  check(not inKeys and C.HiddenCount() == 1, "0.101: nicht mehr pruefen, einmal gezaehlt")
  check(C.StatusText():find("1 weg bis zum nächsten Stand", 1, true), "0.101: Zahl im Status")
  -- Reload: Sitzung leer, Eintrag bleibt
  C.checked, C.goneNow = {}, {}
  Sp.cache = nil
  check(byKey()[2770] == nil, "0.101: nach dem Reload weiter ausgeblendet")
  -- Aufkauf bei abgeschaltetem Aufkauf im Radar: nichts merken
  mod.db.radarBuyoutOn = false
  C.Note(2772, nil, {})
  check(store[2772] == nil, "0.101: Aufkauf aus im Radar, Pruefung sagt nichts")
  mod.db.radarBuyoutOn = nil
  -- wieder da: vergessen
  C.Note(2773, nil, {})
  check(C.ParseGone(store[2773]).offer == 0, "0.101: keine Angebote: Angebot 0")
  C.Note(2773, { gain = 300 }, { { price = 400, qty = 1 } })
  check(store[2773] == nil and byKey()[2773].state == "ok", "0.101: bestaetigt nimmt den Eintrag weg")
  -- neuer Stand des Managers: Chance kommt zurueck, Eintrag wird beim Aufraeumen entfernt
  stand = now - 60
  Sp.cache = nil
  C.checked = {}
  check(byKey()[2770] ~= nil and byKey()[2770].state == "new", "0.101: neuer Stand bringt die Chance zurueck")
  C.Prune()
  check(PeonBrokerDB.chancesGone == nil, "0.101: alter Eintrag aufgeraeumt")
  -- sehr alte Eintraege anderer Maerkte fallen ebenfalls weg
  PeonBrokerDB.chancesGone = { ["Anderer / Horde"] = { [1] = "100:" .. (now - 4 * 86400) .. ":0", [2] = "100:" .. (now - 3600) .. ":0" } }
  C.Prune()
  check(PeonBrokerDB.chancesGone["Anderer / Horde"][1] == nil and PeonBrokerDB.chancesGone["Anderer / Horde"][2], "0.101: nach 3 Tagen entfernt")
  PeonBrokerDB.chancesGone = nil
  C.checked, C.goneNow = {}, {}
  ns.Buy.KnownKey = knownOrig
  Peon.GetModule = orig
  Sp.cache = nil
end)()

-- ===== 0.102.0: Chancen mit Varianten ohne gelernten Schluessel (Rueckmeldung KarloDerBaer 17.11.2026) =====
;(function()
  local Sp, C, R = ns.Spec, ns.Chances, ns.Radar
  local now = time()
  local kA, kB, kC = "2780:Kette der Beweglichkeit", "2781:Ring des Adlers", "2782:Umhang des Affen"
  local fake = { Chances = function()
    return now - 600, { [kA] = "s:500:900:" .. (now + 3600) .. ":3000:1", [kB] = "s:500:900:" .. (now + 3600) .. ":2000:1",
                        [kC] = "s:500:900:" .. (now + 3600) .. ":1000:1" }, {}
  end }
  local orig = Peon.GetModule
  Peon.GetModule = function(self, k) if k == "bridge" then return fake end return orig(self, k) end
  Sp.cache = nil
  local savedAH, savedOpen, savedKeys = rawget(_G, "C_AuctionHouse"), ns.Scan.ahOpen, PeonBrokerDB.itemKeys
  local ah = savedAH or {}
  C_AuctionHouse = ah
  local sBQ, sGBR, sGIKI = ah.SendBrowseQuery, ah.GetBrowseResults, ah.GetItemKeyInfo
  ns.Scan.ahOpen = true
  PeonBrokerDB.itemKeys = nil
  C.checked, C.goneNow, C.learnAt, C.learnTries, PeonBrokerDB.chancesGone = {}, {}, {}, {}, nil
  local function inKeys(k) for _, x in ipairs(C.Keys()) do if x == k then return true end end return false end
  check(not inKeys(kA) and C.NextLearn() == kA, "0.102: Variante ohne Schluessel nicht abfragbar, zuerst lernen (hoechster Gewinn)")
  -- gefunden: Schluessel gelernt, ab jetzt normal pruefen
  local browsed
  local names = { [5] = "Kette der Beweglichkeit", [6] = "Kette des Baeren", [7] = "Ring des Baeren" }
  ah.SendBrowseQuery = function(q) browsed = q end
  ah.GetItemKeyInfo = function(k) return names[k.itemSuffix] and { itemName = names[k.itemSuffix] } or nil end
  ah.GetBrowseResults = function() return { { itemKey = { itemID = 2780, itemLevel = 30, itemSuffix = 5 }, minPrice = 400, totalQuantity = 1 },
      { itemKey = { itemID = 2780, itemLevel = 30, itemSuffix = 6 }, minPrice = 700, totalQuantity = 1 } } end
  R.pending = nil
  check(R.LearnChance(kA) and R.pending and R.pending.browse and browsed, "0.102: Browse-Suche gestartet")
  fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
  check(R.pending == nil and PeonBrokerDB.itemKeys[kA] == "30:5" and inKeys(kA) and C.checked[kA] == nil,
      "0.102: Schluessel gelernt, Chance steht zum Pruefen an")
  check(C.NextLearn() == kB, "0.102: danach die naechste Variante")
  -- andere Varianten mit Namen da, diese nicht: weg
  ah.GetBrowseResults = function() return { { itemKey = { itemID = 2781, itemLevel = 30, itemSuffix = 7 }, minPrice = 400, totalQuantity = 1 } } end
  R.LearnChance(kB)
  fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
  local rows = {}
  for _, r in ipairs(C.Rows()) do rows[r.key] = r end
  check(rows[kB] and rows[kB].state == "gone" and C.NextLearn() == kC, "0.102: Variante nicht dabei: weg")
  -- Namen noch nicht geladen: nicht weg, spaeter nochmal
  names[8] = nil
  ah.GetBrowseResults = function() return { { itemKey = { itemID = 2782, itemLevel = 30, itemSuffix = 8 }, minPrice = 400, totalQuantity = 1 } } end
  R.LearnChance(kC)
  fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
  check(C.checked[kC] == nil and C.learnTries[kC] == 1 and C.NextLearn() == nil, "0.102: Namen fehlen: nicht weg, erst spaeter nochmal")
  C.learnAt[kC] = C.learnAt[kC] - C.LEARN_AGAIN
  check(C.NextLearn() == kC, "0.102: nach der Pause neuer Versuch")
  -- gar nichts gefunden: nach der Wartezeit weg
  ah.GetBrowseResults = function() return {} end
  R.LearnChance(kC)
  fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
  timers[#timers]()
  check(C.checked[kC] and C.checked[kC].ok == false and R.pending == nil, "0.102: keine Angebote: weg")
  ah.SendBrowseQuery, ah.GetBrowseResults, ah.GetItemKeyInfo = sBQ, sGBR, sGIKI
  C_AuctionHouse, ns.Scan.ahOpen, PeonBrokerDB.itemKeys = savedAH, savedOpen, savedKeys
  C.checked, C.goneNow, C.learnAt, C.learnTries, PeonBrokerDB.chancesGone = {}, {}, {}, {}, nil
  R.pending = nil
  Peon.GetModule = orig
  Sp.cache = nil
end)()

-- 0.94: Schnittstelle fuer Peon_Profession (Kaufpreis, Einkaufsliste mit festem Namen)
;(function()
  local p, src = mod:BuyPrice(123456789)
  check(p == nil and (src == "none" or src == nil), "0.94: BuyPrice ohne Preis")
  check(mod:BuyPrice("x") == nil, "0.94: BuyPrice nur mit Nummer")
  local before = #ns.Buy.Lists()
  local n, list = mod:AddToList("Beruf: Alchimie", { { id = 2449, n = 20 }, { id = 3371, n = 10 }, { id = 765, n = 0 } })
  check(n == 2 and list and list.name == "Beruf: Alchimie" and #ns.Buy.Lists() == before + 1, "0.94: Liste angelegt, Menge 0 ausgelassen")
  check(list.items[2449].wish == 20 and list.items[3371].wish == 10 and list.items[765] == nil, "0.94: Wunschmenge gesetzt")
  check(type(list.items[2449].t) == "table" and list.items[2449].t.wish, "0.94: Zeit je Wert fuer den Manager")
  n = mod:AddToList("Beruf: Alchimie", { { id = 2449, n = 8 } })
  check(n == 1 and #ns.Buy.Lists() == before + 1 and list.items[2449].wish == 8, "0.94: gleiche Liste, Menge ersetzt")
  check(mod:AddToList("", {}) == 0, "0.94: ohne Namen nichts")
  ns.Buy.DeleteList(#ns.Buy.Lists())
end)()

-- ===== 0.104: Kaufknopf nach Kauf und "schon weg", Lockangebote beim Verkaufen, Schnellkauf =====
;(function()
  local F, Q, L, A, M = ns.Focus, ns.Quick, ns.L, ns.Advice, ns.Measure
  local function R(p, q, own) return { price = p, qty = q, own = own or 0 } end
  -- Stufen nach Kauf und "weg"
  local rows = { R(100, 1), R(150, 20), R(160, 50, 2), commodity = true }
  local r2 = Rd.TakeRows(rows, 5)
  check(r2[1].qty == 0 and r2[2].qty == 16 and r2[3].qty == 50 and rows[1].qty == 1 and r2.commodity,
    "0.104: Kauf nimmt die guenstigsten Stueck aus einer Kopie der Stufen")
  local r3 = Rd.TakeRows(rows, nil)
  check(r3[1].qty == 0 and r3[2].qty == 20, "0.104: schon weg: die guenstigste fremde Stufe faellt ganz weg")
  -- Lockangebote erkennen
  local db = { baitQty = 5, baitPct = 2, baitGap = 10 }
  local b = D.SkipBait({ R(100, 1), R(150, 200) }, db)
  check(b and b.price == 150 and b.qty == 1 and b.top == 100, "0.104: 1 Stueck weit unter der naechsten Stufe ist ein Lockangebot")
  b = D.SkipBait({ R(100, 1), R(108, 2), R(150, 500) }, db)
  check(b and b.price == 150 and b.qty == 3 and b.top == 108, "0.104: zwei kleine Stufen zaehlen zusammen")
  check(D.SkipBait({ R(100, 1), R(105, 200) }, db) == nil, "0.104: kleiner Abstand zur naechsten Stufe: kein Lockangebot")
  check(D.SkipBait({ R(100, 50), R(150, 200) }, db) == nil, "0.104: grosse Menge: kein Lockangebot")
  b = D.SkipBait({ R(100, 30), R(150, 2000) }, db)
  check(b and b.price == 150 and b.qty == 30, "0.104: unter 2 % aller Angebote zaehlt auch mit mehr als 5 Stueck")
  check(D.SkipBait({ R(100, 1, 1), R(150, 200) }, db) == nil, "0.104: eigenes Angebot ist kein Lockangebot")
  check(mod.db.baitQty == 5 and mod.db.baitPct == 2 and mod.db.baitGap == 10, "0.104: Grenzen mit Vorgaben in den Einstellungen")
  -- Verkaufen: Knoepfe und Rat
  -- ab 0.120: nur bei Massenware (Ring mit 1 zu 6g 74s unter 2 zu 7g 50s ist kein Lockangebot)
  mod.acc.commodity[7970] = false
  A.liveRows = { key = 7970, rows = { R(100, 1), R(150, 2) } }
  check(A.Bait(7970) == nil, "0.120: Einzelgegenstand: kein Schutz vor Lockangeboten")
  mod.acc.commodity[7970] = true
  A.liveRows = { key = 7970, rows = { R(100, 1), R(150, 200) } }
  local p = A.Prices(7970, { m = 100, md = 150 }, nil, nil)
  check(p.cheap == 150 and p.bait and p.bait.qty == 1, "0.104: Knopf Guenstige geht von der ersten echten Stufe aus")
  local adv = { title = "x", kind = "sell" }
  A.CheckBait(adv, { key = 7970, price = 99 })
  check(adv.title == L.ADV_BAIT and adv.kind == "wait" and plain(adv.why):find("1 zu", 1, true), "0.104: Preis im Feld vom Lockangebot: Rat Lockangebot: " .. plain(adv.why or ""))
  adv = { title = "x", kind = "sell" }
  A.CheckBait(adv, { key = 7970, price = 149 })
  check(adv.kind == "sell" and adv.bait, "0.104: Preis ueber dem Lockangebot: Rat bleibt, Hinweis bleibt")
  check(A.Bait(7971) == nil, "0.104: Live-Angebote gelten nur fuer ihren Gegenstand")
  A.liveRows = nil
  mod.acc.commodity[7970] = nil

  -- Schnellkauf
  local keepOpen, keepMoney, keepPlay, keepCC = ns.Scan.ahOpen, GetMoney, Rd.PlayAlert, C_Container
  local ah = C_AuctionHouse
  local keep = { ah.StartCommoditiesPurchase, ah.ConfirmCommoditiesPurchase, ah.CancelCommoditiesPurchase, ah.PostCommodity, ah.ConfirmPostCommodity, ah.CancelAuction }
  GetMoney = function() return 10000000 end
  ns.Scan.ahOpen = true
  mod.acc.commodity[7971] = true
  market.items[7971] = { m = 100, md = 150, q = 71, n = 3, t = clock, nm = "Lockstoff", ql = 1 }
  Rd.entries, Rd.gone, Rd.job, Rd.buyUntil = {}, {}, nil, nil
  F.Set(7971)
  ns.Buy.live[7971] = { rows = { R(100, 1), R(150, 20), R(200, 50), commodity = true }, t = clock, commodity = true }
  Q.SetMode("quick")
  check(mod.db.focusMode == "quick" and not F.targetInput.shown and not F.rows[1].label.shown and F.quick.post.shown and F.limitLabel.shown,
    "0.104: Schnellkauf blendet Zielpreis und Angaben aus und zeigt das Lockangebot")
  check(plain(F.sectionTab.text) == L.FOCUS_MODE_QUICK and F.modeQuick.locked, "0.104: Umschalter zeigt den Modus")
  F.Update()
  check(F.ManualLimit(7971) == 75 and F.limitInput:GetAmount() == 75,
    "0.120: erstes Oeffnen: Kaufen bis = Haelfte des guenstigsten Angebots (1 Stueck ganz unten zaehlt nicht): " .. tostring(F.ManualLimit(7971)))
  check(Q.Price(7971) == 37, "0.107: Lockpreis 50 % unter Kaufen bis")
  VENDOR[7971] = 90
  check(Q.DefaultLimit(7971) == 90, "0.120: Haendlerpreis, wenn er hoeher ist")
  check(Q.DefaultLimit(7971, 400) == 200, "0.120: mit bekanntem guenstigstem Preis")
  mod.db.quickLimitPct = 80
  check(Q.DefaultLimit(7971, 400) == 320, "0.120: Anteil einstellbar")
  mod.db.quickLimitPct, VENDOR[7971] = nil, nil
  F.SetLimitTyped(0)
  check(F.ManualLimit(7971) == nil and plain(F.verdict.text) == L.QUICK_V_NOLIMIT and F.buyButton.disabled,
    "0.104/0.107: selbst geleert bleibt Kaufen bis leer, dann kauft der Schnellkauf nichts")
  F.SetLimit(150)
  local d = F.Plan()
  check(plain(F.verdict.text) == L.QUICK_V_BUY and d and d.quick and d.best.qty == 21, "0.104: alles bis Kaufen bis: 21 Stueck")
  check(plain(F.buyInfo.text) == "Menge 21, Kosten " .. plain(ns.Tooltip.Money(3100)), "0.104: ueber dem Knopf Menge und Kosten ohne Gewinn: " .. plain(F.buyInfo.text))
  check(Q.Price(7971) == 75, "0.107: Lockpreis 50 % unter Kaufen bis, nicht vom guenstigsten Angebot")
  -- Kauf, Angebot schon weg
  local started, confirmed
  ah.StartCommoditiesPurchase = function(_, n) started = n end
  ah.ConfirmCommoditiesPurchase = function() confirmed = true end
  ah.CancelCommoditiesPurchase = function() end
  F.Buy()
  check(started == 21 and Rd.job and Rd.job.quick, "0.104: Kaufknopf startet den Kauf aller 21")
  fire("COMMODITY_PRICE_UPDATED", 300, 6300)
  check(Rd.job == nil and Rd.IsStale(7971) and ns.Buy.live[7971].rows[1].qty == 0, "0.104: schon weg: Stufe faellt sofort weg, Stand gilt als veraltet")
  F.Update()
  check(plain(F.buyButton.text) == L.FOCUS_CHECKING and F.buyButton.disabled, "0.104: Kaufknopf wartet auf die frische Antwort")
  started = nil
  F.Buy()
  PeonBroker_RadarBuy()
  check(started == nil, "0.104: Klick und Taste waehrend der Pruefung starten keinen alten Kauf")
  now = now + 4
  check(not Rd.IsStale(7971), "0.104: ohne Antwort gilt der Stand nach 3 Sek. wieder")
  -- frische Antwort, Kauf klappt
  ns.Buy.live[7971] = { rows = { R(140, 10), R(200, 50), commodity = true }, t = clock, commodity = true }
  F.Update()
  check(F.Plan().best.qty == 10 and not F.buyButton.disabled, "0.104: frische Antwort: Kaufknopf wieder frei")
  F.Buy()
  check(started == 10, "0.104: Kauf von 10")
  fire("COMMODITY_PRICE_UPDATED", 140, 1400)
  check(confirmed and Rd.job and Rd.job.stage == "wait", "0.104: Preis passt: gleich bestaetigt")
  fire("COMMODITY_PURCHASE_SUCCEEDED")
  check(Rd.job == nil and ns.Buy.live[7971].rows[1].qty == 0 and not Rd.IsStale(7971), "0.104: gekaufte Menge sofort aus den Stufen")
  check(Q.sessions[7971] and Q.sessions[7971].bought == 10 and Q.sessions[7971].cost == 1400, "0.104: Kauf in der Bilanz der Sitzung")
  -- Alarm und neue Stufen
  local played
  Rd.PlayAlert = function(k) played = k end
  F.Update()
  check(played == nil and not F.buyButton.locked, "0.104: nichts unter Kaufen bis: kein Ton, Knopf leuchtet nicht")
  ns.Buy.live[7971] = { rows = { R(120, 3), R(200, 50), commodity = true }, t = clock, commodity = true }
  F.Update()
  check(played == "raid" and F.buyButton.locked and Q.IsNew(120), "0.104: neues Angebot unter Kaufen bis: Ton, Knopf leuchtet, Stufe neu")
  local newRow
  for _, it in ipairs(F.tiers.items) do if it.price == 120 then newRow = it end end
  check(newRow and newRow.isNew, "0.104: neue Stufe in der Liste markiert")
  local limBefore = F.ManualLimit(F.key)
  F.tiers.o.onClick(newRow, "LeftButton")
  F.tiers.o.onClick(newRow, "RightButton")
  check(F.ManualLimit(F.key) == limBefore and F.ManualTarget(F.key) == nil, "0.116: Klick auf eine Preisstufe aendert im Schnellkauf nichts")
  played = nil
  F.Update()
  check(played == nil, "0.104: gleiche Antwort: kein zweiter Ton")
  -- Lockangebot einstellen
  local posted
  ah.PostCommodity = function(loc, dur, qty, price) posted = { loc = loc, dur = dur, qty = qty, price = price }; return false end
  C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
    GetContainerItemID = function(_, slot) return slot == 2 and 7971 or nil end }
  check(Q.Price(7971) == 75, "0.107: Vorschlag folgt Kaufen bis, nicht dem Markt")
  Q.Post()
  check(posted and posted.qty == 1 and posted.dur == 1 and posted.price == 75 and posted.loc.slot == 2 and Q.bait.state == "posting",
    "0.104: 1 Stueck aus der Tasche, kuerzeste Laufzeit, zum Lockpreis")
  fire("AUCTION_HOUSE_AUCTION_CREATED", 555)
  check(Q.bait.state == "up" and Q.bait.id == 555 and Q.sessions[7971].baits == 1 and #Q.marks[7971] == 1, "0.104: Lockangebot steht, in Bilanz und Diagramm")
  ns.Buy.live[7971] = { rows = { R(75, 1, 1), R(120, 3), R(200, 50), commodity = true }, t = clock + 1, commodity = true }
  F.Update()
  local own
  for _, it in ipairs(F.tiers.items) do if it.isOwn then own = it end end
  check(own and own.price == 75 and Q.bait.seen and plain(F.quick.state.text):find("steht seit", 1, true), "0.104: eigenes Angebot markiert, Zustand steht: " .. plain(F.quick.state.text))
  local bal = plain(ns.Quick.BalanceText(F.key))
  check(bal:find("1 Lockangebote", 1, true) and bal:find("gekauft 10", 1, true) and not F.quick.balance.shown, "0.104/0.114: Bilanz gerechnet, Zeile Sitzung nicht gezeigt: " .. bal)
  -- zurueckziehen
  local cancelled
  ah.CancelAuction = function(id) cancelled = id end
  Q.Cancel()
  check(cancelled == 555 and Q.bait.state == "cancelling", "0.104: Zurueckziehen bricht die Auktion ab")
  fire("AUCTION_CANCELED", 555)
  check(Q.bait.state == "cancelled", "0.104: Lockangebot zurueckgezogen")
  -- weg (gekauft oder abgelaufen)
  Q.bait = { key = 7971, price = 160, state = "up", seen = true, wall = clock, t = now }
  ns.Buy.live[7971] = { rows = { R(200, 50), commodity = true }, t = clock + 2, commodity = true }
  F.Update()
  check(Q.bait.state == "gone" and plain(F.quick.state.text):find("weg", 1, true), "0.104: eigenes Lockangebot nicht mehr da: weg")
  -- Spiel fragt nach
  ah.PostCommodity = function() return true end
  local conf
  ah.ConfirmPostCommodity = function(loc, dur, qty, price) conf = price end
  Q.Post()
  check(Q.bait.state == "confirm" and plain(F.quick.post.text) == L.QUICK_CONFIRM, "0.104: Rueckfrage des Spiels: Knopf Bestaetigen")
  Q.Post()
  check(conf == Q.bait.price and Q.bait.state == "posting", "0.104: zweiter Klick bestaetigt")
  -- kein Gegenstand in der Tasche
  Q.bait = nil
  C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemID = function() return nil end }
  posted = nil
  ah.PostCommodity = function() posted = true end
  Q.Post()
  check(posted == nil and Q.bait == nil, "0.104: ohne Gegenstand in der Tasche wird nichts eingestellt")
  -- Diagramm: Menge unter Kaufen bis und eigene Lockangebote
  local function Off(list)
    local rs = { offers = {}, commodity = true }
    for i, o in ipairs(list) do rs[#rs + 1] = R(o[1], o[2]); rs.offers[i] = { id = i, q = o[2], p = o[1] } end
    return rs
  end
  M.Start(7971)
  M.Add(7971, Off({ { 200, 50 } }), 0)
  M.Add(7971, Off({ { 120, 3 }, { 200, 50 } }), 10)
  Q.marks[7971] = { 5 }
  local n, under, mins, marks = Q.Series(150)
  check(n == 2 and under[1] == 0 and under[2] == 3 and mins[2] == 120 and marks[2] and not marks[1], "0.104: Diagramm: Menge unter Kaufen bis, Preis, Strich beim Lockangebot")
  -- zurueck zum Aufkauf
  Q.SetMode("buyout")
  check(mod.db.focusMode == "buyout" and F.targetInput.shown and F.rows[1].label.shown and not F.quick.post.shown and F.modeBuyout.locked and not F.buyButton.locked,
    "0.104: Aufkauf zeigt wieder Zielpreis und Angaben")
  -- aufraeumen
  ah.StartCommoditiesPurchase, ah.ConfirmCommoditiesPurchase, ah.CancelCommoditiesPurchase, ah.PostCommodity, ah.ConfirmPostCommodity, ah.CancelAuction =
    keep[1], keep[2], keep[3], keep[4], keep[5], keep[6]
  ns.Scan.ahOpen, GetMoney, Rd.PlayAlert, C_Container = keepOpen, keepMoney, keepPlay, keepCC
  M.Stop()
  mod.acc.focusMeasure = nil
  market.items[7971], ns.Buy.live[7971], mod.acc.commodity[7971] = nil, nil, nil
  Rd.entries, Rd.gone, Rd.job, Rd.focus = {}, {}, nil, nil
  Q.bait, Q.sessions, Q.marks = nil, {}, {}
  F.SetLimit(nil)
end)()

-- ===== 0.105: Radar im Reiter Chancen (eine Liste, Scan mit Auswahl, Zahl blinkt nach dem Scan) =====
;(function()
  local Sp, R, C = ns.Spec, ns.Radar, ns.Chances
  local t0 = time()
  local fake = { Chances = function()
    return t0 - 600, { ["7101"] = "s:500:900:" .. (t0 + 3600) .. ":1200:1:2" }, {}
  end }
  local orig = Peon.GetModule
  Peon.GetModule = function(self, k) if k == "bridge" then return fake end return orig(self, k) end
  Sp.cache = nil
  local knownOrig, budgetOrig = ns.Buy.KnownKey, R.Budget
  ns.Buy.KnownKey = function() return true end
  R.Budget = function() return 1e9 end
  C.checked, C.goneNow, PeonBrokerDB.chancesGone = {}, {}, nil
  R.entries, R.gone, R.lastVisible = {}, {}, nil
  -- Treffer des Radars: 7101 ist zugleich Chance des Managers, 7102 nur im Radar
  R.entries[7101] = { key = 7101, kind = "vendor", name = "Doppelstein", gain = 300, showGain = 300, qty = 3, cost = 30, ref = 110, limit = 10, rows = {} }
  R.entries[7102] = { key = 7102, kind = "vendor", name = "Radarstein", gain = 200, showGain = 200, qty = 2, cost = 20, ref = 110, limit = 10, rows = {},
                      seenT = t0 - 120 }
  local keepVis = R.Visible
  R.Visible = function(d) return d.kind ~= "spec" end
  local function byKey() local by, n = {}, 0 for _, r in ipairs(C.Rows()) do by[r.key] = r; n = n + 1 end return by, n end
  local by, n = byKey()
  check(n == 2 and by[7101] and not by[7101].radar and by[7101].kindText == "Spekulation" and by[7102] and by[7102].radar and by[7102].kindText == "Händler",
    "0.105: eine Liste: Chance des Managers ohne Doppel, Treffer des Radars dazu (" .. tostring(by[7101] and by[7101].kindText) .. ")")
  check(C.StateText(by[7102]):find("Scan vor 2 Min.", 1, true), "0.105: Treffer aus dem Scan mit Alter: " .. plain(C.StateText(by[7102])))
  -- Live-Pruefung aktualisiert die Chance des Managers
  R.entries[7101].risk = "mid"
  C.Note(7101, { showGain = 777 }, { { price = 5, qty = 3 } })
  by = byKey()
  check(by[7101].state == "ok" and by[7101].gain == 777 and by[7101].risk == "mid" and not by[7101].radar, "0.105: Live-Pruefung aktualisiert die Chance des Managers, mit Risiko")
  -- verworfene Chance des Managers bleibt ausgeblendet, auch wenn das Radar etwas findet
  C.Note(7101, nil, {})
  C.goneNow = {}
  by, n = byKey()
  check(by[7101] == nil and n == 1, "0.105: verworfene Chance erscheint nicht als Treffer des Radars")
  C.checked, PeonBrokerDB.chancesGone = {}, nil
  -- Erneuern: Chancen des Managers und Treffer des Radars gemeinsam, am laengsten nicht geprueft zuerst
  -- ab 0.119: nur die Liste des offenen Unterreiters (7101 Spekulation, 7102 Haendler im Unterreiter Aufkauf)
  R.entries[7102].checked = GetTime() - 1000
  C.checked[7101] = { t = GetTime() - 5, ok = true }
  mod.db.chancesTab = "buyout"
  check(R.NextRenew() == 7102, "0.105/0.119: Erneuern im Unterreiter Aufkauf nimmt den Treffer des Radars")
  mod.db.chancesTab = "spec"
  check(R.NextRenew() == nil, "0.119: im Unterreiter Spekulation nicht den Treffer des Radars")
  C.checked[7101] = { t = GetTime() - 5000, ok = true }
  check(R.NextRenew() == 7101, "0.105/0.119: ... dort die Chance des Managers")
  check(#C.TabRows("spec") == 1 and C.TabRows("spec")[1].key == 7101 and #C.TabRows("buyout") == 1 and C.TabRows("buyout")[1].key == 7102,
    "0.119: Zeilen je Unterreiter")
  -- ab 0.120: R.Refresh fuellt die Liste nur mit dem offenen Unterreiter (bis 0.119 standen Spekulationen im Aufkauf)
  do
    local keepList, keepShown, keepView = C.list, C.Shown, C.UpdateView
    local got
    C.list = { SetData = function(_, rows) got = rows end }
    C.Shown, C.UpdateView = function() return true end, function() end
    mod.db.chancesTab = "buyout"
    R.Refresh()
    local keys = {}
    for _, r in ipairs(got or {}) do keys[#keys + 1] = tostring(r.key) end
    check(table.concat(keys, ",") == "7102", "0.120: Radar zeigt im Unterreiter Aufkauf keine Spekulation: " .. table.concat(keys, ","))
    C.list, C.Shown, C.UpdateView = keepList, keepShown, keepView
  end
  mod.db.chancesTab = "buyout"
  -- Auswahl des Scans
  local keepAH, keepOpen = ns.Scan.ahOpen, rawget(_G, "C_AuctionHouse")
  check(C.Mode() == "mgr" and C.ModeText() == "Manager-Chancen", "0.105: Standard Manager-Chancen")
  local started = 0
  local keepStart = R.Start
  R.Start = function() started = started + 1; R.running = true end
  C.CheckAll()
  check(started == 1 and R.forceMode == "mgronly", "0.105: Manager-Chancen: eine Runde ueber die Chancen")
  C.SetMode("all")
  check(not R.running and mod.db.chancesScan == "all", "0.105: andere Auswahl haelt den laufenden Scan an")
  C.CheckAll()
  check(started == 2 and R.forceMode == nil and mod.db.radarScanMode == "all", "0.105: Alles: Radar-Scan ueber alle Gegenstaende")
  C.CheckAll()
  check(not R.running, "0.105: zweiter Klick haelt an")
  R.Start = keepStart
  C.SetMode("mgr")
  mod.db.radarScanMode = "watch"
  -- Zahl blinkt nach einem Komplettscan bis zum Oeffnen
  C.OnScanDone(2)
  check(C.blink, "0.105: neue Treffer nach dem Scan: Zahl blinkt")
  C.Open()
  check(not C.blink, "0.105: geoeffnet: kein Blinken mehr")
  C.OnScanDone(0)
  check(not C.blink, "0.105: ohne Treffer kein Blinken")
  -- aufraeumen
  R.Visible, R.Budget, ns.Buy.KnownKey, Peon.GetModule = keepVis, budgetOrig, knownOrig, orig
  R.entries, R.gone, R.lastVisible = {}, {}, nil
  C.checked, C.goneNow, PeonBrokerDB.chancesGone = {}, {}, nil
  Sp.cache = nil
end)()

-- ===== 0.106: Schnellkauf ohne Hinweise, Max. Menge, Beobachten je Modus =====
;(function()
  local F, Q, Wt, WP, LT = ns.Focus, ns.Quick, ns.Watch, ns.WatchPage, ns.Lots
  local keepOpen, keepMoney = ns.Scan.ahOpen, GetMoney
  GetMoney = function() return 10000000 end
  ns.Scan.ahOpen = true
  mod.acc.commodity[7981] = true
  market.items[7981] = { m = 100, md = 150, q = 25, n = 3, t = clock, nm = "Modusstein", ql = 1 }
  Rd.entries, Rd.gone, Rd.job = {}, {}, nil
  F.Set(7981)
  ns.Buy.live[7981] = { rows = { { price = 100, qty = 5, own = 0 }, { price = 150, qty = 20, own = 0 }, commodity = true }, t = clock, commodity = true }
  Q.SetMode("quick")
  check(not F.verdict.shown and not F.why.shown and not F.relistCheck.shown and not F.qtySlider.shown and not F.qtyInput.shown
    and F.goldInput.shown and plain(F.qtyLabel.text) == "Limit pro Kauf", "0.106/0.112: Schnellkauf ohne Hinweistexte, ohne Wiedereinstellen, Limit pro Kauf als Goldfeld")
  local lim0 = F.ManualLimit(7981)
  check(lim0 == 50 and F.ManualGold(7981) == 50000 and F.manualGold.auto and plain(F.qtyHint.text) == "≥ 1000 Stück" and Q.SkipOn(7981) and Q.AvgOn(7981),
    "0.113/0.120: Vorgaben ohne gespeicherte Werte: Limit pro Kauf 5 Gold, beide Haken an: " .. plain(F.qtyHint.text))
  F.SetGoldTyped(nil)
  check(F.ManualGold(7981) == nil and plain(F.qtyHint.text) == "ohne Grenze", "0.113: selbst geleert heisst ohne Grenze und bleibt leer: " .. plain(F.qtyHint.text))
  local qp = F.goldInput.points[1]
  local lp = F.limitInput.points[1]
  check(qp and qp[2] == F.qtyLabel and qp[1] == "LEFT" and qp[3] == "LEFT" and lp and lp[2] == F.limitLabel and lp[3] == "LEFT" and qp[4] == lp[4]
    and F.qtyLabel.w == 0 and F.limitLabel.w == 0, "0.107/0.112.1: Feld buendig unter dem Goldfeld von Kaufen bis, Beschriftungen ohne feste Breite")
  F.SetLimit(150)
  F.SetGoldTyped(1500)
  check(F.Plan().best.qty == 11 and F.Plan().goldCap == 1500 and plain(F.qtyHint.text) == "≥ 10 Stück",
    "0.112: Limit pro Kauf begrenzt den Kauf (5 x 1s + 6 x 1s 50c), dahinter die Menge zu Kaufen bis: " .. plain(F.qtyHint.text))
  -- Speichern je Modus
  F.Save()
  local w = Wt.Store()[7981]
  check(w and w.qlim == 150 and w.qgold == 1500 and w.qmax == nil and w.mode == "quick" and w.lim == nil and w.up == nil, "0.106: Speichern im Schnellkauf merkt Kaufen bis und Limit pro Kauf")
  Q.SetMode("buyout")
  check(F.qtyInput.points[1][2] == F.qtySlider and F.qtyInput.shown and not F.goldInput.shown and F.ManualLimit(7981) == nil and F.ManualQty(7981) == nil and F.verdict.shown and F.relistCheck.shown and plain(F.qtyLabel.text) == "Menge",
    "0.106: Aufkauf laedt seine eigenen Werte und zeigt Urteil und Wiedereinstellen")
  F.SetLimit(120)
  F.SetTarget(200)
  F.Save()
  check(w.lim == 120 and w.up == 200 and w.mode == nil and w.qlim == 150 and w.qgold == 1500, "0.106: Speichern im Aufkauf laesst die Werte des Schnellkaufs")
  Q.SetMode("quick")
  check(F.ManualLimit(7981) == 150 and F.ManualGold(7981) == 1500 and F.ManualTarget(7981) == nil, "0.106: Umschalten laedt die Werte des Modus")
  F.Save()
  -- Fokus aus Beobachten im gespeicherten Modus, aus Chancen im Aufkauf
  Q.SetMode("buyout", true)
  F.FromPage(7981, "watch")
  check(mod.db.focusMode == "quick" and F.ManualLimit(7981) == 150 and F.origin == "watch", "0.106: aus Beobachten im gespeicherten Modus")
  F.FromPage(7981, "chances")
  check(mod.db.focusMode == "buyout", "0.106: aus Chancen immer Aufkauf")
  -- Liste Beobachten: ab 0.119 je Unterreiter, ein Gegenstand mit Werten in beiden Modi steht in beiden Listen
  local function row(tab) for _, x in ipairs(WP.Rows(tab)) do if x.key == 7981 then return x end end end
  local rq, rb = row("quick"), row("buyout")
  check(rq and rq.mode == "quick" and rq.limit == 150 and rq.target == nil and rb and rb.mode == "buyout" and rb.limit == 120 and rb.target == 200,
    "0.106/0.119: Gegenstand in beiden Listen, jede mit ihren Werten (Schnellkauf ohne Zielpreis)")
  Wt.SetMode(7981, "buyout")
  check(Wt.ActiveLimit(7981) == 120 and row("active").limit == 120, "0.106: Art Aufkauf: Alarm und Zahl am Reiter mit seinen Werten")
  Wt.SetMode(7981, "quick")
  check(Wt.ActiveLimit(7981) == 150 and row("active").limit == 150, "0.106: Alarm nimmt Kaufen bis des gespeicherten Modus")
  if WP.lists then
    local function cols(tab) local t = {} for _, c in ipairs(WP.lists[tab].o.columns) do t[#t + 1] = plain(c.title) end return table.concat(t, ",") end
    check(not cols("buyout"):find("Art", 1, true) and not cols("buyout"):find("Stand", 1, true) and cols("buyout"):find("Zielpreis", 1, true),
      "0.119: Liste Aufkauf ohne Spalte Art: " .. cols("buyout"))
    check(cols("quick"):find("Bewegung", 1, true) and cols("quick"):find("Darunter", 1, true) and cols("quick"):find("Einbrüche", 1, true)
      and not cols("quick"):find("Zielpreis", 1, true), "0.119/0.126: Liste Schnellkauf mit eigenen Spalten: " .. cols("quick"))
  end
  check(Wt.SKIP.qlim and Wt.SKIP.qgold and Wt.SKIP.qavg and Wt.SKIP.mode, "0.106: Werte des Schnellkaufs bleiben im Spiel (kein Abgleich mit dem Manager)")
  -- Stand oben rechts: juengste Einzelabfrage
  Rd.watchAt[7981] = GetTime() - 12
  check(plain(WP.LiveText()):find("Letzter Gegenstand gescannt vor: 12 s", 1, true), "0.106: ohne laufende Abfrage die juengste Einzelabfrage: " .. plain(WP.LiveText()))
  Rd.watchAt[7981] = nil
  -- Kauf aus dem Schnellkauf wird kein Posten
  LT.SetWanted(7981, true)
  Rd.job = { key = 7981, id = 7981, qty = 5, limit = 100, name = "Modusstein", stage = "wait", kind = "own", total = 500, done = 0, quick = true }
  Rd.FinishJob(true)
  check(LT.ForKey(7981) == nil, "0.106: Kauf aus dem Schnellkauf wird kein Posten")
  -- aufraeumen
  LT.SetWanted(7981, false)
  Wt.Remove(7981)
  Q.SetMode("buyout", true)
  F.SetLimit(nil)
  F.SetQty(nil)
  F.SetTarget(nil)
  ns.Scan.ahOpen, GetMoney = keepOpen, keepMoney
  market.items[7981], ns.Buy.live[7981], mod.acc.commodity[7981] = nil, nil, nil
  Rd.entries, Rd.gone, Rd.job, Rd.focus = {}, {}, nil, nil
  ns.Quick.sessions = {}
end)()

-- ===== 0.107.1: Kaufen bis im Schnellkauf auch nach Sprung aus Beobachten, Lockpreis-Prozent umgestellt =====
;(function()
  local F, Q, Wt = ns.Focus, ns.Quick, ns.Watch
  local acc = { quickBaitPct = 20 }
  mod.opts.migrate(mod, acc)
  check(acc.quickBaitPct == 50 and acc.quickBaitPct50, "0.107.1: alte Vorgabe 20 % wird einmal 50 %")
  acc = { quickBaitPct = 30 }
  mod.opts.migrate(mod, acc)
  check(acc.quickBaitPct == 30, "0.107.1: eigener Wert bleibt")
  local keepOpen, keepMoney = ns.Scan.ahOpen, GetMoney
  GetMoney = function() return 10000000 end
  ns.Scan.ahOpen = true
  mod.acc.commodity[7982] = true
  market.items[7982] = { m = 400, md = 450, q = 100, n = 3, t = clock, nm = "Flitzstein", ql = 1 }
  Wt.Add(7982, { name = "Flitzstein" })
  Wt.SetLimit(7982, "abs", 300)
  Wt.SetUp(7982, 390)
  Wt.SetMode(7982, "buyout")
  ns.Buy.live[7982] = { rows = { { price = 400, qty = 80, own = 0 }, { price = 412, qty = 10, own = 0 }, commodity = true }, t = clock, commodity = true }
  -- Fokus steht noch im Schnellkauf, Sprung aus Beobachten (gespeichert: Aufkauf)
  Q.SetMode("quick", true)
  F.Set(7982)
  F.FromPage(7982, "watch")
  check(mod.db.focusMode == "buyout" and F.ManualLimit(7982) == 300, "0.107.1: aus Beobachten im Aufkauf mit Kaufen bis 3s")
  Q.SetMode("quick")
  check(F.ManualLimit(7982) == 200 and F.limitInput:GetAmount() == 200 and Q.Price(7982) == 100,
    "0.107.1/0.120: Umschalten in den Schnellkauf fuellt Kaufen bis (Haelfte des guenstigsten), Lockpreis 50 % darunter: " .. tostring(F.ManualLimit(7982)))
  F.SetLimitTyped(0)
  Q.SetMode("buyout")
  Q.SetMode("quick")
  check(F.ManualLimit(7982) == nil, "0.107.1: selbst geleert bleibt leer, auch nach Umschalten")
  F.SetLimitTyped(250)
  check(not Q.limitCleared[7982], "0.107.1: neuer Wert hebt das Leeren auf")
  -- aufraeumen
  Wt.Remove(7982)
  Q.SetMode("buyout", true)
  F.SetLimit(nil)
  Q.limitCleared = {}
  ns.Scan.ahOpen, GetMoney = keepOpen, keepMoney
  market.items[7982], ns.Buy.live[7982], mod.acc.commodity[7982] = nil, nil, nil
  Rd.entries, Rd.gone, Rd.focus = {}, {}, nil
end)()

-- ===== 0.125.1: automatisches Kaufen bis des Schnellkaufs bleibt nicht im Aufkauf stehen =====
;(function()
  local F, Q = ns.Focus, ns.Quick
  local keepOpen, keepMoney = ns.Scan.ahOpen, GetMoney
  GetMoney = function() return 10000000 end
  ns.Scan.ahOpen = true
  mod.acc.commodity[7988] = true
  market.items[7988] = { m = 300, md = 1500, q = 200, n = 3, t = clock, nm = "Perlstein", ql = 1 }
  Rd.entries, Rd.gone, Rd.job = {}, {}, nil
  ns.Buy.live[7988] = { rows = { { price = 306, qty = 9, own = 0 }, { price = 307, qty = 5, own = 0 }, { price = 1600, qty = 3, own = 0 }, commodity = true }, t = clock, commodity = true }
  Q.SetMode("quick", true)
  F.Set(7988)
  check(F.ManualLimit(7988) == 153, "0.125.1: Schnellkauf fuellt Kaufen bis (Haelfte des guenstigsten): " .. tostring(F.ManualLimit(7988)))
  F.FromPage(7988, "chances")
  F.SetTarget(1501)
  local d = F.Plan()
  check(mod.db.focusMode == "buyout" and F.ManualLimit(7988) == nil and d and d.qty == 14,
    "0.125.1: aus Chancen im Aufkauf ohne Kaufen bis des Schnellkaufs, kauft alles unter dem Ziel: " .. tostring(F.ManualLimit(7988)) .. " / " .. tostring(d and d.qty))
  Q.SetMode("quick")
  F.SetLimit(200)
  Q.SetMode("buyout")
  check(F.ManualLimit(7988) == nil and F.ManualTarget(7988) == nil, "0.125.1: auch beim Umschalten per Knopf bleibt nichts aus dem Schnellkauf stehen")
  -- aufraeumen
  Q.SetMode("buyout", true)
  F.SetLimit(nil)
  F.SetTarget(nil)
  Q.limitCleared = {}
  ns.Scan.ahOpen, GetMoney = keepOpen, keepMoney
  market.items[7988], ns.Buy.live[7988], mod.acc.commodity[7988] = nil, nil, nil
  Rd.entries, Rd.gone, Rd.focus = {}, {}, nil
end)()

-- ===== 0.108: Marktbewegung im Schnellkauf (Zufluss, Abfluss, Bewegung, Nachwirkung des Lockangebots) =====
;(function()
  local F, Q, M = ns.Focus, ns.Quick, ns.Measure
  local keepTime = GetTime
  mod.acc.commodity[7983] = true
  market.items[7983] = { m = 100, md = 120, q = 30, n = 2, t = clock, nm = "Bewegungsstein", ql = 1 }
  Rd.entries, Rd.gone, Rd.job = {}, {}, nil
  F.Set(7983)
  Q.SetMode("quick")
  local function lv(list)
    local rows = { offers = {}, commodity = true }
    local id = 0
    for _, x in ipairs(list) do
      id = id + 1
      rows.offers[#rows.offers + 1] = { id = id, q = x[2], p = x[1] }
      rows[#rows + 1] = { price = x[1], qty = x[2], own = 0 }
    end
    return rows
  end
  Q.baits = {}
  M.Start(7983)
  M.Add(7983, lv({ { 100, 10 }, { 120, 20 } }), 0)
  M.Add(7983, lv({ { 100, 10 }, { 120, 25 } }), 5)                       -- neu
  M.Add(7983, lv({ { 100, 6 }, { 120, 25 } }), 10)                       -- Kauf
  M.Add(7983, lv({ { 90, 1 }, { 100, 6 }, { 120, 25 } }), 15)            -- neu, Preissprung
  Q.AddBait(7983, 16, 120, true)   -- eigenes Lockangebot zu 120, Grundmenge 25
  M.Add(7983, lv({ { 90, 1 }, { 100, 6 }, { 120, 30 } }), 20)            -- neu
  M.Add(7983, lv({ { 100, 6 }, { 120, 30 } }), 25)                       -- Kauf, Preissprung
  M.Add(7983, lv({ { 100, 6 }, { 120, 35 }, { 130, 5 } }), 30)           -- zwei Stufen neu
  local v = M.Values()
  check(v.newPerMin == 10 and v.soldPerMin == 4 and v.jumps == 2 and v.jumpsPerMin == 4 and v.inAll == 42 and v.out == 10,
    "0.108: Messung zaehlt Einstellungen, Kaeufe, Preisspruenge und Zufluss aller Preise je Minute")
  check(Q.Movement(v) == "high", "0.108: viele Einstellungen und Ereignisse heisst lebhaft")
  local keepAll = mod.db.quickMoveAll
  mod.db.quickMoveAll = 30
  check(Q.Movement(v) == "mid", "0.108: zu wenige Ereignisse fuer lebhaft heisst maessig")
  mod.db.quickMoveAll = keepAll
  check(Q.Movement({ n = 5, elapsed = 60, newPerMin = 0, soldPerMin = 0.5, jumpsPerMin = 0 }) == "low", "0.108: kaum Ereignisse heisst ruhig")
  check(Q.Movement({ n = 2, elapsed = 5 }) == "first", "0.108: in den ersten Sekunden noch kein Urteil")
  -- ab 0.110 fortlaufend: das fremde Lockangebot bei 15 s (90, 1 Stueck) hat Q.OnSample erkannt
  local foreign = 0
  for _, b in ipairs(Q.baits[7983]) do if not b.own and b.price == 90 then foreign = foreign + 1 end end
  check(foreign == 1 and Q.baits[7983][1].price == 90 and Q.baits[7983][1].t == 15 and Q.baits[7983][1].added == 0, "0.110: fremdes Lockangebot bei der Abfrage erkannt")
  GetTime = function() return 50 end
  local st = Q.BaitStats(7983)
  local own
  for _, b in ipairs(Q.baits[7983]) do if b.own then own = b end end
  check(own and own.added == 10 and own.times == 2, "0.108: nach dem eigenen Lockangebot 10 Stueck in 2 Schritten zum selben Preis")
  check(st and st.n == 2 and st.withFollow == 1 and st.added == 10 and st.last.own and st.last.price == 120 and not st.last.running,
    "0.109: zwei Lockangebote im Fenster, eins mit Folge, das letzte ist das eigene")
  GetTime = function() return 20 end
  st = Q.BaitStats(7983)
  check(st.last.running and st.last.left == 26, "0.108: Nachwirkung laeuft noch 26 Sek.")
  -- Zeilen ueber dem Diagramm (ab 0.110 kurz, Einzelheiten im Tooltip)
  F.UpdateQuickMove(v)
  local t1, t3, t4, t5 = plain(F.mRows[1].value.text), plain(F.mRows[3].value.text), plain(F.mRows[4].value.text), plain(F.mRows[5].value.text)
  check(plain(F.mRows[1].label.text) == "Zufluss" and plain(F.mRows[3].label.text) == "Bewegung"
    and plain(F.mRows[4].label.text) == "Lockangebote" and plain(F.mRows[5].label.text) == "Einbruch"
    and t1 == "42 je Min. (10×)" and t3 == "lebhaft (2 Sprünge)" and t4 == "2 in 10 Min., 1 mit Folge" and t5 == "noch keiner",
    "0.110: kurze Zeilen ueber dem Diagramm: " .. t1 .. " / " .. t3 .. " / " .. t4 .. " / " .. t5)
  check(F.mRows[1].tip and F.mRows[1].tip[1]:find("in 10 Einstellungen je Minute", 1, true) and F.mRows[3].tip and #F.mRows[3].tip == 2
    and F.mRows[4].tip and F.mRows[4].tip[2]:find("Eigenes Lockangebot", 1, true), "0.110/0.125: Einzelheiten im Tooltip der Zeilen (letztes Lockangebot ab 0.125 bei Lockangebote)")
  -- Folge ohne einzelne Stuecke: 80 mit 1 Stueck (Lockangebot), dann +1 (noch ein Lockangebot, zaehlt nicht), dann +20
  Q.baits[7986] = nil
  local p0 = { t = 100, min = 100, lv = { { price = 100, qty = 10 } } }
  local s1 = { t = 105, min = 80, lv = { { price = 80, qty = 1 }, { price = 100, qty = 10 } } }
  local s2 = { t = 110, min = 80, lv = { { price = 80, qty = 2 }, { price = 100, qty = 10 } } }
  local s3 = { t = 115, min = 80, lv = { { price = 80, qty = 22 }, { price = 100, qty = 10 } } }
  Q.OnSample(7986, p0, s1); Q.OnSample(7986, s1, s2); Q.OnSample(7986, s2, s3)
  local b = Q.baits[7986] and Q.baits[7986][1]
  check(b and #Q.baits[7986] == 1 and b.added == 20 and b.times == 1, "0.110: ein weiteres einzelnes Stueck zaehlt nicht als Folge")
  local keepMin = mod.db.quickBaitMinPct
  mod.db.quickBaitMinPct = 25
  Q.baits[7986] = nil
  Q.OnSample(7986, p0, s1)
  check(Q.baits[7986] == nil, "0.109: nur 20 % darunter zaehlt bei Grenze 25 % nicht")
  mod.db.quickBaitMinPct = keepMin
  local keepKey, keepLim = F.key, F.manualLimit
  F.key, F.manualLimit = 7986, { key = 7986, price = 70 }
  Q.baits[7986] = nil
  Q.OnSample(7986, p0, s1)
  -- ab 0.123 erkannt (fuer Auto), aber nicht gemeldet
  check(Q.baits[7986] and Q.baits[7986][1].above == true and Q.baitPing ~= 7986, "0.110: Lockangebot ueber Kaufen bis zaehlt nicht (ab 0.123 nur fuer Auto gemerkt)")
  Q.baits[7986] = nil
  F.manualLimit = { key = 7986, price = 80 }
  Q.OnSample(7986, p0, s1)
  check(Q.baits[7986] and #Q.baits[7986] == 1 and not Q.baits[7986][1].above, "0.110: Lockangebot auf Kaufen bis zaehlt")
  Q.baitPing = nil
  F.key, F.manualLimit = keepKey, keepLim
  Q.baits[7986] = nil
  -- Mausbereiche der Aufkauf-Zeilen liegen im Schnellkauf nicht ueber dem Knopf
  check(not F.rows[1].hover.shown and plain(F.quick.post.text) == "Lockangebot einstellen", "0.110: Mausbereiche verborgen, Knopf heisst Lockangebot einstellen")
  Q.SetMode("buyout", true)
  check(plain(F.mRows[1].label.text) == "Abfluss" and plain(F.mRows[5].label.text) == "" and F.rows[1].hover.shown ~= false, "0.108: im Aufkauf wieder die Zeilen der Messung")
  -- aufraeumen
  GetTime = keepTime
  Q.baits = {}
  M.Stop()
  market.items[7983], mod.acc.commodity[7983] = nil, nil
  Rd.entries, Rd.gone, Rd.job, Rd.focus = {}, {}, nil, nil
end)()

-- ===== 0.109: Haken "Lockangebot ignorieren" (Kaufknopf und Alarm erst ab mehr als 1 Stueck) =====
;(function()
  local F, Q, Wt = ns.Focus, ns.Quick, ns.Watch
  local keepOpen, keepMoney, keepPlay = ns.Scan.ahOpen, GetMoney, ns.Radar.PlayAlert
  local sounds = 0
  ns.Radar.PlayAlert = function() sounds = sounds + 1 end
  GetMoney = function() return 10000000 end
  ns.Scan.ahOpen = true
  mod.acc.commodity[7984] = true
  market.items[7984] = { m = 90, md = 150, q = 21, n = 2, t = clock, nm = "Lockstein", ql = 1 }
  Rd.entries, Rd.gone, Rd.job = {}, {}, nil
  F.Set(7984)
  Q.SetMode("quick")
  F.SetLimit(100)
  ns.Buy.live[7984] = { rows = { { price = 90, qty = 1, own = 0 }, { price = 150, qty = 20, own = 0 }, commodity = true }, t = clock, commodity = true }
  F.Update()
  check(F.quick.skip.checked, "0.113: Haken Lockangebot ignorieren ist vorgegeben")
  Q.SetSkip(false)
  check(F.quick.skip.shown and ns.L.QUICK_SKIP == "Lockangebot ignorieren" and not F.quick.skip.checked
    and F.Plan().maxQty == 1 and not F.buyButton.disabled, "0.109: ohne Haken kauft der Knopf das eine Stueck")
  Q.SetSkip(true)
  check(Q.SkipOn(7984) and F.quick.skip.checked, "0.109: Haken gesetzt")
  local d = F.Plan()
  check(d.maxQty == 0 and d.baitOnly and F.buyButton.disabled, "0.109: mit Haken ist 1 Stueck allein kein Kauf, Knopf gesperrt")
  -- neue Antwort mit groesserer Menge darunter: Knopf frei und Alarm, mit dem einen Stueck allein kein Alarm
  sounds = 0
  ns.Buy.live[7984] = { rows = { { price = 90, qty = 1, own = 0 }, { price = 150, qty = 20, own = 0 }, commodity = true }, t = clock + 1, commodity = true }
  F.Update()
  check(sounds == 0, "0.109: kein Alarm fuer das eine Stueck")
  ns.Buy.live[7984] = { rows = { { price = 90, qty = 1, own = 0 }, { price = 95, qty = 10, own = 0 }, { price = 150, qty = 20, own = 0 }, commodity = true }, t = clock + 2, commodity = true }
  F.Update()
  check(F.Plan().maxQty == 11 and not F.buyButton.disabled and sounds == 1, "0.109: ab mehr als 1 Stueck Knopf frei und Alarm, der Kauf nimmt das eine Stueck mit")
  -- gespeichert je Gegenstand in Beobachten
  F.Save()
  local w = Wt.Store()[7984]
  check(w and w.qskip == true and Wt.SKIP.qskip, "0.109: Haken in Beobachten gespeichert (nur im Spiel)")
  Q.skip = {}
  check(Q.SkipOn(7984), "0.109: ohne Wert der Sitzung gilt der gespeicherte Haken")
  Q.SetSkip(false)
  check(not Q.SkipOn(7984) and Q.SkipOn(7985), "0.109/0.113: Haken je Gegenstand, ohne gespeicherten Wert an")
  -- aufraeumen
  Wt.Remove(7984)
  Q.skip = {}
  Q.SetMode("buyout", true)
  F.SetLimit(nil)
  ns.Scan.ahOpen, GetMoney, ns.Radar.PlayAlert = keepOpen, keepMoney, keepPlay
  market.items[7984], ns.Buy.live[7984], mod.acc.commodity[7984] = nil, nil, nil
  Rd.entries, Rd.gone, Rd.job, Rd.focus = {}, {}, nil, nil
end)()

-- ===== 0.110: Preisalarm aus Beobachten im Fokus still =====
;(function()
  local F, Wt, R = ns.Focus, ns.Watch, ns.Radar
  local keepShown, keepAlert, keepKey = F.Shown, Wt.Alert, F.key
  local alerts = 0
  Wt.Alert = function() alerts = alerts + 1 end
  D.Market().items[7987] = { m = 50, md = 80, q = 10, n = 1, t = clock, nm = "Alarmstein", ql = 1 }
  Wt.Add(7987, { name = "Alarmstein" })
  F.key = 7987
  F.Shown = function() return true end
  Wt.SetLimit(7987, "abs", 60)
  local w = Wt.Store()[7987]
  w.hit = nil
  Wt.Check({ 7987 })
  check(alerts == 0 and w.hit, "0.110: kein Preisalarm fuer den Gegenstand im sichtbaren Fokus")
  F.Shown = function() return false end
  w.hit = nil
  Wt.Check({ 7987 })
  check(alerts == 1, "0.110: ausserhalb des Fokus klingelt der Preisalarm")
  F.Shown, Wt.Alert, F.key = keepShown, keepAlert, keepKey
  Wt.Remove(7987)
  D.Market().items[7987] = nil
end)()

-- ===== 0.111: Ton fuer Lockangebote, mehr Toene, Zeile Gekauft mit Quote =====
;(function()
  local F, Q, R = ns.Focus, ns.Quick, ns.Radar
  local keepPlay, keepKey = R.PlayAlert, F.key
  local played = {}
  R.PlayAlert = function(k) played[#played + 1] = k end
  check(#R.SoundChoices() == 10 and R.SoundChoices()[5][2] == "Münzen", "0.111: zehn Toene zur Auswahl")
  -- fremdes Lockangebot erkannt, Knopf gesperrt: Ton fuer Lockangebote
  F.key = 7988
  Q.baits[7988], Q.sessions[7988], Q.opp[7988], Q.alarm = nil, nil, nil, {}
  local p0 = { t = 200, min = 100, lv = { { price = 100, qty = 10 } } }
  local s1 = { t = 205, min = 80, lv = { { price = 80, qty = 1 }, { price = 100, qty = 10 } } }
  Q.OnSample(7988, p0, s1)
  local rows1 = {}
  Q.CheckAlarm(7988, rows1, 0, nil)
  check(#played == 1 and played[1] == "ping", "0.111: Ton fuer ein Lockangebot, solange der Kaufknopf gesperrt ist")
  -- Knopf schon frei (Haken aus, das Stueck liegt unter Kaufen bis): nur der normale Alarm
  played = {}
  Q.OnSample(7988, p0, s1)
  Q.CheckAlarm(7988, {}, 1, nil)
  check(#played == 0 or played[1] ~= "ping", "0.111: mit freiem Kaufknopf kein Ton fuer Lockangebote")
  -- Gelegenheiten und Quote
  Q.sessions[7988], Q.opp[7988], Q.alarm = nil, nil, { key = 7988, qty = 0 }
  Q.CheckAlarm(7988, {}, 5, nil)            -- Gelegenheit 1
  Q.OnBought({ key = 7988, quick = true }, 5, 500)
  Q.CheckAlarm(7988, {}, 0, nil)
  Q.CheckAlarm(7988, {}, 3, nil)            -- Gelegenheit 2, nicht genutzt
  Q.OnFailed({ key = 7988, quick = true })
  Q.CheckAlarm(7988, {}, 0, nil)
  local text, tip = Q.BoughtText(7988)
  check(plain(text) == "5 Stück (50 %), Ø 1s" and tip[1]:find("1 von 2", 1, true) and tip[1]:find("Käufe: 1, fehlgeschlagen oder zu teuer: 1", 1, true),
    "0.111: Gekauft mit Quote der genutzten Gelegenheiten: " .. plain(text) .. " / " .. tip[1])
  check(plain(F.mRows[6].label.text) == "" or plain(F.mRows[6].label.text) == "Gekauft", "0.111: sechste Zeile vorhanden")
  R.PlayAlert, F.key = keepPlay, keepKey
  Q.baits[7988], Q.sessions[7988], Q.opp[7988], Q.alarm, Q.baitPing = nil, nil, nil, {}, nil
end)()

-- ===== 0.112: Haken "Durchschnitt zaehlt", Limit pro Kauf beim Preis des Spiels =====
;(function()
  local F, Q, R = ns.Focus, ns.Quick, ns.Radar
  local ah = C_AuctionHouse
  local keepOpen, keepMoney = ns.Scan.ahOpen, GetMoney
  local keepStart, keepConfirm = ah.StartCommoditiesPurchase, ah.ConfirmCommoditiesPurchase
  local started, confirmed = 0, 0
  ah.StartCommoditiesPurchase = function() started = started + 1 end
  ah.ConfirmCommoditiesPurchase = function() confirmed = confirmed + 1 end
  GetMoney = function() return 10000000 end
  ns.Scan.ahOpen = true
  mod.acc.commodity[7989] = true
  market.items[7989] = { m = 100, md = 150, q = 25, n = 2, t = clock, nm = "Mittelstein", ql = 1 }
  Rd.entries, Rd.gone, Rd.job = {}, {}, nil
  F.Set(7989)
  Q.SetMode("quick")
  F.SetLimit(200)
  ns.Buy.live[7989] = { rows = { { price = 100, qty = 10, own = 0 }, { price = 150, qty = 10, own = 0 }, commodity = true }, t = clock, commodity = true }
  F.Update()
  check(F.quick.avg.shown and Q.AvgOn(7989) and F.quick.avg.checked and ns.L.QUICK_AVG == "Durchschnitt zählt", "0.112/0.113: Haken Durchschnitt zaehlt, Vorgabe an")
  Q.SetAvg(false)
  -- ohne Haken: Preis des Spiels ueber dem teuersten Stueck -> zu teuer
  F.Buy()
  check(Rd.job and Rd.job.limit == 150 and not Rd.job.avg, "0.112: ohne Haken gilt der Preis des teuersten Stuecks")
  Rd.OnPriceUpdated(170, 3400)
  check(Rd.job == nil and confirmed == 0, "0.112: ohne Haken zu teuer, kein Kauf")
  -- mit Haken: Durchschnitt 170 <= Kaufen bis 200 -> sofort bestaetigt, ohne Warnung
  Q.SetAvg(true)
  ns.Buy.live[7989] = { rows = { { price = 100, qty = 10, own = 0 }, { price = 150, qty = 10, own = 0 }, commodity = true }, t = clock + 5, commodity = true }
  F.Update()
  F.Buy()
  check(Rd.job and Rd.job.limit == 200 and Rd.job.avg, "0.112: mit Haken gilt Kaufen bis fuer den Durchschnitt")
  Rd.OnPriceUpdated(170, 3400)
  check(confirmed == 1 and Rd.job and not Rd.job.warn and Rd.job.stage == "wait", "0.112: Durchschnitt unter Kaufen bis, ohne Warnung bestaetigt")
  Rd.FinishJob(true)
  -- Limit pro Kauf: Gesamtpreis darueber -> zu teuer
  F.SetGoldTyped(1900)
  ns.Buy.live[7989] = { rows = { { price = 100, qty = 10, own = 0 }, { price = 150, qty = 10, own = 0 }, commodity = true }, t = clock + 10, commodity = true }
  F.Update()
  local d = F.Plan()
  check(d.best.qty == 16 and d.goldCap == 1900, "0.112: Limit pro Kauf 19s: 10 x 1s und 6 x 1s 50c")
  confirmed = 0
  F.Buy()
  Rd.OnPriceUpdated(190, 3040)
  check(confirmed == 0 and Rd.job == nil, "0.112: Gesamtpreis ueber dem Limit pro Kauf, kein Kauf")
  -- gespeichert in Beobachten
  F.Save()
  local w = ns.Watch.Store()[7989]
  check(w and w.qavg == true and w.qgold == 1900 and not F.limitHint.shown, "0.112: Haken und Limit pro Kauf in Beobachten")
  -- aufraeumen
  ns.Watch.Remove(7989)
  Q.avg = {}
  Q.SetMode("buyout", true)
  F.SetLimit(nil)
  F.manualGold = nil
  ah.StartCommoditiesPurchase, ah.ConfirmCommoditiesPurchase = keepStart, keepConfirm
  ns.Scan.ahOpen, GetMoney = keepOpen, keepMoney
  market.items[7989], ns.Buy.live[7989], mod.acc.commodity[7989] = nil, nil, nil
  Rd.entries, Rd.gone, Rd.job, Rd.focus = {}, {}, nil, nil
end)()

-- ===== 0.113: Vorgaben im Schnellkauf, automatisch speichern =====
;(function()
  local F, Q, Wt = ns.Focus, ns.Quick, ns.Watch
  local keepOpen, keepMoney = ns.Scan.ahOpen, GetMoney
  GetMoney = function() return 10000000 end
  ns.Scan.ahOpen = true
  mod.acc.commodity[7990] = true
  market.items[7990] = { m = 100, md = 150, q = 25, n = 2, t = clock, nm = "Speicherstein", ql = 1 }
  Rd.entries, Rd.gone, Rd.job = {}, {}, nil
  F.Set(7990)
  Q.SetMode("quick")
  F.SetLimit(200)
  ns.Buy.live[7990] = { rows = { { price = 100, qty = 10, own = 0 }, { price = 150, qty = 10, own = 0 }, commodity = true }, t = clock, commodity = true }
  F.Update()
  check(F.ManualGold(7990) == 50000, "0.120: Limit pro Kauf ohne eigenen Wert 5 Gold")
  F.SetLimit(300)
  mod.db.quickGoldDefault = 70000
  F.Update()
  check(F.ManualGold(7990) == 70000, "0.120: Vorgabe einstellbar, gilt auch nach neuem Kaufen bis")
  mod.db.quickGoldDefault = nil
  F.SetGoldTyped(5000)
  F.SetLimit(250)
  F.Update()
  check(F.ManualGold(7990) == 5000, "0.113: eigener Betrag bleibt")
  -- nicht beobachtet: kein automatisches Speichern
  check(F.AutoSave() == false and not Wt.Is(7990), "0.113: nicht beobachtet, nichts gespeichert")
  -- beobachtet: Verlassen des Reiters speichert still
  Wt.Add(7990, { name = "Speicherstein" })
  Q.SetSkip(false)
  ns.Window.pages.focus.leave()
  local w = Wt.Store()[7990]
  check(w.qlim == 250 and w.qgold == 5000 and w.qskip == false and w.qavg == true and w.mode == "quick", "0.113: Verlassen speichert die Werte des Schnellkaufs")
  -- Einstellung aus: nichts gespeichert
  mod.db.autoSaveQuick = false
  F.SetLimit(222)
  check(F.AutoSave() == false and w.qlim == 250, "0.113: Einstellung aus, nichts gespeichert")
  mod.db.autoSaveQuick = true
  -- Wechsel in den Aufkauf speichert den Schnellkauf
  F.SetLimit(260)
  Q.SetMode("buyout")
  check(w.qlim == 260, "0.113: Wechsel des Modus speichert den bisherigen Modus")
  -- gespeichert ohne Grenze: bleibt ohne Grenze
  w.qgold = 0
  Q.goldCleared = {}
  Q.SetMode("quick")
  check(F.ManualGold(7990) == nil and Q.goldCleared[7990] and not Q.SkipOn(7990), "0.113: gespeichert ohne Grenze und ohne Haken, so geladen")
  -- aufraeumen
  mod.db.autoSaveQuick, mod.db.autoSaveBuyout = true, true
  Wt.Remove(7990)
  Q.skip, Q.avg, Q.goldCleared = {}, {}, {}
  Q.SetMode("buyout", true)
  F.SetLimit(nil)
  F.manualGold = nil
  ns.Scan.ahOpen, GetMoney = keepOpen, keepMoney
  market.items[7990], ns.Buy.live[7990], mod.acc.commodity[7990] = nil, nil, nil
  Rd.entries, Rd.gone, Rd.job, Rd.focus = {}, {}, nil, nil
end)()

-- ===== 0.114: Pause der Abfragen, solange der Kaufknopf frei ist =====
;(function()
  local F, Q = ns.Focus, ns.Quick
  local keepOpen, keepMoney, keepTime = ns.Scan.ahOpen, GetMoney, GetTime
  local now = 1000
  GetTime = function() return now end
  GetMoney = function() return 10000000 end
  ns.Scan.ahOpen = true
  mod.acc.commodity[7991] = true
  market.items[7991] = { m = 100, md = 150, q = 25, n = 2, t = clock, nm = "Pausenstein", ql = 1 }
  Rd.entries, Rd.gone, Rd.job = {}, {}, nil
  F.Set(7991)
  Q.SetMode("quick")
  F.SetLimit(200)
  ns.Buy.live[7991] = { rows = { { price = 100, qty = 10, own = 0 }, { price = 300, qty = 10, own = 0 }, commodity = true }, t = clock, commodity = true }
  F.Update()
  check(Q.HoldQueries(7991) and not Q.Locked(7991) and not F.buyButton.disabled, "0.114: etwas kaufbar: Abfragen pausieren, Knopf frei")
  now = now + 1.2
  F.Update()
  check(not Q.HoldQueries(7991) and Q.Locked(7991) and F.buyButton.disabled, "0.114: nach 1 Sek. ohne Klick: Abfragen weiter, Knopf gesperrt")
  local d0 = Rd.job
  F.Buy()
  check(Rd.job == d0, "0.114: gesperrter Knopf kauft nicht (auch nicht per Taste)")
  -- neue Antwort, wieder etwas da: Knopf frei, neue Pause
  ns.Buy.live[7991] = { rows = { { price = 100, qty = 30, own = 0 }, commodity = true }, t = clock + 1, commodity = true }
  F.Update()
  check(Q.HoldQueries(7991) and not Q.Locked(7991) and not F.buyButton.disabled, "0.114: neue Antwort gibt den Knopf mit neuer Menge frei")
  -- nichts mehr da: keine Pause
  ns.Buy.live[7991] = { rows = { { price = 300, qty = 10, own = 0 }, commodity = true }, t = clock + 2, commodity = true }
  F.Update()
  check(not Q.HoldQueries(7991) and not Q.Locked(7991), "0.114: ohne Kaufbares keine Pause")
  -- Einstellung 0: aus
  mod.db.quickHold = 0
  ns.Buy.live[7991] = { rows = { { price = 100, qty = 30, own = 0 }, commodity = true }, t = clock + 3, commodity = true }
  F.Update()
  check(not Q.HoldQueries(7991), "0.114: Pause abschaltbar")
  mod.db.quickHold = 1
  -- nach einem Kauf sofort wieder abfragen
  ns.Buy.live[7991] = { rows = { { price = 100, qty = 30, own = 0 }, commodity = true }, t = clock + 4, commodity = true }
  F.Update()
  Rd.job = { key = 7991, id = 7991, qty = 5, limit = 100, name = "Pausenstein", stage = "wait", kind = "own", total = 500, done = 0, quick = true }
  Rd.FinishJob(true)
  check(not Q.HoldQueries(7991), "0.114: nach dem Kauf keine Pause mehr")
  -- aufraeumen
  Q.SetMode("buyout", true)
  F.SetLimit(nil)
  F.manualGold = nil
  Q.hold = nil
  GetTime, ns.Scan.ahOpen, GetMoney = keepTime, keepOpen, keepMoney
  market.items[7991], ns.Buy.live[7991], mod.acc.commodity[7991] = nil, nil, nil
  Rd.entries, Rd.gone, Rd.job, Rd.focus = {}, {}, nil, nil
end)()

-- ===== 0.114.1: verkauftes Lockangebot ueber AUCTION_CANCELED erkannt =====
;(function()
  local Q = ns.Quick
  local keep = Q.bait
  Q.bait = { key = 7992, price = 10, t = GetTime(), wall = time(), id = 4711, state = "up" }
  Q.OnCanceled(999)
  check(Q.bait.state == "up", "0.114.1: fremde Nummer aendert nichts")
  Q.OnCanceled(4711)
  check(Q.bait.state == "gone", "0.114.1: Spiel meldet das eigene Lockangebot als entfernt: weg, auch ohne dass eine Antwort es zeigte")
  Q.bait = { key = 7992, price = 10, t = GetTime(), wall = 100, id = 4712, state = "up" }
  Q.CheckBait(7992, { { price = 20, qty = 5, own = 0 } }, 103)
  check(Q.bait.state == "gone", "0.114.1: Antwort klar nach dem Einstellen ohne eigenes Angebot: weg")
  Q.bait = keep
end)()

-- ===== 0.118: Anschluss fuer ein Kaufprotokoll ausserhalb von Broker =====
;(function()
  local R = ns.Radar
  local lines = {}
  mod.traceHook = nil
  R.Trace("ohne %s", 1)
  mod.traceHook = function(text) lines[#lines + 1] = text end
  R.Trace("mit %s", 2)
  R.Send(7777)
  mod.traceHook = function() error("kaputt") end
  R.Trace("Fehler im Abnehmer stoert nicht")
  mod.traceHook = nil
  Rd.pending = nil
  check(#lines == 2 and lines[1] == "mit 2" and lines[2]:find("send key=7777", 1, true) and mod.acc.buyLog == nil,
    "0.118: R.Trace gibt Zeilen nur an einen gesetzten Anschluss, Broker speichert nichts")
end)()

-- ===== 0.119: Chancen der Art Schnellkauf, Unterreiter in Chancen und Beobachten =====
;(function()
  local QC, C, R, Wt, WP, F, Q = ns.QuickChances, ns.Chances, ns.Radar, ns.Watch, ns.WatchPage, ns.Focus, ns.Quick
  local market = ns.Data.Market()
  local keepGT, keepShown, keepWS, keepReady, keepSend, keepOpen = GetTime, C.Shown, WP.Shown, R.ItemReady, R.Send, ns.Scan.ahOpen
  local keepAH = rawget(_G, "C_AuctionHouse")
  local keepDb = {}
  for _, k in ipairs({ "chancesTab", "watchTab", "qcCount", "qcMinPrice", "qcProbes", "chancesShowQ", "focusMode" }) do keepDb[k] = mod.db[k] end
  local tnow = 1000
  GetTime = function() return tnow end
  ns.Scan.ahOpen = true
  if not keepAH then C_AuctionHouse = {} end
  check(mod.db.qcCount == 10 and mod.db.qcMinPrice == 100 and mod.db.qcProbes == 5 and mod.db.chancesShowQ == true, "0.119: Vorgaben 10 Vorschlaege, 1 Silber, 5 Abfragen")
  mod.db.qcCount, mod.db.qcProbes = 2, 3
  -- eigener Markt fuer den Test
  local keepItems = market.items
  market.items = {}
  market.items[7991] = { m = 500, q = 3000, n = 5, t = clock, nm = "Schnellerz", ql = 1 }
  market.items[7992] = { m = 50, q = 9000, n = 5, t = clock, nm = "Billigkraut", ql = 1 }   -- unter 1 Silber
  market.items[7993] = { m = 800, q = 2000, n = 5, t = clock, nm = "Flinkstoff", ql = 1 }
  market.items[7994] = { m = 900, q = 5000, n = 5, t = clock, nm = "Schwert", ql = 2 }      -- keine Massenware
  market.items[7995] = { m = 300, q = 1000, n = 5, t = clock, nm = "Restgut", ql = 1 }
  market.items[7996] = { m = 900, q = 8000, n = 5, t = clock, gone = clock, nm = "Weg", ql = 1 }   -- nicht mehr da
  for _, id in ipairs({ 7991, 7992, 7993, 7994, 7995, 7996 }) do mod.acc.commodity[id] = id ~= 7994 end
  QC.cands, QC.res, QC.run, QC.queue, QC.src, QC.paused = nil, {}, nil, {}, nil, false
  local function keys() local t = {} for _, c in ipairs(QC.Candidates()) do t[#t + 1] = c.key end return table.concat(t, ",") end
  check(keys() == "7991,7993", "0.119: Vorschlaege: Massenware ab Mindestpreis, groesste Menge zuerst, Anzahl begrenzt: " .. keys())
  market.items[7995].q = 99999
  check(keys() == "7991,7993", "0.119: Liste bleibt bis zum naechsten Stand, auch wenn sich die Menge live aendert")
  QC.Candidates(true)
  check(keys() == "7995,7991", "0.119: Neu vorschlagen nimmt die neue Menge: " .. keys())
  market.items[7995].q = 1000
  QC.Candidates(true)
  QC.Hide(7991)
  check(keys() == "7993,7995" and QC.Hidden(7991) and QC.HiddenCount() == 1 and type(mod.acc.quickHide) == "table",
    "0.119: nicht mehr vorschlagen, der naechste rueckt nach: " .. keys())
  QC.Unhide()
  check(keys() == "7991,7993" and mod.acc.quickHide == nil, "0.119: zurueckholen")
  -- Pruefung: ein Gegenstand nach dem anderen, je Gegenstand qcProbes Abfragen
  mod.db.chancesTab = "quick"
  C.Shown = function() return true end
  WP.Shown = function() return false end
  R.ItemReady = function() return true end
  local sent = {}
  R.Send = function(key, forBuy, refresh) sent[#sent + 1] = { key = key, refresh = refresh }; R.pending = { key = key, sent = tnow }; return true end
  local function lv(list)
    local rows = { offers = {}, commodity = true }
    for i, x in ipairs(list) do
      rows.offers[#rows.offers + 1] = { id = i, q = x[2], p = x[1] }
      rows[#rows + 1] = { price = x[1], qty = x[2], own = 0 }
    end
    return rows
  end
  check(QC.Source() == "chances" and QC.Active(), "0.119: Unterreiter Schnellkauf offen: Pruefung aktiv")
  R.soon = nil
  local k, kind = R.NextKey()
  check(k == 7991 and kind == "probe" and QC.run and QC.run.key == 7991, "0.119: Pruefung beginnt beim Vorschlag mit der groessten Menge")
  QC.Send(k)
  check(sent[1].key == 7991 and sent[1].refresh == false and R.pending.probe, "0.119: erste Abfrage als Suche, als Pruefung markiert")
  QC.OnAnswer(7991, lv({ { 500, 10 }, { 600, 20 } }), 0)
  QC.Send(7991)
  check(sent[2].refresh == true, "0.119: danach Neu laden wie im Fokus")
  QC.OnAnswer(7991, lv({ { 450, 1 }, { 500, 10 }, { 600, 25 } }), 3)   -- 2 Einstellungen (eine als Lockangebot), Preissprung
  check(QC.StateText(7991):find("|T", 1, true) and QC.QueuePos(7993) == 2 and plain(QC.StateText(7993)) == "als 2. dran",
    "0.119: laufende Zeile mit Punkten, der naechste als 2. dran: " .. plain(QC.StateText(7993)))
  local qrows = QC.Rows()
  check(qrows[1].running and not qrows[2].running, "0.119: laufende Zeile markiert (hell hinterlegt)")
  QC.OnAnswer(7991, lv({ { 500, 4 }, { 600, 25 } }), 6)   -- 2 Kaeufe, Preissprung
  local v = QC.Result(7991)
  check(v and v.class == "high" and v.early and v.nNew == 1 and v.nSold == 1 and v.jumps == 2 and v.baits == 1 and v.queries == 3
    and math.abs(v.ev - 40) < 0.01 and QC.run == nil,
    "0.119/0.120: 3 Abfragen in 6 Sek.: in der Kaufzone 1 Einstellung, 1 Kauf, dazu 2 Preisspruenge, 1 Lockangebot heisst lebhaft (vorlaeufig)")
  check(plain(QC.MoveText(v)) == "lebhaft?" and plain(QC.StateText(7991)):find("^vor "), "0.119: vorlaeufig mit Fragezeichen, Alter der Pruefung: " .. plain(QC.StateText(7991)))
  check(QC.LivelyCount() == 1 and C.BadgeCount("all", "quick") == 1, "0.119: Zahl am Unterreiter zaehlt die lebhaften")
  k = R.NextKey()
  check(k == 7993, "0.119: dann der naechste Vorschlag")
  for i = 0, 2 do QC.Send(7993); QC.OnAnswer(7993, lv({ { 800, 5 }, { 900, 5 } }), 10 + i * 3) end
  v = QC.Result(7993)
  check(v and v.class == "low" and v.events == 0, "0.119: nichts bewegt heisst ruhig")
  -- neue Runde: lebhafte, ungepruefte, ruhige
  mod.db.qcCount = 3
  k = R.NextKey()
  check(k == 7991 and table.concat(QC.queue, ",") == "7995", "0.119/0.120: neue Runde: lebhafte zuerst, dann ungepruefte, der ruhige wartet: " .. table.concat(QC.queue, ","))
  local due93 = QC.DueIn(7993)
  check(due93 > 250 and due93 <= 300 and plain(QC.StateText(7993)):find("wieder in", 1, true),
    "0.120: ruhig und vorlaeufig wartet bis zu halbe 10 Min.: " .. plain(QC.StateText(7993)))
  check(QC.Wait({ class = "high" }) == 0 and QC.Wait({ class = "mid", newPerMin = 1, ev = 4 }) == 300
    and math.abs(QC.Wait({ class = "mid", newPerMin = 2, ev = 4.5 }) - 60) < 0.01 and QC.Wait({ class = "low", newPerMin = 0, ev = 0 }) == 600,
    "0.120: Wartezeit gleitend: lebhaft 0, maessig nach Anteil an der Grenze, ruhig 10 Min.")
  for i = 0, 2 do QC.Send(7991); QC.OnAnswer(7991, lv({ { 500, 4 }, { 600, 25 } }), 20 + i * 3) end
  v = QC.Result(7991)
  check(v and not v.early and v.probes == 2 and v.secs == 12 and v.events == 4 and v.class == "high",
    "0.119: gleitend: beide Pruefungen zusammen (4 Ereignisse in 12 Sek.)")
  -- Antwort ueber das Radar, lange Pause, Anhalten
  k = R.NextKey()
  check(k == 7995, "0.119: dann der ungepruefte")
  R.Apply({ key = 7995, probe = true }, lv({ { 300, 5 } }), true)
  check(QC.run and QC.run.key == 7995 and QC.run.got == 1, "0.119: Antwort des Radars geht in die Pruefung")
  R.Apply({ key = 7995 }, lv({ { 300, 5 } }), true)
  check(QC.run.got == 1, "0.119: andere Antworten zaehlen nicht")
  tnow = tnow + 30
  k = R.NextKey()
  check(k == 7995 and QC.run and QC.run.got == 0 and QC.res[7995] == nil, "0.119: nach langer Pause beginnt die Pruefung desselben Gegenstands neu")
  QC.SetPaused(true)
  check(not QC.Active() and R.NextKey() == nil, "0.119: angehalten: keine Abfragen")
  QC.SetPaused(false)
  -- Unterreiter ohne Art verschwindet, Rueckfall
  mod.db.chancesShowQ = false
  check(not C.TabOn("quick") and C.Tab() ~= "quick" and QC.Source() == nil, "0.119: Schnellkauf aus: Unterreiter weg, keine Pruefung")
  mod.db.chancesShowQ = true
  check(C.Tab() == "quick", "0.119: Unterreiter gemerkt")
  if C.qlist then
    local t = {}
    for _, c in ipairs(C.qlist.o.columns) do t[#t + 1] = plain(c.title) end
    check(table.concat(t, ",") == "Gegenstand,Günstigster,Menge,Zu / Ab je Min.,Bewegung,Einbr./Std.,Lockangebote,Zustand" and C.tabs and #C.tabs == 4,
      "0.119: vier Unterreiter (ab 0.127 mit Markttausch), Liste Schnellkauf mit eigenen Spalten: " .. table.concat(t, ","))
  end
  -- Menue
  local made = {}
  local root = { CreateButton = function(_, text) made[#made + 1] = text end }
  QC.AddMenu(root, { name = "Schnellerz" }, 7991)
  check(#made == 1 and made[1] == ns.L.MENU_QC_HIDE, "0.119/0.120: Menue: nicht vorschlagen (Beobachten ist ein Haken in Watch.AddMenu)")
  QC.WatchQuick(7991, "Schnellerz")
  local w91 = Wt.Store()[7991]
  check(Wt.InQuick(7991) and w91.qlim == 250 and w91.qgold == 50000 and not Wt.InBuyout(7991),
    "0.120: fuer Schnellkauf beobachten: Kaufen bis Haelfte des guenstigsten, Limit pro Kauf 5 Gold: " .. tostring(w91.qlim))
  -- ab 0.120: Haken im Menue der Beobachtung
  local boxes = {}
  local croot = { CreateCheckbox = function(_, text, get, set) boxes[#boxes + 1] = { text = text, get = get, set = set } end,
                  CreateButton = function() return { CreateButton = function() return {} end, CreateRadio = function() end } end }
  Wt.AddMenu(croot, { name = "Schnellerz" }, 7991)
  check(boxes[1].text == ns.L.MENU_WATCH_BUYOUT and not boxes[1].get() and boxes[2].text == ns.L.MENU_WATCH_QUICK and boxes[2].get(),
    "0.120: zwei Haken: Aufkauf aus, Schnellkauf an")
  Wt.SetBuyoutOn(7991, true)
  check(Wt.InBuyout(7991) and Wt.InQuick(7991) and w91.mode == "quick", "0.120: Haken Aufkauf dazu: in beiden Listen, Modus bleibt")
  Wt.SetQuickOn(7991, false)
  check(Wt.Is(7991) and Wt.InBuyout(7991) and not Wt.InQuick(7991) and w91.mode == nil and w91.qlim == 250, "0.120: Haken Schnellkauf weg: nur noch Aufkauf, Werte bleiben")
  Wt.SetQuickOn(7991, true)
  check(Wt.InQuick(7991) and Wt.InBuyout(7991) and w91.mode == nil, "0.120: wieder an: beide Listen, gespeicherter Modus bleibt Aufkauf")
  Wt.SetBuyoutOn(7991, false)
  check(Wt.InQuick(7991) and not Wt.InBuyout(7991) and w91.mode == "quick", "0.120: Aufkauf aus: nur Schnellkauf, Alarm nach dessen Kaufen bis")
  Wt.SetQuickOn(7991, false)
  check(not Wt.Is(7991), "0.120: beide Haken aus: nicht mehr beobachtet")
  Wt.SetQuickOn(7991, true, { name = "Schnellerz" })
  check(Wt.InQuick(7991) and not Wt.InBuyout(7991) and Wt.Store()[7991].qlim == 250, "0.120: frisch nur fuer Schnellkauf")
  -- Beobachten mit zwei Unterreitern
  C.Shown = function() return false end
  WP.Shown = function() return true end
  mod.db.watchTab = "quick"
  Wt.Add(7993, { name = "Flinkstoff" })
  Wt.SetQuick(7993, 850, nil, true, true)
  Wt.Add(7995, { name = "Restgut" })
  local wk = table.concat(QC.Keys("watch"), ",")
  check(QC.Source() == "watch" and wk == "7991,7993", "0.119: Beobachten/Schnellkauf prueft nur Gegenstaende mit Werten des Schnellkaufs: " .. wk)
  ns.Buy.live[7993] = { rows = lv({ { 800, 5 }, { 900, 5 } }), t = clock, commodity = true }
  local r
  for _, x in ipairs(WP.Rows("quick")) do if x.key == 7993 then r = x end end
  check(r and r.limit == 850 and r.under == 5 and r.v and r.v.class == "low" and r.advice == "buy",
    "0.119: Zeile Schnellkauf mit Kaufen bis, Stueck darunter, Bewegung und Rat")
  local inB = {}
  for _, x in ipairs(WP.Rows("buyout")) do inB[x.key] = true end
  check(inB[7995] and not inB[7993] and not inB[7991], "0.119: nur Werte des Schnellkaufs: nicht in der Liste Aufkauf")
  local got93 = false
  R.watchSent = {}
  for _ = 1, 12 do if R.NextWatch() == 7993 then got93 = true end end
  check(not got93, "0.119: Aufkauf fragt nur seine Liste reihum ab")
  if WP.SelectTab and WP.lists then
    WP.SelectTab("buyout")
    check(WP.list == WP.lists.buyout and mod.db.watchTab == "buyout" and WP.panels.buyout.shown and not WP.panels.quick.shown, "0.119: Unterreiter Aufkauf gewaehlt und gemerkt")
    WP.SelectTab("quick")
    check(WP.list == WP.lists.quick, "0.119: Unterreiter Schnellkauf")
  end
  -- Fokus im Modus der Liste
  Q.SetMode("buyout", true)
  F.FromPage(7993, "chances", "quick")
  check(mod.db.focusMode == "quick", "0.119: aus Chancen/Schnellkauf im Schnellkauf")
  F.FromPage(7993, "watch", "buyout")
  check(mod.db.focusMode == "buyout", "0.119: aus Beobachten/Aufkauf im Aufkauf, auch wenn zuletzt Schnellkauf gespeichert")
  -- aufraeumen
  Q.SetMode("buyout", true)
  for _, id in ipairs({ 7991, 7993, 7995 }) do Wt.Remove(id) end
  ns.Buy.live[7993] = nil
  for _, id in ipairs({ 7991, 7992, 7993, 7994, 7995, 7996 }) do mod.acc.commodity[id] = nil end
  market.items = keepItems
  ns.Data.vIndex = nil
  for k2, v2 in pairs(keepDb) do mod.db[k2] = v2 end
  GetTime, C.Shown, WP.Shown, R.ItemReady, R.Send, ns.Scan.ahOpen = keepGT, keepShown, keepWS, keepReady, keepSend, keepOpen
  if not keepAH then C_AuctionHouse = nil end
  R.pending, R.watchSent = nil, {}
  QC.cands, QC.res, QC.run, QC.queue, QC.src, QC.paused = nil, {}, nil, {}, nil, false
  mod.acc.quickHide, mod.acc.quickMove = nil, nil
end)()

-- ===== 0.121: Knopf Auto neben Kaufen bis im Schnellkauf =====
;(function()
  local F, Q = ns.Focus, ns.Quick
  local keepOpen, keepMoney = ns.Scan.ahOpen, GetMoney
  GetMoney = function() return 10000000 end
  ns.Scan.ahOpen = true
  mod.acc.commodity[7992] = true
  market.items[7992] = { m = 99, md = 150, q = 25, n = 2, t = clock, nm = "Lederprobe", ql = 1 }
  Rd.entries, Rd.gone, Rd.job = {}, {}, nil
  Q.baits[7992] = nil
  F.Set(7992)
  Q.SetMode("quick")
  ns.Buy.live[7992] = { rows = { { price = 53, qty = 1, own = 0 }, { price = 99, qty = 20, own = 0 }, commodity = true }, t = clock, commodity = true }
  F.Update()
  check(Q.AutoLimit(7992) == nil and F.quick.auto.disabled, "0.121: ohne erkanntes Lockangebot ist Auto grau")
  -- eigenes Lockangebot zaehlt nicht
  Q.AddBait(7992, 1, 60, true, 0)
  check(Q.AutoLimit(7992) == nil, "0.121: eigenes Lockangebot zaehlt fuer Auto nicht")
  -- fremdes Lockangebot zu 53, regulaer 99 (live): Mitte 76
  Q.AddBait(7992, 2, 53, false, 1, 101)
  local v, bait, reg = Q.AutoLimit(7992)
  check(v == 76 and bait == 53 and reg == 99, "0.121: Auto = Mitte zwischen Lockangebot und regulaerem Preis (live)")
  F.Update()
  check(not F.quick.auto.disabled, "0.121: mit Lockangebot ist Auto frei")
  local click = F.quick.auto.scripts and F.quick.auto.scripts.OnClick
  if click then click(F.quick.auto) else F.SetLimit(v) end
  check(F.ManualLimit(7992) == 76, "0.121: Klick setzt Kaufen bis")
  -- einzelnes Stueck darueber ist nicht regulaer
  ns.Buy.live[7992] = { rows = { { price = 53, qty = 1, own = 0 }, { price = 70, qty = 1, own = 0 }, { price = 95, qty = 8, own = 0 }, commodity = true }, t = clock + 1, commodity = true }
  check(Q.AutoLimit(7992) == 74, "0.121: regulaer erst ab 2 Stueck")
  -- ohne Abfrage gilt der guenstigste Preis bei der Erkennung
  ns.Buy.live[7992] = nil
  check(Q.AutoLimit(7992) == 77, "0.121: ohne Abfrage der Preis bei der Erkennung")
  -- kein Abstand: nichts
  Q.AddBait(7992, 3, 100, false, 1, 101)
  check(Q.AutoLimit(7992) == nil, "0.121: ohne Abstand kein Vorschlag")
  -- aufraeumen
  Q.SetMode("buyout", true)
  F.SetLimit(nil)
  F.manualGold = nil
  Q.hold = nil
  Q.baits[7992] = nil
  ns.Scan.ahOpen, GetMoney = keepOpen, keepMoney
  market.items[7992], ns.Buy.live[7992], mod.acc.commodity[7992] = nil, nil, nil
  Rd.entries, Rd.gone, Rd.job, Rd.focus = {}, {}, nil, nil
end)()

-- ===== 0.123: Auto auch ueber Kaufen bis, Knopf leuchtet an der Grenze =====
;(function()
  local F, Q = ns.Focus, ns.Quick
  local keepOpen, keepMoney, keepTime = ns.Scan.ahOpen, GetMoney, GetTime
  local now = 500
  GetTime = function() return now end
  GetMoney = function() return 10000000 end
  ns.Scan.ahOpen = true
  mod.acc.commodity[7993] = true
  market.items[7993] = { m = 99, md = 150, q = 25, n = 2, t = clock, nm = "Lockleder", ql = 1 }
  Rd.entries, Rd.gone, Rd.job = {}, {}, nil
  Q.baits[7993] = nil
  F.Set(7993)
  Q.SetMode("quick")
  F.SetLimit(55)
  -- Lockangebot zu 60 ueber Kaufen bis 55: erkannt, nicht gemeldet
  local p0 = { t = 500, min = 99, lv = { { price = 99, qty = 20 } } }
  local s1 = { t = 501, min = 60, lv = { { price = 60, qty = 1 }, { price = 99, qty = 20 } } }
  Q.baitPing = nil
  Q.OnSample(7993, p0, s1)
  check(Q.baits[7993] and #Q.baits[7993] == 1 and Q.baits[7993][1].above and Q.baitPing == nil, "0.123: Lockangebot ueber Kaufen bis erkannt, ohne Ton")
  check(Q.BaitStats(7993) == nil, "0.123: Zeile Lockangebote zaehlt es nicht")
  ns.Buy.live[7993] = { rows = { { price = 60, qty = 1, own = 0 }, { price = 99, qty = 20, own = 0 }, commodity = true }, t = clock, commodity = true }
  local v, bait, reg, high = Q.AutoLimit(7993)
  check(v == 79 and bait == 60 and reg == 99 and high, "0.123: Auto hebt Kaufen bis an (Mitte 60 und 99)")
  F.Update()
  check(not F.quick.auto.disabled and F.quick.auto.locked, "0.123: Auto frei und leuchtet")
  local click = F.quick.auto.scripts and F.quick.auto.scripts.OnClick
  if click then click(F.quick.auto) else F.SetLimit(v) end
  F.Update()
  check(F.ManualLimit(7993) == 79 and not F.quick.auto.locked, "0.123: nach dem Klick Kaufen bis 79, Knopf leuchtet nicht mehr")
  -- genau auf dem Lockpreis: leuchtet
  F.SetLimit(60)
  F.Update()
  check(F.quick.auto.locked, "0.123: Kaufen bis genau auf dem Lockpreis, Knopf leuchtet")
  -- aufraeumen
  Q.SetMode("buyout", true)
  F.SetLimit(nil)
  F.manualGold = nil
  Q.hold = nil
  Q.baits[7993], Q.baitPing = nil, nil
  GetTime, ns.Scan.ahOpen, GetMoney = keepTime, keepOpen, keepMoney
  market.items[7993], ns.Buy.live[7993], mod.acc.commodity[7993] = nil, nil, nil
  Rd.entries, Rd.gone, Rd.job, Rd.focus = {}, {}, nil, nil
end)()

-- ===== 0.125: Einbrueche im Fokus, Auto auch fuer Einbrueche, letzter Kauf =====
;(function()
  local F, Q, QS = ns.Focus, ns.Quick, ns.QuickStats
  local keepOpen, keepMoney, keepTime = ns.Scan.ahOpen, GetMoney, GetTime
  local now = 900
  GetTime = function() return now end
  GetMoney = function() return 10000000 end
  ns.Scan.ahOpen = true
  local key = 7994
  mod.acc.commodity[key] = true
  market.items[key] = { m = 200, md = 200, q = 25, n = 2, t = clock, nm = "Seidenprobe", ql = 1 }
  Rd.entries, Rd.gone, Rd.job = {}, {}, nil
  Q.baits[key], Q.sessions[key], QS.lows[key] = nil, nil, nil
  F.Set(key)
  Q.SetMode("quick")
  F.SetLimit(150)
  check(plain((Q.DipText(key))) == "noch keiner", "0.125: Zeile Einbruch ohne Einbruch")
  check(plain(Q.LastBuyText(key)) == "Noch nichts gekauft.", "0.125: ohne Kauf")
  -- Einbruch mit 20 Stueck zu 150 (genau auf Kaufen bis), regulaer 200, 152 knapp darueber
  local p0 = { t = 900, min = 200, lv = { { price = 200, qty = 100 } } }
  local s1 = { t = 901, min = 150, lv = { { price = 150, qty = 20 }, { price = 152, qty = 5 }, { price = 200, qty = 100 } } }
  Q.OnSample(key, p0, s1)
  local ss = Q.sessions[key]
  check(ss and ss.dips == 1 and ss.dipLow == 150 and ss.lastDip.qty == 25 - 5, "0.125: Einbruch im Fokus gemerkt (Menge der Stufe)")
  -- Folge: keine Lockangebote, Auto trotzdem frei ueber den Einbruch
  ns.Buy.live[key] = { rows = { { price = 150, qty = 20, own = 0 }, { price = 152, qty = 5, own = 0 }, { price = 200, qty = 100, own = 0 }, commodity = true }, t = clock, commodity = true }
  local v, low, reg, high, kind = Q.AutoLimit(key)
  check(v == 175 and low == 150 and reg == 200 and high and kind == "dip", "0.125: Auto ueber Einbruch, regulaer nicht die Stufe knapp darueber: " .. tostring(v) .. "/" .. tostring(reg))
  F.Update()
  check(not F.quick.auto.disabled and F.quick.auto.locked, "0.125: Auto frei und leuchtet beim Einbruch auf Kaufen bis")
  -- noch ein Einbruch nach einer Minute, tiefer
  now = 980
  local p2 = { t = 979, min = 200, lv = { { price = 200, qty = 100 } } }
  local s2 = { t = 980, min = 120, lv = { { price = 120, qty = 8 }, { price = 200, qty = 100 } } }
  Q.OnSample(key, p2, s2)
  F.UpdateQuickMove(ns.Measure.Values())
  check(plain(F.mRows[5].label.text) == "Einbruch" and plain(F.mRows[5].value.text) == "tiefster 1s 20c (2)", "0.125: Zeile Einbruch: " .. plain(F.mRows[5].value.text))
  check(F.mRows[5].tip and F.mRows[5].tip[1]:find("8 Stück", 1, true), "0.125: Tooltip mit dem letzten Einbruch")
  -- juengeres Lockangebot geht vor
  local s3 = { t = 985, min = 90, lv = { { price = 90, qty = 1 }, { price = 120, qty = 8 }, { price = 200, qty = 100 } } }
  Q.OnSample(key, s2, s3)
  local _, low3, _, _, kind3 = Q.AutoLimit(key)
  check(kind3 == "bait" and low3 == 90, "0.125: das juengere zaehlt, hier das Lockangebot")
  -- letzter Kauf und Durchschnitt
  Q.OnBought({ key = key, quick = true }, 10, 1500)
  Q.OnBought({ key = key, quick = true }, 4, 520)
  now = 990
  check(plain(Q.LastBuyText(key)):find("Letzter Kauf: 4 Stück, Ø 1s 30c, vor ", 1, true) == 1, "0.125: letzter Kauf: " .. plain(Q.LastBuyText(key)))
  check(plain((Q.BoughtText(key))):find("14 Stück", 1, true) and plain((Q.BoughtText(key))):find("Ø 1s 44c", 1, true), "0.125: Gekauft mit Durchschnitt: " .. plain((Q.BoughtText(key))))
  F.Update()
  check(F.quick.lastBuy.shown ~= false and plain(F.quick.lastBuy.text):find("4 Stück", 1, true), "0.125: letzter Kauf unter dem Kaufknopf")
  -- aufraeumen
  Q.SetMode("buyout", true)
  check(F.quick.lastBuy.shown == false, "0.125: im Aufkauf kein letzter Kauf")
  F.SetLimit(nil)
  F.manualGold = nil
  Q.hold = nil
  Q.baits[key], Q.sessions[key], QS.lows[key], Q.baitPing = nil, nil, nil, nil
  GetTime, ns.Scan.ahOpen, GetMoney = keepTime, keepOpen, keepMoney
  market.items[key], ns.Buy.live[key], mod.acc.commodity[key] = nil, nil, nil
  mod.acc.quickStats = nil
  Rd.entries, Rd.gone, Rd.job, Rd.focus = {}, {}, nil, nil
end)()

-- Keine unerwarteten Fehlermeldungen
local n = 0 for _, l in ipairs(out) do if l:find("Fehler") and not l:find("hat einen Fehler gemeldet", 1, true) then n = n + 1 end end  -- erwartete Meldung aus dem Verkaufen-Test
check(n == 0, "keine Fehlermeldungen")
-- 0.81: einmaliger Hinweis zum Neuaufbau (Kern-API 20)
-- Eine zweite Meldung mit derselben id lehnt der Kern ab: dann hat Broker sie schon gemeldet
check(Peon.API >= 20 and Peon.AddNotice({ id = "broker:umbau-2026-11", title = "x" }) == false, "0.81: Broker hat den Hinweis broker:umbau-2026-11 gemeldet")
check(type(ns.L.NOTICE_REBUILD_TEXT) == "table" and #ns.L.NOTICE_REBUILD_TEXT == 4 and ns.L.NOTICE_REBUILD_TITLE ~= "NOTICE_REBUILD_TITLE", "0.81: Titel und vier Absaetze")
check(Peon.AddNotice({ id = "broker:schnellkauf-2026-11", title = "x" }) == false, "0.117: Broker hat den Hinweis broker:schnellkauf-2026-11 gemeldet")
check(ns.L.NOTICE_QUICK_TITLE == "Der Button ist heiß" and type(ns.L.NOTICE_QUICK_TEXT) == "table" and #ns.L.NOTICE_QUICK_TEXT == 4
  and ns.L.NOTICE_QUICK_TEXT[3]:find("eigene Gefahr", 1, true), "0.117: Titel und vier Absaetze, Hinweis auf eigene Gefahr")
-- ===== 0.120: Marktbewegung nur in der Kaufzone, Preissprung ab 2 % =====
;(function()
  local M = ns.Measure
  local function lv(list)
    local rows = { offers = {}, commodity = true }
    for i, x in ipairs(list) do
      rows.offers[#rows.offers + 1] = { id = i, q = x[2], p = x[1] }
      rows[#rows + 1] = { price = x[1], qty = x[2], own = 0 }
    end
    return rows
  end
  local a = M.Sample(lv({ { 497, 69 }, { 498, 479 }, { 540, 100 } }), 0, nil)
  local b = M.Sample(lv({ { 497, 60 }, { 498, 479 }, { 540, 150 }, { 520, 10 } }), 1, nil)
  check(math.abs(M.Zone(a, b) - 521.85) < 0.01, "0.120: Kaufzone bis 5 % ueber dem guenstigsten")
  local pr = M.Pair(a, b, nil)
  check(pr.nNew == 2 and pr.zNew == 1 and pr.nSold == 1 and pr.zSold == 1 and pr.newAll == 60 and not pr.jump,
    "0.120: Einstellung oben im Stapel zaehlt nicht fuer die Bewegung, Zufluss bleibt fuer den ganzen Markt")
  check(not M.IsJump(497, 498) and M.IsJump(497, 485) and M.IsJump(500, 510), "0.120: Preissprung erst ab 2 %")
  mod.db.quickJumpPct, mod.db.quickZonePct = 0, 10
  check(M.IsJump(497, 498) and math.abs(M.Zone(a, b) - 546.7) < 0.01, "0.120: Grenzen einstellbar")
  pr = M.Pair(a, b, nil)
  check(pr.zNew == 2, "0.120: groessere Kaufzone zaehlt mehr")
  mod.db.quickJumpPct, mod.db.quickZonePct = nil, nil
  local v = { n = 5, elapsed = 600, newPerMin = 40, soldPerMin = 30, jumpsPerMin = 1, zNewPerMin = 1, zSoldPerMin = 1 }
  local code, ev = ns.Quick.Movement(v)
  check(code == "mid" and ev == 3, "0.120: Bewertung aus der Kaufzone: viel Bewegung oben macht nicht lebhaft (" .. tostring(code) .. ")")
end)()

-- ===== 0.122: Gelegenheiten langfristig (QuickStats.lua) =====
;(function()
  local QS, M = ns.QuickStats, ns.Measure
  local function lv(list)
    local rows = { offers = {}, commodity = true }
    for i, x in ipairs(list) do
      rows.offers[#rows.offers + 1] = { id = i, q = x[2], p = x[1] }
      rows[#rows + 1] = { price = x[1], qty = x[2], own = 0 }
    end
    return rows
  end
  local key = 7999
  mod.acc.commodity[key] = true
  mod.acc.quickStats = nil
  check(QS.Get(key) == nil and plain(QS.Cell(key)) == "-", "0.122: ohne Beobachtung nichts")
  local a = M.Sample(lv({ { 500, 50 }, { 520, 100 } }), 100, nil)
  local b = M.Sample(lv({ { 470, 5 }, { 500, 50 }, { 520, 100 } }), 101, nil)
  local c = M.Sample(lv({ { 440, 1 }, { 470, 5 }, { 500, 50 } }), 130, nil)
  local d = M.Sample(lv({ { 490, 3 }, { 500, 50 } }), 131, nil)
  check(QS.Dip(a, b) and QS.Dip(a, b).price == 470, "0.122: neues Angebot ab 2 Stueck mindestens 5 % unter dem guenstigsten ist ein Einbruch")
  check(QS.Dip(b, c) == nil, "0.122: einzelnes Stueck ist kein Einbruch (Lockangebot)")
  check(QS.Dip(a, d) == nil, "0.122: nur 2 % darunter ist kein Einbruch")
  QS.OnPair(key, a, b)
  QS.OnPair(key, b, c)   -- Abstand 29 Sek. zaehlt nur 10
  QS.OnFollow(key)
  local v = QS.Get(key)
  check(v and v.secs == 11 and v.dips == 1 and v.baits == 1 and v.follows == 1 and not v.sure,
    "0.122: Zeit mit Obergrenze je Abstand, Einbruch, Lockangebot, Nachahmer gezaehlt: " .. tostring(v and v.secs) .. "/" .. tostring(v and v.dips) .. "/" .. tostring(v and v.baits) .. "/" .. tostring(v and v.follows))
  check(plain(QS.Cell(key)) == "-" and QS.Score(key) == 0, "0.124: vor 30 Min. kein Wert je Std. in den Listen, zaehlt nicht fuer die Sortierung")
  check(plain((QS.FocusText(key))) == "1 Einbrüche, 1 Lockangebote (1 Min.)", "0.124: Fokus zaehlt einfach: " .. plain((QS.FocusText(key))))
  -- ab 0.124 ohne Gewichtung: Tage im Zeitraum zaehlen voll, aelter faellt weg, alte Einbrueche (d) zaehlen nicht
  local st = QS.Store(true)
  local today = QS.Today()
  st[key] = { [today] = { s = 1800, e = 2, d = 50, b = 0, f = 0 }, [today - 5] = { s = 1800, e = 4, b = 2, f = 0 }, [today - 20] = { s = 9999, e = 99, b = 0, f = 0 } }
  v = QS.Get(key)
  check(v and v.secs == 3600 and v.dips == 6 and v.baits == 2 and v.sure and math.abs(v.perHour - 6) < 0.001 and QS.Score(key) == 6,
    "0.124: Tage im Zeitraum zaehlen voll, darueber gar nicht: " .. tostring(v and v.dips))
  check(plain(QS.Cell(key)) == "6" and plain((QS.FocusText(key))) == "6 Einbrüche, 2 Lockangebote (1 Std.)", "0.124: Spalte und Zeile im Fokus: " .. plain((QS.FocusText(key))))
  st[key][today] = nil
  QS.Add(key, "d", 1)
  check(st[key][today - 20] == nil and st[key][today - 5] and st[key][today].d == 1, "0.122: neuer Tag raeumt Tage ueber dem Zeitraum weg")
  mod.db.quickDipPct = 2
  check(QS.Dip(a, d) ~= nil, "0.122: Grenze fuer Einbruch einstellbar")
  mod.db.quickDipPct = nil
  -- Massenware nur
  mod.acc.commodity[key] = false
  local before = QS.Get(key).secs
  QS.OnPair(key, a, b)
  check(QS.Get(key).secs == before, "0.122: Einzelgegenstaende zaehlen nicht")
  mod.acc.commodity[key], mod.acc.quickStats = nil, nil
  QS.lows[key] = nil
end)()

-- ===== 0.124: Einbruch nur bei echtem Tief der letzten Minute =====
;(function()
  local QS, M = ns.QuickStats, ns.Measure
  local function lv(list)
    local rows = { offers = {}, commodity = true }
    for i, x in ipairs(list) do
      rows.offers[#rows.offers + 1] = { id = i, q = x[2], p = x[1] }
      rows[#rows + 1] = { price = x[1], qty = x[2], own = 0 }
    end
    return rows
  end
  local key = 7998
  mod.acc.commodity[key] = true
  mod.acc.quickStats, QS.lows[key] = nil, nil
  -- lebhafter Markt: 25 wird weggekauft, 30 ist kurz das guenstigste, dann wieder 25
  local s1 = M.Sample(lv({ { 25, 40 }, { 30, 100 } }), 100, nil)
  local s2 = M.Sample(lv({ { 30, 100 } }), 102, nil)
  local s3 = M.Sample(lv({ { 25, 20 }, { 30, 100 } }), 104, nil)
  check(QS.Dip(s2, s3) ~= nil, "0.124: gegen die vorige Abfrage allein waere es ein Einbruch")
  QS.OnPair(key, s1, s2)
  QS.OnPair(key, s2, s3)
  check(QS.Get(key).dips == 0, "0.124: Wiedereinstellen nach Auskauf ist kein Einbruch")
  -- echtes neues Tief
  local s4 = M.Sample(lv({ { 23, 10 }, { 25, 20 }, { 30, 100 } }), 106, nil)
  QS.OnPair(key, s3, s4)
  check(QS.Get(key).dips == 1, "0.124: echtes neues Tief ist ein Einbruch")
  -- einzelnes Lockangebot verschiebt das Tief nicht
  local s5 = M.Sample(lv({ { 10, 1 }, { 23, 10 }, { 30, 100 } }), 108, nil)
  local s6 = M.Sample(lv({ { 22, 5 }, { 23, 10 }, { 30, 100 } }), 110, nil)
  QS.OnPair(key, s4, s5)
  QS.OnPair(key, s5, s6)
  check(QS.Get(key).dips == 1, "0.124: einzelnes Lockangebot zu 10 senkt das Tief nicht, 22 ist nicht 5 % unter 23")
  -- nach einer Minute zaehlt das alte Tief nicht mehr
  local s7 = M.Sample(lv({ { 30, 100 } }), 200, nil)
  local s8 = M.Sample(lv({ { 27, 5 }, { 30, 100 } }), 202, nil)
  QS.OnPair(key, s6, s7)
  QS.OnPair(key, s7, s8)
  check(QS.Get(key).dips == 2, "0.124: nach einer Minute gilt das neue Tief: " .. tostring(QS.Get(key).dips))
  mod.acc.commodity[key], mod.acc.quickStats, QS.lows[key] = nil, nil, nil
end)()

-- ===== 0.126: Beobachten/Schnellkauf: gespeicherte Bewegung, Treffer, Tiefstpreis 24 Std., Gekauft =====
;(function()
  local QS, QC, M, Wt, WP, Q = ns.QuickStats, ns.QuickChances, ns.Measure, ns.Watch, ns.WatchPage, ns.Quick
  local function lv(list)
    local rows = { offers = {}, commodity = true }
    for i, x in ipairs(list) do
      rows.offers[#rows.offers + 1] = { id = i, q = x[2], p = x[1] }
      rows[#rows + 1] = { price = x[1], qty = x[2], own = 0 }
    end
    return rows
  end
  local key = 7997
  mod.acc.commodity[key] = true
  mod.acc.quickStats, mod.acc.quickMove, QS.lows[key] = nil, nil, nil
  check(mod.db.quickStatDays == 7 and QS.Days() == 7, "0.126: Zeitraum Vorgabe 7 Tage")
  Wt.Add(key, { name = "Ampelerz" })
  Wt.SetQuick(key, 100, nil, true, true)
  check(QS.Limit(key) == 100, "0.126: Kaufen bis des Schnellkaufs aus der Beobachtung")
  -- Treffer: erst taucht 90 auf (Treffer), bleibt stehen (kein neuer), verschwindet, kommt wieder (Treffer)
  local s1 = M.Sample(lv({ { 120, 10 }, { 130, 50 } }), 100, nil)
  local s2 = M.Sample(lv({ { 90, 1 }, { 120, 10 }, { 130, 50 } }), 102, nil)
  local s3 = M.Sample(lv({ { 90, 1 }, { 118, 3 }, { 130, 50 } }), 104, nil)
  local s4 = M.Sample(lv({ { 118, 3 }, { 130, 50 } }), 106, nil)
  local s5 = M.Sample(lv({ { 95, 4 }, { 118, 3 }, { 130, 50 } }), 108, nil)
  QS.OnPair(key, s1, s2); QS.OnPair(key, s2, s3); QS.OnPair(key, s3, s4); QS.OnPair(key, s4, s5)
  local v = QS.Get(key)
  check(v and v.hits == 2, "0.126: Treffer zaehlt nur das Auftauchen unter Kaufen bis: " .. tostring(v and v.hits))
  check(QS.Low24(key) == 95, "0.126: Tiefstpreis 24 Std. nur aus Stufen ab 2 Stueck: " .. tostring(QS.Low24(key)))
  -- alter Tiefstpreis faellt nach 24 Std. heraus
  local d = QS.Store(false)[key][QS.Today()]
  d.lo[QS.Hour() - 30] = 10
  check(QS.Low24(key) == 95, "0.126: Tiefstpreis aelter als 24 Std. zaehlt nicht")
  -- Gekauft bleibt gespeichert
  Q.OnBought({ key = key, quick = true }, 5, 450)
  v = QS.Get(key)
  check(v.bought == 5 and v.cost == 450, "0.126: Kauf im Schnellkauf im Zeitraum gespeichert")
  -- Bewegung: Pruefung speichern, nach "Logout" (QC.res leer) wieder da
  QC.res = {}
  QC.res[key] = nil
  QC.run = { key = key, got = 3, secs = 6, nNew = 4, nSold = 2, jumps = 0, inAll = 10, sold = 5, baits = 0 }
  QC.Finish()
  check(type(mod.acc.quickMove) == "table" and mod.acc.quickMove[ns.MarketKey()][key], "0.126: Pruefung gespeichert")
  QC.res = {}
  local r = QC.Result(key)
  check(r and r.class == "high" and r.early and not r.old and QC.DueIn(key) == 0, "0.126: nach Logout Bewegung wieder da, sofort wieder dran")
  check(QC.Light(r):find("|T", 1, true) ~= nil and QC.Light(nil) ~= QC.Light(r), "0.126: Ampel als Punkt")
  mod.acc.quickMove[ns.MarketKey()][key].p[1].t = time() - 7 * 3600
  QC.res = {}
  r = QC.Result(key)
  check(r and r.old, "0.126: nach 6 Std. alt (blass)")
  -- Zeile und Spalten
  local row
  for _, x in ipairs(WP.Rows("quick")) do if x.key == key then row = x end end
  check(row and row.hits == 2 and row.dips == 1 and row.low24 == 95, "0.126: Zeile mit Treffern, Einbruechen und Tiefstpreis: " .. tostring(row and row.hits) .. "/" .. tostring(row and row.dips) .. "/" .. tostring(row and row.low24) .. "/" .. tostring(row and row.limit))
  if WP.lists and WP.lists.quick and WP.lists.quick.o then
    local t = {}
    for _, c in ipairs(WP.lists.quick.o.columns) do t[#t + 1] = plain(c.title) end
    local cols = table.concat(t, ",")
    check(not cols:find("Rat", 1, true) and cols:find("Treffer,Einbrüche,Tief 24 Std.", 1, true), "0.126: Spalten ohne Rat: " .. cols)
  end
  -- aufraeumen
  Wt.Remove(key)
  QC.res, QC.run = {}, nil
  Q.sessions[key], QS.lows[key] = nil, nil
  mod.acc.commodity[key], mod.acc.quickStats, mod.acc.quickMove = nil, nil, nil
end)()

-- ===== 0.127: Markttausch (Trade.lua, Peon_Broker_Marktvergleich.md 6.2) =====
;(function()
  local T, C, R, G = ns.Trade, ns.Chances, ns.Radar, ns.Pages
  local HK, NK = ns.HomeMarketKey(), ns.NeutralMarketKey()
  local oldGet, oldOpen, oldExists, oldUFG, oldCounts = Peon.GetModule, ns.Scan.ahOpen, rawget(_G, "UnitExists"), UnitFactionGroup, ns.Stock.Counts
  local bridgeT = clock - 600
  local fake = { Compare = function(_, market)
      if market ~= HK then return nil end
      return bridgeT, { [2770] = "n:80:200:90:120:2:15:86:900:g", ["7001"] = "h:100:300:185:30:1:9999:50:40:y", [7002] = "kaputt" },
        { [2770] = "Fraktion kauft für 80c" }, { cutN = 1500, cutSure = false, minPct = 20, minNet = 10 } end }
  Peon.GetModule = function(self, k) if k == "bridge" then return fake end return oldGet(self, k) end
  check(T.Parse("n:80:200:90:120:2:15:86:900:g").perDay == 12 and T.Parse("n:1:2:3:4:5:9999:50:7:y").supply == nil and T.Parse("x") == nil, "0.127: Eintrag lesen")
  local entries, t, mgr = T.Entries()
  check(#entries == 2 and t == bridgeT and mgr, "0.127: Liste des Managers, kaputte Zeile uebersprungen")
  check(T.Say(2770) == "Fraktion kauft für 80c", "0.127: Satz des Managers")
  check(C.TabOn("trade") and T.Count() == 2, "0.127/0.128: Unterreiter an, Zahl = alle Eintraege der Auswahl")
  mod.db.chancesShowT = false
  check(not C.TabOn("trade") and T.Count() == 0, "0.127: Unterreiter abschaltbar")
  mod.db.chancesShowT = true
  -- unterwegs
  ns.Scan.ahOpen = false
  local rows = T.Rows()
  local r2770
  for _, r in ipairs(rows) do if r.key == 2770 then r2770 = r end end
  check(r2770 and r2770.state == "away" and plain(r2770.stateText) == "im eigenen Haus kaufen", "0.127: unterwegs: wo kaufen")
  -- am eigenen Haus (Quelle fuer Richtung n)
  ns.Scan.ahOpen = true
  UnitExists = function(u) return u == "npc" end
  UnitFactionGroup = function(u) return "Horde", "Horde" end
  local hm = D.Market(HK, true)
  local e = hm.items[2770]
  local oldM, oldLt, oldGone = e.m, e.lt, e.gone
  e.m, e.lt, e.gone = 80, clock, nil
  check(T.Where("n") == "src" and select(1, T.State({ key = 2770, dir = "n", buy = 80, sell = 200 })) == "buy", "0.127: am Haus der Quelle kaufbar")
  e.m = 120
  check(select(1, T.State({ key = 2770, dir = "n", buy = 80, sell = 200 })) == "dear", "0.127: zu teuer")
  e.lt = clock - 3600
  check(select(1, T.State({ key = 2770, dir = "n", buy = 80, sell = 200 })) == "open", "0.127: alter Preis: ungeprueft")
  -- 0.128: neuere Preise als der Stand des Managers entfernen eine Chance, die nicht mehr passt
  local oldT = e.t
  e.t, e.lt, e.m = bridgeT - 10, nil, 300   -- aelter als der Stand: zaehlt nicht
  check(#T.Entries() == 2, "0.128: aeltere Preise aendern nichts")
  e.lt, e.m = clock, 150                    -- neuer: Gewinn 200 x 0,85 - 150 = 20, Spanne 13 % < 20 %
  local list1 = T.Entries()
  check(#list1 == 1 and list1[1].key == 7001 and T.GoneAt(2770, bridgeT) and T.GoneCount() == 1, "0.128: Chance mit neuem Preis entfernt")
  e.m = 80
  check(#T.Entries() == 1, "0.128: entfernt bleibt weg, auch wenn der Preis wieder passt")
  check(plain(T.StatusText()):find("1 entfernt", 1, true), "0.128: Status nennt Entfernte")
  bridgeT = clock + 5
  check(#T.Entries() == 2 and not T.GoneAt(2770, bridgeT), "0.128: neuerer Stand des Managers bringt sie zurueck")
  bridgeT = clock - 600
  T.GoneStore()[2770] = nil
  e.t, e.lt, e.m = oldT, clock, 80
  local keys = T.Keys()
  check(#keys == 2, "0.127: Alle pruefen: beide Zeilen betreffen das eigene Haus")
  -- 0.128: laufende Abfrage, solange die Liste offen ist
  local oldShown = C.Shown
  C.Shown = function() return true end
  C.SelectTab("trade")
  T.sent = {}
  local k1 = T.NextKey()
  local k2 = T.NextKey()
  check(T.Active() and k1 ~= nil and k2 ~= nil and k1 ~= k2, "0.128: Zeilen reihum abgefragt")
  local rk, rkind = R.NextKey()
  check(rk ~= nil and rkind == "trade", "0.128: Radar fragt die offene Liste Markttausch ab")
  C.Shown = oldShown
  R.forceMode = "trade"
  check(#R.SearchKeys("trade") == 2, "0.127: Radar fragt die Zeilen des Markttauschs ab")
  R.forceMode = nil
  -- Klick am Haus der Quelle merkt den Gegenstand fuer das Ziel
  T.Remember({ key = 2770, dir = "n", sell = 200 })
  check(mod.acc.tradeGoods[2770] and mod.acc.tradeGoods[2770].dir == "n", "0.127: Gepaeck gemerkt")
  -- am neutralen Haus (Ziel fuer Richtung n)
  UnitFactionGroup = function(u) if u == "npc" then return nil end return "Horde", "Horde" end
  check(ns.AHMarketKey() == NK and T.Where("n") == "dst" and T.Where("h") == "src", "0.127: am neutralen Haus")
  local nm = D.Market(NK, true)
  nm.items[2770] = { m = 300, md = 300, q = 2, n = 1, t = clock, lt = clock }
  ns.Stock.Counts = function() return 0, 0, 0, 0 end
  check(select(1, T.State({ key = 2770, dir = "n", buy = 80, sell = 200 })) == "free", "0.127: am Ziel frei")
  nm.items[2770].m = 150
  check(select(1, T.State({ key = 2770, dir = "n", buy = 80, sell = 200 })) == "under", "0.127: am Ziel unterboten")
  ns.Stock.Counts = function() return 3, 0, 3, 0 end
  check(select(1, T.State({ key = 2770, dir = "n", buy = 80, sell = 200 })) == "bags", "0.127: im Gepaeck")
  local here = T.GoodsHere()
  check(#here == 1 and here[1].n == 3, "0.127: Ware fuer dieses Haus")
  local n0 = #out
  T.OnAHShow()
  check(#out == n0 + 1 and plain(out[#out]):find("Markttausch: 1", 1, true), "0.127: Hinweis am Zielhaus")
  mod.db.chancesTradeNote = false
  n0 = #out
  T.OnAHShow()
  check(#out == n0, "0.127: Hinweis abschaltbar")
  mod.db.chancesTradeNote = true
  -- Unterreiter in Chancen
  C.SelectTab("trade")
  check(C.Tab() == "trade" and (not C.tpanel or C.tpanel:IsShown()), "0.127: Unterreiter Markttausch waehlbar")
  check(plain(T.StatusText()):find("Anteil Neutral 15 % angenommen", 1, true), "0.127: Status mit angenommenem Anteil")
  -- ohne Manager: keine Liste, nur ein Hinweis (ab 0.128)
  Peon.GetModule = oldGet
  local fe, ft, fm = T.Entries()
  check(#fe == 0 and ft == nil and fm == false, "0.128: ohne Manager keine Chancen")
  check(plain(T.StatusText()):find("Keine Daten vom Peon Manager", 1, true), "0.128: Status ohne Manager")
  -- 0.128: Beobachten, Liste Markttausch
  local Wt, WP = ns.Watch, ns.WatchPage
  Wt.Remove(2589)
  check(Wt.SetTradeOn(2589, true, { name = "Zinnerz" }) and Wt.InTrade(2589) and not Wt.InBuyout(2589) and not Wt.InQuick(2589), "0.128: nur in Markttausch")
  local w89 = Wt.Store()[2589]
  check(type(w89.t) == "table" and (w89.t.lists or 0) > 0, "0.128: Zeit der Listen gesetzt (Abgleich mit dem Manager)")
  local trows = WP.Rows("trade")
  check(#trows == 1 and trows[1].key == 2589 and trows[1].mode == "trade", "0.128: Zeile in Beobachten, Markttausch")
  check(#Wt.TradeKeys() == 1, "0.128: Schluessel fuer die laufende Abfrage")
  mod.db.watchTab = "trade"
  check(WP.Tab() == "trade", "0.128: Unterreiter Markttausch in Beobachten")
  mod.db.watchTab = "buyout"
  Wt.SetQuick(2589, 500, 0, false, false)
  check((Wt.Store()[2589].t.q or 0) > 0, "0.128: Zeit des Schnellkaufs gesetzt")
  Wt.SetQuickOn(2589, false)
  check(Wt.Is(2589) and Wt.InTrade(2589) and not Wt.InQuick(2589), "0.128: Schnellkauf aus, Markttausch bleibt")
  Wt.SetBuyoutOn(2589, true)
  Wt.SetTradeOn(2589, false)
  check(Wt.Is(2589) and Wt.InBuyout(2589) and not Wt.InTrade(2589), "0.128: Markttausch aus: bleibt im Aufkauf")
  Wt.Remove(2589)
  Wt.SetTradeOn(2589, true)
  Wt.SetTradeOn(2589, false)
  check(not Wt.Is(2589), "0.128: nur Markttausch aus: Beobachtung endet")
  -- Abgleich: neuere Werte des Schnellkaufs aus dem Manager gelten
  Wt.SetQuickOn(2589, true, { name = "Zinnerz" })
  local tq = Wt.Store()[2589].t.q
  local inc = { u = Wt.Store()[2589].u + 10, qlim = 777, qgold = 0, t = { q = tq + 10, lists = 0, buy = 0, up = 0 } }
  Wt.Merge(Wt.Store(), PeonBrokerDB.watchGone, { items = { [2589] = inc }, gone = {} })
  check(Wt.Store()[2589].qlim == 777, "0.128: Kaufen bis des Schnellkaufs aus dem Manager uebernommen")
  Wt.Remove(2589)
  -- aufraeumen
  C.SelectTab("spec")
  mod.acc.tradeGoods = nil
  e.m, e.lt, e.gone = oldM, oldLt, oldGone
  D.DeleteMarket(NK)
  ns.Stock.Counts = oldCounts
  ns.Scan.ahOpen, UnitExists, UnitFactionGroup = oldOpen, oldExists, oldUFG
end)()

print("ALLE TESTS OK")
