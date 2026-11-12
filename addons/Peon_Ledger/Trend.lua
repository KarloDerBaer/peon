-- Peon_Ledger - Trend.lua
-- Verlauf von Gold, Vermoegen und Handelsgewinn fuer das Diagramm der Uebersicht (ab 0.14.5, Wunsch KarloDerBaer).
-- Gold und Vermoegen (alle Charaktere des Realms) werden als Stand gemerkt, nur bei Ereignissen (Einloggen,
-- Goldaenderung, Taschen, Fenster), hoechstens einmal je Minute:
--   realms[Realm].trend = { { t, g = Gold, w = Vermoegen oder nil ohne Broker }, ... }  (aelteste zuerst)
-- Ausduennen beim Einloggen: aelter als 1 Tag hoechstens ein Stand je Stunde, aelter als 7 Tage einer je Tag.
-- Der Handelsgewinn kommt aus den Bewegungen (Cost.Result), aufsummiert ab dem Beginn des Zeitraums.

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

-- Vermoegen aller Charaktere (nil ohne Broker)
function TR.Worth()
    if not ns.HasBroker() or not ns.Overview then return nil end
    local cache, sum = {}, 0
    for _, c in pairs(ns.Inventory.RealmData().chars) do
        local w = ns.Overview.Worth(c, cache)
        if w then sum = sum + w end
    end
    return sum
end

function TR.Record(force, now)
    now = now or time()
    local list = TR.List()
    local last = list[#list]
    if not force and last and now - (last.t or 0) < TR.MIN_GAP then return false end
    local g = ns.Inventory.TotalMoney()
    if not Num(g) then return false end
    local ok, w = pcall(TR.Worth)
    local e = { t = now, g = g, w = ok and Num(w) and math.floor(w + 0.5) or nil }
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
            local r = ns.Cost.Result(e)
            if r and r.sale then out[#out + 1] = { t = e.t or 0, p = r.profit or 0 }
            elseif r and r.general then out[#out + 1] = { t = e.t or 0, p = -r.general } end
        end
    end
    TR.tradeCache, TR.tradeDirty = out, false
    return out
end

-- Reihen fuer einen Zeitraum: { n, from, step, ends = { t }, gold = {}, worth = {}, trade = {} }
function TR.Series(key, now)
    now = now or time()
    local def = TR.RANGES[1]
    for _, d in ipairs(TR.RANGES) do if d.key == key then def = d end end
    local list = TR.List()
    local trades = TR.TradeEvents()
    local from
    if def.span > 0 then
        from = now - def.span
    else
        from = list[1] and list[1].t or now - 86400
        local m = ns.Moves.List()[1]
        if m and (m.t or now) < from then from = m.t end
        if now - from < 86400 then from = now - 86400 end
    end
    local n = def.points
    local step = (now - from) / n
    local res = { n = n, from = from, step = step, ends = {}, gold = {}, worth = {}, trade = {}, key = def.key }
    local si, cur = 1, nil
    local ti, sum = 1, 0
    while trades[ti] and trades[ti].t < from do ti = ti + 1 end
    for i = 1, n do
        local te = from + i * step
        res.ends[i] = te
        while list[si] and (list[si].t or 0) <= te do cur = list[si]; si = si + 1 end
        if cur then res.gold[i] = cur.g; res.worth[i] = cur.w end
        while trades[ti] and trades[ti].t <= te do sum = sum + trades[ti].p; ti = ti + 1 end
        res.trade[i] = sum
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
