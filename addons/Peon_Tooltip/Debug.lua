-- Peon_Tooltip - Debug.lua
-- /ttp debug: zeigt, welche Infos der Client fuer die Einheit unter der Maus liefert.
-- Dient zur Klaerung, ob Quest- und PvP-Symbole machbar sind.

local ADDON_NAME, ns = ...
local IsSecret = ns.IsSecret

local function S(v)
    if IsSecret(v) then return "<geheim>" end
    return tostring(v)
end

local function Run()
    local p = ns.Print
    local version, build, _, iface = GetBuildInfo()
    p(("Client %s (%s), Interface %s"):format(S(version), S(build), S(iface)))

    local unit = "mouseover"
    if not UnitExists(unit) then
        p("Keine Einheit unter der Maus. Maus auf ein Ziel legen, dann /ttp debug per Enter abschicken.")
        return
    end
    p("Einheit: " .. S(UnitName(unit)))

    -- PvP
    p(("PvP: UnitIsPVP=%s, FFA=%s, Fraktion=%s"):format(
        S(UnitIsPVP and UnitIsPVP(unit)),
        S(UnitIsPVPFreeForAll and UnitIsPVPFreeForAll(unit)),
        S(UnitFactionGroup and UnitFactionGroup(unit))))

    -- Rahmenfarbe
    local _, ttUnit = GameTooltip:GetUnit()
    p("Tooltip-Einheit: " .. S(ttUnit) .. ", Spieler=" .. S(UnitIsPlayer(unit)) .. ", PlayerControlled=" .. S(UnitPlayerControlled and UnitPlayerControlled(unit)))
    local function Col(name, fn, ...)
        if not fn then p(name .. ": nicht vorhanden") return end
        local ok, r, g, b = pcall(fn, ...)
        if type(r) == "table" and not IsSecret(r) then r, g, b = r.r, r.g, r.b end
        p(("%s: ok=%s r=%s g=%s b=%s"):format(name, S(ok), S(r), S(g), S(b)))
    end
    Col("GameTooltip_UnitColor", GameTooltip_UnitColor, unit)
    Col("UnitSelectionColor", UnitSelectionColor, unit)
    Col("UnitSelectionColor (erweitert)", UnitSelectionColor, unit, true)
    local inInstance, instanceType = IsInInstance()
    p("Instanz: " .. S(inInstance) .. " (" .. S(instanceType) .. "), im Kampf: " .. S(UnitAffectingCombat("player")))
    if ns.GetUnitColor then Col("Peon_Tooltip-Farbe", ns.GetUnitColor, unit, ns.GetDB() and ns.GetDB().borderMode) end
    local nine = GameTooltip.NineSlice
    p("NineSlice: " .. S(nine ~= nil) .. (nine and nine.GetBorderColor and (", Rahmen jetzt: " .. S(select(1, nine:GetBorderColor())) .. " " .. S(select(2, nine:GetBorderColor())) .. " " .. S(select(3, nine:GetBorderColor()))) or ""))

    -- Quest
    local api = C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest
    p("C_QuestLog.UnitIsRelatedToActiveQuest: " .. (api and S(api(unit)) or "nicht vorhanden"))
    local questie = (C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded)("Questie")
    p("Questie geladen: " .. S(questie))

    -- Tooltip-Daten
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local data = C_TooltipInfo.GetUnit(unit)
        local names = {}
        if Enum and Enum.TooltipDataLineType then
            for k, v in pairs(Enum.TooltipDataLineType) do names[v] = k end
        end
        if data and data.lines then
            for i, line in ipairs(data.lines) do
                p(("  Zeile %d [%s]: %s"):format(i, S(names[line.type] or line.type), S(line.leftText)))
            end
        else
            p("C_TooltipInfo.GetUnit lieferte keine Zeilen.")
        end
    else
        p("C_TooltipInfo nicht vorhanden.")
    end
end

function ns.Debug()
    local ok, err = pcall(Run)
    if not ok then ns.ReportError("Debug", err) end
end
