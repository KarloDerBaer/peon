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
F.origin = "watch"    -- ab 0.82: wohin "Zurueck" fuehrt: "radar" (von dort gekommen) oder "watch" (sonst)
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
    F.Update()
end

-- "Auto": eigenes Ziel und eigenes "Kaufen bis" zurueck
function F.ResetOwn()
    F.manualLimit, F.manualSrc = nil, nil
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

-- ab 0.82: Fokus geoeffnet von einer Seite. Aus dem Radar: zurueck zum Radar. Sonst zurueck zu Beobachten, und ist
-- der Gegenstand beobachtet, gelten seine gespeicherten Werte (Kaufen bis, Zielpreis) als eigene Werte.
function F.FromPage(key, from)
    if from == "focus" then return end           -- naechste Chance aus dem Fokus heraus: Herkunft bleibt
    F.origin = (from == "radar") and "radar" or "watch"
    if F.origin == "watch" then F.LoadWatch(key) end
    F.UpdateBack()
    F.Update()
end

function F.LoadWatch(key)
    local Wt = ns.Watch
    if not (Wt and key ~= nil and Wt.Is(key)) then return false end
    local w = Wt.Store()[key]
    local limit = Wt.Limit(key)
    F.manual = Num(w.up) and w.up > 0 and { key = key, price = w.up } or nil
    F.manualLimit = Num(limit) and limit > 0 and { key = key, price = math.floor(limit) } or nil
    F.manualSrc = (F.manual or F.manualLimit) and "watch" or nil
    if ns.Measure and ns.Measure.cur and ns.Measure.cur.key == key then ns.Measure.Start(key) end
    return true
end

-- Speichern: Gegenstand in die Beobachtung, mit den geltenden Werten (Kaufen bis = Grenze nach unten,
-- Zielpreis = Grenze nach oben). Vorhandene Eintraege werden aktualisiert.
function F.Save()
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
    Wt.SetLimit(key, Num(limit) and "abs" or nil, limit)
    Wt.SetUp(key, target)
    if F.manual or F.manualLimit then F.manualSrc = "watch" end
    mod:Print(L.FOCUS_SAVED:format(name, Num(limit) and Money(limit) or "-", Num(target) and Money(target) or "-"))
    if ns.WatchPage then ns.WatchPage.Refresh() end
    F.Update()
    return true
end

-- Knopf "Zurueck zu ..." unten im Fokus
function F.UpdateBack()
    if not F.backButton then return end
    local label = F.origin == "radar" and L.TAB_RADAR or L.NTAB_WATCH
    F.backButton:SetText(L.FOCUS_BACK:format(label))
end

function F.GoBack()
    ns.Window.Open(F.origin == "radar" and "radar" or "watch")
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
    local manual = F.ManualTarget(F.key)
    local buyLimit = F.ManualLimit(F.key)
    local d = ns.Radar.entries[F.key]
    if d and not manual and not buyLimit then
        ns.Radar.Annotate(d, ns.Radar.Budget())
        d.risk = ns.Radar.Risk(d)
        return d
    end
    -- eben weggefallene Chance: "VORBEI" mit Grund, bis man ein eigenes Ziel waehlt
    if not d and not manual and not buyLimit and ns.Radar.gone[F.key] then return ns.Radar.gone[F.key] end
    local M = ns.Measure
    local mt = M and M.cur and M.cur.key == F.key and M.cur.target or nil
    local p = F.OwnPlan(manual or (d and d.ref) or mt, buyLimit)
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
    return L.FOCUS_V_BUY, GREEN, L["FOCUS_W_" .. tostring(d.kind):upper()] or ""
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
    local cum, cost = 0, 0
    for _, l in ipairs(ns.Data.Available(rows)) do
        cum, cost = cum + l.qty, cost + l.qty * l.price
        out[#out + 1] = { price = l.price, qty = l.qty, cum = cum, cost = cost, inBuy = Num(limit) and l.price <= limit or false,
                          isTarget = Num(target) and l.price == target or false }
    end
    return out
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
F.ROW_Y, F.ROW_STEP = -240, 18   -- ab 0.77: Ueblich, Verkauft in, Risiko unter den Eingabefeldern (ab 0.82 enger)
F.KIND_Y, F.TARGET_Y, F.LIMIT_Y = -150, -180, -210
F.BLUE = "|cff4da6ff"
function F.Build(c)
    local UI = Peon.UI
    F.frame = c

    local left = UI.Panel(c, "left")
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(UI.LEFT_W)
    F.left = left
    UI.SectionTab(left, L.FOCUS_HEAD_CHANCE)
    F.header = UI.ItemHeader(left)
    F.header:SetPoint("TOPLEFT", 10, -10)
    F.header:SetScript("OnEnter", function(self) if F.key ~= nil then W.ShowItemTooltip(self, F.key) end end)
    F.header:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    F.verdict = UI.Text(left, "big", "")
    F.verdict:SetPoint("TOPLEFT", 16, -88)
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

    F.buyButton = UI.Button(left, L.BUY_BUY, UI.LEFT_W - 20, function()
        local d = F.Plan()
        if d then mod:Call("Radar", ns.Radar.BuyStep, d, "best") end
    end, "gold")
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
    -- ab 0.74 ohne "Jetzt pruefen": der Fokus fragt ohnehin laufend ab (KarloDerBaer 12.11.2026)
    F.tiers = UI.Table(right, {
        columns = {
            { key = "price", title = L.ITEM_TIER_PRICE, align = "RIGHT", format = function(v) return Money(v) end },
            { key = "qty", title = L.ITEM_COL_QTY, width = 80, align = "RIGHT" },
            { key = "cum", title = L.ITEM_TIER_CUM, width = 80, align = "RIGHT" },
            { key = "cost", title = L.ITEM_TIER_COST, width = 110, align = "RIGHT", format = function(v) return Money(v) end },
        },
        sortKey = "price", empty = L.FOCUS_TIER_WAIT,
        rowBg = function(r)   -- Kern API 19: Ziel gelb (ab 0.74), gekaufte Stufen blau (ab 0.77)
            if r and r.isTarget then return 1, 0.82, 0, 0.22 end
            if r and r.inBuy then return 0.25, 0.55, 1, 0.22 end
        end,
        -- ab 0.70: Klick auf eine Preisstufe macht ihren Preis zum Ziel, ab 0.76 Rechtsklick zu "Kaufen bis".
        -- ab 0.83 getauscht (KarloDerBaer, 12.11.2026): Linksklick "Kaufen bis", Rechtsklick Zielpreis. Farben bleiben.
        onClick = function(item, button)
            if not (item and Num(item.price)) then return end
            if button == "RightButton" then F.SetTarget(item.price) else F.SetLimit(item.price) end
        end,
    })
    F.BuildMeasure(c, right)

    if F.key == nil then F.key = mod.acc.focusKey end
    F.Update()
end

F.TIER_H = 152     -- Hoehe der Preisstufen (Kopf und 6 Zeilen)
F.MEASURE_ROWS = { "MEASURE_OUT", "MEASURE_IN", "MEASURE_UNDER", "MEASURE_MIN" }

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
    for i, key in ipairs(F.MEASURE_ROWS) do
        local label = UI.Text(mp, "label", L[key])
        label:SetWidth(130)
        label:SetJustifyH("RIGHT")
        label:SetPoint("TOPLEFT", 4, -28 - (i - 1) * 17)
        local value = UI.Text(mp, "text", "")
        value:SetPoint("TOPLEFT", label, "TOPRIGHT", 10, 0)
        F.mRows[i] = { label = label, value = value }
    end
    local cw = W.WIDTH - 2 * W.SIDE - UI.LEFT_W - UI.GAP
    if Peon.NewChart then
        F.chart = Peon.NewChart(mp, { width = cw - 12, height = 104, left = 46, right = 40, top = 6, bottom = 6, grid = 2,
            leftFormat = AxisMoney, rightFormat = function(v) return Num(v) and Peon.ShortNumber and Peon.ShortNumber(v) or "" end })
        if F.chart and F.chart.frame then F.chart.frame:SetPoint("BOTTOMLEFT", mp, "BOTTOMLEFT", 6, 6) end
        -- ab 0.75: nichts zeichnet ueber den Rand des Diagramms hinaus
        if F.chart and F.chart.plot and F.chart.plot.SetClipsChildren then F.chart.plot:SetClipsChildren(true) end
    end
    F.chartLegend = UI.Text(mp, "small", ("|cff6699cc%s|r  |cffffd133%s|r  |cff60e060%s|r"):format(L.MEASURE_UNDER, L.MEASURE_MIN, L.FOCUS_R_TARGET))
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

-- Messwerte in die Zeilen; v = laufende Messung
function F.UpdateMeasure(v)
    if not F.mRows then return end
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
    local vals = { "", "", "", "" }
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
    local stamp = tostring(n) .. ":" .. tostring(v.target) .. ":" .. tostring(cur and cur.samples[n] and cur.samples[n].t)
    if F.chartN == stamp then return end
    local series = {
        { key = "under", kind = "bar", axis = "right", values = under, color = { 0.4, 0.6, 0.8, 0.45 } },
        { key = "min", kind = "line", values = mins, color = { 1, 0.82, 0.2, 1 }, width = 2, connect = true },
    }
    if Num(v.target) then series[#series + 1] = { key = "target", kind = "hline", value = v.target, color = { 0.38, 0.88, 0.38, 0.9 } } end
    -- ab 0.75: mindestens F.CHART_SLOTS Plaetze, von links gefuellt. Mit nur zwei Abfragen war jeder Balken so breit
    -- wie das halbe Diagramm und ragte ueber den Rand.
    ns.Radar.Perf("diagramm", function() F.chart:SetData(math.max(n, F.CHART_SLOTS or 60), series); F.chart:Draw() end)
    F.chartN = stamp   -- erst nach dem Zeichnen: bricht es ab, versucht es die naechste Antwort neu
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
    local info = F.Summary(d)
    if not d or d.gone then return L.BUY_BUY, false, info end
    local qty = d.best and d.best.qty or 0
    if not AHOpen() then return L.FOCUS_BUY:format(qty), false, info end
    -- ab 0.70: mit eigenem Ziel geht Kaufen auch ohne Gewinn (eigene Entscheidung), nur nicht ohne Menge oder Gold
    if qty < 1 or d.cant then return L.BUY_BUY, false, info end
    return L.FOCUS_BUY:format(qty), job == nil, info
end

function F.Update()
    if not F.tiers then return end
    local key = F.key
    local has = key ~= nil
    local live = AHOpen()
    On(F.marketButton, has); On(F.itemButton, has); On(F.saveButton, has)
    On(F.autoButton, has and live and (F.ManualTarget(key) ~= nil or F.ManualLimit(key) ~= nil))
    if not has then
        F.header:Set(nil, "", 1)
        F.verdict:SetText("")
        F.why:SetText(GREY .. L.FOCUS_EMPTY .. "|r")
        for _, r in ipairs(F.rows) do r.label:SetText(""); r.value:SetText("") end
        F.kindValue:SetText("")
        F.SyncInputs(nil)
        F.tiers:SetData({})
        F.stand:SetText("")
        F.UpdateMeasure(nil)
        F.buyButton:SetText(L.BUY_BUY); F.buyButton:Disable(); F.buyInfo:SetText(F.Summary(nil))
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
    F.tiers:SetData(F.Tiers(limit, d and not d.gone and d.ref or nil))
    local _, t = F.LiveRows()
    if not live then F.stand:SetText(GREY .. L.TAB_AH_ONLY .. "|r")
    elseif t then F.stand:SetText(L.FOCUS_LIVE:format(ns.Scan.Age(t)))
    else F.stand:SetText(GREY .. L.FOCUS_LIVE_WAIT .. "|r") end
    F.UpdateMeasure(F.LiveValues())
    local label, enabled, info = BuyState(d)
    F.buyButton:SetText(label)
    On(F.buyButton, enabled)
    F.buyInfo:SetText(info)
end

-- Gegenstand in den Fokus nehmen (ersetzt den bisherigen)
function F.Set(key)
    if key == nil then return end
    if key ~= F.key then
        F.manual, F.manualLimit, F.manualSrc = nil, nil, nil
        ClearMoney(F.limitInput)
        F.since = time()
        F.chartN = nil
        F.ClearInput()
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
    leave = function() ns.Radar.Halt(); if ns.Settings then ns.Settings.Hide("focus") end end,
}
