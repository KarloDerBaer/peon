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

-- Reihenfolge ab 0.59 (Neuaufbau N1, KarloDerBaer): Blizzards Markt (Kaufen), Verkaufen, Auktionen, danach Brokers
-- Einkaufen, Radar, Fokus, Gegenstand, Mehr. Die Schluessel sind die der Seiten im Broker-Fenster (W.pages).
T.TABS = {
    { key = "buy",    label = "AHTAB_SHOP" },
    { key = "radar",  label = "AHTAB_RADAR" },
    { key = "focus",  label = "NTAB_FOCUS" },
    { key = "prices", label = "NTAB_ITEM" },
    { key = "more",   label = "NTAB_MORE" },
}
-- Rahmenebenen (Blizzards Fenstervorlage, nachgelesen im Zweig forever, SharedUIPanelTemplates.xml): rundes Bild 400,
-- Metallrahmen 500, Titel und Schliessen 510. Brokers Flaeche liegt ueber Blizzards Inhalt, aber unter dem Bild
-- (bis 0.59.0 lag sie ueber allem und sparte die Ecke am Bild aus, dort schien Blizzards Inhalt durch).
T.PAGE_LEVEL = 300  -- Flaeche: ueber Blizzards Inhalt, unter dem runden Bild
T.TOP_LEVEL = 520   -- Knoepfe in der Titelleiste: ueber Rahmen und Titel
T.TAB_GAP = -15     -- Abstand zum Reiter davor wie bei Blizzard. Ab 0.56 misst T.AlignTabs den sichtbaren Abstand nach
T.tabs = {}          -- key -> Knopf
T.current = nil      -- offener eigener Reiter oder nil (Blizzard-Ansicht)
T.blocked = {}       -- gemeldete Blockaden dieser Sitzung: { t, event, fn }
T.host = {}          -- ab 0.48: wo eine Flaeche gerade haengt ("ah" oder "window"), z. B. host.radar
T.badges = {}        -- ab 0.48: Zahl am Reiter je key, blink = true solange nicht geoeffnet

-- Hat Broker fuer diesen Schluessel einen eigenen Reiter im Auktionshaus?
function T.IsHosted(key)
    for _, d in ipairs(T.TABS) do if d.key == key then return true end end
    return false
end

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
-- ab 0.58: auch die Verkaufsfenster (Broker haengt sich an Layout und UpdatePostState und rueckt Zeilen naeher)
T.PROBE_SELL = { ItemSellFrame = "Verkaufen", CommoditiesSellFrame = "Verkaufen Massenware" }
T.PROBE_SELL_KEYS = { "spacing", "Layout", "UpdatePostState", "PostItem" }

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
    -- Inhalt von Blizzards Reiterliste (issecurevariable prueft nur den Eintrag "Tabs", nicht was darin steht)
    if f then
        local n = T.OwnInBlizzardTabs(f)
        r.vars["Tabs (Inhalt)"] = n == 0 and "sauber" or ("beruehrt von Peon_Broker (" .. n .. " Reiter)")
        local isv2 = rawget(_G, "issecurevariable")
        for frameKey, label in pairs(T.PROBE_SELL) do
            local sf = rawget(f, frameKey)
            if type(sf) == "table" and type(isv2) == "function" then
                for _, k in ipairs(T.PROBE_SELL_KEYS) do
                    if sf[k] ~= nil then
                        local ok, secure, by = pcall(isv2, sf, k)
                        r.vars[label .. "." .. k] = ok and (secure and "sauber" or ("beruehrt von " .. tostring(by))) or "?"
                    end
                end
            end
        end
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
        if ns.Cut then mod:Print(L.CUT_HEAD:format(ns.Cut.Report())) end   -- ab 0.43 (U2)
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

-- Blizzards drei Reiter (ohne Brokers eigene, falls sie doch in der Liste stehen sollten)
local function BlizzardTabs(f)
    local list, own = {}, {}
    for _, tab in pairs(T.tabs) do own[tab] = true end
    if type(f.Tabs) == "table" then
        for _, tab in ipairs(f.Tabs) do if not own[tab] then list[#list + 1] = tab end end
    end
    return list
end

-- Steht ein Broker-Reiter in Blizzards Liste? (Pruefung, siehe T.Build)
function T.OwnInBlizzardTabs(f)
    if type(f) ~= "table" or type(f.Tabs) ~= "table" then return 0 end
    local own, n = {}, 0
    for _, tab in pairs(T.tabs) do own[tab] = true end
    for _, tab in ipairs(f.Tabs) do if own[tab] then n = n + 1 end end
    return n
end

function T.Open(key)
    local f = AHFrame()
    if not T.built or not f or not T.IsHosted(key) then return false end
    local was = T.current
    if was and was ~= key then T.Leave(was) end
    T.current = key
    T.opened = (T.opened or 0) + 1
    for k, tab in pairs(T.tabs) do
        if k == key then Select(tab) else Deselect(tab) end
    end
    for _, tab in ipairs(BlizzardTabs(f)) do Deselect(tab) end
    T.page:Show()
    T.Attach(key)
    T.SetBadge(key, nil)
    local W = ns.Window
    if W then
        mod.db.windowTab = key
        W.FillStatus(T.status)
    end
    if ns.Go then ns.Go.OnTab(key) end
    if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
    mod:Dbg("Eigener Reiter im Auktionshaus: " .. key)
    return true
end

-- Reiter am Auktionator zeigen (W.Open und W.Toggle leiten hierher). Brokers Seiten oeffnen als eigener Reiter,
-- "Markt" ist Blizzards Kaufen, alles andere fuehrt zu Einkaufen.
function T.Show(key)
    -- ohne Wunsch: der zuletzt gewaehlte Broker-Reiter, sonst Einkaufen
    if key == nil then key = T.IsHosted(mod.db.windowTab) and mod.db.windowTab or "buy" end
    if T.IsHosted(key) then return T.Open(key) end
    if key == "browse" then
        T.Close()
        return ns.Window.SetAHMode("Buy")
    end
    return T.Open("buy")
end

-- Seite eines Reiters verlassen (z. B. Radar-Scan anhalten)
function T.Leave(key)
    local W = ns.Window
    local page = W and W.pages[key]
    if page and page.leave and T.host[key] == "ah" and not W.WIP[key] then mod:Call("Auktionshaus-Reiter", page.leave) end
end

---------------------------------------------------------------------------
-- Abstaende der Reiter (ab 0.56): Der sichtbare Abstand zwischen Blizzards "Markt" und "Verkaufen" ist das Mass.
-- Broker misst, wie weit die Grafik eines Reiters ueber seinen Rahmen hinausragt, und setzt jeden weiteren Reiter so,
-- dass zwischen den Grafiken genau derselbe Abstand bleibt. Nur Anker der Reiter, nichts in Blizzards Tabellen.
---------------------------------------------------------------------------
local function Edges(tab)
    local fl, fr = tab.GetLeft and tab:GetLeft(), tab.GetRight and tab:GetRight()
    if type(fl) ~= "number" or type(fr) ~= "number" then return nil end
    local l = type(tab.Left) == "table" and tab.Left.GetLeft and tab.Left:GetLeft() or nil
    local r = type(tab.Right) == "table" and tab.Right.GetRight and tab.Right:GetRight() or nil
    if type(l) ~= "number" or type(r) ~= "number" then l, r = fl, fr end
    return l - fl, r - fr, l, r   -- Ueberstand links, Ueberstand rechts, sichtbare Kanten
end

-- Reihenfolge der Reiter unten (ab 0.59): Blizzards Markt, Verkaufen, Auktionen, dann Brokers Reiter
function T.TabOrder(f)
    local list = {}
    if type(f.BuyTab) == "table" then list[#list + 1] = f.BuyTab end
    if type(f.SellTab) == "table" then list[#list + 1] = f.SellTab end
    if type(f.AuctionsTab) == "table" then list[#list + 1] = f.AuctionsTab end
    for _, def in ipairs(T.TABS) do if T.tabs[def.key] then list[#list + 1] = T.tabs[def.key] end end
    return list
end

function T.AlignTabs()
    local f = AHFrame()
    if not T.built or not f or type(f.BuyTab) ~= "table" or type(f.SellTab) ~= "table" then return false end
    local _, _, _, buyR = Edges(f.BuyTab)
    local _, _, sellL = Edges(f.SellTab)
    if not buyR or not sellL then return false end
    local gap = sellL - buyR   -- sichtbarer Abstand bei Blizzard
    local order = T.TabOrder(f)
    T.tabGaps = {}
    for i = 4, #order do   -- Blizzards drei Reiter bleiben, wo Blizzard sie hinsetzt
        local prev, tab = order[i - 1], order[i]
        local _, dr = Edges(prev)
        local dl = Edges(tab)
        if dr and dl then
            local off = gap + dr - dl
            tab:ClearAllPoints()
            tab:SetPoint("LEFT", prev, "RIGHT", off, 0)
            T.tabGaps[#T.tabGaps + 1] = off
        end
    end
    T.tabGap = gap
    return true
end

-- nach dem Aufbau des Bildes messen (vorher kennt das Spiel die Kanten noch nicht)
function T.AlignSoon()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() mod:Call("Auktionshaus-Reiter", T.AlignTabs) end)
    else
        mod:Call("Auktionshaus-Reiter", T.AlignTabs)
    end
end

function T.Close()
    if not T.built then return end
    local was = T.current
    T.current = nil
    T.page:Hide()
    if was then T.Leave(was) end
    for _, tab in pairs(T.tabs) do Deselect(tab) end
    if was then RestoreBlizzardTabs(AHFrame()) end
end

-- Blizzard hat die Ansicht gewechselt (sicherer Anhang an SetDisplayMode)
function T.OnDisplayMode()
    if T.current then T.Close() end
    T.PlaceBack()
end

-- Blizzards Knopf "Zurueck" in der Kaufansicht (Massenware oder Einzelgegenstand), wenn er gerade zu sehen ist
local function BlizzardBack(f)
    for _, key in ipairs({ "CommoditiesBuyFrame", "ItemBuyFrame" }) do
        local bf = rawget(f, key)
        local b = type(bf) == "table" and rawget(bf, "BackButton")
        if type(b) == "table" and b.IsVisible and b:IsVisible() then return b end
    end
    return nil
end

-- "Zurueck zu ..." an die passende Stelle: neben Blizzards "Zurueck", sonst links in die Titelleiste. Nur Anker
-- des eigenen Knopfs, Blizzards Knopf wird nur gelesen.
function T.PlaceBack()
    local b, f = T.back, AHFrame()
    if not b or not f then return end
    local bb = not T.current and BlizzardBack(f) or nil
    b:ClearAllPoints()
    if bb then
        b:SetSize(170, 22)
        b:SetPoint("LEFT", bb, "RIGHT", 8, 0)
    else
        b:SetSize(150, 18)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", ns.Window.BACK_X, -3)
    end
    T.backAt = bb and "blizzard" or "title"
end

-- Hintergrund des Auktionshauses (Bg der Fenstervorlage) auf eine eigene Grafik uebernehmen. Liest nur.
function T.CopyFrameBg(f, tex)
    local src = type(f) == "table" and rawget(f, "Bg")
    if type(src) ~= "table" then return false end
    local atlas = src.GetAtlas and select(2, pcall(src.GetAtlas, src))
    if type(atlas) == "string" and atlas ~= "" and tex.SetAtlas and pcall(tex.SetAtlas, tex, atlas) then return true end
    local file = src.GetTexture and select(2, pcall(src.GetTexture, src))
    if file ~= nil and file ~= "" and pcall(tex.SetTexture, tex, file, "REPEAT", "REPEAT") then
        if tex.SetHorizTile then tex:SetHorizTile(true) end
        if tex.SetVertTile then tex:SetVertTile(true) end
        return true
    end
    return false
end

function T.Build()
    if T.built or ns.AHPlain() then return false end
    local f = AHFrame()
    if not f or type(f.AuctionsTab) ~= "table" or type(f.SetDisplayMode) ~= "function" then return false end

    -- Reiter rechts neben "Auktionen". Sie haengen an einem eigenen Rahmen (T.tabHolder), nicht am Auktionshaus:
    -- Blizzards Vorlage traegt jeden Reiter in die Liste "Tabs" seines Elternrahmens ein (parentArray). Bis 0.41.1
    -- landeten Radar und Einkaufen so in AuctionHouseFrame.Tabs (Blizzards Liste veraendert, und Brokers eigener
    -- Reiter wurde beim Abwaehlen der Blizzard-Reiter gleich wieder abgewaehlt).
    local holder = CreateFrame("Frame", "PeonBrokerAHTabHolder", f)
    holder:SetAllPoints(f)
    if holder.SetFrameLevel and f.GetFrameLevel then holder:SetFrameLevel(f:GetFrameLevel() or 1) end
    T.tabHolder = holder
    local prev = f.AuctionsTab
    for i, def in ipairs(T.TABS) do
        local ok, tab = pcall(CreateFrame, "Button", "PeonBrokerAHTab" .. i, holder, TabTemplate())
        if not ok or not tab then
            tab = CreateFrame("Button", "PeonBrokerAHTab" .. i, holder, "PanelTabButtonTemplate")
        end
        tab:SetText(L[def.label])
        tab:SetPoint("LEFT", prev, "RIGHT", T.TAB_GAP, 0)
        tab:SetScript("OnClick", function() mod:Call("Auktionshaus-Reiter", T.Open, def.key) end)
        if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 20, nil, 70) end
        Deselect(tab)
        T.tabs[def.key] = tab
        prev = tab
    end
    -- "Kaufen" heisst "Markt" (nur der Text, nichts in Blizzards Tabellen). Ab 0.59 bleibt "Auktionen" an seinem Platz.
    if type(f.BuyTab) == "table" and f.BuyTab.SetText then
        f.BuyTab:SetText(L.AHTAB_MARKET)
        if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, f.BuyTab, 20, nil, 70) end
    end

    -- Flaeche ueber Blizzards ganzem Inhalt (ab der Titelleiste), faengt die Maus ab. Sie liegt unter dem runden Bild
    -- und dem Metallrahmen (T.PAGE_LEVEL), darum braucht sie keine Aussparung mehr.
    local p = CreateFrame("Frame", "PeonBrokerAHPage", f)
    p:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -22)
    p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    if p.SetFrameLevel and f.GetFrameLevel then p:SetFrameLevel(math.min((f:GetFrameLevel() or 1) + T.PAGE_LEVEL, 390)) end
    if p.EnableMouse then p:EnableMouse(true) end
    -- undurchsichtiger Grund, darueber derselbe Hintergrund wie Blizzards Fenster (T.CopyFrameBg)
    local under = p:CreateTexture(nil, "BACKGROUND", nil, -8)
    under:SetAllPoints(p)
    under:SetColorTexture(0.05, 0.05, 0.05, 1)
    local bg = p:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetAllPoints(p)
    if not T.CopyFrameBg(f, bg) then bg:SetColorTexture(0.08, 0.08, 0.08, 1) end
    -- ab 0.59: Statuszeile wie im Broker-Fenster (liegt ueber Blizzards Geldanzeige, zeigt das Gold selbst)
    if Peon.UI and ns.Window and ns.Window.NewStatus then
        local bar = ns.Window.NewStatus(p)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 2, 27)
        bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 3)
        if bar.SetFrameLevel and p.GetFrameLevel then bar:SetFrameLevel((p:GetFrameLevel() or 1) + 6) end
        T.status = bar
    end
    p:SetScript("OnShow", function() if ns.Window then ns.Window.FillStatus(T.status) end end)
    p:Hide()
    T.page = p

    -- Blizzard wechselt die Ansicht: Flaeche weg (sicherer Anhang, veraendert Blizzards Ablauf nicht)
    if hooksecurefunc then hooksecurefunc(f, "SetDisplayMode", function() mod:Call("Auktionshaus-Reiter", T.OnDisplayMode) end) end
    if f.HookScript then f:HookScript("OnHide", function() mod:Call("Auktionshaus-Reiter", T.OnAHHide) end) end

    -- ab 0.59: Knopf "Zurueck zu ..." nach einem Sprung. Auf Brokers Seiten links in der Titelleiste, in Blizzards
    -- Kaufansicht rechts neben Blizzards "Zurueck" (T.PlaceBack, KarloDerBaer 11.11.2026)
    if ns.Window and ns.Window.NewBack then
        local b = ns.Window.NewBack(holder, f)
        if b.SetFrameLevel and f.GetFrameLevel then b:SetFrameLevel((f:GetFrameLevel() or 1) + T.TOP_LEVEL) end
        T.back = b
    end

    T.built = true
    mod:Dbg("Eigene Reiter im Auktionshaus angelegt")
    return true
end

---------------------------------------------------------------------------
-- Flaechen umhaengen (ab 0.48, U7): Die Flaeche des Broker-Fensters (W.contents[key]) wandert in den Reiter und
-- zurueck. Alle Knoepfe und Listen bleiben dieselben.
---------------------------------------------------------------------------
function T.Attach(key)
    local W = ns.Window
    local f = AHFrame()
    if not W or not T.page or not f or not W.pages[key] then return false end
    if W.IsOpen() then W.frame:Hide() end   -- nicht an zwei Stellen zugleich
    for k, c in pairs(W.contents) do
        if k ~= key and T.host[k] == "ah" then c:Hide() end   -- ab 0.54: andere Seiten im Auktionshaus verstecken
    end
    local c = W.Content(key, T.page, f)
    if c.SetFrameLevel and T.page.GetFrameLevel then c:SetFrameLevel((T.page:GetFrameLevel() or 1) + 5) end
    c:Show()
    T.host[key] = "ah"
    local page = W.pages[key]
    if page.refresh and not W.WIP[key] then mod:Call("Auktionshaus-Reiter", page.refresh) end
    return true
end

-- Das Broker-Fenster will die Seite zurueck (W.OnTab haengt sie danach selbst um)
function T.Release(key)
    if T.host[key] ~= "ah" then return end
    if T.current == key then T.Close() end
    T.host[key] = "window"
end

-- Das Auktionshaus schliesst: Reiter zu, Stelle merken (dort oeffnet unterwegs das Broker-Fenster)
function T.OnAHHide()
    T.Close()
    local f = AHFrame()
    if f and f.GetLeft and f.GetTop then
        local x, y = f:GetLeft(), f:GetTop()
        if type(x) == "number" and type(y) == "number" then mod.acc.ahPos = { x = math.floor(x + 0.5), y = math.floor(y + 0.5) } end
    end
    if ns.Go then ns.Go.Clear() end
end

---------------------------------------------------------------------------
-- Zahl am Reiter (ab 0.48): "Radar (3)", blinkt bis zum Oeffnen (blink), "Einkaufen (5)" ohne Blinken
---------------------------------------------------------------------------
T.BLINK_SPEED = 2.5   -- Wechsel je Sekunde

function T.SetBadge(key, n, blink)
    local tab = T.tabs[key]
    if n == nil or n <= 0 then T.badges[key] = nil else T.badges[key] = { n = n, blink = blink and T.current ~= key } end
    if ns.Window and ns.Window.ApplyBadges then ns.Window.ApplyBadges() end   -- ab 0.59: gleiche Zahl im Broker-Fenster
    if not tab then return end
    local def
    for _, d in ipairs(T.TABS) do if d.key == key then def = d end end
    local b = T.badges[key]
    tab:SetText(L[def.label] .. (b and (" (" .. b.n .. ")") or ""))
    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 20, nil, 70) end
    T.AlignSoon()
    if b and b.blink then
        tab.blinkT = 0
        tab:SetScript("OnUpdate", function(self, dt)
            self.blinkT = (self.blinkT or 0) + (dt or 0)
            local a = 0.55 + 0.45 * math.abs(math.sin(self.blinkT * T.BLINK_SPEED))
            if self.Text and self.Text.SetAlpha then self.Text:SetAlpha(a) end
        end)
    else
        tab:SetScript("OnUpdate", nil)
        if tab.Text and tab.Text.SetAlpha then tab.Text:SetAlpha(1) end
    end
end

-- Nach einem Komplettscan: Treffer im Radar zaehlen (blinkt), Einkaufen kommt mit U8
function T.OnScanDone()
    if not T.built or ns.AHPlain() then return end
    local R = ns.Radar
    if R and R.LoadFromScan and R.CountHits then
        R.LoadFromScan()
        local n = R.CountHits()
        T.SetBadge("radar", n, n > 0)
        T.lastScanHits = n
    end
end

function T.OnAHShow()
    if ns.AHPlain() then return end
    -- ab 0.59: ein Fenster. Ist das Broker-Fenster offen, schliesst es, und sein Reiter oeffnet im Auktionshaus.
    T.Build()
    T.AlignSoon()
    if not T.built then return end   -- ohne eigene Reiter (Aufbau gescheitert) bleibt das Fenster, wie es ist
    local W = ns.Window
    local was = W and W.IsOpen() and W.current or nil
    if was then W.frame:Hide() end
    if was and T.IsHosted(was) then T.Open(was) end
end

function T.Init()
    Dialogs()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function() mod:Call("Auktionshaus-Reiter", T.OnAHShow) end)
    mod:RegisterEvent("ADDON_ACTION_BLOCKED", function(_, addon, fn) mod:Call("Blizzard pur", T.OnBlocked, "ADDON_ACTION_BLOCKED", addon, fn) end)
    mod:RegisterEvent("ADDON_ACTION_FORBIDDEN", function(_, addon, fn) mod:Call("Blizzard pur", T.OnBlocked, "ADDON_ACTION_FORBIDDEN", addon, fn) end)
    mod:On("SCAN_DONE", function() mod:Call("Auktionshaus-Reiter", T.OnScanDone) end)
    if ns.AHPlain() then mod:Print(L.AH_PLAIN_ACTIVE) end
end
