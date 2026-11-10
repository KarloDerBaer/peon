-- Peon_Broker - Advice.lua
-- Umbau U3 (ab 0.44, Konzept Peon_Broker_Umbau.md, Abschnitt 7.2): Rat im Blizzard-Verkaufsfenster.
-- Blizzard traegt beim Hineinlegen selbst das guenstigste Angebot als Preis ein. Broker aendert daran nichts
-- (KarloDerBaer), sondern sagt in einem Kasten unter "Auktion erstellen", ob man zu dem Preis verkaufen soll,
-- der gerade im Feld steht, und warum.
--
-- Technik:
--   * Sicherer Anhang an UpdatePostState von ItemSellFrame und CommoditiesSellFrame: Blizzard ruft das beim
--     Hineinlegen, bei geaendertem Preis und geaenderter Menge. Broker liest Gegenstand, Preis und Menge nur aus.
--   * Die Angebote, die Blizzard fuer das Verkaufsfenster ohnehin laedt, liest Broker mit (Ergebnis-Ereignisse) und
--     schreibt sie als Live-Stand in die Datenbank. Eine eigene Suche schickt Broker nicht ab.
--   * Gerechnet wird im Markt am offenen Haus (am neutralen Haus also mit den neutralen Preisen und dessen Anteil).
--   * Bei "Blizzard pur" gibt es weder Kasten noch Anhang.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local A = {}
ns.Advice = A

-- Grenzwerte (Konzept: beim Bauen abzustimmen; erster Vorschlag, hier zentral aenderbar)
A.WAIT_PCT = 15      -- "Lieber warten": Preis mehr als 15 % unter dem unteren Rand des ueblichen Bereichs
A.FULL_DAYS = 3      -- "Viel Ware im Markt": Angebote reichen laenger als 3 Tage Absatz
A.WIDTH, A.HEIGHT = 340, 96
A.boxes = {}         -- Verkaufsfenster -> Kasten (nicht am Blizzard-Rahmen gespeichert)

A.COLORS = {
    sell   = { 0.38, 0.88, 0.38 },  -- gruen
    high   = { 0.38, 0.88, 0.38 },
    fall   = { 1.00, 0.82, 0.20 },  -- gelb
    wait   = { 1.00, 0.60, 0.20 },  -- orange
    vendor = { 1.00, 0.30, 0.30 },  -- rot
    none   = { 0.70, 0.70, 0.70 },  -- grau
}

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end

---------------------------------------------------------------------------
-- Der Rat (reine Rechnung, ohne Oberflaeche)
-- e = Eintrag des Gegenstands im Markt, price = Preis je Stueck im Feld, qty = Menge, hp = Haendlerpreis je Stueck
-- Rueckgabe { kind, title, why, extra, band, sales, net, vendor }
---------------------------------------------------------------------------
function A.Judge(e, key, price, qty, hp, db)
    qty = (Num(qty) and qty > 0) and qty or 1
    local r = { price = price, qty = qty }
    if not Num(price) or price <= 0 then
        r.kind, r.title, r.why = "none", L.ADV_NONE, L.ADV_NO_PRICE
        return r
    end
    local cut = ns.Data.Cut()
    r.net = price * qty * (1 - cut)
    if Num(hp) and hp > 0 then r.vendor = hp * qty end

    -- Haendler zahlt mehr als das AH nach Abzug des Anteils
    if r.vendor and r.net < r.vendor then
        r.kind, r.title = "vendor", L.ADV_VENDOR
        r.why = L.ADV_VENDOR_WHY:format(Money(hp), Money(math.floor(price * (1 - cut))))
        return r
    end

    local v = type(e) == "table" and e.m and ns.Data.Evaluate(e, key, 1, hp, db) or nil
    local band = v and v.band
    r.band = band
    r.sales = ns.Sales and type(e) == "table" and ns.Sales.Stats(e, nil, key) or nil
    if not band then
        r.kind, r.title, r.why = "none", L.ADV_NONE, L.ADV_NO_DATA
        return r
    end

    local waitLimit = band.low * (1 - A.WAIT_PCT / 100)
    if price < waitLimit then
        local pct = math.floor((band.low - price) / band.low * 100 + 0.5)
        r.kind, r.title, r.why = "wait", L.ADV_WAIT, L.ADV_WAIT_WHY:format(pct)
    elseif band.trend == "down" then
        r.kind, r.title, r.why = "fall", L.ADV_FALL, L.ADV_FALL_WHY
    elseif price > band.high then
        r.kind, r.title, r.why = "high", L.ADV_SELL, L.ADV_HIGH_WHY
    elseif price < band.low then
        r.kind, r.title, r.why = "sell", L.ADV_SELL, L.ADV_LOW_OK_WHY
    else
        r.kind, r.title, r.why = "sell", L.ADV_SELL, L.ADV_SELL_WHY
    end

    -- Zusatz: viel Ware im Verhaeltnis zum Absatz
    local s = r.sales
    if s and Num(s.perHour) and s.perHour > 0 and type(e) == "table" and Num(e.q) then
        if e.q / s.perHour > A.FULL_DAYS * 24 then r.extra = L.ADV_FULL end
    end
    return r
end

---------------------------------------------------------------------------
-- Blizzards Verkaufsfenster auslesen
---------------------------------------------------------------------------
local function AHFrame()
    local f = rawget(_G, "AuctionHouseFrame")
    return type(f) == "table" and f or nil
end

-- Sichtbares Verkaufsfenster (Einzelgegenstand oder Massenware) und ob es Massenware ist
function A.ActiveSellFrame()
    local f = AHFrame()
    if not f then return nil end
    for _, name in ipairs({ "CommoditiesSellFrame", "ItemSellFrame" }) do
        local sf = rawget(f, name)
        if type(sf) == "table" and sf.IsShown and sf:IsShown() then return sf, name == "CommoditiesSellFrame" end
    end
    return nil
end

local function Call(obj, name, ...)
    if type(obj) ~= "table" or type(obj[name]) ~= "function" then return nil end
    local ok, v = pcall(obj[name], obj, ...)
    if ok and not Peon.IsSecret(v) then return v end
    return nil
end

-- Gegenstand, Schluessel, Preis je Stueck und Menge aus dem Fenster
function A.Read(sf, commodity)
    local loc = Call(sf, "GetItem")
    if type(loc) ~= "table" then return nil end
    local link = C_Item and C_Item.GetItemLink and select(2, pcall(C_Item.GetItemLink, loc)) or nil
    if type(link) ~= "string" or Peon.IsSecret(link) then return nil end
    local key = ns.Data.KeyFromLink(link)
    if key == nil then return nil end
    local price = commodity and Call(sf, "GetUnitPrice") or Call(sf, "GetPrice")
    if not Num(price) and sf.PriceInput then price = Call(sf.PriceInput, "GetAmount") end
    local qty = Call(sf, "GetQuantity")
    return { loc = loc, link = link, key = key, id = ns.Data.ItemID(key), price = price, qty = qty, commodity = commodity }
end

---------------------------------------------------------------------------
-- Kasten
---------------------------------------------------------------------------
-- ab 0.56: ohne Rahmen und ohne Ueberschrift "Broker", dichter unter dem Knopf (KarloDerBaer: Text war abgeschnitten)
local function Box(sf)
    if A.boxes[sf] then return A.boxes[sf] end
    local b = CreateFrame("Frame", nil, sf)
    b:SetSize(A.WIDTH, A.HEIGHT)
    local anchor = rawget(sf, "PostButton")
    if type(anchor) == "table" then b:SetPoint("TOP", anchor, "BOTTOM", 0, -6)
    else b:SetPoint("BOTTOM", sf, "BOTTOM", 0, 40) end
    local title = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.title = title
    local market = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    market:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, -3)
    b.market = market
    local why = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    why:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    why:SetPoint("RIGHT", b, "RIGHT", 0, 0)
    why:SetJustifyH("LEFT")
    b.why = why
    local lines = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lines:SetPoint("TOPLEFT", why, "BOTTOMLEFT", 0, -4)
    lines:SetPoint("RIGHT", b, "RIGHT", 0, 0)
    lines:SetJustifyH("LEFT")
    b.lines = lines
    A.boxes[sf] = b
    return b
end

function A.Show(sf, r, isNeutral)
    local b = Box(sf)
    local c = A.COLORS[r.kind] or A.COLORS.none
    b.title:SetText(r.title or "")
    b.title:SetTextColor(c[1], c[2], c[3])
    b.why:SetText(r.extra and (r.why .. " " .. r.extra) or (r.why or ""))
    b.market:SetText(isNeutral and L.ADV_NEUTRAL or "")
    local parts = {}
    if r.band then parts[#parts + 1] = L.ADV_LINE_RANGE:format(ns.Tooltip.RangeText(r.band)) end
    if r.sales and ns.Sales then parts[#parts + 1] = L.ADV_LINE_SALES:format(ns.Sales.TooltipText(r.sales)) end
    if r.net then
        local erl = L.ADV_LINE_NET:format(Money(r.net), r.qty or 1)
        if r.vendor then erl = erl .. "  " .. L.ADV_LINE_VENDOR:format(Money(r.vendor)) end
        parts[#parts + 1] = erl
    end
    b.lines:SetText(table.concat(parts, "\n"))
    b:Show()
    A.last = r
end

function A.Hide(sf)
    if sf and A.boxes[sf] then A.boxes[sf]:Hide() end
end

-- Neu rechnen fuer ein Verkaufsfenster (nach UpdatePostState oder neuen Angeboten)
function A.Update(sf, commodity)
    if not ns.AHTouch() or type(sf) ~= "table" then return end
    local it = A.Read(sf, commodity)
    if not it then A.Hide(sf); A.current = nil; return end
    A.current = it
    local e = ns.Data.Lookup(it.key)
    local hp = ns.VendorPrice(it.id or it.key)
    local r = A.Judge(e, it.key, it.price, it.qty, hp, mod.db)
    A.Show(sf, r, ns.AtNeutralAH and ns.AtNeutralAH())
end

-- Blizzards Angebote fuer den Gegenstand im Fenster sind da: als Live-Stand uebernehmen, dann neu rechnen
function A.OnResults(commodity, arg)
    local it = A.current
    if not it or not ns.AHTouch() then return end
    local S = ns.Live
    if not S then return end
    local rows
    if commodity then
        if arg ~= it.id or type(S.ReadCommodity) ~= "function" then return end
        rows = S.ReadCommodity(it.id)
    else
        if type(arg) ~= "table" or arg.itemID ~= it.id or type(S.ReadItems) ~= "function" then return end
        rows = S.ReadItems(arg, it.key)
    end
    if type(rows) ~= "table" or #rows == 0 or rows.foreign then return end
    ns.Data.ApplyLive(it.key, rows, time())
    local sf, isCommodity = A.ActiveSellFrame()
    if sf then A.Update(sf, isCommodity) end
end

function A.Hook()
    if A.hooked or not ns.AHTouch() then return end
    local f = AHFrame()
    if not f or not hooksecurefunc then return end
    local done = 0
    for _, name in ipairs({ "CommoditiesSellFrame", "ItemSellFrame" }) do
        local sf = rawget(f, name)
        if type(sf) == "table" and type(sf.UpdatePostState) == "function" then
            local commodity = name == "CommoditiesSellFrame"
            hooksecurefunc(sf, "UpdatePostState", function() mod:Call("Rat beim Verkaufen", A.Update, sf, commodity) end)
            if sf.HookScript then sf:HookScript("OnHide", function() A.current = nil end) end
            done = done + 1
        end
    end
    A.hooked = done > 0
    mod:Dbg("Rat beim Verkaufen: " .. done .. " Verkaufsfenster angehaengt")
end

function A.Init()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function() mod:Call("Rat beim Verkaufen", A.Hook) end)
    mod:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, id) mod:Call("Rat beim Verkaufen", A.OnResults, true, id) end)
    mod:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", function(_, key) mod:Call("Rat beim Verkaufen", A.OnResults, false, key) end)
end
