-- Test fuer Peon_Bridge (bis 0.3.0 Peon_Client, Verbindung zum Peon Manager) mit echtem Kern und Peon_Broker.
-- Nachgebaute Auktionshaus-Schnittstelle wie in test_broker.lua. Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
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
local meta = { Peon = TocMeta("Peon"), Peon_Broker = TocMeta("Peon_Broker"), Peon_Bridge = TocMeta("Peon_Bridge") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function(a) return a ~= "Blizzard_AuctionUI" end, GetNumAddOns = function() return 3 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Broker", "Peon_Bridge" })[i] end }
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
local loaded = {}
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then local skip = dir == "Peon_Bridge" and l == "Data.lua" local f = not skip and io.open(dir .. "/" .. l) if f then f:close(); assert(loadfile(dir .. "/" .. l))(addon, ns); loaded[#loaded+1] = dir .. "/" .. l elseif not skip then error("Datei fehlt: " .. l) end end end return ns end
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

-- Forever-Lua: %d (und %i, %x, %c) nur bis 2^31, sonst "integer overflow attempting to store ..." (gefunden 22.10.2026)
do
  local rawformat = string.format
  string.format = function(fmt, ...)
    local args, i = { ... }, 0
    for spec in fmt:gmatch("%%[%-%+ #0]*%d*%.?%d*([%a%%])") do
      if spec ~= "%" then
        i = i + 1
        local v = args[i]
        if (spec == "d" or spec == "i" or spec == "x" or spec == "c") and type(v) == "number" and (v > 2147483647 or v < -2147483648) then
          error("integer overflow attempting to store " .. rawformat("%.0f", v), 2)
        end
      end
    end
    return rawformat(fmt, ...)
  end
end

-- ===== Laden: echter Kern, Broker, Peon_Bridge (Data.lua fehlt wie nach dem ersten Einbau) =====
local reloads = 0
function ReloadUI() reloads = reloads + 1 end
load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
local nsb = load("Peon_Broker", "Peon_Broker")
fire("ADDON_LOADED", "Peon_Broker")
PeonBridgeDB = nil
PeonBridgeData = nil
local ns = load("Peon_Bridge", "Peon_Bridge")
fire("ADDON_LOADED", "Peon_Bridge")
fire("PLAYER_LOGIN")
local mod, E = ns.mod, ns.Export
local B = nsb.mod
check(mod.initialized and Peon:GetModule("bridge") == mod, "Modul beim echten Kern angemeldet")
check(meta.Peon_Bridge.Version ~= nil and mod.version == meta.Peon_Bridge.Version, "Version aus der TOC: " .. tostring(mod.version))
check(meta.Peon_Bridge.Dependencies == "Peon" and meta.Peon_Bridge.OptionalDeps == "Peon_Broker" and meta.Peon_Bridge.SavedVariables == "PeonBridgeDB", "TOC: Abhaengigkeiten und SavedVariables")
local hasData = false for _, f in ipairs(loaded) do if f == "Peon_Bridge/Data.lua" then hasData = true end end
check(not hasData and ns.ManagerData() == nil, "ohne Data.lua: laeuft, keine Werte des Managers (echte Data.lua wird im Test nie geladen)")
local ph = io.open("Peon_Bridge/Data.lua")
if ph then local txt = ph:read("*a"); ph:close(); local env = {}; local fn = assert(loadstring(txt)); setfenv(fn, env); fn(); check(true, "Data.lua laesst sich laden" .. (env.PeonBridgeData and " (Werte des Managers)" or " (Platzhalter)")) end
check(meta.Peon_Bridge.Title == "|cff8ccf4dPeon|r Bridge" and mod.key == "bridge", "Titel und Modul-Schluessel")
check(type(PeonBridgeDB.queue) == "table" and #PeonBridgeDB.queue == 0 and PeonBridgeDB.fmt == 1, "Warteschlange angelegt, Format 1")
check(PeonBridgeDB.queueMax == 10 and PeonBridgeDB.liveMax == 500 and PeonBridgeDB.offerButton == nil, "Standardwerte 10 / 500, ab 0.9.2 kein Knopf An Manager")
check(ns.channels.broker and ns.channelOrder[1] == "broker", "Kanal broker angemeldet")

-- ===== Ohne Freischaltung: nichts aufzeichnen, keine Werte fuer Broker (0.4.0) =====
check(not ns.ChannelOn("broker") and not ns.hooked and #nsb.listeners == 0, "ohne Data.lua: Kanal aus, kein Zuhoerer bei Broker")
local st0 = table.concat(ns.StatusLines(), "|")
check(st0:find("Kanal broker nicht freigeschaltet", 1, true) and st0:find("Es wird nichts aufgezeichnet", 1, true) and st0:find("noch keine Werte", 1, true), "Stand: Kanal nicht freigeschaltet")
local MK0 = "Classic Beta PvE / Horde"
local vals = { [MK0] = { t = clock, items = { [2589] = "100:1000:95:12:eb" }, sales = { [2589] = "4800:70:240" } } }
PeonBridgeData = { fmt = 1, t = clock, ack = {}, markets = vals }
check(not ns.ChannelOn("broker") and mod:LongTerm(2589, MK0) == nil and mod:Sales(2589, MK0) == nil, "altes Format ohne channels: nichts freigeschaltet, keine Werte")
PeonBridgeData = { fmt = 2, t = clock, manager = "0.6.0", ack = {}, markets = vals }
check(not ns.ChannelOn("broker") and mod:LongTerm(2589, MK0) == nil, "Format 2 ohne channels: nichts freigeschaltet")
PeonBridgeData.channels = { broker = false, ledger = true }
check(not ns.ChannelOn("broker") and mod:LongTerm(2589, MK0) == nil and nsb.Data.ClientBand(2589) == nil, "broker = false: keine Werte, Broker rechnet selbst")
check(ns.StartChannels() == 0 and not ns.hooked, "nicht freigeschaltet: Kanal startet nicht")
PeonBridgeData.channels.broker = true
check(ns.ChannelOn("broker") and mod:LongTerm(2589, MK0) ~= nil and mod:Sales(2589, MK0) ~= nil, "freigeschaltet: Werte fuer Broker")
PeonBridgeData = nil   -- fuer den ersten Scan wieder ohne Manager
check(mod.page ~= nil and cats.Peon and table.concat(cats.Peon.subs, ",") == "Broker,Bridge", "Optionsseite Peon > Bridge")
check(#Peon.GetFeedbackAreas("Peon_Bridge") == 5, "Bereiche fuer Peon_Feedback gemeldet")
check(StaticPopupDialogs == POPUPS and POPUPS.PEON_BRIDGE_CLEAR, "StaticPopupDialogs nicht neu zugewiesen")

-- ===== Bausteine =====
check(E.Bonus("|cff1eff00|Hitem:6611::::::::20:1488:::1:12731:::::|h[Klinge des Wolfs]|h|r") == "12731", "Bonus-Nummer aus Forever-Link")
check(E.Bonus("|Hitem:1::::::::20:1488:::2:10:20:::|h[x]|h") == "10,20", "mehrere Bonus-Nummern")
check(E.Bonus("|cff1eff00|Hitem:15000::::::1047::20:::::::::|h[Schwert]|h|r") == "" and E.Bonus(nil) == "", "ohne Bonus leer")
check(E.BandFromSeconds(1800) == 1 and E.BandFromSeconds(1801) == 2 and E.BandFromSeconds(7200) == 2 and E.BandFromSeconds(43200) == 3 and E.BandFromSeconds(43201) == 4 and E.BandFromSeconds(nil) == nil, "Restzeit-Stufe aus Sekunden")
check(E.Line(2770, "", nil, 20, 2400, nil, nil, 3, nil) == "2770;;;20;2400;;;3;", "Zeile: Felder wie Blizzard")
check(E.Line(1, "", "a;b\nc", 1, 1e11, nil, nil, 7, 5) == "1;;a b c;1;100000000000;;;;5", "Zeile: Name bereinigt, grosse Zahl, falsche Stufe leer")

-- ===== Komplettscan =====
LISTINGS = {
  { "Kupfererz", 2770, 20, 1, 20 * 120 },
  { "Kupfererz", 2770, 20, 1, 20 * 120 },          -- voellig gleich -> n = 2
  { "Kupfererz", 2770, 5, 1, 5 * 120, nil, 2 },    -- andere Menge und Restzeit
  { "Leinenstoff", 2589, 1, 1, 0, nil, 4, 50, 0 }, -- nur Gebot (Mindestgebot 50)
  { "Leinenstoff", 2589, 3, 1, 90, nil, 1, 40, 60 }, -- Sofortkauf und Gebot 60
  { "Klinge des Wolfs", 6611, 1, 2, 9000, "|cff1eff00|Hitem:6611::::::::20:1488:::1:12731:::::|h[Klinge des Wolfs]|h|r" },
  { "Klinge des Baeren", 6611, 1, 2, 7000, "|cff1eff00|Hitem:6611::::::::20:1488:::1:12732:::::|h[Klinge des Baeren]|h|r" },
  { "Klinge des Wolfs", 6611, 1, 2, 9000, "|cff1eff00|Hitem:6611::::::::20:1488:::1:12731:::::|h[Klinge des Wolfs]|h|r" },
}
C_AuctionHouse.GetReplicateItemInfo = function(i) local l = LISTINGS[i + 1]
  return l[1], 1, l[3], l[4], true, 10, "REQ_LEVEL_ABBR", l[8] or 0, 0, l[5], l[9] or 0, nil, nil, nil, nil, 0, l[2], true end
function GetCurrentRegion() return 3 end
local S = nsb.Scan
fire("AUCTION_HOUSE_SHOW")
local function RunScan()
  clock = clock + 1000
  SlashCmdList.PEON_BROKER("scan")
  fire("REPLICATE_ITEM_LIST_UPDATE")
  local g = 0
  while S.state and g < 100000 do S.Step(); g = g + 1 end
end
S.CHUNK, S.SUM_CHUNK = 3, 2
RunScan()
check(#PeonBridgeDB.queue == 0 and nsb.Data.Market().items[2770] ~= nil, "ohne Freischaltung: Broker scannt, die Bridge zeichnet nichts auf")
check(not (_G.PeonBridgeSendButton and _G.PeonBridgeSendButton.shown), "ohne Freischaltung: kein Knopf \"An Manager\"")
-- Manager schreibt Data.lua mit Freischaltung, Spiel laedt neu (INIT/LOGIN starten den Kanal)
PeonBridgeData = { fmt = 2, t = clock, manager = "0.6.0", channels = { broker = true }, ack = {} }
check(ns.StartChannels() == 1, "freigeschalteter Kanal startet")
check(ns.hooked == true and #nsb.listeners == 1 and nsb.listeners[1] == E.OnSnapshot, "freigeschaltet: bei Broker als Zuhoerer angemeldet")
check(ns.StartChannels() == 1 and #nsb.listeners == 1, "zweiter Start meldet nicht doppelt an")
check(B:AddSnapshotListener(E.OnSnapshot) == true and #nsb.listeners == 1, "doppelte Anmeldung wird ignoriert")
check(B:AddSnapshotListener("x") == false, "nur Funktionen als Zuhoerer")
local st1 = table.concat(ns.StatusLines(), "|")
check(st1:find("Kanal broker freigeschaltet", 1, true) and st1:find("Version 0.6.0", 1, true), "Stand: Kanal broker freigeschaltet, Version des Managers")
RunScan()
local q = PeonBridgeDB.queue
check(#q == 1 and q[1].kind == "scan", "Scan liegt in der Warteschlange")
local e = q[1]
check(e.market == "Classic Beta PvE / Horde" and e.realm == "Classic Beta PvE" and e.faction == "Horde" and e.region == 3, "Kopf: Markt, Realm, Fraktion, Region")
check(e.t == clock and e.char == "Mirel" and e.build == "1.60.1.70009" and e.broker == meta.Peon_Broker.Version and e.fmt == 1, "Kopf: Zeit, Charakter, Build, Broker-Version, Format")
check(e.id == clock .. "-1" and e.total == 8 and e.offers == 8 and e.lines == 6 and e.partial == false, "Kopf: Nummer, 8 Angebote in 6 Zeilen")
local lines = {} for l in (e.rows .. "\n"):gmatch("([^\n]*)\n") do lines[#lines+1] = l end
check(lines[1] == "2770;;;20;2400;;;3;;2", "gleiche Angebote zusammengezaehlt: " .. lines[1])
check(lines[2] == "2770;;;5;600;;;2;;1", "andere Menge/Restzeit eigene Zeile: " .. lines[2])
check(lines[3] == "2589;;;1;0;;50;4;;1", "reines Gebot mit Mindestgebot: " .. lines[3])
check(lines[4] == "2589;;;3;90;;60;1;;1", "Sofortkauf mit Gebot: " .. lines[4])
check(lines[5] == "6611;12731;Klinge des Wolfs;1;9000;;;3;;2", "Variante mit Bonus und vollem Namen: " .. lines[5])
check(lines[6] == "6611;12732;Klinge des Baeren;1;7000;;;3;;1", "zweite Variante getrennt: " .. lines[6])
check(e.names and e.names[2770] == "Kupfererz|1|5|1" and e.names[2589] == "Leinenstoff|1|10|1", "Namen mit Haendlerpreis und Warenart (0.3.0): " .. tostring(e.names and e.names[2770]))
check(type(e.names[6611]) == "string" and e.names[6611]:match("^|2|0|"), "Variante: ohne Namen, mit Haendlerpreis: " .. tostring(e.names[6611]))
local market = nsb.Data.Market()
check(market.items[2770].m == 120 and market.items[2589].m == 30, "Broker rechnet unveraendert")
check(_G.PeonBridgeSendButton == nil, "0.9.2: nach dem Scan kein Knopf An Manager")
fire("AUCTION_HOUSE_CLOSED")
fire("AUCTION_HOUSE_SHOW")

-- ===== Live-Abfragen =====
local D = nsb.Data
local rows = { { price = 118, qty = 10, own = 0 }, { price = 120, qty = 30, own = 0 }, commodity = true,
  offers = { { id = 111, q = 10, p = 118, secs = 1000 }, { id = 112, q = 30, p = 120, secs = 50000 } } }
D.ApplyLive(2770, rows, clock)
check(#q == 2 and q[2].kind == "live" and q[2].key == "2770" and q[2].commodity == true and q[2].partial == false, "Live-Abfrage abgelegt")
check(q[2].rows == "2770;;;10;;118;;1;111;1\n2770;;;30;;120;;4;112;1", "Live: Stueckpreis, Auktionsnummer, Restzeit aus Sekunden")
D.ApplyLive(2770, rows, clock + 30)
check(#PeonBridgeDB.queue == 2, "gleiche Abfrage innerhalb 60 Sek. nicht doppelt")
D.ApplyLive(2770, rows, clock + 61)
check(#PeonBridgeDB.queue == 3, "nach 60 Sek. wieder abgelegt")
D.ApplyLive(2770, { partial = true, commodity = true }, clock + 70)
check(#PeonBridgeDB.queue == 3, "leer und unvollstaendig (laedt noch): nichts abgelegt")
D.ApplyLive(2770, { foreign = 2, commodity = true }, clock + 71)
check(#PeonBridgeDB.queue == 3, "Ergebnisse eines anderen Gegenstands: nichts abgelegt")
D.ApplyLive(2770, { commodity = true }, clock + 72)
q = PeonBridgeDB.queue
check(#q == 4 and q[4].rows == "" and q[4].offers == 0, "keine Angebote mehr: leere Aufnahme")
D.ApplyLive("6611:Klinge des Wolfs", { { price = 8000, qty = 1, own = 0 }, link = "|cff1eff00|Hitem:6611::::::::20:1488:::1:12731:::::|h[Klinge des Wolfs]|h|r",
  offers = { { id = 900, q = 1, p = 8000, band = 2 } } }, clock + 73)
check(q[5].key == "6611:Klinge des Wolfs" and q[5].rows == "6611;12731;Klinge des Wolfs;1;;8000;;3;900;1" and q[5].commodity == false, "Live Variante: Bonus, Name, Stufe 0-3 -> 1-4")
D.ApplyLive(2589, { { price = 30, qty = 5, own = 0 }, { price = 30, qty = 5, own = 0 }, partial = true }, clock + 74)
check(q[6].rows == "2589;;;5;;30;;;;2" and q[6].partial == true, "Live ohne Einzelangebote: zusammengefasste Stufen, Teil markiert")

-- ===== Grenzen der Warteschlange =====
mod.db.queueMax = 2
RunScan(); RunScan()
local scans, live = ns.QueueInfo()
check(scans == 2 and live == 5, "hoechstens 2 Komplettscans, aelteste weg")
check(PeonBridgeDB.queue[1].kind == "live", "aeltester Scan entfernt, Live-Abfragen bleiben")
mod.db.liveMax = 2
D.ApplyLive(2589, { { price = 31, qty = 1, own = 0 } }, clock + 80)
scans, live = ns.QueueInfo()
check(scans == 2 and live == 2, "hoechstens 2 Live-Abfragen")
mod.db.liveMax = 0
check(E.Live(2589, { { price = 32, qty = 1 } }, clock + 90) == nil, "Live-Abfragen abschaltbar (0)")
mod.db.queueMax, mod.db.liveMax = 10, 500

-- ===== Bestaetigung durch den Client (Data.lua) =====
q = PeonBridgeDB.queue
local firstScan
for _, x in ipairs(q) do if x.kind == "scan" and not firstScan then firstScan = x end end
check(firstScan.names and firstScan.names[2770], "Scan traegt noch Namen")
local ack = {} for _, x in ipairs(q) do ack[x.id] = true end
local n0 = #q
PeonBridgeData = { fmt = 2, manager = "0.6.0", channels = { broker = true }, t = clock + 100, ack = ack, markets = { ["Classic Beta PvE / Horde"] = { t = clock + 100, items = { [2770] = "x", [2589] = "y" } } } }
q[1].names = q[1].names or {}
q[1].names[4242] = "Unbekannt|1||"
check(ns.ApplyAck() == n0 and #PeonBridgeDB.queue == 0, "bestaetigte Aufnahmen geloescht")
check(PeonBridgeDB.nameIds[4242] == nil, "Name ohne Haendlerpreis gilt nicht als uebergeben (nochmal beim naechsten Scan)")
check(PeonBridgeDB.ackAt == clock + 100 and PeonBridgeDB.ackN == n0 and PeonBridgeDB.nameIds[2770] == true, "Bestaetigung gemerkt, Namen gelten als uebergeben")
local t, mk, it = ns.DataInfo()
check(t == clock + 100 and mk == 1 and it == 2, "Werte des Clients gezaehlt")
RunScan()
check(PeonBridgeDB.queue[1].names == nil, "naechster Scan ohne bekannte Namen")
-- 0.12.0: Stand von 0.11 (nameFmt 2) schickt alle Namen samt Haendlerpreis einmal neu
PeonBridgeDB.nameFmt = 2
ns.Prepare()
check(PeonBridgeDB.nameFmt == 3 and next(PeonBridgeDB.nameIds) == nil, "0.12.0: Namen einmal neu schicken")
PeonBridgeDB.nameIds[2770] = true
ns.Prepare()
check(PeonBridgeDB.nameIds[2770] == true, "0.12.0: nur einmal")
PeonBridgeData.ack = { ["nicht-da"] = true }
check(ns.ApplyAck() == 0 and #PeonBridgeDB.queue == 1, "fremde Bestaetigung loescht nichts")

-- ===== Abbruch und fehlerhafter Zuhoerer =====
clock = clock + 1000
SlashCmdList.PEON_BROKER("scan")
fire("REPLICATE_ITEM_LIST_UPDATE")
S.Step()
check(E.cur ~= nil, "Scan laeuft beim Client mit")
fire("AUCTION_HOUSE_CLOSED")
check(E.cur == nil and #PeonBridgeDB.queue == 1, "abgebrochener Scan wird verworfen")
fire("AUCTION_HOUSE_SHOW")
local bad = function() error("kaputt") end
B:AddSnapshotListener(bad)
check(#nsb.listeners == 2, "zweiter Zuhoerer angemeldet")
RunScan()
check(#nsb.listeners == 1 and nsb.listeners[1] == E.OnSnapshot and #PeonBridgeDB.queue == 2, "fehlerhafter Zuhoerer entfernt, Client arbeitet weiter")
check(said("Zuhoerer") or (function() for _, l in ipairs(out) do if l:find("kaputt", 1, true) then return true end end end)(), "Fehler einmal gemeldet")

-- ===== Fehler im Client bleiben im Client (0.1.2) =====
do
  local save, n0 = E.ScanRow, #PeonBridgeDB.queue
  E.ScanRow = function() error("Testfehler") end
  RunScan()
  E.ScanRow = save
  local er = PeonBridgeDB.errors and PeonBridgeDB.errors[1]
  check(er and er.kind == "scan_row" and er.err:find("Testfehler", 1, true) and er.version == mod.version, "Fehler im Client mit Art und Version gemerkt")
  check(#nsb.listeners == 1 and #PeonBridgeDB.queue == n0 and nsb.Data.Market().lastScan == clock, "Zuhoerer bleibt, Aufnahme verworfen, Broker-Scan fertig")
end
-- ===== Fehler in Brokers Scan (Broker 0.30.1) =====
do
  local saveS = nsb.Data.Summarize
  nsb.Data.Summarize = function() error("Summenfehler") end
  clock = clock + 1000
  SlashCmdList.PEON_BROKER("scan")
  fire("REPLICATE_ITEM_LIST_UPDATE")
  local g = 0
  while S.state and g < 100 do S.driver.scripts.OnUpdate(S.driver); g = g + 1 end
  nsb.Data.Summarize = saveS
  local le = PeonBrokerDB.lastScanError
  check(S.state == nil and g < 20 and le and le.err:find("Summenfehler", 1, true) and le.phase == "sum" and le.version == B.version, "Broker: Fehler beendet den Scan, Meldung gemerkt")
  check(said("wegen eines Fehlers abgebrochen") and E.cur == nil, "Hinweis im Chat, Client verwirft die Aufnahme")
end

-- ===== Angebot zum Hoechstpreis (fast 5 Mio. Gold, Broker 0.30.2) =====
do
  check(not pcall(string.format, "%d", 49999996000), "Testumgebung: %d mit grosser Zahl scheitert wie in Forever")
  LISTINGS = { { "Teurer Stein", 7777, 1, 1, 49999996000 }, { "Teurer Stein", 7777, 1, 1, 40000000000 }, { "Kupfererz", 2770, 20, 1, 2400 } }
  local n0 = #PeonBridgeDB.queue
  RunScan()
  local m2 = nsb.Data.Market()
  check(PeonBrokerDB.lastScanError == nil or PeonBrokerDB.lastScanError.t < clock, "Scan mit Hoechstpreis ohne Fehler")
  check(m2.lastScan == clock and m2.items[7777].m == 40000000000 and m2.items[7777].md >= 40000000000, "Broker speichert Preise ueber 2^31")
  check(m2.items[7777].d:find(":40000000000:", 1, true), "Tageswert mit grosser Zahl: " .. tostring(m2.items[7777].d))
  local e3 = PeonBridgeDB.queue[#PeonBridgeDB.queue]
  check(#PeonBridgeDB.queue == n0 + 1 and e3.rows:find("7777;;;1;49999996000;;;3;;1", 1, true), "Client-Zeile mit Hoechstpreis")
  nsb.Data.ApplyLive(7777, { { price = 49999996000, qty = 1, own = 0 }, offers = { { id = 3000000001, q = 1, p = 49999996000, band = 3 } } }, clock + 5)
  check(PeonBridgeDB.queue[#PeonBridgeDB.queue].rows == "7777;;;1;;49999996000;;4;3000000001;1", "Live mit Hoechstpreis und grosser Auktionsnummer")
  local as, found = m2.items[7777].as, false
  if type(as) == "table" then for _, v in pairs(as) do if type(v) == "string" and v:find("3000000001:1:49999996000:", 1, true) then found = true end end end
  check(found, "Absatz-Daten mit grosser Auktionsnummer und Hoechstpreis geschrieben")
  while #PeonBridgeDB.queue > n0 do table.remove(PeonBridgeDB.queue) end   -- fuer die folgenden Pruefungen
end

-- ===== Langzeit-Teil fuer Broker (0.2.0, Broker 0.31, Rechenmodell Kapitel 8) =====
do
  local MK = "Classic Beta PvE / Horde"
  check(nsb.MarketKey() == MK and ns.MarketKeyOf() == MK, "gleicher Markt wie Broker")
  local today = D.Day()
  local function days(a, b, c) return ("%d:0:%s:0:12;%d:0:%s:0:12;%d:0:%s:0:16"):format(today - 2, a * 12, today - 1, b * 12, today, c * 16) end
  local lein = { m = 30, md = 89, pmd = 59, pm = 30, d = days(110, 99, 79) }
  local own = D.Band(lein, nil, nil, nil, 2589)
  local keep = PeonBridgeData
  PeonBridgeData = nil
  check(mod:LongTerm(2589, MK) == nil and D.ClientBand(2589) == nil, "ohne Data.lua: nichts vom Client")
  check(own and own.src == "own" and own.days == 3 and own.rw == 89, "ohne Client: Broker rechnet selbst")
  PeonBridgeData = { fmt = 2, channels = { broker = true }, t = clock, ack = {}, markets = { [MK] = { t = clock, day = today, items = {
    [2589] = "100:1000:95:12:eb", ["7777:Schwert des Affen"] = "5000:300:5100:4:e", [2590] = "kaputt", [2591] = "0:500:0:5:b" } } } }
  local v = mod:LongTerm(2589, MK)
  check(v and v.mitte == 100 and math.abs(v.schw - 0.1) < 1e-9 and v.lang == 95 and v.days == 12 and v.src == "eb", "Text des Clients gelesen")
  check(mod:LongTerm("2589", MK) and mod:LongTerm(2589, "Anderer / Allianz") == nil, "Schluessel als Text, fremder Markt leer")
  check(mod:LongTerm(2590, MK) == nil and mod:LongTerm(2591, MK) == nil and mod:LongTerm(9999, MK) == nil, "kaputte, leere und fehlende Werte ignoriert")
  local s7 = mod:LongTerm("7777:Schwert des Affen", MK)
  check(s7 and s7.schw == 0.03, "Variante mit vollem Namen")
  local b = D.Band(lein, nil, nil, nil, 2589)
  check(b and b.src == "client" and b.days == 12 and b.mitte == 100 and b.lang == 95 and b.heute == own.heute, "Broker nutzt MITTE, SCHW, LANG vom Client, HEUTE bleibt eigen")
  check(D.Band(lein, nil, nil, nil, 7777) == nil or D.Band(lein, nil, nil, nil, 7777).src == "own", "anderer Schluessel: eigene Rechnung")
  local b7 = D.Band({ md = 5000, pmd = 5000, d = today .. ":0:60000:0:12" }, nil, nil, nil, "7777:Schwert des Affen")
  check(b7 and b7.src == "client" and b7.schw == 0.05, "Client reicht auch bei weniger als 3 eigenen Tagen, SCHW mindestens 5 %")
  check(D.Band(lein).src == "own", "ohne Schluessel wie bisher")
  local sg = select(4, D.Suggest(30, 89, 2589, mod.db and nsb.mod.db, lein, 59))
  local vb = D.Evaluate(lein, 2589, 1, 1, nsb.mod.db)
  check(vb and vb.band and vb.band.src == "client", "Bewertung im Tooltip nutzt den Client")
  -- Absatz vom Client (0.3.0, Broker 0.32, Rechenmodell F49)
  PeonBridgeData.markets[MK].sales = { [2589] = "4800:70:240", [2590] = "x", [2591] = "10:-1:0" }
  local sa = mod:Sales(2589, MK)
  check(sa and sa.perDay == 480 and sa.rate == 0.7 and sa.minutes == 240, "Absatz des Clients gelesen")
  check(mod:Sales(2590, MK) == nil and mod:Sales(2591, MK) == nil and mod:Sales(2589, "Anderer / Allianz") == nil, "kaputter Absatz, ohne Beobachtung, fremder Markt: nichts")
  local SA = nsb.Sales
  local eS = { q = 40 }
  local cs = SA.Stats(eS, nil, 2589)
  check(cs and cs.src == "client" and cs.perHour == 20 and cs.level == 3 and cs.reach == 2, "Broker ohne eigenen Absatz: Wert vom Client (20/Std., gruen, reicht 2 Std.)")
  check(SA.Stats(eS) == nil, "ohne Schluessel wie bisher")
  eS.ar = (time() - 60) .. ":7200:30:0:0"
  local os2 = SA.Stats(eS, nil, 2589)
  check(os2 and os2.src == nil and os2.level == 3 - 1 and math.floor(os2.perHour + 0.5) == 15, "eigener Absatz ab gelb hat Vorrang")
  eS.ar = (time() - 60) .. ":1800:30:0:0"
  check(SA.Stats(eS, nil, 2589).src == "client", "eigener Absatz rot (30 Min.): Client")
  local sl = mod.Sales
  mod.Sales = function() error("kaputt") end
  check(SA.Stats(eS, nil, 2589).src == nil, "Fehler im Client: eigener Wert")
  mod.Sales = sl
  check(nsb.L.TT_SALES_CLIENT == "Absatz (Client, 14 Tage)", "Text fuer den Tooltip")
  -- Frische (F43)
  PeonBridgeData.markets[MK].t = clock - 8 * 86400
  check(mod:LongTerm(2589, MK) == nil and D.Band(lein, nil, nil, nil, 2589).src == "own", "aelter als 7 Tage: Broker rechnet selbst")
  check(mod:Sales(2589, MK) == nil, "alter Absatz: nichts")
  check(table.concat(ns.StatusLines(), "|"):find("älter als 7 Tage", 1, true), "Stand: Werte zu alt")
  mod.db.freshDays = 10
  check(mod:LongTerm(2589, MK) ~= nil, "Frist einstellbar (10 Tage)")
  check(table.concat(ns.StatusLines(), "|"):find("üblicher Bereich von 4, Absatz von 3 Gegenständen", 1, true), "Stand: Anzahl fuer den Markt")
  mod.db.freshDays = 7
  -- Fehler im Client stoert Broker nicht
  local lt = mod.LongTerm
  mod.LongTerm = function() error("kaputt") end
  check(D.Band(lein, nil, nil, nil, 2589).src == "own", "Fehler im Client: Broker rechnet selbst")
  mod.LongTerm = lt
  PeonBridgeData = keep
end

-- ===== Optionen, Befehle =====
local lines2 = ns.StatusLines()
check(lines2[1]:find("^Peon Manager: Werte vom ") and lines2[2] == "Kanal broker freigeschaltet", "Stand: Manager und Kanal oben: " .. lines2[1])
check(table.concat(lines2, "|"):find("|Wartet: 2 Komplettscans, 0 Live-Abfragen (etwa " .. ns.Size(select(3, ns.QueueInfo())) .. ")|", 1, true), "Stand: wartende Scans")
check(table.concat(lines2, "|"):find("Werte für Broker: Stand", 1, true), "Stand: Werte fuer Broker")
reloads = 0
SlashCmdList.PEON("bridge senden")
check(reloads == 1, "/peon bridge senden = Reload")
SlashCmdList.PEON("bridge status")
check(said("Wartet:"), "/peon bridge status")
local pageCleared = false
StaticPopup_Show = function(name, text) popupShown = { name = name, text = text } end
for _, c in ipairs(mod.page.controls or {}) do end
popupShown = nil
POPUPS.PEON_BRIDGE_CLEAR.OnAccept()
check(#PeonBridgeDB.queue == 0 and said("Warteschlange geleert"), "Warteschlange leeren")
RunScan()
check(ns.ShowButton == nil, "0.9.2: Knopf An Manager ganz entfernt")
mod:ResetDefaults()
check(#PeonBridgeDB.queue == 1, "Standardwerte: Warteschlange bleibt")

-- ===== Ohne Broker =====
do
  local get = Peon.GetModule
  Peon.GetModule = function(self, k) if k == "broker" then return nil end return get(self, k) end
  ns.hooked = nil
  check(ns.Hook() == false, "ohne Broker: kein Zuhoerer")
  check(table.concat(ns.StatusLines(), "|"):find("nicht geladen", 1, true), "ohne Broker: Hinweis im Stand")
  Peon.GetModule = get
  check(ns.Hook() == true, "Broker wieder da")
end

-- ===== Nur speicherbare Werte in PeonBridgeDB =====
local function Plain(v, d)
  local t = type(v)
  if t == "table" then for k, x in pairs(v) do if not Plain(k, d + 1) or not Plain(x, d + 1) then return false end end return true end
  return t == "string" or t == "number" or t == "boolean"
end
check(Plain(PeonBridgeDB, 0), "PeonBridgeDB nur mit Texten, Zahlen, Tabellen")

-- ===== Grosser Scan (70.000 Angebote wie in Forever) =====
do
  local big = {}
  math.randomseed(7)
  local function rnd(n) return math.random(0, n - 1) end   -- moeglichst verschiedene Angebote = obere Grenze
  for i = 1, 70000 do
    local id = 1000 + rnd(9000)
    local qty = ({ 1, 1, 1, 5, 10, 20, 20, 200 })[rnd(8) + 1]
    big[i] = { "Gegenstand" .. id, id, qty, 1, qty * (100 + rnd(100000)), nil, rnd(4) + 1 }
  end
  LISTINGS = big
  S.CHUNK, S.SUM_CHUNK = 1500, 300
  PeonBridgeDB.queue = {}
  local c0 = os.clock()
  RunScan()
  local secs = os.clock() - c0
  local e2 = PeonBridgeDB.queue[1]
  local bytes = #e2.rows
  print(("  Grosser Scan: %d Angebote, %d Zeilen, %.0f KB Zeilen, %.2f s"):format(e2.offers, e2.lines, bytes / 1024, secs))
  check(e2.offers == 70000 and e2.lines <= 70000 and bytes < 2 * 1024 * 1024, "70.000 verschiedene Angebote unter 2 MB")
end

-- ===== Fehlerspeicher des Kerns leeren (Bridge 0.5.0) =====
do
  local keepData = PeonBridgeData
  PeonDB.errors = { { addon = "A", where = "alt", msg = "m", last = 100, n = 1 }, { addon = "A", where = "neu", msg = "m", last = 300, n = 1 } }
  PeonBridgeData = { fmt = 2, t = 1, channels = {} }
  check(ns.ApplyErrorClear() == 0 and #PeonDB.errors == 2, "ohne Marke bleibt alles")
  PeonBridgeData.errorsClearBefore = 200
  check(ns.ApplyErrorClear() == 1 and #PeonDB.errors == 1 and PeonDB.errors[1].where == "neu", "Marke loescht bis zum Zeitpunkt")
  PeonBridgeData = nil
  check(ns.ApplyErrorClear() == 0, "ohne Data.lua nichts zu tun")
  PeonDB.errors, PeonBridgeData = nil, keepData
end

-- Ab 0.6.0: genaue Werte aus dem Tooltip, andere Namen eines Markts, Einkaufslisten an Broker
do
  local E, bridge = ns.Export, Peon:GetModule("bridge")
  local GORILLA = "3192:Kurzes Bastardschwert des Gorillas"
  local LINK = "|cnIQ2:|Hitem:3192::::::::20:1488:::1:12723|h[Kurzes Bastardschwert des Gorillas]|h|r"
  check(E.TipText(LINK) == nil, "0.6.0: ohne C_TooltipInfo keine Werte")
  C_TooltipInfo = { GetHyperlink = function() return { lines = {
    { leftText = "Kurzes Bastardschwert des Gorillas" }, { leftText = "Zweihändig", rightText = "Schwert" },
    { leftText = "+5 Ausdauer", leftColor = { r = 0.1, g = 1, b = 0.1 } }, { leftText = "|cffffffffStufe|r 7", leftColor = { r = 1, g = 0.82, b = 0 } },
    { leftText = "Grau", leftColor = { r = 0.5, g = 0.5, b = 0.5 } }, { leftText = "" } } } end }
  check(E.TipText(LINK) == "Zweihändig\tSchwert\t\n+5 Ausdauer\t\tg\nStufe 7\t\ty\nGrau\t\tm", "0.6.0: Zeilen ohne Namen, mit Art, ohne Farbcodes")
  check(E.TipText(nil) == nil, "0.6.0: ohne Link nichts")

  local function scan(rows)
    E.ScanStart({ market = "M / Horde", t = clock, total = 1 })
    for _, r in ipairs(rows) do E.ScanRow(r[1], r[2], 1, r[3], 500, nil, nil, 4, r[4]) end
    return E.ScanEnd({})
  end
  local e = scan({ { 3192, "Kurzes Bastardschwert des Gorillas", 2, LINK }, { 2589, "Leinenstoff", 1, "|Hitem:2589|h" }, { 3192, "Kurzes Bastardschwert des Gorillas", 2, LINK } })
  check(e.tips and e.tips[GORILLA] and e.tips["2589"] == nil, "0.6.0: Werte fuer Ausruestung mit vollem Schluessel, nicht fuer Stoff")
  local data = PeonBridgeData
  PeonBridgeData = { fmt = 2, t = clock, channels = { broker = true }, ack = { [e.id] = true } }
  ns.ApplyAck()
  check(PeonBridgeDB.tipIds[GORILLA] == true, "0.6.0: bestaetigte Werte gelten als uebergeben")
  local e2 = scan({ { 3192, "Kurzes Bastardschwert des Gorillas", 2, LINK } })
  check(e2.tips == nil, "0.6.0: kein zweites Mal")
  PeonBridgeDB.tipIds = {}
  E.TIP_MAX = 1
  local e3 = scan({ { 3192, "Kurzes Bastardschwert des Gorillas", 2, LINK }, { 4000, "Anderes Teil", 3, "|Hitem:4000|h" } })
  local n3 = 0 for _ in pairs(e3.tips) do n3 = n3 + 1 end
  check(n3 == 1, "0.6.0: Obergrenze je Scan, der Rest kommt spaeter")
  E.TIP_MAX = 400
  C_TooltipInfo = { GetHyperlink = function() error("kaputt") end }
  check(E.TipText(LINK) == nil, "0.6.0: Fehler im Spiel stoert nicht")
  C_TooltipInfo = nil

  -- Bestellte Werte: im Hintergrund lesen, wenige auf einmal, nie im Kampf
  do
    local loaded, combat = {}, false
    C_Item = C_Item or {}
    local keepReq, keepCombat = C_Item.RequestLoadItemDataByID, Peon.InCombat
    C_Item.RequestLoadItemDataByID = function(id) loaded[id] = true end
    Peon.InCombat = function() return combat end
    C_TooltipInfo = { GetHyperlink = function(l)
      local id = tonumber(l:match("item:(%d+)"))
      if id == 666 or not loaded[id] then return { lines = { { leftText = "Frage" } } } end
      return { lines = { { leftText = "Name" }, { leftText = "+1 Stärke " .. id } } } end }
    local keep = PeonBridgeData
    PeonBridgeDB.tipBox = { ["alt"] = "schon geliefert", ["1:Offen"] = "wartet noch" }
    local want = { ["1:Offen"] = "item:1::::::::20:1488:::1:5" , [666] = "item:666" }
    for i = 2, 21 do want[i] = "item:" .. i end
    PeonBridgeData = { fmt = 2, t = clock, channels = { broker = true }, tipWant = want }
    check(E.TipStart() == 21, "0.6.0: Bestellung ohne das, was schon bereitliegt")
    check(PeonBridgeDB.tipBox.alt == nil and PeonBridgeDB.tipBox["1:Offen"] == "wartet noch", "0.6.0: Was der Manager nicht mehr bestellt, hat er bekommen")
    combat = true
    check(E.TipStep() == true and E.tipBusyN == 0, "0.6.0: im Kampf passiert nichts")
    combat = false
    E.TipStep()
    check(E.tipBusyN == E.TIP_BATCH, "0.6.0: nur wenige auf einmal")
    local steps = 0
    while E.TipStep() and steps < 100 do steps = steps + 1; now = now + 1 end
    check(steps < 100 and E.tipBusyN == 0 and #E.tipQueue == 0, "0.6.0: alles abgearbeitet")
    check(PeonBridgeDB.tipBox[7] == "+1 Stärke 7\t\t", "0.6.0: Werte liegen bereit")
    check(PeonBridgeDB.tipBox[666] == "", "0.6.0: Was das Spiel nicht nennt, kommt leer zurueck")
    C_TooltipInfo = nil
    check(E.TipStart() == 0, "0.6.0: ohne C_TooltipInfo keine Arbeit")
    check(E.TipStep() == false, "0.6.0: und kein weiterer Schritt")
    C_Item.RequestLoadItemDataByID, Peon.InCombat = keepReq, keepCombat
    PeonBridgeDB.tipBox = nil
    PeonBridgeData = keep
  end

  -- Anderer interner Name desselben Markts
  PeonBridgeData = { fmt = 2, t = clock, channels = { broker = true }, aliases = { ["Realm 1 PvE / Horde"] = "Realm 3 PvE / Horde" },
    markets = { ["Realm 3 PvE / Horde"] = { t = clock, day = 1, items = { [2770] = "100:500:120:5:e" }, sales = {} } },
    shop = { lists = { { id = "m7_7", name = "Vom Manager", pct = 10, u = clock + 5, items = {} } } },
    watch = { items = { ["2770"] = clock + 5 }, gone = {} } }
  local lt = bridge:LongTerm(2770, "Realm 1 PvE / Horde")
  check(lt and lt.lang == 120, "0.6.0: Werte auch unter dem anderen Namen")
  check(bridge:LongTerm(2770, "Realm 3 PvE / Horde").lang == 120, "0.6.0: und unter dem eigenen")
  check(bridge:LongTerm(2770, "Realm 2 PvE / Horde") == nil, "0.6.0: fremder Name nicht")
  check((ns.MarketCount("Realm 1 PvE / Horde")) == 1, "0.6.0: Zaehler auch")

  -- Einkaufslisten gehen beim Anmelden an Broker
  ns.hooked = nil
  check(ns.Hook() == true, "0.6.0: Anmelden")
  local found
  for _, l in ipairs(PeonBrokerDB.lists or {}) do if l.id == "m7_7" then found = l end end
  check(found and found.name == "Vom Manager", "0.6.0: Broker hat die Liste aus dem Manager")
  check(PeonBrokerDB.watch and PeonBrokerDB.watch[2770] and PeonBrokerDB.watch[2770].u == clock + 5, "0.9.0: Broker hat die Beobachtung aus dem Manager")

  -- Ab 0.10.0 (Broker 0.85.0): je Konto unter accts, nur der eigene Teil kommt an
  local brk = ns.Broker()
  local own = brk:AcctId()
  check(type(own) == "string" and own ~= "" and PeonBrokerDB.acct == own, "0.10.0: Broker hat eine Kennung des Kontos")
  check(brk:AcctId() == own, "0.10.0: die Kennung bleibt gleich")
  PeonBridgeData = { fmt = 2, t = clock, channels = { broker = true }, markets = {},
    shop = { lists = { { id = "m8_8", name = "Oben (alt)", pct = 10, u = clock + 6, items = {} } } },
    accts = {
      [own] = { shop = { lists = { { id = "m9_9", name = "Eigenes Konto", pct = 10, u = clock + 6, items = {} } } },
                watch = { items = { ["2771"] = clock + 6 }, gone = {} } },
      ["kfremd_1"] = { shop = { lists = { { id = "m10_10", name = "Fremdes Konto", pct = 10, u = clock + 6, items = {} } } },
                       watch = { items = { ["2772"] = clock + 6 }, gone = {} } },
    } }
  ns.hooked = nil
  check(ns.Hook() == true, "0.10.0: Anmelden")
  local names = {}
  for _, l in ipairs(PeonBrokerDB.lists or {}) do names[l.id] = true end
  check(names["m9_9"], "0.10.0: Liste des eigenen Kontos kommt an")
  check(not names["m10_10"], "0.10.0: Liste eines anderen Kontos nicht")
  check(not names["m8_8"], "0.10.0: mit accts gilt der alte Teil oben nicht")
  check(PeonBrokerDB.watch[2771] ~= nil and PeonBrokerDB.watch[2772] == nil, "0.10.0: Beobachtung nur des eigenen Kontos")
  PeonBridgeData = { fmt = 2, t = clock, channels = { broker = true }, markets = {}, accts = {} }
  ns.hooked = nil
  check(ns.Hook() == true, "0.10.0: Konto noch unbekannt, Anmelden geht trotzdem")
  check(ns.Export.AcctPart(PeonBridgeData, brk) == nil, "0.10.0: ohne eigenen Teil kein Abgleich")
  PeonBridgeData = data
end

-- Neuester Stand des Managers (Bridge 0.7.0, Broker 0.36.0, Manager 0.18.0)
do
  local keep = PeonBridgeData
  local D = nsb.Data
  local mk = D.Market(nil, true)
  local T = clock + 5000
  mk.lastScan, mk.mgrAt = clock, nil
  mk.items[90001] = { m = 100, md = 120, q = 10, n = 3, t = clock, d = "1:100:120:10:1", pm = 90, pmd = 110, pt = clock - 100 }
  mk.items[90002] = { m = 500, md = 500, q = 2, n = 1, t = clock }
  mk.items[90003] = { m = 700, md = 700, q = 1, n = 1, t = clock, lt = T + 10, lv = "700:1" }
  mk.items["90004:Klinge des Affen"] = { m = 900, md = 900, q = 1, n = 1, t = clock }
  PeonBridgeData = { fmt = 2, t = T, channels = { broker = false }, ack = {}, markets = { [nsb.MarketKey()] = { t = T, day = 1, items = {}, sales = {},
    cur = { t = T, src = "api", items = { [90001] = "80:95:30:6", [90003] = "650:650:1:1", ["90004:Klinge des Affen"] = "850:860:2:2", [90005] = "40:40:5:1", [90006] = "kaputt" } } } } }
  check(mod:Current(nsb.MarketKey()) == nil and D.ApplyManager() == 0, "0.7.0: ohne Freischaltung kein Stand vom Manager")
  PeonBridgeData.channels.broker = true
  local t, src, items = mod:Current(nsb.MarketKey())
  check(t == T and src == "api" and items[90001] == "80:95:30:6", "0.7.0: Stand des Managers mit Zeit und Herkunft")
  check(mod:Current("Anderer / Horde") == nil, "0.7.0: fremder Markt leer")
  -- 0.11.0 (Peon_Manager_Chancen.md 9.1): Kandidatenliste fuer Brokers Radar
  check(mod:Chances(nsb.MarketKey()) == nil, "0.11.0: ohne Liste keine Kandidaten")
  PeonBridgeData.markets[nsb.MarketKey()].chances = { t = T, list = { [90001] = "s:80:120:" .. (T + 3600) .. ":40:1:1" }, say = { [90001] = "Satz" } }
  local ct, cl, cs = mod:Chances(nsb.MarketKey())
  check(ct == T and cl[90001] and cs[90001] == "Satz", "0.11.0: Kandidaten mit Zeit und Satz")
  PeonBridgeData.channels.broker = false
  check(mod:Chances(nsb.MarketKey()) == nil, "0.11.0: ohne Freischaltung keine Kandidaten")
  PeonBridgeData.channels.broker = true
  PeonBridgeData.markets[nsb.MarketKey()].chances = nil
  check(D.ApplyManager() == 3, "0.36: drei Gegenstaende neu (einer hat eine neuere Live-Abfrage)")
  local e1 = mk.items[90001]
  check(e1.m == 80 and e1.md == 95 and e1.q == 30 and e1.n == 6 and e1.lt == T, "0.36: aktueller Stand vom Manager")
  check(e1.t == clock and e1.pm == 90 and e1.d == "1:100:120:10:1", "0.36: Verlauf, Trend und Scan-Zeit bleiben")
  check(mk.items[90002].gone == T and mk.items[90002].q == 0 and mk.items[90002].m == 500, "0.36: fehlt im Stand: weg, letzter Preis bleibt")
  check(mk.items[90003].m == 700 and mk.items[90003].lv == "700:1", "0.36: neuere Live-Abfrage bleibt")
  check(mk.items["90004:Klinge des Affen"].m == 850, "0.36: Variante mit vollem Namen")
  check(mk.items[90005] and mk.items[90005].m == 40 and mk.items[90006] == nil, "0.36: neuer Gegenstand, kaputter Wert ignoriert")
  check(mk.mgrAt == T and mk.mgrSrc == "api" and mk.mgrItems == 4, "0.36: Zeit, Herkunft und Zahl fuer die Anzeige")
  check(D.DataAt(mk) == T and D.DataAt({ lastScan = 5 }) == 5 and D.DataAt({}) == nil, "0.36: neueste Daten")
  check(D.ApplyManager() == 0, "0.36: derselbe Stand nur einmal")
  -- Broker 0.80: beim Anmelden auch der neutrale Markt (vorher nur der Markt, in dem man stand)
  local nk = nsb.NeutralMarketKey()
  D.Markets()[nk] = nil
  PeonBridgeData.markets[nk] = { t = T, day = 1, items = {}, sales = {}, cur = { t = T, src = "api", items = { [90001] = "60:70:12:3" } } }
  check(D.ApplyManagerAll() == 1, "Broker 0.80: Stand vom Manager auch fuer den neutralen Markt")
  local nm = D.Market(nk)
  check(nm and nm.items[90001] and nm.items[90001].m == 60 and nm.mgrAt == T and mk.items[90001].m == 80,
    "Broker 0.80: neutrale Preise im neutralen Markt, Heimat unveraendert")
  check(D.ApplyManagerAll() == 0, "Broker 0.80: derselbe Stand nur einmal")
  PeonBridgeData.markets[nk] = nil
  D.Markets()[nk] = nil
  check(D.ApplyManagerAll() == 0 and D.Market(nk) == nil, "Broker 0.80: ohne Werte des Managers entsteht kein neutraler Markt")
  local lnc = nsb.mod.launcher
  if lnc then
    mk.lastScan, mk.mgrAt = clock - 20 * 3600, clock - 1800
    local a, sa = lnc:GetText("age"), lnc:GetText("scanAge")
    check(a:find("30", 1, true) and sa:find("20", 1, true), "0.36: Leiste zeigt die neuesten Daten, Scan-Alter getrennt: " .. tostring(a) .. " / " .. tostring(sa))
  end
  PeonBridgeData = keep
end

check(not said("Fehler in"), "keine Fehlermeldungen")
print("ALLE TESTS OK")
