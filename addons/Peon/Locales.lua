-- Peon - Locales.lua
-- Texte des Kerns. Module legen ihre eigene Tabelle mit Peon.NewLocale() an.

local ADDON_NAME, ns = ...

-- Fehlende Schluessel zeigen den Schluessel selbst an, statt einen Fehler zu werfen
local function NewLocale()
    return setmetatable({}, { __index = function(_, k) return k end })
end

local L = NewLocale()
ns.L = L
ns.NewLocale = NewLocale

-- enUS (Standard)
L.MSG_ERROR          = "Error in %s: %s"
L.MSG_ERROR_SAVED    = "Error in %s (saved, /peon errors shows the text)."   -- API 12
L.MSG_ERRORS_NONE    = "No saved errors."
L.MSG_ERRORS_HEAD    = "Saved errors (newest first, %d in total):"
L.MSG_ERRORS_CLEARED = "%d saved errors deleted."
L.MSG_DEBUG_ON       = "Debug output on."
L.MSG_DEBUG_OFF      = "Debug output off."
L.MSG_COMBAT_OPTIONS = "The options cannot be opened in combat."
L.MSG_NO_OPTIONS     = "Options panel not available."
L.MSG_UNKNOWN_MODULE = "Unknown module \"%s\". /peon list shows all modules."
L.MSG_MODULES        = "Modules:"
L.MSG_NO_MODULES     = "No Peon modules installed."
L.MSG_MODULE_LINE    = "  %s (%s) v%s - %s"
L.STATE_LOADED       = "loaded"
L.STATE_DISABLED     = "not loaded"
L.SECRET             = "<secret>"
L.HELP = {
    "/peon - options",
    "/peon list - installed modules",
    "/peon <module> [command] - command for a module (e.g. /peon tooltip)",
    "/peon debug <module> - debug output of a module on/off",
    "/peon errors [clear] - show or delete saved errors",
}
L.OPT_DESC     = "Shared core of the Peon addon collection. The modules have their own pages below this entry."
L.OPT_MODULES  = "Modules"
L.OPT_VERSION  = "Version %s"
L.RESET        = "Restore defaults"
L.MSG_RESET    = "Defaults restored."
L.POS_none        = "Off"
L.POS_TOPLEFT     = "Top left"
L.POS_TOP         = "Top"
L.POS_TOPRIGHT    = "Top right"
L.POS_LEFT        = "Left"
L.POS_RIGHT       = "Right"
L.POS_BOTTOMLEFT  = "Bottom left"
L.POS_BOTTOM      = "Bottom"
L.POS_BOTTOMRIGHT = "Bottom right"
L.LIST_EMPTY      = "No entries."        -- API 7
L.MINIMAP_DRAG    = "Drag: move button"   -- API 7

if GetLocale() == "deDE" then
    L.MSG_ERROR          = "Fehler in %s: %s"
    L.MSG_ERROR_SAVED    = "Fehler in %s (gespeichert, /peon fehler zeigt den Text)."
    L.MSG_ERRORS_NONE    = "Keine gespeicherten Fehler."
    L.MSG_ERRORS_HEAD    = "Gespeicherte Fehler (neueste zuerst, insgesamt %d):"
    L.MSG_ERRORS_CLEARED = "%d gespeicherte Fehler gelöscht."
    L.MSG_DEBUG_ON       = "Debug-Ausgaben an."
    L.MSG_DEBUG_OFF      = "Debug-Ausgaben aus."
    L.MSG_COMBAT_OPTIONS = "Die Optionen lassen sich im Kampf nicht öffnen."
    L.MSG_NO_OPTIONS     = "Optionsmenü nicht verfügbar."
    L.MSG_UNKNOWN_MODULE = "Unbekanntes Modul „%s“. /peon list zeigt alle Module."
    L.MSG_MODULES        = "Module:"
    L.MSG_NO_MODULES     = "Keine Peon-Module installiert."
    L.STATE_LOADED       = "geladen"
    L.STATE_DISABLED     = "nicht geladen"
    L.SECRET             = "<geheim>"
    L.HELP = {
        "/peon - Optionen",
        "/peon list - installierte Module",
        "/peon <Modul> [Befehl] - Befehl an ein Modul (z. B. /peon tooltip)",
        "/peon debug <Modul> - Debug-Ausgaben eines Moduls an/aus",
        "/peon fehler [leeren] - gespeicherte Fehler zeigen oder löschen",
    }
    L.OPT_DESC    = "Gemeinsamer Kern der Peon-Addonsammlung. Die Module haben eigene Seiten unter diesem Eintrag."
    L.OPT_MODULES = "Module"
    L.RESET       = "Standardwerte wiederherstellen"
    L.MSG_RESET   = "Standardwerte wiederhergestellt."
    L.POS_none        = "Aus"
    L.POS_TOPLEFT     = "Oben links"
    L.POS_TOP         = "Oben"
    L.POS_TOPRIGHT    = "Oben rechts"
    L.POS_LEFT        = "Links"
    L.POS_RIGHT       = "Rechts"
    L.POS_BOTTOMLEFT  = "Unten links"
    L.POS_BOTTOM      = "Unten"
    L.POS_BOTTOMRIGHT = "Unten rechts"
    L.LIST_EMPTY      = "Keine Einträge."
    L.MINIMAP_DRAG    = "Ziehen: Button verschieben"
end
