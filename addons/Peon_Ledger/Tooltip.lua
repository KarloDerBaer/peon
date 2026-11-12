-- Peon_Ledger - Tooltip.lua
-- Ledger-Zeilen im Gegenstands-Tooltip. Ab 0.14.2 frei einstellbar wie bei Broker (Wunsch KarloDerBaer):
-- Bausteine mit Wann (immer / mit Umschalt / aus), Format und Reihenfolge, Vorlagen Schlank / Standard /
-- Ausfuehrlich. Standard: Bestand immer, Orte je Charakter, Kosten und zuletzt gezahlt mit Umschalt.
--   stock  Bestand        all = Summe mit Vornamen, sum = nur Summe, me = dieser Charakter, bagsbank = Taschen + Bank
--   chars  je Charakter   places = Orte (Taschen 5, Bank 15), total = nur Summe je Charakter
--   cost   Kosten         both = naechstes Stueck (Ø), next = naechstes Stueck, value = Lagerwert des Bestands
--   last   zuletzt gezahlt   price = Preis je Stueck, full = mit Menge, Quelle und Datum
--   sale   zuletzt verkauft  price, full
--   rate   Verkaufsquote (30 Tage)
-- Der erste sichtbare Baustein steht in der Kopfzeile ("Ledger · Bestand   48 (Mirel 43, Borin 5)").
-- Einstellung: PeonLedgerDB.tooltipLayout = { shifthint = "always"|"off", lines = { { key, when, fmt }, ... } }
-- Nur der aktuelle Realm.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local T = {}
ns.Tooltip = T

local COLOR = { 0.55, 0.78, 1 }      -- dezent hellblau wie Brokers "Behalten"
local GREY = { 0.75, 0.75, 0.75 }

T.WHEN = { "always", "shift", "off" }
T.BLOCKS = {
    { key = "stock", fmts = { "all", "sum", "me", "bagsbank" }, when = "always" },
    { key = "chars", fmts = { "places", "total" },              when = "shift" },
    { key = "cost",  fmts = { "both", "next", "value" },        when = "shift" },
    { key = "last",  fmts = { "price", "full" },                when = "shift" },
    { key = "sale",  fmts = { "price", "full" },                when = "off" },
    { key = "rate",  fmts = nil,                                when = "off" },
}
T.BLOCK = {}
for _, b in ipairs(T.BLOCKS) do T.BLOCK[b.key] = b end

function T.ItemID(link)
    if type(link) ~= "string" or Peon.IsSecret(link) then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- Vorname (Charaktere haben in Forever Vor- und Nachnamen)
function T.Short(name) return (tostring(name):match("^(%S+)")) or tostring(name) end

-- Orte als Text: "Taschen 5, Bank 15"
function T.PlacesText(places)
    local parts = {}
    for _, place in ipairs(ns.Inventory.PLACES) do
        if places[place] then parts[#parts + 1] = L["PLACE_" .. place:upper()] .. " " .. places[place] end
    end
    return table.concat(parts, ", ")
end

---------------------------------------------------------------------------
-- Einstellung
---------------------------------------------------------------------------
local function Valid(list, v)
    for _, x in ipairs(list or {}) do if x == v then return true end end
    return false
end

function T.Preset(name)
    local lay = { shifthint = "always", lines = {} }
    for _, b in ipairs(T.BLOCKS) do
        local when, fmt = b.when, b.fmts and b.fmts[1] or nil
        if name == "slim" then
            when = (b.key == "stock") and "always" or "off"
            if b.key == "stock" then fmt = "sum" end
        elseif name == "full" then
            when = "always"
            if b.key == "last" or b.key == "sale" then fmt = "full" end
        end
        lay.lines[#lay.lines + 1] = { key = b.key, when = when, fmt = fmt }
    end
    if name == "slim" then lay.shifthint = "off" end
    return lay
end

-- pruefen und ergaenzen: fehlende Bausteine hinten an (aus), unbekannte weg
function T.Normalize(lay)
    if type(lay) ~= "table" or type(lay.lines) ~= "table" then lay = T.Preset("standard") end
    if lay.shifthint ~= "always" and lay.shifthint ~= "off" then lay.shifthint = "always" end
    local seen, lines = {}, {}
    for _, l in ipairs(lay.lines) do
        local b = type(l) == "table" and T.BLOCK[l.key]
        if b and not seen[l.key] then
            seen[l.key] = true
            if not Valid(T.WHEN, l.when) then l.when = b.when end
            if b.fmts and not Valid(b.fmts, l.fmt) then l.fmt = b.fmts[1] end
            lines[#lines + 1] = l
        end
    end
    for _, b in ipairs(T.BLOCKS) do
        if not seen[b.key] then lines[#lines + 1] = { key = b.key, when = "off", fmt = b.fmts and b.fmts[1] or nil } end
    end
    lay.lines = lines
    return lay
end

function T.Layout()
    local lay = T.Normalize(mod.db.tooltipLayout)
    mod.db.tooltipLayout = lay
    return lay
end

function T.SetPreset(name) mod.db.tooltipLayout = T.Preset(name) end

-- Baustein eine Stelle nach oben (-1) oder unten (1). Rueckgabe true bei Erfolg
function T.Move(key, dir)
    local lines = T.Layout().lines
    for i, l in ipairs(lines) do
        if l.key == key then
            local j = i + dir
            if j < 1 or j > #lines then return false end
            lines[i], lines[j] = lines[j], lines[i]
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Daten und Text je Baustein
---------------------------------------------------------------------------
-- Daten eines Gegenstands: { total, me, bags, bank, chars = { { name, total, places } }, warband, next, avg,
--   value, last = { unit, n, src, t }, sale = {...}, rate, sold, back }
function T.Data(id)
    local c = ns.Inventory.Count(id)
    local d = { total = c.total, chars = c.chars, warband = c.warband, me = 0, bags = 0, bank = 0 }
    local me = ns.CharName()
    for _, ch in ipairs(c.chars) do
        if ch.name == me then d.me, d.bags, d.bank = ch.total, ch.places.bags or 0, ch.places.bank or 0 end
    end
    local info = ns.Cost and ns.Cost.Info(id, "*")
    if info then d.next, d.avg, d.value = ns.Cost.Info(id) and ns.Cost.Info(id).next or info.next, info.avg, info.value end
    d.last = ns.Last and ns.Last.Buy(id)
    d.sale = ns.Last and ns.Last.Sale(id)
    if ns.Book then d.rate, d.sold, d.back = ns.Book.SellRate(id) end
    return d
end

local function M(v) return ns.Money(math.floor((v or 0) + 0.5)) end
local function Src(src) return ns.Stock and ns.Stock.SourceText(src) or tostring(src) end

-- Zeilen eines Bausteins: Liste { left, right }, leer wenn nichts zu zeigen ist
function T.BlockLines(key, fmt, d)
    if key == "stock" then
        if (d.total or 0) <= 0 then return {} end
        local right
        if fmt == "sum" then right = tostring(d.total)
        elseif fmt == "me" then right = L.TT_STOCK_ME:format(d.me, d.total)
        elseif fmt == "bagsbank" then right = L.TT_STOCK_BB:format(d.bags, d.bank)
        else
            local parts = {}
            for i, ch in ipairs(d.chars) do
                if i > 3 then parts[#parts + 1] = "…"; break end
                parts[#parts + 1] = T.Short(ch.name) .. " " .. ch.total
            end
            if d.warband then parts[#parts + 1] = L.PLACE_WARBAND .. " " .. d.warband end
            right = L.TT_STOCK_ALL:format(d.total, table.concat(parts, ", "))
        end
        return { { L.TT_STOCK_LEFT, right } }
    elseif key == "chars" then
        local out = {}
        for _, ch in ipairs(d.chars) do
            out[#out + 1] = { "  " .. ch.name, fmt == "total" and tostring(ch.total) or T.PlacesText(ch.places), indent = true }
        end
        return out
    elseif key == "cost" then
        if not d.next and not d.value then return {} end
        local right
        if fmt == "next" then right = M(d.next)
        elseif fmt == "value" then right = M(d.value)
        else
            right = M(d.next)
            if d.avg and math.abs((d.avg or 0) - (d.next or 0)) >= 1 then right = right .. " (Ø " .. M(d.avg) .. ")" end
        end
        return { { fmt == "value" and L.TT_LAGER or L.TT_COST, right } }
    elseif key == "last" or key == "sale" then
        local x = key == "last" and d.last or d.sale
        if not x then return {} end
        local right = M(x.unit)
        if fmt == "full" then right = L.TT_LAST_TEXT:format(right, x.n or 1, Src(x.src), date("%d.%m.", x.t or 0)) end
        return { { key == "last" and L.TT_LAST_BUY or L.TT_LAST_SALE, right } }
    elseif key == "rate" then
        if not d.rate then return {} end
        return { { L.TT_RATE, L.TT_RATE_TEXT:format(math.floor(d.rate * 100 + 0.5), d.sold, d.sold + d.back) } }
    end
    return {}
end

-- Alle Zeilen fuer einen Gegenstand: Liste { left, right, head = true, indent } (erste = Kopfzeile)
function T.Lines(d, shift, lay)
    lay = lay or T.Layout()
    local out, hidden = {}, false
    for _, l in ipairs(lay.lines) do
        if l.when == "always" or (l.when == "shift" and shift) then
            for _, x in ipairs(T.BlockLines(l.key, l.fmt, d)) do out[#out + 1] = x end
        elseif l.when == "shift" and #T.BlockLines(l.key, l.fmt, d) > 0 then
            hidden = true
        end
    end
    if #out == 0 then
        if not hidden then return {} end
        out[1] = { "", "" }
    end
    local title = ("|c%sLedger|r"):format(Peon.COLOR)
    local first = out[1]
    if first.indent then
        table.insert(out, 1, { left = title, right = "", head = true })
    else
        first.left = title .. ((first[1] ~= "" and (" · " .. first[1])) or "")
        first.right = first[2]
        first.head = true
    end
    if hidden and not shift and lay.shifthint == "always" then
        out[1].left = (out[1].left or out[1][1]) .. " |cff777777" .. L.TT_SHIFT_HINT .. "|r"
    end
    return out
end

function T.AddLines(tooltip, link)
    if not mod.db or not mod.db.tooltipShow then return false end
    local id = T.ItemID(link)
    if not id then return false end
    local shift = IsShiftKeyDown and IsShiftKeyDown() and true or false
    local lines = T.Lines(T.Data(id), shift)
    if #lines == 0 then return false end
    for _, x in ipairs(lines) do
        if x.head then
            tooltip:AddDoubleLine(x.left, x.right or "", 1, 1, 1, COLOR[1], COLOR[2], COLOR[3])
        else
            local c = x.indent and GREY or COLOR
            tooltip:AddDoubleLine((x.indent and "  " or "  ") .. x[1], x[2] or "", GREY[1], GREY[2], GREY[3], c[1], c[2], c[3])
        end
    end
    return true
end

-- Vorschau auf der Optionsseite mit Beispielwerten
T.SAMPLE = {
    total = 48, me = 43, bags = 23, bank = 20, warband = nil,
    chars = { { name = "Mirel Dorna", total = 43, places = { bags = 23, bank = 20 } }, { name = "Borin Stein", total = 5, places = { bags = 5 } } },
    next = 210, avg = 245, value = 11760,
    last = { unit = 280, n = 20, src = "ah", t = 0 }, sale = { unit = 349, n = 46, src = "ah", t = 0 },
    rate = 0.67, sold = 4, back = 2,
}
function T.PreviewLines(shift, lay)
    local d = T.SAMPLE
    d.last.t, d.sale.t = time() - 86400, time() - 3600
    local out = {}
    for _, x in ipairs(T.Lines(d, shift, lay)) do
        local l = x.head and x.left or ("  " .. x[1])
        local r = x.head and (x.right or "") or (x[2] or "")
        out[#out + 1] = r ~= "" and (l .. "   |cff8cc7ff" .. r .. "|r") or l
    end
    if #out == 0 then out[1] = "|cff777777" .. L.TTO_EMPTY .. "|r" end
    return out
end

function T.OnItem(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= rawget(_G, "ItemRefTooltip") then return end
    if not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    if link == nil or Peon.IsSecret(link) then return end
    if T.AddLines(tooltip, link) and tooltip.Show then tooltip:Show() end
end

function T.Init()
    if T.hooked then return end
    T.hooked = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            mod:Call("Tooltip", T.OnItem, tooltip, data)
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", function(self)
            mod:Call("Tooltip", T.OnItem, self)
        end)
    end
    -- Umschalt waehrend der Tooltip offen ist: neu aufbauen (macht Broker schon, wenn geladen)
    if Peon.GetModule and Peon.GetModule("broker") then return end
    mod:RegisterEvent("MODIFIER_STATE_CHANGED", function(_, key)
        if type(key) ~= "string" or not key:find("SHIFT") then return end
        local tt = GameTooltip
        if tt and tt.IsShown and tt:IsShown() and tt.GetItem and tt.RefreshData then
            local _, link = tt:GetItem()
            if link then tt:RefreshData() end
        end
    end)
end

---------------------------------------------------------------------------
-- Optionsseite: Vorlagen, je Baustein Wann, Format, Reihenfolge, Vorschau (wie Brokers TooltipOptions.lua)
---------------------------------------------------------------------------
T.ROW = 26
T.WHEN_W, T.FMT_W = 140, 170

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
        for i, o in ipairs(l) do if o[1] == cur then set((l[i + 1] or l[1])[1]); return end end
        if l[1] then set(l[1][1]) end
    end)
    return b
end

local function WhenList() return { { "always", L.TTO_WHEN_ALWAYS }, { "shift", L.TTO_WHEN_SHIFT }, { "off", L.TTO_WHEN_OFF } } end
local function HintList() return { { "always", L.TTO_HINT_ON }, { "off", L.TTO_HINT_OFF } } end
local function FmtList(key)
    local out = {}
    for _, f in ipairs(T.BLOCK[key] and T.BLOCK[key].fmts or {}) do out[#out + 1] = { f, L["TTO_FMT_" .. key:upper() .. "_" .. f:upper()] or f } end
    return out
end

function T.OptChanged()
    if T.optC and T.optC.Refresh then T.optC.Refresh() end
    if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() and GameTooltip.RefreshData then pcall(GameTooltip.RefreshData, GameTooltip) end
end

function T.BuildOptions(page, col)
    local nb = #T.BLOCKS
    local c = page:NewContainer(70 + T.ROW + 22 + nb * T.ROW + 10)
    T.optC = c
    local pl = c:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pl:SetPoint("TOPLEFT", 0, 0)
    pl:SetText(L.TTO_PRESETS)
    T.presetButtons = {}
    local x = 0
    for _, p in ipairs({ { "slim", L.TTO_PRESET_SLIM }, { "standard", L.TTO_PRESET_STANDARD }, { "full", L.TTO_PRESET_FULL } }) do
        local b = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        b:SetSize(110, 22)
        b:SetPoint("TOPLEFT", x, -16)
        b:SetText(p[2])
        b:SetScript("OnClick", function() T.SetPreset(p[1]); T.OptChanged() end)
        T.presetButtons[p[1]] = b
        x = x + 116
    end
    local y = -50
    local hl = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hl:SetPoint("TOPLEFT", 8, y - 5)
    hl:SetText(L.TTO_SHIFTHINT)
    T.optHint = Dropdown(c, T.WHEN_W, HintList, function() return T.Layout().shifthint end, function(v) T.Layout().shifthint = v; T.OptChanged() end)
    T.optHint:SetPoint("TOPLEFT", 150, y)
    y = y - T.ROW
    local h2 = c:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    h2:SetPoint("TOPLEFT", 0, y - 4)
    h2:SetText(L.TTO_LINES)
    y = y - 22
    T.optRows = {}
    for i = 1, nb do
        local r = {}
        r.label = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        r.label:SetPoint("TOPLEFT", 8, y - 5)
        r.when = Dropdown(c, T.WHEN_W, WhenList,
            function() local l = T.Layout().lines[i]; return l and l.when end,
            function(v) local l = T.Layout().lines[i]; if l then l.when = v; T.OptChanged() end end)
        r.when:SetPoint("TOPLEFT", 150, y)
        r.fmt = Dropdown(c, T.FMT_W, function() local l = T.Layout().lines[i]; return l and FmtList(l.key) or {} end,
            function() local l = T.Layout().lines[i]; return l and l.fmt end,
            function(v) local l = T.Layout().lines[i]; if l then l.fmt = v; T.OptChanged() end end)
        r.fmt:SetPoint("TOPLEFT", 150 + T.WHEN_W + 6, y)
        r.up = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        r.up:SetSize(24, 22)
        r.up:SetPoint("TOPLEFT", 150 + T.WHEN_W + T.FMT_W + 12, y)
        r.up:SetText("^")
        r.up:SetScript("OnClick", function() local l = T.Layout().lines[i]; if l and T.Move(l.key, -1) then T.OptChanged() end end)
        r.down = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        r.down:SetSize(24, 22)
        r.down:SetPoint("LEFT", r.up, "RIGHT", 2, 0)
        r.down:SetText("v")
        r.down:SetScript("OnClick", function() local l = T.Layout().lines[i]; if l and T.Move(l.key, 1) then T.OptChanged() end end)
        T.optRows[i] = r
        y = y - T.ROW
    end
    -- Vorschau rechts
    local px = 150 + T.WHEN_W + T.FMT_W + 70
    local ph = c:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    ph:SetPoint("TOPLEFT", px, -50)
    ph:SetText(L.TTO_PREVIEW)
    T.previewShift = false
    local toggle = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    toggle:SetSize(170, 20)
    toggle:SetPoint("TOPLEFT", px, -66)
    toggle:SetScript("OnClick", function() T.previewShift = not T.previewShift; T.OptChanged() end)
    local box = CreateFrame("Frame", nil, c, "BackdropTemplate")
    box:SetPoint("TOPLEFT", px, -92)
    box:SetSize(260, 170)
    if box.SetBackdrop then
        pcall(box.SetBackdrop, box, { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        pcall(box.SetBackdropColor, box, 0, 0, 0, 0.9)
    end
    local text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 10, -10)
    text:SetPoint("RIGHT", box, "RIGHT", -10, 0)
    text:SetJustifyH("LEFT")
    if text.SetSpacing then text:SetSpacing(3) end
    T.preview = text
    c.Refresh = function()
        local lay = T.Layout()
        if T.optHint.Refresh then T.optHint.Refresh() end
        for i, r in ipairs(T.optRows) do
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
        toggle:SetText(T.previewShift and L.TTO_PREVIEW_SHIFT or L.TTO_PREVIEW_NORMAL)
        text:SetText(table.concat(T.PreviewLines(T.previewShift, lay), "\n"))
    end
    page:Add(col, c, 16)
    return c
end
