-- Peon_Broker - Focus.lua
-- Neuaufbau N6 (ab 0.64, Konzept Peon_Broker_Neuaufbau.md, Abschnitt 6.1): Seite "Fokus".
-- Immer genau ein Gegenstand (KarloDerBaer, 11.11.2026). Die Seite zeigt alles Wichtige nur fuer ihn und fragt am
-- Auktionator nur ihn regelmaessig neu ab (Radar.lua, R.SetFocus):
--   links   Kopf, Urteil mit einem Satz, Angaben (Art, Kaufen bis, Menge, Einsatz, Ziel, Gewinn, Verkauft in, Risiko),
--           eigenes Ziel, Gold-Knopf Kaufen, darunter Im Markt zeigen und Gegenstand
--   rechts  der Markt in diesem Moment: Preisstufen mit Summen, darunter Messung und Diagramm (Measure.lua)
-- Ab 0.70 (Anmerkungen KarloDerBaer, 12.11.2026):
--   - nur am Auktionshaus (unterwegs grau wie Verkaufen) und nur mit Live-Daten: die Preisstufen kommen aus der
--     letzten Abfrage des Fokus, nie aus dem Komplettscan
--   - eigenes Ziel: von Hand eintragen oder per Klick auf eine Preisstufe. Gekauft wird dann alles unter dem Ziel,
--     auch ohne Chance aus dem Radar (Art "Eigenes Ziel", wird wie ein Aufkauf ein Posten)
--   - Abfragen je Minute statt Sekunden, Fenster "Einstellungen" (Settings.lua)
-- Ab 0.133 (U1, Konzept Peon_Broker_Schlank.md 3, 4.1, 4.3, 4.5): Der Reiter heisst Einkaufen und zeigt nur den
-- Schnellkauf (Aufkauf ruht hinter focusBuyout). Jede Eingabe wird sofort gespeichert (F.Store), Gegenstand und Im Markt
-- zeigen stehen im Rechtsklick-Menue auf den Namen, Zurueck und Einstellungen sind kleine Symbole. Links: Kaufen bis,
-- Menge (Regler bis "Alle"), Goldreserve, Markt (Zufluss und Abfluss), Einbruch, Gekauft heute, Kaufknopf, darunter
-- aufklappbar Lockangebot und Mehr Einstellungen.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local F = {}
ns.Focus = F

F.key = nil      -- Gegenstand im Fokus (Schluessel wie in der Preisdatenbank), gemerkt in PeonBrokerDB.focusKey
F.manual = nil   -- ab 0.70: eigenes Ziel { key, price } (nur diese Sitzung)
F.manualLimit = nil   -- ab 0.76: eigenes "Kaufen bis" { key, price }: nur bis zu diesem Preis kaufen, Ziel bleibt
F.manualSrc = nil     -- ab 0.82: "watch" = eigene Werte kommen aus der Beobachtung (Art "Beobachten"), sonst "own"
F.manualQty = nil     -- ab 0.99: feste Hoechstmenge { key, qty } (nur diese Sitzung), nil = alle
F.manualGold = nil    -- ab 0.112: Schnellkauf, hoechster Betrag je Kauf { key, gold } in Kupfer, nil = ohne Grenze
F.loaded = nil        -- ab 0.131: { key, mode }: fuer diesen Gegenstand und Modus gelten die Werte aus Beobachten (F.EnsureLoaded)
F.origin = "watch"    -- ab 0.82: wohin "Zurueck" fuehrt: "chances" (ab 0.105 auch statt Radar) oder "watch" (sonst)
                      -- ab 0.152 auch "market" (Klick in Blizzards Markt, AHTabs.OnBrowseResult)
F.since = 0      -- ab 0.70: Live-Daten zaehlen erst ab hier (time(), neuer Gegenstand oder Auktionshaus geoeffnet)

local GREY, GREEN, ORANGE, YELLOW = "|cff999999", "|cff60e060", "|cffff9933", "|cffffd100"
local function Money(v) return ns.Tooltip.Money(v) end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function AHOpen() return ns.Scan.ahOpen and rawget(_G, "C_AuctionHouse") ~= nil end
local function On(b, v) if v then b:Enable() else b:Disable() end end
local function Now() return GetTime and GetTime() or time() end

-- Ist die Seite Fokus zu sehen (Reiter im Auktionshaus oder im Broker-Fenster)?
function F.Shown()
    local T = ns.AHTabs
    if T and T.current == "focus" then return true end
    if T and T.host and T.host.focus == "ah" then return false end
    return W.IsOpen() and W.current == "focus"
end

-- Chance zum Gegenstand im Fokus: Treffer des Radars, sonst der zuletzt weggefallene (grau), sonst nil
function F.Chance()
    local R = ns.Radar
    if F.key == nil then return nil end
    return R.entries[F.key] or R.gone[F.key]
end

-- Posten zum Gegenstand im Fokus (ab 0.67): offen (noch einzustellen) zuerst, sonst eingestellt. Rueckgabe lot, Zustand
function F.Lot()
    local LT = ns.Lots
    if not LT or F.key == nil then return nil end
    local lot = LT.ForKey(F.key)
    if lot then return lot, "open" end
    lot = LT.Posted(F.key)
    if lot then return lot, "posted" end
    return nil
end

-- Messung des Gegenstands im Fokus, solange sie laeuft (am Auktionator), sonst nil
function F.LiveValues()
    local M = ns.Measure
    local c = M and M.cur
    if not (c and F.key ~= nil and c.key == F.key and AHOpen()) then return nil end
    return M.Values()
end

-- ab 0.66 (H2): Verkaufsdauer aus dem gemessenen Abfluss, sobald die Messung genug zeigt
function F.SellHours(d)
    if not F.LiveValues() then return nil end
    return ns.Measure.SellHours(d.qty)
end

---------------------------------------------------------------------------
-- Live-Daten und eigenes Ziel (ab 0.70)
---------------------------------------------------------------------------
-- Letzte Live-Abfrage des Gegenstands im Fokus: rows, Zeit (time()), Warenart oder nil
function F.LiveRows()
    if F.key == nil or not AHOpen() then return nil end
    local lv = ns.Buy.live and ns.Buy.live[F.key]
    local from = math.max(F.since or 0, ns.Scan.ahShownAt or 0)
    if type(lv) ~= "table" or type(lv.rows) ~= "table" or (lv.t or 0) < from then return nil end
    return lv.rows, lv.t, lv.commodity
end

-- Eigenes Ziel fuer key (oder nil)
function F.ManualTarget(key)
    local m = F.manual
    if m and key ~= nil and m.key == key and Num(m.price) and m.price > 0 then return m.price end
    return nil
end

-- Eigenes "Kaufen bis" fuer key (oder nil)
function F.ManualLimit(key)
    local m = F.manualLimit
    if m and key ~= nil and m.key == key and Num(m.price) and m.price > 0 then return m.price end
    return nil
end

local function ClearMoney(t)
    if not t then return end
    for _, k in ipairs({ "gold", "silver", "copper" }) do if t[k] then t[k]:SetText("") end end
end

-- ab 0.166.3: Ein nicht beobachteter Gegenstand bekommt beim Eintragen kein gespeichertes Kaufen bis mehr. Bisher galt
-- das Limit ueber den gespeicherten Wert als eingeschaltet (Quick.LimitOn), jetzt setzt das Eintragen den Haken fuer
-- die Sitzung, solange man ihn nicht selbst geschaltet hat.
function F.LimitOnUnwatched()
    local Q = ns.Quick
    if not (Q and F.manualLimit and F.key ~= nil) or (ns.Watch and ns.Watch.Is(F.key)) then return end
    if Q.limitOn[F.key] == nil then Q.limitOn[F.key] = true end
    if Q.tab and Q.tab[F.key] == nil then Q.tab[F.key] = "limit" end   -- ab 0.168: ein Limit gehoert zum Limitkauf
end

-- "Kaufen bis" setzen (Rechtsklick auf eine Preisstufe), price = nil: wieder alles unter dem Ziel
function F.SetLimit(price)
    if F.key == nil then return end
    F.manualSrc = "own"
    if Num(price) and price > 0 then F.manualLimit = { key = F.key, price = math.floor(price) } else F.manualLimit = nil end
    if ns.Quick then ns.Quick.NoteLimit(F.key, F.manualLimit) end   -- ab 0.107.1: selbst geleert merken
    if F.limitInput then
        if F.manualLimit then F.limitInput:SetAmount(F.manualLimit.price) else ClearMoney(F.limitInput) end
    end
    F.LimitOnUnwatched()
    F.Store(false, true)   -- ab 0.133 sofort speichern. Ab 0.166.3 nur schon beobachtete Gegenstaende (Wunsch KarloDerBaer), neu in Beobachten nur per Stern
    F.ToLists()   -- ab 0.140: Hoechstpreis in den Listen
    F.Update()
end

-- ab 0.140 (KarloDerBaer 26.11.2026): Kaufen bis des Einkaufens ist der Hoechstpreis in allen Listen mit diesem
-- Gegenstand (wie Beobachten). Nur im Schnellkauf, der Aufkauf hat eigene Grenzen.
function F.ToLists()
    if F.key == nil or not (ns.Buy and ns.Buy.SetMaxFromShop) or not (ns.Quick and ns.Quick.On()) then return end
    ns.Buy.SetMaxFromShop(F.key, F.ManualLimit(F.key))
end

-- ab 0.140: nicht beobachtet, aber in einer Liste: Kaufen bis aus dem Hoechstpreis der Liste
function F.LoadList(key)
    if key == nil or not (ns.Buy and ns.Buy.MaxForShop) or not (ns.Quick and ns.Quick.On()) then return false end
    local v = ns.Buy.MaxForShop(key, ns.Quick.fromList and ns.Quick.fromList[key])
    if not Num(v) then return false end
    F.manualLimit = { key = key, price = math.floor(v) }
    F.manualSrc = "list"
    F.loaded = { key = key, mode = "quick" }
    return true
end

-- Getipptes "Kaufen bis" (0 = leer)
function F.SetLimitTyped(amount)
    if F.key == nil then return end
    F.manualSrc = "own"
    if Num(amount) and amount > 0 then F.manualLimit = { key = F.key, price = math.floor(amount) } else F.manualLimit = nil end
    if ns.Quick then ns.Quick.NoteLimit(F.key, F.manualLimit) end   -- ab 0.107.1: selbst geleert merken
    F.LimitOnUnwatched()
    F.Store(false, true)   -- ab 0.133 sofort speichern. Ab 0.166.3 nur schon beobachtete Gegenstaende (Wunsch KarloDerBaer), neu in Beobachten nur per Stern
    F.ToLists()   -- ab 0.140
    F.Update()
end

---------------------------------------------------------------------------
-- Menge (ab 0.99, Wunsch KarloDerBaer 16.11.2026): feste Hoechstmenge per Schieberegler oder Feld. Sie bleibt,
-- wenn sich die Menge im Markt aendert (der Regler rueckt dann, die Zahl nicht). Regler ganz rechts = alle.
---------------------------------------------------------------------------
function F.ManualQty(key)
    local m = F.manualQty
    if m and key ~= nil and m.key == key and Num(m.qty) and m.qty > 0 then return m.qty end
    return nil
end

-- n = Hoechstmenge, nil oder < 1 = alle
function F.SetQty(n)
    if F.key == nil then return end
    n = tonumber(n)
    if n and n >= 1 then F.manualQty = { key = F.key, qty = math.floor(n) } else F.manualQty = nil end
    F.Update()
end

-- Getippte Menge (leer oder 0 = alle). Ab 0.133 im Schnellkauf die Menge des Einkaufens (Quick.lua)
function F.SetQtyTyped(n)
    if ns.Quick and ns.Quick.On() then return ns.Quick.SetQty(n) end
    F.SetQty(n)
end

-- ab 0.112 (Wunsch KarloDerBaer): im Schnellkauf Max. Gold statt Max. Menge. Faengt grosse Mengen ab, die mit dem
-- Durchschnittspreis schnell teuer werden.
function F.ManualGold(key)
    local m = F.manualGold
    if m and key ~= nil and m.key == key and Num(m.gold) and m.gold > 0 then return m.gold end
    return nil
end

function F.SetGold(amount)
    if F.key == nil then return end
    if Num(amount) and amount > 0 then
        F.manualGold = { key = F.key, gold = math.floor(amount) }
        if ns.Quick then ns.Quick.goldCleared[F.key] = nil end
    else
        F.manualGold = nil
        if ns.Quick then ns.Quick.goldCleared[F.key] = true end   -- ab 0.113: selbst geleert bleibt leer
    end
    F.Update()
end
F.SetGoldTyped = F.SetGold

-- Regler bewegt (nicht beim Nachziehen durch die Anzeige): ganz rechts heisst alle
function F.OnQtySlider(v)
    if F.qtySync or F.key == nil or not Num(v) then return end
    v = math.floor(v + 0.5)
    local max = F.qtyMax or 0
    if max < 1 then return end
    if ns.Quick and ns.Quick.On() then
        -- ab 0.140: Massenware ganz links Alle, sonst die Zahl. Einzelware mindestens 1.
        if F.qtyMass then
            -- ab 0.167: ohne Haken gibt es kein Alle (Regler beginnt bei 1)
            if v <= 0 and ns.Quick.BuyKind(F.key) ~= "normal" then ns.Quick.SetQty(nil) else ns.Quick.SetQty(math.max(1, v)) end
        end   -- ab 0.167: Einzelstuecke fest 1
        return
    end
    if v >= max then F.SetQty(nil) else F.SetQty(math.max(1, v)) end
end

-- Plan auf die feste Menge begrenzen. Gibt immer eine Kopie zurueck (Chancen des Radars bleiben unberuehrt),
-- mit maxQty = was ohne Grenze gekauft wuerde und buyLimit = Preis des teuersten Stuecks dieses Kaufs.
-- cap (ab 0.112): feste Menge vom Aufrufer, false = keine, nil = die feste Menge des Aufkaufs (F.ManualQty)
function F.CapPlan(d, cap)
    if not d or d.gone then return d end
    local c = {}
    for k, v in pairs(d) do c[k] = v end
    local best = d.best or {}
    -- eigenes Ziel: auch was gerade zu teuer fuer mein Gold ist (mit kleinerer Menge geht es vielleicht)
    local max = (d.own and Num(d.qty) and d.qty) or (Num(best.qty) and best.qty) or 0
    c.maxQty = max
    if cap == nil then cap = F.ManualQty(d.key or F.key) elseif cap == false then cap = nil end
    if not cap or max < 1 or cap >= max then return c end
    if cap < 1 then   -- ab 0.112: Max. Gold reicht nicht fuer ein Stueck
        c.best = { qty = 0, cost = 0 }
        c.qty, c.cost, c.gain, c.showGain, c.buyLimit, c.capped = 0, 0, nil, nil, 0, true
        return c
    end
    local D = ns.Data
    local cost, got, last = D.CostOf(d.rows or {}, cap)
    if got < 1 then   -- ohne Preisstufen (Stand des Managers): anteilig
        got, last = cap, d.limit
        cost = math.floor((Num(best.cost) and best.cost or 0) * cap / max + 0.5)
    end
    local gain
    if d.kind == "market" then gain = D.ProfitOf(d, got) end
    if not Num(gain) and Num(d.net) then gain = math.floor(d.net * got - cost) end
    if not Num(gain) and Num(best.gain) then gain = math.floor(best.gain * got / max) end
    c.best = { qty = got, cost = cost, gain = gain }
    c.qty, c.cost, c.gain, c.showGain = got, cost, gain, gain
    c.buyLimit = last
    c.capped = true
    if Num(d.perHour) and d.perHour > 0 then c.hours = got / d.perHour end
    if d.own then
        local budget = ns.Radar.Budget()
        c.cant = got < 1 or (budget ~= nil and cost > budget)
    end
    return c
end

-- "Auto": eigenes Ziel und eigenes "Kaufen bis" zurueck (ab 0.99 auch die Menge)
function F.ResetOwn()
    F.manualLimit, F.manualSrc, F.manualQty, F.manualGold = nil, nil, nil, nil
    ClearMoney(F.limitInput)
    F.SetTarget(nil)
end

local function SetManual(price)
    if Num(price) and price > 0 then F.manual = { key = F.key, price = math.floor(price) } else F.manual = nil end
    -- "Menge unter Ziel" gilt fuer ein Ziel: mit einem neuen Ziel beginnt die Messung neu
    if ns.Measure and ns.Measure.cur and ns.Measure.cur.key == F.key then ns.Measure.Start(F.key) end
    F.chartN = nil
end

-- Eigenes Ziel setzen (price = nil: wieder das Ziel der Chance bzw. die zweite Preisstufe)
function F.SetTarget(price)
    if F.key == nil then return end
    F.manualSrc = price and "own" or nil
    SetManual(price)
    if F.manual and F.targetInput then F.targetInput:SetAmount(F.manual.price) else F.ClearInput() end
    F.Update()
end

-- Getipptes Ziel (Betrag 0 = leer: zurueck zum Ziel der Chance)
function F.SetTargetTyped(amount)
    if F.key == nil then return end
    F.manualSrc = "own"
    SetManual(amount)
    F.Update()
end

function F.ClearInput()
    ClearMoney(F.targetInput)
end

function F.ClearLimitInput()
    ClearMoney(F.limitInput)
end

-- ab 0.82: Fokus geoeffnet von einer Seite. Aus dem Radar: zurueck zum Radar. Sonst zurueck zu Beobachten, und ist
-- der Gegenstand beobachtet, gelten seine gespeicherten Werte (Kaufen bis, Zielpreis) als eigene Werte.
function F.FromPage(key, from, want)
    if from == "focus" then return end           -- naechste Chance aus dem Fokus heraus: Herkunft bleibt
    F.origin = (from == "radar" or from == "chances") and "chances" or from == "list" and "list"
        or from == "market" and "market" or "watch"   -- ab 0.136 Listen, ab 0.152 Markt
    -- ab 0.106: aus Chancen immer Aufkauf, aus Beobachten der dort gespeicherte Modus
    -- ab 0.119: want = Modus der Liste, aus der man kommt (Unterreiter Schnellkauf in Chancen und Beobachten)
    local Wt = ns.Watch
    local mode = (want == "quick" or want == "buyout") and want
        or F.origin == "chances" and "buyout" or (Wt and Wt.Is(key) and Wt.Mode(key)) or nil
    if mode and ns.Quick then ns.Quick.SetMode(mode, true) end
    if F.origin == "watch" or F.origin == "list" or F.origin == "market" then
        if not F.LoadWatch(key) then F.LoadList(key) end   -- ab 0.140 auch aus der Liste, ab 0.152 aus dem Markt
    end
    F.UpdateBack()
    F.Update()
end

function F.LoadWatch(key)
    local Wt = ns.Watch
    if not (Wt and key ~= nil and Wt.Is(key)) then return false end
    local w = Wt.Store()[key]
    if ns.Quick and ns.Quick.On() then
        -- ab 0.106: Werte des Schnellkaufs (Kaufen bis, hoechste Menge), kein Zielpreis
        F.manual = nil
        F.manualLimit = Num(w.qlim) and w.qlim > 0 and { key = key, price = w.qlim } or nil
        F.manualQty = nil   -- ab 0.112: Max. Gold statt Max. Menge
        F.manualGold = Num(w.qgold) and w.qgold > 0 and { key = key, gold = w.qgold } or nil
        ns.Quick.goldCleared[key] = (w.qgold == 0) or nil   -- ab 0.113: 0 = ohne Grenze gespeichert
        F.manualSrc = F.manualLimit and "watch" or nil
        ns.Quick.skip[key] = nil   -- ab 0.109: Haken aus Beobachten
        ns.Quick.avg[key] = nil    -- ab 0.112
        ns.Quick.qty[key] = nil    -- ab 0.133: Menge aus Beobachten (qqty)
        ns.Quick.limitOn[key], ns.Quick.glide[key], ns.Quick.method[key] = nil, nil, nil   -- ab 0.143: Kaufart aus Beobachten
        local Q = ns.Quick   -- ab 0.168: Tab und Ausloeser aus Beobachten
        Q.tab[key], Q.trig[key], Q.trigPct[key], Q.trigFix[key] = nil, nil, nil, nil
        F.loaded = { key = key, mode = "quick" }
        return true
    end
    local limit = Wt.Limit(key)
    F.manualQty = nil   -- ab 0.106: die Max. Menge gehoert zum Schnellkauf
    F.manual = Num(w.up) and w.up > 0 and { key = key, price = w.up } or nil
    F.manualLimit = Num(limit) and limit > 0 and { key = key, price = math.floor(limit) } or nil
    F.manualSrc = (F.manual or F.manualLimit) and "watch" or nil
    if ns.Measure and ns.Measure.cur and ns.Measure.cur.key == key then ns.Measure.Start(key) end
    return true
end

-- ab 0.131 (Fehlermeldung KarloDerBaer 24.11.2026, Kaufen bis wurde nicht zuverlaessig gespeichert): Die Werte aus
-- Beobachten kamen nur beim Sprung aus Beobachten in den Fokus. Oeffnete man den Reiter direkt (auch nach /reload)
-- oder kam aus Chancen, fuellte Q.EnsureLimit Kaufen bis mit der Vorgabe (Haelfte des guenstigsten) und Q.EnsureGold
-- das Limit pro Kauf mit 5 Gold. Beim Verlassen speicherte F.AutoSave diese Vorgaben ueber die gespeicherten Werte.
-- Jetzt laedt der Schnellkauf die Werte einmal je Gegenstand, bevor er Vorgaben setzt. Nicht beobachtet: die Werte
-- im Fokus gehoeren zum Gegenstand, kommt er spaeter in Beobachten, werden sie gespeichert.
function F.EnsureLoaded()
    local key = F.key
    if key == nil or not (ns.Quick and ns.Quick.On()) then return end
    local l = F.loaded
    if l and l.key == key and l.mode == "quick" then return end
    F.loaded = { key = key, mode = "quick" }
    if not F.LoadWatch(key) then F.LoadList(key) end   -- ab 0.140
end

function F.Loaded(key)
    local l = F.loaded
    return l ~= nil and key ~= nil and l.key == key and l.mode == (ns.Quick and ns.Quick.Mode() or mod.db.focusMode)
end

-- Speichern: Gegenstand in die Beobachtung, mit den geltenden Werten (Kaufen bis = Grenze nach unten,
-- Zielpreis = Grenze nach oben). Vorhandene Eintraege werden aktualisiert.
-- quiet (ab 0.113): ohne Meldung im Chat und ohne Neuzeichnen (automatisches Speichern)
function F.Save(quiet)
    local key = F.key
    if key == nil or not ns.Watch then return false end
    local d = AHOpen() and F.Plan() or nil
    local live = d and not d.gone
    local target = F.ManualTarget(key) or (live and d.ref) or nil
    local limit = F.ManualLimit(key) or (live and d.limit) or nil
    local Wt, D = ns.Watch, ns.Data
    local e = D.Lookup(key)
    local name = (d and d.name) or D.ItemName(key, e) or tostring(key)
    if not Wt.Is(key) then
        Wt.Add(key, { name = name, quality = (d and d.quality) or (type(e) == "table" and e.ql) or nil, icon = ns.Buy.Icon(D.ItemID(key)) })
    end
    -- ab 0.106: im Schnellkauf nur dessen Werte, Kaufen bis und Zielpreis des Aufkaufs bleiben
    if ns.Quick and ns.Quick.On() then
        -- ab 0.133: Menge statt Limit pro Kauf. Das gespeicherte Limit (qgold) bleibt, wird aber nicht mehr genutzt.
        local ql = F.ManualLimit(key)
        Wt.SetQuickValues(key, ql, ns.Quick.qty[key], ns.Quick.SkipOn(key), ns.Quick.AvgOn(key))
        local ref, margin, minQ = ns.Quick.KindValues(key)   -- ab 0.167 Richtpreis, Gewinnspanne, Min. Menge
        Wt.SetQuickKind(key, ns.Quick.LimitOn(key), ns.Quick.GlideOn(key), ref, margin, minQ)   -- ab 0.143
        if Wt.SetQuickBand then Wt.SetQuickBand(key, ns.Quick.BandValues(key)) end   -- ab 0.168 Tab und Ausloeser
        if ql then F.manualSrc = "watch" end
        if not quiet then mod:Print(L.FOCUS_SAVED_QUICK:format(name, Num(ql) and Money(ql) or "-")) end
        if ns.WatchPage then ns.WatchPage.Refresh() end
        if not quiet then F.Update() end
        return true
    end
    Wt.SetMode(key, "buyout")
    Wt.SetLimit(key, Num(limit) and "abs" or nil, limit)
    Wt.SetUp(key, target)
    if F.manual or F.manualLimit then F.manualSrc = "watch" end
    if not quiet then mod:Print(L.FOCUS_SAVED:format(name, Num(limit) and Money(limit) or "-", Num(target) and Money(target) or "-")) end
    if ns.WatchPage then ns.WatchPage.Refresh() end
    if not quiet then F.Update() end
    return true
end

-- ab 0.113 (Wunsch KarloDerBaer): beim Verlassen des Reiters, Schliessen von Broker oder Auktionshaus, beim Wechsel
-- des Modus oder des Gegenstands speichern, was eingestellt ist. Je Modus abschaltbar (autoSaveBuyout,
-- autoSaveQuick, Vorgabe an). Nur fuer Gegenstaende, die schon in Beobachten stehen: sonst landete jeder angesehene
-- Gegenstand dort.
function F.AutoSave()
    local key = F.key
    local Wt = ns.Watch
    if key == nil or not (Wt and Wt.Is(key)) then return false end
    local quick = ns.Quick and ns.Quick.On()
    if quick and mod.db.autoSaveQuick == false then return false end
    if quick and not F.Loaded(key) then return false end   -- ab 0.131: nie Werte speichern, die nicht geladen waren
    if not quick and mod.db.autoSaveBuyout == false then return false end
    return F.Save(true)
end

-- ab 0.133 (U1, Konzept 2.3 und 4.5): jede Eingabe gilt sofort, der Knopf Speichern entfaellt. Gespeichert wird fuer
-- Gegenstaende in Beobachten. add = true: ein neuer Gegenstand kommt dabei in Beobachten (bis 0.166.2 beim Eintragen
-- von Kaufen bis, ab 0.166.3 ruft das niemand mehr so auf).
-- Nur mit geladenen Werten, damit nie Vorgaben ueber gespeicherte Werte geschrieben werden (wie 0.131).
-- user (ab 0.140, Board KarloDerBaer 26.11.2026: Kaufen bis kam nicht in Beobachten an): eine eigene Eingabe gilt
-- immer, auch wenn die gespeicherten Werte noch nicht als geladen markiert sind. Vorher ging sie dann verloren.
-- Menge und Haken bleiben dabei, wie sie gespeichert sind (Wt.SetQuickValues nimmt nur gesetzte Werte).
function F.Store(add, user)
    local key = F.key
    local Wt = ns.Watch
    if key == nil or not Wt then return false end
    local quick = ns.Quick and ns.Quick.On()
    if not quick then
        if Wt.Is(key) and mod.db.autoSaveBuyout ~= false then return F.Save(true) end
        return false
    end
    if not Wt.Is(key) and not add then return false end
    -- ab 0.140: aus einer Liste geoeffnet und nicht beobachtet: der Wert gehoert in die Liste (F.ToLists), nicht in Beobachten
    if not Wt.Is(key) and ns.Quick.fromList and ns.Quick.fromList[key] ~= nil then return false end
    if Wt.Is(key) and not F.Loaded(key) and not user then return false end
    F.loaded = { key = key, mode = "quick" }
    return F.Save(true)
end

-- Knopf "Zurueck zu ..." in der Kopfzeile (ab 0.133 als Symbol, ab 0.152 wieder ein Knopf mit Text, Wunsch
-- KarloDerBaer 26.11.2026: der Pfeil war kaum zu sehen). Er fuehrt dorthin, woher man kam.
function F.BackLabel()
    local label = F.origin == "chances" and L.TAB_CHANCES or F.origin == "list" and L.AHTAB_SHOP
        or F.origin == "market" and L.AHTAB_MARKET or L.NTAB_WATCH
    return L.FOCUS_BACK:format(label)
end

F.BACK_W = 160
function F.UpdateBack()
    local b = F.backButton
    if not b then return end
    -- zurueck zum Markt geht nur am Auktionshaus, unterwegs fuehrt der Knopf zu Beobachten
    if F.origin == "market" and not (ns.Window.AtAH and ns.Window.AtAH()) then F.origin = "watch" end
    b:SetText(F.BackLabel())
end

function F.GoBack()
    -- ab 0.152: zurueck zum Markt schliesst nur Brokers Flaeche. Blizzards Ansicht schaltet Broker nie selbst um
    -- (Buy.ShowInAH, Fehlerberichte 10 und 11), Blizzard zeigt darum den zuletzt gewaehlten Gegenstand im Markt.
    if F.origin == "market" and ns.AHTabs and ns.AHTabs.current then
        ns.AHTabs.Close()
        return
    end
    ns.Window.Open(F.origin == "chances" and "chances" or F.origin == "list" and "buy" or "watch")
end

-- ab 0.152 (Wunsch KarloDerBaer 26.11.2026): Stern wie Blizzards Favoriten-Stern im Markt. Er zeigt, ob der Gegenstand
-- in Beobachten steht, ein Klick nimmt ihn auf (mit den Werten, die gerade gelten, F.Save) oder nimmt ihn heraus.
-- Blizzards Favoriten bleiben unberuehrt.
F.STAR_ON, F.STAR_OFF = "auctionhouse-icon-favorite", "auctionhouse-icon-favorite-off"
function F.BuildStar(header)
    local b = CreateFrame("Button", nil, header)
    b:SetSize(20, 18)
    b:SetPoint("TOPRIGHT", header, "TOPRIGHT", -6, -6)
    if b.SetFrameLevel and header.GetFrameLevel then b:SetFrameLevel((header:GetFrameLevel() or 1) + 2) end
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    Peon.UI.SetAtlas(b.hl, F.STAR_OFF, false)
    if b.hl.SetBlendMode then b.hl:SetBlendMode("ADD") end
    b:SetScript("OnClick", function() mod:Call("Beobachten", F.ToggleWatch) end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local on = ns.Watch and ns.Watch.Is(F.key)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(on and L.FOCUS_STAR_DEL or L.FOCUS_STAR_ADD, 1, 0.82, 0)
        GameTooltip:AddLine(on and L.FOCUS_STAR_DEL_TIP or L.FOCUS_STAR_ADD_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    F.star = b
    return b
end

function F.UpdateStar()
    local b = F.star
    if not b then return end
    b:SetShown(F.key ~= nil)
    local on = F.key ~= nil and ns.Watch and ns.Watch.Is(F.key) or false
    Peon.UI.SetAtlas(b.tex, on and F.STAR_ON or F.STAR_OFF, false)
    b.on = on
end

function F.ToggleWatch()
    local key, Wt = F.key, ns.Watch
    if key == nil or not Wt then return false end
    if Wt.Is(key) then
        Wt.Remove(key)
        mod:Print(L.FOCUS_STAR_REMOVED:format(tostring(ns.Data.ItemName(key, (ns.Data.Lookup(key))) or key)))
    else
        F.Save(true)
        F.loaded = { key = key, mode = ns.Quick and ns.Quick.Mode() or mod.db.focusMode }
    end
    if ns.WatchPage then ns.WatchPage.Refresh() end
    F.Update()
    return Wt.Is(key)
end

-- Kauf "alles unter dem Ziel" aus den Live-Stufen. Rueckgabe: Plan wie eine Chance (kind "own") oder nil
function F.OwnPlan(target, buyLimit)
    local rows, t, commodity = F.LiveRows()
    if not rows then return nil end
    local D = ns.Data
    local key = F.key
    if commodity == nil then commodity = D.IsCommodity(key) end
    local lv = D.Available(rows)
    if not Num(target) then target = lv[2] and lv[2].price or (lv[1] and lv[1].price) end
    if not Num(target) then return nil end
    local qty, cost, limit, nextQty, near = 0, 0, nil, 0, 0
    for _, l in ipairs(lv) do
        if l.price < target then
            -- ab 0.76: mit eigenem "Kaufen bis" nur die Stufen bis dorthin, die teureren unter dem Ziel bleiben stehen
            if not Num(buyLimit) or l.price <= buyLimit then
                qty, cost, limit = qty + l.qty, cost + l.qty * l.price, l.price
            end
        else
            if nextQty == 0 then nextQty = l.qty end
            if l.price <= target * (1 + ns.Buyout.RISK_NEAR_PCT) then near = near + l.qty end
        end
    end
    local cut = D.Cut()
    local ctx = ns.Buyout.Context(nil, key)
    local e = D.Lookup(key)
    local d = {
        kind = "own", key = key, own = true, commodity = commodity and true or false, rows = rows, live = true,
        checked = Now() - math.max(0, time() - (t or time())), seenT = t,
        name = (type(e) == "table" and e.nm) or D.ItemName(key, e), quality = type(e) == "table" and e.ql or nil,
        qty = qty, cost = cost, limit = limit, ref = target, net = target * (1 - cut), ownLimit = Num(buyLimit) and buyLimit or nil,
        gain = math.floor(qty * target * (1 - cut) - cost),
        hours = (ctx.perHour or 0) > 0 and qty / ctx.perHour or nil, perHour = ctx.perHour, sales = ctx.sales, band = ctx.band,
        nextQty = nextQty, nearQty = near,
    }
    local budget = ns.Radar.Budget()
    d.cant = qty < 1 or (budget ~= nil and cost > budget)
    d.best = { qty = d.cant and 0 or qty, cost = cost, gain = d.gain }
    d.showGain = d.gain
    return d
end

-- Was der Fokus gerade anbietet: Chance des Radars (ohne eigenes Ziel), sonst Kauf unter dem Ziel
function F.Plan()
    if F.key == nil then return nil end
    if ns.Quick and ns.Quick.On() then return ns.Quick.Plan() end   -- ab 0.104: Schnellkauf
    local manual = F.ManualTarget(F.key)
    local buyLimit = F.ManualLimit(F.key)
    local d = ns.Radar.entries[F.key]
    if d and not manual and not buyLimit then
        ns.Radar.Annotate(d, ns.Radar.Budget())
        d.risk = ns.Radar.Risk(d)
        return F.CapPlan(d)
    end
    -- eben weggefallene Chance: "VORBEI" mit Grund, bis man ein eigenes Ziel waehlt
    if not d and not manual and not buyLimit and ns.Radar.gone[F.key] then return ns.Radar.gone[F.key] end
    local M = ns.Measure
    local mt = M and M.cur and M.cur.key == F.key and M.cur.target or nil
    local p = F.CapPlan(F.OwnPlan(manual or (d and d.ref) or mt, buyLimit))
    if p then
        local age = p.seenT and (time() - p.seenT) or nil
        p.risk, p.riskWhy = ns.Buyout.Risk(p, age, ns.Radar.Budget())
    end
    return p
end

F.V_TEXT = { buy = "FOCUS_V_BUY", wait = "MEASURE_V_WAIT", away = "MEASURE_V_AWAY", first = "MEASURE_V_FIRST" }
F.V_COLOR = { buy = GREEN, wait = YELLOW, away = "|cffff5555", first = GREY }

-- Urteil: ohne Messung aus der Chance, mit Messung aus dem Marktverhalten (Konzept 6.1). Rueckgabe: Text, Farbe, Satz
function F.Verdict(d)
    if not AHOpen() then return L.FOCUS_V_AH, GREY, L.FOCUS_W_AH end
    if ns.Quick and ns.Quick.On() then return ns.Quick.Verdict(d) end   -- ab 0.104
    -- ab 0.67 (H3): nach dem Kauf zeigt der Fokus den Posten (unterwegs per Post, eingestellt und bewacht)
    if not d or d.gone then
        local lot, state = F.Lot()
        if state == "open" then
            return L.FOCUS_V_BOUGHT, GREY, L.FOCUS_W_BOUGHT:format(lot.target and Money(lot.target) or "?")
        elseif state == "posted" then
            local v = F.LiveValues()
            if not v then return L.FOCUS_V_POSTED, GREY, L.FOCUS_W_POSTED:format(Money(lot.posted.price or 0)) end
            if v.underTrend == "grow" then return L.FOCUS_V_GUARD_BAD, "|cffff5555", L.FOCUS_W_GUARD_GROW end
            if (v.under or 0) > 0 then return L.FOCUS_V_GUARD_MID, YELLOW, L.FOCUS_W_GUARD_UNDER:format(v.under) end
            return L.FOCUS_V_GUARD_OK, GREEN, L.FOCUS_W_GUARD_OK
        end
        if not d then return L.FOCUS_V_WAIT, GREY, L.FOCUS_W_WAIT end
    end
    if d.gone then return L.FOCUS_V_GONE, GREY, tostring(d.goneWhy or "") end
    if d.own then
        if (d.qty or 0) < 1 then return L.FOCUS_V_NONE, GREY, L.FOCUS_W_NOTHING end
        if (d.gain or 0) <= 0 then return L.FOCUS_V_LOSS, ORANGE, L.FOCUS_W_LOSS end
        if d.cant then return L.FOCUS_V_CANT, ORANGE, L.FOCUS_W_GOLD end
    elseif d.cant then
        return L.FOCUS_V_CANT, ORANGE, L.FOCUS_W_CANT
    end
    local v = (d.kind == "buyout" or d.own) and F.LiveValues() or nil
    if v then
        local code, why, early = ns.Measure.Verdict(v)
        local text = L[F.V_TEXT[code]] or code
        if early and code ~= "first" then text = text .. " " .. L.MEASURE_EARLY end
        return text, F.V_COLOR[code] or GREY, why
    end
    if d.own then return L.FOCUS_V_OWN, YELLOW, L.FOCUS_W_OWN end
    -- ab 0.93 (Peon_Manager_Chancen.md 9.2): bei einer Chance vom Manager dessen Satz und das Alter seines Stands
    local mgr = ns.Spec and ns.Spec.FocusText(d.key or F.key)
    if d.kind == "spec" then return L.FOCUS_V_BUY, GREEN, mgr or L.FOCUS_W_SPEC end
    local w = L["FOCUS_W_" .. tostring(d.kind):upper()] or ""
    if mgr then w = w .. " " .. GREY .. mgr .. "|r" end
    return L.FOCUS_V_BUY, GREEN, w
end

-- Verkaufsdauer: aus dem Absatz der letzten Stunden (H1), ab H2 aus der Messung, sobald sie genug zeigt
function F.SellsText(d)
    local mh = F.SellHours(d)
    if mh then return ns.Buyout.HoursText(mh) .. " " .. GREY .. L.FOCUS_MEASURED .. "|r" end
    return ns.Buyout.HoursText(d.hours)
end

-- Angaben unter den Eingabefeldern: Liste aus { Beschriftung, Wert, tip = Zeilen fuer den Tooltip }.
-- Ab 0.77 (KarloDerBaer 12.11.2026) nur noch Ueblich, Verkauft in, Risiko. Art steht in eigener Zeile mit "Auto",
-- Ziel und Kaufen bis in den Eingabefeldern, Menge, Kosten und Gewinn ueber dem Kaufknopf.
function F.Rows(d)
    local R = ns.Radar
    local rows = {}
    if not d or d.gone then
        -- ab 0.67: Angaben zum Posten (gekauft oder eingestellt)
        local lot, state = F.Lot()
        if lot then
            local unit = ns.Lots.UnitCost(lot)
            if unit then rows[#rows + 1] = { L.LOTS_COL_COST, Money(math.floor(unit + 0.5)) } end
            if Num(lot.target) then rows[#rows + 1] = { L.FOCUS_R_TARGET, Money(lot.target) } end
            if state == "posted" and Num(lot.posted.price) then rows[#rows + 1] = { L.FOCUS_R_POSTED, Money(lot.posted.price) } end
            rows[#rows + 1] = { L.FOCUS_R_QTY, tostring(state == "posted" and (lot.posted.qty or lot.qty) or lot.left or lot.qty or 0) }
            return rows
        end
        if not d then return rows end
    end
    rows[#rows + 1] = { L.FOCUS_R_BAND, F.BandText(d) }
    if d.kind == "spec" and d.risk then
        rows[#rows + 1] = { L.RADAR_COL_RISK, (R.RISK_COLOR[d.risk] or "") .. (L["RADAR_RISK_" .. d.risk:upper()] or d.risk) .. "|r" }
        if d.ref then rows[#rows + 1] = { L.FOCUS_R_TARGET, Money(d.ref) } end
    end
    if d.kind == "buyout" or d.own then
        rows[#rows + 1] = { L.FOCUS_R_SELLS, F.SellsText(d) }
        if d.risk then
            rows[#rows + 1] = { L.RADAR_COL_RISK, (R.RISK_COLOR[d.risk] or "") .. (L["RADAR_RISK_" .. d.risk:upper()] or d.risk) .. "|r",
                                tip = d.riskWhy }
        end
    end
    return rows
end

-- Art als Text (Zeile "Art" mit "Auto" dahinter)
function F.KindText(d)
    if not d or d.gone then return "" end
    if d.own then return F.manualSrc == "watch" and L.FOCUS_KIND_WATCH or L.FOCUS_KIND_OWN end
    return L["RADAR_KIND_" .. tostring(d.kind):upper()] or tostring(d.kind)
end

-- Eingabefelder zeigen die Werte, die gerade gelten (ab 0.77). Nicht, waehrend man darin tippt.
local function Typing(m)
    if not m then return false end
    for _, k in ipairs({ "gold", "silver", "copper" }) do
        local e = m[k]
        if e and e.HasFocus and e:HasFocus() then return true end
    end
    return false
end

function F.SyncInputs(d)
    local live = d and not d.gone
    -- ab 0.80.1: eigene Werte so zeigen, wie man sie eingetragen hat. Vorher stand bei "Kaufen bis" die teuerste
    -- gekaufte Stufe, und lag der eigene Wert unter dem guenstigsten Angebot, wurde das Feld leer.
    local target = F.ManualTarget(F.key) or (live and d.ref)
    local limit = F.ManualLimit(F.key) or (live and d.limit)
    for _, f in ipairs({ { F.targetInput, target }, { F.limitInput, limit } }) do
        local m, v = f[1], f[2]
        if m and not Typing(m) then
            if Num(v) and v > 0 then m:SetAmount(v) else ClearMoney(m) end
        end
    end
end

-- Regler auf Bereich und Stelle setzen, ohne dass das als eigene Wahl zaehlt (F.qtySync)
local function SliderSet(s, lo, hi, pos, enabled)
    if s.peonMin ~= lo or s.peonMax ~= hi or s.peonVal ~= pos then
        F.qtySync = true
        if type(s.Slider) == "table" and type(s.Init) == "function" then
            -- MinimalSliderWithSteppersTemplate. Ab 0.99.1 ohne eigene Zahl rechts (zeigte einen alten Stand, die
            -- Menge steht im Feld daneben)
            local mix = rawget(_G, "MinimalSliderWithSteppersMixin")
            local right = mix and mix.Label and mix.Label.Right
            pcall(s.Init, s, pos, lo, hi, math.max(1, hi - lo), right and { [right] = function() return "" end } or nil)
            if type(s.RightText) == "table" and s.RightText.Hide then s.RightText:Hide() end
        else
            if s.SetMinMaxValues then s:SetMinMaxValues(lo, hi) end
            if s.SetValue then s:SetValue(pos) end
        end
        F.qtySync = false
        s.peonMin, s.peonMax, s.peonVal = lo, hi, pos
    end
    if s.peonOn ~= enabled then
        s.peonOn = enabled
        if type(s.SetEnabled) == "function" then pcall(s.SetEnabled, s, enabled)
        elseif enabled then s:Enable() else s:Disable() end
    end
end

-- Zeile Menge: Regler, Feld (zeigt die feste Menge oder, ohne sie, alle) und Hinweis "alle" bzw. "von N"
function F.SyncQty(d)
    if not F.qtySlider then return end
    if ns.Quick and ns.Quick.On() then return F.SyncQuickQty(d) end   -- ab 0.106, ab 0.133 Regler bis Alle
    local has = d ~= nil and not d.gone and F.key ~= nil
    for _, f in ipairs({ F.qtyLabel, F.qtySlider, F.qtyInput, F.qtyHint, F.qtyHover }) do if f then f:SetShown(has) end end
    local max = has and (d.maxQty or 0) or 0
    F.qtyMax = max
    if not has then return end
    local cap = F.ManualQty(F.key)
    if not (F.qtyInput.HasFocus and F.qtyInput:HasFocus()) then
        F.qtyInput:SetText(tostring(cap or max))
    end
    F.qtyHint:SetText(cap and (GREY .. L.FOCUS_QTY_MAX:format(max) .. "|r") or (GREEN .. L.FOCUS_QTY_ALL .. "|r"))
    if max >= 2 then SliderSet(F.qtySlider, 1, max, cap and math.min(cap, max) or max, true)
    else SliderSet(F.qtySlider, 0, 1, math.min(max, 1), false) end
end

-- ab 0.106: Max. Menge im Schnellkauf, ab 0.112 Max. Gold, ab 0.133 Regler von 1 bis "Alle".
-- Ab 0.140 (Board KarloDerBaer 26.11.2026): der Regler reicht ueber das ganze Marktangebot (alle Stufen). Massenware:
-- ganz links "Alle", nach rechts 1 bis Marktangebot. Einzelware: ganz links 1, nach rechts mehr. Hinter dem Feld kein
-- Zusatz mehr, Max. Preis und Goldreserve stehen in der Zeile darunter (F.MaxText).
function F.MarketSupply()
    local rows = F.LiveRows()
    local n = 0
    for _, l in ipairs(rows and ns.Data.Available(rows) or {}) do n = n + l.qty end
    return n
end

function F.SyncQuickQty(d)
    local Q = ns.Quick
    local key = F.key
    local has = key ~= nil
    if F.goldInput then F.goldInput:Hide() end
    for _, f in ipairs({ F.qtyLabel, F.qtySlider, F.qtyInput, F.qtyHint, F.qtyHover }) do if f then f:SetShown(has) end end
    if F.qtyOne then F.qtyOne:Hide() end
    if not has then F.qtyMax = 0; if F.qtyAll then F.qtyAll:Hide() end; return end
    F.qtyHint:SetText("")
    local mass = ns.Data.IsCommodity(key)
    local supply = F.MarketSupply()
    F.qtyMax, F.qtyMass = supply, mass
    local want = Q.QtyWant(key)
    -- ab 0.167 (Board KarloDerBaer 27.11.2026): mit Haken Limit oder Gleitend heisst die Zeile Max. Menge (ganz links
    -- Alle), ohne Haken Menge ab 1. Einzelstuecke fest 1, Regler und Feld gesperrt.
    local capped = Q.BuyKind(key) ~= "normal"
    F.qtyLabel:SetText((mass and capped) and L.QUICK_QTY_MAX or L.FOCUS_R_QTY)
    local typing = F.qtyInput.HasFocus and F.qtyInput:HasFocus()
    if not typing then F.qtyInput:SetText(want and tostring(want) or "") end
    if F.qtyInput.SetEnabled then F.qtyInput:SetEnabled(mass and true or false) end
    if F.qtyAll then F.qtyAll:SetShown(mass and not want and not typing) end
    if not mass then
        SliderSet(F.qtySlider, 0, 1, 1, false)
        -- ab 0.171: Regler und Feld weg, dafuer "1 Stueck"
        F.qtySlider:Hide(); F.qtyInput:Hide()
        if F.qtyAll then F.qtyAll:Hide() end
        if F.qtyOne then F.qtyOne:SetText(L.QUICK_QTY_ONE); F.qtyOne:Show() end
    elseif capped then
        if supply >= 1 then SliderSet(F.qtySlider, 0, supply, want and math.min(want, supply) or 0, true)
        else SliderSet(F.qtySlider, 0, 1, 0, false) end
    else
        if supply >= 2 then SliderSet(F.qtySlider, 1, supply, math.min(want or 1, supply), true)
        else SliderSet(F.qtySlider, 0, 1, 1, false) end
    end
end

-- ab 0.167: Zeile Min. Menge (nur Massenware mit Haken Limit oder Gleitend, sonst bleibt ihr Platz leer)
function F.SyncMinQty(key)
    local q = F.quick
    if not (q and q.minSlider) then return end
    local Q = ns.Quick
    local show = key ~= nil and Q.On() and ns.Data.IsCommodity(key) and Q.BuyKind(key) ~= "normal"
    for _, f in ipairs(q.minParts) do f:SetShown(show and true or false) end
    if not show then q.minOff:Hide(); return end
    local mn = Q.MinQty(key)
    local top = Q.MinMax()
    local typing = q.minInput.HasFocus and q.minInput:HasFocus()
    if not typing then q.minInput:SetText(mn and tostring(mn) or "") end
    q.minOff:SetShown(not mn and not typing)
    SliderSet(q.minSlider, 0, top, mn and math.min(mn, top) or 0, true)
end

function F.OnMinSlider(v)
    if F.qtySync or F.key == nil or not Num(v) then return end
    v = math.floor(v + 0.5)
    mod:Call("Schnellkauf", ns.Quick.SetMinQty, v > 0 and v or nil)
end

-- Ueblicher Bereich als Text ("1s 20c bis 1s 60c", sonst "unbekannt")
function F.BandText(d, key)
    local band = d and d.band
    key = key or F.key   -- ab 0.140 auch fuer Verkaufen
    if not band and key ~= nil then band = ns.Buyout.Context(nil, key).band end
    if type(band) == "table" and Num(band.low) and Num(band.high) then
        return L.FOCUS_BAND:format(Money(math.floor(band.low + 0.5)), Money(math.floor(band.high + 0.5)))
    end
    return GREY .. L.FOCUS_BAND_NONE .. "|r"
end

-- Preisstufen der letzten Live-Abfrage mit Summen. Ab 0.77 blau hinterlegt, was der Kauf nimmt (bis Kaufen bis),
-- gelb die Stufe des Ziels.
function F.Tiers(limit, target)
    local rows = F.LiveRows()
    local out = {}
    if not rows then return out end
    local Q = ns.Quick
    local quick = Q and Q.On()
    local cum, cost = 0, 0
    for _, l in ipairs(ns.Data.Available(rows)) do
        cum, cost = cum + l.qty, cost + l.qty * l.price
        out[#out + 1] = { price = l.price, qty = l.qty, cum = cum, cost = cost, inBuy = Num(limit) and l.price <= limit or false,
                          isTarget = Num(target) and l.price == target or false, isNew = quick and Q.IsNew(l.price) or false }
    end
    -- ab 0.104: im Schnellkauf auch die eigenen Angebote (zaehlen nicht in Summe und Kosten)
    if quick then
        for _, r in ipairs(rows) do
            if Num(r.own) and r.own > 0 and Num(r.price) then
                out[#out + 1] = { price = r.price, qty = L.QUICK_OWN_QTY:format(r.own), isOwn = true }
            end
        end
        table.sort(out, function(a, b)
            if a.price ~= b.price then return a.price < b.price end
            return (a.isOwn and 1 or 0) < (b.isOwn and 1 or 0)
        end)
    end
    return out
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
F.ROW_Y, F.ROW_STEP = -236, 18   -- ab 0.77: Ueblich, Verkauft in, Risiko unter den Eingabefeldern (ab 0.82 enger)
F.KIND_Y, F.TARGET_Y, F.LIMIT_Y = -150, -180, -210
F.QTY_Y, F.QTY_SLIDER_W = -294, 140   -- ab 0.99: Zeile Menge nach dem Risiko
F.BLUE = "|cff4da6ff"
function F.Build(c)
    local UI = Peon.UI
    F.frame = c

    local left = UI.Panel(c, "left")
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(UI.LEFT_W)
    F.left = left
    -- ab 0.168: zwei anklickbare Tabs (Limitkauf, Direktkauf), im Aufkauf nur der erste mit seiner Ueberschrift
    F.sectionTab = F.MakeTab(left, L.FOCUS_HEAD_CHANCE, function()
        if ns.Quick.On() then mod:Call("Schnellkauf", ns.Quick.SetTab, "limit") end
    end)
    F.sectionTab:SetPoint("BOTTOMLEFT", left, "TOPLEFT", 42, -3)
    UI.SetTooltip(F.sectionTab, function() return ns.Quick.On() and { L.QUICK_TAB_LIMIT, L.QUICK_TAB_LIMIT_TIP } or nil end)
    F.directTab = F.MakeTab(left, L.QUICK_TAB_DIRECT, function() mod:Call("Schnellkauf", ns.Quick.SetTab, "direct") end)
    F.directTab:SetPoint("BOTTOMLEFT", F.sectionTab, "BOTTOMRIGHT", 2, 0)
    UI.SetTooltip(F.directTab, { L.QUICK_TAB_DIRECT, L.QUICK_TAB_DIRECT_TIP })
    F.header = UI.ItemHeader(left)
    F.header:SetPoint("TOPLEFT", 10, -10)
    F.header:SetScript("OnEnter", function(self)
        if F.key == nil then return end
        W.ShowItemTooltip(self, F.key)
        if GameTooltip and GameTooltip.AddLine then GameTooltip:AddLine(L.FOCUS_MENU_HINT, 0.6, 0.6, 0.6); GameTooltip:Show() end
    end)
    F.header:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    F.BuildStar(F.header)   -- ab 0.152
    -- ab 0.133 (U1, Konzept 4.5): Gegenstand und Im Markt zeigen stehen im Rechtsklick-Menue auf den Namen
    if F.header.RegisterForClicks then pcall(F.header.RegisterForClicks, F.header, "LeftButtonUp", "RightButtonUp") end
    F.header:SetScript("OnClick", function(self, button)
        if button == "RightButton" and F.key ~= nil then mod:Call("Menue", ns.Go.Menu, { key = F.key }, self) end
    end)
    -- ab 0.144 (Board KarloDerBaer) ohne sichtbaren Hinweis, der Tooltip des Namens nennt das Menue weiter
    F.verdict = UI.Text(left, "big", "")
    F.verdict:SetPoint("TOPLEFT", 16, -88)
    -- ab 0.91 (Fehlerbericht 22): Gekauftes zum Wiedereinstellen merken, je Gegenstand gespeichert
    F.relistCheck = UI.Check(left, L.FOCUS_RELIST, false, function(on)
        if F.key ~= nil and ns.Lots then ns.Lots.SetWanted(F.key, on) end
    end, { L.FOCUS_RELIST, L.FOCUS_RELIST_TIP })
    if F.relistCheck.SetScale then F.relistCheck:SetScale(0.85) end
    F.relistCheck:SetPoint("TOPLEFT", (UI.LEFT_W - 150) / 0.85, -82 / 0.85)
    F.why = UI.Text(left, "text", "", UI.LEFT_W - 32)
    F.why:SetPoint("TOPLEFT", 16, -110)
    -- ab 0.77: Art mit "Auto", Ziel (Linksklick), Kaufen bis (Rechtsklick)
    local function Label(text, y)
        local t = UI.Text(left, "label", text)
        t:SetWidth(UI.LABEL_W)
        t:SetJustifyH("RIGHT")
        t:SetPoint("TOPLEFT", 8, y)
        return t
    end
    F.kindLabel = Label(L.RADAR_COL_KIND, F.KIND_Y)
    F.kindValue = UI.Text(left, "text", "")
    F.kindValue:SetPoint("TOPLEFT", F.kindLabel, "TOPRIGHT", 12, 0)
    F.autoButton = UI.Button(left, L.FOCUS_AUTO, 60, function() F.ResetOwn() end)
    F.autoButton:SetPoint("LEFT", F.kindValue, "RIGHT", 10, 0)
    UI.SetTooltip(F.autoButton, { L.FOCUS_AUTO, L.FOCUS_AUTO_TIP })
    F.targetLabel = Label(L.FOCUS_R_TARGET, F.TARGET_Y)
    F.targetInput = UI.MoneyInput(left, function(amount) F.SetTargetTyped(amount) end)
    if F.targetInput.SetScale then F.targetInput:SetScale(0.8) end
    F.targetInput:SetPoint("LEFT", F.targetLabel, "RIGHT", 8 / 0.8, 0)
    F.targetHint = UI.Text(left, "small", "|cffffd100" .. L.FOCUS_RIGHT_CLICK .. "|r")   -- ab 0.83 Rechtsklick (vorher Linksklick)
    F.targetHint:SetPoint("LEFT", F.targetInput, "RIGHT", 4, 0)
    F.limitLabel = Label(L.FOCUS_R_LIMIT, F.LIMIT_Y)
    F.limitInput = UI.MoneyInput(left, function(amount) F.SetLimitTyped(amount) end)
    if F.limitInput.SetScale then F.limitInput:SetScale(0.8) end
    F.limitInput:SetPoint("LEFT", F.limitLabel, "RIGHT", 8 / 0.8, 0)
    F.limitHint = UI.Text(left, "small", F.BLUE .. L.FOCUS_LEFT_CLICK .. "|r")   -- ab 0.83 Linksklick (vorher Rechtsklick)
    F.limitHint:SetPoint("LEFT", F.limitInput, "RIGHT", 4, 0)

    F.rows = {}
    for i = 1, 4 do
        local r = {}
        r.label = UI.Text(left, "label", "")
        r.label:SetWidth(UI.LABEL_W)
        r.label:SetJustifyH("RIGHT")
        r.label:SetPoint("TOPLEFT", 8, F.ROW_Y - (i - 1) * F.ROW_STEP)
        r.value = UI.Text(left, "text", "")
        r.value:SetPoint("TOPLEFT", r.label, "TOPRIGHT", 12, 0)
        -- Tooltip einer Zeile (ab 0.65: Gruende fuer das Risiko)
        r.hover = CreateFrame("Frame", nil, left)
        r.hover:SetPoint("TOPLEFT", r.label, "TOPLEFT", 0, 2)
        r.hover:SetPoint("BOTTOMRIGHT", r.value, "BOTTOMRIGHT", 0, -2)
        r.hover:SetScript("OnEnter", function(self)
            if not (r.tip and #r.tip > 0 and GameTooltip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(r.label:GetText() or "", 1, 0.82, 0)
            for _, line in ipairs(r.tip) do GameTooltip:AddLine("- " .. line, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        r.hover:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        F.rows[i] = r
    end

    -- ab 0.99: Menge per Regler und Feld (Feld zeigt zugleich den Wert)
    F.qtyLabel = Label(L.FOCUS_R_QTY, F.QTY_Y)
    F.qtySlider = UI.Slider(left, F.QTY_SLIDER_W, 0, 1, 1, 1, function(v) F.OnQtySlider(v) end)
    F.qtySlider:SetPoint("LEFT", F.qtyLabel, "RIGHT", 6, 0)
    -- ab 0.167: im Einkaufen je nach Kaufart (Max. Menge, Menge, Einzelstueck)
    local function QtyTip()
        local Q = ns.Quick
        if not (Q and Q.On() and F.key ~= nil) then return { L.FOCUS_R_QTY, L.FOCUS_QTY_TIP } end
        if not ns.Data.IsCommodity(F.key) then return { L.FOCUS_R_QTY, L.QUICK_QTY_TIP_ITEM } end
        if Q.BuyKind(F.key) ~= "normal" then return { L.QUICK_QTY_MAX, L.QUICK_QTY_TIP_MAX } end
        return { L.FOCUS_R_QTY, L.QUICK_QTY_TIP_NORMAL }
    end
    UI.SetTooltip(F.qtySlider, QtyTip)
    -- ab 0.167 (Board KarloDerBaer): Tooltip auch ueber der Beschriftung vorn
    F.qtyHover = CreateFrame("Frame", nil, left)
    F.qtyHover:SetPoint("TOPLEFT", F.qtyLabel, "TOPLEFT", 0, 2)
    F.qtyHover:SetSize(F.QUICK_FIELD_X - 4, 18)
    UI.SetTooltip(F.qtyHover, QtyTip)
    F.qtyInput = UI.Input(left, 56, { numeric = true, maxLetters = 6 })
    if F.qtyInput.SetScale then F.qtyInput:SetScale(0.8) end
    if F.qtyInput.SetJustifyH then F.qtyInput:SetJustifyH("RIGHT") end
    if F.qtyInput.SetTextInsets then F.qtyInput:SetTextInsets(6, 8, 0, 0) end
    F.qtyInput:SetPoint("LEFT", F.qtySlider, "RIGHT", 6 / 0.8, 0)
    F.qtyInput:HookScript("OnTextChanged", function(self, user)
        if user then F.SetQtyTyped(tonumber(self:GetText() or "")) end
    end)
    F.qtyHint = UI.Text(left, "small", "")
    F.qtyHint:SetPoint("LEFT", F.qtyInput, "RIGHT", 4, 0)
    -- ab 0.106: grau "alle" im leeren Feld (Schnellkauf)
    -- ab 0.142 am Feld selbst (vorher am linken Bereich, das Feld lag darueber und verdeckte "Alle")
    F.qtyAll = UI.Text(F.qtyInput, "small", GREY .. L.FOCUS_QTY_ALL .. "|r")
    F.qtyAll:SetPoint("LEFT", F.qtyInput, "LEFT", 10, 0)
    F.qtyAll:Hide()
    -- ab 0.171 (KarloDerBaer 28.11.2026): Einzelware im Einkaufen ohne Regler und Feld, nur "1 Stueck"
    F.qtyOne = UI.Text(left, "text", "")
    F.qtyOne:SetPoint("LEFT", F.qtyLabel, "LEFT", F.QUICK_FIELD_X, 0)
    F.qtyOne:Hide()

    -- ab 0.112: Max. Gold im Schnellkauf (an der Stelle des Mengenfelds)
    F.goldInput = UI.MoneyInput(left, function(amount) F.SetGoldTyped(amount) end)
    if F.goldInput.SetScale then F.goldInput:SetScale(0.8) end
    F.goldInput:SetPoint("LEFT", F.qtyLabel, "RIGHT", 8 / 0.8, 0)
    UI.SetTooltip(F.goldInput, { L.QUICK_MAXGOLD, L.QUICK_MAXGOLD_TIP })
    F.goldInput:Hide()

    F.buyButton = UI.Button(left, L.BUY_BUY, UI.LEFT_W - 20, function() F.Buy() end, "gold")
    F.buyButton:SetPoint("BOTTOMLEFT", 10, 70)
    -- ab 0.77: Menge, Kosten, Gewinn mittig ueber dem Knopf
    F.buyInfo = UI.Text(left, "text", "", UI.LEFT_W - 20)
    F.buyInfo:SetJustifyH("CENTER")
    F.buyInfo:SetPoint("BOTTOM", F.buyButton, "TOP", 0, 6)
    -- ab 0.133 (U1, Konzept 4.5): die Knoepfe Im Markt zeigen, Gegenstand und Speichern entfallen (Menue auf dem
    -- Namen, Speichern von selbst). Zurueck und Einstellungen sind kleine Symbole in der Kopfzeile (unten).

    -- rechts: der Markt in diesem Moment. Oben die Preisstufen, darunter ab 0.66 (H2) Messung und Diagramm
    local right = UI.Panel(c, "list", true)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", UI.GAP, -30)
    right:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    right:SetHeight(F.TIER_H)
    F.stand = UI.Text(c, "text", "")
    F.stand:SetPoint("BOTTOMLEFT", right, "TOPLEFT", 8, 8)
    F.settingsButton = F.SmallIcon(c, F.ICON_SETTINGS, function()
        if ns.Settings then mod:Call("Einstellungen", ns.Settings.Toggle, "focus", c) end
    end, { L.SETTINGS_BUTTON })
    F.settingsButton:SetPoint("BOTTOMRIGHT", right, "TOPRIGHT", -4, 5)
    -- ab 0.133: Zurueck als Symbol links daneben (vorher Knopf unten links), ab 0.152 Knopf mit Text
    F.backButton = UI.Button(c, F.BackLabel(), F.BACK_W, function() mod:Call("Sprung", F.GoBack) end)
    F.backButton:SetPoint("RIGHT", F.settingsButton, "LEFT", -8, 0)
    -- ab 0.104: Umschalter Aufkauf / Schnellkauf, ab 0.133 nur mit dem Schalter focusBuyout (Aufkauf ruht)
    F.modeQuick = UI.Button(c, L.FOCUS_MODE_QUICK, 100, function() mod:Call("Schnellkauf", ns.Quick.SetMode, "quick") end)
    F.modeQuick:SetPoint("RIGHT", F.backButton, "LEFT", -12, 0)
    UI.SetTooltip(F.modeQuick, { L.FOCUS_MODE_QUICK, L.FOCUS_MODE_QUICK_TIP })
    F.modeBuyout = UI.Button(c, L.FOCUS_MODE_BUYOUT, 100, function() mod:Call("Schnellkauf", ns.Quick.SetMode, "buyout") end)
    F.modeBuyout:SetPoint("RIGHT", F.modeQuick, "LEFT", -4, 0)
    UI.SetTooltip(F.modeBuyout, { L.FOCUS_MODE_BUYOUT, L.FOCUS_MODE_BUYOUT_TIP })
    -- ab 0.74 ohne "Jetzt pruefen": der Fokus fragt ohnehin laufend ab (KarloDerBaer 12.11.2026)
    F.tiers = UI.Table(right, {
        columns = {
            { key = "price", title = L.ITEM_TIER_PRICE, align = "RIGHT", format = function(v) return Money(v) end },
            { key = "qty", title = L.ITEM_COL_QTY, width = 80, align = "RIGHT" },
            { key = "cum", title = L.ITEM_TIER_CUM, width = 80, align = "RIGHT" },
            { key = "cost", title = L.ITEM_TIER_COST, width = 110, align = "RIGHT", format = function(v) return Num(v) and Money(v) or "" end },
        },
        sortKey = "price", empty = L.FOCUS_TIER_WAIT,
        rowBg = function(r)   -- Kern API 19: Ziel gelb (ab 0.74), gekaufte Stufen blau (ab 0.77)
            if r and r.isOwn then return 0.7, 0.4, 1, 0.25 end   -- ab 0.104: eigenes Angebot lila, neue Stufe gruen
            if r and r.isNew then return 0.3, 0.9, 0.3, 0.28 end
            if r and r.isTarget then return 1, 0.82, 0, 0.22 end
            if r and r.inBuy then return 0.25, 0.55, 1, 0.22 end
        end,
        -- ab 0.70: Klick auf eine Preisstufe macht ihren Preis zum Ziel, ab 0.76 Rechtsklick zu "Kaufen bis".
        -- ab 0.83 getauscht (KarloDerBaer, 12.11.2026): Linksklick "Kaufen bis", Rechtsklick Zielpreis. Farben bleiben.
        onClick = function(item, button)
            if not (item and Num(item.price)) or item.isOwn then return end
            -- ab 0.116: im Schnellkauf aendert ein Klick nichts. Ab 0.143 im normalen Einkauf: Klick waehlt die Stufe, bis zu
            -- der gekauft wird (alle darunter kommen mit), noch ein Klick darauf oder Rechtsklick: wieder die guenstigste
            if ns.Quick and ns.Quick.On() then
                local Q = ns.Quick
                if Q.BuyKind(F.key) ~= "normal" then return end
                if button == "RightButton" or Q.pick[F.key] == item.price then Q.SetPick(nil) else Q.SetPick(item.price) end
                return
            end
            if button == "RightButton" then F.SetTarget(item.price) else F.SetLimit(item.price) end
        end,
    })
    F.BuildMeasure(c, right)
    F.BuildMarketRows(F.measurePanel)   -- ab 0.140
    F.BuildQuick(left, Label)

    if F.key == nil then F.key = mod.acc.focusKey end
    F.ApplyMode()
    F.Update()
end

-- ab 0.133: kleines Symbol als Knopf (Zurueck, Einstellungen in der Kopfzeile)
function F.SmallIcon(parent, tex, fn, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(20, 20)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    pcall(b.icon.SetTexture, b.icon, tex)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    if hl.SetColorTexture then hl:SetColorTexture(1, 1, 1, 0.2) end
    if fn then b:SetScript("OnClick", fn) end
    if tip then Peon.UI.SetTooltip(b, tip) end
    return b
end

F.TIER_H = 152     -- Hoehe der Preisstufen (Kopf und 6 Zeilen)
F.ICON_SETTINGS = "Interface\\Icons\\INV_Misc_Gear_01"             -- ab 0.133: Symbole in der Kopfzeile
F.ICON_BACK = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"
F.ICON_IN = "|TInterface\\Buttons\\Arrow-Down-Up:14:14:0:-3|t"     -- ab 0.133: Zufluss (rein)
F.ICON_OUT = "|TInterface\\Buttons\\Arrow-Up-Up:14:14:0:3|t"       -- Abfluss (raus)
F.CHART_H = 130    -- ab 0.133 hoeher, ab 0.140 etwas flacher (drei Zeilen darueber), vorher 104
F.MEASURE_ROWS = { "MEASURE_OUT", "MEASURE_IN", "MEASURE_UNDER", "MEASURE_MIN" }
F.QUICK_ROWS = { "QUICK_MV_IN", "QUICK_MV_OUT", "QUICK_MV_MOVE", "QUICK_MV_BAITS_L", "QUICK_DIP_L", "QUICK_MV_BOUGHT_L", "QS_LABEL" }   -- ab 0.108: Marktbewegung, ab 0.109 fuenf Zeilen, ab 0.122 Langfristig, ab 0.125 Einbruch statt Letztes
F.ROW_H = 15       -- ab 0.122: sieben Zeilen (vorher 17)

-- ab 0.167 (Board KarloDerBaer 27.11.2026): genau statt gerundet. Bisher stand bei einer engen Achse dreimal "6s".
-- Gold und Silber mit Abstand, mit Kupfer als dritter Stelle ohne Abstand (schmaler Rand links).
local function AxisMoney(v)
    if not Num(v) then return "" end
    v = math.floor(v + 0.5)
    local g, si, c = math.floor(v / 10000), math.floor(v % 10000 / 100), v % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if si > 0 then parts[#parts + 1] = si .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, #parts >= 3 and "" or " ")
end
F.AxisMoney = AxisMoney

-- ab 0.167: Bereich der Preisachse im Einkaufen. Alle Werte (Preislinie, Limit, Gleitend) liegen darin, dazu
-- quickChartPad Prozent ihrer Spanne Luft oben und unten. Eine flache Linie bekommt mindestens 2 % des Preises als
-- Spanne. Die Grenzen und die Mitte liegen auf einer runden Geldstufe (1, 2 oder 5 mal 10^k Kupfer, etwa ein
-- Sechzehntel der Spanne), so sind die drei Beschriftungen genau und verschieden. Rueckgabe lo, hi oder nil.
function F.AxisRange(lo, hi, padPct)
    if not Num(lo) or not Num(hi) then return nil end
    if hi < lo then lo, hi = hi, lo end
    local minSpan = math.max(4, hi * 0.02)
    if hi - lo < minSpan then
        local mid = (lo + hi) / 2
        lo, hi = mid - minSpan / 2, mid + minSpan / 2
    end
    local pad = (hi - lo) * math.max(0, tonumber(padPct) or 0) / 100
    lo, hi = math.max(0, lo - pad), hi + pad
    local want = (hi - lo) / 16
    local u = 1
    while u < want do
        if u * 2 >= want then u = u * 2
        elseif u * 5 >= want then u = u * 5
        else u = u * 10 end
    end
    local a = math.floor(lo / u) * u
    local b = math.ceil(hi / u) * u
    if b <= a then b = a + 2 * u end
    if ((b - a) / u) % 2 == 1 then
        -- Mitte auf eine Stufe: auf der Seite erweitern, die naeher an ihrer Grenze liegt
        if lo - a < b - hi and a >= u then a = a - u else b = b + u end
    end
    return a, b
end

-- Messung und Diagramm unter den Preisstufen (ab 0.66)
function F.BuildMeasure(c, above)
    local UI = Peon.UI
    local mp = UI.Panel(c, "right")
    mp:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -2)
    mp:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
    F.measurePanel = mp
    F.mHead = UI.Text(mp, "label", "")
    F.mHead:SetPoint("TOPLEFT", 12, -8)
    F.mRows = {}
    for i = 1, math.max(#F.MEASURE_ROWS, #F.QUICK_ROWS) do
        local label = UI.Text(mp, "label", L[F.MEASURE_ROWS[i]] or "")
        label:SetWidth(130)
        label:SetJustifyH("RIGHT")
        label:SetPoint("TOPLEFT", 4, -26 - (i - 1) * F.ROW_H)
        local value = UI.Text(mp, "text", "")
        value:SetPoint("TOPLEFT", label, "TOPRIGHT", 10, 0)
        local r = { label = label, value = value }
        -- ab 0.110: Tooltip je Zeile (Einzelheiten, damit die Zeile kurz bleibt)
        r.hover = CreateFrame("Frame", nil, mp)
        r.hover:SetPoint("TOPLEFT", label, "TOPLEFT", 0, 2)
        r.hover:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 260, -2)
        r.hover:SetScript("OnEnter", function(self)
            if not (r.tip and #r.tip > 0 and GameTooltip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label:GetText() or "", 1, 0.82, 0)
            for _, line in ipairs(r.tip) do GameTooltip:AddLine(line, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        r.hover:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        F.mRows[i] = r
    end
    local cw = W.WIDTH - 2 * W.SIDE - UI.LEFT_W - UI.GAP
    if Peon.NewChart then
        -- ab 0.131 (Wunsch KarloDerBaer 24.11.2026): die Menge richtet ihre Achse nach 90 % der Werte (Kern API 28,
        -- trim). Kurze Angebote mit grossen Mengen stauchten sonst alle anderen Balken.
        F.chart = Peon.NewChart(mp, { width = cw - 12, height = F.CHART_H, left = 46, right = 40, top = 6, bottom = 6, grid = 2, trim = { right = 0.9 },
            leftFormat = AxisMoney, rightFormat = function(v) return Num(v) and Peon.ShortNumber and Peon.ShortNumber(v) or "" end })
        -- ab 0.134: Platz fuer die Knoepfe der Linien darunter (vorher 6)
        if F.chart and F.chart.frame then F.chart.frame:SetPoint("BOTTOMLEFT", mp, "BOTTOMLEFT", 6, F.CHART_Y) end
        -- ab 0.75: nichts zeichnet ueber den Rand des Diagramms hinaus
        if F.chart and F.chart.plot and F.chart.plot.SetClipsChildren then F.chart.plot:SetClipsChildren(true) end
    end
    -- ab 0.91: Menge grau, Kaufen bis blau (Wunsch KarloDerBaer, 13.11.2026). Ab 0.134 nur noch im ruhenden Aufkauf.
    F.chartLegend = UI.Text(mp, "small", ("|cff999999%s|r  |cffffd133%s|r  |cff4d8cff%s|r  |cff60e060%s|r"):format(L.MEASURE_UNDER, L.MEASURE_MIN, L.FOCUS_R_LIMIT, L.FOCUS_R_TARGET))
    F.chartLegend:SetPoint("BOTTOMRIGHT", mp, "BOTTOMRIGHT", -10, F.CHART_H + F.CHART_Y + 4)
    F.BuildChartControls(mp)
end

---------------------------------------------------------------------------
-- Linien und Zeitraum des Diagramms (ab 0.134, Schritt U2, Konzept Peon_Broker_Schlank.md 4.4). Kleine Knoepfe unter
-- dem Diagramm schalten die Linien, oben rechts steht der Zeitraum. Die Wahl gilt fuer alle Gegenstaende und bleibt
-- gespeichert (chartMin ... chartBaits, chartRange). Der Preis bestimmt weiter die Aufloesung (0.131): Kaufen bis
-- passt die Achse nicht an, die Menge hat ihre eigene Achse rechts und richtet sich nach 90 % der Werte.
---------------------------------------------------------------------------
F.CHART_Y = 22     -- ab 0.134: Abstand des Diagramms vom unteren Rand (darunter die Knoepfe der Linien)
F.CHART_RANGES = { 5, 15, 60 }
F.CHART_COLORS = {
    min = { 1, 0.82, 0.2, 1 }, limit = { 0.3, 0.55, 1, 0.95 }, under = { 0.6, 0.6, 0.6, 0.4 },
    dips = { 1, 0.35, 0.25, 0.8 }, baits = { 0.7, 0.4, 1, 0.8 }, baitsOther = { 0.7, 0.4, 1, 0.35 },
    suggest = { 0.75, 0.75, 0.75, 0.8 },   -- ab 0.140: Vorschlag grau gestrichelt
}
-- Schluessel im Diagramm, gespeicherter Wert und Beschriftung, in der Reihenfolge der Knoepfe
F.CHART_LINES = {
    { key = "min", db = "chartMin", label = "CHART_L_MIN", kind = "line" },
    { key = "limit", db = "chartLimit", label = "CHART_L_LIMIT", kind = "hline" },
    { key = "under", db = "chartUnder", label = "CHART_L_UNDER", kind = "bar" },
    -- ab 0.140 (Board KarloDerBaer 26.11.2026): ohne Einbrueche, dafuer der Vorschlag (chartDips bleibt gespeichert)
    { key = "baits", db = "chartBaits", label = "CHART_L_BAITS", kind = "marks" },
    { key = "suggest", db = "chartSuggest", label = "CHART_L_SUGGEST", kind = "hline" },
}

function F.ChartRange()
    local m = tonumber(mod.db.chartRange)
    for _, r in ipairs(F.CHART_RANGES) do if r == m then return r end end
    return F.CHART_RANGES[1]
end

function F.SetChartRange(m)
    mod.db.chartRange = m
    F.chartN = nil
    F.UpdateRangeButtons()
    F.RefreshChart()
end

function F.UpdateRangeButtons()
    local cur = F.ChartRange()
    for _, b in ipairs(F.rangeButtons or {}) do
        local on = b.minutes == cur
        if b.fs then b.fs:SetTextColor(on and 1 or 0.6, on and 0.82 or 0.6, on and 0 or 0.6) end
    end
end

-- gespeicherte Wahl ins Diagramm (quick = Schnellkauf). Im ruhenden Aufkauf zeigt es alles wie bisher.
function F.ApplyChartLines(quick)
    local ch = F.chart
    if not ch then return end
    for _, l in ipairs(F.CHART_LINES) do ch.shown[l.key] = (not quick) or mod.db[l.db] ~= false end
    if ch.legend then ch.legend:Update() end
    F.chartN = nil
end

function F.RefreshChart()
    if F.tiers and F.Update then F.Update() end
end

function F.BuildChartControls(mp)
    local ch = F.chart
    if not ch then return end
    local C = F.CHART_COLORS
    ch.legendInfo = {}
    local keys = {}
    for _, l in ipairs(F.CHART_LINES) do
        ch.legendInfo[l.key] = { key = l.key, kind = l.kind, color = C[l.key], label = L[l.label] }
        keys[#keys + 1] = l.key
    end
    F.chartLines = ch:CreateLegend(mp, keys, function(key, on)
        for _, l in ipairs(F.CHART_LINES) do if l.key == key then mod.db[l.db] = on and true or false end end
    end)
    F.chartLines.frame:SetPoint("BOTTOMLEFT", mp, "BOTTOMLEFT", 8, 5)
    -- Zeitraum oben rechts, in der Zeile der Ueberschrift
    F.rangeButtons = {}
    local x = -10
    for i = #F.CHART_RANGES, 1, -1 do
        local m = F.CHART_RANGES[i]
        local b = CreateFrame("Button", nil, mp)
        local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fs:SetPoint("CENTER", 0, 0)
        fs:SetText(i == #F.CHART_RANGES and L.CHART_RANGE_LAST:format(m) or tostring(m))
        local w = ((fs.GetStringWidth and fs:GetStringWidth()) or 20) + 8
        if not Num(w) or w < 14 then w = 20 end
        b:SetSize(w, 16)
        b:SetPoint("TOPRIGHT", mp, "TOPRIGHT", x, -6)
        x = x - w - 2
        b.minutes, b.fs = m, fs
        b:SetScript("OnClick", function() mod:Call("Diagramm", F.SetChartRange, m) end)
        Peon.UI.SetTooltip(b, { L.CHART_RANGE_TIP, L.CHART_RANGE_TIP2:format(m) })
        F.rangeButtons[i] = b
    end
    F.UpdateRangeButtons()
    F.ApplyChartLines(ns.Quick and ns.Quick.On())
end

local function Dec(x)
    local t = ("%.1f"):format(x or 0):gsub("%.0$", "")
    return (t:gsub("%.", L.DEC_SEP or "."))
end
F.Dec = Dec

-- ab 0.70: Diagramm nur neu zeichnen, wenn eine neue Abfrage dazukam (vorher bei jedem Neuzeichnen der Seite)
F.chartN = nil
F.CHART_SLOTS = 60   -- ab 0.75: so viele Plaetze hat das Diagramm mindestens (von links gefuellt)

-- Messwerte in die Zeilen; v = laufende Messung, limit = geltendes "Kaufen bis" (ab 0.91 als blaue Linie)
function F.UpdateMeasure(v, limit)
    if not F.mRows then return end
    if ns.Quick and ns.Quick.On() then F.UpdateQuickMove(v); return F.UpdateQuickChart(limit) end   -- ab 0.104
    local every = ns.Radar.FocusEvery()
    if v then
        local head = L.MEASURE_HEAD:format(Dec(every))
        if v.every then head = head .. "  " .. GREY .. L.MEASURE_REAL:format(Dec(v.every)) .. "|r" end
        F.mHead:SetText(head)
    elseif AHOpen() and F.key ~= nil then
        F.mHead:SetText(L.MEASURE_HEAD:format(Dec(every)) .. "  " .. GREY .. L.MEASURE_STARTING .. "|r")
    else
        F.mHead:SetText(GREY .. L.MEASURE_NONE .. "|r")
    end
    local vals = { "", "", "", "", "", "" }
    if v then
        local trendU = L["MEASURE_T_" .. tostring(v.underTrend):upper()] or ""
        local trendM = L["MEASURE_T_" .. tostring(v.minTrend):upper()] or ""
        vals[1] = L.MEASURE_RATE:format(Dec(v.out))
        vals[2] = L.MEASURE_RATE:format(Dec(v.inUnder)) .. (Num(v.target) and ("  " .. GREY .. L.MEASURE_TARGET:format(Money(v.target)) .. "|r") or "")
        vals[3] = tostring(v.under or 0) .. ", " .. trendU
        vals[4] = (Num(v.min) and Money(v.min) or "-") .. ", " .. trendM
    end
    for i, r in ipairs(F.mRows) do r.value:SetText(vals[i]) end
    -- Diagramm: Menge unter Ziel (rechts), guenstigster Preis und Ziel (links)
    local n, under, mins = nil, nil, nil
    if v then n, under, mins = ns.Measure.Series() end
    local show = F.chart ~= nil and n ~= nil
    if F.chart and F.chart.frame then F.chart.frame:SetShown(show) end
    F.chartLegend:SetShown(show)
    if F.chartLines then F.chartLines.frame:SetShown(false) end   -- ab 0.134: Linien waehlen nur im Schnellkauf
    if not show then F.chartN = nil; return end
    local cur = ns.Measure.cur
    local stamp = tostring(n) .. ":" .. tostring(v.target) .. ":" .. tostring(limit) .. ":" .. tostring(cur and cur.samples[n] and cur.samples[n].t)
    if F.chartN == stamp then return end
    local series = {
        { key = "under", kind = "bar", axis = "right", values = under, color = { 0.6, 0.6, 0.6, 0.4 } },
        { key = "min", kind = "line", values = mins, color = { 1, 0.82, 0.2, 1 }, width = 2, connect = true },
    }
    if Num(v.target) then series[#series + 1] = { key = "target", kind = "hline", value = v.target, color = { 0.38, 0.88, 0.38, 0.9 } } end
    if Num(limit) and limit > 0 then series[#series + 1] = { key = "limit", kind = "hline", value = limit, color = { 0.3, 0.55, 1, 0.95 } } end
    -- ab 0.75: mindestens F.CHART_SLOTS Plaetze, von links gefuellt. Mit nur zwei Abfragen war jeder Balken so breit
    -- wie das halbe Diagramm und ragte ueber den Rand.
    if F.chart.SetRange then F.chart:SetRange("left", nil) end   -- ab 0.167: Bereich wie bisher von selbst
    ns.Radar.Perf("diagramm", function() F.chart:SetData(math.max(n, F.CHART_SLOTS or 60), series); F.chart:Draw() end)
    F.chartN = stamp   -- erst nach dem Zeichnen: bricht es ab, versucht es die naechste Antwort neu
end

-- Kaufknopf und Taste "Kaufen" (ab 0.104 beide hier): kauft, was der Knopf zeigt
-- ab 0.167 (KarloDerBaer 27.11.2026) ohne Sperre nach der Pause der Abfragen (Quick.Locked): Der Knopf blinkte bei
-- Einzelstuecken zwischen rot und grau. Ein Klick kauft mit dem letzten Stand, das Spiel prueft den Preis selbst, ein
-- Fehlschlag steht kurz auf dem Knopf (Radar.FailText).
function F.Buy()
    local d = F.Plan()
    if d then mod:Call("Radar", ns.Radar.BuyStep, d, "best") end
end

---------------------------------------------------------------------------
-- Modus Schnellkauf (ab 0.104, Quick.lua): Block Lockangebot unter Kaufen bis und Menge, eigenes Diagramm
---------------------------------------------------------------------------
-- ab 0.106 ohne Urteil und Satz darunter, alles rueckt nach oben
-- ab 0.133 (U1, Konzept Peon_Broker_Schlank.md 4.1 und 4.3): links untereinander Kaufen bis (mit Auto), Menge,
-- Goldreserve, Markt, Einbruch, Gekauft heute, der Kaufknopf und darunter aufklappbar Lockangebot und Mehr Einstellungen
-- (Haken Lockangebot ignorieren und Durchschnitt zaehlt). Die Bereiche merken sich ihren Zustand (foldBait, foldMore).
-- ab 0.140 (Board KarloDerBaer 26.11.2026): links nur Eingaben und Kaeufe, rechts der Markt.
--   links   Kaufen bis mit Vorschlag, Menge (Regler), Max. Preis, Kaufknopf, Statistik (aufklappbar, Vorgabe offen),
--           Lockangebot und Mehr Einstellungen (mit Goldreserve) aufklappbar
--   rechts  Angebote, darunter drei einstellbare Zeilen (Rechtsklick), darunter das Diagramm
-- ab 0.143: Zeile Gleitend unter Limit, alles darunter 26 tiefer
-- ab 0.144 (Board KarloDerBaer): Zeile Stueckpreis zwischen Menge und Gesamtpreis (vorher Max. Preis), Gesamtpreis mit
-- zweiter Zeile fuer die Goldreserve, der Kaufknopf darunter. Der letzte Kauf steht in der Statistik (Zuletzt).
-- ab 0.165.1 (KarloDerBaer 26.11.2026): Menge und alles darunter 4 tiefer, die breitere Auswahlliste Gleitend ragte
-- sonst in die Zeile Menge
-- ab 0.167 (Board KarloDerBaer 27.11.2026): Zeile Min. Menge unter der Menge, alles darunter 26 tiefer. Der Platz
-- bleibt auch frei, wenn die Zeile nicht zu sehen ist.
F.QUICK_LIMIT_Y, F.QUICK_GLIDE_Y, F.QUICK_QTY_Y, F.QUICK_MIN_Y, F.QUICK_UNIT_Y, F.QUICK_MAX_Y = -100, -126, -158, -184, -210, -250
F.QUICK_TRIG_Y = F.QUICK_GLIDE_Y   -- ab 0.168: Zeile Ausloeser an der Stelle von Gleitend
F.QUICK_BAND_Y = -230               -- ab 0.168: Band unter dem Stueckpreis
F.QUICK_LIMIT_DY = -6   -- Feld des Standards auf Hoehe des Hakens Limit
F.QUICK_BUY_TOP = -290  -- Oberkante des Kaufknopfs
F.QUICK_FOLD_Y = -338   -- erster aufklappbarer Bereich (Statistik)
-- ab 0.168 (KarloDerBaer 28.11.2026): Zeilen je Tab. Limitkauf wie oben, Direktkauf ohne Limit, Ausloeser, Min. Menge
-- und Band, alles rueckt nach oben.
F.QUICK_TAB_ROWS = {
    limit  = { qty = F.QUICK_QTY_Y, unit = F.QUICK_UNIT_Y, band = F.QUICK_BAND_Y, max = F.QUICK_MAX_Y, buy = F.QUICK_BUY_TOP, fold = F.QUICK_FOLD_Y },
    direct = { qty = -100, unit = -132, max = -152, buy = -192, fold = -240 },
}
F.QUICK_SRC_W = 62      -- ab 0.168: Auswahllisten Limit und Ausloeser (zugeklappt Kurzform)
-- ab 0.165 (KarloDerBaer 26.11.2026): Auswahlliste Gleitend buendig mit dem Mengenfeld darunter. Sie beginnt 2 links
-- vom Regler, rechts endet das Feld (Breite 56 bei Massstab 0.8) 6 hinter dem Regler.
F.QUICK_METHOD_W = math.floor(2 + F.QTY_SLIDER_W + 6 + 56 * 0.8 + 0.5)
F.QUICK_MARGIN_W = 66   -- ab 0.167: Gewinnspanne rechts neben dem Richtpreis
F.QUICK_REF_W = F.QUICK_METHOD_W - F.QUICK_MARGIN_W - 4
F.QUICK_X = 16
F.QUICK_FIELD_X = 93   -- ab 0.112.1: Felder im Schnellkauf so weit rechts von der Beschriftung
F.QUICK_AVG_X = 186    -- ab 0.112: Haken "Durchschnitt zaehlt"
F.QUICK_POST_W = 110
F.QUICK_STAT_STEP = 16
F.QUICK_STATS = { { "QUICK_STAT_LAST", "last" }, { "QUICK_STAT_SESSION", "session" }, { "QUICK_STAT_TODAY", 1 }, { "QUICK_STAT_WEEK", 7 } }

-- Goldreserve: gilt fuer alle Gegenstaende (radarReserve in Gold, wie im Fenster Einstellungen)
function F.SetReserve(amount)
    local v = (Num(amount) and amount > 0) and math.floor(amount / 10000) or 0
    mod.db.radarReserve = v
    F.Update()
end

-- ab 0.140: Haken vor der Goldreserve (radarReserveOn, Vorgabe an). Aus: keine Reserve, das Feld ist grau.
function F.SetReserveOn(on)
    mod.db.radarReserveOn = on and true or false
    F.Update()
end

function F.ReserveOn() return mod.db.radarReserveOn ~= false end

-- Geldfeld grau und gesperrt (oder wieder frei)
local function MoneyEnabled(m, on)
    if not m then return end
    if m.SetAlpha then m:SetAlpha(on and 1 or 0.45) end
    for _, k in ipairs({ "gold", "silver", "copper" }) do
        local e = m[k]
        if e and e.SetEnabled then e:SetEnabled(on) end
        if not on and e and e.ClearFocus then e:ClearFocus() end
    end
end
F.MoneyEnabled = MoneyEnabled

---------------------------------------------------------------------------
-- ab 0.142 (Board KarloDerBaer 26.11.2026): Bildlauf fuer den unteren linken Bereich. Sind alle Bereiche
-- aufgeklappt, ragte der Inhalt unten aus dem Fenster. Auch fuer Verkaufen (SellPage.lua).
---------------------------------------------------------------------------
function F.MakeScroll(parent, top)
    local ok, sc = pcall(CreateFrame, "ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    if not ok or not sc then sc = CreateFrame("ScrollFrame", nil, parent) end
    sc:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, top)
    sc:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -24, 6)
    local child = CreateFrame("Frame", nil, sc)
    child:SetSize(Peon.UI.LEFT_W - 28, 10)
    if sc.SetScrollChild then sc:SetScrollChild(child) end
    sc.child = child
    return sc, child
end

-- Hoehe des Inhalts setzen, die Leiste nur zeigen, wenn er nicht ganz hineinpasst
function F.FitScroll(sc, h)
    if not sc then return end
    h = math.max(1, math.floor(h + 0.5))
    sc.child:SetHeight(h)
    sc.contentH = h
    local fh = sc.GetHeight and sc:GetHeight() or nil
    local need = Num(fh) and fh > 0 and h > fh + 1 or false
    local bar = rawget(sc, "ScrollBar")
    if type(bar) == "table" and bar.SetShown then bar:SetShown(need) end
    if not need and sc.SetVerticalScroll then pcall(sc.SetVerticalScroll, sc, 0) end
end

function F.BuildQuick(left, Label)
    local UI = Peon.UI
    local Q = ns.Quick
    local q = {}
    F.quick = q
    local function LeftLabel(text, y)
        local t = Label(text, y)
        t:SetJustifyH("LEFT")
        t:SetWidth(0)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", F.QUICK_X, y)
        return t
    end
    -- ab 0.168 (KarloDerBaer 28.11.2026): statt der Haken Limit und Gleitend zwei Zeilen mit Auswahlliste.
    --   Limit     Fest (Standard im Feld) oder ein Richtpreis (gleitend, dahinter die Gewinnspanne). Kein Aus.
    --   Ausloeser Aus, Fest (eigenes Feld), Limit (dahinter der Abstand) oder Letzter Tiefstpreis
    -- Zugeklappt zeigen die Listen eine Kurzform (Fix, Ruh, Tag ...), aufgeklappt den ganzen Namen.
    local Q2 = Q
    q.limLabel = LeftLabel(L.QUICK_LIMIT, F.QUICK_LIMIT_Y)
    q.limSrc = F.ShortDropdown(left, F.QUICK_SRC_W, function()
        local out = {}
        for _, r in ipairs(F.LimSrcList()) do out[#out + 1] = { r, F.SrcName(r) } end
        return out
    end, function() return Q2.LimSrc(F.key) end, function(r) mod:Call("Schnellkauf", Q2.SetLimSrc, r) end)
    if q.limSrc.fallback then
        q.limSrc:SetScript("OnClick", function(self) mod:Call("Schnellkauf", F.LimSrcMenu, self) end)
    end
    q.limSrc:SetPoint("TOPLEFT", F.QUICK_X + F.QUICK_FIELD_X - 2, F.QUICK_LIMIT_Y + 4)
    UI.SetTooltip(q.limSrc, function() return F.RefTip() end)
    q.limitStd = UI.Text(left, "small", "")
    q.limitStd:SetPoint("LEFT", F.limitInput, "RIGHT", 4, 0)
    q.margin = UI.Dropdown(left, F.QUICK_MARGIN_W, function()
        local out = {}
        for _, m in ipairs(Q2.MARGINS) do out[#out + 1] = { m, L.QUICK_MARGIN_FMT:format(m) } end
        return out
    end, function() return Q2.Margin(F.key) end, function(m) mod:Call("Schnellkauf", Q2.SetMargin, m) end)
    if q.margin.fallback then
        q.margin:SetScript("OnClick", function(self) mod:Call("Schnellkauf", F.MarginMenu, self) end)
    end
    q.margin:SetPoint("LEFT", q.limSrc, "RIGHT", 4, 0)
    UI.SetTooltip(q.margin, function() return F.MarginTip() end)
    q.glideValue = UI.Text(left, "small", "")
    q.glideValue:SetPoint("LEFT", q.margin, "RIGHT", 6, 0)
    -- Ausloeser
    q.trigLabel = LeftLabel(L.QUICK_TRIG_L, F.QUICK_TRIG_Y)
    q.trigHover = CreateFrame("Frame", nil, left)
    q.trigHover:SetPoint("TOPLEFT", q.trigLabel, "TOPLEFT", 0, 2)
    q.trigHover:SetSize(F.QUICK_FIELD_X - 4, 18)
    UI.SetTooltip(q.trigHover, function() return F.TrigTip() end)
    q.trigSrc = F.ShortDropdown(left, F.QUICK_SRC_W, function()
        local out = {}
        for _, t in ipairs(Q2.TRIGS) do out[#out + 1] = { t, F.TrigName(t) } end
        return out
    end, function() return Q2.Trig(F.key) end, function(t) mod:Call("Schnellkauf", Q2.SetTrig, t) end)
    if q.trigSrc.fallback then
        q.trigSrc:SetScript("OnClick", function(self) mod:Call("Schnellkauf", F.TrigMenu, self) end)
    end
    q.trigSrc:SetPoint("TOPLEFT", F.QUICK_X + F.QUICK_FIELD_X - 2, F.QUICK_TRIG_Y + 4)
    UI.SetTooltip(q.trigSrc, function() return F.TrigTip() end)
    q.trigInput = UI.MoneyInput(left, function(amount) mod:Call("Schnellkauf", Q2.SetTrigFix, amount) end)
    if q.trigInput.SetScale then q.trigInput:SetScale(0.8) end
    q.trigInput:SetPoint("LEFT", q.trigSrc, "RIGHT", 4 / 0.8, 0)
    UI.SetTooltip(q.trigInput, function() return F.TrigTip() end)
    q.trigPct = UI.Dropdown(left, F.QUICK_MARGIN_W, function()
        local out = {}
        for _, m in ipairs(Q2.TRIG_PCTS) do out[#out + 1] = { m, L.QUICK_MARGIN_FMT:format(m) } end
        return out
    end, function() return Q2.TrigPct(F.key) end, function(m) mod:Call("Schnellkauf", Q2.SetTrigPct, m) end)
    if q.trigPct.fallback then
        q.trigPct:SetScript("OnClick", function(self) mod:Call("Schnellkauf", F.TrigPctMenu, self) end)
    end
    q.trigPct:SetPoint("LEFT", q.trigSrc, "RIGHT", 4, 0)
    UI.SetTooltip(q.trigPct, function() return F.TrigTip() end)
    q.trigValue = UI.Text(left, "small", "")
    q.trigValue:SetPoint("LEFT", q.trigSrc, "RIGHT", 8, 0)
    q.limitParts = { q.limLabel, q.limSrc, q.trigLabel, q.trigHover, q.trigSrc }
    -- ab 0.167: Min. Menge unter der Menge (Regler ganz links aus, Feld mit der Zahl)
    q.minLabel = LeftLabel(L.QUICK_MIN_L, F.QUICK_MIN_Y)
    q.minSlider = UI.Slider(left, F.QTY_SLIDER_W, 0, 1, 1, 0, function(v) F.OnMinSlider(v) end)
    q.minSlider:SetPoint("LEFT", q.minLabel, "LEFT", F.QUICK_FIELD_X, 0)
    UI.SetTooltip(q.minSlider, function() return { L.QUICK_MIN_L, L.QUICK_MIN_TIP:format(Q2.MinMax()) } end)
    q.minInput = UI.Input(left, 56, { numeric = true, maxLetters = 6 })
    if q.minInput.SetScale then q.minInput:SetScale(0.8) end
    if q.minInput.SetJustifyH then q.minInput:SetJustifyH("RIGHT") end
    if q.minInput.SetTextInsets then q.minInput:SetTextInsets(6, 8, 0, 0) end
    q.minInput:SetPoint("LEFT", q.minSlider, "RIGHT", 6 / 0.8, 0)
    q.minInput:HookScript("OnTextChanged", function(self, user)
        if user then mod:Call("Schnellkauf", Q2.SetMinQty, tonumber(self:GetText() or "")) end
    end)
    UI.SetTooltip(q.minInput, function() return { L.QUICK_MIN_L, L.QUICK_MIN_TIP:format(Q2.MinMax()) } end)
    q.minOff = UI.Text(q.minInput, "small", GREY .. L.QUICK_MIN_OFF .. "|r")
    q.minOff:SetPoint("LEFT", q.minInput, "LEFT", 10, 0)
    q.minHover = CreateFrame("Frame", nil, left)
    q.minHover:SetPoint("TOPLEFT", q.minLabel, "TOPLEFT", 0, 2)
    q.minHover:SetSize(F.QUICK_FIELD_X - 4, 18)
    UI.SetTooltip(q.minHover, function() return { L.QUICK_MIN_L, L.QUICK_MIN_TIP:format(Q2.MinMax()) } end)
    q.minParts = { q.minLabel, q.minSlider, q.minInput, q.minHover }
    -- ab 0.144: Stueckpreis, der ermittelte Zielpreis je Stueck mit dem Hebel dahinter
    q.unitLabel = LeftLabel(L.QUICK_UNIT_L, F.QUICK_UNIT_Y)
    q.unitValue = UI.Text(left, "text", "", UI.LEFT_W - F.QUICK_FIELD_X - 20)
    q.unitValue:SetPoint("TOPLEFT", q.unitLabel, "TOPLEFT", F.QUICK_FIELD_X, 0)
    q.unitHover = CreateFrame("Frame", nil, left)
    q.unitHover:SetPoint("TOPLEFT", q.unitLabel, "TOPLEFT", 0, 2)
    q.unitHover:SetSize(UI.LEFT_W - 24, 16)
    UI.SetTooltip(q.unitHover, function() return { L.QUICK_UNIT_L, L.QUICK_UNIT_TIP } end)
    -- ab 0.168: Band (Ausloeser bis Limit) unter dem Stueckpreis, nur im Limitkauf
    q.bandLabel = LeftLabel(L.QUICK_BAND_L, F.QUICK_BAND_Y)
    q.bandValue = UI.Text(left, "text", "", UI.LEFT_W - F.QUICK_FIELD_X - 20)
    q.bandValue:SetPoint("TOPLEFT", q.bandLabel, "TOPLEFT", F.QUICK_FIELD_X, 0)
    q.bandHover = CreateFrame("Frame", nil, left)
    q.bandHover:SetPoint("TOPLEFT", q.bandLabel, "TOPLEFT", 0, 2)
    q.bandHover:SetSize(UI.LEFT_W - 24, 16)
    UI.SetTooltip(q.bandHover, function() return F.BandTip() end)
    q.limitParts[#q.limitParts + 1] = q.bandLabel
    q.limitParts[#q.limitParts + 1] = q.bandValue
    q.limitParts[#q.limitParts + 1] = q.bandHover
    -- ab 0.140: Max. Preis unter der Menge, ab 0.144 Gesamtpreis mit zweiter Zeile
    q.maxLabel = LeftLabel(L.QUICK_MAX_L, F.QUICK_MAX_Y)
    q.maxValue = UI.Text(left, "text", "", UI.LEFT_W - F.QUICK_FIELD_X - 20)
    q.maxValue:SetPoint("TOPLEFT", q.maxLabel, "TOPLEFT", F.QUICK_FIELD_X, 0)
    if q.maxValue.SetSpacing then q.maxValue:SetSpacing(3) end
    q.maxHover = CreateFrame("Frame", nil, left)
    q.maxHover:SetPoint("TOPLEFT", q.maxLabel, "TOPLEFT", 0, 2)
    q.maxHover:SetSize(UI.LEFT_W - 24, 34)
    UI.SetTooltip(q.maxHover, function()
        local lines = { L.QUICK_MAX_L, L.QUICK_MAX_TIP }
        -- ab 0.167: wie die Portion des Smart-Teilkaufs entstand
        local d = F.key ~= nil and ns.Quick.On() and F.Plan() or nil
        if d and d.portion then
            lines[#lines + 1] = L.QUICK_PORTION_LINE:format(d.portion, d.portionAll or 0)
            lines[#lines + 1] = L["QUICK_PORTION_WHY_" .. tostring(d.portionWhy):upper()] or ""
        end
        return lines
    end)
    -- unter dem Kaufknopf nur noch der Stand eines laufenden Kaufs (ab 0.144, der letzte Kauf steht in der Statistik)
    q.lastBuy = UI.Text(left, "small", "", UI.LEFT_W - 20)
    q.lastBuy:SetJustifyH("CENTER")
    q.lastBuy:SetPoint("TOP", F.buyButton, "BOTTOM", 0, -4)
    q.line1 = UI.Divider(left, UI.LEFT_W - 24)
    q.line1:SetPoint("TOPLEFT", 12, F.QUICK_FOLD_Y + 8)

    -- Statistik (aufklappbar, Vorgabe offen)
    q.foldStats = UI.Collapse(left, L.QUICK_STAT_HEAD, mod.db.foldStats ~= false, function(open)
        mod.db.foldStats = open and true or false
        F.LayoutQuick()
    end)
    q.stats = {}
    for i, def in ipairs(F.QUICK_STATS) do
        local r = {}
        r.label = LeftLabel(L[def[1]], F.QUICK_FOLD_Y)
        r.value = UI.Text(left, "text", "")
        r.value:SetPoint("TOPLEFT", r.label, "TOPLEFT", F.QUICK_FIELD_X, 0)
        r.src = def[2]
        q.stats[i] = r
    end

    -- Lockangebot (aufklappbar, Vorgabe zu)
    q.foldBait = UI.Collapse(left, L.QUICK_HEAD, mod.db.foldBait == true, function(open)
        mod.db.foldBait = open and true or false
        F.LayoutQuick()
    end)
    q.priceLabel = LeftLabel(L.QUICK_PRICE, F.QUICK_FOLD_Y)
    q.priceInput = UI.MoneyInput(left, function(amount) Q.SetPriceTyped(amount) end)
    if q.priceInput.SetScale then q.priceInput:SetScale(0.8) end
    q.priceInput:SetPoint("LEFT", q.priceLabel, "LEFT", F.QUICK_FIELD_X / 0.8, 0)
    q.priceHint = UI.Text(left, "small", "")
    q.priceHint:SetPoint("LEFT", q.priceInput, "RIGHT", 4, 0)
    -- ab 0.132 (U0, Konzept 4.2): unter dem Lockpreis die Menge, rechts davon der Knopf Einstellen
    q.qtyLabel = LeftLabel(L.QUICK_BAIT_QTY, F.QUICK_FOLD_Y)
    q.qtyInput = UI.Input(left, 48, { numeric = true, maxLetters = 4 })
    if q.qtyInput.SetScale then q.qtyInput:SetScale(0.8) end
    if q.qtyInput.SetJustifyH then q.qtyInput:SetJustifyH("RIGHT") end
    if q.qtyInput.SetTextInsets then q.qtyInput:SetTextInsets(6, 8, 0, 0) end
    q.qtyInput:SetPoint("LEFT", q.qtyLabel, "LEFT", F.QUICK_FIELD_X / 0.8, 0)
    q.qtyInput:HookScript("OnTextChanged", function(self, user)
        if user then mod:Call("Schnellkauf", Q.SetBaitQty, tonumber(self:GetText() or "")) end
    end)
    UI.SetTooltip(q.qtyInput, { L.QUICK_BAIT_QTY, L.QUICK_BAIT_QTY_TIP })
    q.qtyHint = UI.Text(left, "small", "")
    q.qtyHint:SetPoint("LEFT", q.qtyInput, "RIGHT", 4, 0)
    q.post = UI.Button(left, L.QUICK_POST, F.QUICK_POST_W, function() mod:Call("Schnellkauf", Q.Post) end)
    UI.SetTooltip(q.post, { L.QUICK_POST, L.QUICK_POST_TIP })
    q.state = UI.Text(left, "text", "", UI.LEFT_W - 32)
    q.balance = UI.Text(left, "small", "", UI.LEFT_W - 32)
    q.balance:Hide()   -- ab 0.114 nicht mehr gezeigt (die Bilanz steht in Gekauft)

    -- Mehr Einstellungen (aufklappbar, Vorgabe zu): Goldreserve (ab 0.140 hier, mit Haken) und die beiden Haken
    q.foldMore = UI.Collapse(left, L.FOCUS_FOLD_MORE, mod.db.foldMore == true, function(open)
        mod.db.foldMore = open and true or false
        F.LayoutQuick()
    end)
    q.resCheck = UI.Check(left, "", F.ReserveOn(), function(on) mod:Call("Schnellkauf", F.SetReserveOn, on) end,
        { L.QUICK_RESERVE, L.QUICK_RESERVE_ON_TIP })
    if q.resCheck.SetScale then q.resCheck:SetScale(0.85) end
    q.resLabel = LeftLabel(L.QUICK_RESERVE, F.QUICK_FOLD_Y)
    q.resInput = UI.MoneyInput(left, function(amount) F.SetReserve(amount) end)
    if q.resInput.SetScale then q.resInput:SetScale(0.8) end
    q.resInput:SetPoint("LEFT", q.resLabel, "LEFT", F.QUICK_FIELD_X / 0.8, 0)
    UI.SetTooltip(q.resInput, { L.QUICK_RESERVE, L.QUICK_RESERVE_TIP })
    -- ab 0.167: Teilkauf (Smart oder Aus) als Auswahlliste
    q.portionLabel = LeftLabel(L.QUICK_PORTION_L, F.QUICK_FOLD_Y)
    q.portionDrop = UI.Dropdown(left, 110, function()
        return { { "smart", L.QUICK_PORTION_SMART }, { "off", L.QUICK_PORTION_OFF } }
    end, function() return Q.PortionOn() and "smart" or "off" end, function(m) mod:Call("Schnellkauf", Q.SetPortionMode, m) end)
    if q.portionDrop.fallback then
        q.portionDrop:SetScript("OnClick", function() mod:Call("Schnellkauf", Q.SetPortionMode, Q.PortionOn() and "off" or "smart") end)
    end
    UI.SetTooltip(q.portionDrop, { L.QUICK_PORTION_L, L.QUICK_PORTION_TIP })
    q.portionHover = CreateFrame("Frame", nil, left)
    q.portionHover:SetPoint("TOPLEFT", q.portionLabel, "TOPLEFT", 0, 2)
    q.portionHover:SetSize(F.QUICK_FIELD_X - 4, 18)
    UI.SetTooltip(q.portionHover, { L.QUICK_PORTION_L, L.QUICK_PORTION_TIP })
    q.skip = UI.Check(left, L.QUICK_SKIP, false, function(on) mod:Call("Schnellkauf", Q.SetSkip, on) end, { L.QUICK_SKIP, L.QUICK_SKIP_TIP })
    if q.skip.SetScale then q.skip:SetScale(0.85) end
    q.avg = UI.Check(left, L.QUICK_AVG, false, function(on) mod:Call("Schnellkauf", Q.SetAvg, on) end, { L.QUICK_AVG, L.QUICK_AVG_TIP })
    if q.avg.SetScale then q.avg:SetScale(0.85) end

    q.statParts = {}
    for _, r in ipairs(q.stats) do q.statParts[#q.statParts + 1] = r.label; q.statParts[#q.statParts + 1] = r.value end
    -- ab 0.142: aufklappbare Bereiche in einem Bildlauf
    q.scroll, q.body = F.MakeScroll(left, F.QUICK_FOLD_Y + 4)
    q.scroll:SetScript("OnSizeChanged", function() if q.contentH then F.FitScroll(q.scroll, q.contentH) end end)
    q.baitParts = { q.priceLabel, q.priceInput, q.priceHint, q.qtyLabel, q.qtyInput, q.qtyHint, q.post, q.state }
    q.avg:Hide()   -- ab 0.143: Durchschnitt zaehlt gilt fuer alle (Einstellungen, Erweitert)
    q.moreParts = { q.resCheck, q.resLabel, q.resInput, q.portionLabel, q.portionDrop, q.portionHover, q.skip }
    for _, f in ipairs({ q.foldStats, q.foldBait, q.foldMore, q.priceLabel, q.priceInput, q.priceHint, q.qtyLabel, q.qtyInput,
                         q.qtyHint, q.post, q.state, q.balance, q.resCheck, q.resLabel, q.resInput, q.skip, q.avg,
                         q.portionLabel, q.portionDrop, q.portionHover }) do f:SetParent(q.body) end
    for _, f in ipairs(q.statParts) do f:SetParent(q.body) end
    -- ab 0.168: Teile nur im Limitkauf (q.limitParts) und solche, die je nach Wahl erscheinen, zeigt F.ApplyTab
    q.all = { q.unitLabel, q.unitValue, q.unitHover,
              q.maxLabel, q.maxValue, q.maxHover, q.lastBuy, q.line1,
              q.foldStats, q.foldBait, q.foldMore, q.scroll }
    q.choiceParts = { q.limitStd, q.margin, q.glideValue, q.trigInput, q.trigPct, q.trigValue }
    q.info = {}   -- bis 0.139 Markt, Einbruch, Gekauft heute links (ab 0.140 rechts, F.marketRows)
end

-- Aufklappbare Bereiche untereinander anordnen (ab 0.133, ab 0.140 mit Statistik, ab 0.142 im Bildlauf q.body:
-- Stellen relativ zum Inhalt, der 4 Punkte rechts vom linken Bereich beginnt)
function F.LayoutQuick()
    local q = F.quick
    if not q then return end
    local quick = ns.Quick.On()
    local X = F.QUICK_X - 4
    local bodyW = Peon.UI.LEFT_W - 28
    local y = -4
    q.foldStats:ClearAllPoints()
    q.foldStats:SetPoint("TOPLEFT", X - 4, y)
    local stats = quick and q.foldStats.open and true or false
    for _, f in ipairs(q.statParts) do f:SetShown(stats) end
    y = y - 24
    if stats then
        for i, r in ipairs(q.stats) do
            r.label:ClearAllPoints()
            r.label:SetPoint("TOPLEFT", X, y - (i - 1) * F.QUICK_STAT_STEP)
        end
        y = y - #q.stats * F.QUICK_STAT_STEP - 6
    end
    q.foldBait:ClearAllPoints()
    q.foldBait:SetPoint("TOPLEFT", X - 4, y)
    -- ab 0.168: Lockangebot nur im Limitkauf, der Direktkauf bleibt schlank
    local limTab = quick and not (F.key ~= nil and ns.Quick.Tab(F.key) == "direct")
    q.foldBait:SetShown(limTab)
    local bait = limTab and q.foldBait.open and true or false
    for _, f in ipairs(q.baitParts) do f:SetShown(bait) end
    if limTab then y = y - 24 end
    if bait then
        q.priceLabel:ClearAllPoints()
        q.priceLabel:SetPoint("TOPLEFT", X, y)
        q.post:ClearAllPoints()
        q.post:SetPoint("TOPLEFT", bodyW - 2 - F.QUICK_POST_W, y - 22)
        q.qtyLabel:ClearAllPoints()
        q.qtyLabel:SetPoint("TOPLEFT", X, y - 26)
        q.state:ClearAllPoints()
        q.state:SetPoint("TOPLEFT", X, y - 50)
        y = y - 72
    end
    q.foldMore:ClearAllPoints()
    q.foldMore:SetPoint("TOPLEFT", X - 4, y)
    local more = quick and q.foldMore.open and true or false
    for _, f in ipairs(q.moreParts) do f:SetShown(more) end
    y = y - 22
    if more then
        y = y - 4
        -- Goldreserve: Haken, Beschriftung, Feld
        q.resCheck:ClearAllPoints()
        q.resCheck:SetPoint("TOPLEFT", 4 / 0.85, (y + 8) / 0.85)
        q.resLabel:ClearAllPoints()
        q.resLabel:SetPoint("TOPLEFT", X + 22, y)
        q.resInput:ClearAllPoints()
        q.resInput:SetPoint("LEFT", q.resLabel, "LEFT", (F.QUICK_FIELD_X + 20) / 0.8, 0)
        y = y - 26
        -- ab 0.167: Teilkauf
        q.portionLabel:ClearAllPoints()
        q.portionLabel:SetPoint("TOPLEFT", X + 22, y)
        q.portionDrop:ClearAllPoints()
        q.portionDrop:SetPoint("LEFT", q.portionLabel, "LEFT", F.QUICK_FIELD_X + 18, 0)
        y = y - 26
        q.skip:ClearAllPoints()
        q.skip:SetPoint("TOPLEFT", 6 / 0.85, y / 0.85)
        y = y - 30
    end
    q.contentH = -y + 4
    F.FitScroll(q.scroll, q.contentH)
end

---------------------------------------------------------------------------
-- ab 0.140: drei einstellbare Zeilen rechts zwischen Angeboten und Diagramm. Rechtsklick auf eine Zeile waehlt,
-- was sie zeigt (gilt fuer alle Gegenstaende, gespeichert in focusRows). Vorgabe Bewegung, Stabilitaet, Einbruch.
-- ab 0.165 (KarloDerBaer 26.11.2026) fuenf Zeilen, neu Marktstabilitaet (market), Stabilitaet heisst
-- Preisstabilitaet. Vorgabe Bewegung, Preisstabilitaet, Marktstabilitaet, Einbruch, Lockangebote. Verkaufen zeigt
-- weiter die ersten drei.
---------------------------------------------------------------------------
-- ab 0.167 (Wunsch KarloDerBaer 27.11.2026): Zeile Menge (qty) mit Trendpfeil, in der Vorgabe statt Einbruch
F.MARKET_ROWS = { "move", "stab", "market", "qty", "dip", "band", "baits", "long" }
F.MARKET_LABEL = { move = "QUICK_ROW_MOVE", stab = "QUICK_ROW_STAB", market = "QUICK_ROW_MARKET", dip = "QUICK_DIP_L",
                   band = "QUICK_ROW_BAND", baits = "QUICK_MV_BAITS_L", long = "QS_LABEL", qty = "QUICK_ROW_QTY" }
F.MARKET_DEFAULT = { "move", "stab", "market", "qty", "baits" }
F.MARKET_Y, F.MARKET_STEP = -26, 16

-- Gespeicherte Auswahl auf fuenf Zeilen ergaenzen. Bis 0.164 waren es drei: die fehlenden Zeilen bekommen der Reihe
-- nach die Vorgaben, die noch nicht zu sehen sind (sonst stuende z. B. Einbruch doppelt da).
function F.MarketRowKinds()
    local t = mod.db.focusRows
    local out, used = {}, {}
    -- die alte Vorgabe (move, stab, dip) gilt als nicht umgestellt
    if type(t) == "table" and t[4] == nil and t[1] == "move" and t[2] == "stab" and t[3] == "dip" then t = nil end
    -- ab 0.167: die Vorgabe bis 0.166 (mit Einbruch) gilt ebenso als nicht umgestellt
    if type(t) == "table" and t[1] == "move" and t[2] == "stab" and t[3] == "market" and t[4] == "dip" and t[5] == "baits" then t = nil end
    if type(t) == "table" then
        for i = 1, #F.MARKET_DEFAULT do
            local k = t[i]
            if F.MARKET_LABEL[k] then out[i] = k; used[k] = true end
        end
    else
        for i, k in ipairs(F.MARKET_DEFAULT) do out[i] = k end
        return out
    end
    local pool = {}
    for _, k in ipairs(F.MARKET_DEFAULT) do if not used[k] then pool[#pool + 1] = k end end
    for i = 1, #F.MARKET_DEFAULT do
        if not out[i] then out[i] = table.remove(pool, 1) or F.MARKET_DEFAULT[i] end
    end
    return out
end

function F.MarketRowKind(i)
    return F.MarketRowKinds()[i]
end

function F.SetMarketRow(i, kind)
    if not F.MARKET_LABEL[kind] then return end
    local t = F.MarketRowKinds()
    t[i] = kind
    mod.db.focusRows = t
    F.Update()
end

function F.MarketRowMenu(i, owner)
    local mu = rawget(_G, "MenuUtil")
    if not (mu and mu.CreateContextMenu) then return false end
    mu.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L.QUICK_ROW_MENU)
        for _, k in ipairs(F.MARKET_ROWS) do
            local kind = k
            local function IsSel() return F.MarketRowKind(i) == kind end
            local function Set() mod:Call("Einkaufen", F.SetMarketRow, i, kind) end
            if root.CreateRadio then root:CreateRadio(L[F.MARKET_LABEL[kind]], IsSel, Set)
            else root:CreateButton((IsSel() and "> " or "") .. L[F.MARKET_LABEL[kind]], Set) end
        end
    end)
    return true
end

function F.BuildMarketRows(mp)
    local UI = Peon.UI
    F.marketRows = {}
    local w = W.WIDTH - 2 * W.SIDE - UI.LEFT_W - UI.GAP - 24
    for i = 1, #F.MARKET_DEFAULT do
        local y = F.MARKET_Y - (i - 1) * F.MARKET_STEP
        local r = { index = i }
        r.label = UI.Text(mp, "label", "")
        r.label:SetWidth(96)
        r.label:SetJustifyH("LEFT")
        r.label:SetPoint("TOPLEFT", 12, y)
        r.value = UI.Text(mp, "text", "", w - 110)
        r.value:SetPoint("TOPLEFT", r.label, "TOPRIGHT", 8, 0)
        r.bg = mp:CreateTexture(nil, "BORDER")
        r.bg:SetPoint("TOPLEFT", mp, "TOPLEFT", 6, y + 2)
        r.bg:SetSize(w, F.MARKET_STEP)
        r.bg:Hide()
        r.hover = CreateFrame("Frame", nil, mp)
        r.hover:SetPoint("TOPLEFT", mp, "TOPLEFT", 6, y + 2)
        r.hover:SetSize(w, F.MARKET_STEP)
        if r.hover.EnableMouse then r.hover:EnableMouse(true) end
        r.hover:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(r.label:GetText() or "", 1, 0.82, 0)
            for _, line in ipairs(r.tip or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
            GameTooltip:AddLine(L.QUICK_ROW_HINT, 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r.hover:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        r.hover:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" then mod:Call("Einkaufen", F.MarketRowMenu, i, self) end
        end)
        F.marketRows[i] = r
    end
end

local function MoveLabel(label, y, x)
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", x or 8, y)
end

-- Teile je Modus zeigen oder verbergen, Kaufen bis und Menge ruecken im Schnellkauf nach oben
function F.ApplyMode()
    if not F.tiers then return end
    local quick = ns.Quick.On()
    for _, f in ipairs({ F.kindLabel, F.kindValue, F.autoButton, F.targetLabel, F.targetInput, F.targetHint, F.verdict, F.why }) do f:SetShown(not quick) end
    if quick and F.relistCheck then F.relistCheck:Hide() end   -- ab 0.106: kein Wiedereinstellen im Schnellkauf
    if F.limitHint then F.limitHint:SetShown(not quick) end   -- ab 0.112: kein "Linksklick" im Schnellkauf
    F.qtyLabel:SetText(L.FOCUS_R_QTY)   -- ab 0.133 auch im Schnellkauf die Menge (vorher Limit pro Kauf)
    if F.goldInput then F.goldInput:Hide() end
    if F.qtyAll then F.qtyAll:Hide() end
    F.qtySlider.peonMin = nil   -- Regler beim naechsten Mal neu setzen
    -- ab 0.110 auch die Mausbereiche: sie lagen im Schnellkauf unsichtbar ueber dem Knopf Lockangebot einstellen
    for _, r in ipairs(F.rows) do r.label:SetShown(not quick); r.value:SetShown(not quick); if r.hover then r.hover:SetShown(not quick) end end
    -- ab 0.133: im Schnellkauf stehen Markt, Einbruch und Gekauft links, rechts nur noch das Diagramm
    for i, r in ipairs(F.mRows or {}) do
        r.label:SetText(quick and "" or (L[F.MEASURE_ROWS[i]] or "")); r.value:SetText(""); r.tip = nil
        r.label:SetShown(not quick); r.value:SetShown(not quick); if r.hover then r.hover:SetShown(not quick) end
    end
    for _, f in ipairs(F.quick and F.quick.all or {}) do f:SetShown(quick) end
    if F.quick and F.quick.minParts and not quick then   -- ab 0.167: Min. Menge nur im Schnellkauf
        for _, f in ipairs(F.quick.minParts) do f:Hide() end
        F.quick.minOff:Hide()
    end
    -- ab 0.140: rechts die drei einstellbaren Zeilen (nur im Schnellkauf)
    for _, r in ipairs(F.marketRows or {}) do
        r.label:SetShown(quick); r.value:SetShown(quick); r.hover:SetShown(quick); r.bg:Hide()
    end
    MoveLabel(F.limitLabel, quick and F.QUICK_LIMIT_Y or F.LIMIT_Y, quick and F.QUICK_X or nil)
    MoveLabel(F.qtyLabel, quick and F.QUICK_QTY_Y or F.QTY_Y, quick and F.QUICK_X or nil)
    F.limitLabel:SetText(quick and "" or L.FOCUS_R_LIMIT)   -- ab 0.143: im Schnellkauf traegt der Haken Limit die Beschriftung
    -- ab 0.110: im Schnellkauf alle Beschriftungen links buendig
    F.limitLabel:SetJustifyH(quick and "LEFT" or "RIGHT")
    F.qtyLabel:SetJustifyH(quick and "LEFT" or "RIGHT")
    -- ab 0.112.1: im Schnellkauf haben die Beschriftungen keine feste Breite, die Felder haengen an einer festen Stelle
    local LW = Peon.UI.LABEL_W
    local fx = F.QUICK_FIELD_X / 0.8
    F.limitLabel:SetWidth(quick and 0 or LW)
    F.qtyLabel:SetWidth(quick and 0 or LW)
    F.limitInput:ClearAllPoints()
    -- ab 0.168 hinter der Auswahlliste Limit
    if quick and F.quick and F.quick.limSrc then F.limitInput:SetPoint("LEFT", F.quick.limSrc, "RIGHT", 4 / 0.8, 0)
    elseif quick then F.limitInput:SetPoint("LEFT", F.limitLabel, "LEFT", fx, F.QUICK_LIMIT_DY / 0.8)
    else F.limitInput:SetPoint("LEFT", F.limitLabel, "RIGHT", 8 / 0.8, 0) end
    if not quick then F.limitInput:Show() end
    F.qtySlider:ClearAllPoints()
    if quick then F.qtySlider:SetPoint("LEFT", F.qtyLabel, "LEFT", F.QUICK_FIELD_X, 0)
    else F.qtySlider:SetPoint("LEFT", F.qtyLabel, "RIGHT", 6, 0) end
    F.qtyInput:ClearAllPoints()
    F.qtyInput:SetPoint("LEFT", F.qtySlider, "RIGHT", 6 / 0.8, 0)
    F.qtyHint:ClearAllPoints()
    F.qtyHint:SetPoint("LEFT", F.qtyInput, "RIGHT", 4, 0)
    if quick then F.qtyHint:SetText("") end   -- ab 0.140 ohne Zusatz hinter der Menge (Max. Preis darunter)
    -- ab 0.140: im Schnellkauf steht der Kaufknopf unter Max. Preis, die Zeile darueber entfaellt (Text im Knopf)
    F.buyButton:ClearAllPoints()
    if quick then F.buyButton:SetPoint("TOPLEFT", 10, F.QUICK_BUY_TOP)
    else F.buyButton:SetPoint("BOTTOMLEFT", 10, 70) end
    F.buyInfo:SetShown(not quick)
    if F.sectionTab and F.sectionTab.SetText then F.sectionTab:SetText(quick and L.QUICK_TAB_LIMIT or L.FOCUS_HEAD_CHANCE) end
    -- ab 0.133: Umschalter nur, wenn der Aufkauf eingeschaltet ist (Einstellungen, Erweitert)
    local both = ns.Quick.BuyoutOn()
    F.modeQuick:SetShown(both)
    F.modeBuyout:SetShown(both)
    if F.modeQuick.LockHighlight then
        if quick then F.modeQuick:LockHighlight(); F.modeBuyout:UnlockHighlight()
        else F.modeBuyout:LockHighlight(); F.modeQuick:UnlockHighlight() end
    end
    -- ab 0.134: Knoepfe fuer Linien und Zeitraum nur im Schnellkauf, der Aufkauf zeigt alles wie bisher
    F.ApplyChartLines(quick)
    for _, b in ipairs(F.rangeButtons or {}) do b:SetShown(quick) end
    if F.chartLines then F.chartLines.frame:SetShown(quick and F.chart ~= nil) end
    if quick then
        F.chartLegend:SetText(("|cff999999%s|r  |cffffd133%s|r  |cff4d8cff%s|r  |cffb366ff%s|r"):format(L.QUICK_LEG_UNDER, L.MEASURE_MIN, L.FOCUS_R_LIMIT, L.QUICK_LEG_BAIT))
    else
        F.chartLegend:SetText(("|cff999999%s|r  |cffffd133%s|r  |cff4d8cff%s|r  |cff60e060%s|r"):format(L.MEASURE_UNDER, L.MEASURE_MIN, L.FOCUS_R_LIMIT, L.FOCUS_R_TARGET))
        if F.buyButton.UnlockHighlight then F.buyButton:UnlockHighlight() end
    end
    F.LayoutQuick()
    F.ApplyTab(true)   -- ab 0.168: Zeilen je Tab
end

-- ab 0.144 (Board KarloDerBaer): Stueckpreis, der ermittelte Zielpreis je Stueck. Dahinter der Hebel, der ihn setzt:
-- (Limit), (Gleitend), (Guenstigstes) oder (Auswahl) fuer eine angeklickte Stufe. Begrenzt der Standard das
-- Gleitende, steht (Limit) dahinter.
function F.UnitText(live)
    local key = F.key
    if key == nil then return "" end
    local Q = ns.Quick
    local rows = live and F.LiveRows() or nil
    local limit, kind = Q.EffectiveLimit(key, rows)
    if not Num(limit) then
        if kind == "limit" then return GREY .. L.QUICK_MAX_NOLIMIT .. "|r" end
        if kind == "glide" then return GREY .. L.QUICK_GLIDE_NONE .. "|r" end
        return GREY .. L.QUICK_MAX_NONE .. "|r"
    end
    local lever
    if kind == "glide" then lever = L.QUICK_LEVER_GLIDE   -- ab 0.168 ohne Deckel durch den Standard
    elseif kind == "limit" then lever = L.QUICK_LEVER_LIMIT
    elseif Num(Q.pick[key]) then lever = L.QUICK_LEVER_PICK
    else
        -- ab 0.169 (KarloDerBaer 28.11.2026): im Direktkauf vorn der aktuell guenstigste Preis. Reicht die Menge ueber
        -- mehrere Stufen, steht die teuerste dahinter.
        local lv = rows and ns.Data.Available(rows) or {}
        local low = lv[1] and lv[1].price
        if Num(low) and low < limit then
            return Money(low) .. " " .. GREY .. "(" .. L.QUICK_LEVER_CHEAP .. ")|r " .. GREY .. L.QUICK_UNIT_UPTO:format(Money(limit)) .. "|r"
        end
        lever = L.QUICK_LEVER_CHEAP
    end
    return Money(limit) .. " " .. GREY .. "(" .. lever .. ")|r"
end

-- Begrenzt der Standard (Haken Limit) gerade das Gleitende?
function F.GlideCapped(key, rows)
    local Q = ns.Quick
    if not (Q.GlideOn(key) and Q.LimitOn(key)) then return false end
    local std = F.ManualLimit(key)
    if not Num(std) then return false end
    local g = Q.GlideValue(key, nil, rows)
    return not Num(g) or std < g
end

-- ab 0.140: Zeile Max. Preis unter der Menge, ab 0.144 Gesamtpreis in zwei Zeilen (Board KarloDerBaer).
--   erste Zeile   Gesamt (Menge x Stueckpreis). Limit oder Gleitend mit fester Menge: Menge mal Grenze. Sonst das,
--                 was ein Klick jetzt kauft, mit dem Durchschnitt je Stueck. Greift die Goldreserve, gilt schon ihre
--                 Menge und ihr Preis.
--   zweite Zeile  "Begrenzt durch Goldreserve (Wert)", wenn sie die Menge kuerzt, und der Hinweis, wenn der hoechste
--                 Stueckpreis ueber dem ueblichen Bereich liegt
function F.MaxText(d, live)
    local key = F.key
    if key == nil then return "" end
    local Q = ns.Quick
    local rows = live and F.LiveRows() or nil
    local limit, kind = Q.EffectiveLimit(key, rows)
    local plan = live and d and not d.gone and d or nil
    local text
    if kind == "limit" and not Num(limit) then return GREY .. L.QUICK_MAX_NOLIMIT .. "|r" end
    if kind == "glide" and not Num(limit) then return GREY .. L.QUICK_GLIDE_NONE .. "|r" end
    local want = Q.QtyWant(key)
    local n, cost, top = 0, 0, nil
    for _, l in ipairs(rows and ns.Data.Available(rows) or {}) do
        if Num(limit) and l.price <= limit then
            local take = l.qty
            if want and n + take > want then take = want - n end
            if take > 0 then n, cost, top = n + take, cost + take * l.price, l.price end
        end
    end
    local function Avg(c, k) return k > 0 and math.floor(c / k + 0.5) or 0 end
    local short = plan and plan.reserveShort
    if short or (plan and plan.portion) then   -- ab 0.167 auch mit Portion des Smart-Teilkaufs
        local best = plan.best or {}
        local got = Num(best.qty) and best.qty or 0
        local c = Num(best.cost) and best.cost or 0
        text = L.QUICK_MAX_FIXED:format(Money(c), got, Money(Avg(c, got)))
    elseif kind ~= "normal" and want then
        text = L.QUICK_MAX_FIXED:format(Money(want * limit), want, Money(limit))
    elseif n <= 0 then
        return GREY .. L.QUICK_MAX_NONE .. "|r"
    else
        text = L.QUICK_MAX_FIXED:format(Money(cost), n, Money(Avg(cost, n)))
    end
    local second = {}
    if short then
        second[#second + 1] = ORANGE .. L.QUICK_MAX_RESERVE:format(Money((tonumber(mod.db.radarReserve) or 0) * 10000)) .. "|r"
    end
    if plan and plan.minShort then second[#second + 1] = ORANGE .. L.QUICK_MIN_SHORT:format(plan.minShort) .. "|r" end   -- ab 0.167
    if plan and plan.portion then second[#second + 1] = GREY .. L.QUICK_PORTION_LINE:format(plan.portion, plan.portionAll or 0) .. "|r" end
    if Num(top) then
        local ok, ctx = pcall(ns.Buyout.Context, nil, key)
        local band = ok and type(ctx) == "table" and ctx.band or nil
        if type(band) == "table" and Num(band.high) and top > band.high then second[#second + 1] = ORANGE .. L.QUICK_MAX_HIGH .. "|r" end
    end
    if #second > 0 then text = text .. "\n" .. table.concat(second, ", ") end
    return text
end

-- ab 0.167: Richtpreis und Gewinnspanne von Gleitend (Menue nur, wenn das Spiel keine Auswahlliste kennt)
local function RadioMenu(owner, title, list, isSel, set)
    local mu = rawget(_G, "MenuUtil")
    if not (mu and mu.CreateContextMenu) then return false end
    mu.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(title)
        for _, o in ipairs(list) do
            local v, text = o[1], o[2]
            if root.CreateRadio then root:CreateRadio(text, function() return isSel(v) end, function() set(v) end)
            else root:CreateButton((isSel(v) and "> " or "") .. text, function() set(v) end) end
        end
    end)
    return true
end

function F.RefMenu(owner)
    local Q, list = ns.Quick, {}
    for _, r in ipairs(Q.REFS) do list[#list + 1] = { r, L["QUICK_REF_" .. r:upper()] } end
    return RadioMenu(owner, L.QUICK_REF_L, list, function(v) return Q.Ref(F.key) == v end,
        function(v) mod:Call("Schnellkauf", Q.SetRef, v) end)
end

function F.MarginMenu(owner)
    local Q, list = ns.Quick, {}
    for _, m in ipairs(Q.MARGINS) do list[#list + 1] = { m, L.QUICK_MARGIN_FMT:format(m) } end
    return RadioMenu(owner, L.QUICK_MARGIN_L, list, function(v) return Q.Margin(F.key) == v end,
        function(v) mod:Call("Schnellkauf", Q.SetMargin, v) end)
end

---------------------------------------------------------------------------
-- ab 0.168 (KarloDerBaer 28.11.2026): Auswahllisten Limit und Ausloeser mit Kurzform im zugeklappten Zustand
---------------------------------------------------------------------------
function F.LimSrcList()
    local out = { "fix" }
    for _, r in ipairs(ns.Quick.REFS) do out[#out + 1] = r end
    return out
end

function F.SrcName(r)
    if r == "fix" then return L.QUICK_SRC_FIX end
    return L["QUICK_REF_" .. tostring(r):upper()] or tostring(r)
end

function F.SrcShort(r) return L["QUICK_SHORT_" .. tostring(r):upper()] or F.SrcName(r) end

function F.TrigName(t) return L["QUICK_TRIG_" .. tostring(t):upper()] or tostring(t) end

function F.TrigShort(t)
    if t == "fix" then return L.QUICK_SHORT_FIX end
    return L["QUICK_SHORT_T" .. tostring(t):upper()] or F.TrigName(t)
end

-- Auswahlliste, die zugeklappt eine Kurzform zeigt (dd.peonShort, gesetzt mit F.SetShort)
function F.ShortDropdown(parent, width, items, get, set)
    local dd = Peon.UI.Dropdown(parent, width, items, get, set)
    if not dd.fallback and dd.SetSelectionTranslator then
        pcall(dd.SetSelectionTranslator, dd, function(sel) return dd.peonShort or (type(sel) == "table" and sel.text) or "" end)
    end
    return dd
end

function F.SetShort(dd, text)
    if not dd then return end
    dd.peonShort = text
    if dd.fallback or not dd.GenerateMenu then dd:SetText(text); return end
    pcall(dd.GenerateMenu, dd)
    local fs = rawget(dd, "Text")
    if type(fs) == "table" and fs.SetText then fs:SetText(text) end
end

-- Auswahlliste neu beschriften (ohne Kurzform)
function F.RefreshDrop(dd, text)
    if not dd then return end
    if dd.fallback or not dd.GenerateMenu then dd:SetText(text) else pcall(dd.GenerateMenu, dd) end
end

function F.LimSrcMenu(owner)
    local Q, list = ns.Quick, {}
    for _, r in ipairs(F.LimSrcList()) do list[#list + 1] = { r, F.SrcName(r) } end
    return RadioMenu(owner, L.QUICK_LIMIT, list, function(v) return Q.LimSrc(F.key) == v end,
        function(v) mod:Call("Schnellkauf", Q.SetLimSrc, v) end)
end

function F.TrigMenu(owner)
    local Q, list = ns.Quick, {}
    for _, t in ipairs(Q.TRIGS) do list[#list + 1] = { t, F.TrigName(t) } end
    return RadioMenu(owner, L.QUICK_TRIG_L, list, function(v) return Q.Trig(F.key) == v end,
        function(v) mod:Call("Schnellkauf", Q.SetTrig, v) end)
end

function F.TrigPctMenu(owner)
    local Q, list = ns.Quick, {}
    for _, m in ipairs(Q.TRIG_PCTS) do list[#list + 1] = { m, L.QUICK_MARGIN_FMT:format(m) } end
    return RadioMenu(owner, L.QUICK_TRIG_PCT_L, list, function(v) return Q.TrigPct(F.key) == v end,
        function(v) mod:Call("Schnellkauf", Q.SetTrigPct, v) end)
end

-- Alter einer Zeit (time()) als kurzer Text
local function Age(t)
    local m = math.max(0, math.floor((time() - (t or time())) / 60))
    if m < 60 then return L.QUICK_AGE_MIN:format(m) end
    return L.QUICK_AGE_HOUR:format(math.floor(m / 60))
end

-- Wert hinter der Auswahlliste Ausloeser (Limit: der Wert nach dem Abstand, Letzter Tiefstpreis: Preis und Alter)
function F.TrigValueText(key)
    local Q = ns.Quick
    if key == nil then return "" end
    local t = Q.Trig(key)
    if t == "low" then
        local p, at = Q.LastLow(key)
        if not Num(p) then return GREY .. L.QUICK_TRIG_LOW_NONE .. "|r" end
        return GREY .. Money(p) .. " (" .. Age(at) .. ")|r"
    end
    if t == "limit" then
        local limit = Q.EffectiveLimit(key, F.LiveRows())
        local v = Num(limit) and Q.TriggerValue(key, limit) or nil
        return Num(v) and (GREY .. Money(v) .. "|r") or ""
    end
    if t == "off" then return GREY .. L.QUICK_TRIG_OFF_HINT .. "|r" end
    return ""
end

function F.TrigTip()
    local Q = ns.Quick
    local key = F.key
    local lines = { L.QUICK_TRIG_L, L.QUICK_TRIG_TIP, " " }
    local limit = key ~= nil and Q.EffectiveLimit(key, F.LiveRows()) or nil
    for _, t in ipairs(Q.TRIGS) do
        local name = F.TrigName(t)
        if key ~= nil and Q.Trig(key) == t then name = "> " .. name end
        lines[#lines + 1] = name .. ": " .. GREY .. L["QUICK_TRIG_" .. t:upper() .. "_TIP"] .. "|r"
    end
    lines[#lines + 1] = " "
    lines[#lines + 1] = L.QUICK_TRIG_CAP
    if Num(limit) then
        local v = Q.TriggerValue(key, limit)
        lines[#lines + 1] = L.QUICK_TRIG_NOW:format(Money(v), Money(limit))
    end
    return lines
end

-- Zeile Band: Ausloeser bis Limit und ob es ausgeloest hat
function F.BandRowText(live, key)
    local Q = ns.Quick
    key = key or F.key
    if key == nil then return "" end
    local limit = Q.EffectiveLimit(key, live and F.LiveRows() or nil)
    if not Num(limit) then return "" end
    local trig, _, capped = Q.TriggerValue(key, limit)
    if not Num(trig) or trig >= limit then
        if capped then return GREY .. L.QUICK_BAND_CAPPED .. "|r" end
        return GREY .. L.QUICK_BAND_NONE .. "|r"
    end
    local text = L.QUICK_BAND_FMT:format(Money(trig), Money(limit))
    if Q.armed[key] then return text .. " " .. GREEN .. L.QUICK_BAND_ARMED .. "|r" end
    return text .. " " .. GREY .. L.QUICK_BAND_WAIT .. "|r"
end

function F.BandTip()
    return { L.QUICK_BAND_L, L.QUICK_BAND_TIP }
end

---------------------------------------------------------------------------
-- ab 0.168: Tabs Limitkauf und Direktkauf ueber dem Gegenstand (wie Blizzards Reiter im Verkaufen, aber anklickbar)
---------------------------------------------------------------------------
function F.MakeTab(parent, text, fn)
    local UI = Peon.UI
    local b = CreateFrame("Button", nil, parent)
    local l = b:CreateTexture(nil, "ARTWORK")
    UI.SetAtlas(l, "auctionhouse-selltab-left", true)
    l:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    local fs = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetPoint("LEFT", l, "RIGHT", 12, 0)
    local m = b:CreateTexture(nil, "BORDER")
    UI.SetAtlas(m, "auctionhouse-selltab-middle", true)
    m:SetPoint("TOPLEFT", l, "TOPRIGHT", 0, 0)
    m:SetPoint("RIGHT", fs, "RIGHT", 12, 0)
    local r = b:CreateTexture(nil, "BORDER")
    UI.SetAtlas(r, "auctionhouse-selltab-right", true)
    r:SetPoint("TOPLEFT", m, "TOPRIGHT", 0, 0)
    r:SetPoint("BOTTOMLEFT", m, "BOTTOMRIGHT", 0, 0)
    b.fs, b.parts = fs, { l, m, r }
    b.Fit = function(self)
        local function Size(f, m)
            local v = f[m] and f[m](f)
            return Num(v) and v or 0
        end
        local lw, rw, tw, h = Size(l, "GetWidth"), Size(r, "GetWidth"), Size(fs, "GetStringWidth"), Size(l, "GetHeight")
        self:SetSize(math.max(40, lw + tw + 24 + rw), math.max(18, h))
    end
    -- Text setzen (ersetzt das SetText des Knopfs, die Schrift ist fs)
    b.SetText = function(self, t) fs:SetText(t or ""); self:Fit() end
    b.SetActive = function(self, on)
        local a = on and 1 or 0.55
        for _, p in ipairs(self.parts) do if p.SetAlpha then p:SetAlpha(a) end end
        if fs.SetTextColor then
            if on then fs:SetTextColor(1, 0.82, 0) else fs:SetTextColor(0.6, 0.6, 0.6) end
        end
    end
    b:SetText(text)
    if fn then b:SetScript("OnClick", fn) end
    return b
end

function F.SyncTabs()
    local Q = ns.Quick
    local quick = Q.On()
    local tab = F.key ~= nil and Q.Tab(F.key) or "limit"
    if F.directTab then F.directTab:SetShown(quick) end
    if F.sectionTab and F.sectionTab.SetActive then F.sectionTab:SetActive(not quick or tab == "limit") end
    if F.directTab and F.directTab.SetActive then F.directTab:SetActive(quick and tab == "direct") end
end

-- Zeilen des Einkaufens je Tab anordnen und die Teile zeigen, die zum Tab und zur Wahl gehoeren
function F.ApplyTab(force)
    local q = F.quick
    if not q then return end
    local Q = ns.Quick
    local quick = Q.On()
    F.SyncTabs()
    if not quick then
        for _, f in ipairs(q.limitParts) do f:Hide() end
        for _, f in ipairs(q.choiceParts) do f:Hide() end
        q.layoutTab = nil
        return
    end
    local key = F.key
    local tab = key ~= nil and Q.Tab(key) or "limit"
    local lim = tab == "limit"
    if lim and key ~= nil then Q.EnsureDefaults(key) end   -- ab 0.170: Vorgaben beim ersten Limitkauf
    for _, f in ipairs(q.limitParts) do f:SetShown(lim) end
    local glide = lim and Q.GlideOn(key) or false
    F.limitInput:SetShown(lim and not glide)
    q.limitStd:SetShown(lim and not glide)
    q.margin:SetShown(glide)
    q.glideValue:SetShown(glide)
    local t = lim and Q.Trig(key) or nil
    q.trigInput:SetShown(t == "fix")
    q.trigPct:SetShown(t == "limit")
    q.trigValue:SetShown(t == "limit" or t == "low" or t == "off")
    q.trigValue:ClearAllPoints()
    if t == "limit" then q.trigValue:SetPoint("LEFT", q.trigPct, "RIGHT", 6, 0)
    else q.trigValue:SetPoint("LEFT", q.trigSrc, "RIGHT", 8, 0) end
    if q.layoutTab == tab and not force then return end
    q.layoutTab = tab
    local rows = F.QUICK_TAB_ROWS[tab]
    MoveLabel(F.qtyLabel, rows.qty, F.QUICK_X)
    MoveLabel(q.unitLabel, rows.unit, F.QUICK_X)
    MoveLabel(q.maxLabel, rows.max, F.QUICK_X)
    if rows.band then MoveLabel(q.bandLabel, rows.band, F.QUICK_X) end
    F.buyButton:ClearAllPoints()
    F.buyButton:SetPoint("TOPLEFT", 10, rows.buy)
    q.line1:ClearAllPoints()
    q.line1:SetPoint("TOPLEFT", 12, rows.fold + 8)
    q.scroll:ClearAllPoints()
    q.scroll:SetPoint("TOPLEFT", F.left, "TOPLEFT", 4, rows.fold + 4)
    q.scroll:SetPoint("BOTTOMRIGHT", F.left, "BOTTOMRIGHT", -24, 6)
    F.LayoutQuick()
end

-- Tooltip am Richtpreis: was er ist, sein Wert jetzt, darunter alle Richtpreise mit Wert
function F.RefTip()
    local Q = ns.Quick
    local r = Q.Ref(F.key)
    local rows = F.LiveRows()
    local lines = { L.QUICK_REF_TIP, " " }
    for _, x in ipairs(Q.REFS) do
        local v = F.key ~= nil and Q.RefValue(F.key, x, rows) or nil
        local name = L["QUICK_REF_" .. x:upper()]
        if x == r then name = "> " .. name end
        lines[#lines + 1] = name .. ": " .. (Num(v) and Money(v) or (GREY .. L.QUICK_REF_NONE .. "|r"))
        lines[#lines + 1] = GREY .. L["QUICK_REF_" .. x:upper() .. "_TIP"] .. "|r"
    end
    local g = F.key ~= nil and Q.GlideValue(F.key, nil, rows) or nil
    lines[#lines + 1] = " "
    lines[#lines + 1] = Num(g) and L.QUICK_M_VALUE:format(Money(g)) or (GREY .. L.QUICK_GLIDE_NONE .. "|r")
    return lines
end

function F.MarginTip()
    local Q = ns.Quick
    local lines = { L.QUICK_MARGIN_TIP }
    local key = F.key
    local base = key ~= nil and Q.RefValue(key, nil, F.LiveRows()) or nil
    local g = key ~= nil and Q.GlideValue(key, nil, F.LiveRows()) or nil
    if Num(base) and Num(g) then
        lines[#lines + 1] = " "
        lines[#lines + 1] = L.QUICK_MARGIN_CALC:format(Money(base), Q.Margin(key), Money(g))
    end
    return lines
end

-- ab 0.140: Statistik links (Sitzung, heute, 7 Tage), ab 0.144 oben der letzte Kauf (Zuletzt)
function F.UpdateStats()
    local q = F.quick
    if not q then return end
    local Q, QS = ns.Quick, ns.QuickStats
    local key = F.key
    for _, r in ipairs(q.stats) do
        if key == nil then r.value:SetText("")
        elseif r.src == "last" then r.value:SetText(Q.StatText(Q.LastStats(key)))
        elseif r.src == "session" then r.value:SetText(Q.StatText(Q.SessionStats(key)))
        else r.value:SetText(Q.StatText(QS and QS.Bought and QS.Bought(key, r.src) or nil)) end
    end
end

-- Lockangebot und Zeilen links fuellen
function F.UpdateQuick(d, live)
    local q = F.quick
    if not q then return end
    local Q = ns.Quick
    local key = F.key
    -- Goldreserve (Gold, fuer alle Gegenstaende), ab 0.140 mit Haken
    local resOn = F.ReserveOn()
    if q.resCheck.SetChecked then q.resCheck:SetChecked(resOn) end
    if not Typing(q.resInput) then
        local res = (tonumber(mod.db.radarReserve) or 0) * 10000
        if res > 0 then q.resInput:SetAmount(res) else ClearMoney(q.resInput) end
    end
    MoneyEnabled(q.resInput, resOn)
    local suggest, base = Q.Suggest()
    local m = q.priceInput
    if not Typing(m) then
        local v = Q.ManualPrice(key) or suggest
        if Num(v) and v > 0 then m:SetAmount(v) else ClearMoney(m) end
    end
    if Q.ManualPrice(key) then q.priceHint:SetText(GREY .. L.QUICK_PRICE_OWN .. "|r")
    elseif Num(base) then q.priceHint:SetText(GREY .. L.QUICK_PRICE_HINT:format(tonumber(mod.db.quickBaitPct) or 50) .. "|r")
    else q.priceHint:SetText("") end
    -- ab 0.132: Menge des Lockangebots, dahinter wie viele in den Taschen liegen
    local qn = key ~= nil and Q.BaitQty(key) or 1
    if not (q.qtyInput.HasFocus and q.qtyInput:HasFocus()) then q.qtyInput:SetText(tostring(qn)) end
    local have = key ~= nil and Q.BagCount(key) or nil
    q.qtyHint:SetText(have and (((have < qn) and ORANGE or GREY) .. L.QUICK_BAIT_HAVE:format(have) .. "|r") or "")
    local b = Q.BaitFor(key)
    local busy = b ~= nil and (b.state == "posting" or b.state == "cancelling")
    local canPost = live and key ~= nil and ns.Data.IsCommodity(key) and Num(Q.Price(key)) and not busy
    q.post:SetText((b and b.state == "confirm") and L.QUICK_CONFIRM or L.QUICK_POST)
    On(q.post, canPost and true or false)
    -- ab 0.168: Tab, Limit (Fest oder Richtpreis) und Ausloeser
    F.ApplyTab()
    local lim = key ~= nil and Q.Tab(key) == "limit"
    local glideOn = lim and Q.GlideOn(key)
    MoneyEnabled(F.limitInput, true)
    if F.limitInput.SetAlpha then F.limitInput:SetAlpha(1) end
    if lim and not glideOn and not F.ManualLimit(key) then q.limitStd:SetText(ORANGE .. L.QUICK_LIMIT_EMPTY .. "|r")
    else q.limitStd:SetText("") end
    -- Auswahllisten: Text neu, wenn Gegenstand oder Wahl wechseln (zugeklappt die Kurzform)
    local msig = tostring(key) .. ":" .. Q.LimSrc(key) .. ":" .. Q.Margin(key) .. ":" .. Q.Trig(key) .. ":" .. Q.TrigPct(key)
    if q.methodSig ~= msig then
        q.methodSig = msig
        F.SetShort(q.limSrc, F.SrcShort(Q.LimSrc(key)))
        F.SetShort(q.trigSrc, F.TrigShort(Q.Trig(key)))
        F.RefreshDrop(q.margin, L.QUICK_MARGIN_FMT:format(Q.Margin(key)))
        F.RefreshDrop(q.trigPct, L.QUICK_MARGIN_FMT:format(Q.TrigPct(key)))
    end
    if not Typing(q.trigInput) then
        local tf = key ~= nil and Q.TrigFix(key) or nil
        if tf then q.trigInput:SetAmount(tf) else ClearMoney(q.trigInput) end
    end
    q.trigValue:SetText(lim and F.TrigValueText(key) or "")
    q.bandValue:SetText(lim and F.BandRowText(live, key) or "")
    F.SyncMinQty(key)
    -- ab 0.167: Teilkauf
    local pm = Q.PortionOn() and "smart" or "off"
    if q.portionSig ~= pm then
        q.portionSig = pm
        if q.portionDrop.fallback or not q.portionDrop.GenerateMenu then
            q.portionDrop:SetText(pm == "smart" and L.QUICK_PORTION_SMART or L.QUICK_PORTION_OFF)
        else pcall(q.portionDrop.GenerateMenu, q.portionDrop) end
    end
    -- ab 0.145 (Board KarloDerBaer) ohne "jetzt ...": der Wert steht in der Zeile Stueckpreis
    q.glideValue:SetText("")
    q.unitValue:SetText(F.UnitText(live))
    q.maxValue:SetText(F.MaxText(d, live))
    -- ab 0.133: waehrend eines Kaufs stand hier sein Stand, ab 0.144 sonst nichts (Zuletzt in der Statistik).
    -- ab 0.166.4 immer leer (Board KarloDerBaer 27.11.2026): der Knopf zeigt den Stand des Kaufs schon selbst.
    q.lastBuy:SetText("")
    if key ~= nil and not ns.Data.IsCommodity(key) then q.state:SetText(GREY .. L.QUICK_ONLY_MASS .. "|r")
    else q.state:SetText(Q.StateText(key)) end
    q.balance:SetText(Q.BalanceText(key))
    if q.skip.SetChecked then q.skip:SetChecked(Q.SkipOn(key)) end
    F.UpdateStats()
end

-- Marktbewegung (ab 0.108): Zufluss, Abfluss, Bewegung, Lockangebote, Einbruch, Gekauft, Langfristig. Rueckgabe
-- vals, tips (je Index wie F.QUICK_ROWS), code der Bewegung
function F.QuickMoveValues(v, key)   -- ab 0.140 key (Vorgabe F.key, Verkaufen nutzt sie mit)
    local Q, M = ns.Quick, ns.Measure
    local db = mod.db
    if key == nil then key = F.key end
    local vals, tips = { "", "", "", "", "", "", "" }, {}
    local win = math.floor(M.WINDOW / 60 + 0.5)
    local function R(x) x = x or 0; if x >= 10 then return tostring(math.floor(x + 0.5)) end return Dec(x) end
    local code, ev, parts = Q.Movement(v)   -- ab 0.165 mit Einbruechen und Lockangeboten des gemessenen Gegenstands (v.key)
    if code == "first" then
        if v or (AHOpen() and key ~= nil) then vals[3] = GREY .. L.QUICK_MV_FIRST:format(M.FIRST) .. "|r" end
    else
        vals[1] = L.QUICK_MV_RATE:format(R(v.inAll), R(v.newPerMin))
        tips[1] = { L.QUICK_MV_TIP_IN:format(R(v.inAll), R(v.newPerMin), win) }
        vals[2] = L.QUICK_MV_RATE:format(R(v.out), R(v.soldPerMin))
        tips[2] = { L.QUICK_MV_TIP_OUT:format(R(v.out), R(v.soldPerMin), win) }
        -- ab 0.165 Marktstabilitaet: stabil gruen, bewegt gelb, unruhig orange, dahinter die Ereignisse je Minute
        vals[3] = (F.MARKET_COLOR[code] or "") .. L["QUICK_MV_" .. code:upper()] .. "|r " .. GREY .. L.QUICK_MV_JUMPS:format(R(ev)) .. "|r"
        tips[3] = { L.QUICK_MV_TIP_MOVE:format(parts.nJumps, tonumber(db.quickJumpPct) or 2, parts.nDips, parts.nBaits, win, R(ev)),
                    GREY .. Q.MoveRuleText() .. "|r" }
    end
    local st = key ~= nil and (v or AHOpen()) and Q.BaitStats(key) or nil
    local sec = tonumber(db.quickFollowSec) or 30
    local ruleTip = L.QUICK_MV_TIP_BAITS:format(tonumber(db.quickBaitMinPct) or 5, sec)
    if not st then
        if v or (AHOpen() and key ~= nil) then vals[4] = GREY .. L.QUICK_MV_BAITS_NONE:format(win) .. "|r" end
        tips[4] = { ruleTip }
    else
        vals[4] = L.QUICK_MV_BAITS:format(st.n, win, st.withFollow)
        local f = st.last
        tips[4] = { L.QUICK_MV_TIP_AVG:format(R(st.added / st.n)),
                    L.QUICK_MV_TIP_LAST:format(f.own and L.QUICK_MV_OWN_L or L.QUICK_MV_FOREIGN_L, Money(f.price),
                        ns.Radar.ShortAge(math.max(0, math.floor(Now() - f.t)))) .. " " .. L.QUICK_MV_TIP_LAST2:format(f.added, f.times, f.sec),
                    ruleTip }
    end
    if key ~= nil and (v or AHOpen()) then vals[5], tips[5] = Q.DipText(key) end   -- ab 0.125
    if key ~= nil then vals[6], tips[6] = Q.BoughtText(key) end   -- ab 0.111
    if key ~= nil and ns.QuickStats then vals[7], tips[7] = ns.QuickStats.FocusText(key) end   -- ab 0.122
    return vals, tips, code, v
end

-- ab 0.165 ohne eingefaerbte Zeile Bewegung (bis 0.164 nach der Lebhaftigkeit), die Marktstabilitaet hat eine eigene Zeile
F.MARKET_COLOR = { low = GREEN, mid = YELLOW, high = ORANGE }

-- ab 0.140 (Board KarloDerBaer 26.11.2026): Zeilen rechts zwischen Angeboten und Diagramm, je Zeile einstellbar.
--   move   Bewegung: Zufluss und Abfluss je Minute (bis 0.164 nach der Lebhaftigkeit eingefaerbt)
--   stab   Preisstabilitaet (bis 0.164 Stabilitaet): stabil, steigend, fallend, sprunghaft, schwankend
--          (Quick.Stability ueber den Zeitraum des Diagramms)
--   market Marktstabilitaet (ab 0.165, vorher Lebhaftigkeit im Tooltip der Stabilitaet): stabil, bewegt, unruhig nach
--          Preisspruengen, Einbruechen und Lockangeboten je Minute (Quick.Movement)
--   dip    Einbruch dieser Sitzung
--   band   Ueblicher Bereich
--   baits  Lockangebote
--   long   Langfristig (Treffer und Einbrueche ueber Tage)
local function HasHist(key)
    local h = ns.Quick.hist[key]
    return h ~= nil and (h.n or 0) > 0
end

F.STAB_COLOR = { stable = GREEN, rising = YELLOW, falling = ORANGE, jumpy = ORANGE, wavy = YELLOW }

function F.MarketRowValue(kind, v, vals, tips, code, key)
    local function R(x) x = x or 0; if x >= 10 then return tostring(math.floor(x + 0.5)) end return Dec(x) end
    if key == nil then key = F.key end
    if key == nil then return "", nil end
    if kind == "move" then
        if code == "first" or not v then return vals[3] ~= "" and vals[3] or "", { tips[3] and tips[3][1] or nil } end
        local tip = { L.QUICK_MV_TIP_IN:format(R(v.inAll), R(v.newPerMin), math.floor(ns.Measure.WINDOW / 60 + 0.5)),
                      L.QUICK_MV_TIP_OUT:format(R(v.out), R(v.soldPerMin), math.floor(ns.Measure.WINDOW / 60 + 0.5)) }
        return L.QUICK_MARKET:format(F.ICON_IN, R(v.inAll), F.ICON_OUT, R(v.out)), tip
    elseif kind == "stab" then
        local st, info = ns.Quick.Stability(key, F.ChartRange())
        local tip = {}
        if st == "first" then
            if not (AHOpen() and HasHist(key)) then return GREY .. L.QUICK_STAB_NONE .. "|r", tip end
            return GREY .. L.QUICK_STAB_FIRST .. "|r", tip
        end
        tip[#tip + 1] = L.QUICK_STAB_TIP:format(info.minutes and R(info.minutes) or "-", (info.trend >= 0 and "+" or "") .. Dec(info.trend),
            Dec(info.span), info.jumps or 0, Dec(info.perMin or 0))
        tip[#tip + 1] = GREY .. L.QUICK_STAB_RULE .. "|r"
        return (F.STAB_COLOR[st] or "") .. L["QUICK_STAB_" .. st:upper()] .. "|r", tip
    elseif kind == "market" then
        if (vals[3] or "") == "" then return GREY .. L.QUICK_STAB_NONE .. "|r", { GREY .. ns.Quick.MoveRuleText() .. "|r" } end
        return vals[3], tips[3]
    elseif kind == "dip" then
        return vals[5] or "", tips[5]
    elseif kind == "band" then
        return F.BandText(nil, key), nil
    elseif kind == "qty" then
        return F.QtyRowValue(key)
    elseif kind == "baits" then
        return vals[4] or "", tips[4]
    elseif kind == "long" then
        return vals[7] or "", tips[7]
    end
    return "", nil
end

-- ab 0.167: Zeile Menge: alles im Markt jetzt, dahinter Pfeil hoch oder runter (ab Quick.QTY_TREND_PCT Prozent ueber
-- den Zeitraum des Diagramms), sonst ein grauer Punkt
F.ICON_UP = "|TInterface\\Buttons\\Arrow-Up-Up:14:14:0:3|t"
F.ICON_DOWN = "|TInterface\\Buttons\\Arrow-Down-Up:14:14:0:-3|t"
function F.QtyRowValue(key)
    local lv = ns.Buy.live and ns.Buy.live[key]
    if not (type(lv) == "table" and type(lv.rows) == "table" and (AHOpen() or HasHist(key))) then return GREY .. L.QUICK_STAB_NONE .. "|r", nil end
    local n = 0
    for _, l in ipairs(ns.Data.Available(lv.rows)) do n = n + l.qty end
    local text = tostring(n)
    local now, old, pct, trend, mins = ns.Quick.QtyTrend(key, F.ChartRange())
    local tip = { L.QUICK_QTY_ROW_TIP:format(ns.Quick.QTY_TREND_PCT) }
    if trend then
        local icon = trend == "up" and F.ICON_UP or trend == "down" and F.ICON_DOWN or ns.QuickStats.Dot("none")
        text = text .. " " .. icon
        tip[#tip + 1] = L.QUICK_QTY_ROW_CMP:format(mins, old, now, (pct >= 0 and "+" or "") .. Dec(pct))
    else
        tip[#tip + 1] = GREY .. L.QUICK_QTY_ROW_WAIT .. "|r"
    end
    if lv.rows.partial then tip[#tip + 1] = GREY .. L.QUICK_QTY_ROW_PART .. "|r" end
    return text, tip
end

function F.UpdateQuickMove(v)
    if not F.marketRows then return end
    local vals, tips, code = F.QuickMoveValues(v)
    for i, r in ipairs(F.marketRows) do
        local kind = F.MarketRowKind(i)
        r.label:SetText(L[F.MARKET_LABEL[kind]] or "")
        local text, tip = F.MarketRowValue(kind, v, vals, tips, code)
        r.value:SetText(text or "")
        r.tip = tip
        r.bg:Hide()
    end
end

-- Diagramm im Schnellkauf: guenstigster Preis, Menge unter Kaufen bis, eigene Lockangebote
-- ab 0.143: Menge unter dem geltenden Limit (Kaufart), Linie Limit nur mit Haken (Standard), gestrichelt der Wert von
-- Gleitend (ohne Haken grau zur Orientierung)
function F.UpdateQuickChart(limit)
    local Q = ns.Quick
    local rows = F.LiveRows()
    local eff, kind = Q.EffectiveLimit(F.key, rows)
    -- ab 0.168: die Linie Limit zeigt das geltende Limit (fest oder gleitend), gestrichelt der Ausloeser, wenn er ein
    -- Band bildet (Linie Ausloeser, bis 0.167 Gleitend)
    local std = (kind ~= "normal" and Num(eff)) and eff or nil
    local glide = Num(std) and Q.TriggerValue(F.key, std) or nil
    if Num(glide) and glide >= std then glide = nil end
    limit = Num(eff) and eff or nil
    if AHOpen() and F.key ~= nil then
        F.mHead:SetText(L.QUICK_CHART_HEAD:format(Dec(ns.Radar.FocusEvery())))
    else
        F.mHead:SetText(GREY .. L.MEASURE_NONE .. "|r")
    end
    -- ab 0.134 (U2): Zeitraum 5, 15 oder 60 Minuten aus dem eigenen Verlauf (Quick.ChartSeries), vorher die letzten
    -- Abfragen der Messung (Quick.Series, knapp 3 Min.)
    local key, minutes, h = F.key, F.ChartRange(), Q.hist[F.key]
    local show = F.chart ~= nil and AHOpen() and h ~= nil and h.n >= 2
    if F.chart and F.chart.frame then F.chart.frame:SetShown(show) end
    F.chartLegend:SetShown(false)
    if F.chartLines then F.chartLines.frame:SetShown(F.chart ~= nil) end
    if not show then F.chartN = nil; return end
    local stamp = "q:" .. tostring(key) .. ":" .. h.n .. ":" .. tostring(limit) .. ":" .. minutes .. ":" .. #(Q.baits[key] or {}) .. ":" .. tostring(glide) .. ":" .. tostring(std)
        .. ":" .. tostring(mod.db.quickChartPad) .. ":" .. tostring(kind)
    if F.chartN == stamp then return end
    local n, under, mins, own, other, dips = Q.ChartSeries(key, limit, minutes)
    if not n then F.chartN = nil; return end
    local C = F.CHART_COLORS
    local series = {
        { key = "baits", kind = "marks", values = other, color = C.baitsOther },
        { key = "baits", kind = "marks", values = own, color = C.baits, label = L.CHART_L_BAITS },
        { key = "under", kind = "bar", axis = "right", values = under, color = C.under },
        { key = "min", kind = "line", values = mins, color = C.min, width = 2, connect = true },
    }
    -- ab 0.131: der Preis bestimmt die Aufloesung. Kaufen bis weit unter dem Preis stauchte die Linie, jetzt steht es
    -- dann gestrichelt am unteren Rand (Kern API 28, fit = false).
    if Num(std) and std > 0 then series[#series + 1] = { key = "limit", kind = "hline", value = std, color = C.limit, fit = false } end
    -- ab 0.140 Vorschlag, ab 0.143 Gleitend als graue gestrichelte Linie (bestimmt die Achse nicht mit)
    if Num(glide) then series[#series + 1] = { key = "suggest", kind = "hline", value = glide, color = C.limit, dash = 4, fit = false } end
    -- ab 0.167 (Board KarloDerBaer 27.11.2026): fester Bereich mit Preislinie, Limit und (wenn an) Gleitend, dazu etwas
    -- Luft (F.AxisRange). Bisher klebte die Linie am Rand und das Limit stand oft gestrichelt unten.
    local lo, hi
    local function Add(v) if Num(v) and v > 0 then lo = (lo == nil or v < lo) and v or lo; hi = (hi == nil or v > hi) and v or hi end end
    for i = 1, n do Add(mins[i]) end
    Add(std)
    Add(glide)
    local a, b = F.AxisRange(lo, hi, tonumber(mod.db.quickChartPad) or 10)
    if F.chart.SetRange then F.chart:SetRange("left", a, b) end
    ns.Radar.Perf("diagramm", function() F.chart:SetData(n, series); F.chart:Draw() end)
    F.chartN = stamp
end

-- Text und Zustand des Kaufknopfs
-- ab 0.78: Zeile "Menge, Kosten, Gewinn" immer zeigen, auch wenn der Knopf gesperrt ist (KarloDerBaer 12.11.2026).
-- Ohne Werte stehen Striche da. Waehrend eines Kaufs steht dort der Stand des Kaufs.
function F.Summary(d)
    local qty, cost, gain
    if d then
        local best = d.best or {}
        qty = Num(best.qty) and best.qty > 0 and best.qty or (Num(d.qty) and d.qty or nil)
        cost = Num(best.cost) and best.cost or (Num(d.cost) and d.cost or nil)
        gain = Num(best.gain) and best.gain or (Num(d.gain) and d.gain or nil)
    end
    return L.FOCUS_SUMMARY_S:format(qty and tostring(qty) or "-", cost and Money(cost) or "-",
        gain and ns.Radar.SignedMoney(math.floor(gain + 0.5)) or "-")
end

local function BuyState(d)
    local R = ns.Radar
    local job = R.job
    local here = job and d and job.key == d.key
    if here then
        local info = ""
        if job.stage == "confirm" then
            info = L.FOCUS_CONFIRM:format(job.qty or 0, Money(job.total or 0))
            if job.warn then info = ORANGE .. L.FOCUS_PRICE_WARN:format(Money(job.total or 0), Money(job.expect or 0)) .. "|r" end
        elseif job.items then info = L.FOCUS_BOUGHT:format(job.done or 0, job.qty or 0, Money(job.cost or 0)) end
        if info == "" then info = F.Summary(d) end
        F.jobInfo = info   -- ab 0.133: im Schnellkauf unter dem Kaufknopf
        return R.JobText(job), job.stage == "confirm" or job.stage == "next", info
    end
    F.jobInfo = nil
    local quick = ns.Quick and ns.Quick.On()
    local info = quick and ns.Quick.Summary(d) or F.Summary(d)
    -- ab 0.167: Fehlschlag kurz auf dem Knopf, der Knopf bleibt frei, wenn es etwas zu kaufen gibt
    local fail = R.FailText((d and d.key) or F.key)
    if fail then
        local can = AHOpen() and d and not d.gone and (d.best and d.best.qty or 0) >= 1 and not d.cant and job == nil
        return ORANGE .. fail .. "|r", can and true or false, info
    end
    if not d or d.gone then return L.BUY_BUY, false, info end
    local qty = d.best and d.best.qty or 0
    -- ab 0.133 (U1, Konzept 4.1): im Schnellkauf steht auf dem Knopf, was ein Klick hoechstens kostet
    local buyText = quick and ns.Quick.BuyLabel(d) or L.FOCUS_BUY:format(qty)
    if not AHOpen() then return buyText, false, info end
    if R.IsStale(d.key or F.key) then return L.FOCUS_CHECKING, false, info end   -- ab 0.104
    -- ab 0.114 hiess es nach der Pause "Prueft ..." bis zur naechsten Antwort, ab 0.167 bleibt der Knopf frei
    -- ab 0.70: mit eigenem Ziel geht Kaufen auch ohne Gewinn (eigene Entscheidung), nur nicht ohne Menge oder Gold
    if qty < 1 or d.cant then return L.BUY_BUY, false, info end
    return buyText, job == nil, info
end

function F.Update()
    if not F.tiers then return end
    F.UpdateStar()   -- ab 0.152
    F.UpdateBack()
    local key = F.key
    local has = key ~= nil
    local live = AHOpen()
    if has and ns.Quick.On() then F.EnsureLoaded() end   -- ab 0.131: erst die gespeicherten Werte, dann Vorgaben
    if has and live and ns.Quick.On() then   -- ab 0.170/0.171: Vorgaben im Limitkauf, Startwert fuer Fest
        if ns.Quick.Tab(key) == "limit" then ns.Quick.EnsureDefaults(key) end
        ns.Quick.EnsureFixStart(key)
    end
    if has and live and ns.Quick.On() then
        -- ab 0.143 ohne Vorgabe fuer Kaufen bis (Q.EnsureLimit ruht): ohne Haken kauft Broker normal
        -- ab 0.133 ohne Limit pro Kauf (Q.EnsureGold): die Goldreserve begrenzt jeden Kauf
    end
    On(F.autoButton, has and live and (F.ManualTarget(key) ~= nil or F.ManualLimit(key) ~= nil))
    if not has then
        F.header:Set(nil, "", 1)
        if F.relistCheck then F.relistCheck:Hide() end
        F.verdict:SetText("")
        F.why:SetText(GREY .. L.FOCUS_EMPTY .. "|r")
        for _, r in ipairs(F.rows) do r.label:SetText(""); r.value:SetText("") end
        F.kindValue:SetText("")
        F.SyncInputs(nil)
        F.SyncQty(nil)
        F.tiers:SetData({})
        F.stand:SetText("")
        F.UpdateMeasure(nil)
        F.buyButton:SetText(L.BUY_BUY); F.buyButton:Disable(); F.buyInfo:SetText(F.Summary(nil))
        if F.quick then
            F.quick.state:SetText(""); F.quick.balance:SetText(""); F.quick.post:Disable()
            for _, r in ipairs(F.marketRows or {}) do r.value:SetText(""); r.tip = nil; r.bg:Hide() end   -- ab 0.140
            F.quick.maxValue:SetText(""); F.quick.unitValue:SetText("")
            F.UpdateStats()
            F.quick.lastBuy:SetText("")
        end
        return
    end
    local D = ns.Data
    local e = D.Lookup(key)
    local d = live and F.Plan() or nil
    if not d and live then d = ns.Radar.gone[key] end
    local id = D.ItemID(key)
    local name = (d and d.name) or D.ItemName(key, e) or L.ITEM_UNKNOWN:format(id or 0)
    local quality = (d and d.quality) or (type(e) == "table" and e.ql) or nil
    F.header:Set(ns.Buy.Icon(id), name, quality)
    if F.relistCheck and ns.Lots then F.relistCheck:SetChecked(ns.Lots.Wanted(key)); F.relistCheck:SetShown(not ns.Quick.On()) end   -- ab 0.106 nur Aufkauf
    local Q = ns.Quick
    local quick = Q.On()
    local liveRows, liveT = F.LiveRows()
    if quick and liveRows then
        Q.NoteTiers(key, liveRows)
        Q.CheckBait(key, liveRows, liveT)
    end
    local text, color, why = F.Verdict(d)
    F.verdict:SetText(color .. text .. "|r")
    F.why:SetText(why or "")
    F.kindValue:SetText(live and F.KindText(d) or "")
    F.SyncInputs(live and d or nil)
    local rows = live and F.Rows(d) or {}
    for i, r in ipairs(F.rows) do
        r.label:SetText(rows[i] and rows[i][1] or "")
        r.value:SetText(rows[i] and rows[i][2] or "")
        r.tip = rows[i] and rows[i].tip or nil
    end
    -- Preisstufen nur aus der letzten Live-Abfrage (ab 0.70)
    local limit = d and not d.gone and d.limit or nil
    -- ab 0.99: blau nur, was der Kauf mit der festen Menge nimmt
    F.tiers:SetData(F.Tiers(d and not d.gone and d.buyLimit or limit, d and not d.gone and d.ref or nil))
    F.SyncQty(live and d or nil)
    local _, t = F.LiveRows()
    if not live then F.stand:SetText(GREY .. L.TAB_AH_ONLY .. "|r")
    elseif t then F.stand:SetText(L.FOCUS_LIVE:format(ns.Scan.Age(t)))
    else F.stand:SetText(GREY .. L.FOCUS_LIVE_WAIT .. "|r") end
    F.UpdateMeasure(F.LiveValues(), limit)
    local label, enabled, info = BuyState(d)
    F.buyButton:SetText(label)
    On(F.buyButton, enabled)
    F.buyInfo:SetText(info)
    if quick then
        F.UpdateQuick(d, live)
        -- ab 0.143: Alarm, Gelegenheiten und Pause nur mit Limit oder Gleitend (im normalen Einkauf gibt es immer etwas)
        local alarmQty = (live and d and not d.gone and Q.BuyKind(key) ~= "normal" and (d.maxQty or d.qty)) or 0
        Q.CheckAlarm(key, liveRows, alarmQty, F.buyButton)
    end
end

-- Gegenstand in den Fokus nehmen (ersetzt den bisherigen)
function F.Set(key)
    if key == nil then return end
    if key ~= F.key then
        if F.key ~= nil then F.AutoSave() end   -- ab 0.113: Werte des bisherigen Gegenstands
        F.manual, F.manualLimit, F.manualSrc, F.manualQty, F.manualGold = nil, nil, nil, nil, nil
        F.loaded = nil   -- ab 0.131
        ClearMoney(F.limitInput)
        F.since = time()
        F.chartN = nil
        F.ClearInput()
        if ns.Quick then ns.Quick.OnNewKey() end   -- ab 0.104
    end
    local changed = F.key ~= key
    F.key = key
    mod.acc.focusKey = key
    if AHOpen() and F.Shown() then ns.Radar.SetFocus(key) end
    F.Update()
    if changed and ns.Side then ns.Side.Refresh() end   -- ab 0.137 (U5): Hervorhebung in der Seitenleiste
end

-- Seite geoeffnet: am Auktionator den Gegenstand abfragen
function F.Open()
    if F.key == nil then F.key = mod.acc.focusKey end
    if F.key ~= nil and AHOpen() then
        ns.Radar.LoadIfStale()
        ns.Radar.SetFocus(F.key)
    end
    F.Update()
end

W.pages.focus = {
    build = F.Build,
    refresh = function() F.Open() end,
    leave = function() F.AutoSave(); ns.Radar.Halt(); if ns.Settings then ns.Settings.Hide("focus") end end,   -- ab 0.113 AutoSave
}
