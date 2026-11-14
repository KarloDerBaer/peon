-- Peon_Profession - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Profession (Kern-Bausteine). Ab 0.2.0 rechts die Einstellungen
-- fuer Kosten und Gewinn im Berufsfenster (gleiche Liste wie das Zahnrad am Block, Craft.lua).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

function ns.CreateOptions()
    local page = mod:NewOptionsPage({ desc = L.DESC })
    local left = page:Column(16, -60)
    local right = page:Column(330, -60)
    page:Add(left, page:Header(L.HDR_MAIN))
    page:Add(left, page:Check("minimapShow", L.MINIMAP))
    page:Add(left, page:Check("showAll", L.SHOW_ALL, L.SHOW_ALL_HINT))
    page:Add(left, page:Button(L.OPEN, function() ns.Window.Open() end), 16)
    page:Add(left, page:Header(L.HDR_CRAFT_WIN), 6)
    page:Add(left, page:Check("titleButton", L.TITLE_BUTTON))
    page:Add(left, page:Check("craftBar", L.CRAFT_BAR, L.CRAFT_BAR_HINT))
    page:Add(left, page:Text(function() return L.PROBE_HINT end), 16)
    if ns.Craft and ns.Craft.AddOptions then ns.Craft.AddOptions(page, right) end
    page:AddResetButton(L.SLASH_HINT, left, right)
    page:Register()
    return page
end
