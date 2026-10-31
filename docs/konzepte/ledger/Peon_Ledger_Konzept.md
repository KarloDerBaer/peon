# Peon_Ledger – Konzept

Stand: 02.10.2026, **abgestimmt mit KarloDerBaer** (Fragen in Abschnitt 11 entschieden). Ersetzt das Konzept `Peon_Broker_Buch.md` (dessen Entscheidungen gelten weiter, siehe Abschnitt 10).

## 1. Worum es geht

Peon_Ledger ist das neue Modul für **Bestand und Buchführung** – unabhängig vom Auktionshaus:

- **Bestand aller Charaktere:** Was liegt wo – Taschen, Bank, Post, Auktionen, angelegt – und wie viel Gold hat jeder Charakter. Auch die Twinks, wie bei Taschen-Addons.
- **Ist-Zustand:** Beim ersten Start eine Inventur je Charakter (Gegenstände und Gold) als Anfangsbestand.
- **Alle Bewegungen mit Grund:** Jeder Zu- und Abgang von Gegenständen und Gold wird erfasst – Beute, Herstellen, Verbrauch, Händler, Handel, Post, Auktionshaus, Zerstören … Was sich nicht zuordnen lässt: „verbraucht/sonstiges“.
- **Post einsammeln:** Auktionshaus-Post per Knopf einsammeln, Rechnungen lesen.
- **Buch:** Einnahmen, Ausgaben, Gebühren und Gewinn je Zeitraum, je Art und je Gegenstand; Verkaufsquote.

Broker bleibt das Auktionshaus-Modul und nutzt Ledger, wenn es geladen ist (Abschnitt 8).

## 2. Grundsätze

1. **Alles erfassen, was machbar ist** – lieber „verbraucht/sonstiges“ als eine Lücke im Bestand.
2. **Nichts automatisch tun.** Ledger liest nur mit. Einzige Aktion ist „Post einsammeln“, und auch das nur per Knopf.
3. **Accountweit, je Realm getrennt** (wie Brokers Märkte): Charaktere mit Vor- und Nachname, z. B. „Mirel Dorna“.
4. **Sparsam speichern:** Beute und Verbrauch je Tag zusammengefasst, einzelne Einträge 90 Tage, danach Wochensummen.
5. **Verständlich:** Gründe in Klartext („Trank getrunken“ → „Benutzt“, „Kupferbarren hergestellt“ → „Hergestellt“).

## 3. Was das Spiel liefert (zuerst mit einem Prüfbefehl prüfen)

`/ledger pruefen` – nur lesend, schreibt ins Debug-Protokoll; bei offenem Postfach, Händler, Bank, Handels- oder Berufsfenster jeweils die passenden Teile.

| Bereich | Funktionen / Ereignisse (wie in Retail/Classic, in Forever ungeprüft) |
|---|---|
| Taschen, Bank | `C_Container.GetContainerNumSlots/GetContainerItemInfo`, Bank-Taschen nur bei offener Bank (`BANKFRAME_OPENED`), `BAG_UPDATE_DELAYED`, `PLAYERBANKSLOTS_CHANGED` |
| Angelegt | `GetInventoryItemLink("player", slot)` |
| Gold | `GetMoney()`, `PLAYER_MONEY` |
| Post | `GetInboxNumItems`, `GetInboxHeaderInfo`, `GetInboxInvoiceInfo`, `GetInboxItemLink`, `TakeInboxMoney`, `TakeInboxItem`/`AutoLootMailItem`, `SendMail` (mitlesen), `MAIL_SHOW/MAIL_INBOX_UPDATE/MAIL_CLOSED` |
| Händler | `MERCHANT_SHOW/CLOSED`, Kauf `BuyMerchantItem` (mitlesen), Verkauf über Taschen-Abgleich bei offenem Händler, Rückkauf, `RepairAllItems` |
| Handel | `TRADE_SHOW`, `GetTradePlayerItemLink/GetTradeTargetItemLink`, `GetPlayerTradeMoney/GetTargetTradeMoney`, `TRADE_CLOSED` |
| Herstellen | `TRADE_SKILL_SHOW` bzw. `CRAFT_SHOW` (Verzauberkunst in Classic), `UNIT_SPELLCAST_SUCCEEDED` (Rezept), Taschen-Abgleich: Materialien weg, Ergebnis dazu |
| Benutzen | `UNIT_SPELLCAST_SUCCEEDED` eines Gegenstands-Zaubers + Taschen-Abgleich (Trank, Essen, Verband, Schriftrolle …) |
| Beute | `LOOT_OPENED/LOOT_CLOSED`, `CHAT_MSG_LOOT`, `CHAT_MSG_MONEY` (Gold aus Beute), Sammeln (Kräuter, Erz, Angeln) |
| Quests | `QUEST_TURNED_IN` (Gold, Erfahrung), Belohnungsgegenstand über Taschen-Abgleich |
| Zerstören | `DeleteCursorItem` (mitlesen) |
| Sonstiges Gold | Flugmeister (`TakeTaxiNode`), Lehrer, Postgebühr, Reparatur |
| Auktionshaus | Einstellen (`AUCTION_HOUSE_AUCTION_CREATED`), Kaufen (`COMMODITY_PURCHASE_SUCCEEDED`, `AUCTION_HOUSE_PURCHASE_COMPLETED`), Abbrechen (`AUCTION_CANCELED`), eigene Auktionen (`OWNED_AUCTIONS_UPDATED`), Rechnungen in der Post |

## 4. Wie Bewegungen erkannt werden

Zwei Bausteine zusammen:

1. **Bestandsabgleich:** Ledger kennt den Bestand jedes Ortes. Ändert sich etwas (z. B. Taschen nach `BAG_UPDATE_DELAYED`, Gold nach `PLAYER_MONEY`), ergibt der Vergleich alt/neu genau, *was* sich geändert hat (Gegenstand, Menge, Gold).
2. **Zusammenhang:** Ledger merkt sich, *was gerade passiert* – welches Fenster offen ist (Händler, Post, Bank, Handel, Auktionshaus, Beruf), welcher Zauber gerade erfolgreich war, welche Beute angezeigt wurde. Die Änderung bekommt den passenden Grund; passt keiner: „verbraucht/sonstiges“.

Umbuchungen sind keine Zu- oder Abgänge: Taschen ↔ Bank, Post an eigene Twinks (Abgang beim einen, Zugang beim anderen – im Buch als „Umbuchung“), Auktion eingestellt (Taschen → Auktionen) und zurück.

### Umsetzung: nur ereignisgesteuert (Wunsch KarloDerBaer)

Es gibt **keinen regelmäßigen Scan** und keine Schleife, die ständig läuft. Ledger reagiert nur auf Meldungen des Spiels:

| Meldung des Spiels | Was Ledger tut |
|---|---|
| `BAG_UPDATE` (Tasche n) | merkt sich nur „Tasche n hat sich geändert“ |
| `BAG_UPDATE_DELAYED` (einmal nach einer Reihe von Änderungen) | liest **nur die geänderten Taschen** neu (je ca. 16–20 Plätze) und vergleicht mit dem gemerkten Stand |
| `PLAYER_MONEY` | Gold neu lesen, Unterschied = Gold-Bewegung |
| `PLAYER_EQUIPMENT_CHANGED` (Platz) | nur diesen Ausrüstungsplatz neu lesen |
| Bank-, Post-, Auktions-Meldungen | nur solange das jeweilige Fenster offen ist, nur der betroffene Teil |
| Händler, Handel, Beute, Beruf, Zauber, Quest … öffnen/schließen | nur „was passiert gerade“ merken (ein paar Werte), nichts lesen |

- **Aufwand:** Ein Abgleich nach einer Änderung liest höchstens ein paar Dutzend Taschenplätze – das dauert weit unter einer Millisekunde, also nicht spürbar. Komplett gelesen wird nur beim Einloggen (Taschen, ca. 100 Plätze) und beim ersten Öffnen von Bank/Post/Auktionshaus.
- **Reihenfolge:** Manche Meldungen kommen in unterschiedlicher Reihenfolge (z. B. Gold vom Händler vor der Taschen-Änderung). Ledger hält deshalb „was gerade passiert ist“ ein paar Sekunden fest und ordnet die Änderung dem passenden Ereignis zu.
- **Kampf:** Im Kampf (z. B. Trank) merkt Ledger sich nur, welche Gegenstands-Zauber gewirkt wurden und welche Taschen sich geändert haben; ausgewertet wird direkt nach dem Kampf. So stört Ledger im Kampf nicht und umgeht die geheimen Werte von Forever.
- **Speichern:** Geschrieben wird nur bei einer Änderung; Beute und Verbrauch werden je Tag zusammengefasst.

### Arten von Bewegungen

| Zugang | Abgang | Umbuchung |
|---|---|---|
| Beute, Sammeln, Angeln | Benutzt (Trank, Essen …) | Taschen ↔ Bank |
| Quest-Belohnung | Quest-Abgabe | Post an/von eigenen Twinks |
| Händler gekauft | An Händler verkauft | Auktion eingestellt / zurück (abgelaufen, abgebrochen) |
| Auktion gekauft | Auktion verkauft | |
| Hergestellt (Ergebnis) | Hergestellt (Materialien) | |
| Handel erhalten | Handel gegeben | |
| Post von anderen | Post an andere | |
| | Zerstört | |
| *Inventur (Anfangsbestand)* | *verbraucht/sonstiges* | |

Gold genauso: Beute, Quest, Händler, Reparatur, Flugmeister, Lehrer, Auktionshaus (Verkaufserlös, Einstellgebühr, Anteil, Abbruchkosten, Kauf), Handel, Post, sonstiges.

## 5. Ist-Zustand (Inventur) und Twinks

- Beim **ersten Einloggen** eines Charakters mit Ledger: Taschen, angelegte Ausrüstung und Gold sofort; **Bank** beim ersten Öffnen der Bank, **Post** beim ersten Öffnen des Postfachs, **Auktionen** beim ersten Öffnen des Auktionshauses. Bis dahin steht dort „noch nicht erfasst“.
- Diese Inventur ist der **Anfangsbestand** im Buch (eigene Art, kein Gewinn).
- **Twinks:** Ledger kennt einen Charakter, sobald er einmal eingeloggt war; danach bleibt sein letzter Stand gespeichert und wird beim nächsten Einloggen weitergeführt. Was ein Twink in der Zwischenzeit nicht tun kann, ändert sich auch nicht – mit einer Ausnahme: Post, die an ihn geht, verbucht Ledger schon beim Absender als „unterwegs“.
- Knopf „Inventur neu“ je Charakter (falls etwas nicht stimmt): setzt den Bestand auf den aktuellen Stand, Unterschied als „Korrektur“ im Buch.

## 6. Post einsammeln

Wie im Broker-Konzept entschieden: **nur Auktionshaus-Post, nur per Knopf**, nie Nachnahme. Knopf am Postfach „Ledger: Post einsammeln (12 · 3g 40s)“, Brief für Brief, Stopp bei vollen Taschen/geschlossenem Postfach/Kampf, Fortschritt im Knopf. Vor dem Holen wird jede Rechnung gelesen (Verkaufspreis, Anteil, Einzahlung zurück, Menge) und ins Buch geschrieben.

## 7. Anzeige

**Ledger-Fenster** (`/ledger`, Minimap-Button) im Stil des Broker-Fensters, Reiter unten:

| Reiter | Inhalt |
|---|---|
| Übersicht | Gold je Charakter und gesamt; Vermögen = Gold + Wert der Gegenstände (Preise von Broker, wenn geladen); Gewinn heute / 7 Tage / 30 Tage |
| Bestand | Suche über alle Charaktere: Gegenstand → wo (Charakter, Taschen/Bank/Post/Auktionen/angelegt) und wie viele; Wert |
| Buch | Zeitraum (Heute, 7 Tage, 30 Tage, Alles) und Charakter (alle/einzeln); Summen Einnahmen, Ausgaben, Gebühren, Gewinn; aufgeteilt nach Art (Auktionshaus, Händler, Beute, Quests, Herstellen, Reparatur, Reisen …) |
| Gegenstände | je Gegenstand: Zugänge, Abgänge, verkauft, abgelaufen, **Verkaufsquote**, Ø Verkaufspreis, Einnahmen, Ausgaben |
| Verlauf | alle Bewegungen zeitlich, Filter nach Art, Charakter, Gegenstand |

**Tooltip:** eine Zeile „Bestand: 25 (Mirel 20, Borin 5)“; mit Umschalt aufgeteilt nach Ort („Bank 15, Taschen 5“).

## 8. Zusammenspiel mit Broker

Nur in eine Richtung und abgesichert (`if Peon.GetModule("ledger") then …`), beide Module laufen auch allein:

- Broker fragt Ledger: **Vorrat über alle Charaktere** (Reiter Behalten, Einkaufslisten: Wunschmenge minus Vorrat aller Charaktere) und **Verkaufsquote** (Tooltip, Verkaufen).
- Ledger fragt Broker (ebenfalls nur lesend, wenn geladen): **Preis eines Gegenstands** für das Vermögen.
- Brokers bisherige Listen `posted`, `cancelled`, `bought` werden beim ersten Start einmal ins Buch übernommen; danach erfasst Ledger diese Ereignisse selbst.
- Brokers gesperrter Reiter „Buch“ entfällt; Ledger öffnet man über seinen eigenen Minimap-Button oder `/ledger`.

## 9. Bauabschnitte

1. **L1 – Prüfbefehl** `/ledger pruefen` (nur lesend): welche Funktionen/Ereignisse Forever hat (Post, Händler, Handel, Beruf, Bank). – **umgesetzt in Ledger 0.1.0** (02.10.2026), Auswertung im Spiel steht aus.
2. **L2 – Bestand:** Inventur, Bestand aller Charaktere (Taschen, Bank, Post, Auktionen, angelegt, Gold), Tooltip-Zeile, Reiter „Bestand“ und „Übersicht“ (Gold). – **umgesetzt in Ledger 0.2.0** (02.10.2026).
3. **L3 – Bewegungen:** Abgleich + Zusammenhang, alle Arten aus Abschnitt 4, Gold; Reiter „Verlauf“. – **umgesetzt in Ledger 0.3.0** (03.10.2026).
4. ~~**L4 – Post einsammeln** und Auktionshaus-Rechnungen.~~ – **entfällt** (KarloDerBaer 03.10.2026): „Alle öffnen“ wird vollständig erfasst, Rechnungen werden beim Holen gelesen (0.3.1).
5. **L5 – Buch:** Reiter „Buch“ und „Gegenstände“, Verkaufsquote. – **umgesetzt in Ledger 0.4.0** (03.10.2026); Übernahme der Broker-Listen entfällt (siehe Entscheidungen 03.10.2026).
6. **L6 – Zusammenspiel mit Broker** (Vorrat aller Charaktere, Verkaufsquote, Preise fürs Vermögen) → **Broker 1.0 / Ledger 1.0**. – **umgesetzt in Ledger 0.5.0 / Broker 0.22.0** (03.10.2026): Vorrat aller Charaktere nur im Reiter „Behalten“ mit Umschalter (Einkaufslisten unverändert), Verkaufsquote im Broker-Tooltip; Absatzquote des Marktes folgt als eigener Broker-Schritt.
7. **Rest aus Abschnitt 5 und 7** (Gewinn heute/7/30 Tage, Wert im Bestand, Ø Verkaufspreis, Filter nach Art, „Inventur neu“ mit Korrektur, Ausrüstung im Vermögen) – **umgesetzt in Ledger 0.6.0** (03.10.2026); „Inventur neu“ nur für den eingeloggten Charakter.
8. **Zuordnen** – Konzept `Peon_Ledger_Zuordnen.md` (abgestimmt 03.10.2026, Kosten nach „älteste zuerst“). **Später ursprünglich:** Einstand und echter Handelsgewinn („Zuordnen“, älteste Käufe zuerst; hergestellte Gegenstände mit Materialkosten).

## 10. Übernommene Entscheidungen (aus `Peon_Broker_Buch.md`, KarloDerBaer 02.10.2026)

- Post einsammeln: nur Auktionshaus-Post, nur per Knopf.
- Alles erfassen, was machbar ist – auch Herstellen und Verbrauch; Rest „verbraucht/sonstiges“.
- Einzelne Einträge 90 Tage, danach Wochensummen.
- Gewinn zuerst je Zeitraum, „Zuordnen“ später – die Daten dafür werden von Anfang an erfasst.
- Ist-Zustand und Twinks (charakterübergreifend).
- Eigenes Modul **Peon_Ledger** mit Bestand und Buch; Broker liest nur, nur wenn geladen.

## 11. Entschieden (KarloDerBaer, 02.10.2026)

1. Brokers Reiter „Buch“ **entfällt**; Ledger hat einen **eigenen Minimap-Button**.
2. Angelegte Ausrüstung zählt zum Bestand (eigener Ort; im Vermögen nur auf Wunsch).
3. Vermögen mit dem Wert aus Zeile 1 des Broker-Tooltips: günstigstes Angebot bzw. Händlerpreis – was man in diesem Moment höchstens bekäme (Stand letzter Scan).
4. Tooltip: immer die kurze Zeile, Aufteilung nach Ort mit Umschalt.
5. Gold aus Beute je Tag und Charakter zusammengefasst.
6. Erfassung nur ereignisgesteuert, kein regelmäßiger Scan (Abschnitt 4).
