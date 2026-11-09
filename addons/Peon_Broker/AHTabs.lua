-- Peon_Broker - AHTabs.lua
-- Umbau U0 (ab 0.41, Konzept Peon_Broker_Umbau.md, Abschnitt 7.1 und 7.7): Pruefaufbau fuer eigene Reiter im
-- Blizzard-Auktionshaus und Notausgang "Blizzard pur".
--
-- Eigene Reiter, ohne Blizzards Ansichts-Steuerung anzufassen:
--   * Broker fuegt nichts zu AuctionHouseFrameDisplayMode oder AuctionHouseFrame.Tabs hinzu und ruft SetDisplayMode
--     nie auf. Die Reiter sind eigene Knoepfe (Vorlage AuctionHouseFrameTabTemplate) rechts neben "Auktionen".
--   * Ein Klick legt eine eigene, undurchsichtige Flaeche ueber Blizzards Inhalt (Blizzards Rahmen bleiben, wie sie sind)
--     und stellt nur das Aussehen der Reiter um (PanelTemplates_SelectTab/DeselectTab).
--   * Wechselt Blizzard die Ansicht (Klick auf Kaufen/Verkaufen/Auktionen, Gegenstand aus der Tasche), meldet das ein
--     sicherer Anhang an SetDisplayMode. Broker blendet die Flaeche dann aus und zeigt Blizzards Reiter wieder richtig
--     (PanelTemplates_UpdateTabs liest nur).
--   * /broker pruefen ah: Stimmen Blizzards Werte noch (issecurevariable)? Ergebnis in PeonBrokerDB.ahProbe.
--
-- "Blizzard pur" (acc.ahPlain): Broker laesst das Auktionshaus ganz in Ruhe (keine Reiter, Knoepfe, Anhaenge, kein
-- Hineinlegen oder Umschalten). Umschalten laedt die Oberflaeche neu, weil sich eine Verunreinigung (Taint) nur so loest.
-- Meldet das Spiel ADDON_ACTION_BLOCKED/FORBIDDEN fuer Peon_Broker, bietet Broker das Umschalten von selbst an.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local T = {}
ns.AHTabs = T

T.TABS = {
    { key = "radar", label = "AHTAB_RADAR" },
    { key = "shop",  label = "AHTAB_SHOP" },
}
T.PAGE_LEVEL = 500  -- Abstand der Flaeche ueber dem Auktionshaus (Rahmenebene)
T.tabs = {}          -- key -> Knopf
T.current = nil      -- offener eigener Reiter oder nil (Blizzard-Ansicht)
T.blocked = {}       -- gemeldete Blockaden dieser Sitzung: { t, event, fn }

local function AHFrame()
    local f = rawget(_G, "AuctionHouseFrame")
    if type(f) == "table" then return f end
    return nil
end

---------------------------------------------------------------------------
-- Blizzard pur
---------------------------------------------------------------------------
function ns.AHPlain()
    return mod.acc ~= nil and mod.acc.ahPlain == true
end

-- Darf Broker das Blizzard-Auktionshaus anfassen? (Reiter, Knoepfe, Gegenstand hineinlegen, Ansicht umschalten)
function ns.AHTouch()
    return not ns.AHPlain()
end

-- Umschalten und neu laden. Nur aus einem Klick (ReloadUI ist geschuetzt).
function T.SetPlain(on)
    mod.acc.ahPlain = on and true or false
    mod:Dbg("Blizzard pur: " .. tostring(mod.acc.ahPlain))
    if ReloadUI then ReloadUI() end
end

function T.AskPlain(on, reason)
    if not StaticPopup_Show then T.SetPlain(on); return end
    local name = on and "PEON_BROKER_AH_PLAIN_ON" or "PEON_BROKER_AH_PLAIN_OFF"
    StaticPopup_Show(name, reason or "")
end

local function Dialogs()
    if not StaticPopupDialogs then return end
    StaticPopupDialogs["PEON_BROKER_AH_PLAIN_ON"] = {
        text = L.AH_PLAIN_ASK, button1 = L.AH_PLAIN_YES, button2 = CANCEL or "Cancel",
        OnAccept = function() mod:Call("Blizzard pur", T.SetPlain, true) end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["PEON_BROKER_AH_PLAIN_OFF"] = {
        text = L.AH_PLAIN_ASK_OFF, button1 = L.AH_PLAIN_YES_OFF, button2 = CANCEL or "Cancel",
        OnAccept = function() mod:Call("Blizzard pur", T.SetPlain, false) end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end

-- Das Spiel meldet eine blockierte Aktion. Nur wenn Broker genannt wird.
function T.OnBlocked(event, addon, fn)
    if addon ~= ADDON_NAME then return end
    fn = type(fn) == "string" and fn or "?"
    T.blocked[#T.blocked + 1] = { t = time and time() or 0, event = event, fn = fn }
    mod.acc.ahBlocked = { t = time and time() or 0, event = event, fn = fn, plain = ns.AHPlain() }
    if Peon.RecordError then
        pcall(Peon.RecordError, ADDON_NAME, "Auktionshaus", event .. ": " .. fn, mod.version)
    end
    mod:Dbg(("Blockiert: %s %s"):format(event, fn))
    -- Anbieten nur bei offenem Auktionshaus und einmal je Sitzung
    if ns.AHPlain() or T.offered or not (ns.Scan and ns.Scan.ahOpen) then return end
    T.offered = true
    T.AskPlain(true, L.AH_PLAIN_BLOCKED:format(fn))
end

---------------------------------------------------------------------------
-- Pruefung: Sind Blizzards Werte noch sauber? (issecurevariable gibt true, wenn kein Addon sie beruehrt hat)
---------------------------------------------------------------------------
T.PROBE_KEYS = { "displayMode", "selectedTab", "numTabs", "Tabs", "tabsForDisplayMode" }

function T.Probe(quiet)
    local f = AHFrame()
    local r = { t = time and time() or 0, plain = ns.AHPlain(), loaded = f ~= nil, built = T.built == true,
        vars = {}, blocked = #T.blocked, opened = T.opened or 0 }
    local isv = rawget(_G, "issecurevariable")
    if f and type(isv) == "function" then
        for _, k in ipairs(T.PROBE_KEYS) do
            local ok, secure, by = pcall(isv, f, k)
            r.vars[k] = ok and (secure and "sauber" or ("beruehrt von " .. tostring(by))) or "?"
        end
        local ok, secure, by = pcall(isv, "AuctionHouseFrameDisplayMode")
        r.vars.AuctionHouseFrameDisplayMode = ok and (secure and "sauber" or ("beruehrt von " .. tostring(by))) or "?"
    end
    mod.acc.ahProbe = r
    if not quiet then
        mod:Print(L.AH_PROBE_HEAD:format(r.plain and L.AH_PROBE_PLAIN or (r.built and L.AH_PROBE_BUILT or L.AH_PROBE_NOT_BUILT)))
        if not r.loaded then mod:Print(L.AH_PROBE_NOT_LOADED) end
        local names = {}
        for k in pairs(r.vars) do names[#names + 1] = k end
        table.sort(names)
        for _, k in ipairs(names) do mod:Print(("  %s: %s"):format(k, r.vars[k])) end
        mod:Print(L.AH_PROBE_BLOCKED:format(r.blocked))
    end
    return r
end

---------------------------------------------------------------------------
-- Reiter und Flaeche
---------------------------------------------------------------------------
local function TabTemplate()
    -- AuctionHouseFrameTabTemplate gibt es erst, wenn Blizzards Auktionshaus geladen ist (beim ersten Besuch)
    return "AuctionHouseFrameTabTemplate"
end

-- Aussehen eines Reiters: gewaehlt (hell, tiefer) oder nicht. Wie PanelTemplates_SelectTab/DeselectTab, aber ohne
-- deren Rest (Tooltip, Schrift), damit ein Fehler dort nicht das Aussehen verhindert (0.41.1: Radar sah nie gewaehlt aus).
local function SideTextures(tab, active)
    for _, n in ipairs({ "Left", "Middle", "Right" }) do
        local a, b = tab[n], tab[n .. "Active"]
        if type(a) == "table" and a.SetShown then a:SetShown(not active) end
        if type(b) == "table" and b.SetShown then b:SetShown(active) end
    end
end

local function Select(tab)
    if PanelTemplates_SelectTab then
        local ok, err = pcall(PanelTemplates_SelectTab, tab)
        if not ok then mod:Dbg("PanelTemplates_SelectTab: " .. tostring(err)) end
    end
    SideTextures(tab, true)
    if tab.Text and tab.Text.SetPoint then
        tab.Text:ClearAllPoints()
        tab.Text:SetPoint("CENTER", tab, "CENTER", 0, -3)
    end
    if tab.Disable then tab:Disable() end
end

local function Deselect(tab)
    if PanelTemplates_DeselectTab then
        local ok, err = pcall(PanelTemplates_DeselectTab, tab)
        if not ok then mod:Dbg("PanelTemplates_DeselectTab: " .. tostring(err)) end
    end
    SideTextures(tab, false)
    if tab.Text and tab.Text.SetPoint then
        tab.Text:ClearAllPoints()
        tab.Text:SetPoint("CENTER", tab, "CENTER", 0, 2)
    end
    if tab.Enable then tab:Enable() end
end

-- Blizzards Reiter so zeigen, wie Blizzard sie gesetzt hat (liest nur selectedTab)
local function RestoreBlizzardTabs(f)
    if PanelTemplates_UpdateTabs and f then pcall(PanelTemplates_UpdateTabs, f) end
end

local function BlizzardTabs(f)
    local list = {}
    if type(f.Tabs) == "table" then
        for _, tab in ipairs(f.Tabs) do list[#list + 1] = tab end
    end
    return list
end

function T.Open(key)
    local f = AHFrame()
    if not T.built or not f then return false end
    T.current = key
    T.opened = (T.opened or 0) + 1
    for k, tab in pairs(T.tabs) do
        if k == key then Select(tab) else Deselect(tab) end
    end
    for _, tab in ipairs(BlizzardTabs(f)) do Deselect(tab) end
    T.page.title:SetText(L["AHTAB_" .. key:upper() .. "_TITLE"] or key)
    T.page:Show()
    T.UpdateStatus()
    if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
    mod:Dbg("Eigener Reiter im Auktionshaus: " .. key)
    return true
end

function T.Close()
    if not T.built then return end
    local was = T.current
    T.current = nil
    T.page:Hide()
    for _, tab in pairs(T.tabs) do Deselect(tab) end
    if was then RestoreBlizzardTabs(AHFrame()) end
end

-- Blizzard hat die Ansicht gewechselt (sicherer Anhang an SetDisplayMode)
function T.OnDisplayMode()
    if T.current then T.Close() end
end

-- Zustand auf der Prueflaeche: zeigt live, ob Blizzards Werte sauber sind
function T.UpdateStatus()
    if not T.page or not T.page.status then return end
    local r = T.Probe(true)
    local lines = {}
    local names = {}
    for k in pairs(r.vars) do names[#names + 1] = k end
    table.sort(names)
    for _, k in ipairs(names) do
        local v = r.vars[k]
        lines[#lines + 1] = (v == "sauber" and "|cff60e060" or "|cffff9933") .. k .. ": " .. v .. "|r"
    end
    lines[#lines + 1] = L.AH_PROBE_BLOCKED:format(r.blocked)
    T.page.status:SetText(table.concat(lines, "\n"))
end

function T.Build()
    if T.built or ns.AHPlain() then return false end
    local f = AHFrame()
    if not f or type(f.AuctionsTab) ~= "table" or type(f.SetDisplayMode) ~= "function" then return false end

    -- Reiter rechts neben "Auktionen", Abstand wie bei Blizzard (-15)
    local prev = f.AuctionsTab
    for i, def in ipairs(T.TABS) do
        local ok, tab = pcall(CreateFrame, "Button", "PeonBrokerAHTab" .. i, f, TabTemplate())
        if not ok or not tab then
            tab = CreateFrame("Button", "PeonBrokerAHTab" .. i, f, "PanelTabButtonTemplate")
        end
        tab:SetText(L[def.label])
        tab:SetPoint("LEFT", prev, "RIGHT", -15, 0)
        tab:SetScript("OnClick", function() mod:Call("Auktionshaus-Reiter", T.Open, def.key) end)
        if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 20, nil, 70) end
        Deselect(tab)
        T.tabs[def.key] = tab
        prev = tab
    end

    -- Flaeche ueber Blizzards Inhalt, faengt die Maus ab. Oben links bleibt das Portraet frei, darum zwei Teile:
    -- die Flaeche ab Hoehe der Kategorien und ein Streifen ueber Blizzards Suchleiste.
    local p = CreateFrame("Frame", "PeonBrokerAHPage", f)
    p:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -60)
    p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    -- Weit ueber Blizzards Inhalt: Teile des Verkaufsfensters (Gegenstand, Knopf, Haken) liegen sonst darueber (0.41.1)
    if p.SetFrameLevel and f.GetFrameLevel then p:SetFrameLevel((f:GetFrameLevel() or 1) + T.PAGE_LEVEL) end
    if p.EnableMouse then p:EnableMouse(true) end
    local strip = CreateFrame("Frame", nil, p)
    strip:SetPoint("BOTTOMLEFT", p, "TOPLEFT", 58, 0)
    strip:SetPoint("BOTTOMRIGHT", p, "TOPRIGHT", 0, 0)
    strip:SetHeight(36)
    if strip.EnableMouse then strip:EnableMouse(true) end
    local sbg = strip:CreateTexture(nil, "BACKGROUND")
    sbg:SetAllPoints(strip)
    sbg:SetColorTexture(0.05, 0.05, 0.05, 0.97)
    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(p)
    local atlas = false
    if C_Texture and C_Texture.GetAtlasInfo and bg.SetAtlas then
        local ok, info = pcall(C_Texture.GetAtlasInfo, "auctionhouse-background-index")
        if ok and info then atlas = pcall(bg.SetAtlas, bg, "auctionhouse-background-index") end
    end
    if not atlas then bg:SetColorTexture(0.05, 0.05, 0.05, 0.97) end
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -14)
    p.title = title
    local text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    text:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    text:SetJustifyH("LEFT")
    text:SetText(L.AHTAB_TEST_TEXT)
    p.text = text
    local status = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -16)
    status:SetJustifyH("LEFT")
    p.status = status
    p:SetScript("OnShow", function() T.UpdateStatus() end)
    p:Hide()
    T.page = p

    -- Blizzard wechselt die Ansicht: Flaeche weg (sicherer Anhang, veraendert Blizzards Ablauf nicht)
    if hooksecurefunc then hooksecurefunc(f, "SetDisplayMode", function() mod:Call("Auktionshaus-Reiter", T.OnDisplayMode) end) end
    if f.HookScript then f:HookScript("OnHide", function() mod:Call("Auktionshaus-Reiter", T.Close) end) end

    T.built = true
    mod:Dbg("Eigene Reiter im Auktionshaus angelegt")
    return true
end

-- Knopf "Blizzard pur" oben rechts im Auktionshaus (links neben dem Schliessen-Knopf)
function T.BuildPlainButton()
    if T.plainButton or ns.AHPlain() then return end
    local f = AHFrame()
    if not f then return end
    local b = CreateFrame("Button", "PeonBrokerAHPlainButton", f, "UIPanelButtonTemplate")
    b:SetSize(96, 18)
    -- in der Titelleiste links neben dem Schliessen-Knopf, ueber Blizzards Rahmen (0.41.1: lag vorher darunter)
    b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -34, -3)
    if b.SetFrameLevel and f.GetFrameLevel then b:SetFrameLevel((f:GetFrameLevel() or 1) + T.PAGE_LEVEL + 10) end
    if b.GetFontString and b:GetFontString() and b:GetFontString().SetFontObject then
        b:GetFontString():SetFontObject("GameFontNormalSmall")
    end
    b:SetText(L.AH_PLAIN_BUTTON)
    b:SetScript("OnClick", function() mod:Call("Blizzard pur", T.AskPlain, true) end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(("|c%sPeon|r Broker"):format(Peon.COLOR))
        GameTooltip:AddLine(L.AH_PLAIN_HINT, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    T.plainButton = b
end

function T.OnAHShow()
    if ns.AHPlain() then return end
    T.BuildPlainButton()
    T.Build()
end

function T.Init()
    Dialogs()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function() mod:Call("Auktionshaus-Reiter", T.OnAHShow) end)
    mod:RegisterEvent("ADDON_ACTION_BLOCKED", function(_, addon, fn) mod:Call("Blizzard pur", T.OnBlocked, "ADDON_ACTION_BLOCKED", addon, fn) end)
    mod:RegisterEvent("ADDON_ACTION_FORBIDDEN", function(_, addon, fn) mod:Call("Blizzard pur", T.OnBlocked, "ADDON_ACTION_FORBIDDEN", addon, fn) end)
    if ns.AHPlain() then mod:Print(L.AH_PLAIN_ACTIVE) end
end
