-- Peon_Feedback - Window.lua
-- Fenster: oben vier Auswahllisten (Modul, Art, Bereich, Priorität), Textfeld, Speichern;
-- unten die Liste der gespeicherten Rückmeldungen (Kern-Liste, API 7) mit Löschen.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end   -- Peon zu alt (Meldung kam schon aus Feedback.lua)

local W, H = 620, 560
local frame, list, editBox, status, dropdowns

-- aktuelle Auswahl
local sel = { module = "Peon", kind = "bug", area = nil, prio = "mid" }

local function C(hex, text) return "|cff" .. hex .. text .. "|r" end

local function SetStatus(text, r, g, b)
    if status then status:SetText(text or ""); status:SetTextColor(r or 1, g or 0.82, b or 0) end
end

-- ===== Auswahlliste =====
-- Neue Menü-API (WowStyle1DropdownTemplate), sonst Knopf, der die Werte durchschaltet.
local function NewDropdown(parent, width, getItems, getValue, setValue)
    local dd
    local ok = pcall(function() dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate") end)
    if ok and dd and dd.SetupMenu then
        dd:SetWidth(width)
        dd:SetupMenu(function(owner, root)
            for _, it in ipairs(getItems()) do
                root:CreateRadio(it[2], function() return getValue() == it[1] end,
                    function() setValue(it[1]) end)
            end
        end)
        dd.Update = function() if dd.GenerateMenu then dd:GenerateMenu() end end
        return dd
    end
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b.Update = function()
        b:SetText(ns.Label(getItems(), getValue()))
    end
    b:SetScript("OnClick", function()
        local items, v, idx = getItems(), getValue(), 0
        for i, it in ipairs(items) do if it[1] == v then idx = i end end
        local nxt = items[idx % #items + 1]
        if nxt then setValue(nxt[1]) end
    end)
    return b
end

-- ===== Auswahl prüfen und merken =====

local function Valid(items, v)
    for _, it in ipairs(items) do if it[1] == v then return true end end
    return false
end

local function Remember()
    local last = mod.db and mod.db.last
    if last then last.module, last.kind, last.area, last.prio = sel.module, sel.kind, sel.area, sel.prio end
end

local function FixSelection()
    local mods = ns.Modules()
    if not Valid(mods, sel.module) then sel.module = mods[1] and mods[1][1] or "Peon" end
    if not Valid(ns.KINDS, sel.kind) then sel.kind = "bug" end
    if not Valid(ns.PRIOS, sel.prio) then sel.prio = "mid" end
    local areas = ns.Areas(sel.module)
    if not Valid(areas, sel.area) then sel.area = areas[1][1] end
end

local function UpdateDropdowns()
    FixSelection()
    for _, dd in pairs(dropdowns) do dd.Update() end
end
ns.UpdateDropdowns = UpdateDropdowns

-- ===== Liste =====

local function ShortTime(t) return date("%d.%m. %H:%M", t) end

local function RefreshList()
    if not list then return end
    list:SetData(ns.Visible())
    list:Refresh()
end
ns.RefreshList = RefreshList

local function ShowEntryTooltip(row, e)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(("#%d  %s · %s"):format(e.id, ns.ModuleTitle(e.module), e.area), 1, 1, 1)
    GameTooltip:AddLine(C(ns.KIND_COLOR[e.kind] or "ffffff", ns.Label(ns.KINDS, e.kind)) .. "  ·  "
        .. C(ns.PRIO_COLOR[e.prio] or "ffffff", ns.Label(ns.PRIOS, e.prio)))
    GameTooltip:AddLine(e.text, 1, 0.82, 0, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.COL_TIME, date("%d.%m.%Y %H:%M", e.t), 0.6, 0.6, 0.6, 0.9, 0.9, 0.9)
    if e.edited then GameTooltip:AddDoubleLine(L.TT_EDITED, date("%d.%m.%Y %H:%M", e.edited), 0.6, 0.6, 0.6, 0.9, 0.9, 0.9) end
    if e.ver then GameTooltip:AddDoubleLine(L.TT_VERSION, e.ver, 0.6, 0.6, 0.6, 0.9, 0.9, 0.9) end
    GameTooltip:AddDoubleLine(L.TT_CHAR, e.char or "?", 0.6, 0.6, 0.6, 0.9, 0.9, 0.9)
    GameTooltip:AddDoubleLine(L.TT_MARKET, e.market or "?", 0.6, 0.6, 0.6, 0.9, 0.9, 0.9)
    if e.zone then GameTooltip:AddDoubleLine(L.TT_ZONE, e.zone, 0.6, 0.6, 0.6, 0.9, 0.9, 0.9) end
    GameTooltip:Show()
end

-- ===== Speichern / Löschen =====

local function Save()
    local entry, err = ns.Add({ module = sel.module, kind = sel.kind, area = sel.area,
                                prio = sel.prio, text = editBox:GetText() })
    if not entry then SetStatus(err, 1, 0.3, 0.3) return end
    editBox:SetText("")
    editBox:ClearFocus()
    Remember()
    RefreshList()
    SetStatus(L.SAVED:format(entry.id), 0.55, 0.81, 0.3)
end
ns.Save = Save

local function DeleteSelected()
    local e = list and list:GetSelected()
    if not e then SetStatus(L.SELECT_ROW) return end
    if ns.Delete(e.id) then
        RefreshList()
        SetStatus(L.DELETED:format(e.id))
    end
end
ns.DeleteSelected = DeleteSelected

-- ===== Fenster bauen =====

local function MakeLabel(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function Create()
    if frame then return end
    local ok = pcall(function() frame = CreateFrame("Frame", "PeonFeedbackFrame", UIParent, "BasicFrameTemplateWithInset") end)
    if not ok or not frame then
        frame = CreateFrame("Frame", "PeonFeedbackFrame", UIParent, "BackdropTemplate")
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.92)
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
    end
    frame:SetSize(W, H)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, _, x, y = f:GetPoint()
        local pos = mod.db and mod.db.windowPos
        if pos then pos.point, pos.x, pos.y = point, x, y end
    end)
    frame:Hide()
    tinsert(UISpecialFrames, "PeonFeedbackFrame")   -- Escape schließt (nur Eintrag hinzufügen)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText(L.WIN_TITLE)

    -- Auswahllisten: zwei Reihen à zwei
    local colX, colW = { 16, W / 2 + 6 }, W / 2 - 30
    MakeLabel(frame, L.MODULE, colX[1], -34)
    MakeLabel(frame, L.KIND,   colX[2], -34)
    MakeLabel(frame, L.AREA,   colX[1], -84)
    MakeLabel(frame, L.PRIO,   colX[2], -84)

    dropdowns = {
        module = NewDropdown(frame, colW, ns.Modules, function() return sel.module end,
            function(v) sel.module = v; sel.area = nil; UpdateDropdowns(); Remember() end),
        kind = NewDropdown(frame, colW, function() return ns.KINDS end, function() return sel.kind end,
            function(v) sel.kind = v; UpdateDropdowns(); Remember() end),
        area = NewDropdown(frame, colW, function() return ns.Areas(sel.module) end, function() return sel.area end,
            function(v) sel.area = v; UpdateDropdowns(); Remember() end),
        prio = NewDropdown(frame, colW, function() return ns.PRIOS end, function() return sel.prio end,
            function(v) sel.prio = v; UpdateDropdowns(); Remember() end),
    }
    dropdowns.module:SetPoint("TOPLEFT", colX[1], -50)
    dropdowns.kind:SetPoint("TOPLEFT",   colX[2], -50)
    dropdowns.area:SetPoint("TOPLEFT",   colX[1], -100)
    dropdowns.prio:SetPoint("TOPLEFT",   colX[2], -100)

    -- Beschreibung (mehrzeilig, mit Bildlauf)
    MakeLabel(frame, L.TEXT, colX[1], -136)
    local box = CreateFrame("Frame", nil, frame)
    box:SetPoint("TOPLEFT", 16, -152)
    box:SetSize(W - 32, 96)
    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints()
    boxBg:SetColorTexture(0, 0, 0, 0.5)

    local scroll
    pcall(function() scroll = CreateFrame("ScrollFrame", "PeonFeedbackTextScroll", box, "UIPanelScrollFrameTemplate") end)
    scroll = scroll or CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)

    editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(W - 32 - 40)
    editBox:SetMaxLetters(2000)
    editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
    editBox:SetScript("OnTextChanged", function() SetStatus("") end)
    scroll:SetScrollChild(editBox)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    -- Knöpfe und Statuszeile
    local save = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    save:SetSize(110, 24)
    save:SetPoint("TOPRIGHT", -16, -256)
    save:SetText(L.SAVE)
    save:SetScript("OnClick", Save)
    ns.saveButton = save

    local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clear:SetSize(90, 24)
    clear:SetPoint("RIGHT", save, "LEFT", -6, 0)
    clear:SetText(L.CLEAR)
    clear:SetScript("OnClick", function() editBox:SetText(""); SetStatus("") end)

    status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", 18, -262)
    status:SetPoint("RIGHT", clear, "LEFT", -8, 0)
    status:SetJustifyH("LEFT")

    -- Liste der Rückmeldungen
    list = Peon.NewList(frame, {
        columns = {
            { key = "t", title = L.COL_TIME, width = 80, format = function(v) return ShortTime(v) end },
            { key = "module", title = L.MODULE, width = 80,
              format = function(v) return ns.ModuleTitle(v) end,
              sortValue = function(e) return ns.ModuleTitle(e.module) end },
            { key = "kind", title = L.KIND, width = 82,
              format = function(v) return C(ns.KIND_COLOR[v] or "ffffff", ns.Label(ns.KINDS, v)) end },
            { key = "area", title = L.AREA, width = 96 },
            { key = "prio", title = L.PRIO, width = 62,
              format = function(v) return C(ns.PRIO_COLOR[v] or "ffffff", ns.Label(ns.PRIOS, v)) end,
              sortValue = function(e) return ({ low = 1, mid = 2, high = 3 })[e.prio] or 0 end },
            { key = "text", title = L.TEXT, width = 164,
              format = function(v) v = (v or ""):gsub("\n", " "); return #v > 40 and v:sub(1, 38) .. "…" or v end },
        },
        rows = 10, rowHeight = 18, sortKey = "t", sortDesc = true, selectable = true,
        emptyText = L.LIST_EMPTY,
        onEnter = function(l, item, row) if item then ShowEntryTooltip(row, item) end end,
        onLeave = function() GameTooltip:Hide() end,
    })
    list.frame:SetPoint("TOPLEFT", 16, -292)
    list.frame:SetPoint("RIGHT", -16, 0)

    -- unten: Löschen links, Bearbeiten Mitte, OK rechts (ab 0.2.0, Feedback #1/#2)
    local del = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    del:SetSize(110, 24)
    del:SetPoint("BOTTOMLEFT", 16, 12)
    del:SetText(L.DELETE)
    del:SetScript("OnClick", DeleteSelected)
    ns.deleteButton = del

    local edit = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    edit:SetSize(110, 24)
    edit:SetPoint("BOTTOM", 0, 12)
    edit:SetText(L.EDIT)
    edit:SetScript("OnClick", function() ns.EditSelected() end)
    ns.editButton = edit

    local okb = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    okb:SetSize(110, 24)
    okb:SetPoint("BOTTOMRIGHT", -16, 12)
    okb:SetText(L.OK)
    okb:SetScript("OnClick", function() frame:Hide() end)
    ns.okButton = okb

    -- ab 0.3.0: Das Spiel schreibt die Daten erst beim Neuladen, danach holt sie der Peon Manager ab
    local send = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    send:SetSize(118, 24)
    send:SetPoint("RIGHT", okb, "LEFT", -4, 0)
    send:SetText(L.TO_MANAGER)
    send:SetScript("OnClick", function()
        local n, hint = ns.SendToManager()
        if not n then SetStatus(hint, 1, 0.3, 0.3) end
    end)
    ns.sendButton = send
    frame:HookScript("OnHide", function() if ns.editFrame then ns.editFrame:Hide() end end)

    frame:SetScript("OnShow", function()
        local last = mod.db and mod.db.last or {}
        sel.module = last.module or sel.module
        sel.kind   = last.kind or sel.kind
        sel.area   = last.area
        sel.prio   = last.prio or sel.prio
        UpdateDropdowns()
        RefreshList()
        local handed = ns.HandedCount()
        if handed > 0 then SetStatus(L.HANDED:format(handed), 0.55, 0.81, 0.3) else SetStatus("") end
    end)
end

-- ===== Bearbeiten (ab 0.2.0, Feedback #2): eigenes Fenster =====
local edit = { id = nil, module = nil, kind = nil, area = nil, prio = nil }
local editFrame, editText, editStatus, editDropdowns

local function UpdateEditDropdowns()
    local mods = ns.Modules()
    if not Valid(mods, edit.module) then mods[#mods + 1] = { edit.module, ns.ModuleTitle(edit.module) } end
    local areas = ns.Areas(edit.module)
    if not Valid(areas, edit.area) then edit.area = areas[1][1] end
    for _, dd in pairs(editDropdowns) do dd.Update() end
end

local function CreateEdit()
    if editFrame then return end
    local EW, EH = 520, 300
    local ok = pcall(function() editFrame = CreateFrame("Frame", "PeonFeedbackEditFrame", UIParent, "BasicFrameTemplateWithInset") end)
    if not ok or not editFrame then
        editFrame = CreateFrame("Frame", "PeonFeedbackEditFrame", UIParent, "BackdropTemplate")
        local bg = editFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
    end
    editFrame:SetSize(EW, EH)
    editFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    editFrame:SetClampedToScreen(true)
    editFrame:SetMovable(true)
    editFrame:EnableMouse(true)
    editFrame:RegisterForDrag("LeftButton")
    editFrame:SetScript("OnDragStart", editFrame.StartMoving)
    editFrame:SetScript("OnDragStop", editFrame.StopMovingOrSizing)
    editFrame:SetPoint("CENTER")
    editFrame:Hide()
    tinsert(UISpecialFrames, "PeonFeedbackEditFrame")
    ns.editFrame = editFrame

    local title = editFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    editFrame.title = title

    local colX, colW = { 16, EW / 2 + 6 }, EW / 2 - 30
    MakeLabel(editFrame, L.MODULE, colX[1], -34)
    MakeLabel(editFrame, L.KIND,   colX[2], -34)
    MakeLabel(editFrame, L.AREA,   colX[1], -84)
    MakeLabel(editFrame, L.PRIO,   colX[2], -84)
    editDropdowns = {
        module = NewDropdown(editFrame, colW, function()
                local mods = ns.Modules()
                if not Valid(mods, edit.module) then mods[#mods + 1] = { edit.module, ns.ModuleTitle(edit.module) } end
                return mods
            end, function() return edit.module end,
            function(v) edit.module = v; edit.area = nil; UpdateEditDropdowns() end),
        kind = NewDropdown(editFrame, colW, function() return ns.KINDS end, function() return edit.kind end,
            function(v) edit.kind = v; UpdateEditDropdowns() end),
        area = NewDropdown(editFrame, colW, function() return ns.Areas(edit.module) end, function() return edit.area end,
            function(v) edit.area = v; UpdateEditDropdowns() end),
        prio = NewDropdown(editFrame, colW, function() return ns.PRIOS end, function() return edit.prio end,
            function(v) edit.prio = v; UpdateEditDropdowns() end),
    }
    editDropdowns.module:SetPoint("TOPLEFT", colX[1], -50)
    editDropdowns.kind:SetPoint("TOPLEFT",   colX[2], -50)
    editDropdowns.area:SetPoint("TOPLEFT",   colX[1], -100)
    editDropdowns.prio:SetPoint("TOPLEFT",   colX[2], -100)

    MakeLabel(editFrame, L.TEXT, colX[1], -136)
    local box = CreateFrame("Frame", nil, editFrame)
    box:SetPoint("TOPLEFT", 16, -152)
    box:SetSize(EW - 32, 96)
    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints()
    boxBg:SetColorTexture(0, 0, 0, 0.5)
    local scroll
    pcall(function() scroll = CreateFrame("ScrollFrame", "PeonFeedbackEditScroll", box, "UIPanelScrollFrameTemplate") end)
    scroll = scroll or CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    editText = CreateFrame("EditBox", nil, scroll)
    editText:SetMultiLine(true)
    editText:SetAutoFocus(false)
    editText:SetFontObject(ChatFontNormal)
    editText:SetWidth(EW - 32 - 40)
    editText:SetMaxLetters(2000)
    editText:SetScript("OnEscapePressed", editText.ClearFocus)
    scroll:SetScrollChild(editText)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() editText:SetFocus() end)

    editStatus = editFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    editStatus:SetPoint("TOPLEFT", 18, -258)
    editStatus:SetJustifyH("LEFT")
    editStatus:SetTextColor(1, 0.3, 0.3)

    local cancel = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
    cancel:SetSize(110, 24)
    cancel:SetPoint("BOTTOMLEFT", 16, 12)
    cancel:SetText(L.CANCEL)
    cancel:SetScript("OnClick", function() editFrame:Hide() end)

    local save = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
    save:SetSize(110, 24)
    save:SetPoint("BOTTOMRIGHT", -16, 12)
    save:SetText(L.SAVE)
    save:SetScript("OnClick", function() ns.SaveEdit() end)
    ns.editSaveButton = save
end

function ns.SaveEdit()
    if not edit.id then return end
    local e, err = ns.Update(edit.id, { module = edit.module, kind = edit.kind, area = edit.area,
                                       prio = edit.prio, text = editText:GetText() })
    if not e then editStatus:SetText(err or ""); return end
    editFrame:Hide()
    RefreshList()
    SetStatus(L.UPDATED:format(e.id), 0.55, 0.81, 0.3)
end

function ns.OpenEdit(e)
    if not e then return end
    CreateEdit()
    edit.id, edit.module, edit.kind, edit.area, edit.prio = e.id, e.module, e.kind, e.area, e.prio
    editFrame.title:SetText(L.EDIT_TITLE:format(e.id))
    editText:SetText(e.text or "")
    editStatus:SetText("")
    UpdateEditDropdowns()
    editFrame:Show()
end

function ns.EditSelected()
    local e = list and list:GetSelected()
    if not e then SetStatus(L.SELECT_ROW) return end
    ns.OpenEdit(ns.Get(e.id) or e)
end

function ns.GetEdit() return edit, editText end

local function Place()
    local pos = mod.db and mod.db.windowPos or {}
    frame:ClearAllPoints()
    if pos.point then frame:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    else frame:SetPoint("CENTER") end
end

function ns.Show()
    Create()
    Place()
    frame:Show()
end

function ns.Toggle()
    Create()
    if frame:IsShown() then frame:Hide() else ns.Show() end
end

function ns.GetFrame() return frame end
function ns.GetSelection() return sel end
function ns.GetEditBox() return editBox end
function ns.GetList() return list end
function ns.GetDropdowns() return dropdowns end
