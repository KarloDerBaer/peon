-- Peon_Broker - Focus.lua
-- Neuaufbau N6 (ab 0.64, Konzept Peon_Broker_Neuaufbau.md, Abschnitt 6.1): Seite "Fokus" in der Grundform.
-- Immer genau ein Gegenstand (KarloDerBaer, 11.11.2026). Die Seite zeigt alles Wichtige nur fuer ihn und fragt am
-- Auktionator nur ihn regelmaessig neu ab (Radar.lua, R.SetFocus):
--   links   Kopf, Urteil mit einem Satz, Angaben zur Chance (Art, Kaufen bis, Menge, Einsatz, Ziel, Gewinn),
--           Gold-Knopf Kaufen, darunter Im Markt zeigen und Gegenstand
--   rechts  der Markt in diesem Moment: Stand und Preisstufen mit Summen bis zu jeder Stufe
-- Hinein kommt ein Gegenstand per Klick im Radar oder ueber "In den Fokus" im Menue jedes Gegenstands. Er muss
-- keine Chance sein. Die laufende Messung (Abfluss, Zufluss, Urteil aus dem Marktverhalten) kommt mit H2.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local F = {}
ns.Focus = F

F.key = nil   -- Gegenstand im Fokus (Schluessel wie in der Preisdatenbank), gemerkt in PeonBrokerDB.focusKey

local GREY, GREEN, ORANGE = "|cff999999", "|cff60e060", "|cffff9933"
local function Money(v) return ns.Tooltip.Money(v) end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function AHOpen() return ns.Scan.ahOpen and rawget(_G, "C_AuctionHouse") ~= nil end
local function On(b, v) if v then b:Enable() else b:Disable() end end

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

F.V_TEXT = { buy = "FOCUS_V_BUY", wait = "MEASURE_V_WAIT", away = "MEASURE_V_AWAY", first = "MEASURE_V_FIRST" }
F.V_COLOR = { buy = GREEN, wait = "|cffffd100", away = "|cffff5555", first = GREY }

-- Urteil: ohne Messung aus der Chance (Grundform), ab 0.66 beim Aufkauf aus der Messung (Konzept 6.1).
-- Rueckgabe: Text, Farbe, Satz
function F.Verdict(d)
    if not d then return L.FOCUS_V_NONE, GREY, L.FOCUS_W_NONE end
    if d.gone then return L.FOCUS_V_GONE, GREY, tostring(d.goneWhy or "") end
    if d.cant then return L.FOCUS_V_CANT, ORANGE, L.FOCUS_W_CANT end
    local v = d.kind == "buyout" and F.LiveValues() or nil
    if v then
        local code, why, early = ns.Measure.Verdict(v)
        local text = L[F.V_TEXT[code]] or code
        if early and code ~= "first" then text = text .. " " .. L.MEASURE_EARLY end
        return text, F.V_COLOR[code] or GREY, why
    end
    return L.FOCUS_V_BUY, GREEN, L["FOCUS_W_" .. tostring(d.kind):upper()] or ""
end

-- Verkaufsdauer: aus dem Absatz der letzten Stunden (H1), ab H2 aus der Messung, sobald sie genug zeigt
function F.SellsText(d)
    local h = d.hours
    if F.SellHours then
        local mh = F.SellHours(d)
        if mh then return ns.Buyout.HoursText(mh) .. " " .. GREY .. L.FOCUS_MEASURED .. "|r" end
    end
    return ns.Buyout.HoursText(h)
end

-- Angaben zur Chance: Liste aus { Beschriftung, Wert, tip = Zeilen fuer den Tooltip }
function F.Rows(d)
    local R = ns.Radar
    local rows = {}
    if not d then return rows end
    local best = d.best or {}
    rows[#rows + 1] = { L.RADAR_COL_KIND, L["RADAR_KIND_" .. tostring(d.kind):upper()] or tostring(d.kind) }
    if Num(d.limit) then rows[#rows + 1] = { L.FOCUS_R_LIMIT, Money(d.limit) } end
    local qty = Num(best.qty) and best.qty or 0
    local all = Num(d.qty) and d.qty or qty
    rows[#rows + 1] = { L.FOCUS_R_QTY, (qty < all) and L.FOCUS_QTY_OF:format(qty, all) or tostring(all) }
    if Num(best.cost) then rows[#rows + 1] = { L.FOCUS_R_COST, Money(best.cost) } end
    if Num(d.ref) then rows[#rows + 1] = { L.FOCUS_R_TARGET, Money(d.ref) .. (d.kind == "vendor" and (" " .. GREY .. L.FOCUS_AT_VENDOR .. "|r") or "") } end
    if Num(best.gain) then rows[#rows + 1] = { L.FOCUS_R_GAIN, R.SignedMoney(math.floor(best.gain + 0.5)) } end
    if d.kind == "buyout" then   -- ab 0.65 (H1)
        rows[#rows + 1] = { L.FOCUS_R_SELLS, F.SellsText(d) }
        if d.risk then
            rows[#rows + 1] = { L.RADAR_COL_RISK, (R.RISK_COLOR[d.risk] or "") .. (L["RADAR_RISK_" .. d.risk:upper()] or d.risk) .. "|r",
                                tip = d.riskWhy }
        end
    end
    return rows
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
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
    F.verdict:SetPoint("TOPLEFT", 16, -94)
    F.why = UI.Text(left, "text", "", UI.LEFT_W - 32)
    F.why:SetPoint("TOPLEFT", 16, -118)
    F.rows = {}
    for i = 1, 9 do
        local r = {}
        r.label = UI.Text(left, "label", "")
        r.label:SetWidth(UI.LABEL_W)
        r.label:SetJustifyH("RIGHT")
        r.label:SetPoint("TOPLEFT", 8, -158 - (i - 1) * 20)
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
        local d = F.key ~= nil and ns.Radar.entries[F.key]
        if d then mod:Call("Radar", ns.Radar.BuyStep, d, "best") end
    end, "gold")
    F.buyButton:SetPoint("BOTTOMLEFT", 10, 40)
    F.buyInfo = UI.Text(left, "small", "", UI.LEFT_W - 32)
    F.buyInfo:SetPoint("BOTTOMLEFT", F.buyButton, "TOPLEFT", 6, 6)
    local half = math.floor((UI.LEFT_W - 26) / 2)
    F.marketButton = UI.Button(left, L.GO_MARKET, half, function()
        if F.key ~= nil then mod:Call("Sprung", ns.Go.Market, { key = F.key }) end
    end)
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
    F.refreshButton = UI.Button(c, L.FOCUS_REFRESH, 120, function()
        if F.key ~= nil and AHOpen() then ns.Radar.SetFocus(F.key) end
    end)
    F.refreshButton:SetPoint("BOTTOMRIGHT", right, "TOPRIGHT", -2, 4)
    F.tiers = UI.Table(right, {
        columns = {
            { key = "price", title = L.ITEM_TIER_PRICE, align = "RIGHT", format = function(v) return Money(v) end,
              color = function(r) if r.inBuy then return 0.38, 0.88, 0.38 end return 1, 1, 1 end },
            { key = "qty", title = L.ITEM_COL_QTY, width = 80, align = "RIGHT" },
            { key = "cum", title = L.ITEM_TIER_CUM, width = 80, align = "RIGHT" },
            { key = "cost", title = L.ITEM_TIER_COST, width = 110, align = "RIGHT", format = function(v) return Money(v) end },
        },
        sortKey = "price", empty = L.ITEM_TIER_EMPTY,
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
    end
    F.chartLegend = UI.Text(mp, "small", ("|cff6699cc%s|r  |cffffd133%s|r  |cff60e060%s|r"):format(L.MEASURE_UNDER, L.MEASURE_MIN, L.FOCUS_R_TARGET))
    F.chartLegend:SetPoint("BOTTOMRIGHT", mp, "BOTTOMRIGHT", -10, 114)
end

local function Dec(x)
    local t = ("%.1f"):format(x or 0):gsub("%.0$", "")
    return (t:gsub("%.", L.DEC_SEP or "."))
end
F.Dec = Dec

-- Messwerte in die Zeilen; v = laufende Messung, saved = gemerkte (unterwegs)
function F.UpdateMeasure(v, saved)
    if not F.mRows then return end
    local src = v or saved
    local every = tonumber(mod.db.focusEvery) or 5
    if v then
        local head = L.MEASURE_HEAD:format(every)
        if v.every then head = head .. "  " .. GREY .. L.MEASURE_REAL:format(Dec(v.every)) .. "|r" end
        F.mHead:SetText(head)
    elseif saved then
        F.mHead:SetText(L.MEASURE_SAVED:format(ns.Scan.Age(saved.t)) .. "  " .. ORANGE .. L.ST_NOT_LIVE .. "|r")
    elseif AHOpen() and F.key ~= nil then
        F.mHead:SetText(L.MEASURE_HEAD:format(every) .. "  " .. GREY .. L.MEASURE_STARTING .. "|r")
    else
        F.mHead:SetText(GREY .. L.MEASURE_NONE .. "|r")
    end
    local vals = { "", "", "", "" }
    if src then
        local trendU = L["MEASURE_T_" .. tostring(src.underTrend):upper()] or ""
        local trendM = L["MEASURE_T_" .. tostring(src.minTrend):upper()] or ""
        vals[1] = L.MEASURE_RATE:format(Dec(src.out))
        vals[2] = L.MEASURE_RATE:format(Dec(src.inUnder)) .. (Num(src.target) and ("  " .. GREY .. L.MEASURE_TARGET:format(Money(src.target)) .. "|r") or "")
        vals[3] = tostring(src.under or 0) .. ", " .. trendU
        vals[4] = (Num(src.min) and Money(src.min) or "-") .. ", " .. trendM
    end
    for i, r in ipairs(F.mRows) do r.value:SetText(vals[i]) end
    -- Diagramm: Menge unter Ziel (rechts), guenstigster Preis und Ziel (links)
    local n, under, mins = nil, nil, nil
    if v then n, under, mins = ns.Measure.Series() end
    local show = F.chart ~= nil and n ~= nil
    if F.chart and F.chart.frame then F.chart.frame:SetShown(show) end
    F.chartLegend:SetShown(show)
    if not show then return end
    local series = {
        { key = "under", kind = "bar", axis = "right", values = under, color = { 0.4, 0.6, 0.8, 0.45 } },
        { key = "min", kind = "line", values = mins, color = { 1, 0.82, 0.2, 1 }, width = 2, connect = true },
    }
    if Num(v.target) then series[#series + 1] = { key = "target", kind = "hline", value = v.target, color = { 0.38, 0.88, 0.38, 0.9 } } end
    F.chart:SetData(n, series)
    F.chart:Draw()
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
    if qty < 1 or d.cant then return L.BUY_BUY, false, "" end
    if not AHOpen() then return L.FOCUS_BUY:format(qty), false, L.TAB_AH_ONLY end
    return L.FOCUS_BUY:format(qty), job == nil, ""
end

function F.Update()
    if not F.tiers then return end
    local R, D = ns.Radar, ns.Data
    local key = F.key
    local has = key ~= nil
    On(F.marketButton, has); On(F.itemButton, has)
    On(F.refreshButton, has and AHOpen() and not ns.Scan.state)
    if not has then
        F.header:Set(nil, "", 1)
        F.verdict:SetText("")
        F.why:SetText(GREY .. L.FOCUS_EMPTY .. "|r")
        for _, r in ipairs(F.rows) do r.label:SetText(""); r.value:SetText("") end
        F.tiers:SetData({})
        F.stand:SetText("")
        F.UpdateMeasure(nil, nil)
        F.buyButton:SetText(L.BUY_BUY); F.buyButton:Disable(); F.buyInfo:SetText("")
        return
    end
    local e = D.Lookup(key)
    local d = F.Chance()
    if d and not d.gone then R.Annotate(d, R.Budget()); d.risk = R.Risk(d) end
    local id = D.ItemID(key)
    local name = (d and d.name) or D.ItemName(key, e) or L.ITEM_UNKNOWN:format(id or 0)
    local quality = (d and d.quality) or (type(e) == "table" and e.ql) or nil
    F.header:Set(ns.Buy.Icon(id), name, quality)
    local text, color, why = F.Verdict(d)
    F.verdict:SetText(color .. text .. "|r")
    F.why:SetText(why or "")
    local rows = F.Rows(d)
    for i, r in ipairs(F.rows) do
        r.label:SetText(rows[i] and rows[i][1] or "")
        r.value:SetText(rows[i] and rows[i][2] or "")
        r.tip = rows[i] and rows[i].tip or nil
    end
    -- Preisstufen: gruen, was der Kauf nimmt
    local tiers = ns.Item.Tiers(type(e) == "table" and e or nil)
    local limit = d and not d.gone and d.limit or nil
    for _, t in ipairs(tiers) do t.inBuy = Num(limit) and t.price <= limit or false end
    F.tiers:SetData(tiers)
    local seen = type(e) == "table" and D.Seen(e) or nil
    local st = seen and L.FOCUS_STAND:format(ns.Scan.Age(seen)) or L.FOCUS_NO_STAND
    if not AHOpen() then st = st .. "  " .. ORANGE .. L.ST_NOT_LIVE .. "|r" end
    F.stand:SetText(st)
    local live = F.LiveValues()
    F.UpdateMeasure(live, not live and not AHOpen() and ns.Measure and ns.Measure.Saved(key) or nil)
    local label, enabled, info = BuyState(d)
    F.buyButton:SetText(label)
    On(F.buyButton, enabled)
    F.buyInfo:SetText(info)
end

-- Gegenstand in den Fokus nehmen (ersetzt den bisherigen)
function F.Set(key)
    if key == nil then return end
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
    leave = function() ns.Radar.Halt() end,
}
