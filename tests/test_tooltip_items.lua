-- Stub-Test fuer Peon_Tooltip: Teile im Gegenstands-Tooltip (Items.lua) und Rahmenfarbe nach Qualitaet
-- Baut einen Tooltip mit Text-Zeilen, Hooks, TooltipDataProcessor und debugstack nach.
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return "deDE" end
function GetTime() return 1 end
date = os.date
time = os.time
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
function IsShiftKeyDown() return false end
function UnitExists() return false end
function GetCursorPosition() return 500, 400 end
SlashCmdList = {}
local SECRET = {}
function issecretvalue(v) return v == SECRET end

-- Blizzard-Texte (deDE)
SELL_PRICE = "Verkaufspreis"
ITEM_MIN_LEVEL = "Benötigt Stufe %d"
ITEM_CLASSES_ALLOWED = "Klassen: %s"
DURABILITY_TEMPLATE = "Haltbarkeit %d / %d"
ITEM_SET_NAME = "%s (%d/%d)"
ITEM_SET_BONUS = "Set: %s"
ITEM_SET_BONUS_GRAY = "(%d) Set: %s"
ITEM_SPELL_TRIGGER_ONEQUIP = "Anlegen:"
ITEM_SPELL_TRIGGER_ONUSE = "Benutzen:"
ITEM_SPELL_TRIGGER_ONPROC = "Chance bei Treffer:"
ITEM_QUALITY_COLORS = { [0] = { r = .6, g = .6, b = .6 }, [1] = { r = 1, g = 1, b = 1 }, [2] = { r = .1, g = 1, b = 0 }, [3] = { r = 0, g = .44, b = .87 } }

local loaded = { Peon = true, Peon_Tooltip = true, Peon_Broker = true, Peon_Ledger = true, BagBrother = true, AtlasLootClassic = true }
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_Tooltip = TocMeta("Peon_Tooltip"),
  Peon_Broker = { Title = "|cff8ccf4dPeon|r Broker" }, Peon_Ledger = { Title = "|cff8ccf4dPeon|r Ledger" },
  BagBrother = { Title = "BagBrother" }, AtlasLootClassic = { Title = "|cff00ff00AtlasLoot|r Classic" } }
C_AddOns = {
  GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function(a) return loaded[a] or false end,
  GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Tooltip" })[i] end,
}

---------------------------------------------------------------------------
-- generische Widgets (wie test_tooltip.lua), HookScript mit mehreren Hooks
---------------------------------------------------------------------------
local allFrames = {}
local function W()
  local o = { scripts = {}, hooks = {}, w = 0, h = 0, shown = true, events = {}, points = {} }
  local m = {}
  function m.SetSize(s, w, h) s.w, s.h = w, h end
  function m.SetHeight(s, h) s.h = h end
  function m.SetWidth(s, w) s.w = w end
  function m.GetHeight(s) return s.h end
  function m.GetWidth(s) return s.w end
  function m.GetStringHeight() return 12 end
  -- Breite: 6 Punkte je sichtbarem Zeichen, breiteste Zeile bei Umbruechen (ab 0.7.1)
  function m.GetStringWidth(s)
    local t = s.text
    if type(t) ~= "string" then return 0 end
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local mx = 0
    for seg in (t .. "\n"):gmatch("(.-)\n") do if #seg * 6 > mx then mx = #seg * 6 end end
    return mx
  end
  function m.SetScript(s, n, f) s.scripts[n] = f end
  function m.GetScript(s, n) return s.scripts[n] end
  function m.HookScript(s, n, f) s.hooks[n] = s.hooks[n] or {}; table.insert(s.hooks[n], f) end
  function m.RunScript(s, n, ...) if s.scripts[n] then s.scripts[n](s, ...) end for _, f in ipairs(s.hooks[n] or {}) do f(s, ...) end end
  function m.SetText(s, t) s.text = t end
  function m.GetText(s) return s.text end
  function m.SetChecked(s, v) s.checked = v end
  function m.GetChecked(s) return s.checked end
  function m.SetValue(s, v) s.value = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end
  function m.IsShown(s) return s.shown end
  function m.Show(s) s.shown = true end
  function m.Hide(s) s.shown = false end
  function m.SetShown(s, v) s.shown = v and true or false end
  function m.SetEnabled(s, v) s.enabled = v end
  function m.SetAlpha(s, a) s.alpha = a end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.GetThumbTexture() return true end
  function m.CreateFontString() return W() end
  function m.CreateTexture() local t = W(); t.shown = true; allFrames[#allFrames+1] = t; t.isTex = true; return t end
  function m.GetScale() return 1 end
  function m.GetEffectiveScale() return 1 end
  function m.SetPoint(s, ...) s.points[#s.points+1] = { ... } end
  function m.ClearAllPoints(s) s.points = {} end
  function m.GetPoint(s, i) local p = s.points[i or 1] if p then return unpack(p) end end
  function m.SetTextColor(s, r, g, b, a) s.color = { r, g, b, a or 1 } end
  function m.GetTextColor(s) local c = s.color or { 1, 1, 1, 1 } return c[1], c[2], c[3], c[4] end
  function m.SetColorTexture(s, ...) s.ctex = { ... } end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" and k ~= "NineSlice" and k ~= "GetFontObject" and k ~= "CanWordWrap" then return function() end end end })
end
function CreateFrame(kind, name, parent, template)
  local f = W(); f.kind = kind; f.template = template
  allFrames[#allFrames+1] = f
  if name then _G[name] = f end
  return f
end
UIParent = W()

---------------------------------------------------------------------------
-- Tooltip-Nachbau
---------------------------------------------------------------------------
local caller = "Interface/AddOns/Blizzard_SharedXML/Tooltip/TooltipDataHandler.lua"
function debugstack()
  return "[Interface/AddOns/Peon_Tooltip/Items.lua]:200: in function <...>\n[C]: in function 'AddLine'\n[" .. caller .. "]:12: in function 'x'\n[Interface/AddOns/Blizzard_SharedXML/Tooltip/TooltipDataHandler.lua]:99: in function 'y'"
end

local function NewFS(font)
  local fs = W(); fs.shown = false; fs.font = font; fs.wrap = false
  fs.GetFontObject = function(s) return s.font end
  fs.SetFontObject = function(s, f) s.font = f end
  fs.CanWordWrap = function(s) return s.wrap end
  fs.SetWordWrap = function(s, v) s.wrap = v end
  return fs
end

local function NewTooltip(name)
  local tt = W()
  tt.n = 0
  tt.NineSlice = { SetBorderColor = function(_, r, g, b) tt.border = { r, g, b } end, SetCenterColor = function() end }
  _G[name] = tt
  function tt:GetName() return name end
  function tt:NumLines() return self.n end
  function tt:IsForbidden() return false end
  function tt:GetOwner() return UIParent end
  function tt:GetUnit() return nil end
  local function line(i)
    if not _G[name .. "TextLeft" .. i] then
      _G[name .. "TextLeft" .. i] = NewFS(i == 1 and "HeaderFont" or "TextFont")
      _G[name .. "TextRight" .. i] = NewFS("TextFont")
    end
    return _G[name .. "TextLeft" .. i], _G[name .. "TextRight" .. i]
  end
  function tt:AddLine(text, r, g, b, wrap)
    self.n = self.n + 1
    local l, rt = line(self.n)
    l:SetText(text); l:SetTextColor(r or 1, g or 1, b or 1); l:Show(); l.wrap = wrap and true or false
    rt:SetText(nil); rt:Hide()
  end
  function tt:AddDoubleLine(a, c, lr, lg, lb, rr, rg, rb)
    self.n = self.n + 1
    local l, rt = line(self.n)
    l:SetText(a); l:SetTextColor(lr or 1, lg or 1, lb or 1); l:Show()
    rt:SetText(c); rt:SetTextColor(rr or 1, rg or 1, rb or 1); rt:Show()
  end
  function tt:ClearLines()
    for i = 1, self.n do local l, rt = line(i); l:SetText(nil); l:Hide(); rt:Hide() end
    self.n = 0
    self.shownMoneyFrames = nil
    self:RunScript("OnTooltipCleared")
  end
  function tt:Show() local was = self.shown; self.shown = true; if not was then self:RunScript("OnShow") end end
  function tt:Hide() self.shown = false; self:RunScript("OnHide") end
  return tt
end
-- Beispiel-Tooltips der Optionen (ab 0.7): GameTooltip-Nachbau, Befuellen ueber PREVIEW_SHOW (weiter unten)
local cfBase = CreateFrame
CreateFrame = function(kind, name, parent, tpl)
  if kind == "GameTooltip" then
    local t = NewTooltip(name); t.kind = kind; allFrames[#allFrames+1] = t
    function t:SetOwner() end
    function t:SetInventoryItem(u, slot) t.inv = slot; PREVIEW_SHOW(self) end
    function t:SetBagItem() PREVIEW_SHOW(self) end
    function t:SetUnit(u) t.unit = u; self:ClearLines(); self:AddLine("Mirel") end
    return t
  end
  return cfBase(kind, name, parent, tpl)
end
GameTooltip = NewTooltip("GameTooltip")
ShoppingTooltip1 = NewTooltip("ShoppingTooltip1")
ItemRefTooltip = NewTooltip("ItemRefTooltip")
GameTooltipMoneyFrame1 = W()

-- hooksecurefunc fuer Methoden und globale Funktionen
function hooksecurefunc(a, b, c)
  if type(a) == "table" then
    local orig = a[b]
    a[b] = function(...) local r = { orig(...) } c(...) return unpack(r) end
  else
    local orig = _G[a]
    _G[a] = function(...) local r = { orig(...) } b(...) return unpack(r) end
  end
end
function GameTooltip_SetDefaultAnchor() end

Enum = { TooltipDataType = { Item = 0, Unit = 2 },
  TooltipDataLineType = { None = 0, Blank = 1, SellPrice = 11, ItemBinding = 20, RestrictedLevel = 27, EquipSlot = 28, ItemName = 29 } }
local LT = Enum.TooltipDataLineType
local postCalls, linePost = {}, {}
TooltipDataProcessor = {
  AllTypes = "ALL",
  AddTooltipPostCall = function(t, f) table.insert(postCalls, { t = t, f = f }) end,
  AddLinePostCall = function(t, f) table.insert(linePost, { t = t, f = f }) end,
}
local timers = {}
C_Timer = { After = function(_, f) table.insert(timers, f) end }
local function runTimers() local t = timers; timers = {} for _, f in ipairs(t) do f() end end

local shownLink
TooltipUtil = { GetDisplayedItem = function() return "x", shownLink, 1 end }
C_Item = { GetItemInfo = function() return nil end, GetItemQualityColor = function(q) local c = ITEM_QUALITY_COLORS[q] return c.r, c.g, c.b end }

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

---------------------------------------------------------------------------
-- fremde Addons: Nachlaeufe werden VOR Peon_Tooltip angemeldet (laden alphabetisch frueher)
---------------------------------------------------------------------------
local addonLines = {
  BagBrother = { { "Mirel: 5 (Taschen 5)", { .5, .5, 1 } } },
  Peon_Broker = { { "AH: 1g 20s", { 0, 1, 0 } }, { "Behalten: alle", { .5, .8, 1 } } },
  Peon_Ledger = { { "Ledger (Umschalt)  Kosten 2s", { .5, .8, 1 } } },
}
local sellAsText = false
local function addonPost(name)
  return function(tt)
    local prev = caller
    caller = "Interface/AddOns/" .. name .. "/Tooltip.lua"
    for _, l in ipairs(addonLines[name]) do tt:AddLine(l[1], l[2][1], l[2][2], l[2][3]) end
    caller = prev
  end
end
TooltipDataProcessor.AddTooltipPostCall(0, addonPost("BagBrother"))
TooltipDataProcessor.AddTooltipPostCall(0, addonPost("Peon_Broker"))
TooltipDataProcessor.AddTooltipPostCall(0, addonPost("Peon_Ledger"))

load("Peon", "Peon", toc("Peon", "Peon.toc"))
fire("ADDON_LOADED", "Peon")
local ns = load("Peon_Tooltip", "Peon_Tooltip", toc("Peon_Tooltip", "Peon_Tooltip.toc"))
fire("ADDON_LOADED", "Peon_Tooltip")
local mod = ns.mod
check(mod and mod.initialized, "Modul initialisiert")
check(PeonTooltipDB.itemParts == true and PeonTooltipDB.itemBorder == "default", "Standardwerte Gegenstands-Tooltip")
check(#PeonTooltipDB.itemOrder == 7 and PeonTooltipDB.itemOrder[1] == "b:head" and PeonTooltipDB.itemOrder[7] == "b:price", "Blizzard-Teile vorbelegt")
fire("PLAYER_LOGIN")
check(#linePost == 1 and postCalls[#postCalls].t == 0, "Nachlaeufe beim Einloggen angemeldet (als letzter)")

---------------------------------------------------------------------------
-- Blizzard-Aufbau eines Gegenstands
---------------------------------------------------------------------------
local ITEM = {
  { LT.ItemName, "Wolfslederhelm" },
  { LT.ItemBinding, "Wird beim Aufheben gebunden" },
  { LT.EquipSlot, "Kopf", "Leder" },
  { LT.None, "87 Rüstung" },
  { LT.None, "+5 Beweglichkeit" },
  { LT.None, "Haltbarkeit 50 / 50" },
  { LT.RestrictedLevel, "Benötigt Stufe 20" },
  { LT.None, "Anlegen: Erhöht Angriffskraft um 10.", { 0, 1, 0 } },
  { LT.Blank, " " },
  { LT.None, "\"Riecht nach Wolf.\"", { 1, .82, 0 } },
  { LT.SellPrice, " ", nil, true },
}
local function show(tt, item, link)
  tt = tt or GameTooltip
  shownLink = link or "|cnIQ3:|Hitem:123::::::::|h[Wolfslederhelm]|h|r"
  tt:ClearLines()
  caller = "Interface/AddOns/Blizzard_SharedXML/Tooltip/TooltipDataHandler.lua"
  for _, d in ipairs(item or ITEM) do
    if d[3] and type(d[3]) == "string" then tt:AddDoubleLine(d[2], d[3])
    elseif d[1] == LT.SellPrice and sellAsText then
      caller = "Interface/AddOns/BagBrother/core/features/antiMoneyTaint.lua"
      tt:AddLine("Verkaufspreis: 5s")
      caller = "Interface/AddOns/Blizzard_SharedXML/Tooltip/TooltipDataHandler.lua"
    else
      local c = type(d[3]) == "table" and d[3] or { 1, 1, 1 }
      tt:AddLine(d[2], c[1], c[2], c[3])
      if d[4] then  -- Muenzanzeige an dieser Zeile
        tt.shownMoneyFrames = 1
        local mf = _G[tt:GetName() .. "MoneyFrame1"] or W()
        _G[tt:GetName() .. "MoneyFrame1"] = mf
        mf:ClearAllPoints(); mf:SetPoint("LEFT", _G[tt:GetName() .. "TextLeft" .. tt:NumLines()], "LEFT", 4, 0); mf:Show()
      end
    end
    if not (d[1] == LT.SellPrice and sellAsText) then
      for _, lp in ipairs(linePost) do lp.f(tt, { type = d[1] }) end
    end
  end
  for _, pc in ipairs(postCalls) do if pc.t == 0 or pc.t == "ALL" then pc.f(tt, { type = 0, id = 123 }) end end
  tt:Show()
end
PREVIEW_SHOW = function(tt) show(tt) end
local function lines(tt)
  tt = tt or GameTooltip
  local t = {}
  for i = 1, tt:NumLines() do
    local l, r = _G[tt:GetName() .. "TextLeft" .. i], _G[tt:GetName() .. "TextRight" .. i]
    local tx = l:GetText(); if tx == SECRET then tx = "<geheim>" end
    if tx ~= nil then t[#t+1] = tx .. ((r:IsShown() and r:GetText()) and ("|" .. r:GetText()) or "") end
  end
  return t
end
local function idx(list, text) for i, v in ipairs(list) do if v == text then return i end end end
local function pos(key) for i, v in ipairs(PeonTooltipDB.itemOrder) do if v == key then return i end end end

-- 1) Standard: nichts aendert sich, Teile werden entdeckt
show()
local base = lines()
check(#base == 15 and base[1] == "Wolfslederhelm" and base[3] == "Kopf|Leder" and base[12] == "Mirel: 5 (Taschen 5)" and base[15] == "Ledger (Umschalt)  Kosten 2s", "Standard: Tooltip unveraendert (" .. #base .. " Zeilen)")
local o = PeonTooltipDB.itemOrder
check(pos("a:BagBrother") == 8 and pos("a:Peon_Broker") == 9 and pos("a:Peon_Ledger") == 10, "Addons hinter Verkaufspreis entdeckt")
check(PeonTooltipDB.itemKnown["a:Peon_Broker"].title == "Peon Broker" and PeonTooltipDB.itemKnown["a:BagBrother"].seq == 1, "Titel ohne Farbe, Reihenfolge der Entdeckung")
local snap = ns.itemRecs[GameTooltip].snap
local keys = {}
for i, e in ipairs(snap) do keys[i] = e.key end
check(keys[1] == "pin" and keys[2] == "b:head" and keys[5] == "b:head" and keys[6] == "b:dura" and keys[7] == "b:req"
  and keys[8] == "b:effects" and keys[9] == "b:desc" and keys[10] == "b:desc" and keys[11] == "b:price", "Blizzard-Zeilen richtig eingeteilt (Leerzeile zur Beschreibung)")

-- 2) BagBrother nach oben, Beschreibung und Ledger aus
local function move(key, to) local i = pos(key) table.remove(o, i) table.insert(o, to, key) end
move("a:BagBrother", 1)
PeonTooltipDB.itemHidden["b:desc"] = true
PeonTooltipDB.itemHidden["a:Peon_Ledger"] = true
local hf = GameTooltipTextLeft2
show()
local l2 = lines()
check(l2[1] == "Wolfslederhelm" and l2[2] == "Mirel: 5 (Taschen 5)" and l2[3] == "Wird beim Aufheben gebunden", "BagBrother direkt unter dem Namen")
check(not idx(l2, "\"Riecht nach Wolf.\"") and not idx(l2, "Ledger (Umschalt)  Kosten 2s") and #l2 == 12, "Beschreibung (mit Leerzeile) und Ledger ausgeblendet")
check(idx(l2, "Kopf|Leder") == 4, "Doppelzeile mitverschoben")
check(GameTooltipTextRight2:IsShown() == false, "rechte Spalte der einfachen Zeile versteckt")
local mf = GameTooltipMoneyFrame1
local _, rel = mf:GetPoint(1)
check(rel == _G["GameTooltipTextLeft" .. idx(l2, " ")] and mf.shown, "Muenzanzeige haengt an der neuen Zeile")
check(GameTooltipTextLeft1.font == "HeaderFont", "Name behaelt Ueberschrift-Schrift")

-- 3) Verkaufspreis aus -> Muenzen weg
PeonTooltipDB.itemHidden["b:price"] = true
show()
check(not GameTooltipMoneyFrame1.shown, "Muenzanzeige versteckt mit ihrem Teil")
PeonTooltipDB.itemHidden["b:price"] = nil

-- 4) Trennlinie vor Broker, Leerraum am Ende (faellt weg), Trennlinie unter BagBrother
local s1 = ns.ItemAddSeparator("line", "a:BagBrother")
local s2 = ns.ItemAddSeparator("space", "b:price")
local s3 = ns.ItemAddSeparator("line")    -- ganz am Ende
check(o[pos(s1) - 1] == "a:BagBrother" and o[#o] == s3, "Trennungen an der richtigen Stelle eingefuegt")
show()
local l4 = lines()
check(l4[3] == " " and l4[4] == "Wird beim Aufheben gebunden", "Trennlinie unter BagBrother")
local bi = idx(l4, "AH: 1g 20s")
check(l4[bi - 1] == " " and l4[bi - 2] == " ", "Leerraum zwischen Verkaufspreis und Broker")
check(l4[#l4] == "Behalten: alle", "Trennung am Ende faellt weg")
local texShown = 0
for _, t in ipairs(ns.itemRecs[GameTooltip].seps) do if t.shown then texShown = texShown + 1 end end
check(texShown == 1, "eine sichtbare Linie (Textur)")

-- 5) Neu aufbauen (Umschalt): gleiches Ergebnis, Schrift zurueckgesetzt
GameTooltipTextLeft3.font = "Mist"
show()
local l5 = lines()
check(table.concat(l5, "/") == table.concat(l4, "/"), "Neuaufbau gleiches Ergebnis")

-- 6) spaete Zeile eines neuen Addons -> neu ordnen
caller = "Interface/AddOns/AtlasLootClassic/Core/Tooltip.lua"
GameTooltip:AddLine("Quelle: Wolf", 1, 1, 1)
runTimers()
local l6 = lines()
check(l6[#l6] == "Quelle: Wolf" and pos("a:AtlasLootClassic") == pos("a:Peon_Ledger") + 1, "spaetes Addon entdeckt und eingeordnet")
check(PeonTooltipDB.itemKnown["a:AtlasLootClassic"].title == "AtlasLoot Classic", "Titel AtlasLoot")
move("a:AtlasLootClassic", 1)
show()
caller = "Interface/AddOns/AtlasLootClassic/Core/Tooltip.lua"
GameTooltip:AddLine("Quelle: Wolf", 1, 1, 1)
runTimers()
local l6b = lines()
check(l6b[2] == "Quelle: Wolf" and l6b[3] == "Mirel: 5 (Taschen 5)", "spaete Zeile an gewuenschter Stelle")

-- 7) Teile ordnen aus: unveraendert
PeonTooltipDB.itemParts = false
show()
check(table.concat(lines(), "/") == table.concat(base, "/"), "Hauptschalter aus = wie ohne Peon")
PeonTooltipDB.itemParts = true

-- 8) Verkaufspreis als Text (BagBrother) gehoert zum Blizzard-Teil
sellAsText = true
ns.ItemResetOrder()
PeonTooltipDB.itemHidden["b:price"] = true
show()
check(not idx(lines(), "Verkaufspreis: 5s") and idx(lines(), "Mirel: 5 (Taschen 5)"), "Verkaufspreis als Text ausgeblendet, BagBrother bleibt")
PeonTooltipDB.itemHidden["b:price"] = nil
sellAsText = false

-- 9) Vergleichs-Tooltip: Kopfzeile + Name fest
local CMP = { { LT.None, "Derzeit angelegt" } }
for _, d in ipairs(ITEM) do CMP[#CMP+1] = d end
ns.ItemResetOrder()
move("a:Peon_Broker", 1)
show(ShoppingTooltip1, CMP)
local l9 = lines(ShoppingTooltip1)
check(l9[1] == "Derzeit angelegt" and l9[2] == "Wolfslederhelm" and l9[3] == "AH: 1g 20s", "Vergleichs-Tooltip: Kopf und Name bleiben oben")

-- 9b) 0.6.1: Blizzard haengt die Vergleichszeilen erst nach dem Ordnen an und zeigt dann (SetShown).
--     Neu geordnet wird sofort (kein Flackern), die Vergleichszeilen bleiben unten, keine Luecken.
PeonTooltipDB.itemHidden["b:desc"] = true
timers = {}
show(ShoppingTooltip1, CMP)
caller = "Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua"
ShoppingTooltip1:AddLine(" ")
ShoppingTooltip1:AddLine("Wenn Ihr diesen Gegenstand ersetzt, ergeben sich folgende Werteänderungen:", 1, .82, 0)
ShoppingTooltip1:AddLine("+3 Beweglichkeit", 1, 1, 1)
ShoppingTooltip1:SetShown(true)
local l9b = lines(ShoppingTooltip1)
check(l9b[#l9b] == "+3 Beweglichkeit" and l9b[#l9b - 1]:find("^Wenn Ihr") and l9b[#l9b - 2] == " ", "0.6.1: Vergleichszeilen sofort unten (ohne naechstes Bild)")
check(l9b[3] == "AH: 1g 20s" and not idx(l9b, "\"Riecht nach Wolf.\""), "0.6.1: Reihenfolge und Ausblenden bleiben")
local gap = false
for i = 1, #l9b do if _G["ShoppingTooltip1TextLeft" .. i]:GetText() == nil then gap = true end end
check(not gap, "0.6.1: keine leeren Zeilen dazwischen (Zeilen 1-" .. #l9b .. " belegt)")
check(ns.ItemPartLabel("tail") == "Blizzard: Vergleich", "0.6.1: Bezeichnung fuer /ttp teile")
runTimers()
check(table.concat(lines(ShoppingTooltip1), "/") == table.concat(l9b, "/"), "0.6.1: naechstes Bild aendert nichts mehr")
PeonTooltipDB.itemHidden["b:desc"] = nil

-- 10) Rahmenfarbe nach Qualitaet
PeonTooltipDB.itemBorder = "quality"
show()
check(GameTooltip.border and math.abs(GameTooltip.border[3] - .87) < 0.01, "Rahmen blau (selten, aus |cnIQ3:)")
show(ItemRefTooltip, nil, "|cnIQ2:|Hitem:5::::::::|h[X]|h|r")
check(ItemRefTooltip.border and ItemRefTooltip.border[1] == .1, "Chat-Link-Tooltip gruen")
PeonTooltipDB.itemBorder = "default"
show()
check(GameTooltip.border[1] == 1 and GameTooltip.border[2] == 1, "Standard: Rahmen zurueckgesetzt")

-- 11) geheime Texte: nichts anfassen
ns.ItemResetOrder()
move("a:Peon_Broker", 1)
local SECRET_ITEM = { { LT.ItemName, "X" }, { LT.None, SECRET } }
show(nil, SECRET_ITEM)
local l11 = lines()
check(l11[2] == "<geheim>" and l11[3] == "Mirel: 5 (Taschen 5)", "geheimer Text: Tooltip unveraendert")

-- 12) Optionsseite: Liste der Teile
local page = mod.page
mod.panel.scripts.OnShow()
local partList
for _, c in ipairs(page.controls) do if c.Refresh and c.SetAlpha and c.h and c.h > 200 then partList = c end end
check(partList, "Liste der Teile auf der Optionsseite")
local rowsShown, rowByKey = 0, {}
for _, f in ipairs(allFrames) do if f.kind == "Button" and f.key and f.cb and f.shown then rowsShown = rowsShown + 1; rowByKey[f.key] = f end end
check(rowsShown == #PeonTooltipDB.itemOrder, "eine Zeile je Teil (" .. rowsShown .. ")")
local r = rowByKey["b:desc"]
r.cb:SetChecked(false); r.cb.scripts.OnClick(r.cb)
check(PeonTooltipDB.itemHidden["b:desc"] == true, "Haken aus blendet aus")
local p0 = pos("b:desc")
r.up.scripts.OnClick(r.up)
check(pos("b:desc") == p0 - 1, "Pfeil hoch verschiebt")
for _, f in ipairs(allFrames) do if f.kind == "Button" and f.key == "b:desc" and f.shown then r = f end end
r.scripts.OnClick(r)    -- auswaehlen
local addLine
for _, f in ipairs(allFrames) do if f.text == "Trennlinie einfügen" then addLine = f end end
addLine.scripts.OnClick(addLine)
local sk = PeonTooltipDB.itemOrder[pos("b:desc") + 1]
check(ns.ItemIsSep(sk) and ns.ItemSepKind(sk) == "line", "Trennlinie unter der gewaehlten Zeile")
for _, f in ipairs(allFrames) do if f.kind == "Button" and f.key == sk and f.shown then f.remove.scripts.OnClick(f.remove) end end
check(not pos(sk), "Trennlinie entfernt")
loaded.AtlasLootClassic = false
page:Refresh()
for _, f in ipairs(allFrames) do if f.kind == "Button" and f.key == "a:AtlasLootClassic" and f.shown then
  check(f.remove.shown and f.label.text:find("nicht geladen"), "nicht geladenes Addon grau mit Entfernen-Knopf")
  f.remove.scripts.OnClick(f.remove) end end
check(not pos("a:AtlasLootClassic") and not PeonTooltipDB.itemKnown["a:AtlasLootClassic"], "Addon aus der Liste entfernt")

-- 12b) 0.7: Reiter Allgemein / Gegner / Gegenstaende mit Beispiel-Tooltips
check(page.tabButtons and #page.tabButtons == 3 and page.tabButtons[2].text == "Gegner" and page.tabButtons[3].text == "Gegenstände", "0.7: drei Reiter")
check(page:GetTab() == "general", "0.7: Start mit Allgemein")
page.panel.shown = true
function GetInventoryItemLink(u, s) if s == 16 then return "|cnIQ3:|Hitem:123::::::::|h[Wolfslederhelm]|h|r" end end
ns.ItemResetOrder()
move("a:Peon_Broker", 1)
page:SelectTab("items")
local pv = lines(PeonTooltipPreviewItem)
check(PeonTooltipPreviewItem.inv == 16 and pv[1] == "Wolfslederhelm" and pv[2] == "AH: 1g 20s", "0.7: Beispiel-Gegenstand (Waffe) mit eigener Reihenfolge")
PeonTooltipDB.itemHidden["a:Peon_Broker"] = true
mod:Fire("CHANGED", "itemHidden")
check(not idx(lines(PeonTooltipPreviewItem), "AH: 1g 20s"), "0.7: Aenderung sofort im Beispiel")
PeonTooltipDB.itemHidden["a:Peon_Broker"] = nil
page:SelectTab("units")
check(PeonTooltipPreviewUnit.unit == "player" and lines(PeonTooltipPreviewUnit)[1] == "Mirel", "0.7: Gegner-Beispiel zeigt dich ohne Ziel")
check(ns.IsMainTip(PeonTooltipPreviewUnit) and not ns.IsMainTip(ItemRefTooltip), "0.7: Beispiel bekommt Symbole und Spielerinfos")
page:SelectTab("general")
GetInventoryItemLink = nil

-- 13) Standardwerte: Reihenfolge zurueck, bekannte Addons bleiben
SlashCmdList.PEON_TOOLTIP("reset")
check(next(PeonTooltipDB.itemHidden) == nil and PeonTooltipDB.itemKnown["a:Peon_Broker"] and pos("a:BagBrother") == 8 and pos("b:head") == 1, "Standardwerte: Reihenfolge natuerlich, Addons bleiben bekannt")

-- 14) /ttp teile
SlashCmdList.PEON_TOOLTIP("teile")
show()
local found = false
for _, l in ipairs(out) do if l:find("Blizzard: Effekte") and l:find("Anlegen") then found = true end end
check(found and not ns.partsDebug, "/ttp teile schluesselt einmal auf")

-- 15) 0.7.1: maximale Breite – lange Zeilen werden umgebrochen
check(PeonTooltipDB.itemWrap == true and PeonTooltipDB.itemMaxWidth == 450, "0.7.1: Standard Umbruch an, 450")
local LONG = "Set: Gewährt Euren Nahkampfangriffen beim Angreifen von hinten eine Chance von 5%, einen Vitalpunkt zu treffen, wodurch das Ziel im Verlauf von 5 Sek. für 70 bis 80 körperlichen Schaden blutet."
local ITEM2 = {}
for _, d in ipairs(ITEM) do ITEM2[#ITEM2+1] = d end
table.insert(ITEM2, 9, { LT.None, LONG, { 0, 1, 0 } })
table.insert(ITEM2, 4, { LT.None, "Ein sehr langer Text links mit vielen vielen Woertern darin und noch mehr", "rechts" })
local function wrapped(tt)
  for i = 1, tt:NumLines() do
    local t = _G[tt:GetName() .. "TextLeft" .. i]:GetText()
    if type(t) == "string" and t:find("^Set: Gew") then return t, i end
  end
end
local function maxSeg(t) local m = 0 for seg in (t .. "\n"):gmatch("(.-)\n") do if #seg > m then m = #seg end end return m end
PeonTooltipDB.itemMaxWidth = 300           -- 50 Zeichen im Nachbau
show(GameTooltip, ITEM2)
local wt = wrapped(GameTooltip)
check(wt and wt:find("\n") and maxSeg(wt) <= 50 and wt:gsub("\n", " ") == LONG, "0.7.1: langer Set-Bonus umgebrochen, kein Wort verloren")
local dl = idx(lines(), "Ein sehr langer Text links mit vielen vielen Woertern darin und noch mehr|rechts")
check(dl ~= nil, "0.7.1: Doppelzeile bleibt unveraendert")
show(GameTooltip, ITEM2)
check(wrapped(GameTooltip) == wt, "0.7.1: Neuaufbau gleiches Ergebnis (kein doppelter Umbruch)")
PeonTooltipDB.itemParts = false
show(GameTooltip, ITEM2)
check(wrapped(GameTooltip) == wt, "0.7.1: Umbruch auch ohne 'Teile ordnen'")
PeonTooltipDB.itemParts = true
-- Vergleich: spaete Blizzard-Zeilen, dann SetShown -> Breite stimmt, bevor Blizzard sie liest
local CMP2 = { { LT.None, "Derzeit angelegt" } }
for _, d in ipairs(ITEM2) do CMP2[#CMP2+1] = d end
ShoppingTooltip1.SetShown = function(self, v) self.shown = v and true or false end
hooksecurefunc(ShoppingTooltip1, "SetShown", function() end)
show(ShoppingTooltip1, CMP2)
caller = "Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua"
ShoppingTooltip1:AddLine(" ")
ShoppingTooltip1:AddLine("Wenn Ihr diesen Gegenstand ersetzt, werden sich folgende Werte ändern:")
check(maxSeg(wrapped(ShoppingTooltip1)) <= 50, "0.7.1: Vergleichs-Tooltip umgebrochen")
PeonTooltipDB.itemWrap = false
show(GameTooltip, ITEM2)
check(wrapped(GameTooltip) == LONG, "0.7.1: Umbruch aus = Zeile unveraendert")
PeonTooltipDB.itemWrap = true
PeonTooltipDB.itemMaxWidth = 450
check(ns.ItemWrapText(GameTooltipTextLeft2, "kurz", 300) == nil, "0.7.1: kurze Zeile bleibt")

-- 16) 0.7.2: debugstack liefert einen geheimen Text (Forever im Kampf/in Instanzen)
-- -> kein Lua-Fehler, Tooltip bleibt so, wie Blizzard und die Addons ihn aufgebaut haben
do
  local p0, w0 = PeonTooltipDB.itemParts, PeonTooltipDB.itemWrap
  local o0 = {} for i, v in ipairs(PeonTooltipDB.itemOrder) do o0[i] = v end
  local ord = PeonTooltipDB.itemOrder
  local bi = pos("a:BagBrother") table.remove(ord, bi) table.insert(ord, 2, "a:BagBrother")
  PeonTooltipDB.itemParts, PeonTooltipDB.itemWrap = false, false
  show(); local raw = table.concat(lines(), "\n")
  PeonTooltipDB.itemParts, PeonTooltipDB.itemWrap = p0, w0
  show(); local arranged = table.concat(lines(), "\n")
  check(arranged ~= raw, "0.7.2: Vorbedingung - Teile werden normal umgeordnet")
  -- Im Spiel ist der geheime Text vom Typ "string", Durchsuchen bricht ab; hier steht SECRET dafuer
  -- (Peon.IsSecret erkennt ihn, Durchsuchen wuerde ebenfalls abbrechen)
  local oldDS = debugstack
  debugstack = function() return SECRET end
  local ok, err = pcall(show)
  check(ok, "0.7.2: geheime Aufrufkette ohne Abbruch (" .. tostring(err) .. ")")
  check(table.concat(lines(), "\n") == raw, "0.7.2: geheime Aufrufkette - Tooltip unangetastet")
  check(ns.ItemCallerAddon() == nil and select(2, ns.ItemCallerAddon()) == true, "0.7.2: Herkunft unbekannt, als geheim gemeldet")
  debugstack = oldDS
  show()
  check(table.concat(lines(), "\n") == arranged, "0.7.2: danach wird wieder normal geordnet")
  wipe(ord) for i, v in ipairs(o0) do ord[i] = v end
end

local n = 0 for _, l in ipairs(out) do if l:find("Fehler") or l:find("Error") then n = n + 1 end end
check(n == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
