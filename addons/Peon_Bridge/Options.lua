-- Peon_Bridge - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Bridge. Der Knopf "An Manager" am Auktionshaus entfaellt ab 0.9.2.

local ADDON_NAME, ns = ...
local L = ns.L

StaticPopupDialogs["PEON_BRIDGE_CLEAR"] = {
    text = "%s", button1 = YES or "Ja", button2 = NO or "Nein",
    OnAccept = function()
        ns.mod.acc.queue = {}
        ns.mod:Print(L.CLEARED)
        if ns.mod.page then ns.mod.page:Refresh() end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })

    local left = page:Column(16, -60)
    page:Add(left, page:Header(L.HDR_STATUS), 6)
    page:Add(left, page:Text(function() return table.concat(ns.StatusLines(), "\n") end), 12)
    page:Add(left, page:Header(L.HDR_HANDOVER), 6)
    page:Add(left, page:Slider("queueMax", L.QUEUE_MAX, L.QUEUE_MAX_HINT))
    page:Add(left, page:Slider("liveMax", L.LIVE_MAX, L.LIVE_MAX_HINT))
    page:Add(left, page:Button(L.SEND, function() ns.Send() end, L.SEND_HINT))
    page:Add(left, page:Button(L.CLEAR, function()
        local n = #(mod.acc.queue or {})
        if n == 0 then return end
        if StaticPopup_Show then StaticPopup_Show("PEON_BRIDGE_CLEAR", L.CLEAR_CONFIRM:format(n)) end
    end, L.CLEAR_HINT))
    page:Add(left, page:Header(L.HDR_VALUES), 6)
    page:Add(left, page:Slider("freshDays", L.FRESH_DAYS, L.FRESH_DAYS_HINT))

    page:AddResetButton(L.SLASH_HINT, left)
    page:Register()
end
