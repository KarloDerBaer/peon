-- Peon_Ledger - Overview.lua
-- Reiter "Uebersicht": "Wie stehe ich da?" (ab 0.14 mit Peon.UI, Konzept Peon_Ledger_Neuaufbau.md Abschnitt 6.1)
--   oben drei Kacheln: Gold gesamt (Aenderung heute), Vermoegen, Handelsgewinn heute
--   darunter alle Charaktere des Realms: Name, Stufe, Gold, Lagerwert, Vermoegen (ab 0.14.4), zuletzt gesehen
--   Lagerkosten = was die Waren gekostet haben, Vermoegen = Gold + heutiger Marktwert der Waren (Broker).
--   Ab 0.14.5 darunter ein Diagramm mit Gold, Vermoegen und Handelsgewinn (Trend.lua), Zeitraum 1 T bis Alles.
--   Ab 0.14.1 ohne Post (KarloDerBaer): Das Spiel nennt die Post erst am Briefkasten, die Zahl war oft veraltet.
-- Vermoegen = Gold + Wert der Gegenstaende (Preise von Peon_Broker), Gebundenes zum Haendlerpreis (ns.Worth).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local O = {}
ns.Overview = O

local GREY = W.GREY

-- Vermoegen eines Charakters: Gold (+ Gold an Twinks unterwegs) + Wert der Gegenstaende. nil ohne Broker.
O.VALUE_PLACES = { "bags", "bank", "auctions", "transit", "equip" }
function O.Worth(c, cache)
    if not ns.HasBroker() then return nil end
    local items, missing = 0, 0
    for _, place in ipairs(O.VALUE_PLACES) do
        local p = c.places[place]
        if type(p) == "table" and type(p.items) == "table" then
            for id, n in pairs(p.items) do
                local b = ns.Inventory.BoundIn(p, place, id, n)
                local k = id .. ":" .. n .. ":" .. b
                local v = cache[k]
                if v == nil then v = ns.Worth(id, n, b) or false; cache[k] = v end
                if v then items = items + v else missing = missing + 1 end
            end
        end
    end
    local gold = (c.money or 0) + (type(c.places.transit) == "table" and tonumber(c.places.transit.money) or 0)
    return gold + items, items, missing
end

function O.Rows()
    local I = ns.Inventory
    local rows, me = {}, ns.CharName()
    local cache = {}
    for name, c in pairs(I.RealmData().chars) do
        local r = {
            name = name, class = c.class, me = name == me, money = c.money, level = c.level, faction = c.faction,
            bags = I.PlaceCount(c, "bags"), bank = I.PlaceCount(c, "bank"), auctions = I.PlaceCount(c, "auctions"),
            equip = I.PlaceCount(c, "equip"), transit = I.PlaceCount(c, "transit"),
            seen = c.seen, slots = {}, mail = I.MailInfo(c),
            lager = ns.Cost and ns.Cost.TotalValue(name) or nil,
        }
        r.worth, r.itemsValue, r.missing = O.Worth(c, cache)
        r.mailSort = r.mail and (r.mail.letters * 1e9 + r.mail.money) or -1
        for _, key in ipairs({ "bags", "bank", "auctions" }) do
            local used, all = I.PlaceSlots(c, key)
            if used then r.slots[key] = { used, all } end
        end
        rows[#rows + 1] = r
    end
    return rows
end

function O.Totals(rows)
    local t = { money = 0, chars = 0, worth = 0, items = 0, missing = 0, hasWorth = false,
                letters = 0, mailMoney = 0, nextExp = nil, mailKnown = false }
    for _, r in ipairs(rows) do
        if type(r.money) == "number" then t.money = t.money + r.money; t.chars = t.chars + 1 end
        if r.worth then t.hasWorth = true; t.worth = t.worth + r.worth; t.items = t.items + (r.itemsValue or 0); t.missing = t.missing + (r.missing or 0) end
        if r.mail then
            t.mailKnown = true
            t.letters = t.letters + (r.mail.letters or 0)
            t.mailMoney = t.mailMoney + (r.mail.money or 0)
            if r.mail.next and (not t.nextExp or r.mail.next < t.nextExp) then t.nextExp = r.mail.next end
        end
    end
    return t
end

-- Ablauf als Text: "2 T.", gelb unter 3 Tagen, rot unter 1 Tag
function O.ExpText(t)
    if not t then return "" end
    local d = (t - time()) / 86400
    local txt = d >= 1 and L.AGE_DAYS:format(math.floor(d)) or L.AGE_HOURS:format(math.max(0, math.floor(d * 24)))
    if d < 1 then return W.RED .. txt .. "|r" end
    if d < 3 then return W.YELLOW .. txt .. "|r" end
    return txt
end

-- Kachel: Ueberschrift, grosser Wert, kleiner Zusatz
local function Tile(parent, x, y, w, h, title)
    local U = Peon.UI
    local p = U.Panel(parent, "left")
    p:SetPoint("TOPLEFT", x, y)
    p:SetSize(w, h)
    p.title = p:CreateFontString(nil, "ARTWORK", U.FONT.nav)
    p.title:SetPoint("TOPLEFT", 12, -9)
    p.title:SetText(title)
    p.big = p:CreateFontString(nil, "ARTWORK", U.FONT.big)
    p.big:SetPoint("TOPLEFT", 12, -26)
    p.big:SetJustifyH("LEFT")
    p.sub = p:CreateFontString(nil, "ARTWORK", U.FONT.small)
    p.sub:SetPoint("TOPLEFT", 12, -48)
    p.sub:SetJustifyH("LEFT")
    function p:Set(big, sub) self.big:SetText(big or ""); self.sub:SetText(sub or "") end
    return p
end

function O.Refresh()
    if not O.table then return end
    local rows = O.Rows()
    O.table:SetData(rows)
    local t = O.Totals(rows)
    O.totals = t
    local today = ns.Book.Collect("today", false)
    O.tiles.gold:Set(ns.Money(t.money, true), L.OV_TODAY:format(W.Signed(today.profit)) .. "  ·  " .. ns.Plural(t.chars, "OV_CHARS"))
    if ns.HasBroker() then
        local sub = L.OV_ITEMS_VALUE:format(ns.Money(t.items, true))
        if t.missing > 0 then sub = sub .. GREY .. "  ·  " .. L.OV_NOPRICE:format(t.missing) .. "|r" end
        O.tiles.worth:Set(ns.Money(t.worth, true), sub)
    else
        O.tiles.worth:Set(GREY .. "–|r", GREY .. L.OV_NOBROKER .. "|r")
    end
    local lager = ns.Cost and ns.Cost.TotalValue() or 0
    if ns.Trend then mod:Call("Verlauf Gold", ns.Trend.Record) end
    mod:Call("Diagramm", O.DrawChart)
    O.tiles.trade:Set(W.Signed(today.trade or 0), ns.Plural(today.nsales or 0, "OV_TRADE_SUB", ns.Money(math.floor(lager + 0.5), true)))
end

---------------------------------------------------------------------------
-- Diagramm (ab 0.14.5)
---------------------------------------------------------------------------
O.CHART_H = 196
O.COLORS = { gold = { 1, 0.82, 0, 1 }, worth = { 0.35, 0.85, 0.35, 1 }, trade = { 0.45, 0.7, 1, 1 } }

local function Short(v) if v == nil then return "" end return (v < 0 and "-" or "") .. Peon.ShortGold(math.abs(v)) end

function O.DrawChart()
    local ch = O.chart
    if not ch then return end
    local d = ns.Trend.Series(mod.db.trendRange or "d7")
    O.series = d
    ch:SetData(d.n, {
        { key = "gold", kind = "line", axis = "left", values = d.gold, color = O.COLORS.gold, width = 2, connect = true, label = L.TR_GOLD },
        { key = "worth", kind = "line", axis = "left", values = d.worth, color = O.COLORS.worth, width = 2, connect = true, label = L.TR_WORTH },
        { key = "trade", kind = "step", axis = "right", values = d.trade, color = O.COLORS.trade, width = 2, label = L.TR_TRADE },
        { key = "zero", kind = "hline", axis = "right", value = 0, color = { 0.45, 0.7, 1, 0.3 } },
    })
    for k, off in pairs(mod.db.trendOff or {}) do if off then ch:SetShown(k, false) end end
    -- rechte Achse (Handelsgewinn) mindestens 1g hoch, sonst stuenden bei 0 nur "0s"-Beschriftungen (ab 0.14.6)
    local lo, hi = 0, 0
    for i = 1, d.n do local v = d.trade[i]; if v then lo, hi = math.min(lo, v), math.max(hi, v) end end
    if hi - lo < 10000 then ch:SetRange("right", lo, lo + 10000) else ch:SetRange("right", nil, nil) end
    ch:Draw()
    if not O.legend and ch.CreateLegend then
        O.legend = ch:CreateLegend(O.chartPanel, { "gold", "worth", "trade" }, function(key, on)
            mod.db.trendOff = mod.db.trendOff or {}
            mod.db.trendOff[key] = not on
        end)
        if O.legend and O.legend.frame then O.legend.frame:SetPoint("TOPRIGHT", O.chartPanel, "TOPRIGHT", -200, -8) end
    end
    for _, b in ipairs(O.rangeButtons or {}) do
        if b.key == (mod.db.trendRange or "d7") then b:Disable() else b:Enable() end
    end
    O.ChartHover(nil)
end

-- Werte unter der Maus (oder Hinweis)
function O.ChartHover(i)
    local d = O.series
    if not O.chartInfo then return end
    if not i or not d or not d.ends[i] or not d.last or i > d.last then
        O.chartInfo:SetText(W.GREY .. L.TR_HINT .. "|r")
        return
    end
    local fmt = (d.key == "d1" or d.key == "d7") and "%d.%m. %H:%M" or "%d.%m."
    local parts = { date(fmt, math.min(d.ends[i], d.now or d.ends[i])) }
    if d.gold[i] then parts[#parts + 1] = L.TR_GOLD .. " " .. ns.Money(d.gold[i], true) end
    if d.worth[i] then parts[#parts + 1] = L.TR_WORTH .. " " .. ns.Money(d.worth[i], true) end
    parts[#parts + 1] = L.TR_TRADE .. " " .. W.Signed(d.trade[i] or 0)
    O.chartInfo:SetText(table.concat(parts, "   "))
end

function O.BuildChart(c, a)
    local U = Peon.UI
    local p = U.Panel(c, "list")
    p:SetPoint("BOTTOMLEFT", a.left, a.bottom)
    p:SetPoint("BOTTOMRIGHT", -a.right, a.bottom)
    p:SetHeight(O.CHART_H)
    O.chartPanel = p
    O.rangeButtons = {}
    local prev
    for _, r in ipairs(ns.Trend.RANGES) do
        local b = U.Button(p, L["TR_" .. r.key:upper()], 50, function()
            mod.db.trendRange = r.key
            mod:Call("Diagramm", O.DrawChart)
        end)
        b.key = r.key
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 10, -6) end
        O.rangeButtons[#O.rangeButtons + 1] = b
        prev = b
    end
    O.chartInfo = p:CreateFontString(nil, "ARTWORK", U.FONT.small)
    O.chartInfo:SetPoint("BOTTOMLEFT", 12, 8)
    O.chartInfo:SetPoint("BOTTOMRIGHT", -12, 8)
    O.chartInfo:SetJustifyH("LEFT")
    local w = (U.WINDOW_W - 2 * U.EDGE - 1) - 20
    O.chart = Peon.NewChart(p, {
        width = w, height = O.CHART_H - 58, left = 56, right = 56, grid = 3,
        leftFormat = Short, rightFormat = Short,
        onHover = function(_, i) O.ChartHover(i) end,
        onLeave = function() O.ChartHover(nil) end,
    })
    O.chart.frame:SetPoint("TOPLEFT", 10, -32)
end

-- Text fuer die Statuszeile
function O.Status()
    local t = O.totals
    return t and (ns.Realm() .. "  ·  " .. ns.Plural(t.chars, "OV_CHARS")) or nil
end

-- Kachelinhalt als Text (Tests, Fehlersuche)
function O.TileText(key)
    local p = O.tiles and O.tiles[key]
    if not p then return "" end
    return tostring(p.big.text or "") .. " | " .. tostring(p.sub.text or "")
end

function O.RowTooltip(row, r)
    if not GameTooltip then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(W.ClassColored(r.name, r.class))
    if r.level then GameTooltip:AddLine(L.TT_LEVEL:format(r.level, r.faction or "?"), 0.8, 0.8, 0.8) end
    for _, key in ipairs({ "bags", "bank", "auctions", "equip", "transit" }) do
        local n = r[key]
        if n then
            local s = r.slots[key]
            local right = L.TT_PIECES:format(n)
            if s and s[2] then right = right .. "  ·  " .. L.TT_SLOTS:format(s[1], s[2], s[2] - s[1])
            elseif s then right = right .. "  ·  " .. L.TT_SLOTS_ONLY:format(s[1]) end
            GameTooltip:AddDoubleLine(L["PLACE_" .. key:upper()], right, 1, 1, 1, 0.8, 0.8, 0.8)
        end
    end
    if r.worth then
        GameTooltip:AddDoubleLine(L.TT_WORTH, ns.Money(r.worth), 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.TT_WORTH_ITEMS, ns.Money(r.itemsValue or 0), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
        if (r.missing or 0) > 0 then GameTooltip:AddLine(L.TT_WORTH_MISSING:format(r.missing), 0.6, 0.6, 0.6, true) end
    end
    local p7 = ns.Book.Collect("d7", true, nil, r.name)
    GameTooltip:AddDoubleLine(L.TT_TRADE7, W.Signed(p7.trade or 0), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.TT_PROFIT7, W.Signed(p7.profit), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:Show()
end

function O.Build(c)
    local U = Peon.UI
    local a = W.Area()
    O.tiles = {}
    local gap = 4
    local defs = { { "gold", L.OV_T_GOLD }, { "worth", L.OV_T_WORTH }, { "trade", L.OV_T_TRADE } }
    local tw = math.floor((a.width - (#defs - 1) * gap) / #defs)
    local th = 64
    for i, d in ipairs(defs) do
        O.tiles[d[1]] = Tile(c, a.left + (i - 1) * (tw + gap), -a.top, tw, th, d[2])
    end
    local panel = U.Panel(c, "list", true)
    panel:SetPoint("TOPLEFT", a.left, -(a.top + th + 6))
    panel:SetPoint("BOTTOMRIGHT", -a.right, a.bottom + O.CHART_H + 4)
    O.BuildChart(c, a)
    O.panel = panel
    O.table = U.Table(panel, {
        columns = {
            { key = "name", title = L.COL_CHAR,
              format = function(v, r) return W.ClassColored(v, r.class) .. (r.me and (GREY .. " " .. L.OV_ME .. "|r") or "") end,
              sort = function(r) return W.Lower(r.name) end },
            { key = "level", title = L.COL_LEVEL, width = 60, align = "RIGHT" },
            { key = "money", title = L.COL_GOLD, width = 120, align = "RIGHT", format = function(v) return v and ns.Money(v, true) or (GREY .. "–|r") end },
            { key = "lager", title = L.COL_LAGER, width = 120, align = "RIGHT", format = function(v) return v and v > 0 and ns.Money(math.floor(v + 0.5), true) or (GREY .. "–|r") end },
            { key = "worth", title = L.COL_WORTH, width = 130, align = "RIGHT", format = function(v) return v and ns.Money(math.floor(v + 0.5), true) or (GREY .. "–|r") end,
              sort = function(r) return r.worth or -1 end },
            { key = "seen", title = L.COL_SEEN, width = 90, align = "RIGHT", format = function(v, r) return r.me and L.AGE_NOW or ns.Age(v) end,
              sort = function(r) return r.me and math.huge or (r.seen or 0) end },
        },
        sortKey = "money", sortDesc = true,
        empty = L.OV_EMPTY,
        onEnter = function(row, r) O.RowTooltip(row, r) end,
    })
end

W.pages.overview = { build = O.Build, refresh = O.Refresh, status = O.Status }
