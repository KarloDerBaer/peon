-- Peon_Panel - Panel.lua
-- Modul, Einstellungen und Verwaltung der Starter (Peon.GetLaunchers). Konzept: Peon_Panel_Konzept.md
--   entries[Starter] = { bar = true, box = true, text = "free" oder "none" }
--   barOrder, boxOrder = Reihenfolge je Anzeige, auch fuer gerade nicht geladene Module
--   known[Starter]     = schon einmal gesehen. Nur beim ersten Mal wird der Minimap-Button ausgeblendet.

local ADDON_NAME, ns = ...
local L = ns.L

if not Peon or (Peon.API or 0) < 14 then
    if Peon and Peon.Print then Peon.Print("Peon_Panel: " .. L.MSG_OLD_PEON) end
    return
end

local VIS = { always = true, hover = true, combat = true }
ns.TEXT_NONE = "none"

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "panel",
    title    = "Panel",
    db       = "PeonPanelDB",
    defaults = {
        barPos    = "TOP",        -- 8 Stellen, "none" = aus
        barX      = 0,
        barY      = 0,
        barSize   = 22,
        barBg     = true,
        barVis    = "always",
        boxShow   = false,
        boxCols   = 0,            -- 0 = moeglichst quadratisch
        boxSize   = 28,
        boxBg     = true,
        boxVis    = "always",
        boxLocked = false,
        boxPos    = {},           -- x, y der linken oberen Ecke in UIParent-Einheiten
        entries   = {},
        barOrder  = {},
        boxOrder  = {},
        known     = {},
        hintShown = false,
    },
    ranges = {
        barX = { 0, 800, 1 }, barY = { 0, 800, 1 }, barSize = { 14, 40, 1 },
        boxCols = { 0, 8, 1 }, boxSize = { 16, 48, 1 },
    },
    choices = { barPos = Peon.POSITION_SET, barVis = VIS, boxVis = VIS },
    keepOnReset = { boxPos = true, entries = true, barOrder = true, boxOrder = true, known = true, hintShown = true },
})
ns.mod = mod

ns.starters = {}   -- [Schluessel] = Starter

---------------------------------------------------------------------------
-- Reihenfolge
---------------------------------------------------------------------------
local function IndexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
end

local function EnsureInOrder(list, key)
    if not IndexOf(list, key) then list[#list + 1] = key end
end

-- key vor oder hinter target einsortieren. Rueckgabe: ob sich etwas geaendert hat
function ns.MoveEntry(order, key, target, after)
    if key == target then return false end
    local from, to = IndexOf(order, key), IndexOf(order, target)
    if not from or not to then return false end
    table.remove(order, from)
    to = IndexOf(order, target)
    table.insert(order, after and to + 1 or to, key)
    return true
end

function ns.OrderOf(surfaceKey)
    return surfaceKey == "bar" and mod.db.barOrder or mod.db.boxOrder
end

---------------------------------------------------------------------------
-- Eintraege
---------------------------------------------------------------------------
function ns.Entry(key) return mod.db.entries[key] end

-- Starter, die auf dieser Anzeige stehen, in ihrer Reihenfolge
function ns.VisibleStarters(surfaceKey)
    local list = {}
    for _, key in ipairs(ns.OrderOf(surfaceKey)) do
        local l, e = ns.starters[key], ns.Entry(key)
        if l and e and e[surfaceKey] then list[#list + 1] = l end
    end
    return list
end

-- Ein Starter erscheint: beim ersten Mal auf Leiste und Panel, Minimap-Button aus
function ns.AddStarter(l)
    local db = mod.db
    ns.starters[l.key] = l
    if not db.known[l.key] then
        db.known[l.key] = true
        db.entries[l.key] = db.entries[l.key] or { bar = true, box = true, text = l.defaultText or ns.TEXT_NONE }
        if l:IsMinimapShown() then
            Peon.SetPanelHid(l.key, true)
            l:SetMinimapShown(false)
        end
    elseif not db.entries[l.key] then
        db.entries[l.key] = { bar = false, box = false, text = l.defaultText or ns.TEXT_NONE }
    end
    EnsureInOrder(db.barOrder, l.key)
    EnsureInOrder(db.boxOrder, l.key)
    if ns.ApplyAll then ns.ApplyAll() end
end

local function Changed()
    mod:Fire("CHANGED", "entries")
end

function ns.SetText(l, textKey)
    local e = ns.Entry(l.key)
    if not e or e.text == textKey then return end
    e.text = textKey
    Changed()
end

function ns.SetOnSurface(l, surfaceKey, on)
    local e = ns.Entry(l.key)
    if not e then return end
    e[surfaceKey] = on and true or false
    if not on and not e.bar and not e.box and not l:IsMinimapShown() then
        mod:Print(L.MSG_NOWHERE:format(l.title))
    end
    Changed()
end

-- Selbst umgestellt: Der Kern soll diesen Button nicht mehr von sich aus zurueckholen
function ns.SetMinimap(l, on)
    Peon.SetPanelHid(l.key, false)
    l:SetMinimapShown(on)
    Changed()
end

-- Lesbarer Name des gewaehlten Textes
function ns.TextLabel(l)
    local e = ns.Entry(l.key)
    for _, t in ipairs(l.texts) do
        if e and t.key == e.text then return t.label end
    end
    return L.MENU_NO_TEXT
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
StaticPopupDialogs["PEON_PANEL_HINT"] = {
    text = L.HINT_FIRST,
    button1 = rawget(_G, "OKAY") or "OK",
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

mod:On("INIT", function()
    ns.InitDisplay()
    if ns.CreateOptions then mod:Call("Options", ns.CreateOptions) end
    Peon.OnLauncherRefresh(function(l) ns.RefreshStarter(l) end)
    Peon.OnLauncherAdded(function(l) ns.AddStarter(l) end)
    -- Peon selbst ist kein Modul und bekommt seinen Starter von hier
    mod:NewLauncher({
        key = "peon", title = "Peon", icon = "Interface\\Icons\\INV_Pick_02",
        onClick = function() Peon.OpenOptions() end,
        onTooltip = function(_, tooltip) tooltip:AddLine(L.PEON_TIP, 1, 1, 1) end,
        menu = function(m, root) root:CreateButton(L.MENU_PANEL, function() m:OpenOptions() end) end,
        openOptions = function() Peon.OpenOptions() end,
    })
end)

mod:On("LOGIN", function()
    ns.ApplyAll()
    if not mod.db.hintShown then
        mod.db.hintShown = true
        if StaticPopup_Show then StaticPopup_Show("PEON_PANEL_HINT") end
    end
    local timer = rawget(_G, "C_Timer")
    -- einmal je Minute fuer alles, was mit der Zeit altert (zum Beispiel "vor 12 Min.")
    if timer and timer.NewTicker then timer.NewTicker(60, function() mod:Call("Texte", ns.RefreshAll) end) end
end)

mod:On("CHANGED", function() ns.ApplyAll() end)
mod:On("RESET", function() ns.ApplyAll() end)
mod:On("COMBAT_START", function() ns.ApplyVisibility() end)
mod:On("COMBAT_END", function() ns.ApplyVisibility() end)

if Peon.SetFeedbackAreas then
    Peon.SetFeedbackAreas(ADDON_NAME, { "Leiste", "Panel", "Kontextmenü", "Symbole und Texte", "Optionen" })
end
