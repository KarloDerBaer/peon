# Peon_Broker – Absatzquote (Konzept)

Stand: 03.10.2026, **abgestimmt mit KarloDerBaer** (Abschnitt 9), **A1 umgesetzt in Broker 0.23.0, überarbeitet in 0.23.1** (Abschnitt 11). Grundlage: Prüfung der Suchergebnisse in Forever (Peon_Stand.md, Broker 0.22.0), Entscheidung 03.10.2026 (Verkaufsquote und Absatzquote getrennt).

## 1. Ziel

Broker soll wissen, **wie gut sich ein Gegenstand auf dem Markt verkauft** – unabhängig davon, ob du ihn selbst schon verkauft hast. Zwei Werte je Gegenstand:

| Wert | Frage | Beispiel |
|---|---|---|
| **Absatz je Tag** | Wie viel kaufen andere Spieler pro Tag? | „~120 Stück/Tag“ |
| **Absatzquote** | Von den Angeboten, die endeten: wie viele wurden gekauft, wie viele liefen ab? | „70 % verkauft“ |

Die eigene **Verkaufsquote** (Ledger) bleibt ein eigener Wert. Wie beide später zusammen genutzt werden (z. B. „Chance, dass dein Angebot verkauft wird“), wird erst entschieden, wenn genug Daten da sind.

## 2. Was das Spiel liefert (geprüft 03.10.2026)

| Quelle | Auktionsnummer | Restzeit | Verkäufer | Umfang |
|---|---|---|---|---|
| Live-Abfrage Massenware | ja | **Sekunden genau** | nur Anzahl | ein Gegenstand, billigste zuerst, evtl. nur ein Teil |
| Live-Abfrage Einzelgegenstand | ja | Stufe (bis 30 Min., 2 Std., 12 Std., länger) | nur Anzahl | ein Gegenstand |
| Komplettscan | nein | Stufe über eigene Funktion (noch zu prüfen) | nein | ganzer Markt |

## 3. Wie Broker Verkäufe erkennt

Broker merkt sich bei jeder Live-Abfrage die Angebote mit Nummer, Menge, Preis und **erwartetem Ende** (jetzt + Restzeit). Bei der nächsten Abfrage desselben Gegenstands vergleicht er:

| Beobachtung | Bedeutung | Zählt als |
|---|---|---|
| Gleiche Nummer, Menge kleiner (z. B. 200 → 140) | jemand hat einen Teil gekauft (Massenware) | **verkauft** (60 Stück) – sicher |
| Nummer fehlt, erwartetes Ende noch nicht erreicht | gekauft oder vom Verkäufer abgebrochen | **verkauft**, außer es greift die Abbruch-Regel |
| Nummer fehlt, erwartetes Ende vorbei | abgelaufen | **abgelaufen** |
| Neue Nummer | neu eingestellt | Angebot (für die Menge am Markt) |

**Abbruch-Regel „billigeres Angebot blieb stehen“** (Vorschlag KarloDerBaer, geprüft): Massenware kauft man im Auktionshaus immer **von unten** – das Spiel nimmt beim Kauf automatisch die günstigsten Stücke zuerst, ein teureres Angebot kann man nicht gezielt kaufen. Daraus folgt: Fehlt ein Angebot, obwohl **ein günstigeres Angebot in beiden Abfragen da war** (auch wenn davon ein Teil gekauft wurde), kann es nicht gekauft worden sein → **abgebrochen** (oder abgelaufen, wenn die Zeit um war). Das ist für Massenware eine sichere Regel, keine Schätzung.
- Wichtig „in beiden“: Ist das günstigere Angebot erst neu dazugekommen, könnte das teurere vorher noch gekauft worden sein → keine Aussage.
- **Einzelgegenstände** (Ausrüstung): Käufer wählen selbst, und die Preise hängen stark vom Zusatz ab („des Bären“). Die Regel gilt dort **nicht** (KarloDerBaer). Stattdessen: Fehlt ein Angebot vor Ablauf, gilt es als gekauft – abzüglich eines **Schätzwerts für Abbrüche**, Standard **10 %** (einstellbar). Beispiel: 10 Angebote vor Ablauf verschwunden → 9 verkauft, 1 abgebrochen.
- Zusätzlich (nur Massenware): Fehlt eine Nummer und taucht eine **neue Nummer mit derselben Menge zu niedrigerem Preis** auf → abgebrochen und billiger neu eingestellt.

**Nur vergleichen, was beide Male sicher gesehen wurde:** Die Antwort kommt nach Preis sortiert und manchmal nur zum Teil. Verglichen wird deshalb nur bis zum höchsten Preis, den **beide** Abfragen vollständig enthalten. Was teurer war, zählt nicht.

**Einzelgegenstände:** Restzeit nur als Stufe. „Fehlt, Stufe war 12 Std. oder länger und es ist weniger Zeit vergangen“ → nicht abgelaufen. Bei „bis 30 Min.“ oder „bis 2 Std.“ bleibt es unklar → zählt weder als verkauft noch als abgelaufen.

**Abstand zwischen zwei Abfragen:** höchstens 24 Std.; was länger her ist, wird nicht verglichen (zu viel unbekannt).

## 4. Werte je Gegenstand

- Gespeichert je Tag: verkauft (Stück), abgelaufen (Stück), abgebrochen (Stück), beobachtete Zeit (Stunden zwischen verglichenen Abfragen/Scans) und **Zahl der Vergleiche**.
- **Absatz je Tag** = verkaufte Stück ÷ beobachtete Zeit × 24 Std., über die letzten 14 Tage.
- **Absatzquote** = verkauft ÷ (verkauft + abgelaufen), letzte 14 Tage.
- **Angezeigt ab dem ersten Vergleich** (Wunsch KarloDerBaer). Die **Sicherheit** zeigt ein Zeichen vor der Zahl, nicht die Farbe der Zahl (KarloDerBaer):

| Stufe | Vergleiche (Standard, einstellbar) | Anzeige |
|---|---|---|
| unsicher | 1–4 | grau „≈“ vor der Zahl, z. B. ≈ 120/Tag |
| mittel | 5–14 | gelb „≈“ vor der Zahl |
| sicher | ab 15 | ohne Zeichen |

- Die **Farbe der Zahl** bleibt frei für „viel oder wenig Absatz“ (grün viel, rot wenig). Grundlage dafür: offen (Abschnitt 10).
- Zusätzlich je Verkauf der Preis im Verhältnis zum Richtwert (unter / im / über dem üblichen Bereich) – Grundlage für eine spätere Chance je Preis.

## 5. Speicher

- **Letzter Stand je Gegenstand** (für den nächsten Vergleich): live die günstigsten 30 Angebote mit Nummer, Menge, Preis, Ende (`e.as`), aus dem Scan die günstigsten 15 ohne Nummer (`e.ss`); Ende in Minuten ab der Beobachtung, damit der Text kurz bleibt (geschätzt einige hundert KB). Ein Stand älter als 24 Std. wird nicht mehr verglichen, nur ersetzt.
- **Schon gezählter Zeitraum** (`e.acov`): Ein Vergleich zählt nur, wenn sein Anfang nicht vor dem Ende des letzten gezählten Vergleichs liegt – so wird nichts doppelt gezählt (Live und Scan). Mindestabstand 10 Min.
- **Tageswerte** wie die Preise: 30 Tage einzeln, danach Wochenwerte.

## 6. Anzeige

- **Tooltip mit Umschalt:** „Absatz: ~120/Tag · 70 % verkauft (14 T.)“, darunter wie bisher „Deine Verkäufe (30 T.): 3 von 4“.
- **Verkaufen:** Hinweis „verkauft sich gut“ bzw. „läuft oft ab – lieber Händler?“ (Schwellen werden nach den ersten Daten festgelegt).
- **Preise:** Spalte „Absatz/Tag“.
- Radar und Vorschlag bleiben vorerst unverändert.

## 7. Komplettscan (gleich mit dabei, Wunsch KarloDerBaer)

Ohne Auktionsnummern vergleicht Broker je Gegenstand die Angebote (Preis + Menge) zweier Scans:
- Gleiches Angebot (Preis und Menge) in beiden Scans = steht noch.
- **Massenware, von unten:** Was unterhalb des günstigsten Angebots fehlt, das in beiden Scans stand (auch teilweise gekauft), wurde gekauft (oder ist abgelaufen). Was **oberhalb** davon fehlt, wurde abgebrochen (Regel aus Abschnitt 3).
- **Ablauf:** Liefert Forever die Restzeit-Stufe im Scan (Prüfung `/broker pruefen scan` steht aus), zählt ein fehlendes Angebot mit Stufe „länger als 12 Std.“ bei weniger als 12 Std. Abstand sicher als „nicht abgelaufen“. Ohne Stufe: nur Scans mit höchstens 2 Std. Abstand zählen für „verkauft“, sonst „unklar“.
- Ein Scan-Vergleich zählt für die Sicherheit wie ein Vergleich einer Live-Abfrage.
- Vorteil: gilt für den ganzen Markt; Nachteil: ungenauer (gleiche Preis/Menge von verschiedenen Verkäufern verwechselbar).

## 8. Bauabschnitte

1. **A1 – Sammeln und anzeigen** (umgesetzt in Broker 0.23.0): Live-Abfragen und Komplettscan vergleichen, Zähler je Tag; Anzeige ab dem ersten Vergleich mit Sicherheits-Farbe (Tooltip mit Umschalt, Hinweis beim Verkaufen, Spalte „Absatz/Tag“ in Preise); Optionen für die zwei Schwellen; `/broker absatz <Gegenstand>` zeigt die Zähler im Chat.
2. **A2 – Verfeinern** nach den ersten Daten (Schwellen der Hinweise beim Verkaufen, Restzeit im Scan).
3. **A3 – Verbinden** mit der eigenen Verkaufsquote und Chance je Preis (eigene Abstimmung).

## 9. Entschieden (KarloDerBaer, 03.10.2026)

1. Komplettscan gleich mit dabei (nicht erst später).
2. Anzeige ab dem ersten Vergleich, Sicherheit farbig in drei Stufen, Schwellen in den Optionen einstellbar.
3. Abbruch-Regel: Fehlt ein Angebot, obwohl ein günstigeres in beiden Abfragen/Scans stand, wurde es abgebrochen (Vorschlag KarloDerBaer; für Massenware sicher, weil man immer von unten kauft). Einzelgegenstände: verschwunden vor Ablauf = gekauft, abzüglich Schätzwert Abbrüche (Standard 10 %, einstellbar).
6. Sicherheit als Zeichen „≈“ vor der Zahl (grau unsicher, gelb mittel, ohne Zeichen sicher); Farbe der Zahl für viel/wenig Absatz.
4. Zeitraum 14 Tage (Wert aber von Anfang an sichtbar).
5. Anzeige: Tooltip mit Umschalt, Hinweis beim Verkaufen, Spalte in „Preise“.

## 10. Farbe der Zahl (entschieden 03.10.2026)

- **Farbe der Zahl (viel/wenig Absatz):** nach **Reichweite** (KarloDerBaer: „passt super“) = aktuelle Angebotsmenge ÷ Absatz je Tag („so viele Tage dauert es, bis alles verkauft ist“): unter 1 Tag grün, 1–7 Tage weiß, über 7 Tage rot; Grenzen einstellbar. Absolute Stückzahlen taugen nicht, weil 5 Stück/Tag bei Ausrüstung viel und bei Leinenstoff wenig sind.

## 11. Überarbeitung nach dem ersten Test (Broker 0.23.1, KarloDerBaer 03.10.2026)

- **Hauptwert = aktueller Absatz je Stunde** aus den Vergleichen der letzten 6 Std. (einstellbar). Der 14-Tage-Wert (Abschnitt 4) bleibt intern.
- **Sicherheit nach beobachteter Zeit** (nicht Zahl der Vergleiche, weil 15 Sek. Radar sonst so viel zählen wie 15 Min. zwischen Scans): rot unter 60 Min., gelb ab 60, grün ab 180 Min. (einstellbar). Das Zeichen „≈“ steht immer da. Die Zahl bleibt weiß; „viel/wenig“ zeigen die Hinweise beim Verkaufen (Reichweite), erst ab gelb.
- **Live-Vergleiche ab 1 Min. Abstand** statt 10 Min.
- **Tooltip ohne Reichweite**; Reichweite nur beim Verkaufen, in Stunden oder Tagen.
- **Restzeit-Stufen in Forever 1–4** (Komplettscan), Retail 0–3.
