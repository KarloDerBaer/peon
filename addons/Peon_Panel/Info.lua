-- Peon_Panel - Info.lua
-- Allgemeine Eintraege (XP, Uhr, Zone usw.). Jeder ist ein eigener Starter (mod:AddLauncher, API 15).
--   ns.DefineInfo({ key, title, icon, texts, defaultText, onTooltip, onClick, onWheel, available, menu,
--                   bar = true,       -- beim ersten Start auf der Leiste, sonst nur zum Anhaken
--                   side = "right",   -- Bereich auf der Leiste, Standard links
--                   label = "Level",  -- Wort vor dem Text statt des Titels
--                   noLabel = true,   -- kein Wort vor dem Text
--                   tick = 1,         -- alle n Sekunden neu, nur solange angezeigt
--                   events = { "ZONE_CHANGED" }, -- bei diesen Ereignissen neu
--                   init = function(l) end })

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

local TICK = 0.5

local order = {}
ns.InfoDef = {}

function ns.DefineInfo(def)
    order[#order + 1] = def
    ns.InfoDef[def.key] = def
end

-- Blizzard-Fenster oeffnen: nur wenn es die Funktion gibt und nicht im Kampf, sonst koennte das Spiel es sperren
function ns.OpenBlizzard(name, ...)
    if Peon.InCombat() then return false end
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then return false end
    fn(...)
    return true
end

-- Zahl oder nil, geheime Werte sind nicht verwendbar
function ns.Num(v)
    if v == nil or Peon.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

function ns.Color(text, r, g, b)
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), text)
end

-- Dauer in kurzer Form: unter 1 Min., 12 Min., 1 Std. 24 Min., 3 T. 4 Std.
function ns.FormatDuration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 60 then return L.TIME_LESS_MIN end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return L.TIME_MIN:format(minutes) end
    local hours = math.floor(minutes / 60)
    if hours < 24 then return L.TIME_HOUR:format(hours, minutes % 60) end
    return L.TIME_DAY:format(math.floor(hours / 24), hours % 24)
end

function ns.InitInfos()
    local ticked = {}
    for _, def in ipairs(order) do
        local l = mod:AddLauncher({
            key = def.key, title = def.title, icon = def.icon, texts = def.texts, defaultText = def.defaultText,
            onTooltip = def.onTooltip, onClick = def.onClick, onWheel = def.onWheel, available = def.available,
            menu = def.menu,
        })
        def.launcher = l
        if def.init then mod:Call("Eintrag", def.init, l) end
        for _, event in ipairs(def.events or {}) do
            mod:RegisterEvent(event, function() l:Refresh() end)
        end
        if def.tick then ticked[#ticked + 1] = def end
    end
    ns.tickedInfos = ticked
end

-- Takt fuer alles, was sich laufend aendert. Nicht Angezeigtes kostet nur diese Pruefung.
function ns.TickInfos()
    for _, def in ipairs(ns.tickedInfos or {}) do
        def.wait = (def.wait or 0) - TICK
        if def.wait <= 0 then
            def.wait = def.tick
            if ns.IsDisplayed(def.launcher) then def.launcher:Refresh() end
        end
    end
end

function ns.StartInfoTicker()
    local timer = rawget(_G, "C_Timer")
    if timer and timer.NewTicker then timer.NewTicker(TICK, function() mod:Call("Eintrag", ns.TickInfos) end) end
end
