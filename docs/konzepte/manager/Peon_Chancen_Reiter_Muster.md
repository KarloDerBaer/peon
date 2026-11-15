# Chancen: Reiter in Broker, Muster nach Tageszeit und Wochentag, Händler nur im Radar

Stand: 15.11.2026, Entscheidungen von KarloDerBaer vom selben Tag. Baut auf `Peon_Manager_Chancen.md` auf.

## 1. Ziel

Die Chancen des Peon Managers sind Beobachtungen über Tage. Im Spiel werden sie nur noch bestätigt. Das Radar in Broker bleibt für das, was ein Scan gerade jetzt findet. Beides bekommt eine eigene Seite.

## 2. Händler nur noch im Radar

- Händler-Angebote sind meist nach weniger als einer Stunde weg. Broker findet sie beim Scan selbst.
- Im Manager entfallen die Art Händler, der Reiter „Nur live erreichbar“, die Zeile Händler in der Erfolgskontrolle und die Händler-Kandidaten für Broker. Die Rechenfunktion wird gelöscht (KarloDerBaer).
- Der Händlerpreis selbst bleibt im Manager, er zählt für die Einstellgebühr.

## 3. Reiter Chancen in Broker

- **Name und Platz:** „Chancen“, rechts neben Radar. Der Fokus wandert nach links neben Beobachten. Reihenfolge: Markt, Verkaufen, Auktionen, Einkaufen, Fokus, Beobachten, Radar, Chancen, Mehr.
- **Liste:** alle Chancen vom Manager mit Art (Spekulation, Langfristig, Aufkauf, Muster), Gewinn, Kaufen bis, Zielpreis und Zustand. Der Satz des Managers und das Alter seines Stands stehen im Tooltip.
- **Zustand je Zeile:** ungeprüft, bestätigt (mit Alter der Prüfung) oder weg. Am Auktionator prüft Broker die Zeilen nacheinander live, wie das Erneuern im Radar.
- **Knopf „Alle prüfen“:** fragt alle Kandidaten einmal ab. Er ersetzt die Auswahl „Vom Manager“ im Radar-Scan.
- **Klick auf eine Zeile:** öffnet den Fokus, Kauf wie bisher.
- **Muster:** Liegt die Uhrzeit im günstigen Zeitfenster, ist die Zeile hervorgehoben, sonst steht dort „ab 21 Uhr“.
- **Einstellungen** (Knopf auf der Seite, Fenster wie beim Radar): Arten an oder aus, Hinweis beim Öffnen des Auktionshauses („3 Chancen vom Manager warten“), Meldung, wenn ein günstiges Zeitfenster beginnt.

## 4. Radar ohne Manager

Das Radar zeigt keine Kandidaten des Managers mehr. Es bleiben Händler, Aufkauf und die Beobachtung. Die Einstellung „Spekulation zeigen“ und die Auswahl „Vom Manager“ entfallen.

## 5. Muster nach Tageszeit und Wochentag (Art Muster im Manager)

**Messung am 14.11.2026** mit 10 Tagen Daten: Ohne Bereinigung schien abends 21 bis 24 Uhr fast alles am günstigsten. Das war der Abwärtstrend des jungen Markts. Bereinigt blieben 127 von 4039 Gegenständen, fast nur einzelne Ausrüstungsteile, vermutlich Zufall. Die Art meldet sich darum erst, wenn ein Muster wirklich hält.

**Rechnung** (einmal am Tag je Markt):

- Preise je Tag und 3-Stunden-Abschnitt (Ortszeit des Rechners) aus den Ständen der letzten 28 Tage.
- Abwärts- oder Aufwärtstrend herausrechnen: Jeder Abschnitt wird mit dem Tagesmittel verglichen, das zwischen den Tagen gleitend verläuft.
- **Tageszeit:** mindestens 14 Tage, an mindestens 70 % der Tage derselbe günstigste Abschnitt, Abstand zwischen günstigem und teurem Abschnitt nach Gebühr mindestens 15 %.
- **Wochentag:** mindestens 3 Wochen, derselbe günstigste Wochentag in mindestens 3 Wochen und 75 % der Wochen, Abstand nach Gebühr mindestens 15 %.
- Nur Gegenstände, die im Schnitt mindestens 5 Angebote haben.

**Prüfungen der Chance:** Muster gefunden, Preis fällt nicht, Schwankung höchstens 40 %, Absatz mindestens 1 am Tag, Einsatz passt zum Gold, Abstand zwischen Kaufen bis und Zielpreis nach Gebühr mindestens 10 %.

**Werte:** Kaufen bis = üblicher Preis mal Anteil im günstigen Fenster, Zielpreis = üblicher Preis mal Anteil im teuren Fenster. Menge höchstens ein Tagesabsatz und das Gold.

**Satz:** „Am günstigsten 0 bis 3 Uhr, am teuersten 9 bis 12 Uhr, an 11 von 14 Tagen so.“

**Übergabe an Broker** (Data.lua, Eintrag der Liste): `m:KaufenBis:Zielpreis:GültigBis:Gewinn:Risiko:Menge:Kaufen:Verkaufen`, Fenster als `Wochentage/Abschnitt` (Wochentage als Zahl aus 7 Bits, Montag = 1, alle Tage = 127; Abschnitt 0 bis 7, `-1` = ganzer Tag).

**Nachprüfung:** nach 3 Tagen, wie die anderen Arten.

## 6. Später

- Muster aus Tageszeit und Wochentag zusammen (braucht deutlich mehr Wochen).
- Bester Zeitpunkt zum Verkaufen aus den belegten Verkäufen je Abschnitt, sobald genug da sind.
