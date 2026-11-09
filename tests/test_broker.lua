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

-- ===== Tooltip (Kapitel 3) =====
lines = hover(KUPFER)
check(lines[1] == "Broker (Umschalt) = AH: 1s 14c" and #lines == 1, "Z1 ohne Umschalt: AH-Erloes fuer 1 Stueck")
lines = hover(KUPFER, "Stapel20")
check(lines[1] == "Broker (Umschalt) = AH: 22s 80c", "Z1: Erloes fuer den Stapel (Beispiel Rechenmodell)")
shift = true
lines = hover(KUPFER, "Stapel20")
check(lines[1] == "Broker = AH: 22s 80c", "Z1 mit Umschalt")
check(lines[2] == "Angebote: 120 (4) = (Scan vor 1 Min.)", "Z2: Angebote (Anzahl)")
check(lines[3] == "AH = Min 1s 20c   Median 1s 60c", "Z3: AH je Stueck")
check(lines[4] == "Vorschlag = 1s 20c je Stück", "Z5: Vorschlag je Stueck (Z4 erst ab 2 Tagen)")
check(lines[5] == "Einstellgebühr (8 Std.) = 20c", "Z6: Einstellgebuehr fuer den Stapel")
check(lines[6] == "Händler = 5c je Stück" and #lines == 6, "Z7: Haendler je Stueck (ab 0.19), keine Hinweise")
lines = hover(LEINEN)
check(lines[1] == "Broker = Händler: 10c" and lines[4] == "Vorschlag = 3c je Stück", "Haendler besser")
check(lines[6] == "Händler = 10c je Stück" and lines[7] == "Wenig Angebote." and #lines == 7, "Haendler je Stueck auch wenn Zeile 1 den Haendler zeigt (ab 0.19); Hinweis wenig Angebote")
lines = hover("|cff1eff00|Hitem:15000::::::1047::20:::::::::|h[x]|h|r")
check(lines[1] == "Broker = AH: 47s 49c" and lines[4] == "Vorschlag = 49s 99c je Stück", "Einzelgegenstand: 1 Kupfer unterboten")
-- Schwerer Leinenverband: Markt auf Haendlerniveau
VENDOR[7777] = 20
market.items[7777] = { m = 20, md = 20, q = 2420, n = 148, t = clock, d = D.Day(clock) .. ":20:20:2420:1" }
lines = hover("|cffffffff|Hitem:7777::::::::20:1488:::::::::|h[Verband]|h|r", "Stapel20")
check(lines[1] == "Broker = Händler: 4s", "Leinenverband: 20 x 20c x 0,95 = 3s 80c < 4s -> Haendler")
market.items[7777] = nil
mod.db.tooltipAvg, mod.db.tooltipVendor = false, false
check(#hover(KUPFER) == 5, "Zeilen 7 Tage und Haendler abschaltbar")
mod.db.tooltipShow = false
check(#hover(KUPFER) == 0, "Tooltip ganz aus")
mod.db.tooltipShow, mod.db.tooltipAvg, mod.db.tooltipVendor = true, true, true
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
    mod.db.tooltipNeutral = "off"
    check(neutralLine(hover(KUPFER)) == nil, "U1: Einstellung aus")
    shift = false
    mod.db.tooltipNeutral = "always"
    check(neutralLine(hover(KUPFER)) ~= nil, "U1: Einstellung immer, auch ohne Umschalt")
    nm.items[2770].gone = clock
    check(neutralLine(hover(KUPFER)) == nil, "U1: neutral zurzeit keine Angebote: keine Zeile")
    mod.db.tooltipNeutral = "shift"
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
check(lines[1] == "Broker = AH: 1s 24c [trend_up1]", "Trend Erloes gegenueber vorherigem Scan (+8 %)")
check(lines[2] == "Angebote: 120 (4) [trend_flat] = (Scan vor 1 Min.)", "Trend Angebote")
check(lines[3] == "AH = Min 1s 30c [trend_up1]   Median 1s 60c [trend_flat]", "Trend AH-Werte")

-- ===== Zweiter Tag: 7-Tage-Werte, verschwundener Gegenstand =====
clock = clock + 86400
local leinen = table.remove(LISTINGS, 5)         -- Leinenstoff ausverkauft (nur noch ein Gebot)
S.Start()
fire("REPLICATE_ITEM_LIST_UPDATE")
while S.state do S.Step() end
lines = hover(KUPFER)
check(lines[4] == "7 Tage (2) = Min 1s 28c [trend_flat]   Median 1s 60c [trend_flat]", "Z4: 7 Tage (2), Trend gegenueber Vortag")
local le = market.items[2589]
check(le.q == 0 and le.gone == clock and le.m == 3, "verschwundener Gegenstand: 0 Angebote, letzte Preise bleiben")
lines = hover(LEINEN)
check(lines[1] == "Broker = Händler: 10c" and lines[2]:find("Angebote: 0 (0) [trend_down2]", 1, true), "Tooltip: keine Angebote")
check(lines[3]:find("AH (zuletzt) = Min 3c", 1, true) and lines[#lines]:find("Zurzeit keine Angebote", 1, true), "zuletzt gesehen + Hinweis")
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
local Win, P = ns.Window, ns.Prices
-- Einkaufsliste in Arbeit (0.37.0): Fuer die Pruefungen der Liste den Hinweis abschalten, am Ende pruefen
check(Win.WIP.buy == true, "0.37: Einkaufsliste in Arbeit")
local wipKeep = Win.WIP
Win.WIP = {}
check(market.items[2770].nm == "Kupfererz" and market.items[2770].ql == 1, "Scan merkt Name und Qualitaet")
check(market.items["15000:1047"].nm == "Schwert des Baeren" and market.items["15000:1047"].ql == 2, "Name bei Ausruestung mit Zusatz")
check(D.LinkFromKey(2770) == "item:2770" and D.KeyFromLink(D.LinkFromKey("15000:1047")) == "15000:1047", "Link aus Schluessel und zurueck")
check(Win.Lower("ÄÖÜ Erz") == "äöü erz", "Suche: Umlaute klein")
fire("AUCTION_HOUSE_SHOW")
check(_G.PeonBrokerWindowButton == nil, "0.41.1: kein Knopf Broker mehr am Auktionshaus")
check(not (_G.PeonBrokerFrame and _G.PeonBrokerFrame.shown), "Fenster oeffnet nicht von selbst (Standard)")
Win.Open()
local wf = _G.PeonBrokerFrame
check(wf.shown and Win.docked and wf.points[1][2] == AuctionHouseFrame and wf.points[1][3] == "TOPRIGHT", "Knopf oeffnet Fenster, rechts am Auktionshaus angedockt")
check(UISpecialFrames[#UISpecialFrames] == "PeonBrokerFrame", "Escape schliesst das Fenster")
local nTabs, open = 0, {}
for _, b in ipairs(Win.tabButtons) do nTabs = nTabs + 1; if not b.disabled then open[#open + 1] = b.text end end
check(nTabs == 7 and #open == 7 and open[1] == "Start" and open[5] == "Einkaufsliste" and open[6] == "Radar" and open[7] == "Preise", "sieben Reiter, Start vorne (ab 0.24)")
check(Win.current == "start" and Win.tabButtons[1].locked, "am Auktionshaus: Reiter Start gewaehlt (ab 0.24)")
-- Startseite: eine Zeile je Bereich, Klick springt zum Reiter
local St = ns.Start
local sLines = St.list:GetItems()
local byArea = {} for _, l in ipairs(sLines) do byArea[l.area] = l end
check(#sLines == 5 and byArea["Verkaufen"] and byArea["Meine Auktionen"] and not byArea["Post"] and byArea["Radar"] and byArea["Einkaufsliste"] and byArea["Scan"],
    "Startseite: Meine Auktionen, Verkaufen, Radar, Einkaufsliste, Scan (ab 0.25.1 ohne Post)")
check(plain(byArea["Scan"].text):find("Letzter Scan", 1, true), "Scan-Stand")
St.Click(byArea["Verkaufen"])
check(Win.current == "sell", "Klick auf Verkaufen: Reiter Verkaufen")
Win.Select("start")
Win.tabButtons[7].scripts.OnClick(Win.tabButtons[7])
check(Win.current == "prices" and Win.tabButtons[7].locked and not Win.tabButtons[1].locked, "Reiter Preise gewaehlt und markiert")
local items = P.list:GetItems()
check(#items == 4 and items[1].name == "Kupfererz" and items[4].name == "Schwert des Baeren", "Liste: alle Gegenstaende nach Name")
check(P.count.text == "4 von 4 Gegenständen", "Zaehler")
check(Win.footer.text:find("Classic Beta PvE / Horde", 1, true) and Win.footer.text:find("Letzter Scan", 1, true), "Fusszeile: Markt und Scan")
P.search:SetText("ERZ"); P.search.scripts.OnTextChanged(P.search)
check(#P.list:GetItems() == 1 and P.count.text == "1 von 4 Gegenständen", "Suche: Teil des Namens, Gross/klein egal")
P.search:SetText("xyz"); P.search.scripts.OnTextChanged(P.search)
check(#P.list:GetItems() == 0 and P.list.empty.text == "Nichts gefunden.", "Suche ohne Treffer")
P.search:SetText("schwert"); P.search.scripts.OnTextChanged(P.search)
check(#P.list:GetItems() == 2, "Suche: zwei Schwerter")
local row1 = P.list.rowFrames[1]
check(row1.cells[1].text:find("|cff1eff00Schwert des Affen|r", 1, true), "Name in Qualitaetsfarbe")
row1.scripts.OnEnter(row1)
check(tt.hyper == "item:15000::::::1048", "Maus ueber Zeile zeigt Gegenstand im Tooltip")
P.search:SetText(""); P.search.scripts.OnTextChanged(P.search)
P.list.rowFrames[1].scripts.OnClick(P.list.rowFrames[1], "LeftButton")
local dt = plain(P.detail.text)
check(dt:find("Kupfererz", 1, true) and dt:find("Vorschlag: ", 1, true) and dt:find("je Stück", 1, true) and dt:find("Massenware", 1, true), "Einzelheiten: Name, Vorschlag, Warenart")
check(dt:find("Händler: 5c je Stück", 1, true), "Einzelheiten: Haendlerpreis je Stueck")
local hist = P.history:GetItems()
local hasWeek = false for _, h in ipairs(hist) do if h.week then hasWeek = true end end
check(#hist >= 2 and hasWeek and hist[1].sort >= hist[#hist].sort, "Verlauf: Tage und Wochen, neueste oben")
check(P.history.rowFrames[1].cells[1].text:match("^%d%d%.%d%d%.$"), "Verlauf: Datum TT.MM.")
Win.Refresh()
check(P.selectedKey == 2770 and P.list:GetSelected() and P.list:GetSelected().key == 2770, "Auswahl bleibt beim Aktualisieren")
-- Gegenstand ohne gemerkten Namen (Daten von 0.6): Name vom Spiel
market.items[2589].nm = nil; P.cache = nil
Win.Refresh()
local lein for _, it in ipairs(P.list:GetItems()) do if it.key == 2589 then lein = it end end
check(lein and lein.name == "Gegenstand2589", "ohne gemerkten Namen: Name vom Spiel")
-- Auktionshaus zu: angedocktes Fenster schliesst mit
fire("AUCTION_HOUSE_CLOSED")
check(not wf.shown, "angedocktes Fenster schliesst mit dem Auktionshaus")
-- ohne Auktionshaus: frei, Position wird gemerkt
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
check(wf.shown and Win.docked, "offenes Fenster dockt beim Auktionshaus an")
fire("AUCTION_HOUSE_CLOSED")
mod.db.windowWithAH = true
fire("AUCTION_HOUSE_SHOW")
check(wf.shown and Win.docked, "Einstellung: Fenster oeffnet mit dem Auktionshaus")
mod.db.windowWithAH = false
fire("AUCTION_HOUSE_CLOSED")
check(not wf.shown, "und schliesst mit ihm")
-- ohne Scan im Markt: Hinweis
PeonBrokerDB.markets["Classic Beta PvE / Horde"], P.cache = nil, nil
SlashCmdList.PEON_BROKER("")
check(Win.current == "start", "ohne Auktionshaus: zuletzt gewaehlter Reiter")
Win.Select("prices")
check(#P.list:GetItems() == 0 and P.list.empty.text:find("Noch kein Scan", 1, true) and P.count.text == "0 von 0 Gegenständen", "ohne Scan: Hinweis in der Liste")
SlashCmdList.PEON_BROKER("")
PeonBrokerDB.markets["Classic Beta PvE / Horde"], P.cache = market, nil
fire("AUCTION_HOUSE_SHOW")

-- ===== Reiter "Verkaufen" (0.8, ab 0.10 ueber das Verkaufsfenster des Auktionshauses) =====
local Sell = ns.Sell
check(D.MinPrice(5) == 6 and D.MinPrice(20) == 22 and D.MinPrice(0) == nil, "F19: Mindestpreis (5c -> 6c, 20c -> 22c)")
local lvMin, lvMed, lvQty, lvOwn = D.LiveValues({ { price = 110, qty = 5, own = 5 }, { price = 115, qty = 8, own = 0 }, { price = 150, qty = 7, own = 2 } })
check(lvMin == 115 and lvOwn == 110 and lvQty == 20 and lvMed == 115, "F21/F22: Min ohne eigene, Median ueber alle")
local sg = D.SuggestSell({ { price = 110, qty = 5, own = 5 }, { price = 115, qty = 8, own = 0 } }, nil, 2770, 5, mod.db)
check(sg.vp == 110 and sg.source == "own", "F23: eigenes Angebot am guenstigsten -> eigener Preis")
sg = D.SuggestSell({ { price = 120, qty = 4, own = 4 }, { price = 115, qty = 8, own = 0 } }, nil, 2770, 5, mod.db)
check(sg.vp == 115 and sg.source == "live", "F23: anderer guenstiger -> nach Rechenmodell")
sg = D.SuggestSell({}, market.items[2770], 2770, 5, mod.db)
check(sg.source == "scan" and sg.vp == market.items[2770].m, "F24: ohne Live-Daten aus dem Scan (AHmin, Massenware nicht unterboten)")
sg = D.SuggestSell(nil, nil, 9999, 7, mod.db)
check(sg.source == "vendor" and sg.vp == 8, "F24: nur Haendlerpreis: 7c / 0,95 -> 8c")
check(D.SuggestSell(nil, nil, 9999, nil, mod.db).vp == nil, "F24: ohne jeden Vergleich kein Vorschlag")
check(D.SellDuration(2770, 25, mod.db) == 2 and D.SellDuration(2770, 5, mod.db) == 8, "F25: Massenware ab 20 Angeboten 2 Std., sonst 8")
check(D.SellDuration("15000:1047", 99, mod.db) == 8, "F25: Einzelgegenstand bleibt bei 8 Std.")
check(D.SellDuration(2770, 25, mod.db, { dur = 24 }) == 24, "F25: von Hand gewaehlte Laufzeit gewinnt")
mod.db.shortMass = false
check(D.SellDuration(2770, 25, mod.db) == 8, "F25: Einstellung aus -> 8 Std.")
mod.db.shortMass = true
check(D.IsLowPrice(50, 115, mod.db) and not D.IsLowPrice(90, 115, mod.db), "F27: Preis stark unter dem Vorschlag")

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
Win.Toggle()
check(wf.shown and Win.current == "start", "am Auktionshaus oeffnet Start (ab 0.24)")
local sellLine for _, l in ipairs(ns.Start.list:GetItems()) do if l.tab == "sell" then sellLine = l end end
check(sellLine and plain(sellLine.text):find("2 Gegenstände", 1, true), "Start: 2 lohnende Gegenstaende in den Taschen (" .. plain(sellLine and sellLine.text or "") .. ")")
Win.Select("sell")
local sl = Sell.list:GetItems()
check(#sl == 2 and sl[1].name == "Kupfererz" and sl[1].count == 60 and #sl[1].locs == 2, "Taschen: Stapel zusammengefasst, nach Erloes sortiert")
check(sl[2].key == "15000:1047", "Ausruestung mit Zusatz in der Liste")
local names = {} for _, it in ipairs(sl) do names[it.name] = true end
check(not names["Leinenstoff"] and not names["Seelengebunden"], "nur lohnende, gebundenes nie")
check(Sell.list.rowFrames[1].cells[3].text:find("|cff60e060", 1, true), "Wert gruen (AH lohnt)")
check(Sell.list.rowFrames[1].cells[4].text:find("trend_", 1, true), "Spalte Trend (wie Zeile 1 im Tooltip)")
check(Sell.list.rowFrames[1].cells[1].text:find("|T", 1, true), "kleines Symbol vor dem Namen")
Sell.onlyCheck:SetChecked(false); Sell.onlyCheck.scripts.OnClick(Sell.onlyCheck)
check(#Sell.list:GetItems() == 3 and mod.db.sellOnlyProfitable == false, "Haken aus: auch Haendler-Gegenstaende")
Sell.onlyCheck:SetChecked(true); Sell.onlyCheck.scripts.OnClick(Sell.onlyCheck)
check(Sell.pick.shown and not Sell.panel.shown, "ohne Auswahl: Hinweis statt Verkaufsfeld")

-- Kupfererz waehlen: ins Auktionshaus legen, Live-Abfrage, Werte eintragen
Sell.list.rowFrames[1].scripts.OnClick(Sell.list.rowFrames[1], "LeftButton")
check(CSF.shown and CSF.loc and CSF.loc.slot == 1 and Sell.inAH == 2770, "Gegenstand liegt im Verkaufsfenster des Auktionshauses")
check(query and query.normal and query.key.itemID == 2770 and query.key.itemLevel == 20 and query.separate == true and query.sorts[1].sortOrder == 0, "Live-Abfrage ueber die normale Suche mit dem Schluessel des Gegenstands")
check(Sell.liveState == "wait" and Sell.liveText.text:find("wird geladen", 1, true), "wartet auf Live-Daten")
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
check(#Sell.live == 4 and Sell.live[1].price == 115 and Sell.liveText.text:find("vor 0 Sek.", 1, true), "Live-Angebote gelesen (nur im Hintergrund)")
check(CSF.price == 115 and CSF.qty == 60 and CSF.dur == 2, "eingetragen: 1s 15c je Stueck, alle 60, 8 Std.")
CSF.price = 999                       -- das Auktionshaus setzt nach seiner Suche selbst einen Preis
timers[#timers - 1](); timers[#timers]()
check(CSF.price == 115, "Brokers Preis wird danach nochmal eingetragen")
check(plain(Sell.priceValue.text) == "1s 15c" and plain(Sell.why.text):find("günstigstes Angebot", 1, true), "links: Vorschlag mit Stichwort")
Sell.whyFrame.scripts.OnEnter(Sell.whyFrame)
check(tt.lines[2] and tt.lines[2]:find("nicht unterboten", 1, true), "ausfuehrlicher Grund beim Ueberfahren")
check(plain(Sell.proceedsValue.text) == "65s 55c" and Sell.proceedsFor.text:find("für 60 Stück, 8 Std.", 1, true), "Erloes fuer Menge und Dauer aus dem Auktionshaus")
check(Sell.proceedsValue.text:find("|cff60e060", 1, true), "Erloes gruen (ueber Haendlerwert)")
check(not plain(Sell.hints.text):find("nicht ins Auktionshaus eintragen", 1, true), "kein Hinweis zum Eintragen, wenn es geklappt hat")
check(not Sell.post.disabled and not Sell.postNext.disabled and Sell.keepButton.text == "Nicht verkaufen", "Knoepfe: nicht verkaufen, einstellen")
CSF.qty = 99; Sell.UpdatePanel()
check(Sell.post.disabled and plain(Sell.hints.text):find("Nur 60 verfügbar", 1, true), "zu grosse Menge im Auktionshaus: gesperrt mit Hinweis")

-- im Auktionshaus geaendert, dann ueber Broker einstellen: es zaehlt, was dort steht
CSF.price, CSF.qty, CSF.dur = 118, 30, 1
Sell.UpdatePanel()
check(plain(Sell.proceedsValue.text) == "33s 63c" and Sell.proceedsFor.text:find("für 30 Stück, 2 Std.", 1, true), "Erloes folgt den Werten im Auktionshaus")
Sell.post.scripts.OnClick(Sell.post)
check(CSF.clicked == 1 and #posted == 1 and posted[1][1] == "C" and posted[1][3] == 1 and posted[1][4] == 30 and posted[1][5] == 118, "eingestellt ueber den Knopf des Auktionshauses mit dessen Werten")
check(Sell.busy and Sell.busy.blizzard and Sell.post.disabled, "wartet auf Rueckmeldung, Knopf gesperrt")
Sell.post.scripts.OnClick(Sell.post)
check(#posted == 1, "kein zweites Einstellen waehrend des Wartens")
fire("AUCTION_HOUSE_AUCTION_CREATED", 123)
local lastPlain = false for i = #out, math.max(1, #out - 12), -1 do if plain(out[i]):find("Eingestellt: 30× Kupfererz zu 1s 18c je Stück (2 Std.)", 1, true) then lastPlain = true end end
check(lastPlain, "Meldung im Chat")
check(PeonBrokerDB.posted == nil and PeonBrokerDB.sellMem[2770].last == 118 and PeonBrokerDB.sellMem[2770].dur == 2, "fuers Buch vermerkt; Preis und geaenderte Dauer gemerkt")
check(Sell.item and Sell.item.key == 2770 and CSF.dur == 1, "Rest bleibt gewaehlt; gemerkte Dauer (2 Std.) eingetragen")
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
local h = plain(Sell.hints.text)
check(h:find("Zuletzt eingestellt zu 1s 18c", 1, true), "Hinweis: zuletzt eingestellt")
PeonBrokerDB.sellMem[2770] = nil

-- Auktionshaus sperrt ("zu schnell"): Broker-Knoepfe folgen Blizzards Knopf
CSF.enabled = false
Sell.UpdatePanel()
check(Sell.post.disabled and Sell.postNext.disabled and Sell.blockedText.text:find("zu schnell", 1, true), "Auktionshaus sperrt: Knoepfe gesperrt mit Hinweis")
local nBefore = #posted
Sell.Post(false)
check(#posted == nBefore and not Sell.busy and said("kurz warten"), "Einstellen waehrend der Sperre: nichts passiert, kein Warten")
CSF.enabled = true
Sell.panel.scripts.OnUpdate(Sell.panel, 0.5)
check(not Sell.post.disabled and Sell.blockedText.text == "", "Sperre vorbei: Knoepfe wieder frei, ohne selbst etwas einzustellen")
-- gerade eingestellte (gesperrte) Taschenplaetze zaehlen nicht; Rest erst nach dem Taschen-Update wieder ins Auktionshaus
BAG[2].isLocked = true
local lockedCount for _, it in ipairs(Sell.ScanBags()) do if it.key == 2770 then lockedCount = it.count end end
check(lockedCount == 20, "gesperrter Stapel wird nicht mitgezaehlt")
BAG[2].isLocked = nil
local puts = 0
local savedPut = AuctionHouseFrame.SetPostItem
AuctionHouseFrame.SetPostItem = function(self, loc) puts = puts + 1; savedPut(self, loc) end
CSF.price, CSF.qty, CSF.dur = 115, 20, 2
Sell.post.scripts.OnClick(Sell.post)
fire("AUCTION_HOUSE_AUCTION_CREATED", 125)
check(puts == 0 and Sell.reselectKey == 2770, "nach dem Einstellen: Rest noch nicht ins Auktionshaus gelegt")
fire("BAG_UPDATE_DELAYED")
check(puts == 1 and Sell.reselectKey == nil and CSF.loc and CSF.loc.slot == 1, "nach dem Taschen-Update: Rest wieder im Auktionshaus")
AuctionHouseFrame.SetPostItem = savedPut
-- Gegenstand verschwindet aus den Taschen: aus dem Verkaufsfenster nehmen
local savedB1, savedB2 = BAG[1], BAG[2]
BAG[1], BAG[2] = { itemID = 1, stackCount = 1, hyperlink = "x", isBound = true }, { itemID = 1, stackCount = 1, hyperlink = "x", isBound = true }
fire("BAG_UPDATE_DELAYED")
check(Sell.item == nil and CSF.loc == nil and Sell.inAH == nil, "Gegenstand weg: Verkaufsfenster geleert")
BAG[1], BAG[2] = savedB1, savedB2
fire("BAG_UPDATE_DELAYED")
PeonBrokerDB.sellMem[2770] = nil
local kuAgain for _, it in ipairs(Sell.list:GetItems()) do if it.key == 2770 then kuAgain = it end end
Sell.Select(kuAgain)

-- Nicht verkaufen (je Charakter): Rechtsklick, Knopf, Alt+Klick zum Zuruecknehmen
local swRow
for i, it in ipairs(Sell.list:GetItems()) do if it.key == "15000:1047" then swRow = Sell.list.rowFrames[i] end end
swRow.scripts.OnClick(swRow, "RightButton")
check(type(PeonBrokerCharDB.keep["15000:1047"]) == "table" and PeonBrokerCharDB.keep["15000:1047"].n == nil and PeonBrokerCharDB.keep["15000:1047"].name == "Schwert des Baeren" and #Sell.list:GetItems() == 1 and said("nicht mehr zum Verkauf"), "Rechtsklick: nicht verkaufen, aus der Liste")
check(Sell.item and Sell.item.key == 2770 and Sell.list:GetSelected() == Sell.item, "Auswahl bleibt beim Rechtsklick auf eine andere Zeile")
check(PeonBrokerDB.keep == nil, "nicht in den accountweiten Daten")
Sell.keepButton.scripts.OnClick(Sell.keepButton)
check(type(PeonBrokerCharDB.keep[2770]) == "table" and #Sell.list:GetItems() == 0 and Sell.item and Sell.item.keep, "Knopf: gewaehlten Gegenstand nicht verkaufen")
check(Sell.keepButton.text == "Wieder verkaufen" and Sell.post.disabled and plain(Sell.hints.text):find("nicht verkaufen", 1, true), "markierter Gegenstand: Knopf 'Wieder verkaufen', Einstellen gesperrt")
Sell.keepButton.scripts.OnClick(Sell.keepButton)
check(PeonBrokerCharDB.keep[2770] == nil and #Sell.list:GetItems() == 1 and said("wieder zum Verkauf"), "wieder verkaufen")
Sell.SelectLink("|cff1eff00|Hitem:15000::::::1047::20:::::::::|h[Schwert des Baeren]|h|r")
check(Sell.item and Sell.item.key == "15000:1047" and Sell.item.keep and ISF.shown, "Auswahl per Link auch fuer markierte Gegenstaende")
Sell.keepButton.scripts.OnClick(Sell.keepButton)
check(PeonBrokerCharDB.keep["15000:1047"] == nil and #Sell.list:GetItems() == 2, "und kann sie wieder freigeben")

-- Behalten mit Menge (0.11): Vorrat = Taschen + Bank, Tooltip, Reiter "Behalten"
local BANK = { [2770] = 5 }
C_Item.GetItemCount = function(id, bank)
  local n = 0
  for _, b in ipairs(BAG) do if b.itemID == id then n = n + b.stackCount end end
  if bank then n = n + (BANK[id] or 0) end
  return n
end
local K = ns.Keep
PeonBrokerCharDB.keep[5] = true
check(type(K.List()[5]) == "table" and K.List()[5].n == nil, "alte Markierung (0.10) wird zu 'alle behalten'")
K.Remove(5)
local b1, bk1, tot1 = K.Counts(2770)
check(b1 == 60 and bk1 == 5 and tot1 == 65, "Vorrat = Taschen 60 + Bank 5 (vom Spiel, auch bei geschlossener Bank)")
K.Set(2770, 50, { name = "Kupfererz", quality = 1 })
check(K.Sellable(2770, 2770, 60) == 15, "Behalten 50: 15 zu verkaufen (65 - 50)")
BANK[2770] = 0
check(K.Sellable(2770, 2770, 60) == 10, "ohne Bank: 10 zu verkaufen")
BANK[2770] = 5
K.Set(2770, 3)
check(K.Sellable(2770, 2770, 60) == 60, "hoechstens so viel wie in den Taschen")
K.Set(2770, 50)
Sell.Refresh()
local kuRow for _, it in ipairs(Sell.list:GetItems()) do if it.key == 2770 then kuRow = it end end
check(kuRow and kuRow.count == 15 and kuRow.bagCount == 60, "Verkaufen zeigt nur den Rest (15)")
Sell.Select(kuRow)
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
check(CSF.qty == 15 and Sell.have.text:find("60 in Taschen", 1, true), "im Auktionshaus 15 eingetragen, links 60 in Taschen")
check(plain(Sell.hints.text):find("Behalten: 50 (15 zu verkaufen)", 1, true), "Hinweis Behalten links")
CSF.qty = 20; Sell.UpdatePanel()
check(plain(Sell.hints.text):find("Du wolltest 50 behalten", 1, true) and not Sell.post.disabled, "mehr eingetragen: Hinweis, Einstellen bleibt moeglich")
local function ttLines(link)
  tt.lines = {}
  ns.Tooltip.AddLines(GameTooltip, link, 1)
  return tt.lines
end
local KLINK = "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r"
check(ttLines(KLINK)[2] == "Behalten: 50 (15 zu verkaufen)", "Tooltip: Behalten direkt unter Zeile 1 (auch ohne Umschalt)")
K.Set(2770, 70)
Sell.Refresh()
local vis = false for _, it in ipairs(Sell.list:GetItems()) do if it.key == 2770 then vis = true end end
check(not vis, "Behalten-Menge ueber dem Vorrat: nicht mehr in der Liste")
K.Set(2770, nil)
check(ttLines(KLINK)[2] == "Behalten: alle", "Tooltip: Behalten alle")
check(ttLines("|cff1eff00|Hitem:15000::::::1047::20:::::::::|h[Schwert des Baeren]|h|r")[2] ~= "Behalten: alle", "nicht markiert: keine Zeile")

-- Reiter "Behalten"
Win.Select("keep")
local kr = K.list:GetItems()
check(#kr == 1 and kr[1].key == 2770 and kr[1].total == 65 and kr[1].bags == 60 and kr[1].bank == 5, "Reiter Behalten: Vorrat, Taschen, Bank")
check(K.list.rowFrames[1].cells[2].text == "alle" and K.list.rowFrames[1].cells[3].text == "65" and K.list.rowFrames[1].cells[4].text == "60" and K.list.rowFrames[1].cells[5].text == "5", "Spalten Menge, Vorrat, Taschen, Bank")
check(K.list.rowFrames[1].cells[3].fontObject == "GameFontHighlight", "Vorrat hervorgehoben")
check(K.list.rowFrames[1].cells[8].text:match("^%d%d%.%d%d%.$"), "Seit (Datum)")
check(K.list.rowFrames[1].cells[6].text:find("–", 1, true) and (not K.allChars.shown or K.allChars.shown == false or not K.Ledger()), "ohne Ledger: Spalte Twinks leer, kein Umschalter")
check(K.count.text:find("1 Gegenstände (nur dieser Charakter)", 1, true) and not K.bar.shown, "Anzahl unten, ohne Auswahl keine Mengenleiste")
K.list.rowFrames[1].scripts.OnClick(K.list.rowFrames[1], "LeftButton")
check(K.bar.shown and K.amount.text == "", "Zeile gewaehlt: Menge leer = alle")
K.amount:SetText("30"); K.amount.scripts.OnEnterPressed(K.amount)
check(PeonBrokerCharDB.keep[2770].n == 30 and K.list.rowFrames[1].cells[2].text == "30", "Menge gesetzt")
K.allButton.scripts.OnClick(K.allButton)
check(PeonBrokerCharDB.keep[2770].n == nil and K.list.rowFrames[1].cells[2].text == "alle", "Alle: wieder alles behalten")
K.Set(8888, nil, { name = "Ruhestein", quality = 1 })
K.Refresh()
kr = K.list:GetItems()
check(#kr == 2 and kr[2].name == "Ruhestein" and kr[2].bags == 0 and kr[2].total == 0, "auch Gegenstaende, die gerade nicht da sind (Vorrat 0)")
K.list.rowFrames[2].scripts.OnClick(K.list.rowFrames[2], "RightButton")
check(PeonBrokerCharDB.keep[8888] == nil and #K.list:GetItems() == 1, "Rechtsklick: wieder verkaufen")
K.list.rowFrames[1].scripts.OnClick(K.list.rowFrames[1], "LeftButton")
K.unkeepButton.scripts.OnClick(K.unkeepButton)
check(PeonBrokerCharDB.keep[2770] == nil and #K.list:GetItems() == 0 and K.list.empty.shown and not K.bar.shown, "Knopf: wieder verkaufen, Liste leer")
Win.Select("sell")
for _, it in ipairs(Sell.ScanBags()) do if it.key == "15000:1047" then Sell.Select(it) end end

-- Ausruestung und "Erstellen & weiter"
fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 15000 })
check(ISF.price == 5199 and ISF.qty == 1 and ISF.dur == 2, "Einzelgegenstand: 1c unterboten, im Auktionshaus eingetragen")
check(Sell.live[1].price == 5200 and Sell.live[1].qty == 3, "Einzelgegenstand: Preis je Stueck, nicht durch Anzahl geteilt")
local ku for _, it in ipairs(Sell.list:GetItems()) do if it.key == 2770 then ku = it end end
Sell.Select(ku)
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
Sell.postNext.scripts.OnClick(Sell.postNext)
BAG[1], BAG[2] = { itemID = 1, stackCount = 1, hyperlink = "x", isBound = true }, { itemID = 1, stackCount = 1, hyperlink = "x", isBound = true }
fire("AUCTION_HOUSE_AUCTION_CREATED", 124)
check(Sell.item and Sell.item.key == "15000:1047" and query.key.itemID == 15000 and ISF.shown and ISF.loc.slot == 4, "weiter: naechster Gegenstand gewaehlt, ins Auktionshaus gelegt und abgefragt")
fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 15000 })
Sell.post.scripts.OnClick(Sell.post)
check(ISF.clicked == 1 and posted[#posted][1] == "I" and posted[#posted][5] == 5199 and posted[#posted][6] == nil and posted[#posted][4] == 1, "PostItem ueber das Auktionshaus: Sofortkauf, kein Gebot")
fire("AUCTION_HOUSE_SHOW_ERROR")
check(Sell.busy == nil and said("Fehler gemeldet"), "Meldung des Auktionshauses weitergegeben")
BAG[1] = { itemID = 2770, stackCount = 20, hyperlink = "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r", quality = 1 }
BAG[2] = { itemID = 2770, stackCount = 40, hyperlink = "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r", quality = 1 }
fire("BAG_UPDATE_DELAYED")
check(#Sell.list:GetItems() == 2, "Taschen aendern sich -> Liste neu")

-- Ohne Verkaufsfenster des Auktionshauses: Rueckfall auf Brokers eigene Werte
WithBlizzard(false)
LIVE[2770][1] = { unitPrice = 115, quantity = 60, containsOwnerItem = true, numOwnerItems = 60 }
LIVE[2770][2] = { unitPrice = 120, quantity = 40 }
Sell.Select(Sell.list:GetItems()[1])
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
check(Sell.inAH == nil and plain(Sell.hints.text):find("nicht ins Auktionshaus eintragen", 1, true), "Hinweis, wenn das Eintragen nicht geht")
check(Sell.sugg.source == "own" and Sell.GetPrice() == 115 and plain(Sell.why.text) == "dein Preis", "eigenes Angebot am guenstigsten: Preis bleibt")
mod.db.shortMassMin = 3
Sell.Select(Sell.list:GetItems()[1])
check(Sell.duration == 2 and Sell.durWhy == "short", "viele Angebote: 2 Std.")
mod.db.shortMassMin = 20
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
Sell.price = 50; Sell.UpdatePanel()
check(plain(Sell.hints.text):find("Unter dem Vorschlag 1s 15c (57 % weniger)", 1, true) and Sell.hints.text:find("|cffff4040Unter", 1, true), "Warnung bei zu niedrigem Preis (rot, mit Vorschlag)")
popupShown = nil
local nPosted = #posted
Sell.post.scripts.OnClick(Sell.post)
check(popupShown and popupShown.name == "PEON_BROKER_CONFIRM_POST" and #posted == nPosted, "Rueckfrage statt sofort einstellen")
StaticPopupDialogs.PEON_BROKER_CONFIRM_POST.OnAccept(nil, popupShown.data)
check(#posted == nPosted + 1 and posted[#posted][5] == 50 and posted[#posted][3] == 2 and posted[#posted][4] == 60, "nach Ja: selbst eingestellt (Brokers Werte)")
Sell.busy = nil
confirmNeeded = true
Sell.price = 115; Sell.UpdatePanel()
popupShown = nil
Sell.post.scripts.OnClick(Sell.post)
check(popupShown and popupShown.text:find("Das Spiel fragt", 1, true) and not Sell.busy, "Rueckfrage des Spiels weitergegeben")
StaticPopupDialogs.PEON_BROKER_CONFIRM_POST.OnAccept(nil, popupShown.data)
check(confirmed and confirmed[4] == 115 and Sell.busy, "nach Ja: bestaetigt, wartet")
confirmNeeded = false
timers[#timers]()
check(Sell.busy == nil and said("Keine Rückmeldung"), "keine Rueckmeldung nach Wartezeit")

-- Live-Ergebnis ohne Ereignis (Spiel hat die Ergebnisse schon): Nachsehen nach kurzer Zeit
local nT = #timers
Sell.Select(Sell.list:GetItems()[1])
check(Sell.liveState == "wait" and #timers >= nT + 6, "Abfrage mit Nachsehen und Zeitgrenze (nach 2 Eintrage-Zeitpunkten)")
timers[nT + 3]()
check(Sell.liveState == "done" and #Sell.live >= 1, "Ergebnis per Nachsehen uebernommen")
-- keine Ergebnisse, kein Ereignis: Zeitgrenze
local savedLive = LIVE[2770]; LIVE[2770] = nil
local savedNI = AHs.GetNumItemSearchResults; AHs.GetNumItemSearchResults = function() return 0 end
nT = #timers
Sell.Select(Sell.list:GetItems()[1])
for i = nT + 3, nT + 5 do timers[i]() end
check(Sell.liveState == "wait", "noch nichts da: wartet weiter")
timers[nT + 6]()
check(Sell.liveState == "timeout" and Sell.liveText.text:find("keine Antwort", 1, true) and plain(Sell.hints.text):find("Keine aktuellen Angebote", 1, true), "Zeitgrenze: keine Antwort, Vorschlag aus dem Scan")
check(Sell.sugg.source == "scan", "Rueckfall auf den Scan")
LIVE[2770] = savedLive; AHs.GetNumItemSearchResults = savedNI
-- Ereignis passt nicht zur vermuteten Warenart: trotzdem uebernehmen
BAG[1] = { itemID = 2770, stackCount = 20, hyperlink = "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r", quality = 1 }
PeonBrokerDB.commodity[2770] = false
Sell.Refresh()
local ku for _, it in ipairs(Sell.list:GetItems()) do if it.key == 2770 then ku = it end end
Sell.Select(ku)
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
check(Sell.liveState == "done" and Sell.live[1].price == 115, "Warenart falsch vermutet: Ereignis des Spiels gilt")
PeonBrokerDB.commodity[2770] = true

-- Ergebnisse unter einem anderen Schluessel (Meldung "neue Ergebnisse" des Spiels)
local savedNI2, savedII = AHs.GetNumItemSearchResults, AHs.GetItemSearchResultInfo
AHs.GetNumItemSearchResults = function(k) return (type(k) == "table" and k.itemLevel == 99) and 1 or 0 end
AHs.GetItemSearchResultInfo = function(k, i) return { buyoutAmount = 7000, quantity = 1 } end
local swd for _, it in ipairs(Sell.ScanBags()) do if it.key == "15000:1047" then swd = it end end
Sell.Select(swd)
fire("AUCTION_HOUSE_NEW_RESULTS_RECEIVED", { itemID = 15000, itemLevel = 99, itemSuffix = 0 })
check(Sell.liveState == "done" and Sell.live[1].price == 7000, "Ergebnisse unter anderem Schluessel gefunden")
AHs.GetNumItemSearchResults, AHs.GetItemSearchResultInfo = savedNI2, savedII

-- Auswahl per Link (ab 0.27.1 kein Alt+Klick mehr in Broker - gehoert Peon_Ledger)
Win.Select("prices")
alt = true
HandleModifiedItemClick("|cff1eff00|Hitem:15000::::::1047::20:::::::::|h[Schwert des Baeren]|h|r")
check(Win.current == "prices", "Alt+Klick in den Taschen aendert in Broker nichts mehr")
alt = false
Sell.SelectLink("|cff1eff00|Hitem:15000::::::1047::20:::::::::|h[Schwert des Baeren]|h|r")
check(Win.current == "sell" and Sell.item and Sell.item.key == "15000:1047", "Auswahl per Link waehlt den Gegenstand im Reiter Verkaufen")
Sell.SelectLink("|cffffffff|Hitem:2589::::::::20:1488:::::::::|h[Leinenstoff]|h|r")
check(Sell.item and Sell.item.key == 2589, "auch nicht lohnende Gegenstaende")
check(plain(Sell.hints.text):find("Lieber beim Händler verkaufen (zahlt 1s)", 1, true), "Hinweis mit Haendlerpreis statt eigener Zeile")
check(Sell.proceedsValue.text:find("|cffff9933", 1, true), "Erloes orange, wenn der Haendler mehr zahlt")
HandleModifiedItemClick("|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r")
check(Sell.item.key == 2589, "Klick mit Taste aendert die Auswahl nicht")

-- ===== Reiter "Meine Auktionen" (0.12) =====
local Auc = ns.Auctions
local SWLINK = "|cff1eff00|Hitem:15000::::::1047::20:::::::::|h[Schwert des Baeren]|h|r"
local OWNED = {
  { auctionID = 11, itemLink = "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r", itemKey = { itemID = 2770, itemLevel = 20 }, status = 0, quantity = 60, buyoutAmount = 118, timeLeftSeconds = 5 * 3600 },
  { auctionID = 12, itemLink = SWLINK, itemKey = { itemID = 15000, itemLevel = 20 }, status = 0, quantity = 1, buyoutAmount = 5199, timeLeftSeconds = 20 * 3600 },
  { auctionID = 13, itemLink = "|cffffffff|Hitem:2589::::::::20:1488:::::::::|h[Leinenstoff]|h|r", itemKey = { itemID = 2589 }, status = 1, quantity = 10, buyoutAmount = 3 },
}
local ownedQueried, cancelledIDs = 0, {}
AHs.QueryOwnedAuctions = function() ownedQueried = ownedQueried + 1 end
AHs.GetNumOwnedAuctions = function() return #OWNED end
AHs.GetOwnedAuctionInfo = function(i) return OWNED[i] end
AHs.GetCancelCost = function(id) return id == 11 and 60 or 400 end
AHs.CanCancelAuction = function() return true end
AHs.CancelAuction = function(id) cancelledIDs[#cancelledIDs + 1] = id end
market.items["15000:1047"].m = 5000
market.items[2770].m = 120   -- ab 0.15 schreiben Live-Abfragen (Verkaufen) den aktuellen Stand; hier ein Stand ohne Unterbieten
Win.Select("auctions")
check(Win.current == "auctions" and ownedQueried == 1, "Reiter oeffnen: eigene Auktionen abgefragt")
fire("OWNED_AUCTIONS_UPDATED")
local ar = Auc.list:GetItems()
check(#ar == 3 and ar[1].id == 12 and ar[2].id == 11 and ar[3].id == 13, "Reihenfolge: unterboten, guenstigster, verkauft")
check(ar[1].status == "under" and ar[1].other == 5000 and ar[1].source == "scan", "Schwert unterboten (Scan: 50s < 51s 99c)")
check(ar[2].status == "best" and ar[3].status == "sold", "Kupfererz guenstigster, Leinenstoff verkauft")
check(Auc.list.rowFrames[1].cells[5].text:find("unterboten", 1, true) and Auc.list.rowFrames[1].cells[5].text:find("|cffff9933", 1, true), "Status unterboten in Orange")
check(Auc.list.rowFrames[2].cells[6].text == "5 Std." and Auc.list.rowFrames[3].cells[6].text == "–", "Restzeit")
check(Auc.nextButton.text == "Nächste unterbotene (1)" and not Auc.nextButton.disabled, "Knopf naechste unterbotene mit Anzahl")
check(Auc.liveRun and Auc.status.text:find("Prüfe live", 1, true), "ab 0.24: Reiter geoeffnet -> nach dem Neuladen automatisch live pruefen")
check(PeonBrokerDB.owned and #PeonBrokerDB.owned.rows == 3, "Stand fuer die Anzeige ohne Auktionshaus gemerkt")
-- Live pruefen: nacheinander, eigene Angebote zaehlen nicht
LIVEITEM[1] = { buyoutAmount = 5199, quantity = 1 }
Auc.liveButton.scripts.OnClick(Auc.liveButton)   -- laeuft schon: kein zweiter Lauf
check(Auc.liveRun and query.key.itemID == 2770 and Auc.status.text:find("Prüfe live 1 von 2", 1, true), "Live pruefen: erster Gegenstand")
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
check(query.key.itemID == 15000 and Auc.live[2770].min == 120, "zweiter Gegenstand; Kupfererz: guenstigstes anderer 1s 20c (eigene 1s 15c zaehlen nicht)")
fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 15000 })
ar = Auc.list:GetItems()
local byId = {} for _, r in ipairs(ar) do byId[r.id] = r end
check(not Auc.liveRun and byId[12].status == "equal" and byId[11].status == "best" and Auc.status.text:find("Stand: live", 1, true), "nach Live: Schwert gleichauf, Kupfererz guenstigster")
-- Abbrechen mit Kosten
for i, r in ipairs(ar) do if r.id == 12 then Auc.list.rowFrames[i].scripts.OnClick(Auc.list.rowFrames[i], "LeftButton") end end
check(plain(Auc.selText.text):find("Abbrechen kostet 4s", 1, true) and not Auc.cancelButton.disabled, "Auswahl zeigt die Abbruchkosten")
Auc.cancelButton.scripts.OnClick(Auc.cancelButton)
check(#cancelledIDs == 1 and cancelledIDs[1] == 12 and Auc.busy, "abgebrochen, wartet auf das Spiel")
table.remove(OWNED, 2)
local q0 = ownedQueried
fire("AUCTION_CANCELED", 12)
check(ownedQueried == q0 + 1 and PeonBrokerDB.cancelled == nil, "fuers Buch vermerkt (Kosten), neu abgefragt")
local cPlain = false for i = #out, math.max(1, #out - 6), -1 do if plain(out[i]):find("Abgebrochen: 1× Schwert des Baeren (Kosten 4s)", 1, true) then cPlain = true end end
check(cPlain, "Meldung im Chat")
fire("OWNED_AUCTIONS_UPDATED")
check(#Auc.list:GetItems() == 2 and not Auc.repostButton.disabled, "Liste ohne die abgebrochene; Neu einstellen moeglich")
Auc.repostButton.scripts.OnClick(Auc.repostButton)
check(Win.current == "sell" and Sell.item and Sell.item.key == "15000:1047", "Neu einstellen: zu Verkaufen, Gegenstand gewaehlt")
-- Naechste unterbotene
OWNED[1].buyoutAmount = 200
Win.Select("auctions")
fire("OWNED_AUCTIONS_UPDATED")
check(Auc.list:GetItems()[1].id == 11 and Auc.list:GetItems()[1].status == "under", "Kupfererz jetzt unterboten (live 1s 20c < 2s)")
Auc.nextButton.scripts.OnClick(Auc.nextButton)
check(cancelledIDs[2] == 11, "Naechste unterbotene: abgebrochen")
fire("AUCTION_CANCELED", 11)
table.remove(OWNED, 1)
fire("OWNED_AUCTIONS_UPDATED")
check(Auc.nextButton.disabled, "keine unterbotenen mehr")
Auc.CancelNextUnder()
check(said("Keine unterbotenen Auktionen"), "Meldung, wenn keine unterboten sind")
-- ohne Auktionshaus: letzter Stand, nichts abbrechen
fire("AUCTION_HOUSE_CLOSED")
SlashCmdList.PEON_BROKER("")
Win.Select("auctions")
check(#Auc.list:GetItems() == 1 and Auc.cancelButton.disabled and Auc.liveButton.disabled and Auc.status.text:find("Auktionshaus öffnen", 1, true), "ohne Auktionshaus: letzter Stand, Abbrechen gesperrt")
SlashCmdList.PEON_BROKER("")
fire("AUCTION_HOUSE_SHOW")
Win.Select("sell")

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
check(Win.current == "buy" and Buy.mode == "lists" and Buy.listsView.shown and Buy.dealsView == nil, "Reiter Einkaufsliste")
Buy.newButton.scripts.OnClick(Buy.newButton)
check(#PeonBrokerDB.lists == 1 and PeonBrokerDB.lists[1].name == "Liste 1" and PeonBrokerDB.lists[1].pct == 10 and type(PeonBrokerDB.lists[1].id) == "string", "neue Liste (accountweit, 10 %, mit Nummer)")
Buy.nameBox:SetText("Erze"); Buy.nameBox.scripts.OnEditFocusLost(Buy.nameBox)
check(PeonBrokerDB.lists[1].name == "Erze" and Buy.listList:GetItems()[1].name == "Erze", "Liste umbenannt")
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
Sell.pending = nil   -- (Live-Abfrage aus dem Verkaufen-Test haengt im Testaufbau noch; ab 0.21.1 wartet die Anzeige darauf)
Buy.itemList.rowFrames[kuL].scripts.OnClick(Buy.itemList.rowFrames[kuL], "LeftButton")
check(query.normal and query.key.itemID == 2770 and browse and browse.itemKey.itemID == 2770, "Anklicken: Live-Abfrage und im Auktionshaus geoeffnet")
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
check(Buy.live[2770] and #Buy.live[2770].rows >= 2, "Live-Angebote gelesen")
Buy.selected.limit = 130      -- feste Grenze fuer den Test: nur die Stufe 1s 20c (40 Stueck, eigene 1s 15c zaehlen nicht)
local plan = Buy.Plan(Buy.selected)
check(plan.qty == 40 and plan.cost == 4800 and plan.commodity, "Kaufplan: 40 Stueck fuer 48s")
Buy.wishBox:SetText("100"); Buy.wishBox.scripts.OnEditFocusLost(Buy.wishBox)
check(PeonBrokerDB.lists[1].items[2770].wish == 100, "Wunschmenge gesetzt")
Buy.selected.limit = 130
plan = Buy.Plan(Buy.selected)
check(plan.qty == 35 and plan.cost == 4200, "Wunschmenge 100 minus Vorrat 65 = 35")
Buy.UpdateView()
check(plain(Buy.selText.text):find("35 kaufen für 42s", 1, true) and not Buy.buyButton.disabled, "Anzeige: was gekauft wuerde")
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
for i, r in ipairs(Buy.itemList:GetItems()) do if r.key == "15000:1047" then Buy.itemList.rowFrames[i].scripts.OnClick(Buy.itemList.rowFrames[i], "LeftButton") end end
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
P.search:SetText(""); P.search.scripts.OnTextChanged(P.search)
for i, it in ipairs(P.list:GetItems()) do if it.key == 2589 then P.list.rowFrames[i].scripts.OnClick(P.list.rowFrames[i], "LeftButton") end end
check(not P.addButton.disabled, "Preise: Knopf 'Zur Einkaufsliste' aktiv")
P.addButton.scripts.OnClick(P.addButton)
check(PeonBrokerDB.lists[1].items[2589] ~= nil, "aus dem Reiter Preise hinzugefuegt")

-- ===== Reiter "Radar" (0.14) =====
local Rd = ns.Radar
check(Rd.preOff == true, "0.33.1: Preis vorab ist aus (Spiel erlaubt ihn nur direkt aus einem Klick)")
local sounds = 0
mod.db.dealDepth = 100   -- einfache Testfaelle: ganze Stufe, danach nichts mehr im Angebot
local lastSound
PlaySound = function(id, ch) sounds = sounds + 1; lastSound = { id, ch } end
mod.acc.commodity = mod.acc.commodity or {}
mod.acc.commodity[7777], mod.acc.commodity[7778], mod.acc.commodity[7779] = true, true, false
market.items[7777] = { m = 3, md = 10, q = 20, n = 1, t = clock - 120, lv = "3:20", nm = "Billigzeug", ql = 1 }
market.items[7778] = { m = 500, md = 1000, q = 20, n = 1, t = clock - 120, lv = "500:20", nm = "Dumpware", ql = 2, d = D.Day(clock) .. ":10000:20000:400:12" }
market.items[7779] = { m = 40, md = 200, q = 1, n = 1, t = clock - 120, lv = "40:1", nm = "Altes Schwert", ql = 2 }
VENDOR[7777], VENDOR[7779] = 10, 100
local savedV2589 = VENDOR[2589]
VENDOR[2589] = nil   -- sonst waere Silberblatt aus den frueheren Tests auch ein Haendler-Schnaeppchen
LIVE[7777] = { { unitPrice = 3, quantity = 20 } }
LIVE[7778] = {}
local savedLI2 = LIVEITEM
LIVEITEM = { { buyoutAmount = 40, quantity = 1, auctionID = 91 } }
local savedLast = market.lastScan
market.lastScan = clock - 60
local nT = #timers
Win.Select("radar")
local rItems = Rd.list:GetItems()
check(Win.current == "radar" and #rItems == 3 and rItems[1].key == 7778 and rItems[1].kind == "market", "Radar: Treffer aus dem frischen Scan, hoechster Gewinn oben")
check(plain(Rd.list.rowFrames[1].cells[6].text) == "61s 50c" and Rd.list.rowFrames[1].cells[2].text == "AH" and Rd.list.rowFrames[1].cells[7].text:find("2 Min.", 1, true), "eine Spalte Gewinn (hoechster Gewinn mit meinem Gold), Art kurz, Gesehen (Alter der Daten)")
check(#Rd.list.columns == 7 and Rd.list.rowFrames[1].tint.shown == false and Rd.list.rowFrames[2].tint.shown and Rd.list.rowFrames[2].cells[2].text:find("ffd100", 1, true)
    and Rd.list.rowFrames[2].cells[6].text:find("ffd100", 1, true), "Haendler-Schnaeppchen: Zeile dezent gold, Art und Gewinn gold (ab 0.19)")
check(Rd.loop and not Rd.running and #timers == nT + 1, "beim Oeffnen: Schnellpruefung der Scan-Treffer, auch ohne Radar-Scan")
check(Rd.status.text:find("noch 3", 1, true), "Anzeige: Schnellpruefung, 3 uebrig")
now = now + 1; timers[#timers]()
check(query.key.itemID == 7778, "Schnellpruefung: zuerst der hoechste Gewinn")
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 7778)
check(Rd.entries[7778] and Rd.entries[7778].emptySeen and Rd.soon and Rd.soon.key == 7778, "keine Angebote: erst nochmal pruefen (ab 0.20.1)")
Rd.pending = nil; Rd.Send(7778)
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 7778)
local function liveRows() local n = 0 for _, r in ipairs(Rd.list:GetItems()) do if not r.gone then n = n + 1 end end return n end
check(Rd.entries[7778] == nil and liveRows() == 2 and #Rd.list:GetItems() == 3, "Angebot weg: Treffer entfernt (ab 0.20 noch kurz grau in der Liste)")
check(Rd.gone[7778] and Rd.gone[7778].goneWhy == "Keine Angebote mehr." and PeonBrokerDB.radarLog == nil, "weggefallen: Grund (Radar-Protokoll ab 0.28 nur mit Debug)")
check(market.items[7778].gone == clock and market.items[7778].q == 0 and market.items[7778].lv == nil and market.items[7778].m == 500
    and market.items[7778].d == D.Day(clock) .. ":10000:20000:400:12", "Datenbank: weg vermerkt, letzte Preise und Verlauf bleiben")
now = now + 1; timers[#timers]()
check(query.key.itemID == 7777, "dann der naechste")
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 7777)
check(Rd.entries[7777].live and Rd.entries[7777].checked == now and sounds == 0, "noch da: live bestaetigt, kein Ton (war schon angezeigt)")
check(market.items[7777].lt == clock and market.items[7777].t == clock - 120 and market.items[7777].lv == "3:20" and D.Seen(market.items[7777]) == clock, "Datenbank: Live-Stand mit Zeit, Scan-Zeit bleibt")
now = now + 1; timers[#timers]()
fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 7779 })
check(Rd.entries[7779].live and Rd.entries[7779].auctionID == 91 and Rd.entries[7779].price == 40, "Einzelgegenstand live: Auktion gemerkt")
local nT2 = #timers
now = now + 1; timers[#timers]()
check(not Rd.loop and #timers == nT2, "alles einmal geprueft: Schnellpruefung endet")
-- ab 0.18: Kaufzeile unter der Liste fuer den gewaehlten Treffer (1 Stueck / bis ein Stapel / alle)
local function selectKey(key)
    if Rd.selected and Rd.selected.key == key and not Rd.selected.gone then Rd.SelectRow(Rd.entries[key]); return end  -- ab 0.20: nochmal anklicken hebt die Auswahl auf
    for i, it in ipairs(Rd.list:GetItems()) do
        if it.key == key and not it.gone then Rd.list.rowFrames[i].scripts.OnClick(Rd.list.rowFrames[i], "LeftButton") end
    end
end
check(Rd.selected == nil and plain(Rd.selText.text):find("anklicken", 1, true) and not Rd.buyButton.shown and not Rd.buyAllButton.shown, "ohne Auswahl: Hinweis, keine Knoepfe")
check(Rd.vendorButton == nil and Rd.marketButton == nil, "keine Schnellkauf-Knoepfe mehr")
selectKey(7777)
check(plain(Rd.selText.text):find("Schnäppchen: 20 Stück", 1, true) and Rd.buyButton.shown and Rd.buyAllButton.shown and not Rd.buyStackButton.shown, "Massenware: Menge, 1 Stueck und Alle (Stapel = alle: nicht doppelt)")
check(Rd.buyButton.text == "1 Stück" and plain(Rd.modeInfo.one.text) == "3c\n+7c" and Rd.buyAllButton.text == "Alle (20)" and plain(Rd.modeInfo.all.text) == "60c\n+1s 40c", "Knoepfe mit Kosten und Gewinn darunter")
-- Alle: Massenware mit Preis vom Spiel, zweiter Klick bestaetigt
purchaseStarted, purchaseConfirmed = nil, nil
Rd.buyAllButton.scripts.OnClick(Rd.buyAllButton)
check(purchaseStarted and purchaseStarted[1] == 7777 and purchaseStarted[2] == 20, "Alle: 20× Billigzeug")
check(Rd.buyAllButton.disabled and Rd.buyButton.disabled, "warten auf den Preis vom Spiel")
fire("COMMODITY_PRICE_UPDATED", 3, 60)
check(Rd.buyAllButton.text == "Bestätigen" and plain(Rd.modeInfo.all.text) == "60c" and not Rd.buyAllButton.disabled and Rd.buyButton.disabled and not purchaseConfirmed, "Preis passt: zweiter Klick bestaetigt")
Rd.buyAllButton.scripts.OnClick(Rd.buyAllButton)
check(purchaseConfirmed and purchaseConfirmed[1] == 7777 and purchaseConfirmed[2] == 20, "bestaetigt")
fire("COMMODITY_PURCHASE_SUCCEEDED")
check(Rd.entries[7777] == nil and PeonBrokerDB.bought == nil and said("Gekauft: 20× Billigzeug"), "alles gekauft: entfernt, fuers Buch vermerkt")
-- Einzelgegenstand: nur 1 Stueck; Pruefung aelter als 10 Sek. -> erst pruefen, dann kaufen
selectKey(7779)
check(Rd.buyButton.shown and not Rd.buyAllButton.shown and not Rd.buyStackButton.shown and plain(Rd.modeInfo.one.text) == "40c\n+60c", "Einzelgegenstand: nur 1 Stueck")
now = now + 11
placed = {}
Rd.buyButton.scripts.OnClick(Rd.buyButton)
check(#placed == 0 and query.key.itemID == 7779, "vor dem Kauf: Auktion noch da?")
fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 7779 })
Rd.buyButton.scripts.OnClick(Rd.buyButton)
check(#placed == 1 and placed[1][1] == 91 and placed[1][2] == 40, "Auktion noch da: PlaceBid")
fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 91)
check(Rd.entries[7779] == nil and liveRows() == 0, "gekauft und entfernt")
-- Massenware je Stueck: 1 kaufen, Rest bleibt und wird neu geprueft
Rd.entries[7777] = Rd.Evaluate(7777, { { price = 3, qty = 20, own = 0 } }, true, true)
Rd.entries[7777].checked = now
Rd.Refresh(); selectKey(7777)
purchaseStarted, purchaseConfirmed = nil, nil
Rd.buyButton.scripts.OnClick(Rd.buyButton)
check(purchaseStarted and purchaseStarted[2] == 1, "1 Stueck")
fire("COMMODITY_PRICE_UPDATED", 3, 3)
Rd.buyButton.scripts.OnClick(Rd.buyButton)
fire("COMMODITY_PURCHASE_SUCCEEDED")
check(purchaseConfirmed and purchaseConfirmed[2] == 1 and Rd.entries[7777] and Rd.entries[7777].qty == 19 and not Rd.entries[7777].live, "Rest bleibt (19) und wird neu geprueft")
-- Massenware inzwischen teurer: abbrechen
Rd.Halt()
Rd.entries[7777] = Rd.Evaluate(7777, { { price = 3, qty = 20, own = 0 } }, true, true)
Rd.Refresh(); selectKey(7777)
purchaseCancelled = 0
Rd.buyButton.scripts.OnClick(Rd.buyButton)
fire("COMMODITY_PRICE_UPDATED", 15, 15)
check(purchaseCancelled == 1 and Rd.entries[7777] == nil and Rd.job == nil and said("das günstige Angebot ist weg"), "teurer als die Grenze: Kauf abgebrochen")
-- Stapel (bis ein Stapel) und Gewinn erst ab einer Mindestmenge (Beispiel Echtsilberbarren)
do
    local es = { m = 12033, md = 20000, q = 66, n = 5, t = clock, nm = "Echtsilberbarren", ql = 1, d = D.Day(clock) .. ":240000:240000:792:12" }
    market.items[6037] = es
    mod.acc.commodity[6037] = true
    local rows = { { price = 12033, qty = 9, own = 0 }, { price = 17433, qty = 2, own = 0 }, { price = 17500, qty = 17, own = 0 }, { price = 20000, qty = 2, own = 0 }, { price = 25044, qty = 36, own = 0 } }
    mod.db.dealDepth = 20
    local de = Rd.Evaluate(6037, rows, true, true)
    check(de and de.qty == 9 and Rd.MinProfitQty(de) == 9, "Echtsilber: 9 Stueck, Gewinn erst ab 9 (davor verkauft der Rest der Stufe billiger)")
    local g1 = D.ProfitOf(de, 1)
    check(g1 < 0, "1 Stueck: Verlust")
    Rd.entries[6037] = de
    Rd.Refresh(); selectKey(6037)
    check(plain(Rd.selText.text):find("Gewinn erst ab 9 Stück", 1, true) and plain(Rd.modeInfo.one.text):find("−", 1, true), "Hinweis und Verlust unter dem Knopf")
    -- Gold reicht nicht fuer alle: Knopf grau
    GetMoney = function() return 50000 end
    Rd.UpdateView()
    check(not Rd.buyButton.disabled and Rd.buyAllButton.disabled and plain(Rd.modeInfo.all.text):find("Nicht genug Gold", 1, true), "zu teuer: grau mit Hinweis")
    GetMoney = nil
    -- Stapel: Stapelgroesse kleiner als die Menge
    check(not Rd.buyStackButton.shown, "Gewinn erst ab 9 = alle: kein mittlerer Knopf")
    -- mittlerer Knopf (ab 0.19): Menge ab Gewinn, wenn weniger als alle
    de.qty = 12
    Rd.UpdateView()
    check(Rd.buyStackButton.shown and Rd.buyStackButton.text == "9 Stück", "mittlerer Knopf: ab Gewinn (9 Stueck)")
    purchaseStarted = nil
    Rd.buyStackButton.scripts.OnClick(Rd.buyStackButton)
    check(purchaseStarted and purchaseStarted[1] == 6037 and purchaseStarted[2] == 9, "ab Gewinn gekauft (gestartet)")
    Rd.OnError()
    check(Rd.job == nil and Rd.entries[6037] and not Rd.entries[6037].live, "Meldung des Spiels: Kauf beendet, Treffer wird neu geprueft")
    de.qty = 9
    -- Massenware ohne Mindestmenge: mittlerer Knopf = bis ein Stapel
    local d77 = Rd.Evaluate(7777, { { price = 3, qty = 20, own = 0 } }, true, true)
    d77.stackQty = 5
    check(Rd.ModeQty(d77, "stack") == 5, "Massenware: mittlerer Knopf bis ein Stapel")
    -- Rechtsklick: ausblenden, bleibt weg solange Schnaeppchen, wieder frei wenn einmal keins
    for i, it in ipairs(Rd.list:GetItems()) do if it.key == 6037 then Rd.list.rowFrames[i].scripts.OnClick(Rd.list.rowFrames[i], "RightButton") end end
    check(Rd.entries[6037] == nil and Rd.IsHidden(6037) and PeonBrokerDB.radarHidden[ns.MarketKey()][6037] and not said("Echtsilberbarren ausgeblendet"), "Rechtsklick: ausgeblendet (alle Charaktere, je Markt), ohne Chatmeldung (ab 0.19)")
    check(plain(Rd.hiddenButton.text) == "Ausgeblendet (1)", "Knopf zeigt Anzahl")
    LIVE[6037] = { { unitPrice = 12033, quantity = 9 }, { unitPrice = 17433, quantity = 2 }, { unitPrice = 17500, quantity = 17 }, { unitPrice = 20000, quantity = 2 }, { unitPrice = 25044, quantity = 36 } }
    sounds = 0
    Rd.pending = nil
    Rd.Send(6037); fire("COMMODITY_SEARCH_RESULTS_UPDATED", 6037)
    check(Rd.entries[6037] == nil and Rd.IsHidden(6037) and sounds == 0, "noch Schnaeppchen: bleibt ausgeblendet, kein Ton")
    LIVE[6037] = { { unitPrice = 19000, quantity = 30 } }
    Rd.Send(6037); fire("COMMODITY_SEARCH_RESULTS_UPDATED", 6037)
    check(not Rd.IsHidden(6037) and Rd.entries[6037] == nil, "kein Schnaeppchen mehr: wieder frei")
    LIVE[6037] = { { unitPrice = 12033, quantity = 9 }, { unitPrice = 17433, quantity = 2 }, { unitPrice = 20000, quantity = 60 } }
    Rd.Send(6037); fire("COMMODITY_SEARCH_RESULTS_UPDATED", 6037)
    check(Rd.entries[6037] ~= nil and sounds == 1, "danach wieder Schnaeppchen: erscheint wieder (mit Ton)")
    -- Liste der Ausgeblendeten: Klick zeigt wieder
    Rd.Hide(6037)
    Rd.ToggleHiddenPanel()
    check(Rd.hiddenPanel.shown and #Rd.hiddenPanel.list:GetItems() == 1, "Liste der Ausgeblendeten")
    Rd.hiddenPanel.list.rowFrames[1].scripts.OnClick(Rd.hiddenPanel.list.rowFrames[1], "LeftButton")
    check(not Rd.IsHidden(6037) and #Rd.hiddenPanel.list:GetItems() == 0, "Klick: wieder zeigen")
    Rd.ToggleHiddenPanel()
    -- nach vollem Scan: Ausgeblendete aus der Datenbank neu bewerten
    Rd.Hide(6037)
    es.lv, es.gone = "19000:30", nil
    Rd.CheckHidden()
    check(not Rd.IsHidden(6037), "voller Scan: kein Schnaeppchen mehr -> wieder frei")
    market.items[6037], LIVE[6037], Rd.entries[6037] = nil, nil, nil
    mod.db.dealDepth = 100
    Rd.selected = nil
end
-- Gold: was ich mir nicht leisten kann, wird nicht gezeigt (einstellbar)
Rd.entries[7777] = Rd.Evaluate(7777, { { price = 3, qty = 20, own = 0 } }, true, true)
GetMoney = function() return 2 end
Rd.Refresh()
check(liveRows() == 0, "nicht genug Gold: nicht angezeigt")
mod.db.radarShowExpensive = true
Rd.Refresh()
local allCant = liveRows() >= 1
for _, it in ipairs(Rd.list:GetItems()) do if not it.cant and not it.gone then allCant = false end end
check(allCant, "einstellbar: grau angezeigt")
mod.db.radarShowExpensive = false
GetMoney = nil
-- Anzeige: nur Haendler / nur AH
Rd.SetKind("market")
check(Rd.entries[7777] == nil, "nur AH: Haendler-Treffer weg")
Rd.SetKind("both")
Rd.entries, Rd.gone, Rd.lastVisible = {}, {}, nil
Rd.Halt()   -- Schleife aus den Kauf-Tests beenden (Nachpruefen nach Fehler)
-- Radar-Scan
Rd.scanButton.scripts.OnClick(Rd.scanButton)
check(Rd.running and Rd.loop and #Rd.round > 0 and Rd.scanButton.text == "Radar-Scan stoppen", "Radar-Scan gestartet")
local r1 = Rd.round[1]
check(PeonBrokerDB.lists[1].items[r1] ~= nil, "Runde beginnt mit den Einkaufslisten")
now = now + 1; timers[#timers]()
check(Rd.stats.sent == 1 and Rd.status.text:find("Radar läuft", 1, true), "Abfrage gesendet, Anzeige laeuft")
local pk = Rd.pending.key
local savedLivePk, savedLIpk = LIVE[pk], LIVEITEM
LIVE[pk], LIVEITEM = nil, {}  -- auch keine vorhandenen Ergebnisse
now = now + 1.1; timers[#timers]()
LIVEITEM = savedLIpk
check(Rd.stats.timeouts == 1 and Rd.stats.lastTimeouts[1] == tostring(pk) and Rd.stats.sent == 2, "keine Antwort nach 1 Sek., keine Ergebnisse: gezaehlt und weiter")
LIVE[pk] = savedLivePk
fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")
check(Rd.stats.gameSent == 1 and #Rd.stats.log == 2 and Rd.stats.log[2].sent and not Rd.stats.log[1].sent, "Protokoll: vom Spiel gesendet je Abfrage")
Rd.UpdateView()
check(PeonBrokerDB.radarStats == nil and Rd.stats.timeouts == 1 and not Rd.status.text:find("ohne Antwort", 1, true)
    and Rd.nowText.text:find("Prüfe:", 1, true), "Zaehler nur in PeonBrokerDB, Anzeige: welcher Gegenstand gerade geprueft wird")
fire("AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED")
check(Rd.stats.dropped == 1 and Rd.pending == nil, "vom Spiel verworfen: gezaehlt")
local readyFn = AHs.IsThrottledMessageSystemReady
AHs.IsThrottledMessageSystemReady = function() return false end
now = now + 1; timers[#timers]()
check(Rd.stats.waitReady >= 0.9 and Rd.stats.sent == 2, "Spiel nicht bereit: warten, Wartezeit zaehlen")
AHs.IsThrottledMessageSystemReady = readyFn
-- keine Antwort, aber das Spiel hat schon Ergebnisse (beobachtet 0.14.4): diese lesen
Rd.pending = nil
LIVE[7777] = { { unitPrice = 3, quantity = 20 } }
market.items[7777] = { m = 3, md = 10, q = 20, n = 1, t = clock, lv = "3:20", nm = "Billigzeug", ql = 1 }
VENDOR[7777] = 10
Rd.entries[7777] = nil
Rd.Send(7777)
now = now + 1.1; timers[#timers]()
check(Rd.stats.cached == 1 and Rd.entries[7777] and Rd.entries[7777].live and Rd.stats.timeouts == 1, "ohne Antwort: vorhandene Ergebnisse gelesen, Treffer erkannt")
Rd.entries[7777] = nil
Rd.pending = nil
sounds = 0
-- zweimal ohne Antwort: fuer diese Sitzung auslassen; Ereignisse im Protokoll
local savedL77 = LIVE[7777]
LIVE[7777], LIVEITEM = nil, {}
Rd.misses[7777] = nil
Rd.Send(7777); fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")
now = now + 1.1; timers[#timers]()
Rd.pending = nil
Rd.Send(7777)
now = now + 1.1; timers[#timers]()
Rd.pending = nil
check(Rd.skip[7777] and Rd.stats.skipped == 1 and Rd.stats.timeoutLog[#Rd.stats.timeoutLog - 1]:find("7777 S", 1, true), "zweimal ohne Antwort: ausgelassen, Ereignisse protokolliert")
Rd.round = { 7777, 2770 }; Rd.index = 0; Rd.tick = 1
check(Rd.NextKey() == 2770, "ausgelassener Gegenstand wird uebersprungen")
Rd.skip[7777], Rd.misses[7777] = nil, nil
-- nur AUCTION_HOUSE_NEW_RESULTS_RECEIVED fuer den Gegenstand: Ergebnisse nachsehen
LIVE[7777], LIVEITEM = savedL77, savedLIpk
Rd.Send(7777)
fire("AUCTION_HOUSE_NEW_RESULTS_RECEIVED", { itemID = 7777 })
timers[#timers]()
check(Rd.pending == nil and Rd.stats.cached == 2 and Rd.entries[7777], "neues Ergebnis ohne ..._UPDATED: gelesen")
Rd.entries[7777] = nil
sounds = 0
-- Datenbank: Live-Stand (Rechenmodell F5-Median), weg, wieder da, naechster Scan
local eL = D.ApplyLive(7780, { { price = 10, qty = 3, own = 0 }, { price = 20, qty = 1, own = 1 } }, clock)
check(eL.m == 10 and eL.md == 10 and eL.q == 4 and eL.lv == "10:3;20:1" and eL.lt == clock and eL.t == nil and eL.d == nil, "ApplyLive: Min, Median, Menge, Stufen; kein Verlauf")
D.ApplyLive(7780, {}, clock + 5)
check(eL.gone == clock + 5 and eL.q == 0 and eL.m == 10, "ApplyLive ohne Angebote: weg, letzte Preise bleiben")
D.ApplyLive(7780, { { price = 12, qty = 2, own = 0 } }, clock + 9)
check(eL.gone == nil and eL.m == 12 and eL.lt == clock + 9, "wieder da")
local fm = { items = { [7780] = eL, [7781] = { m = 5, t = clock + 20, q = 1 } } }
check(D.MarkGone(fm, clock - 100, clock + 20) == 1 and eL.gone == clock + 20 and not fm.items[7781].gone, "naechster Scan ohne den Gegenstand: weg (auch wenn nur live gesehen)")
market.items[7780] = nil
Rd.pending = nil
Rd.Send(7777)
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 7777)
check(Rd.entries[7777] and sounds == 1 and lastSound[1] == 8959 and lastSound[2] == "Master" and Rd.entries[7777].newUntil
    and Rd.list.rowFrames[1].cells[1].text:find("dot_new", 1, true) and not Rd.list.rowFrames[1].cells[1].text:find("●", 1, true), "neuer Treffer: Ton (Schlachtzugswarnung, Master), Punkt als eigenes Bild (ab 0.19)")
check(Rd.entries[7777].flashUntil == now + 5 and Rd.list.rowFrames[1].tint.shown, "Zeile pulsiert 5 Sek. (Standard)")
do
local r1c, g1c, b1c, a1 = Rd.RowColor(Rd.entries[7777])
now = now + 0.33
local _, _, _, a2 = Rd.RowColor(Rd.entries[7777])
check(g1c == 0.9 and a1 ~= a2, "Pulsieren: Deckkraft aendert sich")
now = now + 5
local rr = { Rd.RowColor(Rd.entries[7777]) }
check(rr[1] == 1 and rr[4] == 0.10, "nach 5 Sek.: wieder normale Farbe (Haendler gold)")
mod.db.radarSoundKey = "alarm"; Rd.PlayAlert()
check(lastSound[1] == 12889, "Warnton waehlbar")
mod.db.radarSoundKey = "raid"; sounds = sounds - 1
end
mod.db.radarSound = false
Rd.entries[7777] = nil
Rd.Send(7777); fire("COMMODITY_SEARCH_RESULTS_UPDATED", 7777)
check(sounds == 1 and Rd.entries[7777], "Ton abschaltbar")
mod.db.radarSound = true
Rd.entries[7777].checked = now - 20
Rd.tick = 2
check(Rd.NextKey() == 7777, "Treffer wird oefter nachgeprueft (jeder dritte Schritt)")
Win.Select("prices")
check(not Rd.running and not Rd.loop, "Reiter verlassen: Radar-Scan aus")
do -- 0.16: Reihenfolge, nur Warnton, ungeladene Gegenstaende, Auswahltext
check(Rd.selected == nil or Rd.selText.text ~= "", "Auswahlzeile gefuellt")
local CV = { Sound_SFXVolume = "0.8", Sound_MusicVolume = "0.5", Sound_AmbienceVolume = "0.6", Sound_DialogVolume = "1",
    Sound_EnableSoundWhenGameIsInBG = "0", Sound_EnableAllSound = "1", Sound_MasterVolume = "0.7" }
C_CVar = { GetCVar = function(n) return CV[n] end, SetCVar = function(n, v) CV[n] = tostring(v) end }
Win.Select("prices"); Win.Select("radar")
check(mod.db.radarMute == true and Rd.muteCheck:GetChecked(), "Nur Warnton: Standard an, Haken im Reiter")
Rd.scanButton.scripts.OnClick(Rd.scanButton)
check(Rd.running and CV.Sound_SFXVolume == "0" and CV.Sound_MusicVolume == "0" and CV.Sound_AmbienceVolume == "0" and CV.Sound_DialogVolume == "0"
    and CV.Sound_EnableSoundWhenGameIsInBG == "1" and CV.Sound_MasterVolume == "0.7" and PeonBrokerDB.radarMuteSaved.Sound_SFXVolume == "0.8", "Scan: nur Gesamt-Kanal, Ton im Hintergrund, alte Werte gemerkt")
Rd.scanButton.scripts.OnClick(Rd.scanButton)
check(not Rd.running and CV.Sound_SFXVolume == "0.8" and CV.Sound_EnableSoundWhenGameIsInBG == "0" and PeonBrokerDB.radarMuteSaved == nil, "Stopp: Tonkanaele zurueck")
Rd.scanButton.scripts.OnClick(Rd.scanButton)
Win.Select("prices")
check(CV.Sound_MusicVolume == "0.5" and PeonBrokerDB.radarMuteSaved == nil, "Reiter verlassen: Tonkanaele zurueck")
Win.Select("radar")
Rd.scanButton.scripts.OnClick(Rd.scanButton)
fire("PLAYER_LOGOUT")
check(CV.Sound_DialogVolume == "1" and PeonBrokerDB.radarMuteSaved == nil, "Ausloggen/Reload waehrend des Scans: zurueck")
Rd.muteCheck:SetChecked(false); Rd.muteCheck.scripts.OnClick(Rd.muteCheck)
Rd.MuteOn()
check(mod.db.radarMute == false and CV.Sound_SFXVolume == "0.8", "Nur Warnton aus: nichts veraendert")
Rd.Stop()
mod.db.radarMute = true
PeonBrokerDB.radarMuteSaved = { Sound_SFXVolume = "0.3" }
Rd.Init()
check(CV.Sound_SFXVolume == "0.3" and PeonBrokerDB.radarMuteSaved == nil, "nach Absturz: gemerkte Werte beim Start zurueck")
CV.Sound_SFXVolume = "0.8"
-- Reihenfolge
local function roundKeys() local r = Rd.BuildRound(); local t = {} for i, k in ipairs(r) do t[k] = i end return r, t end
local nList = 0 for _ in pairs(PeonBrokerDB.lists[1].items) do nList = nList + 1 end
mod.db.radarOrder = "high"
local rh = Rd.BuildRound()
local okHigh = true
for i = nList + 2, #rh do if (market.items[rh[i - 1]].md or 0) < (market.items[rh[i]].md or 0) then okHigh = false end end
check(okHigh and #rh > nList, "hoechster Preis zuerst (nach den Einkaufslisten)")
mod.db.radarOrder = "low"
local rl = Rd.BuildRound()
local okLow = true
for i = nList + 2, #rl do if (market.items[rl[i - 1]].md or 0) > (market.items[rl[i]].md or 0) then okLow = false end end
check(okLow, "niedrigster Preis zuerst")
mod.db.radarOrder = "commodity"
local rc = Rd.BuildRound()
local seenItem, okCom = false, true
for i = nList + 1, #rc do if D.IsCommodity(rc[i]) then if seenItem then okCom = false end else seenItem = true end end
check(okCom, "Massenware zuerst")
mod.db.radarOrder = "random"
local rr = Rd.BuildRound()
check(#rr == #rh, "zufaellig: alle Gegenstaende")
Rd.orderBox.Refresh()
Rd.SetOrder("smart")
check(mod.db.radarOrder == "smart" and Rd.OrderText("commodity") == "Massenware zuerst", "Auswahl gespeichert, Texte")
-- Gegenstandsdaten nicht geladen: anfordern, spaeter abfragen
local requested = {}
C_Item.IsItemDataCachedByID = function(id) return id ~= 2589 or requested.done end
C_Item.RequestLoadItemDataByID = function(id) requested[id] = true end
Rd.round, Rd.index, Rd.later, Rd.tick, Rd.entries = { 2589, 2770 }, 0, {}, 0, {}
Rd.running = true
check(Rd.NextKey() == 2770 and requested[2589] and Rd.later[1] == 2589, "ungeladen: Daten angefordert, erst ein anderer Gegenstand")
requested.done = true
check(Rd.NextKey() == 2589 and #Rd.later == 0, "danach der nachgeladene")
C_Item.IsItemDataCachedByID, C_Item.RequestLoadItemDataByID = nil, nil
Rd.running = false
Win.Select("prices")
C_CVar = nil
end

-- Beim Oeffnen: Treffer aus der Datenbank bis radarMaxAge (Standard 60 Min., 0 = unbegrenzt)
Rd.entries = {}
Win.Select("prices"); Win.Select("radar")
check(Rd.entries[7778] == nil and Rd.entries[7777] ~= nil, "weggefallener Treffer kommt aus der Datenbank nicht wieder, gespeicherter Live-Treffer schon")
Win.Select("prices")
Rd.entries = {}
market.items[7777].t, market.items[7777].lt = clock - 7200, nil
check(mod.db.radarMaxAge == 60, "Standard: 60 Min.")
Win.Select("radar")
check(Rd.entries[7777] == nil, "aelter als 60 Min.: nicht angezeigt")
Win.Select("prices")
mod.db.radarMaxAge = 0
Win.Select("radar")
local r77 for i, it in ipairs(Rd.list:GetItems()) do if it.key == 7777 then r77 = i end end
check(Rd.entries[7777] ~= nil and r77 and Rd.list.rowFrames[r77].cells[7].text:find("2 Std.", 1, true), "0 = unbegrenzt, Alter 2 Std.")
Win.Select("buy")
mod.db.radarMaxAge = 60
market.lastScan = savedLast
market.items[7777], market.items[7778], market.items[7779], VENDOR[7777], VENDOR[7779] = nil, nil, nil, nil, nil
LIVEITEM = savedLI2
VENDOR[2589] = savedV2589
Rd.entries = {}

-- ===== Radar 0.19: Gewinn mit meinem Gold, Mindestgewinn, Schnellkauf, mehrere Einzelgegenstaende, Auswahl, Ausblenden, voller Scan, Haendler =====
do
    check(ns.ParseMoney("1g 20s 5c") == 12005 and ns.ParseMoney("50s") == 5000 and ns.ParseMoney("10c") == 10 and ns.ParseMoney("3", 100) == 300
        and ns.ParseMoney("2", 10000) == 20000 and ns.ParseMoney("abc") == nil and ns.MoneyText(12005) == "1g 20s 5c" and ns.MoneyText(0) == "0c", "Geldbetraege lesen und schreiben")
    Win.Select("radar")
    Rd.Halt(); Rd.entries = {}; Rd.selected = nil
    mod.acc.commodity[8801], mod.acc.commodity[8802] = true, false
    VENDOR[8801] = 100
    market.items[8801] = { m = 50, md = 95, q = 60, n = 2, t = clock - 30, lv = "50:40;90:20", nm = "Haendlerkram", ql = 1 }
    market.items[8802] = { m = 40000, md = 100000, q = 23, n = 4, t = clock - 30, lv = "40000:3;100000:20", nm = "Stab des Testers", ql = 2,
        d = D.Day(clock) .. ":480000:1200000:48:12" }
    LIVE[8801] = { { unitPrice = 50, quantity = 40 }, { unitPrice = 90, quantity = 20 } }
    local savedLI = LIVEITEM
    LIVEITEM = { { buyoutAmount = 40000, quantity = 1, auctionID = 201 }, { buyoutAmount = 40000, quantity = 1, auctionID = 202 },
        { buyoutAmount = 40000, quantity = 1, auctionID = 203 }, { buyoutAmount = 100000, quantity = 20, auctionID = 204 } }
    Rd.entries[8801] = Rd.Evaluate(8801, D.ParseLevels(market.items[8801].lv), true, true); Rd.entries[8801].checked = now
    Rd.entries[8802] = Rd.Evaluate(8802, D.ParseLevels(market.items[8802].lv), false, false)
    -- Gewinn mit meinem Gold (Gold minus Goldreserve)
    GetMoney = function() return 10000 + 3000 end
    mod.db.radarReserve = 1
    Rd.Refresh()
    local h = Rd.entries[8801]
    check(Rd.Budget() == 3000 and h.best.qty == 51 and h.best.gain == 40 * 50 + 11 * 10 and h.showGain == 2110, "Gewinn mit meinem Gold: 51 Stueck (Goldreserve 1g abgezogen), +21s 10c")
    local hr for i, it in ipairs(Rd.list:GetItems()) do if it.key == 8801 then hr = i end end
    check(hr and plain(Rd.list.rowFrames[hr].cells[5].text) == "51/60", "Menge: mit meinem Gold / ganzes Schnaeppchen")
    local sr for _, it in ipairs(Rd.list:GetItems()) do if it.key == 8802 then sr = true end end
    check(Rd.entries[8802] and Rd.entries[8802].cant and not sr, "Stab: mit 1g 30s kein Gewinn moeglich -> nicht angezeigt")
    -- Mindestgewinn im Reiter (Geldbetrag)
    Rd.minVendorBox:SetText("30s"); Rd.minVendorBox.scripts.OnEnterPressed(Rd.minVendorBox)
    check(mod.db.dealMinVendor == 3000 and Rd.entries[8801].cant and liveRows() == 0, "Mindestgewinn Haendler 30s: 21s 10c reicht nicht")
    Rd.minVendorBox:SetText("10c"); Rd.minVendorBox.scripts.OnEnterPressed(Rd.minVendorBox)
    Rd.minMarketBox:SetText("2"); Rd.minMarketBox.scripts.OnEnterPressed(Rd.minMarketBox)
    check(mod.db.dealMinVendor == 10 and mod.db.dealMinMarket == 2 and Rd.minMarketBox:GetText() == "2s", "Mindestgewinn: Zahl ohne Einheit = Silber")
    mod.db.dealMinMarket = 50
    -- Schnellkauf: bestes Haendler-Schnaeppchen, alles was ich mir leisten kann
    Rd.UpdateView()
    check(Rd.quickTarget == Rd.entries[8801] and not Rd.quickButton.disabled and plain(Rd.quickInfo.text):find("×51", 1, true), "Schnellkauf zeigt das beste Haendler-Schnaeppchen")
    purchaseStarted, purchaseConfirmed = nil, nil
    Rd.quickButton.scripts.OnClick(Rd.quickButton)
    check(purchaseStarted and purchaseStarted[1] == 8801 and purchaseStarted[2] == 51 and Rd.quickButton.disabled, "Schnellkauf: 51 Stueck, warten auf den Preis")
    fire("COMMODITY_PRICE_UPDATED", 90, 2990)
    check(Rd.quickButton.text == "Bestätigen" and not Rd.quickButton.disabled, "Preis passt: Bestaetigen")
    Rd.quickButton.scripts.OnClick(Rd.quickButton)
    fire("COMMODITY_PURCHASE_SUCCEEDED")
    check(purchaseConfirmed and purchaseConfirmed[2] == 51 and not (PeonBrokerCharDB.vendorFlip or {})[8801] and Rd.entries[8801].qty == 9 and not Rd.entries[8801].live,
        "gekauft: nichts mehr gemerkt (Haendler-Knopf entfaellt), Rest wird neu geprueft")
    -- 0.24 (Feedback #6): Preis vorab holen, ein Klick kauft sofort
    Rd.preOff, Rd.preMiss, Rd.preAt = nil, 0, nil
    Rd.entries[8801].qty, Rd.entries[8801].live = 51, true
    Rd.entries[8801].rows = { { price = 50, qty = 51, own = 0 } }
    Rd.entries[8801].best = { qty = 51, cost = 2550, gain = 100 }
    purchaseStarted, purchaseConfirmed = nil, nil
    local cancelledPre = 0
    AHs.CancelCommoditiesPurchase = function() cancelledPre = cancelledPre + 1 end
    Rd.UpdateView()
    check(purchaseStarted and purchaseStarted[1] == 8801 and purchaseStarted[2] == 51 and Rd.pre and Rd.pre.stage == "quote"
        and not Rd.quickButton.disabled, "Schnellkauf: Preis wird vorab angefragt, Knopf bleibt frei")
    fire("COMMODITY_PRICE_UPDATED", 50, 2550)
    check(Rd.pre.stage == "ready" and Rd.quickButton.text == "Händler: jetzt kaufen", "Preis da: Knopf kauft mit einem Klick")
    Rd.quickButton.scripts.OnClick(Rd.quickButton)
    check(purchaseConfirmed and purchaseConfirmed[1] == 8801 and purchaseConfirmed[2] == 51 and Rd.pre == nil and Rd.job and Rd.job.stage == "wait",
        "ein Klick: sofort bestaetigt")
    fire("COMMODITY_PURCHASE_SUCCEEDED")
    check(Rd.job == nil, "gekauft")
    -- Preis vorab zu hoch: verwerfen, Treffer neu pruefen
    Rd.entries[8801] = Rd.entries[8801] or Rd.Evaluate(8801, { { price = 50, qty = 51, own = 0 } }, true, true)
    Rd.entries[8801].rows, Rd.entries[8801].best, Rd.entries[8801].live = { { price = 50, qty = 51, own = 0 } }, { qty = 51, cost = 2550, gain = 100 }, true
    Rd.preAt = nil
    Rd.UpdateView()
    check(Rd.pre and Rd.pre.stage == "quote", "neue Anfrage")
    fire("COMMODITY_PRICE_UPDATED", 80, 4080)
    check(Rd.pre == nil and cancelledPre >= 1 and Rd.entries[8801] and not Rd.entries[8801].live, "Preis gestiegen: Anfrage verworfen, Treffer wird neu geprueft")
    -- 0.28: Blizzards Kaufansicht offen -> kein Vorab-Preis, eine Preisantwort bricht nichts ab
    Rd.entries[8801].rows, Rd.entries[8801].best, Rd.entries[8801].live = { { price = 50, qty = 51, own = 0 } }, { qty = 51, cost = 2550, gain = 100 }, true
    Rd.preAt = nil
    Rd.UpdateView()
    check(Rd.pre and Rd.pre.stage == "quote", "0.28: Anfrage vorab")
    AuctionHouseFrame.CommoditiesBuyFrame = { IsShown = function() return true end }
    Rd.c0 = cancelledPre
    fire("COMMODITY_PRICE_UPDATED", 80, 4080)
    check(Rd.pre == nil and cancelledPre == Rd.c0 and Rd.entries[8801].live, "0.28: Blizzard kauft gerade - Antwort nicht als eigene gewertet, nichts abgebrochen")
    Rd.preAt = nil; purchaseStarted = nil
    Rd.UpdateView()
    check(Rd.pre == nil and purchaseStarted == nil, "0.28: Blizzards Kaufansicht offen - kein Preis vorab")
    AuctionHouseFrame.CommoditiesBuyFrame = nil
    Rd.selected = Rd.entries[8801]
    Rd.preAt = nil; Rd.UpdateView()
    check(Rd.pre == nil and purchaseStarted == nil, "0.28: Treffer gewaehlt - kein Preis vorab")
    Rd.selected = nil
    -- keine Antwort: nach zwei Versuchen zwei Klicks wie bisher
    Rd.preOff, Rd.preMiss = nil, 0
    for _ = 1, 2 do
        Rd.entries[8801].best, Rd.entries[8801].rows = { qty = 51, cost = 2550, gain = 100 }, { { price = 50, qty = 51, own = 0 } }
        Rd.preAt = nil; Rd.UpdateView(); now = now + Rd.PRE_WAIT + 1; Rd.UpdateView()
    end
    check(Rd.preOff and Rd.pre == nil, "Spiel antwortet nicht: Preis vorab aus, zwei Klicks")
    Rd.preOff, AHs.CancelCommoditiesPurchase = true, nil
    Rd.entries[8801] = nil
    -- Einzelgegenstaende: mehrere Auktionen (Stab mit Gewinn erst ab 3 Kaeufen)
    GetMoney = function() return 1000000 end
    mod.db.radarReserve = 0
    Rd.Halt()
    Rd.Refresh()
    local st = Rd.entries[8802]
    check(not st.cant and st.qty == 3 and Rd.MinProfitQty(st) == 3, "Stab: Gewinn erst ab 3 Stueck")
    Rd.SelectRow(st)
    check(Rd.focus and Rd.focus.key == 8802 and Rd.buyAllButton.shown and Rd.buyAllButton.text == "Alle (3)" and not Rd.buyStackButton.shown, "Einzelgegenstand: Knopf Alle (3)")
    -- gewaehlt: zuerst zeigt das Auktionshaus den Gegenstand (dessen Abfrage zaehlt), dann alle 5 Sek. neu
    browse, query = nil, nil
    Sell.pending, Buy.pending = nil, nil   -- haengende Abfragen aus frueheren Tests (ab 0.21.1 wartet die Anzeige darauf)
    now = now + 1; timers[#timers]()
    check(browse and browse.itemKey.itemID == 8802 and Rd.pending and Rd.pending.viaAH and query == nil, "Auswahl: im Auktionshaus gezeigt, keine zweite Abfrage")
    fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 8802 })
    check(Rd.pending == nil and Rd.entries[8802].live and Rd.entries[8802].auctionID == 201, "Antwort fuer die Anzeige des Auktionshauses ausgewertet")
    check(Buy.showGuard and Buy.showGuard.itemID == 8802, "Anzeige wird einmal wie „Neu laden“ nachgeladen (eigener Ablauf, ab 0.21.1)")
    Buy.showGuard = nil
    now = now + 2; timers[#timers]()
    check(query == nil or query.key.itemID ~= 8802, "vor 5 Sek. keine neue Abfrage fuer den gewaehlten")
    now = now + 4; timers[#timers]()
    check(query == nil or query.key.itemID ~= 8802, "ab 0.21.1: auch nach 5 Sek. kein Neuladen (Blizzard-Fenster lud sonst immer wieder neu)")
    placed = {}
    Rd.buyAllButton.scripts.OnClick(Rd.buyAllButton)
    check(#placed == 1 and placed[1][1] == 201 and placed[1][2] == 40000 and Rd.buyAllButton.disabled, "Alle: erste Auktion")
    fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 201)
    check(Rd.buyAllButton.text == "Weiter (2 übrig)" and not Rd.buyAllButton.disabled and Rd.job.done == 1, "ein Klick je Auktion: Weiter (2 uebrig)")
    Rd.buyAllButton.scripts.OnClick(Rd.buyAllButton)
    fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 202)
    Rd.buyAllButton.scripts.OnClick(Rd.buyAllButton)
    check(#placed == 3 and placed[3][1] == 203, "dritte Auktion")
    fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 203)
    check(Rd.job == nil and PeonBrokerDB.bought == nil and Rd.entries[8802] == nil and Rd.focus == nil and said("Gekauft: 3× Stab des Testers"), "alle drei gekauft, fuers Buch vermerkt, Auswahl beendet")
    -- Alle ausblenden / alle wieder zeigen (ohne Chatmeldung)
    Rd.entries[8801] = Rd.Evaluate(8801, D.ParseLevels(market.items[8801].lv), true, true)
    Rd.Refresh()
    local nOut = #out
    Rd.hideAllButton.scripts.OnClick(Rd.hideAllButton)
    check(liveRows() == 0 and Rd.IsHidden(8801) and #out == nOut, "Alle ausblenden, ohne Chatmeldung")
    Rd.ShowAllHidden()
    check(not Rd.IsHidden(8801) and Rd.HiddenCount() == 0, "Alle wieder zeigen")
    -- voller Scan beendet den Radar-Scan
    Rd.Halt()
    Rd.Start()
    check(Rd.running, "Radar-Scan laeuft")
    ns.Scan.state = { phase = "wait" }
    timers[#timers]()
    check(not Rd.running and not Rd.loop and Rd.scanButton.disabled and plain(Rd.status.text):find("Broker-Scan läuft", 1, true), "Broker-Scan: Radar-Scan beendet, Knopf gesperrt")
    Rd.Start()
    check(not Rd.running, "waehrend des Scans kein Radar-Start")
    ns.Scan.state = nil
    -- Optionsseite: Geldbetraege
    local moneyC
    for _, c in ipairs(mod.page.controls) do if c.boxes then moneyC = c end end
    check(moneyC and #moneyC.boxes == 3, "Optionen: Mindestgewinn Haendler/Markt und Goldreserve")
    moneyC.boxes[3]:SetText("25"); moneyC.boxes[3].scripts.OnEnterPressed(moneyC.boxes[3])
    check(mod.db.radarReserve == 25 and moneyC.boxes[3]:GetText() == "25g", "Goldreserve: Zahl = Gold")
    mod.db.radarReserve = 0
    -- aufraeumen
    GetMoney = nil
    Rd.Halt(); Rd.entries = {}; Rd.selected = nil
    market.items[8801], market.items[8802], LIVE[8801], VENDOR[8801] = nil, nil, nil, nil
    LIVEITEM = savedLI
    Win.Select("buy")
end
-- Abfrage-Test (/broker pruefen abfrage, 0.14.3): in welchem Zusammenhang schickt das Spiel eine Abfrage ab?
query = nil
SlashCmdList.PEON_BROKER("pruefen abfrage")
check(said("Abfrage-Test mit") and query and query.normal, "Abfrage-Test: 1. direkt im Befehl gesendet")
local qid = query.key.itemID
fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT"); now = now + 0.3
query = nil
fire("COMMODITY_SEARCH_RESULTS_UPDATED", qid)
check(query and query.key.itemID == qid, "2. im Ergebnis-Ereignis gesendet")
fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT"); fire("COMMODITY_SEARCH_RESULTS_UPDATED", qid)
query = nil
timers[#timers]()
check(query and query.key.itemID == qid, "3. aus C_Timer gesendet")
timers[#timers]()            -- keine Antwort (wie im Spiel beobachtet): Zeit abgelaufen
timers[#timers]()            -- 4. vorbereiten: OnUpdate
local qf
for _, f in ipairs(allFrames) do if f.scripts.OnUpdate and f.events.AUCTION_HOUSE_THROTTLED_MESSAGE_SENT then qf = f end end
query = nil
qf.scripts.OnUpdate(qf, 0.02)
check(query and not qf.scripts.OnUpdate, "4. aus OnUpdate gesendet (einmal)")
fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT"); fire("COMMODITY_SEARCH_RESULTS_UPDATED", qid)
query = nil
timers[#timers]()            -- 5. ueber die Radar-Funktion
check(query and query.key.itemID == qid and Rd.pending and Rd.pending.key == qid, "5. ueber die Radar-Funktion gesendet")
fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT"); fire("COMMODITY_SEARCH_RESULTS_UPDATED", qid)
query = nil
timers[#timers]()            -- 6. Radar-Funktion mit einem Gegenstand der Einkaufsliste
local lid = query and query.key.itemID
check(lid and PeonBrokerDB.lists[1].items[lid] ~= nil, "6. Gegenstand der Einkaufsliste ueber die Radar-Funktion")
fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT"); fire("COMMODITY_SEARCH_RESULTS_UPDATED", lid)
local ql = PeonBrokerDB.queryTest and PeonBrokerDB.queryTest.lines or {}
check(#ql == 6 and ql[5]:find("Radar: gesendet ja, Antwort ja", 1, true) and ql[6]:find("Radar " .. lid .. ": gesendet ja, Antwort ja", 1, true) and ql[1]:find("Befehl: gesendet ja, Antwort ja", 1, true) and ql[2]:find("Ereignis: gesendet ja, Antwort ja", 1, true)
    and ql[3]:find("Timer: gesendet nein, Antwort nein", 1, true) and ql[4]:find("OnUpdate: gesendet ja, Antwort ja", 1, true), "Ergebnis im Chat und in PeonBrokerDB.queryTest")
Buy.deleteButton.scripts.OnClick(Buy.deleteButton)
check(#PeonBrokerDB.lists == 0, "Liste geloescht")
Win.Select("sell")

-- ohne Auktionshaus
fire("AUCTION_HOUSE_CLOSED")
SlashCmdList.PEON_BROKER("")
Win.Select("sell")
Sell.Select(Sell.list:GetItems()[1])
check(Sell.post.disabled and plain(Sell.hints.text):find("Auktionshaus öffnen", 1, true) and Sell.liveText.text:find("geschlossen", 1, true), "ohne Auktionshaus: nur ansehen")
Sell.post.scripts.OnClick(Sell.post)
check(said("Zum Einstellen das Auktionshaus öffnen"), "Einstellen verweigert")
SlashCmdList.PEON_BROKER("")
C_Container, AHs.IsSellItemValid, AHs.GetItemCommodityStatus, AHs.PostCommodity = savedContainer, savedValid, savedStatus, savedPostC
AHs.PostItem = function() error("darf nie aufgerufen werden") end
fire("AUCTION_HOUSE_SHOW")

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
    local sgP = D.SuggestSell(rowsP, market.items[4444], 4444, nil, mod.db)
    check(sgP.median == 200 and sgP.dump, "Vorschlag mit Teil-Ergebnis: Median aus der Datenbank (Dumping erkannt)")
    market.items[4444], LIVE[4444] = nil, nil
    AHs.HasFullCommoditySearchResults = savedHF
    -- 0.28: Teil-Ergebnis beim Verkaufen - Rest wird beim Spiel angefordert
    WithBlizzard(true)
    Win.Select("sell")
    local savedL0, fullNow, asked = LIVE[2770], false, 0
    AHs.HasFullCommoditySearchResults = function(id) return id ~= 2770 or fullNow end
    AHs.RequestMoreCommoditySearchResults = function() asked = asked + 1; return false end
    LIVE[2770] = { { unitPrice = 100, quantity = 5 } }
    local ku0 for _, it in ipairs(Sell.ScanBags()) do if it.key == 2770 then ku0 = it end end
    Sell.Select(ku0)
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
    check(asked == 1 and Sell.pending and Sell.live == nil, "0.28: Teil-Ergebnis - Rest angefordert, Broker wartet")
    fullNow = true
    LIVE[2770] = { { unitPrice = 100, quantity = 5 }, { unitPrice = 300, quantity = 60 } }
    fire("COMMODITY_SEARCH_RESULTS_ADDED", 2770)
    check(Sell.pending == nil and Sell.live and #Sell.live == 2 and not Sell.live.partial, "0.28: Rest da - vollstaendige Liste uebernommen")
    AHs.RequestMoreCommoditySearchResults, LIVE[2770] = nil, savedL0

    -- Eintragspreis (F23a): guenstigstes Angebot minus Unterbieten, Vorschlag bleibt Richtwert
    local e = { m = 100, md = 300 }
    local sg = D.SuggestSell({ { price = 100, qty = 5, own = 0 }, { price = 300, qty = 20, own = 0 } }, e, 2770, 5, mod.db)
    local ep, why = D.EntryPrice(sg, e, 2770, 5, mod.db)
    check(sg.dump and sg.vp > 100 and ep == 100 and why == "cheapest", "Dumping: eingetragen wird das guenstigste Angebot, Vorschlag hoeher")
    local ep2, why2 = D.EntryPrice({ source = "live", min = 4, vp = 4 }, nil, 2770, 5, mod.db)
    check(ep2 == 6 and why2 == "min", "unter dem Haendlerpreis: auf den Mindestpreis angehoben")
    check(D.EntryPrice({ source = "own", vp = 77, min = 77 }, nil, 2770, 5, mod.db) == 77, "eigenes Angebot am guenstigsten: Preis bleibt")
    -- im Reiter: Hinweis "Unter dem Vorschlag"
    WithBlizzard(true)
    Win.Select("sell")
    local savedL = LIVE[2770]
    LIVE[2770] = { { unitPrice = 100, quantity = 5 }, { unitPrice = 300, quantity = 60 } }
    local ku for _, it in ipairs(Sell.ScanBags()) do if it.key == 2770 then ku = it end end
    Sell.Select(ku)
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
    check(Sell.price == 100 and CSF.price == 100 and plain(Sell.priceValue.text) == "1s", "Reiter Verkaufen: guenstigstes Angebot eingetragen")
    check(plain(Sell.hints.text):find("Unter dem Vorschlag", 1, true) and plain(Sell.hints.text):find("Dumping", 1, true), "Hinweis: unter dem Vorschlag, mit Grund")
    popupShown = nil
    local nP, savedPC = 0, AHs.PostCommodity
    AHs.PostCommodity = function(loc, dur, qty, price) nP = price end
    Sell.post.scripts.OnClick(Sell.post)
    AHs.PostCommodity = savedPC
    check(popupShown == nil and nP == 100, "eingetragener Preis: keine Rueckfrage")
    fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
    -- 0.21.2 (Feedback KarloDerBaer): Platz gesperrt, weil der Gegenstand im Verkaufsfenster liegt -> trotzdem einstellen
    local savedCC = C_Container
    C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
        GetContainerItemInfo = function(bag, slot) if bag == 0 and slot == 1 then return { itemID = 2770, stackCount = 5, isLocked = true,
            hyperlink = "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r", quality = 1 } end end }
    Sell.busy = nil
    Sell.item = ku
    local loc0, _, n0 = Sell.CurrentLocation(2770)
    check(loc0 and n0 and n0 > 0, "gesperrter Platz wird trotzdem gefunden")
    local posted2, savedPC2 = nil, AHs.PostCommodity
    AHs.PostCommodity = function(loc, dur, qty, price) posted2 = price end
    CSF.qty = 5
    local nOut = #out
    Sell.post.scripts.OnClick(Sell.post)
    AHs.PostCommodity = savedPC2
    check(posted2 == 100 and not said("nicht mehr in den Taschen"), "Gegenstand im Verkaufsfenster (Platz gesperrt): wird eingestellt, keine falsche Meldung")
    fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
    C_Container = savedCC
    LIVE[2770] = savedL

    -- Blizzard-Fenster: Daten noch nicht geladen -> warten, dann zeigen
    local modes = { Buy = {}, CommoditiesBuy = {}, ItemBuy = {}, Auctions = {}, ItemSell = {} }
    AuctionHouseFrameDisplayMode = modes
    local curMode
    AuctionHouseFrame.SetDisplayMode = function(_, m) curMode = m end
    AuctionHouseFrame.GetDisplayMode = function() return curMode end
    local shown = {}
    AuctionHouseFrame.SelectBrowseResult = function(_, r) shown[#shown + 1] = r.itemKey.itemID; curMode = modes.CommoditiesBuy end
    local loaded = false
    AHs.GetItemKeyInfo = function(k) if k.itemID == 5555 and not loaded then return nil end return { itemID = k.itemID } end
    local nT = #timers
    check(Buy.ShowInAH({ key = 5555 }) == false and #shown == 0 and #timers == nT + 1, "Daten nicht geladen: noch nicht zeigen, nachsehen")
    loaded = true
    fire("ITEM_KEY_ITEM_INFO_RECEIVED", 5555)
    check(shown[1] == 5555 and Buy.showWait == nil, "Daten da: Gegenstand gezeigt")
    timers[nT + 1]()
    check(#shown == 1, "alter Nachsehen-Auftrag tut nichts mehr")
    -- 0.20.2/0.21.1: passen die Ergebnisse nicht zum gezeigten Gegenstand -> neu laden, eigene Suche, nochmal zeigen
    local refreshed = {}
    AHs.RefreshItemSearchResults = function(k) refreshed[#refreshed + 1] = k.itemID end
    AHs.RefreshCommoditySearchResults = function(id) refreshed[#refreshed + 1] = id end
    local savedLIg, savedHFIg = LIVEITEM, AHs.HasFullItemSearchResults
    LIVEITEM = {}
    AHs.HasFullItemSearchResults = function() return false end
    Sell.pending, Buy.pending, Rd.pending = nil, nil, nil
    mod.acc.commodity[6666], mod.acc.commodity[6667] = false, false
    check(Buy.ShowInAH({ key = 6666 }) == true and Buy.showGuard and Buy.showGuard.itemID == 6666, "gezeigt, Nachsehen geplant")
    timers[#timers]()
    check(refreshed[1] == 6666 and Buy.showGuard.forced and Buy.showGuard.tries == 0, "nach dem Umschalten: einmal wie „Neu laden“ (Liste leeren, neu abfragen)")
    timers[#timers]()
    check(refreshed[2] == 6666 and Buy.showGuard and Buy.showGuard.tries == 1, "noch keine Ergebnisse: Versuch 1 nochmal neu laden")
    LIVEITEM = { { buyoutAmount = 100, quantity = 1, itemLink = "|cffffffff|Hitem:1234::::::::20:::::::::|h[Anderes]|h|r" } }
    query = nil
    timers[#timers]()
    check(query and query.key.itemID == 6666 and Buy.showGuard.tries == 2, "Ergebnisse eines anderen Gegenstands: Versuch 2 eigene Suche")
    check(#Sell.ReadItems({ itemID = 6666 }) == 0 and Sell.ReadItems({ itemID = 6666 }).foreign == 1, "fremde Ergebnisse werden nicht gelesen")
    LIVEITEM = { { buyoutAmount = 100, quantity = 1, itemLink = "|cffffffff|Hitem:6666::::::::20:::::::::|h[Richtig]|h|r" } }
    fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 6666 })
    timers[#timers]()
    check(Buy.showGuard == nil and PeonBrokerDB.showLog == nil, "passende Ergebnisse: fertig (Protokoll ab 0.28 nur mit Debug)")
    LIVEITEM, AHs.HasFullItemSearchResults = savedLIg, savedHFIg
    Buy.ShowInAH({ key = 6667 })
    timers[#timers]()
    fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 6667 })
    timers[#timers]()
    check(#refreshed == 3 and Buy.showGuard == nil, "Ergebnis passt nach dem Neuladen: keine weiteren Versuche")
    local readyFn2 = AHs.IsThrottledMessageSystemReady
    AHs.IsThrottledMessageSystemReady = function() return false end
    local nShown = #shown
    check(Buy.ShowInAH({ key = 6668 }) == false and #shown == nShown, "Spiel nicht bereit: noch nicht umschalten")
    AHs.IsThrottledMessageSystemReady = readyFn2
    timers[#timers]()
    check(shown[#shown] == 6668, "Spiel bereit: umgeschaltet")
    Buy.showGuard = nil
    AHs.RefreshItemSearchResults, AHs.RefreshCommoditySearchResults = nil, nil
    -- Reiter "Meine Auktionen": Blizzard auf "Auktionen", Klick zeigt die Angebote
    Win.Select("auctions")
    check(curMode == modes.Auctions, "Reiter Meine Auktionen: Blizzard zeigt Auktionen")
    local myOwned = { { auctionID = 21, itemLink = "|cffffffff|Hitem:2770::::::::20:1488:::::::::|h[Kupfererz]|h|r", itemKey = { itemID = 2770, itemLevel = 20 },
        status = 0, quantity = 60, buyoutAmount = 118, timeLeftSeconds = 3600 } }
    local savedNO, savedOI = AHs.GetNumOwnedAuctions, AHs.GetOwnedAuctionInfo
    AHs.GetNumOwnedAuctions, AHs.GetOwnedAuctionInfo = function() return #myOwned end, function(i) return myOwned[i] end
    Auc.Read()
    Auc.UpdateView()
    AHs.GetNumOwnedAuctions, AHs.GetOwnedAuctionInfo = savedNO, savedOI
    local kuRow for i, r in ipairs(Auc.list:GetItems()) do if r.key == 2770 then kuRow = i end end
    Auc.list.rowFrames[kuRow].scripts.OnClick(Auc.list.rowFrames[kuRow], "LeftButton")
    check(shown[#shown] == 2770 and Auc.watch and Auc.watch.key == 2770, "Klick auf eigene Auktion: Angebote im Blizzard-Fenster")
    LIVE[2770] = { { unitPrice = 110, quantity = 5 }, { unitPrice = 118, quantity = 60, containsOwnerItem = true, numOwnerItems = 60 } }
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
    check(Auc.watch == nil and Auc.live[2770].min == 110 and Auc.selected.status == "under", "Ergebnis des Blizzard-Fensters genutzt: unterboten")
    LIVE[2770] = savedL
    Win.Select("radar")
    check(curMode == modes.Buy, "Reiter Radar ohne Auswahl: Blizzard Kaufen-Seite")

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
    check(ghostRow and plain(Rd.list.rowFrames[ghostRow].cells[6].text) == "weg", "Spalte Gewinn zeigt „weg“")
    now = now + 31
    Rd.Refresh()
    check(Rd.gone[7777] == nil and #Rd.list:GetItems() == 0, "nach 30 Sek. aus der Liste")
    -- Pause: Treffer gewaehlt -> keine fremden Abfragen, nochmal anklicken -> weiter
    Rd.entries[7777] = Rd.Evaluate(7777, { { price = 3, qty = 20, own = 0 } }, true, true)
    Rd.entries[7777].checked = now
    Rd.Refresh()
    Rd.Start()
    Rd.list.rowFrames[1].scripts.OnClick(Rd.list.rowFrames[1], "LeftButton")
    check(Rd.focus and Rd.status.text:find("pausiert", 1, true), "Treffer gewaehlt: Radar-Scan pausiert")
    Rd.pending, Rd.lastSend = nil, -100
    Rd.focus.at = now + 100
    local sentBefore = Rd.stats.sent
    now = now + 1; timers[#timers]()
    check(Rd.stats.sent == sentBefore, "pausiert: keine fremde Abfrage")
    Rd.list.rowFrames[1].scripts.OnClick(Rd.list.rowFrames[1], "LeftButton")
    check(Rd.selected == nil and Rd.focus == nil and not Rd.status.text:find("pausiert", 1, true), "nochmal angeklickt: Auswahl weg, Radar laeuft weiter")
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
    -- 0.24 (Feedback #7): graue Zeile anklicken zeigt den Gegenstand trotzdem im Blizzard-Fenster
    Rd.Refresh()
    local nShown2 = #shown
    for i, it in ipairs(Rd.list:GetItems()) do if it.key == 7779 then Rd.list.rowFrames[i].scripts.OnClick(Rd.list.rowFrames[i], "LeftButton") end end
    check(#shown == nShown2 + 1 and shown[#shown] == 7779 and Rd.goneSel == 7779 and Rd.focus == nil, "graue Zeile: im Blizzard-Fenster gezeigt, Radar pausiert")
    Rd.gone[7779].goneUntil = 0
    Rd.Refresh()
    check(Rd.gone[7779] and Rd.selected and Rd.selected.key == 7779, "gewaehlte graue Zeile bleibt in der Liste")
    Rd.SelectRow(nil)
    Rd.Refresh()
    check(Rd.gone[7779] == nil and Rd.goneSel == nil, "Auswahl weg: graue Zeile verschwindet")
    LIVEITEM, AHs.GetNumItemSearchResults, AHs.SendBrowseQuery, AHs.GetBrowseResults = savedLI5, savedNI5, nil, nil
    PeonBrokerDB.itemKeys = nil
    Rd.Halt()
    Rd.entries, Rd.gone, Rd.lastVisible, Rd.soon = {}, {}, nil, nil
    market.items[7777], market.items[7779] = nil, nil
    AuctionHouseFrame.SetDisplayMode, AuctionHouseFrame.GetDisplayMode, AHs.GetItemKeyInfo, AuctionHouseFrameDisplayMode = nil, nil, nil, nil
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
  Win.Select("keep"); K.Refresh()
  check(K.allChars.shown ~= false, "mit Ledger: Umschalter sichtbar")
  K.allChars:SetChecked(true); K.allChars.scripts.OnClick(K.allChars)
  check(mod.db.keepAllChars == true, "Umschalter an")
  _, _, tot, oth = K.Counts(2770)
  check(tot == 85 and oth == 20, "Vorrat aller Charaktere: 65 + 20 bei Twinks")
  K.Set(2770, 70)
  check(K.Sellable(2770, 2770, 60) == 15, "Behalten 70 von 85: 15 zu verkaufen")
  K.Refresh()
  local kr = K.list:GetItems()
  local r for _, x in ipairs(kr) do if x.key == 2770 then r = x end end
  check(r and r.others == 20 and r.total == 85, "Reiter Behalten: Spalte Twinks")
  K.allChars:SetChecked(false); K.allChars.scripts.OnClick(K.allChars)
  check(K.Sellable(2770, 2770, 60) == 0, "Umschalter aus: 65 - 70 = nichts zu verkaufen")
  K.Set(2770, nil); K.Remove(2770)
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
  -- 0.24: Verkaufen zeigt die eigene Verkaufsquote als Hinweis
  local savedItem = Sell.item
  Sell.item = Sell.item or {}
  local hasRate = false
  local okH, errH = pcall(function()
      local fakeIt = { key = 2770, count = 60, e = market.items[2770], hp = 5, locs = {} }
      Sell.item = fakeIt
      for _, h in ipairs(Sell.Hints()) do if plain(h):find("Deine Verkäufe (30 T.): 3 von 4 verkauft (75 %)", 1, true) then hasRate = true end end
  end)
  Sell.item = savedItem
  if not okH then print("FEHLER", errH) end
  check(okH and hasRate, "Verkaufen: Hinweis mit eigener Verkaufsquote")
  -- 0.25: Kosten aus Ledger - Hinweis, wenn der Erloes je Stueck darunter liegt
  Peon.modules.ledger.Cost = function(_, id) if id == 2770 then return 500, 450, 10, 4500 end end
  local savedGP = Sell.GetPrice
  Sell.GetPrice = function() return 300 end
  local hasCost = false
  Sell.item = { key = 2770, count = 60, e = market.items[2770], hp = 5, locs = {} }
  local okC = pcall(function() for _, h in ipairs(Sell.Hints()) do if plain(h):find("Unter deinen Kosten (5s je Stück", 1, true) then hasCost = true end end end)
  Sell.GetPrice = function() return 600 end
  local noCost = true
  pcall(function() for _, h in ipairs(Sell.Hints()) do if plain(h):find("Unter deinen Kosten", 1, true) then noCost = false end end end)
  Sell.item, Sell.GetPrice = savedItem, savedGP
  Peon.modules.ledger.Cost = nil
  check(okC and hasCost and noCost, "Verkaufen: Hinweis unter deinen Kosten (nur wenn der Erloes darunter liegt)")
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
  check(Sa.Speed(r) == nil, "rot: keine Hinweise schnell/voll")
  -- Scan-Vergleich im gleichen Zeitraum: nicht doppelt zaehlen
  Sa.OnScan(e, key, { 50, 100, 3, 60, 40, 3 }, t0)
  Sa.OnScan(e, key, { 50, 70, 3, 60, 40, 3 }, t0 + 1200)
  r = Sa.Stats(e, t0 + 1800)
  check(r.cmp == 1 and r.sold == 30, "Scan-Zeitraum schon gezaehlt: nicht doppelt")
  -- mehr beobachtete Zeit: gelb, dann gruen; Hinweise ab gelb
  live(t0 + 5400, { { 11, 40, 50, 14600 }, { 12, 40, 60, 14600 } })
  r = Sa.Stats(e, t0 + 5400)
  check(r.level == 2 and r.minutes == 90 and Sa.TooltipText(r):find("|cffffd100≈", 1, true), "90 Min. beobachtet: gelbes ≈")
  check(Sa.Speed(r) == "fast", "ab gelb: verkauft sich schnell")
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
  local found for _, l in ipairs(lines) do if l:find("Absatz (6 Std.)", 1, true) then found = l end end
  check(found and found:find("/Std.", 1, true), "Tooltip: Zeile Absatz (6 Std.)")
  shift = false
  -- Chat
  SlashCmdList.PEON_BROKER("absatz Kupfererz")
  check(said("Absatz Kupfererz") and said("letzte 6 Std.:"), "/broker absatz Kupfererz (aktuell; 14 Tage wenn vorhanden)")
  -- Preise: Spalte
  local col for _, c in ipairs(ns.Prices.list.columns) do if c.key == "sales" then col = c end end
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
  fire("MERCHANT_SHOW")
  check(mod.acc.merchant[3002] and mod.acc.merchant[3002].p == 10 and mod.acc.merchant[3100] == nil, "Haendler: Preis je Stueck gemerkt, ohne Gold nicht")
  Cr.Tick()
  c = Cr.calc[3100]
  check(c.lines[1].src == "vendor" and c.lines[1].cost == 10 and c.cost == 30 and plain(b.rows[1].src.text) == "Händler" and plain(b.rows[1].cost.text) == "10c",
      "Faden beim Haendler guenstiger: Quelle Haendler")
  tl = Cr.LineTipLines(b.rows[1].line)
  check(plain(tl[4][2]) == "10c" and plain(tl[6]):find("^Händlerpreis gesehen bei "), "Tooltip: wo der Haendlerpreis herkommt")
  mod.acc.merchant[3002].p = 40
  Cr.dirty = true
  Cr.Tick()
  check(Cr.calc[3100].lines[1].src == "ah" and Cr.calc[3100].lines[1].cost == 30, "AH guenstiger: Quelle AH")
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
  local rows = ns.Sell.ReadItems({ itemID = 11996 }, kA)
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
  PeonBrokerDB.listsGone.items.alt = clock - 90 * 86400
  brokerMod:MergeShop({})
  check(PeonBrokerDB.listsGone.items.alt == nil, "0.34: alte Loeschmarken verfallen")
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

-- ===== Einkaufsliste in Arbeit (0.37.0) =====
Win.WIP = wipKeep
if Win.contents.buy then Win.contents.buy:Hide() end
Win.contents.buy = nil
Win.Open("buy")
check(Win.current == "buy" and Win.contents.buy.wipText and Win.contents.buy.wipText.text == ns.L.TAB_WIP
  and ns.L.TAB_WIP:find("WIP", 1, true), "0.37: Reiter Einkaufsliste zeigt nur den Hinweis")
local hasBuy = false
for _, line in ipairs(ns.Start.Lines()) do if line.tab == "buy" then hasBuy = true end end
check(not hasBuy, "0.37: Start ohne Zeile zur Einkaufsliste")
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
  fire("AUCTION_HOUSE_SHOW")
  check(T.built and T.tabs.radar and T.tabs.shop and T.page and T.plainButton, "U0: zwei Reiter, Flaeche und Knopf Blizzard pur angelegt")
  check(T.tabs.radar.points[1][2] == ah.AuctionsTab and T.tabs.shop.points[1][2] == T.tabs.radar, "U0: Reiter rechts neben Auktionen")
  check(T.tabs.radar.text == ns.L.AHTAB_RADAR and T.tabs.shop.text == ns.L.AHTAB_SHOP, "U0: Reiter heissen Radar und Einkaufen")
  check(#ah.Tabs == 3 and ah.numTabs == nil, "U0: Blizzards Reiterliste bleibt unberuehrt")
  check(T.tabs.radar.parent == T.tabHolder and T.tabHolder.parent == ah and #T.tabHolder.Tabs == 2, "0.41.2: Reiter haengen am eigenen Rahmen, nicht an Blizzards Liste")
  check(T.tabs.radar.points[1][4] == T.TAB_GAP and T.TAB_GAP > -15, "0.41.2: etwas mehr Abstand als Blizzards -15")
  local modesAfter = 0 for _ in pairs(AuctionHouseFrameDisplayMode) do modesAfter = modesAfter + 1 end
  check(modesAfter == modesBefore, "U0: keine eigenen Eintraege in AuctionHouseFrameDisplayMode")
  check(hookedSecure.SetDisplayMode, "U0: sicherer Anhang an SetDisplayMode")
  check(not T.page:IsShown(), "U0: Flaeche anfangs verborgen")

  local dsel = calls.deselect
  T.tabs.radar.scripts.OnClick(T.tabs.radar)
  check(T.current == "radar" and T.page:IsShown() and T.page.title.text == ns.L.AHTAB_RADAR_TITLE, "U0: Klick auf Radar zeigt die Flaeche")
  check(calls.display == 0, "U0: Broker ruft SetDisplayMode nie selbst auf")
  check(calls.deselect - dsel >= 4 and calls.select >= 1, "U0: nur das Aussehen der Reiter wird umgestellt")
  local rt, st = T.tabs.radar, T.tabs.shop
  check(rt.LeftActive.shown and rt.MiddleActive.shown and not rt.Left.shown and rt.disabled, "0.41.2: Radar sieht gewaehlt aus und bleibt es")
  check(not st.LeftActive.shown and st.Left.shown, "0.41.2: Einkaufen sieht nicht gewaehlt aus")
  check(T.Probe(true).vars["Tabs (Inhalt)"] == "sauber", "0.41.2: Pruefung sieht keinen Broker-Reiter in Blizzards Liste")
  table.insert(ah.Tabs, rt)
  check(T.Probe(true).vars["Tabs (Inhalt)"]:find("Peon_Broker", 1, true), "0.41.2: Pruefung meldet Broker-Reiter in Blizzards Liste")
  table.remove(ah.Tabs)
  check(T.page.status.text and T.page.status.text:find("displayMode", 1, true), "U0: Flaeche zeigt den Zustand von Blizzards Werten")

  ah:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)   -- wie Klick auf Blizzards Reiter Kaufen
  check(T.current == nil and not T.page:IsShown() and calls.update >= 1, "U0: Blizzard wechselt die Ansicht -> Flaeche weg, Blizzards Reiter wieder richtig")

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
  check(not ns.AHTouch() and Win.SetAHMode("Buy") == false and ns.Buy.ShowInAH({ key = 2770 }) == false, "U0: bei Blizzard pur kein Umschalten und kein Zeigen in Blizzards Fenster")
  local built = T.built; T.built, T.plainButton = nil, nil
  check(T.Build() == false and T.plainButton == nil, "U0: bei Blizzard pur keine Reiter")
  T.built = built
  mod:ResetDefaults()
  check(mod.acc.ahPlain == true, "U0: Standardwerte lassen Blizzard pur stehen")
  SlashCmdList.PEON_BROKER("pur")
  check(popupShown and popupShown.name == "PEON_BROKER_AH_PLAIN_OFF", "U0: /broker pur fragt beim Zurueckschalten nach")
  StaticPopupDialogs.PEON_BROKER_AH_PLAIN_OFF.OnAccept()
  check(mod.acc.ahPlain == false and calls.reload == 2 and ns.AHTouch(), "U0: Broker im Auktionshaus wieder an")
  AuctionHouseFrame = {}
  CreateFrame = origCreate
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

-- Keine unerwarteten Fehlermeldungen
local n = 0 for _, l in ipairs(out) do if l:find("Fehler") and not l:find("hat einen Fehler gemeldet", 1, true) then n = n + 1 end end  -- erwartete Meldung aus dem Verkaufen-Test
check(n == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
