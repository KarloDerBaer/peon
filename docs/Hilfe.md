# Hilfe zu den Peon-Addons

Hier steht kurz, was jedes Addon tut, wie du es bedienst und wo du es einstellst. Der Peon Manager zeigt denselben Text unter **Hilfe**.

Alle Addons haben ihre Einstellungen im Spiel unter **Einstellungen > AddOns > Peon**. Tastenbelegungen stehen unter **Tastaturbelegung > AddOns**. Nach Änderungen an Addons reicht im Spiel `/reload`.

## Peon

Der gemeinsame Kern. Ohne ihn läuft kein anderes Peon-Addon.

- `/peon` öffnet die Einstellungen, `/peon list` zeigt die geladenen Addons.
- `/peon fehler` zeigt gespeicherte Fehler, `/peon fehler leeren` löscht sie.
- `/peon neu` zeigt die Hinweise der Addons noch einmal.
- **Gegenstandsmenü:** Strg und Rechtsklick auf einen Gegenstand öffnet ein Menü der Peon-Addons (einstellbar).
- **Daten teilen:** Peon tauscht still kleine Datenpakete mit anderen Peon-Nutzern aus, zum Beispiel für die Rezepte deiner Freunde. Im Chat erscheint nichts. `/peon teilen aus` schaltet es ab, `/peon teilen an` wieder ein.
- **Profile:** Alle Charaktere nutzen das Profil „Standard“. Unter **Peon > Profile** oder mit `/peon profil benutzen <Name>` bekommt ein Charakter ein eigenes Profil (ein neuer Name startet als Kopie der jetzigen Einstellungen). Was du einstellst, gilt dann für alle Charaktere mit diesem Profil. `/peon profil standard` wechselt zurück. Fensterpositionen und die Daten der Addons gelten immer für alle.

## Peon_Broker

Helfer fürs Auktionshaus mit eigenem Fenster und Reitern direkt im Auktionshaus.

- `/broker` öffnet und schließt das Broker-Fenster, `/broker optionen` die Einstellungen.
- **Komplettscan:** Knopf oben im Auktionshaus oder `/broker scan`. Danach kennt Broker die Preise des ganzen Markts.
- **Reiter:** Markt (Preise und Suche), Verkaufen (Rat zum Preis), Auktionen, Einkaufen (Einkaufslisten), Beobachten (Preisalarm), Radar (günstige Angebote), Chancen (vom Peon Manager), Fokus (ein Gegenstand genau beobachtet), Gegenstand.
- **Tooltip:** zeigt Preise, Trend und Bestand. Die Teile stellst du unter Peon > Broker ein.
- **Tasten:** „Radar: gewählten Treffer kaufen“ und „Radar: nächster Treffer“.
- Mit dem Peon Manager und seinem Modul Peon Broker Client bekommt Broker zusätzlich Preise aus der Blizzard-API und Chancen.

## Peon_Ledger

Bestand aller Charaktere und ein Buch über Einnahmen und Ausgaben.

- `/ledger` öffnet das Fenster mit Übersicht, Bestand, Buch, Verlauf und Info.
- `/ledger <Name oder Link>` zeigt einen Gegenstand.
- **Peon Post:** eigenes Postfenster mit Eingang, Einsammeln und Senden (abschaltbar).
- **Tooltip:** zeigt, wie viel davon deine Charaktere haben und was es gekostet hat.
- **Taste:** „Gegenstand unter der Maus in Ledger zeigen“.
- Bank und Post kennt Ledger erst, wenn der Charakter sie einmal geöffnet hat.

## Peon_Bags

Taschen, Bank und Gildenbank in je einem eigenen Fenster.

- Die Taste B öffnet die Taschen wie gewohnt. `/peon bags` öffnet sie auch, `/peon bags optionen` die Einstellungen.
- **Suche** oben im Fenster, **Sortieren** per Knopf.
- **Einstellen:** Knopf im Fenster. Dort wählst du Kategorien, eigene Bereiche und das Layout.
- Eigene Bereiche: einen Gegenstand auf die Überschrift eines eigenen Bereichs ziehen, dann bleibt er dort.

## Peon_Profession

Berufe leveln mit Plan, Preisen und Einkaufsliste.

- `/prof` öffnet das Fenster mit Guide, Route, Material, Verlauf und Codex.
- **Guide:** sagt, was du als Nächstes herstellst, mit Kosten aus Broker.
- **Berufsfenster:** zeigt Kosten und Gewinn je Rezept und eine Leiste mit dem nächsten Schritt.
- **Codex:** alle Rezepte mit Herkunft, Sammelgebiete für Erze, Kräuter und Fische, dazu die Rezepte deiner Freunde und Gilde (`/prof freunde`).
- `/prof vergessen` liest die Rezepte neu, wenn etwas falsch zugeordnet ist.

## Peon_Warhorn

Gruppensuche mit Filtern statt Blizzards Liste.

- `/warhorn` öffnet die Gruppensuche, `/warhorn suchen` sucht neu.
- **Filter** nach Rolle, Klasse und Stufe für Gruppen und Mitspieler.
- **Eintragen** und **Wer-Liste** als eigene Seiten. Rechtsklick auf einen Eintrag zum Anflüstern oder Einladen.
- **Flüstervorlagen** mit Platzhaltern unter Einstellungen.
- **Taste:** „Gruppensuche: Suchen“. Eine neue Suche startet nur auf Knopfdruck oder per Taste, das verlangt das Spiel.
- Mit dem Addon ForeverDungeonJournal übernimmt Warhorn den gesuchten Dungeon.

## Peon_Fishing

Angeln mit einem Klick und automatischem Ausrüstungswechsel.

- `/fp` öffnet die Einstellungen, `/fp toggle` schaltet den Angelmodus an oder aus.
- Im Angelmodus angelst du per Doppelklick oder mit der Angel-Taste (Auswerfen und Einholen auf einer Taste).
- Köder legt Peon Fishing selbst an, wenn du es einstellst. Ein Warnton meldet, wenn ein Fisch anbeißt.
- **Tasten:** „Angelmodus an/aus“, „Angeln (Auswerfen / Einholen)“, „Waffen anlegen (auch im Kampf)“.
- `/fp fische` zeigt deine Fänge je Gebiet, `/fp statistik` eine Übersicht.

## Peon_ClassBuddy

Kleine Helfer je Klasse.

- `/peon classbuddy` öffnet die Einstellungen.
- **Schurke:** runde Combo-Punkte über dem Namensschild des Gegners, Größe und Farben einstellbar.
- **Hexenmeister:** vernichtet überzählige Seelensplitter, wenn du einen Zauber wirkst. Dazu gibt es die Taste „Seelensplitter vernichten“ und das Makro `/click PeonClassBuddyShard`.

## Peon_Tooltip

Ein besserer Tooltip.

- `/ttp` öffnet die Einstellungen.
- Der Tooltip folgt der Maus. Größe, Deckkraft, Rahmenfarbe und das Verhalten im Kampf sind einstellbar.
- Im Gegenstands-Tooltip kannst du Teile ausblenden und anders sortieren.

## Peon_Panel

Eine Leiste oben am Bildschirm und ein verschiebbares Panel für die Symbole der Peon-Addons.

- `/peon panel` öffnet die Einstellungen.
- Rechtsklick auf die Leiste oder einen Eintrag öffnet das Menü: anzeigen, verschieben, Text oder nur Symbol.
- Dazu gibt es Einträge wie XP, Zone, Koordinaten, Uhr, Haltbarkeit, Freunde und Gilde.

## Peon_Mover

Fenster von Blizzard und Peon verschieben und in der Größe ändern.

- Fenster an der Titelleiste ziehen, um sie zu verschieben. Strg und Mausrad ändert die Größe. Umschalt und Rechtsklick auf die Titelleiste setzt Position und Größe zurück.
- `/peon mover` öffnet die Einstellungen, `/peon mover zuruecksetzen` setzt alle Fenster zurück.

## Peon_Feedback

Fehler und Ideen direkt im Spiel aufschreiben.

- `/feedback` öffnet das Fenster. Schreib auf, was dir auffällt, und wähle Addon und Art.
- Der Knopf **An Manager** übergibt die Einträge an den Peon Manager. Dort siehst du sie unter **Rückmeldungen** und sendest sie mit einem Klick.

## Peon_Bridge

Die Verbindung zwischen Spiel und Peon Manager. Sie wird mit dem Manager installiert und arbeitet unsichtbar.

- `/peon bridge status` zeigt, ob der Manager verbunden ist und wann er zuletzt Daten geschickt hat.

## Peon Manager

Das Programm für Windows installiert und aktualisiert die Addons.

- **Updates:** zeigt neue Versionen. Installiert wird nur, wenn du auf Aktualisieren klickst. Läuft WoW dabei, reicht danach `/reload`.
- **Rückmeldungen:** Fehler der Addons und deine Rückmeldungen ansehen, ergänzen und senden.
- **Einstellungen:** WoW-Ordner, Kanal Stabil oder Test, Aussehen, Größe der Oberfläche, Datensicherung.
- **Spieldaten sichern:** Der Manager sichert die Daten der Peon-Addons vor jedem Update und einmal am Tag. Unter Einstellungen holst du einen älteren Stand zurück, wenn WoW geschlossen ist.
- **Größe:** Strg und Plus oder Minus, Strg und Mausrad, Strg und 0 für 100 %.
- **Modul Peon Broker Client** (unter Updates einschaltbar): sammelt die Auktionsdaten von Broker, wertet sie aus und zeigt Übersicht, Marktübersicht, Chancen, Einkaufen und Beobachten.

## Peon unterstützen

Peon ist kostenlos. Wenn es dir beim Spielen hilft, freut sich KarloDerBaer über einen Kaffee: https://buymeacoffee.com/karloderbaer. Im Peon Manager geht das auch über **☕ Peon unterstützen** unten in der Seitenleiste.
