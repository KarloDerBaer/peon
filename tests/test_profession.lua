-- Stub-Test fuer Peon + Peon_Profession: Routen, Schrittwahl, Anzahl, Ersatzrezept, Preise und Einkaufsliste ueber
-- ein nachgebautes Broker-Modul, Lesen des Berufsfensters, Messungen, Fenster und Leiste ohne Fehler.
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
local now = 100
function GetTime() return now end
date = os.date
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
function UnitFactionGroup() return "Horde" end
SlashCmdList = {}
UISpecialFrames = {}
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_Profession = TocMeta("Peon_Profession") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function() return true end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Profession" })[i] end }
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
  function m.GetScript(s, n) return s.scripts[n] end
  function m.SetText(s, t) s.text = t end
  function m.GetText(s) return s.text end
  function m.SetChecked(s, v) s.checked = v end
  function m.GetChecked(s) return s.checked end
  function m.SetValue(s, v) s.value = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end
  function m.IsShown(s) return s.shown end
  function m.Show(s) s.shown = true; if s.scripts.OnShow then s.scripts.OnShow(s) end end
  function m.Hide(s) s.shown = false end
  function m.SetShown(s, v) if v then s.shown = true else s.shown = false end end
  function m.SetEnabled(s, v) s.enabled = v end
  function m.SetAlpha(s, a) s.alpha = a end
  function m.SetTexture(s, t) s.tex = t end
  function m.SetColorTexture(s, ...) s.color = { ... } end
  function m.SetStatusBarColor(s, ...) s.color = { ... } end
  function m.SetPoint(s, ...) s.points[#s.points+1] = { ... } end
  function m.GetPoint(s) local p = s.points[1] if p then return p[1], nil, p[3], p[4], p[5] end end
  function m.ClearAllPoints(s) s.points = {} end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.RegisterUnitEvent(s, e) s.unitev[e] = true end
  function m.UnregisterAllEvents(s) s.events = {}; s.unitev = {} end
  function m.GetThumbTexture() return true end
  function m.CreateFontString() return W() end
  function m.CreateTexture() return W() end
  function m.CreateMaskTexture() return W() end
  function m.GetStatusBarTexture() return W() end
  function m.GetFontString() return nil end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" then return function() end end end })
end
function CreateFrame(kind) local f = W(); f.kind = kind; allFrames[#allFrames+1] = f; return f end
UIParent = W()
Minimap = W()
local cats = {}
Settings = { RegisterCanvasLayoutCategory = function(p, n) local c = { name = n, subs = {}, GetID = function() return n end } cats[n] = c return c end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) table.insert(par.subs, n) return { GetID = function() return par.name .. "/" .. n end } end,
  RegisterAddOnCategory = function(c) c.registered = true end,
  OpenToCategory = function(id) print("OPEN " .. id) end }
C_Timer = { After = function(_, fn) fn() end }

-- Spieldaten: Gegenstaende, Berufe, Berufsfenster
local NAMES = { [2447] = "Friedensblume", [765] = "Silberblatt", [2449] = "Erdwurzel", [3371] = "Leere Phiole",
  [5997] = "Elixier der schwachen Verteidigung", [2458] = "Elixier der schwachen Seelenstaerke", [2770] = "Kupfererz" }
local bags = { [2447] = 30, [2449] = 14 }
C_Item = {
  GetItemInfo = function(id) if NAMES[id] then return NAMES[id], nil, 1 end end,
  GetItemIconByID = function(id) return 1000 + id end,
  GetItemCount = function(id) return bags[id] or 0 end,
  RequestLoadItemDataByID = function() end,
}
C_Spell = { GetSpellName = function(id) return "Zauber " .. id end, GetSpellTexture = function() return 1 end }
C_Map = { GetMapInfo = function(id) return { name = "Karte " .. id } end }
local profs = { { "Alchimie", 87, 150, 171 }, { "Bergbau", 40, 75, 186 } }
function GetProfessions() return 1, 2 end
function GetProfessionInfo(i) local p = profs[i] return p[1], "icon", p[2], p[3], 0, 0, p[4] end

local recipes = {
  [101] = { name = "Elixier der schwachen Verteidigung", out = 5997, c = 2, m = { { 765, 1 }, { 2447, 1 }, { 3371, 1 } } },
  [102] = { name = "Elixier der schwachen Seelenstaerke", out = 2458, c = 0, m = { { 2449, 2 }, { 2447, 1 }, { 3371, 1 } } },
  [103] = { name = "Teurer Trank", out = 9999, c = 0, m = { { 765, 5 } } },
  [104] = { name = "Gelber Trank", out = 9998, c = 1, m = { { 2447, 1 } } },
}
local tsSkill = 87
local opened
C_TradeSkillUI = {
  GetBaseProfessionInfo = function() return { professionID = 171, professionName = "Alchimie", skillLevel = tsSkill, maxSkillLevel = 150 } end,
  GetAllRecipeIDs = function() return { 101, 102, 103, 104, 105 } end,
  GetRecipeInfo = function(id)
    if id == 105 then return { recipeID = 105, learned = false, name = "Unbekannt" } end
    local r = recipes[id]
    return { recipeID = id, learned = true, name = r.name, relativeDifficulty = r.c }
  end,
  GetRecipeSchematic = function(id)
    local r = recipes[id]
    local slots = {}
    for _, m in ipairs(r.m) do slots[#slots + 1] = { reagentType = 1, required = true, quantityRequired = m[2], reagents = { { itemID = m[1] } } } end
    return { outputItemID = r.out, quantityMin = 1, quantityMax = 1, reagentSlotSchematics = slots, name = r.name }
  end,
  OpenRecipe = function(id) opened = id end,
}

local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end

load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")

-- Nachgebautes Broker-Modul mit der neuen Schnittstelle (ab Broker 0.94)
local listCalls = {}
local fb = Peon:NewModule("Peon_FakeBroker", { key = "broker", title = "Broker", db = "FakeBrokerDB", defaults = {} })
local PRICES = { [765] = 50, [2447] = 20, [2449] = 40, [3371] = 4 }
function fb:BuyPrice(id) if PRICES[id] then return PRICES[id], id == 3371 and "vendor" or "ah" end return nil, "none" end
function fb:AddToList(name, mats) listCalls[#listCalls + 1] = { name = name, mats = mats } return #mats end
fire("ADDON_LOADED", "Peon_FakeBroker")

local ns = load("Peon_Profession", "Peon_Profession")
fire("ADDON_LOADED", "Peon_Profession")
local mod = ns.mod
check(mod.initialized and mod.page, "Modul + Optionsseite")
fire("PLAYER_LOGIN")
check(cats.Peon and cats.Peon.subs[#cats.Peon.subs] == "Profession", "Seite unter Peon > Profession")

-- Routen
local G = ns.Guide
check(type(ns.Routes[171]) == "table" and #ns.Routes[171] > 5, "Route Alchimie vorhanden")
for _, key in ipairs(ns.ORDER) do check(type(ns.Routes[key]) == "table", "Route fuer Beruf " .. key) end
for key, r in pairs(ns.Routes) do
  local last = 0
  for i, s in ipairs(r) do
    assert(s.from < s.to, "Schritt " .. key .. "/" .. i .. " von < bis")
    assert(s.from >= last - 0, "Schritt " .. key .. "/" .. i .. " aufsteigend")
    last = s.from
  end
end
check(true, "alle Schritte aufsteigend und gueltig")

-- Schrittwahl und Anzahl
local s1 = G.StepAt(171, 1)
check(s1.from == 1, "Stufe 1 -> erster Schritt")
check(G.StepAt(171, 0).from == 1, "unter dem ersten -> erster")
local s87, i87 = G.StepAt(171, 87)
check(s87.from <= 87 and s87.to > 87, "Stufe 87 -> passender Schritt")
check(G.StepAt(171, 300) == nil, "Stufe 300 -> fertig")
check(G.Remaining({ from = 60, to = 100, n = 40 }, 60) == 40, "Anzahl am Anfang = n")
check(G.Remaining({ from = 60, to = 100, n = 40 }, 90) == 10, "Anzahl anteilig")
check(G.Remaining({ from = 60, to = 100, n = 40 }, 99) == 1, "Anzahl kurz vor Ende mindestens 1")

-- Plan bis zum Hoechstwert mit Lehrerzeile
local plan = G.Plan(171, 87, 150)
check(plan[1].from == 87, "Plan beginnt bei der Stufe")
check(plan[#plan].trainer and plan[#plan].from == 150, "Plan endet mit Lehrerzeile bei 150")
for _, e in ipairs(plan) do assert(e.trainer or e.to <= 150, "Plan nicht ueber den Hoechstwert") end
check(G.TrainerHint(171, 140, 150) ~= nil, "Lehrer-Hinweis kurz vor dem Hoechstwert")
check(G.TrainerHint(171, 100, 150) == nil, "kein Lehrer-Hinweis weit davor")
check(G.TrainerHint(185, 140, 150):find("Buch"), "Kochkunst Experte als Buch")

-- Berufsfenster lesen (TRADE_SKILL_SHOW)
fire("TRADE_SKILL_SHOW")
local known = mod.db.known[171]
check(known and known[101] and known[101].out == 5997 and known[101].c == 2, "Rezept mit Ergebnis und Farbe gelesen")
check(known[105] == nil, "nicht erlerntes Rezept nicht gemerkt")
check(known[102].m[1] == 2449 and known[102].m[2] == 2, "Material aus dem Berufsfenster")
check(mod.db.colors[101][2][1] == 87, "Farbe gemessen (gruen bei 87)")
check(PeonProfessionCharDB.known ~= nil, "erlernte Rezepte je Charakter")

-- Ansicht: Schritt 10-55 (Elixier der schwachen Verteidigung) ist gruen -> Ersatz orange und guenstig
local stepDef
for i, s in ipairs(ns.Routes[171]) do if s.item == 5997 then stepDef = s end end
check(stepDef ~= nil, "Schritt mit Elixier der schwachen Verteidigung in der Route")
local v = G.View(171, stepDef, 40)
check(v.learned and v.color == 2, "Rezept erkannt, gruen")
check(v.alt and v.alt.id == 102, "Ersatz: guenstigstes oranges Rezept (nicht das teure)")
local mats, rid = G.Active(v)
check(rid == 102 and mats[1].id == 2449, "aktives Rezept ist der Ersatz")

-- Preise und Vorrat
local rows, total, noPrice = ns.Prices.Rows({ { id = 2449, q = 2 }, { id = 3371, q = 1 } }, 10)
check(rows[1].need == 20 and rows[1].have == 14 and rows[1].missing == 6, "Bedarf, Vorrat, Fehlt")
check(rows[1].cost == 240 and rows[2].cost == 40 and total == 280 and noPrice == 0, "Kosten nur fuer das Fehlende")
check(rows[2].src == "vendor", "Quelle Haendler")

-- Einkaufsliste
local added = ns.Prices.ToList(171, { [2449] = 20, [2447] = 5, [3371] = 10 })
check(added == 2, "nur fehlendes Material auf die Liste")
local call = listCalls[#listCalls]
check(call.name == "Beruf: Alchimie", "Liste je Beruf")
check(call.mats[1].id == 2449 and call.mats[1].n == 20, "Wunschmenge = ganzer Bedarf")

-- Messung: Herstellung + Punkt
now = 200
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 102)
profs[1][2] = 88
now = 205
fire("SKILL_LINES_CHANGED")
check(mod.db.ups[102] and mod.db.ups[102][1] == 87 and mod.db.ups[102][2] == 87, "Punkt dem Rezept zugeordnet")
now = 300
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 102)
profs[1][2] = 89
now = 400
fire("SKILL_LINES_CHANGED")
check(mod.db.ups[102][2] == 87, "zu spaeter Punkt nicht zugeordnet")
local lines = ns.Measure.Report()
check(type(lines) == "table", "/prof messungen laeuft")

-- Fenster
ns.Window.Open()
check(ns.Window.IsOpen(), "Fenster offen")
check(ns.Window.prof and ns.Window.prof.key == 171, "erster nicht fertiger Beruf gewaehlt")
check(ns.Window.view ~= nil, "Ansicht des aktuellen Schritts")
check(#ns.Window.mats.items > 0, "Material in der Tabelle")
check(#ns.Window.plan.items > 0, "Plan in der Tabelle")
local n = ns.Window.ToList("max")
check(n >= 0 and #listCalls >= 1, "Knopf bis zum Hoechstwert")
ns.Window.Open(186)
check(ns.Window.view and ns.Window.view.gather, "Sammelberuf zeigt Sammeln")
check(ns.Window.info.text:find("Karte"), "Gebiete fuer die eigene Fraktion")

-- Leiste am Berufsfenster
ProfessionsFrame = W()
tsSkill = 40
ns.CraftBar.Update()
check(ns.CraftBar.frame and ns.CraftBar.frame.shown, "Leiste sichtbar")
check(ns.CraftBar.frame.text.text:find("Seelenst"), "Leiste nennt den Ersatz")
ns.CraftBar.Select()
check(opened == 102, "Auswaehlen oeffnet das Rezept")
mod.db.craftBar = false
ns.CraftBar.Update()
check(not ns.CraftBar.frame.shown, "Leiste abschaltbar")

-- Starter-Text und Slash
check(ns.LauncherText() == "Bergbau 40/75", "Text fuer Peon_Panel: gewaehlter Beruf")
mod.db.sel = 0
check(ns.LauncherText() == "Alchimie 89/150", "Text fuer Peon_Panel: erster nicht fertiger Beruf")
local wasOpen = ns.Window.IsOpen()
SlashCmdList.PEON("profession")
check(ns.Window.IsOpen() ~= wasOpen, "/peon profession schaltet das Fenster")
SlashCmdList.PEON("profession optionen")
check(out[#out] == "OPEN Peon/Profession", "/peon profession optionen oeffnet Seite")

local nerr = 0 for _, l in ipairs(out) do if l:find("Fehler") then nerr = nerr + 1 end end
check(nerr == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
