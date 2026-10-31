-- Peon_Broker - Sales.lua
-- Absatzquote (ab 0.23, Konzept Peon_Broker_Absatz.md, mit KarloDerBaer abgestimmt 03.10.2026).
-- Broker vergleicht zwei Beobachtungen desselben Gegenstands und zaehlt, was dazwischen verkauft, abgelaufen
-- oder abgebrochen wurde:
--   Live-Abfragen (Radar, Verkaufen, Einkaufsliste, Meine Auktionen): Angebote mit Auktionsnummer, Menge, Preis und
--     Restzeit (Massenware in Sekunden, Einzelgegenstaende als Stufe) -> e.as
--   Komplettscan: Angebote ohne Nummer (Preis, Menge, Restzeit-Stufe falls das Spiel sie liefert) -> e.ss
-- Regeln:
--   gleiche Nummer, Menge kleiner                      -> verkauft (Massenware, Teilkauf)
--   Angebot weg, Ende sicher vorbei                     -> abgelaufen
--   Angebot weg, Ende sicher noch nicht erreicht        ->
--       Massenware: guenstigeres Angebot stand in beiden Beobachtungen (auch teilweise gekauft) -> abgebrochen (man kauft immer
--                   von unten); gleiche Menge billiger neu eingestellt -> abgebrochen; sonst verkauft
--       Einzelgegenstand: verkauft, abzueglich Schaetzwert fuer Abbrueche (db.salesCancelPct, Standard 10 %)
--   Ende unklar (Restzeit-Stufe ueberlappt den Abstand)  -> nicht gezaehlt
-- Nur verglichen wird, was beide Beobachtungen vollstaendig enthalten (bis zum hoechsten sicher gesehenen Preis),
-- nur bei 10 Min. bis 24 Std. Abstand, und nur, wenn der Zeitraum nicht schon von einem anderen Vergleich gezaehlt
-- wurde (e.acov). Tageswerte e.ab = "Tag:verkauft:abgelaufen:abgebrochen:Sekunden:Vergleiche;..." (ab 0.27 so lange wie
-- die Preise, mind. 14 Tage; aeltere als Wochensummen e.abw).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local S = {}
ns.Sales = S

S.KEEP_OFFERS = 30        -- so viele guenstigste Angebote je Gegenstand merken (live; Scan: S.KEEP_SCAN)
S.MIN_GAP     = 60        -- Sekunden: kuerzerer Abstand -> alten Stand behalten und spaeter vergleichen (bis 0.23.0: 10 Min.)
S.RECENT_KEEP = 24 * 3600 -- Sekunden: so lange bleiben die einzelnen Vergleiche fuer den aktuellen Absatz (e.ar)
S.MAX_GAP     = 24 * 3600 -- Sekunden: laengerer Abstand -> nicht vergleichen, neu anfangen
S.SCAN_NOBAND_GAP = 2 * 3600  -- ohne Restzeit im Scan: nur so kurze Abstaende zaehlen "verkauft"
S.DAYS        = 14
S.TOL         = 60        -- Sekunden Toleranz beim Ende (Massenware, sekundengenau)
-- Restzeit-Stufen: kurz (bis 30 Min.), mittel (bis 2 Std.), lang (bis 12 Std.), sehr lang (bis 48 Std.).
-- Forever liefert sie als 1-4 (Pruefung 03.10.2026: 1, 2, 3, 4 gesehen, nie 0) - Retail als 0-3. Deshalb gilt die
-- Bedeutung aus Enum.AuctionHouseTimeLeftBand, wenn das Spiel sie kennt, sonst 1-4; 0 = kurz.
S.RANGES = { Short = { 0, 1800 }, Medium = { 1800, 7200 }, Long = { 7200, 43200 }, VeryLong = { 43200, 172800 } }
S.BANDS = { [0] = S.RANGES.Short, [1] = S.RANGES.Short, [2] = S.RANGES.Medium, [3] = S.RANGES.Long, [4] = S.RANGES.VeryLong }
function S.InitBands()
    local E = rawget(_G, "Enum")
    local t = type(E) == "table" and E.AuctionHouseTimeLeftBand or nil
    if type(t) ~= "table" then return end
    local map, max = {}, -1
    for name, r in pairs(S.RANGES) do
        local v = t[name]
        if type(v) == "number" then map[v] = r; if v > max then max = v end end
    end
    -- nur uebernehmen, wenn die Werte zu dem passen, was das Spiel liefert (hoechste Stufe 4)
    if max == 4 then S.BANDS = map; S.BANDS[0] = S.BANDS[0] or S.RANGES.Short end
end

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

---------------------------------------------------------------------------
-- Angebote <-> Text
---------------------------------------------------------------------------
-- Angebot: { id, q, p, lo, hi } (lo/hi = fruehestes/spaetestes Ende, 0 = unbekannt; id = 0 im Scan)
function S.Ends(t, secs, band)
    if Num(secs) and secs > 0 then return t + secs, t + secs end
    local b = Num(band) and S.BANDS[band]
    if b then return t + b[1], t + b[2] end
    return 0, 0
end

-- Gespeichert wird kompakt (Platz in der Einstellungsdatei): Ende als Minuten ab dem Zeitpunkt der Beobachtung
-- (-1 = unbekannt); im Scan ohne Nummer und nur die guenstigsten S.KEEP_SCAN Angebote.
-- Live: "Nummer:Menge:Preis:frueh:spaet;..."   Scan: "Menge:Preis:frueh:spaet;..."
S.KEEP_SCAN = 15
local function Rel(v, t) if (v or 0) <= 0 then return -1 end return math.floor((v - t) / 60) end
local function Abs(v, t) if v < 0 then return 0 end return t + v * 60 end

function S.Encode(list, t, withIds)
    local parts = {}
    local keep = withIds and S.KEEP_OFFERS or S.KEEP_SCAN
    for i = 1, math.min(#list, keep) do
        local o = list[i]
        local p = math.floor(o.p + 0.5)
        if withIds then
            parts[#parts + 1] = ("%.0f:%d:%.0f:%d:%d"):format(o.id or 0, o.q, p, Rel(o.lo, t), Rel(o.hi, t))   -- Preis/Nummer ueber 2^31 (ab 0.30.2)
        else
            parts[#parts + 1] = ("%d:%.0f:%d:%d"):format(o.q, p, Rel(o.lo, t), Rel(o.hi, t))
        end
    end
    return table.concat(parts, ";")
end

function S.Decode(s, t, withIds)
    local list = {}
    if type(s) ~= "string" then return list end
    if withIds then
        for id, q, p, lo, hi in s:gmatch("(%d+):(%d+):(%d+):(%-?%d+):(%-?%d+)") do
            list[#list + 1] = { id = tonumber(id), q = tonumber(q), p = tonumber(p), lo = Abs(tonumber(lo), t), hi = Abs(tonumber(hi), t) }
        end
    else
        for q, p, lo, hi in s:gmatch("(%d+):(%d+):(%-?%d+):(%-?%d+)") do
            list[#list + 1] = { id = 0, q = tonumber(q), p = tonumber(p), lo = Abs(tonumber(lo), t), hi = Abs(tonumber(hi), t) }
        end
    end
    return list
end

-- Stand aus einer Liste von Angeboten: guenstigste zuerst, cap = Preisgrenze, bis zu der die Liste vollstaendig ist
function S.Snapshot(t, offers, partial, withIds)
    table.sort(offers, function(a, b) if a.p ~= b.p then return a.p < b.p end return (a.id or 0) < (b.id or 0) end)
    local keep = withIds and S.KEEP_OFFERS or S.KEEP_SCAN
    local cap = math.huge
    if partial and #offers > 0 then cap = offers[#offers].p end           -- teurere Stufe evtl. unvollstaendig
    if #offers > keep then cap = math.min(cap, offers[keep + 1].p) end
    return { t = t, cap = cap ~= math.huge and cap or 0, s = S.Encode(offers, t, withIds) }
end

---------------------------------------------------------------------------
-- Vergleich
---------------------------------------------------------------------------
-- Ende eines verschwundenen Angebots bei tB: "expired", "early" oder nil (unklar)
local function EndState(o, tA, tB, scan)
    if (o.hi or 0) > 0 then
        if tB >= o.hi - S.TOL then return "expired" end
        if tB < o.lo then return "early" end
        return nil
    end
    -- keine Restzeit bekannt (Scan ohne Stufe): nur kurze Abstaende
    if scan and tB - tA <= S.SCAN_NOBAND_GAP then return "early" end
    return nil
end

-- A, B = Listen; withIds = Live (Nummern), sonst Scan. Rueckgabe sold, expired, cancelled
function S.Compare(A, B, tA, tB, cap, commodity, withIds, cancelPct)
    local sold, expired, cancelled = 0, 0, 0
    local function In(o) return cap == 0 or o.p < cap end
    local matchedB, gone, newB = {}, {}, {}
    local anchor   -- guenstigstes Angebot, das in beiden unveraendert stand
    if withIds then
        local byId = {}
        for i, b in ipairs(B) do byId[b.id] = i end
        for _, a in ipairs(A) do
            if In(a) then
                local i = byId[a.id]
                if i then
                    matchedB[i] = true
                    local b = B[i]
                    if b.q < a.q then sold = sold + (a.q - b.q) end
                    -- stand in beiden (auch teilweise gekauft): alles Teurere konnte nicht gekauft werden
                    if b.q > 0 and (not anchor or a.p < anchor) then anchor = a.p end
                else
                    gone[#gone + 1] = a
                end
            end
        end
    else
        -- ohne Nummern: gleiches Angebot = gleicher Preis und gleiche Menge
        local used = {}
        for _, a in ipairs(A) do
            if In(a) then
                local hit
                for i, b in ipairs(B) do
                    if not used[i] and b.p == a.p and b.q == a.q then hit = i; break end
                end
                if hit then
                    used[hit] = true
                    if not anchor or a.p < anchor then anchor = a.p end
                else
                    gone[#gone + 1] = a
                end
            end
        end
        matchedB = used
        -- Teilkauf (Massenware): gleicher Preis, weniger Menge
        if commodity then
            local still = {}
            for _, a in ipairs(gone) do
                local hit
                for i, b in ipairs(B) do
                    if not used[i] and b.p == a.p and b.q < a.q then hit = i; break end
                end
                if hit then
                    used[hit] = true; sold = sold + (a.q - B[hit].q)
                    if not anchor or a.p < anchor then anchor = a.p end
                else
                    still[#still + 1] = a
                end
            end
            gone = still
        end
    end
    for i, b in ipairs(B) do if In(b) and not matchedB[i] then newB[#newB + 1] = b end end
    for _, a in ipairs(gone) do
        local st = EndState(a, tA, tB, not withIds)
        if st == "expired" then
            expired = expired + a.q
        elseif st == "early" then
            if commodity then
                local repost = false
                for j, b in ipairs(newB) do
                    if b.q == a.q and b.p < a.p then repost = true; table.remove(newB, j); break end
                end
                if repost or (anchor and a.p > anchor) then cancelled = cancelled + a.q
                else sold = sold + a.q end
            else
                local c = a.q * (cancelPct or 0)
                cancelled = cancelled + c
                sold = sold + (a.q - c)
            end
        end
    end
    return sold, expired, cancelled
end

---------------------------------------------------------------------------
-- Tageswerte
---------------------------------------------------------------------------
function S.ParseDays(s)
    local d = {}
    if type(s) ~= "string" then return d end
    for day, so, ex, ca, sec, n in s:gmatch("(%d+):([%d%.]+):([%d%.]+):([%d%.]+):(%d+):(%d+)") do
        d[#d + 1] = { tonumber(day), tonumber(so), tonumber(ex), tonumber(ca), tonumber(sec), tonumber(n) }
    end
    return d
end

local function R1(v) return math.floor(v * 10 + 0.5) / 10 end

function S.JoinDays(d)
    local parts = {}
    for _, x in ipairs(d) do
        parts[#parts + 1] = ("%d:%s:%s:%s:%d:%d"):format(x[1], R1(x[2]), R1(x[3]), R1(x[4]), x[5], x[6])
    end
    return table.concat(parts, ";")
end

function S.AddDay(e, t, sold, expired, cancelled, secs)
    local day = ns.Data.Day(t)
    local d = S.ParseDays(e.ab)
    local last = d[#d]
    if last and last[1] == day then
        last[2], last[3], last[4], last[5], last[6] = last[2] + sold, last[3] + expired, last[4] + cancelled, last[5] + secs, last[6] + 1
    else
        d[#d + 1] = { day, sold, expired, cancelled, secs, 1 }
    end
    S.CompactDays(e, d, day)
end

-- Ab 0.27 (KarloDerBaer 06.10.2026, fuer den Ledger-Reiter "Gegenstand"): Tageswerte so lange wie die Preise (dataDays,
-- mindestens S.DAYS), aeltere als Wochensummen e.abw = "Woche:verk:abgel:abgebr:Sekunden:Vergleiche;..." (D.WEEKS Wochen).
function S.KeepDays()
    local n = mod.db and tonumber(mod.db.dataDays) or 30
    return math.max(S.DAYS, n)
end

function S.CompactDays(e, d, day)
    d = d or S.ParseDays(e.ab)
    day = day or ns.Data.Day()
    local keepDays = S.KeepDays()
    local keep, w = {}, S.ParseDays(e.abw)
    for _, x in ipairs(d) do
        if x[1] > day - keepDays then
            keep[#keep + 1] = x
        else
            local week = math.floor(x[1] / 7)
            local found
            for _, y in ipairs(w) do if y[1] == week then found = y end end
            if found then
                for k = 2, 6 do found[k] = found[k] + x[k] end
            else
                w[#w + 1] = { week, x[2], x[3], x[4], x[5], x[6] }
                table.sort(w, function(a, b) return a[1] < b[1] end)
            end
        end
    end
    local wkeep = {}
    local weeks = ns.Data.WEEKS or 26
    for _, y in ipairs(w) do if y[1] > math.floor(day / 7) - weeks then wkeep[#wkeep + 1] = y end end
    e.ab = #keep > 0 and S.JoinDays(keep) or nil
    e.abw = #wkeep > 0 and S.JoinDays(wkeep) or nil
end

-- Einzelne Vergleiche der letzten 24 Std. (fuer den aktuellen Absatz): e.ar = "Ende:Sekunden:verk:abgel:abgebr;..."
function S.ParseRecent(s)
    local list = {}
    if type(s) ~= "string" then return list end
    for t, sec, so, ex, ca in s:gmatch("(%d+):(%d+):([%d%.]+):([%d%.]+):([%d%.]+)") do
        list[#list + 1] = { tonumber(t), tonumber(sec), tonumber(so), tonumber(ex), tonumber(ca) }
    end
    return list
end

-- Ab 0.28 (Platz): Vergleiche, die in derselben Stunde enden, werden zu einem Eintrag zusammengefasst
-- (Ende = spaetestes Ende, Sekunden und Stueck addiert) - hoechstens 24 Eintraege je Gegenstand statt einer je Vergleich.
function S.AddRecent(e, t, secs, sold, expired, cancelled)
    local list = {}
    for _, x in ipairs(S.ParseRecent(e.ar)) do
        if x[1] > t - S.RECENT_KEEP then list[#list + 1] = x end
    end
    local last = list[#list]
    if last and math.floor(last[1] / 3600) == math.floor(t / 3600) and t >= last[1] then
        last[1], last[2], last[3], last[4], last[5] = t, last[2] + secs, last[3] + sold, last[4] + expired, last[5] + cancelled
    else
        list[#list + 1] = { t, secs, sold, expired, cancelled }
    end
    local parts = {}
    for i, x in ipairs(list) do parts[i] = ("%d:%d:%s:%s:%s"):format(x[1], x[2], R1(x[3]), R1(x[4]), R1(x[5])) end
    e.ar = table.concat(parts, ";")
end

-- Ab 0.28 (Platz): Momentaufnahmen und Einzelvergleiche, die aelter als 24 Std. sind, werden nicht mehr gebraucht
-- (verglichen wird hoechstens S.MAX_GAP auseinander) - beim taeglichen Verdichten loeschen.
function S.Prune(e, now)
    if type(e) ~= "table" then return end
    now = now or time()
    if type(e.as) == "table" and (type(e.as.t) ~= "number" or now - e.as.t > S.MAX_GAP) then e.as = nil end
    if type(e.ss) == "table" and (type(e.ss.t) ~= "number" or now - e.ss.t > S.MAX_GAP) then e.ss = nil end
    if e.ar then
        local keep = {}
        for _, x in ipairs(S.ParseRecent(e.ar)) do
            if x[1] > now - S.RECENT_KEEP then keep[#keep + 1] = ("%d:%d:%s:%s:%s"):format(x[1], x[2], R1(x[3]), R1(x[4]), R1(x[5])) end
        end
        e.ar = #keep > 0 and table.concat(keep, ";") or nil
    end
    if e.as == nil and e.ss == nil then e.acov = nil end
end

-- Neue Beobachtung: mit dem gemerkten Stand vergleichen und zaehlen; field = "as" (live) oder "ss" (Scan)
function S.Observe(e, field, snap, offers, commodity, withIds)
    local old = e[field]
    if type(old) == "table" and old.t then
        local gap = snap.t - old.t
        if gap < S.MIN_GAP and gap >= 0 then return false end      -- zu kurz: alten Stand behalten
        if gap > 0 and gap <= S.MAX_GAP and old.t >= (e.acov or 0) then
            local cap = old.cap or 0
            if (snap.cap or 0) > 0 then cap = (cap > 0) and math.min(cap, snap.cap) or snap.cap end
            local pct = (tonumber(mod.db.salesCancelPct) or 10) / 100
            local so, ex, ca = S.Compare(S.Decode(old.s, old.t, withIds), offers, old.t, snap.t, cap, commodity, withIds, pct)
            S.AddDay(e, snap.t, so, ex, ca, gap)
            S.AddRecent(e, snap.t, gap, so, ex, ca)
            e.acov = snap.t
        end
    end
    e[field] = snap
    return true
end

-- Live-Ergebnis (aus Data.ApplyLive): rows.offers = { { id, q, p, secs, band } }, rows.commodity
function S.OnLive(e, rows, t)
    if type(e) ~= "table" or type(rows) ~= "table" or type(rows.offers) ~= "table" then return end
    if rows.foreign then return end
    local offers = {}
    for _, o in ipairs(rows.offers) do
        if Num(o.id) and Num(o.q) and o.q > 0 and Num(o.p) and o.p > 0 then
            local lo, hi = S.Ends(t, o.secs, o.band)
            offers[#offers + 1] = { id = o.id, q = o.q, p = o.p, lo = lo, hi = hi }
        end
    end
    if #offers == 0 and rows.partial then return end
    local snap = S.Snapshot(t, offers, rows.partial, true)
    S.Observe(e, "as", snap, offers, rows.commodity and true or false, true)
end

-- Komplettscan (aus Scan.lua): list = flach { Preis je Stueck, Menge, Restzeit-Stufe oder -1, ... }
function S.OnScan(e, key, list, t)
    if type(e) ~= "table" or type(list) ~= "table" then return end
    local offers = {}
    for i = 1, #list - 2, 3 do
        local band = list[i + 2]
        local lo, hi = S.Ends(t, nil, band >= 0 and band or nil)
        offers[#offers + 1] = { id = 0, q = list[i + 1], p = list[i], lo = lo, hi = hi }
    end
    local snap = S.Snapshot(t, offers, false, false)
    S.Observe(e, "ss", snap, offers, ns.Data.IsCommodity(key), false)
end

---------------------------------------------------------------------------
-- Auswertung und Anzeige
---------------------------------------------------------------------------
-- Aktueller Absatz (ab 0.23.1, Wunsch KarloDerBaer): Vergleiche der letzten db.salesWindow Stunden (Standard 6).
-- { perHour, rate, sold, expired, cancelled, minutes, cmp, level, reach (Stunden) } oder nil (kein Vergleich)
-- Sicherheit nach beobachteter Zeit: rot unter db.salesMidMin, gelb bis db.salesSureMin, gruen darueber (Minuten).
-- ab 0.32 (Rechenmodell F49): mit key und ohne eigene sichere Beobachtung (unter gelb) der Absatz vom Peon Client, src = "client"
function S.Stats(e, now, key)
    local own = S.OwnStats(e, now)
    if key ~= nil and (not own or (own.level or 1) < 2) then
        local c = S.ClientStats(e, key)
        if c then return c end
    end
    return own
end

-- Absatz vom Peon Manager (14 Tage, ueber Peon_Bridge), nil ohne Bridge, ohne Wert, bei alten Werten oder bei Fehler
function S.ClientStats(e, key)
    local c = Peon:GetModule("bridge")
    if not c or type(c.Sales) ~= "function" then return nil end
    local ok, v = pcall(c.Sales, c, key, ns.MarketKey())
    if not ok or type(v) ~= "table" or type(v.perDay) ~= "number" or type(v.minutes) ~= "number" then return nil end
    local db = mod.db
    local r = { perHour = v.perDay / 24, rate = v.rate, minutes = v.minutes, cmp = 0, src = "client" }
    local mid, sure = tonumber(db.salesMidMin) or 60, tonumber(db.salesSureMin) or 180
    r.level = (r.minutes >= sure and 3) or (r.minutes >= mid and 2) or 1
    local supply = type(e) == "table" and tonumber(e.q) or 0
    if r.perHour > 0 then r.reach = supply / r.perHour elseif supply > 0 then r.reach = math.huge end
    return r
end

function S.OwnStats(e, now)
    if type(e) ~= "table" or not e.ar then return nil end
    now = now or time()
    local db = mod.db
    local from = now - (tonumber(db.salesWindow) or 6) * 3600
    local so, ex, ca, sec, n = 0, 0, 0, 0, 0
    for _, x in ipairs(S.ParseRecent(e.ar)) do
        if x[1] > from then so, ex, ca, sec, n = so + x[3], ex + x[4], ca + x[5], sec + x[2], n + 1 end
    end
    if n == 0 or sec <= 0 then return nil end
    local r = { sold = so, expired = ex, cancelled = ca, minutes = sec / 60, cmp = n }
    r.perHour = so / sec * 3600
    if so + ex > 0 then r.rate = so / (so + ex) end
    local mid, sure = tonumber(db.salesMidMin) or 60, tonumber(db.salesSureMin) or 180
    r.level = (r.minutes >= sure and 3) or (r.minutes >= mid and 2) or 1
    local supply = tonumber(e.q) or 0
    if r.perHour > 0 then r.reach = supply / r.perHour elseif supply > 0 then r.reach = math.huge end
    return r
end

-- Langfristig: 14 Tage (fuer Preise-Einzelheiten, /broker absatz und spaeter die Verbindung mit der Verkaufsquote)
function S.Stats14(e, today)
    if type(e) ~= "table" or not e.ab then return nil end
    today = today or ns.Data.Day()
    local so, ex, ca, sec, n = 0, 0, 0, 0, 0
    for _, x in ipairs(S.ParseDays(e.ab)) do
        if x[1] > today - S.DAYS then so, ex, ca, sec, n = so + x[2], ex + x[3], ca + x[4], sec + x[5], n + x[6] end
    end
    if n == 0 or sec <= 0 then return nil end
    local r = { sold = so, expired = ex, cancelled = ca, hours = sec / 3600, cmp = n, perHour = so / sec * 3600 }
    if so + ex > 0 then r.rate = so / (so + ex) end
    return r
end

-- Zeichen fuer die Sicherheit: immer da ("ganz exakt ist es nie"), rot schlecht, gelb besser, gruen gut
S.LEVEL_COLORS = { "|cffff5555", "|cffffd100", "|cff60e060" }
function S.Mark(level) return (S.LEVEL_COLORS[level or 1] or S.LEVEL_COLORS[1]) .. "≈|r " end

-- Zahl mit Komma: 120, 4,5, 0,3
function S.Num(v)
    if v >= 10 then return tostring(math.floor(v + 0.5)) end
    local s = ("%.1f"):format(v)
    return (s:gsub("%.", ","))
end

-- "≈ 30/Std."
function S.PerHourText(r)
    return S.Mark(r.level) .. L.SALES_PER_HOUR:format(S.Num(r.perHour))
end

-- Reichweite in Stunden: "reicht 15 Std." / "reicht 3 T."
function S.ReachText(r)
    if not r.reach then return nil end
    if r.reach == math.huge or r.reach > 99 * 24 then return L.SALES_REACH_LONG end
    if r.reach < 1 then return L.SALES_REACH_LT1 end
    if r.reach < 48 then return L.SALES_REACH_H:format(S.Num(r.reach)) end
    return L.SALES_REACH:format(S.Num(r.reach / 24))
end

-- Tooltip: "≈ 30/Std. · 70 % verkauft" (ohne Reichweite, KarloDerBaer)
function S.TooltipText(r)
    local parts = { S.PerHourText(r) }
    if r.rate then parts[#parts + 1] = L.SALES_RATE:format(math.floor(r.rate * 100 + 0.5)) end
    return table.concat(parts, " · ")
end

-- Verkaufen: zusaetzlich die Reichweite
function S.SellText(r)
    local parts = { S.PerHourText(r) }
    local reach = S.ReachText(r)
    if reach then parts[#parts + 1] = reach end
    if r.rate then parts[#parts + 1] = L.SALES_RATE:format(math.floor(r.rate * 100 + 0.5)) end
    return table.concat(parts, " · ")
end

-- Markt schnell / voll (nur ab gelb): "fast", "slow" oder nil
function S.Speed(r)
    if not r or r.level < 2 or not r.reach then return nil end
    local db = mod.db
    if r.reach < (tonumber(db.salesGreenHours) or 24) then return "fast" end
    if r.reach > (tonumber(db.salesRedDays) or 7) * 24 then return "slow" end
    return nil
end

-- Daten bis 0.23.0 verwerfen (Restzeit-Stufen falsch gelesen, Vergleiche erst ab 10 Min.)
function S.Migrate(acc)
    if type(acc) ~= "table" or acc.salesVer == 2 then return end
    for _, m in pairs(type(acc.markets) == "table" and acc.markets or {}) do
        for _, e in pairs(type(m.items) == "table" and m.items or {}) do
            if type(e) == "table" then e.as, e.ss, e.ab, e.ar, e.acov, e.abw = nil, nil, nil, nil, nil, nil end
        end
    end
    acc.salesVer = 2
end

-- /broker absatz <Name, Nummer oder Link>
function S.Report(text)
    local D = ns.Data
    local market = D.Market()
    if not market then mod:Print(L.SALES_NO_MARKET); return end
    text = strtrim and strtrim(text or "") or (text or "")
    if text == "" then mod:Print(L.SALES_USAGE); return end
    local key = D.KeyFromLink(text) or tonumber(text)
    if key == nil then
        local low = text:lower()
        for k, e in pairs(market.items) do
            local name = type(e) == "table" and (e.nm or D.ItemName(k, e))
            if type(name) == "string" and name:lower() == low then key = k; break end
        end
        if key == nil then
            for k, e in pairs(market.items) do
                local name = type(e) == "table" and (e.nm or D.ItemName(k, e))
                if type(name) == "string" and name:lower():find(low, 1, true) then key = k; break end
            end
        end
    end
    local e = key ~= nil and market.items[key]
    if type(e) ~= "table" then mod:Print(L.SALES_NOT_FOUND:format(text)); return end
    local name = e.nm or D.ItemName(key, e) or tostring(key)
    local r = S.Stats(e)
    local r14 = S.Stats14(e)
    if not r and not r14 then
        mod:Print(L.SALES_NONE:format(name, e.as and 1 or 0, e.ss and 1 or 0))
        return
    end
    if r then
        mod:Print(L.SALES_HEAD:format(name, S.SellText(r)))
        mod:Print(L.SALES_DETAIL_NOW:format(tonumber(mod.db.salesWindow) or 6, S.Num(r.sold), S.Num(r.expired), S.Num(r.cancelled), S.Num(r.minutes), r.cmp, tonumber(e.q) or 0))
    end
    if r14 then
        mod:Print(L.SALES_DETAIL_14:format(S.Num(r14.perHour), S.Num(r14.sold), S.Num(r14.expired), S.Num(r14.cancelled), S.Num(r14.hours), r14.cmp))
    end
end

S.InitBands()
