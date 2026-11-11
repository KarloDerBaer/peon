-- Peon_Broker - Window.lua
-- Neuaufbau N1 (ab 0.59, Konzept Peon_Broker_Neuaufbau.md, Abschnitt 3): ein Fenster in zwei Zustaenden.
--   * Unterwegs: Broker-Fenster mit Peon.UI (Kern-API 18), 800 x 538 wie das Auktionshaus, Reiter unten, Statuszeile.
--   * Am Auktionator: dieselben Seiten als Reiter in Blizzards Auktionshaus (AHTabs.lua). Das Broker-Fenster
--     oeffnet dort nicht, W.Open und W.Toggle waehlen stattdessen den Reiter im Auktionshaus.
-- Die Seiten (W.pages) werden einmal gebaut und haengen je nach Zustand im Fenster oder im Auktionshaus (W.Content).
-- Oeffnen: /broker, Minimap-Button, Peon_Panel. Escape schliesst.
--
-- Reiter: Markt, Verkaufen, Auktionen, Einkaufen, Radar, Fokus, Gegenstand, Mehr (KarloDerBaer, 11.11.2026).
-- Seiten: Markt (Market.lua), Auktionen (Pages.lua), Einkaufen (Buy.lua), Radar (Radar.lua), Fokus (Focus.lua),
-- Gegenstand (Item.lua), Mehr (unten).
-- Verkaufen ist unterwegs grau. Seiten in W.WIP zeigen noch den Hinweis "in Arbeit".

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local W = {}
ns.Window = W

W.WIDTH, W.HEIGHT = 800, 538
W.TOP = 64            -- Abstand der Seiten vom oberen Rand (Platz fuer Bild und Titel)
W.TOP_BAR = 30        -- Seiten mit oberer Leiste (Einkaufen) beginnen neben dem Bild
W.SIDE = 14           -- Abstand links und rechts
W.BOTTOM = 30         -- Abstand unten (Statuszeile)
W.TABS = {
    { key = "browse",   label = "TAB_BROWSE" },      -- Markt (am Auktionator Blizzards Kaufen)
    { key = "sell",     label = "TAB_SELL" },        -- Verkaufen (nur am Auktionator, Blizzards Seite)
    { key = "auctions", label = "NTAB_AUCTIONS" },   -- Auktionen
    { key = "buy",      label = "AHTAB_SHOP" },      -- Einkaufen
    { key = "radar",    label = "TAB_RADAR" },
    { key = "focus",    label = "NTAB_FOCUS" },
    { key = "prices",   label = "NTAB_ITEM" },       -- Gegenstand
    { key = "more",     label = "NTAB_MORE" },       -- Mehr: Haendler, Neutral, Datenlage
}
W.AH_ONLY = { sell = true }                          -- unterwegs grau
W.BAR = { buy = true }                               -- Seiten mit oberer Leiste neben dem Bild
W.DEFAULT = "prices"
W.pages = {}          -- key -> { build = fn(content), refresh = fn(), enter = fn(), leave = fn() }
W.contents = {}       -- key -> Rahmen der Seite

-- In Arbeit: Reiter, die nur einen Hinweis zeigen, bis ihr Bauabschnitt kommt (seit N6 keiner mehr)
W.WIP = {}

local function BuildWip(c)
    local t = c:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("CENTER", 0, 20)
    t:SetText(L.TAB_WIP)
    c.wipText = t
end

-- Farben der Qualitaetsstufen (Grau, Weiss, Gruen, Blau, Lila, Orange)
W.QUALITY = { [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000" }

function W.TabLabel(key)
    for _, t in ipairs(W.TABS) do if t.key == key then return L[t.label] or key end end
    return key
end

---------------------------------------------------------------------------
-- Seiten: einmal bauen, je nach Zustand ins Fenster oder ins Auktionshaus haengen
---------------------------------------------------------------------------
-- parent = Rahmen, an dem die Seite haengt. anchor = Fenster, nach dem sie sich ausrichtet (Broker-Fenster oder
-- Blizzards Auktionshaus). Beide Zustaende nutzen dieselben Abstaende, damit es wie ein Fenster aussieht.
function W.Content(key, parent, anchor)
    local c = W.contents[key]
    local new = c == nil
    if new then
        c = CreateFrame("Frame", nil, parent)
        W.contents[key] = c
    end
    if c.SetParent then c:SetParent(parent) end
    c.parent = parent
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", anchor, "TOPLEFT", W.SIDE, -(W.BAR[key] and W.TOP_BAR or W.TOP))
    c:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -W.SIDE, W.BOTTOM)
    if new then
        if W.WIP[key] then BuildWip(c) else W.pages[key].build(c) end
    end
    return c
end

-- Text der Statuszeile: Markt und Datenlage in einem Satz (Konzept Abschnitt 3)
function W.StatusText()
    local D, G = ns.Data, ns.Pages
    local key = ns.MarketKey()
    local m = D.Markets()[key]
    local parts = { G and G.MarketLabel(key) or tostring(key) }
    if type(m) == "table" and (m.lastScan or m.mgrAt) then
        if m.lastScan then parts[#parts + 1] = L.PG_SCAN:format(ns.Scan.Age(m.lastScan)) end
        if m.mgrAt then parts[#parts + 1] = (m.mgrSrc == "api" and L.PG_API or L.PG_MANAGER):format(ns.Scan.Age(m.mgrAt)) end
    else
        parts[#parts + 1] = L.ST_NO_DATA
    end
    if not ns.Scan.ahOpen then parts[#parts + 1] = L.ST_NOT_LIVE end
    return table.concat(parts, " · ")
end

-- Statuszeile fuellen (Fenster und Auktionshaus nutzen dieselbe Funktion)
function W.FillStatus(bar)
    if not bar then return end
    bar:SetText(W.StatusText())
    if bar.money and bar.money.SetAmount and GetMoney then
        local ok, money = pcall(GetMoney)
        if ok and type(money) == "number" and not Peon.IsSecret(money) then bar.money:SetAmount(money) end
    end
end

-- Statuszeile anlegen: Klick oeffnet Mehr > Datenlage
function W.NewStatus(parent)
    local bar = Peon.UI.StatusBar(parent)
    if bar.EnableMouse then bar:EnableMouse(true) end
    bar:SetScript("OnMouseUp", function() mod:Call("Fenster", W.ShowData) end)
    Peon.UI.SetTooltip(bar, function() return { W.StatusText(), L.ST_HINT } end)
    return bar
end

function W.ShowData()
    W.Open("sources")
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local function SavePosition(f)
    if not f.GetPoint then return end
    local point, _, rel, x, y = f:GetPoint(1)
    if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
    mod.db.windowPos = { point = point, rel = rel, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
end

function W.Create()
    if W.frame then return W.frame end
    local UI = Peon.UI
    local f = UI.Window("PeonBrokerFrame", { title = ("|c%sPeon|r Broker"):format(Peon.COLOR),
        icon = "Interface\\Icons\\INV_Misc_Coin_02", width = W.WIDTH, height = W.HEIGHT })
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    local defs = {}
    for _, t in ipairs(W.TABS) do defs[#defs + 1] = { t.key, L[t.label] } end
    W.tabs = UI.BottomTabs(f, defs, function(key) mod:Call("Fenster", W.OnTab, key) end)
    W.tabButtons = W.tabs
    for _, b in ipairs(W.tabs) do
        if W.AH_ONLY[b.key] then
            if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
            UI.SetTooltip(b, { W.TabLabel(b.key), L.TAB_AH_ONLY })
        end
    end

    W.status = W.NewStatus(f)
    W.back = W.NewBack(f, f)

    f:SetScript("OnShow", function() mod:Call("Fenster", W.Refresh) end)
    f:SetScript("OnHide", function() W.Leave(nil) end)
    W.frame = f
    if W.ApplyBadges then W.ApplyBadges() end
    return f
end

-- Knopf "Zurueck zu ..." links in der Titelleiste (rechts neben dem runden Bild). parent = Rahmen, anchor = Fenster
W.BACK_X = 62
function W.NewBack(parent, anchor)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(150, 18)
    b:SetPoint("TOPLEFT", anchor, "TOPLEFT", W.BACK_X, -3)
    if b.GetFontString and b:GetFontString() and b:GetFontString().SetFontObject then
        b:GetFontString():SetFontObject("GameFontNormalSmall")
    end
    b:SetScript("OnClick", function() mod:Call("Sprung", ns.Go.Back) end)
    b:Hide()
    return b
end

-- Zahl am Reiter (wie im Auktionshaus, dort setzt sie AHTabs.SetBadge)
function W.ApplyBadges()
    if not W.tabs then return end
    local T = ns.AHTabs
    for _, b in ipairs(W.tabs) do
        local badge = T and T.badges and T.badges[b.key]
        if b.SetBadge then b:SetBadge(badge and badge.n or 0) end
    end
end

-- Gesperrte Reiter wieder sperren (Blizzards Abwaehlen gibt jeden Reiter frei)
local function LockTabs()
    for _, b in ipairs(W.tabs or {}) do
        if W.AH_ONLY[b.key] and b.Disable then b:Disable() end
    end
end

-- Stelle des Fensters: selbst verschoben, sonst dort, wo das Auktionshaus zuletzt stand, sonst Mitte
function W.Place()
    local f = W.frame
    f:ClearAllPoints()
    local p = mod.db.windowPos
    local a = mod.acc.ahPos
    if type(p) == "table" and type(p.point) == "string" and type(p.x) == "number" and type(p.y) == "number" then
        f:SetPoint(p.point, UIParent, type(p.rel) == "string" and p.rel or p.point, p.x, p.y)
    elseif type(a) == "table" and type(a.x) == "number" and type(a.y) == "number" then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", a.x, a.y)
    else
        f:SetPoint("CENTER")
    end
end

-- Gilt gerade "am Auktionator"? Dann stehen Brokers Seiten als Reiter in Blizzards Fenster.
function W.AtAH()
    local T = ns.AHTabs
    return ns.Scan.ahOpen == true and ns.AHTouch() and T ~= nil and T.built == true
end

-- Gueltiger Reiter fuer das Fenster
local function ValidKey(key)
    if key and W.pages[key] and not W.AH_ONLY[key] then
        for _, t in ipairs(W.TABS) do if t.key == key then return key end end
    end
    return W.DEFAULT
end

-- Unterpunkt von "Mehr" (Haendler, Neutral, Datenlage, Beobachtung)? Dann oeffnet Mehr mit diesem Unterpunkt.
local function Resolve(key)
    for _, t in ipairs(W.MORE) do
        if t.key == key and W.pages[key] then return "more", key end
    end
    return key, nil
end

local function SelectSub(sub)
    if not sub then return end
    mod.acc.moreTab = sub
    if W.more and W.more.tabs and W.more.current ~= sub then W.more.tabs:Select(sub) end
end

function W.Open(tab)
    local sub
    tab, sub = Resolve(tab)
    if sub then mod.acc.moreTab = sub end
    if W.AtAH() then
        local ok = ns.AHTabs.Show(tab)
        SelectSub(sub)
        return ok
    end
    W.Create()
    W.Place()
    W.Select(ValidKey(tab or W.current or mod.db.windowTab))
    SelectSub(sub)
    W.frame:Show()
end

function W.Toggle(tab)
    if W.AtAH() then
        local T = ns.AHTabs
        if T.current and not tab then T.Close() else T.Show(tab) end
        return
    end
    if W.frame and W.frame:IsShown() then W.frame:Hide() else W.Open(tab) end
end

function W.IsOpen() return W.frame ~= nil and W.frame:IsShown() end

-- Den bisherigen Reiter verlassen (z. B. Radar-Scan anhalten); next = neuer Reiter oder nil (Fenster zu)
function W.Leave(next)
    local cur = W.current
    if cur and cur ~= next and W.pages[cur] and W.pages[cur].leave and not W.WIP[cur] then
        local T = ns.AHTabs
        if not (T and T.host[cur] == "ah") then mod:Call("Fenster", W.pages[cur].leave) end
    end
end

-- Blizzard-Auktionshaus auf eine Ansicht umschalten (ab 0.20): "Buy", "ItemSell", "Auctions" ...
-- (AuctionHouseFrameDisplayMode; SetDisplayMode stellt auch Blizzards Reiter um). Nur bei offenem Auktionshaus.
function W.SetAHMode(name)
    local f, modes = rawget(_G, "AuctionHouseFrame"), rawget(_G, "AuctionHouseFrameDisplayMode")
    if not (ns.Scan.ahOpen and type(f) == "table" and type(modes) == "table" and modes[name]) then return false end
    if not ns.AHTouch() then return false end   -- ab 0.41: "Blizzard pur"
    if type(f.SetDisplayMode) ~= "function" then return false end
    if type(f.GetDisplayMode) == "function" then
        local ok, m = pcall(f.GetDisplayMode, f)
        if ok and m == modes[name] then return true end
    end
    local ok = pcall(f.SetDisplayMode, f, modes[name])
    mod:Dbg("Auktionshaus-Ansicht " .. name .. ": " .. tostring(ok))
    return ok
end

-- Reiter im Fenster waehlen
function W.Select(key)
    W.Create()
    local sub
    key, sub = Resolve(key)
    if sub then mod.acc.moreTab = sub end
    W.tabs:Select(ValidKey(key))
    SelectSub(sub)
end

-- Ein Reiter wurde gewaehlt (Klick oder W.Select)
function W.OnTab(key)
    if key ~= ValidKey(key) then   -- gesperrt oder unbekannt: beim bisherigen bleiben
        local back = ValidKey(W.current)
        if back ~= key then W.tabs:Select(back) end
        return
    end
    W.Leave(key)
    local changed = W.current ~= key or not (W.frame and W.frame:IsShown())
    W.current = key
    mod.db.windowTab = key
    local T = ns.AHTabs
    for k, c in pairs(W.contents) do
        if k ~= key and not (T and T.host[k] == "ah") then c:Hide() end
    end
    if T and T.Release then T.Release(key) end   -- haengt die Seite gerade im Auktionshaus, zurueckholen
    local c = W.Content(key, W.frame, W.frame)
    c:Show()
    LockTabs()
    if ns.Go then ns.Go.OnTab(key) end
    if W.frame:IsShown() then W.Refresh() end
    if changed and W.pages[key].enter and not W.WIP[key] then mod:Call("Fenster", W.pages[key].enter) end
end

function W.Refresh()
    if not W.frame then return end
    W.FillStatus(W.status)
    local page = W.current and W.pages[W.current]
    if page and page.refresh and not W.WIP[W.current] then page.refresh() end
end

---------------------------------------------------------------------------
-- Seite "Mehr": Haendler (Vendors.lua), Neutral (Marktvergleich) und Datenlage (Quellen, beide Pages.lua).
-- Die Beobachtung steht ab 0.62 als besondere Liste in Einkaufen.
---------------------------------------------------------------------------
W.MORE = {
    { key = "vendors", label = "MORE_VENDORS" },
    { key = "market",  label = "MORE_NEUTRAL" },
    { key = "sources", label = "MORE_DATA" },
}

local function MoreSelect(key)
    local m = W.more
    if not m then return end
    local page = W.pages[key]
    if not page then return end
    m.current = key
    mod.acc.moreTab = key
    for k, c in pairs(m.contents) do if k ~= key then c:Hide() end end
    local c = m.contents[key]
    if not c then
        c = CreateFrame("Frame", nil, m.frame)
        c:SetPoint("TOPLEFT", m.frame, "TOPLEFT", 0, -34)
        c:SetPoint("BOTTOMRIGHT", m.frame, "BOTTOMRIGHT", 0, 0)
        m.contents[key] = c
        page.build(c)
    end
    c:Show()
    if page.refresh then page.refresh() end
end

W.pages.more = {
    build = function(c)
        local defs = {}
        for _, t in ipairs(W.MORE) do if W.pages[t.key] then defs[#defs + 1] = { t.key, L[t.label] } end end
        local m = { frame = c, contents = {} }
        W.more = m
        m.tabs = Peon.UI.TopTabs(c, defs, function(key) mod:Call("Mehr", MoreSelect, key) end)
        if m.tabs[1] then m.tabs[1]:SetPoint("TOPLEFT", c, "TOPLEFT", 8, 0) end
        local want = mod.acc.moreTab
        if not (type(want) == "string" and W.pages[want]) then want = defs[1] and defs[1][1] end
        local known = false
        for _, d in ipairs(defs) do if d[1] == want then known = true end end
        if not known then want = defs[1] and defs[1][1] end
        if want then m.tabs:Select(want) end
    end,
    refresh = function()
        local m = W.more
        local page = m and m.current and W.pages[m.current]
        if page and page.refresh then page.refresh() end
    end,
}

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
function W.Init()
    mod:On("SCAN_DONE", function() if W.IsOpen() then W.Refresh() end end)
    mod:On("CHANGED", function() if W.IsOpen() then W.Refresh() end end)
end
