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
-- Ab 0.39 (KarloDerBaer 08.11.2026): im modernen Berufsfenster statt der Box ein Block unter den Reagenzien
-- (Ergebniszeile Kosten/Ertrag/Gewinn, Tabelle je Material mit Quelle Vorrat/Haendler/AH, Kosten aus Peon_Ledger
-- oder Kaufpreis, Erloes im AH, Hinweis verkaufen oder herstellen) und der Gewinn rechts in
-- der Rezeptliste mit goldenem Strich am besten Rezept. Alles einstellbar (Zahnrad im Block, Optionsseite).
-- Die Box bleibt als Rueckfall, wenn das Fenster die Reagenzien nicht wie erwartet hat.

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
    local m, o, any = {}, {}, false
    for _, slot in ipairs(type(s.reagentSlotSchematics) == "table" and s.reagentSlotSchematics or {}) do
        -- nur Pflicht-Materialien (Grundmaterial); wahlweise Zusaetze zaehlen nicht
        local basic = slot.reagentType == nil or slot.reagentType == 1
            or (Enum and Enum.CraftingReagentType and slot.reagentType == Enum.CraftingReagentType.Basic)
        if slot.required ~= false and basic and type(slot.reagents) == "table" and slot.reagents[1] then
            local rid = slot.reagents[1].itemID
            local q = tonumber(slot.quantityRequired) or 1
            if Num(rid) and q > 0 then
                if not m[rid] then o[#o + 1] = rid end
                m[rid] = (m[rid] or 0) + q; any = true
            end
        end
    end
    if not any then return nil end
    local n = Num(s.quantityMin) and s.quantityMin > 0 and s.quantityMin or 1
    if Num(s.quantityMax) and s.quantityMax > n then n = (n + s.quantityMax) / 2 end   -- Durchschnitt, falls es schwankt
    return { r = id, name = s.name, out = s.outputItemID, n = n, m = m, o = o }
end

-- Alle erlernten Rezepte des offenen Berufs lesen und merken
function C.ReadAll()
    C.readAt = GetTime and GetTime() or 0
    C.needRead = false
    local ts = TS()
    if not ts or not ts.GetAllRecipeIDs then return 0 end
    local ok, ids = pcall(ts.GetAllRecipeIDs)
    if not ok or type(ids) ~= "table" then return 0 end
    local list, n = C.List(true), 0
    C.open, C.byRecipe, C.known = {}, {}, {}
    for _, id in ipairs(ids) do
        if Num(id) then C.known[id] = true end
        local learned = true
        if ts.GetRecipeInfo then
            local oki, info = pcall(ts.GetRecipeInfo, id)
            if oki and type(info) == "table" and info.learned == false then learned = false end
        end
        if learned then
            local rec = C.ReadRecipe(id)
            if rec then
                list[rec.out] = { r = rec.r, name = rec.name, n = rec.n, m = rec.m, o = rec.o }
                C.open[#C.open + 1] = rec.out
                C.byRecipe[rec.r] = rec.out
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

-- Rueckfall: Box rechts neben dem Fenster (bis 0.38 die einzige Anzeige)
function C.UpdateBox()
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

-- Block unter den Reagenzien, sonst die Box
function C.Update()
    if C.UpdateBlock() then
        if C.box then C.box:Hide() end
        return
    end
    C.UpdateBox()
end

function C.OnShow()
    C.selected = nil
    mod:Call("Berufe", C.ReadAll)
    C.dirty = true
    local function Start()
        mod:Call("Berufe", C.Driver)
        mod:Call("Berufe", C.Tick)
    end
    if C_Timer then C_Timer.After(0.3, Start) else Start() end
end

-- Rezepte neu lesen, sobald es geht. Das Ereignis kommt oft hintereinander: hoechstens alle
-- C.READ_GAP Sek. lesen, das letzte aber nie verschlucken (0.39, vorher fehlte die Liste bis zu einer Minute)
C.READ_GAP = 0.5
function C.ReadSoon()
    C.needRead = true
    C.dirty = true
    mod:Call("Berufe", C.Driver)
    if C.driver then return end   -- der Takt liest nach
    -- ohne Takt (altes Fenster): selbst nachlesen
    local function Read()
        C.timerOn = false
        if not C.needRead or not C.Frame() then return end
        C.needRead = false
        mod:Call("Berufe", C.ReadAll)
        C.Update()
    end
    if not C_Timer then return Read() end
    if C.timerOn then return end
    C.timerOn = true
    C_Timer.After(C.READ_GAP, Read)
end

function C.OnSelect(recipeID)
    if Num(recipeID) then C.selected = recipeID end
    mod:Call("Berufe", C.Update)
end

function C.Init()
    if ns.Merchant then ns.Merchant.Init() end
    pcall(mod.RegisterEvent, mod, "TRADE_SKILL_SHOW", function() C.OnShow() end)
    pcall(mod.RegisterEvent, mod, "TRADE_SKILL_LIST_UPDATE", function()
        if not C.Frame() then return end
        C.ReadSoon()
    end)
    -- Vorrat geaendert: neu rechnen (beim naechsten Takt, nur bei offenem Fenster)
    pcall(mod.RegisterEvent, mod, "BAG_UPDATE_DELAYED", function() if C.Frame() then C.dirty = true end end)
    pcall(mod.RegisterEvent, mod, "TRADE_SKILL_CLOSE", function() C.selected = nil; if C.box then C.box:Hide() end end)
    -- gewaehltes Rezept (Retail-Fenster): Ereignis der Rezeptliste
    local reg = rawget(_G, "EventRegistry")
    if type(reg) == "table" and reg.RegisterCallback then
        pcall(reg.RegisterCallback, reg, "ProfessionsRecipeListMixin.Event.OnRecipeSelected", function(_, info)
            C.OnSelect(type(info) == "table" and info.recipeID or nil)
        end, C)
    end
    -- Preise geaendert (Scan): Box neu rechnen
    mod:On("SCAN_DONE", function()
        if C.Frame() then C.dirty = true end
        if C.box and C.box:IsShown() then C.Update() end
    end)
end

---------------------------------------------------------------------------
-- Ab 0.39: Anzeige im Berufsfenster (Block unter den Reagenzien, Gewinn in der Rezeptliste)
---------------------------------------------------------------------------
local function DB() return mod.db or {} end
local function IsOn(key) return DB()[key] == true end

-- Peon_Ledger (wenn geladen, nur lesend)
function C.Ledger()
    if not Peon.GetModule then return nil end
    local ok, l = pcall(Peon.GetModule, Peon, "ledger")
    if ok and type(l) == "table" then return l end
    return nil
end

-- Eigene Kosten je Stueck laut Ledger (naechstes Stueck, aelteste zuerst), nil ohne Ledger oder ohne Posten
function C.OwnCost(id)
    local l = C.Ledger()
    if not l or type(l.Cost) ~= "function" then return nil end
    local ok, nxt = pcall(l.Cost, l, id)
    if ok and Num(nxt) and nxt >= 0 then return nxt end
    return nil
end

-- Vorrat wie im Reiter Behalten: gesamt, Taschen, Bank, andere Charaktere (nur mit Haken "Twinks mitzaehlen")
function C.Stock(id)
    local K = ns.Keep
    if K and K.Counts then
        local ok, bags, bank, total, others = pcall(K.Counts, id)
        if ok and Num(total) then return total, bags or 0, bank or 0, others or 0 end
    end
    return 0, 0, 0, 0
end

-- Rechnung fuer das Berufsfenster (Tabelle mit KarloDerBaer abgestimmt 08.11.2026). Jedes Material kommt aus dem
-- Vorrat oder wird gekauft, beim Haendler oder im AH, je nachdem wo es guenstiger ist.
--   Vorrat: Kosten laut Ledger (naechstes Stueck, ohne Wert im Ledger der AH-Preis), dazu der Erloes, den das
--           Material im AH braechte (ns.ItemValue, nach Gebuehr).
--   Kaufen: Menge x guenstigster Kaufpreis (Haendler oder AH).
--   cost = Summe der Kosten, value = Ertrag des Ergebnisses, profit = value - cost.
--   craftNet = value - buy: was Herstellen bringt (der Vorrat ist schon da).
--   erl = Erloes des Vorrats. sellBetter = erl > craftNet: das Material zu verkaufen bringt mehr.
-- { cost, missing, value, profit, n, craftable, stockUsed, stockCost, buy, hasBuy, erl, craftNet, sellBetter,
--   allProfit, mats = { { id, q, have, bags, bank, others, own, ah, vendor, vsrc, vwho, unit, src, from, rest } },
--   lines = { { mat, n, src = "stock"|"vendor"|"ah"|"none", cost, guess, est, erl } } }

-- Kaufpreis je Stueck: Preis, Quelle ("vendor", "ah", "none"), AH-Preis, Haendlerpreis, Herkunft des Haendlerpreises, Haendler
function C.BuyPrice(id)
    local ah = C.UnitCost(id)
    local vp, vsrc, vwho
    if ns.Merchant then vp, vsrc, vwho = ns.Merchant.Price(id) end
    if vp and (not ah or vp <= ah) then return vp, "vendor", ah, vp, vsrc, vwho end
    if ah then return ah, "ah", ah, vp, vsrc, vwho end
    return nil, "none", ah, vp, vsrc, vwho
end

function C.CalcFull(rec, outID, cache)
    if type(rec) ~= "table" or type(rec.m) ~= "table" then return nil end
    local order = rec.o
    if type(order) ~= "table" then
        order = {}
        for id in pairs(rec.m) do order[#order + 1] = id end
        table.sort(order)
    end
    local mats, lines, craftable, stockUsed, hasBuy = {}, {}, nil, false, false
    local cost, missing, stockCost, buy, buyMissing, erl, erlMissing, all, allMissing = 0, 0, 0, 0, false, 0, false, 0, false
    for _, id in ipairs(order) do
        local q = rec.m[id]
        if q then
            local st = cache and cache[id]
            if not st then
                st = { C.Stock(id) }
                if cache then cache[id] = st end
            end
            local have = st[1]
            local own = C.OwnCost(id)
            local unit, src, ah, vp, vsrc, vwho = C.BuyPrice(id)
            local from = math.max(0, math.min(q, have))
            local rest = q - from
            local m = { id = id, q = q, have = have, bags = st[2], bank = st[3], others = st[4], own = own, ah = ah,
                        vendor = vp, vsrc = vsrc, vwho = vwho, unit = unit, src = src, from = from, rest = rest }
            if from > 0 then
                stockUsed = true
                local sc = (own and own * from) or (ah and ah * from) or nil
                local sv = ns.ItemValue(id, from)
                if not Num(sv) then sv = nil end
                m.sellV = sv
                lines[#lines + 1] = { mat = m, n = from, src = "stock", cost = sc, guess = own == nil, erl = sv }
                if sc then cost, stockCost = cost + sc, stockCost + sc else missing = missing + 1 end
                if sv then erl = erl + sv else erlMissing = true end
            end
            if rest > 0 then
                hasBuy = true
                local bc = unit and unit * rest or nil
                lines[#lines + 1] = { mat = m, n = rest, src = src, cost = bc, est = src == "vendor" and vsrc == "est" }
                if bc then cost, buy = cost + bc, buy + bc else missing, buyMissing = missing + 1, true end
            end
            if unit then all = all + unit * q else allMissing = true end
            local can = math.floor(have / q)
            craftable = craftable and math.min(craftable, can) or can
            mats[#mats + 1] = m
        end
    end
    local n = rec.n or 1
    local value = ns.ItemValue(outID, math.max(1, math.floor(n + 0.5)))
    if not Num(value) then value = nil end
    local c = { cost = cost, missing = missing, value = value, n = n, mats = mats, lines = lines, craftable = craftable or 0,
                stockUsed = stockUsed, stockCost = stockCost, buy = buy, hasBuy = hasBuy }
    c.profit = (value and missing == 0) and (value - cost) or nil
    c.craftNet = (value and not buyMissing) and (value - buy) or nil
    c.erl = (stockUsed and not erlMissing) and erl or nil
    c.sellBetter = (c.erl and c.craftNet and c.erl > c.craftNet) and true or false
    c.allProfit = (value and not allMissing) and (value - all) or nil
    return c
end

-- Alle Rezepte des offenen Berufs rechnen. Der goldene Strich geht an das Rezept mit dem hoechsten Gewinn,
-- bei dem Herstellen mehr bringt als das Material zu verkaufen.
function C.Compute()
    local list = C.List(false) or {}
    local cache, res, ranked = {}, {}, {}
    for _, out in ipairs(C.open or {}) do
        local rec = list[out]
        local c = rec and C.CalcFull(rec, out, cache)
        if c then
            res[out] = c
            if c.profit and c.profit > 0 and not c.sellBetter then ranked[#ranked + 1] = out end
        end
    end
    table.sort(ranked, function(a, b) return res[a].profit > res[b].profit end)
    for i, out in ipairs(ranked) do res[out].rank = i end
    C.calc, C.best = res, ranked[1]
end

-- Text rechts in der Rezeptliste (nil = nichts zeigen). Orange: das Material zu verkaufen bringt mehr.
function C.ListText(c)
    local db = DB()
    if db.craftList ~= true or type(c) ~= "table" then return nil end
    local which = db.craftListWhich or "all"
    if not c.profit then
        if which ~= "all" or db.craftListUnknown ~= true then return nil end
        return GREY .. "?|r"
    end
    if which == "all" then
        if c.profit < 0 and db.craftListLoss ~= true then return nil end
    else
        if c.profit <= 0 then return nil end
        local top = tonumber(which:match("^top(%d+)$"))
        if top and not (c.rank and c.rank <= top) then return nil end
    end
    local p = c.profit
    if db.craftListMode == "pct" and c.cost > 0 then
        local pct = math.floor(p / c.cost * 100 + 0.5)
        local t = (pct > 0 and "+" or "") .. pct .. " %"
        if c.sellBetter then return ORANGE .. t .. "|r" end
        if pct > 0 then return GREEN .. t .. "|r" end
        if pct < 0 then return RED .. t .. "|r" end
        return t
    end
    if c.sellBetter then
        return ORANGE .. (p > 0 and "+" or (p < 0 and "-" or "")) .. Money(math.abs(p)) .. "|r"
    end
    return C.ProfitText(c)
end

---------------------------------------------------------------------------
-- Rezeptliste: Gewinn rechts in der Zeile, goldener Strich am besten Rezept
---------------------------------------------------------------------------
C.deco = setmetatable({}, { __mode = "k" })   -- Zeile -> { fs, bar } (nichts in Blizzards Tabellen schreiben)

function C.ListBox()
    local f = rawget(_G, "ProfessionsFrame")
    local page = type(f) == "table" and rawget(f, "CraftingPage")
    local rl = type(page) == "table" and rawget(page, "RecipeList")
    local sb = type(rl) == "table" and rawget(rl, "ScrollBox")
    if type(sb) == "table" then return sb end
    return nil
end

local function RowRecipeID(row)
    if type(row) ~= "table" or type(row.GetElementData) ~= "function" then return nil end
    local ok, node = pcall(row.GetElementData, row)
    if not ok or type(node) ~= "table" then return nil end
    local d = node
    if type(node.GetData) == "function" then
        local ok2, x = pcall(node.GetData, node)
        if ok2 and type(x) == "table" then d = x end
    end
    local info = d.recipeInfo
    if type(info) == "table" and Num(info.recipeID) then return info.recipeID end
    return nil
end
C.RowRecipeID = RowRecipeID

function C.DecorateRow(row)
    local id = RowRecipeID(row)
    -- Rezept in der Liste, das wir noch nicht gelesen haben (anderer Beruf, Liste kam spaeter): nachlesen
    if id and not (C.known and C.known[id]) then C.needRead = true end
    local out = id and C.byRecipe and C.byRecipe[id]
    local c = out and C.calc and C.calc[out]
    local text = c and C.ListText(c) or nil
    local best = c ~= nil and out == C.best and IsOn("craftList") and IsOn("craftListBest")
    local d = C.deco[row]
    if not d then
        if not text and not best then return end
        d = {}
        d.fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        d.fs:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        d.fs:SetJustifyH("RIGHT")
        d.bar = row:CreateTexture(nil, "OVERLAY")
        d.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
        d.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
        d.bar:SetWidth(2)
        d.bar:SetColorTexture(1, 0.82, 0, 0.9)
        C.deco[row] = d
    end
    d.fs:SetText(text or "")
    d.fs:SetShown(text ~= nil)
    d.bar:SetShown(best and true or false)
end

function C.DecorateList()
    local sb = C.ListBox()
    if not sb then return end
    if type(sb.ForEachFrame) == "function" then
        pcall(sb.ForEachFrame, sb, function(row) C.DecorateRow(row) end)
    elseif type(sb.GetFrames) == "function" then
        local ok, frames = pcall(sb.GetFrames, sb)
        if ok and type(frames) == "table" then
            for _, row in ipairs(frames) do C.DecorateRow(row) end
        end
    end
end

---------------------------------------------------------------------------
-- Block unter den Reagenzien
---------------------------------------------------------------------------
C.BLOCK_W, C.ROW_H, C.COL_SRC, C.COL_MONEY = 340, 15, 52, 66

-- Rezeptformular des modernen Berufsfensters (nur wenn sichtbar)
function C.Form()
    local f = rawget(_G, "ProfessionsFrame")
    if type(f) ~= "table" or not (f.IsShown and f:IsShown()) then return nil end
    local page = rawget(f, "CraftingPage")
    local form = type(page) == "table" and rawget(page, "SchematicForm")
    if type(form) == "table" and Visible(form) then return form end
    return nil
end

-- Unterster sichtbarer Reagenzien-Bereich (Pflicht-Reagenzien, darunter evtl. wahlweise Zusaetze)
function C.ReagentAnchor(form)
    local best, low
    for _, k in ipairs({ "Reagents", "OptionalReagents" }) do
        local fr = rawget(form, k)
        if type(fr) == "table" and Visible(fr) then
            local _, _, _, b = Rect(fr)
            if not best or (b and low and b < low) then best, low = fr, b end
        end
    end
    return best
end

local function FS(parent, justify)
    local s = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s:SetJustifyH(justify or "LEFT")
    if s.SetWordWrap then s:SetWordWrap(false) end
    return s
end

local function Hint(owner, text)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
end
local function HideTip() if GameTooltip then GameTooltip:Hide() end end

-- Name des Charakters wie in Peon_Ledger ("Vorname" oder "Vorname Nachname")
local function CharName()
    if not UnitName then return nil end
    local first, last = UnitName("player")
    if type(first) ~= "string" or Peon.IsSecret(first) then return nil end
    if type(last) == "string" and last ~= "" and not Peon.IsSecret(last) then return first .. " " .. last end
    return first
end

local function Places(p)
    local parts = {}
    for _, k in ipairs({ "bags", "bank", "transit" }) do
        if Num(p[k]) and p[k] > 0 then parts[#parts + 1] = L["CRAFT_PL_" .. k:upper()] .. " " .. p[k] end
    end
    return table.concat(parts, ", ")
end

-- Zeilen fuer den Tooltip ueber dem Vorrat: wo liegt was
function C.StockLines(m)
    local lines = {}
    local mine = Places({ bags = m.bags, bank = m.bank })
    lines[#lines + 1] = L.CRAFT_ST_ME .. ": " .. (mine ~= "" and mine or "0")
    local l = C.Ledger()
    if not l or type(l.Stock) ~= "function" then return lines end
    local ok, _, c = pcall(l.Stock, l, m.id)
    if not ok or type(c) ~= "table" then return lines end
    local me, others, n = CharName(), {}, 0
    for _, ch in ipairs(type(c.chars) == "table" and c.chars or {}) do
        if ch.name ~= me and type(ch.places) == "table" then
            local t = Places(ch.places)
            if t ~= "" then
                others[#others + 1] = (tostring(ch.name):match("^(%S+)") or "?") .. ": " .. t
                for _, k in ipairs({ "bags", "bank", "transit" }) do n = n + (tonumber(ch.places[k]) or 0) end
            end
        end
    end
    if Num(c.warband) and c.warband > 0 then
        others[#others + 1] = L.CRAFT_ST_WARBAND .. ": " .. c.warband
        n = n + c.warband
    end
    if ns.Keep and ns.Keep.AllChars and ns.Keep.AllChars() then
        for _, t in ipairs(others) do lines[#lines + 1] = t end
    elseif n > 0 then
        lines[#lines + 1] = GREY .. L.CRAFT_ST_OFF:format(n) .. "|r"
    end
    return lines
end

-- Kasten der Ergebniszeile (Kosten, Ertrag, Gewinn), Maus darueber: wie er sich ergibt
local function NewBox(b)
    local x = CreateFrame("Frame", nil, b)
    x:SetHeight(32)
    x.bg = x:CreateTexture(nil, "BACKGROUND")
    x.bg:SetAllPoints(x)
    x.label = FS(x)
    x.label:SetPoint("TOPLEFT", x, "TOPLEFT", 6, -4)
    x.value = FS(x)
    x.value:SetPoint("TOPLEFT", x, "TOPLEFT", 6, -18)
    x.value:SetPoint("RIGHT", x, "RIGHT", -4, 0)
    if x.EnableMouse then x:EnableMouse(true) end
    x:SetScript("OnEnter", function(self) mod:Call("Berufe", C.BoxTooltip, self, self.index) end)
    x:SetScript("OnLeave", HideTip)
    return x
end

local function Row(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(C.ROW_H)
    r.name, r.src, r.cost, r.sell = FS(r), FS(r), FS(r, "RIGHT"), FS(r, "RIGHT")
    return r
end

function C.CreateBlock(form)
    local b = C.block
    if b then
        if b.GetParent and b.SetParent and b:GetParent() ~= form then b:SetParent(form) end
        return b
    end
    b = CreateFrame("Frame", "PeonBrokerCraftBlock", form)
    b:SetSize(C.BLOCK_W, 120)
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetColorTexture(0.55, 0.45, 0.3, 0.6)
    b.line:SetHeight(1)
    b.line:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.line:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
    b.title = FS(b)
    b.title:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -9)
    b.title:SetText(("|c%sBroker|r"):format(Peon.COLOR))
    -- Zahnrad: alle Einstellungen der Anzeige
    local g = CreateFrame("Button", nil, b)
    g:SetSize(16, 16)
    g:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, -6)
    g:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    g:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    g:SetScript("OnClick", function(self) mod:Call("Berufe", C.ShowMenu, self) end)
    g:SetScript("OnEnter", function(self) Hint(self, L.CRAFT_MENU_HINT) end)
    g:SetScript("OnLeave", HideTip)
    b.gear = g
    -- Haken "Twinks mitzaehlen" (gleiche Einstellung wie im Reiter Behalten)
    b.ckText = FS(b)
    b.ckText:SetPoint("RIGHT", g, "LEFT", -8, 0)
    b.ckText:SetText(L.CRAFT_TWINKS)
    local ck = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate")
    ck:SetSize(20, 20)
    ck:SetPoint("RIGHT", b.ckText, "LEFT", 0, 0)
    ck:SetScript("OnClick", function(self) C.Set("keepAllChars", self:GetChecked() and true or false) end)
    ck:SetScript("OnEnter", function(self) Hint(self, L.CRAFT_TWINKS_HINT) end)
    ck:SetScript("OnLeave", HideTip)
    b.ck = ck
    -- Ergebniszeile
    b.boxes = { NewBox(b), NewBox(b), NewBox(b) }
    for i, x in ipairs(b.boxes) do x.index = i end
    -- Tabelle: Spaltenkoepfe, Zeilen je Material und Quelle, Gesamt
    b.head = Row(b)
    b.head.name:SetText(GREY .. L.CRAFT_COL_MAT .. "|r")
    b.head.src:SetText(GREY .. L.CRAFT_COL_SRC .. "|r")
    b.head.cost:SetText(GREY .. L.CRAFT_COL_COST .. "|r")
    b.head.sell:SetText(GREY .. L.CRAFT_COL_SELL .. "|r")
    b.rows = {}
    b.sep = b:CreateTexture(nil, "ARTWORK")
    b.sep:SetColorTexture(0.55, 0.45, 0.3, 0.4)
    b.sep:SetHeight(1)
    b.total = Row(b)
    b.hint = FS(b)
    if b.hint.SetWordWrap then b.hint:SetWordWrap(true) end
    C.block = b
    return b
end

-- Tabellenzeile i (Maus ueber dem Namen: Gegenstand, ueber Quelle, Kosten, Erloes: wie sich die Zeile ergibt)
local function MatRow(b, i)
    local r = b.rows[i]
    if r then return r end
    r = Row(b)
    if r.EnableMouse then r:EnableMouse(true) end
    r:SetScript("OnEnter", function(self)
        local m = self.line and self.line.mat
        if not m or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then pcall(GameTooltip.SetItemByID, GameTooltip, m.id) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", HideTip)
    r.hoverSrc, r.hoverCost, r.hoverSell = CreateFrame("Frame", nil, r), CreateFrame("Frame", nil, r), CreateFrame("Frame", nil, r)
    for _, h in ipairs({ r.hoverSrc, r.hoverCost, r.hoverSell }) do
        if h.EnableMouse then h:EnableMouse(true) end
        h:SetScript("OnEnter", function(self) mod:Call("Berufe", C.LineTooltip, self, r.line) end)
        h:SetScript("OnLeave", HideTip)
    end
    b.rows[i] = r
    return r
end

-- Spalten von rechts nach links: Erloes, Kosten, Quelle; der Name bekommt den Rest
local COLS = { { "sell", "craftColSell", "COL_MONEY" }, { "cost", "craftColCost", "COL_MONEY" }, { "src", "craftColSrc", "COL_SRC" } }
local function Columns(r)
    local x = 0
    for _, k in ipairs(COLS) do
        local on = IsOn(k[2])
        local fs = r[k[1]]
        fs:ClearAllPoints()
        if on then
            local w = C[k[3]]
            fs:SetPoint("TOPRIGHT", r, "TOPRIGHT", -x, 0)
            fs:SetWidth(w)
            x = x + w + 6
        end
        fs:SetShown(on and true or false)
    end
    r.name:ClearAllPoints()
    r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.name:SetPoint("TOPRIGHT", r, "TOPRIGHT", -x, 0)
end

local function Place(fr, b, y)
    fr:ClearAllPoints()
    fr:SetPoint("TOPLEFT", b, "TOPLEFT", 0, y)
    fr:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, y)
end

-- Betrag mit Minus, aber ohne Farbe
local function SMoney(v)
    if not v then return GREY .. "?|r" end
    if v < 0 then return "-" .. Money(-v) end
    return Money(v)
end

-- Hinweis unter der Tabelle: wofuer der Vorrat reicht (wenn nichts zu kaufen ist), darunter mit Material aus
-- dem Vorrat, was mehr bringt, mit beiden Betraegen. Gibt Text und Zahl der Zeilen zurueck.
function C.HintText(c)
    local lines = {}
    if not c.hasBuy then lines[1] = GREY .. L.CRAFT_ENOUGH:format(c.craftable) .. "|r" end
    if c.stockUsed and c.erl and c.craftNet and c.erl ~= c.craftNet then
        if c.sellBetter then lines[#lines + 1] = ORANGE .. L.CRAFT_SELL_BETTER:format(Money(c.erl), SMoney(c.craftNet)) .. "|r"
        else lines[#lines + 1] = GREY .. L.CRAFT_CRAFT_BETTER:format(SMoney(c.craftNet), Money(c.erl)) .. "|r" end
    end
    return table.concat(lines, "\n"), #lines
end

-- Unsichtbare Flaeche ueber einer Spalte fuer den Tooltip
function C.Cover(h, fs, on, w)
    h:ClearAllPoints()
    if on then
        h:SetPoint("TOPRIGHT", fs, "TOPRIGHT", 0, 0)
        h:SetSize(w, C.ROW_H)
        h:Show()
    else
        h:Hide()
    end
end

---------------------------------------------------------------------------
-- Tooltips im Block. Zeilen sind Tabellen { links, rechts } oder Texte ("#" vorne = Ueberschrift).
---------------------------------------------------------------------------
local function MatName(m, k) return (k and k > 1 and (k .. "× ") or "") .. (ns.GetItemInfo(m.id) or ("#" .. m.id)) end
local function M(v) return v and Money(v) or (GREY .. "?|r") end
local SRC_KEY = { stock = "CRAFT_SRC_STOCK", vendor = "CRAFT_SRC_VENDOR", ah = "CRAFT_SRC_AH", none = "CRAFT_SRC_NONE" }

-- Text der Spalte Quelle
function C.SrcText(line)
    local t = L[SRC_KEY[line.src] or "CRAFT_SRC_NONE"]
    if line.src == "none" then return ORANGE .. t .. "|r" end
    if line.est then return GREY .. t .. "|r" end
    return t
end

-- Herkunft des Haendlerpreises
local function VendorNote(m)
    if m.vsrc == "seen" then return m.vwho and L.CRAFT_TT_V_SEEN:format(m.vwho) or L.CRAFT_TT_V_SEEN_ANY end
    if m.vsrc == "ledger" then return L.CRAFT_TT_V_LEDGER end
    if m.vsrc == "est" then return L.CRAFT_TT_V_EST end
    return nil
end

function C.LineTipLines(line)
    local m = line.mat
    local t = { "#" .. MatName(m, line.n) }
    t[#t + 1] = { L.CRAFT_COL_SRC, C.SrcText(line) }
    if line.src == "stock" then
        for _, s in ipairs(C.StockLines(m)) do t[#t + 1] = GREY .. s .. "|r" end
        t[#t + 1] = { L.CRAFT_TT_OWN, m.own and Money(m.own) or (GREY .. L.CRAFT_TT_NONE .. "|r") }
        t[#t + 1] = { L.CRAFT_TT_AH_UNIT, m.ah and Money(m.ah) or (GREY .. L.CRAFT_TT_NO_OFFER .. "|r") }
        t[#t + 1] = { L.CRAFT_TT_ERL:format(line.n), M(line.erl) }
        if line.guess then t[#t + 1] = L.CRAFT_TT_OWN_GUESS end
        t[#t + 1] = L.CRAFT_TT_ERL_NOTE
    else
        t[#t + 1] = { L.CRAFT_TT_AH_UNIT, m.ah and Money(m.ah) or (GREY .. L.CRAFT_TT_NO_OFFER .. "|r") }
        t[#t + 1] = { L.CRAFT_TT_VENDOR_UNIT, m.vendor and ((m.vsrc == "est" and "~" or "") .. Money(m.vendor)) or (GREY .. L.CRAFT_TT_NONE .. "|r") }
        t[#t + 1] = { L.CRAFT_TT_STOCK, tostring(m.have) }
        local note = VendorNote(m)
        if note then t[#t + 1] = note end
    end
    return t
end

function C.BoxLines(c, i)
    local t = {}
    if i == 1 then
        t[1] = "#" .. L.CRAFT_TT_COST_HEAD
        if c.stockUsed then t[#t + 1] = { L.CRAFT_TT_COST_STOCK, Money(c.stockCost) } end
        if c.hasBuy then t[#t + 1] = { L.CRAFT_TT_COST_BUY, M(c.buy) .. (c.missing > 0 and (ORANGE .. " +?|r") or "") } end
        t[#t + 1] = L.CRAFT_TT_COST_NOTE
    elseif i == 2 then
        t[1] = "#" .. L.CRAFT_TT_VAL_HEAD
        t[#t + 1] = { L.CRAFT_TT_VAL_N, tostring(c.n) }
        t[#t + 1] = { L.CRAFT_TT_VAL_LOW, M(c.out and C.UnitCost(c.out)) }
        t[#t + 1] = L.CRAFT_TT_VAL_NOTE
    else
        t[1] = "#" .. L.CRAFT_TT_P_HEAD
        t[#t + 1] = { L.CRAFT_BOX_VALUE, M(c.value) }
        t[#t + 1] = { L.CRAFT_TT_P_MINUS, M(c.cost) .. (c.missing > 0 and (ORANGE .. " +?|r") or "") }
        t[#t + 1] = { L.CRAFT_BOX_PROFIT, C.ProfitText(c) }
        if c.stockUsed then
            t[#t + 1] = { " ", " " }
            t[#t + 1] = { L.CRAFT_TT_P_CRAFT, SMoney(c.craftNet) }
            t[#t + 1] = { L.CRAFT_TT_P_SELL, M(c.erl) }
        end
        t[#t + 1] = { GREY .. L.CRAFT_TT_P_ALL .. "|r", C.ProfitText({ profit = c.allProfit }) }
    end
    return t
end

local function ShowLines(owner, lines)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for _, x in ipairs(lines) do
        if type(x) == "table" then GameTooltip:AddDoubleLine(x[1], x[2], 1, 1, 1, 1, 1, 1)
        elseif x:sub(1, 1) == "#" then GameTooltip:AddLine(x:sub(2), 1, 0.82, 0)
        else GameTooltip:AddLine(x, 0.7, 0.7, 0.7, true) end
    end
    GameTooltip:Show()
end

function C.LineTooltip(owner, line)
    if type(line) == "table" then ShowLines(owner, C.LineTipLines(line)) end
end

function C.BoxTooltip(owner, i)
    local c = C.block and C.block.calc
    if type(c) == "table" and i then ShowLines(owner, C.BoxLines(c, i)) end
end

-- Block fuellen; true = Block zustaendig (auch wenn ausgeschaltet), false = Rueckfall auf die Box
function C.UpdateBlock()
    local form = C.Form()
    local anchor = form and C.ReagentAnchor(form)
    if not anchor then
        if C.block then C.block:Hide() end
        return false
    end
    local sel = C.SelectedRecipe()
    local rec = sel and C.ReadRecipe(sel)
    if not IsOn("craftBlock") or not rec then
        if C.block then C.block:Hide() end
        return true
    end
    local c = C.CalcFull(rec, rec.out, {})
    c.out = rec.out
    local b = C.CreateBlock(form)
    b.calc = c
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    local fw = form.GetWidth and form:GetWidth()
    local w = C.BLOCK_W
    if Num(fw) and fw > 100 then w = math.min(C.BLOCK_W, fw - 40) end
    b:SetWidth(w)
    -- Haken nur mit Ledger
    local led = ns.Keep and ns.Keep.Ledger and ns.Keep.Ledger() ~= nil
    b.ck:SetShown(led and true or false)
    b.ckText:SetShown(led and true or false)
    b.ck:SetChecked(DB().keepAllChars == true)

    local y = -28
    -- Ergebniszeile: Kosten, Ertrag, Gewinn
    local boxes = IsOn("craftSummary")
    for _, x in ipairs(b.boxes) do x:ClearAllPoints(); x:SetShown(boxes) end
    if boxes then
        local bw = math.floor((w - 12) / 3)
        local vals = {
            { L.CRAFT_BOX_COST, Money(c.cost) .. (c.missing > 0 and (ORANGE .. " +?|r") or "") },
            { c.n > 1 and L.CRAFT_BOX_VALUE_N:format(tostring(c.n)) or L.CRAFT_BOX_VALUE, c.value and Money(c.value) or (GREY .. "?|r") },
            { L.CRAFT_BOX_PROFIT, C.ProfitText(c) },
        }
        for i, x in ipairs(b.boxes) do
            x:SetPoint("TOPLEFT", b, "TOPLEFT", (i - 1) * (bw + 6), y)
            x:SetSize(bw, 32)
            x.label:SetText(GREY .. vals[i][1] .. "|r")
            x.value:SetText(vals[i][2])
            if i == 3 and c.profit and c.profit > 0 then x.bg:SetColorTexture(0.12, 0.25, 0.1, 0.6)
            elseif i == 3 and c.profit and c.profit < 0 then x.bg:SetColorTexture(0.3, 0.08, 0.08, 0.6)
            else x.bg:SetColorTexture(0.14, 0.12, 0.09, 0.6) end
        end
        y = y - 32 - 8
    end
    -- Tabelle
    Place(b.head, b, y)
    Columns(b.head)
    y = y - C.ROW_H
    for i, line in ipairs(c.lines) do
        local r = MatRow(b, i)
        r.line = line
        Place(r, b, y)
        Columns(r)
        r.name:SetText((line.n > 1 and (GREY .. line.n .. "× |r") or "") .. (ns.GetItemInfo(line.mat.id) or ("#" .. line.mat.id)))
        r.src:SetText(C.SrcText(line))
        local tilde = (line.guess or line.est) and (GREY .. "~|r") or ""
        r.cost:SetText(line.cost and (tilde .. Money(line.cost)) or (ORANGE .. "?|r"))
        if line.src == "stock" then r.sell:SetText(line.erl and Money(line.erl) or (GREY .. "?|r"))
        else r.sell:SetText(GREY .. "-|r") end
        C.Cover(r.hoverSrc, r.src, IsOn("craftColSrc"), C.COL_SRC)
        C.Cover(r.hoverCost, r.cost, IsOn("craftColCost"), C.COL_MONEY)
        C.Cover(r.hoverSell, r.sell, IsOn("craftColSell"), C.COL_MONEY)
        r:Show()
        y = y - C.ROW_H
    end
    for i = #c.lines + 1, #b.rows do b.rows[i]:Hide() end
    b.sep:ClearAllPoints()
    b.sep:SetPoint("TOPLEFT", b, "TOPLEFT", 0, y - 1)
    b.sep:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, y - 1)
    y = y - 3
    Place(b.total, b, y)
    Columns(b.total)
    b.total.name:SetText(L.CRAFT_TOTAL)
    b.total.src:SetText("")
    b.total.cost:SetText(Money(c.cost) .. (c.missing > 0 and (ORANGE .. " +?|r") or ""))
    b.total.sell:SetText(c.stockUsed and M(c.erl) or (GREY .. "-|r"))
    y = y - C.ROW_H
    -- Hinweis
    b.hint:ClearAllPoints()
    local text, lines = C.HintText(c)
    if IsOn("craftHint") and lines > 0 then
        y = y - 4
        b.hint:SetPoint("TOPLEFT", b, "TOPLEFT", 0, y)
        b.hint:SetWidth(w)
        b.hint:SetText(text)
        b.hint:Show()
        y = y - 14 * lines
    else
        b.hint:Hide()
    end
    b:SetHeight(-y + 4)
    b:Show()
    return true
end

---------------------------------------------------------------------------
-- Einstellungen: Zahnrad-Menue im Block und Optionsseite (gleiche Liste)
---------------------------------------------------------------------------
function C.MenuSpec()
    local s = {}
    local function T(text) s[#s + 1] = { kind = "title", text = text } end
    local function Chk(key, text, hint) s[#s + 1] = { kind = "check", key = key, text = text, hint = hint } end
    local function Radio(key, text, opts, hint) s[#s + 1] = { kind = "radio", key = key, text = text, opts = opts, hint = hint } end
    T(L.CRAFT_M_LIST)
    Chk("craftList", L.CRAFT_O_LIST, L.CRAFT_O_LIST_HINT)
    Radio("craftListWhich", L.CRAFT_O_WHICH, { { "all", L.CRAFT_W_ALL }, { "profit", L.CRAFT_W_PROFIT },
        { "top3", L.CRAFT_W_TOP:format(3) }, { "top5", L.CRAFT_W_TOP:format(5) }, { "top10", L.CRAFT_W_TOP:format(10) } })
    Radio("craftListMode", L.CRAFT_O_MODE, { { "money", L.CRAFT_MODE_MONEY }, { "pct", L.CRAFT_MODE_PCT } })
    Chk("craftListBest", L.CRAFT_O_BEST)
    Chk("craftListLoss", L.CRAFT_O_LOSS)
    Chk("craftListUnknown", L.CRAFT_O_UNKNOWN)
    T(L.CRAFT_M_RECIPE)
    Chk("craftBlock", L.CRAFT_O_BLOCK)
    Chk("craftSummary", L.CRAFT_O_SUMMARY)
    Chk("craftColSrc", L.CRAFT_O_SRC)
    Chk("craftColCost", L.CRAFT_O_COST)
    Chk("craftColSell", L.CRAFT_O_SELL)
    Chk("craftHint", L.CRAFT_O_HINT)
    Chk("keepAllChars", L.CRAFT_TWINKS, L.CRAFT_TWINKS_HINT)
    return s
end

function C.Set(key, value)
    mod.db[key] = value
    C.dirty = true
    if C.Frame() or C.Form() then mod:Call("Berufe", C.Tick) end
end

local fallbackMenu
function C.ShowMenu(owner)
    local db = mod.db
    local spec = C.MenuSpec()
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            for _, it in ipairs(spec) do
                if it.kind == "title" then root:CreateTitle(it.text)
                elseif it.kind == "check" then
                    root:CreateCheckbox(it.text, function() return db[it.key] == true end,
                        function() C.Set(it.key, not (db[it.key] == true)) end)
                elseif it.kind == "radio" then
                    local sub = root:CreateButton(it.text)
                    for _, o in ipairs(it.opts) do
                        sub:CreateRadio(o[2], function() return db[it.key] == o[1] end, function() C.Set(it.key, o[1]) end)
                    end
                end
            end
            root:CreateDivider()
            root:CreateButton(L.CRAFT_M_OPTIONS, function() mod:OpenOptions() end)
        end)
    elseif UIDropDownMenu_Initialize and ToggleDropDownMenu then
        if not fallbackMenu then
            fallbackMenu = CreateFrame("Frame", "PeonBrokerCraftMenu", UIParent, "UIDropDownMenuTemplate")
        end
        UIDropDownMenu_Initialize(fallbackMenu, function(_, level)
            local function Add(info) UIDropDownMenu_AddButton(info, level) end
            for _, it in ipairs(spec) do
                local info = UIDropDownMenu_CreateInfo()
                if it.kind == "title" then
                    info.text, info.isTitle, info.notCheckable = it.text, true, true
                    Add(info)
                elseif it.kind == "check" then
                    info.text, info.checked, info.isNotRadio, info.keepShownOnClick = it.text, db[it.key] == true, true, true
                    info.func = function() C.Set(it.key, not (db[it.key] == true)) end
                    Add(info)
                else
                    info.text, info.disabled, info.notCheckable = it.text .. ":", true, true
                    Add(info)
                    for _, o in ipairs(it.opts) do
                        local oi = UIDropDownMenu_CreateInfo()
                        oi.text, oi.checked = "   " .. o[2], db[it.key] == o[1]
                        oi.func = function() C.Set(it.key, o[1]) end
                        Add(oi)
                    end
                end
            end
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.notCheckable, info.func = L.CRAFT_M_OPTIONS, true, function() mod:OpenOptions() end
            Add(info)
        end, "MENU")
        ToggleDropDownMenu(1, nil, fallbackMenu, owner, 0, 0)
    else
        mod:OpenOptions()
    end
end

-- Abschnitt auf der Optionsseite (aus Options.lua)
function C.AddOptions(page, col)
    page:Add(col, page:Header(L.HDR_CRAFT), 6)
    local spec = C.MenuSpec()
    for i, it in ipairs(spec) do
        local gap = i == #spec and 16 or nil
        if it.kind == "title" then
            page:Add(col, page:Text(function() return "|cffffd100" .. it.text .. "|r" end), 4)
        elseif it.kind == "check" then
            page:Add(col, page:Check(it.key, it.text, it.hint), gap)
        else
            page:Add(col, page:Dropdown(it.key, it.text, it.opts, it.hint), gap)
        end
    end
end

-- Kennung der Einstellungen: aendert sich etwas (auch auf der Optionsseite), wird neu gerechnet
function C.Sig()
    local db, t = DB(), {}
    for _, it in ipairs(C.MenuSpec()) do
        if it.key then t[#t + 1] = tostring(db[it.key]) end
    end
    return table.concat(t, ",")
end

---------------------------------------------------------------------------
-- Takt, solange das Berufsfenster offen ist
---------------------------------------------------------------------------
function C.Tick()
    local sig = C.Sig()
    if sig ~= C.sig then C.sig = sig; C.dirty = true end
    local now = GetTime and GetTime() or 0
    if C.needRead and now - (C.readAt or -99) >= C.READ_GAP then
        C.ReadAll()
        C.dirty = true
    end
    if C.dirty then
        C.dirty = false
        C.Compute()
        C.Update()
    end
    C.DecorateList()
end

function C.Driver()
    local f = rawget(_G, "ProfessionsFrame")
    if C.driver or type(f) ~= "table" then return end
    local d = CreateFrame("Frame", nil, f)
    d.t = 0
    d:SetScript("OnUpdate", function(self, el)
        self.t = self.t + (tonumber(el) or 0)
        if self.t < 0.1 then return end
        self.t = 0
        mod:Call("Berufe", C.Tick)
    end)
    C.driver = d
    -- Zeilen der Rezeptliste sofort beschriften, wenn das Spiel sie (neu) belegt
    local sb = C.ListBox()
    if sb and ScrollUtil and type(ScrollUtil.AddInitializedFrameCallback) == "function" then
        pcall(ScrollUtil.AddInitializedFrameCallback, sb, function(_, row) mod:Call("Berufe", C.DecorateRow, row) end, C, false)
    end
end

-- /broker pruefen beruf: Aufbau des Berufsfensters (fuer die Anpassung an Forever)
function C.Probe()
    local out = {}
    local function Add(t) out[#out + 1] = t end
    local f = rawget(_G, "ProfessionsFrame")
    Add("ProfessionsFrame: " .. (type(f) == "table" and (Visible(f) and "sichtbar" or "versteckt") or "fehlt"))
    local page = type(f) == "table" and rawget(f, "CraftingPage")
    local form = type(page) == "table" and rawget(page, "SchematicForm")
    Add("SchematicForm: " .. (type(form) == "table" and (Visible(form) and "sichtbar" or "versteckt") or "fehlt"))
    if type(form) == "table" then
        local keys = {}
        for k, v in pairs(form) do
            if type(k) == "string" and type(v) == "table" and type(v.GetObjectType) == "function" then
                local _, _, t, bo = Rect(v)
                keys[#keys + 1] = k .. (Visible(v) and "" or "(aus)") .. (t and bo and ("@" .. math.floor(t) .. "/" .. math.floor(bo)) or "")
            end
        end
        table.sort(keys)
        Add("Teile: " .. table.concat(keys, " "))
        local a = C.ReagentAnchor(form)
        Add("Anker: " .. (a and (a == rawget(form, "Reagents") and "Reagents" or "OptionalReagents") or "keiner"))
    end
    local sb = C.ListBox()
    local n, hit = 0, 0
    if sb and type(sb.ForEachFrame) == "function" then
        pcall(sb.ForEachFrame, sb, function(row) n = n + 1; if RowRecipeID(row) then hit = hit + 1 end end)
    end
    Add("Rezeptliste: " .. (sb and (n .. " Zeilen, " .. hit .. " mit Rezept") or "fehlt"))
    Add("Gewaehlt: " .. tostring(C.SelectedRecipe()) .. ", Rezepte gelesen: " .. #(C.open or {}))
    if type(mod.acc) == "table" then mod.acc.craftProbe = out end
    for _, t in ipairs(out) do mod:Print(t) end
end
