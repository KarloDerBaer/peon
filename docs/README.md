# Peon: Inhaltsverzeichnis der Doku

## Projekt (`projekt/`)

| Datei | Inhalt |
|---|---|
| [Peon_Ueberblick.md](projekt/Peon_Ueberblick.md) | Wo alles liegt, Aufbau, Kern-API, Wissen zu WoW Forever, Arbeitsweise. Zu Beginn jeder Arbeit lesen |
| [Peon_Stand.md](projekt/Peon_Stand.md) | Stand je Modul (Version, Dateien, Einstellungen, Befehle), offene Punkte, Prüfliste erster Spieltag |
| [Peon_Entscheidungen.md](projekt/Peon_Entscheidungen.md) | Protokoll der Entscheidungen, neueste oben |
| [Peon_Vorlage.md](projekt/Peon_Vorlage.md) | Vorlage für neue Module (gehört zu `vorlage/`) |

## Konzepte und Designs (`konzepte/`)

| Modul | Datei | Inhalt |
|---|---|---|
| Broker | [Peon_Broker_Konzept.md](konzepte/broker/Peon_Broker_Konzept.md) | Konzept für Broker (Funktionsumfang, Preisvorschlag, Märkte, Bauabschnitte) |
| Broker | [Peon_Broker_Rechenmodell.md](konzepte/broker/Peon_Broker_Rechenmodell.md) | Begriffe, Formeln und Anzeige |
| Broker | [Peon_Broker_Verkaufen.md](konzepte/broker/Peon_Broker_Verkaufen.md) | Reiter Verkaufen |
| Broker | [Peon_Broker_Einkaufen.md](konzepte/broker/Peon_Broker_Einkaufen.md) | Reiter Einkaufsliste und Radar |
| Broker | [Peon_Broker_Absatz.md](konzepte/broker/Peon_Broker_Absatz.md) | Absatzquote |
| Ledger | [Peon_Ledger_Konzept.md](konzepte/ledger/Peon_Ledger_Konzept.md) | Bestand und Buch |
| Ledger | [Peon_Ledger_Zuordnen.md](konzepte/ledger/Peon_Ledger_Zuordnen.md) | Kosten, Lagerwert und Handelsgewinn |
| Ledger | [Peon_Ledger_Gegenstand.md](konzepte/ledger/Peon_Ledger_Gegenstand.md) | Reiter Gegenstand, Kosten je Charakter |
| Manager | [Peon_Client_Design.md](konzepte/manager/Peon_Client_Design.md) | Programm Peon Client und Modul Peon_Client (jetzt Peon Manager mit Modul Peon Broker Client und Peon_Bridge) |
| Manager | [Peon_GitHub_Design.md](konzepte/manager/Peon_GitHub_Design.md) | GitHub-Repo, Peon Manager, Peon_Bridge, Umsetzungsplan |
| Manager | [Peon_Blizzard_API.md](konzepte/manager/Peon_Blizzard_API.md) | Blizzard-API für Forever: Aufbau, Häuser, offene Fragen, Beobachter |
| Tooltip | [Peon_Tooltip_Konzept.md](konzepte/tooltip/Peon_Tooltip_Konzept.md) | Teile im Gegenstands-Tooltip |
| Mover | [Peon_Mover_Konzept.md](konzepte/mover/Peon_Mover_Konzept.md) | Fenster verschieben |
| Bags | [Peon_Bags_Konzept.md](konzepte/bags/Peon_Bags_Konzept.md) | Taschen, Bank, Gildenbank |
| Bags | [Peon_Bags_Bereiche.md](konzepte/bags/Peon_Bags_Bereiche.md) | Eigene Bereiche in Taschen und Bank |

## Verlauf der Versionen (`changelog/`)

Je Modul eine Datei, neueste Version oben. Daraus entstehen auch die Texte „Was ist neu“ im Release.

[Peon](changelog/Peon.md) · [Peon_Bags](changelog/Peon_Bags.md) · [Peon_Broker](changelog/Peon_Broker.md) · [Peon_Bridge](changelog/Peon_Bridge.md) · [Peon_ComboPoints](changelog/Peon_ComboPoints.md) · [Peon_Fishing](changelog/Peon_Fishing.md) · [Peon_Ledger](changelog/Peon_Ledger.md) · [Peon_Mover](changelog/Peon_Mover.md) · [Peon_Tooltip](changelog/Peon_Tooltip.md) · [Peon Manager](changelog/Peon_Manager.md)

## Archiv (`archiv/`)

Abgelöste Konzepte, nur zum Nachlesen.

| Datei | Abgelöst durch |
|---|---|
| [Peon_Broker_Programm.md](archiv/Peon_Broker_Programm.md) | Peon_Client_Design.md (22.10.2026) |
| [Peon_Broker_Buch.md](archiv/Peon_Broker_Buch.md) | Peon_Ledger_Konzept.md (02.10.2026) |
