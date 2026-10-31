# Peon_Broker – Konzept Programm und Datenaustausch

Stand: 30.09.2026. **Abgelöst am 22.10.2026 durch `Peon_Client_Design.md`** (nur noch zum Nachlesen). Ergänzt `Peon_Broker_Konzept.md` und `Peon_Broker_Rechenmodell.md`.

## 1. Worum es geht

Broker bekommt ein Begleitprogramm auf dem PC (Arbeitsname **Broker-Programm**). Die Aufgaben sind klar verteilt:

| | Broker (im Spiel) | Broker-Programm (auf dem PC) |
|---|---|---|
| Aufgabe | Handeln: verkaufen, kaufen, eigene Auktionen, schnelle Übersicht | Langzeitdaten überwachen und auswerten |
| Daten | eigene Scans, Live-Abfrage beim Verkaufen | alle Scans dauerhaft, später zusätzlich die Blizzard-API |
| Zeigt | Tooltip, Reiter Verkaufen / Meine Auktionen / Einkaufen, kompakte Preise | Verlauf mit Diagrammen, Ranglisten, Schnäppchen, Buch-Auswertung |
| Liefert dem anderen | Scans und Buch-Einträge | Preisbereiche je Gegenstand („gut verkaufen ab …“, „günstig kaufen unter …“) |

## 2. Grundsätze (mit KarloDerBaer festgelegt, 30.09.2026)

- **Broker funktioniert auch ohne Programm voll.** Es rechnet weiter selbst nach dem Rechenmodell. Die Werte des Programms machen die Einschätzung nur besser.
- **Austausch nur über Dateien:** Broker schreibt in seine gespeicherten Einstellungen (WTF-Ordner), das Programm schreibt eine Datendatei, die das Spiel beim Start oder Reload einliest. Das Spiel schreibt nur bei Reload, Ausloggen oder Beenden. Einen anderen Weg gibt es nicht (TSM macht es genauso).
- **Kein Kopieren und Einfügen** von Texten zwischen Spiel und Programm.
- Das Programm greift nie ins laufende Spiel ein, es liest und schreibt nur Dateien.
- **Märkte bleiben getrennt** (Regelsatz / Fraktion), wie in Broker.
- **Datenquellen sind austauschbar:** heute Scans aus dem Spiel, später vielleicht die Blizzard-API (liefert für Forever bisher keine Auktionsdaten).
- Ziel: fertig zum Release. Datenverlust in der Beta ist nicht schlimm.

## 3. Datenfluss

```
Spiel: Broker scannt ──► PeonBrokerDB.export (WTF)  ──► Programm liest ein ──► eigene Datenbank
                                                                                 │
Spiel liest beim Start/Reload ◄── Peon_BrokerData\Data.lua ◄── Programm schreibt ┘
       (Preisbereiche, Empfangsbestätigung)
```

- **Spiel → Programm:** Das Programm überwacht die Datei `PeonBrokerDB` im WTF-Ordner. Sobald das Spiel sie schreibt (Reload, Ausloggen, Beenden), übernimmt es neue Schnappschüsse. Normalerweise genügt das Ausloggen am Ende einer Spielrunde.
- **Knopf „An Programm übergeben“** im Broker-Fenster: löst einen Reload aus. Nach einem Scan kann Broker das dezent anbieten. Das Auktionshaus schließt sich dabei.
- **Programm → Spiel:** Das Programm schreibt `Data.lua` in einen eigenen kleinen Addon-Ordner **`Peon_BrokerData`**. Vorschlag: eigener Ordner statt im Broker-Ordner, damit Updates von Broker die Datei nicht überschreiben und im Broker-Ordner nur Code liegt. Broker nutzt die Daten, wenn sie da sind (optionale Abhängigkeit).

## 4. Schnappschuss – das gemeinsame Format

Alles, was ins Programm kommt, ist ein **Schnappschuss**: der Zustand eines Auktionshauses zu einem Zeitpunkt, egal aus welcher Quelle.

| Feld | Inhalt |
|---|---|
| Markt | „Classic Beta PvE / Alliance“ |
| Zeit | Zeitpunkt des Scans |
| Quelle | „Scan“ (Spiel) oder später „API“ |
| je Gegenstand | Schlüssel (itemID bzw. itemID:suffixID), Name, Qualität |
| je Preisstufe | Preis je Stück, Menge, Anzahl Angebote |

Mit den Preisstufen kann das Programm später alles neu berechnen (Min, Median, andere Kennzahlen), auch wenn sich das Rechenmodell ändert.

- **In Broker:** Nach jedem Scan wird der Schnappschuss als kompakter Text in `PeonBrokerDB.export` abgelegt. Geschätzt 1–2 MB je Scan. Broker hält höchstens eine einstellbare Zahl (Vorschlag: 20, das sind etwa 5 Stunden bei einem Scan alle 15 Minuten), danach fällt der älteste weg.
- **Empfangsbestätigung:** Das Programm trägt in `Peon_BrokerData` ein, bis zu welchem Zeitpunkt es Schnappschüsse je Markt übernommen hat. Beim nächsten Start oder Reload löscht Broker diese. So bleibt die WTF-Datei klein, und nichts geht verloren.
- **Buch:** Verkäufe, Käufe und abgelaufene Auktionen erfasst Broker im Spiel (nur dort kommen die Meldungen an). Sie gehen auf demselben Weg ins Programm.

## 5. Datenquellen im Programm

- Für jede Quelle gibt es einen eigenen **Einleser**, der in das Schnappschuss-Format übersetzt: zuerst „Scan“ (aus der WTF-Datei), später „API“. Dahinter ist alles gleich.
- **Markt-Zuordnung:** Die API nennt Realms und Auktionshäuser über Nummern. Eine kleine Zuordnungstabelle verbindet sie mit „Regelsatz / Fraktion“.
- **Doppelte Daten:** Liefern Scan und API Daten zum selben Markt in kurzem Abstand, zählen beide als eigener Schnappschuss. Wie die Tageswerte dann gewichtet werden, wird im Rechenmodell festgelegt (offene Frage 4).
- Namen kommen aus den Scans. Die API liefert keine Namen; das Programm nutzt seine eigene Namensliste.

## 6. Rückweg: Preisbereiche für das Spiel

Das Programm liefert je Markt und Gegenstand wenige Werte:

| Wert | Bedeutung |
|---|---|
| üblicher Bereich (unten / Mitte / oben) | wo der Preis in den letzten Wochen meistens lag |
| „gut verkaufen ab“ | Preis liegt im oberen Bereich |
| „günstig kaufen unter“ | Preis liegt im unteren Bereich |
| Verlässlichkeit | wie viele Daten und wie viel Umsatz dahinterstehen |
| Stand | Zeitpunkt der Auswertung |

Wie genau diese Werte berechnet werden, kommt als neues Kapitel ins Rechenmodell und wird vorher abgestimmt.

**So nutzt Broker die Werte:**

- **Tooltip:** Einschätzung des Programms (Stand letzter Reload) neben den eigenen Scans seit dem Reload.
- **Verkaufen:** Broker fragt für den gewählten Gegenstand die aktuellen Angebote live beim Auktionshaus ab und vergleicht sie mit den Bereichen: „guter Zeitpunkt“, „unter dem üblichen Preis – lieber warten“ oder „lieber beim Händler verkaufen“. Der Preisvorschlag folgt weiter dem Rechenmodell.
- **Einkaufen / Schnäppchen:** Angebote unter „günstig kaufen unter“ werden hervorgehoben.
- **Ohne Programm oder mit alten Werten** (Vorschlag: älter als 7 Tage) zeigt Broker das an und stützt sich nur auf die eigenen Scans.

## 7. Das Programm

**Technik (Vorschlag):** ein kleines Programm in **Python**, das im Hintergrund läuft, die WTF-Datei überwacht, die Daten in einer Datenbankdatei (SQLite) speichert und seine Oberfläche **im Browser** anzeigt (nur auf deinem PC, nicht im Internet). Gründe: gut für Tabellen und Diagramme, und es lässt sich hier genauso testen wie das Addon.

- Damit du Python nicht installieren musst: eine eigenständige Python-Version liegt direkt im Programmordner, gestartet wird per Doppelklick.
- Programmordner (Vorschlag): `<Repo>\programm\` für den Quellcode. Die Datenbank liegt getrennt davon, damit sie bei Updates erhalten bleibt.

**Funktionen, in Stufen:**

1. Schnappschüsse einlesen und speichern, Empfangsbestätigung, einfache Übersicht (Märkte, letzte Scans, Anzahl Gegenstände).
2. Suche und Verlauf je Gegenstand mit Diagramm (Min, Median, Menge über Tage, Wochen, Monate, auch Tagesverlauf).
3. Preisbereiche berechnen und an Broker übergeben.
4. Ranglisten und Chancen: was sich lohnt, Händler-Schnäppchen, Dumping über längere Zeit, bester Wochentag.
5. Buch-Auswertung: Gewinn je Tag und Gegenstand, Verkaufsquote, Gebühren.
6. Blizzard-API als zweite Quelle, sobald verfügbar.

## 8. Auswirkungen auf Broker

Die Bauabschnitte 5–8 aus `Peon_Broker_Konzept.md` werden neu geordnet (Vorschlag):

| Nr. | Bauabschnitt | Wo |
|---|---|---|
| 5 | Schnappschüsse ablegen, Empfangsbestätigung, `Peon_BrokerData`, Knopf „An Programm übergeben“ | Broker |
| 6 | Programm Stufe 1 (einlesen, speichern, Übersicht) | Programm |
| 7 | Verkaufen mit Live-Abfrage und Preisvorschlag | Broker |
| 8 | Meine Auktionen | Broker |
| 9 | Programm Stufen 2–3 (Verlauf, Preisbereiche), Anzeige der Bereiche in Broker | beide |
| 10 | Einkaufen (Listen, Schnäppchen) mit Preisbereichen | Broker |
| 11 | Buch: Erfassung im Spiel, Auswertung im Programm | beide |
| 12 | Programm Stufe 4, später API | Programm |

- Der Reiter „Preise“ bleibt, wie er ist (kompakte Nachschlage-Hilfe), und wird nicht weiter ausgebaut.
- Die eigene Verdichtung in Broker (Tageswerte → Wochenwerte) bleibt, damit Broker ohne Programm funktioniert. Ob der Aufbewahrungszeitraum kürzer werden kann, wenn das Programm läuft, klären wir später.

## 9. Offene Fragen

1. Eigener Addon-Ordner `Peon_BrokerData` für die Daten des Programms – einverstanden?
2. Höchstens 20 Schnappschüsse im Spiel bis zur Abholung – passt das, oder lieber mehr bzw. weniger?
3. Knopf „An Programm übergeben“: Soll Broker ihn nach einem Scan von sich aus anbieten, oder nur auf Klick?
4. Scan und API zum selben Markt: beide speichern und im Rechenmodell gewichten – einverstanden, das später festzulegen?
5. Technik: Python mit Oberfläche im Browser – einverstanden, oder lieber ein klassisches Windows-Programm mit eigenem Fenster?
6. Neue Reihenfolge der Bauabschnitte (Abschnitt 8) – passt das?
