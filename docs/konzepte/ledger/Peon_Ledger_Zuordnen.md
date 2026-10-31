# Peon_Ledger – Zuordnen (Kosten, Lagerwert und Handelsgewinn)

Stand: 03.10.2026, **abgestimmt mit KarloDerBaer** (Entscheidungen in Abschnitt 8), **umgesetzt in Ledger 0.7.0 / Broker 0.25.0**. Ergänzt `Peon_Ledger_Konzept.md`, Abschnitt 9 Punkt 8.

## 1. Worum es geht

Bisher zeigt Ledger Einnahmen und Ausgaben **je Zeitraum**. Kauf und Verkauf desselben Gegenstands werden nicht miteinander verrechnet. Wer diese Woche 20 Erz für 1g kauft und nächste Woche für 1,5g verkauft, sieht einmal −1g und einmal +1,5g, aber nicht „+0,5g Gewinn mit Erz“.

Zuordnen heißt: Jeder Zugang bekommt seine **Kosten** (was ein Stück gekostet hat). Bei jedem Abgang werden die Kosten der abgegebenen Stücke abgezogen, **die ältesten zuerst**. So entsteht ein echter **Gewinn oder Verlust je Verkauf** und je Gegenstand, egal wann gekauft wurde. Gesammelte und gekaufte Ware bleiben dabei getrennt.

## 2. Begriffe (Anzeige im Spiel)

| Begriff | Bedeutung | Buchhaltung |
|---|---|---|
| **Posten** | ein Zugang mit Stückzahl, Kosten je Stück und Datum, z. B. „20 Erz zu je 5s, gekauft am 01.10.“ (nur intern) | Lagerposten |
| **Kosten** | was ein Stück gekostet hat (gekauft oder hergestellt) | Anschaffungs- oder Herstellungskosten, Einstandspreis |
| **Lagerwert** | Summe der Kosten aller Stücke, die noch da sind | Bestandswert |
| **Wareneinsatz** | Kosten der verkauften Stücke | Wareneinsatz |
| **Handelsgewinn** | Erlös − Wareneinsatz − Gebühren | Rohgewinn |
| **Verbrauch** | Kosten benutzter oder zerstörter Stücke (nur zur Information) | – |

Reihenfolge: **älteste zuerst** (Buchhaltung: „First in, first out“, FIFO).

## 3. Was Ledger dafür schon hat

Alle nötigen Daten werden seit 0.3/0.6 erfasst:

| Bewegung | vorhanden |
|---|---|
| Auktion gekauft | Gold, Gegenstand, Menge (seit 0.6 in einer Zeile) |
| Händler gekauft / Rückkauf | Gold und Gegenstand in einer Zeile (seit 0.6 auch mehrere Stapel) |
| Hergestellt | Ergebnis (+) und Material (−) mit Rezeptname, zeitlich zusammen |
| Auktion verkauft | Erlös, Menge, Anteil, Sofortkaufpreis aus der Rechnung |
| Händler verkauft | Gold und Gegenstand |
| Einstellgebühr, Abbruchkosten | Gold, Zeitpunkt (Gegenstand bisher nicht dabei) |
| Beute, Quest, Post, Handel, Sonstiges | Gegenstand und Menge, kein Preis |
| Anfangsbestand (Inventur) | Gegenstand und Menge, kein Preis |

## 4. Wie gerechnet wird

**Zugänge** legen einen Posten an (hinten in der Reihe):

| Zugang | Kosten je Stück |
|---|---|
| Auktion gekauft, Händler gekauft, Rückkauf | bezahlter Preis ÷ Menge |
| Hergestellt | Kosten des verbrauchten Materials (älteste zuerst) ÷ hergestellte Menge |
| Beute, Quest, Sonstiger Zugang | 0 (kostenlos erhalten) |
| Post von fremden Spielern und von Absendern ohne Nachname (NPCs, Systempost) | 0 |
| Post mit Nachnahme | bezahlter Betrag ÷ Menge |
| Post von eigenen Twinks | Umbuchung, Posten bleiben (accountweit) |
| Handel ohne Gegenleistung | 0 |
| Handel mit Gegenleistung (Gold und/oder Gegenstände gegeben) | Gegenwert = gegebenes Gold + Kosten der gegebenen Gegenstände, verteilt auf die erhaltenen nach Marktwert |
| Anfangsbestand (Inventur, „Buch zurücksetzen“, „Inventur neu“) | Marktpreis beim Start (Zeile 1 des Broker-Tooltips), ohne Broker-Preis Händlerpreis |

**Abgänge** nehmen Stücke aus den **ältesten Posten zuerst**:

| Abgang | Wirkung |
|---|---|
| Auktion verkauft, Händler verkauft | Handelsgewinn = Erlös − Wareneinsatz − Gebühren des Gegenstands |
| Material verbraucht | Kosten gehen ins Hergestellte |
| Benutzt, Zerstört, Verbraucht/sonstiges | „Verbrauch“: Kosten als eigene Zeile im Buch (zur Info), zählt nicht gegen den Handelsgewinn |
| Auktion eingestellt / zurück, Taschen ↔ Bank | Umbuchung, Posten bleiben |
| Post an Twink | Umbuchung, Posten bleiben (accountweit) |
| Post an fremde Spieler, Handel gegeben | wie Verbrauch (Handel mit Gegenleistung: Kosten gehen in den Gegenwert des Erhaltenen) |

**Beispiel:** 10 Friedensblumen gesammelt (0), dann 10 im Auktionshaus zu 2s gekauft. Für 5 Heiltränke (je 2 Blumen + 1 Phiole zu 20c) werden die 10 gesammelten verbraucht → Kosten je Trank 20c. Im Lager bleiben 10 Blumen zu 2s (Lagerwert 20s). Ein Trank, für 6s verkauft (−5 % Anteil), bringt 5s 70c − 20c = 5s 50c Handelsgewinn.

**Gebühren:** Einstellgebühren und Abbruchkosten werden dem Gegenstand der Auktion zugerechnet (Zeitpunkt „Auktion eingestellt“ bzw. Abbruch). Die Einzahlung kommt beim Verkauf zurück; verlorene Gebühren (abgelaufen, abgebrochen) bleiben als „offene Gebühr“ beim Gegenstand und mindern den Gewinn des nächsten Verkaufs.

**Speichern (umgesetzt):** Die Posten werden durch Nachspielen von Anfangsbestand und Verlauf berechnet und zwischengespeichert (neu bei jeder Bewegung). Bevor Einträge nach 90 Tagen zu Wochensummen werden, wird ihr Stand in `realms[Realm].lotBase = { untilT, lots[itemID] = { { t, n, c }, … }, fee }` übernommen. Marktwerte des Anfangsbestands werden beim ersten Rechnen eingefroren (`start.v[itemID]`).
- Zugänge derselben Art am selben Tag zum gleichen Preis werden zu einem Posten zusammengefasst (wie Beute heute).
- Höchstens **30 Posten** je Gegenstand; darüber werden die ältesten zu einem Posten mit ihren Durchschnittskosten zusammengelegt.
- Geschätzte Größe: üblich ~40 KB, viel ~500 KB (zum Vergleich Broker heute 1,9 MB). Gerechnet wird nur bei einem Zu- oder Abgang und nur für diesen Gegenstand.
- Knopf „Neu berechnen“ baut die Posten aus dem Verlauf neu auf (soweit noch Einzeleinträge da sind).

## 5. Anzeige

- **Tooltip (ohne Umschalt, kompakt):** „Ledger  Kosten 2s (Ø 1s 50c)“ – Kosten des nächsten Stücks, das abgeht, und Durchschnitt des ganzen Bestands (nur wenn verschieden). Der Bestand („Bestand: 25 (Mirel 20, Borin 5)“ und die Orte je Charakter) steht unter Umschalt.
- **Gegenstände:** neue Spalten „Kosten“ (je Stück, Durchschnitt des Bestands) und „Gewinn“ (Handelsgewinn im Zeitraum, grün/rot).
- **Bestand und Übersicht:** „Lagerwert“ (Kosten der vorhandenen Stücke) neben dem Marktwert (Vermögen).
- **Buch:** Zeilen „Wareneinsatz“, „Handelsgewinn“ (Auktionshaus und Händler) und „Verbrauch“ (Info), getrennt vom übrigen Gewinn (Beute, Quests …).
- **Verlauf:** Bei Verkäufen steht im Tooltip „Wareneinsatz X · Gewinn Y“.
- **Broker (später, nur lesend):** Hinweis beim Verkaufen „unter deinen Kosten“.

## 6. Grenzen

- Was vor dem Anfangsbestand bzw. vor „Buch zurücksetzen“ war, kennt Ledger nicht. Diese Stücke bekommen den Marktpreis beim Start.
- Kostenlos Erhaltenes (Kosten 0): Der Gewinn beim Verkauf ist der volle Erlös (nach Gebühren).
- Gewinn je Verkauf kann schwanken: Gleiche Stücke zum gleichen Preis zeigen je nach Posten unterschiedlichen Gewinn; über die Zeit gleicht sich das aus.
- Wird ein Abgang einmal nicht erfasst, ist die Reihe verschoben, bis der Bestand einmal leer war. Abhilfe: „Inventur neu“ bzw. „Neu berechnen“.
- Post von Absendern ohne Nachname: Forever-Spieler haben Vor- und Nachnamen; fehlt der Nachname, gilt der Absender als NPC/System.
- Hergestelltes mit mehreren Ergebnissen (selten): Das Material wird gleichmäßig verteilt.
- Abgänge ohne passende Posten: Kosten 0, Hinweis „ohne Kosten“.

## 7. Bauabschnitte

1. **Z1 – Posten und Kosten:** Posten anlegen und verbrauchen (älteste zuerst), Zusammenfassen und Obergrenze, „Neu berechnen“ aus dem Verlauf, Test mit nachgebauten Bewegungen (u. a. das Beispiel aus Abschnitt 4).
2. **Z2 – Anzeige:** Tooltip, Spalten im Reiter Gegenstände, Lagerwert, Wareneinsatz/Handelsgewinn/Verbrauch im Buch, Verlauf.
3. **Z3 – Broker:** Kosten als Schnittstelle (`mod:Cost(itemID)` → nächstes, Ø), Hinweis beim Verkaufen.

## 8. Entscheidungen (KarloDerBaer, 03.10.2026)

1. **Kostenlos Erhaltenes = 0:** Beute, Quests, Post von fremden Spielern und von Absendern ohne Nachname (NPCs, Systempost), Handel ohne Gegenleistung. Handel mit Gegenleistung bekommt den Gegenwert (gegebenes Gold, Kosten gegebener Gegenstände). Nachnahme-Post: bezahlter Betrag.
2. **Anfangsbestand:** Marktpreis beim Start (Broker), sonst Händlerpreis.
3. **Älteste zuerst** (FIFO) statt Durchschnitt – gesammelte und gekaufte Ware bleiben getrennt. Höchstens 30 Posten je Gegenstand, gleiche Zugänge am selben Tag zusammengefasst. Tooltip zeigt Kosten des nächsten Stücks und den Durchschnitt.
4. **Accountweit** je Realm; Post an/von Twinks ändert nichts.
5. **Gebühren** (Einstellgebühr, Abbruchkosten) werden dem Gegenstand zugerechnet.
6. **Benutzt/Zerstört** = „Verbrauch“ als eigene Info-Zeile im Buch, kein Verlust im Handelsgewinn.
7. **Begriffe:** „Kosten“ (statt „Einstand“), „Lagerwert“, „Wareneinsatz“, „Handelsgewinn“, „Verbrauch“.
8. **Tooltip:** Kosten ohne Umschalt, kompakt „Kosten x (Ø y)“; die Stückzahlen (Bestand) unter Umschalt.
