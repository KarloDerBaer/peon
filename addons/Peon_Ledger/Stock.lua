-- Peon_Ledger - Stock.lua
-- Reiter "Bestand": "Was habe ich wo?" (ab 0.14 mit Peon.UI, Konzept Peon_Ledger_Neuaufbau.md Abschnitt 6.2)
-- Oben Suche, Auswahl Charakter (alle oder einzeln) und Ort. Tabelle: Gegenstand, Menge, Wo, Kosten Ø, Zuletzt
-- (zuletzt gezahlt), Marktwert. Ab 0.14 auch Ware in der Post (gekauft, noch nicht abgeholt).
-- Klick: Gegenstand in Broker (Seite Gegenstand), Rechtsklick: Gegenstandsmenue.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local S = {}
ns.Stock = S

local GREY = W.GREY
S.PLACES = { "bags", "bank", "mail", "auctions", "equip", "transit" }

-- "Mirel: Taschen 5, Bank 15 · Borin: Post 3"
function S.WhereText(e, oneChar)
    local parts, me = {}, ns.CharName()
    local names = {}
    for name in pairs(e.where) do names[#names + 1] = name end
    table.sort(names, function(a, b) if (a == me) ~= (b == me) then return a == me end return a < b end)
    for _, name in ipairs(names) do
        local p = S.PlacesText(e.where[name])
        parts[#parts + 1] = oneChar and p or (ns.Tooltip.Short(name) .. ": " .. p)
    end
    if e.warband then parts[#parts + 1] = L.PLACE_WARBAND .. " " .. e.warband end
    return table.concat(parts, " · ")
end

function S.PlacesText(places)
    local parts = {}
    for _, place in ipairs(S.PLACES) do
        if places[place] then parts[#parts + 1] = L["PLACE_" .. place:upper()] .. " " .. places[place] end
    end
    return table.concat(parts, ", ")
end

-- Alle Gegenstaende nach Auswahl: char ("*" oder Name), place ("all" oder Ort)
function S.Collect(char, place)
    local I = ns.Inventory
    local out = {}
    local function Add(id, name, pl, n, bound)
        local e = out[id]
        if not e then e = { total = 0, where = {}, bound = 0 }; out[id] = e end
        e.total = e.total + n
        e.bound = e.bound + (bound or 0)
        e.where[name] = e.where[name] or {}
        e.where[name][pl] = (e.where[name][pl] or 0) + n
    end
    for name, c in pairs(I.RealmData().chars) do
        if char == "*" or char == name then
            for _, pl in ipairs(S.PLACES) do
                if place == "all" or place == pl then
                    local p = c.places and c.places[pl]
                    if type(p) == "table" and type(p.items) == "table" then
                        for id, n in pairs(p.items) do
                            if n > 0 then Add(id, name, pl, n, I.BoundIn(p, pl, id, n)) end
                        end
                    end
                end
            end
        end
    end
    if char == "*" and (place == "all" or place == "warband") then
        local wb = I.RealmData().account.places.warband
        if type(wb) == "table" and type(wb.items) == "table" then
            for id, n in pairs(wb.items) do
                local e = out[id]
                if not e then e = { total = 0, where = {}, bound = 0 }; out[id] = e end
                e.total = e.total + n
                e.warband = (e.warband or 0) + n
            end
        end
    end
    return out
end

function S.Rows()
    local filter = S.search and W.Lower(S.search) or ""
    local char = mod.db.stockChar or "*"
    if char ~= "*" and not ns.Inventory.RealmData().chars[char] then char = "*" end
    local rows = {}
    for id, e in pairs(S.Collect(char, mod.db.stockPlace or "all")) do
        local name, quality, icon = ns.Inventory.ItemInfo(id)
        name = name or ("#" .. id)
        if filter == "" or W.Lower(name):find(filter, 1, true) then
            local info = ns.Cost and ns.Cost.Info(id, char)
            local last = ns.Last and ns.Last.Buy(id)
            rows[#rows + 1] = { id = id, name = name, quality = quality, icon = icon, total = e.total,
                where = S.WhereText(e, char ~= "*"),
                cost = info and info.avg or nil, lager = info and info.value or nil,
                last = last and last.unit or nil, lastInfo = last,
                value = ns.Worth(id, e.total, e.bound) }
        end
    end
    return rows
end

function S.Refresh()
    if not S.table then return end
    if S.charDD and S.charDD.GenerateMenu then pcall(S.charDD.GenerateMenu, S.charDD) end
    local rows = S.Rows()
    S.table:SetData(rows)
    local sum, lager = 0, 0
    for _, r in ipairs(rows) do sum = sum + (r.value or 0); lager = lager + (r.lager or 0) end
    S.sums = { n = #rows, value = sum, lager = lager }
end

function S.Status()
    local s = S.sums
    if not s then return nil end
    local t = ns.Plural(s.n, "STOCK_COUNT")
    if ns.HasBroker() then t = t .. "  ·  " .. L.STOCK_VALUE:format(ns.Money(s.value, true)) end
    return t .. "  ·  " .. L.STOCK_LAGER:format(ns.Money(math.floor(s.lager + 0.5), true))
end

local SRC = { ah = "SRC_AH", vendor = "SRC_VENDOR", cod = "SRC_COD", trade = "SRC_TRADE" }
function S.SourceText(src) return L[SRC[src] or "SRC_AH"] end

function S.RowTooltip(row, r)
    W.ShowItemTooltip(row, r.id)
    if not GameTooltip then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(r.where, 0.8, 0.8, 0.8, true)
    if r.lastInfo then
        local l = r.lastInfo
        GameTooltip:AddLine(L.LAST_BUY_TT:format(ns.Money(math.floor(l.unit + 0.5)), l.n, S.SourceText(l.src), date("%d.%m.", l.t)), 0.8, 0.8, 0.8)
    end
    local sale = ns.Last and ns.Last.Sale(r.id)
    if sale then
        GameTooltip:AddLine(L.LAST_SALE_TT:format(ns.Money(math.floor(sale.unit + 0.5)), sale.n, S.SourceText(sale.src), date("%d.%m.", sale.t)), 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine(L.STOCK_CLICK_HINT, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

function S.Build(c)
    local U = Peon.UI
    local a = W.Area()
    S.searchBox = U.SearchBox(c, 220, function(text)
        S.search = text
        mod:Call("Bestand", W.Refresh)
    end)
    S.searchBox:SetPoint("TOPLEFT", 80, -32)
    S.charDD = U.Dropdown(c, 170, W.CharItems, function() return mod.db.stockChar or "*" end,
        function(v) mod.db.stockChar = v; mod:Call("Bestand", W.Refresh) end)
    S.charDD:SetPoint("LEFT", S.searchBox, "RIGHT", 12, 0)
    local places = { { "all", L.ALL_PLACES } }
    for _, pl in ipairs(S.PLACES) do places[#places + 1] = { pl, L["PLACE_" .. pl:upper()] } end
    S.placeDD = U.Dropdown(c, 130, places, function() return mod.db.stockPlace or "all" end,
        function(v) mod.db.stockPlace = v; mod:Call("Bestand", W.Refresh) end)
    S.placeDD:SetPoint("LEFT", S.charDD, "RIGHT", 8, 0)
    local panel = U.Panel(c, "list", true)
    panel:SetPoint("TOPLEFT", a.left, -a.top)
    panel:SetPoint("BOTTOMRIGHT", -a.right, a.bottom)
    S.table = U.Table(panel, {
        icon = true,
        columns = {
            { key = "name", title = L.COL_ITEM, format = function(v, r) return W.Colored(v, r.quality) end, sort = function(r) return W.Lower(r.name) end },
            { key = "total", title = L.COL_TOTAL, width = 60, align = "RIGHT" },
            { key = "where", title = L.COL_WHERE, width = 230, font = "GameFontHighlightSmall", sort = function(r) return W.Lower(r.where) end },
            { key = "cost", title = L.COL_COST, width = 95, align = "RIGHT", format = function(v) return W.MoneyOr(v) end },
            { key = "last", title = L.COL_LAST, width = 95, align = "RIGHT", format = function(v) return W.MoneyOr(v) end },
            { key = "value", title = L.COL_VALUE, width = 95, align = "RIGHT", format = function(v) return W.MoneyOr(v) end },
        },
        sortKey = "name",
        empty = L.STOCK_EMPTY,
        onEnter = function(row, r) S.RowTooltip(row, r) end,
        onClick = function(r, button)
            if button == "RightButton" then W.ItemMenu(r.id) elseif r.id then mod:ShowItem(r.id) end
        end,
    })
end

W.pages.stock = { build = S.Build, refresh = S.Refresh, status = S.Status }
