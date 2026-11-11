-- Peon-Kern: UI-Bausteine (UIKit.lua) und Beispielfenster /peon ui (UIDemo.lua), ab 0.18.0.
-- Nachgebaute Rahmen ohne Blizzards Vorlagen (Rueckfall-Wege). Prueft: Fenster und vier Seiten ohne Fehler,
-- Reiter wechseln und merken, Zahl am Reiter, Tabelle (Sortierung, leere Werte unten, Richtung, Auswahl, leer,
-- Laden), Geld anzeigen und eingeben, Kategorieliste, Masse aus der Pruefung, Toggle und Kampf.
-- Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
function GetTime() return 1 end
date, time = os.date, os.time
local combat = false
function InCombatLockdown() return combat end
function UnitAffectingCombat() return false end
function GetMoney() return 1234567 end
function hooksecurefunc(t, name, fn) local old = t[name] t[name] = function(...) local r = old and old(...) fn(...) return r end end
SlashCmdList, UISpecialFrames = {}, {}

local function fail(msg) print("FEHLER: " .. msg); os.exit(1) end
local function check(c, msg) if not c then fail(msg) end end

local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function() return true end, GetNumAddOns = function() return 1 end,
  GetAddOnInfo = function(i) return ({ "Peon" })[i] end }
C_Texture = { GetAtlasInfo = function(name) return { width = 10, height = 10 } end }

-- Rahmen-Nachbau: Zustand fuer Groesse, Text, Sichtbarkeit, Skripte, Haken, Werte; alles andere tut nichts
local created = {}
local function W(kind)
  local o = { kind = kind, scripts = {}, w = 0, h = 0, shown = true, txt = "", checked = false, enabled = true, points = {} }
  local m = {}
  function m.SetSize(s, w, h) s.w, s.h = w, h end
  function m.SetWidth(s, w) s.w = w end
  function m.SetHeight(s, h) s.h = h end
  function m.GetWidth(s) return s.w end
  function m.GetHeight(s) return s.h end
  function m.GetStringWidth(s) return #(s.txt or "") * 6 end
  function m.SetText(s, t) s.txt = t end
  function m.GetText(s) return s.txt end
  function m.Show(s) s.shown = true end
  function m.Hide(s) s.shown = false end
  function m.IsShown(s) return s.shown end
  function m.SetShown(s, v) s.shown = v and true or false end
  function m.SetScript(s, n, f) s.scripts[n] = f end
  function m.GetScript(s, n) return s.scripts[n] end
  function m.HookScript(s, n, f) local old = s.scripts[n] s.scripts[n] = function(...) if old then old(...) end f(...) end end
  function m.SetChecked(s, v) s.checked = v end
  function m.GetChecked(s) return s.checked end
  function m.Disable(s) s.enabled = false end
  function m.Enable(s) s.enabled = true end
  function m.IsEnabled(s) return s.enabled end
  function m.SetPoint(s, ...) s.points[#s.points + 1] = { ... } end
  function m.ClearAllPoints(s) s.points = {} end
  function m.GetFrameLevel() return 1 end
  function m.SetTextColor(s, r, g, b) s.color = { r, g, b } end
  function m.SetVertexColor(s, r, g, b) s.vcolor = { r, g, b } end
  function m.SetAtlas(s, a) s.atlas = a end
  function m.SetTexture(s, f) s.file = f end
  function m.SetTexCoord(s, ...) s.tc = { ... } end
  function m.GetPoint(s, i) local p = s.points[i or 1] if p then return unpack(p) end end
  function m.SetMinMaxValues(s, a, b) s.min, s.max = a, b end
  function m.SetValue(s, v) s.value = v end
  function m.GetValue(s) return s.value end
  function m.CreateFontString() local f = W("FontString") return f end
  function m.CreateTexture() return W("Texture") end
  function m.CreateMaskTexture() return W("MaskTexture") end
  return setmetatable(o, { __index = function(_, k)
    if m[k] then return m[k] end
    if type(k) == "string" and k:match("^%u") and k ~= "Text" and k ~= "Bg" and k ~= "NineSlice" and k ~= "Icon" and k ~= "Low" and k ~= "High" then return function() end end
  end })
end
UIParent = W("Frame")
GameTooltip = W("GameTooltip")
function CreateFrame(kind, name, parent, tmpl)
  -- Blizzards Vorlagen fehlen im Nachbau: wie im Spiel ein Fehler, der Rueckfall muss greifen
  if tmpl and tmpl ~= "UIPanelButtonTemplate" and tmpl ~= "InputBoxTemplate" then error("Couldn't find inherited node \"" .. tmpl .. "\"") end
  local f = W(kind)
  f.name, f.parent, f.tmpl = name, parent, tmpl
  if kind == "Button" then
    -- Knopf mit eigener Schrift wie UIPanelButtonTemplate
    local fs = W("FontString")
    f.GetFontString = function() return fs end
    f.SetText = function(s, t) s.txt = t; fs.txt = t end
  end
  if name then _G[name] = f end
  created[#created + 1] = f
  return f
end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }

local function load(dir, files)
  local ns = {}
  for _, f in ipairs(files) do
    local chunk, err = loadfile(dir .. "/" .. f)
    if not chunk then fail(err) end
    chunk(dir, ns)
  end
  return ns
end
local ns = load("Peon", { "Locales.lua", "Core.lua", "Module.lua", "Options.lua", "UIKit.lua", "UIDemo.lua", "UIProbe.lua", "Slash.lua" })
PeonDB = {}
Peon.db = PeonDB
local reported = {}
Peon.ReportCoreError = function(where, err) reported[#reported + 1] = where .. ": " .. tostring(err) end
local UI, D = ns.UI, ns.UIDemo
check(UI and D, "UIKit oder UIDemo fehlt")
check(Peon.API >= 18 and Peon.UI == UI, "API 18: Peon.UI")
local toc = io.open("Peon/Peon.toc"):read("*a")
check(toc:find("Chart.lua\r?\nUIKit.lua\r?\nUIDemo.lua\r?\nUIProbe.lua\r?\nSlash.lua"), "Reihenfolge in der TOC")

-- 1. gemessene Masse (Pruefung im Spiel 11.11.2026)
check(UI.WINDOW_W == 800 and UI.WINDOW_H == 538, "Fenster wie das Auktionshaus")
check(UI.ROW_H == 20 and UI.HEADER_H == 19 and UI.NAV_H == 21 and UI.INPUT_H == 33, "Zeilen, Kopf, Kategorie, Eingabe")
check(UI.BG.left[1] == "auctionhouse-background-sell-left" and UI.BG.left[2] == 357 and UI.BG.left[3] == 437, "Hintergrund links")
check(UI.BG.list[2] == 595 and UI.BG.list[3] == 413, "Hintergrund Liste")

-- 2. Fenster ueber /peon ui: vier Seiten, keine Fehler, ESC
SlashCmdList.PEON("ui")
local win = D.win
check(win and win.shown, "Fenster offen")
check(#reported == 0, "Fehler beim Aufbau: " .. table.concat(reported, " | "))
check(win.w == 800 and win.h == 538, "Fenstergroesse")
local esc = false
for _, n in ipairs(UISpecialFrames) do if n == "PeonUIDemoFrame" then esc = true end end
check(esc, "ESC schliesst das Fenster")
for _, p in ipairs(D.PAGES) do check(D.pages[p[1]], "Seite " .. p[1]) end
check(D.pages.basics.shown and not D.pages.lists.shown, "erste Seite sichtbar")

-- 3. Reiter wechseln, merken, Zahl am Reiter
D.tabs:Select("lists")
check(D.pages.lists.shown and not D.pages.basics.shown, "Reiter Listen")
check(PeonDB.uiDemoTab == "lists", "Reiter gemerkt")
check(D.tabs[3].badge.shown and D.tabs[3].badge.text.txt == "3", "Zahl am Reiter")
D.tabs[3]:SetBadge(0)
check(not D.tabs[3].badge.shown, "Zahl 0 ausgeblendet")
D.tabs[3]:SetBadge(150)
check(D.tabs[3].badge.text.txt == "99+", "grosse Zahl gekuerzt")
SlashCmdList.PEON("ui")
check(not win.shown, "zweites /peon ui schliesst")
combat = true
out = {}
SlashCmdList.PEON("ui")
check(not win.shown and out[1] and out[1]:find("Kampf"), "im Kampf nicht")
combat = false

-- 4. Tabelle: Sortierung, leere Werte unten, Richtung, Auswahl
local t = D.listTable
check(#t.items == 40, "40 Testzeilen")
check(t.sortKey == "price", "Sortierung nach Preis")
for i = 2, #t.items do check(t.items[i - 1].price <= t.items[i].price, "aufsteigend nach Preis") end
t.sortKey, t.sortDesc = "level", false
t:Sort()
check(t.items[#t.items].level == nil, "leerer Wert unten (aufsteigend)")
t.sortDesc = true
t:Sort()
check(t.items[#t.items].level == nil, "leerer Wert unten (absteigend)")
check(t.items[1].level >= t.items[2].level, "absteigend")
-- Klick auf Kopf: gleiche Spalte dreht die Richtung, andere Spalte beginnt aufsteigend
t.heads[1].scripts.OnClick()
check(t.sortKey == "name" and not t.sortDesc, "Kopf Name aufsteigend")
check(t.items[1].name:lower() <= t.items[2].name:lower(), "Namen sortiert")
t.heads[1].scripts.OnClick()
check(t.sortDesc, "zweiter Klick dreht")
-- Auswahl ueber Zeile
local row = t.list.rows[2]
row.scripts.OnClick(row, "LeftButton")
check(t:GetSelected() == row.data and row.sel.shown, "Zeile ausgewaehlt")
check(D.status.text.txt:find(row.data.name, 1, true), "Statuszeile nennt Auswahl")
-- Zeilen gefuellt: Streifen, Symbol, Preis
check(row.cells[1].txt == row.data.name and row.icon, "Zelle Name mit Symbol")
check(row.cells[4].txt ~= "", "Preis-Zelle")

-- 5. leer und laden
t:SetData({})
check(t.empty.shown and #t.items == 0 and t:GetSelected() == nil, "leere Liste mit Hinweis, Auswahl weg")
t:SetLoading(true, "Suche...")
check(t.spinner.shown and not t.empty.shown and not t.list.box.shown, "Ladeanzeige")
t:SetLoading(false)
check(t.empty.shown and t.list.box.shown, "wieder leer")

-- 6. Seite Aufbau: Kategorie waehlt, Suche laeuft mit Ladeanzeige
D.tabs:Select("layout")
check(D.pages.layout.shown, "Seite Aufbau")
-- sichtbare Kategorie-Knoepfe (Rueckfall-Liste: sichtbare Zeilen der Kategorieliste)
local function CatRow(key)
  for _, f in ipairs(created) do if f.shown and f.data and f.data.key == key and f.data.level then return f end end
end
local function CatShown(key) return CatRow(key) ~= nil end
check(CatShown("Waffen") and CatShown("Handwerkswaren"), "oberste Stufe sichtbar")
check(not CatShown("Handwerkswaren/Stoff") and not CatShown("Waffen/Einhandschwerter"), "Unterpunkte zu")
local hw = CatRow("Handwerkswaren")
hw.scripts.OnClick(hw, "LeftButton")
check(CatShown("Handwerkswaren/Stoff") and CatShown("Handwerkswaren/Metall und Stein"), "Handwerkswaren aufgeklappt")
check(not CatShown("Handwerkswaren/Metall und Stein/Erz"), "dritte Stufe noch zu")
check(not CatShown("Waffen/Einhandschwerter"), "andere Kategorie bleibt zu")
local catRow = CatRow("Handwerkswaren/Metall und Stein")
catRow.scripts.OnClick(catRow, "LeftButton")
check(CatShown("Handwerkswaren/Metall und Stein/Erz") and CatShown("Handwerkswaren/Stoff"), "dritte Stufe offen, Geschwister bleiben")
catRow = CatRow("Handwerkswaren/Metall und Stein")
check(#timers > 0, "Suche wartet kurz (Ladeanzeige)")
timers[#timers]()
check(D.status.text.txt:find("Ergebnisse in Handwerkswaren/Metall und Stein", 1, true), "Ergebnisse gefiltert: " .. D.status.text.txt)
local n = tonumber(D.status.text.txt:match("^(%d+)"))
check(n and n > 0, "Treffer vorhanden")
check(catRow.sel.shown, "Kategorie markiert")
-- erneuter Klick klappt zu und waehlt die Eltern-Kategorie
catRow.scripts.OnClick(catRow, "LeftButton")
timers[#timers]()
check(not CatShown("Handwerkswaren/Metall und Stein/Erz") and CatShown("Handwerkswaren/Stoff"), "zugeklappt, Eltern offen")
check(D.status.text.txt:find("in Handwerkswaren$"), "Eltern gewaehlt: " .. D.status.text.txt)
hw = CatRow("Handwerkswaren")
hw.scripts.OnClick(hw, "LeftButton")
timers[#timers]()
check(not CatShown("Handwerkswaren/Stoff") and D.status.text.txt:find("^60 Ergebnisse$"), "alles zu, alle Ergebnisse: " .. D.status.text.txt)

-- 6b. Fortschritt wie der Balken beim Herstellen
local pb = UI.Progress(UIParent, 208)
check(pb.w == 208 and pb.h == 11, "Balken 208x11")
pb:Set(0.5, "Scan 50 %")
check(pb.value == 0.5 and pb.text.txt == "Scan 50 %", "Balken halb")
pb:Set(2)
check(pb.value == 1 and pb.isFull and not pb.spark.shown, "voll ohne Funke")

-- 7. Geld anzeigen und eingeben
local m = UI.Money(UIParent)
m:SetAmount(12345678)
check(m.gold.text.txt == "1234" and m.silver.text.txt == "56" and m.copper.text.txt == "78", "Geld 1234g 56s 78c")
m:SetAmount(5)
check(not m.gold.shown and not m.silver.shown and m.copper.shown, "nur Kupfer")
m:SetAmount(30000)
check(m.gold.shown and m.silver.shown and m.silver.text.txt == "0" and m.copper.text.txt == "0", "Silber und Kupfer als 0")
m:SetAmount(3e10)
check(m.gold.text.txt == "3000000", "grosser Betrag ohne Ueberlauf")
local mi = UI.MoneyInput(UIParent)
mi:SetAmount(123456)
check(mi.gold.txt == "12" and mi.silver.txt == "34" and mi.copper.txt == "56", "Geld eingeben setzen")
check(mi:GetAmount() == 123456, "Geld eingeben lesen")
mi.gold:SetText("")
check(mi:GetAmount() == 3456, "leeres Gold = 0")
check(D.MoneyText(12345) == "1g 23s 45c", "Geld als Text ohne Blizzard: " .. D.MoneyText(12345))

-- 8. Haken: gesperrt wird grau
local cb = UI.Check(UIParent, "Test", true)
check(cb.checked and cb.label.txt == "Test", "Haken an")
cb:Disable()
check(cb.label.color[1] == 0.5, "gesperrter Haken grau")
cb:Enable()
check(cb.label.color[2] == 0.82, "wieder gold")

-- 9. Testdaten
local items = D.Items(40)
check(#items == 40 and items[5].level == nil, "Testdaten mit leerem Wert")
local q = {}
for _, it in ipairs(items) do q[it.quality] = true end
check(q[1] and q[2] and q[3], "mehrere Qualitaeten")

-- 10. Reiter: Breite aus Text + 40, mit Zahl breiter, Abstand 3, Zahl im Reiter
local tabs = UI.BottomTabs(UIParent, { { "a", "Markt" }, { "b", "Verkaufen" } })
local fsA = tabs[1].Text or tabs[1]:GetFontString()
check(tabs[1].w == 5 * 6 + 40, "Reiter Breite Text + 40: " .. tostring(tabs[1].w))
local p2 = tabs[2].points[#tabs[2].points]
check(p2[1] == "LEFT" and p2[3] == "RIGHT" and p2[4] == 3, "Abstand der Reiter")
tabs[2]:SetBadge(4)
check(tabs[2].w == 9 * 6 + 40 + 16 + 4, "Reiter mit Zahl breiter: " .. tostring(tabs[2].w))
local bp = tabs[2].badge.points[1]
check(bp[1] == "LEFT" and bp[3] == "RIGHT", "Zahl rechts neben dem Text")
tabs[2]:SetBadge(0)
check(tabs[2].w == 9 * 6 + 40, "ohne Zahl wieder schmal")

-- 11. Hintergrund: kleiner Bereich schneidet ab, grosser dehnt, nie ueber den Rand
C_Texture.GetAtlasInfo = function() return { file = 3054898, width = 138, height = 433, leftTexCoord = 0.4, rightTexCoord = 0.6, topTexCoord = 0.2, bottomTexCoord = 0.8 } end
local pn = UI.Panel(UIParent, "summary")
pn:SetSize(386, 66)
pn.FitBackground()
check(pn.Background.file == 3054898, "Datei des Atlas")
check(pn.Background.w == 380 and pn.Background.h == 60, "Hintergrund so gross wie der Bereich innen")
local tc = pn.Background.tc
check(math.abs(tc[2] - 0.6) < 1e-9, "breiter Bereich: ganze Breite, gedehnt")
check(math.abs(tc[4] - (0.2 + 0.6 * 60 / 433)) < 1e-9, "flacher Bereich: abgeschnitten statt ueber den Rand")
local pl = UI.Panel(UIParent, "list", true)
pl:SetSize(400, 300)
pl.FitBackground()
check(pl.Background.w == 400 - 3 - 25 and pl.Background.h == 300 - 22 - 3, "Liste: Platz fuer Kopf und Leiste")

-- 11b. Kategorien: Hintergrund endet vor der Bildlaufleiste (138 von 168 wie bei Blizzard)
local pc = UI.Panel(UIParent, "categories")
pc:SetSize(168, 438)
UI.CategoryList(pc, { { key = "A", text = "A", level = 1 } })
check(pc.Background.w == 138, "Kategorien: Hintergrund 138 breit, hinter der Leiste das Fenster: " .. tostring(pc.Background.w))

-- 12. Rueckfrage: festes kleines Fenster, Inhalt ueber dem Rahmen
local dlg = UI.Confirm("Frage?", "Ja", "Nein", function() end)
check(dlg.w == 320 and dlg.h == 110 and dlg.parent == UIParent, "Rueckfrage 320x110")
check(dlg.text.txt == "Frage?" and dlg.yes.txt == "Ja" and dlg.no.txt == "Nein", "Texte der Rueckfrage")
dlg.yes.scripts.OnClick()
check(not dlg.shown, "Ja schliesst")

print("ALLE TESTS OK")
