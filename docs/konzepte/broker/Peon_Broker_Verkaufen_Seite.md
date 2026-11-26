# Peon_Broker: Konzept eigene Seite Verkaufen

Stand: 26.11.2026, **von KarloDerBaer freigegeben** (Antworten auf Abschnitt 3 am selben Tag), umgesetzt ab Broker 0.141.0. Ausgangsversion Broker 0.140.0. Grundlage ist die Karte „Verkaufen“ im Board Broker von KarloDerBaer (26.11.2026) und seine Antwort, dass Verkaufen eine eigene Broker-Seite wird (nicht Blizzards Fenster umgeordnet).

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

## 3. Antworten von KarloDerBaer (26.11.2026)

1. **Einzelstücke:** Broker stellt alles selbst ein, Massenware mit `PostCommodity`, Einzelstücke mit `PostItem` (ohne Gebot, nur Sofortkauf).
2. **Zum Einstellen und Preisknöpfe:** auf die linke Seite. Günstige, Vorschlag, Letzter und Ziel stehen unter dem Preis, Zum Einstellen unten links mit dem sicheren Knopf, der einen Posten auf die Seite legt.
3. **Gegenstand je Seite:** Jede Seite behält ihren eigenen Gegenstand. Abgefragt wird nur der Gegenstand der offenen Seite. Wechselt man zurück ins Einkaufen, steht dort wieder der vorige Gegenstand und wird wieder abgefragt.

## 3a. Nachgelesen in Blizzards Quelltext (Zweig forever)

- Blizzards eigener Knopf ruft `C_AuctionHouse.PostCommodity(Gegenstand, Dauer, Menge, Stückpreis)` bzw. `PostItem(Gegenstand, Dauer, Menge, Gebot, Sofortkauf)`. Gibt das `true` zurück, wartet eine Rückfrage, sonst ist eingestellt.
- Die Rückfrage des Spiels (`AUCTION_HOUSE_POST_WARNING`) zeigt Blizzards Dialog. Er bestätigt nur Blizzards eigenen Vorgang, bei Brokers Einstellen tut er nichts. Broker bestätigt deshalb mit dem zweiten Klick auf seinen Knopf (wie beim Lockangebot).
- Blizzards Fenster prüft den Gegenstand an den wichtigen Stellen mit `IsValid`. Ist nach Brokers Einstellen nichts mehr übrig, bleibt Blizzards Fenster mit dem leeren Platz stehen, bis man den nächsten Gegenstand hineinlegt. Broker schreibt nicht hinein, damit Blizzards Ablauf beim Rechtsklick in der Tasche sauber bleibt.

## 4. Schritte

Alles in einem Schritt ab Broker 0.141.0 (`SellPage.lua`, `AHTabs.OpenSell`).
