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
    local total = W.WIDTH - 24
    local stand = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    stand:SetPoint("TOPLEFT", 4, -2)
    stand:SetPoint("RIGHT", c, "RIGHT", -4, 0)
    stand:SetJustifyH("LEFT")
    stand:SetSpacing(3)
    G.stand = stand
    local inset = W.Inset(c)
    inset:SetPoint("TOPLEFT", 0, -48)
    inset:SetPoint("BOTTOMRIGHT", 0, 0)
    local title = inset:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetText(L.PG_COMPARE)
    G.compareTitle = title
    local cb = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPRIGHT", -200, -4)
    local cbl = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cbl:SetText(L.PG_ONLY_STOCK)
    cb:SetScript("OnClick", function(self) G.onlyStock = self:GetChecked() and true or false; G.RefreshMarket() end)
    G.stockCheck = cb
    local box = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
    box:SetSize(32, 20)
    box:SetAutoFocus(false)
    if box.SetNumeric then box:SetNumeric(true) end
    box:SetPoint("TOPRIGHT", -40, -5)
    box:SetText(tostring(G.minPct))
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self) G.minPct = tonumber(self:GetText() or "") or 0; G.RefreshMarket() end)
    local bl = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bl:SetPoint("RIGHT", box, "LEFT", -6, 0)
    bl:SetText(L.PG_MIN_PCT)
    local bl2 = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bl2:SetPoint("LEFT", box, "RIGHT", 4, 0)
    bl2:SetText("%")
    G.minBox = box
    local fixed = 90 + 90 + 80 + 80
    G.compare = Peon.NewList(inset, {
        columns = {
            { key = "name", title = L.COL_ITEM, width = total - 16 - 24 - fixed, format = function(v, r) return W.Colored(v, r.quality) end },
            { key = "home", title = L.PG_COL_HOME, width = 90, align = "RIGHT", format = function(v) return Money(v) end },
            { key = "neutral", title = L.PG_COL_NEUTRAL, width = 90, align = "RIGHT", format = function(v) return Money(v) end },
            { key = "pct", title = L.PG_COL_DIFF, width = 80, align = "RIGHT",
              format = function(v) return (v > 0 and GREEN .. "+" or ORANGE) .. v .. " %|r" end,
              sortValue = function(r) return -math.abs(r.pct) end },
            { key = "better", title = L.PG_COL_BETTER, width = 80, align = "RIGHT",
              format = function(v) return v == "neutral" and L.FACTION_NEUTRAL or L.PG_HOME end },
        },
        rows = 16, rowHeight = 18, sortKey = "pct",
        onClick = function(_, r) if ns.Menu then ns.Menu.Info({ id = ns.Data.ItemID(r.key), name = r.name }) end end,
        onEnter = function(_, r, row) W.ShowItemTooltip(row, r.key) end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
        emptyText = L.PG_COMPARE_EMPTY,
    })
    G.compare.frame:SetPoint("TOPLEFT", 4, -30)
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
    if G.compare then G.compare:SetData(G.CompareRows(G.minPct, G.onlyStock)) end
end

---------------------------------------------------------------------------
-- Beobachtung
---------------------------------------------------------------------------
function G.WatchRows()
    local rows = {}
    local Wt, D = ns.Watch, ns.Data
    if not Wt then return rows end
    for key, w in pairs(Wt.Store()) do
        local e = D.Lookup(key)
        local band
        if type(e) == "table" and e.m then
            local ok, v = pcall(D.Evaluate, e, key, 1, ns.VendorPrice(D.ItemID(key)), mod.db)
            band = ok and type(v) == "table" and v.band or nil
        end
        rows[#rows + 1] = { key = key, name = w.name or D.ItemName(key, e) or tostring(key), quality = w.q or (type(e) == "table" and e.ql),
            cheapest = type(e) == "table" and not e.gone and e.m or nil, limit = Wt.Limit(key, e), limitText = Wt.LimitText(key),
            band = band, hit = w.hit and true or false }
    end
    return rows
end

function G.BuildWatch(c)
    local total = W.WIDTH - 24
    local inset = W.Inset(c)
    inset:SetPoint("TOPLEFT", 0, 0)
    inset:SetPoint("BOTTOMRIGHT", 0, 0)
    local fixed = 90 + 110 + 130 + 70
    G.watchList = Peon.NewList(inset, {
        columns = {
            { key = "name", title = L.COL_ITEM, width = total - 16 - 24 - fixed, format = function(v, r) return W.Colored(v, r.quality) end },
            { key = "cheapest", title = L.BUY_COL_CHEAPEST, width = 90, align = "RIGHT", format = function(v) return v and Money(v) or "–" end },
            { key = "limitText", title = L.PG_COL_LIMIT, width = 110, align = "RIGHT", format = function(v) return v or (GREY .. L.MENU_WATCH_NONE .. "|r") end },
            { key = "band", title = L.TT_USUAL, width = 130, align = "RIGHT", format = function(v) return v and ns.Tooltip.RangeText(v) or "–" end,
              sortValue = function(r) return r.band and r.band.low or 0 end },
            { key = "hit", title = L.PG_COL_ALARM, width = 70, align = "RIGHT", format = function(v) return v and (GREEN .. L.PG_ALARM .. "|r") or "" end,
              sortValue = function(r) return r.hit and 0 or 1 end },
        },
        rows = 18, rowHeight = 18, sortKey = "hit", selectable = true,
        onClick = function(_, r) G.watchSel = r; G.UpdateWatchView() end,
        onEnter = function(_, r, row) W.ShowItemTooltip(row, r.key) end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
        emptyText = L.PG_WATCH_EMPTY,
    })
    G.watchList.frame:SetPoint("TOPLEFT", 4, -4)
    local function Btn(text, w, fn)
        local b = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetText(text)
        b:SetScript("OnClick", fn)
        return b
    end
    G.watchRemove = Btn(L.BUY_REMOVE, 100, function()
        if G.watchSel then ns.Watch.Remove(G.watchSel.key); G.watchSel = nil; G.RefreshWatch() end
    end)
    G.watchRemove:SetPoint("BOTTOMRIGHT", -8, 8)
    G.watchInfo = Btn(L.MENU_INFO, 110, function()
        if G.watchSel and ns.Menu then ns.Menu.Info({ id = ns.Data.ItemID(G.watchSel.key), name = G.watchSel.name }) end
    end)
    G.watchInfo:SetPoint("RIGHT", G.watchRemove, "LEFT", -6, 0)
    local box = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
    box:SetSize(60, 20)
    box:SetAutoFocus(false)
    box:SetPoint("BOTTOMLEFT", 110, 9)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self)
        if not G.watchSel or G.filling then return end
        local gold = tonumber((tostring(self:GetText() or ""):gsub(",", ".")))
        ns.Watch.SetLimit(G.watchSel.key, (gold and gold > 0) and "abs" or nil, gold and math.floor(gold * 10000 + 0.5) or nil)
        G.RefreshWatch()
    end)
    local bl = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bl:SetPoint("RIGHT", box, "LEFT", -6, 0)
    bl:SetText(L.PG_LIMIT_GOLD)
    G.watchBox = box
    G.RefreshWatch()
end

function G.UpdateWatchView()
    if not G.watchRemove then return end
    local sel = G.watchSel
    if sel then G.watchRemove:Enable(); G.watchInfo:Enable() else G.watchRemove:Disable(); G.watchInfo:Disable() end
    G.filling = true
    local w = sel and ns.Watch.Store()[sel.key]
    G.watchBox:SetText(w and w.lim and tostring(w.lim / 10000) or "")
    G.filling = false
end

function G.RefreshWatch()
    if not G.watchList then return end
    G.watchList:SetData(G.WatchRows())
    if G.watchSel then
        local found
        for _, r in ipairs(G.watchList:GetItems()) do if r.key == G.watchSel.key then found = r end end
        G.watchSel = found
        if found then G.watchList:Select(found) end
    end
    G.UpdateWatchView()
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
    local inset = W.Inset(c)
    inset:SetPoint("TOPLEFT", 0, 0)
    inset:SetPoint("BOTTOMRIGHT", 0, 0)
    local text = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 10, -10)
    text:SetPoint("RIGHT", inset, "RIGHT", -10, 0)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)
    G.sources = text
    local b = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    b:SetSize(200, 22)
    b:SetPoint("BOTTOMLEFT", 8, 8)
    b:SetText(L.PG_SEND)
    b:SetScript("OnClick", function() if ReloadUI then ReloadUI() end end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L.PG_SEND_HINT, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    G.sendButton = b
    G.RefreshSources()
end

function G.RefreshSources()
    if not G.sources then return end
    G.sources:SetText(table.concat(G.SourceLines(), "\n"))
    local bridge = Peon.GetModule and Peon:GetModule("bridge")
    G.sendButton:SetShown(bridge ~= nil)
end

W.pages.market = { build = G.BuildMarket, refresh = G.RefreshMarket }
W.pages.watch = { build = G.BuildWatch, refresh = G.RefreshWatch }
W.pages.sources = { build = G.BuildSources, refresh = G.RefreshSources }
