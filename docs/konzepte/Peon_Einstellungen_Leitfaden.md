# Peon: Leitfaden für Einstellungen

Stand: 24.11.2026, **von KarloDerBaer freigegeben** (Regeln in Abschnitt 1). Gilt für die Einstellungen aller Module im Spiel und für den Peon Manager. Bestehende Seiten werden Modul für Modul umgestellt (Abschnitt 3).

## 1. Regeln

1. **Drei Reiter, immer gleich:** Allgemein, Anzeige, Erweitert. Ein Modul mit wenigen Einstellungen hat nur Allgemein. Der Baustein ist `page:Tabs` im Kern (schon in Panel, ClassBuddy, Tooltip).
2. **Allgemein zeigt höchstens sechs Schalter.** Ganz oben der Hauptschalter des Moduls (falls es einen gibt) und der Knopf „Fenster öffnen“.
3. **Erweitert** sammelt Grenzen, Zeiten, Feinwerte, Daten löschen und Zurücksetzen. Oben steht ein Satz: „Normalerweise musst du hier nichts ändern.“
4. **Keine Prüfungen und Debug-Knöpfe** in den Einstellungen. Sie gehören in Befehle (`/<modul> pruefen`) oder in Peon_Debug.
5. **Was im Fenster einstellbar ist, bleibt im Fenster** (Filter, Zeitraum, Spalten, Sortierung). Es steht nicht noch einmal in den Einstellungen.
6. **Jeder Schalter hat einen Tooltip** in einem Satz, der sagt, was passiert.
7. **Gute Standardwerte statt Fragen.** Neue Funktionen kommen nur eingeschaltet, wenn sie niemanden stören.
8. **Neue Schalter brauchen einen Grund.** Ein Schalter, den niemand ändert, fällt weg und der Standard bleibt (nur nach Zustimmung von KarloDerBaer).

Was in welchen Reiter gehört:

| Allgemein | Anzeige | Erweitert |
|---|---|---|
| Modul oder Hauptfunktion an und aus, Fenster öffnen, Minimap-Knopf, die zwei bis drei Dinge, die jeder einstellt | Aussehen, Farben, Größe, Schrift, Zeilen im Tooltip, Einträge im Panel | Grenzen, Zeiten, Mengen, Daten löschen, neu rechnen, Zurücksetzen |

Der Knopf „Standardwerte“ steht wie heute unten auf jeder Seite (`page:AddResetButton`).

## 2. Ist-Stand (24.11.2026)

Bedienelemente je Optionsseite (Haken, Regler, Auswahl, Farbe, Knopf, grob gezählt):

| Modul | Anzahl | Aufbau heute |
|---|---|---|
| Broker | 47 | lange Seite, dazu Einstellungen in Fenstern |
| Panel | 33 | Reiter |
| ClassBuddy | 24 | Reiter je Klasse |
| Fishing | 24 | lange Seite |
| Bags | 22 | lange Seite |
| Tooltip | 17 | Reiter |
| Warhorn | 17 | lange Seite |
| Ledger | 11 | lange Seite mit Prüfung |
| Profession | 11 | lange Seite |
| Peon, Bridge, Feedback, Mover | 1 bis 9 | kurz |

## 3. Reihenfolge der Umstellung

1. Ledger und Manager (mit den Konzepten `ledger/Peon_Ledger_Schlank.md` und `manager/Peon_Manager_Schlank.md`).
2. Fishing, Bags, Warhorn, Profession (lange Seiten ohne Reiter).
3. Panel, ClassBuddy, Tooltip (haben Reiter, nur anpassen).
4. Broker, sobald die Konzept-Session zu Broker steht.
5. Kleine Module nur prüfen.

Je Modul vor dem Umbau eine kurze Liste „Allgemein, Anzeige, Erweitert, fällt weg“ mit KarloDerBaer abstimmen. Gespeicherte Werte und ihre Namen bleiben gleich, nur die Seite ändert sich.

Stand 25.11.2026: Punkte 2 und 3 sind umgestellt (Fishing 1.9.0, Bags 0.9.0, Warhorn 0.6.0, Profession 0.8.0, Panel 0.5.0, ClassBuddy 0.5.0, Tooltip 0.8.0). Hinweise stehen dort als Tooltip über `NewOptionsPage({ tipHints = true })` (Kern-API 29). Punkt 4 ist umgestellt (Broker 0.139.0).
