-- Peon_Bags - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Bags (Bausteine aus dem Peon-Kern).

local ADDON_NAME, ns = ...
local L = ns.L

function ns.CreateOptions()
    local mod = ns.mod
    if not mod or mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })
    local layouts = { { "bags", L.LAYOUT_BAGS }, { "type", L.LAYOUT_TYPE } }

    local left = page:Column(16, -60)
    page:Add(left, page:Header(L.HDR_GENERAL), 6)
    page:Add(left, page:Check("replace", L.REPLACE, L.REPLACE_HINT), 34)
    page:Add(left, page:Check("replaceGuild", L.REPLACE_GUILD), 20)
    page:Add(left, page:Text(function() return ns.BagnonLoaded() and L.STATUS_BAGNON or L.STATUS_OK end))

    page:Add(left, page:Header(L.HDR_BAGS), 6)
    page:Add(left, page:Slider("bagCols", L.COLS))
    page:Add(left, page:Slider("bagScale", L.SCALE, nil, "%"))
    page:Add(left, page:Dropdown("bagLayout", L.LAYOUT, layouts))
    page:Add(left, page:Check("bagBar", L.BAGBAR), 20)

    page:Add(left, page:Header(L.HDR_SLOTS), 6)
    page:Add(left, page:Check("quality", L.QUALITY), 20)
    page:Add(left, page:Check("newGlow", L.NEWGLOW), 20)
    page:Add(left, page:Check("junk", L.JUNK), 20)

    local right = page:Column(330, -60)
    page:Add(right, page:Header(L.HDR_BANK), 6)
    page:Add(right, page:Slider("bankCols", L.COLS))
    page:Add(right, page:Slider("bankScale", L.SCALE, nil, "%"))
    page:Add(right, page:Dropdown("bankLayout", L.LAYOUT, layouts))

    page:Add(right, page:Header(L.HDR_GUILD), 6)
    page:Add(right, page:Slider("guildCols", L.COLS))
    page:Add(right, page:Slider("guildScale", L.SCALE, nil, "%"))
    page:Add(right, page:Dropdown("guildLayout", L.LAYOUT, layouts))

    page:Add(right, page:Header(L.HDR_AUTO), 6)
    page:Add(right, page:Check("autoMerchant", L.AUTO_MERCHANT), 20)
    page:Add(right, page:Check("autoBank", L.AUTO_BANK), 20)
    page:Add(right, page:Check("autoMail", L.AUTO_MAIL), 20)
    page:Add(right, page:Check("autoAuction", L.AUTO_AUCTION), 20)
    page:Add(right, page:Check("autoTrade", L.AUTO_TRADE), 20)
    page:Add(right, page:Check("autoGuild", L.AUTO_GUILD), 20)
    page:Add(right, page:Button(L.RESET_POS, function()
        wipe(mod.db.pos)
        for _, w in pairs(ns.windows or {}) do if w.ApplyPosition then w:ApplyPosition() end end
        mod:Print(L.MSG_POS_RESET)
    end))

    page:AddResetButton(L.SLASH_HINT, left, right)
    page:Register()
end
