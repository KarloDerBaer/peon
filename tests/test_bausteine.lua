-- Stub-Test fuer die Kern-Bausteine ab API 7: Liste mit Bildlauf (List.lua) und Minimap-Button (Minimap.lua)
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
  function m.SetShown(s, v) s.shown = v and true or false end
  function m.SetParent(s, p) s.parent = p end
  function m.GetParent(s) return s.parent end
  function m.IsVisible(s) local f = s while f do if not f.shown then return false end f = f.parent end return true end
  function m.SetPoint(s, ...) s.points[#s.points+1] = { ... } end
  function m.ClearAllPoints(s) s.points = {} end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.CreateFontString() local f = W(); allFrames[#allFrames+1] = f; return f end
  function m.CreateTexture() return W() end
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
local function near(a, b) return math.abs(a - b) < 0.01 end

load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
check(Peon.API >= 7 and Peon.NewList and Peon.ModulePrototype.NewMinimapButton and Peon.PagePrototype.List, "API 7: Liste, Minimap-Button, page:List")

-- ===== Liste =====
local clicks = {}
local list = Peon.NewList(UIParent, {
  columns = {
    { key = "name", title = "Name", width = 120 },
    { key = "price", title = "Preis", width = 80, align = "RIGHT", format = function(v) return v and (v .. "c") or "-" end },
    { key = "qty", title = "Menge", width = 60, sortValue = function(it) return it.qty end },
  },
  rows = 5, sortKey = "name",
  onClick = function(l, item, button) clicks[#clicks+1] = item.name .. ":" .. button end,
})
check(list:GetWidth() == 4 * 2 + 16 + 260 and list:GetHeight() == 20 + 5 * 18 + 8, "Groesse aus Spalten und Zeilen")
check(list.headers[1].label.text == "Name ^" and list.headers[2].label.text == "Preis", "Spaltenkoepfe mit Sortierzeichen")
check(list.empty.shown and not list.rowFrames[1].shown, "leere Liste zeigt Hinweis")
check(list.empty.text == "Keine Einträge.", "Hinweistext aus dem Kern")

local items = {}
local names = { "Kupfererz", "Zinnerz", "Leinenstoff", "Silbererz", "Wollstoff", "Friedensblume", "Silberblatt", "Erdwurzel", "Maguskönigskraut", "Leichtes Leder", "Grobes Leder", "Nachtkriecher" }
for i, n in ipairs(names) do items[i] = { name = n, qty = 13 - i }; if i % 4 ~= 0 then items[i].price = i * 10 end end
list:SetData(items)
check(not list.empty.shown and list.rowFrames[5].shown, "Daten angezeigt")
check(list.rowFrames[1].cells[1].text == "Erdwurzel" and list.rowFrames[2].cells[1].text == "Friedensblume", "nach Name sortiert")
check(list.rowFrames[1].cells[2].text == "-" and list.rowFrames[2].cells[2].text == "60c", "Anzeige ueber format")
check(list.bar.max == 7 and list.bar.shown, "Bildlauf: 12 Eintraege, 5 sichtbar")
list:Scroll(3)
check(list.offset == 3 and list.bar.value == 3 and list.rowFrames[1].cells[1].text == "Kupfererz", "Bildlauf um 3 Zeilen")
list:Scroll(100)
check(list.offset == 7 and list.rowFrames[5].cells[1].text == "Zinnerz", "Bildlauf endet am letzten Eintrag")
list.frame.scripts.OnMouseWheel(list.frame, 1)
check(list.offset == 4, "Mausrad nach oben")
list.bar:SetValue(0)
check(list.offset == 0, "Schieberegler setzt Position")

-- Sortieren per Kopfklick
list.headers[2].scripts.OnClick()
check(list.sortKey == "price" and not list.sortDesc and list.rowFrames[1].cells[1].text == "Kupfererz", "Klick sortiert nach Preis aufsteigend")
list:Scroll(100)
check(list.rowFrames[5].cells[2].text == "-", "leere Preise stehen am Ende")
list.headers[2].scripts.OnClick()
check(list.sortDesc and list.headers[2].label.text == "Preis v", "zweiter Klick: absteigend")
check(list.view[1].name == "Grobes Leder" and list.view[#list.view].price == nil, "absteigend, leere Werte trotzdem am Ende")
list:Sort("qty", false)
check(list.view[1].name == "Nachtkriecher", "sortValue")

-- Auswahl
list:SetOffset(0)
list.rowFrames[2].scripts.OnClick(list.rowFrames[2], "LeftButton")
check(list:GetSelected() == list.view[2] and list.rowFrames[2].sel.shown and not list.rowFrames[1].sel.shown, "Klick markiert Zeile")
check(clicks[1] == list.view[2].name .. ":LeftButton", "onClick mit Eintrag und Taste")
list:Select(list.view[12])
check(list.offset == 7 and list.rowFrames[5].sel.shown, "Select blaettert zum Eintrag")
list:SetData({ { name = "neu" } })
check(list:GetSelected() == nil and list.offset == 0 and not list.bar.shown, "neue Daten: Auswahl weg, kein Bildlauf")

-- Fehler in Rueckruf/Format
local bad = Peon.NewList(UIParent, { columns = { { key = "a", format = function() error("kaputt") end } }, onClick = function() error("kaputt2") end })
bad:SetData({ { a = 1 } })
check(bad.rowFrames[1].cells[1].text == "?", "Fehler in format -> ?")
bad.rowFrames[1].scripts.OnClick(bad.rowFrames[1], "LeftButton")
bad.rowFrames[1].scripts.OnClick(bad.rowFrames[1], "LeftButton")
local n = 0 for _, l in ipairs(out) do if l:find("kaputt2") then n = n + 1 end end
check(n == 1, "Fehler in onClick einmal gemeldet")

-- ===== Modul mit Minimap-Button und page:List =====
TestMiniDB = { minimapAngle = 90 }
local got = {}
local mod = Peon:NewModule("Peon_Mini", { key = "mini", title = "Mini", db = "TestMiniDB",
  defaults = { minimapAngle = 200, minimapShow = true }, ranges = { minimapAngle = { 0, 359, 1 } } })
fire("ADDON_LOADED", "Peon_Mini")
local page = mod:NewOptionsPage({ desc = "x" })
local left = page:Column(16, -60)
local c = page:Add(left, page:List({ columns = { { key = "a", title = "A", width = 100 } }, rows = 3 }))
check(c.list and c.w == c.list:GetWidth() and c.h == c.list:GetHeight(), "page:List: Container so gross wie die Liste")

local btn = mod:NewMinimapButton({ icon = 133784, name = "PeonMiniButton",
  onClick = function(m, b) got[#got+1] = b end,
  onTooltip = function(m, t) t:AddLine("Zeile vom Modul") end, hint = "Linksklick: Test" })
check(_G.PeonMiniButton == btn and mod:NewMinimapButton() == btn, "Button angelegt, zweiter Aufruf liefert denselben")
local p = btn.points[1]
check(p[1] == "CENTER" and near(p[4], 0) and near(p[5], 80), "Position aus gespeichertem Winkel (90 Grad oben)")
check(btn.shown, "sichtbar")
btn.scripts.OnClick(btn, "RightButton")
check(got[1] == "RightButton", "Klick an Modul weitergereicht")
btn.scripts.OnEnter(btn)
check(tt.lines[1]:find("Mini") and tt.lines[2] == "Zeile vom Modul" and tt.lines[3] == "Linksklick: Test" and tt.lines[4] == "Ziehen: Button verschieben", "Tooltip: Titel, Modul-Zeilen, Hinweise")
-- Ziehen nach rechts
cursor = { 600, 400 }
btn.scripts.OnDragStart(btn)
btn.scripts.OnUpdate(btn)
btn.scripts.OnDragStop(btn)
check(TestMiniDB.minimapAngle == 0 and near(btn.points[1][4], 80), "Ziehen speichert neuen Winkel")
check(btn.scripts.OnUpdate == nil, "Ziehen beendet")
-- Ausblenden ueber Einstellung
mod.db.minimapShow = false
mod:Fire("CHANGED", "minimapShow")
check(not btn.shown, "ausgeblendet nach Einstellung")
mod:ResetDefaults()
check(btn.shown and TestMiniDB.minimapAngle == 200, "Standardwerte: wieder sichtbar, Winkel 200")

-- ===== Untertabs auf Optionsseiten (API 11) =====
check(Peon.API >= 11 and Peon.PagePrototype.Tabs and Peon.PagePrototype.SelectTab, "API 11: Untertabs")
local tm = Peon:NewModule("TestTabs", { key = "testtabs", title = "Tabs", db = "TestTabsDB", defaults = { a = true, b = false, c = 5 }, ranges = { c = { 1, 10, 1 } } })
fire("ADDON_LOADED", "TestTabs")
local tp = tm:NewOptionsPage({ desc = "x" })
tp:Tabs({ { "one", "Eins" }, { "two", "Zwei" } }, -58)
local always = tp:Column(400, -96)
local c1 = tp:Column(16, -96, "one")
local c2 = tp:Column(16, -96, "two")
local a1 = tp:Add(c1, tp:Check("a", "A"))
local a2 = tp:Add(c1, tp:Slider("c", "C"))
local b1 = tp:Add(c2, tp:Check("b", "B"))
local x1 = tp:Add(always, tp:Header("immer"))
tp:AddResetButton("hint", c1, c2)
local seen = {}
tp.onTab = function(_, key) seen[#seen + 1] = key end
tp:Register()
tp:Refresh()
check(tp:GetTab() == "one" and a1:IsVisible() and a2:IsVisible() and not b1:IsVisible() and x1:IsVisible(), "erster Reiter aktiv, Spalte ohne Reiter immer sichtbar")
local resetY1 = tp.resetButton.points[1][5]
tp.tabButtons[2].scripts.OnClick(tp.tabButtons[2])
check(tp:GetTab() == "two" and not a1:IsVisible() and b1:IsVisible() and x1:IsVisible(), "Klick auf Reiter 2 wechselt")
check(tp.resetButton.points[1][5] > resetY1, "Reset-Knopf unter der tiefsten sichtbaren Spalte (" .. resetY1 .. " -> " .. tp.resetButton.points[1][5] .. ")")
check(seen[#seen] == "two", "onTab meldet den Wechsel")
tp:SelectTab("gibtsnicht")
check(tp:GetTab() == "two", "unbekannter Reiter: nichts passiert")
a1:Hide(); tp:SelectTab("one")
check(not a1.shown and a2:IsVisible(), "eigenes Ausblenden eines Bausteins bleibt erhalten")

local e = 0 for _, l in ipairs(out) do if l:find("Fehler") and not l:find("kaputt2") and not l:find("^ok ") then e = e + 1 end end
check(e == 0, "keine weiteren Fehlermeldungen")
print("ALLE TESTS OK")
