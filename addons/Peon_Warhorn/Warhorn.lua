-- Peon_Warhorn - Warhorn.lua
-- Gruppen, Dungeons und Raids. Ab 0.1.0 nur der Pruefaufbau fuer die Gruppensuche (Probe.lua).
-- Einstellungen in PeonWarhornDB.

local ADDON_NAME, ns = ...
local L = ns.L

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "warhorn",           -- /peon warhorn ...
    title    = "Warhorn",
    db       = "PeonWarhornDB",
    defaults = {
        probe = {},                 -- Ergebnis der letzten Pruefung (/peon warhorn pruefen)
    },
    keepOnReset = { probe = true },
    onSlash  = function(m, cmd)
        if cmd == "pruefen" or cmd == "prüfen" or cmd == "probe" then
            ns.Probe.Start("key")
        else
            m:OpenOptions()
        end
    end,
})
ns.mod = mod

mod:On("INIT", function()
    if ns.CreateOptions then mod:Call("Options", ns.CreateOptions) end
end)
