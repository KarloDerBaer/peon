-- Peon_Feedback gegen den ECHTEN Kern (Peon mit Feedback.lua, API 9).
-- Ergaenzt test_feedback.lua (dort kleiner Kern-Nachbau und Rueckfall-Auswahlliste):
-- hier echter Kern, echte Liste, echter Minimap-Button, echte Optionsseite, Slash ueber /peon,
-- neue Menue-API (nachgebaut) und die Bereichs-Zeilen aus den echten Moduldateien.
-- Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
function GetTime() return 1 end
date, time = os.date, os.time
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
function UnitName() return "Talia", "Sylan" end
function GetRealmName() return "Classic Beta PvE" end
function UnitFactionGroup() return "Alliance" end
function GetRealZoneText() return "Dun Morogh" end
function tinsert(t, v) table.insert(t, v) end
UISpecialFrames, SlashCmdList, ChatFontNormal = {}, {}, {}

local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local addons = { "Peon", "Peon_Broker", "Peon_ComboPoints", "Peon_Feedback", "Peon_Fishing", "Peon_Tooltip", "BagBrother" }
local meta = {}
for _, a in ipairs(addons) do meta[a] = TocMeta(a) end
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function(a) return a ~= "BagBrother" end, GetNumAddOns = function() return #addons end,
  GetAddOnInfo = function(i) return addons[i] end }

local allFrames = {}
local function W()
  local o = { scripts = {}, w = 0, h = 0, shown = true, events = {}, points = {}, txt = "" }
  local m = {}
  function m.SetSize(s, w, h) s.w, s.h = w, h end
  function m.SetHeight(s, h) s.h = h end
  function m.SetWidth(s, w) s.w = w end
  function m.GetHeight(s) return s.h end
  function m.GetWidth(s) return s.w end
  function m.GetStringHeight() return 12 end
  function m.SetScript(s, n, f) s.scripts[n] = f end
  function m.GetScript(s, n) return s.scripts[n] end
  function m.HookScript(s, n, f) s.scripts[n] = f end
  function m.SetText(s, t) s.txt = t end
  function m.GetText(s) return s.txt end
  function m.SetValue(s, v) s.value = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end
  function m.GetValue(s) return s.value or 0 end
  function m.SetMinMaxValues(s, a, b) s.min, s.max = a, b end
  function m.Show(s) local was = s.shown; s.shown = true; if not was and s.scripts.OnShow then s.scripts.OnShow(s) end end
  function m.Hide(s) s.shown = false end
  function m.IsShown(s) return s.shown end
  function m.SetShown(s, v) if v then s:Show() else s:Hide() end end
  function m.GetPoint(s) return "TOPLEFT", nil, "TOPLEFT", 100, -50 end
  function m.SetPoint(s, ...) s.points[#s.points+1] = { ... } end
  function m.ClearAllPoints(s) s.points = {} end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.CreateFontString() local f = W(); allFrames[#allFrames+1] = f; return f end
  function m.CreateTexture() return W() end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" then return function() end end end })
end
local menuFrames = {}
function CreateFrame(kind, name, parent, tmpl)
  local f = W(); f.kind, f.tmpl = kind, tmpl; allFrames[#allFrames+1] = f
  if kind == "Frame" and name == "PeonFeedbackFrame" then f.shown = false end
  if kind == "DropdownButton" then
    -- neue Menue-API nachgebaut: SetupMenu merkt den Aufbau, GenerateMenu baut ihn
    function f.SetupMenu(s, gen) s.gen = gen; s:GenerateMenu() end
    function f.GenerateMenu(s)
      s.radios = {}
      local root = { CreateRadio = function(_, text, isSel, onSel) s.radios[#s.radios+1] = { text = text, isSel = isSel, onSel = onSel } end }
      s.gen(s, root)
      for _, r in ipairs(s.radios) do if r.isSel() then s.txt = r.text end end
    end
    menuFrames[#menuFrames+1] = f
  end
  if name then _G[name] = f end
  return f
end
local opened = {}
Settings = { RegisterCanvasLayoutCategory = function(p, n) return { name = n, GetID = function() return n end } end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) return { GetID = function() return n end } end,
  RegisterAddOnCategory = function() end, OpenToCategory = function(id) opened[#opened+1] = id end }
UIParent = W()
Minimap = W(); Minimap.w = 140
function Minimap.GetCenter() return 500, 400 end
function Minimap.GetEffectiveScale() return 1 end
function GetCursorPosition() return 500, 480 end
local tt = { lines = {} }
GameTooltip = { SetOwner = function() tt.lines = {} end, AddLine = function(_, t) tt.lines[#tt.lines+1] = t end,
  AddDoubleLine = function(_, a, b) tt.lines[#tt.lines+1] = a .. "=" .. b end,
  Show = function() tt.shown = true end, Hide = function() tt.shown = false end }

local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(dir, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end

-- ===== Echter Kern =====
load("Peon")
fire("ADDON_LOADED", "Peon")
check(Peon.API >= 9 and Peon.version == meta.Peon.Version, "echter Kern: API " .. Peon.API .. ", Version " .. Peon.version)
check(type(Peon.SetFeedbackAreas) == "function" and type(Peon.GetFeedbackAreas) == "function", "Set/GetFeedbackAreas vorhanden")
check(#Peon.GetFeedbackAreas("Peon") == 7 and Peon.GetFeedbackAreas("Peon")[1] == "Einstellungsseite", "Kern meldet eigene Bereiche")
check(Peon.NewList and Peon.ModulePrototype.NewMinimapButton and Peon.PagePrototype.Dropdown, "bestehende Bausteine unveraendert da")

-- Bereichs-Zeilen aus den echten Moduldateien ausfuehren
local files = { Peon_Broker = "Broker.lua", Peon_Tooltip = "Tooltip.lua", Peon_Fishing = "Fishing.lua", Peon_ComboPoints = "ComboPoints.lua" }
local expect = { Peon_Broker = 12, Peon_Tooltip = 8, Peon_Fishing = 9, Peon_ComboPoints = 3 }
for addon, file in pairs(files) do
  local line
  for l in io.lines(addon .. "/" .. file) do if l:match("^if Peon%.SetFeedbackAreas then") then line = l end end
  check(line ~= nil, addon .. ": Bereichs-Zeile vorhanden")
  assert(loadstring("local ADDON_NAME = ...\n" .. line))(addon)
  check(#Peon.GetFeedbackAreas(addon) == expect[addon], addon .. ": " .. expect[addon] .. " Bereiche gemeldet")
end
check(Peon.GetFeedbackAreas("Peon_Broker")[6] == "Radar" and Peon.GetFeedbackAreas("Peon_Fishing")[4] == "Schwimmer-Erkennung", "Bereiche in der richtigen Reihenfolge")
-- Zeile mit altem Kern (ohne API 9) ist harmlos
do
  local save = Peon.SetFeedbackAreas; Peon.SetFeedbackAreas = nil
  local line
  for l in io.lines("Peon_Broker/Broker.lua") do if l:match("^if Peon%.SetFeedbackAreas then") then line = l end end
  check(pcall(assert(loadstring("local ADDON_NAME = ...\n" .. line)), "Peon_Broker"), "Bereichs-Zeile laeuft auch mit altem Kern")
  Peon.SetFeedbackAreas = save
end

-- ===== Peon_Feedback mit echtem Modul-Unterbau =====
PeonFeedbackDB = nil
local ns = load("Peon_Feedback")
local mod = ns.mod
check(mod and Peon:GetModule("feedback") == mod, "Modul beim echten Kern angemeldet")
fire("ADDON_LOADED", "Peon_Feedback")
check(mod.initialized and PeonFeedbackDB and mod.db == PeonFeedbackDB, "SavedVariables angelegt")
check(type(PeonFeedbackDB.entries) == "table" and PeonFeedbackDB.nextId == 1 and PeonFeedbackDB.minimapShow == true and PeonFeedbackDB.minimapAngle == 200, "Standardwerte")
check(mod.page and mod.panel and _G.PeonFeedbackMinimapButton, "Optionsseite (echt) und Minimap-Button (echt)")
fire("PLAYER_LOGIN")

-- Module-Liste mit echten TOC-Titeln
local mods = ns.Modules()
check(#mods == 6 and mods[1][1] == "Peon" and mods[1][2] == "Peon (Kern)", "Module: Kern zuerst, fremde Addons weg")
local titles = {} for i = 2, #mods do titles[#titles+1] = mods[i][2] end
check(table.concat(titles, ",") == "Broker,ComboPoints,Feedback,Fishing,Tooltip", "Titel aus den echten TOCs: " .. table.concat(titles, ","))
check(#ns.Areas("Peon_Broker") == 13 and ns.Areas("Peon_Broker")[13][1] == "Sonstiges", "Broker: 12 Bereiche + Sonstiges (ab 0.24 mit Start und Berufe, ohne Händler)")
check(#ns.Areas("Peon_Feedback") == 1, "Feedback selbst: nur Sonstiges")

-- Fenster mit neuer Menue-API
ns.Toggle()
local f = ns.GetFrame()
check(f and f.shown and UISpecialFrames[#UISpecialFrames] == "PeonFeedbackFrame", "Fenster offen, Escape angemeldet")
local dd = ns.GetDropdowns()
check(dd.module.kind == "DropdownButton" and dd.module.gen, "neue Menue-API genutzt")
local sel = ns.GetSelection()
check(sel.module == "Peon" and sel.area == "Einstellungsseite" and dd.module.txt == "Peon (Kern)", "Startauswahl angezeigt")
check(#dd.module.radios == 6 and #dd.kind.radios == 4 and #dd.prio.radios == 3, "Eintraege der Auswahllisten")
dd.module.radios[2].onSel()
check(sel.module == "Peon_Broker" and sel.area == "Start" and #dd.area.radios == 13 and dd.area.txt == "Start", "Modulwechsel: Bereiche des Moduls")
dd.area.radios[6].onSel(); dd.prio.radios[3].onSel(); dd.kind.radios[1].onSel()
check(sel.area == "Radar" and sel.prio == "high" and sel.kind == "bug" and dd.area.txt == "Radar", "Bereich/Prioritaet/Art gewaehlt")

-- Speichern, Liste (echt)
ns.GetEditBox():SetText("  Radar piept doppelt  ")
ns.Save()
local e = PeonFeedbackDB.entries[1]
check(e and e.id == 1 and e.module == "Peon_Broker" and e.area == "Radar" and e.prio == "high" and e.kind == "bug", "Eintrag gespeichert")
check(e.ver == meta.Peon_Broker.Version and e.char == "Talia Sylan" and e.market == "Classic Beta PvE / Alliance", "Version des Moduls (" .. e.ver .. "), Charakter, Markt")
local list = ns.GetList()
check(#list.data == 1 and list.o.sortKey == "t" and list.o.sortDesc, "echte Liste: Eintrag, neueste zuerst")
local w = 0 for _, c in ipairs(list.o.columns) do w = w + c.width end
check(list:GetWidth() <= 620 - 32, "Liste passt ins Fenster (" .. list:GetWidth() .. ")")
ns.GetEditBox():SetText("Zweiter"); ns.Save()
check(#list.data == 2 and PeonFeedbackDB.nextId == 3, "zweiter Eintrag")
list:Select(PeonFeedbackDB.entries[1]); ns.DeleteSelected()
check(#PeonFeedbackDB.entries == 1 and PeonFeedbackDB.entries[1].id == 2, "gewaehlten Eintrag geloescht (echte Auswahl)")

-- Zeilen-Tooltip ueber die echte Liste
local row = list.rowFrames[1]
check(row.item and row.item.id == 2, "Zeile zeigt Eintrag")
row.scripts.OnEnter(row)
check(tt.shown and tt.lines[3] == "Zweiter", "Tooltip beim Ueberfahren")

-- Standardwerte: Eintraege und Auswahl bleiben
PeonFeedbackDB.minimapShow = false
mod:ResetDefaults()
check(PeonFeedbackDB.minimapShow == true and #PeonFeedbackDB.entries == 1 and PeonFeedbackDB.last.module == "Peon_Broker", "Reset behaelt Eintraege und Auswahl")

-- Slash ueber den echten Kern
f:Hide()
SlashCmdList.PEON("feedback")
check(f.shown, "/peon feedback oeffnet das Fenster")
SlashCmdList.PEON_FEEDBACK("")
check(not f.shown, "/feedback schaltet das Fenster")
local n = #opened
SlashCmdList.PEON_FEEDBACK("optionen")
check(#opened == n + 1, "/feedback optionen oeffnet die Optionsseite")

-- Minimap-Button (echt)
local btn = _G.PeonFeedbackMinimapButton
btn.scripts.OnClick(btn, "LeftButton")
check(f.shown, "Minimap Linksklick oeffnet Fenster")
btn.scripts.OnClick(btn, "RightButton")
check(#opened == n + 2, "Minimap Rechtsklick oeffnet Optionen")

-- Uebergabe an den Manager (ab 0.3.0)
do
  PeonFeedbackDB.entries = { { id = 1, t = 100, text = "alt" }, { id = 2, t = 100, edited = 300, text = "spaeter geaendert" }, { id = 3, t = 400, text = "neu" } }
  PeonBridgeData = nil
  check(ns.ApplyManagerMark() == 0 and #PeonFeedbackDB.entries == 3, "ohne Data.lua bleibt alles")
  PeonBridgeData = { fmt = 2, feedbackClearBefore = 200 }
  check(ns.ApplyManagerMark() == 1 and #PeonFeedbackDB.entries == 2 and PeonFeedbackDB.entries[1].id == 2, "Marke loescht, was der Manager hat, Geaendertes bleibt")
  PeonBridgeData = nil
  local reloaded = false
  ReloadUI = function() reloaded = true end
  ns.Show()
  ns.sendButton.scripts.OnClick(ns.sendButton)
  check(reloaded, "Knopf An Manager laedt neu")
end

print("ALLE TESTS OK")
