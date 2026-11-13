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
check(StaticPopupDialogs == POPUPS and POPUPS.PEON_BROKER_DELETE_MARKET, "StaticPopupDialogs nicht neu zugewiesen (sonst ESC-Problem)")
check(type(PeonBrokerDB) == "table" and PeonBrokerDB.debug == false, "PeonBrokerDB angelegt")
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

-- Ereignisse
local ev = PeonBrokerDB.probeEvents
check(ev.AUCTION_HOUSE_SHOW.known == true and ev.NEW_AUCTION_UPDATE.known == false, "unbekannte Ereignisse sauber abgewiesen")

-- Pruefung ohne Auktionshaus
SlashCmdList.PEON_BROKER("pruefen")
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
check(table.concat(names, ",") == "Markt,Verkaufen,Auktionen,Einkaufen,Beobachten,Radar,Fokus,Mehr",
  "0.82: Reiter Markt, Verkaufen, Auktionen, Einkaufen, Beobachten, Radar, Fokus, Mehr (Gegenstand unter Mehr): " .. table.concat(names, ","))
check(Win.tabButtons[2].key == "sell" and Win.tabButtons[2].disabled, "N1: Verkaufen ist unterwegs grau")
check(Win.current == "more" and Win.more and Win.more.current == "prices", "Fenster oeffnet beim zuletzt gewaehlten Reiter (0.82: Gegenstand unter Mehr)")
check(Win.status and Win.status.text.text:find("letzter Stand, nicht live", 1, true) == nil and Win.status.text.text:find("Scan", 1, true),
  "N1: Statuszeile nennt Markt und Scan: " .. tostring(Win.status.text.text))
check(ns.Start == nil and Win.pages.start == nil, "U12: Startseite entfaellt")
Win.Select("buy")
check(Win.current == "buy" and mod.db.windowTab == "buy", "N1: Reiter Einkaufen gewaehlt und gemerkt")
Win.tabButtons[2].scripts.OnClick(Win.tabButtons[2])
check(Win.current == "buy" and Win.tabButtons[2].disabled, "N1: Klick auf Verkaufen bleibt beim bisherigen Reiter")
Win.tabButtons[8].scripts.OnClick(Win.tabButtons[8])
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
    ns.AHTabs.current = "radar"
    sentQ = nil
    check(Buy.ShowInAH({ key = 2770 }) == false and sentQ == nil, "Broker-Reiter offen: nichts tun (Go schliesst vorher die Flaeche)")
    ns.AHTabs.current = wasCur
    curMode = modes.Buy
    AuctionHouseFrame.SearchBar, UIErrorsFrame, AHs.SendBrowseQuery = nil, nil, savedSBQ
    Win.Select("radar")
    check(Win.current == "radar" and Rd.list and Rd.scanButton and Rd.status, "N6: Seite Radar mit Peon.UI")

    -- Radar: weggefallen mit Grund, Pause bei Auswahl, vorhandene Ergebnisse entfernen nichts
    Rd.Halt()
    Rd.entries, Rd.gone, Rd.lastVisible = {}, {}, nil
    VENDOR[7777] = 10
    mod.db.dealMinVendor = 10
    market.items[7777] = { m = 3, md = 10, q = 20, n = 1, t = clock, lv = "3:20", nm = "Billigzeug", ql = 1 }
    Rd.entries[7777] = Rd.Evaluate(7777, { { price = 3, qty = 20, own = 0 } }, true, true)
    Rd.entries[7777].checked = now
    Rd.Refresh()
    -- vorhandene (evtl. alte) Ergebnisse ohne Schnaeppchen: Treffer bleibt
    Rd.Apply({ key = 7777, itemID = 7777 }, { { price = 12, qty = 20, own = 0 } }, true, true)
    check(Rd.entries[7777] and not Rd.gone[7777], "alte Ergebnisse des Spiels entfernen keinen Treffer")
    Rd.Apply({ key = 7777, itemID = 7777 }, { { price = 12, qty = 20, own = 0 } }, true)
    check(Rd.entries[7777] == nil and Rd.gone[7777] and Rd.gone[7777].goneWhy:find("günstigstes jetzt", 1, true), "Live: guenstige Angebote weg -> grau mit Grund")
    local ghostRow for i, it in ipairs(Rd.list:GetItems()) do if it.gone then ghostRow = i end end
    check(ghostRow and plain(Rd.list.list.rows[ghostRow].cells[3].text) == "weg" and plain(Rd.list.list.rows[ghostRow].cells[2].text) ~= "weg"
      and plain(Rd.list.list.rows[ghostRow].cells[2].text) ~= "", "0.75: „weg“ steht unter Art, der moegliche Gewinn bleibt sichtbar")
    now = now + 31
    Rd.Refresh()
    check(Rd.gone[7777] == nil and #Rd.list:GetItems() == 0, "nach 30 Sek. aus der Liste")
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
    local F, T = ns.Focus, ns.AHTabs
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
    check(Rd.entries[7801] and Rd.entries[7801].kind == "vendor" and Rd.entries[7802] == nil, "N6: nur Chancen der Art Haendler")
    local rows = Rd.list:GetItems()
    check(#rows == 1 and rows[1].key == 7801 and rows[1].risk == "low" and rows[1].checked == nil, "N6: Liste aus der Datenbank, nichts live geprueft")
    local cols = {}
    for _, c in ipairs(Rd.list.o.columns) do cols[#cols + 1] = c.title end
    check(table.concat(cols, ",") == "Gegenstand,Gewinn,Art,Risiko,Stand", "N6: schlanke Spalten: " .. table.concat(cols, ","))
    local cells = Rd.list.list.rows[1].cells
    check(cells[1].text == "Billigzeug" and plain(cells[3].text) == "Händler" and plain(cells[4].text) == "gering" and plain(cells[2].text) ~= "",
        "N6: Zeile mit Gewinn, Art und Risiko")
    check(Rd.stats.sent == sent0 and not Rd.loop and Rd.scanButton.disabled and Rd.status.text:find(ns.L.ST_NOT_LIVE, 1, true),
        "N6: unterwegs keine Abfragen, Radar-Scan gesperrt")
    rows[1].seenT = clock - 4000
    check(Rd.Risk(rows[1]) == "mid", "N6: alter, nie live gepruefter Stand: mittleres Risiko")
    rows[1].seenT = clock
    -- unterwegs (ab 0.70): Fokus nur am Auktionshaus. Klick merkt den Gegenstand, die Seite bleibt
    local n0 = #out
    Rd.list.list.rows[1].scripts.OnClick(Rd.list.list.rows[1], "LeftButton")
    check(Win.current == "radar" and F.key == 7801 and mod.acc.focusKey == 7801 and Rd.focus == nil and #out > n0 and out[#out]:find("Auktionshaus", 1, true),
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
    T.tabs.radar.scripts.OnClick(T.tabs.radar)
    check(T.current == "radar" and Rd.Shown() and not Rd.scanButton.disabled and Rd.stats.sent == sent0, "N6: Radar am Auktionator, noch keine Abfrage")
    -- ab 0.71: Erneuern der gezeigten Moeglichkeiten laeuft von selbst, solange der Radar offen ist
    check(Rd.loop and Rd.Renewing() and Rd.scanButton.text == ns.L.RADAR_START, "0.71: Radar offen: Erneuern laeuft ohne Knopf")
    LIVE[7801] = { { unitPrice = 3, quantity = 15 }, { unitPrice = 12, quantity = 50 } }
    Rd.pending, Rd.lastSend = nil, -100
    now = now + 1; tick()
    check(Rd.pending and Rd.pending.key == 7801, "0.71: Erneuern fragt die gezeigte Moeglichkeit ab")
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 7801)
    check(Rd.entries[7801].live and Rd.entries[7801].qty == 15 and Rd.list:GetItems()[1].checked ~= nil, "N6: Chance live bestaetigt, Menge neu")
    Rd.lastSend = -100
    now = now + 1; tick()
    check(Rd.pending == nil and Rd.renewEvery == 60, "0.71: gerade geprueft: erst nach 60 Sek. wieder")
    check(Rd.RenewInterval(200) == 120 and Rd.RenewInterval(100) > 60, "0.71: viele Moeglichkeiten: Abstand waechst, hoechstens 2 Min.")
    -- Radar-Scan sucht neue Moeglichkeiten, hier unter allen Massenwaren
    mod.db.radarScanMode = "mass"
    Rd.scanButton.scripts.OnClick(Rd.scanButton)
    check(Rd.running and Rd.loop and Rd.scanButton.text == ns.L.RADAR_STOP, "N6: Radar-Scan gestartet")
    Rd.lastSend = -100
    now = now + 1; tick()
    check(Rd.pending and Rd.search and Rd.search.mode == "mass" and Rd.search.done == 1 and #Rd.search.keys >= 2, "0.71: Radar-Scan fragt eine Massenware ab")
    local searched = Rd.pending.key
    check(mod.acc.commodity[searched] or D.IsCommodity(searched), "0.71: nur Massenware: " .. tostring(searched))
    Rd.pending = nil
    check(plain(Rd.status.text):find("Massenware", 1, true), "0.71: Status nennt die Auswahl: " .. plain(Rd.status.text))
    -- Anteil: faellig sind Erneuern und Suche, die Suche bekommt mindestens 20 %
    Rd.mix = { renew = 9, search = 1 }
    Rd.entries[7801].checked = nil
    local k1, kind1 = Rd.NextKey()
    Rd.mix = { renew = 1, search = 9 }
    local k2, kind2 = Rd.NextKey()
    check(kind1 == "search" and kind2 == "renew" and k2 == 7801, "0.71: Suche bekommt ihren Anteil, sonst zuerst Erneuern")
    Rd.entries[7801].checked = GetTime()
    Rd.scanButton.scripts.OnClick(Rd.scanButton)
    check(not Rd.running and Rd.Renewing(), "N6/0.71: Radar-Scan gestoppt, Erneuern laeuft weiter")
    mod.db.radarScanMode = "watch"
    -- Klick: Fokus fragt nur diesen Gegenstand ab
    Rd.list.list.rows[1].scripts.OnClick(Rd.list.list.rows[1], "LeftButton")
    check(T.current == "focus" and F.Shown() and F.key == 7801 and Rd.focus and Rd.focus.key == 7801 and Rd.loop and not Rd.running and not T.back.shown
        and F.origin == "radar" and F.backButton.text == "Zurück zu Radar",
        "N6/0.82: Fokus am Auktionator: genau dieser Gegenstand wird abgefragt, Zurueck unten fuehrt zum Radar")
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
    Win.Open("radar")
    local d1 = Rd.entries[7901]
    check(d1 and d1.kind == "buyout" and d1.gain == 31000, "H1: Aufkauf aus dem Komplettscan im Radar")
    local r1
    for i, r in ipairs(Rd.list:GetItems()) do if r.key == 7901 then r1 = i end end
    local cells = Rd.list.list.rows[r1].cells
    check(plain(cells[3].text) == "Aufkauf" and plain(cells[4].text) == "mittel", "H1: Zeile mit Art Aufkauf und Risiko")
    -- Sortierung: rot nach unten
    local sortFn = Rd.list.o.columns[2].sort
    check(sortFn({ showGain = 100, risk = "high" }) < sortFn({ showGain = 1, risk = "low" }) and sortFn({ gone = true }) < sortFn({ showGain = 1, risk = "high" }),
        "H1: Gewinn absteigend, rotes Risiko unten, Weggefallenes ganz unten")
    -- weniger Gold: Chance gilt nicht mehr
    GetMoney = function() return 50000 end
    Rd.Refresh()
    local still = false
    for _, r in ipairs(Rd.list:GetItems()) do if r.key == 7901 and not r.gone then still = true end end
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
    check(plain(ah.SellTab.text) == "Verkaufen" and ah.SellTab.badge and ah.SellTab.badge.shown and ah.SellTab.badge.text.text == "1",
      "H3/0.82: Blizzards Reiter Verkaufen mit Zahl im roten Kreis")
    sf:UpdatePostState()
    local box = A.boxes[sf]
    check(A.lot and A.lot.id == lot.id and box.fill.shown and plain(box.lines.text):find("Posten: gekauft für 10s 38c je Stück, Ziel 15s", 1, true),
        "H3: Rat nennt Einsatz und Ziel, Knopf Zielpreis eintragen: " .. plain(box.lines.text))
    check(plain(box.lines.text):find("unter dem Ziel", 1, true), "H3: Warnung: Markt liegt unter dem Ziel")
    GetTime = function() return now end
    box.fill.scripts.OnClick(box.fill)
    check(setTo == 1500 and sf.price == 1500 and LT.filledAt, "H3: Zielpreis ins Preisfeld geschrieben")
    -- Einstellen: Anhang an PostItem, Ereignis bestaetigt
    sf:PostItem()
    fire("AUCTION_HOUSE_AUCTION_CREATED", 555)
    check(posted == 1 and lot.left == 0 and lot.posted and lot.posted.price == 1500 and lot.posted.qty == 80 and LT.Count() == 0,
        "H3: eingestellt: Posten erledigt, Preis gemerkt")
    check(plain(ah.SellTab.text) == "Verkaufen", "H3: Zahl am Reiter Verkaufen weg")
    -- Blockade direkt nach dem Eintragen: Knopf nicht mehr anbieten
    LT.Add(7961, 10, 10000, 1500, "radar")
    LT.filledAt = now
    fire("ADDON_ACTION_FORBIDDEN", "Peon_Broker", "UNKNOWN()")
    check(type(mod.acc.targetBlocked) == "table" and not LT.CanFill(), "H3: Blockade nach dem Eintragen gemerkt")
    sf:UpdatePostState()
    check(not box.fill.shown and plain(box.lines.text):find("selbst eintippen", 1, true), "H3: dann nur noch der Preis im Rat")
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
    -- Knopf im Berufsfenster: Menue mit Anzahl
    local opened
    MenuUtil = { CreateContextMenu = function(owner, gen)
        local node = { items = {} }
        function node:CreateTitle() end
        function node:CreateButton(t, fn) self.items[#self.items + 1] = { t = t, fn = fn } end
        gen(owner, node); opened = node
    end }
    local keepBlock = C.block
    C.block = C.block or {}
    local keepCalc = C.block.calc
    C.block.calc = { mats = { { id = 7975, q = 3, have = 1, ah = 100 } } }
    C.ListMenu(CreateFrame("Button"))
    check(opened and #opened.items == 4 and opened.items[2].t == "für 5 Herstellungen", "H4: Menue im Berufsfenster: 1, 5, 10, 20 Herstellungen")
    opened.items[2].fn()
    check(list.items[7975] and list.items[7975].wish == 15, "H4: Klick setzt das Material fuer 5 Herstellungen auf die Liste")
    C.block.calc = keepCalc
    C.block = keepBlock
    MenuUtil = nil
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

-- ===== Berufe: Herstellkosten und Gewinn (ab 0.24) =====
;(function()
  local Cr = ns.Craft
  market.items[3001] = { m = 10, md = 12, q = 100, n = 5, t = clock, nm = "Stoff", ql = 1 }
  market.items[3002] = { m = 30, md = 30, q = 10, n = 2, t = clock, nm = "Faden", ql = 1 }
  market.items[3100] = { m = 500, md = 520, q = 10, n = 4, t = clock, nm = "Hemd", ql = 2 }
  market.items[3200] = { m = 20, md = 20, q = 10, n = 4, t = clock, nm = "Lappen", ql = 1 }
  VENDOR[3100], VENDOR[3200] = 50, 1
  local SCH = {
    [11] = { outputItemID = 3100, quantityMin = 1, quantityMax = 1, name = "Hemd",
             reagentSlotSchematics = { { reagents = { { itemID = 3001 } }, quantityRequired = 4, reagentType = 1, required = true },
                                       { reagents = { { itemID = 3002 } }, quantityRequired = 1, reagentType = 1, required = true },
                                       { reagents = { { itemID = 9999 } }, quantityRequired = 1, reagentType = 0, required = false } } },
    [12] = { outputItemID = 3200, quantityMin = 2, quantityMax = 2, name = "Lappen",
             reagentSlotSchematics = { { reagents = { { itemID = 3001 } }, quantityRequired = 5, reagentType = 1, required = true } } },
    [13] = { outputItemID = 3300, quantityMin = 1, name = "Unbekannt", reagentSlotSchematics = { { reagents = { { itemID = 3001 } }, quantityRequired = 1 } } },
  }
  C_TradeSkillUI = { GetAllRecipeIDs = function() return { 11, 12, 13 } end,
    GetRecipeInfo = function(id) return { recipeID = id, learned = id ~= 13 } end,
    GetRecipeSchematic = function(id) return SCH[id] end }
  ProfessionsFrame = CreateFrame("Frame", "ProfessionsFrame")
  fire("TRADE_SKILL_SHOW")
  timers[#timers]()
  local rec = PeonBrokerCharDB.recipes
  check(rec and rec[3100] and rec[3100].m[3001] == 4 and rec[3100].m[3002] == 1 and rec[3100].m[9999] == nil and rec[3300] == nil,
      "Rezepte gelesen: Pflicht-Material, ohne wahlweise Zusaetze, nur erlernte")
  local c = Cr.Calc(rec[3100], 3100)
  check(c.cost == 70 and c.missing == 0 and c.value and c.profit == c.value - 70, "Hemd: Material 4×10c + 30c = 70c, Gewinn = Wert - Material (" .. tostring(c.value) .. ")")
  local c2 = Cr.Calc(rec[3200], 3200)
  check(c2.cost == 50 and c2.n == 2, "Lappen: 2 je Herstellen, Material 50c")
  check(Cr.box and Cr.box.shown and plain(Cr.box.text.text):find("Beste Rezepte", 1, true) and plain(Cr.box.text.text):find("Gegenstand3100", 1, true), "Box am Berufsfenster mit den besten Rezepten")
  Cr.OnSelect(11)
  check(plain(Cr.box.text.text):find("4× Gegenstand3001", 1, true) and plain(Cr.box.text.text):find("Lohnt sich", 1, true), "gewaehltes Rezept: Material einzeln, lohnt sich")
  check(plain(Cr.TooltipText(3100)):find("Material 70c", 1, true) and plain(Cr.TooltipText(3100)):find("Gewinn +", 1, true), "Tooltip-Text: Material und Gewinn")
  market.items[3002] = nil
  check(plain(Cr.TooltipText(3100)):find("(1 ohne Preis)", 1, true) and plain(Cr.TooltipText(3100)):find("unbekannt", 1, true), "Material ohne Preis: Gewinn unbekannt")
  -- ab 0.25.2: Box rueckt hinter die Symbolleiste rechts am Berufsfenster
  local function Fake(l, r, t, b, kids, sc)
    return { GetLeft = function() return l end, GetRight = function() return r end, GetTop = function() return t end,
      GetBottom = function() return b end, GetEffectiveScale = function() return sc or 1 end, IsVisible = function() return true end,
      GetChildren = function() return unpack(kids or {}) end }
  end
  local tab = Fake(1025, 1100, 700, 640)
  local wide = Fake(1020, 1500, 700, 600)           -- zu breit: zaehlt nicht
  local far = Fake(1300, 1350, 700, 600)            -- nicht an der Kante: zaehlt nicht
  check(Cr.SideOffset(Fake(20, 1025, 900, 100, { tab, wide, far })) == 75 + Cr.SIDE_GAP, "Box hinter der Symbolleiste (" .. tostring(Cr.SideOffset(Fake(20, 1025, 900, 100, { tab, wide, far }))) .. ")")
  check(Cr.SideOffset(Fake(20, 1025, 900, 100, { Fake(0, 10, 50, 0, { tab }) })) == 75 + Cr.SIDE_GAP, "Symbolleiste auch eine Ebene tiefer")
  check(Cr.SideOffset(Fake(20, 1025, 900, 100, { wide, far })) == Cr.SIDE_GAP, "ohne Leiste: direkt am Fenster")
  check(Cr.SideOffset({}) == Cr.SIDE_GAP, "Fenster ohne Lage: Standardabstand")
  -- 0.28.1: GetChildren nie ueber pcall (Absturz "L->top < L->ci->top" bei vielen Kindern von UIParent)
  local src = io.open("Peon_Broker/Craft.lua"):read("*a")
  check(not src:find("pcall%([^)]*GetChildren"), "0.28.1: GetChildren ohne pcall")
  local many = {}
  for i = 1, 400 do many[i] = Fake(0, 10, 50, 0, {}) end
  local savedUI = UIParent
  UIParent = Fake(0, 1920, 1080, 0, many)
  check(Cr.SideOffset(Fake(20, 1025, 900, 100, { wide })) == Cr.SIDE_GAP, "0.28.1: UIParent mit 400 Kindern")
  UIParent = savedUI
  fire("TRADE_SKILL_CLOSE")
  check(not Cr.box.shown, "Beruf zu: Box weg")
  C_TradeSkillUI, ProfessionsFrame = nil, nil
  market.items[3001], market.items[3100], market.items[3200] = nil, nil, nil
  PeonBrokerCharDB.recipes = nil
end)()

-- ===== ab 0.39: Berufsfenster - Block unter den Reagenzien, Gewinn in der Rezeptliste, Einstellungen =====
;(function()
  local Cr = ns.Craft
  local db = mod.db
  check(db.craftList == true and db.craftListWhich == "all" and db.craftBlock == true and db.craftSummary == true
      and db.craftColSrc == true and db.craftColCost == true and db.craftColSell == true and db.craftHint == true,
      "0.39: Vorgaben fuer das Berufsfenster")
  market.items[3001] = { m = 10, md = 12, q = 100, n = 5, t = clock, nm = "Stoff", ql = 1 }
  market.items[3002] = { m = 30, md = 30, q = 10, n = 2, t = clock, nm = "Faden", ql = 1 }
  market.items[3100] = { m = 500, md = 520, q = 10, n = 4, t = clock, nm = "Hemd", ql = 2 }
  market.items[3200] = { m = 20, md = 20, q = 10, n = 4, t = clock, nm = "Lappen", ql = 1 }
  local SCH = {
    [11] = { outputItemID = 3100, quantityMin = 1, quantityMax = 1, name = "Hemd",
             reagentSlotSchematics = { { reagents = { { itemID = 3002 } }, quantityRequired = 1, reagentType = 1, required = true },
                                       { reagents = { { itemID = 3001 } }, quantityRequired = 4, reagentType = 1, required = true } } },
    [12] = { outputItemID = 3200, quantityMin = 2, quantityMax = 2, name = "Lappen",
             reagentSlotSchematics = { { reagents = { { itemID = 3001 } }, quantityRequired = 5, reagentType = 1, required = true } } },
  }
  C_TradeSkillUI = { GetAllRecipeIDs = function() return { 11, 12 } end,
    GetRecipeInfo = function(id) return { recipeID = id, learned = true } end,
    GetRecipeSchematic = function(id) return SCH[id] end }
  -- Vorrat: Taschen 2, Bank 1 (Stoff); andere Charaktere 10; eigene Kosten und Haendlerkaeufe aus Ledger
  local savedCount = C_Item.GetItemCount
  local MINE = { [3001] = { 2, 1 } }
  C_Item.GetItemCount = function(id, bank)
    local s = MINE[id] or { 0, 0 }
    return bank and (s[1] + s[2]) or s[1]
  end
  local COST, OTH, VB = { [3001] = 5 }, { [3001] = 10 }, {}
  local ledger = { StockOthers = function(_, id) return OTH[id] or 0 end, Cost = function(_, id) return COST[id] end,
    VendorBuy = function(_, id) return VB[id] end,
    Stock = function(_, id) return 15, { total = 15, warband = 3,
      chars = { { name = "Mirel", places = { bags = 2 } }, { name = "Borin Stein", places = { bank = 7, auctions = 4 } } } } end }
  local savedGM = Peon.GetModule
  Peon.GetModule = function(self, k) if k == "ledger" then return ledger end return savedGM(self, k) end
  db.keepAllChars = true
  mod.acc.merchant = nil
  local savedIV = ns.ItemValue
  local IV = savedIV
  -- Fenster: Rezeptformular mit Reagenzien und Rezeptliste
  local function Vis(f) f.IsVisible = function(s) return s.shown end return f end
  local form = Vis(CreateFrame("Frame"))
  form.Reagents = Vis(CreateFrame("Frame"))
  local selected = 11
  form.GetRecipeInfo = function() return { recipeID = selected } end
  local function RowFor(id)
    local r = CreateFrame("Button")
    r.GetElementData = function() return { GetData = function() return id and { recipeInfo = { recipeID = id } } or { categoryInfo = {} } end } end
    return r
  end
  local rows = { RowFor(nil), RowFor(11), RowFor(12) }
  local sb = { ForEachFrame = function(_, fn) for _, r in ipairs(rows) do fn(r) end end }
  ProfessionsFrame = Vis(CreateFrame("Frame", "ProfessionsFrame"))
  ProfessionsFrame.CraftingPage = { SchematicForm = form, RecipeList = { ScrollBox = sb } }
  fire("TRADE_SKILL_SHOW")
  timers[#timers]()
  Cr.Tick()
  -- Rechnung Hemd: Faden fehlt -> im AH kaufen (30c), 4 Stoff aus dem Vorrat zu Kosten laut Ledger (5c)
  local c = Cr.calc[3100]
  local erl4 = IV(3001, 4)
  check(c and c.cost == 50 and #c.lines == 2 and c.lines[1].src == "ah" and c.lines[1].cost == 30
      and c.lines[2].src == "stock" and c.lines[2].n == 4 and c.lines[2].cost == 20 and c.lines[2].erl == erl4,
      "Hemd: Faden im AH 30c, 4 Stoff aus dem Vorrat 20c, Reihenfolge wie im Rezept (" .. tostring(c and c.cost) .. ")")
  check(c.value == IV(3100, 1) and c.profit == c.value - 50 and c.craftNet == c.value - 30 and c.erl == erl4 and not c.sellBetter,
      "Hemd: Gewinn = Ertrag - Kosten, Herstellen bringt Ertrag - Kaufen, mehr als der Verkauf des Stoffs")
  check(c.mats[2].have == 13 and c.craftable == 0, "Vorrat mit Twinks 13")
  local c2 = Cr.calc[3200]
  local erl5 = IV(3001, 5)
  check(c2 and c2.cost == 25 and c2.value == IV(3200, 2) and erl5 > c2.value and c2.sellBetter and c2.profit > 0,
      "Lappen: Gewinn auf Kosten, aber 5 Stoff zu verkaufen bringt mehr als 2 Lappen")
  db.keepAllChars = false
  Cr.Tick()
  local c1 = Cr.calc[3100]
  check(c1.cost == 30 + 3 * 5 + 10 and #c1.lines == 3 and c1.lines[2].n == 3 and c1.lines[2].src == "stock"
      and c1.lines[3].n == 1 and c1.lines[3].src == "ah" and c1.lines[3].cost == 10,
      "ohne Twinks: 3 Stoff aus dem Vorrat, 1 Stoff kaufen, eigene Zeile (" .. tostring(c1.cost) .. ")")
  db.keepAllChars = true
  Cr.Tick()
  -- Rezeptliste
  check(not Cr.deco[rows[1]], "Kategorie-Zeile bleibt leer")
  local d11, d12 = Cr.deco[rows[2]], Cr.deco[rows[3]]
  check(d11 and d11.fs.shown and plain(d11.fs.text):find("^%+") and d11.fs.text:find("60e060", 1, true), "Liste: Gewinn gruen")
  check(d12 and d12.fs.shown and plain(d12.fs.text):find("^%+") and d12.fs.text:find("ff9933", 1, true), "Liste: orange, wenn Verkaufen mehr bringt")
  check(Cr.best == 3100 and d11.bar.shown and not d12.bar.shown, "goldener Strich am besten Rezept, bei dem Herstellen lohnt")
  Cr.Set("craftListMode", "pct")
  local p = math.floor(Cr.calc[3100].profit / 50 * 100 + 0.5)
  check(plain(d11.fs.text) == "+" .. p .. " %", "Liste in Prozent vom Material (" .. plain(d11.fs.text) .. ")")
  Cr.Set("craftListMode", "money")
  Cr.Set("craftListWhich", "top1")
  check(Cr.ListText(Cr.calc[3100]) ~= nil and Cr.ListText(Cr.calc[3200]) == nil, "nur die besten N")
  Cr.Set("craftListWhich", "all")
  Cr.Set("craftListBest", false)
  check(not d11.bar.shown, "Strich abschaltbar")
  Cr.Set("craftListBest", true)
  check(Cr.ListText({ cost = 10, profit = -5, missing = 0 }) and plain(Cr.ListText({ cost = 10, profit = -5, missing = 0 })) == "-5c", "Verlust rot")
  db.craftListLoss = false
  check(Cr.ListText({ cost = 10, profit = -5, missing = 0 }) == nil, "Verluste abschaltbar")
  db.craftListLoss = true
  check(plain(Cr.ListText({ cost = 10, missing = 1 })) == "?", "ohne Preis: ?")
  db.craftListUnknown = false
  check(Cr.ListText({ cost = 10, missing = 1 }) == nil, "ohne Preis abschaltbar")
  db.craftListUnknown = true
  db.craftListWhich = "profit"
  check(Cr.ListText({ cost = 10, profit = -5, missing = 0 }) == nil and Cr.ListText({ cost = 10, missing = 1 }) == nil, "nur mit Gewinn")
  db.craftListWhich = "all"
  Cr.Set("craftList", false)
  check(not d11.fs.shown and not d11.bar.shown, "Liste ganz abschaltbar")
  Cr.Set("craftList", true)
  -- Block unter den Reagenzien: Ergebniszeile, Tabelle, Hinweis
  local b = Cr.block
  check(b and b.shown and b.points[1][2] == form.Reagents and not (Cr.box and Cr.box.shown), "Block unter den Reagenzien statt der Box daneben")
  check(plain(b.boxes[1].label.text) == "Kosten" and plain(b.boxes[1].value.text) == "50c" and plain(b.boxes[2].label.text) == "Ertrag"
      and plain(b.boxes[3].label.text) == "Gewinn" and plain(b.boxes[3].value.text):find("^%+"), "Ergebniszeile Kosten, Ertrag, Gewinn")
  check(b.boxes[1].points[1][5] > b.head.points[1][5], "Ergebniszeile ueber der Tabelle")
  check(plain(b.head.name.text) == "Material" and plain(b.head.src.text) == "Quelle" and plain(b.head.cost.text) == "Kosten"
      and plain(b.head.sell.text) == "Erlös", "Spalten Material, Quelle, Kosten, Erloes")
  check(plain(b.rows[1].name.text) == "Gegenstand3002" and plain(b.rows[1].src.text) == "AH" and plain(b.rows[1].cost.text) == "30c"
      and plain(b.rows[1].sell.text) == "-", "Zeile Faden: im AH kaufen, kein Erloes")
  check(plain(b.rows[2].name.text) == "4× Gegenstand3001" and plain(b.rows[2].src.text) == "Vorrat" and plain(b.rows[2].cost.text) == "20c"
      and plain(b.rows[2].sell.text) == plain(ns.Tooltip.Money(erl4)), "Zeile Stoff: Vorrat, Kosten laut Ledger, Erloes im AH")
  check(plain(b.total.name.text) == "Gesamt" and plain(b.total.cost.text) == "50c" and plain(b.total.sell.text) == plain(ns.Tooltip.Money(erl4)), "Zeile Gesamt")
  check(plain(b.hint.text) == "Herstellen bringt mehr: " .. plain(ns.Tooltip.Money(c.craftNet)) .. " statt " .. plain(ns.Tooltip.Money(erl4)) .. " beim Verkauf des Materials",
      "Hinweis: Herstellen lohnt, beide Betraege (" .. plain(b.hint.text) .. ")")
  check(b.ck.shown and b.ck.checked == true, "Haken Twinks mitzaehlen (mit Ledger)")
  local lines = Cr.StockLines(b.rows[2].line.mat)
  check(plain(lines[1]) == "Dieser Charakter: Taschen 2, Bank 1" and plain(lines[2]) == "Borin: Bank 7" and plain(lines[3]) == "Accountbank: 3" and #lines == 3,
      "Vorrat: wo liegt was (" .. plain(table.concat(lines, " | ")) .. ")")
  b.ck.checked = false
  b.ck.scripts.OnClick(b.ck)
  check(db.keepAllChars == false and plain(b.rows[2].name.text) == "3× Gegenstand3001" and plain(b.rows[3].src.text) == "AH", "Haken aus: nur dieser Charakter")
  lines = Cr.StockLines(b.rows[2].line.mat)
  check(#lines == 2 and plain(lines[2]) == "Twinks und Accountbank: 10 (nicht mitgezählt)", "Vorrat ohne Twinks: Summe grau")
  Cr.Set("keepAllChars", true)
  check(not b.rows[3].shown, "ueberzaehlige Zeile versteckt")
  -- Tooltips
  local tl = Cr.LineTipLines(b.rows[2].line)
  check(plain(tl[1]) == "#4× Gegenstand3001" and plain(tl[2][2]) == "Vorrat" and plain(tl[6][1]) == "Deine Kosten je Stück (Ledger)" and plain(tl[6][2]) == "5c"
      and plain(tl[7][2]) == "10c" and plain(tl[8][1]) == "Erlös für 4 nach Gebühr", "Tooltip Vorrat: wo, Kosten, AH, Erloes (" .. tostring(#tl) .. ")")
  tl = Cr.LineTipLines(b.rows[1].line)
  check(plain(tl[3][2]) == "30c" and plain(tl[4][2]) == "unbekannt" and plain(tl[5][2]) == "0", "Tooltip Kaufen: AH, Haendler, Vorrat")
  b.rows[2].hoverSrc.scripts.OnEnter(b.rows[2].hoverSrc)
  check(plain(tt.lines[1]) == "4× Gegenstand3001" and b.rows[2].hoverCost.shown and b.rows[2].hoverSell.shown, "Maus ueber Quelle, Kosten, Erloes")
  tl = Cr.BoxLines(b.calc, 1)
  check(plain(tl[1]) == "#So ergeben sich die Kosten" and plain(tl[2][2]) == "20c" and plain(tl[3][2]) == "30c", "Tooltip Kosten: Vorrat und Kaufen")
  tl = Cr.BoxLines(b.calc, 2)
  check(plain(tl[1]) == "#Ertrag des Ergebnisses" and plain(tl[2][2]) == "1", "Tooltip Ertrag")
  tl = Cr.BoxLines(b.calc, 3)
  check(plain(tl[2][1]) == "Ertrag" and plain(tl[3][1]) == "minus Kosten" and plain(tl[3][2]) == "50c" and plain(tl[6][1]) == "Herstellen bringt (Ertrag minus Kaufen)"
      and plain(tl[7][2]) == plain(ns.Tooltip.Money(erl4)) and plain(tl[8][1]) == "Alles gekauft", "Tooltip Gewinn: Rechnung und Vergleich")
  b.boxes[3].scripts.OnEnter(b.boxes[3])
  check(plain(tt.lines[1]) == "Gewinn je Herstellen" and #tt.lines == 8, "Maus ueber dem Gewinn-Kasten")
  -- Einstellungen
  Cr.Set("craftColCost", false)
  check(not b.rows[2].cost.shown and b.rows[2].sell.shown and not b.head.cost.shown and not b.rows[2].hoverCost.shown, "Spalte Kosten abschaltbar")
  Cr.Set("craftColCost", true)
  Cr.Set("craftSummary", false)
  check(not b.boxes[1].shown and b.head.points[1][5] == -28, "Ergebniszeile abschaltbar, Tabelle rueckt hoch")
  Cr.Set("craftSummary", true)
  Cr.Set("craftHint", false)
  check(not b.hint.shown, "Hinweis abschaltbar")
  Cr.Set("craftHint", true)
  -- Faden im Vorrat ohne Kosten im Ledger: AH-Preis zaehlt, mit ~
  MINE[3002] = { 1, 0 }
  fire("BAG_UPDATE_DELAYED")
  Cr.Tick()
  check(plain(b.rows[1].src.text) == "Vorrat" and plain(b.rows[1].cost.text) == "~30c" and Cr.LineTipLines(b.rows[1].line)[8] ~= nil,
      "ohne Kosten im Ledger: AH-Preis mit ~")
  check(plain(b.hint.text):match("^Dein Vorrat reicht für 1×\n"), "nichts zu kaufen: Vorrat reicht (" .. plain(b.hint.text) .. ")")
  MINE[3002] = nil
  -- Lappen: Verkaufen bringt mehr, Hinweis mit beiden Betraegen
  selected = 12
  Cr.OnSelect(12)
  c2 = b.calc
  check(plain(b.rows[1].name.text) == "5× Gegenstand3001" and not b.rows[2].shown and plain(b.boxes[2].label.text) == "Ertrag (2 Stück)", "anderes Rezept gewaehlt")
  check(plain(b.hint.text) == "Dein Vorrat reicht für 2×\nMaterial verkaufen bringt mehr: " .. plain(ns.Tooltip.Money(erl5)) .. " statt " .. plain(ns.Tooltip.Money(c2.value)) .. " beim Herstellen",
      "Hinweis: lieber verkaufen, beide Betraege (" .. plain(b.hint.text) .. ")")
  check(b.hint.text:find("ff9933", 1, true), "Hinweis orange")
  Cr.Set("craftBlock", false)
  check(not b.shown and not (Cr.box and Cr.box.shown), "Block abschaltbar, dann auch keine Box")
  Cr.Set("craftBlock", true)
  check(b.shown, "Block wieder da")
  selected = 11
  Cr.OnSelect(11)
  -- Haendlerpreise: 1. beim Besuch gesehen, 2. letzter Kauf laut Ledger, 3. geschaetzt
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
  Cr.Tick()
  c = Cr.calc[3100]
  check(c.lines[1].src == "vendor" and c.lines[1].cost == 10 and c.cost == 30 and plain(b.rows[1].src.text) == "Händler" and plain(b.rows[1].cost.text) == "10c",
      "Faden beim Haendler guenstiger: Quelle Haendler")
  tl = Cr.LineTipLines(b.rows[1].line)
  check(plain(tl[4][2]) == "10c" and plain(tl[6]):find("^Händlerpreis gesehen bei "), "Tooltip: wo der Haendlerpreis herkommt")
  vend.items[3002].p = 40
  Cr.dirty = true
  Cr.Tick()
  check(Cr.calc[3100].lines[1].src == "ah" and Cr.calc[3100].lines[1].cost == 30, "AH guenstiger: Quelle AH")
  mod.acc.vendors = nil
  mod.acc.merchant = { [3002] = { p = 12, t = clock, w = "Alt" } }
  Cr.dirty = true
  Cr.Tick()
  check(Cr.calc[3100].lines[1].src == "vendor" and Cr.calc[3100].lines[1].cost == 12, "N5: frueherer Speicher wird noch gelesen")
  mod.acc.merchant = nil
  VB[3002] = 20
  Cr.dirty = true
  Cr.Tick()
  check(Cr.calc[3100].lines[1].src == "vendor" and Cr.calc[3100].lines[1].cost == 20 and Cr.calc[3100].mats[1].vsrc == "ledger", "Haendlerpreis aus Ledger")
  VB[3002] = nil
  local savedVP = ns.VendorPrice
  ns.VendorPrice = function(id) if id == 3002 then return 2 end return savedVP(id) end
  check(ns.Merchant.Price(3002) == nil, "nicht in der Liste: keine Schaetzung")
  ns.Merchant.LIST[3002] = true
  Cr.dirty = true
  Cr.Tick()
  check(Cr.calc[3100].lines[1].src == "vendor" and Cr.calc[3100].lines[1].cost == 8 and Cr.calc[3100].lines[1].est and plain(b.rows[1].cost.text) == "~8c",
      "geschaetzt: 4x Ankaufspreis, mit ~")
  ns.Merchant.LIST[3002] = nil
  ns.VendorPrice = savedVP
  GetMerchantNumItems, GetMerchantItemID, GetMerchantItemInfo = nil, nil, nil
  mod.acc.merchant = nil
  -- Zahnrad-Menue (neue Menue-API)
  local made = {}
  MenuUtil = { CreateContextMenu = function(owner, gen)
    local root = {}
    function root:CreateTitle(t) made[#made + 1] = "T:" .. t end
    function root:CreateDivider() end
    function root:CreateCheckbox(t, get, set) made[#made + 1] = { t = t, get = get, set = set } end
    function root:CreateButton(t, fn) made[#made + 1] = "B:" .. t; return { CreateRadio = function(_, rt, rget, rset) made[#made + 1] = { t = rt, get = rget, set = rset, radio = true } end } end
    gen(owner, root)
  end }
  Cr.ShowMenu(b.gear)
  local loss, pct, sell
  for _, it in ipairs(made) do
    if type(it) == "table" and it.t == "Verluste zeigen" then loss = it end
    if type(it) == "table" and it.t == "Prozent vom Material" then pct = it end
    if type(it) == "table" and it.t == "Spalte Erlös (Vorrat im AH verkauft)" then sell = it end
  end
  check(made[1] == "T:Rezeptliste" and loss and loss.get() == true and pct and pct.radio and sell, "Menue: Rezeptliste und Tabelle mit Haken und Auswahl")
  loss.set()
  check(db.craftListLoss == false and loss.get() == false, "Menue: Haken schaltet um")
  loss.set()
  pct.set()
  check(db.craftListMode == "pct", "Menue: Auswahl setzt den Wert")
  db.craftListMode = "money"
  MenuUtil = nil
  -- Einstellungen geaendert (z. B. auf der Optionsseite): naechster Takt zeichnet neu
  Cr.Tick()
  db.craftColSell = false
  Cr.Tick()
  check(not b.rows[1].sell.shown, "Aenderung ohne Menue wird beim naechsten Takt erkannt")
  db.craftColSell = true
  -- ohne Reagenzien-Bereich: Rueckfall auf die Box
  form.Reagents = nil
  Cr.dirty = true
  Cr.Tick()
  check(not b.shown and Cr.box and Cr.box.shown, "ohne Reagenzien-Bereich: Box daneben wie bisher")
  form.Reagents = Vis(CreateFrame("Frame"))
  Cr.dirty = true
  Cr.Tick()
  -- 0.39: Rezeptliste kommt spaeter oder anderer Beruf: unbekanntes Rezept in der Liste wird nachgelesen
  SCH[13] = { outputItemID = 3002, quantityMin = 1, quantityMax = 1, name = "Faden",
              reagentSlotSchematics = { { reagents = { { itemID = 3200 } }, quantityRequired = 1, reagentType = 1, required = true } } }
  C_TradeSkillUI.GetAllRecipeIDs = function() return { 11, 12, 13 } end
  rows[#rows + 1] = RowFor(13)
  Cr.Tick()
  check(Cr.needRead and not Cr.byRecipe[13], "0.39: unbekanntes Rezept bemerkt, liest nicht sofort wieder")
  now = now + 1
  Cr.Tick()
  Cr.Tick()
  check(Cr.byRecipe[13] == 3002 and Cr.deco[rows[4]] and Cr.deco[rows[4]].fs.shown and not Cr.needRead, "0.39: nachgelesen, Gewinn steht in der neuen Zeile")
  -- Ereignis mehrmals schnell hintereinander: das letzte wird nicht verschluckt
  now = now + 1
  C_TradeSkillUI.GetAllRecipeIDs = function() return { 11, 12 } end
  fire("TRADE_SKILL_LIST_UPDATE")
  Cr.Tick()
  check(Cr.byRecipe[13] == nil, "0.39: Listen-Ereignis wird beim naechsten Takt gelesen")
  C_TradeSkillUI.GetAllRecipeIDs = function() return { 11, 12, 13 } end
  fire("TRADE_SKILL_LIST_UPDATE")
  Cr.Tick()
  check(Cr.byRecipe[13] == nil and Cr.needRead, "0.39: zweites Ereignis kurz danach wartet")
  now = now + 1
  Cr.Tick()
  check(Cr.byRecipe[13] == 3002, "0.39: und wird danach gelesen")
  table.remove(rows)
  SCH[13] = nil
  C_TradeSkillUI.GetAllRecipeIDs = function() return { 11, 12 } end
  -- Pruefbefehl
  form.Reagents.GetObjectType = function() return "Frame" end
  SlashCmdList.PEON_BROKER("pruefen beruf")
  check(said("SchematicForm: sichtbar") and said("Anker: Reagents") and said("Rezeptliste: 3 Zeilen, 2 mit Rezept"), "/broker pruefen beruf")
  fire("TRADE_SKILL_CLOSE")
  Peon.GetModule = savedGM
  ns.ItemValue = savedIV
  C_Item.GetItemCount = savedCount
  db.keepAllChars = false
  C_TradeSkillUI, ProfessionsFrame = nil, nil
  market.items[3001], market.items[3002], market.items[3100], market.items[3200] = nil, nil, nil, nil
  PeonBrokerCharDB.recipes = nil
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
  check(T.built and T.tabs.buy and T.tabs.watch and T.tabs.radar and T.tabs.focus and T.tabs.prices == nil and T.tabs.more and T.page,
    "N1: fuenf Reiter und Flaeche angelegt")
  check(_G.PeonBrokerAHPlainButton == nil and T.BuildPlainButton == nil, "0.59.1: kein Knopf Blizzard pur mehr im Auktionshaus")
  check(T.page.points[1][5] == -22 and T.page.level == 370 and T.status.level == 376,
    "0.59.1: Flaeche ab der Titelleiste, unter dem runden Bild (Ebene 400)")
  local sbt = _G.PeonBrokerScanButton
  check(sbt.points[1][1] == "TOPRIGHT" and sbt.points[1][3] == "TOPRIGHT" and sbt.points[1][4] == -34 and sbt.status,
    "0.59.1: Scan-Knopf mit Text in der Titelleiste neben dem Schliessen-Knopf")
  check(T.status and T.back and not T.back.shown, "N1: Statuszeile und Knopf Zurueck im Auktionshaus, Zurueck anfangs verborgen")
  check(T.tabs.buy.points[1][2] == ah.AuctionsTab and T.tabs.watch.points[1][2] == T.tabs.buy and T.tabs.radar.points[1][2] == T.tabs.watch
    and T.tabs.focus.points[1][2] == T.tabs.radar and T.tabs.more.points[1][2] == T.tabs.focus and #ah.AuctionsTab.points == 0,
    "N1: Reihenfolge Markt, Verkaufen, Auktionen, Einkaufen, Radar, Fokus, Gegenstand, Mehr, Blizzards Auktionen bleibt an seinem Platz")
  check(ah.BuyTab.text == ns.L.AHTAB_MARKET, "0.54: Kaufen heisst Markt")
  check(T.tabs.radar.text == ns.L.AHTAB_RADAR and T.tabs.buy.text == ns.L.AHTAB_SHOP and T.tabs.focus.text == "Fokus"
    and T.tabs.watch.text == "Beobachten" and T.tabs.more.text == "Mehr", "0.82: Reiter heissen Einkaufen, Beobachten, Radar, Fokus, Mehr")
  check(#ah.Tabs == 3 and ah.numTabs == nil, "U0: Blizzards Reiterliste bleibt unberuehrt")
  check(T.tabs.radar.parent == T.tabHolder and T.tabHolder.parent == ah and #T.tabHolder.Tabs == 5, "0.41.2: Reiter haengen am eigenen Rahmen, nicht an Blizzards Liste")
  check(T.tabs.radar.points[1][4] == T.TAB_GAP and T.TAB_GAP == -15, "0.56: Grundabstand wie Blizzard (-15)")
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
    geo(T.tabs.radar, 340, 440, -3, 7)
    check(T.AlignTabs() and T.tabGap == -25, "0.56: Abstand bei Blizzard gemessen")
    local shopOff = T.tabs.buy.points[#T.tabs.buy.points][4]
    local radarOff = T.tabs.radar.points[#T.tabs.radar.points][4]
    check(shopOff == -8 and radarOff == -15 and #ah.AuctionsTab.points == 0,
      "N1: Brokers Reiter so gesetzt, dass die Grafiken denselben Abstand haben, Blizzards Reiter unberuehrt")
    for _, t in ipairs({ ah.BuyTab, ah.SellTab, T.tabs.buy, T.tabs.radar, ah.AuctionsTab }) do t.GetLeft, t.GetRight = nil, nil end
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
  T.tabs.radar.scripts.OnClick(T.tabs.radar)
  check(T.current == "radar" and T.page:IsShown() and T.host.radar == "ah" and Win.contents.radar.parent == T.page and Win.contents.radar.shown,
    "N1: Klick auf Radar zeigt die Seite Radar im Auktionshaus")
  check(not wf.shown and mod.db.windowTab == "radar", "N1: am Auktionator ist das Broker-Fenster zu, der Reiter wird gemerkt")
  check(calls.display == 0, "U0: Broker ruft SetDisplayMode nie selbst auf")
  check(star1.alpha == 0 and star2.alpha == 0, "0.64.1: Favoriten-Stern unsichtbar, solange Brokers Flaeche offen ist")
  check(calls.deselect - dsel >= 4 and calls.select >= 1, "U0: nur das Aussehen der Reiter wird umgestellt")
  local rt, st = T.tabs.radar, T.tabs.buy
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
  check(T.built and T.tabs.radar, "U7: Reiter da")
  -- Radar im Auktionshaus oeffnen: die Flaeche des Broker-Fensters wandert in den Reiter
  if Win.frame then Win.frame:Hide() end
  T.tabs.radar.scripts.OnClick(T.tabs.radar)
  local c = Win.contents.radar
  check(c and c.parent == T.page and c.points[1][2] == ah and T.host.radar == "ah" and c.shown, "U7: Radar-Flaeche haengt im Reiter des Auktionshauses")
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
  Win.Open("radar")
  check(T.current == "radar" and not (Win.frame and Win.frame.shown), "N1: Fenster oeffnen am Auktionator waehlt den Reiter im Auktionshaus")
  Win.Toggle()
  check(T.current == nil and not Win.frame.shown, "N1: nochmal schliesst den Reiter")
  Win.Toggle()
  check(T.current == "radar", "N1: und oeffnet den zuletzt gewaehlten wieder")
  -- Spruenge (Go.lua): Im Markt zeigen schliesst Brokers Flaeche und zeigt den Gegenstand in Blizzards Kaufansicht
  do
    local shown
    local oldShow = ns.Buy.ShowInAH
    ns.Buy.ShowInAH = function(row) shown = row; return true end
    check(ns.Go.Market({ key = 2770, offer = 120, qty = 10 }) and T.current == nil and shown and shown.key == 2770 and shown.offer == 120,
      "N1: Im Markt zeigen aus dem Radar: Flaeche zu, Gegenstand in Blizzards Kaufansicht")
    check(ns.Go.back == "radar" and T.back.shown and T.back.text == "Zurück zu Radar", "N1: Knopf Zurueck zu Radar")
    check(T.backAt == "title" and T.back.points[1][1] == "TOPLEFT" and T.back.points[1][4] == 62, "0.59.1: ohne Blizzards Zurueck links in der Titelleiste")
    local bb = CreateFrame("Button")
    bb.IsVisible = function() return true end
    ah.CommoditiesBuyFrame = { BackButton = bb }
    T.OnDisplayMode()   -- Blizzard hat die Kaufansicht geoeffnet
    check(T.backAt == "blizzard" and T.back.points[1][1] == "LEFT" and T.back.points[1][2] == bb and T.back.points[1][3] == "RIGHT",
      "0.59.1: in Blizzards Kaufansicht rechts neben Blizzards Zurueck")
    ah.CommoditiesBuyFrame = nil
    T.back.scripts.OnClick(T.back)
    check(T.current == "radar" and ns.Go.back == nil and not T.back.shown, "N1: Zurueck fuehrt zum Radar, Knopf weg")
    ns.Go.Item({ id = 2770, name = "Kupfererz" })
    check(T.current == "more" and ns.Item.key == 2770 and ns.Go.back == "radar" and T.back.shown, "N1: Sprung zum Gegenstand mit Zurueck")
    T.tabs.buy.scripts.OnClick(T.tabs.buy)
    check(ns.Go.back == nil and not T.back.shown, "N1: anderer Reiter beendet den Sprung")
    shown = nil
    check(ns.Go.Market({}) == false and shown == nil and said(ns.L.GO_NONE), "N1: ohne Gegenstand kein Sprung")
    ns.Buy.ShowInAH = oldShow
  end
  T.tabs.radar.scripts.OnClick(T.tabs.radar)
  check(c.shown and not Win.contents.buy.shown, "0.54: zurueck zum Radar, Einkaufen versteckt")
  check(ns.Buy.ShowInAH({ key = 2770 }) == false and display == 0, "U7: im Reiter schaltet Broker Blizzards Ansicht nicht um")
  -- Blizzard wechselt die Ansicht: Reiter zu, Radar haelt an
  local halted = 0
  local oldHalt = R.Halt
  R.Halt = function(...) halted = halted + 1; return oldHalt(...) end
  ah:SetDisplayMode("Buy")
  check(T.current == nil and not R.Shown() and halted >= 1, "U7: anderer Reiter -> Radar haelt an")
  -- Unterwegs holt das Broker-Fenster die Flaeche zurueck
  T.tabs.radar.scripts.OnClick(T.tabs.radar)
  ah.GetLeft, ah.GetTop = function() return 40.4 end, function() return 700.2 end
  ah.scripts.OnHide(ah)
  check(T.current == nil and mod.acc.ahPos and mod.acc.ahPos.x == 40 and mod.acc.ahPos.y == 700, "N1: Auktionshaus zu: Reiter zu, Stelle gemerkt")
  fire("AUCTION_HOUSE_CLOSED")
  local keepPos = mod.db.windowPos
  mod.db.windowPos = {}
  Win.Open("radar")
  check(T.host.radar == "window" and c.parent == Win.frame and c.points[1][2] == Win.frame and T.current == nil and R.Shown(), "U7: Broker-Fenster holt das Radar zurueck")
  check(Win.frame.points[1][1] == "TOPLEFT" and Win.frame.points[1][4] == 40 and Win.frame.points[1][5] == 700, "N1: Fenster oeffnet dort, wo das Auktionshaus stand")
  check(Win.status.text.text:find(ns.L.ST_NOT_LIVE, 1, true), "N1: unterwegs steht in der Statuszeile nicht live")
  mod.db.windowPos = keepPos
  ns.Go.Item({ id = 2770, name = "Kupfererz" })
  check((Win.current == "more" and Win.more.current == "prices") and Win.back.shown and Win.back.text == "Zurück zu Radar", "N1: Sprung im Fenster mit Zurueck")
  check(ns.Go.Market({ key = 2589 }) and Win.current == "browse" and #ns.Market.list.items == 1
    and ns.Market.list.items[1].key == 2589 and ns.Go.back == "prices" and Win.back.text == "Zurück zu Gegenstand", "N3: Im Markt zeigen fuehrt unterwegs zur Marktseite mit genau diesem Gegenstand")
  Win.back.scripts.OnClick(Win.back)
  check((Win.current == "more" and Win.more.current == "prices") and not Win.back.shown, "N1: Zurueck im Fenster (ein Schritt)")
  Win.Select("radar")
  -- offenes Fenster wandert beim Oeffnen des Auktionshauses in den Reiter
  fire("AUCTION_HOUSE_SHOW")
  check(not Win.frame.shown and T.current == "radar" and T.host.radar == "ah", "N1: Auktionshaus oeffnet: Fenster zu, Radar als Reiter")
  T.Close()
  R.Halt = oldHalt
  -- Zahl am Reiter nach einem Komplettscan, blinkt bis zum Oeffnen
  local oldCount, oldLoad = R.CountHits, R.LoadFromScan
  R.CountHits = function() return 3 end
  R.LoadFromScan = function() end
  mod:Fire("SCAN_DONE", "Markt")
  check(T.badges.radar and T.badges.radar.n == 3 and T.badges.radar.blink and T.tabs.radar.text == ns.L.AHTAB_RADAR
    and T.tabs.radar.badge.shown and T.tabs.radar.badge.text.text == "3", "U7/0.82: Radar mit roter 3 nach dem Scan")
  check(T.tabs.radar.scripts.OnUpdate ~= nil, "U7: Reiter blinkt")
  T.tabs.radar.scripts.OnClick(T.tabs.radar)
  check(T.badges.radar == nil and T.tabs.radar.text == ns.L.AHTAB_RADAR and not T.tabs.radar.badge.shown and T.tabs.radar.scripts.OnUpdate == nil, "U7: geoeffnet -> Zahl und Blinken weg")
  R.CountHits = function() return 0 end
  ah:SetDisplayMode("Buy")
  mod:Fire("SCAN_DONE", "Markt")
  check(T.badges.radar == nil, "U7: ohne Treffer keine Zahl")
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
  B.CountBuyable = oldCount
  check(type(B.CountBuyable()) == "number", "U8: Zaehlung ueber alle Listen und Beobachtung")
  ns.AHTabs.SetBadge, ns.AHTabs.built = oldT, wasBuilt
  -- Gegenstandsmenue und Tooltip-Zeichen
  check(ns.Tooltip.OnShopList(2770), "U8: beobachtete Gegenstaende bekommen das Zeichen in Zeile 1")
  local items = {}
  local root = { CreateButton = function(_, t, fn) local c = { text = t, fn = fn, CreateButton = function(self2, t2, f2) items[#items + 1] = t2; return {} end }; items[#items + 1] = t; return c end }
  Wt.AddMenu(root, { name = "Kupfererz" }, 2770)
  check(items[1] == ns.L.MENU_UNWATCH and items[2] == ns.L.MENU_WATCH_LIMIT, "U8: Menue Nicht mehr beobachten und Preisgrenze")
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
  check(cu and cu.pct == 100 and cu.better == "neutral", "U10: Vergleich nach Gebuehr, neutral besser")
  check(#G.CompareRows(500, false) == 0, "U10: Mindestabstand filtert")
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
  local lst = Rd.list
  check(lst.list and lst.o.icon and lst.o.sortDesc, "N6: Radar-Liste mit Peon.UI")
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
  check(f and f:IsShown() and #f.controls == 8, "0.70: Fenster Einstellungen des Fokus mit 7 Reglern (ab 0.91 dazu Haken Wiedereinstellen)")
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

-- ===== 0.71: Fenster Einstellungen im Radar, Arten abschaltbar =====
;(function()
  local S, R = ns.Settings, ns.Radar
  S.Toggle("radar")
  local f = S.frames.radar
  local vendor, spec
  for _, c in ipairs(f.controls) do
    if c.row[2] == "radarVendorOn" then vendor = c end
    if c.row[2] == "radarSpecOn" then spec = c end
  end
  check(f:IsShown() and vendor and spec and spec.frame.disabled, "0.71: Radar-Einstellungen mit Haendler, Aufkauf, Spekulation (grau)")
  vendor.frame:SetChecked(false)
  vendor.frame.scripts.OnClick(vendor.frame)
  check(S.Get("radar", "radarVendorOn") == false and mod.db.radarVendorOn ~= false, "0.74: Haken aendert erst den Entwurf")
  f.ok.scripts.OnClick(f.ok)
  check(mod.db.radarVendorOn == false, "0.74: OK uebernimmt")
  mod.db.radarVendorOn = false
  check(R.KIND_ON.vendor == false and R.KIND_ON.buyout == true, "0.71: Art Haendler abgeschaltet")
  mod.db.radarVendorOn = true
  S.Hide("radar")
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
  check(F.origin == "radar" and F.backButton.text == "Zurück zu Radar" and F.ManualTarget(7995) == nil, "0.82: aus dem Radar: zurueck zum Radar, ohne Werte der Beobachtung")
  F.FromPage(7995, "focus")
  check(F.origin == "radar", "0.82: naechste Chance aus dem Fokus heraus: Herkunft bleibt")
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
  T.current = "radar"
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

-- Keine unerwarteten Fehlermeldungen
local n = 0 for _, l in ipairs(out) do if l:find("Fehler") and not l:find("hat einen Fehler gemeldet", 1, true) then n = n + 1 end end  -- erwartete Meldung aus dem Verkaufen-Test
check(n == 0, "keine Fehlermeldungen")
-- 0.81: einmaliger Hinweis zum Neuaufbau (Kern-API 20)
-- Eine zweite Meldung mit derselben id lehnt der Kern ab: dann hat Broker sie schon gemeldet
check(Peon.API >= 20 and Peon.AddNotice({ id = "broker:umbau-2026-11", title = "x" }) == false, "0.81: Broker hat den Hinweis broker:umbau-2026-11 gemeldet")
check(type(ns.L.NOTICE_REBUILD_TEXT) == "table" and #ns.L.NOTICE_REBUILD_TEXT == 4 and ns.L.NOTICE_REBUILD_TITLE ~= "NOTICE_REBUILD_TITLE", "0.81: Titel und vier Absaetze")
print("ALLE TESTS OK")
