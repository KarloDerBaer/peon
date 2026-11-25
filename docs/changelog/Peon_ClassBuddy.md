# Peon_ClassBuddy: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Konzept: `docs/konzepte/classbuddy/Peon_ClassBuddy_Konzept.md`.

## 0.5.0

Kurz: Die Einstellungen haben jetzt die Reiter Allgemein, Anzeige und Erweitert, nur mit den Teilen deiner Klasse. Erklärungen stehen im Tooltip.

- 0.5.0 (25.11.2026, Leitfaden für Einstellungen, Aufteilung von KarloDerBaer freigegeben):
  - **Geändert:** Statt Reitern je Klasse gibt es Allgemein (Schurke: Gifte an, Gift je Hand, Ersetzen, Erinnerung mit Ton, Makro anlegen. Hexenmeister: Seelensplitter vernichten, Regel, mit Zaubern, Meldung, Makro anlegen), Anzeige (nur Schurke: Combo-Punkte mit Farben und Vorschau) und Erweitert (Gifte erneuern ab, Ladungen ab, Erinnerung ab, Höchstzahl der Seelensplitter). Gespeicherte Werte und ihre Namen bleiben gleich.
  - **Geändert:** Jeder Schalter hat einen Satz als Tooltip statt Text darunter (Kern-API 29). Die Erklärung zur Taste steht im Tooltip des Knopfs „Makro anlegen“.
  - **Entfernt:** Statuszeilen der Gifte und der Bericht zu den Seelensplittern auf der Optionsseite. Sie bleiben als `/peon classbuddy gifte` und `/peon classbuddy splitter`.
  - Tests: `test_classbuddy.lua`, `test_classbuddy_schurke.lua` (Reiter je Klasse).

## 0.4.1

Kurz: Combo-Punkte erscheinen nicht mehr über Fässern, Truhen und anderen Objekten in der Welt, sondern nur noch über echten Gegnern.

- 0.4.1 (24.11.2026, Meldung KarloDerBaer):
  - **Behoben:** Seit das Spiel die Interaktionstaste mit Soft Targeting nutzt, bekommen auch Objekte in Reichweite ein Nameplate. Die Combo-Punkte prüften nur `UnitCanAttack` und zeigten sich deshalb auch an solchen Objekten. Jetzt gilt ein Nameplate nur als Gegner, wenn `UnitIsGameObject` nein sagt (ein geheimes Ergebnis zählt als Objekt) und der Rahmen wirklich zum Unit-Token gehört. Ein wiederverwendeter Rahmen mit altem Token zeigt nichts mehr.
  - Peon_Fishing schaltet Namen über Objekten (`SoftTargetNameplateInteract`) nur in der Anzeige „Text“ und nur bei ausgeworfener Angel ein und setzt den alten Wert danach zurück. Die Meldung kommt also vom Spiel selbst, nicht von Fishing.
  - Test: `test_classbuddy_schurke.lua` mit Nameplates (Gegner, Fass, Fass als Ziel, Rahmen mit altem Token).

## 0.4.0

Kurz: Schurken tragen Gifte jetzt mit einer Taste auf. Jeder Druck legt das nächste fehlende oder bald ablaufende Gift auf, zuerst auf die Haupthand, dann auf die Nebenhand.
Kurz: Der Klassenbuddy erinnert dich, wenn ein Gift fehlt, bald ausläuft oder in den Taschen knapp wird.
Kurz: Neuer Eintrag „Gifte“ für Peon Panel: Linksklick trägt das nächste Gift auf, Rechtsklick wählt das Gift je Waffe, auf Wunsch mit Anzahl in den Taschen.
Kurz: Der Klassenbuddy zeigt nur noch die Helfer deiner Klasse, in den Optionen und im Panel.

- 0.4.0 (18.11.2026, Wunsch KarloDerBaer, Vorschlag A mit Erinnerung, Konzept Abschnitt 10):
  - **Gift-Taste** (`Rogue_Poisons.lua`): sicherer Knopf `PeonClassBuddyPoison` (Typ `item`, `target-slot`, wirkt beim Loslassen), Tastenbelegung „Gift auftragen“, Makro `PeonGift` über den Knopf „Makro anlegen“. Gift je Hand wählbar (`poisonMain` Standard Sofort wirkend, `poisonOff` Standard Tödlich, oder keins), genommen wird der höchste benutzbare Rang. Erneuert unter `poisonRenew` Minuten (Standard 10) oder `poisonCharges` Ladungen (Standard 10, 0 = aus). Im Kampf gilt die beim Kampfbeginn vorbereitete Hand.
  - **Ersetzen ohne Nachfrage** (`poisonReplace`): Die Frage des Spiels direkt nach dem Druck bestätigt der Klassenbuddy selbst. Sperrt das Spiel das, kommt die Frage wieder mit Hinweis im Chat.
  - **Erinnerung** (`poisonWarn`, `poisonSound`): einmal in der Bildschirmmitte, wenn ein Gift fehlt oder abläuft und ein passendes in den Taschen liegt. Nicht im Kampf, tot, auf dem Flug oder in Stadt und Gasthaus. Dazu nach Einloggen, Instanz, Wiederbeleben und Bereitschaftscheck. Vorratswarnung bei `poisonLow` oder weniger (Standard 5, 0 = aus).
  - Neuer Reiter „Gifte“ in den Optionen, Befehl `/peon classbuddy gifte`, Rückmeldebereich „Gifte“.
  - **Panel-Eintrag „Gifte“:** Texte Restzeit, Gifte in den Taschen oder beides (im Menü des Panels wählbar). Beim Tooltip legt sich der unsichtbare sichere Knopf `PeonClassBuddyPoisonPanel` über das Symbol (nur positioniert, nicht angehängt, damit das Panel im Kampf frei bleibt). Linksklick klickt die Gift-Taste, Rechtsklick, Tooltip und Ziehen gehen an das Symbol weiter. Im Kampf verschwindet der Knopf, ein Klick auf das Symbol erklärt, dass nur die Taste geht. Das Menü wählt das Gift je Waffe, jeweils mit Anzahl in den Taschen.
  - **Nur die eigene Klasse:** Panel-Einträge (Gifte, Seelensplitter) entstehen nur für die passende Klasse (`ns.ForClass`), die Optionen zeigen nur ihre Reiter. Andere Klassen sehen einen Hinweis.
  - Tests: `test_classbuddy_schurke.lua` neu (Combo-Punkte, Auswahl, Ränge, Taste, Kampf, Ersetzen und Sperre, Waffen, Erinnerung, Vorrat, Makro, Befehl, Panel mit Klick, Menü und Kampf, Reiter). `test_classbuddy.lua` läuft als Hexenmeister und prüft, dass nichts vom Schurken da ist.

Kurz: Neue Regel „Seelentasche minus 1“ für Seelensplitter, jetzt der Standard: Ein Platz der Seelentasche bleibt immer frei, so landet ein neuer Splitter nie in einer normalen Tasche.

- 0.3.0 (14.11.2026, Wunsch KarloDerBaer nach dem Test von 0.2.0): Regel `free` in `shardRule`. Erlaubt sind so viele Splitter, wie die Seelentaschen Plätze haben, weniger einer. Zu viel sind zuerst die außerhalb, dann der hinterste in der Seelentasche. Ohne Seelentasche gilt die Höchstzahl. Meldung „ein Platz der Seelentasche bleibt frei“.
  - Neuer Standard `free`. Wer noch den alten Standard `bag` hat, bekommt einmal `free` (`shardRule3`). Danach bleibt jede eigene Wahl.
  - Test: `test_classbuddy.lua` (Regel, Reihenfolge, ohne Seelentasche, Aktionstaste, Umstellung).
  - **Im Spiel prüfen:** Seelentasche bis auf einen Platz füllen, beim nächsten Splitter und Zauber wird einer vernichtet, kein Splitter in einer normalen Tasche.

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
