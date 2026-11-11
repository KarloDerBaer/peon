-- Peon_Broker - Pages.lua
-- Umbau U10 (ab 0.51, Konzept Peon_Broker_Umbau.md, Abschnitt 8): neue Reiter des Broker-Fensters, das nur noch
-- enthaelt, was ohne Auktionshaus geht.
--   market   Markt: Datenstand je Markt und Vergleich Heimat gegen Neutral (nach Gebuehren beider Haeuser)
--   watch    Beobachtung: beobachtete Gegenstaende mit Preis, Grenze, ueblichem Bereich und Alarm
--   sources  Quellen: Datenstand, Verbindung zum Manager, Anteil der Haeuser, Listen

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local G = {}
ns.Pages = G

local GREY, GREEN, ORANGE = "|cff999999", "|cff60e060", "|cffff9933"
local function Money(v) return ns.Tooltip.Money(v) end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

-- Anzeigename eines Markts: "PvE Allianz" statt "CAMWOW EU4 Realm 3 PvE / Alliance"
function G.MarketLabel(key)
    if type(key) ~= "string" then return "?" end
    local realm, faction = key:match("^(.*) / ([^/]+)$")
    if not realm then return key end
    local rule = realm:match("(%a+)%s*$") or realm
    local f = L["FACTION_" .. faction:upper()] or faction
    return rule .. " " .. f
end

-- Alter als Farbe: gruen bis 1 Tag, orange aelter, grau ohne Daten
local function AgeColor(t)
    if not t then return GREY end
    if time() - t <= 86400 then return GREEN end
    return ORANGE
end

-- Zeile Datenstand eines Markts
function G.StandLine(key, m)
    if type(m) ~= "table" then return nil end
    local parts = {}
    if m.lastScan then parts[#parts + 1] = L.PG_SCAN:format(ns.Scan.Age(m.lastScan)) end
    if m.mgrAt then parts[#parts + 1] = (m.mgrSrc == "api" and L.PG_API or L.PG_MANAGER):format(ns.Scan.Age(m.mgrAt)) end
    local n = 0
    for _ in pairs(m.items or {}) do n = n + 1 end
    parts[#parts + 1] = L.PG_ITEMS:format(n)
    local at = ns.Data.DataAt(m)
    return AgeColor(at) .. G.MarketLabel(key) .. "|r: " .. table.concat(parts, " · ")
end

---------------------------------------------------------------------------
-- Markt
---------------------------------------------------------------------------
G.minPct = 20
G.onlyStock = false

-- Vergleich Heimat gegen Neutral: { key, name, home, neutral, pct, better }
function G.CompareRows(minPct, onlyStock)
    local D = ns.Data
    local hk, nk = ns.HomeMarketKey(), ns.NeutralMarketKey()
    local hm, nm = D.Markets()[hk], D.Markets()[nk]
    local rows = {}
    if type(hm) ~= "table" or type(nm) ~= "table" or hk == nk then return rows end
    local cutH, cutN = D.Cut(hk), D.Cut(nk)
    for key, ne in pairs(nm.items or {}) do
        local he = hm.items and hm.items[key]
        if type(ne) == "table" and type(he) == "table" and Num(ne.m) and Num(he.m) and not ne.gone and not he.gone and he.m > 0 then
            local netH, netN = he.m * (1 - cutH), ne.m * (1 - cutN)
            local pct = math.floor((netN - netH) / netH * 100 + 0.5)
            local stockOk = true
            if onlyStock then
                local id = D.ItemID(key)
                local total = 0
                if ns.Stock then local _, _, t = ns.Stock.Counts(id, nil); total = t or 0 end
                stockOk = total > 0
            end
            if math.abs(pct) >= (minPct or 0) and stockOk then
                rows[#rows + 1] = { key = key, name = he.nm or ne.nm or D.ItemName(key, he) or tostring(key), quality = he.ql or ne.ql,
                    home = he.m, neutral = ne.m, pct = pct, better = pct > 0 and "neutral" or "home" }
            end
        end
    end
    return rows
end

function G.BuildMarket(c)
    local UI = Peon.UI
    G.stand = UI.Text(c, "small", "")
    G.stand:SetPoint("TOPLEFT", 8, -2)
    G.stand:SetPoint("RIGHT", c, "RIGHT", -8, 0)
    if G.stand.SetSpacing then G.stand:SetSpacing(3) end
    G.stockCheck = UI.Check(c, L.PG_ONLY_STOCK, G.onlyStock, function(on) G.onlyStock = on; mod:Call("Neutral", G.RefreshMarket) end)
    G.stockCheck:SetPoint("TOPLEFT", 4, -34)
    G.minBox = UI.Input(c, 60, { numeric = true })
    G.minRow = UI.FormRow(c, L.PG_MIN_PCT, G.minBox, 220, -36)
    G.minBox:SetText(tostring(G.minPct))
    G.minBox:SetScript("OnEditFocusLost", function(self) G.minPct = tonumber(self:GetText() or "") or 0; G.RefreshMarket() end)
    local p = UI.Panel(c, "list", true)
    p:SetPoint("TOPLEFT", 0, -70)
    p:SetPoint("BOTTOMRIGHT", 0, 0)
    G.comparePanel = p
    G.compare = UI.Table(p, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
              color = function(r) return UI.QualityColor(r.quality or 1) end },
            { key = "home", title = L.PG_COL_HOME, width = 110, align = "RIGHT", format = function(v) return Money(v) end },
            { key = "neutral", title = L.PG_COL_NEUTRAL, width = 110, align = "RIGHT", format = function(v) return Money(v) end },
            { key = "pct", title = L.PG_COL_DIFF, width = 100, align = "RIGHT",
              format = function(v) return (v > 0 and GREEN .. "+" or ORANGE) .. v .. " %|r" end,
              sort = function(r) return -math.abs(r.pct) end },
            { key = "better", title = L.PG_COL_BETTER, width = 100, align = "RIGHT",
              format = function(v) return v == "neutral" and L.FACTION_NEUTRAL or L.PG_HOME end },
        },
        sortKey = "pct", icon = true, empty = L.PG_COMPARE_EMPTY,
        onClick = function(r, button)
            local item = { id = ns.Data.ItemID(r.key), key = r.key, name = r.name }
            if button == "RightButton" then ns.Go.Menu(item, G.comparePanel) else mod:Call("Sprung", ns.Go.Item, item) end
        end,
        onEnter = function(row, r) if r then W.ShowItemTooltip(row, r.key) end end,
    })
    function G.compare:GetItems() return self.items end
    G.RefreshMarket()
end

function G.RefreshMarket()
    if not G.stand then return end
    local lines = {}
    local hk, nk = ns.HomeMarketKey(), ns.NeutralMarketKey()
    for _, key in ipairs({ hk, nk }) do
        local l = G.StandLine(key, ns.Data.Markets()[key])
        if l then lines[#lines + 1] = l end
    end
    if #lines == 0 then lines[1] = GREY .. L.PG_NO_DATA .. "|r" end
    G.stand:SetText(table.concat(lines, "\n"))
    if G.compare then
        local rows = G.CompareRows(G.minPct, G.onlyStock)
        for _, r in ipairs(rows) do r.icon = ns.Buy and ns.Buy.Icon(ns.Data.ItemID(r.key)) or nil end
        G.compare:SetData(rows)
    end
end

---------------------------------------------------------------------------
-- Quellen
---------------------------------------------------------------------------
function G.SourceLines()
    local lines = {}
    local D = ns.Data
    lines[#lines + 1] = "|cffffd100" .. L.PG_SRC_MARKETS .. "|r"
    local keys = {}
    for k in pairs(D.Markets()) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local m = D.Markets()[k]
        local l = G.StandLine(k, m)
        if l then
            if m.lastListings then l = l .. " · " .. L.PG_LISTINGS:format(m.lastListings) end
            lines[#lines + 1] = "  " .. l
        end
    end
    if #keys == 0 then lines[#lines + 1] = "  " .. GREY .. L.PG_NO_DATA .. "|r" end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cffffd100" .. L.PG_SRC_MANAGER .. "|r"
    local bridge = Peon.GetModule and Peon:GetModule("bridge")
    if not bridge then
        lines[#lines + 1] = "  " .. GREY .. L.PG_NO_BRIDGE .. "|r"
    else
        local ok, t, src, items = pcall(bridge.Current, bridge, ns.HomeMarketKey())
        if ok and Num(t) then
            local n = 0
            for _ in pairs(type(items) == "table" and items or {}) do n = n + 1 end
            lines[#lines + 1] = "  " .. GREEN .. L.PG_MANAGER_ON:format(src == "api" and L.PG_SRC_API or L.PG_SRC_SCAN, ns.Scan.Age(t), n) .. "|r"
        else
            lines[#lines + 1] = "  " .. ORANGE .. L.PG_MANAGER_OFF .. "|r"
        end
        local okb, band = pcall(D.ClientBand, 2770)
        lines[#lines + 1] = "  " .. GREY .. ((okb and band) and L.PG_BANDS_MANAGER or L.PG_BANDS_OWN) .. "|r"
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cffffd100" .. L.PG_SRC_CUT .. "|r"
    lines[#lines + 1] = "  " .. (ns.Cut and ns.Cut.Report() or "?")
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cffffd100" .. L.PG_SRC_LISTS .. "|r"
    local nl, ni, nw = 0, 0, 0
    for _, l in ipairs(ns.Buy and ns.Buy.Lists() or {}) do nl = nl + 1; for _ in pairs(l.items or {}) do ni = ni + 1 end end
    for _ in pairs(ns.Watch and ns.Watch.Store() or {}) do nw = nw + 1 end
    lines[#lines + 1] = "  " .. L.PG_LISTS_N:format(nl, ni, nw)
    if ns.Vendors and ns.Vendors.Summary then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "|cffffd100" .. L.PG_SRC_VENDORS .. "|r"
        lines[#lines + 1] = "  " .. ns.Vendors.Summary()
    end
    return lines
end

function G.BuildSources(c)
    local UI = Peon.UI
    local p = UI.Panel(c, "left")
    p:SetPoint("TOPLEFT", 0, 0)
    p:SetPoint("BOTTOMRIGHT", 0, 0)
    G.sources = UI.Text(p, "text", "")
    G.sources:SetPoint("TOPLEFT", 14, -14)
    G.sources:SetPoint("RIGHT", p, "RIGHT", -14, 0)
    if G.sources.SetSpacing then G.sources:SetSpacing(4) end
    G.sendButton = UI.Button(p, L.PG_SEND, 220, function() if ReloadUI then ReloadUI() end end)
    G.sendButton:SetPoint("BOTTOMLEFT", 12, 12)
    UI.SetTooltip(G.sendButton, { L.PG_SEND, L.PG_SEND_HINT })
    G.RefreshSources()
end

function G.RefreshSources()
    if not G.sources then return end
    G.sources:SetText(table.concat(G.SourceLines(), "\n"))
    local bridge = Peon.GetModule and Peon:GetModule("bridge")
    G.sendButton:SetShown(bridge ~= nil)
end

---------------------------------------------------------------------------
-- Auktionen unterwegs (ab 0.63, Neuaufbau N5, Konzept Abschnitt 4.5): der letzte bekannte Stand der eigenen
-- Auktionen, nur zum Lesen. Am Auktionator ist "Auktionen" Blizzards Seite mit Brokers Spalte (AuctionsAH.lua).
---------------------------------------------------------------------------
G.AUC_COLOR = { best = GREEN, under = ORANGE, sold = GREY }

-- Zeilen aus dem zuletzt gelesenen Stand (PeonBrokerDB.owned), bewertet mit den heutigen Preisdaten
function G.AuctionRows()
    local o = mod.acc and mod.acc.owned
    local rows = {}
    if type(o) ~= "table" or type(o.rows) ~= "table" then return rows, nil, nil end
    local items = type(ns.Data.Markets()[o.market]) == "table" and ns.Data.Markets()[o.market].items or {}
    for _, r in ipairs(o.rows) do
        if type(r) == "table" then
            local e = items[r.key]
            local other = type(e) == "table" and not e.gone and e.m or nil
            local status = "best"
            if r.sold then status = "sold"
            elseif Num(r.price) and Num(other) and other < r.price then status = "under" end
            rows[#rows + 1] = { key = r.key, name = r.name or tostring(r.key), quality = r.quality,
                icon = r.icon or (ns.Buy and ns.Buy.Icon(ns.Data.ItemID(r.key))) or nil,
                qty = r.qty or 1, price = r.price, other = other, status = status }
        end
    end
    return rows, o.t, o.market
end

function G.BuildAuctions(c)
    local UI = Peon.UI
    G.aucHead = UI.Text(c, "text", "")
    G.aucHead:SetPoint("TOPLEFT", 8, -6)
    G.aucHead:SetPoint("RIGHT", c, "RIGHT", -8, 0)
    local p = UI.Panel(c, "list", true)
    p:SetPoint("TOPLEFT", 0, -30)
    p:SetPoint("BOTTOMRIGHT", 0, 0)
    G.aucPanel = p
    G.auctions = UI.Table(p, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
              color = function(r) return UI.QualityColor(r.quality or 1) end },
            { key = "qty", title = L.ITEM_COL_QTY, width = 70, align = "RIGHT" },
            { key = "price", title = L.AUCP_COL_PRICE, width = 110, align = "RIGHT", format = function(v) return v and Money(v) or "–" end },
            { key = "other", title = L.BUY_COL_CHEAPEST, width = 110, align = "RIGHT", format = function(v) return v and Money(v) or "–" end },
            { key = "status", title = L.AUCP_COL_STATUS, width = 110, align = "RIGHT",
              format = function(v) return (G.AUC_COLOR[v] or "") .. (L["AUCP_ST_" .. tostring(v):upper()] or "") .. "|r" end,
              sort = function(r) return ({ under = 1, best = 2, sold = 3 })[r.status] or 9 end },
        },
        sortKey = "status", icon = true, empty = L.AUCP_EMPTY,
        onClick = function(r, button)
            ns.Go.Click(r, button, G.aucPanel, function() mod:Call("Sprung", ns.Go.Item, { key = r.key, name = r.name }) end)
        end,
        onEnter = function(row, r) if r then W.ShowItemTooltip(row, r.key) end end,
    })
    G.RefreshAuctions()
end

function G.RefreshAuctions()
    if not G.auctions then return end
    local rows, t, market = G.AuctionRows()
    G.auctions:SetData(rows)
    if t then
        local under = 0
        for _, r in ipairs(rows) do if r.status == "under" then under = under + 1 end end
        G.aucHead:SetText(L.AUCP_HEAD:format(#rows, under, ns.Scan.Age(t), G.MarketLabel(market)))
    else
        G.aucHead:SetText("")
    end
end

W.pages.market = { build = G.BuildMarket, refresh = G.RefreshMarket }
W.pages.sources = { build = G.BuildSources, refresh = G.RefreshSources }
W.pages.auctions = { build = G.BuildAuctions, refresh = G.RefreshAuctions }
