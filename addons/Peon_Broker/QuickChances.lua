-- Peon_Broker - QuickChances.lua
-- Ab 0.119 (Konzept Peon_Broker_Chancen_Schnellkauf.md, KarloDerBaer 19.11.2026): Chancen der Art Schnellkauf.
--   Vorschlaege  Massenware aus dem juengsten Stand des Markts. In markets[...].items steht schon der neuere Wert aus
--                eigenem Komplettscan oder Stand des Managers (Data.ApplyManager). Guenstigster Preis mindestens
--                qcMinPrice, die qcCount mit der groessten Menge. Die Liste bleibt bis zum naechsten Stand, bis sich
--                eine Einstellung aendert oder bis "Neu vorschlagen".
--   Pruefung     ein Gegenstand nach dem anderen, je Gegenstand qcProbes Abfragen direkt hintereinander im Takt des
--                Radars. Je Paar zaehlen Einstellungen, Kaeufe und Preisspruenge (Measure.Pair) und fremde
--                Lockangebote (Quick.NewBaits). Bewertet wird gleitend ueber die letzten QC.HIST Pruefungen desselben
--                Gegenstands mit den Grenzen der Marktbewegung im Schnellkauf (Quick.MoveClass). Mit nur einer
--                Pruefung ist das Ergebnis vorlaeufig ("?").
--   Reihenfolge  erste Runde nach Menge, danach lebhafte (meiste Ereignisse zuerst), ungepruefte, maessige, ruhige.
--                Ab 0.120 (KarloDerBaer 19.11.2026) wartet ein Gegenstand, der nicht lebhaft ist, bis zur naechsten
--                Pruefung: je ruhiger, desto laenger, hoechstens qcWaitMax Minuten (QC.Wait). Lebhafte sind immer dran.
--   Listen       Reiter Chancen, Unterreiter Schnellkauf (Vorschlaege), und Beobachten, Unterreiter Schnellkauf
--                (Gegenstaende mit Werten des Schnellkaufs). Geprueft wird nur die Liste, die zu sehen ist (QC.Source).
-- Die Abfragen schickt Radar.lua (R.NextKey Art "probe", QC.Send), die Antworten kommen ueber R.Apply (QC.OnAnswer).
-- Ausgeblendete Vorschlaege: PeonBrokerDB.quickHide[Markt][Schluessel] = time().
-- Ab 0.126 (KarloDerBaer 20.11.2026): Die letzten QC.HIST Pruefungen je Gegenstand bleiben gespeichert,
-- PeonBrokerDB.quickMove[Markt][Schluessel] = { p = { Pruefungen }, t = time() }. Nach Logout oder /reload zeigt die
-- Bewegung den letzten Stand, ab QC.OLD Sekunden blass (v.old). Gespeicherte Gegenstaende sind sofort wieder dran.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local QC = {}
ns.QuickChances = QC

QC.HIST = 3          -- gleitend: so viele Pruefungen eines Gegenstands zaehlen zusammen
QC.EXTRA = 3         -- so viele Abfragen ohne Antwort darf eine Pruefung mehr schicken, dann ist der naechste dran
QC.WAIT_LOAD = 30    -- so oft auf die Daten des Gegenstands warten (Takt des Radars 0,1 Sek.), dann der naechste
QC.DOTS_MAX = 8      -- bis zu so vielen Abfragen je Pruefung Punkte, darueber "3/12"
QC.STALE = 10        -- Sekunden ohne Abfrage: angefangene Pruefung verwerfen
QC.RANK = { high = 1, none = 2, mid = 3, low = 4 }
QC.OLD = 6 * 3600    -- ab 0.126: gespeicherte Bewegung gilt ab so vielen Sekunden als alt (blass)

QC.res = {}          -- [Schluessel] = { probes = { { secs, nNew, nSold, jumps, inAll, sold, baits, n, t } }, min, qty, at, last }
QC.run = nil         -- laufende Pruefung { key, got, sent, wait, answered, prev, secs, nNew, nSold, jumps, inAll, sold, baits }
QC.queue = {}        -- noch offene Gegenstaende dieser Runde
QC.src = nil         -- "chances" oder "watch": Liste, fuer die die Runde laeuft
QC.round = 0         -- Gegenstaende in dieser Runde
QC.sortStamp = 0     -- zaehlt hoch, wenn eine Pruefung fertig ist (dann darf die Liste neu sortieren)
QC.paused = false    -- Knopf Anhalten im Reiter Chancen

local GREY, GREEN, ORANGE, WHITE = "|cff999999", "|cff60e060", "|cffff9933", "|cffffffff"
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Now() return GetTime and GetTime() or time() end
local function AHOpen() return ns.Scan.ahOpen and rawget(_G, "C_AuctionHouse") ~= nil end
local function Money(v) return ns.Tooltip.Money(v) end

function QC.On() return mod.db.chancesShowQ ~= false end
-- ab 0.140 (KarloDerBaer 26.11.2026): in Beobachten eigene Zahl (watchProbes, 1 bis 5, Vorgabe 3, Regler oben rechts).
-- Mit 1 Abfrage gibt es nur Preis und Menge, die Bewegung braucht mindestens 2.
function QC.WatchProbes() return math.max(1, math.min(5, math.floor(tonumber(mod.db.watchProbes) or 3))) end
function QC.Probes(src)
    src = src or QC.src or QC.Source()
    if src == "watch" then return QC.WatchProbes() end
    return math.max(2, math.floor(tonumber(mod.db.qcProbes) or 5))
end

---------------------------------------------------------------------------
-- Ausgeblendete Vorschlaege (je Markt)
---------------------------------------------------------------------------
function QC.HideStore(create)
    local acc, market = mod.acc, ns.MarketKey()
    if type(acc) ~= "table" or type(market) ~= "string" then return nil end
    if type(acc.quickHide) ~= "table" then
        if not create then return nil end
        acc.quickHide = {}
    end
    local s = acc.quickHide[market]
    if type(s) ~= "table" then
        if not create then return nil end
        s = {}
        acc.quickHide[market] = s
    end
    return s
end

function QC.Hidden(key)
    local s = QC.HideStore(false)
    return s ~= nil and s[key] ~= nil
end

function QC.HiddenCount()
    local n = 0
    for _ in pairs(QC.HideStore(false) or {}) do n = n + 1 end
    return n
end

function QC.Hide(key)
    local s = QC.HideStore(true)
    if not s or key == nil then return false end
    s[key] = time()
    QC.cands = nil
    QC.Changed(true)
    return true
end

-- alle ausgeblendeten dieses Markts wieder vorschlagen
function QC.Unhide()
    local acc = mod.acc
    if type(acc) == "table" and type(acc.quickHide) == "table" then
        acc.quickHide[ns.MarketKey() or ""] = nil
        if next(acc.quickHide) == nil then acc.quickHide = nil end
    end
    QC.cands = nil
    QC.Changed(true)
end

---------------------------------------------------------------------------
-- Vorschlaege
---------------------------------------------------------------------------
-- Rueckgabe { { key, qty, min }, ... }, groesste Menge zuerst. force = neu rechnen (Knopf "Neu vorschlagen")
function QC.Candidates(force)
    local D = ns.Data
    local market = D.Market()
    if not market then QC.cands = nil; return {} end
    local minP = math.max(0, math.floor(tonumber(mod.db.qcMinPrice) or 100))
    local count = math.max(1, math.floor(tonumber(mod.db.qcCount) or 10))
    local stamp = table.concat({ tostring(ns.MarketKey()), tostring(D.DataAt(market) or 0), minP, count, QC.HiddenCount() }, ":")
    if not force and QC.cands and QC.candStamp == stamp then return QC.cands end
    local all = {}
    for key, e in pairs(market.items) do
        if type(key) == "number" and type(e) == "table" and not e.gone and Num(e.m) and e.m >= minP and Num(e.q) and e.q > 0 then
            all[#all + 1] = { key = key, qty = e.q, min = e.m }
        end
    end
    table.sort(all, function(a, b)
        if a.qty ~= b.qty then return a.qty > b.qty end
        return a.key < b.key
    end)
    local hide = QC.HideStore(false) or {}
    local list = {}
    for _, c in ipairs(all) do
        if #list >= count then break end
        if not hide[c.key] and D.IsCommodity(c.key) then list[#list + 1] = c end
    end
    QC.cands, QC.candStamp = list, stamp
    QC.candAt, QC.candMgr = D.DataAt(market), market.mgrAt ~= nil and market.mgrAt == D.DataAt(market) and (market.lastScan or 0) < market.mgrAt
    return list
end

function QC.IsCandidate(key)
    for _, c in ipairs(QC.cands or {}) do if c.key == key then return true end end
    return false
end

-- Knopf "Neu vorschlagen": Liste neu, Runde neu (Ergebnisse bleiben)
function QC.Renew()
    QC.Candidates(true)
    QC.queue, QC.run, QC.round = {}, nil, 0
    QC.sortStamp = QC.sortStamp + 1
    QC.Changed(true)
end

function QC.SetPaused(on)
    QC.paused = on and true or false
    if QC.paused then QC.run = nil end
    QC.Changed(true)
    if ns.Radar then ns.Radar.Wake() end
end

---------------------------------------------------------------------------
-- ab 0.126: gespeicherte Pruefungen (je Markt)
---------------------------------------------------------------------------
function QC.SaveStore(create)
    local acc, market = mod.acc, ns.MarketKey()
    if type(acc) ~= "table" or type(market) ~= "string" then return nil end
    if type(acc.quickMove) ~= "table" then
        if not create then return nil end
        acc.quickMove = {}
    end
    local s = acc.quickMove[market]
    if type(s) ~= "table" then
        if not create then return nil end
        s = {}
        acc.quickMove[market] = s
    end
    return s
end

-- Pruefungen eines Gegenstands speichern, Eintraege ueber dem Zeitraum (quickStatDays) fallen weg
function QC.Save(key, probes)
    local st = QC.SaveStore(true)
    if not st or key == nil then return end
    local now = time()
    local keep = (ns.QuickStats and ns.QuickStats.Days() or 14) * 86400
    for k, e in pairs(st) do
        if type(e) ~= "table" or not Num(e.t) or now - e.t > keep then st[k] = nil end
    end
    st[key] = { p = probes, t = now }
end

-- gespeicherte Pruefungen in QC.res holen (einmal je Sitzung und Gegenstand)
function QC.Load(key)
    if QC.res[key] then return QC.res[key] end
    local st = QC.SaveStore(false)
    local e = st and st[key]
    if type(e) ~= "table" or type(e.p) ~= "table" or #e.p == 0 then return nil end
    local probes = {}
    for _, p in ipairs(e.p) do if type(p) == "table" then probes[#probes + 1] = p end end
    QC.res[key] = { probes = probes, saved = true }
    return QC.res[key]
end

---------------------------------------------------------------------------
-- Ergebnis eines Gegenstands (gleitend ueber die letzten Pruefungen)
---------------------------------------------------------------------------
-- Rueckgabe nil (noch keine Pruefung) oder { class, early, ev, newPerMin, soldPerMin, jumpsPerMin, inPerMin,
-- outPerMin, baits, events, queries, secs, probes, at }
function QC.Result(key)
    local r = QC.res[key] or QC.Load(key)   -- ab 0.126 auch gespeichert
    if not (r and r.probes and #r.probes > 0) then return nil end
    local v = { secs = 0, nNew = 0, nSold = 0, jumps = 0, inAll = 0, sold = 0, baits = 0, queries = 0 }
    for _, p in ipairs(r.probes) do
        for k in pairs(v) do
            if k == "queries" then v.queries = v.queries + (p.n or 0) else v[k] = v[k] + (p[k] or 0) end
        end
    end
    if v.secs <= 0 then return nil end
    local mins = v.secs / 60
    v.newPerMin, v.soldPerMin, v.jumpsPerMin = v.nNew / mins, v.nSold / mins, v.jumps / mins
    v.inPerMin, v.outPerMin = v.inAll / mins, v.sold / mins
    v.ev = v.newPerMin + v.soldPerMin + v.jumpsPerMin
    v.events = v.nNew + v.nSold + v.jumps
    v.class = ns.Quick.MoveClass(v.newPerMin, v.ev)
    v.probes, v.early, v.at = #r.probes, #r.probes < 2, r.at
    -- ab 0.126: Zeitpunkt der juengsten Pruefung (time()), alt ab QC.OLD
    local newest
    for _, p in ipairs(r.probes) do if Num(p.t) and (not newest or p.t > newest) then newest = p.t end end
    v.stamp = newest
    v.old = newest ~= nil and time() - newest > QC.OLD
    return v
end

function QC.Rank(v) return QC.RANK[v and v.class or "none"] or 2 end

-- ab 0.120: Wartezeit bis zur naechsten Pruefung in Sekunden. Lebhaft und ungeprueft 0. Sonst gleitend nach dem Anteil
-- an der Grenze fuer lebhaft (0 = gar keine Bewegung, 1 = fast lebhaft): Wartezeit = qcWaitMax x (1 - Anteil),
-- mindestens 30 Sekunden. Vorlaeufige Ergebnisse (nur eine Pruefung) warten halb so lange.
QC.WAIT_MIN = 30
function QC.Wait(v)
    if not v or v.class == "high" then return 0 end
    local db = mod.db
    local needIn = math.max(1, tonumber(db.quickMoveIn) or 2)
    local needAll = math.max(1, tonumber(db.quickMoveAll) or 5)
    local share = math.min(1, (v.newPerMin or 0) / needIn, (v.ev or 0) / needAll)
    local max = math.max(1, tonumber(db.qcWaitMax) or 10) * 60
    local w = math.max(QC.WAIT_MIN, max * (1 - share))
    if v.early then w = w / 2 end
    return w
end

-- Sekunden bis der Gegenstand wieder dran ist (0 = jetzt)
function QC.DueIn(key)
    local res = QC.res[key]
    local v = QC.Result(key)
    if not (v and res and res.last) then return 0 end
    return math.max(0, QC.Wait(v) - (Now() - res.last))
end

---------------------------------------------------------------------------
-- Pruefung
---------------------------------------------------------------------------
-- Welche Liste wird gerade geprueft? "chances", "watch" oder nil
function QC.Source()
    local C, P = ns.Chances, ns.WatchPage
    if C and C.Shown() and C.Tab() == "quick" then return "chances" end
    if P and P.Shown() then return "watch" end   -- ab 0.135 (U3): Beobachten ist eine Liste
    return nil
end

function QC.Active()
    local src = QC.Source()
    return src ~= nil and AHOpen() and not (src == "chances" and QC.paused)
end

-- Gegenstaende der Liste, Reihenfolge der ersten Runde
function QC.Keys(src)
    local keys = {}
    if src == "watch" then
        local Wt, D = ns.Watch, ns.Data
        local qty = {}
        for key in pairs(Wt.Store()) do
            if ns.Buy.KnownKey(key) then   -- ab 0.135 (U3): die ganze Liste
                keys[#keys + 1] = key
                local e = D.Lookup(key)
                qty[key] = type(e) == "table" and Num(e.q) and e.q or 0
            end
        end
        table.sort(keys, function(a, b)
            if qty[a] ~= qty[b] then return qty[a] > qty[b] end
            return tostring(a) < tostring(b)
        end)
        return keys
    end
    if not QC.On() then return keys end
    for _, c in ipairs(QC.Candidates()) do keys[#keys + 1] = c.key end
    return keys
end

-- Reihenfolge einer Runde: lebhafte (meiste Ereignisse zuerst), ungepruefte, maessige, ruhige
-- ab 0.120 nur, wer wieder dran ist (QC.DueIn)
function QC.BuildQueue(src)
    local keys = {}
    local pos, info = {}, {}
    for i, k in ipairs(QC.Keys(src)) do
        if QC.DueIn(k) <= 0 then
            keys[#keys + 1] = k
            pos[k] = i
            local v = QC.Result(k)
            info[k] = { rank = QC.Rank(v), ev = v and v.ev or 0 }
        end
    end
    table.sort(keys, function(a, b)
        local ia, ib = info[a], info[b]
        if ia.rank ~= ib.rank then return ia.rank < ib.rank end
        if ia.rank == 1 and ia.ev ~= ib.ev then return ia.ev > ib.ev end
        return pos[a] < pos[b]
    end)
    return keys
end

function QC.Begin(key)
    QC.run = { key = key, got = 0, sent = 0, wait = 0, answered = false, touch = Now(),
               secs = 0, nNew = 0, nSold = 0, jumps = 0, inAll = 0, sold = 0, baits = 0 }
    return QC.run
end

-- Naechster Gegenstand fuer die Abfrage (Radar.lua R.NextKey), nil = nichts zu tun
function QC.Next()
    if not QC.Active() then return nil end
    local src = QC.Source()
    if QC.src ~= src then QC.src, QC.queue, QC.run, QC.round = src, {}, nil, 0 end
    local R = ns.Radar
    local r = QC.run
    local n = QC.Probes()
    -- lange Pause (Reiter verlassen, Auktionshaus zu): angefangene Pruefung verwerfen, sie beginnt neu
    if r and Now() - (r.touch or 0) > QC.STALE then
        table.insert(QC.queue, 1, r.key)
        QC.run, r = nil, nil
    end
    if r and (r.got >= n or r.sent >= n + QC.EXTRA or r.wait > QC.WAIT_LOAD or R.skip[r.key]) then
        QC.Finish()
        r = nil
    end
    if not r then
        local valid = {}
        for _, k in ipairs(QC.Keys(src)) do valid[k] = true end
        for _ = 1, 2 do
            while #QC.queue > 0 and not r do
                local key = table.remove(QC.queue, 1)
                if valid[key] and not R.skip[key] then r = QC.Begin(key) end
            end
            if r then break end
            QC.queue = QC.BuildQueue(src)
            QC.round = #QC.queue
            if #QC.queue == 0 then return nil end
        end
        if not r then return nil end
        QC.Changed()
    end
    if not R.ItemReady(r.key) then r.wait, r.touch = r.wait + 1, Now() end
    return r.key
end

-- Abfrage schicken: die erste als Suche, danach "Neu laden" (wie der Fokus, R.SendFocus)
function QC.Send(key)
    local R, r = ns.Radar, QC.run
    if not (r and r.key == key) then return R.Send(key) end
    r.sent, r.touch = r.sent + 1, Now()
    local ok = R.Send(key, nil, r.answered and true or false)
    if ok and R.pending then R.pending.probe = true end
    return ok
end

-- Keine Antwort: beim naechsten Mal den anderen Weg (Suche <-> Neu laden)
function QC.OnTimeout(p)
    local r = QC.run
    if r and p and r.key == p.key then r.answered = not r.answered end
end

-- Antwort (Radar.lua R.Apply, nur echte Antworten)
function QC.OnAnswer(key, rows, t)
    local r = QC.run
    if not (r and r.key == key and type(rows) == "table") then return end
    r.answered, r.touch = true, Now()
    local M = ns.Measure
    local s = M.Sample(rows, t or Now(), nil)
    if not s then return end
    if r.prev and s.t > r.prev.t then
        if ns.QuickStats then ns.QuickStats.OnPair(key, r.prev, s) end   -- ab 0.122: Gelegenheiten langfristig
        local pr = M.Pair(r.prev, s, nil)
        r.secs = r.secs + (pr.gap or 0)
        r.nNew, r.nSold = r.nNew + (pr.zNew or 0), r.nSold + (pr.zSold or 0)   -- ab 0.120 nur in der Kaufzone
        r.inAll, r.sold = r.inAll + (pr.newAll or 0), r.sold + (pr.sold or 0)
        if pr.jump then r.jumps = r.jumps + 1 end
        r.baits = r.baits + #ns.Quick.NewBaits(r.prev, s, nil)
        r.prev.offers, r.prev.levels = nil, nil
    end
    r.prev = s
    r.got = r.got + 1
    local q = 0
    for _, l in ipairs(s.lv or {}) do q = q + (Num(l.qty) and l.qty or 0) end
    r.min, r.qty = s.min, q
    if r.got >= QC.Probes() then QC.Finish() end
    QC.Changed()
end

-- Pruefung fertig: Ergebnis merken (ab 2 Antworten), naechster Gegenstand
function QC.Finish()
    local r = QC.run
    QC.run = nil
    if not r then return end
    local res = QC.res[r.key] or QC.Load(r.key) or { probes = {} }
    if r.got >= 2 and r.secs > 0 then
        res.probes[#res.probes + 1] = { secs = r.secs, nNew = r.nNew, nSold = r.nSold, jumps = r.jumps, inAll = r.inAll,
                                        sold = r.sold, baits = r.baits, n = r.got, t = time() }
        while #res.probes > QC.HIST do table.remove(res.probes, 1) end
        res.at = Now()
        QC.Save(r.key, res.probes)   -- ab 0.126
    end
    if Num(r.min) then res.min, res.qty = r.min, r.qty end
    res.last = Now()
    QC.res[r.key] = res
    QC.sortStamp = QC.sortStamp + 1
end

-- Listen neu zeigen. all = auch die Zahl am Reiter und den Rest der Seite
function QC.Changed(all)
    local C, P = ns.Chances, ns.WatchPage
    if C and C.Shown() and C.Tab() == "quick" then C.Refresh()
    elseif all and C and C.UpdateBadge then C.UpdateBadge() end
    if P and P.Shown() then P.Refresh() end
end

-- Platz in der Runde: 1 = gerade dran, 2 = als naechster ...
function QC.QueuePos(key)
    if QC.run and QC.run.key == key then return 1 end
    for i, k in ipairs(QC.queue) do if k == key then return i + (QC.run and 1 or 0) end end
    return nil
end

-- Fortschritt der Runde fuer die Statuszeile: Nummer des laufenden Gegenstands, Gegenstaende der Runde
function QC.Progress()
    if not QC.run then return nil end
    return math.max(1, QC.round - #QC.queue), math.max(1, QC.round)
end

---------------------------------------------------------------------------
-- Texte
---------------------------------------------------------------------------
function QC.Dots(got, n)
    if n > QC.DOTS_MAX then return GREEN .. ("%d/%d"):format(got, n) .. "|r" end
    local dot = ns.Radar.DOT
    local on = "|T" .. dot .. ":9:9:0:0:32:32:0:32:0:32:96:224:96|t"
    local off = "|T" .. dot .. ":9:9:0:0:32:32:0:32:0:32:90:90:90|t"
    return on:rep(math.min(got, n)) .. off:rep(math.max(0, n - got))
end

-- Bewegung: "lebhaft", "lebhaft?" (vorlaeufig) oder grau "ungeprueft"
function QC.MoveText(v)
    if not v then return GREY .. L.QC_UNCHECKED .. "|r" end
    local color = v.class == "high" and GREEN or v.class == "low" and GREY or WHITE
    local word = L["QUICK_MV_" .. v.class:upper()] or v.class
    return color .. word .. (v.early and "?" or "") .. "|r"
end

-- ab 0.126 (KarloDerBaer 20.11.2026): Ampel fuer die Bewegung in Beobachten. Gruen lebhaft, gelb maessig, rot ruhig,
-- grau ungeprueft. Vorlaeufig (eine Pruefung) oder alt (QC.OLD) blass.
QC.LIGHT = { high = { 96, 224, 96 }, mid = { 255, 209, 0 }, low = { 230, 70, 60 }, none = { 110, 110, 110 } }
function QC.Light(v)
    local c = QC.LIGHT[v and v.class or "none"] or QC.LIGHT.none
    local f = (v and (v.early or v.old)) and 0.45 or 1
    local dot = ns.Radar.DOT
    return ("|T%s:12:12:0:0:32:32:0:32:0:32:%d:%d:%d|t"):format(dot, math.floor(c[1] * f), math.floor(c[2] * f), math.floor(c[3] * f))
end

-- Zustand einer Zeile: Punkte (laeuft), "als 3. dran" oder Alter der letzten Pruefung
function QC.StateText(key)
    local r = QC.run
    if r and r.key == key then return QC.Dots(r.got, QC.Probes()) end
    local res, pos = QC.res[key], QC.QueuePos(key)
    local at = res and (res.at or res.last)
    if at then
        local age = ns.Radar.ShortAge(math.max(0, Now() - at))
        if pos then return GREY .. L.QC_STATE_AGE_POS:format(age, pos) .. "|r" end
        local due = QC.DueIn(key)   -- ab 0.120: wann wieder dran
        if due > 0 then return GREY .. L.QC_STATE_AGE_NEXT:format(age, ns.Radar.ShortAge(due)) .. "|r" end
        return GREY .. L.QC_STATE_AGE:format(age) .. "|r"
    end
    if pos then return GREY .. L.QC_STATE_POS:format(pos) .. "|r" end
    return GREY .. L.QC_STATE_WAIT .. "|r"
end

function QC.Rate(v)
    if not Num(v) then return "-" end
    if v >= 10 then return tostring(math.floor(v + 0.5)) end
    return ns.Settings and ns.Settings.Dec and ns.Settings.Dec(v) or ("%.1f"):format(v)
end

-- Herkunft der Vorschlaege fuer Statuszeile und Tooltip
function QC.SourceText()
    if not QC.candAt then return GREY .. L.QC_SRC_NONE .. "|r" end
    local age = ns.Scan.Age(QC.candAt)
    return GREY .. (QC.candMgr and L.QC_SRC_MGR or L.QC_SRC_SCAN):format(age) .. "|r"
end

-- Zeilen in einem Tooltip (Chancen und Beobachten)
function QC.TipLines(GT, key)
    local v = QC.Result(key)
    if not v then
        GT:AddLine(L.QC_TIP_NONE, 0.7, 0.7, 0.7, true)
    else
        GT:AddLine(L.QC_TIP_MOVE:format(QC.MoveText(v)), 1, 1, 1)
        if v.early then GT:AddLine(L.QC_TIP_EARLY, 0.7, 0.7, 0.7, true) end
        if v.stamp then   -- ab 0.126: Stand der Bewegung (auch gespeichert)
            GT:AddLine(L.QC_TIP_STAMP:format(ns.Radar.ShortAge(math.max(0, time() - v.stamp))) .. (v.old and (" " .. L.QC_TIP_OLD) or ""), 0.7, 0.7, 0.7, true)
        end
        GT:AddLine(L.QC_TIP_RATES:format(tonumber(mod.db.quickZonePct) or 5, QC.Rate(v.newPerMin), QC.Rate(v.soldPerMin), QC.Rate(v.jumpsPerMin)), 0.85, 0.85, 0.85, true)
        GT:AddLine(L.QC_TIP_FLOW:format(QC.Rate(v.inPerMin), QC.Rate(v.outPerMin)), 0.85, 0.85, 0.85, true)
        GT:AddLine(L.QC_TIP_BASE:format(v.events, v.probes, v.queries, QC.Rate(v.secs)), 0.7, 0.7, 0.7, true)
        if v.baits > 0 then GT:AddLine(L.QC_TIP_BAITS:format(v.baits), 1, 0.82, 0, true) end
    end
    if ns.QuickStats then ns.QuickStats.TipLines(GT, key) end   -- ab 0.122
    local db = mod.db
    GT:AddLine(L.QUICK_MV_TIP_RULE:format(tonumber(db.quickMoveIn) or 2, tonumber(db.quickMoveAll) or 5, tonumber(db.quickMoveLow) or 1), 0.6, 0.6, 0.6, true)
end

---------------------------------------------------------------------------
-- Zeilen fuer den Reiter Chancen, Unterreiter Schnellkauf
---------------------------------------------------------------------------
function QC.Rows()
    local D, R, Wt = ns.Data, ns.Radar, ns.Watch
    local rows = {}
    for i, c in ipairs(QC.On() and QC.Candidates() or {}) do
        local key = c.key
        local e = D.Lookup(key)
        local res = QC.res[key]
        local v = QC.Result(key)
        local r = { key = key, order = i, quality = type(e) == "table" and e.ql or nil, icon = ns.Buy.Icon(key),
                    min = res and res.min or c.min, qty = res and res.qty or c.qty, v = v, class = v and v.class or nil,
                    rank = QC.Rank(v), ev = v and v.ev or 0, baits = v and v.baits or nil,
                    dips = ns.QuickStats and ns.QuickStats.Score(key) or 0,   -- ab 0.122: Einbrueche je Std.
                    running = QC.run ~= nil and QC.run.key == key, watched = Wt and Wt.InQuick(key) or false }
        r.name = (type(e) == "table" and e.nm) or D.ItemName(key, e)
        if not r.name then r.name, r.noName = tostring(key), true; if R then R.RequestName(D.ItemID(key)) end end
        rows[#rows + 1] = r
    end
    return rows
end

-- Zahl der lebhaften Vorschlaege (Zahl am Reiter)
function QC.LivelyCount()
    local n = 0
    if not QC.On() then return 0 end
    for _, c in ipairs(QC.cands or {}) do
        local v = QC.Result(c.key)
        if v and v.class == "high" then n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Gegenstandsmenue (Menu.lua): nicht mehr vorschlagen, fuer den Schnellkauf beobachten
---------------------------------------------------------------------------
-- ab 0.120: Kaufen bis und Limit pro Kauf wie im Fokus ohne eigene Werte (Quick.DefaultLimit, Quick.DefaultGold).
-- Bis 0.119 war Kaufen bis der guenstigste Preis und Limit pro Kauf "ohne Grenze".
function QC.WatchQuick(key, name)
    ns.Watch.SetQuickOn(key, true, { name = name })
    QC.Changed(true)
    return true
end

-- Vorgaben fuer einen Gegenstand, der neu in die Liste Schnellkauf kommt: Kaufen bis, Limit pro Kauf
function QC.Defaults(key)
    local res = QC.res[key]
    return ns.Quick.DefaultLimit(key, res and res.min or nil), ns.Quick.DefaultGold()
end

function QC.AddMenu(root, item, key)
    if key == nil or type(key) ~= "number" then return end
    if QC.IsCandidate(key) then
        root:CreateButton(L.MENU_QC_HIDE, function() mod:Call("Schnellkauf-Chancen", QC.Hide, key) end)
    end
    -- ab 0.120: "Beobachten: Schnellkauf" als Haken im Menue der Beobachtung (Watch.AddMenu)
end
