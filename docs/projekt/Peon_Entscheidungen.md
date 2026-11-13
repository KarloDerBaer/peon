# Peon – Entscheidungen

Kurzes Protokoll wichtiger Entscheidungen. Neue Einträge oben anfügen (Datum, Entscheidung, Grund).

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

## 31.10.2026: Manager-Module, Schritt G (Peon Manager 0.7.0)

- **Eigene Datenbankdatei je Manager-Modul** (KarloDerBaer): `broker-client.db` für den Broker Client, `peon.db` für den Manager. „Daten löschen“ löscht so einfach die Datei des Moduls. Die alte `peon.db` zieht einmalig um (Claude).
- Wer vor 0.7.0 schon Einstellungen oder Daten hatte, behält den Broker Client aktiv. Neue Nutzer starten ohne Modul (Design 5.2, 5.5).
- Übersicht, Gegenstände, Chancen und Quellen gehören zum Broker Client und erscheinen nur mit ihm. Ohne Modul zeigt der Manager „Module“ und „Einstellungen“ (Claude).
- Ohne aktives Modul schreibt der Manager `channels = {}` in Data.lua, damit eine installierte Bridge sicher nichts aufzeichnet. Ohne Bridge schreibt er nichts (Claude).
- Fehlende Addons eines Moduls zeigt die Ansicht „Module“ nur an. Installieren kommt mit Schritt H (Claude).

## 31.10.2026: Keine privaten Daten im Repo

- Im öffentlichen Repo steht für den Besitzer nur **KarloDerBaer**, auch in Entscheidungen, Changelogs und Code-Kommentaren (KarloDerBaer). Die Addons bekommen dafür keine neue Version, weil sich nur Kommentare ändern und es noch kein Release gab (KarloDerBaer).
- **Keine Pfade des eigenen Rechners** im Repo. Doku nutzt Platzhalter, die echten Pfade stehen in `CLAUDE.local.md`, das Junction-Skript liest den AddOns-Ordner aus `scripts\local.json`. Beide Dateien sind nicht im Repo (KarloDerBaer, Umsetzung Claude).
- Der Peon Manager nimmt als Standard für den WoW-Ordner den üblichen Ort von Battle.net (`C:\Program Files (x86)\World of Warcraft\_forever_`). Wer WoW woanders hat, stellt es in den Einstellungen ein, die automatische Suche kommt mit Phase 2 (Claude).
- Das Repo auf GitHub wird gelöscht und mit einem einzigen Commit neu angelegt, damit die alten Commits mit Namen und Pfaden wirklich weg sind (KarloDerBaer). Löschen macht KarloDerBaer selbst.

## 31.10.2026: Erstes Release erst mit fertigem Manager

- Das erste Release kommt erst, wenn der Peon Manager mit Installieren, Aktualisieren und Selbst-Update fertig ist, also nach G, H und I. Freunde bekommen Peon damit vermutlich erst nach dem Start von Forever (KarloDerBaer).
- Das Skript für Zips und Manifest (F1) kommt trotzdem zuerst, weil der Manager genau dieses Manifest zum Installieren liest (Claude).
- WoW Forever läuft als `Wow.exe` im Ordner `_forever_` (geprüft, offener Punkt aus dem Design geklärt).

## 31.10.2026: GitHub, Schritt E (Ledger 0.10.1)

- Repo heißt **peon** unter dem Konto KarloDerBaer, öffentlich, Lizenz **MIT** mit KarloDerBaer als Inhaber (KarloDerBaer).
- **Alle persönlichen Daten ersetzt** (KarloDerBaer): Kontoname, Battle.net-Kontonummer und Charakternamen durch erfundene Namen gleicher Länge (Mirel Dorna, Borin, Venla-Ostra), auch in den echten Testdaten, damit Breiten und Sortierungen in den Tests gleich bleiben (Claude). Die lokalen Commits wurden vor dem ersten Push zu einem zusammengefasst, damit die alten Namen nicht im Verlauf stehen (KarloDerBaer).
- **Autor KarloDerBaer** in allen Addons (`## Author`), in der Vorlage und im Peon Manager (KarloDerBaer). Ohne neue Versionen, weil sich nur die Autor-Zeile ändert und es noch kein Release gab (KarloDerBaer).
- **Peon_Bridge kommt nicht ins erste Release** (Design 6.2, `managerOnly`): Ohne Manager zeichnet sie nichts auf, und ohne die nie ausgelieferte Data.lua meldet das Spiel eine LUA_WARNING. Der Manager legt den Platzhalter später beim Installieren an.
- **Kein Discord-Link** in der README, Feedback über Issues im Repo (KarloDerBaer).
- Die Tests auf GitHub laufen ohne `npm ci`, weil der Rechenkern des Managers nur Node braucht. Das spart den Download von Electron (Claude).

## 31.10.2026: Umsetzung Phase 1, Schritte A bis D (Bridge 0.4.0, Broker 0.33.0, Peon Manager 0.6.0)

- Doku je Modul in Stand (kurz) und Changelog (Verlauf) geteilt. Notizen zu Tests stehen im Changelog bei der Version, zu der sie gehören. Der Verlauf von Peon_Feedback liegt mit dem Addon im Archiv (Claude).
- Zeilenenden im Repo bleiben wie im AddOns-Ordner (LF), nur `.cmd` mit CRLF, damit Git die Addon-Dateien nie umschreibt (Claude).
- `scripts\junctions.cmd` ersetzt einen echten Ordner nur, wenn alle Dateien per Prüfsumme gleich sind, und verschiebt ihn vorher ins Archiv. `Data.lua` der Bridge zählt beim Vergleich nicht (Claude).
- Die Bridge meldet sich ohne Freischaltung gar nicht erst bei Broker an. So hat Broker ohne Manager keine Zusatzarbeit beim Scan (Claude).
- Kanäle werden beim Laden einmal geprüft. Eine neue Freischaltung wirkt nach dem nächsten Reload, wie jede neue Data.lua (Claude).
- Brokers interne Namen (`src = "client"`, `D.ClientBand`) und Texte („Üblich (Client, n Tage)“) bleiben, nur das Modul heißt `bridge` (Design 4.1).
- Programm nach `<Programmordner>\Runtime`, Daten nach `<Programmordner>\DB` mitgezogen (KarloDerBaer). Eine Einstellung „Datenordner“ gibt es nicht, der Ordner ergibt sich aus der Lage der exe. Umzug kostete nichts, weil es nach dem Wechsel zu `_forever_` noch keine Datenbank gab.
- Solange es keine Manager-Module gibt (Phase 2), schaltet der Manager den Kanal broker immer frei (Claude).
- WoW Forever ist bis zum Start nicht spielbar. Prüfungen im Spiel stehen in der Prüfliste erster Spieltag (KarloDerBaer).

## 31.10.2026: Peon auf GitHub, Peon Manager, Peon_Bridge (Design `Peon_GitHub_Design.md`)

- Peon kommt in ein **öffentliches GitHub-Repo** (Addons, Programm, Tests, Doku), Versionen als GitHub Releases, damit KarloDerBaer es Freunden geben kann (KarloDerBaer).
- **Kein Feedback über GitHub oder das Programm.** Zu aufwendig für ein paar Freunde. Peon_Feedback kommt nicht ins Repo und wird archiviert, Feedback läuft über einen Kanal auf KarloDerBaers Discord oder das Repo (KarloDerBaer). Die Kern-Funktion `Peon.SetFeedbackAreas` bleibt (API nie ändern).
- Das Programm heißt **Peon Manager** und installiert und aktualisiert Addons und Manager-Module. Die bisherigen Funktionen werden das Manager-Modul **Peon Broker Client** (KarloDerBaer).
- **Manager-Module als mitgelieferte, abschaltbare Teile** (Variante B) statt nachgeladenem Code: Electron selbst ist fast die ganze Größe, ein getrennter Download spart nichts, und es gibt keine Versionsprobleme zwischen Manager und Modulen (KarloDerBaer, Vorschlag Claude).
- Addon Peon_Client heißt **Peon_Bridge**, weil es die allgemeine Verbindung zwischen Spiel und Manager ist und nicht nur zu Broker gehört (KarloDerBaer). Inhalte melden sich als Kanäle an, der Manager schaltet sie über `Data.lua` frei, damit niemand ohne Broker Client Scans in WTF ansammelt (Claude). Jetzt umbenennen, weil in `_forever_\WTF` noch keine Peon-Daten liegen (Claude).
- Das Repo wird die maßgebliche Quelle für den Addon-Code, der AddOns-Ordner zeigt per Junction darauf (Claude). Die doppelte Pflege der Doku im Claude-Projekt endet nach dem Umzug (Claude, Teil des Plans).
- Aufräumen, Git, Repo, Umbenennung und ein erstes Release vor dem Start, Manager-Funktionen danach (KarloDerBaer). Umsetzung mit **Claude Code** auf KarloDerBaers PC (KarloDerBaer).

## 25.10.2026 – Peon Client 0.5.0

- Englische Texte bleiben vorerst aus: Das wäre ein eigener Schritt über alle Ansichten, KarloDerBaer spielt deutsch (Claude, KarloDerBaer kann es jederzeit anstoßen).
- Der übliche Bereich im Diagramm zeigt je Tag den Stand, den Broker an diesem Tag bekommen hätte, statt eines festen Bands mit dem heutigen Wert (Claude).

## 25.10.2026 – Umzug in die Release-Version `_forever_`

- Die Beta ist beendet. Gearbeitet wird ab jetzt in `<WoW-Ordner>` (KarloDerBaer). Im Beta-Ordner waren Dateien schreibgeschützt.
- Nur die Peon-Addons ziehen um, fremde Addons kommen über CurseForge (KarloDerBaer).
- Frisch anfangen: keine Einstellungen oder Daten aus der Beta im Spiel (KarloDerBaer), neue Datenbank im Peon Client, die alte bleibt als `DB_beta` liegen (KarloDerBaer).
- Tests hängen nicht mehr an KarloDerBaers Spieldaten: test_fish nutzt eine feste Kopie der Beta-Einstellungen im Projektordner (Claude).

## 23.10.2026 – Absatz und Chancen, C6 (Programm 0.4.0, Peon_Client 0.3.0, Broker 0.32.0)

- **Der Client rechnet den Absatz und gibt ihn an Broker**, weil er alle Angebote kennt und sich das später mit Auktionsnummern aus der Blizzard-API verbessern lässt (KarloDerBaer).
- **Händlerpreis liefert Peon_Client** mit den Namen (KarloDerBaer). Alle vier Reiter (Wiederverkauf, Händler, Fallend und Steigend, Lohnend) gleich im ersten Schritt (KarloDerBaer).
- Vergleich genau nach Brokers Regeln, damit beide gleich zählen; geprüft gegen den Lua-Code (Claude).
- Broker nimmt den Absatz des Clients nur, wenn er selbst in den letzten 6 Std. unter 60 Min. beobachtet hat. Sein eigener, aktueller Wert hat sonst Vorrang (Claude).
- Wiederverkauf gilt als zweifelhaft, wenn in 14 Tagen nie nahe der Untergrenze verkauft wurde. Scherzpreise ziehen sonst den Bereich hoch und täuschen große Gewinne vor (Claude, mit Beispieldaten gesehen).
- Einzelne Vergleiche werden nach 2 Tagen zu Tageswerten zusammengefasst, sonst wächst die Datenbank mit stündlichen Scans um Gigabytes (Claude).

## 23.10.2026 – Rückgabe an Broker, C4 (Programm 0.3.0, Peon_Client 0.2.0, Broker 0.31.0)

- Der Client liefert nur den **Langzeit-Teil** des üblichen Bereichs (MITTE, SCHW, LANG, Tage). HEUTE, Richtwert, Trend und Schnäppchen rechnet Broker weiter live, weil sie vom aktuellen Scan abhängen (KarloDerBaer).
- **14 Tage und Halbwertszeit 3 Tage wie Broker**, damit beide gleich rechnen und der Wechsel nicht auffällt (KarloDerBaer). Absatz kommt später mit C6 (KarloDerBaer).
- Werte gelten 7 Tage, einstellbar 1–30 (`freshDays`); danach und bei jedem Fehler rechnet Broker selbst (Claude).
- Tageswert im Client: Mittel der Mediane aller eigenen Scans eines Tages, ohne eigenen Scan Brokers Tagesmittel (Claude).
- Neue Programmversion nur mit den geänderten Dateien eingespielt (app.asar und eine kleine Änderung an der exe), statt 320 MB zu übertragen (Claude).

## 23.10.2026 Geheime Aufrufkette (Tooltip 0.7.2, Bags 0.2.1)

- Liefert Forever die Aufrufkette als geheimen Text, wird der betroffene Gegenstands-Tooltip gar nicht geordnet, statt die Zeilen ohne Herkunft einzusortieren. So landet keine Zeile im falschen Teil, und es bleibt beim Grundsatz „geheime Werte: nichts anfassen“ (Claude).

## 22.10.2026 – Maximale Breite für Gegenstands-Tooltips (Tooltip 0.7.1)

- Lange Zeilen in Gegenstands-Tooltips werden umgebrochen, Breite einstellbar (Wunsch KarloDerBaer). Standard an mit 450 Punkten, Bereich 250–800 (Claude, bitte im Spiel prüfen und bei Bedarf anpassen).
- Umgebrochen wird durch eingefügte Zeilenumbrüche statt über Blizzards Umbruch, weil der nach dem Umschreiben der Zeilen nicht zuverlässig greift (Claude).

## 22.10.2026 – Umsetzung Broker-Verlauf und C3 (Peon Client 0.2.0)

- Gegenstandsliste standardmäßig nach Zahl der Angebote sortiert, nicht nach Wert (Median × Menge): Scherzangebote zu Millionen Gold standen sonst oben (Claude).
- Muster „Wann ist es günstig?“ in 3-Stunden-Abschnitten und erst ab 10 Scans, sonst zeigt es Zufall (Claude).
- Platz je Zeile für die Speicherschätzung wird aus der eigenen Datenbank gemessen (Suchverzeichnisse zählen mit), statt eines festen Werts (Claude).
- Rechtschreibprüfung im Programm aus, damit es keine Wörterbücher aus dem Netz lädt (Claude).
- Neue Programmversionen werden neben `Runtime` entpackt und dann getauscht; die alte bleibt als Sicherung liegen (Claude).

## 22.10.2026 – Beta geht offline: neue Reihenfolge für den Peon Client

- Die Beta-Server sind offline und werden am 23.10. abends bis zum Start abgeschaltet. Tests im Spiel gibt es bis zum Start (4./5. November) nicht mehr, vielleicht noch ein paar Scans am 23.10. (KarloDerBaer).
- **Bis zum Start wird das Programm fertig gebaut** (C3 Gegenstand mit Verlauf, C4 Rückgabe an Broker, C6 Chancen), geprüft mit den echten Daten und dem Nachbau. **AHledger, Blizzard-API und weitere Quellen erst zum Release**, ebenso die Quellenprüfung (C5) mit frischen Scans (KarloDerBaer). Die Ersatz-Prüfung über Tageswerte (Broker gegen AHledger-Verlauf) entfällt.
- **Brokers Tages- und Wochenwerte werden eine eigene Quelle im Client** („Broker-Verlauf“, gekennzeichnet als Mittel der Scans je Tag), damit der Verlauf von Anfang an Tiefe hat (KarloDerBaer).
- Alles, was ab jetzt im Spiel läuft (Broker, Peon_Client), ist bis zum Start nur mit dem Nachbau geprüft; Änderungen an Broker klein halten und immer mit Rückfall auf die eigene Rechnung (Claude).

## 22.10.2026 – Umsetzung C2: Programm Peon Client 0.1.0

- **Electron 44 mit eingebautem SQLite** (`node:sqlite`) statt einer zusätzlichen Datenbank-Bibliothek: keine Teile, die für Windows eigens gebaut werden müssen (Claude, im ersten Bauabschnitt getestet wie im Design vorgesehen).
- **Angebote je Momentaufnahme gepackt** in der Tabelle der Momentaufnahmen statt einer Zeile je Angebot (Abweichung vom Design 7.1): etwa zehnmal kleiner, alles bleibt neu berechenbar; die Kennzahlen je Gegenstand stehen in `item_snap` (Claude).
- **AHledger wird schon für den Vorschlag abgerufen**, nicht erst nach Bestätigung, damit bis zur Quellenprüfung Daten da sind; angezeigt wird es nur zum Vergleich (Claude).
- Größte Preisänderungen in der Übersicht nur ab 1 Silber und 3 Stück, sonst überwiegen Zufallswerte (Claude).
- Schrift Barlow im Programm enthalten, weil die Oberfläche nichts aus dem Netz lädt (Claude).

## 22.10.2026 – Große Zahlen in Texten (Broker 0.30.2)

- Geldbeträge und Auktionsnummern werden nie mit `%d` geschrieben, weil Forever-Lua dort bei 2^31 abbricht. Regel im Überblick, Nachbau der Grenze im Test (Claude).
- Scheitert ein Scan-Schritt, beendet Broker den Scan und merkt die Meldung (0.30.1), damit Fehler nachlesbar sind, auch ohne Chat (Claude).

## 22.10.2026 – Platzhalter Data.lua (Peon_Client 0.1.1)

- Das Spiel meldet eine fehlende TOC-Datei als LUA_WARNING. Statt eines eigenen Datenordners liegt in Peon_Client eine leere Data.lua als Platzhalter, die nie ausgeliefert und vom Client überschrieben wird (Claude, hält die Entscheidung „im Ordner von Peon_Client“).

## 22.10.2026 – Umsetzung C1: Peon_Client 0.1.0, Broker 0.30.0

- Broker meldet Momentaufnahmen über eine Zuhörer-Schnittstelle, Peon_Client macht daraus das Format (Claude). Broker kennt so das Format nicht und bleibt ohne Peon_Client unverändert. Ein Zuhörer mit Fehler wird entfernt, damit ein Fehler im Client nie den Scan stört (Claude).
- Reine Gebote kommen mit in die Momentaufnahme, wie bei Blizzard, auch wenn Broker sie nicht auswertet (Claude).
- Namen gehen mit jedem Scan mit, bis der Client sie einmal bestätigt hat, danach nur noch neue (Claude). Varianten tragen ihren vollen Namen in der Zeile.
- Dieselbe Live-Abfrage mit gleichem Ergebnis wird innerhalb 60 Sek. nur einmal abgelegt (Radar fragt oft nach) (Claude).
- `Data.lua` steht in der TOC, wird aber nie ausgeliefert, damit ein Update die Werte des Clients nicht überschreibt (KarloDerBaer, Design 6.5).

## 22.10.2026 – Peon Client (Programm für Windows), Design `Peon_Client_Design.md`

- Begleitprogramm heißt **Peon Client** und löst den Entwurf `Peon_Broker_Programm.md` ab. Hauptaufgaben: Auktionsdaten erfassen, speichern, auswerten und Schnittstelle zu Broker (KarloDerBaer).
- Technik **Electron** mit **Vue** und ECharts, Datenbank SQLite, Aussehen dunkel und modern mit Peon-Grün (KarloDerBaer, Vorschläge Claude mit Beispielen). Python verworfen: die Oberfläche wäre ohnehin HTML gewesen, Electron hält alles in einer Sprache und ist hier vollständig testbar.
- Stufe 1: Übersicht und Import, Gegenstand mit Verlauf, Ranglisten und Chancen, Rückgabe an Broker, schöne und übersichtliche Oberfläche (KarloDerBaer).
- **Quellen nach Qualität** (KarloDerBaer): eigene Scans und Blizzard-API sind Momentaufnahmen, AHledger ist eine Fremdmessung aus Scans vieler Spieler. AHledger erst nach einer Quellenprüfung (Vergleich mit eigenen Scans, noch in der Beta) je Zweck freigeben, bis dahin nur zum Vergleich. AHledger immer mit Quellenangabe und Link (Bedingung von AHledger).
- **Export im Format der Blizzard-API** (KarloDerBaer): je Angebot eine Zeile mit item, bonus, quantity, buyout, unit_price, bid, time_left, id. Völlig gleiche Angebote als eine Zeile mit Zähler (verlustfrei, weil der Scan keine Auktionsnummer liefert). Live-Abfragen kommen mit.
- **Eigenes Modul Peon_Client** im Spiel für die Schnittstelle (KarloDerBaer): Warteschlange (10 Scans, einstellbar), Knopf „An Client übergeben“ nach einem Scan, Client-Werte als `Data.lua` im Ordner des Moduls (nur vom Client erzeugt, nie ausgeliefert). Broker bekommt nur eine Zuhörer-Schnittstelle und liest die Werte über das Modul.
- **Broker nutzt Client-Werte vorrangig**, solange sie höchstens 7 Tage alt sind, sonst eigene Rechnung, Quelle sichtbar (KarloDerBaer).
- **Aufbewahrung einstellbar** mit Anzeige des aktuellen und geschätzten Speicherbedarfs, Standard 30 Tage fein (KarloDerBaer).
- Ordner: Quellcode `<Repo>\client`, Programm `<alter Programmordner>\Runtime`, Datenbank `<alter Programmordner>\DB`. Läuft im Infobereich und überwacht selbst (KarloDerBaer).

## 07.10.2026 – Anmerkungen von KarloDerBaer zu Bags, Tooltip, Ledger; Absturz Broker (Peon 0.11.0, Bags 0.2.0, Tooltip 0.7.0, Broker 0.29.0, Ledger 0.10.0)

- **Bags:** Umschalter „Nach Art“ (grau = aus, farbig = an) statt langem Text; Fenster im Stil von Blizzards Fenstern – Taschen und Bank mit Blizzards eigenen Vorlagen (KarloDerBaer).
- **Tooltip-Optionen mit Untertabs** Allgemein / Gegner / Gegenstände (KarloDerBaer, Vorschlag Claude). Dafür neuer Kern-Baustein (API 11), weil Reiter auf Optionsseiten auch andere Module brauchen können. Damit wird `Peon.RegisterWindow` für Mover M4 API 12.
- **Beispiel-Tooltips** in den Reitern Gegner und Gegenstände; Gegenstand aus den eigenen Sachen mit Pfeilen wählbar (Claude).
- **Vergleichs-Flackern:** späte Zeilen sofort ordnen, Blizzards Vergleichszeilen immer unten statt in die Teile einzuordnen (Claude, aus Blizzards Code abgeleitet).
- **Ledger:** neuer Reiter „Gegenstände“ mit allen bekannten Gegenständen (inkl. Auktionshaus), der bisherige heißt **„Umsatz“** (KarloDerBaer). Minimap-Symbol Schriftrolle `INV_Scroll_03` (Claude, KarloDerBaer wollte nur „ein anderes passendes“).
- **Ledger-Diagramme nach Einheit getrennt**: oben Preis je Stück (alles in Gold), unten Stück (links du, rechts Auktionshaus); alle Linien in der Legende, Werte-Kasten beim Überfahren (KarloDerBaer, aus zwei Vorschlägen). Ersetzt den Aufbau vom 06.10. „oben Charakter, unten Auktionshaus, je links Gold/rechts Stück, gleicher Gold-Maßstab“ – die zwei Achsen je Diagramm machten es schwer lesbar.
- **Absturz Broker:** nie `pcall` um Funktionen mit sehr vielen Rückgabewerten (z. B. `GetChildren` von UIParent) – Forever-Lua stürzt mit einer Assertion ab (Claude, Regel im Überblick).

## 07.10.2026 – Umsetzung Peon_Bags 0.1.0 (T1–T4)

- Alles in einem Zug gebaut (KarloDerBaer: „setze alles um“), Gildenbank ungetestet.
- Ein Hauptschalter für Taschen **und** Bank, eigener Schalter für die Gildenbank (Claude).
- Blizzards Bank- und Gildenbank-Fenster werden nicht versteckt, sondern in einen winzigen, sichtbaren Rahmen umgehängt – Verstecken würde die Bank schließen; Knopf „Blizzard“ holt das Fenster für den Besuch zurück (Claude).
- Taschen öffnen nur über B-Taste/Taschenknöpfe und die gewählten Fenster des Spiels; Blizzards `OpenAllBags`/`CloseAllBags` werden nicht mitgelesen, damit Händler & Co. nur nach den eigenen Haken öffnen (Claude).
- Gold der Gildenbank über eigene Rückfragen (`PEON_BAGS_GB_DEPOSIT/WITHDRAW`) statt Blizzards, weil diese erst mit Blizzards Gildenbank geladen werden (Claude).

## 07.10.2026 – Neues Modul Peon_Bags (Taschen, Bank, Gildenbank), Konzept `Peon_Bags_Konzept.md`

- Eigenes Taschen-Modul statt Bagnon, damit KarloDerBaer es anpassen kann und die Einbindung von Ledger, Broker und Mover unter eigener Kontrolle ist (KarloDerBaer).
- Name **Peon_Bags**; Reagenzientasche als **eigener Abschnitt**; Anordnung **Taschenreihenfolge oder nach Art**, umschaltbar per Knopf im Fenster (KarloDerBaer).
- **Schlank:** vorerst keine Anzeigen von Broker/Ledger im Fenster (Wert, Markierungen, Filter, Müll verkaufen) (KarloDerBaer).
- **Twinks nicht in Peon_Bags** – die Anzeige in Ledger reicht; BagBrother entfällt (KarloDerBaer).
- **Gildenbank** gleich mit vorbereiten nach Blizzards Retail-Schnittstelle, Test später (KarloDerBaer).
- Technik (Claude): Plätze aus Blizzards Taschenknopf-Vorlage (Benutzen auch im Kampf), Blizzard-Fenster nur ausblenden, kein Code aus Bagnon (All Rights Reserved), keine fremden Bibliotheken; solange Bagnon geladen ist, bleibt Peon_Bags passiv.

## 07.10.2026 – Durchsicht Broker (Broker 0.28.0)

- Alle Punkte der Durchsicht umgesetzt (KarloDerBaer): Varianten, kleine Fehler, Schnellkauf absichern, Aufräumen und Datenmenge.
- **Ausrüstung mit Zusatz je Variante getrennt, erkannt am vollen Namen** (KarloDerBaer, Vorschlag Claude). Ein Prüfbefehl war nicht nötig: die vorhandenen Daten zeigten, dass Scan, Taschen und Links den vollen Namen liefern. Schlüssel `"itemID:voller Name"` (sprachabhängig – unkritisch, KarloDerBaer spielt deDE). Alte gemischte Einträge werden beim nächsten Scan gelöscht.
- Suchschlüssel je Variante werden nebenbei gelernt; **Varianten ohne gelernten Schlüssel lässt der Radar aus**, statt sie fälschlich als „weg“ zu melden (KarloDerBaer).
- **Ledger bekommt bei Varianten den Wert der günstigsten Variante** (vorsichtig; KarloDerBaer, statt Durchschnitt).
- Schnellkauf: kein Preis vorab bei gewähltem Treffer oder offener Blizzard-Kaufansicht, und dann nie `CancelCommoditiesPurchase` – damit Broker keinen eigenen Kauf des Spielers abbricht (Claude, im Spiel nicht beobachtet, nur vorbeugend).
- Fehlersuch-Protokolle nur mit `/broker debug`; Brokers alte Buch-Listen und der Abgleich der Einstellgebühr entfallen (Claude, abgestimmt).

## 06.10.2026 – Alt+Klick öffnet den Gegenstand in Ledger (Ledger 0.9.1, Broker 0.27.1)

- Alt+Klick gehört Ledger: überall, wo ein Gegenstands-Tooltip erscheint, und auf Chat-Links; nicht auf Aktionsleisten, weil das Spiel dort zusätzlich die Taste auslöst (KarloDerBaer, aus Vorschlag Claude). Dazu eine frei wählbare Tastenbelegung für den Gegenstand unter der Maus (KarloDerBaer).
- Broker gibt Alt+Klick ab (Verkaufen, Behalten, Einkaufsliste) – KarloDerBaer nutzt dafür das Broker-Fenster.
- Belegte Kombinationen im Spiel: Umschalt+Klick, Strg+Klick, Rechtsklick; Alt+Umschalt verworfen (Gefahr „Stapel teilen“).

## 06.10.2026 – Peon_Mover 0.1.0 (M1–M3)

- Position und Größe **accountweit**; Umschalt + Rechtsklick setzt **beides** zurück; Peon-Fenster später über Kern-Erweiterung API 11 (KarloDerBaer).
- Nur die Größe ändern speichert keine Position, damit Blizzard das Fenster weiter anordnen kann (Claude).
- Zurücksetzen nutzt die mitgelesene Wunschposition von Blizzard statt Blizzards Anordnungs-Funktion aufzurufen – vermeidet Taint im Fenster-Manager (Claude).
- „Standardwerte wiederherstellen“ lässt die Fensterpositionen stehen; dafür „Alle Fenster zurücksetzen“ (Claude).
- Ausgelassen: Taschen (Bagnon) und die Weltkarte, solange Leatrix_Maps geladen ist (macht sie selbst verschiebbar) (Claude).
- Die Fensterliste zeigt nur gefundene Fenster (plus gespeicherte), nicht die ganze feste Liste – viele Retail-Fenster gibt es in Forever nicht (Claude).

## 06.10.2026 – Neues Modul Peon_Mover (Fenster verschieben), Konzept `Peon_Mover_Konzept.md`

- Eigenes Modul statt Kern, weil der Kern nur Bausteine liefert und das Modul abschaltbar bleibt (KarloDerBaer, Vorschlag Claude). Name Peon_Mover (KarloDerBaer).
- Positionen dauerhaft, Verschieben an der Titelleiste, Größe mit Strg + Mausrad, Zurücksetzen mit Umschalt + Rechtsklick, Fensterliste in den Optionen, Sperre nur in den Optionen (KarloDerBaer).
- Kein Prüfbefehl (Wunsch KarloDerBaer): Recherche ergab, dass Forever den Retail-Client nutzt und BlizzMove Forever offiziell unterstützt. Grundlage ist BlizzMoves Fensterliste (nur die Namen, eigener Code), ergänzt um automatische Erkennung über `UIPanelWindows`; die Fensterliste in den Optionen zeigt, was erkannt wurde (Claude).
- Nur Fenster, keine Aktionsleisten oder Einheitenrahmen – dafür gibt es in Forever den Bearbeitungsmodus (Claude).

## 06.10.2026 – Teile im Gegenstands-Tooltip (Peon_Tooltip 0.6.0, Konzept `Peon_Tooltip_Konzept.md`)

- Zuerst nur **Gegenstände** (KarloDerBaer); Einheiten bleiben, wie sie sind (geheime Werte im Kampf).
- **Kein Prüfschritt vorab** (KarloDerBaer): Forever verhält sich bei Tooltips wie Retail; geprüft wird erst bei Problemen, dafür gibt es `/ttp teile`.
- Name immer oben; ausgeblendete Teile sind ganz weg; Trennung als eigener Eintrag – Trennlinie oder Leerraum; jedes Peon-Modul ist ein eigener Teil, auch künftige; alles in einem Zug (KarloDerBaer).
- Neu dazu: **Rahmenfarbe bei Gegenständen** wählbar – Standard (Blizzard) oder Qualität des Gegenstands (KarloDerBaer).
- Technik (Claude): Herkunft über die Aufrufkette statt Anpassung der fremden Addons; Zeilen werden in die vorhandenen Zeilen umgeschrieben statt den Tooltip neu aufzubauen (kein erneutes Auslösen der anderen Addons); Kern bleibt unverändert.

## 06.10.2026 – Accountbank und Gildenbank in den Unterlagen

- Recherche (Blizzard-Forum): Eine Accountbank gibt es in Forever vermutlich nicht, die Gildenbank schon (100 Gold). Die Accountbank-Hinweise in den Unterlagen werden durch den Hinweis ersetzt, dass Ledger die Gildenbank noch nicht erfasst (KarloDerBaer). Die Erfassung der Gildenbank wird erst eingeplant, wenn KarloDerBaers Gilde eine hat und sie im Spiel geprüft werden kann. Der Code, der eine Accountbank mit Plätzen lesen würde, bleibt unverändert.

## 06.10.2026 – Umsetzung Reiter „Gegenstand“ (Peon 0.10.0, Broker 0.27.0, Ledger 0.9.0)

- Alle fünf Bauabschnitte in einem Zug (KarloDerBaer: „führe alle Schritte durch“).
- **Marge-Kasten** rechnet mit den Kosten des **nächsten Stücks** (wie Brokers „Unter deinen Kosten“), das Diagramm mit Kosten Ø je Tag (Claude, offener Punkt aus dem Konzept; im Spiel prüfen).
- **„Ohne Verlust ab“** = Kosten ÷ 0,95, vorerst ohne offene Einstellgebühren (Claude, einfacher; später möglich).
- **Bestand im Diagramm** aus den Kostenposten (Stück mit Posten), weil nur sie je Tag nachgerechnet werden können; die Textspalte zeigt den echten Bestand (Claude).
- **Ledger braucht Kern API 10**, weil der Reiter den Diagramm-Baustein nutzt; alle drei Addons kommen zusammen (Claude).
- Post vom Twink ohne bekannten Versand bekommt den Marktwert wie ein Anfangsbestand (Claude).

## 06.10.2026 – Reiter „Gegenstand“ in Ledger und Kosten je Charakter (Konzept `Peon_Ledger_Gegenstand.md`)

- **Ort:** Peon_Ledger, neuer Reiter „Gegenstand“ (KarloDerBaer, Vorschlag Claude) – Bestand, Kosten und Verkäufe hat nur Ledger, das Fenster geht überall auf. Diagramm als Kern-Baustein (API 10).
- **Aufbau** (KarloDerBaer, aus fünf Entwürfen): links Textspalte, rechts oben Diagramm mit den Werten des Charakters, unten Diagramm Auktionshaus; je Diagramm links Gold, rechts Stück; beide Gold-Achsen mit gleichem Maßstab. Überschrift oben = Auswahlliste Charakter (Standard eingeloggter Charakter, auch „Alle Charaktere“).
- **Vergleich Kosten/AH-Preis:** Gewinnzone (Fläche zwischen AH Min und „ohne Verlust ab“ = Kosten ÷ 0,95, grün/rot) als Standard, Marge-Streifen zuschaltbar (KarloDerBaer). Dazu Kosten als Stufenlinie, Bestand als Umriss, senkrechte Striche für Käufe/Verkäufe, Marge-Kasten in der Textspalte.
- **Zeitraum** zuletzt gewählter; zusätzlich Beute je Tag, Menge im AH (Stück) und Marktabsatz – Broker hebt den Absatz dafür so lange auf wie die Preise (KarloDerBaer).
- **Kosten je Charakter** statt accountweit (KarloDerBaer): ersetzt die Entscheidung vom 03.10. Post an Twinks nimmt die Kosten mit, Posten behalten ihr ursprüngliches Datum; Buch und Gegenstände rechnen „Nur dieser Charakter“ mit den eigenen Kosten; `mod:Cost` ohne Charakter = eingeloggter Charakter.

## 03.10.2026 – Markt-Schnäppchen nachgeschärft (Broker 0.26.0)

- Anlass (KarloDerBaer): „Abgefangene Kiste“ – Radar bot 55 Stück an, obwohl 323 Angebote im Markt lagen, der Absatz 0,0/Std. war und der Preis seit Tagen fiel.
- **Wiederverkauf höchstens zur Untergrenze des üblichen Bereichs** (KarloDerBaer, aus zwei Varianten gewählt). Ursprünglicher Vorschlag „höchstens der Vorschlag des Verkaufen-Reiters“ hätte nichts geändert: nach dem Kauf läge das günstigste Angebot im (sehr breiten) üblichen Bereich, Verkaufen schlüge dann denselben Preis vor. Bei ruhigen Märkten wird es dadurch etwas strenger (Untergrenze ≥ 5 % unter dem Richtwert).
- **Menge höchstens Absatz je Std. × 48 Std.** (KarloDerBaer; einstellbar). Nur Messungen ab gelbem ≈ zählen; rote oder fehlende Messung begrenzt nicht, zeigt aber einen Hinweis (KarloDerBaer: „erst ab gelb“).

## 03.10.2026 – Verlauf: zusammengehörige Vorgänge in einer Zeile (Ledger 0.8.1)

- Zusammengefasst werden feste Paare (Auktion eingestellt + Gebühr, Handel, Quest, Post an/von Twink) und Serien gleicher Art kurz hintereinander („Alle öffnen“, Händler, Korrekturen) – KarloDerBaer, aus Claudes Durchsicht der Daten und des Codes gewählt. Nur Anzeige; die Einträge bleiben einzeln gespeichert. Tagessummen und Abbruchkosten bleiben eigene Zeilen.

## 03.10.2026 – Darstellung Übersicht, Verlauf und Berufs-Box (Ledger 0.8.0, Broker 0.25.2)

- **Ledger-Übersicht:** Charakterliste auf 5 Zeilen verkleinert, darunter drei Blöcke Vermögen, Gewinn, Plätze (KarloDerBaer, aus zwei Vorschlägen gewählt).
- **Verlauf:** ein Herstellvorgang = eine Zeile mit Material grau dahinter, Einzelheiten im Tooltip (KarloDerBaer). Nur Anzeige, die Einträge bleiben einzeln gespeichert, damit Kosten und Buch unverändert rechnen.
- **Broker-Box am Berufsfenster** rückt automatisch hinter die Berufs-Symbolleiste statt eines festen Abstands (Claude), damit sie auch ohne Leiste direkt am Fenster sitzt.

## 03.10.2026 – Gebundenes im Vermögen zum Händlerpreis (Ledger 0.7.3)

- Seelengebundene Gegenstände (auch BoE nach dem Anlegen) kann man nur noch beim Händler verkaufen, also zählen sie im Vermögen nur mit dem Händlerpreis (KarloDerBaer). Angelegte Ausrüstung ist immer gebunden und zählt deshalb immer mit, ebenfalls zum Händlerpreis; die Option dafür entfällt (KarloDerBaer).

## 03.10.2026 – Post gehört erst beim Nehmen dazu (Ledger 0.7.2)

- Was im Briefkasten liegt, gehört noch nicht zum Bestand; Zugang erst beim Nehmen (KarloDerBaer). Ausnahme: Post an eigene Twinks bleibt als „Unterwegs“ beim Twink im Bestand, bis er sie abholt – sonst verschwände die Ware zwischenzeitlich (Vorschlag Claude, von KarloDerBaer bestätigt).

## 03.10.2026 – Post nicht mehr anzeigen (Broker 0.25.1, Ledger 0.7.1)

- Ohne Besuch am Briefkasten liefert das Spiel keinen Inhalt; Schätzungen aus Chatmeldungen („Käufer gefunden“) sind KarloDerBaer zu ungenau, und beim Öffnen wird die Post ohnehin geleert. Deshalb: Zeile „Post“ auf der Broker-Startseite und Post-Anzeige in der Ledger-Übersicht (Spalte, Gold in der Post, Post-Gold im Vermögen) entfernt. Die Erfassung beim Leeren bleibt (Buch, Kosten).

## 03.10.2026 – Ledger: Zuordnen (Kosten, Lagerwert und Handelsgewinn), Konzept `Peon_Ledger_Zuordnen.md`

- **Nachtrag (nach Rechenbeispiel):** **Älteste zuerst** (FIFO) statt Durchschnitt, damit gesammelte und gekaufte Ware getrennt bleiben (KarloDerBaer). Höchstens 30 Posten je Gegenstand, gleiche Zugänge am selben Tag zusammengefasst; Datenmenge üblich ~40 KB, viel ~500 KB – unkritisch. Tooltip zeigt Kosten des nächsten Stücks und den Durchschnitt.
- **Tooltip** (KarloDerBaer, bei der Umsetzung): Kosten ohne Umschalt und kompakt „Ledger  Kosten x (Ø y)“; Bestand und Orte rutschen unter Umschalt.
- **Begriffe** (KarloDerBaer): „Kosten“ statt „Einstand“, dazu „Lagerwert“, „Wareneinsatz“, „Handelsgewinn“, „Verbrauch“ – angelehnt an die Buchhaltung, aber ohne Fachjargon.

- Kostenlos Erhaltenes hat Einstand 0: Beute, Quests, Post von fremden Spielern und von Absendern ohne Nachname (NPCs, Systempost), Handel ohne Gegenleistung. Handel mit Gegenleistung bekommt den Gegenwert, Nachnahme-Post den bezahlten Betrag (KarloDerBaer).
- Anfangsbestand mit dem Marktpreis beim Start (Broker), sonst Händlerpreis.
- ~~Durchschnitts-Einstand~~ (durch Nachtrag ersetzt: älteste zuerst); accountweit je Realm; Post an/von Twinks ändert nichts.
- Einstellgebühren und Abbruchkosten werden dem Gegenstand zugerechnet.
- Benutzt/Zerstört = „Verbrauch“ (Info-Zeile im Buch), kein Verlust im Handelsgewinn.

## 03.10.2026 – Feedback-Liste und offene Punkte (Broker 0.24.0, Ledger 0.6.0, Feedback 0.2.0)

- **Meine Auktionen:** beim Öffnen des Reiters neu laden und automatisch live prüfen (KarloDerBaer).
- **Schnellkauf mit einem Klick:** Broker holt den Preis fürs beste Händler-Schnäppchen vorab beim Spiel, der Klick bestätigt sofort; ohne gültige Anfrage bleibt es bei zwei Klicks. Einzelgegenstände weiter ein Klick je Auktion (KarloDerBaer, Vorschlag Claude). Automatisches Bestätigen nach dem Klick wurde verworfen (Spiel blockiert es womöglich).
- **Radar „weg“ bei Gegenständen mit Zusatz:** statt aufzugeben Browse-Suche nach dem Grundnamen und Schlüssel des Spiels merken (Claude, aus dem Radar-Protokoll abgeleitet). Saubere Trennung der Zusatz-Varianten im Scan folgt, sobald `keyLog` zeigt, wie Forever den Zusatz im Schlüssel ablegt.
- **Händler-Knopf „Schnäppchen verkaufen“** entfernt (KarloDerBaer).
- **Startseite** als erster Reiter „Start“, am Auktionshaus öffnet das Fenster damit (KarloDerBaer).
- **Berufe:** Box am Berufsfenster (gewähltes Rezept, beste Rezepte) und Zeile im Tooltip; keine Spalte in der Rezeptliste (KarloDerBaer).
- **Einkaufsliste:** derselbe Umschalter „Vorrat aller Charaktere“ wie im Reiter Behalten (KarloDerBaer); Verkaufen zeigt die eigene Verkaufsquote.
- **Gestrichen als erledigt:** Abverkauf (= Absatz 0.23) und Vorschlag bei stark schwankenden Preisen (= Richtwert 0.21) (KarloDerBaer).
- **Ledger „Inventur neu“** nur für den eingeloggten Charakter; Unterschiede als „Korrektur“ (Umbuchung, zählt nicht als Gewinn) (KarloDerBaer).
- **Ledger-Lücken** alle drei geschlossen (KarloDerBaer): Erlös ohne Rechnung wird dem Verkauf zugeordnet, Auktionskauf in einer Zeile, Händlergold nach Händlerwert aufgeteilt.
- **Feedback:** Löschen links, Bearbeiten Mitte (eigenes Fenster), OK rechts (KarloDerBaer).

## 03.10.2026 – Absatzquote (Broker): Konzept `Peon_Broker_Absatz.md`

- **Nachtrag nach dem ersten Test (Broker 0.23.1, KarloDerBaer):** Angezeigt wird der **aktuelle Absatz je Stunde** (letzte 6 Std.), der 14-Tage-Wert ist nur intern. Sicherheit nach beobachteter Zeit; das Zeichen „≈“ steht **immer** da (ganz genau ist es nie) und ist rot (wenig Daten), gelb (besser), grün (gut) – grau war kaum erkennbar. Die Reichweite gehört nicht in den Tooltip, nur zum Verkaufen.
- Komplettscan gleich mit auswerten, nicht erst später (KarloDerBaer).
- Anzeige ab dem ersten Vergleich zweier Abfragen/Scans; Sicherheit farbig in drei Stufen nach Zahl der Vergleiche, Schwellen in den Optionen (KarloDerBaer). Zeitraum 14 Tage.
- Abbruch-Regel (Vorschlag KarloDerBaer): Fehlt ein Angebot vor Ablauf, obwohl ein günstigeres in beiden Abfragen/Scans unverändert stand, wurde es abgebrochen – für Massenware sicher, weil das Spiel beim Kauf immer die günstigsten Stücke zuerst nimmt; bei Einzelgegenständen „wahrscheinlich“.
- Anzeige: Tooltip mit Umschalt, Hinweis beim Verkaufen, Spalte in „Preise“.
- Einzelgegenstände (Zusätze, sehr unterschiedliche Preise): Abbruch-Regel gilt nicht; verschwunden vor Ablauf = gekauft, abzüglich einstellbarem Schätzwert für Abbrüche (Standard 10 %) (KarloDerBaer).
- Sicherheit nicht als Farbe der Zahl, sondern als Zeichen „≈“ davor (grau unsicher, gelb mittel, ohne Zeichen sicher); die Farbe der Zahl bleibt für viel/wenig Absatz (KarloDerBaer).

## 03.10.2026 – L6: Vorrat im Reiter „Behalten“, Verkaufsquote und Absatzquote getrennt

- **Behalten** (Broker) bekommt den Vorrat aus Ledger, mit **Umschalter im Reiter**: nur dieser Charakter / alle Charaktere (KarloDerBaer). Ohne Ledger wie bisher (Taschen + Bank).
- **Zwei getrennte Werte** (KarloDerBaer): **Verkaufsquote** = eigene Verkäufe (Ledger: verkauft ÷ (verkauft + zurück)); **Absatzquote** = was der Markt umsetzt, ermittelt Broker aus seinen Scans/Abfragen. Wie beide kombiniert werden, wird später entschieden.
- Offen: ob die Absatzquote über die Auktionsnummern (auctionID) und die Restlaufzeit genauer wird – erst prüfen, was Forever bei den Abfragen liefert.

## 03.10.2026 – Ledger: kein eigener Post-Knopf (L4), Buch zurücksetzen, Buch ohne Broker-Altdaten

- **L4 „Post einsammeln“ entfällt** (KarloDerBaer): Ledger erfasst die Post auch beim Blizzard-Knopf „Alle öffnen“ zuverlässig (seit 0.3.1 mit Brief-Warteschlange und Abgleich Post ↔ Taschen); ein eigener Knopf bringt keinen Mehrwert. Die Rechnungen (Erlös, Anteil, Menge) werden beim Holen gelesen.
- **Knopf „Buch zurücksetzen“** in den Optionen (KarloDerBaer): Verlauf und Wochensummen des Realms löschen, aktuellen Stand neu lesen, er wird der neue Anfangsbestand.
- **Brokers alte Listen** (eingestellt, abgebrochen, gekauft) werden **nicht** ins Buch übernommen (Vorschlag Claude bei L5): Sie haben keinen Charakter und keine Verkäufe, und KarloDerBaer fängt mit dem Zurücksetzen bei null an. Lässt sich später nachholen.
- **Buch:** Gewinn = Einnahmen − Ausgaben − Gebühren, nur Gold, Umbuchungen zählen nicht. Auktionshaus-Verkäufe mit dem erhaltenen Betrag (Anteil schon abgezogen, zur Info angezeigt); Gebühren = gezahlte Einstellgebühren und Abbruchkosten.
- **Verkaufsquote** = verkauft ÷ (verkauft + zurück) in Stück, 30 Tage, ab 3 Stück. Verkauft aus den Rechnungen (Menge), zurück aus den Briefen „abgelaufen/abgebrochen“. Verschwindet eine Auktion ohne „verkauft“, gibt es keinen Eintrag mehr („Auktion beendet“ bis 0.3.2) – der Brief entscheidet.

## 02.10.2026 – Neues Modul Peon_Ledger (Bestand und Buch)

- Post einsammeln und Buch wachsen über das Auktionshaus hinaus: KarloDerBaer möchte alles erfassen (auch Herstellen, Verbrauch, Händler, Handel, Post, Zerstören; Rest „verbraucht/sonstiges“), einen Ist-Zustand zu Beginn und die Bestände der Twinks wie in Taschen-Addons.
- Deshalb eigenes Modul **Peon_Ledger** mit Bestand, Bewegungen, Gold, Post einsammeln und Buch. Broker liest daraus nur (Vorrat aller Charaktere, Verkaufsquote), abgesichert, beide laufen auch allein. Verworfen: alles in Broker (zu groß) und „Bestand neu, Buch in Broker“ (Schnittstelle in beide Richtungen).
- Name: Peon_Ledger (KarloDerBaer).
- Konzept abgestimmt: Brokers Reiter „Buch“ entfällt, Ledger bekommt eigenen Minimap-Button; angelegte Ausrüstung zählt zum Bestand; Vermögen mit dem Wert aus Zeile 1 des Broker-Tooltips; Tooltip kurz, Aufteilung mit Umschalt; Beute-Gold je Tag zusammengefasst; Erfassung nur ereignisgesteuert (nur geänderte Taschen nach `BAG_UPDATE_DELAYED`, Auswertung im Kampf erst danach), kein regelmäßiger Scan.
- Übernommen aus der Broker-Abstimmung: nur Auktionshaus-Post, nur per Knopf; 90 Tage einzeln, danach Wochensummen; Gewinn zuerst je Zeitraum, „Zuordnen“ (Einstand) später, Daten dafür von Anfang an.

## 02.10.2026 – Richtwert und üblicher Bereich (Broker 0.21.0)

- Preisfindung nach Börsen-Vorbild (gleitender Mittelwert mit Schwankungsband, robuste Maße), ausgearbeitet als Rechenmodell Kapitel 7 und mit KarloDerBaer abgestimmt: 14 Tage, Halbwertszeit 3 Tage, Bereich fest 1 × Schwankung; die 30-%-Dumping-Grenze bleibt nur als Rückfall unter 3 Tageswerten.
- Radar nutzt den Richtwert für Markt-Schnäppchen; fällt der Markt, gibt es keine Markt-Schnäppchen.
- Zeile 1 im Tooltip zeigt das günstigste Angebot (so wird eingestellt) statt des Vorschlags, mit Farbe der Marktlage: grün gut, orange Markt fällt, rot Dumping. Händlerpreis weiter, wenn der Händler mehr zahlt.
- Weitere Methoden für später: Verkaufspreis-Schätzung aus verschwundenen Angeboten (beim Abverkauf), Erwartungswert aus Verkaufsquote (mit dem Buch).

## 02.10.2026 – Broker nach dem Vergleich mit anderen AH-Addons (Broker 0.20.0)

- Vergleich mit Auctionator, TSM, Journalator, Auctioneer und aux: Broker hat die meisten Werkzeuge, ihm fehlt ein roter Faden. Beschlossen (Reihenfolge offen): Buch mit Verkaufsquote, Post einsammeln (sehr wichtig), Startseite „Was steht an?“, Abverkauf (wenn realistisch schätzbar), Herstellkosten bei Berufen, Bestände anderer Charaktere. Nicht gebraucht: Tastenbelegungen (Knopf reicht), Preisgrenzen je Gegenstand (Händlerpreis als Untergrenze reicht), Verkaufs-Durchlauf.
- Verkaufen: eingetragen wird immer das günstigste Angebot minus Unterbieten, auch bei Dumping; der Vorschlag bleibt als Richtwert mit Hinweis (Wunsch von KarloDerBaer). Untergrenze bleibt der Mindestpreis (Händler).
- Radar: weggefallene Treffer bleiben 30 Sek. grau mit Grund in der Liste und kommen ins Radar-Protokoll – damit ist sichtbar, ob ein Treffer wirklich weg ist oder ein Fehler vorliegt.
- Radar pausiert, solange ein Treffer gewählt ist, weil jede fremde Suche die Anzeige im Blizzard-Fenster verändert; nochmal anklicken hebt die Auswahl auf.
- Broker schaltet das Blizzard-Fenster beim Reiterwechsel passend um (Auktionen / Kaufen / Verkaufsfenster) und zeigt beim Klick auf eine eigene Auktion deren aktuelle Angebote.

## 02.10.2026 – Neues Modul Peon_Feedback, Kern API 9 (Peon 0.9.0, Feedback 0.1.0)

- Rückmeldungen (Fehler, Verbesserung, Neue Idee, Sonstiges) werden im Spiel in einem eigenen Modul gesammelt, accountweit in `PeonFeedbackDB`, mit Modul, Bereich, Priorität (Standard Mittel) und automatisch Charakter, Markt, Zone und Version des Moduls.
- Die Bereiche gehören dem jeweiligen Modul: Es meldet sie selbst über die Kern-Erweiterung `Peon.SetFeedbackAreas` (API 9, Schlüssel = Addon-Name). Feedback braucht so keine Modul-Interna; jedes Modul hängt mit einer Zeile an, abgesichert per `if` für ältere Kerne. „Sonstiges“ gibt es immer.
- Lieferungen aus dem Chat kommen als Zip mit `EINBAU.md` in `eingang\`; in Cowork werden sie gegen den echten Kern getestet und erst dann eingebaut. Dafür gibt es neben dem mitgelieferten Test (Kern-Nachbau) einen zweiten Test gegen den echten Kern.
- Kleine Korrekturen beim Einbau statt Rückfrage (Listenbreite, Wertebereich Minimap-Winkel, Hinweistext), weil sie nur Darstellung und Text betreffen.

## 01.10.2026 – Radar-Überarbeitung (Broker 0.19.0, Peon 0.8.0)

- Eine Gewinn-Spalte: höchster Gewinn mit meinem Gold (abzüglich Goldreserve), nicht der Gewinn des ganzen Schnäppchens. Sortierung, Mindestgewinn und Schnellkauf richten sich danach; was sich mit meinem Gold nicht lohnt, wird wie Unbezahlbares behandelt.
- Schnellkauf nur für Händler-Schnäppchen: kauft alles, was ich mir leisten kann (Massenware zwei Klicks, Einzelgegenstände ein Klick je Auktion).
- Neue Treffer: Zeile pulsiert (einstellbar, Standard 5 Sek.), dazu der grüne Punkt (als eigenes Bild); Warnton wählbar wie bei Fishing.
- Händlerware, die der Radar kauft, wird je Charakter gemerkt und am Händler per Knopf verkauft (nur diese, nie mehr als gekauft). Goldreserve und „Alle wieder zeigen“ übernommen; Taschenplatz-Prüfung entfällt (Ware kommt per Post).
- Kern API 8: Zeilenfarbe in der Liste (Erweiterung, bestehende Aufrufe unverändert).

## 30.09.2026 – Kaufzeile und Ausblenden (Broker 0.18.0)

- KarloDerBaer schaut sich jedes Angebot an: Schnellkauf-Knöpfe für das „beste“ Angebot entfallen; gekauft wird über die Kaufzeile des gewählten Treffers (1 Stück / bis ein Stapel / alle), jeweils mit Kosten und Gewinn für genau diese Menge und Hinweis, ab welcher Menge sich der Kauf lohnt.
- Ausblenden per Rechtsklick für alle Charaktere je Markt. Es gilt, bis eine Prüfung zeigt, dass kein Schnäppchen mehr vorliegt; wird es danach wieder eins, erscheint es wieder. So bleiben Gegenstände im freien Fall weg, ohne dauerhaft verloren zu gehen.

## 30.09.2026 – Markt-Schnäppchen und Kaufen je Stück (Broker 0.17.0)

- Markt-Schnäppchen: Wiederverkauf gegen das nächste Angebot nach dem Kauf statt gegen den Median; zusätzlich Mindestmarge je Stück (20 %) und höchstens 20 % des Angebots – viel billige Ware ist kein Dumping, sondern ein verschobener Preis.
- Gewinn wird je Stück und je Stapel (Stapelgröße des Spiels) gezeigt; „bestes“ Angebot und Sortierung nach Gewinn je Stück.
- Kaufen nur noch je Stück oder je Stapel, der Knopf zeigt den Preis genau dieses Kaufs.
- Radar: Auswahl Händler/AH/beide; was ich mir nicht leisten kann, wird standardmäßig ausgeblendet (einstellbar).

## 30.09.2026 – Radar-Bedienung (Broker 0.16.0)

- Reihenfolge des Radar-Scans im Reiter wählbar (smart, zufällig, Massenware zuerst, höchster/niedrigster Preis); Einkaufslisten und Treffer bleiben immer vorne.
- „Nur Warnton“ standardmäßig an: während des Scans nur der Gesamt-Kanal hörbar, auch im Hintergrund; wird immer zurückgesetzt (auch nach Reload/Absturz).
- Zähler-Zeile nicht mehr sichtbar, stattdessen der gerade geprüfte Gegenstand.

## 30.09.2026 – Live-Daten im aktuellen Stand (Broker 0.15.0)

- Live-Abfragen liefern für einen Gegenstand alle aktuellen Angebote und schreiben deshalb den aktuellen Stand (Min, Median, Menge, Preisstufen, „weg“) in die Datenbank – Vorschlag von KarloDerBaer.
- Verlauf (Tages-/Wochenwerte), Anzahl Scans (Datenlage) und Trend bleiben reine Scan-Werte, damit die Datenlage aussagekräftig bleibt und Trends nicht springen.
- Radar zeigt beim Öffnen alle Schnäppchen aus der Datenbank bis 60 Minuten (einstellbar, 0 = unbegrenzt) und prüft jedes einmal; ersetzt die 5-Minuten-Regel.

## 30.09.2026 – Reiter „Einkaufsliste“ und „Radar“ (Broker 0.14.0)

- Einkaufslisten und Schnäppchen sind eigene Reiter unten; „Schnäppchen“ heißt jetzt **Radar**.
- Radar: zwei Knöpfe „Bestes kaufen“ (Händler / AH), ab 0.14.1 mit dem Preis nur dieses einen Kaufs (vorher „alle kaufen“ mit Gesamtkosten – irreführend, weil je Klick nur ein Angebot gekauft wird). Ein Klick = ein Kauf, höchster Gewinn zuerst. Vor jedem Kauf wird geprüft, ob das Angebot noch da und noch so günstig ist (Massenware: Preis vom Spiel, bei höherem Preis Abbruch; Einzelgegenstand: frische Live-Abfrage, höchstens 10 Sek. alt).
- Radar-Scan: kein Vollscan, sondern laufend Einzelabfragen knapp unter der Grenze des Spiels (etwa 92 pro Minute), nur solange der Reiter offen ist. Reihenfolge: Treffer (spätestens alle 15 Sek. nachgeprüft), Einkaufslisten, Gegenstände mit den besten Chancen.
- 5-Minuten-Regel nur beim Öffnen des Reiters: Treffer aus einem höchstens 5 Min. alten vollen Scan werden angezeigt und sofort einmal live geprüft (auch ohne Radar-Scan); was weg ist, verschwindet gleich.
- Neue Treffer: Ton (abschaltbar) und grüne Hervorhebung, nur im Reiter.

## 30.09.2026 – Reiter „Einkaufen“ (Broker 0.13.0)

- Zwei Teile: Einkaufslisten und Schnäppchen (statt nur Händler-Schnäppchen auch Markt-/Dump-Angebote).
- Kaufansicht im Blizzard-Fenster, zusätzlich Knopf „Kaufen“ in Broker (mit Rückfrage und Preis vom Spiel).
- Einkaufslisten je Charakter; Höchstpreis = x % unter dem 7-Tage-Median, x einmal je Liste.
- Markt-Schnäppchen nur ab 50s möglichem Gewinn und bei mindestens 10 Scans in 7 Tagen; alle Schnäppchen nur bis 5 Minuten nach dem Scan (einstellbar), sonst sind viele Angebote schon weg.

## 30.09.2026 – Reiter „Meine Auktionen“ (Broker 0.12.0)

- Eine breite Liste mit Status (günstigster, gleichauf, unterboten, verkauft); unterbotene zuerst.
- Vergleich zuerst mit dem letzten Scan; „Live prüfen“ nur auf Knopfdruck, damit die Abfragegrenze für „Verkaufen“ frei bleibt.
- Abbrechen mit Anzeige der Kosten, „Nächste unterbotene“ je Klick; „Neu einstellen“ springt zu „Verkaufen“.
- Abgelaufene Auktionen erscheinen nicht in der Liste (das Spiel meldet sie nur per Post), sie kommen ins Buch.

## 30.09.2026 – Reiter „Behalten“ (Broker 0.11.0)

- Name des Reiters: „Behalten“, direkt hinter „Verkaufen“.
- Optionale Menge je Gegenstand; im Reiter „Verkaufen“ erscheint nur, was darüber liegt.
- Vorrat zählt Taschen und Bank (die Bank-Menge liefert das Spiel auch bei geschlossener Bank). Im Reiter die Spalten Vorrat (hervorgehoben), Taschen und Bank.
- „Behalten“ steht auch im Tooltip (eigene Zeile unter Zeile 1, nur aktueller Charakter).

## 30.09.2026 – Verkaufen über das Auktionshaus-Fenster, „nicht verkaufen“ (Broker 0.10.0)

- Der gewählte Gegenstand wird ins Verkaufsfenster des Auktionshauses gelegt, Brokers Werte werden dort eingetragen. Eingestellt wird mit den Werten, die dort stehen (Broker drückt dessen Knopf); die Eingabefelder in Broker entfallen.
- Linke Spalte schmal, Knöpfe übereinander; rechte Spalte breiter mit Trend (wie Zeile 1 im Tooltip).
- „Nicht verkaufen“ je Charakter (eigene Einstellungsdatei `PeonBrokerCharDB`), per Rechtsklick in der Liste und per Knopf links über „Auktion erstellen“. Kein Umbau des Listen-Bausteins im Kern nötig.
- Zum Verwalten der markierten Gegenstände kommt ein eigener Reiter.

## 30.09.2026 – Layout „Verkaufen“ wie Blizzard (Broker 0.9.0)

- Das Broker-Fenster orientiert sich am Blizzard-Auktionshaus: gleicher Rahmen, Reiter unten.
- „Verkaufen“ zweispaltig: links die Einstellungen im Aufbau des Blizzard-Fensters „Auktion erstellen“, rechts die Taschen mit kleinem Symbol vor dem Namen.
- Die aktuellen Angebote zeigt Broker nicht an (die stehen im Blizzard-Fenster); sie werden nur im Hintergrund für den Vorschlag abgefragt.
- Händlerpreis nur noch als Hinweis, wenn der Händler mehr zahlt; zum Vorschlag nur ein Stichwort, der ausführliche Grund beim Überfahren.

## 30.09.2026 – Reiter „Verkaufen“ (Broker 0.8.0)

- Zuerst im Spiel weiter, weil Broker ohne Programm funktionieren muss. Das Programm-Konzept bleibt als Entwurf liegen.
- Entwurf `Peon_Broker_Verkaufen.md` komplett angenommen: Taschenliste links, Live-Abgleich und Verkaufsfeld rechts, „Einstellen & weiter“, Alt+Klick in den Taschen.
- Beim Verkaufen gilt der Live-Preis (Rechenmodell Kapitel 4). Eigene Angebote werden nicht unterboten; ist man schon günstigster, bleibt der eigene Preis.
- Laufzeit Standard 8 Std.; Massenware ab 20 Angeboten 2 Std. (einstellbar); von Hand gewählte Laufzeit und Menge werden je Gegenstand gemerkt, der Preis nicht.
- Mehrere Stapel: Massenware wird als Gesamtmenge eingestellt (keine Stapel mehr im modernen Auktionshaus), Einzelgegenstände als Anzahl Auktionen.
- Einstellen nur per Klick, nie im Kampf; Rückfrage bei Preis weit unter dem Vorschlag und wenn das Spiel selbst nachfragt.
- Am Auktionshaus öffnet das Broker-Fenster mit dem Reiter „Verkaufen“, sonst mit dem zuletzt gewählten.

## 30.09.2026 – Begleitprogramm für Broker (Grundsätze)

- Broker bekommt ein Programm auf dem PC für die Langzeitdaten. Im Spiel geht es um Handeln (verkaufen, kaufen, eigene Auktionen) und eine schnelle Übersicht. Konzept: `Peon_Broker_Programm.md`.
- Broker funktioniert auch ohne Programm voll. Die Werte des Programms (Preisbereiche) verbessern nur die Einschätzung.
- Austausch nur über Dateien: WTF-Datei (Spiel → Programm, geschrieben bei Reload/Ausloggen/Beenden) und eine Datendatei, die das Spiel beim Start/Reload liest. Reload ist akzeptiert, Kopieren und Einfügen von Texten ist ausgeschlossen.
- Das Programm arbeitet mit Schnappschüssen aus beliebigen Quellen: jetzt Scans aus dem Spiel, später vielleicht die Blizzard-API.
- Ziel: Broker fertig zum Release. Datenverlust während der Beta ist nicht schlimm.

## 30.09.2026 – Broker-Fenster und Einstellgebühr (Broker 0.6.2 / 0.7.0)

- Einstellgebühr: Das Spiel rechnet 5 % vom Händlerwert des Stapels, rundet ab und nimmt das mal 1/4/12 für 2/8/24 Std. Belegt durch den automatischen Abgleich im Spiel (17 von 17 Beispielen). Ersetzt die Annahme „5/20/60 %“.
- Das Broker-Fenster ist vorerst Teil von Peon_Broker, kein Kern-Baustein. Es kann in den Kern wandern, falls ein weiteres Modul ein Fenster mit Reitern braucht.
- Alle fünf Reiter aus dem Konzept sind sichtbar. Noch nicht gebaute Reiter sind gesperrt und zeigen „Folgt in einer späteren Version“.
- Andocken: Bei offenem Auktionshaus hängt das Fenster rechts daneben und schließt mit ihm. Ohne Auktionshaus ist es frei verschiebbar, die Position wird gemerkt.
- Das Fenster öffnet sich nicht von selbst mit dem Auktionshaus (Standard aus, einstellbar), solange nur der Reiter „Preise“ fertig ist.
- Der Scan merkt sich Name und Qualität jedes Gegenstands, damit die Suche ohne Nachladen vom Spiel funktioniert. Einträge von 0.6 bekommen den Namen beim nächsten Scan, bis dahin kommt er vom Spiel (falls geladen).
- Bedienung: `/broker` und Linksklick auf den Minimap-Button öffnen das Fenster. Rechtsklick und `/broker optionen` öffnen die Einstellungen.

## 30.09.2026 – Rechenmodell für Broker abgestimmt (Grundlage für 0.6.0)

- Vor dem Weiterprogrammieren wurde das System „auf dem Papier“ aufgebaut: `Peon_Broker_Rechenmodell.md` (Begriffe, Formeln F1–F20, Tooltip-Anzeige), mit KarloDerBaer Punkt für Punkt abgestimmt.
- Wichtigste Änderungen gegenüber 0.5.1: Median statt „Durchschnitt der günstigsten 25 %“; Tageswerte = Mittel aller Scans des Tages; 7-Tage-Werte gleitend (heute eingeschlossen), Trend gegenüber Vortag; Abverkauf gestrichen (bei Massenware nicht messbar, fremde Verkäufe meldet das Spiel nicht); Einstellgebühr kommt bei Verkauf zurück und wird nicht mehr vom Erlös abgezogen, sondern aus Händlerpreis × Satz (2/8/24 Std.: 5/20/60 %) berechnet; Unterbieten getrennt für Massenware (Standard 0) und Einzelgegenstände (1c); Vergleichspreis = aktueller Median; bei Dumping Basis = Mitte zwischen Dumping-Grenze und Median.
- Blizzard-API: liefert keine Forever-Auktionsdaten; eine geplante Aufgabe („Forever-API prüfen“, täglich 8:58) meldet Änderungen. Ein Zusatzprogramm auf dem PC kommt für KarloDerBaer grundsätzlich in Frage.

## 29.09.2026 – Tooltip kompakter (Broker 0.5.0)

- Zeile 1 zeigt nur den besseren Wert („AH: …“ oder „Händler: …“), kein Wort „Erlös“ mehr.
- Standard ist der ganze Stapel; Umschalt schaltet nicht mehr Stück/Stapel um, sondern blendet die Detailzeilen ein. Dezenter Hinweis „(Umschalt)“ in Zeile 1.
- Trend-Symbole: gleich = dezent blauer Balken (gelber Punkt sah wie Gold aus); stark gestiegen dunkelgrün, gestiegen hellgrün, gefallen orange, stark gefallen rot. Vor dem Einbau als Bild mit KarloDerBaer abgestimmt.

## 29.09.2026 – Tooltip nach KarloDerBaers Aufbau, Trends, Abverkauf (Broker 0.4.0)

- Markt = Regelsatz + Fraktion: alle Charaktere dort teilen die Daten (accountweit). Bestätigt mit KarloDerBaer.
- Tooltip-Aufbau von KarloDerBaer: Erlös (mit Unterbieten, 5 % Anteil und Einstellgebühr), Angebote, AH Min/Ø, 7 Tage Min/Ø, Hinweise. Händlerpreis klein unter den Hinweisen. Werte je Stück, Umschalt = Stapel.
- Trend in fünf Stufen (KarloDerBaer): gerade Pfeile für starke, schräge für normale Änderungen, gelber Punkt für gleich; eigene Symbolbilder, weil die Spielschrift keine schrägen Pfeile hat. Grenzen 5 % / 20 % einstellbar.
- 7-Tage-Werte: Mittel der täglichen Tiefst- bzw. typischen Preise; Trend gegenüber den 7 Tagen davor.
- Abverkauf je Stunde als Schätzung (das Spiel meldet fremde Verkäufe nicht): Vergleich der günstigsten 20 Preisstufen zweier Scans (höchstens 24 Std. auseinander), Angebote kurz vor Ablauf ausgenommen. Abgebrochene Angebote zählen mit – ist als „ca.“ gekennzeichnet.
- Einstellgebühr außerhalb des Auktionshauses unbekannt: Broker merkt sie sich je Gegenstand, sobald er sie abfragen konnte; bis dahin „~“ vor dem Erlös.
- Tageswerte mindestens 14 Tage (sonst kein 7-Tage-Trend).

## 29.09.2026 – Preisdatenbank und Scan (Broker 0.3.0)

- Daten je Markt unter `PeonBrokerDB.markets["Realm / Fraktion"]`; Tooltip und Auswertung lesen nur den aktuellen Markt.
- Gegenstands-Schlüssel: itemID; bei Ausrüstung mit Zusatz „itemID:suffixID“, damit „… des Bären“ und „… des Affen“ nicht vermischt werden.
- Typischer Preis = Durchschnitt der günstigsten 25 % der angebotenen Menge (Mondpreise zählen nicht).
- Verlauf als kompakter Text (ein Eintrag je Tag, später je Woche), damit die Einstellungsdatei klein bleibt.
- Tooltip zeigt nichts bei Gegenständen ohne Daten (keine Störung bei Quest- oder gebundenen Sachen); nur ohne jeden Scan im Markt ein kurzer Hinweis.
- Die 15-Minuten-Sperre zählt Broker selbst mit (das Spiel verrät sie nicht); ein abgebrochener Scan verbraucht sie trotzdem.

## 29.09.2026 – Kern API 7: Liste und Minimap-Button (Peon 0.7.0, Broker 0.2.0)

- Neue Bausteine in eigenen Dateien (List.lua, Minimap.lua), bestehende Funktionen unverändert. `Widgets.lua` gibt dafür nur zusätzlich `Peon.PagePrototype` heraus.
- Liste ohne Blizzard-Vorlagen für Bildlauf (eigener Regler), damit sie im Forever-Client sicher läuft. Leere Werte stehen beim Sortieren immer unten.
- Minimap-Button nach dem Vorbild von Fishing. Fishing behält vorerst seinen eigenen Button (eigenes Rechtsklick-Menü); eine Umstellung wäre eine eigene Entscheidung.
- Broker nutzt beides schon jetzt (Minimap-Button, Ereignis-Liste), damit die Bausteine im Spiel getestet werden, bevor das Broker-Fenster kommt.

## 29.09.2026 – Neues Modul Peon_Broker (Konzept freigegeben, Broker 0.1.0)

- Broker ist der Auktionshaus-Helfer von Peon und ersetzt Auctionator vollständig. Konzept in `Peon_Broker_Konzept.md`.
- Eigenes Broker-Fenster (dockt am Auktionshaus an) statt Reiter im Blizzard-Fenster.
- Märkte strikt getrennt: Markt = Realm-Name (Regelsatz) + Fraktion. Der Nachname der Charaktere (z. B. Mirel Dorna) gehört nicht zum Markt.
- Preisvorschlag: günstigstes Angebot minus Unterbieten (einstellbar, Standard 1 Kupfer); bei unrealistisch tiefem Angebot Warnung und Durchschnitt minus Unterbieten; Untergrenze immer „Erlös nach Einstellgebühr und Verkaufsanteil ≥ Händlerpreis“.
- Buch über Käufe und Verkäufe und Minimap-Button gehören zu Stufe 1; der Minimap-Button wird als Baustein im Kern gebaut (API 7), Fishing behält vorerst seinen eigenen.
- Erster Bauabschnitt ist ein reiner Prüfbefehl, weil die Online-Angaben zur Forever-Auktionshaus-Schnittstelle ungenau sind. Er ruft nur lesende Funktionen auf (und `ReplicateItems` nur auf Knopfdruck).

## 29.09.2026 – Auswahllisten statt Knopfreihen (Peon 0.6.0, Fishing 1.5.0, Tooltip 0.5.2)

- KarloDerBaer bevorzugt Auswahllisten (Dropdown), wenn aus mehreren Möglichkeiten gewählt wird. Kern bekommt dafür `page:Dropdown` (API 6). Ersetzt die Entscheidung von 0.5.0, keinen Dropdown in den Kern aufzunehmen.
- Ausnahme: Positionen bleiben Knopfreihen/Raster (Tooltip-Position, PvP- und Quest-Symbol), weil man die Lage sofort sieht.
- Umgestellt: Fishing (Angel-Set, Markierung, Warnton, nach dem Kampf), Tooltip (Rahmenfarbe, Kampfmodus), Vorlage (Modus).

## 29.09.2026 – Fishing-Optionen auf Kern-Bausteine (Peon 0.5.0, Fishing 1.4.0)

- Kern um API 5 erweitert statt Fishing eigene Bausteine behalten zu lassen: Button, Text, Check mit Hinweis und eigenen an/aus-Werten, Neuanordnung beim Refresh, `keepOnReset`. Bestehende Aufrufe unverändert.
- ~~Keine Auswahlliste (Dropdown) im Kern~~ – mit 0.6.0 aufgehoben (siehe oben).
- Neue Anordnung der Fishing-Seite mit Überschrift „Schwimmer-Erkennung“; Tonmix-Regler werden ohne Tonmix ausgegraut.
- Neuer Knopf „Standardwerte“ für Fishing; Angel-Set, Zustand, Köder, Minimap-Position und Fänge bleiben erhalten.

## 29.09.2026 – Projektorganisation

- Projektdateien (Überblick, Stand, Entscheidungen, Tests, Werkzeuge, Vorlage) liegen in `<Repo>`, zusätzlich im Claude-Projekt. Im AddOns-Ordner nur Addon-Code; der alte Ordner „Claude outputs“ mit einer veralteten Kopie des Überblicks wurde gelöscht.
- Lua 5.1.5 liegt als fertige Programmdatei in `tools\` (Windows und Cowork). Tests laufen damit direkt auf den echten Dateien, ohne Übertragung in die Cloud.
- Modultests lesen die Version aus der TOC statt fester Werte.
- Neue Module starten aus `vorlage\Peon_Beispiel`.
- Die alten „Offenen Ideen“ (Gatherer, Auctionator, Minimap-Button im Kern, Fishing-Optionen umstellen, Tooltip-Ideen) wurden aus den Unterlagen genommen; KarloDerBaer gibt Ideen einzeln vor.

## Bis 29.09.2026 – Grundlagen (aus dem Überblick übernommen)

- **Aufbau:** Kern-Addon heißt „Peon“ (ohne „_Core“), Module sind eigene Addons `Peon_<Funktion>` mit `## Dependencies: Peon` und `## Group: Peon`. TOC-Titel `|cff8ccf4dPeon|r <Name>`, eigenes Icon.
- **Kern-API wird nur erweitert, nie geändert**; bei neuen Funktionen `Peon.API` erhöhen (derzeit 4).
- **Umbenennung auf Peon_*:** TooltipPlus → Peon_Tooltip, Combo Point Display → Peon_ComboPoints, FishingPlus → Peon_Fishing. Einstellungen über `oldDB`/`oldCharDB` übernommen, alte Namen eine Version lang in der TOC, danach entfernt. Abgeschlossen: keine alten Namen mehr in Code, TOC und WTF.
- **Tastenbelegungen umbenannt** (FISHINGPLUS_* → PEON_FISHING_*), alte Namen eine Version versteckt behalten und beim Login umgelegt; Gamepad-Tasten direkt in `bindings-cache.wtf` umbenannt. Abgeschlossen.
- **Geheime Werte:** nie vergleichen, rechnen oder als Schlüssel nutzen; immer `Peon.IsSecret()` prüfen. Combo-Punkte über StatusBars, Träger über Nameplate-Rahmen statt GUID.
- **Geschützte Aktionen** (Köder anlegen, Auswerfen) nie automatisch, nur per Tastendruck/Klick des Spielers.
- **Einstellungen:** Einstellungen > AddOns > Peon mit Unterseite je Modul; Seiten spätestens bei INIT anmelden.
- **Texte:** deutsch (deDE) und englisch (enUS), verständlich ohne Fachjargon.
