# Peon_Warhorn: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`.

## 0.2.0

Kurz: Warhorn liegt jetzt über Blizzards Gruppensuche und filtert Gruppen und Mitspieler nach Rolle, Klasse und Stufe. Mit dem Knopf Blizzard kommst du jederzeit zur Originalansicht zurück.

- 0.2.0 (17.11.2026, Konzept `docs/konzepte/warhorn/Peon_Warhorn_Konzept.md`, Schritte 2 bis 4 auf Wunsch von KarloDerBaer in einem Zug):
  - **Fläche über Blizzards Suchseite** (`Overlay.lua`, `Window.lua`): hängt an `LFGBrowseFrame`, ist also nur auf Blizzards Reiter „Suchen“ zu sehen und wandert mit, wenn Peon_Mover das Fenster verschiebt. Links oben bündig, 680 breit, unten endet sie über Blizzards Reitern (angehängt an `LFGParentFrameTab1`). Die Titelleiste lässt Klicks zu Blizzards Fenster durch (Verschieben mit Peon_Mover). Schließen schließt Blizzards Gruppensuche.
  - **Umschalten ohne Neuladen:** Knopf „Blizzard“ in Warhorn, Knopf „Warhorn“ oben an Blizzards Suchseite, Haken in den Optionen (`show`). Warhorn schreibt nichts in Blizzards Tabellen.
  - **Auswahl:** eigene Kategorie und Aktivitäten (mehrere), beim ersten Mal aus Blizzards Auswahl, je Charakter gemerkt.
  - **Suchen** (`Search.lua`) nur über den Knopf „Suchen“, den Knopf zum Neuladen, die Taste „Gruppensuche: Suchen“ (`Bindings.xml`) und `/warhorn suchen`, nie automatisch. Sucht Blizzards eigener Knopf, übernimmt Warhorn das Ergebnis. Änderungen an gefundenen Einträgen zeigt die Liste sofort. Im Kampf ist Suchen gesperrt. Lehnt das Spiel ab, steht das in der Statuszeile.
  - **Reiter Gruppen** (`Filter.lua`): freier Platz für die gewählten Rollen (Start mit Blizzards Rollenwahl), Klassen „nur mit“ oder „nur ohne“, ohne meine Klasse, Gruppengröße höchstens 2, 3 oder 4, Stufe von bis (ein Mitglied im Bereich). Spalten Aktivität, Anführer, Stufe, Rollen (Symbol, Anzahl, freie Plätze grün), Klassen, Alter.
  - **Reiter Mitspieler:** Einträge mit einem Mitglied, Filter nach Rolle, Klasse und Stufe. Spalten Name, Klasse, Stufe, Rollen, Aktivität, Alter.
  - Zahl der Treffer an den Reitern, Statuszeile mit Treffern und Alter der Suche (ab 60 Sekunden gold mit Hinweis). Neue Einträge seit der letzten Suche grün hinterlegt, der eigene Eintrag blau und oben, ausgetragene grau. Sortierung zu Beginn nach Alter.
  - **Tooltip** mit Aktivitäten, Anführer, Kommentar, Mitgliedern (Rolle, Klasse, Stufe) und Alter. **Doppelklick** flüstert an, **Rechtsklick** öffnet ein Menü mit Anflüstern und Einladen (Einladen nur bei Einzelspielern und wenn man einladen darf, wie bei Blizzard).
  - Einträge mit geheimen Werten werden nie herausgefiltert und nicht ausgewertet, der Tooltip nennt das.
  - `/warhorn` öffnet Blizzards Gruppensuche auf dem Reiter „Suchen“ (über Blizzards `LFGVanilla_ToggleFrame`), `/warhorn optionen` die Optionen. Starter für Peon_Panel.
  - Neu `PeonWarhornCharDB` (je Charakter): `category`, `activities`, `tab`, `gFilter`, `pFilter`. Braucht Peon API 18.
  - Tests: `test_warhorn.lua` neu aufgebaut (Fläche, Suche, alle Filter, Reiter, Tooltip, Aktionen, Aktualisierung, Kampf, Umschalten, Prüfaufbau).
  - **Im Spiel prüfen:** Lage und Größe der Fläche (Unterkante über Blizzards Reitern, Knopf „Warhorn“ oben rechts), Symbole für Rollen und Klassen, ob `/warhorn` die Gruppensuche ohne Fehlermeldung öffnet, ob Einladen aus Warhorn geht.

## 0.1.0

Kurz: Neues Modul für Gruppen, Dungeons und Raids. Diese erste Version prüft nur, was die Gruppensuche im Spiel erlaubt.

- 0.1.0 (17.11.2026, Schritt 1 des Plans unter „Offene Punkte“ in `Peon_Stand.md`):
  - **Prüfaufbau:** `/peon warhorn pruefen` oder der Knopf „Prüfung starten“ auf der Optionsseite. Sucht in der Gruppensuche zweimal mit `C_LFGList.Search`: einmal direkt nach Tastendruck oder Klick, drei Sekunden später von selbst über einen Zeitgeber. Danach zählt die Prüfung 60 Sekunden lang, wie oft das Spiel gefundene Einträge von selbst aktualisiert (`LFG_LIST_SEARCH_RESULT_UPDATED`).
  - **Gelesen wird:** welche Fenster es gibt (`LFGParentFrame`, `LFGBrowseFrame`, `PVEFrame` und weitere), ob Blizzards Gruppensuche im Vanilla-Stil geladen ist, welche Funktionen von `C_LFGList` vorhanden sind, je Suche Antwort, Anzahl und bis zu 15 Einträge mit Feldern, Anzahl je Rolle, Anführer und bis zu 10 Mitgliedern (Klasse, Stufe, Rolle, mögliche Rollen). Blockiert das Spiel die Suche (`ADDON_ACTION_BLOCKED` oder `ADDON_ACTION_FORBIDDEN`), wird das gemerkt.
  - **Datenschutz:** Namen anderer Spieler, Titel und Kommentare der Einträge werden nicht gespeichert, nur ob sie lesbar, leer oder geheim sind. Geheime Werte werden nicht ausgewertet, nur gezählt.
  - Kategorie und Aktivitäten kommen aus Blizzards Auswahl im Fenster, sonst die erste verfügbare Kategorie mit allen Aktivitäten. Blizzards Fenster wird nur gelesen. Im Kampf startet die Prüfung nicht.
  - Ergebnis in `PeonWarhornDB.probe`, nach `/reload` in `SavedVariables\Peon_Warhorn.lua`. Kurze Zusammenfassung im Chat und auf der Optionsseite.
  - Tests: `test_warhorn.lua`.
  - **Im Spiel geprüft (KarloDerBaer, 17.11.2026):** Beide Wege ausgeführt (Taste und Knopf). Suche nach Klick geht, Suche von selbst blockiert das Spiel, Änderungen an gefundenen Einträgen kommen von selbst, keine geheimen Werte. Einzelheiten in `Peon_Stand.md` unter „Offene Punkte“.
