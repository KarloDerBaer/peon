-- Peon_Panel - Panel.lua
-- Modul, Einstellungen und Verwaltung der Starter (Peon.GetLaunchers). Konzept: Peon_Panel_Konzept.md
--   entries[Starter] = { bar = true, box = true, side = Bereich auf der Leiste, row = Zeile auf der Leiste (ab 0.3.0),
--                        text, show, label = Text, Anzeige und Beschriftung auf der Leiste,
--                        boxText, boxShow, boxLabel = dasselbe im Panel (ab 0.3.0, getrennt einstellbar) }
--   barOrder, boxOrder = Reihenfolge je Anzeige, auch fuer gerade nicht geladene Module
--   known[Starter]     = schon einmal gesehen. Nur beim ersten Mal wird der Minimap-Button ausgeblendet.

local ADDON_NAME, ns = ...
local L = ns.L

if not Peon or (Peon.API or 0) < 15 then
    if Peon and Peon.Print then Peon.Print("Peon_Panel: " .. L.MSG_OLD_PEON) end
    return
end

local VIS = { always = true, hover = true, combat = true, fold = true }   -- fold: aufklappbar (ab 0.3.0)
ns.TEXT_NONE = "none"
ns.SIDES = { "left", "center", "right" }
ns.SHOWS = { "both", "icon", "text" }
ns.ROWS = { 1, 2 }
ns.BOX_LAYOUTS = { "below", "right" }

-- Felder eines Eintrags je Anzeige
local FIELD = {
    bar = { text = "text", show = "show", label = "label" },
    box = { text = "boxText", show = "boxShow", label = "boxLabel" },
}
local function Field(sk, name) return FIELD[sk == "box" and "box" or "bar"][name] end

-- Bereich auf der Leiste, solange nichts gewaehlt wurde
local DEFAULT_SIDE = { bags = "right", peon = "right" }

-- Erster Start (ab 0.4.0): Eintraege nach der Einstellung von KarloDerBaer.
-- Gilt nur fuer Starter, die noch nie gesehen wurden. Unbekannte Starter wie bisher.
local DEFAULT_ENTRIES = {
    peon       = { bar = true,  box = false, side = "left",  text = "none" },
    fishing    = { bar = true,  box = false, side = "left",  text = "mode", label = false },
    feedback   = { bar = true,  box = false, text = "count", show = "icon", label = false },
    broker     = { bar = true,  box = false, text = "age" },
    zone       = { bar = true,  box = false, text = "both" },
    coords     = { bar = true,  box = false, text = "xy", show = "text" },
    friends    = { bar = true,  box = false, side = "right", text = "online", label = false },
    guild      = { bar = true,  box = false, side = "right", text = "online", label = false },
    durability = { bar = true,  box = false, text = "low", label = false },
    bags       = { bar = true,  box = false, text = "free", label = false },
    ledger     = { bar = true,  box = false, side = "right", text = "goldMe", label = false },
    xpRate     = { bar = false, box = true,  text = "rate", boxShow = "text", boxLabel = true },
    xp         = { bar = false, box = true,  side = "center", text = "full", boxShow = "text" },
    xpEta      = { bar = false, box = true,  text = "eta", boxShow = "text" },
    clock      = { bar = false, box = false, text = "local" },
    resets     = { bar = false, box = false, text = "daily" },
    perf       = { bar = false, box = false, text = "both" },
    playtime   = { bar = false, box = false, text = "session" },
    volume     = { bar = false, box = false, text = "pct" },
    rep        = { bar = false, box = false, text = "standing" },
}

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "panel",
    title    = "Panel",
    db       = "PeonPanelDB",
    defaults = {
        barShow   = true,         -- immer oben in der Mitte
        barWidth  = 65,           -- Prozent der Bildschirmbreite
        barSize   = 18,
        barBg     = true,
        barLabels = true,         -- Modulname vor dem Text
        barVis    = "always",
        barRows   = 1,            -- zwei Zeilen moeglich (ab 0.3.0)
        fontSize  = 11,
        -- Standard ab 0.4.0 nach der Einstellung von KarloDerBaer
        bgColor   = { 0.10, 0.10, 0.01, 0.85 },
        lineColor = { 0.45, 0.40, 0.27, 0.9 },
        style     = "plain",
        fontFace  = "default",
        fontStyle = "shadow",
        labelColor = { 0.91, 0.79, 0.373, 1 },
        valueColor = { 1, 1, 1, 1 },
        barHeight = 26,
        barGap    = 18,
        barSeps   = false,        -- feine Trennstriche
        iconBorder = false,
        highlight = "soft",
        xpLog     = {},           -- InfoXP.lua
        session   = {},           -- InfoSystem.lua
        boxShow   = true,
        boxCols   = 1,            -- 0 = moeglichst quadratisch
        boxSize   = 18,
        boxBg     = true,
        boxVis    = "fold",
        boxLabels = true,         -- Beschriftung vor dem Text im Panel (ab 0.3.0)
        boxLayout = "below",      -- Text unter dem Symbol oder rechts daneben (ab 0.3.0)
        boxFoldDir = "down",      -- Richtung beim Aufklappen (ab 0.3.0)
        boxLocked = false,
        boxPos    = {},           -- x, y der linken oberen Ecke in UIParent-Einheiten, leer = oben links
        entries   = {},
        barOrder  = { "peon", "feedback", "broker", "fishing", "xpRate", "xpEta", "zone", "coords", "xp", "resets",
                      "friends", "guild", "durability", "bags", "ledger", "clock", "perf", "playtime", "volume", "rep" },
        boxOrder  = { "broker", "feedback", "ledger", "peon", "bags", "fishing", "xpRate", "xp", "xpEta", "clock",
                      "zone", "coords", "resets", "durability", "perf", "playtime", "volume", "friends", "guild", "rep" },
        known     = {},
        hintShown = false,
    },
    ranges = {
        barWidth = { 30, 100, 1 }, barSize = { 14, 40, 1 }, fontSize = { 8, 16, 1 },
        barHeight = { 18, 48, 1 }, barGap = { 4, 30, 1 },
        boxCols = { 0, 8, 1 }, boxSize = { 16, 48, 1 }, barRows = { 1, 2, 1 },
    },
    choices = { barVis = VIS, boxVis = VIS, boxLayout = { below = true, right = true },
        boxFoldDir = { down = true, up = true, right = true, left = true },
        style = { tooltipDark = true, tooltip = true, metal = true, dialog = true, wood = true, plain = true },
        fontFace = { default = true, friz = true, arial = true, morpheus = true, skurri = true },
        fontStyle = { none = true, shadow = true, outline = true },
        highlight = { soft = true, glow = true, none = true } },
    keepOnReset = { boxPos = true, entries = true, barOrder = true, boxOrder = true, known = true, hintShown = true,
                    xpLog = true, session = true },
    -- bis 0.1.0: Leiste an 8 Stellen. Ab 0.2.0 nur noch oben.
    migrate = function(_, acc)
        if acc.barPos == nil then return end
        if acc.barPos == "none" then acc.barShow = false end
        if acc.barSize == 22 then acc.barSize = nil end   -- alter Standard
        acc.barPos, acc.barX, acc.barY = nil, nil, nil
    end,
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
        if l and e and e[surfaceKey] and l:IsAvailable() then list[#list + 1] = l end
    end
    return list
end

-- Ein Starter erscheint: beim ersten Mal auf Leiste und Panel, Minimap-Button aus
function ns.AddStarter(l)
    local db = mod.db
    ns.starters[l.key] = l
    if not db.known[l.key] then
        db.known[l.key] = true
        -- Allgemeine Eintraege nur, wenn sie als Standard vorgesehen sind, der Rest zum Anhaken
        local def = ns.InfoDef and ns.InfoDef[l.key]
        db.entries[l.key] = db.entries[l.key] or (DEFAULT_ENTRIES[l.key] and Peon.CopyTable(DEFAULT_ENTRIES[l.key]))
            or { bar = not def or def.bar == true, box = not def, text = l.defaultText or ns.TEXT_NONE }
        if l:IsMinimapShown() then
            Peon.SetPanelHid(l.key, true)
            l:SetMinimapShown(false)
        end
    elseif not db.entries[l.key] then
        db.entries[l.key] = { bar = false, box = false, text = l.defaultText or ns.TEXT_NONE }
    end
    -- bis 0.2.0 galten Text und Anzeige fuer beide: das Panel startet mit den Werten der Leiste
    local e = db.entries[l.key]
    if e.boxText == nil then e.boxText = e.text end
    if e.boxShow == nil then e.boxShow = e.show end
    EnsureInOrder(db.barOrder, l.key)
    EnsureInOrder(db.boxOrder, l.key)
    if ns.ApplyAll then ns.ApplyAll() end
end

local function Changed()
    mod:Fire("CHANGED", "entries")
end

-- Gewaehlter Text auf einer Anzeige (sk = "bar" oder "box", Standard Leiste)
function ns.TextOf(key, sk)
    local e = ns.Entry(key)
    if not e then return nil end
    local v = e[Field(sk, "text")]
    if v == nil then v = e.text end
    return v
end

function ns.SetText(l, textKey, sk)
    local e = ns.Entry(l.key)
    if not e or ns.TextOf(l.key, sk) == textKey then return end
    e[Field(sk, "text")] = textKey
    Changed()
end

function ns.SideOf(key)
    local e = ns.Entry(key)
    local def = ns.InfoDef and ns.InfoDef[key]
    return e and e.side or def and def.side or DEFAULT_SIDE[key] or "left"
end

function ns.SetSide(l, side)
    local e = ns.Entry(l.key)
    if not e or ns.SideOf(l.key) == side then return end
    e.side = side
    Changed()
end

-- Zeile auf der Leiste (ab 0.3.0). Mit nur einer Zeile immer 1.
function ns.RowOf(key)
    if (mod.db.barRows or 1) < 2 then return 1 end
    local e = ns.Entry(key)
    return e and e.row == 2 and 2 or 1
end

function ns.SetRow(l, row)
    local e = ns.Entry(l.key)
    if not e or ns.RowOf(l.key) == row then return end
    e.row = row
    Changed()
end

function ns.ShowOf(key, sk)
    local e = ns.Entry(key)
    return e and e[Field(sk, "show")] or "both"
end

function ns.SetShow(l, show, sk)
    local e = ns.Entry(l.key)
    if not e or ns.ShowOf(l.key, sk) == show then return end
    e[Field(sk, "show")] = show
    Changed()
end

-- Beschriftung vor dem Text, je Eintrag und Anzeige (ab 0.3.0). Ohne eigene Wahl: an, ausser bei noLabel.
function ns.LabelOf(key, sk)
    local e = ns.Entry(key)
    local v = e and e[Field(sk, "label")]
    if v ~= nil then return v end
    local def = ns.InfoDef and ns.InfoDef[key]
    return not (def and def.noLabel)
end

function ns.SetLabel(l, on, sk)
    local e = ns.Entry(l.key)
    if not e or ns.LabelOf(l.key, sk) == on then return end
    e[Field(sk, "label")] = on and true or false
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
function ns.TextLabel(l, sk)
    local v = ns.TextOf(l.key, sk)
    for _, t in ipairs(l.texts) do
        if t.key == v then return t.label end
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
    -- Die Breite der Leiste haengt von der Bildschirmbreite ab
    mod:RegisterEvent("UI_SCALE_CHANGED", function() ns.ApplyAll() end)
    mod:RegisterEvent("DISPLAY_SIZE_CHANGED", function() ns.ApplyAll() end)
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
    ns.InitInfos()
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
    ns.StartInfoTicker()
end)

mod:On("CHANGED", function() ns.ApplyAll() end)
mod:On("RESET", function() ns.ApplyAll() end)
mod:On("COMBAT_START", function() ns.ApplyVisibility() end)
mod:On("COMBAT_END", function() ns.ApplyVisibility() end)

if Peon.SetFeedbackAreas then
    Peon.SetFeedbackAreas(ADDON_NAME, { "Leiste", "Panel", "Kontextmenü", "Symbole und Texte", "Optionen" })
end
