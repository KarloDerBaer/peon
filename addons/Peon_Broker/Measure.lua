-- Peon_Broker - Measure.lua
-- Stufe 2, H2 (ab 0.66, Konzept Peon_Broker_Neuaufbau.md, Abschnitt 6.1, Reiter Fokus): laufende Messung fuer genau
-- einen Gegenstand. Radar.lua fragt den Gegenstand im Fokus alle focusEvery Sekunden ab (Vorgabe 5, 3 bis 30) und
-- gibt jede Antwort hierher (M.Add). Aus zwei Abfragen nacheinander entsteht mit den Auktionsnummern:
--   verkauft     Menge eines Angebots kleiner, oder Angebot vorzeitig weg und ein guenstigeres stand in beiden
--                Abfragen nicht mehr (man kauft immer von unten)
--   abgebrochen  Angebot vorzeitig weg, waehrend ein guenstigeres stehen blieb
--   abgelaufen   Restzeit war kleiner als der Abstand (zaehlt nicht)
--   neu          Nummer nur in der zweiten Abfrage
-- Gleiche Regeln wie Sales.lua (Absatz), hier nur fuer kurze Abstaende und mit Raten je Minute.
--
-- Messwerte (Fenster der letzten M.WINDOW Sekunden):
--   Abfluss            verkaufte Stueck je Minute
--   Zufluss unter Ziel neu eingestellte Stueck unter dem Zielpreis je Minute
--   Menge unter Ziel   waechst, bleibt, schrumpft (Vergleich erste und letzte Abfrage im Fenster)
--   Guenstigster Preis faellt, bleibt, steigt
-- Ziel: Zielpreis der Chance (Aufkauf: naechste Stufe, Haendler: Haendlerpreis). Ohne Chance der Preis der zweiten
-- Stufe bei Beginn der Messung (Startwert, Entscheidungen 12.11.2026).
--
-- Urteil (Startwerte, Entscheidungen 12.11.2026): erst nach M.FIRST Sekunden, bis M.SURE Sekunden "vorlaeufig".
--   Finger weg  Menge unter Ziel waechst oder guenstigster Preis faellt
--   Kaufen      Abfluss groesser als M.MORE x Zufluss unter Ziel, Menge waechst nicht, Preis faellt nicht
--   Abwarten    sonst (kaum Bewegung, oder Zufluss und Abfluss etwa gleich)

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local M = {}
ns.Measure = M

M.WINDOW = 600     -- Sekunden: Fenster fuer Raten und Trends
M.FIRST  = 30      -- Sekunden bis zum ersten (vorlaeufigen) Urteil
M.SURE   = 120     -- Sekunden bis zum Urteil ohne "vorlaeufig"
M.MORE   = 1.2     -- Abfluss muss mehr als 20 % ueber dem Zufluss unter Ziel liegen ("etwa gleich" bis dahin)
M.GROW   = 0.10    -- Menge unter Ziel waechst / schrumpft ab 10 % (und mindestens 1 Stueck)
M.KEEP   = 240     -- hoechstens so viele Abfragen merken (Diagramm)
M.TOL    = 5       -- Sekunden Toleranz fuer abgelaufene Angebote

-- ab 0.70: Grenzen aus den Einstellungen des Fokus (Fenster Einstellungen)
function M.Sync()
    local db = mod.db
    M.WINDOW = (tonumber(db.focusWindow) or 10) * 60
    M.FIRST  = tonumber(db.focusFirst) or 30
    M.SURE   = math.max(M.FIRST, tonumber(db.focusSure) or 120)
    M.MORE   = 1 + (tonumber(db.focusMore) or 20) / 100
    M.GROW   = (tonumber(db.focusGrow) or 10) / 100
end

M.cur = nil        -- { key, t0, target, samples = { { t, offers, min, under, partial, maxP } }, pairs = { { t, gap, sold, newUnder, cancelled } } }

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Now() return GetTime and GetTime() or time() end

-- Zielpreis der Chance im Fokus (nil = keine Chance)
function M.ChanceTarget(key)
    -- ab 0.70: eigenes Ziel im Fokus geht vor
    local F = ns.Focus
    local own = F and F.ManualTarget and F.ManualTarget(key)
    if Num(own) and own > 0 then return own end
    local R = ns.Radar
    local d = R and (R.entries[key])
    if d and Num(d.ref) and d.ref > 0 then return d.ref end
    -- ab 0.67 (H3): eingestellter Posten, der Fokus bewacht ihn (Menge unter meinem Preis)
    local lot = ns.Lots and ns.Lots.Posted(key)
    if lot and Num(lot.posted.price) and lot.posted.price > 0 then return lot.posted.price end
    return nil
end

-- Neue Messung fuer key (alles vorherige weg)
function M.Start(key)
    M.cur = { key = key, t0 = nil, samples = {}, pairs = {} }
end

function M.Stop()
    M.Save()
    M.cur = nil
end

-- Angebote einer Antwort als Tabelle Nummer -> { q, p, secs }
local function OfferMap(rows)
    local map, n, maxP = {}, 0, 0
    for _, o in ipairs(rows.offers or {}) do
        if Num(o.id) and Num(o.q) and o.q > 0 and Num(o.p) and o.p > 0 then
            map[o.id] = { q = o.q, p = o.p, secs = Num(o.secs) and o.secs or nil }
            n = n + 1
            if o.p > maxP then maxP = o.p end
        end
    end
    return map, n, maxP
end

-- Vergleich zweier Abfragen: verkauft, neu unter Ziel, abgebrochen
function M.Compare(A, B, target)
    local gap = B.t - A.t
    local cap = math.huge
    if A.partial then cap = math.min(cap, A.maxP) end
    if B.partial then cap = math.min(cap, B.maxP) end
    local sold, cancelled, newUnder, newAll = 0, 0, 0, 0
    local anchor, gone = nil, {}
    for id, a in pairs(A.offers) do
        if a.p <= cap then
            local b = B.offers[id]
            if b then
                if b.q < a.q then sold = sold + (a.q - b.q) end
                if b.q > 0 and (not anchor or a.p < anchor) then anchor = a.p end
            else
                gone[#gone + 1] = a
            end
        end
    end
    for _, a in ipairs(gone) do
        if a.secs and a.secs <= gap + M.TOL then
            -- abgelaufen: zaehlt nicht
        elseif anchor and a.p > anchor then
            cancelled = cancelled + a.q
        else
            sold = sold + a.q
        end
    end
    for id, b in pairs(B.offers) do
        if b.p <= cap and not A.offers[id] then
            newAll = newAll + b.q
            if target and b.p < target then newUnder = newUnder + b.q end
        end
    end
    return { t = B.t, gap = gap, sold = sold, cancelled = cancelled, newUnder = newUnder, newAll = newAll }
end

-- ab 0.74: Massenware ueber die Preisstufen vergleichen statt ueber Auktionsnummern. Im Spiel sprang der Abfluss,
-- obwohl sich an den Stufen nichts aenderte: Die Nummern der Massenware-Angebote sind offenbar nicht von Abfrage zu
-- Abfrage gleich, jede neue Nummer zaehlte als "alt weg, neu da". Je Preisstufe zaehlt jetzt nur die Menge:
--   weniger Stueck, solange alle guenstigeren Stufen auch weniger wurden  -> verkauft (man kauft von unten)
--   weniger Stueck ueber einer Stufe, die stehen blieb                     -> abgebrochen
--   mehr Stueck                                                          -> neu (unter dem Ziel: Zufluss)
-- Kauf und neues Angebot im selben Abstand auf derselben Stufe heben sich auf. Bei kurzen Abstaenden selten.
function M.CompareLevels(A, B, target)
    local gap = B.t - A.t
    local cap = math.huge
    if A.partial then cap = math.min(cap, A.maxP) end
    if B.partial then cap = math.min(cap, B.maxP) end
    local prices = {}
    for p in pairs(A.levels) do if p <= cap then prices[#prices + 1] = p end end
    table.sort(prices)
    local sold, cancelled, newUnder, newAll, intact = 0, 0, 0, 0, false
    for _, p in ipairs(prices) do
        local a, b = A.levels[p], B.levels[p] or 0
        if b >= a then
            intact = true
        else
            if intact then cancelled = cancelled + (a - b) else sold = sold + (a - b) end
            if b > 0 then intact = true end
        end
    end
    for p, b in pairs(B.levels) do
        if p <= cap then
            local a = A.levels[p] or 0
            if b > a then
                newAll = newAll + (b - a)
                if target and p < target then newUnder = newUnder + (b - a) end
            end
        end
    end
    return { t = B.t, gap = gap, sold = sold, cancelled = cancelled, newUnder = newUnder, newAll = newAll, byLevels = true }
end

-- Antwort auf eine Abfrage im Fokus. rows = Preisstufen mit offers (Live.lua), t = Zeit (GetTime)
function M.Add(key, rows, t)
    if type(rows) ~= "table" or key == nil then return end
    if not M.cur or M.cur.key ~= key then M.Start(key) end
    local c = M.cur
    t = t or Now()
    local offers, n, maxP = OfferMap(rows)
    if n == 0 and #ns.Data.Available(rows) > 0 then return end   -- ohne Auktionsnummern laesst sich nichts vergleichen
    local lv = ns.Data.Available(rows)
    if not c.target then
        c.target = M.ChanceTarget(key) or (lv[2] and lv[2].price) or (lv[1] and lv[1].price) or nil
        c.ownTarget = M.ChanceTarget(key) == nil
    end
    local target = M.ChanceTarget(key) or c.target
    c.target = target
    local under = 0
    for _, l in ipairs(lv) do if target and l.price < target then under = under + l.qty end end
    local s = { t = t, offers = offers, min = lv[1] and lv[1].price or nil, under = under, partial = rows.partial and true or false, maxP = maxP }
    if rows.commodity then   -- ab 0.74: Preisstufen fuer den Vergleich (alle Stueck, auch eigene)
        local levels, top = {}, 0
        for _, r in ipairs(rows) do
            if Num(r.price) and Num(r.qty) and r.qty > 0 then
                levels[r.price] = (levels[r.price] or 0) + r.qty
                if r.price > top then top = r.price end
            end
        end
        s.levels = levels
        if rows.partial then s.maxP = top end
    end
    local prev = c.samples[#c.samples]
    if prev and t > prev.t then
        if prev.levels and s.levels then c.pairs[#c.pairs + 1] = M.CompareLevels(prev, s, target)
        else c.pairs[#c.pairs + 1] = M.Compare(prev, s, target) end
    end
    c.t0 = c.t0 or t
    c.samples[#c.samples + 1] = s
    while #c.samples > M.KEEP do table.remove(c.samples, 1) end
    while #c.pairs > M.KEEP do table.remove(c.pairs, 1) end
    -- alte Angebotslisten brauchen nur die letzten beiden Abfragen
    for i = 1, #c.samples - 2 do c.samples[i].offers, c.samples[i].levels = nil, nil end
end

-- Messwerte. Rueckgabe nil (noch keine Messung) oder
-- { key, target, elapsed, n, out (je Min.), inUnder (je Min.), under, underTrend ("grow"/"same"/"shrink"),
--   min, minTrend ("fall"/"same"/"rise"), every (tatsaechlicher Abstand in Sek.), moved }
function M.Values(now)
    M.Sync()
    local c = M.cur
    if not c or #c.samples == 0 then return nil end
    now = now or c.samples[#c.samples].t
    local from = now - M.WINDOW
    local sold, inUnder, secs, moved = 0, 0, 0, 0
    for _, p in ipairs(c.pairs) do
        if p.t > from then
            sold, inUnder, secs = sold + p.sold, inUnder + p.newUnder, secs + p.gap
            moved = moved + p.sold + p.newAll + p.cancelled
        end
    end
    local first
    for _, s in ipairs(c.samples) do if s.t >= from then first = s; break end end
    first = first or c.samples[1]
    local last = c.samples[#c.samples]
    local v = { key = c.key, target = c.target, ownTarget = c.ownTarget, elapsed = last.t - (c.t0 or last.t), n = #c.samples,
                under = last.under, min = last.min, moved = moved, sold = sold }
    local mins = secs / 60
    v.out = mins > 0 and sold / mins or 0
    v.inUnder = mins > 0 and inUnder / mins or 0
    local du = last.under - first.under
    if du > 0 and du >= math.max(1, first.under * M.GROW) then v.underTrend = "grow"
    elseif du < 0 and -du >= math.max(1, first.under * M.GROW) then v.underTrend = "shrink"
    else v.underTrend = "same" end
    if Num(first.min) and Num(last.min) and last.min < first.min then v.minTrend = "fall"
    elseif Num(first.min) and Num(last.min) and last.min > first.min then v.minTrend = "rise"
    else v.minTrend = "same" end
    local np = #c.pairs
    if np > 0 then
        local k, sum = 0, 0
        for i = math.max(1, np - 5), np do sum, k = sum + c.pairs[i].gap, k + 1 end
        v.every = sum / k
    end
    return v
end

-- Urteil aus den Messwerten: "wait_first" (noch zu frueh), "buy", "wait", "away"; Satz; vorlaeufig
function M.Verdict(v)
    M.Sync()
    if not v or v.n < 2 or v.elapsed < M.FIRST then return "first", L.MEASURE_W_FIRST:format(M.FIRST), true end
    local early = v.elapsed < M.SURE
    if v.underTrend == "grow" then return "away", L.MEASURE_W_GROW, early end
    if v.minTrend == "fall" then return "away", L.MEASURE_W_FALL, early end
    if (v.moved or 0) == 0 then return "wait", L.MEASURE_W_QUIET, early end
    if v.out > v.inUnder * M.MORE and v.out > 0 then return "buy", L.MEASURE_W_BUY, early end
    return "wait", L.MEASURE_W_EVEN, early
end

-- Verkaufsdauer aus dem gemessenen Abfluss (Stunden), erst ab M.SURE Sekunden und mit Abfluss
function M.SellHours(qty)
    local v = M.Values()
    if not v or v.elapsed < M.SURE or not v.out or v.out <= 0 or not Num(qty) then return nil end
    return qty / (v.out * 60)
end

-- Reihen fuer das Diagramm: Menge unter Ziel und guenstigster Preis je Abfrage
function M.Series()
    local c = M.cur
    if not c or #c.samples < 2 then return nil end
    local under, mins = {}, {}
    for i, s in ipairs(c.samples) do under[i], mins[i] = s.under, s.min end
    return #c.samples, under, mins
end

-- Letzte Messung merken (fuer unterwegs: "Stand der letzten Messung", nur lesen)
function M.Save()
    local v = M.Values()
    if not v then return end
    local verdict, _, early = M.Verdict(v)
    mod.acc.focusMeasure = { key = v.key, t = time and time() or 0, out = v.out, inUnder = v.inUnder, under = v.under,
        underTrend = v.underTrend, min = v.min, minTrend = v.minTrend, target = v.target, verdict = verdict,
        early = early or nil, elapsed = math.floor(v.elapsed), every = v.every }
end

-- Gemerkte Messung zu key (oder nil)
function M.Saved(key)
    local s = mod.acc.focusMeasure
    if type(s) == "table" and s.key == key then return s end
    return nil
end
