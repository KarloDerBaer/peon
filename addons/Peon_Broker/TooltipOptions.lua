-- Peon_Broker - TooltipOptions.lua
-- Umbau U5 (ab 0.46, Konzept Abschnitt 6.3): Tooltip frei einstellen auf der Optionsseite.
--   Vorlagen Schlank / Standard / Ausfuehrlich, Zeile 1 (Format, Zeichen Einkaufsliste, Hinweis "(Umschalt)"),
--   je Baustein Wann (immer / mit Umschalt / aus), Format und Reihenfolge (Pfeile), daneben die Vorschau mit
--   Beispielwerten (gleiche Ausgabe wie der echte Tooltip, T.PreviewLines).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local O = {}
ns.TooltipOptions = O

O.ROW = 26
O.WHEN_W, O.FMT_W = 140, 170

local function T() return ns.Tooltip end

-- Auswahlliste (Blizzards neues Menue, sonst Knopf, der weiterschaltet)
local function Dropdown(parent, width, list, get, set)
    local ok, dd = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    if ok and dd and dd.SetupMenu then
        dd:SetWidth(width)
        dd:SetupMenu(function(_, root)
            for _, o in ipairs(list()) do
                root:CreateRadio(o[2], function() return get() == o[1] end, function() set(o[1]) end)
            end
        end)
        dd.Refresh = function() if dd.GenerateMenu then dd:GenerateMenu() end end
        return dd
    end
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b.Refresh = function()
        local cur = get()
        for _, o in ipairs(list()) do if o[1] == cur then b:SetText(o[2]) end end
    end
    b:SetScript("OnClick", function()
        local l, cur = list(), get()
        for i, o in ipairs(l) do
            if o[1] == cur then set((l[i + 1] or l[1])[1]); return end
        end
        if l[1] then set(l[1][1]) end
    end)
    return b
end

local function WhenList()
    return { { "always", L.TTO_WHEN_ALWAYS }, { "shift", L.TTO_WHEN_SHIFT }, { "off", L.TTO_WHEN_OFF } }
end

local function FmtList(key)
    local b = T().BLOCK[key]
    local out = {}
    for _, f in ipairs(b and b.fmts or {}) do out[#out + 1] = { f, L["TTO_FMT_" .. key:upper() .. "_" .. f:upper()] or f } end
    return out
end

function O.Changed()
    if O.c and O.c.Refresh then O.c.Refresh() end
    if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() and GameTooltip.RefreshData then pcall(GameTooltip.RefreshData, GameTooltip) end
end

function O.Build(page, col)
    local nb = #T().BLOCKS
    local height = 74 + 3 * O.ROW + nb * O.ROW + 10
    local c = page:NewContainer(height)
    O.c = c

    -- Vorlagen
    local pl = c:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pl:SetPoint("TOPLEFT", 0, 0)
    pl:SetText(L.TTO_PRESETS)
    local x = 0
    O.presets = {}
    for _, p in ipairs({ { "slim", L.TTO_PRESET_SLIM }, { "standard", L.TTO_PRESET_STANDARD }, { "full", L.TTO_PRESET_FULL } }) do
        local b = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        b:SetSize(110, 22)
        b:SetPoint("TOPLEFT", x, -16)
        b:SetText(p[2])
        b:SetScript("OnClick", function() T().SetPreset(p[1]); O.Changed() end)
        O.presets[p[1]] = b
        x = x + 116
    end

    -- Zeile 1
    local y = -50
    local h1 = c:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    h1:SetPoint("TOPLEFT", 0, y)
    h1:SetText(L.TTO_LINE1)
    y = y - 18
    local function Row(label, dd)
        local fs = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 8, y - 5)
        fs:SetText(label)
        dd:SetPoint("TOPLEFT", 150, y)
        y = y - O.ROW
        return fs
    end
    local valueList = function()
        return { { "both", L.TTO_FMT_VALUE_BOTH }, { "stack", L.TTO_FMT_VALUE_STACK }, { "unit", L.TTO_FMT_VALUE_UNIT } }
    end
    O.value = Dropdown(c, O.FMT_W, valueList, function() return T().Layout().value end, function(v) T().Layout().value = v; O.Changed() end)
    Row(L.TTO_VALUE, O.value)
    O.mark = Dropdown(c, O.WHEN_W, WhenList, function() return T().Layout().mark end, function(v) T().Layout().mark = v; O.Changed() end)
    Row(L.TTO_MARK, O.mark)
    O.shifthint = Dropdown(c, O.WHEN_W, WhenList, function() return T().Layout().shifthint end, function(v) T().Layout().shifthint = v; O.Changed() end)
    Row(L.TTO_SHIFTHINT, O.shifthint)

    -- Bausteine: Zeilen in der Reihenfolge der Einstellung (Inhalte werden bei Refresh neu verteilt)
    local h2 = c:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    h2:SetPoint("TOPLEFT", 0, y - 4)
    h2:SetText(L.TTO_LINES)
    y = y - 22
    O.rows = {}
    for i = 1, nb do
        local r = { i = i }
        r.label = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        r.label:SetPoint("TOPLEFT", 8, y - 5)
        r.when = Dropdown(c, O.WHEN_W, WhenList,
            function() local l = T().Layout().lines[i]; return l and l.when end,
            function(v) local l = T().Layout().lines[i]; if l then l.when = v; O.Changed() end end)
        r.when:SetPoint("TOPLEFT", 150, y)
        r.fmt = Dropdown(c, O.FMT_W, function() local l = T().Layout().lines[i]; return l and FmtList(l.key) or {} end,
            function() local l = T().Layout().lines[i]; return l and l.fmt end,
            function(v) local l = T().Layout().lines[i]; if l then l.fmt = v; O.Changed() end end)
        r.fmt:SetPoint("TOPLEFT", 150 + O.WHEN_W + 6, y)
        r.up = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        r.up:SetSize(24, 22)
        r.up:SetPoint("TOPLEFT", 150 + O.WHEN_W + O.FMT_W + 12, y)
        r.up:SetText("^")
        r.up:SetScript("OnClick", function() local l = T().Layout().lines[i]; if l and T().Move(l.key, -1) then O.Changed() end end)
        r.down = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        r.down:SetSize(24, 22)
        r.down:SetPoint("LEFT", r.up, "RIGHT", 2, 0)
        r.down:SetText("v")
        r.down:SetScript("OnClick", function() local l = T().Layout().lines[i]; if l and T().Move(l.key, 1) then O.Changed() end end)
        O.rows[i] = r
        y = y - O.ROW
    end

    -- Vorschau rechts neben der Liste
    local px = 150 + O.WHEN_W + O.FMT_W + 70
    local ph = c:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    ph:SetPoint("TOPLEFT", px, -50)
    ph:SetText(L.TTO_PREVIEW)
    O.previewShift = false
    local toggle = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    toggle:SetSize(170, 20)
    toggle:SetPoint("TOPLEFT", px, -66)
    toggle:SetScript("OnClick", function() O.previewShift = not O.previewShift; O.Changed() end)
    O.toggle = toggle
    local box = CreateFrame("Frame", nil, c, "BackdropTemplate")
    box:SetPoint("TOPLEFT", px, -92)
    box:SetSize(260, 220)
    if box.SetBackdrop then
        pcall(box.SetBackdrop, box, { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        pcall(box.SetBackdropColor, box, 0, 0, 0, 0.9)
    end
    local text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 10, -10)
    text:SetPoint("RIGHT", box, "RIGHT", -10, 0)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)
    O.preview = text

    c.Refresh = function()
        local lay = T().Layout()
        for _, dd in ipairs({ O.value, O.mark, O.shifthint }) do if dd.Refresh then dd.Refresh() end end
        for i, r in ipairs(O.rows) do
            local l = lay.lines[i]
            if l then
                r.label:SetText(L["TTO_BLOCK_" .. l.key:upper()] or l.key)
                r.when.Refresh()
                local hasFmt = #FmtList(l.key) > 0
                r.fmt:SetShown(hasFmt)
                if hasFmt then r.fmt.Refresh() end
                if i == 1 then r.up:Disable() else r.up:Enable() end
                if i == #lay.lines then r.down:Disable() else r.down:Enable() end
            end
        end
        toggle:SetText(O.previewShift and L.TTO_PREVIEW_SHIFT or L.TTO_PREVIEW_NORMAL)
        text:SetText(table.concat(T().PreviewLines(O.previewShift, lay), "\n"))
    end
    page:Add(col, c, 16)
    return c
end
