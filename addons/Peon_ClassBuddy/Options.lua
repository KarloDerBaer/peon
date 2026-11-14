-- Peon_ClassBuddy - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Klassenbuddy. Ein Reiter je Klasse, geoeffnet wird der
-- Reiter der eigenen Klasse. Die Einstellungen anderer Klassen lassen sich trotzdem ansehen und aendern.

local ADDON_NAME, ns = ...
local L = ns.L

local previewRow

function ns.UpdatePreview()
    if not previewRow or not ns.mod.db then return end
    ns.StyleRow(previewRow, 5)
    local alpha = ns.mod.db.showSockets and 1 or 0
    for _, pip in ipairs(previewRow.pips) do
        pip.socket:SetAlpha(alpha)
        pip.ring:SetAlpha(alpha)
    end
end

local function RogueTab(page)
    local left = page:Column(16, -100, "rogue")
    page:Add(left, page:Header(L.CP_HDR_LAYOUT), 6)
    page:Add(left, page:Slider("size", L.CP_SIZE))
    page:Add(left, page:Slider("gap", L.CP_GAP))
    page:Add(left, page:Slider("yOffset", L.CP_Y_OFFSET, L.CP_Y_OFFSET_HINT))
    page:Add(left, page:Slider("ringPad", L.CP_RING_PAD))
    page:Add(left, page:Check("showSockets", L.CP_SHOW_SOCKETS), 2)
    local hint = page:NewContainer(14)
    page:AddHint(hint, L.CP_SOCKETS_HINT, 0)
    page:Add(left, hint)

    local right = page:Column(330, -100, "rogue")
    page:Add(right, page:Header(L.CP_HDR_COLORS), 6)
    page:Add(right, page:Color("fillColor", L.CP_FILL, false), 6)
    page:Add(right, page:Color("socketColor", L.CP_SOCKET, true), 6)
    page:Add(right, page:Color("ringColor", L.CP_RING, true), 20)

    -- Vorschau: dieselben Punkte wie am Nameplate, alle mit Wert 3
    page:Add(right, page:Header(L.CP_HDR_PREVIEW), 10)
    local box = page:NewContainer(48)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
    previewRow = CreateFrame("Frame", nil, box)
    previewRow:SetPoint("LEFT", box, "LEFT", 12, 0)
    previewRow.pips = {}
    for i = 1, 5 do
        previewRow.pips[i] = ns.CreatePip(previewRow, i)
        previewRow.pips[i]:SetValue(3)
    end
    box.Refresh = ns.UpdatePreview
    page:Add(right, box)
    return left, right
end

local function WarlockTab(page)
    local left = page:Column(16, -100, "warlock")
    page:Add(left, page:Header(L.SH_HDR), 6)
    page:Add(left, page:Check("shardOn", L.SH_ON), 2)
    local rule = page:Add(left, page:Dropdown("shardRule", L.SH_RULE, { { "bag", L.SH_RULE_BAG }, { "max", L.SH_RULE_MAX } }, L.SH_RULE_HINT))
    local max = page:Add(left, page:Slider("shardMax", L.SH_MAX, L.SH_MAX_HINT))
    local action = page:Add(left, page:Check("shardAction", L.SH_ACTION, L.SH_ACTION_HINT), 2)
    local msg = page:Add(left, page:Check("shardMsg", L.SH_MSG), 2)

    local right = page:Column(330, -100, "warlock")
    page:Add(right, page:Header(L.SH_HDR_MANUAL), 6)
    page:Add(right, page:Text(function() return L.SH_MANUAL_TEXT end))
    page:Add(right, page:Button(L.SH_BTN_MACRO, function() ns.Shards.MakeMacro() end, L.SH_BTN_MACRO_HINT))
    page:Add(right, page:Text(function()
        local S = ns.Shards
        if not S.IsActive() then return L.SH_NOT_WARLOCK end
        local list, total = S.Surplus()
        return L.SH_REPORT:format(total, #list, S.Destroyed())
    end))

    page.onRefresh = function()
        local db = ns.mod.db
        if not db then return end
        local on = db.shardOn and 1 or 0.4
        for _, c in ipairs({ rule, action, msg }) do c:SetAlpha(on) end
        max:SetAlpha((db.shardOn and db.shardRule == "max") and 1 or ((db.shardOn) and 0.7 or 0.4))
    end
    return left, right
end

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })
    page:Tabs({ { "rogue", L.TAB_ROGUE }, { "warlock", L.TAB_WARLOCK } }, -62)
    local rl, rr = RogueTab(page)
    local wl, wr = WarlockTab(page)
    page:AddResetButton(L.SLASH_HINT, rl, rr, wl, wr)
    page:Register()
    if ns.PlayerClass() == "WARLOCK" then page:SelectTab("warlock") end
    ns.UpdatePreview()
end
