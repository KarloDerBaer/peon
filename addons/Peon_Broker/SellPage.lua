-- Peon_Broker - SellPage.lua
-- Ab 0.141 (Konzept Peon_Broker_Verkaufen_Seite.md, KarloDerBaer 26.11.2026): eigene Seite Verkaufen, aufgebaut wie
-- Einkaufen. Links die Eingaben (Preis mit den Knoepfen Guenstige, Vorschlag, Letzter, Ziel, Menge, Dauer,
-- Einstellgebuehr, Gesamtpreis, Gewinn mit Tooltip, Einstellen, darunter Zum Einstellen), rechts der Markt (Angebote
-- jetzt, Hinweise als Tabelle, Marktlage mit den drei Zeilen des Einkaufens).
--
-- Technik (Blizzards Quelltext nachgelesen im Zweig forever, Blizzard_AuctionHouseSellFrame.lua und
-- Blizzard_AuctionHouseFrame.lua):
--   * Waehlt Blizzard die Ansicht Verkaufen (Reiter oder Rechtsklick in der Tasche), legt Broker diese Seite ueber
--     Blizzards Verkaufsfenster (AHTabs.OpenSell). Blizzards Fenster bleibt darunter und haelt den Gegenstand.
--   * Den Gegenstand liest Broker nur aus (GetItem). Broker schreibt nichts in Blizzards Fenster und ruft weder
--     SetPostItem noch SetDisplayMode auf (Fehlerberichte 10 und 11): Blizzards eigener Ablauf beim Rechtsklick in
--     der Tasche liest diese Werte und darf nicht verunreinigt werden.
--   * Eingestellt wird direkt mit C_AuctionHouse.PostCommodity bzw. PostItem und dem Gegenstand aus Blizzards Fenster
--     (wie Blizzards Knopf, nur ohne dessen Felder). Fragt das Spiel nach, bestaetigt der zweite Klick.
--   * Abgefragt wird nur, solange die Seite offen ist, ueber die laufende Abfrage des Einkaufens (Radar.SetFocus).
--     Das Einkaufen behaelt seinen eigenen Gegenstand und fragt ihn wieder ab, sobald man dorthin wechselt.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local S = {}
ns.SellPage = S

S.key = nil          -- Gegenstand auf der Seite (Schluessel der Preisdatenbank)
S.it = nil           -- zuletzt gelesener Gegenstand { loc, link, key, id, commodity }
S.own = nil          -- eigener Preis { key, price }
S.qty = nil          -- eigene Menge { key, qty }, qty 0 = Alle
S.hours = nil        -- gewaehlte Dauer in Stunden (Sitzung), sonst die Einstellung duration
S.post = nil         -- laufendes Einstellen { key, loc, dur, qty, price, commodity, state, t }
S.since = 0          -- Live-Daten zaehlen ab hier (neuer Gegenstand)
S.POST_WAIT = 10     -- Sekunden, so lange gilt ein Einstellen als unterwegs
S.HOURS = { 2, 8, 24 }

local GREY, GREEN, ORANGE, YELLOW, RED = "|cff999999", "|cff60e060", "|cffff9933", "|cffffd100", "|cffff6666"
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end
local function AHApi() return rawget(_G, "C_AuctionHouse") end
local function AHOpen() return ns.Scan.ahOpen and AHApi() ~= nil end
local function Now() return GetTime and GetTime() or time() end
local function On(b, v) if v then b:Enable() else b:Disable() end end

function S.Shown()
    local T = ns.AHTabs
    return T ~= nil and T.current == "sell"
end

---------------------------------------------------------------------------
-- Gegenstand aus Blizzards Verkaufsfenster (nur lesen)
---------------------------------------------------------------------------
local function Valid(loc)
    if type(loc) ~= "table" then return false end
    if type(loc.IsValid) ~= "function" then return true end
    local ok, v = pcall(loc.IsValid, loc)
    return ok and v == true
end

function S.ReadItem()
    local A = ns.Advice
    if not (A and A.ActiveSellFrame) then return nil end
    local sf, commodity = A.ActiveSellFrame()
    if not sf then return nil end
    local it = A.Read(sf, commodity)
    if not it or not Valid(it.loc) then return nil end
    it.sf = sf
    return it
end

-- Gegenstand abgleichen: ein neuer setzt eigene Werte zurueck und richtet die laufende Abfrage auf ihn
function S.Sync()
    local it = S.ReadItem()
    local key = it and it.key or nil
    if key ~= S.key then
        S.key = key
        S.own, S.qty = nil, nil
        S.since = time()
        if S.Shown() and AHOpen() then ns.Radar.SetFocus(key) end
    end
    S.it = it
    return it
end

-- So viele Stueck lassen sich einstellen (wie Blizzards Feld Menge), mindestens 1
function S.MaxQty(it)
    it = it or S.it
    if not it then return 0 end
    local ah = AHApi()
    if ah and ah.GetAvailablePostCount then
        local ok, n = pcall(ah.GetAvailablePostCount, it.loc)
        if ok and Num(n) and n > 0 then return math.floor(n) end
    end
    local n = ns.Quick and ns.Quick.BagCount and ns.Quick.BagCount(it.key) or nil
    return (Num(n) and n > 0) and n or 1
end

-- Menge: eigene Wahl, sonst Massenware alles, Einzelware 1. Rueckgabe Menge, Alle gewaehlt
function S.Qty(it)
    it = it or S.it
    if not it then return 0, false end
    local max = S.MaxQty(it)
    local q = S.qty and S.qty.key == it.key and S.qty.qty or nil
    if q == nil then
        if it.commodity then return max, true end
        return 1, false
    end
    if q <= 0 then return max, true end
    return math.max(1, math.min(q, max)), false
end

function S.SetQty(n)
    if not S.it then return end
    n = tonumber(n)
    S.qty = { key = S.it.key, qty = (n and n >= 1) and math.floor(n) or 0 }
    S.Update()
end

function S.Hours()
    local h = tonumber(S.hours)
    for _, x in ipairs(S.HOURS) do if x == h then return h end end
    return ns.Data.Duration(mod.db)
end

function S.SetHours(h)
    S.hours = h
    S.Update()
end

-- Preise der Knoepfe (wie bisher im Kasten, Advice.Prices) und der Rat dazu
function S.Prices(it, r)
    local A = ns.Advice
    if not (A and it) then return {} end
    local lot = ns.Lots and ns.Lots.ForKey(it.key) or nil
    return A.Prices(it.key, ns.Data.Lookup(it.key), lot, r)
end

-- Preis je Stueck: eigener, sonst Vorschlag, sonst Guenstige, sonst Blizzards Vorgabe
function S.Price(it, prices)
    it = it or S.it
    if not it then return nil end
    local o = S.own
    if o and o.key == it.key and Num(o.price) and o.price > 0 then return o.price end
    prices = prices or S.Prices(it)
    return prices.suggest or prices.cheap or (Num(it.price) and it.price > 0 and it.price or nil)
end

function S.SetPrice(price)
    if not S.it then return end
    S.own = (Num(price) and price > 0) and { key = S.it.key, price = math.floor(price) } or nil
    S.Update()
end

-- Preis von aussen (Pakete): gilt, sobald der Gegenstand auf der Seite liegt
function S.SetOwnPrice(key, price)
    if key == nil or not Num(price) or price <= 0 then return end
    S.own = { key = key, price = math.floor(price) }
    if S.Shown() then S.Update() end
end

-- Einstellgebuehr fuer Menge und Dauer (Spiel, sonst Broker-Rechnung)
function S.Deposit(it, qty, hours)
    if not it then return nil end
    local ah = AHApi()
    local dur = ns.Data.DUR_INDEX[hours] or 2
    if ah then
        if it.commodity and ah.CalculateCommodityDeposit and it.id then
            local ok, v = pcall(ah.CalculateCommodityDeposit, it.id, dur, qty)
            if ok and Num(v) then return v end
        elseif not it.commodity and ah.CalculateItemDeposit then
            local ok, v = pcall(ah.CalculateItemDeposit, it.loc, dur, qty)
            if ok and Num(v) then return v end
        end
    end
    local hp = ns.VendorPrice(it.id or it.key)
    local ok, v = pcall(ns.Data.Deposit, hp, qty, { duration = hours })
    if ok and Num(v) then return v end
    return nil
end

-- Rat zum Preis auf der Seite (gleiche Rechnung wie der Kasten, ohne Blizzards Preisfeld anzufassen)
function S.Judge(it, price, qty)
    local A, D = ns.Advice, ns.Data
    local e = D.Lookup(it.key)
    local hp = ns.VendorPrice(it.id or it.key)
    local r = A.Judge(e, it.key, price, qty, hp, mod.db)
    r.key = it.key
    local x = { key = it.key, id = it.id, price = price, qty = qty, commodity = it.commodity }
    A.CheckVariant(r, x, e)
    A.CheckNoOffers(r, x, e, hp)
    A.CheckBait(r, x)
    return r, e, hp
end

-- Gewinn mit Aufschluesselung: { gain, net, cost, fee, cut } oder nil
function S.Gain(it, price, qty, r)
    if not (it and Num(price) and price > 0 and qty and qty > 0) then return nil end
    local cut = ns.Data.Cut()
    local net = price * qty * (1 - cut)
    local lot = ns.Lots and ns.Lots.ForKey(it.key) or nil
    local g = ns.Advice.Profit({ net = net, qty = qty, key = it.key }, lot)
    if not g then return nil end
    g.net, g.cut, g.total = math.floor(net + 0.5), cut, price * qty
    return g
end

---------------------------------------------------------------------------
-- Einstellen (nur aus einem Klick)
---------------------------------------------------------------------------
function S.Post()
    if not AHOpen() then return end
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.SELL_COMBAT); return end
    local ah = AHApi()
    local p = S.post
    if p and p.state == "confirm" and S.it and p.key == S.it.key then
        local fn = p.commodity and ah.ConfirmPostCommodity or ah.ConfirmPostItem
        local ok
        if p.commodity then ok = fn and pcall(fn, p.loc, p.dur, p.qty, p.price)
        else ok = fn and pcall(fn, p.loc, p.dur, p.qty, nil, p.price) end
        if ok then p.state, p.t = "posting", Now() else S.post = nil; mod:Print(L.SELL_POST_FAILED) end
        S.Update()
        return
    end
    if p and p.state == "posting" and Now() - p.t < S.POST_WAIT then return end
    local it = S.Sync()
    if not it then return end
    local price = S.Price(it)
    local qty = S.Qty(it)
    if not Num(price) or price <= 0 or qty < 1 then return end
    local hours = S.Hours()
    local dur = ns.Data.DUR_INDEX[hours] or 2
    local ok, needs
    if it.commodity then
        if not ah.PostCommodity then mod:Print(L.SELL_POST_FAILED); return end
        ok, needs = pcall(ah.PostCommodity, it.loc, dur, qty, price)
    else
        if not ah.PostItem then mod:Print(L.SELL_POST_FAILED); return end
        ok, needs = pcall(ah.PostItem, it.loc, dur, qty, nil, price)
    end
    if not ok then mod:Print(L.SELL_POST_FAILED); return end
    S.post = { key = it.key, loc = it.loc, dur = dur, qty = qty, price = price, commodity = it.commodity,
               name = it.link, state = needs == true and "confirm" or "posting", t = Now() }
    ns.Radar.lastSend = Now()   -- Einstellen zaehlt wie eine Abfrage (Bremse des Spiels)
    -- wie Blizzards Knopf: Letzter Preis und Posten nach der Bestaetigung des Spiels (Lots.OnCreated)
    if ns.Lots then ns.Lots.pendingPost = { key = it.key, qty = qty, price = price, t = Now() } end
    if needs == true then mod:Print(L.SELL_CONFIRM_ASK) end
    S.Update()
end

function S.OnPostWarning()
    local p = S.post
    if p and p.state == "posting" and Now() - p.t < S.POST_WAIT then
        p.state = "confirm"
        mod:Print(L.SELL_CONFIRM_ASK)
        if S.Shown() then S.Update() end
    end
end

function S.OnCreated()
    local p = S.post
    if not p or p.state ~= "posting" then return end
    S.post = nil
    S.done = { key = p.key, qty = p.qty, price = p.price, t = Now() }
    S.own = nil   -- naechster Stapel beginnt wieder beim Vorschlag
    if S.Shown() then S.Update() end
end

function S.StatusText()
    local p = S.post
    if p then
        if p.state == "confirm" then return ORANGE .. L.SELL_CONFIRM_ASK .. "|r" end
        return GREY .. L.SELL_POSTING .. "|r"
    end
    local d = S.done
    if d and Now() - d.t < 60 then return GREEN .. L.SELL_POSTED:format(d.qty, Money(d.price)) .. "|r" end
    return ""
end

---------------------------------------------------------------------------
-- Aufbau
---------------------------------------------------------------------------
S.X, S.FIELD_X = 16, 93
S.PRICE_Y, S.BTN_Y, S.QTY_Y, S.DUR_Y = -96, -120, -150, -176
S.DEP_Y, S.ROW_STEP = -202, 17
S.POST_TOP = -260
S.LOTS_Y = -308
S.TIER_H = 152
S.INFO_STEP = 16
S.INFO_ROWS = 8

local function Typing(m)
    if not m then return false end
    for _, k in ipairs({ "gold", "silver", "copper" }) do
        local e = m[k]
        if e and e.HasFocus and e:HasFocus() then return true end
    end
    return false
end

local function SliderSet(s, lo, hi, pos, enabled)
    if s.peonMin ~= lo or s.peonMax ~= hi or s.peonVal ~= pos then
        S.sync = true
        if type(s.Slider) == "table" and type(s.Init) == "function" then
            local mix = rawget(_G, "MinimalSliderWithSteppersMixin")
            local right = mix and mix.Label and mix.Label.Right
            pcall(s.Init, s, pos, lo, hi, math.max(1, hi - lo), right and { [right] = function() return "" end } or nil)
            if type(s.RightText) == "table" and s.RightText.Hide then s.RightText:Hide() end
        else
            if s.SetMinMaxValues then s:SetMinMaxValues(lo, hi) end
            if s.SetValue then s:SetValue(pos) end
        end
        S.sync = false
        s.peonMin, s.peonMax, s.peonVal = lo, hi, pos
    end
    if s.peonOn ~= enabled then
        s.peonOn = enabled
        if type(s.SetEnabled) == "function" then pcall(s.SetEnabled, s, enabled)
        elseif enabled then s:Enable() else s:Disable() end
    end
end

function S.OnSlider(v)
    if S.sync or not S.it or not Num(v) then return end
    v = math.floor(v + 0.5)
    if S.it.commodity then S.SetQty(v <= 0 and 0 or v) else S.SetQty(math.max(1, v)) end
end

-- Zeile mit Beschriftung links und Wert (fuer Gebuehr, Gesamtpreis, Gewinn)
local function ValueRow(parent, label, y, tipFn)
    local UI = Peon.UI
    local r = {}
    r.label = UI.Text(parent, "label", label)
    r.label:SetJustifyH("LEFT")
    r.label:SetPoint("TOPLEFT", S.X, y)
    r.value = UI.Text(parent, "text", "")
    r.value:SetPoint("TOPLEFT", r.label, "TOPLEFT", S.FIELD_X, 0)
    if tipFn then
        r.hover = CreateFrame("Frame", nil, parent)
        r.hover:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y + 2)
        r.hover:SetSize(UI.LEFT_W - 16, S.ROW_STEP)
        if r.hover.EnableMouse then r.hover:EnableMouse(true) end
        UI.SetTooltip(r.hover, tipFn)
    end
    return r
end

function S.Build(c)
    local UI = Peon.UI
    S.frame = c
    local left = UI.Panel(c, "left")
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(UI.LEFT_W)
    S.left = left
    S.sectionTab = UI.SectionTab(left, L.SELL_PAGE_HEAD)
    S.header = UI.ItemHeader(left)
    S.header:SetPoint("TOPLEFT", 10, -10)
    S.header:SetScript("OnEnter", function(self)
        if S.key == nil then return end
        W.ShowItemTooltip(self, S.key)
    end)
    S.header:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    if S.header.RegisterForClicks then pcall(S.header.RegisterForClicks, S.header, "LeftButtonUp", "RightButtonUp") end
    S.header:SetScript("OnClick", function(self, button)
        if button == "RightButton" and S.key ~= nil then mod:Call("Menue", ns.Go.Menu, { key = S.key }, self) end
    end)
    S.empty = UI.Text(left, "text", GREY .. L.SELL_PAGE_EMPTY .. "|r", UI.LEFT_W - 32)
    S.empty:SetPoint("TOPLEFT", S.X, -96)

    -- Preis je Stueck und die Knoepfe darunter
    S.priceLabel = UI.Text(left, "label", L.SELL_PAGE_PRICE)
    S.priceLabel:SetPoint("TOPLEFT", S.X, S.PRICE_Y)
    S.priceInput = UI.MoneyInput(left, function(amount) S.SetPrice(amount) end)
    if S.priceInput.SetScale then S.priceInput:SetScale(0.8) end
    S.priceInput:SetPoint("LEFT", S.priceLabel, "LEFT", S.FIELD_X / 0.8, 0)
    S.btn = {}
    local A = ns.Advice
    local bw = math.floor((UI.LEFT_W - 28) / #A.BUTTONS)
    for i, k in ipairs(A.BUTTONS) do
        local b = UI.Button(left, L["ADV_BTN_" .. k:upper()], bw - 2, function()
            local p = S.prices and S.prices[k]
            if Num(p) then S.SetPrice(p) end
        end)
        b:SetPoint("TOPLEFT", 12 + (i - 1) * bw, S.BTN_Y)
        UI.SetTooltip(b, function()
            local p = S.prices and S.prices[k]
            local tip = (k == "target" and S.prices and S.prices.targetSrc == "watch") and L.ADV_BTN_TARGET_WATCH_TIP or L["ADV_BTN_" .. k:upper() .. "_TIP"]
            return { L["ADV_BTN_" .. k:upper()], tip, Num(p) and Money(p) or (GREY .. L.ADV_BTN_NONE .. "|r") }
        end)
        S.btn[k] = b
    end

    -- Menge: Regler (Massenware links Alle, dann 1 bis alles in den Taschen), Feld daneben
    S.qtyLabel = UI.Text(left, "label", L.FOCUS_R_QTY)
    S.qtyLabel:SetPoint("TOPLEFT", S.X, S.QTY_Y)
    S.qtySlider = UI.Slider(left, 110, 0, 1, 1, 0, function(v) S.OnSlider(v) end)
    S.qtySlider:SetPoint("LEFT", S.qtyLabel, "LEFT", S.FIELD_X, 0)
    UI.SetTooltip(S.qtySlider, { L.FOCUS_R_QTY, L.SELL_PAGE_QTY_TIP })
    S.qtyInput = UI.Input(left, 56, { numeric = true, maxLetters = 6 })
    if S.qtyInput.SetScale then S.qtyInput:SetScale(0.8) end
    if S.qtyInput.SetJustifyH then S.qtyInput:SetJustifyH("RIGHT") end
    if S.qtyInput.SetTextInsets then S.qtyInput:SetTextInsets(6, 8, 0, 0) end
    S.qtyInput:SetPoint("LEFT", S.qtySlider, "RIGHT", 6 / 0.8, 0)
    S.qtyInput:HookScript("OnTextChanged", function(self, user)
        if user then S.SetQty(tonumber(self:GetText() or "") or 0) end
    end)
    S.qtyAll = UI.Text(left, "small", GREY .. L.QUICK_QTY_ALL0 .. "|r")
    S.qtyAll:SetPoint("LEFT", S.qtyInput, "LEFT", 10 * 0.8, 0)

    -- Dauer: drei Knoepfe
    S.durLabel = UI.Text(left, "label", L.SELL_PAGE_DUR)
    S.durLabel:SetPoint("TOPLEFT", S.X, S.DUR_Y)
    S.durBtn = {}
    for i, h in ipairs(S.HOURS) do
        local b = UI.Button(left, L.SELL_PAGE_HOURS:format(h), 44, function() S.SetHours(h) end)
        b:SetPoint("LEFT", S.durLabel, "LEFT", S.FIELD_X + (i - 1) * 46, 0)
        b.hours = h
        S.durBtn[i] = b
    end

    -- Gebuehr, Gesamtpreis, Gewinn (Aufschluesselung im Tooltip)
    S.depRow = ValueRow(left, L.SELL_PAGE_DEPOSIT, S.DEP_Y, function() return { L.SELL_PAGE_DEPOSIT, L.SELL_PAGE_DEPOSIT_TIP } end)
    S.totalRow = ValueRow(left, L.SELL_PAGE_TOTAL, S.DEP_Y - S.ROW_STEP)
    S.gainRow = ValueRow(left, L.SELL_PAGE_GAIN, S.DEP_Y - 2 * S.ROW_STEP, function() return S.GainTip() end)

    S.postButton = UI.Button(left, L.SELL_PAGE_POST, UI.LEFT_W - 20, function() mod:Call("Verkaufen", S.Post) end, "gold")
    S.postButton:SetPoint("TOPLEFT", 10, S.POST_TOP)
    S.status = UI.Text(left, "small", "", UI.LEFT_W - 20)
    S.status:SetJustifyH("CENTER")
    S.status:SetPoint("TOP", S.postButton, "BOTTOM", 0, -4)

    S.BuildLots(left)
    S.BuildRight(c, left)
    S.Update()
end

---------------------------------------------------------------------------
-- Zum Einstellen links unten: Posten waehlen, der sichere Knopf legt ihn per Klick in Blizzards Verkaufsfenster
-- (derselbe Klick wie der Rechtsklick in der Tasche, Lots.lua). Danach liegt er auf dieser Seite.
---------------------------------------------------------------------------
function S.BuildLots(left)
    local UI = Peon.UI
    S.lotsLine = UI.Divider(left, UI.LEFT_W - 24)
    S.lotsLine:SetPoint("TOPLEFT", 12, S.LOTS_Y + 8)
    S.lotsHead = UI.Text(left, "label", L.LOTS_TITLE)
    S.lotsHead:SetPoint("TOPLEFT", S.X, S.LOTS_Y)
    local lp = UI.Panel(left, "list", true)
    lp:SetPoint("TOPLEFT", 6, S.LOTS_Y - 18)
    lp:SetPoint("BOTTOMRIGHT", -6, 34)
    S.lotsPanel = lp
    S.lots = UI.Table(lp, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
              color = function(r) return UI.QualityColor(r.quality or 1) end },
            { key = "qty", title = L.FOCUS_R_QTY, width = 44, align = "RIGHT" },
            { key = "bags", title = L.LOTS_COL_BAGS, width = 54, align = "RIGHT",
              format = function(v) if v and v > 0 then return tostring(v) end return GREY .. L.LOTS_MAIL .. "|r" end },
        },
        sortKey = "name", icon = true, empty = L.LOTS_EMPTY,
        onClick = function(r, button)
            if button == "RightButton" then if ns.Lots then ns.Lots.Menu(r, lp) end; return end
            mod:Call("Verkaufen", S.SelectLot, r)
        end,
        onEnter = function(row, r) if r then W.ShowItemTooltip(row, r.key) end end,
    })
    local b = CreateFrame("Button", "PeonBrokerSellPageLotButton", left, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    b:SetSize(UI.LEFT_W - 20, 22)
    b:SetPoint("BOTTOMLEFT", 10, 8)
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    b:SetText(L.LOTS_PICK)
    b:Disable()
    UI.SetTooltip(b, { L.LOTS_TITLE, L.SELL_PAGE_LOT_TIP })
    S.lotButton = b
end

local function InCombat() return InCombatLockdown and InCombatLockdown() or false end

-- Posten waehlen: den sicheren Knopf auf seinen Taschenplatz richten (wie Lots.Select)
function S.SelectLot(row)
    S.lotSel = row
    local b, LT = S.lotButton, ns.Lots
    if not (b and LT) then return end
    local text, ready = L.LOTS_POST, false
    if not row then text = L.LOTS_PICK
    elseif not ((row.bags or 0) > 0) then text = L.LOTS_IN_MAIL
    elseif InCombat() then text = L.LOTS_COMBAT
    else
        local bag, slot = LT.FindBagSlot(row.key)
        local name = bag and LT.FindButton(bag, slot)
        if name then
            b:SetAttribute("type", "macro")
            b:SetAttribute("macrotext", "/click " .. name .. " RightButton")
            ready = true
        else
            text = L.LOTS_NO_SLOT
        end
    end
    if not ready and not InCombat() then b:SetAttribute("type", nil); b:SetAttribute("macrotext", nil) end
    b:SetText(ready and L.SELL_PAGE_LOT_PUT or text)
    if ready then b:Enable() else b:Disable() end
end

function S.RefreshLots()
    if not (S.lots and ns.Lots) then return end
    local rows = ns.Lots.Rows()
    S.lots:SetData(rows)
    S.lotsHead:SetText(L.LOTS_TITLE .. ((#rows > 0) and (" (" .. #rows .. ")") or ""))
    local sel
    for _, r in ipairs(rows) do if S.lotSel and r.lot == S.lotSel.lot then sel = r end end
    S.SelectLot(sel)
end

---------------------------------------------------------------------------
-- Rechts: Angebote jetzt, Hinweise als Tabelle, Marktlage
---------------------------------------------------------------------------
function S.BuildRight(c, left)
    local UI = Peon.UI
    local right = UI.Panel(c, "list", true)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", UI.GAP, -30)
    right:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    right:SetHeight(S.TIER_H)
    S.stand = UI.Text(c, "text", "")
    S.stand:SetPoint("BOTTOMLEFT", right, "TOPLEFT", 8, 8)
    S.offers = UI.Table(right, {
        columns = {
            { key = "price", title = L.ITEM_TIER_PRICE, align = "RIGHT", format = function(v) return Money(v) end },
            { key = "qty", title = L.ITEM_COL_QTY, width = 80, align = "RIGHT" },
            { key = "cum", title = L.ITEM_TIER_CUM, width = 80, align = "RIGHT" },
        },
        sortKey = "price", empty = L.FOCUS_TIER_WAIT,
        rowBg = function(r)
            if r and r.isOwn then return 0.7, 0.4, 1, 0.25 end     -- eigenes Angebot lila
            if r and r.under then return 1, 0.4, 0.4, 0.18 end     -- unter meinem Preis
        end,
        -- Klick auf eine Stufe: knapp darunter einstellen (wie Blizzards Liste), Rechtsklick: genau diesen Preis
        onClick = function(r, button)
            if not (r and Num(r.price)) or r.isOwn or not S.key then return end
            local p = r.price
            if button ~= "RightButton" then p = ns.Data.Undercut(r.price, S.key, mod.db) or r.price end
            S.SetPrice(p)
        end,
    })
    local mp = UI.Panel(c, "right")
    mp:SetPoint("TOPLEFT", right, "BOTTOMLEFT", 0, -2)
    mp:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
    S.infoPanel = mp
    S.title = UI.Text(mp, "big", "")
    S.title:SetPoint("TOPLEFT", 12, -8)
    S.why = UI.Text(mp, "text", "", W.WIDTH - 2 * W.SIDE - UI.LEFT_W - UI.GAP - 30)
    S.why:SetPoint("TOPLEFT", S.title, "BOTTOMLEFT", 0, -4)
    S.info = {}
    for i = 1, S.INFO_ROWS do
        local r = {}
        r.label = UI.Text(mp, "label", "")
        r.label:SetWidth(120)
        r.label:SetJustifyH("LEFT")
        r.value = UI.Text(mp, "text", "")
        r.value:SetPoint("TOPLEFT", r.label, "TOPRIGHT", 8, 0)
        S.info[i] = r
    end
    -- Marktlage: dieselben drei Zeilen wie im Einkaufen (Rechtsklick waehlt, gilt fuer beide Seiten)
    S.marketHead = UI.Text(mp, "label", L.SELL_PAGE_MARKET)
    S.marketHead:SetPoint("BOTTOMLEFT", mp, "BOTTOMLEFT", 12, 8 + 3 * 16 + 4)
    S.market = {}
    local w = W.WIDTH - 2 * W.SIDE - UI.LEFT_W - UI.GAP - 24
    for i = 1, 3 do
        local y = 8 + (3 - i) * 16
        local r = { index = i }
        r.label = UI.Text(mp, "label", "")
        r.label:SetWidth(110)
        r.label:SetJustifyH("LEFT")
        r.label:SetPoint("BOTTOMLEFT", mp, "BOTTOMLEFT", 12, y)
        r.value = UI.Text(mp, "text", "", w - 120)
        r.value:SetPoint("TOPLEFT", r.label, "TOPRIGHT", 8, 0)
        r.hover = CreateFrame("Frame", nil, mp)
        r.hover:SetPoint("BOTTOMLEFT", mp, "BOTTOMLEFT", 6, y - 2)
        r.hover:SetSize(w, 16)
        if r.hover.EnableMouse then r.hover:EnableMouse(true) end
        r.hover:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(r.label:GetText() or "", 1, 0.82, 0)
            for _, line in ipairs(r.tip or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
            GameTooltip:AddLine(L.QUICK_ROW_HINT, 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r.hover:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        r.hover:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" then mod:Call("Verkaufen", ns.Focus.MarketRowMenu, i, self) end
        end)
        S.market[i] = r
    end
end

-- Angebote der letzten Abfrage (seit der Gegenstand auf der Seite liegt) mit Summe, eigene lila
function S.LiveRows()
    if S.key == nil or not AHOpen() then return nil end
    local lv = ns.Buy.live and ns.Buy.live[S.key]
    if type(lv) ~= "table" or type(lv.rows) ~= "table" or (lv.t or 0) < (S.since or 0) then return nil end
    return lv.rows, lv.t
end

function S.OfferRows(rows, price)
    local out, cum = {}, 0
    for _, l in ipairs(ns.Data.Available(rows or {})) do
        cum = cum + l.qty
        out[#out + 1] = { price = l.price, qty = l.qty, cum = cum, under = Num(price) and l.price < price or false }
    end
    for _, r in ipairs(rows or {}) do
        if Num(r.own) and r.own > 0 and Num(r.price) then
            out[#out + 1] = { price = r.price, qty = L.QUICK_OWN_QTY:format(r.own), isOwn = true }
        end
    end
    table.sort(out, function(a, b)
        if a.price ~= b.price then return a.price < b.price end
        return (a.isOwn and 1 or 0) < (b.isOwn and 1 or 0)
    end)
    return out
end

-- Hinweise als Zeilen { label, value }
function S.InfoRows(it, r, e, hp, price, qty)
    local rows = {}
    local function Row(label, value) if value and value ~= "" then rows[#rows + 1] = { label, value } end end
    if r.band then Row(L.ADV_ROW_RANGE, ns.Tooltip.RangeText(r.band)) end
    if r.sales and ns.Sales then
        Row(L.ADV_ROW_SALES, ns.Sales.PerHourText(r.sales))
        if Num(r.sales.rate) then Row(L.ADV_ROW_RATE, L.ADV_RATE:format(math.floor(r.sales.rate * 100 + 0.5))) end
    end
    if Num(hp) and hp > 0 then Row(L.ADV_ROW_VENDOR, Money(hp)) end
    local bait = r.bait or (S.prices and S.prices.bait)
    if bait then Row(L.ADV_ROW_BAIT, L.ADV_BAIT_ROW:format(bait.qty, Money(bait.top))) end
    local lot = ns.Lots and ns.Lots.ForKey(it.key) or nil
    if lot then
        local unit = ns.Lots.UnitCost(lot)
        Row(L.SELL_PAGE_LOT, L.SELL_PAGE_LOT_VAL:format(unit and Money(math.floor(unit + 0.5)) or "?", lot.target and Money(lot.target) or "?"))
    end
    if ns.AtNeutralAH and ns.AtNeutralAH() then Row(L.SELL_PAGE_HOUSE, L.ADV_NEUTRAL) end
    return rows
end

function S.GainTip()
    local g = S.gain
    if not g then return { L.SELL_PAGE_GAIN, GREY .. L.ADV_BTN_NONE .. "|r" } end
    local lines = { L.SELL_PAGE_GAIN }
    lines[#lines + 1] = L.SELL_PAGE_TIP_TOTAL:format(Money(g.total))
    lines[#lines + 1] = L.SELL_PAGE_TIP_CUT:format(ns.Focus.Dec(g.cut * 100), Money(math.max(0, g.total - g.net)))
    if g.cost then lines[#lines + 1] = L.SELL_PAGE_TIP_COST:format(Money(g.cost))
    else lines[#lines + 1] = GREY .. L.ADV_PROFIT_NOCOST .. "|r" end
    if g.fee then lines[#lines + 1] = L.SELL_PAGE_TIP_FEE:format(Money(g.fee)) end
    lines[#lines + 1] = L.SELL_PAGE_TIP_GAIN:format(ns.Radar.SignedMoney(g.gain))
    lines[#lines + 1] = GREY .. L.SELL_PAGE_TIP_DEPOSIT .. "|r"
    return lines
end

local function ClearMoney(t)
    if not t then return end
    for _, k in ipairs({ "gold", "silver", "copper" }) do if t[k] then t[k]:SetText("") end end
end

-- Anzeige
function S.Update()
    if not S.left then return end
    local it = S.Sync()
    local has = it ~= nil
    for _, f in ipairs({ S.priceLabel, S.priceInput, S.qtyLabel, S.qtySlider, S.qtyInput, S.durLabel, S.depRow.label, S.depRow.value,
                         S.totalRow.label, S.totalRow.value, S.gainRow.label, S.gainRow.value, S.gainRow.hover, S.depRow.hover }) do
        f:SetShown(has)
    end
    for _, b in pairs(S.btn) do b:SetShown(has) end
    for _, b in ipairs(S.durBtn) do b:SetShown(has) end
    S.empty:SetShown(not has)
    S.RefreshLots()
    if not has then
        S.header:Set(nil, "", 1)
        S.qtyAll:Hide()
        S.postButton:SetText(L.SELL_PAGE_POST); S.postButton:Disable()
        S.status:SetText(S.StatusText())
        S.offers:SetData({})
        S.stand:SetText(AHOpen() and "" or (GREY .. L.TAB_AH_ONLY .. "|r"))
        S.title:SetText(""); S.why:SetText("")
        for _, r in ipairs(S.info) do r.label:SetText(""); r.value:SetText("") end
        for _, r in ipairs(S.market) do r.label:SetText(""); r.value:SetText(""); r.tip = nil end
        S.gain = nil
        return
    end
    local D = ns.Data
    local e = D.Lookup(it.key)
    local name = D.ItemName(it.key, e) or (it.link and it.link:match("%[(.-)%]")) or tostring(it.key)
    S.header:Set(ns.Buy.Icon(it.id), name, type(e) == "table" and e.ql or nil)
    -- Preis, Knoepfe
    S.prices = S.Prices(it)
    local price = S.Price(it, S.prices)
    local qty, all = S.Qty(it)
    local r, _, hp = S.Judge(it, price, qty)
    S.prices = S.Prices(it, r)   -- mit dem Vergleichspreis des Rats (ohne Angebote)
    price = S.Price(it, S.prices)
    if not Typing(S.priceInput) then
        if Num(price) and price > 0 then S.priceInput:SetAmount(price) else ClearMoney(S.priceInput) end
    end
    for k, b in pairs(S.btn) do
        On(b, Num(S.prices[k]))
        if k == "target" then b:SetShown(Num(S.prices[k])) end
    end
    -- Menge
    local max = S.MaxQty(it)
    local typingQty = S.qtyInput.HasFocus and S.qtyInput:HasFocus()
    if not typingQty then S.qtyInput:SetText(all and "" or tostring(qty)) end
    S.qtyAll:SetShown(all and not typingQty)
    if it.commodity then
        if max >= 1 then SliderSet(S.qtySlider, 0, max, all and 0 or qty, max > 1) else SliderSet(S.qtySlider, 0, 1, 0, false) end
    else
        if max >= 2 then SliderSet(S.qtySlider, 1, max, qty, true) else SliderSet(S.qtySlider, 0, 1, 1, false) end
    end
    -- Dauer
    local hours = S.Hours()
    for _, b in ipairs(S.durBtn) do
        if b.LockHighlight then if b.hours == hours then b:LockHighlight() else b:UnlockHighlight() end end
    end
    -- Gebuehr, Gesamtpreis, Gewinn
    local dep = S.Deposit(it, qty, hours)
    S.depRow.value:SetText(Num(dep) and Money(dep) or "-")
    S.totalRow.value:SetText(Num(price) and Money(price * qty) or "-")
    S.gain = S.Gain(it, price, qty, r)
    if S.gain then
        S.gainRow.value:SetText((S.gain.gain >= 0 and GREEN or RED) .. ns.Radar.SignedMoney(S.gain.gain) .. "|r")
    else
        S.gainRow.value:SetText("-")
    end
    -- Knopf
    local p = S.post
    local busy = p and p.state == "posting" and Now() - p.t < S.POST_WAIT
    if p and p.state == "posting" and not busy then S.post, p = nil, nil end
    local confirm = p and p.state == "confirm" and p.key == it.key
    S.postButton:SetText(confirm and L.SELL_PAGE_CONFIRM or L.SELL_PAGE_POST_N:format(qty, Num(price) and Money(price * qty) or "-"))
    On(S.postButton, AHOpen() and not busy and Num(price) and price > 0 and qty >= 1)
    S.status:SetText(S.StatusText())
    -- rechts: Angebote
    local rows, t = S.LiveRows()
    S.offers:SetData(rows and S.OfferRows(rows, price) or {})
    if not AHOpen() then S.stand:SetText(GREY .. L.TAB_AH_ONLY .. "|r")
    elseif t then S.stand:SetText(L.FOCUS_LIVE:format(ns.Scan.Age(t)))
    else S.stand:SetText(GREY .. L.FOCUS_LIVE_WAIT .. "|r") end
    -- Rat und Hinweise
    local col = ns.Advice.COLORS[r.kind] or ns.Advice.COLORS.none
    S.title:SetText(r.title or "")
    S.title:SetTextColor(col[1], col[2], col[3])
    S.why:SetText(r.extra and ((r.why or "") .. " " .. r.extra) or (r.why or ""))
    local info = S.InfoRows(it, r, e, hp, price, qty)
    local h = S.why.GetStringHeight and S.why:GetStringHeight() or 14
    if not Num(h) or h < 12 then h = 14 end
    local y0 = -30 - h - 6
    for i, row in ipairs(S.info) do
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", 12, y0 - (i - 1) * S.INFO_STEP)
        local x = info[i]
        row.label:SetText(x and x[1] or "")
        row.value:SetText(x and x[2] or "")
    end
    -- Marktlage (Messung nur fuer den Gegenstand dieser Seite)
    local M = ns.Measure
    local v = (M and M.cur and M.cur.key == it.key and AHOpen()) and M.Values() or nil
    local F = ns.Focus
    local vals, tips, code = F.QuickMoveValues(v, it.key)
    for i, m in ipairs(S.market) do
        local kind = F.MarketRowKind(i)
        m.label:SetText(L[F.MARKET_LABEL[kind]] or "")
        local text, tip = F.MarketRowValue(kind, v, vals, tips, code, it.key)
        m.value:SetText(text or "")
        m.tip = tip
    end
end

-- Seite geoeffnet: Gegenstand lesen und abfragen
function S.Open()
    S.Sync()
    if S.key ~= nil and AHOpen() then
        ns.Radar.LoadIfStale()
        ns.Radar.SetFocus(S.key)
    end
    S.Update()
end

function S.Init()
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_POST_WARNING", function() mod:Call("Verkaufen", S.OnPostWarning) end)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_AUCTION_CREATED", function() mod:Call("Verkaufen", S.OnCreated) end)
end

W.pages.sell = {
    build = S.Build,
    refresh = function() S.Open() end,
    leave = function() ns.Radar.Halt() end,
}
