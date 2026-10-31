-- Peon_Ledger - Window.lua
-- Ledger-Fenster (Bauabschnitt L2) im Stil des Broker-Fensters: Rahmen wie das Auktionshaus, Reiter unten.
-- Reiter ab 0.2: Uebersicht (Overview.lua), Bestand (Stock.lua); ab 0.3 Verlauf (History.lua); ab 0.4 Buch und Gegenstände (Book.lua). Oeffnen: /ledger, Minimap-Button. Escape schliesst.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local W = {}
ns.Window = W

W.WIDTH, W.HEIGHT = 760, 500   -- ab 0.7 breiter (Spalten Kosten, Gewinn, Lagerwert)
W.TOP = 64
W.TABS = {
    { key = "overview", label = "TAB_OVERVIEW" },
    { key = "stock",    label = "TAB_STOCK" },
    { key = "history",  label = "TAB_HISTORY" },
    { key = "book",     label = "TAB_BOOK" },
    { key = "items",    label = "TAB_SALES" },    -- ab 0.10 "Umsatz" (vorher "Gegenstaende")
    { key = "catalog",  label = "TAB_CATALOG" },  -- ab 0.10: alle bekannten Gegenstaende (Catalog.lua)
    { key = "item",     label = "TAB_ITEM" },     -- ab 0.9 (Item.lua)
}
W.pages = {}
W.QUALITY = { [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000" }

local function TryFrame(kind, name, parent, template)
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then return f end
    return nil
end

local function SavePosition(f)
    if not f.GetPoint then return end
    local point, _, rel, x, y = f:GetPoint(1)
    if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
    mod.db.windowPos = { point = point, rel = rel, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
end

function W.Inset(parent)
    local f = TryFrame("Frame", nil, parent, "InsetFrameTemplate")
    if not f then
        f = CreateFrame("Frame", nil, parent)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.4)
    end
    return f
end

local TAB_TEMPLATES = { { "PanelTabButtonTemplate", 3 }, { "CharacterFrameTabButtonTemplate", -15 } }

local function CreateTab(f, i, tab, prev)
    local b, gap
    for _, t in ipairs(TAB_TEMPLATES) do
        b = TryFrame("Button", "PeonLedgerFrameTab" .. i, f, t[1])
        if b then gap = t[2]; W.tabStyle = t[1]; break end
    end
    if not b then
        b = CreateFrame("Button", "PeonLedgerFrameTab" .. i, f, "UIPanelButtonTemplate")
        b:SetSize(112, 24)
        gap = 4
        W.tabStyle = "button"
    end
    if prev then b:SetPoint("LEFT", prev, "RIGHT", gap, 0) else b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 2) end
    b:SetText(L[tab.label])
    if W.tabStyle ~= "button" and PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, b, 0) end
    b.key = tab.key
    b:SetID(i)
    b:SetScript("OnClick", function() W.Select(tab.key) end)
    return b
end

function W.Create()
    if W.frame then return W.frame end
    local f = TryFrame("Frame", "PeonLedgerFrame", UIParent, "ButtonFrameTemplate")
    if f then
        if f.SetTitle then pcall(f.SetTitle, f, ("|c%sPeon|r Ledger"):format(Peon.COLOR)) end
        if f.SetPortraitToAsset then pcall(f.SetPortraitToAsset, f, "Interface\\Icons\\INV_Scroll_03") end
        if type(f.Inset) == "table" and f.Inset.Hide then f.Inset:Hide() end
    else
        f = CreateFrame("Frame", "PeonLedgerFrame", UIParent, "BackdropTemplate")
        if f.SetBackdrop then
            f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
                insets = { left = 6, right = 6, top = 6, bottom = 6 } })
        end
        local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -14)
        title:SetText(("|c%sPeon|r Ledger"):format(Peon.COLOR))
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
    end
    f:SetSize(W.WIDTH, W.HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition(self) end)
    W.tabButtons = {}
    local prev
    for i, tab in ipairs(W.TABS) do
        prev = CreateTab(f, i, tab, prev)
        W.tabButtons[i] = prev
    end
    local foot = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    foot:SetPoint("BOTTOMLEFT", 14, 9)
    foot:SetPoint("BOTTOMRIGHT", -14, 9)
    foot:SetJustifyH("LEFT")
    W.footer = foot
    W.contents = {}
    f:SetScript("OnShow", function() mod:Call("Fenster", W.Refresh) end)
    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "PeonLedgerFrame") end
    f:Hide()
    W.frame = f
    return f
end

local function MarkTab(b, on)
    if W.tabStyle ~= "button" and PanelTemplates_SelectTab and PanelTemplates_DeselectTab then
        pcall(on and PanelTemplates_SelectTab or PanelTemplates_DeselectTab, b)
    end
    if on then b:LockHighlight() else b:UnlockHighlight() end
end

function W.Place()
    local f = W.frame
    f:ClearAllPoints()
    local p = mod.db.windowPos
    if type(p) == "table" and type(p.point) == "string" and type(p.x) == "number" and type(p.y) == "number" then
        f:SetPoint(p.point, UIParent, type(p.rel) == "string" and p.rel or p.point, p.x, p.y)
    else
        f:SetPoint("CENTER")
    end
end

function W.Open(tab)
    W.Create()
    W.Place()
    W.Select(tab or W.current or mod.db.windowTab)
    W.frame:Show()
end

function W.Toggle(tab)
    if W.frame and W.frame:IsShown() then W.frame:Hide() else W.Open(tab) end
end

function W.IsOpen() return W.frame ~= nil and W.frame:IsShown() end

function W.Select(key)
    if not W.pages[key] then key = "overview" end
    W.current = key
    mod.db.windowTab = key
    for _, b in ipairs(W.tabButtons) do MarkTab(b, b.key == key) end
    for k, c in pairs(W.contents) do if k ~= key then c:Hide() end end
    local c = W.contents[key]
    if not c then
        c = CreateFrame("Frame", nil, W.frame)
        c:SetPoint("TOPLEFT", 12, -W.TOP)
        c:SetPoint("BOTTOMRIGHT", -12, 26)
        W.contents[key] = c
        W.pages[key].build(c)
    end
    c:Show()
    if W.frame:IsShown() then W.Refresh() end
end

function W.Refresh()
    if not W.frame then return end
    local total, n = ns.Inventory.TotalMoney()
    W.footer:SetText(L.FOOTER:format(ns.Realm(), n, ns.Money(total)))
    local page = W.current and W.pages[W.current]
    if page and page.refresh then page.refresh() end
end

-- Neue Daten (Bestand geaendert): offenes Fenster einmal je Bild auffrischen
function W.OnData()
    if not W.IsOpen() or W.pending then return end
    W.pending = true
    if C_Timer then
        C_Timer.After(0, function() W.pending = nil; mod:Call("Fenster", W.Refresh) end)
    else
        W.pending = nil
        W.Refresh()
    end
end

-- Hilfen fuer die Reiter
function W.Lower(s)
    return (tostring(s or ""):lower():gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"))
end

function W.Colored(name, quality)
    local c = W.QUALITY[quality or 1] or W.QUALITY[1]
    return "|c" .. c .. tostring(name) .. "|r"
end

function W.ClassColored(name, class)
    local cc = type(class) == "string" and rawget(_G, "RAID_CLASS_COLORS") and RAID_CLASS_COLORS[class]
    if type(cc) == "table" and type(cc.colorStr) == "string" then return "|c" .. cc.colorStr .. name .. "|r" end
    return name
end

function W.ShowItemTooltip(owner, id)
    if not GameTooltip or not id then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. id)
    if ok then GameTooltip:Show() else GameTooltip:Hide() end
end

-- Auswahlliste (ab 0.6): neue Menue-API (WowStyle1DropdownTemplate), sonst Knopf zum Durchschalten.
-- items = { { Wert, Text }, ... } oder Funktion; get/set lesen und schreiben den Wert
function W.Dropdown(parent, width, items, get, set)
    local function Items() return type(items) == "function" and items() or items end
    local dd
    local ok = pcall(function() dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate") end)
    if ok and dd and dd.SetupMenu then
        dd:SetWidth(width)
        dd:SetupMenu(function(owner, root)
            for _, it in ipairs(Items()) do
                root:CreateRadio(it[2], function() return get() == it[1] end, function() set(it[1]) end)
            end
        end)
        dd.Update = function() if dd.GenerateMenu then dd:GenerateMenu() end end
        return dd
    end
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b.Update = function()
        local v = get()
        for _, it in ipairs(Items()) do if it[1] == v then b:SetText(it[2]) end end
    end
    b:SetScript("OnClick", function()
        local list, v, idx = Items(), get(), 0
        for i, it in ipairs(list) do if it[1] == v then idx = i end end
        local nxt = list[idx % #list + 1]
        if nxt then set(nxt[1]); b.Update() end
    end)
    b.Update()
    return b
end

function W.Init() end
