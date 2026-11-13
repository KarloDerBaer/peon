# Peon Manager: Konzept Chancen und Prognosen

Stand: 13.11.2026, **Entwurf, noch nicht freigegeben.** Ausgearbeitet von Claude aus den Vorgaben von KarloDerBaer vom 13.11.2026. Das Konzept ist Teil 2 (Chancen im Manager) und Teil 3 (Daten für Broker) der Angleichung (`Peon_Manager_Angleichung.md`, Abschnitt 10). Ausgangsversionen Manager 0.33.0, Broker 0.92.0, Bridge 0.10.0.

## 1. Ausgangslage

Grundsatz (KarloDerBaer, 13.11.2026): **Der Manager übernimmt, was das Spiel nicht kann.** Das Radar arbeitet im Spiel mit Live-Daten und wird im Manager nicht nachgebaut. Der Manager arbeitet vor allem mit den Ständen der Blizzard-API, die höchstens einmal je Stunde kommen. Er bleibt deshalb bei **Chancen**, die über Stunden oder Tage gelten, und bei **Prognosen**. Die Chancen gehen an Broker, wo das Radar die Art **Spekulation** bekommt.

### 1.1 Was es schon gibt

- **Manager** (`manager\src\core\chances.js`): Aufkauf, Wiederverkauf (F50 bis F50c), Händler (F51), Fallend und Steigend (F52), Lohnend (F53), neues Preisniveau (F54), Trefferquote nur für den Wiederverkauf (F55). Der Aufkauf rechnet noch nach Broker 0.65. Die Seite Radar steht seit 0.32.0 auf WIP.
- **Absatz** (`manager\src\core\sales.js`): API-Stände werden über die Angebotsnummern verglichen. Je Gegenstand und Tag gibt es verkauft, abgelaufen, abgebrochen, neu eingestellt, Summe der Verkaufswerte und den höchsten Verkaufspreis. **Einzelne Verkaufspreise werden nicht gespeichert**, nur ihr Mittel und das Maximum.
- **Broker**: Radar mit Aufkauf und Händler, „Spekulation (kommt später)“ ist schon in den Einstellungen vorgesehen (`L.SET_RADAR_SPEC`). Einschätzungen einer Chance (`Rating.lua`, ab 0.91) werden mit allen Werten des Moments gespeichert, die Auswertung im Manager ist offen.
- **Gegenstandsdaten** der API (`item-info.js`) liefern unter anderem die benötigte Stufe. Abgerufen werden sie bisher nur für Gegenstände, die man im Manager ansieht.

### 1.2 Befund aus den Daten

Auswertung der Broker-Daten im Heimatmarkt (Allianz, 55 eigene Scans, Stand 13.11.2026). Schwankung grob gemessen als mittlere Abweichung der Tagesmediane.

| Kennzahl | Wert |
|---|---|
| Gegenstände im Markt | 30.707 |
| davon Ausrüstung mit Zusatz (Varianten) | etwa 24.100 |
| Absatz ab 10 Stück am Tag | 1.123 |
| ruhige Preise (unter 25 % Schwankung) mit Absatz | etwa 6.550 |
| Einzelstücke (höchstens 3 im Angebot, über 1g), gerade unter 60 % ihres Mittels | 1.113 |

**Folgerung:** Der Markt besteht vor allem aus Einzelstücken. „Billiger als üblich“ allein liefert über tausend Treffer, viele davon Schrott. Für Spekulation braucht es einen Nachweis, dass der Gegenstand zum Zielpreis wirklich verkauft wird.

### 1.3 Was stündliche Stände können und was nicht

- **Nicht:** Schnäppchen, die nach Minuten weg sind. Die findet nur das Radar im Spiel.
- **Wohl:** Über die Angebotsnummern sieht der Manager **echte Verkäufe** (zu welchem Preis wirklich gekauft wurde) und **wie lange ein Angebot steht**. Das kann Broker nicht, weil es nur bei geöffnetem Auktionshaus misst.
- **Gut geeignet** für alles, was sich über Tage entwickelt: Knappheit, Wochenrhythmus, Feste, Stufenbereiche.

## 2. Grundsätze

1. **Nachvollziehbar.** Zu jedem Vorschlag und jeder Prognose sieht man, warum er kommt, mit den echten Zahlen. Zu jedem Gegenstand sieht man auch, warum er *nicht* vorgeschlagen wird.
2. **Korrigierbar.** Jeder Vorschlag lässt sich bewerten, je Gegenstand übersteuern und über wenige, verständliche Regler anpassen.
3. **Nachgeprüft.** Jede Art und jedes Signal hat eine Trefferquote. Angezeigt wird nur, was sich bewährt hat oder ausdrücklich als neu gekennzeichnet ist.
4. **Übersichtlich.** In der Liste ein Satz je Vorschlag, alles Weitere beim Aufklappen oder im Steckbrief.
5. **Belegt statt geschätzt.** Wo es geht, zählen echte Verkäufe mehr als Angebotspreise.
6. **Der Manager liefert Kandidaten, das Urteil fällt live.** Was gekauft wird, prüft Broker im Spiel.

## 3. Datenbasis

### 3.1 Vorhanden

Stündliche API-Stände mit Angebotsnummern, Absatz je Tag (`sales_day`, `sales_cmp`), Stunden- und Tageswerte (`item_hour`, `item_day`), Langzeitbereich (F42), neues Preisniveau (F54), Händlerpreise, Warenart, Vorrat aus Ledger (Seite Einkaufen).

### 3.2 Neu zu speichern

| Nr. | Was | Wozu | Platz |
|---|---|---|---|
| D1 | **Verkaufspreise je Gegenstand und Tag** als Preisstufen (Preis gerundet auf 2 % Schritte, Stück) | belegter Verkaufspreis (F56) statt nur Mittel und Maximum | klein, je Gegenstand wenige Stufen |
| D2 | **Lebensdauer verkaufter Angebote:** je Verkauf Preis im Verhältnis zum belegten Verkaufspreis und Stunden bis zum Verkauf | Haltbarkeit (F58) | wie D1 |
| D3 | **Benötigte Stufe und Gegenstandsstufe** aller Gegenstände im Markt, im Hintergrund nach und nach von der API geholt | Stufenbereich-Index (F63) | eine Zeile je Gegenstand |
| D4 | **Feste und Ereignisse** aus dem Kalender des Spiels (Abschnitt 5.4) | Prognose zu Festen (F65) | sehr klein |
| D5 | **Vorschläge mit allen Werten des Moments** (Art, Zahlen jeder Bedingung) | Nachvollziehbarkeit, Erfolgskontrolle, Rückmeldung | Tage wie Stundenwerte |

D1 und D2 entstehen beim Vergleich zweier API-Stände, den es schon gibt. Ältere Tage lassen sich nicht nachrechnen, solange die Angebote nach der Aufbewahrung (Standard 14 Tage) gelöscht sind. Die Zahlen beginnen also mit dem Einbau.

## 4. Chancen

Grundlage wie Rechenmodell Kapitel 9: Gebühr 5 % (F11), Einstellgebühr wie Broker (F18, kommt beim Verkauf zurück, geht beim Ablauf verloren).

### 4.1 Kennzahlen für alle Arten

| Nr. | Ergebnis | Formel |
|---|---|---|
| F56 | Belegter Verkaufspreis | Median der Verkaufspreise (D1) der letzten 14 Tage. Nur mit mindestens N_BELEG Verkäufen, sonst „unbelegt“. |
| F57 | Verkaufsdauer | Stück, die vor einem eigenen Angebot zum Zielpreis stehen (alle Angebote bis zum Zielpreis), plus eigene Menge, geteilt durch Absatz je Tag (F46). |
| F58 | Haltbarkeit | Median der Stunden, die verkaufte Angebote unter 80 % des belegten Verkaufspreises standen (D2). Unter 1 Std. heißt „nur live erreichbar“. |
| F59 | Erwarteter Gewinn | Zielpreis × 0,95 × Menge minus Einsatz minus Einstellgebühren. Je angefangene Verkaufsdauer von 24 Std. über die erste hinaus eine weitere Einstellgebühr, weil neu eingestellt werden muss. |

### 4.2 Spekulation schnell

Für Einzelstücke und wenig Angebotenes (alles, was nicht Aufkauf ist). Kaufen unter dem belegten Verkaufspreis, zum belegten Preis wieder einstellen.

| Bedingung | Startwert | Name im Regler |
|---|---|---|
| Kaufpreis mindestens ABSTAND unter dem belegten Verkaufspreis (F56) | 30 % | „So viel günstiger als verkauft“ |
| Belegte Verkäufe in 14 Tagen mindestens N_BELEG | 5 | „Mindestens so viele Verkäufe gesehen“ |
| Verkaufsdauer (F57) höchstens | 3 Tage | „Höchstens so lange bis zum Verkauf“ |
| Erwarteter Gewinn (F59) mindestens | 1g | „Mindestgewinn“ |
| Kein neues Preisniveau nach unten (F54) | fest | |

Zielpreis = belegter Verkaufspreis, höchstens das nächste fremde Angebot darüber. Risiko als Ampel wie beim Aufkauf: je ein Punkt für Verkaufsdauer über 75 % der Grenze, weniger als 2 × N_BELEG Verkäufe, Schwankung über 40 %, Haltbarkeit unter 1 Std., alter Stand.

### 4.3 Spekulation langfristig

Kaufen, weil eine Knappheit kommt (Prognosen in Abschnitt 5). Kein Abstand zum Preis nötig, der Gewinn kommt aus dem erwarteten Anstieg.

| Bedingung | Startwert |
|---|---|
| Prognose „steigt“ mit Sicherheit mindestens mittel (Abschnitt 5.5) | fest |
| Erwarteter Anstieg nach Gebühr mindestens | 25 % |
| Zeitraum der Prognose höchstens | 14 Tage |
| Absatz vorhanden (Absatz-Stufe ab 2) | fest |

Zielpreis = Preis heute × (1 + erwarteter Anstieg). Die Chance gilt so lange wie die Prognose.

### 4.4 Aufkauf-Kandidaten

Rechnung wie Broker `Buyout.lua` mit dem heutigen Stand (nur Massenware, nur im üblichen Bereich, Ziel höchstens 20 % darüber, Startwerte wie im Spiel), auf dem letzten API-Stand. Ergebnis ist nur ein **Kandidat** für den Radar, das Urteil fällt live. Die Regeln liest der Manager aus Brokers Einstellungen, damit beide gleich rechnen.

### 4.5 Händler

Wie F51. Neu wird jede Zeile mit der Haltbarkeit (F58) bewertet. Ist sie unter einer Stunde, steht dort „nur live erreichbar“, und der Gegenstand geht als Kandidat an den Radar statt als Chance in die Liste.

### 4.6 Bestehende Arten

Wiederverkauf (F50) wird von der schnellen Spekulation abgelöst, weil sie dasselbe mit belegten Preisen rechnet. Fallend, Steigend und Lohnend ziehen in die Marktübersicht (Abschnitt 8). **Nichts davon fällt ohne Zustimmung weg** (Abschnitt 11).

## 5. Prognosen

Eine Prognose sagt für einen Gegenstand **Richtung** (steigt, fällt), **Zeitraum** (Tage) und **Sicherheit** (niedrig, mittel, hoch). Jede Prognose nennt die Signale, aus denen sie entsteht.

### 5.1 Reichweite

| Nr. | Ergebnis | Formel |
|---|---|---|
| F60 | Reichweite | Stück im Angebot geteilt durch Absatz je Tag, je Tag aus dem letzten Stand des Tages. |
| F61 | Signal Knappheit | Reichweite an mindestens 4 von 5 Tagen gefallen und heute unter 60 % ihres Mittels über 14 Tage, Absatz nicht gefallen. Richtung steigt. |
| F62 | Signal Schwemme | Neu eingestellt je Tag über 150 % des Mittels an 3 Tagen, Reichweite gestiegen. Richtung fällt. |

### 5.2 Stufenbereich-Index

Beantwortet die Frage, ob Gegenstände für bestimmte Stufen knapper werden, weil weniger Spieler dort leveln, und welche BoE-Gegenstände oft droppen und trotzdem gefragt sind. Es braucht dazu keine Spielerdaten, das Auktionshaus misst es direkt.

| Nr. | Ergebnis | Formel |
|---|---|---|
| F63 | Index je Stufenbereich | Bereiche zu 10 Stufen nach benötigter Stufe (D3), getrennt nach Ausrüstung und Sonstigem. Je Tag: Summe neu eingestellt (Angebot, steht für Drops), Summe verkauft (Nachfrage), Median der Preise im Verhältnis zum eigenen Mittel jedes Gegenstands. |
| F64 | Signal Stufenbereich | Neu eingestellt im Bereich über 7 Tage um mindestens 25 % gefallen, verkauft um weniger. Richtung steigt für alle Gegenstände des Bereichs mit Absatz. Sicherheit höchstens mittel. |

Daraus entsteht auch eine Rangliste je Bereich: häufig eingestellt (droppt oft) und trotzdem schnell verkauft.

### 5.3 Wochenrhythmus und Tageszeit

Mittel der Preise und des Absatzes je Wochentag und je 3-Stunden-Abschnitt über 4 Wochen. Ein Signal entsteht nur, wenn der Abstand zwischen günstigster und teuerster Zeit nach Gebühr mindestens 10 % beträgt und in mindestens 3 von 4 Wochen gleich lag. Anzeige als Raster im Steckbrief.

### 5.4 Feste und Ereignisse aus dem Spiel

Questie zeigt den Dunkelmond-Jahrmarkt, indem es den Kalender des Spiels liest (`C_Calendar.GetNumDayEvents`, `C_Calendar.GetHolidayInfo`). Für den Jahrmarkt muss dabei die Einstellung `calendarShowDarkmoon` an sein. Questie schaltet sie kurz ein und danach zurück. Ohne Kalender rechnet Questie mit einer Regel nach dem Datum.

- Ein Peon-Modul (Vorschlag: Peon_Bridge, weil sie ohnehin an den Manager liefert) liest beim Anmelden die Feste der nächsten 6 Wochen mit Name, Beginn und Ende und gibt sie an den Manager.
- Ob wir die Einstellung wie Questie kurz umschalten oder die Datumsregel nutzen, klärt Prüfung P2.
- Dazu kann KarloDerBaer eigene Ereignisse von Hand eintragen, zum Beispiel eine neue Inhaltsphase.

| Nr. | Ergebnis | Formel |
|---|---|---|
| F65 | Signal Fest | Für jedes Fest, das in den nächsten 14 Tagen beginnt: Preis und Absatz des Gegenstands im Fest und in den 7 Tagen davor, verglichen mit den 14 Tagen vor dem letzten gleichen Fest. Signal, wenn der Preis damals um mindestens 20 % stieg oder fiel. Ohne früheres Fest kein Signal. |

### 5.5 Sicherheit und Nachprüfung

| Nr. | Ergebnis | Formel |
|---|---|---|
| F66 | Sicherheit | Ein Signal: niedrig. Zwei gleichgerichtete: mittel. Drei oder ein Signal mit Trefferquote über 70 %: hoch. Gegenläufige Signale heben sich auf. |
| F67 | Trefferquote je Signal | Jede Prognose wird gespeichert (D5). Nach Ablauf ihres Zeitraums: Preis in die genannte Richtung um mindestens die Hälfte des erwarteten Werts bewegt = Treffer, sonst daneben. Je Signalart über 30 Tage. |

Ein Signal mit weniger als 20 nachgeprüften Fällen heißt „neu“ und zählt nicht für die Sicherheit. Ein Signal mit Trefferquote unter 40 % wird nicht mehr angezeigt, bis KarloDerBaer es wieder einschaltet.

### 5.6 Spielerdaten (nur nach Prüfung)

Eine Liste aller Spieler mit Stufen gibt es nicht. Die Profil-API liefert einen Charakter nur mit bekanntem Namen und Realm, und Forever hat keine Realms. Zwei Wege werden nur geprüft (P3, P4) und erst nach Freigabe eingebaut:

- Profil-API mit einem echten Charakter von KarloDerBaer.
- Zählung im Spiel über `/who` je Stufenbereich, ohne Namen zu speichern. Sie erfasst nur eine Stichprobe der eigenen Fraktion.

## 6. Nachvollziehbar

### 6.1 Drei Stufen je Vorschlag

1. **In der Liste ein Satz.** Er wird aus der wichtigsten erfüllten Bedingung und der knappsten gebaut. Beispiel: „Liegt 40 % unter dem, wofür er zuletzt verkauft wurde. Verkauft sich etwa 2 Mal am Tag.“
2. **Aufgeklappt eine Prüfliste.** Jede Bedingung mit Haken oder Kreuz, echtem Wert und Grenze, zum Beispiel „Belegte Verkäufe: 9 (nötig 5) ✓“. Knappe Werte (innerhalb 10 % der Grenze) sind gelb. Bei Prognosen stehen dort die Signale mit ihrer Trefferquote.
3. **Steckbrief** (Klick auf den Namen): Diagramm mit Angeboten als Linie, echten Verkäufen als Punkten, Zielpreis und Kaufen bis als Linien, Prognose als Fächer. Darunter der Rechenweg in einfachen Zeilen („Einsatz 12g, Erlös nach Gebühr 18g 50s, Einstellgebühr 30s, Gewinn 6g 20s“), Haltbarkeit, Raster nach Tageszeit, Feste.

### 6.2 Warum nicht?

Auf der Gegenstandsseite und in der Suche der Chancen gibt es für jeden Gegenstand dieselbe Prüfliste, auch wenn er nicht vorgeschlagen wird. Das erste Kreuz steht oben, mit Satz: „Kein Vorschlag, weil erst 2 Verkäufe gesehen (nötig 5).“

### 6.3 Begriffe

Alle Begriffe stehen in einer kurzen Erklärung beim Fragezeichen neben der Spalte, in einem Satz und ohne Formel. Die Formel steht nur im Rechenweg.

## 7. Korrigieren

Drei Wege, vom einfachsten zum stärksten. Alle Änderungen stehen im Protokoll des Managers.

### 7.1 Rückmeldung je Vorschlag

- Daumen hoch oder runter, dazu ein Grund zum Anklicken: „Scherzpreis“, „verkauft sich nicht“, „Zielpreis zu hoch“, „zu riskant“, „schon bekannt“, „lief gut“, „gekauft“. Freitext bis 250 Zeichen.
- Gespeichert wird der Vorschlag mit allen Werten des Moments (D5).
- Die Einschätzungen aus Broker (`PeonBrokerDB.ratings`) liest der Manager ein und zeigt sie in derselben Liste.
- Eine Seite „Rückmeldungen zu Chancen“ zeigt alles gesammelt. Ein Knopf legt eine Datei für die Auswertung durch Claude an (ohne Konto- und Charakternamen). Claude schlägt daraus geänderte Startwerte oder neue Bedingungen vor, KarloDerBaer entscheidet.

### 7.2 Je Gegenstand

„Nie vorschlagen“, „Art für diesen Gegenstand aus“, „Zielpreis selbst festlegen“, „Kaufen bis selbst festlegen“. In der Prüfliste steht dann „von dir geändert“ mit einem Knopf zum Zurücknehmen. Eine Liste aller Übersteuerungen steht in den Einstellungen.

### 7.3 Regler je Art mit Probe

- Je Art höchstens 5 Regler, benannt in Alltagssprache (Spalte „Name im Regler“ in Abschnitt 4), mit Knopf „Standard“.
- Beim Verschieben rechnet eine **Probe** mit den gespeicherten Vorschlägen der letzten 14 Tage: „Mit diesem Wert wären es 34 statt 12 Vorschläge gewesen, davon hätten sich 60 % statt 75 % gelohnt.“ Übernommen wird erst mit „Übernehmen“.
- Prognosen haben statt Reglern einen Schalter je Signal und eine Mindest-Sicherheit.

## 8. Seiten im Manager

| Seite | Inhalt |
|---|---|
| **Chancen** | Eine Liste aller Arten. Spalten: Gegenstand, Art, Gewinn, Verkaufsdauer, Haltbarkeit, Risiko, Aussicht (Pfeil, Zeitraum, Sicherheit), Stand. Darunter der Satz je Zeile. Filter je Art, Mindestgewinn, Qualität, Suche. Zeile aufklappbar (6.1). Knöpfe je Zeile: Steckbrief, Rückmeldung, Beobachten, An Broker. |
| **Steckbrief** | 6.1 Stufe 3, erreichbar aus Chancen, Marktübersicht und Gegenstand. |
| **Marktübersicht** | Fallend, Steigend, Lohnend, größte Preisänderungen, Stufenbereich-Index mit Rangliste, kommende Feste mit betroffenen Gegenständen. |
| **Erfolgskontrolle** | Trefferquote je Art und je Signal über 30 Tage, Verlauf als Linie, dazu eigene Käufe aus Ledger mit Einsatz, Erlös und Dauer (Neuaufbau 6.7). |

Die Seite Radar (WIP) wird durch Chancen ersetzt.

## 9. Übergabe an Broker

### 9.1 Kandidatenliste

Der Manager schreibt je Markt eine Liste in `Data.lua`, die Bridge gibt sie beim Anmelden an Broker:

```
chances = { t = Zeit, list = { [Schlüssel] = "Art:KaufenBis:Zielpreis:GültigBis:Gewinn:Risiko" } }
```

- Art: `s` Spekulation schnell, `l` Spekulation langfristig, `b` Aufkauf-Kandidat, `v` Händler.
- Höchstens 200 Einträge je Markt, sortiert nach Gewinn.
- Abgelaufene Einträge (GültigBis) ignoriert Broker.

### 9.2 In Broker

- Radar bekommt die Art **Spekulation** (Einstellung „Spekulation“ statt „kommt später“). Gezeigt werden Einträge `s` und `l` mit dem Alter des Manager-Stands. Erneuern prüft sie live wie jede andere Zeile. Was live nicht mehr stimmt, wird „weg“ wie heute.
- Radar-Scan bekommt die Auswahl **„Vom Manager“**: Er fragt zuerst alle Kandidaten ab (`b` und `v` eingeschlossen), danach die bisherige Auswahl.
- Der Fokus zeigt bei einer Chance vom Manager den Satz aus 6.1 und einen Hinweis „vom Manager, Stand vor X Std.“.
- Einschätzungen in Broker speichern die Art und den Satz mit, damit der Manager sie zuordnen kann.

### 9.3 Rückweg

Die Bridge liefert Einschätzungen (`ratings`) und Feste (D4) an den Manager. Käufe aus dem Radar erkennt der Manager über Ledger und verknüpft sie mit dem Vorschlag für die Erfolgskontrolle.

## 10. Prüfungen vor dem Bau

| Nr. | Was | Wie | Entscheidet |
|---|---|---|---|
| P1 | Haltbarkeit | D2 eine Woche lang mitschreiben, ohne Anzeige. Ergebnis: Anteil der Chancen, die länger als 1 Std. stehen. | Wie viel Spekulation im Manager sinnvoll ist und wie viel nur als Kandidat an den Radar geht |
| P2 | Kalender im Spiel | Prüfbefehl in der Bridge: Feste der nächsten 6 Wochen ausgeben, einmal mit und einmal ohne `calendarShowDarkmoon`. | Ob der Kalender in Forever vollständig ist und ob wir die Einstellung kurz umschalten |
| P3 | Profil-API | Prüfabruf unter `profile-forever-eu` mit einem echten Charakter von KarloDerBaer, Ergebnis nur lokal, Name nie im Repo. | Ob es Profildaten gibt |
| P4 | `/who` | Prüfbefehl: eine Abfrage je Stufenbereich, prüfen ob das Spiel einen Klick je Abfrage verlangt und wie viele Treffer kommen. | Ob eine Zählung ohne Störung beim Spielen möglich ist |

## 11. Was wegfällt oder sich ändert (Vorschlag, nichts ohne Zustimmung)

- Reiter Wiederverkauf geht in Spekulation schnell auf.
- Reiter Fallend, Steigend und Lohnend ziehen in die Marktübersicht.
- Trefferquote F55 geht in der Erfolgskontrolle auf.
- Seite Radar (WIP) wird zu Chancen.

## 12. Bauabschnitte

| Nr. | Inhalt | Module |
|---|---|---|
| K1 | D1 und D2 mitschreiben, Prüfung P1 auswerten | Manager |
| K2 | Prüfungen P2 bis P4 | Bridge, Manager |
| K3 | Kennzahlen F56 bis F59, Spekulation schnell, Aufkauf und Händler neu, Seite Chancen mit Satz und Prüfliste, Warum nicht | Manager |
| K4 | Steckbrief | Manager |
| K5 | Korrigieren: Rückmeldung, Übersteuerung je Gegenstand, Regler mit Probe, Einlesen der Einschätzungen aus Broker | Manager |
| K6 | Übergabe an Broker: Kandidatenliste, Art Spekulation im Radar, Auswahl „Vom Manager“ | Manager, Bridge, Broker |
| K7 | D3 und Prognosen Reichweite und Stufenbereich, Marktübersicht | Manager |
| K8 | Feste aus dem Spiel (D4, F65), Wochenrhythmus, Spekulation langfristig | Bridge, Manager, Broker |
| K9 | Erfolgskontrolle mit Ledger | Manager |

K1 zuerst, weil die übrigen Abschnitte die neuen Daten brauchen. K3 bis K6 ergeben die erste nutzbare Fassung.

## 13. Abstimmung mit KarloDerBaer

### Geklärt (13.11.2026)

1. Im Manager kein Radar, sondern Chancen und Prognosen auf Grundlage der stündlichen API-Stände.
2. Chancen gehen an Broker, das Radar bekommt die Art Spekulation.
3. Prognosen gehören dazu. Spielerstufen wären wünschenswert, ersatzweise misst der Stufenbereich-Index die Knappheit direkt im Auktionshaus.
4. Feste wie der Dunkelmond-Jahrmarkt sollen aus dem Spiel kommen, wenn möglich.
5. Alles muss nachvollziehbar sein: Warum wird etwas vorgeschlagen?
6. Vorschläge müssen sich korrigieren lassen, über Rückmeldung zur Auswertung und über direkte Regler. Alles übersichtlich und leicht verständlich.
7. Empfehlung von Claude, von KarloDerBaer gutgeheißen: Spekulation über belegte Verkäufe und Haltbarkeit als Kern, eine Liste für alle Arten mit Steckbrief, Übergabe als Kandidatenliste, Prognosen zuerst über Reichweite und Stufenbereich.

### Offen

- Freigabe des Konzepts.
- Startwerte in Abschnitt 4 und 5.
- Einverstanden mit dem Wegfall und den Umzügen in Abschnitt 11?
- Gehört das Lesen der Feste in die Bridge oder in Broker?
- Soll die Probe (7.3) auch die Rückmeldungen einbeziehen, zum Beispiel „davon hattest du 3 als Scherzpreis markiert“?
- Reihenfolge der Bauabschnitte, besonders ob die Übergabe an Broker (K6) vor den Prognosen (K7) kommen soll.
