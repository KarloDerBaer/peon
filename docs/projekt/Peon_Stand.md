# Peon: Stand je Modul

Stand: 31.10.2026, **umgezogen ins Git-Repo** (Addon-Code in `addons\`), nach Peon 0.11.0 / Broker 0.33.0 / Bridge 0.4.0 (bis 0.3.0 Peon_Client) / Peon Manager 0.11.0 (bis 0.5.0 Programm Peon Client) / Ledger 0.10.1 / Fishing 1.5.1 / Tooltip 0.7.4 / ComboPoints 3.5.1 / Mover 0.1.0 / Bags 0.2.2. Peon_Feedback 0.2.0 ist archiviert (`<Archiv>\Peon_Feedback_0.2.0\`).
Je Modul stehen hier nur Version, Dateien, Einstellungen, Befehle und was noch zu prüfen ist. Der Verlauf der Versionen steht in `docs\changelog\<Modul>.md` (neueste oben). Bei jeder Änderung an einem Modul diesen Abschnitt und den Changelog aktualisieren.

## Peon (Kern) – 0.11.1, API 11

- Dateien: Locales.lua, Core.lua, Feedback.lua (ab 0.9, direkt nach Core.lua), Module.lua, Options.lua, Widgets.lua, List.lua, Minimap.lua, Chart.lua (ab 0.10), Slash.lua
- SavedVariables: `PeonDB` (derzeit leer)
- Aufgaben: globales Objekt `Peon`, Modulverwaltung (`Peon:NewModule`), Einstellungen mit Standardwerten/Bereichen/erlaubten Werten, Übernahme alter Variablennamen (`oldDB`/`oldCharDB`), Ereignisse (INIT, LOGIN, COMBAT_START, COMBAT_END, RESET, CHANGED), Debug-Log, Einstellungsseite „Peon“ mit Modulübersicht, Optionsseite mit Bildlauf und Bausteinen (Header, Slider, Check mit Hinweis/eigenen Werten, Dropdown, Choice, PositionGrid, Color, Button, Text, Reset-Knopf, mitwachsende Anordnung), `keepOnReset`, `/peon`.
- Noch nicht im Kern: `RegisterUnitEvent`.
- Verlauf der Versionen: `docs/changelog/Peon.md`
- Hinweise „Im Spiel prüfen“ im Verlauf bei: 0.11.1, 0.10.0 (zusammen mit der Prüfliste erster Spieltag unter „Offene Punkte“ durchgehen)

## Peon_Tooltip – 0.7.4 (früher TooltipPlus)

- Dateien: Locales.lua, Tooltip.lua, Style.lua, Units.lua, Icons.lua, Items.lua (ab 0.6), Debug.lua, Options.lua
- SavedVariables: `PeonTooltipDB`
- Befehle: `/ttp` (Optionen), `/ttp reset`, `/ttp debug` (Einheit unter der Maus untersuchen), `/ttp teile` (nächsten Gegenstands-Tooltip im Chat in Teile aufschlüsseln, ab 0.6), `/ttp log` bzw. `/peon debug tooltip` (Debug-Log)
- Funktionen: Tooltip folgt der Maus (Ecke, Abstand X/Y, Kantenwechsel), Größe, Hintergrund-Deckkraft, Rahmenfarbe (keine/Haltung/Klasse), Spielerinfos (Name in Klassenfarbe, Gilde), eigenes Ausblenden, Kampfmodus (normal/durchsichtig/aus, Umschalt zeigt), PvP- und Quest-Symbol mit Position und Größe.
- Optionsseite: Kern-Bausteine (braucht Peon API 6). Position der Tooltips und Symbole als Knopfraster, Rahmenfarbe und Kampfmodus als Auswahllisten.
- Verlauf der Versionen: `docs/changelog/Peon_Tooltip.md`
- Hinweise „Im Spiel prüfen“ im Verlauf bei: 0.7.4, 0.7.3, 0.7.2, 0.7.1, 0.7.0, 0.6.0 (zusammen mit der Prüfliste erster Spieltag unter „Offene Punkte“ durchgehen)

## Peon_ComboPoints – 3.5.1 (früher Combo Point Display)

- Dateien: ComboPoints.lua, Options.lua
- SavedVariables: `PeonComboPointsDB`
- Befehle: `/peon combopoints` (Optionen), `/peon debug combopoints`
- Funktionen: runde Combo-Punkte im Blizzard-Stil über dem Nameplate des Gegners, nur für Schurken aktiv. Einstellbar: Größe, Abstand, Höhe, Randdicke, leere Fassungen, Farben (Füllung, Fassung, Rand).
- Technik: geheime Werte über StatusBars (`SetMinMaxValues(i-1, i)`), Träger über den Nameplate-Rahmen; eigener Ereignisrahmen wegen `RegisterUnitEvent`.
- Optionsseite: Kern-Bausteine, mit Vorschau.
- Verlauf der Versionen: `docs/changelog/Peon_ComboPoints.md`

## Peon_Fishing – 1.5.2 (früher FishingPlus)

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
- Hinweise „Im Spiel prüfen“ im Verlauf bei: 1.5.2 (zusammen mit der Prüfliste erster Spieltag unter „Offene Punkte“ durchgehen)

## Peon_Broker – 0.33.1 (neu, Auktionshaus-Helfer)

- Konzept: `Peon_Broker_Konzept.md` (freigegeben 29.09.2026) – Funktionsumfang, Preisvorschlag, Markttrennung, Bauabschnitte.
- Dateien: Locales.lua, Broker.lua, Data.lua, Scan.lua, Tooltip.lua, Window.lua, Keep.lua, Sell.lua, Auctions.lua, Buy.lua, Radar.lua, Prices.lua, Probe.lua, Options.lua, Start.lua und Craft.lua (ab 0.24; Merchant.lua 0.19–0.23 entfernt), Media\trend_*.tga (5 Trend-Symbole, 32×32, selbst erstellt: dunkelgrün ↑, hellgrün ↗, blauer Balken, orange ↘, rot ↓), Media\dot_new.tga (grüner Punkt für neue Radar-Treffer, ab 0.19)
- SavedVariables: `PeonBrokerCharDB` (je Charakter, ab 0.10): `keep[Schlüssel] = { n = Menge oder nil (alle), t, name, q, icon }` (Behalten), `lists` (Einkaufslisten: name, pct, items[Schlüssel] = { wish, name, q, icon }), `listSel`, `recipes[Ergebnis-itemID] = { r, name, n, m = { [itemID] = Stück } }` (erlernte Rezepte, ab 0.24); `vendorFlip` entfällt ab 0.24 (wird beim Start gelöscht). `PeonBrokerDB` (accountweit): Einstellungen `minimapShow`, `minimapAngle`, `tooltipShow`, `tooltipAvg`, `tooltipVendor`, `tooltipHint`, `trendNeutral` (5 %), `trendStrong` (20 %), `undercutMode`/`undercutValue` (Einzelgegenstände, 1 Kupfer), `undercutMassMode`/`undercutMassValue` (Massenware, 0), `dumpPct` (30 %), `duration` (2/8/24 Std., Standard 8), `dataDays` (14–90, Standard 30), `windowWithAH` (aus), `windowTab`, `windowPos`, `shortMass` (an), `shortMassMin` (20), `sellOnlyProfitable` (an), `dealMinVendor` (10c), `dealMinMarket` (50s), `dealScans` (10), `dealDays` (7), `radarMaxAge` (60 Min., 0 = unbegrenzt; ersetzt `dealMaxAge`), `radarSound` (an), `radarMute` (an), `radarOrder` (smart), `radarKind` (both), `radarShowExpensive` (aus), `dealMargin` (20 %), `dealDepth` (20 %), `radarSoundKey` (raid), `radarFlash` (5 Sek.), `radarReserve` (Goldreserve in Gold, 0), `dealHold` (Markt-Schnäppchen: verkaufen innerhalb, 48 Std., 6–168, ab 0.26); `dealMinVendor` in Kupfer bis 1000g, `dealMinMarket` in Silber (ab 0.19 größere Bereiche); Daten `dataVersion` = 2, `markets["Realm / Fraktion"]` (Aufbau siehe Data.lua), `commodity` (Warenart je Gegenstand), `sellMem` (je Gegenstand: gewählte Laufzeit/Menge, zuletzt eingestellter Preis), `owned` (letzter Stand der eigenen Auktionen je Markt), `itemKeys[itemID] = "Stufe:Zusatz"` (Schlüssel des Spiels für Gegenstände, die die normale Suche nicht findet, ab 0.24; ab 0.28 für Varianten `itemKeys["itemID:voller Name"]`), `markets[…].variants[itemID] = true` (Gegenstände mit Varianten, ab 0.28), Varianten-Einträge mit `lk` (Link), `keyLog` (letzte 30 Schlüssel-Suchen; ab 0.28 wie `radarLog`, `showLog`, `aucLog`, `radarStats` nur mit `/broker debug`), `lastScanAt`, `probe`, `probeEvents`
- Braucht Peon API 8 (meldet sonst „Peon ist zu alt“).
- Befehle: `/broker` (Broker-Fenster ein/aus), `/broker optionen`, `/broker scan`, `/broker pruefen` (auch `check`), `/broker pruefen scan`, `/broker pruefen abfrage`, `/broker debug`, `/peon broker`
- Optionsseite: Minimap-Button an/aus; Broker-Fenster mit dem Auktionshaus öffnen, Knopf „Broker-Fenster öffnen“; Preise im Tooltip (an/aus, Zeile 7 Tage, Zeile Händler, Hinweise); Trend (Grenzen); Preisvorschlag (Unterbieten Massenware und Einzelgegenstände je Kupfer/Prozent, Dumping-Grenze, Laufzeit, Massenware mit vielen Angeboten 2 Std. ab X Angeboten, nur lohnende im Reiter Verkaufen); Preisdaten (Tageswerte aufbewahren, Märkte verwalten); Prüfung; Ereignis-Liste.
- Verlauf der Versionen: `docs/changelog/Peon_Broker.md`
- Hinweise „Im Spiel prüfen“ im Verlauf bei: 0.33.1, 0.28.0, 0.25.2, 0.24.0 (zusammen mit der Prüfliste erster Spieltag unter „Offene Punkte“ durchgehen)

## Peon Manager (Programm für Windows, bis 0.5.0 Peon Client) – 0.11.0

- Quellcode: `manager\` (bisher `client\`), Anleitung in `manager\README.md`. Design: `docs\konzepte\manager\Peon_Client_Design.md` (Funktionen, jetzt Modul Peon Broker Client) und `Peon_GitHub_Design.md` (Peon Manager, Module, Installieren).
- Programm bei KarloDerBaer: installiert wie bei allen anderen (ab 04.11.2026, siehe unten). Der frühere Ordner `<Programmordner>` mit Runtime und DB bleibt als Sicherung. Anderer Datenordner: Umgebungsvariable `PEON_MANAGER_DB`.
- Liest `WTF\Account\<Konto>\SavedVariables\Peon_Bridge.lua` (`PeonBridgeDB`), schreibt `AddOns\Peon_Bridge\Data.lua` (`PeonBridgeData`, Format 2, `channels` aus den aktiven Manager-Modulen).
- Manager-Module (ab 0.7.0, Variante B): Liste in `manager\src\core\modules.js`, je Modul Schlüssel, Name, Beschreibung, nötige Addons, Kanäle, Ansichten, Datenbankdatei. Erstes Modul **Peon Broker Client** (`broker-client`, Code in `broker-client.js`), standardmäßig aus, bei KarloDerBaer aktiv. Ansicht „Module“ mit Installieren, Entfernen und Daten löschen.
- Addons (ab 0.8.0, `src\core\addons.js`): Manifest des Release holen, Zip laden und prüfen, tauschen, bei Fehler zurücktauschen. Sucht beim Start und alle 6 Stunden, installiert nur per Klick. Junctions gelten als „Entwicklung (Repo)“ und bleiben unberührt, deshalb ändert der Manager bei KarloDerBaer keine Addons. Kanal Stabil oder Test in den Einstellungen. Quelle zum Testen: Umgebungsvariable `PEON_MANAGER_RELEASES`.
- Installiert (ab 0.9.0): Installer `PeonManager-Setup-<Version>.exe` für den Benutzer, ohne Administratorrechte, Programm unter `%LOCALAPPDATA%\Programs`, Daten in `%APPDATA%\Peon Manager\Daten`. Selbst-Update über `electron/updater.js`: lädt im Hintergrund, fragt vor dem Neustart. Liegt ein Ordner `DB` neben dem Programmordner (Aufbau bei KarloDerBaer), gilt dieser, und es gibt kein Selbst-Update.
- Blizzard-API (ab 0.11.0): Zugang, Anleitung und Prüfabruf unter Einstellungen für alle Module (`src\core\blizzard.js`). Einleser im Broker Client (`blizzard-import.js`), Auswahl der Häuser unter Quellen, Einstellung `blizzard.houses`. Beobachter nur in der Testfassung (`blizzard-watch.js`). Wissen und offene Fragen: `docs\konzepte\manager\Peon_Blizzard_API.md`.
- AHledger ist ab 0.11.0 entfernt.
- Bauen: `npm ci`, `npm run dist:setup` (Installer) oder `npm run dist` (nur Ordner) (Ordner `manager\release\win-unpacked`), Selbsttest mit `PEON_MANAGER_SELFTEST=<Ordner>`.
- Tests: `npm test` im Ordner `manager\` (Rechenkern, dazu der Vergleich mit Brokers Sales.lua über `tools\lua5.1.exe`).
- Verlauf der Versionen: `docs/changelog/Peon_Manager.md`

## Peon_Bridge – 0.4.0 (bis 0.3.0 Peon_Client, Verbindung zum Peon Manager)

- Design: `Peon_GitHub_Design.md` Abschnitt 4 (Bridge, Kanäle, Format von Data.lua), vorher `Peon_Client_Design.md` Bauabschnitt C1.
- Dateien: Data.lua (Platzhalter, vom Manager überschrieben, **nie mit ausgeliefert, nicht im Repo**), Locales.lua, Bridge.lua (Transport, Kanäle), Channel_Broker.lua (Kanal broker: Momentaufnahmen, Werte für Broker), Options.lua; Symbol `INV_Misc_Gear_01`. `## OptionalDeps: Peon_Broker`.
- SavedVariables: `PeonBridgeDB` (accountweit): Einstellungen `queueMax` (10, 1–30), `liveMax` (500, 0–2000, 0 = keine Live-Abfragen), `offerButton` (an), `freshDays` (7, 1–30, so lange gelten die Werte des Managers); Daten `nameFmt` (2), `fmt` (1), `queue` (wartende Momentaufnahmen, älteste zuerst), `seq`, `nameIds` (itemIDs, deren Namen der Manager schon hat), `ackAt`/`ackN` (letzte Bestätigung), `errors`. Warteschlange bleibt bei „Standardwerte“.
- Kanäle: Ein Kanal arbeitet nur, wenn `Data.lua` ihn freischaltet (`fmt = 2`, `channels.broker = true`). Ohne Freischaltung kein Zuhörer bei Broker, keine Aufzeichnung, keine Werte für Broker.
- Braucht Peon API 5 (Button, Text), Broker ab 0.30 für den Kanal broker.
- Befehle: `/peon bridge` (Optionen), `/peon bridge senden` (Reload), `/peon bridge status`, `/peon debug bridge`.
- Verlauf der Versionen: `docs/changelog/Peon_Bridge.md`
- Im Spiel prüfen (nach dem Start): Optionsseite zeigt „Kanal broker freigeschaltet“ und „Peon Manager: Werte vom … (Version 0.6.0)“.

## Peon_Ledger – 0.10.2 (neu, Bestand und Buch)

- Konzept: `Peon_Ledger_Konzept.md` (abgestimmt 02.10.2026). Bestand aller Charaktere, alle Bewegungen von Gegenständen und Gold mit Grund (nur ereignisgesteuert), Post einsammeln, Buch; Broker liest später nur daraus.
- Dateien: Locales.lua, Ledger.lua, Inventory.lua, Moves.lua, Cost.lua (ab 0.7), Tooltip.lua, Window.lua, Overview.lua, Stock.lua, History.lua, Book.lua, Catalog.lua (ab 0.10), Item.lua (ab 0.9), Pick.lua und Bindings.xml (ab 0.9.1), Probe.lua, Options.lua; Symbol `INV_Scroll_03` (bis 0.9.1 `INV_Misc_Book_09`, das nutzt schon das Dungeon-Journal)
- SavedVariables: `PeonLedgerDB` (accountweit): Einstellungen `minimapShow`, `minimapAngle`, `tooltipShow`, `windowPos`, `windowTab` (overview/stock/history/book/items), `historyMoves`, `historyOnlyMe`, `historyKind` (Filter Verlauf, ab 0.6), `bookPeriod` (today/d7/d30/all), `bookOnlyMe` (`worthEquip` ab 0.6, entfällt ab 0.7.3), ab 0.9 `itemPeriod` (7/30/90/0 = alles), `itemMarge`, `itemOff` (Linien aus), `itemLast`; ab 0.10 `catalogFilter` (all/stock/moved/ah) und `windowTab` auch `catalog`; `windowTab` auch `item`; Bewegungen „Post von Twink“ ohne bekannten Versand merken `v` (Marktwert); `lotBase` ab 0.9 je Charakter `{ untilT, chars = { [Name] = { lots, fee } }, transit }`; `realms[Realm].chars[Vorname Nachname]` = { faction, class, level, money, moneyT, seen, places = { bags, bank, mail, auctions, equip } je { t, items = { [itemID] = Stück }, slots, used (Taschen/Bank: alle/belegte Plätze ab 0.2.1; Post: used = Anhänge, Auktionen: used = laufende Auktionen ab 0.2.2), … }, start = Inventur }; `realms[Realm].account.places.warband` (Accountbank, falls vorhanden); `realms[Realm].moves` = Bewegungen { t, c = Charakter, k = Art, id, n = Stück ±, m = Kupfer ±, x = Zusatz; Beute/Benutzt mit d = Tag, s = Vorzeichen, cnt } (älteste zuerst); `realms[Realm].weeks["JJJJ-WW"]["Charakter|Art|itemID"]` = { n, m } (Einträge älter als 90 Tage); `mailLog` (erste 40 verschiedene Briefe: Absender, Betreff, Gold, Rechnung – Fehlersuche); `items[itemID]` = { n, q, i }; `bankLog` (erste 5 Bankbesuche); `probe` (Ergebnis des Prüfbefehls), `probeEvents` (je Ereignis bekannt/Anzahl/letzte Zeit/3 Beispiele), `probeHooks` (mitgelesene Aufrufe: vorhanden, mitgelesen, Anzahl, Beispiele), `probeSnaps` (automatische Schnappschüsse je Fenster, höchstens 3)
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

## Peon_Mover – 0.1.0 (neu, Fenster verschieben)

- Konzept: `Peon_Mover_Konzept.md` (abgestimmt 06.10.2026). Dateien: Locales.lua, Frames.lua, Mover.lua, Options.lua; Symbol `Ability_Rogue_Sprint`.
- SavedVariables: `PeonMoverDB` (accountweit): `enabled` (Verschieben erlaubt, Standard an), `frames[Fenstername] = { x, y, s, off }` (x/y = linke obere Ecke in UIParent-Einheiten, s = Größe, off = Mover für dieses Fenster aus). `frames` bleibt bei „Standardwerte“ erhalten.
- Braucht Peon API 7 (Liste auf der Optionsseite).
- Befehle: `/peon mover` (Optionen), `/peon mover zuruecksetzen` (alle Fenster), `/peon debug mover` (Log: eingehängte Fenster, Verschieben, Größe).
- Verlauf der Versionen: `docs/changelog/Peon_Mover.md`

## Peon_Bags – 0.2.2 (neu, Taschen, Bank, Gildenbank)

- Konzept: `Peon_Bags_Konzept.md` (abgestimmt 07.10.2026). Ersetzt Bagnon, Bagnon_Bank, Bagnon_GuildBank und BagBrother (Twinks zeigt Ledger).
- Dateien: Locales.lua, Bags.lua, Slots.lua, Window.lua, Inventory.lua, Bank.lua, Guild.lua, Options.lua; Symbol `INV_Misc_Bag_08`.
- SavedVariables: `PeonBagsDB` (accountweit): `replace` (Taschen und Bank ersetzen, an), `replaceGuild` (an), `bagCols` (10), `bagScale` (100 %), `bagLayout` (bags/type), `bagBar` (an), `bankCols`/`bankScale`/`bankLayout` (14, 100, bags), `guildCols`/`guildScale`/`guildLayout` (14, 100, bags), `quality`, `newGlow`, `junk` (an), `autoMerchant`, `autoBank`, `autoMail`, `autoAuction`, `autoTrade`, `autoGuild` (an), `pos[bag|bank|guild] = { x, y }` (bleibt bei „Standardwerte“). Spalten 6–24, Größe 50–200 % (5er).
- Braucht Peon API 6 (Auswahlliste); Bereiche für Peon_Feedback ab API 9.
- Befehle: `/peon bags` (Taschenfenster ein/aus, geht immer – auch mit Bagnon), `/peon bags optionen`, `/peon bags debug`.
- Verlauf der Versionen: `docs/changelog/Peon_Bags.md`
- Hinweise „Im Spiel prüfen“ im Verlauf bei: 0.2.2, 0.2.0 (zusammen mit der Prüfliste erster Spieltag unter „Offene Punkte“ durchgehen)

## Projektordner <Repo>

- Git-Repo, Aufbau siehe `docs\projekt\Peon_Ueberblick.md` (Wo alles liegt) und `docs\README.md`.
- `tests\`: eine Testdatei je Modul, Übersicht in `tests\README.md`. Die Tests für Peon_Feedback liegen im Archiv.
- `tools\`: lua5.1.exe (Windows), lua5.1-linux (Linux, GitHub), LUA_COPYRIGHT.txt, gebaut aus dem offiziellen Quellcode Lua 5.1.5
- `vorlage\`: Peon_Beispiel (fertiges Grundgerüst) und test_beispiel.lua
- Alte Lieferungen aus dem Chat (`eingang\`) liegen im Archiv `<Archiv>\eingang\`.

## Offene Punkte

Ideen gibt KarloDerBaer einzeln vor; sie werden hier erst eingetragen, wenn sie beschlossen sind.

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
