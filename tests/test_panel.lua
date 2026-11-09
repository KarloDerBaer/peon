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
  function m.GetStringWidth(s) return #((s.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) * 6 end
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
  function m.SetVertexColor(s, ...) s.vertex = { ... } end
  function m.SetTexCoord(s, ...) s.coord = { ... } end
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
UIParent.w = 1000
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
local NewRoot
function NewRoot()
  local r = { items = {} }
  function r:CreateTitle(t) table.insert(self.items, { kind = "title", text = t }) end
  function r:CreateDivider() table.insert(self.items, { kind = "divider" }) end
  function r:CreateRadio(t, isSel, setSel, v) table.insert(self.items, { kind = "radio", text = t, isSel = isSel, setSel = setSel, value = v }) end
  function r:CreateButton(t, fn) local sub = NewRoot() table.insert(self.items, { kind = "button", text = t, fn = fn, sub = sub }) return sub end
  function r:CreateCheckbox(t, isSel, setSel) table.insert(self.items, { kind = "check", text = t, isSel = isSel, setSel = setSel }) end
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

-- Nachbau fuer die allgemeinen Eintraege, sie sind hier ausgeblendet (eigene Tests in test_panel_info.lua)
function UnitGUID() return "Player-1" end
function time() return 1000000 end
function UnitLevel() return 10 end
function UnitXP() return 100 end
function UnitXPMax() return 1000 end
function IsInGuild() return false end
C_FriendList = { ShowFriends = function() end, GetNumOnlineFriends = function() return 0 end, GetNumFriends = function() return 0 end }
C_Map = { GetBestMapForUnit = function() return nil end }
function GetZoneText() return "Zone" end
function GetSubZoneText() return "" end
function GetInventoryItemDurability() return nil end

-- ===== Kern =====
loadToc("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
check(Peon.API >= 15, "API 15 oder neuer")
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
-- Gespeicherte Einstellungen wie vor 0.4.0, damit die Pruefungen der Anzeige gleich bleiben.
-- Die neuen Standardwerte prueft test_panel_info.lua.
PeonPanelDB = { barWidth = 60, barGap = 12, style = "tooltipDark", boxShow = false, boxCols = 0, boxSize = 28,
  boxVis = "always", bgColor = { 0.05, 0.07, 0.10, 0.85 }, lineColor = { 0.70, 0.65, 0.50, 1 },
  barOrder = {}, boxOrder = {}, entries = { peon = { bar = true, box = true, text = "none" } } }
local ns = loadToc("Peon_Panel", "Peon_Panel")
fire("ADDON_LOADED", "Peon_Panel")
local mod = ns.mod
check(mod.initialized and mod.page, "Modul + Optionsseite")
-- Allgemeine Eintraege heraus, hier geht es um Leiste und Panel
local INFO_COUNT = 0
local function WithoutInfos(list)
  for i = #list, 1, -1 do if ns.InfoDef[list[i]] then table.remove(list, i) end end
end
for key in pairs(ns.InfoDef) do
  INFO_COUNT = INFO_COUNT + 1
  PeonPanelDB.entries[key].bar = false
  PeonPanelDB.entries[key].box = false
end
WithoutInfos(PeonPanelDB.barOrder)
WithoutInfos(PeonPanelDB.boxOrder)
check(INFO_COUNT == 14, "14 allgemeine Eintraege")
ns.ApplyAll()
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
check(#tickers == 2 and tickers[1].sec == 60 and tickers[2].sec == 0.5, "Texte einmal je Minute, Takt fuer laufende Eintraege")

-- ===== Leiste =====
local bar, box = ns.surfaces.bar, ns.surfaces.box
check(bar.frame.shown and not box.frame.shown, "Leiste an, Panel aus")
check(bar.frame.points[1][1] == "TOP" and bar.frame.points[1][3] == "TOP" and bar.frame.points[1][4] == 0 and bar.frame.points[1][5] == 0, "Leiste oben in der Mitte, direkt am Rand")
check(bar.frame.w == 600 and bar.frame.h == 26, "Breite 60 Prozent, Hoehe aus der Symbolgroesse")
local bt, bp = bar.buttons.test, bar.buttons.peon
check(bt.icon.tex == "icon-test" and bt.icon.colored, "Symbol und Faerbung")
local LABEL = "|cffe8c95fTest:|r "
check(bt.label.text == LABEL .. "12,3k g" and bt.label.shown, "Modulname und Text neben dem Symbol")
check(bp.label.shown == false, "Peon ohne Text")
check(bt.points[1][4] == 12, "Bereich links beginnt hinter der runden Ecke")
check(bp.points[1][4] == 600 - 12 - 18, "Peon anfangs rechts, am rechten Ende")
check(bt.w == 18 + 3 + 78 and bt.h == 18, "Breite nach Symbol und Text")

-- Breite waechst nur
goldText = "9 g"
tm.launcher:Refresh()
check(bt.label.text == LABEL .. "9 g" and bt.w == 99, "kuerzerer Text: Platz bleibt")
goldText = "123.456,7k g"
tm.launcher:Refresh()
check(bt.w == 18 + 3 + 108, "laengerer Text: Platz waechst")
goldText = "12,3k g"
tickers[1].fn()
check(bt.label.text == LABEL .. "12,3k g" and bt.w == 129, "Minutentakt aktualisiert den Text")
ns.ApplyAll()
check(bt.w == 99, "Umstellen setzt die Breite zurueck")

-- Breite, Modulname, Schalter
PeonPanelDB.barWidth = 30
mod:Fire("CHANGED", "barWidth")
check(bar.frame.w == 300, "Breite einstellbar")
UIParent.w = 800
fire("DISPLAY_SIZE_CHANGED")
check(bar.frame.w == 240, "neue Bildschirmbreite wird uebernommen")
UIParent.w = 1000
PeonPanelDB.barWidth = 1
mod:Fire("CHANGED", "barWidth")
check(bar.frame.w == 12 + 99 + 18 + 18 + 18 + 12, "Inhalt passt nicht: Leiste wird breiter als eingestellt")
PeonPanelDB.barWidth = 60
mod:Fire("CHANGED", "barWidth")
PeonPanelDB.barLabels = false
mod:Fire("CHANGED", "barLabels")
check(bt.label.text == "12,3k g", "Modulname abschaltbar")
PeonPanelDB.barLabels = true
mod:Fire("CHANGED", "barLabels")
PeonPanelDB.barShow = false
mod:Fire("CHANGED", "barShow")
check(not bar.frame.shown and bt.shown == false, "Haken aus blendet die Leiste aus")
PeonPanelDB.barShow = true
mod:Fire("CHANGED", "barShow")
check(bar.frame.shown and bt.shown, "wieder an")

-- Bereiche
local function Starts(...) return ns.ZoneStarts(600, ...) end
local zl, zc, zr = Starts(100, 60, 50)
check(zl == 12 and zc == 270 and zr == 538, "Mitte bleibt mittig")
zl, zc, zr = Starts(280, 60, 50)
check(zc == 12 + 280 + 18, "Mitte weicht dem linken Bereich aus")
zl, zc, zr = Starts(50, 60, 280)
check(zr == 308 and zc == 308 - 18 - 60, "Mitte weicht dem rechten Bereich aus")
check(ns.ZoneAt(600, 100) == "left" and ns.ZoneAt(600, 300) == "center" and ns.ZoneAt(600, 500) == "right", "Drittel der Leiste")
ns.SetSide(tm.launcher, "center")
check(PeonPanelDB.entries.test.side == "center" and bt.points[1][4] == (600 - 99) / 2, "Bereich Mitte")
ns.SetSide(tm.launcher, "right")
check(bt.points[1][4] == 600 - 12 - 18 - 12 - 99 and bp.points[1][4] == 600 - 12 - 18, "Bereich rechts: nebeneinander bis zum Rand")
ns.SetSide(tm.launcher, "left")

-- Anzeige je Eintrag
ns.SetShow(tm.launcher, "icon")
check(bt.label.shown == false and bt.icon.shown and bt.w == 18, "nur Symbol")
ns.SetShow(tm.launcher, "text")
check(bt.label.shown and bt.icon.shown == false and bt.w == 78, "nur Text")
ns.SetText(tm.launcher, "none")
check(bt.icon.shown and bt.w == 18, "nur Text, aber kein Text gewaehlt: Symbol bleibt")
ns.SetText(tm.launcher, "gold")
ns.SetShow(tm.launcher, "both")
check(bt.icon.shown and bt.label.shown and bt.w == 99, "Symbol und Text")

-- Aussehen
local function HasCornerFile(s, file, n)
  local c = 0
  for _, t in ipairs(s.bg.fillCorners) do if t.tex:find(file, 1, true) then c = c + 1 end end
  for _, t in ipairs(s.bg.lineCorners) do if t.tex:find(file, 1, true) then c = c + 1 end end
  return c == n
end
check(bar.bg.used == "plain", "ohne Blizzard-Rahmen bleibt es bei den eigenen Stuecken")
check(HasCornerFile(bar, "corner_fill.tga", 2) and HasCornerFile(bar, "corner_line.tga", 2), "Leiste: nur zwei runde Ecken")
check(HasCornerFile(box, "corner_fill.tga", 4) and HasCornerFile(box, "corner_line.tga", 4), "Panel: vier runde Ecken")
PeonPanelDB.bgColor[1], PeonPanelDB.bgColor[4] = 0.5, 0.25
mod:Fire("CHANGED", "bgColor")
check(bar.bg.fillRects[1].color[1] == 0.5 and bar.bg.fillRects[1].color[4] == 0.25, "Hintergrundfarbe auf den Flaechen")
check(bar.bg.fillCorners[1].vertex[1] == 0.5 and bar.bg.fillCorners[1].vertex[4] == 0.25, "Hintergrundfarbe auf den Ecken")
check(box.bg.lineRects[1].color[1] == PeonPanelDB.lineColor[1] and bar.bg.lineCorners[1].vertex[1] == PeonPanelDB.lineColor[1], "Randfarbe auf beiden Anzeigen")
PeonPanelDB.bgColor[1], PeonPanelDB.bgColor[4] = 0.05, 0.85
mod:Fire("CHANGED", "bgColor")

-- Eckbilder: die untere linke Ecke, aussen durchsichtig
local function ReadTga(file)
  local f = assert(io.open("Peon_Panel/Media/" .. file, "rb"))
  local d = f:read("*a")
  f:close()
  return d
end
local function Alpha(d, x, y) return d:byte(18 + (y * 32 + x) * 4 + 4) end
for _, file in ipairs({ "corner_fill.tga", "corner_line.tga" }) do
  local d = ReadTga(file)
  check(#d == 18 + 32 * 32 * 4 and d:byte(3) == 2 and d:byte(13) == 32 and d:byte(15) == 32 and d:byte(17) == 32 and d:byte(18) == 8, file .. ": Format wie die Bilder von Broker")
  check(Alpha(d, 0, 0) == 0, file .. ": aussen an der Ecke durchsichtig")
end
local df, dl = ReadTga("corner_fill.tga"), ReadTga("corner_line.tga")
check(Alpha(df, 31, 31) == 255 and Alpha(dl, 31, 31) == 0, "innen: Flaeche voll, Linie frei")
check(Alpha(df, 31, 0) == 255 and Alpha(dl, 31, 0) == 255 and Alpha(df, 0, 31) == 255 and Alpha(dl, 0, 31) == 255, "Rand trifft die Kanten an beiden Enden")

-- Alte Einstellungen
local old = { barPos = "none", barX = 5, barY = 6, barSize = 22 }
mod.opts.migrate(mod, old)
check(old.barShow == false and old.barPos == nil and old.barX == nil and old.barY == nil and old.barSize == nil, "Position Aus: Leiste bleibt aus, alte Werte weg, alter Standard weg")
old = { barPos = "BOTTOMRIGHT", barSize = 30 }
mod.opts.migrate(mod, old)
check(old.barShow == nil and old.barPos == nil and old.barSize == 30, "andere Stelle: nach oben, eigene Groesse bleibt")
old = { barSize = 22 }
mod.opts.migrate(mod, old)
check(old.barSize == 22, "schon umgestellt: eigene Wahl 22 bleibt")

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
check(a[1] == "TOPLEFT" and a[2] == bar.frame and a[3] == "BOTTOMLEFT" and a[4] == 12 and a[5] == -2, "obere Haelfte: Menue unter der Leiste")
local items = menuOpened.desc.items
-- sucht auch in Untermenues
local function find(list, text)
  for _, it in ipairs(list) do
    if it.text == text then return it end
    local hit = it.sub and find(it.sub.items, text)
    if hit then return hit end
  end
end
check(items[1].kind == "title" and items[1].text == "Test", "Titel")
check(find(items, "Eigener Eintrag"), "Eintraege des Moduls")
local radioGold, radioNone = find(items, "Gold"), find(items, "Kein Text")
check(radioGold.isSel("gold") and not radioNone.isSel("none"), "gewaehlter Text markiert")
radioNone.setSel("none")
check(PeonPanelDB.entries.test.text == "none" and bt.label.shown == false, "Text im Menue abwaehlen")
radioGold.setSel("gold")
check(bt.label.text == LABEL .. "12,3k g", "Text im Menue waehlen")
find(items, "Nur Symbol").setSel("icon")
check(PeonPanelDB.entries.test.show == "icon" and find(items, "Nur Symbol").isSel("icon"), "Anzeige im Menue")
find(items, "Symbol und Text").setSel("both")
find(items, "Rechts").setSel("right")
check(PeonPanelDB.entries.test.side == "right" and find(items, "Rechts").isSel("right"), "Bereich im Menue")
find(items, "Links").setSel("left")
-- Untermenue (ab 0.3.0): oben nur Modul, Untermenue und Optionen
local subBtn = find(items, "Leiste")
check(subBtn and subBtn.sub and subBtn.sub.items[1].text == "Text", "Einstellungen der Leiste im Untermenue")
for _, it in ipairs(items) do check(it.text ~= "Kein Text" and it.text ~= "Rechts", "oben keine Einstellungen der Leiste") end
check(find(subBtn.sub.items, "Von der Leiste entfernen") and items[#items].text == "Optionen von Test", "Entfernen im Untermenue, Optionen oben")
-- Beschriftung je Eintrag
local labelCheck = find(items, "Beschriftung „Test:“")
check(labelCheck and labelCheck.isSel() == true, "Beschriftung an als Standard")
labelCheck.setSel()
check(PeonPanelDB.entries.test.label == false and bt.label.text == "12,3k g", "Beschriftung aus: nur Symbol und Wert")
labelCheck.setSel()
check(PeonPanelDB.entries.test.label == true and bt.label.text == LABEL .. "12,3k g", "Beschriftung wieder an")
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
cursorX, cursorY = 100 + 590, 700 - 10
bar.frame.scripts.OnUpdate(bar.frame)
check(bar.marker.shown and bar.marker.points[1][4] == bp.points[1][4] + 18 + 1, "Markierung zeigt die Zielstelle im anderen Bereich")
bt.scripts.OnDragStop(bt)
check(table.concat(PeonPanelDB.barOrder, ",") == "peon,test", "Loslassen ordnet um")
check(PeonPanelDB.entries.test.side == "right", "Loslassen im rechten Drittel: Bereich rechts")
check(not bar.marker.shown and bt.alpha == 1 and bar.frame.scripts.OnUpdate == nil, "Ziehen beendet")
check(bp.points[1][4] == 600 - 12 - 18 - 12 - 99 and bt.points[1][4] == 600 - 12 - 99, "Symbole sind umgerueckt")
check(table.concat(PeonPanelDB.boxOrder, ",") == "test,peon", "Panel hat eine eigene Reihenfolge")
-- in einen leeren Bereich
bt.scripts.OnDragStart(bt)
cursorX = 100 + 300
bar.frame.scripts.OnUpdate(bar.frame)
check(bar.marker.shown and bar.marker.points[1][4] == 300, "leerer Bereich: Markierung in seiner Mitte")
bt.scripts.OnDragStop(bt)
check(PeonPanelDB.entries.test.side == "center" and bt.points[1][4] == (600 - 99) / 2, "leerer Bereich: Symbol zieht um")
bt.scripts.OnDragStart(bt)
cursorX = 100 + 50
bar.frame.scripts.OnUpdate(bar.frame)
check(bar.marker.points[1][4] == 12, "leerer Bereich links: Markierung am Anfang")
bt.scripts.OnDragStop(bt)
check(PeonPanelDB.entries.test.side == "left" and bt.points[1][4] == 12, "wieder links")
-- innerhalb eines Bereichs
ns.SetSide(ns.starters.peon, "left")
check(bp.points[1][4] == 12 and bt.points[1][4] == 12 + 18 + 12, "Reihenfolge gilt im Bereich")
bp.scripts.OnDragStart(bp)
cursorX = 100 + 12 + 18 + 12 + 90
bp.scripts.OnDragStop(bp)
check(table.concat(PeonPanelDB.barOrder, ",") == "test,peon" and bt.points[1][4] == 12 and bp.points[1][4] == 12 + 99 + 12, "umgeordnet im selben Bereich")
ns.SetSide(ns.starters.peon, "right")

-- Menue auf einer freien Stelle
cursorX, cursorY = 100 + 250, 700 - 10
menuOpened = nil
bar.frame.scripts.OnMouseUp(bar.frame, "LeftButton")
check(menuOpened == nil, "Linksklick auf eine freie Stelle: kein Menue")
bar.frame.scripts.OnMouseUp(bar.frame, "RightButton")
a = menuOpened.anchor
check(menuOpened.owner == bar.frame and a[3] == "BOTTOMLEFT" and a[4] == 250, "Rechtsklick: Menue unter der Leiste an der Maus")
items = menuOpened.desc.items
check(items[1].text == "Leiste" and find(items, "Peon").kind == "check" and find(items, "Test").kind == "check", "alle Module zum Anhaken")
local posPeon, posTest
for i, it in ipairs(items) do
  if it.text == "Peon" then posPeon = i elseif it.text == "Test" then posTest = i end
end
check(posPeon < posTest, "nach Name sortiert")
check(find(items, "Optionen von Panel"), "Weg zu den Optionen")
local mt = find(items, "Test")
check(mt.isSel(), "Haken zeigt den Stand")
mt.setSel()
check(PeonPanelDB.entries.test.bar == false and bt.shown == false and not mt.isSel(), "abhaken entfernt von der Leiste")
find(items, "Peon").setSel()
check(bar.frame.shown and #bar.cells == 0, "ohne Eintraege bleibt die Leiste da")
bar.frame.scripts.OnMouseUp(bar.frame, "RightButton")
check(menuOpened.owner == bar.frame, "auch leer gibt es das Menue")
find(menuOpened.desc.items, "Peon").setSel()
find(menuOpened.desc.items, "Test").setSel()
check(PeonPanelDB.entries.test.bar == true and bt.shown and bp.shown, "wieder angehakt")

-- ===== Panel =====
PeonPanelDB.boxShow = true
mod:Fire("CHANGED", "boxShow")
check(box.frame.shown and box.frame.points[1][1] == "TOPLEFT" and box.frame.points[1][3] == "TOPLEFT", "Panel an, anfangs oben links unter der Leiste")
local xt, xp = box.buttons.test, box.buttons.peon
check(xt.label.text == LABEL .. "12,3k g" and xt.label.points[1][1] == "TOP" and xt.label.points[1][3] == "BOTTOM", "Text mit Beschriftung unter dem Symbol")
check(xt.w == xp.w and xt.h == 28 + 14, "alle Zellen gleich gross")
check(xt.points[1][4] == 8 and xt.points[1][5] == -8, "Abstand zu den runden Ecken")
ns.SetShow(tm.launcher, "text")
check(xt.icon.shown and xt.label.shown and not bt.icon.shown, "nur Text auf der Leiste aendert das Panel nicht")
ns.SetShow(tm.launcher, "both")
box.frame.cy = 950
cursorX, cursorY = 110, 690
box.frame.scripts.OnMouseUp(box.frame, "RightButton")
check(menuOpened.owner == box.frame and menuOpened.desc.items[1].text == "Panel", "Menue auf einer freien Stelle des Panels")
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
check(xt.w == 150 and xt.label.w == 150, "Zelle waechst nur bis zur Obergrenze")
goldText = "12,3k g"
ns.ApplyAll()

-- ===== Leiste und Panel getrennt einstellbar (0.3.0) =====
local L1 = tm.launcher
ns.SetText(L1, "none", "box")
check(xt.label.shown == false and bt.label.shown and PeonPanelDB.entries.test.text == "gold", "Text nur im Panel aus, Leiste behaelt ihn")
ns.SetText(L1, "gold", "box")
ns.SetShow(L1, "icon", "box")
check(xt.label.shown == false and bt.label.shown, "nur Symbol im Panel, Leiste zeigt weiter Text")
ns.SetShow(L1, "both", "box")
ns.SetLabel(L1, false, "box")
check(xt.label.text == "12,3k g" and bt.label.text == LABEL .. "12,3k g", "Beschriftung nur im Panel aus")
ns.SetLabel(L1, true, "box")
PeonPanelDB.boxLabels = false
mod:Fire("CHANGED", "boxLabels")
check(xt.label.text == "12,3k g", "Hauptschalter Beschriftung im Panel")
PeonPanelDB.boxLabels = true
mod:Fire("CHANGED", "boxLabels")
-- Menue des Panels stellt das Panel ein
xt.scripts.OnClick(xt, "RightButton")
local boxItems = menuOpened.desc.items
check(find(boxItems, "Panel") and find(boxItems, "Panel").sub, "Panel: Untermenue Panel")
find(boxItems, "Nur Symbol").setSel("icon")
check(PeonPanelDB.entries.test.boxShow == "icon" and ns.ShowOf("test") == "both", "Menue im Panel aendert nur das Panel")
find(boxItems, "Symbol und Text").setSel("both")

-- Text rechts neben dem Symbol
PeonPanelDB.boxLayout = "right"
mod:Fire("CHANGED", "boxLayout")
check(xt.label.points[1][1] == "LEFT" and xt.label.points[1][3] == "RIGHT" and xt.h == 28, "Text rechts neben dem Symbol")
check(xt.points[1][4] == xp.points[1][4] and xt.points[1][5] ~= xp.points[1][5], "rechts: eine Spalte untereinander")
PeonPanelDB.boxLayout = "below"
mod:Fire("CHANGED", "boxLayout")

-- Panel aufklappbar
PeonPanelDB.boxPos.x, PeonPanelDB.boxPos.y = 300, 400
PeonPanelDB.boxVis = "fold"
mod:Fire("CHANGED", "boxVis")
local nAll = #ns.VisibleStarters("box")
check(nAll > 1 and #box.cells == 1 and box.frame.shown and box.frame.alpha == 1, "zugeklappt: nur der erste Eintrag")
local firstKey = box.cells[1].key
box.frame.scripts.OnEnter(box.frame)
check(#box.cells == nAll and box.cells[1].key == firstKey, "Maus darueber: alles aufgeklappt")
box.frame.scripts.OnLeave(box.frame)
check(#box.cells == 1, "Maus weg: wieder zu")
check(box.frame.points[1][1] == "TOPLEFT" and box.frame.points[1][5] == 400, "nach unten: oben links fest")
PeonPanelDB.boxFoldDir = "up"
mod:Fire("CHANGED", "boxFoldDir")
local foldH = box.frame.h
check(box.frame.points[1][1] == "BOTTOMLEFT" and box.frame.points[1][5] == 400 - foldH, "nach oben: unten fest, erster Eintrag bleibt stehen")
box.frame.scripts.OnEnter(box.frame)
local ys = {}
for _, c in ipairs(box.cells) do ys[c.key] = c.y end
local firstLowest = true
for k, y in pairs(ys) do if k ~= firstKey and y >= ys[firstKey] then firstLowest = false end end
check(firstLowest and box.frame.points[1][5] == 400 - foldH, "nach oben: die anderen darueber")
box.frame.scripts.OnLeave(box.frame)
PeonPanelDB.boxFoldDir = "left"
mod:Fire("CHANGED", "boxFoldDir")
box.frame.scripts.OnEnter(box.frame)
local xs = {}
for _, c in ipairs(box.cells) do xs[c.key] = c.x end
local firstRight = true
for k, x in pairs(xs) do if k ~= firstKey and x >= xs[firstKey] then firstRight = false end end
check(firstRight and box.frame.points[1][1] == "TOPRIGHT", "nach links: die anderen links daneben")
box.frame.scripts.OnLeave(box.frame)
PeonPanelDB.boxFoldDir = "down"
PeonPanelDB.boxVis = "always"
wipe(PeonPanelDB.boxPos)
mod:Fire("CHANGED", "boxVis")
check(#box.cells == nAll, "wieder immer offen")

-- Leiste zweizeilig
PeonPanelDB.barRows = 2
mod:Fire("CHANGED", "barRows")
local rowH = math.max(PeonPanelDB.barHeight, PeonPanelDB.barSize + 4)
check(bar.frame.h == 2 * rowH, "zwei Zeilen: doppelt so hoch")
ns.SetRow(L1, 2)
local yTest, yPeon
for _, c in ipairs(bar.cells) do if c.key == "test" then yTest = c.y elseif c.key == "peon" then yPeon = c.y end end
check(PeonPanelDB.entries.test.row == 2 and yTest > yPeon and yTest >= rowH, "Eintrag in der unteren Zeile")
bt.scripts.OnClick(bt, "RightButton")
local rowItem = find(menuOpened.desc.items, "Obere Zeile")
check(rowItem and find(menuOpened.desc.items, "Untere Zeile").isSel(2), "Zeile im Menue")
rowItem.setSel(1)
check(ns.RowOf("test") == 1, "Zeile im Menue gewechselt")
ns.SetRow(L1, 2)
PeonPanelDB.barRows = 1
mod:Fire("CHANGED", "barRows")
check(bar.frame.h == rowH and ns.RowOf("test") == 1, "eine Zeile: alles oben, Wahl bleibt gespeichert")
check(PeonPanelDB.entries.test.row == 2, "Wahl der Zeile bleibt fuer spaeter")
PeonPanelDB.entries.test.row = nil

-- Leiste aufklappbar: nur die Mitte der oberen Zeile, ohne Symbole
local keepSide = PeonPanelDB.entries.test.side
ns.SetSide(L1, "center")
PeonPanelDB.barRows = 2
PeonPanelDB.barVis = "fold"
mod:Fire("CHANGED", "barVis")
check(bt.shown and not bt.icon.shown and bt.label.shown and not bp.shown, "zugeklappt: nur die Mitte, Text ohne Symbol")
check(bar.frame.h == rowH and bar.frame.w < 300, "zugeklappt: einzeilig und schmal")
bar.frame.scripts.OnEnter(bar.frame)
check(bp.shown and bt.icon.shown and bar.frame.h == 2 * rowH, "Maus darueber: ganze Leiste, zweizeilig")
bar.frame.scripts.OnLeave(bar.frame)
check(not bp.shown and bar.frame.h == rowH, "Maus weg: wieder zu")
PeonPanelDB.entries.test.text = "none"
mod:Fire("CHANGED", "entries")
check(bt.shown and bt.icon.shown, "ohne Text bleibt das Symbol")
PeonPanelDB.entries.test.text = "gold"
PeonPanelDB.barVis = "always"
PeonPanelDB.barRows = 1
PeonPanelDB.entries.test.side = keepSide
mod:Fire("CHANGED", "barVis")
check(bp.shown and bt.icon.shown, "Leiste wieder immer offen")

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
check(sc and #sc.list.list.data == 5 + INFO_COUNT, "Liste mit allen Modulen")
check(sc.minimap.enabled == false, "ohne Auswahl gesperrt")
sc.select("test")
check(sc.bar.enabled and sc.minimap.enabled and sc.bar.checked and not sc.minimap.checked, "Auswahl zeigt die Werte")
local row
for _, r in ipairs(sc.list.list.data) do if r.key == "test" then row = r end end
check(row.minimap == "-" and row.bar == "Ja" and row.text == "Gold" and row.side == "Links", "Zeile der Liste")
sc.side.Select("center")
check(PeonPanelDB.entries.test.side == "center", "Auswahlliste Bereich")
sc.side.Select("left")
sc.show.Select("icon")
check(PeonPanelDB.entries.test.show == "icon", "Auswahlliste Anzeige")
sc.show.Select("both")
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
PeonPanelDB.entries.test.side = "right"
mod:ResetDefaults()
check(PeonPanelDB.entries.test.side == "right", "Standardwerte: Bereich bleibt")
check(PeonPanelDB.barSize == 18 and PeonPanelDB.entries.test and PeonPanelDB.boxPos.x == 300 and PeonPanelDB.hintShown, "Standardwerte: Auswahl, Position und Merker bleiben")
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
