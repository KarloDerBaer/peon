# Marktvergleich mit dem neutralen Auktionshaus

Stand: 20.11.2026, **freigegeben von KarloDerBaer am 20.11.2026** (Antworten in Abschnitt 8). Vorgaben von KarloDerBaer vom 20.11.2026, ausgearbeitet von Claude. Ausgangsversionen Broker 0.126.0, Bridge 0.12.0, Manager 0.49.0.

## 1. Ziel

Preisunterschiede zwischen dem eigenen Haus (Heimat) und dem neutralen Haus finden und nutzen: in einem Haus günstig kaufen, im anderen teurer verkaufen. Drei Teile:

1. **Broker, Mehr, Neutral:** Suche nach Gegenständen im Vergleich.
2. **Broker, Chancen, neuer Unterreiter:** die aussichtsreichsten Fälle, bewertet nach Preisunterschied und Absatz im Zielmarkt.
3. **Manager, eigener Reiter Marktvergleich:** ausführlicher Vergleich über Tage, ermittelt die Chancen und gibt sie an Broker weiter. Teil 2 baut darauf auf.

Grundsatz wie bei den Chancen (`Peon_Manager_Chancen.md`): Der Manager rechnet über Tage mit den Ständen der Blizzard-API und echten Verkäufen. Broker zeigt die Liste und prüft live am Auktionator.

## 2. Ausgangslage

### 2.1 Was es schon gibt

- **Broker, Mehr, Neutral** (`Pages.lua`, `G.CompareRows`): Tabelle mit Heimat, Neutral, Unterschied in Prozent nach Gebühr und „Besser in“. Filter „Nur Gegenstände im Bestand“ und Mindestunterschied. Grundlage ist nur der günstigste Preis aus dem letzten Stand beider Märkte. Keine Suche, kein Absatz, keine Geschichte.
- **Broker, Gebühr** (`Cut.lua`): Der Anteil wird aus den Rechnungen im Postfach gemessen. Für Neutral gibt es noch keinen Messwert, Broker meldet „Neutral nicht gemessen“.
- **Bridge:** liefert je Markt `LongTerm`, `Sales` (Absatz je Tag und Absatzquote), `Current` und `Chances`. Der Manager rechnet das schon für jeden Markt, also auch für Neutral.
- **Manager:** Stände, Absatz (`sales.js`), Langzeitbereich, Stabilität und Chancen je Markt. Einen Vergleich zwischen zwei Märkten gibt es noch nicht.

### 2.2 Datenlage (echte Daten, 20.11.2026, nur lesend gemessen)

| | Heimat (PvE Allianz) | Neutral (PvE) |
|---|---|---|
| Stände der Blizzard-API | 354 (ab 05.11.) | 262 (ab 09.11.) |
| Gegenstände mit Absatzdaten | 51.821 | 28.518 |

Grobe Zählung über die letzten 7 Tage, Kaufpreis und Verkaufspreis je als Mittel der echten Verkäufe, Anteil 5 % Heimat und 15 % Neutral (angenommen):

| | Heimat → Neutral | Neutral → Heimat |
|---|---|---|
| In beiden Märkten verkauft | 12.222 | 12.222 |
| Unterschied nach Gebühr ab 20 % | 2.826 | 4.718 |
| davon ab 1 verkauftem Stück am Tag im Ziel | 1.304 | 3.179 |
| davon ab 5 am Tag | 659 | 537 |
| davon ab 20 am Tag | 436 | 78 |
| ab 1 am Tag und ab 1 Gold Gewinn am Tag | 681 | 1.076 |

**Folgerung:** Es gibt viele Treffer, darunter sicher viel Rauschen (Einzelstücke, Ausrüstung mit Zusatz, Ausreißer im Mittel). Die Bewertung muss streng sein und vor allem prüfen, ob der Unterschied über Tage hält und ob der Zielmarkt die Menge wirklich abnimmt.

## 3. Rechnung im Manager

Neue Datei `manager\src\core\compare.js`, gerechnet zusammen mit den Chancen (`buildMarkets`), je Paar Heimat und Neutral desselben Regelsatzes (`sameMarket`, gleiche Region und gleicher Regelsatz).

### 3.1 Werte je Gegenstand und Richtung

Zeitraum Vorgabe 7 Tage, wählbar 3, 7 oder 14.

| Wert | Bedeutung | Quelle |
|---|---|---|
| **Kaufpreis** | was man in der Quelle üblicherweise zahlt: Median der günstigsten Preise je Stand | Stände der Quelle |
| **Verkaufspreis** | was im Ziel wirklich bezahlt wird: Median der Verkaufspreise je Tag, höchstens der übliche günstigste Preis im Ziel | `sales_day` (Wert durch Stück) und Stände des Ziels |
| **Netto je Stück** | Verkaufspreis mal (1 minus Anteil Ziel) minus Kaufpreis minus Einstellgebühr mal Ablaufanteil | |
| **Spanne** | Netto je Stück geteilt durch Kaufpreis | |
| **Absatz im Ziel** | verkaufte Stück je Tag (Median der Tage, gegen Ausreißer) und Absatzquote | `sales_day` |
| **Vorrat im Ziel** | Angebot im Ziel geteilt durch Absatz je Tag, also Tage bis alles weg ist | letzter Stand |
| **Beständigkeit** | Anteil der Tage im Zeitraum, an denen Netto über null lag | Tageswerte beider Märkte |
| **Menge** | sinnvolle Kaufmenge: eigener Anteil am Absatz mal Haltedauer, höchstens das übliche Angebot in der Quelle bis Kaufen bis | |

Eigener Anteil am Absatz Vorgabe 10 %, Haltedauer Vorgabe 1 Tag (beides einstellbar im Manager, KarloDerBaer). Der Gedanke: Man ist nicht der einzige Verkäufer und will die Ware in wenigen Tagen los sein.

### 3.2 Bewertung

**Gewinn je Tag** = Netto je Stück mal Absatz im Ziel mal eigener Anteil.

**Bewertung** = Gewinn je Tag mal Beständigkeit mal Abschlag für vollen Zielmarkt (ab 3 Tagen Vorrat sinkt der Wert, ab 10 Tagen fällt die Chance weg).

Bedingungen, sonst keine Chance:

- Daten aus mindestens 3 Tagen in beiden Märkten (bei Zeitraum 3 Tage: 2)
- Spanne mindestens 20 %, Netto mindestens 10 Silber je Stück
- Absatz im Ziel mindestens 1 Stück am Tag
- Beständigkeit mindestens 50 %

**Ampel** in Manager und Broker: grün ab 70 % Beständigkeit und höchstens 3 Tage Vorrat, gelb dazwischen, rot nur in der Liste „Alle“ sichtbar.

**Satz je Chance** (wie bei den Chancen): „Heimat kauft für 1g 20s, Neutral verkauft im Mittel für 2g 10s, 14 am Tag. Unterschied an 6 von 7 Tagen.“

### 3.3 Gebühr des neutralen Hauses

Der Manager kennt den Anteil nicht selbst. Vorschlag: Er liest den gemessenen Anteil aus `Peon_Broker.lua` (wie schon die Einschätzungen). Solange Neutral nicht gemessen ist, gilt 15 % und die Zahlen tragen den Hinweis „Gebühr angenommen“. Die Einstellgebühr im neutralen Haus ist im klassischen Spiel ebenfalls höher, auch sie wird angenommen, bis Broker sie gemessen hat.

## 4. Reiter Marktvergleich im Manager

Eigener Eintrag in der Seitenleiste unter Chancen: **Marktvergleich**. Neue Ansicht `views\Compare.vue`, gelesen über den Lese-Prozess wie die anderen Seiten.

**Kopf:** Paar (zum Beispiel „PvE Allianz ↔ PvE Neutral“), Richtung (beide, nach Neutral, nach Heimat), Zeitraum, Suche, Filter Qualität, Mindestgewinn je Tag, Mindestabsatz, nur Massenware.

**Unterreiter:**

1. **Chancen:** die bewerteten Fälle, sortiert nach Bewertung. Spalten Gegenstand, Richtung, Kaufpreis, Verkaufspreis, Netto, Spanne, Absatz im Ziel, Vorrat im Ziel, Beständigkeit, Gewinn je Tag, Ampel. Aufklappen zeigt den Satz und die Zahlen dahinter. Daumen hoch und runter sowie „An Broker“ (anheften) wie bei den Chancen.
2. **Alle Gegenstände:** jeder Gegenstand aus beiden Märkten mit Preis und Absatz beider Seiten, auch ohne Chance. Wer nur in einem Markt vorkommt, steht mit „fehlt“ da. Gedacht zum Stöbern und Suchen.
3. **Übersicht:** wie viele Chancen je Richtung, Summe Gewinn je Tag der grünen, Verteilung nach Kategorie, Datenstand beider Märkte, gemessene oder angenommene Gebühr.

**Gegenstand:** Die bestehende Seite eines Gegenstands bekommt einen Abschnitt „Neutral“ mit beiden Märkten in einem Diagramm (günstigster Preis und Verkaufspreise je Tag), dem Unterschied nach Gebühr als Fläche darunter und dem Absatz beider Seiten.

**Erfolgskontrolle** (später, Abschnitt 8): War eine Chance vor 3 Tagen grün, hat sie gehalten?

## 5. Weitergabe an Broker

In `Data.lua` beim Heimatmarkt eine neue Tabelle neben `chances`:

```lua
markets["<Heimat>"].cmp = {
    t = 1763640000, other = "<Neutral>", cutN = 1500, cutSure = false,
    list = { [Schluessel] = "Richtung:KaufenBis:Verkaufspreis:Netto:Absatz:Menge:Vorrat:Bestaendigkeit:Bewertung" },
    say  = { [Schluessel] = "Satz fuer den Tooltip" },
}
```

- Richtung `n` (Heimat nach Neutral) oder `h` (Neutral nach Heimat). Preise in Kupfer, Absatz mal 10, Vorrat in Zehntel Tagen, Beständigkeit in Prozent.
- Höchstens 150 Einträge je Richtung, die besten nach Bewertung, dazu alle angehefteten. Ohne die Grenze würde `Data.lua` zu groß.
- **Bridge 0.13.0:** neue Funktion `mod:Compare(market)` nach dem Muster von `mod:Chances`. Alte Bridge ohne die Funktion: Broker zeigt den Unterreiter mit dem Hinweis, Bridge zu aktualisieren.

## 6. Broker

### 6.1 Mehr, Neutral: Suche

- **Suchfeld** oben links über der Tabelle, wie in Einkaufen. Gesucht wird im Namen aller Gegenstände, die in mindestens einem der beiden Märkte vorkommen.
- Mit Suchtext gilt der Mindestunterschied nicht, man sieht also auch Gegenstände ohne Unterschied und solche, die nur in einem Markt stehen („fehlt“).
- **Neue Spalten:** Absatz Heimat und Absatz Neutral je Tag (aus `bridge:Sales`, ohne Manager „–“). Die Spalte „Besser in“ wird zu „Richtung“ mit Pfeil, Netto nach beiden Gebühren bleibt.
- Tooltip je Zeile: beide Preise, Gebühren, Absatz, und falls der Manager den Gegenstand als Chance führt, sein Satz.
- Rechtsklick wie bisher Gegenstandsmenü, Linksklick Seite Gegenstand.

### 6.2 Chancen, neuer Unterreiter „Markttausch“

- **Platz:** vierter Unterreiter nach Spekulation, Aufkauf, Schnellkauf. Abschaltbar wie die anderen.
- **Liste** aus `bridge:Compare`: Gegenstand, Richtung (Pfeil und Haus), Kaufen bis, Verkaufen für, Gewinn je Stück, Absatz im Ziel je Tag, Menge, Ampel, Zustand. Sortiert nach Bewertung des Managers.
- **Zustand und Prüfung live**, nur im Haus, an dem man steht:
  - Am Haus der Quelle prüft Broker das günstigste Angebot: „kaufbar“ (Menge unter Kaufen bis) oder „zu teuer“.
  - Am Haus des Ziels prüft Broker die Konkurrenz: „frei“ (günstigstes Angebot nicht unter dem Verkaufspreis) oder „unterboten“.
  - Laufend geprüft wird wie bisher nur der offene Unterreiter.
- **Klick:** am Haus der Quelle öffnet den Fokus im Aufkauf mit Kaufen bis und Menge des Managers. Am Haus des Ziels öffnet Verkaufen mit dem Gegenstand, falls er in der Tasche ist.
- **Merken für den Weg:** Gekaufte Posten bekommen das Ziel „Neutral“ oder „Heimat“ (`lots`). Verkaufen am Zielhaus hebt sie hervor. Damit vergisst man nichts zwischen den Häusern.
- **Ohne Manager:** Liste aus Brokers eigenen Daten, nur nach Preisunterschied, Hinweis „Ohne Peon Manager kein Absatz, Bewertung nur nach Preis“.
- **Hinweis beim Öffnen des neutralen Hauses:** „Im Gepäck: 4 Posten für Neutral“ (abschaltbar).

## 7. Reihenfolge des Baus

| Schritt | Inhalt | Versionen |
|---|---|---|
| M1 | Suche und Absatzspalten in Mehr, Neutral (geht sofort mit den vorhandenen Daten) | Broker |
| M2 | Rechnung `compare.js`, Reiter Marktvergleich mit Unterreitern, Abschnitt im Gegenstand | Manager |
| M3 | Weitergabe in `Data.lua`, `mod:Compare` | Manager, Bridge |
| M4 | Unterreiter Neutral in Chancen mit Live-Prüfung | Broker |
| M5 | Posten mit Ziel, Hinweis am Zielhaus, Erfolgskontrolle | Broker, Manager |

Vor M2 eine Messung mit der echten Datenbank: Wie viele grüne Chancen bleiben mit den Regeln aus 3.2, und stimmen Stichproben?

## 8. Entscheidungen (KarloDerBaer, 20.11.2026)

1. **Beide Richtungen** von Anfang an. Die Horde bleibt draußen.
2. **Gebühr Neutral:** noch nicht gemessen, 15 % Anteil annehmen, bis Broker ihn misst.
3. **Name des Unterreiters:** „Markttausch“.
4. **Keine Summe je Gang.**
5. **Ohne Manager** eine einfache Liste nur nach Preisunterschied.
6. **Eigener Anteil am Absatz und Haltedauer** deutlich kleiner und kürzer, aber einstellbar: Vorgabe 10 % und 1 Tag.

## 9. Umsetzung (20.11.2026)

- M1 bis M4 gebaut wie oben (Broker 0.127.0, Bridge 0.13.0, Manager 0.50.0).
- M5 vereinfacht: Gepäck für das Zielhaus mit Hinweis (`PeonBrokerDB.tradeGoods`), kein eigener Posten im Buch. Erfolgskontrolle für den Marktvergleich steht noch aus.
- Abweichungen: Der Manager vergleicht nur Gegenstände, die in beiden Häusern vorkommen (Gegenstände aus nur einem Haus findet die Suche in Broker). Die Einstellgebühr ist in der Rechnung noch nicht enthalten. Der Abschnitt Neutral auf der Seite eines Gegenstands zeigt Zahlen ohne eigenes Diagramm.

## 10. Zweite Runde (Vorgaben KarloDerBaer, 20.11.2026, umgesetzt in Broker 0.128.0, Bridge 0.13.1, Manager 0.51.0)

### 10.1 Markttausch in Broker nur mit Auswahl des Managers

- Der Unterreiter zeigt nur die Chancen, die der Manager ausgewählt hat. Ohne Daten vom Manager steht dort ein Hinweis, die einfache Liste nach Preisunterschied entfällt (ersetzt Entscheidung 5 aus Abschnitt 8).
- Broker fügt nie selbst etwas hinzu. Er entfernt eine Chance, wenn neue Preise ihre Bedingungen nicht mehr erfüllen: Spanne und Gewinn je Stück nach dem Anteil des Zielhauses, gerechnet mit dem jüngsten Preis beider Häuser. Entfernte bleiben weg, bis der Manager sie mit einem neueren Stand wieder schickt (wie `chancesGone`).
- Neue Preise kommen aus drei Quellen: laufende Abfrage der Zeilen am Haus, an dem man steht (solange der Unterreiter offen ist, reihum wie Beobachten), Komplettscan und Stand vom Manager.

### 10.2 Auswahl im Manager

- Nach jedem neuen Stand vergleicht der Manager beide Märkte und schickt die besten N an Broker, Vorgabe 10, einstellbar.
- Bewertung wie bisher (Gewinn je Tag, Beständigkeit, Vorrat im Ziel), dazu Langzeitwerte über 14 Tage: wie beständig der Unterschied über 14 Tage war, wie gleichmäßig der Absatz im Ziel ist (Tage mit Verkäufen) und ob der Unterschied wächst oder schrumpft.

### 10.3 Beobachten Markttausch

- Dritter Unterreiter in Beobachten (Broker) neben Aufkauf und Schnellkauf, und dieselbe Liste im Manager.
- Zeilen: Gegenstand, Richtung, Preis Fraktion, Preis Neutral, Spanne nach Gebühr, Absatz im Ziel, Zustand am Haus, an dem man steht.
- Hinzufügen über das Gegenstandsmenü („Beobachten: Markttausch“), aus der Liste Markttausch und im Manager.

### 10.4 Beobachten im Manager wie in Broker

- Unterreiter Aufkauf, Schnellkauf und Markttausch wie im Spiel.

### 10.5 Händler im Manager

- Seite wieder an (ohne WIP). Die Daten kommen schon heute aus `Peon_Broker.lua` (`vendors`). Aufbau wie Mehr, Händler in Broker.

### 10.6 Entscheidungen (KarloDerBaer, 20.11.2026)

- Schnellkauf und Haken der Listen werden mit dem Manager abgeglichen und sind dort änderbar.
- Beobachten Markttausch nur beobachten, ohne eigene Grenzen.
- Entfernte Chancen kommen erst mit einem neueren Stand des Managers wieder.

## 11. Dritte Runde (KarloDerBaer, 20.11.2026, umgesetzt in Ledger 0.17.0, Broker 0.128.1, Manager 0.52.0)

- **Einstellgebühr:** 5 % vom Händlerpreis mal 4 (8 Std.), im neutralen Haus gleich hoch gemessen. Verlust je Verkauf = Gebühr mal (1 durch Absatzquote minus 1).
- **Lücke im Ziel:** Verkäufe an mindestens 3 Tagen in 14 Tagen, aber kein Angebot jetzt oder kein Preis im Zeitraum. Verkaufspreis = Median der echten Verkäufe.
- **Ledger:** Haus an Bewegungen (`h`) und Posten. Ein Verkauf im anderen Haus als dem Kauf ist ein Markttausch, das Buch zeigt ihn als „davon Markttausch“. Broker nimmt die Ware für das andere Haus aus Ledger.
- **Manager:** Liste Chancen zeigt zuerst die Auswahl für Broker. Diagramm im Reiter Neutral, abschaltbar. Erfolgskontrolle: Auswahl je Tag gemerkt, nach 3 Tagen nachgeprüft, dazu echte Tausche aus Ledger.

## 12. Messung Anteil Neutral (20.11.2026)

Erster Verkauf im neutralen Haus: 20 Seidenstoff für 38s 20c, Anteil 5s 73c, also 15,0 %. Die Annahme von 15 % stimmt. Broker misst den Anteil beim Nehmen des Briefs, der Manager liest ihn danach aus `Peon_Broker.lua`.
