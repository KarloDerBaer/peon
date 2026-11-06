-- Peon_Panel - Options.lua
-- Optionsseite: Reiter Allgemein (Leiste, Panel) und Symbole (je Modul: wo es erscheint, welcher Text).

local ADDON_NAME, ns = ...
local L = ns.L

local function Visibility()
    return { { "always", L.VIS_ALWAYS }, { "hover", L.VIS_HOVER }, { "combat", L.VIS_COMBAT } }
end

-- Eigener Haken, der nicht direkt in mod.db schreibt (Wert kommt vom gewaehlten Modul)
local function Check(page, parent, label, y, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", -4, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", cb, "TOPRIGHT", 2, -6)
    fs:SetText(label)
    cb:SetScript("OnClick", function(self) page.mod:Call("Optionen", onClick, self:GetChecked() and true or false) end)
    return cb
end

local function AddSymbols(page, col)
    local mod = page.mod
    local selectedKey
    local listC, list, textC, cbMinimap, cbBar, cbBox

    local function Selected() return selectedKey and ns.starters[selectedKey] or nil end

    local function Mark(v) return v and L.YES or L.NO end

    local function UpdateControls()
        local l = Selected()
        local e = l and ns.Entry(l.key)
        cbBar:SetChecked(e and e.bar or false)
        cbBox:SetChecked(e and e.box or false)
        cbMinimap:SetChecked(l and l:IsMinimapShown() or false)
        if l then cbBar:Enable(); cbBox:Enable() else cbBar:Disable(); cbBox:Disable() end
        if l and l:HasMinimap() then cbMinimap:Enable() else cbMinimap:Disable() end
        textC.Refresh()
    end

    local function Refresh()
        if not mod.db then return end
        local rows, sel = {}, nil
        for key, l in pairs(ns.starters) do
            local e = ns.Entry(key)
            local row = { key = key, name = l.title, minimap = l:HasMinimap() and Mark(l:IsMinimapShown()) or L.NO,
                          bar = Mark(e and e.bar), box = Mark(e and e.box), text = ns.TextLabel(l) }
            rows[#rows + 1] = row
            if key == selectedKey then sel = row end
        end
        list:SetData(rows)
        if sel then list:Select(sel) else selectedKey = nil end
        UpdateControls()
    end

    listC = page:List({
        columns = {
            { key = "name", title = L.COL_MODULE, width = 130 },
            { key = "minimap", title = L.COL_MINIMAP, width = 60 },
            { key = "bar", title = L.COL_BAR, width = 60 },
            { key = "box", title = L.COL_BOX, width = 60 },
            { key = "text", title = L.COL_TEXT, width = 190 },
        },
        rows = 8, rowHeight = 18, sortKey = "name",
        emptyText = L.LIST_EMPTY,
        onClick = function(_, item)
            selectedKey = item.key
            UpdateControls()
        end,
    })
    list = listC.list
    listC.Refresh = Refresh
    page:Add(col, listC, 8)

    local checks = page:NewContainer(26 * 3)
    cbMinimap = Check(page, checks, L.SYM_MINIMAP, 0, function(on)
        local l = Selected()
        if l then ns.SetMinimap(l, on) end
    end)
    cbBar = Check(page, checks, L.SYM_BAR, -26, function(on)
        local l = Selected()
        if l then ns.SetOnSurface(l, "bar", on) end
    end)
    cbBox = Check(page, checks, L.SYM_BOX, -52, function(on)
        local l = Selected()
        if l then ns.SetOnSurface(l, "box", on) end
    end)
    page:Add(col, checks, 6)

    textC = page:Dropdown("symText", L.SYM_TEXT, function()
        local l = Selected()
        local options = { { ns.TEXT_NONE, L.MENU_NO_TEXT } }
        if l then
            for _, t in ipairs(l.texts) do options[#options + 1] = { t.key, t.label } end
        end
        return options
    end, nil, {
        get = function()
            local l = Selected()
            local e = l and ns.Entry(l.key)
            return e and e.text or nil
        end,
        set = function(v)
            local l = Selected()
            if l then ns.SetText(l, v) end
        end,
        empty = L.SYM_NONE,
    })
    page:Add(col, textC)

    mod:On("CHANGED", Refresh)
    ns.RefreshSymbolList = Refresh
    ns.SymbolControls = { list = listC, text = textC, minimap = cbMinimap, bar = cbBar, box = cbBox,
                          select = function(key) selectedKey = key; Refresh() end }
end

function ns.CreateOptions()
    local mod = ns.mod
    if not mod or mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })
    page:Tabs({ { "general", L.TAB_GENERAL }, { "symbols", L.TAB_SYMBOLS } }, -62)

    local left = page:Column(16, -100, "general")
    page:Add(left, page:Header(L.HDR_BAR), 6)
    page:Add(left, page:PositionGrid("barPos", L.BAR_POS))
    page:Add(left, page:Slider("barX", L.BAR_X))
    page:Add(left, page:Slider("barY", L.BAR_Y))
    page:Add(left, page:Slider("barSize", L.SIZE))
    page:Add(left, page:Check("barBg", L.BACKGROUND), 6)
    page:Add(left, page:Dropdown("barVis", L.VISIBILITY, Visibility()))

    local right = page:Column(330, -100, "general")
    page:Add(right, page:Header(L.HDR_BOX), 6)
    page:Add(right, page:Check("boxShow", L.BOX_SHOW), 6)
    page:Add(right, page:Slider("boxCols", L.BOX_COLS))
    page:Add(right, page:Slider("boxSize", L.SIZE))
    page:Add(right, page:Check("boxBg", L.BACKGROUND), 6)
    page:Add(right, page:Check("boxLocked", L.BOX_LOCKED), 6)
    page:Add(right, page:Dropdown("boxVis", L.VISIBILITY, Visibility()))
    page:Add(right, page:Button(L.BOX_RESET, function()
        wipe(mod.db.boxPos)
        ns.ApplyAll()
        mod:Print(L.MSG_BOX_RESET)
    end))

    local symbols = page:Column(16, -100, "symbols")
    page:Add(symbols, page:Text(function() return L.SYM_HINT end), 8)
    AddSymbols(page, symbols)

    page:AddResetButton(L.SLASH_HINT, left, right, symbols)
    page:Register()
end
