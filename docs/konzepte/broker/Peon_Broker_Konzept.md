# Peon_Broker – Konzept

Stand: 29.09.2026, **von KarloDerBaer freigegeben**. Umsetzung in Bauabschnitten; der Fortschritt steht in `Peon_Stand.md`.

## Worum es geht

Peon_Broker ist das Auktionshaus-Modul von Peon. Es hilft, mit dem Auktionshaus Gold zu machen und bessere Entscheidungen beim Kaufen und Verkaufen zu treffen. Broker ersetzt Auctionator vollständig. Es soll alles können, was man im Alltag braucht, aber ohne die Überladung von TSM oder Auctioneer.

Broker unterstützt alle üblichen Wege zu Gold:

- Farmgut und Materialien verkaufen
- Berufe (Herstellen und Verkaufen)
- Handel (billig kaufen und teurer verkaufen, auch beim Händler)

## Rahmenbedingungen in WoW Forever

- **Modernes Auktionshaus wie in Retail** (`C_AuctionHouse`). Es gibt zwei Arten von Waren:
  - **Massenware** wie Erze, Kräuter und Stoffe, mit einem Preis je Stück.
  - **Einzelgegenstände** wie Ausrüstung, die einzeln gelistet werden.
- **Keine Realms:** Es gibt ein Auktionshaus je Regelsatz (Normal, PvP, RP, später Hardcore) und Fraktion. Der Markt ist sehr groß, deshalb wird oft stark unterboten.
- **Komplettscan** des ganzen Auktionshauses nur alle 15 Minuten (`ReplicateItems`, gilt für den ganzen Account).
- **Kaufen, Einstellen und Abbrechen nur per Klick** des Spielers. Das Spiel verlangt das, und Peon hält es ohnehin so.
- **Keine fremden Preisdaten:** Es gibt keine offizielle Schnittstelle, und TSM hat keine Forever-Region. Die eigenen Scans sind die einzige Datenquelle.
- **Gebühren:** Einstellgebühr plus Anteil beim Verkauf. Die genauen Werte werden im Spiel geprüft, denn die Online-Angaben widersprechen sich.
- Beta mit Stufe 30 als Obergrenze; der Start ist am 4. November 2026.

## Grundsätze

1. **Nichts automatisch kaufen oder einstellen.** Broker bereitet vor, der Spieler klickt.
2. **Märkte strikt getrennt.** Daten aus verschiedenen Auktionshäusern werden nie vermischt (siehe unten).
3. **Schlank bleiben.** Lieber wenige Funktionen, die gut funktionieren.
4. **Verständlich.** Klare Hinweise wie „lieber beim Händler verkaufen“ statt Zahlenkolonnen ohne Erklärung.
5. **Sparsam speichern.** Preise werden je Tag zusammengefasst und alte Daten verdichtet, damit die Einstellungsdatei klein bleibt.

## Märkte sauber trennen

- **Ein Markt ist Regelsatz plus Fraktion**, zum Beispiel „Classic Beta PvE / Horde“.
- **Erkennung:** Realm-Name aus dem Spiel (`GetRealmName`) und die Fraktion (`UnitFactionGroup`).
  - Im WTF-Ordner heißt der Realm „Classic Beta PvE“. Charaktere haben in Forever Vor- und Nachnamen (z. B. Mirel Dorna). Der Nachname gehört zum Charakter, nicht zum Markt.
  - Der Prüfbefehl bestätigt im Spiel, was `GetRealmName` liefert, bevor das festgeschrieben wird.
- **Je Markt getrennt:** Preisdaten und Preisverlauf, Zeitpunkt des letzten Scans, Einträge im Buch über Käufe und Verkäufe.
- **Gemeinsam für alle Märkte:** Einstellungen, Einkaufslisten (nur die Gegenstände; welche Treffer es gibt, hängt vom aktuellen Markt ab) und gemerkte Verkaufseinstellungen (Menge, Laufzeit).
- **Tooltip und Fenster** zeigen immer nur den Markt des aktuellen Charakters. Gibt es für ihn keine Daten, steht dort „Keine Preisdaten für diesen Markt“.
- **Beta und Start:** Beta-Daten landen durch den anderen Realm-Namen automatisch in einem eigenen Markt. Ein Knopf löscht Märkte, die nicht mehr gebraucht werden.
- **Neutrales Auktionshaus:** Ob es in Forever eines gibt, zum Beispiel in Beutebucht, wird geprüft. Falls ja, wird es ein eigener Markt.

## Aufbau

**Eigenes Broker-Fenster** mit Reitern. Es dockt beim Auktionshaus rechts an und lässt sich mit `/broker` auch ohne Auktionshaus öffnen. Wir bauen nicht in Blizzards Auktionshausfenster hinein, weil das bei Client-Updates schneller kaputtgeht.

| Reiter | Inhalt | Braucht Auktionshaus | Stufe |
|---|---|---|---|
| Verkaufen | Taschenliste, Preisvorschlag, Einstellen per Klick | ja | 1 |
| Meine Auktionen | Unterboten ja/nein, Abbrechen per Klick | ja | 1 |
| Einkaufsliste | Einkaufslisten (ab 0.14 eigener Reiter) | ja | 1 |
| Radar | Schnäppchen (Händler und Markt), Radar-Scan, Bestes kaufen (ab 0.14) | ja | 1 |
| Preise | Gegenstand suchen, Preise und Verlauf ansehen | nein | 1 |
| Buch | Käufe, Verkäufe, Gewinn je Tag und Gegenstand | nein | 1 |

Dazu kommen:

- zwei kleine Knöpfe am Auktionshausfenster: **Scan** (mit Wartezeit bis zum nächsten Scan) und **Broker** (Fenster ein/aus)
- **Preiszeilen im Tooltip** überall im Spiel
- die **Optionsseite** unter Einstellungen > AddOns > Peon > Broker

## Funktionen – Stufe 1 (erste Version)

1. **Preisdatenbank:** Mit dem Scan-Knopf liest Broker das ganze Auktionshaus ein und speichert je Gegenstand und Tag:
   - den niedrigsten Preis
   - einen typischen Preis (Durchschnitt der günstigen Angebote, damit einzelne Mondpreise nicht zählen)
   - die angebotene Menge

   Tageswerte werden etwa 30 Tage aufbewahrt (einstellbar), danach zu Wochenwerten verdichtet.
2. **Preise im Tooltip** (Aufbau mit KarloDerBaer abgestimmt, 29.09.2026; Werte je Stück, mit Umschalt für den ganzen Stapel, Geld mit Münzsymbolen):
   - Ab 0.5.0: Werte immer für den ganzen Stapel; ohne Umschalt nur Zeile 1 (mit dezentem Hinweis „(Umschalt)“), mit Umschalt alle Zeilen
   - Zeile 1: „Broker“ und der bessere Wert: „AH: …“ = Erlös aus dem Preisvorschlag (siehe unten) nach 5 % Anteil und Einstellgebühr (24 Std.), mit Trend; „~“ solange die Einstellgebühr nur geschätzt ist – oder „Händler: …“, wenn der Händler mehr zahlt
   - Zeile 2: Anzahl Angebote, **geschätzter Abverkauf je Stunde** (aus zwei Scans höchstens 24 Std. auseinander: was je Preisstufe verschwunden ist; Angebote kurz vor Ablauf zählen nicht), Alter des Scans
   - Zeile 3: AH Min und Durchschnitt (typischer Preis)
   - Zeile 4: 7 Tage: Mittel der täglichen Tiefstpreise und der typischen Preise
   - Zeile 5: Hinweise – „Günstigstes Angebot weit unter Durchschnitt“, „Wenig Angebote (weniger als 5)“, „Preisdaten älter als 3 Tage“, „Zurzeit keine Angebote“; darunter klein der Händlerpreis (nur wenn Zeile 1 den AH-Wert zeigt)
   - **Trend** in fünf Stufen hinter jedem Wert (Zeilen 1–3: gegenüber dem vorherigen Scan, Zeile 4: gegenüber den 7 Tagen davor): ↑ stark gestiegen (dunkelgrün), ↗ gestiegen (hellgrün), blauer Balken gleich (Standard ±5 %), ↘ gefallen (orange), ↓ stark gefallen (rot, Standard ab ±20 %); Grenzen einstellbar
3. **Verkaufen:** Gegenstand aus der Tasche anklicken, Broker schlägt einen Preis vor (Regeln siehe „Preisvorschlag beim Verkaufen“).
   - Warnungen sind gut sichtbar, der Grund steht dabei.
   - Angezeigt wird der Erlös nach Gebühren im Vergleich zum Händlerpreis.
   - Menge und Laufzeit werden je Gegenstand gemerkt.
   - Einstellen per Klick; der vorgeschlagene Preis lässt sich vorher von Hand ändern.
4. **Meine Auktionen:** Liste der eigenen Auktionen mit Hinweis „unterboten“. Abbrechen mit einem Klick je Auktion, dabei wird die verlorene Einstellgebühr angezeigt.
5. **Einkaufslisten:**
   - Listen mit Gegenständen und einem Höchstpreis je Gegenstand
   - Broker sucht die ganze Liste auf einmal
   - Treffer unter dem Höchstpreis werden hervorgehoben
   - Kaufen per Klick
6. **Händler-Schnäppchen:** Nach einem Scan listet Broker Angebote auf, die billiger sind als ihr Händlerpreis, sortiert nach Gewinn. Kaufen per Klick, danach beim Händler verkaufen.
7. **Preise ansehen:** einen Gegenstand suchen und niedrigsten Preis, Durchschnitt, Menge und den Verlauf der letzten Tage als Liste sehen.
8. **Buch über Käufe und Verkäufe:** Broker erfasst Verkäufe, abgelaufene Auktionen und Käufe über Post und Auktionshaus. Das Buch zeigt:
   - den Gewinn je Tag und je Gegenstand
   - wie oft sich ein Gegenstand wirklich verkauft (Verkaufsquote)
   - die bezahlten Gebühren, auch verlorene Einstellgebühren
9. **Minimap-Button:** Linksklick öffnet das Broker-Fenster, Rechtsklick die Optionen. Der Tooltip zeigt Markt und Alter des letzten Scans. Der Button kommt als Baustein in den Kern (siehe Technik).

## Preisvorschlag beim Verkaufen

Broker schlägt nie einen Preis vor, bei dem nach allen Gebühren weniger übrig bleibt als der Händlerpreis.

1. **Normalfall:** günstigstes Angebot minus Unterbieten-Betrag.
   - Der Betrag ist einstellbar, als fester Betrag oder in Prozent.
   - Standard ist 1 Kupfer.
2. **Günstigstes Angebot unrealistisch tief** (mehr als x % unter dem Durchschnitt, x einstellbar):
   - Broker zeigt eine Warnung.
   - Der Vorschlag ist der Durchschnittspreis minus Unterbieten-Betrag.
3. **Untergrenze:** Liegt der Vorschlag unter dem Mindestpreis, schlägt Broker den Mindestpreis vor und zeigt die Warnung „lohnt sich nicht – lieber beim Händler verkaufen“.
   - Mindestpreis = Preis, bei dem **Erlös nach Einstellgebühr und Verkaufsanteil ≥ Händlerpreis** ist.
   - Rechnung je Stück: Mindestpreis = (Händlerpreis + Einstellgebühr je Stück) ÷ (1 − Verkaufsanteil), aufgerundet.
   - Die Einstellgebühr hängt von Laufzeit und Menge ab. Broker fragt sie möglichst beim Spiel ab (`C_AuctionHouse.CalculateCommodityDeposit` bzw. `CalculateItemDeposit`, im Spiel zu prüfen).
4. **Keine Preisdaten** (Gegenstand nicht im Auktionshaus): Vorschlag ist der Durchschnitt aus früheren Tagen. Gibt es keinen, steht dort „kein Vergleich – Preis selbst festlegen“, mindestens aber der Mindestpreis.
5. **Gegenstände ohne Händlerpreis:** Die Untergrenze deckt dann nur die Gebühren ab.

## Funktionen – Stufe 2 (späterer Ausbau)

10. **Preisentwicklung:** Trend (steigend oder fallend), bester Wochentag zum Verkaufen, kleine Verlaufsgrafik im Reiter „Preise“.
11. **Berufe:** Materialkosten gegen Verkaufspreis im Berufsfenster, mit Hinweis „lohnt sich / lohnt sich nicht“.
12. **Post leeren:** alle Auktionshaus-Post per Klick einsammeln.

## Bewusst nicht dabei

- automatisches Kaufen, Einstellen oder Abbrechen (vom Spiel verboten und gegen die Peon-Regeln)
- ein dauernder Schnäppchenjäger im Hintergrund (der Radar-Scan ab 0.14 läuft nur, solange der Reiter „Radar“ offen ist; gekauft wird nur per Klick)
- Preisformeln und Regelwerke wie bei TSM
- das Hochladen von Daten zu Webseiten
- Entzauberungswerte, weil dafür große Tabellen gepflegt werden müssten
- Bieten auf Auktionen (nur Sofortkauf)

## Einstellungen (Vorschlag)

- Unterbieten um: fester Betrag oder Prozent (Auswahlliste plus Wert), Standard 1 Kupfer
- Standard-Laufzeit (Auswahlliste)
- „Unrealistisch tief“ ab x % unter Durchschnitt
- Minimap-Button anzeigen
- Tooltip: welche Zeilen angezeigt werden
- Datenaufbewahrung in Tagen
- Broker-Fenster beim Öffnen des Auktionshauses automatisch zeigen
- Märkte verwalten: Liste der Märkte mit Datenumfang und Knopf zum Löschen

## Technik

- Addon `Peon_Broker`, Abhängigkeit zu Peon, erstellt aus `vorlage\Peon_Beispiel`
- SavedVariables `PeonBrokerDB` (accountweit, mit den Märkten als Unterbereiche)
- Befehle `/broker` und `/peon broker`
- **Kern-Erweiterung (API 7), nur Ergänzungen, bestehende Aufrufe bleiben unverändert:**
  - eine Liste mit Bildlauf und Spalten, die auch andere Module nutzen können (z. B. die Fangübersicht in Fishing)
  - ein Minimap-Button-Baustein: Symbol, Links-/Rechtsklick, Tooltip, verschiebbar, Position gespeichert. Fishing behält vorerst seinen eigenen Button; eine spätere Umstellung wäre eine eigene Entscheidung.
- Scan-Auswertung in kleinen Portionen, damit das Spiel nicht stockt
- Tests mit nachgebauter `C_AuctionHouse`-Schnittstelle in lua5.1

## Erster Schritt: Prüfbefehl

Bevor die eigentliche Arbeit beginnt, gibt es eine kleine erste Version mit `/broker pruefen`. Sie zeigt im Spiel:

- Realm-Name und Fraktion, also den späteren Markt-Schlüssel
- welche Auktionshaus-Funktionen der Client 16001 hat (Scan, Suchen, Kaufen, Einstellen, Abbrechen, Gebühren)
- ob das Auktionshaus-Fenster das moderne `AuctionHouseFrame` ist
- die Ergebnisse als Debug-Log in den SavedVariables, damit sie ausgewertet werden können

## Bauabschnitte (Vorschlag)

Stufe 1 ist groß, deshalb wird sie in Abschnitten gebaut. Nach jedem Abschnitt ist Broker im Spiel testbar, und die Version wird erhöht.

1. **Prüfbefehl** `/broker pruefen` (Version 0.1)
2. **Kern API 7:** Liste mit Bildlauf und Minimap-Button-Baustein
3. **Scan, Preisdatenbank und Tooltip-Preise**, mit Markttrennung
4. **Broker-Fenster** mit Reiter „Preise“ und Minimap-Button – umgesetzt in 0.7.0
5. **Verkaufen** mit Preisvorschlag – umgesetzt in 0.8.0 (Entwurf `Peon_Broker_Verkaufen.md`)
6. **Meine Auktionen** – umgesetzt in 0.12.0
7. **Einkaufen:** Einkaufslisten und Händler-Schnäppchen – umgesetzt in 0.13.0 (allgemein „Schnäppchen“, `Peon_Broker_Einkaufen.md`); ab 0.14.0 zwei Reiter „Einkaufsliste“ und „Radar“
8. **Buch** über Käufe und Verkäufe (Version 1.0)

## Beschlossen im Gespräch (29.09.2026)

- Broker ersetzt Auctionator vollständig.
- Eigenes Fenster statt Reiter im Auktionshausfenster.
- Märkte strikt getrennt (Regelsatz plus Fraktion).
- Unterbieten einstellbar, Standard 1 Kupfer.
- Preisvorschlag mit Untergrenze „Erlös nach Gebühren ≥ Händlerpreis“, bei unrealistisch tiefem Angebot Warnung und Vorschlag auf Basis des Durchschnitts.
- Minimap-Button ja, als Baustein im Kern.
- Das Buch über Käufe und Verkäufe gehört zu Stufe 1.

## Offene Fragen

- Keine. Bauabschnitt 1 (Prüfbefehl) ist als Version 0.1.0 umgesetzt; die Ergebnisse aus dem Spiel entscheiden über Details der nächsten Abschnitte.
