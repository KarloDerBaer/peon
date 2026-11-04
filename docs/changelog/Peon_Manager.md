# Peon Manager (bisher Programm Peon Client): Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

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
