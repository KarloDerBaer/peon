-- Peon_Warhorn - Locales.lua
-- Allgemeine Texte (Fehler, Standardwerte, Positionen) liefert der Peon-Kern (Peon.L)
local ADDON_NAME, ns = ...

local L = Peon.NewLocale()
ns.L = L

-- enUS (Standard)
L.DESC         = "Groups, dungeons and raids. This version only contains a test of the group finder."
L.HDR_PROBE    = "Group finder test"
L.PROBE_HINT   = "Open the group finder, pick a category and start the test. It searches twice (once after your click, once on its own) and watches the results for 60 seconds. Afterwards type /reload so the result is saved."
L.BTN_PROBE    = "Start test"
L.BTN_PROBE_HINT = "If WoW shows a message that the addon was blocked, choose Ignore. That is part of the test."
L.SLASH_HINT   = "Chat: /peon warhorn opens this panel, /peon warhorn pruefen starts the test."

L.P_COMBAT     = "Not possible in combat."
L.P_RUNNING    = "The test is still running."
L.P_NO_API     = "The game has no group finder interface (C_LFGList.Search is missing)."
L.P_NO_CAT     = "No category found. Open the group finder and pick a category."
L.P_START      = "Test started (category %s). Please wait about 80 seconds."
L.P_STEP_KEY   = "Search after key press"
L.P_STEP_CLICK = "Search after click"
L.P_STEP_AUTO  = "Search on its own"
L.P_RES_OK     = "%s: %d results"
L.P_RES_FAIL   = "%s: failed"
L.P_RES_NONE   = "%s: no answer"
L.P_RES_ERR    = "%s: error"
L.P_BLOCKED    = " (blocked by the game)"
L.P_WATCH      = "Updates within %d seconds: %d"
L.P_SECRETS    = "Secret values: %d"
L.P_DONE       = "Test finished. Type /reload so the result is saved (SavedVariables, Peon_Warhorn.lua)."
L.P_LAST       = "Last test: %s"
L.P_NEVER      = "No test yet."

if GetLocale() == "deDE" then
    L.DESC         = "Gruppen, Dungeons und Raids. Diese Version enthält nur eine Prüfung der Gruppensuche."
    L.HDR_PROBE    = "Prüfung der Gruppensuche"
    L.PROBE_HINT   = "Öffne die Gruppensuche, wähle eine Kategorie und starte die Prüfung. Sie sucht zweimal (einmal nach deinem Klick, einmal von selbst) und beobachtet die Ergebnisse 60 Sekunden lang. Danach /reload eingeben, damit das Ergebnis gespeichert wird."
    L.BTN_PROBE    = "Prüfung starten"
    L.BTN_PROBE_HINT = "Meldet WoW, dass das Addon blockiert wurde, wähle Ignorieren. Das gehört zur Prüfung."
    L.SLASH_HINT   = "Chat: /peon warhorn öffnet dieses Menü, /peon warhorn pruefen startet die Prüfung."

    L.P_COMBAT     = "Im Kampf nicht möglich."
    L.P_RUNNING    = "Die Prüfung läuft noch."
    L.P_NO_API     = "Das Spiel hat keine Schnittstelle für die Gruppensuche (C_LFGList.Search fehlt)."
    L.P_NO_CAT     = "Keine Kategorie gefunden. Öffne die Gruppensuche und wähle eine Kategorie."
    L.P_START      = "Prüfung gestartet (Kategorie %s). Bitte etwa 80 Sekunden warten."
    L.P_STEP_KEY   = "Suche nach Tastendruck"
    L.P_STEP_CLICK = "Suche nach Klick"
    L.P_STEP_AUTO  = "Suche von selbst"
    L.P_RES_OK     = "%s: %d Ergebnisse"
    L.P_RES_FAIL   = "%s: fehlgeschlagen"
    L.P_RES_NONE   = "%s: keine Antwort"
    L.P_RES_ERR    = "%s: Fehler"
    L.P_BLOCKED    = " (vom Spiel blockiert)"
    L.P_WATCH      = "Aktualisierungen in %d Sekunden: %d"
    L.P_SECRETS    = "Geheime Werte: %d"
    L.P_DONE       = "Prüfung fertig. Bitte /reload eingeben, damit das Ergebnis gespeichert wird (SavedVariables, Peon_Warhorn.lua)."
    L.P_LAST       = "Letzte Prüfung: %s"
    L.P_NEVER      = "Noch keine Prüfung."
end
