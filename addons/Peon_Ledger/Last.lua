-- Peon_Ledger - Last.lua
-- Zuletzt gezahlt und zuletzt verkauft (ab 0.14, Konzept Peon_Ledger_Neuaufbau.md Abschnitt 4, Bauabschnitt E3).
-- Zusaetzlich zu den Kosten nach "aelteste zuerst" merkt sich Ledger je Gegenstand den letzten Kauf und den
-- letzten Verkauf, accountweit je Realm:
--   Kauf:    Auktionshaus, Haendler (auch Rueckkauf), Nachnahme, Handel mit Gold (src "ah", "vendor", "cod", "trade")
--   Verkauf: Auktionshaus (netto nach Anteil), Haendler (src "ah", "vendor")
-- Ergebnis je Gegenstand { t, unit = Kupfer je Stueck, n = Stueck, src, c = Charakter }.
-- Gerechnet aus dem Verlauf (zwischengespeichert bis zur naechsten Bewegung). Bevor Eintraege nach 90 Tagen zu
-- Wochensummen werden, kommt der Stand nach realms[Realm].last = { buy = {}, sale = {} } (Persist).

local ADDON_NAME, ns = ...
local mod = ns.mod

local LB = {}
ns.Last = LB
LB.dirty = true
LB.TRADE_GAP = 10   -- Sekunden: Gold und Gegenstaende eines Handels gehoeren zusammen

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

local function Put(t, id, e, unit, n, src)
    if not id or not Num(unit) or unit < 0 or not Num(n) or n <= 0 then return end
    local old = t[id]
    if old and (old.t or 0) > (e.t or 0) then return end
    t[id] = { t = e.t or 0, unit = unit, n = n, src = src, c = e.c }
end

function LB.Index()
    if not LB.dirty and LB.cache then return LB.cache end
    local r = ns.Inventory.RealmData()
    local base = type(r.last) == "table" and r.last or {}
    local buy, sale = {}, {}
    for id, v in pairs(type(base.buy) == "table" and base.buy or {}) do buy[id] = v end
    for id, v in pairs(type(base.sale) == "table" and base.sale or {}) do sale[id] = v end
    local list = ns.Moves.List()
    local trades = {}
    for _, e in ipairs(list) do
        local k, id, n, m = e.k, e.id, e.n, e.m
        if k == "ahbuy" and id and Num(m) and m < 0 then
            local q = (Num(n) and n > 0) and n or (Num(e.q) and e.q or nil)
            if q then Put(buy, id, e, -m / q, q, "ah") end
        elseif (k == "vendor" or k == "buyback") and id and Num(n) and n > 0 and Num(m) and m < 0 then
            Put(buy, id, e, -m / n, n, "vendor")
        elseif k == "mail" and id and Num(n) and n > 0 and Num(e.paid) and e.paid > 0 then
            Put(buy, id, e, e.paid / n, n, "cod")
        elseif k == "ahsold" and id and Num(m) and m > 0 then
            local q = (Num(e.q) and e.q) or ((Num(n) and n < 0) and -n) or 1
            local net = m
            if Num(e.gross) and Num(e.cut) then net = e.gross - e.cut end
            Put(sale, id, e, net / q, q, "ah")
        elseif k == "vendor" and id and Num(n) and n < 0 and Num(m) and m > 0 then
            Put(sale, id, e, m / -n, -n, "vendor")
        elseif k == "trade" then
            -- Handel: Gold gegeben und genau ein Gegenstand erhalten
            local key = tostring(e.c) .. "|" .. tostring(e.x)
            local g = trades[key]
            if not g or math.abs((e.t or 0) - g.t) > LB.TRADE_GAP then
                if g then LB.CloseTrade(buy, g) end
                g = { t = e.t or 0, m = 0, ins = {}, e = e }
                trades[key] = g
            end
            if Num(m) then g.m = g.m + m end
            if id and Num(n) and n > 0 then g.ins[id] = (g.ins[id] or 0) + n; g.e = e end
        end
    end
    for _, g in pairs(trades) do LB.CloseTrade(buy, g) end
    LB.cache = { buy = buy, sale = sale }
    LB.dirty = false
    return LB.cache
end

function LB.CloseTrade(buy, g)
    if g.m >= 0 then return end
    local only, cnt = nil, 0
    for id in pairs(g.ins) do only = id; cnt = cnt + 1 end
    if cnt == 1 then Put(buy, only, g.e, -g.m / g.ins[only], g.ins[only], "trade") end
end

function LB.Buy(id) return LB.Index().buy[id] end
function LB.Sale(id) return LB.Index().sale[id] end

-- Stand vor dem Zusammenfassen sichern (Moves.Prune)
function LB.Persist()
    local idx = LB.Index()
    local r = ns.Inventory.RealmData()
    r.last = { buy = idx.buy, sale = idx.sale }
end

function LB.Clear()
    ns.Inventory.RealmData().last = nil
    LB.dirty = true
end
