# Peon_Ledger: Konzept schlank und übersichtlich

Stand: 24.11.2026, **freigegeben**, Abschnitte 2 bis 6 von KarloDerBaer im Gespräch vorgegeben, Abschnitt 3 (Charaktere) am 24.11.2026 freigegeben. Ausgangsversion Ledger 0.17.2. Baut auf `Peon_Ledger_Neuaufbau.md` und `Peon_Ledger_Buch_AH.md` auf. Skizzen der Varianten: Artifact-Seite „Peon schlank“.

## 1. Ausgangslage

Wunsch von KarloDerBaer: Ledger soll leichter werden, ohne mit Werten zu überladen, die er im Alltag nicht braucht. Im Gespräch (24.11.2026) ergab sich:

- Die **Übersicht** gefällt. Mit **Vermögen** und **Marktwert der Waren** kann er wenig anfangen. Beim **Handelsgewinn** ist er nicht sicher, ob er immer stimmt.
- Die Reiter **Bestand** und **Verlauf** nutzt er kaum. Gewünscht ist stattdessen, die **zuletzt gespeicherten Taschen und Banken** der Charaktere durchzusehen, als ob man Bags öffnet, dazu eine **Suche** nach Gegenständen.
- **Buch** bleibt, wenn die Zahlen stimmen und richtig dargestellt werden. **Verlauf** bleibt, soll aber übersichtlicher werden. **Info** bleibt, weil sie die vielen Begriffe erklärt.
- Der **Tooltip** bleibt wie heute (Bausteine einstellbar).
- Kein Nutzungszähler. Was gebraucht wird, klären wir im Gespräch.

Die Schnittstellen für andere Module bleiben in jedem Fall unverändert: `mod:Stock`, `mod:StockOthers`, `mod:Cost`, `mod:OpenFee`, `mod:SellRate`, `mod:LastBuy`, `mod:LastSale`, `mod:ShowItem`, `mod:HouseLots` (Broker, Profession, Panel).

## 2. Reiter danach

| Reiter heute | danach |
|---|---|
| Übersicht | bleibt, ohne Vermögen und Marktwert, mit Goldänderung 24 Std. und AH-Erlös (Abschnitt 4) |
| Bestand | wird **Charaktere** (Abschnitt 3) |
| Buch | bleibt (Abschnitt 5) |
| Verlauf | bleibt, übersichtlicher (Abschnitt 5) |
| Info | bleibt, Begriffe angepasst |

Reihenfolge der Reiter: Übersicht, Charaktere, Buch, Verlauf, Info.

## 3. Neuer Reiter Charaktere

Frage der Seite: **„Was liegt wo, bei welchem Charakter?“**

### 3.1 Aufbau

Links die Charaktere des Realms, rechts der Inhalt des gewählten Charakters, nach Ort gegliedert. Oben eine Suche über alle Charaktere.

```
┌ Ledger ───────────────────────────────────────────────────────────────────┐
│ [Suche: Gegenstand über alle Charaktere      ]                            │
│ ┌ Charaktere ──────────┐ ┌ Hauptcharakter · Stufe 60 · 912g ────────────┐ │
│ │ Alle Charaktere      │ │ ▼ Taschen   64/80 Plätze · vor 2 Min. [Bags] │ │
│ │ Hauptcharakter   60 ◄│ │    Seidenstoff                          64   │ │
│ │ Bankcharakter    12  │ │    Schwerer Heiltrank                   12   │ │
│ │ Twink Schurke    34  │ │    …                                         │ │
│ │ Twink Magier     22  │ │ ▼ Bank      96/112 Plätze · vor 3 Tg. [Bags] │ │
│ │                      │ │    Seidenstoff                         120   │ │
│ │                      │ │    Magiestoff                           40   │ │
│ │                      │ │ ► Auktionen  8 laufend · vor 1 Std.          │ │
│ │                      │ │ ► Unterwegs (Post an diesen Charakter)  2    │ │
│ │                      │ │ ► Angelegt  17 Teile                         │ │
│ └──────────────────────┘ └──────────────────────────────────────────────┘ │
│  Übersicht │ Charaktere │ Buch │ Verlauf │ Info                            │
└───────────────────────────────────────────────────────────────────────────┘
```

- Jeder Ort ist eine einklappbare Überschrift (`UI.Collapse`) mit Plätzen, Anzahl und Alter des Stands („vor 3 Tg.“, ab 7 Tagen gelb). Taschen und Angelegt sind offen, der Rest zu.
- Zeilen: Symbol mit Qualitätsrahmen, Name, Stück. Sortiert wie in Bags nach Kategorie, darin nach Name. Mausover zeigt den normalen Tooltip des Gegenstands, Klick öffnet ihn in Broker, Rechtsklick das Gegenstandsmenü (wie heute im Bestand).
- „Alle Charaktere“ zeigt dieselben Orte zusammengezählt, je Zeile mit Mausover, wer wie viel hat.
- Ohne Daten zu einem Ort steht dort ein Hinweis: „Noch nicht gesehen. Öffne einmal die Bank mit diesem Charakter.“

### 3.2 Suche über alle Charaktere

Sobald Text in der Suche steht, zeigt die rechte Seite statt des Charakters die Treffer:

```
┌ Suche „seide“ · 3 Gegenstände ───────────────────────────────┐
│ Seidenstoff                                     gesamt 224    │
│    Hauptcharakter   Taschen 64 · Bank 120                     │
│    Bankcharakter    Post 40                                   │
│ Seidenbeutel                                    gesamt 3      │
│    Twink Magier     Taschen 1 · Bank 2                        │
│ Gewebte Seidenhose                              gesamt 1      │
│    Twink Schurke    Angelegt 1                                │
└──────────────────────────────────────────────────────────────┘
```

- Gesucht wird im Namen (ohne Groß- und Kleinschreibung), auch mit Gegenstandslink oder Nummer wie bei `/ledger <Name>`.
- Klick auf einen Charakter in den Treffern wählt ihn links und klappt den Ort auf.
- Leeren der Suche führt zurück zum gewählten Charakter.

### 3.3 Ansicht in Bags

Ledger bleibt bei der einfachen Liste je Ort (Gegenstand und Stückzahl, wie heute gespeichert). Die Ansicht „wie im Inventar“ übernimmt **Peon_Bags**: Bags speichert selbst, wie Taschen, Bank und Gildenbank zuletzt aussahen, **platzgenau**, und kann diesen Stand für jeden Charakter wieder zeigen (KarloDerBaer, 24.11.2026).

Der Knopf **[Bags]** an Taschen und Bank im Reiter Charaktere öffnet das Taschenfenster von Bags mit dem gespeicherten Stand dieses Charakters. Nur ansehen, nichts bewegen.

```
┌ Taschen von Hauptcharakter · Stand vor 2 Min. ─── [Bank] [Gildenbank] ┐
│ Handwerkswaren                                                        │
│ [Seide 20][Seide 20][Seide 20][Seide 4][Magie 20][Magie 20]           │
│ Verbrauchbares                                                        │
│ [Heiltr. 12][Manatr. 5]                                               │
│ Ausrüstung                                                            │
│ [Ring][Umhang]                                                        │
│                                         64/80 Plätze · 16 frei        │
└───────────────────────────────────────────────────────────────────────┘
```

- Gezeigt wird genau so, wie es beim Charakter liegt: dieselben Stapel, dieselbe Anordnung und dieselben Bereiche wie im echten Taschenfenster von Bags.
- In der Ansicht der Taschen oben zwei Knöpfe **Bank** und **Gildenbank**. Sie zeigen die Bank dieses Charakters und die Gildenbank seiner Gilde im selben Fenster. Ohne gespeicherten Stand sind sie ausgegraut, der Tooltip sagt, wo man ihn bekommt („Öffne einmal die Bank mit diesem Charakter“).
- Bags bekommt dafür auch eine eigene Auswahl des Charakters im Taschenfenster, damit man die Ansicht ohne Ledger erreicht (KarloDerBaer, 24.11.2026). Der eingeloggte Charakter steht oben und zeigt die echten Taschen, jeder andere den gespeicherten Stand.
- Ohne Peon_Bags fehlt der Knopf [Bags], die Liste im Reiter Charaktere reicht dann.

### 3.4 Was dafür neu gebaut wird

| Teil | Wo | Was |
|---|---|---|
| Reiter Charaktere | Ledger (`Chars.lua` neu, ersetzt `Stock.lua`) | Liste je Ort, Suche über alle Charaktere, Knopf [Bags] |
| Stand speichern | Peon_Bags | beim Schließen von Taschen, Bank und Gildenbank je Platz Gegenstand und Stückzahl speichern, je Charakter (Gildenbank je Gilde) |
| Gespeicherten Stand zeigen | Peon_Bags, neue Schnittstelle `bags:ShowSaved(name, ort)` | Taschenfenster nur zum Ansehen, mit Knöpfen Bank und Gildenbank |
| Gildenbank | Peon_Bags (`Guild.lua`) | Fächer beim Öffnen lesen, die der Charakter sehen darf |

Zur Gildenbank: Sie ist in Bags vorbereitet, aber im Spiel noch nicht getestet. Gespeichert werden kann sie erst, wenn KarloDerBaer sie mit einer Gildenbank prüfen kann. Bis dahin bleibt der Knopf ausgegraut. Ledger erfasst die Gildenbank weiter nicht (Ein- und Auslagern erscheint dort wie bisher als Verbrauch oder Zugang).

Größe: Ein Platz kostet zwei Werte (Gegenstand, Stück). Bei 10 Charakteren mit je 100 Plätzen in Taschen und 200 in der Bank sind das rund 6.000 Werte, weit unter der Grenze des Spiels von etwa 262.000 je Datei.

## 4. Übersicht

### 4.1 Kacheln

| heute | danach |
|---|---|
| Gold gesamt (Änderung heute) | **Gold gesamt** (Anzahl Charaktere) |
| Vermögen | **Gold 24 Std.**: Änderung gegenüber dem Stand vor 24 Stunden, grün oder rot. Mausover: höchster und tiefster Stand in der Zeit. |
| Handelsgewinn heute | **AH-Erlös heute**: Summe der Verkäufe aus den Rechnungen (sicher erfasst), darunter Anzahl Verkäufe. Mausover: Handelsgewinn mit dem Hinweis „geschätzt, hängt von den erfassten Einkaufskosten ab“. |

Die Goldänderung kommt aus den gespeicherten Ständen in `Trend.lua` (je Stunde ein Stand für den letzten Tag, das reicht).

### 4.2 Charakterliste

Spalten danach: Name, Stufe, Gold, **24 Std.**, zuletzt gesehen. Lagerwert und Vermögen fallen weg. Klick auf einen Charakter öffnet ihn im Reiter Charaktere.

### 4.3 Diagramm

Das Diagramm wird **einstellbar** (KarloDerBaer, 24.11.2026). Über ein Menü am Diagramm wählt man die Linien:

| Linie | Vorgabe |
|---|---|
| Gold (alle Charaktere) | an |
| AH-Erlös (aufsummiert im Zeitraum) | an |
| Handelsgewinn (aufsummiert, mit Hinweis „geschätzt“) | aus, bis die Kosten als richtig gelten |
| Gold eines Charakters (je Charakter wählbar) | aus |

Dazu wie heute der Zeitraum (1 T bis Alles). Gespeichert in den vorhandenen Werten `trendRange` und `trendOff` (ausgeblendete Linien), neue Linien bekommen eigene Schlüssel. Die Linie Vermögen fällt weg, ebenso das Speichern des Vermögens in `trend` (`w`). Für Gold je Charakter speichert `trend` künftig auch die Stände je Charakter (gleiches Ausdünnen wie heute).

## 5. Buch, Verlauf, Info

- **Buch** bleibt wie in `Peon_Ledger_Buch_AH.md`. Bedingung von KarloDerBaer: Die Zahlen müssen stimmen. Die Fehler bei Kosten und Gold behebt eine eigene Session, danach prüft KarloDerBaer das Buch. Vermögen und Lagerwert erscheinen im Buch nur noch, wo sie zur Überleitung nötig sind.
- **Verlauf**: Die Bewegungen werden in jedem Fall erfasst, denn Kosten, Buch und Erlös rechnen daraus. Der Reiter ist nur die Anzeige. Für mehr Übersicht kommen alle vier Vorschläge (KarloDerBaer, 24.11.2026):
  1. Nach Tagen gegliedert, je Tag eine Kopfzeile mit Summe Gold rein und raus.
  2. Vorgabe-Filter „Wichtiges“: Auktionshaus, Händler, Post, Handel. Beute, Benutzt und Umbuchungen erst mit Haken.
  3. Filter als Knöpfe in einer Zeile statt der Auswahlliste mit 13 Arten.
  4. Aus dem Buch per Klick auf eine Zeile in den Verlauf mit passendem Filter springen.
- **Info** bleibt. Begriffe anpassen: Vermögen und Marktwert raus, Gold 24 Std. und AH-Erlös rein.

## 6. Tooltip und Einstellungen

- Tooltip bleibt wie heute, mit den einstellbaren Bausteinen (Wunsch KarloDerBaer).
- Einstellungen nach `docs/konzepte/Peon_Einstellungen_Leitfaden.md`:
  - **Allgemein**: Fenster öffnen, Minimap-Knopf, Zeilen im Tooltip, eigenes Postfenster.
  - **Anzeige**: Bausteine im Tooltip.
  - **Erweitert**: Charaktere löschen, Reihenfolge der Kosten, Kosten neu rechnen, Inventur, Buch zurücksetzen, Selbstprüfung.
  - Der Block „Prüfung“ fällt aus den Einstellungen weg, `/ledger pruefen` bleibt.

## 7. Was wegfällt

Nur nach Zustimmung von KarloDerBaer, entfernte Teile kommen ins Archiv.

- Reiter Bestand (`Stock.lua`), ersetzt durch Charaktere.
- Vermögen in Übersicht, Charakterliste und Diagramm (`ns.Worth` bleibt, solange das Buch es braucht).
- Spalte Lagerwert in der Charakterliste.
- Block Prüfung in den Einstellungen.

## 8. Bauabschnitte

| Nr. | Inhalt |
|---|---|
| S1 | Übersicht: Kacheln, Charakterliste, einstellbares Diagramm ohne Vermögen |
| S2 | Reiter Charaktere mit Orten und Suche |
| S3 | Peon_Bags: Stand von Taschen und Bank speichern und zeigen (`ShowSaved`), Knopf [Bags] in Ledger |
| S4 | Verlauf nach Tagen, Vorgabe „Wichtiges“, Filter als Knöpfe, Sprung aus dem Buch |
| S5 | Einstellungen nach Leitfaden, Info angepasst |
| S6 | Peon_Bags: Gildenbank speichern und zeigen (erst wenn prüfbar) |

S1, S3, S4 und S5 hängen nicht voneinander ab. Der Knopf [Bags] aus S3 kommt in den Reiter aus S2, wer später fertig wird, hängt ihn ein.

## 9. Offene Fragen an KarloDerBaer

1. Passt der Aufbau des Reiters Charaktere mit den Beispielen in Abschnitt 3?
