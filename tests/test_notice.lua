-- Peon-Kern: einmalige Hinweise (Notice.lua, API 20, ab 0.20.0).
-- Prueft: Anmelden (Kern und Modul, id Pflicht, keine Doppelten), Anzeige nach dem Einloggen mit Verzoegerung,
-- nie im Kampf (spaeter erneut), einmal je Konto, spaeter gemeldete Hinweise, /peon neu zeigt alle, Fenstertexte.
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
timers = {}
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
local ns = load("Peon", { "Locales.lua", "Core.lua", "Module.lua", "Options.lua", "UIKit.lua", "Notice.lua", "Slash.lua" })
PeonDB = {}
Peon.db = PeonDB
local reported = {}
Peon.ReportCoreError = function(where, err) reported[#reported + 1] = where .. ": " .. tostring(err) end
local N = ns.Notice
check(N and Peon.AddNotice and Peon.ModulePrototype.AddNotice, "Notice.lua geladen")
check(Peon.API >= 20, "Kern-API 20")
local toc = io.open("Peon/Peon.toc"):read("*a")
check(toc:find("UIKit.lua.-Notice.lua.-Slash.lua"), "Notice.lua in der TOC nach UIKit und vor Slash")

local function runTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end

-- 1. Anmelden
check(Peon.AddNotice({ title = "ohne id" }) == false, "ohne id abgelehnt")
check(Peon.AddNotice("x") == false, "falscher Typ abgelehnt")
local mod = Peon:NewModule("Peon_Broker", { key = "broker", title = "|cff8ccf4dPeon|r Broker" })
check(mod:AddNotice({ id = "umbau", date = "12.11.2026", title = "Broker neu", text = { "Absatz 1", "Absatz 2" } }), "Modul meldet Hinweis")
check(mod:AddNotice({ id = "umbau", title = "doppelt" }) == false, "gleiche id nur einmal")
check(N.byId["broker:umbau"] and N.byId["broker:umbau"].from == "Peon Broker", "id mit Modulschluessel, Absender ohne Farbcodes")
check(Peon.AddNotice({ id = "kern-1", title = "Kern", text = "Ein Text" }), "Kern meldet Hinweis")
check(#N.byId["kern-1"].text == 1 and N.byId["kern-1"].from == "Peon", "Text als Liste, Absender Peon")
check(#timers == 0 and not N.frame, "vor dem Einloggen nichts gezeigt")

-- 2. Nach dem Einloggen: Verzoegerung, nie im Kampf
Peon.loggedIn = true
N.OnLogin()
check(#timers == 1 and not N.frame, "erst nach Verzoegerung")
combat = true
runTimers()
check(not N.frame and #timers == 1, "im Kampf nicht gezeigt, neuer Versuch geplant")
check(not (PeonDB.noticesSeen or {})["broker:umbau"], "im Kampf nicht als gesehen gemerkt")
combat = false
runTimers()
local f = N.frame
check(f and f.shown and f.name == "PeonNoticeFrame", "Fenster nach dem Kampf gezeigt")
check(#f.shownList == 2 and f.shownList[1].id == "broker:umbau", "beide Hinweise in Reihenfolge")
local texts = {}
for _, p in ipairs(f.parts) do if p.shown then texts[#texts + 1] = p.txt end end
check(texts[1] == "Broker neu" and texts[2]:find("Peon Broker") and texts[2]:find("12.11.2026") and texts[3] == "Absatz 1" and texts[4] == "Absatz 2", "Titel, Absender mit Datum, Absaetze: " .. table.concat(texts, "|"))
check(texts[5] == "Kern" and texts[6] == "Peon" and texts[7] == "Ein Text", "zweiter Hinweis ohne Datum")
check(f.dividers[1] and f.dividers[1].shown, "Trennlinie zwischen Hinweisen")
check(PeonDB.noticesSeen["broker:umbau"] and PeonDB.noticesSeen["kern-1"], "als gesehen gemerkt")
check(UISpecialFrames[#UISpecialFrames] == "PeonNoticeFrame" or (function() for _, n in ipairs(UISpecialFrames) do if n == "PeonNoticeFrame" then return true end end end)(), "ESC schliesst")
check(f.ok.txt == ns.L.NOTICE_OK, "Knopf Verstanden")
f.ok.scripts.OnClick()
check(not f.shown, "Verstanden schliesst")

-- 3. Naechster Login: nichts mehr
N.OnLogin(); runTimers()
check(not f.shown, "gesehene Hinweise kommen nicht wieder")

-- 4. Spaeter gemeldeter Hinweis (Modul nach dem Einloggen geladen): nur der neue
check(Peon.AddNotice({ id = "kern-2", title = "Neu", text = "Spaet" }), "spaeter Hinweis")
check(#timers == 1, "spaeter Hinweis geplant")
runTimers()
check(f.shown and #f.shownList == 1 and f.shownList[1].id == "kern-2", "nur der neue Hinweis")
for _, p in ipairs(f.parts) do if p.shown then check(p.txt ~= "Broker neu", "alter Text versteckt") end end
check(not f.dividers[1].shown, "keine Trennlinie bei einem Hinweis")
f:Hide()

-- 5. Konto merkt sich das ueber Reload (frische Liste, gleiche PeonDB)
N.list, N.byId = {}, {}
mod.AddNotice(mod, { id = "umbau", title = "Broker neu" })
N.OnLogin(); runTimers()
check(not f.shown, "nach Reload nicht erneut")

-- 6. /peon neu zeigt alle, auch gesehene. Im Kampf nicht.
SlashCmdList.PEON("neu")
check(f.shown and #f.shownList == 1, "/peon neu zeigt gesehene")
f:Hide()
combat = true
SlashCmdList.PEON("hinweise")
check(not f.shown, "/peon neu im Kampf nicht")
combat = false
N.list, N.byId = {}, {}
SlashCmdList.PEON("news")
check(not f.shown and out[#out]:find(ns.L.NOTICE_NONE), "ohne Hinweise eine Zeile im Chat")

check(#reported == 0, "keine Fehler: " .. table.concat(reported, "; "))
print("ALLE TESTS OK")
