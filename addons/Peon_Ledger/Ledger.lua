-- Peon_Ledger - Ledger.lua
-- Bestand aller Charaktere und Buchfuehrung (Konzept: Peon_Ledger_Konzept.md im Projektordner).
-- Stand 0.1 (L1): Pruefbefehl /ledger pruefen (Probe.lua).
-- Stand 0.2 (L2): Bestand aller Charaktere (Inventory.lua), Tooltip-Zeile (Tooltip.lua), Fenster mit den Reitern
--   Uebersicht und Bestand (Window.lua, Overview.lua, Stock.lua), Minimap-Button. Nur ereignisgesteuert.
-- Stand 0.3 (L3): Bewegungen von Gegenstaenden und Gold mit Grund (Moves.lua), Reiter Verlauf (History.lua).
-- Stand 0.4 (L5): Buch und Gegenstaende mit Verkaufsquote (Book.lua). L4 (eigener Knopf "Post einsammeln") entfaellt.

-- Schnittstelle fuer andere Module (z. B. Broker, L6), nur lesend:
--   mod:SellRate(itemID [, Tage])  -> Quote 0..1 oder nil (unter 3 Stueck), verkauft, zurueck
--   mod:Stock(itemID)              -> Stueck ueber alle Charaktere, Tabelle wie Inventory.Count
--   mod:StockOthers(itemID)        -> Stueck der anderen Charaktere (Taschen, Bank, Post) + Accountbank
--   mod:Cost(itemID [, Charakter])  -> Kosten naechstes Stueck, Durchschnitt, Stueck, Lagerwert (ab 0.7, Cost.lua);
--                                     ab 0.9 je Charakter: ohne Angabe der eingeloggte, "*" = alle Charaktere
-- Ab 0.5 (L6): Vermoegen mit Brokers Wert (ns.Value, Broker: mod:ItemValue).
-- PeonLedgerDB (accountweit): realms[Realm].chars[Vorname Nachname] = Bestand; items[itemID] = { n, q, i };
--   probe*, bankLog (Fehlersuche Bank).

local ADDON_NAME, ns = ...
local L = ns.L

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "ledger",             -- /peon ledger ...
    title    = "Ledger",
    db       = "PeonLedgerDB",
    defaults = {
        minimapShow  = true,
        minimapAngle = 200,
        tooltipShow  = true,     -- Zeile "Bestand" im Tooltip
        windowPos    = {},
        windowTab    = "overview",
        historyMoves  = true,    -- Verlauf: Umbuchungen zeigen
        historyOnlyMe = false,   -- Verlauf: nur eingeloggter Charakter
        bookPeriod    = "d7",    -- Buch/Gegenstände: Zeitraum (today, d7, d30, all)
        bookOnlyMe    = false,   -- Buch/Gegenstände: nur eingeloggter Charakter
        historyKind   = "all",   -- Verlauf: Filter nach Art (ab 0.6)
        itemPeriod    = 30,      -- Reiter Gegenstand (ab 0.9): Zeitraum in Tagen, 0 = alles
        itemMarge     = false,   -- Reiter Gegenstand: Marge-Streifen
        itemOff       = {},      -- Reiter Gegenstand: an/aus je Linie (true = aus)
        itemLast      = 0,       -- Reiter Gegenstand: zuletzt gezeigter Gegenstand
        catalogFilter = "all",   -- Reiter Gegenstaende (ab 0.10): all / stock / moved / ah
    },
    ranges   = { minimapAngle = { 0, 359, 1 } },
    choices  = { windowTab = { overview = true, stock = true, history = true, book = true, items = true, catalog = true, item = true },
                 catalogFilter = { all = true, stock = true, moved = true, ah = true },
                 itemPeriod = { [7] = true, [30] = true, [90] = true, [0] = true },
                 bookPeriod = { today = true, d7 = true, d30 = true, all = true },
                 historyKind = { all = true, ah = true, vendor = true, loot = true, use = true, quest = true, craft = true,
                                 trade = true, mail = true, travel = true, destroy = true, fix = true, other = true } },
    keepOnReset = { windowPos = true, windowTab = true, historyMoves = true, historyOnlyMe = true, bookPeriod = true, bookOnlyMe = true, historyKind = true,
                    itemPeriod = true, itemMarge = true, itemOff = true, itemLast = true, catalogFilter = true },
    slash    = { "/ledger" },
    onSlash  = function(m, cmd, rest)
        if cmd == "pruefen" or cmd == "prüfen" or cmd == "check" or cmd == "probe" then
            ns.Probe.Run()
        elseif cmd == "optionen" or cmd == "options" or cmd == "config" then
            m:OpenOptions()
        elseif cmd and cmd ~= "" then
            -- ab 0.9: /ledger <Name, Nummer oder Link> zeigt den Gegenstand im Reiter "Gegenstand"
            local text = cmd .. ((rest and rest ~= "") and (" " .. rest) or "")
            local id = ns.Item and ns.Item.Find(text)
            if id then m:ShowItem(id) else m:Print(L.ITEM_NOT_FOUND:format(text)) end
        else
            ns.Window.Toggle()
        end
    end,
})
ns.mod = mod

function mod:SellRate(id, days) return ns.Book.SellRate(id, days) end
function mod:Stock(id)
    local c = ns.Inventory.Count(id)
    return c.total, c
end
-- Vorrat der anderen Charaktere (Taschen, Bank, unterwegs per Post von Twinks) und der Accountbank - fuer Brokers "Behalten" (L6)
function mod:StockOthers(id)
    local c = ns.Inventory.Count(id)
    local me, n = ns.CharName(), c.warband or 0
    for _, ch in ipairs(c.chars) do
        if ch.name ~= me then n = n + (ch.places.bags or 0) + (ch.places.bank or 0) + (ch.places.transit or 0) end
    end
    return n
end

-- Kosten eines Gegenstands (ab 0.7, Zuordnen): naechstes Stueck, Durchschnitt, Stueck mit Posten, Lagerwert
-- (Kupfer, je Stueck mit Nachkommastellen); nil ohne Posten
function mod:Cost(id, char)
    if not ns.Cost then return nil end
    local info = ns.Cost.Info(id, char)
    if not info then return nil end
    return info.next, info.avg, info.n, info.value
end

-- Wert eines Gegenstands von Peon_Broker (Zeile 1 des Broker-Tooltips), nil ohne Broker oder ohne Preis
function ns.Value(id, count)
    if not Peon.GetModule then return nil end
    local ok, b = pcall(Peon.GetModule, Peon, "broker")
    if not ok or type(b) ~= "table" or type(b.ItemValue) ~= "function" then return nil end
    local ok2, v = pcall(b.ItemValue, b, id, count)
    if ok2 and type(v) == "number" and not Peon.IsSecret(v) then return v end
    return nil
end
-- Wert fuer das Vermoegen (ab 0.7.3): ungebundene Stueck mit Brokers Wert, gebundene (seelengebunden, angelegt)
-- nur mit dem Haendlerpreis - mehr bekommt man dafuer nicht. nil ohne Broker oder ohne Preis fuer Ungebundenes.
function ns.Worth(id, n, bound)
    if not ns.HasBroker() then return nil end
    bound = math.max(0, math.min(tonumber(bound) or 0, n))
    local v = 0
    if n - bound > 0 then
        v = ns.Value(id, n - bound)
        if not v then return nil end
    end
    if bound > 0 then v = v + ((ns.Moves and ns.Moves.SellPrice and ns.Moves.SellPrice(id)) or 0) * bound end
    return v
end

function ns.HasBroker()
    if not Peon.GetModule then return false end
    local ok, b = pcall(Peon.GetModule, Peon, "broker")
    return ok and type(b) == "table" and type(b.ItemValue) == "function"
end

-- Charakter mit Vor- und Nachname (Forever: zweiter Wert von UnitName ist der Nachname, nicht der Realm)
function ns.CharName()
    local first, last = UnitName("player")
    if Peon.IsSecret(first) or type(first) ~= "string" then return "?" end
    if type(last) == "string" and last ~= "" and not Peon.IsSecret(last) then return first .. " " .. last end
    return first
end

function ns.Realm()
    local realm = GetRealmName and GetRealmName() or nil
    if Peon.IsSecret(realm) or type(realm) ~= "string" or realm == "" then return "?" end
    return realm
end

-- Geldbetrag als kurzer Text (ohne Muenzsymbole): "12g 3s 4c"
function ns.MoneyText(c)
    if type(c) ~= "number" or Peon.IsSecret(c) then return "?" end
    c = math.floor(c)
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if k > 0 or #parts == 0 then parts[#parts + 1] = k .. "c" end
    return table.concat(parts, " ")
end

local GOLD   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

-- Geld mit Muenzsymbolen; nur Gold ab 1g, wenn short (Uebersicht)
function ns.Money(c, short)
    if type(c) ~= "number" or Peon.IsSecret(c) then return "?" end
    local neg = c < 0
    c = math.floor(math.abs(c) + 0.5)
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. GOLD end
    if s > 0 and not (short and g >= 100) then parts[#parts + 1] = s .. SILVER end
    if (k > 0 and not (short and g > 0)) or #parts == 0 then parts[#parts + 1] = k .. COPPER end
    return (neg and "-" or "") .. table.concat(parts, " ")
end

-- Alter als kurzer Text: "jetzt", "5 Min.", "3 Std.", "2 T."
function ns.Age(t)
    if type(t) ~= "number" then return "–" end
    local d = math.max(0, time() - t)
    if d < 60 then return L.AGE_NOW end
    if d < 3600 then return L.AGE_MIN:format(math.floor(d / 60)) end
    if d < 48 * 3600 then return L.AGE_HOURS:format(math.floor(d / 3600)) end
    return L.AGE_DAYS:format(math.floor(d / 86400))
end

-- Minimap-Button (Kern-Baustein): Linksklick Fenster, Rechtsklick Einstellungen
local function CreateMinimapButton()
    mod:NewMinimapButton({
        icon = "Interface\\Icons\\INV_Scroll_03",
        name = "PeonLedgerMinimapButton",
        hint = L.MM_HINT,
        onClick = function(m, button)
            if button == "RightButton" then m:OpenOptions() else ns.Window.Toggle() end
        end,
        onTooltip = function(m, tt)
            local total, chars = ns.Inventory.TotalMoney()
            tt:AddLine(L.MM_MONEY:format(ns.Money(total), chars), 1, 1, 1)
        end,
        -- Texte fuer Peon_Panel
        texts = {
            { key = "goldAll", label = L.TEXT_GOLD_ALL, get = function() return Peon.ShortGold((ns.Inventory.TotalMoney())) end },
            { key = "goldMe", label = L.TEXT_GOLD_ME, get = function() return Peon.ShortGold(GetMoney()) end },
        },
        defaultText = "goldAll",
    })
end

mod:On("INIT", function()
    if (Peon.API or 0) < 10 then   -- ab 0.9: Diagramm-Baustein (API 10)
        mod:Error(L.MSG_OLD_CORE)
        return
    end
    if ns.CreateOptions then mod:Call("Options", ns.CreateOptions) end
    mod:Call("Pruefung", ns.Probe.Init)
    mod:Call("Bestand", ns.Inventory.Init)
    mod:Call("Bewegungen", ns.Moves.Init)
    mod:Call("Tooltip", ns.Tooltip.Init)
    mod:Call("Fenster", ns.Window.Init)
    if ns.Pick then mod:Call("Gegenstand", ns.Pick.Init) end   -- ab 0.9.1: Alt+Klick, Tastenbelegung
    mod:Call("Minimap", CreateMinimapButton)
end)
mod:On("LOGIN", function()
    mod:Call("Bestand", ns.Inventory.OnLogin)
    mod:Call("Bewegungen", ns.Moves.OnLogin)
end)
mod:On("COMBAT_END", function() mod:Call("Bestand", ns.Inventory.Flush) end)

-- Bereiche für Rückmeldungen in Peon_Feedback (Kern ab API 9)
if Peon.SetFeedbackAreas then Peon.SetFeedbackAreas(ADDON_NAME, { "Prüfung", "Bestand", "Übersicht", "Bewegungen", "Post", "Buch", "Kosten", "Gegenstand", "Tooltip", "Fenster", "Optionen" }) end
