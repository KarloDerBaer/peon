-- Peon_Bags - Setup.lua
-- Knopf "Einstellen" und Leiste neben dem Fenster (ab 0.5, Konzept Peon_Bags_Anordnung.md). Ab 0.7 mit zwei
-- Reitern (Konzept Peon_Bags_Layout.md):
--   Kategorien: oben die Anordnung (Klassisch, Nach Art, Individuell), darunter die automatischen Kategorien,
--               darunter die eigenen Bereiche, ganz unten eine Erklaerung.
--   Layout:     oben die Vorauswahl (Untereinander, Locker, Ausgewogen, Kompakt, Individuell), darunter die
--               einzelnen Einstellungen zum Platzsparen, die Spalten und die Breite je Abschnitt.
-- Die Leiste ist so hoch wie das Fenster und rollt, wenn die Listen laenger sind.
-- Je Fenster: Anordnung, angehakte Kategorien und Bereiche, Layout. Gemeinsam: Reihenfolge der Kategorien, Bereiche.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod or not ns.Window then return end

local Window = ns.Window
local WIDTH, INNER, ROW = 270, 222, 22
local LAYOUTS = { { "classic", L.LAYOUT_CLASSIC }, { "type", L.LAYOUT_TYPE }, { "custom", L.LAYOUT_CUSTOM } }
local EMPTY = { { "hint", L.EMPTY_HINT }, { "slot", L.EMPTY_SLOT }, { "drag", L.EMPTY_DRAG } }
local TABS = { { "cats", L.TAB_CATS }, { "layout", L.TAB_LAYOUT } }
local MIN_COLS, MAX_COLS = 6, 24

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

-- Zeile mit Haken und Beschriftung (Reiter Layout)
local function CheckRow(parent, label, tip, onClick)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(INNER, ROW)
    r.check = Check(r, function(_, on) onClick(on) end)
    r.label = Text(r, "GameFontNormalSmall")
    r.label:SetPoint("LEFT", r.check, "RIGHT", 2, 0)
    r.label:SetWidth(INNER - 26)
    r.label:SetText(label)
    Tip(r.check, label, tip)
    return r
end

-- Zeile mit Zahl: Beschriftung, "-", Wert, "+". get() liefert den Wert (nil = automatisch), step(delta) aendert,
-- reset() setzt auf automatisch (Klick auf den Wert, nur wenn reset angegeben)
local function NumberRow(parent, labelWidth)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(INNER, ROW)
    r.label = Text(r)
    r.label:SetPoint("LEFT", 2, 0)
    r.label:SetWidth(labelWidth)
    r.plus = ns.SmallButton(r, "+", 22, nil, function(self) local row = self:GetParent() if row.step then row.step(1) end end)
    r.plus:SetPoint("RIGHT", 0, 0)
    r.value = CreateFrame("Button", nil, r)
    r.value:SetSize(36, ROW)
    r.value:SetPoint("RIGHT", r.plus, "LEFT", -2, 0)
    r.value.text = Text(r.value, "GameFontHighlightSmall")
    r.value.text:SetAllPoints()
    r.value.text:SetJustifyH("CENTER")
    r.value:SetScript("OnClick", function(self) local row = self:GetParent() if row.reset then mod:Call("Einstellen", row.reset) end end)
    r.minus = ns.SmallButton(r, "-", 22, nil, function(self) local row = self:GetParent() if row.step then row.step(-1) end end)
    r.minus:SetPoint("RIGHT", r.value, "LEFT", -2, 0)
    return r
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

-- Breite je Abschnitt (Reiter Layout): Name, "-", Spalten oder "auto", "+"
local function WidthRow(w, i)
    local p = w.setup
    local r = p.widthRows[i]
    if r then return r end
    r = NumberRow(p.lcontent, INNER - 90)
    r.step = function(delta)
        local t = w:Table("Widths")
        local cur = t[r.secKey] or r.auto or 1
        t[r.secKey] = math.max(1, math.min(MAX_COLS, cur + delta))
        mod:Fire("CHANGED", w.key .. "Widths")
    end
    r.reset = function()
        w:Table("Widths")[r.secKey] = nil
        mod:Fire("CHANGED", w.key .. "Widths")
    end
    Tip(r.value, L.WIDTH_VALUE, L.WIDTH_VALUE_TIP)
    p.widthRows[i] = r
    return r
end

---------------------------------------------------------------------------
-- Inhalt aufbauen
---------------------------------------------------------------------------
local function Place(parent, region, y, height)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    return y - height
end

local function PresetLabel(key)
    return L["PRESET_" .. key:upper()] or key
end

local function RefreshCats(w)
    local p = w.setup
    local c = p.content
    local layout = w:Layout()
    for _, b in ipairs(p.layoutBtns) do ns.SetButtonOn(b, b.value == layout) end
    local y = -26
    p.modeText:SetText(L["MODE_" .. layout:upper()] or "")
    y = Place(c, p.modeText, y, (p.modeText:GetStringHeight() or 12) + 10)

    -- automatische Kategorien: bei Klassisch ausgegraut
    local catsOn = layout ~= "classic"
    y = Place(c, p.catHdr, y, 20)
    local off, order = w:Table("CatsOff"), ns.CatOrder()
    for i, cat in ipairs(order) do
        local r = CatRow(w, i)
        r.cat = cat
        r.check:SetChecked(not off[cat])
        r.label:SetText(ns.CAT_TITLE[cat] or cat)
        SetEnabled(r.check, catsOn)
        SetEnabled(r.up, catsOn and i > 1)
        SetEnabled(r.down, catsOn and i < #order)
        r:SetAlpha(catsOn and 1 or 0.45)
        r:Show()
        y = Place(c, r, y, ROW)
    end
    for i = #order + 1, #p.catRows do p.catRows[i]:Hide() end
    p.catHdr:SetAlpha(catsOn and 1 or 0.45)
    y = y - 10

    -- eigene Bereiche: nur bei Individuell waehlbar
    if w.useGroups then
        local grpOn = layout == "custom"
        y = Place(c, p.grpHdr, y, 20)
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
            y = Place(c, r, y, ROW)
        end
        for i = #groups + 1, #p.grpRows do p.grpRows[i]:Hide() end
        p.emptyGroups:SetShown(#groups == 0)
        if #groups == 0 then
            p.emptyGroups:SetAlpha(grpOn and 1 or 0.45)
            y = Place(c, p.emptyGroups, y, 18)
        end
        SetEnabled(p.newBtn, grpOn)
        y = Place(c, p.newBtn, y - 4, 30)
    end

    y = Place(c, p.hint, y - 4, (p.hint:GetStringHeight() or 12) + 12)
    y = Place(c, p.moreBtn, y, 26)
    c:SetHeight(math.max(1, -y))
end

local function RefreshLayout(w)
    local p = w.setup
    local c = p.lcontent
    local preset = ns.CurrentPreset(w.key)
    if p.preset.Update then p.preset:Update(preset) end
    local y = Place(c, p.presetLbl, 0, 16)
    y = Place(c, p.preset, y, 30)
    p.presetText:SetText(L["PRESET_DESC_" .. preset:upper()] or "")
    y = Place(c, p.presetText, y, (p.presetText:GetStringHeight() or 12) + 12)

    -- Abschnitte
    local pack = w:Setting("Pack") ~= false
    y = Place(c, p.arrHdr, y, 20)
    p.packRow.check:SetChecked(pack)
    y = Place(c, p.packRow, y, ROW)
    p.fillRow.check:SetChecked(w:Setting("Fill") and true or false)
    p.narrowRow.check:SetChecked(w:Setting("Narrow") and true or false)
    for _, r in ipairs({ p.fillRow, p.narrowRow }) do
        SetEnabled(r.check, pack)
        r:SetAlpha(pack and 1 or 0.45)
        y = Place(c, r, y, ROW)
    end
    y = y - 8

    -- Plaetze
    y = Place(c, p.slotHdr, y, 20)
    p.freeRow.check:SetChecked(w:Setting("FreeStack") and true or false)
    y = Place(c, p.freeRow, y, ROW)
    if w.useGroups then
        y = Place(c, p.emptyLbl, y - 4, 16)
        local mode = w:Setting("Empty") or "slot"
        for _, b in ipairs(p.emptyBtns) do ns.SetButtonOn(b, b.value == mode) end
        y = Place(c, p.emptyRow, y, 26)
        p.emptyDesc:SetText(L["EMPTY_DESC_" .. mode:upper()] or "")
        y = Place(c, p.emptyDesc, y, (p.emptyDesc:GetStringHeight() or 12) + 6)
    end
    y = y - 8

    -- Spalten
    y = Place(c, p.colsHdr, y, 20)
    local cols = w:Cols()
    p.colsRow.value.text:SetText(cols)
    SetEnabled(p.colsRow.minus, cols > MIN_COLS)
    SetEnabled(p.colsRow.plus, cols < MAX_COLS)
    y = Place(c, p.colsRow, y, ROW + 2)
    local auto = w:Setting("AutoCols") and true or false
    p.autoRow.check:SetChecked(auto)
    p.autoRow.label:SetText(auto and w.usedCols and w.usedCols ~= cols and L.AUTOCOLS_NOW:format(w.usedCols) or L.AUTOCOLS)
    y = Place(c, p.autoRow, y, ROW)
    y = y - 8

    -- Breite je Abschnitt (nur Abschnitte mit Ueberschrift, die das Fenster gerade zeigt)
    y = Place(c, p.widthHdr, y, 20)
    local list = w.lastSections or {}
    local widths = w:Table("Widths")
    for i, s in ipairs(list) do
        local r = WidthRow(w, i)
        r.secKey, r.auto = s.key, s.c
        r.label:SetText(s.title)
        local v = widths[s.key]
        r.value.text:SetText(v and tostring(v) or L.WIDTH_AUTO)
        SetEnabled(r.minus, (v or s.c or 2) > 1)
        SetEnabled(r.plus, (v or s.c or 0) < MAX_COLS)
        r:Show()
        y = Place(c, r, y, ROW)
    end
    for i = #list + 1, #p.widthRows do p.widthRows[i]:Hide() end
    p.widthEmpty:SetShown(#list == 0)
    if #list == 0 then y = Place(c, p.widthEmpty, y, 18) end
    y = Place(c, p.widthHint, y - 4, (p.widthHint:GetStringHeight() or 12) + 12)
    c:SetHeight(math.max(1, -y))
end

local function ShowTab(w, key)
    local p = w.setup
    p.tab = key
    p.catsScroll:SetShown(key == "cats")
    p.layoutScroll:SetShown(key == "layout")
    if p.tabs then
        if p.tabs.Select and p.tabs.selected ~= key then
            p.tabs.selecting = true
            p.tabs:Select(key)
            p.tabs.selecting = nil
        end
        for _, t in ipairs(p.tabs) do if t.peonFallback then ns.SetButtonOn(t, t.key == key) end end
    end
end

local function Refresh(w)
    local p = w.setup
    if not p or not mod.db then return end
    RefreshCats(w)
    RefreshLayout(w)
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

local function Scroll(p, top)
    local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, top)
    scroll:SetPoint("BOTTOMRIGHT", -32, 10)
    local c = CreateFrame("Frame", nil, scroll)
    c:SetSize(INNER, 1)
    scroll:SetScrollChild(c)
    return scroll, c
end

-- Reiter oben: Peon.UI.TopTabs (Kern-API 18), sonst zwei Knoepfe
local function BuildTabs(w, p)
    local function OnSelect(key)
        if p.tabs and p.tabs.selecting then return end
        mod.db.setupTab = key
        mod:Call("Einstellen", ShowTab, w, key)
    end
    local UI = rawget(Peon, "UI")
    local tabs
    if type(UI) == "table" and type(UI.TopTabs) == "function" then
        local ok, t = pcall(UI.TopTabs, p, TABS, OnSelect)
        if ok and type(t) == "table" and t[1] then tabs = t end
    end
    if tabs then
        tabs[1]:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -26)
    else
        tabs = {}
        local bw = math.floor((INNER - 4) / 2)
        for i, d in ipairs(TABS) do
            local b = ns.SmallButton(p, d[2], bw, nil, function() OnSelect(d[1]) end)
            b:SetPoint("TOPLEFT", 12 + (i - 1) * (bw + 4), -30)
            b.key, b.peonFallback = d[1], true
            tabs[i] = b
        end
    end
    p.tabs = tabs
end

-- Auswahlliste der Vorauswahl: neue Menue-API, sonst ein Knopf, der die Vorauswahlen der Reihe nach durchgeht
local function BuildPreset(w, c)
    local function Choose(key) mod:Call("Einstellen", ns.ApplyPreset, w.key, key) end
    local ok, dd = pcall(CreateFrame, "DropdownButton", nil, c, "WowStyle1DropdownTemplate")
    if ok and dd and dd.SetupMenu then
        dd:SetWidth(INNER)
        dd:SetupMenu(function(_, root)
            for _, pr in ipairs(ns.PRESETS) do
                root:CreateRadio(PresetLabel(pr.key), function() return ns.CurrentPreset(w.key) == pr.key end,
                    function() Choose(pr.key) end)
            end
            -- Individuell: zeigt nur an, dass einzelne Einstellungen abweichen
            root:CreateRadio(PresetLabel("custom"), function() return ns.CurrentPreset(w.key) == "custom" end, function() end)
        end)
        dd.Update = function(self, key)
            self.current = key
            if self.GenerateMenu then pcall(self.GenerateMenu, self) end
        end
    else
        dd = ns.SmallButton(c, "", INNER, L.PRESET_TIP, function()
            local cur, list = ns.CurrentPreset(w.key), ns.PRESETS
            local nextKey = list[1].key
            for i, pr in ipairs(list) do
                if pr.key == cur then nextKey = list[i % #list + 1].key end
            end
            Choose(nextKey)
        end)
        dd.Update = function(self, key) self.current = key; self:SetText(PresetLabel(key)) end
    end
    dd.Choose = Choose
    return dd
end

local function BuildLayoutTab(w, p)
    local c = p.lcontent
    p.presetLbl = Text(c, "GameFontNormal")
    p.presetLbl:SetText(L.PRESET)
    p.preset = BuildPreset(w, c)
    p.presetText = Text(c)
    p.presetText:SetWidth(INNER)
    p.presetText:SetTextColor(0.8, 0.8, 0.8)

    p.arrHdr = Text(c, "GameFontNormal")
    p.arrHdr:SetText(L.HDR_ARRANGE)
    p.packRow = CheckRow(c, L.PACK, L.PACK_TIP, function(on) w:Set("Pack", on) end)
    p.fillRow = CheckRow(c, L.FILL, L.FILL_TIP, function(on) w:Set("Fill", on) end)
    p.narrowRow = CheckRow(c, L.NARROW, L.NARROW_TIP, function(on) w:Set("Narrow", on) end)

    p.slotHdr = Text(c, "GameFontNormal")
    p.slotHdr:SetText(L.HDR_SLOTS_LAYOUT)
    p.freeRow = CheckRow(c, L.FREESTACK, L.FREESTACK_TIP, function(on) w:Set("FreeStack", on) end)
    if w.useGroups then
        p.emptyLbl = Text(c, "GameFontNormalSmall")
        p.emptyLbl:SetText(L.EMPTY)
        p.emptyRow = CreateFrame("Frame", nil, c)
        p.emptyRow:SetSize(INNER, 24)
        p.emptyBtns = {}
        local bw = math.floor((INNER - 8) / 3)
        for i, e in ipairs(EMPTY) do
            local b = ns.SmallButton(p.emptyRow, e[2], bw, L["EMPTY_DESC_" .. e[1]:upper()], function() w:Set("Empty", e[1]) end)
            b:SetPoint("TOPLEFT", (i - 1) * (bw + 4), 0)
            b.value = e[1]
            p.emptyBtns[i] = b
        end
        p.emptyDesc = Text(c)
        p.emptyDesc:SetWidth(INNER)
        p.emptyDesc:SetTextColor(0.8, 0.8, 0.8)
    end

    p.colsHdr = Text(c, "GameFontNormal")
    p.colsHdr:SetText(L.COLS)
    p.colsRow = NumberRow(c, INNER - 90)
    p.colsRow.label:SetText(L.COLS_MAX)
    p.colsRow.step = function(delta)
        w:Set("Cols", math.max(MIN_COLS, math.min(MAX_COLS, w:Cols() + delta)))
    end
    p.autoRow = CheckRow(c, L.AUTOCOLS, L.AUTOCOLS_TIP, function(on) w:Set("AutoCols", on) end)

    p.widthHdr = Text(c, "GameFontNormal")
    p.widthHdr:SetText(L.HDR_WIDTHS)
    p.widthRows = {}
    p.widthEmpty = Text(c, "GameFontDisableSmall")
    p.widthEmpty:SetText(L.WIDTH_NONE)
    p.widthHint = Text(c, "GameFontNormalSmall")
    p.widthHint:SetWidth(INNER)
    p.widthHint:SetTextColor(0.8, 0.8, 0.8)
    p.widthHint:SetText(L.WIDTH_HINT)
end

local function BuildCatsTab(w, p)
    local c = p.content
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
        p.emptyGroups = Text(c, "GameFontDisableSmall")
        p.emptyGroups:SetText(L.GROUP_LIST_EMPTY)
        p.newBtn = ns.SmallButton(c, L.SETUP_NEW_GROUP, 130, nil, function() StaticPopup_Show("PEON_BAGS_GROUP_NEW") end)
    end
    p.hint = Text(c, "GameFontNormalSmall")
    p.hint:SetWidth(INNER)
    p.hint:SetTextColor(0.8, 0.8, 0.8)
    p.hint:SetText(w.useGroups and L.SETUP_HINT or L.SETUP_HINT_GUILD)
    p.moreBtn = ns.SmallButton(c, L.SETUP_MORE, 150, nil, function() mod:OpenOptions() end)
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

    p.catsScroll, p.content = Scroll(p, -64)
    p.layoutScroll, p.lcontent = Scroll(p, -64)
    BuildCatsTab(w, p)
    BuildLayoutTab(w, p)
    BuildTabs(w, p)

    p:SetScript("OnShow", function()
        Anchor(w)
        ShowTab(w, mod.db.setupTab == "layout" and "layout" or "cats")
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

-- Reiter per Code waehlen (fuer Tests und spaetere Aufrufe)
function Window:SetupTab(key)
    if not self.setup then Build(self) end
    mod.db.setupTab = key
    ShowTab(self, key)
end
