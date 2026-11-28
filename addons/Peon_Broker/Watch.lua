-- Peon_Broker - Watch.lua
-- Umbau U8 (ab 0.49, Konzept Peon_Broker_Umbau.md, Abschnitt 8.7): Beobachtung (im Manager bisher Favoriten).
--   PeonBrokerDB.watch[Schluessel] = { u, name, q, icon, lim (Kupfer) oder pct (% unter dem Vergleichspreis), hit,
--                                      up (Grenze nach oben in Kupfer, ab 0.68), upHit }
--   PeonBrokerDB.watchGone[Schluessel] = Zeit (Loeschmarke, wie bei den Einkaufslisten)
-- Ab 0.89 (Manager-Angleichung A2, Peon_Manager_Angleichung.md 3.2): t = { buy, up } Zeit je Wert. "buy" ist Kaufen bis
-- (lim oder pct), "up" der Zielpreis. Der Abgleich mit dem Manager laeuft je Wert, beide Grenzen gehen mit.
-- Preisalarm: Liegt das guenstigste Angebot auf oder unter der Grenze, meldet Broker das einmal im Chat und mit
-- Ton (wie das Radar) und erst wieder, nachdem der Preis darueber lag. Geprueft nach jedem Komplettscan, nach
-- dem Stand vom Manager (Anmelden) und nach jeder Live-Abfrage.
-- Ab 0.82 eigener Reiter Beobachten (WatchPage.lua). up heisst dort "Zielpreis" (Preis, ab dem man verkaufen wuerde).
-- Ab 0.106 (KarloDerBaer 19.11.2026) Werte je Modus des Fokus: lim/pct und up gehoeren zum Aufkauf, qlim (Kaufen bis)
-- und qmax (hoechste Menge) zum Schnellkauf, mode = "quick" oder nil (Aufkauf) ist der zuletzt gespeicherte Modus.
-- qlim, qmax und mode bleiben im Spiel, der Abgleich mit dem Manager laesst sie aus (Wt.SKIP). Der Preisalarm nimmt
-- Kaufen bis des gespeicherten Modus, den Zielpreis nur im Aufkauf.
-- Ab 0.128 (KarloDerBaer 20.11.2026): Liste Markttausch (ton = true, Haken "Beobachten: Markttausch"). Werte des
-- Schnellkaufs (qlim, qgold, qskip, qavg, Zeit t.q) und die Haken der Listen (bon, qon, ton, Zeit t.lists) gleicht Broker
-- jetzt mit dem Manager ab, je Gruppe mit eigener Zeit wie Kaufen bis und Zielpreis. qmax und mode bleiben im Spiel.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local Wt = {}
ns.Watch = Wt

Wt.PCTS = { 10, 20, 30 }   -- Vorschlaege im Menue: % unter dem Vergleichspreis

-- Werte mit eigener Zeit (ab 0.89, Regeln in Shop.lua): Kaufen bis und Zielpreis. hit und upHit sind Merker des Alarms
Wt.SPEC = { { f = "buy", keys = { "lim", "pct" }, reset = "hit" }, { f = "up", keys = { "up" }, reset = "upHit" },
            { f = "q", keys = { "qlim", "qgold", "qskip", "qavg" }, reset = "hit" },   -- ab 0.128: Schnellkauf
            { f = "lists", keys = { "bon", "qon", "ton" } } }                         -- ab 0.128: Listen
Wt.SKIP = { u = true, t = true, lim = true, pct = true, up = true, hit = true, upHit = true, sDown = true, sUp = true, muteDown = true, muteUp = true,
            qlim = true, qmax = true, qqty = true, mode = true, qskip = true, qgold = true, qavg = true,   -- ab 0.106: Werte des Schnellkaufs (ab 0.128 ueber t.q), qqty ab 0.133 nur im Spiel
            bon = true, qon = true, ton = true,   -- ab 0.120: Haken der Listen (ab 0.128 ueber t.lists)
            qlimOn = true, qglide = true, qmethod = true,   -- ab 0.143: Kaufart im Einkaufen, nur im Spiel
            qref = true, qmargin = true, qmin = true,   -- ab 0.167: Richtpreis, Gewinnspanne, Min. Menge
            qtab = true, qtrig = true, qtrigPct = true, qtrigFix = true,   -- ab 0.168: Tab und Ausloeser, nur im Spiel
            qbait = true, qbaitPct = true, qbaitFix = true }   -- ab 0.174: Lockpreis, nur im Spiel
-- ab 0.91 (Fehlerberichte 20 und 21): Warnton je Richtung, einstellbar fuer alle (watchSoundDown, watchSoundUp, dazu
-- Chatnachricht watchChatDown, watchChatUp) und je Gegenstand (sDown, sUp: Ton oder "off", nil = wie eingestellt).
-- Die Werte je Gegenstand bleiben im Spiel, der Manager kennt sie nicht.
Wt.SOUND_CHOICES = { "off", "raid", "ready", "alarm", "tell" }

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end

-- ab 0.128: Werte einer Gruppe merken und nach einer Aenderung die Zeit der Gruppe setzen (Abgleich mit dem Manager)
local GROUP_KEYS = { q = { "qlim", "qgold", "qskip", "qavg" }, lists = { "bon", "qon", "ton" } }
function Wt.Snap(w)
    local o = {}
    if type(w) ~= "table" then return o end
    for g, keys in pairs(GROUP_KEYS) do
        local parts = {}
        for _, k in ipairs(keys) do parts[#parts + 1] = tostring(w[k]) end
        o[g] = table.concat(parts, "|")
    end
    return o
end

function Wt.StampChanged(w, old)
    if type(w) ~= "table" or not ns.Shop then return end
    local now = Wt.Snap(w)
    for g in pairs(GROUP_KEYS) do
        if now[g] ~= (old and old[g]) then ns.Shop.Stamp(w, Wt.SPEC, g, time and time() or 0) end
    end
end

function Wt.Store()
    local acc = mod.acc
    if type(acc) ~= "table" then return {} end
    if type(acc.watch) ~= "table" then acc.watch = {} end
    return acc.watch
end

function Wt.Gone()
    local acc = mod.acc
    if type(acc) ~= "table" then return {} end
    if type(acc.watchGone) ~= "table" then acc.watchGone = {} end
    return acc.watchGone
end

local function NextU(old)
    local t = time and time() or 0
    if Num(old) and old >= t then return old + 1 end
    return t
end

function Wt.Is(key) return key ~= nil and Wt.Store()[key] ~= nil end

function Wt.Add(key, info)
    if key == nil then return false end
    local st = Wt.Store()
    local w = st[key] or {}
    info = type(info) == "table" and info or {}
    w.name = info.name or w.name
    w.q = info.quality or info.q or w.q
    w.icon = info.icon or w.icon
    w.u = NextU(math.max(w.u or 0, Wt.Gone()[key] or 0))
    Wt.Gone()[key] = nil
    st[key] = w
    mod:Print(L.WATCH_ADDED:format(w.name or tostring(key)))
    Wt.Check({ key })
    if ns.Side then ns.Side.Refresh() end   -- ab 0.137 (U5)
    return true
end

function Wt.Remove(key)
    local st = Wt.Store()
    if not st[key] then return false end
    Wt.Gone()[key] = NextU(st[key].u)
    st[key] = nil
    if ns.Side then ns.Side.Refresh() end   -- ab 0.137 (U5)
    return true
end

function Wt.Toggle(key, info)
    if Wt.Is(key) then Wt.Remove(key); return false end
    Wt.Add(key, info)
    return true
end

-- Grenze setzen: kind "pct" (value % unter dem Vergleichspreis), "abs" (value Kupfer), nil = keine Grenze
function Wt.SetLimit(key, kind, value)
    local w = Wt.Store()[key]
    if not w then return false end
    w.lim, w.pct, w.hit = nil, nil, nil
    if kind == "pct" and Num(value) then w.pct = value
    elseif kind == "abs" and Num(value) and value > 0 then w.lim = math.floor(value) end
    ns.Shop.Stamp(w, Wt.SPEC, "buy", time and time() or 0)   -- ab 0.89 je Wert
    Wt.Check({ key })
    return true
end

-- Grenze nach oben (ab 0.68, H4, Konzept 6.6): "Melde, wenn der Preis ueber X liegt" fuer Dinge, die man spaeter
-- verkaufen will. value = Kupfer je Stueck oder nil (keine Grenze)
function Wt.SetUp(key, value)
    local w = Wt.Store()[key]
    if not w then return false end
    w.up, w.upHit = nil, nil
    if Num(value) and value > 0 then w.up = math.floor(value) end
    ns.Shop.Stamp(w, Wt.SPEC, "up", time and time() or 0)   -- ab 0.89 je Wert
    Wt.Check({ key })
    return true
end

-- ab 0.106: zuletzt gespeicherter Modus des Fokus ("quick" oder "buyout")
function Wt.Mode(key)
    local w = Wt.Store()[key]
    return (w and w.mode == "quick") and "quick" or "buyout"
end

function Wt.SetMode(key, mode)
    local w = Wt.Store()[key]
    if not w then return false end
    local m = mode == "quick" and "quick" or nil
    local old = Wt.Snap(w)
    if w.mode ~= m then w.mode, w.hit = m, nil end
    if m == "quick" then w.qon = true else w.bon = true end   -- ab 0.120: in die Liste des Modus
    Wt.StampChanged(w, old)
    return true
end

-- ab 0.119: Unterreiter in Beobachten. Ein Gegenstand steht in jeder Liste, fuer die er Werte hat, also auch in beiden.
-- Schnellkauf: Kaufen bis des Schnellkaufs oder zuletzt im Schnellkauf gespeichert. Aufkauf: Werte des Aufkaufs oder
-- gar keine Werte (frisch hinzugefuegt).
-- Ab 0.120 (KarloDerBaer 19.11.2026) schalten Haken im Gegenstandsmenue jede Liste einzeln: bon / qon = true oder false
-- gehen vor, nil = wie bisher nach den Werten.
function Wt.InQuick(key)
    local w = Wt.Store()[key]
    if w == nil then return false end
    if w.qon ~= nil then return w.qon end
    return w.mode == "quick" or Num(w.qlim)
end

function Wt.InBuyout(key)
    local w = Wt.Store()[key]
    if not w then return false end
    if w.bon ~= nil then return w.bon end
    if Num(w.lim) or Num(w.pct) or Num(w.up) then return true end
    if w.ton then return false end   -- ab 0.128: nur in Markttausch
    return not Wt.InQuick(key)
end

-- ab 0.128: Liste Markttausch
function Wt.InTrade(key)
    local w = Wt.Store()[key]
    return w ~= nil and w.ton == true
end

-- Schluessel der Liste Markttausch (bekannte Suchschluessel), sortiert
function Wt.TradeKeys()
    local keys = {}
    for key, w in pairs(Wt.Store()) do
        if w.ton == true and (not ns.Buy or ns.Buy.KnownKey(key)) then keys[#keys + 1] = key end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

-- Haken "Beobachten: Markttausch". Aus: steht der Gegenstand in keiner anderen Liste, endet die Beobachtung.
function Wt.SetTradeOn(key, on, info)
    if key == nil then return false end
    if on then
        local fresh = not Wt.Is(key)
        if fresh then Wt.Add(key, info) end
        local w = Wt.Store()[key]
        local old = Wt.Snap(w)
        if fresh then w.bon, w.qon = false, false end
        w.ton = true
        Wt.StampChanged(w, old)
    else
        local w = Wt.Store()[key]
        if not w then return false end
        local old = Wt.Snap(w)
        w.ton = false
        if not Wt.InBuyout(key) and not Wt.InQuick(key) then Wt.Remove(key); return true end
        Wt.StampChanged(w, old)
    end
    return true
end

-- ab 0.120: Haken "Beobachten: Aufkauf". Aus: steht der Gegenstand noch im Schnellkauf, bleibt er dort, sonst endet
-- die Beobachtung. Die Werte des Aufkaufs bleiben gespeichert.
function Wt.SetBuyoutOn(key, on, info)
    if key == nil then return false end
    if on then
        if not Wt.Is(key) then Wt.Add(key, info) end
        local w = Wt.Store()[key]
        local old = Wt.Snap(w)
        w.bon = true
        if not Wt.InQuick(key) then w.mode = nil end
        Wt.StampChanged(w, old)
    else
        local w = Wt.Store()[key]
        if not w then return false end
        if not Wt.InQuick(key) and not Wt.InTrade(key) then Wt.Remove(key); return true end
        local old = Wt.Snap(w)
        w.bon = false
        if Wt.InQuick(key) or not Wt.InTrade(key) then
            if w.mode ~= "quick" then w.mode, w.hit = "quick", nil end   -- Alarm nach Kaufen bis des Schnellkaufs
            w.qon = true
        end
        Wt.StampChanged(w, old)
    end
    Wt.Check({ key })
    return true
end

-- ab 0.120: Haken "Beobachten: Schnellkauf". An ohne Werte des Schnellkaufs: Kaufen bis und Limit pro Kauf wie im
-- Fokus ohne eigene Werte (QuickChances.Defaults), beide Haken an. Der gespeicherte Modus wird nur Schnellkauf, wenn
-- der Gegenstand nicht auch im Aufkauf steht.
function Wt.SetQuickOn(key, on, info)
    if key == nil then return false end
    if on then
        local fresh = not Wt.Is(key)
        if fresh then Wt.Add(key, info) end
        local w = Wt.Store()[key]
        local old = Wt.Snap(w)
        if not Num(w.qlim) then
            local limit, gold = nil, nil
            if ns.QuickChances then limit, gold = ns.QuickChances.Defaults(key) end
            w.qlim = Num(limit) and limit > 0 and math.floor(limit) or nil
            w.qgold = Num(gold) and gold > 0 and math.floor(gold) or 0
            w.qskip, w.qavg = true, true
        end
        w.qon = true
        if fresh then w.bon = false end
        if fresh or not Wt.InBuyout(key) then w.mode, w.hit = "quick", nil end
        Wt.StampChanged(w, old)
    else
        local w = Wt.Store()[key]
        if not w then return false end
        local inB = Wt.InBuyout(key)   -- vor dem Ausschalten: steht er auch im Aufkauf?
        if not inB and not Wt.InTrade(key) then Wt.Remove(key); return true end
        local old = Wt.Snap(w)
        w.qon = false
        if inB or not Wt.InTrade(key) then w.bon = true end
        if w.mode == "quick" then w.mode, w.hit = nil, nil end
        Wt.StampChanged(w, old)
    end
    Wt.Check({ key })
    return true
end

-- ab 0.106: Werte des Schnellkaufs (Kaufen bis und hoechste Menge, nil = alle), Modus wird Schnellkauf
function Wt.SetQuick(key, limit, gold, skip, avg)
    local w = Wt.Store()[key]
    if not w then return false end
    local old = Wt.Snap(w)
    w.qlim = Num(limit) and limit > 0 and math.floor(limit) or nil
    w.qmax = nil   -- bis 0.111 Max. Menge
    w.qgold = Num(gold) and gold > 0 and math.floor(gold) or 0   -- ab 0.112 Limit pro Kauf, ab 0.113 0 = ohne Grenze
    w.qavg = avg and true or false   -- ab 0.112 Haken "Durchschnitt zaehlt", ab 0.113 auch aus gespeichert
    w.qskip = skip and true or false   -- ab 0.109: Haken "Lockangebot ignorieren", ab 0.113 auch aus gespeichert
    w.mode, w.hit = "quick", nil
    w.qon = true   -- ab 0.120: Speichern im Schnellkauf stellt ihn in die Liste Schnellkauf
    Wt.StampChanged(w, old)
    Wt.Check({ key })
    return true
end

-- ab 0.133 (U1, Konzept Peon_Broker_Schlank.md 4.1): Werte des Einkaufens speichern, ohne das alte Limit pro Kauf
-- (qgold) anzufassen. qty = Menge (0 = Alle, nil = nichts gespeichert, dann gilt die Vorgabe)
function Wt.SetQuickValues(key, limit, qty, skip, avg)
    local w = Wt.Store()[key]
    if not w then return false end
    local old = Wt.Snap(w)
    w.qlim = Num(limit) and limit > 0 and math.floor(limit) or nil
    if Num(qty) and qty >= 0 then w.qqty = math.floor(qty) end
    w.qavg = avg and true or false
    w.qskip = skip and true or false
    w.mode, w.hit = "quick", nil
    w.qon = true
    Wt.StampChanged(w, old)
    Wt.Check({ key })
    return true
end

-- ab 0.143: Kaufart im Einkaufen je Gegenstand (Haken Limit und Gleitend, Methode), nur im Spiel
-- ab 0.167 statt der Methode Richtpreis und Gewinnspanne (qmethod bleibt gespeichert, ungenutzt), dazu Min. Menge
function Wt.SetQuickKind(key, limitOn, glideOn, ref, margin, minQty)
    local w = Wt.Store()[key]
    if not w then return false end
    w.qlimOn = limitOn and true or false
    w.qglide = glideOn and true or false
    w.qref = ref
    w.qmargin = Num(margin) and margin or nil
    w.qmin = Num(minQty) and minQty > 0 and math.floor(minQty) or nil
    return true
end

-- ab 0.168: Tab (Limitkauf oder Direktkauf) und Ausloeser im Einkaufen je Gegenstand, nur im Spiel.
-- Nur gesetzte Werte, nil laesst den gespeicherten Wert stehen. fix 0 = Feld geleert.
function Wt.SetQuickBand(key, tab, trig, pct, fix)
    local w = Wt.Store()[key]
    if not w then return false end
    if tab == "limit" or tab == "direct" then w.qtab = tab end
    if type(trig) == "string" then w.qtrig = trig end
    if Num(pct) then w.qtrigPct = math.floor(pct) end
    if Num(fix) then w.qtrigFix = fix > 0 and math.floor(fix) or nil end
    return true
end

-- ab 0.174: Lockpreis (Quelle, Abstand, fester Preis) je Gegenstand, nur gesetzte Werte. fix 0 = Feld geleert.
function Wt.SetQuickBait(key, src, pct, fix)
    local w = Wt.Store()[key]
    if not w then return false end
    if type(src) == "string" then w.qbait = src end
    if Num(pct) then w.qbaitPct = math.floor(pct) end
    if Num(fix) then w.qbaitFix = fix > 0 and math.floor(fix) or nil end
    return true
end

-- ab 0.106: Kaufen bis des gespeicherten Modus (fuer Liste und Alarm)
function Wt.ActiveLimit(key, e)
    local w = Wt.Store()[key]
    if not w then return nil end
    -- ab 0.169: im Einkaufen der Ausloeser (ohne Ausloeser das Limit, fest oder gleitend), im Direktkauf keiner
    if w.mode == "quick" then
        local Q = ns.Quick
        if Q and Q.BandFor then
            local _, trig = Q.BandFor(key)
            return trig
        end
        return Num(w.qlim) and w.qlim or nil
    end
    return Wt.Limit(key, e)
end

-- Grenze in Kupfer (je Stueck) oder nil
function Wt.Limit(key, e)
    local w = Wt.Store()[key]
    if not w then return nil end
    if Num(w.lim) then return w.lim end
    if Num(w.pct) then return ns.Data.MaxBuyPrice(e or ns.Data.Lookup(key), w.pct) end
    return nil
end

-- Text der Grenze fuer Listen und Menue
function Wt.LimitText(key)
    local w = Wt.Store()[key]
    if not w then return nil end
    if Num(w.lim) then return Money(w.lim) end
    if Num(w.pct) then return L.WATCH_PCT:format(w.pct) end
    return nil
end

-- Warnton fuer einen Gegenstand und eine Richtung ("Down" = Kaufen bis, "Up" = Zielpreis): Schluessel oder "off"
function Wt.Sound(key, dir)
    local w = Wt.Store()[key]
    local own = w and w["s" .. dir] or nil
    if own ~= nil then return own end
    local v = mod.db["watchSound" .. dir]
    if v == nil then return "raid" end
    return v
end

function Wt.SetSound(key, dir, v)
    local w = Wt.Store()[key]
    if not w then return end
    w["s" .. dir] = v
end

-- ab 0.92: Warnung je Gegenstand und Richtung aus (Symbole in der Liste Beobachten hinter Kaufen bis und Zielpreis).
-- muteDown / muteUp = true: weder Chat noch Ton fuer diese Grenze. dir = "Down" (Kaufen bis) oder "Up" (Zielpreis)
function Wt.Muted(key, dir)
    local w = Wt.Store()[key]
    return w ~= nil and w["mute" .. dir] == true
end

function Wt.ToggleMute(key, dir)
    local w = Wt.Store()[key]
    if not w or (dir ~= "Down" and dir ~= "Up") then return nil end
    local f = "mute" .. dir
    w[f] = (not w[f]) or nil
    return w[f] == true
end

-- Meldung eines Alarms: Chat und Ton je nach Einstellung
function Wt.Alert(key, dir, text)
    if mod.db.watchAlarm == false then return end   -- ab 0.83: Haken unter Beobachten schaltet alles ab
    if Wt.Muted(key, dir) then return end
    if mod.db["watchChat" .. dir] ~= false then mod:Print(text) end
    local snd = Wt.Sound(key, dir)
    if snd ~= "off" and ns.Radar and ns.Radar.PlayAlert then pcall(ns.Radar.PlayAlert, snd) end
end

-- Preisalarm pruefen (keys = Liste von Schluesseln oder nil = alle). Rueckgabe: Zahl neuer Alarme
-- ab 0.110: Gegenstand steht gerade im sichtbaren Fokus
function Wt.InFocus(key)
    local F = ns.Focus
    return F ~= nil and key ~= nil and F.key == key and F.Shown ~= nil and F.Shown() and true or false
end

function Wt.Check(keys)
    local st = Wt.Store()
    local list = keys
    if not list then list = {}; for k in pairs(st) do list[#list + 1] = k end end
    local n = 0
    for _, key in ipairs(list) do
        local w = st[key]
        if w then
            local e = ns.Data.Lookup(key)
            local limit = Wt.ActiveLimit(key, e)   -- ab 0.106 je Modus
            local hit = limit and type(e) == "table" and not e.gone and Num(e.m) and e.m <= limit
            if hit and not w.hit then
                w.hit = true
                -- ab 0.110: nicht fuer den Gegenstand, der gerade im Fokus zu sehen ist (dort gibt es den eigenen Alarm)
                if not Wt.InFocus(key) then
                n = n + 1
                Wt.Alert(key, "Down", L.WATCH_ALARM:format(w.name or ns.Data.ItemName(key, e) or tostring(key), Money(e.m), Money(limit)))
                end
            elseif not hit and w.hit and (type(e) ~= "table" or e.gone or (limit and Num(e.m) and e.m > limit)) then
                w.hit = nil
            end
            -- ab 0.68: Grenze nach oben, guenstigstes Angebot liegt darueber (guter Zeitpunkt zum Verkaufen)
            local up = Num(w.up) and w.mode ~= "quick" and w.up or nil   -- ab 0.106: Zielpreis nur im Aufkauf
            local upHit = up and type(e) == "table" and not e.gone and Num(e.m) and e.m >= up
            if upHit and not w.upHit then
                w.upHit = true
                if not Wt.InFocus(key) then
                n = n + 1
                Wt.Alert(key, "Up", L.WATCH_ALARM_UP:format(w.name or ns.Data.ItemName(key, e) or tostring(key), Money(e.m), Money(up)))
                end
            elseif not upHit and w.upHit and (type(e) ~= "table" or e.gone or (up and Num(e.m) and e.m < up) or not up) then
                w.upHit = nil
            end
        end
    end
    if n > 0 and ns.Buy and ns.Buy.UpdateBadge then pcall(ns.Buy.UpdateBadge) end
    if ns.WatchPage and ns.WatchPage.UpdateBadge then pcall(ns.WatchPage.UpdateBadge) end   -- ab 0.82
    return n
end

-- Pseudo-Liste fuer den Reiter Einkaufen (wie eine Einkaufsliste, aber ohne Abgleich und ohne Wunschmenge)
function Wt.PseudoList()
    local items = {}
    for key, w in pairs(Wt.Store()) do
        items[key] = { name = w.name, q = w.q, icon = w.icon, max = Wt.Limit(key), up = Num(w.up) and w.up or nil }
    end
    return { id = "watch", name = L.WATCH_LIST, pct = 0, items = items, watch = true }
end

-- Gegenstandsmenue: "Beobachten" (Haken) und Untermenue "Preisgrenze"
-- Ab 0.120 bei Massenware zwei Haken: "Beobachten: Aufkauf" und "Beobachten: Schnellkauf" (Wunsch KarloDerBaer).
-- Preisgrenze und Zielpreis gehoeren zum Aufkauf und stehen nur dort.
function Wt.AddMenu(root, item, key)
    local on = Wt.Is(key)
    local info = { name = item.name }
    -- ab 0.135 (U3, Konzept Peon_Broker_Schlank.md 6.2): Beobachten ist eine Liste. Ohne Aufkauf ein Haken
    -- "Beobachten" (aus = entfernen). Massenware kommt dabei wie im Einkaufen mit Kaufen bis in die Liste.
    local buyoutOn = ns.Quick and ns.Quick.BuyoutOn and ns.Quick.BuyoutOn()
    if key ~= nil and not buyoutOn then
        local commodity = ns.Data.IsCommodity(key)
        local get = function() return Wt.Is(key) end
        local set = function()
            if Wt.Is(key) then mod:Call("Beobachtung", Wt.Remove, key)
            elseif commodity then mod:Call("Beobachtung", Wt.SetQuickOn, key, true, info)
            else mod:Call("Beobachtung", Wt.Add, key, info) end
        end
        if root.CreateCheckbox then root:CreateCheckbox(L.MENU_WATCH, get, set)
        else root:CreateButton(on and L.MENU_UNWATCH or L.MENU_WATCH, set) end
        if ns.Trade and ns.Trade.On() then
            local tget = function() return Wt.InTrade(key) end
            local tset = function() mod:Call("Beobachtung", Wt.SetTradeOn, key, not tget(), info) end
            if root.CreateCheckbox then root:CreateCheckbox(L.MENU_WATCH_TRADE, tget, tset)
            else root:CreateButton((tget() and "[x] " or "[ ] ") .. L.MENU_WATCH_TRADE, tset) end
        end
        if on then Wt.SoundMenu(root, key, { "Down" }) end
        return
    end
    if key ~= nil and ns.Data.IsCommodity(key) then
        local function Add(text, get, set)
            if root.CreateCheckbox then
                root:CreateCheckbox(text, get, function() mod:Call("Beobachtung", set, key, not get(), info) end)
            else
                root:CreateButton((get() and "[x] " or "[ ] ") .. text, function() mod:Call("Beobachtung", set, key, not get(), info) end)
            end
        end
        Add(L.MENU_WATCH_BUYOUT, function() return Wt.InBuyout(key) end, Wt.SetBuyoutOn)
        Add(L.MENU_WATCH_QUICK, function() return Wt.InQuick(key) end, Wt.SetQuickOn)
        if ns.Trade and ns.Trade.On() then Add(L.MENU_WATCH_TRADE, function() return Wt.InTrade(key) end, Wt.SetTradeOn) end   -- ab 0.128, ab 0.128.2 nur eingeschaltet
    elseif root.CreateCheckbox then
        root:CreateCheckbox(L.MENU_WATCH, function() return Wt.Is(key) end,
            function() mod:Call("Beobachtung", Wt.Toggle, key, info) end)
    else
        root:CreateButton(on and L.MENU_UNWATCH or L.MENU_WATCH, function() mod:Call("Beobachtung", Wt.Toggle, key, info) end)
    end
    -- ab 0.128: Markttausch auch fuer Gegenstaende, die keine Massenware sind
    if key ~= nil and not ns.Data.IsCommodity(key) and ns.Trade and ns.Trade.On() then
        local get = function() return Wt.InTrade(key) end
        local set = function() mod:Call("Beobachtung", Wt.SetTradeOn, key, not get(), info) end
        if root.CreateCheckbox then root:CreateCheckbox(L.MENU_WATCH_TRADE, get, set)
        else root:CreateButton((get() and "[x] " or "[ ] ") .. L.MENU_WATCH_TRADE, set) end
    end
    if not on then return end
    if not Wt.InBuyout(key) then return end
    local sub = root:CreateButton(L.MENU_WATCH_LIMIT)
    for _, p in ipairs(Wt.PCTS) do
        sub:CreateButton(L.WATCH_PCT:format(p), function() mod:Call("Beobachtung", Wt.SetLimit, key, "pct", p) end)
    end
    local e = ns.Data.Lookup(key)
    if type(e) == "table" and Num(e.m) then
        sub:CreateButton(L.MENU_WATCH_NOW:format(Money(e.m)), function() mod:Call("Beobachtung", Wt.SetLimit, key, "abs", e.m) end)
    end
    sub:CreateButton(L.MENU_WATCH_NONE, function() mod:Call("Beobachtung", Wt.SetLimit, key, nil) end)
    -- ab 0.68: Grenze nach oben
    local upSub = root:CreateButton(L.MENU_WATCH_UP)
    if type(e) == "table" and Num(e.m) then
        upSub:CreateButton(L.MENU_WATCH_NOW:format(Money(e.m)), function() mod:Call("Beobachtung", Wt.SetUp, key, e.m) end)
        for _, p in ipairs(Wt.PCTS) do
            local v = math.floor(e.m * (1 + p / 100))
            upSub:CreateButton(L.MENU_WATCH_UP_PCT:format(p, Money(v)), function() mod:Call("Beobachtung", Wt.SetUp, key, v) end)
        end
    end
    upSub:CreateButton(L.MENU_WATCH_NONE, function() mod:Call("Beobachtung", Wt.SetUp, key, nil) end)
    Wt.SoundMenu(root, key, { "Down", "Up" })
end

-- ab 0.91: Warnton je Gegenstand (Rechtsklick in der Liste Beobachten oeffnet dieses Menue), ab 0.135 eigene Funktion
function Wt.SoundMenu(root, key, dirs)
    for _, dir in ipairs(dirs) do
        local sSub = root:CreateButton(L["MENU_WATCH_SOUND_" .. dir:upper()])
        local function Own() local w = Wt.Store()[key]; return w and w["s" .. dir] or nil end
        if sSub.CreateRadio then
            sSub:CreateRadio(L.WATCH_SOUND_DEFAULT, function() return Own() == nil end,
                function() mod:Call("Beobachtung", Wt.SetSound, key, dir, nil) end)
            for _, v in ipairs(Wt.SOUND_CHOICES) do
                sSub:CreateRadio(Wt.SoundName(v), function() return Own() == v end, function()
                    mod:Call("Beobachtung", Wt.SetSound, key, dir, v)
                    if v ~= "off" and ns.Radar and ns.Radar.PlayAlert then pcall(ns.Radar.PlayAlert, v) end
                end)
            end
        end
    end
end

-- Name eines Tons fuer Menues und Einstellungen
function Wt.SoundName(v)
    if v == "off" then return L.WATCH_SOUND_OFF end
    return L["SOUND_" .. tostring(v):upper()] or tostring(v)
end

function Wt.Init()
    mod:On("SCAN_DONE", function() mod:Call("Beobachtung", Wt.Check) end)
    -- nach jeder Live-Abfrage den Gegenstand pruefen
    local D = ns.Data
    local orig = D.ApplyLive
    D.ApplyLive = function(key, ...)
        local a, b, c = orig(key, ...)
        if key ~= nil and Wt.Store()[key] then mod:Call("Beobachtung", Wt.Check, { key }) end
        return a, b, c
    end
end

-- Beobachtung aus dem Peon Manager einmischen (ab 0.49, ueber Peon_Bridge 0.9.0, Data.lua "watch").
-- data = { items = { [Schluessel] = Eintrag }, gone = { [Schluessel] = u } }. Ab 0.89 ist ein Eintrag
-- { u, lim, pct, up, t, name, q, icon } und der Abgleich laeuft je Wert (Wt.Merge). Ein Manager vor 0.30 schickt nur u
-- (Zahl), dann zaehlt nur, ob beobachtet wird. Rueckgabe: true bei Aenderung
function mod:MergeWatch(data)
    if type(data) ~= "table" then return false end
    local st = Wt.Store()
    local changed = Wt.Merge(st, Wt.Gone(), data)
    for key, w in pairs(st) do
        if w.name == nil and ns.Data and ns.Data.Lookup then w.name = ns.Data.ItemName(key, ns.Data.Lookup(key)) end
    end
    if changed then Wt.Check() end
    return changed
end

-- Reiner Abgleich ohne Spiel (gleiche Regeln wie manager/src/core/watching.js, Test umbau2.test.js, watch_compare.lua)
function Wt.Merge(st, gone, data)
    local S = ns.Shop
    local changed = false
    local function Key(k)
        if type(k) == "string" and k:match("^%d+$") then return tonumber(k) end
        return k
    end
    for k, raw in pairs(type(data.items) == "table" and data.items or {}) do
        local key = Key(k)
        local bare = type(raw) ~= "table"
        local inc = bare and { u = tonumber(raw) or 0 } or raw
        local uu = tonumber(inc.u) or 0
        local w = st[key]
        local localU = w and (tonumber(w.u) or 0) or (tonumber(gone[key]) or 0)
        if not w then
            if uu > localU or gone[key] == nil then
                -- ab 0.90: als Zahl ohne Grenzen, Werte unbekannt (Zeit 0), jede Grenze ist neuer (wie watching.js)
                st[key] = bare and { u = uu, t = { buy = 0, up = 0 } } or S.NewFrom(inc, Wt.SPEC)
                gone[key] = nil
                changed = true
            end
        elseif bare then
            if uu > (tonumber(w.u) or 0) then w.u = uu; changed = true end
        elseif S.MergeFields(w, inc, Wt.SPEC, Wt.SKIP) then
            changed = true
        end
    end
    for k, u in pairs(type(data.gone) == "table" and data.gone or {}) do
        local key, uu = Key(k), tonumber(u) or 0
        local w = st[key]
        if w and uu > (tonumber(w.u) or 0) then st[key] = nil; gone[key] = uu; changed = true
        elseif not w and uu > (tonumber(gone[key]) or 0) then gone[key] = uu; changed = true end
    end
    return changed
end
