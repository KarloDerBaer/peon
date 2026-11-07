# Peon_Bags: Anordnung Klassisch, Nach Art, Individuell (abgestimmt)

Stand: 07.11.2026, mit KarloDerBaer abgestimmt. Baut auf den eigenen Bereichen auf (`Peon_Bags_Bereiche.md`). Umgesetzt in Peon_Bags 0.5.0.

## 1. Ziel

- Statt des Knopfs „Nach Art“ gibt es im Fenster den Knopf **Einstellen**. „Sortieren“ steht ganz links, „Einstellen“ rechts in der Knopfreihe.
- „Einstellen“ öffnet eine Leiste rechts neben dem Fenster. Oben stehen drei Knöpfe für die Anordnung, darunter die automatischen Kategorien, darunter die eigenen Bereiche, ganz unten eine kurze Erklärung.
- Die Leiste ist so hoch wie das Fenster und lässt sich rollen, wenn die Listen länger sind.

## 2. Die drei Anordnungen

| Anordnung | Was man sieht | In der Leiste |
|---|---|---|
| **Klassisch** | Alle Taschen zusammen in Taschenreihenfolge, ohne Kategorien und ohne eigene Bereiche | Kategorien und eigene Bereiche ausgegraut |
| **Nach Art** | Die angehakten automatischen Kategorien, darunter „Übrige“ | Eigene Bereiche ausgegraut, Kategorien wählbar |
| **Individuell** | Oben die angehakten eigenen Bereiche, dann die angehakten Kategorien, dann „Übrige“ | Alles wählbar |

- **Übrige** ist keine Kategorie, sondern der Rest in normaler Taschenreihenfolge.
- Die Zuordnungen zu eigenen Bereichen bleiben gespeichert, auch wenn man Klassisch oder Nach Art wählt.
- Eigene Bereiche gehen immer vor. Liegt ein Questgegenstand im eigenen Bereich „Behalten“, steht er dort und nicht unter „Quest“.
- Ziehen auf eine Kategorie oder auf „Übrige“ nimmt einen Gegenstand aus seinem eigenen Bereich. Er steht danach dort, wo er automatisch hingehört.
- Leere Kategorien werden ausgeblendet. Leere eigene Bereiche bleiben stehen, damit man etwas hineinziehen kann.
- Die Reagenzientasche, das Materiallager und die Accountbank bleiben eigene Abschnitte wie bisher.

## 3. Automatische Kategorien

Jede einzeln an- und abwählbar, Reihenfolge mit Pfeilen änderbar. Standardreihenfolge:

Neu, Quest, Ausrüstung, Essen und Trinken, Tränke und Elixiere, Verbände, Verbrauchbares, Handwerkswaren, Reagenzien, Rezepte, Edelsteine, Munition und Köcher, Taschen, Schlüssel, Verschiedenes, Müll, Freie Plätze

- Zuordnung in dieser Reihenfolge: eigener Bereich, Neu, Quest, Müll, dann nach der Art des Spiels (Klasse und Unterklasse).
- **Neu:** frisch erhaltene Gegenstände. Sie bleiben dort, bis das Fenster geschlossen wird, und springen nicht schon beim Überfahren mit der Maus weg.
- **Freie Plätze:** abgewählt stehen die leeren Plätze am Ende von „Übrige“.

## 4. Je Fenster und gemeinsam

- Je Fenster (Taschen, Bank, Gildenbank): Anordnung, welche Kategorien angehakt sind, welche eigenen Bereiche angehakt sind, eingeklappte Abschnitte.
- Gemeinsam: die Liste der eigenen Bereiche mit Namen und Zuordnungen, die Reihenfolge der Kategorien.
- So kann ein eigener Bereich in der Tasche genutzt werden und in der Bank nicht. Dort wird der Gegenstand dann automatisch einsortiert.
- Die Gildenbank kennt nur Klassisch und Nach Art.

## 5. Einklappen

Ein Klick auf eine Überschrift ohne Gegenstand am Mauszeiger klappt den Abschnitt ein oder aus. Eingeklappt steht die Anzahl hinter dem Namen. Mit Gegenstand am Mauszeiger bleibt der Klick das Ablegen.

## 6. Übernahme alter Einstellungen

- Mit eigenen Bereichen wird aus „Taschenreihenfolge“ Individuell ohne Kategorien und aus „Nach Art“ Individuell mit allen bisherigen Kategorien (ohne Neu).
- Ohne eigene Bereiche wird „Taschenreihenfolge“ zu Klassisch, „Nach Art“ bleibt Nach Art (ohne Neu).
- Gildenbank: „Taschenreihenfolge“ wird Klassisch.

## 7. Was gespeichert wird

In `PeonBagsDB`, accountweit:

```lua
bagLayout = "classic",        -- classic | type | custom (Gildenbank: classic | type)
bagCatsOff = { new = true },  -- abgewählte Kategorien je Fenster (bag, bank, guild)
bagGroupsOff = { [2] = true },-- abgewählte eigene Bereiche je Fenster (bag, bank)
bagCollapsed = { ["c:junk"] = true }, -- eingeklappte Abschnitte je Fenster
catOrder = { "new", "quest", ... },   -- gemeinsame Reihenfolge der Kategorien
layoutVer = 2,                -- Übernahme erledigt
```

Abgewählte Kategorien und Bereiche, ihre Reihenfolge und `layoutVer` bleiben bei „Standardwerte“ erhalten.
