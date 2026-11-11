-- Peon_Broker - Market.lua
-- Neuaufbau N3 (ab 0.61, Konzept Peon_Broker_Neuaufbau.md, Abschnitt 4.1): Seite "Markt" aus Scandaten, gebaut mit
-- Peon.UI. Unterwegs steht sie an der Stelle von Blizzards Kaufen: Suche, links Kategorien wie im Auktionshaus,
-- rechts die Liste mit Gegenstand, Preis ab, Menge, Trend und Stand. Am Auktionator ist "Markt" Blizzards Seite.
--   * Kategorien: Namen vom Spiel (GetItemClassInfo, GetItemSubClassInfo), Zuordnung ueber GetItemInfoInstant
--     (geht ohne Zwischenspeicher des Spiels). Es erscheinen nur Kategorien, zu denen es Angebote gibt.
--   * Ohne Suche und Kategorie: Beobachtung und Einkaufslisten.
--   * Auswahl des Markts nur, wenn es Daten fuer mehr als einen gibt.
--   * Klick auf eine Zeile zeigt den Gegenstand (Seite Gegenstand, mit Zurueck), Rechtsklick oeffnet das Menue.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local M = {}
ns.Market = M

M.MAX = 500            -- hoechstens so viele Zeilen in der Liste
M.SEARCH_MIN = 2
M.marketKey = nil      -- gewaehlter Markt, nil = der aktuelle (ns.MarketKey())
M.category = nil       -- gewaehlte Kategorie: "c<Klasse>" oder "c<Klasse>/s<Unterklasse>"

local function Money(v) return ns.Tooltip.Money(v) end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

function M.Key()
    local key = M.marketKey
    if key and type(ns.Data.Markets()[key]) == "table" then return key end
    return ns.MarketKey()
end

-- Klasse und Unterklasse eines Gegenstands (nil, wenn das Spiel sie nicht nennt)
local function ClassOf(id)
    local fn = C_Item and C_Item.GetItemInfoInstant
    if not fn or not id then return nil end
    local ok, _, _, _, _, _, class, sub = pcall(fn, id)
    if ok and Num(class) then return class, Num(sub) and sub or nil end
    return nil
end

local function ClassName(class, sub)
    if sub == nil then
        local fn = C_Item and C_Item.GetItemClassInfo
        local ok, name = pcall(fn or error, class)
        if ok and type(name) == "string" and name ~= "" then return name end
        return L.MARKET_CLASS:format(class)
    end
    local fn = C_Item and C_Item.GetItemSubClassInfo
    local ok, name = pcall(fn or error, class, sub)
    if ok and type(name) == "string" and name ~= "" then return name end
    return L.MARKET_CLASS:format(sub)
end

-- Alle Gegenstaende des gewaehlten Markts mit Kategorie (zwischengespeichert bis zum naechsten Stand)
function M.All()
    local D = ns.Data
    local key = M.Key()
    local market = D.Markets()[key]
    local stamp = tostring(key) .. ":" .. tostring(market and market.lastScan) .. ":" .. tostring(market and market.mgrAt) .. ":" .. tostring(D.liveStamp)
    if M.cache and M.cacheStamp == stamp then return M.cache, M.nodes end
    local all, classes = {}, {}
    if type(market) == "table" then
        for k, e in pairs(market.items or {}) do
            if type(e) == "table" and e.m then
                local id = D.ItemID(k)
                local name = e.nm or ns.WithMarket(key, D.ItemName, k, e) or L.ITEM_UNKNOWN:format(id or 0)
                local class, sub = ClassOf(id)
                local cat = class and ("c" .. class) or "c?"
                local full = (class and sub) and (cat .. "/s" .. sub) or cat
                all[#all + 1] = { key = k, e = e, name = name, lname = W.Lower(name), cat = cat, full = full }
                local c = classes[cat]
                if not c then c = { class = class, subs = {} }; classes[cat] = c end
                if class and sub then c.subs[sub] = true end
            end
        end
    end
    -- Kategorien: Klassen nach Nummer (wie im Auktionshaus), "Sonstiges" zuletzt
    local nodes, order = {}, {}
    for cat, c in pairs(classes) do order[#order + 1] = { cat = cat, c = c } end
    table.sort(order, function(a, b) return (a.c.class or 9999) < (b.c.class or 9999) end)
    for _, o in ipairs(order) do
        local c = o.c
        nodes[#nodes + 1] = { key = o.cat, text = c.class and ClassName(c.class) or L.MARKET_OTHER, level = 1 }
        local subs = {}
        for sub in pairs(c.subs) do subs[#subs + 1] = sub end
        table.sort(subs)
        if #subs > 1 then
            for _, sub in ipairs(subs) do
                nodes[#nodes + 1] = { key = o.cat .. "/s" .. sub, text = ClassName(c.class, sub), level = 2 }
            end
        end
    end
    M.cache, M.cacheStamp, M.nodes = all, stamp, nodes
    return all, nodes
end

-- Schluessel aller Gegenstaende auf Einkaufslisten und in der Beobachtung
function M.Wanted()
    local keys = {}
    if ns.Watch then for k in pairs(ns.Watch.Store()) do keys[k] = true end end
    if ns.Buy then
        for _, l in ipairs(ns.Buy.Lists()) do
            for k in pairs(l.items or {}) do keys[k] = true end
        end
    end
    return keys
end

local function RowOf(it)
    local e = it.e
    local T = ns.Tooltip
    return { key = it.key, name = it.name, lname = it.lname, quality = e.ql,
        icon = ns.Buy and ns.Buy.Icon(ns.Data.ItemID(it.key)) or nil,
        min = e.m, qty = e.gone and 0 or (e.q or 0), gone = e.gone,
        trend = T.TrendLevel(e.m, e.pm), trendText = T.Trend(e.m, e.pm),
        t = e.gone or ns.Data.Seen(e) }
end

-- Zeilen der Liste. Rueckgabe: Zeilen (hoechstens MAX), Zahl der Treffer, Art ("start", "search")
function M.Rows()
    local all = M.All()
    local text = W.Lower(strtrim and strtrim(M.text or "") or (M.text or ""))
    if #text < M.SEARCH_MIN then text = "" end
    local cat = M.category
    local rows, found = {}, 0
    if text == "" and not cat then
        local wanted = M.Wanted()
        for _, it in ipairs(all) do
            if wanted[it.key] then
                found = found + 1
                if #rows < M.MAX then rows[#rows + 1] = RowOf(it) end
            end
        end
        return rows, found, "start"
    end
    for _, it in ipairs(all) do
        if (not cat or it.cat == cat or it.full == cat) and (text == "" or it.lname:find(text, 1, true)) then
            found = found + 1
            if #rows < M.MAX then rows[#rows + 1] = RowOf(it) end
        end
    end
    return rows, found, "search"
end

-- Maerkte mit Daten: { { Schluessel, Name }, ... }
function M.Markets()
    local out = {}
    local G = ns.Pages
    for key, m in pairs(ns.Data.Markets()) do
        if type(m) == "table" and type(m.items) == "table" and next(m.items) ~= nil then
            out[#out + 1] = { key, G and G.MarketLabel(key) or key }
        end
    end
    table.sort(out, function(a, b) return a[2] < b[2] end)
    return out
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
function M.Build(c)
    local UI = Peon.UI
    M.frame = c

    M.search = UI.SearchBox(c, 240, function(text)
        if M.filling then return end
        M.text = text
        mod:Call("Markt", M.Refresh)
    end)
    M.search:SetPoint("TOPLEFT", 8, -2)
    M.count = UI.Text(c, "small", "")
    M.count:SetPoint("LEFT", M.search, "RIGHT", 12, 0)

    M.marketBox = UI.Dropdown(c, 160, M.Markets, M.Key, function(key)
        M.marketKey = key
        M.category = nil
        if M.cats then M.cats.selected = nil end
        mod:Call("Markt", M.Refresh)
    end)
    M.marketBox:SetPoint("TOPRIGHT", -4, 0)
    M.stand = UI.Text(c, "small", "")
    M.stand:SetPoint("RIGHT", M.marketBox, "LEFT", -10, 0)
    M.stand:SetJustifyH("RIGHT")

    local left = UI.Panel(c, "categories")
    left:SetPoint("TOPLEFT", 0, -30)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(UI.CAT_W)
    M.cats = UI.CategoryList(left, {}, function(key)
        M.category = key
        mod:Call("Markt", M.Refresh)
    end)

    local right = UI.Panel(c, "list", true)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    M.panel = right
    M.list = UI.Table(right, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(it) return it.lname end,
              color = function(it) return UI.QualityColor(it.quality or 1) end },
            { key = "min", title = L.ITEM_COL_MIN, width = 100, align = "RIGHT",
              format = function(v, it) return (it.gone and "|cff808080" or "") .. Money(v) .. (it.gone and "|r" or "") end },
            { key = "qty", title = L.ITEM_COL_QTY, width = 80, align = "RIGHT" },
            { key = "trend", title = L.MARKET_COL_TREND, width = 60, align = "RIGHT",
              format = function(_, it) return it.trendText or "" end, sort = function(it) return it.trend or 0 end },
            { key = "t", title = L.MARKET_COL_AGE, width = 90, align = "RIGHT", format = function(v) return ns.Scan.Age(v) end },
        },
        sortKey = "name", icon = true, empty = L.MARKET_START_EMPTY,
        onClick = function(it, button)
            if button == "RightButton" then
                ns.Go.Menu(it, M.panel)
            else
                mod:Call("Sprung", ns.Go.Item, { key = it.key, name = it.name })
            end
        end,
        onEnter = function(row, it) if it then W.ShowItemTooltip(row, it.key) end end,
    })
    M.Refresh()
end

function M.Refresh()
    if not M.list then return end
    local key = M.Key()
    local _, nodes = M.All()
    if M.cats.nodesFor ~= M.cacheStamp then
        M.cats.nodesFor = M.cacheStamp
        M.cats:SetNodes(nodes)
        if M.category and not M.cats.byKey[M.category] then M.category = nil end
    end
    local rows, found, kind = M.Rows()
    local market = ns.Data.Markets()[key]
    local hint = L.MARKET_NOTHING
    if type(market) ~= "table" or next(market.items or {}) == nil then hint = L.PRICES_NO_SCAN
    elseif kind == "start" then hint = L.MARKET_START_EMPTY end
    M.list.empty:SetText(hint)
    M.list:SetData(rows)
    if kind == "start" then M.count:SetText(found > 0 and L.MARKET_START:format(found) or "")
    elseif found > #rows then M.count:SetText(L.ITEM_COUNT_CAP:format(#rows, found))
    else M.count:SetText(L.ITEM_COUNT:format(found)) end
    local markets = M.Markets()
    M.marketBox:SetShown(#markets > 1)
    if M.marketBox.fallback then M.marketBox:SetText(ns.Pages and ns.Pages.MarketLabel(key) or key) end
    local at = type(market) == "table" and ns.Data.DataAt(market) or nil
    M.stand:SetText(at and L.MARKET_STAND:format(ns.Scan.Age(at)) or "")
end

-- Sprung "Im Markt zeigen" unterwegs: nach genau diesem Gegenstand suchen
function M.Find(name)
    M.category = nil
    M.text = name or ""
    if M.cats then M.cats:Select(nil) end
    if M.search then
        M.filling = true
        M.search:SetText(M.text)
        M.filling = false
    end
    M.Refresh()
end

W.pages.browse = {
    build = M.Build,
    refresh = function() M.Refresh() end,
}
