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
F.origin = "watch"    -- ab 0.82: wohin "Zurueck" fuehrt: "chances" (ab 0.105 auch statt Radar) oder "watch" (sonst)
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

-- "Kaufen bis" setzen (Rechtsklick auf eine Preisstufe), price = nil: wieder alles unter dem Ziel
function F.SetLimit(price)
    if F.key == nil then return end
    F.manualSrc = "own"
    if Num(price) and price > 0 then F.manualLimit = { key = F.key, price = math.floor(price) } else F.manualLimit = nil end
    if ns.Quick then ns.Quick.NoteLimit(F.key, F.manualLimit) end   -- ab 0.107.1: selbst geleert merken
    if F.limitInput then
        if F.manualLimit then F.limitInput:SetAmount(F.manualLimit.price) else ClearMoney(F.limitInput) end
    end
    F.Update()
end

-- Getipptes "Kaufen bis" (0 = leer)
function F.SetLimitTyped(amount)
    if F.key == nil then return end
    F.manualSrc = "own"
    if Num(amount) and amount > 0 then F.manualLimit = { key = F.key, price = math.floor(amount) } else F.manualLimit = nil end
    if ns.Quick then ns.Quick.NoteLimit(F.key, F.manualLimit) end   -- ab 0.107.1: selbst geleert merken
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

-- Getippte Menge (leer oder 0 = alle)
function F.SetQtyTyped(n)
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
    F.origin = (from == "radar" or from == "chances") and "chances" or "watch"
    -- ab 0.106: aus Chancen immer Aufkauf, aus Beobachten der dort gespeicherte Modus
    -- ab 0.119: want = Modus der Liste, aus der man kommt (Unterreiter Schnellkauf in Chancen und Beobachten)
    local Wt = ns.Watch
    local mode = (want == "quick" or want == "buyout") and want
        or F.origin == "chances" and "buyout" or (Wt and Wt.Is(key) and Wt.Mode(key)) or nil
    if mode and ns.Quick then ns.Quick.SetMode(mode, true) end
    if F.origin == "watch" then F.LoadWatch(key) end
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
        local ql, qg = F.ManualLimit(key), F.ManualGold(key)
        Wt.SetQuick(key, ql, qg, ns.Quick.SkipOn(key), ns.Quick.AvgOn(key))
        if ql then F.manualSrc = "watch" end
        if not quiet then mod:Print(L.FOCUS_SAVED_QUICK:format(name, Num(ql) and Money(ql) or "-", qg and Money(qg) or L.QUICK_NO_CAP)) end
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
    if not quick and mod.db.autoSaveBuyout == false then return false end
    return F.Save(true)
end

-- Knopf "Zurueck zu ..." unten im Fokus
function F.UpdateBack()
    if not F.backButton then return end
    local label = F.origin == "chances" and L.TAB_CHANCES or L.NTAB_WATCH
    F.backButton:SetText(L.FOCUS_BACK:format(label))
end

function F.GoBack()
    ns.Window.Open(F.origin == "chances" and "chances" or "watch")
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
    if ns.Quick and ns.Quick.On() then return F.SyncQuickQty(d) end   -- ab 0.106: Max. Menge
    local has = d ~= nil and not d.gone and F.key ~= nil
    for _, f in ipairs({ F.qtyLabel, F.qtySlider, F.qtyInput, F.qtyHint }) do f:SetShown(has) end
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

-- ab 0.106: Max. Menge im Schnellkauf, ab 0.112 Max. Gold (Wunsch KarloDerBaer): Goldfeld, leer = ohne Grenze.
-- Dahinter, wie viele Stueck zu Kaufen bis mindestens hineinpassen.
function F.SyncQuickQty()
    local has = F.key ~= nil
    F.qtySlider:Hide()
    F.qtyInput:Hide()
    if F.qtyAll then F.qtyAll:Hide() end
    for _, f in ipairs({ F.qtyLabel, F.goldInput, F.qtyHint }) do f:SetShown(has) end
    local gold = has and F.ManualGold(F.key) or nil
    if not Typing(F.goldInput) then
        if gold then F.goldInput:SetAmount(gold) else ClearMoney(F.goldInput) end
    end
    local limit = has and F.ManualLimit(F.key) or nil
    if not has then F.qtyHint:SetText("")
    elseif gold and limit and limit > 0 then F.qtyHint:SetText(GREY .. L.QUICK_GOLD_QTY:format(math.floor(gold / limit)) .. "|r")
    elseif gold then F.qtyHint:SetText("")
    else F.qtyHint:SetText(GREY .. L.QUICK_NO_CAP .. "|r") end
end

-- Ueblicher Bereich als Text ("1s 20c bis 1s 60c", sonst "unbekannt")
function F.BandText(d)
    local band = d and d.band
    if not band and F.key ~= nil then band = ns.Buyout.Context(nil, F.key).band end
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
    F.sectionTab = UI.SectionTab(left, L.FOCUS_HEAD_CHANCE)
    F.header = UI.ItemHeader(left)
    F.header:SetPoint("TOPLEFT", 10, -10)
    F.header:SetScript("OnEnter", function(self) if F.key ~= nil then W.ShowItemTooltip(self, F.key) end end)
    F.header:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
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
    UI.SetTooltip(F.qtySlider, { L.FOCUS_R_QTY, L.FOCUS_QTY_TIP })
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
    F.qtyAll = UI.Text(left, "small", GREY .. L.FOCUS_QTY_ALL .. "|r")
    F.qtyAll:SetPoint("LEFT", F.qtyInput, "LEFT", 10 * 0.8, 0)
    F.qtyAll:Hide()
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
    local half = math.floor((UI.LEFT_W - 26) / 2)
    F.marketButton = ns.Go.MarketButton(left, half, function() return F.key ~= nil and { key = F.key } or nil end)   -- ab 0.73 sicher
    F.marketButton:SetPoint("BOTTOMLEFT", 10, 40)
    F.itemButton = UI.Button(left, L.NTAB_ITEM, half, function()
        if F.key ~= nil then mod:Call("Sprung", ns.Go.Item, { key = F.key }) end
    end)
    F.itemButton:SetPoint("LEFT", F.marketButton, "RIGHT", 6, 0)
    -- ab 0.82: Zurueck (Radar oder Beobachten) und Speichern (in die Beobachtung)
    F.backButton = UI.Button(left, L.FOCUS_BACK:format(L.NTAB_WATCH), half, function() mod:Call("Sprung", F.GoBack) end)
    F.backButton:SetPoint("BOTTOMLEFT", 10, 10)
    F.saveButton = UI.Button(left, L.FOCUS_SAVE, half, function() mod:Call("Beobachtung", F.Save) end)
    F.saveButton:SetPoint("LEFT", F.backButton, "RIGHT", 6, 0)
    UI.SetTooltip(F.saveButton, { L.FOCUS_SAVE, L.FOCUS_SAVE_TIP })
    F.UpdateBack()

    -- rechts: der Markt in diesem Moment. Oben die Preisstufen, darunter ab 0.66 (H2) Messung und Diagramm
    local right = UI.Panel(c, "list", true)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", UI.GAP, -30)
    right:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    right:SetHeight(F.TIER_H)
    F.stand = UI.Text(c, "text", "")
    F.stand:SetPoint("BOTTOMLEFT", right, "TOPLEFT", 8, 8)
    F.settingsButton = UI.Button(c, L.SETTINGS_BUTTON, 110, function()
        if ns.Settings then mod:Call("Einstellungen", ns.Settings.Toggle, "focus", c) end
    end)
    F.settingsButton:SetPoint("BOTTOMRIGHT", right, "TOPRIGHT", -2, 4)
    -- ab 0.104: Umschalter Aufkauf / Schnellkauf
    F.modeQuick = UI.Button(c, L.FOCUS_MODE_QUICK, 100, function() mod:Call("Schnellkauf", ns.Quick.SetMode, "quick") end)
    F.modeQuick:SetPoint("RIGHT", F.settingsButton, "LEFT", -12, 0)
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
            if ns.Quick and ns.Quick.On() then return end   -- ab 0.116: im Schnellkauf aendert ein Klick nichts
            if button == "RightButton" then F.SetTarget(item.price) else F.SetLimit(item.price) end
        end,
    })
    F.BuildMeasure(c, right)
    F.BuildQuick(left, Label)

    if F.key == nil then F.key = mod.acc.focusKey end
    F.ApplyMode()
    F.Update()
end

F.TIER_H = 152     -- Hoehe der Preisstufen (Kopf und 6 Zeilen)
F.MEASURE_ROWS = { "MEASURE_OUT", "MEASURE_IN", "MEASURE_UNDER", "MEASURE_MIN" }
F.QUICK_ROWS = { "QUICK_MV_IN", "QUICK_MV_OUT", "QUICK_MV_MOVE", "QUICK_MV_BAITS_L", "QUICK_MV_LAST", "QUICK_MV_BOUGHT_L", "QS_LABEL" }   -- ab 0.108: Marktbewegung, ab 0.109 fuenf Zeilen, ab 0.122 Langfristig
F.ROW_H = 15       -- ab 0.122: sieben Zeilen (vorher 17)

local function AxisMoney(v)
    if not Num(v) then return "" end
    if v >= 10000 then return math.floor(v / 10000 + 0.5) .. "g" end
    if v >= 100 then return math.floor(v / 100 + 0.5) .. "s" end
    return math.floor(v + 0.5) .. "c"
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
        F.chart = Peon.NewChart(mp, { width = cw - 12, height = 104, left = 46, right = 40, top = 6, bottom = 6, grid = 2,
            leftFormat = AxisMoney, rightFormat = function(v) return Num(v) and Peon.ShortNumber and Peon.ShortNumber(v) or "" end })
        if F.chart and F.chart.frame then F.chart.frame:SetPoint("BOTTOMLEFT", mp, "BOTTOMLEFT", 6, 6) end
        -- ab 0.75: nichts zeichnet ueber den Rand des Diagramms hinaus
        if F.chart and F.chart.plot and F.chart.plot.SetClipsChildren then F.chart.plot:SetClipsChildren(true) end
    end
    -- ab 0.91: Menge grau, Kaufen bis blau (Wunsch KarloDerBaer, 13.11.2026)
    F.chartLegend = UI.Text(mp, "small", ("|cff999999%s|r  |cffffd133%s|r  |cff4d8cff%s|r  |cff60e060%s|r"):format(L.MEASURE_UNDER, L.MEASURE_MIN, L.FOCUS_R_LIMIT, L.FOCUS_R_TARGET))
    F.chartLegend:SetPoint("BOTTOMRIGHT", mp, "BOTTOMRIGHT", -10, 114)
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
    ns.Radar.Perf("diagramm", function() F.chart:SetData(math.max(n, F.CHART_SLOTS or 60), series); F.chart:Draw() end)
    F.chartN = stamp   -- erst nach dem Zeichnen: bricht es ab, versucht es die naechste Antwort neu
end

-- Kaufknopf und Taste "Kaufen" (ab 0.104 beide hier): kauft, was der Knopf zeigt
function F.Buy()
    if ns.Quick and ns.Quick.Locked(F.key) then return end   -- ab 0.114: erst die neue Antwort abwarten
    local d = F.Plan()
    if d then mod:Call("Radar", ns.Radar.BuyStep, d, "best") end
end

---------------------------------------------------------------------------
-- Modus Schnellkauf (ab 0.104, Quick.lua): Block Lockangebot unter Kaufen bis und Menge, eigenes Diagramm
---------------------------------------------------------------------------
-- ab 0.106 ohne Urteil und Satz darunter, alles rueckt nach oben
-- ab 0.109 Haken "Lockangebot ignorieren" unter Max. Menge, der Block Lockangebot rueckt 16 nach unten.
-- ab 0.110 Linien ueber und unter dem Block Lockangebot, Beschriftungen links buendig ab F.QUICK_X
F.QUICK_LIMIT_Y, F.QUICK_QTY_Y, F.QUICK_HEAD_Y, F.QUICK_PRICE_Y, F.QUICK_BTN_Y, F.QUICK_STATE_Y, F.QUICK_BAL_Y =
    -100, -130, -190, -212, -238, -266, -282
F.QUICK_SKIP_Y, F.QUICK_LINE1_Y, F.QUICK_LINE2_Y, F.QUICK_X = -152, -180, -294, 16   -- ab 0.114 Linie hoeher (ohne Zeile Sitzung)
F.QUICK_FIELD_X = 93   -- ab 0.112.1: Felder im Schnellkauf so weit rechts von der Beschriftung (wie bisher 8 + 93 - 8)
F.QUICK_AVG_X = 186   -- ab 0.112: Haken "Durchschnitt zaehlt"
function F.BuildQuick(left, Label)
    local UI = Peon.UI
    local Q = ns.Quick
    local q = {}
    F.quick = q
    q.head = UI.Text(left, "label", YELLOW .. L.QUICK_HEAD .. "|r")
    q.head:SetPoint("TOPLEFT", F.QUICK_X, F.QUICK_HEAD_Y)
    q.priceLabel = Label(L.QUICK_PRICE, F.QUICK_PRICE_Y)
    q.priceLabel:SetJustifyH("LEFT")
    q.priceLabel:SetWidth(0)   -- ab 0.112.1 eigene Breite, das Feld haengt an fester Stelle
    q.priceLabel:ClearAllPoints()
    q.priceLabel:SetPoint("TOPLEFT", F.QUICK_X, F.QUICK_PRICE_Y)
    q.line1 = UI.Divider(left, UI.LEFT_W - 24)
    q.line1:SetPoint("TOPLEFT", 12, F.QUICK_LINE1_Y)
    q.line2 = UI.Divider(left, UI.LEFT_W - 24)
    q.line2:SetPoint("TOPLEFT", 12, F.QUICK_LINE2_Y)
    q.priceInput = UI.MoneyInput(left, function(amount) Q.SetPriceTyped(amount) end)
    if q.priceInput.SetScale then q.priceInput:SetScale(0.8) end
    q.priceInput:SetPoint("LEFT", q.priceLabel, "LEFT", F.QUICK_FIELD_X / 0.8, 0)
    q.priceHint = UI.Text(left, "small", "")
    q.priceHint:SetPoint("LEFT", q.priceInput, "RIGHT", 4, 0)
    local half = math.floor((UI.LEFT_W - 26) / 2)
    -- ab 0.110 "Lockangebot einstellen" (vorher "1 einstellen"): dieser Knopf breiter
    local cw = 110
    q.post = UI.Button(left, L.QUICK_POST, 2 * half - cw, function() mod:Call("Schnellkauf", Q.Post) end)
    q.post:SetPoint("TOPLEFT", 10, F.QUICK_BTN_Y)
    UI.SetTooltip(q.post, { L.QUICK_POST, L.QUICK_POST_TIP })
    q.cancel = UI.Button(left, L.QUICK_CANCEL, cw, function() mod:Call("Schnellkauf", Q.Cancel) end)
    q.cancel:SetPoint("LEFT", q.post, "RIGHT", 6, 0)
    UI.SetTooltip(q.cancel, { L.QUICK_CANCEL, L.QUICK_CANCEL_TIP })
    q.state = UI.Text(left, "text", "", UI.LEFT_W - 32)
    q.state:SetPoint("TOPLEFT", 16, F.QUICK_STATE_Y)
    q.balance = UI.Text(left, "small", "", UI.LEFT_W - 32)
    q.balance:SetPoint("TOPLEFT", 16, F.QUICK_BAL_Y)
    q.skip = UI.Check(left, L.QUICK_SKIP, false, function(on) mod:Call("Schnellkauf", Q.SetSkip, on) end, { L.QUICK_SKIP, L.QUICK_SKIP_TIP })
    if q.skip.SetScale then q.skip:SetScale(0.85) end
    q.skip:SetPoint("TOPLEFT", 10 / 0.85, F.QUICK_SKIP_Y / 0.85)
    -- ab 0.112: Haken "Durchschnitt zaehlt" rechts daneben
    q.avg = UI.Check(left, L.QUICK_AVG, false, function(on) mod:Call("Schnellkauf", Q.SetAvg, on) end, { L.QUICK_AVG, L.QUICK_AVG_TIP })
    if q.avg.SetScale then q.avg:SetScale(0.85) end
    q.avg:SetPoint("TOPLEFT", F.QUICK_AVG_X / 0.85, F.QUICK_SKIP_Y / 0.85)
    q.balance:Hide()   -- ab 0.114 nicht mehr gezeigt (Wunsch KarloDerBaer): die Bilanz steht in der Zeile "Gekauft"
    -- ab 0.121: Knopf Auto hinter Kaufen bis (Q.AutoLimit), grau ohne erkanntes fremdes Lockangebot
    q.auto = UI.Button(left, L.QUICK_AUTO, 50, function()
        local v = Q.AutoLimit(F.key)
        if v then F.SetLimit(v) end
    end)
    q.auto:SetPoint("LEFT", F.limitInput, "RIGHT", 6, 0)
    UI.SetTooltip(q.auto, function()
        local v, bait, reg = Q.AutoLimit(F.key)
        if not v then return { L.QUICK_AUTO, L.QUICK_AUTO_TIP, GREY .. L.QUICK_AUTO_NONE .. "|r" } end
        return { L.QUICK_AUTO, L.QUICK_AUTO_TIP, L.QUICK_AUTO_VALUES:format(Money(bait), Money(reg), Money(v)) }
    end)
    q.all = { q.head, q.priceLabel, q.priceInput, q.priceHint, q.post, q.cancel, q.state, q.skip, q.line1, q.line2, q.avg, q.auto }
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
    F.qtyLabel:SetText(quick and L.QUICK_MAXGOLD or L.FOCUS_R_QTY)
    -- ab 0.112: im Schnellkauf Goldfeld statt Mengenfeld, der Hinweis steht dahinter
    if F.goldInput then
        F.goldInput:SetShown(quick)
        F.qtyInput:SetShown(not quick)
        F.qtyHint:ClearAllPoints()
        F.qtyHint:SetPoint("LEFT", quick and F.goldInput or F.qtyInput, "RIGHT", 4, 0)
    end
    F.qtySlider:SetShown(not quick)
    if F.qtyAll and not quick then F.qtyAll:Hide() end
    F.qtySlider.peonMin = nil   -- Regler beim naechsten Mal neu setzen
    -- ab 0.107: im Schnellkauf steht das Feld buendig unter dem Goldfeld von Kaufen bis (Platz fuer den Text dahinter)
    F.qtyInput:ClearAllPoints()
    if quick then F.qtyInput:SetPoint("LEFT", F.qtyLabel, "RIGHT", 8 / 0.8, 0)
    else F.qtyInput:SetPoint("LEFT", F.qtySlider, "RIGHT", 6 / 0.8, 0) end
    -- ab 0.110 auch die Mausbereiche: sie lagen im Schnellkauf unsichtbar ueber dem Knopf Lockangebot einstellen
    for _, r in ipairs(F.rows) do r.label:SetShown(not quick); r.value:SetShown(not quick); if r.hover then r.hover:SetShown(not quick) end end
    -- ab 0.108: im Schnellkauf stehen hier Zufluss, Abfluss, Bewegung und die Nachwirkung des Lockangebots
    for i, r in ipairs(F.mRows or {}) do r.label:SetText(L[(quick and F.QUICK_ROWS or F.MEASURE_ROWS)[i]] or ""); r.value:SetText(""); r.tip = nil end
    for _, f in ipairs(F.quick and F.quick.all or {}) do f:SetShown(quick) end
    MoveLabel(F.limitLabel, quick and F.QUICK_LIMIT_Y or F.LIMIT_Y, quick and F.QUICK_X or nil)
    MoveLabel(F.qtyLabel, quick and F.QUICK_QTY_Y or F.QTY_Y, quick and F.QUICK_X or nil)
    -- ab 0.110: im Schnellkauf alle Beschriftungen links buendig
    F.limitLabel:SetJustifyH(quick and "LEFT" or "RIGHT")
    F.qtyLabel:SetJustifyH(quick and "LEFT" or "RIGHT")
    -- ab 0.112.1: "Limit pro Kauf" stand im Spiel trotzdem rechtsbuendig. Im Schnellkauf haben die Beschriftungen
    -- deshalb keine feste Breite mehr, die Felder haengen an einer festen Stelle (F.QUICK_FIELD_X ab der Beschriftung).
    local W = Peon.UI.LABEL_W
    local fx = F.QUICK_FIELD_X / 0.8
    F.limitLabel:SetWidth(quick and 0 or W)
    F.qtyLabel:SetWidth(quick and 0 or W)
    F.limitInput:ClearAllPoints()
    if quick then F.limitInput:SetPoint("LEFT", F.limitLabel, "LEFT", fx, 0)
    else F.limitInput:SetPoint("LEFT", F.limitLabel, "RIGHT", 8 / 0.8, 0) end
    if F.goldInput then
        F.goldInput:ClearAllPoints()
        F.goldInput:SetPoint("LEFT", F.qtyLabel, "LEFT", fx, 0)
    end
    if F.sectionTab and F.sectionTab.SetText then F.sectionTab:SetText(quick and L.FOCUS_MODE_QUICK or L.FOCUS_HEAD_CHANCE) end
    if F.modeQuick.LockHighlight then
        if quick then F.modeQuick:LockHighlight(); F.modeBuyout:UnlockHighlight()
        else F.modeBuyout:LockHighlight(); F.modeQuick:UnlockHighlight() end
    end
    if quick then
        F.chartLegend:SetText(("|cff999999%s|r  |cffffd133%s|r  |cff4d8cff%s|r  |cffb366ff%s|r"):format(L.QUICK_LEG_UNDER, L.MEASURE_MIN, L.FOCUS_R_LIMIT, L.QUICK_LEG_BAIT))
    else
        F.chartLegend:SetText(("|cff999999%s|r  |cffffd133%s|r  |cff4d8cff%s|r  |cff60e060%s|r"):format(L.MEASURE_UNDER, L.MEASURE_MIN, L.FOCUS_R_LIMIT, L.FOCUS_R_TARGET))
        if F.buyButton.UnlockHighlight then F.buyButton:UnlockHighlight() end
    end
end

-- Block Lockangebot fuellen
function F.UpdateQuick(d, live)
    local q = F.quick
    if not q then return end
    local Q = ns.Quick
    local key = F.key
    local suggest, base = Q.Suggest()
    local m = q.priceInput
    if not Typing(m) then
        local v = Q.ManualPrice(key) or suggest
        if Num(v) and v > 0 then m:SetAmount(v) else ClearMoney(m) end
    end
    if Q.ManualPrice(key) then q.priceHint:SetText(GREY .. L.QUICK_PRICE_OWN .. "|r")
    elseif Num(base) then q.priceHint:SetText(GREY .. L.QUICK_PRICE_HINT:format(tonumber(mod.db.quickBaitPct) or 50) .. "|r")
    else q.priceHint:SetText("") end
    local b = Q.BaitFor(key)
    local busy = b ~= nil and (b.state == "posting" or b.state == "cancelling")
    local canPost = live and key ~= nil and ns.Data.IsCommodity(key) and Num(Q.Price(key)) and not busy
    q.post:SetText((b and b.state == "confirm") and L.QUICK_CONFIRM or L.QUICK_POST)
    On(q.post, canPost and true or false)
    On(q.cancel, live and b ~= nil and b.state == "up" and b.id ~= nil)
    On(q.auto, live and key ~= nil and Q.AutoLimit(key) ~= nil)
    if key ~= nil and not ns.Data.IsCommodity(key) then q.state:SetText(GREY .. L.QUICK_ONLY_MASS .. "|r")
    else q.state:SetText(Q.StateText(key)) end
    q.balance:SetText(Q.BalanceText(key))
    if q.skip.SetChecked then q.skip:SetChecked(Q.SkipOn(key)) end
    if q.avg.SetChecked then q.avg:SetChecked(Q.AvgOn(key)) end
end

-- Zeilen ueber dem Diagramm im Schnellkauf (ab 0.108): Zufluss, Abfluss, Bewegung, Nachwirkung des Lockangebots
function F.UpdateQuickMove(v)
    if not F.mRows then return end
    local Q, M = ns.Quick, ns.Measure
    local db = mod.db
    local vals, tips = { "", "", "", "", "", "", "" }, {}
    local win = math.floor(M.WINDOW / 60 + 0.5)
    -- ab 0.110 kurz, Einzelheiten im Tooltip (Wunsch KarloDerBaer: nicht ueber den Rand)
    local function R(x) x = x or 0; if x >= 10 then return tostring(math.floor(x + 0.5)) end return Dec(x) end
    local code, ev = Q.Movement(v)
    if code == "first" then
        if v or (AHOpen() and F.key ~= nil) then vals[3] = GREY .. L.QUICK_MV_FIRST:format(M.FIRST) .. "|r" end
    else
        vals[1] = L.QUICK_MV_RATE:format(R(v.inAll), R(v.newPerMin))
        tips[1] = { L.QUICK_MV_TIP_IN:format(R(v.inAll), R(v.newPerMin), win) }
        vals[2] = L.QUICK_MV_RATE:format(R(v.out), R(v.soldPerMin))
        tips[2] = { L.QUICK_MV_TIP_OUT:format(R(v.out), R(v.soldPerMin), win) }
        local color = (code == "high" and GREEN) or (code == "mid" and YELLOW) or GREY
        vals[3] = color .. L["QUICK_MV_" .. code:upper()] .. "|r " .. GREY .. L.QUICK_MV_JUMPS:format(v.jumps or 0) .. "|r"
        tips[3] = { L.QUICK_MV_TIP_MOVE:format(v.jumps or 0, tonumber(db.quickJumpPct) or 2, R(v.jumpsPerMin), R(ev), tonumber(db.quickZonePct) or 5),
                    L.QUICK_MV_TIP_RULE:format(tonumber(db.quickMoveIn) or 2, tonumber(db.quickMoveAll) or 5, tonumber(db.quickMoveLow) or 1) }
    end
    local st = F.key ~= nil and (v or AHOpen()) and Q.BaitStats(F.key) or nil
    local sec = tonumber(db.quickFollowSec) or 30
    local ruleTip = L.QUICK_MV_TIP_BAITS:format(tonumber(db.quickBaitMinPct) or 5, sec)
    if not st then
        if v or (AHOpen() and F.key ~= nil) then vals[4] = GREY .. L.QUICK_MV_BAITS_NONE:format(win) .. "|r" end
        tips[4] = { ruleTip }
    else
        vals[4] = L.QUICK_MV_BAITS:format(st.n, win, st.withFollow)
        tips[4] = { L.QUICK_MV_TIP_AVG:format(R(st.added / st.n)), ruleTip }
        local f = st.last
        local own = f.own and (GREY .. " " .. L.QUICK_MV_OWN .. "|r") or ""
        if f.running then
            vals[5] = (f.added > 0 and GREEN or GREY) .. L.QUICK_MV_BAIT_RUN:format(f.added, f.left) .. "|r" .. own
        elseif f.added > 0 then vals[5] = GREEN .. L.QUICK_MV_BAIT_DONE:format(f.added, f.sec) .. "|r" .. own
        else vals[5] = ORANGE .. L.QUICK_MV_BAIT_ZERO:format(f.sec) .. "|r" .. own end
        tips[5] = { L.QUICK_MV_TIP_LAST:format(f.own and L.QUICK_MV_OWN_L or L.QUICK_MV_FOREIGN_L, Money(f.price),
                    ns.Radar.ShortAge(math.max(0, math.floor(Now() - f.t)))), L.QUICK_MV_TIP_LAST2:format(f.added, f.times, f.sec) }
    end
    if F.key ~= nil then vals[6], tips[6] = Q.BoughtText(F.key) end   -- ab 0.111
    if F.key ~= nil and ns.QuickStats then vals[7], tips[7] = ns.QuickStats.FocusText(F.key) end   -- ab 0.122
    for i, r in ipairs(F.mRows) do r.value:SetText(vals[i]); r.tip = tips[i] end
end

-- Diagramm im Schnellkauf: guenstigster Preis, Menge unter Kaufen bis, eigene Lockangebote
function F.UpdateQuickChart(limit)
    local Q = ns.Quick
    limit = F.ManualLimit(F.key) or limit
    if AHOpen() and F.key ~= nil then
        F.mHead:SetText(L.QUICK_CHART_HEAD:format(Dec(ns.Radar.FocusEvery())))
    else
        F.mHead:SetText(GREY .. L.MEASURE_NONE .. "|r")
    end
    local n, under, mins, marks = nil, nil, nil, nil
    if AHOpen() then n, under, mins, marks = Q.Series(limit) end
    local show = F.chart ~= nil and n ~= nil
    if F.chart and F.chart.frame then F.chart.frame:SetShown(show) end
    F.chartLegend:SetShown(show)
    if not show then F.chartN = nil; return end
    local nm = 0
    for _ in pairs(marks) do nm = nm + 1 end
    local cur = ns.Measure.cur
    local stamp = "q:" .. tostring(n) .. ":" .. tostring(limit) .. ":" .. nm .. ":" .. tostring(cur and cur.samples[n] and cur.samples[n].t)
    if F.chartN == stamp then return end
    local series = {
        { key = "marks", kind = "marks", values = marks, color = { 0.7, 0.4, 1, 0.8 } },
        { key = "under", kind = "bar", axis = "right", values = under, color = { 0.6, 0.6, 0.6, 0.4 } },
        { key = "min", kind = "line", values = mins, color = { 1, 0.82, 0.2, 1 }, width = 2, connect = true },
    }
    if Num(limit) and limit > 0 then series[#series + 1] = { key = "limit", kind = "hline", value = limit, color = { 0.3, 0.55, 1, 0.95 } } end
    ns.Radar.Perf("diagramm", function() F.chart:SetData(math.max(n, F.CHART_SLOTS or 60), series); F.chart:Draw() end)
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
        return R.JobText(job), job.stage == "confirm" or job.stage == "next", info
    end
    local info = (ns.Quick and ns.Quick.On()) and ns.Quick.Summary(d) or F.Summary(d)
    if not d or d.gone then return L.BUY_BUY, false, info end
    local qty = d.best and d.best.qty or 0
    if not AHOpen() then return L.FOCUS_BUY:format(qty), false, info end
    if R.IsStale(d.key or F.key) then return L.FOCUS_CHECKING, false, info end   -- ab 0.104
    if ns.Quick and ns.Quick.Locked(d.key or F.key) then return L.FOCUS_CHECKING, false, info end   -- ab 0.114
    -- ab 0.70: mit eigenem Ziel geht Kaufen auch ohne Gewinn (eigene Entscheidung), nur nicht ohne Menge oder Gold
    if qty < 1 or d.cant then return L.BUY_BUY, false, info end
    return L.FOCUS_BUY:format(qty), job == nil, info
end

function F.Update()
    if not F.tiers then return end
    local key = F.key
    local has = key ~= nil
    local live = AHOpen()
    if has and live and ns.Quick.On() then
        ns.Quick.EnsureLimit()   -- ab 0.107, ab 0.120 Haelfte des guenstigsten, mindestens Haendlerpreis
        ns.Quick.EnsureGold()    -- ab 0.113, ab 0.120 fester Betrag (quickGoldDefault)
    end
    On(F.marketButton, has); On(F.itemButton, has); On(F.saveButton, has)
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
        if F.quick then F.quick.state:SetText(""); F.quick.balance:SetText(""); F.quick.post:Disable(); F.quick.cancel:Disable() end
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
        Q.CheckAlarm(key, liveRows, (live and d and not d.gone and (d.maxQty or d.qty)) or 0, F.buyButton)
    end
end

-- Gegenstand in den Fokus nehmen (ersetzt den bisherigen)
function F.Set(key)
    if key == nil then return end
    if key ~= F.key then
        if F.key ~= nil then F.AutoSave() end   -- ab 0.113: Werte des bisherigen Gegenstands
        F.manual, F.manualLimit, F.manualSrc, F.manualQty, F.manualGold = nil, nil, nil, nil, nil
        ClearMoney(F.limitInput)
        F.since = time()
        F.chartN = nil
        F.ClearInput()
        if ns.Quick then ns.Quick.OnNewKey() end   -- ab 0.104
    end
    F.key = key
    mod.acc.focusKey = key
    if AHOpen() and F.Shown() then ns.Radar.SetFocus(key) end
    F.Update()
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
