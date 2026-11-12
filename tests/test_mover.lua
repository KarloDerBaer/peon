-- Stub-Test fuer Peon + Peon_Mover (Fenster verschieben, Groesse, Zuruecksetzen, Kampf, Optionen)
-- Ausfuehren aus dem AddOns-Ordner (run_tests.sh).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
function GetTime() return 1 end
date = os.date
local combat = false
function InCombatLockdown() return combat end
function UnitAffectingCombat() return combat end
local shift, ctrl = false, false
function IsShiftKeyDown() return shift end
function IsControlKeyDown() return ctrl end
local cursorX, cursorY = 0, 0
local secure = false   -- true = Blizzards geschuetzter Code (darf im Kampf)
function GetCursorPosition() return cursorX, cursorY end
YES, NO = "Ja", "Nein"
StaticPopupDialogs = {}
local popupShown
function StaticPopup_Show(n) popupShown = n end
SlashCmdList = {}
function hooksecurefunc(t, name, fn)
  local orig = t[name]
  t[name] = function(...) local r = { orig(...) } fn(...) return unpack(r) end
end
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_Mover = TocMeta("Peon_Mover") }
local loadedAddons = { Peon = true, Peon_Mover = true, Leatrix_Maps = true }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function(a) return loadedAddons[a] == true end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Mover" })[i] end }
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
  function m.GetScript(s, n) return s.scripts[n] end
  function m.HookScript(s, n, f) local old = s.scripts[n] if old then s.scripts[n] = function(...) old(...) f(...) end else s.scripts[n] = f end end
  function m.SetText(s, t) s.text = t end
  function m.SetChecked(s, v) s.checked = v end
  function m.GetChecked(s) return s.checked end
  function m.SetValue(s, v) s.value = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end
  function m.IsShown(s) return s.shown end
  function m.Show(s) s.shown = true if s.scripts.OnShow then s.scripts.OnShow(s) end end
  function m.Hide(s) s.shown = false if s.scripts.OnHide then s.scripts.OnHide(s) end end
  function m.SetAlpha(s, a) s.alpha = a end
  function m.Enable(s) s.enabled = true end
  function m.Disable(s) s.enabled = false end
  function m.SetColorTexture(s, ...) s.color = { ... } end
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
C_Timer = { After = function() end }
local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end
local function near(a, b) return a and b and math.abs(a - b) < 0.01 end

-- ===== Fenster-Nachbau: Position als linke obere Ecke (in Fenster-Einheiten) =====
UIParent = { GetEffectiveScale = function() return 0.8 end }
local function Win(name, protected)
  local f = { name = name, scale = 1, left = 16, top = 650, shown = false, scripts = {}, pts = {},
    protected = protected, mouse = true, wheel = false, userPlaced = false, height = 400 }
  function f:GetObjectType() return "Frame" end
  function f:IsProtected() return self.protected, self.protected end
  function f:IsForbidden() return false end
  function f:SetMovable(v) self.movable = v end
  function f:SetClampedToScreen(v) self.clamped = v end
  function f:IsMouseEnabled() return self.mouse end
  function f:EnableMouse(v) self.mouse = v end
  function f:IsMouseWheelEnabled() return self.wheel end
  function f:EnableMouseWheel(v) self.wheel = v end
  function f:HookScript(n, fn) local old = self.scripts[n] if old then self.scripts[n] = function(...) old(...) fn(...) end else self.scripts[n] = fn end end
  function f:GetScale() return self.scale end
  function f:SetScale(s) if combat and self.protected then error("BLOCKIERT SetScale " .. name) end self.scale = s end
  function f:GetEffectiveScale() return self.scale * 0.8 * (self.parentScale or 1) end
  function f:SetParent(p) self.parentScale = p and p.scale or 1 end
  function f:GetLeft() return self.left end
  function f:GetTop() return self.top end
  function f:GetNumPoints() return #self.pts end
  function f:GetPoint(i) return unpack(self.pts[i]) end
  function f:ClearAllPoints() if combat and self.protected and not secure then error("BLOCKIERT ClearAllPoints " .. name) end self.pts = {} end
  function f:SetPoint(p, rel, rp, x, y)
    if combat and self.protected and not secure then error("BLOCKIERT SetPoint " .. name) end
    self.pts[#self.pts + 1] = { p, rel, rp, x, y }
    if p == "TOPLEFT" and rp == "BOTTOMLEFT" then self.left, self.top = x, y
    elseif p == "TOPLEFT" then self.left, self.top = x or 0, 700 + (y or 0) end
  end
  function f:StartMoving() if combat and self.protected then error("BLOCKIERT StartMoving") end self.isMoving = true self.userPlaced = true end
  function f:StopMovingOrSizing() self.isMoving = false end
  function f:IsUserPlaced() return self.userPlaced end
  function f:SetUserPlaced(v) self.userPlaced = v end
  function f:IsShown() return self.shown end
  function f:Show() self.shown = true if self.scripts.OnShow then self.scripts.OnShow(self) end end
  function f:Hide() self.shown = false if self.scripts.OnHide then self.scripts.OnHide(self) end end
  _G[name] = f
  return f
end
-- Blizzard setzt ein Fenster an "seinen" Platz (wie der Fenster-Manager beim Oeffnen)
local function Blizz(f, x, y) f:ClearAllPoints() f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y) end
-- Maus an eine Stelle im Fenster (dy = Abstand von der Oberkante in Fenster-Einheiten)
local function Cursor(f, dy) cursorX = (f.left + 50) * f:GetEffectiveScale(); cursorY = (f.top - dy) * f:GetEffectiveScale() end
local function Down(f, b) f.scripts.OnMouseDown(f, b or "LeftButton") end
local function Up(f, b) f.scripts.OnMouseUp(f, b or "LeftButton") end

local char = Win("CharacterFrame")
Blizz(char, 16, -116)
local spells = Win("PlayerSpellsFrame", true)        -- geschuetzt
local auto = Win("MyPanelFrame")                      -- nur ueber UIPanelWindows bekannt
local bags = Win("ContainerFrame1")                   -- Taschen: nie anfassen
local map = Win("WorldMapFrame")                      -- gehoert Leatrix_Maps
UIPanelWindows = { MyPanelFrame = { area = "left" }, ContainerFrame1 = { area = "left" }, CharacterFrame = { area = "left" } }

-- ===== Laden =====
load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
PeonMoverDB = { enabled = "kaputt", frames = { OldFrame = { x = 10, y = 500 } } }
local ns = load("Peon_Mover", "Peon_Mover")
fire("ADDON_LOADED", "Peon_Mover")
local mod = ns.mod
check(mod.initialized and mod.page, "Modul + Optionsseite")
check(PeonMoverDB.enabled == true, "ungueltiger Wert -> Standard")
check(StaticPopupDialogs.PEON_MOVER_RESET_ALL ~= nil, "Rueckfrage nur als Eintrag angelegt")
fire("PLAYER_LOGIN")
check(cats.Peon and cats.Peon.subs[1] == "Mover", "Seite unter Peon > Mover")

-- ===== Finden =====
check(ns.win.CharacterFrame and ns.win.CharacterFrame.hooked, "bekanntes Fenster eingehaengt")
check(ns.win.MyPanelFrame and ns.win.MyPanelFrame.auto, "Fenster aus UIPanelWindows automatisch gefunden")
check(ns.win.ContainerFrame1 == nil, "Taschen ausgelassen")
check(ns.win.WorldMapFrame == nil, "Weltkarte ausgelassen, weil Leatrix_Maps geladen ist")
check(ns.win.PlayerSpellsFrame and ns.win.PlayerSpellsFrame.hooked, "geschuetztes Fenster ausserhalb des Kampfes eingehaengt")
check(char.movable and char.clamped and char.wheel, "verschiebbar, am Bildschirm gehalten, Mausrad an")
check(#ns.win.CharacterFrame.orig == 1 and ns.win.CharacterFrame.orig[1][4] == 16, "Blizzards Position gemerkt")

-- ===== Verschieben an der Titelleiste =====
char:Show()
Cursor(char, 100)                                   -- mitten im Fenster
Down(char)
check(not char.isMoving, "Klick ausserhalb der Titelleiste verschiebt nicht")
Cursor(char, 10)                                    -- in der Titelleiste
Down(char)
check(char.isMoving, "Titelleiste ziehen startet Verschieben")
char.left, char.top = 300, 600                      -- Spieler zieht
Up(char)
local s = PeonMoverDB.frames.CharacterFrame
check(s and near(s.x, 300) and near(s.y, 600), "Position gespeichert (x/y in UIParent-Einheiten)")
check(char.userPlaced == false, "Blizzards Merker 'vom Spieler platziert' zurueckgesetzt")

-- Blizzard setzt das Fenster beim naechsten Oeffnen neu -> zurueck an unsere Stelle
Blizz(char, 16, -116)
check(char.left == 300 and char.top == 600, "nach Blizzards Neusetzen wieder an der gespeicherten Stelle")
check(ns.win.CharacterFrame.orig[1][4] == 16, "Blizzards Wunschposition weiter bekannt")

-- ===== Groesse =====
Cursor(char, 100)
char.scripts.OnMouseWheel(char, 1)
check(char.scale == 1, "Mausrad ohne Strg aendert nichts")
ctrl = true
char.scripts.OnMouseWheel(char, 1)
char.scripts.OnMouseWheel(char, 1)
ctrl = false
check(near(char.scale, 1.1) and near(s.s, 1.1), "Strg + Mausrad: Groesse 110 % gespeichert")
check(near(char.left * 1.1, 300) and near(char.top * 1.1, 600), "Ecke bleibt bei neuer Groesse an derselben Stelle")
ctrl = true
for i = 1, 40 do char.scripts.OnMouseWheel(char, 1) end
check(near(char.scale, 2.0), "Groesse hoechstens 200 %")
for i = 1, 40 do char.scripts.OnMouseWheel(char, -1) end
check(near(char.scale, 0.5), "Groesse mindestens 50 %")
for i = 1, 10 do char.scripts.OnMouseWheel(char, 1) end
ctrl = false
check(near(char.scale, 1.0) and s.s == nil, "zurueck auf 100 % = keine gespeicherte Groesse")

-- Groesse ohne Verschieben: Position bleibt Blizzards Sache
local auto_ = auto
auto_:Show()
Blizz(auto_, 20, -100)
ctrl = true; Cursor(auto_, 100); auto_.scripts.OnMouseWheel(auto_, 1); ctrl = false
local sa = PeonMoverDB.frames.MyPanelFrame
check(sa and near(sa.s, 1.05) and sa.x == nil, "nur Groesse gespeichert, keine Position")
Blizz(auto_, 40, -100)
check(auto_.left == 40, "Blizzard darf ein nur vergroessertes Fenster weiter anordnen")

-- ===== Zuruecksetzen (Umschalt + Rechtsklick auf die Titelleiste) =====
ctrl = true; Cursor(char, 100); char.scripts.OnMouseWheel(char, 1); ctrl = false
Cursor(char, 10)
Down(char, "RightButton")
check(PeonMoverDB.frames.CharacterFrame ~= nil, "Rechtsklick ohne Umschalt setzt nicht zurueck")
shift = true; Down(char, "RightButton"); shift = false
check(PeonMoverDB.frames.CharacterFrame == nil, "Umschalt + Rechtsklick loescht Position und Groesse")
check(char.scale == 1 and char.left == 16 and char.top == 700 - 116, "Fenster wieder an Blizzards Stelle und 100 %")

-- ===== Sperre =====
mod.db.enabled = false
Cursor(char, 10); Down(char)
check(not char.isMoving, "Sperre: Ziehen bewirkt nichts")
ctrl = true; char.scripts.OnMouseWheel(char, 1); ctrl = false
check(char.scale == 1, "Sperre: Groesse bleibt")
mod.db.enabled = true
-- gespeicherte Positionen gelten auch bei Sperre
Cursor(char, 10); Down(char); char.left, char.top = 200, 500; Up(char)
mod.db.enabled = false
Blizz(char, 16, -116)
check(char.left == 200, "Sperre: gespeicherte Position gilt weiter")
mod.db.enabled = true

-- ===== An/Aus je Fenster =====
ns.Toggle("CharacterFrame")
check(ns.IsOff("CharacterFrame") and char.left == 16, "Aus: Blizzards Position")
Cursor(char, 10); Down(char)
check(not char.isMoving, "Aus: Ziehen bewirkt nichts")
Blizz(char, 16, -116)
check(char.left == 16, "Aus: Blizzard setzt frei")
ns.Toggle("CharacterFrame")
check(not ns.IsOff("CharacterFrame") and char.left == 200, "An: gemerkte Position wieder da")

-- ===== Kampf (geschuetztes Fenster) =====
spells:Show()
Cursor(spells, 10); Down(spells); spells.left, spells.top = 400, 550; Up(spells)
check(PeonMoverDB.frames.PlayerSpellsFrame.x == 400, "geschuetztes Fenster ausserhalb des Kampfes verschiebbar")
fire("PLAYER_REGEN_DISABLED"); combat = true
local function Hints() local n = 0 for _, l in ipairs(out) do if l:find("im Kampf nicht verschieben") then n = n + 1 end end return n end
Cursor(spells, 10); Down(spells)
check(not spells.isMoving, "im Kampf kein Verschieben eines geschuetzten Fensters")
check(Hints() == 1, "Hinweis im Chat")
Down(spells)
check(Hints() == 1, "Hinweis nur einmal je Kampf")
ctrl = true; spells.scripts.OnMouseWheel(spells, 1); ctrl = false
check(spells.scale == 1, "im Kampf keine Groessenaenderung")
-- Blizzard setzt das Fenster im Kampf (geschuetzter Code darf das) -> nach dem Kampf nachholen
secure = true; spells:ClearAllPoints(); spells:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116); secure = false
check(spells.left == 16, "im Kampf nicht angefasst")
check(ns.queue["apply:PlayerSpellsFrame"] ~= nil, "fuer nach dem Kampf vorgemerkt")
-- neues geschuetztes Fenster taucht im Kampf auf
local prof = Win("ProfessionsFrame", true)
fire("ADDON_LOADED", "Blizzard_Professions")
check(ns.win.ProfessionsFrame and not ns.win.ProfessionsFrame.hooked, "im Kampf geladenes Fenster wartet")
combat = false; fire("PLAYER_REGEN_ENABLED")
check(spells.left == 400 and spells.top == 550, "nach dem Kampf an die gespeicherte Stelle")
check(ns.win.ProfessionsFrame.hooked, "nach dem Kampf eingehaengt")
check(next(ns.queue) == nil, "Warteschlange leer")

-- ===== Optionsseite =====
if mod.panel.scripts.OnShow then mod.panel.scripts.OnShow(mod.panel) end
local items = ns.ListItems()
local byName = {}
for _, it in ipairs(items) do byName[it.name] = it end
check(byName.CharacterFrame and byName.CharacterFrame.title == "Charakter" and byName.CharacterFrame.state == "verschoben", "Liste: Charakter verschoben")
check(byName.MyPanelFrame.state == "Größe 105 %" and byName.MyPanelFrame.auto, "Liste: Groesse und automatisch gefunden")
check(byName.OldFrame and not byName.OldFrame.loaded, "Liste: gespeichertes, noch nicht geladenes Fenster")
check(byName.ProfessionsFrame and byName.ProfessionsFrame.state == "Standard", "Liste: Standard")
ns.list:Select(byName.CharacterFrame)
ns.Toggle("CharacterFrame")
check(ns.list:GetSelected() and ns.list:GetSelected().name == "CharacterFrame" and ns.list:GetSelected().state == "aus", "Auswahl bleibt nach Neuaufbau, Status aus")
ns.Toggle("CharacterFrame")
mod:ResetDefaults()
check(PeonMoverDB.frames.CharacterFrame ~= nil, "Standardwerte behalten die Fensterpositionen")

-- ===== Winzig versteckt (Peon_Bags: Rahmen mit Groesse 0,001) und zurueckgeholt =====
do
  local s = PeonMoverDB.frames.CharacterFrame
  char:Show()
  local x0, y0 = char.left, char.top
  char:SetParent({ scale = 0.001 })
  Blizz(char, 16, -116)                       -- Blizzard setzt die Lage, waehrend das Fenster versteckt ist
  check(char.left < 10000 and char.top < 10000, "0.1.1: versteckt keine riesigen Abstaende")
  char:SetParent({ scale = 1 })
  check(near(char.left, x0) and near(char.top, y0) and s.x, "0.1.1: nach dem Zurueckholen wieder an der gespeicherten Stelle")
  char:Hide()
end

-- ===== Alle zuruecksetzen =====
SlashCmdList.PEON("mover zuruecksetzen")
check(next(PeonMoverDB.frames) == nil, "/peon mover zuruecksetzen leert alles")
check(char.left == 16 and spells.left == 16 and near(auto_.scale, 1), "alle Fenster wieder an Blizzards Stelle")
SlashCmdList.PEON("mover")
check(out[#out] == "OPEN Peon/Mover", "/peon mover oeffnet Seite")

local n = 0 for _, l in ipairs(out) do if l:find("Fehler") or l:find("BLOCKIERT") then n = n + 1 end end
check(n == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
