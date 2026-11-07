-- Peon_Panel - Display.lua
-- Die beiden Anzeigen: Leiste oben in der Mitte mit drei Bereichen (bar) und verschiebbares Panel im Raster (box).
-- Nichts davon ist geschuetzt, alles darf sich auch im Kampf aendern.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

local BAR_PAD_X = ns.CORNER   -- seitlich so viel wie die runde Ecke
local BAR_MARGIN = 4          -- so viel Luft bleibt mindestens ueber und unter dem Symbol
local ZONE_GAP = 18
local BOX_PAD, BOX_GAP = 8, 6
local TEXT_GAP = 3
local BOX_CELL_MAX = 150   -- breiter wird eine Zelle im Panel nicht, laengere Texte kuerzt das Spiel
local BOX_RIGHT_MAX = 220  -- dasselbe, wenn der Text rechts neben dem Symbol steht
local BAR_FOLD_MIN = 60    -- so breit ist die zugeklappte Leiste mindestens
local GLOW_TEXTURE = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local ICON_BORDER = "Interface\\Common\\WhiteIconFrame"
local FONT_FILES = {
    friz = "Fonts\\FRIZQT__.TTF", arial = "Fonts\\ARIALN.TTF",
    morpheus = "Fonts\\MORPHEUS.TTF", skurri = "Fonts\\SKURRI.TTF",
}

local surfaces = {}
ns.surfaces = surfaces

local function Active(s)
    if s.key == "bar" then return mod.db.barShow == true end
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

-- Bereich der Leiste an der Stelle x: linkes, mittleres oder rechtes Drittel
function ns.ZoneAt(width, x)
    if x < width / 3 then return "left" end
    if x < width * 2 / 3 then return "center" end
    return "right"
end

-- Hoehe einer Zeile der Leiste
function ns.BarRowHeight()
    return math.max(mod.db.barHeight, mod.db.barSize + BAR_MARGIN)
end

-- Zeile an der Stelle y (1 oder 2)
function ns.RowAt(y)
    if (mod.db.barRows or 1) < 2 then return 1 end
    return y >= ns.BarRowHeight() and 2 or 1
end

-- Ziel auf der Leiste: Bereich, Zeile und, wenn dort schon etwas steht, das naechste Symbol
function ns.BarDropTarget(s, x, y)
    local zone = ns.ZoneAt(s.frame:GetWidth(), x)
    local row = ns.RowAt(y)
    local inZone = {}
    for _, c in ipairs(s.cells) do
        if ns.SideOf(c.key) == zone and ns.RowOf(c.key) == row then inZone[#inZone + 1] = c end
    end
    local cell, after = ns.DropTarget(inZone, x, y)
    return zone, cell, after, row
end

function ns.CursorInFrame(frame)
    local cx, cy = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    local left, top = frame:GetLeft(), frame:GetTop()
    if not cx or not left or not top or not scale or scale == 0 then return nil end
    return cx / scale - left, top - cy / scale
end

local function PlaceMarker(s, x, y, h)
    s.marker:ClearAllPoints()
    s.marker:SetPoint("TOPLEFT", s.frame, "TOPLEFT", x, -y)
    s.marker:SetHeight(h)
    s.marker:Show()
end

local function UpdateMarker(s)
    local x, y = ns.CursorInFrame(s.frame)
    if not x then return end
    local zone, cell, after, row
    if s.key == "bar" then
        zone, cell, after, row = ns.BarDropTarget(s, x, y)
    else
        cell, after = ns.DropTarget(s.cells, x, y)
    end
    if cell then
        PlaceMarker(s, after and cell.x + cell.w + 1 or cell.x - 3, cell.y, cell.h)
    elseif zone then
        local w = s.frame:GetWidth()
        local mx = zone == "left" and BAR_PAD_X or zone == "center" and w / 2 or w - BAR_PAD_X
        local rh = ns.BarRowHeight()
        PlaceMarker(s, mx, ((row or 1) - 1) * rh + (rh - mod.db.barSize) / 2, mod.db.barSize)
    end
end

local function DragStart(s, b)
    if s.key == "box" and mod.db.boxLocked then return end
    s.dragging = b
    b:SetAlpha(0.4)
    GameTooltip:Hide()
    s.frame:SetScript("OnUpdate", function() UpdateMarker(s) end)
end

local function DropOnBar(s, b, x, y)
    local zone, cell, after, row = ns.BarDropTarget(s, x, y)
    local key = b.starter.key
    local moved = cell and ns.MoveEntry(ns.OrderOf(s.key), key, cell.key, after)
    local e = ns.Entry(key)
    if e and (ns.SideOf(key) ~= zone or ns.RowOf(key) ~= row) then
        e.side, e.row = zone, row
        mod:Fire("CHANGED", "entries")
    elseif moved then
        ns.Layout(s)
    end
end

local function DragStop(s, b)
    if s.dragging ~= b then return end
    s.dragging = nil
    b:SetAlpha(1)
    s.frame:SetScript("OnUpdate", nil)
    s.marker:Hide()
    local x, y = ns.CursorInFrame(s.frame)
    if not x then return end
    if s.key == "bar" then
        DropOnBar(s, b, x, y)
        return
    end
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
    local hint = s.key == "bar" and L.TIP_HINT_BAR or mod.db.boxLocked and L.TIP_HINT_LOCKED or L.TIP_HINT
    GameTooltip:AddLine(hint, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- Maus ueber der Anzeige: bei "hover" einblenden, bei "fold" (nur Panel, ab 0.3.0) aufklappen
local function SetHover(s, on)
    if s.vis == "hover" then s.frame:SetAlpha(on and 1 or 0) end
    if s.vis == "fold" and s.expanded ~= on and not s.dragging then
        s.expanded = on
        if s.key == "bar" then s.widths = {} end
        ns.Layout(s)
    end
end

local function NewButton(s, l)
    local b = CreateFrame("Button", nil, s.frame)
    b.starter = l
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.highlight = b:CreateTexture(nil, "HIGHLIGHT")
    b.highlight:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.iconBorder = b:CreateTexture(nil, "OVERLAY")
    b.iconBorder:SetTexture(ICON_BORDER)
    b.iconBorder:SetAllPoints(b.icon)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if b.label.SetWordWrap then b.label:SetWordWrap(false) end
    b.baseFont = b.label:GetFont()
    if l.onWheel then
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", function(self, delta)
            l:Wheel(delta, self)
            if self:IsMouseOver() then ShowTooltip(s, self) end
        end)
    end
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

-- Text, Anzeige und Beschriftung gelten je Anzeige (ab 0.3.0).
-- Ohne Text bleibt das Symbol immer da, sonst waere der Knopf unsichtbar.
local function UpdateButton(s, b)
    local l = b.starter
    local show = ns.ShowOf(l.key, s.key)
    local textKey = ns.TextOf(l.key, s.key)
    local text = textKey and textKey ~= ns.TEXT_NONE and show ~= "icon" and l:GetText(textKey) or nil
    b.textValue = text
    b.iconShown = not text or show ~= "text"
    if s.key == "bar" and s.folded and text then b.iconShown = false end   -- zugeklappt nur Text
    b.icon:SetTexture(l.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    l:ColorIcon(b.icon)
    b.icon:SetShown(b.iconShown)
    local db = mod.db
    b.iconBorder:SetShown(b.iconShown and db.iconBorder)
    b.iconBorder:SetVertexColor(db.lineColor[1], db.lineColor[2], db.lineColor[3], db.lineColor[4] or 1)
    ns.StyleLabel(b)
    ns.StyleHighlight(b)
    local labelsOn = (s.key == "bar" and db.barLabels) or (s.key == "box" and db.boxLabels)
    local word = text and labelsOn and ns.LabelWord(l, s.key)
    if word then
        b.label:SetText(("%s %s"):format(ns.Color(word .. ":", db.labelColor[1], db.labelColor[2], db.labelColor[3]), text))
    else
        b.label:SetText(text or "")
    end
    if text then b.label:Show() else b.label:Hide() end
end

-- Wort vor dem Text, nil = keines
function ns.LabelWord(l, sk)
    if not ns.LabelOf(l.key, sk) then return nil end
    return ns.LabelName(l)
end

-- Das Wort selbst, auch wenn es gerade aus ist (fuer Menue und Optionen)
function ns.LabelName(l)
    local def = ns.InfoDef and ns.InfoDef[l.key]
    return def and def.label or l.title
end

function ns.StyleLabel(b)
    local db = mod.db
    local font = FONT_FILES[db.fontFace] or b.baseFont
    if font then b.label:SetFont(font, db.fontSize, db.fontStyle == "outline" and "OUTLINE" or "") end
    if db.fontStyle == "shadow" then
        b.label:SetShadowOffset(1, -1)
        b.label:SetShadowColor(0, 0, 0, 1)
    else
        b.label:SetShadowOffset(0, 0)
    end
    local c = db.valueColor
    b.label:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

function ns.StyleHighlight(b)
    local kind = mod.db.highlight
    if kind == b.highlightKind then return end
    b.highlightKind = kind
    if kind == "glow" then
        b.highlight:SetTexture(GLOW_TEXTURE)
        b.highlight:SetBlendMode("ADD")
    elseif kind == "soft" then
        b.highlight:SetColorTexture(1, 1, 1, 0.12)
        b.highlight:SetBlendMode("BLEND")
    else
        b.highlight:SetColorTexture(0, 0, 0, 0)
    end
end

---------------------------------------------------------------------------
-- Anordnen
---------------------------------------------------------------------------
local function TextWidth(b)
    if not b.textValue then return 0 end
    return b.label:GetStringWidth() or 0
end

-- Startstellen der Bereiche. Die Mitte bleibt mittig, solange sie die Nachbarn nicht beruehrt.
function ns.ZoneStarts(width, leftW, centerW, rightW)
    local left, right = BAR_PAD_X, width - BAR_PAD_X - rightW
    local lo = left + leftW + (leftW > 0 and ZONE_GAP or 0)
    local hi = right - (rightW > 0 and ZONE_GAP or 0) - centerW
    local center = (width - centerW) / 2
    if center > hi then center = hi end
    if center < lo then center = lo end
    return left, center, right
end

-- Die Breiten wachsen nur (s.widths, s.cellW), damit die Nachbarn nicht bei jeder Goldaenderung springen.
-- ns.ApplyAll setzt sie zurueck.
local function ButtonWidth(b, size)
    local w = b.iconShown and size or 0
    if b.textValue then w = w + (b.iconShown and TEXT_GAP or 0) + TextWidth(b) end
    return w
end

-- Feine Trennstriche zwischen den Eintraegen eines Bereichs
local function PlaceSeparator(s, index, x, y, h)
    s.seps = s.seps or {}
    local t = s.seps[index]
    if not t then
        t = s.frame:CreateTexture(nil, "BORDER")
        t:SetWidth(1)
        s.seps[index] = t
    end
    local c = mod.db.lineColor
    t:SetColorTexture(c[1], c[2], c[3], (c[4] or 1) * 0.5)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", s.frame, "TOPLEFT", x, -y)
    t:SetHeight(h)
    t:Show()
end

local function PlaceBar(s, list)
    local size, gap = mod.db.barSize, mod.db.barGap
    local rowH = ns.BarRowHeight()
    local rowCount = (not s.folded and (mod.db.barRows or 1) >= 2) and 2 or 1
    local rows = {}
    for r = 1, rowCount do rows[r] = { left = { w = 0 }, center = { w = 0 }, right = { w = 0 } } end
    for _, l in ipairs(list) do
        local b = s.buttons[l.key]
        local w = math.max(ButtonWidth(b, size), s.widths[l.key] or 0)
        s.widths[l.key] = w
        local zones = rows[ns.RowOf(l.key)] or rows[1]
        local z = zones[ns.SideOf(l.key)] or zones.left
        z.w = z.w + (z.w > 0 and gap or 0) + w
        z[#z + 1] = l
    end

    -- Passt der Inhalt nicht, wird die Leiste breiter als eingestellt. Die breiteste Zeile zaehlt.
    local width = s.folded and BAR_FOLD_MIN or math.floor((UIParent:GetWidth() or 0) * mod.db.barWidth / 100)
    for _, zones in ipairs(rows) do
        local needed = BAR_PAD_X * 2 + zones.left.w + zones.center.w + zones.right.w
        if zones.left.w > 0 then needed = needed + ZONE_GAP end
        if zones.right.w > 0 then needed = needed + ZONE_GAP end
        width = math.max(width, needed)
    end

    local sepCount = 0
    for r, zones in ipairs(rows) do
        local top = (r - 1) * rowH + (rowH - size) / 2
        local startL, startC, startR = ns.ZoneStarts(width, zones.left.w, zones.center.w, zones.right.w)
        local starts = { left = startL, center = startC, right = startR }
        for name, z in pairs(zones) do
            local x = starts[name]
            for i, l in ipairs(z) do
                local b, w = s.buttons[l.key], s.widths[l.key]
                if i > 1 and mod.db.barSeps then
                    sepCount = sepCount + 1
                    PlaceSeparator(s, sepCount, x - gap / 2, top, size)
                end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", s.frame, "TOPLEFT", x, -top)
                b:SetSize(w, size)
                b.icon:ClearAllPoints()
                b.icon:SetPoint("LEFT", b, "LEFT", 0, 0)
                b.icon:SetSize(size, size)
                b.label:ClearAllPoints()
                b.label:SetWidth(0)
                if b.iconShown then
                    b.label:SetPoint("LEFT", b.icon, "RIGHT", TEXT_GAP, 0)
                else
                    b.label:SetPoint("LEFT", b, "LEFT", 0, 0)
                end
                s.cells[#s.cells + 1] = { key = l.key, x = x, y = top, w = w, h = size }
                x = x + w + gap
            end
        end
    end
    for i = sepCount + 1, #(s.seps or {}) do s.seps[i]:Hide() end
    s.frame:SetSize(width, rowH * rowCount)
end

-- Breite, die der Text einer Zelle im Panel braucht
local function BoxTextNeed(b)
    if mod.db.boxLayout == "right" then
        local w = TextWidth(b)
        if b.textValue and b.iconShown then w = w + TEXT_GAP end
        return math.min(w, BOX_RIGHT_MAX)
    end
    return math.min(TextWidth(b) + 4, BOX_CELL_MAX)
end

-- Panel im Raster. Text unter dem Symbol (below) oder rechts daneben (right, ab 0.3.0).
-- Aufklappbar: eine Reihe oder Spalte in der gewaehlten Richtung, der erste Eintrag bleibt an seiner Stelle.
-- all = alle Eintraege, auch zugeklappte, damit die Zellen beim Aufklappen gleich gross bleiben.
local function PlaceBox(s, list, all)
    local size = mod.db.boxSize
    local right = mod.db.boxLayout == "right"
    local fold = mod.db.boxVis == "fold"
    local dir = mod.db.boxFoldDir or "down"
    local n = #list
    local cols
    if fold then
        cols = (dir == "left" or dir == "right") and n or 1
    else
        cols = mod.db.boxCols
        if cols < 1 then cols = right and 1 or math.ceil(math.sqrt(n)) end
        cols = math.min(cols, n)
    end
    local rows = math.ceil(n / cols)
    local textW, hasText = 0, false
    for _, l in ipairs(all or list) do
        local b = s.buttons[l.key]
        if b.textValue then hasText = true end
        textW = math.max(textW, BoxTextNeed(b))
    end
    local cellW, cellH
    if right then
        cellW, cellH = size + textW, size
    else
        cellW, cellH = math.max(size, textW), size + (hasText and mod.db.fontSize + 3 or 0)
    end
    cellW = math.max(cellW, s.cellW or 0)
    s.cellW = cellW
    for i, l in ipairs(list) do
        local b = s.buttons[l.key]
        local row, col = math.floor((i - 1) / cols), (i - 1) % cols
        if fold and dir == "up" then row = rows - 1 - row end
        if fold and dir == "left" then col = cols - 1 - col end
        local x, y = BOX_PAD + col * (cellW + BOX_GAP), BOX_PAD + row * (cellH + BOX_GAP)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", s.frame, "TOPLEFT", x, -y)
        b:SetSize(cellW, cellH)
        b.icon:ClearAllPoints()
        b.icon:SetSize(size, size)
        b.label:ClearAllPoints()
        if right then
            b.icon:SetPoint("LEFT", b, "LEFT", 0, 0)
            b.label:SetWidth(cellW - (b.iconShown and size + TEXT_GAP or 0))
            b.label:SetJustifyH("LEFT")
            if b.iconShown then
                b.label:SetPoint("LEFT", b.icon, "RIGHT", TEXT_GAP, 0)
            else
                b.label:SetPoint("LEFT", b, "LEFT", 0, 0)
            end
        else
            b.icon:SetPoint("TOP", b, "TOP", 0, 0)
            b.label:SetWidth(cellW)
            b.label:SetJustifyH("CENTER")
            if b.iconShown then
                b.label:SetPoint("TOP", b.icon, "BOTTOM", 0, -1)
            else
                b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
            end
        end
        s.cells[#s.cells + 1] = { key = l.key, x = x, y = y, w = cellW, h = cellH }
    end
    s.frame:SetSize(BOX_PAD * 2 + cols * cellW + (cols - 1) * BOX_GAP, BOX_PAD * 2 + rows * cellH + (rows - 1) * BOX_GAP)
    s.foldW, s.foldH = BOX_PAD * 2 + cellW, BOX_PAD * 2 + cellH   -- Groesse zugeklappt
end

local function Anchor(s)
    local f = s.frame
    f:ClearAllPoints()
    if s.key == "bar" then
        f:SetPoint("TOP", UIParent, "TOP", 0, 0)
    else
        local p = mod.db.boxPos
        local dir = mod.db.boxVis == "fold" and s.foldW and mod.db.boxFoldDir
        if type(p.x) == "number" and type(p.y) == "number" and dir == "up" then
            f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p.x, p.y - s.foldH)
        elseif type(p.x) == "number" and type(p.y) == "number" and dir == "left" then
            f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", p.x + s.foldW, p.y)
        elseif type(p.x) == "number" and type(p.y) == "number" then
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
        else
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
end

-- Zugeklappt (ab 0.3.0): Panel nur mit dem ersten Eintrag, Leiste nur mit der Mitte der oberen Zeile.
-- Mit der Maus darueber klappt alles auf.
local function Folded(s, all)
    if s.key == "box" then return #all > 0 and { all[1] } or {} end
    local list = {}
    for _, l in ipairs(all) do
        if ns.SideOf(l.key) == "center" and ns.RowOf(l.key) == 1 then list[#list + 1] = l end
    end
    return list
end

function ns.Layout(s)
    local all = Active(s) and ns.VisibleStarters(s.key) or {}
    local vis = s.key == "bar" and mod.db.barVis or mod.db.boxVis
    s.folded = vis == "fold" and not s.expanded
    local list = s.folded and Folded(s, all) or all
    -- Das Panel misst alle Eintraege, damit die Zellen beim Aufklappen gleich bleiben
    local measure = s.key == "box" and all or list
    local shown = {}
    s.cells = {}
    for _, l in ipairs(measure) do
        local b = s.buttons[l.key] or NewButton(s, l)
        UpdateButton(s, b)
    end
    for _, l in ipairs(list) do
        s.buttons[l.key]:Show()
        shown[l.key] = true
    end
    for key, b in pairs(s.buttons) do
        if not shown[key] then b:Hide() end
    end
    s.shown = shown
    if s.key == "bar" then
        PlaceBar(s, list)   -- auch leer, sonst fehlt das Menue zum Wiedereinblenden
    elseif #list > 0 then
        PlaceBox(s, list, all)
        if not s.moving then Anchor(s) end
    end
    s.list = list
    ns.ApplySurfaceVisibility(s)
end

-- Soll dieser Starter auf der Anzeige stehen?
local function Wanted(s, l)
    local e = ns.Entry(l.key)
    return Active(s) and e ~= nil and e[s.key] == true and l:IsAvailable()
end

-- Steht er gerade sichtbar da? Zugeklappt verborgene Eintraege loesen kein Neuanordnen aus.
local function WantedShown(s, l)
    if not Wanted(s, l) then return false end
    if s.folded then return s.shown ~= nil and s.shown[l.key] == true end
    return true
end

-- Steht der Starter gerade irgendwo? Dann lohnt sich das Neuberechnen im Takt.
function ns.IsDisplayed(l)
    for _, s in pairs(surfaces) do
        if Wanted(s, l) then return true end
    end
    return false
end

function ns.ApplySurfaceVisibility(s)
    local db = mod.db
    local vis = s.key == "bar" and db.barVis or db.boxVis
    s.vis = vis
    local hasContent = Active(s) and (s.key == "bar" or #s.cells > 0)
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
        s.bg:Apply(mod.db.style, mod.db.bgColor, mod.db.lineColor, s.key == "bar" and mod.db.barBg or s.key == "box" and mod.db.boxBg)
        Anchor(s)
        ns.Layout(s)
    end
end

-- Symbol und Text eines Starters neu (Kern: s:Refresh()). Liest nur diesen einen Eintrag,
-- weil das im Takt laufen kann. Neu angeordnet wird nur, wenn er auf- oder abtaucht oder mehr Platz braucht.
function ns.RefreshStarter(l)
    for _, s in pairs(surfaces) do
        local b = s.buttons[l.key]
        local wanted = WantedShown(s, l)
        if wanted ~= (b ~= nil and b:IsShown()) then
            ns.Layout(s)
        elseif wanted then
            local hadText = b.textValue ~= nil
            UpdateButton(s, b)
            local fits
            if s.key == "bar" then
                fits = ButtonWidth(b, mod.db.barSize) <= (s.widths[l.key] or 0)
            else
                local need = BoxTextNeed(b) + (mod.db.boxLayout == "right" and mod.db.boxSize or 0)
                fits = hadText == (b.textValue ~= nil) and need <= (s.cellW or 0)
            end
            if not fits then ns.Layout(s) end
        end
    end
end

function ns.RefreshAll()
    for _, s in pairs(surfaces) do ns.Layout(s) end
end

---------------------------------------------------------------------------
-- Anlegen
---------------------------------------------------------------------------
local function NewSurface(key, name, roundTop)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetFrameStrata("LOW")   -- Fenster und Vollbildkarte liegen darueber
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()
    local s = { key = key, frame = f, buttons = {}, widths = {}, cells = {} }
    s.bg = ns.NewSkin(f, roundTop)
    s.marker = f:CreateTexture(nil, "OVERLAY")
    s.marker:SetColorTexture(0.55, 0.81, 0.30, 1)   -- Peon-Gruen
    s.marker:SetWidth(2)
    s.marker:Hide()
    f:SetScript("OnEnter", function() SetHover(s, true) end)
    f:SetScript("OnLeave", function()
        if not f:IsMouseOver() then SetHover(s, false) end
    end)
    -- Freie Stelle: Menue mit allen Modulen. Die Symbole fangen ihre Klicks selbst ab.
    f:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.OpenSurfaceMenu(s) end
    end)
    surfaces[key] = s
    return s
end

-- Gespeichert wird die linke obere Ecke des ersten Eintrags (zugeklappt), damit er beim Aufklappen stehen bleibt
function ns.SaveBoxPosition()
    local s = surfaces.box
    local f = s.frame
    local left, top = f:GetLeft(), f:GetTop()
    if not left or not top then return end
    local dir = mod.db.boxVis == "fold" and s.foldW and mod.db.boxFoldDir
    if dir == "up" then
        local bottom = f:GetBottom()
        if bottom then top = bottom + s.foldH end
    elseif dir == "left" then
        local r = f:GetRight()
        if r then left = r - s.foldW end
    end
    mod.db.boxPos.x, mod.db.boxPos.y = left, top
end

function ns.InitDisplay()
    if surfaces.bar then return end
    NewSurface("bar", "PeonPanelBar", false)
    local box = NewSurface("box", "PeonPanelBox", true).frame
    box:SetMovable(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", function(self)
        if not mod.db.boxLocked then
            surfaces.box.moving = true
            self:StartMoving()
        end
    end)
    box:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        surfaces.box.moving = nil
        ns.SaveBoxPosition()
    end)
    ns.ApplyAll()
end
