-- Peon_Broker - Item.lua
-- Neuaufbau N2 (ab 0.60, Konzept Peon_Broker_Neuaufbau.md, Abschnitt 4.6): Seite "Gegenstand", gebaut mit Peon.UI.
-- Die einzige Seite mit vielen Angaben. Sie zeigt immer den zuletzt gewaehlten Gegenstand:
--   links   Kopf mit Symbol und Namen, Werte (dieselben Bausteine wie im Tooltip), Mein Bestand aus Peon_Ledger,
--           Knoepfe Im Markt zeigen, Beobachten, Auf Einkaufsliste
--   rechts  Diagramm (7, 14, 30, 90 Tage: guenstigstes Angebot, Median, ueblicher Bereich, Menge),
--           darunter die guenstigsten Preisstufen des letzten Stands
-- Oben ein Suchfeld: Ab zwei Buchstaben zeigt die Seite statt der Einzelheiten die Treffer. Ein Klick waehlt.
-- Ersetzt Prices.lua (Reiter Preise bzw. Info). Nur Daten des aktuellen Markts, Preise je Stueck.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local P = {}
ns.Item = P

P.RESULT_MAX = 200                 -- hoechstens so viele Treffer in der Liste
P.SEARCH_MIN = 2                   -- ab so vielen Buchstaben wird gesucht
P.PERIODS = { 7, 14, 30, 90 }      -- Zeitraeume des Diagramms in Tagen
P.ROW_STEP = 19
P.key = nil                        -- gewaehlter Gegenstand (Schluessel wie in der Preisdatenbank)

local GREY, ORANGE = "|cff808080", "|cffff9933"

local function Money(v) return ns.Tooltip.Money(v) end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

---------------------------------------------------------------------------
-- Daten
---------------------------------------------------------------------------
-- Alle Gegenstaende des aktuellen Markts (zwischengespeichert bis zum naechsten Scan oder Live-Stand)
function P.All()
    local D = ns.Data
    local market, key = D.Market()
    local stamp = tostring(key) .. ":" .. tostring(market and market.lastScan) .. ":" .. tostring(D.liveStamp)
    if P.cache and P.cacheStamp == stamp then return P.cache end
    local all = {}
    if market then
        for k, e in pairs(market.items) do
            if type(e) == "table" and e.m then
                local name = D.ItemName(k, e) or L.ITEM_UNKNOWN:format(D.ItemID(k) or 0)
                all[#all + 1] = { key = k, e = e, name = name, lname = W.Lower(name) }
            end
        end
    end
    P.cache, P.cacheStamp = all, stamp
    return all
end

-- Suche: Teil des Namens (Gross/klein egal). Rueckgabe: Zeilen fuer die Liste (hoechstens RESULT_MAX), Zahl der Treffer
function P.Search(text)
    text = W.Lower(strtrim and strtrim(text or "") or (text or ""))
    local rows, found = {}, 0
    if #text < P.SEARCH_MIN then return rows, 0 end
    local D = ns.Data
    for _, it in ipairs(P.All()) do
        if it.lname:find(text, 1, true) then
            found = found + 1
            if #rows < P.RESULT_MAX then
                local e = it.e
                local sales = ns.Sales and ns.Sales.Stats(e, nil, it.key) or nil
                rows[#rows + 1] = { key = it.key, name = it.name, lname = it.lname, quality = e.ql,
                    icon = ns.Buy and ns.Buy.Icon(D.ItemID(it.key)) or nil,
                    min = e.m, median = e.md, qty = e.q or 0, sales = sales,
                    t = e.gone or D.Seen(e), gone = e.gone }
            end
        end
    end
    return rows, found
end

function P.Ledger()
    if not Peon.GetModule then return nil end
    local ok, m = pcall(Peon.GetModule, Peon, "ledger")
    if ok and type(m) == "table" then return m end
    return nil
end

-- Kosten je Stueck laut Peon_Ledger (naechstes Stueck) oder nil
function P.OwnCost(id)
    local led = P.Ledger()
    if not led or type(led.Cost) ~= "function" then return nil end
    local ok, c = pcall(led.Cost, led, id)
    if ok and Num(c) then return c end
    return nil
end

-- Abschnitt "Mein Bestand": nur mit Peon_Ledger. Zeilen { label, value }
function P.StockRows(key, ctx)
    local out = {}
    if not P.Ledger() then return out end
    local id = ns.Data.ItemID(key)
    if ns.Stock then
        local bags, bank, total, others = ns.Stock.Counts(id, nil)
        out[#out + 1] = { L.ITEM_STOCK, L.ITEM_STOCK_TEXT:format(total or 0, bags or 0, bank or 0, others or 0) }
    end
    local cost = P.OwnCost(id)
    if cost then out[#out + 1] = { L.ITEM_COST, Money(cost) } end
    local left, right = ns.Tooltip.BlockText("own", "rate", ctx or {})
    if left then out[#out + 1] = { left, right } end
    return out
end

-- Werte links: dieselben Bausteine wie im Tooltip, alle an. Rueckgabe: Liste aus { label, value }, { head = Text }
-- und { hint = Text }
P.BLOCKS = { { "market", "both" }, { "range", "range" }, { "sales", "day" }, { "vendor", "unit" }, { "merchant" },
             { "neutral", "pct" }, { "craft" } }

function P.ValueRows(key)
    local D, T = ns.Data, ns.Tooltip
    local ctx = T.Context(key, D.LinkFromKey(key), 1)
    local rows = {}
    if not ctx.e then
        rows[#rows + 1] = { hint = L.ITEM_NO_DATA, grey = true }
    end
    for _, b in ipairs(P.BLOCKS) do
        local left, right = T.BlockText(b[1], b[2], ctx)
        if b[1] == "range" and ctx.e then
            if not left then
                left, right = L.TT_USUAL, GREY .. L.ITEM_BAND_NONE .. "|r"
            elseif ctx.band and Num(ctx.band.schw) and ctx.band.schw > 0.4 then
                right = right .. " " .. ORANGE .. L.ITEM_BAND_SHAKY .. "|r"   -- unsicherer Bereich (Rechenmodell F50c)
            end
        end
        if left then rows[#rows + 1] = { left, right } end
    end
    if ctx.e then
        rows[#rows + 1] = { L.ITEM_KIND, D.IsCommodity(key) and L.ITEM_KIND_C or L.ITEM_KIND_I }
    end
    local hint = T.HintText(ctx)
    if hint then rows[#rows + 1] = { hint = hint } end
    local stock = P.StockRows(key, ctx)
    if #stock > 0 then
        rows[#rows + 1] = { head = L.PRICES_STOCK_HEAD }
        for _, r in ipairs(stock) do rows[#rows + 1] = r end
    end
    return rows, ctx
end

-- Preisstufen des letzten Stands, guenstigste zuerst, mit Summen bis zu jeder Stufe
function P.Tiers(e)
    local rows = {}
    if type(e) ~= "table" or e.gone then return rows end
    local cum, cost = 0, 0
    for _, l in ipairs(ns.Data.ParseLevels(e.lv)) do
        cum = cum + l.qty
        cost = cost + l.price * l.qty
        rows[#rows + 1] = { price = l.price, qty = l.qty, cum = cum, cost = cost }
    end
    return rows
end

-- Reihen fuer das Diagramm: Werte der letzten n Tage, aelteste zuerst, Luecken = nil.
-- Aeltere Tage stehen als Wochenwerte in der Datenbank, sie gelten fuer alle sieben Tage der Woche.
function P.Series(e, days, today)
    today = today or ns.Data.Day()
    local byDay = {}
    for _, r in ipairs(ns.Data.History(e)) do
        if r.week then
            for d = r.week * 7, r.week * 7 + 6 do byDay[d] = byDay[d] or r end
        elseif r.day then
            byDay[r.day] = r
        end
    end
    local mins, meds, qtys, got = {}, {}, {}, 0
    for i = 1, days do
        local r = byDay[today - days + i]
        if r and Num(r.min) then
            mins[i], meds[i], qtys[i] = r.min, r.median, r.qty
            got = got + 1
        end
    end
    return mins, meds, qtys, got
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
local function AxisMoney(v)
    if not Num(v) then return "" end
    if v >= 10000 then return ("%.1fg"):format(v / 10000) end
    if v >= 100 then return ("%.1fs"):format(v / 100) end
    return ("%.0fc"):format(v)
end

local function ItemInfo(key, e)
    local D = ns.Data
    local id = D.ItemID(key)
    local name = D.ItemName(key, e) or L.ITEM_UNKNOWN:format(id or 0)
    local quality = type(e) == "table" and e.ql or nil
    if quality == nil then
        local _, _, q = ns.GetItemInfo(id)
        if Num(q) then quality = q end
    end
    return { key = key, id = id, name = name, quality = quality, icon = ns.Buy and ns.Buy.Icon(id) or nil,
             link = D.LinkFromKey(key) }
end

-- Menue "Auf Einkaufsliste": alle Listen und "Neue Liste". Ohne Blizzards Menue: auf die gewaehlte Liste.
local function ListMenu(owner, item)
    local B, M = ns.Buy, ns.Menu
    if not (MenuUtil and MenuUtil.CreateContextMenu and B and M) then
        if B then B.AddItem(item.key, { name = item.name, quality = item.quality, icon = item.icon }) end
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for i, l in ipairs(B.Lists()) do
            local idx = i
            root:CreateButton(l.name or ("#" .. i), function() mod:Call("Gegenstand", M.AddToList, idx, item) end)
        end
        root:CreateButton(L.MENU_SHOP_NEW, function() mod:Call("Gegenstand", M.AddToList, nil, item) end)
    end)
end

function P.Build(c)
    local UI = Peon.UI
    P.frame = c

    -- Suchfeld und Zahl der Treffer
    P.search = UI.SearchBox(c, 260, function() mod:Call("Gegenstand", P.OnSearch) end)
    P.search:SetPoint("TOPLEFT", 8, -2)
    P.count = UI.Text(c, "small", "")
    P.count:SetPoint("LEFT", P.search, "RIGHT", 12, 0)

    -- Treffer der Suche (ganze Breite)
    local rp = UI.Panel(c, "list", true)
    rp:SetPoint("TOPLEFT", 0, -30)
    rp:SetPoint("BOTTOMRIGHT", 0, 0)
    P.resultPanel = rp
    P.results = UI.Table(rp, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(it) return it.lname end,
              color = function(it) return UI.QualityColor(it.quality or 1) end },
            { key = "min", title = L.ITEM_COL_MIN, width = 100, align = "RIGHT",
              format = function(v, it) return (it.gone and GREY or "") .. Money(v) .. (it.gone and "|r" or "") end },
            { key = "median", title = L.TT_MEDIAN, width = 100, align = "RIGHT", format = function(v) return v and Money(v) or "" end },
            { key = "qty", title = L.ITEM_COL_QTY, width = 80, align = "RIGHT" },
            { key = "sales", title = L.TT_SALES, width = 90, align = "RIGHT",
              format = function(v) return v and ns.Sales.PerHourText(v) or (GREY .. "–|r") end,
              sort = function(it) return it.sales and it.sales.perHour or -1 end },
            { key = "t", title = L.COL_AGE, width = 80, align = "RIGHT", format = function(v) return ns.Scan.Age(v) end },
        },
        sortKey = "name", icon = true, empty = L.ITEM_SEARCH_HINT,
        onClick = function(it, button)
            if button == "RightButton" then
                ns.Go.Menu(it, P.resultPanel)
            else
                mod:Call("Gegenstand", P.Show, it.key)
            end
        end,
        onEnter = function(row, it) if it then W.ShowItemTooltip(row, it.key) end end,
    })

    -- Einzelheiten
    local d = CreateFrame("Frame", nil, c)
    d:SetPoint("TOPLEFT", 0, -30)
    d:SetPoint("BOTTOMRIGHT", 0, 0)
    P.detail = d

    local left = UI.Panel(d, "left")
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(UI.LEFT_W)
    P.left = left
    P.header = UI.ItemHeader(left)
    P.header:SetPoint("TOPLEFT", 10, -10)
    P.header:SetScript("OnEnter", function(self) if P.key ~= nil then W.ShowItemTooltip(self, P.key) end end)
    P.header:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    P.rows = {}

    local bw = math.floor((UI.LEFT_W - 20 - 12) / 3)
    P.marketButton = UI.Button(left, L.GO_MARKET, bw, function()
        if P.item then mod:Call("Sprung", ns.Go.Market, P.item) end
    end)
    P.marketButton:SetPoint("BOTTOMLEFT", 10, 10)
    if P.marketButton.SetMotionScriptsWhileDisabled then P.marketButton:SetMotionScriptsWhileDisabled(true) end
    UI.SetTooltip(P.marketButton, function()
        if W.AtAH() then return { L.GO_MARKET, L.ITEM_MARKET_TIP } end
        return { L.GO_MARKET, L.TAB_AH_ONLY }
    end)
    P.watchButton = UI.Button(left, L.MENU_WATCH, bw, function()
        if not (P.item and ns.Watch) then return end
        ns.Watch.Toggle(P.item.key, { name = P.item.name, q = P.item.quality, icon = P.item.icon })
        P.UpdateButtons()
    end)
    P.watchButton:SetPoint("LEFT", P.marketButton, "RIGHT", 6, 0)
    P.listButton = UI.Button(left, L.MENU_SHOP, bw, function(self)
        if P.item then mod:Call("Gegenstand", ListMenu, self, P.item) end
    end)
    P.listButton:SetPoint("LEFT", P.watchButton, "RIGHT", 6, 0)

    -- rechts oben: Diagramm mit Zeitraum
    local cp = UI.Panel(d, "right")
    cp:SetPoint("TOPLEFT", left, "TOPRIGHT", UI.GAP, 0)
    cp:SetPoint("RIGHT", d, "RIGHT", 0, 0)
    cp:SetHeight(214)
    P.chartPanel = cp
    local cw = W.WIDTH - 2 * W.SIDE - UI.LEFT_W - UI.GAP
    P.legend = UI.Text(cp, "small", ("|cffffd133%s|r  |cffaaaaaa%s|r  |cff60e060%s|r  |cff6699cc%s|r"):format(
        L.ITEM_LEG_MIN, L.TT_MEDIAN, L.TT_USUAL, L.ITEM_COL_QTY))
    P.legend:SetPoint("TOPLEFT", 12, -10)
    P.periodButtons = {}
    local prev
    for i = #P.PERIODS, 1, -1 do
        local days = P.PERIODS[i]
        local b = UI.Button(cp, tostring(days), 34, function() mod:Call("Gegenstand", P.SetPeriod, days) end)
        if prev then b:SetPoint("RIGHT", prev, "LEFT", -2, 0) else b:SetPoint("TOPRIGHT", -8, -6) end
        P.periodButtons[days] = b
        prev = b
    end
    local dl = UI.Text(cp, "small", L.ITEM_DAYS)
    dl:SetPoint("RIGHT", prev, "LEFT", -6, 0)
    if Peon.NewChart then
        P.chart = Peon.NewChart(cp, { width = cw - 12, height = 170, left = 46, right = 40, top = 8, bottom = 8, grid = 2,
            leftFormat = AxisMoney, rightFormat = function(v) return Num(v) and Peon.ShortNumber and Peon.ShortNumber(v) or "" end })
        if P.chart and P.chart.frame then P.chart.frame:SetPoint("TOPLEFT", cp, "TOPLEFT", 6, -34) end
    end
    P.chartEmpty = UI.Text(cp, "hint", L.HISTORY_EMPTY, cw - 40)
    P.chartEmpty:SetPoint("CENTER", 0, -10)

    -- rechts unten: Preisstufen
    local tp = UI.Panel(d, "list", true)
    tp:SetPoint("TOPLEFT", cp, "BOTTOMLEFT", 0, -2)
    tp:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 0, 0)
    P.tierPanel = tp
    P.tiers = UI.Table(tp, {
        columns = {
            { key = "price", title = L.ITEM_TIER_PRICE, align = "RIGHT", format = function(v) return Money(v) end },
            { key = "qty", title = L.ITEM_COL_QTY, width = 80, align = "RIGHT" },
            { key = "cum", title = L.ITEM_TIER_CUM, width = 80, align = "RIGHT" },
            { key = "cost", title = L.ITEM_TIER_COST, width = 110, align = "RIGHT", format = function(v) return Money(v) end },
        },
        sortKey = "price", empty = L.ITEM_TIER_EMPTY,
    })

    if P.key == nil then P.key = mod.acc.itemKey end
    P.Refresh()
end

-- Zeilen links (Beschriftung gold und rechtsbuendig, Wert weiss), Ueberschrift, Hinweis
local function Row(i)
    local r = P.rows[i]
    if r then return r end
    local UI = Peon.UI
    r = {}
    r.label = UI.Text(P.left, "label", "")
    r.label:SetWidth(UI.LABEL_W)
    r.label:SetJustifyH("RIGHT")
    if r.label.SetWordWrap then r.label:SetWordWrap(false) end
    r.value = UI.Text(P.left, "text", "")
    r.value:SetWidth(UI.LEFT_W - UI.LABEL_W - 36)
    if r.value.SetWordWrap then r.value:SetWordWrap(false) end
    r.wide = UI.Text(P.left, "text", "", UI.LEFT_W - 28)
    P.rows[i] = r
    return r
end

function P.SetRows(rows)
    local UI = Peon.UI
    local y = -92
    for i, def in ipairs(rows) do
        local r = Row(i)
        r.label:ClearAllPoints(); r.value:ClearAllPoints(); r.wide:ClearAllPoints()
        if def.head or def.hint then
            if def.head then y = y - 8 end
            UI.Font(r.wide, def.head and "heading" or "text")
            r.wide:SetText(def.head or ((def.grey and GREY or ORANGE) .. def.hint .. "|r"))
            r.wide:SetPoint("TOPLEFT", P.left, "TOPLEFT", 14, y)
            r.wide:Show(); r.label:Hide(); r.value:Hide()
            local h = r.wide.GetStringHeight and r.wide:GetStringHeight() or 12
            y = y - math.max(P.ROW_STEP, (Num(h) and h or 12) + 6)
        else
            r.label:SetText(def[1] or "")
            r.value:SetText(def[2] or "")
            r.label:SetPoint("TOPLEFT", P.left, "TOPLEFT", 8, y)
            r.value:SetPoint("TOPLEFT", r.label, "TOPRIGHT", 12, 0)
            r.label:Show(); r.value:Show(); r.wide:Hide()
            y = y - P.ROW_STEP
        end
    end
    for i = #rows + 1, #P.rows do
        local r = P.rows[i]
        r.label:Hide(); r.value:Hide(); r.wide:Hide()
    end
    P.shownRows = rows
end

function P.Period()
    local d = tonumber(mod.acc.itemDays)
    for _, p in ipairs(P.PERIODS) do if p == d then return d end end
    return 14
end

function P.SetPeriod(days)
    mod.acc.itemDays = days
    P.Refresh()
end

function P.UpdateButtons()
    if not P.marketButton then return end
    local item = P.item
    if item and W.AtAH() then P.marketButton:Enable() else P.marketButton:Disable() end
    if item then P.watchButton:Enable(); P.listButton:Enable() else P.watchButton:Disable(); P.listButton:Disable() end
    local watching = item and ns.Watch and ns.Watch.Is(item.key)
    P.watchButton:SetText(watching and L.ITEM_UNWATCH or L.MENU_WATCH)
    local cur = P.Period()
    for days, b in pairs(P.periodButtons) do
        if days == cur then b:Disable() else b:Enable() end
    end
end

function P.DrawChart(e, ctx)
    if not P.chart then
        P.chartEmpty:Show()
        return
    end
    local days = P.Period()
    local mins, meds, qtys, got = P.Series(e, days)
    local show = got >= 2
    if P.chart.frame then P.chart.frame:SetShown(show) end
    P.chartEmpty:SetShown(not show)
    P.legend:SetShown(show)
    if not show then return end
    local series = {}
    local b = ctx and ctx.band
    if b and Num(b.low) and Num(b.high) then
        local hi, lo = {}, {}
        for i = 1, days do hi[i], lo[i] = b.high, b.low end
        series[#series + 1] = { key = "band", kind = "band", values = hi, values2 = lo, color = { 0.38, 0.88, 0.38, 0.18 } }
    end
    series[#series + 1] = { key = "qty", kind = "bar", axis = "right", values = qtys, color = { 0.4, 0.6, 0.8, 0.35 } }
    series[#series + 1] = { key = "median", kind = "line", values = meds, color = { 0.67, 0.67, 0.67, 0.9 }, width = 1, dash = 4, connect = true }
    series[#series + 1] = { key = "min", kind = "line", values = mins, color = { 1, 0.82, 0.2, 1 }, width = 2, connect = true }
    local cost = P.item and P.OwnCost(P.item.id)
    if cost then series[#series + 1] = { key = "cost", kind = "hline", value = cost, color = { 1, 0.4, 0.4, 0.9 } } end
    P.chart:SetData(days, series)
    P.chart:Draw()
end

-- Suche oder Einzelheiten?
function P.Mode()
    local text = P.search and P.search:GetText() or ""
    if P.key == nil or #(strtrim and strtrim(text) or text) > 0 then return "results" end
    return "detail"
end

function P.Refresh()
    if not P.results then return end
    local mode = P.Mode()
    P.resultPanel:SetShown(mode == "results")
    P.detail:SetShown(mode == "detail")
    if mode == "results" then
        local rows, found = P.Search(P.search:GetText())
        local market = ns.Data.Market()
        local hint = L.ITEM_SEARCH_HINT
        if not market or not (market.lastScan or market.mgrAt) then hint = L.PRICES_NO_SCAN
        elseif #W.Lower(P.search:GetText() or "") >= P.SEARCH_MIN then hint = L.PRICES_NOTHING end
        P.results.empty:SetText(hint)
        P.results:SetData(rows)
        if found > #rows then P.count:SetText(L.ITEM_COUNT_CAP:format(#rows, found))
        elseif found > 0 then P.count:SetText(L.ITEM_COUNT:format(found))
        else P.count:SetText("") end
        return
    end
    P.count:SetText("")
    local key = P.key
    local e = ns.Data.Lookup(key)
    if type(e) ~= "table" or not e.m then e = nil end
    P.item = ItemInfo(key, e)
    P.header:Set(P.item.icon, P.item.name, P.item.quality)
    local rows, ctx = P.ValueRows(key)
    P.SetRows(rows)
    P.tiers:SetData(P.Tiers(e))
    P.DrawChart(e, ctx)
    P.UpdateButtons()
end

function P.OnSearch()
    if P.filling then return end
    P.Refresh()
end

-- Gegenstand zeigen (Klick in der Trefferliste, Sprung, Menue)
function P.Show(key)
    if key == nil then return end
    P.key = key
    mod.acc.itemKey = key
    if P.search then
        P.filling = true
        P.search:SetText("")
        P.filling = false
    end
    P.Refresh()
end

W.pages.prices = {
    build = P.Build,
    refresh = function() P.Refresh() end,
}
