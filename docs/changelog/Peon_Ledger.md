# Peon_Ledger: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 0.11.0

Kurz: Mit Peon_Panel zeigt Ledger auf der Leiste dein Gold.

- 0.11.0 (07.11.2026): Texte für Peon_Panel: Gold aller Charaktere (Standard), Gold dieses Charakters, in kurzer Form wie `12,3k g`. Bei jeder Änderung des Golds aktualisiert. Ohne Peon_Panel ändert sich nichts.

## 0.10.2

Kurz: Diagramme zeigen auch bei Daten von nur einem Tag etwas an.
Kurz: Abgeschnittene Texte behoben.

- 0.10.2 (05.11.2026, Rückmeldung KarloDerBaer): Reiter „Gegenstand“: Liegen erst Daten von einem Tag vor, zeigen die Diagramme Punkte (braucht Peon 0.11.1) und unter dem Diagramm steht ein Hinweis, dass Linien ab dem zweiten Tag entstehen. Abgeschnittene Texte behoben: im Marge-Kasten nur noch „Kosten 0“, Suchhinweis kürzer, die Menge im Auktionshaus hat eine eigene Zeile statt im Untertitel zu stehen. „Üblich“ zeigt ohne Werte „–“ statt einer leeren Zeile. Die gespeicherten Werte waren richtig. **Im Spiel prüfen:** Punkte in beiden Diagrammen, alle Texte vollständig, Textspalte passt ins Fenster.

## 0.10.1

- 0.10.1 (31.10.2026): Beispielnamen im Hinweis der Optionsseite („Bestand: 25 (Mirel 20, Borin 5)“) erfunden statt echter Charakternamen, weil das Repo öffentlich wird. Sonst unverändert.

## 0.10.0

- 0.10.0 (07.10.2026, Wünsche KarloDerBaer, abgestimmt; **WoW komplett neu starten** – neue Datei Catalog.lua; braucht Broker 0.29 für die AH-Spalten, sonst „–“):
  - **Minimap-Symbol** (und Fenster, Addonliste): Schriftrolle `INV_Scroll_03` statt Buch (das Buch nutzt schon das Dungeon-Journal).
  - **Neuer Reiter „Gegenstände“** = alle bekannten Gegenstände: Bestand aller Charaktere, Verlauf, gemerkte Namen und alle Gegenstände des aktuellen Markts (Broker `MarketItems`). Suche nach Namensteil oder Nummer, Auswahlliste „Alle bekannten / Im Bestand / Im Verlauf / Im Auktionshaus“ (gemerkt). Spalten Gegenstand, Bestand, Kosten (Ø aller Charaktere), AH Min, AH Menge, Händler, Zuletzt (Bewegung oder AH gesehen). Klick öffnet den Reiter „Gegenstand“. Namen ohne Nachladen vom Server (Ledger, sonst Broker).
  - **Bisheriger Reiter „Gegenstände“ heißt „Umsatz“** (Zu/Ab, Verkaufsquote, Einnahmen, Gewinn je Gegenstand), sonst unverändert. Sieben Reiter.
  - **Reiter „Gegenstand“ – Diagramme nach Einheit getrennt** (KarloDerBaer, aus zwei Vorschlägen): oben **„Preis je Stück“** nur Gold (AH Min, Median, üblicher Bereich, deine Kosten, Gewinnzone mit „ohne Verlust ab“, Händler; Kreise/Quadrate = Verkäufe/Käufe); unten **„Stück“** (links dein Bestand und Beute, rechts Menge im AH und Absatz/Tag, Achsen beschriftet „links: Mirel“ / „rechts: Auktionshaus“). Kein gemeinsamer Maßstab mehr, nur gemeinsame Mauslinie. Alle Linien in einer Legende (vorher fehlten AH Min im oberen, Kosten im unteren Diagramm, und „zone“ war falsch beschriftet). Oben links Auswahlliste Charakter, daneben Marge-Streifen, rechts Zeitraum.
  - **Werte-Kasten beim Überfahren** neben der Mauslinie statt zweier Textzeilen: Datum; Preis je Stück (AH Min, Median, Üblich, Kosten, Ohne Verlust ab, Marge); Stück (Bestand, Beute, Menge im AH, Absatz/Tag); Käufe und Verkäufe.
  - Gespeicherte Linien an/aus bleiben (Schlüssel gleich; „Kosten blass“ im unteren Diagramm entfällt).
  - **Im Spiel prüfen:** Passen sieben Reiter unten ins Fenster? Liest sich das Diagramm besser? Werte-Kasten an der richtigen Stelle? Reiter „Gegenstände“ mit vielen AH-Gegenständen flüssig (Suche)?
- **Ergebnis Prüfung Absatzquote (03.10.2026, `PeonBrokerDB.fieldProbe`):**
  - **Massenware** (147 Ergebnisse): `auctionID`, **`timeLeftSeconds` (Sekunden genau, z. B. 6959)**, `quantity`, `unitPrice`, `totalNumberOfOwners` (Zahl, z. B. 3 bei Menge 4 → eine Zeile kann mehrere Verkäufer zusammenfassen), `owners` **leer**, `numOwnerItems`, `containsOwnerItem`.
  - **Einzelgegenstände** (379 Ergebnisse): `auctionID`, **`timeLeft` (Stufe 0–3)**, `timeLeftSeconds` nur 1×, `buyoutAmount`, `quantity`, `itemKey`, `itemLink`, `totalNumberOfOwners`, `owners` **leer**, `minBid`/`bidAmount` nur bei Geboten.
  - **Komplettscan:** Restzeit-Prüfung noch nicht gelaufen (`probe.scan` ohne „Restzeit“, ohne Stufen-Zählung) – `/broker pruefen scan` nochmal mit Broker 0.22.1.
- Nächster Schritt: gemeinsamer Test – Broker 0.23.0 (**WoW komplett neu starten**, neue Datei): ein paar Komplettscans und Radar laufen lassen, dann Tooltip mit Umschalt, Preise-Spalte, `/broker absatz <Gegenstand>`; `/broker pruefen scan` (Restzeit im Scan); Behalten-Umschalter und Vermögen (Ledger 0.5.1).
- **L6 abgestimmt (03.10.2026):** Broker-Reiter „Behalten“ nutzt den Vorrat aus Ledger mit Umschalter „nur dieser Charakter / alle Charaktere“; Broker zeigt die eigene **Verkaufsquote** (aus Ledger); Ledger-Vermögen mit Brokers Preisen; Brokers Reiter „Buch“ entfällt. Getrennt davon ermittelt Broker später eine **Absatzquote** des Marktes (eigener Schritt; vorher prüfen, ob Auktionsnummern und Restlaufzeit bei den Abfragen geliefert werden). Kombination beider Werte später.

## 0.9.1

- 0.9.1 (06.10.2026, Wunsch KarloDerBaer, abgestimmt; **WoW komplett neu starten** – neue Dateien Pick.lua und Bindings.xml):
  - **Alt+Klick** auf einen Gegenstand öffnet ihn im Reiter „Gegenstand“: überall, wo ein Gegenstands-Tooltip erscheint (`GLOBAL_MOUSE_DOWN` + `GameTooltip:GetItem()`, auch Listen von Broker/Ledger und Auktionshaus), dazu Chat-Links und alles, was das Spiel als Klick mit Taste meldet (`HandleModifiedItemClick`). **Nicht auf Aktionsleisten** (dort löst Alt+Klick zusätzlich die Taste aus – KarloDerBaer). Nur Alt (nicht mit Strg/Umschalt), nur Linksklick; derselbe Klick über zwei Wege öffnet nur einmal.
  - **Tastenbelegung** „Gegenstand unter der Maus in Ledger zeigen“ (`PEON_LEDGER_ITEM`, Kategorie AddOns, frei wählbar): nimmt den Gegenstand aus dem Tooltip unter der Maus, auch auf Aktionsleisten; ohne Tooltip Hinweis im Chat.
  - **Im Spiel prüfen:** löst Alt+Klick in Taschen/Bank zusätzlich etwas vom Spiel aus? Erkennt Ledger Aktionsleisten-Knöpfe (auch von anderen Leisten-Addons)?

## 0.9.0

- 0.9.0 (06.10.2026, Konzept `Peon_Ledger_Gegenstand.md` G3–G5, mit KarloDerBaer abgestimmt; **WoW komplett neu starten** – neue Dateien Item.lua und im Kern Chart.lua):
  - **Kosten je Charakter** (Cost.lua, ersetzt „accountweit“): Posten je Charakter und Gegenstand. Post an eigene Twinks nimmt die ältesten Posten des Absenders mit; sie liegen bis zum Abholen „unterwegs“ beim Empfänger und kommen dann mit ihrem **ursprünglichen Datum** zu seinen Posten. Abholen ohne bekannten Versand: Marktwert (gemerkt). Gebühren, Verkäufe, Käufe je Charakter. `ns.Cost.Info(id, Charakter)` (nil = eingeloggter, `"*"` = alle), `ByChar`, `TotalValue(Charakter)`. Buch und Gegenstände mit „Nur dieser Charakter“ rechnen mit den eigenen Kosten; Bestand/Übersicht mit allen. Tooltip: Kosten des eingeloggten Charakters, mit Umschalt je Charakter hinter den Orten. `mod:Cost(itemID [, Charakter])` (ohne = eingeloggter) – Broker „Unter deinen Kosten“ nimmt damit die Kosten des Verkäufers. KarloDerBaers Daten (nur Mirel): Lagerwert und Handelsgewinn unverändert.
  - **Tagesverlauf** `ns.Cost.ItemDays(id, Charakter)`: Nachspielen mit Stand je Tag (Stück mit Posten inkl. unterwegs, Kosten Ø), Beute, Käufe und Verkäufe (Preis je Stück; Verkauf mit Sofortkaufpreis aus der Rechnung). Tage wie Broker (`ns.Cost.DayOf`).
  - **Reiter „Gegenstand“** (Item.lua, sechster Reiter): links Suchfeld (Name, Teil, Nummer, Link + Eingabe), Symbol, Name, Warenart/Menge im AH, Marge-Kasten (Verkaufen lohnt / Verkauf mit Verlust: Marge je Stück mit den Kosten des nächsten Stücks und Prozent, seit n Tagen; Kosten 0 = „alles gesammelt“ mit Erlös), „Ohne Verlust ab“, „AH jetzt (Min)“; Charakter (Bestand, Kosten Ø, Lagerwert, Verkaufsquote, bei allen die Aufteilung); Auktionshaus (Üblich, Absatz ≈ x/Std. farbig, Median, Händler). Rechts: Marge-Streifen an/aus, Zeitraum 7/30/90 T./Alles; Diagramm Charakter (Überschrift = Auswahlliste Charakter, Standard eingeloggter; Gewinnzone, Kosten Ø als Stufe, Bestand als Umriss, Beute aus; Kreise = Verkäufe, Quadrate = Käufe, senkrechte Striche); Marge-Streifen (Achse um 0); Diagramm Auktionshaus (Üblich, Median, Min, Menge; Absatz/Tag und Händler aus; Kosten blass); gemeinsame Mauslinie mit zwei Zeilen darunter. Gold-Achsen mit gleichem Maßstab, Lücken im Markt linear überbrückt, Wochenwerte von Broker auf die Tage der Woche verteilt. Linien an/aus, Zeitraum, Marge-Streifen und letzter Gegenstand werden gemerkt.
  - **Öffnen:** Klick auf eine Zeile in Bestand, Verlauf und Gegenstände; `/ledger <Name, Nummer oder Link>`; Broker-Reiter Preise „Mehr… (Ledger)“; `mod:ShowItem(itemID)`.
  - Ohne Broker: nur das Diagramm Charakter, Hinweis in der Textspalte.
  - Grenzen: Bestand im Diagramm = Stück mit Posten; Tagesverlauf erst ab Start von Ledger, Wochensummen nach 90 Tagen fließen noch nicht ein; „Ohne Verlust ab“ ohne offene Einstellgebühren.
  - Bereiche für Peon_Feedback: zusätzlich „Kosten“ und „Gegenstand“.

## 0.8.1

- 0.8.1 (03.10.2026, Wunsch KarloDerBaer, abgestimmt): **Verlauf fasst weitere Vorgänge zusammen** (nur Anzeige, `H.Family`/`H.GroupRow` in History.lua). Gleicher Charakter, höchstens 5 Sek. Abstand (Herstellen 30 Sek.), kein anderer Eintrag dazwischen:
  - Feste Paare: **Auktion eingestellt + Einstellgebühr** (gleicher Gegenstand; Zeile grau als Umbuchung, Gebühr rot in der Goldspalte), **Handel** (gleicher Partner), **Quest** (Belohnung „gegen“ abgegebene Questgegenstände, Gold), **Post an/von Twink** (gleicher Empfänger).
  - Serien gleicher Art und Richtung: Auktion zurück / verkauft / gekauft („Alle öffnen“), Händler verkauft bzw. gekauft, Rückkauf, Post vom selben Absender, Korrekturen.
  - Nicht zusammengefasst: Abbruchkosten, Tagessummen (Beute, Benutzt), Flug, Lehrer, Reparatur, Zerstört, sonstiges. Ohne „Umbuchungen“ steht die Einstellgebühr allein.
  - Anzeige: Hauptgegenstand ×Menge, dahinter grau „+ 2 Seidenstoff, 1 Leinenstoff“ (gleiche Richtung, ab 3 „+ 1 X, n weitere“) bzw. „gegen …“ (Gegenrichtung), Gold als Summe. Tooltip: jeder Eintrag einzeln (Art, Gegenstand, Gold), Summe, bei Verkäufen Wareneinsatz/Gebühren/Gewinn zusammen. Suche findet die Zeile über alle Gegenstände.
  - In KarloDerBaers Daten vom 03.10.: 41 Einträge → 13 Zeilen.

## 0.8.0

- 0.8.0 (03.10.2026, Wünsche KarloDerBaer zur Darstellung, abgestimmt):
  - **Übersicht neu:** Charakterliste nur 5 Zeilen (Bildlauf bei mehr), darunter drei Blöcke nebeneinander mit Beschriftung links und Betrag rechts: **Vermögen** (Gold mit Anzahl Charaktere, Gegenstände, Gesamt, Lagerwert (Kosten), Hinweis „n Gegenstände ohne Preis“ bzw. „braucht Peon_Broker“), **Gewinn** (Heute, 7 Tage, 30 Tage, Handelsgewinn 7 Tage, Verbrauch 7 Tage), **Plätze** (Taschen frei, Bank frei, laufende Auktionen; „–“ = noch nicht erfasst). Die überlappenden Textzeilen unten sind weg; Hinweis „– = noch nicht erfasst“ allein unten rechts.
  - **Verlauf – Herstellen zusammengefasst:** Einträge „Hergestellt“/„Material verbraucht“ desselben Charakters und Rezepts, höchstens 30 Sek. auseinander, sind eine Zeile: „Disteltee ×5  aus 5 Flitzdistel, 5 Erfrischendes Quellwasser“ (Material grau). Tooltip: Ergebnis, Material, Kosten je Stück, Zahl der zusammengefassten Einträge. Suche findet die Zeile auch über das Material. Nur Anzeige – gespeichert bleibt alles einzeln (Kosten rechnen unverändert).

## 0.7.3

- 0.7.3 (03.10.2026, Frage KarloDerBaer zu gebundenen Gegenständen):
  - **Gebundenes zählt im Vermögen nur mit dem Händlerpreis** – mehr bekommt man dafür nicht. Taschen, Bank und Accountbank merken sich je Gegenstand die gebundenen Stück (`places.bags/bank.bound[itemID]`, `warband.bound`, aus `isBound`); Ungebundenes (z. B. BoE) weiter mit Brokers Wert.
  - **Angelegte Ausrüstung zählt immer zum Vermögen**, immer als gebunden (Händlerpreis). Die Option „Angelegte Ausrüstung zum Vermögen zählen“ (`worthEquip`) entfällt.
  - Gilt für Spalte „Vermögen“ (Übersicht) und Spalte „Wert“ (Bestand); neue Funktion `ns.Worth(id, n, gebunden)`. Lagerwert/Kosten unverändert.

## 0.7.2

- 0.7.2 (03.10.2026, Wunsch KarloDerBaer: „was in der Post ist, gehört mir erst beim Nehmen“):
  - Der Briefkasten zählt **nicht mehr zum Bestand** (Tooltip, Reiter Bestand, Vermögen, Vorrat aller Charaktere). Er wird nur noch intern gelesen (Briefe, Rechnungen, Gründe).
  - Bewegungen erst **beim Nehmen**: Öffnen des Briefkastens bucht nichts; nimmst du einen Gegenstand (Taschen +), wird er als Zugang verbucht (Auktion gekauft – an die Goldzeile des Kaufs gehängt, Auktion zurück, Post von anderen, Nachnahme). Der alte „unterwegs“-Abgleich Post ↔ Taschen entfällt.
  - **Post an eigene Twinks:** steht bis zum Abholen beim Twink als neuer Ort **„Unterwegs“** (`places.transit`, Gegenstände und Gold) – zählt zu Bestand, Vermögen und Vorrat; beim Abholen dort wieder weg.
  - Kosten (Zuordnen): Briefkasten und „Unterwegs“ gehören nicht zum Anfangsbestand.

## 0.7.1

- 0.7.1 (03.10.2026, Wunsch KarloDerBaer): Post wird nicht mehr angezeigt – Spalte „Post“ in der Übersicht und „Gold in der Post“ entfernt, Vermögen ohne Post-Gold, Schnittstelle `mod:MailInfo()` entfällt. Das Mitlesen beim Leeren des Briefkastens (Erlöse, Auktion gekauft/zurück, Post an Twinks) bleibt für Buch und Kosten; Post zählt intern weiter als Ort (Tooltip mit Umschalt, Vorrat der Twinks).

## 0.7.0

- 0.7.0 (03.10.2026, **Zuordnen Z1–Z3**, Konzept `Peon_Ledger_Zuordnen.md`), neue Datei Cost.lua (**WoW komplett neu starten**):
  - **Kosten je Stück nach „älteste zuerst“**, accountweit je Realm: Anfangsbestand zum Marktwert beim Start (eingefroren in `start.v`), Käufe (AH, Händler, Rückkauf) zum bezahlten Preis, Hergestelltes aus den Materialkosten, Beute/Quest/Post von anderen/Sonstiges 0, Nachnahme-Post zum bezahlten Betrag (`paid`), Handel mit Gegenleistung zum Gegenwert (verteilt nach Marktwert), Korrektur aus „Inventur neu“ zum Marktwert (`v`). Abgänge nehmen die ältesten Posten; höchstens 30 Posten je Gegenstand.
  - **Gebühren je Gegenstand:** Einstellgebühr und Abbruchkosten bekommen den Gegenstand (`id`, über „Auktion eingestellt“ bzw. die Auktionsnummer beim Abbruch); offene Gebühren mindern den nächsten Verkauf.
  - **Rechnung:** Nachspielen von Anfangsbestand und Verlauf (zwischengespeichert, neu bei jeder Bewegung; 10.000 Bewegungen ≈ 30 ms). Vor dem Zusammenfassen nach 90 Tagen wird der Stand in `realms[Realm].lotBase` übernommen; „Buch zurücksetzen“ löscht ihn. Knopf „Kosten neu berechnen“ in den Optionen.
  - **Tooltip (Wunsch KarloDerBaer):** ohne Umschalt nur „Ledger (Umschalt)  Kosten 2s (Ø 1s 50c)“ (Kosten des nächsten Stücks, Durchschnitt nur wenn verschieden); Bestand und Orte je Charakter mit Umschalt.
  - **Anzeige:** Fenster 760 breit. Gegenstände: Spalten „Kosten“ (Ø je Stück) und „Gewinn“ (Handelsgewinn im Zeitraum), Tooltip mit Wareneinsatz und Verbrauch. Bestand: Spalte „Lagerwert“ und Summe. Übersicht: Lagerwert unten. Buch: Zeile „Handelsgewinn X (Erlös − Wareneinsatz − Gebühren)“ und „Verbrauch“ (Info). Verlauf-Tooltip: Wareneinsatz/Gebühren/Gewinn bei Verkäufen, Verbrauch, Kosten je Stück bei Zugängen.
  - Schnittstelle `mod:Cost(itemID)` → nächstes, Ø, Stück, Lagerwert (Broker 0.25).
  - Grenzen (0.7): Beute und Benutzt sind je Tag zusammengefasst und zählen mit der Zeit des letzten Zugangs des Tages; Verkäufe ohne Gegenstand (sehr alte Erlöse) zählen voll als Gewinn.

## 0.6.0

- 0.6.0 (03.10.2026, offene Punkte aus dem Konzept und bekannte Lücken, mit KarloDerBaer abgestimmt):
  - **Übersicht:** Zeile „Gewinn (alle Charaktere): Heute · 7 Tage · 30 Tage“; im Zeilen-Tooltip „Gewinn 7 Tage“ je Charakter. Option „Angelegte Ausrüstung zum Vermögen zählen“ (`worthEquip`, Standard aus).
  - **Bestand:** Spalte „Wert“ (Brokers Zeile-1-Wert für die ganze Menge) und Summe unten.
  - **Gegenstände:** Spalte „Ø Preis“ = durchschnittlicher Verkaufspreis je Stück (Sofortkaufpreis aus der Rechnung, sonst Erlös + Anteil).
  - **Verlauf:** Auswahlliste „Filter nach Art“ (Alle, Auktionshaus, Händler, Beute, Benutzt, Quests, Herstellen, Handel, Post, Flüge/Lehrer, Zerstört, Korrekturen, Sonstiges).
  - **Inventur neu (dieser Charakter)** in den Optionen (mit Rückfrage): liest Taschen, Ausrüstung, Gold (und offene Bank/Post) neu; Unterschiede kommen als „Korrektur +/-“ (Art `fix`, Umbuchung, zählt nicht als Gewinn) in den Verlauf. Andere Charaktere kann das Spiel nicht lesen.
  - **Erlös ohne Rechnung** (Betreff „Rufe Daten ab“): Ledger merkt sich beim Verkauf den Preis je Stück aus der Auktionsliste (`p`) und ordnet den Erlös dem passenden Verkauf zu (gleicher Charakter, 7 Tage, Betrag ≈ Preis × Stück − 5 %); steht der Name im Betreff, wird der Gegenstand darüber gefunden. Zugeordnete Erlöse tragen `est`.
  - **Auktion gekauft in einer Zeile:** Kauf von Massenware wird mitgelesen (`StartCommoditiesPurchase` → Gegenstand und Menge an der Goldzeile); der Gegenstand aus der Post wird an diese Zeile gehängt statt eine eigene zu bekommen (auch über den Betrag der Kaufrechnung, z. B. bei Einzelgegenständen).
  - **Händler, mehrere Stapel:** ein Goldbetrag für mehrere Gegenstände wird nach Händlerwert auf die Zeilen aufgeteilt (`split`).
  - Schnittstelle für Broker: `mod:MailInfo()` → Gold in der Post, Briefe, Zeitpunkt (Startseite).

## 0.5.1

- 0.5.1 (03.10.2026, Test von KarloDerBaer): Bei „Alle öffnen“ meldete das Spiel zwei Erlöse als EINE Goldänderung (167 + 3590 = 3757); Ledger buchte alles auf den ersten Brief, der zweite fehlte. Jetzt: gibt es keinen Brief mit genau diesem Betrag, sucht Ledger 2–4 genommene Briefe, deren Gold zusammen passt, und bucht je Brief einen Eintrag. (Der falsche Eintrag vom 03.10. 11:36 bleibt stehen.)

## 0.5.0

- 0.5.0 (03.10.2026, **Bauabschnitt L6 – Zusammenspiel mit Broker**):
  - **Übersicht:** neue Spalte **„Vermögen“** = Gold + Gold in der Post + Wert der Gegenstände in Taschen, Bank, Post und Auktionen (Brokers Zeile-1-Wert; angelegte Ausrüstung zählt nicht); unten Vermögen aller Charaktere; Zeilen-Tooltip mit Anteil der Gegenstände und Anzahl ohne Preis. Ohne Broker „–“.
  - Schnittstelle `mod:StockOthers(itemID)` für Brokers „Behalten“ (Taschen, Bank, Post der anderen Charaktere + Accountbank).

## 0.4.0

- 0.4.0 (03.10.2026, **Bauabschnitt L5 – Buch**; L4 „Post einsammeln“ entfällt, Entscheidung KarloDerBaer), neue Datei Book.lua:
  - **Reiter „Buch“:** Zeitraum (Heute, 7 Tage, 30 Tage, Alles – mit Wochensummen), „Nur dieser Charakter“; Liste nach Art (Auktionshaus Verkäufe/Käufe/Gebühren, Händler, Rückkauf, Reparaturen, Beute, Quests, Herstellen, Handel, Post, Flüge, Lehrer, Sonstiges) mit Einnahmen, Ausgaben, Saldo; unten Summen und **Gewinn = Einnahmen − Ausgaben − Gebühren**, Anteil des Auktionshauses zur Info. Umbuchungen zählen nicht.
  - **Reiter „Gegenstände“:** je Gegenstand Zu/Ab (Stück), im Auktionshaus verkauft/zurück, **Verkaufsquote** (ab 3 Stück, Tooltip „x von y verkauft“), Einnahmen, Ausgaben; Suche.
  - **Erlöse aus der Post** bekommen den Gegenstand (über den Namen aus der Rechnung) und speichern Menge `q`, Anteil `cut`, Sofortkaufpreis `gross`.
  - **„Auktion zurück“** (neu, Umbuchung): Brief vom Auktionshaus mit Gegenstand ohne Kaufrechnung, Zusatz „abgelaufen/abgebrochen“. Auktionen, die ohne „verkauft“ aus der Liste verschwinden, erzeugen keinen Eintrag mehr.
  - **Schnittstelle für Broker (L6):** `mod:SellRate(itemID [, Tage])` → Quote, verkauft, zurück; `mod:Stock(itemID)` → Stück aller Charaktere.
  - Brokers alte Listen werden nicht übernommen (Entscheidungen 03.10.2026).

## 0.3.2

- 0.3.2 (03.10.2026, Wunsch KarloDerBaer): Optionen, Abschnitt „Buch“: Knopf **„Buch zurücksetzen“** (mit Rückfrage) – löscht Verlauf und Wochensummen des Realms, liest Gold, Taschen, Ausrüstung (und offene Bank/Post) neu und nimmt den aktuellen Stand aller Charaktere des Realms als neuen Anfangsbestand. Daneben Anzahl der Einträge im Verlauf. Test 0.3.1 im Spiel: Post mit „Alle öffnen“, Händler, Auktionshaus in Ordnung.

## 0.3.1

- 0.3.1 (03.10.2026, Test von KarloDerBaer mit „Alle öffnen“, Händler, Auktionshaus):
  - **Nach dem Einloggen** lieferte das Spiel 27 Gegenstände der Taschen erst Sekunden später – sie standen als „Sonstiger Zugang“ im Verlauf. Jetzt 20 s Ruhezeit nach dem Einloggen/Neuladen: Bestand wird gelesen, aber keine Bewegungen.
  - **„Alle öffnen“:** Alle Erlöse bekamen denselben Brief (6× „Bauplan: Arkaner Wiederverwerter“). Jetzt Warteschlange der genommenen Briefe (`TakeInboxItem`, `TakeInboxMoney`, `AutoLootMailItem`); jeder Goldbetrag sucht den Brief mit genau diesem Betrag.
  - **Post ↔ Taschen getrennt gemeldet** (Server langsamer als 1 s): Pfeile standen als „verbraucht“ und danach als „Auktion gekauft“. Jetzt „unterwegs“-Abgleich je Gegenstand (bis 30 s) – kein Eintrag.
  - **Briefart aus der Rechnung:** In Forever haben auch gekaufte Auktionen eine Rechnung (Art „buyer“). Brief vom Auktionshaus mit Gegenstand ohne Kaufrechnung = Auktion zurück (Umbuchung) – unabhängig vom Betreff (Stoppelfühlerwels stand als „Post erhalten“). Überboten: Gebot zurück als „Auktion gekauft“ (+). Brief-Protokoll `mailLog` zur Kontrolle.
  - **Händler:** Gold steht jetzt in derselben Zeile wie der Gegenstand (bei mehreren Stapeln über den Verkaufspreis zugeordnet; bleibt nur Gold übrig, eigene Zeile).
  - „Interner Nachrichten-Datenbankfehler“ beim „Alle öffnen“ ist eine Meldung des Servers, nicht von Ledger.
  - Alte falsche Einträge vom 03.10. (27× „Sonstiger Zugang“ 09:21, Erlöse mit falschem Gegenstand, Pfeile 09:27) bleiben im Verlauf stehen.

## 0.3.0

- 0.3.0 (03.10.2026, **Bauabschnitt L3 – Bewegungen**), neue Dateien Moves.lua und History.lua:
  - **Abgleich:** Jede Änderung eines Ortes (Taschen, Bank, Ausrüstung, Post) und des Golds wird gemeldet, 1 s gesammelt und je Gegenstand verrechnet – Taschen ↔ Bank, Taschen ↔ Ausrüstung und „aus der Post geholt“ heben sich auf (kein Eintrag). Beim Einloggen und beim ersten Erfassen eines Ortes keine Bewegungen. Ausrüstung wird mit jeder Taschenänderung mitgelesen, weil `PLAYER_EQUIPMENT_CHANGED` in Forever bisher nie kam.
  - **Zusammenhang (Grund):** offene Fenster (Händler, Post, Bank, Auktionshaus, Handel, Beruf, Beute, Quest, Flugmeister, Lehrer – über `PLAYER_INTERACTION_MANAGER_FRAME_*` und die alten Ereignisse; gilt noch 6 s nach dem Schließen), mitgelesene Aufrufe (Händlerkauf/-rückkauf, Reparieren, Benutzen, Aufnehmen + Zerstören, Herstellen mit Rezeptname, Post verschicken mit Empfänger und Gold, Post nehmen mit Brief, Flug, Lehrer) und Ereignisse (Quest abgegeben, Auktion eingestellt/abgebrochen/gekauft, Beute-Meldung im Chat).
  - **Arten:** Beute (Gegenstände und Gold, je Tag zusammengefasst), Benutzt (je Tag; auch Tränke aus der Aktionsleiste über `GetItemSpell`), Quest-Belohnung/-Abgabe, Händler gekauft/verkauft (Gegenstand und Gold getrennt), Zurückgekauft, Reparatur (Gold weg beim Händler ohne Kauf), Auktion gekauft (Gold beim Kauf, Gegenstand mit dem Brief „gewonnen“), Auktion verkauft (Gegenstand, wenn die Auktion als verkauft erscheint; Gold beim Nehmen des Erlöses mit Gegenstand und Menge aus der Rechnung), Auktionsgebühr, Hergestellt/Material verbraucht, Handel, Post erhalten/verschickt, Flug, Lehrer, Zerstört, sonstiger Zugang, verbraucht/sonstiges.
  - **Umbuchungen** (grau, zählen nicht): Auktion eingestellt (Taschen → Auktionen), Auktion beendet (kommt per Post zurück; der Brief „abgelaufen/abgebrochen“ nimmt den Gegenstand auch aus „Auktionen“, wenn das Auktionshaus seitdem nicht besucht wurde), Post an/von eigenen Twinks (Gegenstände und Gold stehen sofort beim Twink unter Post).
  - **Speichern:** einzelne Einträge 90 Tage, danach beim Einloggen Wochensummen.
  - **Reiter „Verlauf“:** alle Bewegungen, neueste zuerst; Spalten Zeit, Charakter, Art (grün Zugang, rot Abgang, grau Umbuchung), Gegenstand, Gold; Suche, „Nur dieser Charakter“, „Umbuchungen“ ein/aus; Tooltip mit Gegenstand, Zusatz (Partner, Absender, Rezept) und Tagessumme.
  - Grenzen: Accountbank-Bewegungen werden nicht erfasst (gibt es in Forever vermutlich nicht, siehe 06.10.2026); Bank-Änderungen nur bei offener Bank; bei mehr als 50 Briefen sieht das Spiel nur einen Teil.

## 0.2.2

- 0.2.2 (03.10.2026, Feedback Nr. 9 von KarloDerBaer, Fehler/Übersicht/mittel): Post und Auktionen in der Übersicht ebenfalls in Plätzen statt Stück (Post = Anhänge, Auktionen = laufende Auktionen; alter Auktionsstand wird aus `active` gelesen, Post zeigt bis zum nächsten Öffnen des Postfachs noch Stück). Stück je Ort im Zeilen-Tooltip. Feedback-Eintrag gelöscht.

## 0.2.1

- 0.2.1 (02.10.2026): Übersicht zeigte bei Taschen die Stückzahl (237 Stück in 38 Sorten) – jetzt belegte/alle Plätze wie die Taschenanzeige; Stück im Zeilen-Tooltip. Ausrüstung wurde beim Einloggen leer erfasst (Spiel liefert sie erst später): leeres Ergebnis wird nicht gespeichert, bis zu 3 neue Versuche im Abstand von 3 s; die leere Inventur von 0.2.0 wird durch die erste echte ersetzt. Bank (bankLog): Charakterbank = Tasche 6 mit 48 Plätzen, Accountbank-Taschen ohne Plätze.

## 0.2.0

- 0.2.0 (02.10.2026, **Bauabschnitt L2 – Bestand**):
  - Bestand je Charakter und Ort, nur ereignisgesteuert: Taschen 0–5 (nach `BAG_UPDATE_DELAYED` nur die gemeldeten Taschen; im Kampf erst danach), Ausrüstung (`PLAYER_EQUIPMENT_CHANGED`), Gold (`PLAYER_MONEY`), Bank nur offen (Taschen aus `Enum.BagIndex`: Namen mit „Bank“, „Account“ = Accountbank für alle Charaktere; ohne Enum klassische Belegung −1, 6–12; Öffnen/Schließen über `BANKFRAME_*` und `PLAYER_INTERACTION_MANAGER_FRAME_*` Typ 8), Post nur offen (Anhänge mit `GetInboxItem`, Gold in Briefen; Typ 17), eigene Auktionen (`QueryOwnedAuctions` beim Öffnen des Auktionshauses, laufende als Bestand, verkaufte gezählt).
  - **Inventur (Ist-Zustand):** Jeder Ort wird beim ersten Erfassen als Anfangsbestand gespeichert (`start`), Gold beim ersten Login.
  - **Tooltip:** „Ledger · Bestand: 48 (Mirel 43, Borin 5)“ (hellblau, Vornamen, eigener Charakter zuerst); mit Umschalt je Charakter die Orte.
  - **Ledger-Fenster** (Minimap-Button links, `/ledger`): Reiter „Übersicht“ (Charaktere mit Gold, Taschen und Bank als belegte/alle Plätze inkl. Reagenzientasche, Post = Anhänge, Auktionen = laufende Auktionen, Sortierung nach Plätzen, gesehen; Zeilen-Tooltip: Stück und freie Plätze je Ort; „–“ = noch nicht erfasst; Gold aller Charaktere) und „Bestand“ (alle Gegenstände aller Charaktere, Suche, Spalte „Wo“).
  - Optionen: Minimap-Button, Bestand im Tooltip, Fenster öffnen, Charakterliste mit „Gewählten Charakter löschen“, Prüfung.

## 0.1.0

- 0.1.0 (02.10.2026, **Bauabschnitt L1 – Prüfbefehl**, nur lesend):
  - `/ledger pruefen`: Charakter (Vor- und Nachname), Realm, Gold, Version; welche Funktionen es je Bereich gibt (Taschen/Bank, Ausrüstung, Post, Händler, Handel, Berufe, Beute, Quests, Sonstiges) mit Liste der fehlenden; Texte und Konstanten (Beute-, Quest-, Auktions-Texte, Taschen-Nummern); Taschen, Ausrüstung, Tränke mit Zauber; dazu jedes gerade offene Fenster.
  - Ereignisse für Taschen, Bank, Gold, Ausrüstung, Post, Händler, Handel, Berufe, Zauber (nur eigene), Beute, Quests, Flugmeister, Lehrer, Zerstören, Auktionshaus, Kampf: bekannt/unbekannt, Anzahl, Beispiele.
  - Mitlesen von Aufrufen (nach dem Aufruf, ändert nichts): Händlerkauf/-rückkauf, Reparieren, Zerstören, Benutzen, Post verschicken/nehmen, Flugmeister, Lehrer, Herstellen, Handel annehmen.
  - Automatisch die ersten 3 Male beim Öffnen gelesen (einmal Hinweis im Chat): Postfach (Kopf, Rechnung, Anhang), Händler (Waren, Reparatur, Rückkauf), Bank (Hauptfach, Bank-Taschen), Handel, Beruf (alte und neue Schnittstelle, Rezept mit Materialien), Verzauberkunst, Beute, Quest-Belohnung, Flugmeister, Lehrer.
  - Optionsseite: Knopf „Prüfung starten“ und Stand (letzte Prüfung, Ereignisse gesehen, gelesene Fenster).
- **Ergebnis der Prüfung im Spiel (02.10.2026, Mirel Dorna, Build 70170):**
  - Taschen: `C_Container` vollständig; **6 Taschen** (0–5, `NUM_TOTAL_EQUIPPED_BAG_SLOTS` = 5, Tasche 5 = 12 Plätze, vermutlich Reagenzientasche). `GetContainerItemInfo` liefert Tabelle mit itemID, stackCount, hyperlink, isBound, isLocked, hasNoValue, quality. **`BANK_CONTAINER` und `NUM_BANKBAGSLOTS` fehlen**, `KEYRING_CONTAINER` = −1, `GetNumBankSlots` fehlt → Bank über die moderne Schnittstelle (Enum.BagIndex / C_Bank) prüfen. `BANKFRAME_OPENED` kam nicht (Bank evtl. nicht geöffnet), `PLAYERBANKSLOTS_CHANGED` 1×.
  - **Links haben ein neues Farbformat** `|cnIQ1:|Hitem:…` statt `|cffxxxxxx` (betrifft u. a. Brokers Qualitätserkennung aus Links in „Meine Auktionen“).
  - Ausrüstung: `GetInventoryItemLink` 1–19 geht. Gold: `GetMoney`, `PLAYER_MONEY` gehen.
  - **Post vollständig:** `GetInboxHeaderInfo` (Absender „Auktionshaus der Allianz“, Betreff, Gold, Tage, Anzahl/Link des Anhangs), `GetInboxInvoiceInfo` = Art („buyer“/„seller“), Name, Spieler, Gebot, Sofortkauf, **Einzahlung**, **Anteil**, …, Menge. Beispiel Verkauf: 9500 Sofortkauf, Einzahlung 75, Anteil 475 → Brief 9100 = 9500 − 475 + 75. `TakeInboxMoney`/`TakeInboxItem` mitgelesen. `MAIL_CLOSED` kam nicht – Schließen kommt über `PLAYER_INTERACTION_MANAGER_FRAME_HIDE` (Typ 17).
  - **Händler:** `GetMerchantItemInfo` fehlt (moderne Schnittstelle `C_MerchantFrame` nutzen), Links, Rückkauf (`GetBuybackItemInfo`), `GetRepairAllCost`, `BuyMerchantItem` (mitgelesen: Index, Menge) gehen.
  - **Berufe:** alte Funktionen (`GetTradeSkillInfo`, `GetCraftInfo`, `DoTradeSkill`) fehlen, `CRAFT_*` unbekannt; **modern `C_TradeSkillUI`** geht: `GetAllRecipeIDs`, `GetRecipeInfo`, `GetRecipeSchematic` (Ergebnis-Gegenstand, Menge, Materialien), `CraftRecipe(recipeID, Anzahl)` mitgelesen; `UNIT_SPELLCAST_START/SUCCEEDED` mit derselben Nummer.
  - **Beute:** `GetLootSlotInfo/Link/Type` gehen; `CHAT_MSG_LOOT` liefert „Ihr erhaltet Beute/einen Gegenstand: …“ (auch für Post-Anhänge); `ITEM_PUSH`, `BAG_NEW_ITEMS_UPDATED` kommen.
  - Benutzen: `C_Container.UseContainerItem` mitgelesen; Tränke/Gifte haben einen Zauber (`C_Item.GetItemSpell`). Flugmeister: `TakeTaxiNode`, `TaxiNodeCost`. `UseItemByName` fehlt.
  - Fenster öffnen/schließen meldet zuverlässig `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` mit Typ (z. B. 5 Händler, 17 Post, 3 Flugmeister).
  - Noch nicht gesehen: Bank, Handel, Quest-Abgabe, Lehrer, Zerstören.
