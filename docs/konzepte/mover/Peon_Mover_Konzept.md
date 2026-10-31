# Peon_Mover – Konzept (abgestimmt)

Stand: 06.10.2026, umgesetzt M1–M3 in Peon_Mover 0.1.0. Neues Modul, das Fenster von Blizzard und von Peon verschiebbar und in der Größe veränderbar macht (Vorbild: BlizzMove).

## 1. Abgestimmt (06.10.2026)

- Eigenes Modul **Peon_Mover** (`## Dependencies: Peon`), der Kern bleibt unverändert (siehe 6.4 für eine kleine Erweiterung).
- Positionen werden **dauerhaft** gemerkt.
- Verschieben an der **Titelleiste**.
- Extras: **Größe** mit Strg + Mausrad, **Zurücksetzen** mit Umschalt + Rechtsklick auf die Titelleiste, **Fensterliste** in den Optionen (je Fenster an/aus, zurücksetzen), **Sperre** nur als Schalter in den Optionen.
- Nur **Fenster** – keine Aktionsleisten, Minimap, Spieler- oder Zielrahmen. Dafür hat Forever den Bearbeitungsmodus des Spiels (in WTF liegen `edit-mode-cache-character.txt`).

## 2. Ergebnis der Recherche – warum kein Prüfbefehl nötig ist

- **Forever nutzt den Retail-Client (Midnight, 12.x)** mit dessen Oberfläche: in KarloDerBaers WTF und BugGrabber tauchen `Blizzard_Professions`, `Blizzard_ProfessionsBook`, `Blizzard_GameMenuEsc`, `Blizzard_DamageMeter`, Bearbeitungsmodus usw. auf – alles Retail-Teile.
- **BlizzMove unterstützt Forever offiziell** (eigene Version „Forever“, Interface 16001 wird als Forever erkannt, Familie „Mainline“ wie Retail). Seine Fensterliste ist damit eine geprüfte Grundlage. Peon_Mover übernimmt daraus nur die **Namen der Fenster** (Tatsachen, kein Code) und schreibt den Code selbst.
- BlizzMoves Liste ist für Forever nicht ganz vollständig (z. B. fehlt dort das Berufsbuch, obwohl Forever `Blizzard_ProfessionsBook` lädt). Deshalb zusätzlich die **automatische Erkennung** (3.2). Wer im Spiel ein Fenster vermisst, sieht in der Fensterliste sofort, ob es erkannt wurde – das ersetzt den Prüfbefehl.

## 3. Welche Fenster

### 3.1 Feste Liste (aus BlizzMove, für Forever passend)

Immer geladen: Charakter, Bank, Taschen (Blizzard), Händler, Post, Handel, Flugmeister, Gossip/Quest, Freunde, Spielmenü, Einstellungen, Addon-Liste, Chat-Einstellungen, Weltkarte, Beute, Anprobe, Gildenwappen, Tutorial-Fenster u. a.
Erst bei Bedarf geladen (Blizzard lädt sie beim ersten Öffnen): Auktionshaus, Berufe und Berufsbuch, Zauberbuch/Talente (`PlayerSpellsFrame`), Lehrer, Gildenbank, Gilde/Communities, Kalender, Makros, Erfolge, Sammlungen, Betrachten, Uhr/Stoppuhr, Sockel, Transmog u. a.
Fenster, die es in Forever nicht gibt (Garnison, Pakt, Azerit …), stehen in der Liste nicht drin bzw. werden einfach übersprungen.

### 3.2 Automatisch erkannt

- Alle Fenster, die das Spiel selbst als „Fenster“ führt (Blizzards Tabelle `UIPanelWindows`, wird nur gelesen, nie geändert).
- Jedes Mal, wenn Blizzard ein Teil nachlädt (`ADDON_LOADED`), wird neu nachgesehen.
- Nur Fenster, die es wirklich gibt, werden angefasst. Neu gefundene Fenster schreibt das Debug-Log mit.

### 3.3 Ausgenommen

- Taschen (`ContainerFrame…`): Blizzard ordnet sie selbst an, Bagnon ersetzt sie.
- **Weltkarte**, solange Leatrix_Maps geladen ist (macht sie selbst verschiebbar).
- Fenster fremder Addons.
- Hinweis-Leisten oben am Bildschirm (UIWidget-Rahmen), Bereitschaftscheck, Todesbericht u. ä. kleine Einblendungen – vorerst nicht, kann man später ergänzen.

## 4. Bedienung

| Aktion | Wirkung |
|---|---|
| Titelleiste mit links ziehen | Fenster verschieben (oberer Streifen von etwa 25 Punkten; Schließen-Knopf und andere Knöpfe dort funktionieren normal) |
| Strg + Mausrad über dem Fenster | Größe 50–200 % in 5-%-Schritten |
| Umschalt + Rechtsklick auf die Titelleiste | Position **und** Größe zurück auf Blizzards Standard |

- Fenster bleiben immer ganz auf dem Bildschirm (nicht hinausschiebbar).
- Position und Größe gelten **accountweit** (gleicher Bildschirm für alle Charaktere).
- Nur die Größe ändern speichert keine Position: das Fenster bleibt dann in Blizzards Anordnung (nebeneinander usw.).
- Das Spiel stellt viele Fenster beim Öffnen selbst wieder an „seinen“ Platz und schiebt sie nebeneinander. Peon_Mover setzt verschobene Fenster danach jedes Mal zurück an deine Position. Folge: Ein verschobenes Fenster rückt nicht mehr automatisch zur Seite, wenn ein zweites aufgeht – es kann sich überlappen (so ist es auch bei BlizzMove).

## 5. Optionsseite (Einstellungen > AddOns > Peon > Mover)

- Haken **„Fenster verschieben erlaubt“** (= Sperre, Standard an).
- **Fensterliste** (Kern-Liste): Fenster (deutscher Name, wo bekannt, sonst Name des Spiels), Herkunft (Blizzard / Peon), Status (Standard / verschoben / Größe x %), an/aus. Zeile wählen → Knöpfe **„An/Aus“**, **„Zurücksetzen“**; darunter **„Alle zurücksetzen“** (mit Rückfrage).
- In der Liste stehen die gefundenen Fenster; Fenster, die das Spiel erst beim ersten Öffnen lädt, erscheinen danach. Gespeicherte, aber gerade nicht geladene Fenster stehen grau darin. Rechtsklick auf eine Zeile = an/aus.
- „Standardwerte wiederherstellen“ lässt die Fensterpositionen stehen (dafür gibt es „Alle Fenster zurücksetzen“, auch per `/peon mover zuruecksetzen`).

## 6. Technik und Risiken (kurz)

1. **Nichts von Blizzard ersetzen**: nur nachträglich mitlesen (`hooksecurefunc`, `HookScript`), keine Blizzard-Tabelle neu zuweisen oder ändern (Lehre aus Broker 0.4.0).
2. **Kampf**: Manche Fenster sind im Kampf geschützt. Peon_Mover verschiebt oder vergrößert sie im Kampf nicht; was ansteht (z. B. ein im Kampf geöffnetes Fenster an deine Position setzen), wird **nach dem Kampf** nachgeholt. Ziehen im Kampf bei einem geschützten Fenster: einmal Hinweis im Chat.
3. **Gespeichert** wird die Position relativ zum Bildschirm (Ecke + Abstand) und die Größe; beim Öffnen des Fensters und wenn das Spiel es neu setzt, wird sie wieder angewendet.
4. **Peon-Fenster** (Broker, Ledger, Feedback, Fishing-Fänge) sind schon verschiebbar und merken ihre Position selbst. Vorschlag: Sie melden sich mit einer Zeile beim Mover an – **Kern-Erweiterung API 11** `Peon.RegisterWindow(frame, { key, title, reset = fn })` (wie die Feedback-Bereiche, abgesichert per `if`). Der Mover bringt dann Größe, Zurücksetzen und den Eintrag in der Fensterliste; die Position speichert weiter das Modul. Broker bleibt am Auktionshaus angedockt und wandert mit, wenn das Auktionshaus verschoben wird; ebenso die Broker-Box am Berufsfenster.

## 7. Bauabschnitte

- **M1** Grundgerüst aus `vorlage\Peon_Beispiel`, feste Liste + automatische Erkennung, Verschieben an der Titelleiste, dauerhaft speichern, Kampf-Schutz.
- **M2** Größe (Strg + Mausrad), Zurücksetzen (Umschalt + Rechtsklick).
- **M3** Optionsseite mit Sperre und Fensterliste, Bereiche für Peon_Feedback.
- **M4** Peon-Fenster: Kern API 11 (`Peon.RegisterWindow`), Anmeldung in Broker, Ledger, Feedback, Fishing.

M1–M3 können zusammen geliefert werden. Test vorher mit lua5.1 und nachgebauter WoW-API (Verschieben, Speichern, Kampf-Warteschlange, Nachladen).

## 8. Entschieden (KarloDerBaer, 06.10.2026)

1. Position und Größe **accountweit**.
2. Umschalt + Rechtsklick setzt **Position und Größe** zusammen zurück.
3. Peon-Fenster über die Kern-Erweiterung (6.4) einbinden – ja (Bauabschnitt M4).

## 9. Im Spiel prüfen (0.1.0)

- Lassen sich Charakter, Zauberbuch/Talente, Händler, Post, Bank, Auktionshaus, Berufe an der Titelleiste ziehen? Erkennt der Streifen (26 Punkte) die Titelleiste richtig?
- Bleiben verschobene Fenster nach dem erneuten Öffnen, nach `/reload` und nach Neustart an ihrer Stelle?
- Strg + Mausrad: ändert die Größe, ohne dass Listen im Fenster stören? Hinweis: Über einem Fenster zoomt das Mausrad die Kamera nicht mehr.
- Kampf: keine Meldung „Aktion wegen AddOn blockiert“, besonders bei Zauberbuch/Talenten und ESC-Menü.
- Fensterliste: welche Fenster wurden gefunden, fehlt eins?

## Quellen

- BlizzMove (Kiatra, GitHub): `Frames.lua` (Fensterliste mit Forever-Kennung), `BlizzMove.lua` (Erkennung Forever über Interface < 20000, Vorgehen bei geschützten Fenstern).
- KarloDerBaers WTF-Ordner und BugGrabber (Retail-Teile von Blizzard in Forever).
- kami-labs.fr: Forever nutzt denselben Client wie Retail Midnight.
