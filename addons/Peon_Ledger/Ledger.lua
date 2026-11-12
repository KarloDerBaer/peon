-- Peon_Ledger - Ledger.lua
-- Bestand aller Charaktere und Buchfuehrung (Konzept: Peon_Ledger_Konzept.md im Projektordner).
-- Stand 0.1 (L1): Pruefbefehl /ledger pruefen (Probe.lua).
-- Stand 0.2 (L2): Bestand aller Charaktere (Inventory.lua), Tooltip-Zeile (Tooltip.lua), Fenster mit den Reitern
--   Uebersicht und Bestand (Window.lua, Overview.lua, Stock.lua), Minimap-Button. Nur ereignisgesteuert.
-- Stand 0.3 (L3): Bewegungen von Gegenstaenden und Gold mit Grund (Moves.lua), Reiter Verlauf (History.lua).
-- Stand 0.4 (L5): Buch und Gegenstaende mit Verkaufsquote (Book.lua). L4 (eigener Knopf "Post einsammeln") entfaellt.
-- Ab 0.14 Neuaufbau (Konzept Peon_Ledger_Neuaufbau.md): Kontrollrechnung (Check.lua), Erfassung an der Quelle
--   (Moves.lua), zuletzt gezahlt/verkauft (Last.lua), Fenster mit Peon.UI und vier Reitern, Postfenster (Mail.lua).
--   Reiter Gegenstaende und Gegenstand entfallen, alles zu einem Gegenstand zeigt Broker (mod:ShowItem).

-- Schnittstelle fuer andere Module (z. B. Broker, L6), nur lesend:
--   mod:SellRate(itemID [, Tage])  -> Quote 0..1 oder nil (unter 3 Stueck), verkauft, zurueck
--   mod:Stock(itemID)              -> Stueck ueber alle Charaktere, Tabelle wie Inventory.Count
--   mod:StockOthers(itemID)        -> Stueck der anderen Charaktere (Taschen, Bank, Post) + Accountbank
--   mod:Cost(itemID [, Charakter])  -> Kosten naechstes Stueck, Durchschnitt, Stueck, Lagerwert (ab 0.7, Cost.lua);
--                                     ab 0.9 je Charakter: ohne Angabe der eingeloggte, "*" = alle Charaktere
--   mod:LastBuy(itemID)            -> zuletzt gezahlt je Stueck, Zeit, Stueck, Quelle ("ah", "vendor", "cod", "trade") (ab 0.14)
--   mod:LastSale(itemID)           -> zuletzt verkauft je Stueck (netto), Zeit, Stueck, Quelle ("ah", "vendor") (ab 0.14)
--   mod:ShowItem(itemID)           -> Gegenstand zeigen: Seite Gegenstand in Broker (ab 0.14), sonst Bestand mit Suche
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
        tooltipShow  = true,     -- Ledger-Zeilen im Tooltip
        tooltipLayout = {},      -- Bausteine im Tooltip (ab 0.14.2, Tooltip.lua: shifthint, lines)
        windowPos    = {},
        windowTab    = "overview",
        historyMoves  = true,    -- Verlauf: Umbuchungen zeigen
        historyOnlyMe = false,   -- Verlauf: nur eingeloggter Charakter (bis 0.13, ab 0.14 historyChar)
        historyChar   = "*",     -- Verlauf: Charakter ("*" = alle, ab 0.14)
        historyKind   = "all",   -- Verlauf: Filter nach Art (ab 0.6)
        bookPeriod    = "d7",    -- Buch: Zeitraum (today, d7, d30, all)
        bookOnlyMe    = false,   -- (bis 0.13, ab 0.14 bookChar)
        bookChar      = "*",     -- Buch: Charakter (ab 0.14)
        bookView      = "kinds", -- Buch: Ansicht "Nach Art" oder "Nach Gegenstand" (ab 0.14)
        stockChar     = "*",     -- Bestand: Charakter (ab 0.14)
        stockPlace    = "all",   -- Bestand: Ort (ab 0.14)
        stockCat      = "all",   -- Bestand: Kategorie (ab 0.14.2)
        costOrder     = "lifo",  -- Kosten: neueste zuerst (lifo) oder aelteste zuerst (fifo), ab 0.14.3
        mailWindow    = true,    -- eigenes Postfenster statt Blizzards Postfach (ab 0.14)
        mailFilter    = "all",   -- Postfenster: Filter nach Art (ab 0.14)
        mailRecent    = {},      -- Postfenster: zuletzt angeschriebene Empfaenger (ab 0.14)
        session       = {},      -- Gold zu Beginn der Sitzung (ab 0.12): who, money, uebersteht /reload
    },
    ranges   = { minimapAngle = { 0, 359, 1 } },
    choices  = { windowTab = { overview = true, stock = true, history = true, book = true },
                 bookPeriod = { today = true, d7 = true, d30 = true, all = true },
                 bookView = { kinds = true, items = true },
                 costOrder = { lifo = true, fifo = true },
                 stockPlace = { all = true, bags = true, bank = true, mail = true, auctions = true, equip = true, transit = true },
                 stockCat = { all = true, equip = true, trade = true, consum = true, recipe = true, bag = true, quest = true, other = true },
                 mailFilter = { all = true, sale = true, buy = true, ["return"] = true, other = true },
                 historyKind = { all = true, ah = true, vendor = true, loot = true, use = true, quest = true, craft = true,
                                 trade = true, mail = true, travel = true, destroy = true, fix = true, other = true } },
    keepOnReset = { windowPos = true, windowTab = true, historyMoves = true, historyOnlyMe = true, historyChar = true, bookPeriod = true,
                    bookOnlyMe = true, bookChar = true, bookView = true, historyKind = true, stockChar = true, stockPlace = true, stockCat = true,
                    mailFilter = true, mailRecent = true, session = true },
    slash    = { "/ledger" },
    onSlash  = function(m, cmd, rest)
        if cmd == "pruefen" or cmd == "prüfen" or cmd == "check" or cmd == "probe" then
            ns.Probe.Run()
        elseif cmd == "optionen" or cmd == "options" or cmd == "config" then
            m:OpenOptions()
        elseif cmd and cmd ~= "" then
            -- /ledger <Name, Nummer oder Link> zeigt den Gegenstand (ab 0.14 in Broker, sonst im Bestand)
            local text = cmd .. ((rest and rest ~= "") and (" " .. rest) or "")
            local id = ns.FindItem(text)
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

-- Zuletzt gezahlt und zuletzt verkauft (ab 0.14, Last.lua): Preis je Stueck, Zeit, Stueck, Quelle; nil ohne Kauf
function mod:LastBuy(id)
    local b = ns.Last and type(id) == "number" and ns.Last.Buy(id)
    if not b then return nil end
    return b.unit, b.t, b.n, b.src
end
function mod:LastSale(id)
    local b = ns.Last and type(id) == "number" and ns.Last.Sale(id)
    if not b then return nil end
    return b.unit, b.t, b.n, b.src
end

-- Gegenstand zeigen (ab 0.14): Seite Gegenstand in Broker, ohne Broker der Bestand mit Suche nach dem Namen
function mod:ShowItem(id)
    if type(id) ~= "number" then return end
    local ok, b = pcall(Peon.GetModule, Peon, "broker")
    if ok and type(b) == "table" and type(b.ShowItem) == "function" then
        local done = pcall(b.ShowItem, b, id)
        if done then return end
    end
    local name = ns.Inventory.ItemInfo(id) or tostring(id)
    ns.Window.Open("stock")
    ns.Stock.search = name
    if ns.Stock.searchBox then ns.Stock.searchBox:SetText(name) end
    ns.Window.Refresh()
end

-- Gegenstand nach Name (auch Teil), Nummer oder Link
function ns.FindItem(text)
    if type(text) ~= "string" or text == "" then return nil end
    local id = tonumber(text:match("item:(%d+)")) or tonumber(text:match("^%s*(%d+)%s*$"))
    if id then return id end
    local q = ns.Window.Lower((text:gsub("^%s+", ""):gsub("%s+$", "")))
    if q == "" then return nil end
    local best
    for k, it in pairs(mod.acc.items or {}) do
        if type(it) == "table" and type(it.n) == "string" then
            local n = ns.Window.Lower(it.n)
            if n == q then return k end
            if not best and n:find(q, 1, true) then best = k end
        end
    end
    return best
end

-- Letzter Kauf beim Haendler (ab 0.13.1, fuer Brokers Berufsfenster): Preis je Stueck und Zeit, nil ohne Kauf
function mod:VendorBuy(id)
    if not ns.Moves or type(id) ~= "number" then return nil end
    local list = ns.Moves.List()
    for i = #list, 1, -1 do
        local e = list[i]
        if e.k == "vendor" and e.id == id and type(e.n) == "number" and e.n > 0 and type(e.m) == "number" and e.m < 0 then
            return -e.m / e.n, e.t
        end
    end
    return nil
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

-- Text mit Anzahl in Einzahl oder Mehrzahl (ab 0.14.1): L[key .. "_1"] fuer genau 1, sonst L[key]
function ns.Plural(n, key, ...)
    local fmt = (n == 1 and rawget(L, key .. "_1")) or L[key]
    return fmt:format(n, ...)
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

-- Kurzer Betrag mit Muenzsymbolen fuer Peon_Panel (ab 0.12): Gold und Silber, Kupfer nur unter 1g.
-- Ab 1000g nur Gold, gekuerzt wie bei Peon.ShortNumber ("12,3k").
function ns.PanelMoney(c)
    if type(c) ~= "number" or Peon.IsSecret(c) then return "?" end
    local g = math.floor(math.abs(c) / 10000)
    if g >= 1000 then return (c < 0 and "-" or "") .. Peon.ShortNumber(g) .. GOLD end
    return ns.Money(c, true)
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
            { key = "goldAll", label = L.TEXT_GOLD_ALL, get = function() return ns.PanelMoney((ns.Inventory.TotalMoney())) end },
            { key = "goldMe", label = L.TEXT_GOLD_ME, get = function() return ns.PanelMoney(GetMoney()) end },
            { key = "goldSession", label = L.TEXT_GOLD_SESSION, get = function() return ns.SessionGoldText() end },
        },
        defaultText = "goldAll",
    })
end

-- Gold der Sitzung (ab 0.12). Neu beim Einloggen und bei einem anderen Charakter, /reload zaehlt weiter.
local function StartSession()
    local s = mod.db.session
    s.who, s.money = UnitGUID("player"), GetMoney()
end

function ns.SessionGold()
    local s = mod.db.session
    if s.who ~= UnitGUID("player") or type(s.money) ~= "number" then StartSession() end
    return GetMoney() - s.money
end

function ns.SessionGoldText()
    local delta = ns.SessionGold()
    if delta < 0 then return "-" .. ns.PanelMoney(-delta) end
    return "+" .. ns.PanelMoney(delta)
end

mod:RegisterEvent("PLAYER_ENTERING_WORLD", function(_, isLogin)
    if isLogin and mod.db then StartSession() end
end)

mod:On("INIT", function()
    if (Peon.API or 0) < 19 or not Peon.UI then   -- ab 0.14: Peon.UI mit Zeilenfarben (API 19)
        mod:Error(L.MSG_OLD_CORE)
        return
    end
    if ns.CreateOptions then mod:Call("Options", ns.CreateOptions) end
    mod:Call("Pruefung", ns.Probe.Init)
    mod:Call("Bestand", ns.Inventory.Init)
    mod:Call("Bewegungen", ns.Moves.Init)
    mod:Call("Tooltip", ns.Tooltip.Init)
    mod:Call("Fenster", ns.Window.Init)
    mod:Call("Post", ns.Mail.Init)   -- ab 0.14: eigenes Postfenster
    if mod.AddNotice then mod:AddNotice({
        id = "neuaufbau-2026-11", date = "12.11.2026", title = L.NOTICE_TITLE,
        text = { L.NOTICE_1, L.NOTICE_2, L.NOTICE_3 },
    }) end
    mod:Call("Minimap", CreateMinimapButton)
end)
-- Ab 0.14 (Neuaufbau, KarloDerBaer): Die Erfassung im Auktionshaus und in der Post ist neu. Das Buch jedes Realms
-- beginnt deshalb einmal neu (alte Zeilen hatten die Luecken aus Abschnitt 3.2 des Konzepts).
ns.BOOK_VERSION = 4   -- 3 ab 0.14.2 (Sondereinnahme), 4 ab 0.14.3 (Startbestand markiert, Variante C)
function ns.MigrateBook()
    local r = ns.Inventory.RealmData()
    if (tonumber(r.bookV) or 0) >= ns.BOOK_VERSION then return false end
    local had = type(r.moves) == "table" and #r.moves > 0
    if had then ns.Moves.ResetBook() end
    r.bookV = ns.BOOK_VERSION
    if had then mod:Print(L.MSG_BOOK_NEW:format(ns.Realm())) end
    return had
end

mod:On("LOGIN", function()
    mod:Call("Bestand", ns.Inventory.OnLogin)
    mod:Call("Bewegungen", ns.Moves.OnLogin)
    mod:Call("Buch", ns.MigrateBook)
    mod:Call("Kontrollrechnung", ns.Check.OnLogin)
end)
-- Reihenfolge der Kosten geaendert: neu rechnen (ab 0.14.3)
mod:On("CHANGED", function()
    if ns.Cost then ns.Cost.Invalidate() end
    if ns.Last then ns.Last.dirty = true end
    if ns.Window and ns.Window.OnData then ns.Window.OnData() end
end)
mod:On("COMBAT_END", function() mod:Call("Bestand", ns.Inventory.Flush) end)

-- Bereiche für Rückmeldungen in Peon_Feedback (Kern ab API 9)
if Peon.SetFeedbackAreas then Peon.SetFeedbackAreas(ADDON_NAME, { "Prüfung", "Bestand", "Übersicht", "Bewegungen", "Post", "Postfenster", "Buch", "Kosten", "Kontrollrechnung", "Tooltip", "Fenster", "Optionen" }) end
