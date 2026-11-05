-- Peon - Chart.lua
-- Diagramm mit zwei Achsen, Linien, Flaechen, Balken, Punkten und Markierungen (ab API 10).
-- Reine Erweiterung, bestehende Funktionen bleiben unveraendert.
--
--   local ch = Peon.NewChart(parent, {
--       width = 480, height = 130,
--       left = 40, right = 44, top = 6, bottom = 6,   -- Rand fuer die Achsen-Beschriftung
--       grid = 2,                                     -- Hilfslinien (Abschnitte)
--       leftFormat  = function(v) return text end,    -- Beschriftung linke Achse (nil = keine)
--       rightFormat = function(v) return text end,    -- Beschriftung rechte Achse
--       onHover = function(chart, index) end,         -- Maus ueber dem Diagramm (index 1..n)
--       onLeave = function(chart) end,
--   })
--   ch:SetData(n, {                                    -- n Punkte (Tage) von links nach rechts
--       { key = "md", kind = "line", axis = "left", color = { r, g, b, a }, width = 2, dash = 4, values = { ... } },
--       { key = "cost", kind = "step", ... },           -- Stufenlinie
--       { key = "band", kind = "band", values = oben, values2 = unten, color = ... },        -- Flaeche
--       { key = "zone", kind = "zone", values = a, values2 = b, color = gut, colorBelow = schlecht },  -- zweifarbig
--       { key = "st", kind = "bar", axis = "right", values = ..., size = 0.6 },             -- Balken (Anteil der Breite)
--       { key = "sell", kind = "points", shape = "circle"|"square", size = 6, values = ... },
--       { key = "ev", kind = "marks", values = { [i] = true } },                             -- senkrechte Striche
--       { key = "ven", kind = "hline", value = 33 },                                          -- waagerechte Linie
--   })                                                 -- nil in values = Luecke; hidden = true = aus
--   ch:SetRange("left", min, max)  -- fester Bereich (nil = automatisch); ch:GetRange("left")
--   connect = true bei line/step: Luecken (nil) werden ueberbrueckt
--   ch:SetSize(breite, hoehe)      -- Groesse aendern (danach Draw)
--   ch:Draw(); ch:SetShown(key, bool); ch:IsShownKey(key); ch:SetHover(index oder nil)
--   ch:CreateLegend(parent, { keys }, onToggle)   -- Reihe kleiner Knoepfe (Farbe + Name), Klick = an/aus
--   Peon.LinkCharts({ ch1, ch2 }, { shareLeft = true })  -- gemeinsame Mauslinie, gleicher Bereich links

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local L = ns.L

local Chart = {}
Chart.__index = Chart
Peon.ChartPrototype = Chart

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function Num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and not Peon.IsSecret(v) end
local function Col(c) c = c or {}; return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1 end

-- "schoene" Achsengrenzen: Schritt 1/2/5 x 10^k
function Peon.NiceRange(lo, hi, steps)
    steps = steps or 2
    if not Num(lo) or not Num(hi) then return 0, 1 end
    if hi < lo then lo, hi = hi, lo end
    if hi == lo then
        if hi == 0 then return 0, 1 end
        lo, hi = lo * 0.9, hi * 1.1
        if hi < lo then lo, hi = hi, lo end
    end
    local raw = (hi - lo) / steps
    local p = 10 ^ math.floor(math.log10 and math.log10(raw) or (math.log(raw) / math.log(10)))
    local step
    for _, m in ipairs({ 1, 2, 2.5, 5, 10 }) do
        step = m * p
        if math.floor(lo / step) * step + step * steps >= hi then break end
    end
    local a = math.floor(lo / step) * step
    local b = a + step * steps
    while b < hi do b = b + step end
    return a, b
end

local function Call(chart, where, fn, ...)
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        chart.reported = chart.reported or {}
        local k = tostring(where) .. tostring(err)
        if not chart.reported[k] then
            chart.reported[k] = true
            Peon.Print(L.MSG_ERROR:format("Chart " .. tostring(where), tostring(err)))
        end
    end
end

function Peon.NewChart(parent, o)
    o = o or {}
    local ch = setmetatable({ o = o, n = 0, series = {}, shown = {}, fixed = {}, range = {},
        pools = { line = {}, tex = {}, text = {} }, used = {} }, Chart)
    ch.width, ch.height = o.width or 400, o.height or 120
    ch.padL, ch.padR, ch.padT, ch.padB = o.left or 40, o.right or 40, o.top or 6, o.bottom or 6
    ch.plotW = math.max(10, ch.width - ch.padL - ch.padR)
    ch.plotH = math.max(10, ch.height - ch.padT - ch.padB)

    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(ch.width, ch.height)
    ch.frame = f
    local plot = CreateFrame("Frame", nil, f)
    plot:SetSize(ch.plotW, ch.plotH)
    plot:SetPoint("BOTTOMLEFT", ch.padL, ch.padB)
    ch.plot = plot
    local bg = plot:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.25)

    -- Maus: Index unter dem Mauszeiger
    f:EnableMouse(true)
    f:SetScript("OnEnter", function() ch.mouse = true end)
    f:SetScript("OnLeave", function()
        ch.mouse = false
        ch:HoverAll(nil)
    end)
    f:SetScript("OnUpdate", function()
        if not ch.mouse or ch.n < 1 then return end
        local x = GetCursorPosition()
        local scale = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
        local left = plot.GetLeft and plot:GetLeft()
        if not Num(x) or not Num(left) or scale == 0 then return end
        local idx = ch:IndexAt(x / scale - left)
        if idx ~= ch.hover then ch:HoverAll(idx) end
    end)
    return ch
end

function Chart:SetSize(w, h)
    self.width, self.height = w or self.width, h or self.height
    self.plotW = math.max(10, self.width - self.padL - self.padR)
    self.plotH = math.max(10, self.height - self.padT - self.padB)
    self.frame:SetSize(self.width, self.height)
    self.plot:SetSize(self.plotW, self.plotH)
end

function Chart:GetWidth() return self.width end
function Chart:GetHeight() return self.height end

function Chart:SetData(n, series)
    self.n = Num(n) and math.max(0, math.floor(n)) or 0
    self.series = type(series) == "table" and series or {}
    for _, s in ipairs(self.series) do
        if s.key and self.shown[s.key] == nil then self.shown[s.key] = not s.hidden end
    end
    if self.hover and self.hover > self.n then self.hover = nil end
    self:Draw()
end

function Chart:SetShown(key, on)
    self.shown[key] = on and true or false
    if self.linked then for _, c in ipairs(self.linked) do c:Draw() end else self:Draw() end
end
function Chart:IsShownKey(key) return self.shown[key] ~= false end

function Chart:SetRange(axis, lo, hi)
    if Num(lo) and Num(hi) then self.fixed[axis] = { lo, hi } else self.fixed[axis] = nil end
end

-- Werte einer Achse (sichtbare Reihen)
function Chart:Extent(axis)
    local lo, hi
    local function add(v) if Num(v) then lo = (lo == nil or v < lo) and v or lo; hi = (hi == nil or v > hi) and v or hi end end
    for _, s in ipairs(self.series) do
        if (s.axis or "left") == axis and self:IsShownKey(s.key) and s.kind ~= "marks" then
            if s.kind == "hline" then add(s.value)
            else
                for i = 1, self.n do add(s.values and s.values[i]); if s.values2 then add(s.values2[i]) end end
            end
            if s.kind == "bar" then add(0) end
        end
    end
    return lo, hi
end

function Chart:GetRange(axis)
    local r = self.range[axis]
    if r then return r[1], r[2] end
    return nil
end

function Chart:ComputeRange(axis)
    if self.fixed[axis] then self.range[axis] = self.fixed[axis]; return end
    local lo, hi = self:Extent(axis)
    if lo == nil then self.range[axis] = nil; return end
    if axis == "right" or (self.o.zeroBased and self.o.zeroBased[axis]) then lo = math.min(0, lo) end
    local a, b = Peon.NiceRange(lo, hi, self.o.grid or 2)
    self.range[axis] = { a, b }
end

function Chart:X(i)
    if self.n <= 1 then return self.plotW / 2 end
    return (i - 1) * self.plotW / (self.n - 1)
end
function Chart:Y(axis, v)
    local r = self.range[axis]
    if not r or not Num(v) or r[2] == r[1] then return nil end
    local y = (v - r[1]) / (r[2] - r[1]) * self.plotH
    if y < 0 then y = 0 elseif y > self.plotH then y = self.plotH end
    return y
end
function Chart:IndexAt(px)
    if self.n < 1 or not Num(px) then return nil end
    if px < -4 or px > self.plotW + 4 then return nil end
    if self.n == 1 then return 1 end
    local i = math.floor(px / self.plotW * (self.n - 1) + 1.5)
    return math.max(1, math.min(self.n, i))
end

---------------------------------------------------------------------------
-- Zeichnen (Objekte werden wiederverwendet)
---------------------------------------------------------------------------
local function Get(ch, kind)
    local pool, used = ch.pools[kind], ch.used
    used[kind] = (used[kind] or 0) + 1
    local obj = pool[used[kind]]
    if not obj then
        if kind == "line" then
            obj = ch.plot.CreateLine and ch.plot:CreateLine(nil, "ARTWORK")
            if not obj then obj = false end
        elseif kind == "tex" then
            obj = ch.plot:CreateTexture(nil, "ARTWORK")
        else
            obj = ch.frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        end
        pool[used[kind]] = obj
    end
    if obj and obj.Show then obj:Show() end
    return obj
end

local function Rect(ch, x, y, w, h, c, layer, sub, tex)
    local t = Get(ch, "tex")
    t:SetDrawLayer(layer or "ARTWORK", sub or 0)
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", ch.plot, "BOTTOMLEFT", x, y)
    t:SetSize(math.max(w, 0.5), math.max(h, 0.5))
    if tex then t:SetTexture(tex); t:SetVertexColor(Col(c))
    else
        if t.SetVertexColor then t:SetVertexColor(1, 1, 1, 1) end   -- Farbe eines frueheren Punktes nicht mitnehmen
        t:SetColorTexture(Col(c))
    end
    if t.SetVertexOffset then for v = 1, 4 do t:SetVertexOffset(v, 0, 0) end end
    return t
end

-- Linie von (x1,y1) nach (x2,y2); ohne CreateLine Rueckfall auf kleine Kaestchen
local function Seg(ch, x1, y1, x2, y2, c, w, layer, sub)
    w = w or 1
    local l = Get(ch, "line")
    if l then
        l:SetDrawLayer(layer or "ARTWORK", sub or 0)
        l:SetThickness(w)
        l:SetColorTexture(Col(c))
        l:SetStartPoint("BOTTOMLEFT", ch.plot, x1, y1)
        l:SetEndPoint("BOTTOMLEFT", ch.plot, x2, y2)
        return
    end
    ch.used.line = ch.used.line - 1
    if math.abs(y2 - y1) < 0.5 then Rect(ch, math.min(x1, x2), y1 - w / 2, math.abs(x2 - x1), w, c, layer, sub); return end
    if math.abs(x2 - x1) < 0.5 then Rect(ch, x1 - w / 2, math.min(y1, y2), w, math.abs(y2 - y1), c, layer, sub); return end
    local steps = math.max(1, math.floor(math.max(math.abs(x2 - x1), math.abs(y2 - y1)) / 3))
    for k = 0, steps - 1 do
        local xa, ya = x1 + (x2 - x1) * k / steps, y1 + (y2 - y1) * k / steps
        Rect(ch, xa - w / 2, ya - w / 2, math.max(w, math.abs(x2 - x1) / steps), w, c, layer, sub)
    end
end

-- Linie mit Strichelung (dash = Laenge von Strich und Luecke)
local function DSeg(ch, x1, y1, x2, y2, c, w, dash, layer, sub)
    if not dash or dash <= 0 then return Seg(ch, x1, y1, x2, y2, c, w, layer, sub) end
    local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    if len <= 0 then return end
    local pos, on = ch.dashPos or 0, true
    local p = 0
    while p < len do
        local seg = dash - (pos % dash)
        local q = math.min(len, p + seg)
        if math.floor(pos / dash) % 2 == 0 then
            Seg(ch, x1 + (x2 - x1) * p / len, y1 + (y2 - y1) * p / len, x1 + (x2 - x1) * q / len, y1 + (y2 - y1) * q / len, c, w, layer, sub)
        end
        pos = pos + (q - p)
        p = q
    end
    ch.dashPos = pos
end

-- Flaeche zwischen zwei Linien im Abschnitt x1..x2 (Trapez mit SetVertexOffset, sonst Rechteck)
local function Quad(ch, x1, x2, top1, top2, bot1, bot2, c)
    local hi, lo = math.max(top1, top2, bot1, bot2), math.min(top1, top2, bot1, bot2)
    local t = Rect(ch, x1, lo, x2 - x1, hi - lo, c, "BORDER", 0)
    if t.SetVertexOffset then
        -- Ecken: 1 oben links, 2 unten links, 3 oben rechts, 4 unten rechts
        t:SetVertexOffset(1, 0, top1 - hi)
        t:SetVertexOffset(2, 0, bot1 - lo)
        t:SetVertexOffset(3, 0, top2 - hi)
        t:SetVertexOffset(4, 0, bot2 - lo)
    else
        t:ClearAllPoints()
        local a, b = (top1 + top2) / 2, (bot1 + bot2) / 2
        t:SetPoint("BOTTOMLEFT", ch.plot, "BOTTOMLEFT", x1, math.min(a, b))
        t:SetSize(math.max(x2 - x1, 0.5), math.max(math.abs(a - b), 0.5))
    end
end

-- Punkt ohne Nachbarn: eine Linie braucht zwei Punkte, einzelne Werte waeren sonst unsichtbar (ab 0.11.1)
local function LonePoints(ch, s, axis)
    local total = 0
    if s.connect then
        for i = 1, ch.n do if ch:Y(axis, s.values[i]) then total = total + 1 end end
    end
    local size = math.max((s.width or 2) + 3, 5)
    for i = 1, ch.n do
        local y = ch:Y(axis, s.values[i])
        if y then
            local alone
            if s.connect then alone = total == 1
            else alone = not ch:Y(axis, s.values[i - 1]) and not ch:Y(axis, s.values[i + 1]) end
            if alone then Rect(ch, ch:X(i) - size / 2, y - size / 2, size, size, s.color, "OVERLAY", 1, CIRCLE) end
        end
    end
end

local DRAW = {}
function DRAW.line(ch, s, axis)
    ch.dashPos = 0
    local px, py
    for i = 1, ch.n do
        local y = ch:Y(axis, s.values[i])
        local x = ch:X(i)
        if y and px then DSeg(ch, px, py, x, y, s.color, s.width or 2, s.dash, "ARTWORK", s.layer or 2) end
        if y then px, py = x, y elseif not s.connect then px, py = nil, nil end
    end
    LonePoints(ch, s, axis)
end
function DRAW.step(ch, s, axis)
    ch.dashPos = 0
    local px, py
    for i = 1, ch.n do
        local y = ch:Y(axis, s.values[i])
        local x = ch:X(i)
        if y and px then
            DSeg(ch, px, py, x, py, s.color, s.width or 2, s.dash, "ARTWORK", s.layer or 2)
            if math.abs(y - py) >= 0.5 then DSeg(ch, x, py, x, y, s.color, s.width or 2, s.dash, "ARTWORK", s.layer or 2) end
        end
        if y then px, py = x, y elseif not s.connect then px, py = nil, nil end
    end
    LonePoints(ch, s, axis)
end
local function Area(ch, s, axis, two)
    local a, b = s.values, s.values2 or {}
    for i = 1, ch.n - 1 do
        local t1, t2, b1, b2 = ch:Y(axis, a[i]), ch:Y(axis, a[i + 1]), ch:Y(axis, b[i]), ch:Y(axis, b[i + 1])
        if t1 and t2 and b1 and b2 then
            local c = s.color
            if two and (a[i] + a[i + 1]) < (b[i] + b[i + 1]) then c = s.colorBelow or s.color end
            Quad(ch, ch:X(i), ch:X(i + 1), t1, t2, b1, b2, c)
        end
    end
end
function DRAW.band(ch, s, axis) Area(ch, s, axis, false) end
function DRAW.zone(ch, s, axis) Area(ch, s, axis, true) end
function DRAW.bar(ch, s, axis)
    local slot = ch.n > 1 and ch.plotW / (ch.n - 1) or ch.plotW
    local w = math.max(1, slot * (s.size or 0.6))
    local y0 = ch:Y(axis, 0) or 0
    for i = 1, ch.n do
        local y = ch:Y(axis, s.values[i])
        if y and s.values[i] ~= 0 then
            local c = s.color
            if s.colorBelow and s.values[i] < 0 then c = s.colorBelow end
            Rect(ch, ch:X(i) - w / 2, math.min(y, y0), w, math.abs(y - y0), c, "ARTWORK", s.layer or 0)
        end
    end
end
function DRAW.points(ch, s, axis)
    local size = s.size or 6
    for i = 1, ch.n do
        local y = ch:Y(axis, s.values[i])
        if y then
            Rect(ch, ch:X(i) - size / 2, y - size / 2, size, size, s.color, "OVERLAY", 2, s.shape == "circle" and CIRCLE or nil)
        end
    end
end
function DRAW.marks(ch, s)
    for i = 1, ch.n do
        if s.values[i] then Rect(ch, ch:X(i) - 0.5, 0, 1, ch.plotH, s.color, "BORDER", 2) end
    end
end
function DRAW.hline(ch, s, axis)
    local y = ch:Y(axis, s.value)
    if y then ch.dashPos = 0; DSeg(ch, 0, y, ch.plotW, y, s.color, s.width or 1, s.dash, "ARTWORK", 1) end
end

local ORDER = { band = 1, zone = 1, marks = 2, bar = 3, hline = 4, line = 5, step = 5, points = 6 }

function Chart:Draw()
    for kind, pool in pairs(self.pools) do
        for i = 1, #pool do local o = pool[i]; if o and o.Hide then o:Hide() end end
    end
    self.used = {}
    self:ComputeRange("left")
    self:ComputeRange("right")
    if self.linkRange then self.linkRange(self) end
    -- Hilfslinien und Beschriftung
    local grid = self.o.grid or 2
    for g = 0, grid do
        local y = self.plotH * g / grid
        Rect(self, 0, y - 0.5, self.plotW, 1, { 1, 1, 1, 0.08 }, "BACKGROUND", 1)
        for _, side in ipairs({ "left", "right" }) do
            local r, fmt = self.range[side], self.o[side .. "Format"]
            if r and fmt then
                local ok, txt = pcall(fmt, r[1] + (r[2] - r[1]) * g / grid)
                local fs = Get(self, "text")
                fs:ClearAllPoints()
                if side == "left" then
                    fs:SetPoint("RIGHT", self.frame, "BOTTOMLEFT", self.padL - 3, self.padB + y)
                    fs:SetJustifyH("RIGHT")
                else
                    fs:SetPoint("LEFT", self.frame, "BOTTOMLEFT", self.padL + self.plotW + 3, self.padB + y)
                    fs:SetJustifyH("LEFT")
                end
                fs:SetText(ok and txt or "?")
            end
        end
    end
    -- Reihen in fester Reihenfolge (Flaechen hinten, Punkte vorne)
    local list = {}
    for idx, s in ipairs(self.series) do
        if self:IsShownKey(s.key) and DRAW[s.kind or "line"] and (s.values or s.kind == "hline") then list[#list + 1] = { s = s, i = idx } end
    end
    table.sort(list, function(a, b)
        local oa, ob = ORDER[a.s.kind or "line"] or 5, ORDER[b.s.kind or "line"] or 5
        if oa ~= ob then return oa < ob end
        return a.i < b.i
    end)
    for _, e in ipairs(list) do
        local s = e.s
        local ok, err = pcall(DRAW[s.kind or "line"], self, s, s.axis or "left")
        if not ok then Call(self, "draw " .. tostring(s.key), error, err) end
    end
    -- Mauslinie
    self.hoverLine = nil
    if self.hover and self.n > 0 then
        self.hoverLine = Rect(self, self:X(self.hover) - 0.5, 0, 1, self.plotH, { 1, 1, 1, 0.6 }, "OVERLAY", 7)
    end
    if self.legend then self.legend:Update() end
end

function Chart:SetHover(idx)
    if idx ~= nil and (not Num(idx) or idx < 1 or idx > self.n) then idx = nil end
    if idx == self.hover then return end
    self.hover = idx
    self:Draw()
    if idx then Call(self, "onHover", self.o.onHover, self, idx) end
end

function Chart:HoverAll(idx)
    if self.linked then
        for _, c in ipairs(self.linked) do c:SetHover(idx) end
    else
        self:SetHover(idx)
    end
    if idx == nil and self.o.onLeave then Call(self, "onLeave", self.o.onLeave, self) end
end

-- Mehrere Diagramme: gemeinsame Mauslinie, auf Wunsch gleicher Bereich der linken Achse
function Peon.LinkCharts(charts, opts)
    opts = opts or {}
    for _, c in ipairs(charts) do
        c.linked = charts
        if opts.shareLeft then
            c.linkRange = function(self)
                if self.fixed.left then return end
                local lo, hi
                for _, o in ipairs(charts) do
                    local a, b = o:Extent("left")
                    if a then lo = (lo == nil or a < lo) and a or lo; hi = (hi == nil or b > hi) and b or hi end
                end
                if lo then local a, b = Peon.NiceRange(lo, hi, self.o.grid or 2); self.range.left = { a, b } end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Legende: Knoepfe mit Farbe und Namen, Klick schaltet an/aus
---------------------------------------------------------------------------
function Chart:CreateLegend(parent, keys, onToggle)
    local lg = { chart = self, buttons = {} }
    local f = CreateFrame("Frame", nil, parent)
    lg.frame = f
    local x = 0
    for _, key in ipairs(keys or {}) do
        -- Reihe mit Beschriftung bevorzugen (mehrere Reihen koennen denselben Schluessel haben;
        -- bis 0.10 gewann die letzte – die Legende zeigte dann z. B. "zone" statt "Gewinnzone")
        local s
        for _, ss in ipairs(self.series) do
            if ss.key == key and (not s or (ss.label and not s.label)) then s = ss end
        end
        if not s and self.legendInfo then s = self.legendInfo[key] end
        if s then
            local b = CreateFrame("Button", nil, f)
            local sw = b:CreateTexture(nil, "ARTWORK")
            sw:SetSize(s.kind == "points" and 6 or 10, (s.kind == "bar" or s.kind == "band" or s.kind == "zone" or s.kind == "points") and 6 or 2)
            sw:SetPoint("LEFT", 2, 0)
            if s.kind == "points" and s.shape == "circle" then sw:SetTexture(CIRCLE); sw:SetVertexColor(Col(s.legendColor or s.color))
            else sw:SetColorTexture(Col(s.legendColor or s.color)) end
            local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", 15, 0)
            fs:SetText(s.label or key)
            local w = 18 + ((fs.GetStringWidth and fs:GetStringWidth()) or 40) + 4
            if not Num(w) or w < 20 then w = 60 end
            b:SetSize(w, 14)
            b:SetPoint("LEFT", f, "LEFT", x, 0)
            x = x + w + 4
            b.key, b.sw, b.fs = key, sw, fs
            b:SetScript("OnClick", function()
                local on = not self:IsShownKey(key)
                self:SetShown(key, on)
                if onToggle then Call(self, "onToggle", onToggle, key, on) end
            end)
            lg.buttons[#lg.buttons + 1] = b
        end
    end
    f:SetSize(math.max(x, 1), 14)
    lg.width = x
    function lg:Update()
        for _, b in ipairs(self.buttons) do
            local a = self.chart:IsShownKey(b.key) and 1 or 0.35
            if b.SetAlpha then b:SetAlpha(a) end
        end
    end
    self.legend = lg
    lg:Update()
    return lg
end
