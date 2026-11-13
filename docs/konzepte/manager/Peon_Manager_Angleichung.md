# Peon Manager: Konzept Angleichung nach dem Neuaufbau von Broker und Ledger

Stand: 13.11.2026, **Teil 1 von KarloDerBaer freigegeben** (Abschnitt 9). A1 gebaut (Broker 0.85.0, Bridge 0.10.0, Manager 0.29.0), A2 gebaut (Broker 0.89.0, Manager 0.30.0), A3 gebaut (Manager 0.31.0), nicht veröffentlicht. Ausgangsversionen Manager 0.28.0, Broker 0.84.0, Bridge 0.9.2, Ledger 0.14.7.

Das Konzept hat drei Teile, die nacheinander ausgearbeitet und gebaut werden (KarloDerBaer, 13.11.2026):

1. **Einkaufslisten und Beobachten** im Manager sehen und verwalten, mit einem nachvollziehbaren Abgleich (dieses Dokument, Abschnitte 2 bis 9).
2. **Chancen im Manager selbst:** Regeln anpassen oder anpassbar machen. Fallend, Steigend und Ähnliches nicht mehr unter Chancen, sondern als eigene Marktübersicht (Abschnitt 10, noch offen).
3. **Daten für Broker aufbereiten**, zum Beispiel Kandidaten für das Radar (Abschnitt 10, noch offen).

## 1. Ausgangslage

Grundsatz (KarloDerBaer, 13.11.2026): **Der Manager übernimmt, was das Spiel nicht kann.** Er hat stündlich frische Daten aus der Blizzard-API, kann sich über Windows melden, auch wenn WoW nicht läuft, und kann für Broker vorrechnen. Fokus, Verkaufen und Auktionen bleiben im Spiel. Das Radar arbeitet im Spiel mit Live-Daten und wird im Manager nicht nachgebaut.

Befund aus dem Code (13.11.2026):

- Der Datenaustausch läuft nach dem Umbau weiter. Der Manager liest Einkaufslisten (`lists`, `listsGone`), Beobachtung (`watch`, `watchGone`) und Händler aus `Peon_Broker.lua` und schreibt `shop` und `watch` in `Data.lua`. Die Bridge gibt beides beim Anmelden an Broker (`MergeShop`, `MergeWatch`).
- Je Eintrag gewinnt die neuere Änderung (`u`), Gelöschtes bekommt eine Löschmarke, die nach 60 Tagen verfällt.
- Der Manager liest alle Kontoordner unter `WTF\Account` und mischt sie zu einem Stand. Darüber gleichen sich die Listen heute auch zwischen verschiedenen WoW-Konten ab.
- Bei der Beobachtung läuft nur mit, *ob* ein Gegenstand beobachtet wird. „Kaufen bis“ (`lim` in Kupfer oder `pct` in % unter dem Vergleichspreis) und „Zielpreis“ (`up`) bleiben im Spiel.
- Die Seiten Einkaufen und Beobachtung im Manager stehen seit 0.28.0 auf WIP.

Schwachstellen:

1. Was der Abgleich übernommen hat und woher, sieht man nirgends. Der Manager zeigt nur „3 warten, im Spiel /reload“.
2. Es gewinnt immer der ganze Eintrag. Wer im Manager die Menge und im Spiel vor dem nächsten `/reload` den Höchstpreis ändert, verliert eine der beiden Änderungen ohne Hinweis.
3. Bei der Beobachtung fehlen die Grenzen im Manager.
4. Löschmarken verfallen nach 60 Tagen. Ein Kontoordner, in dem lange nicht gespielt wurde, bringt danach alte Einträge zurück.
5. Gelöscht ist endgültig.
6. Die Listen sind in den Addons accountweit, im Manager aber über alle Konten gemischt.

## 2. Grundsätze

1. **Je WoW-Konto eigene Listen und eigene Beobachtung**, wie in den Addons. Kein Abgleich über Konten hinweg.
2. **Abgleich je Wert.** Jeder Wert trägt seine eigene Zeit. Nur wenn derselbe Wert an beiden Stellen geändert wurde, gewinnt die neuere Änderung.
3. **Alles Übernommene steht im Protokoll** des Managers. Im Spiel gibt es dazu keine Meldung.
4. **Nichts geht still verloren.** Gelöschtes bleibt 30 Tage wiederherstellbar, Löschmarken halten ein Jahr.
5. **Gleiche Rechnung wie im Spiel.** Rat, Vergleichspreis, Vorrat und Fehlt rechnet der Manager wie Broker, damit beide dasselbe zeigen.

## 3. Abgleich

### 3.1 Je Konto

- Broker legt beim ersten Laden eine zufällige Kennung für das Konto an (`PeonBrokerDB.acct`). Das Spiel kennt den Namen des Kontoordners nicht, die Kennung ersetzt ihn.
- Der Manager liest `Peon_Broker.lua` je Kontoordner und merkt sich, welche Kennung zu welchem Ordner gehört.
- `Data.lua` bekommt Listen und Beobachtung je Kennung: `accts = { [Kennung] = { shop = …, watch = … } }`. Die Bridge gibt Broker nur den Teil mit der eigenen Kennung.
- Im Manager wählt man oben auf den Seiten Einkaufen und Beobachten das Konto. Die Auswahl erscheint nur, wenn mehr als ein Konto Broker-Daten hat. Angezeigt wird ein Name, den man im Manager selbst vergeben kann, und zum Erkennen die Charaktere des Kontos (aus Broker oder Ledger).
- Wer einen Kontoordner kopiert, kopiert auch die Kennung. Findet der Manager dieselbe Kennung in zwei Ordnern, meldet er das auf der Seite Datenlage und gleicht nur mit dem Ordner ab, der zuletzt geschrieben wurde.

### 3.2 Je Wert

Werte mit eigener Zeit:

| Teil | Werte |
|---|---|
| Liste | Name, Rabatt |
| Eintrag einer Liste | Menge, Höchstpreis |
| Beobachtung | Kaufen bis (Betrag oder %), Zielpreis |

- Jeder Wert hat eine Zeit in `t`, zum Beispiel `{ wish = 20, max = 1500, t = { wish = …, max = … } }`. Ein geleerter Wert ist ebenfalls eine Änderung mit Zeit.
- `u` bleibt als Zeit der letzten Änderung des ganzen Eintrags erhalten (Anlegen, Löschen, Sortieren der Anzeige).
- Kaufen bis ist ein Wert, auch wenn er als Betrag oder als % gespeichert ist. Wechselt man von Betrag zu %, ist das eine Änderung dieses einen Werts.
- Name, Qualität und Symbol eines Gegenstands sind nur Anzeige. Sie werden ergänzt, wo sie fehlen, ohne Zeit und ohne Protokoll.
- Die Regeln stehen in beiden Sprachen gleich: `Shop.lua` und `Watch.lua` in Broker, `shopping.js` und ein neues `watching.js` im Manager. Ein Test prüft dieselben Fälle auf beiden Seiten (wie heute `umbau2.test.js`).

### 3.3 Gleichzeitige Änderungen

Ein Wert gilt als an beiden Stellen geändert, wenn der Manager ihn geändert hat, das Spiel diese Änderung noch nicht bestätigt hat (3.5) und das Spiel denselben Wert mit einer anderen Zeit und einem anderen Inhalt bringt. Dann gilt die neuere Änderung, und das Protokoll zeigt den Fall als „beide geändert“ mit beiden Werten.

### 3.4 Löschen und Wiederherstellen

- Löschmarken halten **ein Jahr** statt 60 Tage, im Spiel und im Manager.
- Der Manager merkt sich gelöschte Listen und Einträge mit ihren Werten **30 Tage** lang. Unter „Gelöscht“ auf beiden Seiten lassen sie sich wiederherstellen. Wiederherstellen ist ein neues Anlegen mit neuer Zeit und kommt so auch ins Spiel.
- Gelöscht wird weiter an beiden Stellen. Was im Spiel gelöscht wurde, erscheint nach dem Abgleich ebenfalls unter „Gelöscht“.

### 3.5 Zustand je Zeile

- Ändert man im Manager etwas, steht an der Zeile „wartet auf /reload“ (WoW läuft) oder „beim nächsten Anmelden“ (WoW läuft nicht).
- Bestätigt ist die Änderung, sobald `Peon_Broker.lua` desselben Kontos den Wert mit derselben oder einer neueren Zeit enthält. Dann verschwindet der Hinweis.
- Der Zähler in der Kopfleiste bleibt als Summe.

### 3.6 Protokoll

- Neue Tabelle `sync_log` in `broker-client.db`: Zeit, Konto, Herkunft (Spiel oder Manager), Liste, Gegenstand, Wert, alt, neu, Art (geändert, angelegt, gelöscht, wiederhergestellt, beide geändert).
- Zu sehen auf den Seiten Einkaufen und Beobachten unter „Protokoll“, neueste oben, mit Filter nach Konto und Herkunft. Einträge bleiben 90 Tage.
- Beispiele:
  - „13.11. 14:02 aus dem Spiel: Erzliste, Kupfererz, Menge 20 → 40“
  - „13.11. 14:05 im Manager: Silberblatt aus der Kräuterliste entfernt“
  - „13.11. 14:10 beide geändert: Kupfererz, Höchstpreis Spiel 12s, Manager 10s, es gilt 12s aus dem Spiel“

## 4. Seiten

### 4.1 Beobachten

| Spalte | Inhalt |
|---|---|
| Gegenstand | Name in Qualitätsfarbe, Klick öffnet die Seite Gegenstand |
| Preis | günstigstes Angebot im letzten Stand (Scan oder Blizzard-API), mit Alter im Tooltip |
| Kaufen bis | Betrag oder %, direkt in der Zeile änderbar, % zeigt den daraus gerechneten Betrag im Tooltip |
| Zielpreis | Betrag, direkt in der Zeile änderbar |
| Üblich | üblicher Bereich |
| Rat | KAUFEN (Preis auf oder unter Kaufen bis) oder VERKAUFEN (Preis auf oder über dem Zielpreis), wie im Spiel |
| Meldung | zwei Glocken, je eine für Kaufen bis und Zielpreis (4.3) |

- Hinzufügen über den Stern auf den Seiten Markt und Gegenstand (wie heute) und über ein Suchfeld oben.
- Kaufen bis in % rechnet mit demselben Vergleichspreis wie Broker (`D.RefBuy`: Median der Woche ab 2 Tagen, sonst Median). Der Manager hat dafür eigene Werte. Der Test vergleicht das Ergebnis mit Broker.
- Darunter „Gelöscht“ und „Protokoll“ zum Aufklappen.

### 4.2 Einkaufen

- Links die Listen des gewählten Kontos mit Anlegen, Umbenennen, Rabatt und Löschen.
- Rechts die Einträge:

| Spalte | Inhalt |
|---|---|
| Gegenstand | wie oben |
| Menge | Wunschmenge, änderbar |
| Fehlt | Menge minus Vorrat, Vorrat im Tooltip |
| Preis | günstigstes Angebot im letzten Stand |
| Höchstpreis | eigener Wert oder Wert der Liste, änderbar |
| Treffer | Stück im letzten Stand bis zum Höchstpreis |

- **Vorrat** wie im Spiel: Taschen und Bank aller Charaktere **desselben Kontos** aus `Peon_Ledger.lua`. Post und Auktionen zählen im Spiel nicht mit und deshalb auch hier nicht.
- Die Meldung über Windows, wenn etwas unter dem Höchstpreis zu haben ist (`shopNotify`), bleibt wie heute.
- Darunter „Gelöscht“ und „Protokoll“ zum Aufklappen.

### 4.3 Meldungen über Windows für Beobachten

- Der Manager prüft nach jedem neuen Stand (Blizzard-API stündlich, Scan, `/reload`).
- Meldung, wenn der Preis auf oder unter Kaufen bis fällt oder auf oder über den Zielpreis steigt. Danach erst wieder, wenn der Preis zwischendurch auf der anderen Seite der Grenze lag (wie im Spiel).
- **Einstellbar je Gegenstand und je Grenze** (KarloDerBaer): zwei Glocken in der Zeile. Bei neuen Einträgen sind beide Glocken aus (KarloDerBaer). Dazu ein Hauptschalter für alle.
- Diese Schalter gelten nur im Manager und werden nicht abgeglichen. Die Warnung im Spiel bleibt beim Haken unter Beobachten (`watchAlarm`).
- Ein Klick auf die Meldung öffnet die Seite Beobachten mit der Zeile.

## 5. Gespeicherte Daten

| Wo | Neu |
|---|---|
| `PeonBrokerDB` | `acct` (Kennung des Kontos), je Liste, Eintrag und Beobachtung `t` mit Zeiten je Wert, Löschmarken ein Jahr |
| `Data.lua` | `accts[Kennung] = { shop, watch }` statt `shop` und `watch` oben, `watch` mit Kaufen bis und Zielpreis |
| `broker-client.db` | Stand je Konto statt eines gemischten Stands (`meta` `shop` und Tabelle `favorites` werden je Konto geführt), Tabellen `sync_log` und `sync_trash` (Gelöschtes 30 Tage), Name der Konten, Schalter der Meldungen je Gegenstand |

## 6. Umstellung alter Daten

- Broker gibt beim ersten Laden jedem Eintrag ohne `t` die Zeit `u` für alle Werte. Danach gilt der Abgleich je Wert.
- Beim Bau von A1 vereinfacht (Claude, 13.11.2026): Der bisherige gemischte Stand des Managers geht **ganz** an das erste Konto mit Kennung, also an das Konto, in dem nach dem Update zuerst gespielt wird. So sieht man dort genau das, was der Manager vorher zeigte, und nichts geht verloren. Weitere Konten beginnen mit dem, was ihr Spiel liefert. Weil der alte Abgleich alle Konten gemischt hat, stehen die Einträge ohnehin schon in jedem Konto, das seitdem gespielt wurde. Eine Liste „nicht zugeordnet“ entfällt.
- Der bisherige Stand bleibt unverändert in der Datenbank (`meta` `shop`, Tabelle `favorites`). Bis zum ersten Konto mit Kennung arbeitet der Manager mit ihm wie bisher.
- Broker, Bridge und Manager müssen zusammen ins Release. Eine ältere Bridge findet `shop` und `watch` oben in `Data.lua` nicht mehr und gleicht dann einfach nichts ab.

## 7. Was wegfällt

- Der Abgleich über Konten hinweg.
- Der gemischte Stand im Manager.
- Die WIP-Hinweise der Seiten Einkaufen und Beobachtung (Händler und Radar bleiben vorerst WIP, sie gehören zu Teil 2).

## 8. Bauabschnitte

| Schritt | Inhalt | Teile | Größe |
|---|---|---|---|
| A1 Konto | Kennung in Broker, Stand je Konto im Manager, `accts` in `Data.lua`, Auswahl des Kontos, Umstellung | Broker, Bridge, Manager | mittel |
| A2 Je Wert | Zeiten je Wert, Abgleich je Wert auf beiden Seiten, Beobachtung mit Grenzen, Löschmarken ein Jahr, gemeinsamer Test | Broker, Bridge, Manager | mittel |
| A3 Nachvollziehen | Protokoll, Zustand je Zeile, Gelöscht und Wiederherstellen | Manager | mittel |
| A4 Beobachten | Seite neu nach 4.1, Meldungen nach 4.3 | Manager | mittel |
| A5 Einkaufen | Seite neu nach 4.2, Vorrat je Konto | Manager | mittel |

A1 und A2 ändern das Format und gehen zusammen als Vorabversion in den Kanal Test. A3 bis A5 nur im Manager, je eine Version.

## 9. Abstimmung mit KarloDerBaer

### Geklärt (13.11.2026)

1. **Rolle des Managers:** übernimmt, was das Spiel nicht kann. Das Radar wird im Manager nicht nachgebaut, weil es im Spiel mit Live-Daten arbeitet.
2. **Reihenfolge:** erst Einkaufslisten und Beobachten, dann Chancen im Manager, dann Daten für Broker.
3. **Abgleich je Wert** statt je Eintrag.
4. **Protokoll nur im Manager**, keine Meldung im Spiel.
5. **Gelöschtes wiederherstellbar**, Löschmarken ein Jahr.
6. **Kein Abgleich über Konten hinweg**, weil die Listen in den Addons accountweit geführt werden.
7. **Meldungen über Windows für Beobachten**, einstellbar je Gegenstand und je Grenze.
8. **Glocken neuer Einträge aus.**
9. **Kein Kopieren zwischen Konten**, auch nicht auf Knopfdruck. Bei Bedarf später.

10. **Freigabe** von Teil 1 (13.11.2026). Gebaut wird ab A1, jeder Schritt als eigene Version.

### Offen

- Im echten Programm zu prüfen: Umstellung beim ersten `/reload` mit Broker 0.85 (A1), Grenzen der Beobachtung hin und zurück (A2), Protokoll und Wiederherstellen (A3).
- Beim Bau von A3 festgelegt (Claude): „Wartet auf /reload“ gilt bis zum nächsten Laden im Spiel nach der Eingabe. Das Spiel schreibt seine Datei beim Laden, bevor es `Data.lua` liest, die Bestätigung in `Peon_Broker.lua` kommt also erst ein Speichern später. Der Manager behält die Eingabe trotzdem bis zu dieser Bestätigung (höchstens 60 Tage), um „beide geändert“ zu erkennen.
- Beim Bau von A2 festgelegt (Claude): Kommt ein Eintrag ohne Zeit für einen Wert, gilt für diesen Wert die Zeit des ganzen Eintrags (`u`). So verhalten sich Daten von vor A2 wie bisher. Bevor sich `u` ändert, werden fehlende Zeiten aus dem alten `u` eingetragen, damit ein alter Wert nicht plötzlich als neu gilt.

## 10. Teil 2 und Teil 3 (noch auszuarbeiten)

- **Chancen im Manager:** Aufkauf und Händler mit Regeln, die zu Broker passen oder einstellbar sind. Broker hat seit 0.65 neue Bedingungen (nur Massenware, nur im üblichen Bereich, Ziel höchstens 20 % darüber, neue Standardwerte), der Manager rechnet noch nach 0.65.
- **Marktübersicht:** Fallend, Steigend, Lohnend und die größten Preisänderungen als eigene Seite statt als Reiter unter Chancen. Ob Wiederverkauf bleibt, wird dort entschieden.
- **Daten für Broker:** zum Beispiel Kandidaten für das Radar aus den stündlichen Ständen (Broker-Konzept Neuaufbau 6.7).
