-- Peon_Ledger - Book.lua
-- Buch: Auswertung der Bewegungen (Moves.lua) je Zeitraum und Charakter.
-- Ab 0.14 (Neuaufbau E4, Konzept Peon_Ledger_Neuaufbau.md Abschnitt 6.3) ein Reiter mit Peon.UI:
--   oben Zeitraum und Charakter, links die Summen (zuerst Handelsgewinn und Gesamtgewinn), rechts zwei Ansichten:
--   "Nach Art" (Einnahmen und Ausgaben je Art) und "Nach Gegenstand" (ersetzt den Reiter Umsatz).
-- Gewinn = Einnahmen - Ausgaben - Gebuehren (nur Gold, Umbuchungen zaehlen nicht). Handelsgewinn (Zuordnen, Cost.lua)
-- = Erloes - Wareneinsatz - Gebuehren der verkauften Stuecke. Beute, Quests und Verbrauch nur unter "Nach Art".
-- Verkaufsquote = verkauft / (verkauft + zurueck) in Stueck, letzte 30 Tage, ab 3 Stueck.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local B = {}
ns.Book = B

local GREY = W.GREY

B.PERIODS = { { key = "today", label = "BK_TODAY" }, { key = "d7", label = "BK_D7" }, { key = "d30", label = "BK_D30" }, { key = "all", label = "BK_ALL" } }
B.RATE_DAYS = 30
B.RATE_MIN = 3
B.ORDER = { "ahsold", "ahbuy", "ahfee", "vendor", "buyback", "repair", "loot", "quest", "craft", "trade", "mail", "taxi", "trainer", "other" }

function B.From(period, now)
    now = now or time()
    if period == "today" then
        local d = date("*t", now)
        return time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
    elseif period == "d7" then return now - 7 * 86400
    elseif period == "d30" then return now - 30 * 86400 end
    return nil
end

local function Side(e) return ns.Moves.Side(e) end

-- Auswertung: { kinds = { [Art] = { inc, exp } }, inc, exp, fee, cut, items = { [id] = {...} }, sales, cogs, tfee, trade, use }
function B.Collect(period, onlyMe, now, char)
    local from = B.From(period, now)
    local me = char or ns.CharName()
    if char then onlyMe = true end
    local res = { kinds = {}, inc = 0, exp = 0, fee = 0, cut = 0, items = {},
                  sales = 0, cogs = 0, tfee = 0, trade = 0, use = 0, nsales = 0 }
    local function Item(id)
        local it = res.items[id]
        if not it then it = { id = id, nin = 0, nout = 0, sold = 0, back = 0, inc = 0, exp = 0, gross = 0, grossQ = 0,
            profit = nil, cogs = 0, use = 0, buyN = 0, buyV = 0, sellN = 0, sellV = 0 }; res.items[id] = it end
        return it
    end
    local function Money(k, m)
        if not m or m == 0 then return end
        local kk = res.kinds[k]
        if not kk then kk = { inc = 0, exp = 0 }; res.kinds[k] = kk end
        if k == "ahfee" then
            res.fee = res.fee - m
            kk.exp = kk.exp - m
        elseif m > 0 then
            res.inc = res.inc + m; kk.inc = kk.inc + m
        else
            res.exp = res.exp - m; kk.exp = kk.exp - m
        end
    end
    local function Zuordnen(e)
        local r = ns.Cost and ns.Cost.Result(e)
        if not r then return end
        if r.sale then
            local m = math.max(0, e.m or 0)
            res.sales, res.cogs, res.tfee = res.sales + m, res.cogs + (r.cost or 0), res.tfee + (r.fee or 0)
            res.trade = res.trade + (r.profit or 0)
            res.nsales = res.nsales + 1
            if e.id then
                local it = Item(e.id)
                it.profit = (it.profit or 0) + (r.profit or 0)
                it.cogs = it.cogs + (r.cost or 0)
            end
        elseif r.general then
            res.tfee = res.tfee + r.general
            res.trade = res.trade - r.general
        elseif r.use and not r.traded then
            res.use = res.use + r.use
            if e.id then Item(e.id).use = Item(e.id).use + r.use end
        end
    end
    local function Use(e)
        Zuordnen(e)
        local side = Side(e)
        if e.k == "ahreturn" and e.id and (e.n or 0) > 0 then Item(e.id).back = Item(e.id).back + e.n end
        if side == "move" then return end
        Money(e.k, e.m)
        if e.k == "ahsold" and e.cut then res.cut = res.cut + e.cut end
        if e.id then
            local it = Item(e.id)
            if e.n and e.n > 0 then it.nin = it.nin + e.n elseif e.n and e.n < 0 then it.nout = it.nout - e.n end
            if e.m and e.m > 0 then it.inc = it.inc + e.m elseif e.m and e.m < 0 then it.exp = it.exp - e.m end
            if e.k == "ahsold" and e.m and e.m > 0 then
                local q = e.q or (e.n and -e.n) or 1
                it.sold = it.sold + q
                local g = e.gross or (e.m + (e.cut or 0))
                if e.q or e.gross then it.gross = it.gross + g; it.grossQ = it.grossQ + q end
                it.sellN, it.sellV = it.sellN + q, it.sellV + e.m
            elseif e.k == "vendor" and (e.n or 0) < 0 and (e.m or 0) > 0 then
                it.sellN, it.sellV = it.sellN + (-e.n), it.sellV + e.m
            end
            -- Einkauf (ab 0.14): Auktionshaus, Haendler, Rueckkauf
            if (e.k == "ahbuy" or e.k == "vendor" or e.k == "buyback") and (e.m or 0) < 0 then
                local q = (e.n and e.n > 0) and e.n or e.q
                if q and q > 0 then it.buyN, it.buyV = it.buyN + q, it.buyV - e.m end
            end
        end
    end
    for _, e in ipairs(ns.Moves.List()) do
        if (not from or (e.t or 0) >= from) and (not onlyMe or e.c == me) then Use(e) end
    end
    if not from then
        local weeks = ns.Inventory.RealmData().weeks
        if type(weeks) == "table" then
            for _, w in pairs(weeks) do
                for key, sum in pairs(w) do
                    local c, k, id = key:match("^(.-)|(.-)|(.-)$")
                    if c and (not onlyMe or c == me) then
                        id = tonumber(id)
                        Use({ c = c, k = k, id = (id and id > 0) and id or nil, n = sum.n, m = sum.m })
                    end
                end
            end
        end
    end
    res.profit = res.inc - res.exp - res.fee
    return res
end

function B.SellRate(id, days, now)
    now = now or time()
    local from = now - (days or B.RATE_DAYS) * 86400
    local sold, back = 0, 0
    for _, e in ipairs(ns.Moves.List()) do
        if e.id == id and (e.t or 0) >= from then
            if e.k == "ahsold" and e.m and e.m > 0 then sold = sold + (e.q or (e.n and -e.n) or 1)
            elseif e.k == "ahreturn" and (e.n or 0) > 0 then back = back + e.n end
        end
    end
    if sold + back < B.RATE_MIN then return nil, sold, back end
    return sold / (sold + back), sold, back
end

local function Rate(it)
    if it.sold + it.back < B.RATE_MIN then return nil end
    return it.sold / (it.sold + it.back)
end

function B.BookRows(res)
    local rows = {}
    for _, k in ipairs(B.ORDER) do
        local kk = res.kinds[k]
        if kk and (kk.inc ~= 0 or kk.exp ~= 0) then
            rows[#rows + 1] = { k = k, label = L["BK_" .. k:upper()] or k, inc = kk.inc, exp = kk.exp, sum = kk.inc - kk.exp, order = #rows }
        end
    end
    for k, kk in pairs(res.kinds) do
        local known = false
        for _, o in ipairs(B.ORDER) do if o == k then known = true end end
        if not known and (kk.inc ~= 0 or kk.exp ~= 0) then
            rows[#rows + 1] = { k = k, label = L.BK_OTHER, inc = kk.inc, exp = kk.exp, sum = kk.inc - kk.exp, order = #rows }
        end
    end
    return rows
end

-- Zeilen "Nach Gegenstand": nur Gegenstaende mit Kauf oder Verkauf
function B.ItemRows(res, search, char)
    local who = (char and char ~= "*") and char or "*"
    local filter = search and W.Lower(search) or ""
    local rows = {}
    for id, it in pairs(res.items) do
        if it.buyN > 0 or it.sellN > 0 or it.sold > 0 or it.back > 0 then
            local name, quality, icon = ns.Inventory.ItemInfo(id)
            name = name or ("#" .. id)
            if filter == "" or W.Lower(name):find(filter, 1, true) then
                local info = ns.Cost and ns.Cost.Info(id, who)
                rows[#rows + 1] = { id = id, name = name, quality = quality, icon = icon,
                    buyN = it.buyN > 0 and it.buyN or nil, sellN = it.sellN > 0 and it.sellN or nil,
                    buyAvg = it.buyN > 0 and it.buyV / it.buyN or nil,
                    sellAvg = it.sellN > 0 and it.sellV / it.sellN or nil,
                    avg = it.grossQ > 0 and math.floor(it.gross / it.grossQ + 0.5) or nil,
                    sold = it.sold, back = it.back, rate = Rate(it), inc = it.inc, exp = it.exp,
                    cost = info and info.avg or nil, profit = it.profit, cogs = it.cogs, use = it.use }
            end
        end
    end
    return rows
end

---------------------------------------------------------------------------
-- Reiter "Buch"
---------------------------------------------------------------------------
B.book = {}

-- Charakter der Auswahl (nil = alle). Frueher "Nur dieser Charakter" (bookOnlyMe)
function B.Char()
    local c = mod.db.bookChar or "*"
    if c ~= "*" and not ns.Inventory.RealmData().chars[c] then c = "*" end
    return c ~= "*" and c or nil
end

function B.Refresh()
    local page = B.book
    if not page.kinds then return end
    if page.charDD and page.charDD.GenerateMenu then pcall(page.charDD.GenerateMenu, page.charDD) end
    local char = B.Char()
    local res = B.Collect(mod.db.bookPeriod, char ~= nil, nil, char)
    page.res = res
    local s = page.lines
    s.trade:Set(L.BK_L_TRADE, W.Signed(res.trade))
    s.profit:Set(L.BK_L_PROFIT, W.Signed(res.profit))
    s.inc:Set(L.BK_L_INC, ns.Money(res.inc))
    s.exp:Set(L.BK_L_EXP, ns.Money(res.exp))
    s.fee:Set(L.BK_L_FEE, ns.Money(res.fee))
    s.sales:Set(L.BK_L_SALES, ns.Money(res.sales))
    s.cogs:Set(L.BK_L_COGS, ns.Money(math.floor(res.cogs + 0.5)))
    s.cut:Set(L.BK_L_CUT, ns.Money(res.cut))
    s.use:Set(GREY .. L.BK_L_USE .. "|r", GREY .. ns.Money(math.floor(res.use + 0.5)) .. "|r")
    page.kinds:SetData(B.BookRows(res))
    page.items:SetData(B.ItemRows(res, page.search, char))
    local view = mod.db.bookView == "items" and "items" or "kinds"
    page.kindsPanel:SetShown(view == "kinds")
    page.itemsPanel:SetShown(view == "items")
    if page.searchBox then page.searchBox:SetShown(view == "items") end
end

function B.Status()
    local res = B.book.res
    if not res then return nil end
    return ns.Plural(res.nsales, "BK_STATUS")
end

local function Pieces(v) if not v or v == 0 then return GREY .. "–|r" end return tostring(v) end

function B.ItemTooltip(row, r)
    W.ShowItemTooltip(row, r.id)
    if not GameTooltip then return end
    if r.rate then GameTooltip:AddLine(L.BK_RATE_TT:format(r.sold, r.sold + r.back), 0.8, 0.8, 0.8) end
    if r.avg then GameTooltip:AddLine(L.BK_AVG_TT:format(ns.Money(r.avg)), 0.8, 0.8, 0.8) end
    if r.profit then GameTooltip:AddLine(L.BK_PROFIT_TT:format(ns.Money(math.floor((r.cogs or 0) + 0.5)), W.Signed(r.profit)), 0.8, 0.8, 0.8) end
    if (r.use or 0) > 0 then GameTooltip:AddLine(L.BK_USE:format(ns.Money(math.floor(r.use + 0.5))), 0.6, 0.6, 0.6) end
    GameTooltip:Show()
end

function B.Build(c)
    local U = Peon.UI
    local a = W.Area()
    local page = B.book
    -- Zeitraum und Charakter oben rechts
    local periods = {}
    for _, p in ipairs(B.PERIODS) do periods[#periods + 1] = { p.key, L[p.label] } end
    page.periodDD = U.Dropdown(c, 120, periods, function() return mod.db.bookPeriod end,
        function(v) mod.db.bookPeriod = v; mod:Call("Buch", W.Refresh) end)
    page.charDD = U.Dropdown(c, 170, W.CharItems, function() return mod.db.bookChar or "*" end,
        function(v) mod.db.bookChar = v; mod:Call("Buch", W.Refresh) end)
    page.charDD:SetPoint("TOPRIGHT", -16, -32)
    page.periodDD:SetPoint("RIGHT", page.charDD, "LEFT", -8, 0)
    -- links die Summen
    local lw = 260
    local left = U.Panel(c, "left")
    left:SetPoint("TOPLEFT", a.left, -a.top)
    left:SetPoint("BOTTOMLEFT", a.left, a.bottom)
    left:SetWidth(lw)
    page.left = left
    local head = left:CreateFontString(nil, "ARTWORK", U.FONT.heading)
    head:SetPoint("TOPLEFT", 14, -12)
    head:SetText(L.BK_HEAD)
    page.lines = {}
    local keys = { "trade", "profit", "-", "inc", "exp", "fee", "-", "sales", "cogs", "cut", "-", "use" }
    local y = -38
    for _, k in ipairs(keys) do
        if k == "-" then
            y = y - 10
        else
            page.lines[k] = W.ValueLine(left, y)
            y = y - 22
        end
    end
    U.Font(page.lines.trade.value, "big"); U.Font(page.lines.profit.value, "big")
    local hint = U.Text(left, "sub", L.BK_HINT, lw - 28)
    hint:SetPoint("BOTTOMLEFT", 14, 12)
    -- rechts zwei Ansichten
    local function RightPanel()
        local p = U.Panel(c, "list", true)
        p:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 0)
        p:SetPoint("BOTTOMRIGHT", -a.right, a.bottom)
        return p
    end
    page.kindsPanel = RightPanel()
    page.itemsPanel = RightPanel()
    page.view = U.TopTabs(c, { { "kinds", L.BK_VIEW_KINDS }, { "items", L.BK_VIEW_ITEMS } }, function(key)
        mod.db.bookView = key
        mod:Call("Buch", W.Refresh)
    end)
    if page.view[1] then page.view[1]:SetPoint("BOTTOMLEFT", page.kindsPanel, "TOPLEFT", 10, -2) end
    page.kinds = U.Table(page.kindsPanel, {
        columns = {
            { key = "label", title = L.COL_KIND, sort = function(r) return r.order end },
            { key = "inc", title = L.BK_INC, width = 120, align = "RIGHT", format = function(v) return v ~= 0 and (W.GREEN .. ns.Money(v) .. "|r") or (GREY .. "–|r") end },
            { key = "exp", title = L.BK_EXP, width = 120, align = "RIGHT", format = function(v) return v ~= 0 and (W.RED .. ns.Money(v) .. "|r") or (GREY .. "–|r") end },
            { key = "sum", title = L.BK_SUM, width = 120, align = "RIGHT", format = function(v) return W.Signed(v) end },
        },
        sortKey = "label", empty = L.BK_EMPTY,
    })
    page.items = U.Table(page.itemsPanel, {
        icon = true,
        columns = {
            { key = "name", title = L.COL_ITEM, format = function(v, r) return W.Colored(v, r.quality) end, sort = function(r) return W.Lower(r.name) end },
            { key = "buyN", title = L.BK_COL_BOUGHT, width = 64, align = "RIGHT", format = Pieces },
            { key = "sellN", title = L.BK_COL_SOLD, width = 64, align = "RIGHT", format = Pieces },
            { key = "buyAvg", title = L.BK_COL_BUYAVG, width = 90, align = "RIGHT", format = function(v) return W.MoneyOr(v) end },
            { key = "sellAvg", title = L.BK_COL_SELLAVG, width = 90, align = "RIGHT", format = function(v) return W.MoneyOr(v) end },
            { key = "profit", title = L.BK_COL_PROFIT, width = 96, align = "RIGHT", format = function(v) return v and W.Signed(v) or (GREY .. "–|r") end,
              sort = function(r) return r.profit or -math.huge end },
        },
        sortKey = "profit", sortDesc = true, empty = L.BK_EMPTY_ITEMS,
        onEnter = function(row, r) B.ItemTooltip(row, r) end,
        onClick = function(r, button) if button == "RightButton" then W.ItemMenu(r.id) elseif r.id then mod:ShowItem(r.id) end end,
    })
    page.searchBox = U.SearchBox(c, 170, function(text) page.search = text; mod:Call("Buch", W.Refresh) end)
    page.searchBox:SetPoint("TOPLEFT", 80, -32)
    page.view:Select(mod.db.bookView == "items" and "items" or "kinds")
end

W.pages.book = { build = B.Build, refresh = B.Refresh, status = B.Status }
