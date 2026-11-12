-- Peon_Ledger - Stock.lua
-- Reiter "Bestand": "Was habe ich wo?" (ab 0.14 mit Peon.UI, Konzept Peon_Ledger_Neuaufbau.md Abschnitt 6.2)
-- Oben Suche, Auswahl Charakter (alle oder einzeln) und Ort. Tabelle: Gegenstand, Menge, Wo, Kosten Ø, Zuletzt
-- (zuletzt gezahlt), Marktwert. Ab 0.14 auch Ware in der Post (gekauft, noch nicht abgeholt).
-- Klick: Gegenstand in Broker (Seite Gegenstand), Rechtsklick: Gegenstandsmenue.
-- Ab 0.14.2: Kategorie oben (Ausruestung, Handelswaren, Verbrauchbares ...) und unten eine Summenzeile
-- (Anzahl, Stueck, Lagerwert, zuletzt gezahlt, Marktwert der angezeigten Gegenstaende).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local S = {}
ns.Stock = S

local GREY = W.GREY
S.PLACES = { "bags", "bank", "mail", "auctions", "equip", "transit" }

-- Kategorien nach Blizzards Gegenstandsklasse (C_Item.GetItemInfoInstant, 6. Wert), gemerkt in items[id].c
S.CATS = {
    { key = "all" },
    { key = "equip",   classes = { [2] = true, [4] = true } },          -- Waffe, Ruestung
    { key = "trade",   classes = { [7] = true, [5] = true, [3] = true } }, -- Handelswaren, Reagenzien, Edelsteine
    { key = "consum",  classes = { [0] = true } },                       -- Verbrauchbares
    { key = "recipe",  classes = { [9] = true } },                       -- Rezepte
    { key = "bag",     classes = { [1] = true, [11] = true } },          -- Behaelter, Koecher
    { key = "quest",   classes = { [12] = true } },                      -- Quest
    { key = "other" },                                                   -- alles andere
}

function S.ItemClass(id)
    local it = mod.acc.items and mod.acc.items[id]
    if type(it) == "table" and type(it.c) == "number" then return it.c end
    local CI = rawget(_G, "C_Item")
    local fn = (CI and CI.GetItemInfoInstant) or rawget(_G, "GetItemInfoInstant")
    if type(fn) ~= "function" then return nil end
    local ok, _, _, _, _, _, classID = pcall(fn, id)
    if ok and type(classID) == "number" and not Peon.IsSecret(classID) then
        if type(it) ~= "table" then
            mod.acc.items = mod.acc.items or {}
            it = {}
            mod.acc.items[id] = it
        end
        it.c = classID
        return classID
    end
    return nil
end

function S.InCat(id, cat)
    if not cat or cat == "all" then return true end
    local c = S.ItemClass(id)
    if cat == "other" then
        for _, d in ipairs(S.CATS) do if d.classes and c and d.classes[c] then return false end end
        return true
    end
    for _, d in ipairs(S.CATS) do if d.key == cat then return c ~= nil and d.classes[c] == true end end
    return true
end

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
    local cat = mod.db.stockCat or "all"
    for id, e in pairs(S.Collect(char, mod.db.stockPlace or "all")) do
        local name, quality, icon = ns.Inventory.ItemInfo(id)
        name = name or ("#" .. id)
        if (filter == "" or W.Lower(name):find(filter, 1, true)) and S.InCat(id, cat) then
            local info = ns.Cost and ns.Cost.Info(id, char)
            local last = ns.Last and ns.Last.Buy(id)
            local value = ns.Worth(id, e.total, e.bound)
            -- offener Gewinn (ab 0.14.5): Marktwert der Stuecke ohne Startbestand minus ihre Lagerkosten
            local open
            if value and info and e.total > 0 then
                local own = math.min(e.total, info.n - (info.sn or 0))
                if own > 0 then open = value * own / e.total - info.value end
            end
            rows[#rows + 1] = { id = id, name = name, quality = quality, icon = icon, total = e.total,
                where = S.WhereText(e, char ~= "*"),
                cost = info and info.avg or nil, lager = info and info.value or nil,
                startN = info and info.sn or 0, startAll = info and (info.sn or 0) >= info.n,
                last = last and last.unit or nil, lastInfo = last,
                value = value, open = open }
        end
    end
    return rows
end

function S.Refresh()
    if not S.table then return end
    if S.charDD and S.charDD.GenerateMenu then pcall(S.charDD.GenerateMenu, S.charDD) end
    local rows = S.Rows()
    S.table:SetData(rows)
    local sum, lager, pieces, last, open = 0, 0, 0, 0, 0
    for _, r in ipairs(rows) do
        sum = sum + (r.value or 0); lager = lager + (r.lager or 0); pieces = pieces + (r.total or 0)
        last = last + (r.last or 0) * (r.total or 0)
        open = open + (r.open or 0)
    end
    S.sums = { n = #rows, value = sum, lager = lager, pieces = pieces, last = last, open = open }
    S.UpdateFooter()
end

-- Summenzeile unter der Tabelle: Werte genau unter ihren Spalten
function S.UpdateFooter()
    local f = S.footer
    local s = S.sums
    if not f or not s then return end
    if S.table.Layout then S.table.Layout() end
    local x = 4
    local right = {}
    for i, c in ipairs(S.table.o.columns) do
        x = x + (c.cur or c.width or 100) - 2
        right[c.key] = x
    end
    local function Put(fs, key, text)
        fs:ClearAllPoints()
        fs:SetPoint("RIGHT", f, "LEFT", (right[key] or 0) - 6, 0)
        fs:SetText(text)
    end
    f.label:SetText(L.STOCK_SUM:format(ns.Plural(s.n, "STOCK_COUNT")))
    Put(f.total, "total", tostring(s.pieces))
    Put(f.cost, "cost", s.lager > 0 and ns.Money(math.floor(s.lager + 0.5), true) or "")
    Put(f.last, "last", s.last > 0 and ns.Money(math.floor(s.last + 0.5), true) or "")
    Put(f.value, "value", ns.HasBroker() and ns.Money(math.floor(s.value + 0.5), true) or "")
    Put(f.open, "open", ns.HasBroker() and W.Signed(s.open) or "")
    f.texts = { label = f.label.text, total = f.total.text, cost = f.cost.text, last = f.last.text, value = f.value.text, open = f.open.text }
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
    if (r.startN or 0) > 0 then GameTooltip:AddLine(L.STOCK_START_TT:format(r.startN), 1, 0.82, 0, true) end
    if r.open then GameTooltip:AddLine(L.STOCK_OPEN_TT, 0.6, 0.6, 0.6, true) end
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
    local cats = {}
    for _, d in ipairs(S.CATS) do cats[#cats + 1] = { d.key, L["STOCK_CAT_" .. d.key:upper()] } end
    S.catDD = U.Dropdown(c, 150, cats, function() return mod.db.stockCat or "all" end,
        function(v) mod.db.stockCat = v; mod:Call("Bestand", W.Refresh) end)
    S.catDD:SetPoint("LEFT", S.placeDD, "RIGHT", 8, 0)
    local footH = 26
    local panel = U.Panel(c, "list", true)
    panel:SetPoint("TOPLEFT", a.left, -a.top)
    panel:SetPoint("BOTTOMRIGHT", -a.right, a.bottom + footH)
    local foot = U.Panel(c, "list")
    foot:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", -a.right, a.bottom)
    foot.label = foot:CreateFontString(nil, "ARTWORK", U.FONT.label)
    foot.label:SetPoint("LEFT", 30, 0)
    for _, k in ipairs({ "total", "cost", "last", "value", "open" }) do
        foot[k] = foot:CreateFontString(nil, "ARTWORK", U.FONT.number)
        foot[k]:SetJustifyH("RIGHT")
    end
    S.footer = foot
    S.table = U.Table(panel, {
        icon = true,
        columns = {
            { key = "name", title = L.COL_ITEM, format = function(v, r) return W.Colored(v, r.quality) end, sort = function(r) return W.Lower(r.name) end },
            { key = "total", title = L.COL_TOTAL, width = 56, align = "RIGHT" },
            { key = "where", title = L.COL_WHERE, width = 180, font = "GameFontHighlightSmall", sort = function(r) return W.Lower(r.where) end },
            { key = "cost", title = L.COL_COST, width = 88, align = "RIGHT",
              format = function(v, r) if r.startAll then return GREY .. "0 · " .. L.STOCK_START .. "|r" end return W.MoneyOr(v) end },
            { key = "last", title = L.COL_LAST, width = 84, align = "RIGHT", format = function(v) return W.MoneyOr(v) end },
            { key = "value", title = L.COL_VALUE, width = 88, align = "RIGHT", format = function(v) return W.MoneyOr(v) end },
            { key = "open", title = L.COL_OPEN, width = 96, align = "RIGHT", format = function(v) return v and W.Signed(v) or (GREY .. "–|r") end,
              sort = function(r) return r.open or -math.huge end },
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
