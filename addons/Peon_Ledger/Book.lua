-- Peon_Ledger - Book.lua
-- Buch (Bauabschnitt L5): Auswertung der Bewegungen (Moves.lua) je Zeitraum und Charakter.
--   Reiter "Buch":        Einnahmen, Ausgaben, Gebuehren und Gewinn, aufgeteilt nach Art.
--   Reiter "Gegenstände": je Gegenstand Zugang/Abgang (Stueck), im Auktionshaus verkauft/zurueck, Verkaufsquote,
--                         Einnahmen und Ausgaben.
-- Gewinn = Einnahmen - Ausgaben - Gebuehren (nur Gold; Umbuchungen zaehlen nicht). Verkaeufe im Auktionshaus
-- zaehlen mit dem erhaltenen Betrag (nach Abzug des Anteils, mit zurueckgezahlter Einstellgebuehr); der Anteil
-- steht zur Information dabei. Gebuehren = gezahlte Einstellgebuehren und Abbruchkosten.
-- Verkaufsquote (Rechenmodell 1.8) = verkauft / (verkauft + zurueck) in Stueck, letzte 30 Tage, ab 3 Stueck.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local B = {}
ns.Book = B

local GREY = "|cff999999"
local GREEN = "|cff40c040"
local RED = "|cffe05050"

B.PERIODS = { { key = "today", label = "BK_TODAY" }, { key = "d7", label = "BK_D7" }, { key = "d30", label = "BK_D30" }, { key = "all", label = "BK_ALL" } }
B.RATE_DAYS = 30
B.RATE_MIN = 3
-- Reihenfolge der Arten im Buch
B.ORDER = { "ahsold", "ahbuy", "ahfee", "vendor", "buyback", "repair", "loot", "quest", "craft", "trade", "mail", "taxi", "trainer", "other" }

-- Beginn eines Zeitraums (Sekunden seit 1970) oder nil fuer "Alles"
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

-- Auswertung: { kinds = { [Art] = { inc, exp } }, inc, exp, fee, cut, items = { [id] = {...} } }
function B.Collect(period, onlyMe, now, char)
    local from = B.From(period, now)
    local me = char or ns.CharName()
    if char then onlyMe = true end
    local res = { kinds = {}, inc = 0, exp = 0, fee = 0, cut = 0, items = {},
                  sales = 0, cogs = 0, tfee = 0, trade = 0, use = 0, nsales = 0 }   -- ab 0.7: Zuordnen
    local function Item(id)
        local it = res.items[id]
        if not it then it = { id = id, nin = 0, nout = 0, sold = 0, back = 0, inc = 0, exp = 0, gross = 0, grossQ = 0, profit = nil, cogs = 0, use = 0 }; res.items[id] = it end
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
                it.sold = it.sold + (e.q or 1)
                -- Ø Verkaufspreis je Stueck (ab 0.6): Sofortkaufpreis aus der Rechnung, sonst Erloes + Anteil
                local g = e.gross or (e.m + (e.cut or 0))
                if e.q or e.gross then it.gross = it.gross + g; it.grossQ = it.grossQ + (e.q or 1) end
            end
        end
    end
    for _, e in ipairs(ns.Moves.List()) do
        if (not from or (e.t or 0) >= from) and (not onlyMe or e.c == me) then Use(e) end
    end
    -- "Alles": auch die Wochensummen (Eintraege aelter als 90 Tage)
    if not from then
        local weeks = ns.Inventory.RealmData().weeks
        if type(weeks) == "table" then
            for _, w in pairs(weeks) do
                for key, sum in pairs(w) do
                    local c, k, id = key:match("^(.-)|(.-)|(.-)$")
                    if c and (not onlyMe or c == me) then
                        id = tonumber(id)
                        Use({ c = c, k = k, id = (id and id > 0) and id or nil, n = sum.n, m = sum.m })   -- ohne Zuordnen (kein Eintrag mehr)
                    end
                end
            end
        end
    end
    res.profit = res.inc - res.exp - res.fee
    return res
end

-- Verkaufsquote eines Gegenstands (alle Charaktere, letzte 30 Tage): Quote 0..1 oder nil, verkauft, zurueck
function B.SellRate(id, days, now)
    now = now or time()
    local from = now - (days or B.RATE_DAYS) * 86400
    local sold, back = 0, 0
    for _, e in ipairs(ns.Moves.List()) do
        if e.id == id and (e.t or 0) >= from then
            if e.k == "ahsold" and e.m and e.m > 0 then sold = sold + (e.q or 1)
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

local function MoneyCell(v, sign)
    if not v or v == 0 then return GREY .. "–|r" end
    return (sign > 0 and GREEN or RED) .. "|r" .. ns.Money(v)
end

local function Signed(v)
    if not v or v == 0 then return GREY .. "0|r" end
    return (v > 0 and GREEN .. "+" or RED .. "-") .. "|r" .. ns.Money(math.abs(v))
end

---------------------------------------------------------------------------
-- Gemeinsame Kopfzeile: Zeitraum-Knoepfe und "Nur dieser Charakter"
---------------------------------------------------------------------------
function B.Header(page, inset)
    page.periodButtons = {}
    local prev
    for _, p in ipairs(B.PERIODS) do
        local b = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
        b:SetSize(76, 22)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 12, -8) end
        b:SetText(L[p.label])
        b.key = p.key
        b:SetScript("OnClick", function()
            mod.db.bookPeriod = p.key
            mod:Call("Buch", W.Refresh)
        end)
        page.periodButtons[#page.periodButtons + 1] = b
        prev = b
    end
    local cb = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("LEFT", prev, "RIGHT", 10, 0)
    local label = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    label:SetText(L.HIST_ONLY_ME)
    cb.label = label
    cb:SetScript("OnClick", function(self)
        mod.db.bookOnlyMe = self:GetChecked() and true or false
        mod:Call("Buch", W.Refresh)
    end)
    page.onlyMe = cb
end

function B.UpdateHeader(page)
    for _, b in ipairs(page.periodButtons or {}) do
        if b.LockHighlight then
            if b.key == mod.db.bookPeriod then b:LockHighlight() else b:UnlockHighlight() end
        end
        if b.SetEnabled then b:SetEnabled(b.key ~= mod.db.bookPeriod) end
    end
    if page.onlyMe then page.onlyMe:SetChecked(mod.db.bookOnlyMe == true) end
end

---------------------------------------------------------------------------
-- Reiter "Buch"
---------------------------------------------------------------------------
B.book = {}

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

function B.RefreshBook()
    local page = B.book
    if not page.list then return end
    B.UpdateHeader(page)
    local res = B.Collect(mod.db.bookPeriod, mod.db.bookOnlyMe == true)
    page.list:SetData(B.BookRows(res))
    page.sums:SetText(L.BK_SUMS:format(GREEN .. ns.Money(res.inc) .. "|r", RED .. ns.Money(res.exp) .. "|r", RED .. ns.Money(res.fee) .. "|r"))
    page.profit:SetText(L.BK_PROFIT:format(Signed(res.profit)))
    page.cut:SetText(res.cut > 0 and (GREY .. L.BK_CUT:format(ns.Money(res.cut)) .. "|r") or "")
    -- Handelsgewinn (Zuordnen, ab 0.7): Erloes - Wareneinsatz - Gebuehren; Verbrauch nur zur Info
    page.trade:SetText(L.BK_TRADE:format(Signed(res.trade), ns.Money(res.sales), ns.Money(res.cogs), ns.Money(res.tfee))
        .. (res.use > 0 and ("   " .. GREY .. L.BK_USE:format(ns.Money(res.use)) .. "|r") or ""))
end

function B.BuildBook(c)
    local page = B.book
    local inset = W.Inset(c)
    inset:SetAllPoints()
    B.Header(page, inset)
    local total = W.WIDTH - 24 - 8 - 24
    page.list = Peon.NewList(inset, {
        columns = {
            { key = "label", title = L.COL_KIND, width = total - 3 * 120, sortValue = function(r) return r.order end },
            { key = "inc", title = L.BK_INC, width = 120, align = "RIGHT", format = function(v) return MoneyCell(v, 1) end },
            { key = "exp", title = L.BK_EXP, width = 120, align = "RIGHT", format = function(v) return MoneyCell(v, -1) end },
            { key = "sum", title = L.BK_SUM, width = 120, align = "RIGHT", format = function(v) return Signed(v) end },
        },
        rows = 11, rowHeight = 19, sortKey = "label",
        emptyText = L.BK_EMPTY,
    })
    page.list.frame:SetPoint("TOPLEFT", 4, -36)
    page.sums = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    page.sums:SetPoint("BOTTOMLEFT", 12, 34)
    page.trade = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    page.trade:SetPoint("BOTTOMLEFT", 12, 54)
    page.profit = inset:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    page.profit:SetPoint("BOTTOMLEFT", 12, 12)
    page.cut = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    page.cut:SetPoint("BOTTOMRIGHT", -12, 12)
end

---------------------------------------------------------------------------
-- Reiter "Gegenstände"
---------------------------------------------------------------------------
B.items = {}

function B.ItemRows(res, search, onlyMe)
    local who = onlyMe and ns.CharName() or "*"   -- ab 0.9: Kosten je Charakter
    local filter = search and W.Lower(search) or ""
    local rows = {}
    for id, it in pairs(res.items) do
        local name, quality, icon = ns.Inventory.ItemInfo(id)
        name = name or ("#" .. id)
        if filter == "" or W.Lower(name):find(filter, 1, true) then
            rows[#rows + 1] = { id = id, name = name, quality = quality, icon = icon, nin = it.nin, nout = it.nout,
                sold = it.sold, back = it.back, rate = Rate(it), inc = it.inc, exp = it.exp,
                avg = it.grossQ > 0 and math.floor(it.gross / it.grossQ + 0.5) or nil,
                cost = (ns.Cost and ns.Cost.Info(id, who)) and ns.Cost.Info(id, who).avg or nil,   -- Kosten je Stueck (Ø Bestand, ab 0.7)
                profit = it.profit, cogs = it.cogs, use = it.use }
        end
    end
    return rows
end

function B.RefreshItems()
    local page = B.items
    if not page.list then return end
    B.UpdateHeader(page)
    local res = B.Collect(mod.db.bookPeriod, mod.db.bookOnlyMe == true)
    local rows = B.ItemRows(res, page.search, mod.db.bookOnlyMe == true)
    page.list:SetData(rows)
    page.count:SetText(GREY .. L.STOCK_COUNT:format(#rows) .. "|r")
end

local function Pieces(v) if not v or v == 0 then return GREY .. "–|r" end return tostring(v) end

function B.BuildItems(c)
    local page = B.items
    local inset = W.Inset(c)
    inset:SetAllPoints()
    B.Header(page, inset)
    local total = W.WIDTH - 24 - 8 - 24
    page.list = Peon.NewList(inset, {
        columns = {
            { key = "name", title = L.COL_ITEM, width = total - (46 * 4 + 50 + 70 + 70 + 80 + 80 * 2),
              format = function(v, r) return "|T" .. tostring(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":16:16:0:0|t " .. W.Colored(v, r.quality) end,
              sortValue = function(r) return W.Lower(r.name) end },
            { key = "nin", title = L.BK_COL_IN, width = 46, align = "RIGHT", format = Pieces },
            { key = "nout", title = L.BK_COL_OUT, width = 46, align = "RIGHT", format = Pieces },
            { key = "sold", title = L.BK_COL_SOLD, width = 46, align = "RIGHT", format = Pieces },
            { key = "back", title = L.BK_COL_BACK, width = 46, align = "RIGHT", format = Pieces },
            { key = "rate", title = L.BK_COL_RATE, width = 50, align = "RIGHT",
              format = function(v) return v and (math.floor(v * 100 + 0.5) .. " %") or (GREY .. "–|r") end,
              sortValue = function(r) return r.rate or -1 end },
            { key = "avg", title = L.BK_COL_AVG, width = 70, align = "RIGHT",
              format = function(v) return v and ns.Money(v) or (GREY .. "–|r") end, sortValue = function(r) return r.avg or -1 end },
            { key = "cost", title = L.BK_COL_COST, width = 70, align = "RIGHT",
              format = function(v) return v and ns.Money(math.floor(v + 0.5)) or (GREY .. "–|r") end, sortValue = function(r) return r.cost or -1 end },
            { key = "profit", title = L.BK_COL_PROFIT, width = 80, align = "RIGHT",
              format = function(v) return v and Signed(math.floor(v + 0.5)) or (GREY .. "–|r") end, sortValue = function(r) return r.profit or -math.huge end },
            { key = "inc", title = L.BK_INC, width = 80, align = "RIGHT", format = function(v) return MoneyCell(v, 1) end },
            { key = "exp", title = L.BK_EXP, width = 80, align = "RIGHT", format = function(v) return MoneyCell(v, -1) end },
        },
        rows = 14, rowHeight = 19, sortKey = "inc", sortDesc = true,
        onClick = function(list, r, button) if button == "LeftButton" and r.id then mod:ShowItem(r.id) end end,   -- ab 0.9
        onEnter = function(list, r, row)
            W.ShowItemTooltip(row, r.id)
            if GameTooltip and r.rate then
                GameTooltip:AddLine(L.BK_RATE_TT:format(r.sold, r.sold + r.back), 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
            if GameTooltip and r.avg then
                GameTooltip:AddLine(L.BK_AVG_TT:format(ns.Money(r.avg)), 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
            if GameTooltip and r.profit then
                GameTooltip:AddLine(L.BK_PROFIT_TT:format(ns.Money(math.floor((r.cogs or 0) + 0.5)), Signed(math.floor(r.profit + 0.5))), 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
            if GameTooltip and (r.use or 0) > 0 then
                GameTooltip:AddLine(L.BK_USE:format(ns.Money(math.floor(r.use + 0.5))), 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end
        end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
        emptyText = L.BK_EMPTY,
    })
    page.list.frame:SetPoint("TOPLEFT", 4, -36)
    local box = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
    box:SetSize(130, 20)
    box:SetPoint("TOPRIGHT", -12, -9)
    box:SetAutoFocus(false)
    box:SetScript("OnTextChanged", function(self) page.search = self:GetText(); mod:Call("Buch", B.RefreshItems) end)
    box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    page.searchBox = box
    page.count = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    page.count:SetPoint("BOTTOMLEFT", 10, 12)
    page.hint = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    page.hint:SetPoint("BOTTOMRIGHT", -10, 12)
    page.hint:SetText(GREY .. L.BK_ITEMS_HINT .. "|r")
end

W.pages.book = { build = B.BuildBook, refresh = B.RefreshBook }
W.pages.items = { build = B.BuildItems, refresh = B.RefreshItems }
