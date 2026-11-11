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

-- Urteil in der Grundform: aus der Chance, nicht aus einer Messung. Rueckgabe: Text, Farbe, Satz
function F.Verdict(d)
    if not d then return L.FOCUS_V_NONE, GREY, L.FOCUS_W_NONE end
    if d.gone then return L.FOCUS_V_GONE, GREY, tostring(d.goneWhy or "") end
    if d.cant then return L.FOCUS_V_CANT, ORANGE, L.FOCUS_W_CANT end
    return L.FOCUS_V_BUY, GREEN, L["FOCUS_W_" .. tostring(d.kind):upper()] or ""
end

-- Angaben zur Chance: Liste aus { Beschriftung, Wert }
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
    for i = 1, 7 do
        local r = {}
        r.label = UI.Text(left, "label", "")
        r.label:SetWidth(UI.LABEL_W)
        r.label:SetJustifyH("RIGHT")
        r.label:SetPoint("TOPLEFT", 8, -158 - (i - 1) * 20)
        r.value = UI.Text(left, "text", "")
        r.value:SetPoint("TOPLEFT", r.label, "TOPRIGHT", 12, 0)
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

    -- rechts: der Markt in diesem Moment
    local right = UI.Panel(c, "list", true)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", UI.GAP, -30)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
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

    if F.key == nil then F.key = mod.acc.focusKey end
    F.Update()
end

-- Text und Zustand des Kaufknopfs
local function BuyState(d)
    local R = ns.Radar
    local job = R.job
    local here = job and d and job.key == d.key
    if here then
        local info = ""
        if job.stage == "confirm" then info = L.FOCUS_CONFIRM:format(job.qty or 0, Money(job.total or 0))
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
        F.buyButton:SetText(L.BUY_BUY); F.buyButton:Disable(); F.buyInfo:SetText("")
        return
    end
    local e = D.Lookup(key)
    local d = F.Chance()
    if d and not d.gone then R.Annotate(d, R.Budget()) end
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
