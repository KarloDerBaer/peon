-- Peon_Broker - Craft.lua
-- Berufe: Herstellkosten und Gewinn (ab 0.24, mit KarloDerBaer abgestimmt 03.10.2026: Box am Berufsfenster + Tooltip).
--
-- Beim Oeffnen eines Berufs liest Broker die erlernten Rezepte (C_TradeSkillUI.GetAllRecipeIDs, GetRecipeInfo,
-- GetRecipeSchematic - in Forever vorhanden, Pruefung Ledger 02.10.2026) und merkt sie je Charakter:
-- PeonBrokerCharDB.recipes[Ergebnis-itemID] = { r = recipeID, name, n = Menge je Herstellen, m = { [itemID] = Stueck } }.
--   Materialkosten = Summe (guenstigstes AH-Angebot je Stueck x Menge); ohne Preis fuer ein Material: unvollstaendig.
--   Wert          = Zeile 1 des Tooltips fuer das Ergebnis (guenstigstes Angebot bzw. Haendlerpreis, ns.ItemValue).
--   Gewinn        = Wert - Materialkosten.
-- Anzeige: Box rechts am Berufsfenster (gewaehltes Rezept, sonst nur die besten Rezepte) und mit Umschalt im
-- Tooltip des Ergebnisses ("Herstellen: Material 1g 20s · Gewinn +35s"). Nur lesend, Broker stellt nichts her.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local C = {}
ns.Craft = C

local GREY, ORANGE, GREEN, RED = "|cff999999", "|cffff9933", "|cff60e060", "|cffff4040"
local function Money(v) return ns.Tooltip.Money(v) end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function TS() return rawget(_G, "C_TradeSkillUI") end

C.TOP = 5   -- so viele beste Rezepte in der Box

function C.List(create)
    local c = mod.char
    if type(c.recipes) ~= "table" then
        if not create then return nil end
        c.recipes = {}
    end
    return c.recipes
end

-- Ein Rezept lesen: { r, name, out, n, m } oder nil
function C.ReadRecipe(id)
    local ts = TS()
    if not ts or not ts.GetRecipeSchematic then return nil end
    local ok, s = pcall(ts.GetRecipeSchematic, id, false)
    if not ok or type(s) ~= "table" or not Num(s.outputItemID) or s.outputItemID <= 0 then return nil end
    local m, any = {}, false
    for _, slot in ipairs(type(s.reagentSlotSchematics) == "table" and s.reagentSlotSchematics or {}) do
        -- nur Pflicht-Materialien (Grundmaterial); wahlweise Zusaetze zaehlen nicht
        local basic = slot.reagentType == nil or slot.reagentType == 1
            or (Enum and Enum.CraftingReagentType and slot.reagentType == Enum.CraftingReagentType.Basic)
        if slot.required ~= false and basic and type(slot.reagents) == "table" and slot.reagents[1] then
            local rid = slot.reagents[1].itemID
            local q = tonumber(slot.quantityRequired) or 1
            if Num(rid) and q > 0 then m[rid] = (m[rid] or 0) + q; any = true end
        end
    end
    if not any then return nil end
    local n = Num(s.quantityMin) and s.quantityMin > 0 and s.quantityMin or 1
    if Num(s.quantityMax) and s.quantityMax > n then n = (n + s.quantityMax) / 2 end   -- Durchschnitt, falls es schwankt
    return { r = id, name = s.name, out = s.outputItemID, n = n, m = m }
end

-- Alle erlernten Rezepte des offenen Berufs lesen und merken
function C.ReadAll()
    local ts = TS()
    if not ts or not ts.GetAllRecipeIDs then return 0 end
    local ok, ids = pcall(ts.GetAllRecipeIDs)
    if not ok or type(ids) ~= "table" then return 0 end
    local list, n = C.List(true), 0
    C.open = {}
    for _, id in ipairs(ids) do
        local learned = true
        if ts.GetRecipeInfo then
            local oki, info = pcall(ts.GetRecipeInfo, id)
            if oki and type(info) == "table" and info.learned == false then learned = false end
        end
        if learned then
            local rec = C.ReadRecipe(id)
            if rec then
                list[rec.out] = { r = rec.r, name = rec.name, n = rec.n, m = rec.m }
                C.open[#C.open + 1] = rec.out
                n = n + 1
            end
        end
    end
    mod:Dbg("Berufe: " .. n .. " Rezepte gelesen")
    return n
end

-- Kosten je Stueck eines Materials: guenstigstes Angebot (aktueller Stand), nil = unbekannt
function C.UnitCost(id)
    local e = ns.Data.Lookup(id)
    if type(e) == "table" and Num(e.m) and not e.gone then return e.m end
    return nil
end

-- Rechnung fuer ein Rezept: { cost, missing (Anzahl Materialien ohne Preis), value, profit, n }
function C.Calc(rec, outID)
    if type(rec) ~= "table" or type(rec.m) ~= "table" then return nil end
    local cost, missing = 0, 0
    for id, q in pairs(rec.m) do
        local u = C.UnitCost(id)
        if u then cost = cost + u * q else missing = missing + 1 end
    end
    local n = rec.n or 1
    local value = ns.ItemValue(outID, math.max(1, math.floor(n + 0.5)))
    local profit = (value and missing == 0) and (value - cost) or nil
    return { cost = cost, missing = missing, value = value, profit = profit, n = n }
end

function C.ProfitText(c)
    if not c then return "" end
    if not c.profit then return GREY .. L.CRAFT_UNKNOWN .. "|r" end
    if c.profit > 0 then return GREEN .. "+" .. Money(c.profit) .. "|r" end
    if c.profit < 0 then return RED .. "-" .. Money(-c.profit) .. "|r" end
    return Money(0)
end

-- Tooltip (mit Umschalt): "Herstellen: Material 1g 20s · Gewinn +35s"
function C.TooltipText(key)
    local id = ns.Data.ItemID(key)
    local list = C.List(false)
    local rec = list and id and list[id]
    if not rec then return nil end
    local c = C.Calc(rec, id)
    if not c then return nil end
    local mat = Money(c.cost) .. (c.missing > 0 and (GREY .. " " .. L.CRAFT_MISSING:format(c.missing) .. "|r") or "")
    return L.CRAFT_TT:format(mat, C.ProfitText(c))
end

---------------------------------------------------------------------------
-- Box am Berufsfenster
---------------------------------------------------------------------------
-- Fenster des Berufs (Forever: modern wie Retail oder Classic-Rahmen)
function C.Frame()
    for _, name in ipairs({ "ProfessionsFrame", "TradeSkillFrame" }) do
        local f = rawget(_G, name)
        if type(f) == "table" and f.IsShown and f:IsShown() then return f end
    end
    return nil
end

-- Gewaehltes Rezept, soweit erkennbar
function C.SelectedRecipe()
    if C.selected then return C.selected end
    local f = rawget(_G, "ProfessionsFrame")
    local page = type(f) == "table" and rawget(f, "CraftingPage")
    local form = type(page) == "table" and rawget(page, "SchematicForm")
    if type(form) == "table" and form.GetRecipeInfo then
        local ok, info = pcall(form.GetRecipeInfo, form)
        if ok and type(info) == "table" and Num(info.recipeID) then return info.recipeID end
    end
    return nil
end

function C.Lines()
    local lines = {}
    local list = C.List(false) or {}
    local sel = C.SelectedRecipe()
    if sel then
        local rec = C.ReadRecipe(sel)
        if rec then
            local c = C.Calc(rec, rec.out)
            local name = ns.GetItemInfo(rec.out) or rec.name or tostring(rec.out)
            lines[#lines + 1] = "|cffffffff" .. name .. (rec.n > 1 and (" ×" .. rec.n) or "") .. "|r"
            for id, q in pairs(rec.m) do
                local u = C.UnitCost(id)
                local mn = ns.GetItemInfo(id) or ("#" .. id)
                lines[#lines + 1] = GREY .. "  " .. q .. "× " .. mn .. ": |r" .. (u and Money(u * q) or (ORANGE .. "?|r"))
            end
            lines[#lines + 1] = L.CRAFT_COST .. " " .. Money(c.cost) .. (c.missing > 0 and (ORANGE .. " " .. L.CRAFT_MISSING:format(c.missing) .. "|r") or "")
            lines[#lines + 1] = L.CRAFT_VALUE .. " " .. (c.value and Money(c.value) or (GREY .. "?|r"))
            lines[#lines + 1] = L.CRAFT_PROFIT .. " " .. C.ProfitText(c)
            if c.profit then
                lines[#lines + 1] = c.profit > 0 and (GREEN .. L.CRAFT_WORTH .. "|r") or (ORANGE .. L.CRAFT_NOT_WORTH .. "|r")
            end
            lines[#lines + 1] = " "
        end
    end
    -- beste Rezepte des offenen Berufs
    local best = {}
    for _, out in ipairs(C.open or {}) do
        local rec = list[out]
        local c = rec and C.Calc(rec, out)
        if c and c.profit and c.profit > 0 then best[#best + 1] = { out = out, rec = rec, c = c } end
    end
    table.sort(best, function(a, b) return a.c.profit > b.c.profit end)
    lines[#lines + 1] = "|cffffd100" .. L.CRAFT_BEST .. "|r"
    if #best == 0 then lines[#lines + 1] = GREY .. L.CRAFT_BEST_NONE .. "|r" end
    for i = 1, math.min(C.TOP, #best) do
        local b = best[i]
        lines[#lines + 1] = (ns.GetItemInfo(b.out) or b.rec.name or tostring(b.out)) .. "  " .. C.ProfitText(b.c)
    end
    return lines
end

function C.CreateBox()
    if C.box then return C.box end
    local b = CreateFrame("Frame", "PeonBrokerCraftBox", UIParent, "BackdropTemplate")
    b:SetSize(230, 260)
    b:SetFrameStrata("HIGH")
    if b.SetBackdrop then
        b:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                        tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        if b.SetBackdropColor then b:SetBackdropColor(0, 0, 0, 0.85) end
    end
    local title = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText(("|c%sBroker|r %s"):format(Peon.COLOR, L.CRAFT_TITLE))
    local text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 10, -28)
    text:SetPoint("RIGHT", -10, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    b.text = text
    b:Hide()
    C.box = b
    return b
end

-- Abstand rechts vom Berufsfenster (ab 0.25.2): Forever haengt rechts eine Leiste mit Berufs-Symbolen an das Fenster.
-- Die Box rueckt hinter alles, was rechts am Fenster klebt (sichtbare Rahmen, die links an der Fensterkante beginnen
-- und hoechstens C.SIDE_MAX breit sind); sonst C.SIDE_GAP.
C.SIDE_GAP, C.SIDE_MAX = 4, 140
-- Lage eines Rahmens in Bildschirm-Punkten (Massstab eingerechnet) oder nil
local function Rect(fr)
    if type(fr) ~= "table" or not fr.GetLeft then return nil end
    local ok, l, r, t, b, sc = pcall(function()
        return fr:GetLeft(), fr:GetRight(), fr:GetTop(), fr:GetBottom(), fr.GetEffectiveScale and fr:GetEffectiveScale() or 1
    end)
    if not ok or type(l) ~= "number" or type(r) ~= "number" or type(t) ~= "number" or type(b) ~= "number" or type(sc) ~= "number" then return nil end
    return l * sc, r * sc, t * sc, b * sc, sc
end

local function Visible(fr)
    local fn = fr.IsVisible or fr.IsShown
    if not fn then return false end
    local ok, v = pcall(fn, fr)
    return ok and v and true or false
end

function C.SideOffset(f)
    local fl, right, top, bottom, fsc = Rect(f)
    if not fl then return C.SIDE_GAP end
    local best = right
    local function Check(k)
        if k == C.box or not Visible(k) then return end
        local l, r, t, b, sc = Rect(k)
        if not l then return end
        local max = C.SIDE_MAX * sc
        if l >= right - 30 * fsc and l <= right + 20 * fsc and r > right and r - l <= max and t <= top + 10 * fsc and b >= bottom - 10 * fsc then
            if r > best then best = r end
        end
    end
    -- GetChildren direkt aufrufen, NIE ueber pcall: pcall mit sehr vielen Rueckgabewerten
    -- (UIParent hat Hunderte Kinder) laesst WoW abstuerzen (Assertion "L->top < L->ci->top",
    -- Broker 0.28.0 beim Oeffnen des Berufsfensters). Fehler faengt mod:Call um C.Update ab.
    local function Scan(parent, depth)
        if type(parent) ~= "table" or type(parent.GetChildren) ~= "function" then return end
        local kids = { parent:GetChildren() }
        for i = 1, #kids do
            Check(kids[i])
            if depth > 1 then Scan(kids[i], depth - 1) end
        end
    end
    Scan(f, 2)
    if UIParent then Scan(UIParent, 1) end
    if best <= right then return C.SIDE_GAP end
    local bsc = (C.box and C.box.GetEffectiveScale and C.box:GetEffectiveScale()) or (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    -- Versatz gilt im Massstab der Box; Ankerpunkt ist die rechte Kante des Fensters
    return math.floor((best - right) / bsc + C.SIDE_GAP + 0.5)
end

function C.Update()
    local f = C.Frame()
    if not f then if C.box then C.box:Hide() end return end
    local b = C.CreateBox()
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPRIGHT", C.SideOffset(f), 0)
    local lines = C.Lines()
    b.text:SetText(table.concat(lines, "\n"))
    b:SetHeight(40 + #lines * 13)
    b:Show()
end

function C.OnShow()
    C.selected = nil
    mod:Call("Berufe", C.ReadAll)
    if C_Timer then C_Timer.After(0.3, function() mod:Call("Berufe", C.Update) end) else C.Update() end
end

function C.OnSelect(recipeID)
    if Num(recipeID) then C.selected = recipeID end
    mod:Call("Berufe", C.Update)
end

function C.Init()
    pcall(mod.RegisterEvent, mod, "TRADE_SKILL_SHOW", function() C.OnShow() end)
    pcall(mod.RegisterEvent, mod, "TRADE_SKILL_LIST_UPDATE", function()
        local now = GetTime and GetTime() or 0
        if not C.Frame() or now - (C.readAt or -99) < 2 then return end   -- kommt oft: hoechstens alle 2 Sek.
        C.readAt = now
        mod:Call("Berufe", C.ReadAll)
        C.Update()
    end)
    pcall(mod.RegisterEvent, mod, "TRADE_SKILL_CLOSE", function() C.selected = nil; if C.box then C.box:Hide() end end)
    -- gewaehltes Rezept (Retail-Fenster): Ereignis der Rezeptliste
    local reg = rawget(_G, "EventRegistry")
    if type(reg) == "table" and reg.RegisterCallback then
        pcall(reg.RegisterCallback, reg, "ProfessionsRecipeListMixin.Event.OnRecipeSelected", function(_, info)
            C.OnSelect(type(info) == "table" and info.recipeID or nil)
        end, C)
    end
    -- Preise geaendert (Scan): Box neu rechnen
    mod:On("SCAN_DONE", function() if C.box and C.box:IsShown() then C.Update() end end)
end
