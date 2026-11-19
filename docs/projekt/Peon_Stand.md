# Peon: Stand je Modul

Stand: 18.11.2026. Peon 0.26.0 (API 26) / Broker 0.103.3 / Ledger 0.16.2 / Bridge 0.12.0 / Peon Manager 0.49.0 / Fishing 1.7.1 / Tooltip 0.7.5 / ClassBuddy 0.4.0 / Mover 0.1.1 / Bags 0.7.0 / Feedback 0.5.0 / Panel 0.4.1 / Profession 0.6.0 / Warhorn 0.5.2.

Je Modul stehen hier nur Version, Dateien, Daten, Befehle, Schnittstellen und was wirklich noch offen ist. Kurz halten, höchstens etwa 15 Zeilen je Modul.

- Was sich wann geändert hat, steht im Changelog `docs\changelog\<Modul>.md` (neueste oben).
- Welche Releases es gab, zeigen GitHub und `docs\releases\`.
- Hinweise „im Spiel prüfen“ kommen nicht hierher. KarloDerBaer prüft selbst, ein angefordertes normales Release gilt als geprüft (18.11.2026).
- Der frühere, lange Stand mit Verlauf und Prüfhinweisen: `docs\archiv\Peon_Stand_bis_2026-11-18.md`.
- Alle Einstellungen mit Standardwerten stehen im Code unter `defaults` bei `Peon:NewModule` (meist in der Hauptdatei des Moduls). Hier stehen nur die Daten, die man sonst schwer findet.

## Peon (Kern) – 0.26.0, API 26

- Dateien: Locales.lua, Core.lua, Feedback.lua, ItemMenu.lua, Bindings.xml, Module.lua, Options.lua, Widgets.lua, List.lua, Launcher.lua, Minimap.lua, Chart.lua, UIKit.lua, Notice.lua, Comm.lua, Profiles.lua, Slash.lua. Beispielfenster und UI-Prüfung (bis 0.24.1 `/peon ui`) liegen seit 0.25.0 im privaten Peon_Debug (`/pdebug ui`).
- SavedVariables `PeonDB`: `errors` (Fehlerspeicher, höchstens 100), `feedbackAreas`, `panelHid`, `itemMenuClick`, `noticesSeen[id]`, `profileList[Name] = { t }` (höchstens 20, immer mit „Standard“), `profileUsers["Name-Realm"] = Profil`, `profileSeed` (Stände aus 0.25.0, bis jedes Modul sie übernommen hat). `PeonCharDB` (je Charakter, ab 0.26.0): `profile`. Je Modul in der Kontotabelle: `_profile` (aktives Profil, seine Werte liegen direkt in der Tabelle), `_profiles[Name]` (die anderen), `commOff` (Teilen aus, fehlt = an), `comm` (Zähler, `peers[Prüfwert]` ohne Namen, höchstens 200, `probe`).
- Aufgaben: Modulverwaltung (`Peon:NewModule`), Einstellungen mit Standardwerten, Bereichen und Übernahme alter Namen, Ereignisse (INIT, LOGIN, COMBAT_START, COMBAT_END, RESET, CHANGED), Debug-Log, Einstellungsseite „Peon“, Bausteine für Optionsseiten.
- Schnittstellen (Kern-API, nur erweitern): Fehlerspeicher (API 12), Starter für Panel (API 14/15), Gegenstandsmenü Strg+Rechtsklick (API 16), Fenster-Bausteine `Peon.UI` (API 18, Regeln `docs\konzepte\Peon_UI_Design.md`), einmalige Hinweise `mod:AddNotice` (API 20), Rückmeldungen aus Modulen (API 22), Datenaustausch `Peon.Comm` (API 23/24, Konzept `docs\konzepte\kern\Peon_Comm_Konzept.md`), laufende Profile `Peon.Profiles` (API 25/26, „Standard“ für alle, je Charakter wählbar, `opts.noProfile` lässt ein Modul aus, Merker gehören in `keepOnReset`). Liste im Überblick unter „Kern-API“.
- Datenaustausch: versteckter Kanal `PeonNet`, an alle über den Kanal, an einen per Addon-Flüstern, keine Weitergabe (ab 0.24.1 auch nicht für Nachrichten von 0.23.0). Einmaliger Hinweis zum Teilen beim ersten Login (ab 0.24.1). Dienste: `hello` (Kern), `recipes` (Profession).
- Befehle: `/peon`, `/peon list`, `/peon fehler [leeren]`, `/peon neu`, `/peon teilen [an | aus | pruefen]`, `/peon profil [benutzen | neu | leer | kopieren | loeschen <Name> | standard]`, `/peon debug <modul>`.
- Noch nicht im Kern: `RegisterUnitEvent`.
- Offen: nach ein paar Tagen `PeonDB.comm.peers` ansehen, ob sich Peon-Nutzer kennenlernen.

## Peon_Tooltip – 0.7.5

- Dateien: Locales.lua, Tooltip.lua, Style.lua, Units.lua, Icons.lua, Items.lua, Debug.lua, Options.lua
- SavedVariables: `PeonTooltipDB`
- Funktionen: Tooltip folgt der Maus, Größe, Deckkraft, Rahmenfarbe, Spielerinfos, Kampfmodus, PvP- und Quest-Symbol, Teile im Gegenstands-Tooltip sortieren und ausblenden (Konzept `docs\konzepte\tooltip\Peon_Tooltip_Konzept.md`).
- Befehle: `/ttp` (Optionen), `/ttp reset`, `/ttp debug`, `/ttp teile`, `/ttp log`.

## Peon_ClassBuddy – 0.4.0 („Klassenbuddy“)

- Dateien: Locales.lua, ClassBuddy.lua, Rogue_ComboPoints.lua, Rogue_Poisons.lua, Warlock_Shards.lua, Options.lua, Bindings.xml. Konzept `docs\konzepte\classbuddy\Peon_ClassBuddy_Konzept.md`.
- Peon_ComboPoints ist seit 18.11.2026 aus dem Repo (Verlauf in `docs\archiv\Peon_ComboPoints_Changelog.md`). `retired` in `scripts\release.json`: Der Manager ab 0.48.0 entfernt es, sobald `cpImported` gesetzt ist.
- SavedVariables `PeonClassBuddyDB` (flach): Combo-Punkte mit den Namen aus Peon_ComboPoints, `cpImported`, Gifte `poisonOn`, `poisonMain`, `poisonOff` (`instant`, `deadly`, `crippling`, `mind`, `wound`, `none`), `poisonRenew`, `poisonCharges`, `poisonReplace`, `poisonWarn`, `poisonSound`, `poisonLow`, Seelensplitter `shardOn`, `shardRule` (`free`, `bag`, `max`), `shardRule3`, `shardMax`, `shardAction`, `shardMsg`.
- Schurke: Combo-Punkte über dem Nameplate (Code aus ComboPoints 3.5.1). Gifte mit einer Taste (sicherer Knopf `PeonClassBuddyPoison`, Makro `PeonGift`, Tastenbelegung) und Erinnerung, Panel-Eintrag mit Klick (sicherer Knopf `PeonClassBuddyPoisonPanel` über dem Symbol) und Menü je Waffe, Konzept Abschnitt 10. Optionen und Panel-Einträge nur für die eigene Klasse (`ns.ForClass`). Hexenmeister: überzählige Seelensplitter vernichten, je Zauber einer, Makro `/click PeonClassBuddyShard`, Tastenbelegung, Eintrag für Panel.
- Befehle: `/peon classbuddy`, `/peon classbuddy gifte`, `/peon classbuddy splitter`, `/peon debug classbuddy`.
- Offen: Ob das Spiel das Bestätigen beim Ersetzen eines Gifts erlaubt, zeigt der Alltag (sonst Hinweis und Blizzards Frage). Erkannt werden nur die Gifte aus der Liste in `Rogue_Poisons.lua`.

## Peon_Fishing – 1.7.1

- Dateien: Locales.lua, Fishing.lua, Sets.lua, Click.lua, Lure.lua, Keys.lua, Combat.lua, Sound.lua, Minimap.lua, Catches.lua, Options.lua, Bindings.xml
- SavedVariables: `PeonFishingDB` (Konto), `PeonFishingCharDB` (je Charakter), `dbVersion` 3.
- Funktionen: Angelmodus mit Ausrüstungswechsel, Angeln per Doppelklick oder Taste, Köder, Kampfverhalten, Ton beim Angeln, Schwimmer-Erkennung mit Warnton, Minimap-Button, Fangdatenbank je Zone.
- Tastenbelegungen: `PEON_FISHING_TOGGLE`, `PEON_FISHING_ACTION`, `CLICK PeonFishingWeaponButton:LeftButton`.
- Schnittstelle: `mod:CatchZones()` für Profession (ab 1.7.0).
- Takte: Tasten nur im Angelmodus (`ns.UpdateLureTick`), Schwarm-Zeile nur bei sichtbarer Fangliste (`ns.CatchListTick`), ab 1.7.1.
- Befehle: `/fp` (Optionen), `/fp toggle|an|aus`, `/fp set <Name>`, `/fp saveset`, `/fp kampf fragen|verlassen|bleiben`, `/fp waffenversuch`, `/fp klick doppel|aus`, `/fp status`, `/fp minimap`, `/fp koeder`, `/fp fische`, `/fp statistik`, `/fp debug`.

## Peon_Broker – 0.107.1 (Auktionshaus-Helfer)

- Konzepte: `docs\konzepte\broker\` (Konzept, Rechenmodell, Verkaufen, Einkaufen, Absatz, Umbau, Neuaufbau). Der Neuaufbau (11.11.2026) gilt, der Umbau nur noch für Tooltip, Märkte und Gegenstandsmenü.
- Dateien: siehe `Peon_Broker.toc` (43 Dateien), dazu Bindings.xml und `Media\` (Trend-Symbole, Punkt für neue Radar-Treffer).
- Fenster: ein Fenster in zwei Zuständen (am Auktionator als Reiter im Auktionshaus, unterwegs eigenes Fenster), Reiter Markt, Verkaufen, Auktionen, Einkaufen, Fokus, Beobachten, Chancen, Mehr (mit Gegenstand). Der Fokus hat zwei Modi, Aufkauf und Schnellkauf (`Quick.lua`, ab 0.104.0). Beobachten speichert die Werte je Modus und den zuletzt gespeicherten Modus (`qlim`, `qmax`, `mode` nur im Spiel, ab 0.106.0). Chancen zeigt die Chancen des Managers und die Treffer des Radars in einer Liste, mit Scan-Knopf und Auswahl (ab 0.105.0, das Radar hat keinen eigenen Reiter mehr). Sprünge „Im Markt zeigen“ und „Gegenstand“ (`Go.lua`).
- SavedVariables: `PeonBrokerDB` (Konto): Einstellungen, `markets["Realm / Fraktion"]` (Preise je Tag und Woche, Aufbau in `Data.lua`), `lists`/`listsGone` (Einkaufslisten), `watch`/`watchGone` (Beobachten), `vendors`, `cut`, `commodity`, `itemKeys`, `sellMem`, `lastPost`, `owned`, `relist`, `ratings`, `chancesGone`, `feste`, `acct` (Kennung des Kontos für den Manager), Prüfergebnisse `probe`, `probeEvents`, `ahProbe`, `calProbe`, `fieldProbe`. `PeonBrokerCharDB` (je Charakter): `lots`, `lotSeq`, `listSel`, `recipes`.
- Schnittstellen: für Ledger, Profession und Panel `mod:BuyPrice`, `mod:AhPrice`, `mod:ItemValue`, `mod:AddToList(name, mats, keepMax)`, Markt-Liste für Ledger. Nutzt Ledger (`OpenFee`, `Cost`, `StockOthers`) und Bridge (`Chances`, Preise vom Manager).
- Braucht Peon API 18.
- Prüfungen: `/broker pruefen` startet auch das Zählen der Auktionshaus-Ereignisse bis zum `/reload` (ab 0.103.2, vorher bei jedem Login).
- Befehle: `/broker`, `/broker optionen`, `/broker scan`, `/broker pruefen [scan | abfrage | beruf | ah | zeit | fehler | kalender | auktionen]`, `/broker debug`, `/peon broker`.
- Einstellen aus eigenem Knopf: nur das Lockangebot im Schnellkauf (`PostCommodity`, ab 0.104.0). Sonst bleibt Einstellen Blizzards Weg.
- Offen: `e.sp` (zuletzt vermutlich verkauft) füllt sich nur aus Brokers eigenen Beobachtungen, der Manager kennt keine Verkaufspreise. Einmaligen Hinweis `broker:umbau-2026-11` nach ein paar Versionen aus `Broker.lua` und `Locales.lua` entfernen. Vorgemerkt: „Alles Lohnende kaufen“.

## Peon Manager – 0.49.0 (Programm für Windows)

- Quellcode `manager\`, Anleitung `manager\README.md`. Design `docs\konzepte\manager\Peon_GitHub_Design.md` (Manager, Module, Installieren) und `Peon_Client_Design.md` (Funktionen des Moduls Peon Broker Client).
- Installiert für den Benutzer ohne Administratorrechte, Daten in `%APPDATA%\Peon Manager\Daten` (verlegbar unter Einstellungen, Daten). Selbst-Update über `electron/updater.js`. Anderer Datenordner zum Testen: `PEON_MANAGER_DB`, andere Release-Quelle: `PEON_MANAGER_RELEASES`.
- Addons: Manifest des Release, Zip prüfen, tauschen, bei Fehler zurück (`src\core\addons.js`). Junctions gelten als „Entwicklung (Repo)“ und bleiben unberührt. Kanal Stabil oder Test. Ersetzte Addons über `replacedBy`, abgelöste ohne Zip über `retired` im Manifest (ab 0.48.0).
- Modul **Peon Broker Client** (`broker-client`, Standard aus): eigene Arbeitsprozesse zum Schreiben, Rechnen und Lesen, SQLite `broker-client.db` (Schema 15). Liest `Peon_Bridge.lua`, schreibt `AddOns\Peon_Bridge\Data.lua`. Seiten Übersicht, Marktübersicht (mit Stabilität), Gegenstände, Chancen, Einkaufen, Beobachten, Händler, Datenlage, Erfolgskontrolle. Blizzard-API mit Zugang unter Einstellungen (`docs\konzepte\manager\Peon_Blizzard_API.md`).
- Rückmeldungen (`src\core\reports.js`): Fehler aus `Peon.lua` und `!BugGrabber.lua`, Einträge aus Peon_Feedback, Senden über den Worker `worker\peon-fehler\` in ein privates Repo. Ab 0.49.0 mit anonymer Kennung der Installation (`senderId`, im Issue „Absender …“).
- Spieldaten sichern (ab 0.48.0, `src\core\gamebackup.js`): SavedVariables `Peon*.lua` aus `WTF\Account` gepackt nach `<Datenordner>\Spielsicherung\<Datum>_<Anlass>`, vor jedem Installieren (höchstens alle 10 Minuten) und täglich, je Anlass die neuesten. Wiederherstellen nur bei geschlossenem WoW, vorher Sicherung des jetzigen Stands.
- Hilfe (ab 0.48.0): Seite aus `docs\Hilfe.md` (`views\Help.vue`, `src\renderer\markdown.js`, nur Text, kein HTML). Neue Addons brauchen dort einen Abschnitt, sonst schlägt `test\hilfe.test.js` fehl.
- Einstellungen `settings.json`: unter anderem `wowDir`, `theme`, `zoom` (Größe der Oberfläche, ab 0.47.0), `senderId` (anonyme Kennung, ab 0.49.0), `keepDays`, `hourDays`, `updateCheckMin`, `modules`.
- Bedienung: Strg und Plus, Minus, 0 sowie Strg und Mausrad ändern die Größe (ab 0.47.0). Klickbare Zeilen gehen auch mit Tab und Enter, Dialoge schließen mit Escape.
- Peon unterstützen (ab 0.49.0): Eintrag unten in der Seitenleiste und Abschnitt in der Hilfe, öffnet `https://buymeacoffee.com/karloderbaer` (in `openLink` einzeln freigegeben).
- Bauen: `npm ci`, `npm run dist:setup`. Tests: `npm test` im Ordner `manager\`.
- Offen: Grenzen der Stabilität nach vollen 14 Tagen prüfen (Ende November), dabei klären, ob die Richtung mitzählen soll. Prüfungen P1 bis P4 aus `Peon_Manager_Chancen.md`. Absatz und Prognosen lesen je rund 930 000 Vergleichszeilen (je etwa 4 Sekunden).

## Peon_Bridge – 0.12.0 (Verbindung zum Peon Manager)

- Dateien: Data.lua (vom Manager geschrieben, nie im Repo und nie ausgeliefert), Locales.lua, Bridge.lua, Channel_Broker.lua, Options.lua. Design `Peon_GitHub_Design.md` Abschnitt 4.
- SavedVariables `PeonBridgeDB` (Konto): `queueMax`, `liveMax`, `freshDays`, `queue`, `seq`, `nameIds`, `nameFmt` (3), `tipIds`, `tipBox`, `ackAt`, `ackN`, `errors`.
- Kanäle arbeiten nur, wenn `Data.lua` sie freischaltet (`fmt = 2`, `channels.broker = true`). Je Konto `accts[Kennung]`.
- Schnittstelle: `mod:Chances(market)` für Broker.
- Befehle: `/peon bridge`, `/peon bridge senden`, `/peon bridge status`, `/peon debug bridge`.

## Peon_Ledger – 0.16.2 (Bestand, Buch und Postfenster)

- Konzepte: `docs\konzepte\ledger\` (Konzept, Zuordnen, Gegenstand, Neuaufbau, Buch_AH). Es gilt der Neuaufbau (0.14.0) mit dem Buch nach `Peon_Ledger_Buch_AH.md` (0.15.0).
- Dateien: Locales.lua, Ledger.lua, Inventory.lua, Moves.lua, Cost.lua, Check.lua, Last.lua, Trend.lua, Tooltip.lua, Window.lua, Overview.lua, Stock.lua, History.lua, Book.lua, Info.lua, Mail.lua, Pick.lua, Probe.lua, Options.lua, Bindings.xml
- Fenster mit Reitern Übersicht, Bestand, Buch, Verlauf, Info. Eigenes Postfenster Peon Post (`mailWindow`).
- SavedVariables `PeonLedgerDB` (Konto): Einstellungen, `realms[Realm]` mit `chars[Vorname Nachname]` (Bestand je Ort), `moves` (Bewegungen, älteste zuerst, nach 90 Tagen in `weeks`), `bookV`, `last`, `trend`, `pre`, dazu `items`, `session`, Fehlersuche `mailLog`, `bankLog`, Prüfung `probe`, `probeEvents`, `probeHooks`, `probeSnaps`.
- Schnittstellen: `mod:Stock`, `mod:StockOthers`, `mod:Cost`, `mod:OpenFee`, `mod:SellRate`, `mod:LastBuy`, `mod:LastSale`, `mod:ShowItem`.
- Braucht Peon API 19.
- Prüfung: `/ledger pruefen` startet das Mitlesen von Ereignissen, Aufrufen und Fenstern bis zum `/reload` (ab 0.16.2, vorher bei jedem Login).
- Befehle: `/ledger`, `/ledger optionen`, `/ledger pruefen`, `/ledger <Name, Nummer oder Link>`, `/ledger debug`, `/peon ledger`.
- Offen: Nachnahme ist ausgegraut, weil der Server jeden Brief mit Nachnahme ablehnt (seit etwa 12.11.2026). `MA.COD_OFF` in `Mail.lua` wieder auf `false`, sobald Blizzard es behebt. Gildenbank wird noch nicht erfasst (Ein- und Auslagern erscheint als Verbrauch oder sonstiger Zugang). Bank wird nur bei offener Bank gelesen, bei mehr als 50 Briefen sieht das Spiel nur einen Teil. Später: Verkaufsquote (Ledger) und Absatzquote (Broker) verbinden.

## Peon_Feedback – 0.5.0 (Feedback im Spiel)

- Dateien: Locales.lua, Feedback.lua, Window.lua, Options.lua. `## OptionalDeps: Peon_Bridge`.
- SavedVariables `PeonFeedbackDB` (Konto): `entries` (id, t, module, kind, area, prio, text, char, market, zone, ver, edited, handed), `nextId`, `last`, `windowPos`, `minimapShow`, `minimapAngle`.
- Rückmeldungen im Spiel schreiben und an den Manager übergeben. Andere Module legen über `Peon.AddFeedback` Einträge an (API 22).
- Befehle: `/feedback`, `/feedback optionen`, `/peon debug feedback`.

## Peon_Mover – 0.1.1 (Fenster verschieben)

- Dateien: Locales.lua, Frames.lua, Mover.lua, Options.lua. Konzept `docs\konzepte\mover\Peon_Mover_Konzept.md`.
- SavedVariables `PeonMoverDB` (Konto): `enabled`, `frames[Fenstername] = { x, y, s, off }` (bleibt bei „Standardwerte“).
- Befehle: `/peon mover`, `/peon mover zuruecksetzen`, `/peon debug mover`.

## Peon_Panel – 0.4.1 (Leiste und Panel)

- Dateien: Locales.lua, Panel.lua, Skin.lua, Display.lua, Menu.lua, Info.lua, InfoXP.lua, InfoPlace.lua, InfoSystem.lua, InfoSocial.lua, Options.lua, `Media\corner_fill.tga` und `corner_line.tga` (aus `scripts\panel_media.js`). Konzept `docs\konzepte\panel\Peon_Panel_Konzept.md`.
- SavedVariables `PeonPanelDB` (Konto): Aussehen der Leiste (`bar…`) und des Panels (`box…`), `style`, Schrift und Farben, `entries[Starter] = { bar, box, text, side, show }`, `barOrder`, `boxOrder`, `known`, `hintShown`, `xpLog`, `session`.
- Allgemeine Einträge: XP, XP pro Stunde, Zeit bis Level-Up, Zone, Koordinaten, Haltbarkeit, Uhr, Leistung, Spielzeit, Lautstärke, Freunde, Gilde, Ruf, Reset-Zeiten.
- Braucht Peon API 15. Module melden sich als Starter (`mod:NewLauncher`).
- Befehle: `/peon panel`, `/peon debug panel`.

## Peon_Bags – 0.7.0 (Taschen, Bank, Gildenbank)

- Dateien: Locales.lua, Bags.lua, Groups.lua, Slots.lua, Window.lua, Setup.lua, Inventory.lua, Bank.lua, Guild.lua, Options.lua. Konzepte `docs\konzepte\bags\` (Konzept, Bereiche, Anordnung, Layout).
- SavedVariables `PeonBagsDB` (Konto): je Fenster (`bag`, `bank`, `guild`) Spalten, Größe, Anordnung, abgewählte Kategorien und Bereiche, eingeklappte Abschnitte, Layout (`Fill`, `Narrow`, `FreeStack`, `Empty`, `AutoCols`, `Widths`), dazu `groups` und `groupItems` (eigene Bereiche), `catOrder`, `layoutVer`, `pos`, automatisch öffnen (`auto…`).
- Braucht Peon API 7.
- Befehle: `/peon bags`, `/peon bags optionen`, `/peon bags debug`.

## Peon_Profession – 0.6.0 (Berufe)

- Konzepte: `docs\konzepte\profession\Peon_Profession_Konzept.md`, `Peon_Profession_Codex.md`.
- Dateien: siehe `Peon_Profession.toc`, dazu `Media\guide_arrow.tga` (aus `scripts\profession_media.js`). `Routes.lua` stammt aus `tools\plg_convert.lua` (MIT-Hinweis im Kopf) und wird von Hand gepflegt.
- Reiter Guide, Route, Material, Verlauf, Codex. Kosten und Gewinn im Berufsfenster (`Craft.lua`, früher Broker), Leiste am Berufsfenster.
- SavedVariables: `PeonProfessionDB` (Konto): Einstellungen, Berufsfenster (`craft…`), Messungen `colors`, `ups`, Codex `nodes`, `recipes`, `teach`, `sold`, `npcs`. `PeonProfessionCharDB` (je Charakter): `sel`, `known`, `skills`, `target`, `friends` (Rezepte von Freunden und Gilde, höchstens 200, 30 Tage).
- Braucht Peon API 18, für die Rezepte der Freunde API 24 (Dienst `recipes`). Nutzt Broker (Preise, Einkaufsliste), Ledger (Vorrat der Twinks), Fishing (`CatchZones`).
- Befehle: `/prof`, `/prof optionen`, `/prof messungen`, `/prof pruefen`, `/prof vergessen`, `/prof stellen`, `/prof freunde`, `/peon profession`, `/peon debug profession`.
- Offen: Gibt es in Forever `GetProfessionInfoByRecipeID` oder `GetTradeSkillLineForRecipe` (Ergebnis von `/prof pruefen`)? Als nächster Dienst über `Peon.Comm` die Sammelstellen (`nodes`, fremde Stellen getrennt von den eigenen). Anzeige auf Welt- und Minikarte zurückgestellt (KarloDerBaer, 17.11.2026).

## Peon_Warhorn – 0.5.2 (Gruppen, Dungeons und Raids)

- Konzept: `docs\konzepte\warhorn\Peon_Warhorn_Konzept.md`.
- Dateien: Locales.lua, Warhorn.lua, Search.lua, Filter.lua, Window.lua, Whisper.lua, Placeholders.lua, Contacts.lua, Listing.lua, Who.lua, Settings.lua, Overlay.lua, Journal.lua, Probe.lua, Options.lua, Bindings.xml
- Eigene Fläche über Blizzards Gruppensuche (Seiten Suchen, Eintragen, Wer-Liste, Einstellungen), Umschalten auf Blizzard je Seite. Neue Suche nur über Knopf oder Taste, eine Suche von selbst blockiert das Spiel.
- SavedVariables: `PeonWarhornDB` (Konto): `show`, `replace`, `whisper` (Vorlagen, Rollenwörter, Platzhalter), `contactKeep`, `hideCols`, `colors`, `probe`. `PeonWarhornCharDB` (je Charakter): Auswahl, Filter (`gFilter`, `pFilter`, `wFilter`), Eintragen (`l…`), `wText`, `contacts`.
- Braucht Peon API 18. Optional ForeverDungeonJournal (übernimmt den gesuchten Dungeon).
- Befehle: `/warhorn`, `/warhorn suchen`, `/warhorn optionen`, `/peon warhorn`, `/peon warhorn pruefen`, `/peon debug warhorn`.
- Weitere Ideen zu Dungeons und Raids gibt KarloDerBaer einzeln vor.

## Projektordner <Repo>

- Git-Repo, Aufbau siehe `docs\projekt\Peon_Ueberblick.md` (Wo alles liegt) und `docs\README.md`.
- `tests\`: eine Testdatei je Modul, dazu `test_globals.lua` (keine versehentlichen globalen Variablen, ab 18.11.2026). Übersicht in `tests\README.md`.
- `tools\`: lua5.1.exe (Windows), lua5.1-linux (Linux, GitHub), gebaut aus Lua 5.1.5.
- `vorlage\`: Peon_Beispiel (Grundgerüst) und test_beispiel.lua.
- `worker\peon-fehler\`: Cloudflare Worker für Rückmeldungen. Änderungen wirken erst nach `npx wrangler deploy` durch KarloDerBaer.

## Offene Punkte

Ideen gibt KarloDerBaer einzeln vor, sie kommen erst nach Zustimmung hierher. Hier steht nur, was beschlossen und noch nicht fertig ist. Erledigte Vorhaben stehen im Archiv `docs\archiv\Peon_Stand_bis_2026-11-18.md`.

### Aus dem Review vom 18.11.2026 (KarloDerBaer)

- Punkte 1 bis 7 und 9 erledigt (Prüfungen nur auf Befehl, README, kurzer Stand, Fehler-Worker, Datenaustausch, Prüfung der API-Angabe, globale Variablen, Tastatur und Zoom im Manager). Der Fehler-Worker muss noch hochgeladen werden (`npx wrangler deploy` in `worker\peon-fehler\`).
- Zweite Runde erledigt (18.11.2026): Sicherung der Spieldaten (Manager 0.48.0), Hilfe im Manager (`docs\Hilfe.md`), Profile im Kern (Peon 0.25.0), Beispielfenster und UI-Prüfung nach Peon_Debug, Peon_ComboPoints entfernt (Ablösung über `retired`), klare Meldung bei ausgeschaltetem Broker Client, Takte in Fishing 1.7.1.
- Nicht gemacht: Gildenbank im Ledger (KarloDerBaer hat sie nicht gewählt, erst prüfbar mit Gildenbank). Die Sprachdatei von Profession bleibt in Blöcken je Version (Umbau ohne Nutzen für Spieler). test_broker.lua bleibt eine Datei.

### Datenaustausch zwischen Peon-Nutzern

- Konzept `docs\konzepte\kern\Peon_Comm_Konzept.md`, Regeln für Module in Abschnitt 8. Gebaut: Kern (Peon 0.23/0.24), Rezepte der Freunde (Profession 0.6.0).
- Als Nächstes: Sammelstellen (Dienst `nodes`) in Profession.

### Todo: Überarbeitung (KarloDerBaer, 06.11.2026)

- Damals offen: Einkaufsliste in Broker und Manager sowie Gegenstände in Ledger. Seitdem durch den Neuaufbau von Broker und Ledger und die Angleichung des Managers ersetzt. Mit KarloDerBaer klären, ob noch etwas offen ist, sonst streichen.
