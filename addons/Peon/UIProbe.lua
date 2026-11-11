-- Peon - UIProbe.lua
-- Ab 0.18.0: Pruefbefehl fuer das UI-Design (/peon ui pruefen). Liest aus, was Blizzards Fenster in WoW Forever
-- wirklich zeigen: Grafiken (Atlas, Datei, Ausschnitt, Farbe), Groessen, Anker und Schriften. Grund: In Broker
-- 0.56 bis 0.58 wurden Grafiken nach dem Code geraten, Forever ("Camelot") hat aber unter denselben Atlas-Namen
-- teils eigene Grafiken. Das Ergebnis landet in PeonDB.uiProbe und nach /reload in WTF (SavedVariables\Peon.lua).
-- Nur lesen: Blizzards Rahmen werden nicht veraendert. Fuer Vorlagen legt die Pruefung eigene, versteckte Rahmen an.

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local L = ns.L

local P = {}
ns.UIProbe = P

P.MAX_LINES = 2500     -- je Fenster
P.MAX_DEPTH = 9
P.TEXT_LEN  = 40

-- Blizzard-Fenster, die ohne Angabe geprueft werden, sobald sie sichtbar sind
P.FRAMES = {
    "AuctionHouseFrame", "ProfessionsFrame", "SettingsPanel", "CharacterFrame", "PVEFrame", "CollectionsJournal",
    "EncounterJournal", "MerchantFrame", "MailFrame", "BankFrame", "FriendsFrame", "AddonList", "GameMenuFrame",
    "PlayerSpellsFrame", "SpellBookFrame", "WorldMapFrame", "ContainerFrameCombinedBags", "ItemTextFrame",
    "GossipFrame", "QuestFrame", "LootFrame", "TradeFrame", "GuildBankFrame", "ProfessionsCustomerOrdersFrame",
}

-- Atlas-Namen aus Blizzards Code (Zweig forever): Auktionshaus, Vorlagen, Rahmen, moderne Bedienelemente
P.ATLASES = {
    "auctionhouse-background-categories", "auctionhouse-background-index", "auctionhouse-background-sell-left",
    "auctionhouse-background-sell-right", "auctionhouse-background-summarylist", "auctionhouse-background-auctions",
    "auctionhouse-background-buy-commodities", "auctionhouse-background-buy-commodities-market",
    "auctionhouse-background-buy-noncommodities-header", "auctionhouse-background-buy-noncommodities-market",
    "auctionhouse-nav-button", "auctionhouse-nav-button-highlight", "auctionhouse-nav-button-select",
    "auctionhouse-nav-button-secondary", "auctionhouse-nav-button-secondary-highlight",
    "auctionhouse-nav-button-secondary-select", "auctionhouse-nav-button-tertiary-filterline",
    "auctionhouse-rowstripe-1", "auctionhouse-rowstripe-2", "auctionhouse-ui-row-highlight", "auctionhouse-ui-row-select",
    "auctionhouse-ui-sortarrow", "auctionhouse-itemheaderframe", "auctionhouse-selltab-left",
    "auctionhouse-selltab-middle", "auctionhouse-selltab-right", "auctionhouse-itemicon-small-border",
    "auctionhouse-icon-favorite", "auctionhouse-icon-favorite-off", "auctionhouse-icon-checkmark",
    "auctionhouse-ui-filter-redx", "auctionhouse-ui-inputfield-left", "auctionhouse-ui-inputfield-middle",
    "auctionhouse-ui-inputfield-right",
    "common-insideframe", "Profession-Background-Template2", "Profession-Background-Overview",
    "UI-Frame-Metal-CornerTopLeft", "UI-Frame-Metal-CornerTopRight", "UI-Frame-Metal-CornerTopRightDouble",
    "UI-Frame-Metal-CornerBottomLeft", "UI-Frame-Metal-CornerBottomRight", "_UI-Frame-Metal-EdgeTop",
    "_UI-Frame-Metal-EdgeBottom", "!UI-Frame-Metal-EdgeLeft", "!UI-Frame-Metal-EdgeRight",
    "UI-Frame-PortraitMetal-CornerTopLeft", "UI-Frame-SimpleMetal-CornerTopLeft", "_UI-Frame-SimpleMetal-EdgeTop",
    "UI-Frame-DiamondMetal-CornerTopLeft", "UI-Frame-DiamondMetal-Header-CornerLeft", "_UI-Frame-DiamondMetal-Header-Tile",
    "UI-Frame-GenericMetal-Corner", "_UI-Frame-GenericMetal-EdgeTop",
    "UI-Frame-InnerTopLeft", "UI-Frame-InnerTopRight", "UI-Frame-InnerBotLeftCorner", "UI-Frame-InnerBotRight",
    "_UI-Frame-InnerTopTile", "_UI-Frame-InnerBotTile", "!UI-Frame-InnerLeftTile", "!UI-Frame-InnerRightTile",
    "GeneralFrame-InsetFrame-TopLeft", "GeneralFrame-InsetFrame-TopRight", "_GeneralFrame-InsetFrame-Top",
    "UI-Frame-Portrait", "_UI-Frame-TitleTileBg",
    "uiframe-tab-left", "uiframe-tab-right", "_uiframe-tab-center", "uiframe-activetab-left", "uiframe-activetab-right",
    "_uiframe-activetab-center",
    "Tooltip-NineSlice-CornerTopLeft", "Tooltip-NineSlice-Center", "_Tooltip-NineSlice-EdgeTop",
    "checkbox-minimal", "checkmark-minimal", "checkmark-minimal-disabled",
    "Minimal_SliderBar_Left", "_Minimal_SliderBar_Middle", "Minimal_SliderBar_Right", "Minimal_SliderBar_Button",
    "Minimal_SliderBar_Button_Left", "Minimal_SliderBar_Button_Right",
    "minimal-scrollbar-track-top", "!minimal-scrollbar-track-middle", "minimal-scrollbar-track-bottom",
    "minimal-scrollbar-small-thumb-top", "minimal-scrollbar-small-thumb-middle", "minimal-scrollbar-small-thumb-bottom",
    "common-dropdown-bg", "common-dropdown-a-button", "common-dropdown-b-button", "common-dropdown-textholder",
    "common-search-border-left", "common-search-border-middle", "common-search-border-right",
    "common-search-magnifyingglass", "common-search-clearbutton", "common-searchbar-a",
    "common-gray-button-entrybox-left", "common-gray-button-entrybox-center", "common-gray-button-entrybox-right",
    "common-button-square-gray-up", "common-button-square-gray-down", "common-slider-thumb", "common-slider-track",
    "common-sidetab", "common-sidetab-hover", "common-sidetab-selected",
    "RedButton-Exit", "RedButton-Highlight", "128-RedButton-Left", "128-RedButton-Center", "128-RedButton-Right",
    "128-GoldRedButton-Left", "Spinner_Ring", "search-highlight", "_search-rowbg", "perks-divider",
    "Options_ListExpand_Right", "Options_HorizontalDivider", "UI-Character-Info-Title",
    "ui-castingbar-background", "ui-castingbar-filling-applyingcrafting", "ui-castingbar-full-applyingcrafting",
    "ui-castingbar-frame", "ui-castingbar-pip",
}

-- Schrift-Objekte, die Blizzards moderne Fenster nutzen
P.FONTS = {
    "GameFontNormal", "GameFontHighlight", "GameFontDisable", "GameFontNormalSmall", "GameFontHighlightSmall",
    "GameFontDisableSmall", "GameFontNormalMed1", "GameFontNormalMed2", "GameFontNormalMed3", "GameFontHighlightMed2",
    "GameFontNormalLarge", "GameFontHighlightLarge", "GameFontNormalHuge", "GameFontNormalHuge2", "GameFontRed",
    "GameFontGreen", "GameFontNormalSmall2", "GameFontHighlightSmall2", "GameFontDisableLarge",
    "Number12Font", "Number13FontWhite", "Number14FontWhite", "Number15FontWhite", "NumberFontNormal",
    "NumberFont_Normal_Med", "SystemFont_Shadow_Med1", "SystemFont_Shadow_Large", "SystemFont_Shadow_Large2",
    "SystemFont_Med1", "SystemFont_Small", "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall",
    "QuestFont", "Fancy16Font", "Game15Font_o1", "Game13FontShadow", "PriceFont",
}

-- Vorlagen, die als eigener, versteckter Rahmen angelegt werden (Typ laut Blizzards XML)
P.TEMPLATES = {
    { "Frame", "PortraitFrameTemplate" }, { "Frame", "ButtonFrameTemplate" }, { "Frame", "PortraitFrameFlatTemplate" },
    { "Frame", "BasicFrameTemplate" }, { "Frame", "DefaultPanelTemplate" }, { "Frame", "DefaultPanelFlatTemplate" },
    { "Frame", "InsetFrameTemplate" }, { "Frame", "DialogBorderTemplate" }, { "Frame", "TooltipBackdropTemplate" },
    { "Frame", "ThinGoldEdgeTemplate" }, { "Frame", "SpinnerTemplate" }, { "Frame", "LoadingSpinnerTemplate" },
    { "Button", "UIPanelButtonTemplate" }, { "Button", "UIPanelGoldButtonTemplate" },
    { "Button", "UIPanelDynamicResizeButtonTemplate" }, { "Button", "UIPanelCloseButtonDefaultAnchors" },
    { "Button", "RefreshButtonTemplate" }, { "Button", "SquareIconButtonTemplate" },
    { "Button", "PanelTabButtonTemplate" }, { "Button", "PanelTopTabButtonTemplate" }, { "Button", "MinimalTabTemplate" },
    { "Frame", "LargeSideTabButtonTemplate" }, { "Button", "ColumnDisplayButtonShortTemplate" },
    { "CheckButton", "UICheckButtonTemplate" }, { "CheckButton", "MinimalCheckboxTemplate" },
    { "CheckButton", "SettingsCheckboxTemplate" },
    { "EditBox", "InputBoxTemplate" }, { "EditBox", "LargeInputBoxTemplate" }, { "EditBox", "SearchBoxTemplate" },
    { "EditBox", "InputBoxInstructionsTemplate" }, { "EditBox", "NumericInputSpinnerTemplate" },
    { "Slider", "MinimalSliderTemplate" }, { "Frame", "MinimalSliderWithSteppersTemplate" },
    { "Slider", "OptionsSliderTemplate" },
    { "DropdownButton", "WowStyle1DropdownTemplate" }, { "DropdownButton", "WowStyle1FilterDropdownTemplate" },
    { "DropdownButton", "WowStyle2DropdownTemplate" },
    { "EventFrame", "MinimalScrollBar" }, { "EventFrame", "WowTrimScrollBar" }, { "EventFrame", "WowClassicScrollBar" },
}

---------------------------------------------------------------------------
-- Hilfen
---------------------------------------------------------------------------
-- Methode geschuetzt aufrufen (hoechstens 8 Rueckgabewerte, nie fuer GetChildren/GetRegions)
local function M(obj, name, ...)
    if type(obj) ~= "table" then return nil end
    local fn = obj[name]
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, obj, ...)
    if not ok then return nil end
    return a, b, c, d, e, f, g, h
end

local function N(v)
    if type(v) ~= "number" or Peon.IsSecret(v) then return tostring(v) end
    local s = ("%.2f"):format(v)
    s = s:gsub("0+$", ""):gsub("%.$", "")
    return s
end

local function T(v)
    if v == nil then return "nil" end
    if Peon.IsSecret(v) then return L.SECRET end
    if type(v) == "number" then return N(v) end
    local s = tostring(v)
    if #s > P.TEXT_LEN then s = s:sub(1, P.TEXT_LEN) .. "…" end
    return (s:gsub("|", "||"):gsub("\n", " "))
end

-- Datei oder Name ungekuerzt
local function F(v)
    if v == nil then return "nil" end
    if Peon.IsSecret(v) then return L.SECRET end
    return (tostring(v):gsub("|", "||"))
end

local function Name(obj)
    if type(obj) ~= "table" then return tostring(obj) end
    local n = M(obj, "GetDebugName")
    if type(n) ~= "string" or n == "" or Peon.IsSecret(n) then n = M(obj, "GetName") end
    if type(n) ~= "string" or n == "" or Peon.IsSecret(n) then n = "?" end
    return n
end

-- Name relativ zum geprueften Fenster kuerzen
local function Short(name, root)
    if root and root ~= "" and name:sub(1, #root) == root then
        local rest = name:sub(#root + 1)
        return rest == "" and "." or rest
    end
    return name
end

local function Color(r, g, b, a)
    if type(r) ~= "number" then return nil end
    if r == 1 and g == 1 and b == 1 and (a == nil or a == 1) then return nil end
    return N(r) .. "," .. N(g) .. "," .. N(b) .. (a and a ~= 1 and ("," .. N(a)) or "")
end

local function Points(obj, root)
    local n = M(obj, "GetNumPoints")
    if type(n) ~= "number" or n == 0 then return "" end
    local out = {}
    for i = 1, math.min(n, 4) do
        local p, rel, rp, x, y = M(obj, "GetPoint", i)
        if p then
            local rn = rel and Short(Name(rel), root) or "-"
            out[#out + 1] = ("%s>%s:%s(%s,%s)"):format(tostring(p), rn, tostring(rp), N(x or 0), N(y or 0))
        end
    end
    return " @" .. table.concat(out, " ")
end

local function Size(obj)
    local w, h = M(obj, "GetSize")
    if type(w) ~= "number" then return "" end
    return " " .. N(w) .. "x" .. N(h)
end

---------------------------------------------------------------------------
-- Beschreibung einzelner Teile
---------------------------------------------------------------------------
function P.DescribeTexture(tex, root, label)
    local parts = { "TEX " .. (label or Short(Name(tex), root)) }
    local layer, sub = M(tex, "GetDrawLayer")
    if layer then parts[#parts + 1] = "layer=" .. tostring(layer) .. ":" .. tostring(sub or 0) end
    local atlas = M(tex, "GetAtlas")
    if type(atlas) == "string" and atlas ~= "" then parts[#parts + 1] = "atlas=" .. atlas end
    local file = M(tex, "GetTexture")
    if file ~= nil and file ~= "" then parts[#parts + 1] = "file=" .. F(file) end
    if not atlas or atlas == "" then
        local a, b, c, d, e, f, g, h = M(tex, "GetTexCoord")
        if type(a) == "number" and not (a == 0 and b == 0 and c == 0 and d == 1 and e == 1 and f == 0 and g == 1 and h == 1) then
            parts[#parts + 1] = ("tc=%s,%s,%s,%s,%s,%s,%s,%s"):format(N(a), N(b), N(c), N(d), N(e), N(f), N(g), N(h))
        end
    end
    local col = Color(M(tex, "GetVertexColor"))
    if col then parts[#parts + 1] = "col=" .. col end
    local alpha = M(tex, "GetAlpha")
    if type(alpha) == "number" and alpha ~= 1 then parts[#parts + 1] = "alpha=" .. N(alpha) end
    local blend = M(tex, "GetBlendMode")
    if blend and blend ~= "BLEND" then parts[#parts + 1] = "blend=" .. tostring(blend) end
    if M(tex, "GetHorizTile") then parts[#parts + 1] = "htile" end
    if M(tex, "GetVertTile") then parts[#parts + 1] = "vtile" end
    if M(tex, "IsShown") == false then parts[#parts + 1] = "hidden" end
    return table.concat(parts, " ") .. Size(tex) .. Points(tex, root)
end

function P.DescribeFont(fs, root, label)
    local parts = { "FONT " .. (label or Short(Name(fs), root)) }
    local obj = M(fs, "GetFontObject")
    local on = obj and M(obj, "GetName")
    if type(on) == "string" then parts[#parts + 1] = "obj=" .. on end
    local file, size, flags = M(fs, "GetFont")
    if file then parts[#parts + 1] = ("font=%s/%s/%s"):format(F(file), N(size), tostring(flags or "")) end
    local col = Color(M(fs, "GetTextColor"))
    if col then parts[#parts + 1] = "col=" .. col end
    local sx, sy = M(fs, "GetShadowOffset")
    if type(sx) == "number" and (sx ~= 0 or sy ~= 0) then parts[#parts + 1] = "shadow=" .. N(sx) .. "," .. N(sy) end
    local jh = M(fs, "GetJustifyH")
    if jh and jh ~= "CENTER" then parts[#parts + 1] = "j=" .. tostring(jh) end
    local text = M(fs, "GetText")
    if text ~= nil and text ~= "" then parts[#parts + 1] = "text=\"" .. T(text) .. "\"" end
    if M(fs, "IsShown") == false then parts[#parts + 1] = "hidden" end
    return table.concat(parts, " ") .. Size(fs) .. Points(fs, root)
end

-- Rahmen samt Kindern beschreiben. out = Zeilen, root = Name des geprueften Fensters (zum Kuerzen)
function P.DescribeFrame(f, out, root, depth, maxDepth)
    depth = depth or 0
    maxDepth = maxDepth or P.MAX_DEPTH
    if #out >= P.MAX_LINES then
        out.cut = true
        return
    end
    local pad = ("  "):rep(depth)
    local parts = { pad .. "FRAME " .. Short(Name(f), root), tostring(M(f, "GetObjectType") or "?") }
    if M(f, "IsShown") == false then parts[#parts + 1] = "hidden" end
    local lt = rawget(f, "layoutType")
    if type(lt) == "string" then parts[#parts + 1] = "layout=" .. lt end
    local ba = rawget(f, "backgroundAtlas")
    if type(ba) == "string" then parts[#parts + 1] = "bgAtlas=" .. ba end
    local strata = M(f, "GetFrameStrata")
    local level = M(f, "GetFrameLevel")
    if depth == 0 and strata then parts[#parts + 1] = "strata=" .. tostring(strata) .. ":" .. tostring(level) end
    local scale = M(f, "GetScale")
    if type(scale) == "number" and scale ~= 1 then parts[#parts + 1] = "scale=" .. N(scale) end
    local fo = M(f, "GetFontObject")
    local fon = fo and M(fo, "GetName")
    if type(fon) == "string" then parts[#parts + 1] = "fontObj=" .. fon end
    local nfo = M(f, "GetNormalFontObject")
    local nfon = nfo and M(nfo, "GetName")
    if type(nfon) == "string" then parts[#parts + 1] = "normalFont=" .. nfon end
    if M(f, "IsEnabled") == false then parts[#parts + 1] = "disabled" end
    out[#out + 1] = table.concat(parts, " ") .. Size(f) .. Points(f, root)

    -- benannte Grafiken von Knoepfen, Haken, Reglern, Balken
    local seen = {}
    for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture",
                         "GetCheckedTexture", "GetDisabledCheckedTexture", "GetThumbTexture", "GetStatusBarTexture" }) do
        local tex = M(f, g)
        if type(tex) == "table" then
            seen[tex] = true
            out[#out + 1] = pad .. "  " .. P.DescribeTexture(tex, root, g:sub(4))
        end
    end
    local fsBtn = M(f, "GetFontString")
    if type(fsBtn) == "table" then
        seen[fsBtn] = true
        out[#out + 1] = pad .. "  " .. P.DescribeFont(fsBtn, root, "FontString")
    end

    if depth >= maxDepth then return end
    local regions = { f:GetRegions() }
    for _, r in ipairs(regions) do
        if #out >= P.MAX_LINES then out.cut = true; break end
        if not seen[r] then
            local ot = M(r, "GetObjectType")
            if ot == "Texture" or ot == "MaskTexture" then
                out[#out + 1] = pad .. "  " .. P.DescribeTexture(r, root)
            elseif ot == "FontString" then
                out[#out + 1] = pad .. "  " .. P.DescribeFont(r, root)
            elseif ot == "Line" then
                out[#out + 1] = pad .. "  LINE " .. Short(Name(r), root) .. " col=" .. tostring(Color(M(r, "GetVertexColor")))
            end
        end
    end
    local children = { f:GetChildren() }
    for _, c in ipairs(children) do
        if #out >= P.MAX_LINES then out.cut = true; break end
        P.DescribeFrame(c, out, root, depth + 1, maxDepth)
    end
end

-- Pfad wie "AuctionHouseFrame.CategoriesList" aufloesen (nur lesen)
function P.Resolve(path)
    if type(path) ~= "string" or path == "" then return nil end
    local obj
    for part in path:gmatch("[^%.]+") do
        if obj == nil then obj = rawget(_G, part) else obj = type(obj) == "table" and rawget(obj, part) or nil end
        if obj == nil then return nil end
    end
    return type(obj) == "table" and obj or nil
end

---------------------------------------------------------------------------
-- Pruefungen
---------------------------------------------------------------------------
local function Store()
    if type(Peon.db) ~= "table" then return nil end
    local s = Peon.db.uiProbe
    if type(s) ~= "table" then s = {}; Peon.db.uiProbe = s end
    local _, build, _, toc = nil, nil, nil, nil
    if GetBuildInfo then _, build, _, toc = GetBuildInfo() end
    s.build, s.toc, s.at, s.peon = build, toc, time and time() or 0, Peon.version
    if type(s.frames) ~= "table" then s.frames = {} end
    return s
end

function P.Atlases()
    local out = {}
    local missing = 0
    local get = C_Texture and C_Texture.GetAtlasInfo
    for _, name in ipairs(P.ATLASES) do
        local info
        if get then
            local ok, i = pcall(get, name)
            if ok then info = i end
        end
        if type(info) == "table" then
            out[#out + 1] = ("%s file=%s name=%s %sx%s tc=%s,%s,%s,%s%s%s"):format(name, F(info.file), F(info.filename),
                N(info.width), N(info.height), N(info.leftTexCoord), N(info.rightTexCoord), N(info.topTexCoord),
                N(info.bottomTexCoord), info.tilesHorizontally and " htile" or "", info.tilesVertically and " vtile" or "")
        else
            missing = missing + 1
            out[#out + 1] = name .. " FEHLT"
        end
    end
    return out, missing
end

function P.Fonts()
    local out = {}
    for _, name in ipairs(P.FONTS) do
        local fo = rawget(_G, name)
        if type(fo) == "table" then
            local file, size, flags = M(fo, "GetFont")
            local line = ("%s font=%s/%s/%s"):format(name, F(file), N(size), tostring(flags or ""))
            local col = Color(M(fo, "GetTextColor"))
            if col then line = line .. " col=" .. col end
            local sx, sy = M(fo, "GetShadowOffset")
            if type(sx) == "number" and (sx ~= 0 or sy ~= 0) then
                line = line .. " shadow=" .. N(sx) .. "," .. N(sy) .. " shadowCol=" .. tostring(Color(M(fo, "GetShadowColor")))
            end
            out[#out + 1] = line
        else
            out[#out + 1] = name .. " FEHLT"
        end
    end
    return out
end

local holder
function P.Templates()
    local out = {}
    if not holder then
        holder = CreateFrame("Frame", nil, UIParent)
        holder:SetSize(600, 400)
        holder:SetPoint("CENTER")
        holder:Hide()
    end
    for i, t in ipairs(P.TEMPLATES) do
        local kind, tmpl = t[1], t[2]
        local name = "PeonUIProbe" .. i
        local f = rawget(_G, name)
        if not f then
            local ok, made = pcall(CreateFrame, kind, name, holder, tmpl)
            f = ok and made or nil
            if not ok then out[#out + 1] = "### " .. tmpl .. " FEHLT (" .. T(made) .. ")" end
        end
        if f then
            out[#out + 1] = "### " .. tmpl .. " (" .. kind .. ")"
            P.DescribeFrame(f, out, name, 0, 4)
        end
    end
    return out
end

-- Zeilengrenze genau einhalten (ein Rahmen schreibt seine Grafiken in einem Zug)
function P.Cut(out)
    local cut = out.cut or #out > P.MAX_LINES
    out.cut = nil
    if cut then
        for i = #out, P.MAX_LINES + 1, -1 do out[i] = nil end
        out[#out + 1] = "…"
    end
    return out
end

function P.Frame(path, maxDepth)
    local f = P.Resolve(path)
    if not f then return nil end
    local out = {}
    P.DescribeFrame(f, out, Name(f), 0, maxDepth)
    return P.Cut(out)
end

function P.Mouse()
    local f
    if GetMouseFoci then
        local foci = GetMouseFoci()
        f = type(foci) == "table" and foci[1] or nil
    elseif GetMouseFocus then
        f = GetMouseFocus()
    end
    if type(f) ~= "table" or f == WorldFrame then return nil end
    local out = { "Kette: " .. Name(f) }
    local p, n = M(f, "GetParent"), 0
    while type(p) == "table" and n < 12 do
        out[#out + 1] = "  in " .. Name(p) .. " " .. tostring(M(p, "GetObjectType")) .. Size(p)
        p, n = M(p, "GetParent"), n + 1
    end
    -- Grafik direkt unter der Maus (z. B. Hintergrund) wird oft vom Rahmen verdeckt: Rahmen samt Kindern ausgeben
    P.DescribeFrame(f, out, Name(f), 0, 4)
    return P.Cut(out), Name(f)
end

---------------------------------------------------------------------------
-- Befehl: /peon ui pruefen [maus | <Pfad> | leeren]
---------------------------------------------------------------------------
function P.Run(arg)
    arg = strtrim(arg or "")
    local low = arg:lower()
    if low == "leeren" or low == "clear" then
        if type(Peon.db) == "table" then Peon.db.uiProbe = nil end
        Peon.Print(L.UIPROBE_CLEARED)
        return
    end
    local s = Store()
    if not s then return end
    if low == "maus" or low == "mouse" then
        local out, name = P.Mouse()
        if not out then Peon.Print(L.UIPROBE_NO_MOUSE); return end
        s.mouse = s.mouse or {}
        table.insert(s.mouse, 1, { name = name, at = s.at, lines = out })
        while #s.mouse > 10 do table.remove(s.mouse) end
        Peon.Print(L.UIPROBE_MOUSE:format(name, #out))
        return
    end
    if arg ~= "" then
        local out = P.Frame(arg)
        if not out then Peon.Print(L.UIPROBE_NOT_FOUND:format(arg)); return end
        s.frames[arg] = { at = s.at, lines = out }
        Peon.Print(L.UIPROBE_FRAME:format(arg, #out))
        return
    end
    local missing
    s.atlas, missing = P.Atlases()
    s.fonts = P.Fonts()
    s.templates = P.Templates()
    local names = {}
    for _, fname in ipairs(P.FRAMES) do
        local f = rawget(_G, fname)
        if type(f) == "table" and M(f, "IsVisible") then
            local out = P.Frame(fname)
            if out then
                s.frames[fname] = { at = s.at, lines = out }
                names[#names + 1] = fname
            end
        end
    end
    Peon.Print(L.UIPROBE_DONE:format(#s.atlas, missing, #s.fonts, #s.templates,
        #names > 0 and table.concat(names, ", ") or L.UIPROBE_NONE))
    Peon.Print(L.UIPROBE_HINT)
end

-- /peon ui: Beispielfenster (UIDemo.lua), /peon ui pruefen [...]: Pruefung
function P.Slash(rest)
    local sub, arg = (rest or ""):match("^(%S*)%s*(.-)$")
    sub = (sub or ""):lower()
    if sub == "pruefen" or sub == "prüfen" or sub == "check" then
        P.Run(arg)
    elseif sub == "" and ns.UIDemo then
        ns.UIDemo.Toggle()
    else
        for _, line in ipairs(L.UIPROBE_HELP) do Peon.Print(line) end
    end
end
