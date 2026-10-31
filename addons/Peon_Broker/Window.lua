-- Peon_Broker - Window.lua
-- Broker-Fenster mit Reitern (Bauabschnitt 4), ab 0.9 im Stil des Auktionshauses (Reiter unten). Dockt bei geoeffnetem Auktionshaus rechts an,
-- sonst frei verschiebbar (Position wird gemerkt). Oeffnen: /broker, Minimap-Button, Knopf "Broker"
-- unter dem Auktionshausfenster. Escape schliesst.
--
-- Reiter: Start (ab 0.24), Verkaufen, Behalten, Meine Auktionen, Einkaufsliste, Radar (ab 0.14), Preise. Der Reiter "Buch"
-- entfaellt ab 0.22 (Buch in Peon_Ledger).
-- Stand 0.13: Verkaufen, Behalten, Meine Auktionen, Einkaufen (Buy.lua), Preise; das Buch ist sichtbar,
-- aber gesperrt ("folgt").

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local W = {}
ns.Window = W

W.WIDTH, W.HEIGHT = 680, 540
W.TOP = 64            -- Abstand der Reiter-Inhalte vom oberen Rand (Platz fuer Symbol und Titel)
W.TABS = {
    { key = "start",    label = "TAB_START" },      -- ab 0.24: Was steht an?
    { key = "sell",     label = "TAB_SELL" },
    { key = "keep",     label = "TAB_KEEP" },
    { key = "auctions", label = "TAB_AUCTIONS" },
    { key = "buy",      label = "TAB_BUY" },
    { key = "radar",    label = "TAB_RADAR" },
    { key = "prices",   label = "TAB_PRICES" },
}
W.pages = {}          -- key -> { build = fn(content), refresh = fn() }

-- Farben der Qualitaetsstufen (Grau, Weiss, Gruen, Blau, Lila, Orange)
W.QUALITY = { [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000" }

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local function SavePosition(f)
    if not f.GetPoint then return end
    local point, _, rel, x, y = f:GetPoint(1)
    if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
    mod.db.windowPos = { point = point, rel = rel, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
end

-- Vorlage des Spiels versuchen, sonst nil (Forever kann Vorlagen umbenennen)
local function TryFrame(kind, name, parent, template)
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then return f end
    return nil
end

-- Eigener Rahmen, falls die Blizzard-Vorlage fehlt
local function PlainBackdrop(f)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
    end
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText(("|c%sPeon|r Broker"):format(Peon.COLOR))
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
end

-- Dunkles Innenfeld wie im Auktionshaus (fuer Spalten der Reiter)
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

-- Reiter unten wie im Auktionshaus
local TAB_TEMPLATES = { { "PanelTabButtonTemplate", 3 }, { "CharacterFrameTabButtonTemplate", -15 } }

local function CreateTab(f, i, tab, prev)
    local b, gap
    for _, t in ipairs(TAB_TEMPLATES) do
        b = TryFrame("Button", "PeonBrokerFrameTab" .. i, f, t[1])
        if b then gap = t[2]; W.tabStyle = t[1]; break end
    end
    if not b then
        b = CreateFrame("Button", "PeonBrokerFrameTab" .. i, f, "UIPanelButtonTemplate")
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
    b:SetScript("OnEnter", function(self)
        if W.pages[tab.key] or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L[tab.label], 1, 1, 1)
        GameTooltip:AddLine(L.TAB_LATER, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    if not W.pages[tab.key] then b:Disable() end
    return b
end

function W.Create()
    if W.frame then return W.frame end
    -- Rahmen wie das Auktionshaus (ButtonFrameTemplate), sonst eigener Rahmen
    local f = TryFrame("Frame", "PeonBrokerFrame", UIParent, "ButtonFrameTemplate")
    if f then
        W.style = "blizzard"
        if f.SetTitle then pcall(f.SetTitle, f, ("|c%sPeon|r Broker"):format(Peon.COLOR)) end
        if f.SetPortraitToAsset then pcall(f.SetPortraitToAsset, f, "Interface\\Icons\\INV_Misc_Coin_02") end
        if type(f.Inset) == "table" and f.Inset.Hide then f.Inset:Hide() end
    else
        f = CreateFrame("Frame", "PeonBrokerFrame", UIParent, "BackdropTemplate")
        W.style = "plain"
        PlainBackdrop(f)
    end
    f:SetSize(W.WIDTH, W.HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not W.docked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not W.docked then SavePosition(self) end
    end)

    -- Reiter
    W.tabButtons = {}
    local prev
    for i, tab in ipairs(W.TABS) do
        prev = CreateTab(f, i, tab, prev)
        W.tabButtons[i] = prev
    end

    -- Fusszeile: Markt und letzter Scan
    local foot = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    foot:SetPoint("BOTTOMLEFT", 14, 9)
    foot:SetPoint("BOTTOMRIGHT", -14, 9)
    foot:SetJustifyH("LEFT")
    W.footer = foot

    W.contents = {}
    f:SetScript("OnShow", function() mod:Call("Fenster", W.Refresh) end)
    f:SetScript("OnHide", function() W.docked = false; W.Leave(nil) end)
    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "PeonBrokerFrame") end   -- Escape schliesst
    f:Hide()
    W.frame = f
    return f
end

-- Reiter optisch waehlen (Blizzard-Funktionen, sonst Hervorhebung)
local function MarkTab(b, on)
    if W.tabStyle ~= "button" and PanelTemplates_SelectTab and PanelTemplates_DeselectTab then
        pcall(on and PanelTemplates_SelectTab or PanelTemplates_DeselectTab, b)
        if not W.pages[b.key] then b:Disable() end
    end
    if on then b:LockHighlight() else b:UnlockHighlight() end
end

-- Andocken ans Auktionshaus oder an die gemerkte Stelle
function W.Place()
    local f = W.frame
    f:ClearAllPoints()
    local ah = rawget(_G, "AuctionHouseFrame")
    if ns.Scan.ahOpen and ah and (not ah.IsShown or ah:IsShown()) then
        f:SetPoint("TOPLEFT", ah, "TOPRIGHT", 4, 0)
        W.docked = true
        return
    end
    W.docked = false
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
    -- am Auktionshaus standardmaessig "Start" (ab 0.24; vorher "Verkaufen"), sonst der zuletzt gewaehlte Reiter
    if not tab and W.docked and W.pages.start then tab = "start" end
    W.Select(tab or W.current or mod.db.windowTab)
    W.frame:Show()
end

function W.Toggle(tab)
    if W.frame and W.frame:IsShown() then W.frame:Hide() else W.Open(tab) end
end

function W.IsOpen() return W.frame ~= nil and W.frame:IsShown() end

-- Reiter waehlen (gesperrte Reiter werden uebersprungen)
-- Den bisherigen Reiter verlassen (z. B. Radar-Scan anhalten); next = neuer Reiter oder nil (Fenster zu)
function W.Leave(next)
    local cur = W.current
    if cur and cur ~= next and W.pages[cur] and W.pages[cur].leave then
        mod:Call("Fenster", W.pages[cur].leave)
    end
end

-- Blizzard-Auktionshaus auf eine Ansicht umschalten (ab 0.20): "Buy", "ItemSell", "Auctions" ...
-- (AuctionHouseFrameDisplayMode; SetDisplayMode stellt auch Blizzards Reiter um). Nur bei offenem Auktionshaus.
function W.SetAHMode(name)
    local f, modes = rawget(_G, "AuctionHouseFrame"), rawget(_G, "AuctionHouseFrameDisplayMode")
    if not (ns.Scan.ahOpen and type(f) == "table" and type(modes) == "table" and modes[name]) then return false end
    if type(f.SetDisplayMode) ~= "function" then return false end
    if type(f.GetDisplayMode) == "function" then
        local ok, m = pcall(f.GetDisplayMode, f)
        if ok and m == modes[name] then return true end
    end
    local ok = pcall(f.SetDisplayMode, f, modes[name])
    mod:Dbg("Auktionshaus-Ansicht " .. name .. ": " .. tostring(ok))
    return ok
end

function W.Select(key)
    if not W.pages[key] then key = "prices" end
    W.Leave(key)
    local changed = W.current ~= key or not (W.frame and W.frame:IsShown())
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
    -- Reiter neu gewaehlt: Blizzard-Fenster passend umschalten (ab 0.20)
    if changed and W.pages[key].enter then mod:Call("Fenster", W.pages[key].enter) end
end

function W.Refresh()
    if not W.frame then return end
    local market = ns.Data.Market()
    local text = L.MM_MARKET:format(ns.MarketKey())
    if market and market.lastScan then
        text = text .. "   ·   " .. L.MM_SCAN:format(ns.Scan.Age(market.lastScan), market.lastItems or 0)
    else
        text = text .. "   ·   " .. L.MM_NO_SCAN
    end
    W.footer:SetText(text)
    local page = W.current and W.pages[W.current]
    if page and page.refresh then page.refresh() end
end

---------------------------------------------------------------------------
-- Hilfen fuer die Reiter
---------------------------------------------------------------------------
-- Kleinschreibung auch fuer Umlaute (string.lower kennt nur A-Z)
function W.Lower(s)
    return (tostring(s or ""):lower():gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"))
end

function W.Colored(name, quality)
    local c = W.QUALITY[quality or 1] or W.QUALITY[1]
    return "|c" .. c .. name .. "|r"
end

-- Gegenstand im Tooltip zeigen (mit den Broker-Zeilen)
function W.ShowItemTooltip(owner, key)
    local link = ns.Data.LinkFromKey(key)
    if not link or not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    if ok then GameTooltip:Show() else GameTooltip:Hide() end
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
-- Knopf "Broker" links neben dem Scan-Knopf unter dem Auktionshausfenster
function W.CreateAHButton()
    if W.ahButton then return end
    local parent = rawget(_G, "AuctionHouseFrame")
    if not parent then return end
    local b = CreateFrame("Button", "PeonBrokerWindowButton", parent, "UIPanelButtonTemplate")
    b:SetSize(90, 22)
    b:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 2, -2)
    b:SetText(L.WINDOW_BUTTON)
    b:SetScript("OnClick", function() mod:Call("Fenster", W.Toggle) end)
    W.ahButton = b
end

function W.Init()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function()
        W.CreateAHButton()
        if W.IsOpen() then
            W.Place()                                     -- schon offen: ans Auktionshaus andocken
        elseif mod.db.windowWithAH then
            W.Open()
        end
    end)
    mod:RegisterEvent("AUCTION_HOUSE_CLOSED", function()
        if W.IsOpen() and W.docked then W.frame:Hide() end   -- angedockt: schliesst mit dem Auktionshaus
    end)
    mod:On("SCAN_DONE", function() if W.IsOpen() then W.Refresh() end end)
    mod:On("CHANGED", function() if W.IsOpen() then W.Refresh() end end)
end
