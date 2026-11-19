# Peon Broker: Chancen in drei Listen und Chancen für den Schnellkauf

Stand: 19.11.2026, mit KarloDerBaer abgestimmt, umgesetzt in Broker 0.119.0, Nachbesserungen in 0.120.0 (Abschnitt 6).

## 1. Ziel

- Neue Art von Chancen: **Schnellkauf**. Broker schlägt Massenware vor, bei der viel auf dem Markt liegt und sich viel bewegt. Dort lohnt der Schnellkauf im Fokus (Lockangebote, Nachahmer, kurze günstige Angebote).
- Der Reiter **Chancen** bekommt drei Unterreiter: **Spekulation**, **Aufkauf**, **Schnellkauf**. Laufend geprüft wird nur der offene Unterreiter. Broker merkt sich den zuletzt offenen.
- Der Reiter **Beobachten** bekommt zwei Unterreiter: **Aufkauf** und **Schnellkauf**, jeder mit eigenen Spalten.

## 2. Neue Art Schnellkauf (`QuickChances.lua`)

### 2.1 Vorschläge

Grundlage ist der jüngste Stand des Markts. In `markets[...].items` steht schon der neuere Wert aus eigenem Komplettscan oder Stand des Peon Managers, denn Broker trägt den Stand des Managers (Menge und günstigster Preis je Gegenstand) über `Data.ApplyManager` ein. Manager und Bridge brauchen dafür nichts Neues.

Regeln:

1. Nur Massenware (`Data.IsCommodity`), nur Gegenstände mit Angeboten.
2. Günstigster Preis je Stück mindestens **Mindestpreis** (`qcMinPrice`, Vorgabe 1 Silber).
3. Sortiert nach Menge auf dem Markt, die meisten zuerst.
4. Die ersten **Anzahl** davon (`qcCount`, Vorgabe 10) bilden die Liste.
5. Ausgeblendete Gegenstände (Menü „Nicht für Schnellkauf vorschlagen“, `PeonBrokerDB.quickHide[Markt]`) fallen heraus, der nächste rückt nach. Knopf „Zurückholen“ bringt alle wieder.

Die Liste entsteht neu, sobald ein neuer Stand da ist, eine Einstellung sich ändert oder per Knopf „Neu vorschlagen“. Ergebnisse bereits geprüfter Gegenstände bleiben erhalten.

### 2.2 Prüfung der Marktbewegung

- Ein Gegenstand nach dem anderen. Je Gegenstand laufen **Abfragen je Prüfung** (`qcProbes`, Vorgabe 5) direkt hintereinander im Takt des Radars. Die erste ist eine Suche, danach „Neu laden“ wie im Fokus.
- Gezählt werden Einstellungen, Käufe und Preissprünge aus dem Vergleich zweier Abfragen hintereinander (`Measure.Sample`, `Measure.Pair`) und fremde Lockangebote (`Quick.NewBaits`).
- Bewertet wird mit den Grenzen der Marktbewegung im Schnellkauf (`Quick.MoveClass`, Einstellungen `quickMoveIn`, `quickMoveAll`, `quickMoveLow`): lebhaft, mäßig oder ruhig.
- **Gleitend**: Die letzten 3 Prüfungen desselben Gegenstands zählen zusammen. Grund: Fünf Abfragen dauern nur etwa 3 Sekunden, hochgerechnet auf eine Minute wäre sonst fast alles lebhaft. Mit nur einer Prüfung ist das Ergebnis vorläufig und steht als „lebhaft?“ da.
- **Reihenfolge**: Die erste Runde beginnt beim Kandidaten mit der größten Menge. Jede weitere Runde: lebhafte (meiste Ereignisse zuerst), ungeprüfte, mäßige, ruhige. Danach beginnt sofort die nächste Runde, solange die Liste offen ist.
- Knopf „Prüfung anhalten“. Nach mehr als 10 Sekunden ohne Abfrage (Reiter verlassen) beginnt die angefangene Prüfung neu.
- Die Abfragen schickt `Radar.lua` (`R.NextKey`, Art „probe“), die Antworten kommen über `R.Apply` zurück. Die Messung im Fokus bleibt unverändert und hat Vorrang.

### 2.3 Liste im Unterreiter Schnellkauf

| Spalte | Inhalt |
|---|---|
| Gegenstand | Name mit Symbol, grau bei „ruhig“ |
| Günstigster | günstigster Preis der letzten Abfrage (vor der ersten Prüfung aus dem Stand) |
| Menge | Menge auf dem Markt, letzte Abfrage oder Stand |
| Zu / Ab je Min. | eingestellte und gekaufte Stück je Minute |
| Bewegung | lebhaft (grün), mäßig, ruhig (grau), vorläufig mit „?“ |
| Lockangebote | fremde Lockangebote in den gezählten Prüfungen |
| Zustand | Punkte während der Prüfung, „als 3. dran“, „vor 2 Min. (3.)“ |

- Die geprüfte Zeile ist hell hinterlegt, oben steht „Prüft 4 von 10: Name“.
- Sortierung: lebhaft oben, ruhige grau unten. Neu sortiert wird erst nach einer fertigen Prüfung, damit die Zeilen nicht unter der Maus springen.
- Klick öffnet den Fokus im Modus Schnellkauf. Rechtsklick: Gegenstandsmenü mit „Nicht für Schnellkauf vorschlagen“ und ab 0.120 den Haken „Beobachten: Aufkauf“ und „Beobachten: Schnellkauf“ (Vorgaben siehe 6).
- Tooltip: Bewegung, Raten je Minute, Zahl der Ereignisse, Prüfungen und Abfragen, Lockangebote, Regel für lebhaft, Herkunft der Vorschläge.

### 2.4 Einstellungen (Fenster Einstellungen der Chancen)

| Einstellung | Vorgabe | Bereich |
|---|---|---|
| Arten: Schnellkauf (`chancesShowQ`) | an | |
| Anzahl der Vorschläge (`qcCount`) | 10 | 3 bis 30 |
| Günstigster Preis mindestens (`qcMinPrice`) | 1 Silber | frei |
| Abfragen je Prüfung (`qcProbes`) | 5 | 3 bis 20 |

Die Grenzen für lebhaft und ruhig bleiben die Einstellungen der Marktbewegung im Fokus.

## 3. Reiter Chancen mit drei Unterreitern

| Unterreiter | Inhalt | Knopf |
|---|---|---|
| Spekulation | Chancen des Managers der Arten Spekulation, Langzeit und Muster | „Alle prüfen“ |
| Aufkauf | Chancen des Managers der Art Aufkauf, Treffer des Radars (Aufkauf, Händler) | Scan mit Auswahl |
| Schnellkauf | Vorschläge aus 2.1 | „Neu vorschlagen“, „Prüfung anhalten“ |

- Laufend geprüft (Erneuern) wird nur die offene Liste. Ein Wechsel hält einen laufenden Radar-Scan an.
- Gemerkt in `chancesTab`. Ein Unterreiter ohne eingeschaltete Art verschwindet.
- Zahl am Reiter Chancen: alle Listen zusammen (Schnellkauf: lebhafte). Die Unterreiter zeigen ihre eigene Zahl.
- Der alte Reiter Radar öffnet den Unterreiter Aufkauf. Der Hinweis beim Öffnen des Auktionshauses zählt weiter alle Chancen des Managers.

## 4. Reiter Beobachten mit zwei Unterreitern

Ein Gegenstand steht in jeder Liste, für die er Werte hat (`Watch.InQuick`, `Watch.InBuyout`), also auch in beiden. Ein frisch hinzugefügter Gegenstand ohne Werte steht im Aufkauf. Gemerkt in `watchTab`. Abgefragt wird nur die offene Liste. Doppelklick öffnet den Fokus im Modus der Liste.

- **Aufkauf**: Gegenstand, Preis, Kaufen bis, Glocke, Zielpreis, Glocke, Rat (wie bisher ohne Spalte Art).
- **Schnellkauf**: Gegenstand, Günstigster, Kaufen bis, Glocke, Darunter (Stück unter Kaufen bis), Bewegung (Prüfung wie in 2.2), Gekauft (diese Sitzung), Rat. Limit pro Kauf, die Haken und die Bilanz stehen im Tooltip.

Preisalarm und Zahl am Reiter bleiben beim zuletzt gespeicherten Modus.

## 6. Nachbesserungen in 0.120.0 (KarloDerBaer 19.11.2026)

- **Kaufen bis ohne eigenen Wert:** die Hälfte des günstigsten fremden Angebots (`quickLimitPct`, Vorgabe 50 %), mindestens der Händlerpreis. Ein einzelnes Stück ganz unten zählt nicht, wenn darüber weitere Angebote liegen. Gilt im Fokus und beim Hinzufügen zur Liste Schnellkauf.
- **Limit pro Kauf ohne eigenen Wert:** 5 Gold (`quickGoldDefault`).
- **Prüfabstand:** Lebhafte und ungeprüfte sofort wieder. Sonst Wartezeit = `qcWaitMax` (Vorgabe 10 Min.) × (1 − Anteil an der Grenze für lebhaft), mindestens 30 Sek., vorläufige halb so lange. Zustand „vor 2 Min., wieder in 3 Min.“.
- **Gegenstandsmenü:** Bei Massenware zwei Haken „Beobachten: Aufkauf“ und „Beobachten: Schnellkauf“. Beide aus beendet die Beobachtung, die Werte einer abgewählten Liste bleiben.
- **Marktbewegung nur in der Kaufzone:** Einstellungen und Käufe zählen bis 5 % über dem günstigsten Angebot (`quickZonePct`), Preissprünge ab 2 % (`quickJumpPct`). Zufluss und Abfluss bleiben für den ganzen Markt.
- **Listen der Chancen ohne Spalte Art**, die Art steht im Tooltip. Fehler behoben: Im Unterreiter Aufkauf standen nach Antworten des Radars auch Spekulationen.

## 7. Gelegenheiten langfristig (0.122.0, KarloDerBaer 19.11.2026)

Gelegenheiten fallen in den kurzen Prüfungen nur zufällig auf und taugen nicht für die Bewertung der Bewegung. Über längere Zeit zeigen sie aber, bei welchen Waren es immer wieder günstige Angebote gibt. Dort setzen andere auch häufiger Lockangebote.

- **Einbruch:** neues fremdes Angebot mit mindestens 2 Stück, mindestens 5 % (`quickDipPct`) unter dem bisher günstigsten. Höchstens einer je Abfrage, unabhängig von Kaufen bis.
- **Dazu:** fremde Lockangebote und Lockangebote mit Nachahmern (nur im Fokus).
- **Quelle:** jede Beobachtung einer Massenware, im Fokus und in den Prüfungen. Zeit je Abstand höchstens 10 Sek.
- **Speicher:** je Markt, Gegenstand und Tag (`quickStats`), über 14 Tage (`quickStatDays`), ältere Tage mit weniger Gewicht.
- **Kennzahl:** Einbrüche je Stunde beobachteter Zeit, unter 30 Min. vorläufig (grau).
- **Anzeige:** Fokus Zeile „Langfristig“, Chancen und Beobachten Spalte „Einbr./Std.“ (in Beobachten statt Gekauft), Tooltips. In den Chancen stehen bei gleicher Bewegung die mit mehr Einbrüchen oben.

## 5. Spätere Ideen (nicht umgesetzt, nur nach Zustimmung)

1. Vorschläge, die schon beobachtet werden, mit einem Zeichen markieren.
2. Die Abfragen der Prüfung als Start in die Messung des Fokus geben.
3. Meldung mit Ton, wenn ein Vorschlag auf lebhaft wechselt.
4. Seite Chancen im Manager mit denselben drei Listen.
