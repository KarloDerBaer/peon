-- Stub-Test fuer Peon + Peon_Tooltip
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
function GetTime() return 1 end
date = os.date
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
function IsShiftKeyDown() return false end
local mouseoverUnit = false
function UnitExists() return mouseoverUnit end
function GetCursorPosition() return 500, 400 end
SlashCmdList = {}
local loaded = { Peon = true, Peon_Tooltip = true }
-- Metadaten (Version, Titel) direkt aus der TOC-Datei lesen, damit der Test immer die echte Version zeigt
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_Tooltip = TocMeta("Peon_Tooltip") }
C_AddOns = {
  GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function(a) return loaded[a] or false end,
  GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Tooltip" })[i] end,
}

-- generisches Widget
local allFrames = {}
local function W()
  local o = { scripts = {}, w = 0, h = 0, shown = true, events = {} }
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
  function m.SetText(s, t) s.text = t end
  function m.GetText(s) return s.text end
  function m.SetChecked(s, v) s.checked = v end
  function m.GetChecked(s) return s.checked end
  function m.SetValue(s, v) s.value = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end
  function m.IsShown(s) return s.shown end
  function m.Show(s) s.shown = true end
  function m.Hide(s) s.shown = false end
  function m.SetAlpha(s, a) s.alpha = a end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.GetThumbTexture() return true end
  function m.CreateFontString() return W() end
  function m.CreateTexture() return W() end
  function m.GetScale() return 1 end
  function m.GetEffectiveScale() return 1 end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" and k ~= "NineSlice" then return function() end end end })
end
function CreateFrame(kind, name, parent, template)
  local f = W(); f.kind = kind; f.template = template
  allFrames[#allFrames+1] = f
  return f
end
UIParent = W()
GameTooltip = W()
local hooks = {}
function hooksecurefunc(a, b, c)
  if type(a) == "string" then hooks[a] = b else hooks[b] = c end
end
function GameTooltip.GetOwner(s) return s.owner end
function GameTooltip.GetAnchorType(s) return s.anchorType end
function GameTooltip.SetOwner(s, o, a) s.owner, s.anchorType = o, a end
function GameTooltip.FadeOut() end
function GameTooltip_SetDefaultAnchor() end
TooltipDataProcessor = { AddTooltipPostCall = function() end, AllTypes = "ALL" }
Enum = { TooltipDataType = { Unit = 2 }, TooltipDataLineType = {} }

local cats = {}
Settings = {
  RegisterCanvasLayoutCategory = function(p, n) local c = { name = n, subs = {}, GetID = function() return n end } cats[n] = c return c end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) local c = { name = n, GetID = function() return par.name .. "/" .. n end } table.insert(par.subs, n) return c end,
  RegisterAddOnCategory = function(c) c.registered = true end,
  OpenToCategory = function(id) print("OPEN " .. tostring(id)) end,
}
local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon, files) local ns = {} for _, f in ipairs(files) do assert(loadfile(dir .. "/" .. f))(addon, ns) end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end
local function toc(dir, name) local t = {} for l in io.lines(dir .. "/" .. name) do if l:match("%.lua$") then t[#t+1] = l end end return t end

load("Peon", "Peon", toc("Peon", "Peon.toc"))
fire("ADDON_LOADED", "Peon")

-- vorhandene Einstellungen (teils ungueltig)
PeonTooltipDB = { corner = "TOPLEFT", offsetX = 35, scale = 120, pvpIcon = "BOTTOM", questIcon = "none", combatMode = "hide", fadeTime = 99 }
local ns = load("Peon_Tooltip", "Peon_Tooltip", toc("Peon_Tooltip", "Peon_Tooltip.toc"))
fire("ADDON_LOADED", "Peon_Tooltip")
local mod = ns.mod
check(mod and mod.initialized, "Modul initialisiert")
check(PeonTooltipDB.corner == "TOPLEFT" and PeonTooltipDB.offsetX == 35 and PeonTooltipDB.scale == 120, "alte Einstellungen uebernommen")
check(PeonTooltipDB.pvpIcon == "BOTTOM" and PeonTooltipDB.questIcon == "none", "Symbolpositionen uebernommen")
check(PeonTooltipDB.fadeTime == 20, "ausserhalb Bereich geklemmt")
check(PeonTooltipDB.iconSize == 20 and PeonTooltipDB.edgeFlip == true, "fehlende Werte ergaenzt")
check(mod.page and mod.panel, "Optionsseite gebaut")
check(#mod.page.controls >= 18, "Bausteine: " .. #mod.page.controls)

fire("PLAYER_LOGIN")
check(cats.Peon.registered and cats.Peon.subs[1] == "Tooltip", "Seite unter Peon > Tooltip")

-- Bedienung simulieren
local page = mod.page
mod.panel.scripts.OnShow()
local v0 = ns.settingsVersion
local function findButton(label)
  for _, f in ipairs(allFrames) do if f.label == label then return f end end
end
local b = findButton("Unten rechts") or findButton("Bottom right")
b.scripts.OnClick(b)
check(PeonTooltipDB.corner == "BOTTOMRIGHT" or PeonTooltipDB.pvpIcon == "BOTTOMRIGHT", "Knopf setzt Wert")
local dd
for _, c in ipairs(mod.page.controls) do if c.key == "borderMode" then dd = c end end
check(dd and dd.Select, "Rahmenfarbe als Auswahlliste")
dd.Select("class")
check(PeonTooltipDB.borderMode == "class", "Auswahlliste setzt Wert")
check(ns.settingsVersion > v0, "CHANGED -> OnSettingChanged")
local slider
for _, f in ipairs(allFrames) do if f.kind == "Slider" and f.value == 120 then slider = f end end
check(slider, "Regler Groesse gefunden")
slider:SetValue(143)
check(PeonTooltipDB.scale == 145, "Regler rundet auf Schritt (145)")
local alphaBefore
for _, c in ipairs(page.controls) do if c.alpha then alphaBefore = true end end
check(alphaBefore, "Ausgrauen aktiv")

-- Slash
SlashCmdList.PEON_TOOLTIP("reset")
check(PeonTooltipDB.corner == "BOTTOMRIGHT" and PeonTooltipDB.scale == 100 and PeonTooltipDB.pvpIcon == "TOPRIGHT", "/ttp reset")
check(PeonTooltipDB.offsetX == 40 and PeonTooltipDB.offsetY == 40, "0.7.3: Standard-Abstand 40")
check(PeonTooltipDB.fadeCustom == true and PeonTooltipDB.fadeTime == 0, "0.7.3: Standard sofort ausblenden")
-- neue Standardwerte einmalig uebernehmen
local old = { offsetX = 20, offsetY = 20, fadeCustom = false, fadeTime = 2 }
ns.MigrateDefaults(old)
check(old.offsetX == 40 and old.offsetY == 40 and old.fadeCustom == true and old.fadeTime == 0, "0.7.3: alte Standardwerte werden umgestellt")
old.fadeCustom, old.fadeTime, old.offsetX, old.offsetY = false, 2, 20, 20
ns.MigrateDefaults(old)
check(old.fadeCustom == false and old.fadeTime == 2 and old.offsetX == 20, "0.7.3: nur einmal, spaetere eigene Wahl bleibt")
local own = { offsetX = 35, offsetY = 20, fadeCustom = false, fadeTime = 5 }
ns.MigrateDefaults(own)
check(own.offsetX == 35 and own.offsetY == 20 and own.fadeCustom == false and own.fadeTime == 5, "0.7.3: eigene Werte bleiben")
local fresh = {}
ns.MigrateDefaults(fresh)
check(fresh.defaultsVer == 1 and fresh.offsetX == nil and fresh.fadeCustom == nil, "0.7.3: neue Installation bekommt die Standardwerte")

-- Ausblenden in der Welt (0.7.4: auch Objekte)
local function Anchor() GameTooltip:Show(); hooks.GameTooltip_SetDefaultAnchor(GameTooltip, UIParent) end
local function Tick() GameTooltip.scripts.OnUpdate(GameTooltip) end
Anchor(); Tick()
check(GameTooltip.shown, "0.7.4: Maus auf dem Objekt, Tooltip bleibt")
hooks.GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)   -- wie Blizzards SetWorldCursor beim Verlassen
hooks.FadeOut(GameTooltip); Tick()
check(not GameTooltip.shown, "0.7.4: Objekt verlassen, Tooltip sofort weg")
Anchor(); mouseoverUnit = true; Tick()
check(GameTooltip.shown, "0.7.4: Maus auf der Einheit, Tooltip bleibt")
mouseoverUnit = false; Tick()
check(not GameTooltip.shown, "0.7.4: Einheit verlassen, Tooltip sofort weg")
PeonTooltipDB.fadeCustom = false
Anchor(); hooks.FadeOut(GameTooltip); Tick()
check(GameTooltip.shown, "0.7.4: Funktion aus, Blizzard blendet aus")
PeonTooltipDB.fadeCustom = true
Anchor(); Tick()
check(GameTooltip.shown, "0.7.4: neuer Tooltip vergisst das Verlassen")
GameTooltip.owner = nil
SlashCmdList.PEON("tooltip")
check(out[#out] == "OPEN Peon/Tooltip", "/peon tooltip oeffnet Seite")
SlashCmdList.PEON_TOOLTIP("")
check(out[#out] == "OPEN Peon/Tooltip", "/ttp oeffnet Seite")
check(_G.SLASH_PEON_TOOLTIP1 == "/ttp" and _G.SLASH_PEON_TOOLTIP2 == nil, "Slash-Namen")
SlashCmdList.PEON("debug tooltip")
check(PeonTooltipDB.debug == true and type(PeonTooltipDB.debugLog) == "table", "Debug-Log ueber /peon debug tooltip")
fire("PLAYER_REGEN_DISABLED"); check(ns.inCombat == true, "Kampf an")
fire("PLAYER_REGEN_ENABLED"); check(ns.inCombat == false, "Kampf aus")
SlashCmdList.PEON("list")
local n = 0 for _, l in ipairs(out) do if l:find("Fehler") or l:find("Error") then n = n + 1 end end
check(n == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
