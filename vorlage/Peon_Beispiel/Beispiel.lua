-- Peon_Beispiel - Beispiel.lua
-- Anmeldung beim Peon-Kern, Einstellungen, Ereignisse.
-- Einstellungen in PeonBeispielDB.
--
-- Neues Modul aus dieser Vorlage:
--   1. Ordner und TOC umbenennen (Peon_<Name>), in der TOC Titel, Notes, Icon, SavedVariables anpassen
--   2. Hier key, title, db anpassen; "Beispiel"/"beispiel" ueberall ersetzen
--   3. tests/test_<name>.lua aus vorlage/test_beispiel.lua anlegen
--   4. Neuer Addon-Ordner: WoW komplett neu starten (kein /reload)

local ADDON_NAME, ns = ...
local L = ns.L

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "beispiel",          -- /peon beispiel ...
    title    = "Beispiel",
    db       = "PeonBeispielDB",
    defaults = {
        enabled = true,
        size    = 16,
        mode    = "a",
    },
    ranges   = { size = { 8, 32, 1 } },        -- min, max, Schrittweite
    choices  = { mode = { a = true, b = true } },
    -- eigene Slash-Befehle (optional): slash = { "/xy" }, onSlash = function(m, cmd, rest) end,
})
ns.mod = mod

-- Einstellungen anwenden (nach Start, Aenderung im Menue und Reset)
local function Apply()
    local db = mod.db
    if not db then return end
    mod:Dbg(("Apply enabled=%s size=%s mode=%s"):format(tostring(db.enabled), tostring(db.size), tostring(db.mode)))
end
ns.Apply = Apply

mod:On("INIT", function()
    -- Optionsseite spaetestens hier anmelden (der Kern haengt Unterseiten bei PLAYER_LOGIN ein)
    if ns.CreateOptions then mod:Call("Options", ns.CreateOptions) end
end)
mod:On("LOGIN", Apply)
mod:On("CHANGED", Apply)
mod:On("RESET", Apply)

-- Beispiel fuer ein WoW-Ereignis (fn bekommt event, ...)
-- mod:RegisterEvent("ZONE_CHANGED_NEW_AREA", function(event) Apply() end)
