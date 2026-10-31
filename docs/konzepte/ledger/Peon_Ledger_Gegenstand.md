# Peon_Ledger – Reiter „Gegenstand“ und Kosten je Charakter

Stand: 06.10.2026 – mit KarloDerBaer im Chat abgestimmt (Entwürfe 1–5), **umgesetzt** in Peon 0.10.0, Broker 0.27.0, Ledger 0.9.0 (Tests OK, im Spiel noch zu prüfen). Einzelheiten der Umsetzung in `Peon_Stand.md`.

## 1. Ziel

Ein Reiter im Ledger-Fenster, der alles zu einem Gegenstand zeigt: was ich davon habe und was es mich gekostet hat, was der Markt macht und ob sich Verkaufen gerade lohnt – mit zwei Diagrammen über einen Zeitraum.

Dazu kommen **Kosten je Charakter** (bisher accountweit), damit die Werte eines Charakters stimmen.

## 2. Ort und Öffnen

- **Peon_Ledger**, neuer Reiter **„Gegenstand“** (KarloDerBaer). Grund: Bestand, Kosten und Verkäufe hat nur Ledger; das Ledger-Fenster geht überall auf, Broker ist ans Auktionshaus gebunden.
- Öffnen: Klick auf eine Zeile in den Ledger-Reitern Bestand, Gegenstände und Verlauf; Knopf „Mehr…“ in den Einzelheiten des Broker-Reiters Preise (nur wenn Ledger geladen ist); `/ledger <Name, Nummer oder Link>`; Suchfeld im Reiter.
- Ab Ledger 0.9.1 (KarloDerBaer): **Alt+Klick** auf einen Gegenstand überall, wo ein Tooltip erscheint (nicht auf Aktionsleisten), und eine frei wählbare **Tastenbelegung** für den Gegenstand unter der Maus. Broker gibt Alt+Klick dafür ab.
- Gemerkt werden: zuletzt gewählter Zeitraum, an-/abgeschaltete Linien, Marge-Streifen an/aus, zuletzt gezeigter Gegenstand.

## 3. Aufbau (Entwurf 5)

Links eine Textspalte (~170 breit), rechts übereinander: Diagramm „Charakter“, zuschaltbarer Marge-Streifen, Diagramm „Auktionshaus“, darunter die Zeile mit den Werten unter der Maus. Oben rechts der Zeitraum (7 T. / 30 T. / 90 T. / Alles).

### 3.1 Textspalte (von oben nach Wichtigkeit)

1. Suchfeld, Symbol, Name in Qualitätsfarbe, Warenart und Angebote im AH.
2. **Marge-Kasten**: „Verkaufen lohnt“ (grün) bzw. „Verkauf mit Verlust“ (rot) – Marge je Stück in Kupfer und Prozent, „seit n Tagen“.
   Darunter „Ohne Verlust ab X“ und „AH jetzt (Min)“.
3. **Charakter** (Name aus der Auswahlliste): Bestand, Kosten Ø; blasser: Lagerwert, Verkaufsquote, bei „Alle Charaktere“ die Aufteilung je Charakter.
4. **Auktionshaus**: üblicher Bereich, Absatz; blasser: Median, Händlerpreis.

### 3.2 Diagramm „Charakter“

- **Überschrift = Auswahlliste** mit dem Charakter (KarloDerBaer): Standard der eingeloggte Charakter, außerdem „Alle Charaktere“ und jeder andere Charakter des Realms. Gilt für die Textspalte „Charakter“, dieses Diagramm, den Marge-Kasten und die Markierungen.
- Achse links Gold je Stück, rechts Stück.
- Linien (an/aus über die Leiste neben der Überschrift, sie ist zugleich die Legende):
  - **Gewinnzone** (Standard an): AH Min als blaue gestrichelte Linie, „ohne Verlust ab“ als dünne orange gestrichelte Linie, die Fläche dazwischen grün (lohnt) bzw. rot (Verlust).
  - **Kosten Ø** als Stufenlinie (orange), Standard an.
  - **Bestand** als Umriss (grau), Standard an.
  - **Beute je Tag** als Balken (grün), Standard aus.
  - Käufe (Quadrat) und Verkäufe (Kreis) als Punkt beim Preis je Stück.

### 3.3 Marge-Streifen (zuschaltbar, Standard aus)

Flacher Streifen zwischen den Diagrammen: Marge je Stück je Tag als Balken über (grün) bzw. unter (rot) null.

### 3.4 Diagramm „Auktionshaus“

- Achse links Gold je Stück, rechts Stück.
- Üblicher Bereich (helles Band), Median, Min (gestrichelt), Menge im AH (Stück), Absatz je Tag (Standard aus), Händlerpreis (Standard aus).
- Meine Kosten als blasse orange Stufenlinie (zum Vergleich, immer an).

### 3.5 Gemeinsam

- **Beide Gold-Achsen haben denselben Maßstab** (gleicher Preis = gleiche Höhe). Die Stück-Achsen haben je einen eigenen.
- **Farbregel**: Orange = ich (Kosten), Blau = Markt, Grün/Rot nur Gewinn/Verlust, Grau = Bestand.
- **Senkrechte Striche** für meine Käufe (ocker) und Verkäufe (grün) in beiden Diagrammen.
- **Mauslinie** durch alle Diagramme; darunter zwei Zeilen: Tag, Marge, Ereignis („verkauft 25 zu 79c“) / Werte Charakter | Werte Auktionshaus.
- Bis 90 Tage Tageswerte, darüber Wochenwerte (so speichern Broker und Ledger).
- Achsen: links immer „c“ (bzw. s/g bei größeren Werten), rechts immer „St.“.

## 4. Rechnung

- **Ohne Verlust ab** = Kosten ÷ 0,95 (Anteil des Auktionshauses; die Einstellgebühr kommt beim Verkauf zurück, offene Gebühren des Gegenstands werden je Stück dazugerechnet).
- **Marge je Stück** = Wert wie Zeile 1 des Broker-Tooltips je Stück (günstigstes Angebot minus Unterbieten) × 0,95 − Kosten.
  Im Diagramm mit Kosten Ø des Tages; im Marge-Kasten mit den Kosten des nächsten Stücks (wie Brokers Hinweis „Unter deinen Kosten“) – *bei der Umsetzung im Spiel prüfen, ob das verständlich ist*.
- Kosten 0 (nur gesammelt): Kasten zeigt „Kosten 0 – alles gesammelt“ und den Erlös je Stück.
- „Lohnend seit“ / „im Zeitraum lohnend“: Tage, an denen der Tageswert AH Min × 0,95 über den Kosten lag.

## 5. Daten

| Wert | Quelle | Zeitraum |
|---|---|---|
| AH Min, Median, Menge | Broker Tageswerte (`e.d`), dann Wochenwerte (`e.w`) | `dataDays` (30–90) Tage, dann 26 Wochen |
| Üblicher Bereich | aus den Tagesmedianen bis zu jedem Tag (Rechenmodell Kapitel 7) | wie oben, ab 3 Tageswerten |
| Absatz je Tag | Broker `e.ab` – **neu so lange wie die Preise** (KarloDerBaer), dann Wochenwerte | bisher 14 Tage |
| Bestand, Kosten Ø, Beute, Käufe/Verkäufe | Ledger: Nachspielen von Anfangsbestand und Verlauf mit Tagesständen | ab Start von Ledger (03.10.2026); nach 90 Tagen Wochenwerte |
| Händlerpreis | `C_Item.GetItemInfo` | fest |

Marktdaten nur aus dem aktuellen Markt (Realm / Fraktion), Ledger-Daten aus dem aktuellen Realm.

## 6. Kosten je Charakter (neu, KarloDerBaer 06.10.2026)

Ersetzt „accountweit je Realm“ aus `Peon_Ledger_Zuordnen.md`.

- **Posten je Charakter und Gegenstand**, weiter „älteste zuerst“, höchstens 30 Posten. Zugänge und Abgänge eines Charakters betreffen nur seine Posten.
- **Post an eigene Twinks**: Beim Absender werden die ältesten Posten entnommen; sie liegen beim Empfänger unter „Unterwegs“ und kommen beim Abholen zu seinen Posten – **mit ihrem ursprünglichen Datum** (KarloDerBaer), also an der richtigen Stelle der Reihenfolge, und den Kosten vom Absender. Gold an Twinks bleibt Umbuchung.
- **Anfangsbestand**: je Charakter, wie bisher zum Marktwert beim Start.
- **„Alle Charaktere“**: Posten aller Charaktere zusammen (Kosten Ø gewichtet, Lagerwert = Summe).
- **Buch und Gegenstände** mit „Nur dieser Charakter“ rechnen Wareneinsatz und Handelsgewinn mit den eigenen Kosten (KarloDerBaer). Über alle Charaktere bleibt die Summe gleich.
- **Tooltip**: Kosten des eingeloggten Charakters; mit Umschalt je Charakter.
- **Schnittstelle** `mod:Cost(itemID [, Charakter])`: ohne Charakter = eingeloggter Charakter (bisher alle). Broker („Unter deinen Kosten“) nutzt damit automatisch die Kosten des Charakters, der verkauft. `"*"` = alle Charaktere.
- **Übergang**: Ledger rechnet ohnehin aus dem Verlauf neu – nach dem Update einmal neu gerechnet, kein Datenverlust. Vorhandener Stand in `lotBase` (gibt es erst nach 90 Tagen) wird ab dann je Charakter gespeichert.
- **Grenze**: Die Gildenbank erfasst Ledger noch nicht (erst testbar mit einer Gildenbank). Eine Accountbank gibt es in Forever vermutlich nicht.

## 7. Bauabschnitte

- **G1 – Kern, API 10: Diagramm-Baustein** (`Peon.NewChart`, eigene Datei Chart.lua, Bestehendes unverändert). Linien, Stufenlinien, gestrichelt, Band/Fläche zwischen zwei Linien (zweifarbig je Abschnitt), Balken, Punkte (Kreis/Quadrat), senkrechte Markierungen, zwei Achsen mit eigener Beschriftung, Legende-Knöpfe an/aus, Mauslinie mit Rückmeldung (`onHover(index)`), mehrere Diagramme verknüpfbar (gleiche Mauslinie, gemeinsamer Maßstab einer Achse). Technik: Linien über `CreateLine` (im Spiel prüfen, sonst schmale gedrehte Texturen); Flächen als senkrechte Streifen je Tag. Test mit lua5.1 und Nachbau.
- **G2 – Broker: Verlauf für Ledger.** Absatz-Tageswerte so lange wie die Preise aufbewahren, danach Wochenwerte. Neue Schnittstelle `mod:History(itemID, Tage)` → je Tag/Woche Min, Median, Menge, Absatz, Bereich unten/oben. Bestehende Daten bleiben.
- **G3 – Ledger: Kosten je Charakter** (Cost.lua, Abschnitt 6), Tooltip, Buch, Gegenstände, Schnittstelle `mod:Cost`. Test gegen eine Kopie der echten SavedVariables (Summe über alle Charaktere gleich wie vorher).
- **G4 – Ledger: Tagesverlauf eines Gegenstands** – beim Nachspielen Tagesstände je Charakter für einen Gegenstand (Bestand, Kosten Ø, Beute, Käufe, Verkäufe); nur auf Anfrage für den gezeigten Gegenstand.
- **G5 – Ledger: Reiter „Gegenstand“** (neue Datei Item.lua) nach Abschnitt 3, Öffnen aus den anderen Reitern, Broker-Knopf „Mehr…“, `/ledger <Name>`.

Reihenfolge: G1 → G2 → G3 → G4 → G5. Nach jedem Abschnitt Version erhöhen und Stand aktualisieren. **WoW komplett neu starten** nach G1 und G5 (neue Dateien).

## 8. Offen (bei der Umsetzung klären)

- ~~Marge im Kasten mit Kosten des nächsten Stücks oder Kosten Ø~~ – nächstes Stück (Umsetzung 06.10.2026), im Spiel prüfen.
- Ob `CreateLine` und `SetVertexOffset` im Forever-Client laufen (sonst Rückfall: Kästchen bzw. Treppe).
- Fensterhöhe: Diagramme passen sich an (mit Marge-Streifen flacher), Fenster bleibt 760 × 500 – im Spiel prüfen.
- Später: offene Einstellgebühren in „Ohne Verlust ab“, Wochensummen (nach 90 Tagen) im Tagesverlauf.
