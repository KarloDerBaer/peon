# Peon Manager (bisher Programm Peon Client): Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 0.57.0

Kurz: Live-Abfragen aus dem Spiel speichert der Manager nur noch einmal je Gegenstand und Stunde. Im Diagramm steht je Stunde eine Raute mit dem günstigsten Preis. Das spart viel Platz, vor allem nach langem Limitkauf.

- 0.57.0 (28.11.2026, Pflege der Datenmengen, Zustimmung KarloDerBaer):
  - **Ursache:** Jede Live-Abfrage aus Broker landete einzeln samt Angeboten in der Datenbank und als Raute im Diagramm. Messung mit echten Daten: 34.928 Abfragen in 7 Tagen, 23 MB Angebote, 17.694 davon für einen Gegenstand. Gebraucht werden seit 0.40.0 nur der letzte Stand und im Diagramm der günstigste Preis.
  - **Geändert, Schema 16** (`db.js`): neue Spalte `item_snap.low` (günstigster Stückpreis der Stunde, nur Live, `min` bleibt der letzte Stand) und Tabelle `live_ids` (Nummern zusammengefasster Abfragen, gelten als bekannt und werden der Bridge weiter bestätigt, `game.knownId`). Einmalige Umstellung `migrateLiveHourly` (meta `liveHourly`). Mit einer Kopie der echten Daten: aus 34.928 Abfragen werden 1.069, aus 23 MB etwa 0,4 MB, Dauer 0,3 Sek.
  - **Geändert, Zusammenfassen beim Aufräumen** (`db.mergeLiveHours`, `retention.dropOld`): je Markt, Gegenstand und Stunde bleibt die neueste Abfrage, die laufende Stunde bleibt unberührt. Nicht beim Einlesen, weil der Zwischenspeicher (`snapindex.js`) sonst jedes Mal alles neu lesen müsste. `live_ids` fallen nach 7 Tagen weg wie die Abfragen.
  - **Geändert, Diagramm** (`ItemChart.vue`): Reihe „Live (Min je Std.)“, eine Raute je Stunde mit dem günstigsten Preis (`low`, sonst `min`).
  - **Behoben, Datenlage** (`Sources.vue`): Live-Abfragen zählen seit 0.40.0 nicht für den Absatz, die Übersicht sagte noch „Ergänzt“. Jetzt Verlauf „Je Std.“, Absatz „Nein“, gezählt werden Stundenwerte (auch in `status.js` und `Item.vue`).
  - Gehört zu Bridge 0.15.0 (`e.low`). Tests: `live-stunde.test.js` (low aus der Bridge, Zusammenfassen, laufende Stunde, leere Abfrage, bekannte Nummern, Umstellung).

## 0.56.0

Kurz: Der Manager ist aufgeräumt. Die Seitenleiste hat nur noch sechs Einträge: Heute, Chancen, Listen, Markt, Addons und Mehr. Die einzelnen Seiten stehen als Reiter oben. Die neue Startseite Heute zeigt nur, was gerade zu tun ist. Die Einstellungen haben die Reiter Allgemein und Erweitert.

- 0.56.0 (25.11.2026, Konzept `Peon_Manager_Schlank.md` M1 bis M4):
  - **Neu, Seitenleiste** (`App.vue`, `SECTIONS`): Heute, Chancen (Spekulation, Marktvergleich, Pakete, Erfolg), Listen (Einkaufslisten, Beobachten), Markt (Übersicht, Gegenstände, Händler), Addons, Mehr (Datenlage, Rückmeldungen, Hilfe, Einstellungen). Unterreiter als Reiterleiste oben, der zuletzt gewählte bleibt je Eintrag gemerkt (Einstellung `navSubs`). Ohne Broker Client nur Heute, Addons und Mehr. Alte Sprünge zeigen auf den neuen Platz (`MOVED`). Die Auswahl des Markts steht oben in der Leiste, offene Gegenstände unter ihrem Eintrag.
  - **Neu, Startseite Heute** (`views\Today.vue`): Karten Updates, Daten (Ampel und nicht gesendete Rückmeldungen), Lohnt sich jetzt (die fünf besten aus Spekulation, Marktvergleich und Pakete, je mit Sprung) und Meine Listen. Jede Karte nur, wenn sie etwas zu sagen hat. Die Einrichtungsliste steht darüber.
  - **Geändert, Markt:** Kacheln, Diagramm, Stabilität, Meistverkauft und größte Preisänderungen der alten Übersicht sind der erste Reiter der Marktübersicht (`views\MarketSummary.vue`, vorher `Overview.vue`). Die Liste aller Gegenstände ist ein eigener Unterreiter Gegenstände.
  - **Geändert, Pakete** eigener Unterreiter unter Chancen (`Compare.vue` mit `packages`), nicht mehr Reiter im Marktvergleich.
  - **Geändert, Einstellungen** nach dem Leitfaden: Allgemein mit WoW-Ordner, Kanal, Aussehen, Größe und vier Schaltern mit Tooltip. Erweitert mit Suche nach Updates, Blizzard-API, Daten, Spieldaten sichern, Aufbewahrung und Chancen. Der Kanal steht nicht mehr unter Addons.
  - **Geändert, Blizzard-API:** kein Knopf „Zugang prüfen“ mehr. Der Manager prüft den Zugang nach dem Speichern und beim Öffnen der Seite, solange die letzte Prüfung nicht geklappt hat. Die Testzeile des Beobachters ist aus den Einstellungen entfernt.
  - **Geändert, Namen:** Seiten heißen Spekulation, Einkaufslisten, Addons und Gegenstände wie in der Seitenleiste.
  - Hilfe (`docs\Hilfe.md`) mit den neuen Namen. Tests: `schlank.test.js` (Einträge, Unterreiter, Sprünge, Karten auf Heute, Schalter und Reiter der Einstellungen, Hilfe).

## 0.55.0

Kurz: Die Erfolgskontrolle zählt nur noch echte Verkäufe. Ein Angebot, das zurückgezogen und neu eingestellt wurde oder einfach ablief, gilt nicht mehr als verkauft. Neu ist eine Meldung von Windows, wenn neue Daten ausgewertet sind (unter Einstellungen einschalten). Die Stabilität berücksichtigt jetzt auch, wie stark ein Preis über die Tage gestiegen oder gefallen ist.

- 0.55.0 (25.11.2026, Rückmeldung KarloDerBaer: Trefferquote zu hoch):
  - **Ursache:** Die Erfolgskontrolle zeigte 97 % Treffer. Ein Treffer zählte, wenn in den 3 Tagen danach irgendein Verkauf oder der Median der Angebote den Zielpreis erreichte. Der Zielpreis ist aber der Median früherer Verkäufe, die Hälfte aller Verkäufe liegt darüber. Die Menge zählte nicht. Dazu galten Angebote, die zum gleichen Preis neu eingestellt wurden, als Verkauf (in 2 Tagen rund 440.000).
  - **Geändert, Verkäufe** (`sales.js`, `compare` bei Ständen der Blizzard-API): Ein verschwundenes Angebot ist nur ein Verkauf, wenn es das günstigste war, nicht ablief, kein Angebot gleicher Menge zum gleichen oder billigeren Preis neu kam und kein billigeres neu eingestellt wurde. Das gilt für Absatz, belegte Verkaufspreise und Chancen. Bisherige Werte bleiben und fallen nach 30 Tagen weg.
  - **Geändert, Nachprüfung der Chancen** (`chancebook.js`, `check`): gelohnt nur, wenn mindestens die vorgeschlagene Menge zu 98 % des Zielpreises verkauft wurde, „gerade so“, wenn sie wenigstens Kaufpreis und Gebühr brachte. Angebotspreise zählen nicht mehr. Ohne Stände der API im Zeitraum: keine Daten. Gezählt werden nur Tage ab dem Tag nach dem Update (`meta saleStrictDay`, `proof.js`).
  - **Geändert, Nachprüfung des Marktvergleichs** (`compare-client.js`, `compareCheck`): zählt der höchste echte Verkauf im Zielhaus statt des Tagesmittels der Preise. Ohne Verkauf „nicht gehalten“.
  - **Geändert, Stabilität** (`stability.js`, `dayPart`): Die Richtung zählt mit halbem Gewicht in den Tagesteil (größerer Wert aus Schwankung und ½ × |ln(letzter ÷ erster Tageswert)|). Messung mit 14 vollen Tagen: Die Grenzen passen, aber 251 Gegenstände galten trotz über 30 % Bewegung als stabil.
  - **Neu, Meldung bei neuen Daten** (`electron/main.js`, `notifyData`, Einstellung `dataNotify`, Standard aus): kommt, wenn ein neuer Stand der Blizzard-API oder neue Scans aus dem Spiel ausgewertet und die Werte für Broker geschrieben sind.
  - Tests: strenge Verkäufe bei Einzelgegenständen und Massenware, Nachprüfung mit Menge, „gerade so“ und ohne Daten (`chancen.test.js`), Marktvergleich nur mit Verkauf (`marktvergleich.test.js`), Richtung im Tagesteil (`stabilitaet.test.js`), Meldung standardmäßig aus (`updates.test.js`).

## 0.54.0

Kurz: Gleiche Fehler gehen als eine Meldung mit Anzahl an KarloDerBaer. Beim Senden vieler Fehler auf einmal kommt keine falsche Fehlermeldung mehr, und nichts wird doppelt geschickt.

- 0.54.0 (24.11.2026, 28 doppelte Fehlerberichte am 21.11.2026):
  - **Ursache:** Ein Manager schickte am 21.11.2026 dreimal je 11 Einträge. Der Fehler-Worker stieß dabei an die Grenze von Cloudflare (50 Abrufe je Anfrage, je Eintrag brauchte er vier) und brach ab, nachdem die Issues schon angelegt waren. Der Manager meldete „Senden fehlgeschlagen“, behielt alles und schickte es später noch einmal. Dazu bekam „script ran too long“ mit jeder Zeilennummer eine eigene Kennung.
  - **Geändert, Kennung eines Fehlers** (`reports.js`, `errorText`): ohne wechselnde Teile, also „script ran too long“ ohne Datei und Zeile und Adressen von Tabellen und Funktionen ohne Wert. Gleiche Regeln wie im Kern 0.27.2 und im Worker. Vorhandene Zeilen bekommen beim nächsten Einlesen die neue Kennung und zählen weiter, nicht doppelt.
  - **Neu, Bündeln vor dem Senden** (`errorGroups`): Gleiche Fehler (Addon, Stelle, Meldung) gehen als eine Meldung mit der Summe der Anzahl, dem ganzen Zeitraum und der Version der neuesten. Bestätigt der Worker sie, fallen alle zugehörigen Zeilen weg.
  - **Fehler-Worker** (`worker\peon-fehler\worker.mjs`, wirkt erst nach `npx wrangler deploy`): liest die offenen Issues einmal je Sendung als Verzeichnis „Kennung zu Issue“ statt für jeden Eintrag die Suche von GitHub zu fragen (die kennt neue Issues erst nach einer Weile). Gleiche Fehler einer Sendung werden zu einer Meldung. Er zählt seine Abrufe und hört vor der Grenze auf, bestätigt wird dann nur das Angelegte. Eine volle Sendung mit 20 Einträgen braucht jetzt höchstens 27 Abrufe.
  - Tests: Bündeln und Löschen beim Senden, Umstellung alter Kennungen, Verzeichnis statt Suche, gleiche Fehler einer Sendung, volle Sendung unter der Grenze, Adressen in der Kennung (`reports.test.js`).

## 0.53.1

Kurz: Der Manager liest den Preisverlauf von Peon Broker auch in dessen neuer, kompakter Speicherform.

- 0.53.1 (20.11.2026, passend zu Broker 0.130.0):
  - **Geändert, Einleser Broker-Verlauf** (`broker.js`, `unpackItem`): Ab Broker 0.130.0 stehen die Texte eines Gegenstands gepackt in `e.x`. Der Einleser trennt sie wieder, alte Dateien liest er wie bisher. Varianten ohne Namen bekommen ihn aus dem Schlüssel (wie bisher).
  - Tests: gepackte Einträge mit Text und Tabelle, Einlesen einer gepackten Datei (`c3.test.js`).

## 0.53.0

Kurz: Neu sind Pakete im Marktvergleich: je Richtung mehrere kleine Angebote, die zusammen auch dann Gewinn bringen, wenn nur die Hälfte verkauft wird. Die Erfolgskontrolle zeigt, was aus jedem Paket geworden ist.

- 0.53.0 (20.11.2026, Wunsch KarloDerBaer, Konzept `Peon_Broker_Pakete.md`):
  - **Neu, Pakete** (`packages.js`): aus allen Kandidaten des Marktvergleichs je Richtung ein Paket. Einzelstücke oder kleine Mengen Massenware (höchstens ein Tag im Ziel, höchstens ein Stapel), höchstens ein Angebot je Gegenstand und drei je Kategorie (Varianten mit der Kategorie des Grundgegenstands), ein Angebot höchstens ein Viertel des Einsatzes. Gewinnprüfung: verkauft werden nur die schlechtesten 50 %, der Rest zählt mit 0, alle Einstellgebühren abgezogen. Gierige Auswahl nach erwartetem Gewinn mit 30 Startangeboten, gestreute Pakete (ab 4 Angeboten) gehen vor.
  - **Neu, Regeln** `pkgSize` (8), `pkgGold` (10 % des Golds laut Ledger, ohne Ledger höchstens 25 Gold), `pkgSafe` (50 %), unter Einstellen auf der Seite Marktvergleich.
  - **Neu, Unterreiter Pakete** auf der Seite Marktvergleich mit Einsatz, erwartetem Gewinn, Gewinn im schlechten Fall und allen Angeboten. Angebote lassen sich ausschließen (`meta pkgExclude`), der Manager rechnet neu.
  - **Neu, Weitergabe an Broker** in `Data.lua` (`markets[Heimat].pkg`, je Angebot Menge, Kaufen bis, Verkaufen ab und erwarteter Preis).
  - **Neu, Erfolgskontrolle der Pakete:** das erste Paket je Tag und Richtung wird gemerkt (`meta pkgLog`) und mit den Bewegungen aus Ledger ausgewertet (gekauft im Haus der Quelle, verkauft im Haus des Ziels, Ausgaben, Erlös, Ergebnis).
  - Mit echten Daten (20.11.2026, Einsatz 200 Gold zum Vergleich): je Richtung 8 Angebote, Gewinn auch im schlechten Fall.
  - Tests: Streuung, Budget, Gewinnprüfung, Ausschließen, Mindestpreis für Broker, Auswertung mit Ledger (`test/marktvergleich.test.js`).

## 0.52.0

Kurz: Die Seite Marktvergleich zeigt jetzt zuerst nur die Auswahl, die an Broker geht. Alle Kandidaten gibt es über die Auswahlliste.
Kurz: Neu sind die Einstellgebühr in der Rechnung, Chancen für Gegenstände, die im anderen Haus gerade fehlen, ein Diagramm im Reiter Neutral und der Marktvergleich in der Erfolgskontrolle.

- 0.52.0 (20.11.2026, Wunsch KarloDerBaer):
  - **Geändert, Liste Chancen:** Vorgabe ist die Auswahl für Broker (die besten 10), „Alle Kandidaten“ über die Auswahlliste. Die Zahl am Reiter folgt der Auswahl.
  - **Neu, Einstellgebühr** (`compare.js`, `depositLoss`): 5 % vom Händlerpreis, mal 4 für 8 Std., wie in Broker. Im neutralen Haus gleich hoch gemessen (20 Seidenstoff 1s 50c). Verloren ist sie je Verkauf so oft, wie Angebote ablaufen (1 durch Absatzquote minus 1, Absatzquote höchstens bis 20 % gerechnet).
  - **Neu, Lücke im Ziel:** Gegenstände, die im Zielhaus verkauft werden, dort aber gerade kein Angebot oder im Zeitraum keinen Preis haben. Verkaufspreis ist der Median der echten Verkäufe über 14 Tage, mindestens 3 Tage mit Verkäufen. Der Satz sagt „Im Ziel gerade kein Angebot“.
  - **Neu, Diagramm im Reiter Neutral** der Gegenstandsseite (`components/CompareChart.vue`, `compare.itemSeries`): günstigster Preis und Verkaufspreise beider Häuser über 30 Tage, abschaltbar.
  - **Neu, Erfolgskontrolle für den Marktvergleich** (`compare-client.js`, `meta compareLog`): Die Auswahl wird je Tag gemerkt und nach 3 Tagen nachgeprüft (gehalten, teilweise, nicht gehalten). Dazu echte Tausche aus Peon_Ledger.lua (ab Ledger 0.17 mit Haus).
  - Tests: Einstellgebühr, Lücke, Verlauf, Erfolgskontrolle (`test/marktvergleich.test.js`).

## 0.51.0

Kurz: Der Marktvergleich wählt nach jedem neuen Stand die besten 10 Chancen für Broker aus und berücksichtigt dabei auch die letzten 14 Tage. Die Anzahl ist einstellbar.
Kurz: Beobachten hat jetzt Unterreiter wie im Spiel: Aufkauf, Schnellkauf und Markttausch. Die Seite Händler ist wieder da.

- 0.51.0 (20.11.2026, Wunsch KarloDerBaer, Konzept `Peon_Broker_Marktvergleich.md` Abschnitt 10):
  - **Neu, Auswahl für Broker** (`compare.js`, `pickTop`, Regel `top`, Vorgabe 10): beide Richtungen zusammen, je Gegenstand eine. Ausgeblendete rücken nach, Angeheftete kommen dazu. Bis 0.50.x gingen je Richtung die besten 150.
  - **Neu, Langzeitwerte in der Bewertung** über 14 Tage: Beständigkeit des Unterschieds, wie gleichmäßig im Ziel verkauft wird und ob der Unterschied wächst oder schrumpft. Sie stehen beim Aufklappen einer Chance und im Satz.
  - **Neu, Grenzen für Broker** in `Data.lua` (`cmp.minPct`, `cmp.minNet`).
  - **Neu, Beobachten mit Unterreitern** (`views/Watch.vue`): Aufkauf wie bisher, Schnellkauf mit Kaufen bis und Limit pro Kauf, Markttausch mit beiden Häusern aus dem Marktvergleich. Hinzufügen und Entfernen wirken auf die Liste des offenen Unterreiters.
  - **Neu, Abgleich des Schnellkaufs** (`watching.js`): Kaufen bis, Limit pro Kauf, Lockangebot ignorieren, Durchschnitt zählt und die Haken der Listen je Gruppe mit eigener Zeit (`t.q`, `t.lists`).
  - **Geändert, Seite Händler** wieder an (ohne WIP). Die Händlerdaten kamen schon aus `Peon_Broker.lua`.
  - Tests: Auswahl der besten, schrumpfender Unterschied, Grenzen für Broker, Listen und Abgleich der Beobachtung (`test/marktvergleich.test.js`).

## 0.50.1

Kurz: Die Seite Marktvergleich steht jetzt wirklich in der Seitenleiste unter Chancen.

- 0.50.1 (20.11.2026, Fehler gemeldet von KarloDerBaer): Die Seite fehlte in der Liste der Seiten des Moduls Peon Broker Client (`modules.js`, `views`), darum zeigte die Seitenleiste sie nicht.
  - Tests: Liste der Seiten mit `compare` (`test/modules.test.js`).

## 0.50.0

Kurz: Neue Seite Marktvergleich: Sie vergleicht dein Auktionshaus mit dem neutralen über die letzten Tage und findet Gegenstände, die sich im einen Haus kaufen und im anderen verkaufen lassen. Die besten gehen an Broker.

- 0.50.0 (20.11.2026, Wunsch KarloDerBaer, Konzept `Peon_Broker_Marktvergleich.md`):
  - **Neu, Rechnung** (`compare.js`): je Paar Heimat und Neutral und je Richtung Kaufpreis (Median der Tageswerte des günstigsten Preises), Verkaufspreis (Median der echten Verkaufspreise, höchstens das übliche günstigste Angebot), Gewinn nach dem Anteil des Zielhauses, Absatz im Ziel, Vorrat im Ziel, Beständigkeit und Menge. Bewertung = Gewinn je Tag mal Beständigkeit mal Abschlag für vollen Zielmarkt. Grün ab 70 % Beständigkeit und höchstens 3 Tagen Vorrat.
  - **Neu, Regeln einstellbar** (`compareRules` in `meta`): Zeitraum 3, 7 oder 14 Tage, eigener Anteil am Absatz (Vorgabe 10 %), Haltedauer (Vorgabe 1 Tag), Mindestspanne, Mindestgewinn, Mindestabsatz, Beständigkeit und der angenommene Anteil des neutralen Hauses (15 %). Den gemessenen Anteil liest der Manager aus `Peon_Broker.lua` (`cut`).
  - **Neu, Seite Marktvergleich** (`views/Compare.vue`) mit Unterreitern Chancen, Alle Gegenstände, Übersicht und Einstellen. Chancen lassen sich ausblenden (auch für Broker) und an Broker anheften.
  - **Neu, Reiter Neutral** auf der Seite eines Gegenstands.
  - **Neu, Weitergabe an Broker** (`compare-client.js`, `Data.lua` `markets[Heimat].cmp`): je Richtung die besten 150, dazu alle angehefteten.
  - **Neu, günstigster Preis je Tag im Zwischenspeicher** (`snapindex.js`, `dayMins`, `lastSeen`). Ältere gesicherte Stände haben ihn nicht, dort gilt bis zum nächsten Neulesen der Median.
  - Messung mit echten Daten (20.11.2026, 7 Tage): rund 27.000 Gegenstände in beiden Häusern, 532 Chancen nach Neutral und 912 nach Fraktion, davon 965 grün.
  - Tests: Regeln, beide Richtungen, gemessener Anteil, Beständigkeit, voller Zielmarkt, Tageswerte aus dem Zwischenspeicher, Liste für Broker, Ansicht (`test/marktvergleich.test.js`).

## 0.49.0

Kurz: Rückmeldungen tragen jetzt eine anonyme Kennung deines Peon Managers. So sieht KarloDerBaer, ob mehrere Berichte von derselben Installation kommen.

- 0.49.0 (18.11.2026, Wunsch KarloDerBaer):
  - **Neu, anonyme Absender-Kennung:** 8 Zeichen, zufällig beim ersten Senden erzeugt (`reports.js`, Einstellung `senderId`), ohne Bezug zu Namen, Konto oder Rechner. Sie geht mit jeder Sendung mit und steht im Issue als „Absender …“ (Worker). Der Sendedialog zeigt sie, „Neue Kennung“ erzeugt eine andere.
  - **Neu, Peon unterstützen:** Eintrag „☕ Peon unterstützen“ unten in der Seitenleiste und ein Abschnitt am Ende der Hilfe. Öffnet die Seite von KarloDerBaer bei Buy Me a Coffee im Browser (nur genau diese Adresse ist freigegeben).
  - Der Worker nimmt nur gültige Kennungen an. Ältere Manager senden keine, ihre Issues bleiben ohne Absender. Wirkt nach dem Hochladen des Workers (`npx wrangler deploy`).

## 0.48.0

Kurz: Der Manager sichert jetzt die Daten deiner Peon-Addons vor jedem Update und einmal am Tag. Unter Einstellungen holst du einen älteren Stand zurück.
Kurz: Neue Seite Hilfe mit einer kurzen Anleitung zu jedem Addon.

- 0.48.0 (18.11.2026, Review mit KarloDerBaer):
  - **Neu, Spieldaten sichern** (`src/core/gamebackup.js`): Die SavedVariables der Peon-Addons aus `WTF\Account` (Konto und Charaktere) gepackt im Datenordner unter `Spielsicherung`. Vor jedem Installieren oder Aktualisieren (höchstens alle 10 Minuten) und einmal am Tag. Je Anlass bleiben die neuesten (vor Update 5, täglich 7, von Hand 5, vor Wiederherstellen 3). Unter Einstellungen: Jetzt sichern, Liste, Wiederherstellen (nur bei geschlossenem WoW, vorher wird der jetzige Stand gesichert), Löschen, Ordner öffnen. Fremde Dateien bleiben unberührt.
  - **Neu, Hilfe:** Seite Hilfe mit Suche und Sprungleiste, Inhalt aus `docs/Hilfe.md` im Repo (auch auf GitHub lesbar). Ein kleiner Leser (`src/renderer/markdown.js`) gibt nur Text aus, kein HTML.
  - **Neu, abgelöste Addons:** `retired` im Manifest. Peon_ComboPoints wird nicht mehr ausgeliefert. Ist es noch installiert, zeigt die Seite Updates es als „Abgelöst“ und entfernt es wie bisher von selbst, sobald Peon_ClassBuddy die Einstellungen übernommen hat. Von Hand entfernen geht ebenfalls.
  - **Geändert:** Änderungen am Broker Client bei ausgeschaltetem Modul melden „Das Modul Peon Broker Client ist ausgeschaltet.“ statt eines Programmfehlers.

## 0.47.0

Kurz: Die Größe des Fensterinhalts lässt sich einstellen, auch mit Strg und Plus oder Minus.
Kurz: Mehr Listen gehen jetzt auch mit der Tastatur, und Rückmeldungen an Peon werden bei gleichen Fehlern zusammengefasst.

- 0.47.0 (18.11.2026, Review mit KarloDerBaer):
  - **Neu:** Größe der Oberfläche unter Einstellungen, Programm (80 bis 175 %), dazu Strg und Plus, Minus, 0 sowie Strg und Mausrad (`src/core/zoom.js`, Einstellung `zoom`, gemerkt in `settings.json`). Vorher gab es keinen Zoom, weil das Fenster kein Menü hat.
  - **Geändert:** Klickbare Zeilen und Spaltenköpfe in Stabilität, Marktübersicht und Erfolgskontrolle gehen jetzt auch mit Tab und Enter (wie schon in Übersicht, Chancen, Einkaufen, Beobachten und Händler).
  - **Behoben:** Der Dialog „Rückmeldung“ zu einer Chance schließt jetzt mit Escape, und der Zähler zeigt die richtige Grenze (1000 statt 250 Zeichen).
  - **Geändert (Fehler-Worker, gilt nach dem Hochladen):** Die Sperre zählt Einträge statt Sendungen (20 je Stunde und Adresse, 60 insgesamt). Gleiche Fehler (Addon, Stelle, Meldung) kommen als Kommentar an das offene Issue statt als neues Issue.

## 0.46.0

Kurz: Die Übersicht zeigt jetzt, wie stabil der Markt ist, mit Verlauf im Diagramm. Der Markt ist jetzt der erste Reiter in der Marktübersicht.

- 0.46.0 (17.11.2026, Wunsch KarloDerBaer):
  - **Neu, Übersicht:** Kachel „Stabilität des Markts“ mit Stufe, Index und Änderung zu gestern. Klick führt zur Marktübersicht, Reiter Stabilität. Darunter ein Diagramm mit dem Verlauf des Index für den ganzen Markt, Massenware und Handwerkswaren, dahinter die Stufen.
  - **Geändert, Marktübersicht:** Die bisherige Seite Markt ist der erste Reiter der Marktübersicht. Die Marktübersicht steht in der Leiste dafür an zweiter Stelle. Verweise auf den Markt (Beobachten, leere Beobachtung) führen dorthin.
  - **Geändert, Stabilität:** Der Verlauf im Reiter Stabilität ist dasselbe Diagramm wie in der Übersicht, mit Achse, Stufen und Werten beim Darüberfahren.
  - Neuer Aufruf `stabilitySummary` (nur Gruppen und Verlauf, ohne Liste) für die Übersicht.
  - Tests: `stabilitySummary` im Integrationstest (`stabilitaet.test.js`).

## 0.45.0

Kurz: Neu in der Marktübersicht: Wie stabil sind die Preise? Für jeden Gegenstand, jede Kategorie und den ganzen Markt, aus Stunden und Tagen.

- 0.45.0 (17.11.2026, Wunsch KarloDerBaer, Konzept `docs/konzepte/manager/Peon_Manager_Stabilitaet.md`):
  - **Neu, Stabilität** (`stability.js`): zwei Teile. Stunden: mittlere Bewegung von Stand zu Stand der Blizzard-API über 7 Tage. Tage: Schwankung der Tageswerte über 14 Tage wie F36. Preis bei Massenware die günstigsten 25 %, sonst das günstigste Angebot. Es zählt der schlechtere Teil, Stufen von „sehr stabil“ bis „unsicher“ und Index 0 bis 100. Die Richtung über die Tage steht daneben.
  - **Neu, Kategorien und Markt:** Median der Gegenstände je Klasse und Unterklasse, dazu ganzer Markt, Massenware, Handwerkswaren und Einzelgegenstände. Gegenstände mit weniger als 20 Angeboten im Schnitt zählen nicht. Verlauf über 30 Tage.
  - **Neu, Anzeige:** Reiter Stabilität in der Marktübersicht, Zeile auf der Gegenstandsseite (Reiter mit dem üblichen Bereich), Spalte Stabilität in der Markt-Liste.
  - **Schema 15:** Klasse, Unterklasse und Stapelbarkeit je Gegenstand aus der Blizzard-API (`items.cls`, `sub`, `cls_name`, `sub_name`, `stack`). Bekannte Gegenstände holt der Manager einmal nach, bis zu 1000 je Stand.
  - Gerechnet wird nach jedem neuen Stand im Hintergrund, nachdem Data.lua geschrieben ist (`stabilityInBackground`, `calc_cache` `stability` und `stabHist`). Mit echten Daten etwa 13 Sek. für den großen Markt.
  - Tests: Index und Stufen, beide Teile, Markt mit Kategorien und Gruppen, Tage aus 3-Stunden-Werten, Rechnung im Hintergrund, Lese-Prozess (`stabilitaet.test.js`), Klasse aus der Blizzard-API (`blizzard-import.test.js`).

## 0.44.0

Kurz: Chancen, die Broker im Spiel beim Prüfen nicht mehr gefunden hat, blendet der Manager aus, bis neue Daten sie wieder bewerten.

- 0.44.0 (17.11.2026, Wunsch KarloDerBaer):
  - **Neu, Chancen:** Der Manager liest `PeonBrokerDB.chancesGone` (Broker 0.101.0) aus `Peon_Broker.lua` und merkt sich die Einträge je Kontoordner in `meta` `chanceGone` (`goneFromGame`, `goneFor`). Jede neu gelesene Datei ersetzt den Teil ihres Kontoordners. Andere Namen desselben Markts zählen mit.
  - **Neu, Chancen:** Was zum aktuellen Stand im Spiel weg ist, geht nicht mehr an Broker und steht auf der Seite Chancen nicht in der Liste. Darunter steht eine Zeile mit Gegenstand, Zeitpunkt und günstigstem Angebot. Mit dem nächsten Stand werden die Chancen neu bewertet.
  - Tests: Einlesen, zwei Kontoordner, anderer Name des Markts, neuer Stand (`chancen.test.js`).

## 0.43.0

Kurz: Deine Eingaben im Manager werden jetzt sofort gespeichert, auch wenn er gerade neue Daten rechnet.
Kurz: Chancen, Marktübersicht, Beobachten und Einkaufen öffnen sofort, auch während einer Rechnung.

- 0.43.0 (16.11.2026, KarloDerBaer 15.11.2026: Ergebnisse auf die Platte, Schreiben und Rechnen trennen, „beides“). Gemessen mit den echten Daten während einer Neurechnung von 15 Sek.: Eine Eingabe brauchte 0,0 statt 14,3 Sek., Chancen, Beobachten und Einkaufen öffneten in höchstens 0,4 Sek.
  - **Drei Arbeitsprozesse** (`broker-remote.js`, Rolle in `BrokerClient.role`): Der Schreib-Prozess liest ein, nimmt alle Eingaben an, räumt auf und schreibt Data.lua. Er rechnet nichts Abgeleitetes. Der Rechen-Prozess rechnet nach jedem Einlesen Bereich, Absatz, Chancen, Liste und Marktübersicht (`calcMarkets`), nach dem Aufräumen Vergleiche, Muster und Tageswerte (`maintainInBackground`). Danach schreibt der Schreib-Prozess Data.lua aus den gespeicherten Werten (`bridgeFromCalc`). Der Lese-Prozess (ab 0.42.0) beantwortet die Ansichten.
  - **Ergebnisse in der Datenbank** (Tabelle `calc_cache`): Chancen, Marktübersicht, Bewegungen für die Übersicht und Werte für Broker je Markt, jeweils mit Datenstand und Regelstand (`ruleSig`). Ein Ergebnis zu einem älteren Datenstand gilt, solange die Rechnung läuft, eines zu alten Regeln nie. Dann antwortet der Rechen-Prozess.
  - **Über den Lese-Prozess** neu: Chancen, Marktübersicht, Beobachten, Einkaufen und „Jetzt kaufbar“. Ob WoW läuft, bekommt er mit jeder Anfrage. „Warum nicht“ und Steckbrief kommen aus dem Rechen-Prozess.
  - **Nach Eingaben zu den Chancen** (Regler, Übersteuerung, eigene Ereignisse, Rückmeldungen) rechnet der Rechen-Prozess gleich neu, Broker bekommt die neuen Kandidaten mit Data.lua. Bisher erst beim nächsten Einlesen. Angeheftetes und Daumen runter gelten wie bisher sofort.
  - **Sicher:** Beide Prozesse schreiben, gewartet wird statt Fehler (`busy_timeout`, Transaktionen mit `BEGIN IMMEDIATE`). Fällt der Rechen-Prozess aus oder antwortet 10 Min. nicht, rechnet der Schreib-Prozess wie bisher. Nach einer Minute startet er neu, ein Ausfall steht im Protokoll.
  - Behoben: Der Lese-Prozess hielt eine Liste zum alten Stand für den neuen. Die fertige neue Liste kam so erst nach dem übernächsten Stand an.
  - Eigene Ereignisse zählen jetzt zum Regelstand der Chancen. Neue Stufen von Gegenständen aus der Blizzard-API kommen mit der nächsten Rechnung in die Chancen.
  - Tests: gespeicherte Ergebnisse im Lese-Prozess, alte Regeln, neue Liste (`c6.test.js`), Eingabe während einer Rechnung, Regeln geändert, Aufräumen, Ausfall des Rechen-Prozesses (`worker.test.js`).

## 0.42.0

Kurz: Gegenstandsseite und Gegenstandsliste laden jetzt auch dann sofort, wenn der Manager gerade neue Daten einliest oder neu rechnet.

- 0.42.0 (15.11.2026, Stufe 3 der Beschleunigung, KarloDerBaer 15.11.2026). Gemessen mit den echten Daten: Während einer Neurechnung von 17 Sek. lädt die Gegenstandsseite in etwa 1 Sek., über den bisherigen Weg wartete sie 14 Sek.
  - **Lese-Prozess:** `BrokerRemote.read` schickt Abfragen an einen zweiten Arbeitsprozess, der die Datenbank nur liest (`db.openReadDb`, `host.readOnly`). Er startet, sobald der erste Prozess bereit ist (dieser stellt die Datenbank beim Öffnen um). Über ihn laufen Gegenstandsseite, Gegenstandsliste und das Protokoll des Abgleichs.
  - **Abgeleitete Werte:** Die Liste kommt aus dem Zwischenspeicher der letzten fertigen Rechnung (`list_cache`), auch wenn die Neurechnung nach einem neuen Stand noch läuft. Die Gegenstandsseite rechnet ihre Werte selbst aus der Datenbank.
  - **Sicher:** Versucht eine Abfrage im Lese-Prozess zu schreiben oder fällt er aus, beantwortet der erste Prozess sie wie bisher. Nach einer Minute startet der Lese-Prozess neu. Ein Ausfall steht im Protokoll.
  - Tests: Lesen über den zweiten Prozess, Schreiben geht an den ersten, Ausfall (`worker.test.js`).

## 0.41.0

Kurz: Die Datenbank ist nur noch etwa halb so groß und wächst kaum noch. Preise bleiben 7 Tage Stand für Stand, danach in Abschnitten von 3 Stunden bis 28 Tage, danach je Tag.
Kurz: Beim ersten Start stellt der Manager die Daten einmal um, das dauert je nach Größe bis zu einer Minute.

- 0.41.0 (15.11.2026, Stufe 2 der Beschleunigung, KarloDerBaer 15.11.2026: Stundenwerte 7 Tage, „setz alles so um“). Gemessen mit den echten Daten: Datei 1,96 auf 1,08 GB, Umstellung 18 Sek.
  - **Schema 14** (`db.migrate14`): `snapshots.sid` als feste Zahl je Stand. `item_snap` ohne rowid mit Schlüssel (sid, Gegenstand) und einer Suchhilfe, 107 statt 206 Byte je Zeile. Abfragen über eine Zeitspanne gehen über die Stände (`db.SNAPS_IN`). `item_snap_t` und `item_hour_t` entfallen.
  - **3-Stunden-Werte:** `item_hour` hält Abschnitte von 3 Stunden in Ortszeit (wie die Muster, `db.slotHour`) mit tiefstem und höchstem Median (`med_lo`, `med_hi`), Schlüssel (Markt, Abschnitt, Gegenstand, Quelle). Die Erfolgskontrolle nimmt den höchsten Median, eine kurze Spitze zählt weiter. Die Umstellung rechnet Kennzahlen älter als 7 Tage gleich so um.
  - **Aufbewahrung neu:** 7 Tage je Stand, 3-Stunden-Werte bis 28 Tage (mindestens 28, die Muster brauchen sie), danach Tageswerte. Vorlagen Sparsam 3/28, Ausgewogen 7/28, Ausführlich 14/90, Alles 30/365. Einmalig für alle auf 7/28 (`retentionV` 3). Seite Einstellungen mit neuen Texten und Schätzung.
  - **Tageswerte gesichert:** `SnapIndex.save`/`load` in `snap_cache`, beim Start 1 statt 12 Sek. Nach dem Aufräumen in Schritten neu gelesen (`rebuildSteps`), nicht mehr am Stück.
  - **Erstes Auftauchen der Angebote** ohne rowid (`auc_first`), rund 70 MB weniger.
  - Tests: Umstellung einer alten Datenbank, Abschnitte mit tiefstem und höchstem Wert, 28 Tage, Sichern und Laden, Neu lesen in Schritten. Tests legen Kennzahlen mit ihrem Stand an (`test/snap-helper.js`).

## 0.40.0

Kurz: Der Manager rechnet nach einer Live-Abfrage aus Broker nicht mehr alles neu und hält die Datenbank kleiner. Die Angebote der Blizzard-Stände bleiben 2 Tage, Live-Abfragen 7 Tage.

- 0.40.0 (15.11.2026, Stufe 1 der Beschleunigung, KarloDerBaer 15.11.2026: „setz alles so um“). Gemessen mit den echten Daten (1,9 GB nach 10 Tagen).
  - **Live-Abfragen lösen keine Neurechnung mehr aus:** `dataSig` zählt nur Scans und Stände der API. Vorher rechnete jede Live-Abfrage beide Märkte neu (rund 20 Sek.). Ihr Preis steht sofort auf der Gegenstandsseite, Liste und Bereich kommen mit dem nächsten Stand.
  - **Live-Abfragen zählen nicht mehr für den Absatz** (`sales.updateMarket` ohne Live-Paare). Sie trugen 290 von 1,16 Mio. Vergleichen bei. Nach 7 Tagen löscht das Aufräumen sie ganz (`retention.LIVE_DAYS`).
  - **Angebote der Stände kürzer:** Blizzard-API 2 Tage (`API_BLOB_DAYS`), eigene Scans 14 Tage (`SCAN_BLOB_DAYS`), die Kennzahlen bleiben. Gebraucht werden nur der neueste und der vorige Stand. Mit den echten Daten rund 400 MB weniger (1,93 auf 1,58 GB), danach 50 MB je Tag. Gelöscht wird in Gruppen zu 20 Ständen.
  - **Absatz der API schneller:** Einzelvergleiche der Blizzard-API nach 3 Std. zu Tageswerten (`FOLD_API_AFTER`), eigene Scans weiter nach 2 Tagen (ein später eingelesener Scan ersetzt dann noch das Paar).
  - **Muster in Schritten:** eine Abfrage je Ortstag über den Index der Zeit, längster Schritt 0,6 statt 20 Sek. am Stück.
  - **Mitternacht:** Die Tageswerte verschieben sich um einen Tag (`SnapIndex.shift`), bisher wurde alles neu gelesen (27 Sek.).
  - Tests: Aufräumen von Angeboten und Live-Abfragen (`c3.test.js`), Live ohne Absatz und ohne Neurechnung (`c6.test.js`), Verschieben gleich wie neu lesen (`snapindex.test.js`).

## 0.39.1

Kurz: Der Manager reagiert wieder schneller. Die Gegenstandsseite blieb oft lange bei „Lade Gegenstand“ stehen, weil der Manager nach jedem neuen Stand über eine Minute mit der Rechnung für Feste beschäftigt war.

- 0.39.1 (15.11.2026, Rückmeldung KarloDerBaer): Gegenstandsseite lud nicht, Manager allgemein langsamer.
  - **Ursache:** Messung mit den echten Daten (1,9 GB, 3,7 Mio. Kennzahlen im größeren Markt): Die Chancen eines Markts brauchten 69 Sek., davon 60 Sek. `forecast.festSignals`. Seit dem Anglerwettbewerb vom 15.11. gibt es für die kommenden Termine ein letztes gleiches Fest, ab da lief die Rechnung bei jedem Einlesen. Jede Abfrage las alle Zeilen des Markts (Index über Markt statt über die Zeit), und das wöchentliche Fest stand zweimal in der Liste. Der Arbeitsprozess erledigt alles der Reihe nach, so lange wartete auch die Gegenstandsseite.
  - **Behoben:** Abfragen mit `+market_id` über den Index der Zeit (16 auf 2 Sek.), jedes Zeitfenster nur einmal gelesen, Ergebnis je Markt höchstens einmal je Stunde gerechnet (`festSignalsOf`, auch für die Marktübersicht). Chancen eines Markts danach 7 Sek. statt 69, das Ergebnis bleibt gleich.
  - **Neu:** Arbeiten, die den Arbeitsprozess über 10 Sek. am Stück belegen, stehen im Protokoll (Kennung `dauer`). Die Gegenstandsseite zeigt einen Fehler mit „Erneut versuchen“ statt immer „Lade Gegenstand“.
  - Weiter langsam, aber kein Fehler: Absatz und Prognosen lesen je Markt rund 930 000 Vergleichszeilen (je etwa 4 Sek.), der erste Aufbau nach Start und Aufräumen etwa 30 Sek.
  - Tests: Feste mit Zeitindex, gleiche Fenster einmal, Zwischenspeicher je Stunde (`chancen.test.js`).

## 0.39.0

Kurz: Händler-Angebote zeigt der Manager nicht mehr, sie sind meist nach Minuten weg. Die findet das Radar in Broker.
Kurz: Neue Art Muster: Ist ein Gegenstand zu einer Tageszeit oder an einem Wochentag fest günstiger, schlägt der Manager vor, dann zu kaufen und zur teuren Zeit zu verkaufen. Vorschläge gibt es frühestens nach 14 Tagen Daten.

- 0.39.0 (15.11.2026): Konzept `docs/konzepte/manager/Peon_Chancen_Reiter_Muster.md` (KarloDerBaer 15.11.2026). Braucht Broker 0.96 für die Zeitfenster im Spiel.
  - **Händler entfernt** (KarloDerBaer: löschen): `spec.evalVendor`, der Reiter „Nur live erreichbar“, die Regler der Art und die Händler-Kandidaten für Broker. Schema 13 löscht gespeicherte Händler-Vorschläge aus `chance_log` (`meta` `vendorKindGone`), Rückmeldungen dazu bleiben. Der Händlerpreis selbst zählt weiter für die Einstellgebühr.
  - **Muster:** Neue Datei `pattern.js`. Einmal am Tag je Markt beim Aufräumen (`broker-client.patternSteps`, `meta` `patterns:<Markt>`) aus den Kennzahlen der letzten 28 Tage: Preis je Tag und 3-Stunden-Abschnitt in Ortszeit, Trend herausgerechnet (gleitendes Tagesmittel). Tageszeit ab 14 Tagen mit 70 % gleichem günstigstem Abschnitt, Wochentag ab 3 Wochen mit 75 %, Abstand nach Gebühr mindestens 15 %, im Schnitt mindestens 5 Angebote. Messung mit 10 Tagen echter Daten: mit diesen Grenzen noch kein Muster, die Rechnung braucht etwa 15 Sek. je Markt.
  - **Chance Muster** (`spec.evalPattern`, Art `m`): Kaufen bis und Zielpreis aus dem üblichen Preis und den Anteilen im günstigen und teuren Fenster, Menge höchstens ein Tagesabsatz und das Gold. Prüfungen: festes Muster, Abstand nach Gebühr, Absatz, Preis fällt nicht, Schwankung, Gold. Satz „Am günstigsten 0 bis 3 Uhr, am teuersten 9 bis 12 Uhr, an 12 von 14 Tagen so.“ Nachprüfung nach 3 Tagen.
  - **Übergabe an Broker:** Einträge der Art Muster tragen die Zeitfenster zum Kaufen und Verkaufen (`m:…:Menge:127/0:32/-1`, Wochentage als 7 Bits, Abschnitt oder -1).
  - Seite Chancen: Art Muster in der Auswahl, Zeitfenster bei jeder Chance (mit „jetzt“), Hinweis, wann die Muster zuletzt gerechnet wurden. Erfolgskontrolle mit der Art Muster.
  - Tests: neue Datei `test/muster.test.js` (Muster trotz fallendem Markt, nur Trend ist kein Muster, Grenzen, Wochentag, Chance mit Gold und Preis fällt, Übergabe mit Fenstern, Schema 13). Händler-Tests entfernt oder umgestellt (`test/chancen.test.js`, `test/c6.test.js`). Alle 237 Tests grün, Oberfläche gebaut.
  - **Im echten Programm prüfen:** Seite Chancen ohne Händler, Hinweis zu den Mustern nach dem ersten Aufräumen des Tages, Protokoll ohne Fehler.

## 0.38.0

Kurz: Wird ein Peon-Addon durch ein anderes ersetzt, installiert der Manager das neue mit und entfernt das alte von selbst, sobald das neue seine Einstellungen übernommen hat. Zuerst betrifft das Peon ComboPoints, das im Klassenbuddy aufgeht.

- 0.38.0 (14.11.2026, Wunsch KarloDerBaer): **Ersetzte Addons** (`addons.js`).
  - Neue Angabe im Manifest `replacedBy = { by, db, key }` je Addon, aus `scripts/release.json`. `checkManifest` prüft sie (Peon-Addon aus demselben Manifest, Namen in Lua). Erste Nutzung: Peon_ComboPoints wird durch Peon_ClassBuddy ersetzt (`PeonClassBuddyDB.cpImported`).
  - **Liste:** Ist das alte Addon installiert und das neue nicht, gilt das neue als Update (`status update`, `replaces`). Es steht damit unter „Alle aktualisieren“ und im Update-Fenster mit „ersetzt …“. Das alte zeigt in der Ansicht Module einen Hinweis.
  - **Entfernen** (`autoReplace`, bei jeder Suche nach Updates): erst, wenn das neue installiert ist, in den Einstellungen eines Kontos `<db>.<key> = true` steht (`replaceReady`, liest `WTF\Account\<Konto>\SavedVariables\<neu>.lua`) und WoW nicht läuft. Der Ordner wandert in die Sicherung, die Einstellungen in WTF bleiben. Junctions (Entwicklung) bleiben immer. Eintrag im Protokoll.
  - Tests: `addons.test.js` (Update mit Hinweis, Warten auf die Übernahme, laufendes WoW, Sicherung, Junction, ungültige Angaben), `build_release.test.js` (Angabe im echten Manifest).
  - **Im echten Programm prüfen:** Mit Peon ComboPoints installiert nach Updates suchen: Klassenbuddy steht als Update da. Installieren, einmal einloggen, WoW schließen, nach Updates suchen: Peon ComboPoints ist weg, im Protokoll steht „ersetzt durch Peon_ClassBuddy“.

## 0.37.0

Kurz: Spekulation schnell schlägt nichts mehr vor, dessen Preis fällt, und braucht 7 Tage Preisverlauf. Solange der Markt jung ist, gibt es darum kaum Vorschläge.
Kurz: Abgebrochene und billiger neu eingestellte Angebote zählen nicht mehr als Verkauf. Die bisherigen Werte rechnet der Manager im Hintergrund neu.
Kurz: Der Einsatz je Chance richtet sich nach deinem Gold laut Ledger (Regler unter Chancen, Einstellen). Jede Chance zeigt den möglichen Verlust, wenn du schnell verkaufen musst.

- 0.37.0 (14.11.2026): Prüfung der Vorabversion `v2026.11.14.2-test` mit den echten Daten von KarloDerBaer (Flammenauge: Preiskampf von 125g auf 35g in 28 Std., trotzdem als Spekulation vorgeschlagen). Wünsche KarloDerBaer: alles beheben, Ideen umsetzen, ein fallender Preis schließt Spekulation aus.
  - **Umstellungen sind keine Verkäufe:** Bei Einzelgegenständen zählte jedes vor dem Ablauf verschwundene Angebot zu 90 % als Verkauf. In 24 Std. kamen 30 % davon im selben Stand billiger mit gleicher Menge wieder, weitere 16 % lagen über einem billigeren Angebot, das stehen blieb. Für Stände der Blizzard-API gelten beide jetzt als abgebrochen (`sales.compare` mit `singles`). Schema 12: belegte Verkäufe beginnen neu (`sale_px`, `sale_life` geleert), die Vergleiche der API bis dahin rechnet das Aufräumen im Hintergrund neu, je Schritt ein Paar (`redoApiSteps`, `meta` `apiRedoMax`, bei 1,4 GB etwa 1,4 Sek. je Paar).
  - **Preis fällt:** `spec.trendOf` urteilt ab 2 Tagen. Der Preis fällt, wenn heute 10 % unter dem Median der 3 Tage davor liegt, die letzten 3 Tage 15 % unter den Tagen 7 bis 14 oder er an 3 Tagen ohne Anstieg dazwischen zusammen 10 % gefallen ist. Gilt für Spekulation schnell und Aufkauf.
  - **Neue feste Prüfungen:** verlässlicher üblicher Preis (Schwankung höchstens 40 %), mindestens 7 Tage Preisverlauf (auch beim Aufkauf). Die Seite Chancen sagt, solange der Markt weniger als 7 Tage hat.
  - **Kaufen bis passt zum Zielpreis:** Sinkt der Zielpreis unter das nächste fremde Angebot, sinkt Kaufen bis mit, so dass nach 5 % Gebühr 10 % Abstand bleiben. Bei Flammenauge hätte das teuerste Stück sonst Verlust gebracht.
  - **Gold und Einsatz:** Gold der Charaktere der Fraktion aus `Peon_Ledger.lua` (`ledgerGold`, Neutral alle). Neuer Regler „Höchstens so viel deines Golds je Chance“ (25 %). Spekulation und Händler kaufen nur so viel, der Aufkauf ganz oder gar nicht. Ohne Ledger keine Grenze, die Seite sagt das.
  - **Möglicher Verlust:** Verkauf zum unteren Rand des üblichen Bereichs oder knapp unter dem nächsten fremden Angebot, je nachdem, was niedriger ist. Neue Prüfung „Möglicher Verlust kleiner als der Gewinn“, der Wert steht bei jeder Chance.
  - Nachgerechnet mit einer Kopie der echten Daten: statt 74 Vorschlägen (davon 87 von 126 am Tag mit fallendem Preis) bleiben 6 Aufkäufe mit kleinem Einsatz. Flammenauge scheitert an Preis fällt, Schwankung, 7 Tagen und Gold.
  - Tests: Preis fällt mit wenigen Tagen und in Folge, unsicherer Bereich, Kaufen bis, Gold, Verlust, Umstellungen, Schema 12 (`test/chancen.test.js`). Alle 229 Tests grün, Oberfläche gebaut.
  - **Im echten Programm prüfen:** Hinweis auf weniger als 7 Tage, Gold laut Ledger, Neurechnung im Hintergrund (Protokoll „Vergleiche der Blizzard-API neu gerechnet“), Regler unter Einstellen.

## 0.36.0

Kurz: Der Manager ist nach dem Start sofort bedienbar. Einstellungen, Updates und Rückmeldungen gehen gleich, die Marktseiten folgen, sobald die Daten geladen sind.
Kurz: Unter Einstellungen, Daten kannst du den Datenordner verlegen, zum Beispiel auf ein anderes Laufwerk. Der Manager kopiert alles beim Neustart, der alte Ordner bleibt als Sicherung liegen.
Kurz: Chancen mit Daumen runter verschwinden aus der Liste und gehen nicht mehr an Broker. Spekulation schnell schlägt keinen Zielpreis über dem üblichen Bereich mehr vor und nichts, dessen Preis seit Tagen fällt.
Kurz: Händlerpreise werden einmal neu aus dem Spiel geholt, falsche Werte aus der Blizzard-API verschwinden damit. In der Erfolgskontrolle kannst du Käufe, die du selbst behältst, herausnehmen.

- 0.36.0 (14.11.2026): Rückmeldungen KarloDerBaer zur Vorabversion `v2026.11.14-test` (lange Ladezeit beim Start, Datenordner auf ein anderes Laufwerk, vier Rückmeldungen zu Chancen, ein Wunsch zur Erfolgskontrolle).
  - **Schneller Start:** Das Fenster wartete auf die erste Übersicht aus dem Arbeitsprozess. Der arbeitet alles der Reihe nach ab und bekam beim Start zuerst das Einlesen, die Blizzard-API und das Aufräumen. Jetzt kommt zuerst ein Grundteil ohne Arbeitsprozess (`overviewBase`, `brokerLoading`): Seitenleiste, Updates, Rückmeldungen und Einstellungen sind sofort da, die Marktseiten zeigen „Marktdaten werden geladen“. Einlesen und Blizzard-API starten erst nach der ersten vollen Übersicht (höchstens 30 Sek. später), das Aufräumen nach 5 Minuten (`main.js`, `App.vue`).
  - **Datenordner verlegen:** Neue Datei `datadir.js`. Knopf „Ordner ändern“ unter Einstellungen, Daten. Der Manager prüft das Ziel (leer oder Unterordner „Peon Manager Daten“, nicht im alten Ordner, genug Platz, Schreibprobe), merkt es sich (`umzug.json`), startet neu und kopiert vor dem Öffnen der Datenbanken alles außer `tmp` mit kleinem Hinweisfenster. Erst wenn die Kopie vollständig ist, zeigt `datenordner.json` (neben dem Standardordner) auf den neuen Ordner. Der alte Ordner bleibt liegen, die Einstellungen nennen ihn. Nicht bei `PEON_MANAGER_DB`, in der Entwicklung und mit Runtime und DB nebeneinander.
  - **Händlerpreis neu aus dem Spiel (Schema 11):** Bis 0.35.0 haben Stände der Blizzard-API mit dem Namen ihren Händlerpreis weitergetragen und den Wert aus dem Spiel überschrieben. Schema 10 hat solche Werte dann als `game` markiert (Eisengranate 5s statt 1s 85c). Einmalig gilt kein Händlerpreis mehr als bestätigt (`meta` `vendorRecheck`), Bridge 0.12 schickt alle Namen samt Preis aus dem Spiel neu.
  - **Daumen runter blendet aus:** Die letzte Bewertung je Gegenstand der letzten 14 Tage zählt (`latestRatings`). Daumen runter nimmt die Chance aus Vorschlägen, „Nur live erreichbar“ und der Liste für Broker, außer sie ist mit „An Broker“ angeheftet. Unter der Liste steht, welche ausgeblendet sind. Bewertung löschen oder Daumen hoch holt sie zurück.
  - **Spekulation schnell:** Der belegte Verkaufspreis zählt höchstens bis zum oberen Rand des üblichen Bereichs (Schmiedehammer: belegt etwa 5g bei Angeboten um 1s). Die Prüfliste nennt dann beide Werte. Neue Prüfung im Punkt „Kein neues Preisniveau nach unten“: Liegen die letzten 3 Tage 15 % oder mehr unter den Tagen 7 bis 14, gibt es keinen Vorschlag (`spec.trendOf`, Tageswerte im Kontext).
  - **Bemerkung länger:** bis 1000 Zeichen statt 250.
  - **Erfolgskontrolle:** Knopf „Behalte ich“ je Kauf aus Ledger, die markierten Käufe stehen eingeklappt darunter und lassen sich zurückholen (`meta` `ownUse`, je Gegenstand und Zeit, 60 Tage).
  - **Offen, mit KarloDerBaer abzustimmen:** Gold und Einsatz bei Chancen bewerten (Gold aus Broker, Menge nach Einsatz und möglichem Verlust), siehe Rückmeldung zu Muster: Lebendige Krone.
  - Tests: Deckel und Preisverlauf, Ausblenden mit Daumen runter und angeheftet, Schema 11, Behalte ich (`test/chancen.test.js`), Umzug des Datenordners (`test/datenordner.test.js`, neu). Länge der Bemerkung in `test/c6.test.js` angepasst. Alle 225 Tests grün, Oberfläche gebaut.
  - **Im echten Programm prüfen:** Start mit großer Datenbank (Einstellungen gleich bedienbar), Umzug auf D: über Einstellungen, Daten, Eisengranate nach dem nächsten Scan ohne Händler-Chance, Schmiedehammer und Imperiale Plattenrüstung ohne Vorschlag, Daumen runter blendet aus, Behalte ich.

## 0.35.1

Kurz: Händler-Chancen rechnen nur noch mit dem Händlerpreis aus dem Spiel. Ein Preis, den nur die Blizzard-API nennt, steht in der Prüfliste als nicht bestätigt.
Kurz: Rückmeldungen zu Chancen stehen zusätzlich unter Rückmeldungen und gehen mit „Senden“ mit, auch die schon geschriebenen.

- 0.35.1 (14.11.2026): Rückmeldung KarloDerBaer zur Vorabversion `v2026.11.13.5-test`: eine Händler-Chance mit komplett falschem Händlerpreis.
  - **Ursache:** Für Gegenstände, die der Manager nur aus den Ständen der Blizzard-API kennt, kam der Händlerpreis aus den Gegenstandsdaten der API (`sell_price`), oft aus den Classic-Daten, wenn Forever den Gegenstand nicht kennt. Die Händler-Chance hat damit gerechnet, als wäre es der Preis aus dem Spiel.
  - **Herkunft je Preis:** neue Spalte `items.vendor_src` (Schema 10), `game` aus dem Spiel, `api` aus der Blizzard-API. Ein Preis aus dem Spiel ersetzt einen aus der API, nie umgekehrt. Stände der API tragen ihre Namen mit dem Preis aus der Datenbank weiter und gelten dabei als `api` (`game.js`). Bisherige Werte gelten einmalig als aus dem Spiel, wenn der Gegenstand in einem eigenen Scan oder im Verlauf aus Broker vorkam.
  - **Händler-Chance** nur mit Preis aus dem Spiel (`chanceCtx.vendor`). Sonst steht in der Prüfliste „Händlerpreis nicht bestätigt: nur die Blizzard-API nennt …“ (`vendorApi`). Für die Einstellgebühr der Spekulation zählt auch der Wert aus der API.
  - **Rückmeldungen mitschicken:** Jede Rückmeldung zu einer Chance, aus dem Manager oder als Einschätzung aus Broker, steht einmal zusätzlich im Reiter Rückmeldungen (Bereich Chancen, Art Verbesserung) mit Gegenstand, Art, Bewertung, Bemerkung, Satz, Werten und Prüfliste, der Markt nur als Fraktion (`chancebook.feedbackText`). Ein Merker (`meta` `ratingsForwarded`, `takeNewRatings`) sorgt dafür, dass jede nur einmal kommt, auch die von vor 0.35.1. Neue Bereiche des Managers: Beobachten, Chancen, Marktübersicht, Erfolgskontrolle (statt Radar).
  - Tests: Herkunft des Preises bei Scan und API, Händler-Chance nur bestätigt, Text der Rückmeldung, Weitergabe einmal und auch für ältere (`test/chancen.test.js`). Alle 217 Tests grün.
  - **Im echten Programm prüfen:** Die falsche Händler-Chance ist weg oder steht in der Prüfliste als nicht bestätigt. Unter Rückmeldungen steht deine Rückmeldung zur Chance, „Senden“ schickt sie.

## 0.35.0

Kurz: Neue Seite Chancen statt Radar: eine Liste aller Kaufvorschläge mit einem Satz, warum, und einer Prüfliste zum Aufklappen.
Kurz: Spekulation schnell rechnet mit echten Verkaufspreisen aus der Blizzard-API und löst den Wiederverkauf ab. Die Preise sammelt der Manager ab jetzt, darum gibt es anfangs kaum Vorschläge.
Kurz: Neu sind der Steckbrief je Gegenstand, die Marktübersicht mit Prognosen, Stufenbereichen und Festen sowie die Erfolgskontrolle.
Kurz: Vorschläge lassen sich bewerten, je Gegenstand übersteuern und über Regler mit Probe anpassen. Kandidaten gehen an das Radar in Broker.

- 0.35.0 (13.11.2026): Chancen und Prognosen, alle Bauabschnitte K1 bis K9 (Konzept `docs/konzepte/manager/Peon_Manager_Chancen.md`, freigegeben 13.11.2026). Braucht für die Übergabe Bridge 0.11 und Broker 0.93.
  - **K1 Belegte Verkäufe (D1, D2):** Beim Vergleich zweier Stände der Blizzard-API hält `sales.compare` jeden Verkauf mit Preis, Stück und Angebotsnummer fest (`soldList`). Neue Datei `proof.js`: Tabellen `sale_px` (Stück je Tag und Preisstufe zu 2 %), `sale_life` (dazu die Stunden im Markt) und `auc_first` (erster Stand je Angebotsnummer, 3 Tage). F56 belegter Verkaufspreis, F58 Haltbarkeit. Ältere Tage lassen sich nicht nachrechnen. Prüfung P1 ergibt sich aus der Spalte Haltbarkeit nach einer Woche.
  - **K3 Kennzahlen und Seite Chancen:** Neue Datei `spec.js` mit Spekulation schnell (4.2), Händler mit Haltbarkeit (4.5, unter 1 Std. „nur live erreichbar“), Aufkauf-Kandidaten mit Brokers Regeln (4.4, `chances.buyout` mit `targetPct`, `minQty`, `minLevels`, `minSales`) und Spekulation langfristig (4.3). Jede Chance trägt ihre Prüfliste, daraus kommen Satz und „Warum nicht?“. Neue Datei `chance-client.js` hängt die Methoden an das Modul. Seite `views/Chances.vue` neu mit den Reitern Vorschläge, Nur live erreichbar, Rückmeldungen und Einstellen, Prüfliste `components/ChecksList.vue`, „Warum nicht?“ in der Suche und auf der Gegenstandsseite (`components/WhyNot.vue`). Die Übersicht zeigt „Beste Chancen jetzt“ aus der neuen Liste.
  - **K4 Steckbrief:** `views/Brief.vue` mit `components/BriefChart.vue` (Angebote als Linie, Verkäufe als Punkte, Zielpreis und Kaufen bis, Prognose als Fächer), Rechenweg, Haltbarkeit nach Standzeit, Raster nach Wochentag und Tageszeit, Feste, Prüfliste. Erreichbar aus Chancen, Marktübersicht, Erfolgskontrolle und Gegenstand.
  - **K5 Korrigieren:** Rückmeldung je Vorschlag (`components/RateDialog.vue`, Tabelle `chance_rate`), Einschätzungen aus Broker werden eingelesen (`chancebook.importBroker`), Datei für die Auswertung ohne Konto- und Charakternamen. Übersteuerung je Gegenstand (`meta` `chanceOverrides`: nie vorschlagen, Art aus, Zielpreis, Kaufen bis) mit Liste unter Einstellungen. Regler je Art mit Probe über die gespeicherten Vorschläge der letzten 14 Tage samt Rückmeldungen (`components/ChanceRules.vue`, `meta` `chanceRules`). Gespeichert werden dafür auch Beinahe-Vorschläge (`chance_log` mit `shown = 0`).
  - **K6 Übergabe an Broker:** `Data.lua` enthält je Markt `chances = { t, list, say }` mit höchstens 200 Einträgen, Format `Art:KaufenBis:Zielpreis:GültigBis:Gewinn:Risiko:Menge` (Menge als Erweiterung). Der Knopf „An Broker“ setzt einen Gegenstand sicher auf die Liste (`meta` `chancePinned`).
  - **K7 Prognosen:** Neue Datei `forecast.js` mit Reichweite (F60), Knappheit (F61), Schwemme (F62), Stufenbereich-Index (F63, F64) mit Rangliste, Sicherheit (F66) und Nachprüfung je Signal (F67, Tabelle `forecast_log`). Die benötigte Stufe aller Gegenstände (D3, Tabelle `item_level`) holt der Manager in Minuten ohne Abruf der Auktionshäuser nach, etwa 100 je Minute (`fetchLevels`). `snapindex` führt dazu die Menge je Tag. Neue Seite `views/Market.vue` (Marktübersicht) mit Prognosen, Fallend, Steigend, Lohnend, größten Änderungen, Stufenbereichen und Festen.
  - **K8 Feste und Wochenrhythmus:** Feste aus Broker (`PeonBrokerDB.feste`, `meta` `feste`, 400 Tage) und eigene Ereignisse (`meta` `events`), Signal Fest (F65), Raster nach Wochentag und Tageszeit (5.3) im Steckbrief.
  - **K9 Erfolgskontrolle:** `views/Success.vue` mit Trefferquote je Art und je Signal über 30 Tage samt Verlauf und den eigenen Käufen im Auktionshaus aus `Peon_Ledger.lua`.
  - **Entfallen:** Wiederverkauf (F50) und seine Trefferquote (F55), die Reiter Fallend, Steigend und Lohnend auf der Seite Chancen (jetzt Marktübersicht) und die Seite Radar (WIP). Die Rechenfunktionen dazu sind entfernt (`chances.scanOpp`, `updateMarket`, `summarizeOpp`, `hitRate`, `resetRules`, mit Zustimmung von KarloDerBaer), ebenso ihre sechs Tests in `test/vorschlag.test.js`. `opp_snap` und `opp_scan` werden nicht mehr gefüllt. Schema 9.
  - Tests: neue Datei `test/chancen.test.js` (11 Tests: D1 und D2, Vergleich mit Nummern, Spekulation schnell mit Satz und Übersteuerung, Händler nur live, Regler und Probe mit Rückmeldungen, Nachprüfung, Prognosen und Sicherheit, Stufenbereich, Stufe aus der API, Einschätzungen aus Broker). Test Chancen in `test/c6.test.js` auf die neue Seite umgestellt. Alle 215 Tests grün, Oberfläche gebaut.
  - **Im echten Programm prüfen:** Seite Chancen mit Satz und Prüfliste, „Warum nicht?“ in der Suche, Steckbrief, Marktübersicht (Stufenbereiche erst nach einigen Stunden mit Blizzard-Zugang), Erfolgskontrolle, Rückmeldung und Datei für die Auswertung, Regler mit Probe, Übersteuerung. Nach einer Woche: Spalte Haltbarkeit (Prüfung P1).

## 0.34.0

Kurz: Beträge gibst du jetzt wie im Spiel in Gold, Silber und Kupfer ein.
Kurz: Kaufen bis und Zielpreis aus dem Spiel stehen jetzt auch bei Beobachtungen, die du schon länger hast, und die Glocken lassen sich einschalten.
Kurz: Der Hinweis „wartet auf /reload“ verschwindet nach dem Neuladen zuverlässig, und Beobachten öffnet schneller.

- 0.34.0 (13.11.2026): Fehler aus dem ersten Test der Vorabversion `v2026.11.13-test` (Rückmeldung KarloDerBaer zu Beobachten).
  - **Grenzen kamen nicht an:** Beobachtungen aus der Zeit vor 0.30.0 kannten nur „beobachtet“. Ihre Zeiten je Wert kamen aus `u`, das gleich war wie im Spiel, darum gewannen die Grenzen aus dem Spiel nie. Ein Eintrag als Zahl bekommt jetzt die Zeit 0 für beide Werte (`watching.BARE_T`, gleich in Broker 0.90). Schon gespeicherte leere Werte ohne Eingabe im Manager repariert `repairWatchTimes` einmalig (`meta` `fixWatchT`), wartende leere Werte entfallen. Ohne Werte waren die Glocken gesperrt, das löst sich damit mit.
  - **Leere Änderung ohne Eingabe:** `setBuy` und `setUp` vermerken einen unveränderten Wert nicht mehr als Änderung. Vorher bekam etwa ein Wechsel der Einheit ohne Wert eine neue Zeit, und Broker hätte beim nächsten Laden eine Grenze gelöscht, die der Manager nicht kannte.
  - **„wartet auf /reload“ blieb stehen:** Das Laden im Spiel erkannte nur die Prüfung des Prozesses. Jetzt gilt zusätzlich: Speichert das Spiel seine Bridge-Datei, hat es danach `Data.lua` geladen (`importGame` setzt `gameLoadAt`).
  - **Langsam:** Die erste Eingabe nach dem Start (Stern, Grenze, Liste) rechnete alle Märkte neu, mit vielen Ständen der Blizzard-API mehrere Sekunden voller Arbeit. `writeBridge` nimmt jetzt die Werte aus dem letzten Einlesen oder aus der vorhandenen `Data.lua` (`marketsForBridge`). Beobachten bleibt beim Wechsel der Seite im Speicher (`KeepAlive`).
  - **Beträge in Gold, Silber, Kupfer:** neuer Baustein `components/MoneyInput.vue` mit drei Feldern und Münzen in den Farben des Spiels, für Kaufen bis und Zielpreis unter Beobachten und den Höchstpreis unter Einkaufen. Der Wert der Liste steht grau in den Feldern. Die Glocken nennen im Tooltip, warum sie gesperrt sind.
  - Tests: neue Datei `test/reparatur.test.js` (6 Tests mit dem Stand aus dem Test: alte Beobachtung, Reparatur, bewusst geleerte Werte, unveränderter Wert, keine Neuberechnung, Laden über die Bridge-Datei). Alle 210 Tests grün, Oberfläche gebaut.
  - **Im echten Programm prüfen:** Unter Beobachten stehen nach dem ersten Einlesen Kaufen bis und Zielpreis aus dem Spiel. Bei Blassblatt prüfen, ob Kaufen bis im Spiel noch 3s ist (siehe Stand). Eingabe in Gold, Silber, Kupfer, Glocken, „wartet auf /reload“ nach dem Neuladen, Wechsel der Seiten.

## 0.33.0

Kurz: Die Seite Einkaufen ist neu: Listen je WoW-Konto, Menge, Fehlt, Preis, Höchstpreis und Treffer, alles direkt in der Liste änderbar.
Kurz: Der Vorrat zählt jetzt wie im Spiel nur Taschen und Bank der Charaktere dieses Kontos.

- 0.33.0 (13.11.2026): Angleichung des Managers, Bauabschnitt A5 (Konzept `docs/konzepte/manager/Peon_Manager_Angleichung.md` 4.2). Nur der Manager. Damit ist Teil 1 des Konzepts gebaut.
  - **Seite Einkaufen** (`views/Shopping.vue` neu, ohne „(WIP)“): links die Listen des gewählten Kontos mit Anlegen, Name, Rabatt und Löschen, ein Punkt an Listen mit Änderungen, die noch nicht im Spiel sind. Rechts Gegenstand, Menge, Fehlt (Vorrat im Tooltip), Preis, Höchstpreis in einer Spalte (eigener Wert fett, sonst steht der Wert der Liste grau im Feld), Treffer, Entfernen. „wartet auf /reload“ an Zeilen. Auswahl des Kontos bei mehreren Konten. Darunter „Gelöscht“ und „Protokoll“ (A3), die unter dem WIP-Hinweis entfallen.
  - **Vorrat je Konto** (`ledgerStock(acct)`): nur `Peon_Ledger.lua` aus dem Kontoordner des gewählten Kontos, Taschen und Bank wie im Spiel. Vor dem ersten Konto mit Kennung wie bisher alle Ordner. Neu je Zeile `need` (Fehlt wie im Spiel: Menge minus Vorrat).
  - Tests: neue Datei `test/einkaufen.test.js` (3 Tests: Vorrat und Fehlt je Konto ohne Post, ohne Ledger, Zustand von Liste und Zeile). Alle 204 Tests grün, Oberfläche gebaut.
  - **Im echten Programm prüfen:** Seite Einkaufen mit echten Listen, Vorrat und Fehlt im Vergleich zum Spiel, eigenen Höchstpreis setzen und wieder leeren.

## 0.32.0

Kurz: Die Seite Beobachten ist neu: Preis, Kaufen bis, Zielpreis und Rat wie im Spiel. Die Grenzen änderst du direkt in der Liste.
Kurz: Mit den Glocken je Gegenstand meldet sich der Manager über Windows, wenn ein Preis Kaufen bis oder den Zielpreis erreicht.

- 0.32.0 (13.11.2026): Angleichung des Managers, Bauabschnitt A4 (Konzept `docs/konzepte/manager/Peon_Manager_Angleichung.md` 4.1 und 4.3). Nur der Manager.
  - **Seite Beobachten** (neu `views/Watch.vue`, ersetzt die eingegrenzte Gegenstandsliste, in der Seitenleiste „Beobachten“ wie im Spiel statt „Beobachtung (WIP)“): Gegenstand, Preis im letzten Stand des gewählten Markts, Kaufen bis (Gold oder % unter dem üblichen Preis, umschaltbar, bei % zeigt der Tooltip den Betrag), Zielpreis, Üblich, Rat (KAUFEN auf oder unter Kaufen bis, VERKAUFEN auf oder über dem Zielpreis), Glocken, Entfernen. Rat zuerst. Hinzufügen über die Suche oder den Stern. „wartet auf /reload“ an Zeilen, deren Änderung noch nicht im Spiel ist. Auswahl des Kontos bei mehreren Konten. Darunter „Gelöscht“ und „Protokoll“ (A3).
  - **Rechnung** (`watchRow`, `watchView`): Kaufen bis in % rechnet mit demselben Vergleichspreis wie die Einkaufsliste (Mittel der Woche, sonst Median).
  - **Glocken** je Gegenstand und Grenze, nur im Manager (`meta` `bells:<Kennung>`), bei neuen Einträgen aus, beim Entfernen gelöscht. Hauptschalter `watchNotify` (Standard an) oben auf der Seite.
  - **Meldung über Windows** (`watchCheck`, `notifyWatch` in `electron/main.js`): nach jedem neuen Stand und nach Eingaben, für alle Konten und Märkte. Einmal je Überschreiten, wieder erst nach einem Preis auf der anderen Seite, ohne Preis im Stand bleibt der Zustand. Die Meldung nennt Markt und bei mehreren Konten den Namen des Kontos. Ein Klick wählt das Konto und öffnet Beobachten mit der Zeile.
  - Tests: neue Datei `test/beobachten.test.js` (4 Tests: Ansicht und Rat, Glocken und Meldungen, je Konto, Eingaben). Alle 201 Tests grün, Oberfläche gebaut. `test/ui/shots.js` klickt auf „Beobachten“.
  - **Im echten Programm prüfen:** Seite Beobachten mit echten Daten (Preise, Rat, Üblich), Kaufen bis zwischen Gold und % umschalten, Glocke an, Meldung nach dem nächsten Stand der Blizzard-API, Klick auf die Meldung.

## 0.31.0

Kurz: Unter Einkaufen und Beobachtung siehst du jetzt, was der Abgleich mit dem Spiel getan hat, und kannst Gelöschtes 30 Tage lang wiederherstellen.

- 0.31.0 (13.11.2026): Angleichung des Managers, Bauabschnitt A3 (Konzept `docs/konzepte/manager/Peon_Manager_Angleichung.md` 3.3 bis 3.6). Nur der Manager.
  - **Protokoll** (Tabelle `sync_log`, 90 Tage): Jede Änderung an Einkaufslisten und Beobachtung mit Zeit, Konto, Herkunft (aus dem Spiel, im Manager, beide geändert), Liste, Gegenstand, Wert, alt und neu. Erkannt über den Vergleich vor und nach dem Abgleich (neue Datei `synclog.js`: `diffShop`, `diffWatch`).
  - **Beide geändert:** Hat der Manager einen Wert geändert, den das Spiel noch nicht bestätigt hat, und bringt das Spiel denselben Wert anders, steht das als ein Eintrag „beide geändert“ mit beiden Werten im Protokoll und welcher gilt (`checkPending`). Hat das Spiel gewonnen, entfällt die normale Zeile für diesen Wert.
  - **Zustand je Zeile:** Eingaben im Manager werden je Konto gemerkt (`meta` `pend:<Kennung>`), bis `Peon_Broker.lua` sie bestätigt, höchstens 60 Tage. Bis zum nächsten Laden im Spiel gelten sie als wartend: `shopView` gibt je Liste und Eintrag `wait`, der Zähler in der Kopfleiste zählt sie (statt `shopping.pending`).
  - **Gelöscht** (Tabelle `sync_trash`, 30 Tage): Was im Spiel oder im Manager gelöscht wird, lässt sich wiederherstellen (`restoreTrash`). Wiederherstellen legt den Eintrag mit neuer Zeit wieder an, er geht so auch ins Spiel. Ein Gegenstand einer gelöschten Liste braucht zuerst die Liste.
  - **Anzeige:** neuer Baustein `components/SyncPanel.vue` mit „Gelöscht“ und „Protokoll“ (Filter nach Herkunft), vorerst unter den WIP-Hinweisen der Seiten Einkaufen und Beobachtung. A4 und A5 übernehmen ihn in die neuen Seiten und zeigen den Zustand je Zeile.
  - Datenbank Schema 8. `prune` räumt Protokoll und Gelöschtes mit auf.
  - Tests: neue Datei `test/nachvollziehen.test.js` (6 Tests: Eingabe und Bestätigung, Änderung aus dem Spiel, beide geändert in beide Richtungen, Wiederherstellen von Gegenstand und Liste, Beobachtung mit Grenzen, Aufbewahrung). Alle 197 Tests grün, Oberfläche gebaut.
  - **Im echten Programm prüfen:** Unter Einkaufen (WIP) und Beobachtung (WIP) „Gelöscht“ und „Protokoll“ aufklappen. Im Spiel einen Eintrag löschen, `/reload`: Er steht unter Gelöscht und lässt sich wiederherstellen, nach dem nächsten `/reload` ist er im Spiel.

## 0.30.0

Kurz: Änderst du an einer Einkaufsliste im Spiel und im Manager verschiedene Werte, bleiben jetzt beide erhalten.
Kurz: Der Manager kennt jetzt Kaufen bis und Zielpreis deiner Beobachtung aus dem Spiel.

- 0.30.0 (13.11.2026): Angleichung des Managers, Bauabschnitt A2 (Konzept `docs/konzepte/manager/Peon_Manager_Angleichung.md` 3.2 bis 3.4). Braucht Broker 0.89.
  - **Abgleich je Wert** (`shopping.js`): gleiche Regeln wie Brokers `Shop.lua` 0.89 (`fieldT`, `fill`, `stamp`, `newFrom`, `mergeFields`). Name und Rabatt einer Liste, Menge und Höchstpreis eines Eintrags mit eigener Zeit in `t`. Ohne `t` gilt `u`. `setItem` und `updateList` vermerken nur die geänderten Werte, `forGame` gibt `t` der Liste mit.
  - **Beobachtung mit Grenzen** (neue Datei `watching.js`): Einträge `{ u, lim, pct, up, t: { buy, up }, name, q, icon }` statt nur der Zeit. Abgleich je Wert wie `Wt.Merge` in Broker. Neu im Broker Client `setWatchBuy(key, kind, value)` und `setWatchUp(key, value)` (für die Seite Beobachten in A4). Eine Zahl von früher gilt als Eintrag nur mit `u`. Der Stern legt Name und Qualität mit an.
  - Aus `Peon_Broker.lua` liest der Manager jetzt den ganzen Eintrag der Beobachtung (ohne die Merker des Alarms).
  - **Löschmarken halten ein Jahr** statt 60 Tage, bei Listen und Beobachtung.
  - Tests: neue Datei `test/je-wert.test.js` (6 Tests, darunter 3000 Zufallsfälle gegen `Watch.lua` über `test/lua/watch_compare.lua` und der Weg der Grenzen ins Spiel und zurück), der Vergleich mit `Shop.lua` jetzt mit 3000 Fällen und Zeiten je Wert. Alle 191 Tests grün, Oberfläche gebaut.
  - **Im echten Programm prüfen:** zusammen mit A3 bis A5, weil die Grenzen erst die Seite Beobachten zeigt.

## 0.29.0

Kurz: Einkaufslisten und Beobachtung gelten jetzt je WoW-Konto, wie im Spiel. Unter Datenlage siehst du deine Konten, gibst ihnen einen Namen und wählst, welches Konto der Manager zeigt.

- 0.29.0 (13.11.2026): Angleichung des Managers, Bauabschnitt A1 (Konzept `docs/konzepte/manager/Peon_Manager_Angleichung.md` 3.1 und 6). Braucht Broker 0.85 und Bridge 0.10.
  - **Konten:** Broker legt je WoW-Konto eine Kennung an. Der Manager merkt sich je Kontoordner die Kennung (`meta` `acctFolders`) und je Kennung einen eigenen Namen (`accts`). Einkaufslisten stehen je Konto in `meta` `shop:<Kennung>`, die Beobachtung in `watch:<Kennung>` (bisher Tabelle `favorites`).
  - **Abgleich je Konto:** Was aus einem Kontoordner kommt, mischt nur in dieses Konto. `Data.lua` schreibt `accts = { [Kennung] = { shop, watch } }` statt `shop` und `watch` oben. Ein Ordner mit Broker ohne Kennung gleicht nichts mehr ab, sobald es ein Konto mit Kennung gibt. Steht dieselbe Kennung in zwei Ordnern (kopierter Ordner), gilt nur der zuletzt gespeicherte, die Datenlage zeigt einen Hinweis.
  - **Gewähltes Konto:** Stern, Einkaufslisten im Gegenstandsfenster und die Seiten zeigen das gewählte Konto (`meta` `acctSel`), ohne Wahl das zuletzt gespielte. Meldungen der Einkaufsliste und die Bestellung genauer Werte gelten für alle Konten.
  - **Datenlage, neuer Abschnitt Konten:** Auswahl, eigener Name, Ordner, Charaktere aus `Peon_Ledger.lua`, Zahl der Listen und Beobachtungen, zuletzt gespielt. Dazu Ordner, die noch keine Kennung haben.
  - **Umstellung:** Der bisherige gemischte Stand geht ganz an das erste Konto mit Kennung, also an das Konto, in dem nach dem Update zuerst gespielt wird (`meta` `acctMigrated`, Eintrag im Protokoll). Weitere Konten beginnen mit dem, was ihr Spiel liefert. Der alte Stand bleibt unverändert in der Datenbank. Bis zum ersten Konto mit Kennung arbeitet der Manager wie bisher.
  - **Behoben nebenbei:** Eine Eingabe in der Einkaufsliste schrieb `Data.lua` ohne die Beobachtung, ein Stern schrieb `Data.lua` gar nicht neu. Jetzt schreiben beide sofort alles (`writeBridge`).
  - Tests: neue Datei `test/konten.test.js` (6 Tests: vor dem ersten Konto, Umstellung, Auswahl, Abgleich je Konto, dieselbe Kennung in zwei Ordnern, Datenlage), `umbau2.test.js` auf `accts` umgestellt. Alle 185 Tests grün, Oberfläche gebaut.
  - **Im echten Programm prüfen:**
    1. Nach dem ersten `/reload` mit Broker 0.85 erscheint das Konto unter Datenlage, Konten. Die bisherigen Einkaufslisten und die Beobachtung sind dort.
    2. Nach einem weiteren `/reload` stehen Listen und Beobachtung wie gewohnt im Spiel.
    3. Name vergeben, bei mehreren Konten die Auswahl wechseln: Der Stern zeigt die Beobachtung des gewählten Kontos.

## 0.28.0

Kurz: Einkaufen, Beobachtung, Radar und Händler werden überarbeitet und sind derzeit nur im Spiel verfügbar.

- 0.28.0 (12.11.2026): **Vier Seiten in Überarbeitung** (Rückmeldung KarloDerBaer nach der Vorabversion v2026.11.12-test). Einkaufen, Beobachtung, Radar und Händler heißen in der Seitenleiste „(WIP)“ und zeigen nur „Überarbeitung notwendig! Derzeit nur im Spiel verfügbar.“ (`wip` in der Liste `ALL` in `App.vue`). Der Abgleich der Beobachtung mit dem Spiel und die Meldung von Windows für die Einkaufsliste laufen weiter.
  - **Im echten Programm prüfen:** Seitenleiste und die vier Seiten.

## 0.27.0

Kurz: Das Update-Fenster zeigt je Teil eine kurze Anmerkung und die Punkte Neu, Geändert, Behoben und Entfernt, wie im Text des Release auf GitHub.

- 0.27.0 (12.11.2026): **Was ist neu wie im Release.** Das Release-Skript schreibt je geändertem Teil `release = { from, note, items }` ins Manifest (aus `docs/releases/*.md`, `from` = Version des letzten normalen Release).
  - `addons.js`: `releaseFor` prüft die Angabe (nur die vier Arten, Text gekürzt wie die kurzen Texte, sortiert nach Art). Wer vor `from` stehen geblieben ist, bekommt die kurzen Texte der übersprungenen Versionen bis `from` als `older` dazu. Ohne Angabe (älteres Manifest) `null`.
  - Neue Komponente `components/ReleaseText.vue` im Update-Fenster und unter „Was ist neu“ in der Ansicht Module: Anmerkung, Punkte mit farbiger Art, darunter „Davor:“ mit den kurzen Texten. Ohne Angabe wie bisher die kurzen Texte.
  - Sichtbar erst ab dem Update nach 0.27.0, weil das Fenster immer der installierte Manager zeichnet.
  - Tests: neuer Test „Text des Release“ in `addons.test.js`.
  - **Im echten Programm prüfen:** Update-Fenster und „Was ist neu“ beim ersten Update nach 0.27.0.

## 0.26.0

Kurz: Die Seiten heißen jetzt wie im Spiel: Markt, Einkaufen, Beobachtung, Radar, Händler und Datenlage.
Kurz: Im Radar zeigt der neue erste Reiter „Aufkauf“ dieselben Chancen wie Broker im Spiel: Massenware bis zu einer Preisstufe kaufen und zum Preis der nächsten Stufe wieder einstellen, mit Ampel für das Risiko.

- 0.26.0 (12.11.2026, Neuaufbau Broker H5, Konzept `docs/konzepte/broker/Peon_Broker_Neuaufbau.md` Abschnitt 8): **Seiten und Begriffe wie im Spiel.**
  - **Seitenleiste:** Übersicht, Markt (bisher Gegenstände), Einkaufen (bisher Einkaufsliste, weiter mit „WIP“), Beobachtung (jetzt direkt unter Einkaufen, im Spiel eine Liste in Einkaufen), Radar (bisher Chancen), Händler, Datenlage (bisher Quellen). Überschriften, Hinweise in der Einrichtungsliste, beim Blizzard-Zugang und auf der Übersicht mitgezogen. Die Bereiche für Rückmeldungen heißen entsprechend (`reports.js`), alte Rückmeldungen behalten ihren Bereich.
  - **Radar, Reiter „Aufkauf“** (neu, zuerst gewählt): gleiche Regel wie Broker 0.65.0 (`chances.buyout`, `buyoutFor`): je Massenware die Stelle zwischen zwei Preisstufen mit dem höchsten Gewinn (Menge × Ziel × 0,95 − Einsatz), mindestens 50 Silber, verkauft sich beim Absatz des Managers in höchstens 2 Std., kein neues Preisniveau nach unten (F54). Gerechnet auf dem letzten Stand (Scan oder Blizzard-API) mit allen Angeboten. Das Gold des Charakters kennt der Manager nicht, darum ohne Grenze für den Einsatz. Spalten Gegenstand, Gewinn, Kaufen bis, Menge, Einsatz, Ziel, Verkauft in, Risiko (Tooltip mit den Gründen). Sortiert nach Gewinn, rotes Risiko unten.
  - **Reiter danach:** Händler, dann Wiederverkauf, Fallend, Steigend, Lohnend wie bisher. Im Spiel gibt es Wiederverkauf nicht mehr (Konzept Abschnitt 6.1), im Manager bleibt er vorerst. Ob er wegfällt, entscheidet KarloDerBaer.
  - Tests: `test/aufkauf.test.js` (3 Tests: Rechnung, jede Bedingung, Risiko und Sortierung), `c6.test.js` prüft den Aufkauf im Ergebnis von `chances`. Alle 178 Tests grün, Oberfläche gebaut (`npm run build`). Die Bildschirmfotos (`npm run shots`) brauchen eine private Datendatei (`test/fixtures/Peon_Bridge_echt.lua`), die nicht im Repo liegt, darum nicht erstellt. `test/ui/shots.js` klickt auf die neuen Namen.
  - **Im echten Programm prüfen:**
    1. Seitenleiste mit den neuen Namen und der neuen Reihenfolge.
    2. Radar, Reiter Aufkauf: Liste mit echten Daten. Passen die Treffer zu dem, was Broker im Spiel zeigt (bis auf das Gold)?
    3. Tooltip der Ampel, Sortierung, Filter „Gewinn ab … Silber“.

## 0.25.0

Kurz: Neue Seite „Händler“: Alles, was Broker im Spiel bei Händlern gesehen hat, mit Ort, Voraussetzungen und dem Preis im Auktionshaus.

- 0.25.0 (09.11.2026, Umbau Broker U11): **Händler.** Der Manager liest `PeonBrokerDB.vendors` aus `Peon_Broker.lua` (Broker 0.52.0), je Händler gewinnt der neuere Besuch (`meta` `vendors`). Seite `views/Vendors.vue` unter Broker: Suche, Auswahl der Zone, „Nur mit AH-Gewinn“, Spalten Gegenstand, Preis (Gold oder andere Währung), Händler, Zone mit Koordinaten, Braucht, AH (grün, wenn das Auktionshaus nach 5 % Anteil mehr bringt). Klick öffnet den Gegenstand. Aufruf `vendors(market)`, `vendorView` im Broker Client.
  - **Im echten Programm prüfen:** Nach einem Händlerbesuch und `/reload` im Spiel erscheint der Händler auf der Seite.

## 0.24.0

Kurz: Favoriten heißen jetzt Beobachtung und werden mit dem Spiel abgeglichen: Was du im Spiel beobachtest, steht auch im Manager, und umgekehrt.

- 0.24.0 (09.11.2026, Umbau Broker U8): **Beobachtung.** Seite, Stern und Texte heißen „Beobachtung“ statt „Favoriten“ (intern weiter `favorites`). Der Manager liest die Beobachtung aus `Peon_Broker.lua` (`watch`, `watchGone`) und schreibt seine als `watch = { items, gone }` in `Data.lua` (Bridge 0.9.0, Broker 0.49.0). Je Gegenstand gewinnt die neuere Änderung, entfernte Einträge bekommen eine Löschmarke (`meta` `watchGone`, verfällt nach 60 Tagen). Preisgrenzen und Alarm bleiben vorerst im Spiel.
  - **Im echten Programm prüfen:** Stern setzen, Spiel neu laden: steht der Gegenstand in Brokers Beobachtung? Im Spiel beobachten, Reload: Stern im Manager gesetzt?

## 0.23.0

Kurz: Der Manager bleibt jetzt flüssig, auch wenn er gerade neue Daten einliest und auswertet. Vorher hing das Fenster danach teils mehrere Sekunden.
Kurz: Neue Daten sind außerdem viel schneller ausgewertet, etwa eine halbe Sekunde statt mehrerer Sekunden.

- 0.23.0 (09.11.2026, KarloDerBaer: Fenster hing mehrere Sekunden, „Keine Rückmeldung“): **Arbeitsprozess.** Nach jedem neuen Stand (Blizzard-API stündlich, Scan, `/reload`, Ausloggen) rechnet das Modul Peon Broker Client alle Märkte neu: Absatz, üblicher Bereich, Chancen, Gegenstandsliste. Das lief im Hauptprozess, gemessen mit Kopien der echten Spieldaten und 120 Stunden nachgebildeter Blizzard-Stände (rund 57.000 Angebote je Stand) etwa 10 Sek. am Stück, solange reagierte das Fenster nicht. Jetzt läuft das ganze Modul in einem eigenen Thread (`src/core/broker-worker.js`), der Hauptprozess spricht über `src/core/broker-remote.js` mit ihm. Jeder Aufruf liefert ein Promise, Einstellungen gehen bei jedem Aufruf mit, gespeicherte Einstellungen (Blizzard-Häuser) kommen als Nachricht zurück. Ein Blizzard-Zugang geht als einfache Daten hinüber, der Thread baut seinen eigenen Client. Stürzt der Thread ab, startet er beim nächsten Aufruf neu, der Fehler steht im Protokoll.
  - `Service` nimmt `brokerFactory` (Programm: Thread, Tests: direkt). `overviewAsync()` für das Programm, `overview()` bleibt für die Tests. Sicherung über `backupTo()` im Thread.
  - Im fertigen Programm liegt `src/core` zusätzlich entpackt (`asarUnpack`), weil Threads nicht aus `app.asar` laden.
  - Tests: `test/worker.test.js` (Einlesen, Data.lua, Ansichten, Übersicht, Einstellungen hin und zurück, Fehler, Sicherung, Hauptteil bleibt frei). Selbsttest im gebauten Programm mit den Testdaten erfolgreich.
- **Schneller rechnen** (`src/core/snapindex.js`): Gegenstandsliste und Tageswerte für den üblichen Bereich lasen bei jedem neuen Stand alle Zeilen aus `item_snap` (gemessen 4,4 Sek. und 1,8 Sek. bei rund 400.000 Zeilen). Jetzt liest ein Zwischenspeicher im Arbeitsprozess den Verlauf einmal und nimmt danach nur die Zeilen neuer Momentaufnahmen dazu. Ändert sich die Zahl der Zeilen anders (Aufräumen, Verdichten), liest er neu, ebenso an einem neuen Tag. Der Absatz je Markt wird einmal je Stand gerechnet statt zweimal. Ein neuer Stand kostet damit etwa 0,6 Sek. statt 7 Sek.
  - Tests: `test/snapindex.test.js` vergleicht Zwischenspeicher und Abfragen über 16 Tage Scans, Live-Abfragen und Broker-Verlauf, nach neuen Ständen, nach dem Verdichten zu Stundenwerten und über einen Tageswechsel.

## 0.22.1

Kurz: Der neutrale Markt aus Broker erscheint als „PvE Neutral“ und bekommt beim Vorschlag unter Quellen das neutrale Haus.

- 0.22.1 (09.11.2026): Der Vorschlag unter Quellen kennt jetzt auch Märkte `<Realm> / Neutral` (Broker 0.40.0). Mit eigenem Scan entscheidet der Vergleich mit den neutralen Häusern, sonst der Regelsatz (Normal: Haus 117 in der EU).
  - Tests: `test/blizzard-import.test.js` um den Vorschlag für einen Scan am neutralen Haus erweitert.

## 0.22.0

Kurz: Chancen zeigen nur noch, was der letzte Scan ergeben hat, mit den Preisen aus diesem Scan.
Kurz: Keine Chance mehr, wenn man dafür den halben Markt leer kaufen müsste oder der Preis zu stark schwankt. Auf der Gegenstandsseite steht dann „Das ist der Marktpreis“.
Kurz: Im Verlauf eines Gegenstands liegen Preis und Menge jetzt auf derselben Zeitachse.

- 0.22.0 (08.11.2026, Wunsch KarloDerBaer, Beispiele Robuster Stein und Umhang des Hügelwächters, Rechenmodell Kapitel 10):
  - **Menge unter dem Ziel (F50b):** Wiederverkauf nur, wenn unter dem Verkaufsziel höchstens so viel Ware liegt, wie an einem Tag verkauft wird (`chances.DEPTH`, geprüft ab Absatz-Stufe 2). Beispiel Robuster Stein: 1.680 Stück unter dem Bereich bei 210 am Tag, also 8 Tage Vorrat. Das ist der Marktpreis, keine Chance. Die Gegenstandsseite sagt dann „Das ist der Marktpreis: Unter dem üblichen Bereich liegen … Stück, so viel wie in … Tagen verkauft wird“ (`itemDepth` aus dem letzten Scan).
  - **Unsicherer Bereich (F50c):** Bei einer Schwankung über 40 % (`chances.UNSURE`) gibt es keinen Wiederverkauf. Die Gegenstandsseite sagt „Der Preis schwankt stark …“ statt einer Prozentzahl, in der Gegenstandsliste ist „Zu üblich“ grau. Beispiel Umhang des Hügelwächters: Nach mehreren Tagen Preisverfall reichte der Bereich von 10s bis 95s.
  - **Neues Preisniveau früher (F54):** Es reichen 12 Std. statt 24 Std. (mindestens 3 Stände über 6 Std.). Beim Robusten Stein lag 23 Std. vorher noch ein Stand im Bereich, deshalb griff die Regel nicht.
  - **Chancen nur aus dem letzten Scan:** Wiederverkauf und Händler zeigen nur Gegenstände, die im letzten Scan eine Chance sind, mit Einkauf, Verkauf, Stück und Gewinn aus diesem Scan. Bisher waren es alle Treffer des Zeitraums mit Mittelwerten über alle Tage, dadurch standen Gegenstände mit alten Preisen in der Liste. Der Zeitraum zählt nur noch, wie oft der Gegenstand schon eine Chance war (Spalte „In Scans“, früher „Treffer“, nicht zu verwechseln mit der Trefferquote) und wann meistens.
  - **Diagramm:** Preis und Menge haben dieselbe Zeitachse. Bisher passte sich jede Achse ihren eigenen Daten an (Bereich als Treppe bis Tagesende, Absatz je Tag als Tagespunkt), so lagen beide gegeneinander verschoben. Bei weniger als 2 Tagen stehen Uhrzeiten an der Achse.
  - `chances.RULES` jetzt 3: Die Wiederverkaufs-Treffer werden nach dem Update neu gerechnet, die Trefferquote beginnt neu.
  - Tests: `test/vorschlag.test.js` erweitert (F50b, F50c, Tabelle aus dem letzten Scan, Satz auf der Gegenstandsseite), F54-Test auf 12 Std. umgestellt.

## 0.21.1

Kurz: „Beste Chancen jetzt“ zeigte nach dem Update noch Chancen nach den alten Regeln, zum Beispiel Robuster Stein. Diese werden jetzt verworfen und neu gerechnet.

- 0.21.1 (08.11.2026, Hinweis KarloDerBaer, Robuster Stein: Min 3s 85c, Median 3s 98c, trotzdem „Wiederverkauf, 1.987 Stück, 110g“): Die Treffer für Wiederverkauf werden je Scan einmal gerechnet und gespeichert (`opp_snap`). Der letzte Scan war noch mit 0.20.1 ausgewertet. Neu `chances.RULES` (Stand der Regeln, jetzt 2) und `resetRules`: Ändern sich die Regeln, löscht der Manager alle Wiederverkaufs-Treffer und wertet den letzten Scan jedes Markts neu aus (Eintrag im Protokoll). Die Trefferquote beginnt damit neu und misst nur die neuen Regeln. Die Ansicht Chancen und die Übersicht werten außerdem noch nicht ausgewertete Scans gleich aus.

## 0.21.0

Kurz: Weniger falsche Schnäppchen. Liegen alle Angebote gleich tief oder ist ein Preis seit einem halben Tag gefallen, meldet der Manager kein Schnäppchen mehr, sondern sagt, dass der Preis gefallen ist.
Kurz: Unter Chancen steht beim Wiederverkauf jetzt eine Trefferquote: Wie oft ist der Preis nach einem Vorschlag wirklich wieder gestiegen?

- 0.21.0 (08.11.2026, Wunsch KarloDerBaer, Beispiel Magicusmantel: Preis in 3 Tagen von 4g auf 1g 20s gefallen, Meldung „68 % unter dem üblichen Preis“, Rechenmodell Kapitel 10):
  - **Kürzung nach unten (F37a, `longterm.js`):** Tageswerte werden nach unten erst ab 75 % unter der Mitte gekürzt. Bisher hat die Kürzung bei wenigen gleichen Tagen (Schwankung 5 %) einen echten Preissturz abgeschnitten. Gleich in Broker 0.38.0.
  - **Neues Preisniveau (F54, `longterm.shifts`):** Liegen alle Stände der letzten 24 Std. unter (über) dem üblichen Bereich, mindestens 3 Stände über mindestens 12 Std., gilt der Bereich als veraltet. Die Gegenstandsseite sagt dann „Der Preis ist gefallen“ und vergleicht mit dem Median dieser Stände. In der Gegenstandsliste steht bei „Zu üblich“ ein Pfeil, die Farbe entfällt. Chancen zeigen für den Gegenstand keinen Wiederverkauf.
  - **Abstand zu den anderen Angeboten (F50a):** Wiederverkauf unter Chancen höchstens zum Median der Angebote im selben Scan (wie Broker, das höchstens zum nächsten Angebot verkauft). Auf der Gegenstandsseite ist der Satz nur grün, wenn das günstigste Angebot mindestens 20 % unter dem Median der aktuellen Angebote liegt. Sonst heißt es „…, die anderen Angebote aber auch“.
  - **Trefferquote (F55, `chances.hitRate`):** Unter Chancen, Wiederverkauf: Für die Vorschläge von vor 3 bis 17 Tagen (je Gegenstand einmal am Tag) wird geprüft, ob der Median der Angebote danach innerhalb von 3 Tagen das Verkaufsziel erreicht hat, nur Kaufpreis plus Gebühr oder nicht. Damit lassen sich die Grenzwerte später mit echten Ergebnissen einstellen.
  - Tests: `test/vorschlag.test.js` neu, Chancen-Test angepasst (die meisten Angebote liegen jetzt im Bereich, Seidenstoff 900 auf 300 zählt jetzt als fallend).

## 0.20.1

Kurz: Unter Einstellungen bei der Blizzard-API steht jetzt ein Link zum Beantragen des Zugangs. Nach dem Speichern erklärt ein Hinweis, dass ein neuer Zugang erst nach ein paar Minuten funktioniert und unter Quellen mindestens ein Auktionshaus gewählt sein muss.

- 0.20.1 (07.11.2026, Wunsch KarloDerBaer, `components/BlizzardCheck.vue`):
  - **Link zum Entwicklerportal** immer sichtbar unter dem Einleitungstext, „Zugang bei Blizzard beantragen“ bzw. mit gespeichertem Zugang „Zugang bei Blizzard verwalten“. Bisher nur in Schritt 2 der Anleitung.
  - **Hinweis Wartezeit:** Nach dem Speichern steht dort, dass ein neuer Zugang bei Blizzard oft erst nach ein paar Minuten funktioniert und eine Prüfung gleich danach fehlschlagen kann. Der Hinweis bleibt, bis eine Prüfung Angebote liefert. Ohne Prüfung zeigt er sich auch bei schon gespeichertem Zugang.
  - **Hinweis Auktionshaus:** Ist ein Zugang gespeichert, aber unter Quellen kein Haus gewählt, steht dort, dass mindestens eines nötig ist, mit Knopf „Zu den Quellen“. Fehlt der Peon Broker Client, führt der Knopf zu Updates.

## 0.20.0

Kurz: Der Manager sucht jetzt alle 10 Minuten nach Updates und meldet sich über Windows, wenn es Neues gibt. Beides stellst du unter Einstellungen ein.

- 0.20.0 (07.11.2026, Wunsch KarloDerBaer, weil es gerade häufig Updates gibt):
  - **Suche im eingestellten Abstand:** Einstellung `updateCheckMin` (10, 30, 60 oder 360 Minuten, Standard 10) unter Einstellungen, Abschnitt Updates. Bisher fest alle 6 Stunden. Der Manager sieht jede Minute nach, ob der Abstand um ist, eine geänderte Einstellung gilt also gleich.
  - **Meldung von Windows:** Einstellung `updateNotify` (Standard an). Findet die Suche eine neue Version eines Addons, kommt eine Meldung mit Namen und Versionen. Der Manager selbst wird gemeldet, sobald er geladen ist und neu starten kann. Jede Version nur einmal je Programmlauf. Zeigt der Start ohnehin das Update-Fenster, meldet die erste Suche nichts. Ein Klick auf die Meldung öffnet das Fenster des Managers mit dem Update-Fenster.
  - Neuer Test `test/updates.test.js`.

## 0.19.0

Kurz: Beim Update des Peon Managers siehst du jetzt, was passiert: Ein Fenster zeigt den Fortschritt, danach startet der Manager von selbst neu.
Kurz: Vor dem Senden deiner Rückmeldungen erscheint der Text in einem eigenen Fenster.

- 0.19.0 (07.11.2026, Wunsch KarloDerBaer):
  - **Selbst-Update sichtbar:** Nach „Neu starten“ zeigt das Update-Fenster drei Sekunden lang die Schritte (geladen, Manager wird geschlossen, neue Version wird eingespielt, Neustart). Danach läuft der Installer sichtbar mit seinem Fortschrittsbalken und deutschen Texten (`nsis.include` = `electron/installer.nsh`, `installerLanguages` de_DE) und startet den Manager wieder. Bisher lief er unsichtbar, und der Manager war eine halbe Minute ohne Hinweis weg. Der Selbsttest spielt weiter unsichtbar ein.
  - **Senden im Dialog:** Die Vorschau vor dem Senden im Reiter Rückmeldungen erscheint in einem eigenen Dialog (`components\SendDialog.vue`) mit Hinweis, Text, Senden und Abbrechen. Ein Fehler beim Senden steht im Dialog.
  - Lokal gebaut: Der Installer baut mit den neuen Einstellungen. **Noch nicht geprüft:** echtes Update von 0.18.1 auf 0.19.0 mit sichtbarem Installer (erst mit dem nächsten Release möglich), Dialog im echten Programm.

## 0.18.1

Kurz: Der Reiter Einkaufsliste ist als „WIP“ markiert, er wird bald überarbeitet.

- 0.18.1 (07.11.2026, Wunsch KarloDerBaer): Reiter und Überschrift „Einkaufsliste (WIP)“.

## 0.18.0

Kurz: Die Preise aus dem neuesten Stand der Blizzard-API gehen jetzt auch ins Spiel. Broker nutzt sie, wenn sie neuer sind als dein letzter Scan.

- 0.18.0 (07.11.2026, Wunsch KarloDerBaer): `Data.lua` enthält je Markt zusätzlich `cur` mit den aktuellen Preisen des neuesten vollständigen Stands (Blizzard-API oder Scan): Zeit `t`, Herkunft `src` (`api` oder `scan`) und je Gegenstand `"min:median:menge:angebote"`. Ein neuer API-Stand ändert damit `Data.lua`, sie wird nach jedem Abruf neu geschrieben. Die Datei wird je nach Markt einige hundert KB größer. Braucht Peon_Bridge 0.7.0 und Peon_Broker 0.36.0, ältere Fassungen übergehen `cur`.

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
