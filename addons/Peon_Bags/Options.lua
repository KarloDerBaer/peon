-- Peon_Bags - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Bags (Bausteine aus dem Peon-Kern).

local ADDON_NAME, ns = ...
local L = ns.L

-- Eigene Bereiche: Liste und Knoepfe (ab 0.3)
function ns.AddGroupOptions(page, col)
    local mod = ns.mod
    local listC, list
    local selectedID
    local buttons = {}

    local function UpdateButtons()
        for _, b in ipairs(buttons) do
            if selectedID then b:Enable() else b:Disable() end
        end
    end

    local function Refresh()
        if not mod.db then return end
        local rows, sel = {}, nil
        for i, g in ipairs(ns.Groups()) do
            rows[i] = { id = g.id, pos = i, name = g.name, count = ns.CountGroup(g.id) }
            if g.id == selectedID then sel = rows[i] end
        end
        selectedID = sel and sel.id or nil
        list:SetData(rows)
        if sel then list:Select(sel) end
        UpdateButtons()
    end

    listC = page:List({
        columns = {
            { key = "pos", title = "#", width = 30, align = "RIGHT" },
            { key = "name", title = L.GROUP_COL_NAME, width = 170 },
            { key = "count", title = L.GROUP_COL_COUNT, width = 60, align = "RIGHT" },
        },
        rows = 6, rowHeight = 18, sortKey = "pos",
        emptyText = L.GROUP_LIST_EMPTY,
        onClick = function(_, item)
            selectedID = item.id
            UpdateButtons()
        end,
    })
    list = listC.list
    listC.Refresh = Refresh
    page:Add(col, listC, 4)

    local btnC = page:NewContainer(48)
    local function Btn(text, width, x, y, needsSelection, onClick)
        local b = ns.SmallButton(btnC, text, width, nil, onClick)
        b:SetPoint("TOPLEFT", x, y)
        if needsSelection then buttons[#buttons + 1] = b end
        return b
    end
    local function Move(delta)
        if ns.MoveGroup(selectedID, delta) then list:Sort("pos", false) end
    end
    Btn(L.GROUP_BTN_NEW, 70, 0, 0, false, function() StaticPopup_Show("PEON_BAGS_GROUP_NEW") end)
    Btn(L.GROUP_BTN_RENAME, 100, 74, 0, true, function()
        StaticPopup_Show("PEON_BAGS_GROUP_RENAME", nil, nil, selectedID)
    end)
    Btn(L.GROUP_BTN_DELETE, 80, 178, 0, true, function() ns.AskDeleteGroup(selectedID) end)
    Btn(L.GROUP_BTN_UP, 100, 0, -24, true, function() Move(-1) end)
    Btn(L.GROUP_BTN_DOWN, 100, 104, -24, true, function() Move(1) end)
    page:Add(col, btnC)

    ns.OnGroupAdded = function(g)
        selectedID = g.id
        Refresh()
    end
    mod:On("CHANGED", Refresh)
    Refresh()
end

-- Gespeicherte Staende der Charaktere: Liste mit Alter und Knopf Loeschen (ab 0.8)
function ns.AddSavedOptions(page, col)
    local mod = ns.mod
    local list, selected, delBtn
    local function Refresh()
        if not mod.db or not mod.SavedChars then return end
        local rows, sel = {}, nil
        for _, c in ipairs(mod:SavedChars()) do
            if c.bags or c.bank then
                rows[#rows + 1] = { name = c.name, bags = c.bags and ns.AgeText(c.bags) or "-",
                                    bank = c.bank and ns.AgeText(c.bank) or "-" }
                if c.name == selected then sel = rows[#rows] end
            end
        end
        selected = sel and sel.name or nil
        list:SetData(rows)
        if sel then list:Select(sel) end
        if delBtn then if selected then delBtn:Enable() else delBtn:Disable() end end
    end
    local listC = page:List({
        columns = {
            { key = "name", title = L.SAVED_COL_NAME, width = 130 },
            { key = "bags", title = L.SAVED_COL_BAGS, width = 70 },
            { key = "bank", title = L.SAVED_COL_BANK, width = 70 },
        },
        rows = 5, rowHeight = 18, sortKey = "name",
        emptyText = L.SAVED_LIST_EMPTY,
        onClick = function(_, item)
            selected = item.name
            if delBtn then delBtn:Enable() end
        end,
    })
    list = listC.list
    listC.Refresh = Refresh
    page:Add(col, listC, 4)
    local btnC = page:NewContainer(24)
    delBtn = ns.SmallButton(btnC, L.SAVED_DELETE, 150, L.SAVED_DELETE_TIP, function()
        if selected and StaticPopup_Show then StaticPopup_Show("PEON_BAGS_SAVED_DELETE", selected, nil, selected) end
    end)
    delBtn:SetPoint("TOPLEFT", 0, 0)
    page:Add(col, btnC)
    ns.OnSavedChanged = Refresh
    mod:On("LOGIN", Refresh)
    Refresh()
end

function ns.CreateOptions()
    local mod = ns.mod
    if not mod or mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })
    local layouts = { { "classic", L.LAYOUT_CLASSIC }, { "type", L.LAYOUT_TYPE }, { "custom", L.LAYOUT_CUSTOM } }

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

    page:Add(left, page:Header(L.HDR_GROUPS), 6)
    page:Add(left, page:Text(function() return L.GROUPS_HINT end), 6)
    ns.AddGroupOptions(page, left)

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

    -- Gespeicherte Staende (ab 0.8). Gehoert nach dem Leitfaden in den Reiter Erweitert, sobald die Seite Reiter hat.
    page:Add(right, page:Header(L.HDR_SAVED), 6)
    page:Add(right, page:Text(function() return L.SAVED_HINT end), 6)
    ns.AddSavedOptions(page, right)

    page:AddResetButton(L.SLASH_HINT, left, right)
    page:Register()
end
