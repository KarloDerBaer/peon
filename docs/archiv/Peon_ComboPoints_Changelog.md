# Peon_ComboPoints: Verlauf der Versionen (Archiv)

Peon_ComboPoints wurde am 18.11.2026 aus Repo und Release genommen (Entscheidung KarloDerBaer). Abgelöst durch Peon_ClassBuddy, der Peon Manager ab 0.48.0 entfernt es über `retired` im Manifest, sobald ClassBuddy die Einstellungen übernommen hat.


Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 3.6.0

Kurz: Die Combo-Punkte zeigt jetzt der Klassenbuddy. Ist er installiert, bleibt Peon ComboPoints still, sagt einmal Bescheid und wird danach vom Peon Manager entfernt.

- 3.6.0 (14.11.2026): letzte Version. Ist Peon_ClassBuddy geladen, meldet sich Peon_ComboPoints beim Einloggen ab und zeigt einmal je Konto einen Hinweis (`movedHint`). Die Einstellungen bleiben, damit der Klassenbuddy sie übernehmen kann. Ohne Klassenbuddy alles wie bisher. Der Peon Manager ab 0.38.0 entfernt Peon_ComboPoints von selbst, sobald der Klassenbuddy die Einstellungen übernommen hat (Manifest-Angabe `replacedBy`). Test: `test_cp.lua`.

## 3.5.1

Kurz: Rückmeldungen lassen sich jetzt auch zu Combo-Punkten geben.

- 3.5.1 (02.10.2026): meldet Bereiche für Peon_Feedback (Anzeige, Farben, Optionen); eine Zeile am Ende von ComboPoints.lua, sonst unverändert.
