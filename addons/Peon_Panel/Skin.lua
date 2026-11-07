-- Peon_Panel - Skin.lua
-- Hintergrund von Leiste und Panel. Zwei Arten:
--   plain: eigene Stuecke. Das Spiel rundet Farbflaechen nicht ab, deshalb Rechtecke fuer Flaechen und Kanten und
--          zwei Bilder fuer die Ecken. Sie ueberlappen sich nicht, sonst saehe man bei durchscheinendem Hintergrund
--          dunklere Streifen.
--   sonst: Rahmen von Blizzard (NineSliceLayouts im Forever-Zweig von Gethe/wow-ui-source). Fehlt etwas, bleibt es bei plain.
-- roundTop = false: oben ohne Ecken (Leiste am oberen Bildschirmrand). Der Blizzard-Rahmen ragt dann oben aus dem Bild.

local ADDON_NAME, ns = ...

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local R = 12
local OVERHANG = 40   -- groesser als die Ecken aller Rahmen
ns.CORNER = R

-- tint: Rahmenfarbe gilt (die Metall- und Holzrahmen haben eigene Farben). center: Der Rahmen bringt die Flaeche mit.
-- corner: geschaetzte Eckgroesse, falls das Spiel sie nicht verraet
ns.STYLES = {
    tooltipDark = { layout = "TooltipDefaultDarkLayout", tint = true, center = true },
    tooltip     = { layout = "TooltipDefaultLayout", tint = true, center = true },
    metal       = { layout = "GenericMetal", corner = 132 },
    dialog      = { layout = "Dialog", corner = 32 },
    wood        = { layout = "WoodenNeutralFrameTemplate", corner = 132 },
    plain       = {},
}

local Skin = {}
Skin.__index = Skin

-- Das Bild zeigt die untere linke Ecke
local function Corner(self, list, layer, file, point, flipX, flipY)
    local t = self.frame:CreateTexture(nil, layer)
    t:SetTexture(MEDIA .. file, nil, nil, "TRILINEAR")
    t:SetTexCoord(flipX and 1 or 0, flipX and 0 or 1, flipY and 1 or 0, flipY and 0 or 1)
    t:SetSize(R, R)
    t:SetPoint(point, self.frame, point, 0, 0)
    list[#list + 1] = t
end

local function Rect(self, list, layer)
    local t = self.frame:CreateTexture(nil, layer)
    list[#list + 1] = t
    return t
end

local function Strip(self, point, x, height)
    local t = Rect(self, self.fillRects, "BACKGROUND")
    t:SetPoint(point .. "LEFT", self.frame, point .. "LEFT", x, 0)
    t:SetPoint(point .. "RIGHT", self.frame, point .. "RIGHT", -x, 0)
    t:SetHeight(height)
end

local function HLine(self, point)
    local t = Rect(self, self.lineRects, "BORDER")
    t:SetPoint(point .. "LEFT", self.frame, point .. "LEFT", R, 0)
    t:SetPoint(point .. "RIGHT", self.frame, point .. "RIGHT", -R, 0)
    t:SetHeight(1)
end

local function VLine(self, side, top)
    local t = Rect(self, self.lineRects, "BORDER")
    t:SetPoint("TOP" .. side, self.frame, "TOP" .. side, 0, -top)
    t:SetPoint("BOTTOM" .. side, self.frame, "BOTTOM" .. side, 0, R)
    t:SetWidth(1)
end

function ns.NewSkin(frame, roundTop)
    local self = setmetatable({ frame = frame, roundTop = roundTop, shown = true, fillRects = {}, fillCorners = {}, lineRects = {}, lineCorners = {} }, Skin)
    local top = roundTop and R or 0

    local middle = Rect(self, self.fillRects, "BACKGROUND")
    middle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top)
    middle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, R)
    Strip(self, "BOTTOM", R, R)
    Corner(self, self.fillCorners, "BACKGROUND", "corner_fill.tga", "BOTTOMLEFT", false, false)
    Corner(self, self.fillCorners, "BACKGROUND", "corner_fill.tga", "BOTTOMRIGHT", true, false)
    Corner(self, self.lineCorners, "BORDER", "corner_line.tga", "BOTTOMLEFT", false, false)
    Corner(self, self.lineCorners, "BORDER", "corner_line.tga", "BOTTOMRIGHT", true, false)
    HLine(self, "BOTTOM")
    VLine(self, "LEFT", top)
    VLine(self, "RIGHT", top)
    if roundTop then
        Strip(self, "TOP", R, R)
        Corner(self, self.fillCorners, "BACKGROUND", "corner_fill.tga", "TOPLEFT", false, true)
        Corner(self, self.fillCorners, "BACKGROUND", "corner_fill.tga", "TOPRIGHT", true, true)
        Corner(self, self.lineCorners, "BORDER", "corner_line.tga", "TOPLEFT", false, true)
        Corner(self, self.lineCorners, "BORDER", "corner_line.tga", "TOPRIGHT", true, true)
        HLine(self, "TOP")
    end
    return self
end

local function Paint(rects, corners, c)
    for _, t in ipairs(rects) do t:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
    for _, t in ipairs(corners) do t:SetVertexColor(c[1], c[2], c[3], c[4] or 1) end
end

local function ShowPlain(self, on)
    for _, group in ipairs({ self.fillRects, self.fillCorners, self.lineRects, self.lineCorners }) do
        for _, t in ipairs(group) do t:SetShown(on) end
    end
end

-- Rahmen von Blizzard. Liegt eine Ebene unter den Knoepfen, die sonst verdeckt werden koennten.
local function Nine(self)
    if self.nine then return self.nine end
    local ok, n = pcall(CreateFrame, "Frame", nil, self.frame, "NineSlicePanelTemplate")
    if not ok or not n then return nil end
    n:SetFrameLevel(self.frame:GetFrameLevel())
    n.fill = n:CreateTexture(nil, "BACKGROUND")
    self.nine = n
    return n
end

-- Metall, Holz und Dialog haben Ecken von 30 bis weit ueber 100 Punkten. Auf der schmalen Leiste hingen sie
-- unten heraus. Deshalb wird der ganze Rahmen so verkleinert, dass eine Ecke hoechstens CORNER_MAX gross ist.
-- Die Anker gelten trotz Verkleinerung fuer die volle Flaeche, nur die Abstaende zaehlen in seinem Massstab.
local CORNER_MAX = { bar = 14, box = 24 }

local function CornerSize(n)
    local c = n.BottomLeftCorner or n.TopLeftCorner
    if type(c) ~= "table" or not c.GetHeight then return 0 end
    local h, w = c:GetHeight() or 0, c.GetWidth and c:GetWidth() or 0
    return math.max(h, w)
end

local function FitNine(self, n, style)
    local size = CornerSize(n)
    if size <= 0 then size = style.corner or 0 end
    local limit = self.roundTop and CORNER_MAX.box or CORNER_MAX.bar
    local scale = size > limit and limit / size or 1
    if n.SetScale then n:SetScale(scale) end
    n:ClearAllPoints()
    n:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, self.roundTop and 0 or OVERHANG / scale)
    n:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    local inset = math.max(4, math.floor(size * 0.25))
    n.fill:ClearAllPoints()
    n.fill:SetPoint("TOPLEFT", n, "TOPLEFT", inset, -inset)
    n.fill:SetPoint("BOTTOMRIGHT", n, "BOTTOMRIGHT", -inset, inset)
    self.scale = scale
end

local function ApplyNine(self, style, fill, line)
    local util = rawget(_G, "NineSliceUtil")
    if not util or not util.GetLayout or not util.GetLayout(style.layout) then return false end
    local n = Nine(self)
    if not n then return false end
    util.ApplyLayoutByName(n, style.layout)
    FitNine(self, n, style)
    n.fill:SetColorTexture(fill[1], fill[2], fill[3], fill[4] or 1)
    n.fill:SetShown(not style.center)
    if n.Center then n.Center:SetShown(style.center == true) end
    if style.center and n.SetCenterColor then n:SetCenterColor(fill[1], fill[2], fill[3], fill[4] or 1) end
    if n.SetBorderColor then
        if style.tint then
            n:SetBorderColor(line[1], line[2], line[3], line[4] or 1)
        else
            n:SetBorderColor(1, 1, 1, 1)
        end
    end
    n:Show()
    return true
end

-- Stil, Farben und Sichtbarkeit in einem Schritt. Rueckgabe: der wirklich verwendete Stil
function Skin:Apply(styleKey, fill, line, shown)
    self.shown = shown and true or false
    local style = ns.STYLES[styleKey] or ns.STYLES.plain
    local used = "plain"
    if self.shown and style.layout then
        local ok, done = pcall(ApplyNine, self, style, fill, line)
        if ok and done then used = styleKey end
    end
    if used == "plain" and self.nine then self.nine:Hide() end
    if not self.shown and self.nine then self.nine:Hide() end
    Paint(self.fillRects, self.fillCorners, fill)
    Paint(self.lineRects, self.lineCorners, line)
    ShowPlain(self, self.shown and used == "plain")
    self.used = used
    return used
end
