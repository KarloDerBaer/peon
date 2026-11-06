-- Peon_Feedback - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Feedback.

local ADDON_NAME, ns = ...
local L = ns.L

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })

    local left = page:Column(16, -60)
    page:Add(left, page:Header(L.HDR_MAIN), 6)
    page:Add(left, page:Check("minimapShow", L.MINIMAP), 20)
    page:Add(left, page:Button(L.OPEN, function() ns.Show() end))
    page:Add(left, page:Text(function() return L.COUNT:format((ns.Counts())) end))

    page:AddResetButton(L.SLASH_HINT, left)
    page:Register()
end
