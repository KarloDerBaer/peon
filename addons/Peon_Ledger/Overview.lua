-- Peon_Ledger - Overview.lua
-- Reiter "Uebersicht": "Wie stehe ich da?" (ab 0.14 mit Peon.UI, Konzept Peon_Ledger_Neuaufbau.md Abschnitt 6.1)
-- Ab 0.18 schlank (Konzept Peon_Ledger_Schlank.md Abschnitt 4, KarloDerBaer): ohne Vermoegen und Marktwert.
--   oben drei Kacheln: Gold gesamt (Anzahl Charaktere), Gold 24 Std. (Mausover: hoechster und tiefster Stand),
--   AH-Erloes heute aus den Rechnungen (Mausover: Handelsgewinn, geschaetzt)
--   darunter alle Charaktere des Realms: Name, Stufe, Gold, 24 Std., zuletzt gesehen. Klick oeffnet den Charakter im
--   Reiter Charaktere.
--   unten ein Diagramm mit waehlbaren Linien (Gold, AH-Erloes, Handelsgewinn, Gold je Charakter), Zeitraum 1 T bis Alles.
--   Ab 0.14.1 ohne Post (KarloDerBaer): Das Spiel nennt die Post erst am Briefkasten, die Zahl war oft veraltet.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local O = {}
ns.Overview = O

local GREY = W.GREY

function O.Rows()
    local I = ns.Inventory
    local rows, me = {}, ns.CharName()
    for name, c in pairs(I.RealmData().chars) do
        local r = {
            name = name, class = c.class, me = name == me, money = c.money, level = c.level, faction = c.faction,
            bags = I.PlaceCount(c, "bags"), bank = I.PlaceCount(c, "bank"), auctions = I.PlaceCount(c, "auctions"),
            equip = I.PlaceCount(c, "equip"), transit = I.PlaceCount(c, "transit"),
            seen = c.seen, slots = {},
        }
        r.d24 = ns.Trend.Change(name)
        for _, key in ipairs({ "bags", "bank", "auctions" }) do
            local used, all = I.PlaceSlots(c, key)
            if used then r.slots[key] = { used, all } end
        end
        rows[#rows + 1] = r
    end
    return rows
end

function O.Totals(rows)
    local t = { money = 0, chars = 0 }
    for _, r in ipairs(rows) do
        if type(r.money) == "number" then t.money = t.money + r.money; t.chars = t.chars + 1 end
    end
    return t
end

-- Kachel: Ueberschrift, grosser Wert, kleiner Zusatz, optional Tooltip (tip(self))
local function Tile(parent, x, y, w, h, title, tip)
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
    -- ab 0.15: Zusatz bleibt in der Kachel (vorher lief er in die naechste)
    p.sub:SetWidth(w - 24)
    if p.sub.SetWordWrap then p.sub:SetWordWrap(false) end
    function p:Set(big, sub) self.big:SetText(big or ""); self.sub:SetText(sub or "") end
    if tip then
        if p.EnableMouse then p:EnableMouse(true) end
        p:SetScript("OnEnter", function(self) tip(self) end)
        p:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    return p
end

-- Beginn des heutigen Tages
local function Today(now)
    local d = date("*t", now or time())
    return time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
end

-- AH-Erloes ab einem Zeitpunkt aus den Rechnungen: Summe (Kupfer), Anzahl Verkaeufe
function O.AHRevenue(from)
    local sum, n = 0, 0
    for _, e in ipairs(ns.Moves.List()) do
        if e.k == "ahsold" and type(e.m) == "number" and e.m > 0 and (e.t or 0) >= from then
            sum, n = sum + e.m, n + 1
        end
    end
    return sum, n
end

-- Zusatz der Kachel Gold 24 Std.: "seit 24 Std." oder "seit 14:05" (Messung juenger)
local function SinceText(since, now)
    if not since or since <= (now or time()) - 86400 + 60 then return L.OV_D24_SUB end
    return L.OV_D24_SINCE:format(date("%H:%M", since))
end

function O.Refresh()
    if not O.table then return end
    local rows = O.Rows()
    O.table:SetData(rows)
    local t = O.Totals(rows)
    O.totals = t
    if ns.Trend then mod:Call("Verlauf Gold", ns.Trend.Record) end
    O.tiles.gold:Set(ns.Money(t.money, true), ns.Plural(t.chars, "OV_CHARS"))
    local now = time()
    local d, hi, lo, since = ns.Trend.Change(nil, now)
    O.day = { d = d, hi = hi, lo = lo, since = since }
    if d then O.tiles.day:Set(W.Signed(d), SinceText(since, now)) else O.tiles.day:Set(GREY .. "–|r", GREY .. L.OV_D24_NONE .. "|r") end
    local sum, n = O.AHRevenue(Today(now))
    O.ahToday = { sum = sum, n = n }
    O.tiles.ah:Set(ns.Money(sum, true), ns.Plural(n, "OV_AH_SALES"))
    mod:Call("Diagramm", O.DrawChart)
end

-- Tooltip der Kachel Gold 24 Std.: hoechster und tiefster Stand
function O.DayTooltip(owner)
    if not GameTooltip then return end
    local x = O.day or {}
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.OV_T_D24, 1, 0.82, 0)
    if x.d then
        GameTooltip:AddDoubleLine(L.OV_D24_HI, ns.Money(x.hi or 0, true), 0.9, 0.9, 0.9, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.OV_D24_LO, ns.Money(x.lo or 0, true), 0.9, 0.9, 0.9, 1, 1, 1)
    end
    GameTooltip:AddLine(L.OV_D24_TT, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- Tooltip der Kachel AH-Erloes: Handelsgewinn heute, geschaetzt
function O.AHTooltip(owner)
    if not GameTooltip then return end
    local today = ns.Book.Collect("today", false)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.OV_T_AH, 1, 0.82, 0)
    GameTooltip:AddLine(L.OV_AH_TT, 0.9, 0.9, 0.9, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.BK_R_TRADE, W.Signed(today.trade or 0), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddLine(L.OV_TRADE_EST, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Diagramm (ab 0.14.5, ab 0.18 mit waehlbaren Linien)
---------------------------------------------------------------------------
O.CHART_H = 196
O.COLORS = { gold = { 1, 0.82, 0, 1 }, ah = { 0.35, 0.85, 0.35, 1 }, trade = { 0.45, 0.7, 1, 1 } }
-- Farben fuer die Linien je Charakter (der Reihe nach)
O.CHAR_COLORS = {
    { 0.95, 0.5, 0.25, 1 }, { 0.8, 0.45, 0.95, 1 }, { 0.3, 0.85, 0.85, 1 }, { 0.95, 0.4, 0.6, 1 },
    { 0.7, 0.75, 0.3, 1 }, { 0.55, 0.6, 1, 1 }, { 0.9, 0.9, 0.9, 1 }, { 0.6, 0.4, 0.25, 1 },
}
-- feste Linien: Schluessel, Beschriftung, Vorgabe an (Konzept Abschnitt 4.3)
O.LINES = { { key = "gold", label = "TR_GOLD", on = true }, { key = "ah", label = "TR_AH", on = true },
            { key = "trade", label = "TR_TRADE_EST", on = false } }

local function Short(v) if v == nil then return "" end return (v < 0 and "-" or "") .. Peon.ShortGold(math.abs(v)) end

-- Linie sichtbar? mod.db.trendLines[key] (ab 0.18), sonst Vorgabe. Fuer Gold gilt noch trendOff aus 0.14.5.
function O.LineOn(key)
    local v = type(mod.db.trendLines) == "table" and mod.db.trendLines[key]
    if v ~= nil and v ~= false and v ~= true then v = nil end
    if v ~= nil then return v end
    for _, l in ipairs(O.LINES) do
        if l.key == key then
            if key == "gold" and type(mod.db.trendOff) == "table" and mod.db.trendOff.gold then return false end
            return l.on
        end
    end
    return false   -- Linien je Charakter: Vorgabe aus
end

function O.SetLine(key, on)
    if type(mod.db.trendLines) ~= "table" then mod.db.trendLines = {} end
    mod.db.trendLines[key] = on and true or false
    mod:Call("Diagramm", O.DrawChart)
end

-- Charaktere fuer das Menue und die Linien: eingeloggter zuerst, dann nach Name
function O.ChartChars()
    local names, me = {}, ns.CharName()
    for name in pairs(ns.Inventory.RealmData().chars) do names[#names + 1] = name end
    table.sort(names, function(a, b) if (a == me) ~= (b == me) then return a == me end return a < b end)
    return names
end

function O.CharColor(i) return O.CHAR_COLORS[((i - 1) % #O.CHAR_COLORS) + 1] end

local function Hex(c) return ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255)) end

-- sichtbare Linien als { key, label, color, kind = "gold"|"sum" }
function O.VisibleLines()
    local out = {}
    for _, l in ipairs(O.LINES) do
        if O.LineOn(l.key) then out[#out + 1] = { key = l.key, label = L[l.label], color = O.COLORS[l.key], sum = l.key ~= "gold" } end
    end
    for i, name in ipairs(O.ChartChars()) do
        local key = "char:" .. name
        if O.LineOn(key) then out[#out + 1] = { key = key, name = name, label = ns.Tooltip.Short(name), color = O.CharColor(i) } end
    end
    return out
end

function O.DrawChart()
    local ch = O.chart
    if not ch then return end
    local d = ns.Trend.Series(mod.db.trendRange or "d7")
    O.series = d
    local series = {}
    O.lines = O.VisibleLines()
    local anyRight = false
    for _, l in ipairs(O.lines) do
        if l.key == "gold" then
            series[#series + 1] = { key = "gold", kind = "line", axis = "left", values = d.gold, color = l.color, width = 2, connect = true, label = l.label }
        elseif l.name then
            series[#series + 1] = { key = l.key, kind = "line", axis = "left", values = d.chars[l.name] or {}, color = l.color, width = 2, connect = true, label = l.label }
        else
            anyRight = true
            series[#series + 1] = { key = l.key, kind = "step", axis = "right", values = d[l.key], color = l.color, width = 2, label = l.label }
        end
    end
    if anyRight then series[#series + 1] = { key = "zero", kind = "hline", axis = "right", value = 0, color = { 0.45, 0.7, 1, 0.3 } } end
    ch:SetData(d.n, series)
    -- rechte Achse (Erloes, Handelsgewinn) mindestens 1g hoch, sonst stuenden bei 0 nur "0s"-Beschriftungen (ab 0.14.6)
    local lo, hi = 0, 0
    for _, l in ipairs(O.lines) do
        if l.sum then for i = 1, d.n do local v = d[l.key][i]; if v then lo, hi = math.min(lo, v), math.max(hi, v) end end end
    end
    if hi - lo < 10000 then ch:SetRange("right", lo, lo + 10000) else ch:SetRange("right", nil, nil) end
    ch:Draw()
    for _, b in ipairs(O.rangeButtons or {}) do
        if b.key == (mod.db.trendRange or "d7") then b:Disable() else b:Enable() end
    end
    O.ChartHover(nil)
end

-- Werte unter der Maus, sonst die sichtbaren Linien in ihrer Farbe
function O.ChartHover(i)
    local d = O.series
    if not O.chartInfo then return end
    local lines = O.lines or {}
    if not i or not d or not d.ends[i] or not d.last or i > d.last then
        local parts = {}
        for _, l in ipairs(lines) do parts[#parts + 1] = Hex(l.color) .. "■|r " .. l.label end
        O.chartInfo:SetText(table.concat(parts, "   ") .. (#parts > 0 and "   " or "") .. W.GREY .. L.TR_HINT .. "|r")
        return
    end
    local fmt = (d.key == "d1" or d.key == "d7") and "%d.%m. %H:%M" or "%d.%m."
    local parts = { date(fmt, math.min(d.ends[i], d.now or d.ends[i])) }
    for _, l in ipairs(lines) do
        local v
        if l.name then v = d.chars[l.name] and d.chars[l.name][i] else v = d[l.key] and d[l.key][i] end
        if v then
            parts[#parts + 1] = Hex(l.color) .. l.label .. "|r " .. (l.sum and W.Signed(v) or ns.Money(v, true))
        end
    end
    O.chartInfo:SetText(table.concat(parts, "   "))
end

-- Menue "Linien": feste Linien und je Charakter ein Haken
function O.BuildLineMenu(root)
    for _, l in ipairs(O.LINES) do
        root:CreateCheckbox(Hex(O.COLORS[l.key]) .. L[l.label] .. "|r", function() return O.LineOn(l.key) end,
            function() O.SetLine(l.key, not O.LineOn(l.key)) end)
    end
    if root.CreateDivider then root:CreateDivider() end
    if root.CreateTitle then root:CreateTitle(L.TR_CHARS) end
    for i, name in ipairs(O.ChartChars()) do
        local key = "char:" .. name
        root:CreateCheckbox(Hex(O.CharColor(i)) .. name .. "|r", function() return O.LineOn(key) end,
            function() O.SetLine(key, not O.LineOn(key)) end)
    end
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
    O.lineMenu = U.FilterDropdown(p, L.TR_LINES, O.BuildLineMenu)
    O.lineMenu:SetPoint("TOPRIGHT", -10, -6)
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
    local p7 = ns.Book.Collect("d7", true, nil, r.name)
    GameTooltip:AddDoubleLine(L.TT_PROFIT7, W.Signed(p7.profit), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddLine(L.OV_ROW_CLICK, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

function O.Build(c)
    local U = Peon.UI
    local a = W.Area()
    O.tiles = {}
    local gap = 4
    local defs = { { "gold", L.OV_T_GOLD }, { "day", L.OV_T_D24, O.DayTooltip }, { "ah", L.OV_T_AH, O.AHTooltip } }
    local tw = math.floor((a.width - (#defs - 1) * gap) / #defs)
    local th = 64
    for i, d in ipairs(defs) do
        O.tiles[d[1]] = Tile(c, a.left + (i - 1) * (tw + gap), -a.top, tw, th, d[2], d[3])
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
            { key = "money", title = L.COL_GOLD, width = 130, align = "RIGHT", format = function(v) return v and ns.Money(v, true) or (GREY .. "–|r") end },
            { key = "d24", title = L.COL_D24, width = 130, align = "RIGHT", format = function(v) return v and W.Signed(v) or (GREY .. "–|r") end,
              sort = function(r) return r.d24 or -math.huge end },
            { key = "seen", title = L.COL_SEEN, width = 100, align = "RIGHT", format = function(v, r) return r.me and L.AGE_NOW or ns.Age(v) end,
              sort = function(r) return r.me and math.huge or (r.seen or 0) end },
        },
        sortKey = "money", sortDesc = true,
        empty = L.OV_EMPTY,
        onEnter = function(row, r) O.RowTooltip(row, r) end,
        onClick = function(r, button) if button == "LeftButton" and r and ns.Chars then ns.Chars.Open(r.name) end end,
    })
end

W.pages.overview = { build = O.Build, refresh = O.Refresh, status = O.Status }
