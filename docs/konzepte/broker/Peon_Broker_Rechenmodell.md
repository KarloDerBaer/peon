# Peon_Broker – Rechenmodell

Stand: 30.09.2026, **abgestimmt** (Kapitel 1–3 mit KarloDerBaer durchgesprochen, Grundlage für Broker 0.6.0; Kapitel 4 Verkaufen für 0.8.0) – wird Schritt für Schritt erarbeitet, bevor wieder programmiert wird.
Reihenfolge: 1. Begriffe, 2. Formeln, 3. Anzeige (Tooltip, später Fenster).

Alle Preise sind **je Stück** in Kupfer, solange nichts anderes steht. Die Anzeige rechnet am Ende mit der Stapelgröße hoch.
Markierung **(neu)**: weicht vom jetzigen Stand (Broker 0.5.1) ab. **(offen)**: noch nicht entschieden.

Quellen:

- **Spiel** – vom Spiel abgefragt
- **Scan** – beim Auswerten eines Komplettscans ermittelt und gespeichert
- **Formel (beim Scan)** – beim Scan berechnet und gespeichert
- **Formel (bei Anzeige)** – erst berechnet, wenn Tooltip oder Fenster es brauchen, nicht gespeichert
- **Einstellung** – von dir in den Optionen festgelegt
- **Festwert** – im Addon festgelegt

## 1. Begriffe

### 1.1 Grunddaten aus dem Spiel

| Variable | Name | Beschreibung | Quelle |
|---|---|---|---|
| HP | Händlerpreis | Was der Händler für 1 Stück zahlt. | Spiel (`C_Item.GetItemInfo`), jederzeit |
| STAPEL | Stapelgröße | Anzahl Stück des Gegenstands unter der Maus. Unbekannt (z. B. Link im Chat) = 1. | Spiel (beim Anzeigen des Tooltips) |
| ART | Warenart | **Massenware** (Erze, Kräuter, Stoffe …: gleicher Preis je Stück, bei gleichem Preis wird das zuletzt eingestellte Angebot zuerst verkauft) oder **Einzelgegenstand** (Ausrüstung …: Käufer wählt ein bestimmtes Angebot). **(neu)** | Spiel bei geöffnetem Auktionshaus (Taschen); sonst Faustregel: stapelbar = Massenware; Ausrüstung mit Zusatz immer Einzelgegenstand |
| MARKT | Markt | Regelsatz + Fraktion, z. B. „Classic Beta PvE / Alliance“. Alle Werte gelten nur für den eigenen Markt. | Spiel (Realm-Name, Fraktion) |

### 1.2 Rohdaten eines Angebots (beim Scan)

| Variable | Name | Beschreibung | Quelle |
|---|---|---|---|
| A_MENGE | Angebotsmenge | Stück in einem einzelnen Angebot. | Scan |
| A_SKP | Sofortkaufpreis | Preis für das ganze Angebot. Angebote ohne Sofortkauf (nur Gebot) werden ignoriert. | Scan |
| A_EP | Einzelpreis des Angebots | A_SKP ÷ A_MENGE | Formel (beim Scan) |

### 1.3 Momentaufnahme je Gegenstand (je Scan)

| Variable | Name | Beschreibung | Quelle |
|---|---|---|---|
| AHmin | AH-Mindestpreis | Günstigster Einzelpreis aller Angebote. | Formel (beim Scan): kleinster A_EP |
| AHmedian | AH-Median | Preis, bei dem die Hälfte aller angebotenen **Stück** billiger und die Hälfte teurer ist (jedes Stück zählt einzeln). Ersetzt den bisherigen „Durchschnitt der günstigsten 25 %“. **(neu)** | Formel (beim Scan) |
| AHmenge | Angebotene Menge | Summe aller Stück im Auktionshaus. | Formel (beim Scan): Summe A_MENGE |
| AHanz | Anzahl Angebote | Anzahl einzelner Angebote. | Formel (beim Scan) |
| ZEIT | Scanzeitpunkt | Wann der Gegenstand zuletzt gescannt wurde. | Scan |

Vorwerte: Für den Trend merkt sich Broker bei jedem Scan die Werte des vorherigen Scans mit Zusatz **_vor** (AHmin_vor, AHmedian_vor, AHmenge_vor, ZEIT_vor). Abgeleitete Werte wie ERL_vor werden bei der Anzeige aus diesen Vorwerten berechnet.

~~AHstufen, A_KURZ, ABV, ABVh (Abverkauf)~~ – **entfallen (neu)**: Bei Massenware werden neue Angebote zum gleichen Preis zuerst verkauft; neue Angebote und Verkäufe auf derselben Preisstufe heben sich auf, der Abverkauf wäre systematisch zu niedrig (z. B. „0,0/Std.“ beim Leinenverband). Das Spiel verrät fremde Verkäufe nicht, und die Scan-Daten enthalten keine Kennung je Angebot. Ersatz später: eigene Verkäufe aus dem Buch (siehe 1.8).

### 1.4 Verlauf

| Variable | Name | Beschreibung | Quelle |
|---|---|---|---|
| TAGmin, TAGmedian, TAGmenge | Tageswerte | Mittel über **alle Scans eines Tages** (nicht mehr nur der letzte), damit z. B. abendliche Tiefpreise das Bild nicht verzerren. **(neu)** | Formel (beim Scan): Summe und Anzahl je Tag gespeichert |
| W7min, W7median, W7menge | 7-Tage-Werte | Mittel der Tageswerte der **letzten 7 Tage einschließlich heute** (gleitend: an Tag 8 die Tage 2–8, an Tag 9 die Tage 3–9 …). Der heutige Tageswert ist das Mittel der bisherigen Scans von heute. **(neu)** | Formel (bei Anzeige) |
| W7min_vortag, W7median_vortag | 7-Tage-Werte vom Vortag | Dieselben Werte einen Tag früher (an Tag 8 die Tage 1–7). Vergleichswert für den Trend der 7-Tage-Werte. **(neu)** | Formel (bei Anzeige) |
| WOCHE | Wochenwerte | Tageswerte, die älter sind als die Aufbewahrungszeit, werden je Woche zusammengefasst (ein halbes Jahr). | Formel (beim Scan, einmal am Tag) |

### 1.5 Abgeleitete Kennzahlen

| Variable | Name | Beschreibung | Quelle |
|---|---|---|---|
| REF | Vergleichspreis | AHmedian des letzten Scans (reagiert sofort auf Marktänderungen, ist aber unempfindlich gegen einzelne Dumping-Angebote). Bisher W7-Wert. **(neu)** | Formel (bei Anzeige) |
| DUMP | Dumping | Ja, wenn AHmin mehr als DG unter REF liegt. | Formel (bei Anzeige) |
| TREND(x) | Trend eines Werts | Änderung eines Werts gegenüber seinem Vorwert, in 5 Stufen. **Scan-Werte** (ERL, AHmin, AHmedian, AHmenge) gegenüber dem vorherigen Scan (x_vor). **7-Tage-Werte** gegenüber dem 7-Tage-Wert vom Vortag (an Tag 8: Tage 2–8 gegenüber Tage 1–7). | Formel (bei Anzeige) |

### 1.6 Preisvorschlag und Ergebnis

| Variable | Name | Beschreibung | Quelle |
|---|---|---|---|
| VP | Verkaufspreis-Vorschlag | Preis je Stück, den du beim Einstellen einträgst: Basis (AHmin, bei DUMP REF) minus UB bzw. UBmass. | Formel (bei Anzeige) |
| ERL | Erlös | Was du bei einem Verkauf zu VP bekommst: VP minus ANTEIL. Die Einstellgebühr kommt beim Verkauf zurück und wird deshalb nicht abgezogen. **(neu)** | Formel (bei Anzeige) |
| EG | Einstellgebühr | Gebühr beim Einstellen, abhängig von HP, Menge und LZ. Kommt bei Verkauf zurück, verloren nur wenn nicht verkauft. **(neu)** | Formel (bei Anzeige) aus HP, STAPEL, LZ, EG_SATZ; wird mit dem Spiel abgeglichen, wenn das Auktionshaus offen ist |
| MP | Mindestpreis | Niedrigster VP, bei dem ERL über HP liegt. | Formel (bei Anzeige) |
| EMPF | Empfehlung | „AH“ oder „Händler“, je nachdem, was mehr bringt (ERL gegenüber HP). Vorerst **ohne** Verlustrisiko der EG; das kommt erst mit der Verkaufsquote aus dem Buch (siehe 1.8). | Formel (bei Anzeige) |

### 1.7 Einstellungen und Festwerte

| Variable | Name | Beschreibung | Quelle |
|---|---|---|---|
| UB | Unterbieten Einzelgegenstände | Fester Betrag (Kupfer) oder Prozent. Standard 1 Kupfer. **(neu)** | Einstellung |
| UBmass | Unterbieten Massenware | Fester Betrag (Kupfer) oder Prozent. Standard 0 (gleicher Preis genügt, weil neue Angebote zuerst verkauft werden). **(neu)** | Einstellung |
| DG | Dumping-Grenze | Ab wie viel % unter REF der Mindestpreis als Dumping gilt. Standard 30 %. | Einstellung |
| TG_gleich | Trend-Grenze „gleich“ | Bis zu dieser Änderung gilt ein Wert als gleich geblieben. Standard 5 %. | Einstellung |
| TG_stark | Trend-Grenze „stark“ | Ab dieser Änderung gilt ein Wert als stark gestiegen/gefallen. Standard 20 %. | Einstellung |
| LZ | Laufzeit | Laufzeit einer Auktion: 2, 8 oder 24 Std. Standard 8 Std. **(neu)** | Einstellung |
| AUFB | Aufbewahrung | Wie lange Tageswerte bleiben, bevor sie zu Wochenwerten werden. Standard 30 Tage. | Einstellung |
| ANTEIL | Auktionshaus-Anteil | Anteil am Verkaufspreis, den das Auktionshaus bei einem **Verkauf** einbehält (zusätzlich zur Einstellgebühr, die aber zurückkommt). Retail: 5 %. Das Spiel bietet keine Abfrage dafür. | Festwert 5 %; wird mit den Rechnungen im Postfach überprüft, sobald das Buch sie liest |
| EG_SATZ | Gebührensatz | Anteil vom Händlerwert als Einstellgebühr: 2 Std. 5 %, 8 Std. 20 %, 24 Std. 60 %. Nicht veröffentlicht; aus Messwerten abgeleitet (Nachtkriecher 1c/4c/12c, Leinenverband 18 Stück 8 Std. = 72c). **(neu)** | Festwert; bei geöffnetem Auktionshaus mit der Berechnung des Spiels abgeglichen |

### 1.8 Für später (noch nicht Teil des Modells)

| Variable | Name | Beschreibung | Quelle |
|---|---|---|---|
| VQ | Verkaufsquote | Anteil deiner eigenen Angebote eines Gegenstands, die verkauft statt abgelaufen sind. Erst damit lässt sich das Verlustrisiko der Einstellgebühr bewerten: AH besser, wenn VQ × (ERL − HP) > (1 − VQ) × EG. | Buch (eigene Verkäufe und abgelaufene Auktionen aus dem Postfach) |
| – | Tagesverlauf | Preise nach Uhrzeit (wann ist ein Gegenstand am teuersten?). | später besprechen |
| – | Blizzard-API | Die offizielle Battle.net-Schnittstelle liefert für Retail stündliche Auktionsdaten mit Kennung je Angebot (damit wären echte Verkäufe fremder Spieler erkennbar). Für **Forever gibt es seit November 2026 eigene Bereiche, ob sie Auktionen liefern, ist offen** (siehe `Peon_Client_Design.md` 5.5), für Classic Era ist sie seit Ende 2024 gestört. Ein Addon kann außerdem nicht ins Internet; nötig wäre ein Zusatzprogramm auf dem PC. Erneut prüfen, falls Blizzard Forever-Daten veröffentlicht. | – |

## 2. Formeln

Durchgehendes Beispiel: **Kupfererz**, Stapel mit 20 Stück in der Tasche, HP = 5c, Massenware, LZ = 8 Std., UBmass = 0, DG = 30 %, TG_gleich = 5 %, TG_stark = 20 %.
Angebote im Auktionshaus beim Scan: 10 Stück zu 1s 20c · 40 Stück zu 1s 50c · 50 Stück zu 1s 60c · 20 Stück zu 5s (Mondpreis).

Rundung: Broker rechnet intern mit Kommastellen und rundet erst bei der Anzeige auf ganze Kupfer.

### 2.1 Beim Scan (je Gegenstand)

| Nr. | Wert | Formel | Beispiel |
|---|---|---|---|
| F1 | A_EP | A_SKP ÷ A_MENGE (je Angebot) | ein Stapel 10 Stück für 12s → 1s 20c je Stück |
| F2 | AHmin | kleinster A_EP | 1s 20c |
| F3 | AHmenge | Summe aller A_MENGE | 10 + 40 + 50 + 20 = 120 Stück |
| F4 | AHanz | Anzahl der Angebote | 4 |
| F5 | AHmedian | Angebote nach A_EP sortieren, Stück durchzählen. Ungerade AHmenge: Preis des mittleren Stücks. Gerade AHmenge: Mittel der Preise der beiden mittleren Stücke (Nr. AHmenge ÷ 2 und AHmenge ÷ 2 + 1). | 120 Stück → Stück Nr. 60 und 61; Stück 1–10 zu 1s 20c, 11–50 zu 1s 50c, 51–100 zu 1s 60c → (1s 60c + 1s 60c) ÷ 2 = **1s 60c** (der Mondpreis spielt keine Rolle) |
| F6 | _vor-Werte | vor dem Speichern: AHmin_vor = altes AHmin usw. | AHmin_vor = 1s 30c (vom Scan davor) |

### 2.2 Verlauf

| Nr. | Wert | Formel | Beispiel |
|---|---|---|---|
| F7 | TAGx | Summe von x über alle Scans des Tages ÷ Anzahl Scans des Tages (gespeichert als Summe und Anzahl). Ein Tag reicht von Mitternacht bis Mitternacht nach der Uhr des PCs. | morgens AHmin 1s 30c, abends 1s 20c → TAGmin = 1s 25c |
| F8 | W7x | Mittel der vorhandenen TAGx von heute und den 6 Tagen davor; Tage ohne Scan werden übersprungen. Angezeigt ab 2 Tageswerten, mit der Anzahl der Tage, z. B. „7 Tage (4)“. | an Tag 8: Mittel der TAGmin von Tag 2–8 |
| F9 | W7x_vortag | dasselbe für gestern und die 6 Tage davor | an Tag 8: Tag 1–7 |

### 2.3 Kennzahlen (bei Anzeige)

| Nr. | Wert | Formel | Beispiel |
|---|---|---|---|
| F10 | Änderung | Δ = (x − x_vor) ÷ x_vor × 100 % | AHmin 1s 30c → 1s 20c: Δ = −7,7 % |
| F11 | TREND | Δ ≥ +TG_stark: stark gestiegen · Δ > +TG_gleich: gestiegen · −TG_gleich ≤ Δ ≤ +TG_gleich: gleich · Δ < −TG_gleich: gefallen · Δ ≤ −TG_stark: stark gefallen. Ohne Vorwert: kein Symbol. Vorwert 0 und jetzt mehr als 0: stark gestiegen. | −7,7 % → **gefallen** |
| F12 | REF | = AHmedian | 1s 60c |
| F13 | DUMP | ja, wenn AHmin < REF × (1 − DG) | Grenze 1s 60c × 0,7 = 1s 12c; AHmin 1s 20c liegt darüber → **kein Dumping** |

### 2.4 Preisvorschlag, Erlös, Empfehlung (bei Anzeige)

| Nr. | Wert | Formel | Beispiel |
|---|---|---|---|
| F14 | Basis | ohne DUMP: AHmin. Bei DUMP: Mitte zwischen Dumping-Grenze und REF = (REF × (1 − DG) + REF) ÷ 2, also REF × (1 − DG ÷ 2) | ohne Dumping: 1s 20c |
| F15 | VP | Kupfer: Basis − UB (bzw. UBmass) · Prozent: Basis × (1 − UB) abgerundet · mindestens 1c | Massenware, UBmass = 0 → **1s 20c** |
| F16 | ERL | STAPEL × VP × (1 − ANTEIL) | 20 × 1s 20c = 24s; minus 5 % (1s 20c) → **22s 80c** |
| F17 | Händlerwert | STAPEL × HP | 20 × 5c = **1s** |
| F18 | EG | Grundgebühr = STAPEL × HP × 5 %, **abgerundet** auf ganze Kupfer; EG = Grundgebühr × 1 (2 Std.) / 4 (8 Std.) / 12 (24 Std.) – so rechnet das Spiel | 20 × 5c × 5 % = 5c, × 4 = **20c** (kommt bei Verkauf zurück); Wollstoff 11 × 33c × 5 % = 18,15c → 18c, × 4 = **72c** |
| F19 | MP | kleinster VP, bei dem ERL > Händlerwert: VP > HP ÷ (1 − ANTEIL), aufgerundet auf ganze Kupfer | 5c ÷ 0,95 = 5,26c → **6c** |
| F20 | EMPF | „AH“, wenn ERL > Händlerwert, sonst „Händler“ (bei Gleichstand Händler – weniger Aufwand) | 22s 80c > 1s → **AH** |

**Variante mit Dumping:** Das günstigste Angebot läge bei 1s statt 1s 20c. Dann gilt 1s < 1s 12c, also DUMP. Basis = Mitte zwischen 1s 12c und 1s 60c = **1s 36c**, VP = 1s 36c (UBmass = 0), ERL = 20 × 1s 36c × 0,95 = **25s 84c**.

**Gegenbeispiel Schwerer Leinenverband** (18 Stück, HP = 20c, AHmin = AHmedian = 20c, Massenware): VP = 20c, ERL = 18 × 20c × 0,95 = 3s 42c, Händlerwert = 3s 60c → **Händler**. MP = 20c ÷ 0,95 = 21,05c → 22c: erst ab 22c je Stück würde sich das Auktionshaus lohnen.

### 2.5 Noch zu prüfen (mit echten Daten, nicht zu entscheiden)

- ~~Rundung der Einstellgebühr~~ – **geklärt (30.09.2026):** Das Spiel rechnet erst die Grundgebühr für 2 Std. (5 % vom Händlerwert des Stapels, abgerundet) und nimmt sie mal 4 (8 Std.) bzw. mal 12 (24 Std.). Belegt durch den automatischen Abgleich im Spiel (`depositCheck`, 17 von 17 Beispielen, u. a. 25c × 1 → 4c statt 5c, 2c × 18 → 4c statt 7c). Umgesetzt in Broker 0.6.2. Gemessen nur mit 8 Std.; 2 und 24 Std. sind daraus abgeleitet.
- Erlös = Gesamtpreis minus 5 %: im Spiel bestätigt (Wollstoff 11 × 2s 35c = 25s 85c, × 0,95 = 24s 55,75c → Broker 24s 56c). **Rechnung bestätigt (30.09.2026):** Verkaufspreis 25s 85c, Auktionshausgebühr 1s 29c (= 5 % von 25s 85c = 1s 29,25c), erhaltener Betrag 25s 56c. ANTEIL = 5 % stimmt. Die Einzahlung kommt zusätzlich zurück: laut Rechnung **1s 0c**, eingezahlt wurden aber nur 72c. Grund unklar (vielleicht Aufrunden auf volle Silber) – bei weiteren Verkäufen beobachten. Für Broker ohne Belang, die Einzahlung zählt nicht als Kosten.
- Ob die Formel auch für 2 und 24 Std. stimmt (bisher nur 8 Std. gemessen) – zeigt der automatische Abgleich, sobald eine andere Laufzeit eingestellt ist.

## 3. Anzeige im Tooltip

Ausgangspunkt ist der Tooltip von Broker 0.5.1, umgestellt auf die Begriffe aus Kapitel 1 und 2. Beispiel: Kupfererz, 20 Stück in der Tasche (Werte aus Kapitel 2).

**Ohne Umschalt** – nur Zeile 1:

```
Broker (Umschalt)                         AH: 22s 80c ↗
```

**Mit Umschalt** – alle Zeilen:

```
Broker                                    AH: 22s 80c ↗
Angebote: 120 (4) ↘                     (Scan vor 5 Min.)
AH (je Stück)            Min 1s 20c ↘     Median 1s 60c ▬
7 Tage (4)               Min 1s 25c ▬     Median 1s 58c ↗
Vorschlag                                 1s 20c je Stück
Einstellgebühr (8 Std.)                   20c
Händler                                   1s
Wenig Angebote.                           (Hinweise, orange)
```

### 3.1 Zeilen

| Zeile | Links | Rechts | Werte | Wann |
|---|---|---|---|---|
| Z1 | „Broker“, ohne Umschalt mit grauem Hinweis „(Umschalt)“ | „AH: ERL“ in Grün mit TREND(ERL) (ab 0.21: ERL zum günstigsten Angebot, Farbe nach Marktlage – F41, Kapitel 7.4) – oder „Händler: Händlerwert“ in Weiß | F16, F17, F20; ganzer Stapel | immer, wenn es Daten gibt |
| Z2 | „Angebote: AHmenge (AHanz)“ mit TREND(AHmenge) | „(Scan vor …)“ in Grau | F3, F4, ZEIT | Umschalt |
| Z3 | „AH“ | „Min AHmin“ mit TREND, „Median AHmedian“ mit TREND – **je Stück** | F2, F5 | Umschalt |
| Z4 | „7 Tage (Anzahl Tage)“ | „Min W7min“, „Median W7median“, je mit TREND gegenüber Vortag – **je Stück** | F8, F9 | Umschalt, ab 2 Tageswerten; abschaltbar |
| Z5 | „Vorschlag“ | VP „je Stück“ | F14, F15 | Umschalt |
| Z6 | „Einstellgebühr (LZ)“ | EG für den Stapel | F18 | Umschalt |
| Z7 | „Händler“ | Händlerwert | F17 | Umschalt, nur wenn Z1 „AH“ zeigt; abschaltbar |
| Z8+ | Hinweise in Orange, je eine Zeile | – | siehe 3.2 | Umschalt; abschaltbar |

Z1, Z6 und Z7 gelten für den ganzen Stapel, Z3 bis Z5 je Stück (vergleichbar mit „Preis/Einheit“ im Auktionshausfenster). Geldbeträge mit Münzsymbolen, Nullwerte weggelassen. Trend-Symbole wie in Broker 0.5 (dunkelgrün ↑, hellgrün ↗, blauer Balken, orange ↘, rot ↓).

### 3.2 Hinweise

| Hinweis | Bedingung |
|---|---|
| „Dumping: günstigstes Angebot weit unter dem Median – Vorschlag angepasst.“ | DUMP |
| „Wenig Angebote.“ | AHanz < 3 |
| „Zurzeit keine Angebote (zuletzt gesehen vor …).“ | Gegenstand fehlte im letzten Scan des Markts; Z3 zeigt dann die zuletzt gesehenen Werte in Grau |
| „Preisdaten älter als 3 Tage.“ | ZEIT älter als 3 Tage |

### 3.3 Sonderfälle

| Fall | Anzeige |
|---|---|
| Im Markt wurde noch nie gescannt | Nur bei verkaufbaren Gegenständen (HP > 0): „Broker: noch kein Scan für diesen Markt“ in Grau |
| Gegenstand nie im Auktionshaus gesehen | nichts |
| Stapelgröße unbekannt (Link im Chat, Auktionshaus-Liste) | Werte für 1 Stück |

### 3.4 Entfällt gegenüber 0.5.1

- Abverkauf je Stunde (Zeile 2) und die Einstellung dazu.
- „Ø“ (Durchschnitt der günstigsten 25 %) – ersetzt durch „Median“.
- „~“ vor dem Erlös – die Einstellgebühr wird berechnet und nicht mehr vom Erlös abgezogen.

## 4. Verkaufen mit Live-Daten (Broker 0.8.0, abgestimmt 30.09.2026)

Grundlage: `Peon_Broker_Verkaufen.md`. Beim Verkaufen fragt Broker die aktuellen Angebote für genau diesen Gegenstand ab und rechnet damit statt mit dem letzten Scan.

### 4.1 Neue Begriffe

| Variable | Name | Beschreibung | Quelle |
|---|---|---|---|
| LIVE | Live-Angebote | Preisstufen (Preis je Stück, Menge, davon eigene) aus der Verkaufs-Suche | Spiel beim Verkaufen |
| AHmin_live | Live-Minimum | günstigstes Angebot **anderer** Verkäufer | F21 |
| AHmedian_live | Live-Median | Median nach Menge über alle Live-Angebote (eigene eingeschlossen) | F22 |
| EIGENmin | eigenes Minimum | günstigstes eigenes Angebot | LIVE |
| VIEL | viele Angebote | ab so vielen Angeboten gilt Massenware als „viel Umsatz“ (Standard 20, 5–100) | Einstellung |
| LZ_kurz | kurze Laufzeit | Massenware mit vielen Angeboten auf 2 Std. (Standard an) | Einstellung |
| MENGE | Menge | Stück (Massenware) bzw. Anzahl Auktionen (Einzelgegenstände); Standard alles in den Taschen | Eingabe |

### 4.2 Formeln

| Nr. | Ergebnis | Formel | Beispiel Kupfererz (live 8@1s15, 40@1s20, 50@1s50, 20@1s60) |
|---|---|---|---|
| F21 | AHmin_live | kleinster Preis mit Menge anderer Verkäufer > 0 | **1s 15c** |
| F22 | AHmedian_live | Median nach Menge wie F3 | 118 Stück → Stück 59/60 → **1s 50c** |
| F23 | VP_live | wenn EIGENmin ≤ AHmin_live: VP = EIGENmin (nicht selbst unterbieten); sonst F12–F15 mit AHmin_live und AHmedian_live | keine eigenen, kein Dumping, UBmass 0 → **1s 15c** |
| F23a | Eintragspreis (ab 0.20, Wunsch von KarloDerBaer 02.10.2026) | eigenes Angebot am günstigsten: dessen Preis; sonst AHmin_live (bzw. AHmin aus dem Scan) minus UB/UBmass – **auch bei Dumping**; liegt das unter MP (F19): MP mit Hinweis „Lieber beim Händler verkaufen“. VP (F23) bleibt Richtwert: liegt der Eintragspreis darunter, Hinweis „Unter dem Vorschlag VP (n % weniger)“ (rot ab F27). Rückfrage nur, wenn von Hand noch tiefer als der Eintragspreis und F27 zutrifft | Dumping-Beispiel: 5 Stück zu 1s, Rest zu 3s → eingetragen 1s, Vorschlag höher |
| F24 | VP ohne Live-Daten | 1. letzter Scan (F12–F15 mit AHmin/AHmedian); 2. nur Händlerpreis bekannt: MP (F19); 3. sonst kein Vorschlag | 7c Händler → 7 ÷ 0,95 = 7,37 → **8c** |
| F25 | LZ beim Verkaufen | von Hand gewählt (je Gegenstand gemerkt) → diese; sonst Massenware und LZ_kurz an und Angebote ≥ VIEL → 2 Std.; sonst LZ (Standard 8 Std.) | 4 Angebote < 20 → **8 Std.** |
| F26 | EG beim Verkaufen | Wert des Spiels für MENGE und LZ (Rückfall F18) | 60 × 5c: 15c × 4 = **60c** |
| F27 | Warnung „zu niedrig“ | Preis von Hand < VP × (1 − DG) → rote Warnung und Rückfrage beim Einstellen | 50c < 1s 15c × 0,7 → **Warnung** |

**Teil-Ergebnisse (ab 0.20):** Liefert das Spiel nur einen Teil der Angebote (`HasFull…SearchResults` = nein), stimmen AHmin_live und die günstigsten Stufen, AHmedian_live und Menge aber nicht. Dann gilt für F22 der Median aus der Datenbank (falls höher), und die Live-Abfrage schreibt nur Minimum und Stufen in den aktuellen Stand (Kapitel 6).

Erlös, Händlerwert und Empfehlung wie F16, F17, F20, mit MENGE statt STAPEL. Der Preis wird nicht gemerkt, nur angezeigt („Zuletzt eingestellt zu …“).

## 5. Einkaufen und Schnäppchen (Broker 0.13.0, abgestimmt 30.09.2026)

Grundlage: `Peon_Broker_Einkaufen.md`.

### 5.1 Neue Begriffe

| Variable | Name | Beschreibung | Quelle |
|---|---|---|---|
| LV | Preisstufen | die 12 günstigsten Preisstufen (Preis je Stück, Menge) aus Scan oder Live-Abfrage (bis 0.16: 5) | Scan, live |
| RAB | Rabatt der Liste | x % unter dem Median, je Einkaufsliste | Einstellung |
| WUNSCH | Wunschmenge | optional je Gegenstand einer Liste | Eingabe |
| VORRAT | Vorrat | Taschen + Bank | Spiel |
| GEW_H | Mindestgewinn Händler | Standard 10c | Einstellung |
| GEW_M | Mindestgewinn Markt | Standard 50s | Einstellung |
| SCANS_MIN, TAGE | Datenlage | mindestens 10 Scans in den letzten 7 Tagen | Einstellung |
| MARGE | Mindestmarge Markt | Wiederverkauf je Stück mindestens so viel über dem Kaufpreis; Standard 20 % (ab 0.17) | Einstellung |
| TIEFE | Höchstmenge Markt | höchstens so viel % aller aktuellen Angebote; Standard 20 % (ab 0.17) | Einstellung |
| ALTER_MAX | Höchstalter der Treffer beim Öffnen des Radars | ab 0.15: Standard 60 Minuten, 0 = unbegrenzt; gemessen ab ZEIT_GES (Kapitel 6) | Einstellung |

### 5.2 Formeln

| Nr. | Ergebnis | Formel |
|---|---|---|
| F28 | REF_kauf | W7median, wenn mindestens 2 Tageswerte; sonst AHmedian |
| F29 | Höchstpreis | REF_kauf × (1 − RAB), abgerundet |
| F30 | Treffer | Angebote anderer Verkäufer mit Preis ≤ Höchstpreis; Kaufmenge = Summe, höchstens WUNSCH − VORRAT (ohne WUNSCH: alle Treffer) |
| F31 | Händler-Schnäppchen | Stufen mit Preis < HP; Gewinn = Σ (HP − Preis) × Menge; anzeigen ab GEW_H |
| F32 | REF_markt | kleinerer Wert aus W7median und AHmedian |
| F33 | Markt-Schnäppchen (ab 0.17, mit KarloDerBaer abgestimmt) | nur wenn das günstigste Angebot < REF_markt × (1 − DG). Für jede Kaufmenge k (günstigste Stück zuerst, höchstens TIEFE × alle Angebote): **Wiederverkauf W_k = Preis des nächsten Angebots nach dem Kauf**, höchstens REF_markt (nichts mehr im Angebot: REF_markt; nur gespeicherte Stufen und weitere unbekannt: Preis der letzten gekauften Stufe); gültig, wenn W_k × 0,95 ≥ teuerstes gekauftes Stück × (1 + MARGE); Gewinn_k = W_k × 0,95 × k − Kosten_k. Genommen wird die Menge mit dem höchsten Gewinn; anzeigen ab GEW_M. **Ab 0.26 (KarloDerBaer 03.10.2026):** REF_markt für den Wiederverkauf höchstens Untergrenze des üblichen Bereichs (F39 `low`), ohne Bereich höchstens REF_markt × (1 − DG/2); Kaufmenge zusätzlich höchstens Absatz je Std. × HALTE (`dealHold`, 48 Std.), nur bei Absatz ab gelbem ≈; Absatz 0 → kein Markt-Schnäppchen. Bis 0.16: Gewinn = Σ (REF_markt × 0,95 − Preis) × Menge |
| F33b | Gewinn bei Teilkauf (ab 0.18) | Kauf der n günstigsten Stück: Händler = HP × n − Kosten_n; Markt = min(REF_markt, nächstes Angebot nach diesen n Stück) × 0,95 × n − Kosten_n (liegt der Rest der Stufe noch im Angebot, ist das nächste Angebot derselbe Preis → Verlust). „Gewinn erst ab n Stück“ = kleinstes n mit Gewinn > 0. Beispiel Echtsilberbarren: 9 × 1g 20s 33c, dann 1g 74s 33c → Gewinn erst ab 9 Stück |
| F33a | Gewinn je Stück / je Stapel (ab 0.17) | je Stück = Gewinn ÷ Menge (Durchschnitt); je Stapel (nur Massenware) = Erlös je Stück × s − Kosten der s günstigsten Stück, s = min(Stapelgröße, Menge). Sortierung und „bestes“ Angebot nach Gewinn je Stück |
| F34 | Datenlage und Aktualität | Markt: Anzahl Scans in den letzten TAGE Tagen ≥ SCANS_MIN; beide Arten: Daten höchstens ALTER_MAX alt (bis 0.14: letzter Scan höchstens 5 Min.) |

Beim Anklicken werden F30, F31 und F33 mit den Live-Angeboten (ohne eigene) neu gerechnet.

Beispiel F33 (KarloDerBaer, „Abgefangene Kiste“, 30.09.2026): 2 × 50s, 1 × 55s, 25 × 57s, 2 × 60s, 22 × 64s, 9 × 65s, … 36 × 69s 65c, 1 × 69s 69c, 3 × 99s 99c, 28 × 1g 20s, 19 × 1g 24s 98c, 120 × 1g 26s (273 Stück, Median 1g 24s 98c). Bis 0.16: 103 Stück „Schnäppchen“, 56g Gewinn gegen den Median. Ab 0.17 mit TIEFE 20 % (höchstens 54 Stück) erreicht keine Menge die MARGE (nach 64s folgt 65s) → **kein Schnäppchen**. Ohne Höchstmenge wären es 103 Stück bis 69s 69c mit Wiederverkauf gegen 99s 99c.

## 6. Live-Daten im aktuellen Stand (Broker 0.15.0, abgestimmt 30.09.2026)

Jede Live-Abfrage (Radar, Einkaufsliste, Verkaufen, Meine Auktionen) liefert für **einen** Gegenstand alle aktuellen Angebote – so vollständig wie ein Scan. Sie schreibt deshalb den **aktuellen Stand** des Gegenstands, aber nicht den Verlauf.

| Wert | aus Live-Abfrage? | Grund |
|---|---|---|
| AHmin, AHmed, AHmenge (F2–F5), günstigste 5 Preisstufen | **ja**, überschrieben | aktueller als der letzte Scan |
| „weg“ (keine Angebote) | **ja** (wie beim Scan; letzte Preise bleiben) | weggefallene Schnäppchen kommen nicht wieder |
| AHanz | nur wenn bisher unbekannt, bei „weg“ 0 | die Live-Abfrage fasst gleiche Preise zusammen |
| ZEIT_LIVE (neu) | Zeit der letzten Live-Abfrage mit Angeboten | |
| ZEIT (Scan-Zeit), Vorwerte für den Trend (F6) | **nein** | Trend vergleicht Scan mit Scan |
| Tageswerte, Wochenwerte, Anzahl Scans (F7, F34) | **nein** | sonst wäre die Datenlage wertlos (ein oft geprüfter Gegenstand hätte nach Minuten „10 Scans“) und die Tageswerte ungleich gewichtet |

- **ZEIT_GES** (zuletzt gesehen) = der spätere Wert aus ZEIT und ZEIT_LIVE. Grundlage für „Stand“ im Reiter Preise, „zuletzt gesehen“ und „Preisdaten älter als 3 Tage“ im Tooltip sowie für ALTER_MAX im Radar.
- Nächster voller Scan: fehlt ein Gegenstand, der beim vorherigen Scan **oder** seitdem live gesehen wurde, wird er „weg“.
- Ausrüstung mit Zusatz (Schlüssel „ID:Zusatz“) schreibt nur, wo die Live-Abfrage nach dem Zusatz trennt (Radar, Einkaufsliste).

## 7. Richtwert und üblicher Bereich (abgestimmt 02.10.2026, Broker 0.21.0)

**Ziel:** Ein Vorschlag, der bei stark schwankenden Preisen ruhig bleibt, einzelne Ausreißer (nach oben wie nach unten) übergeht, einem echten neuen Preisniveau aber folgt. Vorbild sind Verfahren von der Börse: ein gleitender Mittelwert, bei dem neuere Tage stärker zählen, und ein Schwankungsband um ihn herum (ähnlich den Bollinger-Bändern), beides mit robusten Maßen (Median statt Durchschnitt), damit Mondpreise nichts verzerren.

**Was sich ändert:** Nur der Vorschlag (VP) und die Dumping-Erkennung. Eingetragen wird beim Verkaufen weiter das günstigste Angebot (F23a); der Vorschlag ist der Richtwert für Hinweis, Tooltip (Zeile 1) und Erlös-Schätzung.

### 7.1 Neue Begriffe

| Variable | Name | Beschreibung | Quelle |
|---|---|---|---|
| TAGE14 | Tageswerte | TAGmedian der letzten 14 Tage (heute eingeschlossen, Tage ohne Scan übersprungen). Nur Scan-Werte (Kapitel 6). | Formel (bei Anzeige) |
| MITTE | Mitte der Tage | Median der TAGE14 – unempfindlich gegen einzelne verrückte Tage. | F35 |
| SCHW | Schwankung | Wie stark die Tagespreise üblicherweise um MITTE streuen, in Prozent von MITTE. Robustes Maß (MAD): mittlere Abweichung, mal 1,4826, damit es einer normalen Standardabweichung entspricht. Mindestens 5 %. | F36 |
| LANG | gleitender Mittelwert | Mittel der TAGE14, neuere Tage zählen stärker (Gewicht halbiert sich alle 3 Tage); Tageswerte außerhalb MITTE ± 3 × SCHW werden vorher auf diese Grenze gekürzt. | F37 |
| HEUTE | heutiger Tageswert | TAGmedian von heute, nur ab 3 Scans heute. | F7 |
| JETZT, VOR | aktueller und vorheriger Median | AHmedian des letzten Scans (bzw. der letzten vollständigen Live-Abfrage) und AHmedian_vor. | F5, F6 |
| TREND_M | Marktlage | „fällt“ / „steigt“, wenn JETZT **und** VOR beide unter bzw. über dem Bereich um BASIS liegen (zwei Messungen bestätigen ein neues Niveau); sonst „ruhig“. | F38 |
| RW | Richtwert | ruhig: BASIS = Median aus JETZT, HEUTE, LANG (ohne HEUTE: Mittel aus JETZT und LANG). fällt/steigt: JETZT. | F38 |
| UNTEN, OBEN | üblicher Bereich | RW × (1 − SCHW) bis RW × (1 + SCHW). | F39 |

Voraussetzung: mindestens 3 Tageswerte. Sonst gilt das bisherige Verfahren (F12–F15).

### 7.2 Formeln

| Nr. | Ergebnis | Formel |
|---|---|---|
| F35 | MITTE | Median der TAGE14 |
| F36 | SCHW | 1,4826 × Median(\|TAGmedian − MITTE\|) ÷ MITTE, mindestens 5 % |
| F37 | LANG | Σ (Gewicht × gekürzter Tageswert) ÷ Σ Gewicht; Gewicht = 0,5 ^ (Alter in Tagen ÷ 3); gekürzt auf MITTE × (1 ± 3 × SCHW) |
| F38 | BASIS, TREND_M, RW | BASIS = Median(JETZT, HEUTE, LANG). Liegen JETZT und VOR beide unter BASIS × (1 − SCHW): fällt; beide über BASIS × (1 + SCHW): steigt. RW = BASIS (ruhig) bzw. JETZT (fällt/steigt) |
| F39 | UNTEN, OBEN | RW × (1 ∓ SCHW), auf ganze Kupfer abgerundet |
| F40 | Vorschlag (ersetzt F13–F14, wenn F35–F39 möglich) | AHmin ≥ UNTEN: Basis = AHmin (normal unterbieten). AHmin < UNTEN und Markt fällt: Basis = AHmin (nicht gegen den Markt stellen, Hinweis „Preis fällt“). AHmin < UNTEN und Markt ruhig/steigt: **Dumping**, Basis = UNTEN. Dann wie F15 (minus Unterbieten), mindestens MP (F19). |

Warum der Median aus drei Werten: Ein einzelner Ausreißer – ein verrückter Scan jetzt, ein verrückter Tag heute oder eine veraltete Vergangenheit – wird überstimmt, solange die anderen beiden zusammenpassen. Warum zwei Scans für „fällt/steigt“: Ein einzelner Scan kann Zufall sein; zwei hintereinander (15 Min. auseinander) zeigen ein neues Preisniveau, dem der Vorschlag dann folgt, statt auf alte Preise zu warten.

### 7.3 Beispiele mit echten Daten (Markt Classic Beta PvE / Alliance, 02.10.2026, je Stück)

Tageswerte = TAGmedian der letzten drei Tage (30.09. / 01.10. / 02.10.).

| Gegenstand | Tageswerte | JETZT / VOR | AHmin | BASIS | Marktlage | RW | Bereich | Vorschlag neu | bisher (F13–F15) |
|---|---|---|---|---|---|---|---|---|---|
| Wollstoff | 2s 83c / 2s 69c / 1s 07c | 80c / 78c | 68c | 1s 07c | fällt | 80c | 74c – 86c | 68c, „Preis fällt“ | 68c |
| Leinenstoff | 1s 10c / 99c / 79c | 89c / 59c | 30c | 89c | ruhig | 89c | 74c – 1s 03c | **74c**, Dumping | 75c, Dumping |
| Seidenstoff | 17s 01c / 16s 26c / 11s 36c | 8s 25c / 8s 30c | 7s 04c | 11s 36c | fällt | 8s 25c | 7s 68c – 8s 81c | 7s 04c, „Preis fällt“ | 7s 04c |
| Runenstoffballen | 27s 09c / 22s 67c / 1g 53s 19c | 39s / 39s | 37s | 39s | ruhig | 39s | 29s 55c – 48s 44c | 37s | 37s |
| Efeustoffschärpe der Intelligenz | 64s 79c / 42s 92c / 72s 84c | 15s / 22s | 15s | 60s 95c | fällt | 15s | 12s 23c – 17s 76c | 15s, „Preis fällt“ | 15s |
| Silberblatt | 17c / 44c / 18c | 13c / 14c | 10c | 18c | fällt | 13c | 12c – 13c | 10c, „Preis fällt“ | 10c |

Was man sieht: Bei Runenstoffballen übergeht der Median aus drei den verrückten heutigen Tageswert (1g 53s). Bei der Efeustoffschärpe würde ein reiner Mittelwert der Tage (61s) einen Preis vorschlagen, zu dem nichts verkauft wird – zwei Scans zeigen das neue Niveau (15s/22s), der Vorschlag folgt. Bei Leinenstoff erkennt das Band Dumping ähnlich wie bisher, aber begründet mit dem üblichen Bereich statt einer festen 30-%-Grenze. Mit nur drei Tagen Daten (Beta) sind die Unterschiede noch klein; je mehr Tage, desto mehr bringt LANG.

### 7.4 Anzeige

- **Verkaufen:** Hinweis „Üblich: 74c – 1s 03c (3 Tage)“ und ggf. „Preis fällt“ / „Preis steigt“ / „Unter dem üblichen Bereich (Dumping)“ / „Über dem üblichen Bereich – guter Zeitpunkt“. Der Hinweis „Unter dem Vorschlag …“ bleibt.
- **Tooltip** (mit Umschalt): neue Zeile „Üblich (n Tage)  UNTEN – OBEN“ mit „fällt“/„steigt“, unter der Zeile „7 Tage“. Hinweise „Preis fällt …“ (orange) bzw. „Dumping: … unter dem üblichen Bereich“.
- **Zeile 1 im Tooltip und Wert im Reiter Verkaufen (F41, Wunsch von KarloDerBaer 02.10.2026):** zeigt nicht mehr den Erlös zum Vorschlag, sondern zum **günstigsten Angebot minus Unterbieten** (so wird eingestellt, F23a): ERL = (AHmin − UB) × STAPEL × (1 − ANTEIL); Trend gegenüber (AHmin_vor − UB). Farbe = Marktlage: **grün** guter Preis, **orange** Markt fällt (TREND_M = fällt), **rot** Dumping (F40). Zahlt der Händler mindestens so viel, steht wie bisher „Händler: …“.
- **Preise-Reiter:** RW und Bereich bei den Einzelheiten.

### 7.5 Entschieden (KarloDerBaer, 02.10.2026)

1. Fenster 14 Tage, Halbwertszeit 3 Tage.
2. Breite des Bereichs fest 1 × SCHW (nicht einstellbar).
3. Die Dumping-Grenze (30 %, F13–F14) bleibt nur als Rückfall bei weniger als 3 Tageswerten.
4. Radar: Markt-Schnäppchen gegen RW statt F32; Dumping = günstigstes Angebot unter UNTEN und Markt fällt nicht; fällt der Markt, gibt es keine Markt-Schnäppchen (F33 sonst unverändert, REF_markt = RW).
5. Zeile 1 im Tooltip: günstigstes Angebot mit Farbe der Marktlage (F41, siehe 7.4).

## 8. Langzeit-Teil vom Peon Client (abgestimmt 23.10.2026, Peon Client 0.3.0, Broker 0.31.0)

**Ziel:** Broker bekommt den Langzeit-Teil des üblichen Bereichs (F35 bis F37) vom Peon Client. Der Client hat mehr und bessere Tageswerte: alle eigenen Scans, auch über Lücken in Brokers Aufbewahrung hinweg, dazu den Broker-Verlauf, später weitere Quellen. Den Jetzt-Teil (F38 bis F40: JETZT, VOR, HEUTE, Marktlage, Richtwert, Vorschlag) rechnet Broker weiter live im Spiel, damit der Richtwert auf fallende oder steigende Preise sofort reagiert. Die Werte des Clients kommen nur beim Reload oder Login ins Spiel.

### 8.1 Begriffe

| Variable | Name | Beschreibung | Quelle |
|---|---|---|---|
| TAGc | Tageswert im Client | Mittel der Mediane aller eigenen Komplettscans eines Tages (wie TAGmedian, F7). Gibt es an einem Tag keinen eigenen Scan, gilt der Broker-Verlauf dieses Tages (TAGmedian aus `PeonBrokerDB`). Live-Abfragen zählen nicht (wie Kapitel 6). Tag wie Broker (lokale Mittagszeit). | Client |
| TAGE14c | Tageswerte | TAGc der letzten 14 Tage bis zum Tag der Auswertung (eingeschlossen), Tage ohne Wert übersprungen, mindestens 3. | Client |
| MITTEc, SCHWc, LANGc | Langzeit-Teil | wie F35, F36, F37, aber aus TAGE14c; Alter für LANGc gerechnet vom Tag der Auswertung. | F42 |
| TAGEc | Zahl der Tage | Anzahl TAGE14c | F42 |
| STANDc | Stand | Zeitpunkt der Auswertung im Client | Data.lua |
| FRISCH | Frische-Grenze | Werte des Clients gelten bis 7 Tage nach STANDc (einstellbar in Peon_Client, 1 bis 30). | Einstellung |

### 8.2 Formeln

| Nr. | Ergebnis | Formel |
|---|---|---|
| F42 | MITTEc, SCHWc, LANGc | wie F35 bis F37 mit TAGE14c; SCHWc mindestens 5 %; nur bei mindestens 3 Tagen |
| F43 | Langzeit-Teil in Broker | Liegen Werte des Clients für den Gegenstand vor und ist jetzt höchstens FRISCH nach STANDc, nimmt Broker MITTE = MITTEc, SCHW = SCHWc, LANG = LANGc, Tage = TAGEc. Sonst rechnet Broker F35 bis F37 selbst (bisher). |
| F44 | Rest | HEUTE weiter aus Brokers eigenen Tageswerten (ab 3 Scans heute). F38 bis F41 unverändert mit diesen Werten. |

### 8.3 Datei

`AddOns\Peon_Client\Data.lua`: `PeonClientData.markets[Markt] = { t = STANDc, day = Tag der Auswertung, items = { [Schlüssel] = "MITTEc:SCHWc:LANGc:TAGEc:Quelle" } }`. MITTEc und LANGc in Kupfer (gerundet), SCHWc in Zehntausendsteln (500 = 5 %), Quelle `e` (nur eigene Scans), `b` (nur Broker-Verlauf), `eb` (beides). Schlüssel wie in Broker. Nur Gegenstände mit mindestens 3 Tagen.

### 8.4 Anzeige

- Tooltip mit Umschalt, Verkaufen, Preise: „Üblich (Client, n Tage)“ statt „Üblich (n Tage)“, wenn der Langzeit-Teil vom Client kommt.
- Im Client: Gegenstand zeigt „Üblicher Bereich für Broker“ (MITTEc, SCHWc, LANGc, Tage).

### 8.5 Entschieden (KarloDerBaer, 23.10.2026)

1. Der Client liefert nur den Langzeit-Teil, Broker rechnet den Jetzt-Teil live (statt eines fertigen, bis zum Reload eingefrorenen Richtwerts).
2. Zeitraum 14 Tage, Halbwertszeit 3 Tage wie Kapitel 7.
3. Absatz je Tag kommt erst mit C6 vom Client; bis dahin misst Broker ihn selbst.

## 9. Absatz und Chancen im Peon Client (Entwurf 23.10.2026, Peon Client 0.4.0, Peon_Client 0.3.0, Broker 0.32.0)

**Ziel:** Der Client misst den Absatz selbst, aus allen Angeboten zweier aufeinanderfolgender Komplettscans (Broker merkt sich je Gegenstand nur die günstigsten 15). Er gibt ihn an Broker zurück und baut daraus die Ansicht „Chancen“. Sobald die Blizzard-API Auktionsnummern liefert, ersetzen genaue Vergleiche die Schätzung (gleiche Regeln wie Live-Abfragen). Entschieden von KarloDerBaer am 23.10.2026: Client rechnet und gibt an Broker, Händlerpreis kommt von Peon_Client, alle vier Reiter.

### 9.1 Begriffe

| Variable | Name | Beschreibung | Quelle |
|---|---|---|---|
| A, B | Vergleichspaar | zwei aufeinanderfolgende Komplettscans desselben Markts, Abstand 1 Min. bis 24 Std. (wie Broker). Live-Abfragen desselben Gegenstands mit Auktionsnummern nur für Zeiten, die kein Scan-Paar abdeckt. | Client |
| ANG | Angebot | Preis je Stück, Menge, frühestes und spätestes Ende aus der Restzeit-Stufe (1 bis 30 Min., 2 bis 2 Std., 3 bis 12 Std., 4 bis 48 Std.) | Scan |
| WARE | Warenart | Massenware oder Einzelgegenstand: von Broker (Peon_Client liefert es mit), sonst aus Brokers `commodity`, sonst stapelbar laut Spiel, sonst Massenware, sobald ein Angebot mehr als 1 Stück hatte. Gegenstände mit Zusatz sind Einzelgegenstände. | Peon_Client, Broker |
| HP | Händlerpreis | vom Spiel, über Peon_Client mit dem Namen geliefert | Peon_Client |
| TAGEA | Zeitraum Absatz | letzte 14 Tage | fest |

### 9.2 Absatz (Formeln)

| Nr. | Ergebnis | Formel |
|---|---|---|
| F45 | Vergleich eines Paars | genau wie Broker (`Sales.lua`, Konzept Absatz Abschnitt 3 und 7), aber mit allen Angeboten: gleiches Angebot (Preis und Menge) = steht noch; Massenware gleicher Preis, weniger Menge = Teilkauf (verkauft); weg und Ende sicher vorbei = abgelaufen; weg und Ende sicher nicht erreicht: Massenware abgebrochen, wenn ein günstigeres Angebot in beiden stand oder gleiche Menge billiger neu eingestellt wurde, sonst verkauft; Einzelgegenstand verkauft abzüglich 10 % Abbrüche; Ende unklar = nicht gezählt. Neu eingestellt = Angebote nur in B. |
| F46 | Absatz je Tag | Summe verkauft ÷ Summe beobachtete Zeit × 24 Std. über TAGEA. Beobachtet zählt jedes Paar, in dem der Gegenstand in A oder B vorkommt. Einzelne Vergleiche werden nach 2 Tagen zu Tageswerten zusammengefasst (Platz), Tageswerte bleiben ein Jahr. |
| F47 | Absatzquote | verkauft ÷ (verkauft + abgelaufen) über TAGEA |
| F48 | Sicherheit | nach beobachteter Zeit wie Broker: unter 60 Min. rot, ab 60 gelb, ab 180 grün |
| F49 | Absatz in Broker | Hat Broker in den letzten 6 Std. weniger als 60 Min. selbst beobachtet (rot oder gar nichts) und sind die Werte des Clients frisch (F43), nimmt Broker Absatz je Std. = F46 ÷ 24, Quote F47 und Sicherheit F48 vom Client. Sonst bleibt Brokers eigener Wert. Anzeige „Absatz (Client, 14 Tage)“. |

### 9.3 Chancen (Formeln)

Grundlage: der übliche Bereich des Clients (F42) mit UNTEN = LANGc × (1 − SCHWc) und OBEN = LANGc × (1 + SCHWc), Gebühr 5 % (F11). Zeitraum der Reiter: letzte 7 Tage (einstellbar 1 bis 14).

| Nr. | Reiter | Formel |
|---|---|---|
| F50 | Wiederverkauf | Je Scan die Angebote mit 0,95 × UNTEN − Preis ≥ 20 % des Preises (Abstand wie Broker `dealMargin`). Je Gegenstand: Treffer = Scans mit solchen Angeboten ÷ alle Scans im Zeitraum, Stück je Scan (Mittel über alle Scans), Gewinn je Stück (Mittel), **Gewinn je Tag = min(Absatz je Tag, Stück je Scan) × Gewinn je Stück**, beste Tageszeit (3-Stunden-Abschnitt mit den meisten Treffern). Verkauft wird zur Untergrenze wie Broker F40. **Zweifelhaft** (kein Gewinn je Tag), wenn in 14 Tagen nie zu mindestens 80 % der Untergrenze verkauft wurde (schützt vor Scherzpreisen, die den Bereich hochziehen). |
| F51 | Händler-Schnäppchen | Je Scan die Angebote mit Preis < HP. Gewinn je Stück = HP − Preis (keine Gebühr beim Händler). Treffer, Stück je Scan, Gewinn je Tag = Stück je Scan × Gewinn je Stück, beste Tageszeit. |
| F52 | Fallend, Steigend | JETZT = Median im letzten Scan. Änderung = JETZT ÷ LANGc − 1. Steigend: JETZT > OBEN und Änderung ≥ +15 %. Fallend: JETZT < UNTEN und Änderung ≤ −15 %. Dumping: Min im letzten Scan < 70 % von LANGc (wie Broker `dumpPct`). Nur ab 1 Silber Median und 3 Stück (wie die Übersicht) und SCHWc höchstens 50 % (sonst kein verlässlicher Bereich). Dazu die Tageswerte der letzten 14 Tage als kleine Linie. |
| F53 | Lohnend | Umsatz je Tag = Absatz je Tag × LANGc. Spanne je Tag = Absatz je Tag × (0,95 × OBEN − UNTEN), nur wenn positiv. Sortiert nach Spanne je Tag. Nur mit mindestens gelber Sicherheit (F48) und wenn in 14 Tagen mindestens einmal zu 80 % der Untergrenze verkauft wurde. Umsatz mit dem mittleren Verkaufspreis. |

Filter in allen Reitern: Mindestgewinn je Tag (Standard 10 Silber), Qualität ab, Suche. Klick öffnet den Gegenstand.

### 9.4 Datei

`PeonClientData.markets[Markt].sales = { [Schlüssel] = "ABSATZ:QUOTE:MINUTEN" }`: ABSATZ = Stück je Tag × 10 (gerundet), QUOTE in Prozent (−1 = unbekannt), MINUTEN = beobachtete Zeit. Nur Gegenstände mit mindestens einem Vergleich. Getrennt von `items`, damit ältere Versionen von Peon_Client die Datei weiter lesen.

Peon_Client hängt an jeden neuen Namen Händlerpreis und Warenart an: `names[itemID] = "Name|Qualität|Händlerpreis|Massenware"` (Händlerpreis leer = unbekannt, Massenware 1/0/leer). Einmalig nach dem Update werden alle Namen neu geschickt.

## 10. Bessere Vorschläge (KarloDerBaer 08.11.2026, Manager 0.21.0, Broker 0.38.0)

**Anlass:** Magicusmantel, Preis in 3 Tagen von etwa 4g auf 1g 20s gefallen, seit einem Tag dort, 12 Angebote dicht beieinander (Min 1g 20s, Median 1g 24s). Der Manager meldete „68 % unter dem üblichen Preis“. Gründe: Die Kürzung (F37) schnitt den neuen Tageswert ab, weil die Schwankung bei zwei gleichen Tagen nur 5 % betrug. Der Manager prüfte den Trend nicht (Broker hat ihn mit F38). Der Abstand zu den anderen Angeboten zählte nicht.

| Nr. | Ergebnis | Formel |
|---|---|---|
| F37a | Kürzung | Wie F37, aber unten gekürzt auf MITTE × (1 − 3 × max(SCHW, 25 %)), höchstens bis 0. Oben bleibt MITTE × (1 + 3 × SCHW). Gilt in Broker (D.Band) und Manager (F42). |
| F50a | Wiederverkauf | Verkaufsziel = min(UNTEN, Median der Angebote im selben Scan). Nicht bei neuem Preisniveau nach unten (F54). |
| F54 | Neues Preisniveau (nur Manager) | Stände der letzten 24 Std. (mindestens 3, erster und letzter mindestens 12 Std. auseinander). Alle Mediane unter UNTEN: fällt. Alle über OBEN: steigt. Niveau = Median dieser Mediane. Die Gegenstandsseite vergleicht dann mit dem Niveau statt mit LANGc. |
| F55 | Trefferquote (nur Manager) | Wiederverkaufs-Treffer von vor 3 bis 17 Tagen, je Gegenstand der erste des Tages. Höchster Median der Angebote in den 3 Tagen danach: mindestens Verkaufsziel = Treffer, mindestens Kaufpreis ÷ 0,95 = ohne Verlust, sonst daneben. Ohne Stand danach nicht gezählt. |

Gegenstandsseite: grün („Schnäppchen“) nur, wenn das günstigste Angebot mindestens 5 % unter dem Vergleichspreis und mindestens 20 % unter dem Median der aktuellen Angebote liegt. Bei nur einem Stück zählt der Abstand nicht.

## Offene Fragen

- Keine. Kapitel 1–7 sind abgestimmt (Kapitel 7 am 02.10.2026, umgesetzt in Broker 0.21.0).
- Kapitel 9 und 10: Schwellen (20 % Abstand, 15 % Bewegung, 80 % Nachweis, 10 Silber Mindestgewinn, 25 % Kürzung, 12 Std. für ein neues Niveau) in 2 bis 4 Wochen mit der Trefferquote (F55) prüfen, wenn der Markt nach dem Start ruhiger ist.

## Entschieden (30.09.2026)

- Trend: Scan-Werte gegenüber dem vorherigen Scan; 7-Tage-Werte gegenüber dem 7-Tage-Wert vom Vortag (gleitend, heute eingeschlossen).
- Empfehlung vorerst ohne Verlustrisiko der Einstellgebühr.
- Blizzard-API: vorerst weiter mit Scans im Spiel; eine geplante Aufgabe prüft täglich, ob Blizzard Forever-Daten veröffentlicht. Ein Zusatzprogramm auf dem PC kommt für KarloDerBaer grundsätzlich in Frage.
- Tagesgrenze: Mitternacht nach der Uhr des PCs.
- 7-Tage-Werte: Tage ohne Scan überspringen, anzeigen ab 2 Tageswerten mit Anzahl der Tage.
- Median bei gerader Stückzahl: Mittel der beiden mittleren Stück-Preise.
- Dumping: Basis ist die Mitte zwischen Dumping-Grenze und Median (REF × (1 − DG ÷ 2)), davon wird noch unterboten.
- Gleichstand Erlös = Händlerwert: Empfehlung Händler.
- Tooltip (Kapitel 3): AH- und 7-Tage-Preise je Stück, Zeile 1/Einstellgebühr/Händler für den Stapel; neue Zeilen „Vorschlag“ und „Einstellgebühr“; „Wenig Angebote“ ab weniger als 3 Angeboten; kein Hinweis „Lohnt sich erst ab …“.
