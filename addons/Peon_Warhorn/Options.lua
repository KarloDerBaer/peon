-- Peon_Warhorn - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Warhorn.

local ADDON_NAME, ns = ...
local L = ns.L

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })

    local left = page:Column(16, -60)
    page:Add(left, page:Header(L.HDR_MAIN), 6)
    page:Add(left, page:Check("show", L.OPT_SHOW, L.OPT_SHOW_HINT), 30)
    page:Add(left, page:Header(L.HDR_PROBE), 6)
    page:Add(left, page:Text(function() return L.PROBE_HINT end), 10)
    page:Add(left, page:Button(L.BTN_PROBE, function() ns.Probe.Start("click") end, L.BTN_PROBE_HINT), 34)
    page:Add(left, page:Text(function() return ns.Probe.LastText() end), 10)

    page:AddResetButton(L.SLASH_HINT, left)
    page:Register()
end
