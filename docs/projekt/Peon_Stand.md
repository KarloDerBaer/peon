# Peon: Stand je Modul

Stand: 08.11.2026, **umgezogen ins Git-Repo** (Addon-Code in `addons\`), nach Peon 0.15.0 / Broker 0.39.0 / Bridge 0.7.0 (bis 0.3.0 Peon_Client) / Peon Manager 0.22.0 (bis 0.5.0 Programm Peon Client) / Ledger 0.13.1 / Fishing 1.6.0 / Tooltip 0.7.5 / ComboPoints 3.5.1 / Mover 0.1.0 / Bags 0.6.0 / Feedback 0.4.0 / Panel 0.4.0.
Je Modul stehen hier nur Version, Dateien, Einstellungen, Befehle und was noch zu prüfen ist. Der Verlauf der Versionen steht in `docs\changelog\<Modul>.md` (neueste oben). Bei jeder Änderung an einem Modul diesen Abschnitt und den Changelog aktualisieren.

## Peon (Kern) – 0.15.0, API 15

- Dateien: Locales.lua, Core.lua, Feedback.lua (ab 0.9, direkt nach Core.lua), Module.lua, Options.lua, Widgets.lua, List.lua, Launcher.lua (ab 0.14), Minimap.lua, Chart.lua (ab 0.10), Slash.lua
- SavedVariables: `PeonDB`: `errors` (Fehlerspeicher ab 0.12.0: `addon`, `where`, `msg`, `version`, `build`, `first`, `last`, `n`, höchstens 100), `feedbackAreas` (Bereiche je Modul für den Manager, ab 0.13.0), `panelHid` (von Peon_Panel ausgeblendete Minimap-Buttons, ab 0.14.0)
- Fehlerspeicher (API 12): `Peon.RecordError`, `Peon.ClearErrors`, `Peon.ReportCoreError`, `mod:ReportError` speichert automatisch. Befehle `/peon fehler`, `/peon fehler leeren`.
- Aufgaben: globales Objekt `Peon`, Modulverwaltung (`Peon:NewModule`), Einstellungen mit Standardwerten/Bereichen/erlaubten Werten, Übernahme alter Variablennamen (`oldDB`/`oldCharDB`), Ereignisse (INIT, LOGIN, COMBAT_START, COMBAT_END, RESET, CHANGED), Debug-Log, Einstellungsseite „Peon“ mit Modulübersicht, Optionsseite mit Bildlauf und Bausteinen (Header, Slider, Check mit Hinweis/eigenen Werten, Dropdown, Choice, PositionGrid, Color, Button, Text, Reset-Knopf, mitwachsende Anordnung), `keepOnReset`, `/peon`.
- Noch nicht im Kern: `RegisterUnitEvent`.
- Verlauf der Versionen: `docs/changelog/Peon.md`
- Hinweise „Im Spiel prüfen“ im Verlauf bei: 0.14.0, 0.13.0, 0.12.0, 0.11.1, 0.10.0 (zusammen mit der Prüfliste erster Spieltag unter „Offene Punkte“ durchgehen)

## Peon_Tooltip – 0.7.5 (früher TooltipPlus)

- Dateien: Locales.lua, Tooltip.lua, Style.lua, Units.lua, Icons.lua, Items.lua (ab 0.6), Debug.lua, Options.lua
- SavedVariables: `PeonTooltipDB`
- Befehle: `/ttp` (Optionen), `/ttp reset`, `/ttp debug` (Einheit unter der Maus untersuchen), `/ttp teile` (nächsten Gegenstands-Tooltip im Chat in Teile aufschlüsseln, ab 0.6), `/ttp log` bzw. `/peon debug tooltip` (Debug-Log)
- Funktionen: Tooltip folgt der Maus (Ecke, Abstand X/Y, Kantenwechsel), Größe, Hintergrund-Deckkraft, Rahmenfarbe (keine/Haltung/Klasse), Spielerinfos (Name in Klassenfarbe, Gilde), eigenes Ausblenden, Kampfmodus (normal/durchsichtig/aus, Umschalt zeigt), PvP- und Quest-Symbol mit Position und Größe.
- Optionsseite: Kern-Bausteine (braucht Peon API 6). Position der Tooltips und Symbole als Knopfraster, Rahmenfarbe und Kampfmodus als Auswahllisten.
- Verlauf der Versionen: `docs/changelog/Peon_Tooltip.md`
- Hinweise „Im Spiel prüfen“ im Verlauf bei: 0.7.5, 0.7.4, 0.7.3, 0.7.2, 0.7.1, 0.7.0, 0.6.0 (zusammen mit der Prüfliste erster Spieltag unter „Offene Punkte“ durchgehen)

## Peon_ComboPoints – 3.5.1 (früher Combo Point Display)

- Dateien: ComboPoints.lua, Options.lua
- SavedVariables: `PeonComboPointsDB`
- Befehle: `/peon combopoints` (Optionen), `/peon debug combopoints`
- Funktionen: runde Combo-Punkte im Blizzard-Stil über dem Nameplate des Gegners, nur für Schurken aktiv. Einstellbar: Größe, Abstand, Höhe, Randdicke, leere Fassungen, Farben (Füllung, Fassung, Rand).
- Technik: geheime Werte über StatusBars (`SetMinMaxValues(i-1, i)`), Träger über den Nameplate-Rahmen; eigener Ereignisrahmen wegen `RegisterUnitEvent`.
- Optionsseite: Kern-Bausteine, mit Vorschau.
- Verlauf der Versionen: `docs/changelog/Peon_ComboPoints.md`

## Peon_Fishing – 1.6.0 (früher FishingPlus)

- Dateien: Locales.lua, Fishing.lua, Sets.lua, Click.lua, Lure.lua, Keys.lua, Combat.lua, Sound.lua, Minimap.lua, Catches.lua, Options.lua, Bindings.xml
- SavedVariables: `PeonFishingDB` (accountweit), `PeonFishingCharDB` (pro Charakter, z. B. Mirel-Dorna); `dbVersion` = 3
- Befehle: `/fp` (Optionen), `/fp toggle|an|aus`, `/fp set <Name>`, `/fp saveset`, `/fp kampf fragen|verlassen|bleiben`, `/fp waffenversuch`, `/fp klick doppel|aus`, `/fp status`, `/fp minimap`, `/fp koeder`, `/fp fische`, `/fp statistik`, `/fp debug`
- Tastenbelegungen: `PEON_FISHING_TOGGLE`, `PEON_FISHING_ACTION`, `CLICK PeonFishingWeaponButton:LeftButton` (Umzug von FISHINGPLUS_* abgeschlossen, keine versteckten Alteinträge mehr)
- Funktionen: Angelmodus mit Ausrüstungswechsel (Angel-Set / Rückkehr-Set, im Kampf vorgemerkt), Angeln per Doppelklick oder Angel-Taste (Auswerfen/Einholen), Köder automatisch/fest/aus und Erneuerung, Kampfverhalten (bleiben/fragen/verlassen, Waffen per sicherem Makro-Button), Ton-Anpassung beim Angeln, Schwimmer-Erkennung über Soft Targeting mit Warnton, Minimap-Button, Fangdatenbank mit Übersicht je Zone.
- Optionsseite (Kern-Bausteine, braucht Peon API 6): links Ausrüstung (Angel-Set als Auswahlliste ohne Rückkehr-Set), Steuerung, Schwimmer-Erkennung (Reichweite, Markierung, neu auswerfen, Warnton mit Hörprobe), Fänge; rechts Ton beim Angeln (ausgegraut ohne Tonmix), Kampf (nach dem Kampf), Anzeige; unten „Standardwerte“. Alle Auswahlen als Auswahllisten.
- Standardwerte-Knopf lässt erhalten (`keepOnReset`): Angel-Set, Rückkehr-Set, Zustand (mode/pending), Köder, Minimap-Position, Klicktaste, dbVersion; Fangdatenbank ist ohnehin keine Einstellung.
- Wertebereiche (`ranges`): Reichweite 10–100 m (5er), Musik/Umgebung/Effekte 0–100 % (5er), Nachlaufzeit 0–15 s.
- Neues Angel-Set: nur Haupt- und Nebenhand aktiv (ab 1.5.2).
- Verlauf der Versionen: `docs/changelog/Peon_Fishing.md`
- Hinweise „Im Spiel prüfen“ im Verlauf bei: 1.6.0, 1.5.2 (zusammen mit der Prüfliste erster Spieltag unter „Offene Punkte“ durchgehen)

## Peon_Broker – 0.39.0 (neu, Auktionshaus-Helfer)

- **Broker im Berufsfenster (ab 0.39.0):** Block unter den Reagenzien (Ergebniszeile Kosten/Ertrag/Gewinn, Tabelle je Material mit Quelle Vorrat/Händler/AH, Kosten laut Ledger oder Kaufpreis, Erlös im AH, Gesamt, Hinweis „Material verkaufen bringt mehr“ oder „Herstellen bringt mehr“ mit beiden Beträgen, Tooltips, Haken Twinks, Zahnrad), Händlerpreise aus Händlerbesuch, Ledger oder Schätzung, Gewinn in der Rezeptliste (orange, wenn Verkaufen mehr bringt) mit goldenem Strich am besten Rezept, alles einstellbar. **Noch zu prüfen durch KarloDerBaer im Spiel** (Prüfpunkte im Verlauf bei 0.39.0, bei Problemen `/broker pruefen beruf`).
- **Kürzung nach unten erst ab 75 % unter der Mitte (ab 0.38.0, F37a):** Ein echter Preissturz zählt im üblichen Bereich gleich voll, gleich wie im Manager.

- **Einkaufsliste in Arbeit (ab 0.37.0):** Der Reiter zeigt nur einen Hinweis (`W.WIP`), bis er überarbeitet ist.
- Konzept: `Peon_Broker_Konzept.md` (freigegeben 29.09.2026) – Funktionsumfang, Preisvorschlag, Markttrennung, Bauabschnitte.
- Dateien: Locales.lua, Broker.lua, Data.lua, Scan.lua, Tooltip.lua, Window.lua, Keep.lua, Sell.lua, Auctions.lua, Shop.lua (ab 0.34), Buy.lua, Radar.lua, Prices.lua, Probe.lua, Options.lua, Start.lua und Craft.lua (ab 0.24; Merchant.lua 0.19–0.23 entfernt), Media\trend_*.tga (5 Trend-Symbole, 32×32, selbst erstellt: dunkelgrün ↑, hellgrün ↗, blauer Balken, orange ↘, rot ↓), Media\dot_new.tga (grüner Punkt für neue Radar-Treffer, ab 0.19)
- SavedVariables: `PeonBrokerCharDB` (je Charakter, ab 0.10): `keep[Schlüssel] = { n = Menge oder nil (alle), t, name, q, icon }` (Behalten), `listSel` (gewählte Einkaufsliste; `lists` bis 0.33, wird beim Laden nach `PeonBrokerDB.lists` übernommen), `recipes[Ergebnis-itemID] = { r, name, n, m = { [itemID] = Stück }, o = Reihenfolge }` (erlernte Rezepte, ab 0.24, `o` ab 0.39); `vendorFlip` entfällt ab 0.24 (wird beim Start gelöscht). `PeonBrokerDB` (accountweit): `lists` (Einkaufslisten ab 0.34: id, name, pct, u, items[Schlüssel] = { wish, max, name, q, icon, u }), `listsGone` (Löschmarken), Einstellungen `minimapShow`, `minimapAngle`, `tooltipShow`, `tooltipAvg`, `tooltipVendor`, `tooltipHint`, `trendNeutral` (5 %), `trendStrong` (20 %), `undercutMode`/`undercutValue` (Einzelgegenstände, 1 Kupfer), `undercutMassMode`/`undercutMassValue` (Massenware, 0), `dumpPct` (30 %), `duration` (2/8/24 Std., Standard 8), `dataDays` (14–90, Standard 30), `windowWithAH` (aus), `windowTab`, `windowPos`, `shortMass` (an), `shortMassMin` (20), `sellOnlyProfitable` (an), `dealMinVendor` (10c), `dealMinMarket` (50s), `dealScans` (10), `dealDays` (7), `radarMaxAge` (60 Min., 0 = unbegrenzt; ersetzt `dealMaxAge`), `radarSound` (an), `radarMute` (an), `radarOrder` (smart), `radarKind` (both), `radarShowExpensive` (aus), `dealMargin` (20 %), `dealDepth` (20 %), `radarSoundKey` (raid), `radarFlash` (5 Sek.), `radarReserve` (Goldreserve in Gold, 0), `dealHold` (Markt-Schnäppchen: verkaufen innerhalb, 48 Std., 6–168, ab 0.26); Berufsfenster ab 0.39: `craftList` (an), `craftListWhich` (all/profit/top3/top5/top10), `craftListMode` (money/pct), `craftListBest`, `craftListLoss`, `craftListUnknown`, `craftBlock`, `craftSummary`, `craftColSrc`, `craftColCost`, `craftColSell`, `craftHint` (alle an); `dealMinVendor` in Kupfer bis 1000g, `dealMinMarket` in Silber (ab 0.19 größere Bereiche); Daten `dataVersion` = 2, `markets["Realm / Fraktion"]` (Aufbau siehe Data.lua), `commodity` (Warenart je Gegenstand), `sellMem` (je Gegenstand: gewählte Laufzeit/Menge, zuletzt eingestellter Preis), `owned` (letzter Stand der eigenen Auktionen je Markt), `itemKeys[itemID] = "Stufe:Zusatz"` (Schlüssel des Spiels für Gegenstände, die die normale Suche nicht findet, ab 0.24; ab 0.28 für Varianten `itemKeys["itemID:voller Name"]`), `markets[…].variants[itemID] = true` (Gegenstände mit Varianten, ab 0.28), `markets[…].mgrAt`, `mgrSrc`, `mgrItems` (zuletzt übernommener Stand vom Peon Manager: Zeit, `api` oder `scan`, Zahl der Gegenstände, ab 0.36), Varianten-Einträge mit `lk` (Link), `keyLog` (letzte 30 Schlüssel-Suchen; ab 0.28 wie `radarLog`, `showLog`, `aucLog`, `radarStats` nur mit `/broker debug`), `lastScanAt`, `probe`, `probeEvents`, `craftProbe` (ab 0.39), `merchant[itemID] = { p, t, w }` (Kaufpreise beim Händler je Stück, ab 0.39)
- Braucht Peon API 8 (meldet sonst „Peon ist zu alt“).
- Befehle: `/broker` (Broker-Fenster ein/aus), `/broker optionen`, `/broker scan`, `/broker pruefen` (auch `check`), `/broker pruefen scan`, `/broker pruefen abfrage`, `/broker pruefen beruf` (ab 0.39), `/broker debug`, `/peon broker`
- Optionsseite: Minimap-Button an/aus; Broker-Fenster mit dem Auktionshaus öffnen, Knopf „Broker-Fenster öffnen“; Preise im Tooltip (an/aus, Zeile 7 Tage, Zeile Händler, Hinweise); Berufe (ab 0.39, gleiche Punkte wie das Zahnrad im Berufsfenster); Trend (Grenzen); Preisvorschlag (Unterbieten Massenware und Einzelgegenstände je Kupfer/Prozent, Dumping-Grenze, Laufzeit, Massenware mit vielen Angeboten 2 Std. ab X Angeboten, nur lohnende im Reiter Verkaufen); Preisdaten (Tageswerte aufbewahren, Märkte verwalten); Prüfung; Ereignis-Liste.
- Verlauf der Versionen: `docs/changelog/Peon_Broker.md`
- Hinweise „Im Spiel prüfen“ im Verlauf bei: 0.36.0, 0.34.0, 0.33.1, 0.28.0, 0.25.2, 0.24.0 (zusammen mit der Prüfliste erster Spieltag unter „Offene Punkte“ durchgehen)

## Peon Manager (Programm für Windows, bis 0.5.0 Peon Client) – 0.22.0

- **Chancen für Massenware und unruhige Preise (ab 0.22.0, Rechenmodell Kapitel 10):** Kein Wiederverkauf, wenn unter dem Ziel mehr als ein Tagesabsatz liegt (F50b) oder die Schwankung über 40 % liegt (F50c). Neues Preisniveau schon nach 12 Std. (F54). Chancen zeigen nur den letzten Scan, der Zeitraum zählt nur die Häufigkeit. Preis und Menge im Diagramm auf derselben Zeitachse. Vorabversion `v2026.11.08.2-test` (08.11.2026, nur Kanal Test, enthält auch 0.21.1), Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen. **Noch zu prüfen durch KarloDerBaer:** Chancen-Tabelle, Satz „Das ist der Marktpreis“ (Robuster Stein), „Der Preis schwankt stark“ (Umhang des Hügelwächters), gemeinsame Zeitachse im Diagramm.

- **Bessere Vorschläge (ab 0.21.0, Rechenmodell Kapitel 10):** Kürzung nach unten erst ab 75 % (F37a), neues Preisniveau nach 12 bis 24 Std. unter oder über dem Bereich (F54, ab 0.22.0 nach 12 Std.), Wiederverkauf höchstens zum Median der Angebote und grüner Satz nur bei 20 % Abstand zu den anderen Angeboten (F50a), Trefferquote unter Chancen (F55). Grenzwerte in 2 bis 4 Wochen mit der Trefferquote prüfen, wenn der Markt nach dem Start ruhiger ist. Vorabversion `v2026.11.08-test` (08.11.2026, nur Kanal Test, zusammen mit Broker 0.38.0), Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen. **Noch zu prüfen durch KarloDerBaer:** Satz auf der Gegenstandsseite (zum Beispiel Magicusmantel), Pfeil bei „Zu üblich“, Trefferquote unter Chancen (erste Zahlen frühestens am 11.11.2026). In 0.21.0 zeigte „Beste Chancen jetzt“ noch Treffer nach alten Regeln (Robuster Stein), behoben in 0.21.1: Bei neuen Regeln (`chances.RULES`) werden die Wiederverkaufs-Treffer neu gerechnet, die Trefferquote beginnt neu.

- Reiter „Einkaufsliste (WIP)“ (ab 0.18.1), wird bald überarbeitet.
- Quellcode: `manager\` (bisher `client\`), Anleitung in `manager\README.md`. Design: `docs\konzepte\manager\Peon_Client_Design.md` (Funktionen, jetzt Modul Peon Broker Client) und `Peon_GitHub_Design.md` (Peon Manager, Module, Installieren).
- Programm bei KarloDerBaer: installiert wie bei allen anderen (ab 04.11.2026, siehe unten). Der frühere Ordner `<Programmordner>` mit Runtime und DB bleibt als Sicherung. Anderer Datenordner: Umgebungsvariable `PEON_MANAGER_DB`.
- Liest `WTF\Account\<Konto>\SavedVariables\Peon_Bridge.lua` (`PeonBridgeDB`), schreibt `AddOns\Peon_Bridge\Data.lua` (`PeonBridgeData`, Format 2, `channels` aus den aktiven Manager-Modulen, ab 0.18.0 je Markt `cur` mit den Preisen des neuesten vollständigen Stands).
- Manager-Module (ab 0.7.0, Variante B): Liste in `manager\src\core\modules.js`, je Modul Schlüssel, Name, Beschreibung, nötige Addons, Kanäle, Ansichten, Datenbankdatei. Erstes Modul **Peon Broker Client** (`broker-client`, Code in `broker-client.js`), standardmäßig aus, bei KarloDerBaer aktiv. Ansicht „Module“ mit Installieren, Entfernen und Daten löschen.
- Addons (ab 0.8.0, `src\core\addons.js`): Manifest des Release holen, Zip laden und prüfen, tauschen, bei Fehler zurücktauschen. Sucht beim Start und dann im eingestellten Abstand (`updateCheckMin`, ab 0.20.0, Standard 10 Minuten, vorher fest 6 Stunden), installiert nur per Klick. Meldung von Windows bei Neuem (`updateNotify`, ab 0.20.0). Junctions gelten als „Entwicklung (Repo)“ und bleiben unberührt, bei KarloDerBaer gibt es sie ab 06.11.2026 nur noch beim Entwickeln (`scripts\junctions.cmd`). Kanal Stabil oder Test in den Einstellungen. Quelle zum Testen: Umgebungsvariable `PEON_MANAGER_RELEASES`.
- Installiert (ab 0.9.0): Installer `PeonManager-Setup-<Version>.exe` für den Benutzer, ohne Administratorrechte, Programm unter `%LOCALAPPDATA%\Programs`, Daten in `%APPDATA%\Peon Manager\Daten`. Selbst-Update über `electron/updater.js`: lädt im Hintergrund, fragt vor dem Neustart. Ab 0.19.0 zeigt das Update-Fenster vor dem Schließen die Schritte, danach läuft der Installer sichtbar mit deutschen Texten (`electron/installer.nsh`) und startet den Manager neu. Liegt ein Ordner `DB` neben dem Programmordner (Aufbau bei KarloDerBaer), gilt dieser, und es gibt kein Selbst-Update.
- Blizzard-API (ab 0.11.0): Zugang, Anleitung und Prüfabruf unter Einstellungen für alle Module (`src\core\blizzard.js`). Ab 0.20.1 dort immer ein Link zum Entwicklerportal, nach dem Speichern ein Hinweis auf die Wartezeit bei neuen Zugängen und, solange kein Haus gewählt ist, ein Hinweis auf Quellen. Einleser im Broker Client (`blizzard-import.js`), Auswahl der Häuser unter Quellen, Einstellung `blizzard.houses`. Beobachter nur in der Testfassung (`blizzard-watch.js`). Wissen und offene Fragen: `docs\konzepte\manager\Peon_Blizzard_API.md`.
- Gegenstands-Tooltip (ab 0.12.0, `src\core\item-info.js`, Tabelle `item_info`): unter Gegenstände beim Überfahren und in der Detailansicht unter Eigenschaften, Daten aus der Blizzard-API. Wissen dazu: `docs\konzepte\manager\Peon_Blizzard_API.md`.
- Reiter Rückmeldungen (ab 0.14.0, `src\core\reports.js`, Tabellen `errors` und `feedback` in `peon.db`): liest Fehler aus `Peon.lua` und `!BugGrabber.lua` und Rückmeldungen aus `Peon_Feedback.lua`, eigene Rückmeldungen schreiben, alles bearbeiten und löschen, Notizen zu Fehlern. Senden über den Worker (ein Issue je Eintrag, höchstens 20 je Senden), die Vorschau vor dem Senden steht ab 0.19.0 in einem Dialog (`components\SendDialog.vue`). Das Spiel löscht Eingelesenes über `errorsClearBefore` und `feedbackClearBefore` in `Data.lua`. Worker: `worker\peon-fehler\` (Einrichtung in der README dort). Worker läuft unter `peon-fehler.karloderbaer.workers.dev`, Adresse steht in `REPORT_URL` (ab 0.13.1).
- Aufbewahrung (ab 0.15.0, `srccore
etention.js`): `keepDays` (Standard 14) und `hourDays` (Standard 60, mindestens 14), Vorlagen in `PRESETS`, Aufräumen in Schritten über `pruneInBackground`, Datei mit `auto_vacuum = INCREMENTAL`.
- Update-Fenster (ab 0.15.0, `components\UpdateDialog.vue`, Inhalt `Service.updateInfo`): beim Programmstart je Stand einmal und abschaltbar (`updateWindow`), immer nach „Nach Updates suchen“ und über „Jetzt aktualisieren“, die Suche im eingestellten Abstand zeigt nur den Knopf und meldet sich ab 0.20.0 über Windows (Klick öffnet das Update-Fenster). Merker `updatesShown` und `addonsSeen` in `peon.db`. Texte aus den Zeilen `Kurz:` der Changelogs, im Manifest als `news` je Version.
- Datensicherung (ab 0.16.0, `src\core\backup.js`, `restore.json` im Datenordner), Einrichtungsliste (`checklistHidden`), Stand des Datenwegs (`renderer\status.js`).
- Einkaufsliste (ab 0.17.0, `src\core\shopping.js`, `views\Shopping.vue`, Stand in `meta` unter `shop`, Merker `shopHits`, Einstellung `shopNotify`), Favoriten (Tabelle `favorites`, `renderer\store.js`, `components\Star.vue`), Märkte (`src\core\markets.js`, Tabelle `market_alias`, Einstellung `market`), Zwischenspeicher (`list_cache`, `dataSig`, `bands`, `listOf` in `broker-client.js`), genaue Werte (Tabelle `item_tip`, Bestellung `tipWants`, `tipWant` in `Data.lua`, Antworten aus `tipBox`), Spalten unter Gegenstände (`itemColumns`), Hinweis in der Kopfleiste (`noteGame`, `sync`, `meta` `gameLoadAt`). Merkliste und Schnellsuche sind ab 0.17.0 entfernt. Gruppen der Seitenleiste aus `navTitle` und `views` in `modules.js`.
- AHledger ist ab 0.11.0 entfernt.
- Bauen: `npm ci`, `npm run dist:setup` (Installer) oder `npm run dist` (nur Ordner) (Ordner `manager\release\win-unpacked`), Selbsttest mit `PEON_MANAGER_SELFTEST=<Ordner>`.
- Tests: `npm test` im Ordner `manager\` (Rechenkern, dazu der Vergleich mit Brokers Sales.lua über `tools\lua5.1.exe`).
- Verlauf der Versionen: `docs/changelog/Peon_Manager.md`

## Peon_Bridge – 0.6.0 (bis 0.3.0 Peon_Client, Verbindung zum Peon Manager)

- Design: `Peon_GitHub_Design.md` Abschnitt 4 (Bridge, Kanäle, Format von Data.lua), vorher `Peon_Client_Design.md` Bauabschnitt C1.
- Dateien: Data.lua (Platzhalter, vom Manager überschrieben, **nie mit ausgeliefert, nicht im Repo**), Locales.lua, Bridge.lua (Transport, Kanäle), Channel_Broker.lua (Kanal broker: Momentaufnahmen, Werte für Broker), Options.lua; Symbol `INV_Misc_Gear_01`. `## OptionalDeps: Peon_Broker`.
- SavedVariables: `PeonBridgeDB` (accountweit): Einstellungen `queueMax` (10, 1–30), `liveMax` (500, 0–2000, 0 = keine Live-Abfragen), `offerButton` (an), `freshDays` (7, 1–30, so lange gelten die Werte des Managers); Daten `nameFmt` (2), `fmt` (1), `queue` (wartende Momentaufnahmen, älteste zuerst), `seq`, `nameIds` (itemIDs, deren Namen der Manager schon hat), `tipIds` (Schlüssel, deren genaue Werte der Manager schon hat, ab 0.6.0), `tipBox` (bestellte genaue Werte für den Manager, ab 0.6.0), `ackAt`/`ackN` (letzte Bestätigung), `errors`. Warteschlange bleibt bei „Standardwerte“.
- Kanäle: Ein Kanal arbeitet nur, wenn `Data.lua` ihn freischaltet (`fmt = 2`, `channels.broker = true`). Ohne Freischaltung kein Zuhörer bei Broker, keine Aufzeichnung, keine Werte für Broker.
- Braucht Peon API 5 (Button, Text), Broker ab 0.30 für den Kanal broker.
- Befehle: `/peon bridge` (Optionen), `/peon bridge senden` (Reload), `/peon bridge status`, `/peon debug bridge`.
- `Data.lua` ab 0.6.0 zusätzlich `aliases` (andere interne Namen eines Markts), `shop` (Einkaufslisten für Broker) und `tipWant` (bestellte genaue Werte), Momentaufnahmen zusätzlich `tips` (genaue Werte).
- Verlauf der Versionen: `docs/changelog/Peon_Bridge.md`
- Im Spiel prüfen (nach dem Start): Optionsseite zeigt „Kanal broker freigeschaltet“ und „Peon Manager: Werte vom … (Version 0.6.0)“.

## Peon_Ledger – 0.13.0 (neu, Bestand und Buch)

- **Gegenstände und Gegenstand in Arbeit (ab 0.13.0):** Beide Reiter zeigen nur einen Hinweis (`W.WIP`), bis sie überarbeitet sind.
- Konzept: `Peon_Ledger_Konzept.md` (abgestimmt 02.10.2026). Bestand aller Charaktere, alle Bewegungen von Gegenständen und Gold mit Grund (nur ereignisgesteuert), Post einsammeln, Buch; Broker liest später nur daraus.
- Dateien: Locales.lua, Ledger.lua, Inventory.lua, Moves.lua, Cost.lua (ab 0.7), Tooltip.lua, Window.lua, Overview.lua, Stock.lua, History.lua, Book.lua, Catalog.lua (ab 0.10), Item.lua (ab 0.9), Pick.lua und Bindings.xml (ab 0.9.1), Probe.lua, Options.lua; Symbol `INV_Scroll_03` (bis 0.9.1 `INV_Misc_Book_09`, das nutzt schon das Dungeon-Journal)
- SavedVariables: `PeonLedgerDB` (accountweit): Einstellungen `minimapShow`, `minimapAngle`, `tooltipShow`, `windowPos`, `windowTab` (overview/stock/history/book/items), `historyMoves`, `historyOnlyMe`, `historyKind` (Filter Verlauf, ab 0.6), `bookPeriod` (today/d7/d30/all), `bookOnlyMe` (`worthEquip` ab 0.6, entfällt ab 0.7.3), ab 0.9 `itemPeriod` (7/30/90/0 = alles), `itemMarge`, `itemOff` (Linien aus), `itemLast`; ab 0.10 `catalogFilter` (all/stock/moved/ah) und `windowTab` auch `catalog`; ab 0.12 `session` (Gold zu Beginn der Sitzung); `windowTab` auch `item`; Bewegungen „Post von Twink“ ohne bekannten Versand merken `v` (Marktwert); `lotBase` ab 0.9 je Charakter `{ untilT, chars = { [Name] = { lots, fee } }, transit }`; `realms[Realm].chars[Vorname Nachname]` = { faction, class, level, money, moneyT, seen, places = { bags, bank, mail, auctions, equip } je { t, items = { [itemID] = Stück }, slots, used (Taschen/Bank: alle/belegte Plätze ab 0.2.1; Post: used = Anhänge, Auktionen: used = laufende Auktionen ab 0.2.2), … }, start = Inventur }; `realms[Realm].account.places.warband` (Accountbank, falls vorhanden); `realms[Realm].moves` = Bewegungen { t, c = Charakter, k = Art, id, n = Stück ±, m = Kupfer ±, x = Zusatz; Beute/Benutzt mit d = Tag, s = Vorzeichen, cnt } (älteste zuerst); `realms[Realm].weeks["JJJJ-WW"]["Charakter|Art|itemID"]` = { n, m } (Einträge älter als 90 Tage); `mailLog` (erste 40 verschiedene Briefe: Absender, Betreff, Gold, Rechnung – Fehlersuche); `items[itemID]` = { n, q, i }; `bankLog` (erste 5 Bankbesuche); `probe` (Ergebnis des Prüfbefehls), `probeEvents` (je Ereignis bekannt/Anzahl/letzte Zeit/3 Beispiele), `probeHooks` (mitgelesene Aufrufe: vorhanden, mitgelesen, Anzahl, Beispiele), `probeSnaps` (automatische Schnappschüsse je Fenster, höchstens 3)
- Braucht Peon API 10 (ab 0.9, Diagramm-Baustein).
- **Accountbank / Gildenbank (Recherche 06.10.2026):** Eine Accountbank (Kriegsmeutenbank) gibt es in Forever nach allem Bekannten nicht – der Reiter im Bankfenster und die Taschen-Nummern stammen aus der Retail-Oberfläche, die Taschen haben keine Plätze. Ledger liest sie nur, falls sie Plätze hat (Code bleibt). Die **Gildenbank** gibt es (Beta, 100 Gold); Gildenbank wird noch nicht erfasst (Ein- und Auslagern erscheint als „verbraucht/sonstiges“ bzw. „sonstiger Zugang“ mit Kosten 0) – erst testbar, wenn KarloDerBaers Gilde eine Gildenbank hat.
- Befehle: `/ledger` (Fenster), `/ledger optionen`, `/ledger pruefen` (auch `check`), `/ledger debug`, `/peon ledger`
- Verlauf der Versionen: `docs/changelog/Peon_Ledger.md`
- Hinweise „Im Spiel prüfen“ im Verlauf bei: 0.10.2, 0.10.0, 0.9.1 (zusammen mit der Prüfliste erster Spieltag unter „Offene Punkte“ durchgehen)

### Ledger – offen (Stand 03.10.2026, für die nächste Session)

**1. Im Spiel testen (umgesetzt, noch nicht gesehen)** – vorher in den Optionen „Buch zurücksetzen“ (entfernt die falschen Einträge vom 03.10.: 27× „Sonstiger Zugang“ nach dem Login, Erlöse mit falschem Gegenstand, zusammengefasster Erlös):
- Reiter **Buch** und **Gegenstände** (0.4): Zeiträume, „Nur dieser Charakter“, Gewinn, Verkaufsquote.
- **Vermögen** in der Übersicht (0.5, braucht Broker).
- **„Alle öffnen“ mit mehreren Erlösen** – Aufteilung je Brief (0.5.1).
- **Broker „Behalten“** mit Umschalter „Vorrat aller Charaktere“ (`mod:StockOthers`) und Verkaufsquote im Broker-Tooltip.
- Arten, die im Spiel noch nie vorkamen: Herstellen, Handel, Quest-Belohnung/-Abgabe, Zerstören, Lehrer, Post an Twink, Taschen ↔ Bank, Anlegen von Ausrüstung (kommt `PLAYER_EQUIPMENT_CHANGED`?).

- Neu in 0.6 (im Spiel testen): Gewinn-Zeile in der Übersicht, Spalten „Wert“ (Bestand) und „Ø Preis“ (Gegenstände), Filter im Verlauf, „Inventur neu“, Option Ausrüstung im Vermögen; Erlös ohne Rechnung zugeordnet, Auktionskauf in einer Zeile, Händler mit mehreren Stapeln.

**2. Bekannte Lücken** – die drei aus 0.5 sind mit 0.6 geschlossen (Erlös ohne Rechnung, Auktionskauf in einer Zeile, Händler mehrere Stapel). Weiter nicht erfasst: Gildenbank wird noch nicht erfasst (Ein- und Auslagern erscheint als „verbraucht/sonstiges“ bzw. „sonstiger Zugang“ mit Kosten 0) – erst testbar, wenn KarloDerBaers Gilde eine Gildenbank hat; Bank nur bei offener Bank; bei mehr als 50 Briefen sieht das Spiel nur einen Teil.

**3. Aus dem Konzept:** alles umgesetzt (0.6.0).

**4. Zuordnen – umgesetzt in 0.7.0 (im Spiel testen), Konzept `Peon_Ledger_Zuordnen.md`:** Kosten je Stück nach „älteste zuerst“ (accountweit, höchstens 30 Posten je Gegenstand), kostenlos Erhaltenes 0, Anfangsbestand zum Marktpreis, Hergestelltes mit Materialkosten, Gebühren je Gegenstand, Verbrauch als Info-Zeile. Begriffe: Kosten, Lagerwert, Wareneinsatz, Handelsgewinn, Verbrauch. Bauabschnitte Z1 (Posten und Kosten), Z2 (Anzeige), Z3 (Broker) – alle in Ledger 0.7.0 / Broker 0.25.0.

**5. Später:** Verkaufsquote (Ledger) und Absatzquote (Broker) verbinden; nach erfolgreichen Tests Ledger 1.0.

## Peon_Feedback – 0.4.0 (Zusatz, Feedback im Spiel)

- Dateien: Locales.lua, Feedback.lua, Window.lua, Options.lua. Symbol `INV_Misc_Note_01`. `## OptionalDeps: Peon_Bridge`
- SavedVariables: `PeonFeedbackDB` (accountweit): `entries` (id, t, module, kind, area, prio, text, char, market, zone, ver, edited, handed = an den Manager übergeben und ausgeblendet), `nextId`, `last`, `windowPos`, `minimapShow`, `minimapAngle`
- Befehle: `/feedback` bzw. `/peon feedback` (Fenster), `/feedback optionen`, `/peon debug feedback`
- Funktionen: Rückmeldungen im Spiel schreiben, ändern und löschen, Knopf „An Manager“ blendet sie aus, lädt neu und übergibt sie. Der Manager liest sie ein und führt sie weiter, das Addon löscht beim nächsten Laden, was er hat. Ohne Manager bleiben sie nur im Spiel.
- Braucht Peon API 7, Bereiche ab API 9. Aus dem Archiv zurück (0.2.0 bleibt in `<Archiv>\Peon_Feedback_0.2.0\`).
- Bei KarloDerBaer zuerst per Junction auf `addons\` verbunden (06.11.2026), der frühere Ordner 0.2.0 liegt in `<Archiv>\AddOns_vor_Peon_Feedback_2026-11-06\`.
- Verlauf der Versionen: `docs/changelog/Peon_Feedback.md`
- Hinweise „Im Spiel prüfen“ im Verlauf bei: 0.3.0 (zusammen mit der Prüfliste erster Spieltag unter „Offene Punkte“ durchgehen)

## Peon_Mover – 0.1.0 (neu, Fenster verschieben)

- Konzept: `Peon_Mover_Konzept.md` (abgestimmt 06.10.2026). Dateien: Locales.lua, Frames.lua, Mover.lua, Options.lua; Symbol `Ability_Rogue_Sprint`.
- SavedVariables: `PeonMoverDB` (accountweit): `enabled` (Verschieben erlaubt, Standard an), `frames[Fenstername] = { x, y, s, off }` (x/y = linke obere Ecke in UIParent-Einheiten, s = Größe, off = Mover für dieses Fenster aus). `frames` bleibt bei „Standardwerte“ erhalten.
- Braucht Peon API 7 (Liste auf der Optionsseite).
- Befehle: `/peon mover` (Optionen), `/peon mover zuruecksetzen` (alle Fenster), `/peon debug mover` (Log: eingehängte Fenster, Verschieben, Größe).
- Verlauf der Versionen: `docs/changelog/Peon_Mover.md`

## Peon_Panel – 0.4.0 (neu, Leiste und Panel)

- Konzept: `Peon_Panel_Konzept.md` (abgestimmt 06.11.2026, Überarbeitungen 07.11.2026 in den Abschnitten 12 und 13). Dateien: Locales.lua, Panel.lua, Skin.lua (ab 0.2), Display.lua, Menu.lua, Info.lua, InfoXP.lua, InfoPlace.lua, InfoSystem.lua, InfoSocial.lua (ab 0.3), Options.lua, Media\corner_fill.tga und corner_line.tga (ab 0.2, erzeugt mit `scripts\panel_media.js`); Symbol `INV_Misc_Spyglass_03`.
- Allgemeine Einträge (ab 0.3): XP, XP pro Stunde, Zeit bis Level-Up, Zone, Koordinaten, Haltbarkeit, Uhr auf der Leiste, Leistung, Spielzeit, Lautstärke, Freunde, Gilde, Ruf, Reset-Zeiten zum Anhaken.
- SavedVariables: `PeonPanelDB` (accountweit): `barShow` (an, immer oben in der Mitte), `barWidth` (30–100 %, 65), `barSize` (14–40, 18), `barHeight` (18–48, 26), `barGap` (4–30, 18), `barSeps` (aus), `barBg`, `barLabels` (Modulname vor dem Text, an), `barVis`, `style` (`tooltipDark`, `tooltip`, `metal`, `dialog`, `wood`, `plain`), `fontFace`, `fontStyle` (`none`, `shadow`, `outline`), `fontSize` (8–16, 11), `bgColor`, `lineColor`, `labelColor`, `valueColor`, `iconBorder` (aus), `highlight` (`soft`, `glow`, `none`), `xpLog` (Messung XP pro Stunde), `session` (Sitzung), `boxShow` (an), `boxCols` (0–8, 1, 0 = möglichst quadratisch), `boxSize` (16–48, 18), `boxBg`, `boxVis`, `boxLocked`, `boxPos` (x, y, leer = oben links unter der Leiste), `entries[Starter] = { bar, box, text, side, show }` (`side`: `left`, `center`, `right`, ohne Wahl Bags und Peon rechts, sonst links; `show`: `both`, `icon`, `text`), `barOrder`, `boxOrder`, `known`, `hintShown`. `barVis` und `boxVis`: `always`, `hover`, `combat`. Bei „Standardwerte“ bleiben `boxPos`, `entries`, die Reihenfolgen, die Merker, `xpLog` und `session`. `barPos`, `barX`, `barY` entfallen ab 0.2 (Übernahme über `migrate`).
- Standard ab 0.4.0 nach der Einstellung von KarloDerBaer: Stil `plain`, Panel an und aufklappbar (`fold`), Einträge beim ersten Start aus `DEFAULT_ENTRIES`, Reihenfolge als Standard von `barOrder` und `boxOrder`.
- Braucht Peon API 15. Module melden sich als Starter (`mod:NewLauncher`, `mod:NewMinimapButton`). Der Peon-Starter kommt aus Panel, weil der Kern kein Modul ist.
- Befehle: `/peon panel` (Optionen), `/peon debug panel`.
- Verlauf der Versionen: `docs/changelog/Peon_Panel.md`
- Hinweise „Im Spiel prüfen“ im Verlauf bei: 0.4.0, 0.3.0, 0.2.0, 0.1.0 (zusammen mit der Prüfliste erster Spieltag unter „Offene Punkte“ durchgehen)

## Peon_Bags – 0.6.0 (neu, Taschen, Bank, Gildenbank)

- Konzept: `Peon_Bags_Konzept.md` (abgestimmt 07.10.2026), eigene Bereiche `Peon_Bags_Bereiche.md` (abgestimmt 06.11.2026). Ersetzt Bagnon, Bagnon_Bank, Bagnon_GuildBank und BagBrother (Twinks zeigt Ledger).
- Dateien: Locales.lua, Bags.lua, Groups.lua (ab 0.3), Slots.lua, Window.lua, Setup.lua (ab 0.5, Leiste „Einstellen“), Inventory.lua, Bank.lua, Guild.lua, Options.lua; Symbol `INV_Misc_Bag_08`.
- SavedVariables: `PeonBagsDB` (accountweit): `replace` (Taschen und Bank ersetzen, an), `replaceGuild` (an), `bagCols` (10), `bagScale` (100 %), `bagLayout` (ab 0.5 classic/type/custom, vorher bags/type), `bagBar` (an), `bankCols`/`bankScale`/`bankLayout` (14, 100, classic), `guildCols`/`guildScale`/`guildLayout` (14, 100, classic, nur classic/type), `quality`, `newGlow`, `junk` (an), `autoMerchant`, `autoBank`, `autoMail`, `autoAuction`, `autoTrade`, `autoGuild` (an), `pos[bag|bank|guild] = { x, y }`, `groups` (eigene Bereiche: id, name, ab 0.3), `groupItems[itemID oder "itemID:voller Name"] = Bereich` (ab 0.3), alle drei bleiben bei „Standardwerte“. Ab 0.5 (Konzept `Peon_Bags_Anordnung.md`): `bagCatsOff`/`bankCatsOff`/`guildCatsOff` (abgewählte Kategorien je Fenster), `bagGroupsOff`/`bankGroupsOff` (abgewählte Bereiche je Fenster), `bagCollapsed`/`bankCollapsed`/`guildCollapsed` (eingeklappte Abschnitte: `g<id>`, `c:<Kategorie>`, `other`, `reagent`, `reagentbank`, `account`), `catOrder` (gemeinsame Reihenfolge der 17 Kategorien), `layoutVer` (2 = alte Anordnung übernommen). Abwahl, Reihenfolge und `layoutVer` bleiben bei „Standardwerte“. Ab 0.6: `bagPack`/`bankPack`/`guildPack` (Abschnitte nebeneinander, an). Spalten 6–24, Größe 50–200 % (5er).
- Braucht Peon API 7 (Liste, ab 0.3); Bereiche für Peon_Feedback ab API 9.
- Befehle: `/peon bags` (Taschenfenster ein/aus, geht immer – auch mit Bagnon), `/peon bags optionen`, `/peon bags debug`.
- Verlauf der Versionen: `docs/changelog/Peon_Bags.md`
- Hinweise „Im Spiel prüfen“ im Verlauf bei: 0.3.0, 0.2.2, 0.2.0 (zusammen mit der Prüfliste erster Spieltag unter „Offene Punkte“ durchgehen)

## Projektordner <Repo>

- Git-Repo, Aufbau siehe `docs\projekt\Peon_Ueberblick.md` (Wo alles liegt) und `docs\README.md`.
- `tests\`: eine Testdatei je Modul, Übersicht in `tests\README.md`.
- `tools\`: lua5.1.exe (Windows), lua5.1-linux (Linux, GitHub), LUA_COPYRIGHT.txt, gebaut aus dem offiziellen Quellcode Lua 5.1.5
- `vorlage\`: Peon_Beispiel (fertiges Grundgerüst) und test_beispiel.lua
- Alte Lieferungen aus dem Chat (`eingang\`) liegen im Archiv `<Archiv>\eingang\`.

## Offene Punkte

Ideen gibt KarloDerBaer einzeln vor; sie werden hier erst eingetragen, wenn sie beschlossen sind.

### Neues Modul Peon_Panel (beschlossen 06.11.2026, Konzept `Peon_Panel_Konzept.md`)

Gebaut mit Peon 0.14.0 und Peon_Panel 0.1.0, dazu Starter und Texte in Broker 0.35.0, Ledger 0.11.0, Fishing 1.6.0, Bags 0.4.0 und Feedback 0.4.0. Vorabversion `v2026.11.07.4-test` veröffentlicht (07.11.2026, nur Kanal Test), Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen. Im Spiel von KarloDerBaer getestet, es funktioniert (07.11.2026). Peon_Panel ist ein neues Addon: „Alles aktualisieren“ fügt es nicht von selbst hinzu, es hat im Manager einen eigenen Knopf.

**Überarbeitung nach dem Vorbild Titan Panel (beschlossen 07.11.2026, Konzept Abschnitte 12 und 13):** Gebaut mit Panel 0.2.0 (Leiste nur oben, runde Ecken, Bereiche, Menü auf freier Stelle, Anzeige je Modul, von KarloDerBaer im Spiel geprüft) und Panel 0.3.0, Peon 0.15.0, Ledger 0.12.0 (14 allgemeine Einträge, Stile, weitere Optionen, von KarloDerBaer im Spiel geprüft). Danach ergänzt und noch nicht im Spiel geprüft: Metall, Dialog und Holz verkleinert, Einstellungen der Leiste im Untermenü, Beschriftung je Eintrag, Gold mit Münzsymbolen, Leiste und Panel getrennt einstellbar, Panel mit Text rechts, Leiste und Panel aufklappbar, Leiste zweizeilig. Enthalten in der Vorabversion `v2026.11.07.5-test` (07.11.2026, nur Kanal Test, Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen). KarloDerBaer prüft alles zusammen im Spiel.

### Neuere Preise aus dem Manager im Spiel (beschlossen 07.11.2026)

Umgesetzt mit Manager 0.18.0, Bridge 0.7.0, Broker 0.36.0: Der Manager schickt die Preise des neuesten Stands (meist Blizzard-API) über `Data.lua`, Broker übernimmt sie beim Anmelden, wenn sie neuer sind als der eigene Scan. Auf der Leiste steht das Alter der neuesten Daten, der Tooltip nennt Scan und API getrennt. Alle Tests grün. Enthalten in der Vorabversion `v2026.11.07.5-test` (07.11.2026, nur Kanal Test), im Spiel noch nicht geprüft.

### Peon_Bags: eigene Bereiche (beschlossen 06.11.2026, Konzept `Peon_Bags_Bereiche.md`)

Erste Fassung gebaut mit Bags 0.3.0 (Bauabschnitte B1 bis B3), enthalten in der Vorabversion `v2026.11.07.4-test` (dort Bags 0.4.0). Von KarloDerBaer im Spiel geprüft, das Ziehen auf eine Überschrift funktioniert (07.11.2026). **Noch offen:** der Bereich zu Brokers Behalten-Liste (B4).

### Peon_Bags: Anordnung Klassisch, Nach Art, Individuell (beschlossen 07.11.2026, Konzept `Peon_Bags_Anordnung.md`)

Knopf „Einstellen“ statt „Nach Art“, Leiste rechts neben dem Fenster mit den drei Anordnungen, automatischen Kategorien (wählbar, Reihenfolge änderbar) und eigenen Bereichen (je Fenster abwählbar). Dazu einklappbare Abschnitte und die Kategorie „Neu“. Gebaut mit Bags 0.5.0, enthalten in der Vorabversion `v2026.11.07.7-test` (07.11.2026, nur Kanal Test, Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen). Von KarloDerBaer im Spiel geprüft, es funktioniert (07.11.2026). Danach gewünscht und gebaut mit Bags 0.6.0: kleine Abschnitte nebeneinander (abschaltbar) und Reihenfolge per Ziehen an der Überschrift, enthalten in der Vorabversion `v2026.11.07.8-test` (07.11.2026, nur Kanal Test, Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen), von KarloDerBaer im Spiel geprüft, es funktioniert (07.11.2026). Im normalen Release `v2026.11.07.9` (07.11.2026).

### Manager: Update mit sichtbarem Fortschritt und Senden im Dialog (beschlossen 07.11.2026)

- Beim Selbst-Update schließt sich der Manager nicht mehr ohne Hinweis: Vorher erklärt ein Dialog die Schritte, danach zeigt der Installer seinen Fortschritt und startet den Manager wieder.
- Die Vorschau vor dem Senden im Reiter Rückmeldungen erscheint in einem eigenen Dialog.
- Gebaut mit Manager 0.19.0, enthalten in der Vorabversion `v2026.11.07.7-test`. **Noch offen:** Update von 0.18.1 auf 0.19.0 im echten Programm. Erst das Update danach (von 0.19.0 aus) zeigt den Installer sichtbar, weil das Einspielen noch von der installierten Fassung gestartet wird.
- Dazu mit Manager 0.20.0 (Wunsch KarloDerBaer): Suche nach Updates einstellbar (Standard alle 10 Minuten) und Meldung von Windows bei Neuem. Ohne Vorabversion direkt im normalen Release `v2026.11.07.9` (07.11.2026, Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen), im echten Programm noch nicht geprüft.
- Dazu mit Manager 0.20.1 (Wunsch KarloDerBaer): unter Einstellungen bei der Blizzard-API immer ein Link zum Entwicklerportal, Hinweis auf die Wartezeit bei neuen Zugängen und auf die Auswahl eines Hauses unter Quellen. Zusammen mit Tooltip 0.7.5 (Rahmen ohne Fehler in Instanzen, Fehlerbericht 9) ohne Vorabversion direkt im normalen Release `v2026.11.07.10` (07.11.2026, Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen), im Spiel und im echten Programm noch nicht geprüft.

### Todo: Überarbeitung (KarloDerBaer, 06.11.2026)

Noch offen, wird in einer eigenen Sitzung bearbeitet. Vorher klären, was KarloDerBaer daran stört, das ist noch nicht besprochen. Bis dahin zeigen die Einkaufsliste in Broker und Manager sowie Gegenstände und Gegenstand in Ledger einen WIP-Hinweis (Broker 0.37.0, Ledger 0.13.0, Manager 0.18.1).

- **Einkaufsliste komplett überarbeiten**, im Spiel (Broker) und im Manager.
- **Reiter Preise** im Broker überarbeiten.
- **Reiter Gegenstände und Gegenstand** in Ledger überarbeiten.

Normales Release `v2026.11.07.6` am 07.11.2026 auf Wunsch von KarloDerBaer, die Reiter in Arbeit zeigen dort einen WIP-Hinweis. Vorher gab es nur Vorabversionen (zuletzt `v2026.11.07.5-test`).

### Navigation, Einkaufsliste, Favoriten, Ladezeiten (beschlossen 06.11.2026)

Umgesetzt mit Manager 0.17.0, Broker 0.34.0, Bridge 0.6.0. Vorabversion `v2026.11.07.3-test` veröffentlicht (06.11.2026, nur Kanal Test), Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen. **Noch zu prüfen im Spiel:** Übernahme der Listen, Abgleich in beide Richtungen, Feld „Max. Gold“, genaue Werte im Hintergrund (bleibt das Spiel flüssig, hängen die Werte von der Stufe im Link ab), wie lange ein Scan dadurch zusätzlich dauert.

**Noch offen, neutrales Auktionshaus:** Broker bildet den Markt aus Realm und Spielerfraktion. Ein Scan am neutralen Haus landet deshalb vermutlich im Markt der eigenen Fraktion und verfälscht dessen Preise. Wie das Spiel das neutrale Haus erkennbar macht, ist nicht geprüft. Klären, sobald KarloDerBaer an einem neutralen Auktionshaus ist. Die API-Daten betrifft das nicht.

### Umbau des Peon Managers (beschlossen 06.11.2026)

In dieser Reihenfolge:

1. **Updates wie bei allen anderen:** Erledigt. Umschalter `scripts\junctions.cmd manager` und `entwicklung`, bei KarloDerBaer umgeschaltet (06.11.2026), alle 10 Addons sind echte Ordner und werden im Kanal Test über den Manager aktualisiert. Update auf 0.15.1 über den normalen Weg geklappt. **Noch offen:** Rückkehr von Test zu Stabil im echten Programm.
2. **Aufbewahrung und Update-Fenster:** Erledigt mit Manager 0.15.0 und 0.15.1.
3. **Seitenleiste, Quellen, Übersicht, Updates und die weiteren Ideen** (Einrichtungsliste, Merkliste mit Preisalarm, Schnellsuche, Datensicherung): Erledigt mit Manager 0.16.0, von KarloDerBaer freigegeben.

### Peon auf GitHub, Peon Manager, Peon_Bridge (beschlossen 31.10.2026, Design `Peon_GitHub_Design.md`)

- Öffentliches GitHub-Repo, Releases mit einem Zip je Addon und Manifest. Projektordner wird das Repo, Addon-Code maßgeblich in `addons\`, Junctions im AddOns-Ordner.
- Peon_Client wird Peon_Bridge (Kanäle, Freischaltung durch den Manager), Programm wird Peon Manager mit dem Modul Peon Broker Client. Peon_Feedback wird archiviert.
- Umsetzung mit Claude Code nach Abschnitt 9 des Designs: Phase 1 (Einrichten, Repo, Junctions, Bridge, GitHub, erstes Release) vor dem Start, Phase 2 (Manager-Module, Ansicht Module) und Phase 3 (Installer, Selbst-Update) danach.
- **Fortschritt Phase 1:**
  - A Einrichten erledigt (31.10.2026): Git, Node 24, gh vorhanden, gh angemeldet, Sicherung in `<Archiv>\Sicherung_2026-10-31\`, `CLAUDE.md`.
  - B Repo lokal erledigt (31.10.2026): Addons nach `addons\` kopiert (Prüfsummen gleich), `client\` heißt `manager\`, Doku in `docs\`, Verlauf je Modul in `docs\changelog\` (geprüft: keine Zeile des alten Stands verloren), Tests laufen auf `addons\`, alte Lieferungen, `Claude outputs` und Peon_Feedback im Archiv. Alte Runtimes `Runtime_0.1.0` bis `Runtime_0.4.0` und `_neu` in `<alter Programmordner>` gelöscht (KarloDerBaer, 31.10.2026), es bleiben `Runtime`, `DB`, `DB_beta`.
  - C Junctions erledigt (31.10.2026): `scripts\junctions.cmd` (Zustand zeigen, `anlegen`), alle 9 Peon-Ordner im AddOns-Ordner per Prüfsumme gleich, ins Archiv `<Archiv>\AddOns_vor_Junctions_2026-10-31\` verschoben und durch Junctions auf `addons\` ersetzt. Peon_Feedback bleibt als normaler Ordner. Tests über die Junctions OK. Im Spiel erst nach dem Start prüfbar (Prüfliste Punkt 1), WoW ist bis dahin nicht spielbar.
  - D Peon_Bridge und Manager-Name erledigt (31.10.2026): Peon_Bridge 0.4.0 mit Kanälen, Broker 0.33.0, Peon Manager 0.6.0 nach `<Programmordner>` (KarloDerBaer), Datenordner mit umgezogen (nur settings.json, noch keine Datenbank, KarloDerBaer). Junction Peon_Bridge angelegt, alte Junction Peon_Client entfernt. Selbsttest des Managers schreibt `Data.lua` mit `channels.broker = true`. Alle Tests OK. Im Spiel erst nach dem Start prüfbar (Prüfliste Punkt 3).
  - E GitHub (31.10.2026): persönliche Daten durch erfundene Namen ersetzt (Ledger 0.10.1 wegen des Beispieltexts), Lizenz MIT, `README.md` für Freunde (ohne Discord, Feedback über Issues), `.github/workflows/tests.yml`. Repo `KarloDerBaer/peon`, öffentlich.
  - **Neue Reihenfolge (KarloDerBaer, 31.10.2026):** Das erste Release kommt erst, wenn auch der Peon Manager fertig ist. Zuerst F1 (Skript für Zips und Manifest, ohne Veröffentlichung), dann G Manager-Module, H Ansicht „Module“ und Installieren, I Installer und Selbst-Update, danach das erste Release mit allen Addons (Peon_Bridge nur über den Manager) und dem Installer.
  - Programmname von WoW Forever: `Wow.exe` im Ordner `_forever_` (geprüft 31.10.2026, für die Warnung „WoW läuft“).
  - F1 erledigt (31.10.2026): `node scripts/build_release.js [--tag vJJJJ.MM.TT] [--test] [--prev manifest.json]` baut nach `build\release\<Tag>\` je Addon ein Zip, `manifest.json` (Design 6.2) und `notes.md` (Text für das Release). Einstellungen je Addon (nötige Kern-API, nur Manager, Ausnahmen wie Data.lua) und die Manager-Module stehen in `scripts\release.json`. Die Zips sind immer gleich gebaut (gleiches Addon, gleiche Prüfsumme). Geprüft: mit Windows entpackt, alle 97 Dateien gleich dem Repo, kein Data.lua. Tests in `scripts\test\`, laufen auch auf GitHub. Nichts veröffentlicht.
  - „Was ist neu“ kommt aus den Changelogs und ist sehr technisch (Funktionsnamen, „Wunsch KarloDerBaer“). Entschieden (04.11.2026): Beim ersten Release bleibt es leer, ab dem zweiten kommen die Changelogs. Ob es dafür kürzere Texte für Freunde geben soll, ist noch offen.
  - G Manager-Module erledigt (31.10.2026): Peon Manager 0.7.0. Broker Client als abschaltbares Modul mit eigener Datei `broker-client.db` (KarloDerBaer), Seitenleiste je nach aktiven Modulen, `channels` je Modul, Ansicht „Module“. Bei KarloDerBaer zieht `peon.db` beim ersten Start einmalig nach `broker-client.db` um (mit einer Kopie im Selbsttest geprüft). Programm eingespielt, alte Version als `Runtime_0.6.0`.
  - H Ansicht „Module“ und Installieren erledigt (04.11.2026): Peon Manager 0.8.0. Im echten Programm geprüft mit einem Paket aus `build_release` über einen lokalen Server und einem Testordner: alle 9 Addons installiert (98 Dateien gleich dem Repo), eines aktualisiert, alte Fassung in der Sicherung. **Noch offen aus der Abnahme:** dasselbe mit dem echten Release auf GitHub, das erst mit dem ersten Release möglich ist (Punkt der Abnahme für das erste Release).
  - I Installer und Selbst-Update (04.11.2026): Peon Manager 0.9.0, `release.yml` baut alles auf GitHub, README mit Installation und SmartScreen. Im Testordner geprüft: Installer installiert 0.9.0, Manager lädt 0.9.1 und spielt sie ein (1,2 MB statt 99 MB, die Fassungen unterschieden sich aber fast nur in der Versionsnummer). **Noch nicht geprüft:** Knopf „Jetzt neu starten“ (Test lief ohne Neustart), Warnung von SmartScreen, Selbst-Update gegen das echte GitHub.
  - Umzug bei KarloDerBaer erledigt (04.11.2026): Manager 0.9.1 mit dem Installer installiert, Daten nach `%APPDATA%\Peon Manager\Daten` kopiert (Prüfsummen gleich), `Data.lua` hat `channels.broker = true`.
  - README neu gestaltet (04.11.2026): Logo, Badges, Bild vom Manager (`docs\bilder\manager_module.png`, nur Testdaten), Link zu Buy Me a Coffee.
  - **Erstes Release `v2026.11.04` veröffentlicht (04.11.2026):** alle 9 Addons, Manager 0.9.2. Gegen das echte GitHub geprüft: frisch gebauter Manager 0.9.2 installiert im Testordner alle 9 Addons (98 Dateien gleich dem Repo), Prüfsumme des geladenen Installers gleich `latest.yml`.
  - **Blizzard-API (04.11.2026):** Prüfabruf unter Quellen fertig (Manager 0.10.0, im Release `v2026.11.04.2`, Addons darin unverändert, gegen das echte GitHub geprüft wie beim ersten Release). **Nächster Schritt:** Nach dem Start mit einem eigenen Zugang prüfen. Liefert er Angebote, passend zum echten Format den Einleser bauen und die Zuordnung zu den Märkten klären. Sonst später erneut prüfen. Stand der Prüfungen (EU): 04.11., 20:13 Uhr, vor dem Start: Realms antworten (26), alles zu Auktionen 404. 05.11., 05:02 Uhr, nach dem Start: Anmeldung klappt, auch die Realms liefern jetzt 404. Im Forum und bei goldbook gibt es dazu noch nichts. Der Bericht meldet dann „Bereich unbekannt“, das ist ungenau: Ein unbekannter Bereich antwortet laut goldbook mit 403, hier kam 404.
  - **Release `v2026.11.05` veröffentlicht (05.11.2026):** Bags 0.2.2 und Tooltip 0.7.4 aus dem ersten Test in Forever, die übrigen Addons und Manager 0.10.0 unverändert. Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen. Tooltip 0.7.3 und 0.7.4 sind im Spiel noch zu prüfen, der Broker erst, wenn KarloDerBaer ins Auktionshaus kommt.
  - **Blizzard-API liefert Auktionsdaten (05.11.2026):** Forever läuft über Regelsatz und Auktionshaus, nicht über Realms (`docs\konzepte\manager\Peon_Blizzard_API.md`). Manager 0.11.0: Zugang unter Einstellungen, Prüfabruf auf den richtigen Wegen, Beobachter in der Testfassung. Geprüft gegen das echte Blizzard: Der Markt von KarloDerBaer ist Haus 111 (Scan 98,7 % gleich, Testangebot bestätigt), Takt stündlich, Angebotsnummern bleiben gleich. Einleser, Auswahl unter Quellen und Anleitung sind gebaut, AHledger ist entfernt. Die Nutzung durch Ledger kommt später.
  - **Release `v2026.11.05.2` veröffentlicht (05.11.2026):** Manager 0.11.0, alle Addons unverändert. Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen, Prüfsumme des Installers gleich `latest.yml`. **Noch offen:** Selbst-Update von 0.10.0 auf 0.11.0 auf dem echten Rechner, Formular der Anleitung, Klicks in Quellen und Einstellungen durch KarloDerBaer.
  - **Release `v2026.11.07.2` veröffentlicht (06.11.2026):** Manager 0.16.0, Addons unverändert, gleicher Stand wie die Vorabversion `v2026.11.07.2-test`. Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen. Davor nur als Vorabversionen: `v2026.11.06.2-test` (0.15.0), `v2026.11.07-test` (0.15.1). **Wichtig für das nächste Release:** Der Name zählt beim Vergleich und `v2026.11.07.2` liegt einen Tag voraus (ein Manager bis 0.15.0 nahm den ersten Eintrag bei GitHub). Ein neues Release braucht einen höheren Namen, also am 06. und 07.11.2026 `v2026.11.07.3` und danach das jeweilige Datum.
  - **Release `v2026.11.06` veröffentlicht (06.11.2026):** Manager 0.14.0 (Reiter Rückmeldungen), Peon 0.13.0, Bridge 0.5.0 und neu Peon_Feedback 0.3.1, die übrigen Addons unverändert. Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen. Die öffentlichen Issues im Repo `peon` sind abgeschaltet, Berichte laufen über den Manager ins private Repo `peon-fehler`.
  - **Release `v2026.11.05.3` veröffentlicht (05.11.2026):** Manager 0.12.0 (Gegenstands-Tooltip), Peon 0.11.1, Broker 0.33.1, Ledger 0.10.2, Fishing 1.5.2, die übrigen Addons unverändert. Bau auf GitHub erfolgreich, Manifest und `latest.yml` nachgelesen, Prüfsumme des Installers gleich `latest.yml`. **Noch offen:** Prüfung im Spiel (siehe Changelogs), Selbst-Update auf 0.12.0 auf dem echten Rechner.
  - **Noch offen aus der Abnahme von H und I:** Installer auf einem fremden Rechner mit Warnung von SmartScreen (Freund), Selbst-Update gegen das echte GitHub mit Knopf „Jetzt neu starten“ (Manager 0.9.1 bei KarloDerBaer auf 0.9.2).

### Peon Client und Modul Peon_Client (beschlossen 22.10.2026, Design `Peon_Client_Design.md` abgestimmt)

- Programm für Windows (Electron, Vue): Auktionsdaten aus eigenen Scans, Live-Abfragen und AHledger (später Blizzard-API) erfassen, speichern, auswerten, Preisbereiche an Broker zurückgeben. Neues Modul Peon_Client im Spiel für die Schnittstelle.
- Bauabschnitte C1 Modul Peon_Client und Broker-Zuhörer, C2 Client-Grundgerüst mit Einlesen und Übersicht, C5 Quellenprüfung AHledger (vor Beta-Ende, Start laut AHledger 4./5. November), C3 Gegenstand mit Verlauf, C4 Rückgabe an Broker (vorher Rechenmodell Kapitel 8 abstimmen), C6 Ranglisten und Chancen.
- C1 umgesetzt und im Spiel bestanden (22.10.2026): Peon_Client 0.1.2, Broker 0.30.2. C2 umgesetzt (22.10.2026): Programm Peon Client 0.1.0.
- **Beta offline ab 22./23.10.2026** bis zum Start (4./5. November): keine Tests im Spiel. Neue Reihenfolge (KarloDerBaer): bis zum Start Programm fertig bauen: Broker-Verlauf als eigene Quelle, C3 Gegenstand mit Verlauf, C4 Rückgabe an Broker (vorher Rechenmodell Kapitel 8 abstimmen), C6 Chancen. AHledger, Blizzard-API, weitere Quellen und C5 (Quellenprüfung) erst zum Release. Programm selbst kann KarloDerBaer ohne Spiel testen (liest die vorhandene WTF-Datei).
- **Kreislauf im Spiel bestätigt (23.10.2026, KarloDerBaer, letzter Beta-Tag):** Peon_Client hat die `Data.lua` des Programms geladen und den bestätigten Scan vom 22.10. aus der Warteschlange gelöscht (`ackAt`, `ackN` = 1); neuer Scan (10.347 Angebote, 5.036 Zeilen, 1.153 Gegenstände) vom Programm 0.2.0 übernommen und bestätigt, Broker-Verlauf 4.607 Gegenstände, keine Fehler. KarloDerBaer: Programm 0.2.0 „scheint alles zu passen“.
- Broker-Verlauf und C3 umgesetzt (Programm 0.2.0, 22.10.2026).
- **C4 umgesetzt (23.10.2026):** Rechenmodell Kapitel 8 abgestimmt (nur Langzeit-Teil, 14 Tage wie Broker, Absatz später mit C6), Programm 0.3.0, Peon_Client 0.2.0, Broker 0.31.0. Im Spiel erst nach dem Start prüfbar.
- **Umzug in die Release-Version (25.10.2026, KarloDerBaer):** Die Beta ist beendet, im Beta-Ordner waren die zuletzt geschriebenen Broker-Dateien schreibgeschützt. Abgestimmt: nur die Peon-Addons ziehen nach `<WoW-Ordner>\Interface\AddOns` (fremde Addons installiert KarloDerBaer über CurseForge), **frisch anfangen** (keine SavedVariables aus der Beta), `Peon_Client\Data.lua` als leerer Platzhalter, **neue Datenbank** im Peon Client (alte als `<alter Programmordner>\DB_beta`, Einstellung WoW-Ordner auf `_forever_`). Alle Peon-Addons in `_forever_` per Prüfsumme gleich der Arbeitskopie bzw. dem Beta-Stand. Tests laufen jetzt im neuen Ordner, test_fish mit fester Kopie der Beta-Einstellungen (`tests\fixtures\wtf`). Standard-Ordner im Quellcode des Programms auf `_forever_` (wirkt mit dem nächsten Bau). In `_forever_` liegt schon ein Konto mit einem Charakter (Realm-Ordner 93) vom **Stresstest am 21.10.** (KarloDerBaer: vermutlich schon der Client, der released wird). `Config.wtf`: `portal "EU"`, deDE; Connection.log nennt EU-Realms („CAMWOW EU4 Realm 3 PvE“), Server-Build 70399, Client 1.60.1.70532. Für AHledger also später ein EU-Markt (`forever.<Regelsatz>.<Fraktion>.eu`).
- **Prüfliste erster Spieltag nach dem Start** (alles bisher nur mit dem Nachbau geprüft):
  1. Addonliste: alle Peon-Module geladen (kommen ab 31.10.2026 per Junction aus dem Repo), keine LUA_WARNING (Interface-Nummer noch 16001?). `/peon list`.
  2. Optionen der Module einmal einstellen (frischer Start), `/reload`, prüfen, dass sie bleiben.
  3. Peon Manager (installierte Fassung) einmal starten (schreibt Data.lua, Modul Peon Broker Client muss installiert sein), dann im Spiel `/peon bridge status`: „Kanal broker freigeschaltet“. Auktionshaus: Komplettscan mit Broker, Knopf „An Manager“, Reload. `/peon bridge status`: 1 Komplettscan, Größe plausibel, keine Fehler (`PeonBridgeDB.errors`, `PeonBrokerDB.lastScanError`).
  4. `Peon_Bridge.lua` in WTF ansehen: Namen mit Händlerpreis und Warenart (`Name|Qualität|Händlerpreis|1/0`), Region (`GetCurrentRegion`, in der Beta 110).
  5. Peon Manager: liest den Scan ein, neuer Markt mit dem Realm-Namen, Bestätigung in Data.lua, nach dem Reload ist die Warteschlange leer.
  6. Live-Abfragen (Verkaufen, Radar) erscheinen im Client mit Auktionsnummern und Restzeit.
  7. Ab dem zweiten Scan (höchstens 24 Std. Abstand): Absatz im Client. Ab Tag 3: üblicher Bereich, Broker-Tooltip zeigt „Üblich (Client, n Tage)“ (Text bleibt so, gemeint ist der Manager mit dem Broker Client) und bei wenig eigener Beobachtung „Absatz (Client, 14 Tage)“.
  8. Chancen mit echten Daten ansehen und die Schwellen aus Rechenmodell Kapitel 9 prüfen.
  9. Peon_Ledger, Peon_Bags, Peon_Fishing, Peon_Tooltip, Peon_Mover und ComboPoints kurz im Alltag prüfen (Bestand neu aufbauen, Taschen, Angeln, Tooltip, Fenster).
- **C6 umgesetzt (23.10.2026):** Rechenmodell Kapitel 9 (Entwurf, Grundsätze von KarloDerBaer abgestimmt), Programm 0.4.0, Peon_Client 0.3.0, Broker 0.32.0 (6 Dateien noch nachzuholen, siehe Programm 0.4.0). Damit sind die Bauabschnitte bis zum Start fertig. **Nächste Schritte:** Broker-Dateien nachholen; Schwellen der Chancen mit echten Daten nach dem Start prüfen; zum Release AHledger, Blizzard-API (Auktionsnummern machen den Absatz genau), C5.

### Neues Modul Peon_Bags (beschlossen 07.10.2026, Konzept `Peon_Bags_Konzept.md` abgestimmt)

- Eigene Taschen, Bank und Gildenbank in Peon; ersetzt Bagnon, Bagnon_Bank, Bagnon_GuildBank und BagBrother (Twinks zeigt Ledger).
- Taschenfenster mit Reagenzientasche als eigenem Abschnitt, Anordnung „Taschenreihenfolge“ oder „nach Art“ (Knopf im Fenster), Suche, Qualitätsrahmen, neue/Quest/Müll markiert, Taschenleiste, Gold, freie Plätze; Bankfenster gleich aufgebaut; Gildenbank nach Blizzards Retail-Schnittstelle vorbereitet (erst testbar, wenn KarloDerBaers Gilde eine hat).
- Schlank: vorerst keine Broker-/Ledger-Anzeigen im Fenster.
- Plätze sind Blizzards Taschenknöpfe (`ContainerFrameItemButtonTemplate`), Blizzard-Fenster nur ausgeblendet, nichts ersetzt. Solange Bagnon geladen ist, ersetzt Peon_Bags nichts (nur `/peon bags`).
- Bauabschnitte T1 Taschenfenster, T2 Plätze/Anordnung/Suche/Optionen, T3 Bank, T4 Gildenbank, T5 Mover M4. T1–T4 umgesetzt in Peon_Bags 0.1.0 (07.10.2026). **Nächster Schritt:** Test im Spiel (Bagnon abschalten), danach T5 mit Mover M4.

### Neues Modul Peon_Mover (beschlossen 06.10.2026, Konzept `Peon_Mover_Konzept.md` abgestimmt)

- Fenster von Blizzard und Peon verschieben (Titelleiste), Größe mit Strg + Mausrad, Zurücksetzen mit Umschalt + Rechtsklick, Positionen dauerhaft; Optionsseite mit Fensterliste (je Fenster an/aus, zurücksetzen) und Sperre. Nur Fenster, keine Aktionsleisten/Rahmen (dafür gibt es den Bearbeitungsmodus).
- Kein Prüfbefehl: Forever nutzt den Retail-Client; BlizzMove unterstützt Forever offiziell, seine Fensterliste ist die Grundlage, dazu automatische Erkennung über Blizzards Fenster-Tabelle (`UIPanelWindows`).
- Bauabschnitte M1–M4 (M4: Peon-Fenster über Kern API 11 `Peon.RegisterWindow`). M1–M3 umgesetzt in Peon_Mover 0.1.0 (06.10.2026, Fragen geklärt: accountweit, Umschalt + Rechtsklick setzt Position und Größe zurück, Peon-Fenster über Kern-Erweiterung). **Nächster Schritt:** Test im Spiel, danach M4.

### Neues Modul Peon_Ledger (beschlossen 02.10.2026, Konzept `Peon_Ledger_Konzept.md` abgestimmt)

- Bestand aller Charaktere (Taschen, Bank, Post, Auktionen, angelegt, Gold) mit Inventur als Ist-Zustand, alle Bewegungen von Gegenständen und Gold mit Grund (inkl. Herstellen, Verbrauch; Rest „verbraucht/sonstiges“), Post einsammeln (nur Auktionshaus-Post, per Knopf), Buch mit Verkaufsquote. Ersetzt die Broker-Punkte „Buch“, „Post einsammeln“ und „Bestände anderer Charaktere“.

### Peon_Ledger – Reiter „Gegenstand“ und Kosten je Charakter (beschlossen 06.10.2026, Konzept `Peon_Ledger_Gegenstand.md`)

- Alles zu einem Gegenstand mit zwei Diagrammen (Charakter / Auktionshaus), Gewinnzone, Marge-Streifen, Auswahlliste Charakter. Bauabschnitte G1 Kern-Diagramm (API 10), G2 Broker-Verlauf (Absatz länger), G3 Kosten je Charakter, G4 Tagesverlauf je Gegenstand, G5 Reiter – **alle umgesetzt 06.10.2026** (Peon 0.10.0, Broker 0.27.0, Ledger 0.9.0), Tests OK.
- **Nächster Schritt:** Test im Spiel (**WoW komplett neu starten**). Besonders: Sehen die Linien glatt aus (`CreateLine`) und ist die Gewinnzone eine Fläche (`SetVertexOffset`)? Passt alles ins Fenster (760 × 500)? Auswahlliste Charakter, Mauslinie, Klick in Bestand/Verlauf/Gegenstände, „Mehr… (Ledger)“ im Broker, Kosten je Charakter im Tooltip (Umschalt).

### Peon_Broker (beschlossen 02.10.2026 nach dem Vergleich mit anderen AH-Addons)

- Alle Punkte erledigt (03.10.2026): Startseite, Berufe, Vorrat/Verkaufsquote aus Ledger (Behalten, Einkaufsliste, Tooltip, Verkaufen) mit Broker 0.24.0; Abverkauf (Absatz 0.23) und Vorschlag bei schwankenden Preisen (Richtwert 0.21) gestrichen. Neue Punkte gibt KarloDerBaer einzeln vor.
- **Nächster Schritt:** Test von Broker 0.24.0, Ledger 0.6.0 und Feedback 0.2.0 im Spiel (**WoW komplett neu starten** – neue Dateien Start.lua und Craft.lua). Besonders: Radar mit Gegenständen mit Zusatz (danach `PeonBrokerDB.keyLog` ansehen), „Händler: jetzt kaufen“ (kommt der Preis vorab an? keine Fehlermeldung „Aktion wegen AddOn fehlgeschlagen“?), Berufsfenster-Box.
