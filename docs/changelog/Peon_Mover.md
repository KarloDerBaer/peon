# Peon_Mover: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 0.1.1

Kurz: Ein verschobenes Bankfenster springt nicht mehr nach rechts oben, wenn du in Peon Bags auf „Blizzard“ klickst.

- 0.1.1 (12.11.2026, gefunden beim Fehlerbericht zu Bags 0.6.0):
  - **Fehler:** Peon_Bags versteckt Blizzards Bankfenster in einem Rahmen mit Größe 0,001. Setzte Blizzard dabei die Lage, wandte der Mover die gespeicherte Stelle an und teilte sie durch die Größe des Fensters gegenüber dem Bildschirm (0,001). Die Abstände wurden so tausendfach, nach dem Zurückholen („Blizzard“) schob das Spiel das Fenster an den Rand nach rechts oben.
  - **Behebung:** Ist ein Fenster so winzig (unter 5 % der Bildschirmgröße), setzt der Mover keine Lage. Wird ein Fenster umgehängt (`SetParent`, mitgelesen), wendet er die gespeicherte Stelle neu an. So steht das Bankfenster nach „Blizzard“ wieder an der verschobenen Stelle. Gilt ebenso für die Gildenbank.
  - **Im Spiel geprüft (KarloDerBaer, 12.11.2026):** Nach „Blizzard“ steht das Bankfenster wieder an der verschobenen Stelle.

## 0.1.0

Kurz: Fenster verschieben und ihre Größe ändern, die Stellen bleiben gespeichert.

- 0.1.0 (06.10.2026, Bauabschnitte M1–M3):
  - **Fenster finden:** feste Liste (Namen aus BlizzMoves Liste für Forever/Retail, ergänzt um Berufsbuch, Zauberbuch, Questlog u. a.) und alle Fenster aus Blizzards `UIPanelWindows` (nur gelesen); nur vorhandene Fenster, neu bei jedem `ADDON_LOADED` nach dem Login. Ausgelassen: Taschen, kleine Einblendungen, Weltkarte solange Leatrix_Maps geladen ist.
  - **Verschieben** an der Titelleiste (oberer Streifen 26 Punkte, nur Klicks auf das Fenster selbst – Knöpfe dort funktionieren normal), am Bildschirm gehalten; Blizzards Merker „vom Spieler platziert“ wird zurückgesetzt. Setzt Blizzard das Fenster neu (Öffnen, Anordnen), kommt es sofort an die gespeicherte Stelle.
  - **Größe** mit Strg + Mausrad 50–200 % (5 %), linke obere Ecke bleibt; nur Größe = keine Position gespeichert. **Umschalt + Rechtsklick** auf die Titelleiste: Position und Größe zurück auf Blizzards Wunsch (mitgelesen aus dessen `SetPoint`/`SetScale`).
  - **Kampf:** geschützte Fenster werden im Kampf nicht angefasst (einmal Hinweis je Kampf); Anwenden, Zurücksetzen und Einhängen werden nach dem Kampf nachgeholt.
  - Nur mitlesen (`HookScript`, `hooksecurefunc`), keine Blizzard-Tabelle neu zugewiesen; Rückfrage „Alle zurücksetzen“ als eigener Eintrag in `StaticPopupDialogs`.
  - **Optionsseite:** „Fenster verschieben erlaubt“ (Sperre: gespeicherte Positionen gelten weiter), Fensterliste (Fenster, Status, An; Tooltip mit Spielname und Herkunft; Rechtsklick = an/aus), Knöpfe „An / Aus“, „Zurücksetzen“, „Alle Fenster zurücksetzen“ (mit Rückfrage).
  - Bereiche für Peon_Feedback: Verschieben, Größe, Zurücksetzen, Fensterliste, Kampf, Optionen.
- **Nächster Schritt:** Test im Spiel (**WoW komplett neu starten** – neuer Addon-Ordner), Punkte siehe Konzept Abschnitt 9. Danach M4: Peon-Fenster (Kern-Erweiterung `Peon.RegisterWindow` – wird API 12, weil API 11 seit 07.10.2026 die Untertabs sind).
