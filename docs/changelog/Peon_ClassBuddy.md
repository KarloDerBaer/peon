# Peon_ClassBuddy: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Konzept: `docs/konzepte/classbuddy/Peon_ClassBuddy_Konzept.md`.

## 0.1.0

Kurz: Neues Modul Klassenbuddy. Vorerst gibt es nur eine Prüfung, ob Seelensplitter vernichtet werden können.

- 0.1.0 (14.11.2026, Wunsch aus dem Feedback, abgestimmt mit KarloDerBaer): erstes Gerüst mit dem Prüfbefehl `/peon classbuddy pruefen` (Konzept Abschnitt 4.3). Braucht Peon mit Kern-API 18 (Fenster), zum Senden Kern-API 22 und Peon_Feedback 0.5.0.
  - Testet vier Wege, einen Seelensplitter (6265) zu vernichten, jeweils außerhalb und im Kampf: ohne Tastendruck (Zeitgeber nach dem Befehl und beim Kampfbeginn), Klick auf einen Knopf, Makro mit `/click PeonClassBuddyShard`, Aktionstaste (mitlesen nach `UseAction`, `ActionButtonDown`, `ActionButtonUp`, `CastSpellByName`, `CastSpellByID` und `PostClick` von `ActionButton1` bis `12`).
  - Jeder Weg vernichtet je Zustand höchstens einen Splitter. Nur Gegenstand 6265, sonst wird zurückgelegt. Hängt schon etwas am Mauszeiger, passiert nichts.
  - Zeigt Taschen mit Taschentyp, Zahl der Splitter, Gegenstandsfamilie und welche Blizzard-Funktionen es gibt. Meldet, wenn das Spiel das Vernichten sperrt (`ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`).
  - Ergebnisse in `PeonClassBuddyDB.probe`, Befehle `pruefen start`, `pruefen ergebnis`, `pruefen senden`, `pruefen leeren`, `pruefen aus`.
  - **Vorläufiges Fenster für Hexenmeister** (`Guide.lua`, Wunsch KarloDerBaer): erscheint beim Einloggen mit dem Hinweis, dass es nur für einen Test da ist und mit der nächsten Version verschwindet. Führt in sechs Schritten durch die Prüfung, zeigt den Stand je Weg, legt das Makro `PeonSplitter` an und hängt es an den Mauszeiger. Haken „Nicht mehr anzeigen“ (`hideGuide`).
  - **Ergebnis an den Manager:** Knopf „Ergebnis senden“ legt über `Peon.AddFeedback` (Kern-API 22) eine Rückmeldung in Peon_Feedback an (Bereich Prüfung). Nach `/reload` zeigt der Manager sie bei den Rückmeldungen. Ohne Peon_Feedback kommt ein Hinweis. Der Text enthält nur Zahlen und Ja/Nein.
  - Test: `tests/test_classbuddy.lua`.
  - **Im Spiel prüfen:** mit einem Hexenmeister, der mindestens 8 Splitter hat, das Fenster durchgehen und das Ergebnis senden.
