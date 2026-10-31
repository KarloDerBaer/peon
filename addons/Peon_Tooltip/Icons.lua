-- Peon_Tooltip - Icons.lua
-- PvP-Symbol und Quest-Symbol am Tooltip.

local ADDON_NAME, ns = ...
local IsSecret = ns.IsSecret
local issecrettable = issecrettable
local function IsSecretTable(t)
    return t ~= nil and issecrettable ~= nil and issecrettable(t) == true
end

local PVP_TEX = {
    Alliance = "Interface\\TargetingFrame\\UI-PVP-Alliance",
    Horde    = "Interface\\TargetingFrame\\UI-PVP-Horde",
    FFA      = "Interface\\TargetingFrame\\UI-PVP-FFA",
}
-- Die PvP-Texturen sind 64x64, das Wappen sitzt oben links
local PVP_COORDS = { 0, 0.62, 0, 0.62 }
local QUEST_TEX = "Interface\\GossipFrame\\AvailableQuestIcon"

-- Richtung, in die ein zweites Symbol an derselben Stelle ausweicht
local STACK = {
    TOPLEFT = { 1, 0 }, TOP = { 1, 0 }, TOPRIGHT = { -1, 0 },
    LEFT = { 0, -1 }, RIGHT = { 0, -1 },
    BOTTOMLEFT = { 1, 0 }, BOTTOM = { 1, 0 }, BOTTOMRIGHT = { -1, 0 },
}

local icons = {}

local function HideAll(tt)
    local t = icons[tt]
    if t then
        t.pvp:Hide()
        t.quest:Hide()
    end
end

local function GetIcons(tt)
    local t = icons[tt]
    if not t then
        t = {
            pvp   = tt:CreateTexture(nil, "OVERLAY", nil, 7),
            quest = tt:CreateTexture(nil, "OVERLAY", nil, 7),
        }
        t.pvp:Hide()
        t.quest:Hide()
        icons[tt] = t
        tt:HookScript("OnHide", HideAll)
    end
    return t
end

-- Symbol mittig auf die Kante/Ecke setzen (halb ausserhalb, verdeckt keinen Text)
local function Place(tt, tex, pos, size, slot)
    local d = STACK[pos] or STACK.TOPRIGHT
    tex:SetSize(size, size)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", tt, pos, d[1] * slot * (size + 2), d[2] * slot * (size + 2))
    tex:Show()
end

local function GetPvPTexture(unit)
    if UnitIsPVPFreeForAll then
        local ffa = UnitIsPVPFreeForAll(unit)
        if IsSecret(ffa) then return nil end
        if ffa then return PVP_TEX.FFA end
    end
    if not UnitIsPVP then return nil end
    local pvp = UnitIsPVP(unit)
    if IsSecret(pvp) or not pvp then return nil end
    local faction = UnitFactionGroup(unit)
    if IsSecret(faction) or not faction then return nil end
    return PVP_TEX[faction]
end

local function IsQuestUnit(tt, unit, data)
    local isPlayer = UnitIsPlayer(unit)
    if IsSecret(isPlayer) or isPlayer then return false end

    -- 1) Tooltip-Daten: offene Quest-Ziele?
    data = data or (tt.GetTooltipData and tt:GetTooltipData())
    -- in Instanzen koennen die Tooltip-Daten geheime Tabellen sein: dann nicht anfassen
    if IsSecretTable(data) or (data and IsSecretTable(data.lines)) then data = nil end
    local LT = Enum and Enum.TooltipDataLineType
    if data and data.lines and LT and LT.QuestObjective then
        local total, open = 0, 0
        for _, line in ipairs(data.lines) do
            if not IsSecret(line.type) and line.type == LT.QuestObjective then
                total = total + 1
                local done = line.completed
                if IsSecret(done) or not done then open = open + 1 end
            end
        end
        if total > 0 then return open > 0 end
    end

    -- 2) direkte Abfrage
    local api = C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest
    if api then
        local related = api(unit)
        return not IsSecret(related) and related == true
    end
    return false
end

function ns.UpdateIcons(tt, data)
    local db = ns.GetDB()
    if not db or not (tt == GameTooltip or (ns.IsMainTip and ns.IsMainTip(tt))) then return end
    local t = GetIcons(tt)
    t.pvp:Hide()
    t.quest:Hide()

    local _, unit = tt:GetUnit()
    if IsSecret(unit) or not unit then return end

    local used = {}
    if db.pvpIcon ~= "none" then
        local tex = GetPvPTexture(unit)
        if tex then
            t.pvp:SetTexture(tex)
            t.pvp:SetTexCoord(PVP_COORDS[1], PVP_COORDS[2], PVP_COORDS[3], PVP_COORDS[4])
            Place(tt, t.pvp, db.pvpIcon, db.iconSize, 0)
            used[db.pvpIcon] = 1
        end
    end
    if db.questIcon ~= "none" and IsQuestUnit(tt, unit, data) then
        t.quest:SetTexture(QUEST_TEX)
        t.quest:SetTexCoord(0, 1, 0, 1)
        Place(tt, t.quest, db.questIcon, db.iconSize, used[db.questIcon] or 0)
    end
end

function ns.SafeUpdateIcons(tt, data)
    local ok, err = pcall(ns.UpdateIcons, tt, data)
    if not ok then
        HideAll(tt)
        ns.ReportError("Icons", err)
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes or "ALL", function(tt, data)
        if (tt == GameTooltip or (ns.IsMainTip and ns.IsMainTip(tt))) then ns.SafeUpdateIcons(tt, data) end
    end)
else
    GameTooltip:HookScript("OnTooltipSetUnit", function(tt) ns.SafeUpdateIcons(tt) end)
    GameTooltip:HookScript("OnTooltipCleared", HideAll)
end
