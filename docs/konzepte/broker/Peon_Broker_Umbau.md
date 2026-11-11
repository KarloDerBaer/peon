# Peon_Broker: Konzept Umbau

Stand: 09.11.2026, **freigegeben von KarloDerBaer** (Abschnitt 14). U0 gebaut mit Broker 0.41.0, Prüfung im Spiel steht aus. Ausgangsversion Broker 0.40.0.

**Hinweis (11.11.2026):** Die Abschnitte 7 (Im Auktionshaus), 8 (Broker-Fenster) und 15 (Reiter Markt) sind durch `Peon_Broker_Neuaufbau.md` ersetzt. Die übrigen Abschnitte gelten weiter.

## 1. Worum es geht

Broker soll schlank werden und sich auf Informationen konzentrieren. Erleichterungen wie Einkaufsliste und Radar bleiben. Die Arbeit teilt sich künftig klar auf (KarloDerBaer):

- **Im Auktionshaus (Blizzard-Fenster):** alles, was ein offenes Auktionshaus braucht. Verkaufen, Meine Auktionen, Radar, Einkaufen.
- **Im Broker-Fenster:** alles, was auch ohne Auktionshaus geht. Einkaufslisten, Marktübersicht, Händler, Quellen, Gegenstände, Beobachtung. Das Broker-Fenster ist damit das **schlanke Gegenstück zum Modul Peon Broker Client im Manager**: gleiche Begriffe, gleicher Aufbau, aber ohne die umfangreichen Auswertungen.
- **Im Tooltip:** frei einstellbar, auf Wunsch mit kleinem Preisdiagramm.
- **Am Gegenstand selbst:** ein Kontextmenü mit Strg+Rechtsklick, überall wo ein Gegenstand ist (Taschen, Bank, Händler, Quest, Beute, Chat). Es gehört zum Kern, alle Peon-Module können Einträge anhängen (Abschnitt 9).
- **Alles im Look des Blizzard-Auktionshauses**, auch das Broker-Fenster (KarloDerBaer).
- **Notausgang:** Ein Knopf im Auktionshaus schaltet auf Blizzards Fenster ohne Broker um, falls nach einem Update etwas blockiert (7.7).

Leitfrage für alles: Was will ich in diesem Moment wissen, und mit wie wenig Klicks komme ich ans Ziel?

## 2. Befund

### 2.1 Falsche Preise nach dem Scan im neutralen Haus

Nachgesehen in den gespeicherten Daten von Broker (09.11.2026):

| Markt | Gegenstände | Stand |
|---|---|---|
| PvE Allianz | 19.678 | eigener Scan 08.11. 23:08, Blizzard-API über den Manager 09.11. 12:12 |
| PvE Neutral | 1.852 | eigener Scan 09.11. 12:59 |

- **Die Daten sind sauber getrennt.** Nichts vom neutralen Haus ist im Allianz-Markt gelandet.
- **Die Ursache liegt in der Regel aus Broker 0.40.0:** Solange das neutrale Auktionshaus offen ist, gilt in Broker überall der neutrale Markt. Das betrifft nicht nur den Verkauf, sondern auch Tooltip, Wert für Ledger, Berufsfenster und Radar. Wer in Beutebucht scannt und dabei Tooltips ansieht, bekommt neutrale Preise.
- **Neutral ist meist teurer:** Von 1.752 Gegenständen, die in beiden Märkten vorkommen, liegt das günstigste Angebot bei 1.139 (65 %) im neutralen Haus mehr als 10 % höher, nur bei 331 niedriger.
- **Zweites Problem, bisher unbemerkt:** Broker rechnet den Erlös überall mit 5 % Anteil des Auktionshauses (`D.CUT`). Im klassischen Spiel nahm das neutrale Haus deutlich mehr. Wie viel es in Forever ist, wissen wir nicht. Prüfen lässt sich das mit einer Verkaufsrechnung aus der Post (Ledger liest den Anteil schon mit).

### 2.2 Warum das Blizzard-Fenster gewinnt (von KarloDerBaer bestätigt)

- **Zweites Fenster:** Man steht ohnehin im Blizzard-Fenster, der Blick springt hin und her.
- **Zu viele Klicks:** Reiter wählen, Gegenstand in Brokers Liste suchen.
- **Liste statt Taschen:** Lieber direkt in der Tasche auf den Gegenstand klicken, den man verkaufen will.
- **Werte unklar:** Viele Zahlen, man sieht nicht sofort, ob der Preis passt.
- **Langsam oder hakelig:** Warten auf Werte, Preis wird überschrieben, Einstellen klappt nicht immer.

Und der wichtigste Satz: Blizzard trägt ohnehin das günstigste Angebot als Preis ein. **Brokers Aufgabe ist nicht, einen Preis einzutragen, sondern zu sagen, ob man zu diesem Preis überhaupt verkaufen soll.**

### 2.3 Tooltip heute

Ohne Umschalt eine Zeile, mit Umschalt bis zu 12 Zeilen: Angebote, AH Min/Median mit zwei Trends, 7 Tage Min/Median mit zwei Trends, üblicher Bereich, Absatz, eigene Verkäufe, Herstellen, Vorschlag, Einstellgebühr, Händler, dazu bis zu drei Hinweise. Viele Zeilen sagen fast dasselbe, und bis zu fünf Trend-Pfeile machen es unruhig.

## 3. Grundsätze

1. **Heimatmarkt zuerst.** Angezeigt wird immer der Markt der eigenen Fraktion. Das neutrale Haus erscheint als zusätzliche Zeile, im Vergleich und beim Handeln im neutralen Haus selbst.
2. **Dort helfen, wo die Hand ist.** Verkaufen passiert im Blizzard-Fenster, ausgewählt wird in der Tasche. Broker ergänzt das, statt es zu ersetzen, und fasst Blizzards Preis nicht an.
3. **Broker berät.** Er sagt „verkaufen“, „lieber warten“, „kaufen“ oder „zu teuer“ und warum.
4. **Eine Antwort statt vieler Zahlen.** Farbe trägt die Bewertung: grün gut, orange abwarten, rot schlecht, grau keine oder alte Daten. Höchstens ein Trend-Pfeil je Anzeige.
5. **Schnell und flüssig im Auktionshaus.** Kein Warten auf Broker, Listen sofort aus dem letzten Stand, live nachgeprüft im Hintergrund.
6. **Aussehen wie das Auktionshaus, Inhalt wie der Manager.** Alle Broker-Fenster nutzen Rahmen, Reiter, Listen und Schrift des Blizzard-Auktionshauses. Namen, Spalten und Farben sind dieselben wie im Manager, damit man sich in beiden zurechtfindet.
7. **Eingestellt, gekauft und abgebrochen wird nur per Klick des Spielers** (auch technisch nötig).

## 4. Aufteilung im Überblick

| Heute (Broker-Fenster) | Künftig | Wo |
|---|---|---|
| Start | entfällt | |
| Verkaufen | Rat im Verkaufsfenster (7.2) | Auktionshaus |
| Behalten | **entfällt ganz** (KarloDerBaer): Verkauft wird nicht mehr halb automatisch, also braucht es keine Sperrliste | |
| Meine Auktionen | Erweiterung von Blizzards Reiter „Auktionen“ (7.3) | Auktionshaus |
| Einkaufsliste | Verwalten im Fenster (8.2), Kaufen im Auktionshaus (7.5) | beides |
| Radar | eigener Reiter im Auktionshaus (7.4) | Auktionshaus |
| Preise | Gegenstände (8.6) | Fenster |
| neu | Marktübersicht (8.3), Händler (8.4), Quellen (8.5), Beobachtung (8.7) | Fenster |
| neu | Kontextmenü auf Gegenständen (9) | überall |
| neu | Knopf „Blizzard pur“ (7.7) | Auktionshaus |
| Scan-Knopf | bleibt am Auktionshaus | Auktionshaus |
| Berufsfenster | bleibt wie es ist | Berufsfenster |

Das Broker-Fenster öffnet sich nicht mehr mit dem Auktionshaus. Der Knopf „Broker“ am Auktionshaus entfällt, weil dort alles in Blizzards Reitern steckt.

## 5. Märkte: Heimatmarkt und Neutral

### 5.1 Zwei Fragen statt einer

Heute gibt es eine einzige Frage „welcher Markt gilt?“ (`ns.MarketKey()`), deren Antwort sich mit dem offenen Auktionshaus ändert. Künftig zwei:

| Frage | Antwort | Wer nutzt sie |
|---|---|---|
| **Heimatmarkt** | immer eigene Fraktion | Tooltip, Wert für Ledger, Berufsfenster, Broker-Fenster |
| **Markt am offenen Haus** | Neutral in Beutebucht, sonst Heimat | Scan, Live-Abfragen, alles in den Reitern des Auktionshauses |

Gespeichert wird wie bisher getrennt je Markt.

### 5.2 Neutral im Tooltip

- Zeile „Neutral: ab X (+35 %)“. Der Prozentwert vergleicht mit dem Heimatmarkt, grün wenn es sich lohnt, dort zu verkaufen (nach Gebühren).
- **Einstellbar: immer, nur im erweiterten Tooltip (Standard) oder aus** (KarloDerBaer).
- Die Zeile erscheint erst, wenn es für den neutralen Markt Daten gibt (KarloDerBaer).

### 5.3 Gebühren am neutralen Haus

Erst messen, dann rechnen: Nach dem ersten Verkauf in Beutebucht zeigt die Rechnung in der Post den Anteil. Danach bekommt jeder Markt seinen eigenen Satz statt der festen 5 %. Bis dahin steht beim Neutral-Erlös „Gebühr ungeprüft“.

## 6. Tooltip

### 6.1 Was brauche ich wirklich?

| Frage | Zeile |
|---|---|
| Was ist das wert? Lohnt AH oder Händler? | Zeile 1 (Wert), Händler nur wenn er gewinnt |
| Ist jetzt ein guter Zeitpunkt? | Farbe und ein Wort in Zeile 1 |
| Beobachte ich das, steht es auf einer Einkaufsliste? | ein kleines Zeichen in Zeile 1 |
| Wie sicher ist der Preis? | Markt (Menge und Alter) |
| Was ist normal? | Üblich |
| Verkauft sich das? | Absatz |
| Was trage ich ein? | Einstellen |
| Wie lief der Preis? | Diagramm (6.4) |

### 6.2 Vorgabe

Ohne Umschalt:

```
Broker                 18g 40s  (20 × 95s)  ↗        <- grün/orange/rot, ein Pfeil
```

Mit Umschalt:

```
Broker                 18g 40s  (20 × 95s)  ↗
Markt          ab 95s · 1.240 Stück · vor 12 Min.
Üblich         90s bis 1g 05s
Absatz         etwa 300 am Tag
Einstellen     95s je Stück, Erlös 18g 05s (8 Std.)
Händler        5c je Stück
Neutral        ab 1g 30s (+37 %)
Herstellen     Gewinn 4g 20s
Deine Verkäufe 4 von 6 (67 %)
[ kleines Preisdiagramm, 14 Tage ]
Dumping: günstigstes Angebot weit unter dem üblichen Bereich.
```

- Zeile 1: Erlös für den Stapel und dahinter der Preis je Stück (KarloDerBaer). Bei einem Stück nur der Preis.
- Zeilen ohne Daten fehlen einfach (Händler 0, kein Rezept, keine neutralen Daten).
- Höchstens ein Hinweis, der wichtigste.
- „Client“ verschwindet aus den Texten.

### 6.3 Frei einstellbar (KarloDerBaer)

Auf der Optionsseite eine Liste aller Bausteine. Je Baustein:

| Einstellung | Auswahl |
|---|---|
| **Wann** | immer / mit Umschalt / aus |
| **Reihenfolge** | Pfeile hoch und runter (oder Ziehen) |
| **Format** | je nach Baustein, siehe unten |

| Baustein | Formate zur Wahl |
|---|---|
| Wert (Zeile 1) | Stapel und je Stück / nur Stapel / nur je Stück, Pfeil an/aus, Erlös nach Gebühr oder Angebotspreis |
| Markt | günstigstes Angebot / Median / beides, Menge an/aus, Alter an/aus |
| Üblich | Bereich „von bis“ / Mitte / Mitte mit Abstand in % zum jetzigen Preis |
| Absatz | am Tag / je Stunde |
| Einstellen | Vorschlag / Vorschlag und Erlös / mit Gebühr |
| Händler | je Stück / für den Stapel |
| Neutral | Preis / Preis und Unterschied in % |
| Herstellen | Gewinn / Kosten und Gewinn |
| Deine Verkäufe | Anzahl / Quote |
| Zeichen Beobachtung/Einkaufsliste | an/aus |
| Diagramm | Zeitraum 7/14/30 Tage, Linien (siehe 6.4), Größe klein/mittel |
| Hinweis | an/aus |

- Darüber drei Vorlagen zum Anklicken: **Schlank** (nur Zeile 1), **Standard** (6.2), **Ausführlich** (alles). Danach frei änderbar.
- Eine kleine Vorschau neben der Liste zeigt den Tooltip mit Beispielwerten, so sieht man sofort, was man einstellt.
- Gespeichert als geordnete Liste `tooltipLayout = { { key, when, fmt }, ... }`. Neue Bausteine späterer Versionen hängen sich hinten an (aus).

### 6.4 Diagramm im Tooltip

**Technisch möglich.** Blizzard hat dafür in der Forever-Version die Funktion `GameTooltip_InsertFrame` (nachgelesen in `Blizzard_SharedXML/SharedTooltipTemplates.lua`, Zweig `forever`). Sie macht im Tooltip Platz und hängt einen eigenen Rahmen ein. Für das Diagramm selbst gibt es den Kern-Baustein `Peon.NewChart` (API 10), den Ledger schon nutzt.

```
Broker                 18g 40s  (20 × 95s)  ↗
  1g10 ┤      ╭─╮
       │  ░░░░│░│░░░░░░░░░░░░   <- Band: üblicher Bereich
   90s ┤──╯   ╰─╰──────╮
       └──────────────────┘
        vor 14 Tagen     heute
```

- Linien zur Wahl: günstigstes Angebot (Standard), Median, üblicher Bereich als Fläche, Menge als Balken. Vorgabe: günstigstes Angebot und Band, ohne Achsenbeschriftung, nur Höchst- und Tiefstwert.
- Größe etwa 200 × 60 Punkte (klein) oder 260 × 90 (mittel).
- **Daten:** Broker hat je Gegenstand Tageswerte für die eingestellte Aufbewahrung (Standard 30 Tage). Das reicht für 7 bis 30 Tage. Stündliche Werte gibt es nur im Manager (siehe 10.3).
- **Leistung:** Ein Rahmen für alle Tooltips, gezeichnet nur, wenn der Gegenstand wechselt. Blizzard baut Tooltips im Auktionshaus alle 0,2 Sek. neu auf, dabei nur einhängen, nicht neu rechnen.
- **Vorgabe: nur mit Umschalt**, damit der normale Tooltip klein bleibt.
- Zu prüfen im Spiel: Verträgt sich das mit Peon_Tooltip (eigener Umbruch, Breite) und mit Vergleichs-Tooltips?

## 7. Im Auktionshaus

### 7.1 Eigene Reiter im Blizzard-Fenster

Blizzard hat unten die Reiter Kaufen, Verkaufen, Auktionen. Dazu kommen **Radar** und **Einkaufen** im gleichen Stil (`AuctionHouseFrameTabTemplate`). Ein Klick blendet Blizzards Inhalt aus und Brokers Inhalt im selben Rahmen ein. Listen bauen auf Blizzards Vorlagen für Tabellen auf (Kopfzeile, Zeilenhöhe, Hervorhebung), damit sie aussehen wie Blizzards Kaufliste.

**Größtes Risiko des Umbaus:** Blizzard steuert die Ansicht über `AuctionHouseFrame:SetDisplayMode` und die Tabelle `AuctionHouseFrameDisplayMode`. Wer dort eigene Einträge hinzufügt, kann Blizzards Kauf- und Verkaufsknöpfe „verunreinigen“ (Taint), dann kommt beim Kaufen „Aktion wegen AddOn blockiert“. Darum ist **der erste Bauschritt ein Prüfaufbau** (12, U0): zwei leere Reiter, umschalten, danach mit Blizzards Knöpfen kaufen und einstellen. Erst wenn das ohne Fehler geht, wird darauf gebaut. Rückfall: Brokers Inhalt als Seitenfenster bündig am Auktionshaus, mit eigenen Reitern oben.

### 7.2 Verkaufen

Ablauf wie gewohnt: Gegenstand in der Tasche anklicken, Blizzard legt ihn ins Verkaufsfenster und trägt das günstigste Angebot als Preis ein. **Broker ändert daran nichts** (KarloDerBaer). Er sagt nur, ob man zu diesem Preis verkaufen soll.

Ein Kasten am Blizzard-Verkaufsfenster, oben groß das Urteil, darunter ein Satz, warum:

```
┌ Broker ─────────────────────────────────────┐
│ VERKAUFEN                           (grün)  │
│ Der Preis liegt im üblichen Bereich.         │
│                                              │
│ Üblich   90s bis 1g 05s                      │
│ Absatz   etwa 300 am Tag                     │
│ Erlös    18g 05s für 20 (Händler 20s)        │
└──────────────────────────────────────────────┘
```

Das Urteil gilt für den Preis, **der gerade im Blizzard-Feld steht**. Ändert man ihn von Hand, rechnet Broker sofort neu.

| Urteil | Farbe | Wann | Satz (Beispiele) |
|---|---|---|---|
| **Verkaufen** | grün | Preis im üblichen Bereich oder darüber | „Der Preis liegt im üblichen Bereich.“ |
| **Lieber warten** | orange | deutlich unter dem üblichen Bereich, der Markt fällt aber nicht dauerhaft | „30 % unter dem Üblichen. Jemand verkauft gerade billig.“ |
| **Verkaufen, Preis fällt** | gelb | seit mehreren Scans unter dem Bereich (neues Preisniveau) | „Der Preis fällt seit 2 Tagen. Warten bringt eher weniger.“ |
| **Lieber zum Händler** | rot | Erlös nach Gebühr unter dem Händlerpreis | „Der Händler zahlt 20s, hier bekämst du nur 15s.“ |
| **Keine Einschätzung** | grau | zu wenig oder zu alte Daten | „Noch zu wenig Preisdaten für eine Einschätzung.“ |

- Grundlage sind die Angebote, die Blizzard für das Verkaufsfenster ohnehin lädt. Broker schickt keine eigene Suche ab und schreibt nichts in Blizzards Felder.
- Am neutralen Haus gilt alles für dieses Haus, mit dessen Gebühr.
- Später: derselbe Rat als kleine Markierung in den Taschen (Peon_Bags), weil dort ausgewählt wird.

### 7.3 Auktionen (Blizzards Reiter erweitert)

Blizzards Liste „Auktionen“ bleibt. Broker ergänzt (KarloDerBaer):

```
Auktionen   12 laufen · 3 unterboten · Wert 140g 20s          [Prüfen]
Gegenstand          Preis      Restzeit   Broker
Robuster Stein x20  95s        7 Std.     Günstigstes          (grün)
Leinenstoff x40     12s        2 Std.     unterboten: 10s      (orange)
Werwolf-Weste       20s        23 Std.    3. Platz, 18s        (orange)
Arkaner Kristall    4g 50s     1 Std.     zu teuer: Üblich 4g  (rot)
```

- **Kopfzeile:** Zahl der Auktionen, wie viele unterboten, Gesamtwert.
- **Spalte „Broker“** je Zeile: „Günstigstes“, „unterboten: X“ (günstigstes fremdes Angebot), Platz in der Preisliste, oder „zu teuer“, wenn der eigene Preis über dem üblichen Bereich liegt und sich lange nichts verkauft.
- **Knopf „Prüfen“:** fragt alle eigenen Gegenstände live ab (rund 90 je Minute, das reicht für normale Mengen). Ohne Klick gilt der letzte Stand.
- Klick auf eine Zeile wie bei Blizzard (Abbrechen). Abbrechen und neu einstellen bleiben Klicks des Spielers.
- Technik: Blizzards Zeilen werden beim Anzeigen um eine Textspalte ergänzt (Rückruf der Bildlaufliste), nicht ersetzt.

### 7.4 Radar

Eigener Reiter im Auktionshaus, aufgebaut wie Blizzards Kaufliste, ausgelegt auf schnelle Reaktion (KarloDerBaer).

```
Radar  [Händler + Markt v]  [ab 50s Gewinn v]           Scan: läuft ●   [Stopp]
 •  Gegenstand              Preis     Menge   Ziel       Gewinn    Alter
 ●  Robuster Stein          60s       40      95s        14g 00s   jetzt
    Leinenstoff             5s        200     12s        14g 00s   2 Min.
    Werwolf-Weste           9s        1       20s        11s       5 Min.
──────────────────────────────────────────────────────────────────────────
 Robuster Stein: 40 Stück zu 60s = 24g 00s            [ Kaufen 40 ]
 Gewinn beim Weiterverkauf etwa 14g 00s (Üblich 90s bis 1g 05s)
```

- **Treffer-Zahl am Reiter:** Findet ein Komplettscan Treffer, steht am Reiter „Radar (3)“, und der Reiter blinkt, bis man ihn öffnet (KarloDerBaer). Gleiches bei neuen Treffern aus dem Radar-Scan, während ein anderer Reiter offen ist.
- **Sofort da:** Beim Öffnen stehen die Treffer aus dem letzten Stand sofort in der Liste, die Live-Prüfung läuft im Hintergrund. Was weg ist, wird grau und verschwindet nach 30 Sek. (wie heute).
- **Ein Klick wählt, ein Klick kauft:** Zeile anklicken, unten erscheint die Kaufzeile mit Menge, Preis und Gewinn. Der Kauf-Knopf steht immer an derselben Stelle, auch die Bestätigung bei Massenware erscheint dort. So bleibt die Maus an einem Platz.
- **Tastenbelegung** (neu, optional): „Radar: Treffer kaufen“ und „Radar: nächster Treffer“. Tastendruck zählt für das Spiel wie ein Klick.
- **Nach dem Kauf** springt die Auswahl auf den nächsten Treffer.
- Sortierbar nach jeder Spalte, Vorgabe Gewinn.
- Ton und grünes Pulsieren bei neuen Treffern bleiben, wie heute einstellbar.
- Weniger Spalten als heute: Art (Händler oder Markt) steckt im Symbol vor dem Namen.

### 7.5 Einkaufen

Eigener Reiter im Auktionshaus für die Einkaufslisten und die Beobachtung (KarloDerBaer): übersichtlich und schnell kaufen, was auf den Listen steht oder einen Preisalarm ausgelöst hat.

```
Einkaufen (5)  [Alle Listen v]  [Nur kaufbar ☑]                      [Prüfen]
 Gegenstand          Liste       Fehlt   Höchstpreis  Günstigstes  Bis Höchstpreis  Rat
 Robuster Stein      Schmied     60      1g 00s       95s          240 Stück        KAUFEN (grün)
 Schwere Lederhaut   Leder       20      2g 00s       2g 40s       0 Stück          ZU TEUER (rot)
 Leinenstoff         Schneider   100     15s          12s          80 Stück         KAUFEN (grün)
 Eisenbarren         Schmied     10      5g 00s       ?            ?                PRÜFEN (grau)
───────────────────────────────────────────────────────────────────────────────────
 Robuster Stein: 60 Stück, im Schnitt 96s, zusammen 57g 60s       [ Kaufen 60 ]
```

- **Fehlt** = Wunschmenge minus Vorrat aller Charaktere (laut Ledger), siehe 8.2.
- **Rat:** KAUFEN (grün) wenn genug unter dem Höchstpreis da ist, TEILWEISE (gelb) wenn nur ein Teil, ZU TEUER (rot), PRÜFEN (grau) ohne frischen Stand.
- **Sortierbar** nach jeder Spalte (KarloDerBaer), Vorgabe: Rat, dann Ersparnis.
- **Prüfen** fragt alle Listen-Gegenstände live ab. Beim Öffnen sofort der letzte Stand.
- **Kaufen** wie im Radar: Kaufzeile unten, ein Knopf an fester Stelle, kauft „Fehlt“ Stück bis zum Höchstpreis, nie darüber. Danach springt die Auswahl zur nächsten Zeile mit KAUFEN.
- **„Alles Lohnende kaufen“** als Ablauf: Jeder Klick kauft die nächste grüne Zeile (das Spiel erlaubt keinen Kauf ohne Klick).
- Nach dem Kauf zählt Ledger den Vorrat hoch, die Zeile wird „erledigt“ (grau) und rutscht nach unten.
- Gegenstände mit Treffern auf der Einkaufsliste erscheinen weiter auch im Radar (wie heute).

**Beobachtung als eigene Liste** (KarloDerBaer): In der Auswahl oben steht neben den Einkaufslisten „Beobachtung“. Dort stehen alle beobachteten Gegenstände mit Preisgrenze (8.7). Statt „Fehlt“ zählt die Menge, die unter der Grenze angeboten wird. Rat KAUFEN (grün), wenn der Alarm ausgelöst ist. Gekauft wird genauso wie bei den Einkaufslisten, so kann man nach einem Scan oder Alarm gleich zugreifen. „Alle Listen“ zeigt beides zusammen, die Spalte Liste sagt, woher eine Zeile kommt.

**Zahl am Reiter** (KarloDerBaer): „Einkaufen (5)“ zählt alle Zeilen aus Einkaufslisten und Beobachtung, die gerade als KAUFEN oder TEILWEISE gelten. **Ohne Blinken**, anders als beim Radar. Die Zahl steht nach jedem Scan, jedem neuen Stand vom Manager und jeder Live-Prüfung neu.

### 7.6 Scan

Der Knopf für den Komplettscan bleibt am Auktionshaus (oben neben Blizzards Suche), mit Markt und Alter des letzten Stands. Neu: Nach dem Scan meldet er kurz „3 Radar-Treffer, 5 kaufbar“ und setzt die Zahlen an den Reitern.

### 7.7 Notausgang: Blizzard pur

Nach einem Spiel-Update kann es passieren, dass Brokers Einbau Blizzards Kaufen, Verkaufen oder Abbrechen blockiert. Dann hilft ein Knopf (KarloDerBaer):

- **Knopf „Blizzard pur“** klein oben rechts im Auktionshaus. Ein Klick fragt kurz nach und lädt die Oberfläche neu. Danach rührt Broker das Auktionshaus nicht an: keine Reiter, kein Kasten, keine Spalte, keine Anhänge an Blizzards Funktionen. Tooltip, Broker-Fenster und Komplettscan (per `/broker scan`) bleiben.
- **Warum neu laden:** Eine einmal entstandene Verunreinigung (Taint) lässt sich nur durch Neuladen loswerden. Ausblenden allein würde nicht helfen.
- **Zurück:** Im Broker-Fenster, im Menü des Starters und auf der Optionsseite steht „Broker im Auktionshaus wieder an“ (lädt ebenfalls neu). Solange „Blizzard pur“ gilt, erinnert der Starter-Tooltip daran.
- **Von selbst anbieten:** Meldet das Spiel bei offenem Auktionshaus „Aktion wegen AddOn blockiert“ und nennt dabei Peon_Broker (Ereignis `ADDON_ACTION_BLOCKED` oder `ADDON_ACTION_FORBIDDEN`), erscheint ein Hinweis mit demselben Knopf. Der Fehler landet zusätzlich im Fehlerspeicher, damit er im Manager auftaucht.
- Einstellung `ahPlain` (accountweit), bleibt bei „Standardwerte“ erhalten.

## 8. Broker-Fenster (ohne Auktionshaus)

### 8.1 Aufbau

**Look wie das Blizzard-Auktionshaus** (KarloDerBaer): gleicher Rahmen mit Symbol oben links, Reiter unten im Stil von Blizzards Kaufen/Verkaufen/Auktionen, Listen mit Blizzards Kopfzeilen, Zeilen und Hervorhebung, gleiche Schrift und Geldanzeige. Das gilt auch für Brokers Kästen im Auktionshaus und im Berufsfenster.

Technik: Blizzards Vorlagen für das Auktionshaus stehen erst bereit, wenn dessen Oberfläche geladen ist (`Blizzard_AuctionHouseUI` lädt beim ersten Besuch). Broker baut den Look deshalb mit den allgemeinen Bausteinen nach, die immer da sind (Rahmen `ButtonFrameTemplate` wie heute, Grafiken des Auktionshauses über ihre Atlas-Namen). So sieht das Fenster auch vor dem ersten Besuch im Auktionshaus richtig aus. Die Listen werden ein gemeinsamer Baustein für alle Broker-Ansichten (im Kern als Erweiterung von `Peon.NewList`, Stil „Auktionshaus“).

Reiter in dieser Reihenfolge:

| Reiter | Inhalt | Gegenstück im Manager |
|---|---|---|
| Einkaufslisten | Listen anlegen und verwalten (8.2) | Einkaufsliste |
| Markt | Übersicht über den Markt (8.3) | Übersicht |
| Händler | erfasste Händlerwaren (8.4) | neu: Händler |
| Gegenstände | Liste und Detail mit Diagramm (8.6) | Gegenstände, Gegenstand |
| Beobachtung | beobachtete Gegenstände (8.7) | Favoriten, wird Beobachtung |
| Quellen | Datenstand und Herkunft (8.5) | Quellen |

Oben im Fenster: Markt-Auswahl (Heimat oder Neutral), erscheint nur, wenn es Daten für beide gibt. Überall gilt: Klick auf einen Gegenstand öffnet ihn unter Gegenstände, Rechtsklick (und Strg+Rechtsklick) öffnet das Kontextmenü aus Abschnitt 9.

### 8.2 Einkaufslisten

Aufbau der Daten bleibt (abgeglichen mit dem Manager, `Shop.lua` und `shopping.js`): Listen mit Name und Rabatt, je Gegenstand Wunschmenge und optional eigener Höchstpreis. Neu ist die Oberfläche.

```
┌ Listen ─────────────┐┌ Schmied ───────────────────────────── Rabatt 10 % unter Üblich ┐
│ Schmied       3/5   ││ Gegenstand        Ziel  Vorrat  Fehlt  Höchstpreis    Jetzt     │
│ Schneider     1/2   ││ Robuster Stein     100   40      60    1g 00s (Liste) 95s  ●    │
│ Leder         0/1   ││ Eisenbarren         20   20       0    5g 00s (eigen) erledigt  │
│                     ││ Kohle               40    0      40    50s (Liste)    60s  ●    │
│                     ││                                                                  │
│ [+ Neue Liste]      ││ [Gegenstand suchen ...........]  oder Gegenstand hierher ziehen  │
└─────────────────────┘│ Kosten für alles Fehlende etwa 72g 00s                           │
                       └──────────────────────────────────────────────────────────────────┘
```

- **Links die Listen** mit „erledigt/gesamt“. Neu, umbenennen, löschen (Rückfrage), Rabatt der Liste.
- **Rechts die Gegenstände** der gewählten Liste. Ziel, Vorrat, Fehlt, Höchstpreis, jetziger Preis mit Punkt (grün unter Höchstpreis, rot darüber, grau ohne Stand).
- **Ziel statt Kaufmenge** (KarloDerBaer): Man trägt ein, wie viele man haben will. Fehlt = Ziel minus Vorrat aller Charaktere (Ledger, Taschen, Bank, Post). So kauft man nie doppelt. Ohne Ledger gilt Ziel als Kaufmenge.
- **Höchstpreis:** von der Liste („10 % unter Üblich“) oder je Gegenstand fest. Steht dabei, woher er kommt.
- **Hinzufügen:** über das Kontextmenü auf jedem Gegenstand (Abschnitt 9, „Auf Einkaufsliste“ mit Untermenü der Listen), Suchfeld (alle bekannten Gegenstände), Gegenstand aus der Tasche ins Fenster ziehen, und aus dem Berufsfenster „Material auf Einkaufsliste“ (fehlendes Material für N Herstellungen, Vorschlag).
- **Bearbeiten direkt in der Zeile:** Klick auf Ziel oder Höchstpreis macht ein Eingabefeld daraus. Rechtsklick entfernt.
- **Unten** die Kosten für alles Fehlende zum jetzigen Stand.
- Ohne Auktionshaus nur Planung, gekauft wird im Reiter Einkaufen (7.5).
- Der Reiter Einkaufsliste im Manager bekommt denselben Aufbau (Ziel, Vorrat, Fehlt), damit beide gleich sind.

### 8.3 Markt

Zwei Teile (KarloDerBaer):

- **Datenstand oben:** je Markt letzter Scan, letzter Stand vom Manager (API oder Scan), Zahl der Gegenstände und Angebote. Kurz und farbig: grün frisch, orange älter als ein Tag, grau keine Daten. Die Einzelheiten stehen unter Quellen (8.5).
- **Neutral im Vergleich darunter:**

```
Allianz gegen Neutral (Beispielwerte)   [Nur Bestand ☑]  [ab 20 % Unterschied v]
Gegenstand              Allianz ab   Neutral ab   Unterschied   Besser
Arkaner Kristall          4g 00s      21g 70s       +443 %      Neutral
Werwolf-Weste ...        13s 00c      20s 00c        +54 %      Neutral
Robuster Stein            1s 20c       0s 95c        -21 %      Allianz
```

- „Unterschied“ und „Besser“ rechnen mit dem Erlös nach Gebühren beider Häuser.
- „Nur Bestand“ (laut Ledger) zeigt, was man nach Beutebucht mitnehmen sollte.
- Im Manager kommt später dieselbe Ansicht mit Verlauf (KarloDerBaer: beides).
- Nicht dabei: eigener Wert und Bewegungen seit gestern (KarloDerBaer).

### 8.4 Händler (neu)

Alles, was Broker bei Händlern gesehen hat (KarloDerBaer). Heute merkt sich Broker nur den Goldpreis je Gegenstand (`merchant[itemID] = { p, t, w }`). Künftig je Händler alles, was das Händlerfenster zeigt:

| Feld | Woher |
|---|---|
| Händler: Name, NPC-Nummer, Zone, Koordinaten, Fraktion | `UnitName("npc")`, GUID, `C_Map` |
| Ware: Gegenstand, Preis in Gold, Stückzahl je Kauf | `C_MerchantFrame.GetItemInfo` |
| Andere Währung: Abzeichen, Marken, Gegenstände mit Menge | `GetMerchantItemCostInfo` / `GetMerchantItemCostItem` |
| Begrenzte Menge (nur X vorrätig) | `numAvailable` |
| Voraussetzung: Ruf, Rang, Beruf, Stufe | Tooltip des Händler-Angebots (`C_TooltipInfo.GetMerchantItem`), rote Zeilen |
| Zuletzt gesehen | Zeit des Besuchs |

```
Händler (Beispielwerte)  [Suche ..............]  [Alle Zonen v]  [Nur mit AH-Gewinn ☐]
Gegenstand              Preis              Händler              Zone           Voraussetzung   AH
Kräftiges Gewürz        1s 00c             Gretta Fingerfett    Eisenschmiede                  4s 50c  ▲
Muster: Runenstoffbeutel 1g 50s            Qia                  Winterquell    Wohlwollend     35g     ▲
Tabard der Argentum…    25 Zeichen der …   Quartiermeister…     Östliche Pest. Ehrfürchtig     
```

- **Spalte AH:** günstigstes Angebot im Auktionshaus. Ein Pfeil zeigt, wenn man beim Händler kauft und im AH mehr bekommt (das kennt das Radar heute als Händler-Schnäppchen, hier für alles sichtbar).
- Klick auf eine Zeile: alle Händler, die den Gegenstand führen, mit Ort.
- Berufsfenster und Einkaufsliste nutzen die Daten wie heute für den Händlerpreis.
- Der Tooltip bekommt optional einen Baustein „Beim Händler: 1s (Gretta, Eisenschmiede)“.
- **Im Manager:** Die Bridge schickt die Händlerdaten mit (neuer Teil im Kanal broker), der Manager zeigt eine Ansicht „Händler“ mit Suche, Filter nach Zone und dem AH-Vergleich über den Verlauf.
- Händlerdaten gelten für alle Märkte gleich (accountweit), nur der AH-Vergleich hängt vom Markt ab.

### 8.5 Quellen

Wie die Seite Quellen im Manager, schlank:

- Je Markt: letzter eigener Scan, letzter Stand vom Manager (API oder Scan), Zahl der Gegenstände, Live-Abfragen heute.
- Verbindung zum Manager: Kanal freigeschaltet, Werte vom … (Version), wartende Momentaufnahmen (heute `/peon bridge status`).
- Welche Daten wofür: üblicher Bereich und Absatz vom Manager oder selbst gerechnet, wie alt.
- Händler: Zahl der Händler und Waren, ältester Besuch.
- Ein Knopf „An Manager übergeben“ (lädt neu), wenn Momentaufnahmen warten.

### 8.6 Gegenstände

Wie im Manager, aber leichter. **Eine Ansicht für alles zu einem Gegenstand** (KarloDerBaer): Broker zeigt Markt und Verlauf, Ledger liefert Bestand, Kosten und eigene Verkäufe als Abschnitt dazu. Ledgers eigener Reiter Gegenstand entfällt bei dessen Überarbeitung.

- **Liste:** Suche, Filter Massenware/Einzelgegenstände, „nur Bestand“. Spalten: Gegenstand, Günstigstes, Üblich, Trend, Menge, Absatz, Gesehen. Spalten wählbar wie im Manager.
- **Detail** (Klick auf eine Zeile oder „Info“ im Kontextmenü):
  - oben die Werte wie im Tooltip (gleiche Bausteine, alle an)
  - Diagramm mit Zeitraum 7/14/30/90 Tage (so weit Daten da sind): günstigstes Angebot, Median, üblicher Bereich als Fläche, Menge als Balken
  - **Mein Bestand** (aus Ledger, nur wenn geladen): Vorrat je Charakter und Ort, Kosten je Stück, Lagerwert, eigene Verkäufe und Verkaufsquote, Linie „meine Kosten“ im Diagramm
  - Händler, Neutral, Rezepte, die ihn brauchen oder herstellen
- Knöpfe: Beobachten, auf Einkaufsliste, im Auktionshaus suchen (nur bei offenem AH).
- Ohne Ledger fehlt nur der Abschnitt „Mein Bestand“.

### 8.7 Beobachtung (bisher Favoriten)

- Im Manager heißen Favoriten künftig **Beobachtung** (KarloDerBaer), im Spiel genauso.
- Die Liste wird zwischen Spiel und Manager abgeglichen wie die Einkaufslisten (neuere Änderung gewinnt).
- Ansicht wie Gegenstände, nur mit den beobachteten. Dazu je Zeile ein kleines Mini-Diagramm (14 Tage).
- **Preisalarm gleich mit** (KarloDerBaer): je Gegenstand optional eine Grenze („unter 80s“ oder „20 % unter Üblich“). Liegt das günstigste Angebot darunter, gilt der Alarm.
  - Geprüft wird nach jedem Komplettscan, jedem neuen Stand vom Manager und bei Live-Abfragen (Radar, Einkaufen).
  - Meldung einmal je Alarm im Chat und mit Ton (wie beim Radar wählbar), erst wieder, nachdem der Preis über der Grenze lag (wie die frühere Merkliste im Manager).
  - Im Auktionshaus erscheint der Gegenstand im Reiter Einkaufen als kaufbar (7.5).
  - Der Manager kann denselben Alarm später über Windows melden (er hat die stündlichen Stände der API).

## 9. Kontextmenü auf Gegenständen (Kern)

**Strg+Rechtsklick auf einen Gegenstand öffnet ein Menü** (KarloDerBaer), egal wo: Taschen (auch Peon_Bags), Bank, Händler, Quest, Beute, Post, Berufsfenster, Auktionshaus, Chat-Links, Brokers und Ledgers Listen.

```
┌ Robuster Stein ────────────┐
│ Info                        │  -> Broker: Gegenstand (8.6)
│ Beobachten              ✓   │  -> Broker: an/aus, Preisgrenze im Untermenü
│ Auf Einkaufsliste       >   │  -> Broker: Listen, „Neue Liste ...“
│ ─────────────────────────── │
│ Bereich in Peon_Bags    >   │  -> Bags (Beispiel für später)
└─────────────────────────────┘
```

- **Warum nicht Umschalt+Rechtsklick:** Im Blizzard-Code der Forever-Version ist Umschalt+Rechtsklick belegt: auf Stapeln in der Tasche „Stapel teilen“, beim Händler „Mehrere Stapel kaufen“, auf Kisten öffnen (`SPLITSTACK`, `AUTOLOOTTOGGLE`, `EXPANDITEM`). Strg+Rechtsklick löst bei Blizzard nichts aus.
- **Änderbar** (KarloDerBaer): Auf der Peon-Optionsseite eine Auswahl der Maustaste mit Taste (Strg, Umschalt oder Alt mit Rechts, Links oder Mitte), Standard Strg+Rechtsklick. Dazu in Blizzards Tastenbelegungen ein Eintrag „Peon: Gegenstandsmenü“ für eine Tastaturtaste, die das Menü für den Gegenstand unter der Maus öffnet. Mausklicks mit Taste lassen sich in Blizzards Tastenbelegungen selbst nicht vergeben, deshalb beides.
- **Erkennung** wie Ledgers Alt+Klick heute (`Pick.lua`): Mausklick (`GLOBAL_MOUSE_DOWN`) plus Gegenstand im sichtbaren Tooltip, dazu `HandleModifiedItemClick` für Chat-Links. Damit geht es überall, wo ein Gegenstands-Tooltip erscheint. Auf Aktionsleisten nicht.
- **Menü** über Blizzards `MenuUtil.CreateContextMenu` am Mauszeiger, sieht aus wie Blizzards Menüs.
- **Im Kern** (KarloDerBaer): neue Kern-API als Erweiterung, `Peon.API` 16:

```lua
Peon.AddItemMenu(addonName, function(root, item)   -- item = { id, link, key, count, location }
    root:CreateButton("Info", function() ... end)
end, order)
```

  Jedes Modul hängt seine Einträge an, der Kern sammelt sie in fester Reihenfolge (Broker, Ledger, Bags und weitere) mit Trennlinien. Ohne Einträge geht kein Menü auf.
- **Alt+Klick von Ledger entfällt** bei dessen Überarbeitung (KarloDerBaer). Was Ledger noch braucht, kommt ins Menü. Bis dahin bleibt Alt+Klick.

## 10. Daten

### 10.1 Neu in den SavedVariables

- `tooltipLayout` (6.3), ersetzt `tooltipAvg`, `tooltipVendor`, `tooltipHint` (Übernahme beim ersten Start).
- `vendors[npcID] = { n = Name, z = Zone, x, y, t, items = { [itemID] = { p, q, cur, lim, req } } }` (8.4), `merchant` wird daraus abgeleitet und entfällt später.
- `watch[Schlüssel] = { u, lim, pct, hit }` (Grenze fest oder in %, Alarm aktiv) und `watchGone` (8.7), Abgleich wie `lists`.
- `cut[Markt]` (5.3), gemessener Anteil des Hauses.
- `ahPlain` (7.7).
- Einkaufslisten: `wish` bedeutet künftig Ziel inklusive Vorrat (gleiches Feld).
- Im Kern: `PeonDB.itemMenuClick` (Maustaste mit Taste, Abschnitt 9).
- **Entfällt:** `PeonBrokerCharDB.keep` (Behalten). Gelöscht wird erst beim Bauen von U12, mit Zustimmung von KarloDerBaer zu diesem Schritt.

### 10.2 Neu zwischen Spiel und Manager

- Bridge: Händlerdaten und Beobachtung (mit Grenzen) ins Spiel und zurück (wie `shop`).
- Manager: Favoriten umbenennen in Beobachtung mit Preisalarm, neue Ansicht Händler, Einkaufsliste mit Ziel/Vorrat/Fehlt, Vergleich Allianz gegen Neutral.

### 10.3 Verlauf für Diagramme

Im Spiel reichen Brokers Tageswerte. Wer mehr will: Der Manager könnte für beobachtete Gegenstände und den eigenen Bestand eine kurze Tagesreihe (30 Tage) in `Data.lua` mitschicken. Für alle 20.000 Gegenstände wäre die Datei zu groß. Vorschlag: erst nur Brokers eigene Tageswerte, Manager-Reihe später, wenn die Lücken stören.

## 11. Technik und Risiken

- **Reiter im Auktionshaus (7.1)** ist das größte Risiko, deshalb zuerst ein Prüfaufbau. Für den Ernstfall gibt es „Blizzard pur“ (7.7).
- **Taint allgemein:** nur `hooksecurefunc`, eigene Rahmen als Kinder, keine Blizzard-Tabellen neu zuweisen. Kaufen über `StartCommoditiesPurchase` und `PlaceBid` nur direkt aus einem Klick oder Tastendruck (bekannt seit Broker 0.33.1).
- **Abfragegrenze** des Spiels (rund 100 je Minute): Radar, Einkaufen und Auktionen teilen sich eine Warteschlange, der offene Reiter hat Vorrang.
- **Blizzards Listen nicht stören:** Jede eigene Suche ersetzt, was Blizzards Kaufliste zeigt. Broker sucht nur in seinen eigenen Reitern, im Verkaufen und Kaufen von Blizzard liest er mit.
- **Kontextmenü:** Der Klick löst trotzdem aus, was Blizzard mit dieser Taste macht (bei Strg+Rechtsklick nach heutigem Code nichts). Wählt jemand Umschalt+Rechtsklick, öffnen sich Blizzards Stapel-Fenster mit. Das steht als Hinweis neben der Auswahl.
- **Tooltip-Diagramm:** ein Rahmen, nur bei Wechsel neu zeichnen, mit Peon_Tooltip zusammen prüfen.
- **Händler-Voraussetzungen** aus dem Tooltip lesen: Texte sind deutsch, also nur „rote Zeile“ merken und als Text zeigen, nicht auswerten.
- Blizzard-Code nachlesen statt raten: `Gethe/wow-ui-source`, Zweig `forever`, `Blizzard_AuctionHouseUI`.

## 12. Bauabschnitte (Reihenfolge von KarloDerBaer bestätigt)

| Schritt | Inhalt | Größe |
|---|---|---|
| **U0 Prüfaufbau** | Zwei leere Reiter im Auktionshaus, kaufen und einstellen mit Blizzards Knöpfen ohne Fehler, dazu „Blizzard pur“ (7.7) | klein, entscheidet über 7.1 |
| **U1 Heimatmarkt** | Zwei Marktfragen (5.1), Neutral-Zeile im Tooltip (5.2) | klein, sofort sinnvoll |
| **U2 Gebühr je Markt** | Anteil am neutralen Haus messen (5.3) | klein, braucht einen Verkauf in Beutebucht |
| **U3 Rat im Verkaufsfenster** | 7.2 | mittel |
| **U4 Kontextmenü** | Kern-API 16, Erkennung, Einstellung, Broker-Einträge (Abschnitt 9) | mittel |
| **U5 Tooltip neu** | Bausteine, frei einstellbar mit Vorschau (6.2, 6.3) | mittel |
| **U6 Tooltip-Diagramm** | 6.4 | mittel |
| **U7 Radar im Auktionshaus** | 7.4 mit Zahl am Reiter | groß |
| **U8 Einkaufslisten und Beobachtung** | Verwalten im Fenster (8.2, 8.7 mit Alarm), Einkaufen im Auktionshaus (7.5), Abgleich und Umbenennen im Manager | groß |
| **U9 Auktionen** | 7.3 | mittel |
| **U10 Broker-Fenster neu** | Look (8.1), Gegenstände mit Ledger-Abschnitt (8.6), Quellen (8.5), Markt (8.3) | groß |
| **U11 Händler** | Erfassen und Ansicht (8.4), danach im Manager | groß |
| **U12 Aufräumen** | alte Reiter, Behalten, Optionen, Texte entfernen | klein |

Jeder Schritt als eigene Version, zuerst als Vorabversion zum Prüfen im Spiel. Die Einkaufsliste im Manager und Ledgers Reiter Gegenstände stehen noch auf WIP. U8 und U10 lösen das für Broker und Manager mit.

## 13. Was wegfällt

- Reiter Start, Verkaufen, Behalten, Meine Auktionen, Radar, Preise im Broker-Fenster.
- **Behalten ganz** (KarloDerBaer): Liste, Tooltip-Zeile, Urteil im Verkaufsfenster, Umschalter „Vorrat aller Charaktere“. Damit entfällt auch der geplante Bereich Behalten in Peon_Bags (B4).
- Knopf „Broker“ am Auktionshaus, Andocken des Fensters ans Auktionshaus, `windowWithAH`.
- Einzelne Tooltip-Schalter (ersetzt durch 6.3).
- Brokers eigene Verkaufsliste mit Taschen und das Eintragen von Preisen.
- Später bei Ledgers Überarbeitung: Alt+Klick und Ledgers eigener Reiter Gegenstand.

## 14. Abstimmung mit KarloDerBaer

### Geklärt (09.11.2026)

1. **Was stört am Reiter Verkaufen:** alles aus 2.2, dazu die Liste. Ausgewählt wird lieber in der Tasche.
2. **Zeile 1 im Tooltip:** Erlös für den Stapel und dahinter der Preis je Stück.
3. **Preis im Verkaufsfenster:** Broker trägt keinen Preis ein. Er sagt, ob man dafür verkaufen soll.
4. **Form des Rats:** Urteil groß und farbig, darunter ein Satz, warum.
5. **Neutral-Zeile im Tooltip:** einstellbar immer, erweiterter Tooltip (Standard) oder aus, erst ab den ersten neutralen Daten.
6. **Marktvergleich:** im Spiel und später im Manager.
7. **Reiter Verkaufen:** fällt weg, sobald der Rat im Verkaufsfenster geprüft ist.
8. **Andere AH-Addons:** keine installiert.
9. **Aufteilung:** Broker-Fenster nur für das, was ohne Auktionshaus geht (Einkaufslisten, Markt, Händler, Quellen, Gegenstände, Beobachtung). Im Auktionshaus Verkaufen, Auktionen, Radar, Einkaufen.
10. **Favoriten heißen Beobachtung**, im Spiel und im Manager.
11. **Händler** neu, im Spiel und im Manager.
12. **Tooltip** frei einstellbar (was, Format, Reihenfolge), Diagramm gewünscht.
13. **Kontextmenü** mit Strg+Rechtsklick, änderbar, als Baustein im Kern für alle Module. Ledgers Alt+Klick entfällt später.
14. **Look:** alle Broker-Fenster wie das Blizzard-Auktionshaus.
15. **Notausgang** „Blizzard pur“ im Auktionshaus.
16. **Behalten entfällt ganz.**
17. **Einkaufslisten** mit Ziel inklusive Vorrat.
18. **Markt:** Datenstand und Neutral-Vergleich.
19. **Gegenstand:** eine Ansicht in Broker, Ledger liefert Bestand und Kosten dazu.
20. **Beobachtung** mit Preisalarm gleich mit, als eigene Liste im Reiter Einkaufen. Zahl am Reiter Einkaufen für alles Kaufbare, ohne Blinken.
21. **Reihenfolge** wie in Abschnitt 12.

### Offen

- Grenzwerte für „Lieber warten“ und „Preis fällt“ (beim Bauen von U3).
- „Material auf Einkaufsliste“ aus dem Berufsfenster: gewünscht?
- Weitere Einträge im Kontextmenü (Ledger, Bags), wenn diese Module überarbeitet werden.
- Prüfung von U0 im Spiel (Broker 0.41.0), danach U1.

## 15. Nachtrag: Reiter Markt wie Blizzards Kaufen und moderner Look (Entwurf, noch nicht freigegeben)

Wunsch von KarloDerBaer nach dem ersten Test: Der Reiter Markt im Broker-Fenster soll aussehen und funktionieren wie Blizzards Reiter Kaufen (im AH jetzt Markt), aber auf Basis der Scandaten und mit Auswahl des Marktes. Alle Broker-Flächen bekommen den hellen, aufgeräumten Look des modernen Auktionshauses.

### 15.1 Aufbau des Reiters Markt

- **Oben:** Suchfeld, Knopf Filter (Stufe, Qualität, nur mit Angeboten), Auswahl des Marktes (Heimatmarkt, Neutral, jeder gescannte Markt) mit Datenstand daneben („Scan vor 3 Std.“).
- **Links:** Kategorieliste wie bei Blizzard (Waffen, Rüstung, Behälter, Edelsteine, Verbesserungen, Verbrauchbares, Glyphen, Handwerkswaren, Rezepte, Questgegenstände, Verschiedenes), aufklappbar in Unterkategorien. Die Namen kommen vom Spiel selbst (`GetItemClassInfo`, `GetItemSubClassInfo`), sind also immer in der Sprache des Spiels. Die Zuordnung eines Gegenstands holt `C_Item.GetItemInfoInstant` (geht ohne Zwischenspeicher des Spiels).
- **Rechts:** Ergebnisliste mit Symbol, Name in Qualitätsfarbe, Preis (Minimum), Menge, Angebote, Trend und Alter der Daten. Sortierbar per Klick auf die Spaltenköpfe wie bei Blizzard.
- **Klick auf eine Zeile:** Detailansicht wie Blizzards Angebotsliste. Gezeigt werden die günstigsten fünf Preisstufen des letzten Scans (diese speichert Broker bereits), dazu Diagramm, Median, Neutral-Vergleich und die Knöpfe Beobachten und Auf Einkaufsliste. Einzelne Angebote mit Verkäufer gibt es aus dem Scan nicht.
- **Ohne Suche und Kategorie:** Startseite wie bei Blizzard mit Beobachtung und Einkaufsliste als Liste.

### 15.2 Moderner Look

- Fenster und Flächen nutzen Blizzards eigene Grafiken des Auktionshauses (Atlas `auctionhouse-background-*`, `auctionhouse-nav-button*`, `auctionhouse-itemicon-small-border`, `auctionhouse-ui-sortarrow`, Favoritenstern). Dadurch kein Nachbau mit eigenen Farben, sondern exakt die hellen Grautöne des Originals.
- Gilt für das Broker-Fenster (alle Reiter) und die Flächen Einkaufen und Radar im AH. Abstände und Spaltenköpfe wie bei Blizzard, Knöpfe unten rechts.
- Umsetzung schrittweise: zuerst ein gemeinsamer Baukasten (Hintergrund, Liste mit Spaltenköpfen, Kategorieknopf), dann Markt, danach die übrigen Reiter.

### 15.3 Offene Fragen an KarloDerBaer

1. Startseite ohne Suche: Beobachtung und Einkaufsliste zeigen, oder leer wie bei Blizzard?
2. Marktauswahl: nur Heimat und Neutral, oder jeder gescannte Markt (auch andere Realms)?
3. Reihenfolge: erst Look-Baukasten plus Markt, die übrigen Reiter danach?
