-- Peon_Beispiel - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Beispiel (Bausteine aus dem Peon-Kern).

local ADDON_NAME, ns = ...
local L = ns.L

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })

    local left = page:Column(16, -60)
    page:Add(left, page:Header(L.HDR_MAIN), 6)
    page:Add(left, page:Check("enabled", L.ENABLED), 20)
    local sizeCtl = page:Add(left, page:Slider("size", L.SIZE, L.SIZE_HINT))
    page:Add(left, page:Dropdown("mode", L.MODE, { { "a", L.MODE_A }, { "b", L.MODE_B } }))

    page:AddResetButton(L.SLASH_HINT, left)

    -- abhaengige Einstellungen ausgrauen
    page.onRefresh = function()
        local db = mod.db
        if db then sizeCtl:SetAlpha(db.enabled and 1 or 0.4) end
    end

    page:Register()
end
