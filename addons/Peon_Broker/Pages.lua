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

-- Anteil des Hauses fuer den Vergleich: gemessen, sonst fuer Neutral die Annahme (ab 0.127.0, Marktvergleich 3.3)
function G.CutOf(market)
    local D = ns.Data
    if D.CutSure(market) then return D.Cut(market) end
    return ns.Cut and ns.Cut.Guess and ns.Cut.Guess(market) or D.Cut(market)
end

-- Absatz je Tag vom Manager (ueber Peon_Bridge), nil ohne Wert (ab 0.127.0)
function G.SalesPerDay(key, market)
    local c = Peon.GetModule and Peon:GetModule("bridge")
    if not c or type(c.Sales) ~= "function" then return nil end
    local ok, v = pcall(c.Sales, c, key, market)
    if ok and type(v) == "table" and Num(v.perDay) then return v.perDay end
    return nil
end

-- Unterschied nach Gebuehr fuer die bessere Richtung: im einen Haus kaufen, im anderen nach Gebuehr verkaufen.
-- Rueckgabe pct (Gewinn in Prozent des Kaufpreises, negativ = Verlust in beiden Richtungen) und better ("neutral",
-- "home" oder nil ohne Gewinn)
function G.Spread(home, neutral, cutH, cutN)
    local toN = (neutral * (1 - cutN) - home) / home
    local toH = (home * (1 - cutH) - neutral) / neutral
    local best, dir = toN, "neutral"
    if toH > toN then best, dir = toH, "home" end
    local pct = math.floor(best * 100 + 0.5)
    return pct, pct > 0 and dir or nil
end

-- Vergleich Heimat gegen Neutral: { key, name, home, neutral, pct, better, salesH, salesN }
-- search (ab 0.127.0): Teil des Namens. Mit Suchtext gilt der Mindestunterschied nicht und Gegenstaende aus nur einem
-- Markt stehen mit fehlendem Preis in der Liste (Konzept Peon_Broker_Marktvergleich.md 6.1).
-- Ab 0.127.0 zaehlt der Unterschied je Richtung (kaufen zum Preis, verkaufen nach Gebuehr), vorher beide nach Gebuehr.
function G.CompareRows(minPct, onlyStock, search)
    local D = ns.Data
    local hk, nk = ns.HomeMarketKey(), ns.NeutralMarketKey()
    local hm, nm = D.Markets()[hk], D.Markets()[nk]
    local rows = {}
    if type(hm) ~= "table" or type(nm) ~= "table" or hk == nk then return rows end
    local cutH, cutN = G.CutOf(hk), G.CutOf(nk)
    local needle = type(search) == "string" and (search:gsub("^%s+", ""):gsub("%s+$", "")) or ""
    needle = needle ~= "" and W.Lower(needle) or nil
    local function Live(e) return type(e) == "table" and Num(e.m) and not e.gone and e.m > 0 end
    local function StockOk(key)
        if not onlyStock then return true end
        local total = 0
        if ns.Stock then local _, _, t = ns.Stock.Counts(D.ItemID(key), nil); total = t or 0 end
        return total > 0
    end
    local seen = {}
    local function Add(key)
        if seen[key] then return end
        seen[key] = true
        local he, ne = hm.items and hm.items[key], nm.items and nm.items[key]
        local hOk, nOk = Live(he), Live(ne)
        if not (hOk or nOk) then return end
        local name = (type(he) == "table" and he.nm) or (type(ne) == "table" and ne.nm) or D.ItemName(key, hOk and he or ne) or tostring(key)
        if needle then
            if not W.Lower(name):find(needle, 1, true) then return end
        elseif not (hOk and nOk) then
            return
        end
        local pct, better
        if hOk and nOk then
            pct, better = G.Spread(he.m, ne.m, cutH, cutN)
            if not needle and pct < (minPct or 0) then return end
        end
        if not StockOk(key) then return end
        rows[#rows + 1] = { key = key, name = name, quality = (type(he) == "table" and he.ql) or (type(ne) == "table" and ne.ql),
            home = hOk and he.m or nil, neutral = nOk and ne.m or nil, pct = pct, better = better,
            salesH = G.SalesPerDay(key, hk), salesN = G.SalesPerDay(key, nk) }
    end
    for key in pairs(nm.items or {}) do Add(key) end
    if needle then for key in pairs(hm.items or {}) do Add(key) end end
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
    -- ab 0.127.0: Suche nach Gegenstaenden (Marktvergleich 6.1)
    G.search = UI.SearchBox(c, 220, function(text)
        if text == (G.searchText or "") then return end
        G.searchText = text
        mod:Call("Neutral", G.RefreshMarket)
    end)
    G.search:SetPoint("TOPRIGHT", -8, -36)
    local p = UI.Panel(c, "list", true)
    p:SetPoint("TOPLEFT", 0, -70)
    p:SetPoint("BOTTOMRIGHT", 0, 0)
    G.comparePanel = p
    G.compare = UI.Table(p, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
              color = function(r) return UI.QualityColor(r.quality or 1) end },
            { key = "home", title = L.PG_COL_HOME, width = 100, align = "RIGHT", format = function(v) return v and Money(v) or GREY .. L.PG_MISSING .. "|r" end },
            { key = "neutral", title = L.PG_COL_NEUTRAL, width = 100, align = "RIGHT", format = function(v) return v and Money(v) or GREY .. L.PG_MISSING .. "|r" end },
            { key = "pct", title = L.PG_COL_DIFF, width = 90, align = "RIGHT",
              format = function(v) if not v then return GREY .. "-|r" end return (v > 0 and GREEN .. "+" or GREY) .. v .. " %|r" end,
              sort = function(r) return r.pct and -r.pct or nil end },
            { key = "salesH", title = L.PG_COL_SALES_H, width = 70, align = "RIGHT", format = function(v) return G.FmtSales(v) end },
            { key = "salesN", title = L.PG_COL_SALES_N, width = 70, align = "RIGHT", format = function(v) return G.FmtSales(v) end },
            { key = "better", title = L.PG_COL_BETTER, width = 100, align = "RIGHT",
              format = function(v) if not v then return "" end return v == "neutral" and L.PG_DIR_TO_NEUTRAL or L.PG_DIR_TO_HOME end },
        },
        sortKey = "pct", icon = true, empty = L.PG_COMPARE_EMPTY,
        onClick = function(r, button)
            local item = { id = ns.Data.ItemID(r.key), key = r.key, name = r.name }
            if button == "RightButton" then ns.Go.Menu(item, G.comparePanel) else mod:Call("Sprung", ns.Go.Item, item) end
        end,
        onEnter = function(row, r) if r then G.CompareTooltip(row, r) end end,
    })
    function G.compare:GetItems() return self.items end
    G.RefreshMarket()
end

-- Absatz je Tag kurz: "12", "1,5", "<0,1", ohne Wert "-"
function G.FmtSales(v)
    if not Num(v) then return GREY .. "-|r" end
    if v >= 10 then return tostring(math.floor(v + 0.5)) end
    if v < 0.1 then return "<0,1" end
    return (("%.1f"):format(v):gsub("%.", ","))
end

-- Tooltip einer Zeile: Gegenstand, dazu beide Haeuser mit Gebuehr und Absatz, und der Satz des Managers
function G.CompareTooltip(row, r)
    W.ShowItemTooltip(row, r.key)
    if not GameTooltip or not GameTooltip.AddLine then return end
    local hk, nk = ns.HomeMarketKey(), ns.NeutralMarketKey()
    GameTooltip:AddLine(" ")
    for _, x in ipairs({ { hk, r.home, r.salesH }, { nk, r.neutral, r.salesN } }) do
        local cut = G.CutOf(x[1])
        GameTooltip:AddDoubleLine(G.MarketLabel(x[1]), (x[2] and Money(x[2]) or L.PG_MISSING), 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddLine(L.PG_TIP_CUT:format(("%.0f"):format(cut * 100), ns.Data.CutSure(x[1]) and "" or L.PG_TIP_GUESS) ..
            "  " .. L.PG_TIP_SALES:format(G.FmtSales(x[3])), 0.7, 0.7, 0.7)
    end
    local say = ns.Trade and ns.Trade.Say and ns.Trade.Say(r.key)
    if say then GameTooltip:AddLine(" "); GameTooltip:AddLine(say, 0.6, 0.9, 1, true) end
    GameTooltip:Show()
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
        local rows = G.CompareRows(G.minPct, G.onlyStock, G.searchText)
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
