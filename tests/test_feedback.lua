-- Stub-Test fuer Peon_Feedback 0.1.0 (+ Peon/Feedback.lua, API 9)
-- Hier mit KLEINEM Kern-Nachbau, weil der echte Kern nicht vorlag. In Cowork zusaetzlich mit dem
-- echten Kern pruefen (Kern-Nachbau unten durch load("Peon") ersetzen).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function GetLocale() return os.getenv("LOC") or "deDE" end
date, time = os.date, os.time
function UnitName() return "Talia", "Sylan" end
function GetRealmName() return "Classic Beta PvE" end
function UnitFactionGroup() return "Alliance" end
function GetRealZoneText() return "Dun Morogh" end
UISpecialFrames = {}
function tinsert(t, v) table.insert(t, v) end
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = { Version = "0.9.0", Title = "|cff8ccf4dPeon|r" }, Peon_Feedback = TocMeta("Peon_Feedback"),
  Peon_Broker = { Version = "0.19.0", Title = "|cff8ccf4dPeon|r Broker" }, Peon_Tooltip = { Version = "0.5.2", Title = "|cff8ccf4dPeon|r Tooltip" } }
local addons = { "Peon_Tooltip", "Blizzard_Foo", "Peon", "Peon_Broker", "Peon_Feedback" }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function() return true end, GetNumAddOns = function() return #addons end,
  GetAddOnInfo = function(i) return addons[i] end }

-- Rahmen-Stub
local function W()
  local o = { scripts = {}, shown = true, points = {}, text = "" }
  local m = {}
  function m.SetScript(s, n, f) s.scripts[n] = f end
  function m.SetText(s, t) s.text = t end
  function m.GetText(s) return s.text end
  function m.Show(s) s.shown = true; if s.scripts.OnShow then s.scripts.OnShow(s) end end
  function m.Hide(s) s.shown = false end
  function m.IsShown(s) return s.shown end
  function m.GetPoint(s) return "TOPLEFT", nil, "TOPLEFT", 100, -50 end
  function m.CreateFontString() return W() end
  function m.CreateTexture() return W() end
  function m.SetPoint(s, ...) s.points[#s.points+1] = { ... } end
  function m.ClearAllPoints(s) s.points = {} end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") then return function() end end end })
end
local frames = {}
function CreateFrame(kind, name, parent, tmpl) local f = W(); f.kind, f.tmpl = kind, tmpl; frames[#frames+1] = f
  if kind == "DropdownButton" then error("kein neues Menue im Stub") end  -- Rueckfall testen
  return f end
UIParent, GameTooltip, ChatFontNormal = W(), W(), {}
GameTooltip.lines = {}
GameTooltip.AddLine = function(s, t) s.lines[#s.lines+1] = t end
GameTooltip.AddDoubleLine = function(s, a, b) s.lines[#s.lines+1] = a .. "=" .. b end

-- Kleiner Kern-Nachbau (nur was Feedback nutzt)
Peon = { API = 9 }
function Peon.NewLocale() return setmetatable({}, { __index = function(_, k) return k end }) end
local mm
function Peon:NewModule(name, o)
  local mod = { name = name, opts = o, handlers = {}, log = {} }
  function mod:On(e, fn) self.handlers[e] = fn end
  function mod:Fire(e) if self.handlers[e] then self.handlers[e]() end end
  function mod:Dbg(t) self.log[#self.log+1] = t end
  function mod:Call(_, fn, ...) return fn(...) end
  function mod:OpenOptions() print("OPEN options") end
  function mod:NewMinimapButton(b) mm = b end
  function mod:NewOptionsPage() local p = { ctl = {} }
    function p:Column() return {} end function p:Add(_, c) self.ctl[#self.ctl+1] = c return c end
    function p:Header(t) return { t = t } end function p:Check(k, t) return { key = k } end
    function p:Button(t, fn) return { click = fn } end function p:Text(fn) return { fn = fn } end
    function p:AddResetButton() end function p:Register() end
    mod.page = p return p end
  self.mod = mod
  return mod
end
function Peon.NewList(parent, o)
  local l = { frame = W(), opts = o, data = {} }
  function l:SetData(d) self.data = d end function l:Refresh() end
  function l:Select(i) self.sel = i end function l:GetSelected() return self.sel end
  function l:GetItems() return self.data end
  return l
end

local function load(dir) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(dir, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end

-- ===== Kern-Erweiterung API 9 =====
assert(loadfile("Peon/Feedback.lua"))("Peon", {})
check(#Peon.GetFeedbackAreas("Peon") >= 6, "Kern meldet eigene Bereiche")
check(Peon.SetFeedbackAreas("Peon_Broker", { "Radar", "Verkaufen", "Radar", "", 5, "Sonstiges" }), "Broker meldet Bereiche")
local a = Peon.GetFeedbackAreas("Peon_Broker")
check(#a == 3 and a[1] == "Radar" and a[2] == "Verkaufen", "doppelte/leere/falsche Eintraege entfernt")
a[1] = "kaputt"
check(Peon.GetFeedbackAreas("Peon_Broker")[1] == "Radar", "Rueckgabe ist eine Kopie")
check(#Peon.GetFeedbackAreas("Peon_Tooltip") == 0, "ohne Meldung leer")
check(Peon.SetFeedbackAreas(nil, {}) == false and Peon.SetFeedbackAreas("x", nil) == false, "falsche Aufrufe abgewiesen")

-- ===== Modul =====
local ns = load("Peon_Feedback")
local mod = ns.mod
PeonFeedbackDB = { entries = {}, nextId = 1, last = {}, windowPos = {}, minimapShow = true }
mod.db = PeonFeedbackDB
mod:Fire("INIT")
check(mod.page and mm and mm.name == "PeonFeedbackMinimapButton", "Optionsseite + Minimap-Button")
check(mod.opts.slash[1] == "/feedback" and mod.opts.keepOnReset.entries, "Slash und Eintraege bleiben bei Reset")

local mods = ns.Modules()
check(#mods == 4 and mods[1][1] == "Peon" and mods[1][2] == "Peon (Kern)", "Module: Kern zuerst, fremde Addons weg")
check(mods[2][2] == "Broker" and mods[3][2] == "Feedback" and mods[4][2] == "Tooltip", "Titel ohne Farbcode und 'Peon', sortiert")

local ar = ns.Areas("Peon_Broker")
check(#ar == 3 and ar[3][1] == "Sonstiges", "Bereiche + Sonstiges (nicht doppelt)")
check(#ns.Areas("Peon_Tooltip") == 1, "ohne gemeldete Bereiche nur Sonstiges")

-- Fenster
ns.Toggle()
local f = ns.GetFrame()
check(f and f.shown and UISpecialFrames[1] == "PeonFeedbackFrame", "Fenster offen, Escape angemeldet")
local sel = ns.GetSelection()
check(sel.module == "Peon" and sel.kind == "bug" and sel.prio == "mid" and sel.area == "Einstellungsseite", "Startauswahl")

-- Rueckfall-Auswahlliste: Modul durchschalten -> Bereich passt sich an
local dd = ns.GetDropdowns()
dd.module.scripts.OnClick()
check(sel.module == "Peon_Broker" and sel.area == "Radar", "Modulwechsel setzt Bereich des Moduls")
check(dd.module.text == "Broker" and dd.area.text == "Radar", "Anzeige der Auswahllisten")
dd.area.scripts.OnClick(); dd.area.scripts.OnClick()
check(sel.area == "Sonstiges", "Bereich Sonstiges waehlbar")
dd.prio.scripts.OnClick()
check(sel.prio == "high", "Prioritaet durchschalten")
dd.kind.scripts.OnClick()
check(sel.kind == "improve", "Art durchschalten")

-- Speichern
ns.GetEditBox():SetText("   ")
ns.Save()
check(#PeonFeedbackDB.entries == 0, "leerer Text wird nicht gespeichert")
ns.GetEditBox():SetText("  Radar piept doppelt  ")
ns.Save()
local e = PeonFeedbackDB.entries[1]
check(e and e.id == 1 and e.module == "Peon_Broker" and e.kind == "improve" and e.area == "Sonstiges" and e.prio == "high", "Eintrag gespeichert")
check(e.text == "Radar piept doppelt" and e.char == "Talia Sylan" and e.market == "Classic Beta PvE / Alliance", "Text, Charakter, Markt")
check(e.zone == "Dun Morogh" and e.ver == "0.19.0" and type(e.t) == "number", "Zone, Version, Zeit")
check(ns.GetEditBox():GetText() == "", "Textfeld danach leer")
check(PeonFeedbackDB.last.module == "Peon_Broker" and PeonFeedbackDB.last.prio == "high", "Auswahl gemerkt")
check(#ns.GetList().data == 1, "Liste zeigt Eintrag")

-- Wiederoeffnen uebernimmt letzte Auswahl
ns.Toggle(); ns.Toggle()
check(sel.module == "Peon_Broker" and sel.area == "Sonstiges", "letzte Auswahl beim Oeffnen")

-- Spaltenformat
local cols = ns.GetList().opts.columns
check(cols[3].format("bug"):find("Fehler"), "Art mit Farbe")
check(cols[6].format(("x"):rep(60)):sub(-3) == "…", "langer Text gekuerzt")

-- Tooltip der Zeile
ns.GetList().opts.onEnter(nil, e, W())
check(GameTooltip.lines[3] == "Radar piept doppelt", "Tooltip zeigt ganzen Text")

-- Zweiter Eintrag, Zaehler
ns.GetEditBox():SetText("Noch was"); ns.Save()
local n, high = ns.Counts()
check(n == 2 and high == 2 and PeonFeedbackDB.entries[2].id == 2, "Zaehler und fortlaufende Nummer")
local tt = { AddLine = function(s, t) s.t = t end }
mm.onTooltip(mod, tt)
check(tt.t:find("2"), "Minimap-Tooltip mit Anzahl")

-- Loeschen
ns.DeleteSelected()
check(#PeonFeedbackDB.entries == 2, "ohne Auswahl wird nichts geloescht")
ns.GetList():Select(PeonFeedbackDB.entries[1])
ns.DeleteSelected()
check(#PeonFeedbackDB.entries == 1 and PeonFeedbackDB.entries[1].id == 2, "Auswahl geloescht")

-- Knoepfe unten (0.2.0): Loeschen links, Bearbeiten Mitte, OK rechts
check(ns.deleteButton.points[1][1] == "BOTTOMLEFT" and ns.editButton.points[1][1] == "BOTTOM"
  and ns.okButton.points[1][1] == "BOTTOMRIGHT", "Loeschen links, Bearbeiten Mitte, OK rechts")
-- Bearbeiten
ns.GetList():Select(nil)
ns.EditSelected()
check(not ns.editFrame or not ns.editFrame.shown, "Bearbeiten ohne Auswahl oeffnet nichts")
ns.GetList():Select(PeonFeedbackDB.entries[1])
ns.EditSelected()
local ed, edText = ns.GetEdit()
check(ns.editFrame.shown and ed.id == 2 and edText:GetText() == "Noch was", "Bearbeiten-Fenster mit Eintrag")
edText:SetText("  ")
ns.SaveEdit()
check(PeonFeedbackDB.entries[1].text == "Noch was" and ns.editFrame.shown, "leerer Text beim Bearbeiten abgewiesen")
edText:SetText("Noch was, geaendert")
ed.kind, ed.prio = "idea", "low"
ns.SaveEdit()
local e2 = PeonFeedbackDB.entries[1]
check(e2.text == "Noch was, geaendert" and e2.kind == "idea" and e2.prio == "low" and e2.edited and e2.id == 2, "Eintrag geaendert")
check(not ns.editFrame.shown, "Bearbeiten-Fenster schliesst nach Speichern")
ns.okButton.scripts.OnClick()
check(not f.shown, "OK schliesst das Fenster")
ns.Toggle()

-- Fensterposition
f.scripts.OnDragStop(f)
check(PeonFeedbackDB.windowPos.point == "TOPLEFT" and PeonFeedbackDB.windowPos.x == 100, "Position gemerkt")

-- Slash / Minimap
mod.opts.onSlash(mod, "optionen", "")
check(out[#out] == "OPEN options", "/feedback optionen")
mm.onClick(mod, "LeftButton")
check(not f.shown, "Minimap-Linksklick schaltet Fenster")

-- Ohne API 9: nur Sonstiges
Peon.GetFeedbackAreas = nil
check(#ns.Areas("Peon_Broker") == 1, "ohne API 9 nur Sonstiges")

print("ALLE TESTS OK")
