-- Peon_Fishing - Fishing.lua
-- Kern des Moduls: Anmeldung beim Peon-Kern, Einstellungen, Hilfsfunktionen, Ereignisse, Slash-Befehle.
-- Einstellungen in PeonFishingDB (accountweit) und PeonFishingCharDB (pro Charakter).

local ADDON_NAME, ns = ...
local L = ns.L

ns.defaults = {
    debug        = false,
    fishingSetID = -1,          -- -1 = kein Angel-Set gewaehlt
    returnSetName = "Standard", -- in dieses Set wird beim Betreten gespeichert
    showMinimap  = true,
    minimapAngle = 200,
    clickMode    = "off",       -- "off" | "double" (Doppel-Rechtsklick wirft im Angelmodus aus)
    clickButton  = "RightButton",
    dbVersion    = 3,
    soundEnabled = true,        -- Ton-Mix, solange die Angel draussen ist
    soundMusic   = 0,           -- Prozent
    soundAmbience = 10,
    soundSFX     = 100,
    soundQuiet   = true,        -- Dialog, Haustiere, Emotes, Fehlersprache aus
    soundBackground = true,     -- Ton auch im Hintergrund
    soundDelay   = 5,           -- Sekunden bis zur Rueckkehr nach dem Einholen
    soundParticles = false,     -- ganzer Angelmodus: Partikeldichte hoch
    soundChannels = false,      -- ganzer Angelmodus: mehr Tonkanaele
    lure         = "none",      -- "auto" | "none" | itemID
    recastOnLost = true,        -- Schwimmer nicht erkannt: Angel-Taste wirft neu aus
    interactRange = 60,         -- Reichweite der Zielerkennung im Angelmodus (Meter, experimentell)
    bobberMarker = "icon",      -- "off" | "icon" | "text": Anzeige ueber dem erkannten Schwimmer
    lostSound    = "raid",      -- "off" oder Schluessel aus ns.LOST_SOUNDS
    combatWeaponTry = true,     -- bei Kampfbeginn automatisch Waffen anlegen versuchen
    afterCombat  = "stay",      -- "stay" | "ask" | "leave"
    showCatchList = true,       -- Fangliste im Angelmodus
    -- Zustand (ueberlebt /reload)
    mode         = "normal",    -- "normal" | "fishing"
    pending      = "",          -- "" | "enter" | "leave" (nach dem Kampf ausfuehren)
    returnSetID  = -1,
}

-- Charakterbezogene Werte liegen in PeonFishingCharDB (SavedVariablesPerCharacter), alles andere
-- (Optionen, Fangdatenbank) accountweit in PeonFishingDB. mod.db ist eine Sicht auf beides.
local CHAR_KEYS = { fishingSetID = true, returnSetID = true, mode = true, pending = true, snapshot = true }
ns.CHAR_KEYS = CHAR_KEYS

local mod -- unten angelegt; der Slash-Handler braucht ihn

local function OnSlash(m, cmd, rest)
    local db = m.db
    if cmd == "debug" then
        m:ToggleDebug()
    elseif cmd == "toggle" or cmd == "an" or cmd == "aus" or cmd == "on" or cmd == "off" then
        if (cmd == "an" or cmd == "on") and ns.IsFishing() then return end
        if (cmd == "aus" or cmd == "off") and not ns.IsFishing() then return end
        ns.Toggle()
    elseif cmd == "set" then
        ns.ChooseFishingSet(rest)
    elseif cmd == "kampf" or cmd == "combat" then
        local modes = { fragen = "ask", ask = "ask", verlassen = "leave", leave = "leave", bleiben = "stay", stay = "stay" }
        local mo = modes[(rest or ""):lower()]
        if mo then db.afterCombat = mo end
        ns.Print(L.MSG_AFTER_COMBAT:format(L["AFTER_" .. db.afterCombat]))
    elseif cmd == "waffenversuch" or cmd == "weapontry" then
        db.combatWeaponTry = not db.combatWeaponTry
        ns.Print(db.combatWeaponTry and L.MSG_WEAPON_TRY_ON or L.MSG_WEAPON_TRY_OFF)
    elseif cmd == "koeder" or cmd == "köder" or cmd == "lure" then
        ns.PrintLures()
    elseif cmd == "fische" or cmd == "fish" or cmd == "fang" then
        if ns.ToggleOverview then ns.ToggleOverview() end
    elseif cmd == "saveset" then
        ns.SaveFishingSet()
    elseif cmd == "klick" or cmd == "click" then
        local modes = { doppel = "double", double = "double", an = "double", on = "double", aus = "off", off = "off" }
        local mo = modes[(rest or ""):lower()]
        if mo then db.clickMode = mo end
        ns.Print(L.MSG_CLICK_MODE:format(L["CLICK_" .. db.clickMode]))
        ns.FireModeChanged()
    elseif cmd == "" or cmd == "optionen" or cmd == "options" then
        if ns.OpenOptions then ns.OpenOptions() end
    elseif cmd == "button" or cmd == "minimap" then
        db.showMinimap = not db.showMinimap
        if ns.UpdateButton then ns.UpdateButton() end
    elseif cmd == "statistik" or cmd == "stats" then
        ns.Print(L.MSG_BOBBER_STATS:format(db.bobberCasts or 0, db.bobberMisses or 0))
        db.bobberCasts, db.bobberMisses = 0, 0
    elseif cmd == "status" then
        ns.PrintStatus()
    else
        for _, line in ipairs(L.HELP) do ns.Print(line) end
    end
end

mod = Peon:NewModule(ADDON_NAME, {
    key      = "fishing",
    title    = "Fishing",
    db       = "PeonFishingDB",
    charDB   = "PeonFishingCharDB",
    charKeys = CHAR_KEYS,
    defaults = ns.defaults,
    choices  = {
        mode         = { normal = true, fishing = true },
        pending      = { [""] = true, enter = true, leave = true },
        clickMode    = { off = true, double = true },
        bobberMarker = { off = true, icon = true, text = true },
        afterCombat  = { stay = true, ask = true, leave = true },
    },
    -- Regler: min, max, Schrittweite (Werte ausserhalb werden beim Laden geklemmt)
    ranges   = {
        interactRange = { 10, 100, 5 },
        soundMusic    = { 0, 100, 5 },
        soundAmbience = { 0, 100, 5 },
        soundSFX      = { 0, 100, 5 },
        soundDelay    = { 0, 15, 1 },
    },
    -- Knopf "Standardwerte": nur Optionen zuruecksetzen, Zustand und gewaehlte Sets/Koeder bleiben
    keepOnReset = {
        fishingSetID = true, returnSetName = true, returnSetID = true, minimapAngle = true,
        clickButton = true, dbVersion = true, lure = true, mode = true, pending = true,
    },
    validate = {
        -- Koeder: Text ("auto"/"none") oder Gegenstands-ID (der reine Typvergleich wuerde eine ID verwerfen)
        lure = function(v) return v == "auto" or v == "none" or type(v) == "number" end,
    },
    -- Reste aelterer Versionen (Einzelklick-Test, alter Button, Diagnose, Migrationsmerker) entfernen
    migrate  = function(m, acc, char)
        acc.doubleClick, acc.reelOnRelease, acc.bobberIcon, acc.showButton = nil, nil, nil, nil
        acc.buttonPos, acc.diag = nil, nil
        char.migrated = nil
    end,
    slash    = { "/fp" },
    ownDebug = true,
    onSlash  = OnSlash,
    maxLog   = 2000,
})
ns.mod = mod
ns.version = mod.version

---------------------------------------------------------------------------
-- Hilfsfunktionen (Kurzformen fuer die uebrigen Dateien)
---------------------------------------------------------------------------
function ns.Print(msg) mod:Print(msg) end
function ns.Error(msg) mod:Error(msg) end
function ns.ReportError(where, err) mod:ReportError(where, err) end
function ns.Dbg(msg) mod:Dbg(msg) end
function ns.ToggleDebug() mod:ToggleDebug() end
ns.IsSecret = Peon.IsSecret
ns.S = Peon.S
ns.InCombat = Peon.InCombat

function ns.GetDB()
    return mod.db
end

-- Werte nach dem Laden pruefen (ungueltige Auswahl -> Standard erledigt schon der Kern ueber choices)
mod:On("INIT", function()
    if type(mod.acc.catches) ~= "table" then mod.acc.catches = {} end
end)

-- Andere Dateien melden sich hier an, um Zustandswechsel mitzubekommen
ns.onModeChanged = {}
function ns.FireModeChanged()
    local db = mod.db
    for _, fn in ipairs(ns.onModeChanged) do
        local ok, err = pcall(fn, db.mode)
        if not ok then ns.ReportError("ModeChanged", err) end
    end
end

-- Aenderungen im Optionsmenue (Kern-Bausteine) und "Standardwerte": Schalter, Tasten,
-- Waffen-Button, Minimap-Button usw. aktualisieren
mod:On("CHANGED", function() ns.FireModeChanged() end)
mod:On("RESET", function() ns.FireModeChanged() end)

function ns.IsFishing()
    return mod.db ~= nil and mod.db.mode == "fishing"
end

---------------------------------------------------------------------------
-- Ereignisse (Listen, ausgeloest ueber den Peon-Kern)
---------------------------------------------------------------------------
ns.onLogin = {}
ns.onCombatEnd = {}

local function RunList(list, where)
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn)
        if not ok then ns.ReportError(where, err) end
    end
end
mod:On("LOGIN", function() RunList(ns.onLogin, "Login") end)
mod:On("COMBAT_END", function() RunList(ns.onCombatEnd, "CombatEnd") end)

---------------------------------------------------------------------------
-- Tastenbelegung (Bindings.xml)
---------------------------------------------------------------------------
function PeonFishing_Toggle()
    if ns.Toggle then ns.Toggle() end
end


-- Bereiche für Rückmeldungen in Peon_Feedback (Kern ab API 9; mit älterem Kern wird nichts gemeldet)
if Peon.SetFeedbackAreas then Peon.SetFeedbackAreas(ADDON_NAME, { "Ausrüstung", "Steuerung", "Köder", "Schwimmer-Erkennung", "Kampf", "Ton", "Fänge", "Minimap-Button", "Optionen" }) end
