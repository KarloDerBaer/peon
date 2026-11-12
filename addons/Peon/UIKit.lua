-- Peon - UIKit.lua
-- Ab 0.18.0: Bausteine fuer einheitliche Peon-Fenster im Look von Blizzards Auktionshaus (WoW Forever).
-- Alle Masse, Grafiken und Schriften sind mit /peon ui pruefen im Spiel gemessen (11.11.2026), nicht geraten.
-- Kern-API 18 (freigegeben von KarloDerBaer, 11.11.2026): Module nutzen Peon.UI, intern heisst die Tabelle ns.UI.
-- Wie die ganze Kern-API wird Peon.UI nur erweitert, nie geaendert.
-- Regeln und Begruendungen: docs/konzepte/Peon_UI_Design.md
-- Nur eigene Rahmen. Blizzards Vorlagen und Grafiken werden genutzt, Blizzards Fenster und Tabellen nicht veraendert.

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local L = ns.L

local UI = {}
ns.UI = UI
Peon.UI = UI   -- API 18

---------------------------------------------------------------------------
-- Gemessene Werte
---------------------------------------------------------------------------
UI.WINDOW_W, UI.WINDOW_H = 800, 538   -- Auktionshaus
UI.TOP = 69          -- Oberkante der Bereiche unter Titel und Suchleiste
UI.BOTTOM = 29       -- Unterkante der Bereiche ueber der Statuszeile
UI.EDGE = 4          -- Abstand der Bereiche zum Fensterrand
UI.GAP = 1           -- Abstand zwischen zwei Bereichen (Verkaufen: links und rechts)
UI.LEFT_W = 363      -- linker Bereich wie das Verkaufsfenster
UI.CAT_W = 168       -- Kategorieliste
UI.ROW_H = 20        -- Zeile einer Liste
UI.HEADER_H = 19     -- Spaltenkopf
UI.NAV_H = 21        -- Knopf der Kategorieliste
UI.LABEL_W = 93      -- Beschriftung im Formular (rechtsbuendig)
UI.LABEL_GAP = 18    -- Abstand Beschriftung zum Feld
UI.FORM_STEP = 27    -- Zeilenabstand im Formular (Dauer, Einzahlen ...)
UI.INPUT_H = 33      -- Eingabefeld des Auktionshauses

-- Hintergruende der Bereiche: Atlas in Originalgroesse, nur oben links verankert (wie Blizzard, nie strecken)
UI.BG = {
    left       = { "auctionhouse-background-sell-left", 357, 437 },
    right      = { "auctionhouse-background-sell-right", 399, 418 },
    list       = { "auctionhouse-background-index", 595, 413 },
    categories = { "auctionhouse-background-categories", 138, 433 },
    summary    = { "auctionhouse-background-summarylist", 138, 433 },
    header     = { "auctionhouse-background-buy-noncommodities-header", 617, 81 },
    market     = { "auctionhouse-background-buy-noncommodities-market", 595, 277 },
    auctions   = { "auctionhouse-background-auctions", 595, 314 },
}

-- Schriften nach Rolle (alle im Spiel gemessen, Datei/Groesse in Peon_UI_Design.md)
UI.FONT = {
    title   = "GameFontNormal",          -- Fenstertitel (12, gold)
    big     = "GameFontNormalLarge",     -- grosse Ueberschrift (16, gold)
    heading = "GameFontNormalMed2",      -- Ueberschrift eines Bereichs (14, gold)
    label   = "GameFontNormal",          -- Beschriftung im Formular, Knopf (12, gold)
    text    = "GameFontHighlight",       -- normaler Text (12, weiss)
    small   = "GameFontHighlightSmall",  -- kleiner Text, Spaltenkopf (10, weiss)
    nav     = "GameFontNormalSmall",     -- Reiter, Kategorie (10, gold)
    sub     = "GameFontDisableSmall",    -- Zusatz unter einer Beschriftung (10, grau)
    off     = "GameFontDisable",         -- gesperrt (12, grau)
    number  = "Number14FontWhite",       -- Zahlen und Namen in Listen (Arial 14)
    price   = "PriceFont",               -- Geldbetraege (Arial 14)
    hint    = "GameFontNormal",          -- Hinweis in leerer Liste (12, gold, mittig)
    warn    = "GameFontRed",             -- Warnung (12, rot)
    good    = "GameFontGreen",           -- Erfolg (12, gruen)
    huge    = "GameFontNormalHuge",      -- Ladeanzeige (20, gold)
}

UI.QUALITY = {   -- Rueckfall, falls C_Item.GetItemQualityColor fehlt
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 }, [6] = { 0.9, 0.8, 0.5 }, [7] = { 0, 0.8, 1 },
}

---------------------------------------------------------------------------
-- Hilfen
---------------------------------------------------------------------------
function UI.TryFrame(kind, name, parent, template)
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then return f end
    return nil
end

function UI.HasAtlas(name)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil
end

-- Atlas setzen, useSize = Originalgroesse. Rueckgabe false, wenn es den Atlas nicht gibt.
function UI.SetAtlas(tex, atlas, useSize)
    if not (tex and tex.SetAtlas) or not UI.HasAtlas(atlas) then return false end
    return (pcall(tex.SetAtlas, tex, atlas, useSize and true or false))
end

function UI.Font(region, role)
    local name = UI.FONT[role] or role
    local fo = rawget(_G, name)
    if region.SetFontObject and type(fo) == "table" then region:SetFontObject(fo) end
end

function UI.QualityColor(q)
    if C_Item and C_Item.GetItemQualityColor and type(q) == "number" then
        local ok, r, g, b = pcall(C_Item.GetItemQualityColor, q)
        if ok and type(r) == "number" then return r, g, b end
    end
    local c = UI.QUALITY[q or 1] or UI.QUALITY[1]
    return c[1], c[2], c[3]
end

local function Tooltip(owner, lines)
    if not (GameTooltip and lines) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for i, l in ipairs(type(lines) == "function" and lines() or lines) do
        if i == 1 then GameTooltip:SetText(l, 1, 0.82, 0) else GameTooltip:AddLine(l, 1, 1, 1, true) end
    end
    GameTooltip:Show()
end
UI.Tooltip = Tooltip

-- Tooltip an jeden Rahmen haengen (lines = Liste oder Funktion)
function UI.SetTooltip(f, lines)
    f:HookScript("OnEnter", function(self) Tooltip(self, lines) end)
    f:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

---------------------------------------------------------------------------
-- Fenster mit rundem Bild, Titel, Schliessen (PortraitFrameTemplate wie das Auktionshaus)
---------------------------------------------------------------------------
function UI.Window(name, o)
    o = o or {}
    local f = UI.TryFrame("Frame", name, UIParent, "PortraitFrameTemplate")
        or UI.TryFrame("Frame", name, UIParent, "BasicFrameTemplate")
        or CreateFrame("Frame", name, UIParent)
    f:SetSize(o.width or UI.WINDOW_W, o.height or UI.WINDOW_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetTitle then pcall(f.SetTitle, f, o.title or "") end
    if o.icon then
        if type(f.SetPortraitToAsset) == "function" then pcall(f.SetPortraitToAsset, f, o.icon)
        elseif type(f.SetPortraitTextureRaw) == "function" then pcall(f.SetPortraitTextureRaw, f, o.icon) end
    end
    -- ESC schliesst: eigener Name in Blizzards Liste UISpecialFrames (nur ein Eintrag, so vorgesehen)
    if name and type(UISpecialFrames) == "table" then
        local known = false
        for _, n in ipairs(UISpecialFrames) do if n == name then known = true end end
        if not known then table.insert(UISpecialFrames, name) end
    end
    f:Hide()
    return f
end

---------------------------------------------------------------------------
-- Reiter unten (PanelTabButtonTemplate, Abstand wie im Auktionshaus) mit Zahl am Reiter
---------------------------------------------------------------------------
function UI.Badge(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(16, 16)
    b:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
    local ring = b:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetAllPoints()
    ring:SetColorTexture(0.15, 0.02, 0.02, 1)
    local dot = b:CreateTexture(nil, "ARTWORK", nil, 2)
    dot:SetPoint("TOPLEFT", 1, -1)
    dot:SetPoint("BOTTOMRIGHT", -1, 1)
    dot:SetColorTexture(0.8, 0.1, 0.05, 1)
    -- rund ueber Blizzards Kreismaske (Datei 130924, gemessen am runden Bild des Auktionshauses)
    if b.CreateMaskTexture then
        for _, t in ipairs({ ring, dot }) do
            local m = b:CreateMaskTexture()
            m:SetAllPoints(t)
            pcall(m.SetTexture, m, 130924, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            if t.AddMaskTexture then t:AddMaskTexture(m) end
        end
    end
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER", 0, 0)
    function b:SetCount(n)
        if not n or n == 0 then self:Hide(); return end
        self.text:SetText(n > 99 and "99+" or tostring(n))
        local w = math.max(16, (self.text:GetStringWidth() or 8) + 8)
        self:SetWidth(w)
        self:Show()
    end
    b:Hide()
    return b
end

-- Reiter wie im Auktionshaus: Breite = Text + 40 (gemessen: "Markt" 31 Text, 71 Reiter), Abstand UI.TAB_GAP.
-- Die Zahl am Reiter steht rechts neben dem Text im Reiter (oben waere sie unter dem Fensterrahmen verdeckt),
-- der Reiter wird dafuer breiter, Text und Zahl bleiben zusammen mittig.
UI.TAB_PAD = 40
UI.TAB_GAP = 3

local function TabText(t)
    return t.Text or (t.GetFontString and t:GetFontString())
end

local function FitTab(t)
    local fs = TabText(t)
    if not fs then return end
    if fs.SetWidth then fs:SetWidth(0) end
    local tw = fs:GetStringWidth() or 0
    if fs.SetWidth then fs:SetWidth(tw) end
    local bw = (t.badge and t.badge:IsShown()) and ((t.badge:GetWidth() or 16) + 4) or 0
    t:SetWidth(tw + UI.TAB_PAD + bw)
    -- Blizzard verschiebt den Text beim Waehlen senkrecht (SelectTab/DeselectTab), nur waagerecht nachziehen
    local p, rel, rp, _, y = fs:GetPoint(1)
    if p then
        fs:ClearAllPoints()
        fs:SetPoint(p, rel, rp, -bw / 2, y or 0)
    end
end
UI.FitTab = FitTab

local function MakeTabs(parent, defs, onSelect, template)
    local tabs = {}
    local function Select(key)
        for _, t in ipairs(tabs) do
            if t.key == key and PanelTemplates_SelectTab then pcall(PanelTemplates_SelectTab, t)
            elseif t.key ~= key and PanelTemplates_DeselectTab then pcall(PanelTemplates_DeselectTab, t) end
            FitTab(t)
        end
        tabs.selected = key
        if onSelect then onSelect(key) end
    end
    for i, d in ipairs(defs) do
        local t = UI.TryFrame("Button", nil, parent, template) or CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        t.key = d[1]
        t:SetText(d[2])
        if i > 1 then t:SetPoint("LEFT", tabs[i - 1], "RIGHT", UI.TAB_GAP, 0) end
        t:SetScript("OnClick", function() Select(d[1]) end)
        t.badge = UI.Badge(t)
        local fs = TabText(t)
        if fs then t.badge:SetPoint("LEFT", fs, "RIGHT", 4, 0) else t.badge:SetPoint("RIGHT", -10, 0) end
        function t:SetBadge(n) self.badge:SetCount(n); FitTab(self) end
        -- Blizzards OnShow rechnet die Breite neu (ohne Zahl): danach die eigene Breite setzen
        t:HookScript("OnShow", FitTab)
        FitTab(t)
        tabs[i] = t
    end
    tabs.Select = function(_, key) Select(key) end
    return tabs
end

-- Reiter unten (PanelTabButtonTemplate) mit Zahl am Reiter. defs = { { key, text }, ... }, tabs:Select(key)
function UI.BottomTabs(win, defs, onSelect)
    local tabs = MakeTabs(win, defs, onSelect, "PanelTabButtonTemplate")
    if tabs[1] then tabs[1]:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 20, -28) end
    return tabs
end

-- Reiter oben (PanelTopTabButtonTemplate), z. B. ueber einem Bereich. Den ersten Reiter verankert der Aufrufer.
function UI.TopTabs(parent, defs, onSelect)
    return MakeTabs(parent, defs, onSelect, "PanelTopTabButtonTemplate")
end

-- Beschriftung ueber einem Bereich wie "Auktion erstellen" (selltab-Grafiken), unten am Bereich verankert
function UI.SectionTab(panel, text)
    local l = panel:CreateTexture(nil, "ARTWORK")
    UI.SetAtlas(l, "auctionhouse-selltab-left", true)
    l:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 42, -3)
    local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetPoint("LEFT", l, "RIGHT", 12, 0)
    fs:SetText(text or "")
    local m = panel:CreateTexture(nil, "BORDER")
    UI.SetAtlas(m, "auctionhouse-selltab-middle", true)
    m:SetPoint("TOPLEFT", l, "TOPRIGHT", 0, 0)
    m:SetPoint("RIGHT", fs, "RIGHT", 12, 0)
    local r = panel:CreateTexture(nil, "BORDER")
    UI.SetAtlas(r, "auctionhouse-selltab-right", true)
    r:SetPoint("TOPLEFT", m, "TOPRIGHT", 0, 0)
    r:SetPoint("BOTTOMLEFT", m, "BOTTOMRIGHT", 0, 0)
    return fs
end

---------------------------------------------------------------------------
-- Bereich mit Rahmen und Hintergrund (InsetFrameTemplate-Rahmen, Hintergrund des Auktionshauses)
-- bg = Schluessel aus UI.BG. header = true laesst oben 19 Punkte fuer Spaltenkoepfe frei (wie Blizzards Listen).
---------------------------------------------------------------------------
function UI.Panel(parent, bg, header)
    local f = UI.TryFrame("Frame", nil, parent, "InsetFrameTemplate") or CreateFrame("Frame", nil, parent)
    -- Blizzards Bereiche im Auktionshaus haben keinen eigenen Grund: das Fenster scheint durch
    if type(f.Bg) == "table" and f.Bg.Hide then f.Bg:Hide() end
    local def = UI.BG[bg or "left"] or UI.BG.left
    local tex = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    local top = header and 22 or 3
    local right = header and 25 or 3
    tex:SetPoint("TOPLEFT", 3, -top)
    f.Background = tex
    local info
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, i = pcall(C_Texture.GetAtlasInfo, def[1])
        if ok and type(i) == "table" and i.file then info = i end
    end
    -- Hintergrund passend zum Bereich: Ist der Bereich kleiner als das Bild, wird es abgeschnitten (nie ueber den
    -- Rand hinaus). Ist er groesser, wird es gedehnt (sonst endet das Grau mitten im Bereich). Blizzard zeigt
    -- Originalgroesse, weil seine Bereiche etwa so gross sind wie die Bilder.
    local function Fit()
        -- f.bgRight: Abstand rechts, z. B. 27 neben einer Bildlaufleiste (dort scheint wie bei Blizzard das Fenster durch)
        local w = (f:GetWidth() or 0) - 3 - (f.bgRight or right)
        local h = (f:GetHeight() or 0) - top - 3
        if w <= 0 or h <= 0 then return end
        tex:SetSize(w, h)
        if not info then return end
        local cw = math.min(1, w / def[2])
        local ch = math.min(1, h / def[3])
        local l, r, t, b = info.leftTexCoord or 0, info.rightTexCoord or 1, info.topTexCoord or 0, info.bottomTexCoord or 1
        tex:SetTexCoord(l, l + (r - l) * cw, t, t + (b - t) * ch)
    end
    if info and pcall(tex.SetTexture, tex, info.file) then
        Fit()
    else
        tex:SetColorTexture(0.1, 0.1, 0.1, 1)
    end
    f:HookScript("OnSizeChanged", Fit)
    f.FitBackground = Fit
    -- Liste wie im Auktionshaus: Rahmen unter den Spaltenkoepfen, Bildlaufleiste rechts ausserhalb des Rahmens
    if header and type(f.NineSlice) == "table" then
        f.NineSlice:ClearAllPoints()
        f.NineSlice:SetPoint("TOPLEFT", 0, -UI.HEADER_H)
        f.NineSlice:SetPoint("BOTTOMRIGHT", -22, 0)
    end
    return f
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------
function UI.Text(parent, role, text, width)
    local fs = parent:CreateFontString(nil, "ARTWORK", UI.FONT[role] or role or UI.FONT.text)
    fs:SetJustifyH((role == "hint") and "CENTER" or "LEFT")
    if fs.SetJustifyV then fs:SetJustifyV("TOP") end
    if width then fs:SetWidth(width); if fs.SetWordWrap then fs:SetWordWrap(true) end end
    fs:SetText(text or "")
    return fs
end

-- Trennlinie (Blizzards Linie der Einstellungen)
function UI.Divider(parent, width)
    local t = parent:CreateTexture(nil, "ARTWORK")
    if not UI.SetAtlas(t, "Options_HorizontalDivider", false) then t:SetColorTexture(1, 1, 1, 0.15) end
    t:SetSize(width or 300, 1)
    return t
end

---------------------------------------------------------------------------
-- Knoepfe
---------------------------------------------------------------------------
-- kind: nil = normal (rot, 22 hoch), "gold" = hervorgehoben (UIPanelGoldButtonTemplate, 32 hoch)
function UI.Button(parent, text, width, fn, kind)
    local tmpl = (kind == "gold") and "UIPanelGoldButtonTemplate" or "UIPanelButtonTemplate"
    local b = UI.TryFrame("Button", nil, parent, tmpl) or CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 120, (kind == "gold") and 32 or 22)
    b:SetText(text or "")
    if fn then b:SetScript("OnClick", fn) end
    return b
end

-- quadratischer Knopf mit Symbol (Favoriten im Auktionshaus): atlas oder Datei
function UI.IconButton(parent, icon, fn, tip)
    local b = UI.TryFrame("Button", nil, parent, "SquareIconButtonTemplate") or CreateFrame("Button", nil, parent)
    b:SetSize(32, 32)
    local t = b.Icon or b:CreateTexture(nil, "OVERLAY")
    if not UI.SetAtlas(t, icon, false) then pcall(t.SetTexture, t, icon) end
    t:SetSize(16, 16)
    if fn then b:SetScript("OnClick", fn) end
    if tip then UI.SetTooltip(b, tip) end
    return b
end

function UI.RefreshButton(parent, fn, tip)
    local b = UI.TryFrame("Button", nil, parent, "RefreshButtonTemplate") or CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(32, 32)
    if fn then b:SetScript("OnClick", fn) end
    if tip then UI.SetTooltip(b, tip) end
    return b
end

---------------------------------------------------------------------------
-- Eingaben
---------------------------------------------------------------------------
-- Eingabefeld des Auktionshauses (LargeInputBoxTemplate, 33 hoch). o.numeric, o.instructions
function UI.Input(parent, width, o)
    o = o or {}
    local e = UI.TryFrame("EditBox", nil, parent, "LargeInputBoxTemplate") or CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width or 134, UI.INPUT_H)
    e:SetAutoFocus(false)
    if o.numeric and e.SetNumeric then e:SetNumeric(true) end
    if o.maxLetters and e.SetMaxLetters then e:SetMaxLetters(o.maxLetters) end
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    if o.instructions then
        local fs = e:CreateFontString(nil, "ARTWORK", UI.FONT.sub)
        fs:SetPoint("LEFT", 10, 0)
        fs:SetText(o.instructions)
        local function Upd() fs:SetShown((e:GetText() or "") == "") end
        e:HookScript("OnTextChanged", Upd)
        Upd()
    end
    return e
end

-- Suchfeld (SearchBoxTemplate, Lupe, Leeren-Knopf, grauer Hinweis)
function UI.SearchBox(parent, width, onChange)
    local e = UI.TryFrame("EditBox", nil, parent, "SearchBoxTemplate") or CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width or 241, 22)
    e:SetAutoFocus(false)
    if onChange then e:HookScript("OnTextChanged", function(self, user) onChange(self:GetText() or "", user) end) end
    return e
end

-- Geld eingeben wie im Verkaufsfenster: Gold 78, Silber und Kupfer je 50 breit, 6 Abstand, Muenze rechts im Feld
function UI.MoneyInput(parent, onChange)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(190, UI.INPUT_H)
    local parts = { { "gold", 78, "Coin-Gold" }, { "silver", 50, "Coin-Silver" }, { "copper", 50, "Coin-Copper" } }
    local prev
    for _, p in ipairs(parts) do
        local e = UI.Input(f, p[2], { numeric = true, maxLetters = (p[1] == "gold") and 7 or 2 })
        e:SetTextInsets(10, 24, 0, 0)
        if e.SetJustifyH then e:SetJustifyH("RIGHT") end
        if prev then e:SetPoint("LEFT", prev, "RIGHT", 6, 0) else e:SetPoint("LEFT", 0, 0) end
        local icon = e:CreateTexture(nil, "ARTWORK")
        if not UI.SetAtlas(icon, p[3], false) then icon:SetColorTexture(1, 0.82, 0, 1) end
        icon:SetSize(12, 14)
        icon:SetPoint("RIGHT", -10, 2)
        e:HookScript("OnTextChanged", function(_, user) if user and onChange then onChange(f:GetAmount()) end end)
        f[p[1]] = e
        prev = e
    end
    function f:GetAmount()
        local g = tonumber(self.gold:GetText()) or 0
        local s = tonumber(self.silver:GetText()) or 0
        local c = tonumber(self.copper:GetText()) or 0
        return g * 10000 + s * 100 + c
    end
    function f:SetAmount(copper)
        copper = math.max(0, math.floor(tonumber(copper) or 0))
        local g = math.floor(copper / 10000)
        self.gold:SetText(g > 0 and ("%.0f"):format(g) or "")
        self.silver:SetText(tostring(math.floor(copper / 100) % 100))
        self.copper:SetText(tostring(copper % 100))
    end
    return f
end

-- Geld anzeigen wie im Auktionshaus: Arial 14 (PriceFont), Muenze 12x14, je Stelle 36 Abstand
function UI.Money(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(128, 13)
    local parts = { { "copper", "Coin-Copper" }, { "silver", "Coin-Silver" }, { "gold", "Coin-Gold" } }
    f.parts = {}
    for i, p in ipairs(parts) do
        local d = CreateFrame("Frame", nil, f)
        d:SetSize(28, 13)
        d.icon = d:CreateTexture(nil, "ARTWORK")
        if not UI.SetAtlas(d.icon, p[2], false) then d.icon:SetColorTexture(1, 0.82, 0, 1) end
        d.icon:SetSize(12, 14)
        d.icon:SetPoint("RIGHT", 0, 0)
        d.text = d:CreateFontString(nil, "ARTWORK", UI.FONT.price)
        d.text:SetJustifyH("RIGHT")
        d.text:SetPoint("RIGHT", -14, 0)
        f[p[1]] = d
        f.parts[i] = d
    end
    function f:SetAmount(copper, gray)
        copper = math.max(0, math.floor(tonumber(copper) or 0))
        local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
        local vals = { c, s, g }
        local x = 0
        local first = true
        for i = 1, 3 do
            local d = self.parts[i]
            local show = vals[i] > 0 or (i == 1 and copper == 0)
            -- Blizzard zeigt Kupfer und Silber auch als 0, sobald ein groesserer Wert da ist
            if i < 3 and copper >= 100 then show = true end
            d:SetShown(show)
            if show then
                d.text:SetText(("%.0f"):format(vals[i]))
                d.text:SetTextColor(gray and 0.5 or 1, gray and 0.5 or 1, gray and 0.5 or 1)
                d:ClearAllPoints()
                d:SetPoint("RIGHT", self, "RIGHT", -x, 0)
                local w = (d.text:GetStringWidth() or 7) + 14
                d:SetWidth(w)
                x = x + w + (first and 8 or 8)
                first = false
            end
        end
        self:SetWidth(math.max(20, x))
    end
    f:SetAmount(0)
    return f
end

-- Auswahlliste (WowStyle1DropdownTemplate). items = { { wert, text }, ... }, get() / set(wert)
function UI.Dropdown(parent, width, items, get, set)
    local dd = UI.TryFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    if not (dd and dd.SetupMenu) then
        local b = UI.Button(parent, "", width or 120)
        b.fallback = true
        return b
    end
    dd:SetWidth(width or 120)
    dd:SetupMenu(function(_, root)
        for _, o in ipairs(type(items) == "function" and items() or items) do
            root:CreateRadio(o[2], function() return get() == o[1] end, function() set(o[1]) end)
        end
    end)
    return dd
end

-- Filter-Knopf mit Menue (WowStyle1FilterDropdownTemplate). build(root) fuellt das Menue.
function UI.FilterDropdown(parent, text, build)
    local dd = UI.TryFrame("DropdownButton", nil, parent, "WowStyle1FilterDropdownTemplate")
    if not (dd and dd.SetupMenu) then return UI.Button(parent, text or "", 90) end
    if text and dd.Text then dd.Text:SetText(text) end
    dd:SetupMenu(function(_, root) build(root) end)
    return dd
end

-- Haken mit gelbem Haekchen (UICheckButtonTemplate wie "Sofortkaufmodus", Schrift GameFontNormal)
function UI.Check(parent, text, checked, fn, tip)
    local cb = UI.TryFrame("CheckButton", nil, parent, "UICheckButtonTemplate") or CreateFrame("CheckButton", nil, parent)
    cb:SetSize(32, 32)
    local fs = cb.Text or cb:CreateFontString(nil, "ARTWORK")
    UI.Font(fs, "label")
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", cb, "RIGHT", -2, 0)
    fs:SetText(text or "")
    cb.label = fs
    cb:SetChecked(checked and true or false)
    if fn then cb:SetScript("OnClick", function(self) fn(self:GetChecked() and true or false) end) end
    if tip then UI.SetTooltip(cb, tip) end
    -- gesperrt: Text grau wie Blizzards GameFontDisable
    hooksecurefunc(cb, "Disable", function() fs:SetTextColor(0.5, 0.5, 0.5) end)
    hooksecurefunc(cb, "Enable", function() fs:SetTextColor(1, 0.82, 0) end)
    return cb
end

-- Schieberegler. style "minimal" (MinimalSliderWithSteppersTemplate wie Blizzards Einstellungen)
-- oder "classic" (UISliderTemplateWithLabels, frueher OptionsSliderTemplate). fn(wert) bei Aenderung.
function UI.Slider(parent, width, minV, maxV, step, value, fn, style, format)
    format = format or function(v) return tostring(v) end
    if style ~= "classic" then
        local f = UI.TryFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
        if f and f.Init then
            f:SetWidth(width or 250)
            local steps = math.floor((maxV - minV) / step + 0.5)
            local mix = rawget(_G, "MinimalSliderWithSteppersMixin")
            local right = mix and mix.Label and mix.Label.Right
            pcall(f.Init, f, value, minV, maxV, steps, right and { [right] = format } or nil)
            if f.RegisterCallback and mix and mix.Event then
                f:RegisterCallback(mix.Event.OnValueChanged, function(_, v) if fn then fn(v) end end, f)
            end
            return f
        end
    end
    -- OptionsSliderTemplate ist bei Blizzard veraltet und erbt nur noch von UISliderTemplateWithLabels
    local s = UI.TryFrame("Slider", nil, parent, "UISliderTemplateWithLabels")
        or UI.TryFrame("Slider", nil, parent, "OptionsSliderTemplate") or CreateFrame("Slider", nil, parent)
    s:SetSize(width or 144, 17)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:SetValue(value)
    if s.Low then s.Low:SetText(format(minV)) end
    if s.High then s.High:SetText(format(maxV)) end
    if s.Text then s.Text:SetText(format(value)) end
    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        if self.Text then self.Text:SetText(format(v)) end
        if fn then fn(v) end
    end)
    return s
end

-- Formularzeile wie im Verkaufsfenster: Beschriftung rechtsbuendig (93 breit), 18 Abstand, dann das Feld.
-- sub = grauer Zusatz unter der Beschriftung ("pro Gegenstand")
function UI.FormRow(parent, label, control, x, y, sub)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(UI.LABEL_W, 30)
    row:SetPoint("TOPLEFT", x, y)
    local fs = row:CreateFontString(nil, "ARTWORK", UI.FONT.label)
    fs:SetJustifyH("RIGHT")
    fs:SetWidth(UI.LABEL_W)
    fs:SetText(label)
    if sub then
        fs:SetPoint("LEFT", 0, 7)
        local s = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        s:SetTextColor(0.5, 0.5, 0.5)
        s:SetJustifyH("RIGHT")
        s:SetWidth(UI.LABEL_W + 30)
        s:SetPoint("TOPRIGHT", fs, "BOTTOMRIGHT", 0, -1)
        s:SetText(sub)
        row.sub = s
    else
        fs:SetPoint("LEFT", 0, 0)
    end
    row.label = fs
    if control then
        control:ClearAllPoints()
        control:SetPoint("LEFT", fs, "RIGHT", UI.LABEL_GAP, -2)
    end
    return row
end

---------------------------------------------------------------------------
-- Gegenstand
---------------------------------------------------------------------------
-- kleines Symbol wie in Blizzards Listen: 14x14, Rahmen 16x16 in Qualitaetsfarbe
function UI.ItemIcon(parent, icon, quality, size)
    size = size or 14
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size + 2, size + 2)
    f.icon = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.icon:SetSize(size, size)
    f.icon:SetPoint("CENTER")
    f.border = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    f.border:SetAllPoints()
    if not UI.SetAtlas(f.border, "auctionhouse-itemicon-small-border", false) then f.border:Hide() end
    function f:Set(ic, q)
        pcall(self.icon.SetTexture, self.icon, ic or 134400)
        self.border:SetVertexColor(UI.QualityColor(q or 1))
    end
    f:Set(icon, quality)
    return f
end

-- Kopf mit grossem Symbol und Namen wie im Verkaufsfenster (342x72)
function UI.ItemHeader(parent, icon, name, quality)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(342, 72)
    local frame = f:CreateTexture(nil, "ARTWORK")
    if not UI.SetAtlas(frame, "auctionhouse-itemheaderframe", false) then frame:SetColorTexture(0, 0, 0, 0.3) end
    frame:SetSize(342, 72)
    frame:SetPoint("CENTER")
    local empty = f:CreateTexture(nil, "BACKGROUND")
    UI.SetAtlas(empty, "auctionhouse-itemicon-empty", false)
    empty:SetSize(54, 54)
    empty:SetPoint("LEFT", 10, 0)
    f.icon = f:CreateTexture(nil, "BORDER")
    f.icon:SetSize(50, 50)
    f.icon:SetPoint("TOPLEFT", empty, "TOPLEFT", 2, -2)
    f.iconBorder = f:CreateTexture(nil, "OVERLAY")
    f.iconBorder:SetAllPoints(f.icon)
    if not UI.SetAtlas(f.iconBorder, "auctionhouse-itemicon-border-white", false) then f.iconBorder:Hide() end
    f.name = f:CreateFontString(nil, "ARTWORK", "SystemFont_Shadow_Large")
    f.name:SetJustifyH("LEFT")
    f.name:SetPoint("LEFT", empty, "RIGHT", 12, 0)
    f.name:SetPoint("RIGHT", -12, 0)
    function f:Set(ic, n, q)
        pcall(self.icon.SetTexture, self.icon, ic)
        self.icon:SetShown(ic ~= nil)
        self.iconBorder:SetShown(ic ~= nil)
        self.iconBorder:SetVertexColor(UI.QualityColor(q or 1))
        self.name:SetText(n or "")
        self.name:SetTextColor(UI.QualityColor(q or 1))
    end
    f:Set(icon, name, quality)
    return f
end

---------------------------------------------------------------------------
-- Ladeanzeige (SpinnerTemplate wie "Suche..." im Auktionshaus)
---------------------------------------------------------------------------
function UI.Spinner(parent, text, size)
    local f = UI.TryFrame("Frame", nil, parent, "SpinnerTemplate") or CreateFrame("Frame", nil, parent)
    f:SetSize(size or 90, size or 90)
    f.text = f:CreateFontString(nil, "ARTWORK", UI.FONT.huge)
    f.text:SetPoint("BOTTOM", f, "TOP", 0, 10)
    f.text:SetText(text or "")
    return f
end

---------------------------------------------------------------------------
-- Liste mit Bildlauf (Blizzards ScrollBox mit MinimalScrollBar, wie im Auktionshaus)
-- o.extent = Zeilenhoehe, o.init(row, data, index) baut/fuellt eine Zeile, o.onClick(data, button)
---------------------------------------------------------------------------
function UI.ScrollList(parent, o)
    local list = { data = {}, o = o }
    local box = UI.TryFrame("Frame", nil, parent, "WowScrollBoxList")
    local bar = UI.TryFrame("EventFrame", nil, parent, "MinimalScrollBar")
    list.box, list.bar = box, bar
    if box and bar and CreateScrollBoxListLinearView and ScrollUtil and CreateDataProvider then
        local view = CreateScrollBoxListLinearView()
        -- Innenabstand links wie Blizzards Kategorieliste (SetPadding(oben, unten, links, rechts, Abstand))
        if o.padLeft and view.SetPadding then view:SetPadding(0, 0, o.padLeft, 0, 0) end
        view:SetElementExtent(o.extent or UI.ROW_H)
        view:SetElementInitializer("Button", function(row, data)
            if not row.peonInit then
                row.peonInit = true
                row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                row:SetScript("OnClick", function(self, button) if o.onClick then o.onClick(self.data, button) end end)
                if o.create then o.create(row) end
            end
            row.data = data
            if o.init then o.init(row, data) end
        end)
        ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
        list.provider = CreateDataProvider()
        box:SetDataProvider(list.provider)
        list.native = true
    else
        -- Rueckfall (z. B. Tests): einfache Zeilen ohne Bildlauf
        box = box or CreateFrame("Frame", nil, parent)
        list.box = box
        list.rows = {}
    end
    function list:SetData(items)
        self.data = items or {}
        if self.native then
            self.provider = CreateDataProvider(self.data)
            self.box:SetDataProvider(self.provider, ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
        else
            for i, data in ipairs(self.data) do
                local row = self.rows[i]
                if not row then
                    row = CreateFrame("Button", nil, self.box)
                    row:SetSize(100, o.extent or UI.ROW_H)
                    row:SetPoint("TOPLEFT", 0, -(i - 1) * (o.extent or UI.ROW_H))
                    row:SetScript("OnClick", function(r, button) if o.onClick then o.onClick(r.data, button) end end)
                    if o.create then o.create(row) end
                    self.rows[i] = row
                end
                row.data = data
                row:Show()
                if o.init then o.init(row, data) end
            end
            for i = #self.data + 1, #self.rows do self.rows[i]:Hide() end
        end
    end
    -- Zeilen neu fuellen, ohne die Daten zu tauschen (z. B. nach Auswahl)
    function list:Refresh()
        if self.native then
            if self.box.ForEachFrame then
                self.box:ForEachFrame(function(row) if o.init then o.init(row, row.data) end end)
            end
        else
            for _, row in ipairs(self.rows) do if row:IsShown() and o.init then o.init(row, row.data) end end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Tabelle wie Blizzards Listen: Spaltenkoepfe mit Sortierpfeil, Streifen, Hervorheben, Auswahl,
-- Bildlauf, Hinweis bei leerer Liste, Ladeanzeige.
-- o.columns = { { key, title, width (nil = waechst), align, format(v, item), sort(item) } }
-- o.panel = Bereich (UI.Panel mit header = true), o.empty = Text bei leerer Liste
---------------------------------------------------------------------------
function UI.Table(panel, o)
    local t = { o = o, items = {}, sortKey = o.sortKey, sortDesc = o.sortDesc, selected = nil }
    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", 4, -1)
    header:SetPoint("TOPRIGHT", -26, -1)
    header:SetHeight(UI.HEADER_H)
    t.header = header
    t.heads = {}

    local function Cmp(a, b)
        local col
        for _, c in ipairs(o.columns) do if c.key == t.sortKey then col = c end end
        local function V(item)
            if col and col.sort then return col.sort(item) end
            return item[t.sortKey]
        end
        local va, vb = V(a), V(b)
        if va == nil and vb == nil then return false end
        if va == nil then return false end      -- leere Werte immer unten
        if vb == nil then return true end
        if type(va) == "string" then va, vb = va:lower(), tostring(vb):lower() end
        if va == vb then return false end
        if t.sortDesc then return va > vb end
        return va < vb
    end

    local function Layout()
        local fixed, flex = 0, nil
        for _, c in ipairs(o.columns) do if c.width then fixed = fixed + c.width - 2 else flex = c end end
        local total = (header:GetWidth() or 0)
        if flex then flex.cur = math.max(60, total - fixed + 2) end
        for _, c in ipairs(o.columns) do c.cur = c.width or c.cur or 100 end
        for i, h in ipairs(t.heads) do
            h:SetWidth(o.columns[i].cur)
            h.arrow:SetShown(o.columns[i].key == t.sortKey)
            if h.arrow:IsShown() then
                -- wie Blizzard (AuctionHouseTableHeaderStringMixin): aufsteigend gedreht, der Pfeil zeigt nach oben
                if t.sortDesc then h.arrow:SetTexCoord(0, 1, 0, 1) else h.arrow:SetTexCoord(0, 1, 1, 0) end
            end
        end
    end
    t.Layout = Layout

    for i, c in ipairs(o.columns) do
        local h = UI.TryFrame("Button", nil, header, "ColumnDisplayButtonShortTemplate") or CreateFrame("Button", nil, header)
        h:SetHeight(UI.HEADER_H)
        if i == 1 then h:SetPoint("TOPLEFT", 0, 0) else h:SetPoint("TOPLEFT", t.heads[i - 1], "TOPRIGHT", -2, 0) end
        h:SetText(c.title or "")
        local fs = h.GetFontString and h:GetFontString()
        h.arrow = h:CreateTexture(nil, "OVERLAY")
        if not UI.SetAtlas(h.arrow, "auctionhouse-ui-sortarrow", true) then h.arrow:SetColorTexture(1, 0.82, 0, 1); h.arrow:SetSize(7, 7) end
        if fs then h.arrow:SetPoint("LEFT", fs, "RIGHT", 3, 0) else h.arrow:SetPoint("RIGHT", -6, 0) end
        if c.nosort then
            h:Disable()
        else
            h:SetScript("OnClick", function()
                if t.sortKey == c.key then t.sortDesc = not t.sortDesc else t.sortKey, t.sortDesc = c.key, false end
                t:Sort()
            end)
        end
        t.heads[i] = h
    end
    header:SetScript("OnSizeChanged", function() Layout(); t.list:Refresh() end)

    local list
    list = UI.ScrollList(panel, {
        extent = UI.ROW_H,
        create = function(row)
            row.stripe = row:CreateTexture(nil, "BACKGROUND")
            row.stripe:SetAllPoints()
            -- API 19: eigene Hintergrundfarbe je Zeile (o.rowBg)
            row.tint = row:CreateTexture(nil, "BACKGROUND", nil, 1)
            row.tint:SetAllPoints()
            row.tint:Hide()
            row.hl = row:CreateTexture(nil, "OVERLAY")
            row.hl:SetAllPoints()
            if not UI.SetAtlas(row.hl, "auctionhouse-ui-row-highlight", false) then row.hl:SetColorTexture(1, 1, 1, 0.08) end
            row.hl:SetBlendMode("ADD")
            row.hl:Hide()
            row.sel = row:CreateTexture(nil, "OVERLAY")
            row.sel:SetAllPoints()
            if not UI.SetAtlas(row.sel, "auctionhouse-ui-row-select", false) then row.sel:SetColorTexture(1, 0.82, 0, 0.2) end
            row.sel:SetBlendMode("ADD")
            row.sel:Hide()
            row.cells = {}
            for ci, c in ipairs(o.columns) do
                local fs = row:CreateFontString(nil, "ARTWORK", c.font or UI.FONT.number)
                fs:SetJustifyH(c.align or "LEFT")
                if fs.SetWordWrap then fs:SetWordWrap(false) end
                row.cells[ci] = fs
            end
            if o.icon then row.icon = UI.ItemIcon(row) end
            row:SetScript("OnEnter", function(self)
                self.hl:Show()
                if o.onEnter then o.onEnter(self, self.data) end
            end)
            row:SetScript("OnLeave", function(self)
                self.hl:Hide()
                if GameTooltip then GameTooltip:Hide() end
            end)
        end,
        init = function(row, item)
            if not item then return end
            local idx = item.__index or 1
            if not UI.SetAtlas(row.stripe, (idx % 2 == 1) and "auctionhouse-rowstripe-1" or "auctionhouse-rowstripe-2", false) then
                row.stripe:SetColorTexture(1, 1, 1, (idx % 2 == 1) and 0.03 or 0)
            end
            row.sel:SetShown(t.selected == item)
            -- API 19: o.rowBg(item) -> r, g, b, a (nil = keine eigene Farbe)
            local tr, tg, tb, ta
            if o.rowBg then tr, tg, tb, ta = o.rowBg(item) end
            if tr then row.tint:SetColorTexture(tr, tg, tb, ta or 0.25); row.tint:Show() else row.tint:Hide() end
            local x = 0
            for ci, c in ipairs(o.columns) do
                local fs = row.cells[ci]
                local w = c.cur or c.width or 100
                local pad = 4
                if ci == 1 and row.icon then
                    row.icon:ClearAllPoints()
                    row.icon:SetPoint("LEFT", row, "LEFT", x + 6, 0)
                    row.icon:Set(item.icon, item.quality)
                    pad = 26
                end
                fs:ClearAllPoints()
                fs:SetPoint("LEFT", row, "LEFT", x + pad, 0)
                fs:SetWidth(math.max(1, w - pad - 6))
                local v = item[c.key]
                local text = c.format and c.format(v, item) or (v ~= nil and tostring(v) or "")
                fs:SetText(text)
                if c.color then fs:SetTextColor(c.color(item)) else fs:SetTextColor(1, 1, 1) end
                x = x + w - 2
            end
        end,
        onClick = function(item, button)
            if not item then return end
            if button == "LeftButton" then
                t.selected = item
                t.list:Refresh()
            end
            if o.onClick then o.onClick(item, button) end
        end,
    })
    t.list = list
    list.box:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    list.box:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    list.box:SetPoint("BOTTOM", panel, "BOTTOM", 0, 3)
    if list.bar then
        list.bar:SetPoint("TOPLEFT", list.box, "TOPRIGHT", 9, 0)
        list.bar:SetPoint("BOTTOMLEFT", list.box, "BOTTOMRIGHT", 9, 4)
    end

    -- leere Liste: goldener Hinweis oben mittig wie "Tipp: ..." im Auktionshaus
    t.empty = panel:CreateFontString(nil, "ARTWORK", UI.FONT.hint)
    t.empty:SetPoint("TOP", list.box, "TOP", 0, -45)
    t.empty:SetWidth(420)
    t.empty:SetText(o.empty or L.LIST_EMPTY or "")
    t.spinner = UI.Spinner(panel, o.loadingText or "")
    t.spinner:SetPoint("CENTER", list.box, "CENTER", 0, -15)
    t.spinner:Hide()

    function t:Sort()
        table.sort(self.items, Cmp)
        for i, item in ipairs(self.items) do item.__index = i end
        Layout()
        self.list:SetData(self.items)
    end
    function t:SetData(items)
        self.items = {}
        for i, item in ipairs(items or {}) do self.items[i] = item end
        if self.selected then
            local still = false
            for _, item in ipairs(self.items) do if item == self.selected then still = true end end
            if not still then self.selected = nil end
        end
        self:Sort()
        self.empty:SetShown(#self.items == 0 and not self.loading)
    end
    function t:SetLoading(on, text)
        self.loading = on and true or false
        if text then self.spinner.text:SetText(text) end
        self.spinner:SetShown(self.loading)
        self.list.box:SetShown(not self.loading)
        if self.list.bar then self.list.bar:SetShown(not self.loading) end
        self.empty:SetShown(#self.items == 0 and not self.loading)
    end
    function t:GetSelected() return self.selected end
    return t
end

---------------------------------------------------------------------------
-- Kategorieliste wie im Auktionshaus. nodes = { { key, text, level = 1..3 } }, onSelect(key)
---------------------------------------------------------------------------
function UI.CategoryList(panel, nodes, onSelect)
    local c = { selected = nil }
    local list
    list = UI.ScrollList(panel, {
        extent = UI.NAV_H, padLeft = 3,
        create = function(b)
            b.normal = b:CreateTexture(nil, "BACKGROUND")
            b.lines = b:CreateTexture(nil, "BACKGROUND")
            UI.SetAtlas(b.lines, "auctionhouse-nav-button-tertiary-filterline", true)
            b.lines:SetPoint("LEFT", 18, 3)
            b.hl = b:CreateTexture(nil, "BORDER")
            b.hl:Hide()
            b.sel = b:CreateTexture(nil, "ARTWORK")
            b.sel:SetBlendMode("ADD")
            b.sel:Hide()
            b.text = b:CreateFontString(nil, "ARTWORK", UI.FONT.nav)
            b.text:SetJustifyH("LEFT")
            b.text:SetPoint("RIGHT", -4, 0)
            if b.text.SetWordWrap then b.text:SetWordWrap(false) end
            b:SetScript("OnEnter", function(self) self.hl:Show() end)
            b:SetScript("OnLeave", function(self) self.hl:Hide() end)
        end,
        init = function(b, n)
            if not n then return end
            local lvl = n.level or 1
            b.normal:ClearAllPoints(); b.hl:ClearAllPoints(); b.sel:ClearAllPoints(); b.text:ClearAllPoints()
            b.text:SetPoint("RIGHT", -4, 0)
            if lvl == 1 then
                UI.SetAtlas(b.normal, "auctionhouse-nav-button", false); b.normal:SetSize(136, 32); b.normal:SetPoint("TOPLEFT", -2, 0)
                UI.SetAtlas(b.sel, "auctionhouse-nav-button-select", false); b.sel:SetSize(132, 21); b.sel:SetPoint("LEFT")
                UI.SetAtlas(b.hl, "auctionhouse-nav-button-highlight", false); b.hl:SetSize(132, 21); b.hl:SetPoint("LEFT")
                UI.Font(b.text, "nav"); b.text:SetPoint("LEFT", 8, 0)
                b.normal:SetAlpha(1); b.lines:Hide()
            elseif lvl == 2 then
                UI.SetAtlas(b.normal, "auctionhouse-nav-button-secondary", false); b.normal:SetSize(133, 32); b.normal:SetPoint("TOPLEFT", 1, 0)
                UI.SetAtlas(b.sel, "auctionhouse-nav-button-secondary-select", false); b.sel:SetSize(122, 21); b.sel:SetPoint("TOPLEFT", 10, 0)
                UI.SetAtlas(b.hl, "auctionhouse-nav-button-secondary-highlight", false); b.hl:SetSize(122, 21); b.hl:SetPoint("TOPLEFT", 10, 0)
                UI.Font(b.text, "small"); b.text:SetPoint("LEFT", 18, 0)
                b.normal:SetAlpha(1); b.lines:Hide()
            else
                UI.SetAtlas(b.normal, "auctionhouse-nav-button-secondary", false); b.normal:SetSize(133, 32); b.normal:SetPoint("TOPLEFT", 10, 0)
                UI.SetAtlas(b.sel, "auctionhouse-ui-row-select", false); b.sel:SetSize(116, 18); b.sel:SetPoint("TOPRIGHT", 0, -2)
                UI.SetAtlas(b.hl, "auctionhouse-ui-row-highlight", false); b.hl:SetSize(116, 18); b.hl:SetPoint("TOPRIGHT", 0, -2)
                UI.Font(b.text, "small"); b.text:SetPoint("LEFT", 26, 0)
                b.normal:SetAlpha(0); b.lines:Show()
            end
            b.text:SetText(n.text or "")
            b.sel:SetShown(c.selected == n.key)
        end,
        onClick = function(n)
            if not n then return end
            -- wie Blizzard: Klick oeffnet die Kategorie mit ihren Unterpunkten, erneuter Klick klappt sie zu
            if c.selected == n.key then c.selected = c.ParentOf(n) else c.selected = n.key end
            c:Update()
            if onSelect then onSelect(c.selected, c.selected and c.byKey[c.selected] or nil) end
        end,
    })
    c.list = list
    -- Masse wie Blizzards Kategorieliste: Liste 3 vom Rand, Leiste 6 rechts daneben
    list.box:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -6)
    list.box:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -25, 2)
    -- Hintergrund endet vor der Leiste wie bei Blizzard (Bild 138 breit im 168 breiten Bereich, gemessen 11.11.2026):
    -- hinter der Leiste ist das hellere Grau des Fensters zu sehen
    panel.bgRight = 27
    if panel.FitBackground then panel.FitBackground() end
    if list.bar then
        list.bar:SetPoint("TOPLEFT", list.box, "TOPRIGHT", 6, 0)
        list.bar:SetPoint("BOTTOMLEFT", list.box, "BOTTOMRIGHT", 6, 4)
    end
    -- Eltern: n.parent oder der Schluessel ohne den letzten Teil ("Handwerkswaren/Stoff" -> "Handwerkswaren")
    function c.ParentOf(n)
        if n.parent then return n.parent end
        local p = type(n.key) == "string" and n.key:match("^(.*)/[^/]+$")
        return p
    end
    -- sichtbar: oberste Stufe immer, sonst nur Unterpunkte der gewaehlten Kategorie und ihrer Eltern
    function c:Visible()
        local open = {}
        local k = self.selected
        while k do
            open[k] = true
            local n = self.byKey[k]
            k = n and self.ParentOf(n) or nil
        end
        local out = {}
        for _, n in ipairs(self.nodes) do
            local p = self.ParentOf(n)
            if not p or open[p] then out[#out + 1] = n end
        end
        return out
    end
    function c:Update() list:SetData(self:Visible()) end
    function c:SetNodes(n)
        self.nodes = n or {}
        self.byKey = {}
        for _, node in ipairs(self.nodes) do self.byKey[node.key] = node end
        if self.selected and not self.byKey[self.selected] then self.selected = nil end
        self:Update()
    end
    function c:Select(key)
        self.selected = key
        self:Update()
    end
    c:SetNodes(nodes)
    return c
end

---------------------------------------------------------------------------
-- Statuszeile unten im Fenster (Rahmen wie Blizzards Geldanzeige: InsetFrameTemplate, 24 hoch)
---------------------------------------------------------------------------
function UI.StatusBar(win)
    local f = UI.TryFrame("Frame", nil, win, "InsetFrameTemplate") or CreateFrame("Frame", nil, win)
    f:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 2, 27)
    f:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -2, 3)
    f.text = f:CreateFontString(nil, "ARTWORK", UI.FONT.small)
    f.text:SetPoint("LEFT", 10, 0)
    f.text:SetJustifyH("LEFT")
    f.money = UI.Money(f)
    f.money:SetPoint("RIGHT", -8, 0)
    function f:SetText(t) self.text:SetText(t or "") end
    return f
end

---------------------------------------------------------------------------
-- Einklappbare Ueberschrift (Plus/Minus wie Blizzards Listen)
---------------------------------------------------------------------------
function UI.Collapse(parent, text, open, fn)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(200, 18)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(14, 14)
    b.icon:SetPoint("LEFT", 0, 0)
    b.text = b:CreateFontString(nil, "ARTWORK", UI.FONT.label)
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
    b.text:SetText(text or "")
    b.open = open and true or false
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    if not UI.SetAtlas(hl, "auctionhouse-ui-row-highlight", false) then hl:SetColorTexture(1, 1, 1, 0.08) end
    hl:SetBlendMode("ADD")
    local function Upd()
        pcall(b.icon.SetTexture, b.icon, b.open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
    end
    b:SetScript("OnClick", function(self)
        self.open = not self.open
        Upd()
        if fn then fn(self.open) end
    end)
    Upd()
    return b
end

---------------------------------------------------------------------------
-- Fortschrittsbalken (Vorschlag: Blizzards Balken-Grafik in einem schmalen Bereich)
---------------------------------------------------------------------------
-- Wie Blizzards Balken beim Herstellen (CastingBarFrameBaseTemplate, Art "applyingcrafting", KarloDerBaer):
-- Hintergrund ui-castingbar-background (1 ueber den Rand), Fuellung ui-castingbar-filling-applyingcrafting,
-- voll ui-castingbar-full-applyingcrafting, Rahmen ui-castingbar-frame (2 ueber den Rand), Funke ui-castingbar-pip
-- 8x20 am Ende der Fuellung. Spielergroesse 208x11. Text darunter wie der Zauberbalken (GameFontHighlightSmall).
UI.PROGRESS = {
    bg = "ui-castingbar-background", fill = "ui-castingbar-filling-applyingcrafting",
    full = "ui-castingbar-full-applyingcrafting", frame = "ui-castingbar-frame", spark = "ui-castingbar-pip",
}

function UI.Progress(parent, width)
    local P = UI.PROGRESS
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width or 208, 11)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", -1, 1)
    bg:SetPoint("BOTTOMRIGHT", 1, -1)
    if not UI.SetAtlas(bg, P.bg, false) then bg:SetColorTexture(0, 0, 0, 0.6) end
    local function Fill(full)
        local atlas = full and P.full or P.fill
        if UI.HasAtlas(atlas) and pcall(bar.SetStatusBarTexture, bar, atlas) then
            bar:SetStatusBarColor(1, 1, 1)
        else
            pcall(bar.SetStatusBarTexture, bar, "Interface\\TargetingFrame\\UI-StatusBar")
            bar:SetStatusBarColor(full and 0 or 1, full and 1 or 0.7, 0)
        end
    end
    Fill(false)
    local border = bar:CreateTexture(nil, "ARTWORK", nil, 4)
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    if not UI.SetAtlas(border, P.frame, false) then border:Hide() end
    local spark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
    spark:SetSize(8, 20)
    if not UI.SetAtlas(spark, P.spark, false) then spark:Hide() end
    local fillTex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if fillTex then spark:SetPoint("CENTER", fillTex, "RIGHT", 0, 0) else spark:SetPoint("CENTER", bar, "LEFT", 0, 0) end
    bar.spark = spark
    bar.text = bar:CreateFontString(nil, "OVERLAY", UI.FONT.small)
    bar.text:SetPoint("TOP", bar, "BOTTOM", 0, -4)
    bar.bar = bar
    function bar:Set(v, text)
        v = math.max(0, math.min(1, v or 0))
        self:SetValue(v)
        local full = v >= 1
        if full ~= self.isFull then self.isFull = full; Fill(full) end
        -- Funke nur waehrend der Fuellung, wie bei Blizzard
        if self.spark.SetShown then self.spark:SetShown(v > 0 and v < 1 and UI.HasAtlas(P.spark)) end
        self.text:SetText(text or "")
    end
    return bar
end

---------------------------------------------------------------------------
-- Rueckfrage (eigenes Fenster mit Blizzards dunklem Dialograhmen, keine Eintraege in Blizzards Tabellen)
---------------------------------------------------------------------------
function UI.Confirm(text, yesText, noText, onYes)
    local d = UI.dialog
    if not d then
        -- Blizzards Dialograhmen fuellt immer seinen Elternrahmen: darum als Kind eines eigenen Fensters
        d = CreateFrame("Frame", "PeonUIConfirm", UIParent)
        d:SetSize(320, 110)
        d.border = UI.TryFrame("Frame", nil, d, "DialogBorderDarkTemplate")
        if not d.border then
            local bg = d:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0, 0, 0, 0.85)
        end
        d:SetPoint("CENTER", 0, 120)
        d:SetFrameStrata("DIALOG")
        d:SetToplevel(true)
        d:EnableMouse(true)
        -- Inhalt auf eigener Ebene ueber dem Rahmen (der Rahmen ist ein Kind und wuerde Text sonst verdecken)
        local c = CreateFrame("Frame", nil, d)
        c:SetAllPoints()
        c:SetFrameLevel((d:GetFrameLevel() or 1) + 10)
        d.content = c
        d.text = c:CreateFontString(nil, "ARTWORK", UI.FONT.text)
        d.text:SetPoint("TOP", 0, -20)
        d.text:SetWidth(280)
        d.yes = UI.Button(c, "", 120, function() d:Hide(); if d.onYes then d.onYes() end end)
        d.yes:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -4, 16)
        d.no = UI.Button(c, "", 120, function() d:Hide() end)
        d.no:SetPoint("BOTTOMLEFT", d, "BOTTOM", 4, 16)
        if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "PeonUIConfirm") end
        UI.dialog = d
    end
    d.text:SetText(text or "")
    d.yes:SetText(yesText or OKAY or "OK")
    d.no:SetText(noText or CANCEL or "Abbrechen")
    d.onYes = onYes
    d:Show()
    return d
end
