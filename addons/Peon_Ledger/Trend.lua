-- Peon_Ledger - Trend.lua
-- Verlauf von Gold, AH-Erloes und Handelsgewinn fuer das Diagramm der Uebersicht (ab 0.14.5, Wunsch KarloDerBaer).
-- Gold (alle Charaktere des Realms) wird als Stand gemerkt, nur bei Ereignissen (Einloggen, Goldaenderung, Taschen,
-- Fenster), hoechstens einmal je Minute:
--   realms[Realm].trend = { { t, g = Gold, c = { [Name] = Gold } }, ... }  (aelteste zuerst)
-- Ab 0.18 (Konzept Peon_Ledger_Schlank.md Abschnitt 4) ohne Vermoegen (w, aeltere Staende behalten es), dafuer das
-- Gold je Charakter (c) fuer die Linien je Charakter und die Spalte "24 Std." der Uebersicht.
-- Ausduennen beim Einloggen: aelter als 1 Tag hoechstens ein Stand je Stunde, aelter als 7 Tage einer je Tag.
-- Handelsgewinn (Cost.Result) und AH-Erloes (Rechnungen, ahsold) kommen aus den Bewegungen, aufsummiert ab dem
-- Beginn des Zeitraums.

local ADDON_NAME, ns = ...
local mod = ns.mod

local TR = {}
ns.Trend = TR

TR.MIN_GAP = 60          -- Sekunden zwischen zwei Messungen
TR.SLOT = 15 * 60        -- innerhalb von 15 Minuten wird der letzte Stand ersetzt
-- Zeitraeume: Schluessel, Dauer (Sekunden, 0 = alles), Zahl der Punkte
TR.RANGES = {
    { key = "d1",  span = 86400,       points = 24 },
    { key = "d7",  span = 7 * 86400,   points = 28 },
    { key = "d30", span = 30 * 86400,  points = 30 },
    { key = "d90", span = 90 * 86400,  points = 45 },
    { key = "all", span = 0,           points = 60 },
}

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

function TR.List()
    local r = ns.Inventory.RealmData()
    if type(r.trend) ~= "table" then r.trend = {} end
    return r.trend
end

-- Gold je Charakter (nur bekannte Staende)
function TR.CharMoney()
    local out = {}
    for name, c in pairs(ns.Inventory.RealmData().chars) do
        if Num(c.money) then out[name] = c.money end
    end
    return out
end

function TR.Record(force, now)
    now = now or time()
    local list = TR.List()
    local last = list[#list]
    if not force and last and now - (last.t or 0) < TR.MIN_GAP then return false end
    local g = ns.Inventory.TotalMoney()
    if not Num(g) then return false end
    local e = { t = now, g = g, c = TR.CharMoney() }
    if last and now - (last.t or 0) < TR.SLOT and math.floor((last.t or 0) / TR.SLOT) == math.floor(now / TR.SLOT) then
        list[#list] = e
    else
        list[#list + 1] = e
    end
    return true
end

-- aeltere Staende ausduennen: aelter als 1 Tag einer je Stunde, aelter als 7 Tage einer je Tag (jeweils der letzte)
function TR.Thin(now)
    now = now or time()
    local list = TR.List()
    local out, seen = {}, {}
    for i = #list, 1, -1 do
        local e = list[i]
        local age = now - (e.t or 0)
        local key
        if age > 7 * 86400 then key = "d" .. math.floor((e.t or 0) / 86400)
        elseif age > 86400 then key = "h" .. math.floor((e.t or 0) / 3600) end
        if not key or not seen[key] then
            if key then seen[key] = true end
            table.insert(out, 1, e)
        end
    end
    ns.Inventory.RealmData().trend = out
    return #list - #out
end

-- Handelsgewinn als Zeitreihe: Liste { t, p } (p = Gewinn dieser Bewegung), zwischengespeichert bis zur
-- naechsten Bewegung
function TR.TradeEvents()
    if TR.tradeCache and not TR.tradeDirty then return TR.tradeCache end
    local out = {}
    if ns.Cost then
        for _, e in ipairs(ns.Moves.List()) do
            -- ab 0.15: nur der Handelsteil (Cost.TradeProfit), Beute zaehlt nicht
            local p = ns.Cost.TradeProfit(ns.Cost.Result(e))
            if p ~= 0 then out[#out + 1] = { t = e.t or 0, p = p } end
        end
    end
    TR.tradeCache, TR.tradeDirty = out, false
    return out
end

-- AH-Erloes als Zeitreihe (ab 0.18): Liste { t, p } aus den Rechnungen (Verkauf im Auktionshaus, Gold netto)
function TR.AHEvents()
    if TR.ahCache and not TR.ahDirty then return TR.ahCache end
    local out = {}
    for _, e in ipairs(ns.Moves.List()) do
        if e.k == "ahsold" and Num(e.m) and e.m > 0 then out[#out + 1] = { t = e.t or 0, p = e.m } end
    end
    TR.ahCache, TR.ahDirty = out, false
    return out
end

-- Gold vor 24 Stunden (ab 0.18): Aenderung, hoechster und tiefster Stand im Zeitraum, Beginn der Messung.
-- name = ein Charakter (nil = alle). Ohne Stand von vor 24 Stunden zaehlt der erste Stand danach (since > now - 24h).
-- nil, wenn es keinen Stand gibt.
function TR.Change(name, now, span)
    now = now or time()
    span = span or 86400
    local from = now - span
    local list = TR.List()
    local function Val(e)
        if not e then return nil end
        if name then return type(e.c) == "table" and Num(e.c[name]) and e.c[name] or nil end
        return Num(e.g) and e.g or nil
    end
    local cur
    if name then
        local c = ns.Inventory.RealmData().chars[name]
        cur = c and Num(c.money) and c.money or nil
    else
        cur = ns.Inventory.TotalMoney()
        if not Num(cur) then cur = nil end
    end
    local base, since
    local hi, lo = cur, cur
    for _, e in ipairs(list) do
        local v = Val(e)
        if v then
            local t = e.t or 0
            if t <= from then
                base, since = v, from
            elseif t <= now then
                if not base then base, since = v, t end
                hi = math.max(hi or v, v); lo = math.min(lo or v, v)
            end
        end
    end
    if base then hi = math.max(hi or base, base); lo = math.min(lo or base, base) end
    if not base or not cur then return nil end
    return cur - base, hi, lo, since
end

-- Erster Zeitpunkt mit Daten: erster Stand oder erste Bewegung
function TR.First(now)
    local list = TR.List()
    local first = list[1] and list[1].t or nil
    local m = ns.Moves.List()[1]
    if m and m.t and (not first or m.t < first) then first = m.t end
    return first or now or time()
end

-- Reihen fuer einen Zeitraum: { n, from, step, ends = { t }, gold = {}, ah = {}, trade = {}, chars = { [Name] = {} } }
-- Ab 0.14.6 (Wunsch KarloDerBaer): Das Diagramm beginnt links beim ersten Wert und fuellt sich nach rechts.
-- Erst wenn der Zeitraum voll ist, wandert es mit. Punkte nach "jetzt" bleiben leer.
function TR.Series(key, now)
    now = now or time()
    local def = TR.RANGES[1]
    for _, d in ipairs(TR.RANGES) do if d.key == key then def = d end end
    local list = TR.List()
    local trades = TR.TradeEvents()
    local first = TR.First(now)
    local from, span
    if def.span > 0 then
        span = def.span
        from = math.max(now - span, first)
    else
        from = first
        span = math.max(now - from, 86400)
    end
    local n = def.points
    local step = span / n
    local ahs = TR.AHEvents()
    local res = { n = n, from = from, step = step, ends = {}, gold = {}, trade = {}, ah = {}, chars = {}, key = def.key }
    for name in pairs(ns.Inventory.RealmData().chars) do res.chars[name] = {} end
    local si, cur = 1, nil
    local ti, sum = 1, 0
    local ai, asum = 1, 0
    while trades[ti] and trades[ti].t < from do ti = ti + 1 end
    while ahs[ai] and ahs[ai].t < from do ai = ai + 1 end
    res.now = now
    for i = 1, n do
        local te = from + i * step
        res.ends[i] = te
        local ts = te - step
        if ts < now then
            -- letzter Punkt bis "jetzt": der aktuelle Stand
            local upto = math.min(te, now)
            while list[si] and (list[si].t or 0) <= upto do cur = list[si]; si = si + 1 end
            if cur then
                res.gold[i] = cur.g
                if type(cur.c) == "table" then
                    for name, v in pairs(cur.c) do if res.chars[name] then res.chars[name][i] = v end end
                end
            end
            while trades[ti] and trades[ti].t <= upto do sum = sum + trades[ti].p; ti = ti + 1 end
            while ahs[ai] and ahs[ai].t <= upto do asum = asum + ahs[ai].p; ai = ai + 1 end
            res.trade[i] = sum
            res.ah[i] = asum
            res.last = i
        end
    end
    return res
end

function TR.Init()
    local function Rec() mod:Call("Verlauf Gold", TR.Record) end
    pcall(mod.RegisterEvent, mod, "PLAYER_MONEY", Rec)
    pcall(mod.RegisterEvent, mod, "BAG_UPDATE_DELAYED", Rec)
end

function TR.OnLogin()
    TR.Thin()
    local CT = rawget(_G, "C_Timer")
    if CT and CT.After then CT.After(30, function() mod:Call("Verlauf Gold", TR.Record, true) end) end
end
