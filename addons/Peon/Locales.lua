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
    "/peon news - show the notices of the modules again",
    "/peon share [on | off | check] - share data with other Peon users",
    "/peon ui - sample window of the UI design",
    "/peon ui check [mouse | <frame> | clear] - read Blizzard's window art for the UI design",
}
-- UI check (0.18.0)
L.UIPROBE_HELP = {
    "/peon ui - sample window with all building blocks",
    "/peon ui check - atlases, fonts, templates and all open Blizzard windows",
    "/peon ui check mouse - the frame under the mouse",
    "/peon ui check <frame> - one frame, e.g. AuctionHouseFrame.CategoriesList",
    "/peon ui check clear - delete the saved results",
}
L.UIPROBE_DONE      = "UI check: %d atlases (%d missing), %d fonts, %d template lines. Windows: %s."
L.UIPROBE_NONE      = "none open"
L.UIPROBE_HINT      = "Saved in PeonDB.uiProbe. /reload writes it to WTF."
L.UIPROBE_MOUSE     = "UI check: %s saved (%d lines)."
L.UIPROBE_FRAME     = "UI check: %s saved (%d lines)."
L.UIPROBE_NOT_FOUND = "UI check: frame \"%s\" not found."
L.UIPROBE_NO_MOUSE  = "UI check: no frame under the mouse."
L.UIPROBE_CLEARED   = "UI check: results deleted."
-- Share data (Comm.lua, API 23)
L.COMM_OPT          = "Share data"
L.COMM_OPT_SHARE    = "Share data with other Peon users"
L.COMM_OPT_HINT     = "Peon quietly gets to know other Peon users through a hidden channel and invisible addon whispers. Nothing shows up in the chat, no character names are stored. For now only the version is exchanged, later the modules share game data such as gathering spots."
L.COMM_STATUS       = "Channel %s, %d Peon users reachable, %d met so far. Messages: %d sent, %d received, %d passed on."
L.COMM_STATUS_OFF   = "Sharing is off."
L.COMM_OFF_HINT     = "Sharing is off. /peon share on switches it on."
L.COMM_NOW_ON       = "Sharing data with other Peon users is on."
L.COMM_NOW_OFF      = "Sharing data with other Peon users is off. Peon left the channel."
L.COMM_HELP = {
    "/peon share on | off - switch sharing on or off",
    "/peon share check - test in the game: channel message, addon whisper, member list",
}
L.COMM_PROBE_START  = "Share check is running (about 10 seconds) ..."
L.COMM_PROBE_COMBAT = "The share check does not run in combat."
L.COMM_PROBE_CHANNEL   = "Channel: %s, joined: %s"
L.COMM_PROBE_CHAN_ECHO = "Addon message in the channel: sent %s, arrived %s"
L.COMM_PROBE_WHISPER   = "Addon whisper to yourself: sent %s, arrived %s"
L.COMM_PROBE_ROSTER    = "Member list: %d names read (the game reports %d members)"
L.COMM_PROBE_SAVED  = "Saved in PeonDB.comm.probe. /reload writes it to WTF."
L.COMM_YES = "yes"
L.COMM_NO  = "no"
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


-- Gegenstandsmenue (API 16)
L.ITEMMENU_OPT        = "Item menu"
L.ITEMMENU_OPT_HINT   = "Click on any item (bags, bank, vendor, quest, loot, chat links) opens a menu with entries of the Peon modules, for example \"Add to shopping list\". Shift+right-click is already used by Blizzard (split stack, buy several stacks). Additionally you can assign a key under Key Bindings > AddOns > Peon."
L.ITEMMENU_CTRL_RIGHT = "Ctrl+right-click"
L.ITEMMENU_ALT_RIGHT  = "Alt+right-click"
L.ITEMMENU_SHIFT_RIGHT = "Shift+right-click (opens Blizzard's stack windows too)"
L.ITEMMENU_CTRL_MIDDLE = "Ctrl+middle click"
L.ITEMMENU_MIDDLE     = "Middle click"
L.ITEMMENU_OFF        = "Off"
-- Einmalige Hinweise (API 20)
L.NOTICE_TITLE  = "Peon: Important notes"
L.NOTICE_OK     = "Got it"
L.NOTICE_AGAIN  = "/peon news shows these notes again."
L.NOTICE_NONE   = "No notes."
L.NOTICE_COMBAT = "The notes cannot be shown in combat."
BINDING_HEADER_PEON   = "Peon"
BINDING_NAME_PEON_ITEM_MENU = "Item menu for the item under the mouse"

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
        "/peon neu - Hinweise der Module wieder zeigen",
        "/peon teilen [an | aus | pruefen] - Daten mit anderen Peon-Nutzern teilen",
        "/peon ui - Beispielfenster zum UI-Design",
        "/peon ui pruefen [maus | <Fenster> | leeren] - Grafiken von Blizzards Fenstern auslesen (UI-Design)",
    }
    L.UIPROBE_HELP = {
        "/peon ui - Beispielfenster mit allen Bausteinen",
        "/peon ui pruefen - Grafiken, Schriften, Vorlagen und alle offenen Blizzard-Fenster",
        "/peon ui pruefen maus - der Rahmen unter der Maus",
        "/peon ui pruefen <Fenster> - ein Rahmen, z. B. AuctionHouseFrame.CategoriesList",
        "/peon ui pruefen leeren - gespeicherte Ergebnisse löschen",
    }
    L.UIPROBE_DONE      = "UI-Prüfung: %d Grafiken (%d fehlen), %d Schriften, %d Zeilen Vorlagen. Fenster: %s."
    L.UIPROBE_NONE      = "keins offen"
    L.UIPROBE_HINT      = "Gespeichert in PeonDB.uiProbe. /reload schreibt es in WTF."
    L.UIPROBE_MOUSE     = "UI-Prüfung: %s gespeichert (%d Zeilen)."
    L.UIPROBE_FRAME     = "UI-Prüfung: %s gespeichert (%d Zeilen)."
    L.UIPROBE_NOT_FOUND = "UI-Prüfung: Rahmen „%s“ nicht gefunden."
    L.UIPROBE_NO_MOUSE  = "UI-Prüfung: kein Rahmen unter der Maus."
    L.UIPROBE_CLEARED   = "UI-Prüfung: Ergebnisse gelöscht."
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
    -- Gegenstandsmenue (API 16)
    L.ITEMMENU_OPT        = "Gegenstandsmenü"
    L.ITEMMENU_OPT_HINT   = "Klick auf einen Gegenstand (Taschen, Bank, Händler, Quest, Beute, Chat-Links) öffnet ein Menü mit Einträgen der Peon-Module, zum Beispiel „Auf Einkaufsliste“. Umschalt+Rechtsklick ist bei Blizzard schon belegt (Stapel teilen, mehrere Stapel kaufen). Zusätzlich lässt sich unter Tastenbelegung > AddOns > Peon eine Taste vergeben."
    L.ITEMMENU_CTRL_RIGHT = "Strg+Rechtsklick"
    L.ITEMMENU_ALT_RIGHT  = "Alt+Rechtsklick"
    L.ITEMMENU_SHIFT_RIGHT = "Umschalt+Rechtsklick (öffnet auch Blizzards Stapel-Fenster)"
    L.ITEMMENU_CTRL_MIDDLE = "Strg+Mittelklick"
    L.ITEMMENU_MIDDLE     = "Mittelklick"
    L.ITEMMENU_OFF        = "Aus"
    -- Daten teilen (Comm.lua, API 23)
    L.COMM_OPT          = "Daten teilen"
    L.COMM_OPT_SHARE    = "Daten mit anderen Peon-Nutzern teilen"
    L.COMM_OPT_HINT     = "Peon lernt über einen versteckten Kanal und unsichtbares Addon-Flüstern still andere Peon-Nutzer kennen. Im Chat erscheint nichts, Charakternamen werden nicht gespeichert. Vorerst geht nur die Version hin und her, später teilen die Module Spieldaten wie Sammelstellen."
    L.COMM_STATUS       = "Kanal %s, %d Peon-Nutzer erreichbar, %d bisher kennengelernt. Nachrichten: %d gesendet, %d empfangen, %d weitergegeben."
    L.COMM_STATUS_OFF   = "Teilen ist aus."
    L.COMM_OFF_HINT     = "Teilen ist aus. /peon teilen an schaltet es ein."
    L.COMM_NOW_ON       = "Daten mit anderen Peon-Nutzern teilen ist an."
    L.COMM_NOW_OFF      = "Daten mit anderen Peon-Nutzern teilen ist aus. Peon hat den Kanal verlassen."
    L.COMM_HELP = {
        "/peon teilen an | aus - Teilen ein- oder ausschalten",
        "/peon teilen pruefen - Prüfung im Spiel: Kanal-Nachricht, Addon-Flüstern, Mitgliederliste",
    }
    L.COMM_PROBE_START  = "Prüfung läuft (etwa 10 Sekunden) ..."
    L.COMM_PROBE_COMBAT = "Die Prüfung läuft nicht im Kampf."
    L.COMM_PROBE_CHANNEL   = "Kanal: %s, beigetreten: %s"
    L.COMM_PROBE_CHAN_ECHO = "Addon-Nachricht im Kanal: gesendet %s, angekommen %s"
    L.COMM_PROBE_WHISPER   = "Addon-Flüstern an sich selbst: gesendet %s, angekommen %s"
    L.COMM_PROBE_ROSTER    = "Mitgliederliste: %d Namen gelesen (das Spiel meldet %d Mitglieder)"
    L.COMM_PROBE_SAVED  = "Gespeichert in PeonDB.comm.probe. /reload schreibt es in WTF."
    L.COMM_YES = "ja"
    L.COMM_NO  = "nein"
    L.NOTICE_TITLE  = "Peon: Wichtige Hinweise"
    L.NOTICE_OK     = "Verstanden"
    L.NOTICE_AGAIN  = "/peon neu zeigt diese Hinweise wieder."
    L.NOTICE_NONE   = "Keine Hinweise."
    L.NOTICE_COMBAT = "Die Hinweise lassen sich im Kampf nicht zeigen."
    BINDING_NAME_PEON_ITEM_MENU = "Gegenstandsmenü für den Gegenstand unter der Maus"
end
