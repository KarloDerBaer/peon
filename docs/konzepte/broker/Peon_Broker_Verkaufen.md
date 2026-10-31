# Peon_Broker – Entwurf Reiter „Verkaufen“

Stand: 30.09.2026, **abgestimmt** (KarloDerBaer: „ja mach alles so“), umgesetzt in Broker 0.8.0. Formeln: Rechenmodell Kapitel 4 (F21–F27).

Vorgaben von KarloDerBaer (30.09.2026):

- Beim Verkaufen gibt es nochmal einen Live-Abgleich.
- Mehrere Stapel auf einmal sollen möglich sein.
- Laufzeit standardmäßig 8 Std., einstellbar. Massenware mit vielen Angeboten darf auf 2 Std.

## 1. Was der Client dafür bietet (aus der Prüfung vom 29.09.2026)

| Aufgabe | Funktion im Spiel | Hinweis |
|---|---|---|
| Live-Angebote für einen Gegenstand holen | `SendSellSearchQuery`, danach `COMMODITY_SEARCH_RESULTS_UPDATED` bzw. `ITEM_SEARCH_RESULTS_UPDATED` | dieselbe Suche, die das Auktionshaus beim Verkaufen selbst macht; zeigt auch, welche Angebote deine eigenen sind |
| Wie viele Stück insgesamt verkaufbar sind | `GetAvailablePostCount` | zählt alle Stapel in den Taschen zusammen |
| Einstellen | `PostCommodity` (Massenware), `PostItem` (Einzelgegenstände) | nur per Klick, nie automatisch |
| Rückfrage des Spiels | `ConfirmPostCommodity` / `ConfirmPostItem` | das Spiel fragt bei manchen Preisen nach; Broker zeigt dann eine eigene Rückfrage |
| Gebühr | `CalculateCommodityDeposit` / `CalculateItemDeposit` | Broker nimmt den Wert des Spiels, die eigene Formel ist bestätigt (24 von 24) |
| Kupferbeträge erlaubt? | `SupportsCopperValues` | in Retail müssen Massenware-Preise volle Silber sein; beim Wollstoff ging 2s 35c, wird trotzdem beim Start geprüft |

**Mehrere Stapel:** Bei Massenware gibt es im modernen Auktionshaus keine Stapel mehr. Man stellt einfach eine Menge ein, zum Beispiel 57 Wollstoff aus drei Stapeln, als ein Angebot. Bei Einzelgegenständen (Ausrüstung) bedeutet die Menge die Zahl der Auktionen, zum Beispiel 3 gleiche Schwerter als 3 Auktionen mit einem Klick.

## 2. Aufbau des Reiters (Skizze)

```
┌ Verkaufen ───────────────────────────────────────────────────────────────────┐
│ Taschen                          │ Kupfererz                   (60 in Taschen) │
│ Gegenstand       Anz.  Wert      │ Live-Angebote (vor 3 Sek.)   [Aktualisieren]│
│ ● Kupfererz        60  AH 67s26c │   1s 18c ×   8                            │
│ ● Wollstoff        57  AH 1g 2s  │   1s 20c ×  40  ← deins                    │
│ ○ Leinenverband    18  Händler   │   1s 50c ×  50                            │
│ ○ Grüner Hut        1  Händler   │   1s 60c ×  20                            │
│ ...                              │ Vorschlag je Stück  [ 1 ] g [ 18 ] s [ 0 ] c│
│                                  │   günstigstes Angebot, nicht unterboten    │
│ [x] nur lohnende zeigen          │ Menge  [ 60 ] [Alle]    Laufzeit [ 2 Std. ▾]│
│                                  │ ─────────────────────────────────────────── │
│                                  │ Gesamtpreis        70s 80c (60 × 1s 18c)   │
│                                  │ Einstellgebühr     15c (kommt zurück)      │
│                                  │ Erlös nach 5 %     67s 26c   (grün)        │
│                                  │ Händler zahlt      3s                      │
│                                  │ ⚠ Hinweise …                               │
│                                  │          [ Einstellen ]  [ Einstellen & weiter ] │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Links: Taschenliste**

- Alle Gegenstände aus den Taschen, die im Auktionshaus verkauft werden dürfen (keine gebundenen), gleiche Gegenstände zusammengefasst.
- Spalten: Name in Qualitätsfarbe, Anzahl, bester Wert für alles (wie Zeile 1 im Tooltip: „AH …“ grün oder „Händler …“).
- ● = im Auktionshaus lohnend, ○ = Händler zahlt mehr.
- „Nur lohnende zeigen“ blendet die ○-Einträge aus (Standard: an).
- Sortierung Standard: nach Erlös, höchster oben.
- Die Liste aktualisiert sich, wenn sich die Taschen ändern.

**Rechts: Verkaufen des gewählten Gegenstands**

- **Live-Angebote:** beim Anklicken automatisch abgefragt, zeigt die günstigsten Preisstufen (Preis je Stück × Menge), eigene markiert. Knopf „Aktualisieren“ für eine neue Abfrage.
- **Vorschlag je Stück:** in Gold/Silber/Kupfer-Feldern, von Hand änderbar. Darunter kurz der Grund (siehe Abschnitt 3).
- **Menge:** Standard = alles in den Taschen (Knopf „Alle“), änderbar.
- **Laufzeit:** Auswahlliste 2/8/24 Std., vorbelegt nach der Regel in Abschnitt 4.
- **Zusammenfassung:** Gesamtpreis, Einstellgebühr (vom Spiel), Erlös nach 5 % (grün, wenn er über dem Händlerwert liegt, sonst orange), Händlerwert zum Vergleich.
- **Hinweise** wie im Tooltip, dazu die neuen aus Abschnitt 5.
- **„Einstellen“** stellt ein. **„Einstellen & weiter“** stellt ein und wählt sofort den nächsten lohnenden Gegenstand aus der Liste. So geht man mit einem Klick je Gegenstand durch die ganzen Taschen.

**Auswahl aus den Taschen (Vorschlag):** Alt+Klick auf einen Gegenstand in den Taschen wählt ihn im Reiter „Verkaufen“ aus. Das würde auch mit Bagnon funktionieren, falls es sich dort einklinken lässt; das wird im Spiel geprüft.

## 3. Preisvorschlag mit Live-Daten

Das Rechenmodell bleibt, es rechnet nur mit den Live-Angeboten statt mit dem letzten Scan:

- **AHmin_live** = günstigstes Live-Angebot **eines anderen Verkäufers** (eigene Angebote zählen hier nicht, man unterbietet sich nicht selbst).
- **AHmedian_live** = Median über alle Live-Angebote nach Menge (F3), eigene eingeschlossen.
- Dumping-Prüfung, Unterbieten (UB / UBmass) und Basis bleiben wie F12–F15.
- **Eigenes Angebot ist schon das günstigste:** Vorschlag = dein Preis (nicht darunter). Hinweis „Du bist schon günstigster Anbieter“.
- **Keine Live-Daten** (Abfrage fehlgeschlagen oder kein Angebot vorhanden): Vorschlag aus dem letzten Scan bzw. den 7-Tage-Werten, Hinweis „keine aktuellen Angebote“. Ohne jede Vergleichsdaten: Händlerpreis ÷ 0,95, aufgerundet, plus Hinweis „kein Vergleich – Preis selbst festlegen“.
- **Später mit dem Programm:** Die Preisbereiche („gut verkaufen ab“) kommen als zusätzliche Einschätzung dazu.

## 4. Laufzeit

| Fall | Laufzeit |
|---|---|
| Standard | 8 Std. (Einstellung „Laufzeit“, wie bisher) |
| Massenware mit vielen Angeboten | 2 Std., wenn eingeschaltet (Einstellung „Massenware mit vielen Angeboten kürzer einstellen“) |
| Von Hand geändert | wird je Gegenstand gemerkt und beim nächsten Mal vorbelegt |

- **„Viele Angebote“** = mindestens X Angebote im letzten Scan bzw. live. Vorschlag: X = 20, einstellbar.
- **Grund:** Bei Massenware wird das neueste Angebot zuerst gekauft. Wer bei viel Umsatz günstigster ist, verkauft schnell. 2 Std. kosten nur ein Viertel der 8-Std.-Gebühr, und verlieren kann man nur diese kleine Gebühr.

## 5. Neue Hinweise beim Verkaufen

| Hinweis | Wann | Farbe |
|---|---|---|
| Lieber beim Händler verkaufen | Erlös ≤ Händlerwert | orange |
| Dumping – Vorschlag angepasst | wie F13 | orange |
| Du bist schon günstigster Anbieter | eigenes Angebot = AHmin_live | grau |
| Preis liegt stark unter dem Vorschlag | Preis von Hand mehr als DG unter dem Vorschlag | rot, dann Rückfrage beim Einstellen |
| Keine aktuellen Angebote | Live-Abfrage leer | grau |
| Live weicht stark vom Scan ab | AHmin_live mehr als TG_stark vom letzten Scan entfernt | grau (nur zur Info) |

## 6. Was Broker sich merkt

- **Je Gegenstand:** zuletzt von Hand gewählte Laufzeit, und ob die Menge von Hand geändert wurde (Standard sonst „alles“).
- **Nicht gemerkt:** der Preis. Er wird immer frisch aus den Live-Daten vorgeschlagen, sonst stellt man versehentlich zu alten Preisen ein. Angezeigt wird aber „Zuletzt eingestellt zu …“.
- Eingestellte Auktionen werden fürs spätere Buch vermerkt (Gegenstand, Menge, Preis, Laufzeit, Gebühr, Zeit).

## 7. Neue Einstellungen

- Massenware mit vielen Angeboten kürzer einstellen (2 Std.): an/aus (Vorschlag: an)
- Ab wie vielen Angeboten: 5–100 (Vorschlag: 20)
- Nur lohnende Gegenstände anzeigen: an/aus (auch direkt im Reiter)
- Die vorhandenen bleiben: Laufzeit (Standard 8 Std.), Unterbieten, Dumping-Grenze

## 8. Sicherheit

- Einstellen passiert **nur per Klick** auf „Einstellen“, nie automatisch, und nie im Kampf.
- Vor dem Einstellen prüft Broker nochmal: Gegenstand noch in den Taschen, Menge verfügbar, Preis > 0.
- Fragt das Spiel nach (`ConfirmPost…`), zeigt Broker eine Rückfrage mit dem Grund. Erst nach „Ja“ wird bestätigt.
- Broker stellt jeweils nur eine Sache auf einmal ein und wartet auf die Rückmeldung des Spiels (`AUCTION_HOUSE_AUCTION_CREATED`), bevor „weiter“ den nächsten Gegenstand wählt.

## 8a. Neues Layout (0.9.0, nach KarloDerBaers Test)

Die Skizze in Abschnitt 2 gilt nicht mehr. Stattdessen zweispaltig, angelehnt an das Blizzard-Fenster:

```
┌ Peon Broker ─────────────────────────────────────────────────────────┐
│ [Symbol] Bauplan: Gärbehälter    │ Gegenstand                 Wert   │
│          1 in Taschen   Live: …  │ [▪] Bauplan: Gärbehälter    19s   │
│ Kaufpreis   [ 0 ][ 20 ][ 0 ]     │ [▪] Elixier der schwachen … 13s   │
│ pro Stück   günstigstes Angebot  │ …                                 │
│ Menge       [ 1 ]  [Max]         │                                   │
│ Dauer       [ 8 Stunden ▾]       │                                   │
│ Einzahlen   72c                  │                                   │
│ Gesamtpreis 20s                  │                                   │
│ Erlös       19s                  │                                   │
│ ⚠ Hinweise                       │ [x] nur lohnende                  │
│ [Auktion erstellen] [Erstellen & weiter]                             │
└─[Verkaufen][Meine Auktionen][Einkaufen][Preise][Buch]────────────────┘
```

- Keine Liste der Live-Angebote (stehen im Blizzard-Fenster), Abfrage nur im Hintergrund.
- Händlerpreis nur als Hinweis, Begründung als Stichwort mit Text beim Überfahren.

## 8b. Über das Verkaufsfenster des Auktionshauses (0.10.0)

- Der gewählte Gegenstand wird ins Verkaufsfenster des Auktionshauses gelegt; Preis, Menge und Dauer von Broker werden dort eingetragen. Eingestellt wird mit den Werten, die dort stehen.
- Broker links nur noch: Gegenstand, Vorschlag mit Stichwort, Erlös, Hinweise, Knöpfe „Nicht verkaufen“, „Auktion erstellen“, „Erstellen & weiter“ (übereinander).
- Rechts: Taschen mit Symbol, Anzahl, Wert, Trend; Rechtsklick = nicht verkaufen (je Charakter).

## 9. Entschieden (30.09.2026)

Alle Vorschläge angenommen: Aufbau wie in der Skizze, „Einstellen & weiter“, 2 Std. für Massenware ab 20 Angeboten (Standard an), eigene Angebote nicht unterbieten, Preis nicht merken (nur „Zuletzt eingestellt zu …“ anzeigen), Alt+Klick in den Taschen.

Noch im Spiel zu prüfen: Alt+Klick mit Bagnon, Rückfrage des Spiels (`ConfirmPost…`), Verhalten bei Einzelgegenständen mit Menge > 1.
