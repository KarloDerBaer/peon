# Peon: Stand je Modul

Stand: 25.11.2026. Peon 0.29.1 (API 29) / Broker 0.138.0 / Ledger 0.18.2 / Bridge 0.14.1 / Peon Manager 0.56.0 / Fishing 1.9.0 / Tooltip 0.8.0 / ClassBuddy 0.5.0 / Mover 0.1.1 / Bags 0.9.1 / Feedback 0.5.1 / Panel 0.5.0 / Profession 0.8.0 / Warhorn 0.6.0.

Je Modul stehen hier nur Version, Dateien, Daten, Befehle, Schnittstellen und was wirklich noch offen ist. Kurz halten, höchstens etwa 15 Zeilen je Modul.

- Was sich wann geändert hat, steht im Changelog `docs\changelog\<Modul>.md` (neueste oben).
- Welche Releases es gab, zeigen GitHub und `docs\releases\`.
- Hinweise „im Spiel prüfen“ kommen nicht hierher. KarloDerBaer prüft selbst, ein angefordertes normales Release gilt als geprüft (18.11.2026).
- Der frühere, lange Stand mit Verlauf und Prüfhinweisen: `docs\archiv\Peon_Stand_bis_2026-11-18.md`.
- Alle Einstellungen mit Standardwerten stehen im Code unter `defaults` bei `Peon:NewModule` (meist in der Hauptdatei des Moduls). Hier stehen nur die Daten, die man sonst schwer findet.

## Peon (Kern) – 0.29.1, API 29

- Dateien: Locales.lua, Core.lua, Feedback.lua, ItemMenu.lua, Bindings.xml, Module.lua, Options.lua, Widgets.lua, List.lua, Launcher.lua, Minimap.lua, Chart.lua, UIKit.lua, Notice.lua, Comm.lua, Profiles.lua, Slash.lua. Beispielfenster und UI-Prüfung (bis 0.24.1 `/peon ui`) liegen seit 0.25.0 im privaten Peon_Debug (`/pdebug ui`).
- SavedVariables `PeonDB`: `errors` (Fehlerspeicher, höchstens 100, „script ran too long“ ab 0.27.1 ohne Datei und Zeile als ein Fehler, ab 0.27.2 auch Adressen wie „table: 0000…“ ohne Wert), `feedbackAreas`, `panelHid`, `itemMenuClick`, `noticesSeen[id]`, `profileList[Name] = { t }` (höchstens 20, immer mit „Standard“), `profileUsers["Name-Realm"] = Profil`, `profileSeed` (Stände aus 0.25.0, bis jedes Modul sie übernommen hat). Die Altlast `uiProbe` (UI-Prüfung bis 0.24.1) löscht der Kern ab 0.29.1 beim Laden. `PeonCharDB` (je Charakter, ab 0.26.0): `profile`. Ab 0.27.0 `PeonDB.lastRealm` (letzter echter Realm-Name). Je Modul in der Kontotabelle: `_profile` (aktives Profil, seine Werte liegen direkt in der Tabelle), `_profiles[Name]` (die anderen), `commOff` (Teilen aus, fehlt = an), `comm` (Zähler, `peers[Prüfwert]` ohne Namen, höchstens 200, `probe`).
- Aufgaben: Modulverwaltung (`Peon:NewModule`), Einstellungen mit Standardwerten, Bereichen und Übernahme alter Namen, Ereignisse (INIT, LOGIN, COMBAT_START, COMBAT_END, RESET, CHANGED), Debug-Log, Einstellungsseite „Peon“, Bausteine für Optionsseiten.
- Schnittstellen (Kern-API, nur erweitern): Fehlerspeicher (API 12), Starter für Panel (API 14/15), Gegenstandsmenü Strg+Rechtsklick (API 16), Fenster-Bausteine `Peon.UI` (API 18, Regeln `docs\konzepte\Peon_UI_Design.md`), einmalige Hinweise `mod:AddNotice` (API 20), Rückmeldungen aus Modulen (API 22), Datenaustausch `Peon.Comm` (API 23/24, Konzept `docs\konzepte\kern\Peon_Comm_Konzept.md`), Realm-Name mit Rückfall `Peon.RealmName()` (API 27, das Spiel lieferte am 20.11.2026 zeitweise einen leeren Namen), Diagramm mit `trim` und `fit = false` (API 28), Hinweise als Tooltip auf Optionsseiten `NewOptionsPage({ tipHints = true })` (API 29), laufende Profile `Peon.Profiles` (API 25/26, „Standard“ für alle, je Charakter wählbar, `opts.noProfile` lässt ein Modul aus, Merker gehören in `keepOnReset`). Liste im Überblick unter „Kern-API“.
- Datenaustausch: versteckter Kanal `PeonNet`, an alle über den Kanal, an einen per Addon-Flüstern, keine Weitergabe (ab 0.24.1 auch nicht für Nachrichten von 0.23.0). Einmaliger Hinweis zum Teilen beim ersten Login (ab 0.24.1). Dienste: `hello` (Kern), `recipes` (Profession).
- Befehle: `/peon`, `/peon list`, `/peon fehler [leeren]`, `/peon neu`, `/peon teilen [an | aus | pruefen]`, `/peon profil [benutzen | neu | leer | kopieren | loeschen <Name> | standard]`, `/peon debug <modul>`.
- Noch nicht im Kern: `RegisterUnitEvent`.
- Offen: nach ein paar Tagen `PeonDB.comm.peers` ansehen, ob sich Peon-Nutzer kennenlernen.

## Peon_Tooltip – 0.8.0

- Dateien: Locales.lua, Tooltip.lua, Style.lua, Units.lua, Icons.lua, Items.lua, Debug.lua, Options.lua
- SavedVariables: `PeonTooltipDB`
- Funktionen: Tooltip folgt der Maus, Größe, Deckkraft, Rahmenfarbe, Spielerinfos, Kampfmodus, PvP- und Quest-Symbol, Teile im Gegenstands-Tooltip sortieren und ausblenden (Konzept `docs\konzepte\tooltip\Peon_Tooltip_Konzept.md`).
- Optionsseite (ab 0.8.0, Leitfaden für Einstellungen): Reiter Allgemein, Anzeige (mit beiden Beispielen und der Liste der Teile), Erweitert.
- Befehle: `/ttp` (Optionen), `/ttp reset`, `/ttp debug`, `/ttp teile`, `/ttp log`.

## Peon_ClassBuddy – 0.5.0 („Klassenbuddy“)

- Dateien: Locales.lua, ClassBuddy.lua, Rogue_ComboPoints.lua, Rogue_Poisons.lua, Warlock_Shards.lua, Options.lua, Bindings.xml. Konzept `docs\konzepte\classbuddy\Peon_ClassBuddy_Konzept.md`.
- Peon_ComboPoints ist seit 18.11.2026 aus dem Repo (Verlauf in `docs\archiv\Peon_ComboPoints_Changelog.md`). `retired` in `scripts\release.json`: Der Manager ab 0.48.0 entfernt es, sobald `cpImported` gesetzt ist.
- SavedVariables `PeonClassBuddyDB` (flach): Combo-Punkte mit den Namen aus Peon_ComboPoints, `cpImported`, Gifte `poisonOn`, `poisonMain`, `poisonOff` (`instant`, `deadly`, `crippling`, `mind`, `wound`, `none`), `poisonRenew`, `poisonCharges`, `poisonReplace`, `poisonWarn`, `poisonSound`, `poisonLow`, Seelensplitter `shardOn`, `shardRule` (`free`, `bag`, `max`), `shardRule3`, `shardMax`, `shardAction`, `shardMsg`.
- Schurke: Combo-Punkte über dem Nameplate (Code aus ComboPoints 3.5.1), nur bei echten Gegnern (`UnitIsGameObject` schließt Objekte mit Soft-Interact-Nameplate aus, ab 0.4.1). Gifte mit einer Taste (sicherer Knopf `PeonClassBuddyPoison`, Makro `PeonGift`, Tastenbelegung) und Erinnerung, Panel-Eintrag mit Klick (sicherer Knopf `PeonClassBuddyPoisonPanel` über dem Symbol) und Menü je Waffe, Konzept Abschnitt 10. Optionen und Panel-Einträge nur für die eigene Klasse (`ns.ForClass`). Hexenmeister: überzählige Seelensplitter vernichten, je Zauber einer, Makro `/click PeonClassBuddyShard`, Tastenbelegung, Eintrag für Panel.
- Optionsseite (ab 0.5.0, Leitfaden für Einstellungen): Reiter Allgemein, Anzeige (nur Schurke), Erweitert, nur mit den Teilen der eigenen Klasse.
- Befehle: `/peon classbuddy`, `/peon classbuddy gifte`, `/peon classbuddy splitter`, `/peon debug classbuddy`.
- Offen: Ob das Spiel das Bestätigen beim Ersetzen eines Gifts erlaubt, zeigt der Alltag (sonst Hinweis und Blizzards Frage). Erkannt werden nur die Gifte aus der Liste in `Rogue_Poisons.lua`.

## Peon_Fishing – 1.9.0

- Dateien: Locales.lua, Fishing.lua, Sets.lua, Click.lua, Lure.lua, Keys.lua, Combat.lua, Sound.lua, Minimap.lua, Catches.lua, Options.lua, Bindings.xml
- SavedVariables: `PeonFishingDB` (Konto), `PeonFishingCharDB` (je Charakter), `dbVersion` 3.
- Funktionen: Angelmodus mit Ausrüstungswechsel, Angeln per Doppelklick oder Taste, Köder, Kampfverhalten, Ton beim Angeln, Schwimmer-Erkennung mit Warnton, Interaktionston im Angelmodus (`interactSound`, ab 1.8.0), Minimap-Button, Fangdatenbank je Zone.
- Tastenbelegungen: `PEON_FISHING_TOGGLE`, `PEON_FISHING_ACTION`, `CLICK PeonFishingWeaponButton:LeftButton`.
- Schnittstelle: `mod:CatchZones()` für Profession (ab 1.7.0).
- Takte: Tasten nur im Angelmodus (`ns.UpdateLureTick`), Schwarm-Zeile nur bei sichtbarer Fangliste (`ns.CatchListTick`), ab 1.7.1.
- Optionsseite (ab 1.9.0, Leitfaden für Einstellungen): Reiter Allgemein, Anzeige, Erweitert, Hinweise als Tooltip. Debug nur noch über `/fp debug`.
- Befehle: `/fp` (Optionen), `/fp toggle|an|aus`, `/fp set <Name>`, `/fp saveset`, `/fp kampf fragen|verlassen|bleiben`, `/fp waffenversuch`, `/fp klick doppel|aus`, `/fp status`, `/fp minimap`, `/fp koeder`, `/fp fische`, `/fp statistik`, `/fp debug`.

## Peon_Broker – 0.138.0 (Auktionshaus-Helfer)

- Konzepte: `docs\konzepte\broker\` (Konzept, Rechenmodell, Verkaufen, Einkaufen, Absatz, Umbau, Neuaufbau, Chancen im Schnellkauf, Marktvergleich, Schlank). Der Neuaufbau (11.11.2026) gilt, der Umbau nur noch für Tooltip, Märkte und Gegenstandsmenü.
- **Schlank** (Konzept `Peon_Broker_Schlank.md`, freigegeben 24.11.2026): Fokus wird Einkaufen (nur Schnellkauf, Menge und Goldreserve, Zufluss und Abfluss sichtbar), Beobachten wird eine Liste, die Einkaufsliste zieht Gekauftes sofort ab, Seitenleiste nur mit Gegenständen aus Beobachten und Liste, Chancen zeigt nur Schnellkauf, der Rest liegt hinter „Weitere Chancen“. U0 (Lockangebot mit Menge, Knopf Einstellen rechts, ohne Zurückziehen) ist ab 0.132.0 umgesetzt, U1 (Einkaufen) ab 0.133.0: Reiter Einkaufen (Seite `focus`) nur mit Schnellkauf, Aufkauf ruht hinter `focusBuyout` (Einstellungen, Erweitert), Speichern von selbst (`F.Store`), Menge mit Regler bis „Alle“ (`qqty` in Beobachten, nur im Spiel), Goldreserve (`radarReserve`) statt Limit pro Kauf (`qgold` bleibt gespeichert, ungenutzt), Zeile Markt mit Pfeilen, Lockangebot und Mehr Einstellungen aufklappbar (`foldBait`, `foldMore`), Gegenstand und Im Markt zeigen im Rechtsklick-Menü auf den Namen. Der Reiter der Einkaufslisten heißt schon ab U1 „Listen“. U2 (Diagramm) ab 0.134.0: Knöpfe für die Linien unter dem Diagramm (`chartMin`, `chartLimit`, `chartUnder`, `chartDips`, `chartBaits`), Zeitraum 5, 15 oder 60 Minuten oben rechts (`chartRange`), eigener Verlauf im Spiel je 3 Sek. für die letzten drei Gegenstände (`Quick.Record`, `Quick.ChartSeries`, nicht gespeichert). U3 (Beobachten) ab 0.135.0: eine Liste mit Gegenstand (Hinweis Neutral bei Markttausch), Günstigster, Kaufen bis (`qlim`, mit Aufkauf ersatzweise dessen Grenze), Glocke, Treffer und Einbrüche je Stunde über `quickStatDays` (`QuickStats.Get`: `hitsPerHour`, `perHour`), Jetzt mit Punkt (`QuickStats.Now`, `Trend`, Sitzung am Auktionshaus nur im Spiel, neu nach 10 Min. zu). Darunter, Bewegung, Tief 24 Std. und Markttausch im Tooltip, laufend geprüft wird die ganze Liste (`QuickChances`, Quelle `watch`). Unterreiter und Knopf Im Markt zeigen entfallen, `watchTab`, `bon`, `qon`, `ton` bleiben gespeichert. U4 (Einkaufsliste) ab 0.136.0: Käufe zählen sofort als unterwegs (`it.way` je Listeneintrag, nur im Spiel, mitgelesen über `ConfirmCommoditiesPurchase` und `PlaceBid`), Fehlt = Brauche minus Vorrat minus unterwegs, erledigte Zeilen grau, × löscht, Regler für Brauche, Spalten Brauche, Fehlt, Höchstpreis, Günstigstes mit Hinweis Händler. Kaufzeile entfällt, Doppelklick öffnet das Einkaufen mit der fehlenden Menge (`Quick.FromList`). U5 (Seitenleiste) ab 0.137.0: `Side.lua`, rechts am Broker-Fenster und immer am Auktionshaus, Griff (`sideOpen`), Reiter Beobachten und Liste (`sideTab`, Liste mit `char.listSel`), Klick ins Einkaufen (aus der Liste über `Buy.ToShop`), Hervorhebung über `Focus.key`. U6 (Chancen) ab 0.138.0: nur Schnellkauf sichtbar, Schalter „Weitere Chancen“ (`chancesMore`, Vorgabe aus, Einstellungen der Chancen unter Erweitert) für Spekulation, Aufkauf, Markttausch und Pakete, Pakete als eine Zeile je Paket, aufklappbar (`Packages.ViewRows`, `Packages.open`). Offen: U7 (Einstellungen nach dem Leitfaden).
- Dateien: siehe `Peon_Broker.toc` (49 Dateien, ab 0.137.0 mit `Side.lua`), dazu Bindings.xml und `Media\` (Trend-Symbole, Punkt für neue Radar-Treffer).
- Fenster: ein Fenster in zwei Zuständen (am Auktionator als Reiter im Auktionshaus, unterwegs eigenes Fenster), Reiter Markt, Verkaufen, Auktionen, Einkaufen, Beobachten, Listen, Chancen, Mehr (mit Gegenstand), ab 0.133.0 in dieser Folge (vorher Einkaufen für die Listen und Fokus). Einkaufen (bis 0.132.0 Fokus) hat zwei Modi, Aufkauf und Schnellkauf (`Quick.lua`, ab 0.104.0), ab 0.133.0 ruht der Aufkauf. Beobachten speichert die Werte je Modus und den zuletzt gespeicherten Modus (`qmax`, `mode` nur im Spiel, ab 0.106.0) und hat ab 0.119.0 Unterreiter Aufkauf und Schnellkauf, ab 0.128.0 dazu Markttausch (`watchTab`). Chancen zeigt die Chancen des Managers und die Treffer des Radars (ab 0.105.0, das Radar hat keinen eigenen Reiter mehr), ab 0.119.0 in drei Unterreitern Spekulation, Aufkauf und Schnellkauf (`chancesTab`), ab 0.127.0 dazu Markttausch (`Trade.lua`, ab 0.128.2 erst nach Einschalten, `tradeOn`), ab 0.129.0 Pakete (`Packages.lua`). Laufend geprüft wird nur der offene Unterreiter. Sprünge „Im Markt zeigen“ und „Gegenstand“ (`Go.lua`).
- SavedVariables: `PeonBrokerDB` (Konto): Einstellungen, `markets["Realm / Fraktion"]` (Preise je Tag und Woche, Aufbau in `Data.lua`), `lists`/`listsGone` (Einkaufslisten), `watch`/`watchGone` (Beobachten), `vendors`, `cut`, `commodity`, `itemKeys`, `sellMem`, `lastPost`, `owned`, `relist`, `ratings`, `chancesGone`, `quickHide` (ab 0.119.0), `quickStats` (ab 0.122.0), `quickMove` (ab 0.126.0), `tradeGoods` (ab 0.127.0), `tradeGone` (ab 0.128.0), `baitQty` (Menge des Lockangebots je Gegenstand, ab 0.132.0), `feste`, `acct` (Kennung des Kontos für den Manager), Prüfergebnisse `probe`, `probeEvents`, `ahProbe`, `calProbe`, `fieldProbe`. `PeonBrokerCharDB` (je Charakter): `lots`, `lotSeq`, `listSel`, `recipes`.
- Schnittstellen: für Ledger, Profession und Panel `mod:BuyPrice`, `mod:AhPrice`, `mod:ItemValue`, `mod:AddToList(name, mats, keepMax)`, Markt-Liste für Ledger. Nutzt Ledger (`OpenFee`, `Cost`, `StockOthers`) und Bridge (`Chances`, `Compare` ab 0.127.0, Preise vom Manager).
- Braucht Peon API 18.
- Prüfungen: `/broker pruefen` startet auch das Zählen der Auktionshaus-Ereignisse bis zum `/reload` (ab 0.103.2, vorher bei jedem Login).
- Befehle: `/broker`, `/broker optionen`, `/broker scan`, `/broker pruefen [scan | abfrage | beruf | ah | zeit | fehler | kalender | auktionen]`, `/broker debug`, `/peon broker`.
- Einstellen aus eigenem Knopf: nur das Lockangebot im Schnellkauf (`PostCommodity`, ab 0.104.0, ab 0.132.0 mit Menge, ohne Knopf Zurückziehen). Sonst bleibt Einstellen Blizzards Weg.
- Marktbewegung im Schnellkauf (ab 0.108.0): über dem Diagramm Zufluss, Abfluss, Bewegung (lebhaft, mäßig, ruhig aus Einstellungen, Käufen und Preissprüngen je Minute) und was andere nach Lockangeboten zum selben Preis eingestellt haben, fremde (1 Stück, mindestens 5 % unter dem günstigsten) und eigene (ab 0.109.0). Grenzen und Dauer im Fenster Einstellungen des Fokus. Haken „Lockangebot ignorieren“ je Gegenstand: Kaufknopf und Alarm erst ab mehr als 1 Stück (ab 0.109.0). Für den Gegenstand im sichtbaren Fokus schweigt der Preisalarm aus Beobachten (ab 0.110.0).
- Chancen im Schnellkauf (ab 0.119.0, `QuickChances.lua`): Vorschläge aus der Menge im jüngsten Stand (Scan oder Manager), Prüfung der Marktbewegung je Gegenstand am Stück, gleitend über die letzten 3 Prüfungen. Dieselbe Prüfung läuft in Beobachten, Unterreiter Schnellkauf. Ab 0.120.0 werden lebhafte sofort wieder geprüft, ruhigere gleitend seltener (höchstens alle 10 Min.). Schnellkauf ohne eigene Werte: Kaufen bis die Hälfte des günstigsten Angebots, mindestens Händlerpreis, Limit pro Kauf 5 Gold. Gegenstandsmenü mit Haken „Beobachten: Aufkauf“ und „Beobachten: Schnellkauf“ (`bon`, `qon` nur im Spiel). Die Marktbewegung zählt ab 0.120.0 nur in der Kaufzone (bis 5 % über dem günstigsten), Preissprünge ab 2 %. Ab 0.122.0 Gelegenheiten langfristig (`QuickStats.lua`) über 14 Tage, im Fokus, in Chancen und in Beobachten. Ab 0.124.0 einfach gezählt (Einbrüche und Lockangebote mit beobachteter Zeit), Einbruch nur bei echtem Tief gegenüber der letzten Minute, je Stunde nur in der Spalte der Listen ab 30 Min. Beobachtung. Ab 0.126.0 Beobachten/Schnellkauf ohne Rat, Bewegung als Ampel und gespeichert (`quickMove`, blass ab 6 Std.), Spalten Treffer (bis Kaufen bis aufgetaucht), Einbrüche (Anzahl) und Tief 24 Std., Gekauft gespeichert. Zeitraum Vorgabe 7 Tage.
- Marktvergleich mit dem neutralen Haus (ab 0.127.0, Konzept `Peon_Broker_Marktvergleich.md`): Mehr, Neutral mit Suche und Absatz beider Häuser. Unterreiter Markttausch in Chancen, ab 0.128.0 nur die Auswahl des Managers (ohne ihn ein Hinweis), laufende Abfrage der offenen Liste, Entfernen nach neueren Preisen bis zum nächsten Stand. Zustand nur für das Haus, an dem man steht, Ware für das Zielhaus mit Hinweis (ab 0.128.1 aus Ledger `mod:HouseLots`). Beobachten mit Unterreiter Markttausch (`ton`), Schnellkauf und Listen ab 0.128.0 mit dem Manager abgeglichen (`t.q`, `t.lists`). Anteil des neutralen Hauses 15 % angenommen, bis Broker ihn misst.
- Pakete (ab 0.129.0, Konzept `Peon_Broker_Pakete.md`): Liste vom Manager (`bridge:Packages`), Spalte Aktion mit Kaufen (Radar `BuyStep` Art `pkg`) und Verkaufen (Massenware `PostCommodity`, Einzelstücke über den sicheren Knopf `PeonBrokerPackageSellButton` ins Verkaufsfenster). Gekauft aus Ledger `mod:HouseLots`, eingestellt aus `owned`. Eigenes Einstellen von Massenware und das Eintragen des Preises bei Einzelstücken sind im Spiel noch nicht erprobt.
- Ab 0.131.0 (Fehlermeldungen 24.11.2026): Der Schnellkauf lädt die Werte aus Beobachten einmal je Gegenstand, bevor er Vorgaben setzt (`F.EnsureLoaded`, vorher nur beim Sprung aus Beobachten, die Vorgaben überschrieben dann beim Verlassen die gespeicherten Werte). Diagramm im Schnellkauf: Mengenachse nach 90 % der Werte, Kaufen bis bestimmt die Preisachse nicht mit (Kern API 28). Markttausch zählt nur ungebundene Stücke in den Taschen. Ein Tooltip für Gegenstände überall (`W.ShowItemTooltip(owner, key, extra)`, Zusatzzeilen über `Tooltip.SetExtra`).
- Größe der SavedVariables: Das Spiel lädt höchstens etwa 262.000 verschiedene Werte je Datei. Am 20.11.2026 war `Peon_Broker.lua` mit 281.000 nicht mehr ladbar (Scan unter „? / Alliance“ bei leerem Realm-Namen), repariert. Ohne den Fehler lag die Datei bei rund 231.000. Ab 0.130.0 packt `Store.lua` beim Abmelden alle Texte eines Gegenstands in `e.x` und trennt sie beim Laden wieder (echte Datei: 108.050 Werte). Varianten speichern keinen Namen und fallen nach 7 Tagen ohne Angebot weg. Schätzung `svEst` (Hinweis ab 180.000), je Charakter `svItems` (Hinweis bei verlorenen Daten). Der Manager liest `e.x` ab 0.53.1.
- Kaufprotokoll (0.110.0 bis 0.114.1) zum Auswerten der Fehlkäufe, ab 0.115.0 aus Broker entfernt. Ab 0.118.0 nur der Anschluss `mod.traceHook` (`R.Trace`), aufgezeichnet wird im privaten Peon_Debug 0.3.0 (`/pdebug kauf`, `PeonDebugDB.brokerLog`). Erste Auswertung (19.11.2026, 13:15 bis 13:24 Uhr): Antwort auf eine Abfrage nach etwa 0,1 Sek., vom Klick bis zum Preis des Spiels 0,2 Sek., bis zum Ergebnis weitere 0,6 Sek. Code 10 folgt jedem Abbruch eines zu teuren Kaufs (`CancelCommoditiesPurchase`) und fehlgeschlagenen Käufen. Nach einem zu teuren Preis zeigen die Abfragen den Stapel noch eine Weile, obwohl ihn jemand gerade kauft. Ab 0.111.1 Versuch ohne Abbrechen bei zu teurem Preis. Offen: prüfen, ob Code 10 damit verschwindet. Ab 0.112.0 Haken „Durchschnitt zählt“ und Limit pro Kauf im Schnellkauf. Zweite Auswertung (14:33 bis 14:46 Uhr): Ohne Abbrechen kein Code 10 mehr nach zu teurem Preis. Belegte Bremse beim Klick verzögert den Kauf um 1 bis 2 Sek. (Preis 0,1 Sek. mit freier Bremse, 1,2 Sek. mit belegter). Ab 0.114.0 Pause der Abfragen, solange der Kaufknopf frei ist (1 Sek., einstellbar), danach gesperrt bis zur nächsten Antwort. Drittes Protokoll (14:50 bis 15:20 Uhr): drei Käufe gelungen, Preis nach 0,14 bis 0,18 Sek., kein Code 10. Viertes Protokoll (19:39 bis 19:54 Uhr): Mit Kaufen bis genau auf dem Lockpreis scheitern die meisten Käufe, andere sind schneller. Etwas darüber gelang die Mehrheit, ab 0.121.0 setzt der Knopf Auto Kaufen bis auf die Mitte zwischen Lockangebot und regulärem Preis. Ab 0.123.0 erkennt der Fokus Lockangebote auch über Kaufen bis (nur für Auto, gemeldet wird weiter bis Kaufen bis), Auto hebt dann an und leuchtet. Ab 0.125.0 nutzt Auto auch Einbrüche, der Fokus zeigt die Zeile Einbruch (tiefster und Anzahl) statt Letztes, den Durchschnitt hinter Gekauft und den letzten Kauf unter dem Kaufknopf. Danach entscheiden, ob der Fokus eine eigene Datei bekommt. Fünftes Protokoll (21.11.2026, 21:05 bis 21:13 Uhr, Seidenstoff): 9 bestätigte Käufe, alle fehlgeschlagen, die Bestätigung wartet nach dem Preis etwa 0,5 Sek. auf die Bremse des Spiels. Ab 0.130.2 bleibt der Fokus nach Code 10 bei „Neu laden“ (vorher kam per Suche die alte Liste mit schon verkauften Angeboten). Sechstes Protokoll (22.11.2026, 14:36 Uhr): Das Spiel verwarf den Start eines Kaufs in seiner Warteschlange, der Kauf hing 20 Sek. ohne Abfragen. Ab 0.130.3 sofort beendet, Wartezeit auf den Preis höchstens 3 Sek.
- Offen: `e.sp` (zuletzt vermutlich verkauft) füllt sich nur aus Brokers eigenen Beobachtungen, der Manager kennt keine Verkaufspreise. Vorgemerkt: „Alles Lohnende kaufen“.

## Peon Manager – 0.56.0 (Programm für Windows)

- Quellcode `manager\`, Anleitung `manager\README.md`. Design `docs\konzepte\manager\Peon_GitHub_Design.md` (Manager, Module, Installieren) und `Peon_Client_Design.md` (Funktionen des Moduls Peon Broker Client).
- Installiert für den Benutzer ohne Administratorrechte, Daten in `%APPDATA%\Peon Manager\Daten` (verlegbar unter Einstellungen, Daten). Selbst-Update über `electron/updater.js`. Anderer Datenordner zum Testen: `PEON_MANAGER_DB`, andere Release-Quelle: `PEON_MANAGER_RELEASES`.
- Addons: Manifest des Release, Zip prüfen, tauschen, bei Fehler zurück (`src\core\addons.js`). Junctions gelten als „Entwicklung (Repo)“ und bleiben unberührt. Kanal Stabil oder Test. Ersetzte Addons über `replacedBy`, abgelöste ohne Zip über `retired` im Manifest (ab 0.48.0).
- Modul **Peon Broker Client** (`broker-client`, Standard aus): eigene Arbeitsprozesse zum Schreiben, Rechnen und Lesen, SQLite `broker-client.db` (Schema 15). Liest `Peon_Bridge.lua`, schreibt `AddOns\Peon_Bridge\Data.lua`. Seitenleiste ab 0.56.0 mit sechs Einträgen und Unterreitern (`Peon_Manager_Schlank.md`): Heute (`Today.vue`), Chancen (Spekulation, Marktvergleich, Pakete, Erfolg), Listen (Einkaufslisten, Beobachten), Markt (Übersicht mit Kennzahlen aus `MarketSummary.vue` und Stabilität, Gegenstände, Händler), Addons, Mehr (Datenlage, Rückmeldungen, Hilfe, Einstellungen mit Allgemein und Erweitert). Seiten Chancen, Marktvergleich (ab 0.50.0, `compare.js`, `compare-client.js`, `views\Compare.vue`, Regeln in `meta.compareRules`, ab 0.51.0 die besten `top` an Broker, ab 0.52.0 Einstellgebühr, Lücken im Ziel, Diagramm im Reiter Neutral, Erfolgskontrolle mit `meta.compareLog`, ab 0.53.0 Pakete `packages.js` mit `meta.pkgLog` und `meta.pkgExclude`), Einkaufen, Beobachten (ab 0.51.0 Unterreiter Aufkauf, Schnellkauf, Markttausch), Händler (ab 0.51.0 wieder an), Datenlage, Erfolgskontrolle (ab 0.55.0 nur streng erkannte Verkäufe mit der vorgeschlagenen Menge, `Peon_Manager_Chancen.md` 8.1). Blizzard-API mit Zugang unter Einstellungen (`docs\konzepte\manager\Peon_Blizzard_API.md`).
- Rückmeldungen (`src\core\reports.js`): Fehler aus `Peon.lua` und `!BugGrabber.lua`, Einträge aus Peon_Feedback, Senden über den Worker `worker\peon-fehler\` in ein privates Repo. Ab 0.49.0 mit anonymer Kennung der Installation (`senderId`, im Issue „Absender …“). Ab 0.54.0 Kennung eines Fehlers ohne wechselnde Teile (`errorText`, wie Kern und Worker) und gleiche Fehler beim Senden als eine Meldung mit Anzahl (`errorGroups`).
- Spieldaten sichern (ab 0.48.0, `src\core\gamebackup.js`): SavedVariables `Peon*.lua` aus `WTF\Account` gepackt nach `<Datenordner>\Spielsicherung\<Datum>_<Anlass>`, vor jedem Installieren (höchstens alle 10 Minuten) und täglich, je Anlass die neuesten. Wiederherstellen nur bei geschlossenem WoW, vorher Sicherung des jetzigen Stands.
- Hilfe (ab 0.48.0): Seite aus `docs\Hilfe.md` (`views\Help.vue`, `src\renderer\markdown.js`, nur Text, kein HTML). Neue Addons brauchen dort einen Abschnitt, sonst schlägt `test\hilfe.test.js` fehl.
- Einstellungen `settings.json`: unter anderem `wowDir`, `theme`, `zoom` (Größe der Oberfläche, ab 0.47.0), `senderId` (anonyme Kennung, ab 0.49.0), `keepDays`, `hourDays`, `updateCheckMin`, `modules`, `navSubs` (zuletzt gewählter Unterreiter je Eintrag, ab 0.56.0). Ab 0.56.0 zwei Reiter Allgemein und Erweitert, der Kanal steht unter Allgemein, die Blizzard-API prüft sich ohne Knopf von selbst.
- Bedienung: Strg und Plus, Minus, 0 sowie Strg und Mausrad ändern die Größe (ab 0.47.0). Klickbare Zeilen gehen auch mit Tab und Enter, Dialoge schließen mit Escape.
- Peon unterstützen (ab 0.49.0): Eintrag unten in der Seitenleiste und Abschnitt in der Hilfe, öffnet `https://buymeacoffee.com/karloderbaer` (in `openLink` einzeln freigegeben).
- Bauen: `npm ci`, `npm run dist:setup`. Tests: `npm test` im Ordner `manager\`.
- Meldung von Windows bei neuen Daten (ab 0.55.0, `dataNotify`, Standard aus, Einstellungen, Allgemein): nach jedem ausgewerteten Stand der API und nach neuen Scans.
- Offen: Horde-Haus (vermutlich 114) unter Quellen wählen und nach 1 bis 2 Wochen messen, ob es steigende oder fallende Preise im neutralen Haus ankündigt (`Peon_Blizzard_API.md`). Ab etwa 9.12.2026 sind die belegten Verkaufspreise ganz streng, dann Erfolgskontrolle und Zahl der Chancen ansehen. Prüfungen P1 bis P4 aus `Peon_Manager_Chancen.md`. Absatz und Prognosen lesen je rund 930 000 Vergleichszeilen (je etwa 4 Sekunden).

## Peon_Bridge – 0.14.1 (Verbindung zum Peon Manager)

- Dateien: Data.lua (vom Manager geschrieben, nie im Repo und nie ausgeliefert), Locales.lua, Bridge.lua, Channel_Broker.lua, Options.lua. Design `Peon_GitHub_Design.md` Abschnitt 4.
- SavedVariables `PeonBridgeDB` (Konto): `queueMax`, `liveMax`, `freshDays`, `queue`, `seq`, `nameIds`, `nameFmt` (3), `tipIds` (höchstens 40.000, darüber von vorn, ab 0.14.1), `tipBox`, `ackAt`, `ackN`, `errors`.
- Kanäle arbeiten nur, wenn `Data.lua` sie freischaltet (`fmt = 2`, `channels.broker = true`). Je Konto `accts[Kennung]`.
- Schnittstelle: `mod:Chances(market)` und ab 0.13.0 `mod:Compare(market)` (Marktvergleich, `markets[Heimat].cmp`), ab 0.14.0 `mod:Packages(market)` (`markets[Heimat].pkg`) für Broker.
- Befehle: `/peon bridge`, `/peon bridge senden`, `/peon bridge status`, `/peon debug bridge`.

## Peon_Ledger – 0.18.2 (Charaktere, Buch und Postfenster)

- Konzepte: `docs\konzepte\ledger\` (Konzept, Zuordnen, Gegenstand, Neuaufbau, Buch_AH, Schlank). Es gilt der Neuaufbau (0.14.0) mit dem Buch nach `Peon_Ledger_Buch_AH.md` (0.15.0) und der Oberfläche nach `Peon_Ledger_Schlank.md` (0.18.0, S1, S2, S4, S5).
- Dateien: Locales.lua, Ledger.lua, Inventory.lua, Moves.lua, Cost.lua, Check.lua, Last.lua, Trend.lua, Tooltip.lua, Window.lua, Overview.lua, Chars.lua, History.lua, Book.lua, Info.lua, Mail.lua, Pick.lua, Probe.lua, Options.lua, Bindings.xml
- Fenster mit Reitern Übersicht, Charaktere, Buch, Verlauf, Info. Eigenes Postfenster Peon Post (`mailWindow`).
- Übersicht (ab 0.18.0): Kacheln Gold gesamt, Gold 24 Std., AH-Erlös heute. Charakterliste mit Spalte 24 Std., Klick öffnet den Charakter. Diagramm mit Menü „Linien“ (`trendLines`: Gold, AH-Erlös, Handelsgewinn geschätzt, Gold je Charakter).
- Charaktere (ab 0.18.0): Orte je Charakter zum Aufklappen, Suche über alle Charaktere, Knöpfe „Taschen in Bags“ und „Bank in Bags“ (Peon_Bags `ShowSaved`).
- Verlauf (ab 0.18.0): nach Tagen, Filter als Knöpfe mit Vorgabe „Wichtiges“, Umbuchungen erst mit Haken, Sprung aus dem Buch (Klick auf eine Zeile „Nach Art“).
- Einstellungen (ab 0.18.0) nach dem Leitfaden: Allgemein, Anzeige, Erweitert.
- SavedVariables `PeonLedgerDB` (Konto): Einstellungen, `realms[Realm]` mit `chars[Vorname Nachname]` (Bestand je Ort), `moves` (Bewegungen, älteste zuerst, nach 90 Tagen in `weeks`, ab 0.17.0 Haus `h` bei Bewegungen im Auktionshaus), `bookV`, `last`, `trend`, `pre`, dazu `items`, `session`, Fehlersuche `mailLog`, `bankLog`, Prüfung `probe`, `probeEvents`, `probeHooks`, `probeSnaps`.
- Schnittstellen: `mod:Stock`, `mod:StockOthers`, `mod:Cost`, `mod:OpenFee`, `mod:SellRate`, `mod:LastBuy`, `mod:LastSale`, `mod:ShowItem`, `mod:HouseLots` (ab 0.17.0).
- Kontrollrechnung (ab 0.18.1): vergleicht nur Taschen, Bank und Angelegtes, die Ware im Auktionshaus folgt aus den Bewegungen statt aus der Liste des Spiels. Einmaliger Nachtrag alter Abweichungen nach dem Einstellen (`fixSoldDiff`).
- Kostenrechnung: Beute, Benutzt, Quest und Zerstört trägt Ledger ab 0.17.2 in den gespeicherten Stand nach (`Cost.Add`), alles andere rechnet 2 Sekunden später im Hintergrund neu (ab 0.17.1). Im Kampf zeigt der Tooltip den letzten Stand. Marktwerte fragt eine Rechnung je Gegenstand nur einmal.
- Käufe im Auktionshaus (ab 0.17.3): Zahlungen gehören zum bestätigten Kauf mit gleichem Gesamtpreis (`M.buys`), Ware aus der Post trägt den Durchschnitt der offenen Käufe des Gegenstands.
- Panel-Texte: Gold aller Charaktere, Gold dieses Charakters, Gold dieser Sitzung, ab 0.17.3 Gold dieses Charakters mit allen in Klammern.
- Markttausch (ab 0.17.0): Posten aus Auktionskäufen tragen das Haus, ein Verkauf im anderen Haus zählt im Buch als „davon Markttausch“.
- Braucht Peon API 19.
- Prüfung: `/ledger pruefen` startet das Mitlesen von Ereignissen, Aufrufen und Fenstern bis zum `/reload` (ab 0.16.2, vorher bei jedem Login).
- Befehle: `/ledger`, `/ledger optionen`, `/ledger pruefen`, `/ledger <Name, Nummer oder Link>`, `/ledger debug`, `/peon ledger`.
- Offen: Nachnahme ist ausgegraut, weil der Server jeden Brief mit Nachnahme ablehnt (seit etwa 12.11.2026). `MA.COD_OFF` in `Mail.lua` wieder auf `false`, sobald Blizzard es behebt. Gildenbank wird noch nicht erfasst (Ein- und Auslagern erscheint als Verbrauch oder sonstiger Zugang). Bank wird nur bei offener Bank gelesen, bei mehr als 50 Briefen sieht das Spiel nur einen Teil. Später: Verkaufsquote (Ledger) und Absatzquote (Broker) verbinden.

## Peon_Feedback – 0.5.1 (Feedback im Spiel)

- Dateien: Locales.lua, Feedback.lua, Window.lua, Options.lua. `## OptionalDeps: Peon_Bridge`.
- SavedVariables `PeonFeedbackDB` (Konto): `entries` (id, t, module, kind, area, prio, text, char, market, zone, ver, edited, handed), `nextId`, `last`, `windowPos`, `minimapShow`, `minimapAngle`.
- Rückmeldungen im Spiel schreiben und an den Manager übergeben. Andere Module legen über `Peon.AddFeedback` Einträge an (API 22).
- Befehle: `/feedback`, `/feedback optionen`, `/peon debug feedback`.

## Peon_Mover – 0.1.1 (Fenster verschieben)

- Dateien: Locales.lua, Frames.lua, Mover.lua, Options.lua. Konzept `docs\konzepte\mover\Peon_Mover_Konzept.md`.
- SavedVariables `PeonMoverDB` (Konto): `enabled`, `frames[Fenstername] = { x, y, s, off }` (bleibt bei „Standardwerte“).
- Befehle: `/peon mover`, `/peon mover zuruecksetzen`, `/peon debug mover`.

## Peon_Panel – 0.5.0 (Leiste und Panel)

- Dateien: Locales.lua, Panel.lua, Skin.lua, Display.lua, Menu.lua, Info.lua, InfoXP.lua, InfoPlace.lua, InfoSystem.lua, InfoSocial.lua, Options.lua, `Media\corner_fill.tga` und `corner_line.tga` (aus `scripts\panel_media.js`). Konzept `docs\konzepte\panel\Peon_Panel_Konzept.md`.
- SavedVariables `PeonPanelDB` (Konto): Aussehen der Leiste (`bar…`) und des Panels (`box…`), `style`, Schrift und Farben, `entries[Starter] = { bar, box, text, side, show }`, `barOrder`, `boxOrder`, `known`, `hintShown`, `xpLog`, `session`.
- Allgemeine Einträge: XP, XP pro Stunde, Zeit bis Level-Up, Zone, Koordinaten, Haltbarkeit, Uhr, Leistung, Spielzeit, Lautstärke, Freunde, Gilde, Ruf, Reset-Zeiten.
- Braucht Peon API 15. Module melden sich als Starter (`mod:NewLauncher`).
- Optionsseite (ab 0.5.0, Leitfaden für Einstellungen): Reiter Allgemein mit der Liste der Einträge, Anzeige, Erweitert.
- Befehle: `/peon panel`, `/peon debug panel`.

## Peon_Bags – 0.9.1 (Taschen, Bank, Gildenbank)

- Dateien: Locales.lua, Bags.lua, Groups.lua, Slots.lua, Window.lua, Setup.lua, Inventory.lua, Bank.lua, Guild.lua, Saved.lua, Options.lua. Konzepte `docs\konzepte\bags\` (Konzept, Bereiche, Anordnung, Layout), gespeicherte Ansicht in `docs\konzepte\ledger\Peon_Ledger_Schlank.md` Abschnitt 3.3.
- SavedVariables `PeonBagsDB` (Konto): je Fenster (`bag`, `bank`, `guild`) Spalten, Größe, Anordnung, abgewählte Kategorien und Bereiche, eingeklappte Abschnitte, Layout (`Fill`, `Narrow`, `FreeStack`, `Empty`, `AutoCols`, `Widths`), dazu `groups` und `groupItems` (eigene Bereiche), `catOrder`, `layoutVer`, `pos`, automatisch öffnen (`auto…`).
- SavedVariables `PeonBagsSaved` (Konto, ab 0.8): `realms[Realm][Charakter]` mit `level`, `class`, `guild`, `money`, `bags` und `bank` (je `t` = Zeit und `list` = Taschen mit `id`, `n` Plätze, `f` Taschenart, `kind`, je Platz Text „Gegenstand,Stück,Qualität[,Name]“).
- Schnittstelle (ab 0.8): `bags:ShowSaved(name, ort)` (`ort` = `bags`, `bank`, `guild`), `bags:HasSaved(name, ort)`, `bags:SavedChars()`. Name mit Nachname wie in Ledger.
- Schlüsselbund aus `KEYRING_CONTAINER` (Forever −1) als eigener Abschnitt der Taschen, nie Teil der Bank.
- Braucht Peon API 11 (Reiter), Hinweise als Tooltip ab API 29.
- Optionsseite (ab 0.9.0, Leitfaden für Einstellungen): Reiter Allgemein, Anzeige, Erweitert. Eigene Bereiche nur im Fenster über „Einstellen“.
- Befehle: `/peon bags`, `/peon bags optionen`, `/peon bags debug`.
- Offen: Gildenbank speichern und zeigen (Ledger-Konzept S6, erst wenn mit einer Gildenbank prüfbar). Ledger 0.18.0 nutzt `ShowSaved` und `HasSaved` für Taschen und Bank.

## Peon_Profession – 0.8.0 (Berufe)

- Konzepte: `docs\konzepte\profession\Peon_Profession_Konzept.md`, `Peon_Profession_Codex.md`.
- Dateien: siehe `Peon_Profession.toc`, dazu `Media\guide_arrow.tga` (aus `scripts\profession_media.js`). `Routes.lua` stammt aus `tools\plg_convert.lua` (MIT-Hinweis im Kopf) und wird von Hand gepflegt.
- Reiter Guide, Route, Material, Verlauf, Codex. Kosten und Gewinn im Berufsfenster (`Craft.lua`, früher Broker), Leiste am Berufsfenster.
- Alt + Klick in der Tasche (`AltClick.lua`, ab 0.7.0): Entzaubern (Waffen und Rüstung ab grün) und Schlossknacken (verschlossene Kassetten, Schurke, auch im Feld „Wird nicht gehandelt“ des Handelsfensters) über einen sicheren Knopf an der Stelle des Platzes (nicht daran gehängt, Schicht DIALOG, wirkt beim Loslassen, ab 0.7.3). Debug-Zeilen zu Maus, Klick und Knopf mit `/peon debug profession`. Einstellung `altClick`.
- SavedVariables: `PeonProfessionDB` (Konto): Einstellungen, Berufsfenster (`craft…`), Messungen `colors`, `ups`, Codex `nodes`, `recipes`, `teach`, `sold`, `npcs`. `PeonProfessionCharDB` (je Charakter): `sel`, `known`, `skills`, `target`, `friends` (Rezepte von Freunden und Gilde, höchstens 200, 30 Tage).
- Braucht Peon API 18, für die Rezepte der Freunde API 24 (Dienst `recipes`). Nutzt Broker (Preise, Einkaufsliste), Ledger (Vorrat der Twinks), Fishing (`CatchZones`).
- Optionsseite (ab 0.8.0, Leitfaden für Einstellungen): Reiter Allgemein und Anzeige. Kosten und Gewinn im Berufsfenster nur im Zahnrad am Block.
- Befehle: `/prof`, `/prof optionen`, `/prof messungen`, `/prof pruefen`, `/prof vergessen`, `/prof stellen`, `/prof freunde`, `/peon profession`, `/peon debug profession`.
- Offen: Gibt es in Forever `GetProfessionInfoByRecipeID` oder `GetTradeSkillLineForRecipe` (Ergebnis von `/prof pruefen`)? Als nächster Dienst über `Peon.Comm` die Sammelstellen (`nodes`, fremde Stellen getrennt von den eigenen). Anzeige auf Welt- und Minikarte zurückgestellt (KarloDerBaer, 17.11.2026).

## Peon_Warhorn – 0.6.0 (Gruppen, Dungeons und Raids)

- Konzept: `docs\konzepte\warhorn\Peon_Warhorn_Konzept.md`.
- Dateien: Locales.lua, Warhorn.lua, Search.lua, Filter.lua, Window.lua, Whisper.lua, Placeholders.lua, Contacts.lua, Listing.lua, Who.lua, Settings.lua, Overlay.lua, Journal.lua, Probe.lua, Options.lua, Bindings.xml
- Eigene Fläche über Blizzards Gruppensuche (Seiten Suchen, Eintragen, Wer-Liste, Einstellungen), Umschalten auf Blizzard je Seite. Neue Suche nur über Knopf oder Taste, eine Suche von selbst blockiert das Spiel. Blockiert das Spiel eine Suche trotzdem, zeigt die Statuszeile einen Hinweis auf den Knopf Suchen.
- SavedVariables: `PeonWarhornDB` (Konto): `show`, `replace`, `whisper` (Vorlagen, Rollenwörter, Platzhalter), `contactKeep`, `hideCols`, `colors`, `probe`. `PeonWarhornCharDB` (je Charakter): Auswahl, Filter (`gFilter`, `pFilter`, `wFilter`), Eintragen (`l…`), `wText`, `contacts`.
- Braucht Peon API 18. Optional ForeverDungeonJournal (übernimmt den gesuchten Dungeon).
- Optionsseite (ab 0.6.0, Leitfaden für Einstellungen): nur Allgemein mit Knopf „Gruppensuche öffnen“ und dem Schalter `show`. Die Prüfung läuft über `/peon warhorn pruefen`, alle weiteren Einstellungen stehen im Fenster.
- Befehle: `/warhorn`, `/warhorn suchen`, `/warhorn optionen`, `/peon warhorn`, `/peon warhorn pruefen`, `/peon debug warhorn`.
- Weitere Ideen zu Dungeons und Raids gibt KarloDerBaer einzeln vor.

## Projektordner <Repo>

- Git-Repo, Aufbau siehe `docs\projekt\Peon_Ueberblick.md` (Wo alles liegt) und `docs\README.md`.
- `tests\`: eine Testdatei je Modul, dazu `test_globals.lua` (keine versehentlichen globalen Variablen, ab 18.11.2026). Übersicht in `tests\README.md`.
- `tools\`: lua5.1.exe (Windows), lua5.1-linux (Linux, GitHub), gebaut aus Lua 5.1.5.
- `vorlage\`: Peon_Beispiel (Grundgerüst) und test_beispiel.lua.
- `worker\peon-fehler\`: Cloudflare Worker für Rückmeldungen. Änderungen wirken erst nach `npx wrangler deploy` durch KarloDerBaer. Offen: Stand vom 24.11.2026 hochladen (Kennung ohne wechselnde Teile, Verzeichnis der offenen Issues statt Suche, Bündeln je Sendung, Grenze von 50 Abrufen je Anfrage beachtet).

## Offene Punkte

Ideen gibt KarloDerBaer einzeln vor, sie kommen erst nach Zustimmung hierher. Hier steht nur, was beschlossen und noch nicht fertig ist. Erledigte Vorhaben stehen im Archiv `docs\archiv\Peon_Stand_bis_2026-11-18.md`.

### Aus dem Review vom 18.11.2026 (KarloDerBaer)

- Punkte 1 bis 7 und 9 erledigt (Prüfungen nur auf Befehl, README, kurzer Stand, Fehler-Worker, Datenaustausch, Prüfung der API-Angabe, globale Variablen, Tastatur und Zoom im Manager). Der Fehler-Worker muss noch hochgeladen werden (`npx wrangler deploy` in `worker\peon-fehler\`).
- Zweite Runde erledigt (18.11.2026): Sicherung der Spieldaten (Manager 0.48.0), Hilfe im Manager (`docs\Hilfe.md`), Profile im Kern (Peon 0.25.0), Beispielfenster und UI-Prüfung nach Peon_Debug, Peon_ComboPoints entfernt (Ablösung über `retired`), klare Meldung bei ausgeschaltetem Broker Client, Takte in Fishing 1.7.1.
- Nicht gemacht: Gildenbank im Ledger (KarloDerBaer hat sie nicht gewählt, erst prüfbar mit Gildenbank). Die Sprachdatei von Profession bleibt in Blöcken je Version (Umbau ohne Nutzen für Spieler). test_broker.lua bleibt eine Datei.

### Datenmengen (Messung 25.11.2026)

- SavedVariables (Grenze etwa 262.000 verschiedene Werte je Datei): Broker 34,8 MB mit 121.000 Werten (57.000 Gegenstände in zwei Märkten), Bridge 2,7 MB mit 41.000, Ledger 1,2 MB mit 17.500 (7.800 Bewegungen seit 12.11., im Schnitt 560 am Tag, nach 90 Tagen etwa 87.000 Werte), Kern 1,4 MB (Altlast `uiProbe`, ab 0.29.1 gelöscht). Alle anderen unter 60 KB.
- Broker mit echten Daten: Packen beim Abmelden 0,5 Sek., Entpacken beim Laden 0,25 Sek. Kein Modul verteilt lange Rechnungen auf mehrere Frames, Broker läuft an 15 Stellen über alle Gegenstände eines Markts (Thema für den Broker-Umbau).
- Manager-DB `broker-client.db` 2,1 GB, alle Aufräumregeln greifen, wächst noch bis etwa 2,6 GB (Stundenwerte 28 Tage, Absatz 30 Tage).

### Datenaustausch zwischen Peon-Nutzern

- Konzept `docs\konzepte\kern\Peon_Comm_Konzept.md`, Regeln für Module in Abschnitt 8. Gebaut: Kern (Peon 0.23/0.24), Rezepte der Freunde (Profession 0.6.0).
- Als Nächstes: Sammelstellen (Dienst `nodes`) in Profession.

### Todo: Überarbeitung (KarloDerBaer, 06.11.2026)

- Damals offen: Einkaufsliste in Broker und Manager sowie Gegenstände in Ledger. Seitdem durch den Neuaufbau von Broker und Ledger und die Angleichung des Managers ersetzt. Mit KarloDerBaer klären, ob noch etwas offen ist, sonst streichen.
