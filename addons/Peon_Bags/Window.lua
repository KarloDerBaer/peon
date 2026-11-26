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
local HDR_H, SEC_GAP, PACK_GAP = 16, 6, 14
local TOP_H, FOOT_H, MIN_W = 84, 28, 330
ns.SLOT, ns.GAP = SLOT, GAP

local Window = {}
Window.__index = Window
ns.Window = Window   -- Setup.lua ergaenzt den Knopf "Einstellen"

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
-- opts: title, point = { Punkt, x, y } (Standardposition), onHide = fn(w), searchable = true,
--       searchWidth (Breite des Suchfelds), topH (Abstand des Inhalts von oben, ab 0.10 fuer den Schluesselbund)
function ns.NewWindow(key, opts)
    local w = setmetatable({ key = key, opts = opts, headers = {}, used = {}, keepNew = {},
                             minW = opts.minWidth or MIN_W, topH = opts.topH or TOP_H }, Window)
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
        if w.OnMoved then w:OnMoved() end
    end)
    f:SetScript("OnHide", function()
        wipe(w.keepNew)   -- "Neu" gilt bis zum Schliessen
        w.frozen = nil    -- beim naechsten Oeffnen wieder platzsparend anordnen (ab 0.10)
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
    w.barX = w.portrait and (opts.portraitSize and 42 or 58) or PAD
    w.bar:SetPoint("TOPLEFT", w.barX, -28)
    w.bar:SetSize(1, 24)

    -- Suchfeld rechts
    if opts.searchable ~= false then
        local sb
        local ok2 = pcall(function() sb = CreateFrame("EditBox", nil, f, "SearchBoxTemplate") end)
        if not ok2 or not sb then sb = CreateFrame("EditBox", nil, f, "InputBoxTemplate") end
        sb:SetSize(opts.searchWidth or 130, 20)
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
    w.content:SetPoint("TOPLEFT", PAD, -w.topH)
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

-- Schluessel der Einstellungen: sonst der des Fensters, in der gespeicherten Ansicht der Bank "bank" (ab 0.8)
function Window:SKey() return self.cfgKey or self.key end

function Window:Setting(name) return mod.db[self:SKey() .. name] end

function Window:Cols() return self:Setting("Cols") or 10 end
function Window:Layout() return self:Setting("Layout") or "classic" end

-- Einstellung des Fensters aendern und alle benachrichtigen (Fenster, Leiste "Einstellen", Optionsseite)
function Window:Set(name, value)
    local k = self:SKey() .. name
    mod.db[k] = value
    mod:Fire("CHANGED", k)
    if mod.page and mod.page.Refresh then pcall(mod.page.Refresh, mod.page) end
end

-- Tabelle des Fensters (CatsOff, GroupsOff, Collapsed), fehlt sie, wird sie angelegt
function Window:Table(name)
    local k = self:SKey() .. name
    if type(mod.db[k]) ~= "table" then mod.db[k] = {} end
    return mod.db[k]
end

-- Alles, was ns.BuildSections fuer dieses Fenster braucht (ab 0.5)
function Window:SectionConfig()
    local layout = self:Layout()
    local empty = self:Setting("Empty") or "slot"
    return { layout = layout, catsOff = self:Table("CatsOff"), groupsOff = self.useGroups and self:Table("GroupsOff") or {},
             collapsed = self:Table("Collapsed"), useGroups = self.useGroups, keepNew = self.keepNew,
             freeStack = self:Setting("FreeStack") and true or false, emptyMode = empty,
             dragging = empty == "drag" and ns.CursorItem() or false }
end

-- Abschnitt ein- oder ausklappen (Klick auf die Ueberschrift ohne Gegenstand am Mauszeiger)
function Window:ToggleCollapse(key)
    local t = self:Table("Collapsed")
    t[key] = (not t[key]) or nil
    self.frozen = nil
    mod:Fire("CHANGED", self:SKey() .. "Collapsed")
end

-- Knopf als gewaehlt (farbig) oder nicht (grau) zeigen
function ns.SetButtonOn(b, on)
    if not b then return end
    b.peonOn = on and true or false
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
---------------------------------------------------------------------------
-- Ueberschrift ziehen: Reihenfolge von Kategorien und eigenen Bereichen (ab 0.6)
---------------------------------------------------------------------------
-- Art und Schluessel einer verschiebbaren Ueberschrift: "c:<Kategorie>" oder "g<Bereich-id>"
function ns.Movable(key)
    if type(key) ~= "string" then return nil end
    local cat = key:match("^c:(.+)$")
    if cat then return "cat", cat end
    local id = tonumber(key:match("^g(%d+)$") or "")
    if id then return "group", id end
    return nil
end

local ghost
local function Ghost()
    if ghost then return ghost end
    ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetSize(200, 16)
    ghost.text = ghost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ghost.text:SetPoint("LEFT", 0, 0)
    ghost:Hide()
    ghost:SetScript("OnUpdate", function(self)
        local gc = rawget(_G, "GetCursorPosition")
        if type(gc) ~= "function" then return end
        local cx, cy = gc()
        local sc = UIParent:GetEffectiveScale()
        if not ns.Num(cx) or not ns.Num(sc) or sc <= 0 then return end
        self:ClearAllPoints()
        self:SetPoint("LEFT", UIParent, "BOTTOMLEFT", cx / sc + 14, cy / sc)
    end)
    return ghost
end

function ns.StartHeaderDrag(w, h)
    w.dragHeader = h
    h:SetAlpha(0.4)
    local g = Ghost()
    g.text:SetText(h.text or "")
    g:Show()
end

-- Loslassen ueber einer anderen Ueberschrift derselben Art: davor bzw. dahinter einsortieren
function ns.StopHeaderDrag(w, h)
    if ghost then ghost:Hide() end
    h:SetAlpha(1)
    w.dragHeader = nil
    local kind, from = ns.Movable(h.key)
    if not kind then return end
    for _, other in ipairs(w.headers) do
        if other ~= h and other:IsShown() and other:IsMouseOver() then
            local k2, to = ns.Movable(other.key)
            if k2 == kind then
                if kind == "cat" then ns.MoveCatTo(from, to) else ns.MoveGroupTo(from, to) end
            end
            return
        end
    end
end

local PLUS = "|TInterface\\Buttons\\UI-PlusButton-Up:12:12:0:0|t "
local MINUS = "|TInterface\\Buttons\\UI-MinusButton-Up:12:12:0:0|t "

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
        local function Drop(self) if self.target ~= nil then mod:Call("Bereich", ns.DropOnHeader, self.target) end end
        -- Klick: mit Gegenstand am Mauszeiger ablegen, mit leerem Mauszeiger ein- oder ausklappen (ab 0.5)
        h:SetScript("OnClick", function(self)
            local cursor = rawget(_G, "GetCursorInfo")
            local kind = type(cursor) == "function" and cursor() or nil
            if kind then
                if kind == "item" then Drop(self) end
                return
            end
            if self.key then w:ToggleCollapse(self.key) end
        end)
        h:SetScript("OnReceiveDrag", Drop)
        -- Ziehen an der Ueberschrift: Kategorien und eigene Bereiche umsortieren (ab 0.6), sonst das Fenster bewegen
        h:SetScript("OnDragStart", function(self)
            if ns.Movable(self.key) then ns.StartHeaderDrag(w, self) else w.frame:StartMoving(); w.movingByHeader = true end
        end)
        h:SetScript("OnDragStop", function(self)
            if w.movingByHeader then
                w.movingByHeader = nil
                w.frame:StopMovingOrSizing()
                w:SavePosition()
                if w.OnMoved then w:OnMoved() end
            else
                ns.StopHeaderDrag(w, self)
            end
        end)
        h:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.text or "", 1, 1, 1)
            if self.target ~= nil then
                GameTooltip:AddLine(self.target == ns.GROUP_NONE and L.GROUP_TIP_OUT or L.GROUP_TIP_IN, nil, nil, nil, true)
            end
            if self.key then GameTooltip:AddLine(L.COLLAPSE_TIP, nil, nil, nil, true) end
            if ns.Movable(self.key) then GameTooltip:AddLine(L.DRAG_TIP, nil, nil, nil, true) end
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        w.headers[i] = h
    end
    return h
end

-- Breite einer Ueberschrift in Pixeln (Text plus etwas Luft), 0, wenn das Spiel sie nicht misst
local function TextWidth(h)
    local ok, wdt = pcall(h.label.GetStringWidth, h.label)
    return (ok and ns.Num(wdt)) and math.ceil(wdt) + 4 or 0
end

-- Ablage-Platz fuer einen leeren eigenen Bereich (ab 0.7, Einstellung <Fenster>Empty = "slot" oder "drag"):
-- ein leerer Platz statt des langen Hinweises in der Ueberschrift. Kein Taschenknopf, nimmt nur Zuordnungen an.
local function DropSlot(w, i)
    w.dropSlots = w.dropSlots or {}
    local b = w.dropSlots[i]
    if b then return b end
    b = CreateFrame("Button", nil, w.content)
    b:SetSize(SLOT, SLOT)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:RegisterForClicks("LeftButtonUp")
    local function Drop(self)
        if self.target ~= nil and ns.CursorItem() then mod:Call("Bereich", ns.DropOnHeader, self.target) end
    end
    b:SetScript("OnClick", Drop)
    b:SetScript("OnReceiveDrag", Drop)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.text or "", 1, 1, 1)
        GameTooltip:AddLine(L.DROP_SLOT_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    w.dropSlots[i] = b
    return b
end

-- Abschnitte auf Zeilen verteilen, rein rechnerisch (ab 0.7, vorher Teil von Arrange).
-- blocks: { n = Plaetze, titled = mit Ueberschrift, headerW = Breite der Ueberschrift, folded, width = eigene Spalten }
-- o: { cols, pack, fill, narrow }
--   pack:   kleine Abschnitte teilen sich eine Zeile (ab 0.6). Ohne Ueberschrift oder volle Breite: allein.
--   fill:   ein Abschnitt kommt in die erste Zeile, in der er noch Platz hat, nicht nur in die letzte.
--   narrow: ein grosser Abschnitt (mehr Plaetze als Spalten) wird so schmal, wie es bei gleich vielen Reihen geht.
--   width:  eigene Spaltenzahl des Abschnitts (Breite je Abschnitt), gilt vor narrow.
-- Rueckgabe: { [i] = { x, y, c = Spalten der Plaetze, width, height } }, Hoehe
function ns.PlanLayout(blocks, o)
    if o.balance and o.pack then return ns.PlanBalanced(blocks, o) end
    local cols = o.cols
    local step = SLOT + GAP
    local full = cols * step - GAP
    local res, lines = {}, {}
    for i, bl in ipairs(blocks) do
        local n = bl.folded and 0 or bl.n
        local alone = not o.pack or not bl.titled
        local c
        if ns.Num(bl.width) and bl.width > 0 then c = math.min(bl.width, cols)
        elseif alone then c = cols
        elseif n <= cols then c = math.max(1, n)
        elseif o.narrow then c = math.ceil(n / math.ceil(n / cols))
        else c = cols end
        local rows = n > 0 and math.ceil(n / c) or 0
        local width = n > 0 and math.min(n, c) * step - GAP or 0
        width = math.min(full, math.max(width, bl.headerW or 0, 1))
        if alone or width >= full then alone, width = true, full end
        local p = { c = c, width = width, alone = alone,
                    height = (bl.titled and HDR_H or 0) + rows * step }
        res[i] = p
        -- Zeile suchen: ohne fill nur die letzte, mit fill die erste mit genug Platz
        local line
        if not alone then
            local first = o.fill and 1 or #lines
            for k = math.max(1, first), #lines do
                local l = lines[k]
                if not l.alone and l.used + PACK_GAP + width <= full then line = l break end
            end
        end
        if line then
            p.x = line.used + PACK_GAP
            line.used = p.x + width
            line.h = math.max(line.h, p.height)
        else
            line = { alone = alone, used = width, h = p.height }
            p.x = 0
            lines[#lines + 1] = line
        end
        line[#line + 1] = p
    end
    local y = 0
    for k, l in ipairs(lines) do
        if k > 1 then y = y + SEC_GAP end
        for _, p in ipairs(l) do p.y, p.line = y, k end
        y = y + l.h
    end
    return res, y
end

-- Zeilen ausgleichen (ab 0.11, o.balance): Die Abschnitte bleiben in ihrer Reihenfolge. Fuer alle Zeilen zusammen
-- wird geplant, welche Abschnitte sich eine Zeile teilen und in wie vielen Reihen sie dort umbrechen, so dass das
-- Fenster am niedrigsten wird. Kein Abschnitt wird schmaler als MIN_C Spalten (ausser er hat weniger Plaetze).
-- Bleibt in einer Zeile Breite uebrig, werden ihre Abschnitte wieder breiter, solange sie dadurch Reihen sparen.
-- Stapeln (o.stack): Ist ein Abschnitt niedriger als seine Zeile, kommt ein spaeterer Abschnitt derselben Zeile
-- darunter, wenn er in die Hoehe passt und die Zeile dadurch schmaler bleibt als mit einer weiteren Spalte.
-- Abschnitte eines Stapels stehen an derselben Stelle x, p.dy ist der Abstand zur Oberkante der Zeile.
local MIN_C = 3
function ns.PlanBalanced(blocks, o)
    local cols = o.cols
    local step = SLOT + GAP
    local full = cols * step - GAP
    local N = #blocks
    local function Count(bl) return bl.folded and 0 or bl.n end
    local function Size(bl, c)
        local n = Count(bl)
        local rows = n > 0 and math.ceil(n / c) or 0
        local width = math.min(full, math.max(n > 0 and c * step - GAP or 0, bl.headerW or 0, 1))
        return width, (bl.titled and HDR_H or 0) + rows * step
    end
    -- Form bei hoechstens maxRows Reihen, so schmal wie moeglich: Spalten, Breite, Hoehe (nil = passt nicht)
    local function Shape(bl, maxRows)
        local n = Count(bl)
        local c
        if n == 0 then c = 1
        elseif ns.Num(bl.width) and bl.width > 0 then c = math.min(bl.width, cols)
        else c = math.min(cols, math.max(math.ceil(n / maxRows), math.min(n, MIN_C))) end
        if n > 0 and math.ceil(n / c) > maxRows then return nil end
        local w, h = Size(bl, c)
        return c, w, h
    end
    -- Zeile aus den Abschnitten i..j, Zeilenhoehe hoechstens H (R Reihen). Rueckgabe: Hoehe, Plan je Abschnitt
    local function Line(i, j, H, R)
        local stacks, used = {}, -PACK_GAP
        local plan = {}
        for k = i, j do
            local bl = blocks[k]
            local n = Count(bl)
            local c2, w2, h2 = Shape(bl, R)
            if not c2 then return nil end
            local best, bc, bw, bh, grow
            if o.stack then
                for _, s in ipairs(stacks) do
                    local rest = H - s.h - SEC_GAP
                    local rows = math.floor((rest - HDR_H) / step)
                    if rest >= HDR_H and (rows >= 1 or n == 0) then
                        local c, w, h = Shape(bl, math.max(rows, 1))
                        if c and s.h + SEC_GAP + h <= H then
                            local g = math.max(s.w, w) - s.w
                            if not best or g < grow then best, bc, bw, bh, grow = s, c, w, h, g end
                        end
                    end
                end
            end
            local p
            if best and grow < PACK_GAP + w2 then
                p = { c = bc, width = bw, height = bh, bl = bl }
                used = used + grow
                best.w, best.h = best.w + grow, best.h + SEC_GAP + bh
                best[#best + 1] = p
            else
                p = { c = c2, width = w2, height = h2, bl = bl }
                local s = { w = w2, h = h2, p }
                stacks[#stacks + 1] = s
                used = used + PACK_GAP + w2
            end
            plan[k] = p
            if used > full then return nil end
        end
        -- uebrige Breite: Abschnitte breiter machen, solange das Reihen spart (im Stapel bis zu dessen Breite)
        local left = full - used
        for _, s in ipairs(stacks) do
            local add = 0
            for _, p in ipairs(s) do
                local bl = p.bl
                local n = Count(bl)
                if n > 0 and not (ns.Num(bl.width) and bl.width > 0) then
                    local rows = math.ceil(n / p.c)
                    for c = math.min(n, cols), p.c + 1, -1 do
                        local w, h = Size(bl, c)
                        local g = math.max(0, w - s.w - add)
                        if math.ceil(n / c) < rows and g <= left - add then
                            p.c, p.width, p.height, add = c, w, h, add + g
                            break
                        end
                    end
                end
            end
            -- nur so viel nehmen, wie der breiteste Abschnitt des Stapels braucht
            local w = 0
            for _, p in ipairs(s) do w = math.max(w, p.width) end
            add = math.max(0, w - s.w)
            s.w, left = s.w + add, left - add
        end
        local x, top = 0, 0
        for _, s in ipairs(stacks) do
            local dy = 0
            for _, p in ipairs(s) do
                p.x, p.dy, p.bl = x, dy, nil
                dy = dy + p.height + SEC_GAP
            end
            top = math.max(top, dy - SEC_GAP)
            x = x + s.w + PACK_GAP
        end
        return top, plan
    end
    -- beste Aufteilung in Zeilen, von hinten geplant: best[i] = niedrigste Hoehe ab Abschnitt i
    local best = { [N + 1] = { h = 0 } }
    for i = N, 1, -1 do
        local bl = blocks[i]
        if not bl.titled then
            -- ohne Ueberschrift: allein, volle Breite
            local n = Count(bl)
            local p = { c = cols, width = full, height = (n > 0 and math.ceil(n / cols) or 0) * step, x = 0, dy = 0, alone = true }
            best[i] = { h = p.height + (i < N and SEC_GAP or 0) + best[i + 1].h, j = i, lh = p.height, plan = { [i] = p } }
        else
            local maxR = 1
            for j = i, N do
                if not blocks[j].titled then break end
                local bj, n = blocks[j], Count(blocks[j])
                local cmin = ns.Num(bj.width) and bj.width > 0 and math.min(bj.width, cols) or math.min(n, MIN_C)
                maxR = math.max(maxR, math.ceil(n / math.max(1, cmin)))
                local lh, plan
                for R = 1, maxR do
                    local h, p = Line(i, j, HDR_H + R * step, R)
                    if h and (not lh or h < lh) then lh, plan = h, p end
                end
                if not lh then break end   -- passt schon so nicht, mit weiteren Abschnitten erst recht nicht
                local total = lh + (j < N and SEC_GAP or 0) + best[j + 1].h
                if not best[i] or total < best[i].h then best[i] = { h = total, j = j, lh = lh, plan = plan } end
            end
            if not best[i] then   -- Sicherheitsnetz: allein, so breit wie moeglich
                local c = ns.Num(bl.width) and bl.width > 0 and math.min(bl.width, cols) or cols
                local w, h = Size(bl, c)
                local p = { c = c, width = w, height = h, x = 0, dy = 0, alone = true }
                best[i] = { h = h + (i < N and SEC_GAP or 0) + best[i + 1].h, j = i, lh = h, plan = { [i] = p } }
            end
        end
    end
    local res, y, line, i = {}, 0, 0, 1
    while i <= N do
        local b = best[i]
        line = line + 1
        for k = i, b.j do
            local p = b.plan[k]
            p.y, p.line = y + p.dy, line
            if not p.alone then p.alone = p.x == 0 and p.dy == 0 and p.width >= full and i == b.j end
            res[k] = p
        end
        y = y + b.lh + (b.j < N and SEC_GAP or 0)
        i = b.j + 1
    end
    return res, y
end

-- Anordnung festhalten (ab 0.10, Einstellung holdLayout): Solange das Fenster offen ist, bleibt jeder Abschnitt
-- in seiner Zeile an seiner Stelle und behaelt seine Breite. Waechst er, bekommt er weitere Reihen, statt dass
-- die anderen Abschnitte springen. Leere Abschnitte lassen ihren Platz frei, ganz leere Zeilen fallen weg.
-- Neue Abschnitte (zum Beispiel "Neu") kommen unten dazu. Beim naechsten Oeffnen wird wieder neu geplant.
-- frozen = { cols, n = Zahl der Zeilen, blocks = { [Schluessel] = { line, x, c, width, alone } } }
function ns.FreezePlan(blocks, plan, cols)
    local fr = { cols = cols, n = 0, blocks = {} }
    for i, bl in ipairs(blocks) do
        local p = plan[i]
        if bl.key and p then
            fr.blocks[bl.key] = { line = p.line, x = p.x, c = p.c, width = p.width, alone = p.alone, dy = p.dy or 0 }
        end
        if p and p.line and p.line > fr.n then fr.n = p.line end
    end
    return fr
end

function ns.HoldLayout(blocks, frozen, o)
    local step = SLOT + GAP
    local res, lines, rest = {}, {}, {}
    for i, bl in ipairs(blocks) do
        local f = bl.key and frozen.blocks[bl.key]
        if f then
            local n = bl.folded and 0 or bl.n
            -- in die festgehaltene Breite hinein wachsen (sie kann wegen der Ueberschrift breiter sein)
            local c = f.alone and f.c or math.max(f.c, math.floor((f.width + GAP) / step))
            c = math.max(1, math.min(c, o.cols))
            local rows = n > 0 and math.ceil(n / c) or 0
            local p = { c = c, x = f.x, width = f.width, alone = f.alone, line = f.line, order = f.dy or 0,
                        height = (bl.titled and HDR_H or 0) + rows * step }
            res[i] = p
            local l = lines[f.line]
            if not l then l = { h = 0 } lines[f.line] = l end
            l[#l + 1] = p
        else
            rest[#rest + 1] = i
        end
    end
    local y, first = 0, true
    for k = 1, frozen.n do
        local l = lines[k]
        if l then
            if not first then y = y + SEC_GAP end
            first = false
            -- gestapelte Abschnitte (gleiches x, ab 0.11) neu untereinander setzen, falls einer gewachsen ist
            table.sort(l, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.order < b.order end)
            local lastX, dy = nil, 0
            for _, p in ipairs(l) do
                if p.x ~= lastX then lastX, dy = p.x, 0 end
                p.y, p.dy, p.order = y + dy, dy, nil
                dy = dy + p.height + SEC_GAP
                l.h = math.max(l.h, dy - SEC_GAP)
            end
            y = y + l.h
        end
    end
    if #rest > 0 then
        local sub = {}
        for k, i in ipairs(rest) do sub[k] = blocks[i] end
        local p2, h2 = ns.PlanLayout(sub, o)
        if not first then y = y + SEC_GAP end
        for k, i in ipairs(rest) do
            p2[k].y = p2[k].y + y
            res[i] = p2[k]
        end
        y = y + h2
    end
    return res, y
end

-- Zeilen neu planen, bei "Spaltenzahl automatisch" mit der Spaltenzahl der kleinsten Flaeche.
-- Rueckgabe: Spalten, Plan, Hoehe
function Window:PlanFresh(blocks, opts)
    local cols = self:Cols()
    opts.cols = cols
    local plan, height = ns.PlanLayout(blocks, opts)
    if self:Setting("AutoCols") then
        local minW = self.minW or MIN_W
        local function Area(c, h) return math.max(minW, PAD * 2 + c * (SLOT + GAP) - GAP) * math.max(h, SLOT) end
        local best = Area(cols, height)
        for c = cols - 1, 6, -1 do
            local o2 = { cols = c, pack = opts.pack, fill = opts.fill, narrow = opts.narrow,
                         balance = opts.balance, stack = opts.stack }
            local p2, h2 = ns.PlanLayout(blocks, o2)
            local a = Area(c, h2)
            if a < best then best, cols, plan, height = a, c, p2, h2 end
        end
    end
    return cols, plan, height
end

-- Abschnitte anordnen. Mit "nebeneinander" (ab 0.6, Einstellung <Fenster>Pack) teilen sich kleine Abschnitte
-- eine Zeile, wenn sie zusammen in die Breite passen. Ein Abschnitt ist dann so breit wie seine Plaetze,
-- mindestens aber wie seine Ueberschrift. Abschnitte ohne Ueberschrift und volle Zeilen stehen allein.
-- Ab 0.7: Luecken fuellen, grosse Abschnitte schmaler, Breite je Abschnitt, Spaltenzahl automatisch
-- (die Spaltenzahl bis zur eingestellten, bei der das Fenster am kleinsten ist), Ablage-Platz leerer Bereiche.
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
    local pack = self:Setting("Pack") ~= false
    local opts = { pack = pack, fill = pack and self:Setting("Fill") and true or false,
                   narrow = pack and self:Setting("Narrow") and true or false,
                   balance = pack and self:Setting("Balance") and true or false }
    opts.stack = opts.balance and self:Setting("Stack") and true or false
    local widths = self:Table("Widths")
    local hi, di = 0, 0
    local shown = {}
    local list = {}

    -- 1. Bloecke: Ueberschrift beschriften, Breite der Ueberschrift messen
    local blocks = {}
    for _, sec in ipairs(sections) do
        local items = sec.items
        if #items == 0 and sec.dropSlot and sec.target ~= nil then
            di = di + 1
            local d = DropSlot(self, di)
            d.target, d.text = sec.target, sec.name or sec.title
            items = { d }
        end
        local n = #items
        if n > 0 or sec.keepEmpty then
            local folded = sec.collapsed and sec.title ~= nil
            local wc = sec.key and widths[sec.key]
            local bl = { sec = sec, items = items, n = n, folded = folded, titled = sec.title ~= nil, key = sec.key,
                         width = ns.Num(wc) and wc or nil, headerW = 0 }
            if sec.title then
                hi = hi + 1
                local h = Header(self, hi)
                -- Zeichen vor dem Namen zeigt, dass sich der Abschnitt einklappen laesst (ab 0.5)
                local label = sec.title
                if sec.key then label = (folded and PLUS or MINUS) .. label end
                if folded then label = label .. " (" .. #sec.items .. ")" end
                h.label:SetText(label)
                h.text, h.target, h.key, h.folded = sec.title, sec.target, sec.key, folded
                h:EnableMouse(sec.target ~= nil or sec.key ~= nil)
                bl.header = h
                bl.headerW = TextWidth(h)
                if sec.key then
                    bl.entry = { key = sec.key, title = sec.name or sec.title }
                    list[#list + 1] = bl.entry
                end
            end
            blocks[#blocks + 1] = bl
        end
    end
    self.lastSections = list

    -- 2. Zeilen planen, bei "Spaltenzahl automatisch" die Spaltenzahl mit der kleinsten Flaeche waehlen
    -- Ab 0.10: Solange das Fenster offen ist, bleibt die Anordnung beim Umraeumen fest (holdLayout).
    local hold = mod.db.holdLayout ~= false
    local frozen = hold and self.frozen
    if frozen and frozen.skey ~= self:SKey() then frozen = nil end
    local cols, plan, height
    if frozen then
        cols = frozen.cols
        opts.cols = cols
        plan, height = ns.HoldLayout(blocks, frozen, opts)
    else
        cols, plan, height = self:PlanFresh(blocks, opts)
        if hold and f:IsShown() then
            self.frozen = ns.FreezePlan(blocks, plan, cols)
            self.frozen.skey = self:SKey()
        else
            self.frozen = nil
        end
    end
    self.usedCols = cols
    for i, bl in ipairs(blocks) do
        if bl.entry then bl.entry.c = plan[i].c end   -- Spalten fuer "Breite je Abschnitt" in Einstellen
    end
    local step = SLOT + GAP
    local full = cols * step - GAP

    -- 3. setzen
    for i, bl in ipairs(blocks) do
        local p = plan[i]
        local top = p.y
        if bl.header then
            local h = bl.header
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", self.content, "TOPLEFT", p.x, -top)
            h:SetWidth(p.width)
            h:Show()
            top = top + HDR_H
        end
        for j, b in ipairs(bl.folded and {} or bl.items) do
            local row, col = math.floor((j - 1) / p.c), (j - 1) % p.c
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.content, "TOPLEFT", p.x + col * step, -(top + row * step))
            b:Show()
            shown[b] = true
        end
    end

    for i = hi + 1, #self.headers do self.headers[i]:Hide() end
    for _, d in ipairs(self.dropSlots or {}) do
        if not shown[d] then d:Hide() end
    end
    for _, b in ipairs(allButtons or {}) do
        if not shown[b] then b:Hide() end
    end
    local width = math.max(self.minW or MIN_W, PAD * 2 + full)
    local frameH = self.topH + math.max(height, SLOT) + FOOT_H + 6
    self.content:SetSize(full, math.max(1, height))
    if not ns.Locked(f) then f:SetSize(width, frameH) end
    if self.OnLayout then self:OnLayout(width) end
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
