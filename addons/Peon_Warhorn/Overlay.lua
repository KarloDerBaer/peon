-- Peon_Warhorn - Overlay.lua
-- Legt die Warhorn-Flaeche ueber Blizzards Suchseite (LFGBrowseFrame in der Gruppensuche im Vanilla-Stil).
--   * Die Flaeche haengt an LFGBrowseFrame: Blizzard zeigt die Suchseite nur auf dem Reiter "Suchen", auf den
--     anderen Reitern ist Warhorn darum von selbst weg. Sie wandert mit, wenn Peon_Mover das Fenster verschiebt.
--   * Unten endet sie ueber Blizzards Reitern (LFGParentFrameTab1), damit diese bedienbar bleiben.
--   * Umschalten ohne Neuladen: Warhorn schreibt nichts in Blizzards Tabellen. Der Knopf "Warhorn" an Blizzards
--     Fenster ist ein eigener Rahmen, nur angehaengt.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local O = {}
ns.Overlay = O

O.LEVEL_UP = 20     -- so viel hoeher als Blizzards Suchseite liegt Warhorn
O.TAB_X = 16        -- Blizzard setzt LFGParentFrameTab1 auf BOTTOMLEFT 16, 45 (Blizzard_LFGVanilla_Browse.lua)

function O.Available()
    return _G.LFGBrowseFrame ~= nil and _G.LFGParentFrame ~= nil
end

function O.Build()
    if O.built or not O.Available() then return O.built end
    if not Peon.UI then
        if not O.warned then O.warned = true; mod:Print(L.MSG_NO_UI) end
        return false
    end
    local browse, parent = LFGBrowseFrame, LFGParentFrame
    ns.Search.EnsureSelection()
    local f = ns.Window.Create(browse)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    local tab = _G.LFGParentFrameTab1
    if tab then
        f:SetPoint("BOTTOMLEFT", tab, "TOPLEFT", -O.TAB_X, -4)
    else
        f:SetHeight((parent:GetHeight() or 535) - 80)
    end
    if f.SetFrameLevel and browse.GetFrameLevel then f:SetFrameLevel((browse:GetFrameLevel() or 1) + O.LEVEL_UP) end

    -- Knopf "Warhorn" oben an Blizzards Suchseite (sichtbar, wenn Blizzard gezeigt wird)
    local b = Peon.UI.Button(browse, L.BTN_WARHORN, 90, function() O.SetShow(true) end)
    b:SetPoint("TOPRIGHT", browse, "TOPRIGHT", -30, -1)
    if b.SetFrameLevel and browse.GetFrameLevel then b:SetFrameLevel((browse:GetFrameLevel() or 1) + 10) end
    Peon.UI.SetTooltip(b, { L.BTN_WARHORN, L.BTN_WARHORN_TIP })
    O.button = b
    O.frame = f
    O.built = true
    O.Apply()
    mod:Dbg("Flaeche ueber der Gruppensuche angelegt")
    return true
end

function O.Apply()
    if not O.built then return end
    local show = mod.db and mod.db.show ~= false
    O.frame:SetShown(show)
    O.button:SetShown(not show)
    if show then ns.Window.Update() end
end

function O.SetShow(on)
    if not mod.db then return end
    mod.db.show = on and true or false
    O.Apply()
    if mod.page then mod.page:Refresh() end
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

mod:On("COMBAT_START", function() if ns.Window.frame then ns.Window.Update() end end)
mod:On("COMBAT_END", function() if ns.Window.frame then ns.Window.Update() end end)
