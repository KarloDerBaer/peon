# Peon – Entscheidungen

Kurzes Protokoll wichtiger Entscheidungen. Neue Einträge oben anfügen (Datum, Entscheidung, Grund).

## 06.11.2026: Feedback zurück, der Manager führt (Peon 0.13.0, Peon_Feedback 0.3.0, Manager 0.14.0)

- **Peon_Feedback kommt zurück und wird ausgeliefert.** Das löst die Entscheidung vom 31.10.2026 ab („Kein Feedback über GitHub oder das Programm“), weil der Weg über den Worker jetzt ohne Aufwand für Nutzer besteht (KarloDerBaer).
- Das Addon ist nur noch ein Zusatz für Feedback im Spiel. Schreiben, Ändern und Löschen geht auch im Manager, Fehler bekommen dort Notizen und lassen sich löschen (KarloDerBaer).
- Der Export als Text entfällt, alles läuft gesammelt im Repo `peon-fehler` zusammen (KarloDerBaer). Der Reiter heißt „Rückmeldungen“ (KarloDerBaer, Vorschlag Claude).
- **Der Manager führt, das Spiel liefert nur an.** Zwei gleichberechtigte Listen abzugleichen wäre fehleranfällig. Was eingelesen ist, löscht das Spiel beim nächsten Laden (Claude).
- **Ein Issue je Eintrag** statt eines Sammelberichts, damit sich Bearbeitetes einzeln schließen lässt. Höchstens 20 je Senden, der Rest bleibt für das nächste Mal (Claude, zugestimmt).
- Der Charakter wird nicht übernommen, Zone und Markt schon, weil sie bei der Fehlersuche helfen (Claude, zugestimmt).
- Die Bereiche speichert der Kern in `PeonDB`, statt sie im Manager fest einzutragen oder aus Lua-Dateien zu lesen, damit sie immer zu Version und Sprache passen (Claude).

## 06.11.2026: Fehlerspeicher im Kern, Reiter Debug, Berichte über einen Worker (Peon 0.12.0, Bridge 0.5.0, Manager 0.13.0)

- Abgefangene Fehler speichert der Kern selbst, statt sie an BugSack weiterzugeben. Der Manager zeigt sie im Reiter Debug, für alle sichtbar, dazu BugGrabber-Einträge mit Peon-Bezug. Im Chat bleibt ein kurzer Hinweis (KarloDerBaer).
- Berichte gehen ohne Konto und Token über einen Cloudflare Worker in ein privates GitHub-Repo, zusätzlich gibt es den Export als Text. Nach dem Senden oder auf Nachfrage beim Export wird der Speicher geleert (KarloDerBaer).
- Das Leeren läuft über `Data.lua` der Bridge statt über eine eigene Austauschdatei des Kerns, weil dieser Weg schon besteht und der Manager SavedVariables nicht schreiben darf: Das Spiel überschreibt sie beim Ausloggen (Claude).
- Geleert wird bis zum spätesten bekannten Fehler statt bis zur aktuellen Uhrzeit. So bleibt ein Fehler erhalten, der in der laufenden Sitzung entstand und noch nicht auf der Platte steht (Claude).
- Namen und Pfade werden schon beim Einlesen ersetzt, die BugGrabber-Spalte `locals` wird nie übernommen, damit private Daten gar nicht erst in einen Bericht gelangen können (Claude).

## 05.11.2026: Gegenstands-Tooltip über die Blizzard-API (Peon Manager 0.12.0)

- Der Broker Client zeigt einen Tooltip mit den Werten eines Gegenstands, Daten aus der Blizzard-API, wenn ein Zugang eingetragen ist (KarloDerBaer).
- Gespeichert wird der fertige Tooltip statt der ganzen Antwort, das hält die Datenbank klein. Neue Gegenstände bringt der Einleser mit, alle anderen werden erst beim Ansehen geholt, statt Tausende auf Vorrat abzufragen (Claude).
- Classic-Daten werden angezeigt, wenn Forever den Gegenstand nicht kennt, aber immer gekennzeichnet, weil Werte abweichen können. Bei Zusätzen steht ein Hinweis, statt Werte vorzutäuschen (Claude).
- Vorerst keine Symbole: Sie bräuchten je Gegenstand eine zweite Abfrage und Bilder aus dem Netz, die Oberfläche lädt bisher nichts von dort (Claude).

## 05.11.2026: Rückmeldungen nach dem Start (Broker 0.33.1, Ledger 0.10.2, Fishing 1.5.2, Peon 0.11.1)

- **Schnellkauf im Radar braucht wieder zwei Klicks.** Das Spiel erlaubt `StartCommoditiesPurchase` nur direkt aus einem Klick, ein Preis vorab ist also nicht möglich. Das ersetzt die Entscheidung vom 03.10. (Schnellkauf mit einem Klick). Der Code bleibt vorerst abgeschaltet im Addon, weil über das Entfernen KarloDerBaer entscheidet (Claude).
- **Neues Angel-Set nur mit Haupt- und Nebenhand**, Hinweis auf weitere Ausrüstung (KarloDerBaer). Vorhandene Sets bleiben unverändert, damit nichts Eingestelltes verloren geht (Claude).
- Einzelne Werte zeichnet der Diagramm-Baustein selbst als Punkt, weil das für jedes Modul gilt und nicht nur für Ledger (Claude).

## 05.11.2026: Einleser der Blizzard-API, AHledger entfernt (Peon Manager 0.11.0)

- **AHledger fliegt ganz raus**, die Blizzard-API ersetzt es (KarloDerBaer). Das Design `Peon_Client_Design.md` nennt AHledger noch, gilt dort aber nicht mehr.
- **Häuser wählt man unter Quellen**, standardmäßig keines. Ein Knopf „Vorschlag“ wählt, was die Addons über Regelsatz, Region und Fraktion wissen. Ohne Zugang steht dort ein Link zu den Einstellungen (KarloDerBaer).
- **Abgefragt wird nur, wenn ein neuer Stand zu erwarten ist**, statt alle 10 Minuten: eine Stunde nach dem letzten Stand, danach alle 5 Minuten, bis er da ist (KarloDerBaer fragte nach dem Sinn von 10 Minuten).
- Der Scan-Vergleich geht beim Vorschlag vor dem Regelsatz, weil nur Normal (PvE) belegt ist (Claude).
- API-Stände werden als Momentaufnahmen wie Scans gespeichert und nur über `art` unterschieden, statt alle Abfragen zu ändern (Claude). Beim Absatz haben sie Vorrang, Scans und API werden nicht miteinander verglichen, weil Scans keine Nummern haben (Claude).
- Gegenstände mit Zusatz: Fehlt der Grundname wegen eines Fehlers bei Blizzard, wird der Stand später eingelesen, statt einen Schlüssel anzulegen, der nie zu den Scans passt (Claude).

## 05.11.2026: Blizzard-API unter Einstellungen, Beobachter (Peon Manager 0.11.0)

- Zugang und Prüfung ziehen nach Einstellungen, weil die API auch für andere Module als den Broker Client taugen kann, zum Beispiel Ledger (KarloDerBaer).
- Offene Fragen zu Takt, Feldern und Angebotsnummern klärt ein Beobachter im Manager, statt eines eigenen Testprogramms. Er sieht das Secret nur im Hauptteil, und seine Abfragen kann der spätere Einleser übernehmen (Claude).
- Der Beobachter läuft nur in der Testfassung über eine Umgebungsvariable, weil er je Stand etwa 30 Abfragen macht und die Antworten ablegt. Nutzer sollen das nicht nebenbei bekommen (Claude).
- Eine Anleitung zum Anlegen des Zugangs und die Nutzung durch Ledger kommen später (KarloDerBaer).

## 05.11.2026: Neue Standardwerte im Tooltip (Tooltip 0.7.3)

- Abstand zum Mauszeiger 40 statt 20, Tooltip von Einheiten verschwindet standardmäßig sofort (KarloDerBaer).
- Gespeicherte Werte, die noch den alten Standardwerten entsprechen, werden einmalig umgestellt, weil ein neuer Standard sonst bei niemandem ankäme, der schon gespielt hat. Selbst gewählte Werte bleiben (Claude).

## 04.11.2026: Blizzard-API, erst prüfen, dann einlesen (Peon Manager 0.10.0)

- Zuerst nur ein Prüfabruf, der Einleser folgt passend zu den echten Daten, weil nicht bestätigt ist, dass Forever Auktionen liefert (KarloDerBaer).
- Der Prüfabruf liegt im Manager, damit auch Freunde ihn nutzen können. Jeder trägt einen eigenen Zugang ein (KarloDerBaer).
- Der Zugang liegt nur verschlüsselt im Datenordner, die Oberfläche bekommt ihn nie zurück, und ohne verfügbare Verschlüsselung wird er nicht gespeichert (Claude).

## 04.11.2026: Erstes Release zum Start von Forever

- Das erste Release erscheint noch vor dem Start, damit ein Freund pünktlich installieren und beim Testen helfen kann (KarloDerBaer). Das Risiko, dass nach dem Start etwas nicht passt (zum Beispiel die Interface-Nummer), fängt eine neue Version auf: Der Manager kann sie verteilen, weitere Releases am selben Tag heißen `vJJJJ.MM.TT.2`.
- Beim ersten Release bleibt „Was ist neu“ leer, weil die Changelogs für eine Erstinstallation zu technisch sind (KarloDerBaer).
- Die README zeigt ein Bild vom Manager aus einem Testordner und den Link zu Buy Me a Coffee (KarloDerBaer).

## 04.11.2026: Umzug auf den Installer (Peon Manager 0.9.1)

- KarloDerBaer nutzt jetzt die installierte Fassung mit Daten im Standard-Datenordner, also dasselbe wie alle anderen, und vor dem ersten Scan (KarloDerBaer). Der frühere Ordner bleibt als Sicherung, die Addons bleiben Junctions.
- Der Manager prüft Data.lua auf der Platte, statt sich auf seinen eigenen Merker zu verlassen. Anlass: Ein Selbsttest ohne eigene Einstellungen fand den echten WoW-Ordner und schrieb dort Data.lua ohne Kanäle (Claude).
- Selbsttests laufen deshalb immer mit eigener `settings.json`, deren `wowDir` auf einen Testordner zeigt.

## 04.11.2026: Installer und Selbst-Update, Schritt I (Peon Manager 0.9.0)

- Selbst-Update liest aus dem Ordner des Release (`generic`) statt über den GitHub-Weg von electron-updater, weil dieser Tags wie v2026.11.04 nicht als Versionen annimmt (im Code nachgelesen). Der Manager kennt den Ordner ohnehin aus dem Manifest (Claude).
- Die neue Version wird im Hintergrund geladen, eingespielt wird nur per Klick, auch nicht beim Beenden. Das passt zu „installiert wird nur per Klick“ (Claude, Design: fragt vor dem Neustart).
- Der Umzug von `<Programmordner>` in den Standard-Datenordner ist kein Code, weil es ihn nur einmal bei KarloDerBaer braucht und kein privater Pfad ins Repo gehört (Claude).

## 04.11.2026: Addons installieren, Schritt H (Peon Manager 0.8.0)

- **Der Manager sucht beim Start und alle 6 Stunden, installiert aber nur per Klick** (KarloDerBaer). So ändert sich nichts ungefragt, etwa während WoW läuft.
- Entfernen verschiebt den Addon-Ordner in die Sicherung statt ihn zu löschen. Das Design sagt „löscht den Ordner“, die Sicherung ist vorsichtiger und kostet kaum Platz (Claude). Alte Sicherungen werden noch nicht automatisch aufgeräumt.
- Laufendes WoW sperrt nichts, der Manager warnt nur (Design 5.4, Punkt 7).
- Der Willkommens-Vorschlag entfällt, sobald Peon installiert ist, auch bei Installation von Hand oder per Junction (Claude).
- Meldet GitHub kein Release, vergisst der Manager das alte Manifest, weil dessen Dateien nicht mehr zu laden wären. Scheitert die Suche nur (Netz, kaputte Antwort), bleibt der letzte gute Stand (Claude).
- Die Abnahme mit dem echten Release bleibt offen, bis es das erste Release gibt. Geprüft wurde mit einem Paket aus `build_release` über einen lokalen Server und einem Testordner (Claude).

## 31.10.2026: Manager-Module, Schritt G (Peon Manager 0.7.0)

- **Eigene Datenbankdatei je Manager-Modul** (KarloDerBaer): `broker-client.db` für den Broker Client, `peon.db` für den Manager. „Daten löschen“ löscht so einfach die Datei des Moduls. Die alte `peon.db` zieht einmalig um (Claude).
- Wer vor 0.7.0 schon Einstellungen oder Daten hatte, behält den Broker Client aktiv. Neue Nutzer starten ohne Modul (Design 5.2, 5.5).
- Übersicht, Gegenstände, Chancen und Quellen gehören zum Broker Client und erscheinen nur mit ihm. Ohne Modul zeigt der Manager „Module“ und „Einstellungen“ (Claude).
- Ohne aktives Modul schreibt der Manager `channels = {}` in Data.lua, damit eine installierte Bridge sicher nichts aufzeichnet. Ohne Bridge schreibt er nichts (Claude).
- Fehlende Addons eines Moduls zeigt die Ansicht „Module“ nur an. Installieren kommt mit Schritt H (Claude).

## 31.10.2026: Keine privaten Daten im Repo

- Im öffentlichen Repo steht für den Besitzer nur **KarloDerBaer**, auch in Entscheidungen, Changelogs und Code-Kommentaren (KarloDerBaer). Die Addons bekommen dafür keine neue Version, weil sich nur Kommentare ändern und es noch kein Release gab (KarloDerBaer).
- **Keine Pfade des eigenen Rechners** im Repo. Doku nutzt Platzhalter, die echten Pfade stehen in `CLAUDE.local.md`, das Junction-Skript liest den AddOns-Ordner aus `scripts\local.json`. Beide Dateien sind nicht im Repo (KarloDerBaer, Umsetzung Claude).
- Der Peon Manager nimmt als Standard für den WoW-Ordner den üblichen Ort von Battle.net (`C:\Program Files (x86)\World of Warcraft\_forever_`). Wer WoW woanders hat, stellt es in den Einstellungen ein, die automatische Suche kommt mit Phase 2 (Claude).
- Das Repo auf GitHub wird gelöscht und mit einem einzigen Commit neu angelegt, damit die alten Commits mit Namen und Pfaden wirklich weg sind (KarloDerBaer). Löschen macht KarloDerBaer selbst.

## 31.10.2026: Erstes Release erst mit fertigem Manager

- Das erste Release kommt erst, wenn der Peon Manager mit Installieren, Aktualisieren und Selbst-Update fertig ist, also nach G, H und I. Freunde bekommen Peon damit vermutlich erst nach dem Start von Forever (KarloDerBaer).
- Das Skript für Zips und Manifest (F1) kommt trotzdem zuerst, weil der Manager genau dieses Manifest zum Installieren liest (Claude).
- WoW Forever läuft als `Wow.exe` im Ordner `_forever_` (geprüft, offener Punkt aus dem Design geklärt).

## 31.10.2026: GitHub, Schritt E (Ledger 0.10.1)

- Repo heißt **peon** unter dem Konto KarloDerBaer, öffentlich, Lizenz **MIT** mit KarloDerBaer als Inhaber (KarloDerBaer).
- **Alle persönlichen Daten ersetzt** (KarloDerBaer): Kontoname, Battle.net-Kontonummer und Charakternamen durch erfundene Namen gleicher Länge (Mirel Dorna, Borin, Venla-Ostra), auch in den echten Testdaten, damit Breiten und Sortierungen in den Tests gleich bleiben (Claude). Die lokalen Commits wurden vor dem ersten Push zu einem zusammengefasst, damit die alten Namen nicht im Verlauf stehen (KarloDerBaer).
- **Autor KarloDerBaer** in allen Addons (`## Author`), in der Vorlage und im Peon Manager (KarloDerBaer). Ohne neue Versionen, weil sich nur die Autor-Zeile ändert und es noch kein Release gab (KarloDerBaer).
- **Peon_Bridge kommt nicht ins erste Release** (Design 6.2, `managerOnly`): Ohne Manager zeichnet sie nichts auf, und ohne die nie ausgelieferte Data.lua meldet das Spiel eine LUA_WARNING. Der Manager legt den Platzhalter später beim Installieren an.
- **Kein Discord-Link** in der README, Feedback über Issues im Repo (KarloDerBaer).
- Die Tests auf GitHub laufen ohne `npm ci`, weil der Rechenkern des Managers nur Node braucht. Das spart den Download von Electron (Claude).

## 31.10.2026: Umsetzung Phase 1, Schritte A bis D (Bridge 0.4.0, Broker 0.33.0, Peon Manager 0.6.0)

- Doku je Modul in Stand (kurz) und Changelog (Verlauf) geteilt. Notizen zu Tests stehen im Changelog bei der Version, zu der sie gehören. Der Verlauf von Peon_Feedback liegt mit dem Addon im Archiv (Claude).
- Zeilenenden im Repo bleiben wie im AddOns-Ordner (LF), nur `.cmd` mit CRLF, damit Git die Addon-Dateien nie umschreibt (Claude).
- `scripts\junctions.cmd` ersetzt einen echten Ordner nur, wenn alle Dateien per Prüfsumme gleich sind, und verschiebt ihn vorher ins Archiv. `Data.lua` der Bridge zählt beim Vergleich nicht (Claude).
- Die Bridge meldet sich ohne Freischaltung gar nicht erst bei Broker an. So hat Broker ohne Manager keine Zusatzarbeit beim Scan (Claude).
- Kanäle werden beim Laden einmal geprüft. Eine neue Freischaltung wirkt nach dem nächsten Reload, wie jede neue Data.lua (Claude).
- Brokers interne Namen (`src = "client"`, `D.ClientBand`) und Texte („Üblich (Client, n Tage)“) bleiben, nur das Modul heißt `bridge` (Design 4.1).
- Programm nach `<Programmordner>\Runtime`, Daten nach `<Programmordner>\DB` mitgezogen (KarloDerBaer). Eine Einstellung „Datenordner“ gibt es nicht, der Ordner ergibt sich aus der Lage der exe. Umzug kostete nichts, weil es nach dem Wechsel zu `_forever_` noch keine Datenbank gab.
- Solange es keine Manager-Module gibt (Phase 2), schaltet der Manager den Kanal broker immer frei (Claude).
- WoW Forever ist bis zum Start nicht spielbar. Prüfungen im Spiel stehen in der Prüfliste erster Spieltag (KarloDerBaer).

## 31.10.2026: Peon auf GitHub, Peon Manager, Peon_Bridge (Design `Peon_GitHub_Design.md`)

- Peon kommt in ein **öffentliches GitHub-Repo** (Addons, Programm, Tests, Doku), Versionen als GitHub Releases, damit KarloDerBaer es Freunden geben kann (KarloDerBaer).
- **Kein Feedback über GitHub oder das Programm.** Zu aufwendig für ein paar Freunde. Peon_Feedback kommt nicht ins Repo und wird archiviert, Feedback läuft über einen Kanal auf KarloDerBaers Discord oder das Repo (KarloDerBaer). Die Kern-Funktion `Peon.SetFeedbackAreas` bleibt (API nie ändern).
- Das Programm heißt **Peon Manager** und installiert und aktualisiert Addons und Manager-Module. Die bisherigen Funktionen werden das Manager-Modul **Peon Broker Client** (KarloDerBaer).
- **Manager-Module als mitgelieferte, abschaltbare Teile** (Variante B) statt nachgeladenem Code: Electron selbst ist fast die ganze Größe, ein getrennter Download spart nichts, und es gibt keine Versionsprobleme zwischen Manager und Modulen (KarloDerBaer, Vorschlag Claude).
- Addon Peon_Client heißt **Peon_Bridge**, weil es die allgemeine Verbindung zwischen Spiel und Manager ist und nicht nur zu Broker gehört (KarloDerBaer). Inhalte melden sich als Kanäle an, der Manager schaltet sie über `Data.lua` frei, damit niemand ohne Broker Client Scans in WTF ansammelt (Claude). Jetzt umbenennen, weil in `_forever_\WTF` noch keine Peon-Daten liegen (Claude).
- Das Repo wird die maßgebliche Quelle für den Addon-Code, der AddOns-Ordner zeigt per Junction darauf (Claude). Die doppelte Pflege der Doku im Claude-Projekt endet nach dem Umzug (Claude, Teil des Plans).
- Aufräumen, Git, Repo, Umbenennung und ein erstes Release vor dem Start, Manager-Funktionen danach (KarloDerBaer). Umsetzung mit **Claude Code** auf KarloDerBaers PC (KarloDerBaer).

## 25.10.2026 – Peon Client 0.5.0

- Englische Texte bleiben vorerst aus: Das wäre ein eigener Schritt über alle Ansichten, KarloDerBaer spielt deutsch (Claude, KarloDerBaer kann es jederzeit anstoßen).
- Der übliche Bereich im Diagramm zeigt je Tag den Stand, den Broker an diesem Tag bekommen hätte, statt eines festen Bands mit dem heutigen Wert (Claude).

## 25.10.2026 – Umzug in die Release-Version `_forever_`

- Die Beta ist beendet. Gearbeitet wird ab jetzt in `<WoW-Ordner>` (KarloDerBaer). Im Beta-Ordner waren Dateien schreibgeschützt.
- Nur die Peon-Addons ziehen um, fremde Addons kommen über CurseForge (KarloDerBaer).
- Frisch anfangen: keine Einstellungen oder Daten aus der Beta im Spiel (KarloDerBaer), neue Datenbank im Peon Client, die alte bleibt als `DB_beta` liegen (KarloDerBaer).
- Tests hängen nicht mehr an KarloDerBaers Spieldaten: test_fish nutzt eine feste Kopie der Beta-Einstellungen im Projektordner (Claude).

## 23.10.2026 – Absatz und Chancen, C6 (Programm 0.4.0, Peon_Client 0.3.0, Broker 0.32.0)

- **Der Client rechnet den Absatz und gibt ihn an Broker**, weil er alle Angebote kennt und sich das später mit Auktionsnummern aus der Blizzard-API verbessern lässt (KarloDerBaer).
- **Händlerpreis liefert Peon_Client** mit den Namen (KarloDerBaer). Alle vier Reiter (Wiederverkauf, Händler, Fallend und Steigend, Lohnend) gleich im ersten Schritt (KarloDerBaer).
- Vergleich genau nach Brokers Regeln, damit beide gleich zählen; geprüft gegen den Lua-Code (Claude).
- Broker nimmt den Absatz des Clients nur, wenn er selbst in den letzten 6 Std. unter 60 Min. beobachtet hat. Sein eigener, aktueller Wert hat sonst Vorrang (Claude).
- Wiederverkauf gilt als zweifelhaft, wenn in 14 Tagen nie nahe der Untergrenze verkauft wurde. Scherzpreise ziehen sonst den Bereich hoch und täuschen große Gewinne vor (Claude, mit Beispieldaten gesehen).
- Einzelne Vergleiche werden nach 2 Tagen zu Tageswerten zusammengefasst, sonst wächst die Datenbank mit stündlichen Scans um Gigabytes (Claude).

## 23.10.2026 – Rückgabe an Broker, C4 (Programm 0.3.0, Peon_Client 0.2.0, Broker 0.31.0)

- Der Client liefert nur den **Langzeit-Teil** des üblichen Bereichs (MITTE, SCHW, LANG, Tage). HEUTE, Richtwert, Trend und Schnäppchen rechnet Broker weiter live, weil sie vom aktuellen Scan abhängen (KarloDerBaer).
- **14 Tage und Halbwertszeit 3 Tage wie Broker**, damit beide gleich rechnen und der Wechsel nicht auffällt (KarloDerBaer). Absatz kommt später mit C6 (KarloDerBaer).
- Werte gelten 7 Tage, einstellbar 1–30 (`freshDays`); danach und bei jedem Fehler rechnet Broker selbst (Claude).
- Tageswert im Client: Mittel der Mediane aller eigenen Scans eines Tages, ohne eigenen Scan Brokers Tagesmittel (Claude).
- Neue Programmversion nur mit den geänderten Dateien eingespielt (app.asar und eine kleine Änderung an der exe), statt 320 MB zu übertragen (Claude).

## 23.10.2026 Geheime Aufrufkette (Tooltip 0.7.2, Bags 0.2.1)

- Liefert Forever die Aufrufkette als geheimen Text, wird der betroffene Gegenstands-Tooltip gar nicht geordnet, statt die Zeilen ohne Herkunft einzusortieren. So landet keine Zeile im falschen Teil, und es bleibt beim Grundsatz „geheime Werte: nichts anfassen“ (Claude).

## 22.10.2026 – Maximale Breite für Gegenstands-Tooltips (Tooltip 0.7.1)

- Lange Zeilen in Gegenstands-Tooltips werden umgebrochen, Breite einstellbar (Wunsch KarloDerBaer). Standard an mit 450 Punkten, Bereich 250–800 (Claude, bitte im Spiel prüfen und bei Bedarf anpassen).
- Umgebrochen wird durch eingefügte Zeilenumbrüche statt über Blizzards Umbruch, weil der nach dem Umschreiben der Zeilen nicht zuverlässig greift (Claude).

## 22.10.2026 – Umsetzung Broker-Verlauf und C3 (Peon Client 0.2.0)

- Gegenstandsliste standardmäßig nach Zahl der Angebote sortiert, nicht nach Wert (Median × Menge): Scherzangebote zu Millionen Gold standen sonst oben (Claude).
- Muster „Wann ist es günstig?“ in 3-Stunden-Abschnitten und erst ab 10 Scans, sonst zeigt es Zufall (Claude).
- Platz je Zeile für die Speicherschätzung wird aus der eigenen Datenbank gemessen (Suchverzeichnisse zählen mit), statt eines festen Werts (Claude).
- Rechtschreibprüfung im Programm aus, damit es keine Wörterbücher aus dem Netz lädt (Claude).
- Neue Programmversionen werden neben `Runtime` entpackt und dann getauscht; die alte bleibt als Sicherung liegen (Claude).

## 22.10.2026 – Beta geht offline: neue Reihenfolge für den Peon Client

- Die Beta-Server sind offline und werden am 23.10. abends bis zum Start abgeschaltet. Tests im Spiel gibt es bis zum Start (4./5. November) nicht mehr, vielleicht noch ein paar Scans am 23.10. (KarloDerBaer).
- **Bis zum Start wird das Programm fertig gebaut** (C3 Gegenstand mit Verlauf, C4 Rückgabe an Broker, C6 Chancen), geprüft mit den echten Daten und dem Nachbau. **AHledger, Blizzard-API und weitere Quellen erst zum Release**, ebenso die Quellenprüfung (C5) mit frischen Scans (KarloDerBaer). Die Ersatz-Prüfung über Tageswerte (Broker gegen AHledger-Verlauf) entfällt.
- **Brokers Tages- und Wochenwerte werden eine eigene Quelle im Client** („Broker-Verlauf“, gekennzeichnet als Mittel der Scans je Tag), damit der Verlauf von Anfang an Tiefe hat (KarloDerBaer).
- Alles, was ab jetzt im Spiel läuft (Broker, Peon_Client), ist bis zum Start nur mit dem Nachbau geprüft; Änderungen an Broker klein halten und immer mit Rückfall auf die eigene Rechnung (Claude).

## 22.10.2026 – Umsetzung C2: Programm Peon Client 0.1.0

- **Electron 44 mit eingebautem SQLite** (`node:sqlite`) statt einer zusätzlichen Datenbank-Bibliothek: keine Teile, die für Windows eigens gebaut werden müssen (Claude, im ersten Bauabschnitt getestet wie im Design vorgesehen).
- **Angebote je Momentaufnahme gepackt** in der Tabelle der Momentaufnahmen statt einer Zeile je Angebot (Abweichung vom Design 7.1): etwa zehnmal kleiner, alles bleibt neu berechenbar; die Kennzahlen je Gegenstand stehen in `item_snap` (Claude).
- **AHledger wird schon für den Vorschlag abgerufen**, nicht erst nach Bestätigung, damit bis zur Quellenprüfung Daten da sind; angezeigt wird es nur zum Vergleich (Claude).
- Größte Preisänderungen in der Übersicht nur ab 1 Silber und 3 Stück, sonst überwiegen Zufallswerte (Claude).
- Schrift Barlow im Programm enthalten, weil die Oberfläche nichts aus dem Netz lädt (Claude).

## 22.10.2026 – Große Zahlen in Texten (Broker 0.30.2)

- Geldbeträge und Auktionsnummern werden nie mit `%d` geschrieben, weil Forever-Lua dort bei 2^31 abbricht. Regel im Überblick, Nachbau der Grenze im Test (Claude).
- Scheitert ein Scan-Schritt, beendet Broker den Scan und merkt die Meldung (0.30.1), damit Fehler nachlesbar sind, auch ohne Chat (Claude).

## 22.10.2026 – Platzhalter Data.lua (Peon_Client 0.1.1)

- Das Spiel meldet eine fehlende TOC-Datei als LUA_WARNING. Statt eines eigenen Datenordners liegt in Peon_Client eine leere Data.lua als Platzhalter, die nie ausgeliefert und vom Client überschrieben wird (Claude, hält die Entscheidung „im Ordner von Peon_Client“).

## 22.10.2026 – Umsetzung C1: Peon_Client 0.1.0, Broker 0.30.0

- Broker meldet Momentaufnahmen über eine Zuhörer-Schnittstelle, Peon_Client macht daraus das Format (Claude). Broker kennt so das Format nicht und bleibt ohne Peon_Client unverändert. Ein Zuhörer mit Fehler wird entfernt, damit ein Fehler im Client nie den Scan stört (Claude).
- Reine Gebote kommen mit in die Momentaufnahme, wie bei Blizzard, auch wenn Broker sie nicht auswertet (Claude).
- Namen gehen mit jedem Scan mit, bis der Client sie einmal bestätigt hat, danach nur noch neue (Claude). Varianten tragen ihren vollen Namen in der Zeile.
- Dieselbe Live-Abfrage mit gleichem Ergebnis wird innerhalb 60 Sek. nur einmal abgelegt (Radar fragt oft nach) (Claude).
- `Data.lua` steht in der TOC, wird aber nie ausgeliefert, damit ein Update die Werte des Clients nicht überschreibt (KarloDerBaer, Design 6.5).

## 22.10.2026 – Peon Client (Programm für Windows), Design `Peon_Client_Design.md`

- Begleitprogramm heißt **Peon Client** und löst den Entwurf `Peon_Broker_Programm.md` ab. Hauptaufgaben: Auktionsdaten erfassen, speichern, auswerten und Schnittstelle zu Broker (KarloDerBaer).
- Technik **Electron** mit **Vue** und ECharts, Datenbank SQLite, Aussehen dunkel und modern mit Peon-Grün (KarloDerBaer, Vorschläge Claude mit Beispielen). Python verworfen: die Oberfläche wäre ohnehin HTML gewesen, Electron hält alles in einer Sprache und ist hier vollständig testbar.
- Stufe 1: Übersicht und Import, Gegenstand mit Verlauf, Ranglisten und Chancen, Rückgabe an Broker, schöne und übersichtliche Oberfläche (KarloDerBaer).
- **Quellen nach Qualität** (KarloDerBaer): eigene Scans und Blizzard-API sind Momentaufnahmen, AHledger ist eine Fremdmessung aus Scans vieler Spieler. AHledger erst nach einer Quellenprüfung (Vergleich mit eigenen Scans, noch in der Beta) je Zweck freigeben, bis dahin nur zum Vergleich. AHledger immer mit Quellenangabe und Link (Bedingung von AHledger).
- **Export im Format der Blizzard-API** (KarloDerBaer): je Angebot eine Zeile mit item, bonus, quantity, buyout, unit_price, bid, time_left, id. Völlig gleiche Angebote als eine Zeile mit Zähler (verlustfrei, weil der Scan keine Auktionsnummer liefert). Live-Abfragen kommen mit.
- **Eigenes Modul Peon_Client** im Spiel für die Schnittstelle (KarloDerBaer): Warteschlange (10 Scans, einstellbar), Knopf „An Client übergeben“ nach einem Scan, Client-Werte als `Data.lua` im Ordner des Moduls (nur vom Client erzeugt, nie ausgeliefert). Broker bekommt nur eine Zuhörer-Schnittstelle und liest die Werte über das Modul.
- **Broker nutzt Client-Werte vorrangig**, solange sie höchstens 7 Tage alt sind, sonst eigene Rechnung, Quelle sichtbar (KarloDerBaer).
- **Aufbewahrung einstellbar** mit Anzeige des aktuellen und geschätzten Speicherbedarfs, Standard 30 Tage fein (KarloDerBaer).
- Ordner: Quellcode `<Repo>\client`, Programm `<alter Programmordner>\Runtime`, Datenbank `<alter Programmordner>\DB`. Läuft im Infobereich und überwacht selbst (KarloDerBaer).

## 07.10.2026 – Anmerkungen von KarloDerBaer zu Bags, Tooltip, Ledger; Absturz Broker (Peon 0.11.0, Bags 0.2.0, Tooltip 0.7.0, Broker 0.29.0, Ledger 0.10.0)

- **Bags:** Umschalter „Nach Art“ (grau = aus, farbig = an) statt langem Text; Fenster im Stil von Blizzards Fenstern – Taschen und Bank mit Blizzards eigenen Vorlagen (KarloDerBaer).
- **Tooltip-Optionen mit Untertabs** Allgemein / Gegner / Gegenstände (KarloDerBaer, Vorschlag Claude). Dafür neuer Kern-Baustein (API 11), weil Reiter auf Optionsseiten auch andere Module brauchen können. Damit wird `Peon.RegisterWindow` für Mover M4 API 12.
- **Beispiel-Tooltips** in den Reitern Gegner und Gegenstände; Gegenstand aus den eigenen Sachen mit Pfeilen wählbar (Claude).
- **Vergleichs-Flackern:** späte Zeilen sofort ordnen, Blizzards Vergleichszeilen immer unten statt in die Teile einzuordnen (Claude, aus Blizzards Code abgeleitet).
- **Ledger:** neuer Reiter „Gegenstände“ mit allen bekannten Gegenständen (inkl. Auktionshaus), der bisherige heißt **„Umsatz“** (KarloDerBaer). Minimap-Symbol Schriftrolle `INV_Scroll_03` (Claude, KarloDerBaer wollte nur „ein anderes passendes“).
- **Ledger-Diagramme nach Einheit getrennt**: oben Preis je Stück (alles in Gold), unten Stück (links du, rechts Auktionshaus); alle Linien in der Legende, Werte-Kasten beim Überfahren (KarloDerBaer, aus zwei Vorschlägen). Ersetzt den Aufbau vom 06.10. „oben Charakter, unten Auktionshaus, je links Gold/rechts Stück, gleicher Gold-Maßstab“ – die zwei Achsen je Diagramm machten es schwer lesbar.
- **Absturz Broker:** nie `pcall` um Funktionen mit sehr vielen Rückgabewerten (z. B. `GetChildren` von UIParent) – Forever-Lua stürzt mit einer Assertion ab (Claude, Regel im Überblick).

## 07.10.2026 – Umsetzung Peon_Bags 0.1.0 (T1–T4)

- Alles in einem Zug gebaut (KarloDerBaer: „setze alles um“), Gildenbank ungetestet.
- Ein Hauptschalter für Taschen **und** Bank, eigener Schalter für die Gildenbank (Claude).
- Blizzards Bank- und Gildenbank-Fenster werden nicht versteckt, sondern in einen winzigen, sichtbaren Rahmen umgehängt – Verstecken würde die Bank schließen; Knopf „Blizzard“ holt das Fenster für den Besuch zurück (Claude).
- Taschen öffnen nur über B-Taste/Taschenknöpfe und die gewählten Fenster des Spiels; Blizzards `OpenAllBags`/`CloseAllBags` werden nicht mitgelesen, damit Händler & Co. nur nach den eigenen Haken öffnen (Claude).
- Gold der Gildenbank über eigene Rückfragen (`PEON_BAGS_GB_DEPOSIT/WITHDRAW`) statt Blizzards, weil diese erst mit Blizzards Gildenbank geladen werden (Claude).

## 07.10.2026 – Neues Modul Peon_Bags (Taschen, Bank, Gildenbank), Konzept `Peon_Bags_Konzept.md`

- Eigenes Taschen-Modul statt Bagnon, damit KarloDerBaer es anpassen kann und die Einbindung von Ledger, Broker und Mover unter eigener Kontrolle ist (KarloDerBaer).
- Name **Peon_Bags**; Reagenzientasche als **eigener Abschnitt**; Anordnung **Taschenreihenfolge oder nach Art**, umschaltbar per Knopf im Fenster (KarloDerBaer).
- **Schlank:** vorerst keine Anzeigen von Broker/Ledger im Fenster (Wert, Markierungen, Filter, Müll verkaufen) (KarloDerBaer).
- **Twinks nicht in Peon_Bags** – die Anzeige in Ledger reicht; BagBrother entfällt (KarloDerBaer).
- **Gildenbank** gleich mit vorbereiten nach Blizzards Retail-Schnittstelle, Test später (KarloDerBaer).
- Technik (Claude): Plätze aus Blizzards Taschenknopf-Vorlage (Benutzen auch im Kampf), Blizzard-Fenster nur ausblenden, kein Code aus Bagnon (All Rights Reserved), keine fremden Bibliotheken; solange Bagnon geladen ist, bleibt Peon_Bags passiv.

## 07.10.2026 – Durchsicht Broker (Broker 0.28.0)

- Alle Punkte der Durchsicht umgesetzt (KarloDerBaer): Varianten, kleine Fehler, Schnellkauf absichern, Aufräumen und Datenmenge.
- **Ausrüstung mit Zusatz je Variante getrennt, erkannt am vollen Namen** (KarloDerBaer, Vorschlag Claude). Ein Prüfbefehl war nicht nötig: die vorhandenen Daten zeigten, dass Scan, Taschen und Links den vollen Namen liefern. Schlüssel `"itemID:voller Name"` (sprachabhängig – unkritisch, KarloDerBaer spielt deDE). Alte gemischte Einträge werden beim nächsten Scan gelöscht.
- Suchschlüssel je Variante werden nebenbei gelernt; **Varianten ohne gelernten Schlüssel lässt der Radar aus**, statt sie fälschlich als „weg“ zu melden (KarloDerBaer).
- **Ledger bekommt bei Varianten den Wert der günstigsten Variante** (vorsichtig; KarloDerBaer, statt Durchschnitt).
- Schnellkauf: kein Preis vorab bei gewähltem Treffer oder offener Blizzard-Kaufansicht, und dann nie `CancelCommoditiesPurchase` – damit Broker keinen eigenen Kauf des Spielers abbricht (Claude, im Spiel nicht beobachtet, nur vorbeugend).
- Fehlersuch-Protokolle nur mit `/broker debug`; Brokers alte Buch-Listen und der Abgleich der Einstellgebühr entfallen (Claude, abgestimmt).

## 06.10.2026 – Alt+Klick öffnet den Gegenstand in Ledger (Ledger 0.9.1, Broker 0.27.1)

- Alt+Klick gehört Ledger: überall, wo ein Gegenstands-Tooltip erscheint, und auf Chat-Links; nicht auf Aktionsleisten, weil das Spiel dort zusätzlich die Taste auslöst (KarloDerBaer, aus Vorschlag Claude). Dazu eine frei wählbare Tastenbelegung für den Gegenstand unter der Maus (KarloDerBaer).
- Broker gibt Alt+Klick ab (Verkaufen, Behalten, Einkaufsliste) – KarloDerBaer nutzt dafür das Broker-Fenster.
- Belegte Kombinationen im Spiel: Umschalt+Klick, Strg+Klick, Rechtsklick; Alt+Umschalt verworfen (Gefahr „Stapel teilen“).

## 06.10.2026 – Peon_Mover 0.1.0 (M1–M3)

- Position und Größe **accountweit**; Umschalt + Rechtsklick setzt **beides** zurück; Peon-Fenster später über Kern-Erweiterung API 11 (KarloDerBaer).
- Nur die Größe ändern speichert keine Position, damit Blizzard das Fenster weiter anordnen kann (Claude).
- Zurücksetzen nutzt die mitgelesene Wunschposition von Blizzard statt Blizzards Anordnungs-Funktion aufzurufen – vermeidet Taint im Fenster-Manager (Claude).
- „Standardwerte wiederherstellen“ lässt die Fensterpositionen stehen; dafür „Alle Fenster zurücksetzen“ (Claude).
- Ausgelassen: Taschen (Bagnon) und die Weltkarte, solange Leatrix_Maps geladen ist (macht sie selbst verschiebbar) (Claude).
- Die Fensterliste zeigt nur gefundene Fenster (plus gespeicherte), nicht die ganze feste Liste – viele Retail-Fenster gibt es in Forever nicht (Claude).

## 06.10.2026 – Neues Modul Peon_Mover (Fenster verschieben), Konzept `Peon_Mover_Konzept.md`

- Eigenes Modul statt Kern, weil der Kern nur Bausteine liefert und das Modul abschaltbar bleibt (KarloDerBaer, Vorschlag Claude). Name Peon_Mover (KarloDerBaer).
- Positionen dauerhaft, Verschieben an der Titelleiste, Größe mit Strg + Mausrad, Zurücksetzen mit Umschalt + Rechtsklick, Fensterliste in den Optionen, Sperre nur in den Optionen (KarloDerBaer).
- Kein Prüfbefehl (Wunsch KarloDerBaer): Recherche ergab, dass Forever den Retail-Client nutzt und BlizzMove Forever offiziell unterstützt. Grundlage ist BlizzMoves Fensterliste (nur die Namen, eigener Code), ergänzt um automatische Erkennung über `UIPanelWindows`; die Fensterliste in den Optionen zeigt, was erkannt wurde (Claude).
- Nur Fenster, keine Aktionsleisten oder Einheitenrahmen – dafür gibt es in Forever den Bearbeitungsmodus (Claude).

## 06.10.2026 – Teile im Gegenstands-Tooltip (Peon_Tooltip 0.6.0, Konzept `Peon_Tooltip_Konzept.md`)

- Zuerst nur **Gegenstände** (KarloDerBaer); Einheiten bleiben, wie sie sind (geheime Werte im Kampf).
- **Kein Prüfschritt vorab** (KarloDerBaer): Forever verhält sich bei Tooltips wie Retail; geprüft wird erst bei Problemen, dafür gibt es `/ttp teile`.
- Name immer oben; ausgeblendete Teile sind ganz weg; Trennung als eigener Eintrag – Trennlinie oder Leerraum; jedes Peon-Modul ist ein eigener Teil, auch künftige; alles in einem Zug (KarloDerBaer).
- Neu dazu: **Rahmenfarbe bei Gegenständen** wählbar – Standard (Blizzard) oder Qualität des Gegenstands (KarloDerBaer).
- Technik (Claude): Herkunft über die Aufrufkette statt Anpassung der fremden Addons; Zeilen werden in die vorhandenen Zeilen umgeschrieben statt den Tooltip neu aufzubauen (kein erneutes Auslösen der anderen Addons); Kern bleibt unverändert.

## 06.10.2026 – Accountbank und Gildenbank in den Unterlagen

- Recherche (Blizzard-Forum): Eine Accountbank gibt es in Forever vermutlich nicht, die Gildenbank schon (100 Gold). Die Accountbank-Hinweise in den Unterlagen werden durch den Hinweis ersetzt, dass Ledger die Gildenbank noch nicht erfasst (KarloDerBaer). Die Erfassung der Gildenbank wird erst eingeplant, wenn KarloDerBaers Gilde eine hat und sie im Spiel geprüft werden kann. Der Code, der eine Accountbank mit Plätzen lesen würde, bleibt unverändert.

## 06.10.2026 – Umsetzung Reiter „Gegenstand“ (Peon 0.10.0, Broker 0.27.0, Ledger 0.9.0)

- Alle fünf Bauabschnitte in einem Zug (KarloDerBaer: „führe alle Schritte durch“).
- **Marge-Kasten** rechnet mit den Kosten des **nächsten Stücks** (wie Brokers „Unter deinen Kosten“), das Diagramm mit Kosten Ø je Tag (Claude, offener Punkt aus dem Konzept; im Spiel prüfen).
- **„Ohne Verlust ab“** = Kosten ÷ 0,95, vorerst ohne offene Einstellgebühren (Claude, einfacher; später möglich).
- **Bestand im Diagramm** aus den Kostenposten (Stück mit Posten), weil nur sie je Tag nachgerechnet werden können; die Textspalte zeigt den echten Bestand (Claude).
- **Ledger braucht Kern API 10**, weil der Reiter den Diagramm-Baustein nutzt; alle drei Addons kommen zusammen (Claude).
- Post vom Twink ohne bekannten Versand bekommt den Marktwert wie ein Anfangsbestand (Claude).

## 06.10.2026 – Reiter „Gegenstand“ in Ledger und Kosten je Charakter (Konzept `Peon_Ledger_Gegenstand.md`)

- **Ort:** Peon_Ledger, neuer Reiter „Gegenstand“ (KarloDerBaer, Vorschlag Claude) – Bestand, Kosten und Verkäufe hat nur Ledger, das Fenster geht überall auf. Diagramm als Kern-Baustein (API 10).
- **Aufbau** (KarloDerBaer, aus fünf Entwürfen): links Textspalte, rechts oben Diagramm mit den Werten des Charakters, unten Diagramm Auktionshaus; je Diagramm links Gold, rechts Stück; beide Gold-Achsen mit gleichem Maßstab. Überschrift oben = Auswahlliste Charakter (Standard eingeloggter Charakter, auch „Alle Charaktere“).
- **Vergleich Kosten/AH-Preis:** Gewinnzone (Fläche zwischen AH Min und „ohne Verlust ab“ = Kosten ÷ 0,95, grün/rot) als Standard, Marge-Streifen zuschaltbar (KarloDerBaer). Dazu Kosten als Stufenlinie, Bestand als Umriss, senkrechte Striche für Käufe/Verkäufe, Marge-Kasten in der Textspalte.
- **Zeitraum** zuletzt gewählter; zusätzlich Beute je Tag, Menge im AH (Stück) und Marktabsatz – Broker hebt den Absatz dafür so lange auf wie die Preise (KarloDerBaer).
- **Kosten je Charakter** statt accountweit (KarloDerBaer): ersetzt die Entscheidung vom 03.10. Post an Twinks nimmt die Kosten mit, Posten behalten ihr ursprüngliches Datum; Buch und Gegenstände rechnen „Nur dieser Charakter“ mit den eigenen Kosten; `mod:Cost` ohne Charakter = eingeloggter Charakter.

## 03.10.2026 – Markt-Schnäppchen nachgeschärft (Broker 0.26.0)

- Anlass (KarloDerBaer): „Abgefangene Kiste“ – Radar bot 55 Stück an, obwohl 323 Angebote im Markt lagen, der Absatz 0,0/Std. war und der Preis seit Tagen fiel.
- **Wiederverkauf höchstens zur Untergrenze des üblichen Bereichs** (KarloDerBaer, aus zwei Varianten gewählt). Ursprünglicher Vorschlag „höchstens der Vorschlag des Verkaufen-Reiters“ hätte nichts geändert: nach dem Kauf läge das günstigste Angebot im (sehr breiten) üblichen Bereich, Verkaufen schlüge dann denselben Preis vor. Bei ruhigen Märkten wird es dadurch etwas strenger (Untergrenze ≥ 5 % unter dem Richtwert).
- **Menge höchstens Absatz je Std. × 48 Std.** (KarloDerBaer; einstellbar). Nur Messungen ab gelbem ≈ zählen; rote oder fehlende Messung begrenzt nicht, zeigt aber einen Hinweis (KarloDerBaer: „erst ab gelb“).

## 03.10.2026 – Verlauf: zusammengehörige Vorgänge in einer Zeile (Ledger 0.8.1)

- Zusammengefasst werden feste Paare (Auktion eingestellt + Gebühr, Handel, Quest, Post an/von Twink) und Serien gleicher Art kurz hintereinander („Alle öffnen“, Händler, Korrekturen) – KarloDerBaer, aus Claudes Durchsicht der Daten und des Codes gewählt. Nur Anzeige; die Einträge bleiben einzeln gespeichert. Tagessummen und Abbruchkosten bleiben eigene Zeilen.

## 03.10.2026 – Darstellung Übersicht, Verlauf und Berufs-Box (Ledger 0.8.0, Broker 0.25.2)

- **Ledger-Übersicht:** Charakterliste auf 5 Zeilen verkleinert, darunter drei Blöcke Vermögen, Gewinn, Plätze (KarloDerBaer, aus zwei Vorschlägen gewählt).
- **Verlauf:** ein Herstellvorgang = eine Zeile mit Material grau dahinter, Einzelheiten im Tooltip (KarloDerBaer). Nur Anzeige, die Einträge bleiben einzeln gespeichert, damit Kosten und Buch unverändert rechnen.
- **Broker-Box am Berufsfenster** rückt automatisch hinter die Berufs-Symbolleiste statt eines festen Abstands (Claude), damit sie auch ohne Leiste direkt am Fenster sitzt.

## 03.10.2026 – Gebundenes im Vermögen zum Händlerpreis (Ledger 0.7.3)

- Seelengebundene Gegenstände (auch BoE nach dem Anlegen) kann man nur noch beim Händler verkaufen, also zählen sie im Vermögen nur mit dem Händlerpreis (KarloDerBaer). Angelegte Ausrüstung ist immer gebunden und zählt deshalb immer mit, ebenfalls zum Händlerpreis; die Option dafür entfällt (KarloDerBaer).

## 03.10.2026 – Post gehört erst beim Nehmen dazu (Ledger 0.7.2)

- Was im Briefkasten liegt, gehört noch nicht zum Bestand; Zugang erst beim Nehmen (KarloDerBaer). Ausnahme: Post an eigene Twinks bleibt als „Unterwegs“ beim Twink im Bestand, bis er sie abholt – sonst verschwände die Ware zwischenzeitlich (Vorschlag Claude, von KarloDerBaer bestätigt).

## 03.10.2026 – Post nicht mehr anzeigen (Broker 0.25.1, Ledger 0.7.1)

- Ohne Besuch am Briefkasten liefert das Spiel keinen Inhalt; Schätzungen aus Chatmeldungen („Käufer gefunden“) sind KarloDerBaer zu ungenau, und beim Öffnen wird die Post ohnehin geleert. Deshalb: Zeile „Post“ auf der Broker-Startseite und Post-Anzeige in der Ledger-Übersicht (Spalte, Gold in der Post, Post-Gold im Vermögen) entfernt. Die Erfassung beim Leeren bleibt (Buch, Kosten).

## 03.10.2026 – Ledger: Zuordnen (Kosten, Lagerwert und Handelsgewinn), Konzept `Peon_Ledger_Zuordnen.md`

- **Nachtrag (nach Rechenbeispiel):** **Älteste zuerst** (FIFO) statt Durchschnitt, damit gesammelte und gekaufte Ware getrennt bleiben (KarloDerBaer). Höchstens 30 Posten je Gegenstand, gleiche Zugänge am selben Tag zusammengefasst; Datenmenge üblich ~40 KB, viel ~500 KB – unkritisch. Tooltip zeigt Kosten des nächsten Stücks und den Durchschnitt.
- **Tooltip** (KarloDerBaer, bei der Umsetzung): Kosten ohne Umschalt und kompakt „Ledger  Kosten x (Ø y)“; Bestand und Orte rutschen unter Umschalt.
- **Begriffe** (KarloDerBaer): „Kosten“ statt „Einstand“, dazu „Lagerwert“, „Wareneinsatz“, „Handelsgewinn“, „Verbrauch“ – angelehnt an die Buchhaltung, aber ohne Fachjargon.

- Kostenlos Erhaltenes hat Einstand 0: Beute, Quests, Post von fremden Spielern und von Absendern ohne Nachname (NPCs, Systempost), Handel ohne Gegenleistung. Handel mit Gegenleistung bekommt den Gegenwert, Nachnahme-Post den bezahlten Betrag (KarloDerBaer).
- Anfangsbestand mit dem Marktpreis beim Start (Broker), sonst Händlerpreis.
- ~~Durchschnitts-Einstand~~ (durch Nachtrag ersetzt: älteste zuerst); accountweit je Realm; Post an/von Twinks ändert nichts.
- Einstellgebühren und Abbruchkosten werden dem Gegenstand zugerechnet.
- Benutzt/Zerstört = „Verbrauch“ (Info-Zeile im Buch), kein Verlust im Handelsgewinn.

## 03.10.2026 – Feedback-Liste und offene Punkte (Broker 0.24.0, Ledger 0.6.0, Feedback 0.2.0)

- **Meine Auktionen:** beim Öffnen des Reiters neu laden und automatisch live prüfen (KarloDerBaer).
- **Schnellkauf mit einem Klick:** Broker holt den Preis fürs beste Händler-Schnäppchen vorab beim Spiel, der Klick bestätigt sofort; ohne gültige Anfrage bleibt es bei zwei Klicks. Einzelgegenstände weiter ein Klick je Auktion (KarloDerBaer, Vorschlag Claude). Automatisches Bestätigen nach dem Klick wurde verworfen (Spiel blockiert es womöglich).
- **Radar „weg“ bei Gegenständen mit Zusatz:** statt aufzugeben Browse-Suche nach dem Grundnamen und Schlüssel des Spiels merken (Claude, aus dem Radar-Protokoll abgeleitet). Saubere Trennung der Zusatz-Varianten im Scan folgt, sobald `keyLog` zeigt, wie Forever den Zusatz im Schlüssel ablegt.
- **Händler-Knopf „Schnäppchen verkaufen“** entfernt (KarloDerBaer).
- **Startseite** als erster Reiter „Start“, am Auktionshaus öffnet das Fenster damit (KarloDerBaer).
- **Berufe:** Box am Berufsfenster (gewähltes Rezept, beste Rezepte) und Zeile im Tooltip; keine Spalte in der Rezeptliste (KarloDerBaer).
- **Einkaufsliste:** derselbe Umschalter „Vorrat aller Charaktere“ wie im Reiter Behalten (KarloDerBaer); Verkaufen zeigt die eigene Verkaufsquote.
- **Gestrichen als erledigt:** Abverkauf (= Absatz 0.23) und Vorschlag bei stark schwankenden Preisen (= Richtwert 0.21) (KarloDerBaer).
- **Ledger „Inventur neu“** nur für den eingeloggten Charakter; Unterschiede als „Korrektur“ (Umbuchung, zählt nicht als Gewinn) (KarloDerBaer).
- **Ledger-Lücken** alle drei geschlossen (KarloDerBaer): Erlös ohne Rechnung wird dem Verkauf zugeordnet, Auktionskauf in einer Zeile, Händlergold nach Händlerwert aufgeteilt.
- **Feedback:** Löschen links, Bearbeiten Mitte (eigenes Fenster), OK rechts (KarloDerBaer).

## 03.10.2026 – Absatzquote (Broker): Konzept `Peon_Broker_Absatz.md`

- **Nachtrag nach dem ersten Test (Broker 0.23.1, KarloDerBaer):** Angezeigt wird der **aktuelle Absatz je Stunde** (letzte 6 Std.), der 14-Tage-Wert ist nur intern. Sicherheit nach beobachteter Zeit; das Zeichen „≈“ steht **immer** da (ganz genau ist es nie) und ist rot (wenig Daten), gelb (besser), grün (gut) – grau war kaum erkennbar. Die Reichweite gehört nicht in den Tooltip, nur zum Verkaufen.
- Komplettscan gleich mit auswerten, nicht erst später (KarloDerBaer).
- Anzeige ab dem ersten Vergleich zweier Abfragen/Scans; Sicherheit farbig in drei Stufen nach Zahl der Vergleiche, Schwellen in den Optionen (KarloDerBaer). Zeitraum 14 Tage.
- Abbruch-Regel (Vorschlag KarloDerBaer): Fehlt ein Angebot vor Ablauf, obwohl ein günstigeres in beiden Abfragen/Scans unverändert stand, wurde es abgebrochen – für Massenware sicher, weil das Spiel beim Kauf immer die günstigsten Stücke zuerst nimmt; bei Einzelgegenständen „wahrscheinlich“.
- Anzeige: Tooltip mit Umschalt, Hinweis beim Verkaufen, Spalte in „Preise“.
- Einzelgegenstände (Zusätze, sehr unterschiedliche Preise): Abbruch-Regel gilt nicht; verschwunden vor Ablauf = gekauft, abzüglich einstellbarem Schätzwert für Abbrüche (Standard 10 %) (KarloDerBaer).
- Sicherheit nicht als Farbe der Zahl, sondern als Zeichen „≈“ davor (grau unsicher, gelb mittel, ohne Zeichen sicher); die Farbe der Zahl bleibt für viel/wenig Absatz (KarloDerBaer).

## 03.10.2026 – L6: Vorrat im Reiter „Behalten“, Verkaufsquote und Absatzquote getrennt

- **Behalten** (Broker) bekommt den Vorrat aus Ledger, mit **Umschalter im Reiter**: nur dieser Charakter / alle Charaktere (KarloDerBaer). Ohne Ledger wie bisher (Taschen + Bank).
- **Zwei getrennte Werte** (KarloDerBaer): **Verkaufsquote** = eigene Verkäufe (Ledger: verkauft ÷ (verkauft + zurück)); **Absatzquote** = was der Markt umsetzt, ermittelt Broker aus seinen Scans/Abfragen. Wie beide kombiniert werden, wird später entschieden.
- Offen: ob die Absatzquote über die Auktionsnummern (auctionID) und die Restlaufzeit genauer wird – erst prüfen, was Forever bei den Abfragen liefert.

## 03.10.2026 – Ledger: kein eigener Post-Knopf (L4), Buch zurücksetzen, Buch ohne Broker-Altdaten

- **L4 „Post einsammeln“ entfällt** (KarloDerBaer): Ledger erfasst die Post auch beim Blizzard-Knopf „Alle öffnen“ zuverlässig (seit 0.3.1 mit Brief-Warteschlange und Abgleich Post ↔ Taschen); ein eigener Knopf bringt keinen Mehrwert. Die Rechnungen (Erlös, Anteil, Menge) werden beim Holen gelesen.
- **Knopf „Buch zurücksetzen“** in den Optionen (KarloDerBaer): Verlauf und Wochensummen des Realms löschen, aktuellen Stand neu lesen, er wird der neue Anfangsbestand.
- **Brokers alte Listen** (eingestellt, abgebrochen, gekauft) werden **nicht** ins Buch übernommen (Vorschlag Claude bei L5): Sie haben keinen Charakter und keine Verkäufe, und KarloDerBaer fängt mit dem Zurücksetzen bei null an. Lässt sich später nachholen.
- **Buch:** Gewinn = Einnahmen − Ausgaben − Gebühren, nur Gold, Umbuchungen zählen nicht. Auktionshaus-Verkäufe mit dem erhaltenen Betrag (Anteil schon abgezogen, zur Info angezeigt); Gebühren = gezahlte Einstellgebühren und Abbruchkosten.
- **Verkaufsquote** = verkauft ÷ (verkauft + zurück) in Stück, 30 Tage, ab 3 Stück. Verkauft aus den Rechnungen (Menge), zurück aus den Briefen „abgelaufen/abgebrochen“. Verschwindet eine Auktion ohne „verkauft“, gibt es keinen Eintrag mehr („Auktion beendet“ bis 0.3.2) – der Brief entscheidet.

## 02.10.2026 – Neues Modul Peon_Ledger (Bestand und Buch)

- Post einsammeln und Buch wachsen über das Auktionshaus hinaus: KarloDerBaer möchte alles erfassen (auch Herstellen, Verbrauch, Händler, Handel, Post, Zerstören; Rest „verbraucht/sonstiges“), einen Ist-Zustand zu Beginn und die Bestände der Twinks wie in Taschen-Addons.
- Deshalb eigenes Modul **Peon_Ledger** mit Bestand, Bewegungen, Gold, Post einsammeln und Buch. Broker liest daraus nur (Vorrat aller Charaktere, Verkaufsquote), abgesichert, beide laufen auch allein. Verworfen: alles in Broker (zu groß) und „Bestand neu, Buch in Broker“ (Schnittstelle in beide Richtungen).
- Name: Peon_Ledger (KarloDerBaer).
- Konzept abgestimmt: Brokers Reiter „Buch“ entfällt, Ledger bekommt eigenen Minimap-Button; angelegte Ausrüstung zählt zum Bestand; Vermögen mit dem Wert aus Zeile 1 des Broker-Tooltips; Tooltip kurz, Aufteilung mit Umschalt; Beute-Gold je Tag zusammengefasst; Erfassung nur ereignisgesteuert (nur geänderte Taschen nach `BAG_UPDATE_DELAYED`, Auswertung im Kampf erst danach), kein regelmäßiger Scan.
- Übernommen aus der Broker-Abstimmung: nur Auktionshaus-Post, nur per Knopf; 90 Tage einzeln, danach Wochensummen; Gewinn zuerst je Zeitraum, „Zuordnen“ (Einstand) später, Daten dafür von Anfang an.

## 02.10.2026 – Richtwert und üblicher Bereich (Broker 0.21.0)

- Preisfindung nach Börsen-Vorbild (gleitender Mittelwert mit Schwankungsband, robuste Maße), ausgearbeitet als Rechenmodell Kapitel 7 und mit KarloDerBaer abgestimmt: 14 Tage, Halbwertszeit 3 Tage, Bereich fest 1 × Schwankung; die 30-%-Dumping-Grenze bleibt nur als Rückfall unter 3 Tageswerten.
- Radar nutzt den Richtwert für Markt-Schnäppchen; fällt der Markt, gibt es keine Markt-Schnäppchen.
- Zeile 1 im Tooltip zeigt das günstigste Angebot (so wird eingestellt) statt des Vorschlags, mit Farbe der Marktlage: grün gut, orange Markt fällt, rot Dumping. Händlerpreis weiter, wenn der Händler mehr zahlt.
- Weitere Methoden für später: Verkaufspreis-Schätzung aus verschwundenen Angeboten (beim Abverkauf), Erwartungswert aus Verkaufsquote (mit dem Buch).

## 02.10.2026 – Broker nach dem Vergleich mit anderen AH-Addons (Broker 0.20.0)

- Vergleich mit Auctionator, TSM, Journalator, Auctioneer und aux: Broker hat die meisten Werkzeuge, ihm fehlt ein roter Faden. Beschlossen (Reihenfolge offen): Buch mit Verkaufsquote, Post einsammeln (sehr wichtig), Startseite „Was steht an?“, Abverkauf (wenn realistisch schätzbar), Herstellkosten bei Berufen, Bestände anderer Charaktere. Nicht gebraucht: Tastenbelegungen (Knopf reicht), Preisgrenzen je Gegenstand (Händlerpreis als Untergrenze reicht), Verkaufs-Durchlauf.
- Verkaufen: eingetragen wird immer das günstigste Angebot minus Unterbieten, auch bei Dumping; der Vorschlag bleibt als Richtwert mit Hinweis (Wunsch von KarloDerBaer). Untergrenze bleibt der Mindestpreis (Händler).
- Radar: weggefallene Treffer bleiben 30 Sek. grau mit Grund in der Liste und kommen ins Radar-Protokoll – damit ist sichtbar, ob ein Treffer wirklich weg ist oder ein Fehler vorliegt.
- Radar pausiert, solange ein Treffer gewählt ist, weil jede fremde Suche die Anzeige im Blizzard-Fenster verändert; nochmal anklicken hebt die Auswahl auf.
- Broker schaltet das Blizzard-Fenster beim Reiterwechsel passend um (Auktionen / Kaufen / Verkaufsfenster) und zeigt beim Klick auf eine eigene Auktion deren aktuelle Angebote.

## 02.10.2026 – Neues Modul Peon_Feedback, Kern API 9 (Peon 0.9.0, Feedback 0.1.0)

- Rückmeldungen (Fehler, Verbesserung, Neue Idee, Sonstiges) werden im Spiel in einem eigenen Modul gesammelt, accountweit in `PeonFeedbackDB`, mit Modul, Bereich, Priorität (Standard Mittel) und automatisch Charakter, Markt, Zone und Version des Moduls.
- Die Bereiche gehören dem jeweiligen Modul: Es meldet sie selbst über die Kern-Erweiterung `Peon.SetFeedbackAreas` (API 9, Schlüssel = Addon-Name). Feedback braucht so keine Modul-Interna; jedes Modul hängt mit einer Zeile an, abgesichert per `if` für ältere Kerne. „Sonstiges“ gibt es immer.
- Lieferungen aus dem Chat kommen als Zip mit `EINBAU.md` in `eingang\`; in Cowork werden sie gegen den echten Kern getestet und erst dann eingebaut. Dafür gibt es neben dem mitgelieferten Test (Kern-Nachbau) einen zweiten Test gegen den echten Kern.
- Kleine Korrekturen beim Einbau statt Rückfrage (Listenbreite, Wertebereich Minimap-Winkel, Hinweistext), weil sie nur Darstellung und Text betreffen.

## 01.10.2026 – Radar-Überarbeitung (Broker 0.19.0, Peon 0.8.0)

- Eine Gewinn-Spalte: höchster Gewinn mit meinem Gold (abzüglich Goldreserve), nicht der Gewinn des ganzen Schnäppchens. Sortierung, Mindestgewinn und Schnellkauf richten sich danach; was sich mit meinem Gold nicht lohnt, wird wie Unbezahlbares behandelt.
- Schnellkauf nur für Händler-Schnäppchen: kauft alles, was ich mir leisten kann (Massenware zwei Klicks, Einzelgegenstände ein Klick je Auktion).
- Neue Treffer: Zeile pulsiert (einstellbar, Standard 5 Sek.), dazu der grüne Punkt (als eigenes Bild); Warnton wählbar wie bei Fishing.
- Händlerware, die der Radar kauft, wird je Charakter gemerkt und am Händler per Knopf verkauft (nur diese, nie mehr als gekauft). Goldreserve und „Alle wieder zeigen“ übernommen; Taschenplatz-Prüfung entfällt (Ware kommt per Post).
- Kern API 8: Zeilenfarbe in der Liste (Erweiterung, bestehende Aufrufe unverändert).

## 30.09.2026 – Kaufzeile und Ausblenden (Broker 0.18.0)

- KarloDerBaer schaut sich jedes Angebot an: Schnellkauf-Knöpfe für das „beste“ Angebot entfallen; gekauft wird über die Kaufzeile des gewählten Treffers (1 Stück / bis ein Stapel / alle), jeweils mit Kosten und Gewinn für genau diese Menge und Hinweis, ab welcher Menge sich der Kauf lohnt.
- Ausblenden per Rechtsklick für alle Charaktere je Markt. Es gilt, bis eine Prüfung zeigt, dass kein Schnäppchen mehr vorliegt; wird es danach wieder eins, erscheint es wieder. So bleiben Gegenstände im freien Fall weg, ohne dauerhaft verloren zu gehen.

## 30.09.2026 – Markt-Schnäppchen und Kaufen je Stück (Broker 0.17.0)

- Markt-Schnäppchen: Wiederverkauf gegen das nächste Angebot nach dem Kauf statt gegen den Median; zusätzlich Mindestmarge je Stück (20 %) und höchstens 20 % des Angebots – viel billige Ware ist kein Dumping, sondern ein verschobener Preis.
- Gewinn wird je Stück und je Stapel (Stapelgröße des Spiels) gezeigt; „bestes“ Angebot und Sortierung nach Gewinn je Stück.
- Kaufen nur noch je Stück oder je Stapel, der Knopf zeigt den Preis genau dieses Kaufs.
- Radar: Auswahl Händler/AH/beide; was ich mir nicht leisten kann, wird standardmäßig ausgeblendet (einstellbar).

## 30.09.2026 – Radar-Bedienung (Broker 0.16.0)

- Reihenfolge des Radar-Scans im Reiter wählbar (smart, zufällig, Massenware zuerst, höchster/niedrigster Preis); Einkaufslisten und Treffer bleiben immer vorne.
- „Nur Warnton“ standardmäßig an: während des Scans nur der Gesamt-Kanal hörbar, auch im Hintergrund; wird immer zurückgesetzt (auch nach Reload/Absturz).
- Zähler-Zeile nicht mehr sichtbar, stattdessen der gerade geprüfte Gegenstand.

## 30.09.2026 – Live-Daten im aktuellen Stand (Broker 0.15.0)

- Live-Abfragen liefern für einen Gegenstand alle aktuellen Angebote und schreiben deshalb den aktuellen Stand (Min, Median, Menge, Preisstufen, „weg“) in die Datenbank – Vorschlag von KarloDerBaer.
- Verlauf (Tages-/Wochenwerte), Anzahl Scans (Datenlage) und Trend bleiben reine Scan-Werte, damit die Datenlage aussagekräftig bleibt und Trends nicht springen.
- Radar zeigt beim Öffnen alle Schnäppchen aus der Datenbank bis 60 Minuten (einstellbar, 0 = unbegrenzt) und prüft jedes einmal; ersetzt die 5-Minuten-Regel.

## 30.09.2026 – Reiter „Einkaufsliste“ und „Radar“ (Broker 0.14.0)

- Einkaufslisten und Schnäppchen sind eigene Reiter unten; „Schnäppchen“ heißt jetzt **Radar**.
- Radar: zwei Knöpfe „Bestes kaufen“ (Händler / AH), ab 0.14.1 mit dem Preis nur dieses einen Kaufs (vorher „alle kaufen“ mit Gesamtkosten – irreführend, weil je Klick nur ein Angebot gekauft wird). Ein Klick = ein Kauf, höchster Gewinn zuerst. Vor jedem Kauf wird geprüft, ob das Angebot noch da und noch so günstig ist (Massenware: Preis vom Spiel, bei höherem Preis Abbruch; Einzelgegenstand: frische Live-Abfrage, höchstens 10 Sek. alt).
- Radar-Scan: kein Vollscan, sondern laufend Einzelabfragen knapp unter der Grenze des Spiels (etwa 92 pro Minute), nur solange der Reiter offen ist. Reihenfolge: Treffer (spätestens alle 15 Sek. nachgeprüft), Einkaufslisten, Gegenstände mit den besten Chancen.
- 5-Minuten-Regel nur beim Öffnen des Reiters: Treffer aus einem höchstens 5 Min. alten vollen Scan werden angezeigt und sofort einmal live geprüft (auch ohne Radar-Scan); was weg ist, verschwindet gleich.
- Neue Treffer: Ton (abschaltbar) und grüne Hervorhebung, nur im Reiter.

## 30.09.2026 – Reiter „Einkaufen“ (Broker 0.13.0)

- Zwei Teile: Einkaufslisten und Schnäppchen (statt nur Händler-Schnäppchen auch Markt-/Dump-Angebote).
- Kaufansicht im Blizzard-Fenster, zusätzlich Knopf „Kaufen“ in Broker (mit Rückfrage und Preis vom Spiel).
- Einkaufslisten je Charakter; Höchstpreis = x % unter dem 7-Tage-Median, x einmal je Liste.
- Markt-Schnäppchen nur ab 50s möglichem Gewinn und bei mindestens 10 Scans in 7 Tagen; alle Schnäppchen nur bis 5 Minuten nach dem Scan (einstellbar), sonst sind viele Angebote schon weg.

## 30.09.2026 – Reiter „Meine Auktionen“ (Broker 0.12.0)

- Eine breite Liste mit Status (günstigster, gleichauf, unterboten, verkauft); unterbotene zuerst.
- Vergleich zuerst mit dem letzten Scan; „Live prüfen“ nur auf Knopfdruck, damit die Abfragegrenze für „Verkaufen“ frei bleibt.
- Abbrechen mit Anzeige der Kosten, „Nächste unterbotene“ je Klick; „Neu einstellen“ springt zu „Verkaufen“.
- Abgelaufene Auktionen erscheinen nicht in der Liste (das Spiel meldet sie nur per Post), sie kommen ins Buch.

## 30.09.2026 – Reiter „Behalten“ (Broker 0.11.0)

- Name des Reiters: „Behalten“, direkt hinter „Verkaufen“.
- Optionale Menge je Gegenstand; im Reiter „Verkaufen“ erscheint nur, was darüber liegt.
- Vorrat zählt Taschen und Bank (die Bank-Menge liefert das Spiel auch bei geschlossener Bank). Im Reiter die Spalten Vorrat (hervorgehoben), Taschen und Bank.
- „Behalten“ steht auch im Tooltip (eigene Zeile unter Zeile 1, nur aktueller Charakter).

## 30.09.2026 – Verkaufen über das Auktionshaus-Fenster, „nicht verkaufen“ (Broker 0.10.0)

- Der gewählte Gegenstand wird ins Verkaufsfenster des Auktionshauses gelegt, Brokers Werte werden dort eingetragen. Eingestellt wird mit den Werten, die dort stehen (Broker drückt dessen Knopf); die Eingabefelder in Broker entfallen.
- Linke Spalte schmal, Knöpfe übereinander; rechte Spalte breiter mit Trend (wie Zeile 1 im Tooltip).
- „Nicht verkaufen“ je Charakter (eigene Einstellungsdatei `PeonBrokerCharDB`), per Rechtsklick in der Liste und per Knopf links über „Auktion erstellen“. Kein Umbau des Listen-Bausteins im Kern nötig.
- Zum Verwalten der markierten Gegenstände kommt ein eigener Reiter.

## 30.09.2026 – Layout „Verkaufen“ wie Blizzard (Broker 0.9.0)

- Das Broker-Fenster orientiert sich am Blizzard-Auktionshaus: gleicher Rahmen, Reiter unten.
- „Verkaufen“ zweispaltig: links die Einstellungen im Aufbau des Blizzard-Fensters „Auktion erstellen“, rechts die Taschen mit kleinem Symbol vor dem Namen.
- Die aktuellen Angebote zeigt Broker nicht an (die stehen im Blizzard-Fenster); sie werden nur im Hintergrund für den Vorschlag abgefragt.
- Händlerpreis nur noch als Hinweis, wenn der Händler mehr zahlt; zum Vorschlag nur ein Stichwort, der ausführliche Grund beim Überfahren.

## 30.09.2026 – Reiter „Verkaufen“ (Broker 0.8.0)

- Zuerst im Spiel weiter, weil Broker ohne Programm funktionieren muss. Das Programm-Konzept bleibt als Entwurf liegen.
- Entwurf `Peon_Broker_Verkaufen.md` komplett angenommen: Taschenliste links, Live-Abgleich und Verkaufsfeld rechts, „Einstellen & weiter“, Alt+Klick in den Taschen.
- Beim Verkaufen gilt der Live-Preis (Rechenmodell Kapitel 4). Eigene Angebote werden nicht unterboten; ist man schon günstigster, bleibt der eigene Preis.
- Laufzeit Standard 8 Std.; Massenware ab 20 Angeboten 2 Std. (einstellbar); von Hand gewählte Laufzeit und Menge werden je Gegenstand gemerkt, der Preis nicht.
- Mehrere Stapel: Massenware wird als Gesamtmenge eingestellt (keine Stapel mehr im modernen Auktionshaus), Einzelgegenstände als Anzahl Auktionen.
- Einstellen nur per Klick, nie im Kampf; Rückfrage bei Preis weit unter dem Vorschlag und wenn das Spiel selbst nachfragt.
- Am Auktionshaus öffnet das Broker-Fenster mit dem Reiter „Verkaufen“, sonst mit dem zuletzt gewählten.

## 30.09.2026 – Begleitprogramm für Broker (Grundsätze)

- Broker bekommt ein Programm auf dem PC für die Langzeitdaten. Im Spiel geht es um Handeln (verkaufen, kaufen, eigene Auktionen) und eine schnelle Übersicht. Konzept: `Peon_Broker_Programm.md`.
- Broker funktioniert auch ohne Programm voll. Die Werte des Programms (Preisbereiche) verbessern nur die Einschätzung.
- Austausch nur über Dateien: WTF-Datei (Spiel → Programm, geschrieben bei Reload/Ausloggen/Beenden) und eine Datendatei, die das Spiel beim Start/Reload liest. Reload ist akzeptiert, Kopieren und Einfügen von Texten ist ausgeschlossen.
- Das Programm arbeitet mit Schnappschüssen aus beliebigen Quellen: jetzt Scans aus dem Spiel, später vielleicht die Blizzard-API.
- Ziel: Broker fertig zum Release. Datenverlust während der Beta ist nicht schlimm.

## 30.09.2026 – Broker-Fenster und Einstellgebühr (Broker 0.6.2 / 0.7.0)

- Einstellgebühr: Das Spiel rechnet 5 % vom Händlerwert des Stapels, rundet ab und nimmt das mal 1/4/12 für 2/8/24 Std. Belegt durch den automatischen Abgleich im Spiel (17 von 17 Beispielen). Ersetzt die Annahme „5/20/60 %“.
- Das Broker-Fenster ist vorerst Teil von Peon_Broker, kein Kern-Baustein. Es kann in den Kern wandern, falls ein weiteres Modul ein Fenster mit Reitern braucht.
- Alle fünf Reiter aus dem Konzept sind sichtbar. Noch nicht gebaute Reiter sind gesperrt und zeigen „Folgt in einer späteren Version“.
- Andocken: Bei offenem Auktionshaus hängt das Fenster rechts daneben und schließt mit ihm. Ohne Auktionshaus ist es frei verschiebbar, die Position wird gemerkt.
- Das Fenster öffnet sich nicht von selbst mit dem Auktionshaus (Standard aus, einstellbar), solange nur der Reiter „Preise“ fertig ist.
- Der Scan merkt sich Name und Qualität jedes Gegenstands, damit die Suche ohne Nachladen vom Spiel funktioniert. Einträge von 0.6 bekommen den Namen beim nächsten Scan, bis dahin kommt er vom Spiel (falls geladen).
- Bedienung: `/broker` und Linksklick auf den Minimap-Button öffnen das Fenster. Rechtsklick und `/broker optionen` öffnen die Einstellungen.

## 30.09.2026 – Rechenmodell für Broker abgestimmt (Grundlage für 0.6.0)

- Vor dem Weiterprogrammieren wurde das System „auf dem Papier“ aufgebaut: `Peon_Broker_Rechenmodell.md` (Begriffe, Formeln F1–F20, Tooltip-Anzeige), mit KarloDerBaer Punkt für Punkt abgestimmt.
- Wichtigste Änderungen gegenüber 0.5.1: Median statt „Durchschnitt der günstigsten 25 %“; Tageswerte = Mittel aller Scans des Tages; 7-Tage-Werte gleitend (heute eingeschlossen), Trend gegenüber Vortag; Abverkauf gestrichen (bei Massenware nicht messbar, fremde Verkäufe meldet das Spiel nicht); Einstellgebühr kommt bei Verkauf zurück und wird nicht mehr vom Erlös abgezogen, sondern aus Händlerpreis × Satz (2/8/24 Std.: 5/20/60 %) berechnet; Unterbieten getrennt für Massenware (Standard 0) und Einzelgegenstände (1c); Vergleichspreis = aktueller Median; bei Dumping Basis = Mitte zwischen Dumping-Grenze und Median.
- Blizzard-API: liefert keine Forever-Auktionsdaten; eine geplante Aufgabe („Forever-API prüfen“, täglich 8:58) meldet Änderungen. Ein Zusatzprogramm auf dem PC kommt für KarloDerBaer grundsätzlich in Frage.

## 29.09.2026 – Tooltip kompakter (Broker 0.5.0)

- Zeile 1 zeigt nur den besseren Wert („AH: …“ oder „Händler: …“), kein Wort „Erlös“ mehr.
- Standard ist der ganze Stapel; Umschalt schaltet nicht mehr Stück/Stapel um, sondern blendet die Detailzeilen ein. Dezenter Hinweis „(Umschalt)“ in Zeile 1.
- Trend-Symbole: gleich = dezent blauer Balken (gelber Punkt sah wie Gold aus); stark gestiegen dunkelgrün, gestiegen hellgrün, gefallen orange, stark gefallen rot. Vor dem Einbau als Bild mit KarloDerBaer abgestimmt.

## 29.09.2026 – Tooltip nach KarloDerBaers Aufbau, Trends, Abverkauf (Broker 0.4.0)

- Markt = Regelsatz + Fraktion: alle Charaktere dort teilen die Daten (accountweit). Bestätigt mit KarloDerBaer.
- Tooltip-Aufbau von KarloDerBaer: Erlös (mit Unterbieten, 5 % Anteil und Einstellgebühr), Angebote, AH Min/Ø, 7 Tage Min/Ø, Hinweise. Händlerpreis klein unter den Hinweisen. Werte je Stück, Umschalt = Stapel.
- Trend in fünf Stufen (KarloDerBaer): gerade Pfeile für starke, schräge für normale Änderungen, gelber Punkt für gleich; eigene Symbolbilder, weil die Spielschrift keine schrägen Pfeile hat. Grenzen 5 % / 20 % einstellbar.
- 7-Tage-Werte: Mittel der täglichen Tiefst- bzw. typischen Preise; Trend gegenüber den 7 Tagen davor.
- Abverkauf je Stunde als Schätzung (das Spiel meldet fremde Verkäufe nicht): Vergleich der günstigsten 20 Preisstufen zweier Scans (höchstens 24 Std. auseinander), Angebote kurz vor Ablauf ausgenommen. Abgebrochene Angebote zählen mit – ist als „ca.“ gekennzeichnet.
- Einstellgebühr außerhalb des Auktionshauses unbekannt: Broker merkt sie sich je Gegenstand, sobald er sie abfragen konnte; bis dahin „~“ vor dem Erlös.
- Tageswerte mindestens 14 Tage (sonst kein 7-Tage-Trend).

## 29.09.2026 – Preisdatenbank und Scan (Broker 0.3.0)

- Daten je Markt unter `PeonBrokerDB.markets["Realm / Fraktion"]`; Tooltip und Auswertung lesen nur den aktuellen Markt.
- Gegenstands-Schlüssel: itemID; bei Ausrüstung mit Zusatz „itemID:suffixID“, damit „… des Bären“ und „… des Affen“ nicht vermischt werden.
- Typischer Preis = Durchschnitt der günstigsten 25 % der angebotenen Menge (Mondpreise zählen nicht).
- Verlauf als kompakter Text (ein Eintrag je Tag, später je Woche), damit die Einstellungsdatei klein bleibt.
- Tooltip zeigt nichts bei Gegenständen ohne Daten (keine Störung bei Quest- oder gebundenen Sachen); nur ohne jeden Scan im Markt ein kurzer Hinweis.
- Die 15-Minuten-Sperre zählt Broker selbst mit (das Spiel verrät sie nicht); ein abgebrochener Scan verbraucht sie trotzdem.

## 29.09.2026 – Kern API 7: Liste und Minimap-Button (Peon 0.7.0, Broker 0.2.0)

- Neue Bausteine in eigenen Dateien (List.lua, Minimap.lua), bestehende Funktionen unverändert. `Widgets.lua` gibt dafür nur zusätzlich `Peon.PagePrototype` heraus.
- Liste ohne Blizzard-Vorlagen für Bildlauf (eigener Regler), damit sie im Forever-Client sicher läuft. Leere Werte stehen beim Sortieren immer unten.
- Minimap-Button nach dem Vorbild von Fishing. Fishing behält vorerst seinen eigenen Button (eigenes Rechtsklick-Menü); eine Umstellung wäre eine eigene Entscheidung.
- Broker nutzt beides schon jetzt (Minimap-Button, Ereignis-Liste), damit die Bausteine im Spiel getestet werden, bevor das Broker-Fenster kommt.

## 29.09.2026 – Neues Modul Peon_Broker (Konzept freigegeben, Broker 0.1.0)

- Broker ist der Auktionshaus-Helfer von Peon und ersetzt Auctionator vollständig. Konzept in `Peon_Broker_Konzept.md`.
- Eigenes Broker-Fenster (dockt am Auktionshaus an) statt Reiter im Blizzard-Fenster.
- Märkte strikt getrennt: Markt = Realm-Name (Regelsatz) + Fraktion. Der Nachname der Charaktere (z. B. Mirel Dorna) gehört nicht zum Markt.
- Preisvorschlag: günstigstes Angebot minus Unterbieten (einstellbar, Standard 1 Kupfer); bei unrealistisch tiefem Angebot Warnung und Durchschnitt minus Unterbieten; Untergrenze immer „Erlös nach Einstellgebühr und Verkaufsanteil ≥ Händlerpreis“.
- Buch über Käufe und Verkäufe und Minimap-Button gehören zu Stufe 1; der Minimap-Button wird als Baustein im Kern gebaut (API 7), Fishing behält vorerst seinen eigenen.
- Erster Bauabschnitt ist ein reiner Prüfbefehl, weil die Online-Angaben zur Forever-Auktionshaus-Schnittstelle ungenau sind. Er ruft nur lesende Funktionen auf (und `ReplicateItems` nur auf Knopfdruck).

## 29.09.2026 – Auswahllisten statt Knopfreihen (Peon 0.6.0, Fishing 1.5.0, Tooltip 0.5.2)

- KarloDerBaer bevorzugt Auswahllisten (Dropdown), wenn aus mehreren Möglichkeiten gewählt wird. Kern bekommt dafür `page:Dropdown` (API 6). Ersetzt die Entscheidung von 0.5.0, keinen Dropdown in den Kern aufzunehmen.
- Ausnahme: Positionen bleiben Knopfreihen/Raster (Tooltip-Position, PvP- und Quest-Symbol), weil man die Lage sofort sieht.
- Umgestellt: Fishing (Angel-Set, Markierung, Warnton, nach dem Kampf), Tooltip (Rahmenfarbe, Kampfmodus), Vorlage (Modus).

## 29.09.2026 – Fishing-Optionen auf Kern-Bausteine (Peon 0.5.0, Fishing 1.4.0)

- Kern um API 5 erweitert statt Fishing eigene Bausteine behalten zu lassen: Button, Text, Check mit Hinweis und eigenen an/aus-Werten, Neuanordnung beim Refresh, `keepOnReset`. Bestehende Aufrufe unverändert.
- ~~Keine Auswahlliste (Dropdown) im Kern~~ – mit 0.6.0 aufgehoben (siehe oben).
- Neue Anordnung der Fishing-Seite mit Überschrift „Schwimmer-Erkennung“; Tonmix-Regler werden ohne Tonmix ausgegraut.
- Neuer Knopf „Standardwerte“ für Fishing; Angel-Set, Zustand, Köder, Minimap-Position und Fänge bleiben erhalten.

## 29.09.2026 – Projektorganisation

- Projektdateien (Überblick, Stand, Entscheidungen, Tests, Werkzeuge, Vorlage) liegen in `<Repo>`, zusätzlich im Claude-Projekt. Im AddOns-Ordner nur Addon-Code; der alte Ordner „Claude outputs“ mit einer veralteten Kopie des Überblicks wurde gelöscht.
- Lua 5.1.5 liegt als fertige Programmdatei in `tools\` (Windows und Cowork). Tests laufen damit direkt auf den echten Dateien, ohne Übertragung in die Cloud.
- Modultests lesen die Version aus der TOC statt fester Werte.
- Neue Module starten aus `vorlage\Peon_Beispiel`.
- Die alten „Offenen Ideen“ (Gatherer, Auctionator, Minimap-Button im Kern, Fishing-Optionen umstellen, Tooltip-Ideen) wurden aus den Unterlagen genommen; KarloDerBaer gibt Ideen einzeln vor.

## Bis 29.09.2026 – Grundlagen (aus dem Überblick übernommen)

- **Aufbau:** Kern-Addon heißt „Peon“ (ohne „_Core“), Module sind eigene Addons `Peon_<Funktion>` mit `## Dependencies: Peon` und `## Group: Peon`. TOC-Titel `|cff8ccf4dPeon|r <Name>`, eigenes Icon.
- **Kern-API wird nur erweitert, nie geändert**; bei neuen Funktionen `Peon.API` erhöhen (derzeit 4).
- **Umbenennung auf Peon_*:** TooltipPlus → Peon_Tooltip, Combo Point Display → Peon_ComboPoints, FishingPlus → Peon_Fishing. Einstellungen über `oldDB`/`oldCharDB` übernommen, alte Namen eine Version lang in der TOC, danach entfernt. Abgeschlossen: keine alten Namen mehr in Code, TOC und WTF.
- **Tastenbelegungen umbenannt** (FISHINGPLUS_* → PEON_FISHING_*), alte Namen eine Version versteckt behalten und beim Login umgelegt; Gamepad-Tasten direkt in `bindings-cache.wtf` umbenannt. Abgeschlossen.
- **Geheime Werte:** nie vergleichen, rechnen oder als Schlüssel nutzen; immer `Peon.IsSecret()` prüfen. Combo-Punkte über StatusBars, Träger über Nameplate-Rahmen statt GUID.
- **Geschützte Aktionen** (Köder anlegen, Auswerfen) nie automatisch, nur per Tastendruck/Klick des Spielers.
- **Einstellungen:** Einstellungen > AddOns > Peon mit Unterseite je Modul; Seiten spätestens bei INIT anmelden.
- **Texte:** deutsch (deDE) und englisch (enUS), verständlich ohne Fachjargon.
