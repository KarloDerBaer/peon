-- Peon_Tooltip - Style.lua
-- Groesse, Hintergrund-Deckkraft, Rahmenfarbe, Verhalten im Kampf.

local ADDON_NAME, ns = ...
local IsSecret = ns.IsSecret

local DEFAULT_BG = TOOLTIP_DEFAULT_BACKGROUND_COLOR or { r = 0.09, g = 0.09, b = 0.19 }
local DEFAULT_BORDER = TOOLTIP_DEFAULT_COLOR or { r = 1, g = 1, b = 1 }

local alphaTouched = {}
local borderTouched = {}

---------------------------------------------------------------------------
-- Low-Level: funktioniert mit NineSlice (neuere Clients) und Backdrop (alt)
---------------------------------------------------------------------------
local function SetBackground(tt, r, g, b, a)
    if tt.NineSlice and tt.NineSlice.SetCenterColor then
        tt.NineSlice:SetCenterColor(r, g, b, a)
    elseif tt.SetBackdropColor then
        tt:SetBackdropColor(r, g, b, a)
    end
end

local function SetBorder(tt, r, g, b)
    if tt.NineSlice and tt.NineSlice.SetBorderColor then
        tt.NineSlice:SetBorderColor(r, g, b)
    elseif tt.SetBackdropBorderColor then
        tt:SetBackdropBorderColor(r, g, b)
    end
end

function ns.SetTooltipAlpha(tt, a)
    tt:SetAlpha(a)
    alphaTouched[tt] = true
end

-- Deckkraft, die der Tooltip gerade haben soll (Kampf beruecksichtigt)
function ns.GetBaseAlpha()
    local db = ns.GetDB()
    if db and ns.inCombat and db.combatMode == "fade" then
        return db.combatAlpha / 100
    end
    return 1
end

function ns.ResetAlpha(tt)
    local a = ns.GetBaseAlpha()
    if a < 1 then
        ns.SetTooltipAlpha(tt, a)
    elseif alphaTouched[tt] then
        tt:SetAlpha(1)
        alphaTouched[tt] = nil
    end
end

---------------------------------------------------------------------------
-- Farbe einer Einheit (entspricht der Namensfarbe im Tooltip)
---------------------------------------------------------------------------
local function ToRGB(a, b, c)
    if not IsSecret(a) and type(a) == "table" then return a.r, a.g, a.b end
    return a, b, c
end

-- Achtung: in neueren Clients koennen Werte "geheim" sein. Geheime Werte darf
-- man nicht pruefen/vergleichen, aber an Widget-Funktionen weiterreichen.
-- Deshalb immer zuerst IsSecret() fragen und geheime Farben einfach durchreichen.
local function GetUnitColor(unit, mode)
    if mode == "class" then
        local isPlayer = UnitIsPlayer(unit)
        if not IsSecret(isPlayer) and isPlayer then
            local _, class = UnitClass(unit)
            local color = not IsSecret(class) and class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
            if color then return color.r, color.g, color.b end
        end
    end
    -- Haltung: UnitSelectionColor ist die Quelle der Haltungsfarben (auch fuer Spieler).
    -- GameTooltip_UnitColor liefert in diesem Client fuer Spieler nur Weiss (1,1,1).
    if UnitSelectionColor then
        local r, g, b = UnitSelectionColor(unit, true)   -- true = erweiterte Farben (z. B. grau fuer tot)
        if IsSecret(r) or IsSecret(g) or IsSecret(b) then return r, g, b end
        if r then
            -- reines Blau (freundlicher Spieler) ist auf dem Rahmen kaum sichtbar: etwas aufhellen
            if r == 0 and g == 0 and b == 1 then return 0.25, 0.5, 1 end
            return r, g, b
        end
    end
    if GameTooltip_UnitColor then
        local r, g, b = ToRGB(GameTooltip_UnitColor(unit))
        if IsSecret(r) or r then return r, g, b end
    end
    local reaction = UnitReaction(unit, "player")
    local c = not IsSecret(reaction) and reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if c then return c.r, c.g, c.b end
end
ns.GetUnitColor = GetUnitColor

---------------------------------------------------------------------------
-- Stil anwenden
---------------------------------------------------------------------------
local function ApplyBorder(tt, db)
    if db.borderMode ~= "none" and tt.GetUnit then
        local _, unit = tt:GetUnit()
        if IsSecret(unit) or unit then
            local ok, r, g, b = pcall(GetUnitColor, unit, db.borderMode)
            if ok and (IsSecret(r) or r) then
                local ok2, err = pcall(SetBorder, tt, r, g, b)
                if ok2 then
                    borderTouched[tt] = true
                    return
                end
                ns.ReportError("Border", err)
            elseif not ok then
                ns.ReportError("Border", r)
            end
        end
    end
    -- Gegenstand: Rahmen in der Farbe der Qualitaet (Items.lua)
    if ns.ItemBorderColor then
        local r, g, b = ns.ItemBorderColor(tt)
        if r then
            SetBorder(tt, r, g, b)
            borderTouched[tt] = true
            return
        end
    end
    if borderTouched[tt] then
        SetBorder(tt, DEFAULT_BORDER.r, DEFAULT_BORDER.g, DEFAULT_BORDER.b)
        borderTouched[tt] = nil
    end
end

-- Rahmen eines Gegenstands-Tooltips (auch Chat-Link- und Vergleichs-Tooltips) neu setzen
function ns.ApplyItemBorder(tt)
    local db = ns.GetDB()
    if not db or not tt or (tt.IsForbidden and tt:IsForbidden()) then return end
    local ok, err = pcall(ApplyBorder, tt, db)
    if not ok then ns.ReportError("Border", err) end
end

local extraScaled = { "ShoppingTooltip1", "ShoppingTooltip2" }

function ns.ApplyStyle(tt)
    local db = ns.GetDB()
    if not db or not tt or (tt.IsForbidden and tt:IsForbidden()) then return end

    local scale = db.scale / 100
    if tt:GetScale() ~= scale then tt:SetScale(scale) end
    if tt == GameTooltip then
        for _, name in ipairs(extraScaled) do
            local f = _G[name]
            if f and f.SetScale and f:GetScale() ~= scale then f:SetScale(scale) end
        end
    end

    SetBackground(tt, DEFAULT_BG.r, DEFAULT_BG.g, DEFAULT_BG.b, db.bgAlpha / 100)
    ApplyBorder(tt, db)
    ns.ResetAlpha(tt)
end

---------------------------------------------------------------------------
-- Kampf
---------------------------------------------------------------------------
local function ShouldHideInCombat(tt)
    local db = ns.GetDB()
    return db and ns.inCombat and db.combatMode == "hide"
        and ns.IsDefaultAnchored(tt)
        and not (db.combatShift and IsShiftKeyDown())
end

function ns.OnCombatChanged()
    if not GameTooltip:IsShown() then return end
    if ShouldHideInCombat(GameTooltip) then
        GameTooltip:Hide()
    else
        ns.ApplyStyle(GameTooltip)
    end
end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------
GameTooltip:HookScript("OnShow", function(tt)
    if ShouldHideInCombat(tt) then
        tt:Hide()
        return
    end
    ns.ApplyStyle(tt)
end)

-- Blizzard setzt Hintergrund/Rahmen beim Anzeigen zurueck: danach erneut anwenden
local function ReapplyAfterBlizzard(tt)
    if tt == GameTooltip or (tt and ns.previewTips and ns.previewTips[tt]) then
        ns.ApplyStyle(tt)
    elseif tt and ns.itemRecs and ns.itemRecs[tt] then
        ns.ApplyItemBorder(tt)      -- Chat-Link- und Vergleichs-Tooltips: nur der Rahmen
    end
end
for _, fname in ipairs({ "SharedTooltip_SetBackdropStyle", "GameTooltip_SetBackdropStyle" }) do
    if type(_G[fname]) == "function" then
        hooksecurefunc(fname, ReapplyAfterBlizzard)
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes or "ALL", ReapplyAfterBlizzard)
end
