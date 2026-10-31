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
-- Metadaten (Version, Titel) direkt aus der TOC-Datei lesen, damit der Test immer die echte Version zeigt
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_ComboPoints = TocMeta("Peon_ComboPoints") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function() return true end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_ComboPoints" })[i] end }
Enum = { PowerType = { ComboPoints = 4 } }
local allFrames = {}
local function W()
  local o = { scripts = {}, w = 0, h = 0, shown = true, events = {}, unitev = {}, points = {} }
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
  function m.SetChecked(s, v) s.checked = v end
  function m.GetChecked(s) return s.checked end
  function m.SetValue(s, v) s.value = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end
  function m.IsShown(s) return s.shown end
  function m.SetAlpha(s, a) s.alpha = a end
  function m.SetColorTexture(s, ...) s.color = { ... } end
  function m.SetStatusBarColor(s, ...) s.color = { ... } end
  function m.SetPoint(s, ...) s.points[#s.points+1] = { ... } end
  function m.ClearAllPoints(s) s.points = {} end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.RegisterUnitEvent(s, e) s.unitev[e] = true end
  function m.UnregisterAllEvents(s) s.events = {}; s.unitev = {} end
  function m.GetThumbTexture() return true end
  function m.CreateFontString() return W() end
  function m.CreateTexture() return W() end
  function m.CreateMaskTexture() return W() end
  function m.GetStatusBarTexture() return W() end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" then return function() end end end })
end
function CreateFrame(kind) local f = W(); f.kind = kind; allFrames[#allFrames+1] = f; return f end
local cats = {}
Settings = { RegisterCanvasLayoutCategory = function(p, n) local c = { name = n, subs = {}, GetID = function() return n end } cats[n] = c return c end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) table.insert(par.subs, n) return { GetID = function() return par.name .. "/" .. n end } end,
  RegisterAddOnCategory = function(c) c.registered = true end,
  OpenToCategory = function(id) print("OPEN " .. id) end }
-- Farbwaehler (neue API)
local pickerInfo
ColorPickerFrame = { SetupColorPickerAndShow = function(self, info) pickerInfo = info end,
  GetColorRGB = function() return 0.1, 0.2, 0.3 end, GetColorAlpha = function() return 0.5 end }
local CLASS = "WARRIOR"
function UnitClass() return "x", CLASS end
function UnitPowerMax() return 5 end
local timers = 0
C_Timer = { After = function(_, fn) timers = timers + 1 end }
local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end

load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
PeonComboPointsDB = { debug = false, size = 99, fillColor = { 2, 0, 0 } }
local ns = load("Peon_ComboPoints", "Peon_ComboPoints")
fire("ADDON_LOADED", "Peon_ComboPoints")
local mod = ns.mod
check(mod.initialized and mod.page, "Modul + Optionsseite")
check(PeonComboPointsDB.size == 32, "Groesse geklemmt")
check(PeonComboPointsDB.fillColor[1] == 1.00 and PeonComboPointsDB.fillColor[2] == 0.24, "ungueltige Farbe -> Standard")
check(PeonComboPointsDB.socketColor[4] == 0.70 and PeonComboPointsDB.socketColor ~= mod.opts.defaults.socketColor, "Farben kopiert")
fire("PLAYER_LOGIN")
check(cats.Peon.subs[1] == "ComboPoints", "Seite unter Peon > ComboPoints")
check(next(allFrames[1].events) ~= nil, "Kern-Rahmen aktiv")

-- Vorschau
mod.panel.scripts.OnShow()
local pips = {}
for _, f in ipairs(allFrames) do if f.kind == "StatusBar" then pips[#pips+1] = f end end
check(#pips == 5, "Vorschau: 5 Punkte")
check(pips[1].w == 32, "Vorschau nutzt Groesse")
-- Regler Groesse aendern
local slider
for _, f in ipairs(allFrames) do if f.kind == "Slider" and f.value == 32 then slider = f end end
slider:SetValue(20)
check(PeonComboPointsDB.size == 20 and pips[1].w == 20, "Regler -> Vorschau aktualisiert")
check(pips[2].points[1][4] == 24, "Abstand in Vorschau (20+4)")
check(timers == 0, "Nicht-Schurke: keine Nameplate-Aktualisierung")
-- Haekchen leere Punkte
local cb
for _, f in ipairs(allFrames) do if f.kind == "CheckButton" then cb = f end end
cb.checked = false; cb.scripts.OnClick(cb)
check(PeonComboPointsDB.showSockets == false and pips[1].socket.alpha == 0, "Leere Punkte aus")
-- Farbwaehler
local colorBtn
for _, f in ipairs(allFrames) do if f.kind == "Button" and f.scripts.OnClick and not f.label then colorBtn = colorBtn or f end end
colorBtn.scripts.OnClick(colorBtn)
check(pickerInfo and pickerInfo.r == 1.00 and pickerInfo.hasOpacity == false, "Farbwaehler geoeffnet (Fuellung)")
pickerInfo.swatchFunc()
check(PeonComboPointsDB.fillColor[1] == 0.1 and pips[1].color[1] == 0.1, "Farbe uebernommen + Vorschau")
pickerInfo.cancelFunc()
check(PeonComboPointsDB.fillColor[1] == 1.00, "Abbrechen stellt Farbe wieder her")
-- Reset
SlashCmdList.PEON("combopoints")
check(out[#out] == "OPEN Peon/ComboPoints", "/peon combopoints oeffnet Seite")
mod:ResetDefaults()
check(PeonComboPointsDB.size == 15 and PeonComboPointsDB.showSockets == true and pips[1].w == 15, "Reset + Vorschau")
-- Schurke: Aenderung zeichnet neu
CLASS = "ROGUE"
local cpFrame
for _, f in ipairs(allFrames) do if f.scripts.OnEvent and f ~= allFrames[1] then cpFrame = f end end
cpFrame.events.PLAYER_LOGIN = true
cpFrame.scripts.OnEvent(cpFrame, "PLAYER_LOGIN")
check(cpFrame.unitev.UNIT_POWER_UPDATE and ns.active, "Schurke aktiv")
slider:SetValue(18)
check(timers == 1, "Schurke: Nameplates werden neu gezeichnet")
local n = 0 for _, l in ipairs(out) do if l:find("Fehler") then n = n + 1 end end
check(n == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
