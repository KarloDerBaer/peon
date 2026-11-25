-- Peon_ClassBuddy - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Klassenbuddy. Ab 0.5.0 nach dem Leitfaden fuer Einstellungen:
-- Reiter Allgemein, Anzeige (nur Schurke: Combo-Punkte) und Erweitert. Es erscheinen nur die Teile der eigenen
-- Klasse. Ist die Klasse beim Laden noch unbekannt, alle untereinander.

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

-- abhaengige Einstellungen ausgrauen: mehrere Teile haengen sich an page.onRefresh
local function OnRefresh(page, fn)
    local prev = page.onRefresh
    page.onRefresh = function()
        if prev then prev() end
        if ns.mod.db then fn(ns.mod.db) end
    end
end

-- Anzeige (Schurke): Combo-Punkte mit Vorschau
local function RogueDisplay(page)
    local left = page:Column(16, -100, "display")
    page:Add(left, page:Header(L.CP_HDR_LAYOUT), 6)
    page:Add(left, page:Slider("size", L.CP_SIZE))
    page:Add(left, page:Slider("gap", L.CP_GAP))
    page:Add(left, page:Slider("yOffset", L.CP_Y_OFFSET, L.CP_Y_OFFSET_HINT))
    page:Add(left, page:Slider("ringPad", L.CP_RING_PAD))
    page:Add(left, page:Check("showSockets", L.CP_SHOW_SOCKETS, L.CP_SOCKETS_HINT))

    local right = page:Column(330, -100, "display")
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

-- Allgemein (Schurke): Gifte, Erinnerung, Makro
local function RogueGeneral(page, left, right)
    local kinds = {}
    for _, k in ipairs({ "instant", "deadly", "crippling", "mind", "wound", "none" }) do
        kinds[#kinds + 1] = { k, L["PO_KIND_" .. k] }
    end
    page:Add(left, page:Header(L.PO_HDR), 6)
    page:Add(left, page:Check("poisonOn", L.PO_ON, L.PO_ON_HINT), 4)
    local main = page:Add(left, page:Dropdown("poisonMain", L.PO_MAIN_SEL, kinds, L.PO_KIND_HINT))
    local off = page:Add(left, page:Dropdown("poisonOff", L.PO_OFF_SEL, kinds, L.PO_KIND_HINT))
    local replace = page:Add(left, page:Check("poisonReplace", L.PO_REPLACE, L.PO_REPLACE_HINT), 16)

    page:Add(right, page:Header(L.PO_HDR_WARN), 6)
    local warn = page:Add(right, page:Check("poisonWarn", L.PO_WARN, L.PO_WARN_HINT), 4)
    local sound = page:Add(right, page:Check("poisonSound", L.PO_SOUND, L.PO_SOUND_HINT), 16)
    page:Add(right, page:Header(L.PO_HDR_KEY), 6)
    page:Add(right, page:Button(L.PO_BTN_MACRO, function() ns.Poisons.MakeMacro() end,
        L.PO_KEY_TEXT .. "\n\n" .. L.PO_BTN_MACRO_HINT), 16)

    OnRefresh(page, function(db)
        local on = db.poisonOn and 1 or 0.4
        for _, c in ipairs({ main, off, replace, warn }) do c:SetAlpha(on) end
        sound:SetAlpha((db.poisonOn and db.poisonWarn) and 1 or 0.4)
    end)
end

-- Allgemein (Hexenmeister): Seelensplitter, Makro
local function WarlockGeneral(page, left, right)
    page:Add(left, page:Header(L.SH_HDR), 6)
    page:Add(left, page:Check("shardOn", L.SH_ON, L.SH_ON_HINT), 4)
    local rule = page:Add(left, page:Dropdown("shardRule", L.SH_RULE, { { "free", L.SH_RULE_FREE }, { "bag", L.SH_RULE_BAG }, { "max", L.SH_RULE_MAX } }, L.SH_RULE_HINT))
    local action = page:Add(left, page:Check("shardAction", L.SH_ACTION, L.SH_ACTION_HINT), 4)
    local msg = page:Add(left, page:Check("shardMsg", L.SH_MSG, L.SH_MSG_HINT), 16)

    page:Add(right, page:Header(L.SH_HDR_MANUAL), 6)
    page:Add(right, page:Button(L.SH_BTN_MACRO, function() ns.Shards.MakeMacro() end,
        L.SH_MANUAL_TEXT .. "\n\n" .. L.SH_BTN_MACRO_HINT), 16)

    OnRefresh(page, function(db)
        local on = db.shardOn and 1 or 0.4
        for _, c in ipairs({ rule, action, msg }) do c:SetAlpha(on) end
    end)
end

-- Erweitert: Grenzen und Zeiten
local function Advanced(page, rogue, warlock)
    local col = page:Column(16, -100, "advanced")
    page:Add(col, page:Text(function() return L.ADVANCED_NOTE end), 12)
    if rogue then
        page:Add(col, page:Header(L.PO_HDR), 6)
        local renew = page:Add(col, page:Slider("poisonRenew", L.PO_RENEW, L.PO_RENEW_HINT))
        local charges = page:Add(col, page:Slider("poisonCharges", L.PO_CHARGES, L.PO_CHARGES_HINT))
        local low = page:Add(col, page:Slider("poisonLow", L.PO_LOW, L.PO_LOW_HINT), 16)
        OnRefresh(page, function(db)
            local on = db.poisonOn and 1 or 0.4
            renew:SetAlpha(on); charges:SetAlpha(on)
            low:SetAlpha((db.poisonOn and db.poisonWarn) and 1 or 0.4)
        end)
    end
    if warlock then
        page:Add(col, page:Header(L.SH_HDR), 6)
        local max = page:Add(col, page:Slider("shardMax", L.SH_MAX, L.SH_MAX_HINT))
        OnRefresh(page, function(db)
            max:SetAlpha((db.shardOn and db.shardRule == "max") and 1 or ((db.shardOn) and 0.7 or 0.4))
        end)
    end
    return col
end

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC, tipHints = true })   -- Hinweise als Tooltip (Kern-API 29)
    -- nur die Teile der eigenen Klasse. Ist die Klasse beim Laden noch unbekannt, alle.
    local class = ns.PlayerClass()
    local rogue, warlock = class == nil or class == "ROGUE", class == nil or class == "WARLOCK"
    local cols = {}
    if rogue or warlock then
        local tabs = { { "general", L.TAB_GENERAL } }
        if rogue then tabs[#tabs + 1] = { "display", L.TAB_DISPLAY } end
        tabs[#tabs + 1] = { "advanced", L.TAB_ADVANCED }
        page:Tabs(tabs, -62)
        local left = page:Column(16, -100, "general")
        local right = page:Column(330, -100, "general")
        cols[1], cols[2] = left, right
        if rogue then RogueGeneral(page, left, right) end
        if warlock then WarlockGeneral(page, left, right) end
        if rogue then
            local a, b = RogueDisplay(page)
            cols[#cols + 1], cols[#cols + 2] = a, b
        end
        cols[#cols + 1] = Advanced(page, rogue, warlock)
    else
        local col = page:Column(16, -70)
        page:Add(col, page:Text(function() return L.NO_CLASS end))
        cols[1] = col
    end
    page:AddResetButton(L.SLASH_HINT, unpack(cols))
    page:Register()
    ns.UpdatePreview()
end
