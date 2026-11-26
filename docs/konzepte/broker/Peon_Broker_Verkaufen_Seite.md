# Peon_Broker: Konzept eigene Seite Verkaufen

Stand: 26.11.2026, **Entwurf, noch nicht freigegeben**. Ausgangsversion Broker 0.140.0. Grundlage ist die Karte „Verkaufen“ im Board Broker von KarloDerBaer (26.11.2026) und seine Antwort, dass Verkaufen eine eigene Broker-Seite wird (nicht Blizzards Fenster umgeordnet).

## 1. Ziel

Der Reiter Verkaufen wird aufgebaut wie Einkaufen: links die Eingaben, rechts der Markt.

- **Rechts oben** die aktuellen Angebote, alle 0,7 Sek. abgefragt (wie im Einkaufen).
- **Rechts darunter** Hinweise und Werte, aufgeräumter als der bisherige Kasten, als kleine Tabelle. Dazu die Marktlage wie im Einkaufen (die drei einstellbaren Zeilen).
- **Links** Einstellpreis, Menge (Regler: links 1, rechts alles in den Taschen), Dauer, Einstellgebühr, Gesamtpreis, Gewinn und die Knöpfe. Wie sich der Gewinn zusammensetzt, steht nur im Tooltip.

## 2. Technik

1. **Fläche über Blizzards Verkaufsfenster.** Wählt Blizzard die Ansicht Verkaufen (Reiter Verkaufen oder Rechtsklick in der Tasche), legt Broker seine eigene Fläche darüber, wie bei den eigenen Reitern. Blizzards Fenster bleibt darunter unverändert und hält weiter den Gegenstand.
2. **Gegenstand hineinlegen** bleibt Blizzards Weg: Rechtsklick in der Tasche. Broker ruft nie `SetPostItem` oder `SetDisplayMode` auf (Fehlerberichte 10 und 11). Den Gegenstand liest Broker aus Blizzards Fenster (`GetItem`).
3. **Einstellen** über einen eigenen Knopf: Massenware mit `C_AuctionHouse.PostCommodity`, wie das Lockangebot. Einzelstücke mit `C_AuctionHouse.PostItem`, das hat Broker bisher nie selbst aufgerufen (Pakete legen Einzelstücke nur ins Fenster).
4. **Einstellgebühr** über `CalculateCommodityDeposit` bzw. `CalculateItemDeposit`.
5. **Angebote alle 0,7 Sek.** über dieselbe laufende Abfrage wie im Einkaufen.
6. **Blizzard pur** zeigt weiter nur Blizzards Fenster.

## 3. Offene Fragen an KarloDerBaer

1. **Einzelstücke:** Soll Broker sie selbst einstellen (`PostItem`, im Spiel noch nicht erprobt), oder beim ersten Schritt nur Massenware, und Einzelstücke laufen vorerst über Blizzards Knopf?
2. **Zum Einstellen:** Die Liste der Posten (Knopf „Zum Einstellen (n)“) und die Knöpfe Günstige, Vorschlag, Letzter, Ziel. Sollen sie links unter die Knöpfe, oder rechts als eigene Ansicht statt der Angebote?
3. **Marktlage:** Teilt sich die laufende Abfrage mit dem Einkaufen. Ist es in Ordnung, wenn das Einkaufen danach den zuletzt verkauften Gegenstand zeigt, oder soll jede Seite ihren eigenen Gegenstand behalten (dann zwei Abfragen im Wechsel, also jede nur halb so oft)?

## 4. Schritte

- V1: Fläche, Gegenstand lesen, Angebote rechts, Eingaben links, Einstellen für Massenware.
- V2: Hinweise als Tabelle, Marktlage, Gewinn mit Tooltip.
- V3: Einzelstücke und Zum Einstellen nach den Antworten auf Abschnitt 3.
