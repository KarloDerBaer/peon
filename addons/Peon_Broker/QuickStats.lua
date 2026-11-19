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
-- Gezaehlt werden die letzten quickStatDays Tage (Vorgabe 14).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local QS = {}
ns.QuickStats = QS

QS.GAP_MAX = 10      -- Sekunden: laengere Abstaende zwischen zwei Abfragen zaehlen nicht als beobachtete Zeit
QS.SURE = 1800       -- Sekunden: ab so viel beobachteter Zeit gilt der Wert je Stunde (Listen)
QS.LOW_SEC = 60      -- ab 0.124: Sekunden, ueber die der Tiefstpreis fuer Einbrueche reicht
QS.lows = {}         -- ab 0.124: [Schluessel] = { { t, p }, ... } Tiefstpreise der letzten QS.LOW_SEC Sekunden (nur Sitzung)

local GREY = "|cff999999"
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

function QS.Days() return math.max(1, math.floor(tonumber(mod.db.quickStatDays) or 14)) end
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
function QS.OnPair(key, prev, s)
    if key == nil or not (prev and type(s) == "table" and Num(prev.t) and Num(s.t)) then return end
    if not ns.Data.IsCommodity(key) then return end
    local gap = s.t - prev.t
    if gap <= 0 then return end
    local d = Day(key)
    if not d then return end
    d.s = d.s + math.min(gap, QS.GAP_MAX)
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
    if QS.Dip(prev, s, ref) then d.e = (d.e or 0) + 1 end
    if ns.Quick and ns.Quick.NewBaits then d.b = d.b + #ns.Quick.NewBaits(prev, s, nil) end
end

-- Lockangebot mit Nachahmern (Quick.OnSample, beim ersten Nachahmer)
function QS.OnFollow(key)
    if key ~= nil and ns.Data.IsCommodity(key) then QS.Add(key, "f", 1) end
end

-- Werte eines Gegenstands: nil (nie beobachtet) oder { secs, dips, baits, follows, perHour, baitsPerHour, sure }
-- Ab 0.124 einfach gezaehlt ueber die letzten quickStatDays Tage, ohne Gewichtung.
function QS.Get(key)
    local st = QS.Store(false)
    local days = st and st[key]
    if type(days) ~= "table" then return nil end
    local today, n = QS.Today(), QS.Days()
    local v = { secs = 0, dips = 0, baits = 0, follows = 0 }
    for day, d in pairs(days) do
        local age = type(day) == "number" and today - day or n
        if age >= 0 and age < n and type(d) == "table" then
            v.secs = v.secs + (d.s or 0)
            v.dips = v.dips + (d.e or 0)
            v.baits = v.baits + (d.b or 0)
            v.follows = v.follows + (d.f or 0)
        end
    end
    if v.secs <= 0 then return nil end
    local h = v.secs / 3600
    v.perHour, v.baitsPerHour = v.dips / h, v.baits / h
    v.sure = v.secs >= QS.SURE
    return v
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
function QS.TipLines(GT, key)
    local v = QS.Get(key)
    if not v then GT:AddLine(L.QS_TIP_NONE, 0.7, 0.7, 0.7, true); return end
    GT:AddLine(L.QS_TIP_LONG:format(v.dips, v.baits, QS.Span(v.secs)), 1, 0.82, 0, true)
end
