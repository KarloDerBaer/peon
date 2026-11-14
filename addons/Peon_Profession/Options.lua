-- Peon_Profession - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Profession (Kern-Bausteine)

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

function ns.CreateOptions()
    local page = mod:NewOptionsPage({ desc = L.DESC })
    local left = page:Column(16, -60)
    page:Add(left, page:Header(L.HDR_MAIN))
    page:Add(left, page:Check("minimapShow", L.MINIMAP))
    page:Add(left, page:Check("craftBar", L.CRAFT_BAR, L.CRAFT_BAR_HINT))
    page:Add(left, page:Button(L.OPEN, function() ns.Window.Open() end))
    page:AddResetButton(L.SLASH_HINT, left)
    page:Register()
    return page
end
