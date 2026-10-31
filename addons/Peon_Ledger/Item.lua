-- Peon_Ledger - Item.lua
-- Reiter "Gegenstand" (ab 0.9, Konzept Peon_Ledger_Gegenstand.md, mit KarloDerBaer abgestimmt 06.10.2026):
-- alles zu einem Gegenstand. Links eine Textspalte (Marge-Kasten, Charakter, Auktionshaus), rechts zwei Diagramme
-- (Kern-Baustein Peon.NewChart, API 10): oben die Werte des gewaehlten Charakters, unten das Auktionshaus;
-- dazwischen zuschaltbar der Marge-Streifen. Beide Gold-Achsen mit gleichem Massstab, gemeinsame Mauslinie.
-- Marktdaten von Peon_Broker (mod:History, mod:MarketInfo, mod:ItemValue), ohne Broker nur das obere Diagramm.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local I = {}
ns.Item = I

I.PERIODS = { 7, 30, 90, 0 }      -- 0 = alles
I.MAX_DAYS = 400
I.CUT = 0.95                      -- Anteil des Auktionshauses 5 %
I.LEFT_W = 184

local GREY = "|cff999999"
local DIM = "|cff777777"
local C = {
    cost = { 0.85, 0.40, 0.19, 1 }, costB = { 0.85, 0.40, 0.19, 0.45 }, be = { 0.90, 0.48, 0.25, 0.75 },
    md = { 0.22, 0.54, 0.87, 1 }, mn = { 0.52, 0.72, 0.92, 1 }, band = { 0.71, 0.83, 0.96, 0.22 },
    good = { 0.59, 0.77, 0.35, 0.30 }, bad = { 0.94, 0.45, 0.45, 0.30 }, goodL = { 0.59, 0.77, 0.35, 1 },
    st = { 0.70, 0.70, 0.66, 0.9 }, loot = { 0.39, 0.60, 0.13, 0.8 }, qty = { 0.50, 0.47, 0.87, 0.9 },
    sales = { 0.83, 0.33, 0.49, 0.9 }, ven = { 0.53, 0.53, 0.50, 1 },
    sell = { 0.11, 0.70, 0.50, 1 }, buy = { 0.80, 0.55, 0.15, 1 },
    sellM = { 0.11, 0.70, 0.50, 0.35 }, buyM = { 0.80, 0.55, 0.15, 0.35 },
    plus = { 0.39, 0.60, 0.13, 1 }, minus = { 0.89, 0.29, 0.29, 1 },
}
I.COLORS = C

local function Num(v) return type(v) == "number" and v == v and not Peon.IsSecret(v) end

local function Broker()
    if not Peon.GetModule then return nil end
    local ok, b = pcall(Peon.GetModule, Peon, "broker")
    if ok and type(b) == "table" and type(b.History) == "function" then return b end
    return nil
end
I.Broker = Broker

-- Achsen: kurze Geldbetraege ohne Symbole ("74c", "1,5s", "12g"), Stueck ("1200 St.")
function I.AxisMoney(v)
    if not Num(v) then return "" end
    local a, sign = math.abs(v), v < 0 and "-" or ""
    if a < 100 then return sign .. math.floor(a + 0.5) .. "c" end
    if a < 10000 then
        local x = a / 100
        if x >= 10 or math.abs(x - math.floor(x + 0.5)) < 0.05 then return sign .. math.floor(x + 0.5) .. "s" end
        return sign .. (("%.1f"):format(x):gsub("%.", ",")) .. "s"
    end
    local x = a / 10000
    if x >= 10 or math.abs(x - math.floor(x + 0.5)) < 0.05 then return sign .. math.floor(x + 0.5) .. "g" end
    return sign .. (("%.1f"):format(x):gsub("%.", ",")) .. "g"
end
function I.AxisPieces(v)
    if not Num(v) then return "" end
    return L.ITEM_PIECES:format(math.floor(v + 0.5))
end
local function M(v) return Num(v) and ns.Money(math.floor(v + 0.5)) or "–" end
local function Signed(v)
    if not Num(v) then return "–" end
    return (v >= 0 and "+" or "-") .. ns.Money(math.floor(math.abs(v) + 0.5))
end

---------------------------------------------------------------------------
-- Gegenstand finden: Nummer, Link oder (Teil des) Namens
---------------------------------------------------------------------------
function I.Find(text)
    if type(text) ~= "string" or Peon.IsSecret(text) then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    local id = tonumber(text:match("item:(%d+)") or text:match("^#?(%d+)$") or "")
    if id then return id end
    id = ns.Inventory.FindItemID(text)
    if id then return id end
    local low, best, bestLen = W.Lower(text), nil, nil
    for k, it in pairs(mod.acc.items or {}) do
        if type(it) == "table" and type(it.n) == "string" then
            local n = W.Lower(it.n)
            if n == low then return k end
            if n:find(low, 1, true) and (not bestLen or #n < bestLen) then best, bestLen = k, #n end
        end
    end
    if best then return best end
    if C_Item and C_Item.GetItemInfo then
        local ok, _, link = pcall(C_Item.GetItemInfo, text)
        if ok and type(link) == "string" then return tonumber(link:match("item:(%d+)")) end
    end
    return nil
end

---------------------------------------------------------------------------
-- Daten: eine Zeile je Tag von "from" bis heute
---------------------------------------------------------------------------
-- Luecken zwischen bekannten Werten linear fuellen (nicht vor dem ersten, nicht nach dem letzten Wert)
local function Interp(arr, n)
    local last
    for i = 1, n do
        if arr[i] ~= nil then
            if last and i - last > 1 then
                for k = last + 1, i - 1 do arr[k] = arr[last] + (arr[i] - arr[last]) * (k - last) / (i - last) end
            end
            last = i
        end
    end
end
I.Interp = Interp

function I.Data(id, char, period, today)
    today = today or ns.Cost.DayOf(time())
    local led = ns.Cost.ItemDays(id, char)
    local b = Broker()
    local hist = {}
    if b then local ok, h = pcall(b.History, b, id); if ok and type(h) == "table" then hist = h end end
    local from
    if period and period > 0 then
        from = today - period + 1
    else
        from = led.first
        for _, r in ipairs(hist) do
            local d = r.week and r.week * 7 or r.day
            if not from or d < from then from = d end
        end
        from = from or (today - 29)
        if today - from + 1 < 7 then from = today - 6 end
    end
    if today - from + 1 > I.MAX_DAYS then from = today - I.MAX_DAYS + 1 end
    local n = today - from + 1
    local d = { n = n, from = from, today = today, id = id, char = char,
        cost = {}, be = {}, st = {}, loot = {}, sell = {}, buy = {}, sellN = {}, buyN = {}, sellM = {}, buyM = {},
        min = {}, median = {}, low = {}, high = {}, qty = {}, sales = {}, marge = {}, hasMarket = #hist > 0 }
    -- Ledger: Stand vom letzten Tag davor uebernehmen
    local keys = {}
    for day in pairs(led.days) do keys[#keys + 1] = day end
    table.sort(keys)
    local cn, ca
    local ki = 1
    while keys[ki] and keys[ki] < from do
        local r = led.days[keys[ki]]
        if r.n ~= nil then cn, ca = r.n, r.avg end
        ki = ki + 1
    end
    for i = 1, n do
        local day = from + i - 1
        local r = led.days[day]
        if r then
            if r.n ~= nil then cn, ca = r.n, r.avg end
            if Num(r.loot) and r.loot > 0 then d.loot[i] = r.loot end
            if Num(r.buyN) and r.buyN > 0 then d.buy[i], d.buyN[i], d.buyM[i] = r.buyV / r.buyN, r.buyN, true end
            if Num(r.sellN) and r.sellN > 0 then d.sell[i], d.sellN[i], d.sellM[i] = r.sellV / r.sellN, r.sellN, true end
        end
        if cn ~= nil and (led.first and day >= led.first) then
            d.st[i] = cn
            if cn > 0 and Num(ca) then d.cost[i] = ca; d.be[i] = ca / I.CUT end
        end
    end
    -- Broker: Tageswerte, Wochenwerte fuer alle Tage der Woche (wenn kein Tageswert)
    local function Put(i, r, weekly)
        if i < 1 or i > n then return end
        if weekly and d.median[i] ~= nil then return end
        d.min[i], d.median[i], d.qty[i] = r.min, r.median, r.qty
        if not weekly then d.low[i], d.high[i] = r.low, r.high end
        if Num(r.sales) and (not weekly or d.sales[i] == nil) then d.sales[i] = r.sales end
    end
    for _, r in ipairs(hist) do if not r.week and r.median then Put(r.day - from + 1, r, false) end end
    for _, r in ipairs(hist) do
        if r.week then for k = 0, 6 do Put(r.week * 7 + k - from + 1, r, true) end
        elseif not r.median and Num(r.sales) then local i = r.day - from + 1; if i >= 1 and i <= n then d.sales[i] = r.sales end end
    end
    for _, k in ipairs({ "min", "median", "qty", "low", "high" }) do Interp(d[k], n) end
    for i = 1, n do
        if Num(d.min[i]) and Num(d.cost[i]) then d.marge[i] = d.min[i] * I.CUT - d.cost[i] end
    end
    return d
end

-- Wie viele Tage bis heute hat die Marge dasselbe Vorzeichen (fuer "seit n Tagen")
function I.Streak(marge, n, positive)
    local k = 0
    for i = n, 1, -1 do
        local v = marge[i]
        if v == nil then break end
        if (v > 0) ~= positive then break end
        k = k + 1
    end
    return k
end

---------------------------------------------------------------------------
-- Aufbau
---------------------------------------------------------------------------
local function Text(parent, font, w, justify)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
    if w then fs:SetWidth(w) end
    fs:SetJustifyH(justify or "LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end

-- Zeile der Textspalte: links Beschriftung, rechts Wert
local function Row(parent, y, dim)
    local l = Text(parent, dim and "GameFontDisableSmall" or "GameFontHighlightSmall", 100)
    l:SetPoint("TOPLEFT", 10, y)
    local r = Text(parent, "GameFontHighlightSmall", 110, "RIGHT")
    r:SetPoint("TOPRIGHT", -8, y)
    return { l = l, r = r, Set = function(self, a, b) self.l:SetText(a or ""); self.r:SetText(b or "") end }
end

function I.BuildLeft(c)
    local box = W.Inset(c)
    box:SetPoint("TOPLEFT", 0, 0)
    box:SetPoint("BOTTOMLEFT", 0, 0)
    box:SetWidth(I.LEFT_W)
    I.left = box
    local search = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
    search:SetSize(I.LEFT_W - 24, 20)
    search:SetPoint("TOPLEFT", 14, -8)
    search:SetAutoFocus(false)
    search:SetScript("OnEnterPressed", function(self)
        local id = I.Find(self:GetText())
        self:ClearFocus()
        if id then self:SetText(""); I.Show(id) else mod:Print(L.ITEM_NOT_FOUND:format(self:GetText())) end
    end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    I.search = search
    local hint = Text(box, "GameFontDisableSmall", I.LEFT_W - 24)
    hint:SetPoint("TOPLEFT", 16, -30)
    hint:SetText(L.ITEM_SEARCH)
    local icon = box:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", 10, -46)
    I.icon = icon
    I.name = Text(box, "GameFontNormal", I.LEFT_W - 50)
    I.name:SetPoint("TOPLEFT", 44, -47)
    I.sub = Text(box, "GameFontDisableSmall", I.LEFT_W - 50)
    I.sub:SetPoint("TOPLEFT", 44, -63)
    -- Marge-Kasten
    local mb = CreateFrame("Frame", nil, box)
    mb:SetPoint("TOPLEFT", 8, -82)
    mb:SetSize(I.LEFT_W - 16, 52)
    local bg = mb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    mb.bg = bg
    mb.title = Text(mb, "GameFontHighlightSmall", I.LEFT_W - 28)
    mb.title:SetPoint("TOPLEFT", 6, -4)
    mb.big = Text(mb, "GameFontNormalLarge", I.LEFT_W - 28)
    mb.big:SetPoint("TOPLEFT", 6, -17)
    mb.small = Text(mb, "GameFontHighlightSmall", I.LEFT_W - 28)
    mb.small:SetPoint("TOPLEFT", 6, -37)
    I.margeBox = mb
    local y = -140
    I.rows = {}
    local function Add(key, dim, gap) y = y - (gap or 0); I.rows[key] = Row(box, y, dim); y = y - 14 end
    Add("be"); Add("now")
    I.hdrChar = Text(box, "GameFontNormalSmall", I.LEFT_W - 20)
    y = y - 8; I.hdrChar:SetPoint("TOPLEFT", 10, y); y = y - 15
    Add("stock"); Add("avg"); Add("lager", true); Add("rate", true); Add("split", true)
    I.hdrAH = Text(box, "GameFontNormalSmall", I.LEFT_W - 20)
    y = y - 8; I.hdrAH:SetPoint("TOPLEFT", 10, y); y = y - 15
    I.hdrAH:SetText(L.ITEM_HDR_AH)
    Add("band"); Add("sales"); Add("median", true); Add("vendor", true)
    I.note = Text(box, "GameFontDisableSmall", I.LEFT_W - 20)
    I.note:SetPoint("BOTTOMLEFT", 10, 8)
    if I.note.SetWordWrap then I.note:SetWordWrap(true) end
end

local function SmallButton(parent, w, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 18)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

function I.CharItems()
    local list = { { "*", L.ITEM_ALL_CHARS } }
    local me = ns.CharName()
    local names = {}
    for name in pairs(ns.Inventory.RealmData().chars) do if name ~= me then names[#names + 1] = name end end
    table.sort(names)
    table.insert(list, 2, { me, me })
    for _, n in ipairs(names) do list[#list + 1] = { n, n } end
    return list
end

function I.BuildRight(c)
    local x0 = I.LEFT_W + 8
    local width = (W.WIDTH - 24) - x0
    I.rightW = width
    local right = CreateFrame("Frame", nil, c)
    right:SetPoint("TOPLEFT", x0, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    I.right = right
    -- oben: Charakter (fuer Kosten, Bestand, Beute), Marge-Streifen an/aus, Zeitraum
    I.charDD = W.Dropdown(right, 150, I.CharItems, function() return I.char end, function(v) I.char = v; I.Refresh() end)
    I.margeBtn = SmallButton(right, 110, L.ITEM_MARGE_BTN, function()
        mod.db.itemMarge = not mod.db.itemMarge
        I.Layout(); I.Refresh()
    end)
    I.periodBtns = {}
    local prev
    for k = #I.PERIODS, 1, -1 do
        local p = I.PERIODS[k]
        local b = SmallButton(right, 52, p == 0 and L.ITEM_ALL or L.ITEM_DAYS:format(p), function()
            mod.db.itemPeriod = p; I.Refresh()
        end)
        if prev then b:SetPoint("RIGHT", prev, "LEFT", -2, 0) else b:SetPoint("TOPRIGHT", 0, 0) end
        b.period = p
        I.periodBtns[#I.periodBtns + 1] = b
        prev = b
    end
    -- ab 0.10 nach Einheit getrennt: oben Preis je Stueck (Gold), unten Stueck – je Diagramm eine Groesse
    local hover = { onHover = function(_, i) I.Hover(i) end, onLeave = function() I.Hover(nil) end }
    I.chartA = Peon.NewChart(right, { width = width, height = 150, left = 46, right = 46, top = 6, bottom = 4, grid = 2,
        leftFormat = I.AxisMoney, rightFormat = I.AxisMoney, onHover = hover.onHover, onLeave = hover.onLeave })
    I.chartM = Peon.NewChart(right, { width = width, height = 40, left = 46, right = 46, top = 3, bottom = 3, grid = 2,
        leftFormat = function(v) if math.abs(v) < 0.5 then return "0" end return I.AxisMoney(v) end,
        onHover = hover.onHover, onLeave = hover.onLeave })
    I.chartB = Peon.NewChart(right, { width = width, height = 140, left = 46, right = 46, top = 6, bottom = 14, grid = 2,
        leftFormat = I.AxisPieces, rightFormat = I.AxisPieces, onHover = hover.onHover, onLeave = hover.onLeave })
    local all = { I.chartA, I.chartM, I.chartB }
    Peon.LinkCharts(all)      -- gemeinsame Mauslinie (kein gemeinsamer Massstab: andere Einheiten)
    for _, ch in ipairs(all) do ch.linked = all end
    I.priceLabel = Text(right, "GameFontNormalSmall", 110)
    I.priceLabel:SetText(L.ITEM_HDR_PRICE)
    I.margeLabel = Text(right, "GameFontNormalSmall", 200)
    I.margeLabel:SetText(L.ITEM_MARGE_TITLE)
    I.margeHint = Text(right, "GameFontDisableSmall", 260, "RIGHT")
    I.margeHint:SetText(L.ITEM_MARGE_HINT)
    I.ahLabel = Text(right, "GameFontNormalSmall", 110)
    I.ahLabel:SetText(L.ITEM_HDR_PIECES)
    -- Achsen im Stueck-Diagramm: links du, rechts das Auktionshaus
    I.axisMe = Text(I.chartB.frame, "GameFontDisableSmall", 120)
    I.axisMe:SetPoint("TOPLEFT", 48, -2)
    I.axisAH = Text(I.chartB.frame, "GameFontDisableSmall", 160, "RIGHT")
    I.axisAH:SetPoint("TOPRIGHT", -48, -2)
    I.dayFrom = Text(I.chartB.frame, "GameFontDisableSmall", 120)
    I.dayTo = Text(I.chartB.frame, "GameFontDisableSmall", 120, "RIGHT")
    I.dayFrom:SetPoint("BOTTOMLEFT", 46, 0)
    I.dayTo:SetPoint("BOTTOMRIGHT", -46, 0)
    I.info1 = Text(right, "GameFontHighlightSmall", width)
    I.info2 = Text(right, "GameFontDisableSmall", width)
    I.empty = Text(right, "GameFontDisable", width, "CENTER")
end

-- Hoehen je nach Marge-Streifen
function I.Layout()
    local c = I.right
    if not c then return end
    local h = (I.content and I.content.GetHeight and I.content:GetHeight()) or 0
    if not Num(h) or h < 300 then h = W.HEIGHT - W.TOP - 26 end
    local fixed = 24 + 18 + 18 + 30
    local strip = mod.db.itemMarge and 44 or 0
    local rest = h - fixed - strip
    local ha = math.floor(rest * 0.55)
    local hb = rest - ha
    I.chartA:SetSize(nil, ha)
    I.chartB:SetSize(nil, hb)
    I.charDD:ClearAllPoints(); I.charDD:SetPoint("TOPLEFT", 0, 1)
    I.margeBtn:ClearAllPoints(); I.margeBtn:SetPoint("LEFT", I.charDD, "RIGHT", 6, 0)
    local y = -24
    I.priceLabel:ClearAllPoints(); I.priceLabel:SetPoint("TOPLEFT", 4, y - 3)
    if I.legendA then I.legendA.frame:ClearAllPoints(); I.legendA.frame:SetPoint("TOPLEFT", 96, y - 2) end
    y = y - 18
    I.chartA.frame:ClearAllPoints(); I.chartA.frame:SetPoint("TOPLEFT", 0, y)
    y = y - ha
    if strip > 0 then
        I.margeLabel:ClearAllPoints(); I.margeLabel:SetPoint("TOPLEFT", 4, y - 3); I.margeLabel:Show()
        I.margeHint:ClearAllPoints(); I.margeHint:SetPoint("TOPRIGHT", -46, y - 3); I.margeHint:Show()
        I.chartM.frame:ClearAllPoints(); I.chartM.frame:SetPoint("TOPLEFT", 0, y - 14); I.chartM.frame:Show()
        I.chartM:SetSize(nil, strip - 14)
        y = y - strip
    else
        I.margeLabel:Hide(); I.margeHint:Hide(); I.chartM.frame:Hide()
    end
    I.ahLabel:ClearAllPoints(); I.ahLabel:SetPoint("TOPLEFT", 4, y - 3)
    if I.legendB then I.legendB.frame:ClearAllPoints(); I.legendB.frame:SetPoint("TOPLEFT", 96, y - 2) end
    y = y - 18
    I.chartB.frame:ClearAllPoints(); I.chartB.frame:SetPoint("TOPLEFT", 0, y)
    y = y - hb
    I.info1:ClearAllPoints(); I.info1:SetPoint("TOPLEFT", 4, y - 3)
    I.info2:ClearAllPoints(); I.info2:SetPoint("TOPLEFT", 4, y - 16)
    I.empty:ClearAllPoints(); I.empty:SetPoint("CENTER", I.chartA.frame, "CENTER", 0, 0)
    I.margeBtn:SetAlpha(mod.db.itemMarge and 1 or 0.55)
end

function I.Build(c)
    I.content = c
    I.char = I.char or ns.CharName()
    I.BuildLeft(c)
    I.BuildRight(c)
    I.Layout()
end

---------------------------------------------------------------------------
-- Reihen fuer die Diagramme
---------------------------------------------------------------------------
-- Preis je Stueck (Gold): Markt, deine Kosten, Gewinnzone, Kaeufe/Verkaeufe
function I.SeriesA(d, vendor)
    return {
        { key = "band", kind = "band", values = d.high, values2 = d.low, color = C.band, legendColor = { 0.71, 0.83, 0.96, 0.8 }, label = L.ITEM_S_BAND },
        { key = "zone", kind = "zone", values = d.min, values2 = d.be, color = C.good, colorBelow = C.bad, legendColor = C.goodL, label = L.ITEM_S_ZONE },
        { key = "zone", kind = "line", values = d.be, color = C.be, width = 1, dash = 2 },
        { key = "ven", kind = "hline", value = vendor, color = C.ven, dash = 3, hidden = true, label = L.ITEM_S_VENDOR },
        { key = "cost", kind = "step", values = d.cost, color = C.cost, width = 2, label = L.ITEM_S_COST },
        { key = "md", kind = "line", values = d.median, color = C.md, width = 2, connect = true, label = L.ITEM_S_MEDIAN },
        { key = "mn", kind = "line", values = d.min, color = C.mn, width = 1.5, dash = 4, connect = true, label = L.ITEM_S_MIN },
        { key = "evS", kind = "marks", values = d.sellM, color = C.sellM },
        { key = "evB", kind = "marks", values = d.buyM, color = C.buyM },
        { key = "pS", kind = "points", values = d.sell, color = C.sell, shape = "circle", size = 7 },
        { key = "pB", kind = "points", values = d.buy, color = C.buy, shape = "square", size = 6 },
    }
end

-- Stueck: links deine (Bestand, Beute), rechts das Auktionshaus (Menge, Absatz/Tag)
function I.SeriesB(d)
    return {
        { key = "loot", kind = "bar", values = d.loot, color = C.loot, size = 0.6, hidden = true, label = L.ITEM_S_LOOT },
        { key = "st", kind = "step", values = d.st, color = C.st, width = 1.5, label = L.ITEM_S_STOCK },
        { key = "qty", kind = "line", axis = "right", values = d.qty, color = C.qty, width = 1.2, connect = true, label = L.ITEM_S_QTY },
        { key = "sales", kind = "line", axis = "right", values = d.sales, color = C.sales, width = 1.2, connect = true, hidden = true, label = L.ITEM_S_SALES },
        { key = "evS", kind = "marks", values = d.sellM, color = C.sellM },
        { key = "evB", kind = "marks", values = d.buyM, color = C.buyM },
    }
end

local function ApplyShown(ch)
    local off = type(mod.db.itemOff) == "table" and mod.db.itemOff or {}
    for _, s in ipairs(ch.series) do
        if s.label and off[s.key] ~= nil then ch.shown[s.key] = not off[s.key] end
    end
end

local function OnToggle(key, on)
    if type(mod.db.itemOff) ~= "table" then mod.db.itemOff = {} end
    mod.db.itemOff[key] = not on
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
function I.Show(id)
    if not Num(id) then return end
    I.id = id
    mod.db.itemLast = id
    if W.current ~= "item" then W.Select("item") else I.Refresh() end
end

function I.Refresh()
    if not I.right then return end
    I.char = I.char or ns.CharName()
    if I.charDD and I.charDD.Update then I.charDD.Update() end
    local period = tonumber(mod.db.itemPeriod) or 30
    for _, b in ipairs(I.periodBtns) do
        if b.period == period then b:LockHighlight() else b:UnlockHighlight() end
        b:SetAlpha(b.period == period and 1 or 0.6)
    end
    local id = I.id or (Num(mod.db.itemLast) and mod.db.itemLast > 0 and mod.db.itemLast) or nil
    I.id = id
    if not id then
        I.empty:SetText(L.ITEM_PICK); I.empty:Show()
        I.chartA:SetData(0, {}); I.chartB:SetData(0, {}); I.chartM:SetData(0, {})
        I.FillLeft(nil); I.info1:SetText(""); I.info2:SetText("")
        return
    end
    I.empty:Hide()
    local ok, d = pcall(I.Data, id, I.char, period)
    if not ok then mod:ReportError("Gegenstand", d); return end
    I.data = d
    local b = Broker()
    local info
    if b and b.MarketInfo then local ok2, r = pcall(b.MarketInfo, b, id); if ok2 then info = r end end
    I.info = info
    local vendor = (info and info.vendor) or (ns.Moves.SellPrice and ns.Moves.SellPrice(id))
    I.chartA:SetData(d.n, I.SeriesA(d, vendor))
    I.chartB:SetData(d.n, I.SeriesB(d))
    ApplyShown(I.chartA); ApplyShown(I.chartB)
    -- Marge-Streifen: symmetrische Achse
    local mx = 1
    for i = 1, d.n do if Num(d.marge[i]) then mx = math.max(mx, math.abs(d.marge[i])) end end
    local a, top = Peon.NiceRange(0, mx, 1)
    I.chartM:SetRange("left", -top, top)
    I.chartM:SetData(d.n, { { key = "m", kind = "bar", values = d.marge, color = C.plus, colorBelow = C.minus, size = 0.7 } })
    if not I.legendA then
        I.legendA = I.chartA:CreateLegend(I.right, { "mn", "md", "band", "cost", "zone", "ven" }, OnToggle)
        I.legendB = I.chartB:CreateLegend(I.right, { "st", "loot", "qty", "sales" }, OnToggle)
        I.Layout()
    end
    I.chartA:Draw(); I.chartB:Draw()
    local who = (I.char == "*") and L.ITEM_ALL_SHORT or (I.char:match("^(%S+)") or I.char)
    I.axisMe:SetText(L.ITEM_AXIS_ME:format(who))
    I.axisAH:SetText(d.hasMarket and L.ITEM_AXIS_AH or "")
    I.dayFrom:SetText(I.DayLabel(d.from))
    I.dayTo:SetText(L.ITEM_TODAY)
    I.FillLeft(d)
    I.Hover(nil)
end

function I.DayLabel(day) return date("%d.%m.", day * 86400 + 43200) end

-- Textspalte
function I.FillLeft(d)
    local id = I.id
    for _, r in pairs(I.rows) do r:Set("", "") end
    local mb = I.margeBox
    if not id then
        I.name:SetText(""); I.sub:SetText(""); I.icon:SetTexture(nil); mb:Hide(); I.hdrChar:SetText(""); I.note:SetText("")
        return
    end
    local name, quality, icon = ns.Inventory.ItemInfo(id)
    I.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local info = I.info
    I.name:SetText(W.Colored(name or (info and info.name) or ("#" .. id), quality or (info and info.quality)))
    if info then
        I.sub:SetText((info.commodity and L.ITEM_COMMODITY or L.ITEM_SINGLE) .. " · " .. L.ITEM_IN_AH:format(math.floor((info.qty or 0) + 0.5)))
    else
        I.sub:SetText(I.Broker() and L.ITEM_NO_MARKET or L.ITEM_NO_BROKER)
    end
    local char = I.char
    local cost = ns.Cost.Info(id, char)
    local value = ns.Value(id, 1)        -- Erloes je Stueck nach 5 % (Zeile 1 des Broker-Tooltips)
    -- Marge-Kasten
    mb:Show()
    if cost and Num(value) then
        local marge = value - cost.next
        local good = marge > 0
        mb.bg:SetColorTexture(good and 0.25 or 0.45, good and 0.45 or 0.12, good and 0.12 or 0.12, 0.45)
        mb.title:SetText(good and L.ITEM_MARGE_GOOD or L.ITEM_MARGE_BAD)
        if cost.next < 0.5 then
            mb.big:SetText(L.ITEM_FREE)
            mb.small:SetText(L.ITEM_EARN:format(M(value)))
        else
            mb.big:SetText(L.ITEM_PER_PIECE:format(Signed(marge)))
            local pct = math.floor(marge / cost.next * 100 + (marge >= 0 and 0.5 or -0.5))
            local streak = d and I.Streak(d.marge, d.n, good) or 0
            mb.small:SetText(L.ITEM_PCT:format((pct >= 0 and "+" or "") .. pct) .. (streak > 0 and (" · " .. L.ITEM_SINCE:format(streak)) or ""))
        end
        I.rows.be:Set(L.ITEM_BREAKEVEN, M(cost.next / I.CUT))
    elseif cost then
        mb.bg:SetColorTexture(0.3, 0.3, 0.3, 0.35)
        mb.title:SetText(L.ITEM_MARGE_NONE); mb.big:SetText("–"); mb.small:SetText(I.Broker() and L.ITEM_NO_MARKET or L.ITEM_NO_BROKER)
        I.rows.be:Set(L.ITEM_BREAKEVEN, M(cost.next / I.CUT))
    else
        mb.bg:SetColorTexture(0.3, 0.3, 0.3, 0.35)
        mb.title:SetText(L.ITEM_MARGE_NONE); mb.big:SetText("–"); mb.small:SetText(L.ITEM_NO_COST)
    end
    if info then I.rows.now:Set(L.ITEM_AH_NOW, M(info.min)) end
    -- Charakter
    I.hdrChar:SetText(char == "*" and L.ITEM_ALL_CHARS or char)
    local cnt = ns.Inventory.Count(id)
    local n = cnt.total
    if char ~= "*" then
        n = 0
        for _, ch in ipairs(cnt.chars) do if ch.name == char then n = ch.total end end
    end
    I.rows.stock:Set(L.ITEM_STOCK, tostring(n))
    I.rows.avg:Set(L.ITEM_AVG, cost and M(cost.avg) or "–")
    I.rows.lager:Set(L.ITEM_LAGER, cost and M(cost.value) or "–")
    local rate, sold, back = mod:SellRate(id)
    if rate then I.rows.rate:Set(L.ITEM_RATE, ("%d %%"):format(math.floor(rate * 100 + 0.5)))
    elseif (sold or 0) + (back or 0) > 0 then I.rows.rate:Set(L.ITEM_RATE, ("%d / %d"):format(sold, sold + back)) end
    if char == "*" and #cnt.chars > 1 then
        local parts = {}
        for k, ch in ipairs(cnt.chars) do if k <= 3 then parts[#parts + 1] = (ch.name:match("^(%S+)") or ch.name) .. " " .. ch.total end end
        I.rows.split:Set(L.ITEM_SPLIT, table.concat(parts, ", "))
    end
    -- Auktionshaus
    if info then
        if info.low and info.high then I.rows.band:Set(L.ITEM_BAND, M(info.low) .. " – " .. M(info.high)) end
        if Num(info.perHour) then
            local col = (info.level == 3 and "|cff40ff40") or (info.level == 2 and "|cffffd200") or "|cffff4040"
            I.rows.sales:Set(L.ITEM_SALES, col .. "≈|r " .. L.ITEM_PER_HOUR:format(info.perHour >= 10 and ("%d"):format(info.perHour + 0.5) or (("%.1f"):format(info.perHour):gsub("%.", ","))))
        end
        I.rows.median:Set(L.ITEM_MEDIAN, M(info.median))
    end
    local vendor = (info and info.vendor) or (ns.Moves.SellPrice and ns.Moves.SellPrice(id))
    if Num(vendor) and vendor > 0 then I.rows.vendor:Set(L.ITEM_VENDOR, M(vendor)) end
    I.note:SetText(d and d.from and ns.Cost and L.ITEM_NOTE or "")
end

-- Werte des Tages unter der Maus (ab 0.10 als Kasten neben der Mauslinie, nach Einheit gegliedert).
-- Liefert die Zeilen { links, rechts, r, g, b } (fuer Tests auch ohne Anzeige).
function I.HoverLines(i)
    local d = I.data
    if not d or not i or not d.st then return nil end
    local lines = {}
    local function H(text) lines[#lines + 1] = { text, nil, 1, 0.82, 0 } end
    local function V(label, value, r, g, b) if value then lines[#lines + 1] = { label, value, r or 1, g or 1, b or 1 } end end
    local day = d.from + i - 1
    lines[1] = { (day == d.today) and L.ITEM_TODAY or I.DayLabel(day), nil, 1, 1, 1 }
    H(L.ITEM_HDR_PRICE)
    if Num(d.min[i]) then V(L.ITEM_S_MIN, M(d.min[i]), 0.52, 0.72, 0.92) end
    if Num(d.median[i]) then V(L.ITEM_S_MEDIAN, M(d.median[i]), 0.22, 0.54, 0.87) end
    if Num(d.low and d.low[i]) and Num(d.high and d.high[i]) then V(L.ITEM_S_BAND, M(d.low[i]) .. " – " .. M(d.high[i]), 0.71, 0.83, 0.96) end
    if Num(d.cost[i]) then V(L.ITEM_S_COST, M(d.cost[i]), 0.85, 0.40, 0.19) end
    if Num(d.be[i]) then V(L.ITEM_BREAKEVEN, M(d.be[i]), 0.90, 0.48, 0.25) end
    if Num(d.marge[i]) then
        local good = d.marge[i] >= 0
        V(L.ITEM_MARGE_TITLE, Signed(d.marge[i]), good and 0.25 or 1, good and 1 or 0.25, 0.25)
    end
    H(L.ITEM_HDR_PIECES)
    local who = (I.char == "*") and L.ITEM_ALL_SHORT or (I.char:match("^(%S+)") or I.char)
    V(L.ITEM_S_STOCK .. " (" .. who .. ")", tostring(d.st[i] or 0), 0.70, 0.70, 0.66)
    if Num(d.loot[i]) then V(L.ITEM_S_LOOT, tostring(d.loot[i]), 0.39, 0.60, 0.13) end
    if Num(d.qty[i]) then V(L.ITEM_S_QTY, tostring(math.floor(d.qty[i] + 0.5)), 0.50, 0.47, 0.87) end
    if Num(d.sales[i]) then V(L.ITEM_S_SALES, tostring(math.floor(d.sales[i] + 0.5)), 0.83, 0.33, 0.49) end
    if d.sellN[i] or d.buyN[i] then
        H(L.ITEM_HDR_EVENTS)
        if d.sellN[i] then lines[#lines + 1] = { L.ITEM_H_SOLD:format(d.sellN[i], M(d.sell[i])), nil, 0.11, 0.70, 0.50 } end
        if d.buyN[i] then lines[#lines + 1] = { L.ITEM_H_BOUGHT:format(d.buyN[i], M(d.buy[i])), nil, 0.80, 0.55, 0.15 } end
    end
    return lines
end

function I.Hover(i)
    I.info1:SetText(L.ITEM_LEGEND_EV)
    I.info2:SetText(L.ITEM_HOVER_HINT)
    local tt = rawget(_G, "GameTooltip")
    local lines = I.HoverLines(i)
    I.hoverLines = lines
    if not lines then
        if tt and I.tipOwned then I.tipOwned = nil; tt:Hide() end
        return
    end
    if not tt or not tt.SetOwner then return end
    tt:SetOwner(I.right, "ANCHOR_NONE")
    tt:ClearAllPoints()
    local x = I.chartA.X and I.chartA:X(i) or 0
    if Num(x) then x = x + ((I.chartA.o and I.chartA.o.left) or 46) end
    if Num(x) and x > (I.rightW or 400) / 2 then
        tt:SetPoint("TOPRIGHT", I.chartA.frame, "TOPLEFT", x - 14, -4)
    else
        tt:SetPoint("TOPLEFT", I.chartA.frame, "TOPLEFT", (Num(x) and x or 0) + 14, -4)
    end
    for k, l in ipairs(lines) do
        if k == 1 then tt:SetText(l[1], l[3], l[4], l[5])
        elseif l[2] then tt:AddDoubleLine(l[1], l[2], l[3], l[4], l[5], 1, 1, 1)
        else tt:AddLine(l[1], l[3], l[4], l[5]) end
    end
    tt:Show()
    I.tipOwned = true
end

W.pages.item = { build = I.Build, refresh = I.Refresh }

-- Schnittstelle: Gegenstand im Reiter zeigen (Broker-Knopf "Mehr…", Klick in den Listen, /ledger <Name>)
function mod:ShowItem(id)
    if not Num(id) then return end
    W.Open("item")
    I.Show(id)
end
