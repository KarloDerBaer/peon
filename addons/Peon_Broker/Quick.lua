-- Peon_Broker - Quick.lua
-- Ab 0.104 (Wunsch KarloDerBaer 19.11.2026): Modus "Schnellkauf" im Reiter Fokus. Der bisherige Fokus heisst
-- "Aufkauf". Beide teilen Gegenstand, laufende Abfrage und Preisstufen, der Umschalter steht oben rechts.
-- Schnellkauf ist fuer guenstige Angebote, die nur Sekunden stehen (Lockangebote und ihre Nachahmer):
--   links   Kaufen bis, Menge, Kaufknopf mit Alarm (Ton und Leuchten, sobald etwas unter Kaufen bis steht),
--           Block Lockangebot (Preisfeld, ab 0.132 Menge und Einstellen, bis 0.131 Zurueckziehen, Zustand) und die Bilanz
--           der Sitzung
--   rechts  Preisstufen (eigene Angebote markiert, neue Stufen kurz gruen), darunter ein Diagramm mit dem
--           guenstigsten Preis, der Menge unter Kaufen bis und senkrechten Strichen fuer eigene Lockangebote
-- Lockangebot: 1 Stueck aus den Taschen (ab 0.132 Menge einstellbar, Q.BaitQty), kuerzeste Laufzeit. Der Preis steht als Vorschlag im Feld: ab 0.107
-- Kaufen bis minus quickBaitPct Prozent (Vorgabe 50, vorher die erste echte Stufe minus 20). Ein eigener Betrag im
-- Feld gilt bis zum naechsten Gegenstand. Ab 0.107 fuellt der Schnellkauf ein leeres Kaufen bis (Q.EnsureLimit), bis
-- 0.119 mit dem Wert des Aufkaufs, ab 0.120 mit der Haelfte des guenstigsten Angebots, mindestens dem Haendlerpreis. Nur Massenware (PostCommodity). Eigenes Einstellen per Knopf war in Forever bisher nicht erprobt:
-- Fragt das Spiel nach (Rueckgabe von PostCommodity oder AUCTION_HOUSE_POST_WARNING), bestaetigt erst der zweite
-- Klick (ConfirmPostCommodity).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local Q = {}
ns.Quick = Q

Q.DURATION = 1        -- kuerzeste Laufzeit des Spiels
Q.NEW_SEC = 6         -- Sekunden: so lange ist eine neue oder groessere Stufe gruen
Q.POST_WAIT = 10      -- Sekunden: so lange warten wir auf die Bestaetigung des Spiels
Q.bait = nil          -- { key, price, t, loc, id, state = "posting" | "confirm" | "up" | "cancelling" | "cancelled" | "gone" }
Q.manual = nil        -- { key, price }: eigener Lockpreis (bis zum naechsten Gegenstand)
Q.sessions = {}       -- [Schluessel] = { baits, deposit, bought, cost }: Bilanz dieser Sitzung
Q.marks = {}          -- [Schluessel] = { GetTime() eigener Lockangebote } fuer das Diagramm
Q.baits = {}          -- ab 0.110: [Schluessel] = { { t, price, own, lastQ, added, times, reg, above }, ... } Lockangebote fortlaufend
Q.hold = nil          -- ab 0.114: { key, rows, untilT } Pause der Abfragen, solange der Kaufknopf frei ist
Q.opp = {}            -- ab 0.111: [Schluessel] = { t, won } letzte Gelegenheit zum Kauf
Q.baitPing = nil      -- ab 0.111: Schluessel, fuer den gerade ein fremdes Lockangebot erkannt wurde
Q.avg = {}            -- ab 0.112: [Schluessel] = true/false, Haken "Durchschnitt zaehlt" (sonst aus Beobachten)
Q.skip = {}           -- ab 0.109: [Schluessel] = true/false, Haken "Lockangebot ignorieren" (sonst aus Beobachten)
Q.newTiers = {}       -- [Preis] = GetTime(), bis wann die Stufe als neu gilt
Q.prev = nil          -- { key, rows, levels = { [Preis] = Menge } }: letzte Antwort fuer den Vergleich
Q.alarm = {}          -- { key, rows, qty }: letzte Antwort fuer den Alarm

local GREY, GREEN, ORANGE, YELLOW = "|cff999999", "|cff60e060", "|cffff9933", "|cffffd100"
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end
local function Now() return GetTime and GetTime() or time() end
local function AHApi() return rawget(_G, "C_AuctionHouse") end
local function AHOpen() return ns.Scan.ahOpen and AHApi() ~= nil end

-- ab 0.133 (U1, Konzept Peon_Broker_Schlank.md 4.5): Der Modus Aufkauf ruht. Ohne den Schalter focusBuyout
-- (Einstellungen, Erweitert) ist der Schnellkauf immer an, focusMode bleibt gespeichert, wie er war.
function Q.BuyoutOn() return mod.db.focusBuyout == true end
function Q.On() return not Q.BuyoutOn() or mod.db.focusMode == "quick" end
function Q.Mode() return Q.On() and "quick" or "buyout" end

-- Anschluss fuer das Kaufprotokoll im privaten Peon_Debug (Radar.lua R.Trace, ab 0.118)
function Q.Trace(fmt, ...)
    if ns.Radar and ns.Radar.Trace then ns.Radar.Trace(fmt, ...) end
end

-- quiet = true: nur umschalten (der Aufrufer zeichnet neu). Ab 0.106 laedt der Modus die Werte, die fuer den
-- Gegenstand in Beobachten gespeichert sind (Aufkauf und Schnellkauf getrennt).
function Q.SetMode(mode, quiet)
    local new = (mode == "quick" or not Q.BuyoutOn()) and "quick" or "buyout"
    local changed = Q.Mode() ~= new
    local F = ns.Focus
    if changed and not quiet and F.AutoSave then F.AutoSave() end   -- ab 0.113: Werte des bisherigen Modus
    mod.db.focusMode = new
    -- ab 0.125.1: eigene Werte gehoeren zum Modus. Vorher blieb das automatische Kaufen bis des Schnellkaufs
    -- (Haelfte des guenstigsten Angebots) beim Wechsel in den Aufkauf stehen, der Aufkauf kaufte dann nichts.
    if changed then
        F.manual, F.manualLimit, F.manualSrc, F.manualQty, F.manualGold = nil, nil, nil, nil, nil
        F.loaded = nil   -- ab 0.131: Werte des neuen Modus erst laden (F.EnsureLoaded)
        if F.limitInput then F.ClearLimitInput() end
        if F.targetInput then F.ClearInput() end
    end
    F.chartN = nil
    if F.ApplyMode then F.ApplyMode() end
    if changed and not quiet and F.key ~= nil and ns.Watch and ns.Watch.Is(F.key) then
        F.LoadWatch(F.key)
        if F.limitInput and not F.ManualLimit(F.key) then F.ClearLimitInput() end
    end
    if not quiet then F.Update() end
end

function Q.Session(key)
    local s = Q.sessions[key]
    if not s then s = { baits = 0, deposit = 0, bought = 0, cost = 0 }; Q.sessions[key] = s end
    return s
end

-- Neuer Gegenstand im Fokus: eigener Lockpreis und Vergleich vergessen (Lockangebot und Bilanz bleiben)
function Q.OnNewKey()
    Q.manual, Q.prev, Q.newTiers, Q.alarm, Q.hold = nil, nil, {}, {}, nil
    Q.armed = {}   -- ab 0.168: das Band gilt nur fuer den Gegenstand, bei dem es ausgeloest hat
    Q.dgot = {}    -- ab 0.168: Ziel des Direktkaufs beginnt von vorn
end

---------------------------------------------------------------------------
-- ab 0.143 (KarloDerBaer 26.11.2026): Kaufart im Einkaufen. Kaufen bis heisst jetzt Limit und ist der Standard je
-- Gegenstand (gespeichert in Beobachten, Hoechstpreis der Listen, Treffer und Alarm rechnen damit).
--   normal    kein Haken: die gewaehlte Menge ab dem guenstigsten Angebot. Alle = alles auf der guenstigsten Stufe.
--             Ein Klick auf eine Stufe nimmt alle Stufen bis dorthin mit (Q.pick, nur in der Sitzung).
--   Limit     Haken Limit: nur Angebote bis zum Standard
--   Gleitend  Haken Gleitend: nur Angebote bis zum Wert der gewaehlten Methode, mit Limit nie ueber dem Standard
-- Gleitend rechnet mit dem ruhigen Tiefstpreis der letzten Minute (Median der Tiefstpreise, Stufen ab 2 Stueck).
--   gain   Mindestgewinn: Weiterverkauf zum Tiefstpreis bringt nach dem Anteil noch quickSuggestPct Prozent
--   under  Unter Markt: mindestens quickUnderPct Prozent unter dem Tiefstpreis (Einbrueche, Lockangebote)
--   band   Ueblicher Bereich: unterer Rand des ueblichen Bereichs aus den Preisdaten
-- Haken und Methode merkt sich Broker je Gegenstand in Beobachten (qlimOn, qglide, qmethod, nur im Spiel).
-- ab 0.167 (Board KarloDerBaer 27.11.2026): statt der drei Methoden zwei Auswahllisten.
--   Richtpreis    Preis, zu dem man wieder einstellen koennte (Q.REFS, Q.RefValue)
--   Gewinnspanne  so viel Prozent Gewinn bleiben mindestens, wenn man zum Richtpreis wieder einstellt (Q.MARGINS)
--   Limit jetzt = Richtpreis x (1 - Anteil des Auktionshauses) / (1 + Gewinnspanne)
-- Gespeichert je Gegenstand in Beobachten (qref, qmargin, nur im Spiel). Ohne qref gilt die alte Methode: gain und
-- under werden zu calm, band zu band. Ohne qmargin gilt quickSuggestPct (Einstellungen). quickUnderPct ruht.
---------------------------------------------------------------------------
Q.limitOn = {}   -- [Schluessel] = true/false dieser Sitzung
Q.glide = {}     -- [Schluessel] = true/false dieser Sitzung
Q.method = {}    -- [Schluessel] = Methode dieser Sitzung
Q.pick = {}      -- [Schluessel] = Preis der Stufe, bis zu der im normalen Einkauf gekauft wird
Q.METHODS = { "gain", "under", "band" }

local function SavedField(key, field)
    local Wt = ns.Watch
    local w = Wt and key ~= nil and Wt.Is(key) and Wt.Store()[key]
    return w and w[field] or nil
end

---------------------------------------------------------------------------
-- ab 0.168 (KarloDerBaer 28.11.2026): zwei Tabs ueber dem Gegenstand statt der Haken Limit und Gleitend.
--   Limitkauf  (limit)  es gilt immer ein Limit: Fest (Standard im Feld) oder gleitend nach einem Richtpreis. Dazu der
--                       Ausloeser (Q.Trig): erst wenn das Guenstigste ihn erreicht, wird bis zum Limit gekauft (Band).
--   Direktkauf (direct) nur eine Menge ab dem guenstigsten Angebot (bisher der Einkauf ohne Haken, Kaufart normal)
-- Welcher Tab beim Oeffnen gilt: der zuletzt gewaehlte (Sitzung, bei beobachteten Gegenstaenden qtab), sonst
-- beobachtete Gegenstaende Limitkauf, alle anderen Direktkauf. Die Haken gibt es nicht mehr: qlimOn ruht, qglide sagt
-- weiter, ob das Limit gleitet (qref ist dann der Richtpreis).
---------------------------------------------------------------------------
Q.tab = {}   -- [Schluessel] = "limit" oder "direct" dieser Sitzung

function Q.Tab(key)
    if key == nil then return "limit" end
    local v = Q.tab[key]
    if v == "limit" or v == "direct" then return v end
    if Q.listDirect and Q.listDirect[key] then return "direct" end   -- ab 0.169 aus einer Liste
    v = SavedField(key, "qtab")
    if v == "limit" or v == "direct" then return v end
    if ns.Watch and ns.Watch.Is(key) then return "limit" end
    return "direct"
end

function Q.GlideOn(key)
    if key == nil or Q.Tab(key) ~= "limit" then return false end
    local v = Q.glide[key]
    if v ~= nil then return v end
    return SavedField(key, "qglide") == true
end

-- Fester Standard im Limitkauf (ab 0.168 ohne Haken: im Limitkauf immer, wenn nicht gleitend)
function Q.LimitOn(key)
    if key == nil or Q.Tab(key) ~= "limit" then return false end
    return not Q.GlideOn(key)
end

function Q.Method(key)
    local m = key ~= nil and (Q.method[key] or SavedField(key, "qmethod")) or nil
    for _, x in ipairs(Q.METHODS) do if x == m then return m end end
    return "gain"
end

-- "normal" (Direktkauf), "limit" (Limit fest) oder "glide" (Limit gleitend)
function Q.BuyKind(key)
    if key ~= nil and Q.Tab(key) == "direct" then return "normal" end
    if Q.GlideOn(key) then return "glide" end
    return "limit"
end

-- Quelle des Limits fuer die Auswahlliste: "fix" oder ein Richtpreis (Q.REFS)
function Q.LimSrc(key)
    if Q.GlideOn(key) then return Q.Ref(key) end
    return "fix"
end

local function Changed()
    local F = ns.Focus
    F.Store()
    F.chartN = nil
    F.Update()
end

-- Bis 0.167 die Haken Limit und Gleitend. Ab 0.168 ohne Haken in der Oberflaeche, die Aufrufe bleiben und bilden die
-- alte Bedeutung auf die Tabs ab: Limit an = Limitkauf fest, Gleitend an = Limitkauf gleitend, beides aus = Direktkauf.
function Q.SetLimitOn(on)
    local key = ns.Focus.key
    if key == nil then return end
    Q.limitOn[key] = on and true or false
    if on then Q.tab[key] = "limit"
    elseif not Q.GlideOn(key) then Q.tab[key] = "direct" end
    Changed()
end

function Q.SetGlideOn(on)
    local key = ns.Focus.key
    if key == nil then return end
    if on then
        Q.tab[key] = "limit"
        Q.glide[key] = true
    else
        Q.glide[key] = false
        if Q.limitOn[key] == false then Q.tab[key] = "direct" end
    end
    Changed()
end

function Q.SetMethod(m)
    local key = ns.Focus.key
    if key == nil then return end
    Q.method[key] = m
    Changed()
end

-- ab 0.168: Tab waehlen. Eine angeklickte Stufe (Q.pick) gilt nur im Direktkauf und faellt beim Wechsel weg.
function Q.SetTab(t)
    local key = ns.Focus.key
    if key == nil or (t ~= "limit" and t ~= "direct") then return end
    Q.tab[key] = t
    Q.listDirect[key] = nil
    Q.pick[key] = nil
    Q.dgot[key] = nil
    ns.Focus.qtyMax = nil
    Changed()
end

-- ab 0.168: Quelle des Limits aus der Auswahlliste ("fix" oder ein Richtpreis)
function Q.SetLimSrc(v)
    local key = ns.Focus.key
    if key == nil then return end
    if v == "fix" then
        Q.glide[key] = false
    else
        local ok = false
        for _, x in ipairs(Q.REFS) do if x == v then ok = true end end
        if not ok then return end
        Q.glide[key] = true
        Q.ref[key] = v
    end
    Changed()
end

---------------------------------------------------------------------------
-- ab 0.168 (KarloDerBaer 28.11.2026): Ausloeser im Limitkauf. Er legt mit dem Limit ein Band fest: gekauft wird erst,
-- wenn das Guenstigste den Ausloeser erreicht oder unterschreitet, dann bis zum Limit (mit Durchschnitt zaehlt im
-- Mittel). Der Ausloeser liegt nie ueber dem Limit, sonst gilt das Limit (Band 0, wie bisher).
--   off    Aus: Ausloeser = Limit
--   fix    Fest: eigener Preis (qtrigFix)
--   limit  Limit minus Abstand in Prozent (qtrigPct, Q.TRIG_PCTS)
--   low    Letzter Tiefstpreis: der letzte Einbruch (QuickStats.LastDip). Einzelstuecke zaehlen nicht (ein Einbruch hat
--          mindestens 2 Stueck, mit Min. Menge mindestens so viele), eigene Angebote auch nicht. Er verfaellt nach
--          Q.LOW_KEEP Sekunden, ohne gueltigen Tiefstpreis gilt das Limit.
-- Einmal ausgeloest bleibt das Band scharf (Q.armed), bis unter dem Limit nichts mehr steht oder der Gegenstand
-- wechselt. So kauft auch der Smart-Teilkauf in mehreren Klicks weiter.
---------------------------------------------------------------------------
Q.TRIGS = { "off", "fix", "limit", "low" }
Q.TRIG_PCTS = { 2, 3, 5, 10, 15, 20, 25, 30 }
Q.TRIG_PCT_DEFAULT = 5
Q.LOW_KEEP = 24 * 3600
Q.trig, Q.trigPct, Q.trigFix, Q.armed = {}, {}, {}, {}

function Q.Trig(key)
    if key == nil then return "off" end
    local v = Q.trig[key] or SavedField(key, "qtrig")
    for _, x in ipairs(Q.TRIGS) do if x == v then return v end end
    return "off"
end

function Q.TrigPct(key)
    local v = key ~= nil and (Q.trigPct[key] or SavedField(key, "qtrigPct")) or nil
    if not Num(v) then v = Q.TRIG_PCT_DEFAULT end
    return math.max(0, math.min(100, math.floor(v)))
end

function Q.TrigFix(key)
    if key == nil then return nil end
    local v = Q.trigFix[key]
    if v == nil then v = SavedField(key, "qtrigFix") end
    if Num(v) and v > 0 then return math.floor(v) end
    return nil
end

function Q.SetTrig(v)
    local key = ns.Focus.key
    if key == nil then return end
    local ok = false
    for _, x in ipairs(Q.TRIGS) do if x == v then ok = true end end
    if not ok then return end
    Q.trig[key] = v
    Q.armed[key] = nil
    Changed()
end

function Q.SetTrigPct(p)
    local key = ns.Focus.key
    if key == nil or not Num(p) then return end
    Q.trigPct[key] = math.max(0, math.floor(p))
    Q.armed[key] = nil
    Changed()
end

-- amount 0 oder nil = leer
function Q.SetTrigFix(amount)
    local key = ns.Focus.key
    if key == nil then return end
    Q.trigFix[key] = (Num(amount) and amount > 0) and math.floor(amount) or 0
    Q.armed[key] = nil
    Changed()
end

-- Letzter Tiefstpreis fuer key: Preis, Zeit (time()), Stueck oder nil
function Q.LastLow(key)
    local QS = ns.QuickStats
    if key == nil or not (QS and QS.LastDip) then return nil end
    local minQ = Q.MinQty(key)
    return QS.LastDip(key, Q.LOW_KEEP, math.max(2, minQ or 2))
end

-- Ausloeser fuer key bei Limit limit. Rueckgabe Preis (nie ueber dem Limit), Art, capped (true = der eingestellte
-- Wert fehlt oder liegt ueber dem Limit, es gilt das Limit)
function Q.TriggerValue(key, limit)
    if not Num(limit) then return nil end
    local t = Q.Trig(key)
    if t == "off" then return limit, t, false end
    local v
    if t == "fix" then v = Q.TrigFix(key)
    elseif t == "limit" then v = math.floor(limit * (1 - Q.TrigPct(key) / 100))
    elseif t == "low" then v = Q.LastLow(key) end
    if not Num(v) or v <= 0 or v >= limit then return limit, t, true end
    return v, t, false
end

-- ab 0.169 (KarloDerBaer 28.11.2026): Band eines beliebigen Gegenstands, auch ausserhalb des Einkaufens (Beobachten,
-- Glocke, Treffer). Rueckgabe limit, trig, kind ("limit", "glide" oder "direct"). Fest: der Standard (im Einkaufen der
-- eingetragene, sonst qlim). Gleitend: aus der letzten Abfrage des Gegenstands, ohne Wert der zuletzt gerechnete dieser
-- Sitzung (Q.lastGlide). Direktkauf hat kein Band: limit und trig nil.
Q.lastGlide = {}
function Q.BandFor(key)
    if key == nil then return nil, nil, nil end
    if Q.Tab(key) == "direct" then return nil, nil, "direct" end
    local F = ns.Focus
    local limit, kind
    if Q.GlideOn(key) then
        kind = "glide"
        local live = ns.Buy and ns.Buy.live and ns.Buy.live[key]
        local rows = type(live) == "table" and type(live.rows) == "table" and live.rows or nil
        limit = Q.GlideValue(key, nil, rows)
        if Num(limit) then Q.lastGlide[key] = limit else limit = Q.lastGlide[key] end
    else
        kind = "limit"
        limit = (F and F.key == key and F.ManualLimit and F.ManualLimit(key)) or SavedField(key, "qlim")
    end
    if not Num(limit) or limit <= 0 then return nil, nil, kind end
    local trig = Q.TriggerValue(key, limit)
    return limit, trig, kind
end

-- Preis, ab dem das Guenstigste den Ausloeser erreicht: mit Lockangebot ignorieren das zweite Stueck von unten (ein
-- einzelnes Lockangebot loest nicht aus), sonst das erste
function Q.TriggerPrice(key, rows)
    local need = Q.SkipOn(key) and (Q.SKIP_MAX + 1) or 1
    local n = 0
    for _, l in ipairs(ns.Data.Available(rows or {})) do
        n = n + l.qty
        if n >= need then return l.price end
    end
    return nil
end

-- Ist das Band fuer key scharf? rows = Live-Stufen, limit = geltendes Limit. Rueckgabe scharf, Ausloeser
function Q.Armed(key, rows, limit)
    if key == nil or not Num(limit) then return false, nil end
    local trig = Q.TriggerValue(key, limit)
    if not Num(trig) or trig >= limit then Q.armed[key] = nil; return true, trig end
    local lv = ns.Data.Available(rows or {})
    if not (lv[1] and lv[1].price <= limit) then Q.armed[key] = nil; return false, trig end
    local p = Q.TriggerPrice(key, rows)
    if Num(p) and p <= trig then Q.armed[key] = true end
    return Q.armed[key] == true, trig
end

-- ab 0.167: Richtpreis und Gewinnspanne
Q.REFS = { "calm", "day", "high", "week", "band", "sold" }
Q.MARGINS = { 0, 5, 10, 15, 20, 25, 30, 40, 50 }
Q.OLD_REF = { gain = "calm", under = "calm", band = "band" }
Q.ref, Q.margin = {}, {}

function Q.Ref(key)
    if key == nil then return "calm" end
    local r = Q.ref[key] or SavedField(key, "qref")
    if r == nil then r = Q.OLD_REF[Q.method[key] or SavedField(key, "qmethod") or ""] end
    for _, x in ipairs(Q.REFS) do if x == r then return r end end
    return "calm"
end

function Q.Margin(key)
    local m = key ~= nil and (Q.margin[key] or SavedField(key, "qmargin")) or nil
    if not Num(m) then m = tonumber(mod.db.quickSuggestPct) or 5 end
    return math.max(0, math.min(100, math.floor(m)))
end

function Q.SetRef(r)
    local key = ns.Focus.key
    if key == nil then return end
    Q.ref[key] = r
    Changed()
end

function Q.SetMargin(m)
    local key = ns.Focus.key
    if key == nil or not Num(m) then return end
    Q.margin[key] = math.max(0, math.floor(m))
    Changed()
end

-- Stufe im normalen Einkauf waehlen (Klick in die Angebote), price = nil: wieder nur die guenstigste
function Q.SetPick(price)
    local key = ns.Focus.key
    if key == nil then return end
    Q.pick[key] = (Num(price) and price > 0) and price or nil
    ns.Focus.chartN = nil
    ns.Focus.Update()
end

-- Ruhiger Tiefstpreis: Median der Tiefstpreise der letzten Minute (QuickStats.lows), sonst das guenstigste ohne
-- Ausreisser der letzten Abfrage
Q.CALM_MIN = 3
function Q.CalmLow(key, rows)
    local QS = ns.QuickStats
    local list = QS and QS.lows and key ~= nil and QS.lows[key] or nil
    local ps = {}
    for _, e in ipairs(list or {}) do if Num(e.p) and e.p > 0 then ps[#ps + 1] = e.p end end
    if #ps >= Q.CALM_MIN then
        table.sort(ps)
        local n = #ps
        if n % 2 == 1 then return ps[(n + 1) / 2] end
        return math.floor((ps[n / 2] + ps[n / 2 + 1]) / 2 + 0.5)
    end
    return rows and Q.CleanLow(rows) or nil
end

-- ab 0.167: Richtpreis fuer key (Kupfer je Stueck) oder nil
--   calm   Guenstigster ruhig: Median der Tiefstpreise der letzten Minute (Q.CalmLow)
--   day    Tagesmedian: Median der Tiefstpreise je Stunde der letzten 24 Std. (QuickStats, nur was Broker sah)
--   high   Tageshoechstwert: hoechster Tiefstpreis einer Stunde der letzten 24 Std.
--   week   Wochenmittel: Mittel der Tiefstpreise aus den Scans der letzten 7 Tage
--   band   Ueblicher Bereich: unterer Rand des ueblichen Bereichs (ab 0.167 Board KarloDerBaer, nicht die Mitte)
--   sold   Verkaufspreis (bis 0.167 Letzter Verkauf): Median meiner Verkaeufe der letzten 7 Tage (Q.SalePrice)
function Q.RefValue(key, ref, rows)
    ref = ref or Q.Ref(key)
    local v
    if ref == "calm" then
        v = Q.CalmLow(key, rows)
    elseif ref == "day" or ref == "high" then
        local QS = ns.QuickStats
        local mean, top = nil, nil
        if QS and QS.LowStats then mean, top = QS.LowStats(key, 24) end
        v = ref == "day" and mean or top
    elseif ref == "week" then
        local e = ns.Data.Lookup(key)
        local w = type(e) == "table" and ns.Data.Week(e) or nil
        v = w and w.min
    elseif ref == "band" then
        local ok, ctx = pcall(ns.Buyout.Context, nil, key)
        local band = ok and type(ctx) == "table" and ctx.band or nil
        v = type(band) == "table" and band.low or nil
    elseif ref == "sold" then
        v = Q.SalePrice(key)
    end
    if not Num(v) or v <= 0 then return nil end
    return math.floor(v + 0.5)
end

-- ab 0.168 (KarloDerBaer 28.11.2026): Verkaufspreis statt Letzter Verkauf. Bisher zaehlte der allerletzte Verkauf,
-- auch ein verkauftes Lockangebot (dann weit unter dem Markt). Jetzt der Median je Stueck aller Verkaeufe im
-- Auktionshaus der letzten Q.SALE_DAYS Tage, gewichtet nach Stueck (Peon_Ledger SalesSince). Verkaeufe von nur einem
-- Stueck zaehlen nur, wenn es keine groesseren gibt: einzelne Lockangebote ziehen den Wert so nicht nach unten.
-- Ein aelteres Ledger ohne SalesSince: wie bisher der letzte Verkauf.
Q.SALE_DAYS = 7
function Q.SalePrice(key)
    local led = ns.Item and ns.Item.Ledger and ns.Item.Ledger()
    if not led then return nil end
    local id = ns.Data.ItemID(key)
    if type(led.SalesSince) ~= "function" then
        if type(led.LastSale) ~= "function" then return nil end
        local ok, unit = pcall(led.LastSale, led, id)
        return ok and unit or nil
    end
    local ok, list = pcall(led.SalesSince, led, id, time() - Q.SALE_DAYS * 86400)
    if not ok or type(list) ~= "table" then return nil end
    return Q.WeightedMedian(list)
end

-- Median je Stueck einer Liste { unit, n }, gewichtet nach n. Einzelstuecke nur ohne groessere Verkaeufe.
function Q.WeightedMedian(list)
    local multi, all = {}, {}
    for _, x in ipairs(list or {}) do
        if type(x) == "table" and Num(x.unit) and x.unit > 0 and Num(x.n) and x.n > 0 then
            all[#all + 1] = x
            if x.n > 1 then multi[#multi + 1] = x end
        end
    end
    local use = #multi > 0 and multi or all
    if #use == 0 then return nil end
    table.sort(use, function(a, b) return a.unit < b.unit end)
    local total = 0
    for _, x in ipairs(use) do total = total + x.n end
    local half, cum = total / 2, 0
    for _, x in ipairs(use) do
        cum = cum + x.n
        if cum >= half then return x.unit end
    end
    return use[#use].unit
end

-- Limit von Gleitend fuer key (Kupfer je Stueck) oder nil. ref = nil: der gewaehlte Richtpreis
function Q.GlideValue(key, ref, rows)
    if Q.OLD_REF[ref or ""] then ref = Q.OLD_REF[ref] end
    local base = Q.RefValue(key, ref, rows)
    if not Num(base) then return nil end
    local cut = ns.Data.Cut and ns.Data.Cut() or 0.05
    local v = math.floor(base * (1 - cut) / (1 + Q.Margin(key) / 100))
    return v >= 1 and v or nil
end

-- Preis der Stufe, bis zu der gekauft wird. Rueckgabe Preis (nil = nichts zu kaufen), Kaufart
function Q.EffectiveLimit(key, rows)
    local F = ns.Focus
    if key == nil then return nil, "normal" end
    local kind = Q.BuyKind(key)
    local std = F.ManualLimit(key)
    if kind == "glide" then
        -- ab 0.168 ohne Deckel durch den Standard: das Band (Ausloeser) begrenzt nach unten, das Limit ist das Limit
        return Q.GlideValue(key, nil, rows), kind
    end
    if kind == "limit" then return std, kind end
    -- normal: gewaehlte Stufe, sonst so weit, wie die feste Menge reicht, sonst die guenstigste Stufe
    local lv = ns.Data.Available(rows or {})
    if not lv[1] then return nil, kind end
    local pick = Q.pick[key]
    if Num(pick) then return pick, kind end
    local want = Q.QtyWant(key)
    if want then
        local cum = 0
        for _, l in ipairs(lv) do
            cum = cum + l.qty
            if cum >= want then return l.price, kind end
        end
        return lv[#lv].price, kind
    end
    return lv[1].price, kind
end

---------------------------------------------------------------------------
-- Was der Schnellkauf kauft: alles bis zum geltenden Limit (Q.EffectiveLimit)
---------------------------------------------------------------------------
function Q.Plan()
    local F = ns.Focus
    local limit, kind = Q.EffectiveLimit(F.key, F.LiveRows())
    if not limit then return nil end
    local d = F.OwnPlan(limit + 1, limit)
    if not d then return nil end
    d.quick = true
    d.ref = F.ManualTarget(F.key)   -- Ziel fuer einen Posten (Wiedereinstellen), sonst keins
    d.net, d.gain, d.showGain = nil, nil, nil
    d.best.gain = nil
    -- ab 0.133 (U1, Konzept 4.1): Menge (Regler bis "Alle") und Goldreserve statt Limit pro Kauf. Die Goldreserve
    -- (radarReserve) bleibt nach jedem Kauf mindestens uebrig, die Menge wird notfalls gekuerzt.
    local want = Q.QtyWant(F.key)
    local budget = ns.Radar.Budget()
    local avail = Q.GoldQty(d.rows, limit, math.huge)
    local cap = want
    -- ab 0.167: Smart-Teilkauf (Q.Portion) begrenzt die Menge eines Klicks
    local portion, portionWhy = Q.Portion(F.key, d.rows)
    local full = math.min(want or avail, avail)
    if portion and portion < full then cap = portion else portion = nil end
    local short = false
    if Num(budget) then
        local gq = Q.GoldQty(d.rows, limit, budget)
        if cap == nil or gq < cap then
            -- ab 0.166.4: gekuerzt nur, wenn bis zum Limit mehr zu haben waere. Bis 0.166.3 stand "Begrenzt durch
            -- Goldreserve" auch dann, wenn unter dem Limit gar nichts angeboten war (Board KarloDerBaer 27.11.2026).
            local need = math.min(cap or avail, avail)
            short = gq < need
            cap = gq
        end
    end
    local c = F.CapPlan(d, cap == nil and false or cap)
    if c and not c.gone then
        c.goldCap = Num(budget) and budget or nil   -- Kauf bricht ab, wenn er die Goldreserve angreifen wuerde
        c.want, c.reserveShort = want, short or nil
        if portion then c.portion, c.portionWhy, c.portionAll = portion, portionWhy, full end   -- ab 0.167
        c.buyKind = kind   -- ab 0.143
        -- ab 0.112: Kauf gilt, solange der Durchschnitt passt (ab 0.143 nur mit Limit oder Gleitend)
        if kind ~= "normal" and Q.AvgOn(F.key) then c.avgLimit = limit end
    end
    -- ab 0.109: Haken "Lockangebot ignorieren": Knopf und Alarm erst ab mehr als 1 Stueck unter Kaufen bis. Das
    -- Spiel verkauft von unten, der Kauf eines groesseren Stapels nimmt das eine Stueck also mit.
    -- ab 0.143 nur mit Limit oder Gleitend: im normalen Einkauf ist das guenstigste Stueck einfach das guenstigste
    -- ab 0.167: Min. Menge. Gibt es unter dem Limit weniger, oder laesst die Goldreserve weniger kaufen, gibt es nichts
    -- zu kaufen. Mehr als die Max. Menge verlangt sie nie.
    local minQ = Q.MinQty(F.key)
    if minQ and want then minQ = math.min(minQ, want) end
    if c and not c.gone and minQ and ((c.maxQty or 0) < minQ or (c.reserveShort and ((c.best and c.best.qty) or 0) < minQ)) then
        c.minShort = minQ
        c.maxQty, c.qty, c.cost = 0, 0, 0
        c.best = { qty = 0, cost = 0 }
        c.buyLimit = 0
        c.reserveShort, c.portion = nil, nil
    end
    if c and not c.gone and kind ~= "normal" and Q.SkipOn(F.key) and (c.maxQty or 0) <= Q.SKIP_MAX and (c.maxQty or 0) > 0 then
        c.baitOnly = true
        c.maxQty, c.qty, c.cost = 0, 0, 0
        c.best = { qty = 0, cost = 0 }
        c.buyLimit = 0
    end
    -- ab 0.168: Band. Bis der Ausloeser erreicht ist, gibt es nichts zu kaufen (kein Knopf, kein Alarm).
    if c and not c.gone and kind ~= "normal" then
        local armed, trig = Q.Armed(F.key, d.rows, limit)
        c.trigger = trig
        if not armed and (c.maxQty or 0) > 0 then
            c.waitTrig = trig
            c.maxQty, c.qty, c.cost = 0, 0, 0
            c.best = { qty = 0, cost = 0 }
            c.buyLimit = 0
            c.reserveShort, c.portion = nil, nil
        end
    end
    return c
end

-- ab 0.109: Haken "Lockangebot ignorieren" je Gegenstand (in dieser Sitzung, sonst aus Beobachten gespeichert)
Q.SKIP_MAX = 1   -- so viele Stueck allein gelten als Lockangebot (fest, KarloDerBaer 19.11.2026)
-- ab 0.113: gespeicherter Wert des Schnellkaufs fuer key (true/false) oder nil (nichts gespeichert -> Vorgabe).
-- Bis 0.112 stand nur true (sonst nil): hat der Eintrag schon Werte des Schnellkaufs, heisst nil dort aus.
local function SavedFlag(key, field)
    local Wt = ns.Watch
    local w = Wt and Wt.Is(key) and Wt.Store()[key]
    if not w then return nil end
    if w[field] ~= nil then return w[field] and true or false end
    if w.qlim ~= nil or w.qgold ~= nil or w.mode == "quick" then return false end
    return nil
end

function Q.SkipOn(key)
    if key == nil then return false end
    local v = Q.skip[key]
    if v ~= nil then return v end
    v = SavedFlag(key, "qskip")
    if v ~= nil then return v end
    return true   -- ab 0.113 Vorgabe an
end

-- ab 0.114 (Wunsch KarloDerBaer): Solange der Kaufknopf frei ist, schickt der Fokus hoechstens quickHold Sekunden
-- keine Abfrage. Laut Kaufprotokoll wartete ein Kauf sonst bis zu 1 Sek. auf den Preis und noch einmal so lange auf
-- die Bestaetigung, weil die Bremse des Spiels von der letzten Abfrage belegt war. Danach ist der Knopf gesperrt, bis
-- die naechste Antwort da ist (sie zeigt, was jetzt noch zu haben ist). Ein laufender Kauf haelt die Abfragen ohnehin an.
function Q.HoldQueries(key)
    local h = Q.hold
    if not (h and Q.On() and key ~= nil and h.key == key) then return false end
    return Now() < h.untilT
end

-- Kaufknopf gesperrt: Pause vorbei, die Antwort von damals ist noch die neueste
function Q.Locked(key)
    local h = Q.hold
    if not (h and Q.On() and key ~= nil and h.key == key) then return false end
    if Now() < h.untilT then return false end
    local rows = ns.Focus.LiveRows()
    return rows == nil or rows == h.rows
end

-- ab 0.112: wie viele Stueck bis Kaufen bis fuer gold Kupfer zu haben sind (von unten)
function Q.GoldQty(rows, limit, gold)
    local n, cost = 0, 0
    for _, l in ipairs(ns.Data.Available(rows or {})) do
        if Num(limit) and l.price > limit then break end
        local can = math.floor((gold - cost) / l.price)
        local take = math.min(l.qty, can)
        if take < 1 then break end
        n, cost = n + take, cost + take * l.price
        if take < l.qty then break end
    end
    return n
end

-- ab 0.112: Haken "Durchschnitt zaehlt" je Gegenstand (Sitzung, sonst aus Beobachten). Ab 0.113 Vorgabe an.
-- ab 0.143: fuer alle Gegenstaende (Einstellungen, Erweitert: quickAvg, Vorgabe an). Q.avg und qavg bleiben, ungenutzt.
function Q.AvgOn(key)
    if key == nil then return false end
    return mod.db.quickAvg ~= false
end

-- ab 0.113 (Wunsch KarloDerBaer): Limit pro Kauf ohne gespeicherten Wert. Leert man das Feld, bleibt es leer
-- (Q.goldCleared). Ab 0.120 (KarloDerBaer 19.11.2026) ein fester Betrag (quickGoldDefault, Vorgabe 5 Gold), bis 0.119
-- der Preis fuer 100 Stueck zu Kaufen bis.
Q.goldCleared = {}
function Q.DefaultGold()
    local v = math.floor(tonumber(mod.db.quickGoldDefault) or 50000)
    return v > 0 and v or nil
end

function Q.EnsureGold()
    local F = ns.Focus
    local key = F.key
    if key == nil or not Q.On() or Q.goldCleared[key] then return end
    local m = F.manualGold
    if m and m.key == key and not m.auto then return end
    local gold = Q.DefaultGold()
    if gold then F.manualGold = { key = key, gold = gold, auto = true } end
end

function Q.SetAvg(on)
    local key = ns.Focus.key
    if key == nil then return end
    Q.avg[key] = on and true or false
    ns.Focus.Store()   -- ab 0.133: jede Eingabe gilt sofort
    ns.Focus.Update()
end

function Q.SetSkip(on)
    local key = ns.Focus.key
    if key == nil then return end
    Q.skip[key] = on and true or false
    ns.Focus.Store()
    ns.Focus.Update()
end

---------------------------------------------------------------------------
-- Menge (ab 0.133, U1, Konzept Peon_Broker_Schlank.md 4.1): Regler von 1 bis "Alle" (alles unter Kaufen bis).
-- Vorgabe fuer Massenware "Alle", fuer andere Gegenstaende 1. Je Gegenstand in Beobachten gespeichert (qqty, 0 = Alle).
---------------------------------------------------------------------------
Q.qty = {}   -- [Schluessel] = Menge dieser Sitzung (0 = Alle), sonst aus Beobachten oder Vorgabe
-- ab 0.136 (U4, Konzept 4.1): aus einer Einkaufsliste geoeffnet: [Schluessel] = id der Liste. Die Menge folgt dann dem,
-- was dort noch fehlt (auch nach jedem Kauf), bis man sie selbst aendert. Wird nie gespeichert.
Q.fromList = {}

-- ab 0.169 (KarloDerBaer 28.11.2026): aus einer Liste immer im Direktkauf (Q.listDirect), bis man selbst einen Tab
-- waehlt. Eine eigene Menge aendert daran nichts. Aus einer anderen Seite gilt wieder der gemerkte Tab.
Q.listDirect = {}

function Q.FromList(key, listId)
    if key == nil then return end
    Q.fromList[key] = listId
    Q.listDirect[key] = listId ~= nil or nil
    if listId ~= nil then
        Q.qty[key] = nil
        Q.tab[key] = nil
        Q.pick[key] = nil
    end
end

-- Menge aus der Liste: was fehlt, mindestens 1 (nie "Alle"), nil = nicht aus einer Liste
function Q.ListQty(key)
    local id = key ~= nil and Q.fromList[key] or nil
    if id == nil or not ns.Buy then return nil end
    local need = ns.Buy.NeedFor(key, id)
    if not Num(need) then return nil end
    return math.max(1, math.floor(need))
end

function Q.QtyDefault(key)
    if key == nil then return nil end
    return ns.Data.IsCommodity(key) and 0 or 1
end

-- Gewaehlte Menge als Zahl (0 = Alle)
function Q.QtyStored(key)
    if key == nil then return nil end
    local v = Q.qty[key]
    if v ~= nil then return v end
    local lq = Q.ListQty(key)   -- ab 0.136
    if lq then return lq end
    local Wt = ns.Watch
    local w = Wt and Wt.Is(key) and Wt.Store()[key]
    if w and Num(w.qqty) and w.qqty >= 0 then return math.floor(w.qqty) end
    return Q.QtyDefault(key)
end

---------------------------------------------------------------------------
-- ab 0.167 (KarloDerBaer 27.11.2026, Kaufprotokoll 22:58 bis 23:15 Uhr): Smart-Teilkauf. Das Spiel verkauft eine
-- angefragte Menge ganz oder gar nicht. Kaufen andere in den 1 bis 2 Sek. bis zum Kauf einen Teil der billigen Stueck,
-- scheitert alles. Im Protokoll klappte kein Kauf ab 16 Stueck (0 von 25), bis 5 Stueck 36 %.
-- Zweite Fassung (Kaufprotokoll 23:21 bis 23:31 Uhr: Quote 14 auf 33 %, aber 41 statt 101 Stueck, die Portion fiel
-- bis auf 1, freie Stapel mit 46 und 24 Stueck kaufte Smart in vier bis fuenf kleinen Klicks):
--   neuer Stapel  der erste Klick kauft alles (bis zur Max. Menge). Neu heisst: der guenstigste Preis ist ein anderer
--                 als beim letzten Fehlschlag, oder an der Spitze kam deutlich Menge dazu (Q.NewStack).
--   high          Preis des Spiels zu hoch: aus dem Preis zurueckrechnen, wie viele billige Stueck noch da waren
--                 (Q.RestAfterQuote), die naechste Portion ist so gross (auch unter Q.PORTION_MIN, das meldet das Spiel)
--   lost          bestaetigt, aber gescheitert: ein Drittel weniger, nie unter Q.PORTION_MIN. Schon kleine Kaeufe
--                 scheitern, weil andere schneller sind, kleiner hilft dann nicht.
--   won           gekauft: Portion doppelt so gross
--   Ablauf        Q.PORTION_KEEP Sek. nach dem letzten Fehlschlag gilt wieder der volle Kauf
-- Einstellung quickPortion: "smart" (Vorgabe) oder "off" (Mehr Einstellungen im Einkaufen).
---------------------------------------------------------------------------
Q.portion = {}        -- [Schluessel] = { n = Stueck, why = "high" | "lost" | "won", t = letzter Fehlschlag, price, qty }
Q.PORTION_MIN = 5
Q.PORTION_KEEP = 20

function Q.PortionOn() return mod.db.quickPortion ~= "off" end

function Q.SetPortionMode(m)
    mod.db.quickPortion = (m == "off") and "off" or "smart"
    ns.Focus.chartN = nil
    ns.Focus.Update()
end

-- Spitze der Stufen: Preis und Menge der guenstigsten Stufe oder nil
local function Top(rows)
    local l = rows and ns.Data.Available(rows)[1]
    if not l then return nil end
    return l.price, l.qty
end

-- Ist an der Spitze ein anderer Stapel als bei p?
function Q.NewStack(p, rows)
    local price, qty = Top(rows)
    if not (p and price) then return true end
    if price ~= p.price then return true end
    return qty > (p.qty or 0) + math.max(Q.PORTION_MIN, math.floor((p.qty or 0) / 2))
end

-- Portion fuer key: Stueck, Grund oder nil (alles kaufen). rows = aktuelle Stufen
function Q.Portion(key, rows)
    if key == nil or not Q.PortionOn() or not ns.Data.IsCommodity(key) or Q.BuyKind(key) == "normal" then return nil end
    local p = Q.portion[key]
    if not p then return nil end
    if Now() - (p.t or 0) > Q.PORTION_KEEP or Q.NewStack(p, rows or ns.Focus.LiveRows()) then
        Q.portion[key] = nil
        return nil
    end
    return p.n, p.why
end

-- Kosten der Stueck from+1 bis from+n der Stufen (guenstigste zuerst). Rueckgabe Kosten, Stueck
local function CostRange(rows, from, n)
    local c1, g1 = ns.Data.CostOf(rows, from + n)
    local c0, g0 = ns.Data.CostOf(rows, from)
    return c1 - c0, g1 - g0
end

-- Nach einem zu hohen Preis: wie viele billige Stueck waren noch da? rows = Stufen beim Start, n = angefragt,
-- unit = Durchschnitt je Stueck vom Spiel, limit = Grenze des Kaufs. Broker sucht, wie viele der guenstigsten Stueck
-- andere vorher gekauft haben (x), sodass n Stueck ab dort den Preis des Spiels ergeben, und gibt zurueck, wie viele
-- Stueck ab x noch selbst unter der Grenze liegen (nil oder 0 = Stapel ganz weg).
function Q.RestAfterQuote(rows, n, unit, limit)
    if type(rows) ~= "table" or not Num(n) or n < 1 or not Num(unit) or not Num(limit) then return nil end
    local total = 0
    for _, l in ipairs(ns.Data.Available(rows)) do total = total + l.qty end
    if total < 1 then return nil end
    local function Avg(from, m)
        local c, g = CostRange(rows, from, m)
        if g < 1 then return math.huge end
        return c / g
    end
    -- kleinstes x mit Durchschnitt >= Preis des Spiels (der Durchschnitt steigt mit x)
    local lo, hi = 0, total
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if Avg(mid, n) >= unit - 0.5 then hi = mid else lo = mid + 1 end
    end
    -- Stueck ab x, die selbst hoechstens limit kosten (vorsichtig: nicht bis an den Rand des Durchschnitts)
    local skip, rest = lo, 0
    for _, l in ipairs(ns.Data.Available(rows)) do
        local q = l.qty
        if skip > 0 then local t = math.min(skip, q); skip, q = skip - t, q - t end
        if q > 0 then
            if l.price > limit then break end
            rest = rest + q
        end
    end
    return rest
end

-- Ergebnis eines Kaufs aus dem Einkaufen: Portion anpassen (Radar ruft es auf)
function Q.PortionLearn(job, what, unit)
    if not (job and job.quick and not job.items and Q.PortionOn() and job.key ~= nil) then return end
    local key, n = job.key, tonumber(job.qty) or 0
    local p = Q.portion[key]
    local price, qty = Top(job.rows)
    local function Set(m, why)
        Q.portion[key] = { n = math.max(1, m), why = why, t = Now(), price = price or (p and p.price), qty = qty or (p and p.qty) }
    end
    if what == "won" then
        if p then p.n, p.why = p.n * 2, "won" end
    elseif what == "lost" then
        if n > Q.PORTION_MIN then Set(math.max(Q.PORTION_MIN, math.floor(n * 2 / 3)), "lost")
        elseif p then p.t = Now() end   -- schon klein: bleibt, der Stapel gilt weiter als umkaempft
    elseif what == "high" then
        local rest = Q.RestAfterQuote(job.rows, n, unit, job.limit)
        if rest and rest >= 1 then
            -- Spitze nach dem Fehlschlag: derselbe Preis mit weniger Menge (sonst gaelte der Rest als neuer Stapel)
            Set(math.min(rest, math.max(1, n - 1)), "high")
            Q.portion[key].qty = rest
        elseif p then p.t = Now() end
    end
    Q.Trace("portion %s %s -> %s", tostring(what), tostring(n), tostring(Q.portion[key] and Q.portion[key].n))
end

---------------------------------------------------------------------------
-- ab 0.168 (KarloDerBaer 28.11.2026): Direktkauf bleibt am Ziel. Das Spiel verkauft alles oder nichts, ein Klick
-- kauft deshalb nicht immer die ganze Menge. Was schon gekauft ist, zaehlt Broker mit (Q.dgot), die naechsten Klicks
-- kaufen nur den Rest ("Noch 40 kaufen"). Ist die Menge erreicht, beginnt das naechste Ziel wieder bei der ganzen
-- Menge. Neue Menge, anderer Tab oder anderer Gegenstand: von vorn. Aus einer Einkaufsliste folgt die Menge ohnehin
-- dem, was dort fehlt (Q.ListQty), dann zaehlt Broker nicht mit.
---------------------------------------------------------------------------
Q.dgot = {}   -- [Schluessel] = schon gekaufte Stueck zum aktuellen Ziel

-- Ziel und schon gekauft fuer key im Direktkauf oder nil (kein Ziel, oder noch nichts davon gekauft)
function Q.DirectProgress(key)
    if key == nil or Q.BuyKind(key) ~= "normal" or Q.fromList[key] ~= nil then return nil end
    local target = Q.QtyStored(key)
    local got = Q.dgot[key]
    if not (Num(target) and target >= 1 and Num(got) and got > 0) then return nil end
    if got >= target then Q.dgot[key] = nil; return nil end
    return target, got
end

function Q.DirectBought(key, n)
    if key == nil or not Num(n) or n <= 0 or Q.BuyKind(key) ~= "normal" or Q.fromList[key] ~= nil then return end
    if not ns.Data.IsCommodity(key) then return end
    local target = Q.QtyStored(key)
    if not (Num(target) and target >= 1) then return end
    local got = (Q.dgot[key] or 0) + n
    Q.dgot[key] = got < target and got or nil
end

-- Hoechstmenge oder nil (Alle)
-- ab 0.167 (Board KarloDerBaer 27.11.2026): Einzelstuecke immer 1 (ein Klick kauft eine Auktion). Ohne Haken Limit
-- und Gleitend gibt es kein Alle: dann gilt 1, bis man eine Zahl waehlt. Mit Haken heisst die Zeile Max. Menge.
function Q.QtyWant(key)
    if key ~= nil and not ns.Data.IsCommodity(key) then return 1 end
    local v = Q.QtyStored(key)
    if Num(v) and v >= 1 then
        local target, got = Q.DirectProgress(key)   -- ab 0.168: Direktkauf, nur noch der Rest
        if target then return math.max(1, target - got) end
        return v
    end
    -- Klick auf eine Stufe (Q.pick) nimmt weiter alles bis dorthin
    if key ~= nil and Q.BuyKind(key) == "normal" and not Num(Q.pick[key]) then return 1 end
    return nil
end

-- ab 0.167: Min. Menge (nur mit Haken Limit oder Gleitend, nur Massenware). Unter dem Limit muessen mindestens so
-- viele Stueck zu haben sein, sonst gibt es nichts zu kaufen. nil = aus. Gespeichert in Beobachten (qmin).
Q.minQty = {}   -- [Schluessel] = Zahl dieser Sitzung (0 = aus)
function Q.MinMax() return math.max(1, math.floor(tonumber(mod.db.quickMinMax) or 100)) end

function Q.MinQty(key)
    if key == nil or not ns.Data.IsCommodity(key) or Q.BuyKind(key) == "normal" then return nil end
    local v = Q.minQty[key]
    if v == nil then v = SavedField(key, "qmin") end
    if Num(v) and v >= 1 then return math.floor(v) end
    return nil
end

function Q.SetMinQty(n)
    local key = ns.Focus.key
    if key == nil then return end
    n = tonumber(n)
    Q.minQty[key] = (n and n >= 1) and math.floor(n) or 0
    Changed()
end

-- ab 0.167: Werte fuer Beobachten (nur was selbst gewaehlt oder schon gespeichert ist, keine Vorgaben)
function Q.KindValues(key)
    local ref = Q.ref[key] or SavedField(key, "qref")
    local margin = Q.margin[key]
    if margin == nil then margin = SavedField(key, "qmargin") end
    local mn = Q.minQty[key]
    if mn == nil then mn = SavedField(key, "qmin") end
    return ref, margin, mn
end

-- ab 0.168: Tab und Ausloeser fuer Beobachten (nur selbst gewaehlte Werte, keine Vorgaben). Der Tab wird erst
-- gespeichert, wenn man ihn selbst gewechselt hat.
function Q.BandValues(key)
    return Q.tab[key], Q.trig[key], Q.trigPct[key], Q.trigFix[key]
end

-- n = Menge, nil oder < 1 = Alle
function Q.SetQty(n)
    local F = ns.Focus
    local key = F.key
    if key == nil then return end
    n = tonumber(n)
    Q.qty[key] = (n and n >= 1) and math.floor(n) or 0
    Q.fromList[key] = nil   -- ab 0.136: eigene Wahl geht vor
    Q.dgot[key] = nil       -- ab 0.168: neue Menge, neues Ziel
    F.Store()
    F.Update()
end

-- Beschriftung des Kaufknopfs: "Kaufen 40 fuer 60s 80c" (ohne Menge nur "Kaufen")
function Q.BuyLabel(d)
    local best = d and not d.gone and d.best or nil
    local qty = best and Num(best.qty) and best.qty or 0
    if qty < 1 then return L.BUY_BUY end
    -- ab 0.168: Direktkauf mit Rest zum Ziel
    if d.key ~= nil and Q.DirectProgress(d.key) then return L.QUICK_BUY_LEFT:format(qty, Money(Num(best.cost) and best.cost or 0)) end
    return L.QUICK_BUY_FOR:format(qty, Money(Num(best.cost) and best.cost or 0))
end

-- Urteil: Text, Farbe, Satz
function Q.Verdict(d)
    local F = ns.Focus
    if not F.ManualLimit(F.key) then return L.QUICK_V_NOLIMIT, GREY, L.QUICK_W_NOLIMIT end
    if not d or d.gone then return L.FOCUS_V_WAIT, GREY, L.FOCUS_W_WAIT end
    if (d.maxQty or d.qty or 0) < 1 then
        return L.QUICK_V_NONE, GREY, mod.db.quickAlarm ~= false and L.QUICK_W_NONE_ALARM or L.QUICK_W_NONE
    end
    if d.cant then return L.FOCUS_V_CANT, ORANGE, L.FOCUS_W_GOLD end
    local lv = ns.Data.Available(d.rows or {})
    return L.QUICK_V_BUY, GREEN, L.QUICK_W_BUY:format(d.maxQty or d.qty or 0, lv[1] and Money(lv[1].price) or "-")
end

function Q.Summary(d)
    local qty, cost
    if d and not d.gone then
        local best = d.best or {}
        qty = Num(best.qty) and best.qty > 0 and best.qty or nil
        cost = qty and Num(best.cost) and best.cost or nil
    end
    return L.QUICK_SUMMARY:format(qty and tostring(qty) or "-", cost and Money(cost) or "-")
end

---------------------------------------------------------------------------
-- Alarm und neue Stufen (bei jeder neuen Antwort einmal)
---------------------------------------------------------------------------
-- Stufen einer Antwort als Preis -> Menge (nur fremde Angebote)
local function Levels(rows)
    local m = {}
    for _, l in ipairs(ns.Data.Available(rows or {})) do m[l.price] = (m[l.price] or 0) + l.qty end
    return m
end

-- Neue oder groessere Stufen seit der letzten Antwort merken
function Q.NoteTiers(key, rows)
    if type(rows) ~= "table" then return end
    local p = Q.prev
    if p and p.rows == rows then return end
    local levels = Levels(rows)
    if p and p.key == key then
        local untilT = Now() + Q.NEW_SEC
        for price, qty in pairs(levels) do
            if qty > (p.levels[price] or 0) then Q.newTiers[price] = untilT end
        end
    end
    Q.prev = { key = key, rows = rows, levels = levels }
end

function Q.IsNew(price)
    local t = Q.newTiers[price]
    return t ~= nil and Now() < t
end

-- Ton, wenn nach einer Antwort ohne Menge unter Kaufen bis jetzt etwas da ist. Der Kaufknopf leuchtet, solange
-- etwas da ist. Gleiche Antwort (z. B. nur Kaufen bis geaendert): kein Ton.
function Q.CheckAlarm(key, rows, qty, button)
    local a = Q.alarm
    -- ab 0.114: neue Antwort mit etwas Kaufbarem -> Abfragen kurz anhalten, damit die Bremse des Spiels beim Klick frei
    -- ist. Ohne Kaufbares keine Pause.
    if rows ~= nil and rows ~= a.rows then
        local sec = tonumber(mod.db.quickHold) or 1
        if qty > 0 and sec > 0 then
            Q.hold = { key = key, rows = rows, untilT = Now() + sec }
            Q.Trace("hold %s s qty=%s", sec, qty)
            if C_Timer then C_Timer.After(sec + 0.05, function() if ns.Focus.Shown() then ns.Focus.Update() end end) end
        else
            Q.hold = nil
        end
    end
    -- ab 0.111: Gelegenheit = etwas Kaufbares unter Kaufen bis taucht auf (mit Haken ohne einzelnes Lockangebot)
    if rows ~= nil and rows ~= a.rows and qty > 0 and (a.key ~= key or (a.qty or 0) == 0) then
        local s = Q.Session(key)
        s.opps = (s.opps or 0) + 1
        Q.opp[key] = { t = Now(), won = false }
        if ns.QuickStats and ns.QuickStats.OnOpp then ns.QuickStats.OnOpp(key) end   -- ab 0.140: Quote ueber Tage
    end
    -- ab 0.111: Ton fuer ein neues fremdes Lockangebot, solange der Kaufknopf noch gesperrt ist (zum Vorbereiten)
    if Q.baitPing == key then
        Q.baitPing = nil
        if qty == 0 and mod.db.quickBaitAlarm ~= false and ns.Radar.PlayAlert then ns.Radar.PlayAlert(mod.db.quickBaitSound or "ping") end
    end
    if rows ~= nil and rows ~= a.rows then
        if a.key == key and (a.qty or 0) == 0 and qty > 0 and mod.db.quickAlarm ~= false and ns.Radar.PlayAlert then
            ns.Radar.PlayAlert(mod.db.quickSound or "raid")
        end
        Q.alarm = { key = key, rows = rows, qty = qty }
    elseif a.key == key then
        a.qty = qty
    end
    if button then
        if qty > 0 and button.LockHighlight then button:LockHighlight()
        elseif button.UnlockHighlight then button:UnlockHighlight() end
    end
end

---------------------------------------------------------------------------
-- Lockangebot
---------------------------------------------------------------------------
-- Vorschlag (ab 0.107): Kaufen bis minus quickBaitPct Prozent (nil ohne Kaufen bis)
function Q.Suggest()
    local F = ns.Focus
    local base = F.ManualLimit(F.key)
    if not Num(base) then return nil, nil end
    local pct = (tonumber(mod.db.quickBaitPct) or 50) / 100
    return math.max(1, math.floor(base * (1 - pct))), base
end

-- ab 0.107: Kaufen bis des Aufkaufs fuer key: in Beobachten gespeichert, sonst was der Aufkauf gerade rechnet
function Q.BuyoutLimit(key)
    local F, Wt = ns.Focus, ns.Watch
    if Wt and Wt.Is(key) then
        local l = Wt.Limit(key)
        if Num(l) and l > 0 then return l end
    end
    local keep, keepOn = mod.db.focusMode, mod.db.focusBuyout
    mod.db.focusMode, mod.db.focusBuyout = "buyout", true
    local ok, d = pcall(F.Plan)
    mod.db.focusMode, mod.db.focusBuyout = keep, keepOn
    if ok and type(d) == "table" and not d.gone and Num(d.limit) and d.limit > 0 then return d.limit end
    return nil
end

-- Schnellkauf ohne Kaufen bis: das des Aufkaufs uebernehmen. Ab 0.107.1 jedes Mal, wenn das Feld leer ist, nur nicht
-- nachdem man es im Schnellkauf selbst geleert hat (Q.limitCleared, bis man wieder einen Wert eintraegt). In 0.107.0
-- galt "einmal je Gegenstand": Oeffnete man den Fokus aus Beobachten, waehrend der Schnellkauf eingestellt war, war das
-- Einmal schon verbraucht, bevor der Fokus in den gespeicherten Aufkauf wechselte. Danach blieb das Feld leer.
Q.limitCleared = {}
function Q.NoteLimit(key, limit)
    if key == nil then return end
    if limit then Q.limitCleared[key] = nil elseif Q.On() then Q.limitCleared[key] = true end
end

-- ab 0.120 (KarloDerBaer 19.11.2026): Kaufen bis ohne eigenen Wert = quickLimitPct Prozent (Vorgabe 50) des
-- guenstigsten fremden Angebots, mindestens der Haendlerpreis. Ein einzelnes Stueck ganz unten (Lockangebot) zaehlt
-- nicht, wenn es darueber weitere Angebote gibt. cheapest = guenstigster Preis, falls bekannt (sonst live oder Stand).
-- Bis 0.119 kam Kaufen bis vom Aufkauf (Q.BuyoutLimit).
function Q.DefaultLimit(key, cheapest)
    if key == nil then return nil end
    local D = ns.Data
    if not Num(cheapest) then
        local live = ns.Buy.live and ns.Buy.live[key]
        local lv = live and live.rows and D.Available(live.rows) or {}
        local first = lv[1]
        if first and first.qty <= 1 and lv[2] then first = lv[2] end
        cheapest = first and first.price or nil
    end
    if not Num(cheapest) then
        local e = D.Lookup(key)
        cheapest = type(e) == "table" and not e.gone and Num(e.m) and e.m or nil
    end
    local pct = tonumber(mod.db.quickLimitPct) or 50
    local v = Num(cheapest) and math.floor(cheapest * pct / 100) or 0
    local hp = ns.VendorPrice(D.ItemID(key) or key)
    if Num(hp) and hp > v then v = hp end
    return v > 0 and v or nil
end

function Q.EnsureLimit()
    local F = ns.Focus
    local key = F.key
    if key == nil or not Q.On() or Q.limitCleared[key] or F.ManualLimit(key) then return end
    local v = Q.DefaultLimit(key)
    if Num(v) and v > 0 then
        F.manualLimit = { key = key, price = math.floor(v) }
        F.manualSrc = F.manualSrc or "own"
    end
end

function Q.ManualPrice(key)
    local m = Q.manual
    if m and key ~= nil and m.key == key and Num(m.price) and m.price > 0 then return m.price end
    return nil
end

function Q.Price(key)
    return Q.ManualPrice(key) or (Q.Suggest())
end

-- Getippter Lockpreis (0 = wieder der Vorschlag)
function Q.SetPriceTyped(amount)
    local F = ns.Focus
    if F.key == nil then return end
    if Num(amount) and amount > 0 then Q.manual = { key = F.key, price = math.floor(amount) } else Q.manual = nil end
    F.Update()
end

-- ab 0.132 (U0, Konzept Peon_Broker_Schlank.md 4.2): Menge des Lockangebots je Gegenstand, Vorgabe 1. Gespeichert in
-- PeonBrokerDB.baitQty[Schluessel], nur wenn nicht 1 (Speichern geschieht von selbst).
Q.BAIT_QTY_MAX = 9999
function Q.BaitQty(key)
    local t = mod.acc.baitQty
    local n = key ~= nil and type(t) == "table" and tonumber(t[key]) or nil
    if n and n >= 1 then return math.min(Q.BAIT_QTY_MAX, math.floor(n)) end
    return 1
end

function Q.SetBaitQty(n)
    local F = ns.Focus
    local key = F.key
    if key == nil then return end
    n = tonumber(n)
    if not n or n < 1 then return end   -- leeres Feld beim Tippen: Wert bleibt, bis eine Zahl dasteht
    n = math.min(Q.BAIT_QTY_MAX, math.floor(n))
    if type(mod.acc.baitQty) ~= "table" then mod.acc.baitQty = {} end
    mod.acc.baitQty[key] = n > 1 and n or nil
    F.Update()
end

-- Stueck in den Taschen (wie das Spiel zaehlt) oder nil
function Q.BagCount(key)
    if not ns.Stock or key == nil then return nil end
    local ok, bags = pcall(ns.Stock.Counts, ns.Data.ItemID(key), nil)
    return ok and Num(bags) and bags or nil
end

-- Gegenstand in den Taschen finden: bag, slot
function Q.FindBag(itemID)
    local C = rawget(_G, "C_Container")
    local slots = (C and C.GetContainerNumSlots) or rawget(_G, "GetContainerNumSlots")
    local idOf = (C and C.GetContainerItemID) or rawget(_G, "GetContainerItemID")
    if not (slots and idOf) then return nil end
    for bag = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do
        local okn, n = pcall(slots, bag)
        for slot = 1, (okn and tonumber(n) or 0) do
            local ok, id = pcall(idOf, bag, slot)
            if ok and id == itemID then return bag, slot end
        end
    end
    return nil
end

-- Lockangebot fuer key: steht es (eigene Menge zum Lockpreis im Live-Stand)?
function Q.BaitFor(key)
    local b = Q.bait
    if b and b.key == key then return b end
    return nil
end

-- Zustand nach einer neuen Antwort: eigenes Angebot zum Lockpreis nicht mehr da -> weg (gekauft oder abgelaufen)
function Q.CheckBait(key, rows, t)
    local b = Q.BaitFor(key)
    if not (b and b.state == "up" and type(rows) == "table" and Num(t)) then return end
    if t <= (b.wall or 0) then return end   -- Antwort von vor dem Einstellen
    for _, r in ipairs(rows) do
        if r.price == b.price and (r.own or 0) > 0 then b.seen = true; return end
    end
    -- ab 0.114.1 auch ohne vorher gesehen, wenn die Antwort sicher nach dem Einstellen kam (2 Sek. Abstand)
    if b.seen or t > (b.wall or 0) + 2 then b.state, b.goneT = "gone", Now() end
end

-- Knopf Einstellen (zweiter Klick bestaetigt, wenn das Spiel nachfragt)
function Q.Post()
    local F = ns.Focus
    local key = F.key
    if key == nil or not AHOpen() then return end
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.SELL_COMBAT); return end
    local ah = AHApi()
    local b = Q.bait
    if b and b.key == key and b.state == "confirm" then
        local ok = ah.ConfirmPostCommodity and pcall(ah.ConfirmPostCommodity, b.loc, Q.DURATION, b.qty or 1, b.price)
        if not ok then Q.bait = nil; mod:Print(L.QUICK_POST_FAILED) else b.state, b.t = "posting", Now() end
        F.Update()
        return
    end
    if b and (b.state == "posting" or b.state == "cancelling") and Now() - b.t < Q.POST_WAIT then return end
    if not ns.Data.IsCommodity(key) then mod:Print(L.QUICK_ONLY_MASS); return end
    local price = Q.Price(key)
    if not Num(price) then return end
    local id = ns.Data.ItemID(key)
    local bag, slot = Q.FindBag(id)
    local IL = rawget(_G, "ItemLocation")
    if not bag then mod:Print(L.QUICK_NO_ITEM); return end
    -- ab 0.132: Menge aus dem Feld. Das Spiel nimmt bei Massenware auch aus weiteren Stapeln.
    local qty = Q.BaitQty(key)
    if qty > 1 then
        local have = Q.BagCount(key)
        if have and have < qty then mod:Print(L.QUICK_FEW_ITEMS:format(have, qty)); return end
    end
    local okl, loc = pcall(function() return IL:CreateFromBagAndSlot(bag, slot) end)
    if not (okl and loc and ah.PostCommodity) then mod:Print(L.QUICK_POST_FAILED); return end
    local ok, needs = pcall(ah.PostCommodity, loc, Q.DURATION, qty, price)
    if not ok then mod:Print(L.QUICK_POST_FAILED); return end
    local dep
    if ah.CalculateCommodityDeposit then
        local okd, v = pcall(ah.CalculateCommodityDeposit, id, Q.DURATION, qty)
        if okd and Num(v) then dep = v end
    end
    Q.bait = { key = key, price = price, qty = qty, t = Now(), wall = time(), loc = loc, deposit = dep, state = needs == true and "confirm" or "posting" }
    ns.Radar.lastSend = Now()   -- Einstellen zaehlt wie eine Abfrage (Bremse des Spiels)
    if needs == true then mod:Print(L.QUICK_CONFIRM_ASK) end
    F.Update()
end

-- Das Spiel fragt nach (z. B. Preis weit unter dem Markt)
function Q.OnPostWarning()
    local b = Q.bait
    if b and b.state == "posting" and Now() - b.t < Q.POST_WAIT then
        b.state = "confirm"
        mod:Print(L.QUICK_CONFIRM_ASK)
        if ns.Focus.Shown() then ns.Focus.Update() end
    end
end

-- Auktion erstellt: Lockangebot steht
function Q.OnCreated(auctionID)
    local b = Q.bait
    if not (b and b.state == "posting" and Now() - b.t < Q.POST_WAIT) then return end
    b.state, b.id, b.t, b.wall = "up", Num(auctionID) and auctionID or nil, Now(), time()
    local s = Q.Session(b.key)
    s.baits = s.baits + 1
    s.deposit = s.deposit + (b.deposit or 0)
    local m = Q.marks[b.key] or {}
    m[#m + 1] = Now()
    Q.marks[b.key] = m
    Q.AddBait(b.key, Now(), b.price, true)
    Q.Trace("bait up price=%s id=%s", b.price, b.id)
    mod:Print(L.QUICK_POSTED:format(b.qty or 1, Money(b.price)))
    if ns.Focus.Shown() then ns.Focus.Update() end
end

-- Fehler des Auktionshauses, waehrend wir einstellen oder zurueckziehen
function Q.OnError()
    local b = Q.bait
    if b and (b.state == "posting" or b.state == "confirm" or b.state == "cancelling") and Now() - b.t < Q.POST_WAIT then
        if b.state == "cancelling" then b.state = "up" else Q.bait = nil end
        mod:Print(L.QUICK_POST_FAILED)
        if ns.Focus.Shown() then ns.Focus.Update() end
    end
end

-- Zurueckziehen. Ab 0.132 ohne Knopf (Konzept Peon_Broker_Schlank.md 4.2), die Funktion bleibt.
function Q.Cancel()
    local b = Q.bait
    if not (b and b.state == "up" and b.id) then return end
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.SELL_COMBAT); return end
    local ah = AHApi()
    local ok = ah and ah.CancelAuction and pcall(ah.CancelAuction, b.id)
    if not ok then mod:Print(L.LOTS_CANCEL_FAILED); return end
    b.state, b.t = "cancelling", Now()
    ns.Focus.Update()
end

function Q.OnCanceled(auctionID)
    local b = Q.bait
    if b and b.state == "cancelling" and (auctionID == nil or auctionID == b.id) then
        b.state = "cancelled"
        if ns.Focus.Shown() then ns.Focus.Update() end
    -- ab 0.114.1: Das Spiel meldet ein verkauftes Angebot ebenfalls mit AUCTION_CANCELED und dessen Nummer (Kaufprotokoll
    -- 19.11.2026: Lockangebot nach 0,35 Sek. weg, bevor eine Abfrage es zeigte). Vorher hiess "weg" nur, was eine
    -- Antwort schon einmal gezeigt hatte, der Zustand blieb sonst bei "steht seit".
    elseif b and b.state == "up" and b.id ~= nil and auctionID == b.id then
        b.state, b.goneT = "gone", Now()
        Q.Trace("bait gone id=%s", b.id)
        if ns.Focus.Shown() then ns.Focus.Update() end
    end
end

-- ab 0.125 (Wunsch KarloDerBaer 20.11.2026): Zeile "Einbruch" statt "Letztes": tiefster Einbruch dieser Sitzung und
-- Anzahl. Rueckgabe Text, Tooltip-Zeilen
function Q.DipText(key)
    local s = key ~= nil and Q.sessions[key]
    local rule = ns.QuickStats and L.QS_TIP_DIP:format(tonumber(mod.db.quickDipPct) or 5) or nil
    if not (s and (s.dips or 0) > 0 and Num(s.dipLow)) then return GREY .. L.QUICK_DIP_NONE .. "|r", { rule } end
    local tip = {}
    local d = s.lastDip
    if d then
        tip[#tip + 1] = L.QUICK_DIP_TIP_LAST:format(Money(d.price), d.qty or 0, ns.Radar.ShortAge(math.max(0, math.floor(Now() - d.t))))
    end
    tip[#tip + 1] = rule
    return L.QUICK_DIP:format(Money(s.dipLow), s.dips), tip
end

-- ab 0.125: letzter Kauf dieser Sitzung unter dem Kaufknopf
function Q.LastBuyText(key)
    local s = key ~= nil and Q.sessions[key]
    local b = s and s.lastBuy
    if not b then return GREY .. L.QUICK_LASTBUY_NONE .. "|r" end
    local avg = Num(b.cost) and b.n > 0 and Money(math.floor(b.cost / b.n + 0.5)) or "-"
    return L.QUICK_LASTBUY:format(b.n, avg, ns.Radar.ShortAge(math.max(0, math.floor(Now() - b.t))))
end

-- Zustand des Lockangebots als Text
function Q.StateText(key)
    local b = Q.BaitFor(key)
    if not b then return GREY .. L.QUICK_BAIT_NONE .. "|r" end
    local ago = math.max(0, math.floor(Now() - b.t))
    if b.state == "confirm" then return ORANGE .. L.QUICK_BAIT_CONFIRM .. "|r" end
    if b.state == "posting" then return GREY .. L.QUICK_BAIT_POSTING .. "|r" end
    if b.state == "cancelling" then return GREY .. L.QUICK_BAIT_CANCELLING .. "|r" end
    if b.state == "cancelled" then return GREY .. L.QUICK_BAIT_CANCELLED .. "|r" end
    if b.state == "gone" then return YELLOW .. L.QUICK_BAIT_GONE:format(Money(b.price)) .. "|r" end
    return GREEN .. L.QUICK_BAIT_UP:format(b.qty or 1, Money(b.price), ns.Radar.ShortAge(ago)) .. "|r"
end

function Q.BalanceText(key)
    local s = Q.sessions[key]
    if not s or (s.baits == 0 and s.bought == 0) then return GREY .. L.QUICK_BALANCE_NONE .. "|r" end
    local avg = s.bought > 0 and Money(math.floor(s.cost / s.bought + 0.5)) or "-"
    return GREY .. L.QUICK_BALANCE:format(s.baits, Money(s.deposit), s.bought, Money(s.cost), avg) .. "|r"
end

-- Kauf fertig (Radar.lua R.FinishJob): in die Bilanz
function Q.OnBought(job, n, cost)
    if not (job and job.quick and n and n > 0) then return end
    local s = Q.Session(job.key)
    s.bought = s.bought + n
    s.cost = s.cost + (Num(cost) and cost or 0)
    s.buys = (s.buys or 0) + 1
    s.lastBuy = { n = n, cost = Num(cost) and cost or nil, t = Now() }   -- ab 0.125: unter dem Kaufknopf
    if ns.QuickStats then ns.QuickStats.OnBought(job.key, n, cost) end   -- ab 0.126: bleibt ueber den Logout
    Q.DirectBought(job.key, n)   -- ab 0.168: Direktkauf bleibt am Ziel
    -- ab 0.111: die letzte Gelegenheit gilt als genutzt (einmal)
    local o = Q.opp[job.key]
    if o and not o.won then
        o.won = true; s.won = (s.won or 0) + 1
        if ns.QuickStats and ns.QuickStats.OnWon then ns.QuickStats.OnWon(job.key) end   -- ab 0.140
    end
end

-- ab 0.111: Kauf aus dem Schnellkauf ohne Erfolg (fehlgeschlagen, zu teuer, Fehler)
function Q.OnFailed(job)
    if not (job and job.quick) then return end
    local s = Q.Session(job.key)
    s.fails = (s.fails or 0) + 1
end

-- ab 0.111: Zeile "Gekauft": Stueck, Quote der genutzten Gelegenheiten. Rueckgabe Text, Tooltip-Zeilen
-- ab 0.125 mit Durchschnittspreis dieser Sitzung
function Q.BoughtText(key)
    local s = key ~= nil and Q.sessions[key]
    local opps, won = s and s.opps or 0, s and s.won or 0
    local bought = s and s.bought or 0
    local pct = opps > 0 and math.floor(won * 100 / opps + 0.5) or nil
    local text = pct and L.QUICK_MV_BOUGHT:format(bought, pct) or L.QUICK_MV_BOUGHT0:format(bought)
    if bought > 0 and Num(s.cost) and s.cost > 0 then
        text = text .. ", " .. L.QUICK_AVG_SHORT:format(Money(math.floor(s.cost / bought + 0.5)))
    end
    local tip = { L.QUICK_MV_TIP_BOUGHT:format(won, opps, s and s.buys or 0, s and s.fails or 0) }
    tip[#tip + 1] = Q.SkipOn(key) and L.QUICK_MV_TIP_BOUGHT_SKIP or L.QUICK_MV_TIP_BOUGHT_ALL
    return text, tip
end

---------------------------------------------------------------------------
-- Diagramm: guenstigster Preis, Menge unter Kaufen bis, Striche fuer eigene Lockangebote
---------------------------------------------------------------------------
function Q.Series(limit)
    local M = ns.Measure
    local c = M and M.cur
    if not c or #c.samples < 2 then return nil end
    local under, mins, marks = {}, {}, {}
    local own = Q.marks[c.key] or {}
    for i, s in ipairs(c.samples) do
        local q = 0
        if Num(limit) then
            for _, l in ipairs(s.lv or {}) do if l.price <= limit then q = q + l.qty end end
        end
        under[i], mins[i] = q, s.min
        local prevT = i > 1 and c.samples[i - 1].t or -math.huge
        for _, t in ipairs(own) do
            if t > prevT and t <= s.t then marks[i] = true end
        end
    end
    return #c.samples, under, mins, marks
end

---------------------------------------------------------------------------
-- Verlauf fuer das Diagramm im Einkaufen (ab 0.134, Schritt U2, Konzept Peon_Broker_Schlank.md 4.4). Die Messung
-- behaelt nur die letzten Measure.KEEP Abfragen (bei 90 je Minute knapp 3 Min.). Fuer die Zeitraeume 5, 15 und 60
-- Minuten merkt sich Broker je Q.HIST_STEP Sekunden einen kleinen Eintrag: tiefster Preis darin und die untersten
-- Q.HIST_LEVELS Preisstufen der letzten Abfrage. So rechnet das Diagramm die Menge unter Kaufen bis auch nach einer
-- Aenderung von Kaufen bis fuer den ganzen Zeitraum neu (wie bisher). Nur im Spiel, nichts wird gespeichert.
---------------------------------------------------------------------------
Q.HIST_STEP = 3        -- Sekunden je Eintrag
Q.HIST_SPAN = 3600     -- so weit zurueck (laengster Zeitraum)
Q.HIST_LEVELS = 16     -- so viele Preisstufen je Eintrag
Q.HIST_KEYS = 3        -- Verlauf fuer so viele Gegenstaende (zuletzt im Einkaufen)
Q.CHART_SLOTS = 100    -- Plaetze im Diagramm (5 Min.: je 3 Sek., 60 Min.: je 36 Sek.)
Q.MARK_KEEP = 200
Q.hist = {}            -- [Schluessel] = { n = Abfragen, last = Zeit, list = { { slot, t, min, p = { Preise }, q = { Mengen } } } }
Q.dipTimes = {}        -- [Schluessel] = { Zeiten der Einbrueche } fuer das Diagramm

function Q.Record(key, s)
    if key == nil or type(s) ~= "table" or not Num(s.t) then return end
    local h = Q.hist[key]
    if not h then h = { n = 0, list = {} }; Q.hist[key] = h end
    h.n, h.last = h.n + 1, s.t
    local list = h.list
    local slot = math.floor(s.t / Q.HIST_STEP)
    local e = list[#list]
    if not e or e.slot ~= slot then
        e = { slot = slot }
        list[#list + 1] = e
    end
    e.t = s.t
    if Num(s.min) and (not Num(e.min) or s.min < e.min) then e.min = s.min end
    local p, q = {}, {}
    for i, l in ipairs(s.lv or {}) do
        if i > Q.HIST_LEVELS then break end
        p[i], q[i] = l.price, l.qty
    end
    e.p, e.q = p, q
    -- ab 0.167: ganze Menge im Markt (alle Stufen) fuer die Zeile Menge mit Trend (Q.QtyTrend)
    local all = 0
    for _, l in ipairs(s.lv or {}) do if Num(l.qty) then all = all + l.qty end end
    e.all = all
    local from = s.t - Q.HIST_SPAN
    while list[1] and list[1].t < from do table.remove(list, 1) end
    -- nur die letzten Gegenstaende behalten
    local n, oldest, oldKey = 0, nil, nil
    for k, o in pairs(Q.hist) do
        n = n + 1
        if k ~= key and (oldest == nil or (o.last or 0) < oldest) then oldest, oldKey = o.last or 0, k end
    end
    if n > Q.HIST_KEYS and oldKey ~= nil then Q.hist[oldKey] = nil end
end

local function UnderAt(e, limit)
    if not Num(limit) then return 0 end
    local sum = 0
    for i, p in ipairs(e.p or {}) do
        if p > limit then break end
        sum = sum + (e.q[i] or 0)
    end
    return sum
end

-- Reihen fuer das Diagramm: minutes Minuten bis zur letzten Abfrage, Q.CHART_SLOTS Plaetze. Rueckgabe nil (weniger
-- als zwei Abfragen) oder n, Menge unter Kaufen bis (letzter Eintrag je Platz), tiefster Preis je Platz, eigene und
-- fremde Lockangebote, Einbrueche ({ [Platz] = true }).
function Q.ChartSeries(key, limit, minutes, now)
    local h = key ~= nil and Q.hist[key]
    if not h or h.n < 2 then return nil end
    local slots = Q.CHART_SLOTS
    local span = (tonumber(minutes) or 5) * 60
    now = now or h.last
    local w, from = span / slots, now - span
    local function Slot(t)
        if not Num(t) or t <= from or t > now then return nil end
        return math.max(1, math.min(slots, math.ceil((t - from) / w)))
    end
    local under, mins, own, other, dips, at = {}, {}, {}, {}, {}, {}
    for _, e in ipairs(h.list) do
        local i = Slot(e.t)
        if i then
            if Num(e.min) and (mins[i] == nil or e.min < mins[i]) then mins[i] = e.min end
            if at[i] == nil or e.t >= at[i] then at[i], under[i] = e.t, UnderAt(e, limit) end
        end
    end
    for _, b in ipairs(Q.baits[key] or {}) do
        local i = Slot(b.t)
        if i then if b.own then own[i] = true else other[i] = true end end
    end
    for _, t in ipairs(Q.dipTimes[key] or {}) do
        local i = Slot(t)
        if i then dips[i] = true end
    end
    return slots, under, mins, own, other, dips
end

---------------------------------------------------------------------------
-- Marktstabilitaet (ab 0.165, KarloDerBaer 26.11.2026, bis 0.164 Lebhaftigkeit). Zaehlt nur noch besondere
-- Ereignisse je Minute: Preisspruenge, Einbrueche und fremde Lockangebote. Einstellungen und Kaeufe zaehlen nicht mehr,
-- bei Massenware hiess der Markt sonst fast immer lebhaft. Die Warenbewegung steht in der Zeile Bewegung.
-- Grundlage ist die laufende Messung (Measure.lua, Fenster focusWindow).
--   unruhig  (Code high) mindestens quickRestless Ereignisse je Minute
--   stabil   (Code low)  weniger als quickCalm Ereignisse je Minute
--   bewegt   (Code mid)  sonst
-- Bis 0.164 (Marktbewegung ab 0.108): Einstellungen + Kaeufe + Preisspruenge, lebhaft ab quickMoveIn Einstellungen
-- und quickMoveAll Ereignissen, ruhig unter quickMoveLow. Diese drei Werte ruhen.
---------------------------------------------------------------------------
-- Einbrueche und fremde Lockangebote eines Gegenstands in den secs Sekunden bis t. Rueckgabe dips, baits
function Q.EventsIn(key, t, secs)
    if key == nil or not Num(t) or not Num(secs) or secs <= 0 then return 0, 0 end
    local from = t - secs
    local dips, baits = 0, 0
    for _, x in ipairs(Q.dipTimes[key] or {}) do if x > from and x <= t then dips = dips + 1 end end
    for _, b in ipairs(Q.baits[key] or {}) do
        if not b.own and Num(b.t) and b.t > from and b.t <= t then baits = baits + 1 end
    end
    return dips, baits
end

-- Rueckgabe code ("first", "high", "mid", "low"), Ereignisse je Minute, Teile { jumps, dips, baits, nJumps, nDips,
-- nBaits } (je Minute und Anzahl)
function Q.Movement(v, key)
    local M = ns.Measure
    M.Sync()
    if not v or (v.n or 0) < 2 or (v.elapsed or 0) < M.FIRST then return "first" end
    if key == nil then key = v.key end
    local secs = math.min(M.WINDOW, tonumber(v.secs) or 0)
    local mins = secs / 60
    local dips, baits = Q.EventsIn(key, v.t, secs)
    local p = { nJumps = v.jumps or 0, nDips = dips, nBaits = baits, jumps = v.jumpsPerMin or 0,
                dips = mins > 0 and dips / mins or 0, baits = mins > 0 and baits / mins or 0 }
    local ev = p.jumps + p.dips + p.baits
    return Q.MoveClass(ev), ev, p
end

-- Grenzen der Marktstabilitaet (Einstellungen, je Minute). Stabil hoechstens so hoch wie unruhig.
function Q.MoveLimits()
    local db = mod.db
    local hi = math.max(0.5, tonumber(db.quickRestless) or 2)
    local lo = math.min(hi, math.max(0.5, tonumber(db.quickCalm) or 0.5))
    return hi, lo
end

-- Regel als Satz fuer Tooltips
function Q.MoveRuleText()
    local hi, lo = Q.MoveLimits()
    local function D(x) return ns.Settings and ns.Settings.Dec and ns.Settings.Dec(x) or tostring(x) end
    return L.QUICK_MV_TIP_RULE:format(D(hi), D(lo))
end

-- ab 0.119: Einordnung (auch fuer QuickChances.lua), ab 0.165 nur aus den Ereignissen je Minute
function Q.MoveClass(ev)
    local hi, lo = Q.MoveLimits()
    if (ev or 0) >= hi then return "high" end
    if (ev or 0) < lo then return "low" end
    return "mid"
end

-- Menge fremder Angebote genau zum Preis in einer Abfrage (eigene zaehlen nicht, Data.Available)
local function QtyAt(s, price)
    for _, l in ipairs(s.lv or {}) do if l.price == price then return l.qty end end
    return 0
end

-- Lockangebote fortlaufend (ab 0.110). Bis 0.109 aus den Abfragen der Messung gerechnet: die behaelt nur die letzten
-- 240 Abfragen (bei 0,7 Sek. knapp 3 Min.) und beginnt bei neuem Kaufen bis oder Modus neu, die Anzeige verschwand.
-- Jetzt prueft jede neue Abfrage (Q.OnSample aus Measure.Add):
--   fremdes Lockangebot  neue Preisstufe mit genau 1 Stueck, mindestens quickBaitMinPct Prozent unter dem bisher
--                        guenstigsten fremden Angebot (ab 0.109) und hoechstens bei Kaufen bis (ab 0.110)
--   Folge                in den quickFollowSec Sekunden danach waechst die Menge genau zum Lockpreis. Waechst sie nur um
--                        1 Stueck, ist das selbst ein Lockangebot und zaehlt nicht (ab 0.110).
-- Eigene Lockangebote kommen ueber Q.OnCreated dazu (Q.AddBait).
Q.BAIT_KEEP = 200

function Q.AddBait(key, t, price, own, lastQ, reg, above)
    if key == nil or not Num(price) then return end
    if lastQ == nil then
        local c = ns.Measure and ns.Measure.cur
        local s = c and c.key == key and c.samples[#c.samples]
        lastQ = s and QtyAt(s, price) or 0
    end
    local list = Q.baits[key] or {}
    list[#list + 1] = { t = t, price = price, own = own or nil, lastQ = lastQ, added = 0, times = 0, reg = reg, above = above or nil }
    while #list > Q.BAIT_KEEP do table.remove(list, 1) end
    Q.baits[key] = list
end

-- ab 0.167 (Wunsch KarloDerBaer 27.11.2026): Trend der Menge im Markt ueber den Zeitraum des Diagramms. Vergleicht
-- die aelteste Abfrage im Zeitraum mit der neuesten. Rueckgabe jetzt, damals, Prozent, Trend ("up", "down", "flat")
-- oder nil (zu wenig Verlauf, unter Q.QTY_TREND_MIN Sekunden)
Q.QTY_TREND_PCT = 5    -- ab so viel Prozent Aenderung zeigt der Pfeil
Q.QTY_TREND_MIN = 30
function Q.QtyTrend(key, minutes)
    local h = key ~= nil and Q.hist[key]
    if not h then return nil end
    local list = h.list or {}
    local last = list[#list]
    if not (last and Num(last.all)) then return nil end
    local from = last.t - (minutes or 5) * 60
    local first
    for _, e in ipairs(list) do
        if e.t >= from and Num(e.all) then first = e; break end
    end
    if not first or last.t - first.t < Q.QTY_TREND_MIN then return nil end
    local now, old = last.all, first.all
    local pct = old > 0 and (now - old) * 100 / old or (now > 0 and 100 or 0)
    local trend = "flat"
    if pct >= Q.QTY_TREND_PCT then trend = "up" elseif pct <= -Q.QTY_TREND_PCT then trend = "down" end
    return now, old, pct, trend, math.floor((last.t - first.t) / 60 + 0.5)
end

function Q.OnSample(key, prev, s)
    if key == nil or type(s) ~= "table" or not Num(s.t) then return end
    Q.Record(key, s)   -- ab 0.134: Verlauf fuer das Diagramm
    local sec = tonumber(mod.db.quickFollowSec) or 30
    local list = Q.baits[key] or {}
    for _, b in ipairs(list) do
        if not b.above and s.t > b.t and s.t <= b.t + sec then   -- ab 0.123 ohne Lockangebote ueber Kaufen bis
            local q = QtyAt(s, b.price)
            local inc = q - (b.lastQ or 0)
            if inc >= 2 then
                b.added, b.times = b.added + inc, b.times + 1
                if b.times == 1 and not b.own and ns.QuickStats then ns.QuickStats.OnFollow(key) end   -- ab 0.122
            end
            b.lastQ = q
        end
    end
    -- ab 0.122: Gelegenheiten langfristig (QuickStats.lua), unabhaengig von Kaufen bis
    -- ab 0.125 (Wunsch KarloDerBaer 20.11.2026): Einbrueche auch fuer den Fokus merken (Zeile Einbruch, Knopf Auto)
    if prev and ns.QuickStats then
        local dip, ref = ns.QuickStats.OnPair(key, prev, s)
        if dip then Q.AddDip(key, s.t, dip.price, dip.qty - QtyAt(prev, dip.price), ref) end
    end
    -- ab 0.110: gemeldet (Zeile, Nachahmer, Ton) wird nur bis Kaufen bis (was man ohnehin nicht kaufen wuerde, zaehlt
    -- nicht). Ohne Kaufen bis alle. Ab 0.123 (Wunsch KarloDerBaer 19.11.2026) erkannt werden alle, die darueber mit
    -- above, damit der Knopf Auto Kaufen bis auch anheben kann (Q.AutoLimit).
    local F = ns.Focus
    local limit = F and F.key == key and F.ManualLimit and F.ManualLimit(key) or nil
    for _, l in ipairs(Q.NewBaits(prev, s, nil)) do
        local above = Num(limit) and l.price > limit
        Q.AddBait(key, s.t, l.price, false, 1, prev.min, above)   -- ab 0.121 mit dem guenstigsten Preis davor
        if not above then
            if ns.Focus and ns.Focus.key == key then Q.baitPing = key end   -- ab 0.111: Ton in Q.CheckAlarm
            Q.Trace("bait foreign price=%s min=%s", l.price, prev.min)
        else
            Q.Trace("bait above price=%s min=%s limit=%s", l.price, prev.min, limit)
        end
    end
end

-- Einbruch im Fokus (ab 0.125, Regel in QuickStats.Dip): in die Bilanz dieser Sitzung. Gezaehlt, tiefster Preis und
-- der letzte (fuer Q.AutoLimit). ref = Tiefstpreis davor (der regulaere Preis).
function Q.AddDip(key, t, price, qty, ref)
    if key == nil or not Num(price) then return end
    local s = Q.Session(key)
    s.dips = (s.dips or 0) + 1
    if not Num(s.dipLow) or price < s.dipLow then s.dipLow = price end
    s.lastDip = { t = t, price = price, qty = qty, reg = ref }
    if Num(t) then   -- ab 0.134: Strich im Diagramm
        local list = Q.dipTimes[key] or {}
        list[#list + 1] = t
        while #list > Q.MARK_KEEP do table.remove(list, 1) end
        Q.dipTimes[key] = list
    end
    Q.Trace("dip price=%s qty=%s low=%s", price, qty, ref)
end

-- Neue fremde Lockangebote in der Abfrage s gegenueber prev (ab 0.119 eigene Funktion, auch fuer QuickChances.lua)
function Q.NewBaits(prev, s, limit)
    local out = {}
    if not (prev and Num(prev.min) and type(s) == "table") then return out end
    local pct = (tonumber(mod.db.quickBaitMinPct) or 5) / 100
    for _, l in ipairs(s.lv or {}) do
        if l.qty == 1 and l.price <= prev.min * (1 - pct) and QtyAt(prev, l.price) == 0
           and not (Num(limit) and l.price > limit) then
            out[#out + 1] = l
        end
    end
    return out
end

-- Alle Lockangebote im Zeitfenster der Messung. Rueckgabe { n, withFollow, added, last } oder nil (keins im Fenster).
-- Jedes: { t, price, own, added, times, running, left, sec }
function Q.BaitStats(key)
    if key == nil then return nil end
    local M = ns.Measure
    M.Sync()
    local now = Now()
    local sec = tonumber(mod.db.quickFollowSec) or 30
    local from = now - M.WINDOW
    local r = { n = 0, withFollow = 0, added = 0 }
    for _, b in ipairs(Q.baits[key] or {}) do
        if b.t > from and not b.above then   -- ab 0.123: ueber Kaufen bis nur fuer Auto
            local f = { t = b.t, price = b.price, own = b.own, added = b.added, times = b.times, sec = sec,
                        running = now < b.t + sec, left = math.max(0, math.ceil(b.t + sec - now)) }
            r.n = r.n + 1
            if f.added > 0 then r.withFollow = r.withFollow + 1 end
            r.added = r.added + f.added
            if not r.last or f.t >= r.last.t then r.last = f end
        end
    end
    if r.n == 0 then return nil end
    return r
end

-- Knopf Auto neben Kaufen bis (ab 0.121, Wunsch KarloDerBaer 19.11.2026): die Mitte zwischen dem letzten fremden
-- Lockangebot und dem guenstigsten regulaeren Angebot darueber, abgerundet. Regulaer ist eine fremde Stufe ueber dem
-- Lockpreis mit mindestens 2 Stueck in der letzten Abfrage, ohne Abfrage der guenstigste Preis bei der Erkennung.
-- Rueckgabe value, bait, regular, high, kind oder nil (noch kein fremdes Lockangebot oder kein Abstand).
-- Ab 0.123 zaehlen auch Lockangebote ueber Kaufen bis. high = das letzte Lockangebot liegt bei oder ueber dem
-- aktuellen Kaufen bis (Kaufen bis haengt an der Grenze, der Knopf leuchtet).
-- Ab 0.125 (Wunsch KarloDerBaer 20.11.2026) zaehlt auch der letzte Einbruch (Q.AddDip), es gilt das juengere. kind =
-- "bait" oder "dip". Regulaer ist beim Einbruch die guenstigste Stufe ab 2 Stueck mindestens quickDipPct Prozent
-- ueber dem Einbruch (knapp darueber liegen oft weitere billige Stufen), sonst der Tiefstpreis davor.
function Q.AutoLimit(key)
    if key == nil then return nil end
    local last
    for _, b in ipairs(Q.baits[key] or {}) do
        if not b.own and (not last or b.t >= last.t) then last = b end
    end
    local kind = "bait"
    local sd = Q.sessions[key] and Q.sessions[key].lastDip
    if sd and Num(sd.price) and (not last or sd.t >= last.t) then last, kind = sd, "dip" end
    if not last then return nil end
    local over = last.price
    if kind == "dip" then over = last.price * (1 + (tonumber(mod.db.quickDipPct) or 5) / 100) - 1 end
    local reg
    local live = ns.Buy.live and ns.Buy.live[key]
    if type(live) == "table" and type(live.rows) == "table" then
        for _, l in ipairs(ns.Data.Available(live.rows)) do
            if l.price > over and l.qty >= 2 then reg = l.price; break end
        end
    end
    if not reg and Num(last.reg) and last.reg > last.price then reg = last.reg end
    if not reg or reg - last.price < 2 then return nil end
    local F = ns.Focus
    local limit = F and F.ManualLimit and F.ManualLimit(key) or nil
    local high = Num(limit) and limit <= last.price or false
    return math.floor((last.price + reg) / 2), last.price, reg, high, kind
end

---------------------------------------------------------------------------
-- ab 0.140 (Board KarloDerBaer 26.11.2026): Vorschlag statt Auto. Kaufen bis, bei dem ein Weiterverkauf zum
-- guenstigsten Angebot jetzt noch Gewinn bringt: guenstigstes Angebot ohne Ausreisser nach unten, minus Anteil des
-- Auktionshauses, minus Mindestgewinn je Stueck (quickSuggestPct Prozent, Vorgabe 5). Ausreisser: Stufen mit nur
-- einem Stueck und eine Stufe mehr als Q.OUTLIER_PCT Prozent unter der naechsten mit mindestens 2 Stueck.
---------------------------------------------------------------------------
Q.OUTLIER_PCT = 15

-- Guenstigster Preis ohne Ausreisser nach unten (rows = Live-Angebote) oder nil
function Q.CleanLow(rows)
    local lv = ns.Data.Available(rows or {})
    local cand = {}
    for _, l in ipairs(lv) do
        if l.qty >= 2 then
            cand[#cand + 1] = l.price
            if #cand >= 2 then break end
        end
    end
    if #cand == 0 then return lv[1] and lv[1].price or nil end
    if cand[2] and cand[1] < cand[2] * (1 - Q.OUTLIER_PCT / 100) then return cand[2] end
    return cand[1]
end

-- Vorschlag fuer key: Wert, guenstigstes (bereinigt), Anteil (0..1), Mindestgewinn je Stueck in Prozent. nil ohne
-- Live-Angebote
function Q.Suggestion(key)
    local F = ns.Focus
    if key == nil or key ~= F.key then return nil end
    local rows = F.LiveRows()
    if not rows then return nil end
    local low = Q.CleanLow(rows)
    if not Num(low) or low <= 0 then return nil end
    local cut = ns.Data.Cut and ns.Data.Cut() or 0.05
    local pct = math.max(0, tonumber(mod.db.quickSuggestPct) or 5)
    local v = math.floor(low * (1 - cut) - low * pct / 100)
    if v < 1 then return nil end
    return v, low, cut, pct
end

---------------------------------------------------------------------------
-- ab 0.140: Stabilitaet des Preises aus dem eigenen Verlauf (Q.hist) ueber den Zeitraum des Diagramms. Vergleicht
-- das erste und das letzte Drittel (Trend) und zaehlt Spruenge des guenstigsten Preises. Rueckgabe Code
-- ("stable", "rising", "falling", "jumpy", "wavy", "first") und Werte fuer den Tooltip.
--   sprunghaft  mindestens Q.STAB_JUMPS Spruenge je Minute (Sprung = mindestens quickJumpPct Prozent, Vorgabe 2)
--   steigend    letztes Drittel mindestens Q.STAB_TREND Prozent ueber dem ersten
--   fallend     letztes Drittel mindestens Q.STAB_TREND Prozent unter dem ersten
--   stabil      Spanne (hoechster minus tiefster) hoechstens Q.STAB_FLAT Prozent
--   schwankend  sonst
---------------------------------------------------------------------------
Q.STAB_MIN = 5       -- so viele Eintraege braucht die Bewertung
Q.STAB_JUMPS = 1.5   -- Spruenge je Minute
Q.STAB_TREND = 3     -- Prozent
Q.STAB_FLAT = 2      -- Prozent

function Q.Stability(key, minutes, now)
    local h = key ~= nil and Q.hist[key]
    if not h then return "first" end
    now = now or h.last
    local from = now - (tonumber(minutes) or 5) * 60
    local vals, times = {}, {}
    for _, e in ipairs(h.list) do
        if e.t > from and Num(e.min) then vals[#vals + 1] = e.min; times[#times + 1] = e.t end
    end
    local n = #vals
    if n < Q.STAB_MIN then return "first", { n = n } end
    local third = math.max(1, math.floor(n / 3))
    local a, b = 0, 0
    for i = 1, third do a = a + vals[i] end
    for i = n - third + 1, n do b = b + vals[i] end
    a, b = a / third, b / third
    local lo, hi, jumps = vals[1], vals[1], 0
    local jp = (tonumber(mod.db.quickJumpPct) or 2) / 100
    for i = 2, n do
        local v = vals[i]
        if v < lo then lo = v end
        if v > hi then hi = v end
        local p = vals[i - 1]
        if p > 0 and math.abs(v - p) / p >= jp then jumps = jumps + 1 end
    end
    local mins = math.max(1 / 60, (times[n] - times[1]) / 60)
    local trend = a > 0 and (b - a) * 100 / a or 0
    local span = lo > 0 and (hi - lo) * 100 / lo or 0
    local info = { n = n, trend = trend, span = span, jumps = jumps, perMin = jumps / mins, lo = lo, hi = hi, minutes = mins }
    if info.perMin >= Q.STAB_JUMPS then return "jumpy", info end
    if trend >= Q.STAB_TREND then return "rising", info end
    if trend <= -Q.STAB_TREND then return "falling", info end
    if span <= Q.STAB_FLAT then return "stable", info end
    return "wavy", info
end

---------------------------------------------------------------------------
-- ab 0.140: Statistik im Einkaufen. Gekauft in dieser Sitzung (Q.sessions), heute und in 7 Tagen (QuickStats), je
-- Stueck, Durchschnitt und Quote der genutzten Gelegenheiten. Rueckgabe { n, cost, opps, won } oder nil
---------------------------------------------------------------------------
function Q.SessionStats(key)
    local s = key ~= nil and Q.sessions[key]
    if not s then return nil end
    return { n = s.bought or 0, cost = s.cost or 0, opps = s.opps or 0, won = s.won or 0 }
end

-- ab 0.144: letzter Kauf dieser Sitzung fuer die Zeile Zuletzt { n, cost } oder nil
function Q.LastStats(key)
    local s = key ~= nil and Q.sessions[key]
    local b = s and s.lastBuy
    if not b then return nil end
    return { n = b.n or 0, cost = b.cost or 0 }
end

-- Zeile der Statistik: "12 (5s 3c)" = Menge (Durchschnitt) oder grau "nichts gekauft". Ab 0.144 (Board KarloDerBaer)
-- ohne die Quote der genutzten Gelegenheiten, sie hing zu sehr davon ab, wie viele gerade mitbieten.
function Q.StatText(st)
    if not st or (st.n or 0) <= 0 then return GREY .. L.QUICK_STAT_NONE .. "|r" end
    local avg = (Num(st.cost) and st.cost > 0) and Money(math.floor(st.cost / st.n + 0.5)) or "-"
    return L.QUICK_STAT:format(st.n, avg)
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
function Q.Init()
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_POST_WARNING", function() mod:Call("Schnellkauf", Q.OnPostWarning) end)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_AUCTION_CREATED", function(_, id) mod:Call("Schnellkauf", Q.OnCreated, id) end)
    pcall(mod.RegisterEvent, mod, "AUCTION_CANCELED", function(_, id) mod:Call("Schnellkauf", Q.OnCanceled, id) end)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_SHOW_ERROR", function() mod:Call("Schnellkauf", Q.OnError) end)
end
