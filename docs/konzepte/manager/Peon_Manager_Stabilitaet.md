# Peon Manager: Stabilität der Preise

Stand: 17.11.2026, umgesetzt mit Manager 0.45.0. Wunsch von KarloDerBaer: Wie stabil ist der Preis, für jeden Gegenstand, für Kategorien und für den ganzen Markt? Besonders wichtig sind die Stundenwerte und Massen- und Handwerksware.

## 1. Was gemessen wird

**Preis:** Bei Massenware die günstigsten 25 % (`p25`), sonst das günstigste Angebot (`min`). Entschieden von KarloDerBaer. Massenware heißt: Das Spiel kennt den Gegenstand als Massenware (`items.commodity`). Ist das unbekannt, gilt ein stapelbarer Gegenstand als Massenware (wie in Broker).

Der Index hat zwei Teile.

| Teil | Zeitraum | Quelle | Maß |
|---|---|---|---|
| Stunden | 7 Tage | Stände der Blizzard-API | Mittlere Bewegung von Stand zu Stand. Paare höchstens gut 2 Std. auseinander, die größten 5 % zählen nicht. Mindestens 48 Stände und im Schnitt 3 Angebote. |
| Tage | 14 Tage | Kennzahlen aller Komplettscans und Stände, ältere Tage aus den 3-Stunden-Werten | Schwankung der Tageswerte wie F36 (1,4826 × mittlere Abweichung ÷ Mitte, mindestens 5 %). Tageswert = Median aller Preise des Tages, mindestens 3 Preise je Tag und 5 Tage. |

Beide Teile messen Verschiedenes. Die Stundensicht sieht Zappeln um einen festen Preis, die Tagessicht sieht langsame Verschiebungen. Deshalb zählt der schlechtere Teil.

**Richtung:** erster zu letztem Tageswert, mit der Zahl der Tage. Sie steht daneben und zählt nicht in den Index.

## 2. Stufen und Index

| Stufe | Stunden | Tage | Index |
|---|---|---|---|
| sehr stabil | bis 1 % | bis 8 % | 80 bis 100 |
| stabil | bis 3 % | bis 15 % | 60 bis 80 |
| mittel | bis 6 % | bis 25 % | 40 bis 60 |
| unruhig | bis 10 % | bis 40 % | 20 bis 40 |
| unsicher | darüber | darüber | 0 bis 20 |

Je Teil verläuft der Index zwischen den Grenzen gleichmäßig, ab der letzten Grenze bis zum Doppelten auf 0. Die Grenze von 40 % bei den Tagen gilt in Broker und Manager schon als „unsicher“ (Entscheidungen 02.10.2026).

## 3. Kategorien und Markt

- Kategorien wie im Auktionshaus: Klasse und Unterklasse aus der Blizzard-API (`items.cls`, `sub`, `cls_name`, `sub_name`, Schema 15). Der Manager holt sie mit den Spieldaten jedes neuen Gegenstands, bekannte Gegenstände einmal nach.
- Wert einer Gruppe: Median der Indizes, dazu Median der beiden Teile und die Zahl je Stufe.
- Gruppen: ganzer Markt, Massenware, Handwerkswaren (Klasse 7), Einzelgegenstände.
- Gegenstände mit weniger als 20 Angeboten im Schnitt zählen nicht für Gruppen und Kategorien. Sie stehen nur auf ihrer eigenen Seite mit dem Hinweis „Wenig Angebote“.
- Verlauf: ein Eintrag je Rechnung, 30 Tage.

## 4. Wann gerechnet wird

Nach jedem neuen Stand im Rechen-Prozess, nachdem Data.lua geschrieben ist (`stabilityInBackground`). Ergebnis in `calc_cache` `stability`, Verlauf in `stabHist`. Mit echten Daten etwa 13 Sek. für den großen Markt, in Schritten.

## 5. Anzeige

- Übersicht (ab 0.46.0): Kachel mit Stufe und Index des ganzen Markts, Änderung zu gestern, darunter der Verlauf als Diagramm (Markt, Massenware, Handwerkswaren, Stufen als Bänder).
- Marktübersicht, Reiter Stabilität: vier Karten (Markt, Massenware, Handwerkswaren, Einzelgegenstände), Verlauf als Diagramm, Kategorien (aufklappbar, Klick filtert die Liste), Gegenstände mit Auswahl der Art, Suche und Sortierung.
- Gegenstandsseite: Stufe, Index, beide Teile, Richtung, Kategorie und Markt zum Vergleich.
- Markt-Liste (ab 0.46.0 Reiter Markt der Marktübersicht): Spalte Stabilität.

## 6. Messung mit echten Daten (17.11.2026, 7 Tage Stundenwerte, 166 Stände je Haus)

- Der Median der Stundenänderung liegt fast überall bei 0 %, weil sich der Preis in den meisten Stunden nicht bewegt. Darum zählt die mittlere Bewegung.
- Massenware mit mindestens 50 Angeboten, Allianz: Bewegung je Stunde zu 25/50/75/90 % unter 1,9 / 3,9 / 6,8 / 10,6 %. Schwankung der Tage 5,0 / 12,7 / 27,5 / 48,4 %.
- Beispiele Allianz (Stunden, Tage): Seidenstoff 0,4 % und 5,0 %, Leinenstoff 2,0 % und 5,3 %, Kupfererz 2,1 % und 16,8 %, Rauer Stein 7,2 % und 7,1 %, Malachit 11,4 % und 18,3 %.
- Die Rangfolgen beider Sichten hängen nur schwach zusammen (Allianz 0,52, Neutral 0,17). Beispiele: Teufelsleder je Stunde 1,9 %, aber 98 % gefallen in 8 Tagen. Aquamarin je Stunde 7 %, aber jeden Tag beim selben Preis.

## 7. Offen

- Grenzen in 2 bis 4 Wochen mit vollen 14 Tagen prüfen, wenn der Markt nach dem Start ruhiger ist.
- Ein einmaliger großer Sprung über die Tage (zum Beispiel Seidenstoff um 75 % gefallen, danach ruhig) bleibt bei der robusten Schwankung „sehr stabil“. Die Richtung zeigt ihn. Ob sie mitzählen soll, entscheidet KarloDerBaer.
- Anzeige im Spiel (Broker-Tooltip) über Data.lua, wenn gewünscht.
