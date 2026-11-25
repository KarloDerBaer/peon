-- Peon_Warhorn - Overlay.lua
-- Legt das Warhorn-Fenster ueber Blizzards Gruppensuche (Gruppensuche im Vanilla-Stil, LFGParentFrame).
--   * Ab 0.3.0 haengt es an Blizzards ganzem Fenster und zeigt je nach Blizzards Reiter die passende Seite:
--     Eintragen (LFGListingFrame), Suchen (LFGBrowseFrame), Wer-Liste (LFGWhoListFrame). Dazu ein eigener
--     Reiter Einstellungen unter Blizzards Reitern rechts. Je Seite waehlbar: Warhorn oder Blizzard.
--   * Es wandert mit, wenn Peon_Mover das Fenster verschiebt.
--   * Schicht HIGH (ab 0.2.1): Blizzards Seiten sind selbst Fenster mit Rahmen auf hoher Ebene.
--   * Unten reicht es bis an Blizzards Reiter (alter Stil, LFGParentFrameTab1) oder bis an den Fensterrand
--     (moderner Stil, Reiter rechts am Fenster). Die Reiter rechts wandern an Warhorns rechten Rand, solange
--     Warhorn zu sehen ist, und zurueck, wenn es weg ist. Warhorn aendert dafuer nur ihren Anker.
--   * Oeffnet der Spieler die Gruppensuche auf einer Seite, die Blizzard zeigt, springt sie auf "Suchen",
--     wenn Warhorn dort eingeschaltet ist. Fragt Blizzard selbst einen Reiter an, gilt Blizzards Wahl.
--   * Umschalten ohne Neuladen: Warhorn schreibt nichts in Blizzards Tabellen. Die Knoepfe "Warhorn" an
--     Blizzards Seiten und der Reiter Einstellungen sind eigene Rahmen, nur angehaengt.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local O = { once = {}, buttons = {} }
ns.Overlay = O

O.TAB_X = 16        -- Blizzard setzt LFGParentFrameTab1 auf BOTTOMLEFT 16, 45 (Blizzard_LFGVanilla_Browse.lua)
O.PAGE_OF_TAB = { "listing", "search", "who" }
O.BLIZZ = { listing = "LFGListingFrame", search = "LFGBrowseFrame", who = "LFGWhoListFrame" }
O.SIDE_TABS = { "ListingTab", "BrowsingTab", "WhoListingTab" }
O.SETTINGS_ICON = "Interface\\Icons\\INV_Misc_Gear_01"

function O.Available()
    return _G.LFGBrowseFrame ~= nil and _G.LFGParentFrame ~= nil
end

local function Blizz(key) return rawget(_G, O.BLIZZ[key]) end

---------------------------------------------------------------------------
-- Was gezeigt wird
---------------------------------------------------------------------------
-- Warhorn ersetzt diese Seite (Einstellung, unabhaengig vom kurzen Blick auf Blizzard)
function O.IsReplaced(key)
    local db = mod.db
    if not db or db.show == false then return false end
    return not (type(db.replace) == "table" and db.replace[key] == false)
end

local function Shows(key) return O.IsReplaced(key) and not O.once[key] end

-- Seite nach Blizzards Reiter. Ab 0.3.2 zaehlt zuerst Blizzards selectedTab: Blizzard setzt ihn vor dem Wechsel
-- der Seiten und zeigt die neue Seite, bevor es die alte versteckt. In 0.3.0 und 0.3.1 fand Warhorn darum beim
-- Klick auf Eintragen noch die Suchseite offen und blieb dort oder zeigte Blizzards Seite.
function O.CurrentPage()
    local parent = _G.LFGParentFrame
    local key = parent and O.PAGE_OF_TAB[parent.selectedTab]
    if key then return key end
    for k in pairs(O.BLIZZ) do
        local fr = Blizz(k)
        if fr and fr.IsShown and fr:IsShown() then return k end
    end
    return "search"
end

function O.Apply()
    if not O.built then return end
    O.Layout()
    local page = O.settings and "settings" or O.CurrentPage()
    local visible = O.settings or Shows(page)
    if visible then ns.Window.ShowPage(page); O.Raise() end
    O.frame:SetShown(visible and true or false)
    for key, b in pairs(O.buttons) do b:SetShown(not Shows(key)) end
    O.MoveSideTabs(visible and O.frame:IsVisible())
    O.UpdateSettingsTab()
    O.page = visible and page or nil
    if visible then
        if page == "search" then ns.Window.Update()
        elseif page == "listing" and ns.Listing.Update then ns.Listing.Update()
        elseif page == "who" and ns.Who.Update then ns.Who.Update()
        elseif page == "settings" and ns.Settings.Update then ns.Settings.Update() end
    end
end

-- Warhorn oder Blizzard fuer eine Seite (Knoepfe und Einstellungen)
function O.SetReplace(key, on)
    if not mod.db then return end
    if type(mod.db.replace) ~= "table" then mod.db.replace = {} end
    mod.db.replace[key] = on and true or false
    if on then
        mod.db.show = true
        O.once[key] = nil
    end
    O.Apply()
    if mod.page then mod.page:Refresh() end
end

-- Hauptschalter aus den Optionen (alle Seiten)
function O.SetShow(on)
    if not mod.db then return end
    mod.db.show = on and true or false
    if on then O.once = {} end
    O.Apply()
    if mod.page then mod.page:Refresh() end
end

-- Fuer einen Schritt Blizzards Seite zeigen (Kommentar beim Eintragen). Zurueck mit dem Knopf Warhorn oder
-- von selbst, sobald Blizzards Seite zugeht.
function O.ShowBlizzardOnce(key)
    O.once[key] = true
    O.settings = false
    O.Apply()
end

---------------------------------------------------------------------------
-- Reiter Einstellungen
---------------------------------------------------------------------------
function O.OpenSettings()
    O.settings = true
    local parent = _G.LFGParentFrame
    for _, k in ipairs(O.SIDE_TABS) do
        local t = parent and parent[k]
        if type(t) == "table" and type(t.SetChecked) == "function" then pcall(t.SetChecked, t, false) end
    end
    O.Apply()
end

function O.CloseSettings()
    if not O.settings then return end
    O.settings = false
    local parent = _G.LFGParentFrame
    if parent and type(parent.UpdateTabs) == "function" then pcall(parent.UpdateTabs, parent) end
    O.Apply()
end

function O.CreateSettingsTab(parent)
    local UI = Peon.UI
    local tab = UI.TryFrame("Frame", "PeonWarhornSettingsTab", parent, "LargeSideTabButtonTemplate")
    if tab and type(tab.Icon) == "table" and tab.Icon.SetTexture then
        tab.Icon:SetTexture(O.SETTINGS_ICON)
        if tab.Icon.SetSize then tab.Icon:SetSize(30, 30) end
        if tab.Icon.SetTexCoord then tab.Icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875) end
        tab.tooltipText = L.SETTINGS_TAB
        O.tabStyle = "blizzard"
    else
        tab = CreateFrame("Button", "PeonWarhornSettingsTab", parent)
        tab:SetSize(44, 44)
        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
        bg:SetSize(64, 64)
        bg:SetPoint("TOPLEFT", -3, 11)
        local ic = tab:CreateTexture(nil, "ARTWORK")
        ic:SetSize(32, 32)
        ic:SetPoint("CENTER", -2, 0)
        ic:SetTexture(O.SETTINGS_ICON)
        tab.Icon = ic
        UI.SetTooltip(tab, { L.SETTINGS_TAB, L.SETTINGS_TAB_TIP })
        O.tabStyle = "own"
    end
    if tab.EnableMouse then tab:EnableMouse(true) end
    if O.tabStyle == "blizzard" and type(tab.SetCustomOnMouseUpHandler) == "function" then
        tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
            if button == "LeftButton" and upInside ~= false then mod:Call("Einstellungen", O.OpenSettings) end
        end)
    else
        tab:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then mod:Call("Einstellungen", O.OpenSettings) end
        end)
    end
    O.settingsTab = tab
    return tab
end

-- Reiter Einstellungen unten am rechten Rand (ab 0.3.2, Wunsch KarloDerBaer), an Warhorn oder an Blizzards Fenster
O.TAB_BOTTOM = 40
function O.UpdateSettingsTab()
    local tab, parent = O.settingsTab, _G.LFGParentFrame
    if not tab then return end
    tab:ClearAllPoints()
    if O.frame and O.frame:IsShown() then
        tab:SetPoint("BOTTOMLEFT", O.frame, "BOTTOMRIGHT", 0, O.TAB_BOTTOM)
    elseif O.IsModern() then
        tab:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 0, O.TAB_BOTTOM)
    else
        tab:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", -30, 74 + O.TAB_BOTTOM)
    end
    if type(tab.SetChecked) == "function" then pcall(tab.SetChecked, tab, O.settings == true) end
end

---------------------------------------------------------------------------
-- Aufbau
---------------------------------------------------------------------------
function O.Build()
    if O.built or not O.Available() then return O.built end
    if not Peon.UI then
        if not O.warned then O.warned = true; mod:Print(L.MSG_NO_UI) end
        return false
    end
    local parent = LFGParentFrame
    ns.Search.EnsureSelection()
    local W = ns.Window
    local f = W.Create(parent)
    O.frame = f
    O.Layout()
    if ns.Listing and ns.Listing.Create then mod:Call("Eintragen", ns.Listing.Create, W.NewPage("listing")) end
    if ns.Who and ns.Who.Create then mod:Call("Wer-Liste", ns.Who.Create, W.NewPage("who")) end
    if ns.Settings and ns.Settings.Create then mod:Call("Einstellungen", ns.Settings.Create, W.NewPage("settings")) end

    f:HookScript("OnShow", function() O.Layout(); O.Raise(); O.MoveSideTabs(true); O.UpdateSettingsTab() end)
    f:HookScript("OnHide", function() O.MoveSideTabs(false); O.UpdateSettingsTab() end)
    if parent.HookScript then
        parent:HookScript("OnShow", function()
            mod:Call("Gruppensuche oeffnen", O.OnParentShow)
            -- Blizzard hebt sein Fenster teils erst nach dem Zeigen an (Dungeon-Journal), darum noch einmal danach
            O.RaiseSoon()
        end)
        parent:HookScript("OnHide", function() O.settings = false; O.once = {} end)
    end

    -- Blizzards Seiten: Wechsel der Seite, Knopf "Warhorn" oben (sichtbar, wenn Blizzard gezeigt wird)
    for key in pairs(O.BLIZZ) do
        local page = Blizz(key)
        if page and page.HookScript then
            page:HookScript("OnShow", function() O.settings = false; mod:Call("Seite", O.Apply) end)
            page:HookScript("OnHide", function() O.once[key] = nil end)
            local b = Peon.UI.Button(page, L.BTN_WARHORN, 90, function() O.SetReplace(key, true) end)
            b:SetPoint("TOPRIGHT", page, "TOPRIGHT", -30, -1)
            -- ab 0.3.1 in der Schicht HIGH: Blizzards Seite Eintragen hat Teile auf Ebene 501, der Knopf lag darunter
            if b.SetFrameStrata then b:SetFrameStrata("HIGH") end
            if b.SetFrameLevel then b:SetFrameLevel(ns.Window.LEVEL) end
            Peon.UI.SetTooltip(b, { L.BTN_WARHORN, L.BTN_WARHORN_TIP })
            O.buttons[key] = b
        end
    end
    O.button = O.buttons.search
    -- Blizzards Reiter verlassen die Einstellungen, auch wenn ihre Seite schon offen ist
    for _, k in ipairs(O.SIDE_TABS) do
        local t = parent[k]
        if type(t) == "table" and type(t.HookScript) == "function" then
            t:HookScript("OnMouseUp", function() mod:Call("Einstellungen", O.CloseSettings) end)
        end
    end
    for i = 1, 3 do
        local t = rawget(_G, "LFGParentFrameTab" .. i)
        if type(t) == "table" and type(t.HookScript) == "function" then
            t:HookScript("OnClick", function() mod:Call("Einstellungen", O.CloseSettings) end)
        end
    end
    mod:Call("Reiter Einstellungen", O.CreateSettingsTab, parent)

    O.built = true
    O.Apply()
    -- Beim ersten Oeffnen nach /reload laedt das Spiel die Gruppensuche erst jetzt, Warhorn entsteht dann bei schon
    -- offenem Fenster und sein OnShow-Haken kommt zu spaet. Die spaeten Pruefungen darum auch hier.
    if parent.IsShown and parent:IsShown() then O.RaiseSoon() end
    mod:Dbg("Fenster ueber der Gruppensuche angelegt")
    return true
end

-- Moderner Stil: Blizzards Schalter, sonst Reiter unten versteckt. Ab 0.3.1 zuerst der Schalter: Seit Warhorn
-- an Blizzards ganzem Fenster haengt, kommt sein OnShow vor Blizzards eigenem, die Reiter unten sind dann noch
-- nicht versteckt (0.3.0 hielt den modernen Stil darum fuer den alten und endete zu weit oben).
function O.IsModern()
    if rawget(_G, "LFGVANILLA_SETTING_MODERN_STYLE") then return true end
    local tab = _G.LFGParentFrameTab1
    return not (tab and tab.IsShown and tab:IsShown())
end

-- Groesse wie Ledger (Window.lua). Im alten Stil endet Warhorn ueber Blizzards Reitern unten.
function O.Layout()
    local f, parent = O.frame, _G.LFGParentFrame
    if not (f and parent) then return end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    if O.IsModern() then
        f:SetHeight(ns.Window.HEIGHT)
        O.style = "modern"
    else
        f:SetPoint("BOTTOMLEFT", _G.LFGParentFrameTab1, "TOPLEFT", -O.TAB_X, -4)
        O.style = "classic"
    end
end

-- Ab 0.3.4: Warhorn liegt immer eine Schicht ueber Blizzards Fenster (mindestens HIGH).
-- ForeverDungeonJournal setzt Blizzards Fenster beim Klick auf sein Auge in die Schicht DIALOG (LFGButton.lua,
-- PostClick). Warhorn rutschte mit in DIALOG, und in derselben Schicht zeichnete das Spiel Blizzards Seiten ueber
-- Warhorn, obwohl Warhorn die hoehere Ebene hatte. Bis 0.3.3 lag es dann bis zum /reload darunter.
-- In einer eigenen Schicht kommt es auf die Ebenen nicht an. Nur in HIGH zaehlt weiter die Ebene: Blizzards
-- Seiten haben dort selbst Teile (Suchfeld der Wer-Liste).
O.STRATA_ORDER = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
O.STRATA_RANK = {}
for i, s in ipairs(O.STRATA_ORDER) do O.STRATA_RANK[s] = i end
O.LEVEL_GAP = 20
O.LEVEL_MAX = 9000
O.SCAN_DEPTH = 3

-- Schicht direkt ueber der genannten (hoechstens FULLSCREEN_DIALOG, TOOLTIP bleibt den Tooltips)
function O.Above(strata)
    local r = O.STRATA_RANK[strata] or O.STRATA_RANK.MEDIUM
    return O.STRATA_ORDER[math.min(r + 1, O.STRATA_RANK.FULLSCREEN_DIALOG)]
end

-- Das Journal setzt die Schicht erst nach dem Oeffnen, darum kurz danach noch einmal
O.RAISE_DELAYS = { 0, 0.3, 1 }
function O.RaiseSoon()
    if not (C_Timer and C_Timer.After) then return end
    for _, d in ipairs(O.RAISE_DELAYS) do C_Timer.After(d, function() mod:Call("Ebene", O.Raise) end) end
end

-- Eigene Fenster (Fluestern, Platzhalter) ueber Warhorn: mindestens DIALOG, sonst eine Schicht ueber Warhorn
function O.AboveWarhorn(frame)
    if not (frame and frame.SetFrameStrata) then return end
    local s = O.Above(O.strata or ns.Window.STRATA)
    frame:SetFrameStrata((O.STRATA_RANK[s] or 0) > O.STRATA_RANK.DIALOG and s or "DIALOG")
end

local function StrataOf(fr)
    if type(fr) == "table" and type(fr.GetFrameStrata) == "function" then return fr:GetFrameStrata() end
    return type(fr) == "table" and fr.strata or nil
end

function O.Raise()
    local f, parent = O.frame, _G.LFGParentFrame
    if not (f and parent and f.SetFrameStrata and f.SetFrameLevel) then return end
    local W, RANK = ns.Window, O.STRATA_RANK
    local strata = O.Above(StrataOf(parent) or "MEDIUM")
    if (RANK[strata] or 0) < (RANK[W.STRATA] or 0) then strata = W.STRATA end
    -- hoechste Ebene von Blizzards Teilen in dieser Schicht (Warhorns eigene Rahmen ausgenommen)
    local skip = { [f] = true }
    for _, b in pairs(O.buttons) do skip[b] = true end
    if O.settingsTab then skip[O.settingsTab] = true end
    local top = 0
    local function Look(fr, depth)
        if type(fr) ~= "table" or skip[fr] then return end
        if StrataOf(fr) == strata and type(fr.GetFrameLevel) == "function" then
            local lv = fr:GetFrameLevel()
            if type(lv) == "number" and lv > top then top = lv end
        end
        if depth < O.SCAN_DEPTH and type(fr.GetChildren) == "function" then
            for _, c in ipairs({ fr:GetChildren() }) do Look(c, depth + 1) end
        end
    end
    Look(parent, 0)
    local level = math.min(O.LEVEL_MAX, math.max(W.LEVEL, top + O.LEVEL_GAP))
    local moved = StrataOf(f) ~= strata
    if moved then f:SetFrameStrata(strata) end
    if (f:GetFrameLevel() or 0) < level then f:SetFrameLevel(level) end
    for _, b in pairs(O.buttons) do
        if b.SetFrameStrata then b:SetFrameStrata(strata) end
        if b.SetFrameLevel and (b:GetFrameLevel() or 0) < level then b:SetFrameLevel(level) end
    end
    O.strata, O.level = strata, level
    -- Neue Schicht bei offenem Fenster: einmal aus- und wieder einblenden, damit das Spiel sie sicher uebernimmt
    if moved and not O.refreshing and f:IsShown() then
        O.refreshing = true
        f:Hide()
        f:Show()
        O.refreshing = false
        O.refreshed = (O.refreshed or 0) + 1
    end
end

-- Reiter rechts am Fenster (moderner Stil) an Warhorns rechten Rand und zurueck. Die anderen beiden Reiter
-- haengen bei Blizzard am ersten, wandern also mit.
function O.MoveSideTabs(toWarhorn)
    local parent = _G.LFGParentFrame
    local tab = parent and parent.ListingTab
    if type(tab) ~= "table" or type(tab.GetPoint) ~= "function" or type(tab.SetPoint) ~= "function" then return end
    if toWarhorn then
        if not (tab.IsShown and tab:IsShown()) or O.sideMoved then return end
        if not O.sidePoint then
            local ok, p1, rel, p2, x, y = pcall(tab.GetPoint, tab, 1)
            if not ok or not p1 then return end
            O.sidePoint = { p1, rel, p2, x, y }
        end
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", O.frame, "TOPRIGHT", 0, O.sidePoint[5] or -60)
        O.sideMoved = true
    elseif O.sideMoved and O.sidePoint then
        local sp = O.sidePoint
        tab:ClearAllPoints()
        tab:SetPoint(sp[1], sp[2], sp[3], sp[4], sp[5])
        O.sideMoved = false
    end
end

-- Blizzards Gruppensuche geht auf einer Seite auf, die Blizzard zeigt: auf "Suchen" springen, wenn Warhorn
-- dort eingeschaltet ist
-- Ab 0.3.2 sucht Warhorn dabei gleich (Wunsch KarloDerBaer): Der Klick auf den Menueknopf oder die Taste
-- zaehlt fuer das Spiel. Nur auf der Seite Suchen, so oeffnet Blizzards Wer-Antwort (Reiter 3, kein Klick) nie
-- eine Suche. Hoechstens alle O.OPEN_GAP Sekunden.
O.OPEN_GAP = 5

-- Ab 0.6.1 (Fehlerbericht 71 in peon-fehler): Oeffnet ein anderes Addon die Gruppensuche ueber Blizzards
-- ShowSearchForActivities (etwa das Auge im ForeverDungeonJournal), sucht Blizzard dort selbst. Eine
-- zweite Suche von Warhorn in diesem Moment blockiert das Spiel (ADDON_ACTION_BLOCKED), darum dann nicht.
function O.OpenedForSearch()
    local ds = rawget(_G, "debugstack")
    if type(ds) ~= "function" then return false end
    local ok, stack = pcall(ds, 2, 40, 0)
    return ok and type(stack) == "string" and stack:find("ShowSearchForActivities", 1, true) ~= nil
end

-- Blizzards Reiter Suchen waehlen, wenn Warhorn dort eingeschaltet ist (ab 0.4.0 auch fuer das Dungeon-Journal)
function O.ShowSearchTab()
    if not (mod.db and mod.db.show ~= false) or Peon.InCombat() then return false end
    local parent = _G.LFGParentFrame
    if not (parent and Shows("search")) or parent.selectedTab == 2 then return false end
    local fn = rawget(_G, "LFGParentFrameTab2_OnClick")
    if type(fn) ~= "function" then return false end
    fn()
    return true
end

function O.OnParentShow()
    if not (mod.db and mod.db.show ~= false) or Peon.InCombat() then return end
    if not Shows(O.CurrentPage()) then O.ShowSearchTab() end
    if O.CurrentPage() == "search" and Shows("search") and not O.OpenedForSearch() then
        local S = ns.Search
        local now = GetTime and GetTime() or 0
        if not S.searching and not (S.requestedAt and now - S.requestedAt < O.OPEN_GAP) then
            S.requestedAt = now
            S.Search()
        end
    end
end

-- /warhorn, Starter: Blizzards Gruppensuche auf dem Reiter Suchen oeffnen oder schliessen
function O.Toggle()
    if Peon.InCombat() then mod:Print(L.MSG_COMBAT) return end
    local fn = rawget(_G, "LFGVanilla_ToggleFrame")
    if type(fn) ~= "function" then
        local load = rawget(_G, "GroupFinderVanillaStyle_LoadUI")
        if type(load) == "function" then pcall(load) end
        fn = rawget(_G, "LFGVanilla_ToggleFrame")
    end
    if type(fn) ~= "function" then mod:Print(L.MSG_NO_LFG) return end
    local ok, err = pcall(fn, 2)
    if not ok then mod:ReportError("Gruppensuche oeffnen", err) end
    O.Build()
end

function O.Init()
    O.Build()
end

-- Blizzards Gruppensuche wird bei Bedarf geladen (Blizzard_GroupFinder_VanillaStyle)
mod:RegisterEvent("ADDON_LOADED", function(event, name)
    if name == "Blizzard_GroupFinder_VanillaStyle" and mod.initialized then mod:Call("Overlay", O.Build) end
end)

local function CombatChanged()
    if not ns.Window.frame then return end
    ns.Window.Update()
    if ns.Listing.Update then ns.Listing.Update() end
    if ns.Who.Update then ns.Who.Update() end
end
mod:On("COMBAT_START", CombatChanged)
mod:On("COMBAT_END", CombatChanged)
