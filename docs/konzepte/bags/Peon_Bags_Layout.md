# Peon_Bags: Layout und Platzsparen

Beschlossen am 16.11.2026 mit KarloDerBaer, gebaut in Bags 0.7.0. Baut auf `Peon_Bags_Anordnung.md` (Einstellen, Kategorien) auf.

## Ausgangslage

Je nach Einstellung blieb in den Fenstern viel Platz leer:

- Abschnitte kamen der Reihe nach dran. Passte einer nicht mehr in die Zeile, blieb der Rest der Zeile leer.
- Ein Abschnitt mit etwas mehr Gegenständen als Spalten belegte zwei volle Zeilen (12 Plätze bei 10 Spalten).
- Leere eigene Bereiche hatten einen langen Hinweis in der Überschrift, der breiter war als der Inhalt.
- Jeder freie Platz stand einzeln im Fenster.

## Umsetzung

Die Leiste „Einstellen“ bekommt zwei Reiter:

- **Kategorien:** alles, was bis 0.6 in der Leiste stand (Anordnung, Kategorien, eigene Bereiche).
- **Layout:** die Einstellungen zum Platzsparen, je Fenster.

Oben im Reiter Layout steht eine Vorauswahl:

| Vorauswahl | Nebeneinander | Lücken füllen | Große schmaler | Freie Plätze als einer | Leere Bereiche | Spalten automatisch |
|---|---|---|---|---|---|---|
| Untereinander | aus | aus | aus | aus | mit Hinweis | aus |
| Locker (wie bis 0.6) | an | aus | aus | aus | mit Hinweis | aus |
| Ausgewogen (Standard) | an | an | an | aus | als Platz | aus |
| Kompakt | an | an | an | an | beim Ziehen | an |

Weicht eine Einstellung von allen Vorauswahlen ab, zeigt die Liste „Individuell“. Gespeichert werden nur die einzelnen Werte, die Vorauswahl wird daraus erkannt. Die Spaltenzahl und die Breite je Abschnitt gehören nicht zur Vorauswahl.

Die Einstellungen im Einzelnen:

1. **Lücken füllen:** Ein Abschnitt kommt in die erste Zeile, in der er Platz hat, auch in eine frühere.
2. **Freie Plätze als ein Platz:** Ein echter leerer Platz je Taschenart mit der Zahl der freien Plätze. Ablegen legt den Gegenstand in genau diesen Platz, deshalb funktioniert es auch im Kampf.
3. **Leere eigene Bereiche:** mit Hinweis, als Platz (Name und Ablage-Platz) oder nur beim Ziehen eines Gegenstands.
4. **Große Abschnitte schmaler:** gleich viele Reihen, so wenig Spalten wie möglich.
5. **Breite je Abschnitt:** eigene Spaltenzahl je Abschnitt und Fenster, „auto“ lässt die anderen Einstellungen entscheiden.
6. Entfällt (Umbruch je Abschnitt), auf Wunsch von KarloDerBaer.
7. **Spaltenzahl automatisch:** Die Spaltenzahl bis zur eingestellten, bei der das Fenster die kleinste Fläche hat.
