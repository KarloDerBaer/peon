-- Peon_Ledger - Book.lua
-- Buch: Auswertung der Bewegungen (Moves.lua) je Zeitraum und Charakter.
-- Ab 0.14 (Neuaufbau E4, Konzept Peon_Ledger_Neuaufbau.md Abschnitt 6.3) ein Reiter mit Peon.UI:
--   oben Zeitraum und Charakter, links die Summen, rechts zwei Ansichten:
--   "Nach Art" (Einnahmen und Ausgaben je Art) und "Nach Gegenstand" (ersetzt den Reiter Umsatz).
-- Ab 0.15 (Konzept Peon_Ledger_Buch_AH.md): "Nach Art" in drei Teilen. Oben das Auktionshaus mit Geld, das wirklich
-- floss (Kaeufe, Einstellgebuehren bezahlt und zurueck, Abbruchkosten, Verkaeufe brutto, Anteil, Ware an Haendler),
-- darunter der Handelsgewinn (Handelsteil der Verkaeufe, Cost.TradeProfit) mit grauen davon-Zeilen, die den
-- Unterschied zum Geldfluss erklaeren (ins Lager ist der Rest, so geht die Rechnung immer auf). In der Mitte der
-- Spielalltag (uebrige Arten, dazu "AH: Verkauf Beute"), unten die Summen. Verkaufsquote = verkauft /
-- (verkauft + zurueck) in Stueck, letzte 30 Tage, ab 3 Stueck.
-- Ab 0.17 (Markttausch): graue Zeile "davon Markttausch" unter dem Handelsgewinn, Gewinn aus Ware, die im anderen Haus
-- gekauft als verkauft wurde (Cost.lua, swap). Sie gehoert nicht zur Ueberleitung darunter.

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
-- Arten im Auktionshaus-Teil (Geldfluss) und im Spielalltag, jeweils in dieser Reihenfolge
B.AH = { "ahbuy", "ahfee", "ahcancel", "ahsold", "ahcut", "ahvendor" }
B.DAILY = { "vendor", "ahloot", "buyback", "repair", "loot", "quest", "craft", "trade", "mail", "taxi", "trainer", "other" }
B.ORDER = {}
for _, k in ipairs(B.AH) do B.ORDER[#B.ORDER + 1] = k end
for _, k in ipairs(B.DAILY) do B.ORDER[#B.ORDER + 1] = k end
-- graue davon-Zeilen unter dem Handelsgewinn
B.BRIDGE = { "stock", "auction", "open", "loot", "foreign", "used" }

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
local function IsAH(k) for _, x in ipairs(B.AH) do if x == k then return true end end return false end

-- Auswertung: { kinds = { [Art] = { inc, exp } }, inc, exp, fee, cut, items = { [id] = {...} },
--   trade (Handelsgewinn), sales (Handelsteil der Verkaeufe brutto), cut (Anteil davon), cogs (Wareneinsatz),
--   tfee (Gebuehren im Handelsgewinn), tdep (Einzahlung zurueck), vend (Ware an Haendler), use (Verbrauch),
--   nsales, ahflow (Saldo Auktionshaus), daily (Spielalltag), result (Gesamtergebnis), profit (Goldaenderung),
--   bridge = { stock, open, foreign, used } }
function B.Collect(period, onlyMe, now, char)
    local from = B.From(period, now)
    local me = char or ns.CharName()
    if char then onlyMe = true end
    local res = { kinds = {}, inc = 0, exp = 0, fee = 0, cut = 0, items = {},
                  sales = 0, cogs = 0, tfee = 0, tdep = 0, vend = 0, trade = 0, use = 0, nsales = 0 }
    local feesUsed, foreign, usedA, lootFees = 0, 0, 0, 0
    local function Item(id)
        local it = res.items[id]
        if not it then it = { id = id, nin = 0, nout = 0, sold = 0, back = 0, inc = 0, exp = 0, gross = 0, grossQ = 0,
            profit = nil, cogs = 0, use = 0, buyN = 0, buyV = 0, sellN = 0, sellV = 0 }; res.items[id] = it end
        return it
    end
    local function Money(k, m)
        if not m or math.abs(m) < 0.0001 then return end
        local kk = res.kinds[k]
        if not kk then kk = { inc = 0, exp = 0 }; res.kinds[k] = kk end
        if m > 0 then
            res.inc = res.inc + m; kk.inc = kk.inc + m
        else
            if k == "ahfee" or k == "ahcancel" then res.fee = res.fee - m else res.exp = res.exp - m end
            kk.exp = kk.exp - m
        end
    end
    -- nur Anzeige (ab 0.15): Einzahlung und Gebuehren des Beuteteils stehen bei "AH: Verkauf Beute", das Gold
    -- dazu ist schon bei den Einstellgebuehren gezaehlt (Goldaenderung bleibt unberuehrt)
    local function Adj(k, inc, exp)
        local kk = res.kinds[k]
        if not kk then kk = { inc = 0, exp = 0 }; res.kinds[k] = kk end
        kk.inc, kk.exp = kk.inc + (inc or 0), kk.exp + (exp or 0)
    end
    local function Zuordnen(e, r)
        if not r then return end
        local p = ns.Cost.TradeProfit(r)
        res.trade = res.trade + p
        if r.swap then   -- ab 0.17: Markttausch (im anderen Haus gekauft als verkauft)
            res.swap = (res.swap or 0) + (r.swap.profit or 0)
            res.swapN = (res.swapN or 0) + (r.swap.n or 0)
        end
        if r.lost then   -- ab 0.16.3: offene Gebuehren, deren Bestand ohne Verkauf weg ist
            res.tfee = res.tfee + r.lost
            feesUsed = feesUsed + r.lost
            if e.id then Item(e.id).profit = (Item(e.id).profit or 0) - r.lost end
        end
        if r.lootShare then
            if r.sale then res.nsales = res.nsales + 1 end
            res.cogs = res.cogs + (r.cost or 0)
            local lam = r.lootShare
            res.tfee, res.tdep = res.tfee + (r.fee or 0) * (1 - lam), res.tdep + (r.dep or 0) * (1 - lam)
            feesUsed = feesUsed + (r.fee or 0)
            if lam > 0 and ((r.fee or 0) > 0 or (r.dep or 0) > 0) then
                lootFees = lootFees + ((r.dep or 0) - (r.fee or 0)) * lam
                Adj("ahloot", (r.dep or 0) * lam, (r.fee or 0) * lam)
            end
            foreign = foreign + (r.cost or 0) - (r.acost or 0)
            if e.id and (r.sale or p ~= 0) then
                local it = Item(e.id)
                it.profit = (it.profit or 0) + p
                it.cogs = it.cogs + (r.cost or 0)
            end
            if r.vendor then res.vend = res.vend + math.max(0, e.m or 0) * (1 - r.lootShare) end
        elseif r.general then
            res.tfee = res.tfee + r.general
            feesUsed = feesUsed + r.general
        elseif r.player then
            usedA = usedA + (r.acost or 0)
        elseif r.use and not r.traded then
            res.use = res.use + r.use
            usedA = usedA + (r.acost or 0)
            if e.id then Item(e.id).use = Item(e.id).use + r.use end
        end
    end
    local function Use(e)
        local zr = ns.Cost and ns.Cost.Result(e)
        Zuordnen(e, zr)
        local side = Side(e)
        if e.k == "ahreturn" and e.id and (e.n or 0) > 0 then Item(e.id).back = Item(e.id).back + e.n end
        if side == "move" then return end
        local m = e.m
        if e.k == "ahsold" and m and m > 0 then
            -- ab 0.15: brutto, Anteil und Einzahlung zurueck einzeln, Beuteteil im Spielalltag
            local lam = zr and zr.lootShare or 0
            local dep = ns.Cost and ns.Cost.Deposit(e) or 0
            local net, cut = m - dep, e.cut or 0
            Money("ahsold", (net + cut) * (1 - lam))
            Money("ahcut", -cut * (1 - lam))
            Money("ahfee", dep)
            Money("ahloot", net * lam)
            res.cut = res.cut + cut * (1 - lam)
            res.sales = res.sales + (net + cut) * (1 - lam)
        elseif e.k == "vendor" and m and m > 0 and zr and zr.vendor then
            local lam = zr.lootShare or 1
            Money("ahvendor", m * (1 - lam))
            Money("vendor", m * lam)
        elseif e.k == "ahfee" and m then
            Money(e.x == L.MV_X_CANCEL and "ahcancel" or "ahfee", m)
        else
            Money(e.k, m)
        end
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
    -- Summen: Geldfluss im Auktionshaus, Spielalltag, Gesamtergebnis, Goldaenderung
    local ahflow, daily = 0, 0
    for k, kk in pairs(res.kinds) do
        if IsAH(k) then ahflow = ahflow + kk.inc - kk.exp else daily = daily + kk.inc - kk.exp end
    end
    res.ahflow, res.daily = ahflow, daily
    res.result = res.trade + daily
    res.profit = res.inc - res.exp - res.fee
    -- davon-Zeilen: Geldfluss im Auktionshaus = Handelsgewinn + stock + open + loot + foreign + used
    -- (der Spielalltag enthaelt die Einzahlungen und Gebuehren der Beute schon, deshalb dort abziehen)
    -- ab 0.15: Ware aus Kaeufen im Zeitraum, die gerade in laufenden Auktionen steht, getrennt vom Lager
    local listed = ns.Cost and ns.Cost.ListedValue and ns.Cost.ListedValue(from, onlyMe and me or nil) or 0
    local b = { open = -(res.fee - feesUsed), loot = lootFees, foreign = foreign, used = -usedA, auction = -listed }
    b.stock = ahflow - res.trade - b.open - b.loot - b.foreign - b.used - b.auction
    res.bridge = b
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

-- Zeilen "Nach Art" (ab 0.15): style = "row" (Einnahmen, Ausgaben, Saldo), "blank", "total" (nur Saldo, gold),
-- "sub" (grau, eingerueckt, nur Saldo); line = Trennstrich ueber der Zeile
local function Known(k) for _, o in ipairs(B.ORDER) do if o == k then return true end end return false end

function B.BookRows(res)
    local rows = {}
    if not next(res.kinds) and math.abs(res.trade or 0) < 0.5 then return rows end   -- leer: Hinweis der Tabelle
    local function Add(r) r.order = #rows; r.style = r.style or "row"; rows[#rows + 1] = r; return r end
    local function Nonzero(kk) return kk and (math.abs(kk.inc) >= 0.5 or math.abs(kk.exp) >= 0.5) end
    for _, k in ipairs(B.AH) do
        local kk = res.kinds[k]
        if Nonzero(kk) then Add({ k = k, label = L["BK_" .. k:upper()] or k, inc = kk.inc, exp = kk.exp, sum = kk.inc - kk.exp }) end
    end
    Add({ style = "blank" })
    Add({ k = "htrade", style = "total", label = L.BK_R_TRADE, sum = res.trade })
    if res.swapN and res.swapN > 0 then   -- ab 0.17: Anteil des Markttauschs (nicht Teil der Ueberleitung darunter)
        Add({ k = "swap", style = "sub", label = L.BK_SWAP:format(math.floor(res.swapN + 0.5)), sum = res.swap or 0 })
    end
    for _, k in ipairs(B.BRIDGE) do
        local v = res.bridge and res.bridge[k]
        if v and math.abs(v) >= 0.5 then Add({ k = "bridge_" .. k, style = "sub", label = L["BK_B_" .. k:upper()], sum = v }) end
    end
    local first = true
    local other = { inc = 0, exp = 0 }
    for k2, x in pairs(res.kinds) do
        if k2 == "other" or not Known(k2) then other.inc, other.exp = other.inc + x.inc, other.exp + x.exp end
    end
    for _, k in ipairs(B.DAILY) do
        local kk = (k == "other") and other or res.kinds[k]   -- unbekannte Arten zaehlen zu Sonstiges
        if Nonzero(kk) then
            Add({ k = k, label = L["BK_" .. k:upper()] or L.BK_OTHER, inc = kk.inc, exp = kk.exp, sum = kk.inc - kk.exp, line = first or nil })
            first = false
        end
    end
    Add({ style = "blank", line = first or nil })
    Add({ k = "daily", style = "total", label = L.BK_R_DAILY, sum = res.daily })
    Add({ k = "sum_trade", tip = "htrade", style = "total", label = L.BK_R_TRADE, sum = res.trade, line = true })
    Add({ k = "sum_daily", tip = "daily", style = "total", label = L.BK_R_DAILY, sum = res.daily })
    Add({ k = "result", style = "total", label = L.BK_R_RESULT, sum = res.result })
    Add({ k = "gold", style = "sub", label = L.BK_R_GOLD, sum = res.profit })
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
    -- ab 0.15: Handelsgewinn, Spielalltag, Gesamtergebnis, Goldaenderung (Einzelheiten im Tooltip)
    local s = page.lines
    s.trade:Set(L.BK_R_TRADE, W.Signed(res.trade))
    s.daily:Set(L.BK_R_DAILY, W.Signed(res.daily))
    s.result:Set(L.BK_R_RESULT, W.Signed(res.result))
    s.gold:Set(GREY .. L.BK_R_GOLD .. "|r", W.Signed(res.profit))
    s.use:Set(GREY .. L.BK_L_USE .. "|r", GREY .. ns.Money(math.floor(res.use + 0.5)) .. "|r")
    page.kinds:SetData(B.BookRows(res))
    page.items:SetData(B.ItemRows(res, page.search, char))
    local view = mod.db.bookView == "items" and "items" or "kinds"
    page.kindsPanel:SetShown(view == "kinds")
    page.itemsPanel:SetShown(view == "items")
    if page.searchBox then page.searchBox:SetShown(view == "items") end
end

-- Tooltip des Handelsgewinns (ab 0.15): woraus er sich zusammensetzt
local function M(v) return ns.Money(math.floor(math.abs(v or 0) + 0.5)) end
function B.TradeTooltip(owner)
    local res = B.book.res
    if not GameTooltip or not res then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddDoubleLine(L.BK_R_TRADE, W.Signed(res.trade), 1, 0.82, 0, 1, 1, 1)
    local function Line(label, v, sign)
        if math.abs(v or 0) < 0.5 then return end
        GameTooltip:AddDoubleLine(label, sign .. M(v), 0.9, 0.9, 0.9, 1, 1, 1)
    end
    Line(L.BK_TT_SALES, res.sales, "+")
    Line(L.BK_TT_CUT, res.cut, "-")
    Line(L.BK_TT_DEP, res.tdep, "+")
    Line(L.BK_TT_FEE, res.tfee, "-")
    Line(L.BK_TT_VEND, res.vend, "+")
    Line(L.BK_TT_COGS, res.cogs, "-")
    GameTooltip:AddLine(L.BK_TT_HINT, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- Tooltip einer Zeile "Nach Art" (ab 0.15): Erklaerung der Summen und davon-Zeilen
function B.KindTooltip(row, r)
    local key = r.tip or r.k
    local text = key and L["BK_TT_" .. key:upper()]
    if not GameTooltip or not text then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(r.label or "", 1, 0.82, 0)
    GameTooltip:AddLine(text, 0.9, 0.9, 0.9, true)
    if B.JumpKinds(r) then GameTooltip:AddLine(L.BK_JUMP_HINT, 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end

-- Sprung in den Verlauf (ab 0.18, Konzept Peon_Ledger_Schlank.md Abschnitt 5): Zeile "Nach Art" -> Arten der Bewegungen.
-- Summen und davon-Zeilen des Handels zeigen alle Bewegungen im Auktionshaus, Spielalltag und Ergebnis haben keinen.
local AH_ALL = { ahbuy = true, ahsold = true, ahfee = true, posted = true, ahback = true, ahreturn = true }
B.JUMP = {
    ahbuy = { ahbuy = true }, ahfee = { ahfee = true, posted = true }, ahcancel = { ahfee = true },
    ahsold = { ahsold = true }, ahcut = { ahsold = true }, ahloot = { ahsold = true }, ahvendor = { vendor = true },
    vendor = { vendor = true }, buyback = { buyback = true }, repair = { repair = true }, loot = { loot = true },
    quest = { quest = true }, craft = { craft = true }, trade = { trade = true }, mail = { mail = true, twink = true },
    taxi = { taxi = true }, trainer = { trainer = true }, other = { other = true, diff = true, fix = true },
    htrade = AH_ALL, sum_trade = AH_ALL, swap = AH_ALL,
}
function B.JumpKinds(r)
    if not r or not r.k then return nil end
    if r.k:sub(1, 7) == "bridge_" then return AH_ALL end
    return B.JUMP[r.k]
end

function B.JumpToHistory(r)
    local kinds = B.JumpKinds(r)
    if not kinds or not ns.History then return false end
    local period
    for _, p in ipairs(B.PERIODS) do if p.key == mod.db.bookPeriod then period = L[p.label] end end
    local label = (r.label or "") .. (period and (" · " .. period) or "")
    ns.History.Jump(kinds, B.From(mod.db.bookPeriod), label, B.Char())
    return true
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
    -- ab 0.15.1: Charakter ganz links, Zeitraum ganz rechts (vorher lag der Zeitraum ueber dem Reiter "Nach Gegenstand")
    page.charDD:SetPoint("TOPLEFT", 80, -32)
    page.periodDD:SetPoint("TOPRIGHT", -16, -32)
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
    -- ab 0.15: grosse Werte (Handelsgewinn, Gesamtergebnis) in eigener Zeile unter der Beschriftung, sonst lagen
    -- Text und Betrag uebereinander
    local keys = { "trade", "daily", "result", "-", "gold", "-", "use" }
    local big = { trade = true, result = true }
    local y = -38
    for _, k in ipairs(keys) do
        if k == "-" then
            y = y - 10
        else
            local line = W.ValueLine(left, y)
            if big[k] then
                line.value:ClearAllPoints()
                line.value:SetPoint("TOPRIGHT", -14, y - 18)
                U.Font(line.value, "big")
                y = y - 46
            else
                y = y - 22
            end
            page.lines[k] = line
        end
    end
    -- Tooltip ueber der Zeile Handelsgewinn
    local hover = CreateFrame("Frame", nil, left)
    hover:SetPoint("TOPLEFT", 8, -34)
    hover:SetPoint("TOPRIGHT", -8, -34)
    hover:SetHeight(44)
    if hover.EnableMouse then hover:EnableMouse(true) end
    hover:SetScript("OnEnter", function(self) B.TradeTooltip(self) end)
    hover:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    page.tradeHover = hover
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
    -- ab 0.15 feste Reihenfolge (keine Sortierung), Summen gold, davon-Zeilen grau, Trennstrich ab Kern-API 21
    local function Cash(v, r, color)
        if r.style ~= "row" then return "" end
        if math.abs(v or 0) < 0.5 then return GREY .. "–|r" end
        return color .. ns.Money(math.floor(v + 0.5)) .. "|r"
    end
    page.kinds = U.Table(page.kindsPanel, {
        columns = {
            { key = "label", title = L.COL_KIND, nosort = true, format = function(v, r)
                if r.style == "total" then return W.YELLOW .. (v or "") .. "|r" end
                if r.style == "sub" then return GREY .. "   " .. (v or "") .. "|r" end
                return v or "" end },
            { key = "inc", title = L.BK_INC, width = 110, align = "RIGHT", nosort = true, format = function(v, r) return Cash(v, r, W.GREEN) end },
            { key = "exp", title = L.BK_EXP, width = 110, align = "RIGHT", nosort = true, format = function(v, r) return Cash(v, r, W.RED) end },
            { key = "sum", title = L.BK_SUM, width = 110, align = "RIGHT", nosort = true, format = function(v, r)
                if r.style == "blank" then return "" end
                if r.style == "sub" then return GREY .. ((v or 0) >= 0.5 and "+" or ((v or 0) <= -0.5 and "-" or "")) .. M(v) .. "|r" end
                return W.Signed(v) end },
        },
        sortKey = "order", empty = L.BK_EMPTY,
        rowLine = function(r) return r.line end,
        onEnter = function(row, r) B.KindTooltip(row, r) end,
        onClick = function(r, button) if button == "LeftButton" then B.JumpToHistory(r) end end,
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
    page.searchBox:SetPoint("RIGHT", page.periodDD, "LEFT", -8, 0)   -- ab 0.15.1 neben dem Zeitraum
    page.view:Select(mod.db.bookView == "items" and "items" or "kinds")
end

W.pages.book = { build = B.Build, refresh = B.Refresh, status = B.Status }
