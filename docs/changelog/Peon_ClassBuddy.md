# Peon_ClassBuddy: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Konzept: `docs/konzepte/classbuddy/Peon_ClassBuddy_Konzept.md`.

## 0.2.0

Kurz: Der Klassenbuddy vernichtet für Hexenmeister überzählige Seelensplitter, mit jedem Zauber von der Aktionsleiste einen. Dazu gibt es ein Makro, eine Tastenbelegung und einen Eintrag für die Leiste von Peon Panel.
Kurz: Die Combo-Punkte für Schurken kommen jetzt aus dem Klassenbuddy, deine Einstellungen aus Peon ComboPoints werden übernommen.
Kurz: Das Testfenster für Hexenmeister ist wieder weg.

- 0.2.0 (14.11.2026, abgestimmt mit KarloDerBaer nach der Prüfung mit 0.1.0, Konzept Abschnitt 4.3):
  - **Seelensplitter** (`Warlock_Shards.lua`): Regel einstellbar (`shardRule`): „Seelentasche voll“ (Standard, Splitter außerhalb der vollen Seelentasche sind zu viel, ohne Seelentasche gilt die Höchstzahl) oder „Mehr als die Höchstzahl“ (`shardMax`, Standard 20, zuerst außerhalb der Seelentasche). Vernichtet wird von hinten.
  - **Auslösen:** Nachlauf auf `UseAction` (`hooksecurefunc`), je Zauber höchstens ein Splitter (`shardAction`). Unsichtbarer Knopf `PeonClassBuddyShard` für Makro, Tastenbelegung „Seelensplitter vernichten“ (`Bindings.xml`) und den neuen Eintrag „Seelensplitter“ für Peon Panel (Zahl der Splitter, Klick vernichtet einen). Knopf „Makro anlegen“ in den Optionen. Nie aus einem Ereignis, das sperrt das Spiel.
  - **Sicherheit:** nur Gegenstand 6265, gesperrte Plätze (`isLocked`) werden übersprungen, nichts bei belegtem Mauszeiger oder wenn ein Zauber ein Ziel sucht (`SpellIsTargeting`). Klappt es nicht, wird zurückgelegt und beim nächsten Zauber neu versucht, der Grund steht im Debug-Log. Meldung im Chat abschaltbar (`shardMsg`).
  - **Combo-Punkte** (`Rogue_ComboPoints.lua`): Code aus Peon_ComboPoints 3.5.1 unverändert übernommen, Einstellungen mit denselben Namen. Beim ersten Einloggen werden die Werte aus `PeonComboPointsDB` geprüft übernommen (`cpImported`). Peon_ComboPoints 3.6.0 bleibt dann still.
  - **Optionen** mit Reitern Schurke und Hexenmeister, geöffnet wird der Reiter der eigenen Klasse. Befehle `/peon classbuddy` (Optionen) und `/peon classbuddy splitter` (Zahl der Splitter).
  - **Entfernt:** Prüfung (`Probe.lua`) und Testfenster (`Guide.lua`) aus 0.1.0, ihre Einträge `probe` und `hideGuide` werden gelöscht.
  - Tests: `test_classbuddy.lua` neu (Regeln, Aktionstaste, gesperrte Plätze, Mauszeiger, Kampf, Sperre, Knopf, Makro, Übernahme, Combo-Punkte).
  - **Im Spiel prüfen:** Hexenmeister mit voller Seelentasche: Zauber wirken, je Zauber verschwindet ein Splitter außerhalb der Seelentasche, auch im Kampf. Makro und Tastenbelegung. Schurke: Combo-Punkte wie bisher, Einstellungen übernommen, Peon ComboPoints meldet einmal den Umzug.

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
