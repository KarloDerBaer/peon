-- Peon_Panel - Display.lua
-- Die beiden Anzeigen: waagerechte Leiste (bar) und verschiebbares Panel im Raster (box).
-- Nichts davon ist geschuetzt, alles darf sich auch im Kampf aendern.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

local PAD, GAP = 4, 6
local TEXT_GAP, TEXT_H = 3, 14
local BOX_CELL_MAX = 90   -- breiter wird eine Zelle im Panel nicht, laengere Texte kuerzt das Spiel

local surfaces = {}
ns.surfaces = surfaces

local function Active(s)
    if s.key == "bar" then return mod.db.barPos ~= "none" end
    return mod.db.boxShow == true
end

-- Liegt die Anzeige in der oberen Bildschirmhaelfte? Dort oeffnen Menue und Tooltip nach unten.
function ns.InUpperHalf(s)
    local _, y = s.frame:GetCenter()
    local h = UIParent:GetHeight()
    if not y or not h then return true end
    return y >= h / 2
end

---------------------------------------------------------------------------
-- Ziehen: Ziel aus der Mausposition (x, y von der linken oberen Ecke, y nach unten)
---------------------------------------------------------------------------
function ns.DropTarget(cells, x, y)
    local best, bestDist
    for _, c in ipairs(cells) do
        local dx, dy = x - (c.x + c.w / 2), (y - (c.y + c.h / 2)) * 2   -- die Reihe zaehlt mehr als die Spalte
        local dist = dx * dx + dy * dy
        if not bestDist or dist < bestDist then best, bestDist = c, dist end
    end
    if not best then return nil end
    return best, x > best.x + best.w / 2
end

local function CursorInFrame(frame)
    local cx, cy = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    local left, top = frame:GetLeft(), frame:GetTop()
    if not cx or not left or not top or not scale or scale == 0 then return nil end
    return cx / scale - left, top - cy / scale
end

local function UpdateMarker(s)
    local x, y = CursorInFrame(s.frame)
    if not x then return end
    local cell, after = ns.DropTarget(s.cells, x, y)
    if not cell then return end
    s.marker:ClearAllPoints()
    s.marker:SetPoint("TOPLEFT", s.frame, "TOPLEFT", after and cell.x + cell.w + 1 or cell.x - 3, -cell.y)
    s.marker:SetHeight(cell.h)
    s.marker:Show()
end

local function DragStart(s, b)
    if s.key == "box" and mod.db.boxLocked then return end
    s.dragging = b
    b:SetAlpha(0.4)
    GameTooltip:Hide()
    s.frame:SetScript("OnUpdate", function() UpdateMarker(s) end)
end

local function DragStop(s, b)
    if s.dragging ~= b then return end
    s.dragging = nil
    b:SetAlpha(1)
    s.frame:SetScript("OnUpdate", nil)
    s.marker:Hide()
    local x, y = CursorInFrame(s.frame)
    if not x then return end
    local cell, after = ns.DropTarget(s.cells, x, y)
    if cell and ns.MoveEntry(ns.OrderOf(s.key), b.starter.key, cell.key, after) then ns.Layout(s) end
end

---------------------------------------------------------------------------
-- Knoepfe
---------------------------------------------------------------------------
local function ShowTooltip(s, b)
    if s.dragging then return end
    local l = b.starter
    GameTooltip:SetOwner(b, ns.InUpperHalf(s) and "ANCHOR_BOTTOM" or "ANCHOR_TOP")
    GameTooltip:AddLine(("|c%sPeon|r %s"):format(Peon.COLOR, l.title))
    l:FillTooltip(GameTooltip)
    local locked = s.key == "box" and mod.db.boxLocked
    GameTooltip:AddLine(locked and L.TIP_HINT_LOCKED or L.TIP_HINT, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function SetHover(s, on)
    if s.vis == "hover" then s.frame:SetAlpha(on and 1 or 0) end
end

local function NewButton(s, l)
    local b = CreateFrame("Button", nil, s.frame)
    b.starter = l
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if b.label.SetWordWrap then b.label:SetWordWrap(false) end
    b:SetScript("OnClick", function(self, button)
        GameTooltip:Hide()
        if button == "RightButton" then
            ns.OpenMenu(s, self)
        else
            l:Click(button, self)
        end
    end)
    b:SetScript("OnDragStart", function(self) DragStart(s, self) end)
    b:SetScript("OnDragStop", function(self) DragStop(s, self) end)
    b:SetScript("OnEnter", function(self)
        SetHover(s, true)
        ShowTooltip(s, self)
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if not s.frame:IsMouseOver() then SetHover(s, false) end
    end)
    s.buttons[l.key] = b
    return b
end

local function UpdateButton(b)
    local l, e = b.starter, ns.Entry(b.starter.key)
    b.icon:SetTexture(l.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    l:ColorIcon(b.icon)
    local text = e and e.text ~= ns.TEXT_NONE and l:GetText(e.text) or nil
    b.textValue = text
    b.label:SetText(text or "")
    if text then b.label:Show() else b.label:Hide() end
end

---------------------------------------------------------------------------
-- Anordnen
---------------------------------------------------------------------------
local function TextWidth(b)
    if not b.textValue then return 0 end
    return b.label:GetStringWidth() or 0
end

-- Die Breiten wachsen nur (s.widths, s.cellW), damit die Nachbarn nicht bei jeder Goldaenderung springen.
-- ns.ApplyAll setzt sie zurueck.
local function PlaceBar(s, list)
    local size = mod.db.barSize
    local x = PAD
    for _, l in ipairs(list) do
        local b = s.buttons[l.key]
        local w = size
        if b.textValue then w = size + TEXT_GAP + TextWidth(b) end
        w = math.max(w, s.widths[l.key] or 0)
        s.widths[l.key] = w
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", s.frame, "TOPLEFT", x, -PAD)
        b:SetSize(w, size)
        b.icon:ClearAllPoints()
        b.icon:SetPoint("LEFT", b, "LEFT", 0, 0)
        b.icon:SetSize(size, size)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", b.icon, "RIGHT", TEXT_GAP, 0)
        s.cells[#s.cells + 1] = { key = l.key, x = x, y = PAD, w = w, h = size }
        x = x + w + GAP
    end
    s.frame:SetSize(x - GAP + PAD, size + PAD * 2)
end

local function PlaceBox(s, list)
    local size = mod.db.boxSize
    local n = #list
    local cols = mod.db.boxCols
    if cols < 1 then cols = math.ceil(math.sqrt(n)) end
    cols = math.min(cols, n)
    local cellW, hasText = size, false
    for _, l in ipairs(list) do
        local b = s.buttons[l.key]
        if b.textValue then hasText = true end
        cellW = math.max(cellW, math.min(TextWidth(b) + 4, BOX_CELL_MAX))
    end
    cellW = math.max(cellW, s.cellW or 0)
    s.cellW = cellW
    local cellH = size + (hasText and TEXT_H or 0)
    for i, l in ipairs(list) do
        local b = s.buttons[l.key]
        local row, col = math.floor((i - 1) / cols), (i - 1) % cols
        local x, y = PAD + col * (cellW + GAP), PAD + row * (cellH + GAP)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", s.frame, "TOPLEFT", x, -y)
        b:SetSize(cellW, cellH)
        b.icon:ClearAllPoints()
        b.icon:SetPoint("TOP", b, "TOP", 0, 0)
        b.icon:SetSize(size, size)
        b.label:ClearAllPoints()
        b.label:SetPoint("TOP", b.icon, "BOTTOM", 0, -1)
        b.label:SetWidth(cellW)
        s.cells[#s.cells + 1] = { key = l.key, x = x, y = y, w = cellW, h = cellH }
    end
    local rows = math.ceil(n / cols)
    s.frame:SetSize(PAD * 2 + cols * cellW + (cols - 1) * GAP, PAD * 2 + rows * cellH + (rows - 1) * GAP)
end

local function Anchor(s)
    local f = s.frame
    f:ClearAllPoints()
    if s.key == "bar" then
        local pos = mod.db.barPos
        local dx = pos:find("LEFT") and mod.db.barX or pos:find("RIGHT") and -mod.db.barX or 0
        local dy = pos:find("TOP") and -mod.db.barY or pos:find("BOTTOM") and mod.db.barY or 0
        f:SetPoint(pos, UIParent, pos, dx, dy)
    else
        local p = mod.db.boxPos
        if type(p.x) == "number" and type(p.y) == "number" then
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
        else
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
end

function ns.Layout(s)
    local list = Active(s) and ns.VisibleStarters(s.key) or {}
    local shown = {}
    s.cells = {}
    for _, l in ipairs(list) do
        local b = s.buttons[l.key] or NewButton(s, l)
        UpdateButton(b)
        b:Show()
        shown[l.key] = true
    end
    for key, b in pairs(s.buttons) do
        if not shown[key] then b:Hide() end
    end
    if #list == 0 then
        s.frame:Hide()
        return
    end
    if s.key == "bar" then PlaceBar(s, list) else PlaceBox(s, list) end
    ns.ApplySurfaceVisibility(s)
end

function ns.ApplySurfaceVisibility(s)
    local db = mod.db
    local vis = s.key == "bar" and db.barVis or db.boxVis
    s.vis = vis
    local hasContent = Active(s) and #s.cells > 0
    local inCombat = vis == "combat" and Peon.InCombat()
    s.frame:SetShown(hasContent and not inCombat)
    local over = vis == "hover" and s.frame:IsMouseOver()
    s.frame:SetAlpha((vis ~= "hover" or over) and 1 or 0)
end

function ns.ApplyVisibility()
    for _, s in pairs(surfaces) do ns.ApplySurfaceVisibility(s) end
end

-- Nach einer Aenderung der Einstellungen: alles neu, Breiten wieder von vorn
function ns.ApplyAll()
    for _, s in pairs(surfaces) do
        s.widths, s.cellW = {}, nil
        s.bg:SetShown((s.key == "bar" and mod.db.barBg or s.key == "box" and mod.db.boxBg) and true or false)
        Anchor(s)
        ns.Layout(s)
    end
end

-- Symbol und Text eines Starters neu (Kern: s:Refresh())
function ns.RefreshStarter(l)
    for _, s in pairs(surfaces) do
        if s.buttons[l.key] and s.buttons[l.key]:IsShown() then ns.Layout(s) end
    end
end

function ns.RefreshAll()
    for _, s in pairs(surfaces) do ns.Layout(s) end
end

---------------------------------------------------------------------------
-- Anlegen
---------------------------------------------------------------------------
local function NewSurface(key, name)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()
    local s = { key = key, frame = f, buttons = {}, widths = {}, cells = {} }
    s.bg = f:CreateTexture(nil, "BACKGROUND")
    s.bg:SetAllPoints()
    s.bg:SetColorTexture(0, 0, 0, 0.5)
    s.marker = f:CreateTexture(nil, "OVERLAY")
    s.marker:SetColorTexture(0.55, 0.81, 0.30, 1)   -- Peon-Gruen
    s.marker:SetWidth(2)
    s.marker:Hide()
    f:SetScript("OnEnter", function() SetHover(s, true) end)
    f:SetScript("OnLeave", function()
        if not f:IsMouseOver() then SetHover(s, false) end
    end)
    surfaces[key] = s
    return s
end

function ns.SaveBoxPosition()
    local f = surfaces.box.frame
    local left, top = f:GetLeft(), f:GetTop()
    if left and top then mod.db.boxPos.x, mod.db.boxPos.y = left, top end
end

function ns.InitDisplay()
    if surfaces.bar then return end
    NewSurface("bar", "PeonPanelBar")
    local box = NewSurface("box", "PeonPanelBox").frame
    box:SetMovable(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", function(self)
        if not mod.db.boxLocked then self:StartMoving() end
    end)
    box:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ns.SaveBoxPosition()
    end)
    ns.ApplyAll()
end
