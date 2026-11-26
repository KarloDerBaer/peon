-- Peon_Broker - QuickStats.lua
-- Ab 0.122 (KarloDerBaer 19.11.2026): Gelegenheiten als langfristige Kennzahl fuer den Schnellkauf.
-- In den kurzen Pruefungen der Chancen fallen Gelegenheiten nur zufaellig auf. Sie zeigen sich erst ueber laengere
-- Beobachtung und sagen, wo andere gern Lockangebote setzen. Deshalb zaehlt Broker sie ueber alle Beobachtungen
-- eines Gegenstands (Fokus, Pruefungen in Chancen und Beobachten).
-- Ab 0.124 (KarloDerBaer 19.11.2026): einfach gezaehlt (ohne Gewichtung der Tage), im Fokus als Anzahl mit Zeit. Je
-- Stunde nur noch fuer die Spalte in den Listen, erst ab QS.SURE Sekunden Beobachtung.
--   Einbruch      neues fremdes Angebot mit mindestens 2 Stueck, mindestens quickDipPct Prozent (Vorgabe 5) unter dem
--                 Tiefstpreis der letzten QS.LOW_SEC Sekunden (ab 0.124, vorher nur der vorigen Abfrage: dann zaehlte
--                 in lebhaften Maerkten jedes Wiedereinstellen nach einem Auskauf). Tiefstpreis = guenstigste Stufe mit
--                 mindestens 2 Stueck, einzelne Lockangebote verschieben ihn nicht. Haengt nicht an Kaufen bis, damit
--                 Gegenstaende vergleichbar sind. Hoechstens ein Einbruch je Abfrage.
--   Lockangebot   wie im Fokus (Quick.NewBaits): neu 1 Stueck weit unter dem guenstigsten
--   Nachahmer     Lockangebot, auf das andere zum selben Preis einstellen (nur im Fokus erkennbar, Quick.OnSample)
--   Zeit          Abstand zweier Abfragen, hoechstens QS.GAP_MAX Sekunden (laengere Pausen zaehlen nicht)
-- Speicher je Markt und Tag: PeonBrokerDB.quickStats[Markt][Schluessel][Tag] = { s, e, b, f } (Tag = time() / 86400).
-- Einbrueche ab 0.124 in e (d aus 0.122 nach alter Regel wird nicht mehr gelesen und faellt mit dem Tag weg).
-- Gezaehlt werden die letzten quickStatDays Tage (Vorgabe 14, ab 0.126 7).
-- Ab 0.126 (KarloDerBaer 20.11.2026, Beobachten/Schnellkauf nuetzlicher, Werte ueberleben Logout) zusaetzlich je Tag:
--   h   Treffer: fremdes Angebot unter Kaufen bis des Schnellkaufs taucht auf, vorher stand dort keins
--   k   gekaufte Stueck im Schnellkauf, c deren Kosten (Kupfer)
--   lo  { [Stunde] = Preis } Tiefstpreis je Stunde (Stunde = time() / 3600), nur Stufen mit mindestens 2 Stueck
-- Ab 0.135 (U3, Konzept Peon_Broker_Schlank.md 6): Beobachten zeigt Treffer und Einbrueche je Stunde beobachteter Zeit
-- ueber den Zeitraum (QS.Get: hitsPerHour, perHour) und die Spalte Jetzt. Jetzt zaehlt seit Beginn der Sitzung am
-- Auktionshaus (QS.now, nur im Spiel, nicht gespeichert). Eine Sitzung beginnt beim Oeffnen des Auktionshauses, wenn
-- es mindestens QS.NOW_GAP Sekunden zu war (kurz zur Post und zurueck setzt nichts zurueck). Treffer zaehlen jetzt fuer
-- jeden beobachteten Gegenstand mit Kaufen bis des Einkaufens (vorher nur in der Liste Schnellkauf).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local QS = {}
ns.QuickStats = QS

QS.GAP_MAX = 10      -- Sekunden: laengere Abstaende zwischen zwei Abfragen zaehlen nicht als beobachtete Zeit
QS.SURE = 1800       -- Sekunden: ab so viel beobachteter Zeit gilt der Wert je Stunde (Listen)
QS.LOW_SEC = 60      -- ab 0.124: Sekunden, ueber die der Tiefstpreis fuer Einbrueche reicht
QS.lows = {}         -- ab 0.124: [Schluessel] = { { t, p }, ... } Tiefstpreise der letzten QS.LOW_SEC Sekunden (nur Sitzung)
QS.NOW_GAP = 600     -- ab 0.135: Sekunden, die das Auktionshaus zu sein muss, damit beim Oeffnen eine neue Sitzung beginnt
QS.NOW_SURE = 600    -- ab 0.135: Sekunden Beobachtung in der Sitzung, ab denen der Punkt in Jetzt farbig wird
QS.now = {}          -- ab 0.135: [Schluessel] = { s, h, e } Zeit, Treffer, Einbrueche dieser Sitzung (nur im Spiel)
QS.nowClosed = nil   -- ab 0.135: Zeit (time()), zu der das Auktionshaus zuletzt geschlossen wurde

local GREY = "|cff999999"
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

function QS.Days() return math.max(1, math.floor(tonumber(mod.db.quickStatDays) or 7)) end
function QS.Today(t) return math.floor((t or time()) / 86400) end

-- Speicher des Markts (create = anlegen)
function QS.Store(create)
    local acc, market = mod.acc, ns.MarketKey()
    if type(acc) ~= "table" or type(market) ~= "string" then return nil end
    if type(acc.quickStats) ~= "table" then
        if not create then return nil end
        acc.quickStats = {}
    end
    local s = acc.quickStats[market]
    if type(s) ~= "table" then
        if not create then return nil end
        s = {}
        acc.quickStats[market] = s
    end
    return s
end

-- Tag eines Gegenstands zum Schreiben, alte Tage fallen weg
local function Day(key)
    local st = QS.Store(true)
    if not st or key == nil then return nil end
    local days = st[key]
    if type(days) ~= "table" then days = {}; st[key] = days end
    local today = QS.Today()
    local d = days[today]
    if not d then
        local from = today - QS.Days()
        for k in pairs(days) do if type(k) ~= "number" or k <= from then days[k] = nil end end
        d = { s = 0, e = 0, b = 0, f = 0 }
        days[today] = d
    end
    return d
end

function QS.Add(key, field, n)
    local d = Day(key)
    if d then d[field] = (d[field] or 0) + (n or 1) end
end

-- Menge fremder Angebote genau zum Preis
local function QtyAt(s, price)
    for _, l in ipairs(s.lv or {}) do if l.price == price then return l.qty end end
    return 0
end

-- Tiefstpreis einer Abfrage: guenstigste fremde Stufe mit mindestens 2 Stueck, sonst der guenstigste Preis
function QS.Low(s)
    if type(s) ~= "table" then return nil end
    for _, l in ipairs(s.lv or {}) do
        if Num(l.qty) and l.qty >= 2 and Num(l.price) then return l.price end
    end
    return Num(s.min) and s.min or nil
end

-- ab 0.126: Tiefstpreis nur aus Stufen mit mindestens 2 Stueck (ohne Rueckfall auf das guenstigste Angebot)
function QS.Low2(s)
    if type(s) ~= "table" then return nil end
    for _, l in ipairs(s.lv or {}) do
        if Num(l.qty) and l.qty >= 2 and Num(l.price) then return l.price end
    end
    return nil
end

-- ab 0.126: Kaufen bis des Schnellkaufs aus der Beobachtung (nil = nicht beobachtet oder ohne Kaufen bis)
-- ab 0.135 (U3): fuer jeden beobachteten Gegenstand, Beobachten ist eine Liste
function QS.Limit(key)
    local Wt = ns.Watch
    if not Wt then return nil end
    local w = Wt.Store()[key]
    return type(w) == "table" and Num(w.qlim) and w.qlim or nil
end

-- ab 0.126: steht in Abfrage s ein fremdes Angebot bis limit?
local function Under(s, limit)
    if type(s) ~= "table" then return false end
    for _, l in ipairs(s.lv or {}) do
        if not Num(l.price) or l.price > limit then break end
        if Num(l.qty) and l.qty > 0 then return true end
    end
    return false
end
QS.Under = Under

function QS.Hour(t) return math.floor((t or time()) / 3600) end

-- ab 0.126: Tiefstpreis der Stunde merken
local function NoteLow(d, price)
    if not (d and Num(price)) then return end
    if type(d.lo) ~= "table" then d.lo = {} end
    local h = QS.Hour()
    if not d.lo[h] or price < d.lo[h] then d.lo[h] = price end
end

-- Einbruch in Abfrage s gegenueber prev? ref = Tiefstpreis davor (ab 0.124, Vorgabe Tiefstpreis von prev).
-- Rueckgabe Preisstufe oder nil
function QS.Dip(prev, s, ref)
    if not (prev and type(s) == "table") then return nil end
    if not Num(ref) then ref = QS.Low(prev) end
    if not Num(ref) then return nil end
    local pct = (tonumber(mod.db.quickDipPct) or 5) / 100
    for _, l in ipairs(s.lv or {}) do
        if l.price > ref * (1 - pct) then break end   -- lv ist nach Preis sortiert
        if Num(l.qty) and l.qty - QtyAt(prev, l.price) >= 2 then return l end
    end
    return nil
end

-- Zwei Abfragen hintereinander (Fokus: Quick.OnSample, Pruefung: QuickChances.OnAnswer). Nur Massenware.
-- Ab 0.125 Rueckgabe Einbruch (Preisstufe) und Tiefstpreis davor oder nil (fuer den Fokus, Quick.OnSample).
function QS.OnPair(key, prev, s)
    if key == nil or not (prev and type(s) == "table" and Num(prev.t) and Num(s.t)) then return nil end
    if not ns.Data.IsCommodity(key) then return nil end
    local gap = s.t - prev.t
    if gap <= 0 then return nil end
    local d = Day(key)
    if d then d.s = d.s + math.min(gap, QS.GAP_MAX) end
    local nw = QS.NowEntry(key)   -- ab 0.135: Sitzung am Auktionshaus
    nw.s = nw.s + math.min(gap, QS.GAP_MAX)
    -- ab 0.124: Tiefstpreis der letzten Minute (prev und gemerkte Abfragen davor)
    local ref, keep, hasPrev = QS.Low(prev), {}, false
    for _, e in ipairs(QS.lows[key] or {}) do
        if e.t >= s.t - QS.LOW_SEC then
            keep[#keep + 1] = e
            if e.t == prev.t then hasPrev = true end
            if e.t < s.t and (not Num(ref) or e.p < ref) then ref = e.p end
        end
    end
    if not hasPrev and Num(ref) and prev.t >= s.t - QS.LOW_SEC then keep[#keep + 1] = { t = prev.t, p = QS.Low(prev) } end
    local low = QS.Low(s)
    if Num(low) then keep[#keep + 1] = { t = s.t, p = low } end
    QS.lows[key] = keep
    local dip = QS.Dip(prev, s, ref)
    local limit = QS.Limit(key)
    local hit = limit ~= nil and Under(s, limit) and not Under(prev, limit)
    if dip then nw.e = nw.e + 1 end
    if hit then nw.h = nw.h + 1 end
    if d then
        if dip then d.e = (d.e or 0) + 1 end
        if ns.Quick and ns.Quick.NewBaits then d.b = d.b + #ns.Quick.NewBaits(prev, s, nil) end
        -- ab 0.126: Treffer unter Kaufen bis und Tiefstpreis der Stunde
        if hit then d.h = (d.h or 0) + 1 end
        NoteLow(d, QS.Low2(prev))
        NoteLow(d, QS.Low2(s))
    end
    if dip then return dip, ref end
    return nil
end

-- Lockangebot mit Nachahmern (Quick.OnSample, beim ersten Nachahmer)
function QS.OnFollow(key)
    if key ~= nil and ns.Data.IsCommodity(key) then QS.Add(key, "f", 1) end
end

-- ab 0.126: Kauf im Schnellkauf (Quick.OnBought), bleibt ueber den Logout
function QS.OnBought(key, n, cost)
    if key == nil or not (Num(n) and n > 0) then return end
    local d = Day(key)
    if not d then return end
    d.k = (d.k or 0) + n
    d.c = (d.c or 0) + (Num(cost) and cost or 0)
end

-- ab 0.140 (Statistik im Einkaufen): Gelegenheiten (o) und genutzte Gelegenheiten (w) je Tag, fuer die Quote
function QS.OnOpp(key)
    if key == nil then return end
    local d = Day(key)
    if d then d.o = (d.o or 0) + 1 end
end

function QS.OnWon(key)
    if key == nil then return end
    local d = Day(key)
    if d then d.w = (d.w or 0) + 1 end
end

-- ab 0.140: Gekauftes der letzten days Tage (1 = heute): { n, cost, opps, won } oder nil
function QS.Bought(key, days)
    local st = QS.Store(false)
    local all = st and key ~= nil and st[key]
    if type(all) ~= "table" then return nil end
    local from = QS.Today() - math.max(1, days or 1) + 1
    local out, any = { n = 0, cost = 0, opps = 0, won = 0 }, false
    for day, d in pairs(all) do
        if type(day) == "number" and day >= from and type(d) == "table" then
            any = true
            out.n = out.n + (Num(d.k) and d.k or 0)
            out.cost = out.cost + (Num(d.c) and d.c or 0)
            out.opps = out.opps + (Num(d.o) and d.o or 0)
            out.won = out.won + (Num(d.w) and d.w or 0)
        end
    end
    return any and out or nil
end

-- ab 0.133 (U1, Konzept Peon_Broker_Schlank.md 4.1): heute Gekauftes eines Gegenstands (Stueck, Kosten) oder nil
function QS.TodayBought(key)
    local st = QS.Store(false)
    local days = st and key ~= nil and st[key]
    local d = type(days) == "table" and days[QS.Today()] or nil
    if type(d) ~= "table" or not Num(d.k) then return nil end
    return d.k, Num(d.c) and d.c or 0
end

-- ab 0.126: Tiefstpreis der letzten 24 Stunden (nur Stufen ab 2 Stueck), nil = keiner gesehen
function QS.Low24(key)
    local st = QS.Store(false)
    local days = st and st[key]
    if type(days) ~= "table" then return nil end
    local from, low = QS.Hour() - 23, nil
    for _, d in pairs(days) do
        if type(d) == "table" and type(d.lo) == "table" then
            for h, p in pairs(d.lo) do
                if type(h) == "number" and h >= from and Num(p) and (not low or p < low) then low = p end
            end
        end
    end
    return low
end

-- Werte eines Gegenstands: nil (nie beobachtet) oder { secs, dips, baits, follows, hits, bought, cost, perHour,
-- baitsPerHour, sure }
-- Ab 0.124 einfach gezaehlt ueber die letzten quickStatDays Tage, ohne Gewichtung.
function QS.Get(key)
    local st = QS.Store(false)
    local days = st and st[key]
    if type(days) ~= "table" then return nil end
    local today, n = QS.Today(), QS.Days()
    local v = { secs = 0, dips = 0, baits = 0, follows = 0, hits = 0, bought = 0, cost = 0 }
    for day, d in pairs(days) do
        local age = type(day) == "number" and today - day or n
        if age >= 0 and age < n and type(d) == "table" then
            v.secs = v.secs + (d.s or 0)
            v.dips = v.dips + (d.e or 0)
            v.baits = v.baits + (d.b or 0)
            v.follows = v.follows + (d.f or 0)
            v.hits = v.hits + (d.h or 0)
            v.bought, v.cost = v.bought + (d.k or 0), v.cost + (d.c or 0)
        end
    end
    if v.secs <= 0 and v.bought <= 0 then return nil end
    local h = math.max(v.secs, 1) / 3600
    v.perHour, v.baitsPerHour = v.dips / h, v.baits / h
    v.hitsPerHour = v.hits / h   -- ab 0.135 (U3)
    v.sure = v.secs >= QS.SURE
    return v
end

---------------------------------------------------------------------------
-- ab 0.135 (U3): Jetzt, seit Beginn der Sitzung am Auktionshaus
---------------------------------------------------------------------------
function QS.NowEntry(key)
    local nw = QS.now[key]
    if not nw then nw = { s = 0, h = 0, e = 0 }; QS.now[key] = nw end
    return nw
end

-- Auktionshaus geoeffnet: neue Sitzung, wenn es lange genug zu war (oder zum ersten Mal)
function QS.OnAHShow(t)
    t = t or time()
    if not QS.nowClosed or t - QS.nowClosed >= QS.NOW_GAP then QS.now = {} end
    QS.nowClosed = nil
end

function QS.OnAHClosed(t) QS.nowClosed = t or time() end

-- Werte der Sitzung: nil (nicht beobachtet) oder { secs, hits, dips, hitsPerHour, perHour, sure }
function QS.Now(key)
    local nw = QS.now[key]
    if not nw or nw.s <= 0 then return nil end
    local h = nw.s / 3600
    return { secs = nw.s, hits = nw.h, dips = nw.e, hitsPerHour = nw.h / h, perHour = nw.e / h, sure = nw.s >= QS.NOW_SURE }
end

-- Farbe des Punkts in Jetzt: "up" (mehr Treffer je Stunde als im Zeitraum), "down" (weniger), "none" (grau: unter
-- QS.NOW_SURE beobachtet, ohne Kaufen bis, ohne Vergleich oder gleich)
function QS.Trend(key)
    local n = QS.Now(key)
    if not (n and n.sure and QS.Limit(key)) then return "none" end
    local v = QS.Get(key)
    if not (v and v.secs > 0) then return "none" end
    if n.hitsPerHour > v.hitsPerHour + 1e-9 then return "up" end
    if n.hitsPerHour < v.hitsPerHour - 1e-9 then return "down" end
    return "none"
end

QS.TREND = { up = { 96, 224, 96 }, down = { 230, 70, 60 }, none = { 110, 110, 110 } }
function QS.Dot(trend)
    local c = QS.TREND[trend] or QS.TREND.none
    local dot = ns.Radar.DOT
    return ("|T%s:12:12:0:0:32:32:0:32:0:32:%d:%d:%d|t"):format(dot, c[1], c[2], c[3])
end

function QS.Init()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function() QS.OnAHShow() end)
    mod:RegisterEvent("AUCTION_HOUSE_CLOSED", function() QS.OnAHClosed() end)
end

-- Einbrueche je Stunde fuer Sortierung (nur wenn der Wert gilt)
function QS.Score(key)
    local v = QS.Get(key)
    return v and v.sure and v.perHour or 0
end

local function Rate(x)
    x = x or 0
    if x >= 10 then return tostring(math.floor(x + 0.5)) end
    local t = ("%.1f"):format(x):gsub("%.0$", "")
    return (t:gsub("%.", L.DEC_SEP or "."))
end
QS.Rate = Rate

-- Dauer kurz: "25 Min.", "6 Std."
function QS.Span(secs)
    if secs < 3600 then return L.QS_MIN:format(math.max(1, math.floor(secs / 60 + 0.5))) end
    return L.QS_HOURS:format(Rate(secs / 3600))
end

-- Zelle fuer Listen: Einbrueche je Std., ab 0.124 erst ab QS.SURE Sekunden Beobachtung (vorher grau "-")
function QS.Cell(key)
    local v = QS.Get(key)
    if not (v and v.sure) then return GREY .. "-|r" end
    return Rate(v.perHour)
end

-- Zeile im Fokus: Text und Tooltip. Ab 0.124 Anzahl mit beobachteter Zeit, kurzer Tooltip.
function QS.FocusText(key)
    local v = QS.Get(key)
    local tips = { L.QS_TIP_DIP:format(tonumber(mod.db.quickDipPct) or 5) }
    if not v then
        tips[#tips + 1] = L.QS_TIP_DAYS:format(QS.Days())
        return GREY .. L.QS_NONE .. "|r", tips
    end
    tips[#tips + 1] = L.QS_TIP_FOLLOW:format(v.follows)
    tips[#tips + 1] = L.QS_TIP_DAYS:format(QS.Days())
    return L.QS_LINE:format(v.dips, v.baits, QS.Span(v.secs)), tips
end

-- Zeilen fuer Tooltips in Chancen und Beobachten
-- ab 0.126 mit Einbruechen je Std., Treffern, Tiefstpreis 24 Std. und Gekauft im Zeitraum
function QS.TipLines(GT, key)
    local v = QS.Get(key)
    if not v then GT:AddLine(L.QS_TIP_NONE, 0.7, 0.7, 0.7, true); return end
    GT:AddLine(L.QS_TIP_PERIOD:format(QS.Days(), QS.Span(v.secs)), 1, 0.82, 0, true)
    GT:AddLine(L.QS_TIP_COUNTS:format(v.dips, Rate(v.perHour), v.baits), 0.85, 0.85, 0.85, true)
    if QS.Limit(key) then GT:AddLine(L.QS_TIP_HITS_H:format(v.hits, Rate(v.hitsPerHour)), 0.85, 0.85, 0.85, true) end   -- ab 0.135 je Std.
    local low = QS.Low24(key)
    if low then GT:AddLine(L.QS_TIP_LOW24:format(ns.Tooltip.Money(low)), 0.85, 0.85, 0.85, true) end
    if v.bought > 0 then
        GT:AddLine(L.QS_TIP_BOUGHT:format(v.bought, ns.Tooltip.Money(math.floor(v.cost / v.bought + 0.5))), 0.85, 0.85, 0.85, true)
    end
end
