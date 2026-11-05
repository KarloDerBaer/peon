-- Test fuer den Diagramm-Baustein (Chart.lua, ab API 10). Ausfuehren aus dem AddOns-Ordner.
-- Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
function GetTime() return 1 end
date = os.date
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
SlashCmdList = {}
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function() return true end, GetNumAddOns = function() return 1 end,
  GetAddOnInfo = function(i) return ({ "Peon" })[i] end }
local allFrames = {}
local function W()
  local o = { scripts = {}, w = 0, h = 0, shown = true, events = {}, points = {} }
  local m = {}
  function m.SetSize(s, w, h) s.w, s.h = w, h end
  function m.SetHeight(s, h) s.h = h end
  function m.SetWidth(s, w) s.w = w end
  function m.GetHeight(s) return s.h end
  function m.GetWidth(s) return s.w end
  function m.GetStringHeight() return 12 end
  function m.SetScript(s, n, f) s.scripts[n] = f end
  function m.HookScript(s, n, f) s.scripts[n] = f end
  function m.SetText(s, t) s.text = t end
  function m.SetValue(s, v) s.value = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end
  function m.SetMinMaxValues(s, a, b) s.min, s.max = a, b end
  function m.Show(s) s.shown = true end
  function m.Hide(s) s.shown = false end
  function m.IsShown(s) return s.shown end
  function m.SetPoint(s, ...) s.points[#s.points+1] = { ... } end
  function m.ClearAllPoints(s) s.points = {} end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.CreateFontString() local f = W(); allFrames[#allFrames+1] = f; return f end
  function m.CreateTexture() local t = W(); t.kind = "tex"; allFrames[#allFrames+1] = t; return t end
  function m.CreateLine() if NO_LINES then return nil end local t = W(); t.kind = "line"; allFrames[#allFrames+1] = t; return t end
  function m.SetStartPoint(s, p, r, x, y) s.sx, s.sy = x, y end
  function m.SetEndPoint(s, p, r, x, y) s.ex, s.ey = x, y end
  function m.SetVertexOffset(s, v, x, y) s.vo = s.vo or {}; s.vo[v] = y end
  function m.GetStringWidth(s) return #(s.text or "") * 5 end
  function m.SetColorTexture(s, r, g, b, a) s.color = { r, g, b, a } end
  function m.SetVertexColor(s, r, g, b, a) s.vcolor = { r, g, b, a } end
  function m.SetAlpha(s, a) s.alpha = a end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" then return function() end end end })
end
function CreateFrame(kind, name) local f = W(); f.kind = kind; allFrames[#allFrames+1] = f; if name then _G[name] = f end return f end
Settings = { RegisterCanvasLayoutCategory = function(p, n) return { name = n, subs = {}, GetID = function() return n end } end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) return { GetID = function() return n end } end,
  RegisterAddOnCategory = function() end, OpenToCategory = function() end }
Minimap = W(); Minimap.w = 140
function Minimap.GetCenter() return 500, 400 end
function Minimap.GetEffectiveScale() return 1 end
local cursor = { 500, 480 }
function GetCursorPosition() return cursor[1], cursor[2] end
local tt = { lines = {} }
GameTooltip = { SetOwner = function() tt.lines = {} end, AddLine = function(_, t) tt.lines[#tt.lines+1] = t end, Show = function() tt.shown = true end, Hide = function() tt.shown = false end }
local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end

local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end
load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
check(Peon.API >= 10 and Peon.NewChart and Peon.LinkCharts and Peon.NiceRange, "API 10: Diagramm")

-- schoene Achsengrenzen
local a, b = Peon.NiceRange(57, 93, 2)
check(a <= 57 and b >= 93 and (b - a) / 2 == math.floor((b - a) / 2), "NiceRange 57..93 -> " .. a .. ".." .. b)
a, b = Peon.NiceRange(0, 1234, 2)
check(a == 0 and b >= 1234 and b <= 2000, "NiceRange 0..1234 -> " .. b)
a, b = Peon.NiceRange(5, 5, 2)
check(a < 5 and b > 5, "NiceRange gleicher Wert")
a, b = Peon.NiceRange(0, 0, 2)
check(a == 0 and b == 1, "NiceRange 0")

local function count(ch, kind) local n = 0 for _, o in ipairs(ch.pools[kind]) do if o and o.shown then n = n + 1 end end return n end
local hovered = {}
local ch = Peon.NewChart(UIParent, { width = 300, height = 100, left = 40, right = 40, top = 5, bottom = 5,
  leftFormat = function(v) return v .. "c" end, rightFormat = function(v) return v .. " St." end,
  onHover = function(c, i) hovered[#hovered+1] = i end })
check(ch.plotW == 220 and ch.plotH == 90, "Zeichenflaeche ohne Rand")
local md = { 60, 70, nil, 80, 90 }
ch:SetData(5, {
  { key = "md", kind = "line", values = md, color = { 0, 0, 1 } },
  { key = "cost", kind = "step", values = { 50, 50, 55, 55, 55 }, color = { 1, .5, 0 } },
  { key = "zone", kind = "zone", values = { 60, 70, 75, 80, 90 }, values2 = { 66, 66, 66, 66, 66 }, color = { 0, 1, 0, .3 }, colorBelow = { 1, 0, 0, .3 } },
  { key = "st", kind = "bar", axis = "right", values = { 10, 20, 0, 40, 50 } },
  { key = "sell", kind = "points", shape = "circle", values = { nil, 75, nil, nil, 88 } },
  { key = "ev", kind = "marks", values = { [2] = true } },
  { key = "ven", kind = "hline", value = 33, hidden = true },
})
local la, lb = ch:GetRange("left")
check(la <= 50 and lb >= 90, "linke Achse umfasst Kosten und Preise (" .. la .. ".." .. lb .. ")")
local ra, rb = ch:GetRange("right")
check(ra == 0 and rb >= 50, "rechte Achse beginnt bei 0")
check(not ch:IsShownKey("ven") and ch:IsShownKey("md"), "hidden = aus")
-- Linie mit Luecke: 1-2 und 4-5 = 2 Segmente; Stufen: 4 waagerecht + 1 senkrecht = 5
check(count(ch, "line") == 2 + 5, "Linien gezeichnet: " .. count(ch, "line"))
local seg = ch.pools.line[1]
check(seg.sx == 0 and seg.ex == 55 and math.abs(seg.sy - ch:Y("left", 60)) < 0.01, "erstes Segment vom ersten zum zweiten Punkt")
-- Flaeche: Zone hat 4 Abschnitte, Abschnitt 1 (60+70 < 65+65) rot, Rest gruen
local zoneTex = {}
for _, t in ipairs(ch.pools.tex) do if t.shown and t.color and t.color[4] == .3 then zoneTex[#zoneTex+1] = t end end
check(#zoneTex == 4 and zoneTex[1].color[1] == 1 and zoneTex[2].color[2] == 1, "Gewinnzone zweifarbig")
check(zoneTex[2].vo[1] ~= nil, "Trapez ueber SetVertexOffset")
ch:SetHover(4)
check(hovered[1] == 4 and ch.hoverLine and ch.hoverLine.shown, "Mauslinie und onHover")
check(ch:IndexAt(0) == 1 and ch:IndexAt(220) == 5 and ch:IndexAt(110) == 3 and ch:IndexAt(500) == nil, "Index unter der Maus")
local before = count(ch, "line")
ch:SetShown("md", false)
check(count(ch, "line") == before - 2, "Reihe ausgeschaltet")
-- Wiederverwendung: erneutes Zeichnen erzeugt keine neuen Objekte
local nTex = #ch.pools.tex
ch:Draw(); ch:Draw()
check(#ch.pools.tex == nTex, "Objekte werden wiederverwendet")

-- Legende
local toggles = {}
local lg = ch:CreateLegend(UIParent, { "md", "cost", "zone", "nichtda" }, function(k, on) toggles[#toggles+1] = k .. tostring(on) end)
check(#lg.buttons == 3 and lg.buttons[1].alpha == 0.35 and lg.buttons[2].alpha == 1, "Legende zeigt an/aus")
lg.buttons[1].scripts.OnClick()
check(ch:IsShownKey("md") and toggles[1] == "mdtrue" and lg.buttons[1].alpha == 1, "Klick schaltet Reihe ein")

-- Verknuepfen
local ch2 = Peon.NewChart(UIParent, { width = 300, height = 80 })
ch2:SetData(5, { { key = "x", kind = "line", values = { 100, 110, 120, 130, 140 } } })
Peon.LinkCharts({ ch, ch2 }, { shareLeft = true })
ch:Draw(); ch2:Draw()
local a1, b1 = ch:GetRange("left"); local a2, b2 = ch2:GetRange("left")
check(a1 == a2 and b1 == b2 and b1 >= 140 and a1 <= 50, "gleicher Bereich links in beiden Diagrammen")
ch2:HoverAll(2)
check(ch.hover == 2 and ch2.hover == 2, "gemeinsame Mauslinie")
ch.frame.scripts.OnLeave()
check(ch.hover == nil and ch2.hover == nil, "Maus weg: beide ohne Mauslinie")

-- ohne CreateLine: Rueckfall auf Kaestchen
NO_LINES = true
local ch3 = Peon.NewChart(UIParent, { width = 200, height = 60 })
ch3:SetData(3, { { key = "a", kind = "line", values = { 1, 5, 2 }, dash = 4 } })
check(count(ch3, "tex") > 3 and count(ch3, "line") == 0, "Rueckfall ohne CreateLine")
NO_LINES = nil
-- leere Daten / Fehler
local ch4 = Peon.NewChart(UIParent, {})
ch4:SetData(0, {})
check(ch4:GetRange("left") == nil, "leeres Diagramm")
ch4:SetData(3, { { key = "a", kind = "line", values = { 1, "x", 3 } } })
check(true, "falscher Wert stoert nicht")
-- 0.11.1: ein einzelner Wert ist als Punkt sichtbar (erster Tag mit Daten)
local function dots(c)
  local n = 0
  for _, t in ipairs(c.pools.tex) do if t.shown and t.vcolor and t.vcolor[1] == 0.1 then n = n + 1 end end
  return n
end
local RED = { 0.1, 0.2, 0.3, 1 }
local ch5 = Peon.NewChart(UIParent, { width = 300, height = 100 })
ch5:SetData(5, { { key = "a", kind = "line", values = { [5] = 26 }, color = RED, connect = true } })
check(dots(ch5) == 1 and count(ch5, "line") == 0, "Linie mit einem Wert: ein Punkt")
ch5:SetData(5, { { key = "a", kind = "step", values = { [5] = 26 }, color = RED } })
check(dots(ch5) == 1, "Stufenlinie mit einem Wert: ein Punkt")
ch5:SetData(5, { { key = "a", kind = "line", values = { 1, 2, nil, 4, nil }, color = RED } })
check(dots(ch5) == 1 and count(ch5, "line") == 1, "ohne connect: nur der Wert ohne Nachbarn wird Punkt")
ch5:SetData(5, { { key = "a", kind = "line", values = { 1, nil, 3, nil, nil }, color = RED, connect = true } })
check(dots(ch5) == 0 and count(ch5, "line") == 1, "mit connect: ueberbrueckte Werte bleiben Linie")
ch5:SetData(5, { { key = "a", kind = "line", values = { 1, 2, 3, 4, 5 }, color = RED } })
check(dots(ch5) == 0, "durchgehende Linie ohne Punkte")
print("ALLE TESTS OK")
