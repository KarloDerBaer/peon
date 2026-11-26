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
-- Preise fuer die Knoepfe (ab 0.99, Wunsch KarloDerBaer 16.11.2026). Ein Klick schreibt den Preis ins Preisfeld
-- (gleicher Weg wie frueher "Zielpreis eintragen": Lots.FillTarget, gleiche Sperre nach einer Blockade).
--   Guenstige  guenstigstes Angebot anderer Verkaeufer, bei Varianten genau dieser Variante, ohne Unterbieten
--   Vorschlag  Preisvorschlag aus diesem Angebot (oder dem ueblichen Bereich), minus Unterbieten (Data.Suggest)
--   Letzter    zuletzt von mir eingestellter Preis, egal ob verkauft (ab 0.99 gemerkt je Markt in acc.lastPost)
--   Ziel       Zielpreis eines Postens, sonst Zielpreis aus Beobachten (nur zu sehen, wenn es einen gibt)
---------------------------------------------------------------------------
A.BUTTONS = { "cheap", "suggest", "last", "target" }
A.BTN_W, A.BTN_H, A.BTN_GAP = 130, 20, 2

local function LastStore(create)
    local acc = mod.acc
    if type(acc) ~= "table" then return nil end
    if type(acc.lastPost) ~= "table" then
        if not create then return nil end
        acc.lastPost = {}
    end
    local mk = ns.MarketKey and ns.MarketKey() or "?"
    if type(acc.lastPost[mk]) ~= "table" then
        if not create then return nil end
        acc.lastPost[mk] = {}
    end
    return acc.lastPost[mk]
end

function A.SetLastPost(key, price)
    if key == nil or not Num(price) or price <= 0 then return end
    local st = LastStore(true)
    if st then st[key] = { p = math.floor(price), t = time() } end
end

function A.LastPost(key)
    local st = key ~= nil and LastStore(false) or nil
    local x = st and st[key]
    return type(x) == "table" and Num(x.p) and x.p or nil
end

-- Rueckgabe { cheap, suggest, last, target, targetSrc = "lot" oder "watch" }, fehlende Preise nil
-- r (ab 0.103): Rat mit Vergleichspreis r.ref, wenn gerade kein Angebot im Markt steht -> "Vorschlag"
function A.Prices(key, e, lot, r)
    local p = {}
    if key == nil then return p end
    if type(r) == "table" and type(r.ref) == "table" and Num(r.ref.price) then p.suggest = r.ref.price end
    local v = A.var
    if v and v.key == key and Num(v.best) then p.cheap = v.best
    elseif type(e) == "table" and not e.gone and Num(e.m) then p.cheap = e.m end
    -- ab 0.104: Lockangebote nicht beachten, "Guenstige" und "Vorschlag" gehen von der ersten echten Stufe aus
    local b = A.Bait(key)
    if b and (not Num(p.cheap) or p.cheap <= b.top) then p.cheap, p.bait = b.price, b end
    if p.cheap and not p.suggest then
        local te = type(e) == "table" and e or nil
        local ok, vp = pcall(ns.Data.Suggest, p.cheap, te and te.md, key, mod.db, te, te and te.pmd)
        if ok and Num(vp) then p.suggest = vp end
    end
    p.last = A.LastPost(key)
    if lot and Num(lot.target) then
        p.target, p.targetSrc = lot.target, "lot"
    elseif ns.Watch and ns.Watch.Is(key) then
        local w = ns.Watch.Store()[key]
        if type(w) == "table" and Num(w.up) and w.up > 0 then p.target, p.targetSrc = w.up, "watch" end
    end
    return p
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
    -- ab 0.99: zwei Spalten, links der Text, rechts die Preisknoepfe (vorher ein Knopf "Zielpreis eintragen")
    local textW = A.WIDTH - A.BTN_W - 8
    local title = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.title = title
    local market = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    market:SetPoint("LEFT", title, "RIGHT", 6, 0)
    b.market = market
    local why = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    why:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    why:SetPoint("RIGHT", b, "LEFT", textW, 0)
    why:SetJustifyH("LEFT")
    b.why = why
    local lines = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lines:SetPoint("TOPLEFT", why, "BOTTOMLEFT", 0, -4)
    lines:SetPoint("RIGHT", b, "LEFT", textW, 0)
    lines:SetJustifyH("LEFT")
    b.lines = lines
    b.btn = {}
    for i, k in ipairs(A.BUTTONS) do
        local btn = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
        btn:SetSize(A.BTN_W, A.BTN_H)
        btn:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 2 - (i - 1) * (A.BTN_H + A.BTN_GAP))
        if btn.SetNormalFontObject then
            btn:SetNormalFontObject("GameFontNormalSmall")
            btn:SetHighlightFontObject("GameFontHighlightSmall")
            btn:SetDisabledFontObject("GameFontDisableSmall")
        end
        btn.which = k
        btn:SetScript("OnClick", function(self)
            local price = b.prices and b.prices[self.which]
            if ns.Lots and Num(price) then mod:Call("Posten", ns.Lots.FillTarget, sf, { target = price }) end
        end)
        btn:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            local tip = L["ADV_BTN_" .. k:upper() .. "_TIP"]
            if k == "target" and b.prices and b.prices.targetSrc == "watch" then tip = L.ADV_BTN_TARGET_WATCH_TIP end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L["ADV_BTN_" .. k:upper()], 1, 0.82, 0)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            if not (b.prices and Num(b.prices[k])) then GameTooltip:AddLine(L.ADV_BTN_NONE, 0.6, 0.6, 0.6, true)
            elseif ns.Lots and not ns.Lots.CanFill() then GameTooltip:AddLine(L.ADV_LOT_TYPE, 1, 0.4, 0.4, true) end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        b.btn[k] = btn
    end
    A.boxes[sf] = b
    return b
end

-- Knoepfe mit Preis beschriften, ohne Preis (oder nach einer Blockade) grau. "Ziel" nur, wenn es einen gibt.
function A.ShowButtons(b, prices)
    b.prices = prices
    local can = ns.Lots and ns.Lots.CanFill() or false
    for _, k in ipairs(A.BUTTONS) do
        local btn, price = b.btn[k], prices[k]
        local name = L["ADV_BTN_" .. k:upper()]
        btn:SetText(Num(price) and (name .. "  " .. Money(price)) or name)
        if Num(price) and can then btn:Enable() else btn:Disable() end
        btn:SetShown(k ~= "target" or Num(price))
    end
end

-- Moeglicher Gewinn (ab 0.99.1): Erloes nach Gebuehr minus Einkauf. Einkauf je Stueck aus dem Posten, sonst aus
-- Peon_Ledger. Ohne Einkauf zaehlt der Erloes ganz. Ab 0.100 (Wunsch KarloDerBaer) zaehlen offene
-- Einstellgebuehren laut Peon_Ledger (abgelaufene oder abgebrochene Auktionen) je Stueck mit.
-- Rueckgabe { gain, cost, fee } oder nil (ohne Erloes)
function A.Profit(r, lot)
    if not (r and Num(r.net)) then return nil end
    local qty = r.qty or 1
    local unit = lot and ns.Lots and ns.Lots.UnitCost(lot) or nil
    local id = r.key ~= nil and ns.Data.ItemID and ns.Data.ItemID(r.key) or nil
    -- ab 0.140: Durchschnitt des Bestands statt Kosten des naechsten Stuecks (Board KarloDerBaer 26.11.2026)
    if not Num(unit) and id and ns.Item and ns.Item.AvgCost then unit = ns.Item.AvgCost(id) end
    local cost = Num(unit) and math.floor(unit * qty + 0.5) or nil
    local per = id and ns.Item and ns.Item.OpenFee and ns.Item.OpenFee(id) or nil
    local fee = Num(per) and math.floor(per * qty + 0.5) or nil
    if fee and fee <= 0 then fee = nil end
    return { gain = math.floor(r.net + 0.5) - (cost or 0) - (fee or 0), cost = cost, fee = fee }
end

function A.Show(sf, r, isNeutral)
    local b = Box(sf)
    local c = A.COLORS[r.kind] or A.COLORS.none
    b.title:SetText(r.title or "")
    b.title:SetTextColor(c[1], c[2], c[3])
    b.why:SetText(r.extra and (r.why .. " " .. r.extra) or (r.why or ""))
    b.market:SetText(isNeutral and L.ADV_NEUTRAL or "")
    -- ab 0.99.1 (Wunsch KarloDerBaer): jede Angabe in eigener Zeile, Beschriftung gold, unten der moegliche Gewinn
    local parts = {}
    local function Row(label, value) parts[#parts + 1] = "|cffffd100" .. label .. "|r  " .. value end
    if r.band then Row(L.ADV_ROW_RANGE, ns.Tooltip.RangeText(r.band)) end
    if r.sales and ns.Sales then
        Row(L.ADV_ROW_SALES, ns.Sales.PerHourText(r.sales))
        if Num(r.sales.rate) then Row(L.ADV_ROW_RATE, L.ADV_RATE:format(math.floor(r.sales.rate * 100 + 0.5))) end
    end
    if r.net then Row(L.ADV_ROW_NET, L.ADV_FOR:format(Money(math.floor(r.net + 0.5)), r.qty or 1)) end
    if r.vendor then Row(L.ADV_ROW_VENDOR, Money(r.vendor)) end
    local g = A.Profit(r, A.lot)
    if g then
        local col = g.gain >= 0 and "|cff33ff33+" or "|cffff6666-"
        local v = col .. Money(math.abs(g.gain)) .. "|r"
        if g.cost then v = v .. "  |cff999999" .. L.ADV_PROFIT_COST:format(Money(g.cost)) .. "|r"
        else v = v .. "  |cff999999" .. L.ADV_PROFIT_NOCOST .. "|r" end
        if g.fee then v = v .. " |cff999999" .. L.ADV_PROFIT_FEE:format(Money(g.fee)) .. "|r" end
        Row(L.ADV_ROW_PROFIT, v)
    end
    -- ab 0.67 (H3): Posten zum Gegenstand: Einsatz, Ziel, Warnung (ab 0.99 Knopf "Ziel" rechts)
    local lot = A.lot
    if lot then
        local unit = ns.Lots.UnitCost(lot)
        local line = "|cffffd100" .. L.ADV_LOT:format(unit and Money(math.floor(unit + 0.5)) or "?", lot.target and Money(lot.target) or "?") .. "|r"
        local e = r.key and ns.Data.Lookup(r.key)
        if lot.target and type(e) == "table" and not e.gone and e.m and e.m < lot.target then
            line = line .. "\n|cffff6666" .. L.ADV_LOT_UNDER:format(Money(e.m)) .. "|r"
        end
        if not ns.Lots.CanFill() and lot.target then
            line = line .. "\n|cff999999" .. L.ADV_LOT_TYPE .. "|r"
        end
        table.insert(parts, 1, line)
    end
    local prices = A.Prices(r.key, r.key ~= nil and ns.Data.Lookup(r.key) or nil, lot, r)
    -- ab 0.104: Lockangebot nicht beachtet
    local bait = r.bait or prices.bait
    if bait then
        parts[#parts + 1] = "|cffffd100" .. L.ADV_ROW_BAIT .. "|r  " .. L.ADV_BAIT_ROW:format(bait.qty, Money(bait.top))
    end
    A.ShowButtons(b, prices)
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
    if not it then
        A.Hide(sf); A.current = nil
        if ns.SellPage and ns.SellPage.Shown() then ns.SellPage.Update() end   -- ab 0.141
        return
    end
    A.current = it
    local e = ns.Data.Lookup(it.key)
    local hp = ns.VendorPrice(it.id or it.key)
    local r = A.Judge(e, it.key, it.price, it.qty, hp, mod.db)
    r.key = it.key
    A.CheckVariant(r, it, e)
    A.CheckNoOffers(r, it, e, hp)
    A.CheckBait(r, it)
    if A.AutoVariant(sf, r, it) then return A.Update(sf, commodity) end   -- mit dem neuen Preis neu rechnen
    A.lot = ns.Lots and ns.Lots.ForKey(it.key) or nil
    A.Show(sf, r, ns.AtNeutralAH and ns.AtNeutralAH())
    if ns.SellVariant then ns.SellVariant.Refresh() end
    if ns.SellPage and ns.SellPage.Shown() then ns.SellPage.Update() end   -- ab 0.141: neuer Gegenstand auf Brokers Seite
end

-- Ab 0.103.1 (Wunsch KarloDerBaer 17.11.2026): Steht im Feld der Preis einer anderen Variante und kennt Broker das
-- guenstigste Angebot genau dieser Variante aus der Live-Abfrage, traegt er den Vorschlag selbst ein (wie der Knopf
-- "Vorschlag"). Einmal je Gegenstand, solange das Fenster offen ist: Eine eigene Aenderung danach bleibt stehen.
function A.AutoVariant(sf, r, it)
    if r.title ~= L.ADV_VARIANT or not Num(r.fillPrice) then return false end
    local v = A.var
    if not (v and v.key == it.key and Num(v.best)) then return false end
    if A.autoFilled == it.key or not (ns.Lots and ns.Lots.CanFill()) then return false end
    A.autoFilled = it.key
    local ok = ns.Lots.FillTarget(sf, { target = r.fillPrice })
    if ok then mod:Dbg("Variante: Preis selbst eingetragen " .. tostring(r.fillPrice)) end
    return ok and true or false
end

---------------------------------------------------------------------------
-- Varianten (ab 0.97.1, Rueckmeldung KarloDerBaer): Blizzards Liste im Verkaufen zeigt alle Varianten eines
-- Gegenstands mit Zusatz ("... des Baeren", "... des Banditen") und traegt das guenstigste Angebot ein, auch wenn es
-- eine andere Variante ist. Liegt der Preis im Feld unter dem guenstigsten Angebot genau dieser Variante, sagt der
-- Kasten das und bietet "Preis eintragen" an (guenstigstes Angebot dieser Variante, unterboten wie im Vorschlag).
-- A.var = { key, other = Zahl der Angebote anderer Varianten, best = guenstigstes Angebot dieser Variante }
---------------------------------------------------------------------------
function A.CheckVariant(r, it, e)
    local v = A.var
    if not (v and v.key == it.key and (v.other or 0) > 0) or not Num(it.price) then return end
    local best = v.best
    if not Num(best) and type(e) == "table" and not e.gone and Num(e.m) then best = e.m end
    if not Num(best) or it.price >= best then return end
    local fill = ns.Data.Undercut(best, it.key, mod.db)
    if not Num(fill) or fill <= it.price then return end
    r.kind, r.title = "wait", L.ADV_VARIANT
    r.why = v.best and L.ADV_VARIANT_WHY:format(Money(best)) or L.ADV_VARIANT_WHY_MKT:format(Money(best))
    r.extra = nil
    r.fillPrice = fill
end

---------------------------------------------------------------------------
-- Lockangebote (ab 0.104, Wunsch KarloDerBaer 19.11.2026): Data.SkipBait auf die Live-Angebote dieses Fensters.
-- Steht im Preisfeld der Preis eines Lockangebots (oder darunter), heisst der Rat "Lockangebot" und nennt die erste
-- echte Stufe. Die Knoepfe "Guenstige" und "Vorschlag" gehen dann ebenfalls von ihr aus (A.Prices).
---------------------------------------------------------------------------
A.liveRows = nil   -- { key, rows }: letzte Live-Angebote im Verkaufen

-- ab 0.120 (KarloDerBaer 19.11.2026): nur bei Massenware. Bei Einzelgegenstaenden ist ein einzelnes guenstiges
-- Stueck ein normales Angebot (z. B. ein Ring, 1 zu 6g 74s unter 2 zu 7g 50s), kein Lockangebot.
function A.Bait(key)
    local lr = A.liveRows
    if key == nil or not (lr and lr.key == key) then return nil end
    if not ns.Data.IsCommodity(key) then return nil end
    return ns.Data.SkipBait(lr.rows, mod.db)
end

function A.CheckBait(r, it)
    local b = A.Bait(it.key)
    if not b then return end
    r.bait = b
    if not Num(it.price) or it.price > b.top or r.title == L.ADV_VARIANT then return end
    local fill = ns.Data.Undercut(b.price, it.key, mod.db)
    if not Num(fill) or fill <= it.price then return end
    r.kind, r.title = "wait", L.ADV_BAIT
    r.why = L.ADV_BAIT_WHY:format(b.qty, Money(b.top), Money(b.price))
    r.extra = nil
end

---------------------------------------------------------------------------
-- Kein Angebot dieses Gegenstands im Markt (ab 0.103, Wunsch KarloDerBaer 17.11.2026). Bisher sagte der Rat
-- "Lieber zum Haendler", wenn Blizzard den billigen Preis einer anderen Variante eintrug und von dieser Variante
-- gerade nichts im Haus stand. Jetzt gilt als Vergleichspreis:
--   1. der Preis, zu dem zuletzt vermutlich verkauft wurde (Sales.LastSold), wenn hoechstens A.SOLD_DAYS alt
--   2. sonst der obere Rand des ueblichen Bereichs (ohne Konkurrenz darf man oben ansetzen)
-- Liegt der Preis im Feld darunter und lohnt der Vergleichspreis mehr als der Haendler, heisst der Rat
-- "Hoeher ansetzen", der Knopf "Vorschlag" traegt den Vergleichspreis ein. Dazu ein Hinweis zum Markt:
--   lange nicht gesehen (selten) oder angeboten, aber kein Verkauf erkannt.
---------------------------------------------------------------------------
A.SOLD_DAYS = 7      -- so alt darf der zuletzt verkaufte Preis sein
A.SEEN_DAYS = 7      -- laenger nicht im Markt gesehen -> "selten"

local function Ago(secs)
    if secs < 3600 then return L.ADV_AGO_NOW end
    if secs < 48 * 3600 then return L.ADV_AGO_H:format(math.floor(secs / 3600)) end
    return L.ADV_AGO_D:format(math.floor(secs / 86400))
end
A.Ago = Ago

-- Gerade kein Angebot genau dieses Gegenstands (bei Varianten: dieser Variante)?
function A.NoOffers(it, e)
    local v = A.var
    if v and v.key == it.key then
        if Num(v.best) then return false end
        if not v.partial then return true end
    end
    return type(e) ~= "table" or e.gone ~= nil
end

-- Vergleichspreis: { price, src = "sold" oder "range", t, band } oder nil
function A.Reference(e, key, now)
    now = now or time()
    local sp, st
    if ns.Sales then sp, st = ns.Sales.LastSold(e) end
    if Num(sp) and Num(st) and now - st <= A.SOLD_DAYS * 86400 then
        return { price = sp, src = "sold", t = st }
    end
    local band = type(e) == "table" and ns.Data.Band(e, nil, nil, nil, key) or nil
    if band and Num(band.high) and band.high > 0 then return { price = band.high, src = "range", band = band } end
    return nil
end

-- Hinweis zum Markt: selten im Markt oder kein Verkauf erkannt, sonst nil
function A.MarketHint(e, key, now)
    now = now or time()
    local seen = ns.Data.Seen(e)
    if not seen then return L.ADV_HINT_NEVER end
    if now - seen > A.SEEN_DAYS * 86400 then return L.ADV_HINT_RARE:format(Ago(now - seen)) end
    local sp, st
    if ns.Sales then sp, st = ns.Sales.LastSold(e) end
    if Num(st) and now - st <= A.SEEN_DAYS * 86400 then return nil end
    local so = ns.Sales and ns.Sales.RecentDays(e, A.SEEN_DAYS) or 0
    if so > 0 then return nil end
    local c = ns.Sales and ns.Sales.ClientStats(e, key)
    if c and Num(c.perHour) and c.perHour > 0 then return nil end
    return L.ADV_HINT_NOSALE:format(A.SEEN_DAYS)
end

function A.CheckNoOffers(r, it, e, hp, now)
    if not A.NoOffers(it, e) then return end
    local hint = A.MarketHint(e, it.key, now)
    local ref = A.Reference(e, it.key, now)
    r.ref = ref
    if ref and not r.band then r.band = ref.band end
    if ref and Num(it.price) and it.price < ref.price
        and not (Num(hp) and hp > 0 and ref.price * (1 - ns.Data.Cut()) < hp) then
        r.kind, r.title = "wait", L.ADV_HIGHER
        if ref.src == "sold" then
            r.why = L.ADV_HIGHER_SOLD:format(Money(ref.price), Ago((now or time()) - ref.t))
        else
            r.why = L.ADV_HIGHER_RANGE:format(Money(ref.price))
        end
        r.fillPrice = ref.price
        r.extra = hint
        return
    end
    if hint then r.extra = r.extra and (r.extra .. " " .. hint) or hint end
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
        if ns.Data.IsVariantKey(it.key) and type(rows) == "table" then
            -- ab 0.98: auch die Zeilen fuer die eigene Liste (SellVariant.lua)
            A.var = { key = it.key, other = rows.other or 0, best = rows[1] and rows[1].price or nil,
                      rows = rows, partial = rows.partial, itemKey = arg }
            if ns.SellVariant then ns.SellVariant.Refresh() end
        end
    end
    if type(rows) ~= "table" or #rows == 0 or rows.foreign then return end
    A.liveRows = { key = it.key, rows = rows }   -- ab 0.104: fuer die Erkennung von Lockangeboten
    ns.Data.ApplyLive(it.key, rows, time())
    local sf, isCommodity = A.ActiveSellFrame()
    if sf then A.Update(sf, isCommodity) end
end

---------------------------------------------------------------------------
-- Dichtere Zeilen im Verkaufsfenster (ab 0.58, Wunsch von KarloDerBaer): Platz fuer den Rat unter "Auktion erstellen",
-- auch mit Blizzards Haken "Sofortkaufmodus" und der Zeile Gebotspreis. Broker aendert keine Werte in Blizzards
-- Fenster: Nach Blizzards Anordnung (sicherer Anhang an Layout) ruecken Dauer, Einzahlen, Gesamtpreis und der Knopf
-- je A.GAP_CUT Punkte naeher zusammen (nur ihre Anker, wie Blizzards Layout sie selbst setzt).
---------------------------------------------------------------------------
A.GAP_CUT = 18
A.COMPACT = { "Duration", "Deposit", "TotalPrice", "PostButton" }

function A.Compact(sf)
    if not ns.AHTouch() or type(sf) ~= "table" then return 0 end
    local shift = 0
    for _, k in ipairs(A.COMPACT) do
        local c = rawget(sf, k)
        if type(c) == "table" and c.GetPoint and (not c.IsShown or c:IsShown()) then
            local ok, p, rel, rp, x, y = pcall(c.GetPoint, c, 1)
            if ok and type(p) == "string" and p:find("TOP") and type(y) == "number" then
                shift = shift + A.GAP_CUT
                c:ClearAllPoints()
                c:SetPoint(p, rel, rp, x, y + shift)
            end
        end
    end
    return shift
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
            if type(sf.Layout) == "function" then   -- ab 0.58: dichtere Zeilen
                hooksecurefunc(sf, "Layout", function() mod:Call("Rat beim Verkaufen", A.Compact, sf) end)
                mod:Call("Rat beim Verkaufen", A.Compact, sf)
            end
            if sf.HookScript then sf:HookScript("OnHide", function() A.current, A.var, A.autoFilled = nil, nil, nil end) end
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
    -- ab 0.98: nachgeladene Teile (Blizzards Liste beim Blaettern oder SellVariant.MaybeMore)
    pcall(mod.RegisterEvent, mod, "ITEM_SEARCH_RESULTS_ADDED", function(_, key) mod:Call("Rat beim Verkaufen", A.OnResults, false, key) end)
end
