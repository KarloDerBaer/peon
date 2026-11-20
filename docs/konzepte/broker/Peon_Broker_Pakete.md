# Pakete im Markttausch

Stand: 20.11.2026, **umgesetzt in Manager 0.53.0, Bridge 0.14.0, Broker 0.129.0**, Entscheidungen von KarloDerBaer in Abschnitt 7. Vorgaben von KarloDerBaer vom 20.11.2026, ausgearbeitet von Claude. Baut auf `Peon_Broker_Marktvergleich.md` auf. Ausgangsversionen Broker 0.128.2, Ledger 0.17.0, Bridge 0.13.1, Manager 0.52.0.

## 1. Ziel

Ein neuer Chancentyp **Paket**, zunächst nur für den Markttausch. Ein Paket ist eine Einkaufsliste aus mehreren kleinen Angeboten, die das Risiko streut:

- viele verschiedene Gegenstände, je Angebot nur eine überschaubare Menge (Einzelstücke oder wenige Stück Massenware, die sich schnell verkaufen),
- das Paket bleibt im Gewinn, auch wenn nur ein Teil der Angebote verkauft wird (Vorgabe 50 %, einstellbar),
- der Manager stellt je Richtung ein Paket zusammen, Broker zeigt es in einer eigenen Liste mit Knöpfen zum Kaufen am Haus der Quelle und zum Verkaufen am Haus des Ziels,
- dazwischen geht das Paket auf Wunsch per Post an einen Twink,
- vor jedem Kauf und Verkauf prüft Broker den Preis live. Ist er nicht mehr lukrativ, ist der Knopf grau oder warnt.

## 2. Begriffe

| Begriff | Bedeutung |
|---|---|
| **Angebot** | eine Zeile im Paket: Gegenstand, Menge, Kaufen bis, Verkaufen ab, erwarteter Verkaufspreis |
| **Paket** | alle Angebote einer Richtung (Fraktion nach Neutral oder Neutral nach Fraktion) |
| **Einsatz** | Summe der Einkaufspreise aller Angebote |
| **Sicherheit** | Anteil der Angebote, der verkauft sein muss, damit das Paket noch Gewinn macht (Vorgabe 50 %) |

## 3. Zusammenstellen im Manager

Neue Funktion in `compare.js` nach der Rechnung des Marktvergleichs, je Richtung ein Paket.

### 3.1 Kandidaten für Angebote

Aus allen Kandidaten des Marktvergleichs (nicht nur der Auswahl der besten 10), dazu Lücken im Ziel:

- **Einzelstücke** (Ausrüstung, Rezepte, alles, was keine Massenware ist): Menge 1.
- **Massenware:** Menge so, dass sie im Ziel in höchstens einem Tag weg ist (Absatz je Tag mal eigener Anteil mal Haltedauer, wie bisher), höchstens 1 Stapel und höchstens ein Wert von 10 % des Pakets.
- Bedingungen wie bei den Chancen (Spanne, Gewinn je Stück, Beständigkeit), dazu eine **Verkaufswahrscheinlichkeit** je Angebot aus Absatzquote und Vorrat im Ziel.

### 3.2 Auswahl mit Streuung

- Höchstens ein Angebot je Gegenstand, höchstens 3 Angebote je Kategorie (zum Beispiel Stoff, Kräuter, Rüstung).
- Größe des Pakets: Vorgabe 8 Angebote, einstellbar 4 bis 24.
- Einsatz höchstens 10 % des Golds laut Ledger (ohne Ledger 25 Gold), einstellbar.
- **Gewinnprüfung:** Das Paket muss Gewinn machen, wenn nur der Anteil S (Sicherheit) der Angebote verkauft wird. Gerechnet wird vorsichtig: Verkauft werden genau die schlechtesten S Prozent der Angebote, die übrigen bleiben liegen und zählen mit 0. Abgezogen werden der ganze Einsatz, der Anteil des Zielhauses und die Einstellgebühren aller Angebote, auch der nicht verkauften.
- Auswahl gierig: Angebote nach erwartetem Gewinn je eingesetztem Gold sortieren, nacheinander aufnehmen, solange die Gewinnprüfung hält und die Grenzen nicht erreicht sind.

### 3.3 Anzeige im Manager

Auf der Seite Marktvergleich ein neuer Unterreiter **Pakete**: je Richtung das Paket mit Einsatz, erwartetem Gewinn, Gewinn bei S Prozent Verkauf und allen Angeboten. Einzelne Angebote lassen sich ausschließen, dann rechnet der Manager das Paket neu.

### 3.4 Weitergabe an Broker

In `Data.lua` beim Heimatmarkt neben `cmp`:

```lua
markets["<Heimat>"].pkg = {
    t = 1763640000, safe = 50,
    n = { stake = 123400, gain = 45600, gainSafe = 3200, list = { "Schluessel:Menge:KaufenBis:VerkaufenAb:Erwartet", ... } },
    h = { ... },
}
```

Bridge bekommt dafür `mod:Packages(market)`.

## 4. Liste in Broker

### 4.1 Ort

Neuer Unterreiter **Pakete** in Chancen, nur zu sehen, wenn Markttausch eingeschaltet ist. Oben je Richtung eine Zeile mit Einsatz, erwartetem Gewinn und Fortschritt („5 von 12 gekauft“, „3 von 12 eingestellt“, „2 verkauft“). Darunter die Angebote des gewählten Pakets.

### 4.2 Zeile je Angebot

Symbol, Name, Menge, Kaufen bis, Verkaufen ab, Zustand, und rechts ein Knopf, der vom Haus abhängt:

| Ort | Knopf | Prüfung live |
|---|---|---|
| Haus der Quelle | **Kaufen** | günstigstes Angebot für die Menge bis Kaufen bis? Sonst grau mit dem jetzigen Preis im Tooltip |
| Haus des Ziels | **Verkaufen** | günstigstes fremdes Angebot nicht unter Verkaufen ab? Sonst gelb mit Warnung „nicht mehr lukrativ“, ein zweiter Klick verkauft trotzdem |
| unterwegs | keiner | Zustand: gekauft, in der Post, beim Twink, eingestellt, verkauft |

### 4.3 Kaufen

- Der Knopf nutzt den Kaufweg des Fokus (Massenware über den Kauf mit Kaufen bis, Einzelstücke über das passende Angebot aus der jüngsten Abfrage). Ein Klick kauft genau die Menge des Angebots, nie mehr.
- Die Zeilen des Pakets werden am Haus der Quelle laufend abgefragt, solange die Liste offen ist (wie Markttausch).
- Gekauftes merkt sich Ledger mit dem Haus, Broker zählt es über `mod:HouseLots` als gekauft.

### 4.4 Verkaufen

- **Massenware:** Broker stellt selbst ein (wie das Lockangebot im Schnellkauf, `PostCommodity`), Preis 1 Kupfer unter dem günstigsten fremden Angebot, mindestens Verkaufen ab.
- **Einzelstücke:** Das Spiel erlaubt Broker kein eigenes Einstellen von Einzelstücken ohne Blizzards Fenster. Der Knopf legt das Stück per sicherem Klick ins Verkaufsfenster (wie „Verkaufen“ in Beobachten) und trägt den Preis ein (wie „Zielpreis eintragen“). Auktion erstellen klickt man in Blizzards Fenster.
- Laufzeit wie in den Einstellungen von Verkaufen.

### 4.5 Post an einen Twink

- Die Post ist nur eine Möglichkeit, kein eigener Schritt im Paket und kein eigener Knopf (KarloDerBaer).
- Ledger nimmt bei Post an einen eigenen Twink die Posten samt Haus des Kaufs mit (ab Ledger 0.17, `twink`, Posten unterwegs). Verkauft der Twink sie im anderen Haus, zählt das als Markttausch.
- Broker zeigt das Paket auf jedem Charakter. Gekauft, im Gepäck und verkauft liest er aus Ledger je Charakter (`mod:HouseLots`), dazu die eigenen Auktionen. Der Twink sieht deshalb am Zielhaus seine Stück mit dem Knopf Verkaufen.
- Grenze: Twinks auf einem anderen Konto teilen Ledgers Daten nicht. Dort fehlt das Haus des Kaufs, der Verkauf zählt dann als normaler Handel.

### 4.6 Nach dem Verkauf

- Verkauft: aus Ledger (Rechnung mit Haus). Das Paket zählt Erlös und Gewinn mit.
- Abgelaufen: Der Zustand zeigt „zurück“. Das Angebot kann erneut eingestellt werden, wenn der Preis noch passt.
- Ein Paket gilt als abgeschlossen, wenn alle Angebote verkauft oder ausgeschlossen sind oder nach 7 Tagen.

## 5. Erfolgskontrolle

Im Manager unter Erfolgskontrolle, Marktvergleich: je Paket Einsatz, Erlös, Gewinn, verkaufter Anteil und ob die Sicherheit gehalten hat. Grundlage sind die Bewegungen mit Haus aus Ledger.

## 6. Reihenfolge des Baus

| Schritt | Inhalt | Versionen |
|---|---|---|
| P1 | Zusammenstellen im Manager, Unterreiter Pakete im Manager, Weitergabe in `Data.lua` | Manager, Bridge |
| P2 | Liste Pakete in Broker mit Zustand und laufender Abfrage | Broker |
| P3 | Knopf Kaufen mit Prüfung | Broker |
| P4 | Knopf Verkaufen (Massenware selbst, Einzelstücke über Blizzards Fenster) | Broker |
| P5 | Erfolgskontrolle der Pakete | Manager |

## 7. Entscheidungen (KarloDerBaer, 20.11.2026)

1. **Größe und Einsatz:** Vorgabe 8 Angebote und höchstens 10 % des Golds, beides einstellbar.
2. **Verkaufspreis:** 1 Kupfer unter dem günstigsten fremden Angebot, nie unter Verkaufen ab.
3. **Einstellen durch Broker:** Massenware stellt Broker selbst ein. Einzelstücke über Blizzards Verkaufsfenster.
4. **Twink:** Die Post ist nur eine Möglichkeit, ohne eigene Einstellung oder Knopf. Ledger und das Einstellen am Zielhaus kommen damit über das Haus an den Posten klar.

## 8. Umsetzung (20.11.2026)

- Auswahl im Manager: gierig nach erwartetem Gewinn, mit jedem der 30 besten als Startangebot probiert, Pakete ab 4 Angeboten gehen vor. Ein Angebot höchstens ein Viertel des Einsatzes. Ohne das füllte ein teures Angebot das ganze Paket (Messung mit echten Daten).
- Verkaufen ab = Kaufpreis plus Einstellgebühr je Stück, geteilt durch (1 minus Anteil des Zielhauses).
- Broker: Aktion in einer eigenen Spalte (die Tabelle meldet nur die Zeile, die Spalte erkennt Broker an der Maus). Kaufen bestätigt selbst, wenn der Preis des Spiels bis Kaufen bis liegt. Einzelstücke über den sicheren Knopf unter der Liste, der Preis wird 0,3 Sek. danach eingetragen.
- Im Spiel noch nicht erprobt: eigenes Einstellen von Massenware mit Menge über 1, Eintragen des Preises nach dem sicheren Knopf.
