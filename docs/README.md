# Peon: Inhaltsverzeichnis der Doku

Für Nutzer: [Hilfe.md](Hilfe.md) erklärt kurz jedes Addon und den Peon Manager (auch im Manager unter Hilfe).

## Projekt (`projekt/`)

| Datei | Inhalt |
|---|---|
| [Peon_Ueberblick.md](projekt/Peon_Ueberblick.md) | Wo alles liegt, Aufbau, Kern-API, Wissen zu WoW Forever, Arbeitsweise. Zu Beginn jeder Arbeit lesen |
| [Peon_Stand.md](projekt/Peon_Stand.md) | Stand je Modul (Version, Dateien, Daten, Befehle, Schnittstellen), offene Punkte |
| [Peon_Entscheidungen.md](projekt/Peon_Entscheidungen.md) | Protokoll der Entscheidungen, neueste oben |
| [Peon_Vorlage.md](projekt/Peon_Vorlage.md) | Vorlage für neue Module (gehört zu `vorlage/`) |

## Konzepte und Designs (`konzepte/`)

| Modul | Datei | Inhalt |
|---|---|---|
| Alle | [Peon_UI_Design.md](konzepte/Peon_UI_Design.md) | Einheitliches UI-Design aller Peon-Fenster (Entwurf in Abstimmung) |
| Kern | [Peon_Comm_Konzept.md](konzepte/kern/Peon_Comm_Konzept.md) | Datenaustausch zwischen Peon-Nutzern (`Peon.Comm`), Regeln für Module |
| Broker | [Peon_Broker_Konzept.md](konzepte/broker/Peon_Broker_Konzept.md) | Konzept für Broker (Funktionsumfang, Preisvorschlag, Märkte, Bauabschnitte) |
| Broker | [Peon_Broker_Rechenmodell.md](konzepte/broker/Peon_Broker_Rechenmodell.md) | Begriffe, Formeln und Anzeige |
| Broker | [Peon_Broker_Verkaufen.md](konzepte/broker/Peon_Broker_Verkaufen.md) | Reiter Verkaufen |
| Broker | [Peon_Broker_Einkaufen.md](konzepte/broker/Peon_Broker_Einkaufen.md) | Reiter Einkaufsliste und Radar |
| Broker | [Peon_Broker_Absatz.md](konzepte/broker/Peon_Broker_Absatz.md) | Absatzquote |
| Broker | [Peon_Broker_Umbau.md](konzepte/broker/Peon_Broker_Umbau.md) | Umbau: Aufteilung Fenster und Auktionshaus, Tooltip, Märkte, Einkaufslisten, Händler (Abschnitte 7, 8 und 15 ersetzt durch den Neuaufbau) |
| Broker | [Peon_Broker_Neuaufbau.md](konzepte/broker/Peon_Broker_Neuaufbau.md) | Neuaufbau: ein Fenster mit acht Reitern, Sprünge, Radar mit Aufkauf, Reiter Fokus, Bauabschnitte N1 bis N6 und H1 bis H5 |
| Ledger | [Peon_Ledger_Konzept.md](konzepte/ledger/Peon_Ledger_Konzept.md) | Bestand und Buch |
| Ledger | [Peon_Ledger_Zuordnen.md](konzepte/ledger/Peon_Ledger_Zuordnen.md) | Kosten, Lagerwert und Handelsgewinn |
| Ledger | [Peon_Ledger_Gegenstand.md](konzepte/ledger/Peon_Ledger_Gegenstand.md) | Reiter Gegenstand, Kosten je Charakter |
| Ledger | [Peon_Ledger_Neuaufbau.md](konzepte/ledger/Peon_Ledger_Neuaufbau.md) | Neuaufbau: Erfassung prüfen, vier Seiten, Postfenster |
| Ledger | [Peon_Ledger_Buch_AH.md](konzepte/ledger/Peon_Ledger_Buch_AH.md) | Buch mit klarem Handelsgewinn (Beuteanteil, Handelsteil) |
| Manager | [Peon_Client_Design.md](konzepte/manager/Peon_Client_Design.md) | Programm Peon Client und Modul Peon_Client (jetzt Peon Manager mit Modul Peon Broker Client und Peon_Bridge) |
| Manager | [Peon_GitHub_Design.md](konzepte/manager/Peon_GitHub_Design.md) | GitHub-Repo, Peon Manager, Peon_Bridge, Umsetzungsplan |
| Manager | [Peon_Blizzard_API.md](konzepte/manager/Peon_Blizzard_API.md) | Blizzard-API für Forever: Aufbau, Häuser, offene Fragen, Beobachter |
| Manager | [Peon_Manager_Angleichung.md](konzepte/manager/Peon_Manager_Angleichung.md) | Angleichung nach dem Neuaufbau: Einkaufslisten und Beobachten (Teil 1) |
| Manager | [Peon_Manager_Chancen.md](konzepte/manager/Peon_Manager_Chancen.md) | Chancen und Prognosen, Übergabe an Broker (Angleichung Teil 2 und 3, Entwurf) |
| Manager | [Peon_Manager_Stabilitaet.md](konzepte/manager/Peon_Manager_Stabilitaet.md) | Stabilität der Preise je Gegenstand, Kategorie und Markt, Messung und Grenzen |
| Manager, Broker | [Peon_Chancen_Reiter_Muster.md](konzepte/manager/Peon_Chancen_Reiter_Muster.md) | Reiter Chancen in Broker, Muster nach Tageszeit und Wochentag, Händler nur im Radar |
| Tooltip | [Peon_Tooltip_Konzept.md](konzepte/tooltip/Peon_Tooltip_Konzept.md) | Teile im Gegenstands-Tooltip |
| Mover | [Peon_Mover_Konzept.md](konzepte/mover/Peon_Mover_Konzept.md) | Fenster verschieben |
| Bags | [Peon_Bags_Konzept.md](konzepte/bags/Peon_Bags_Konzept.md) | Taschen, Bank, Gildenbank |
| Bags | [Peon_Bags_Bereiche.md](konzepte/bags/Peon_Bags_Bereiche.md) | Eigene Bereiche in Taschen und Bank |
| Bags | [Peon_Bags_Anordnung.md](konzepte/bags/Peon_Bags_Anordnung.md) | Anordnung Klassisch, Nach Art, Individuell |
| Bags | [Peon_Bags_Layout.md](konzepte/bags/Peon_Bags_Layout.md) | Layout und Platzsparen |
| Panel | [Peon_Panel_Konzept.md](konzepte/panel/Peon_Panel_Konzept.md) | Leiste und Panel für Symbole und kurze Texte |
| Profession | [Peon_Profession_Konzept.md](konzepte/profession/Peon_Profession_Konzept.md) | Berufe: Guide zum Leveln, später auch Brokers Teil im Berufsfenster |
| Profession | [Peon_Profession_Codex.md](konzepte/profession/Peon_Profession_Codex.md) | Codex und Sammelstellen |
| ClassBuddy | [Peon_ClassBuddy_Konzept.md](konzepte/classbuddy/Peon_ClassBuddy_Konzept.md) | Klassenbuddy: Helfer je Klasse (Schurke, Hexenmeister) |
| Warhorn | [Peon_Warhorn_Konzept.md](konzepte/warhorn/Peon_Warhorn_Konzept.md) | Gruppensuche mit Filtern nach Rolle, Klasse und Stufe |

## Verlauf der Versionen (`changelog/`)

Je Modul eine Datei, neueste Version oben. Daraus entstehen auch die Texte „Was ist neu“ im Release.

[Peon](changelog/Peon.md) · [Peon_Bags](changelog/Peon_Bags.md) · [Peon_Broker](changelog/Peon_Broker.md) · [Peon_Bridge](changelog/Peon_Bridge.md) · [Peon_Fishing](changelog/Peon_Fishing.md) · [Peon_Ledger](changelog/Peon_Ledger.md) · [Peon_Mover](changelog/Peon_Mover.md) · [Peon_Panel](changelog/Peon_Panel.md) · [Peon_Profession](changelog/Peon_Profession.md) · [Peon_Tooltip](changelog/Peon_Tooltip.md) · [Peon_Warhorn](changelog/Peon_Warhorn.md) · [Peon Manager](changelog/Peon_Manager.md)

## Archiv (`archiv/`)

Abgelöste Konzepte, nur zum Nachlesen.

| Datei | Abgelöst durch |
|---|---|
| [Peon_Broker_Programm.md](archiv/Peon_Broker_Programm.md) | Peon_Client_Design.md (22.10.2026) |
| [Peon_Broker_Buch.md](archiv/Peon_Broker_Buch.md) | Peon_Ledger_Konzept.md (02.10.2026) |
| [Peon_Stand_bis_2026-11-18.md](archiv/Peon_Stand_bis_2026-11-18.md) | Kurzer Stand in projekt/Peon_Stand.md (18.11.2026), hier der alte Stand mit Verlauf und Prüfhinweisen |
| [Peon_Entscheidungen_bis_2026-10.md](archiv/Peon_Entscheidungen_bis_2026-10.md) | Ältere Einträge aus projekt/Peon_Entscheidungen.md (September und Oktober 2026) |
| [Peon_Cloud_Uebertragen.md](archiv/Peon_Cloud_Uebertragen.md) | Regeln zum Übertragen aus der Cloud (bis 31.10.2026), früher im Überblick |
| [Peon_ComboPoints_Changelog.md](archiv/Peon_ComboPoints_Changelog.md) | Peon_ComboPoints ist am 18.11.2026 aus dem Repo genommen, abgelöst durch Peon_ClassBuddy |
