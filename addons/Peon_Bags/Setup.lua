-- Peon_Bags - Setup.lua
-- Knopf "Einstellen" und Leiste neben dem Fenster (ab 0.5, Konzept Peon_Bags_Anordnung.md): oben die Anordnung
-- (Klassisch, Nach Art, Individuell), darunter die automatischen Kategorien, darunter die eigenen Bereiche,
-- ganz unten eine Erklaerung. Die Leiste ist so hoch wie das Fenster und rollt, wenn die Listen laenger sind.
-- Je Fenster: Anordnung, angehakte Kategorien und Bereiche. Gemeinsam: Reihenfolge der Kategorien, die Bereiche.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod or not ns.Window then return end

local Window = ns.Window
local WIDTH, INNER, ROW = 270, 222, 22
local LAYOUTS = { { "classic", L.LAYOUT_CLASSIC }, { "type", L.LAYOUT_TYPE }, { "custom", L.LAYOUT_CUSTOM } }

local function Tip(f, title, text)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function SetEnabled(b, on)
    if on then b:Enable() else b:Disable() end
end

-- kleiner Pfeil (hoch/runter) zum Verschieben
local function Arrow(parent, dir, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(16, 16)
    local base = "Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. dir
    b:SetNormalTexture(base .. "-Up")
    b:SetPushedTexture(base .. "-Down")
    b:SetDisabledTexture(base .. "-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", function(self) mod:Call("Einstellen", onClick, self:GetParent()) end)
    Tip(b, dir == "Up" and L.SETUP_UP or L.SETUP_DOWN)
    return b
end

local function Check(parent, onClick)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(22, 22)
    c:SetPoint("LEFT", 0, 0)
    c:SetScript("OnClick", function(self) mod:Call("Einstellen", onClick, self:GetParent(), self:GetChecked() and true or false) end)
    return c
end

local function Text(parent, font)
    local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    t:SetJustifyH("LEFT")
    return t
end

---------------------------------------------------------------------------
-- Zeilen (werden wiederverwendet)
---------------------------------------------------------------------------
local function CatRow(w, i)
    local p = w.setup
    local r = p.catRows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, p.content)
    r:SetSize(INNER, ROW)
    r.check = Check(r, function(row, on)
        w:Table("CatsOff")[row.cat] = (not on) or nil
        mod:Fire("CHANGED", w.key .. "CatsOff")
    end)
    r.label = Text(r)
    r.label:SetPoint("LEFT", r.check, "RIGHT", 2, 0)
    r.down = Arrow(r, "Down", function(row) ns.MoveCat(row.cat, 1) end)
    r.down:SetPoint("RIGHT", 0, 0)
    r.up = Arrow(r, "Up", function(row) ns.MoveCat(row.cat, -1) end)
    r.up:SetPoint("RIGHT", r.down, "LEFT", -2, 0)
    p.catRows[i] = r
    return r
end

local function GroupRow(w, i)
    local p = w.setup
    local r = p.grpRows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, p.content)
    r:SetSize(INNER, ROW)
    r.check = Check(r, function(row, on)
        w:Table("GroupsOff")[row.id] = (not on) or nil
        mod:Fire("CHANGED", w.key .. "GroupsOff")
    end)
    -- Name: Klick benennt um
    r.name = CreateFrame("Button", nil, r)
    r.name:SetSize(INNER - 22 - 2 - 30 - 36 - 22, ROW)
    r.name:SetPoint("LEFT", r.check, "RIGHT", 2, 0)
    r.name.text = Text(r.name)
    r.name.text:SetAllPoints()
    r.name:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    r.name:SetScript("OnClick", function(self)
        local row = self:GetParent()
        mod:Call("Einstellen", StaticPopup_Show, "PEON_BAGS_GROUP_RENAME", nil, nil, row.id)
    end)
    Tip(r.name, L.SETUP_RENAME, L.SETUP_RENAME_TIP)
    r.del = ns.SmallButton(r, "X", 20, L.SETUP_DELETE_TIP, function(self) ns.AskDeleteGroup(self:GetParent().id) end)
    r.del:SetPoint("RIGHT", 0, 0)
    r.down = Arrow(r, "Down", function(row) ns.MoveGroup(row.id, 1) end)
    r.down:SetPoint("RIGHT", r.del, "LEFT", -2, 0)
    r.up = Arrow(r, "Up", function(row) ns.MoveGroup(row.id, -1) end)
    r.up:SetPoint("RIGHT", r.down, "LEFT", -2, 0)
    r.count = Text(r)
    r.count:SetJustifyH("RIGHT")
    r.count:SetWidth(28)
    r.count:SetPoint("RIGHT", r.up, "LEFT", -2, 0)
    p.grpRows[i] = r
    return r
end

---------------------------------------------------------------------------
-- Inhalt aufbauen
---------------------------------------------------------------------------
local function Place(w, region, y, height)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", w.setup.content, "TOPLEFT", 0, y)
    return y - height
end

local function Refresh(w)
    local p = w.setup
    if not p or not mod.db then return end
    local layout = w:Layout()
    for _, b in ipairs(p.layoutBtns) do ns.SetButtonOn(b, b.value == layout) end
    local y = -26
    p.modeText:SetText(L["MODE_" .. layout:upper()] or "")
    y = Place(w, p.modeText, y, (p.modeText:GetStringHeight() or 12) + 12)

    -- automatische Kategorien: bei Klassisch ausgegraut
    local catsOn = layout ~= "classic"
    y = Place(w, p.catHdr, y, 20)
    local off, order = w:Table("CatsOff"), ns.CatOrder()
    for i, c in ipairs(order) do
        local r = CatRow(w, i)
        r.cat = c
        r.check:SetChecked(not off[c])
        r.label:SetText(ns.CAT_TITLE[c] or c)
        SetEnabled(r.check, catsOn)
        SetEnabled(r.up, catsOn and i > 1)
        SetEnabled(r.down, catsOn and i < #order)
        r:SetAlpha(catsOn and 1 or 0.45)
        r:Show()
        y = Place(w, r, y, ROW)
    end
    for i = #order + 1, #p.catRows do p.catRows[i]:Hide() end
    p.catHdr:SetAlpha(catsOn and 1 or 0.45)
    y = y - 10

    -- eigene Bereiche: nur bei Individuell waehlbar
    if w.useGroups then
        local grpOn = layout == "custom"
        y = Place(w, p.grpHdr, y, 20)
        p.grpHdr:SetAlpha(grpOn and 1 or 0.45)
        local goff, groups = w:Table("GroupsOff"), ns.Groups()
        for i, g in ipairs(groups) do
            local r = GroupRow(w, i)
            r.id = g.id
            r.check:SetChecked(not goff[g.id])
            r.name.text:SetText(g.name)
            r.count:SetText(ns.CountGroup(g.id))
            SetEnabled(r.check, grpOn)
            SetEnabled(r.name, grpOn)
            SetEnabled(r.del, grpOn)
            SetEnabled(r.up, grpOn and i > 1)
            SetEnabled(r.down, grpOn and i < #groups)
            r:SetAlpha(grpOn and 1 or 0.45)
            r:Show()
            y = Place(w, r, y, ROW)
        end
        for i = #groups + 1, #p.grpRows do p.grpRows[i]:Hide() end
        p.emptyText:SetShown(#groups == 0)
        if #groups == 0 then
            p.emptyText:SetAlpha(grpOn and 1 or 0.45)
            y = Place(w, p.emptyText, y, 18)
        end
        SetEnabled(p.newBtn, grpOn)
        y = Place(w, p.newBtn, y - 4, 30)
    end

    y = Place(w, p.hint, y - 4, (p.hint:GetStringHeight() or 12) + 12)
    y = Place(w, p.moreBtn, y, 26)
    p.content:SetHeight(math.max(1, -y))
end
ns.RefreshSetup = Refresh

-- Neben das Fenster legen: rechts, oder links, wenn rechts kein Platz ist
local function Anchor(w)
    local p, f = w.setup, w.frame
    if not p then return end
    local right, scale = f:GetRight(), f:GetEffectiveScale()
    local screen = UIParent:GetRight()
    local uiScale = UIParent:GetEffectiveScale()
    local left = false
    if ns.Num(right) and ns.Num(screen) and ns.Num(scale) and ns.Num(uiScale) then
        left = (right + WIDTH) * scale > screen * uiScale
    end
    p:ClearAllPoints()
    if left then
        p:SetPoint("TOPRIGHT", f, "TOPLEFT", 0, 0)
        p:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", 0, 0)
    else
        p:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, 0)
        p:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 0, 0)
    end
    p.onLeft = left
end

local function Build(w)
    local p
    local ok = pcall(function() p = CreateFrame("Frame", nil, w.frame, "BasicFrameTemplateWithInset") end)
    if not ok or not p then
        p = CreateFrame("Frame", nil, w.frame, "BackdropTemplate")
        if p.SetBackdrop then
            pcall(p.SetBackdrop, p, { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
                insets = { left = 6, right = 6, top = 6, bottom = 6 } })
        end
    end
    w.setup = p
    p:SetWidth(WIDTH)
    p:EnableMouse(true)
    p:Hide()
    local title = p.TitleText
    if type(title) ~= "table" and type(p.TitleContainer) == "table" then title = p.TitleContainer.TitleText end
    if type(title) ~= "table" then
        title = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -6)
    end
    title:SetText(L.SETUP_TITLE)

    local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", -32, 10)
    local c = CreateFrame("Frame", nil, scroll)
    c:SetSize(INNER, 1)
    scroll:SetScrollChild(c)
    p.scroll, p.content = scroll, c

    -- Anordnung: drei Knoepfe (Gildenbank: zwei)
    p.layoutBtns = {}
    local list = w.useGroups and LAYOUTS or { LAYOUTS[1], LAYOUTS[2] }
    local bw = math.floor((INNER - 4 * (#list - 1)) / #list)
    for i, l in ipairs(list) do
        local b = ns.SmallButton(c, l[2], bw, L["MODE_" .. l[1]:upper()], function() w:Set("Layout", l[1]) end)
        b:SetPoint("TOPLEFT", (i - 1) * (bw + 4), 0)
        b.value = l[1]
        p.layoutBtns[i] = b
    end
    p.modeText = Text(c)
    p.modeText:SetWidth(INNER)

    p.catHdr = Text(c, "GameFontNormal")
    p.catHdr:SetText(L.SETUP_CATS)
    p.catRows = {}
    if w.useGroups then
        p.grpHdr = Text(c, "GameFontNormal")
        p.grpHdr:SetText(L.SETUP_GROUPS)
        p.grpRows = {}
        p.emptyText = Text(c, "GameFontDisableSmall")
        p.emptyText:SetText(L.GROUP_LIST_EMPTY)
        p.newBtn = ns.SmallButton(c, L.SETUP_NEW_GROUP, 130, nil, function() StaticPopup_Show("PEON_BAGS_GROUP_NEW") end)
    end
    p.hint = Text(c, "GameFontNormalSmall")
    p.hint:SetWidth(INNER)
    p.hint:SetTextColor(0.8, 0.8, 0.8)
    p.hint:SetText(w.useGroups and L.SETUP_HINT or L.SETUP_HINT_GUILD)
    p.moreBtn = ns.SmallButton(c, L.SETUP_MORE, 150, nil, function() mod:OpenOptions() end)

    p:SetScript("OnShow", function()
        Anchor(w)
        Refresh(w)
    end)
    local function Update() if p:IsShown() then mod:Call("Einstellen", Refresh, w) end end
    mod:On("CHANGED", Update)
    mod:On("RESET", Update)
    w.OnMoved = function() if p:IsShown() then Anchor(w) end end
    return p
end

---------------------------------------------------------------------------
-- Knopf "Einstellen": rechts in der Knopfreihe
---------------------------------------------------------------------------
function Window:AddSetupButton()
    local w = self
    local b = ns.SmallButton(self.frame, L.BTN_SETUP, 90, L.BTN_SETUP_TIP, function() w:ToggleSetup() end)
    b:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -12, -55)
    self.setupBtn = b
    return b
end

function Window:ToggleSetup()
    local p = self.setup or Build(self)
    if p:IsShown() then p:Hide() else p:Show() end
end
