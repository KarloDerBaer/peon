-- Peon_Panel - InfoPlace.lua
-- Uhr, Zone, Koordinaten und Reset-Zeiten.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

---------------------------------------------------------------------------
-- Uhr
---------------------------------------------------------------------------
local function ServerTime()
    local h, m = GetGameTime()
    h, m = ns.Num(h), ns.Num(m)
    if not h or not m then return nil end
    return ("%02d:%02d"):format(h, m)
end

local function LocalTime() return date("%H:%M") end

ns.DefineInfo({
    key = "clock", title = L.CLOCK_TITLE, icon = "Interface\\Icons\\INV_Misc_PocketWatch_02", bar = true, side = "right",
    noLabel = true, defaultText = "local", tick = 1,
    texts = {
        { key = "local", label = L.CLOCK_LOCAL, get = LocalTime },
        { key = "server", label = L.CLOCK_SERVER, get = ServerTime },
    },
    onClick = function()
        if not ns.OpenBlizzard("ToggleCalendar") then ns.OpenBlizzard("ToggleTimeManager") end
    end,
    onTooltip = function(_, tt)
        tt:AddLine(L.CLOCK_TIP_LOCAL:format(LocalTime()), 1, 1, 1)
        local server = ServerTime()
        if server then tt:AddLine(L.CLOCK_TIP_SERVER:format(server), 1, 1, 1) end
    end,
})

---------------------------------------------------------------------------
-- Zone
---------------------------------------------------------------------------
local ZONE_COLOR = {
    sanctuary = { 0.41, 0.80, 0.94 },
    arena     = { 1.00, 0.10, 0.10 },
    friendly  = { 0.10, 1.00, 0.10 },
    hostile   = { 1.00, 0.10, 0.10 },
    contested = { 1.00, 0.70, 0.00 },
    combat    = { 1.00, 0.10, 0.10 },
}

-- Art des Gebiets: freundlich, feindlich, umkaempft usw., nil = unbekannt
local function PvpType()
    local pvp = rawget(_G, "C_PvP")
    local fn = pvp and pvp.GetZonePVPInfo or rawget(_G, "GetZonePVPInfo")
    if not fn then return nil end
    local kind = fn()
    if kind == nil or Peon.IsSecret(kind) then return nil end
    return kind
end

local function Tint(text)
    if text == nil or text == "" then return nil end
    local c = ZONE_COLOR[PvpType() or ""]
    if not c then return text end
    return ns.Color(text, c[1], c[2], c[3])
end

-- Unterzone, wenn sie sich von der Zone unterscheidet
local function SubZone()
    local sub = GetSubZoneText()
    if sub == nil or sub == "" or Peon.IsSecret(sub) or sub == GetZoneText() then return nil end
    return sub
end

local function OpenMap() ns.OpenBlizzard("ToggleWorldMap") end

ns.DefineInfo({
    key = "zone", title = L.ZONE_TITLE, icon = "Interface\\Icons\\INV_Misc_Map_01", bar = true, side = "center",
    noLabel = true, defaultText = "zone", onClick = OpenMap,
    events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" },
    texts = {
        { key = "zone", label = L.ZONE_ZONE, get = function() return Tint(GetZoneText()) end },
        { key = "sub", label = L.ZONE_SUB, get = function() return Tint(SubZone() or GetZoneText()) end },
        { key = "both", label = L.ZONE_BOTH, get = function()
            local sub = SubZone()
            return Tint(sub and (GetZoneText() .. ": " .. sub) or GetZoneText())
        end },
    },
    onTooltip = function(_, tt)
        tt:AddLine(GetZoneText(), 1, 1, 1)
        local sub = SubZone()
        if sub then tt:AddLine(sub, 1, 1, 1) end
        local kind = PvpType()
        if kind and L["ZONE_KIND_" .. kind] then tt:AddLine(L["ZONE_KIND_" .. kind], 0.7, 0.7, 0.7) end
    end,
})

---------------------------------------------------------------------------
-- Koordinaten: in Instanzen gibt das Spiel keine heraus
---------------------------------------------------------------------------
function ns.PlayerCoords()
    local map = C_Map.GetBestMapForUnit("player")
    if map == nil or Peon.IsSecret(map) then return nil end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return nil end
    local x, y = ns.Num(pos.x), ns.Num(pos.y)
    if not x or not y or (x == 0 and y == 0) then return nil end
    return x * 100, y * 100
end

local function CoordsText()
    local x, y = ns.PlayerCoords()
    if not x then return "-" end
    local text = ("%.1f / %.1f"):format(x, y)
    if GetLocale() == "deDE" then text = text:gsub("%.", ",") end
    return text
end

ns.DefineInfo({
    key = "coords", title = L.COORDS_TITLE, icon = "Interface\\Icons\\INV_Misc_Spyglass_02", bar = true, side = "center",
    noLabel = true, defaultText = "xy", tick = 0.5, onClick = OpenMap,
    texts = { { key = "xy", label = L.COORDS_TITLE, get = CoordsText } },
    onTooltip = function(_, tt) tt:AddLine(L.COORDS_TIP, 1, 1, 1, true) end,
})

---------------------------------------------------------------------------
-- Reset-Zeiten
---------------------------------------------------------------------------
local function ResetIn(name)
    local fn = C_DateAndTime and C_DateAndTime[name]
    local seconds = fn and ns.Num(fn())
    return seconds and ns.FormatDuration(seconds) or nil
end

ns.DefineInfo({
    key = "resets", title = L.RESET_TITLE, icon = "Interface\\Icons\\INV_Misc_PocketWatch_03", side = "right",
    label = L.RESET_LABEL, defaultText = "daily", tick = 30,
    texts = {
        { key = "daily", label = L.RESET_DAILY, get = function() return ResetIn("GetSecondsUntilDailyReset") end },
        { key = "weekly", label = L.RESET_WEEKLY, get = function() return ResetIn("GetSecondsUntilWeeklyReset") end },
    },
    onTooltip = function(_, tt)
        local daily, weekly = ResetIn("GetSecondsUntilDailyReset"), ResetIn("GetSecondsUntilWeeklyReset")
        if daily then tt:AddLine(L.RESET_TIP_DAILY:format(daily), 1, 1, 1) end
        if weekly then tt:AddLine(L.RESET_TIP_WEEKLY:format(weekly), 1, 1, 1) end
    end,
})
