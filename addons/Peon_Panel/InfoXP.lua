-- Peon_Panel - InfoXP.lua
-- XP, XP pro Stunde und Zeit bis zum naechsten Level.
-- Das Tempo zaehlt die letzten 60 Minuten statt der ganzen Sitzung, sonst drueckt jede Pause den Wert auf Dauer.
-- PeonPanelDB.xpLog = { who = Charakter, start = Beginn der Messung, b = { [Minute] = erhaltene XP } }

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

local WINDOW = 3600
local MIN_ELAPSED = 60

local XP = {}
ns.XP = XP

local lastXP, lastMax

local function Now() return time() end

local function Log()
    local log = mod.db.xpLog
    if log.who ~= UnitGUID("player") or type(log.b) ~= "table" then XP.Reset() end
    return mod.db.xpLog
end

function XP.Reset()
    mod.db.xpLog = { who = UnitGUID("player"), start = Now(), b = {} }
end

-- Auf der Hoechststufe gibt es nichts zu messen
function XP.AtMax()
    local util = rawget(_G, "GameRulesUtil")
    local level = ns.Num(UnitLevel("player"))
    if level and util and util.GetEffectiveMaxLevelForPlayer and level >= util.GetEffectiveMaxLevelForPlayer() then return true end
    local disabled = rawget(_G, "IsXPUserDisabled")
    if disabled and disabled() then return true end
    return (ns.Num(UnitXPMax("player")) or 0) <= 0
end

-- Erhaltene XP seit dem letzten Aufruf. Beim Levelaufstieg ist der neue Stand kleiner als der alte.
function XP.Update()
    local cur, max = ns.Num(UnitXP("player")), ns.Num(UnitXPMax("player"))
    if not cur or not max then return end
    if lastXP and lastMax then
        local gain = cur >= lastXP and cur - lastXP or lastMax - lastXP + cur
        if gain > 0 then
            local log = Log()
            local minute = math.floor(Now() / 60)
            log.b[minute] = (log.b[minute] or 0) + gain
            local oldest = math.floor((Now() - WINDOW) / 60)
            for m in pairs(log.b) do
                if m < oldest then log.b[m] = nil end
            end
        end
    end
    lastXP, lastMax = cur, max
end

-- XP je Stunde, gemessene XP, gemessene Sekunden. Rate nil = noch zu wenig Daten
function XP.Rate()
    local log = Log()
    local now = Now()
    local from = math.max(log.start or now, now - WINDOW)
    local oldest = math.floor(from / 60)
    local sum = 0
    for m, gain in pairs(log.b) do
        if m >= oldest then sum = sum + gain end
    end
    local elapsed = now - from
    if elapsed < MIN_ELAPSED or sum <= 0 then return nil, sum, elapsed end
    return sum / elapsed * 3600, sum, elapsed
end

function XP.Rest()
    local cur, max = ns.Num(UnitXP("player")), ns.Num(UnitXPMax("player"))
    if not cur or not max then return nil end
    return max - cur
end

-- Sekunden bis zum Level, nil = noch unbekannt
function XP.Eta()
    local rate = XP.Rate()
    local rest = XP.Rest()
    if not rate or not rest then return nil end
    return rest / rate * 3600
end

local function Percent(cur, max)
    return ("%.0f %%"):format(cur / max * 100)
end

local function Numbers()
    local cur, max = ns.Num(UnitXP("player")), ns.Num(UnitXPMax("player"))
    if not cur or not max or max <= 0 then return nil end
    return cur, max
end

local function RefreshAll()
    XP.Update()
    for _, key in ipairs({ "xp", "xpRate", "xpEta" }) do
        local def = ns.InfoDef[key]
        if def.launcher then def.launcher:Refresh() end
    end
end

local function Available() return not XP.AtMax() end

local function ResetEntry(_, root)
    root:CreateButton(L.XP_RESET, function()
        XP.Reset()
        RefreshAll()
    end)
end

local function MeasureLine(tt)
    local rate, sum, elapsed = XP.Rate()
    tt:AddLine(L.XP_TIP_MEASURE:format(Peon.ShortNumber(sum), ns.FormatDuration(elapsed)), 1, 1, 1)
    if rate then tt:AddLine(L.XP_TIP_RATE:format(Peon.ShortNumber(rate)), 1, 1, 1) end
end

ns.DefineInfo({
    key = "xp", title = L.XP_TITLE, icon = "Interface\\Icons\\INV_Misc_Book_11", bar = true, side = "left",
    available = Available, menu = ResetEntry, defaultText = "full",
    texts = {
        { key = "full", label = L.XP_FULL, get = function()
            local cur, max = Numbers()
            if not cur then return nil end
            return ("%s/%s (%s)"):format(Peon.ShortNumber(cur), Peon.ShortNumber(max), Percent(cur, max))
        end },
        { key = "percent", label = L.XP_PERCENT, get = function()
            local cur, max = Numbers()
            return cur and Percent(cur, max) or nil
        end },
        { key = "rest", label = L.XP_REST, get = function()
            local rest = XP.Rest()
            return rest and Peon.ShortNumber(rest) or nil
        end },
    },
    onTooltip = function(_, tt)
        local cur, max = Numbers()
        if not cur then return end
        tt:AddLine(L.XP_TIP_NOW:format(Peon.ShortNumber(cur), Peon.ShortNumber(max), Percent(cur, max)), 1, 1, 1)
        tt:AddLine(L.XP_TIP_REST:format(Peon.ShortNumber(max - cur)), 1, 1, 1)
        local rested = ns.Num(rawget(_G, "GetXPExhaustion") and GetXPExhaustion())
        if rested and rested > 0 then tt:AddLine(L.XP_TIP_RESTED:format(Peon.ShortNumber(rested)), 0.4, 0.7, 1) end
    end,
    events = { "UPDATE_EXHAUSTION" },
    init = function()
        mod:RegisterEvent("PLAYER_XP_UPDATE", function(_, unit)
            if unit == nil or unit == "player" then RefreshAll() end
        end)
        mod:RegisterEvent("PLAYER_LEVEL_UP", RefreshAll)
        -- Neue Sitzung, neue Messung. /reload misst weiter.
        mod:RegisterEvent("PLAYER_ENTERING_WORLD", function(_, isLogin)
            if isLogin then XP.Reset() end
            XP.Update()
        end)
    end,
})

ns.DefineInfo({
    key = "xpRate", title = L.XP_RATE_TITLE, icon = "Interface\\Icons\\Spell_Holy_BorrowedTime", bar = true, side = "left",
    noLabel = true, available = Available, menu = ResetEntry, defaultText = "rate", tick = 30,
    texts = {
        { key = "rate", label = L.XP_RATE_TITLE, get = function()
            local rate = XP.Rate()
            return rate and L.XP_RATE_TEXT:format(Peon.ShortNumber(rate)) or L.MEASURING
        end },
    },
    onTooltip = function(_, tt) MeasureLine(tt) end,
})

ns.DefineInfo({
    key = "xpEta", title = L.XP_ETA_TITLE, icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", bar = true, side = "left",
    label = L.XP_ETA_LABEL, available = Available, menu = ResetEntry, defaultText = "eta", tick = 30,
    texts = {
        { key = "eta", label = L.XP_ETA_TITLE, get = function()
            local eta = XP.Eta()
            return eta and ns.FormatDuration(eta) or L.MEASURING
        end },
    },
    onTooltip = function(_, tt)
        local rest = XP.Rest()
        if rest then tt:AddLine(L.XP_TIP_REST:format(Peon.ShortNumber(rest)), 1, 1, 1) end
        MeasureLine(tt)
    end,
})
