-- Peon_Ledger - Chars.lua
-- Reiter "Charaktere" (ab 0.18, Konzept Peon_Ledger_Schlank.md Abschnitt 3, ersetzt den Reiter Bestand):
-- "Was liegt wo, bei welchem Charakter?"
--   links die Charaktere des Realms (oben "Alle Charaktere"), rechts der Inhalt des gewaehlten Charakters nach Ort
--   gegliedert. Jeder Ort ist eine Kopfzeile zum Auf- und Zuklappen mit Plaetzen, Stueck und Alter des Stands (ab 7
--   Tagen gelb). Taschen und Angelegt sind offen, der Rest zu. Darunter je Gegenstand eine Zeile (Symbol, Name, Stueck),
--   nach Kategorie wie in Bags, darin nach Name.
--   Oben eine Suche ueber alle Charaktere (Name, Nummer oder Link). Mit Text zeigt die rechte Seite die Treffer: je
--   Gegenstand eine Zeile mit der Summe, darunter je Charakter, wo er liegt. Klick auf einen Charakter dort waehlt ihn
--   und klappt die Orte mit dem Gegenstand auf.
--   Knoepfe "Taschen in Bags" und "Bank in Bags" oeffnen den gespeicherten Stand in Peon_Bags (bags:ShowSaved), ohne
--   Peon_Bags fehlen sie.
-- Klick auf einen Gegenstand: Gegenstand in Broker, Rechtsklick: Gegenstandsmenue.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local C = {}
ns.Chars = C

local GREY = W.GREY
-- Orte in dieser Reihenfolge. mail = gekauft, noch nicht abgeholt
C.PLACES = { "bags", "bank", "mail", "auctions", "transit", "equip" }
C.OPEN = { bags = true, equip = true }    -- Vorgabe: offen
C.OLD = 7 * 86400                         -- Stand ab 7 Tagen gelb
-- Symbole der Kopfzeilen
C.ICONS = { bags = "Interface\\Icons\\INV_Misc_Bag_08", bank = "Interface\\Icons\\INV_Box_02",
            mail = "Interface\\Icons\\INV_Letter_15", auctions = "Interface\\Icons\\INV_Misc_Coin_02",
            transit = "Interface\\Icons\\INV_Letter_15", equip = "Interface\\Icons\\INV_Chest_Chain",
            warband = "Interface\\Icons\\INV_Box_02" }

-- Kategorien nach Blizzards Gegenstandsklasse (C_Item.GetItemInfoInstant, 6. Wert), gemerkt in items[id].c.
-- Reihenfolge wie in Bags: Ausruestung, Verbrauchbares, Handelswaren, Rezepte, Taschen, Quest, Sonstiges
C.CATS = {
    { key = "equip",   classes = { [2] = true, [4] = true } },             -- Waffe, Ruestung
    { key = "consum",  classes = { [0] = true } },                          -- Verbrauchbares
    { key = "trade",   classes = { [7] = true, [5] = true, [3] = true } },  -- Handelswaren, Reagenzien, Edelsteine
    { key = "recipe",  classes = { [9] = true } },                          -- Rezepte
    { key = "bag",     classes = { [1] = true, [11] = true } },             -- Behaelter, Koecher
    { key = "quest",   classes = { [12] = true } },                         -- Quest
}

function C.ItemClass(id)
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

-- Rang der Kategorie (1 .. #CATS, Sonstiges zuletzt)
function C.CatRank(id)
    local c = C.ItemClass(id)
    if c then for i, d in ipairs(C.CATS) do if d.classes[c] then return i end end end
    return #C.CATS + 1
end

local SRC = { ah = "SRC_AH", vendor = "SRC_VENDOR", cod = "SRC_COD", trade = "SRC_TRADE" }
function C.SourceText(src) return L[SRC[src] or "SRC_AH"] end

-- Gewaehlter Charakter: Name oder "*" (alle). Vorgabe der eingeloggte.
function C.Selected()
    local s = mod.db.charsChar
    if s == "*" then return "*" end
    if type(s) == "string" and s ~= "" and ns.Inventory.RealmData().chars[s] then return s end
    return ns.CharName()
end

function C.IsOpen(place)
    if C.open and C.open[place] ~= nil then return C.open[place] end
    return C.OPEN[place] == true
end

-- Charakter im Reiter oeffnen (Klick in der Uebersicht)
function C.Open(name, place)
    mod.db.charsChar = name or "*"
    C.search = nil
    if C.searchBox then C.searchBox:SetText("") end
    if place then C.open = C.open or {}; C.open[place] = true end
    W.Open("chars")
end

-- "Mirel: Taschen 5, Bank 15"
function C.PlacesText(places)
    local parts = {}
    for _, place in ipairs(C.PLACES) do
        if places[place] then parts[#parts + 1] = L["PLACE_" .. place:upper()] .. " " .. places[place] end
    end
    if places.warband then parts[#parts + 1] = L.PLACE_WARBAND .. " " .. places.warband end
    return table.concat(parts, " · ")
end

-- Zusatz einer Ort-Kopfzeile: Plaetze, Anzahl und Alter. p = Ort eines Charakters (nil bei "alle")
function C.PlaceInfo(place, p, pieces, c)
    local parts = {}
    if p and c then
        local used, all = ns.Inventory.PlaceSlots(c, place)
        if place == "auctions" and used then parts[#parts + 1] = L.CH_RUNNING:format(used)
        elseif used and all then parts[#parts + 1] = L.CH_SLOTS:format(used, all)
        elseif place == "equip" then parts[#parts + 1] = L.CH_PARTS:format(pieces) end
    end
    if pieces > 0 and not (place == "equip" and p) then parts[#parts + 1] = L.TT_PIECES:format(pieces) end
    if p and type(p.t) == "number" and p.t > 1 then
        local age = L.CH_AGO:format(ns.Age(p.t))
        if time() - p.t >= C.OLD then age = W.YELLOW .. age .. "|r" end
        parts[#parts + 1] = age
    end
    return table.concat(parts, "  ·  ")
end

-- Gegenstaende eines Orts (char = Name oder "*"): { [id] = { n, where = { [Name] = n } } }, nil ohne Daten
function C.PlaceItems(char, place)
    local out, any = {}, false
    for name, c in pairs(ns.Inventory.RealmData().chars) do
        if char == "*" or char == name then
            local p = type(c.places) == "table" and c.places[place]
            if type(p) == "table" and type(p.items) == "table" then
                any = true
                for id, n in pairs(p.items) do
                    if type(n) == "number" and n > 0 then
                        local e = out[id]
                        if not e then e = { n = 0, where = {} }; out[id] = e end
                        e.n = e.n + n
                        e.where[name] = (e.where[name] or 0) + n
                    end
                end
            end
        end
    end
    return any and out or nil
end

local function ItemRow(id, n, extra)
    local name, quality, icon = ns.Inventory.ItemInfo(id)
    local r = { kind = "item", id = id, name = name or ("#" .. id), quality = quality, icon = icon, n = n }
    if extra then for k, v in pairs(extra) do r[k] = v end end
    return r
end

local function SortItems(list)
    for _, r in ipairs(list) do r.rank = C.CatRank(r.id) end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        local la, lb = W.Lower(a.name), W.Lower(b.name)
        if la ~= lb then return la < lb end
        return a.id < b.id
    end)
end

-- Zeilen fuer einen Charakter (oder "*"): Kopfzeile je Ort, darunter die Gegenstaende, wenn offen
function C.CharRows(char)
    local rows = {}
    local c = char ~= "*" and ns.Inventory.RealmData().chars[char] or nil
    local places = {}
    for _, pl in ipairs(C.PLACES) do places[#places + 1] = pl end
    if char == "*" then
        local wb = ns.Inventory.RealmData().account.places.warband
        if type(wb) == "table" and type(wb.items) == "table" and next(wb.items) then places[#places + 1] = "warband" end
    end
    local sumN, sumItems = 0, 0
    for _, place in ipairs(places) do
        local items, p
        if place == "warband" then
            p = ns.Inventory.RealmData().account.places.warband
            items = {}
            for id, n in pairs(p.items) do if n > 0 then items[id] = { n = n, where = {} } end end
        else
            items = C.PlaceItems(char, place)
            p = c and type(c.places) == "table" and c.places[place] or nil
        end
        local list, pieces = {}, 0
        for id, e in pairs(items or {}) do
            list[#list + 1] = ItemRow(id, e.n, { where = e.where, place = place })
            pieces = pieces + e.n
        end
        sumN, sumItems = sumN + pieces, sumItems + #list
        local open = C.IsOpen(place)
        -- leere Orte ohne Daten nur beim einzelnen Charakter (Hinweis), "Unterwegs" und "Post" nur mit Inhalt
        local show = items ~= nil or (char ~= "*" and (place == "bags" or place == "bank" or place == "equip" or place == "auctions"))
        if (place == "transit" or place == "mail") and #list == 0 then show = false end
        if show then
            local label = L["PLACE_" .. place:upper()]
            rows[#rows + 1] = { kind = "head", place = place, open = open, label = label, icon = C.ICONS[place],
                info = items and C.PlaceInfo(place, p, pieces, c) or (GREY .. L.CH_UNSEEN .. "|r"), line = #rows > 0 }
            if open then
                if not items then
                    rows[#rows + 1] = { kind = "hint", icon = C.ICONS[place], text = rawget(L, "CH_HINT_" .. place:upper()) or L.CH_HINT }
                elseif #list == 0 then
                    rows[#rows + 1] = { kind = "hint", icon = C.ICONS[place], text = L.CH_EMPTY_PLACE }
                else
                    SortItems(list)
                    for _, r in ipairs(list) do rows[#rows + 1] = r end
                end
            end
        end
    end
    C.sums = { items = sumItems, pieces = sumN }
    return rows
end

-- Treffer einer Suche: Gegenstand mit Summe, darunter je Charakter die Orte
function C.Matches(text)
    local q = W.Lower((tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")))
    if q == "" then return nil end
    local wantId = tonumber(text:match("item:(%d+)")) or tonumber(q:match("^(%d+)$"))
    local found = {}
    local function Add(id, name, place, n)
        local e = found[id]
        if not e then e = { total = 0, chars = {} }; found[id] = e end
        e.total = e.total + n
        e.chars[name] = e.chars[name] or {}
        e.chars[name][place] = (e.chars[name][place] or 0) + n
    end
    local function Hit(id)
        if wantId then return id == wantId end
        local name = ns.Inventory.ItemInfo(id)
        return name ~= nil and W.Lower(name):find(q, 1, true) ~= nil
    end
    local hitCache = {}
    local function IsHit(id)
        local h = hitCache[id]
        if h == nil then h = Hit(id); hitCache[id] = h end
        return h
    end
    for name, c in pairs(ns.Inventory.RealmData().chars) do
        for _, place in ipairs(C.PLACES) do
            local p = type(c.places) == "table" and c.places[place]
            if type(p) == "table" and type(p.items) == "table" then
                for id, n in pairs(p.items) do
                    if type(n) == "number" and n > 0 and IsHit(id) then Add(id, name, place, n) end
                end
            end
        end
    end
    local wb = ns.Inventory.RealmData().account.places.warband
    if type(wb) == "table" and type(wb.items) == "table" then
        for id, n in pairs(wb.items) do if n > 0 and IsHit(id) then Add(id, "*", "warband", n) end end
    end
    return found
end

function C.SearchRows(text)
    local found = C.Matches(text) or {}
    local items = {}
    for id, e in pairs(found) do items[#items + 1] = ItemRow(id, e.total, { found = e }) end
    SortItems(items)
    local rows, me = {}, ns.CharName()
    for i, it in ipairs(items) do
        it.kind, it.total, it.line = "match", it.n, i > 1
        rows[#rows + 1] = it
        local names = {}
        for name in pairs(it.found.chars) do names[#names + 1] = name end
        table.sort(names, function(a, b)
            if (a == "*") ~= (b == "*") then return b == "*" end
            if (a == me) ~= (b == me) then return a == me end
            return a < b
        end)
        for _, name in ipairs(names) do
            local where = it.found.chars[name]
            local first
            for _, pl in ipairs(C.PLACES) do if where[pl] then first = first or pl end end
            rows[#rows + 1] = { kind = "who", char = name, id = it.id, place = first, icon = it.icon, quality = it.quality,
                label = name == "*" and L.PLACE_WARBAND or ns.Tooltip.Short(name), text = C.PlacesText(where) }
        end
    end
    C.sums = { items = #items, search = true }
    return rows
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
function C.CharList()
    local rows = { { name = "*", label = L.ALL_CHARS, ord = 0 } }
    local names, me = {}, ns.CharName()
    for name in pairs(ns.Inventory.RealmData().chars) do names[#names + 1] = name end
    table.sort(names, function(a, b) if (a == me) ~= (b == me) then return a == me end return a < b end)
    for i, name in ipairs(names) do
        local c = ns.Inventory.RealmData().chars[name]
        rows[#rows + 1] = { name = name, label = name, class = c.class, level = c.level, money = c.money, ord = i, me = name == me }
    end
    return rows
end

function C.Refresh()
    if not C.table then return end
    local sel = C.Selected()
    local list = C.CharList()
    C.list:SetData(list)
    for _, r in ipairs(C.list.items) do if r.name == sel then C.list.selected = r end end
    C.list.list:Refresh()
    local rows
    local searching = C.search and C.search:gsub("%s", "") ~= ""
    if searching then rows = C.SearchRows(C.search) else rows = C.CharRows(sel) end
    for i, r in ipairs(rows) do r.ord = i end
    C.rows = rows
    C.table:SetData(rows)
    C.table.empty:SetText(searching and L.CH_NO_MATCH or L.STOCK_EMPTY)
    C.UpdateHead(sel, searching)
end

-- Kopf ueber der rechten Seite: Charakter, Stufe, Gold oder Suche, dazu die Knoepfe fuer Bags
function C.UpdateHead(sel, searching)
    if not C.head then return end
    local text
    if searching then
        text = L.CH_SEARCH_HEAD:format(C.search, ns.Plural(C.sums.items or 0, "STOCK_COUNT"))
    elseif sel == "*" then
        text = L.ALL_CHARS .. GREY .. "  ·  " .. ns.Money(ns.Inventory.TotalMoney() or 0, true) .. "|r"
    else
        local c = ns.Inventory.RealmData().chars[sel] or {}
        local parts = { W.ClassColored(ns.Tooltip.Short(sel), c.class) }
        if c.level then parts[#parts + 1] = L.CH_LEVEL:format(c.level) end
        if type(c.money) == "number" then parts[#parts + 1] = ns.Money(c.money, true) end
        text = table.concat(parts, GREY .. "  ·  |r")
    end
    C.head:SetText(text)
    local bags = C.Bags()
    for _, b in ipairs(C.bagButtons or {}) do
        b:SetShown(bags ~= nil)
        local ok = bags ~= nil and sel ~= "*" and not searching and C.HasSaved(bags, sel, b.ort)
        if ok then b:Enable() else b:Disable() end
    end
end

-- Peon_Bags mit gespeicherter Ansicht (ab Bags 0.8.0), sonst nil
function C.Bags()
    if not Peon.GetModule then return nil end
    local ok, b = pcall(Peon.GetModule, Peon, "bags")
    if ok and type(b) == "table" and type(b.ShowSaved) == "function" and type(b.HasSaved) == "function" then return b end
    return nil
end

function C.HasSaved(bags, name, ort)
    local ok, has = pcall(bags.HasSaved, bags, name, ort)
    return ok and has == true
end

function C.ShowInBags(ort)
    local bags = C.Bags()
    local sel = C.Selected()
    if not bags or sel == "*" then return false end
    local ok, shown = pcall(bags.ShowSaved, bags, sel, ort)
    return ok and shown == true
end

function C.Status()
    local s = C.sums
    if not s then return nil end
    if s.search then return ns.Plural(s.items or 0, "STOCK_COUNT") end
    return ns.Plural(s.items or 0, "STOCK_COUNT") .. "  ·  " .. L.TT_PIECES:format(s.pieces or 0)
end

function C.RowTooltip(row, r)
    if r.kind == "head" then
        if not GameTooltip then return end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:AddLine(r.label, 1, 0.82, 0)
        GameTooltip:AddLine(r.open and L.CH_HEAD_CLOSE or L.CH_HEAD_OPEN, 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
        return
    end
    if r.kind == "hint" then return end
    if r.kind == "who" then
        if not GameTooltip then return end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:AddLine(r.char == "*" and L.PLACE_WARBAND or r.char, 1, 0.82, 0)
        GameTooltip:AddLine(r.text, 0.9, 0.9, 0.9, true)
        if r.char ~= "*" then GameTooltip:AddLine(L.CH_WHO_CLICK, 0.6, 0.6, 0.6, true) end
        GameTooltip:Show()
        return
    end
    W.ShowItemTooltip(row, r.id)
    if not GameTooltip then return end
    -- bei "Alle Charaktere": wer wie viel hat
    if r.where and C.Selected() == "*" then
        local names = {}
        for name in pairs(r.where) do names[#names + 1] = name end
        if #names > 0 then
            table.sort(names, function(a, b) return r.where[a] > r.where[b] end)
            GameTooltip:AddLine(" ")
            for _, name in ipairs(names) do GameTooltip:AddDoubleLine(ns.Tooltip.Short(name), tostring(r.where[name]), 0.9, 0.9, 0.9, 1, 1, 1) end
        end
    end
    GameTooltip:AddLine(L.STOCK_CLICK_HINT, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

function C.OnClick(r, button)
    if not r then return end
    if r.kind == "head" then
        C.open = C.open or {}
        C.open[r.place] = not C.IsOpen(r.place)
        mod:Call("Charaktere", W.Refresh)
    elseif r.kind == "who" then
        if r.char == "*" then return end
        C.Open(r.char, r.place)
        local found = r.id and C.Matches("item:" .. r.id)
        local where = found and found[r.id] and found[r.id].chars[r.char]
        if where then for pl in pairs(where) do C.open[pl] = true end end
        mod:Call("Charaktere", W.Refresh)
    elseif r.id then
        if button == "RightButton" then W.ItemMenu(r.id) else mod:ShowItem(r.id) end
    end
end

local OPEN_ICON = "|TInterface\\Buttons\\UI-MinusButton-Up:14:14:0:0|t "
local CLOSED_ICON = "|TInterface\\Buttons\\UI-PlusButton-Up:14:14:0:0|t "

local function NameText(v, r)
    if r.kind == "head" then
        return (r.open and OPEN_ICON or CLOSED_ICON) .. W.YELLOW .. r.label .. "|r   " .. GREY .. (r.info or "") .. "|r"
    elseif r.kind == "hint" then
        return GREY .. "   " .. r.text .. "|r"
    elseif r.kind == "who" then
        return "      " .. (r.label or "") .. "   " .. GREY .. (r.text or "") .. "|r"
    end
    return W.Colored(v, r.quality)
end

local function CountText(v, r)
    if r.kind == "item" then return tostring(r.n or "") end
    if r.kind == "match" then return GREY .. L.CH_TOTAL .. "|r " .. tostring(r.total or 0) end
    return ""
end

function C.Build(c)
    local U = Peon.UI
    local a = W.Area()
    C.searchBox = U.SearchBox(c, 220, function(text)
        C.search = text
        mod:Call("Charaktere", W.Refresh)
    end)
    C.searchBox:SetPoint("TOPLEFT", 80, -32)
    -- links die Charaktere
    local lw = 200
    local left = U.Panel(c, "list", true)
    left:SetPoint("TOPLEFT", a.left, -a.top)
    left:SetPoint("BOTTOMLEFT", a.left, a.bottom)
    left:SetWidth(lw)
    C.list = U.Table(left, {
        columns = {
            { key = "label", title = L.COL_CHAR, nosort = true, format = function(v, r)
                if r.name == "*" then return W.YELLOW .. v .. "|r" end
                return W.ClassColored(ns.Tooltip.Short(v), r.class) end },
            { key = "level", title = L.COL_LEVEL_SHORT, width = 44, align = "RIGHT", nosort = true },
        },
        sortKey = "ord",
        empty = L.OV_EMPTY,
        onEnter = function(row, r)
            if not GameTooltip or r.name == "*" then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:AddLine(r.name, 1, 0.82, 0)
            if type(r.money) == "number" then GameTooltip:AddLine(ns.Money(r.money), 1, 1, 1) end
            GameTooltip:Show()
        end,
        onClick = function(r, button)
            if button ~= "LeftButton" or not r then return end
            mod.db.charsChar = r.name
            if C.search and C.search ~= "" then
                C.search = nil
                if C.searchBox then C.searchBox:SetText("") end
            end
            mod:Call("Charaktere", W.Refresh)
        end,
    })
    -- rechts der Inhalt
    local right = U.Panel(c, "list", true)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 0)
    right:SetPoint("BOTTOMRIGHT", -a.right, a.bottom)
    C.panel = right
    C.head = c:CreateFontString(nil, "ARTWORK", U.FONT.label)
    C.head:SetPoint("LEFT", C.searchBox, "RIGHT", 16, 0)
    C.head:SetWidth(250)
    C.head:SetJustifyH("LEFT")
    if C.head.SetWordWrap then C.head:SetWordWrap(false) end
    C.bagButtons = {}
    local prev
    for _, d in ipairs({ { "bank", L.CH_BAGS_BANK }, { "bags", L.CH_BAGS_BAGS } }) do
        local b = U.Button(c, d[2], 120, function() mod:Call("Charaktere", C.ShowInBags, d[1]) end)
        b.ort = d[1]
        if prev then b:SetPoint("RIGHT", prev, "LEFT", -4, 0) else b:SetPoint("TOPRIGHT", -16, -32) end
        U.SetTooltip(b, { d[2], L.CH_BAGS_TT })
        if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
        C.bagButtons[#C.bagButtons + 1] = b
        prev = b
    end
    C.table = U.Table(right, {
        icon = true,
        columns = {
            { key = "name", title = L.COL_ITEM, nosort = true, format = NameText },
            { key = "n", title = L.COL_TOTAL, width = 110, align = "RIGHT", nosort = true, format = CountText },
        },
        sortKey = "ord",
        empty = L.STOCK_EMPTY,
        rowBg = function(r) if r.kind == "head" or r.kind == "match" then return 1, 0.82, 0, 0.06 end end,
        rowLine = function(r) return r.line end,
        onEnter = function(row, r) C.RowTooltip(row, r) end,
        onClick = function(r, button) C.OnClick(r, button) end,
    })
end

W.pages.chars = { build = C.Build, refresh = C.Refresh, status = C.Status }
