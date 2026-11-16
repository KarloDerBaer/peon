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
local AH = { [765] = 50, [2447] = 20, [2449] = 40, [3371] = 6, [3001] = 10, [3002] = 30 }
local VEND = { [3371] = 4 }
local VALUE = { [3100] = 500, [3200] = 20, [2458] = 100 }
function fb:BuyPrice(id)
  local ah, vp = AH[id], VEND[id]
  if vp and (not ah or vp <= ah) then return vp, "vendor", ah, vp, "seen", "Gretta" end
  if ah then return ah, "ah", ah, vp end
  return nil, "none", ah, vp
end
function fb:AhPrice(id) return AH[id] end
function fb:ItemValue(id, n) local v = VALUE[id] or AH[id] return v and math.floor(v * (n or 1) * 0.95) or nil end
function fb:AddToList(name, mats, keepMax) listCalls[#listCalls + 1] = { name = name, mats = mats, keepMax = keepMax } return #mats end
-- ab 0.4.0 (Reiter Verlauf): Verlauf im AH und Tagesnummer
local HIST = {}
function fb:History(id) return HIST[id] or {} end
function fb:DayOf() return 20000 end
fire("ADDON_LOADED", "Peon_FakeBroker")
-- Einstellungen des Berufsfensters lagen bis Broker 0.94 in PeonBrokerDB
PeonBrokerDB = { craftListMode = "pct", craftHint = false, keepAllChars = true }
function hooksecurefunc() end

local ns = load("Peon_Profession", "Peon_Profession")
fire("ADDON_LOADED", "Peon_Profession")
local mod = ns.mod
check(mod.initialized and mod.page, "Modul + Optionsseite")
fire("PLAYER_LOGIN")
check(cats.Peon and cats.Peon.subs[#cats.Peon.subs] == "Profession", "Seite unter Peon > Profession")
check(mod.db.craftListMode == "pct" and mod.db.craftHint == false and mod.db.craftTwinks == true and mod.db.craftMigrated == true
    and mod.db.craftBlock == true, "0.2.0: Einstellungen des Berufsfensters einmal von Broker uebernommen")
mod.db.craftListMode, mod.db.craftHint, mod.db.craftTwinks = "money", true, false

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

-- Plan mit Ziel ueber den Hoechstwert hinaus: Lehrerzeilen an den Ranggrenzen, Schritte dort geteilt
local p2 = G.Plan(171, 89, 150, 230)
local tr = {}
for i, e in ipairs(p2) do if e.trainer then tr[#tr + 1] = e.from end end
check(#tr == 2 and tr[1] == 150 and tr[2] == 225, "0.2.0: Lehrerzeilen bei 150 und 225")
for i, e in ipairs(p2) do
  if e.trainer and e.from == 150 then check(p2[i - 1].to == 150 and p2[i + 1].from == 150, "0.2.0: Lehrerzeile genau an der Grenze") end
  assert(e.trainer or e.to <= 230, "Plan nicht ueber das Ziel")
end
local p3 = G.Plan(171, 0, 0, 75)
check(p3[1].trainer and p3[1].from == 0 and p3[2].from == 1, "0.2.0: nicht gelernt: zuerst Lehrling, dann ab 1")
local cut
for _, e in ipairs(G.Plan(171, 60, 75, 100)) do if not e.trainer and e.from == 60 then cut = e end end
check(cut and cut.to == 75 and cut.count == 15, "0.2.0: Schritt 60-100 an 75 geteilt, Anzahl anteilig")
check(G.Target(171, 89, 150) == 150 and G.Target(171, 150, 150) == 225 and G.Target(202, 0, 0) == 75, "0.2.0: Ziel ohne Eingabe")
G.SetTarget(171, 300)
check(G.Target(171, 89, 150) == 300, "0.2.0: Ziel gespeichert")
check(G.SetTarget(171, 999) == 300 and G.SetTarget(171, 0) == nil and G.Target(171, 89, 150) == 150, "0.2.0: Ziel begrenzt, 0 loescht")

-- Fenster
ns.Window.Open()
check(ns.Window.IsOpen(), "Fenster offen")
check(ns.Window.prof and ns.Window.prof.key == 171, "erster nicht fertiger Beruf gewaehlt")
check(ns.Window.view ~= nil, "Ansicht des aktuellen Schritts")
check(#ns.Window.mats.items > 0, "Material in der Tabelle")
check(#ns.Window.plan.items > 0, "Plan in der Tabelle")
check(ns.Window.target.text == "150", "0.2.0: Ziel im Feld")
ns.Window.target.text = "200"
ns.Window.ApplyTarget()
check(mod.db.target[171] == 200 and ns.Window.goal == 200, "0.2.0: Ziel eingegeben")
local last = ns.Window.plan.items[#ns.Window.plan.items]
check(last and not last.trainer, "0.2.0: Plan bis 200 endet mit einem Schritt")
local n = ns.Window.ToList("target")
check(n >= 0 and #listCalls >= 1, "Knopf bis zum Ziel")
-- Reiter Route und Material
ns.Window.Select("route")
check(#ns.Window.route.items == #ns.Routes[171], "0.2.0: Route mit allen Schritten 1-300")
local curRows = 0
for _, it in ipairs(ns.Window.route.items) do if it.current then curRows = curRows + 1 end end
check(curRows == 1, "0.2.0: aktueller Schritt hervorgehoben")
ns.Window.Select("mats")
local m2449
for _, it in ipairs(ns.Window.allMats.items) do if it.id == 2449 then m2449 = it end end
check(m2449 and m2449.need > 0 and m2449.have == 14, "0.2.0: Material bis zum Ziel mit Vorrat")
check(ns.Window.matsNote.text:find("89") and ns.Window.matsNote.text:find("200"), "0.2.0: Ueberschrift Material von bis")
ns.Window.Select("guide")
-- alle Berufe
mod.db.showAll = true
ns.Window.Refresh()
local all = ns.Window.ProfList()
check(#all == 12, "0.2.0: alle 12 Berufe")
ns.Window.Open(202)
check(ns.Window.prof.key == 202 and not ns.Window.prof.learned and ns.Window.goal == 75, "0.2.0: nicht gelernter Beruf, Ziel 75")
check(ns.Window.plan.items[1].trainer and ns.Window.view ~= nil, "0.2.0: zuerst Lehrling, Jetzt zeigt den ersten Schritt")
mod.db.showAll = false
ns.Window.Open(186)
check(ns.Window.view and ns.Window.view.gather, "Sammelberuf zeigt Sammeln")
check(ns.Window.info.text:find("Karte"), "Gebiete fuer die eigene Fraktion")

-- Leiste und Knopf am Berufsfenster
ProfessionsFrame = W()
ProfessionsFrame.TitleContainer = { TitleText = W() }
ProfessionsFrame.CloseButton = W()
tsSkill = 40
ns.CraftBar.Update()
check(ns.CraftBar.frame and ns.CraftBar.frame.shown, "Leiste sichtbar")
check(ns.CraftBar.frame.text.text:find("Seelenst"), "Leiste nennt den Ersatz")
ns.CraftBar.Select()
check(opened == 102, "Auswaehlen oeffnet das Rezept")
mod.db.craftBar = false
ns.CraftBar.Update()
check(not ns.CraftBar.frame.shown, "Leiste abschaltbar")
local tb = ns.CraftBar.title
check(tb and tb.shown and tb.points[1][2] == ProfessionsFrame.CloseButton and tb.points[1][1] == "RIGHT" and tb.text == "Peon Profession", "0.2.1: roter Knopf mit Text rechts in der Titelleiste")
local wasOpen0 = ns.Window.IsOpen()
tb.scripts.OnClick(tb)
check(ns.Window.IsOpen() ~= wasOpen0, "0.2.0: Knopf schaltet das Fenster")
mod.db.titleButton = false
ns.CraftBar.Update()
check(not tb.shown, "0.2.0: Knopf abschaltbar")
mod.db.titleButton = true

-- Berufsfenster: Kosten und Gewinn (ab 0.2.0 aus Broker), Pfeil des Guides, Goldmuenze
;(function()
  local Cr = ns.Craft
  local SCH = {
    [11] = { outputItemID = 3100, quantityMin = 1, quantityMax = 1, name = "Hemd",
             reagentSlotSchematics = { { reagents = { { itemID = 3002 } }, quantityRequired = 1, reagentType = 1, required = true },
                                       { reagents = { { itemID = 3001 } }, quantityRequired = 4, reagentType = 1, required = true },
                                       { reagents = { { itemID = 9999 } }, quantityRequired = 1, reagentType = 0, required = false } } },
    [12] = { outputItemID = 3200, quantityMin = 2, quantityMax = 2, name = "Lappen",
             reagentSlotSchematics = { { reagents = { { itemID = 3001 } }, quantityRequired = 5, reagentType = 1, required = true } } },
  }
  for id, s in pairs(SCH) do recipes[id] = { name = s.name, out = s.outputItemID, c = 3, m = {} } end   -- grau: kein Ersatz
  local keepSch = C_TradeSkillUI.GetRecipeSchematic
  C_TradeSkillUI.GetRecipeSchematic = function(id) return SCH[id] or keepSch(id) end
  C_TradeSkillUI.GetAllRecipeIDs = function() return { 101, 102, 103, 104, 11, 12 } end
  local MINE = { [3001] = { 2, 1 } }
  local keepCount = C_Item.GetItemCount
  C_Item.GetItemCount = function(id, bank) local s = MINE[id] if not s then return keepCount(id) end return bank and (s[1] + s[2]) or s[1] end
  local COST, OTH = { [3001] = 5 }, { [3001] = 10 }
  local ledger = { StockOthers = function(_, id) return OTH[id] or 0 end, Cost = function(_, id) return COST[id] end,
    Stock = function() return 15, { warband = 3, chars = { { name = "Borin Stein", places = { bank = 7 } } } } end }
  local savedGM = Peon.GetModule
  Peon.GetModule = function(self, k) if k == "ledger" then return ledger end return savedGM(self, k) end
  mod.db.craftTwinks = true
  local function Vis(f) f.IsVisible = function(s) return s.shown end return f end
  local form = Vis(CreateFrame("Frame"))
  form.Reagents = Vis(CreateFrame("Frame"))
  local selected = 11
  form.GetRecipeInfo = function() return { recipeID = selected } end
  local function RowFor(id)
    local r = CreateFrame("Button")
    r.GetElementData = function() return { GetData = function() return id and { recipeInfo = { recipeID = id } } or { categoryInfo = {} } end } end
    return r
  end
  local rows = { RowFor(nil), RowFor(11), RowFor(12), RowFor(102) }
  local sb = { ForEachFrame = function(_, fn) for _, r in ipairs(rows) do fn(r) end end }
  ProfessionsFrame = Vis(W())
  ProfessionsFrame.CraftingPage = { SchematicForm = form, RecipeList = { ScrollBox = sb } }
  tsSkill = 40
  fire("TRADE_SKILL_SHOW")
  Cr.dirty = true
  Cr.Tick()
  local c = Cr.calc[3100]
  check(c and c.cost == 50 and #c.lines == 2 and c.lines[1].src == "ah" and c.lines[1].cost == 30
      and c.lines[2].src == "stock" and c.lines[2].n == 4 and c.lines[2].cost == 20,
      "Hemd: Faden im AH 30c, 4 Stoff aus dem Vorrat zu Kosten laut Ledger 20c (" .. tostring(c and c.cost) .. ")")
  check(c.value == 475 and c.profit == 425 and c.mats[2].have == 13, "Hemd: Ertrag, Gewinn, Vorrat mit Twinks")
  check(Cr.calc[3200].sellBetter, "Lappen: Material verkaufen bringt mehr")
  -- Rezeptliste: Gewinn, Goldmuenze am besten Rezept, gruener Pfeil am Rezept des Guides
  check(not Cr.deco[rows[1]], "Kategorie-Zeile bleibt leer")
  local d11, d12, dg = Cr.deco[rows[2]], Cr.deco[rows[3]], Cr.deco[rows[4]]
  check(d11 and d11.fs.shown and d11.fs.text:find("60e060", 1, true), "Liste: Gewinn gruen")
  check(d12 and d12.fs.text:find("ff9933", 1, true), "Liste: orange, wenn Verkaufen mehr bringt")
  check(Cr.best == 3100 and d11.coin.shown and not d12.coin.shown, "0.2.0: Goldmuenze am besten Rezept")
  check(d11.coin.points[1][2] == d11.fs and d11.coin.points[1][3] == "LEFT", "0.2.0: Muenze direkt vor dem Gewinn")
  check(Cr.guideID == 102 and dg and dg.arrow.shown and not d11.arrow.shown, "0.2.0: gruener Pfeil am Rezept des Guides")
  check(dg.arrow.points[1][1] == "RIGHT" and dg.arrow.points[1][3] == "LEFT" and dg.arrow.points[1][4] < 0, "0.2.0: Pfeil links neben der Zeile")
  Cr.Set("craftGuideMark", false)
  check(not dg.arrow.shown, "0.2.0: Pfeil abschaltbar")
  Cr.Set("craftGuideMark", true)
  Cr.Set("craftListBest", false)
  check(not d11.coin.shown, "Muenze abschaltbar")
  Cr.Set("craftListBest", true)
  Cr.Set("craftListMode", "pct")
  check(d11.fs.text:find("%%"), "Liste in Prozent vom Material")
  Cr.Set("craftListMode", "money")
  -- Block unter den Reagenzien
  local b = Cr.block
  check(b and b.shown and b.points[1][2] == form.Reagents, "Block unter den Reagenzien")
  check(b.boxes[1].value.text == "50c" and b.rows[1].src.text == "AH" and b.rows[2].src.text == "Vorrat" and b.total.cost.text == "50c",
      "Block: Kosten, Quelle je Zeile, Gesamt")
  check(b.ck.shown and b.ck.checked == true, "Haken Twinks mitzaehlen (mit Ledger)")
  b.ck.checked = false
  b.ck.scripts.OnClick(b.ck)
  check(mod.db.craftTwinks == false and Cr.calc[3100].mats[2].have == 3, "Haken aus: nur dieser Charakter")
  Cr.Set("craftTwinks", true)
  Cr.Set("craftBlock", false)
  check(not b.shown, "Block abschaltbar")
  Cr.Set("craftBlock", true)
  -- Auf die Einkaufsliste "Material" ueber Broker (Wunschmenge wird nicht kleiner)
  MINE[3001] = { 0, 0 }
  OTH[3001] = 0
  Cr.dirty = true
  Cr.Tick()
  local before = #listCalls
  Cr.ToList(5)
  local call = listCalls[#listCalls]
  check(#listCalls == before + 1 and call.name == "Material" and call.keepMax == true, "Liste Material mit keepMax")
  local n3001
  for _, m in ipairs(call.mats) do if m.id == 3001 then n3001 = m.n end end
  check(n3001 == 20, "Menge je Herstellung x 5")
  -- Tooltip fuer Broker
  check(mod:CraftTooltip(3100) and mod:CraftTooltip(3100):find("Material") and mod:CraftTooltip(4711) == nil, "0.2.0: Zeile fuer Brokers Tooltip")
  -- Pruefbefehl
  form.Reagents.GetObjectType = function() return "Frame" end
  ns.Craft.Probe()
  local sawProbe = false
  for _, l in ipairs(out) do if l:find("Guide-Rezept: 102", 1, true) then sawProbe = true end end
  check(sawProbe, "/prof pruefen nennt das Rezept des Guides")
  -- 0.28.1 (Broker): GetChildren nie ueber pcall
  local src = io.open("Peon_Profession/Craft.lua"):read("*a")
  check(not src:find("pcall%([^)]*GetChildren"), "GetChildren ohne pcall")
  fire("TRADE_SKILL_CLOSE")
  Peon.GetModule = savedGM
  C_Item.GetItemCount = keepCount
  C_TradeSkillUI.GetRecipeSchematic = keepSch
  C_TradeSkillUI.GetAllRecipeIDs = function() return { 101, 102, 103, 104, 105 } end
  mod.db.craftTwinks = false
end)()

-- 0.2.1: Rezepte ohne Angabe "learned" zaehlen als erlernt, Beruf notfalls ueber den Titel des Berufsfensters
;(function()
  local keepInfo, keepBase = C_TradeSkillUI.GetRecipeInfo, C_TradeSkillUI.GetBaseProfessionInfo
  C_TradeSkillUI.GetRecipeInfo = function(id) local r = keepInfo(id) if r and id ~= 105 then r.learned = nil end return r end
  C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionName = "", skillLevel = 41, maxSkillLevel = 150 } end
  ProfessionsFrame = W()
  ProfessionsFrame.TitleContainer = { TitleText = W() }
  ProfessionsFrame.TitleContainer.TitleText.text = "Alchimie"
  local k, s, m = ns.Measure.OpenProfession()
  check(k == 171 and s == 41 and m == 150, "0.2.1: Beruf ueber den Titel erkannt, Stufe vom Spiel")
  mod.db.known[171] = nil
  ns.Measure.ReadAll()
  check(mod.db.known[171] and mod.db.known[171][102] and mod.db.known[171][105] == nil, "0.2.1: Rezepte ohne learned gemerkt, ausdruecklich nicht erlernte nicht")
  local lines = ns.Measure.ProbeLines()
  check(lines[#lines]:find("Beruf 171", 1, true), "0.2.1: /prof pruefen nennt den erkannten Beruf")
  C_TradeSkillUI.GetRecipeInfo, C_TradeSkillUI.GetBaseProfessionInfo = keepInfo, keepBase
end)()

-- 0.2.2: der im Fenster gezeigte Beruf ist der verfolgte, die Leiste von Peon_Panel wird neu gezeichnet
;(function()
  local refreshed = 0
  local keepL = mod.launcher
  mod.launcher = { Refresh = function() refreshed = refreshed + 1 end }
  mod.db.sel = 0
  ns.Window.key = nil
  ns.Window.Open()
  check(mod.db.sel == 171 and refreshed >= 1, "0.2.2: gezeigter Beruf wird verfolgt, Leiste neu gezeichnet")
  check(ns.LauncherText():find("^Alchimie"), "0.2.2: Leiste zeigt den verfolgten Beruf")
  mod.launcher = keepL
  check(ns.ICON == 8197101 and meta.Peon_Profession.IconTexture == "8197101", "0.2.2: Symbol Hammer und Spitzhacke")
end)()

-- 0.3.0: Buecher fuer den Rang Experte (Erste Hilfe, Kochkunst, Angeln) mit Haendler und Wegpunkt
;(function()
  local K = ns.Books
  NAMES[16072] = "Expertenkochbuch"
  check(K.For(185, 150) and K.For(185, 150).item == 16072 and K.For(185, 75) == nil and K.For(171, 150) == nil, "0.3.0: Buch nur fuer Kochkunst beim Hoechstwert 150")
  check(K.Vendor(K.For(185, 150)).name == "Wulan", "0.3.0: Haendler der eigenen Fraktion (Horde)")
  check(K.Vendor(K.For(356, 150)).name == "Old Man Heming", "0.3.0: neutraler Haendler fuer beide")
  local hint = G.TrainerHint(185, 131, 150)
  check(hint and hint:find("Expertenkochbuch", 1, true) and hint:find("Wulan, Karte 1443 (26.2, 69.8)", 1, true) and hint:find("1g", 1, true),
      "0.3.0: Hinweis mit Buch, Preis, Haendler und Ort (" .. tostring(hint) .. ")")
  -- Wegpunkt
  local set, tracked
  C_Map.CanSetUserWaypointOnMap = function(map) return map ~= 9999 end
  C_Map.SetUserWaypoint = function(p) set = p end
  UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
  C_SuperTrack = { SetSuperTrackedUserWaypoint = function(v) tracked = v end }
  check(K.Mark(185, 150) and set.map == 1443 and math.abs(set.x - 0.262) < 1e-9 and math.abs(set.y - 0.698) < 1e-9 and tracked == true,
      "0.3.0: Wegpunkt auf der Karte gesetzt und verfolgt")
  check(not K.Waypoint({ name = "X", map = 9999, x = 1, y = 1 }), "0.3.0: nicht markierbare Karte meldet sich")
  -- im Fenster: Plan mit Buchzeile, Klick setzt den Wegpunkt, Knopf Auf Karte bei 131/150
  profs[3] = { "Kochkunst", 131, 150, 185 }
  GetProfessions = function() return 1, 2, 3 end
  ns.Window.Open(185)
  set = nil
  local row
  for _, it in ipairs(ns.Window.plan.items) do if it.book then row = it end end
  check(row and row.name:find("als Buch", 1, true), "0.3.0: Buchzeile im Plan")
  ns.Window.plan.o.onClick(row, "LeftButton")
  check(set and set.map == 1443, "0.3.0: Klick auf die Buchzeile setzt den Wegpunkt")
  check(ns.Window.mapBtn.shown and ns.Window.info.text:find("Wulan", 1, true), "0.3.0: Knopf Auf Karte und Hinweis im Jetzt")
  set = nil
  ns.Window.mapBtn.scripts.OnClick(ns.Window.mapBtn)
  check(set and set.map == 1443, "0.3.0: Knopf Auf Karte setzt den Wegpunkt")
  ns.Window.Open(171)
  check(not ns.Window.mapBtn.shown, "0.3.0: ohne Buch kein Knopf")
  profs[3] = nil
  GetProfessions = function() return 1, 2 end
end)()

-- 0.3.1: selbst herstellbare Zwischenprodukte (Schneiderei: Wollstoffballen 2997 aus Wollstoff 2592)
;(function()
  local G, P = ns.Guide, ns.Prices
  mod.db.known[197] = nil
  local mats, yield = G.Producer(197, 2997)
  check(mats and mats[1].id == 2592 and mats[1].q == 3 and yield == 1, "0.3.1: Wollstoffballen stellt die Schneiderei selbst her")
  check(G.Producer(197, 2592) == nil, "0.3.1: Wollstoff nicht herstellbar")
  bags[2997] = 5
  local base, made = G.Resolve(197, { [2997] = 135, [2321] = 90 })
  check(base[2997] == nil and base[2592] == 390 and base[2321] == 90, "0.3.1: Ballen in Wollstoff aufgeloest, Vorrat abgezogen")
  check(made[2997].need == 135 and made[2997].have == 5 and made[2997].crafts == 130, "0.3.1: Zwischenprodukt mit Bedarf und Herstellungen")
  bags[2997] = nil
  -- Plan: die Ballen aus dem Schritt 60-70 zaehlen fuer die spaeteren Schritte
  local plan = { { from = 60, to = 70, count = 12, item = 2997, step = ns.Routes[197][1] } }
  for _, s in ipairs(ns.Routes[197]) do if s.item == 2997 then plan[1].step = s end end
  for _, s in ipairs(ns.Routes[197]) do if s.item == 4314 then plan[2] = { from = 85, to = 125, count = 45, item = 4314, step = s } end end
  local need, mk = G.Need(197, plan)
  check(need[2997] == nil and need[2592] == 36 + (135 - 12) * 3 and mk[2997].have == 12, "0.3.1: Plan rechnet hergestellte Ballen an (" .. tostring(need[2592]) .. ")")
  -- Tabelle im Jetzt: Zeile fuer die Ballen ohne Preis, danach Wollstoff
  local rows = P.Rows({ { id = 2997, q = 3 }, { id = 2321, q = 2 } }, 45, 197)
  check(rows[1].id == 2997 and rows[1].src == "craft" and rows[1].cost == nil and rows[2].id == 2321 and rows[3].id == 2592 and rows[3].need == 405,
      "0.3.1: Jetzt zeigt Ballen als selbst herstellen und Wollstoff dazu")
  check(#P.Rows({ { id = 2997, q = 3 } }, 1) == 1, "0.3.1: ohne Beruf keine Aufloesung")
end)()

-- 0.4.0: Verhuetten beim Bergbau
;(function()
  local G = ns.Guide
  local steps = G.Steps(186)
  check(#steps == #ns.Routes[186] + #ns.Smelt[186] and steps[1] == ns.Routes[186][1] and steps[#steps].smelt,
      "0.4.0: Route und Verhuetten zusammen, Nummern der Route bleiben")
  for _, s in ipairs(ns.Smelt[186]) do assert(s.from < s.to and s.smelt and s.n and ns.Learn[s.spell], "Verhuetten gueltig") end
  check(#G.Steps(171) == #ns.Routes[171], "0.4.0: andere Berufe ohne Verhuetten")
  local s = G.SmeltAt(186, 40)
  check(s and s.item == 2840, "0.4.0: bei 40 Kupferbarren verhuetten")
  check(G.SmeltAt(186, 50) == nil, "0.4.0: bei 50 nichts zu verhuetten")
  check(G.CraftStepAt(186, 40) == s and G.CraftStepAt(186, 50).gather and G.CraftStepAt(171, 89) == G.StepAt(171, 89),
      "0.4.0: Berufsfenster beim Bergbau zeigt das Verhuetten")
  local plan = G.Plan(186, 40, 75, 100)
  local prev, sm, tr = 0, 0, false
  for _, e in ipairs(plan) do
    assert(e.from >= prev, "Plan nach Stufe geordnet")
    prev = e.from
    if e.smelt then sm = sm + 1 end
    if e.trainer and e.from == 75 then tr = true end
    assert(e.trainer or e.from >= 75 or e.to <= 75, "an 75 geteilt")
  end
  check(sm >= 4 and tr, "0.4.0: Plan Bergbau mit Verhuetten, geteilt an der Lehrerzeile bei 75")
  local need, made = G.Need(186, plan)
  check(need[2770] and need[2770] > 0 and need[2771] and need[2840] == nil and made[2840], "0.4.0: Bronze aus selbst verhuettetem Kupfer und Zinn")
  local v = G.View(186, s, 40)
  check(v and not v.gather and v.smelt and v.mats[1].id == 2770 and v.count > 0, "0.4.0: Verhuetten im Jetzt als Rezept mit Erz")
  ns.Window.Open(186)
  check(ns.Window.info.text:find("Verhütten", 1, true) and ns.Window.view.gather, "0.4.0: Jetzt beim Sammeln nennt das Verhuetten")
  local row
  for _, it in ipairs(ns.Window.plan.items) do if it.name and it.name:find("^Verhütten") then row = it end end
  check(row ~= nil and ns.Window.btnTarget.shown, "0.4.0: Plan zeigt Verhuetten, Knopf Einkaufsliste da")
  ns.Window.plan.o.onClick(row, "LeftButton")
  check(ns.Window.view.smelt and ns.Window.name.text:find("^Verhütten"), "0.4.0: Klick zeigt das Verhuetten im Jetzt")
  ns.Window.Select("route")
  local nSm = 0
  for _, it in ipairs(ns.Window.route.items) do if it.name:find("Verhütten", 1, true) then nSm = nSm + 1 end end
  check(#ns.Window.route.items == #steps and nSm == #ns.Smelt[186], "0.4.0: Route mit Verhuetten")
  ns.Window.Select("guide")
end)()

-- 0.4.0: Reiter Verlauf (Kosten bis zum Ziel je Tag)
;(function()
  local H = ns.History
  HIST[2449] = { { day = 19990, min = 20 }, { day = 19995, min = 30 }, { week = 2854, min = 10 } }
  HIST[3371] = { { day = 19996, min = 9 } }
  local s, real = H.Prices(2449, 7, 20000)
  check(s and s[1] == 30 and s[2] == 30 and s[6] == 30 and s[7] == 40 and real[2] and not real[1],
      "0.4.0: Tagespreise, Luecken mit dem letzten Wert, heute der aktuelle Preis")
  local s2 = H.Prices(3371, 7, 20000)
  check(s2[3] == 4 and s2[1] == 4, "0.4.0: hoechstens der Haendlerpreis")
  check(H.Prices(77777, 7, 20000) == nil, "0.4.0: ohne Preis nil")
  HIST[2449][#HIST[2449] + 1] = { week = 2856, min = 25 }   -- Tage 19992-19998, Tageswert geht vor
  s = H.Prices(2449, 7, 20000)
  check(s[1] == 25 and s[2] == 30 and s[3] == 25, "0.4.0: Wochenwert fuellt Tage ohne Tageswert")
  check(H.Signed(150):find("+", 1, true) and H.Signed(-150):find("-", 1, true) and H.Percent(0.25):find("+25 %", 1, true), "0.4.0: Vorzeichen")
  mod.db.histDays = 7
  ns.Window.Open(171)
  ns.Window.Select("history")
  local d = ns.Window.histData
  check(d and d.days == 7 and #d.total == 7 and #ns.Window.histTable.items > 0, "0.4.0: Verlauf berechnet")
  local m
  for _, it in ipairs(ns.Window.histTable.items) do if it.id == 2449 then m = it end end
  check(m and m.first == 25 and m.now == 40 and m.delta == 15 * m.need, "0.4.0: Material mit Preis vorher, heute, Mehrkosten")
  check(ns.Window.histHead.text:find("heute", 1, true) and ns.Window.histHead.text:find("vor 7 Tagen", 1, true), "0.4.0: Kopf mit Summe")
  check(d.real >= 2 and ns.Window.histEmpty.shown == false, "0.4.0: Diagramm mit echten Tagen")
  check(mod.db.windowTab == "history", "0.4.0: Reiter gemerkt")
  HIST[2449], HIST[3371] = nil, nil
  ns.Window.Select("history")
  check(ns.Window.histEmpty.shown and ns.Window.histEmpty.text:find("Noch kein Verlauf", 1, true), "0.4.0: ohne Verlauf ein Hinweis")
  ns.Window.Select("guide")
end)()

-- 0.4.1: Fremde Rezepte (Gifte beim Wechsel zu Kochkunst) nicht merken, Lesen erst nach Ruhe, /prof vergessen
;(function()
  local M = ns.Measure
  recipes[901] = { name = "Sofort wirkendes Gift", out = 6947, c = 0, m = { { 2928, 1 } } }
  mod.db.known[171][902] = { out = 6950, c = 0, name = "Altes Gift" }   -- frueher falsch gemerkt
  local keepIDs = C_TradeSkillUI.GetAllRecipeIDs
  C_TradeSkillUI.GetAllRecipeIDs = function() return { 101, 102, 103, 104, 105, 901 } end
  C_TradeSkillUI.GetTradeSkillLineForRecipe = function(id) if id >= 900 then return 40, "Gifte" end return 171, "Alchimie" end
  fire("TRADE_SKILL_SHOW")
  local k = mod.db.known[171]
  check(k[101] and k[102] and k[901] == nil and k[902] == nil and M.foreign >= 1, "0.4.1: Gifte unter Alchimie verworfen, alte entfernt")
  check(M.Belongs(101, 171) == true and M.Belongs(901, 171) == false and M.Belongs(901, 185) == false, "0.4.1: Rezept-Pruefung")
  C_TradeSkillUI.GetTradeSkillLineForRecipe = function() return 2550, "Kochkunst (Classic)" end
  check(M.Belongs(1, 185) == true, "0.4.1: Unterberuf mit Namen des Berufs gehoert dazu")
  C_TradeSkillUI.GetTradeSkillLineForRecipe = nil
  C_TradeSkillUI.GetProfessionInfoByRecipeID = function(id) return { professionID = 2550, parentProfessionID = 185 } end
  check(M.Belongs(1, 185) == true and M.Belongs(1, 171) == false, "0.4.1: Pruefung ueber den Grundberuf")
  C_TradeSkillUI.GetProfessionInfoByRecipeID = nil
  check(M.Belongs(901, 171) == nil, "0.4.1: ohne Schnittstelle unbekannt, nichts wird verworfen")
  local probe = M.ProbeLines()
  check(probe[#probe - 1]:find("Rezept-Pruefung", 1, true), "0.4.1: /prof pruefen nennt die Rezept-Pruefung")
  C_TradeSkillUI.GetAllRecipeIDs = keepIDs
  -- Lesen erst nach Ruhe: zwei Ereignisse kurz hintereinander, gelesen wird einmal am Ende
  local queue, reads = {}, 0
  local keepTimer, keepShow = C_Timer.After, M.OnShow
  C_Timer.After = function(_, fn) queue[#queue + 1] = fn end
  M.OnShow = function() reads = reads + 1 end
  fire("TRADE_SKILL_LIST_UPDATE")
  fire("TRADE_SKILL_LIST_UPDATE")
  for _, fn in ipairs(queue) do fn() end
  check(reads == 1, "0.4.1: nur das letzte Ereignis liest")
  C_Timer.After, M.OnShow = keepTimer, keepShow
  -- /prof vergessen
  SlashCmdList.PEON("profession vergessen")
  check(next(mod.db.known) == nil and out[#out - 0]:find("vergessen", 1, true), "0.4.1: /prof vergessen leert die gemerkten Rezepte")
  fire("TRADE_SKILL_SHOW")
  check(mod.db.known[171][102] ~= nil, "0.4.1: danach neu gelesen")
end)()

-- 0.4.1: Ton und Chatzeile, wenn das Rezept des Guides wechselt
;(function()
  local M = ns.Measure
  local played = {}
  PlaySound = function(id, ch) played[#played + 1] = { id, ch } end
  SOUNDKIT = { READY_CHECK = 11, RAID_WARNING = 12 }
  check(mod.db.stepSound == true and mod.db.stepSoundKey == "ready", "0.4.1: Ton ab Werk an")
  M.sig[171] = nil
  check(M.CheckMilestone(171, 89, 150) == false and #played == 0, "0.4.1: erster Stand ohne Ton")
  check(M.CheckMilestone(171, 95, 150) == false and #played == 0, "0.4.1: gleiches Rezept, kein Ton")
  local function LastMsg() for i = #out, 1, -1 do if out[i]:find("Meilenstein", 1, true) and not out[i]:find("ok  ", 1, true) then return out[i] end end return "" end
  check(M.CheckMilestone(171, 100, 150) == true and played[1][1] == 11 and played[1][2] == "Master", "0.4.1: neuer Schritt bei 100: Ton")
  check(LastMsg():find("bis 135", 1, true), "0.4.1: Chatzeile nennt den naechsten Schritt")
  check(M.CheckMilestone(171, 100, 150) == false and #played == 1, "0.4.1: nur einmal")
  -- Rezept des Schritts wird gruen: der Guide nimmt einen Ersatz, das ist auch ein Meilenstein
  mod.db.known[171][201] = { out = 3383, c = 2, n = 1, m = { 785, 1 } }
  check(M.CheckMilestone(171, 101, 150) == true and #played == 2, "0.4.1: Ersatz wegen Farbe: Ton")
  mod.db.known[171][201] = nil
  mod.db.stepSoundKey = "raid"
  check(M.CheckMilestone(171, 150, 150) == true and played[3][1] == 12 and LastMsg():find("Höchstwert", 1, true), "0.4.1: Hoechstwert erreicht, gewaehlter Ton")
  mod.db.stepSound = false
  M.sig[171] = { sig = "x", base = 0 }
  check(M.CheckMilestone(171, 120, 150) == true and #played == 3, "0.4.1: Ton abschaltbar")
  mod.db.stepSound, mod.db.stepSoundKey = true, "ready"
  M.Alert("Probe", true)
  check(#played == 4, "0.4.1: Probe-Knopf spielt den Ton")
  -- ueber die Stufe des Spiels
  M.sig[171] = nil
  M.InitMilestones()
  check(M.sig[171] and M.sig[171].base == 89, "0.4.1: beim Einloggen gemerkt")
  profs[1][2] = 100
  fire("SKILL_LINES_CHANGED")
  check(#played == 5, "0.4.1: Punkt im Spiel loest den Ton aus")
  profs[1][2] = 89
  fire("SKILL_LINES_CHANGED")
  PlaySound, SOUNDKIT = nil, nil
end)()

-- Starter-Text und Slash
ns.Window.Open(186)
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
