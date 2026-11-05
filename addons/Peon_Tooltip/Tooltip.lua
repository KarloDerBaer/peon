-- Peon_Tooltip - Tooltip.lua
-- Anmeldung beim Peon-Kern, Einstellungen, Verankerung am Mauszeiger, Ausblenden, Slash-Befehle.
-- Einstellungen in PeonTooltipDB.

local ADDON_NAME, ns = ...
local L = ns.L
local PL = Peon.L

ns.ICON_POSITIONS = Peon.POSITIONS

-- Neue Standardwerte (ab 0.7.3) einmalig uebernehmen: nur wer noch die alten Standardwerte hat,
-- bekommt die neuen. Selbst gewaehlte Werte bleiben.
function ns.MigrateDefaults(acc)
    if acc.defaultsVer then return end
    acc.defaultsVer = 1
    if acc.offsetX == 20 and acc.offsetY == 20 then
        acc.offsetX, acc.offsetY = 40, 40
    end
    if acc.fadeCustom == false and acc.fadeTime == 2 then
        acc.fadeCustom, acc.fadeTime = true, 0
    end
end

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "tooltip",
    title    = "Tooltip",
    db       = "PeonTooltipDB",
    defaults = {
        corner      = "BOTTOMRIGHT",
        defaultsVer = 1,         -- neue Standardwerte uebernommen (ns.MigrateDefaults)
        offsetX     = 40,
        offsetY     = 40,
        edgeFlip    = true,
        scale       = 100,       -- Prozent
        bgAlpha     = 100,       -- Prozent
        borderMode  = "reaction",
        playerInfo  = true,
        fadeCustom  = true,
        fadeTime    = 0,         -- Zehntelsekunden, 0 = sofort
        combatMode  = "normal",
        combatAlpha = 40,        -- Prozent
        combatShift = true,
        pvpIcon     = "TOPRIGHT",
        questIcon   = "TOPLEFT",
        iconSize    = 20,
        -- Gegenstands-Tooltip (Items.lua, ab 0.6.0)
        itemParts   = true,      -- Teile ordnen/ausblenden
        itemBorder  = "default", -- Rahmenfarbe: default (Blizzard) / quality (Qualitaet)
        itemOrder   = {},        -- Reihenfolge der Teile ("b:head", "a:Peon_Broker", "s:line:1" ...)
        itemHidden  = {},        -- [Teil] = true: ausgeblendet
        itemKnown   = {},        -- ["a:<Addon>"] = { title, seen, seq }: Addons, die schon geschrieben haben
        itemSepId   = 0,         -- laufende Nummer fuer Trennlinien/Leerraum
        itemWrap    = true,      -- ab 0.7.1: lange Zeilen umbrechen
        itemMaxWidth = 450,      -- ab 0.7.1: maximale Breite des Textes (Tooltip-Punkte)
    },
    migrate  = function(_, acc) ns.MigrateDefaults(acc) end,
    keepOnReset = { itemKnown = true, itemSepId = true },
    -- min, max, Schrittweite
    ranges = {
        offsetX     = { -200, 200, 1 },
        offsetY     = { -200, 200, 1 },
        scale       = { 50, 200, 5 },
        bgAlpha     = { 0, 100, 5 },
        fadeTime    = { 0, 20, 1 },
        combatAlpha = { 10, 100, 5 },
        iconSize    = { 12, 40, 2 },
        itemMaxWidth = { 250, 800, 10 },
    },
    choices = {
        corner     = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true },
        borderMode = { none = true, reaction = true, class = true },
        combatMode = { normal = true, fade = true, hide = true },
        itemBorder = { default = true, quality = true },
        pvpIcon    = Peon.POSITION_SET,
        questIcon  = Peon.POSITION_SET,
    },
    slash    = { "/ttp" },
    ownDebug = true,    -- /ttp debug untersucht die Einheit unter der Maus; Log ueber /peon debug tooltip
    onSlash  = function(m, cmd)
        if cmd == "reset" then
            m:ResetDefaults()
            m:Print(PL.MSG_RESET)
        elseif cmd == "debug" then
            if ns.Debug then ns.Debug() end
        elseif cmd == "teile" or cmd == "parts" then
            if ns.ItemPartsDebug then ns.ItemPartsDebug() end
        elseif cmd == "log" then
            m:ToggleDebug()
        elseif cmd == "help" or cmd == "hilfe" or cmd == "?" then
            m:Print(L.MSG_HELP)
        else
            m:OpenOptions()
        end
    end,
})
ns.mod = mod

-- Kurzformen fuer Style.lua, Units.lua, Icons.lua und Debug.lua
ns.IsSecret = Peon.IsSecret
function ns.GetDB() return mod.db end
function ns.Print(msg) mod:Print(msg) end
function ns.ReportError(where, err) mod:ReportError(where, err) end

ns.settingsVersion = 0
ns.inCombat = false

-- Upvalues fuer den OnUpdate-Pfad
local GetCursorPosition, GetTime, UnitExists = GetCursorPosition, GetTime, UnitExists
local UIParent = UIParent

---------------------------------------------------------------------------
-- Einstellungen geaendert
---------------------------------------------------------------------------
function ns.OnSettingChanged()
    ns.settingsVersion = ns.settingsVersion + 1
    if GameTooltip:IsShown() then
        if ns.ApplyStyle then ns.ApplyStyle(GameTooltip) end
        if ns.SafeUpdateIcons then ns.SafeUpdateIcons(GameTooltip) end
    end
end
mod:On("CHANGED", ns.OnSettingChanged)
mod:On("RESET", ns.OnSettingChanged)

---------------------------------------------------------------------------
-- Verankerung am Mauszeiger
---------------------------------------------------------------------------
local CORNERS = {
    BOTTOMRIGHT = {  1, -1 },
    BOTTOMLEFT  = { -1, -1 },
    TOPRIGHT    = {  1,  1 },
    TOPLEFT     = { -1,  1 },
}

-- Pro Tooltip: Besitzer, Positions-Cache und Ausblend-Zustand
local state = {}
-- Besitzer beim letzten Default-Anker (fuer "im Kampf ausblenden")
ns.defaultOwner = {}

local function PositionAtCursor(tooltip, st)
    local db = mod.db
    local scale = tooltip:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    local w, h = tooltip:GetWidth(), tooltip:GetHeight()

    -- nichts neu berechnen, wenn sich nichts geaendert hat
    if cx == st.cx and cy == st.cy and w == st.w and h == st.h and st.ver == ns.settingsVersion then
        return
    end
    st.cx, st.cy, st.w, st.h, st.ver = cx, cy, w, h, ns.settingsVersion

    local c = CORNERS[db.corner] or CORNERS.BOTTOMRIGHT
    local dx, dy = c[1], c[2]
    local ox, oy = db.offsetX, db.offsetY

    if db.edgeFlip then
        local uiScale = UIParent:GetEffectiveScale() / scale
        local sw, sh = UIParent:GetWidth() * uiScale, UIParent:GetHeight() * uiScale
        if dx == 1 and cx + ox + w > sw then dx = -1
        elseif dx == -1 and cx - ox - w < 0 then dx = 1 end
        if dy == -1 and cy - oy - h < 0 then dy = 1
        elseif dy == 1 and cy + oy + h > sh then dy = -1 end
    end

    local point = (dy == -1 and "TOP" or "BOTTOM") .. (dx == 1 and "LEFT" or "RIGHT")
    tooltip:ClearAllPoints()
    tooltip:SetPoint(point, UIParent, "BOTTOMLEFT", cx + dx * ox, cy + dy * oy)
end

-- Eigenes Ausblenden fuer Einheiten und Objekte in der Welt (Besitzer = UIParent)
local function HandleFade(tooltip, st)
    local db = mod.db
    if st.owner ~= UIParent then return end
    if UnitExists("mouseover") then
        st.sawUnit = true
        if st.fadeStart then
            st.fadeStart = nil
            if ns.ResetAlpha then ns.ResetAlpha(tooltip) end
        end
        return
    end
    -- Maus noch auf dem Objekt, anderer Tooltip oder Funktion aus: Blizzard ausblenden lassen
    if not (st.sawUnit or st.objectLeft) or not db.fadeCustom then return end

    local duration = db.fadeTime / 10
    if duration <= 0 then
        tooltip:Hide()
        return
    end
    local now = GetTime()
    if not st.fadeStart then st.fadeStart = now end
    local p = (now - st.fadeStart) / duration
    if p >= 1 then
        tooltip:Hide()
    elseif ns.SetTooltipAlpha then
        ns.SetTooltipAlpha(tooltip, ns.GetBaseAlpha() * (1 - p))
    end
end

local function OnTooltipUpdate(tooltip)
    local st = state[tooltip]
    if not st or not st.owner or not mod.db then return end
    -- Hat inzwischen jemand anderes den Tooltip neu verankert? Dann loslassen.
    if tooltip:GetOwner() ~= st.owner
        or (tooltip.GetAnchorType and tooltip:GetAnchorType() ~= "ANCHOR_NONE") then
        st.owner = nil
        return
    end
    PositionAtCursor(tooltip, st)
    HandleFade(tooltip, st)
end

local function OnTooltipHide(tooltip)
    local st = state[tooltip]
    if st then
        st.owner, st.fadeStart, st.sawUnit, st.objectLeft = nil, nil, false, false
    end
end

local function OnSetDefaultAnchor(tooltip, parent)
    if not mod.db or not tooltip then return end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end
    parent = parent or UIParent

    tooltip:SetOwner(parent, "ANCHOR_NONE")

    local st = state[tooltip]
    if not st then
        st = {}
        state[tooltip] = st
        tooltip:HookScript("OnUpdate", OnTooltipUpdate)
        tooltip:HookScript("OnHide", OnTooltipHide)
    end
    -- neuer Inhalt waehrend des eigenen Ausblendens: wieder voll sichtbar
    if st.fadeStart and ns.ResetAlpha then ns.ResetAlpha(tooltip) end
    st.owner, st.ver, st.fadeStart, st.sawUnit, st.objectLeft = parent, nil, nil, false, false
    ns.defaultOwner[tooltip] = parent

    PositionAtCursor(tooltip, st)
end

function ns.IsDefaultAnchored(tooltip)
    local owner = ns.defaultOwner[tooltip]
    return owner ~= nil and tooltip:GetOwner() == owner
end

if type(GameTooltip_SetDefaultAnchor) == "function" then
    hooksecurefunc("GameTooltip_SetDefaultAnchor", OnSetDefaultAnchor)
else
    mod:Print(L.MSG_NO_ANCHOR)
end

-- Maus hat ein Objekt in der Welt verlassen: Blizzards SetWorldCursor ruft dann FadeOut auf (nur
-- mitgelesen). Ausgeblendet wird im naechsten OnUpdate ueber HandleFade, wie bei Einheiten.
if type(GameTooltip.FadeOut) == "function" then
    hooksecurefunc(GameTooltip, "FadeOut", function(tooltip)
        local st = state[tooltip]
        if st and st.owner then st.objectLeft = true end
    end)
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
mod:On("INIT", function()
    if ns.CreateOptions then mod:Call("Options", ns.CreateOptions) end
end)

mod:On("LOGIN", function()
    ns.inCombat = UnitAffectingCombat("player") and true or false
end)

local function CombatChanged(inCombat)
    ns.inCombat = inCombat
    if ns.OnCombatChanged then ns.OnCombatChanged() end
end
mod:On("COMBAT_START", function() CombatChanged(true) end)
mod:On("COMBAT_END", function() CombatChanged(false) end)

-- Bereiche für Rückmeldungen in Peon_Feedback (Kern ab API 9; mit älterem Kern wird nichts gemeldet)
if Peon.SetFeedbackAreas then Peon.SetFeedbackAreas(ADDON_NAME, { "Position", "Aussehen", "Spielerinfos", "Kampfmodus", "Symbole", "Gegenstands-Tooltip", "Rahmenfarbe", "Optionen" }) end
