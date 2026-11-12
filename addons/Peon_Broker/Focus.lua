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

local function SetManual(price)
    if Num(price) and price > 0 then F.manual = { key = F.key, price = math.floor(price) } else F.manual = nil end
    -- "Menge unter Ziel" gilt fuer ein Ziel: mit einem neuen Ziel beginnt die Messung neu
    if ns.Measure and ns.Measure.cur and ns.Measure.cur.key == F.key then ns.Measure.Start(F.key) end
    F.chartN = nil
F.CHART_SLOTS = 60
end

-- Eigenes Ziel setzen (price = nil: wieder das Ziel der Chance bzw. die zweite Preisstufe)
function F.SetTarget(price)
    if F.key == nil then return end
    SetManual(price)
    if F.manual and F.targetInput then F.targetInput:SetAmount(F.manual.price) else F.ClearInput() end
    F.Update()
end

-- Getipptes Ziel (Betrag 0 = leer: zurueck zum Ziel der Chance)
function F.SetTargetTyped(amount)
    if F.key == nil then return end
    SetManual(amount)
    F.Update()
end

function F.ClearInput()
    local t = F.targetInput
    if not t then return end
    for _, k in ipairs({ "gold", "silver", "copper" }) do if t[k] then t[k]:SetText("") end end
end

-- Kauf "alles unter dem Ziel" aus den Live-Stufen. Rueckgabe: Plan wie eine Chance (kind "own") oder nil
function F.OwnPlan(target)
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
            qty, cost, limit = qty + l.qty, cost + l.qty * l.price, l.price
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
        qty = qty, cost = cost, limit = limit, ref = target, net = target * (1 - cut),
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
    local d = ns.Radar.entries[F.key]
    if d and not manual then
        ns.Radar.Annotate(d, ns.Radar.Budget())
        d.risk = ns.Radar.Risk(d)
        return d
    end
    -- eben weggefallene Chance: "VORBEI" mit Grund, bis man ein eigenes Ziel waehlt
    if not d and not manual and ns.Radar.gone[F.key] then return ns.Radar.gone[F.key] end
    local M = ns.Measure
    local mt = M and M.cur and M.cur.key == F.key and M.cur.target or nil
    local p = F.OwnPlan(manual or (d and d.ref) or mt)
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

-- Angaben: Liste aus { Beschriftung, Wert, tip = Zeilen fuer den Tooltip }
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
    local best = d.best or {}
    rows[#rows + 1] = { L.RADAR_COL_KIND, d.own and L.FOCUS_KIND_OWN or (L["RADAR_KIND_" .. tostring(d.kind):upper()] or tostring(d.kind)) }
    if Num(d.limit) then rows[#rows + 1] = { L.FOCUS_R_LIMIT, Money(d.limit) } end
    local all = Num(d.qty) and d.qty or 0
    local qty = Num(best.qty) and best.qty or all
    rows[#rows + 1] = { L.FOCUS_R_QTY, (qty < all and qty > 0) and L.FOCUS_QTY_OF:format(qty, all) or tostring(all) }
    if Num(best.cost) then rows[#rows + 1] = { L.FOCUS_R_COST, Money(best.cost) } end
    if Num(d.ref) then
        local extra = ""
        if d.kind == "vendor" then extra = " " .. GREY .. L.FOCUS_AT_VENDOR .. "|r"
        elseif F.ManualTarget(d.key) then extra = " " .. GREY .. L.FOCUS_OWN_MARK .. "|r" end
        rows[#rows + 1] = { L.FOCUS_R_TARGET, Money(d.ref) .. extra }
    end
    -- ab 0.74: ueblicher Bereich aus dem Verlauf (KarloDerBaer 12.11.2026)
    rows[#rows + 1] = { L.FOCUS_R_BAND, F.BandText(d) }
    if Num(best.gain) then rows[#rows + 1] = { L.FOCUS_R_GAIN, R.SignedMoney(math.floor(best.gain + 0.5)) } end
    if d.kind == "buyout" or d.own then   -- ab 0.65 (H1)
        rows[#rows + 1] = { L.FOCUS_R_SELLS, F.SellsText(d) }
        if d.risk then
            rows[#rows + 1] = { L.RADAR_COL_RISK, (R.RISK_COLOR[d.risk] or "") .. (L["RADAR_RISK_" .. d.risk:upper()] or d.risk) .. "|r",
                                tip = d.riskWhy }
        end
    end
    return rows
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

-- Preisstufen der letzten Live-Abfrage mit Summen; gruen, was der Kauf nimmt, gelb die Stufe des Ziels (ab 0.74)
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
F.ROW_Y, F.ROW_STEP = -146, 18   -- ab 0.74 dichter, Platz fuer den ueblichen Bereich

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
    F.rows = {}
    for i = 1, 9 do
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

    -- ab 0.70: eigenes Ziel (von Hand oder per Klick auf eine Preisstufe), "Auto" nimmt es zurueck
    F.targetLabel = UI.Text(left, "label", L.FOCUS_OWN_TARGET)
    F.targetLabel:SetWidth(UI.LABEL_W)
    F.targetLabel:SetJustifyH("RIGHT")
    F.targetLabel:SetPoint("BOTTOMLEFT", 8, 112)
    F.targetInput = UI.MoneyInput(left, function(amount) F.SetTargetTyped(amount) end)
    F.targetInput:SetPoint("LEFT", F.targetLabel, "RIGHT", 6, 0)
    if F.targetInput.SetScale then F.targetInput:SetScale(0.85) end
    F.autoButton = UI.Button(left, L.FOCUS_AUTO, 52, function() F.SetTarget(nil) end)
    F.autoButton:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -8, 110)
    UI.SetTooltip(F.autoButton, { L.FOCUS_AUTO, L.FOCUS_AUTO_TIP })

    F.buyButton = UI.Button(left, L.BUY_BUY, UI.LEFT_W - 20, function()
        local d = F.Plan()
        if d then mod:Call("Radar", ns.Radar.BuyStep, d, "best") end
    end, "gold")
    F.buyButton:SetPoint("BOTTOMLEFT", 10, 40)
    F.buyInfo = UI.Text(left, "small", "", UI.LEFT_W - 32)
    F.buyInfo:SetPoint("BOTTOMLEFT", F.buyButton, "TOPLEFT", 6, 6)
    local half = math.floor((UI.LEFT_W - 26) / 2)
    F.marketButton = ns.Go.MarketButton(left, half, function() return F.key ~= nil and { key = F.key } or nil end)   -- ab 0.73 sicher
    F.marketButton:SetPoint("BOTTOMLEFT", 10, 10)
    F.itemButton = UI.Button(left, L.NTAB_ITEM, half, function()
        if F.key ~= nil then mod:Call("Sprung", ns.Go.Item, { key = F.key }) end
    end)
    F.itemButton:SetPoint("LEFT", F.marketButton, "RIGHT", 6, 0)

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
            { key = "price", title = L.ITEM_TIER_PRICE, align = "RIGHT", format = function(v) return Money(v) end,
              color = function(r) if r.inBuy then return 0.38, 0.88, 0.38 end return 1, 1, 1 end },
            { key = "qty", title = L.ITEM_COL_QTY, width = 80, align = "RIGHT" },
            { key = "cum", title = L.ITEM_TIER_CUM, width = 80, align = "RIGHT" },
            { key = "cost", title = L.ITEM_TIER_COST, width = 110, align = "RIGHT", format = function(v) return Money(v) end },
        },
        sortKey = "price", empty = L.FOCUS_TIER_WAIT,
        rowBg = function(r) if r and r.isTarget then return 1, 0.82, 0, 0.22 end end,   -- ab 0.74 (Kern API 19)
        -- ab 0.70: Klick auf eine Preisstufe macht ihren Preis zum Ziel
        onClick = function(item, button) if item and Num(item.price) and button ~= "RightButton" then F.SetTarget(item.price) end end,
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
    F.chartN = stamp
    local series = {
        { key = "under", kind = "bar", axis = "right", values = under, color = { 0.4, 0.6, 0.8, 0.45 } },
        { key = "min", kind = "line", values = mins, color = { 1, 0.82, 0.2, 1 }, width = 2, connect = true },
    }
    if Num(v.target) then series[#series + 1] = { key = "target", kind = "hline", value = v.target, color = { 0.38, 0.88, 0.38, 0.9 } } end
    -- ab 0.75: mindestens F.CHART_SLOTS Plaetze, von links gefuellt. Mit nur zwei Abfragen war jeder Balken so breit
    -- wie das halbe Diagramm und ragte ueber den Rand.
    ns.Radar.Perf("diagramm", function() F.chart:SetData(math.max(n, F.CHART_SLOTS), series); F.chart:Draw() end)
end

-- Text und Zustand des Kaufknopfs
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
        return R.JobText(job), job.stage == "confirm" or job.stage == "next", info
    end
    if not d or d.gone then return L.BUY_BUY, false, "" end
    local qty = d.best and d.best.qty or 0
    if not AHOpen() then return L.FOCUS_BUY:format(qty), false, L.TAB_AH_ONLY end
    -- ab 0.70: mit eigenem Ziel geht Kaufen auch ohne Gewinn (eigene Entscheidung), nur nicht ohne Menge oder Gold
    if qty < 1 or d.cant then return L.BUY_BUY, false, "" end
    return L.FOCUS_BUY:format(qty), job == nil, ""
end

function F.Update()
    if not F.tiers then return end
    local key = F.key
    local has = key ~= nil
    local live = AHOpen()
    On(F.marketButton, has); On(F.itemButton, has)
    On(F.autoButton, has and live and F.ManualTarget(key) ~= nil)
    if not has then
        F.header:Set(nil, "", 1)
        F.verdict:SetText("")
        F.why:SetText(GREY .. L.FOCUS_EMPTY .. "|r")
        for _, r in ipairs(F.rows) do r.label:SetText(""); r.value:SetText("") end
        F.tiers:SetData({})
        F.stand:SetText("")
        F.UpdateMeasure(nil)
        F.buyButton:SetText(L.BUY_BUY); F.buyButton:Disable(); F.buyInfo:SetText("")
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
        F.manual = nil
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
