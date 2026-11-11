# Peon_Broker: Konzept Neuaufbau

Stand: 12.11.2026, **von KarloDerBaer freigegeben** (Abschnitt 9). Ausgangsversion Broker 0.58.0. Stufe 1 (N1 bis N6) ist gebaut (Broker 0.59.0 bis 0.64.0), Stufe 2 (H1 bis H5) ebenfalls (Broker 0.65.0 bis 0.68.0, Manager 0.26.0), nichts davon veröffentlicht. Im Spiel geprüft sind N1 und N2, die Prüfung von N3 bis H5 steht aus. Dieses Konzept baut auf `Peon_Broker_Umbau.md` auf und ersetzt dessen Abschnitte 7, 8 und 15. Rechenregeln stehen weiter in `Peon_Broker_Rechenmodell.md`.

## 1. Ausgangslage

Antworten von KarloDerBaer (11.11.2026):

- Genutzt werden vor allem Blizzards eigene Seiten: Markt durchsuchen, gezielt kaufen, verkaufen.
- **So wird heute Gewinn gemacht:** Massenware suchen, bei der es zwischen den günstigsten Angeboten einen größeren Preissprung gibt. Alles bis zum Sprung aufkaufen, zum höheren Preis wieder einstellen. Diese Angebote sucht KarloDerBaer von Hand. Genau das soll Broker übernehmen.
- Das Radar hilft in seiner heutigen Form nicht. Es zeigt (wie der Manager) viele Chancen, die sich nicht nutzen lassen, weil die Preise kurz nach dem Start noch falsch eingeschätzt werden.
- Drei Fenster zu Gegenständen (Auktionshaus, Broker, Ledger) zeigen zu viele Informationen.
- Einkaufslisten werden später mit den Berufen wichtig. Beobachtung ist denkbar, um Preise von Dingen im Blick zu haben, die man später verkaufen will.
- Händler: Übersicht, damit man nichts im Auktionshaus kauft, was ein Händler günstiger hat.
- Quellen: reine Information, kein eigener Reiter nötig. Händler, Marktvergleich und Quellen reichen als Unterpunkte.
- Der Manager wird danach angeglichen, nicht gleichzeitig.

Befund aus dem Code (Bestandsaufnahme 11.11.2026): drei verschiedene Looks, der Sprung von Einkaufen oder Radar zum Markt ist gesperrt, „Info“ führt auf eine WIP-Seite, „Markt“ gibt es zweimal, mehrere Dinge sind doppelt (Beobachtung, Händlerdaten, Datenstand, Kaufen). Die meisten Teile aus U1 bis U11 sind im Spiel nie gezielt geprüft worden.

## 2. Grundsätze

1. **Ein Fenster.** Für den Nutzer gibt es nur „das Auktionshaus mit Broker“: dieselbe Größe, derselbe Look, dieselbe Reiterleiste, egal ob man am Auktionator steht oder unterwegs ist.
2. **Eine Frage je Seite.** Jede Seite beantwortet eine Frage (Abschnitt 4). Listen haben höchstens sechs Spalten. Alles Weitere zu einem Gegenstand steht nur auf der Seite Gegenstand.
3. **Überall dieselben Sprünge** (Abschnitt 5).
4. **Jetzt vor Verlauf.** Solange der Markt unruhig ist, rechnen Kaufhilfen mit dem, was gerade im Auktionshaus steht (Preisstufen, Menge, Absatz). Der übliche Bereich aus dem Verlauf ist nur eine Warnung und bleibt still, wenn die Daten dünn oder die Schwankung groß ist.
5. **Blizzards Seiten bleiben** für Kaufen, Verkaufen und Auktionen. Broker ergänzt sie sichtbar und von außen (UI-Design Abschnitt 7).
6. **Jede Aktion ist ein Klick des Spielers.** Kaufen, Einstellen und Abbrechen erlaubt das Spiel nur aus einem Klick oder Tastendruck. „Automatisch“ heißt hier: Broker bereitet alles vor, der Klick löst aus.
7. **Alle Flächen nur mit `Peon.UI`** nach `Peon_UI_Design.md`. `Window.lua`, `Look.lua` und die alten Listen entfallen.

## 3. Ein Fenster, zwei Zustände

Brokers Seiten werden einmal gebaut. Sie erscheinen an zwei Stellen, die gleich aussehen:

- **Am Auktionator:** als Reiter in Blizzards Auktionshaus (wie seit U0, im Spiel ohne Blockade geprüft).
- **Unterwegs:** in einem Broker-Fenster mit `UI.Window`, 800 × 538 wie das Auktionshaus, mit derselben Reiterleiste.

Regeln:

- Öffnet man das Auktionshaus, schließt sich das Broker-Fenster. `/broker`, Minimap-Button und Panel wählen am Auktionator den zuletzt genutzten Broker-Reiter im Auktionshaus, statt ein zweites Fenster zu öffnen.
- Unterwegs öffnet das Broker-Fenster nach Möglichkeit an der Stelle, an der das Auktionshaus zuletzt stand.
- Reiter, die das Auktionshaus brauchen, zeigen unterwegs den letzten Stand oder sind grau (Tabelle unten).
- Die Statuszeile unten nennt immer Markt und Datenlage in einem Satz, zum Beispiel „PvE Allianz · Scan vor 3 Std. · Manager vor 20 Min.“. Tooltip und Klick führen zur Datenlage (4.7). Unterwegs steht dort zusätzlich „Stand vom …, nicht live“.
- „Blizzard pur“ bleibt als Notausgang.

| Reiter | Am Auktionator | Unterwegs |
|---|---|---|
| Markt | Blizzards Kaufen (live) mit Brokers Zeilen | Markt aus Scandaten (4.1) |
| Verkaufen | Blizzards Verkaufen mit Brokers Rat | grau, Tooltip „Nur am Auktionshaus“ |
| Auktionen | Blizzards Auktionen mit Spalte Broker | letzter bekannter Stand, nur lesen |
| Einkaufen | Listen, live prüfen, kaufen | Listen planen, letzter Stand, kein Kaufen |
| Radar | schlanke Liste der Chancen, Aktualisieren | Chancen aus dem letzten Stand |
| Fokus | einen Gegenstand laufend messen, Urteil, kaufen | letzter Gegenstand mit letzter Messung, als alt markiert, kein Messen |
| Gegenstand | alles zu einem Gegenstand | gleich |
| Mehr | Händler, Neutral, Datenlage | gleich |

Reihenfolge von KarloDerBaer (11.11.2026): erst Blizzards drei Seiten in Blizzards Reihenfolge, dann Brokers Seiten. Das ersetzt die Reihenfolge aus 0.54. Acht Reiter passen rechnerisch knapp in die Breite (etwa 790 von 800 Punkten ohne Zahlen am Reiter). Das wird in N1 im Spiel gemessen. Reicht es nicht, wird „Mehr“ ein Knopf in der Statuszeile.

### Warum nicht ein ganz eigenes Fenster (Variante B)

Variante B hieße: Blizzards Auktionshaus verstecken und Kaufen, Verkaufen und Auktionen selbst nachbauen.

- Suche mit Kategorien und Filtern, Angebotslisten, Gebote, Sofortkauf, Einstellen mit Dauer und Einzahlung, Abbrechen: alles müsste neu gebaut werden, ohne dass es mehr Gewinn bringt.
- Eigenes Einstellen (`PostItem`, `PostCommodity` aus eigenem Knopf) ist in Forever nie erprobt. Der frühere Reiter Verkaufen ging immer über Blizzards Fenster.
- Blizzards Fenster müsste unsichtbar offen bleiben, sonst endet der Besuch beim Auktionator. Klicks in der Tasche landen weiter dort.
- Jedes Spiel-Update kann den Nachbau brechen, und der Notausgang „Blizzard pur“ wäre dann ein anderes Fenster mit anderer Bedienung.
- Der Rat von KarloDerBaer vom 09.11.2026 (Blizzards Verkaufen ist schneller und vertrauter) spricht ebenfalls dagegen.

Variante A erreicht dasselbe Bild für den Nutzer mit dem, was schon geprüft ist.

## 4. Die Seiten

### 4.1 Markt: „Was gibt es, und was kostet es?“

- **Am Auktionator** Blizzards Kaufen. Broker ergänzt in der Kaufansicht eines Gegenstands höchstens drei Zeilen: Weiterverkauf (wie seit 0.56), Händler-Warnung (4.7) und einen kleinen Knopf „Gegenstand“ (Sprung zur Seite 4.6).
- **Unterwegs** Markt aus Scandaten: Suchleiste, links Kategorien (`UI.CategoryList`, Namen vom Spiel), rechts die Liste mit Gegenstand, Preis ab, Menge, Trend, Stand. Auswahl des Markts (Heimat, Neutral) nur, wenn es beide gibt. Ohne Suche zeigt die Liste Beobachtung und Einkaufslisten.

### 4.2 Verkaufen: „Soll ich zu diesem Preis verkaufen?“

Blizzards Seite mit Brokers Rat wie heute (Urteil, ein Satz, drei Werte). Neu in Stufe 2: Kommt der Gegenstand aus einem Radar-Kauf oder einer abgebrochenen Auktion, nennt der Rat das Ziel („Gekauft für 12s, Ziel 19s 50c“), siehe 6.2.

### 4.3 Einkaufen: „Was brauche ich, und ist es gerade günstig?“

- Links die Listen, rechts die Gegenstände der gewählten Liste: Gegenstand, Fehlt, Höchstpreis, Günstigstes, Rat.
- **Beobachtung ist eine besondere Liste** ohne Menge, immer oben, nicht löschbar. Je Gegenstand eine Grenze nach unten (kaufen bis) oder nach oben (verkaufen ab, siehe 6.6). Der eigene Reiter Beobachten entfällt.
- Rat zusätzlich „HÄNDLER“, wenn ein Händler günstiger ist.
- Unter der Liste die Kaufzeile mit Gold-Knopf, daneben der Knopf „Im Markt zeigen“.

### 4.4 Radar und Fokus: „Womit kann ich jetzt Gewinn machen?“ und „Wie verhält sich dieser Markt gerade?“

Zwei Reiter, die zusammengehören (Idee von KarloDerBaer, 11.11.2026), beide in Abschnitt 6.1 beschrieben:

- **Radar** ist eine schlanke Liste der Chancen: Gegenstand, Gewinn, Art, Risiko, Stand. Der Radar-Scan hält die gezeigten Chancen aktuell. Ein Klick auf eine Zeile öffnet sie im Fokus.
- **Fokus** zeigt immer genau einen Gegenstand: alles zu seiner Chance, laufende Messung nur für ihn, Kaufen. Man kann dort auch einen Gegenstand verfolgen, den das Radar nicht vorgeschlagen hat.

In Stufe 1 (N6) entstehen beide Reiter in ihrer Grundform mit der Art Händler: Liste, Radar-Scan, Fokus mit Angaben und Kaufen. Das laufende Messen kommt mit H2.

### 4.5 Auktionen: „Wie stehen meine Auktionen?“

Am Auktionator Blizzards Seite mit Kopfzeile und Spalte Broker wie heute. Unterwegs der letzte bekannte Stand als Liste (Gegenstand, Preis, Restzeit, Status), deutlich als alt markiert.

### 4.6 Gegenstand: „Was weiß ich über diesen Gegenstand?“

Die einzige Seite mit vielen Angaben. Sie zeigt immer den zuletzt gewählten Gegenstand.

- Oben `UI.ItemHeader`, daneben die Knöpfe Im Markt zeigen, Beobachten, Auf Einkaufsliste.
- Links Werte: Preis ab, üblicher Bereich (mit Hinweis, wenn unsicher), Absatz, Händler, Neutral, Herstellen.
- Rechts Diagramm (7, 14, 30, 90 Tage): günstigstes Angebot, üblicher Bereich, Menge.
- Darunter die günstigsten Preisstufen des letzten Stands (zeigt Preissprünge) und „Mein Bestand“ aus Ledger (Vorrat, Kosten, eigene Verkäufe).
- Ersetzt den Reiter Info und Brokers alten Reiter Preise. Ledgers eigener Reiter Gegenstand entfällt bei dessen Überarbeitung (schon am 09.11.2026 entschieden).

### 4.7 Mehr: Händler, Neutral, Datenlage

Ein Reiter mit drei Unterpunkten (`UI.TopTabs`):

- **Händler:** Liste aller gesehenen Händlerwaren mit Preis, Händler, Zone und AH-Preis. Der eigentliche Nutzen liegt aber an der Stelle des Kaufs: Warnung in Blizzards Kaufansicht, Rat „HÄNDLER“ in Einkaufen, Zeile im Tooltip. Die beiden Speicher `merchant` und `vendors` werden zu einem. Grenze: Broker kennt nur Händler, die man besucht hat, dazu die geschätzte Liste bekannter Reagenzien.
- **Neutral:** der heutige Marktvergleich.
- **Datenlage:** die heutigen Quellen, als ruhige Übersicht.

## 5. Navigation und Sprünge

Eine zentrale Funktion (`ns.Go(ziel, gegenstand)`) für alle Sprünge. Jede Liste mit Gegenständen verhält sich gleich:

| Bedienung | Wirkung |
|---|---|
| Linksklick | Zeile wählen |
| Doppelklick | Im Markt zeigen |
| Rechtsklick | Menü: Im Markt zeigen, Gegenstand, In den Fokus, Beobachten, Auf Einkaufsliste |
| Strg+Rechtsklick | dasselbe Menü auf jedem Gegenstand im Spiel (Kern, wie heute) |
| Maus darüber | Tooltip des Gegenstands |

- **Im Markt zeigen:** am Auktionator Blizzards Kaufansicht mit genau diesem Gegenstand und seinen Angeboten. Unterwegs die Marktseite aus Scandaten mit dem Gegenstand gewählt. Die heutige Sperre bei offenem Broker-Reiter entfällt: Broker schließt erst seine Fläche und stellt dann Blizzards Ansicht um.
- **Knöpfe an ausgewählten Stellen:** „Im Markt zeigen“ in der Kaufzeile von Radar und Einkaufen, die drei Knöpfe auf der Seite Gegenstand, „Gegenstand“ in Blizzards Kaufansicht.
- **Ausnahme Radar:** Dort öffnet schon der einfache Klick die Zeile im Fokus, weil die Liste nur der Auswahl dient. Rechtsklick und Tooltip wie überall.
- **Zurück:** Nach einem Sprung steht oben links ein kleiner Knopf „Zurück zu Radar“ (oder Einkaufen und so weiter). Ein Schritt zurück, kein Verlauf.
- Derselbe Sprung steht auch im Menü der Einträge in Ledger und Bags, sobald diese Module überarbeitet werden.

## 6. Hilfen zum Ein- und Verkauf (Stufe 2)

### 6.1 Radar neu: Aufkauf

Die Art heißt **Aufkauf** (KarloDerBaer, 11.11.2026). Das Vorgehen von KarloDerBaer: Massenware bis zu einer Preisstufe aufkaufen und zum Preis der nächsten Stufe wieder einstellen. Bei gleichem Preis verkauft das Spiel die zuletzt eingestellte Ware zuerst. Wer genau zum Preis der nächsten Stufe einstellt, steht also vorn. Es scheitert, wenn unter dem Zielpreis mehr neue Ware eingestellt als gekauft wird.

Im Radar gibt es vorerst nur zwei Arten: **Aufkauf** und **Händler** (unter Händlerpreis, sicherer Gewinn). Die heutige Art „unter dem üblichen Preis“ entfällt. Der Radar-Scan bleibt, prüft aber nur noch die gezeigten Chancen (KarloDerBaer, 11.11.2026).

#### Ablauf in drei Schritten

```
Komplettscan  ->  Radar: Liste der Chancen  ->  Radar-Scan  ->  Klick  ->  Fokus: ein Gegenstand, messen, Urteil, Kaufen
```

1. **Liste nach dem Komplettscan** (Reiter Radar). Broker rechnet aus den gespeicherten Preisstufen alle Chancen und listet sie. Nichts wird von selbst live nachgeprüft. Jede Zeile zeigt, wie alt ihr Stand ist.
2. **Radar-Scan.** Ein Knopf startet und stoppt ihn. Er geht reihum durch alle gezeigten Chancen und prüft live, ob sie noch stimmen (KarloDerBaer, 11.11.2026). Was weg ist, verschwindet, der Rest wird neu gerechnet, die Zeit in der Spalte Stand springt zurück. Er läuft nur, solange der Reiter Radar offen ist, und sucht keine neuen Gegenstände. Neue Chancen kommen aus dem nächsten Komplettscan.
3. **Fokus** (eigener Reiter). Ein Klick auf eine Chance öffnet sie dort. Broker misst den Gegenstand in kurzen Abständen und sagt, wie sich der Markt gerade verhält.

#### Wann etwas eine Chance ist

Für jede Stelle zwischen zwei Preisstufen: Kauf aller Stück darunter (Menge, Einsatz), Zielpreis = Preis der nächsten Stufe, Gewinn = Menge × Zielpreis nach Anteil des Hauses minus Einsatz. Eine Stelle zählt, wenn alles passt:

| Bedingung | Vorgabe | Einstellbar |
|---|---|---|
| Aufkaufbar: Einsatz höchstens mein Gold minus Reserve | Reserve 0 | ja |
| Gewinn in Gold mindestens | 50s | ja |
| Schnell wieder verkauft: Menge ÷ Absatz je Stunde höchstens | 2 Std. | ja |
| Kein anhaltender Trend nach unten (Preis fällt seit mehreren Ständen) | fest | nein |

- Einen Mindestsprung in Prozent gibt es nicht. Bei Massenware geht es oft um wenige Kupfer, es zählt der Gewinn in Gold. Die Rechnung zieht den Anteil des Hauses ab, darunter lohnt es ohnehin nie.
- Der übliche Bereich aus dem Verlauf filtert nicht. Nur der Trend nach unten schließt aus.
- Je Gegenstand zählt die Stelle mit dem höchsten Gewinn, die alle Bedingungen erfüllt.
- **Risiko** als Ampel je Zeile (grün, gelb, rot), aus: Verkaufsdauer nahe an der Grenze, viel Ware knapp über dem Zielpreis, dünne nächste Stufe, großer Teil des eigenen Golds im Einsatz, alter Stand, wenig Absatzdaten.

**Liste im Radar, bewusst schlank** (KarloDerBaer, 11.11.2026): Gegenstand, Gewinn, Art (Aufkauf oder Händler), Risiko, Stand. Vorgabe der Sortierung: Gewinn, bei rotem Risiko nach unten. Alle weiteren Angaben (Kaufen bis, Menge, Einsatz, Zielpreis, Verkauft in) stehen im Fokus.

#### Reiter Fokus

```
┌ Chance ───────────────────────────┐┌ Markt jetzt ─────────── Messung alle 5 Sek. ┐
│ [Symbol] Robuster Stein           ││ Preisleiter                                 │
│                                   ││   60s    340   <- kaufen bis                │
│ KAUFEN (grün)                     ││   95s    120   <- Ziel                      │
│ Mehr wird gekauft als eingestellt.││   96s    800                                │
│                                   ││                                             │
│ Kaufen bis      60s               ││ Abfluss            12 je Min.               │
│ Menge           340 Stück         ││ Zufluss unter Ziel  3 je Min.               │
│ Einsatz         41g               ││ Menge unter Ziel   schrumpft                │
│ Ziel            95s               ││ Günstigster Preis  bleibt                   │
│ Gewinn          14g               ││                                             │
│ Verkauft in     etwa 40 Min.      ││ [ Diagramm: Menge unter Ziel, Preis ]       │
│                                   ││                                             │
│ [ Kaufen 340 ]                    ││                                             │
│ [Im Markt zeigen]  [Gegenstand]   ││                                             │
└───────────────────────────────────┘└─────────────────────────────────────────────┘
```

- **Immer genau ein Gegenstand** (KarloDerBaer, 11.11.2026). Der Fokus zeigt alles Wichtige nur für diesen einen und fragt nur ihn ab. Links die Chance mit Urteil und Kaufen, rechts der Markt in diesem Moment.
- **Hinein** kommt ein Gegenstand per Klick im Radar oder über „In den Fokus“ im Menü jedes Gegenstands. Er ersetzt den bisherigen. So lässt sich auch ein Gegenstand verfolgen, den das Radar nicht vorgeschlagen hat. Der letzte Gegenstand bleibt gemerkt.
- **Kurzer Abstand:** Der Markt für Massenware gilt für ganz Europa und ändert sich sehr schnell. Vorgabe **5 Sekunden**, einstellbar von 3 bis 30. Gemessen wird, solange der Reiter Fokus offen ist.
- **Technische Grenze:** Das Spiel nimmt rund 90 Abfragen je Minute an, große Angebotslisten kommen in mehreren Teilen. 5 Sekunden für einen Gegenstand liegen weit darunter. Meldet das Spiel, dass es gerade keine Abfrage annimmt, wartet Broker und zeigt den tatsächlichen Abstand an. Wie kurz es wirklich geht, zeigt erst der Test im Spiel.
- Für einen Gegenstand ohne Chance (über das Menü in den Fokus gesetzt) zeigt der Fokus rechts Preisleiter, Messwerte und Diagramm, links steht „Zurzeit keine Chance“. Rechnet sich später ein Aufkauf, erscheinen die Zeilen zur Chance und der Kaufknopf.
- Aus zwei Abfragen nacheinander erkennt Broker schon heute, was verkauft, abgebrochen und neu eingestellt wurde (`Sales.lua`, mit Auktionsnummern). Daraus entstehen:

| Messwert | Bedeutung |
|---|---|
| Abfluss | gekaufte Stück je Minute |
| Zufluss unter Ziel | neu eingestellte Stück unter dem Zielpreis je Minute |
| Menge unter Ziel | wächst, bleibt, schrumpft |
| Günstigster Preis | fällt, bleibt, steigt |

- **Urteil** zuerst nach 30 Sekunden als „vorläufig“, ab 2 Minuten ohne diesen Zusatz, danach laufend genauer:

| Urteil | Wann |
|---|---|
| **Kaufen** (grün) | Abfluss größer als Zufluss unter Ziel, Menge unter Ziel wächst nicht, Preis fällt nicht |
| **Abwarten** (gelb) | kaum Bewegung oder Zufluss und Abfluss etwa gleich |
| **Finger weg** (rot) | Menge unter Ziel wächst oder der günstigste Preis fällt |

- Die geschätzte Verkaufsdauer rechnet mit dem gemessenen Abfluss, sobald genug Messungen da sind, vorher mit dem Absatz der letzten Stunden.
- Gekauft wird mit dem Stand der letzten Messung (wenige Sekunden alt). Das Spiel nennt vor dem Bestätigen ohnehin den echten Gesamtpreis. Weicht er vom erwarteten ab, warnt Broker vor dem zweiten Klick.
- Chancen der Art Händler öffnen ebenfalls im Fokus (Kaufen bis Händlerpreis, Gewinn beim Verkauf an den Händler). Das Messen spielt dort kaum eine Rolle.
- **Grenze:** Bei Ware, die sich langsam dreht, zeigen zwei Minuten wenig. Dann steht „zu wenig Bewegung“, und es gilt der Absatz aus den letzten Stunden. Wer länger offen lässt, bekommt ein besseres Urteil.
- **Nach dem Einstellen** kann derselbe Fokus den eigenen Posten bewachen (wächst die Menge unter meinem Preis?). Das kommt mit 6.2.

Einstellungen: Mindestgewinn, Goldreserve, höchste Verkaufsdauer, Abstand im Fokus, Ton. Alle übrigen heutigen Radar-Einstellungen entfallen.

Kandidaten kommen zuerst nur aus dem Komplettscan (Broker speichert die 12 günstigsten Stufen je Gegenstand, Aktualisieren und Fokus lesen alle). Später kann der Manager Kandidaten aus den stündlichen Ständen der Blizzard-API liefern (6.7).

### 6.2 Wiederverkauf-Kette

Gekauftes kommt per Post. Zwischen Kaufen und Einstellen liegt also immer ein Gang zum Briefkasten. Broker merkt sich deshalb jeden Radar-Kauf als **Posten** (Gegenstand, Menge, Einsatz, Zielpreis):

- Die Statuszeile und der Reiter Verkaufen zeigen „3 Posten zum Einstellen“.
- Eine Liste „Zum Einstellen“ zeigt die Posten mit Ziel und ob die Ware schon in der Tasche ist. Ein Klick legt den Gegenstand in Blizzards Verkaufsfenster, ein zweiter Klick auf Blizzards „Auktion erstellen“ stellt ein.
- Der Rat nennt Einsatz und Ziel und warnt, wenn der Markt inzwischen unter dem Ziel liegt.
- **Knopf „Zielpreis eintragen“** schreibt bei einem Posten den Zielpreis in Blizzards Feld (KarloDerBaer, 11.11.2026: ja, wenn es sinnvoll ist). Das ändert die Entscheidung vom 09.11.2026 (Broker trägt keinen Preis ein) nur für Posten und nur per Klick. Vor dem Bau eine Prüfung auf Blockaden wie bei U0. Blockiert es, bleibt der Preis nur im Rat stehen und man tippt ihn selbst.
- Der Fokus (6.1) kann einen eingestellten Posten bewachen und warnt, wenn die Menge unter dem eigenen Preis wächst.

### 6.3 Unterbotene Auktionen

- Knopf „Unterbotene abbrechen“ unter Auktionen: Jeder Klick bricht die nächste unterbotene Auktion ab (das Spiel erlaubt eine je Klick). Vorher steht da, was an Einzahlung verloren geht.
- Abgebrochenes kommt per Post zurück. Es landet als Posten in derselben Liste „Zum Einstellen“ (6.2) mit dem neuen Preis. „Neu einstellen“ ist damit kein eigener Ablauf mehr.

### 6.4 Händler-Warnung beim Kauf

Siehe 4.7. Klein, wirkt an drei Stellen.

### 6.5 Material aus dem Berufsfenster auf die Einkaufsliste

Knopf im Broker-Block des Berufsfensters: fehlendes Material für N Herstellungen auf eine Liste setzen. Was der Händler günstiger hat, wird als Händlerware markiert.

### 6.6 Beobachtung für den Verkauf

Grenze nach oben: „Melde, wenn der Preis über X liegt“ für Dinge, die man später verkaufen will. Meldung wie beim Preisalarm heute. Auf der Seite Gegenstand sieht man dazu den Verlauf.

### 6.7 Für später vorgemerkt

Nicht Teil der ersten Fassung des Neuaufbaus (KarloDerBaer, 11.11.2026).

- **Kandidaten vom Manager:** Der Manager kennt aus der Blizzard-API stündlich alle Angebote und kann Preissprünge vorrechnen. Er schickt nur die Liste der Gegenstände, Broker prüft live. Damit findet das Radar Chancen ohne eigenen Komplettscan.
- **Erfolgskontrolle:** Je Posten Einsatz, Erlös und Dauer aus Ledger. Eine kleine Zeile „letzte 14 Tage: 12 Posten, Gewinn 84g, 2 mit Verlust“ zeigt, ob die Grenzwerte passen.
- **Alles Lohnende kaufen** in Einkaufen: Jeder Klick kauft die nächste grüne Zeile.

### 6.8 Nutzen und Aufwand

| Hilfe | Nutzen | Aufwand |
|---|---|---|
| Radar Aufkauf mit Liste und Aktualisieren (6.1) | sehr hoch | mittel |
| Fokus (6.1) | sehr hoch | groß |
| Wiederverkauf-Kette (6.2) | hoch | mittel |
| Unterbotene abbrechen und Zum Einstellen (6.3) | mittel | klein, wenn 6.2 steht |
| Händler-Warnung (6.4) | mittel | klein |
| Material auf Einkaufsliste (6.5) | später hoch | klein |
| Beobachtung für den Verkauf (6.6) | mittel | klein |
| Später: Kandidaten vom Manager (6.7) | hoch | mittel |
| Später: Erfolgskontrolle (6.7) | mittel | mittel |
| Später: Alles Lohnende kaufen (6.7) | später mittel | klein |

## 7. Was wegfällt oder zusammengelegt wird (Vorschlag, nichts ohne Zustimmung)

- Eigene Reiter Beobachten, Quellen, Marktvergleich, Händler (wandern in Einkaufen und Mehr).
- Reiter Info und alter Reiter Preise (werden Seite Gegenstand).
- `Window.lua`, `Look.lua`, `Pages.lua`, `Prices.lua` in der heutigen Form (neu mit `Peon.UI`).
- Radar-Art „unter dem üblichen Preis“, die Suche des Radar-Scans nach neuen Gegenständen, die Live-Prüfung beim Öffnen, der abgeschaltete Schnellkauf und die meisten Radar-Einstellungen.
- Speicher `merchant` (geht in `vendors` auf).
- Tooltip: Standard-Vorlage wird schlanker, die Bausteine bleiben einstellbar.

Gespeicherte Daten (Listen, Beobachtung, Händler, Preise) bleiben alle erhalten.

## 8. Bauabschnitte

Jeder Schritt ist eine eigene Version und wird im Spiel geprüft, bevor der nächste beginnt.

**Stufe 1: Grundfunktionen**

| Schritt | Inhalt | Größe |
|---|---|---|
| N1 Gerüst | Ein Fenster in zwei Zuständen, Reiterleiste, Statuszeile, Sprünge mit Zurück, Menü. Seiten vorerst mit altem Inhalt im neuen Rahmen | mittel |
| N2 Gegenstand | Seite Gegenstand mit Diagramm, Preisstufen, Mein Bestand | mittel |
| N3 Markt (Scan) | Kategorien, Suche, Liste, Sprung von überall | mittel |
| N4 Einkaufen | neu mit `Peon.UI`, Beobachtung als besondere Liste | mittel |
| N5 Mehr und Auktionen | Händler, Neutral, Datenlage, Auktionen unterwegs, ein Händler-Speicher | mittel |
| N6 Radar und Fokus, Grundform | schlanke Radar-Liste mit Radar-Scan, Reiter Fokus für einen Gegenstand mit Angaben und Kaufen, nur Art Händler, Altes entfernt | mittel |

**Stufe 2: Hilfen**

| Schritt | Inhalt | Größe |
|---|---|---|
| H1 Aufkauf: Chancen | 6.1 Schritte 1 und 2: Chancen aus dem Komplettscan, Bedingungen, Risiko, Angaben im Fokus | mittel |
| H2 Fokus: Messen | 6.1 Schritt 3: laufende Abfragen, Messwerte, Urteil, Diagramm, eigenen Gegenstand verfolgen | groß |
| H3 Wiederverkauf-Kette | 6.2 mit Prüfung „Zielpreis eintragen“, dazu 6.3 | mittel |
| H4 Kleine Hilfen | 6.4, 6.5, 6.6 | klein bis mittel |
| H5 Manager | Seiten und Begriffe angleichen | groß |

Die Reihenfolge bleibt so (KarloDerBaer, 11.11.2026): erst N1 bis N6, dann H1 bis H5. Die Punkte aus 6.7 kommen danach.

## 9. Abstimmung mit KarloDerBaer

### Geklärt (11.11.2026)

1. **Variante A** (Abschnitt 3): einverstanden.
2. **Reiter:** Markt, Verkaufen, Auktionen, Einkaufen, Radar, Fokus, Gegenstand, Mehr.
3. **Aufkauf:** kein Mindestsprung in Prozent. Es zählen Aufkaufbarkeit, Gewinn in Gold gegen das Risiko, schneller Wiederverkauf (Vorgabe 2 Std., einstellbar) und kein anhaltender Trend nach unten.
4. **Radar:** nur Aufkauf und Händler. Keine Live-Prüfung von selbst. Der Radar-Scan (Knopf) prüft reihum die gezeigten Chancen, jede Zeile zeigt ihr Alter.
5. **Zielpreis eintragen:** ja, wenn die Prüfung auf Blockaden sauber ist.
6. **Streichliste** (Abschnitt 7): einverstanden.
7. **Reihenfolge** der Bauabschnitte: wie in Abschnitt 8.
8. **6.7** ist für später vorgemerkt.

9. **Name** der Radar-Art: Aufkauf.
10. **Radar schlank, Fokus als eigener Reiter:** Radar zeigt nur Gegenstand, Gewinn, Art, Risiko, Stand. Ein Klick öffnet den Fokus mit diesem Gegenstand.
11. **Fokus zeigt und misst immer genau einen Gegenstand** in kurzem Abstand (Vorgabe 5 Sekunden, einstellbar). Keine Liste im Fokus. Ein eigener Gegenstand kommt über „In den Fokus“ im Menü hinein.
12. **Trend nach unten:** Brokers heutige Regel „Preis fällt seit mehreren Ständen“ reicht.
13. **Freigabe** des Konzepts (11.11.2026). Gebaut wird ab N1, jeder Schritt als eigene Version mit Prüfung im Spiel.

### Offen

- Im Spiel zu messen: Breite der acht Reiter (N1), kürzester Abstand im Fokus, den das Spiel annimmt (H2), Blockaden bei „Zielpreis eintragen“ (H3).
- Grenzwerte für Risiko und Urteil: Startwerte gesetzt (Entscheidungen 12.11.2026), mit echten Daten nachzuschärfen.
- Abweichungen beim Bau von Stufe 2, mit KarloDerBaer abzustimmen: „Im Markt zeigen“ öffnet nur Blizzards Suchergebnis, nicht direkt die Angebote (Broker 0.64.1). Ein Klick in „Zum Einstellen“ legt nichts selbst ins Verkaufsfenster (Broker 0.67.0). Beides, weil Broker sonst Blizzards Wert `displayMode` berührt und das Spiel danach das Benutzen aus der Tasche blockiert (Fehlerberichte 10 und 11).
- Im Manager bleibt der Reiter Wiederverkauf vorerst (Manager 0.26.0).