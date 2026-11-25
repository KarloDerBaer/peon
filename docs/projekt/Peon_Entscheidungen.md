# Peon – Entscheidungen

Kurzes Protokoll wichtiger Entscheidungen. Neue Einträge oben anfügen (Datum, Entscheidung, Grund).
Ältere Einträge (September und Oktober 2026): `docs/archiv/Peon_Entscheidungen_bis_2026-10.md`.

## 25.11.2026: Kontrollrechnung ohne Auktionsliste (Ledger 0.18.1)

- **Für Kosten und Handelsgewinn zählen nur Einstellen und Post** (KarloDerBaer fragte, wozu die Liste nötig ist): Was im Auktionshaus liegt, folgt aus eingestellt, zurück und verkauft. Die Liste des Spiels kam nach dem Einstellen teils ohne die neue Auktion. Dann buchte die Kontrollrechnung gekaufte Ware als fehlend aus und der Verkauf wurde Beute (914 Dickes Leder). Die Liste bleibt nur für die Anzeige und die frühe Meldung eines Verkaufs.
- **Höchstens der ganze Bestand gilt als eingestellt** (Claude): Ältere Daten enthalten mehr Eingestelltes als Bestand. Ohne Grenze hätte die Rechnung dafür ein Plus ohne Kosten gebucht, und spätere Verkäufe wären wieder Beute geworden.
- **In Forever kommt alles außer dem Einstellen per Post** (KarloDerBaer): Kauf, Abbruch und Erlös. Ein Zugang am Auktionshaus ist also immer Post. Ledger merkt sich deshalb jeden Abbruch und ordnet einen Brief ohne geladenen Betreff zuerst diesem Abbruch zu, erst dann einem offenen Kauf.
- **Verkauf in der Auktionsliste bucht nichts mehr** (KarloDerBaer): Nur die Post bucht, die Liste dient der Anzeige. Die frühe Meldung und die spätere Rechnung passten nicht immer zusammen (118 Dickes Leder). Gemerkt wird der Verkauf nur noch, damit ein Brief ohne geladene Rechnung seine Menge bekommt.
- **Alte Fälle einmal korrigieren** (Claude): Abweichungen minus nach dem Einstellen, deren Ware danach verkauft wurde, werden zu „Auktion (korrigiert)“. Die Bewegungen bleiben, nur ihre Art ändert sich, die Kosten rechnet Ledger neu.

## 25.11.2026: Broker schlank, Schritt U2 Diagramm (Broker 0.134.0)

- **Eigener Verlauf für das Diagramm** (Claude): Die Messung behält nur 240 Abfragen, bei 90 je Minute knapp 3 Minuten. Für 15 und 60 Minuten merkt sich Broker je 3 Sekunden einen kleinen Eintrag mit dem tiefsten Preis und den untersten 16 Preisstufen, für die letzten drei Gegenstände und nur im Spiel. Mit den Stufen rechnet das Diagramm die Menge unter Kaufen bis nach einer Änderung für den ganzen Zeitraum neu, wie bisher. Liegt Kaufen bis über der 16. Stufe, zählt die Menge bis dorthin.
- **100 Plätze je Zeitraum** (Claude): 5 Minuten je 3 Sekunden, 60 Minuten je 36 Sekunden. Je Platz der tiefste Preis und die Menge der letzten Abfrage. Rechts steht immer die letzte Abfrage, ein neuer Gegenstand füllt das Diagramm von rechts.
- **Knopf „Menge“ statt „Menge darunter“** (Claude): Die fünf Knöpfe passen sonst nicht in eine Zeile unter dem Diagramm. Der Zeitraum steht deshalb oben rechts in der Zeile der Überschrift.
- **Fremde Lockangebote im Diagramm** (Claude): Der Knopf Lockangebote schaltet eigene (kräftig) und fremde (blass) zusammen. Bisher zeigte das Diagramm nur eigene.
- **Ruhender Aufkauf zeigt alle Linien** (Claude): Die Knöpfe gibt es nur im Schnellkauf, der Aufkauf behält seine Textlegende.
- **Kern unverändert** (Claude): `Chart:CreateLegend` und `legendInfo` gab es schon, U2 braucht keine Erweiterung der Kern-API.

## 25.11.2026: Broker schlank, Schritt U1 Einkaufen (Broker 0.133.0)

- **Reiter Listen schon in U1** (Claude, Konzept sah die Umbenennung in U4 vor): Mit „Einkaufen“ für die Hauptseite hätte es zwei Reiter dieses Namens gegeben. Der Reiter der Einkaufslisten heißt deshalb jetzt „Listen“ und steht hinter Beobachten wie in Abschnitt 3. Sonst ändert sich an den Listen nichts.
- **Goldreserve ist die vorhandene Goldreserve** (Claude): `radarReserve` aus dem Fenster Einstellungen galt schon für Radar und Aufkauf. Das Feld im Einkaufen schreibt denselben Wert, so gibt es nur eine Reserve für alles.
- **Menge nur im Spiel gespeichert** (Claude): `qqty` gleicht Broker nicht mit dem Manager ab (wie früher `qmax`). Der Manager kennt die Menge erst, wenn er sie braucht.
- **Gespeicherte Limits bleiben** (Konzept 4.5): `qgold` und `quickGoldDefault` bleiben erhalten und werden nicht mehr gezeigt oder genutzt. Ein früheres Limit begrenzt keinen Kauf mehr.
- **Menge aus der Einkaufsliste kommt mit U4** (Claude): Aus den Listen gibt es noch keinen Sprung ins Einkaufen, der die fehlende Menge kennt. Er entsteht mit dem Umbau der Listen.
- **Speichern von selbst auch im ruhenden Aufkauf** (Claude): Mit eingeschaltetem Aufkauf gilt jede Eingabe für beobachtete Gegenstände ebenfalls sofort (Haken „Aufkauf automatisch speichern“ bleibt).
- **Pfeile als Grafik** (Claude): Die Schrift des Spiels hat keine Zeichen ⤓ und ⤒. Zufluss und Abfluss zeigen deshalb kleine Pfeilgrafiken des Spiels (`Arrow-Down-Up`, `Arrow-Up-Up`), leicht in `F.ICON_IN` und `F.ICON_OUT` zu tauschen.

## 25.11.2026: Ledger schlank umgesetzt (Ledger 0.18.0)

- **Knöpfe [Bags] oben rechts** (Claude, Konzept zeigte sie an den Kopfzeilen der Orte): Die Liste kann in ihren Zeilen keine Knöpfe tragen. „Taschen in Bags“ und „Bank in Bags“ stehen neben der Suche und gelten für den gewählten Charakter.
- **Verlauf: ein Filter zur Zeit, zehn Knöpfe** (Claude): Wichtiges, Alle, AH, Händler, Post, Handel, Herstellen, Beute, Benutzt, Weitere. Die 13 Arten der alten Auswahlliste passen nicht in eine Zeile, deshalb fasst „Weitere“ die seltenen zusammen. Umbuchungen bleiben ein Haken, Vorgabe aus. Bisherige Einstellungen wechseln einmal auf „Wichtiges“.
- **Verlauf immer neueste zuerst** (Claude): Mit Kopfzeilen je Tag würde Sortieren nach Spalten die Tage zerreißen.
- **Sprung aus dem Buch mit Zeitraum und Charakter des Buchs** (Claude): So zeigt der Verlauf genau die Bewegungen hinter der Zahl. Ein Knopf hebt den Filter auf.
- **Gold je Charakter im Verlauf Gold statt Vermögen** (Konzept Abschnitt 4.3): Alte Stände behalten ihr Vermögen, neue speichern es nicht mehr. Nichts gelöscht.
- **Reiter Bestand ins Archiv** (Konzept Abschnitt 7): `Stock.lua` und die alte `Overview.lua` liegen unter `<Archiv>\Ledger_vor_0.18`. Die gespeicherten Werte des Bestands (`stockChar`, `stockPlace`, `stockCat`) bleiben ungenutzt erhalten.

## 25.11.2026: Einstellungen nach dem Leitfaden, Hinweise als Tooltip

- **Aufteilung je Modul freigegeben** (KarloDerBaer): Fishing, Bags, Warhorn und Profession bekommen die Reiter nach dem Leitfaden. Prüfknöpfe und Debug-Haken fallen von den Seiten, sie bleiben als Befehle. Was schon im Fenster einstellbar ist (Eigene Bereiche in Bags, Kosten und Gewinn im Berufsfenster), steht nicht mehr in den Einstellungen.
- **Hinweise als Tooltip** (Vorschlag Claude, KarloDerBaer zugestimmt): Auf umgestellten Seiten steht der Satz zu einem Schalter im Tooltip statt als Text darunter. Grund: Die Seiten werden deutlich kürzer und Regel 6 des Leitfadens verlangt einen Tooltip. Umgesetzt als Erweiterung im Kern (API 29, `tipHints`), nicht umgestellte Seiten bleiben, wie sie sind.

## 25.11.2026: Manager schlank umgesetzt (Manager 0.56.0)

- **Namen wie beschlossen** (KarloDerBaer, 24.11.2026): Unterreiter Einkaufslisten wie in Broker, unter Chancen Spekulation, Marktvergleich, Pakete und Erfolg. Heute ohne weitere Karte („passt erstmal so“).
- **Kanal nur unter Einstellungen** (Claude, nach Leitfaden Regel 5 und Konzept Abschnitt 5): unter Addons nur der jetzige Kanal mit Sprung.
- **Kein Knopf „Zugang prüfen“** (Claude, Leitfaden Regel 4): Der Manager prüft den Zugang zur Blizzard-API nach dem Speichern und beim Öffnen der Einstellungen, solange es nicht geklappt hat. Die Testzeile des Beobachters fällt aus den Einstellungen weg.
- **Knöpfe auf Heute öffnen das Bekannte** (Claude): Updates über das Update-Fenster, Rückmeldungen über ihre Seite mit Vorschau, damit nichts ungesehen installiert oder gesendet wird.
- **Markt, Übersicht mit Reitern** (Claude): Die Kennzahlen der alten Startseite sind der erste Reiter, die übrigen Auswertungen bleiben als Reiter dahinter.

## 25.11.2026: Erfolgskontrolle streng, Richtung in der Stabilität, Horde-Haus (Manager 0.55.0)

- **Nur glaubwürdige Verkäufe zählen** (KarloDerBaer, Messung Claude): verschwunden als günstigstes Angebot, nicht abgelaufen, kein gleich billiges Angebot gleicher Menge und kein billigeres neu eingestellt. Grund: Die Erfolgskontrolle zeigte 97 % Treffer, ein guter Teil der „Verkäufe“ waren neu eingestellte Angebote.
- **Überall streng** (KarloDerBaer): auch belegter Verkaufspreis, Absatz und Marktvergleich, nicht nur die Erfolgskontrolle. Folge: vermutlich weniger und vorsichtigere Chancen.
- **Menge muss gedeckt sein, Angebotspreise zählen nicht** (Vorschlag Claude, zugestimmt).
- **Übergang ohne Löschen** (Claude, beim Bau): Bisherige belegte Verkäufe bleiben und laufen in 30 Tagen aus. Löschen hätte die Chancen für Tage leer gemacht, weil die Angebote älterer Stände nicht mehr da sind. Die Nachprüfung zählt erst die Tage nach dem Update.
- **Stabilität: Grenzen bleiben, die Richtung zählt mit halbem Gewicht** (Vorschlag Claude nach Messung mit 14 vollen Tagen, KarloDerBaer zugestimmt).
- **Horde-Haus: erst Daten sammeln** (KarloDerBaer): Haus 114 unter Quellen wählen, nach 1 bis 2 Wochen messen, ob der Preisabstand Horde zu Neutral steigende oder fallende Preise im neutralen Haus ankündigt. Erst danach eine Anzeige bauen.
- **Meldung bei neuen Daten** (Wunsch KarloDerBaer): eine Einstellung, Standard aus, nach jeder fertigen Auswertung.

## 25.11.2026: Gespeicherte Ansicht, Gildenbank und Schlüsselbund (Bags 0.8.0)

- **Speichern ohne Schalter** (Claude, nach Leitfaden Regel 7 und 8): Gespeichert wird immer. Löschen eines Charakters steht in den Optionen und kommt beim Umbau der Seite in den Reiter Erweitert.
- **Wann gespeichert wird** (Claude, Abweichung vom Konzept „beim Schließen“): Die Bank meldet ihre Plätze nach dem Schließen nicht mehr. Deshalb speichert Bags die Bank beim Öffnen und bei jeder Änderung, die Taschen nach dem Einloggen, beim Schließen des Fensters und beim Abmelden.
- **Eigene SavedVariable `PeonBagsSaved`** (Claude): Die Stände gehören nicht zu Profilen und nicht zu „Standardwerte“, deshalb nicht in `PeonBagsDB`.
- **Knöpfe Taschen, Bank, Gildenbank an der Stelle der Taschenleiste** (Claude, Konzept zeigte zwei Knöpfe oben rechts): Dort ist Platz, und die Leiste hat in der Ansicht keine Aufgabe. Ein Knopf Taschen braucht es, um von der Bank zurückzukommen.
- **Gildenbank mit eigenen Bereichen** (KarloDerBaer, 24.11.2026, „dasselbe Aussehen“): derselbe Rahmen wie die Bank, alle drei Anordnungen und dieselben Layout-Einstellungen.
- **Schlüsselbund als Abschnitt der Taschen** (Claude, Werte aus Forever vom 25.11.2026: `Enum.BagIndex.Keyring` = −1, 32 Plätze, Bank über `CharacterBankTab_1` bis `_9` = 6 bis 14): Blizzards eigenes Schlüsselbund-Fenster ist neben Peon_Bags nicht bedienbar (grau überlagert). Bags versteckt es wie die übrigen Taschenfenster und zeigt den Schlüsselbund im Taschenfenster. Er gehört nie zur Bank, weil −1 in anderen Spielversionen das Hauptfach der Bank ist.

## 24.11.2026: Offene Fragen vor dem Umbau geklärt

- **Ledger: Reiter Charaktere freigegeben** (KarloDerBaer), wie in `Peon_Ledger_Schlank.md` Abschnitt 3.
- **Manager: Startseite Heute mit den vier Karten** aus `Peon_Manager_Schlank.md` Abschnitt 4 (KarloDerBaer, „passt erstmal so“). Kacheln, Diagramm und Stabilität der alten Übersicht wandern nach Markt, Übersicht. Der Unterreiter unter Listen heißt „Einkaufslisten“ wie in Broker.
- **Broker: Reiter Markt behält seinen Namen** (KarloDerBaer).
- **Bags: Gildenbank bekommt dasselbe Aussehen wie Taschen und Bank** (KarloDerBaer).
- **Restliche offene Fehlerberichte zum Schluss** (KarloDerBaer): nach den Umbauten prüfen, ob sie noch auftreten.

## 24.11.2026: Broker schlank (Konzept)

- **Entwurf A mit Seitenleiste** (KarloDerBaer, von drei Entwürfen): Die Reiter bleiben fast wie bisher, jede Seite wird entrümpelt. Dazu eine aufklappbare Leiste rechts am Fenster mit Beobachten und Einkaufsliste für den schnellen Wechsel. Die Leiste zeigt nur die Gegenstände, Werte und Einstellungen stehen im Reiter Beobachten. Verworfen: Reiter Beobachten ganz in die Leiste (zu wenig Platz für die Werte), Kaufen und Einstellen in einem Fenster (größter Umbau, doppelt sich mit Blizzards Verkaufen, vorgemerkt). Konzept `docs/konzepte/broker/Peon_Broker_Schlank.md`.
- **Fokus wird Einkaufen, nur noch Schnellkauf** (KarloDerBaer): Der Schnellkauf bringt am meisten Gold. Der Modus Aufkauf wird nicht mehr genutzt und ruht hinter einem Schalter. Speichern geschieht von selbst, Gegenstand und Im Markt zeigen nur noch im Menü.
- **Goldreserve und Menge statt Limit pro Kauf** (KarloDerBaer): Mit Regler Menge (ganz rechts „Alle“) taugt die Seite auch zum normalen Einkaufen. Vorgabe 1 für Gegenstände, die keine Massenware sind.
- **Zufluss und Abfluss sichtbar** (KarloDerBaer): nebeneinander mit Symbolen. Bewegung und Langfristig wandern in den Tooltip.
- **Einkaufsliste zieht sofort ab** (KarloDerBaer): Erledigtes wird grau und bleibt, × löscht, Regler setzt eine neue Menge.
- **Beobachten eine Liste** (KarloDerBaer): gleiche Spalten für alle, Treffer und Einbrüche je Stunde über 7 Tage, dazu Jetzt mit Punkt.
- **Chancen: nur Schnellkauf sichtbar** (KarloDerBaer): Die übrigen sind zurzeit zu riskant. Sie ruhen hinter dem Schalter „Weitere Chancen“ und können auf Stufe 60 bei seltenen Gegenständen wieder lohnen. Pakete dann eine Zeile je Paket.
- **Lockangebot bleibt** (KarloDerBaer): Ein Freund nutzt es oft. Sofort als kleiner Schritt mit Menge und Knopf „Einstellen“, ohne Zurückziehen. Einstellen in Teilen zum Preisdrücken ist vorgemerkt.

## 24.11.2026: Peon schlank, Ledger, Manager und Einstellungen (Konzepte)

- **Kein Nutzungszähler** (KarloDerBaer): Was gebraucht wird, klären wir im Gespräch statt durch eine Messwoche.
- **Manager: Startseite „Heute“ und fünf Bereiche** (KarloDerBaer, Variante A von drei): Chancen, Listen, Markt, Addons, Mehr. Aus 14 Einträgen werden sechs, jede heutige Seite bekommt einen festen Platz als Unterreiter. Verworfen: Schalter Einfach und Experte (ändert für den Hauptnutzer wenig), Suche statt Menü (man muss wissen, wonach man sucht). Konzept `docs/konzepte/manager/Peon_Manager_Schlank.md`.
- **Leitfaden für Einstellungen** (KarloDerBaer): drei Reiter Allgemein, Anzeige, Erweitert, höchstens sechs Schalter sichtbar, keine Prüfknöpfe, Einstellungen aus Fenstern nur im Fenster. `docs/konzepte/Peon_Einstellungen_Leitfaden.md`.
- **Ledger: Reiter bleiben, Bestand wird Charaktere** (KarloDerBaer): Übersicht, Buch, Verlauf und Info bleiben. Vermögen und Marktwert fallen weg, dafür Goldänderung der letzten 24 Stunden. Statt Handelsgewinn zeigt die Kachel den AH-Erlös aus den Rechnungen, weil der Gewinn von den erfassten Kosten abhängt. Der Bestand wird ein Reiter Charaktere mit gespeicherten Taschen und Banken je Ort, Suche über alle Charaktere und Ansicht im Look von Bags. Der Tooltip bleibt wie heute. Entwurf `docs/konzepte/ledger/Peon_Ledger_Schlank.md`, der Reiter Charaktere liegt KarloDerBaer zur Prüfung vor.
- **Ansicht wie im Inventar macht Bags, nicht Ledger** (KarloDerBaer): Ledger bleibt bei der einfachen Liste je Ort. Bags speichert selbst platzgenau, wie Taschen, Bank und später die Gildenbank zuletzt aussahen, und zeigt das für jeden Charakter. So muss Ledger keine Plätze erfassen. Bags bekommt dazu eine eigene Auswahl des Charakters im Taschenfenster.
- **Diagramm der Übersicht einstellbar** (KarloDerBaer): Linien wählbar, Handelsgewinn als Linie, Vorgabe aus, bis die Kosten stimmen.
- **Verlauf mit allen vier Vorschlägen** (KarloDerBaer): nach Tagen gegliedert, Vorgabe „Wichtiges“, Filter als Knöpfe, Sprung aus dem Buch.
- **Manager: Händler unter Markt, Erfolgskontrolle unter Chancen** (KarloDerBaer): Händler zeigt, was bei Händlern zu kaufen ist, und gehört deshalb zum Markt.

## 24.11.2026: Angeln mit der Interaktionstaste (Fishing 1.8.0, ClassBuddy 0.4.1)

- **Combo-Punkte an Objekten** (Claude): Über Soft Interact bekommen auch Objekte ein Nameplate. ClassBuddy prüft jetzt `UnitIsGameObject`. Fishing war nicht die Ursache, es schaltet Namen über Objekten nur bei Anzeige „Text“ und nur mit Angel im Wasser.
- **Einholen mit der Interaktionstaste des Spiels nur als Hinweis** (KarloDerBaer, Vorschlag A): Das geht schon, weil Fishing die Zielerkennung einschaltet und die Angel-Taste beim Einholen dieselbe Bindung nutzt. Die Optionen zeigen die Taste jetzt an.
- **Interaktionston als Option, Standard an** (KarloDerBaer, Vorschlag B): Im Angelmodus an, danach der alte Wert, gesichert wie die übrigen CVars. Er klingt auch bei anderen Objekten, deshalb abschaltbar.
- **Interaktionstaste nicht zum Auswerfen** (KarloDerBaer, Vorschlag C abgelehnt): Sie würde im Angelmodus für Truhen und NPCs fehlen.

## 24.11.2026: Fehler gebündelt melden (Peon 0.27.2, Peon Manager 0.54.0, Fehler-Worker)

- **Ursache der 28 doppelten Issues vom 21.11.2026** (Claude, aus den Issues abgelesen): Ein Manager schickte dreimal je 11 Einträge, zwei Schwünge waren gleich bis auf die Sekunde. Der Worker brauchte je Eintrag vier Abrufe (Cache, Suche, Anlegen, Cache) und riss beim zwölften Eintrag die Grenze von Cloudflare (50 je Anfrage in der Gratis-Stufe). Die Issues waren da angelegt, der Manager bekam einen Fehler, behielt alles und schickte es erneut. Die wechselnden Zeilennummern bei „script ran too long“ machten zusätzlich aus einem Fehler viele.
- **Verzeichnis aus der Liste der offenen Issues** statt Suche oder eigenem Speicher (Claude): Die Liste ist sofort aktuell und kostet einen Abruf je Sendung. Ein eigener Speicher bei Cloudflare (KV) hätte zusätzliche Einrichtung durch KarloDerBaer gebraucht. Gelesen werden höchstens 300 offene Issues.
- **Gleiche Regeln an allen drei Stellen** (Claude): Kern, Manager und Worker vergleichen Meldungen ohne Datei und Zeile bei „script ran too long“ und ohne Adressen von Tabellen und Funktionen. Zahlen und Zeilen sonst bleiben, weil sie verschiedene Fehler unterscheiden.
- **Bündeln im Manager vor dem Senden und im Worker je Sendung** (Claude): Eine Meldung mit der Summe der Anzahl und der Version des neuesten Eintrags. So helfen auch Fehler, die noch aus älteren Versionen einzeln im Manager liegen.

## 21.11.2026: Ledger rechnet neue Bewegungen nach (Ledger 0.17.2, Peon 0.27.1)

- **Ursache der neuen Fehlerberichte** (Claude): Im Dungeon ist jedes Plündern eine Bewegung. Ledger verwarf danach den ganzen Stand, und der nächste Tooltip spielte alles nach. Im Kampf wurde das Rechnen im Hintergrund (0.17.1) immer weiter verschoben, darum blieb es beim Tooltip. Dazu fragte jede Rechnung den Marktwert bei Broker hunderte Male für dieselben Gegenstände ab (echte Daten: 483 Abfragen für 21 Gegenstände).
- **Nachtragen statt Neurechnen** (KarloDerBaer): Neue Beute, Benutzt, Quest und Zerstört kommen auf den gespeicherten Stand. Wächst ein Tageseintrag, kommt nur der Zuwachs dazu, wenn seitdem nichts anderes denselben Gegenstand dieses Charakters berührt hat. Andere Arten werden nach dem Anlegen noch ergänzt (Haus, Menge, Nachnahme) oder hängen an mehreren Gegenständen (Herstellen, Handel), sie rechnen weiter neu. Mit echten Daten (4.506 Bewegungen) gleiche Posten und Ergebnisse wie beim vollen Nachspielen.
- **Im Kampf zeigt der Tooltip den letzten Stand**, gerechnet wird danach im Hintergrund. Die erste Rechnung nach dem Einloggen läuft ebenfalls im Hintergrund.
- **„script ran too long“ als ein Fehler** (Claude, weil 20 Berichte einzeln ankamen): Die Zeile in der Meldung ist nur die Stelle, an der das Spiel abbrach. Kern und Fehler-Worker vergleichen solche Meldungen ohne Datei und Zeile.

## 21.11.2026: Ledger-Tooltip zu lang (Ledger 0.17.1)

- **Andere Ursache als das Ruckeln bei Kisten** (Claude, nach Fehlerberichten): Die Fehler lagen in der Kostenrechnung des Ledger, die nach einer Bewegung beim nächsten Tooltip alles nachspielt. Abgelaufene Gebote blieben in der Liste und machten jede Suche länger.
- **Abgelaufene Gebote entfernen und nach einer Bewegung im Hintergrund rechnen** (KarloDerBaer): Das Ergebnis bleibt im Speicher und wird nur nach einer Bewegung neu gerechnet, jetzt kurz danach statt beim Tooltip. Schrittweises Weiterrechnen nur mit der neuen Bewegung wäre schneller, aber Tausche und Startbestand hängen an allen Bewegungen. Das bleibt offen, falls es noch einmal nötig wird.

## 20.11.2026: Ruckeln bei Kisten mit Paketliste (Broker 0.130.1)

- **Erst mit echten Daten messen** (Claude, nach Fehlermeldung KarloDerBaer): Nicht der Tooltip war langsam (unter 0,1 ms), sondern das Namensverzeichnis des Paketvergleichs, das beim Zeigen einer Kiste jede Minute neu entstand (190 ms).
- **Verzeichnis nur mit Gegenständen mit Nummer, neu nur bei neuen Preisdaten, Aufbau im Hintergrund** (KarloDerBaer, Vorschlag Claude). Namen aus Live-Abfragen zwischen zwei Scans findet Broker wie bisher über das Spiel.

## 20.11.2026: Broker-Datei unter der Grenze des Spiels (Broker 0.130.0, Manager 0.53.1)

- **Erst messen, dann bauen** (KarloDerBaer). Ergebnis: Das Spiel zählt verschiedene Werte, nicht die Größe. Jeder Text zählt einmal, egal wie lang. Tageswerte kürzen, Wochenwerte weglassen, runden oder alte Gegenstände entfernen hätte fast nichts gespart (Claude, Messung mit der reparierten Datei).
- **Texte je Gegenstand nur in der Datei bündeln** (KarloDerBaer, Vorschlag Claude): Beim Abmelden kommen sie in einen Text, beim Laden werden sie getrennt. Im Spiel bleibt alles gleich, nichts geht verloren. Von 230.868 auf 108.050 Werte. Der Manager liest die neue Form im selben Release.
- **Varianten ohne Namen und nach 7 Tagen ohne Angebot entfernen** (KarloDerBaer). Der Name steht im Schlüssel, die Langzeitwerte hat der Manager.
- **Warnen statt verhindern** (KarloDerBaer): Ab 180.000 geschätzten Werten ein Hinweis. Startet Broker leer, nennt ein Hinweis die Spielsicherung im Manager. Das Überschreiben der Datei kann ein Addon nicht verhindern.

## 20.11.2026: Leerer Realm-Name, Pakete gebaut (Peon 0.27.0, Broker 0.129.0, Ledger 0.17.0, Bridge 0.14.0, Manager 0.53.0)

- **Realm-Name mit Rückfall im Kern** (Claude, nach Fehlermeldung KarloDerBaer): Das Spiel lieferte einen leeren Namen, Ledger und Broker zeigten leere Fenster. `Peon.RealmName()` merkt sich den letzten Namen, ohne ihn hilft die Liste der Profile. Daten, die unter „?“ entstanden, wandern beim Anmelden zum echten Realm und Markt.
- **Broker-Datei repariert, nicht zurückgesetzt** (KarloDerBaer): Die nicht mehr ladbare Datei wurde ohne den doppelten Markt „? / Alliance“ zurückgelegt, so blieb alles seit dem letzten guten Stand erhalten. Sicherungen im Archiv.
- **Größe der Broker-Datei in eigener Sitzung** (KarloDerBaer).
- **Pakete gebaut wie im Konzept**, Auswahl mit mehreren Startangeboten und Vorrang für gestreute Pakete (Claude, nach Messung mit echten Daten: sonst nahm ein teures Angebot das ganze Paket ein).

## 20.11.2026: Markttausch erst nach Einschalten, Konzept Pakete (Broker 0.128.2)

- **Markttausch in Broker ab Werk aus** (KarloDerBaer): Chancen und Beobachten zeigen ihn erst nach dem Einschalten in den Einstellungen der Chancen. Der Manager zeigt den Marktvergleich immer.
- **Pakete im Markttausch** (Konzept `docs/konzepte/broker/Peon_Broker_Pakete.md`, Entscheidungen dort in Abschnitt 7): 8 Angebote, höchstens 10 % des Golds, knapp unterbieten, Massenware stellt Broker selbst ein, Post an Twinks ohne eigenen Schritt.

## 20.11.2026: Markttausch im Ledger, Einstellgebühr, Lücken, Erfolgskontrolle (Ledger 0.17.0, Broker 0.128.1, Manager 0.52.0)

- **Markttausch im Ledger verorten** (KarloDerBaer): Das Haus hängt an der Bewegung und am Posten, nicht an einem eigenen Merker in Broker. Das Buch zeigt den Gewinn als graue Zeile unter dem Handelsgewinn, getrennt von der Überleitung (Claude).
- **Einstellgebühr im neutralen Haus wie im eigenen** (Messung 20.11.2026 aus Ledger, KarloDerBaer hat dort eingestellt). Verlust je Verkauf nach der Absatzquote (Claude).
- **Lücken im Ziel sind Chancen** (KarloDerBaer): Absatz vorhanden, gerade kein Angebot.
- **Diagramm nur im Manager, abschaltbar** (KarloDerBaer). In Broker wäre es zu unübersichtlich.
- **Seite Marktvergleich zeigt zuerst die Auswahl für Broker** (Frage KarloDerBaer, warum dort viel mehr stehen als in Broker).
- **Erfolgskontrolle:** Nachprüfung nach 3 Tagen über die Preise beider Häuser, echte Tausche aus Ledger (Claude).

## 20.11.2026: Markttausch nur mit Auswahl des Managers, Beobachten Markttausch (Broker 0.128.0, Bridge 0.13.1, Manager 0.51.0)

Konzept `docs/konzepte/broker/Peon_Broker_Marktvergleich.md`, Abschnitt 10.

- **Markttausch nur mit Auswahl des Managers** (KarloDerBaer): Ohne Daten vom Manager ein Hinweis, die Liste nach Preisunterschied entfällt. Das ersetzt die Entscheidung „Ohne Manager eine einfache Liste“ vom selben Tag.
- **Broker entfernt nur, fügt nie hinzu** (KarloDerBaer). Entfernte kommen erst mit einem neueren Stand des Managers wieder (KarloDerBaer, Vorschlag Claude).
- **Die besten 10 an Broker, einstellbar, mit Langzeitwerten** (KarloDerBaer). Langzeit über 14 Tage: Beständigkeit, gleichmäßiger Absatz im Ziel, wachsender oder schrumpfender Unterschied (Claude).
- **Beobachten Markttausch nur beobachten**, ohne eigene Grenzen (KarloDerBaer, Vorschlag Claude).
- **Werte des Schnellkaufs und Haken der Listen mit dem Manager abgleichen** (KarloDerBaer, Vorschlag Claude). Das ändert die Entscheidung von 0.106, dass sie nur im Spiel bleiben. `qmax` und `mode` bleiben im Spiel.
- **Händler im Manager wieder an** (KarloDerBaer). Der Datenaustausch lief schon.

## 20.11.2026: Marktvergleich mit dem neutralen Haus (Broker 0.127.0, Bridge 0.13.0, Manager 0.50.0)

Konzept `docs/konzepte/broker/Peon_Broker_Marktvergleich.md`, freigegeben von KarloDerBaer.

- **Beide Richtungen** (KarloDerBaer): Fraktion nach Neutral und Neutral nach Fraktion. Die Horde bleibt draußen.
- **Anteil des neutralen Hauses 15 % annehmen** (KarloDerBaer), bis Broker ihn aus Rechnungen misst. Der Manager liest den Messwert aus `Peon_Broker.lua`. In Broker gilt die Annahme nur für den Vergleich, nicht für Rat und Tooltip.
- **Name „Markttausch“** für den Unterreiter in Chancen (KarloDerBaer).
- **Keine Summe je Gang** zum neutralen Haus (KarloDerBaer).
- **Ohne Manager eine einfache Liste** nach Preisunterschied (KarloDerBaer).
- **Eigener Anteil am Absatz 10 %, Haltedauer 1 Tag**, beides einstellbar (KarloDerBaer: deutlich weniger und kürzer als vorgeschlagen).
- **Kaufpreis aus dem günstigsten Preis je Tag, Verkaufspreis aus echten Verkäufen** (Claude): Der Median der Angebote hätte den Kauf zu teuer und den Verkauf zu günstig gerechnet. Dafür merkt sich der Zwischenspeicher des Managers jetzt auch den günstigsten Preis je Tag.
- **Zustand nur für das Haus, an dem man steht** (Claude): Live abfragen geht nur am offenen Auktionshaus. „Alle prüfen“ nutzt die Abfrage des Radars.
- **Gepäck einfach gehalten** (Claude): Broker merkt sich den Gegenstand beim Klick am Haus der Quelle, nicht als eigenen Posten im Buch. Ein Hinweis am Zielhaus nennt, was davon in den Taschen liegt.

## 20.11.2026: Sicherer Knopf über fremden Symbolen (Profession 0.7.2 und 0.7.3)

- **Nur hinsetzen, nicht anhängen** (Claude): Ein unsichtbarer sicherer Knopf über einem fremden Knopf (Taschenplatz, Symbol) wird nur an dieselbe Bildschirmstelle gesetzt (Position über `UIParent`), nie mit `SetAllPoints` oder `SetPoint` an den fremden Knopf gehängt. Angehängt tat der Klick bei Alt + Klick nichts. Er wirkt beim Loslassen (`useOnKeyDown = false`). Muster wie das Gifte-Symbol in Peon_ClassBuddy.
- **Eigene, höhere Schicht** (Claude, im Spiel bestätigt): Der Knopf liegt in der Schicht DIALOG, nicht in der Schicht des fremden Knopfes. Fenster mit `SetToplevel` (Peon_Bags) heben sich sonst samt Plätzen über ihn.
- **Nicht ständig neu setzen** (Claude, im Spiel bestätigt): Der Tooltip baut sich alle 0,2 Sekunden neu auf. Liegt der Knopf schon über demselben Platz, bleibt er unberührt, sonst verliert er bei jedem Neusetzen die Maus.

## 20.11.2026: Auto auch für Einbrüche, Zeile Einbruch, letzter Kauf (Broker 0.125.0)

- **Auto auch für Einbrüche** (KarloDerBaer): Die billigen Angebote bei Seidenstoff hatten mehrere Stück, waren also keine Lockangebote, und Auto blieb grau. Es gilt das jüngere von Lockangebot und Einbruch.
- **Regulär beim Einbruch** (Vorschlag Claude): die günstigste Stufe mindestens `quickDipPct` Prozent darüber, weil knapp über einem Einbruch oft weitere billige Stufen liegen.
- **Zeile Einbruch statt Letztes** (KarloDerBaer): tiefster Einbruch der Sitzung und Anzahl. Das letzte Lockangebot steht nur noch im Tooltip.
- **Durchschnitt hinter Gekauft, letzter Kauf unter dem Kaufknopf** (KarloDerBaer).

## 19.11.2026: Langfristig einfach zählen (Broker 0.124.0)

- **Zählen statt hochrechnen** (KarloDerBaer): Werte je Stunde nach wenigen Minuten Beobachtung springen stark und sagen nichts. Der Fokus zeigt Anzahl und beobachtete Zeit, ohne Gewichtung der Tage. Je Stunde bleibt nur für den Vergleich in den Listen, ab 30 Min. Beobachtung.
- **Einbruch nur bei echtem Tief** (Vorschlag Claude, KarloDerBaer einverstanden): In lebhaften Märkten zählte jedes Wiedereinstellen nach einem Auskauf als Einbruch. Jetzt gilt der Tiefstpreis der letzten Minute, einzelne Lockangebote zählen dafür nicht.
- **Kurzer Text** (KarloDerBaer): Zeile und Tooltip gekürzt.

## 19.11.2026: Auto auch über Kaufen bis (Broker 0.123.0)

- **Lockangebote über Kaufen bis erkennen** (KarloDerBaer): Kaufen bis hing oft genau an der Grenze zu den Lockangeboten, Auto konnte es nicht anheben.
- **Erkennen und Melden getrennt** (Vorschlag Claude, KarloDerBaer einverstanden): Zeile, Nachahmer und Ton bleiben bei „höchstens Kaufen bis“ (0.110), sonst klingelt es bei Angeboten, die man nicht kaufen will. Nur Auto nutzt alle.
- **Auto leuchtet an der Grenze** (Vorschlag Claude): wenn das letzte Lockangebot bei oder über Kaufen bis liegt.

## 19.11.2026: Gelegenheiten langfristig (Broker 0.122.0)

- **Einbruch statt Gelegenheit unter Kaufen bis** (Vorschlag Claude, KarloDerBaer einverstanden): Ein Einbruch (neues Angebot ab 2 Stück mindestens 5 % unter dem günstigsten) hängt nicht an Kaufen bis. So bleiben die Zahlen vergleichbar, auch wenn Kaufen bis sich ändert. Die Gelegenheiten unter Kaufen bis zählt der Fokus weiter für die Sitzung.
- **Aus allen Beobachtungen, über 14 Tage gewichtet** (Vorschlag Claude, KarloDerBaer einverstanden): Fokus und Prüfungen zählen zusammen, je Stunde beobachteter Zeit. Unter 30 Minuten vorläufig.
- **Spalte in Chancen und Beobachten** (KarloDerBaer): In Beobachten ersetzt sie Gekauft, das in den Tooltip wandert.

## 19.11.2026: Knopf Auto für Kaufen bis im Schnellkauf (Broker 0.121.0)

- **Auto setzt Kaufen bis zwischen Lockangebot und regulären Preis** (KarloDerBaer): Im Kaufprotokoll scheiterten die meisten Käufe, solange Kaufen bis genau auf dem Lockpreis lag. Etwas darüber gelang die Mehrheit. Die Mitte als Wert (Vorschlag Claude) entspricht dem, was KarloDerBaer von Hand eingestellt hatte.
- **Ein Klick, kein Nachführen** (Vorschlag Claude, KarloDerBaer einverstanden): Ein Wert, der sich alleine bewegt, könnte einen schnellen Kauf überraschend teuer machen.
- **Code 10 nach Fehlkäufen bleibt** (KarloDerBaer): Eine Pause nach dem Fehlkauf würde die nächste Abfrage verzögern, der Fehler stört nicht.

## 19.11.2026: Vorgaben im Schnellkauf, Prüfabstand, Haken im Menü (Broker 0.120.0)

- **Kaufen bis ohne eigenen Wert** (KarloDerBaer): die Hälfte des günstigsten Angebots oder der Händlerpreis, je nachdem was höher ist. Anteil einstellbar. Ein einzelnes Stück ganz unten zählt nicht (Vorschlag Claude), sonst würde ein Lockangebot die Vorgabe drücken. Ersetzt die Übernahme aus dem Aufkauf (0.107).
- **Limit pro Kauf ohne eigenen Wert 5 Gold** (KarloDerBaer), einstellbar. Ersetzt 100 Stück zu Kaufen bis (0.113).
- **Prüfabstand nach Bewegung** (KarloDerBaer): lebhafte oft, je schlechter desto seltener. Gleitend nach dem Anteil an der Grenze für lebhaft, höchstens 10 Minuten (Werte Claude, einstellbar).
- **Haken je Liste im Gegenstandsmenü** (KarloDerBaer): „Beobachten: Aufkauf“ und „Beobachten: Schnellkauf“. Nur bei Massenware, weil der Schnellkauf nur dort geht (Claude).
- **Marktbewegung nur in der Kaufzone** (KarloDerBaer, Vorschlag Claude): Einstellungen und Käufe zählen nur bis 5 % über dem günstigsten Angebot, Preissprünge erst ab 2 %. Grund: Bei großen Märkten wie Magiestoff passiert oben im Stapel ständig etwas, auch 20 Einstellungen je Minute reichten als Grenze nicht. Zufluss und Abfluss bleiben für den ganzen Markt (KarloDerBaer).
- **Gelegenheiten als langfristige Kennzahl** (KarloDerBaer): Sie fallen in den kurzen Prüfungen nur zufällig auf und taugen nicht für die Bewertung der Bewegung. Wie sie gesammelt und gezeigt werden, folgt nach Abstimmung.
- **Schutz vor Lockangeboten beim Verkaufen nur bei Massenware** (KarloDerBaer): Bei Einzelgegenständen ist ein einzelnes günstiges Stück ein normales Angebot.
- **Spalte Art entfällt** (KarloDerBaer): Die Unterreiter trennen die Arten schon, die Art steht im Tooltip.

## 19.11.2026: Chancen im Schnellkauf, Unterreiter (Broker 0.119.0)

- **Vorschläge aus der Menge** (KarloDerBaer): Massenware mit der größten Menge im jüngsten Stand, günstigster Preis mindestens 1 Silber (1 Gold war für Massenware zu hoch), Anzahl 10. Beides einstellbar.
- **Prüfung am Stück je Gegenstand** (KarloDerBaer): mehrere Abfragen direkt hintereinander zeigen schnelle Bewegungen und Lockangebote wie im Fokus. Reihum über alle Gegenstände (Vorschlag Claude) wäre für Lockangebote noch mehr Zufall.
- **Gleitend über 3 Prüfungen** (KarloDerBaer, Vorschlag Claude): Fünf Abfragen dauern nur etwa 3 Sekunden, hochgerechnet auf eine Minute wäre fast alles lebhaft. Die erste Prüfung gilt als vorläufig.
- **Daten des Managers ohne neue Schnittstelle** (Claude): Broker trägt den neuesten Stand des Managers (Menge und günstigster Preis) schon in seine Marktdaten ein (`Data.ApplyManager`). Die Vorschläge nehmen ihn damit automatisch, Manager und Bridge bleiben unverändert.
- **Unterreiter** (KarloDerBaer): Chancen in Spekulation, Aufkauf und Schnellkauf, Beobachten in Aufkauf und Schnellkauf. Nur die offene Liste wird geprüft, die zuletzt offene merkt sich Broker. Langzeit und Muster gehören zu Spekulation, Händler zu Aufkauf. Ein Gegenstand mit Werten in beiden Modi steht in beiden Listen von Beobachten.
- **Alle Vorschläge zeigen** (KarloDerBaer): ruhige grau unten statt ausgeblendet.

## 19.11.2026: Kaufprotokoll über Peon_Debug (Broker 0.118.0)

- **Aufzeichnen im privaten Peon_Debug** (KarloDerBaer): nach weiteren Fehlkäufen wieder nötig, aber nicht mit ausliefern. Broker bekommt nur einen Anschluss ohne Einstellung und Speicher, wie `Peon.Comm.Listen` für Peon_Debug (Claude).

## 19.11.2026: Kaufprotokoll entfernt (Broker 0.115.0)

- **Nicht mit ausliefern** (KarloDerBaer): Das Protokoll hat die Ursache der Fehlkäufe gezeigt (belegte Bremse des Spiels, Abbrechen löste Code 10 aus). Es wird nicht mehr gebraucht.

## 19.11.2026: Pause der Abfragen bei freiem Kaufknopf (Broker 0.114.0)

- **Pause statt Dauerabfrage** (KarloDerBaer, Vorschlag Claude aus dem Kaufprotokoll): Solange etwas kaufbar ist, keine Abfrage, damit die Bremse des Spiels beim Klick frei ist.
- **Nur kurz, dann gesperrt** (KarloDerBaer): nach 1 Sek. (einstellbar) ohne Klick wieder abfragen und den Knopf bis zur Antwort sperren. Sonst entginge einem eine größere Menge, die kurz darauf kommt.

## 19.11.2026: Vorgaben und automatisch speichern (Broker 0.113.0)

- **Vorgaben im Schnellkauf** (KarloDerBaer): beide Haken an, Limit pro Kauf = 100 Stück zu Kaufen bis. Gespeicherte Werte gehen vor.
- **Automatisch speichern je Modus** (KarloDerBaer), nur für Gegenstände in Beobachten (Claude): sonst landete jeder angesehene Gegenstand dort.

## 19.11.2026: Durchschnitt und Limit pro Kauf (Broker 0.112.0)

- **Durchschnitt statt teuerstes Stück, einstellbar** (KarloDerBaer, Vorschlag aus der Auswertung des Kaufprotokolls): erhöht die Chance, wenn andere gleichzeitig einen Teil des Stapels kaufen. Nur im Schnellkauf, Haken je Gegenstand, Vorgabe aus.
- **Limit pro Kauf statt Max. Menge** (KarloDerBaer): ein Betrag fängt große Mengen besser ab als eine Stückzahl, gerade mit dem Durchschnittspreis.
- **Gleich weniger kaufen (etwa 60 %) verworfen** (Claude, zugestimmt): Im Protokoll waren von 19 angezeigten Stück nur 3 bis 5 zu haben, 60 % hätten nicht gereicht.

## 19.11.2026: Kein Abbruch bei zu teurem Preis (Broker 0.111.1)

- **Versuch ohne `CancelCommoditiesPurchase`** (KarloDerBaer): Im Kaufprotokoll folgte jedem Abbruch der Fehler Code 10. Ob er damit verschwindet, zeigt das nächste Protokoll.
- **Nicht der Menge hinterherjagen** (KarloDerBaer): Nach einem zu teuren Preis kauft der nächste Klick nicht automatisch weniger.

## 19.11.2026: Kaufprotokoll und aufgeräumter Schnellkauf (Broker 0.110.0)

- **Erst messen, dann umbauen** (KarloDerBaer, Vorschlag Claude): Die Fehlkäufe (Code 10) werden mit einem Kaufprotokoll aufgezeichnet. Ob Kauf und Abfragen des Fokus eine eigene Datei bekommen, entscheidet sich nach der Auswertung.
- **Keine Pause nach dem Kauf** (KarloDerBaer): Während des Kaufs ruhen die Abfragen schon, danach geht es sofort weiter.
- **Preisalarm aus Beobachten im Fokus still** (KarloDerBaer): für den Gegenstand, der gerade im Fokus zu sehen ist.
- **Kurze Zeilen, Einzelheiten im Tooltip** (KarloDerBaer).
- **Fremde Lockangebote nur bis Kaufen bis** (KarloDerBaer): darüber könnte man sie ohnehin nicht kaufen. Ohne Kaufen bis zählen alle (Claude).

## 19.11.2026: Fremde Lockangebote und Haken „Lockangebot ignorieren“ (Broker 0.109.0)

- **Fremdes Lockangebot = genau 1 Stück** (KarloDerBaer), neu und mindestens 5 % unter dem bisher günstigsten Angebot (Vorschlag Claude, einstellbar). Grund: 1 Kupfer darunter ist normales Unterbieten, kein Lockangebot.
- **Nachfolger nur zum gleichen Preis** (KarloDerBaer): sicheres Zeichen, dass jemand einfach den günstigsten Preis übernommen hat.
- **Anzeige** (KarloDerBaer): Zusammenfassung über das Zeitfenster und das letzte Lockangebot, das eigene gekennzeichnet.
- **Haken „Lockangebot ignorieren“** (KarloDerBaer): Kaufknopf und Alarm erst ab mehr als 1 Stück, fest. Je Gegenstand, gespeichert in Beobachten. Das eine Stück wird nicht übersprungen, weil das Spiel Massenware von unten verkauft.

## 19.11.2026: Marktbewegung im Schnellkauf (Broker 0.108.0)

- **Zufluss, Abfluss und Bewegung getrennt** (KarloDerBaer): Lockangebote wirken nur, wenn viel eingestellt wird. Der Zufluss ist deshalb der wichtigste Wert und steht eigens da.
- **Bewegung aus Ereignissen statt aus dem üblichen Absatz** (KarloDerBaer): Einstellungen, Käufe und Preissprünge je Minute. Gezählt werden Ereignisse, nicht Stück, damit die Grenzen bei billiger Massenware und seltenen Gegenständen ähnlich passen (Claude). Lebhaft nur mit genug Einstellungen. Grenzen einstellbar.
- **Nachwirkung statt Verkaufsdauer des Lockangebots** (KarloDerBaer): was andere in 30 Sekunden (einstellbar) danach zum selben Preis eingestellt haben.
- **Zeilen über dem Diagramm** (KarloDerBaer): wie die Messwerte im Aufkauf, kein Balken im Diagramm.

## 19.11.2026: Offene Gebühren ohne Auktionsverkauf (Ledger 0.16.3)

- **Händlerverkauf trägt offene Gebühren** (KarloDerBaer, Vorschlag Claude): anteilig nach dem Bestand vor dem Verkauf, das letzte Stück alle. Grund: Sonst blieben sie liegen und belasteten einen späteren Auktionsverkauf oder nie den Handelsgewinn.
- **Restgebühren als Verlust** (Claude, zugestimmt): Ist der Bestand ohne Verkauf weg (Verbrauch, Herstellen, Zerstören, Handel, Post an andere), mindern die restlichen Gebühren den Handelsgewinn.
- **Post an Twinks** (Claude): Die Gebühren wandern anteilig mit zum Empfänger, weil die Ware dort weiterverkauft werden kann.

## 19.11.2026: Schnellkauf übernimmt Kaufen bis (Broker 0.107.0)

- **Kaufen bis aus dem Aufkauf** (KarloDerBaer): damit das Feld nicht leer ist. Ab 0.107.1 immer, wenn das Feld leer ist, nur nicht nachdem man es im Schnellkauf selbst geleert hat (0.107.0 „einmal je Gegenstand“ ging beim Sprung aus Beobachten verloren).
- **Lockpreis 50 % unter Kaufen bis** (KarloDerBaer): nicht mehr vom günstigsten Angebot abgeleitet, Prozent einstellbar.

## 19.11.2026: Schnellkauf und Beobachten je Modus (Broker 0.106.0)

- **Schnellkauf schlank** (KarloDerBaer): keine Hinweistexte, kein Wiedereinstellen. Käufe daraus werden nie Posten.
- **Max. Menge als Feld** (KarloDerBaer, ohne Haken nach Vorschlag Claude): leer heißt alle, der Höchstbetrag (Menge mal Kaufen bis) steht hinter dem Feld. Ein Regler passt nicht, weil man ihn bei Angeboten von Sekunden nicht nachstellt.
- **Werte je Modus in Beobachten** (KarloDerBaer): Aufkauf mit Kaufen bis und Zielpreis, Schnellkauf mit Kaufen bis und Max. Menge, dazu der zuletzt gespeicherte Modus. Eine Spalte „Kaufen bis“ zeigt den Wert der Art in der neuen Spalte „Art“. Der Preisalarm folgt der Art.
- **Neue Werte nur im Spiel** (Claude, zugestimmt): Der Manager nutzt sie nicht, darum lässt der Abgleich sie aus.
- **Fokus aus Chancen immer im Aufkauf** (Claude, zugestimmt): Chancen haben Ziel und Gewinn.
- **Stand in Beobachten** (KarloDerBaer): Spalte „Stand“ weg, oben rechts die jüngste Einzelabfrage („Letzter Gegenstand gescannt vor: …“). Die Abfragen gehen reihum, die anderen sind nur Sekunden älter.

## 19.11.2026: Schnellkauf, Lockangebote, schnellerer Kaufknopf, Radar in Chancen (Broker 0.104.0 und 0.105.0)

- **Ein Reiter Fokus mit zwei Modi** (KarloDerBaer, Vorschlag Claude): „Aufkauf“ ist der bisherige Fokus, „Schnellkauf“ ist neu. Nicht gewählt: zwei getrennte Reiter. Grund: Beide brauchen dieselben Preisstufen und dieselbe laufende Abfrage, beim Umschalten bleibt der Gegenstand.
- **Schnellkauf nur mit Kaufen bis** (Claude): Gekauft wird alles bis Kaufen bis, ohne Zielpreis, Gewinn, üblichen Bereich und Risiko. Ohne Kaufen bis kauft der Schnellkauf nichts.
- **Diagramm im Schnellkauf** (KarloDerBaer): Preislinie und Menge unter Kaufen bis reichen, dazu ein Strich je eigenem Lockangebot (Vorschlag Claude). So sieht man, wie oft Lockangebote und Nachahmer kommen.
- **Lockangebot** (KarloDerBaer): immer 1 Stück, kürzeste Laufzeit, eigenes Feld mit Vorschlag. Der Vorschlag liegt einen festen, einstellbaren Prozentsatz (Vorgabe 20 %) unter der ersten echten Stufe. Nur Massenware. Es ist Brokers erstes Einstellen aus eigenem Knopf, deshalb mit Rückfrage des Spiels als zweitem Klick und ohne Automatik.
- **Lockangebote beim Verkaufen erkennen** (KarloDerBaer, Grenzen von Claude): höchstens 5 Stück oder unter 2 % aller Angebote, und die nächste Stufe mehr als 10 % teurer. Alle Grenzen einstellbar.
- **Kaufknopf nach Kauf und „schon weg“** (Claude): Stufen sofort anpassen und sofort neu abfragen statt bis zur nächsten Antwort mit dem alten Stand zu rechnen. Nach „schon weg“ wartet der Knopf auf die frische Antwort, höchstens 3 Sekunden, damit er nicht hängen bleibt, wenn eine Antwort ausfällt.
- **Radar in Chancen** (KarloDerBaer, umgesetzt in Broker 0.105.0): kein eigener Reiter Radar mehr. Ein Scan-Knopf mit Auswahl Manager-Chancen, Beobachten, Massenware, Alles. Spalten Gegenstand, Art, Gewinn, Kaufen bis, Risiko, Zustand. Keine doppelten Zeilen: Die Live-Prüfung aktualisiert die Chance des Managers. Weggefallene je Herkunft wie bisher. Zahl am Reiter und Einstellungen zusammengeführt. Standard der Zahl bleibt aus (Entscheidung vom 15.11.2026), nach einem Komplettscan blinkt sie wie früher beim Radar, wenn sie eingeschaltet ist.

## 18.11.2026: Gifte mit einer Taste (ClassBuddy 0.4.0)

- **Eine schlaue Taste mit Erinnerung** (KarloDerBaer, Vorschlag A mit C): Jeder Druck trägt das nächste fehlende oder bald ablaufende Gift auf, zuerst Haupthand, dann Nebenhand. Nicht gewählt: je Hand eine eigene Taste.
- **Sicherer Knopf mit `target-slot`** (Claude): Gegenstände auf eine Waffe legen darf nur Blizzards Knopfvorlage, wie beim Köder in Peon_Fishing. Der Knopf wirkt beim Loslassen (`useOnKeyDown = false`), damit Tastenbelegung und `/click` unabhängig von `ActionButtonUseKeyDown` gehen. Im Kampf bleibt die vorbereitete Hand, weil sich die Attribute dann nicht ändern dürfen.
- **Gift je Hand als Art, Rang automatisch** (Claude): Man wählt Sofort wirkend, Tödlich usw., die Taste nimmt den höchsten benutzbaren Rang. Standard Haupthand Sofort wirkend, Nebenhand Tödlich, erneuert unter 10 Minuten oder 10 Ladungen.
- **Ersetzen selbst bestätigen, mit Rückfall** (Claude): Nur wenn die Frage direkt nach unserem Druck kommt. Sperrt das Spiel das, erscheint Blizzards Frage wieder und es wird in der Sitzung nicht mehr versucht.
- **Panel-Klick über einen sicheren Knopf auf dem Symbol** (Wunsch KarloDerBaer, Weg Claude): Linksklick trägt auf, Rechtsklick wählt das Gift je Waffe. Der sichere Knopf legt sich beim Tooltip über das Symbol, nur positioniert und nicht angehängt, damit das Panel im Kampf frei bleibt. Keine Änderung an Kern-API und Peon_Panel. Im Kampf geht das Auftragen nur mit Taste oder Makro.
- **Nur die eigene Klasse** (KarloDerBaer): Panel-Einträge und Optionsreiter gibt es nur für die Klasse des Charakters.
- **Erinnerung nur, wenn man etwas tun kann** (Claude): Warnung nur, wenn ein passendes Gift in den Taschen liegt, nicht in Stadt und Gasthaus, nicht im Kampf. So stört sie Schurken ohne Gifte (unter Stufe 20) nicht.

## 18.11.2026: Anonyme Absender-Kennung und übersichtlichere Releases (Manager 0.49.0)

- **Anonyme Kennung je Installation** (KarloDerBaer): 8 zufällige Zeichen, beim ersten Senden erzeugt, im Issue als „Absender …“. Damit ist erkennbar, ob mehrere Berichte von derselben Installation kommen, ohne Namen oder Rechner zu kennen. Im Sendedialog sichtbar und jederzeit neu erzeugbar, erwähnt im Abschnitt Datenschutz der README.
- **Weniger Dateien im Release:** Die Blockmaps alter Installer (fürs Laden nur geänderter Teile beim Update des Managers) kommen nur noch für die letzten 5 Versionen mit, vorher für alle (zuletzt 18). Ältere Versionen laden beim Update den ganzen Installer.
- **Hinweis oben im Release-Text:** Direktlink auf den Installer und ein Satz, dass alle anderen Dateien der Manager selbst holt. GitHub lässt die Liste der Dateien nicht ordnen oder ausblenden.

## 18.11.2026: Laufende Profile mit Standard (Peon 0.26.0, Kern-API 26)

- **Standard für alle, eigenes Profil je Charakter** (KarloDerBaer): Es gibt immer „Standard“. Jeder Charakter nutzt es, bis man ein anderes wählt. Änderungen gelten sofort für alle Charaktere mit demselben Profil. Die Stände aus 0.25.0 werden zu Profilen.
- **Werte des aktiven Profils bleiben direkt in der Kontotabelle** (Claude): Beim Einloggen und Wechseln tauscht der Kern die Werte aus. So lesen und schreiben die Module ihre Einstellungen wie bisher, auch über `mod.acc`, und die Tests der Module laufen unverändert. Eine Umleitung von `mod.db` hätte jedes Modul und jeden Test berührt.
- **Nicht im Profil:** Fensterpositionen, Merker und Daten (alles in `keepOnReset` oder außerhalb von `defaults`) sowie Charakterwerte (`charKeys`). Geprüft am 18.11.2026: Alle Merker der Module stehen in `keepOnReset`.

## 18.11.2026: Zweite Runde nach dem Review (Peon 0.25.0, Fishing 1.7.1, Manager 0.48.0)

- **Gewählt von KarloDerBaer:** Sicherung der Spieldaten, Hilfe für Nutzer im Manager, Profile im Kern. Nicht gewählt: Gildenbank im Ledger.
- **Sicherung der Spieldaten im Manager:** nur die `Peon*.lua` aus `WTF\Account` (Konto und Charaktere), gepackt im Datenordner. Vor jedem Installieren (höchstens alle 10 Minuten) und täglich. Je Anlass die neuesten (5 vor Update, 7 täglich, 5 von Hand, 3 vor Wiederherstellen). Wiederherstellen nie bei laufendem WoW (das Spiel schreibt beim Beenden alles neu) und immer erst nach einer Sicherung des jetzigen Stands. Grund: Ein kaputtes Ledger-Buch ließ sich bisher nicht zurückholen.
- **Hilfe im Manager aus `docs/Hilfe.md`:** eine Datei für GitHub und Manager. Der Manager gibt sie nur als Text aus (eigener kleiner Leser, kein HTML). Ein Test verlangt einen Abschnitt je ausgeliefertem Addon.
- **Profile im Kern (API 25):** Gespeichert werden je Modul die Schlüssel aus `defaults` ohne `keepOnReset` und `debug`. So bleiben Fensterpositionen und Daten der Module unberührt, Charakterwerte reisen mit. Laden prüft jeden Wert wie beim Start und empfiehlt danach `/reload`. Eigene Unterseite Peon > Profile, damit die Seite Peon nicht zu lang wird.
- **Beispielfenster und UI-Prüfung nach Peon_Debug** (KarloDerBaer): `UIDemo.lua` und `UIProbe.lua` gehören nur zum Entwickeln. Ihre Tests liegen mit in Peon_Debug. Die Prüfungen der Bausteine `Peon.UI` bleiben als `tests/test_uikit.lua` im Repo.
- **Peon_ComboPoints entfernt** (KarloDerBaer, „jetzt entfernen“): Ordner, Test und Release-Eintrag weg, Changelog im Archiv. Neu `retired` in `scripts/release.json` und im Manifest, damit der Manager ab 0.48.0 ein noch installiertes ComboPoints weiter von selbst entfernt. Wer ClassBuddy noch nie geladen hat, verliert die Übernahme der Einstellungen. Das war bekannt und gewollt.
- **Nicht umgebaut:** die Sprachdatei von Profession (Blöcke je Version) und `test_broker.lua`. Beides bringt Spielern nichts und birgt Risiko.

## 18.11.2026: Aufräumen nach dem Review (Peon 0.24.1, Broker 0.103.2, Ledger 0.16.2, Manager 0.47.0)

- **Kein „im Spiel prüfen“ mehr in Stand und Changelog** (KarloDerBaer): KarloDerBaer prüft selbst und meldet es nicht mehr zurück. Fordert KarloDerBaer ein normales Release an, gilt der Stand als geprüft. Hinweise zum Prüfen nur, wenn KarloDerBaer sie ausdrücklich will.
- **Stand kurz:** `Peon_Stand.md` hat nur noch Version, Dateien, Daten, Befehle, Schnittstellen und echte offene Punkte (140 KB auf etwa 21 KB). Der alte Stand liegt unverändert in `docs/archiv/Peon_Stand_bis_2026-11-18.md`, die Entscheidungen bis Oktober in `docs/archiv/Peon_Entscheidungen_bis_2026-10.md`.
- **Prüfungen nur auf Befehl:** Ledger und Broker lesen Ereignisse und Aufrufe erst nach `/ledger pruefen` bzw. `/broker pruefen` bis zum `/reload` mit. Grund: Das lief bei allen Nutzern bei jedem Login mit und kostete Leistung.
- **Keine Weitergabe im Datenaustausch mehr** (Peon 0.24.1): auch Nachrichten von Peon 0.23.0 werden nicht mehr weitergegeben. In 0.23.0 hat nur die Begrüßung Daten getauscht, die Weitergabe ließ jeden Empfänger fremde Spieler anflüstern. `RandomNames`, `RELAY`, `FANOUT` und `MAX_HOPS` bleiben als Teil der Kern-API stehen. Dazu ein einmaliger Hinweis, dass Peon Daten teilt und wie man es ausschaltet, und ein Abschnitt Datenschutz in der README.
- **Angabe `api` im Manifest:** bleibt nur zur Auskunft (Kern-API, die ein Addon mindestens zum Laufen braucht). Der Manager wertet sie nicht aus, weil er Peon immer mit aktualisiert. Der Bau prüft, dass sie eine Zahl ist und nicht neuer als der Kern.
- **Fehler-Worker:** Die Sperre zählt Einträge statt Sendungen (20 je Stunde und Adresse, 60 insgesamt). Gleiche Fehler (Addon, Stelle, Meldung) kommen als Kommentar an das offene Issue. Wirkt erst nach `npx wrangler deploy` durch KarloDerBaer.
- **Globale Variablen:** `tests/test_globals.lua` liest den Bytecode jeder Addon-Datei und meldet unerwartete globale Variablen. Ohne Zusatzwerkzeug, läuft mit allen Tests und auf GitHub.
- **test_broker.lua bleibt eine Datei:** Die Abschnitte bauen aufeinander auf und teilen sich lokale Variablen. Ein Aufteilen wäre ein großer Umbau mit Risiko, Abdeckung zu verlieren. Neue, unabhängige Bereiche dürfen eigene Testdateien bekommen.
- **Manager bedienbar mit Tastatur:** Größe der Oberfläche (Strg und Plus, Minus, 0, Strg und Mausrad, Einstellung `zoom`), alle klickbaren Zeilen mit Tab und Enter, Dialog Rückmeldung schließt mit Escape.

## 19.11.2026: Addons nur lokal (Angabe `local` in release.json)

- **Umsetzung** (Claude): neue Angabe `"local": true` je Addon in `scripts/release.json`. Der Bau lässt solche Addons aus (kein Zip, nicht im Manifest) und prüft sie nicht auf ungespeicherte Änderungen, damit Arbeit daran ein Release nicht blockiert. Getestet wird über die Junction (Entwicklung). Der Manager zeigt sie dann als „Entwicklung (Repo)“ und fasst sie nicht an.

## 18.11.2026: Nachnahme in Peon Post ausgegraut (Ledger 0.16.1)

- **Haken ausgrauen statt Umweg** (KarloDerBaer): Nachnahme scheitert auf dem Forever-Server bei jedem Weg, auch mit Mausklick in Blizzards eigenem Fenster. Peon Post graut den Haken mit Hinweis aus, bis Blizzard den Serverfehler behebt. Der vorher gebaute sichere Knopf, der Blizzards Knopf „Senden“ drückt, ist verworfen, er half nicht.

## 18.11.2026: Rezepte der Freunde (Profession 0.6.0, Peon 0.24.0 mit API 24)

- **Nur Freunde und Gilde** (KarloDerBaer): Gespeichert und gezeigt werden nur Peon-Nutzer aus Freundesliste (auch Battle.net) und Gilde. Namen Unbekannter landen nicht beim Nutzer.
- **Nur der eingeloggte Charakter wird geteilt** (KarloDerBaer): Twinks bleiben unsichtbar.
- **30 Tage speichern** (KarloDerBaer), ab dem letzten Mal gesehen.
- **Anzeige in Spalte und Tooltip** (KarloDerBaer): Zahl der Freunde in „Erlernt“, Namen im Tooltip, hellblau.
- **Stand an alle, Listen nur auf Frage** (Claude, nach Konzept Abschnitt 8.3): Der Stand ist klein, die Listen gehen nur an Freunde, die sie wirklich brauchen. Fragen beantwortet Peon jedem, die Rezepte sind nicht privat.
- **`info.name` im Kern** (Claude): Für Namen in der Anzeige braucht der Dienst den Absender. Erweiterung als API 24, nur für Dienste mit erlaubter Namensanzeige.

## 18.11.2026: Wege für den Datenaustausch und erster Dienst (Peon 0.24.0)

- **An alle über den Kanal, an einen per Flüstern** (KarloDerBaer): Mit zwei Spielern geprüft, Kanal-Nachrichten erreichen alle Mitglieder. Eine Rundsendung ist eine Nachricht statt drei plus Weitergaben und erreicht alle, die online sind, sofort. Mitlesen kann jedes Addon im Kanal, die Daten sind aber nicht privat. Antworten und Nachholen per Flüstern. Nachrichten von 0.23.0 werden weiter weitergegeben.
- **Antwort nur auf die erste Begrüßung** (Claude): Sonst würde jede Begrüßung im Kanal eine Antwort von allen auslösen.
- **Prüfbefehl bleibt** (KarloDerBaer): `/peon teilen pruefen` hilft bei Problemen anderer Nutzer. Nur der überholte Test mit „Vorname-Nachname“ ist entfernt.
- **Regeln für Module** im Konzept Abschnitt 8 (Claude, mit KarloDerBaer abgestimmt): sparsam senden, Nachholen beim Einloggen, Daten prüfen, fremde Daten getrennt und als fremd erkennbar.
- **Erster Dienst: Rezepte der Freunde** (KarloDerBaer): Der Codex zeigt, welche Rezepte andere Peon-Nutzer kennen, weil Blizzards Berufslinks in Forever derzeit nicht beim anderen aufgehen. Erste Ausnahme von „keine Namen“. Einzelheiten werden vor dem Bau im Konzept von Peon_Profession geklärt.

## 17.11.2026: Kanal mittesten und privates Peon_Debug (Peon 0.23.0)

- **Begrüßung im Release zusätzlich über den Kanal** (KarloDerBaer): Die Prüfung allein zeigte, dass die eigene Kanal-Nachricht zurückkommt. Ob andere sie bekommen, zeigt das Release. Höchstens alle 30 Minuten eine, ohne Weitergabe, Antwort per Flüstern. Der Weg steht je Nutzer in `PeonDB.comm.peers`.
- **Mitgliederliste gebremst** (Claude, nach einer Trennung vom Chatserver im Test): höchstens eine Anfrage je Minute, keine Anfrage als Antwort auf eine angekommene Liste. Ob die Schleife die Trennung ausgelöst hat, ist nicht sicher, sie war aber ein Fehler.
- **Namen immer mit Nachnamen** (Claude, nach der Prüfung): Flüstern an den Vornamen allein scheitert in Forever. „Vorname Nachname“ und „Vorname-Nachname“ gelten als derselbe Spieler.
- **Peon_Debug nur für KarloDerBaer** (KarloDerBaer): Zeigt die Nachrichten von Peon, Kanal und Flüstern getrennt schaltbar. Liegt in `privat/` (in `.gitignore`), nicht in `addons/`, weil der Release-Bau jeden Ordner in `addons/` erwartet. Ins Spiel kommt es über eine von Hand angelegte Junction. Der Kern bekommt dafür `Peon.Comm.Listen` und `Peon.Comm.SetShow`. Der Peon Manager fasst Addons, die nicht in seiner Liste stehen, nicht an.

## 17.11.2026: Datenaustausch im Kern, erster Schritt nur Kennenlernen (Peon 0.23.0, API 23)

- **Noch keine Dienste der Module** (KarloDerBaer): Über das nächste Release erst testen, ob der Austausch funktioniert. Dafür reicht ein unsichtbares Kennenlernen, das sich danach ansehen lässt. Der Kern meldet dafür selbst den Dienst `hello` an (Version und Kern-API), das Ergebnis steht in `PeonDB.comm`. Die Sammelstellen von Peon_Profession folgen danach.
- **Kanal `PeonNet`**, Ausweichnamen `PeonNet2` und `PeonNet3` (KarloDerBaer).
- **Stand in den Kern-Optionen** unter dem Schalter „Daten mit anderen Peon-Nutzern teilen“, dazu `/peon teilen` (KarloDerBaer). Keine Anzeige in Peon_Panel.
- **Prüfung im Spiel an sich selbst** (KarloDerBaer): `/peon teilen pruefen` schickt eine Addon-Nachricht in den Kanal und ein Addon-Flüstern an den eigenen Charakter und liest die Mitgliederliste.
- **Alle Nachrichten per Flüstern, der Kanal nur als Treffpunkt** (Claude, nach dem Fund aus PLG). Eigene Nachricht an 3, weitergegeben an 2, höchstens 3 Sprünge, Takt 1,25 Sekunden, nicht im Kampf und nicht in Instanzen. Beim ersten Sprung muss der Prüfwert zum Absender passen.
- **Eigenes Verpackungsformat ohne Ausführen von Lua-Code** (Claude): Daten aus dem Netz sind fremd, deshalb kein `loadstring`. Unbekannte Dienste werden weitergegeben, aber nicht zugestellt, damit neuere Module ihre Daten auch über ältere Peon-Versionen verbreiten. Ein neueres Nachrichtenformat wird weder verstanden noch weitergegeben.
- **Keine Namen in PeonDB** (Konzept): Namen liegen nur im Speicher zum Zustellen, gemerkt wird der Prüfwert. Module bekommen statt des Namens eine Funktion `info.reply` für Antworten.

## 17.11.2026: Codex und Sammelstellen in Peon_Profession (Profession 0.5.0, Fishing 1.7.0)

- **Aus Mastercraft nur Ideen, keine Daten und kein Code** (KarloDerBaer, nach Hinweis von Claude): Mastercraft steht unter „alle Rechte vorbehalten“, seine Daten kommen von Wowhead. Große Datenmengen per Skript aus Wowhead zu ziehen verstößt gegen deren Nutzungsbedingungen und den Schutz von Datenbanken. Einzelne Fakten von Hand und eigene Messungen bleiben erlaubt.
- **Daten nur aus dem, was Peon schon hat, plus eigene Sammlung im Spiel** (KarloDerBaer): Routen, erlernte Rezepte, Lehrer- und Händlerfenster, Sammelstellen, Fänge aus Peon_Fishing.
- **Codex und Sammelstellen in Peon_Profession, kein eigenes Modul** (KarloDerBaer).
- **Keine Anzeige auf Welt- und Minikarte vorerst** (KarloDerBaer): Die gelben Punkte der Kräuter- und Erzsuche zeichnet das Spiel selbst, ein Addon kann sie nicht lesen oder einzeln umfärben. Der Vorschlag mit Ring und durchscheinendem Punkt an bekannten Stellen bleibt im Konzept für später.
- **Sammelstellen ab jetzt mitschreiben, Gebiete im Codex und im Guide** (KarloDerBaer).
- **Fische bleiben in Peon_Fishing**, Profession liest sie über die neue Schnittstelle `CatchZones` (Claude, im Sinne von „verbinden statt zusammenlegen“).
- **Rezepte aus Route, Lehrer, Händler und allen Charakteren in einer Zeile, zusammengeführt über den Namen** (Claude, beim Bau): Lehrer und Händler nennen keine Nummer des Rezepts. Bei Händlern wird der Vorsatz wie „Rezept:“ entfernt.
- **Datenaustausch über Addon-Flüstern im Kern, Bau in eigener Sitzung** (KarloDerBaer): Entwurf `docs\konzepte\kern\Peon_Comm_Konzept.md`. Von Anfang an an und abschaltbar, fremde Daten sofort sichtbar und als fremd erkennbar.

## 17.11.2026: Suchen beim Öffnen (Warhorn 0.3.2)

- Beim Öffnen der Gruppensuche sucht Warhorn gleich (KarloDerBaer). Nur auf der Seite Suchen und höchstens alle 5 Sekunden (Claude): Blizzard öffnet die Gruppensuche auch von selbst, etwa mit der Antwort der Wer-Liste. Ohne Klick würde das Spiel die Suche blockieren.
- Reiter Einstellungen unten am rechten Rand (KarloDerBaer).

## 17.11.2026: Korrekturen nach dem Test von 0.3.0 (Warhorn 0.3.1)

- Größe wie Ledger, 800 x 538 (KarloDerBaer).
- Spielstil beim Eintragen, Vorgabe Entspannt (KarloDerBaer).
- Der Kommentar-Knopf wechselt Blizzards Seite Eintragen mit Blizzards `SetCategorySelection` in die Ansicht mit dem Kommentarfeld (Claude). Das ruft eine Funktion von Blizzards Fenster aus Warhorn auf. Ob Blizzards eigenes Eintragen danach noch geht, wird im Spiel geprüft. Eingetragen wird ohnehin in Warhorn.

## 17.11.2026: Alle Seiten der Gruppensuche und Einstellungen (Warhorn 0.3.0)

- Eintragen und Wer-Liste bekommen Warhorn-Seiten, dazu ein Reiter Einstellungen rechts (KarloDerBaer, Konzept Abschnitt 13).
- Eintragen alles auf einer Seite (KarloDerBaer). Wer-Liste mit Filtern, Anflüstern und Einladen und Schnellsuche (KarloDerBaer). Flüstern über ein eigenes Fenster mit Textfeld und Vorlagen, nie von selbst (KarloDerBaer). Einstellungen: welche Seiten Warhorn ersetzt, Spalten und Farben, dazu die Vorlagen (KarloDerBaer).
- Das Fenster hängt an Blizzards ganzem Fenster statt an der Suchseite und wechselt die Seite mit Blizzards Reiter (Claude): So bleibt Blizzards Seite darunter offen, und Blizzards Abläufe (Wer-Antwort, Eintrag) laufen weiter.
- Kommentar beim Eintragen über Blizzards Seite (Claude): Blizzards Kommentarfeld ist geschützt (`SetSecurityDisableSetText`), ein Addon kann dort keinen Text setzen.
- Spalten ausblenden baut die Liste neu auf (Claude): Peons Tabelle kennt kein Ausblenden einzelner Spalten. Die erste Spalte bleibt immer.
- Die Vorlagen bleiben bei „Standardwerte“ (Claude): Sie sind eigene Texte und gingen sonst verloren.

## 17.11.2026: Suchen bei jeder Änderung (Warhorn 0.2.2)

- **Bei jeder Änderung an Auswahl und Filter sucht Warhorn gleich neu** (KarloDerBaer). Das ersetzt „Suchen nie automatisch“ aus dem Konzept für Änderungen durch den Spieler. Ein Zeitgeber sucht weiterhin nie, das lässt das Spiel nicht zu.
- Die Stufe sucht erst mit der Eingabetaste, beim Tippen wird nur gefiltert (Claude): sonst eine Suche je Ziffer.
- Rollen ohne „+n“, freier Platz als grüne Zahl (KarloDerBaer wollte das „+n“ weg, die grüne Zahl hat Claude gewählt, damit die freien Plätze sichtbar bleiben).
- Warhorn nicht von selbst auf Leiste und Panel (KarloDerBaer), über `DEFAULT_ENTRIES` in Peon_Panel.

## 17.11.2026: Korrekturen nach dem ersten Blick im Spiel (Warhorn 0.2.1)

- Warhorn liegt in der Schicht HIGH statt auf einer höheren Ebene in Blizzards Schicht (Claude): Blizzards Suchseite ist selbst ein Fenster mit Rahmen auf hoher Ebene. Eine feste Ebene wie bei Broker hätte auch Warhorns eigenen Rahmen betroffen. Andere Fenster der Schicht MEDIUM liegen damit unter Warhorn.
- Öffnet man die Gruppensuche, springt sie auf den Reiter „Suchen“, solange Warhorn eingeschaltet ist (Wunsch KarloDerBaer). Kein eigener Haken dafür, der Haken „Warhorn zeigen“ gilt auch hier.
- Im modernen Stil wandern Blizzards Reiter rechts an Warhorns Rand, solange Warhorn zu sehen ist (Claude). Warhorn ändert dafür nur ihren Anker und setzt ihn danach zurück.

## 17.11.2026: Gruppensuche mit Filtern gebaut (Warhorn 0.2.0)

- **Alles in einem Zug** statt 0.2 bis 0.4 nacheinander (KarloDerBaer).
- Die Fläche hängt an Blizzards Suchseite `LFGBrowseFrame`, nicht an `LFGParentFrame` (Claude, beim Bau): Blizzard zeigt die Suchseite nur auf dem Reiter „Suchen“, Warhorn verschwindet so auf den Reitern zum Eintragen und der Wer-Liste von selbst.
- Unterkante an Blizzards Reiter `LFGParentFrameTab1` gehängt, damit die Reiter bedienbar bleiben. Die Titelleiste lässt Klicks durch, damit Peon_Mover das Fenster weiter verschieben kann (Claude).
- Gruppengröße als Auswahl „höchstens 2, 3 oder 4“ im Filtermenü statt zweier Zahlenfelder (Claude, weniger Felder in der Leiste).
- Sortierung zu Beginn nach Alter statt nach freiem Platz (Claude): Der Rollenfilter zeigt schon nur passende Gruppen. Nach freiem Platz sortiert ein Klick auf „Rollen“.
- `/warhorn` öffnet die Gruppensuche über Blizzards `LFGVanilla_ToggleFrame` (Claude). Ob das im Spiel ohne Fehlermeldung geht, wird geprüft.

## 17.11.2026: Konzept Gruppensuche mit Filtern (Peon_Warhorn, Konzept `Peon_Warhorn_Konzept.md`)

- **Fläche über Blizzards Suchseite wie bei Broker** (KarloDerBaer) statt eines angedockten Fensters (Vorschlag Claude). Knopf zum Umschalten auf Blizzards Original (KarloDerBaer). Sofort ohne Neuladen, weil Warhorn nichts in Blizzards Tabellen schreibt (Claude).
- **Eigene Auswahl der Dungeons in Warhorn**, zu Beginn aus Blizzards Auswahl (KarloDerBaer).
- **Klassenfilter „nur mit“ und „nur ohne“** bei Gruppen, dazu „Ohne meine Klasse“ (KarloDerBaer).
- **Suchen nie automatisch**, nur über Knopf und Taste (KarloDerBaer). Das Mitsuchen bei Klicks entfällt.
- Ein Eintrag mit einem Mitglied gilt als Einzelspieler, wie bei Blizzard (Claude, nach den Messdaten: Titel und Kommentar waren immer leer).

## 17.11.2026: Neues Modul Peon_Warhorn, Gruppensuche mit Filtern (Warhorn 0.1.0)

- **Eigenes Modul für Gruppen, Dungeons und Raids** (Wunsch KarloDerBaer). Name Peon_Warhorn (Vorschlag Claude, gewählt von KarloDerBaer): das Kriegshorn ruft die Truppe zusammen und der Name deckt Suchen, Dungeons und Raids ab.
- **Filter nach Klassen und Rollen in beide Richtungen** (KarloDerBaer): Gruppen, denen eine Rolle oder Klasse fehlt, und Einzelspieler nach Klasse und Rolle.
- **Eigene Liste statt Filter in Blizzards Liste** (Claude, zugestimmt): Ein Filter in Blizzards Liste müsste in Blizzards Tabelle und Sortierung eingreifen (Taint, danach können Knöpfe wie „Einladung anfragen“ gesperrt sein). Wie bei Broker dockt ein eigenes Fenster an.
- **Erst ein Prüfaufbau** (Claude, zugestimmt): `C_LFGList.Search` ist in Blizzards Code als eingeschränkt markiert (`HasRestrictions`), in Retail heißt das nur nach Klick oder Tastendruck. Ob eine automatische Aktualisierung mit Zeitgeber geht, klärt die Prüfung im Spiel. Namen anderer Spieler und Texte der Einträge speichert die Prüfung nicht.

## 17.11.2026: Markt in der Marktübersicht, Stabilität in der Übersicht (Manager 0.46.0)

- **Markt wird Reiter der Marktübersicht** (Wunsch KarloDerBaer). Er ist der erste Reiter und öffnet sich zuerst. Die Marktübersicht rückt in der Leiste an die frühere Stelle des Markts (Claude, beim Bau: der Markt ist die meistgenutzte Seite).
- **Stabilität des Markts in der Übersicht mit Verlauf** (Wunsch KarloDerBaer). Eigenes Diagramm statt einer dritten Linie im Diagramm der Angebote (Claude, beim Bau: Index 0 bis 100 und Angebotszahlen passen nicht auf dieselben Achsen).

## 17.11.2026: Stabilität der Preise (Manager 0.45.0)

- **Stabilitätsindex je Gegenstand, Kategorie und Markt** (Wunsch KarloDerBaer). Besonders wichtig: Stundenwerte und Massen- und Handwerksware.
- **Preis:** Massenware die günstigsten 25 %, sonst das günstigste Angebot (KarloDerBaer).
- **Stunden und Tage zusammen, der schlechtere Teil zählt** (Vorschlag Claude nach Messung mit echten Daten, KarloDerBaer zugestimmt). Grund: Beide Sichten hängen nur schwach zusammen. Je Stunde ruhig kann über Tage stark fallen (Teufelsleder), je Stunde unruhig kann über Tage fest sein (Aquamarin).
- **Bewegung je Stunde als Mittel ohne die größten 5 %**, nicht der Median (Claude): Der Median ist fast überall 0 %, weil sich der Preis meist nicht bewegt.
- **Grenzen** Stunden 1/3/6/10 %, Tage 8/15/25/40 % (Claude, nach der Messung, KarloDerBaer zugestimmt). Index so, dass die Grenzen bei 80/60/40/20 liegen (Claude, beim Bau: Stufe und Index passen so immer zusammen).
- **Richtung zählt nicht in den Index**, sie steht daneben (Vorschlag Claude, zugestimmt).
- **Gegenstände mit weniger als 20 Angeboten im Schnitt zählen nicht** für Kategorie und Markt, auch Massenware (Claude, beim Bau: dünne Märkte springen stark).
- **Kategorien aus der Blizzard-API** statt aus Broker (Claude, beim Bau): Die Spieldaten jedes Gegenstands enthalten Klasse und Unterklasse schon, so braucht es keine Änderung an Broker.

## 17.11.2026: Verworfene Chancen merken und an den Manager melden (Broker 0.101.0, Manager 0.44.0)

- **Weg gilt bis zum nächsten Stand** (Wunsch KarloDerBaer): Eine Chance, die beim Prüfen weg ist, kommt erst wieder, wenn der Manager sie mit einem neueren Stand erneut als Chance bewertet. Grund: Nach jedem Reload musste man dieselben Chancen wieder prüfen.
- **Format der Rückmeldung** (KarloDerBaer): `PeonBrokerDB.chancesGone[Markt][Schlüssel] = "Stand:Zeit:Angebot"`. Der Manager liest es direkt aus `Peon_Broker.lua` wie die Einschätzungen, Peon_Bridge bleibt unverändert.
- **Im Manager ausblenden mit Hinweis** (KarloDerBaer): wie Daumen runter nicht in der Liste und nicht an Broker, darunter eine Zeile mit Gegenstand, Zeitpunkt und Angebot.
- **Im Spiel sichtbar bis zum Verlassen des Reiters** (KarloDerBaer): Eine gerade verworfene Zeile bleibt als „weg“ stehen, damit man sieht, was passiert ist.

## 16.11.2026: Schreiben, Rechnen und Lesen in eigenen Prozessen (Manager 0.43.0)

- **Drei Arbeitsprozesse** (KarloDerBaer 15.11.2026: „Schreiben und Rechnen sollten doch nicht in einem Prozess sein“): Der Schreib-Prozess nimmt Eingaben und neue Stände an und schreibt Data.lua, der Rechen-Prozess rechnet, der Lese-Prozess bedient die Ansichten. Grund: Eine Eingabe wartete bis zu 15 Sek. hinter einer Rechnung.
- **Ergebnisse in der Datenbank** statt nur im Speicher (KarloDerBaer): Die Rechnung läuft einmal je Stand, die Ansichten lesen ihr Ergebnis. Ein Ergebnis zu einem älteren Stand ist während der Rechnung recht, eines zu alten Regeln nie.
- Ein neuer Stand selbst wird weiter im Schreib-Prozess eingelesen. Eingaben können also kurz warten, während ein Stand hereinkommt, aber nicht mehr während einer Rechnung.

## 15.11.2026: Daten des Managers gestuft aufheben, Arbeitsprozess zum Lesen (Manager 0.40.0 bis 0.42.0)

- **Live-Abfragen aus Broker** zählen nicht mehr für den Absatz und lösen keine Neurechnung aus (KarloDerBaer): Seit die Blizzard-API stündlich ganze Stände liefert, trugen sie fast nichts bei, jede kostete aber eine volle Neurechnung. Sie bleiben 7 Tage für den neuesten Preis.
- **Stufen der Aufbewahrung** (KarloDerBaer, mit Stundenwerten für 7 Tage statt 3): 7 Tage je Stand, 3-Stunden-Werte bis 28 Tage, danach Tageswerte. Die einzelnen Angebote 2 Tage (API) bzw. 14 Tage (eigene Scans). Grund: Die Datenbank wuchs um 150 MB je Tag auf absehbar 7 bis 8 GB. Nachteil, bewusst in Kauf genommen: Geänderte Regeln für den Absatz lassen sich nur 2 Tage zurück neu rechnen.
- **Ansichten lesen über einen eigenen Arbeitsprozess**: Das Fenster wartet nie auf eine Neurechnung. Abgeleitete Werte (Bereich, Absatz, Chancen) zeigen den Stand der letzten fertigen Rechnung, was bei stündlichen Daten unkritisch ist (KarloDerBaer).

## 14.11.2026: Regel „Seelentasche minus 1“ als Standard (ClassBuddy 0.3.0)

- **Ein Platz der Seelentasche bleibt frei** (KarloDerBaer): So fällt ein neuer Splitter nie in eine normale Tasche, auch nicht kurz. Neuer Standard. Der alte Standard „Seelentasche voll“ wird einmal umgestellt (Claude), eigene Wahl bleibt danach.
- **Normales Release ohne eigene Vorabversion für 0.3.0** (KarloDerBaer): 0.2.0 lief in der Vorabversion `v2026.11.14.5-test`, 0.3.0 bringt nur die neue Regel.

## 14.11.2026: Seelensplitter mit Zaubern, ClassBuddy ersetzt ComboPoints (ClassBuddy 0.2.0, ComboPoints 3.6.0)

- **Vernichten mit jedem Zauber von der Aktionsleiste** (KarloDerBaer nach der Prüfung mit 0.1.0): Ohne Tastendruck sperrt das Spiel, mit Klick, Makro und Aktionstaste geht es, auch im Kampf. Je Zauber höchstens ein Splitter, Fehlversuche still und beim nächsten Zauber neu (Vorschlag Claude). Makro, Tastenbelegung und Panel als Rückfall.
- **Gesperrte Plätze überspringen** (Claude): Der einzige Fehlversuch im Kampf kam vermutlich von einem Platz, der nach dem Vernichten oder Zurücklegen noch gesperrt war. Ein Zauber mit Zielkreis war es laut Mitspieler nicht.
- **Einstellungen flach statt je Klasse** (Claude, beim Bau): Die Bausteine der Optionsseite arbeiten mit Schlüsseln der obersten Ebene. Die Combo-Punkte behalten ihre Namen, damit die Übernahme einfach bleibt.
- **Übernahme beim Einloggen** (Claude, beim Bau): Peon_ComboPoints lädt alphabetisch nach Peon_ClassBuddy, seine Einstellungen sind erst danach da. Peon_ComboPoints 3.6.0 bleibt still, wenn der Klassenbuddy geladen ist, und behält seine Einstellungen.
- **Testfenster wieder entfernt** (wie bei KarloDerBaers Wunsch angekündigt: verschwindet mit der nächsten Version).

## 14.11.2026: Neues Modul Peon_ClassBuddy (Konzept abgestimmt)

- **Ein Modul für Klassenhelfer** (Wunsch aus dem Feedback, KarloDerBaer): Name im Code `Peon_ClassBuddy`, angezeigt „Klassenbuddy“. Es ersetzt Peon_ComboPoints, die Einstellungen werden übernommen.
- **Seelensplitter: Regel einstellbar, Standard „Seelentasche voll“** (KarloDerBaer). Alternative ist eine Höchstzahl.
- **Vernichten zusammen mit einem Zauber** (KarloDerBaer): Automatisch ohne Tastendruck wird es wahrscheinlich nicht gehen, vor allem nicht im Kampf. Bevorzugt hängt sich ClassBuddy an die Aktionstasten und vernichtet je Zauber einen Splitter, Rückfall ist ein Makro mit `/click` (Vorschlag Claude). Vorher klärt ein Prüfbefehl im Spiel, was erlaubt ist.

## 14.11.2026: Buch mit klarem Handelsgewinn (Ledger 0.15.0, Peon 0.21.0)

- **Handelsgewinn nur aus dem Handel** (KarloDerBaer): Zeilen AH: Käufe, Einstellgebühren, Abbruchkosten, Verkäufe, Anteil, darunter AH: Handelsgewinn. Der Rest ist Spielalltag, am Ende AH: Handelsgewinn, Spielalltag, Gesamtergebnis. Spielerhandel als eigene Zeile.
- **Zurückgezahlte Einzahlung als Einnahme bei den Einstellgebühren, Abbruchkosten als eigene Zeile** (KarloDerBaer).
- **„davon“-Zeilen unter dem Handelsgewinn** (Vorschlag Claude, zugestimmt): Die AH-Zeilen sind Geldfluss, der Handelsgewinn rechnet nur verkaufte Stücke. „davon ins Lager“ ist der Rest, so geht die Rechnung immer auf.
- **Beute und Startbestand zählen nicht zum Handelsgewinn** (Vorschlag Claude, zugestimmt), Name „AH: Verkauf Beute“ (KarloDerBaer). Hergestelltes wird nach Marktwert des erbeuteten Materials gegen Kosten des gekauften aufgeteilt (KarloDerBaer). Gekaufte Ware beim Händler zählt zum Handelsgewinn, Ware an Spieler zum Spielerhandel.
- **Gebühren teilen sich nach dem Beuteanteil** (Claude, beim Prüfen mit echten Daten): Sonst drückten die Einzahlungen für verkaufte Beute den Handelsgewinn. Offene Gebühren verteilen sich auf die Stücke im Auktionshaus statt alle auf den ersten Verkauf.
- **Trennstrich über den Kern** (Claude, beim Bau): `UI.Table` mit `o.rowLine`, Kern-API 21, weil der Kern nur erweitert wird.
- **Post in der Ruhezeit, Kontrollrechnung mit „Unterwegs“, einmalige Reparatur, Fortschritt beim Einsammeln** (KarloDerBaer nach dem Fehler mit Twink-Post). Ein langsameres Einsammeln hätte nicht geholfen, die Ursache war die Ruhezeit von 20 Sekunden nach dem Einloggen.

## 15.11.2026: Reiter Chancen in Broker, Muster, Händler nur im Radar (Broker 0.96.0, Manager 0.39.0)

- **Händler nur noch im Radar, im Manager gelöscht** (KarloDerBaer). Die Angebote sind meist nach Minuten weg.
- **Eigener Reiter „Chancen“ rechts neben dem Radar, Fokus links neben Beobachten** (KarloDerBaer). Chancen sind Beobachtungen über Tage, das Radar zeigt, was ein Scan gerade findet. Das Radar gibt die Kandidaten des Managers ganz ab (KarloDerBaer).
- **Meldungen einstellbar über ein Fenster Einstellungen im Reiter Chancen** (KarloDerBaer): Hinweis beim Öffnen des Auktionshauses und beim Beginn eines günstigen Zeitfensters, beide ab Werk an (Claude).
- **Neue Art Muster nach Tageszeit und Wochentag** (Idee KarloDerBaer, Regeln Claude, zugestimmt): Trend herausrechnen, Tageszeit ab 14 Tagen, Wochentag ab 3 Wochen, strenge Grenzen. Die Messung mit 10 Tagen zeigte nur Scheinmuster durch den fallenden Markt.
- **Live-Prüfung über den Radar-Teil** (Claude, beim Bau): Der Reiter Chancen nutzt dieselbe Abfrage, denselben Fokus und denselben Kauf, nur die Anzeige ist getrennt.

## 14.11.2026: Chancen nach Prüfung mit echten Daten (Manager 0.37.0)

- **Ein fallender Preis schließt Spekulation aus** (KarloDerBaer). Auch wenn es dadurch erst kaum Vorschläge gibt, der Markt muss sich einpendeln.
- **7 Tage Preisverlauf vor Spekulation und Aufkauf, Schwankung höchstens 40 %** (Vorschlag Claude, zugestimmt). Die 7 Tage sind fest, weil das Konzept höchstens 5 Regler je Art erlaubt (Claude, beim Bau).
- **Umgestellte Angebote sind keine Verkäufe** (Claude, aus der Messung): Billiger mit gleicher Menge neu eingestellt oder über einem stehenden billigeren Angebot verschwunden gilt als abgebrochen. Nur für Stände der Blizzard-API, die Scans im Spiel bleiben wie Brokers `Sales.lua`. Die bisherigen Vergleiche werden neu gerechnet, belegte Verkäufe beginnen neu.
- **Gold aus Ledger statt aus Broker** (Claude, beim Bau): Ledger speichert das Gold je Charakter mit Fraktion schon, Broker muss nichts übergeben. Ohne Ledger keine Grenze.
- **Einsatz höchstens 25 % des Golds je Chance, als Regler** (Vorschlag Claude). Aufkauf ganz oder gar nicht, weil er nur wirkt, wenn alle Stufen gekauft sind.

## 14.11.2026: Schneller Start, Datenordner, Rückmeldungen zu Chancen (Manager 0.36.0, Bridge 0.12.0)

- **Datenordner im Manager verlegbar** (KarloDerBaer, lieber auf D:). Der Manager kopiert beim Neustart vor dem Öffnen der Datenbanken, der alte Ordner bleibt als Sicherung liegen und wird nicht gelöscht (Claude). Auf D: kann Claude die Daten auch lesen, unter `%APPDATA%` sieht die Claude-App eine alte Kopie.
- **Beim Start ist das Fenster sofort bedienbar** (KarloDerBaer: wenigstens Einstellungen öffnen können). Einlesen und Aufräumen warten auf die erste Übersicht (Claude).
- **Händlerpreise einmal neu aus dem Spiel** (Claude): Bis 0.35.0 haben Stände der Blizzard-API den Wert aus dem Spiel überschrieben, Schema 10 konnte das nicht erkennen.
- **Daumen runter blendet eine Chance aus, auch für Broker** (KarloDerBaer). Bewertung löschen holt sie zurück, „An Broker“ geht vor (Claude).
- **Spekulation schnell: Zielpreis höchstens am oberen Rand des üblichen Bereichs, kein Vorschlag bei fallendem Preis** (Claude, aus den Rückmeldungen zu Schmiedehammer und Imperialer Plattenrüstung). Grenze für „fällt“: die letzten 3 Tage 15 % unter den Tagen 7 bis 14.
- **Käufe aus der Erfolgskontrolle nehmen** (KarloDerBaer), je Kauf mit „Behalte ich“.
- **Noch offen:** Gold, Einsatz und möglicher Verlust bei Chancen (KarloDerBaer). Braucht eine Abstimmung, wie Broker das Gold übergibt und wie die Menge begrenzt wird.

## 14.11.2026: Buchhändler mit Wegpunkt (Peon_Profession 0.3.0)

- **Bücher für Experte mit Händler und Kartenmarkierung** (KarloDerBaer): Erste Hilfe, Kochkunst und Angeln. Das ergänzt „Lehrer nur als Text“ vom selben Tag, für die Lehrer der übrigen Berufe bleibt es dabei (Claude).
- **Händlerdaten aus PLG übernommen** (Claude): dort im Spiel auf dem Forever-Client gesammelt, mit Nummer, Karte und Koordinaten. Wegpunkt mit Blizzards eigener Kartenmarkierung, ohne TomTom.

## 14.11.2026: Peon_Profession 0.2.0 nach dem ersten Test, Umzug des Berufsfensters (Broker 0.95)

- **Brokers Teil im Berufsfenster zieht jetzt um (S6)** (KarloDerBaer, zusammen mit den Wünschen nach dem ersten Test). Bei Broker bleiben Preise, Vorrat und Einkaufslisten, Peon_Profession fragt sie über die Schnittstelle ab. Die alten Einstellungen werden einmal übernommen (Claude).
- **Markierungen in der Rezeptliste: grüner Pfeil links für das Rezept des Guides, Goldmünze vor dem Gewinn für das beste Rezept** (KarloDerBaer, aus vier Vorschlägen von Claude). Der Pfeil steht im Einzug links neben der Zeile, weil zwischen Zeilenrand und Blizzards Pfeilen kaum Platz ist (Claude, beim Bau). Ob er dort sichtbar ist, zeigt der Test im Spiel.
- **Knopf in der Titelleiste des Berufsfensters** öffnet Peon Berufe (KarloDerBaer). Die Leiste über dem Fenster bleibt, beide sind abschaltbar (Claude).
- **Alle Berufe zeigbar, Zielstufe frei wählbar, ganze Route bis 300, Material bis zum Ziel** (KarloDerBaer). Umsetzung als Haken unter der Liste, Feld „Ziel“ im Kopf und Reiter Guide, Route, Material (Claude). Ohne Eingabe gilt der Höchstwert, ist er erreicht der nächste Rang, bei nicht gelernten Berufen 75 (Claude).
- **Box neben dem Berufsfenster bleibt als Rückfall** (Claude): Sie wurde mit übernommen statt entfernt, weil nichts ohne Zustimmung wegfallen soll.

## 14.11.2026: Neues Modul Peon_Profession (Konzept `Peon_Profession_Konzept.md`, freigegeben)

- **Eigenes Berufe-Modul statt Profession Leveling Guide** (KarloDerBaer): einfach, im Peon-Stil, mit Preisen und Einkaufsliste von Broker. Ohne Gilde, Streamer-Modus, Spieler-Netz und andere Zusatzfunktionen.
- **Name `Peon_Profession`** (KarloDerBaer): Alles rund um Berufe soll dort Platz haben. Brokers Teil im Berufsfenster zieht später um (S6), erst nach der Prüfung des Guides im Spiel. Preise und Einkaufslisten bleiben bei Broker.
- **Alle Berufe**, auch Sammelberufe und Angeln (KarloDerBaer).
- **Leiste am Berufsfenster, abschaltbar. Lehrer nur als Text** (KarloDerBaer).
- **Daten einmal aus PLG 2.7.2 umwandeln, danach nur eigene Messungen** (KarloDerBaer). PLG steht unter MIT-Lizenz, der Hinweis steht in `Routes.lua`. Texte aus Wowhead-Guides und Daten aus QuestieDB (GPL) werden nicht übernommen (Claude). Der Autor wird nicht eigens angeschrieben (KarloDerBaer).
- **Leiste außerhalb über dem Berufsfenster** (Claude, beim Bau): So verdeckt sie weder Blizzards Inhalt noch Brokers Block.
- **Lehrer-Hinweis ohne Datenbank** (Claude, beim Bau): Der Rang folgt aus dem Höchstwert (75, 150, 225), die Charakterstufe aus den festen Grenzen 10, 20, 35. Kochkunst, Erste Hilfe und Angeln nennen für Experte ein Buch.
- **Einkaufsliste je Beruf mit dem ganzen Bedarf** (Claude, beim Bau): Die Liste heißt „Beruf: <Name>“, die Wunschmenge wird bei jedem Klick ersetzt, „Fehlt“ rechnet Broker gegen den Vorrat.

## 14.11.2026: Händlerpreis und Rückmeldungen zu Chancen (Manager 0.35.1)

- **Händler-Chancen nur mit dem Händlerpreis aus dem Spiel** (KarloDerBaer, Vorschlag Claude): Die Blizzard-API nennt für Forever oft den Preis aus den Classic-Daten. Ein solcher Preis steht in der Prüfliste als nicht bestätigt.
- **Rückmeldungen zu Chancen gehen über den Reiter Rückmeldungen mit** (KarloDerBaer): Claude sieht die Datenbank des Managers nicht. Über die Berichte lassen sie sich für spätere Verbesserungen auswerten.

## 13.11.2026: Chancen und Prognosen im Manager (Konzept `Peon_Manager_Chancen.md`, freigegeben)

- **Konzept freigegeben**, Bau aller Abschnitte in einem Zug (KarloDerBaer).
- **Startwerte wie im Konzept** (KarloDerBaer): Über die Regler mit Probe lassen sie sich später anpassen.
- **Wiederverkauf sofort abgelöst** (KarloDerBaer): Spekulation schnell rechnet dasselbe mit belegten Verkaufspreisen. Bis genug Verkäufe gesammelt sind, gibt es dafür kaum Vorschläge. Die Trefferquote F55 geht in der Erfolgskontrolle auf.
- **Fallend, Steigend und Lohnend in die Marktübersicht, Radar (WIP) wird zu Chancen** (KarloDerBaer, Vorschlag Claude): Chancen zeigt nur Kaufvorschläge, die Marktübersicht alles Beschreibende.
- **Feste liest Peon_Broker** (KarloDerBaer): Broker kann sie so auch selbst nutzen, die Bridge reicht sie an den Manager weiter. Für den Dunkelmond-Jahrmarkt schaltet Broker `calendarShowDarkmoon` kurz ein und zurück wie Questie (KarloDerBaer, Vorschlag Claude).
- **Probe mit Rückmeldungen** (KarloDerBaer, Vorschlag Claude): Die Probe beim Verschieben eines Reglers nennt auch, wie viele der betroffenen Vorschläge bewertet wurden.
- **Übergabe an Broker (K6) vor den Prognosen (K7)** (KarloDerBaer, Vorschlag Claude): K1 bis K6 ergeben die erste nutzbare Fassung.
- **Beim Bau (Claude):** Der Manager liest Feste und Einschätzungen direkt aus `Peon_Broker.lua`, wie schon Händler, Einkaufslisten und Beobachtung. Die Bridge gibt nur die Kandidaten an Broker. Ein eigener Rückweg über die Bridge hätte nichts gebracht.
- **Beim Bau (Claude):** Die Kandidatenliste bekommt als siebtes Feld die Menge, damit Broker Einsatz und Gewinn zeigen kann, bevor er live prüft. Das Format ist damit nur erweitert.
- **Beim Bau (Claude):** Neben jedem Vorschlag speichert der Manager auch Beinahe-Vorschläge (halber Abstand erreicht). Nur so kann die Probe sagen, was mit lockereren Reglern dazukäme.
- **Beim Bau (Claude):** Neue Signale (unter 20 Nachprüfungen) ergeben höchstens eine Prognose mit niedriger Sicherheit. Spekulation langfristig braucht mittlere Sicherheit und erscheint deshalb erst, wenn sich Signale bewährt haben.
- **Beim Bau (Claude):** Die benötigte Stufe holt der Manager in Minuten ohne Abruf der Auktionshäuser, etwa 100 Gegenstände je Minute. Der Stufenbereich-Index ist so nach einigen Stunden vollständig.

## 13.11.2026: Wünsche aus den Fehlerberichten (Broker 0.91, Ledger 0.14.8, Peon 0.20.1)

- **Kaufen im Fokus mit einem Klick, außer bei Preiswarnung** (KarloDerBaer, Vorschlag Claude): Das Spiel verlangt den echten Klick nur für den Start des Kaufs, die Bestätigung darf Broker selbst senden. Ist der Gesamtpreis höher als erwartet, bleibt der zweite Klick als Schutz.
- **Wiedereinstellen merken gilt für alle Käufe, Standard aus** (KarloDerBaer): Auch Aufkäufe aus dem Radar werden nur noch Posten, wenn der Gegenstand dafür eingeschaltet ist. Die Vorgabe lässt sich in den Einstellungen des Fokus ändern.
- **Einschätzung einer Chance erst nur im Spiel** (KarloDerBaer): Gespeichert in den Broker-Daten mit allen Werten des Moments, die Auswertung im Peon Manager kommt später.
- **Ton je Gegenstand über das Rechtsklick-Menü** (Claude): In der Liste Beobachten ist kein Platz für weitere Spalten. Die Werte bleiben im Spiel, der Manager kennt sie nicht.
- **Gegenstandsmenü öffnet nach dem Loslassen** (Claude): Blizzards Menüs öffnen beim Klick und ersetzten Peons Menü, das schon beim Drücken aufging.

## 13.11.2026: Paketvergleich bei Kisten (Broker 0.87 und 0.88)

- **Kosten je Paket im Tooltip, das günstigste markiert** (KarloDerBaer): Für die Kiste muss man ein Paket abgeben, gesucht ist also das günstigste, nicht das wertvollste. Was in den Taschen liegt, kostet nichts.
- **Vergleich über den Namen** (Claude): Die Paketliste ist nur Text, ohne Gegenstandsnummern.
- **Auf die Einkaufsliste über das Peon-Menü statt per Rechtsklick** (KarloDerBaer, Vorschlag Claude): Ein einfacher Rechtsklick benutzt die Kiste, das kann Broker nicht verhindern. Ziel ist die Liste „Handelsauftrag“.

## 13.11.2026: Angleichung des Managers, Teil 1 (Konzept `Peon_Manager_Angleichung.md`, freigegeben)

- **Teil 1 freigegeben**, Bau ab A1 (KarloDerBaer).
- **Umstellung vereinfacht** (Claude, beim Bau von A1): Der frühere gemischte Stand geht ganz an das erste Konto mit Kennung statt aufgeteilt mit einer Liste „nicht zugeordnet“. Der alte Abgleich hat alle Konten gemischt, die Einträge stehen also ohnehin schon in jedem gespielten Konto. So geht nichts verloren und das Konto zeigt, was der Manager vorher zeigte.
- **Kennung in zwei Ordnern** (Claude): Abgeglichen wird nur der zuletzt gespeicherte Ordner, die Datenlage zeigt einen Hinweis.

- **Der Manager übernimmt, was das Spiel nicht kann** (KarloDerBaer, Vorschlag Claude): stündliche Daten, Meldungen über Windows, Vorarbeit für Broker. Das Radar wird nicht nachgebaut, weil es im Spiel mit Live-Daten arbeitet.
- **Reihenfolge** (KarloDerBaer): erst Einkaufslisten und Beobachten, dann Chancen im Manager, dann Daten für Broker.
- **Abgleich je Wert statt je Eintrag** (KarloDerBaer): Änderungen an verschiedenen Werten gehen nicht mehr still verloren.
- **Protokoll des Abgleichs nur im Manager** (KarloDerBaer).
- **Gelöschtes 30 Tage wiederherstellbar, Löschmarken ein Jahr** (KarloDerBaer): Ein lange nicht gespielter Kontoordner bringt sonst alte Einträge zurück.
- **Kein Abgleich über WoW-Konten hinweg** (KarloDerBaer): Die Listen sind in den Addons accountweit. Broker bekommt dafür eine Kennung des Kontos, weil das Spiel den Namen des Kontoordners nicht kennt (Claude).
- **Meldungen über Windows für Beobachten, einstellbar je Gegenstand und je Grenze** (KarloDerBaer). Bei neuen Einträgen sind beide Glocken aus (KarloDerBaer).
- **Kein Kopieren von Einträgen zwischen Konten**, auch nicht auf Knopfdruck (KarloDerBaer).

## 12.11.2026: Begriffe, Diagramm, Info (Ledger 0.14.4 und 0.14.5)

- **Begriffe** (KarloDerBaer): Vermögen = Gold + Marktwert. „Marktwert“ ist der heutige Wert, „Lagerkosten“ (statt Lagerwert) das, was die Waren gekostet haben. Alle Begriffe stehen im Reiter Info.
- **Startbestand kostet 0** (KarloDerBaer): Er zählt ohnehin nicht zum Gewinn. Ändert 0.14.3 (Marktwert beim Neustart) und `Peon_Ledger_Zuordnen.md` (Anfangsbestand zum Marktpreis).
- **Offener Gewinn nur im Bestand** (KarloDerBaer), ohne Startbestand.
- **Vermögen je Charakter in der Übersicht**, Kachel „Vermögen gesamt“ (KarloDerBaer).
- **Diagramm in der Übersicht** mit Gold, Vermögen und Handelsgewinn (KarloDerBaer). Gold und Vermögen lassen sich nicht aus dem Verlauf nachrechnen, deshalb merkt Ledger sie ab 0.14.5 bei Ereignissen (Claude), ohne regelmäßigen Takt.
- **Abweichungen im Reiter Info aufgeschlüsselt** (KarloDerBaer).

## 12.11.2026: Startbestand und Reihenfolge der Kosten (Ledger 0.14.3)

- **Startbestand als Sondereinnahme (Variante C, KarloDerBaer):** Was beim Neustart des Buchs da war, behält zur Information den Marktwert, sein Verkauf zählt aber nicht als Handelsgewinn. Kosten 0 hätte jeden alten Verkauf als vollen Gewinn gezeigt, Marktwert allein zeigte falsche Verluste.
- **Reihenfolge einstellbar, Standard „neueste zuerst“** (KarloDerBaer, Vorschlag Claude): Ändert „älteste zuerst“ vom 03.10.2026 (`Peon_Ledger_Zuordnen.md`). Beim Aufkaufen und teurer Einstellen zeigt „neueste zuerst“ den Gewinn sofort, der Startbestand bleibt unten liegen. „Zuletzt gezahlt“ bleibt eine eigene Anzeige.

## 12.11.2026: Sondereinnahme, Bestand, Tooltip (Ledger 0.14.2)

- **Auktionen von vor dem Neustart sind eine Sondereinnahme** (KarloDerBaer): Ledger kennt ihr Einstellen nicht. Ihr Erlös zählt wie eine Bestandsaufnahme und nicht als Handelsgewinn. Ebenso jeder Erlös, der keinem Gegenstand zuzuordnen ist.
- **Buch noch einmal von 0, ohne WoW zu beenden** (KarloDerBaer): Das Zurückspielen der alten Daten entfällt. Die gesicherte Datei bleibt im Archiv.
- **Angelegte Ausrüstung zählt zum Lagerwert** (KarloDerBaer): Sie lässt sich beim Händler verkaufen.
- **Tooltip wie Broker einstellbar, Standard Bestand statt Kosten** (KarloDerBaer). Was im Bestand steht und was nur mit Umschalt, ist je Baustein wählbar.

## 12.11.2026: Nach dem ersten Test (Ledger 0.14.1)

- **Übersicht ohne Post** (KarloDerBaer): Das Spiel nennt Briefe nur am offenen Briefkasten, für Twinks gar nicht. Die Zahl war meist veraltet.
- **Neustart des Buchs behält die Kosten** (Claude, nach dem falschen Verlust im Postfenster): Bisher galt der ganze Bestand als zum heutigen Marktpreis gekauft. Jetzt bleiben die Posten aus dem bisherigen Verlauf, nur Fehlendes kommt zum Marktwert dazu. Ändert die Regel „Anfangsbestand zum Marktpreis“ aus `Peon_Ledger_Zuordnen.md` für diesen Fall.
- **Verkaufspreis aus dem Gold im Brief** (Claude): Forever schreibt bei Massenware die Menge ins Feld Sofortkauf der Rechnung.
- **Briefe lesen im Postfenster** (Wunsch KarloDerBaer): Klick liest Textbriefe, Rechtsklick jeden Brief, mit Antworten und Löschen.

## 12.11.2026: Umsetzung Neuaufbau Ledger (Ledger 0.14.0, Broker 0.84.0)

- **Alles in einem Schritt gebaut** (KarloDerBaer: „Baue bitte gleich alles“), die Woche Probelauf nach E1 entfällt. Die Kontrollrechnung zeigt die restlichen Lücken im Alltag.
- **Abweichungen werden beim Einloggen verbucht**, nicht laufend (Claude): Direkt nach einer Bewegung (Bank offen, Brief unterwegs) gäbe es falsche Abweichungen. Das Fenster zeigt offene Abweichungen jederzeit.
- **Postfenster über einen winzigen Rahmen** wie Peon_Bags mit der Bank (Claude): Blizzards `MailMixin:OnHide` ruft `CloseMail`, nachgelesen im Zweig forever. Rechtsklick in der Tasche auf der Seite Senden über `SetSendMailShowing(true)`, ohne Blizzards Reiter anzufassen.
- **Ein eigener Rahmen je Modul statt Kern-Baustein** (Claude): Der Rahmen für Blizzards Fenster im Hintergrund steht vorerst in Bags und Ledger je einmal. Ein gemeinsamer Baustein im Kern bleibt als offener Punkt.
- **Tastenbelegung „Gegenstand unter der Maus“ bleibt** und führt zu Brokers Seite Gegenstand, Alt+Klick entfällt wie entschieden (Claude).

## 12.11.2026: Neuaufbau von Ledger (Konzept `Peon_Ledger_Neuaufbau.md`)

- **Erst die Erfassung, dann die Anzeige** (KarloDerBaer, Vorschlag Claude). Die Prüfung der echten Daten einer Woche zeigte echte Lücken: Gold geht um rund 9,9g nicht auf, Verkäufe im Auktionshaus werden meist nur als Gold erfasst, Käufe finden ihre Ware oft nicht (Briefe noch nicht geladen).
- **Kontrollrechnung:** Ledger rechnet Gold und Bestand selbst nach und zeigt Abweichungen (Claude). Grund: Der Spieler soll nie selbst nachrechnen müssen.
- **Auktionshaus und Post an der Quelle erfassen:** Kauf beim Bestätigen, Verkauf aus der Rechnung, Briefe erst nach dem Laden, Post zählt zum Bestand (Claude).
- **Zuletzt gezahlt und zuletzt verkauft** zusätzlich zu den Kosten nach „älteste zuerst“, alle Käufe mit Quelle (KarloDerBaer).
- **Buch wird nach dem Umbau der Erfassung zurückgesetzt** (KarloDerBaer), weil die alten Zeilen die Lücken enthalten.
- **Vier Seiten** mit `Peon.UI`: Übersicht (Kachel Handelsgewinn heute), Bestand, Buch (Umsatz wird „Nach Gegenstand“, Beute und Quests nur „Nach Art“), Verlauf. Reiter Gegenstände und Gegenstand entfallen, Gegenstand zeigt Broker (KarloDerBaer).
- **Eigenes Postfenster „Peon Post“** mit Blizzards Postfach im Hintergrund, Eingang und eigene Seite Senden (KarloDerBaer). Klick auf einen Brief nimmt ihn, Knöpfe „Auktionshaus-Post einsammeln“ und „Alles einsammeln“, nie Nachnahme. Ändert die Entscheidung vom 03.10.2026 (kein eigener Einsammel-Knopf).
- **Art einer Bewegung von Hand ändern:** später, erst nach der neuen Erfassung (KarloDerBaer).

## 12.11.2026: Text des Release ohne Entwickler-Verlauf

- **Tabelle** mit Addon/Modul, Version alt, Version neu und Anmerkung, dazu eine Zeile für den Peon Manager. „Version alt“ ist der Stand des letzten normalen Release. Unveränderte Teile stehen mit „unverändert“ drin.
- **Darunter je geändertem Teil eine kurze Liste** mit `Neu`, `Geändert`, `Behoben`, `Entfernt`, für Nutzer geschrieben und über alle Versionen seit dem letzten Release zusammengefasst. Kein Verlauf aus den Changelogs mehr, keine Hinweise auf Personen, Orte oder Wünsche.
- **Auch im Manager:** Update-Fenster und „Was ist neu“ zeigen dieselben Angaben aus dem Manifest (ab Manager 0.27.0). Für übersprungene Releases bleiben die kurzen Texte darunter.
- **Quelle:** eine Datei je Release in `docs/releases/`, von Claude aus den Changelogs zusammengefasst und von KarloDerBaer gegengelesen. Grund: Bei vielen Versionen seit dem letzten Release (Broker 0.40 bis 0.81) wären automatisch gesammelte Zeilen lang und doppelt.

## 12.11.2026: Einmalige Hinweise im Kern (Peon 0.20.0, API 20)

- **Module melden ihre Hinweise selbst** (`mod:AddNotice`), der Kern sammelt und zeigt sie. Grund: Ein Hinweis kommt und geht mit dem Update des Moduls, der Kern muss dafür nicht mit ausgeliefert werden.
- **Einmal je Konto, für alle**, auch bei neuer Installation. Gesehen gilt, sobald das Fenster offen war. Grund: Twinks sollen nicht jedes Mal dasselbe zeigen, neue Nutzer brauchen die Hinweise genauso.
- `/peon neu` zeigt alle Hinweise wieder.

## 12.11.2026: Beobachten als eigener Reiter (Broker 0.82.0)

- **Beobachten eigener Reiter, nicht mehr in Einkaufen** (KarloDerBaer). Ändert den Neuaufbau (4.3: Beobachtung als besondere Liste). Spalten passend zu Beobachtung und Fokus, nicht die der Einkaufsliste.
- **Zielpreis = Grenze nach oben** (KarloDerBaer): Der Zielpreis ist der Preis, ab dem man verkaufen würde, die Meldung kommt, wenn der Preis darüber liegt. „Verkaufen ab“ entfällt. Kaufen bis bleibt die Grenze nach unten.
- **Fokus öffnet mit den gespeicherten Werten, Art „Beobachten“** (KarloDerBaer), außer er kommt aus dem Radar (Claude).
- **Zurück im Fokus unten** zu Radar oder Beobachten, ohne Radar immer Beobachten (KarloDerBaer). Der Knopf in der Titelleiste entfällt dort (Claude, damit es nicht zwei gibt).
- **Gegenstand unter Mehr** (KarloDerBaer), damit die Reiterleiste nicht zu breit wird.
- **Zahl am Reiter als roter Kreis** wie im UI-Design (KarloDerBaer).

## 12.11.2026: Stand vom Manager auch für Neutral (Broker 0.80.0)

- **Beim Anmelden Heimat und Neutral übernehmen** (KarloDerBaer): Die aktuellen Preise des neutralen Markts aus der Blizzard-API kamen sonst nie an. Der neutrale Markt entsteht nur mit Werten des Managers (Claude).

## 12.11.2026: Aufkauf nur im üblichen Bereich (Broker 0.79.0)

Ändert die Regel vom 11.11.2026 „Der übliche Bereich filtert nicht“ (Vorschlag Claude, KarloDerBaer einverstanden):

- **Kaufen bis nie über der oberen Grenze des üblichen Bereichs.**
- **Ziel höchstens 20 % über dieser Grenze**, einstellbar. Grund: Einzelne überteuerte Angebote stellen weder den üblichen noch den aktuellen Preis dar.
- **Ohne üblichen Bereich kein Aufkauf.** Ohne Verlauf lässt sich nicht sagen, ob ein Preis überteuert ist.
- **Eigene Werte im Fokus ohne diese Grenzen.**

## 12.11.2026: Fokus neu geordnet (Broker 0.77.0)

- **Aufbau links nach Vorgabe von KarloDerBaer**, Risiko nach „Verkauft in“.
- **Felder zeigen immer die geltenden Werte** (Vorschlag Claude, bestätigt): auch bei einer Chance aus dem Radar, ändern macht daraus ein eigenes Ziel, „Auto“ holt die Werte der Chance zurück.
- **Gekaufte Stufen blau, Ziel gelb, kein grüner Preistext mehr** (KarloDerBaer, Vorschlag Claude bestätigt).

## 12.11.2026: Fokus mit Kaufen bis (Broker 0.76.0)

- **Kaufen bis per Rechtsklick, Ziel per Linksklick** (KarloDerBaer): Man kann ein höheres Ziel wählen, ohne alles darunter zu kaufen. „Auto“ setzt beides zurück (Claude).
- **Kosten und Gewinn über dem Kaufknopf** (KarloDerBaer).

## 12.11.2026: Nachbesserungen nach dem dritten Test (Broker 0.75.0)

- **Knopf „Angebote“ entfällt** (KarloDerBaer): Der zweite Klick auf die Zeile in Blizzards Liste reicht.
- **Weggefallene Chancen behalten den Gewinn** (KarloDerBaer): „weg“ unter Art, damit man sie noch beobachten kann.

## 12.11.2026: Nachbesserungen nach dem zweiten Test (Broker 0.74.0, Bridge 0.9.2, Peon 0.19.0)

- **Brokers Flächen über Blizzards Ansichten nur ohne offenen Broker-Reiter** (Claude, Rückmeldung KarloDerBaer): Die Liste der Auktionen liegt wie Brokers eigene Reiter über dem ganzen Inhalt.
- **Einstellungen im großen Fenster mit OK und Abbrechen** (KarloDerBaer).
- **Kein „Jetzt prüfen“ im Fokus** (KarloDerBaer).
- **Abfluss bei Massenware über die Preisstufen** (Claude): Die Auktionsnummern der Massenware wechseln offenbar zwischen zwei Abfragen. Kauf und neues Angebot auf derselben Stufe im selben Abstand heben sich auf, bei wenigen Sekunden Abstand selten.
- **Keine Abfragen während eines Kaufs** (Claude, Vermutung zu „Interner Auktionsfehler“): erkannt über die Ereignisse des Spiels, ohne Blizzards Funktionen anzufassen. Die Meldungen werden gemerkt, um die Vermutung im Spiel zu prüfen.
- **Knopf „An Manager“ entfällt** (KarloDerBaer): Übergeben unter Mehr, Datenlage reicht.
- **Kern-API 19: Zeilenfarbe in `UI.Table`** (Claude, für die gelbe Zielstufe): nur eine neue Option, nichts geändert.

## 12.11.2026: Nachbesserungen nach dem ersten Test von Stufe 2 (Broker 0.69.0 bis 0.73.0)

Anmerkungen von KarloDerBaer nach dem ersten Blick ins Spiel, abgestimmt im Gespräch am 12.11.2026.

- **Fokus nur am Auktionshaus und nur live** (KarloDerBaer): Unterwegs ist der Reiter grau wie Verkaufen, die Preisstufen kommen nur aus Live-Abfragen dieses Besuchs. „In den Fokus“ unterwegs merkt den Gegenstand für den nächsten Besuch (Claude).
- **Kaufen im Fokus immer möglich** (KarloDerBaer): eigenes Ziel von Hand oder per Klick auf eine Preisstufe, gekauft wird alles unter dem Ziel. Ohne Chance gilt die zweite Preisstufe als Ziel (wie bisher in der Messung). Kaufen geht auch ohne Gewinn, nur nicht ohne Menge oder Gold. Der Kauf wird ein Posten wie ein Aufkauf (Claude).
- **Ein neues Ziel beginnt die Messung neu** (Claude): „Menge unter Ziel“ und „Zufluss unter Ziel“ gelten für ein bestimmtes Ziel, alte Werte würden sonst ein falsches Urteil geben.
- **Abfragen pro Minute statt Sekunden** (KarloDerBaer): 2 bis 90, Vorgabe 12 (alle 5 Sek.). 90 ist die Grenze, die das Spiel ungefähr annimmt. Ob das im Spiel geht, zeigt erst der Test.
- **Grenzen des Urteils einstellbar** (KarloDerBaer: „alle relevanten Einstellungen“): Fenster der Messung, erstes und sicheres Urteil, Vorsprung des Abflusses, Wachstum der Menge, Warnung beim Kauf. Startwerte wie am 12.11.2026 festgelegt.
- **Erste Abfrage im Fokus ist eine Suche** (Claude, Fehler bei der Flitzdistel): „Neu laden“ schickt das Spiel nur ab, wenn es schon Ergebnisse für den Gegenstand hat. Bleibt eine Antwort aus, wechselt Broker zwischen Suche und Neu laden.
- **Absatz und Trend je Gegenstand 5 Minuten gemerkt** (Claude, Bildrate): Vorher rechnete jede Antwort im Fokus den ganzen Verlauf neu. Ob das Diagramm bleibt, entscheidet die Zeitmessung `/broker pruefen zeit` im Spiel.
- **Unterbotene abbrechen unten neben Blizzards „Auktionsabbruch“** (Claude, auf die Frage von KarloDerBaer).
- **Aufkauf nur für Massenware** (KarloDerBaer, Startwerte vorgeschlagen von Claude und bestätigt): mindestens 200 Stück im Angebot, 5 Preisstufen, 50 Stück Absatz am Tag, alles einstellbar. Einzelnes und wenig Angebotenes gehört später zur Art Spekulation.
- **Radar-Scan wieder als Suche** (KarloDerBaer): Beobachten, Massenware oder Alles, zufällige Reihenfolge, bis zu etwa 92 Abfragen je Minute, solange der Radar offen und der Scan an ist. Das ändert die Auslegung vom 11.11.2026 („prüft nur die gezeigten Chancen“).
- **Erneuern vor Suchen** (KarloDerBaer): Gezeigte Möglichkeiten werden zuerst erneuert (Vorgabe jede Minute). Reicht das Budget nicht, wird der Abstand bis 2 Minuten länger. Der Radar-Scan behält immer mindestens 20 % (Claude, damit eine lange Liste ihn nicht ganz verdrängt).
- **Eigene Liste der Auktionen über Blizzards Ansicht** (KarloDerBaer wählte Weg A): Spalte Broker als echte Spalte und Filter gingen in Blizzards Liste nur mit Eingriffen in Blizzards Tabelle (Taint). Blizzards Ansicht bleibt im Hintergrund offen, Gebote zeigt weiter Blizzard (Claude: vorerst keine eigenen Gebote).
- **Abgebrochene Auktion ohne fremdes Angebot behält ihren Preis als Ziel** (Claude): Ohne günstigeres Angebot gibt es keinen besseren Vorschlag.
- **Im Markt zeigen über sichere Knöpfe** (KarloDerBaer: „direkt auf den Markt springen“): Ein sicherer Knopf klickt Blizzards Reiter Markt oder die Zeile des Gegenstands an. Das ist der einzige saubere Weg, weil von Broker geschriebene Werte in Blizzards Fenster auch nach dem Schließen des Auktionshauses berührt bleiben (Schriftrolle beim Questen, Fehlerbericht 10). „Nur am Auktionshaus erlauben“ hilft deshalb nicht (Claude, nachgelesen in `ContainerFrame.lua` und `Blizzard_AuctionHouseFrame.lua`, Zweig forever). Ob das Spiel den Weg als sauber wertet, zeigt erst der Test.
- **Zum Einstellen unter Verkaufen mit sicherem Knopf** (KarloDerBaer zu Ort, Claude zum Weg): Ein sicherer Knopf klickt per Makro den Taschenplatz rechts an. So legt Blizzards eigener Code den Gegenstand hinein, ohne dass Broker Blizzards Werte berührt. Das löst die Abweichung „Kein Hineinlegen per Klick“ vom 12.11.2026 auf, wenn der Test im Spiel sauber ist.

## 12.11.2026: Stufe 2 des Neuaufbaus, Startwerte (Broker 0.65.0 bis 0.68.0)

Grenzwerte, die das Konzept offen lässt, mit Startwert von Claude. Mit echten Daten nachzuschärfen, KarloDerBaer prüft im Spiel.

- **Aufkauf nur mit Absatzdaten** (H1): Ohne gemessenen Absatz lässt sich die Verkaufsdauer nicht schätzen, darum gibt es dann keinen Aufkauf. Wenig Absatzdaten (Sicherheit rot) zählen nur als Risiko.
- **Aufkauf nur für Massenware** (H1): Nur dort gibt es Preisstufen, bei denen die zuletzt eingestellte Ware zuerst verkauft wird.
- **Mindestgewinn Aufkauf = bisheriger Mindestgewinn Markt** (`dealMinMarket`, 50s), damit keine Einstellung doppelt ist.
- **Risiko-Ampel** (H1): je ein Punkt für Verkaufsdauer über 75 % der Grenze, Ware bis 5 % über dem Ziel mehr als der Absatz in der Höchstdauer, nächste Stufe unter 5 Stück oder unter 10 % der eigenen Menge, Einsatz über der Hälfte des verfügbaren Golds, Stand älter als 30 Min. (über 2 Std. zwei Punkte), wenig Absatzdaten oder kein üblicher Bereich. Grün 0, gelb 1 bis 2, rot ab 3. Grund: Jeder Punkt ist ein eigener Weg, wie der Aufkauf scheitern kann. Ein einzelner macht ihn unsicher, drei zusammen machen ihn riskant.
- **Urteil im Fokus** (H2): Fenster der letzten 10 Minuten. „Finger weg“ ab 10 % mehr Menge unter dem Ziel (mindestens 1 Stück) oder bei jedem fallenden günstigsten Preis. „Kaufen“ erst, wenn der Abfluss mehr als 20 % über dem Zufluss unter dem Ziel liegt, darunter gilt „etwa gleich“. Grund: Bei wenigen Sekunden Abstand schwanken die Zahlen stark, ein kleiner Vorsprung ist noch keine Richtung.
- **Ziel ohne Chance** (H2): die zweite Preisstufe beim Beginn der Messung, damit „Menge unter Ziel“ auch bei einem selbst gewählten Gegenstand etwas zeigt.
- **Eigene Käufe zählen als Abfluss** (H2): Die Auktionsnummern verraten nicht, wer gekauft hat. Das ist richtig für die Frage „wird hier gekauft?“, nach einem eigenen Aufkauf wirkt der Markt kurz lebhafter.
- **Warnung beim Kauf ab 1 % über dem erwarteten Gesamtpreis** (H2). Der Kauf bricht weiter von selbst ab, wenn der Stückpreis über „Kaufen bis“ liegt.
- **Posten je Charakter** (H3): Die Ware kommt in Post und Tasche dieses Charakters. Händler-Käufe werden keine Posten.
- **Kein Hineinlegen per Klick** (H3, Abweichung vom Konzept 6.2): `SetPostItem` aus Broker würde Blizzards Wert `displayMode` berühren wie in Fehlerbericht 10 und 11. Hineinlegen bleibt der Rechtsklick in der Tasche, die Liste sagt das. **Mit KarloDerBaer noch abzustimmen.**
- **Prüfung „Zielpreis eintragen“** (H3): Eine blockierte Aktion von Broker bis 60 Sekunden nach dem Klick gilt als Folge. Dann bietet Broker den Knopf nicht mehr an (Konzept: „Blockiert es, bleibt der Preis nur im Rat stehen“). Zurücksetzen geht, indem man den Wert `targetBlocked` in der Einstellungsdatei löscht.
- **Neuer Preis nach dem Abbrechen** (H3): günstigstes fremdes Angebot minus Unterbieten wie beim Verkaufen. Der Einsatz bleibt leer, weil die ursprünglichen Kosten nicht bekannt sind.
- **Eingestellte Posten bleiben 2 Tage**, damit der Fokus sie bewachen kann, danach räumt Broker sie beim Anmelden weg.
- **Material auf eine feste Liste „Material“** (H4): Eine feste Liste ist vorhersehbar und vermischt nichts mit eigenen Listen. Die Anzahl der Herstellungen wählt ein kleines Menü (1, 5, 10, 20) statt eines Eingabefelds, damit im Block unter den Reagenzien kein Platz verloren geht.
- **Händler-Warnung nur bei Massenware** (H4): Sie sitzt unter Brokers Zeile zum Weiterverkauf, die es nur in Blizzards Kaufansicht für Massenware gibt. Händler führen fast nur Massenware.
- **Manager angeglichen** (H5): Namen und Reihenfolge der Seiten wie im Spiel. Der Aufkauf kommt als erster Reiter ins Radar, mit derselben Rechnung wie im Spiel, ohne Goldgrenze. Die übrigen Reiter (Wiederverkauf, Fallend, Steigend, Lohnend) bleiben, weil nichts ohne Zustimmung wegfällt. Beobachtung bleibt eine eigene Seite direkt unter Einkaufen, statt in die Seite Einkaufen zu wandern (die noch WIP ist).
- **Optionen aufgeräumt** (H1, Streichliste Abschnitt 7): Regler der früheren Art „unter dem üblichen Preis“ sind nicht mehr auf der Seite, die Werte bleiben gespeichert. Die Altersgrenze für Chancen aus der Datenbank (`radarMaxAge`) bleibt, weil sie die Liste kurz hält.

## 12.11.2026: Broker schaltet Blizzards Auktionshaus nicht mehr um (Broker 0.64.1)

- **„Im Markt zeigen“ sucht nur noch** (Claude, wegen der Fehlerberichte 10 und 11): Broker ruft `SelectBrowseResult` und `SetDisplayMode` nicht mehr auf, weil das Blizzards Wert `displayMode` berührt und danach das Benutzen von Gegenständen aus der Tasche blockiert. Der Name kommt ins Suchfeld, Blizzards Liste zeigt den Gegenstand, ein Klick auf die Zeile zeigt die Angebote. Das ist ein Klick mehr als im Konzept (Abschnitt 5: „Kaufansicht mit genau diesem Gegenstand“). Ohne Berührung von Blizzards Werten geht es nicht anders, weil nur ein Klick des Spielers auf Blizzards Zeile die Ansicht sauber umschaltet. **Mit KarloDerBaer noch abzustimmen.**
- **Favoriten-Stern nur unsichtbar** statt eigener Schicht für Brokers Fläche (Claude): Eine Fläche in Blizzards Schicht HIGH läge über dem runden Bild und dem Rahmen (wie bis 0.59.0).

## 11.11.2026: Neuaufbau Peon_Broker (Konzept `Peon_Broker_Neuaufbau.md`, freigegeben)

- **Ein Fenster in zwei Zuständen** (KarloDerBaer, Vorschlag Claude): Brokers Seiten als Reiter in Blizzards Auktionshaus, unterwegs ein Broker-Fenster mit derselben Reiterleiste. Ein ganz eigenes Fenster wurde verworfen, weil Kaufen, Verkaufen und Auktionen nachgebaut werden müssten und eigenes Einstellen in Forever nie erprobt ist.
- **Reiter:** Markt, Verkaufen, Auktionen, Einkaufen, Radar, Fokus, Gegenstand, Mehr (KarloDerBaer). Das ersetzt die Reihenfolge aus Broker 0.54. Händler, Marktvergleich und Quellen sind Unterpunkte von Mehr, Beobachtung ist eine besondere Einkaufsliste, der Gegenstand hat eine eigene Seite mit Diagramm (KarloDerBaer).
- **Radar nur noch mit Aufkauf und Händler** (KarloDerBaer): Die Art „unter dem üblichen Preis“ entfällt, weil die Preise kurz nach dem Start noch falsch eingeschätzt werden. Aufkauf bildet das Vorgehen von KarloDerBaer ab: Massenware bis zu einer Preisstufe aufkaufen und zum Preis der nächsten Stufe einstellen.
- **Aufkauf ohne Mindestsprung in Prozent** (KarloDerBaer): Es zählen Aufkaufbarkeit, Gewinn in Gold gegen das Risiko, schneller Wiederverkauf (Vorgabe 2 Std.) und kein anhaltender Trend nach unten. Der übliche Bereich filtert nicht (Claude).
- **Radar schlank, Fokus als eigener Reiter** (KarloDerBaer): Die Liste zeigt nur Gegenstand, Gewinn, Art, Risiko und Stand. Ein Klick öffnet den Fokus. Der Fokus zeigt und misst immer genau einen Gegenstand in kurzem Abstand, weil sich der Markt für Massenware sehr schnell ändert. Der Radar-Scan prüft nur die gezeigten Chancen und sucht keine neuen (Auslegung Claude).
- **Zielpreis eintragen per Knopf** bei Posten aus dem Radar (KarloDerBaer: ja, wenn es sinnvoll ist). Das lockert „Broker trägt keinen Preis ein“ vom 09.11.2026 für diesen Fall, nach einer Prüfung auf Blockaden (Claude).
- **Neu einstellen über eine Liste „Zum Einstellen“** (Claude, auf die Frage von KarloDerBaer): Gekauftes und Abgebrochenes kommt per Post, darum merkt Broker Posten mit Zielpreis statt eines Ablaufs in einem Zug.
- **Reihenfolge:** erst die Grundfunktionen N1 bis N6, dann die Hilfen H1 bis H5, der Manager zuletzt. Kandidaten vom Manager, Erfolgskontrolle und „Alles Lohnende kaufen“ sind für später vorgemerkt (KarloDerBaer).

## 11.11.2026: Einheitliches UI-Design, erst prüfen (Peon 0.18.0)

- **Ein Look für alle Peon-Fenster nach Blizzards modernem Auktionshaus** (KarloDerBaer). Zuerst Bestandsaufnahme, dann Vorschlag, Beispielfenster im Kern, Abstimmung Schritt für Schritt, danach Regeln in `docs\konzepte\Peon_UI_Design.md` und Bausteine als Erweiterung der Kern-API. Bestehende Fenster bleiben vorerst.
- **Grafiken nicht raten, sondern im Spiel auslesen** (KarloDerBaer): In Broker 0.56 bis 0.58 passte der Look dreimal nicht. Ursache laut Blizzards Code: Forever hat unter denselben Atlas-Namen eigene Grafiken, und das Auktionshaus zeigt seine Hintergründe in Originalgröße statt gestreckt. Dafür der Prüfbefehl `/peon ui pruefen`, der nur liest (Claude).
- **Antworten von KarloDerBaer zum Look:** rundes Bild mit dem Symbol des Moduls, Hintergründe gemischt wie im Auktionshaus, Haken mit gelbem Häkchen, Gold-Knopf für die wichtigste Aktion, feste Fenstergröße, eigene runde Zahl am Reiter, vier Beispielseiten, zusätzliche Bausteine (Gegenstand, Geld, Rückfrage, Kontextmenü, Fortschritt, Trennlinie, Einklappen).
- **Freigabe** (KarloDerBaer, nach dem dritten Test): Der Look passt, die Bausteine kommen als `Peon.UI` in die Kern-API 18. Neue Peon-Fenster nutzen sie, zuerst Broker.
- **Nach dem dritten Test** (KarloDerBaer): Hinter der Bildlaufleiste der Kategorien fehlte das hellere Grau des Fensters, Blizzards Bild endet vor der Leiste (Messung mit `/peon ui pruefen maus`).
- **Nach dem zweiten Test** (KarloDerBaer): moderner Schieberegler, Fortschritt wie der Balken beim Herstellen, Kategorien auf- und zuklappbar wie im Auktionshaus. Der Rest passt.
- **Hintergründe passen sich dem Bereich an** (Claude, nach dem ersten Test): abschneiden, wenn der Bereich kleiner ist, dehnen, wenn er größer ist.
- **Bausteine zuerst intern** (`ns.UI` in `UIKit.lua`), erst nach der Freigabe als Kern-API (Claude): So bleibt die API stabil, solange sich der Look noch ändert.
- **Listen mit Blizzards ScrollBox und MinimalScrollBar** statt des eigenen Bildlaufs von `Peon.NewList` (Claude): nur so sehen Leiste und Bildlauf genau wie im Auktionshaus aus. `Peon.NewList` bleibt unverändert.
- **Rückfrage als eigenes Fenster** statt eines Eintrags in `StaticPopupDialogs` (Claude), weil Einträge in Blizzards Tabellen erst abgestimmt werden.
- **Peon passt Blizzards Fenster nur sichtbar und von außen an** (KarloDerBaer): eigene Rahmen und Texte, Anker und Beschriftungen, sichere Anhänge mit `hooksecurefunc` und `HookScript`. Werte oder Funktionen in Blizzards Tabellen nur nach Abstimmung und Prüfung auf Taint.

## 09.11.2026: Umbau Peon_Broker (Konzept `Peon_Broker_Umbau.md`, Broker 0.41.0)

- **Broker wird schlank und berät** (KarloDerBaer): Verkauft wird über Blizzards Fenster, ausgewählt in der Tasche. Broker trägt keinen Preis ein, sondern sagt, ob man zu Blizzards Preis verkaufen soll. Grund: KarloDerBaer nutzt Brokers Reiter Verkaufen kaum.
- **Aufteilung** (KarloDerBaer): Im Auktionshaus Verkaufen, Auktionen, Radar und Einkaufen. Im Broker-Fenster nur, was ohne Auktionshaus geht (Einkaufslisten, Markt, Händler, Gegenstände, Beobachtung, Quellen), aussehen wie das Auktionshaus, Inhalt wie der Manager.
- **Heimatmarkt zuerst** (KarloDerBaer): Tooltip und Werte zeigen immer die eigene Fraktion. Das neutrale Haus kommt als einstellbare Zeile dazu (Ursache der „falschen Preise“ war die Regel aus 0.40.0, dass bei offenem neutralen Haus überall Neutral gilt).
- **Behalten entfällt** (KarloDerBaer), weil nicht mehr halb automatisch verkauft wird. Damit entfällt auch Bags B4.
- **Kontextmenü auf Gegenständen im Kern** mit Strg+Rechtsklick, änderbar (KarloDerBaer). Umschalt+Rechtsklick ist bei Blizzard belegt (Stapel teilen, mehrere Stapel kaufen), nachgelesen im Code der Forever-Version (Claude). Ledgers Alt+Klick entfällt später.
- **Favoriten heißen Beobachtung**, mit Preisalarm und als eigene Liste im Reiter Einkaufen (KarloDerBaer).
- **Erst ein Prüfaufbau (U0)** (Claude, zugestimmt): Eigene Reiter im Auktionshaus sind das größte Risiko. Broker ruft dafür `SetDisplayMode` nie auf und fügt Blizzards Tabellen nichts hinzu, sondern legt eine eigene Fläche darüber. Dazu der Notausgang „Blizzard pur“ mit Neuladen (KarloDerBaer), weil sich Taint nur so löst.

## 09.11.2026: Manager rechnet im Hintergrund (Manager 0.23.0)

- **Modul Peon Broker Client im Arbeitsprozess** (KarloDerBaer, Vorschlag Claude): Das Fenster darf nie hängen. Die Werte erscheinen dafür ein paar Sekunden später.
- **Danach schneller rechnen** (KarloDerBaer): Nach einem neuen Stand nur das Neue verarbeiten statt den ganzen Verlauf.
- **Normales Release** `v2026.11.09.2` direkt ohne Vorabversion (KarloDerBaer).

## 09.11.2026: Neutrales Auktionshaus als eigener Markt (Broker 0.40.0)

- **Eigener Markt `<Realm> / Neutral`** (KarloDerBaer, schon im Konzept vorgesehen): Daten vom neutralen Haus dürfen sich nicht mit denen der eigenen Fraktion mischen.
- **Erkennung über den Auktionator** (Claude, im Spiel geprüft): Der Auktionator in Beutebucht hat keine Fraktion. Gilt nur, solange das Auktionshaus offen ist. Danach zeigen Tooltips wieder den Markt der eigenen Fraktion, weil man dort meistens handelt.
- **Normales Release** `v2026.11.09` direkt ohne Vorabversion, weil das Update wichtig ist (KarloDerBaer).

## 08.11.2026: Broker im Berufsfenster (Broker 0.39.0)

- **Block unter den Reagenzien statt Box daneben** (KarloDerBaer): Kosten, Vorrat und Gewinn stehen da, wo man beim Herstellen hinschaut. Die Box bleibt nur als Rückfall.
- **Gewinn in der Rezeptliste** (KarloDerBaer): ersetzt die Entscheidung vom 03.10.2026 „keine Spalte in der Rezeptliste“. Das beste Rezept bekommt einen goldenen Strich, eine eigene Zeile „Bestes Rezept“ gibt es nicht.
- **Vorrat als Gesamtmenge mit Tooltip** (KarloDerBaer): wo was liegt, steht im Tooltip. Twinks zählen nur mit Haken, gleiche Einstellung wie im Reiter Behalten.
- **Eigene Kosten aus Ledger** (KarloDerBaer): Vorhandene Stück zählen mit dem, was sie gekostet haben, fehlende mit dem AH-Preis (Vorschlag Claude). Umschaltbar auf „immer AH-Preis“.
- **Berufsfenster: Tabelle nach Quelle, ein Gewinn** (KarloDerBaer nach zwei Tests im Spiel, ersetzt die drei Rechnungen „Herstellen statt verkaufen“, „aus Vorrat“, „alles zu AH-Preisen“): Wer Material hat, kauft es nicht extra. Darum zeigt eine Tabelle je Material, woher es kommt (Vorrat, Händler oder AH), was es kostet (Vorrat laut Ledger) und was das Material aus dem Vorrat im AH bringen würde (Erlös). Darüber Kosten, Ertrag und Gewinn = Ertrag minus Kosten. Die Frage „lieber verkaufen?“ beantwortet ein Hinweis mit beiden Beträgen statt dem Abstand, in der Rezeptliste wird der Gewinn dann orange. Bei mehreren Materialien zählt das ganze Rezept.
- **Händlerpreise aus drei Quellen** (KarloDerBaer): Die Spiel-API nennt den Kaufpreis beim Händler nur bei offenem Händlerfenster. Broker merkt sich die Angebote bei jedem Besuch, nimmt sonst den letzten Kauf laut Ledger und schätzt für bekannte Händler-Reagenzien den Ankaufspreis × 4 (markiert, bis ein echter Preis bekannt ist). Die Quelle ist Händler oder AH, je nachdem was günstiger ist.
- **Tooltips zu jedem Wert** (KarloDerBaer): Material, Wert und Gewinn zeigen, wie sie sich ergeben, und die anderen Rechnungen zum Vergleich.
- **Alles einstellbar** (KarloDerBaer): Zahnrad direkt im Block und die gleichen Punkte auf der Optionsseite. Einstellungen gelten fürs ganze Konto.

## 08.11.2026: Chancen für Massenware (Manager 0.22.0)

- **Menge unter dem Ziel zählt** (KarloDerBaer): Liegt sehr viel Ware unter dem üblichen Bereich, ist das der Marktpreis. Man müsste den Markt leer kaufen, um den Preis zu bewegen. Grenze vorerst ein Tagesabsatz (Claude), später mit der Trefferquote prüfen.
- **Chancen zeigen nur den letzten Scan** (KarloDerBaer, Variante A): Die Tabelle zeigt, was jetzt eine Chance ist. Der Zeitraum bleibt als Zusatzinfo (wie oft, wann meistens). Eine eigene Ansicht für wiederkehrende Gelegenheiten gibt es vorerst nicht.
- **Bereich mit über 40 % Schwankung gilt als unsicher** (Claude): Nach mehreren Tagen Preisverfall wird die Schwankung so groß, dass der Bereich nichts mehr aussagt (Umhang des Hügelwächters: 10s bis 95s).
- **Neues Preisniveau schon nach 12 Std.** (Claude): 24 Std. waren bei einem schnellen Absturz zu träge.

## 08.11.2026: Bessere Vorschläge (Manager 0.21.0, Broker 0.38.0)

- **Fehler im Rechenweg jetzt beheben, Grenzwerte später einstellen** (KarloDerBaer): Der Markt schwankt nach dem Start stark. Fehler, die nicht vom Markt abhängen (Kürzung, veralteter Bereich, gleich tiefe Angebote), werden gleich behoben. Die Zahlen (Prozent, Tage) werden in 2 bis 4 Wochen mit der Trefferquote geprüft.
- **Kürzung nach unten erst ab 75 % unter der Mitte statt „Kürzung erst ab 7 Tagen“** (Claude): Nach oben bleibt die Kürzung, damit Mondpreise bei wenigen Tagen nichts verzerren. Nach unten schnitt sie echte Preisstürze ab.
- **Trefferquote mit dem Median der Angebote**, nicht mit dem günstigsten Angebot (Claude): Das günstigste Angebot wäre ja gekauft und steht danach noch im Scan.

## 07.11.2026: Release v2026.11.07.10

- **Hinweise zur Blizzard-API** im Manager: Link zum Entwicklerportal, Wartezeit bei neuen Zugängen, mindestens ein Haus unter Quellen (KarloDerBaer).
- **Normales Release** `v2026.11.07.10` direkt, Manager 0.20.1 und Tooltip 0.7.5 ohne eigene Vorabversion (KarloDerBaer).

## 07.11.2026: Bags-Anordnung, sichtbares Update, Release v2026.11.07.9

- **Bags: Einstellen mit Klassisch, Nach Art, Individuell**, automatische Kategorien wählbar, eigene Bereiche je Fenster abwählbar, einklappbar, Kategorie Neu (KarloDerBaer, Konzept `Peon_Bags_Anordnung.md`). Danach Abschnitte nebeneinander und Reihenfolge per Ziehen an der Überschrift (KarloDerBaer).
- **Selbst-Update sichtbar** über den Installer mit Fortschritt statt eines eigenen Fensters im Peon-Look (KarloDerBaer: Installer reicht).
- **Suche nach Updates alle 10 Minuten** mit Meldung von Windows, beides einstellbar, weil es gerade häufig Updates gibt (KarloDerBaer).
- **Normales Release** `v2026.11.07.9` direkt, Manager 0.20.0 ohne eigene Vorabversion (KarloDerBaer).

## 07.11.2026: Normales Release, Reiter in Arbeit mit WIP, neuer Standard im Panel

- **Normales Release** `v2026.11.07.6`, direkt ohne eigene Vorabversion für die letzten Änderungen (KarloDerBaer).
- **Einkaufsliste (Broker, Manager), Gegenstände und Gegenstand (Ledger) zeigen „WIP“,** weil sie überarbeitet werden (KarloDerBaer). Im Spiel zeigt der Reiter nur den Hinweis, der Code bleibt und wird weiter getestet. Im Manager bleibt die Seite nutzbar, nur der Reiter ist markiert (Claude, nach dem Wortlaut des Wunsches).
- **Einstellung von KarloDerBaer als Standard im Panel** (KarloDerBaer). Sie gilt nur für neue Einstellungen und neue Einträge, bestehende bleiben (Claude). Die Stelle des Panels wird nicht übernommen, weil sie von der Bildschirmgröße abhängt. Ohne eigene Stelle steht es oben links unter der Leiste (Claude).

## 07.11.2026: Panel und Leiste getrennt, aufklappbar, zweizeilig (Peon_Panel 0.3.0)

- Text, Anzeige und Beschriftung gelten je Anzeige. Bestehende Einstellungen übernimmt das Panel einmal von der Leiste (Claude).
- **Zweite Zeile: Zeile je Eintrag** statt automatischem Umbruch (KarloDerBaer, Vorschlag Claude).
- **Panel aufklappbar: der erste Eintrag bleibt sichtbar** (KarloDerBaer, Vorschlag Claude). Aufgeklappt stehen die Einträge in einer Reihe oder Spalte in der gewählten Richtung, die Spaltenzahl gilt dann nicht (Claude).
- Leiste aufklappbar: zugeklappt nur der mittlere Bereich der oberen Zeile als Text ohne Symbole, sonst ein schmaler Streifen (KarloDerBaer, Auslegung Claude).

## 07.11.2026: Neuere Preise aus dem Manager im Spiel (Manager 0.18.0, Bridge 0.7.0, Broker 0.36.0)

- **Broker nutzt die Preise des neuesten Stands aus dem Manager**, meist aus der Blizzard-API, wenn sie neuer sind als der eigene Scan (KarloDerBaer). Der Manager schickt dafür je Markt den neuesten vollständigen Stand mit, egal ob API oder Scan (Claude).
- Der Stand gilt in Broker wie eine Live-Abfrage: aktueller Preis ja, Verlauf, Trend und Zahl der Scans nein. Den Verlauf rechnet schon der Manager, sonst würde doppelt gezählt (Claude, zugestimmt).
- Die günstigsten Preisstufen schickt der Manager nicht mit, weil `Data.lua` sonst stark wächst. Für übernommene Gegenstände fallen sie weg, damit keine alten Schnäppchen gemeldet werden (Claude).
- Auf der Leiste steht das Alter der neuesten Daten (Text `age`), das reine Scan-Alter bleibt als eigener Text (Claude, zugestimmt).

## 07.11.2026: Allgemeine Einträge und Blizzard-Stile (Peon_Panel 0.3.0, Peon 0.15.0, Ledger 0.12.0, Konzept Abschnitt 13)

- **Alle vorgeschlagenen Einträge kommen rein**, auch Freunde, Gilde, Ruf und Reset-Zeiten (KarloDerBaer). Anfangs stehen nur sieben davon auf der Leiste, damit sie nicht überläuft, der Rest ist zum Anhaken (Claude).
- **Alles in einem Zug, getestet wird zum Schluss** (KarloDerBaer). Vieles ist deshalb bis dahin nur mit dem Nachbau geprüft.
- XP pro Stunde über die letzten 60 Minuten statt über die Sitzung, sonst drückt jede Pause den Wert auf Dauer (Claude, Vorschlag ohne Widerspruch).
- Die Einträge liegen in Peon_Panel statt in einem eigenen Addon, weil sie nur dort angezeigt werden. Dafür erlaubt der Kern mehrere Starter je Modul (Claude).
- Die Gesamtspielzeit fehlt, weil `/played` in den Chat schreibt und das Abfangen in Blizzards Chatfenster eingreifen würde (Claude).
- **Standard ist der Stil Tooltip dunkel**, weil er schlank ist und zu Blizzard passt. Rahmen aus Blizzards eigenem Code statt eigener Grafik, die Fassung aus 0.2.0 bleibt als Schlicht und als Rückfall (Claude, nach dem Wunsch von KarloDerBaer nach Blizzard-Look).
- Metall, Dialog und Holz behalten ihre Randfarben, weil das Einfärben ihre Grafik verdunkeln würde (Claude).

## 07.11.2026: Umschalten der Addons auch bei laufendem WoW

- `scripts\junctions.cmd` prüft nicht mehr, ob WoW läuft, auch eine Warnung gibt es nicht. Die frühere Regel war nur eine Vorsichtsmaßnahme, und beim Neueinloggen kann es Wartezeiten geben (KarloDerBaer). Im Spiel einmal bestätigt: Peon_Panel bei laufendem WoW umgeschaltet, es gab kein Problem (KarloDerBaer). Verweigert Windows das Verschieben, bricht das Skript mit einer Meldung ab (Claude).

## 07.11.2026: Peon_Panel nach dem Vorbild Titan Panel (Peon_Panel 0.2.0, Konzept Abschnitt 12)

- **Die Leiste steht nur noch oben**, mittig am Rand. Das ersetzt „an einer von 8 Stellen“ vom 06.11.2026, weil an anderen Stellen Blizzards Oberfläche verschoben werden müsste (KarloDerBaer).
- **Nicht über den ganzen Bildschirm, mit runden Ecken**, in Optik und Bedienung wie Titan Panel. Auch das Panel bekommt runde Ecken und bleibt neben der Leiste bestehen (KarloDerBaer). So bleiben Minimap und Buffs frei, und es gibt keine Eingriffe in Blizzards Fenster (Claude).
- Breite in Prozent, Standard 60 %, weil das nach dem Screenshot von KarloDerBaer auch auf einem 16:9-Bildschirm neben Minimap und Buffs passen sollte. Reicht der Platz nicht, geht der Inhalt vor (Claude).
- Drei Bereiche mit Ziehen über die Drittel der Leiste, damit auch ein leerer Bereich erreichbar ist (Claude).
- Der Hintergrund besteht aus Stücken ohne Überlappung statt aus einem Bild mit neun Feldern, weil dafür nur sicher vorhandene Funktionen nötig sind. Es wird kein Code und keine Grafik aus Titan Panel übernommen (Claude).
- Die Leiste bleibt auch ohne Einträge sichtbar, sonst wäre das Menü zum Wiedereinblenden nicht erreichbar (Claude).
- Ebene `LOW` statt `MEDIUM`, damit Fenster und Karte darüber liegen. Im Spiel zu prüfen (Claude).

## 07.11.2026: Kein Hinweis mehr auf einen Neustart von WoW (Peon Manager 0.17.1)

- `/reload` hat bisher immer gereicht, auch bei neuen Dateien und einem ganzen neuen Addon. Der Hinweis auf einen Neustart entfällt deshalb künftig in Doku, Vorlage und Manager (KarloDerBaer). Das ersetzt die frühere Regel „neue Dateien: WoW neu starten“. Alte Einträge im Verlauf bleiben stehen (Claude).

## 06.11.2026: Neues Modul Peon_Panel (Peon_Panel 0.1.0, Peon 0.14.0, Konzept `Peon_Panel_Konzept.md`)

- **Waagerechte Leiste an einer von 8 Stellen und zusätzlich ein quadratisches, frei verschiebbares Panel**, beide gleichzeitig möglich. Senkrechte Leisten vorerst nicht, weil der Text sie zu breit macht (KarloDerBaer).
- **Symbole und Texte gleich in der ersten Fassung.** Je Modul einstellbar, wo es erscheint und ob und welchen Text es zeigt, auch im Kontextmenü, und später erweiterbar (KarloDerBaer).
- Dabei sind die Module mit Button, dazu Bags und Peon, Feedback öffnet per Klick sein Fenster (KarloDerBaer).
- **Minimap-Buttons werden automatisch ausgeblendet**, sobald das Modul angezeigt wird. Beim ersten Start erklärt ein Hinweis, dass sich jeder Button wieder einschalten lässt (KarloDerBaer).
- Der Kern merkt sich, was Panel ausgeblendet hat, und stellt es wieder her, wenn Panel nicht mehr aktiv ist, sonst fehlten nach dem Abschalten alle Symbole (Claude).
- Ob ein Minimap-Button sichtbar ist, bleibt im jeweiligen Modul gespeichert, damit dessen eigene Optionsseite weiter stimmt (Claude).
- Die Anbindung läuft über einen neuen Eintrag im Kern (`mod:NewLauncher`, API 14), den `NewMinimapButton` selbst anlegt (Claude).
- **Symbole lassen sich ziehen, das ändert nur die Reihenfolge** (KarloDerBaer). **Der Rechtsklick öffnet ein Kontextmenü, das nicht verdeckt wird** (KarloDerBaer). Es wird am Rand von Leiste oder Panel verankert, weil Blizzards Kontextmenü am Mauszeiger die Anzeige überdecken kann (Claude).
- Texte werden von den Modulen kurz geschrieben statt abgeschnitten, weil ein abgeschnittener Goldbetrag falsch wäre. Im Panel stehen sie unter dem Symbol (Claude).
- Beim Ziehen zeigt eine Markierung die Zielstelle, die Symbole rücken erst beim Loslassen, weil sie sonst bei unterschiedlich breiten Texten hin- und herspringen könnten (Claude, weicht vom ersten Entwurf ab).
- Das Raster für die Leiste nutzt „Aus“ in der Mitte als Schalter, statt eines eigenen Hakens (Claude).

## 06.11.2026: Eigene Bereiche in Peon_Bags (Bags 0.3.0, Konzept `Peon_Bags_Bereiche.md`)

- **Eigene, frei benennbare Bereiche** in Taschen und Bank, accountweit (KarloDerBaer, Vorschlag Claude). Die Gildenbank bleibt außen vor, weil sie allen in der Gilde gehört (Claude).
- **Zuordnen per Ziehen auf die Überschrift**, weil alle Klicks auf Gegenstände schon belegt sind (KarloDerBaer, Vorschlag Claude).
- **Brokers Behalten-Liste kommt als zweiter Schritt** in einen eigenen Bereich, nur lesend und abschaltbar (KarloDerBaer, Vorschlag Claude). Das lockert „vorerst keine Broker-Anzeigen“ vom 07.10.2026.
- Gegenstände mit Zusatz werden je Variante getrennt, weil man oft nur eine davon behalten will (Claude).

## 06.11.2026: Navigation, Einkaufsliste, Favoriten, Ladezeiten (Peon Manager 0.17.0, Broker 0.34.0, Bridge 0.6.0)

- **Märkte heißen „PvE Allianz“**, der interne Name des Spiels steht nur noch unter Quellen. Die Auswahl sitzt in der Seitenleiste und erscheint erst ab zwei Märkten (KarloDerBaer). Der Schlüssel bleibt, weil Broker damit seine Werte findet (Claude).
- Forever hat keine Realms, also darf es kein „PvE Allianz 2“ geben (KarloDerBaer). Ein anderer interner Name mit gleicher Region, gleichem Regelsatz und gleicher Fraktion führt deshalb in denselben Markt, `Data.lua` nennt ihn als Verweis (Claude). Schon getrennte Märkte werden nicht zusammengelegt, das gab es bisher nicht.
- **Vor und Zurück wie im Browser, offener Gegenstand als Untertab am Herkunftsreiter** (KarloDerBaer). Je Reiter höchstens ein Untertab, er bleibt bis zum Schließen (Claude).
- **Einkaufsliste ersetzt die Merkliste**, die Merkliste wird ohne Übernahme verworfen (KarloDerBaer, bisher nicht genutzt). Listen gelten accountweit (KarloDerBaer), damit der Manager sie ohne Charakter führen kann. Das ersetzt für diese Daten den Grundsatz „Der Manager führt, das Spiel liefert nur an“ vom 06.11.2026, weil hier beide Seiten eingeben. Je Eintrag gewinnt die neuere Änderung, Gelöschtes bleibt 60 Tage als Marke, damit es nicht zurückkommt (Claude).
- Optionaler eigener Höchstpreis je Gegenstand (KarloDerBaer), er geht vor dem Rabatt der Liste (Claude). Die Meldung von Windows gilt für alle Einträge, weil jeder einen Höchstpreis hat, und ist abschaltbar (Claude).
- **Kein Knopf zum Austausch und kein „Jetzt einlesen“:** Der Manager liest und schreibt von selbst, ein Knopf könnte im Spiel ohnehin kein /reload auslösen (KarloDerBaer). Die Kopfleiste nennt nur, was das Spiel noch nicht hat. Neue Preiswerte stehen dezent, sonst stünde der Hinweis stündlich da (Claude).
- **Suche nur auf den Seiten**, die Schnellsuche mit Strg+K entfällt (KarloDerBaer).
- **Favoriten** gelten für alle Märkte und bleiben im Manager, ohne Abgleich mit dem Spiel (Claude, zugestimmt).
- **Datenbank der genauen Werte im Manager, gefüllt aus dem Spiel** (Idee KarloDerBaer): Die Blizzard-API liefert zu Zusätzen nichts (geprüft mit Parametern und Abfragewegen), Ledger speichert nur Name, Qualität und Symbol. Der Manager kennt aus der API Gegenstand und Bonus-Nummer, baut daraus den Link und bestellt die Werte über `Data.lua`. Die Bridge liest sie im Hintergrund, ein Scan ist nicht nötig. Der Befehl im Spiel bestätigte es am 06.11.2026: Der Link nennt den vollen Namen und „+1 Stärke“, „+1 Intelligenz“. Das ändert die Aussage vom 05.11.2026, dass es bei Zusätzen nur Grundwerte gibt (Claude, zugestimmt).
- **Ladezeiten:** Rechnung einmal je Stand beim Einlesen statt bei jedem Öffnen, gespeichert als gepackte Liste je Markt. Eine Spalte je Wert in einer eigenen Tabelle wäre mehr Aufwand ohne Vorteil, weil die Liste immer ganz gebraucht wird (Claude).
- Keine Vorabversion je Paket, alles zusammen (KarloDerBaer).

## 06.11.2026: Manager übersichtlicher (Peon Manager 0.16.0)

- Der Reiter Module heißt Updates, oben stehen Kanal und Suche, darunter Module und Addons. Der Hinweis „WoW läuft“ steht klein bei den Addons (KarloDerBaer).
- Reiter je Modul in einer Gruppe mit Überschrift, damit später Ledger sichtbar getrennt dazukommen kann (KarloDerBaer). Die Gruppen entstehen aus der Modulliste, ein neues Modul braucht dafür keinen eigenen Code in der Seitenleiste (Claude).
- Die Merkliste ist ein eigener Reiter im Broker und gilt je Markt, weil Preise je Markt verschieden sind (Claude). Gemeldet wird einmal und wieder erst, nachdem der Preis über der Grenze lag, damit stündliche Stände nicht jede Stunde melden (Claude).
- Eine Sicherung enthält den Zugang zur Blizzard-API nicht: Er ist für das Windows-Konto verschlüsselt und auf einem anderen Rechner wertlos (Claude). Eingespielt wird beim nächsten Start vor dem Öffnen der Datenbanken, der bisherige Stand bleibt liegen (Claude).
- Preisänderungen vergleichen mit dem üblichen Preis, weil zwei einzelne Stände vor allem Ausreißer zeigten (Knappenhemd +1.900 %). In den ersten Tagen gibt es den noch nicht, dann bleibt der alte Vergleich mit Hinweis (Claude).
- Meistverkauft zeigt den Absatz je Tag aus 14 Tagen statt der letzten 24 Stunden, weil nur dieser Wert sicher gemessen ist (Claude).

## 06.11.2026: Update-Fenster und kurze Texte (Peon Manager 0.15.0)

- Das Update-Fenster kommt schon mit 0.15.0, nicht erst nach dem Umbau der Seitenleiste (KarloDerBaer). Es hängt nicht davon ab.
- Es öffnet sich beim Start, nach jeder Suche von Hand, wenn es etwas gibt, und über „Jetzt aktualisieren“, damit man vor einem Update immer sieht, was neu ist. „Was ist neu“ unter Module zeigt denselben kurzen Text (KarloDerBaer).
- Die Suche alle 6 Stunden öffnet es nicht von selbst, sondern zeigt nur den Knopf, damit es nicht mitten in der Arbeit aufspringt (Claude, so aus dem Wunsch von KarloDerBaer verstanden). Der Knopf „Aktualisieren“ auf einer einzelnen Karte unter Module bleibt direkt, weil der Text dort danebensteht (Claude).
- Die kurzen Texte stehen als Zeilen `Kurz:` im Changelog, nicht in einer eigenen Datei, damit sie beim Schreiben der Version nicht vergessen werden. Der Bau bricht ohne sie ab. Das Manifest führt sie je Version, damit auch sieht, wer Releases übersprungen hat, was seit seiner Version neu ist (Claude).
- „Alles aktualisieren“ fügt neue Addons nicht ungefragt hinzu, sie haben einen eigenen Knopf. Vorgestellt wird ein neues Addon einmal, sonst käme ein bewusst nicht installiertes immer wieder (Claude).

## 06.11.2026: Aufbewahrung im Hintergrund (Peon Manager 0.15.0)

- Aufgeräumt wird in Zeitscheiben im Hauptprozess statt in einem eigenen Thread. Zwei Verbindungen zur Datenbank brächten Sperrfehler beim Einlesen, die Scheiben sind einfacher und reichen (Claude).
- Die Datei schrumpft schrittweise (`auto_vacuum = INCREMENTAL`) statt mit `VACUUM`, das bei Gigabytes das Programm lange anhalten würde. Die einmalige Umstellung beim Öffnen kostet jetzt wenig, weil noch niemand große Datenbanken hat (Claude).
- Die Regler speichern erst mit „Übernehmen“, weil Verdichten sich nicht rückgängig machen lässt. Die Warnung erscheint nur, wenn wirklich Daten betroffen sind, damit sie ernst genommen wird (Claude).
- Das Muster „Wann ist es günstig?“ liest nur vollständige Momentaufnahmen und sieht mit dem neuen Standard 14 statt bis zu 60 Tage. Das steht unter dem Regler und bleibt so, wer mehr will, stellt mehr ein (Claude).

## 06.11.2026: Umbau des Peon Managers, Updates wie bei allen anderen

- **KarloDerBaer bekommt Updates über den normalen Weg**, um zu erleben, was Freunde erleben (KarloDerBaer). Der Normalzustand im AddOns-Ordner sind echte Ordner, die der Manager im Kanal Test aktualisiert. Junctions gibt es nur noch beim Entwickeln, auch für einzelne Addons (`scripts\junctions.cmd manager` und `entwicklung`), weil sonst jede kleine Änderung einen Bau auf GitHub bräuchte (Claude, zugestimmt).
- **Jedes Release zuerst als Vorabversion** mit `-test`, nach der Prüfung durch KarloDerBaer derselbe Stand als normales Release (Claude, zugestimmt). Freunde im Kanal Stabil sehen im Manager nur normale Releases.
- Beim Wechsel zu Entwicklung wandert der echte Ordner ins Archiv, auch wenn er vom Repo abweicht, denn dort geht nichts verloren. `anlegen` bleibt streng und ersetzt nur gleiche Ordner (Claude).
- **Aufbewahrung neu:** Standard 14 Tage alle Angebote und 60 Tage Stundenwerte (etwa 2,7 GB statt 12,7 GB nach einem Jahr), Vorlagen und zwei Regler, Tageswerte bleiben unbegrenzt (KarloDerBaer, Vorschlag Claude).
- **Seitenleiste nach Modulen**, die Gruppe des Broker Client heißt „Broker“ (KarloDerBaer).
- Reihenfolge: Umschalter, Aufbewahrung, Seitenleiste mit Quellen und Übersicht, Update-Fenster (KarloDerBaer, Vorschlag Claude). Dazu alle vorgeschlagenen Ideen, siehe `Peon_Stand.md` (KarloDerBaer).

## 06.11.2026: Feedback zurück, der Manager führt (Peon 0.13.0, Peon_Feedback 0.3.0, Manager 0.14.0)

- **Peon_Feedback kommt zurück und wird ausgeliefert.** Das löst die Entscheidung vom 31.10.2026 ab („Kein Feedback über GitHub oder das Programm“), weil der Weg über den Worker jetzt ohne Aufwand für Nutzer besteht (KarloDerBaer).
- Das Addon ist nur noch ein Zusatz für Feedback im Spiel. Schreiben, Ändern und Löschen geht auch im Manager, Fehler bekommen dort Notizen und lassen sich löschen (KarloDerBaer).
- Der Export als Text entfällt, alles läuft gesammelt im Repo `peon-fehler` zusammen (KarloDerBaer). Der Reiter heißt „Rückmeldungen“ (KarloDerBaer, Vorschlag Claude).
- **Der Manager führt, das Spiel liefert nur an.** Zwei gleichberechtigte Listen abzugleichen wäre fehleranfällig. Was eingelesen ist, löscht das Spiel beim nächsten Laden (Claude).
- **Ein Issue je Eintrag** statt eines Sammelberichts, damit sich Bearbeitetes einzeln schließen lässt. Höchstens 20 je Senden, der Rest bleibt für das nächste Mal (Claude, zugestimmt).
- Der Charakter wird nicht übernommen, Zone und Markt schon, weil sie bei der Fehlersuche helfen (Claude, zugestimmt).
- Die Bereiche speichert der Kern in `PeonDB`, statt sie im Manager fest einzutragen oder aus Lua-Dateien zu lesen, damit sie immer zu Version und Sprache passen (Claude).

## 06.11.2026: Fehlerspeicher im Kern, Reiter Debug, Berichte über einen Worker (Peon 0.12.0, Bridge 0.5.0, Manager 0.13.0)

- Abgefangene Fehler speichert der Kern selbst, statt sie an BugSack weiterzugeben. Der Manager zeigt sie im Reiter Debug, für alle sichtbar, dazu BugGrabber-Einträge mit Peon-Bezug. Im Chat bleibt ein kurzer Hinweis (KarloDerBaer).
- Berichte gehen ohne Konto und Token über einen Cloudflare Worker in ein privates GitHub-Repo, zusätzlich gibt es den Export als Text. Nach dem Senden oder auf Nachfrage beim Export wird der Speicher geleert (KarloDerBaer).
- Das Leeren läuft über `Data.lua` der Bridge statt über eine eigene Austauschdatei des Kerns, weil dieser Weg schon besteht und der Manager SavedVariables nicht schreiben darf: Das Spiel überschreibt sie beim Ausloggen (Claude).
- Geleert wird bis zum spätesten bekannten Fehler statt bis zur aktuellen Uhrzeit. So bleibt ein Fehler erhalten, der in der laufenden Sitzung entstand und noch nicht auf der Platte steht (Claude).
- Namen und Pfade werden schon beim Einlesen ersetzt, die BugGrabber-Spalte `locals` wird nie übernommen, damit private Daten gar nicht erst in einen Bericht gelangen können (Claude).

## 05.11.2026: Gegenstands-Tooltip über die Blizzard-API (Peon Manager 0.12.0)

- Der Broker Client zeigt einen Tooltip mit den Werten eines Gegenstands, Daten aus der Blizzard-API, wenn ein Zugang eingetragen ist (KarloDerBaer).
- Gespeichert wird der fertige Tooltip statt der ganzen Antwort, das hält die Datenbank klein. Neue Gegenstände bringt der Einleser mit, alle anderen werden erst beim Ansehen geholt, statt Tausende auf Vorrat abzufragen (Claude).
- Classic-Daten werden angezeigt, wenn Forever den Gegenstand nicht kennt, aber immer gekennzeichnet, weil Werte abweichen können. Bei Zusätzen steht ein Hinweis, statt Werte vorzutäuschen (Claude).
- Vorerst keine Symbole: Sie bräuchten je Gegenstand eine zweite Abfrage und Bilder aus dem Netz, die Oberfläche lädt bisher nichts von dort (Claude).

## 05.11.2026: Rückmeldungen nach dem Start (Broker 0.33.1, Ledger 0.10.2, Fishing 1.5.2, Peon 0.11.1)

- **Schnellkauf im Radar braucht wieder zwei Klicks.** Das Spiel erlaubt `StartCommoditiesPurchase` nur direkt aus einem Klick, ein Preis vorab ist also nicht möglich. Das ersetzt die Entscheidung vom 03.10. (Schnellkauf mit einem Klick). Der Code bleibt vorerst abgeschaltet im Addon, weil über das Entfernen KarloDerBaer entscheidet (Claude).
- **Neues Angel-Set nur mit Haupt- und Nebenhand**, Hinweis auf weitere Ausrüstung (KarloDerBaer). Vorhandene Sets bleiben unverändert, damit nichts Eingestelltes verloren geht (Claude).
- Einzelne Werte zeichnet der Diagramm-Baustein selbst als Punkt, weil das für jedes Modul gilt und nicht nur für Ledger (Claude).

## 05.11.2026: Einleser der Blizzard-API, AHledger entfernt (Peon Manager 0.11.0)

- **AHledger fliegt ganz raus**, die Blizzard-API ersetzt es (KarloDerBaer). Das Design `Peon_Client_Design.md` nennt AHledger noch, gilt dort aber nicht mehr.
- **Häuser wählt man unter Quellen**, standardmäßig keines. Ein Knopf „Vorschlag“ wählt, was die Addons über Regelsatz, Region und Fraktion wissen. Ohne Zugang steht dort ein Link zu den Einstellungen (KarloDerBaer).
- **Abgefragt wird nur, wenn ein neuer Stand zu erwarten ist**, statt alle 10 Minuten: eine Stunde nach dem letzten Stand, danach alle 5 Minuten, bis er da ist (KarloDerBaer fragte nach dem Sinn von 10 Minuten).
- Der Scan-Vergleich geht beim Vorschlag vor dem Regelsatz, weil nur Normal (PvE) belegt ist (Claude).
- API-Stände werden als Momentaufnahmen wie Scans gespeichert und nur über `art` unterschieden, statt alle Abfragen zu ändern (Claude). Beim Absatz haben sie Vorrang, Scans und API werden nicht miteinander verglichen, weil Scans keine Nummern haben (Claude).
- Gegenstände mit Zusatz: Fehlt der Grundname wegen eines Fehlers bei Blizzard, wird der Stand später eingelesen, statt einen Schlüssel anzulegen, der nie zu den Scans passt (Claude).

## 05.11.2026: Blizzard-API unter Einstellungen, Beobachter (Peon Manager 0.11.0)

- Zugang und Prüfung ziehen nach Einstellungen, weil die API auch für andere Module als den Broker Client taugen kann, zum Beispiel Ledger (KarloDerBaer).
- Offene Fragen zu Takt, Feldern und Angebotsnummern klärt ein Beobachter im Manager, statt eines eigenen Testprogramms. Er sieht das Secret nur im Hauptteil, und seine Abfragen kann der spätere Einleser übernehmen (Claude).
- Der Beobachter läuft nur in der Testfassung über eine Umgebungsvariable, weil er je Stand etwa 30 Abfragen macht und die Antworten ablegt. Nutzer sollen das nicht nebenbei bekommen (Claude).
- Eine Anleitung zum Anlegen des Zugangs und die Nutzung durch Ledger kommen später (KarloDerBaer).

## 05.11.2026: Neue Standardwerte im Tooltip (Tooltip 0.7.3)

- Abstand zum Mauszeiger 40 statt 20, Tooltip von Einheiten verschwindet standardmäßig sofort (KarloDerBaer).
- Gespeicherte Werte, die noch den alten Standardwerten entsprechen, werden einmalig umgestellt, weil ein neuer Standard sonst bei niemandem ankäme, der schon gespielt hat. Selbst gewählte Werte bleiben (Claude).

## 04.11.2026: Blizzard-API, erst prüfen, dann einlesen (Peon Manager 0.10.0)

- Zuerst nur ein Prüfabruf, der Einleser folgt passend zu den echten Daten, weil nicht bestätigt ist, dass Forever Auktionen liefert (KarloDerBaer).
- Der Prüfabruf liegt im Manager, damit auch Freunde ihn nutzen können. Jeder trägt einen eigenen Zugang ein (KarloDerBaer).
- Der Zugang liegt nur verschlüsselt im Datenordner, die Oberfläche bekommt ihn nie zurück, und ohne verfügbare Verschlüsselung wird er nicht gespeichert (Claude).

## 04.11.2026: Erstes Release zum Start von Forever

- Das erste Release erscheint noch vor dem Start, damit ein Freund pünktlich installieren und beim Testen helfen kann (KarloDerBaer). Das Risiko, dass nach dem Start etwas nicht passt (zum Beispiel die Interface-Nummer), fängt eine neue Version auf: Der Manager kann sie verteilen, weitere Releases am selben Tag heißen `vJJJJ.MM.TT.2`.
- Beim ersten Release bleibt „Was ist neu“ leer, weil die Changelogs für eine Erstinstallation zu technisch sind (KarloDerBaer).
- Die README zeigt ein Bild vom Manager aus einem Testordner und den Link zu Buy Me a Coffee (KarloDerBaer).

## 04.11.2026: Umzug auf den Installer (Peon Manager 0.9.1)

- KarloDerBaer nutzt jetzt die installierte Fassung mit Daten im Standard-Datenordner, also dasselbe wie alle anderen, und vor dem ersten Scan (KarloDerBaer). Der frühere Ordner bleibt als Sicherung, die Addons bleiben Junctions.
- Der Manager prüft Data.lua auf der Platte, statt sich auf seinen eigenen Merker zu verlassen. Anlass: Ein Selbsttest ohne eigene Einstellungen fand den echten WoW-Ordner und schrieb dort Data.lua ohne Kanäle (Claude).
- Selbsttests laufen deshalb immer mit eigener `settings.json`, deren `wowDir` auf einen Testordner zeigt.

## 04.11.2026: Installer und Selbst-Update, Schritt I (Peon Manager 0.9.0)

- Selbst-Update liest aus dem Ordner des Release (`generic`) statt über den GitHub-Weg von electron-updater, weil dieser Tags wie v2026.11.04 nicht als Versionen annimmt (im Code nachgelesen). Der Manager kennt den Ordner ohnehin aus dem Manifest (Claude).
- Die neue Version wird im Hintergrund geladen, eingespielt wird nur per Klick, auch nicht beim Beenden. Das passt zu „installiert wird nur per Klick“ (Claude, Design: fragt vor dem Neustart).
- Der Umzug von `<Programmordner>` in den Standard-Datenordner ist kein Code, weil es ihn nur einmal bei KarloDerBaer braucht und kein privater Pfad ins Repo gehört (Claude).

## 04.11.2026: Addons installieren, Schritt H (Peon Manager 0.8.0)

- **Der Manager sucht beim Start und alle 6 Stunden, installiert aber nur per Klick** (KarloDerBaer). So ändert sich nichts ungefragt, etwa während WoW läuft.
- Entfernen verschiebt den Addon-Ordner in die Sicherung statt ihn zu löschen. Das Design sagt „löscht den Ordner“, die Sicherung ist vorsichtiger und kostet kaum Platz (Claude). Alte Sicherungen werden noch nicht automatisch aufgeräumt.
- Laufendes WoW sperrt nichts, der Manager warnt nur (Design 5.4, Punkt 7).
- Der Willkommens-Vorschlag entfällt, sobald Peon installiert ist, auch bei Installation von Hand oder per Junction (Claude).
- Meldet GitHub kein Release, vergisst der Manager das alte Manifest, weil dessen Dateien nicht mehr zu laden wären. Scheitert die Suche nur (Netz, kaputte Antwort), bleibt der letzte gute Stand (Claude).
- Die Abnahme mit dem echten Release bleibt offen, bis es das erste Release gibt. Geprüft wurde mit einem Paket aus `build_release` über einen lokalen Server und einem Testordner (Claude).
