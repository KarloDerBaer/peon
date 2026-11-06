# Peon Manager (bisher Programm Peon Client): Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 0.17.1

Kurz: Der Hinweis zum Neustart von WoW entfällt: Nach einem Update reicht im Spiel immer `/reload`.

- 0.17.1 (07.11.2026, Hinweis KarloDerBaer): `/reload` hat bisher auch bei neuen Dateien und ganzen neuen Addons gereicht. Die Texte unter Updates und im Update-Fenster nennen deshalb keinen Neustart von WoW mehr.

## 0.17.0

Kurz: Seiten öffnen viel schneller, auch mit vielen Daten.
Kurz: Neu: Vor und Zurück wie im Browser, offene Gegenstände als Untertab unter dem Reiter, von dem du kommst.
Kurz: Neu: Favoriten mit Stern und eine Einkaufsliste, die sich mit dem Broker im Spiel abgleicht. Die Merkliste entfällt.
Kurz: Das Gegenstandsfenster ist neu aufgeteilt, die Eigenschaften stehen gleich unter dem Namen. Die genauen Werte auch von Gegenständen mit Zusatz holt der Manager aus dem Spiel, ganz ohne Scan.
Kurz: Märkte heißen jetzt einfach „PvE Allianz“. Die Kopfleiste sagt dir, wenn im Spiel ein /reload nötig ist.

- 0.17.0 (06.11.2026, Wunsch KarloDerBaer): **Navigation, Einkaufsliste, Favoriten, Ladezeiten.**
  - **Ladezeiten:** Gegenstand öffnen rechnet nur noch diesen Gegenstand statt alle. Die Gegenstandsliste wird einmal je neuem Stand gerechnet und in `list_cache` gemerkt, übliche Bereiche und Marktdaten ebenfalls einmal je Stand (`dataSig`, `bands`, `listOf`, `marketInfoCached`). Listen bleiben beim Seitenwechsel erhalten. Messung mit 5.000 Gegenständen und 14 Tagen stündlicher Stände (nur Abfragen, ohne Anzeige): Liste 6,2 Sek. auf unter 0,01 Sek., Gegenstand 5,4 Sek. auf 0,02 Sek., Übersicht und Chancen entsprechend. Die Rechnung läuft jetzt einmal je Stand beim Einlesen.
  - **Navigation:** Vor und Zurück (Knöpfe, Alt+Pfeil, Seitentasten der Maus), Verlauf merkt Seite, Gegenstand und Markt. Untertab je Reiter mit Stern und Schließen, der Link „Zurück zu …“ entfällt.
  - **Kopfleiste** auf allen Seiten: Pfeile, Hinweis auf wartende Eingaben, letzter Stand. „Jetzt einlesen“, die Schnellsuche mit Strg+K und der Eintrag im Infobereich entfallen, der Manager liest ohnehin von selbst ein. Der Manager prüft alle 30 Sek., ob WoW läuft (`noteGame`, `sync`), und erkennt daraus, ob das Spiel `Data.lua` gelesen hat.
  - **Märkte** (`src/core/markets.js`): Anzeige „PvE Allianz“, Auswahl in der Seitenleiste und nur ab zwei Märkten, gewählter Markt bleibt gemerkt. Der interne Name steht unter Quellen. Ein anderer interner Name für denselben Regelsatz, dieselbe Fraktion und Region ergibt keinen zweiten Markt mehr (`market_alias`, `aliases` in `Data.lua`).
  - **Gegenstandsfenster:** links die Eigenschaften, rechts Einschätzung in einem Satz, Kennzahlen, andere Märkte und Verlauf, darunter die Reiter Angebote jetzt, Wann günstig?, Absatz im Detail, Werte für Broker.
  - **Genaue Werte:** Tabelle `item_tip` als Datenbank der Eigenschaften, gefüllt aus dem Tooltip des Spiels. Die Blizzard-API liefert sie nicht (geprüft, siehe `Peon_Blizzard_API.md`). Der Manager bestellt über `tipWant` in `Data.lua`, was fehlt (`tipWants`, höchstens 1.000 je Laden, Favoriten und Einkaufslisten zuerst), und liest die Antworten aus `tipBox`. Kennt das Spiel etwas nicht, fragt er erst nach 7 Tagen wieder. Unter Quellen steht, wie viele bekannt und offen sind.
  - **Einkaufsliste** (`src/core/shopping.js`, Ansicht `Shopping.vue`): mehrere Listen, Rabatt je Liste, Menge und optionaler eigener Höchstpreis je Gegenstand, Vorrat aus Peon_Ledger, Treffer im letzten Stand, Meldung von Windows (`shopNotify`). Abgleich mit Broker je Eintrag nach der neueren Änderung. Ersetzt die **Merkliste**, sie wird ohne Übernahme entfernt (KarloDerBaer).
  - **Favoriten:** Tabelle `favorites`, gelten für alle Märkte, eigener Reiter, Stern auch in der Liste.
  - **Gegenstände:** Spalte „Zu üblich“, Spalten ein- und ausblendbar (`itemColumns`). **Übersicht:** Bereich „Jetzt kaufbar“. **Diagramm:** Legende überlappt die Achse nicht mehr.
  - Im echten Programm mit Testdaten durchgeklickt (Untertabs, Stern, Einkaufsliste, Vor und Zurück, Data.lua). Der Abgleich und die genauen Werte sind im Spiel noch zu prüfen.

## 0.16.0

Kurz: Die Reiter sind jetzt nach Modulen geordnet, der Broker hat seine eigene Gruppe.
Kurz: Die Übersicht zeigt die besten Chancen und was sich am meisten verkauft. Der Datenweg steht jetzt übersichtlich unter Quellen.
Kurz: Neu: Merkliste mit Preisalarm, Schnellsuche mit Strg+K und Datensicherung per Knopf.
Kurz: Der Reiter Module heißt jetzt Updates, dort stehen auch Kanal und Suche.

- 0.16.0 (06.11.2026, Wunsch KarloDerBaer): **Manager übersichtlicher.**
  - **Seitenleiste:** Je aktives Modul eine Gruppe mit Überschrift (`navTitle`, beim Broker Client „Broker“). Markt, Letzter Stand und „Jetzt einlesen“ stehen nur noch bei den Reitern des Brokers.
  - **Reiter Updates** (bisher Module): oben Kanal und „Nach Updates suchen“, darunter Module, darunter Addons. Der Hinweis „WoW läuft“ steht klein bei den Addons. Der Kanal zieht aus den Einstellungen hierher.
  - **Quellen:** Datenweg mit Lampe, Stand und wann die Daten kommen, Tabelle „Welche Daten wofür“, Auktionshäuser und Protokoll aufklappbar. Das Protokoll geht bei Fehlern von selbst auf und zeigt die letzten 40 Einträge. Offen sind die Auktionshäuser nur, wenn noch keines gewählt ist.
  - **Übersicht:** Statuszeile, Kennzahlen mit Änderung zu gestern, Beste Chancen jetzt, Meistverkauft, darunter wie bisher die Preisänderungen.
  - **Lampen:** Sie prüfen jetzt auch den Inhalt (`renderer\status.js`). Noch keine üblichen Bereiche ist gelb statt grün, „0 Momentaufnahmen“ heißt jetzt „Nichts wartet“.
  - **Marktdiagramm:** Titel nach dem echten Zeitraum, bei unter 3 Tagen mit Uhrzeit auf der Achse, sonst höchstens ein Datum je Tag.
  - **Preisänderungen:** Vergleich mit dem üblichen Preis, sobald es ihn für mindestens 20 Gegenstände gibt, ohne zu unruhige Gegenstände (`computeMoves`). Vorher wie bisher gegen den Stand davor, mit Hinweis. Einmal je Stand gerechnet.
  - **Einrichtungsliste** (`components\Checklist.vue`): unter Übersicht und Updates, bis alles erledigt oder ausgeblendet ist (`checklistHidden`).
  - **Merkliste** (`views\Watch.vue`, `core\watch.js`, Tabelle `watchlist`, Schema 6): Merken in der Detailansicht, Reiter im Broker. Grenze in Gold, Meldung von Windows einmal beim Erreichen und wieder, nachdem der Preis darüber lag. Abschaltbar (`watchNotify`). Ein Klick auf die Meldung öffnet den Gegenstand.
  - **Schnellsuche** (`components\QuickSearch.vue`): Strg+K oder Knopf in der Kopfzeile, Gegenstände und Seiten.
  - **Datensicherung** (`core\backup.js`): unter Einstellungen, Daten. Datenbanken und Einstellungen in einen Ordner, die Datenbanken laufen dabei weiter. Einspielen startet neu, der bisherige Stand bleibt in `vor-Wiederherstellung-<Datum>`. Der Zugang zur Blizzard-API ist nicht dabei.
  - Zurück aus der Detailansicht führt jetzt immer dorthin, woher man kam.
  - Geprüft im echten Programm mit Testordner und erfundenen Daten: Seitenleiste, Übersicht, Quellen, Updates, Schnellsuche, Merkliste samt Treffer. Sicherung und Einspielen über Tests. **Noch nicht geprüft:** Meldung von Windows in der installierten Fassung, Knöpfe der Sicherung mit dem Ordnerfenster, echte Daten auf den neuen Seiten.

## 0.15.1

Kurz: Im Kanal Test findet der Manager jetzt zuverlässig die neueste Vorabversion.

- 0.15.1 (06.11.2026, Rückmeldung KarloDerBaer): **Kanal Test fand die Vorabversion nicht.** Der Manager nahm den ersten Eintrag aus GitHubs Liste, dort stand aber `v2026.11.06` vor `v2026.11.06.2-test`. Jetzt zählt der Name (`newestTag`: Datum, Nummer des Tages, bei gleichem Stand das normale Release). Der Test hatte die Liste nur in der passenden Reihenfolge.

## 0.15.0

Kurz: Neues Fenster zeigt beim Start und vor dem Aktualisieren, was neu ist.
Kurz: Du stellst genauer ein, wie lange der Manager Daten aufhebt. Der neue Standard braucht viel weniger Platz.

- 0.15.0 (06.11.2026, Wunsch KarloDerBaer): **Aufbewahrung genauer einstellbar.**
  - **Einstellungen:** Vorlagen (Sparsam, Ausgewogen, Ausführlich, Alles) mit geschätzter Größe und zwei Regler für alle Angebote und für Stundenwerte. Der Balken zeigt, was wie viel Platz braucht. Erst „Übernehmen“ speichert. Eine Warnung erscheint nur, wenn dabei wirklich Daten zusammengefasst würden.
  - **Neuer Standard:** 14 Tage alle Angebote und 60 Tage Stundenwerte, vorher 30 und 365 Tage. Nach den Daten von KarloDerBaer sind das nach einem Jahr etwa 2,6 GB statt 12,7 GB. Die festen 365 Tage Stundenwerte werden einmalig bei allen auf 60 gestellt (`retentionV`), ein selbst gewählter Wert für alle Angebote bleibt.
  - **Untergrenze:** Stundenwerte bleiben mindestens 14 Tage, weil der übliche Bereich für Broker keine Tageswerte liest.
  - **Aufräumen im Hintergrund:** Verdichtet wird in Zeitscheiben von 6 Stunden, dazwischen arbeitet das Programm weiter. Index `item_hour_t`.
  - **Datei wird kleiner:** Die Datenbank gibt freien Platz jetzt schrittweise zurück (`auto_vacuum = INCREMENTAL`, wird beim ersten Öffnen umgestellt), auch wenn nur Stundenwerte wegfallen. Bis 0.14.0 schrumpfte sie in diesem Fall nicht.
  - **Schätzung:** Tageswerte zählen im ersten Jahr nur für die Tage nach den Stundenwerten, dazu steht der Zuwachs je weiteres Jahr. Der Text nennt „Stände“ (Scans und Blizzard-API) statt nur Scans.
  - Geprüft im echten Programm mit einem Testordner: Umstellung, Vorlagen, Regler, Warnung, Verwerfen, Übernehmen. **Noch nicht geprüft:** Lauf mit wirklich großen Datenmengen und in der installierten Fassung.
- **Update-Fenster** (Wunsch KarloDerBaer, `components\UpdateDialog.vue`): Manager, Addon-Updates und neue Addons mit kurzem Text, einzeln oder alles auf einmal.
  - **Wann:** beim Programmstart, je Stand einmal und abschaltbar (`updateWindow`), immer nach „Nach Updates suchen“ und über „Jetzt aktualisieren“ in der Seitenleiste. Die Suche alle 6 Stunden öffnet es nicht von selbst.
  - **Kurze Texte:** Zeilen `Kurz:` je Version im Changelog, das Manifest führt sie je Version (`news`), der Bau bricht ohne sie ab. „Was ist neu“ unter Module zeigt sie ebenfalls statt des Changelogs.
  - **Neue Addons** werden einmal vorgestellt (`addonsSeen`), „Alles aktualisieren“ fügt sie nicht ungefragt hinzu.

## 0.14.0

- 0.14.0 (06.11.2026, Wunsch KarloDerBaer): **Reiter „Rückmeldungen“ ersetzt „Debug“.** Der Manager ist jetzt der zentrale Ort für Fehler und Feedback (`src/core/reports.js`, Tabellen `errors` und `feedback`).
  - **Neue Rückmeldung** direkt im Manager, gleicher Aufbau wie Peon_Feedback (Modul, Art, Bereich, Priorität, Beschreibung), dazu das Modul „Peon Manager“. Bereiche kommen aus `PeonDB.feedbackAreas`.
  - **Bearbeiten und Löschen** aller Rückmeldungen, auch aus dem Spiel. **Fehler** bekommen ein Notizfeld und lassen sich einzeln löschen.
  - **Der Manager führt:** Eingelesenes löscht das Spiel beim nächsten Laden (`errorsClearBefore`, `feedbackClearBefore` in `Data.lua`). Gleiche Fehler zählen weiter hoch, die Notiz bleibt. Gelöschte oder gesendete Fehler kommen nur zurück, wenn sie neu auftreten.
  - **Senden:** Ein Issue je Eintrag, höchstens 20 je Senden, die ältesten zuerst. Gelöscht wird nur, was der Worker bestätigt. Namen und Pfade werden auch in selbst geschriebenen Texten ersetzt, die Vorschau zeigt genau das Gesendete.
  - **Entfernt:** Export als Text. Der Link „Feedback und Fehler melden“ führt in den neuen Reiter statt zu den öffentlichen Issues.
  - Tests: `test/reports.test.js`.

## 0.13.1

- 0.13.1 (06.11.2026): Adresse des Workers eingetragen, das Senden im Reiter Debug ist damit freigeschaltet. `PEON_MANAGER_REPORT_URL` leer schaltet es ab (für Tests).

## 0.13.0

- 0.13.0 (06.11.2026, Wunsch KarloDerBaer): **Reiter Debug mit Fehlerspeicher**, immer sichtbar, ein Zähler zeigt die Zahl der Fehler.
  - **Einlesen:** Abgefangene Fehler aus `Peon.lua` und die BugGrabber-Einträge, die ein Peon-Addon nennen (ohne `locals`), einmal je Minute und beim Öffnen. Konto- und Charakternamen, Spieler-Kennungen und Pfade werden dabei ersetzt.
  - **Weitergeben:** Export als lesbarer Text in die Zwischenablage, danach Frage, ob der Speicher geleert werden soll. Senden an KarloDerBaer über den Cloudflare Worker `worker/peon-fehler` (kein Konto, kein Token), mit Vorschau. Nach bestätigtem Senden wird automatisch geleert. Der Knopf bleibt gesperrt, bis die Adresse des Workers eingetragen ist.
  - **Leeren:** Im Manager sofort, im Spiel über `errorsClearBefore` in `Data.lua` beim nächsten Laden. Neuere Fehler bleiben auf beiden Seiten erhalten. Tests: `test/errors.test.js`.

## 0.12.0

- 0.12.0 (05.11.2026, Wunsch KarloDerBaer): **Gegenstands-Tooltip im Broker Client.**
  - **Anzeige:** Beim Überfahren einer Zeile unter „Gegenstände“ erscheint ein Tooltip wie im Spiel (Stufe, Bindung, Platz, Waffenschaden, Rüstung, Werte, Effekte, Voraussetzungen, Haltbarkeit, Set, Rezept, Händlerpreis). Die Detailansicht zeigt dasselbe unter „Eigenschaften“. Die Angabe der Quellen steht weiter an der Spalte „Quellen“, nicht mehr zusätzlich am Namen.
  - **Daten:** `/data/wow/item/{id}` der Blizzard-API (`src\core\item-info.js`), neue Tabelle `item_info` (Schema 5). Neue Gegenstände bringt der Einleser ohne Zusatzabfrage mit, alle anderen werden beim ersten Ansehen geholt. Einträge gelten 30 Tage, unbekannte Gegenstände werden 7 Tage nicht erneut abgefragt. Ohne Antwort oder Zugang bleibt ein vorhandener Eintrag gültig.
  - **Kennzeichnung:** Fehlt ein Gegenstand in `static-forever`, stammen die Werte aus den Classic-Daten und der Tooltip sagt das. Bei Gegenständen mit Zusatz steht dort, dass nur die Grundwerte bekannt sind. Ohne Zugang steht ein Hinweis auf die Einstellungen im Tooltip.
  - Geprüft im echten Programm mit einem Testordner und echten Abfragen an Blizzard. **Noch nicht geprüft:** Lauf in der installierten Fassung, Abgleich der Classic-Werte mit dem Spiel.

## 0.11.0

- 0.11.0 (05.11.2026, Wunsch KarloDerBaer): **Blizzard-API unter Einstellungen und mit den richtigen Wegen.**
  - **Einstellungen:** Zugang und Prüfung ziehen von Quellen nach Einstellungen und sind damit auch ohne Peon Broker Client erreichbar, weil andere Module die API ebenfalls nutzen können. Unter Quellen bleibt die Zeile mit dem Stand.
  - **Prüfabruf:** Forever hat keine Realms. 0.10.0 fragte Realm-Wege ab und meldete fälschlich „Blizzard kennt den Forever-Bereich nicht“. Jetzt geht er über Regelsatz und Auktionshaus und findet das erste Haus mit Angeboten.
  - **Baustein:** `blizzard.js` hat eine allgemeine Abfrage (`BlizzardClient`) für dynamische und statische Daten, mit erneuter Anmeldung und `If-Modified-Since`.
  - **Beobachter** (`blizzard-watch.js`), nur in der Testfassung mit `PEON_MANAGER_BLIZZARD_WATCH`: klärt Takt, Felder, Werte und Angebotsnummern (`docs\konzepte\manager\Peon_Blizzard_API.md`).
  - **Einleser** (`blizzard-import.js`): Unter Quellen lassen sich Auktionshäuser wählen, standardmäßig keines. „Vorschlag“ wählt sie aus Scans, Broker und Ledger. Ohne Zugang steht dort ein Link zu den Einstellungen. Abgefragt wird nur, wenn ein neuer Stand zu erwarten ist. Stände laufen wie Scans durch Verlauf, Chancen und die Werte für Broker, die Übersicht zeigt sie im Datenweg.
  - **Absatz:** Vergleicht API-Stände über die Angebotsnummern und erkennt so auch Teilkäufe. Eigene Scans zählen nur noch für Zeiten ohne API-Paar.
  - **Anleitung:** Fünf Schritte zum eigenen API-Zugang unter Einstellungen, geprüft an Blizzards Anleitung. Das Formular selbst liegt hinter der Anmeldung und ist ungeprüft.
  - **AHledger entfernt** (KarloDerBaer): Abruf, Zuordnung, Ansichten, Einstellungen. Die Tabellen `ext_fetch` und `ext_ahledger` werden beim Start gelöscht, Schema 4. Neue Tabelle `variant_names`.
  - Im echten Programm gegen das echte Blizzard geprüft (EU, Testfassung): Prüfabruf meldet Daten, Beobachter holt alle 15 Häuser und vergleicht zwei Stände, Vorschlag findet Haus 111 über den Scan, Abruf liest 47.266 Angebote ein.

## 0.10.0

- 0.10.0 (04.11.2026, Wunsch KarloDerBaer): **Prüfabruf für die Blizzard-API** unter Quellen (`src\core\blizzard.js`, Ansicht `components\BlizzardCheck.vue`). Er prüft, ob `dynamic-forever-{region}` Auktionsdaten liefert, zeigt je Stufe den Antwort-Code und liest nichts ein. Jeder trägt einen eigenen Zugang von develop.battle.net ein, er liegt nur verschlüsselt im Datenordner und wird nur an Blizzard geschickt. Mit nachgebautem Blizzard geprüft, **gegen das echte Blizzard noch nicht**.

## 0.9.3

- 0.9.3 (04.11.2026, Wunsch KarloDerBaer): Seitenleiste: Module und Einstellungen stehen jetzt unten, darüber ein Querbalken, wenn der Peon Broker Client installiert ist. Dabei behoben: Bei langen Seiten scrollte das ganze Fenster und die Leiste wurde mitgezogen, jetzt scrollt nur der Inhalt.

## 0.9.2

- 0.9.2 (04.11.2026): Ansicht Module: Bei Addons ohne Eintrag im Release stand doppelt „Installiert · installiert 0.2.0“, jetzt „Installiert 0.2.0“.

## 0.9.1

- 0.9.1 (04.11.2026, Fehler beim Umzug gefunden): Der Manager merkte sich nur, was er zuletzt in Data.lua geschrieben hatte, und prüfte die Datei nicht. Stand dort etwas anderes (Datei ohne Kanäle, Platzhalter einer neu installierten Bridge, gelöscht oder kaputt), blieb das so, und die Bridge zeichnete nichts auf, obwohl der Broker Client aktiv war. Jetzt vergleicht er beim Einlesen Format und Kanäle mit der Datei und schreibt sie bei Abweichung neu. Test in `test\modules.test.js`.

## 0.9.0

- 0.9.0 (04.11.2026, Design `Peon_GitHub_Design.md` 5.6 und 6.3, Schritt I): **Installer und Selbst-Update.**
  - **Installer** (NSIS) für den Benutzer, ohne Administratorrechte. Programm jetzt mit eigenem Symbol und Angaben in der exe.
  - **Selbst-Update** mit electron-updater: Nennt das Manifest eine neuere Version, lädt der Manager sie im Hintergrund (nur geänderte Teile, wenn möglich) und zeigt unter Module „Jetzt neu starten“. Beim Beenden wird nichts ungefragt eingespielt.
  - Quelle ist der Ordner des Release aus dem Manifest, weil der GitHub-Weg von electron-updater unsere Tags vJJJJ.MM.TT nicht als Versionen annimmt.
  - **Datenordner:** Installiert liegen die Daten in `%APPDATA%\Peon Manager\Daten`. Liegt `DB` neben dem Programmordner, gilt weiter dieser Ordner, und es gibt kein Selbst-Update.
  - `release.yml`: Tag `v*` führt Tests aus, baut Zips, Manifest und Installer und veröffentlicht. Von Hand gestartet ist es ein Probelauf ohne Veröffentlichung. Die Blockmap des letzten Installers kommt mit ins neue Release, damit schon das erste Update nur Teile lädt.
  - README mit Installation des Managers und Hinweis auf SmartScreen.

## 0.8.0

- 0.8.0 (04.11.2026, Design `Peon_GitHub_Design.md` 5.3 bis 5.5, Schritt H): **Addons installieren und aktualisieren.**
  - **Ansicht „Module“:** Gruppe Addons mit Status, installierter und verfügbarer Version, „Was ist neu“, Knöpfen Installieren, Aktualisieren und Entfernen, dazu „Nach Updates suchen“ und „Alle aktualisieren“. In der Seitenleiste zeigt eine Zahl, wie viele Updates bereitliegen.
  - **Ablauf je Addon:** Zip laden, Größe und SHA-256 gegen das Manifest prüfen, in einen Zwischenordner entpacken, Inhalt prüfen, alten Ordner nach `backup\<Addon>-<Version>` verschieben, neuen an seine Stelle, jede Datei prüfen. Bei einem Fehler kommt die alte Fassung zurück.
  - **Schutz:** Manifest und Zip kommen aus dem Netz. Namen, Dateien und Tags werden geprüft, Pfade außerhalb des Addon-Ordners im Zip werden abgewiesen, Größen sind begrenzt. Fremde Addons und WTF werden nie angefasst. Ein `Data.lua` im Zip der Bridge wird nicht übernommen, die vorhandene bleibt erhalten, sonst legt der Manager den Platzhalter an.
  - **Abhängigkeiten:** Peon und Peon_Bridge kommen automatisch mit. „Installieren“ eines Manager-Moduls holt seine fehlenden Addons. Entfernen ist gesperrt, solange etwas das Addon braucht. Es verschiebt den Ordner in die Sicherung, die Einstellungen in WTF bleiben.
  - **Entwicklermodus:** Ist ein Addon-Ordner eine Junction, zeigt der Manager „Entwicklung (Repo)“ und ändert nichts.
  - **Suchen:** beim Start und alle 6 Stunden, installiert wird nur per Klick (KarloDerBaer). Kanal Stabil über `releases/latest/download/manifest.json`, Kanal Test über die Liste der Releases mit ETag und Zwischenspeicher. Ohne Release sagt der Manager das und vergisst ein altes Manifest. Ist der Manager zu alt für ein Release (`minVersion`), installiert er nichts und sagt warum.
  - **WoW läuft:** Warnung über den Programmnamen `Wow.exe`. Aktualisieren geht trotzdem, neue Dateien brauchen dann einen Neustart von WoW.
  - **Erster Start:** Vorschlag mit allen Addons außer dem Broker Client, der als Angebot dabeisteht. WoW-Ordner aus der Windows-Registrierung und an üblichen Orten suchen, sonst fragen. Der Vorschlag entfällt, sobald Peon da ist oder man „Später“ wählt.
  - **Feedback:** Link zu den Issues im Repo, ein Discord-Link aus dem Manifest hätte Vorrang.
  - **Einstellungen mit BOM-Markierung** (zum Beispiel aus Notepad) gelten jetzt. Vorher wurden sie still verworfen.
  - Zip-Code in `src\core\zip.js`, auch für `scripts\build_release.js`. `minVersion` im Manifest ist 0.8.0, weil ältere Manager kein Manifest lesen.
  - Tests: neue `test\addons.test.js` gegen einen lokalen Server mit den Pfaden von GitHub (Installieren, Aktualisieren, Prüfsumme, manipulierte Zips, Zurücktauschen, Junctions, Entfernen, Kanäle, erster Start).

## 0.7.0

- 0.7.0 (31.10.2026, Design `Peon_GitHub_Design.md` 5.2, Schritt G): **Manager-Module.**
  - Liste der Module in `src\core\modules.js` (Schlüssel, Name, Beschreibung, nötige Addons, Kanäle, Ansichten, Datenbankdatei). Erstes Modul **Peon Broker Client** (`broker-client`): alle bisherigen Funktionen, jetzt als eigene Datei `src\core\broker-client.js`. `service.js` ist nur noch der Manager (Einstellungen, Module, Kanäle für Data.lua).
  - **Eigene Datenbank je Modul** (KarloDerBaer): `broker-client.db` für den Broker Client, `peon.db` nur noch für Zustand und Protokoll des Managers. Wer schon Daten hatte, bekommt die alte `peon.db` beim ersten Start einmalig als `broker-client.db` (samt -wal, -shm), der Broker Client bleibt dann aktiv. Neue Nutzer starten ohne Modul.
  - **Installieren / Entfernen:** schaltet das Modul ein oder aus, mit Eintrag im Protokoll. Entfernen schließt die Datenbank, die Daten bleiben liegen. „Daten löschen“ (mit Rückfrage) löscht die Datei, nur wenn das Modul aus ist.
  - **Kanäle je Modul:** Data.lua bekommt `channels` aus den aktiven Modulen. Ohne aktives Modul schreibt der Manager einmal `channels = {}` (die Bridge zeichnet dann nichts auf), ohne Peon_Bridge nichts.
  - **Hintergrund nur mit Modul:** Dateiwächter, Abfrage jede Minute, AHledger, Aufräumen und Tageswechsel laufen nur mit aktivem Broker Client. Das Menü im Infobereich zeigt „Jetzt einlesen“ und „AHledger abrufen“ nur dann.
  - **Oberfläche:** neue Ansicht „Module“ (Manager-Module mit Beschreibung, nötigen Addons und ob sie im AddOns-Ordner liegen). Übersicht, Gegenstände, Chancen, Quellen, Kopfzeile mit „Jetzt einlesen“ und die Einstellungen AHledger und Aufbewahrung nur mit aktivem Broker Client. Ohne Modul startet der Manager in „Module“.
  - Tests: neue `test\modules.test.js` (Liste gleich wie im Release-Manifest, frisch ohne Modul, ohne Bridge, Umzug, alte Einstellungen, Installieren, Entfernen, Daten löschen, wieder installieren). Die bisherigen Tests nutzen `svc.broker`. Selbsttest frisch und mit einer Kopie der echten Daten.

## 0.6.0

- 0.6.0 (31.10.2026, Design `Peon_GitHub_Design.md` Abschnitt 5.1): **Programm heißt Peon Manager.** Paket `peon-manager`, Name „Peon Manager“, `appId` `de.peon.manager`, Programm `PeonManager.exe`, Fenster und Infobereich „Peon Manager“. Quellcode in `manager\` (bisher `client\`).
  - Liest `Peon_Bridge.lua` (`PeonBridgeDB`) statt `Peon_Client.lua`, schreibt `AddOns\Peon_Bridge\Data.lua` im **Format 2**: `fmt = 2`, `manager = Version` (bisher `client`), `channels = { broker = true }`. Solange es noch keine Manager-Module gibt, ist der Kanal broker immer freigeschaltet.
  - Umgebungsvariablen `PEON_MANAGER_DB` und `PEON_MANAGER_SELFTEST` (bisher `PEON_CLIENT_…`). Texte der Oberfläche sagen „Manager“ statt „Client“.
  - Ort bei KarloDerBaer: `<Programmordner>\Runtime`, Daten `<Programmordner>\DB` (KarloDerBaer, 31.10.2026). Der alte Ordner `<alter Programmordner>` bleibt als Sicherung.
  - Tests: Format 2 geprüft. Der Vergleich mit Brokers Sales.lua (3000 Zufallsfälle) läuft jetzt auch unter Windows mit `tools\lua5.1.exe` aus dem Repo (bisher übersprungen), 0 Abweichungen.

## 0.5.0

- 0.5.0 (25.10.2026, Rest aus dem Design, KarloDerBaer: „0.4 läuft, also baue 0.5.0“):
  - **Gegenstände:** Spalten „Üblicher Bereich“ (Unter- bis Obergrenze wie für Broker) und „Quellen“ (S eigene Scans, L Live-Abfragen, B Broker-Verlauf, Einzelheiten beim Darüberfahren), Filter nach Warenart (Massenware, Einzelgegenstände). Sortierbar wie alle Spalten.
  - **Gegenstand:** im Preisdiagramm der übliche Bereich je Tag als gestrichelte Treppe (der Stand, den Broker an dem Tag bekommen hätte), im Stück-Diagramm der Absatz je Tag mit eigener Skala rechts.
  - **Protokoll als Datei:** zusätzlich je Tag `<alter Programmordner>\DB\logs\JJJJ-MM-TT.log`, älter als 30 Tage wird beim Verdichten gelöscht.
  - Standard-Ordner für WoW ist `_forever_`.
  - Nicht gemacht: englische Texte (alle Ansichten, eigener Schritt, wenn gewünscht) und Filter nach Art des Gegenstands (dafür fehlt die Art, müsste Peon_Client mitliefern).
  - Tests: zusammen 23. Bildschirmfotos geprüft. Eingespielt wie zuvor (app.asar und 60 Bytes der exe), Prüfsummen gleich dem Bau, alte Version als `Runtime_0.4.0`.

## 0.4.0

- 0.4.0 (23.10.2026, C6 Chancen, Rechenmodell Kapitel 9, abgestimmt mit KarloDerBaer: Client rechnet Absatz und gibt ihn an Broker, Händlerpreis von Peon_Client, alle vier Reiter):
  - **Absatz:** vergleicht aufeinanderfolgende Komplettscans (1 Min. bis 24 Std.) mit allen Angeboten nach Brokers Regeln (gleich wie `Sales.lua`, geprüft mit 3.000 Zufallsfällen gegen den echten Lua-Code). Live-Abfragen mit Auktionsnummern nur für Zeiten ohne Scan-Paar. Scan dazwischen ersetzt das alte Paar. Nach 2 Tagen zu Tageswerten zusammengefasst, Tageswerte 1 Jahr. Absatz je Tag, Quote, Sicherheit wie Broker (60/180 Min.). Warenart von Broker (`commodity`, später über Peon_Client), sonst Massenware, sobald ein Angebot mehr als 1 Stück hatte.
  - **Data.lua:** zusätzlich `markets[…].sales[Schlüssel] = "ABSATZ×10:QUOTE:MINUTEN"`.
  - **Ansicht Chancen** mit Reitern Wiederverkauf (unter der Untergrenze, mindestens 20 % Gewinn nach Gebühr, Gewinn je Tag begrenzt durch Absatz, „zweifelhaft“ wenn nie nahe der Untergrenze verkauft), Händler (unter dem Händlerpreis), Fallend, Steigend (mindestens 15 % vom Langzeitwert und außerhalb des Bereichs, Dumping, 14-Tage-Linie), Lohnend (Absatz × Spanne). Zeitraum 1/3/7/14 Tage, Mindestgewinn je Tag (Standard 10 Silber), Qualität, Suche, Sortierung, 50 Zeilen und mehr auf Klick. Klick öffnet den Gegenstand, zurück zu Chancen.
  - Gegenstände: Spalte Absatz. Gegenstand: Absatz mit Einzelheiten, Händlerpreis und Warenart. Übersicht: Station Broker mit Zahl für Bereich und Absatz.
  - Tests: zusammen 22 (neu `c6.test.js`). Mit KarloDerBaers echter Datenbank: Umstellung auf Schema 3 klappt, 1 Scan-Paar (16,5 Std.), Absatz für 3.061 Gegenstände, meist „abgelaufen“ wegen des großen Abstands. Chancen leer, weil erst 2 Tage Daten (Bereich braucht 3).
  - Eingespielt wie 0.3.0 (app.asar und 57 Bytes der exe), Prüfsummen gleich dem Bau. Alte Version als `Runtime_0.3.0`.
  - **Erledigt 25.10.:** Mit dem Umzug nach `_forever_` sind alle Dateien von Broker 0.32.0 drin, alle 14 Tests OK. Vorher: Windows verweigerte am 23.10. um 14:06 das Schreiben von 6 Broker-Dateien und der TOC (`Broker.lua`, `Data.lua`, `Locales.lua`, `Prices.lua`, `Sell.lua`, `Tooltip.lua`, `Peon_Broker.toc`), vermutlich weil sie geöffnet sind (Spiel oder Editor) oder der Ordnerschutz greift. Nachholen, dann `run_tests.sh` (test_client braucht Broker 0.32).

## 0.3.0

- 0.3.0 (23.10.2026, C4 Rückgabe an Broker, Rechenmodell Kapitel 8):
  - **Langzeit-Teil für Broker (F42):** je Markt und Gegenstand MITTE (Median der Tageswerte), SCHW (1,4826 × MAD ÷ MITTE, mindestens 5 %) und LANG (gewichtetes Mittel, Halbwertszeit 3 Tage, Werte auf MITTE × (1 ± 3 × SCHW) begrenzt) aus den letzten 14 Tagen, ab 3 Tagen. Tageswert = Mittel der Mediane aller eigenen Komplettscans des Tages (auch aus Stundenwerten), sonst Brokers Tagesmittel. Gleiche Formeln wie Broker: mit KarloDerBaers Daten für alle 2.275 Gegenstände gleich wie Brokers eigene Rechnung.
  - **Data.lua** enthält jetzt `markets["Realm / Fraktion"] = { t, day, items = { [Schlüssel] = "MITTE:SCHW:LANG:TAGE:Quelle" } }` (Kupfer, SCHW in Zehntausendsteln, Quelle e = eigene Scans, b = Broker-Verlauf). Neu geschrieben, wenn sich Bestätigung oder Werte ändern; einmal pro Stunde wird geprüft, ob ein neuer Tag begonnen hat.
  - Gegenstand: Kasten „Üblicher Bereich für Broker“ (Langzeitwert, Bereich, Schwankung, Tage, Quelle). Übersicht, Station Broker: Zahl der Gegenstände und Größe der Data.lua.
  - Tests: zusammen 17 (neu: Leinenstoff-Beispiel, Data.lua mit Werten, eigene Tage vor Broker-Tagen, neues Schreiben beim Tageswechsel). Bildschirmfotos geprüft.
  - Eingespielt nur mit den geänderten Teilen (app.asar und 58 Bytes der exe), Prüfsummen aller Dateien gleich dem Bau. Alte Version als `<alter Programmordner>\Runtime_0.2.0` (kann gelöscht werden, ebenso `Runtime_0.1.0`).

## 0.2.0

- 0.2.0 (22.10.2026, Broker-Verlauf und C3, von KarloDerBaer 0.1.0 unter Windows getestet: „läuft gut und gefällt mir“):
  - **Broker-Verlauf als eigene Quelle:** liest `Peon_Broker.lua` aller Konten (nur wenn geändert, auch über den Dateiwächter), Tageswerte (Summen ÷ Anzahl Scans = Tagesmittel) und Wochenmittel je Gegenstand in Tabelle `hist`, Namen und Qualität dazu (Namen aus eigenen Scans haben Vorrang). Je Einlesen werden die Werte eines Markts ersetzt (Broker verdichtet selbst). Tag wie Broker (lokale Mittagszeit ÷ 86400). Gibt es für einen Tag eigene Scans, gilt der Broker-Wert dieses Tages nicht. KarloDerBaers Daten: 4.481 Gegenstände, Tage 30.09. bis 03.10. und 22.10.
  - **Gegenstände:** alle Gegenstände des Markts (eigene Scans und Broker-Verlauf) mit Min, Median, Menge, Angebote, Ø 7 Tage (Mittel der Tagesmediane), Trend (Median gegen Ø 7 Tage, ab 2 Tagen), zuletzt gesehen; Suche nach Name oder Nummer (Groß/klein und Umlaute egal), Qualität ab, „nur im letzten Scan“, Sortierung per Spaltenkopf (Standard Angebote, leere Werte unten), Geldbeträge kurz (ab 100g nur Gold), nur sichtbare Zeilen werden gezeichnet. Nicht im letzten Scan = blass mit „weg“.
  - **Gegenstand:** Min/Median jetzt (letzter Scan oder neuere Live-Abfrage), Menge, Angebote, Ø 7 Tage, Spanne 14 Tage (tiefster/höchster Tagesmedian); Verlauf 24 Std./7/30/90 Tage/Alles mit Preis je Stück (Median, Min, mittlere Hälfte als Band, Live-Min, Broker-Tagesmittel gestrichelt) und Stück (Menge, Broker-Menge), gemeinsame Mauslinie; **„Wann ist es günstig?“** (Median gegen das Mittel aller Scans der letzten 60 Tage je Wochentag und 3-Stunden-Abschnitt, ab 10 Scans); **Angebot im letzten Scan** (Treppe Stück bis Preis, ohne Ausreißer über dem Dreifachen des mittleren Stücks, Tabelle der günstigsten 10 Preisstufen). Klick in der Übersicht (Preisänderungen) und in der Liste öffnet den Gegenstand.
  - **Aufbewahrung:** Schieber 7 bis 365 Tage oder unbegrenzt (Standard 30) für vollständige Momentaufnahmen; danach Stundenwerte 365 Tage (`item_hour`), dann Tageswerte (`item_day`), Kopfdaten der Scans bleiben. Anzeige jetzt und geschätzt nach einem Jahr (vollständig, Stunden, Tage), gerechnet mit Scans je Tag und Platz je Zeile aus den eigenen Daten (Testdaten: etwa 650 KB je Scan). Verdichten beim Start, einmal am Tag und nach Änderung.
  - Quellen: Zeile „Broker-Verlauf“; Übersicht: Tage des Broker-Verlaufs bei der Station Client.
  - Rechtschreibprüfung aus: Electron lädt sonst Wörterbücher aus dem Netz.
  - Tests: `client\test\c3.test.js` (6 Tests: Broker-Tag, Einlesen/Ersetzen/Namen/kaputte Datei, Liste, Gegenstand mit Vorrang eigener Tage, Muster, Preisstufen, Zeiträume, Verdichten und gewichtetes Zusammenführen, Schätzung, echte Daten), zusammen 15 Tests OK; echtes Electron mit echten Daten (4.481 Gegenstände über die Befehlsliste); Bildschirmfotos aller Ansichten.
  - Bilder der Gegenstände entfallen bis zum Release (kämen von einer externen Quelle).
  - Einspielen: neuer Ordner neben `Runtime`, dann getauscht; die alte Version liegt als `<alter Programmordner>\Runtime_0.1.0` daneben (kann gelöscht werden), dazu ein leerer Ordner `_neu`.

## 0.1.0


- Design: `Peon_Client_Design.md`, Bauabschnitt C2 (22.10.2026). Quellcode `client\` im Projektordner (Anleitung `client\README.md`), Programm `<alter Programmordner>\Runtime\PeonClient.exe`, Daten `<alter Programmordner>\DB\` (`peon.db`, `settings.json`).
- Technik: Electron 44.9.3 (Node 24, SQLite eingebaut über `node:sqlite`), Vue 3.5, Vite 8, ECharts 6, Schrift Barlow / Barlow Semi Condensed (im Programm enthalten, nichts aus dem Netz). Nur Deutsch und Englisch als Sprachdateien, Programmordner etwa 320 MB.
- Sicherheit: Oberfläche ohne Node-Zugriff (`contextIsolation`, `sandbox`), feste Befehlsliste (`preload.js`), keine fremden Seiten, Links nur zu ahledger.com, Netz nur im Hauptteil.
- **Einlesen aus dem Spiel:** sucht `Peon_Client.lua` in allen Konten unter WTF, liest sie ohne etwas auszuführen (eigener Lua-Leser, Umlaute und `\ddd` richtig), übernimmt jede Momentaufnahme genau einmal (über ihre id), je Gegenstand Min, Median je Stück, Viertel, Menge, Angebote (wie Broker). Angebote einer Momentaufnahme gepackt (zlib) gespeichert, Kennzahlen in `item_snap`, Namen und Qualität in `items`. Teil-Ergebnisse von Live-Abfragen: nur Min. Fehlerhafte Einträge werden übersprungen und protokolliert.
- **Rückgabe:** schreibt `AddOns\Peon_Client\Data.lua` mit `ack` (alles, was sicher in der Datenbank ist) und leeren `markets` (Preisbereiche folgen in C4); neue Datei, dann ersetzen. Nur neu geschrieben, wenn sich die Bestätigung ändert. Im echten Lua 5.1 geprüft.
- **Dateiwächter:** Änderung an `Peon_Client.lua` → Einlesen, sobald die Datei 2 Sek. gleich bleibt; dazu jede Minute nachsehen.
- **AHledger:** Preistabelle des zugeordneten Markts alle 30 Min. (15/30/60, abschaltbar), ETag und gleicher Stand werden nicht doppelt gespeichert (`ext_fetch`, `ext_ahledger`). Neuer Markt bekommt einen Vorschlag (Beta: `forever.normal.alliance.us`), der schon abgerufen wird, damit Daten für die Quellenprüfung (C5) entstehen; Bestätigung unter Quellen. Nur Anzeige, nie eingerechnet.
- **Oberfläche** (dunkel, Peon-Grün, hell umschaltbar): Übersicht mit Datenweg Spiel → Client → Broker und AHledger (Lampe aktuell/älter/keine Daten/Fehler), Markt der letzten 30 Tage (Angebote und Gegenstände je Scan), größte Preisänderungen (Median letzter Scan gegen etwa einen Tag vorher, ab 1 Silber und 3 Stück), Protokoll. Quellen (Art, Verwendung, Stand, Zuordnung zu AHledger mit Bestätigen). Einstellungen (WoW-Ordner, AHledger, mit Windows starten, Aussehen, Datenordner). Gegenstände und Chancen als „folgt“.
- **Betrieb:** Symbol im Infobereich (Fenster öffnen, Jetzt einlesen, AHledger abrufen, Beenden), Fenster schließen = weiterlaufen, nur ein Client gleichzeitig, mit Windows starten (Standard aus, startet unsichtbar).
- Tests: `client\test\core.test.js` (9 Tests: Lua-Leser, Rückweg, Kennzahlen wie Broker, AHledger-Tabelle, Einstellungen, Einlesen/Bestätigung/kein Doppel, Fehlerfälle, AHledger mit ETag und Fehler, echte WTF-Datei). Echte Datei vom 22.10.: 2.773 Gegenstände wie Broker, unter 0,1 Sek., Datenbank etwa 1 MB je Scan. Echtes Electron unter Linux gestartet (Fenster, Einlesen, Data.lua, Dateiwächter). Bildschirmfotos dunkel/hell, Quellen, Einstellungen, leer.
- Übertragen: Paket in Stücken zu 15 MB (größere lehnt die Übertragung ab), auf dem PC zusammengesetzt und je Datei geprüft (19 Dateien Programm, 28 Dateien Quellcode).
- **Nächster Schritt:** KarloDerBaer startet `PeonClient.exe`, prüft die Übersicht, bestätigt unter Quellen die Zuordnung zu AHledger und lässt den Client laufen (AHledger wird gesammelt). Dann C5 (Quellenprüfung) vor dem Start von Forever.
