-- Peon_Panel - InfoSystem.lua
-- Haltbarkeit, Leistung, Spielzeit und Lautstaerke.
-- PeonPanelDB.session = { who = Charakter, start = Beginn der Sitzung, level = letzter Levelaufstieg }

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

---------------------------------------------------------------------------
-- Haltbarkeit: Ausruestungsplaetze 1 bis 19, nicht jeder Gegenstand hat Haltbarkeit
---------------------------------------------------------------------------
local WARN, DANGER = 50, 25

-- Niedrigster Wert in Prozent und die Liste { { slot, pct } }, schlechteste zuerst. nil = nichts mit Haltbarkeit
function ns.Durability()
    local list, lowest = {}, nil
    for slot = 1, 19 do
        local cur, max = GetInventoryItemDurability(slot)
        cur, max = ns.Num(cur), ns.Num(max)
        if cur and max and max > 0 then
            local pct = cur / max * 100
            list[#list + 1] = { slot = slot, pct = pct }
            if not lowest or pct < lowest then lowest = pct end
        end
    end
    table.sort(list, function(a, b)
        if a.pct ~= b.pct then return a.pct < b.pct end
        return a.slot < b.slot
    end)
    return lowest, list
end

local function DurabilityColor(pct)
    if pct < DANGER then return 1, 0.1, 0.1 end
    if pct < WARN then return 1, 0.8, 0 end
    return 1, 1, 1
end

ns.DefineInfo({
    key = "durability", title = L.DURA_TITLE, icon = "Interface\\Icons\\Trade_BlackSmithing", bar = true, side = "right",
    label = L.DURA_LABEL, defaultText = "low", events = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" },
    texts = {
        { key = "low", label = L.DURA_LOW, get = function()
            local lowest = ns.Durability()
            if not lowest then return "-" end
            local r, g, b = DurabilityColor(lowest)
            return ns.Color(("%.0f %%"):format(lowest), r, g, b)
        end },
    },
    onClick = function() ns.OpenBlizzard("ToggleCharacter", "PaperDollFrame") end,
    onTooltip = function(_, tt)
        local _, list = ns.Durability()
        if #list == 0 then
            tt:AddLine(L.DURA_NONE, 1, 1, 1)
            return
        end
        for _, e in ipairs(list) do
            local r, g, b = DurabilityColor(e.pct)
            tt:AddDoubleLine(GetInventoryItemLink("player", e.slot) or "?", ("%.0f %%"):format(e.pct), 1, 1, 1, r, g, b)
        end
    end,
})

---------------------------------------------------------------------------
-- Leistung
---------------------------------------------------------------------------
local function Fps() return math.floor((ns.Num(GetFramerate()) or 0) + 0.5) end

local function Latency()
    local _, _, home, world = GetNetStats()
    return ns.Num(home) or 0, ns.Num(world) or 0
end

ns.DefineInfo({
    key = "perf", title = L.PERF_TITLE, icon = "Interface\\Icons\\INV_Gizmo_02", side = "right",
    noLabel = true, defaultText = "both", tick = 1,
    texts = {
        { key = "both", label = L.PERF_BOTH, get = function()
            local _, world = Latency()
            return L.PERF_TEXT:format(Fps(), world)
        end },
        { key = "fps", label = L.PERF_FPS, get = function() return L.PERF_FPS_TEXT:format(Fps()) end },
        { key = "ms", label = L.PERF_MS, get = function()
            local _, world = Latency()
            return L.PERF_MS_TEXT:format(world)
        end },
    },
    onTooltip = function(_, tt)
        local home, world = Latency()
        tt:AddLine(L.PERF_FPS_TEXT:format(Fps()), 1, 1, 1)
        tt:AddLine(L.PERF_TIP_HOME:format(home), 1, 1, 1)
        tt:AddLine(L.PERF_TIP_WORLD:format(world), 1, 1, 1)
    end,
})

---------------------------------------------------------------------------
-- Spielzeit. /played schreibt in den Chat, deshalb zaehlt Panel selbst.
---------------------------------------------------------------------------
local function StartSession()
    mod.db.session = { who = UnitGUID("player"), start = time(), level = time() }
end

local function Session()
    if mod.db.session.who ~= UnitGUID("player") then StartSession() end
    return mod.db.session
end

ns.DefineInfo({
    key = "playtime", title = L.PLAY_TITLE, icon = "Interface\\Icons\\Spell_Nature_TimeStop", side = "right",
    label = L.PLAY_LABEL, defaultText = "session", tick = 30,
    texts = {
        { key = "session", label = L.PLAY_SESSION, get = function() return ns.FormatDuration(time() - Session().start) end },
        { key = "level", label = L.PLAY_LEVEL, get = function() return ns.FormatDuration(time() - Session().level) end },
    },
    onTooltip = function(_, tt)
        local s = Session()
        tt:AddLine(L.PLAY_TIP_SESSION:format(ns.FormatDuration(time() - s.start)), 1, 1, 1)
        tt:AddLine(L.PLAY_TIP_LEVEL:format(ns.FormatDuration(time() - s.level)), 1, 1, 1)
    end,
    init = function()
        mod:RegisterEvent("PLAYER_ENTERING_WORLD", function(_, isLogin)
            if isLogin then StartSession() end
        end)
        mod:RegisterEvent("PLAYER_LEVEL_UP", function() Session().level = time() end)
    end,
})

---------------------------------------------------------------------------
-- Lautstaerke: Mausrad aendert sie, Klick schaltet den Ton an und aus
---------------------------------------------------------------------------
local VOLUME, SOUND_ON = "Sound_MasterVolume", "Sound_EnableAllSound"
local STEP = 0.05

local function GetCV(name) return (C_CVar and C_CVar.GetCVar or GetCVar)(name) end
local function SetCV(name, value) return (C_CVar and C_CVar.SetCVar or SetCVar)(name, value) end

local function Volume() return tonumber(GetCV(VOLUME)) or 0 end
local function SoundOn() return GetCV(SOUND_ON) ~= "0" end

function ns.ChangeVolume(delta)
    local v = math.max(0, math.min(1, Volume() + (delta > 0 and STEP or -STEP)))
    SetCV(VOLUME, ("%.2f"):format(v))
    local def = ns.InfoDef.volume
    if def.launcher then def.launcher:Refresh() end
end

ns.DefineInfo({
    key = "volume", title = L.VOL_TITLE, icon = "Interface\\Icons\\INV_Misc_Drum_01", side = "right",
    label = L.VOL_LABEL, defaultText = "pct", events = { "CVAR_UPDATE" },
    texts = {
        { key = "pct", label = L.VOL_TITLE, get = function()
            if not SoundOn() then return L.VOL_OFF end
            return ("%.0f %%"):format(Volume() * 100)
        end },
    },
    onClick = function()
        SetCV(SOUND_ON, SoundOn() and "0" or "1")
        ns.InfoDef.volume.launcher:Refresh()
    end,
    onWheel = function(_, delta) ns.ChangeVolume(delta) end,
    onTooltip = function(_, tt) tt:AddLine(L.VOL_TIP, 1, 1, 1, true) end,
})
