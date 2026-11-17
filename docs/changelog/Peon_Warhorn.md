# Peon_Warhorn: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`.

## 0.1.0

Kurz: Neues Modul für Gruppen, Dungeons und Raids. Diese erste Version prüft nur, was die Gruppensuche im Spiel erlaubt.

- 0.1.0 (17.11.2026, Schritt 1 des Plans unter „Offene Punkte“ in `Peon_Stand.md`):
  - **Prüfaufbau:** `/peon warhorn pruefen` oder der Knopf „Prüfung starten“ auf der Optionsseite. Sucht in der Gruppensuche zweimal mit `C_LFGList.Search`: einmal direkt nach Tastendruck oder Klick, drei Sekunden später von selbst über einen Zeitgeber. Danach zählt die Prüfung 60 Sekunden lang, wie oft das Spiel gefundene Einträge von selbst aktualisiert (`LFG_LIST_SEARCH_RESULT_UPDATED`).
  - **Gelesen wird:** welche Fenster es gibt (`LFGParentFrame`, `LFGBrowseFrame`, `PVEFrame` und weitere), ob Blizzards Gruppensuche im Vanilla-Stil geladen ist, welche Funktionen von `C_LFGList` vorhanden sind, je Suche Antwort, Anzahl und bis zu 15 Einträge mit Feldern, Anzahl je Rolle, Anführer und bis zu 10 Mitgliedern (Klasse, Stufe, Rolle, mögliche Rollen). Blockiert das Spiel die Suche (`ADDON_ACTION_BLOCKED` oder `ADDON_ACTION_FORBIDDEN`), wird das gemerkt.
  - **Datenschutz:** Namen anderer Spieler, Titel und Kommentare der Einträge werden nicht gespeichert, nur ob sie lesbar, leer oder geheim sind. Geheime Werte werden nicht ausgewertet, nur gezählt.
  - Kategorie und Aktivitäten kommen aus Blizzards Auswahl im Fenster, sonst die erste verfügbare Kategorie mit allen Aktivitäten. Blizzards Fenster wird nur gelesen. Im Kampf startet die Prüfung nicht.
  - Ergebnis in `PeonWarhornDB.probe`, nach `/reload` in `SavedVariables\Peon_Warhorn.lua`. Kurze Zusammenfassung im Chat und auf der Optionsseite.
  - Tests: `test_warhorn.lua`.
  - **Im Spiel prüfen:** Gruppensuche öffnen, Kategorie wählen, `/peon warhorn pruefen`, etwa 80 Sekunden warten, dann `/reload`. Meldet WoW, dass das Addon blockiert wurde, „Ignorieren“ wählen.
