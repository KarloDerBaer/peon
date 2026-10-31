# Peon

Peon ist eine Sammlung von Addons für **World of Warcraft Forever** (deutscher Client, Interface 16001). Alle Teile hängen an einem gemeinsamen Kern und haben ihre Einstellungen unter **Einstellungen > AddOns > Peon**.

> Peon ist noch jung. Die Addons sind mit einem Nachbau des Spiels getestet und bis zum Ende der Beta im Spiel gelaufen. Nach dem Start von Forever kann es noch Fehler geben. Rückmeldungen helfen sehr (siehe unten).

## Die Addons

| Addon | Was es tut | Befehl |
|---|---|---|
| **Peon** | Gemeinsamer Kern. Wird von allen anderen gebraucht. | `/peon`, `/peon list` |
| **Peon_Tooltip** | Tooltip folgt der Maus, mit Größe, Transparenz, Rahmenfarbe, PvP- und Quest-Symbol und Kampfmodus. Teile im Gegenstands-Tooltip lassen sich sortieren und ausblenden. | `/ttp` |
| **Peon_Broker** | Helfer fürs Auktionshaus: Komplettscan, Preise je Markt, Preise im Tooltip, eigenes Fenster mit Verkaufen, Meine Auktionen, Einkaufsliste und Radar. | `/broker` |
| **Peon_Ledger** | Bestand aller Charaktere (Taschen, Bank, Post, Auktionen, Gold) und Buchführung über Einnahmen und Ausgaben. | `/ledger` |
| **Peon_Bags** | Taschen, Bank und Gildenbank in je einem Fenster mit Suche und Sortierung. | `/peon bags` |
| **Peon_Fishing** | Angelmodus mit Ausrüstungswechsel, Angeln per Doppelklick oder Taste, Köder, Warnton. | `/fp` |
| **Peon_Mover** | Fenster von Blizzard und Peon verschieben und in der Größe ändern. | `/peon mover` |
| **Peon_ComboPoints** | Runde Combo-Punkte über dem Namensschild des Gegners (nur Schurken). | `/peon combopoints` |

Jedes Addon außer Peon ist freiwillig. Nimm nur, was du willst, aber **Peon selbst muss immer dabei sein**.

Peon_Bridge (Verbindung zum Programm Peon Manager) gehört zum Peon Manager und wird mit ihm installiert. Ohne den Manager tut es nichts.

## Installation

Bis der Peon Manager fertig ist, geht die Installation von Hand:

1. Öffne die Seite [Releases](https://github.com/KarloDerBaer/peon/releases/latest) und lade die Zip-Dateien der Addons, die du möchtest. **Peon** brauchst du immer.
2. Schließe WoW.
3. Entpacke jede Zip-Datei in den AddOns-Ordner von Forever, zum Beispiel  
   `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns`  
   Danach liegt dort für jedes Addon ein eigener Ordner, z. B. `AddOns\Peon` und `AddOns\Peon_Broker`. Achte darauf, dass kein doppelter Ordner entsteht (`AddOns\Peon\Peon`).
4. Starte WoW. In der Addonliste stehen die Peon-Module eingerückt unter Peon. Im Chat zeigt `/peon list`, was geladen ist.

**Aktualisieren:** Den alten Ordner des Addons löschen und die neue Zip-Datei genauso entpacken. Deine Einstellungen bleiben erhalten, sie liegen im Ordner `WTF` und nicht im Addon-Ordner.

## Peon Manager

Später gibt es ein kleines Windows-Programm, den **Peon Manager**. Er installiert und aktualisiert die Addons von selbst. Als Zusatz bringt er den **Peon Broker Client** mit, der die Auktionsdaten von Broker sammelt, auswertet und Broker bessere Preise zurückgibt. Bis dahin funktioniert alles auch ohne Programm.

## Feedback und Fehler

Fehler, Wünsche und Ideen bitte als [Issue](https://github.com/KarloDerBaer/peon/issues) hier im Repo melden. Hilfreich sind dabei:

- welches Addon und welche Version (steht in der Addonliste und bei `/peon list`)
- was du gemacht hast und was passiert ist
- die Fehlermeldung, falls es eine gab (zum Beispiel aus BugSack)

## Für Entwickler

Der Code liegt in `addons\`, die Tests in `tests\` (Lua 5.1 mit nachgebauter WoW-Schnittstelle), das Programm in `manager\` und die Doku in `docs\`. Einstieg: [docs/README.md](docs/README.md).

## Lizenz

MIT, siehe [LICENSE](LICENSE).
