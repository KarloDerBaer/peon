-- Peon_Bags - Window.lua
-- Gemeinsames Fenster fuer Taschen, Bank und Gildenbank: Rahmen mit Titel und Schliessen-Knopf,
-- Leiste (Taschen/Faecher), Suchfeld, Knopfreihe, Inhalt in Abschnitten (Ueberschrift + Raster), Fusszeile.
-- Position (Ziehen am Kopf) und Groesse je Fenster in PeonBagsDB.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

ns.windows = {}

local SLOT, GAP, PAD = 37, 4, 10
local HDR_H, SEC_GAP = 16, 6
local TOP_H, FOOT_H, MIN_W = 84, 28, 330
ns.SLOT, ns.GAP = SLOT, GAP

local Window = {}
Window.__index = Window

local function Rel(f)
    local p = UIParent:GetEffectiveScale()
    local e = f:GetEffectiveScale()
    if not p or p <= 0 or not e or e <= 0 then return 1 end
    return e / p
end

local function SmallButton(parent, text, width, tip, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 20)
    b:SetText(text)
    b:SetScript("OnClick", function(self, button) mod:Call("Knopf", onClick, self, button) end)
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self:GetText() or text, 1, 1, 1)
            GameTooltip:AddLine(tip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
end
ns.SmallButton = SmallButton

-- key: "bag" | "bank" | "guild" (Praefix der Einstellungen bagCols, bagScale, bagLayout ...)
-- opts: title, point = { Punkt, x, y } (Standardposition), onHide = fn(w), searchable = true
function ns.NewWindow(key, opts)
    local w = setmetatable({ key = key, opts = opts, headers = {}, used = {} }, Window)
    local name = "PeonBags" .. key:gsub("^%l", string.upper) .. "Frame"
    -- Rahmen wie Blizzards Fenster (ab 0.2): Taschen = PortraitFrameFlatTemplate (wie Blizzards Taschen),
    -- Bank = PortraitFrameTemplate (wie Blizzards Bank), Gildenbank = BasicFrameTemplate (wie Blizzards
    -- Gildenbank). Rueckfall: BasicFrameTemplateWithInset, dann einfacher Rahmen.
    local f
    local templates = { opts.template, "BasicFrameTemplateWithInset" }
    for _, t in ipairs(templates) do
        if t then
            local ok, fr = pcall(CreateFrame, "Frame", name, UIParent, t)
            if ok and fr then f, w.template = fr, t break end
        end
    end
    if not f then
        f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
        if f.SetBackdrop then
            pcall(f.SetBackdrop, f, { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
                insets = { left = 6, right = 6, top = 6, bottom = 6 } })
        end
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
    end
    w.frame = f
    -- rundes Bild oben links (nur bei den Portrait-Vorlagen)
    w.portrait = (w.template == "PortraitFrameFlatTemplate" or w.template == "PortraitFrameTemplate")
        and (type(f.SetPortraitToAsset) == "function" or type(f.PortraitContainer) == "table" or type(f.portrait) == "table")
    if w.portrait then
        if opts.portraitSize and type(f.SetPortraitTextureSizeAndOffset) == "function" then
            -- kleiner Ring wie Blizzards Taschen: Die Vorlage bringt sonst den grossen Ring mit, der
            -- nicht zum kleinen Bild passt und in die Taschenleiste ragt
            if opts.border and type(f.SetBorder) == "function" then pcall(f.SetBorder, f, opts.border) end
            pcall(f.SetPortraitTextureSizeAndOffset, f, opts.portraitSize, -4, 1)
            if type(f.SetTitleOffsets) == "function" then pcall(f.SetTitleOffsets, f, opts.portraitSize - 1) end
            -- runde Maske genau auf das kleine Bild legen (wie Blizzards Taschen in Forever)
            local pc = f.PortraitContainer
            if type(pc) == "table" and type(pc.CircleMask) == "table" and type(pc.portrait) == "table" then
                pc.CircleMask:ClearAllPoints()
                pc.CircleMask:SetPoint("TOPLEFT", pc.portrait, "TOPLEFT", 0, 0)
                pc.CircleMask:SetPoint("BOTTOMRIGHT", pc.portrait, "BOTTOMRIGHT", 0, 0)
            end
        end
        w:SetPortrait(opts.portrait)
    end
    f:Hide()
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        w:SavePosition()
    end)
    f:SetScript("OnHide", function()
        if opts.onHide then mod:Call("Schliessen", opts.onHide, w) end
        if ns.focusBag then ns.focusBag = nil end
    end)
    f:SetScript("OnShow", function()
        if opts.portrait == "npc" then w:SetPortrait("npc") end   -- Bank: Bild des Bankiers
        if opts.onShow then mod:Call("Oeffnen", opts.onShow, w) end
    end)
    -- ESC schliesst (nur Eintrag hinzufuegen, Blizzard-Tabelle nicht neu zuweisen)
    local special = rawget(_G, "UISpecialFrames")
    if type(special) == "table" then table.insert(special, name) end

    local title = f.TitleText
    if type(title) ~= "table" and type(f.TitleContainer) == "table" then title = f.TitleContainer.TitleText end
    if type(title) ~= "table" then title = f.title end
    if type(title) ~= "table" then
        title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -6)
    end
    title:SetText(opts.title or "")
    w.title = title

    -- Leiste (Taschen/Faecher), links unter dem Titel
    w.bar = CreateFrame("Frame", nil, f)
    w.bar:SetPoint("TOPLEFT", w.portrait and (opts.portraitSize and 42 or 58) or PAD, -28)
    w.bar:SetSize(1, 24)

    -- Suchfeld rechts
    if opts.searchable ~= false then
        local sb
        local ok2 = pcall(function() sb = CreateFrame("EditBox", nil, f, "SearchBoxTemplate") end)
        if not ok2 or not sb then sb = CreateFrame("EditBox", nil, f, "InputBoxTemplate") end
        sb:SetSize(130, 20)
        sb:SetPoint("TOPRIGHT", -PAD - 2, -30)
        sb:SetAutoFocus(false)
        sb:HookScript("OnTextChanged", function(self) ns.SetSearch(self:GetText()) end)
        sb:HookScript("OnEscapePressed", function(self) self:ClearFocus() end)
        w.search = sb
    end

    -- Knopfreihe
    w.buttons = CreateFrame("Frame", nil, f)
    w.buttons:SetPoint("TOPLEFT", (w.portrait and not opts.portraitSize) and 58 or PAD, -54)
    w.buttons:SetSize(1, 22)
    w.btnX = 0

    -- Inhalt
    w.content = CreateFrame("Frame", nil, f)
    w.content:SetPoint("TOPLEFT", PAD, -TOP_H)
    w.content:SetSize(1, 1)

    -- Fusszeile
    w.footLeft = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.footLeft:SetPoint("BOTTOMLEFT", PAD + 2, 10)
    w.footLeft:SetJustifyH("LEFT")
    w.footRight = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.footRight:SetPoint("BOTTOMRIGHT", -PAD - 2, 10)
    w.footRight:SetJustifyH("RIGHT")

    ns.windows[key] = w
    return w
end

function Window:AddButton(text, width, tip, onClick)
    local b = SmallButton(self.buttons, text, width, tip, onClick)
    b:SetPoint("LEFT", self.buttons, "LEFT", self.btnX, 0)
    self.btnX = self.btnX + width + 4
    return b
end

-- Knopfreihe neu anordnen (sichtbare Knoepfe nebeneinander)
function Window:ArrangeButtons(list)
    local x = 0
    for _, b in ipairs(list) do
        if b:IsShown() then
            b:ClearAllPoints()
            b:SetPoint("LEFT", self.buttons, "LEFT", x, 0)
            x = x + (b:GetWidth() or 80) + 4
        end
    end
end

function Window:Setting(name) return mod.db[self.key .. name] end

function Window:Cols() return self:Setting("Cols") or 10 end
function Window:Layout() return self:Setting("Layout") or "bags" end

function Window:ToggleLayout()
    local k = self.key .. "Layout"
    mod.db[k] = (mod.db[k] == "type") and "bags" or "type"
    mod:Fire("CHANGED", k)
    self:UpdateLayoutButton()
    if mod.page and mod.page.Refresh then pcall(mod.page.Refresh, mod.page) end
end

function Window:LayoutText()
    return L.LAYOUT_TYPE
end

-- Bild oben links (Datei/Icon); nur bei Portrait-Rahmen
function Window:SetPortrait(asset)
    local f = self.frame
    if not self.portrait or not asset or not f then return end
    if asset == "npc" and type(f.SetPortraitToUnit) == "function" then
        pcall(f.SetPortraitToUnit, f, "npc")
    elseif type(f.SetPortraitToAsset) == "function" then
        pcall(f.SetPortraitToAsset, f, asset)
    end
end

-- Umschalter "Nach Art" (ab 0.2): grau = Taschenreihenfolge, farbig = nach Art
function Window:AddLayoutToggle()
    local b = self:AddButton(L.LAYOUT_TYPE, 84, L.BTN_LAYOUT_TIP, function() self:ToggleLayout() end)
    self.layoutBtn = b
    self:UpdateLayoutButton()
    return b
end

function Window:UpdateLayoutButton()
    local b = self.layoutBtn
    if not b then return end
    local on = self:Layout() == "type"
    b.peonOn = on
    b:SetText(L.LAYOUT_TYPE)
    local fo = on and rawget(_G, "GameFontNormal") or rawget(_G, "GameFontDisable")
    if fo and b.SetNormalFontObject then pcall(b.SetNormalFontObject, b, fo) end
    -- Knopf-Grafik grau bzw. farbig (nur wenige Teile, kein Risiko mit vielen Rueckgabewerten)
    for _, k in ipairs({ "Left", "Middle", "Right" }) do
        local t = b[k]
        if type(t) == "table" and t.SetDesaturated then t:SetDesaturated(not on) end
    end
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
        local t = type(b[get]) == "function" and b[get](b) or nil
        if type(t) == "table" and t.SetDesaturated then t:SetDesaturated(not on) end
    end
end

---------------------------------------------------------------------------
-- Position und Groesse
---------------------------------------------------------------------------
function Window:SavePosition()
    local f = self.frame
    local left, top = f:GetLeft(), f:GetTop()
    if not left or not top then return end
    local r = Rel(f)
    mod.db.pos[self.key] = { x = math.floor(left * r * 10 + 0.5) / 10, y = math.floor(top * r * 10 + 0.5) / 10 }
end

function Window:ApplyPosition()
    local f = self.frame
    if ns.Locked(f) then ns.Defer("pos:" .. self.key, function() self:ApplyPosition() end) return end
    local s = (self:Setting("Scale") or 100) / 100
    f:SetScale(s)
    f:ClearAllPoints()
    local p = mod.db.pos and mod.db.pos[self.key]
    if type(p) == "table" and ns.Num(p.x) and ns.Num(p.y) then
        local r = Rel(f)
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x / r, p.y / r)
    else
        local d = self.opts.point or { "CENTER", 0, 0 }
        f:SetPoint(d[1], UIParent, d[1], d[2], d[3])
    end
end

---------------------------------------------------------------------------
-- Abschnitte anordnen
-- sections = { { title = Text oder nil, items = { Knopf, ... }, keepEmpty, target }, ... }
-- keepEmpty = Ueberschrift auch ohne Gegenstaende zeigen
-- target = nimmt abgelegte Gegenstaende an (Bereich-id oder ns.GROUP_NONE, siehe Groups.lua), nil = reine Schrift
---------------------------------------------------------------------------
local function Header(w, i)
    local h = w.headers[i]
    if not h then
        -- Rahmen statt reiner Schrift (ab 0.3), nicht geschuetzt: darf sich auch im Kampf bewegen
        h = CreateFrame("Button", nil, w.content)
        h:SetHeight(HDR_H)
        h.label = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h.label:SetPoint("TOPLEFT", 0, 0)
        h.label:SetPoint("TOPRIGHT", 0, 0)
        h.label:SetJustifyH("LEFT")
        h:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        h:RegisterForClicks("LeftButtonUp")
        h:RegisterForDrag("LeftButton")
        local function Drop(self) mod:Call("Bereich", ns.DropOnHeader, self.target) end
        h:SetScript("OnClick", Drop)
        h:SetScript("OnReceiveDrag", Drop)
        -- Ziehen an der Ueberschrift bewegt weiter das Fenster
        h:SetScript("OnDragStart", function() w.frame:StartMoving() end)
        h:SetScript("OnDragStop", function()
            w.frame:StopMovingOrSizing()
            w:SavePosition()
        end)
        h:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.text or "", 1, 1, 1)
            GameTooltip:AddLine(self.target == ns.GROUP_NONE and L.GROUP_TIP_OUT or L.GROUP_TIP_IN, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        w.headers[i] = h
    end
    return h
end

function Window:Arrange(sections, allButtons)
    local f = self.frame
    -- im Kampf: geschuetzte Knoepfe nicht bewegen, spaeter nachholen
    for _, sec in ipairs(sections) do
        for _, b in ipairs(sec.items) do
            if ns.Locked(b) then
                ns.Defer("arrange:" .. self.key, function() self:Arrange(sections, allButtons) end)
                return false
            end
        end
    end
    local cols = self:Cols()
    local step = SLOT + GAP
    local y, hi, maxCols = 0, 0, 1
    local shown = {}
    for _, sec in ipairs(sections) do
        local n = #sec.items
        if n > 0 or sec.keepEmpty then
            if sec.title then
                hi = hi + 1
                local h = Header(self, hi)
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
                h:SetWidth(cols * step - GAP)
                h.label:SetText(sec.title)
                h.text, h.target = sec.title, sec.target
                h:EnableMouse(sec.target ~= nil)
                h:Show()
                y = y + HDR_H
            end
            for i, b in ipairs(sec.items) do
                local row, col = math.floor((i - 1) / cols), (i - 1) % cols
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", self.content, "TOPLEFT", col * step, -(y + row * step))
                b:Show()
                shown[b] = true
            end
            if n > maxCols then maxCols = math.min(n, cols) end
            y = y + math.ceil(n / cols) * step + SEC_GAP
        end
    end
    for i = hi + 1, #self.headers do self.headers[i]:Hide() end
    for _, b in ipairs(allButtons or {}) do
        if not shown[b] then b:Hide() end
    end
    local width = math.max(MIN_W, PAD * 2 + cols * step - GAP)
    local height = TOP_H + math.max(y - SEC_GAP, SLOT) + FOOT_H + 6
    self.content:SetSize(cols * step - GAP, math.max(1, y))
    if not ns.Locked(f) then f:SetSize(width, height) end
    return true
end

function Window:SetFooter(left, right)
    self.footLeft:SetText(left or "")
    self.footRight:SetText(right or "")
end

function Window:Show() if not self.frame:IsShown() then self.frame:Show() end end
function Window:Hide() if self.frame:IsShown() then self.frame:Hide() end end
function Window:IsShown() return self.frame:IsShown() end
function Window:Toggle() if self:IsShown() then self:Hide() else self:Show() end end

-- Geld als Text mit Muenzsymbolen
function ns.Money(copper)
    copper = tonumber(copper) or 0
    local f = rawget(_G, "GetMoneyString") or rawget(_G, "GetCoinTextureString")
    if f then
        local ok, s = pcall(f, copper, true)
        if ok and s then return s end
    end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    return ("%dg %ds %dc"):format(g, s, c)
end

-- Suchfeld aller Fenster gleich halten und Plaetze neu einfaerben
function ns.OnSearch()
    for _, w in pairs(ns.windows) do
        if w.OnSearch then mod:Call("Suche", w.OnSearch, w) end
    end
end
