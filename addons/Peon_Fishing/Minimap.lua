-- Peon_Fishing - Minimap.lua
-- Minimap-Button: Linksklick = Angelmodus an/aus, Rechtsklick = Menue (Koeder, Fang-Uebersicht,
-- Optionen), ziehen = verschieben.

local ADDON_NAME, ns = ...
local L = ns.L

local FISHING_ICON = 136245
local btn

local function UpdatePosition()
    local angle = math.rad(ns.GetDB().minimapAngle or 200)
    local r = (Minimap:GetWidth() / 2) + 10
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    ns.GetDB().minimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    UpdatePosition()
end

local function ShowTooltip(self)
    local db = ns.GetDB()
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff8ccf4dPeon|r Fishing")
    local state = db.mode == "fishing" and L.MODE_FISHING or L.MODE_NORMAL
    if db.pending ~= "" then state = state .. " (" .. L["PENDING_" .. db.pending] .. ")" end
    GameTooltip:AddLine(state, 1, 1, 1)
    local fish = ns.SetInfo(db.fishingSetID)
    GameTooltip:AddLine(L.TT_FISHING_SET:format(fish and fish.name or L.NONE), 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L.TT_MINIMAP_HINT, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

function ns.UpdateButton()
    local db = ns.GetDB()
    if not btn or not db then return end
    btn:SetShown(db.showMinimap)
    local fishing = db.mode == "fishing"
    btn.icon:SetDesaturated(not fishing)
    if db.pending ~= "" or ns.IsSwapping() then
        btn.icon:SetVertexColor(1, 0.85, 0.3)
    else
        btn.icon:SetVertexColor(1, 1, 1)
    end
    if GameTooltip:GetOwner() == btn then ShowTooltip(btn) end
end

---------------------------------------------------------------------------
-- Rechtsklick-Menue: Koederwahl und Optionen
---------------------------------------------------------------------------
local function MenuItems()
    ns.ScanLures()
    local db = ns.GetDB()
    local items = {}
    items[#items + 1] = { title = L.LURE_TITLE .. "  |cffaaaaaa" .. ns.LureStatusText() .. "|r" }
    items[#items + 1] = { text = L.LURE_AUTO, value = "auto" }
    items[#items + 1] = { text = L.LURE_NONE_CHOICE, value = "none" }
    local lures = ns.GetLures()
    local found = false
    if #lures > 0 then items[#items + 1] = { divider = true } end
    for _, e in ipairs(lures) do
        local text = ("%s |cff88ff88+%d|r  x%d"):format(e.name, e.bonus, e.count)
        if not e.usable then text = "|cff888888" .. text .. " (" .. L.LURE_NOT_USABLE .. ")|r" end
        items[#items + 1] = { text = text, value = e.id }
        if db.lure == e.id then found = true end
    end
    if type(db.lure) == "number" and not found then
        local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(db.lure)) or ("item:" .. db.lure)
        items[#items + 1] = { text = "|cffff6060" .. name .. "  x0|r", value = db.lure }
    end
    items[#items + 1] = { divider = true }
    items[#items + 1] = { button = L.MENU_OVERVIEW, func = function() ns.ToggleOverview() end }
    items[#items + 1] = { button = L.MENU_OPTIONS, func = function() ns.OpenOptions() end }
    return items
end

local fallbackMenu
local function ShowMenu(owner)
    local db = ns.GetDB()
    local items = MenuItems()
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            local isSel = function(v) return ns.GetDB().lure == v end
            local setSel = function(v) ns.SetLureChoice(v) end
            for _, it in ipairs(items) do
                if it.title then root:CreateTitle(it.title)
                elseif it.divider then root:CreateDivider()
                elseif it.button then root:CreateButton(it.button, it.func)
                else root:CreateRadio(it.text, isSel, setSel, it.value) end
            end
        end)
    elseif UIDropDownMenu_Initialize and ToggleDropDownMenu then
        if not fallbackMenu then
            fallbackMenu = CreateFrame("Frame", "PeonFishingMinimapMenu", UIParent, "UIDropDownMenuTemplate")
        end
        UIDropDownMenu_Initialize(fallbackMenu, function(_, level)
            for _, it in ipairs(MenuItems()) do
                local info = UIDropDownMenu_CreateInfo()
                if it.title then
                    info.text, info.isTitle, info.notCheckable = it.title, true, true
                elseif it.divider then
                    info.text, info.disabled, info.notCheckable = "", true, true
                elseif it.button then
                    info.text, info.notCheckable, info.func = it.button, true, it.func
                else
                    info.text = it.text
                    info.checked = db.lure == it.value
                    info.func = function() ns.SetLureChoice(it.value) end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end, "MENU")
        ToggleDropDownMenu(1, nil, fallbackMenu, owner, 0, 0)
    else
        ns.OpenOptions()
    end
end

local function Create()
    btn = CreateFrame("Button", "PeonFishingMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(18, 18)
    btn.icon:SetTexture(FISHING_ICON)
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon:SetPoint("TOPLEFT", 7, -6)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            GameTooltip:Hide()
            ShowMenu(btn)
        else
            ns.Toggle()
        end
    end)
    btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", ShowTooltip)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
end

table.insert(ns.onLogin, function()
    Create()
    ns.UpdateButton()
end)
table.insert(ns.onModeChanged, function() ns.UpdateButton() end)
