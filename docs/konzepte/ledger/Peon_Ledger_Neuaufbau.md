# Peon_Ledger: Konzept Neuaufbau

Stand: 12.11.2026, **von KarloDerBaer freigegeben** (Abschnitt 10), **gebaut in Ledger 0.14.0 und Broker 0.84.0** (alle Bauabschnitte E1 bis E7), Prüfung im Spiel steht aus. Ausgangsversion Ledger 0.13.1. Baut auf `Peon_Ledger_Konzept.md` und `Peon_Ledger_Zuordnen.md` auf. Vorbild ist der Neuaufbau von Broker (`docs/konzepte/broker/Peon_Broker_Neuaufbau.md`).

## 1. Ausgangslage

Wünsche von KarloDerBaer (12.11.2026):

1. Umstellung auf die neue Peon-Oberfläche (`Peon.UI`, `docs/konzepte/Peon_UI_Design.md`).
2. Reiter Gegenstände und Gegenstand entfernen.
3. Deutlich übersichtlicher, nur die wesentlichen Angaben.
4. Datenerfassung prüfen. Gefühl: Es wird nicht alles richtig erfasst.
5. Zusätzlich zu den Durchschnittskosten den **zuletzt gezahlten Preis** je Gegenstand kennen.
6. Den Briefkasten genauer erfassen, eventuell das Postfach um eigene Angaben ergänzen.

Heute hat Ledger sieben Reiter: Übersicht, Bestand, Verlauf, Buch, Umsatz, Gegenstände (WIP), Gegenstand (WIP). Das Fenster ist ein eigener Rahmen (760 × 500) im alten Look.

## 2. Grundsätze

1. **Richtig vor schön.** Zuerst die Erfassung prüfen und reparieren, dann die Anzeige. Eine schöne Seite mit falschen Zahlen hilft nicht.
2. **Fehler sichtbar machen.** Ledger rechnet selbst nach und zeigt, wenn Gold oder Bestand nicht aufgehen (Abschnitt 3.4). Der Spieler muss nicht nachrechnen.
3. **Erfassen an der Quelle.** Was das Spiel direkt sagt (Kauf mit Menge und Preis, Rechnung im Brief), wird direkt gespeichert. Raten aus Taschen-Änderungen nur dort, wo es nicht anders geht.
4. **Eine Frage je Seite**, höchstens sechs Spalten, wie in Broker.
5. **Alles zu einem Gegenstand steht in Broker** auf der Seite Gegenstand (Block „Mein Bestand“ mit Daten aus Ledger). Ledger zeigt keine eigene Gegenstandsseite mehr.
6. **Nichts automatisch.** Ledger liest mit. Aktionen nur per Klick des Spielers.

## 3. Prüfung der Datenerfassung

### 3.1 Wie geprüft wurde

Ausgewertet wurden die echten Ledger-Daten des Hauptcharakters von KarloDerBaer (05.11. bis 12.11.2026, 3.145 Bewegungen). Gerechnet wurde: Anfangsbestand plus alle Bewegungen, verglichen mit dem Stand, den Ledger zuletzt im Spiel gesehen hat. Dazu der Code von `Moves.lua`, `Inventory.lua` und `Cost.lua`.

### 3.2 Befunde

Das Gefühl stimmt. Es gibt mehrere echte Lücken:

| Nr. | Befund | Größe | Ursache |
|---|---|---|---|
| B1 | **Gold geht nicht auf.** Anfangsgold plus alle Bewegungen ergibt rund −2,3g, tatsächlich hat der Charakter rund 7,5g. | rund 9,9g fehlen | Mehrere Gründe möglich: Der Anfangsbestand hat 0 Gold (verdächtig, vermutlich zu früh gelesen), beim Einloggen werden Änderungen absichtlich nicht verbucht, einzelne Goldänderungen fallen in Ruhezeiten. Muss im Spiel nachgestellt werden. |
| B2 | **Verkäufe im Auktionshaus haben zwei Hälften, die selten zusammenfinden.** Das Gold kommt aus der Rechnung im Brief. Dass die Ware weg ist, sieht Ledger nur, wenn das Auktionshaus offen ist und die eigene Auktionsliste den Verkauf noch zeigt. | Beispiel Flitzdistel: laut Rechnungen 532 Stück verkauft, als Warenabgang erfasst 145 | Bestand „Auktionen“ bleibt zu hoch, bis man wieder am Auktionshaus war. Die Kosten rechnet Ledger zwar über einen Umweg richtig, der Bestand und die Verkaufsquote aber nicht. |
| B3 | **Käufe im Auktionshaus ohne Ware.** Das Gold beim Kauf wird verbucht, die Ware aus dem Brief findet oft nicht zum Kauf zurück. | 20 Kaufzeilen ohne angekommene Ware, 9 Warenzeilen ohne Gold | Briefe werden gelesen, bevor das Spiel sie geladen hat (Betreff „Rufe Daten ab“, ohne Rechnung). Ein solcher Brief vom Auktionshaus mit Ware gilt dann als „Auktion zurück“, obwohl es ein Kauf war. |
| B4 | **Möglicherweise doppelte Kaufzeilen.** Sechs gleiche Käufe zum selben Preis in derselben Minute, zweimal 38s ohne Gegenstand in derselben Minute. | 8 Zeilen | Unklar. Kann echt sein (sechs Einzelkäufe) oder doppelt gezählt. Im Spiel nachstellen. |
| B5 | **„Sonstiges“ Gold ohne Grund.** | 23 Zeilen, darunter einmal 22,77s und viele 1 Kupfer | Ursache offen (Beute ohne passende Chatzeile, Post, Handel?). |
| B6 | **Nicht-Massenware gekauft** (z. B. Ausrüstung): Ledger kennt beim Kauf den Gegenstand nicht. | im Code | Mitgelesen wird nur der Kauf von Massenware. Der zuletzt gekaufte Massenartikel bleibt 120 Sekunden „gemerkt“ und kann einem anderen Kauf zugeordnet werden. |
| B7 | **Zeitfenster überschneiden sich.** Kauf kurz nach dem Einstellen kann als Einstellgebühr gelten und umgekehrt. Ein Gegenstand, den man an einen Brief hängt, verlässt die Tasche vor dem Absenden und kann als „Benutzt“ oder „Sonstiges“ gelten. | im Code | Zuordnung über „was passierte in den letzten 6 bis 15 Sekunden“. |

Gut funktioniert nach den Daten: Händler (Kauf, Verkauf, Reparatur), Beute, Quests, Herstellen, Flugmeister, Lehrer, Rechnungen von Verkäufen (Erlös, Menge, Anteil).

### 3.3 Vorschlag: Auktionshaus und Post an der Quelle erfassen

| Vorgang | heute | neu |
|---|---|---|
| **Kauf Massenware** | Gold aus der Goldänderung, Gegenstand aus einem gemerkten Aufruf | Beim Bestätigen (`ConfirmCommoditiesPurchase`) eine Kaufzeile mit Gegenstand, Menge und Stückpreis (aus `COMMODITY_PRICE_UPDATED`). Die Goldänderung bestätigt nur noch. |
| **Kauf Einzelgegenstand** | Gegenstand unbekannt bis zum Brief | `PlaceBid(auctionID, Betrag)` mitlesen, Gegenstand aus dem gerade gezeigten Suchergebnis. |
| **Ware im Brief** | Zugang mit geratenem Grund | Keine neue Bewegung, nur Umbuchung „Post → Taschen“. Gekaufte Ware liegt bis zum Abholen als **„Post“ im Bestand**. |
| **Verkauf** | Ware weg nur bei offenem Auktionshaus, Gold aus dem Brief | Die Rechnung ist maßgeblich: Beim Lesen des Briefs eine Verkaufszeile mit Gegenstand, Menge, Brutto, Anteil, Einzahlung. Die Auktionsliste pflegt nur den Ort „Auktionen“. |
| **Briefe noch nicht geladen** | werden trotzdem eingeordnet | Briefe ohne geladenen Betreff oder ohne Rechnung werden zurückgestellt, bis `MAIL_INBOX_UPDATE` sie vollständig liefert. |
| **Post verschicken** | Abgang beim Anhängen, Grund geraten | Angehängte Gegenstände gelten bis zum Absenden als „im Briefentwurf“. Erst `SendMail` verbucht sie (an Twink oder an andere). |

Dazu ein **eigener Knopf „Post einsammeln“** im Postfenster (Abschnitt 5). Holt Ledger Brief für Brief selbst, weiß es bei jedem Betrag und jedem Gegenstand genau, aus welchem Brief er kommt. Das ist der sicherste Weg zu richtigen Zahlen. „Alle öffnen“ von Blizzard bleibt erfasst wie heute. Der Knopf war am 03.10.2026 verworfen worden und kommt nun wieder (KarloDerBaer, 12.11.2026).

### 3.4 Kontrollrechnung (neu)

Ledger rechnet bei jedem Einloggen und nach jeder Buchung nach:

- **Gold:** erwartet (letzter Stand plus verbuchte Bewegungen) gegen `GetMoney()`.
- **Bestand:** je Gegenstand erwartet gegen gelesen (Taschen, Bank, Ausrüstung, Post bei offenem Postfach).

Eine Abweichung wird als eigene Zeile „Abweichung“ verbucht (zählt nicht als Gewinn) und in der Übersicht als kleiner Hinweis gezeigt: „Erfassung: 3 Abweichungen seit 7 Tagen“. Ein Klick zeigt sie im Verlauf. So sieht man sofort, ob und wo die Erfassung hakt, und wir finden die restlichen Lücken im Alltag statt durch Nachrechnen.

### 3.5 Tests

Die Befunde B2, B3 und B7 werden als Abläufe in den Tests nachgebaut (Kauf, Brief noch nicht geladen, Brief geladen, abholen). Erst wenn die Kontrollrechnung dort aufgeht, kommt der Umbau ins Spiel.

## 4. Zuletzt gezahlter Preis

Die Kosten bleiben wie entschieden nach „älteste zuerst“ (FIFO). Sie sind richtig für den Gewinn. Zusätzlich merkt sich Ledger je Gegenstand den **letzten Kauf**:

```
last[itemID] = { t = Zeit, unit = Stückpreis, n = Menge, src = "ah" | "vendor" | "cod" | "trade", c = Charakter }
```

- Wird bei jedem Kauf überschrieben, accountweit je Realm. Klein, unabhängig vom Verlauf, bleibt auch nach 90 Tagen erhalten.
- Es zählen **alle Käufe**: Auktionshaus, Händler, Nachnahme und Handel mit Gold (KarloDerBaer). Die Quelle wird mit angezeigt. Hergestelltes und Beute zählen nicht (sonst wäre der letzte Preis oft 0).
- Genauso wird der **letzte Verkauf** gemerkt (netto je Stück nach Anteil, mit Quelle Auktionshaus oder Händler): `lastSale[itemID]`, Schnittstelle `mod:LastSale(id)`. Anzeige im Tooltip nur mit Umschalt, in Broker Gegenstand und im Buch (Nach Gegenstand).
- **Anzeige:**
  - Tooltip: `Kosten 2s 10c (Ø 1s 80c) · zuletzt 2s 40c`. „zuletzt“ nur, wenn es sich von den Kosten unterscheidet.
  - Bestand: eigene Spalte „Zuletzt“.
  - Broker Gegenstand, Block „Mein Bestand“: letzter Kauf mit Datum und Menge.
- **Schnittstelle für Broker:** neu `mod:LastBuy(id)` → Stückpreis, Zeit, Menge, Quelle. Bestehende Funktionen (`Stock`, `StockOthers`, `Cost`, `SellRate`, `VendorBuy`) bleiben unverändert.
- Weil das Buch nach dem Umbau zurückgesetzt wird (Abschnitt 9), beginnen `last` und `lastSale` leer und füllen sich mit den ersten Käufen und Verkäufen.

## 5. Briefkasten

### 5.1 Erfassen

- Je Brief: Art (Verkauf, Kauf, Zurück, Twink, Spieler, System), Gold, Anhänge, Nachnahme, **Tage bis zum Ablauf** (`GetInboxHeaderInfo` liefert sie), Rechnung.
- Nur vollständig geladene Briefe werden eingeordnet (Abschnitt 3.3).
- Je Charakter bleibt der letzte gesehene Stand des Postfachs gespeichert, mit Ablaufdatum je Brief.
- Verkäufe, die Ledger am Auktionshaus schon gesehen hat, deren Brief aber noch nicht abgeholt ist, zählen als „Erlös unterwegs“.

### 5.2 Eigenes Postfenster (Wunsch KarloDerBaer)

Statt Blizzards Postfach erscheint am Briefkasten ein eigenes Fenster **Peon Post**, gebaut nur mit `Peon.UI` (`UI.Window`, Größe wie Broker). Blizzards Postfach bleibt im Hintergrund offen, denn schließt es sich, beendet das Spiel den Kontakt zum Briefkasten.

**Blizzards Postfach im Hintergrund:** wie Peon_Bags mit Bank und Gildenbank. Blizzards Fenster wird in einen winzigen sichtbaren Rahmen umgehängt (nicht versteckt, sonst schließt sich der Briefkasten). Die bekannte Falle mit den riesig gemessenen Texten (Bags 0.6.1) gilt auch hier: Beim Zurückholen Texte und Geldanzeigen neu setzen. Lohnt sich, das als gemeinsamen Baustein in den Kern zu legen, weil Bags dasselbe tut (Kern-API wird nur erweitert).

**Aufbau:**

```
 ┌ Peon Post ─────────────────────────────────────────────────────────┐
 │ Übersicht            │ Art      Inhalt                Gold   Gewinn  Ablauf │
 │ 12 Briefe  3g 40s    │ Verkauf  Flitzdistel ×72      2g 37s  +1g 02s  29 T │
 │ Verkäufe 8  2g 95s   │ Verkauf  Maguskönigskraut ×41 1g 25s  +40s     29 T │
 │   Gewinn    1g 12s   │ Kauf     Flitzdistel ×21      Ware             30 T │
 │ Käufe 2  Zurück 2    │ Zurück   Leinenstoff ×20      Ware             30 T │
 │ Läuft bald ab 1      │ Spieler  „Ein Angebot“                          2 T │
 │                      │ ...                                                  │
 │ Filter [Alle     v]  │                                                      │
 ├──────────────────────┴──────────────────────────────────────────────────────┤
 │ [Auktionshaus-Post einsammeln (10 · 3g 40s)]  [Alles einsammeln]  12 frei │
 └Eingang─┬─Senden─────────────────────────────────────────────────────────────┘
```

Zwei Reiter unten: **Eingang** und **Senden** (Abschnitt 5.4).

- **Links** die Summen: Briefe, Gold, Verkäufe mit Erlös und Gewinn, Käufe, Zurück, was bald abläuft. Darunter ein Filter nach Art.
- **Rechts** die Briefe als Tabelle (`UI.Table`, höchstens sechs Spalten): Art, Inhalt (Gegenstand mit Menge oder Betreff), Gold, Gewinn, Ablauf. Nachnahme rot markiert. Ablauf unter 3 Tagen gelb.
- **Tooltip** eines Briefes: Absender, Brutto, Anteil, Einzahlung zurück, Kosten der Ware, Gewinn. Bei Spielerbriefen der Anfang des Textes.
- **Klick auf eine Zeile** nimmt diesen Brief direkt (Gold und Gegenstände, KarloDerBaer). Gelesen wird über den Tooltip. Nachnahme nur nach Rückfrage (`UI.Confirm`).
- **„Auktionshaus-Post einsammeln“** holt Brief für Brief, nur Briefe vom Auktionshaus. **„Alles einsammeln“** (KarloDerBaer) holt zusätzlich Briefe von Spielern, Twinks und vom System. Beide nehmen nie Nachnahme. Stopp bei vollen Taschen, geschlossenem Briefkasten oder Kampf. Fortschritt im Knopf, ein zweiter Klick hält an.
- **Statuszeile:** freie Taschenplätze, Hinweis bei mehr als 50 Briefen („50 von 63 sichtbar, nach dem Abholen kommen weitere“).
- Eine Einstellung schaltet zurück auf Blizzards Postfach (falls etwas nicht geht).

Vorher im Blizzard-Code der Forever-Version nachlesen (`Gethe/wow-ui-source`, Zweig `forever`, `Blizzard_MailFrame`): was beim Verstecken passiert, ob `TakeInboxItem`, `TakeInboxMoney` und `AutoLootMailItem` aus Addon-Code erlaubt sind (in Retail ja, Postal nutzt sie), wie schnell hintereinander man nehmen darf.

### 5.3 Post aller Charaktere

In der Übersicht eine Spalte „Post“ je Charakter: Briefe, Gold darin, nächster Ablauf. So sieht man, bei welchem Twink Post wartet oder bald verfällt.

### 5.4 Seite Senden (Wunsch KarloDerBaer)

Eigene Seite im Peon-Look statt Blizzards Seite Senden:

```
 Empfänger  [Name________] [Twinks v]      Betreff [__________________]
 Anhänge    [ ][ ][ ][ ][ ][ ][ ]           Text    [__________________]
            [ ][ ][ ][ ][ ][ ]                      [__________________]
 Gold       [   ] g [  ] s [  ] c   ( ) Senden  ( ) Nachnahme
 Kosten     30c Porto · Wert der Anhänge 4g 20s (Kosten laut Ledger)
                                                   [ Abschicken ]
```

- **Empfänger** mit Auswahlliste der eigenen Charaktere dieses Markts (Ledger kennt sie) und der zuletzt angeschriebenen Spieler.
- **Anhänge:** Gegenstand aus der Tasche auf ein Feld ziehen oder Rechtsklick in der Tasche (das Spiel hängt dann selbst an, solange die Seite Senden offen ist). Die Felder zeigen, was am Brief hängt (`GetSendMailItem`).
- **Gold oder Nachnahme** mit `UI.MoneyInput`, Umschalter wie bei Blizzard.
- **Kosten:** Porto und der Wert der Anhänge nach Ledger-Kosten. Bei Post an Twinks der Hinweis „Umbuchung, Kosten bleiben erhalten“.
- **Abschicken** nur per Klick. Danach bleibt der Empfänger stehen (mehrere Briefe an denselben Twink).
- Für die Erfassung ist das ein Gewinn: Ledger weiß beim Abschicken genau, was an wen geht (behebt B7).

Vorher im Blizzard-Code nachlesen, ob `SendMail`, `SetSendMailMoney`, `SetSendMailCOD` und `ClickSendMailItemButton` aus Addon-Code erlaubt sind (in Retail ja), und wie Blizzards Rechtsklick in der Tasche erkennt, dass Senden offen ist (`SendMailFrame:IsShown()`, bleibt im winzigen Rahmen sichtbar). Peon_Bags muss dabei mitspielen.

Die Seite Senden ist ein eigener Bauabschnitt (E7) nach dem Eingang. Bis dahin führt ein Knopf „Blizzards Senden“ zu Blizzards Seite.

## 6. Fenster und Seiten

Neues Fenster mit `UI.Window`, Größe wie Broker (800 × 538), Reiter unten mit `UI.BottomTabs`. **Vier Seiten statt sieben:**

### 6.1 Übersicht: „Wie stehe ich da?“

- Oben vier Kacheln: **Gold gesamt** (mit Änderung heute), **Vermögen** (Gold plus Marktwert der Waren), **Handelsgewinn heute** (KarloDerBaer), **Post wartet** (Briefe, Gold, nächster Ablauf).
- Darunter Tabelle Charaktere: Name, Stufe, Gold, Lagerwert, Post, zuletzt gesehen.
- Unten in der Statuszeile: Kontrollrechnung („Erfassung in Ordnung“ oder „3 Abweichungen“).

### 6.2 Bestand: „Was habe ich wo?“

- Links Suchfeld und Auswahl Charakter (alle oder einzeln), dazu die Orte als Filter (Taschen, Bank, Post, Auktionen, angelegt).
- Tabelle: Gegenstand, Menge, Wo (kurz, z. B. „Bank 15 · Taschen 5“), Kosten Ø, Zuletzt, Marktwert.
- Klick auf eine Zeile: Broker Gegenstand (wenn Broker geladen), sonst nur Tooltip.

### 6.3 Buch: „Was habe ich verdient, und wofür ging Gold weg?“

- Oben Zeitraum (Heute, 7 Tage, 30 Tage, Alles) und Charakter als Auswahlliste.
- Links die Summen: **Handelsgewinn** (Auktionshaus und Händler mit Kosten) und **Gesamtgewinn**, darunter Einnahmen und Ausgaben. Beute, Quests und Verbrauch erscheinen nur in der Ansicht „Nach Art“ (KarloDerBaer).
- Rechts mit `UI.TopTabs` zwei Ansichten:
  - **Nach Art:** Auktionshaus, Händler, Beute, Quests, Herstellen, Reparatur, Reisen, Lehrer, Post, Sonstiges.
  - **Nach Gegenstand** (ersetzt den Reiter Umsatz): Gegenstand, gekauft, verkauft, Ø Einkauf, Ø Verkauf, Gewinn.

### 6.4 Verlauf: „Was ist passiert?“

- Liste aller Bewegungen mit Filter nach Art, Charakter und Suche.
- Unsichere Zuordnungen (geschätzt, ohne Rechnung, Abweichung) sind farbig markiert.
- Vorgemerkt für später: Rechtsklick auf eine Zeile → Art ändern (z. B. „Sonstiges“ → „Post an Spieler“). Erst wenn sich nach der neuen Erfassung zeigt, wie viel noch falsch eingeordnet wird (KarloDerBaer).

### 6.5 Tooltip

Bleibt kompakt: `Kosten 2s 10c (Ø 1s 80c) · zuletzt 2s 40c`. Mit Umschalt der Bestand je Charakter und Ort wie heute.

## 7. Was wegfällt (nichts ohne Zustimmung)

| Was | Grund |
|---|---|
| Reiter **Gegenstände** (`Catalog.lua`) | Wunsch KarloDerBaer. Die Liste aller bekannten Gegenstände bietet Broker (Markt). |
| Reiter **Gegenstand** (`Item.lua`, Diagramme) | Wunsch KarloDerBaer, schon am 09.11.2026 entschieden. Ersatz: Broker Gegenstand. `mod:ShowItem(id)` bleibt und öffnet dann Broker Gegenstand. |
| Reiter **Umsatz** als eigener Reiter | wandert ins Buch (Nach Gegenstand). |
| **Alt+Klick** auf Gegenstände | schon entschieden: entfällt zugunsten des Gegenstandsmenüs (Strg+Rechtsklick). |
| Einstellungen `itemPeriod`, `itemMarge`, `itemOff`, `itemLast`, `catalogFilter` | gehören zu den entfallenden Reitern. |
| Altes Fenster (`Window.lua`, eigene Reiter-Vorlagen) | ersetzt durch `Peon.UI`. |

Bleibt: Prüfbefehl `/ledger pruefen`, Optionen, Minimap-Button und Starter, „Inventur neu“, „Buch zurücksetzen“.

## 8. Zusammenspiel mit Broker

- Broker Gegenstand, Block „Mein Bestand“: Vorrat aller Charaktere, Kosten (Ø und nächstes Stück), zuletzt gezahlt, eigene Verkäufe (Menge, Ø Erlös, Verkaufsquote).
- Broker liest weiter nur über die Schnittstelle, beide Module laufen allein.
- Broker „Händlerpreise aus drei Quellen“ nimmt künftig `mod:LastBuy(id)` mit Quelle „vendor“ statt den Verlauf zu durchsuchen.

## 9. Bauabschnitte

| Nr. | Inhalt | Modul |
|---|---|---|
| **E1** | Kontrollrechnung (Abschnitt 3.4) und Tests mit den Abläufen aus 3.2. Danach eine Woche im Alltag mitlaufen lassen. | Ledger |
| **E2** | Erfassung an der Quelle (Abschnitt 3.3): Käufe, Rechnungen, Briefe erst nach dem Laden, Briefentwurf. Ware in der Post zählt zum Bestand. | Ledger |
| **E3** | Letzter Kauf und letzter Verkauf (Abschnitt 4), `mod:LastBuy`, `mod:LastSale`, Tooltip. | Ledger |
| **E4** | Neues Fenster mit vier Seiten (Abschnitt 6), alte Reiter und Dateien entfernen (Abschnitt 7). | Ledger |
| **E5** | Eigenes Postfenster Peon Post mit „Auktionshaus-Post einsammeln“, Erfassen mit Ablauf, Post aller Charaktere (Abschnitt 5). Vorher Blizzard-Code nachlesen. Eventuell gemeinsamer Kern-Baustein mit Peon_Bags für Blizzard-Fenster im Hintergrund. | Ledger, eventuell Peon |
| **E6** | Broker Gegenstand „Mein Bestand“ mit letztem Kauf, Händlerpreise über `LastBuy`. | Broker |
| **E7** | Seite Senden im Postfenster (Abschnitt 5.4). | Ledger |

E1 kommt zuerst, weil es uns zeigt, welche Lücken nach E2 noch übrig sind. E4 kann nach E1 parallel laufen.

**Daten:** Mit dem Update von E2 wird das Buch einmal zurückgesetzt (KarloDerBaer), weil die alten Auktionshaus-Zeilen die Lücken aus 3.2 enthalten. Der aktuelle Stand wird zum neuen Anfangsbestand. Ein einmaliger Hinweis (`mod:AddNotice`) erklärt das beim ersten Einloggen.

## 10. Abstimmung mit KarloDerBaer

### Entschieden (KarloDerBaer, 12.11.2026)

1. **Zuletzt gezahlt:** alle Käufe (Auktionshaus, Händler, Nachnahme, Handel mit Gold), Quelle wird angezeigt. Zusätzlich wird der letzte Verkaufspreis gemerkt.
2. **Post einsammeln:** Der eigene Knopf kommt wieder (nur per Klick, Brief für Brief).
3. **Neustart der Daten:** Nach dem Umbau der Erfassung wird das Buch zurückgesetzt.
4. **Briefkasten:** eigenes Postfenster, Blizzards Postfach wenn nötig im Hintergrund (Abschnitt 5.2).
5. **Verlauf korrigieren:** später, nicht jetzt.
6. **Übersicht:** Kacheln wie vorgeschlagen, aber Handelsgewinn **heute** statt 7 Tage.
7. **Buch:** oben Handelsgewinn und Gesamtgewinn, Beute, Quests und Verbrauch nur in „Nach Art“.

8. **Postfenster:** Klick auf einen Brief nimmt ihn direkt. Neben „Auktionshaus-Post einsammeln“ gibt es „Alles einsammeln“ (ohne Nachnahme). Senden bekommt gleich eine eigene Seite im Peon-Look (E7).

### Offen

- Prüfung im Spiel (Liste im Changelog von Ledger 0.14.0).
- Gemeinsamer Kern-Baustein für Blizzard-Fenster im Hintergrund (Bags und Ledger nutzen je eine eigene Kopie).
