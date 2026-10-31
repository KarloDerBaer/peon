-- Peon_Tooltip - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Tooltip (Bausteine aus dem Peon-Kern, API 6).
-- Positionen als Knopfreihe/Raster (man sieht die Lage), sonst Auswahllisten.

local ADDON_NAME, ns = ...
local L = ns.L

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })

    -- Untertabs (Kern API 11); aelterer Kern: alles auf einer Seite wie bisher
    local tabs = page.Tabs and true or false
    local Y = tabs and -100 or -60
    if tabs then
        page:Tabs({ { "general", L.TAB_GENERAL }, { "units", L.TAB_UNITS }, { "items", L.TAB_ITEMS } }, -62)
    end
    local function Col(x, tab) return page:Column(x, Y, tabs and tab or nil) end

    -- Reiter "Allgemein": Position, Aussehen, Kampf
    local gl = Col(16, "general")
    page:Add(gl, page:Header(L.HDR_POSITION), 6)
    page:Add(gl, page:Choice("corner", L.CORNER, {
        { "TOPLEFT", L.CORNER_TOPLEFT }, { "TOPRIGHT", L.CORNER_TOPRIGHT },
        { "BOTTOMLEFT", L.CORNER_BOTTOMLEFT }, { "BOTTOMRIGHT", L.CORNER_BOTTOMRIGHT },
    }, 2, 138))
    page:Add(gl, page:Slider("offsetX", L.OFFSET_X, L.OFFSET_X_HINT))
    page:Add(gl, page:Slider("offsetY", L.OFFSET_Y, L.OFFSET_Y_HINT))
    page:Add(gl, page:Check("edgeFlip", L.EDGE_FLIP), 20)

    local gr = Col(330, "general")
    page:Add(gr, page:Header(L.HDR_LOOK), 6)
    page:Add(gr, page:Slider("scale", L.SCALE, nil, "%"))
    page:Add(gr, page:Slider("bgAlpha", L.BG_ALPHA, nil, "%"), 20)
    page:Add(gr, page:Header(L.HDR_COMBAT), 6)
    page:Add(gr, page:Dropdown("combatMode", L.COMBAT_MODE, {
        { "normal", L.COMBAT_NORMAL }, { "fade", L.COMBAT_FADE }, { "hide", L.COMBAT_HIDE },
    }))
    local combatAlphaCtl = page:Add(gr, page:Slider("combatAlpha", L.COMBAT_ALPHA, nil, "%"))
    local combatShiftCtl = page:Add(gr, page:Check("combatShift", L.COMBAT_SHIFT))

    -- Reiter "Gegner": Rahmen, Spielerinfos, Ausblenden, Symbole; rechts Beispiel
    local ul = Col(16, "units")
    page:Add(ul, page:Header(L.HDR_UNITS), 6)
    page:Add(ul, page:Dropdown("borderMode", L.BORDER, {
        { "none", L.BORDER_NONE }, { "reaction", L.BORDER_REACTION }, { "class", L.BORDER_CLASS },
    }, L.BORDER_HINT))
    page:Add(ul, page:Check("playerInfo", L.PLAYER_INFO), 20)
    page:Add(ul, page:Header(L.HDR_FADE), 6)
    page:Add(ul, page:Check("fadeCustom", L.FADE_CUSTOM), 4)
    local fadeTimeCtl = page:Add(ul, page:Slider("fadeTime", L.FADE_TIME, L.FADE_HINT, "", 10), 20)
    page:Add(ul, page:Header(L.HDR_ICONS), 6)
    page:Add(ul, page:PositionGrid("pvpIcon", L.PVP_ICON))
    page:Add(ul, page:PositionGrid("questIcon", L.QUEST_ICON))
    page:Add(ul, page:Slider("iconSize", L.ICON_SIZE, L.ICON_HINT), 20)

    -- Reiter "Gegenstaende": Rahmen, Teile; rechts Beispiel
    local il = Col(16, "items")
    page:Add(il, page:Header(L.HDR_ITEMS), 6)
    page:Add(il, page:Dropdown("itemBorder", L.ITEM_BORDER, {
        { "default", L.ITEM_BORDER_DEFAULT }, { "quality", L.ITEM_BORDER_QUALITY },
    }))
    page:Add(il, page:Check("itemWrap", L.ITEM_WRAP, L.ITEM_WRAP_HINT))
    local maxWidthCtl = page:Add(il, page:Slider("itemMaxWidth", L.ITEM_MAX_WIDTH, L.ITEM_MAX_WIDTH_HINT, ""), 6)
    page:Add(il, page:Check("itemParts", L.ITEM_PARTS, L.ITEM_PARTS_HINT), 6)
    local partList = page:Add(il, ns.CreatePartList(page))

    local ur, ir
    if tabs then
        ur = Col(330, "units")
        page:Add(ur, page:Header(L.HDR_PREVIEW), 6)
        page:Add(ur, ns.CreatePreview(page, "unit"))
        ir = Col(330, "items")
        page:Add(ir, page:Header(L.HDR_PREVIEW), 6)
        page:Add(ir, ns.CreatePreview(page, "item"))
    end

    page:AddResetButton(L.SLASH_HINT, gl, gr, ul, il)

    -- abhaengige Einstellungen ausgrauen
    page.onRefresh = function()
        local db = mod.db
        if not db then return end
        combatAlphaCtl:SetAlpha(db.combatMode == "fade" and 1 or 0.4)
        combatShiftCtl:SetAlpha(db.combatMode == "hide" and 1 or 0.4)
        fadeTimeCtl:SetAlpha(db.fadeCustom and 1 or 0.4)
        partList:SetAlpha(db.itemParts and 1 or 0.4)
        maxWidthCtl:SetAlpha(db.itemWrap and 1 or 0.4)
    end
    page.onTab = function() if ns.UpdatePreviews then ns.UpdatePreviews() end end

    page:Register()
end

---------------------------------------------------------------------------
-- Beispiel-Tooltips (ab 0.7): Einheit (Ziel, sonst du selbst) und Gegenstand (eigene Gegenstaende,
-- mit Pfeilen umschaltbar). Sie laufen durch dieselben Anpassungen wie der echte Tooltip.
---------------------------------------------------------------------------
ns.previewTips = {}
local previews = {}

function ns.IsMainTip(tt)
    return tt == GameTooltip or (tt ~= nil and ns.previewTips[tt] == true)
end

-- eigene Gegenstaende: angelegt (Waffe zuerst), dann Taschen
local function ItemCandidates()
    local list = {}
    local slots = { 16, 17, 18, 1, 5, 7, 10, 3, 6, 8, 9, 15, 2, 11, 12, 13, 14, 4, 19 }
    for _, s in ipairs(slots) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", s)
        if type(link) == "string" and not Peon.IsSecret(link) then list[#list + 1] = { inv = s } end
    end
    local C = C_Container
    if C and C.GetContainerNumSlots and C.GetContainerItemInfo then
        for bag = 0, 5 do
            local n = C.GetContainerNumSlots(bag) or 0
            for slot = 1, n do
                local info = C.GetContainerItemInfo(bag, slot)
                if type(info) == "table" and info.itemID then list[#list + 1] = { bag = bag, slot = slot } end
                if #list >= 60 then return list end
            end
        end
    end
    return list
end

local function FillPreview(p)
    local tt = p.tt
    tt:SetOwner(p.frame, "ANCHOR_NONE")
    tt:ClearAllPoints()
    tt:SetPoint("TOPLEFT", p.frame, "TOPLEFT", 0, p.kind == "item" and -26 or 0)
    if p.kind == "unit" then
        local unit = (UnitExists and UnitExists("target")) and "target" or "player"
        tt:SetUnit(unit)
        p.note:SetText(unit == "target" and L.PREVIEW_TARGET or L.PREVIEW_SELF)
    else
        if not p.items or #p.items == 0 then p.items = ItemCandidates() end
        local n = #p.items
        if n == 0 then
            tt:Hide()
            p.note:SetText(L.PREVIEW_NO_ITEM)
            return
        end
        if p.index > n then p.index = 1 end
        local c = p.items[p.index]
        if c.inv then tt:SetInventoryItem("player", c.inv) else tt:SetBagItem(c.bag, c.slot) end
        p.note:SetText(L.PREVIEW_COUNT:format(p.index, n))
    end
    tt:Show()
    if ns.ApplyStyle then ns.ApplyStyle(tt) end
    -- Hoehe des Kastens an den Tooltip anpassen (Seite ordnet neu)
    local sc = tt:GetScale() or 1
    local h = (tt:GetHeight() or 100) * sc + (p.kind == "item" and 26 or 0) + 22
    if math.abs((p.frame:GetHeight() or 0) - h) > 1 then
        p.frame:SetHeight(h)
        p.page:Layout()
    end
end

function ns.UpdatePreviews()
    for _, p in pairs(previews) do
        local active = p.page.panel:IsShown() and (not p.page.GetTab or p.page:GetTab() == p.tab)
        if active then
            local ok, err = pcall(FillPreview, p)
            if not ok then ns.mod:ReportError("Beispiel", err) end
        elseif p.tt:IsShown() then
            p.tt:Hide()
        end
    end
end

function ns.CreatePreview(page, kind)
    local mod = ns.mod
    local c = page:NewContainer(140)
    local name = kind == "unit" and "PeonTooltipPreviewUnit" or "PeonTooltipPreviewItem"
    local tt = CreateFrame("GameTooltip", name, c, "GameTooltipTemplate")
    tt:SetFrameStrata("DIALOG")
    ns.previewTips[tt] = true
    local p = { kind = kind, tab = kind == "unit" and "units" or "items", page = page, frame = c, tt = tt, index = 1 }
    previews[kind] = p
    p.note = c:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    p.note:SetPoint("BOTTOMLEFT", 0, 4)
    if kind == "item" then
        if ns.HookItemTooltip then ns.HookItemTooltip(tt) end    -- Teile ordnen wie beim echten Tooltip
        local function Step(d)
            local n = p.items and #p.items or 0
            if n == 0 then p.items = nil; ns.UpdatePreviews() return end
            p.index = ((p.index - 1 + d) % n) + 1
            ns.UpdatePreviews()
        end
        local prev = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        prev:SetSize(28, 22); prev:SetText("<"); prev:SetPoint("TOPLEFT", 0, 0)
        prev:SetScript("OnClick", function() Step(-1) end)
        local nxt = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        nxt:SetSize(28, 22); nxt:SetText(">"); nxt:SetPoint("LEFT", prev, "RIGHT", 2, 0)
        nxt:SetScript("OnClick", function() Step(1) end)
        local again = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        again:SetSize(110, 22); again:SetText(L.PREVIEW_RELOAD); again:SetPoint("LEFT", nxt, "RIGHT", 6, 0)
        again:SetScript("OnClick", function() p.items = nil; p.index = 1; ns.UpdatePreviews() end)
    end
    c:HookScript("OnHide", function() tt:Hide() end)
    return c
end

-- Einstellungen geaendert / Ziel gewechselt: Beispiele neu aufbauen
local function Changed() if ns.UpdatePreviews then ns.UpdatePreviews() end end
ns.mod:On("CHANGED", Changed)
ns.mod:On("RESET", Changed)
ns.mod:RegisterEvent("PLAYER_TARGET_CHANGED", function()
    local p = previews.unit
    if p and p.page.panel:IsShown() then Changed() end
end)

---------------------------------------------------------------------------
-- Liste der Teile im Gegenstands-Tooltip: Haken (anzeigen), Name, hoch/runter, entfernen
---------------------------------------------------------------------------
local ROW_H = 22
local ARROW = "Interface\\Buttons\\UI-ScrollBar-Scroll%sButton-%s"

local function IconButton(parent, kind, tip, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(20, 20)
    if kind == "remove" then
        b:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    else
        b:SetNormalTexture(ARROW:format(kind, "Up"))
        b:SetPushedTexture(ARROW:format(kind, "Down"))
        b:SetDisabledTexture(ARROW:format(kind, "Disabled"))
        b:SetHighlightTexture(ARROW:format(kind, "Highlight"), "ADD")
    end
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tip)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

function ns.CreatePartList(page)
    local mod = ns.mod
    local c = page:NewContainer(100)
    local width = page.colW
    local rows = {}
    local selected

    local function Changed()
        page:Changed("itemOrder")
        page:Refresh()
    end

    local fixed = c:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    fixed:SetPoint("TOPLEFT", 24, -4)
    fixed:SetText(L.ITEM_NAME_FIXED)

    local function GetRow(i)
        local r = rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, c)
        r:SetSize(width, ROW_H)
        r.sel = r:CreateTexture(nil, "BACKGROUND")
        r.sel:SetAllPoints()
        r.sel:SetColorTexture(1, 0.82, 0, 0.15)
        r.cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
        r.cb:SetSize(22, 22)
        r.cb:SetPoint("LEFT", -2, 0)
        if r.cb.text then r.cb.text:SetText("") end
        if r.cb.Text then r.cb.Text:SetText("") end
        r.cb:SetScript("OnClick", function(b)
            local db = mod.db
            if not db or not r.key then return end
            db.itemHidden[r.key] = (not b:GetChecked()) or nil
            Changed()
        end)
        r.label = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        r.label:SetPoint("LEFT", 24, 0)
        r.label:SetWidth(width - 24 - 70)
        r.label:SetJustifyH("LEFT")
        r.label:SetWordWrap(false)
        r.up = IconButton(r, "Up", L.ITEM_TT_UP, function() ns.ItemMove(r.key, -1); Changed() end)
        r.up:SetPoint("RIGHT", -44, 0)
        r.down = IconButton(r, "Down", L.ITEM_TT_DOWN, function() ns.ItemMove(r.key, 1); Changed() end)
        r.down:SetPoint("RIGHT", -24, 0)
        r.remove = IconButton(r, "remove", L.ITEM_TT_REMOVE, function()
            if selected == r.key then selected = nil end
            ns.ItemRemove(r.key)
            Changed()
        end)
        r.remove:SetPoint("RIGHT", -2, 0)
        r:SetScript("OnClick", function()
            selected = (selected ~= r.key) and r.key or nil
            c.Refresh()
        end)
        rows[i] = r
        return r
    end

    local function Button(text, w)
        local b = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetText(text)
        return b
    end
    local addLine = Button(L.ITEM_ADD_LINE, 142)
    local addSpace = Button(L.ITEM_ADD_SPACE, 142)
    local resetOrder = Button(L.ITEM_RESET_ORDER, 200)
    addLine:SetScript("OnClick", function()
        selected = ns.ItemAddSeparator("line", selected)
        Changed()
    end)
    addSpace:SetScript("OnClick", function()
        selected = ns.ItemAddSeparator("space", selected)
        Changed()
    end)
    resetOrder:SetScript("OnClick", function()
        selected = nil
        ns.ItemResetOrder()
        Changed()
    end)

    local hint = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetWidth(width)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.ITEM_LIST_HINT)

    c.Refresh = function()
        local db = mod.db
        if not db then return end
        ns.ItemEnsureOrder()
        local order = db.itemOrder
        local y = -ROW_H
        for i, key in ipairs(order) do
            local r = GetRow(i)
            r.key = key
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, y)
            y = y - ROW_H
            local sep = ns.ItemIsSep(key)
            local loaded = ns.ItemPartLoaded(key)
            local label = ns.ItemPartLabel(key)
            if not loaded then label = label .. " |cff888888" .. L.ITEM_NOT_LOADED .. "|r" end
            r.label:SetText(label)
            if sep or not loaded then
                r.label:SetTextColor(0.6, 0.6, 0.6)
            else
                r.label:SetTextColor(1, 1, 1)
            end
            r.cb:SetShown(not sep)
            r.cb:SetChecked(not db.itemHidden[key])
            r.up:SetEnabled(i > 1)
            r.down:SetEnabled(i < #order)
            r.remove:SetShown(sep or not loaded)
            r.sel:SetShown(selected == key)
            r:Show()
        end
        for i = #order + 1, #rows do rows[i]:Hide() end
        y = y - 6
        addLine:ClearAllPoints(); addLine:SetPoint("TOPLEFT", 0, y)
        addSpace:ClearAllPoints(); addSpace:SetPoint("TOPLEFT", 148, y)
        y = y - 26
        resetOrder:ClearAllPoints(); resetOrder:SetPoint("TOPLEFT", 0, y)
        y = y - 28
        hint:ClearAllPoints(); hint:SetPoint("TOPLEFT", 0, y)
        local h = hint:GetStringHeight() or 24
        c:SetHeight(-y + h + 4)
    end

    -- neue Teile entdeckt, waehrend die Seite offen ist
    ns.ItemOptionsChanged = function()
        if page.panel and page.panel:IsShown() then page:Refresh() end
    end
    return c
end
