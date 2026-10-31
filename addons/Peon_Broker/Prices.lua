-- Peon_Broker - Prices.lua
-- Reiter "Preise" im Broker-Fenster: Gegenstand suchen, aktuelle Preise, 7-Tage-Werte, Vorschlag
-- und Verlauf (Tageswerte, aeltere als Wochenwerte). Nur Daten des aktuellen Markts, Preise je Stueck.
--
--   Suchen: [erz          ]                                 12 von 4567 Gegenstaenden
--   Gegenstand                    Min        Median     Angebote   Stand
--   Kupfererz                     1s 20c     1s 60c         120    vor 5 Min.
--   ...
--   Kupfererz                           | Tag        Min      Median   Angebote
--   AH: Min 1s 20c  Median 1s 60c       | 30.09.     1s 20c   1s 60c        120
--   Angebote: 120 (4)                   | 29.09.     ...
--   7 Tage (2): Min ... Median ...      | Woche ab 01.09.  ...
--   Vorschlag: 1s 20c je Stück
--   Händler: 5c je Stück
--   Massenware

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local P = {}
ns.Prices = P

local GREY = "|cff808080"

local function Money(v) return ns.Tooltip.Money(v) end

---------------------------------------------------------------------------
-- Daten
---------------------------------------------------------------------------
-- Alle Gegenstaende des aktuellen Markts (zwischengespeichert bis zum naechsten Scan)
function P.All()
    local D = ns.Data
    local market, key = D.Market()
    local stamp = tostring(key) .. ":" .. tostring(market and market.lastScan) .. ":" .. tostring(D.liveStamp)
    if P.cache and P.cacheStamp == stamp then return P.cache end
    local all = {}
    if market then
        for k, e in pairs(market.items) do
            if type(e) == "table" and e.m then
                local name = D.ItemName(k, e)
                local id = D.ItemID(k)
                all[#all + 1] = {
                    key = k, e = e,
                    name = name or L.ITEM_UNKNOWN:format(id or 0),
                    lname = W.Lower(name or ""),
                    min = e.m, median = e.md, qty = e.q or 0,
                    t = e.gone or D.Seen(e), gone = e.gone,
                    sales = ns.Sales and ns.Sales.Stats(e, nil, k) or nil,
                }
            end
        end
    end
    P.cache, P.cacheStamp = all, stamp
    return all
end

-- Suche: Teil des Namens (Gross/klein egal), leer = alles
function P.Filter(text)
    local all = P.All()
    text = W.Lower(strtrim and strtrim(text or "") or (text or ""))
    if text == "" then return all, #all end
    local out = {}
    for _, it in ipairs(all) do
        if it.lname:find(text, 1, true) then out[#out + 1] = it end
    end
    return out, #all
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
local function S14Rate(r) return r.rate and (" · " .. L.SALES_RATE:format(math.floor(r.rate * 100 + 0.5))) or "" end

local function Grey(item, text)
    if item and item.gone then return GREY .. text .. "|r" end
    return text
end

function P.Build(c)
    -- Suche
    local label = c:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 4, -4)
    label:SetText(L.SEARCH)
    local box = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
    box:SetSize(220, 20)
    box:SetPoint("LEFT", label, "RIGHT", 10, 0)
    box:SetAutoFocus(false)
    box:SetScript("OnTextChanged", function() mod:Call("Preise", P.Update) end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    P.search = box
    local count = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    count:SetPoint("TOPRIGHT", -4, -4)
    count:SetJustifyH("RIGHT")
    P.count = count

    -- Liste aller Gegenstaende
    P.list = Peon.NewList(c, {
        columns = {
            { key = "name", title = L.COL_ITEM, width = 190,
              format = function(v, it) return W.Colored(v, it.e.ql) end,
              sortValue = function(it) return it.lname ~= "" and it.lname or W.Lower(it.name) end },
            { key = "min", title = L.TT_MIN, width = 95, align = "RIGHT",
              format = function(v, it) return Grey(it, Money(v)) end },
            { key = "median", title = L.TT_MEDIAN, width = 95, align = "RIGHT",
              format = function(v, it) return Grey(it, Money(v)) end },
            { key = "qty", title = L.COL_OFFERS, width = 70, align = "RIGHT" },
            { key = "sales", title = L.COL_SALES, width = 80, align = "RIGHT",
              format = function(v) return v and ns.Sales.PerHourText(v) or (GREY .. "–|r") end,
              sortValue = function(it) return it.sales and it.sales.perHour or -1 end },
            { key = "t", title = L.COL_AGE, width = 50, align = "RIGHT",
              format = function(v, it) return Grey(it, ns.Scan.Age(v)) end },
        },
        rows = 11, sortKey = "name",
        onClick = function(list, it) P.Show(it) end,
        onEnter = function(list, it, row) W.ShowItemTooltip(row, it.key) end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
    })
    P.list.frame:SetPoint("TOPLEFT", 0, -28)

    -- Einzelheiten links unten
    local detail = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", 4, -(28 + P.list:GetHeight() + 12))
    detail:SetWidth(252)
    detail:SetJustifyH("LEFT")
    detail:SetJustifyV("TOP")
    if detail.SetSpacing then detail:SetSpacing(3) end
    P.detail = detail

    -- Verlauf rechts unten
    P.history = Peon.NewList(c, {
        columns = {
            { key = "label", title = L.COL_DAY, width = 95,
              format = function(v, it) if it.week then return L.WEEK_FROM:format(v) end return v end,
              sortValue = function(it) return it.sort end },
            { key = "min", title = L.TT_MIN, width = 80, align = "RIGHT", format = function(v) return Money(v) end },
            { key = "median", title = L.TT_MEDIAN, width = 80, align = "RIGHT", format = function(v) return Money(v) end },
            { key = "qty", title = L.COL_OFFERS, width = 65, align = "RIGHT",
              format = function(v) return v and ("%d"):format(math.floor(v + 0.5)) or "" end },
        },
        rows = 8, sortKey = "label", sortDesc = true, selectable = false,
        emptyText = L.HISTORY_EMPTY,
    })
    P.history.frame:SetPoint("TOPRIGHT", 0, -(28 + P.list:GetHeight() + 8))
    P.addButton = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    P.addButton:SetSize(150, 22)
    P.addButton:SetPoint("BOTTOMLEFT", 0, 0)
    P.addButton:SetText(L.BUY_TO_LIST)
    P.addButton:SetScript("OnClick", function()
        if P.selectedKey == nil or not ns.Buy then return end
        local e = ns.Data.Lookup(P.selectedKey)
        ns.Buy.AddItem(P.selectedKey, { name = ns.Data.ItemName(P.selectedKey, e), quality = type(e) == "table" and e.ql or nil,
            icon = ns.Buy.Icon(ns.Data.ItemID(P.selectedKey)) })
    end)
    P.addButton:Disable()
    -- ab 0.27: alles zum Gegenstand im Ledger-Reiter "Gegenstand" (nur mit Peon_Ledger)
    P.moreButton = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    P.moreButton:SetSize(110, 22)
    P.moreButton:SetPoint("LEFT", P.addButton, "RIGHT", 6, 0)
    P.moreButton:SetText(L.PRICES_MORE)
    P.moreButton:SetScript("OnClick", function()
        local led = P.Ledger()
        local id = P.selectedKey ~= nil and ns.Data.ItemID(P.selectedKey)
        if led and id then led:ShowItem(id) end
    end)
    P.moreButton:Hide()
end

function P.Ledger()
    if not Peon.GetModule then return nil end
    local ok, m = pcall(Peon.GetModule, Peon, "ledger")
    if ok and type(m) == "table" and type(m.ShowItem) == "function" then return m end
    return nil
end

-- Suche anwenden, Liste und Zaehler aktualisieren
function P.Update()
    if not P.list then return end
    local items, total = P.Filter(P.search:GetText())
    P.list:SetData(items)
    local market = ns.Data.Market()
    if not market or not market.lastScan then
        P.list.empty:SetText(L.PRICES_NO_SCAN)
    else
        P.list.empty:SetText(L.PRICES_NOTHING)
    end
    P.count:SetText(L.PRICES_COUNT:format(#items, total))
    -- Auswahl nach neuem Scan/Suche beibehalten (gleicher Gegenstand)
    local found
    if P.selectedKey ~= nil then
        for _, it in ipairs(items) do if it.key == P.selectedKey then found = it; break end end
    end
    if found then P.list:Select(found) end
    P.Show(found)
end

-- Einzelheiten und Verlauf eines Gegenstands
function P.Show(it)
    if not P.detail then return end
    if P.addButton then if it then P.addButton:Enable() else P.addButton:Disable() end end
    if P.moreButton then if P.Ledger() and it then P.moreButton:Show() else P.moreButton:Hide() end end
    if not it then
        P.selectedKey = nil
        P.detail:SetText(GREY .. L.PRICES_PICK .. "|r")
        P.history:SetData({})
        return
    end
    P.selectedKey = it.key
    local e, key, db = it.e, it.key, mod.db
    local D = ns.Data
    local hp = ns.VendorPrice(D.ItemID(key))
    local v = D.Evaluate(e, key, 1, hp, db)
    local lines = {}
    lines[#lines + 1] = W.Colored(it.name, e.ql)
    local ah = ("%s %s   %s %s"):format(L.TT_MIN, Money(e.m), L.TT_MEDIAN, Money(e.md))
    lines[#lines + 1] = (e.gone and L.TT_AH_LAST or L.TT_AH) .. ": " .. Grey(it, ah)
    lines[#lines + 1] = L.TT_OFFERS2:format(e.q or 0, e.n or 0)
    local w = v.week
    if w and w.days and w.days >= 1 then
        lines[#lines + 1] = L.TT_7D_N:format(w.days) .. ": " ..
            ("%s %s   %s %s"):format(L.TT_MIN, Money(w.min), L.TT_MEDIAN, Money(w.median))
    end
    if v.band then
        lines[#lines + 1] = (v.band.src == "client" and L.TT_RANGE_CLIENT or L.TT_RANGE):format(v.band.days) .. ": " .. ns.Tooltip.RangeText(v.band) .. "   " ..
            GREY .. L.PRICES_RW:format(Money(math.floor(v.band.rw + 0.5))) .. "|r"
    end
    lines[#lines + 1] = L.TT_SUGGEST .. ": " .. L.TT_PER_UNIT:format(Money(v.vp))
    if hp and hp > 0 then
        lines[#lines + 1] = L.TT_VENDOR .. ": " .. L.TT_PER_UNIT:format(Money(hp))
    else
        lines[#lines + 1] = L.TT_VENDOR .. ": " .. GREY .. L.NO_VENDOR .. "|r"
    end
    local sr = ns.Sales and ns.Sales.Stats(e, nil, key)
    if sr then lines[#lines + 1] = (sr.src == "client" and L.TT_SALES_CLIENT or L.TT_SALES_NOW:format(tonumber(mod.db.salesWindow) or 6)) .. ": " .. ns.Sales.SellText(sr) end
    local s14 = ns.Sales and ns.Sales.Stats14(e)
    if s14 then lines[#lines + 1] = GREY .. L.SALES_14:format(ns.Sales.Num(s14.perHour), S14Rate(s14)) .. "|r" end
    lines[#lines + 1] = GREY .. (D.IsCommodity(key) and L.KIND_COMMODITY or L.KIND_ITEM) .. "|r"
    if v.state == "falling" then lines[#lines + 1] = "|cffff9933" .. L.HINT_FALLING .. "|r"
    elseif v.dump then lines[#lines + 1] = "|cffff4040" .. (v.band and L.HINT_DUMP_RANGE or L.HINT_DUMP2) .. "|r" end
    P.detail:SetText(table.concat(lines, "\n"))
    P.history:SetData(D.History(e))
end

W.pages.prices = {
    build = P.Build,
    refresh = P.Update,
}
