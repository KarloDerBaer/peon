# Peon – Vorlage für neue Module

Diese Notiz bündelt den Inhalt von `<Repo>\vorlage\` (dort liegen dieselben Dateien).

`Peon_Beispiel` ist ein fertiges, getestetes Grundgerüst (Einstellungen mit Standardwerten, Wertebereich und erlaubten Werten, Optionsseite mit Kern-Bausteinen, Debug-Log, `/peon beispiel`). `test_beispiel.lua` ist der passende Test.

## Neues Modul anlegen (Beispiel: Peon_Gatherer)

1. `vorlage\Peon_Beispiel` in eine Arbeitskopie kopieren und zu `Peon_Gatherer` umbenennen, ebenso die TOC-Datei (`Peon_Gatherer.toc`) und `Beispiel.lua` (`Gatherer.lua`, auch in der TOC).
2. In allen Dateien ersetzen: `Beispiel` → `Gatherer`, `beispiel` → `gatherer`, `PeonBeispielDB` → `PeonGathererDB`.
3. In der TOC Titel, Notes (en/de), IconTexture und Version (0.1.0) anpassen. Pro-Charakter-Werte: `## SavedVariablesPerCharacter: PeonGathererCharDB` und in `NewModule` `charDB` + `charKeys` setzen.
4. `test_beispiel.lua` als `tests\test_gatherer.lua` ablegen, Namen ersetzen, Prüfungen erweitern.
5. Testen (`run_tests.sh`), in den AddOns-Ordner übertragen, Prüfsummen kontrollieren.
6. Im Spiel `/reload`.
7. `Peon_Stand.md` und bei Bedarf `Peon_Entscheidungen.md` ergänzen.

## Aufbau

| Datei | Inhalt |
|---|---|
| Peon_Beispiel.toc | Interface 16001, Dependencies/Group Peon, Titel in Peon-Grün, Icon, SavedVariables |
| Locales.lua | Texte enUS, darunter deDE; `Peon.NewLocale()` |
| Beispiel.lua | `Peon:NewModule(...)`, `Apply()` bei LOGIN/CHANGED/RESET, Optionsseite bei INIT |
| Options.lua | `mod:NewOptionsPage`, Header, Check, Slider, Dropdown (Auswahlliste), Reset-Knopf, Ausgrauen |

Weitere Bausteine und die ganze Kern-API: siehe `Peon_Ueberblick.md`.

## Eigenes Fenster (ab Kern-API 18)

Fenster eines Moduls nur mit `Peon.UI` bauen, damit alle Peon-Fenster gleich aussehen. Regeln, Maße und alle Bausteine: `docs\konzepte\Peon_UI_Design.md`, Beispiele im Spiel mit `/peon ui`.

```lua
if Peon.UI then
    local UI = Peon.UI
    local win = UI.Window("PeonBeispielFrame", { title = "Peon Beispiel", icon = "Interface\\Icons\\INV_Misc_QuestionMark" })
    local panel = UI.Panel(win, "left")
    panel:SetPoint("TOPLEFT", UI.EDGE, -UI.TOP)
    panel:SetPoint("BOTTOMRIGHT", -5, UI.BOTTOM)
    UI.SectionTab(panel, "Beispiel")
    UI.FormRow(panel, "Anzahl", UI.Input(panel, 134, { numeric = true }), 11, -20)
    UI.StatusBar(win):SetText("Bereit")
end
```

In der TOC dann `## Dependencies: Peon` und in `NewModule` prüfen, ob `Peon.API >= 18` ist (sonst „Peon ist zu alt“ melden).

## Peon_Beispiel/Peon_Beispiel.toc

```
## Interface: 16001
## Title: |cff8ccf4dPeon|r Beispiel
## Notes: Template module for the Peon addon collection.
## Notes-deDE: Vorlage für ein Peon-Modul.
## Author: KarloDerBaer
## Version: 0.1.0
## Dependencies: Peon
## Group: Peon
## IconTexture: Interface\Icons\INV_Misc_QuestionMark
## SavedVariables: PeonBeispielDB

Locales.lua
Beispiel.lua
Options.lua
```

## Peon_Beispiel/Locales.lua

```lua
-- Peon_Beispiel - Locales.lua
-- Allgemeine Texte (Fehler, Standardwerte, Positionen) liefert der Peon-Kern (Peon.L)
local ADDON_NAME, ns = ...

local L = Peon.NewLocale()
ns.L = L

-- enUS (Standard)
L.DESC       = "Template module. Changes apply immediately."
L.HDR_MAIN   = "General"
L.ENABLED    = "Enabled"
L.SIZE       = "Size"
L.SIZE_HINT  = "Just an example value."
L.MODE       = "Mode"
L.MODE_A     = "A"
L.MODE_B     = "B"
L.SLASH_HINT = "Chat: /peon beispiel opens this panel."

if GetLocale() == "deDE" then
    L.DESC       = "Vorlage für ein Modul. Änderungen wirken sofort."
    L.HDR_MAIN   = "Allgemein"
    L.ENABLED    = "Eingeschaltet"
    L.SIZE       = "Größe"
    L.SIZE_HINT  = "Nur ein Beispielwert."
    L.MODE       = "Modus"
    L.SLASH_HINT = "Chat: /peon beispiel öffnet dieses Menü."
end
```

## Peon_Beispiel/Beispiel.lua

```lua
-- Peon_Beispiel - Beispiel.lua
-- Anmeldung beim Peon-Kern, Einstellungen, Ereignisse.
-- Einstellungen in PeonBeispielDB.
--
-- Neues Modul aus dieser Vorlage:
--   1. Ordner und TOC umbenennen (Peon_<Name>), in der TOC Titel, Notes, Icon, SavedVariables anpassen
--   2. Hier key, title, db anpassen; "Beispiel"/"beispiel" ueberall ersetzen
--   3. tests/test_<name>.lua aus vorlage/test_beispiel.lua anlegen
--   4. Im Spiel /reload

local ADDON_NAME, ns = ...
local L = ns.L

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "beispiel",          -- /peon beispiel ...
    title    = "Beispiel",
    db       = "PeonBeispielDB",
    defaults = {
        enabled = true,
        size    = 16,
        mode    = "a",
    },
    ranges   = { size = { 8, 32, 1 } },        -- min, max, Schrittweite
    choices  = { mode = { a = true, b = true } },
    -- eigene Slash-Befehle (optional): slash = { "/xy" }, onSlash = function(m, cmd, rest) end,
})
ns.mod = mod

-- Einstellungen anwenden (nach Start, Aenderung im Menue und Reset)
local function Apply()
    local db = mod.db
    if not db then return end
    mod:Dbg(("Apply enabled=%s size=%s mode=%s"):format(tostring(db.enabled), tostring(db.size), tostring(db.mode)))
end
ns.Apply = Apply

mod:On("INIT", function()
    -- Optionsseite spaetestens hier anmelden (der Kern haengt Unterseiten bei PLAYER_LOGIN ein)
    if ns.CreateOptions then mod:Call("Options", ns.CreateOptions) end
end)
mod:On("LOGIN", Apply)
mod:On("CHANGED", Apply)
mod:On("RESET", Apply)

-- Beispiel fuer ein WoW-Ereignis (fn bekommt event, ...)
-- mod:RegisterEvent("ZONE_CHANGED_NEW_AREA", function(event) Apply() end)
```

## Peon_Beispiel/Options.lua

```lua
-- Peon_Beispiel - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Beispiel (Bausteine aus dem Peon-Kern).

local ADDON_NAME, ns = ...
local L = ns.L

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })

    local left = page:Column(16, -60)
    page:Add(left, page:Header(L.HDR_MAIN), 6)
    page:Add(left, page:Check("enabled", L.ENABLED), 20)
    local sizeCtl = page:Add(left, page:Slider("size", L.SIZE, L.SIZE_HINT))
    page:Add(left, page:Dropdown("mode", L.MODE, { { "a", L.MODE_A }, { "b", L.MODE_B } }))

    page:AddResetButton(L.SLASH_HINT, left)

    -- abhaengige Einstellungen ausgrauen
    page.onRefresh = function()
        local db = mod.db
        if db then sizeCtl:SetAlpha(db.enabled and 1 or 0.4) end
    end

    page:Register()
end
```

## test_beispiel.lua

```lua
-- Stub-Test fuer Peon + Peon_Beispiel (Vorlage fuer neue Module)
-- Kopieren nach tests/test_<name>.lua, "Beispiel" ersetzen, Pruefungen anpassen.
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
-- Metadaten (Version, Titel) direkt aus der TOC-Datei lesen, damit der Test immer die echte Version zeigt
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_Beispiel = TocMeta("Peon_Beispiel") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function() return true end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Beispiel" })[i] end }
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

-- ===== Ab hier modulspezifisch =====
load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
PeonBeispielDB = { size = 99, mode = "falsch" }      -- ungueltige Werte, die korrigiert werden muessen
local ns = load("Peon_Beispiel", "Peon_Beispiel")
fire("ADDON_LOADED", "Peon_Beispiel")
local mod = ns.mod
check(mod.initialized and mod.page, "Modul + Optionsseite")
check(PeonBeispielDB.size == 32, "Groesse auf Bereich geklemmt")
check(PeonBeispielDB.mode == "a", "ungueltiger Modus -> Standard")
check(PeonBeispielDB.enabled == true, "fehlender Wert ergaenzt")
fire("PLAYER_LOGIN")
check(cats.Peon and cats.Peon.subs[1] == "Beispiel", "Seite unter Peon > Beispiel")

-- Seite anzeigen (fuellt die Regler mit den aktuellen Werten)
if mod.panel.scripts.OnShow then mod.panel.scripts.OnShow(mod.panel) end
-- Regler aendert Einstellung
local slider
for _, f in ipairs(allFrames) do if f.kind == "Slider" and f.value == 32 then slider = f end end
check(slider ~= nil, "Regler gefunden")
slider:SetValue(20)
check(PeonBeispielDB.size == 20, "Regler -> Einstellung")

-- Auswahlliste
for _, c in ipairs(mod.page.controls) do if c.key == "mode" then c.Select("b") end end
check(PeonBeispielDB.mode == "b", "Auswahlliste -> Einstellung")

-- Slash + Reset
SlashCmdList.PEON("beispiel")
check(out[#out] == "OPEN Peon/Beispiel", "/peon beispiel oeffnet Seite")
mod:ResetDefaults()
check(PeonBeispielDB.size == 16, "Reset")

local n = 0 for _, l in ipairs(out) do if l:find("Fehler") then n = n + 1 end end
check(n == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
```
