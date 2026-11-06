-- Stub-Test fuer Peon (Starter, API 14) + Peon_Panel (Leiste, Panel, Kontextmenue, Optionen)
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
YES, NO, ACCEPT, CANCEL, OKAY = "Ja", "Nein", "Annehmen", "Abbrechen", "Okay"
StaticPopupDialogs = {}
local popups = {}
function StaticPopup_Show(n) popups[#popups + 1] = n end
SlashCmdList = {}
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_Panel = TocMeta("Peon_Panel") }
local loadedAddons = { Peon = true, Peon_Panel = true, Peon_Test = true, Peon_Spaet = true }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function(a) return loadedAddons[a] == true end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Panel" })[i] end }

-- ===== Rahmen-Nachbau =====
local allFrames = {}
local function W(kind, name, parent)
  local o = { scripts = {}, w = 0, h = 0, shown = true, events = {}, points = {}, kind = kind, name = name, parent = parent, alpha = 1 }
  local m = {}
  function m.SetSize(s, w, h) s.w, s.h = w, h end
  function m.SetHeight(s, h) s.h = h end
  function m.SetWidth(s, w) s.w = w end
  function m.GetHeight(s) return s.h end
  function m.GetWidth(s) return s.w end
  function m.GetStringHeight() return 12 end
  function m.GetStringWidth(s) return #(s.text or "") * 6 end
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
  function m.SetShown(s, v) s.shown = v and true or false end
  function m.SetAlpha(s, a) s.alpha = a end
  function m.GetAlpha(s) return s.alpha end
  function m.GetEffectiveScale() return 1 end
  function m.Enable(s) s.enabled = true end
  function m.Disable(s) s.enabled = false end
  function m.SetColorTexture(s, ...) s.color = { ... } end
  function m.SetTexture(s, t) s.tex = t end
  function m.SetPoint(s, ...) s.points[#s.points+1] = { ... } end
  function m.ClearAllPoints(s) s.points = {} end
  function m.GetLeft(s) return s.left or 100 end
  function m.GetTop(s) return s.top or 700 end
  function m.GetCenter(s) return s.cx or 500, s.cy or 700 end
  function m.GetParent(s) return s.parent end
  function m.SetParent(s, p) s.parent = p end
  function m.SetID(s, id) s.id = id end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.UnregisterAllEvents(s) s.events = {} end
  function m.GetThumbTexture() return true end
  function m.CreateFontString(s) return W("FontString", nil, s) end
  function m.CreateTexture(s) return W("Texture", nil, s) end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" then return function() end end end })
end
UIParent = W("Frame", "UIParent")
UIParent.h = 1000
Minimap = W("Frame", "Minimap")
Minimap.w = 140
function CreateFrame(kind, name, parent, template)
  local f = W(kind, name, parent)
  f.template = template
  allFrames[#allFrames+1] = f
  if name then _G[name] = f end
  return f
end
GameTooltip = W("GameTooltip")
GameTooltip.lines = {}
function GameTooltip:AddLine(t) table.insert(self.lines, t) end
function GameTooltip:SetOwner(o, a) self.owner, self.anchor = o, a; self.lines = {} end
local cats = {}
Settings = { RegisterCanvasLayoutCategory = function(p, n) local c = { name = n, subs = {}, GetID = function() return n end } cats[n] = c return c end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) table.insert(par.subs, n) return { GetID = function() return par.name .. "/" .. n end } end,
  RegisterAddOnCategory = function(c) c.registered = true end,
  OpenToCategory = function(id) print("OPEN " .. id) end }
local tickers = {}
C_Timer = { After = function(_, fn) fn() end, NewTicker = function(sec, fn) tickers[#tickers + 1] = { sec = sec, fn = fn } end }
local cursorX, cursorY = 0, 0
function GetCursorPosition() return cursorX, cursorY end

-- Menue-Nachbau: zeichnet auf, was das Modul einhaengt
local function NewRoot()
  local r = { items = {} }
  function r:CreateTitle(t) table.insert(self.items, { kind = "title", text = t }) end
  function r:CreateDivider() table.insert(self.items, { kind = "divider" }) end
  function r:CreateRadio(t, isSel, setSel, v) table.insert(self.items, { kind = "radio", text = t, isSel = isSel, setSel = setSel, value = v }) end
  function r:CreateButton(t, fn) table.insert(self.items, { kind = "button", text = t, fn = fn }) end
  return r
end
local menuOpened
Menu = { PopulateDescription = function(gen, owner, desc) gen(owner, desc) end,
  GetManager = function() return { OpenMenu = function(_, owner, desc, anchor) menuOpened = { owner = owner, desc = desc, anchor = anchor } return {} end } end }
MenuUtil = { CreateRootMenuDescription = function() return NewRoot() end,
  CreateContextMenu = function(owner, gen) local r = NewRoot() gen(owner, r) menuOpened = { owner = owner, desc = r, context = true } end }
MenuVariants = { GetDefaultContextMenuMixin = function() return {} end }
AnchorUtil = { CreateAnchor = function(...) return { ... } end }

local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function loadToc(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end

-- ===== Kern =====
loadToc("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
check(Peon.API == 14, "API 14")
check(Peon.ShortNumber(950) == "950" and Peon.ShortNumber(12345) == "12,3k" and Peon.ShortNumber(1200000) == "1,2M", "kurze Zahlen")
check(Peon.ShortGold(4500) == "45s" and Peon.ShortGold(9500000) == "950g" and Peon.ShortGold(123450000) == "12,3k g", "kurzes Gold")
check(Peon.ShortGold(30000000000000) == "3000,0M g", "sehr grosses Gold ohne Abbruch")

-- Testmodul mit Minimap-Button, zwei Texten und eigenen Menueeintraegen
PeonTestDB = { minimapShow = true }
local clicks, goldText = {}, "12,3k g"
local tm = Peon:NewModule("Peon_Test", { key = "test", title = "Test", db = "PeonTestDB",
  defaults = { minimapShow = true, minimapAngle = 200 } })
fire("ADDON_LOADED", "Peon_Test")
tm:NewMinimapButton({ icon = "icon-test", name = "PeonTestButton", hint = "Hinweis",
  onClick = function(m, button, owner) clicks[#clicks + 1] = { button, owner } end,
  onTooltip = function(m, tt) tt:AddLine("Zeile vom Modul") end,
  menu = function(m, root) root:CreateButton("Eigener Eintrag", function() end) end,
  update = function(m, tex) tex.colored = true end,
  texts = { { key = "gold", label = "Gold", get = function() return goldText end },
            { key = "kaputt", label = "Kaputt", get = function() error("Text kaputt") end } },
  defaultText = "gold" })
check(tm.launcher and tm.launcher.showKey == "minimapShow" and tm.launcher.key == "test", "NewMinimapButton legt den Starter an")
check(tm:NewLauncher({}) == tm.launcher, "je Modul nur ein Starter")
check(#Peon.GetLaunchers() == 1 and tm.launcher:IsMinimapShown(), "Starter gemeldet, Button an")
check(tm.launcher:GetText("gold") == "12,3k g", "Text lesen")
check(tm.launcher:GetText("gibtsnicht") == nil, "unbekannter Text")
check(tm.launcher:GetText("kaputt") == nil and #PeonDB.errors >= 1, "Fehler im Text wird abgefangen und gespeichert")
if PeonDB.errors then wipe(PeonDB.errors) end

-- ===== Panel laden: Starter kommt nach =====
local ns = loadToc("Peon_Panel", "Peon_Panel")
fire("ADDON_LOADED", "Peon_Panel")
local mod = ns.mod
check(mod.initialized and mod.page, "Modul + Optionsseite")
check(ns.starters.test and ns.starters.peon, "Starter des Testmoduls und Peon-Starter")
check(PeonTestDB.minimapShow == false, "erster Start: Minimap-Button aus")
check(tm.minimapButton.shown == false, "Button wirklich ausgeblendet")
check(PeonDB.panelHid.test == true and PeonDB.panelHid.peon == nil, "Kern merkt sich nur, was einen Button hatte")
check(PeonPanelDB.entries.test.bar and PeonPanelDB.entries.test.box and PeonPanelDB.entries.test.text == "gold", "Eintrag mit Standardtext")
check(PeonPanelDB.entries.peon.text == "none", "Peon ohne Text")
fire("PLAYER_LOGIN")
check(cats.Peon and cats.Peon.subs[1] == "Panel", "Seite unter Peon > Panel")
check(#popups == 1 and popups[1] == "PEON_PANEL_HINT" and PeonPanelDB.hintShown, "Hinweis einmalig")
check(StaticPopupDialogs.PEON_PANEL_HINT.text:find("wieder einschalten"), "Hinweis nennt das Wiedereinschalten")
check(#tickers == 1 and tickers[1].sec == 60, "Texte einmal je Minute")

-- ===== Leiste =====
local bar, box = ns.surfaces.bar, ns.surfaces.box
check(bar.frame.shown and not box.frame.shown, "Leiste an, Panel aus")
check(bar.frame.points[1][1] == "TOP", "Leiste oben")
local bt, bp = bar.buttons.test, bar.buttons.peon
check(bt.icon.tex == "icon-test" and bt.icon.colored, "Symbol und Faerbung")
check(bt.label.text == "12,3k g" and bt.label.shown, "Text neben dem Symbol")
check(bp.label.shown == false, "Peon ohne Text")
check(bt.points[1][4] == 4 and bp.points[1][4] == 4 + 22 + 3 + 42 + 6, "nebeneinander, Breite nach Text")
check(bar.frame.w == 4 + 67 + 6 + 22 + 4 and bar.frame.h == 30, "Leiste passt sich an")

-- Breite waechst nur
goldText = "9 g"
tm.launcher:Refresh()
check(bt.label.text == "9 g" and bt.w == 67 and bp.points[1][4] == 77, "kuerzerer Text: Nachbar bleibt stehen")
goldText = "123.456,7k g"
tm.launcher:Refresh()
check(bt.w == 22 + 3 + 72 and bp.points[1][4] == 4 + 97 + 6, "laengerer Text: Platz waechst")
goldText = "12,3k g"
tickers[1].fn()
check(bt.label.text == "12,3k g" and bt.w == 97, "Minutentakt aktualisiert den Text")
ns.ApplyAll()
check(bt.w == 67, "Umstellen setzt die Breite zurueck")

-- Position und Abstand
PeonPanelDB.barPos, PeonPanelDB.barX, PeonPanelDB.barY = "BOTTOMRIGHT", 10, 20
mod:Fire("CHANGED", "barPos")
local p = bar.frame.points[1]
check(p[1] == "BOTTOMRIGHT" and p[4] == -10 and p[5] == 20, "Abstand zeigt vom Rand weg")
PeonPanelDB.barPos = "TOPLEFT"
mod:Fire("CHANGED", "barPos")
p = bar.frame.points[1]
check(p[1] == "TOPLEFT" and p[4] == 10 and p[5] == -20, "oben links")
PeonPanelDB.barPos, PeonPanelDB.barX, PeonPanelDB.barY = "none", 0, 0
mod:Fire("CHANGED", "barPos")
check(not bar.frame.shown, "Position Aus blendet die Leiste aus")
PeonPanelDB.barPos = "TOP"
mod:Fire("CHANGED", "barPos")
check(bar.frame.shown, "wieder an")

-- Klick
bt.scripts.OnClick(bt, "LeftButton")
check(clicks[1][1] == "LeftButton" and clicks[1][2] == bt, "Linksklick ruft das Modul mit dem Knopf")

-- Tooltip
bar.frame.cy = 950
bt.scripts.OnEnter(bt)
check(GameTooltip.owner == bt and GameTooltip.anchor == "ANCHOR_BOTTOM", "Tooltip oben: nach unten")
check(table.concat(GameTooltip.lines, "|"):find("Zeile vom Modul") and table.concat(GameTooltip.lines, "|"):find("Rechtsklick"), "Tooltip mit Zeile und Hinweis")
check(not table.concat(GameTooltip.lines, "|"):find("Hinweis|"), "Hinweis des Minimap-Buttons steht nicht dabei")
bar.frame.cy = 50
bt.scripts.OnEnter(bt)
check(GameTooltip.anchor == "ANCHOR_TOP", "Tooltip unten: nach oben")

-- ===== Kontextmenue =====
bar.frame.cy = 950
bt.scripts.OnClick(bt, "RightButton")
check(menuOpened and menuOpened.owner == bt and not menuOpened.context, "Rechtsklick oeffnet das Menue am Knopf")
check(#clicks == 1, "Rechtsklick ruft das Modul nicht")
local a = menuOpened.anchor
check(a[1] == "TOPLEFT" and a[2] == bar.frame and a[3] == "BOTTOMLEFT" and a[4] == 4 and a[5] == -2, "obere Haelfte: Menue unter der Leiste")
local items = menuOpened.desc.items
local function find(list, text) for _, it in ipairs(list) do if it.text == text then return it end end end
check(items[1].kind == "title" and items[1].text == "Test", "Titel")
check(find(items, "Eigener Eintrag"), "Eintraege des Moduls")
local radioGold, radioNone = find(items, "Gold"), find(items, "Kein Text")
check(radioGold.isSel("gold") and not radioNone.isSel("none"), "gewaehlter Text markiert")
radioNone.setSel("none")
check(PeonPanelDB.entries.test.text == "none" and bt.label.shown == false, "Text im Menue abwaehlen")
radioGold.setSel("gold")
check(bt.label.text == "12,3k g", "Text im Menue waehlen")
bar.frame.cy = 50
bp.scripts.OnClick(bp, "RightButton")
a = menuOpened.anchor
check(a[1] == "BOTTOMLEFT" and a[3] == "TOPLEFT" and a[5] == 2 and a[4] == bp.points[1][4], "untere Haelfte: darueber, am Symbol ausgerichtet")
items = menuOpened.desc.items
check(not find(items, "Kein Text"), "ohne Texte keine Auswahl")
check(find(items, "Optionen von Panel") and find(items, "Optionen von Peon"), "Peon-Menue")
bar.frame.cy = 950

-- Rueckfall ohne verankertes Oeffnen
local keepMenu = Menu
Menu = nil
bt.scripts.OnClick(bt, "RightButton")
check(menuOpened.context, "Rueckfall: Blizzards Kontextmenue")
Menu = keepMenu
Menu.GetManager = function() error("kaputt") end
bt.scripts.OnClick(bt, "RightButton")
check(menuOpened.context, "Fehler beim Verankern: Rueckfall")
Menu.GetManager = function() return { OpenMenu = function(_, owner, desc, anchor) menuOpened = { owner = owner, desc = desc, anchor = anchor } return {} end } end

-- Entfernen und wieder einblenden
bt.scripts.OnClick(bt, "RightButton")
local n = #out
find(menuOpened.desc.items, "Von der Leiste entfernen").fn()
check(#out == n, "steht noch im Panel: kein Hinweis")
check(PeonPanelDB.entries.test.bar == false and bt.shown == false, "von der Leiste entfernt")
check(PeonPanelDB.entries.test.box == true, "im Panel noch vorgesehen")
ns.SetOnSurface(tm.launcher, "box", false)
check(out[#out]:find("nirgends"), "nirgends mehr angezeigt: Hinweis im Chat")
ns.SetOnSurface(tm.launcher, "bar", true)
ns.SetOnSurface(tm.launcher, "box", true)

-- ===== Reihenfolge =====
local ord = { "a", "b", "c" }
check(ns.MoveEntry(ord, "a", "c", true) and table.concat(ord) == "bca", "hinter das Ziel")
check(ns.MoveEntry(ord, "a", "b", false) and table.concat(ord) == "abc", "vor das Ziel")
check(not ns.MoveEntry(ord, "a", "a") and not ns.MoveEntry(ord, "x", "a"), "auf sich selbst oder unbekannt: nichts")
local cells = { { key = "a", x = 0, y = 0, w = 10, h = 10 }, { key = "b", x = 20, y = 0, w = 10, h = 10 }, { key = "c", x = 0, y = 20, w = 10, h = 10 } }
local c1, after = ns.DropTarget(cells, 28, 5)
check(c1.key == "b" and after, "rechte Haelfte: dahinter")
c1, after = ns.DropTarget(cells, 2, 22)
check(c1.key == "c" and not after, "andere Reihe, linke Haelfte: davor")
check(ns.DropTarget({}, 0, 0) == nil, "keine Zellen")

-- Ziehen auf der Leiste
check(table.concat(PeonPanelDB.barOrder, ",") == "test,peon", "Reihenfolge am Anfang")
bar.frame.left, bar.frame.top = 100, 700
bt.scripts.OnDragStart(bt)
check(bar.dragging == bt and bt.alpha == 0.4 and bar.frame.scripts.OnUpdate, "Ziehen beginnt")
cursorX, cursorY = 100 + bp.points[1][4] + 20, 700 - 10
bar.frame.scripts.OnUpdate(bar.frame)
check(bar.marker.shown and bar.marker.points[1][4] == bp.points[1][4] + 22 + 1, "Markierung zeigt die Zielstelle")
bt.scripts.OnDragStop(bt)
check(table.concat(PeonPanelDB.barOrder, ",") == "peon,test", "Loslassen ordnet um")
check(not bar.marker.shown and bt.alpha == 1 and bar.frame.scripts.OnUpdate == nil, "Ziehen beendet")
check(bp.points[1][4] == 4 and bt.points[1][4] == 4 + 22 + 6, "Symbole sind umgerueckt")
check(table.concat(PeonPanelDB.boxOrder, ",") == "test,peon", "Panel hat eine eigene Reihenfolge")

-- ===== Panel =====
PeonPanelDB.boxShow = true
mod:Fire("CHANGED", "boxShow")
check(box.frame.shown and box.frame.points[1][1] == "CENTER", "Panel an, anfangs in der Mitte")
local xt, xp = box.buttons.test, box.buttons.peon
check(xt.label.text == "12,3k g" and xt.label.points[1][1] == "TOP" and xt.label.points[1][3] == "BOTTOM", "Text unter dem Symbol")
check(xt.w == xp.w and xt.h == 28 + 14, "alle Zellen gleich gross")
check(xt.points[1][5] == xp.points[1][5] and xp.points[1][4] > xt.points[1][4], "2 Symbole: 2 Spalten")
check(box.frame.scripts.OnDragStart ~= nil, "Panel ist verschiebbar")

-- Viele Starter: moeglichst quadratisch, feste Spalten
local extra = {}
for i = 1, 3 do
  local name = "Peon_Extra" .. i
  loadedAddons[name] = true
  _G["Peon" .. i .. "DB"] = {}
  local m = Peon:NewModule(name, { key = "extra" .. i, title = "Extra " .. i, db = "Peon" .. i .. "DB", defaults = {} })
  fire("ADDON_LOADED", name)
  extra[i] = m:NewLauncher({ icon = "x" })
end
check(ns.starters.extra1 and PeonPanelDB.known.extra3, "spaeter angelegte Starter kommen dazu")
check(#popups == 1, "Hinweis nur einmal")
local rows = {}
for _, c in ipairs(box.cells) do rows[c.y] = (rows[c.y] or 0) + 1 end
local rc, maxInRow = 0, 0
for _, v in pairs(rows) do rc = rc + 1; if v > maxInRow then maxInRow = v end end
check(#box.cells == 5 and maxInRow == 3 and rc == 2, "5 Symbole: 3 Spalten, 2 Reihen")
PeonPanelDB.boxCols = 2
mod:Fire("CHANGED", "boxCols")
rows = {}
for _, c in ipairs(box.cells) do rows[c.y] = true end
rc = 0
for _ in pairs(rows) do rc = rc + 1 end
check(rc == 3, "feste 2 Spalten: 3 Reihen")
PeonPanelDB.boxCols = 8
mod:Fire("CHANGED", "boxCols")
rows = {}
for _, c in ipairs(box.cells) do rows[c.y] = true end
rc = 0
for _ in pairs(rows) do rc = rc + 1 end
check(rc == 1, "mehr Spalten als Symbole: eine Reihe")
PeonPanelDB.boxCols = 0
mod:Fire("CHANGED", "boxCols")

-- Langer Text wird in der Zelle begrenzt
goldText = string.rep("x", 40)
tm.launcher:Refresh()
check(xt.w == 90 and xt.label.w == 90, "Zelle waechst nur bis zur Obergrenze")
goldText = "12,3k g"
ns.ApplyAll()

-- Verschieben und Position
box.frame.left, box.frame.top = 300, 400
box.frame.scripts.OnDragStop(box.frame)
check(PeonPanelDB.boxPos.x == 300 and PeonPanelDB.boxPos.y == 400, "Position gespeichert")
mod:Fire("CHANGED", "boxShow")
check(box.frame.points[1][1] == "TOPLEFT" and box.frame.points[1][4] == 300 and box.frame.points[1][5] == 400, "gespeicherte Position angewendet")

-- Sperren
local started = false
box.frame.StartMoving = function() started = true end
PeonPanelDB.boxLocked = true
box.frame.scripts.OnDragStart(box.frame)
check(not started, "gesperrt: kein Verschieben")
xt.scripts.OnDragStart(xt)
check(box.dragging == nil, "gesperrt: kein Umordnen")
xt.scripts.OnEnter(xt)
check(not table.concat(GameTooltip.lines, "|"):find("Ziehen"), "gesperrt: Tooltip nennt kein Ziehen")
PeonPanelDB.boxLocked = false
box.frame.scripts.OnDragStart(box.frame)
check(started, "entsperrt: verschiebbar")

-- Menue am Panel
box.frame.cy = 950
xt.scripts.OnClick(xt, "RightButton")
check(menuOpened.anchor[2] == box.frame and find(menuOpened.desc.items, "Aus dem Panel entfernen"), "Menue am Panel")

-- ===== Sichtbarkeit =====
PeonPanelDB.boxVis = "combat"
mod:Fire("CHANGED", "boxVis")
check(box.frame.shown, "ausserhalb des Kampfes sichtbar")
combat = true
fire("PLAYER_REGEN_DISABLED")
check(not box.frame.shown and bar.frame.shown, "im Kampf ausgeblendet, Leiste bleibt")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(box.frame.shown, "nach dem Kampf wieder da")
PeonPanelDB.boxVis = "hover"
mod:Fire("CHANGED", "boxVis")
check(box.frame.shown and box.frame.alpha == 0, "nur mit der Maus: unsichtbar")
xt.scripts.OnEnter(xt)
check(box.frame.alpha == 1, "Maus darueber: sichtbar")
xt.scripts.OnLeave(xt)
check(box.frame.alpha == 0, "Maus weg: unsichtbar")
PeonPanelDB.boxVis = "always"
mod:Fire("CHANGED", "boxVis")
check(box.frame.alpha == 1, "immer: sichtbar")

-- Hintergrund
PeonPanelDB.barBg = false
mod:Fire("CHANGED", "barBg")
check(bar.bg.shown == false and box.bg.shown == true, "Hintergrund je Anzeige")
PeonPanelDB.barBg = true
mod:Fire("CHANGED", "barBg")

-- ===== Optionsseite =====
if mod.panel.scripts.OnShow then mod.panel.scripts.OnShow(mod.panel) end
local sc = ns.SymbolControls
check(sc and #sc.list.list.data == 5, "Liste mit allen Modulen")
check(sc.minimap.enabled == false, "ohne Auswahl gesperrt")
sc.select("test")
check(sc.bar.enabled and sc.minimap.enabled and sc.bar.checked and not sc.minimap.checked, "Auswahl zeigt die Werte")
local row
for _, r in ipairs(sc.list.list.data) do if r.key == "test" then row = r end end
check(row.minimap == "-" and row.bar == "Ja" and row.text == "Gold", "Zeile der Liste")
sc.minimap.checked = true
sc.minimap.scripts.OnClick(sc.minimap)
check(PeonTestDB.minimapShow == true and tm.minimapButton.shown and PeonDB.panelHid.test == nil, "Minimap-Button wieder an, Merker weg")
sc.box.checked = false
sc.box.scripts.OnClick(sc.box)
check(PeonPanelDB.entries.test.box == false and xt.shown == false, "Haken Panel")
sc.box.checked = true
sc.box.scripts.OnClick(sc.box)
sc.text.Select("none")
check(PeonPanelDB.entries.test.text == "none", "Auswahlliste Text")
sc.text.Select("gold")
sc.select("peon")
check(sc.minimap.enabled == false and sc.bar.enabled, "Peon hat keinen Minimap-Button")
sc.minimap.checked = true
sc.minimap.scripts.OnClick(sc.minimap)

-- Selbst ausgeblendet: Haken aus zaehlt als eigene Wahl
sc.select("test")
sc.minimap.checked = false
sc.minimap.scripts.OnClick(sc.minimap)
check(PeonTestDB.minimapShow == false and PeonDB.panelHid.test == nil, "selbst ausgeblendet: kein Merker")

-- Standardwerte
PeonPanelDB.barSize = 30
mod:ResetDefaults()
check(PeonPanelDB.barSize == 22 and PeonPanelDB.entries.test and PeonPanelDB.boxPos.x == 300 and PeonPanelDB.hintShown, "Standardwerte: Auswahl, Position und Merker bleiben")
PeonPanelDB.barSize = 99
PeonPanelDB.barVis = "falsch"
SlashCmdList.PEON("panel")
check(out[#out] == "OPEN Peon/Panel", "/peon panel oeffnet die Seite")

-- ===== Einmaliges Ausblenden: Einstellung bleibt nach neuem Laden =====
do
  check(PeonPanelDB.known.test, "Merker fuer spaeteres Laden gesetzt")
  PeonTestDB.minimapShow = true
  ns.AddStarter(tm.launcher)
  check(PeonTestDB.minimapShow == true, "schon bekannt: Button bleibt, wie eingestellt")
end

-- ===== Kern ohne Panel: Button kommt zurueck =====
PeonDB.panelHid = { test = true, selbst = nil }
PeonTestDB.minimapShow = false
loadedAddons.Peon_Panel = nil
Peon._RestoreLaunchers()
check(PeonTestDB.minimapShow == true and tm.minimapButton.shown and PeonDB.panelHid.test == nil, "Panel aus: ausgeblendeter Button zurueck, Merker weg")
PeonTestDB.minimapShow = false
Peon._RestoreLaunchers()
check(PeonTestDB.minimapShow == false, "selbst ausgeblendet: bleibt aus")
PeonDB.panelHid = { spaet = true }
PeonPanelDB.known.spaet = true   -- im Nachbau laeuft Panel weiter mit, es soll hier nicht eingreifen
_G.PeonSpaetDB = { minimapShow = false }
local late = Peon:NewModule("Peon_Spaet", { key = "spaet", title = "Spaet", db = "PeonSpaetDB", defaults = { minimapShow = true } })
fire("ADDON_LOADED", "Peon_Spaet")
local beforeIdx = #Peon.GetLaunchers()
local lateL = late:NewLauncher({ showKey = "minimapShow" })
check(PeonSpaetDB.minimapShow == true and PeonDB.panelHid.spaet == nil and #Peon.GetLaunchers() == beforeIdx + 1, "Starter nach dem Login: auch zurueck")
-- Panel geladen: nichts zurueckholen
loadedAddons.Peon_Panel = true
PeonDB.panelHid = { test = true }
PeonTestDB.minimapShow = false
Peon._RestoreLaunchers()
check(PeonTestDB.minimapShow == false and PeonDB.panelHid.test == true, "Panel geladen: Merker bleibt")

-- ===== Peon-Starter =====
local opened = false
local keepOpen = Peon.OpenOptions
Peon.OpenOptions = function() opened = true end
bp.scripts.OnClick(bp, "LeftButton")
check(opened, "Linksklick auf Peon oeffnet die Einstellungen")
Peon.OpenOptions = keepOpen

local errs = 0 for _, l in ipairs(out) do if l:find("Fehler") and not l:find("^ok ") then errs = errs + 1 end end
check(errs == 1, "nur die eine erwartete Meldung zum kaputten Text")
check(PeonDB.errors == nil or #PeonDB.errors == 0, "keine weiteren gespeicherten Meldungen")
print("ALLE TESTS OK")
