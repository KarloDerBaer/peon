-- Peon_ClassBuddy - ClassBuddy.lua
-- Klassenbuddy: kleine Helfer je Klasse (Konzept docs/konzepte/classbuddy/Peon_ClassBuddy_Konzept.md).
-- Ab 0.1.0 nur der Pruefbefehl fuer Seelensplitter (Probe.lua). Die Combo-Punkte ziehen spaeter von Peon_ComboPoints um.
-- Einstellungen in PeonClassBuddyDB.

local ADDON_NAME, ns = ...
local L = ns.L

local function Help(m)
    for _, line in ipairs(L.HELP) do m:Print(line) end
end

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "classbuddy",        -- /peon classbuddy ...
    title    = L.TITLE,
    db       = "PeonClassBuddyDB",
    defaults = {
        probe = {},                 -- Ergebnisse der Pruefung (Probe.lua)
        hideGuide = false,          -- Fenster fuer Hexenmeister nicht mehr zeigen (Guide.lua)
    },
    keepOnReset = { probe = true, hideGuide = true },
    onSlash  = function(m, cmd, rest)
        if cmd == "pruefen" or cmd == "prüfen" or cmd == "check" or cmd == "probe" then
            ns.Probe.Slash((rest or ""):lower())
        else
            Help(m)
        end
    end,
})
ns.mod = mod

-- Klasse des Charakters als englischer Schluessel (ROGUE, WARLOCK, ...)
function ns.PlayerClass()
    local _, class = UnitClass("player")
    if Peon.IsSecret(class) then return nil end
    return class
end

mod:On("LOGIN", function()
    if ns.Probe then ns.Probe.OnLogin() end
    if ns.Guide then ns.Guide.OnLogin() end
end)

-- Bereiche fuer Rueckmeldungen in Peon_Feedback
if Peon.SetFeedbackAreas then Peon.SetFeedbackAreas(ADDON_NAME, { "Prüfung", "Seelensplitter", "Allgemein" }) end
