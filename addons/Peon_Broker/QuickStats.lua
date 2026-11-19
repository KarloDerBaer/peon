-- Peon_Broker - QuickStats.lua
-- Ab 0.122 (KarloDerBaer 19.11.2026): Gelegenheiten als langfristige Kennzahl fuer den Schnellkauf.
-- In den kurzen Pruefungen der Chancen fallen Gelegenheiten nur zufaellig auf. Sie zeigen sich erst ueber laengere
-- Beobachtung und sagen, wo andere gern Lockangebote setzen. Deshalb zaehlt Broker sie ueber alle Beobachtungen
-- eines Gegenstands (Fokus, Pruefungen in Chancen und Beobachten) und rechnet sie je Stunde beobachteter Zeit.
--   Einbruch      neues fremdes Angebot mit mindestens 2 Stueck, mindestens quickDipPct Prozent (Vorgabe 5) unter dem
--                 bisher guenstigsten fremden Angebot. Haengt nicht an Kaufen bis, damit Gegenstaende vergleichbar sind.
--                 Hoechstens ein Einbruch je Abfrage.
--   Lockangebot   wie im Fokus (Quick.NewBaits): neu 1 Stueck weit unter dem guenstigsten
--   Nachahmer     Lockangebot, auf das andere zum selben Preis einstellen (nur im Fokus erkennbar, Quick.OnSample)
--   Zeit          Abstand zweier Abfragen, hoechstens QS.GAP_MAX Sekunden (laengere Pausen zaehlen nicht)
-- Speicher je Markt und Tag: PeonBrokerDB.quickStats[Markt][Schluessel][Tag] = { s, d, b, f } (Tag = time() / 86400).
-- Gezaehlt werden die letzten quickStatDays Tage (Vorgabe 14), aeltere Tage mit weniger Gewicht (heute 1, dann
-- gleichmaessig weniger). Unter QS.SURE Sekunden Beobachtung ist der Wert vorlaeufig (grau).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local QS = {}
ns.QuickStats = QS

QS.GAP_MAX = 10      -- Sekunden: laengere Abstaende zwischen zwei Abfragen zaehlen nicht als beobachtete Zeit
QS.SURE = 1800       -- Sekunden: ab so viel beobachteter Zeit gilt der Wert (vorher grau)

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
        d = { s = 0, d = 0, b = 0, f = 0 }
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

-- Einbruch in Abfrage s gegenueber prev? Rueckgabe Preisstufe oder nil
function QS.Dip(prev, s)
    if not (prev and Num(prev.min) and type(s) == "table") then return nil end
    local pct = (tonumber(mod.db.quickDipPct) or 5) / 100
    for _, l in ipairs(s.lv or {}) do
        if l.price > prev.min * (1 - pct) then break end   -- lv ist nach Preis sortiert
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
    if QS.Dip(prev, s) then d.d = d.d + 1 end
    if ns.Quick and ns.Quick.NewBaits then d.b = d.b + #ns.Quick.NewBaits(prev, s, nil) end
end

-- Lockangebot mit Nachahmern (Quick.OnSample, beim ersten Nachahmer)
function QS.OnFollow(key)
    if key ~= nil and ns.Data.IsCommodity(key) then QS.Add(key, "f", 1) end
end

-- Werte eines Gegenstands: nil (nie beobachtet) oder { secs, dips, baits, follows, perHour, baitsPerHour, sure }
function QS.Get(key)
    local st = QS.Store(false)
    local days = st and st[key]
    if type(days) ~= "table" then return nil end
    local today, n = QS.Today(), QS.Days()
    local v = { secs = 0, dips = 0, baits = 0, follows = 0 }
    for day, d in pairs(days) do
        local age = type(day) == "number" and today - day or n
        if age >= 0 and age < n and type(d) == "table" then
            local w = 1 - age / n
            v.secs = v.secs + (d.s or 0) * w
            v.dips = v.dips + (d.d or 0) * w
            v.baits = v.baits + (d.b or 0) * w
            v.follows = v.follows + (d.f or 0) * w
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

-- Zelle fuer Listen: Einbrueche je Std., grau solange vorlaeufig, "-" ohne Beobachtung
function QS.Cell(key)
    local v = QS.Get(key)
    if not v then return GREY .. "-|r" end
    local t = Rate(v.perHour)
    return v.sure and t or (GREY .. t .. "|r")
end

-- Zeile im Fokus: Text und Tooltip
function QS.FocusText(key)
    local v = QS.Get(key)
    local rule = L.QS_TIP_RULE:format(tonumber(mod.db.quickDipPct) or 5, QS.Days())
    if not v then return GREY .. L.QS_NONE .. "|r", { rule } end
    local text = L.QS_LINE:format(Rate(v.perHour), Rate(v.baitsPerHour), QS.Span(v.secs))
    if not v.sure then text = GREY .. text .. "|r" end
    local tips = { L.QS_TIP_VALUES:format(Rate(v.dips), Rate(v.baits), Rate(v.follows), QS.Span(v.secs)) }
    if not v.sure then tips[#tips + 1] = L.QS_TIP_EARLY:format(math.floor(QS.SURE / 60)) end
    tips[#tips + 1] = rule
    return text, tips
end

-- Zeilen fuer Tooltips in Chancen und Beobachten
function QS.TipLines(GT, key)
    local v = QS.Get(key)
    if not v then GT:AddLine(L.QS_TIP_NONE, 0.7, 0.7, 0.7, true); return end
    GT:AddLine(L.QS_TIP_LONG:format(Rate(v.perHour), Rate(v.baitsPerHour), QS.Span(v.secs)), v.sure and 1 or 0.7, v.sure and 0.82 or 0.7, v.sure and 0 or 0.7, true)
end
