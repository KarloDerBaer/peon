-- Peon - Widgets.lua
-- Bausteine fuer Optionsseiten der Module.
--
--   local page = mod:NewOptionsPage({ desc = L.DESC })
--   local left = page:Column(16, -60)
--   page:Add(left, page:Header(L.HDR_POSITION), 6)
--   page:Add(left, page:Slider("offsetX", L.OFFSET_X, L.OFFSET_X_HINT))
--   page:Add(left, page:Check("edgeFlip", L.EDGE_FLIP))
--   page:Add(left, page:Choice("corner", L.CORNER, { { "TOPLEFT", "Links oben" }, ... }, 2, 138))
--   page:Add(left, page:PositionGrid("pvpIcon", L.PVP_ICON))
--   page:Add(left, page:Color("ringColor", L.RING, true))   -- mit Deckkraft
--   page:Add(left, page:Button(L.SAVE, function() ... end, L.SAVE_HINT))      -- ab API 5
--   page:Add(left, page:Text(function() return "..." end))                  -- ab API 5, wechselnder Text
--   page:Add(left, page:Check("clickMode", L.CLICK, L.HINT, { "double", "off" }))  -- ab API 5
--   page:Add(left, page:Dropdown("mode", L.MODE, { { "a", "A" }, { "b", "B" } }, L.HINT))  -- ab API 6
--   page:Add(left, page:List({ columns = { ... }, rows = 8 }))           -- ab API 7, siehe List.lua
--   page:AddResetButton(L.SLASH_HINT, left, right)
--   page:Register()
--
-- Untertabs (ab API 11):
--   page:Tabs({ { "general", "Allgemein" }, { "items", "Gegenstände" } }, -58)   -- Reiterleiste bei y
--   local left = page:Column(16, -96, "general")      -- Spalte gehoert zum Reiter "general"
--   page.onTab = function(page, key) ... end          -- nach jedem Wechsel (auch beim ersten Anzeigen)
--   page:SelectTab("items")
-- Spalten ohne Reiter sind immer sichtbar. Der Reset-Knopf steht unter der tiefsten sichtbaren Spalte.
--
-- Jede Aenderung schreibt in mod.db und feuert mod:Fire("CHANGED", key).
-- Wertebereiche fuer Regler kommen aus opts.ranges des Moduls ({ min, max, Schritt }).
-- Ab API 5 wird die Seite bei jedem Refresh neu angeordnet: Bausteine, deren Hoehe sich
-- aendert (eigene Container, Text), schieben alles darunter mit.

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local L = ns.L
local Module = Peon.ModulePrototype

local Page = {}
Page.__index = Page
Peon.PagePrototype = Page   -- ab API 7: weitere Bausteine in eigenen Dateien (z. B. List.lua)

-- Aus + 8 Ankerpunkte als 3x3-Raster, "Aus" in der Mitte
Peon.POSITIONS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "none", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
Peon.POSITION_SET = {}
for _, pos in ipairs(Peon.POSITIONS) do Peon.POSITION_SET[pos] = true end

---------------------------------------------------------------------------
-- Seite
---------------------------------------------------------------------------
-- o.desc: Beschreibung unter dem Titel; o.colW: Spaltenbreite (Standard 290); o.height: Starthoehe
function Module:NewOptionsPage(o)
    o = o or {}
    local page = setmetatable({ mod = self, controls = {}, columns = {}, colW = o.colW or 290 }, Page)

    local panel = CreateFrame("Frame")
    panel.name = self.title
    panel:Hide()
    page.panel = panel

    -- Scrollbereich, damit alles Platz hat (Fallback: ohne Scrollen)
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    local content
    if ok and scroll then
        scroll:SetPoint("TOPLEFT", 0, -4)
        scroll:SetPoint("BOTTOMRIGHT", -28, 4)
        content = CreateFrame("Frame", nil, scroll)
        content:SetSize(640, o.height or 900)
        scroll:SetScrollChild(content)
        scroll:SetScript("OnSizeChanged", function(_, w)
            if w and w > 0 then content:SetWidth(w) end
        end)
    else
        content = panel
    end
    page.content = content

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText(("|c%sPeon|r %s  |cff888888v%s|r"):format(Peon.COLOR, self.title, tostring(self.version)))

    if o.desc then
        local desc = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        desc:SetWidth(600)
        desc:SetJustifyH("LEFT")
        desc:SetText(o.desc)
    end

    panel:SetScript("OnShow", function() page:Refresh() end)
    local function Reset() self:ResetDefaults() end
    panel.default = Reset      -- alter "Standard"-Knopf
    panel.OnDefault = Reset

    self:On("RESET", function() if panel:IsShown() then page:Refresh() end end)
    self.page = page
    return page
end

function Page:Register()
    self.mod:RegisterOptions(self.panel)
end

-- Werte aller Bausteine neu anzeigen; page.onRefresh fuer abhaengige Zustaende (ausgrauen)
function Page:Refresh()
    for _, c in ipairs(self.controls) do
        if c.Refresh then c.Refresh() end
    end
    self:Layout()
    if self.onRefresh then self.mod:Call("Options", self.onRefresh, self) end
    if self.tabList and self.onTab then self.mod:Call("Options", self.onTab, self, self.tab) end
end

function Page:Changed(key)
    self.mod:Fire("CHANGED", key)
    if self.onRefresh then self.mod:Call("Options", self.onRefresh, self) end
end

---------------------------------------------------------------------------
-- Layout: Spalte mit laufender Y-Position
---------------------------------------------------------------------------
function Page:Column(x, y, tab)
    local col = { x = x, y = y, y0 = y, items = {}, tab = tab }
    self.columns[#self.columns + 1] = col
    return col
end

function Page:Add(col, c, gap)
    gap = gap or 10
    c:SetPoint("TOPLEFT", self.content, "TOPLEFT", col.x, col.y)
    if col.tab and c.SetParent then c:SetParent(self:TabFrame(col.tab)) end   -- ab API 11
    col.y = col.y - c:GetHeight() - gap
    if col.items then col.items[#col.items + 1] = { c = c, gap = gap } end
    self.controls[#self.controls + 1] = c
    return c
end

-- Alle Spalten neu anordnen (Hoehen koennen sich beim Refresh aendern); Reset-Knopf wandert mit
function Page:Layout()
    for _, col in ipairs(self.columns) do
        if col.items then
            local y = col.y0
            for _, it in ipairs(col.items) do
                it.c:ClearAllPoints()
                it.c:SetPoint("TOPLEFT", self.content, "TOPLEFT", col.x, y)
                y = y - it.c:GetHeight() - it.gap
            end
            col.y = y
        end
    end
    if self.resetButton then self:_PlaceReset() end
end

function Page:_ColVisible(col)
    return not col.tab or col.tab == self.tab
end

function Page:_PlaceReset()
    local bottomY = 0
    local any = false
    for _, col in ipairs(self.resetCols) do
        if self:_ColVisible(col) then bottomY = math.min(bottomY, col.y); any = true end
    end
    if not any then     -- ab API 11: Reiter ohne genannte Spalte -> seine Spalten
        for _, col in ipairs(self.columns) do
            if self:_ColVisible(col) then bottomY = math.min(bottomY, col.y) end
        end
    end
    if self.extraBottom then bottomY = math.min(bottomY, self.extraBottom) end
    bottomY = bottomY - 10
    local content = self.content
    self.resetButton:ClearAllPoints()
    self.resetButton:SetPoint("TOPLEFT", content, "TOPLEFT", 14, bottomY)
    if content ~= self.panel then content:SetHeight(-bottomY + 40) end
end

-- Knopf "Standardwerte" unter der tiefsten Spalte; hint z. B. Chat-Befehle
function Page:AddResetButton(hint, ...)
    local content = self.content
    local reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    reset:SetSize(220, 24)
    self.resetButton, self.resetCols = reset, { ... }
    self:_PlaceReset()
    reset:SetText(L.RESET)
    reset:SetScript("OnClick", function()
        self.mod:ResetDefaults()
        self.mod:Print(L.MSG_RESET)
    end)
    if hint then
        local fs = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        fs:SetPoint("LEFT", reset, "RIGHT", 12, 0)
        fs:SetText(hint)
    end
    return reset
end

---------------------------------------------------------------------------
-- Bausteine
---------------------------------------------------------------------------
function Page:NewContainer(height)
    local c = CreateFrame("Frame", nil, self.content)
    c:SetSize(self.colW, height)
    return c
end

-- Hinweistext unter einem Baustein; Container waechst mit der Textlaenge
function Page:AddHint(c, text, y)
    local h = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    h:SetPoint("TOPLEFT", 0, y)
    h:SetWidth(self.colW)
    h:SetJustifyH("LEFT")
    h:SetText(text)
    local textH = h:GetStringHeight() or 12
    if textH < 12 then textH = 12 end
    c:SetHeight(-y + textH + 2)
end

function Page:Header(text)
    local c = self:NewContainer(24)
    local fs = c:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 0, 0)
    fs:SetText(text)
    local line = c:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.15)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -16)
    line:SetPoint("TOPRIGHT", 0, -16)
    return c
end

-- Regler mit Zahlenfeld. suffix z. B. "%"; divisor zeigt Werte geteilt an (Zehntelsekunden -> s)
function Page:Slider(key, label, hint, suffix, divisor)
    local mod = self.mod
    local range = mod.opts.ranges and mod.opts.ranges[key]
    assert(range, "Peon: kein Wertebereich fuer " .. tostring(key))
    local c = self:NewContainer(54)
    suffix, divisor = suffix or "", divisor or 1

    local function Show(v)
        if divisor == 1 then return tostring(v) end
        return ("%.1f"):format(v / divisor)
    end

    local title = c:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label)

    local ok, slider = pcall(CreateFrame, "Slider", nil, c, "OptionsSliderTemplate")
    if not ok or not slider then slider = CreateFrame("Slider", nil, c) end
    if not slider:GetThumbTexture() then
        -- Template fehlt: selbst zeichnen
        slider:SetOrientation("HORIZONTAL")
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        local bg = slider:CreateTexture(nil, "BACKGROUND")
        bg:SetColorTexture(0, 0, 0, 0.5)
        bg:SetPoint("LEFT")
        bg:SetPoint("RIGHT")
        bg:SetHeight(6)
    end
    slider:SetPoint("TOPLEFT", 4, -20)
    slider:SetSize(190, 17)
    slider:SetMinMaxValues(range[1], range[2])
    slider:SetValueStep(range[3] or 1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    if slider.Low then slider.Low:SetText(Show(range[1]) .. suffix) end
    if slider.High then slider.High:SetText(Show(range[2]) .. suffix) end
    if slider.Text then slider.Text:SetText("") end

    if hint then self:AddHint(c, hint, -54) end

    local box = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
    box:SetSize(44, 20)
    box:SetPoint("LEFT", slider, "RIGHT", 14, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(5)
    box:SetJustifyH("CENTER")
    local unit = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    unit:SetPoint("LEFT", box, "RIGHT", 2, 0)
    unit:SetText(divisor == 10 and "s" or suffix)

    local updating = false

    slider:SetScript("OnValueChanged", function(_, value)
        local db = mod.db
        if updating or not db then return end
        value = Peon.Clamp(value, range)
        if value == nil or db[key] == value then return end
        db[key] = value
        box:SetText(Show(value))
        self:Changed(key)
    end)

    local function ApplyBox(b)
        local db = mod.db
        if not db then return end
        local raw = tonumber((b:GetText() or ""):gsub(",", ".") .. "")
        local value = raw and Peon.Clamp(raw * divisor, range)
        if value then slider:SetValue(value) end
        b:SetText(Show(db[key]))   -- ungueltige Eingabe: alter Wert
        b:ClearFocus()
    end
    box:SetScript("OnEnterPressed", ApplyBox)
    box:SetScript("OnEditFocusLost", ApplyBox)
    box:SetScript("OnEscapePressed", function(b)
        if mod.db then b:SetText(Show(mod.db[key])) end
        b:ClearFocus()
    end)

    c.Refresh = function()
        local db = mod.db
        if not db then return end
        updating = true
        slider:SetValue(db[key])
        box:SetText(Show(db[key]))
        updating = false
    end
    return c
end

-- Haekchen. hint (ab API 5): Text darunter. values (ab API 5): { anWert, ausWert } fuer
-- Einstellungen, die keine true/false-Werte sind, z. B. { "double", "off" }
function Page:Check(key, label, hint, values)
    local mod = self.mod
    local on, off = true, false
    if values then on, off = values[1], values[2] end
    local c = self:NewContainer(26)
    local cb = CreateFrame("CheckButton", nil, c, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", -4, 0)
    if cb.text then cb.text:SetText("") end
    if cb.Text then cb.Text:SetText("") end
    local fs = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", cb, "TOPRIGHT", 2, -6)
    fs:SetWidth(self.colW - 26)
    fs:SetJustifyH("LEFT")
    fs:SetText(label)
    local textH = fs:GetStringHeight() or 12
    if textH > 14 then c:SetHeight(textH + 12) end   -- lange Texte brechen um
    if hint then self:AddHint(c, hint, -c:GetHeight()) end
    cb:SetScript("OnClick", function(b)
        if not mod.db then return end
        if b:GetChecked() then mod.db[key] = on else mod.db[key] = off end
        self:Changed(key)
    end)
    c.Refresh = function()
        if mod.db then cb:SetChecked(mod.db[key] == on) end
    end
    return c
end

-- Knopf (ab API 5); onClick(page), hint: Text darunter
function Page:Button(text, onClick, hint)
    local c = self:NewContainer(26)
    local b = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    b:SetSize(200, 24)
    b:SetPoint("TOPLEFT", 0, 0)
    b:SetText(text)
    b:SetScript("OnClick", function() self.mod:Call("Button", onClick, self) end)
    if hint then self:AddHint(c, hint, -28) end
    c.button = b
    return c
end

-- Wechselnder Text (ab API 5): fn() liefert den Text, wird bei jedem Refresh neu gesetzt
function Page:Text(fn)
    local c = self:NewContainer(16)
    local fs = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 0, 0)
    fs:SetWidth(self.colW)
    fs:SetJustifyH("LEFT")
    c.Refresh = function()
        if not self.mod.db then return end
        local ok, text = pcall(fn)
        fs:SetText(ok and tostring(text or "") or "")
        c:SetHeight(math.max(14, fs:GetStringHeight() or 14) + 2)
    end
    return c
end

-- Auswahl per Knopfreihe. Nur wo die Anordnung selbst etwas zeigt (z. B. Positionen);
-- sonst page:Dropdown verwenden (Entscheidung KarloDerBaer, 29.09.2026)
-- options = { { wert, text }, ... }
function Page:Choice(key, label, options, perRow, btnW, hint)
    local mod = self.mod
    perRow, btnW = perRow or 3, btnW or 92
    local rows = math.ceil(#options / perRow)
    local c = self:NewContainer(18 + rows * 26)
    local title = c:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label)

    local buttons = {}
    for i, opt in ipairs(options) do
        local b = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        b:SetSize(btnW, 22)
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        b:SetPoint("TOPLEFT", col * (btnW + 4), -16 - row * 26)
        b.value, b.label = opt[1], opt[2]
        b:SetScript("OnClick", function(btn)
            if not mod.db then return end
            mod.db[key] = btn.value
            c.Refresh()
            self:Changed(key)
        end)
        buttons[i] = b
    end
    if hint then self:AddHint(c, hint, -18 - rows * 26) end
    c.Refresh = function()
        local db = mod.db
        if not db then return end
        for _, b in ipairs(buttons) do
            if db[key] == b.value then
                b:SetText("|cffffd100" .. b.label .. "|r")
                b:LockHighlight()
            else
                b:SetText(b.label)
                b:UnlockHighlight()
            end
        end
    end
    return c
end

-- Auswahlliste (Dropdown, ab API 6) - Standard, wenn aus mehreren Moeglichkeiten eine gewaehlt wird.
-- options = { { wert, text }, ... } oder eine Funktion, die diese Liste liefert (wird bei jedem
-- Oeffnen/Refresh neu gelesen, z. B. fuer Ausruestungssets).
-- h (optional): { get = fn() -> wert, set = fn(wert), empty = "Text ohne Auswahl" (oder Funktion) } statt mod.db[key].
-- Neue Menue-API (WowStyle1DropdownTemplate), sonst UIDropDownMenu, sonst eine Knopfreihe.
-- c.Select(wert) waehlt per Code (fuer Tests).
function Page:Dropdown(key, label, options, hint, h)
    local mod = self.mod
    h = h or {}
    local c = self:NewContainer(48)
    c.key = key
    local title = c:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label)

    local function List()
        if type(options) == "function" then
            local ok, list = pcall(options)
            return ok and type(list) == "table" and list or {}
        end
        return options
    end
    local function Get()
        if h.get then return h.get() end
        return mod.db and mod.db[key]
    end
    local function TextOf(v)
        for _, o in ipairs(List()) do if o[1] == v then return o[2] end end
        return nil
    end
    local function Empty()
        if type(h.empty) == "function" then return h.empty() end
        return h.empty
    end
    local refresh
    function c.Select(v)
        if not mod.db then return end
        if h.set then
            mod:Call("Dropdown", h.set, v)
        else
            if mod.db[key] == v then return end
            mod.db[key] = v
        end
        self:Changed(key)
        if refresh then refresh() end
    end

    local ok, dd = pcall(CreateFrame, "DropdownButton", nil, c, "WowStyle1DropdownTemplate")
    if ok and dd and dd.SetupMenu then
        dd:SetPoint("TOPLEFT", 0, -16)
        dd:SetWidth(200)
        dd:SetupMenu(function(_, root)
            for _, o in ipairs(List()) do
                root:CreateRadio(o[2], function() return Get() == o[1] end, function() c.Select(o[1]) end)
            end
        end)
        refresh = function()
            local e = Empty(); if e and dd.SetDefaultText then dd:SetDefaultText(e) end
            if dd.GenerateMenu then dd:GenerateMenu() end
        end
    else
        ok, dd = pcall(CreateFrame, "Frame", nil, c, "UIDropDownMenuTemplate")
        if ok and dd and UIDropDownMenu_Initialize then
            dd:SetPoint("TOPLEFT", -16, -14)
            UIDropDownMenu_SetWidth(dd, 180)
            UIDropDownMenu_Initialize(dd, function()
                for _, o in ipairs(List()) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = o[2]
                    info.checked = Get() == o[1]
                    info.func = function() c.Select(o[1]) end
                    UIDropDownMenu_AddButton(info)
                end
            end)
            refresh = function() UIDropDownMenu_SetText(dd, TextOf(Get()) or Empty() or "") end
        else
            -- Rueckfall: Knopfreihe (Knoepfe werden bei Bedarf angelegt)
            local buttons = {}
            refresh = function()
                local list = List()
                for i, o in ipairs(list) do
                    local b = buttons[i]
                    if not b then
                        b = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
                        b:SetSize(94, 22)
                        b:SetPoint("TOPLEFT", ((i - 1) % 3) * 98, -16 - math.floor((i - 1) / 3) * 26)
                        b:SetScript("OnClick", function(btn) c.Select(btn.value) end)
                        buttons[i] = b
                    end
                    b.value = o[1]
                    b:SetText(Get() == o[1] and ("|cffffd100" .. o[2] .. "|r") or o[2])
                    b:Show()
                end
                for i = #list + 1, #buttons do buttons[i]:Hide() end
            end
        end
    end
    if hint then self:AddHint(c, hint, -48) end
    c.Refresh = function()
        if mod.db and refresh then refresh() end
    end
    return c
end

-- 3x3-Raster: Aus in der Mitte, 8 Ankerpunkte drumherum (Werte aus Peon.POSITIONS)
function Page:PositionGrid(key, label, hint)
    local options = {}
    for i, pos in ipairs(Peon.POSITIONS) do options[i] = { pos, L["POS_" .. pos] } end
    return self:Choice(key, label, options, 3, 92, hint)
end

-- Farbfeld mit Blizzards Farbwaehler. Wert in mod.db[key] = { r, g, b [, a] } (0..1).
-- hasAlpha: Deckkraft mit einstellen (Tabelle hat dann vier Werte)
function Page:Color(key, label, hasAlpha)
    local mod = self.mod
    local c = self:NewContainer(26)

    local btn = CreateFrame("Button", nil, c)
    btn:SetSize(24, 24)
    btn:SetPoint("LEFT", 0, 0)
    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.8, 0.8, 0.8, 1)
    local checker = btn:CreateTexture(nil, "BORDER")   -- dunkler Grund, damit Deckkraft sichtbar wird
    checker:SetPoint("TOPLEFT", 2, -2)
    checker:SetPoint("BOTTOMRIGHT", -2, 2)
    checker:SetColorTexture(0.15, 0.15, 0.15, 1)
    local swatch = btn:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 2, -2)
    swatch:SetPoint("BOTTOMRIGHT", -2, 2)

    local fs = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", btn, "RIGHT", 8, 0)
    fs:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(label)

    local function Set(r, g, b, a)
        local col = mod.db and mod.db[key]
        if type(col) ~= "table" or type(r) ~= "number" then return end
        col[1], col[2], col[3] = r, g, b
        if hasAlpha and type(a) == "number" then col[4] = a end
        c.Refresh()
        self:Changed(key)
    end

    local function Current()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        local a
        if hasAlpha then
            if ColorPickerFrame.GetColorAlpha then
                a = ColorPickerFrame:GetColorAlpha()
            elseif OpacitySliderFrame then
                a = 1 - OpacitySliderFrame:GetValue()   -- alter Farbwaehler: Transparenz statt Deckkraft
            end
        end
        return r, g, b, a
    end

    btn:SetScript("OnClick", function()
        local col = mod.db and mod.db[key]
        if type(col) ~= "table" or not ColorPickerFrame then return end
        local old = { col[1], col[2], col[3], col[4] }
        local function OnChange() Set(Current()) end
        local function OnCancel() Set(old[1], old[2], old[3], old[4]) end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = col[1], g = col[2], b = col[3],
                opacity = col[4] or 1, hasOpacity = hasAlpha and true or false,
                swatchFunc = OnChange, opacityFunc = OnChange, cancelFunc = OnCancel,
            })
        else
            ColorPickerFrame:Hide()
            ColorPickerFrame.func, ColorPickerFrame.opacityFunc = OnChange, OnChange
            ColorPickerFrame.cancelFunc = OnCancel
            ColorPickerFrame.hasOpacity = hasAlpha and true or false
            ColorPickerFrame.opacity = 1 - (col[4] or 1)
            ColorPickerFrame:SetColorRGB(col[1], col[2], col[3])
            ColorPickerFrame:Show()
        end
    end)

    c.Refresh = function()
        local col = mod.db and mod.db[key]
        if type(col) == "table" then swatch:SetColorTexture(col[1], col[2], col[3], col[4] or 1) end
    end
    return c
end

---------------------------------------------------------------------------
-- Untertabs (ab API 11)
---------------------------------------------------------------------------
-- Haltefenster je Reiter: Bausteine der Spalten haengen daran, sichtbar nur im aktiven Reiter
function Page:TabFrame(key)
    self.tabFrames = self.tabFrames or {}
    local f = self.tabFrames[key]
    if not f then
        f = CreateFrame("Frame", nil, self.content)
        f:SetAllPoints(self.content)
        f:SetShown(self.tab == nil or self.tab == key)
        self.tabFrames[key] = f
    end
    return f
end

local TAB_TEMPLATES = { "PanelTopTabButtonTemplate", "UIPanelButtonTemplate" }

-- list = { { key, Text }, ... }; y = Hoehe der Reiterleiste (Standard -58)
function Page:Tabs(list, y)
    local bar = CreateFrame("Frame", nil, self.content)
    bar:SetPoint("TOPLEFT", self.content, "TOPLEFT", 16, y or -58)
    bar:SetSize(600, 30)
    self.tabBar, self.tabButtons, self.tabList = bar, {}, list
    local x = 0
    for i, t in ipairs(list) do
        local b, style
        for _, tpl in ipairs(TAB_TEMPLATES) do
            local ok, f = pcall(CreateFrame, "Button", nil, bar, tpl)
            if ok and f then b, style = f, tpl break end
        end
        b:SetText(t[2])
        if style == "PanelTopTabButtonTemplate" and PanelTemplates_TabResize then
            pcall(PanelTemplates_TabResize, b, 12)
        else
            b:SetSize(math.max(90, ((b.GetFontString and b:GetFontString() and b:GetFontString():GetStringWidth()) or 70) + 24), 24)
        end
        b.key, b.style = t[1], style
        b:SetID(i)
        b:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
        local w = b:GetWidth()
        if type(w) ~= "number" or w < 20 then w = 100 end
        x = x + w + 2
        b:SetScript("OnClick", function() self:SelectTab(t[1]) end)
        self.tabButtons[i] = b
        self:TabFrame(t[1])
    end
    local line = bar:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.15)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    self.tab = self.tab or (list[1] and list[1][1])
    self:_UpdateTabs()
    return bar
end

function Page:_UpdateTabs()
    for key, f in pairs(self.tabFrames or {}) do f:SetShown(key == self.tab) end
    for _, b in ipairs(self.tabButtons or {}) do
        local on = b.key == self.tab
        if b.style == "PanelTopTabButtonTemplate" and PanelTemplates_SelectTab and PanelTemplates_DeselectTab then
            if on then pcall(PanelTemplates_SelectTab, b) else pcall(PanelTemplates_DeselectTab, b) end
        else
            if on then b:LockHighlight() else b:UnlockHighlight() end
            b:SetAlpha(on and 1 or 0.7)
        end
    end
end

function Page:SelectTab(key)
    local known = false
    for _, t in ipairs(self.tabList or {}) do if t[1] == key then known = true end end
    if not known then return end
    self.tab = key
    self:_UpdateTabs()
    self:Refresh()
    if self.content.SetVerticalScroll then self.content:SetVerticalScroll(0) end
    local sc = self.content.GetParent and self.content:GetParent()
    if sc and sc.SetVerticalScroll then pcall(sc.SetVerticalScroll, sc, 0) end
end

function Page:GetTab() return self.tab end
