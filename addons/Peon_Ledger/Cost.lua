-- Peon_Ledger - Cost.lua
-- Zuordnen (ab 0.7, Konzept Peon_Ledger_Zuordnen.md, abgestimmt mit KarloDerBaer 03.10.2026):
-- Kosten je Stueck nach "aelteste zuerst" (FIFO), ab 0.9 je Charakter (vorher accountweit je Realm; Konzept
-- Peon_Ledger_Gegenstand.md, KarloDerBaer 06.10.2026). Daraus Lagerwert, Wareneinsatz, Handelsgewinn und Verbrauch.
-- Post an eigene Twinks nimmt die Posten mit (aelteste zuerst beim Absender), sie liegen bis zum Abholen in
-- st.transit[Empfaenger] und kommen dann mit ihrem urspruenglichen Datum zu seinen Posten.
--
-- Gerechnet wird durch Nachspielen: Anfangsbestand (Inventur je Charakter und Ort, zum Marktwert beim Start)
-- und alle Bewegungen (Moves.lua) in zeitlicher Reihenfolge. Das Ergebnis wird zwischengespeichert und bei
-- jeder neuen Bewegung verworfen (ns.Cost.dirty). Werden Bewegungen nach 90 Tagen zu Wochensummen, uebernimmt
-- Absorb ihren Stand vorher in realms[Realm].lotBase = { untilT, lots, fee } (sonst gingen die Posten verloren).
--
-- Posten je Charakter und Gegenstand: st.chars[Name].lots[itemID] = { { t, n, c }, ... } aelteste zuerst (t = Zeit, n = Stueck, c = Kosten je Stueck in Kupfer).
--   Zugaenge derselben Art am selben Tag zum gleichen Preis werden zusammengefasst; hoechstens C.MAX_LOTS Posten,
--   darueber werden die aeltesten zu einem Posten mit ihren Durchschnittskosten zusammengelegt.
-- fee[itemID] = offene Gebuehren (Einstellgebuehren, Abbruchkosten), mindern den Gewinn des naechsten Verkaufs.
-- res[Eintrag] = Ergebnis je Bewegung: { sale, cost, fee, profit, miss } | { use } | { unit } | { general } | { mat }

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local C = {}
ns.Cost = C

C.MAX_LOTS = 30
C.CRAFT_CARRY = 30     -- Sekunden: Material und Ergebnis beim Herstellen gehoeren zusammen
C.MATCH_DAYS = 7       -- Gold eines Auktionskaufs und Gegenstand aus der Post
C.dirty = true

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Day(t) return math.floor((t or 0) / 86400) end   -- Tag (schnell, ohne date())

-- Marktwert je Stueck: Zeile 1 des Broker-Tooltips, sonst Haendlerpreis; nil wenn unbekannt
function C.MarketValue(id)
    local v = ns.Value and ns.Value(id, 1)
    if Num(v) and v > 0 then return v end
    local p = ns.Moves.SellPrice and ns.Moves.SellPrice(id)
    if Num(p) and p > 0 then return p end
    return nil
end

---------------------------------------------------------------------------
-- Posten
---------------------------------------------------------------------------
local function NewState() return { chars = {}, transit = {}, craft = {}, trade = {}, res = {}, general = 0 } end

-- Teilstand eines Charakters waehlen: st.lots, st.fee, st.buy, st.soldQ, st.pre zeigen auf seine Tabellen
local function Sub(st, c)
    c = c or "?"
    local x = st.chars[c]
    if not x then x = { lots = {}, fee = {}, buy = {}, soldQ = {}, pre = {} }; st.chars[c] = x end
    st.lots, st.fee, st.buy, st.soldQ, st.pre, st.cur = x.lots, x.fee, x.buy, x.soldQ, x.pre, c
    return x
end
C.Sub = Sub

local function AddLot(st, id, n, c, t, noMerge)
    if not id or not Num(n) or n <= 0 then return nil end
    c = (Num(c) and c > 0) and c or 0
    local q = st.lots[id]
    if not q then q = {}; st.lots[id] = q end
    local last = q[#q]
    if not noMerge and last and not last.wait and Day(last.t) == Day(t) and math.abs(last.c - c) < 0.5 then
        last.n = last.n + n
        return last
    end
    local lot = { t = t or 0, n = n, c = c }
    q[#q + 1] = lot
    C.Cap(q)
    return lot
end
C.AddLot = AddLot

-- hoechstens C.MAX_LOTS Posten: die aeltesten zu einem zusammenlegen
function C.Cap(q)
    if #q > C.MAX_LOTS then
        local k = #q - C.MAX_LOTS + 1
        local n2, v2 = 0, 0
        for i = 1, k do n2 = n2 + q[i].n; v2 = v2 + q[i].n * q[i].c end
        local merged = { t = q[k].t, n = n2, c = n2 > 0 and v2 / n2 or 0 }
        for _ = 1, k do table.remove(q, 1) end
        table.insert(q, 1, merged)
    end
end

-- Posten nach Datum einsortieren (Post vom Twink behaelt das urspruengliche Datum)
local function InsertLot(st, id, lot)
    if not id or not Num(lot.n) or lot.n <= 0 then return end
    local q = st.lots[id]
    if not q then q = {}; st.lots[id] = q end
    local pos = #q + 1
    for i, x in ipairs(q) do if (x.t or 0) > (lot.t or 0) then pos = i; break end end
    local prev = q[pos - 1]
    if prev and not prev.wait and Day(prev.t) == Day(lot.t) and math.abs(prev.c - lot.c) < 0.5 then
        prev.n = prev.n + lot.n
        return
    end
    table.insert(q, pos, { t = lot.t or 0, n = lot.n, c = lot.c or 0 })
    C.Cap(q)
end
C.InsertLot = InsertLot

-- n Stueck mit ihren Posten entnehmen (fuer Post an Twinks); Rueckgabe: Liste { t, n, c }, Stueck ohne Posten
local function TakeLots(st, id, n)
    local q = id and st.lots[id]
    local out, left = {}, n or 0
    while q and left > 0 and q[1] do
        local lot = q[1]
        local k = math.min(left, lot.n)
        out[#out + 1] = { t = lot.t, n = k, c = lot.c }
        lot.n = lot.n - k
        left = left - k
        if lot.n <= 0 then table.remove(q, 1) end
    end
    if q and #q == 0 then st.lots[id] = nil end
    return out, left
end
C.TakeLots = TakeLots

-- n Stueck entnehmen, aelteste zuerst; Rueckgabe: Kosten zusammen, Stueck ohne Posten
local function Take(st, id, n)
    local q = id and st.lots[id]
    local cost, left = 0, n or 0
    while q and left > 0 and q[1] do
        local lot = q[1]
        local k = math.min(left, lot.n)
        cost = cost + k * lot.c
        lot.n = lot.n - k
        left = left - k
        if lot.n <= 0 then table.remove(q, 1) end
    end
    if q and #q == 0 then st.lots[id] = nil end
    return cost, left
end
C.Take = Take

---------------------------------------------------------------------------
-- Ereignisse: Anfangsbestand + Bewegungen, zeitlich geordnet
---------------------------------------------------------------------------
-- Reihenfolge innerhalb derselben Sekunde: Anfangsbestand, Abgaenge (Material, gegebene Ware, Gold raus),
-- Gold rein, Zugaenge - so kennt ein Ergebnis die Kosten seines Materials
local function Class(e)
    if e.start then return 0 end
    if (e.n and e.n < 0) or (not e.n and (e.m or 0) < 0) then return 1 end
    if not e.n and (e.m or 0) > 0 then return 2 end
    return 3
end

function C.StartEvents(fromT)
    local ev = {}
    for name, c in pairs(ns.Inventory.RealmData().chars) do
        local s = c.start
        if type(s) == "table" and type(s.places) == "table" then
            for place, p in pairs(s.places) do
                -- Post gehoert erst beim Nehmen dazu (ab 0.7.2): Briefkasten und "unterwegs" nicht als Anfangsbestand
                local t = type(p) == "table" and place ~= "mail" and place ~= "transit" and (p.t or s.t) or nil
                if t and t >= fromT and type(p.items) == "table" then
                    for id, n in pairs(p.items) do
                        if Num(id) and Num(n) and n > 0 then ev[#ev + 1] = { start = true, t = t, c = name, id = id, n = n, s = s } end
                    end
                end
            end
        end
    end
    return ev
end

local function Sorted(ev)
    for i, e in ipairs(ev) do e.__i = i end
    table.sort(ev, function(a, b)
        local ta, tb = a.t or 0, b.t or 0
        if ta ~= tb then return ta < tb end
        local ca, cb = Class(a.e or a), Class(b.e or b)
        if ca ~= cb then return ca < cb end
        return a.__i < b.__i
    end)
    return ev
end

-- Marktwert beim Start einfrieren (beim ersten Rechnen gemerkt: start.v[itemID])
local function StartValue(s, id)
    if type(s.v) ~= "table" then s.v = {} end
    local v = s.v[id]
    if v == nil then
        v = C.MarketValue(id)
        if v then s.v[id] = v end
    end
    return v or 0
end

---------------------------------------------------------------------------
-- Eine Bewegung nachspielen
---------------------------------------------------------------------------
local function PopBuy(st, id, t)
    local best
    for i, p in ipairs(st.buy) do
        if t - p.t <= C.MATCH_DAYS * 86400 and (p.id == id) then best = i; break end
    end
    if not best then
        for i, p in ipairs(st.buy) do
            if t - p.t <= C.MATCH_DAYS * 86400 and p.id == nil then best = i; break end
        end
    end
    if not best then return nil end
    return table.remove(st.buy, best).m
end

local function Use(st, e, id, n)
    local cost = Take(st, id, n)
    st.res[e] = { use = cost }
end

local function Craft(st, e, id, n)
    local pool = st.craft[e.c]
    if not pool or (e.t or 0) - pool.t > C.CRAFT_CARRY then
        pool = { cost = 0, t = e.t or 0, wait = {} }
        st.craft[e.c] = pool
    end
    pool.t = e.t or 0
    if n < 0 then
        local cost = Take(st, id, -n)
        st.res[e] = { mat = cost }
        if #pool.wait > 0 then
            -- Ergebnis kam schon vorher (anderer Schub): Kosten nachtragen
            local pieces = 0
            for _, w in ipairs(pool.wait) do pieces = pieces + w.n end
            for _, w in ipairs(pool.wait) do
                local add = cost * w.n / pieces
                if w.lot.n > 0 then w.lot.c = w.lot.c + add / w.n end
                if st.res[w.e] then st.res[w.e].unit = (st.res[w.e].unit or 0) + add / w.n end
            end
        else
            pool.cost = pool.cost + cost
        end
    elseif n > 0 then
        if pool.cost > 0 then
            local unit = pool.cost / n
            AddLot(st, id, n, unit, e.t, true)
            st.res[e] = { unit = unit }
            pool.cost, pool.wait = 0, {}
        else
            local lot = AddLot(st, id, n, 0, e.t, true)
            st.res[e] = { unit = 0 }
            if lot then pool.wait[#pool.wait + 1] = { lot = lot, n = n, e = e } end
        end
    end
end

-- Handel: gegebene Ware und Gold = Gegenwert des Erhaltenen (nach Marktwert verteilt); nur Gold erhalten = Verkauf
local function Trade(st, e, id, n, m, groups)
    local key = tostring(e.c) .. "|" .. tostring(e.t)
    local g = st.trade[key]
    if not g then g = { give = 0, got = 0 }; st.trade[key] = g end
    if id and n < 0 then
        g.give = g.give + Take(st, id, -n)
        st.res[e] = { use = 0, traded = true }
    elseif not id and m < 0 then
        g.give = g.give - m
    elseif not id and m > 0 then
        g.got = g.got + m
        local recv = groups[key]
        if not recv or recv.mv == 0 then
            -- nur Gold erhalten: Verkauf
            st.res[e] = { sale = true, cost = g.give, fee = 0, profit = m - g.give, miss = 0 }
            g.give = 0
        end
    elseif id and n > 0 then
        local recv = groups[key]
        local value = math.max(0, g.give - g.got)
        local share = 0
        if recv and recv.mv > 0 then share = value * (C.MarketValue(id) or 0) * n / recv.mv end
        AddLot(st, id, n, share / n, e.t)
        st.res[e] = { unit = share / n }
    end
end

-- Post an/von eigenen Twinks (ab 0.9): Posten wandern mit
local function Twink(st, e, id, n)
    if not id or n == 0 then return end
    if n < 0 then
        local lots, left = TakeLots(st, id, -n)
        if left > 0 then lots[#lots + 1] = { t = e.t or 0, n = left, c = 0 } end   -- ohne Posten: Kosten 0 (wie beim Verkauf)
        local to = e.x
        if type(to) ~= "string" or to == "" then return end
        local tr = st.transit[to]
        if not tr then tr = {}; st.transit[to] = tr end
        local q = tr[id]
        if not q then q = {}; tr[id] = q end
        for _, lot in ipairs(lots) do q[#q + 1] = lot end
    else
        local tr = st.transit[st.cur]
        local q = tr and tr[id]
        local left = n
        while q and left > 0 and q[1] do
            local lot = q[1]
            local k = math.min(left, lot.n)
            InsertLot(st, id, { t = lot.t, n = k, c = lot.c })
            lot.n = lot.n - k
            left = left - k
            if lot.n <= 0 then table.remove(q, 1) end
        end
        if q and #q == 0 then tr[id] = nil end
        if left > 0 then
            -- Versand vor Beginn der Aufzeichnung: zum Marktwert (beim ersten Rechnen gemerkt, wie der Anfangsbestand)
            if not Num(e.v) then e.v = C.MarketValue(id) or 0 end
            InsertLot(st, id, { t = e.t or 0, n = left, c = e.v })
        end
    end
end

function C.Apply(st, e, groups)
    Sub(st, e.c)
    if e.start then
        AddLot(st, e.id, e.n, StartValue(e.s, e.id), e.t)
        return
    end
    local k, id, n, m = e.k, e.id, e.n or 0, e.m or 0
    if k == "twink" then Twink(st, e, id, n); return end
    if k == "posted" or k == "ahback" or k == "ahreturn" then return end   -- Umbuchung
    if k == "diff" then   -- ab 0.14: Abweichung der Kontrollrechnung, Kosten wie eine Korrektur
        if id and n > 0 then AddLot(st, id, n, e.v or 0, e.t) elseif id and n < 0 then Take(st, id, -n) end
        return
    end
    if k == "fix" then
        if id and n > 0 then AddLot(st, id, n, e.v or 0, e.t) elseif id and n < 0 then Take(st, id, -n) end
        return
    end
    if k == "ahfee" then
        if id then st.fee[id] = (st.fee[id] or 0) - m
        else st.res[e] = { general = -m } end
        return
    end
    if k == "ahbuy" then
        if id and n > 0 then
            local paid = m < 0 and -m or PopBuy(st, id, e.t or 0)
            AddLot(st, id, n, paid and paid / n or 0, e.t)
            st.res[e] = { unit = paid and paid / n or 0 }
        elseif n == 0 and m < 0 then
            st.buy[#st.buy + 1] = { m = -m, id = id, t = e.t or 0 }
        elseif n == 0 and m > 0 then
            -- Gebot zurueck (ueberboten): passenden Kauf aus der Warteschlange nehmen
            for i, p in ipairs(st.buy) do if p.m == m then table.remove(st.buy, i); break end end
        end
        return
    end
    if k == "vendor" or k == "buyback" then
        if id and n > 0 then
            local unit = m < 0 and -m / n or 0
            AddLot(st, id, n, unit, e.t)
            st.res[e] = { unit = unit }
        elseif id and n < 0 then
            local cost, miss = Take(st, id, -n)
            local got = m > 0 and m or 0
            st.res[e] = { sale = true, cost = cost, fee = 0, profit = got - cost, miss = miss }
        end
        return
    end
    if k == "ahsold" then
        if e.sp and m > 0 then
            -- ab 0.14.2: Sondereinnahme (Auktion von vor dem Neustart): Ware geht, kein Handelsgewinn
            local cost = 0
            if id then
                local cnt = (n < 0 and -n) or 0
                if cnt == 0 then
                    -- Ware schon ueber die Auktionsliste weg (soldQ) oder noch nicht: wie ein Verkauf vormerken
                    local q = e.q or 1
                    local sq = st.soldQ[id]
                    while sq and q > 0 and sq[1] do
                        local s = sq[1]
                        local k2 = math.min(q, s.n)
                        s.n, q = s.n - k2, q - k2
                        if s.n <= 0 then table.remove(sq, 1) end
                    end
                    if q > 0 then cost = Take(st, id, q); st.pre[id] = (st.pre[id] or 0) + q end
                else
                    local pre = st.pre[id] or 0
                    local use = math.min(pre, cnt)
                    st.pre[id] = pre - use
                    if cnt - use > 0 then cost = Take(st, id, cnt - use) end
                end
            end
            st.res[e] = { special = m, cost = cost }
        elseif id and n < 0 and m > 0 then
            -- ab 0.14 (Erfassung an der Quelle): Rechnung mit Ware und Erloes in einer Zeile
            local cnt = -n
            local pre = st.pre[id] or 0
            local use = math.min(pre, cnt)
            st.pre[id] = pre - use
            local cost, miss = 0, 0
            if cnt - use > 0 then cost, miss = Take(st, id, cnt - use) end
            local fee = st.fee[id] or 0
            st.fee[id] = nil
            st.res[e] = { sale = true, cost = cost, fee = fee, profit = m - cost - fee, miss = miss }
        elseif id and n < 0 then
            -- Gegenstand weg (Auktionsliste): Kosten fuer den Erloes vormerken
            local cnt = -n
            local pre = st.pre[id] or 0
            local use = math.min(pre, cnt)
            st.pre[id] = pre - use
            cnt = cnt - use
            if cnt > 0 then
                local cost = Take(st, id, cnt)
                local sq = st.soldQ[id]
                if not sq then sq = {}; st.soldQ[id] = sq end
                sq[#sq + 1] = { n = cnt, cost = cost }
            end
        elseif m > 0 then
            if not id then
                st.res[e] = { sale = true, cost = 0, fee = 0, profit = m, miss = e.q or 1, noitem = true }
                return
            end
            local q = e.q or 1
            local cost, left = 0, q
            local sq = st.soldQ[id]
            while sq and left > 0 and sq[1] do
                local s = sq[1]
                local kk = math.min(left, s.n)
                local part = s.n > 0 and s.cost * kk / s.n or 0
                cost, s.cost, s.n, left = cost + part, s.cost - part, s.n - kk, left - kk
                if s.n <= 0 then table.remove(sq, 1) end
            end
            local miss = 0
            if left > 0 then
                -- Auktionsliste kam (noch) nicht: jetzt aus dem Bestand nehmen und fuer spaeter vormerken
                local c2, mm = Take(st, id, left)
                cost, miss = cost + c2, mm
                st.pre[id] = (st.pre[id] or 0) + (left - mm)
            end
            local fee = st.fee[id] or 0
            st.fee[id] = nil
            st.res[e] = { sale = true, cost = cost, fee = fee, profit = m - cost - fee, miss = miss }
        end
        return
    end
    if k == "craft" then if id and n ~= 0 then Craft(st, e, id, n) end return end
    if k == "trade" then Trade(st, e, id, n, m, groups); return end
    if k == "mail" then
        if id and n > 0 then
            local unit = Num(e.paid) and e.paid / n or 0   -- Nachnahme
            AddLot(st, id, n, unit, e.t)
            st.res[e] = { unit = unit }
        elseif id and n < 0 then
            Use(st, e, id, -n)                             -- Post an andere: wie Verbrauch
        end
        return
    end
    -- Beute, Quest, Sonstiges, Benutzt, Zerstoert
    if id and n > 0 then
        AddLot(st, id, n, 0, e.t)
        st.res[e] = { unit = 0 }
    elseif id and n < 0 then
        Use(st, e, id, -n)
    end
end

-- Gruppen fuer den Handel: erhaltene Ware je Handel (Marktwert zum Verteilen)
local function TradeGroups(list)
    local g = {}
    for _, e in ipairs(list) do
        if e.k == "trade" and e.id and (e.n or 0) > 0 then
            local key = tostring(e.c) .. "|" .. tostring(e.t)
            local x = g[key]
            if not x then x = { mv = 0 }; g[key] = x end
            x.mv = x.mv + (C.MarketValue(e.id) or 0) * e.n
        end
    end
    return g
end

local function CopyLots(src)
    local lots = {}
    for id, q in pairs(type(src) == "table" and src or {}) do
        local c = {}
        for i, lot in ipairs(q) do c[i] = { t = lot.t, n = lot.n, c = lot.c } end
        lots[id] = c
    end
    return lots
end

-- Stand aus lotBase uebernehmen: ab 0.9 { untilT, chars = { [Name] = { lots, fee } }, transit };
-- altes Format (accountweit: lots, fee) geht an den eingeloggten Charakter
local function LoadBase(st, base)
    if not base then return 0 end
    if type(base.chars) == "table" then
        for c, x in pairs(base.chars) do
            local sub = Sub(st, c)
            for id, q in pairs(CopyLots(x.lots)) do sub.lots[id] = q end
            for id, f in pairs(type(x.fee) == "table" and x.fee or {}) do sub.fee[id] = f end
        end
        for to, tr in pairs(type(base.transit) == "table" and base.transit or {}) do st.transit[to] = CopyLots(tr) end
    elseif type(base.lots) == "table" then
        local sub = Sub(st, ns.CharName())
        for id, q in pairs(CopyLots(base.lots)) do sub.lots[id] = q end
        for id, f in pairs(type(base.fee) == "table" and base.fee or {}) do sub.fee[id] = f end
    end
    return base.untilT or 0
end

-- Alles nachspielen: Stand aus lotBase + Anfangsbestand ab untilT + Bewegungen
-- observer(st, x) (ab 0.9, fuer den Tagesverlauf): nach jedem Ereignis aufgerufen
function C.Replay(observer)
    local r = ns.Inventory.RealmData()
    local base = type(r.lotBase) == "table" and r.lotBase or nil
    local st = NewState()
    local fromT = LoadBase(st, base)
    local ev = C.StartEvents(fromT)
    local moves = ns.Moves.List()
    for _, e in ipairs(moves) do ev[#ev + 1] = { e = e, t = e.t or 0 } end
    Sorted(ev)
    local groups = TradeGroups(moves)
    for _, x in ipairs(ev) do
        if x.start then C.Apply(st, x, groups) else C.Apply(st, x.e, groups) end
        if observer then observer(st, x.start and x or x.e) end
    end
    return st, fromT
end

function C.State()
    if C.dirty or not C.state or C.realm ~= ns.Realm() then
        C.state = C.Replay()
        C.realm = ns.Realm()
        C.dirty = false
    end
    return C.state
end

function C.Invalidate() C.dirty = true end

-- Vor dem Zusammenfassen alter Bewegungen (Moves.Prune): ihren Stand in lotBase uebernehmen
function C.Absorb(old, limit)
    local r = ns.Inventory.RealmData()
    local base = type(r.lotBase) == "table" and r.lotBase or nil
    local st = NewState()
    local fromT = LoadBase(st, base)
    local ev = {}
    for _, x in ipairs(C.StartEvents(fromT)) do if x.t < limit then ev[#ev + 1] = x end end
    for _, e in ipairs(old) do ev[#ev + 1] = { e = e, t = e.t or 0 } end
    Sorted(ev)
    local groups = TradeGroups(old)
    for _, x in ipairs(ev) do
        if x.start then C.Apply(st, x, groups) else C.Apply(st, x.e, groups) end
    end
    local chars = {}
    for c, x in pairs(st.chars) do chars[c] = { lots = x.lots, fee = x.fee } end
    r.lotBase = { untilT = limit, chars = chars, transit = st.transit }
    C.dirty = true
end

-- Buch zuruecksetzen mit Kosten (ab 0.14.1): Posten aus dem bisherigen Stand (st) passend zum neuen Anfangsbestand.
-- Je Charakter und Gegenstand so viele Stueck wie er jetzt hat (Taschen, Bank, Auktionen, Ausruestung): die
-- neuesten Posten bleiben, fehlt etwas, kommt es zum Marktwert dazu (als aeltester Posten). "Unterwegs" (Post an
-- Twinks) bleibt passend zum Ort transit. Rueckgabe lotBase mit untilT nach dem Anfangsbestand (zaehlt dann nicht
-- noch einmal zum Marktwert).
C.CARRY_PLACES = { "bags", "bank", "auctions", "equip" }
local function Fit(q, want, t, id)
    local have = 0
    for _, lot in ipairs(q or {}) do have = have + lot.n end
    local out = {}
    -- neueste behalten: von hinten auffuellen
    local left = want
    for i = #(q or {}), 1, -1 do
        if left <= 0 then break end
        local lot = q[i]
        local k = math.min(lot.n, left)
        table.insert(out, 1, { t = lot.t, n = k, c = lot.c })
        left = left - k
    end
    if left > 0 then table.insert(out, 1, { t = t, n = left, c = C.MarketValue(id) or 0 }) end
    return out
end

function C.CarryOver(st, t)
    local r = ns.Inventory.RealmData()
    local chars, transit = {}, {}
    for name, c in pairs(r.chars) do
        local hold = {}
        for _, place in ipairs(C.CARRY_PLACES) do
            local p = c.start and c.start.places and c.start.places[place]
            if type(p) == "table" and type(p.items) == "table" then
                for id, n in pairs(p.items) do if Num(n) and n > 0 then hold[id] = (hold[id] or 0) + n end end
            end
        end
        local old = st.chars and st.chars[name]
        local lots = {}
        for id, n in pairs(hold) do lots[id] = Fit(old and old.lots and old.lots[id], n, t, id) end
        local fee = {}
        for id, f in pairs(old and old.fee or {}) do if hold[id] then fee[id] = f end end
        chars[name] = { lots = lots, fee = fee }
        local tr = c.places and c.places.transit
        if type(tr) == "table" and type(tr.items) == "table" and st.transit and st.transit[name] then
            local q = {}
            for id, n in pairs(tr.items) do if Num(n) and n > 0 then q[id] = Fit(st.transit[name][id], n, t, id) end end
            transit[name] = q
        end
    end
    return { untilT = t + 1, chars = chars, transit = transit }
end

---------------------------------------------------------------------------
-- Abfragen
---------------------------------------------------------------------------
-- Kosten eines Gegenstands (ab 0.9 je Charakter): naechstes Stueck, Durchschnitt, Stueck mit Posten, Lagerwert.
-- char: nil = eingeloggter Charakter, "*" = alle Charaktere. Posten "unterwegs" (Post an diesen Twink) zaehlen mit,
-- das naechste Stueck kommt aber aus dem, was der Charakter schon hat.
local function Lots(st, id, char)
    local own, all = {}, {}
    local function add(q, mine) for _, lot in ipairs(q or {}) do all[#all + 1] = lot; if mine then own[#own + 1] = lot end end end
    if char == "*" then
        for _, x in pairs(st.chars) do add(x.lots[id], true) end
        for _, tr in pairs(st.transit) do add(tr[id], false) end
    else
        local x = st.chars[char]
        add(x and x.lots[id], true)
        add(st.transit[char] and st.transit[char][id], false)
    end
    return own, all
end

function C.Info(id, char)
    char = char or ns.CharName()
    local own, all = Lots(C.State(), id, char)
    if not all[1] then return nil end
    local n, v = 0, 0
    for _, lot in ipairs(all) do n = n + lot.n; v = v + lot.n * lot.c end
    if n <= 0 then return nil end
    local first = own[1] or all[1]
    if char == "*" then
        for _, lot in ipairs(own) do if (lot.t or 0) < (first.t or 0) then first = lot end end
    end
    return { next = first.c, avg = v / n, n = n, value = v, lots = #all }
end

-- Kosten je Charakter: { { name, info }, ... } (nur Charaktere mit Posten)
function C.ByChar(id)
    local st, list, seen = C.State(), {}, {}
    for c in pairs(st.chars) do seen[c] = true end
    for c in pairs(st.transit) do seen[c] = true end
    for c in pairs(seen) do
        local info = C.Info(id, c)
        if info then list[#list + 1] = { name = c, info = info } end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function C.Result(e) return C.State().res[e] end

-- Lagerwert aller Gegenstaende (char: nil/"*" = alle Charaktere, sonst nur dieser)
function C.TotalValue(char)
    local st, v = C.State(), 0
    local function sum(lots) for _, q in pairs(lots or {}) do for _, lot in ipairs(q) do v = v + lot.n * lot.c end end end
    for c, x in pairs(st.chars) do if char == nil or char == "*" or c == char then sum(x.lots) end end
    for c, tr in pairs(st.transit) do if char == nil or char == "*" or c == char then sum(tr) end end
    return v
end

-- Tooltip-Text: "Kosten 2s (Ø 1s 50c)" bzw. "Kosten 2s", nil ohne Posten (char wie bei C.Info)
function C.Text(id, char)
    local info = C.Info(id, char)
    if not info then return nil end
    local nxt = ns.Money(math.floor(info.next + 0.5))
    if math.abs(info.avg - info.next) < 0.5 then return L.COST_TT:format(nxt) end
    return L.COST_TT_AVG:format(nxt, ns.Money(math.floor(info.avg + 0.5)))
end

---------------------------------------------------------------------------
-- Tagesverlauf eines Gegenstands (ab 0.9, Reiter "Gegenstand", Konzept Peon_Ledger_Gegenstand.md G4)
---------------------------------------------------------------------------
-- Tag wie in Brokers Daten (Mitternacht nach PC-Uhr), damit beide Diagramme dieselben Tage haben
function C.DayOf(t)
    local d = date("*t", t or time())
    return math.floor(time({ year = d.year, month = d.month, day = d.day, hour = 12 }) / 86400)
end

-- Rueckgabe { days = { [Tag] = { n, avg, loot, buyN, buyV, sellN, sellV } }, first, last }; n/avg = Stand am Ende des Tages
-- (Stueck mit Posten inkl. "unterwegs", Kosten Ø je Stueck), buy/sell: Stueck und Gold (Preis je Stueck = V / N).
-- char: nil = eingeloggter Charakter, "*" = alle. Neu gerechnet bei jedem Aufruf (nur fuer den gezeigten Gegenstand).
function C.ItemDays(id, char)
    char = char or ns.CharName()
    local days, first, last = {}, nil, nil
    local function Mine(c) return char == "*" or c == char end
    local function Stand(st)
        local n, v = 0, 0
        local function add(q) for _, lot in ipairs(q or {}) do n = n + lot.n; v = v + lot.n * lot.c end end
        for c, x in pairs(st.chars) do if Mine(c) then add(x.lots[id]) end end
        for c, tr in pairs(st.transit) do if Mine(c) then add(tr[id]) end end
        return n, n > 0 and v / n or nil
    end
    local function D(day)
        local r = days[day]
        if not r then r = {}; days[day] = r end
        if not first or day < first then first = day end
        if not last or day > last then last = day end
        return r
    end
    local st0 = C.Replay(function(st, e)
        if e.id ~= id then return end
        local r = D(C.DayOf(e.t))
        r.n, r.avg = Stand(st)
        if e.start or not Mine(e.c) then return end
        local k, n, m = e.k, e.n or 0, e.m or 0
        if k == "loot" and n > 0 then r.loot = (r.loot or 0) + n
        elseif (k == "ahbuy" or k == "vendor" or k == "buyback") and n > 0 then
            local res = st.res[e]
            local unit = res and res.unit
            if Num(unit) and unit > 0 then r.buyN, r.buyV = (r.buyN or 0) + n, (r.buyV or 0) + unit * n end
        elseif k == "ahsold" and m > 0 then
            local q = e.q or 1
            local gross = Num(e.gross) and e.gross or m
            r.sellN, r.sellV = (r.sellN or 0) + q, (r.sellV or 0) + gross
        elseif k == "vendor" and n < 0 and m > 0 then
            r.sellN, r.sellV = (r.sellN or 0) + (-n), (r.sellV or 0) + m
        end
    end)
    -- heute: aktueller Stand (auch ohne Bewegung heute)
    local n, avg = Stand(st0)
    if n > 0 or first then
        local r = D(C.DayOf(time()))
        r.n, r.avg = n, avg
    end
    return { days = days, first = first, last = last }
end

