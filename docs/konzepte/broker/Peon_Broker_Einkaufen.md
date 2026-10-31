# Peon_Broker – Reiter „Einkaufsliste“ und „Radar“

Stand: 30.09.2026, **mit KarloDerBaer abgestimmt**, Umsetzung in Broker 0.13.0, ab 0.14.0 als zwei eigene Reiter. Formeln: Rechenmodell Kapitel 5 (F28–F34).

## 1. Aufbau

### Reiter „Einkaufsliste“ (je Charakter)

```
┌ Einkaufsliste ───────────────────────────────────────────────────────────────┐
│ Listen          │ Gegenstand           Höchstpreis  Menge  Günstigst  Treffer│
│ ▸ Kräuter       │ [▪] Friedensblume        3s        40     2s 80c      25   │
│   Schneiderei   │ [▪] Silberblatt          1s 50c    –      1s 90c      –    │
│ [Neu] [Löschen] │ Hinzufügen: Alt+Klick oder Suche [________]                 │
│ Höchstpreis:    │ Gewählt: Menge [40] [Entfernen]                             │
│ [10] % unter    │ [Liste durchsuchen]                           [Kaufen]      │
│ Median          │                                                             │
└──────────────────────────────────────────────────────────────────────────────┘
```

- Beliebig viele Listen je Charakter; je Liste **ein Rabatt x %** (Höchstpreis = x % unter dem Median).
- Je Gegenstand optional eine **Wunschmenge**. Gekauft wird höchstens bis zur Wunschmenge, abzüglich dessen, was schon da ist (Taschen + Bank).
- Hinzufügen: Alt+Klick auf einen Gegenstand (Taschen, Chat-Link), Suchfeld mit allen Gegenständen aus den Scans, Knopf „Zur Einkaufsliste“ im Reiter „Preise“.
- „Günstigst“ zuerst aus dem letzten Scan; „Liste durchsuchen“ fragt alle Gegenstände nacheinander live ab. Treffer (Angebote bis zum Höchstpreis) werden grün mit Menge angezeigt.

### Reiter „Radar“ (Schnäppchen)

```
│ Gegenstand          Art       Angebot   Vergleich  Menge  Gewinn   Daten     Gesehen │
│ ● Eisenerz          Markt     2s        4s 10c       40   1g 44s   14 / 7 T  vor 3 s │
│ [▪] Grüner Hut      Händler   3s        5s            1   2s       –         Scan    │
│ Radar läuft: 92/Min., 431 Abfragen       [Reihenfolge: smart ▾] [Radar-Scan stoppen] │
│ Prüfe: [▪] Eisenerz                                                                  │
│ Grüner Hut  1 kaufen für 3s                  [x] Nur Warnton    [Kaufen]            │
│ [ Händler: Bestes kaufen (3s) ]            [ AH: Bestes kaufen (1g 20s) ]            │
```

- **Händler:** Angebot unter dem Händlerpreis; Gewinn beim Verkauf an den Händler.
- **Markt (Dump):** Angebot weit unter dem üblichen Preis; möglicher Gewinn beim Wiederverkauf im Auktionshaus. Nur bei guter Datenlage.
- **Beim Öffnen des Reiters:** alle Schnäppchen aus der Datenbank, deren Daten (voller Scan oder, ab 0.15, gespeicherte Live-Abfrage) höchstens **60 Minuten** alt sind (einstellbar, 0 = unbegrenzt); Grundlage sind die günstigsten 5 Preisstufen je Gegenstand. Diese Treffer werden sofort einmal live geprüft (auch ohne Radar-Scan). Das Ergebnis steht danach in der Datenbank (Rechenmodell Kapitel 6): was weg ist, kommt nicht wieder. Spalte „Gesehen“: Alter der Daten (z. B. „40 Min.“), nach der Prüfung Sekunden.
- **Radar-Scan** (Knopf): laufend Einzelabfragen knapp unter der Grenze des Spiels (alle 0,65 Sek., etwa 92 pro Minute, Grenze 100), nur solange der Reiter und das Auktionshaus offen sind. Reihenfolge: Treffer (spätestens alle 15 Sek. nachgeprüft, jeder dritte Schritt), Einkaufslisten, dann bis zu 400 Gegenstände mit den besten Chancen (Median × Menge; Händlerpreis bekannt oder gute Datenlage).
- **Neue Treffer:** Ton (abschaltbar) und grün mit ● für 60 Sekunden.
- **Markt-Schnäppchen ab 0.17:** Wiederverkauf gegen das nächste Angebot nach dem Kauf (höchstens Median), Mindestmarge je Stück 20 %, höchstens 20 % aller Angebote (Rechenmodell F33).
- **Ab 0.26:** Wiederverkauf höchstens zur Untergrenze des üblichen Bereichs; Menge höchstens Absatz je Std. × 48 Std. (einstellbar, ab gelbem ≈; Absatz 0 = kein Markt-Schnäppchen). Zeilen-Tooltip zeigt Wiederverkauf und Absatz-Grenze bzw. „Absatz unbekannt“.
- **Spalten ab 0.17:** Gegenstand, Art (H/AH), Angebot, Wiederverkauf, Menge, Gewinn je Stück, Gewinn je Stapel (Massenware), Gesehen; Datenlage im Tooltip. Sortierung nach Gewinn je Stück.
- **Anzeige** (Auswahl, ab 0.17): Händler + AH, nur Händler, nur AH – gilt für Liste und Scan.
- **Gold** (ab 0.17): was ich mir nicht leisten kann, wird ausgeblendet (Einstellung: grau zeigen).
- **Reihenfolge** (Auswahl neben dem Scan-Knopf, ab 0.16): smart (beste 400 nach Wert × Menge), zufällig, Massenware zuerst, höchster Preis zuerst, niedrigster Preis zuerst (Median). Einkaufslisten und Nachprüfen der Treffer immer zuerst.
- **Nur Warnton** (Haken im Reiter, Standard an, ab 0.16): während des Radar-Scans alle Tonkanäle außer „Gesamt“ auf 0, Ton auch im Hintergrund; zurück beim Stoppen oder Verlassen des Reiters.
- Unter „Radar läuft: x/Min.“ steht, welcher Gegenstand gerade geprüft wird.
- Sortierung nach Gewinn.

## 2. Kaufen

- Beim Anklicken wird der Gegenstand auch in Blizzards Kaufen-Ansicht geöffnet.
- **Ab 0.18: Kaufzeile unter der Liste** für den gewählten Treffer: Menge des Schnäppchens, „Gewinn erst ab n Stück“, Knöpfe „1 Stück“, „n Stück“ (bis ein Stapel) und „Alle (n)“ mit Kosten und Gewinn darunter, grau wenn das Gold nicht reicht. Keine Schnellkauf-Knöpfe mehr. Rechtsklick blendet aus (siehe Entscheidungen 0.18).
- **0.17: je Stück oder Stapel** – unten vier Knöpfe (Händler 1×, Händler Stapel, AH 1×, AH Stapel), für die gewählte Zeile zwei; jeder Knopf zeigt den Preis genau dieses Kaufs. Stapel = Stapelgröße des Spiels, höchstens Schnäppchen-Menge und Gold. Bestes = höchster Gewinn je Stück. Nach einem Teilkauf bleibt der Treffer und wird neu geprüft.
- **Bis 0.16 – „Bestes kaufen“** (je ein Knopf für Händler und AH, mit dem Preis nur dieses Kaufs; ohne Treffer „nichts zu kaufen“): je Klick ein Kauf, **höchster Gewinn zuerst**. Vor jedem Kauf wird geprüft, ob das Angebot noch da und noch so günstig ist:
  - Massenware: Broker startet den Kauf, das Spiel nennt den Preis. Liegt er über der Grenze, bricht Broker ab („das günstige Angebot ist weg“) und entfernt den Treffer; sonst zeigt der Knopf „Bestätigen: 20× … für …“ und der nächste Klick kauft.
  - Einzelgegenstand: nur, wenn die Live-Prüfung höchstens 10 Sek. alt ist; sonst prüft der Klick erst („Prüfe: …“), der nächste kauft per `PlaceBid`.
  - Gekaufte Treffer verschwinden; der Radar-Scan findet sie wieder, wenn noch mehr da ist.
- **Knopf „Kaufen“ im Reiter Einkaufsliste:**
  - Massenware: Broker startet den Kauf für die berechnete Menge, das Spiel nennt den genauen Gesamtpreis, Broker fragt nach („Kaufen: 25× Friedensblume für 70s?“), nach „Ja“ wird gekauft. Ist der Preis höher als die Grenze, steht das rot in der Rückfrage.
  - Einzelgegenstand: Broker fragt nach und kauft das günstigste passende Angebot (je Klick eines).
- Jeder Kauf nur per Klick, nie im Kampf.

## 3. Einstellungen

- Mindestgewinn Händler-Schnäppchen: 10c
- Mindestgewinn Markt-Schnäppchen: 50s
- Datenlage Markt: mindestens 10 Scans in den letzten 7 Tagen
- Treffer aus der Datenbank bis 60 Minuten alt (0 = unbegrenzt; bis 0.14: 5 Minuten nach dem Scan)
- Ton bei neuen Radar-Treffern: an
- Rabatt (Dump-Grenze) wie beim Verkaufen: DG (Standard 30 %)

## 4. Im Spiel geprüft / noch zu prüfen

- Geprüft (0.13.0): Kaufen-Ansicht, Kauf von Händler-Schnäppchen, Abfragen ohne eigenen Klick.
- Noch zu prüfen (0.14.0): Radar-Scan dauerhaft mit ~92 Abfragen pro Minute ohne Sperre des Spiels (Grenze laut Wowpedia/TSM für Retail: 100 Suchen pro Minute, für Forever unbestätigt); „Bestes kaufen“ mit Bestätigen-Klick bei Massenware; Ton.
