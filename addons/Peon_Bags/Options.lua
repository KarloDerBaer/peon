-- Peon_Bags - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Bags (Bausteine aus dem Peon-Kern).

local ADDON_NAME, ns = ...
local L = ns.L

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

-- Taschen automatisch oeffnen: sechs kleine Haken als ein Block, zwei je Reihe (ab 0.9.0)
local AUTO = { { "autoMerchant", "AUTO_MERCHANT" }, { "autoBank", "AUTO_BANK" }, { "autoMail", "AUTO_MAIL" },
               { "autoAuction", "AUTO_AUCTION" }, { "autoTrade", "AUTO_TRADE" }, { "autoGuild", "AUTO_GUILD" } }

function ns.AddAutoOptions(page, col)
    local mod = ns.mod
    local c = page:NewContainer(3 * 24)
    c.label = L.HDR_AUTO
    local boxes = {}
    for i, a in ipairs(AUTO) do
        local key = a[1]
        local cb = CreateFrame("CheckButton", nil, c, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", ((i - 1) % 2) * 145 - 4, -math.floor((i - 1) / 2) * 24)
        if cb.text then cb.text:SetText("") end
        if cb.Text then cb.Text:SetText("") end
        local fs = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        fs:SetText(L[a[2]])
        cb.key = key
        cb:SetScript("OnClick", function(b)
            if not mod.db then return end
            mod.db[key] = b:GetChecked() and true or false
            page:Changed(key)
        end)
        boxes[i] = cb
    end
    page:AddHint(c, L.AUTO_HINT, -3 * 24)
    c.boxes = boxes
    c.Refresh = function()
        if not mod.db then return end
        for _, cb in ipairs(boxes) do cb:SetChecked(mod.db[cb.key] == true) end
    end
    return page:Add(col, c)
end

-- Seite (ab 0.9.0 mit den Reitern Allgemein, Anzeige, Erweitert nach dem Leitfaden fuer Einstellungen)
function ns.CreateOptions()
    local mod = ns.mod
    if not mod or mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC, tipHints = true })   -- Hinweise als Tooltip (Kern-API 29)
    local layouts = { { "classic", L.LAYOUT_CLASSIC }, { "type", L.LAYOUT_TYPE }, { "custom", L.LAYOUT_CUSTOM } }
    page:Tabs({ { "general", L.TAB_GENERAL }, { "display", L.TAB_DISPLAY }, { "advanced", L.TAB_ADVANCED } }, -58)

    -- Allgemein: ersetzen und automatisch oeffnen
    local left = page:Column(16, -96, "general")
    page:Add(left, page:Check("replace", L.REPLACE, L.REPLACE_HINT), 4)
    page:Add(left, page:Check("replaceGuild", L.REPLACE_GUILD, L.REPLACE_GUILD_HINT), 8)
    page:Add(left, page:Text(function() return ns.BagnonLoaded() and L.STATUS_BAGNON or L.STATUS_OK end))
    local right = page:Column(330, -96, "general")
    page:Add(right, page:Header(L.HDR_AUTO), 6)
    ns.AddAutoOptions(page, right)

    -- Anzeige: Fenster und Plaetze
    local look = page:Column(16, -96, "display")
    page:Add(look, page:Header(L.HDR_BAGS), 6)
    page:Add(look, page:Slider("bagCols", L.COLS))
    page:Add(look, page:Slider("bagScale", L.SCALE, nil, "%"))
    page:Add(look, page:Dropdown("bagLayout", L.LAYOUT, layouts, L.LAYOUT_HINT))
    page:Add(look, page:Check("bagBar", L.BAGBAR, L.BAGBAR_HINT), 20)
    page:Add(look, page:Header(L.HDR_SLOTS), 6)
    page:Add(look, page:Check("quality", L.QUALITY, L.QUALITY_HINT), 4)
    page:Add(look, page:Check("newGlow", L.NEWGLOW, L.NEWGLOW_HINT), 4)
    page:Add(look, page:Check("junk", L.JUNK, L.JUNK_HINT))

    local lookRight = page:Column(330, -96, "display")
    page:Add(lookRight, page:Header(L.HDR_BANK), 6)
    page:Add(lookRight, page:Slider("bankCols", L.COLS))
    page:Add(lookRight, page:Slider("bankScale", L.SCALE, nil, "%"))
    page:Add(lookRight, page:Dropdown("bankLayout", L.LAYOUT, layouts, L.LAYOUT_HINT), 16)
    page:Add(lookRight, page:Header(L.HDR_GUILD), 6)
    page:Add(lookRight, page:Slider("guildCols", L.COLS))
    page:Add(lookRight, page:Slider("guildScale", L.SCALE, nil, "%"))
    page:Add(lookRight, page:Dropdown("guildLayout", L.LAYOUT, layouts, L.LAYOUT_HINT))

    -- Erweitert: Fensterpositionen, gespeicherte Charaktere
    local adv = page:Column(16, -96, "advanced")
    page:Add(adv, page:Text(function() return L.ADVANCED_NOTE end), 12)
    page:Add(adv, page:Button(L.RESET_POS, function()
        wipe(mod.db.pos)
        for _, w in pairs(ns.windows or {}) do if w.ApplyPosition then w:ApplyPosition() end end
        mod:Print(L.MSG_POS_RESET)
    end, L.RESET_POS_HINT), 20)
    page:Add(adv, page:Header(L.HDR_SAVED), 6)
    page:Add(adv, page:Text(function() return L.SAVED_HINT end), 6)
    ns.AddSavedOptions(page, adv)

    page:AddResetButton(L.SLASH_HINT, left, right, look, lookRight, adv)
    page:Register()
end
