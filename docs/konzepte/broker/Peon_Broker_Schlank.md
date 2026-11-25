# Peon_Broker: Konzept schlank und bequem

Stand: 24.11.2026, **von KarloDerBaer freigegeben** (Entwurf A „Aufgeräumt“ mit Seitenleiste). Ausgangsversion Broker 0.130.3. Skizzen: Artifact-Seite „Broker schlank“. Das Konzept baut auf `Peon_Broker_Neuaufbau.md` auf und ändert dort die Reiter, den Fokus und Beobachten. Rechenregeln stehen weiter in `Peon_Broker_Rechenmodell.md`.

## 1. Ausgangslage

Antworten von KarloDerBaer (24.11.2026):

- Am meisten Gold bringt der **Schnellkauf**. Täglich genutzt werden der Schnellkauf im Fokus und Beobachten, Unterreiter Schnellkauf, um schnell zwischen den Gegenständen zu springen.
- Verkaufen und die Einkaufsliste werden ebenfalls genutzt, den Markt sucht KarloDerBaer ab und zu von Hand durch.
- Chancen und Gegenstand werden selten genutzt. Dort hilft vor allem mehr Übersicht.
- Den Modus Aufkauf im Fokus nutzt KarloDerBaer nicht mehr. Die anderen Chancen sind derzeit zu riskant, weil es viele Chancen mit geringer Aussicht gibt. Bei seltenen Gegenständen auf Stufe 60 könnten sie später wieder lohnen.
- Die Einstellungen des Schnellkaufs und das Diagramm sind sehr hilfreich. Das Diagramm soll einstellbar werden.
- Die Einkaufsliste ist zu umständlich. Nach einem Kauf muss man von Hand löschen.
- Das Lockangebot nutzt KarloDerBaer selten, ein Freund aber oft. Es bleibt und darf wachsen, zum Beispiel Preis drücken mit mehreren Teilen.
- Eingestellt wird viel in Massen: Beute und Ware aus dem Schnellkauf, über Blizzards Verkaufen.
- Kein Nutzungszähler (Entscheidung vom 24.11.2026 aus der Konzept-Session Ledger, Manager, Einstellungen).

Geprüfte Entwürfe: A Aufgeräumt, B Einkaufen mit Seitenleiste statt Reiter Beobachten, C Handelsplatz (Kaufen und Einstellen in einem Fenster). **Gewählt: A, dazu die Seitenleiste aus B mit Beobachten und Einkaufsliste** (KarloDerBaer, 24.11.2026).

## 2. Grundsätze

1. **Der Schnellkauf ist die Hauptseite.** Er heißt künftig Einkaufen und taugt auch zum ganz normalen Einkaufen.
2. **Nichts wird gelöscht.** Was kaum genutzt wird, ruht hinter einem Schalter. Code und gespeicherte Daten bleiben.
3. **Speichern geschieht von selbst.** Jede Eingabe gilt sofort.
4. **Sprünge über das Menü.** „Gegenstand“ und „Im Markt zeigen“ stehen im Rechtsklick-Menü, nicht als Knöpfe auf jeder Seite.
5. **Selten Gebrauchtes klappt zu.** Lockangebot und weitere Einstellungen sind aufklappbar und merken sich ihren Zustand.

## 3. Reiter danach

| Reiter | Inhalt | bisher |
|---|---|---|
| Kaufen | Blizzards Kaufen mit Brokers Zeilen | Markt |
| Verkaufen | Blizzards Verkaufen mit Rat und „Zum Einstellen“ | gleich |
| Auktionen | eigene Liste über Blizzards Ansicht | gleich |
| **Einkaufen** | ein Gegenstand, kaufen, Lockangebot, Diagramm (Abschnitt 4) | Fokus, Modus Schnellkauf |
| **Beobachten** | eine Liste mit gleichen Spalten (Abschnitt 6) | Beobachten mit drei Unterreitern |
| **Listen** | Einkaufslisten (Abschnitt 7) | Einkaufen |
| Chancen | Schnellkauf-Vorschläge, der Rest hinter „Weitere Chancen“ (Abschnitt 8) | fünf Unterreiter |
| Mehr | Gegenstand, Händler, Neutral, Datenlage | gleich |

- Blizzards Reiter heißt im deutschen Spiel ohnehin „Kaufen“. Brokers Reiter Markt zeigt am Auktionator Blizzards Kaufen und unterwegs den Markt aus Scandaten. Er heißt weiter „Markt“ (KarloDerBaer, 24.11.2026). Wichtig ist nur, dass „Einkaufen“ eindeutig die Hauptseite meint.
- Der Menüpunkt „In den Fokus“ heißt künftig „Einkaufen“.
- Der Reiter Beobachten bleibt neben der Seitenleiste, weil man dort die Werte einstellt und alle Spalten sieht. Die Leiste dient nur dem schnellen Wechsel.

## 4. Einkaufen (bisher Fokus, Schnellkauf)

```
┌ Seidenstoff (Rechtsklick: Menü) ─┐┌ Angebote jetzt ───────────────┐┌ Leiste »
│ Kaufen                            ││ 1s 52c     40    60s 80c      ││ [Beobachten] [Liste]
│  Kaufen bis      [1s 90c]         ││ 2s 08c  1.200    25g 56s      ││ Seidenstoff
│  Menge   1 ───────────● Alle (40) │└───────────────────────────────┘│ Wollstoff
│  Goldreserve     [200g]           │┌ Verlauf ──────────────────────┐│ Magiestoff
│  Markt   ⤓ 12 rein  ⤒ 18 raus/Min ││ (Diagramm)                    ││
│  Einbruch        1s 40c · 3×      ││ [Günstigster][Kaufen bis]     ││
│  Gekauft heute   120 · Ø 1s 62c   ││ [Menge darunter][Einbrüche]   ││
│  [ Kaufen 40 für 60s 80c ] [Auto] ││ [Lockangebote]   5 · 15 · 60  ││
│ ▸ Lockangebot                     │└───────────────────────────────┘│
│ ▸ Mehr Einstellungen              │                                 │
└───────────────────────────────────┘                                 └
```

### 4.1 Kaufen

- **Kaufen bis:** wie heute.
- **Menge** (Regler, wie früher im Aufkauf): von 1 bis ganz rechts „Alle“, also alles, was gerade unter Kaufen bis angeboten wird. Vorgabe für Massenware „Alle“, für andere Gegenstände 1. Kommt der Gegenstand aus der Einkaufsliste, steht der Regler auf dem, was noch fehlt.
- **Goldreserve** ersetzt das Limit pro Kauf. So viel Gold bleibt nach jedem Kauf mindestens übrig, die Menge wird notfalls gekürzt. Was ein Klick höchstens kostet, ergibt sich aus Kaufen bis und Menge und steht auf dem Kaufknopf („Kaufen 40 für 60s 80c“). Die Goldreserve gilt für alle Gegenstände, Kaufen bis und Menge je Gegenstand.
- **Markt:** Zufluss und Abfluss je Minute nebeneinander mit Symbolen (⤓ rein, ⤒ raus). Die Bewegung (lebhaft, mäßig, ruhig) färbt die Zeile leicht ein, Einzelheiten im Tooltip.
- **Einbruch** und **Gekauft heute** (mit Durchschnitt) bleiben, der letzte Kauf steht klein unter dem Kaufknopf.
- **Auto** und Bestätigen bleiben wie heute.
- In den Tooltip der Zeile Markt wandern: fremde und eigene Lockangebote, Preissprünge und Langfristig (14 Tage).

### 4.2 Lockangebot (aufklappbar, Vorgabe zu)

- Lockpreis wie heute. Darunter **Menge** und rechts davon der Knopf **Einstellen**. Der Knopf „Zurückziehen“ entfällt.
- Kommt vorab als kleiner eigener Schritt (U0), noch vor dem Umbau.
- Vorgemerkt für später: **in Teilen einstellen**, also mehrere kleine Stapel mit fallendem Preis, um den Preis zu drücken. Jeder Teil braucht einen eigenen Klick, der Knopf zählt mit („Einstellen 2 von 3“).

### 4.3 Mehr Einstellungen (aufklappbar, Vorgabe zu)

Die Haken „Durchschnitt zählt“ und „Lockangebot ignorieren“. Alles Weitere steht im Fenster Einstellungen (kleines Symbol oben rechts).

### 4.4 Diagramm

- Linien zum Ein- und Ausschalten als kleine Knöpfe unter dem Diagramm: Günstigster, Kaufen bis, Menge darunter, Einbrüche, Lockangebote.
- Zeitraum 5, 15 oder 60 Minuten.
- Die Wahl gilt für alle Gegenstände und bleibt gespeichert.

### 4.5 Was entfällt oder ruht

| Teil | Wohin |
|---|---|
| Knopf Speichern | entfällt, jede Eingabe wird sofort gespeichert. Ein Gegenstand kommt in Beobachten, sobald man ein Kaufen bis einträgt oder im Menü „Beobachten“ wählt |
| Knöpfe Gegenstand, Im Markt zeigen | nur im Rechtsklick-Menü auf den Namen |
| Knöpfe Zurück, Einstellungen | kleine Symbole in der Kopfzeile |
| Umschalter Aufkauf, Schnellkauf | entfällt. Der Modus Aufkauf ruht und lässt sich im Fenster Einstellungen unter „Erweitert“ wieder einschalten |
| Zeilen Bewegung, Langfristig | in den Tooltip (4.1) |
| Limit pro Kauf | wird Goldreserve. Gespeicherte Limits bleiben erhalten, werden aber nicht mehr angezeigt |

## 5. Seitenleiste

- Hängt rechts außen am Fenster (am Auktionator und unterwegs), klappt über einen Griff auf und zu. Der Zustand bleibt gemerkt.
- Oben zwei kleine Reiter: **Beobachten** und **Liste**. Unter Liste wählt man die Einkaufsliste aus.
- Je Zeile **nur der Gegenstand** (Symbol und Name), keine Werte (KarloDerBaer, 24.11.2026). Werte und Einstellungen stehen im Reiter Beobachten und in Listen. Der Gegenstand, der gerade im Einkaufen steht, ist hervorgehoben. Erledigtes aus der Einkaufsliste ist grau.
- Ein Klick setzt den Gegenstand ins Einkaufen. Rechtsklick öffnet das übliche Menü.
- Machbarkeit: Die Leiste ist ein eigener Rahmen aus `UI.Panel` und `UI.ScrollList`, außen am Fenster verankert. Blizzards Fenster wird nicht verändert. Die Breite (etwa 180 Punkte) wird im Spiel geprüft.

## 6. Beobachten: eine Liste statt drei

| Spalte | Bedeutung |
|---|---|
| Gegenstand | Name, bei Markttausch ein kleiner Hinweis „Neutral“ |
| Günstigster | günstigstes Angebot im letzten Stand |
| Kaufen bis | eigener Wert |
| Treffer 7 T. | Treffer je Stunde beobachteter Zeit in den letzten 7 Tagen (Angebot unter Kaufen bis aufgetaucht) |
| Einbrüche 7 T. | Einbrüche je Stunde beobachteter Zeit in den letzten 7 Tagen |
| Jetzt | Treffer seit Beginn dieser Sitzung am Auktionshaus, mit Punkt |

### 6.1 Der Punkt in „Jetzt“

Grün, wenn die Treffer je Stunde gerade über dem Wert der 7 Tage liegen, rot darunter, grau bei zu wenig Beobachtungszeit (unter 10 Minuten). Im Tooltip stehen Bewegung, Zufluss, Abfluss und Einbrüche jetzt.

### 6.2 Was sich ändert

- Die Unterreiter Aufkauf, Schnellkauf und Markttausch entfallen. Alle Einträge stehen in einer Liste. Zielpreis und Rat aus dem Aufkauf ruhen mit dem Modus Aufkauf. Die Spalten des Markttauschs stehen im Tooltip und in Chancen.
- Die Spalten Darunter, Bewegung und Tief 24 Std. wandern in den Tooltip.
- Die Knöpfe Entfernen, Verkaufen und Warnung bleiben. Entfernen kommt zusätzlich ins Menü.
- Die gespeicherten Werte je Modus (`watch`, `qmax`, `mode`) bleiben erhalten.

## 7. Einkaufsliste (Reiter Listen)

| Spalte | Bedeutung |
|---|---|
| Gegenstand | Name |
| Brauche | gewünschte Menge, mit Regler änderbar |
| Fehlt | Brauche minus Gekauftes |
| Höchstpreis | wie heute |
| Günstigstes | mit Hinweis „Händler“, wenn ein Händler günstiger ist |
| × | Zeile löschen |

- **Sofort abziehen:** Jeder Kauf zählt sofort, egal ob aus Brokers Einkaufen oder aus Blizzards Kaufen. Broker kennt Menge und Gegenstand aus dem Kaufstart des Spiels.
- **Erledigt:** Ist alles gekauft, wird die Zeile grau und bleibt stehen. Das × löscht sie. Ein neuer Wert am Regler macht sie wieder aktiv.
- Links bleiben die Listen, rechts die Gegenstände wie heute. Die Kaufzeile unter der Liste entfällt, gekauft wird im Einkaufen (Klick oder Seitenleiste).

## 8. Chancen

- Sichtbar bleibt nur **Schnellkauf** (die Vorschläge, die Beobachten füttern), ohne Unterreiterleiste.
- Ein Schalter **„Weitere Chancen“** (Vorgabe aus) im Fenster Einstellungen unter Erweitert bringt die Unterreiter Spekulation, Aufkauf, Markttausch und Pakete zurück. Alles Laufende (Abfragen, Radar-Scan) bleibt aus, solange der Schalter aus ist.
- **Pakete** (wenn eingeschaltet): eine Zeile je Paket mit Richtung, Zahl der Angebote, Einsatz, Gewinn und Stand („2 von 6 gekauft“). Aufgeklappt zeigt das Paket seine Angebote mit Kaufen und Verkaufen wie heute.

## 9. Verträglichkeit

- Gespeicherte Daten bleiben alle erhalten: Listen, Beobachten mit allen Modi, Limits, `quickHide`, `quickStats`, `quickMove`, `tradeGoods`.
- Neue Einstellungen: Goldreserve, Linien und Zeitraum des Diagramms, Zustand der Leiste und der aufklappbaren Bereiche, Schalter „Weitere Chancen“, Schalter Aufkauf.
- Die Schnittstellen für andere Module bleiben unverändert (`mod:AddToList` und so weiter). Profession setzt Material weiter auf Listen.
- Die Kern-API wird höchstens erweitert, etwa um aufklappbare Zeilen in `UI.Table` für die Pakete.

## 10. Umsetzungsschritte

Jeder Schritt ist eine eigene Broker-Version und läuft in einer eigenen Session. Fast alle Schritte ändern `Locales.lua`, die TOC und den Changelog. Deshalb laufen sie **nacheinander** auf main, nicht gleichzeitig.

| Schritt | Inhalt | Dateien (Schwerpunkt) | Größe |
|---|---|---|---|
| **U0 Lockangebot** | Menge, Knopf „Einstellen“ rechts, Zurückziehen entfällt (4.2) | `Focus.lua`, `Quick.lua` | klein |
| **U1 Einkaufen** | Reiter umbenennen, nur Schnellkauf, Speichern von selbst, Knöpfe ins Menü, Menge und Goldreserve, Zeile Markt, aufklappbare Bereiche, Aufkauf ruht (3, 4.1, 4.3, 4.5) | `Focus.lua`, `Quick.lua`, `Window.lua`, `AHTabs.lua`, `Menu.lua` | groß |
| **U2 Diagramm** | Linien und Zeitraum wählbar (4.4) | `Focus.lua` | klein |
| **U3 Beobachten** | eine Liste, Spalten 7 Tage und Jetzt mit Punkt (6) | `WatchPage.lua`, `QuickStats.lua` | mittel |
| **U4 Einkaufsliste** | sofort abziehen, grau, ×, Regler, Menge im Einkaufen aus der Liste (4.1, aus U1 verschoben) (7) | `Shop.lua`, `Buy.lua` | mittel |
| **U5 Seitenleiste** | Leiste mit Beobachten und Liste (5), braucht U1, U3 und U4 | neue Datei `Side.lua`, `Window.lua` | mittel |
| **U6 Chancen** | nur Schnellkauf sichtbar, Schalter „Weitere Chancen“, Pakete je Zeile (8) | `Chances.lua`, `Packages.lua`, ggf. Kern `UI.Table` | mittel |
| **U7 Einstellungen** | Broker nach dem Leitfaden `Peon_Einstellungen_Leitfaden.md` | `Settings.lua`, `Options.lua` | mittel |

- Reihenfolge: U0, dann U1 bis U6 in dieser Folge, U7 zum Schluss (wie im Leitfaden vorgesehen).
- Stand: U0 in Broker 0.132.0, U1 in Broker 0.133.0, U2 in Broker 0.134.0, U3 in Broker 0.135.0, U4 in Broker 0.136.0, U5 in Broker 0.137.0, U6 in Broker 0.138.0, U7 in Broker 0.139.0. Damit sind alle Schritte umgesetzt. Abweichungen in U1 (Entscheidungsprotokoll 25.11.2026): Der Reiter der Einkaufslisten heißt schon ab U1 „Listen“, sonst gäbe es zwei Reiter „Einkaufen“. Die Goldreserve ist die vorhandene `radarReserve`. Die Menge aus der Einkaufsliste kommt mit U4.
- Abweichungen in U2 (Entscheidungsprotokoll 25.11.2026): Der Knopf für die Menge heißt kurz „Menge“, damit alle fünf Knöpfe in eine Zeile passen. Der Zeitraum steht oben rechts im Diagramm statt neben den Knöpfen. Fremde Lockangebote stehen blass neben den eigenen.
- Abweichungen in U3 (Entscheidungsprotokoll 25.11.2026): Die Glocke der Warnung bleibt als schmale Spalte hinter Kaufen bis. Eine Sitzung für „Jetzt“ beginnt beim Öffnen des Auktionshauses nur, wenn es mindestens 10 Minuten zu war. Ohne Aufkauf hat das Menü nur noch den Haken „Beobachten“ statt Aufkauf und Schnellkauf.
- Abweichungen in U4 (Entscheidungsprotokoll 25.11.2026): Fehlt bleibt Brauche minus Vorrat, dazu minus Gekauftes, das noch unterwegs ist (KarloDerBaer). Doppelklick in der Liste öffnet das Einkaufen statt den Markt. Der Regler steht unter dem Feld Brauche, nicht in der Zeile.
- Entscheidungen in U5 (Entscheidungsprotokoll 25.11.2026): Die Leiste hängt immer am Auktionshaus, auch in Blizzards Ansichten, Vorgabe offen (KarloDerBaer). Die Auswahl der Einkaufsliste ist dieselbe wie im Reiter Listen.
- Abweichungen in U6 (Entscheidungsprotokoll 25.11.2026): Der Schalter „Weitere Chancen“ steht in den Einstellungen der Chancen unter Erweitert (nicht im Fenster des Einkaufens). Die Pakete kommen ohne Erweiterung der Kern-API aus.
- **Manager:** In der Seitenleiste des Managers (Konzept `Peon_Manager_Schlank.md`) heißt der Unterreiter unter Listen künftig „Einkaufslisten“ statt „Einkaufen“, damit die Namen zu Broker passen. Beobachten zeigt dort dieselben Spalten wie in 6.
- Vorgemerkt, nicht Teil dieses Plans: Lockangebot in Teilen (4.2), Einstellen im Einkaufen aus Entwurf C.

## 11. Abstimmung mit KarloDerBaer

### Geklärt (24.11.2026)

1. Entwurf A mit Seitenleiste (Beobachten und Einkaufsliste). In der Leiste nur die Gegenstände, die Einstellungen im Reiter Beobachten.
2. Zufluss und Abfluss sichtbar, nebeneinander mit Symbolen.
3. Limit pro Kauf wird Goldreserve, dazu der Regler Menge mit „Alle“ ganz rechts, Vorgabe 1 für Gegenstände, die keine Massenware sind.
4. Einkaufsliste zieht Gekauftes sofort ab, Erledigtes wird grau und bleibt, × löscht, Regler setzt eine neue Menge.
5. Beobachten: Treffer und Einbrüche je Stunde über 7 Tage, dazu Jetzt mit Punkt.
6. Chancen: nur Schnellkauf sichtbar, der Rest ruht hinter „Weitere Chancen“.
7. Lockangebot mit Menge kommt sofort als eigener Schritt.

### Offen

- Keine. Der Reiter Markt behält seinen Namen (24.11.2026).
- Freigabe: erteilt am 24.11.2026.
