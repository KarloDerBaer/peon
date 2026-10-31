-- Peon_Ledger - Catalog.lua
-- Reiter "Gegenstaende" (ab 0.10): alle bekannten Gegenstaende – Bestand aller Charaktere, Verlauf,
-- gemerkte Namen und (mit Peon_Broker) alle Gegenstaende des aktuellen Markts. Suche nach Namensteil oder
-- Nummer, Filter (alle / im Bestand / im Verlauf / im Auktionshaus). Klick oeffnet den Reiter "Gegenstand".
-- Der bisherige Reiter "Gegenstaende" (Zu/Ab, Verkaufsquote, Gewinn je Gegenstand) heisst jetzt "Umsatz".

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local CT = {}
ns.Catalog = CT

local GREY = "|cff999999"
local QMARK = "Interface\\Icons\\INV_Misc_QuestionMark"

local function Num(v) return type(v) == "number" and v == v and not Peon.IsSecret(v) end

local function Broker()
    if not Peon.GetModule then return nil end
    local ok, b = pcall(Peon.GetModule, Peon, "broker")
    if ok and type(b) == "table" and type(b.MarketItems) == "function" then return b end
    return nil
end

-- Gegenstaende aus dem Verlauf: zuletzt bewegt je itemID
local function Moved()
    local out = {}
    local ok, list = pcall(ns.Moves.List)
    if not ok or type(list) ~= "table" then return out end
    for _, e in ipairs(list) do
        if Num(e.id) and Num(e.t) and (not out[e.id] or e.t > out[e.id]) then out[e.id] = e.t end
    end
    return out
end

-- Name ohne Nachladen vom Server: gemerkt (Ledger), sonst Broker, erst dann das Spiel
local function Info(id, b)
    local it = mod.acc and type(mod.acc.items) == "table" and mod.acc.items[id] or nil
    if type(it) == "table" and it.n then return it.n, it.q, it.i end
    if b and b.name then
        local icon
        local CI = rawget(_G, "C_Item")
        if CI and CI.GetItemIconByID then local ok, ic = pcall(CI.GetItemIconByID, id); if ok then icon = ic end end
        return b.name, b.quality, icon
    end
    return ns.Inventory.ItemInfo(id)
end

function CT.Rows()
    local filter = CT.search and W.Lower(CT.search) or ""
    local fid = tonumber(filter)
    local mode = mod.db.catalogFilter or "all"
    local stock = ns.Inventory.AllItems()
    local moved = Moved()
    local br = Broker()
    local market = {}
    if br then local ok, m = pcall(br.MarketItems, br); if ok and type(m) == "table" then market = m end end
    local ids = {}
    local function Add(id) if Num(id) then ids[id] = true end end
    if mode == "all" or mode == "stock" then for id in pairs(stock) do Add(id) end end
    if mode == "all" or mode == "moved" then for id in pairs(moved) do Add(id) end end
    if mode == "all" or mode == "ah" then for id in pairs(market) do Add(id) end end
    if mode == "all" and mod.acc and type(mod.acc.items) == "table" then
        for id in pairs(mod.acc.items) do Add(id) end
    end
    local rows = {}
    for id in pairs(ids) do
        local b = market[id]
        local name, quality, icon = Info(id, b)
        name = name or ("#" .. id)
        if filter == "" or (fid and fid == id) or W.Lower(name):find(filter, 1, true) then
            local s = stock[id]
            local last = moved[id]
            if b and Num(b.t) and (not last or b.t > last) then last = b.t end
            rows[#rows + 1] = { id = id, name = name, quality = quality, icon = icon,
                total = s and s.total or nil, min = b and not b.gone and b.min or nil, qty = b and (b.gone and 0 or b.qty) or nil,
                last = last }
        end
    end
    return rows
end

-- Kosten (alle Charaktere) und Haendlerpreis erst beim Anzeigen (nur sichtbare Zeilen)
local function Cost(r)
    if r.cost == nil then
        local ok, info = pcall(ns.Cost.Info, r.id, "*")
        r.cost = (ok and type(info) == "table" and info.avg) or false
    end
    return r.cost or nil
end

local function Vendor(r)
    if r.vendor == nil then
        local p = ns.Moves.SellPrice and ns.Moves.SellPrice(r.id)
        r.vendor = (Num(p) and p > 0) and p or false
    end
    return r.vendor or nil
end

function CT.Refresh()
    if not CT.list then return end
    if CT.filterDD and CT.filterDD.Update then CT.filterDD.Update() end
    local rows = CT.Rows()
    CT.list:SetData(rows)
    CT.count:SetText(GREY .. L.CAT_COUNT:format(#rows) .. "|r")
end

local function MoneyOrDash(v) return Num(v) and ns.Money(math.floor(v + 0.5)) or (GREY .. "–|r") end

function CT.Build(c)
    local inset = W.Inset(c)
    inset:SetAllPoints()
    local total = W.WIDTH - 24 - 8 - 24
    CT.list = Peon.NewList(inset, {
        columns = {
            { key = "name", title = L.COL_ITEM, width = 230,
              format = function(v, r) return "|T" .. tostring(r.icon or QMARK) .. ":16:16:0:0|t " .. W.Colored(v, r.quality) end,
              sortValue = function(r) return W.Lower(r.name) end },
            { key = "total", title = L.CAT_COL_STOCK, width = 60, align = "RIGHT",
              format = function(v) return v and tostring(v) or (GREY .. "–|r") end },
            { key = "cost", title = L.CAT_COL_COST, width = 80, align = "RIGHT",
              format = function(_, r) return MoneyOrDash(Cost(r)) end, sortValue = function(r) return Cost(r) end },
            { key = "min", title = L.CAT_COL_MIN, width = 80, align = "RIGHT", format = function(v) return MoneyOrDash(v) end },
            { key = "qty", title = L.CAT_COL_QTY, width = 65, align = "RIGHT",
              format = function(v) return v and tostring(math.floor(v + 0.5)) or (GREY .. "–|r") end },
            { key = "vendor", title = L.CAT_COL_VENDOR, width = 75, align = "RIGHT",
              format = function(_, r) return MoneyOrDash(Vendor(r)) end, sortValue = function(r) return Vendor(r) end },
            { key = "last", title = L.CAT_COL_LAST, width = total - 590, align = "RIGHT",
              format = function(v) return v and ns.Age(v) or (GREY .. "–|r") end },
        },
        rows = 16, rowHeight = 19, sortKey = "name",
        onEnter = function(list, r, row) W.ShowItemTooltip(row, r.id) end,
        onClick = function(list, r, button) if button == "LeftButton" and r.id then mod:ShowItem(r.id) end end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
        emptyText = L.CAT_EMPTY,
    })
    CT.list.frame:SetPoint("TOPLEFT", 4, -34)
    local box = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
    box:SetSize(200, 20)
    box:SetPoint("TOPLEFT", 14, -8)
    box:SetAutoFocus(false)
    box:SetScript("OnTextChanged", function(self) CT.search = self:GetText(); mod:Call("Gegenstaende", CT.Refresh) end)
    box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    CT.searchBox = box
    local label = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    label:SetText(GREY .. L.STOCK_SEARCH .. "|r")
    CT.filterDD = W.Dropdown(inset, 170, {
        { "all", L.CAT_FILTER_ALL }, { "stock", L.CAT_FILTER_STOCK }, { "moved", L.CAT_FILTER_MOVED }, { "ah", L.CAT_FILTER_AH },
    }, function() return mod.db.catalogFilter or "all" end, function(v) mod.db.catalogFilter = v; mod:Call("Gegenstaende", CT.Refresh) end)
    CT.filterDD:SetPoint("TOPRIGHT", -12, -6)
    CT.count = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    CT.count:SetPoint("BOTTOMLEFT", 10, 12)
end

W.pages.catalog = { build = CT.Build, refresh = CT.Refresh }
