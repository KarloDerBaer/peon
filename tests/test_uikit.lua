-- Peon-Kern: UI-Bausteine (UIKit.lua, Kern-API 18). Bis Peon 0.24.1 Teil von test_uidemo.lua, das Beispielfenster
-- liegt seit 18.11.2026 im privaten Peon_Debug. Nachgebaute Rahmen ohne Blizzards Vorlagen (Rueckfall-Wege). Prueft:
-- gemessene Masse, Fortschritt, Geld anzeigen und eingeben, Haken, Reiter mit Zahl, Hintergruende, Kategorieliste, Rueckfrage.
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
local ns = load("Peon", { "Locales.lua", "Core.lua", "Module.lua", "Options.lua", "UIKit.lua", "Slash.lua" })
PeonDB = {}
Peon.db = PeonDB
local reported = {}
Peon.ReportCoreError = function(where, err) reported[#reported + 1] = where .. ": " .. tostring(err) end
local UI = ns.UI
check(UI, "UIKit fehlt")
check(Peon.API >= 18 and Peon.UI == UI, "API 18: Peon.UI")
local toc = io.open("Peon/Peon.toc"):read("*a")
check(toc:find("Chart.lua\r?\nUIKit.lua\r?\nNotice.lua\r?\nComm.lua\r?\nProfiles.lua\r?\nSlash.lua"), "Reihenfolge in der TOC")
check(not toc:find("UIDemo") and not toc:find("UIProbe"), "Beispielfenster und UI-Pruefung nicht mehr im Kern (ab 0.25.0)")

-- 1. gemessene Masse (Pruefung im Spiel 11.11.2026)
check(UI.WINDOW_W == 800 and UI.WINDOW_H == 538, "Fenster wie das Auktionshaus")
check(UI.ROW_H == 20 and UI.HEADER_H == 19 and UI.NAV_H == 21 and UI.INPUT_H == 33, "Zeilen, Kopf, Kategorie, Eingabe")
check(UI.BG.left[1] == "auctionhouse-background-sell-left" and UI.BG.left[2] == 357 and UI.BG.left[3] == 437, "Hintergrund links")
check(UI.BG.list[2] == 595 and UI.BG.list[3] == 413, "Hintergrund Liste")

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

-- 8. Haken: gesperrt wird grau
local cb = UI.Check(UIParent, "Test", true)
check(cb.checked and cb.label.txt == "Test", "Haken an")
cb:Disable()
check(cb.label.color[1] == 0.5, "gesperrter Haken grau")
cb:Enable()
check(cb.label.color[2] == 0.82, "wieder gold")

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
