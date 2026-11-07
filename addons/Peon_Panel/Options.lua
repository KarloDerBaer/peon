-- Peon_Panel - Options.lua
-- Optionsseite: Reiter Allgemein (Leiste, Panel) und Symbole (je Modul: wo es erscheint, welcher Text).

local ADDON_NAME, ns = ...
local L = ns.L

local function Visibility()
    return { { "always", L.VIS_ALWAYS }, { "hover", L.VIS_HOVER }, { "combat", L.VIS_COMBAT }, { "fold", L.VIS_FOLD } }
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
    local listC, list, textC, showC, sideC, rowC, scopeC, cbMinimap, cbBar, cbBox, cbLabel
    local scope = "bar"   -- Text, Anzeige und Beschriftung gelten fuer Leiste oder Panel (ab 0.3.0)

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
        cbLabel:SetChecked(l and ns.LabelOf(l.key, scope) or false)
        if l and #l.texts > 0 then cbLabel:Enable() else cbLabel:Disable() end
        scopeC.Refresh()
        textC.Refresh()
        showC.Refresh()
        sideC.Refresh()
        rowC.Refresh()
    end

    local function Refresh()
        if not mod.db then return end
        local rows, sel = {}, nil
        for key, l in pairs(ns.starters) do
            local e = ns.Entry(key)
            local row = { key = key, name = l.title, minimap = l:HasMinimap() and Mark(l:IsMinimapShown()) or L.NO,
                          bar = Mark(e and e.bar), box = Mark(e and e.box), side = ns.SIDE_LABEL[ns.SideOf(key)],
                          text = ns.TextLabel(l) }
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
            { key = "side", title = L.COL_SIDE, width = 60 },
            { key = "text", title = L.COL_TEXT, width = 130 },
        },
        rows = 12, rowHeight = 18, sortKey = "name",
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

    scopeC = page:Dropdown("symScope", L.SYM_SCOPE, { { "bar", L.COL_BAR }, { "box", L.COL_BOX } }, nil, {
        get = function() return scope end,
        set = function(v)
            scope = v
            UpdateControls()
        end,
    })
    page:Add(col, scopeC)

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
            return l and ns.TextOf(l.key, scope) or nil
        end,
        set = function(v)
            local l = Selected()
            if l then ns.SetText(l, v, scope) end
        end,
        empty = L.SYM_NONE,
    })
    page:Add(col, textC)

    -- Auswahl aus einer festen Liste fuer das gewaehlte Modul
    local function Choice(key, label, values, labels, get, set)
        local options = {}
        for _, v in ipairs(values) do options[#options + 1] = { v, labels[v] } end
        return page:Dropdown(key, label, options, nil, {
            get = function()
                local l = Selected()
                return l and get(l.key) or nil
            end,
            set = function(v)
                local l = Selected()
                if l then set(l, v) end
            end,
            empty = L.SYM_NONE,
        })
    end
    showC = Choice("symShow", L.MENU_SHOW, ns.SHOWS, ns.SHOW_LABEL,
        function(key) return ns.ShowOf(key, scope) end, function(l, v) ns.SetShow(l, v, scope) end)
    page:Add(col, showC)
    local labelBox = page:NewContainer(26)
    cbLabel = Check(page, labelBox, L.SYM_LABEL, 0, function(on)
        local l = Selected()
        if l then ns.SetLabel(l, on, scope) end
    end)
    page:Add(col, labelBox, 6)
    -- Nur Leiste
    sideC = Choice("symSide", L.MENU_SIDE, ns.SIDES, ns.SIDE_LABEL, ns.SideOf, ns.SetSide)
    page:Add(col, sideC)
    rowC = Choice("symRow", L.SYM_ROW, ns.ROWS, ns.ROW_LABEL, ns.RowOf, ns.SetRow)
    page:Add(col, rowC)

    mod:On("CHANGED", Refresh)
    ns.RefreshSymbolList = Refresh
    ns.SymbolControls = { list = listC, text = textC, show = showC, side = sideC, row = rowC, scope = scopeC, minimap = cbMinimap, bar = cbBar, box = cbBox, label = cbLabel,
                          select = function(key) selectedKey = key; Refresh() end,
                          setScope = function(v) scope = v; UpdateControls() end }
end

function ns.CreateOptions()
    local mod = ns.mod
    if not mod or mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })
    page:Tabs({ { "general", L.TAB_GENERAL }, { "symbols", L.TAB_SYMBOLS }, { "look", L.TAB_LOOK } }, -62)

    local left = page:Column(16, -100, "general")
    page:Add(left, page:Header(L.HDR_BAR), 6)
    page:Add(left, page:Check("barShow", L.BAR_SHOW), 6)
    page:Add(left, page:Slider("barWidth", L.BAR_WIDTH, nil, " %"))
    page:Add(left, page:Slider("barSize", L.SIZE))
    page:Add(left, page:Check("barBg", L.BACKGROUND), 6)
    page:Add(left, page:Check("barLabels", L.BAR_LABELS), 6)
    page:Add(left, page:Slider("barRows", L.BAR_ROWS))
    page:Add(left, page:Dropdown("barVis", L.VISIBILITY, Visibility(), L.VIS_FOLD_BAR_HINT))

    local right = page:Column(330, -100, "general")
    page:Add(right, page:Header(L.HDR_BOX), 6)
    page:Add(right, page:Check("boxShow", L.BOX_SHOW), 6)
    page:Add(right, page:Slider("boxCols", L.BOX_COLS))
    page:Add(right, page:Slider("boxSize", L.SIZE))
    page:Add(right, page:Check("boxBg", L.BACKGROUND), 6)
    page:Add(right, page:Check("boxLocked", L.BOX_LOCKED), 6)
    page:Add(right, page:Check("boxLabels", L.BOX_LABELS), 6)
    page:Add(right, page:Dropdown("boxLayout", L.BOX_LAYOUT, { { "below", L.LAYOUT_BELOW }, { "right", L.LAYOUT_RIGHT } }))
    page:Add(right, page:Dropdown("boxVis", L.VISIBILITY, Visibility(), L.VIS_FOLD_HINT))
    page:Add(right, page:Dropdown("boxFoldDir", L.BOX_FOLD_DIR, {
        { "down", L.DIR_DOWN }, { "up", L.DIR_UP }, { "right", L.DIR_RIGHT }, { "left", L.DIR_LEFT } }))
    page:Add(right, page:Button(L.BOX_RESET, function()
        wipe(mod.db.boxPos)
        ns.ApplyAll()
        mod:Print(L.MSG_BOX_RESET)
    end))

    local symbols = page:Column(16, -100, "symbols")
    page:Add(symbols, page:Text(function() return L.SYM_HINT end), 8)
    AddSymbols(page, symbols)

    local look = page:Column(16, -100, "look")
    page:Add(look, page:Header(L.HDR_LOOK), 6)
    page:Add(look, page:Dropdown("style", L.STYLE, {
        { "tooltipDark", L.STYLE_TOOLTIPDARK }, { "tooltip", L.STYLE_TOOLTIP }, { "metal", L.STYLE_METAL },
        { "dialog", L.STYLE_DIALOG }, { "wood", L.STYLE_WOOD }, { "plain", L.STYLE_PLAIN },
    }, L.STYLE_HINT))
    page:Add(look, page:Color("bgColor", L.BG_COLOR, true), 6)
    page:Add(look, page:Color("lineColor", L.LINE_COLOR, true), 6)
    page:Add(look, page:Header(L.HDR_BAR_LOOK), 6)
    page:Add(look, page:Slider("barHeight", L.BAR_HEIGHT))
    page:Add(look, page:Slider("barGap", L.BAR_GAP))
    page:Add(look, page:Check("barSeps", L.BAR_SEPS), 6)

    local lookRight = page:Column(330, -100, "look")
    page:Add(lookRight, page:Header(L.HDR_FONT), 6)
    page:Add(lookRight, page:Dropdown("fontFace", L.FONT_FACE, {
        { "default", L.FONT_DEFAULT }, { "friz", L.FONT_FRIZ }, { "arial", L.FONT_ARIAL },
        { "morpheus", L.FONT_MORPHEUS }, { "skurri", L.FONT_SKURRI },
    }))
    page:Add(lookRight, page:Slider("fontSize", L.FONT_SIZE))
    page:Add(lookRight, page:Dropdown("fontStyle", L.FONT_STYLE, {
        { "none", L.FONT_NONE }, { "shadow", L.FONT_SHADOW }, { "outline", L.FONT_OUTLINE },
    }))
    page:Add(lookRight, page:Color("labelColor", L.LABEL_COLOR, false), 6)
    page:Add(lookRight, page:Color("valueColor", L.VALUE_COLOR, false), 6)
    page:Add(lookRight, page:Header(L.HDR_SYMBOLS), 6)
    page:Add(lookRight, page:Check("iconBorder", L.ICON_BORDER), 6)
    page:Add(lookRight, page:Dropdown("highlight", L.HIGHLIGHT, {
        { "soft", L.HL_SOFT }, { "glow", L.HL_GLOW }, { "none", L.HL_NONE },
    }))

    page:AddResetButton(L.SLASH_HINT, left, right, symbols, look, lookRight)
    page:Register()
end
