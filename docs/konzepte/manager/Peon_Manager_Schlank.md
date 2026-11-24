# Peon Manager: Konzept schlank und übersichtlich

Stand: 24.11.2026, **freigegeben**, Richtung von KarloDerBaer gewählt (Variante A „Heute und fünf Bereiche“), Karten auf Heute wie in Abschnitt 4 bestätigt. Ausgangsversion Peon Manager 0.54.0. Skizzen der Varianten: Artifact-Seite „Peon schlank“.

## 1. Ausgangslage

Die Seitenleiste hat 14 Einträge: Übersicht, Marktübersicht, Gegenstände, Chancen, Marktvergleich, Einkaufen, Beobachten, Händler, Datenlage, Erfolgskontrolle, Updates, Rückmeldungen, Hilfe, Einstellungen. Chancen, Marktvergleich und Beobachten haben selbst Unterreiter. Die Übersicht zeigt vier Kacheln, „Jetzt kaufbar“, ein Diagramm, Stabilität und „Beste Chancen jetzt“.

Geprüfte Varianten: A Startseite „Heute“ und fünf Bereiche, B Schalter Einfach und Experte, C Suche statt Menü. **Gewählt: A** (KarloDerBaer, 24.11.2026).

## 2. Grundsätze

1. **Die Startseite sagt, was jetzt zu tun ist.** Nicht was es alles gibt.
2. **Höchstens sechs Einträge in der Seitenleiste.** Alles andere wird Unterreiter.
3. **Nichts geht verloren.** Jede heutige Seite hat einen festen neuen Platz.
4. **Gleiche Namen wie im Spiel.** Was Broker „Chancen“ oder „Beobachten“ nennt, heißt im Manager genauso.

## 3. Seitenleiste danach

| Eintrag | Unterreiter | kommt von |
|---|---|---|
| **Heute** | keine | neue Startseite (Abschnitt 4) |
| **Chancen** | Spekulation, Marktvergleich, Pakete, Erfolg | Chancen, Marktvergleich (mit Pakete), Erfolgskontrolle |
| **Listen** | Einkaufslisten, Beobachten | Einkaufen, Beobachten (mit Aufkauf, Schnellkauf, Markttausch) |
| **Markt** | Übersicht, Gegenstände, Händler | Marktübersicht, Gegenstände, Händler (zeigt, was es bei Händlern zu kaufen gibt), Diagramme der alten Übersicht |
| **Addons** | keine | Updates (Zahl am Eintrag bleibt) |
| **Mehr** | Datenlage, Rückmeldungen, Hilfe, Einstellungen | wie heute, Zahl an Rückmeldungen erscheint auf Heute |

Unten in der Leiste bleibt „Peon unterstützen“. Ohne eingeschalteten Broker Client zeigt die Leiste nur Heute, Addons und Mehr.

Unterreiter erscheinen oben auf der Seite als Reiterleiste wie heute bei Beobachten. Der zuletzt gewählte Unterreiter je Eintrag bleibt gemerkt. Sprünge aus anderen Seiten (`go('market:stab')`) gehen weiter, sie zeigen nur auf den neuen Platz.

Abstimmung mit der Konzept-Session zu Broker: Wenn Broker seine Reiter Chancen oder Beobachten neu ordnet, folgen die Unterreiter im Manager diesen Namen.

## 4. Startseite Heute

Höchstens vier Karten, jede nur, wenn sie etwas zu sagen hat. Reihenfolge nach Dringlichkeit.

```
┌ Heute ─────────────────────────────────────────────────────────┐
│ ┌ 2 Updates bereit ──────────┐ ┌ Daten ──────────────────────┐ │
│ │ Broker 0.131.0, Ledger …   │ │ ● frisch · Scan vor 3 Std.  │ │
│ │ [Installieren]             │ │ 3 Rückmeldungen nicht gesendet│
│ └────────────────────────────┘ └─────────────────────────────┘ │
│ ┌ Lohnt sich jetzt ───────────────────────────────────────────┐ │
│ │ Seidenstoff        kaufen bis 1s 10c      Spekulation  →    │ │
│ │ Runenstoff         nach Neutral tauschen  Marktvergleich →  │ │
│ │ Paket Kräuter      +4g 20s                Pakete →          │ │
│ └─────────────────────────────────────────────────────────────┘ │
│ ┌ Meine Listen ───────────────────────────────────────────────┐ │
│ │ Einkaufen: 3 offen · Beobachten: 1 Preis erreicht   →       │ │
│ └─────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

| Karte | Inhalt | erscheint wenn |
|---|---|---|
| Updates | Anzahl, Namen, Knopf Installieren | Updates da |
| Daten | Ampel der Datenlage (frisch, älter als 1 Tag, fehlt), Rückmeldungen nicht gesendet mit Knopf Senden | immer (Ampel), Rückmeldungen nur wenn da |
| Lohnt sich jetzt | die fünf besten Einträge aus Spekulation, Marktvergleich und Pakete, je mit Sprung | Broker Client an |
| Meine Listen | offene Einkäufe, erreichte Preise in Beobachten | Listen nicht leer |

Kacheln, Diagramm und Stabilität der alten Übersicht wandern nach Markt, Übersicht.

## 5. Einstellungen des Managers

Nach `docs/konzepte/Peon_Einstellungen_Leitfaden.md`:

- **Allgemein**: WoW-Ordner, Kanal Stabil oder Test, Aussehen, Größe der Oberfläche.
- **Erweitert**: Datenordner, Spieldaten sichern, Aufbewahrung, Grenzen der Chancen, Zugang zur Blizzard-API.

## 6. Bauabschnitte

| Nr. | Inhalt |
|---|---|
| M1 | Seitenleiste mit sechs Einträgen und Unterreitern, alle Sprünge umgestellt |
| M2 | Startseite Heute mit den vier Karten |
| M3 | Einstellungen in Allgemein und Erweitert |
| M4 | Hilfe (`docs/Hilfe.md`) und Bilder an die neuen Namen anpassen |

## 7. Offene Fragen an KarloDerBaer

1. Fehlt auf Heute etwas, das du beim Start sehen willst?

Geklärt (KarloDerBaer, 24.11.2026): Erfolgskontrolle als Unterreiter „Erfolg“ unter Chancen. Händler unter Markt, weil die Seite zeigt, was bei Händlern zu kaufen ist.
