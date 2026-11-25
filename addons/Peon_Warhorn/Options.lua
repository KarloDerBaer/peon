-- Peon_Warhorn - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Warhorn. Ab 0.6.0 nach dem Leitfaden fuer Einstellungen:
-- nur Allgemein, die Pruefung der Gruppensuche laeuft ueber /peon warhorn pruefen. Weitere Einstellungen stehen im Fenster.

local ADDON_NAME, ns = ...
local L = ns.L

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC, tipHints = true })   -- Hinweise als Tooltip (Kern-API 29)

    local left = page:Column(16, -60)
    page:Add(left, page:Button(L.BTN_OPEN, function() ns.Overlay.Toggle() end, L.BTN_OPEN_HINT), 16)
    page:Add(left, page:Header(L.HDR_MAIN), 6)
    page:Add(left, page:Check("show", L.OPT_SHOW, L.OPT_SHOW_HINT))

    page:AddResetButton(L.SLASH_HINT, left)
    page:Register()
end
