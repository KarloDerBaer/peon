-- Peon_Profession - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Profession (Kern-Bausteine). Ab 0.8.0 nach dem Leitfaden fuer
-- Einstellungen: Reiter Allgemein und Anzeige. Kosten und Gewinn im Berufsfenster stellt man nur noch im Zahnrad am
-- Block ein (Craft.lua), die Pruefung laeuft ueber /prof pruefen.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

function ns.CreateOptions()
    local page = mod:NewOptionsPage({ desc = L.DESC, tipHints = true })   -- Hinweise als Tooltip (Kern-API 29)
    page:Tabs({ { "general", L.TAB_GENERAL }, { "display", L.TAB_DISPLAY } }, -58)

    local left = page:Column(16, -96, "general")
    page:Add(left, page:Button(L.OPEN, function() ns.Window.Open() end, L.OPEN_HINT), 16)
    page:Add(left, page:Header(L.HDR_MAIN), 6)
    page:Add(left, page:Check("minimapShow", L.MINIMAP, L.MINIMAP_HINT), 4)
    page:Add(left, page:Check("showAll", L.SHOW_ALL, L.SHOW_ALL_HINT), 4)
    page:Add(left, page:Check("altClick", L.ALTCLICK, L.ALTCLICK_TIP), 4)   -- ab 0.7.0
    page:Add(left, page:Check("stepSound", L.STEP_SOUND, L.STEP_SOUND_HINT))   -- ab 0.4.1

    local right = page:Column(330, -96, "general")
    page:Add(right, page:Header(L.HDR_CRAFT_WIN), 6)
    page:Add(right, page:Check("titleButton", L.TITLE_BUTTON, L.TITLE_BUTTON_HINT), 4)
    page:Add(right, page:Check("craftBar", L.CRAFT_BAR, L.CRAFT_BAR_HINT))

    local look = page:Column(16, -96, "display")
    page:Add(look, page:Header(L.HDR_SOUND), 6)
    page:Add(look, page:Dropdown("stepSoundKey", L.STEP_SOUND_KEY, {
        { "ready", L.SOUND_READY }, { "raid", L.SOUND_RAID }, { "tell", L.SOUND_TELL }, { "levelup", L.SOUND_LEVELUP } },
        L.STEP_SOUND_KEY_HINT))

    page:AddResetButton(L.SLASH_HINT, left, right, look)
    page:Register()
    return page
end

-- Hoerprobe beim Waehlen des Tons (ersetzt ab 0.8.0 den Knopf Probe)
mod:On("CHANGED", function(key)
    if key == "stepSoundKey" and ns.Measure and ns.Measure.Alert then ns.Measure.Alert(nil, true) end
end)
