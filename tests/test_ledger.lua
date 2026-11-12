-- Stub-Test fuer Peon + Peon_Ledger (L1 Pruefbefehl, L2 Bestand aller Charaktere)
-- Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
function GetTime() return 1 end
date = os.date
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
SlashCmdList = {}
-- Metadaten (Version, Titel) direkt aus der TOC-Datei lesen, damit der Test immer die echte Version zeigt
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_Ledger = TocMeta("Peon_Ledger") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function() return true end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Ledger" })[i] end }
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
  function m.GetText(s) return s.text end
  function m.SetChecked(s, v) s.checked = v end
  function m.GetChecked(s) return s.checked end
  function m.SetValue(s, v) s.value = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end
  function m.IsShown(s) return s.shown end
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
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" then return function() end end end })
end
function CreateFrame(kind) local f = W(); f.kind = kind; allFrames[#allFrames+1] = f; return f end
time = os.time
Minimap = CreateFrame("Frame")
UIParent = CreateFrame("Frame")
local cats = {}
Settings = { RegisterCanvasLayoutCategory = function(p, n) local c = { name = n, subs = {}, GetID = function() return n end } cats[n] = c return c end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) table.insert(par.subs, n) return { GetID = function() return par.name .. "/" .. n end } end,
  RegisterAddOnCategory = function(c) c.registered = true end,
  OpenToCategory = function(id) print("OPEN " .. id) end }
-- Farbwaehler (neue API)
local pickerInfo
ColorPickerFrame = { SetupColorPickerAndShow = function(self, info) pickerInfo = info end,
  GetColorRGB = function() return 0.1, 0.2, 0.3 end, GetColorAlpha = function() return 0.5 end }
local CLASS = "WARRIOR"
function UnitClass() return "x", CLASS end
function UnitPowerMax() return 5 end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end
local function said(pat) for i = #out, math.max(1, #out - 30), -1 do if out[i]:find(pat, 1, true) then return true end end return false end

-- ===== Ab hier modulspezifisch =====
-- nachgebaute Spiel-Funktionen (nur ein Teil; der Rest soll als "fehlt" erkannt werden)
function UnitName() return "Mirel", "Dorna" end
function GetRealmName() return "Classic Beta PvE" end
function UnitFactionGroup() return "Alliance", "Allianz" end
function GetBuildInfo() return "1.60.1", "70009", "Oct 1 2026", 16001 end
local money = 123456
function GetMoney() return money end
NUM_BAG_SLOTS, BANK_CONTAINER, NUM_BANKBAGSLOTS = 4, -1, 6
LOOT_ITEM_SELF = "Ihr erhaltet Beute: %s."
local BAGS = { [0] = { { itemID = 118, stackCount = 3, itemName = "Schwacher Heiltrank", quality = 1, iconFileID = 1, hyperlink = "|cffffffff|Hitem:118::::::::20:::::::::|h[Schwacher Heiltrank]|h|r" } } }
C_Container = { GetContainerNumSlots = function(b) return BAGS[b] and 16 or 0 end,
  GetContainerItemInfo = function(b, s) return BAGS[b] and BAGS[b][s] end,
  UseContainerItem = function() end, PickupContainerItem = function(b, s) cursorItem = BAGS[b] and BAGS[b][s] and BAGS[b][s].itemID end }
C_Item = { GetItemSpell = function(id) if id == 118 then return "Heilung", 439 end end }
function GetInventoryItemLink(unit, slot) if slot == 5 then return "|cffffffff|Hitem:6129|h[Robe]|h|r" end end
function GetInventoryItemID(unit, slot) if slot == 5 then return 6129 end end
local inbox = { { "Interface\\Icons\\Inv", nil, "Auktionshaus", "Auktion gewonnen: Jade", 0, 0, 29, 1 }, { nil, nil, "Auktionshaus", "Auktion erfolgreich: Kupfererz", 2556, 0, 29, nil } }
function GetInboxNumItems() return #inbox, #inbox end
function GetInboxItem(i, a) if i == 1 and a == 1 then return "Jade", 1529, 134134, 4, 2, true end end
function GetInboxHeaderInfo(i) return unpack(inbox[i]) end
function GetInboxInvoiceInfo(i) return "seller", "Kupfererz", "Bob", 0, 2585, 100, 129 end
function TakeInboxMoney() end
function GetMerchantNumItems() return 2 end
function GetMerchantItemInfo(i) return "Ware " .. i, nil, 100 * i, 1, -1, true end
function BuyMerchantItem() end
-- weitere Aufrufe, die Ledger mitliest (L3)
local cursorItem, sendMoney = nil, 0
function GetCursorInfo() if cursorItem then return "item", cursorItem end end
function DeleteCursorItem() cursorItem = nil end
function SendMail() end
function GetSendMailMoney() return sendMoney end
function TakeInboxItem() end
function AutoLootMailItem() end
function RepairAllItems() end
function BuybackItem() end
function TakeTaxiNode() end
function BuyTrainerService() end
C_TradeSkillUI = { CraftRecipe = function() end, GetRecipeInfo = function(id) return { name = "Kupferbarren" } end }
local hooks = {}
StaticPopupDialogs = {}
YES, NO = "Ja", "Nein"
local popup
function StaticPopup_Show(name, a, b, data) popup = { name = name, data = data } end
function UnitLevel() return 22 end
local shift = false
function IsShiftKeyDown() return shift end
altDown, ctrlDown = false, false
function IsAltKeyDown() return altDown end
function IsControlKeyDown() return ctrlDown end
function HandleModifiedItemClick(link) return false end
local tt = { lines = {} }
function tt:AddLine(t) self.lines[#self.lines + 1] = t end
function tt:AddDoubleLine(a, b) self.lines[#self.lines + 1] = a .. " | " .. b end
function tt:SetOwner() self.lines = {} end
function tt:Show() end
function tt:Hide() end
function tt:SetHyperlink(l) self.link = l end
function tt:GetItem() return "x", self.link end
function tt:ClearAllPoints() end
function tt:SetPoint(...) self.point = { ... } end
function tt:SetText(t) self.lines = { t } end
GameTooltip = tt
local ttPost
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) ttPost = fn end }
Enum = { TooltipDataType = { Item = 0 }, PlayerInteractionType = { Banker = 8, MailInfo = 17 },
  BagIndex = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5, Bank = -1, BankBag_1 = 6, BankBag_2 = 7, AccountBankTab_1 = 13 } }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
function hooksecurefunc(a, b, c)
  if type(a) == "string" then local orig = _G[a]; _G[a] = function(...) local r = { orig(...) } b(...) return unpack(r) end
  else local orig = a[b]; a[b] = function(...) local r = { orig(...) } c(...) return unpack(r) end end
end

load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
local ns = load("Peon_Ledger", "Peon_Ledger")
fire("ADDON_LOADED", "Peon_Ledger")
local mod = ns.mod
check(mod.initialized and mod.page, "Modul + Optionsseite")
fire("PLAYER_LOGIN")
check(cats.Peon and cats.Peon.subs[1] == "Ledger", "Seite unter Peon > Ledger")
check(Peon.GetFeedbackAreas("Peon_Ledger")[1] == "Prüfung", "Bereiche fuer Peon_Feedback gemeldet")
check(ns.CharName() == "Mirel Dorna" and ns.Realm() == "Classic Beta PvE", "Charakter mit Vor- und Nachname, Realm")

-- Ereignisse und Aufrufe
local ev = PeonLedgerDB.probeEvents
check(ev.BAG_UPDATE_DELAYED and ev.BAG_UPDATE_DELAYED.known and ev.MAIL_SHOW.known, "Ereignisse angemeldet")
fire("UNIT_SPELLCAST_SUCCEEDED", "target", "x", 1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "y", 439)
check(ev.UNIT_SPELLCAST_SUCCEEDED.count == 1 and ev.UNIT_SPELLCAST_SUCCEEDED.samples[1]:find("439", 1, true), "Zauber: nur eigene gezaehlt, mit Werten")
BuyMerchantItem(2, 5)
check(PeonLedgerDB.probeHooks.BuyMerchantItem.count == 1 and PeonLedgerDB.probeHooks.BuyMerchantItem.samples[1] == "2, 5", "Aufruf mitgelesen (Haendlerkauf)")
C_Container.UseContainerItem(0, 1)
check(PeonLedgerDB.probeHooks["C_Container.UseContainerItem"].count == 1, "Aufruf in C_Container mitgelesen (Benutzen)")
check(PeonLedgerDB.probeHooks.DoCraft.exists == false, "fehlende Funktion: nicht mitgelesen")

-- Fenster automatisch lesen
fire("MAIL_SHOW")
timers[#timers]()
local ms = PeonLedgerDB.probeSnaps.mail
check(ms and #ms == 1 and ms[1].letters[1].invoice:find("seller | Kupfererz", 1, true) and ms[1].letters[2].header:find("Auktion erfolgreich", 1, true), "Postfach automatisch gelesen (Kopf und Rechnung)")
check(said("Postfach gelesen"), "Hinweis im Chat beim ersten Mal")
for _ = 1, 4 do fire("MAIL_SHOW"); timers[#timers]() end
check(#PeonLedgerDB.probeSnaps.mail == 3, "hoechstens 3 Schnappschuesse je Fenster")
fire("MAIL_CLOSED")
fire("MERCHANT_SHOW")

-- Pruefbefehl (Haendler noch offen)
SlashCmdList.PEON_LEDGER("pruefen")
local r = PeonLedgerDB.probe
check(r and r.char == "Mirel Dorna" and r.money == 123456 and r.build:find("16001", 1, true), "Pruefung: Charakter, Gold, Version")
check(r.funcs.GROUP_MAIL.GetInboxInvoiceInfo == true and r.funcs.GROUP_SKILL.GetNumTradeSkills == false, "Funktionen je Bereich: vorhanden / fehlt")
check(r.strings.LOOT_ITEM_SELF == "Ihr erhaltet Beute: %s." and r.strings.BANK_CONTAINER == "-1", "Texte und Konstanten")
check(r.bags.bags[1]:find("Tasche 0: 16 Plaetze, 1 belegt", 1, true), "Taschen gelesen")
check(r.equip.equipped:find("1 von 19", 1, true), "Ausruestung gelesen")
check(r.usable.items[1]:find("Zauber Heilung (439)", 1, true), "Trank hat einen Zauber (fuer Benutzt)")
check(r.open_merchant and r.open_merchant.num == "2" and r.open_merchant.items[1]:find("Ware 1", 1, true), "offenes Haendlerfenster mitgelesen")
check(not r.open_mail, "geschlossene Fenster nicht")
check(said("Gerade offen: Händler"), "Meldung: offene Fenster")
check(said("fehlt: ") and said("Post: ") , "Meldung: Funktionen je Bereich, fehlende genannt")
check(ns.Probe.Summary():find("Ereignisse gesehen", 1, true) and ns.Probe.Summary():find("Postfach 3×", 1, true), "Stand fuer die Optionsseite")
check(money == 123456, "nichts veraendert (Gold)")

-- ===== L2: Bestand aller Charaktere =====
local I = ns.Inventory
local realm = PeonLedgerDB.realms["Classic Beta PvE"]
local me = realm and realm.chars["Mirel Dorna"]
check(me and me.money == 123456 and me.class == "WARRIOR" and me.level == 22, "Login: Charakter mit Gold, Klasse, Stufe")
check(me.places.bags.items[118] == 3 and me.places.equip.items[6129] == 1, "Login: Taschen und Ausruestung erfasst")
check(me.start.places.bags.items[118] == 3 and me.start.money == 123456, "Inventur (Ist-Zustand) beim ersten Erfassen")
do
  local used, all = ns.Inventory.PlaceSlots(me, "bags")
  check(used == 1 and all == 16, "Taschen: belegte/alle Plaetze gespeichert")
  -- Ausruestung kommt nach dem Einloggen spaet: leer nicht speichern, spaeter erneut lesen
  local orig = GetInventoryItemID
  GetInventoryItemID = function() end
  me.start.places.equip = { t = 1, items = {} }   -- Stand bis 0.2.0: leere Inventur
  local nt = #timers
  ns.Inventory.ScanEquip()
  check(#timers == nt + 1 and me.places.equip.items[6129] == 1, "leere Ausruestung: nicht gespeichert, neuer Versuch geplant")
  GetInventoryItemID = orig
  timers[#timers]()
  check(me.places.equip.items[6129] == 1 and me.start.places.equip.items[6129] == 1, "zweiter Versuch: Ausruestung und Inventur nachgeholt")
end
check(PeonLedgerDB.items[118].n == "Schwacher Heiltrank", "Name des Gegenstands gemerkt")
-- Taschen aendern sich: nur die gemeldete Tasche wird neu gelesen
BAGS[0][2] = { itemID = 2589, stackCount = 10, itemName = "Leinenstoff", quality = 1, iconFileID = 2 }
BAGS[1] = { { itemID = 2589, stackCount = 5, itemName = "Leinenstoff", quality = 1 } }
fire("BAG_UPDATE", 0)
fire("BAG_UPDATE_DELAYED")
check(me.places.bags.items[2589] == 10, "nur Tasche 0 neu gelesen (Tasche 1 nicht gemeldet)")
fire("BAG_UPDATE", 1); fire("BAG_UPDATE_DELAYED")
check(me.places.bags.items[2589] == 15 and me.start.places.bags.items[2589] == nil, "Tasche 1 dazu; Inventur bleibt beim ersten Stand")
-- im Kampf erst danach
local inCombat = true
local savedIC = Peon.InCombat
Peon.InCombat = function() return inCombat end
BAGS[0][1].stackCount = 2
fire("BAG_UPDATE", 0); fire("BAG_UPDATE_DELAYED")
check(me.places.bags.items[118] == 3, "im Kampf: noch nicht gelesen")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(me.places.bags.items[118] == 2, "nach dem Kampf gelesen")
Peon.InCombat = savedIC
-- Gold
money = 200000
fire("PLAYER_MONEY")
check(me.money == 200000 and me.start.money == 123456, "Gold aktualisiert, Inventur bleibt")
-- Bank (Enum.BagIndex, moderne Bank)
BAGS[-1] = { { itemID = 2589, stackCount = 20, itemName = "Leinenstoff", quality = 1 } }
BAGS[13] = { { itemID = 118, stackCount = 7 } }
local nT = #timers
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
timers[#timers]()
check(I.BankIDs().char[1] == -1 and I.BankIDs().account[1] == 13, "Bank-Taschen aus Enum.BagIndex (Charakter und Accountbank)")
check(me.places.bank.items[2589] == 20 and realm.account.places.warband.items[118] == 7, "Bank und Accountbank erfasst")
check(PeonLedgerDB.bankLog[1]:find("-1:16", 1, true), "Bank-Protokoll")
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 8)
BAGS[-1] = nil
fire("BAG_UPDATE", -1); fire("BAG_UPDATE_DELAYED")
check(me.places.bank.items[2589] == 20, "Bank geschlossen: Stand bleibt")
-- Post (nur offen)
fire("MAIL_INBOX_UPDATE")
check(me.places.mail == nil, "Postfach zu: nichts gelesen")
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 17)
fire("MAIL_INBOX_UPDATE")
check(me.places.mail.items[1529] == 4 and me.places.mail.money == 2556 and me.places.mail.letters == 2, "Post: Anhaenge und Gold")
check(ns.Inventory.PlaceSlots(me, "mail") == 1, "Post: Plaetze = Anhaenge")
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 17)
-- eigene Auktionen
C_AuctionHouse = { QueryOwnedAuctions = function() end, GetNumOwnedAuctions = function() return 2 end,
  GetOwnedAuctionInfo = function(i) return ({ { itemKey = { itemID = 2589 }, quantity = 8, status = 0 }, { itemKey = { itemID = 118 }, quantity = 1, status = 1 } })[i] end }
fire("OWNED_AUCTIONS_UPDATED")
check(me.places.auctions.items[2589] == 8 and me.places.auctions.sold == 1 and not me.places.auctions.items[118], "Auktionen: laufende als Bestand, verkaufte gezaehlt")
do
  local u, a = ns.Inventory.PlaceSlots(me, "auctions")
  check(u == 1 and a == nil, "Auktionen: Plaetze = laufende Auktionen")
  me.places.auctions.used = nil
  check(ns.Inventory.PlaceSlots(me, "auctions") == 1, "Auktionen: alter Stand (ohne used) aus active")
  me.places.auctions.used = 1
end
-- ein Twink (frueher eingeloggt)
realm.chars["Borin Stein"] = { class = "MAGE", money = 50000, seen = os.time() - 7200, places = { bags = { t = 1, items = { [2589] = 5 } } }, start = { places = {} } }
I.Changed()
local cnt = I.Count(2589)
check(cnt.total == 15 + 20 + 8 + 5 and cnt.chars[1].name == "Mirel Dorna" and cnt.chars[2].name == "Borin Stein", "Zaehlen ueber alle Charaktere, eigener zuerst")
check(select(1, I.TotalMoney()) == 250000, "Gold aller Charaktere")
-- Tooltip
tt.lines = {}
tt.link = "|cffffffff|Hitem:2589::::|h[Leinenstoff]|h|r"
ttPost(tt, {})
check(#tt.lines == 1 and tt.lines[1]:find("Ledger", 1, true) and tt.lines[1]:find("Bestand", 1, true) and tt.lines[1]:find("(Umschalt)", 1, true)
  and tt.lines[1]:find("48 (Mirel 43, Borin 5)", 1, true) and not tt.lines[1]:find("Kosten", 1, true), "0.14.2: Standard ohne Umschalt eine Zeile mit dem Bestand (nicht mehr die Kosten)")
shift = true; tt.lines = {}; ttPost(tt, {}); shift = false
check(tt.lines[2] and tt.lines[2]:find("Mirel Dorna | Taschen 15, Bank 20, Auktionen 8", 1, true), "mit Umschalt: Orte je Charakter")
check(tt.lines[3] and tt.lines[3]:find("Borin Stein | Taschen 5", 1, true), "mit Umschalt: Twink")
do
  local TT = ns.Tooltip
  TT.SetPreset("slim")
  tt.lines = {}; ttPost(tt, {})
  check(#tt.lines == 1 and tt.lines[1]:find("| 48", 1, true) and not tt.lines[1]:find("Umschalt", 1, true), "Vorlage Schlank: nur die Summe, ohne Hinweis")
  local lay = TT.Layout()
  lay.lines[1].fmt = "me"; tt.lines = {}; ttPost(tt, {})
  check(tt.lines[1]:find("43 von 48", 1, true), "Format: dieser Charakter")
  lay.lines[1].fmt = "bagsbank"; tt.lines = {}; ttPost(tt, {})
  check(tt.lines[1]:find("Taschen 15 · Bank 20", 1, true), "Format: Taschen + Bank")
  lay.lines[1].when = "off"; tt.lines = {}; ttPost(tt, {})
  check(#tt.lines == 0, "alles aus: keine Zeile")
  TT.SetPreset("standard")
  check(TT.Move("chars", -1) and TT.Layout().lines[1].key == "chars" and not TT.Move("chars", -1), "Reihenfolge aendern")
  shift = true; tt.lines = {}; ttPost(tt, {}); shift = false
  check(tt.lines[1]:find("Ledger", 1, true) and tt.lines[2]:find("Mirel Dorna", 1, true), "Je Charakter zuerst: Kopfzeile allein, dann die Charaktere")
  TT.SetPreset("standard")
  mod.db.tooltipLayout = { lines = { { key = "unbekannt" }, { key = "stock", when = "kaputt" } } }
  local n = TT.Layout()
  check(#n.lines == #TT.BLOCKS and n.lines[1].key == "stock" and n.lines[1].when == "always" and n.lines[2].when == "off", "Einstellung geprueft und ergaenzt")
  TT.SetPreset("standard")
  local pv = table.concat(TT.PreviewLines(true, TT.Layout()), " / ")
  check(pv:find("Bestand", 1, true) and pv:find("Zuletzt gezahlt", 1, true), "Vorschau mit Beispielwerten")
  ns.CreateOptions()
  check(TT.optC and TT.optRows and #TT.optRows == #TT.BLOCKS, "Optionsseite: Zeilen je Baustein")
end
tt.lines = {}; tt.link = "item:99999"; ttPost(tt, {})
check(#tt.lines == 0, "niemand hat ihn: keine Zeile")
-- Fenster (ab 0.14 mit Peon.UI, vier Reiter)
SlashCmdList.PEON_LEDGER("")
local W = ns.Window
local function rowsOf(t) return t.items end
check(W.IsOpen() and W.current == "overview" and #rowsOf(ns.Overview.table) == 2, "Fenster: Uebersicht mit zwei Charakteren")
check(#W.tabButtons == 5 and W.tabButtons[1].text == "Übersicht" and W.tabButtons[3].text == "Buch" and W.tabButtons[5].text == "Info", "0.14.5: fuenf Reiter (Uebersicht, Bestand, Buch, Verlauf, Info)")
check(ns.Overview.TileText("gold"):find("2 Charaktere", 1, true), "Kachel Gold gesamt: " .. ns.Overview.TileText("gold"))
check(ns.Overview.TileText("worth"):find("Peon_Broker", 1, true), "Kachel Vermoegen ohne Broker: Hinweis")
check(ns.Overview.tiles.mail == nil, "0.14.1: keine Kachel Post (erst am Briefkasten bekannt)")
check(ns.Overview.TileText("trade"):find("Verkäufe", 1, true), "Kachel Handelsgewinn heute")
check(W.statusText and W.statusText:find("Charaktere", 1, true), "Statuszeile: " .. tostring(W.statusText))
do
  local rowT
  for _, r in ipairs(rowsOf(ns.Overview.table)) do if r.me then rowT = r end end
  local hasMail = false
  for _, c in ipairs(ns.Overview.table.o.columns) do if c.key == "mailSort" then hasMail = true end end
  local hasWorth = false
  for _, c in ipairs(ns.Overview.table.o.columns) do if c.key == "worth" then hasWorth = true end end
  check(not hasMail and hasWorth and #ns.Overview.table.o.columns == 6, "0.14.4: Uebersicht ohne Post, mit Vermoegen je Charakter")
  check(ns.Overview.tiles.worth.title.text == "Vermögen gesamt", "Kachel heisst Vermoegen gesamt")
  tt.lines = {}
  ns.Overview.RowTooltip({}, rowT)
  local found
  for _, l in ipairs(tt.lines) do if l:find(" frei)", 1, true) and l:find("Stück", 1, true) then found = l end end
  check(found, "Zeilen-Tooltip: Stueck und Plaetze (" .. tostring(found) .. ")")
end
W.Select("stock")
local rows = rowsOf(ns.Stock.table)
check(#rows == 4, "Bestand: alle Gegenstaende, ab 0.14 mit Ware in der Post (" .. #rows .. ")")
ns.Stock.searchBox:SetText("lein"); ns.Stock.searchBox.scripts.OnTextChanged(ns.Stock.searchBox, true)
rows = rowsOf(ns.Stock.table)
check(#rows == 1 and rows[1].total == 48 and rows[1].where:find("Mirel: Taschen 15, Bank 20, Auktionen 8 · Borin: Taschen 5", 1, true), "Suche, Wo-Spalte")
mod.db.stockChar = "Borin Stein"; W.Refresh()
rows = rowsOf(ns.Stock.table)
check(#rows == 1 and rows[1].total == 5 and rows[1].where == "Taschen 5", "Bestand: nur ein Charakter")
mod.db.stockChar = "*"; mod.db.stockPlace = "mail"; ns.Stock.searchBox:SetText(""); ns.Stock.searchBox.scripts.OnTextChanged(ns.Stock.searchBox, true)
rows = rowsOf(ns.Stock.table)
check(#rows == 1 and rows[1].id == 1529 and rows[1].where:find("Post 4", 1, true), "Bestand: Ort Post (gekauft, noch nicht abgeholt)")
mod.db.stockPlace = "all"; W.Refresh()
-- 0.14.2: Summenzeile und Kategorie
local ft = ns.Stock.footer.texts
check(ft and ft.label:find("Summe: 4 Gegenstände", 1, true) and ft.total == tostring(2 + 7 + 48 + 1 + 4), "Summenzeile: Anzahl und Stueck (" .. tostring(ft and ft.label) .. " / " .. tostring(ft and ft.total) .. ")")
C_Item.GetItemInfoInstant = function(id) local c = ({ [118] = 0, [2589] = 7, [6129] = 4, [1529] = 3 })[id] return id, "", "", "", 1, c, 0 end
mod.db.stockCat = "trade"; W.Refresh()
local ids = {} for _, r in ipairs(ns.Stock.table.items) do ids[#ids + 1] = r.id end
table.sort(ids)
check(table.concat(ids, ",") == "1529,2589" and ns.Stock.footer.texts.label:find("2 Gegenstände", 1, true), "Kategorie Handelswaren (mit Edelsteinen)")
mod.db.stockCat = "equip"; W.Refresh()
check(#ns.Stock.table.items == 1 and ns.Stock.table.items[1].id == 6129 and ns.Stock.footer.texts.label:find("1 Gegenstand", 1, true), "Kategorie Ausruestung, Einzahl in der Summe")
mod.db.stockCat = "other"; W.Refresh()
check(#ns.Stock.table.items == 0, "Kategorie Sonstiges: nichts")
mod.db.stockCat = "all"; W.Refresh()
-- Optionen: Twink loeschen
if mod.panel.scripts.OnShow then mod.panel.scripts.OnShow(mod.panel) end
local cl
for _, c in ipairs(mod.page.controls) do if c.list and c.list.columns[1].key == "name" then cl = c.list end end
for _, it in ipairs(cl:GetItems()) do if it.name == "Borin Stein" then cl:Select(it) end end
for _, c in ipairs(mod.page.controls) do if c.button and c.button.text == "Gewählten Charakter löschen" then c.button.scripts.OnClick() end end
check(popup and popup.data == "Borin Stein", "Loeschen fragt nach")
StaticPopupDialogs.PEON_LEDGER_DELETE_CHAR.OnAccept(nil, popup.data)
check(realm.chars["Borin Stein"] == nil and said("Daten von Borin Stein gelöscht"), "Twink geloescht")

-- ===== L3: Bewegungen =====
;(function()
local Mv = ns.Moves
local clock = 1000
GetTime = function() return clock end
local function settle() clock = clock + 2; local list = timers; timers = {}; for _, f in ipairs(list) do f() end end
local function bags() fire("BAG_UPDATE", 0); fire("BAG_UPDATE_DELAYED") end
timers = {}   -- alte, nie ausgefuehrte Zeitgeber der frueheren Tests verwerfen
Mv.pending = nil
Mv.open, Mv.closed, Mv.ctx = {}, {}, {}
realm.moves = {}
local function last() return realm.moves[#realm.moves] end
local function find(k, id) for i = #realm.moves, 1, -1 do local e = realm.moves[i] if e.k == k and (id == nil or e.id == id) then return e end end end
clock = clock + 100
-- Beute (Tagessumme)
fire("LOOT_OPENED")
BAGS[0][10] = { itemID = 2770, stackCount = 5, itemName = "Kupfererz", quality = 1 }
bags(); fire("LOOT_CLOSED"); settle()
check(#realm.moves == 1 and last().k == "loot" and last().id == 2770 and last().n == 5 and Mv.Label(last()) == "Beute", "Beute erfasst")
clock = clock + 100
fire("LOOT_OPENED"); BAGS[0][10].stackCount = 8; bags(); fire("LOOT_CLOSED"); settle()
check(#realm.moves == 1 and last().n == 8 and last().cnt == 2, "Beute: je Tag zusammengefasst")
clock = clock + 100
-- Gold aus Beute
fire("LOOT_OPENED"); money = money + 75; fire("PLAYER_MONEY"); fire("LOOT_CLOSED"); settle()
check(last().k == "loot" and last().m == 75 and not last().id, "Gold aus Beute")
clock = clock + 100
-- Taschen -> Bank: Umbuchung, kein Eintrag
BAGS[6] = {}
BAGS[-1] = { { itemID = 2589, stackCount = 20 } }   -- Bank wie beim letzten Besuch
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8); timers[#timers](); timers = {}
local n0 = #realm.moves
BAGS[0][10] = nil; BAGS[6][1] = { itemID = 2770, stackCount = 8 }
fire("BAG_UPDATE", 0); fire("BAG_UPDATE", 6); fire("BAG_UPDATE_DELAYED"); settle()
check(#realm.moves == n0 and me.places.bank.items[2770] == 8 and not me.places.bags.items[2770], "Taschen -> Bank: kein Zu- oder Abgang")
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 8)
clock = clock + 100
-- Haendler: verkaufen
fire("MERCHANT_SHOW")
BAGS[0][11] = { itemID = 4306, stackCount = 2, itemName = "Seidenstoff", quality = 1 }
Mv.paused = true; bags(); settle(); Mv.paused = nil   -- vorher schon in den Taschen
n0 = #realm.moves
C_Container.UseContainerItem(0, 11)
BAGS[0][11] = nil; money = money + 50; fire("PLAYER_MONEY"); bags(); settle()
local s1 = find("vendor", 4306)
check(#realm.moves == n0 + 1 and s1.n == -2 and s1.m == 50 and Mv.Label(s1) == "An Händler verkauft", "Haendler: Gegenstand verkauft, Erloes in derselben Zeile")
-- mehrere Stapel auf einmal: Gold nach Verkaufspreis zugeordnet
C_Item.GetItemInfo = function(id) local p = ({ [4306] = 25, [2589] = 10, [3576] = 7 })[id] return "x", nil, 1, 1, 1, "", "", 20, "", 1, p end
BAGS[0][11] = { itemID = 4306, stackCount = 3 }; BAGS[0][12] = { itemID = 3576, stackCount = 4 }
Mv.paused = true; bags(); settle(); Mv.paused = nil
n0 = #realm.moves
BAGS[0][11] = nil; money = money + 75; fire("PLAYER_MONEY")
BAGS[0][12] = nil; money = money + 28; fire("PLAYER_MONEY"); bags(); settle()
check(#realm.moves == n0 + 2 and find("vendor", 4306).m == 75 and find("vendor", 3576).m == 28, "Haendler: zwei Stapel, Gold je Gegenstand")
C_Item.GetItemInfo = nil
clock = clock + 100
-- Haendler: kaufen und reparieren
BuyMerchantItem(1, 1)
BAGS[0][11] = { itemID = 159, stackCount = 5, itemName = "Wasser", quality = 1 }
money = money - 100; fire("PLAYER_MONEY"); bags(); settle()
check(find("vendor", 159).n == 5 and find("vendor", 159).m == -100 and Mv.Label(find("vendor", 159)) == "Händler gekauft", "Haendler: gekauft, bezahlt in derselben Zeile")
clock = clock + 100
money = money - 300; fire("PLAYER_MONEY"); settle()
check(last().k == "repair" and last().m == -300 and Mv.Label(last()) == "Reparatur", "Haendler: Gold weg ohne Kauf = Reparatur")
fire("MERCHANT_CLOSED")
clock = clock + 100
-- Benutzen (Trank) und Zerstoeren
C_Container.UseContainerItem(0, 1)
BAGS[0][1].stackCount = BAGS[0][1].stackCount - 1; bags(); settle()
check(last().k == "use" and last().id == 118 and last().n == -1 and Mv.Label(last()) == "Benutzt", "Trank benutzt")
clock = clock + 100
C_Container.PickupContainerItem(0, 11); DeleteCursorItem()
BAGS[0][11] = nil; bags(); settle()
check(last().k == "destroy" and last().id == 159 and last().n == -5 and Mv.Label(last()) == "Zerstört", "Zerstoert")
clock = clock + 100
-- Herstellen
fire("TRADE_SKILL_SHOW")
C_TradeSkillUI.CraftRecipe(2657, 1)
BAGS[0][12] = { itemID = 2840, stackCount = 1, itemName = "Kupferbarren", quality = 1 }
BAGS[0][13] = { itemID = 2770, stackCount = 1 }
Mv.paused = true; bags(); settle(); Mv.paused = nil
C_TradeSkillUI.CraftRecipe(2657, 1)
BAGS[0][12].stackCount = 2; BAGS[0][13] = nil; bags(); settle()
check(find("craft", 2840).n == 1 and Mv.Label(find("craft", 2840)) == "Hergestellt" and find("craft", 2840).x == "Kupferbarren", "Herstellen: Ergebnis")
check(find("craft", 2770).n == -1 and Mv.Label(find("craft", 2770)) == "Material verbraucht", "Herstellen: Material")
fire("TRADE_SKILL_CLOSE")
clock = clock + 100
-- Quest
fire("QUEST_TURNED_IN", 1, 100, 500)
money = money + 500; fire("PLAYER_MONEY"); settle()
check(last().k == "quest" and last().m == 500 and Mv.Label(last()) == "Quest-Belohnung", "Quest: Gold")
clock = clock + 100
-- Auktionshaus: einstellen (Umbuchung + Gebuehr), verkauft
fire("AUCTION_HOUSE_SHOW")
fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
BAGS[0][12] = nil; money = money - 20; fire("PLAYER_MONEY"); bags(); settle()
check(find("posted", 2840).n == -2 and Mv.Side(find("posted", 2840)) == "move", "Auktion eingestellt: Umbuchung")
check(last().k == "ahfee" and last().m == -20 and last().id == 2840, "Auktion eingestellt: Gebuehr, ab 0.7 mit Gegenstand")
me.places.auctions = { t = 1, items = {}, soldItems = {} }   -- keine alten Auktionen aus den frueheren Tests
n0 = #realm.moves
local owned = { { itemKey = { itemID = 2840 }, quantity = 2, status = 0 } }
C_AuctionHouse = { QueryOwnedAuctions = function() end, GetNumOwnedAuctions = function() return #owned end, GetOwnedAuctionInfo = function(i) return owned[i] end }
fire("OWNED_AUCTIONS_UPDATED"); settle()
check(#realm.moves == n0 and me.places.auctions.items[2840] == 2, "Auktion erscheint unter Auktionen: kein weiterer Eintrag")
owned[1].status = 1
fire("OWNED_AUCTIONS_UPDATED"); settle()
check(last().k == "ahsold" and last().id == 2840 and last().n == -2 and Mv.Label(last()) == "Auktion verkauft", "Auktion verkauft (Abgang)")
-- abgelaufene Auktion: Umbuchung
owned = { { itemKey = { itemID = 2589 }, quantity = 3, status = 0 } }
fire("OWNED_AUCTIONS_UPDATED"); settle()
owned = {}
fire("OWNED_AUCTIONS_UPDATED"); settle()
check(last().k == "ahsold", "Auktion verschwunden, nicht verkauft: kein Eintrag (Brief zaehlt)")
-- Kauf im Auktionshaus: Gold
money = money - 1000; fire("PLAYER_MONEY"); fire("COMMODITY_PURCHASE_SUCCEEDED"); settle()
check(last().k == "ahbuy" and last().m == -1000, "Auktion gekauft: Gold")
fire("AUCTION_HOUSE_CLOSED")
clock = clock + 100
-- Post: neue Briefe beim Oeffnen (gekauft, zurueck, Erloes)
inbox = { { nil, nil, "Auktionshaus", "Auktion gewonnen: Jade", 0, 0, 29, 1 },
          { nil, nil, "Auktionshaus", "Auktion abgelaufen: Leinenstoff", 0, 0, 29, 1 },
          { nil, nil, "Auktionshaus", "Auktion erfolgreich: Kupferbarren", 4500, 0, 29, nil } }
GetInboxItem = function(i, a) if a ~= 1 then return end if i == 1 then return "Jade", 1529, 1, 2, 2 elseif i == 2 then return "Leinenstoff", 2589, 1, 3, 1 end end
GetInboxInvoiceInfo = function(i) if i == 1 then return "buyer", "Jade", "Bob", 0, 1000, 0, 0 elseif i == 3 then return "seller", "Kupferbarren", "Bob", 0, 5000, 100, 600, nil, nil, nil, 2 end end
me.auctionsBefore = me.places.auctions.items[2589]
me.places.auctions.items[2589] = 3   -- Auktionshaus nicht mehr besucht: steht noch als Auktion da
me.places.mail = { t = 1, items = {} }   -- Postfach beim letzten Besuch leer
n0 = #realm.moves
local jadeBefore = I.Count(1529).total
fire("MAIL_SHOW"); fire("MAIL_INBOX_UPDATE"); settle()
check(#realm.moves == n0 and I.Count(1529).total == jadeBefore, "ab 0.7.2: Briefkasten geoeffnet - noch kein Zugang, Post zaehlt nicht zum Bestand")
TakeInboxItem(1, 1)
inbox[1][8] = nil; table.remove(inbox, 1)
GetInboxItem = function(i, a) if a == 1 and i == 1 then return "Leinenstoff", 2589, 1, 3, 1 end end
GetInboxInvoiceInfo = function(i) if i == 2 then return "seller", "Kupferbarren", "Bob", 0, 5000, 100, 600, nil, nil, nil, 2 end end
BAGS[0][12] = { itemID = 1529, stackCount = 2 }
fire("MAIL_INBOX_UPDATE"); bags(); settle()
local jade = find("ahbuy", 1529)
check(#realm.moves == n0 and jade and jade.n == 2 and jade.m == -1000 and Mv.Label(jade) == "Auktion gekauft", "genommen: gekaufte Auktion als Zugang, an der Goldzeile des Kaufs")
-- abgelaufene Auktion nehmen: Umbuchung
TakeInboxItem(1, 1)
table.remove(inbox, 1)
GetInboxItem = function() end
GetInboxInvoiceInfo = function(i) if i == 1 then return "seller", "Kupferbarren", "Bob", 0, 5000, 100, 600, nil, nil, nil, 2 end end
BAGS[0][15] = { itemID = 2589, stackCount = 3 }
fire("MAIL_INBOX_UPDATE"); bags(); settle()
check(last().k == "ahreturn" and last().id == 2589 and last().n == 3 and find("mail", 2589) == nil and not me.places.auctions.items[2589], "genommen: abgelaufene Auktion = Umbuchung, nicht mehr unter Auktionen")
TakeInboxMoney(1)
money = money + 4500; fire("PLAYER_MONEY"); settle()
check(last().k == "ahsold" and last().m == 4500 and last().x == "Kupferbarren ×2", "Erloes aus der Post: Auktion verkauft mit Gegenstand")
-- "Alle öffnen": mehrere Erloese kurz hintereinander, jeder Betrag bekommt seinen Brief
inbox = { { nil, nil, "Auktionshaus der Allianz", "Auktion erfolgreich: A", 604, 0, 29, nil },
          { nil, nil, "Auktionshaus der Allianz", "Auktion erfolgreich: B", 157, 0, 29, nil },
          { nil, nil, "Auktionshaus der Allianz", "Auktion erfolgreich: C", 9100, 0, 29, nil } }
GetInboxItem = function() end
GetInboxInvoiceInfo = function(i) return "seller", ({ "Erz A", "Erz B", "Bauplan C" })[i], "Bob", 0, 1, 0, 0, nil, nil, nil, 1 end
fire("MAIL_INBOX_UPDATE"); settle()
n0 = #realm.moves
AutoLootMailItem(1); AutoLootMailItem(2); AutoLootMailItem(3)
money = money + 9100; fire("PLAYER_MONEY"); money = money + 604; fire("PLAYER_MONEY"); money = money + 157; fire("PLAYER_MONEY")
settle()
local xs = {} for i = n0 + 1, #realm.moves do xs[realm.moves[i].m] = realm.moves[i].x end
check(#realm.moves == n0 + 3 and xs[604] == "Erz A" and xs[157] == "Erz B" and xs[9100] == "Bauplan C", "Alle öffnen: jeder Erloes mit eigenem Gegenstand")
-- zwei Erloese in EINER Goldaenderung (Spiel meldet nur eine): je Brief ein Eintrag
inbox = { { nil, nil, "Auktionshaus der Allianz", "Auktion erfolgreich: W", 167, 0, 29, nil },
          { nil, nil, "Auktionshaus der Allianz", "Auktion erfolgreich: K", 3590, 0, 29, nil } }
GetInboxInvoiceInfo = function(i) return "seller", ({ "Wels", "Kruemel" })[i], "Bob", 0, 1, 0, 0, nil, nil, nil, i == 1 and 7 or 1 end
fire("MAIL_INBOX_UPDATE"); settle()
n0 = #realm.moves
AutoLootMailItem(1); AutoLootMailItem(2)
money = money + 3757; fire("PLAYER_MONEY"); settle()
xs = {} for i = n0 + 1, #realm.moves do xs[realm.moves[i].m] = realm.moves[i] end
check(#realm.moves == n0 + 2 and xs[167] and xs[167].x == "Wels ×7" and xs[167].q == 7 and xs[3590] and xs[3590].x == "Kruemel", "zwei Erloese in einer Goldaenderung: aufgeteilt (167 + 3590 = 3757)")
-- Post: Taschen und Postfach kommen in getrennten Schueben (Server langsam) -> keine Eintraege
inbox = { { nil, nil, "Auktionshaus der Allianz", "Auktion gewonnen: Pfeil", 0, 0, 29, 1 } }
GetInboxItem = function(i, a) if i == 1 and a == 1 then return "Pfeil", 3464, 1, 200, 1 end end
GetInboxInvoiceInfo = function(i) return "buyer", "Pfeil", "Bob", 600, 1, 0, 0 end
fire("MAIL_INBOX_UPDATE"); settle()
check(find("ahbuy", 3464) == nil, "Pfeile noch im Briefkasten: kein Eintrag")
n0 = #realm.moves
AutoLootMailItem(1)
inbox = {}; fire("MAIL_INBOX_UPDATE"); settle()             -- Postfach zuerst leer ...
BAGS[0][16] = { itemID = 3464, stackCount = 200 }; bags(); settle()   -- ... Taschen erst danach
check(#realm.moves == n0 + 1 and last().k == "ahbuy" and last().id == 3464 and last().n == 200, "Post -> Taschen in getrennten Schueben: ein Zugang beim Nehmen")
-- umgekehrt: Taschen zuerst, Postfach danach
inbox = { { nil, nil, "Auktionshaus der Allianz", "Auktion gewonnen: Pfeil", 0, 0, 29, 1 } }
fire("MAIL_INBOX_UPDATE"); settle()
n0 = #realm.moves
AutoLootMailItem(1)
BAGS[0][16].stackCount = 400; bags(); settle()
inbox = {}; fire("MAIL_INBOX_UPDATE"); settle()
check(#realm.moves == n0 + 1 and last().k == "ahbuy" and last().n == 200, "Taschen -> Post in getrennten Schueben: ein Zugang")
-- Auktion zurueck: Brief vom Auktionshaus mit Gegenstand, ohne Kaufrechnung, unbekannter Betreff
me.places.auctions.items[6308] = 7
inbox = { { nil, nil, "Auktionshaus der Allianz", "Auktion beendet: Wels", 0, 0, 29, 1 } }
GetInboxItem = function(i, a) if i == 1 and a == 1 then return "Wels", 6308, 1, 7, 1 end end
GetInboxInvoiceInfo = function() end
n0 = #realm.moves
fire("MAIL_INBOX_UPDATE"); settle()
check(#realm.moves == n0, "Auktion zurueck im Briefkasten: noch kein Eintrag")
AutoLootMailItem(1)
BAGS[1][16] = { itemID = 6308, stackCount = 7 }; fire("BAG_UPDATE", 1); fire("BAG_UPDATE_DELAYED"); settle()
check(#realm.moves == n0 + 1 and last().k == "ahreturn" and last().n == 7 and Mv.Side(last()) == "move" and Mv.Label(last()) == "Auktion zurück" and not me.places.auctions.items[6308], "Auktionshaus-Brief mit Gegenstand ohne Rechnung = Auktion zurueck (Umbuchung)")
check(PeonLedgerDB.mailLog and #PeonLedgerDB.mailLog >= 3 and PeonLedgerDB.mailLog[1]:find("Rechnung", 1, true), "Brief-Protokoll (Betreff, Rechnung)")
inbox = {}; fire("MAIL_INBOX_UPDATE"); settle()
-- Post an eigenen Twink: Umbuchung, beim Twink unter Post
realm.chars["Borin Stein"] = { places = {}, start = { places = {} } }
sendMoney = 1000
SendMail("Borin", "Erz", "")
BAGS[0][12] = nil; money = money - 1030; fire("PLAYER_MONEY"); bags(); settle()
local tw = find("twink", 1529)
check(tw and tw.n == -2 and tw.x == "Borin Stein" and Mv.Label(tw) == "Post an Twink" and Mv.Side(tw) == "move", "Post an Twink: Umbuchung")
check(realm.chars["Borin Stein"].places.transit.items[1529] == 2 and realm.chars["Borin Stein"].places.transit.money == 1000, "Twink hat es unter Unterwegs (bis zum Abholen)")
local gch for _, ch in ipairs(I.Count(1529).chars) do if ch.name == "Borin Stein" then gch = ch end end
check(gch and gch.places.transit == 2, "unterwegs zaehlt zum Bestand des Twinks")
check(last().k == "twink" and last().m == -1030, "Gold an Twink")
fire("MAIL_CLOSED")
clock = clock + 100
-- Sonstiges
BAGS[0][14] = { itemID = 6948, stackCount = 1 }
bags(); settle()
check(last().k == "other" and last().n == 1 and Mv.Label(last()) == "Sonstiger Zugang", "ohne Zusammenhang: sonstiger Zugang")
BAGS[0][14] = nil; bags(); settle()
check(last().k == "other" and last().n == -1 and Mv.Label(last()) == "Verbraucht/sonstiges", "ohne Zusammenhang: verbraucht/sonstiges")
-- Anlegen ohne Meldung PLAYER_EQUIPMENT_CHANGED: Ausruestung wird mit den Taschen gelesen
BAGS[0][15] = { itemID = 7000, stackCount = 1 }
Mv.paused = true; bags(); settle(); Mv.paused = nil
n0 = #realm.moves
local origInv = GetInventoryItemID
GetInventoryItemID = function(u, slot) if slot == 5 then return 6129 elseif slot == 6 then return 7000 end end
BAGS[0][15] = nil; bags(); settle()
check(#realm.moves == n0 and me.places.equip.items[7000] == 1, "Anlegen: Taschen -> Ausruestung ohne Eintrag")
GetInventoryItemID = origInv
Mv.paused = true; bags(); settle(); Mv.paused = nil
-- Einloggen: keine Bewegungen
n0 = #realm.moves
BAGS[0][14] = { itemID = 6948, stackCount = 1 }
I.OnLogin()
check(#realm.moves == n0 and me.places.bags.items[6948] == 1, "Einloggen: Stand gelesen, keine Bewegung")
BAGS[0][9] = { itemID = 765, stackCount = 18 }; bags(); settle()
check(#realm.moves == n0 and me.places.bags.items[765] == 18, "kurz nach dem Einloggen nachgelieferte Gegenstaende: keine Bewegung")
clock = clock + 30
BAGS[0][9] = nil; bags(); settle()
check(#realm.moves == n0 + 1 and last().id == 765, "danach wieder erfasst")
-- ===== ab 0.6: bekannte Luecken =====
-- Haendler: mehrere Stapel gekauft, EIN Goldbetrag -> nach Haendlerwert aufgeteilt
C_Item.GetItemInfo = function(id) local p = ({ [4306] = 25, [3576] = 7 })[id] return "x", nil, 1, 1, 1, "", "", 20, "", 1, p end
fire("MERCHANT_SHOW")
BuyMerchantItem(1, 2)
n0 = #realm.moves
BAGS[0][11] = { itemID = 4306, stackCount = 2 }; BAGS[0][12] = { itemID = 3576, stackCount = 4 }
money = money - 156; fire("PLAYER_MONEY"); bags(); settle()
local b1, b2 = find("vendor", 4306), find("vendor", 3576)
check(#realm.moves == n0 + 2 and b1.n == 2 and b2.n == 4 and b1.m == -100 and b2.m == -56, "Haendler: zwei Stapel gekauft, Gold aufgeteilt (" .. tostring(b1.m) .. "/" .. tostring(b2.m) .. ")")
fire("MERCHANT_CLOSED")
C_Item.GetItemInfo = nil
BAGS[0][11], BAGS[0][12] = nil, nil
Mv.paused = true; bags(); settle(); Mv.paused = nil
clock = clock + 100
-- Erloes ohne Rechnung (Daten noch nicht geladen): Gegenstand aus dem Betreff, Menge aus dem Verkauf
fire("AUCTION_HOUSE_SHOW")
me.places.auctions = { t = 1, items = {}, soldItems = {} }
local owned2 = { { itemKey = { itemID = 2840 }, quantity = 2, status = 0, buyoutAmount = 1000 } }
C_AuctionHouse.GetNumOwnedAuctions = function() return #owned2 end
C_AuctionHouse.GetOwnedAuctionInfo = function(i) return owned2[i] end
fire("OWNED_AUCTIONS_UPDATED"); settle()
owned2[1].status = 1
fire("OWNED_AUCTIONS_UPDATED"); settle()
local soldItem = last()
check(soldItem.k == "ahsold" and soldItem.id == 2840 and soldItem.n == -2 and soldItem.p == 1000, "Auktion verkauft: Preis je Stueck gemerkt")
fire("AUCTION_HOUSE_CLOSED"); clock = clock + 100
inbox = { { nil, nil, "Auktionshaus der Allianz", "Rufe Daten ab", 1900, 0, 29, nil } }
GetInboxItem = function() end
GetInboxInvoiceInfo = function() end
fire("MAIL_SHOW"); fire("MAIL_INBOX_UPDATE"); settle()
TakeInboxMoney(1)
money = money + 1900; fire("PLAYER_MONEY"); settle()
check(last().k == "ahsold" and last().m == 1900 and last().id == 2840 and last().q == 2 and last().est and soldItem.paid, "Erloes ohne Rechnung: Gegenstand und Menge vom Verkauf zugeordnet")
-- Betreff mit Namen, Rechnung fehlt: Gegenstand ueber den Namen
I.Remember(2841, "Bronzebarren", 1)
inbox = { { nil, nil, "Auktionshaus der Allianz", "Auktion erfolgreich: Bronzebarren", 333, 0, 29, nil } }
fire("MAIL_INBOX_UPDATE"); settle()
TakeInboxMoney(1)
money = money + 333; fire("PLAYER_MONEY"); settle()
check(last().k == "ahsold" and last().id == 2841, "Erloes ohne Rechnung: Gegenstand aus dem Betreff")
inbox = {}; fire("MAIL_INBOX_UPDATE"); settle()
fire("MAIL_CLOSED")
clock = clock + 100
-- ab 0.7: Nachnahme - bezahlter Betrag als Kosten am Gegenstand
inbox = { { nil, nil, "Bob Baum", "Ware", 0, 250, 29, 1 } }
GetInboxItem = function(i, a) if i == 1 and a == 1 then return "Ware", 5005, 1, 2, 1 end end
GetInboxInvoiceInfo = function() end
fire("MAIL_SHOW"); fire("MAIL_INBOX_UPDATE"); settle()
n0 = #realm.moves
TakeInboxItem(1, 1)
BAGS[0][13] = { itemID = 5005, stackCount = 2 }
money = money - 250; fire("PLAYER_MONEY")
inbox = {}; fire("MAIL_INBOX_UPDATE"); bags(); settle()
local codItem = find("mail", 5005)
check(codItem and codItem.n == 2 and codItem.paid == 250 and last().m == -250 and last().k == "mail", "Nachnahme: Gegenstand mit bezahltem Betrag, Gold als Post")
BAGS[0][13] = nil
Mv.paused = true; bags(); settle(); Mv.paused = nil
fire("MAIL_CLOSED")
clock = clock + 100
-- Auktion gekauft: Gold beim Kauf und Gegenstand aus der Post in EINER Zeile
fire("AUCTION_HOUSE_SHOW")
Mv.Note("ahbuyitem", { id = 2772, qty = 5 })   -- mitgelesen: C_AuctionHouse.StartCommoditiesPurchase(2772, 5)
money = money - 500; fire("PLAYER_MONEY"); fire("COMMODITY_PURCHASE_SUCCEEDED"); settle()
local buy = last()
check(buy.k == "ahbuy" and buy.m == -500 and buy.id == 2772 and buy.q == 5, "Auktion gekauft: Gegenstand des Kaufs vermerkt")
fire("AUCTION_HOUSE_CLOSED")
clock = clock + 100
n0 = #realm.moves
inbox = { { nil, nil, "Auktionshaus der Allianz", "Auktion gewonnen: Eisenerz", 0, 0, 29, 1 } }
GetInboxItem = function(i, a) if i == 1 and a == 1 then return "Eisenerz", 2772, 1, 5, 1 end end
GetInboxInvoiceInfo = function(i) return "buyer", "Eisenerz", "Bob", 0, 500, 0, 0 end
fire("MAIL_SHOW"); fire("MAIL_INBOX_UPDATE"); settle()
AutoLootMailItem(1)
BAGS[1][15] = { itemID = 2772, stackCount = 5 }; fire("BAG_UPDATE", 1)
inbox = {}; fire("MAIL_INBOX_UPDATE"); fire("BAG_UPDATE_DELAYED"); settle()
check(#realm.moves == n0 and buy.n == 5 and buy.id == 2772, "Gegenstand aus der Post (beim Nehmen) an den Kauf gehaengt (keine eigene Zeile)")
fire("MAIL_CLOSED")
clock = clock + 100
-- Inventur neu (dieser Charakter): Unterschiede als Korrektur
Mv.paused = true
BAGS[0][13] = { itemID = 4306, stackCount = 3 }   -- ohne Meldung des Spiels
money = money + 11
Mv.paused = nil
n0 = #realm.moves
local p0 = ns.Book.Collect("all", false).profit
local nfix = Mv.Recount()
local fx = find("fix", 4306)
check(nfix == 2 and fx and fx.n == 3 and Mv.Side(fx) == "move" and Mv.Label(fx) == "Korrektur +" and last().m == 11, "Inventur neu: Gegenstand und Gold als Korrektur")
check(ns.Book.Collect("all", false).profit == p0 and #realm.moves == n0 + 2, "Korrektur zaehlt nicht als Gewinn")
BAGS[0][13] = nil
Mv.paused = true; bags(); settle(); Mv.paused = nil
-- Verlauf: Filter nach Art
ns.Window.Select("history")
mod.db.historyKind = "fix"; ns.History.Refresh()
local onlyFix = true for _, r in ipairs(ns.History.table.items) do if r.e.k ~= "fix" then onlyFix = false end end
local function nEnt(rows) local n = 0 for _, r in ipairs(rows) do n = n + (r.grp and #r.grp.list or 1) end return n end
check(onlyFix and nEnt(ns.History.table.items) == 2 and #ns.History.table.items == 1, "Verlauf: nur Korrekturen (ab 0.8.1 eine Zeile)")
mod.db.historyKind = "ah"; ns.History.Refresh()
local onlyAh = #ns.History.table.items > 0
for _, r in ipairs(ns.History.table.items) do if not Mv.InGroup(r.e.k, "ah") then onlyAh = false end end
check(onlyAh, "Verlauf: nur Auktionshaus")
mod.db.historyKind = "all"
-- Verlauf
ns.Window.Select("history")
local rows = ns.History.table.items
local nEntries = 0 for _, r in ipairs(rows) do nEntries = nEntries + (r.grp and #r.grp.list or 1) end
check(nEntries == #realm.moves and (rows[1].e == realm.moves[#realm.moves] or (rows[1].grp and rows[1].grp.list[1] == realm.moves[#realm.moves])), "Verlauf: alle Eintraege (Herstellen zusammengefasst), neueste zuerst")
ns.History.searchBox:SetText("kupfer"); ns.History.searchBox.scripts.OnTextChanged(ns.History.searchBox, true)
rows = ns.History.table.items
check(#rows >= 3, "Verlauf: Suche (" .. #rows .. ")")
ns.History.searchBox:SetText(""); ns.History.searchBox.scripts.OnTextChanged(ns.History.searchBox, true)
ns.History.moves:SetChecked(false); ns.History.moves.scripts.OnClick(ns.History.moves)
local nm = 0 for _, r in ipairs(ns.History.table.items) do if r.side == "move" then nm = nm + 1 end end
check(nm == 0 and mod.db.historyMoves == false, "Verlauf: Umbuchungen ausblenden")
ns.History.moves:SetChecked(true); ns.History.moves.scripts.OnClick(ns.History.moves)
local col for _, c in ipairs(ns.History.table.o.columns) do if c.key == "m" then col = c end end
check(col.format(nil, { m = -1030 }):find("-", 1, true), "Verlauf: Gold mit Vorzeichen")
check(ns.History.Unsure({ e = { k = "other" } }) and not ns.History.Unsure({ e = { k = "loot" } }), "0.14: unsichere Zeilen (sonstiges) markiert")
-- Alte Eintraege -> Wochensummen
table.insert(realm.moves, 1, { t = os.time() - 100 * 86400, c = "Mirel Dorna", k = "loot", id = 2770, n = 4 })
local moved = Mv.Prune()
local wk = realm.weeks and next(realm.weeks)
check(moved == 1 and wk and realm.weeks[wk]["Mirel Dorna|loot|2770"].n == 4, "nach 90 Tagen: Wochensumme")
-- Buch zuruecksetzen (Optionen): Verlauf weg, aktueller Stand = neuer Anfangsbestand
check(#realm.moves > 0, "vor dem Zuruecksetzen: Verlauf vorhanden")
BAGS[0][9] = { itemID = 2318, stackCount = 6 }
popup = nil
for _, c in ipairs(mod.page.controls) do if c.button and c.button.text == "Buch zurücksetzen" then c.button.scripts.OnClick() end end
check(popup and popup.name == "PEON_LEDGER_RESET_BOOK", "Zuruecksetzen fragt nach")
StaticPopupDialogs.PEON_LEDGER_RESET_BOOK.OnAccept()
check(#realm.moves == 0 and realm.weeks == nil and said("Buch von Classic Beta PvE zurückgesetzt"), "Verlauf und Wochensummen geloescht")
check(me.places.bags.items[2318] == 6 and me.start.places.bags.items[2318] == 6 and me.start.money == money, "aktueller Stand neu gelesen und als Anfangsbestand")
check(realm.chars["Borin Stein"].start.places.transit.items[1529] == 2, "Twinks: letzter Stand als Anfangsbestand")
BAGS[0][9] = nil
GetTime = function() return 1 end
end)()

-- ===== L5: Buch und Gegenstaende =====
;(function()
local Mv, Bk = ns.Moves, ns.Book
realm.moves = {}
-- ohne Anfangsbestand: Verkaeufe aus dem Startbestand waeren ab 0.14.3 Sondereinnahmen
local keepStart, keepBase = realm.chars["Mirel Dorna"].start, realm.lotBase
realm.chars["Mirel Dorna"].start = { t = 0, places = {} }
realm.lotBase = nil
ns.Cost.Invalidate()
local now = os.time()
local function add(dt, k, id, n, m, extra) local e = { t = now - dt, c = "Mirel Dorna", k = k, id = id, n = n, m = m } for a, b in pairs(extra or {}) do e[a] = b end realm.moves[#realm.moves + 1] = e return e end
add(100, "ahsold", 2589, nil, 900, { q = 3, cut = 50 })     -- 3 Stueck verkauft, 9s erhalten
add(200, "ahsold", 2589, nil, 300, { q = 1, cut = 15 })
add(300, "ahreturn", 2589, 2, nil)                        -- 2 Stueck zurueck
add(300, "posted", 2589, -6, nil)                         -- Umbuchung: zaehlt nicht
add(400, "ahfee", nil, nil, -60)
add(500, "ahbuy", nil, nil, -1000)
add(600, "vendor", 4306, -2, 50)
add(700, "loot", nil, nil, 75, { d = "x" })
add(800, "twink", nil, nil, -500, { x = "Borin Stein" })  -- Umbuchung: zaehlt nicht
add(10 * 86400, "vendor", 159, 5, -100)                   -- aelter als 7 Tage
add(900, "repair", nil, nil, -300, { c = "Borin Stein" })
realm.moves[#realm.moves].c = "Borin Stein"
local r = Bk.Collect("d7")
check(r.inc == 900 + 300 + 50 + 75 and r.exp == 1000 + 300 and r.fee == 60, "Buch 7 Tage: Einnahmen, Ausgaben, Gebuehren (Umbuchungen zaehlen nicht)")
check(r.profit == 1325 - 1300 - 60 and r.cut == 65, "Gewinn und Anteil des Auktionshauses")
check(r.kinds.ahsold.inc == 1200 and r.kinds.vendor.inc == 50 and r.kinds.vendor.exp == 0 and not r.kinds.twink, "nach Art aufgeteilt")
local r30 = Bk.Collect("d30")
check(r30.kinds.vendor.exp == 100 and r30.items[159].nin == 5, "30 Tage: aelterer Einkauf dabei")
local rme = Bk.Collect("d7", true)
check(rme.exp == 1000 and not rme.kinds.repair, "nur dieser Charakter")
local it = r.items[2589]
check(it.sold == 4 and it.back == 2 and it.inc == 1200, "Gegenstand: verkauft, zurueck, Einnahmen")
local rate, sold, back = Bk.SellRate(2589)
check(math.abs(rate - 4 / 6) < 0.001 and sold == 4 and back == 2, "Verkaufsquote 4 von 6")
check(Bk.SellRate(4306) == nil, "Verkaufsquote erst ab 3 Stueck")
check(math.abs(mod:SellRate(2589) - 4 / 6) < 0.001, "Schnittstelle fuer Broker: mod:SellRate")
-- Wochensummen bei "Alles"
realm.weeks = { ["2026-20"] = { ["Mirel Dorna|vendor|4306"] = { n = -10, m = 400 } } }
local ra = Bk.Collect("all")
check(ra.kinds.vendor.inc == 450 and ra.items[4306].nout == 12, "Alles: mit Wochensummen")
realm.weeks = nil
-- Reiter (ab 0.14: Summen links, Ansichten Nach Art und Nach Gegenstand)
ns.Window.Select("book")
local rows = Bk.book.kinds.items
check(#rows >= 5 and Bk.book.lines.profit.label.text == "Gesamtgewinn" and Bk.book.lines.trade.label.text == "Handelsgewinn", "Reiter Buch: Arten, Handelsgewinn und Gesamtgewinn")
mod.db.bookPeriod = "d30"; ns.Window.Refresh()
check(Bk.book.res.kinds.vendor.exp == 100, "Zeitraum 30 Tage")
mod.db.bookPeriod = "d7"; mod.db.bookChar = "Mirel Dorna"; ns.Window.Refresh()
check(Bk.book.res.exp == 1000 and not Bk.book.res.kinds.repair, "Buch: nur ein Charakter")
mod.db.bookChar = "*"
Bk.book.view:Select("items")
rows = Bk.book.items.items
local row for _, x in ipairs(rows) do if x.id == 2589 then row = x end end
check(mod.db.bookView == "items" and Bk.book.itemsPanel:IsShown() ~= false, "Ansicht Nach Gegenstand")
check(row and row.sold == 4 and row.back == 2 and math.abs(row.rate - 4 / 6) < 0.001 and row.sellN == 4, "Nach Gegenstand: verkauft, zurueck, Quote")
check(row.avg == 316, "Ø Verkaufspreis je Stueck: (950 + 315) / 4 = 316 (" .. tostring(row.avg) .. ")")
local r159 for _, x in ipairs(Bk.ItemRows(Bk.Collect("d30"), nil, nil)) do if x.id == 159 then r159 = x end end
check(r159 and r159.buyN == 5 and r159.buyAvg == 20, "Nach Gegenstand: gekauft und Ø Einkauf")
Bk.book.search = "zzz"; ns.Window.Refresh()
check(#Bk.book.items.items == 0, "Nach Gegenstand: Suche")
Bk.book.search = nil
Bk.book.view:Select("kinds")
-- Erloes aus Rechnung: Gegenstand ueber den Namen gefunden
check(ns.Inventory.FindItemID("Schwacher Heiltrank") == 118, "Gegenstand nach Namen")
mod.db.bookPeriod = "d7"
realm.chars["Mirel Dorna"].start, realm.lotBase = keepStart, keepBase
ns.Cost.Invalidate()
end)()

-- ===== L6: Zusammenspiel mit Peon_Broker =====
;(function()
local I = ns.Inventory
local me = realm.chars["Mirel Dorna"]
realm.chars["Borin Stein"] = { class = "MAGE", money = 50000, places = { bags = { t = 1, items = { [2589] = 5 } }, bank = { t = 1, items = { [2589] = 7 } },
  transit = { t = 1, items = { [2589] = 2 } }, mail = { t = 1, items = { [2589] = 50 }, money = 300 }, auctions = { t = 1, items = { [2589] = 9 } }, equip = { t = 1, items = { [2589] = 1 } } }, start = { places = {} } }
realm.account.places.warband = { t = 1, items = { [2589] = 4 } }
I.Changed()
check(mod:StockOthers(2589) == 5 + 7 + 2 + 4, "Vorrat der Twinks fuer Broker: Taschen, Bank, unterwegs, Accountbank (ohne Briefkasten, Auktionen, Angelegtes)")
-- ohne Broker: kein Vermoegen
ns.Window.Select("overview")
local rows = ns.Overview.table.items
local g for _, r in ipairs(rows) do if r.name == "Borin Stein" then g = r end end
check(g and g.worth == nil and ns.Overview.TileText("worth"):find("Peon_Broker", 1, true), "ohne Broker: kein Vermoegen, Hinweis in der Kachel")
-- Broker (nachgebaut): 10c je Stueck
Peon.modules.broker = { ItemValue = function(_, id, n) if id == 2589 then return 10 * n end return nil end }
ns.Overview.Refresh()
rows = ns.Overview.table.items
for _, r in ipairs(rows) do if r.name == "Borin Stein" then g = r end end
check(g.worth == 50000 + 10 * (5 + 7 + 2 + 9) and g.itemsValue == 230, "Vermoegen: Gold + Gegenstaende (ab 0.7.1 ohne Post-Gold, ohne Angelegtes)")
check(ns.Overview.TileText("worth"):find("Waren", 1, true), "Vermoegen aller Charaktere in der Kachel: " .. ns.Overview.TileText("worth"))
-- ab 0.7.3: angelegte Ausruestung zaehlt immer, Gebundenes (auch Angelegtes) nur mit dem Haendlerpreis
local origGII = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id) local p = ({ [2589] = 3 })[id] return "x", nil, 1, 1, 1, "", "", 20, "", 1, p end
realm.chars["Borin Stein"].places.bags.bound = { [2589] = 2 }
realm.chars["Borin Stein"].places.bank.bound = { [2589] = 99 }   -- mehr gebunden als da: hoechstens alle
I.Changed()
ns.Overview.Refresh()
for _, r in ipairs(ns.Overview.table.items) do if r.name == "Borin Stein" then g = r end end
check(g.worth == 50000 + 10 * (3 + 2 + 9) + 3 * (2 + 7 + 1), "Vermoegen: Gebundenes und Angelegtes zum Haendlerpreis (" .. tostring(g.worth) .. ")")
check(ns.Worth(2589, 4, 4) == 12 and ns.Worth(2589, 4, 0) == 40 and ns.Worth(2589, 4, 1) == 33, "ns.Worth: gebunden Haendlerpreis, sonst Broker")
check(ns.Worth(4306, 2, 0) == nil and ns.Worth(4306, 2, 2) == 0, "ns.Worth: ohne Brokerpreis nil, nur gebunden ohne Haendlerpreis 0")
ns.Window.Select("stock")
local sv for _, r in ipairs(ns.Stock.table.items) do if r.id == 2589 then sv = r end end
local e = ns.Stock.Collect("*", "all")[2589]
check(sv and e.bound == 2 + 7 + 1 and sv.value == 10 * (sv.total - e.bound) + 3 * e.bound and ns.Stock.Status():find("Marktwert", 1, true), "Bestand: Spalte Marktwert (Gebundenes Haendlerpreis) und Summe")
check(sv.startAll and sv.open == nil and ns.Stock.footer.texts.open ~= nil, "0.14.5: nur Startbestand: Kosten 0 (Start), kein offener Gewinn")
-- Taschen lesen: gebundene Stueck werden gemerkt
BAGS[0][9] = { itemID = 6129, stackCount = 1, isBound = true }
I.quiet = true; I.ScanBags(); I.quiet = false
check(me.places.bags.bound and me.places.bags.bound[6129] == 1 and not me.places.bags.bound[118], "Taschen: gebundene Stueck erfasst")
BAGS[0][9] = nil
I.quiet = true; I.ScanBags(); I.quiet = false
C_Item.GetItemInfo = origGII
realm.chars["Borin Stein"].places.bags.bound = nil
realm.chars["Borin Stein"].places.bank.bound = nil
ns.Window.Select("overview")
Peon.modules.broker = nil
realm.chars["Borin Stein"] = nil
realm.account.places.warband = nil
I.Changed()
end)()

-- ===== 0.7: Zuordnen (Kosten nach "aelteste zuerst", Beispiel aus Peon_Ledger_Zuordnen.md) =====
mod.db.costOrder = "fifo"   -- ab 0.14.3 einstellbar, diese Beispiele rechnen aelteste zuerst
;(function()
local Co = ns.Cost
local me = realm.chars["Mirel Dorna"]
local savedStart, savedMoves = me.start, realm.moves
local t0 = os.time() - 5000
me.start = { t = t0 - 100, places = {} }
for name in pairs(realm.chars) do if name ~= "Mirel Dorna" then realm.chars[name] = nil end end
realm.lotBase = nil
local C = "Mirel Dorna"
local function E(dt, k, id, n, m, extra) local e = { t = t0 + dt, c = C, k = k, id = id, n = n, m = m } for a, b in pairs(extra or {}) do e[a] = b end return e end
local sold1, sold2, use1
realm.moves = {
  E(0, "loot", 2447, 10),                       -- 10 Friedensblumen gesammelt (0)
  E(10, "ahbuy", 2447, 10, -2000),              -- 10 im AH zu 2s
  E(20, "vendor", 3371, 5, -100),               -- 5 Phiolen zu 20c
  E(30, "craft", 929, 5),                       -- Ergebnis steht vor dem Material (gleiche Sekunde)
  E(30, "craft", 2447, -10), E(30, "craft", 3371, -5),
  E(40, "posted", 929, -3), E(40, "ahfee", 929, nil, -30),
  E(50, "ahsold", 929, -3),
  E(60, "ahsold", 929, nil, 1740, { q = 3 }),   -- 18s - 90c Anteil + 30c Einzahlung
  E(70, "posted", 929, -1), E(70, "ahfee", 929, nil, -10),
  E(80, "ahreturn", 929, 1),                    -- abgelaufen: 10c bleiben offen
  E(90, "use", 929, -1),                        -- getrunken
  E(100, "posted", 929, -1), E(100, "ahfee", 929, nil, -10),
  E(110, "ahsold", 929, -1),
  E(120, "ahsold", 929, nil, 580, { q = 1 }),   -- 6s - 30c + 10c
}
sold1, use1, sold2 = realm.moves[10], realm.moves[14], realm.moves[18]
Co.Invalidate()
local h = Co.Result(realm.moves[4])
check(h and math.abs(h.unit - 20) < 0.01, "Heiltrank: Kosten 20c je Stueck (gesammelte Blumen zuerst = 0, Phiole 20c)")
local r1 = Co.Result(sold1)
check(r1.sale and math.abs(r1.cost - 60) < 0.01 and r1.fee == 30 and math.abs(r1.profit - 1650) < 0.01, "Verkauf 3 Traenke: Wareneinsatz 60c, Gebuehr 30c, Gewinn 16s 50c")
check(math.abs(Co.Result(use1).use - 20) < 0.01, "getrunken: Verbrauch 20c")
local r2 = Co.Result(sold2)
check(r2.fee == 20 and math.abs(r2.profit - 540) < 0.01, "letzter Trank: offene Gebuehr des abgelaufenen (10c) + neue 10c, Gewinn 5s 40c")
local fb = Co.Info(2447)
check(fb and fb.n == 10 and math.abs(fb.next - 200) < 0.01 and math.abs(fb.value - 2000) < 0.01, "im Lager: 10 gekaufte Blumen zu 2s (Lagerwert 20s)")
check(Co.Info(929) == nil and Co.Info(3371) == nil, "Traenke und Phiolen aufgebraucht")
check(Co.Text(2447):find("Kosten 2", 1, true) and not Co.Text(2447):find("Ø", 1, true), "Tooltip-Text: Kosten 2s (ohne Ø, alle gleich)")
local b = ns.Book.Collect("all", false)
check(math.abs(b.trade - 2190) < 0.01 and math.abs(b.cogs - 80) < 0.01 and b.tfee == 50 and b.sales == 2320 and math.abs(b.use - 20) < 0.01,
    "Buch: Handelsgewinn 21s 90c (Erloes 23s 20c - Wareneinsatz 80c - Gebuehren 50c), Verbrauch 20c")
ns.Window.Select("book"); mod.db.bookPeriod = "d7"; ns.Window.Refresh()
local row for _, x in ipairs(ns.Book.book.items.items) do if x.id == 929 then row = x end end
check(row and math.abs(row.profit - 2190) < 0.01, "Buch Nach Gegenstand: Gewinn je Gegenstand")
-- Durchschnitt im Tooltip, wenn die Posten verschieden sind
table.insert(realm.moves, E(130, "ahbuy", 2447, 10, -3000))
Co.Invalidate()
check(Co.Text(2447):find("Ø", 1, true) and math.abs(Co.Info(2447).avg - 250) < 0.01, "Kosten 2s (Ø 2s 50c) bei zwei Posten")
-- Auktionskauf: Gold und Gegenstand getrennt (Post spaeter) -> Kosten aus dem Gold
table.insert(realm.moves, E(140, "ahbuy", nil, nil, -500))
table.insert(realm.moves, E(150, "ahbuy", 2448, 5))
Co.Invalidate()
check(math.abs(Co.Info(2448).next - 100) < 0.01, "Kauf und Post getrennt: Kosten 1c je Stueck aus dem Gold")
-- Handel mit Gegenleistung: 2 Blumen (Kosten 4s) gegen 4 Stueck -> je 1s
Peon.modules.broker = { ItemValue = function(_, id, n) return 100 * (n or 1) end }
table.insert(realm.moves, E(160, "trade", 2447, -2))
table.insert(realm.moves, E(160, "trade", 5001, 4))
Co.Invalidate()
check(math.abs(Co.Info(5001).next - 100) < 0.01, "Handel: Gegenwert der gegebenen Blumen (4s) auf 4 Stueck verteilt")
-- Nachnahme
table.insert(realm.moves, E(170, "mail", 5002, 2, nil, { paid = 300 }))
table.insert(realm.moves, E(180, "mail", 5003, 2))
Co.Invalidate()
check(math.abs(Co.Info(5002).next - 150) < 0.01 and Co.Info(5003).next == 0, "Post: Nachnahme = bezahlter Betrag, sonst 0")
-- Anfangsbestand zum Marktwert beim Start (eingefroren)
me.start = { t = t0 - 100, places = { bags = { t = t0 - 100, items = { [5004] = 3 } } } }
Co.Invalidate()
check(Co.Info(5004).next == 0 and Co.Info(5004).sn == 3 and Co.Info(5004).value == 0, "0.14.5: Anfangsbestand ist Startbestand mit Kosten 0")
Peon.modules.broker = { ItemValue = function(_, id, n) return 999 * (n or 1) end }
Co.Invalidate()
check(Co.Info(5004).next == 0, "Startbestand bleibt bei 0, auch wenn der Markt sich aendert")
Peon.modules.broker = nil
-- Hoechstens 30 Posten
local lots = { lots = {} }
for i = 1, 40 do Co.AddLot(lots, 7, 1, i, i * 86400) end
check(#lots.lots[7] == 30 and lots.lots[7][1].n == 11 and math.abs(lots.lots[7][1].c - 6) < 0.01, "hoechstens 30 Posten, aelteste zusammengelegt (Ø)")
-- Zusammenfassen nach 90 Tagen: Stand bleibt
local before = Co.Info(2447).value
Co.Absorb(realm.moves, t0 + 1000)
realm.moves = {}
Co.Invalidate()
check(math.abs(Co.Info(2447).value - before) < 0.01, "nach dem Zusammenfassen bleiben die Posten (lotBase)")
-- Tooltip zeigt die Kosten ohne Umschalt
tt.lines = {}; tt.link = "|cffffffff|Hitem:2447::::|h[Friedensblume]|h|r"; ttPost(tt, {})
shift = true; tt.lines = {}; ttPost(tt, {}); shift = false
check(tt.lines[1] and tt.lines[1]:find("Kosten", 1, true) and tt.lines[1]:find("| 2", 1, true), "Tooltip: Kosten mit Umschalt (" .. tostring(tt.lines[1]) .. ")")
-- Schnittstelle fuer Broker
local nx, av = mod:Cost(2447)
check(nx and av and av >= nx, "mod:Cost fuer Broker")
-- 0.13.1: letzter Kauf beim Haendler (fuer Brokers Berufsfenster)
realm.moves = { { t = 1, k = "vendor", id = 2450, n = 5, m = -50 }, { t = 2, k = "vendor", id = 2450, n = -1, m = 3 },
                { t = 3, k = "loot", id = 2450, n = 2 }, { t = 4, k = "vendor", id = 2450, n = 2, m = -30 },
                { t = 5, k = "buyback", id = 2450, n = 1, m = -1 } }
local vu, vt = mod:VendorBuy(2450)
check(vu == 15 and vt == 4 and mod:VendorBuy(9999) == nil, "0.13.1: mod:VendorBuy = letzter Kauf beim Haendler je Stueck")
realm.lotBase = nil
me.start, realm.moves = savedStart, savedMoves
Co.Invalidate()
end)()

;(function()
-- ===== ab 0.9: Kosten je Charakter, Post an Twinks nimmt die Posten mit =====
local Co = ns.Cost
local T, G = "Mirel Dorna", "Borin Dorna"
local me = realm.chars[T]
local savedStart, savedMoves, savedChars = me.start, realm.moves, {}
for name, c in pairs(realm.chars) do savedChars[name] = c end
for name in pairs(realm.chars) do if name ~= T then realm.chars[name] = nil end end
realm.chars[G] = { faction = "Alliance", places = {}, start = { t = 0, places = {} } }
local t0 = os.time() - 5000
me.start = { t = t0 - 100, places = {} }
realm.lotBase = nil
local function E(dt, c, k, id, n, m, extra) local e = { t = t0 + dt, c = c, k = k, id = id, n = n, m = m } for a, b in pairs(extra or {}) do e[a] = b end return e end
realm.moves = {
  E(0, G, "loot", 2589, 20),                         -- Borin sammelt 20 Leinenstoff (0)
  E(10, T, "ahbuy", 2589, 20, -1600),                -- Mirel kauft 20 zu 80c
  E(20, G, "twink", 2589, -5, nil, { x = T }),       -- Borin schickt 5 an Mirel
  E(30, T, "ahsold", 2589, -10),                     -- Mirel verkauft 10 (ihre gekauften, 80c)
  E(31, T, "ahsold", 2589, nil, 950, { q = 10 }),
}
local sale = realm.moves[5]
Co.Invalidate()
check(math.abs(Co.Info(2589, T).avg - (10 * 80 + 5 * 0) / 15) < 0.01, "Mirel: 10 eigene zu 80c + 5 unterwegs zu 0 (Ø " .. math.floor(Co.Info(2589, T).avg) .. "c)")
check(math.abs(Co.Info(2589, T).next - 80) < 0.01, "naechstes Stueck kommt aus dem, was Mirel schon hat")
check(Co.Info(2589, G).n == 15 and Co.Info(2589, G).next == 0, "Borin: 15 gesammelte, Kosten 0")
local r = Co.Result(sale)
check(r and math.abs(r.cost - 800) < 0.01 and math.abs(r.profit - 150) < 0.01, "Talias Verkauf mit ihren eigenen Kosten (80c je Stueck, nicht Grimms 0)")
local all = Co.Info(2589, "*")
check(all.n == 30 and math.abs(all.value - 800) < 0.01, "alle Charaktere: 30 Stueck, Lagerwert 8s (Summe)")
check(math.abs(Co.TotalValue() - (Co.TotalValue(T) + Co.TotalValue(G))) < 0.01, "Lagerwert gesamt = Summe je Charakter")
-- Abholen: Posten mit urspruenglichem Datum (aelter als Talias Kauf) -> gehen zuerst weg
table.insert(realm.moves, E(40, T, "twink", 2589, 5, nil, { x = G }))
table.insert(realm.moves, E(50, T, "use", 2589, -5))
local use = realm.moves[#realm.moves]
Co.Invalidate()
check(Co.Result(use).use == 0, "abgeholte Stueck behalten ihr Datum (Grimms Beute vor Talias Kauf) und gehen zuerst weg")
check(Co.Info(2589, T).n == 10 and math.abs(Co.Info(2589, T).next - 80) < 0.01, "danach Talias Kaufposten")
-- Abholen ohne bekannten Versand: Marktwert (gemerkt)
Peon.modules.broker = { ItemValue = function(_, id, n) return 50 * (n or 1) end }
table.insert(realm.moves, E(60, T, "twink", 4306, 2, nil, { x = G }))
Co.Invalidate()
local tw = realm.moves[#realm.moves]
check(Co.Info(4306, T).next == 0 and Co.Info(4306, T).sn == 2, "0.14.5: Post vom Twink ohne Versand: Startbestand, Kosten 0")
Peon.modules.broker = nil
-- Schnittstelle: ohne Charakter = eingeloggter, "*" = alle
check(select(3, mod:Cost(2589)) == 10 and select(3, mod:Cost(2589, "*")) == 25 and select(3, mod:Cost(2589, G)) == 15, "mod:Cost je Charakter")
local by = Co.ByChar(2589)
check(#by == 2 and by[1].name == G and by[2].name == T, "Kosten je Charakter fuer den Tooltip")
-- Buch "Nur dieser Charakter"
local mine, every = ns.Book.Collect("all", true), ns.Book.Collect("all", false)
check(math.abs(mine.trade - 150) < 0.01 and math.abs(every.trade - 150) < 0.01, "Handelsgewinn je Charakter = gesamt (nur Mirel verkauft)")
-- Tagesverlauf (G4)
local hd = Co.ItemDays(2589, T)
local today = Co.DayOf(time())
local d0 = hd.days[Co.DayOf(t0)]
check(hd.first and d0 and d0.buyN == 20 and math.abs(d0.buyV - 1600) < 0.01, "Tagesverlauf: Kauf 20 zu 80c")
check(d0.sellN == 10 and d0.sellV == 950, "Tagesverlauf: Verkauf 10 (Erloes ohne Rechnung)")
check(hd.days[today] and hd.days[today].n == Co.Info(2589, T).n, "Tagesverlauf: heute = aktueller Stand")
local hg = Co.ItemDays(2589, G)
check(hg.days[Co.DayOf(t0)].loot == 20 and hg.days[Co.DayOf(t0)].buyN == nil, "Tagesverlauf Borin: nur seine Beute")
local ha = Co.ItemDays(2589, "*")
check(ha.days[today].n == Co.Info(2589, "*").n and ha.days[Co.DayOf(t0)].loot == 20, "Tagesverlauf alle Charaktere")
check(Co.ItemDays(999999, T).first == nil, "Gegenstand ohne Bewegungen: leer")
-- Zusammenfassen: Stand je Charakter bleibt
local bt, bg = Co.Info(2589, T).value, Co.Info(2589, G).value
Co.Absorb(realm.moves, t0 + 1000)
check(realm.lotBase.chars and realm.lotBase.chars[G], "lotBase je Charakter")
realm.moves = {}
Co.Invalidate()
check(math.abs(Co.Info(2589, T).value - bt) < 0.01 and Co.Info(2589, G).n == 15, "nach dem Zusammenfassen: Posten je Charakter bleiben")
-- altes Format (accountweit) geht an den eingeloggten Charakter
realm.lotBase = { untilT = t0 + 1000, lots = { [2589] = { { t = t0, n = 3, c = 70 } } }, fee = {} }
Co.Invalidate()
check(Co.Info(2589, T).n == 3 and Co.Info(2589, G) == nil, "lotBase im alten Format: eingeloggter Charakter")
realm.lotBase = nil
for name in pairs(realm.chars) do realm.chars[name] = nil end
for name, c in pairs(savedChars) do realm.chars[name] = c end
me.start, realm.moves = savedStart, savedMoves
Co.Invalidate()
end)()

mod.db.costOrder = "lifo"
ns.Cost.Invalidate()
-- ===== ab 0.8: Herstellen im Verlauf zusammengefasst =====
;(function()
local Mv = ns.Moves
local saved = realm.moves
local me = ns.CharName()
local t = time()
realm.moves = {
  { t = t - 100, c = me, k = "loot", id = 2589, n = 2 },
  { t = t - 10, c = me, k = "craft", id = 2452, n = -1, x = "Disteltee" },
  { t = t - 10, c = me, k = "craft", id = 159, n = -1, x = "Disteltee" },
  { t = t - 9, c = me, k = "craft", id = 2447, n = 1, x = "Disteltee" },
  { t = t - 8, c = me, k = "craft", id = 159, n = -1, x = "Disteltee" },
  { t = t - 8, c = me, k = "craft", id = 2452, n = -1, x = "Disteltee" },
  { t = t - 7, c = me, k = "craft", id = 2447, n = 1, x = "Disteltee" },
  { t = t - 1, c = me, k = "craft", id = 2447, n = 1, x = "Anderes Rezept" },
}
Mv.Changed()
mod.db.historyKind = "all"
ns.Window.Select("history")
ns.History.Refresh()
local rows = ns.History.table.items
local grp, single
for _, r in ipairs(rows) do if r.grp then grp = r elseif r.x == "Anderes Rezept" then single = r end end
check(#rows == 3, "Herstellen: ein Vorgang = eine Zeile (" .. #rows .. " Zeilen)")
check(grp and grp.id == 2447 and grp.n == 2 and grp.grp.mats[2452] == -2 and grp.grp.mats[159] == -2 and #grp.grp.list == 6, "Herstellen: Ergebnis x2, Material summiert")
check(single and not single.grp and single.id == 2447, "anderes Rezept: eigene Zeile")
local col for _, c in ipairs(ns.History.table.o.columns) do if c.key == "name" then col = c end end
local txt = col.format(grp.name, grp)
check(txt:find("×2", 1, true) and txt:find(" aus 2 ", 1, true), "Herstellen: Material grau dahinter (" .. txt .. ")")
tt.lines = {}
ns.History.RowTooltip({}, grp)
local hasMat for _, l in ipairs(tt.lines) do if l:find("Material:", 1, true) then hasMat = true end end
check(hasMat, "Herstellen: Tooltip mit Material")
ns.History.searchBox:SetText(string.lower(select(1, ns.Inventory.ItemInfo(159)) or "#159")); ns.History.searchBox.scripts.OnTextChanged(ns.History.searchBox, true)
check(#ns.History.table.items >= 1 and ns.History.table.items[1].grp, "Suche findet Herstellen auch ueber das Material")
ns.History.searchBox:SetText(""); ns.History.searchBox.scripts.OnTextChanged(ns.History.searchBox, true)
realm.moves = saved
Mv.Changed()
end)()

-- ===== ab 0.8.1: weitere Vorgaenge zusammengefasst =====
;(function()
local Mv = ns.Moves
local saved = realm.moves
local me = ns.CharName()
local t = time() - 1000
realm.moves = {
  { t = t, c = me, k = "ahreturn", id = 2589, n = 8, x = "abgelaufen" },
  { t = t + 1, c = me, k = "ahreturn", id = 2447, n = 1, x = "abgelaufen" },
  { t = t + 40, c = me, k = "posted", id = 2589, n = -8 },
  { t = t + 40, c = me, k = "ahfee", id = 2589, m = -100 },
  { t = t + 48, c = me, k = "posted", id = 2447, n = -1 },
  { t = t + 48, c = me, k = "ahfee", id = 2447, m = -75 },
  { t = t + 60, c = me, k = "ahfee", id = 2447, m = -20, x = "abgebrochen" },
  { t = t + 100, c = me, k = "trade", id = 2589, n = -10, x = "Fremder" },
  { t = t + 100, c = me, k = "trade", m = 5000, x = "Fremder" },
  { t = t + 200, c = me, k = "quest", id = 2447, n = -2 },
  { t = t + 200, c = me, k = "quest", id = 4306, n = 1 },
  { t = t + 200, c = me, k = "quest", m = 120 },
  { t = t + 300, c = me, k = "vendor", id = 2589, n = -3, m = 30 },
  { t = t + 301, c = me, k = "vendor", id = 2447, n = -1, m = 10 },
  { t = t + 303, c = me, k = "vendor", id = 4306, n = -2, m = 8 },
  { t = t + 304, c = me, k = "vendor", id = 159, n = 5, m = -25 },
  { t = t + 400, c = me, k = "twink", id = 2589, n = -4, x = "Borin Stein" },
  { t = t + 400, c = me, k = "twink", m = -500, x = "Borin Stein" },
  { t = t + 500, c = me, k = "loot", id = 2589, n = 2, d = "x" },
  { t = t + 501, c = me, k = "loot", id = 2447, n = 2, d = "x" },
}
Mv.Changed()
mod.db.historyKind = "all"; mod.db.historyMoves = true; mod.db.historyOnlyMe = false
ns.Window.Select("history")
ns.History.Refresh()
local rows = ns.History.table.items
local by = {}
for _, r in ipairs(rows) do by[#by + 1] = r end
local function find(fn) for _, r in ipairs(rows) do if fn(r) then return r end end end
local col for _, c in ipairs(ns.History.table.o.columns) do if c.key == "name" then col = c end end
local ret = find(function(r) return r.e.k == "ahreturn" end)
check(ret and ret.grp and ret.id == 2589 and ret.n == 8 and #ret.grp.list == 2, "Serie: Auktion zurueck (Alle oeffnen) eine Zeile")
local p1 = find(function(r) return r.e.k == "posted" and r.id == 2589 end)
local p2 = find(function(r) return r.e.k == "posted" and r.id == 2447 end)
check(p1 and p1.grp and p1.m == -100 and p1.side == "move" and p2 and p2.grp and p2.m == -75, "Auktion eingestellt + Gebuehr je Gegenstand eine Zeile")
local cancel = find(function(r) return r.e.k == "ahfee" end)
check(cancel and not cancel.grp and cancel.m == -20, "Abbruchkosten bleiben eigene Zeile")
local tr = find(function(r) return r.e.k == "trade" end)
check(tr and tr.grp and tr.m == 5000 and tr.n == -10 and col.format(tr.name, tr):find("×10", 1, true), "Handel: Gegenstand und Gold eine Zeile")
local q = find(function(r) return r.e.k == "quest" end)
local qt = col.format(q.name, q)
check(q and q.grp and q.id == 4306 and q.m == 120 and qt:find("gegen 2 ", 1, true), "Quest: Belohnung gegen Questgegenstaende (" .. qt .. ")")
local vs = find(function(r) return r.e.k == "vendor" and r.side == "out" end)
local vb = find(function(r) return r.e.k == "vendor" and r.side == "in" end)
check(vs and vs.grp and #vs.grp.list == 3 and vs.m == 48 and vb and not vb.grp, "Haendler: Verkaeufe eine Zeile, Kauf getrennt")
check(col.format(vs.name, vs):find("+ 2 ", 1, true), "Haendler: weitere Gegenstaende dahinter (" .. col.format(vs.name, vs) .. ")")
local tw = find(function(r) return r.e.k == "twink" end)
check(tw and tw.grp and tw.m == -500, "Post an Twink: Gegenstand und Gold eine Zeile")
local nl = 0 for _, r in ipairs(rows) do if r.e.k == "loot" then nl = nl + 1 end end
check(nl == 2, "Tagessummen (Beute) bleiben einzeln")
check(#rows == 11, "insgesamt 11 Zeilen (" .. #rows .. ")")
tt.lines = {}
ns.History.RowTooltip({}, vs)
local tsum, tgrp for _, l in ipairs(tt.lines) do if l:find("Summe", 1, true) then tsum = true end if l:find("zusammengefasst", 1, true) then tgrp = true end end
check(tsum and tgrp, "Tooltip: Eintraege einzeln mit Summe")
mod.db.historyMoves = false; ns.History.Refresh()
p1 = nil for _, r in ipairs(ns.History.table.items) do if r.e.k == "ahfee" and r.id == 2589 then p1 = r end end
check(p1 and not p1.grp, "ohne Umbuchungen: Gebuehr allein")
mod.db.historyMoves = true
realm.moves = saved
Mv.Changed()
end)()

;(function()
-- ===== ab 0.14: Gegenstand zeigen (Broker), Suche, Tastenbelegung =====
mod.acc.items[2592] = { n = "Wollstoff", q = 1, i = 132889 }
check(ns.FindItem("wollstoff") == 2592 and ns.FindItem("woll") == 2592 and ns.FindItem("2592") == 2592 and ns.FindItem("|cnIQ1:|Hitem:2592::|h[x]|h|r") == 2592, "Gegenstand finden: Name, Teil, Nummer, Link")
-- ohne Broker: Bestand mit Suche
mod:ShowItem(2592)
check(ns.Window.current == "stock" and ns.Stock.search == "Wollstoff", "ohne Broker: Bestand mit Suche nach dem Namen")
-- mit Broker: dessen Seite Gegenstand
local shown
Peon.modules.broker = { ShowItem = function(_, id) shown = id end, ItemValue = function() return nil end }
mod:ShowItem(2589)
check(shown == 2589, "mit Broker: Seite Gegenstand in Broker")
mod.opts.onSlash(mod, "wollstoff", "")
check(shown == 2592, "/ledger wollstoff")
mod.opts.onSlash(mod, "gibtsnicht", "")
check(said("nicht gefunden"), "/ledger mit unbekanntem Namen")
-- Tastenbelegung: Gegenstand unter der Maus
function tt:IsShown() return self.shown end
tt.link = "|cnIQ1:|Hitem:2447::::|h[Friedensblume]|h|r"; tt.shown = true
PeonLedger_ShowHoverItem()
check(shown == 2447, "Tastenbelegung zeigt den Gegenstand in Broker")
tt.shown = false
PeonLedger_ShowHoverItem()
check(said("Kein Gegenstand unter der Maus"), "Tastenbelegung ohne Tooltip: Hinweis")
tt.IsShown, tt.shown = nil, nil
Peon.modules.broker = nil
ns.Stock.search = nil
ns.Window.Select("overview")
end)()

-- Texte fuer Peon_Panel (ab 0.11)
check(mod.launcher and mod.launcher.showKey == "minimapShow", "0.11: Starter ueber den Minimap-Button")
check(mod.launcher.defaultText == "goldAll" and type(mod.launcher:GetText("goldAll")) == "string", "0.11: Text Gold aller Charaktere: " .. tostring(mod.launcher:GetText("goldAll")))
check(type(mod.launcher:GetText("goldMe")) == "string", "0.11: Text Gold dieses Charakters: " .. tostring(mod.launcher:GetText("goldMe")))

-- Gold der Sitzung (ab 0.12), mit Muenzsymbolen
local function Plain(t) return (t:gsub("|T[^|]*UI%-(%a+)Icon[^|]*|t", function(k) return k:sub(1, 1):lower() end)) end
do
  local keepGuid = UnitGUID
  UnitGUID = function() return "Player-1" end
  fire("PLAYER_ENTERING_WORLD", true, false)
  local function S() return Plain(mod.launcher:GetText("goldSession")) end
  check(S() == "+0c", "0.12: Sitzung beginnt bei null: " .. S())
  money = money + 123456
  check(S() == "+12g 34s", "0.12: Gewinn mit Gold und Silber: " .. S())
  money = money - 150000
  check(S() == "-2g 65s", "0.12: Verlust: " .. S())
  fire("PLAYER_ENTERING_WORLD", false, true)
  check(S() == "-2g 65s", "0.12: /reload zaehlt weiter")
  PeonLedgerDB.session.who = "jemand anders"
  check(S() == "+0c", "0.12: anderer Charakter beginnt neu")
  money = money + 30000
  UnitGUID = keepGuid
end
check(Plain(ns.PanelMoney(4567)) == "45s 67c", "0.12: unter 1g mit Kupfer")
check(Plain(ns.PanelMoney(123456789)) == "12,3kg","0.12: ab 1000g gekuerzt: " .. Plain(ns.PanelMoney(123456789)))
check(mod.launcher:GetText("goldMe"):find("UI-GoldIcon", 1, true),"0.12: Gold mit Muenzsymbol: " .. mod.launcher:GetText("goldMe"))

-- ===== 0.14: Neuaufbau =====
;(function()
-- ----- E1: Kontrollrechnung -----
local Mv, K = ns.Moves, ns.Check
local T, G = "Mirel Dorna", "Borin Stein"
local me = realm.chars[T]
local saved = { start = me.start, moves = realm.moves, places = me.places, money = me.money, weeks = realm.weeks }
realm.weeks = nil
me.places = { bags = { t = 1, items = { [2589] = 10, [118] = 2 } }, bank = { t = 1, items = { [2589] = 5 } },
              auctions = { t = 1, items = { [2840] = 3 } }, mail = { t = 1, items = { [9999] = 7 } } }
me.money = 5000
me.start = { t = 1, money = 1000, places = { bags = { t = 1, items = { [2589] = 4 } } } }
local now = time()
realm.moves = {
  { t = now - 50, c = T, k = "loot", id = 2589, n = 11, d = "x" },
  { t = now - 40, c = T, k = "vendor", id = 118, n = 2, m = -100 },
  { t = now - 30, c = T, k = "loot", id = 2840, n = 3, d = "x" },
  { t = now - 30, c = T, k = "posted", id = 2840, n = -3 },   -- Umbuchung: zaehlt nicht
  { t = now - 20, c = T, k = "ahsold", m = 4100 },
  { t = now - 10, c = G, k = "loot", m = 999 },                 -- anderer Charakter
}
Mv.Changed()
local res = K.Run(T)
check(res.n == 0 and res.gold == 0, "Kontrollrechnung: Gold und Bestand gehen auf (Post zaehlt nicht, eingestellt ist Umbuchung)")
me.money = 5600
me.places.bags.items[2589] = 9
res = K.Run(T)
check(res.n == 2 and res.gold == 600 and res.items[2589] == -1, "Kontrollrechnung: 6s zu viel, 1 Leinenstoff zu wenig")
check(ns.Check.StatusText():find("2 Abweichungen offen", 1, true), "Statuszeile: offene Abweichungen")
Mv.pending = { items = {}, money = {}, gen = 1 }
check(K.Book(T) == 0, "nicht verbuchen, solange Bewegungen offen sind")
Mv.pending = nil
local p0 = ns.Book.Collect("all", false).profit
check(K.Book(T) == 2 and K.Run(T).n == 0, "Abweichungen verbucht, danach geht die Rechnung auf")
local d = realm.moves[#realm.moves]
check(d.k == "diff" and Mv.Side(d) == "move" and ns.Book.Collect("all", false).profit == p0, "Abweichung zaehlt nicht als Gewinn")
check(Mv.Label({ k = "diff", m = 600 }) == "Abweichung", "Bezeichnung Abweichung")
check(K.Recent() == 2 and ns.Check.StatusText():find("2 Abweichungen in 7 Tagen", 1, true), "Statuszeile: Abweichungen der letzten 7 Tage")
check(Mv.InGroup("diff", "fix"), "Filter Korrekturen zeigt auch Abweichungen")
-- Wochensummen zaehlen mit
realm.moves = {}
realm.weeks = { ["2026-40"] = { [T .. "|loot|2589|"] = nil, [T .. "|loot|2589"] = { n = 11 }, [T .. "|vendor|118"] = { n = 2, m = -100 },
  [T .. "|loot|2840"] = { n = 3 }, [T .. "|posted|2840"] = { n = -3 }, [T .. "|ahsold|0"] = { m = 4700 } } }
me.places.bags.items[2589] = 10
check(K.Run(T).n == 0, "Kontrollrechnung mit Wochensummen")
realm.weeks = nil
me.start, realm.moves, me.places, me.money = saved.start, saved.moves, saved.places, saved.money
realm.weeks = saved.weeks
Mv.Changed()
end)()

;(function()
-- ----- E2: Erfassung an der Quelle -----
local Mv, I = ns.Moves, ns.Inventory
local T = "Mirel Dorna"
local me = realm.chars[T]
local saved = { moves = realm.moves, start = me.start }
realm.moves = {}
Mv.Changed()
local clock = 100000
GetTime = function() return clock end
local function settle() clock = clock + 2; local list = timers; timers = {}; for _, f in ipairs(list) do f() end end
local function bags() fire("BAG_UPDATE", 0); fire("BAG_UPDATE_DELAYED") end
local function last() return realm.moves[#realm.moves] end
timers = {}
Mv.pending, Mv.open, Mv.closed, Mv.ctx, Mv.draft = nil, {}, {}, {}, {}
Mv.paused = true; fire("PLAYER_MONEY"); Mv.paused = nil   -- Gold der frueheren Tests (Sitzung) angleichen
-- Kauf kurz nach dem Einstellen: der Kauf, nicht die Gebuehr
fire("AUCTION_HOUSE_SHOW")
fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
clock = clock + 3
fire("COMMODITY_PURCHASE_SUCCEEDED")
money = money - 777; fire("PLAYER_MONEY"); settle()
check(last().k == "ahbuy" and last().m == -777, "Kauf kurz nach dem Einstellen ist ein Kauf (vorher Einstellgebuehr)")
fire("AUCTION_HOUSE_AUCTION_CREATED", 2)
money = money - 30; fire("PLAYER_MONEY"); settle()
check(last().k == "ahfee" and last().m == -30, "danach Einstellen: Gebuehr (Kauf schon verbraucht)")
-- Gegenstand des Kaufs nur einmal
Mv.Note("ahbuyitem", { id = 2772, qty = 5 })
fire("COMMODITY_PURCHASE_SUCCEEDED"); money = money - 500; fire("PLAYER_MONEY"); settle()
check(last().id == 2772 and last().q == 5, "Kauf mit Gegenstand")
fire("COMMODITY_PURCHASE_SUCCEEDED"); money = money - 120; fire("PLAYER_MONEY"); settle()
check(last().m == -120 and last().id == nil, "zweiter Kauf bekommt nicht denselben Gegenstand")
-- Einzelgegenstand: PlaceBid mitgelesen, Gegenstand aus der Auktion
C_AuctionHouse.PlaceBid = function() end
C_AuctionHouse.GetAuctionInfoByID = function(aid) if aid == 77 then return { itemKey = { itemID = 6611 } } end end
Mv.Init()   -- Haken neu (PlaceBid gab es vorher nicht)
C_AuctionHouse.PlaceBid(77, 2500)
fire("AUCTION_HOUSE_PURCHASE_COMPLETED"); money = money - 2500; fire("PLAYER_MONEY"); settle()
check(last().k == "ahbuy" and last().id == 6611 and last().q == 1, "Einzelgegenstand gekauft: Gegenstand bekannt (B6)")
fire("AUCTION_HOUSE_CLOSED")
clock = clock + 100
-- Brief noch nicht geladen ("Rufe Daten ab"): offener Kauf -> Kauf, nicht "Auktion zurueck"
RETRIEVING_DATA = "Rufe Daten ab"
local buy = Mv.Add("ahbuy", 3576, nil, -400); buy.q = 4
inbox = { { nil, nil, "Auktionshaus der Allianz", "Rufe Daten ab", 0, 0, 30, 1 } }
GetInboxItem = function(i, a) if i == 1 and a == 1 then return "Zinnbarren", 3576, 1, 4, 1 end end
GetInboxInvoiceInfo = function() end
local nt = #timers
fire("MAIL_SHOW"); fire("MAIL_INBOX_UPDATE")
check(I.letters[1].loading and #timers > nt, "Brief noch nicht geladen: erkannt, erneutes Lesen geplant")
local n0 = #realm.moves
AutoLootMailItem(1)
BAGS[0][14] = { itemID = 3576, stackCount = 4 }
inbox = {}; fire("MAIL_INBOX_UPDATE"); bags(); settle()
check(#realm.moves == n0 and buy.n == 4 and buy.id == 3576, "Ware aus ungeladenem Brief an den offenen Kauf gehaengt (B3)")
-- Rechnung mit Ware: Abgang in derselben Zeile, Ort Auktionen kleiner
me.places.auctions = { t = 1, items = { [2841] = 5 }, used = 1 }
inbox = { { nil, nil, "Auktionshaus der Allianz", "Auktion erfolgreich: Bronzebarren", 950, 0, 30, nil } }
GetInboxItem = function() end
GetInboxInvoiceInfo = function(i) return "seller", "Bronzebarren", "Bob", 0, 1000, 0, 50, nil, nil, nil, 5 end
fire("MAIL_INBOX_UPDATE"); settle()
TakeInboxMoney(1)
money = money + 950; fire("PLAYER_MONEY"); settle()
local sale = last()
check(sale.k == "ahsold" and sale.m == 950 and sale.n == -5 and sale.q == 5 and not me.places.auctions.items[2841], "Verkauf aus der Rechnung: Ware weg, Ort Auktionen kleiner (B2)")
check(Mv.ClaimSale(2841, 5) == 0 and Mv.ClaimSale(2841, 1) == 1, "Auktionsliste meldet den Verkauf spaeter: nicht doppelt")
local z = ns.Cost.Result(sale)
check(z and z.sale and z.profit, "Kosten: Verkauf mit Ware und Erloes in einer Zeile")
inbox = {}; fire("MAIL_INBOX_UPDATE"); settle()
-- Briefentwurf: angehaengt, abgeschickt an Twink
realm.chars["Borin Stein"] = realm.chars["Borin Stein"] or { places = {}, start = { places = {} } }
BAGS[0][14] = nil; bags(); settle()
check(Mv.draft[3576] == 4 and #realm.moves == n0 + 1, "an den Brief gehaengt: noch keine Bewegung (Entwurf)")
SendMail("Borin", "Zinn", "")
local tw = last()
check(tw.k == "twink" and tw.id == 3576 and tw.n == -4 and not next(Mv.draft) and realm.chars["Borin Stein"].places.transit.items[3576] >= 4, "abgeschickt: Post an Twink (B7)")
-- angehaengt und zurueck in die Tasche: nichts
BAGS[0][14] = { itemID = 4306, stackCount = 2 }
Mv.paused = true; bags(); settle(); Mv.paused = nil
n0 = #realm.moves
BAGS[0][14] = nil; bags(); settle()
BAGS[0][14] = { itemID = 4306, stackCount = 2 }; bags(); settle()
check(#realm.moves == n0 and not next(Mv.draft), "angehaengt und wieder abgenommen: keine Bewegung")
-- angehaengt, Postfach zu, nicht abgeschickt: danach ein Abgang ohne Zusammenhang
BAGS[0][14] = nil; bags(); settle()
fire("MAIL_CLOSED")
settle()
check(last().k == "other" and last().id == 4306 and last().n == -2 and not next(Mv.draft), "Entwurf nicht abgeschickt: Abgang ohne Zusammenhang")
clock = clock + 100
GetTime = function() return 1 end
RETRIEVING_DATA = nil
realm.moves, me.start = saved.moves, saved.start
Mv.Changed()
end)()

;(function()
-- ----- E3: zuletzt gezahlt und zuletzt verkauft -----
local Mv, LB = ns.Moves, ns.Last
local T = "Mirel Dorna"
local saved = realm.moves
realm.moves = {
  { t = 10, c = T, k = "ahbuy", id = 500, n = 4, m = -400 },
  { t = 20, c = T, k = "vendor", id = 500, n = 2, m = -300 },
  { t = 30, c = T, k = "ahsold", id = 500, m = 950, q = 5, gross = 1000, cut = 50 },
  { t = 40, c = T, k = "vendor", id = 501, n = -3, m = 30 },
  { t = 50, c = T, k = "mail", id = 502, n = 2, paid = 500 },
  { t = 60, c = T, k = "trade", m = -900, x = "Bob" },
  { t = 61, c = T, k = "trade", id = 503, n = 3, x = "Bob" },
  { t = 70, c = T, k = "ahbuy", m = -800, q = 2, id = 504 },
  { t = 80, c = T, k = "loot", id = 500, n = 9 },
}
Mv.Changed()
local u, t, n, src = mod:LastBuy(500)
check(u == 150 and t == 20 and n == 2 and src == "vendor", "zuletzt gezahlt: letzter Kauf (Haendler), Beute zaehlt nicht")
u, t, n, src = mod:LastSale(500)
check(u == 190 and n == 5 and src == "ah", "zuletzt verkauft: netto nach Anteil je Stueck")
check(mod:LastSale(501) == 10 and select(4, mod:LastSale(501)) == "vendor", "zuletzt verkauft beim Haendler")
check(mod:LastBuy(502) == 250 and select(4, mod:LastBuy(502)) == "cod", "Nachnahme")
check(mod:LastBuy(503) == 300 and select(4, mod:LastBuy(503)) == "trade", "Handel mit Gold")
check(mod:LastBuy(504) == 400, "Auktionskauf, Ware noch in der Post (Menge aus dem Kauf)")
check(mod:LastBuy(9999) == nil, "ohne Kauf: nil")
-- Tooltip: zuletzt gezahlt, auch ohne Bestand
tt.lines = {}; tt.link = "|cffffffff|Hitem:504::::|h[X]|h|r"; ttPost(tt, {})
check(#tt.lines == 1 and tt.lines[1]:find("Umschalt", 1, true), "ohne Bestand: nur Hinweis auf Umschalt")
shift = true; tt.lines = {}; ttPost(tt, {}); shift = false
check(tt.lines[1] and tt.lines[1]:find("Zuletzt gezahlt", 1, true), "Tooltip: zuletzt gezahlt mit Umschalt (" .. tostring(tt.lines[1]) .. ")")
ns.Tooltip.SetPreset("full")
shift = true; tt.lines = {}; tt.link = "|cffffffff|Hitem:500::::|h[X]|h|r"; ttPost(tt, {}); shift = false
ns.Tooltip.SetPreset("standard")
local hasBuy, hasSale
for _, l in ipairs(tt.lines) do if l:find("Zuletzt gezahlt", 1, true) then hasBuy = true end if l:find("Zuletzt verkauft", 1, true) then hasSale = true end end
check(hasBuy and hasSale, "Tooltip mit Umschalt: letzter Kauf und Verkauf")
-- bleibt nach dem Zusammenfassen
LB.Persist()
realm.moves = {}
Mv.Changed()
check(mod:LastBuy(500) == 150 and mod:LastSale(501) == 10, "nach dem Zusammenfassen gemerkt")
LB.Clear()
check(mod:LastBuy(500) == nil, "Buch zurueckgesetzt: beginnt leer")
realm.moves = saved
Mv.Changed()
end)()

;(function()
-- ----- E5/E7: Postfenster -----
local MA, I = ns.Mail, ns.Inventory
local showing
SetSendMailShowing = function(on) showing = on end
C_Container.CalculateTotalNumberOfFreeBagSlots = function() return 10 end
inbox = {
  { nil, nil, "Auktionshaus der Allianz", "Auktion erfolgreich: Bronzebarren", 1900, 0, 29.5, nil },
  { nil, nil, "Auktionshaus der Allianz", "Auktion gewonnen: Wollstoff", 0, 0, 2.5, 1 },
  { nil, nil, "Bob Baum", "Ware", 0, 500, 0.5, 1 },
  { nil, nil, "Kesha", "Willkommen", 0, 0, 20, nil },
}
GetInboxItem = function(i, a) if a ~= 1 then return end if i == 2 then return "Wollstoff", 2592, 1, 20, 1 elseif i == 3 then return "Ware", 5005, 1, 2, 1 end end
GetInboxInvoiceInfo = function(i) if i == 1 then return "seller", "Bronzebarren", "Bob", 0, 2000, 0, 100, nil, nil, nil, 2 elseif i == 2 then return "buyer", "Wollstoff", "Bob", 0, 600, 0, 0 end end
fire("MAIL_SHOW"); fire("MAIL_INBOX_UPDATE")
check(MA.win and MA.open and MA.tab == "inbox", "Briefkasten: Peon Post offen, Seite Eingang")
local rows = MA.table.items
local by = {}
for _, r in ipairs(rows) do by[r.kind] = r end
check(#rows == 4 and by.sale and by.buy and by.player and by.system, "vier Briefe: Verkauf, Kauf, Spieler, System")
check(by.sale.content == "Bronzebarren ×2" and by.sale.profit and by.buy.content:find("Wollstoff ×20", 1, true), "Inhalt aus Rechnung bzw. Anhang, Gewinn beim Verkauf")
check(by.player.cod == 500 and MA.DaysText(0.5):find("Std", 1, true) and MA.DaysText(2.5):find("2", 1, true), "Nachnahme und Ablauf")
check(ns.Plural(1, "MAIL_L_LETTERS") == "1 Brief" and ns.Plural(3, "MAIL_L_LETTERS") == "3 Briefe", "0.14.1: Einzahl und Mehrzahl")
check(MA.sum.sale == 1 and MA.sum.soon == 2 and MA.sum.cod == 1 and MA.sum.ah == 2, "Summen links")
check(MA.btnAH.text:find("Auktionshaus-Post (", 1, true) and not MA.btnAH.text:find("(2 ", 1, true) and MA.btnAH.text:find("SilverIcon", 1, true), "0.14.1: Knopf Auktionshaus-Post nur mit Gold: " .. tostring(MA.btnAH.text))
check(by.sale.letter.invoice.gross == 2000, "0.14.1: Verkaufspreis = Gold im Brief + Anteil - Einzahlung (Forever: Sofortkauf-Feld ist die Menge)")
-- Brief nur mit Text: Klick liest
local textRow = by.system
check(MA.TextOnly(textRow) and not MA.TextOnly(by.sale), "Brief ohne Gold und Anhang erkannt")
GetInboxText = function(i) return i == 4 and "Hallo Welt" or "" end
InboxItemCanDelete = function() return true end
local deleted
DeleteInboxItem = function(i) deleted = i end
MA.table.o.onClick(textRow, "LeftButton")
check(MA.reading == textRow and MA.reader.body.text == "Hallo Welt" and MA.reader.del.text == "Löschen", "Klick auf Textbrief: lesen mit Loeschen")
MA.DeleteOrReturn()
Peon.UI.dialog.onYes()
check(deleted == 4 and not MA.reading, "Loeschen nach Rueckfrage")
MA.table.o.onClick(by.sale, "RightButton")
check(MA.reading == by.sale, "Rechtsklick liest jeden Brief")
MA.CloseReader()
check(MA.statusText:find("10 Taschenplätze frei", 1, true), "Statuszeile: freie Plaetze")
mod.db.mailFilter = "sale"; MA.Refresh()
check(#MA.table.items == 1, "Filter Verkaeufe")
mod.db.mailFilter = "all"; MA.Refresh()
-- Einsammeln: nur Auktionshaus, nie Nachnahme
local taken = {}
local oM, oI = TakeInboxMoney, TakeInboxItem
TakeInboxMoney = function(i) taken[#taken + 1] = "money" .. i; return oM(i) end
TakeInboxItem = function(i, a) taken[#taken + 1] = "item" .. i .. ":" .. tostring(a); return oI(i, a) end
timers = {}
MA.Collect("ah")
check(taken[1] == "money1" and MA.run, "Einsammeln: zuerst das Gold des Verkaufs")
table.remove(inbox, 1)
GetInboxItem = function(i, a) if a ~= 1 then return end if i == 1 then return "Wollstoff", 2592, 1, 20, 1 elseif i == 2 then return "Ware", 5005, 1, 2, 1 end end
GetInboxInvoiceInfo = function(i) if i == 1 then return "buyer", "Wollstoff", "Bob", 0, 600, 0, 0 end end
local list = timers; timers = {}; for _, f in ipairs(list) do f() end
check(taken[2] == "item1:1", "dann die gekaufte Ware")
table.remove(inbox, 1)
GetInboxItem = function(i, a) if a == 1 and i == 1 then return "Ware", 5005, 1, 2, 1 end end
GetInboxInvoiceInfo = function() end
list = timers; timers = {}; for _, f in ipairs(list) do f() end
check(#taken == 2 and not MA.run and said("Post eingesammelt (2)"), "Nachnahme und Systembrief bleiben, fertig")
-- Klick auf Nachnahme fragt vorher
MA.Take({ index = 1, cod = 500, letter = {} })
check(Peon.UI.dialog and Peon.UI.dialog.onYes, "Nachnahme: Rueckfrage")
Peon.UI.dialog.onYes()
check(taken[3] == "item1:1", "nach Ja: bezahlt und genommen")
TakeInboxMoney, TakeInboxItem = oM, oI
-- Senden
local sent, setM
GetSendMailItem = function(i) if i == 1 then return "Leinenstoff", 2589, 1, 20, 1 end end
GetSendMailPrice = function() return 30 end
SetSendMailMoney = function(v) setM = v; return true end
SetSendMailCOD = function() end
local oS = SendMail
SendMail = function(to, subj, body) sent = { to, subj, body }; return oS(to, subj, body) end
MA.tabs:Select("send")
check(MA.tab == "send" and showing == true, "Seite Senden: Rechtsklick in der Tasche haengt an (SetSendMailShowing)")
MA.send.to:SetText("Borin"); MA.RefreshSend()
check(MA.send.slots[1].has and MA.send.attachValue.text:find("Umbuchung", 1, true), "Anhang und Hinweis: an Twink ist eine Umbuchung")
check(MA.send.cost.text:find("Porto", 1, true), "Porto angezeigt")
local items = {}
for _, it in ipairs(MA.Recipients()) do items[#items + 1] = it[1] end
check(table.concat(items, ","):find("Borin", 1, true), "Empfaenger: Liste der Twinks")
MA.Send()
check(sent and sent[1] == "Borin" and sent[2] == "Leinenstoff (20)" and setM == 0, "Abschicken: Betreff aus dem Anhang")
fire("MAIL_SEND_SUCCESS")
check(mod.db.mailRecent[1] == "Borin" and said("Brief an Borin abgeschickt"), "zuletzt angeschrieben gemerkt")
SendMail = oS
MA.tabs:Select("inbox")
check(showing == false, "zurueck im Eingang: Senden aus")
-- eigenes Fenster zu: Briefkasten schliessen
local closed
CloseMail = function() closed = true end
MA.OnWindowHide()
check(closed, "Fenster zu (ESC): Briefkasten wird geschlossen")
fire("MAIL_CLOSED")
check(not MA.open, "Briefkasten zu")
-- Einstellung: Blizzards Postfach
mod.db.mailWindow = false
fire("MAIL_SHOW")
check(not MA.Replacing(), "Einstellung aus: Blizzards Postfach")
fire("MAIL_CLOSED")
mod.db.mailWindow = true
inbox = {}
end)()

;(function()
-- ----- 0.14.3: Startbestand ist Sondereinnahme, Reihenfolge einstellbar -----
do
  local me = realm.chars["Mirel Dorna"]
  local keepS, keepM, keepB = me.start, realm.moves, realm.lotBase
  local t0 = time() - 1000
  realm.lotBase = nil
  me.start = { t = t0, places = { bags = { t = t0, items = { [7001] = 10 } } } }
  Peon.modules.broker = { ItemValue = function(_, id, n) return 100 * (n or 1) end }
  local function run(order)
    mod.db.costOrder = order
    realm.moves = {
      { t = t0 + 10, c = "Mirel Dorna", k = "ahbuy", id = 7001, n = 5, m = -1500 },             -- 5 gekauft zu 3s
      { t = t0 + 20, c = "Mirel Dorna", k = "ahsold", id = 7001, n = -5, m = 2000, q = 5 },     -- 5 verkauft fuer 20s
      { t = t0 + 30, c = "Mirel Dorna", k = "ahsold", id = 7001, n = -7, m = 2800, q = 7 },     -- 7 verkauft fuer 28s
    }
    ns.Cost.Invalidate()
    return ns.Cost.Result(realm.moves[2]), ns.Cost.Result(realm.moves[3]), ns.Book.Collect("all", false)
  end
  local a, b, bk = run("lifo")
  check(a.sale and math.abs(a.profit - 500) < 0.01 and not a.special, "neueste zuerst: gekaufte Ware geht zuerst, Gewinn 5s")
  check(b.special and not b.sale and math.abs(b.special - 2800) < 0.01, "danach Startbestand: Sondereinnahme, kein Handelsgewinn")
  check(math.abs(bk.trade - 500) < 0.01 and math.abs(bk.special - 2800) < 0.01 and bk.kinds.special.inc == 2800 and bk.kinds.ahsold.inc == 2000, "Buch: Handelsgewinn nur aus gekaufter Ware")
  a, b, bk = run("fifo")
  check(a.special and not a.sale and math.abs(a.special - 2000) < 0.01, "aelteste zuerst: erst der Startbestand (Sondereinnahme)")
  check(b.sale and math.abs(b.special - 2800 * 5 / 7) < 0.01 and math.abs(b.profit - (2800 * 2 / 7 - 600)) < 0.01, "gemischter Verkauf: anteilig Sondereinnahme und Handelsgewinn")
  mod.db.costOrder = "lifo"
  check(select(2, ns.Cost.Peek(7001, 3)) == 0, "Vorschau ohne Entnahme")
  Peon.modules.broker = nil
  me.start, realm.moves, realm.lotBase = keepS, keepM, keepB
  ns.Cost.Invalidate()
end
-- ----- 0.14.5: Startbestand Kosten 0, offener Gewinn, Diagramm, Info -----
do
  local me = realm.chars["Mirel Dorna"]
  local keepS, keepM, keepB, keepT = me.start, realm.moves, realm.lotBase, realm.trend
  local t0 = time() - 3 * 86400
  realm.lotBase = nil
  me.start = { t = t0, places = { bags = { t = t0, items = { [7101] = 4, [7102] = 2 } } } }
  realm.moves = {
    { t = t0 + 10, c = "Mirel Dorna", k = "craft", id = 7101, n = -4, x = "Rezept" },   -- nur Startbestand verbraucht
    { t = t0 + 10, c = "Mirel Dorna", k = "craft", id = 7103, n = 1, x = "Rezept" },
    { t = t0 + 20, c = "Mirel Dorna", k = "ahbuy", id = 7102, n = 3, m = -300 },         -- 3 gekauft zu 1s
    { t = t0 + 30, c = "Mirel Dorna", k = "ahsold", id = 7102, n = -1, m = 250, q = 1 }, -- neueste zuerst: gekauft
  }
  ns.Cost.Invalidate()
  local p = ns.Cost.Info(7103)
  check(p and p.n == 1 and p.sn == 1 and p.value == 0, "Hergestelltes nur aus Startbestand bleibt Startbestand (Kosten 0)")
  check(ns.Cost.Result(realm.moves[4]).sale and math.abs(ns.Cost.Result(realm.moves[4]).profit - 150) < 0.01, "Verkauf gekaufter Ware: Gewinn 1s 50c")
  -- offener Gewinn im Bestand: 2 gekaufte zu 1s, 2 Startbestand, Marktwert 2s je Stueck
  local keepP = me.places
  me.places = { bags = { t = 1, items = { [7102] = 4 } } }
  Peon.modules.broker = { ItemValue = function(_, id, n) return 200 * (n or 1) end }
  ns.Window.Select("stock"); mod.db.stockChar = "*"; mod.db.stockPlace = "all"; mod.db.stockCat = "all"
  ns.Stock.search = nil; if ns.Stock.searchBox then ns.Stock.searchBox:SetText("") end
  ns.Window.Refresh()
  local row for _, r in ipairs(ns.Stock.table.items) do if r.id == 7102 then row = r end end
  check(row and row.startN == 2 and math.abs(row.open - (2 * 200 - 200)) < 0.01, "offener Gewinn: nur gekaufte Stuecke (2 x 2s Marktwert - 2s Kosten)")
  -- Verlauf fuer das Diagramm
  realm.trend = {}
  local T0 = time()
  ns.Trend.Record(true, T0 - 5 * 3600)
  money = money + 5000; ns.Inventory.ScanMoney()
  ns.Trend.Record(false, T0 - 5 * 3600 + 30)
  check(#realm.trend == 1, "hoechstens ein Stand je Minute")
  ns.Trend.Record(true, T0 - 3600)
  check(#realm.trend == 2 and realm.trend[2].w ~= nil, "Stand mit Gold und Vermoegen")
  local d = ns.Trend.Series("d1", T0)
  check(d.n == 24 and d.gold[1] == nil and d.gold[20] == realm.trend[1].g and d.gold[24] == realm.trend[2].g, "Reihe 1 Tag: 24 Stunden, vor dem ersten Stand leer")
  -- 0.14.6: Daten erst seit kurzem: links beginnen, rechts leer
  local keepMv = realm.moves
  realm.moves = {}
  local keepTr = realm.trend
  realm.trend = { { t = T0 - 2 * 3600, g = 100 }, { t = T0 - 600, g = 200 } }
  local dl = ns.Trend.Series("d1", T0)
  check(dl.from == T0 - 2 * 3600 and dl.gold[1] == 100 and dl.last == 2 and dl.gold[2] == 200 and dl.gold[3] == nil and dl.gold[24] == nil, "0.14.6: beginnt links beim ersten Wert, Zukunft leer")
  realm.trend = keepTr
  realm.moves = keepMv
  local d7 = ns.Trend.Series("d7", T0)
  check(d7.last and d7.last < d7.n and d7.trade[d7.last] and math.abs(d7.trade[d7.last] - 150) < 0.01, "Handelsgewinn im Zeitraum aufsummiert (Zeitraum noch nicht voll)")
  realm.trend = { { t = T0 - 10 * 86400, g = 1 }, { t = T0 - 10 * 86400 + 60, g = 2 }, { t = T0 - 2 * 86400, g = 3 }, { t = T0 - 2 * 86400 + 120, g = 4 }, { t = T0 - 60, g = 5 } }
  check(ns.Trend.Thin(T0) == 2 and realm.trend[1].g == 2 and realm.trend[2].g == 4, "Ausduennen: alt ein Stand je Tag bzw. je Stunde")
  ns.Window.Select("overview")
  check(ns.Overview.chart and ns.Overview.series and #ns.Overview.rangeButtons == 5, "Diagramm in der Uebersicht mit fuenf Zeitraeumen")
  ns.Overview.rangeButtons[1].scripts.OnClick()
  check(mod.db.trendRange == "d1" and ns.Overview.series.key == "d1", "Zeitraum waehlen")
  ns.Overview.ChartHover(24)
  check(ns.Overview.chartInfo.text:find("Gold", 1, true), "Werte unter der Maus")
  mod.db.trendRange = "d7"
  -- Info
  realm.moves[#realm.moves + 1] = { t = time(), c = "Mirel Dorna", k = "diff", id = 7102, n = -1, x = "Kontrollrechnung" }
  ns.Moves.Changed()
  ns.Window.Select("info")
  check(#ns.Info.terms >= 15 and ns.Info.terms[1].term == "Gold", "Info: Begriffe")
  check(#ns.Info.table.items == 1 and ns.Info.table.items[1].id == 7102, "Info: verbuchte Abweichungen")
  check(ns.Info.open.text ~= "", "Info: offene Abweichungen")
  Peon.modules.broker = nil
  me.start, realm.moves, realm.lotBase, realm.trend, me.places = keepS, keepM, keepB, keepT, keepP
  ns.Cost.Invalidate()
  ns.Window.Select("overview")
end
-- 0.14.5: frueher gespeicherter Startbestand mit Marktwert wird beim Laden 0
do
  local keepB, keepM = realm.lotBase, realm.moves
  realm.moves = {}
  realm.lotBase = { untilT = time() + 1000, chars = { ["Mirel Dorna"] = { lots = { [7201] = { { t = 1, n = 3, c = 500, s = true }, { t = 2, n = 1, c = 300 } } }, fee = {} } }, transit = {} }
  ns.Cost.Invalidate()
  local i = ns.Cost.Info(7201)
  check(i.n == 4 and i.value == 300 and i.sn == 3, "alter Startbestand im gespeicherten Stand: Kosten 0, gekaufte bleiben")
  realm.lotBase, realm.moves = keepB, keepM
  ns.Cost.Invalidate()
end
-- ----- einmaliger Neustart des Buchs (ab 0.14) -----
-- 0.14.1: Kosten aus dem bisherigen Verlauf bleiben, fehlende Stueck zum Marktwert
do
  local me = realm.chars["Mirel Dorna"]
  local keepS, keepM, keepB, keepP = me.start, realm.moves, realm.lotBase, me.places
  for name in pairs(realm.chars) do if name ~= "Mirel Dorna" then realm.chars[name] = nil end end
  local t0 = time() - 1000
  me.start = { t = t0 - 10, places = {} }
  realm.lotBase = nil
  realm.moves = { { t = t0, c = "Mirel Dorna", k = "ahbuy", id = 2589, n = 10, m = -1000 },     -- 10 zu 1s
                  { t = t0 + 1, c = "Mirel Dorna", k = "ahbuy", id = 2589, n = 10, m = -3000 } } -- 10 zu 3s
  ns.Cost.Invalidate()
  BAGS[0] = { { itemID = 2589, stackCount = 15 }, { itemID = 4306, stackCount = 2 } }
  BAGS[1] = nil
  me.places.bank = { t = 1, items = {} }
  Peon.modules.broker = { ItemValue = function(_, id, n) return 50 * (n or 1) end }
  ns.Moves.ResetBook()
  ns.Cost.Invalidate()
  local info = ns.Cost.Info(2589)
  check(info and info.n == 15 and info.value == 0 and info.sn == 15, "0.14.5: Zuruecksetzen: alles ist Startbestand mit Kosten 0")
  check(ns.Cost.Info(4306).next == 0 and ns.Cost.Info(4306).sn == 2, "auch ohne bisherige Kosten")
  check(mod:LastBuy(2589) == 300, "zuletzt gezahlt bleibt beim Zuruecksetzen")
  Peon.modules.broker = nil
  me.start, realm.moves, realm.lotBase, me.places = keepS, keepM, keepB, keepP
  ns.Inventory.RealmData().last = nil
  ns.Last.dirty = true
  ns.Cost.Invalidate()
end
realm.bookV = nil
local keep = realm.moves
realm.moves = { { t = time(), c = "Mirel Dorna", k = "loot", id = 2589, n = 1 } }
local meC = realm.chars["Mirel Dorna"]
local keepA = meC.places.auctions
meC.places.auctions = { t = 1, items = { [2840] = 4 } }
meC.places.mail = meC.places.mail or { t = 1, items = {} }
meC.places.mail.list = { { m = 500, ah = true, sold = "Bronzebarren", q = 2 } }
check(ns.MigrateBook() == true and #realm.moves == 0 and realm.bookV == 4 and said("neu aufgebaut"), "Neuaufbau: Buch einmal neu begonnen (ab 0.14.3 Stand 4)")
local pre = realm.pre["Mirel Dorna"]
check(pre and pre.auctions[2840] == 4 and pre.sold["Bronzebarren"] == 2, "0.14.2: laufende Auktionen und Verkaufsbriefe beim Neustart gemerkt")
-- Erloes einer gemerkten Auktion: Sondereinnahme, kein Handelsgewinn
local sp = ns.Moves.Add("ahsold", 2840, nil, 900, "Kupferbarren ×4"); sp.q = 4
ns.Moves.MarkSpecial(sp, "Kupferbarren")
local sp2 = ns.Moves.Add("ahsold", 2841, nil, 500, "Bronzebarren ×2"); sp2.q = 2
ns.Moves.MarkSpecial(sp2, "Bronzebarren")
local sp3 = ns.Moves.Add("ahsold", 2840, nil, 300, "Kupferbarren"); sp3.q = 1
ns.Moves.MarkSpecial(sp3, "Kupferbarren")
ns.Cost.Invalidate()
local bk = ns.Book.Collect("all", false)
check(sp.sp and sp2.sp and not sp3.sp and not pre.auctions[2840] and not pre.sold["Bronzebarren"], "Sondereinnahme fuer gemerkte Auktion und Brief, danach wieder normal")
check(bk.special == 1400 and bk.kinds.special.inc == 1400 and bk.nsales == 1 and ns.Moves.Label(sp) == "Sondereinnahme", "Buch: Sondereinnahme eigene Art, kein Handelsgewinn (der Startbestand von 4 ist danach verbraucht)")
check(ns.Cost.Result(sp).special == 900 and not ns.Cost.Result(sp).sale, "Kosten: Sondereinnahme ist kein Verkauf")
meC.places.auctions = keepA
meC.places.mail.list = nil
realm.pre = nil
realm.moves = {}
realm.moves = { { t = time(), c = "Mirel Dorna", k = "loot", id = 2589, n = 1 } }
check(ns.MigrateBook() == false and #realm.moves == 1, "nur einmal")
realm.moves = keep
ns.Moves.Changed()
check(mod.AddNotice and mod:AddNotice({ id = "neuaufbau-2026-11", title = "x" }) == false, "Hinweis zum Neuaufbau angemeldet (gleiche id ein zweites Mal abgelehnt)")
end)()


local n = 0 for _, l in ipairs(out) do if l:find("Fehler") then n = n + 1 end end
check(n == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
