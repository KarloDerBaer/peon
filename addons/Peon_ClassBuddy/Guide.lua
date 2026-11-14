-- Peon_ClassBuddy - Guide.lua
-- Vorlaeufiges Fenster fuer Hexenmeister (ab 0.1.0): fuehrt durch die Pruefung der Seelensplitter (Probe.lua)
-- und schickt das Ergebnis ueber Peon_Feedback an den Peon Manager. Erscheint beim Einloggen mit einem Hexenmeister,
-- bis "Nicht mehr anzeigen" angehakt ist. Faellt mit der naechsten Version wieder weg.
-- Oeffnen jederzeit mit /peon classbuddy pruefen.

local ADDON_NAME, ns = ...
local L = ns.L

local G = {}
ns.Guide = G

local WAYS = { "event", "click", "macro", "action" }
local W, H = 470, 600
local win, cells, sentText

local function StatusText(r)
    if not r then return "|cff9d9d9d" .. L.G_OPEN .. "|r" end
    if r.ok then return "|cff40ff40" .. L.P_DONE .. "|r" end
    return "|cffff8040" .. tostring(r.why) .. "|r"
end

local function Build()
    local UI = Peon.UI
    if not (UI and UI.Window) then return nil end
    win = UI.Window("PeonClassBuddyGuideFrame", { title = L.G_TITLE, width = W, height = H,
        icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02" })

    local y = -34
    local function Line(text, role, gap)
        local fs = UI.Text(win, role or "text", text, W - 40)
        fs:SetPoint("TOPLEFT", 20, y)
        y = y - (fs:GetStringHeight() or 12) - (gap or 6)
        return fs
    end

    Line("|cffffd100" .. L.G_TEMP .. "|r", "text", 8)
    Line(L.G_WHY, "text", 10)

    -- Schritte mit Knoepfen
    local function Step(text, btnText, fn, width)
        local fs = Line(text, "text", 4)
        if btnText then
            local b = UI.Button(win, btnText, width or 190, function() ns.mod:Call("Fenster", fn) end)
            b:SetPoint("TOPLEFT", 36, y)
            y = y - 28
        end
        return fs
    end
    Step(L.G_STEP1, L.G_BTN_START, function() ns.Probe.Start() end)
    Step(L.G_STEP2, L.P_BUTTON, function() ns.Probe.ClickTest() end)
    Step(L.G_STEP3, L.G_BTN_MACRO, function() ns.Probe.MakeMacro() end)
    Step(L.G_STEP4)
    Step(L.G_STEP5)

    -- Stand je Weg: kein Kampf, Kampf
    y = y - 4
    local head = UI.Text(win, "label", L.G_STATE, 150)
    head:SetPoint("TOPLEFT", 20, y)
    local h1 = UI.Text(win, "label", L.P_FREE, 130); h1:SetPoint("TOPLEFT", 180, y)
    local h2 = UI.Text(win, "label", L.P_COMBAT, 130); h2:SetPoint("TOPLEFT", 320, y)
    y = y - 18
    cells = {}
    for _, way in ipairs(WAYS) do
        local name = UI.Text(win, "text", L.P_WAY[way], 150); name:SetPoint("TOPLEFT", 20, y)
        local c1 = UI.Text(win, "text", "", 135); c1:SetPoint("TOPLEFT", 180, y)
        local c2 = UI.Text(win, "text", "", 135); c2:SetPoint("TOPLEFT", 320, y)
        cells[way] = { c1, c2 }
        y = y - 18
    end

    y = y - 8
    Step(L.G_STEP6, L.G_BTN_SEND, function() ns.Probe.Send() end)
    sentText = Line("", "text", 4)

    local cb = UI.Check(win, L.G_HIDE, ns.mod.db and ns.mod.db.hideGuide, function(on)
        if ns.mod.db then ns.mod.db.hideGuide = on end
    end)
    cb:SetPoint("BOTTOMLEFT", 14, 10)
    return win
end

function G.Refresh()
    if not (win and cells) then return end
    for _, way in ipairs(WAYS) do
        cells[way][1]:SetText(StatusText(ns.Probe.Result(way, false)))
        cells[way][2]:SetText(StatusText(ns.Probe.Result(way, true)))
    end
    local p = ns.mod.db and ns.mod.db.probe
    if sentText then
        sentText:SetText((p and p.sent) and ("|cff40ff40" .. L.G_SENT .. "|r") or "")
    end
end

function G.Show()
    if not win and not Build() then return false end
    G.Refresh()
    win:Show()
    return true
end

function G.IsShown() return win ~= nil and win:IsShown() end

-- Beim Einloggen mit einem Hexenmeister zeigen, solange nicht abgehakt
function G.OnLogin()
    local db = ns.mod.db
    if not db or db.hideGuide then return end
    if ns.PlayerClass() ~= "WARLOCK" then return end
    C_Timer.After(3, function()
        if not Peon.InCombat() then ns.mod:Call("Fenster", G.Show) end
    end)
end
