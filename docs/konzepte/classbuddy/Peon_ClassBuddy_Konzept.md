# Peon_ClassBuddy: Konzept

Stand: 14.11.2026, abgestimmt mit KarloDerBaer (Abschnitt 8), Prüfung im Spiel erledigt (Abschnitt 4.3), umgesetzt in ClassBuddy 0.2.0 und Peon_ComboPoints 3.6.0. Anlass: Wunsch aus dem Feedback (peon-fehler #36, Bereich ComboPoints, Priorität hoch): ein Addon für mehrere Klassen, das die Combo-Punkte des Schurken mitbringt und für den Hexenmeister überzählige Seelensplitter vernichtet. Angezeigt wird es als „Klassenbuddy“.

## 1. Idee

Ein Modul **Peon_ClassBuddy**, das für jede Klasse kleine Helfer bündelt. Es startet nur den Teil, der zur Klasse des eingeloggten Charakters passt. Andere Klassen kosten nichts außer dem Laden der Dateien.

- **Schurke:** die heutigen Combo-Punkte über dem Nameplate (aus Peon_ComboPoints übernommen, unverändert im Verhalten).
- **Hexenmeister:** überzählige Seelensplitter vernichten.
- **Später:** weitere Klassen nach Wunsch (siehe Abschnitt 7), jede als eigener Teil.

## 2. Aufbau

- Neues Modul nach Vorlage `vorlage/Peon_Beispiel`, hängt von Peon ab, ein Eintrag beim Kern (`Peon:NewModule`, Schlüssel `classbuddy`, Titel „Klassenbuddy“, englisch „Class Buddy“).
- Dateien je Klasse, damit es übersichtlich bleibt:
  - `ClassBuddy.lua`: Start, erkennt die Klasse (`UnitClass("player")`, englischer Schlüssel wie `ROGUE`, `WARLOCK`), startet nur den passenden Teil.
  - `Rogue_ComboPoints.lua`: der heutige Code von `ComboPoints.lua`, nur an das neue Modul angebunden.
  - `Warlock_Shards.lua`: Seelensplitter.
  - `Options.lua`: ein Reiter je Klasse. Für andere Klassen ausgegraut mit Hinweis „nur für Schurken“ usw.
- Einstellungen in einer SavedVariable `PeonClassBuddyDB`. Umgesetzt flach statt mit Unterbereichen je Klasse: Die Bausteine der Optionsseite arbeiten mit Schlüsseln der obersten Ebene. Die Combo-Punkte behalten ihre Namen aus Peon_ComboPoints, die Seelensplitter beginnen mit `shard`. Die Einstellungen gelten für alle Charaktere des Kontos (wie bisher bei ComboPoints).
- Feedback-Bereiche: „Schurke: Combo-Punkte“, „Hexenmeister: Seelensplitter“, „Allgemein“.
- Symbol auf der Panel-Leiste: das Klassensymbol. Der Tooltip zeigt, was aktiv ist, beim Hexer z. B. „Seelensplitter: 24 in der Tasche, 2 zu viel“.

## 3. Ersatz für Peon_ComboPoints (abgestimmt)

ClassBuddy ersetzt Peon_ComboPoints ganz. Der Wechsel soll für Nutzer ohne Zutun gehen.

- ClassBuddy übernimmt beim ersten Start die Einstellungen aus `PeonComboPointsDB` (Größe, Abstand, Farben usw.) nach `rogue`. Dafür steht `PeonComboPointsDB` eine Version lang zusätzlich in der TOC (wie bei der Umbenennung auf Peon_* über `oldDB`).
- Peon_ComboPoints bekommt eine letzte Version, die nichts mehr anzeigt, wenn ClassBuddy geladen ist (sonst gäbe es die Punkte doppelt), und auf ClassBuddy hinweist.
- Der Manager installiert ClassBuddy und führt ComboPoints danach nicht mehr. Wann Peon_ComboPoints aus Repo und Manager verschwindet, entscheidet KarloDerBaer, sobald der Wechsel bei allen durch ist.

## 4. Hexenmeister: Seelensplitter

### 4.1 Wann ein Splitter zu viel ist (einstellbar)

| Regel | Bedeutung |
|---|---|
| **Seelentasche voll** (Standard) | Ist die Seelentasche voll, ist jeder Splitter in einer anderen Tasche zu viel. Splitter in der Seelentasche werden nie angefasst. Ohne Seelentasche greift die Höchstzahl. |
| **Höchstzahl** | Mehr als N Splitter insgesamt (Standard 20), egal wo sie liegen. Zu viel sind zuerst die außerhalb der Seelentasche. |

- Seelensplitter werden an der Gegenstandsnummer erkannt (6265), die Seelentasche am Taschentyp (zweiter Rückgabewert von `C_Container.GetContainerNumFreeSlots`). Beides vorher im Spiel prüfen.
- Gezählt wird bei jeder Änderung der Taschen (`BAG_UPDATE_DELAYED`). Das Zählen ist erlaubt, nur das Vernichten braucht einen Anlass (4.3).

### 4.2 Einstellungen

| Einstellung | Standard | Bedeutung |
|---|---|---|
| Seelensplitter vernichten | an | Hauptschalter |
| Regel | Seelentasche voll | siehe 4.1 |
| Höchstzahl | 20 | für die Regel Höchstzahl und ohne Seelentasche |
| Auslösen | mit Zaubern | siehe 4.3 |
| Meldung im Chat | an | „Klassenbuddy: Seelensplitter vernichtet (Seelentasche voll).“ |

### 4.3 Auslösen: zusammen mit einem Zauber

Vernichten geht über `C_Container.PickupContainerItem` und danach `DeleteCursorItem`. Wahrscheinlich verlangt das Spiel dafür einen Tastendruck oder Klick des Spielers (so wie beim Angeln das Auswerfen). Der Wunsch von KarloDerBaer: Das Vernichten läuft mit, wenn der Spieler ohnehin einen Zauber auslöst. Dafür gibt es zwei Wege, beide werden mit dem Prüfbefehl getestet:

**Weg A: mit jeder Aktionstaste (bevorzugt, ohne Zutun).**
Peon hängt sich an Blizzards Aktionsknöpfe an (nur mitlesen nach dem Auslösen, `hooksecurefunc` bzw. `HookScript("PostClick")`). Der Zauber selbst läuft unverändert, danach vernichtet ClassBuddy im selben Tastendruck **einen** überzähligen Splitter. Gibt es keinen, passiert nichts. Bei mehreren zu viel räumt jeder weitere Zauber einen weiteren weg. Der Spieler muss nichts einrichten.

**Weg B: Makro (Rückfall).**
Ein Knopf zum Anklicken aus Makros, z. B.:

```
/cast Schattenblitz
/click PeonClassBuddyShard
```

ClassBuddy legt auf Wunsch fertige Makros für häufige Zauber an (Schattenblitz, Feuerbrand, Lebensentzug). So läuft es auch, wenn Weg A nicht geht, etwa weil die Aktionsleisten von einem anderen Addon stammen.

**Dazu immer:** Tastenbelegung und Eintrag auf der Panel-Leiste „Splitter vernichten“, die alle überzähligen auf einmal wegräumen (außerhalb des Kampfes).

**Im Kampf:** Ob `PickupContainerItem` und `DeleteCursorItem` im Kampf erlaubt sind, ist offen. Gegenstände in Taschen verschieben geht im Kampf, Vernichten vielleicht nicht. Geht es nicht, sammelt ClassBuddy im Kampf nur und räumt mit dem ersten Zauber nach dem Kampf auf. Der Zauber darf dadurch nie gestört werden: Klappt das Vernichten nicht, bricht ClassBuddy leise ab und versucht es beim nächsten Zauber.

**Prüfung bei Mitspielern (umgesetzt in ClassBuddy 0.1.0):** KarloDerBaer hat keinen Hexenmeister, deshalb prüft ein Mitspieler. Für Hexenmeister erscheint beim Einloggen ein vorläufiges Fenster mit dem Hinweis, dass es nur für den Test da ist und mit der nächsten Version wieder verschwindet (Haken „Nicht mehr anzeigen“). Es führt durch die Schritte, legt das Makro an und schickt das Ergebnis mit „Ergebnis senden“ über Peon_Feedback an den Peon Manager (Kern-API 22). Von dort sendet der Mitspieler es wie jede Rückmeldung.

**Prüfbefehl** `/peon classbuddy pruefen` (öffnet das Fenster, vor dem Bau des Rests):
1. Vernichten ohne Tastendruck (aus einem Ereignis): geht es?
2. Vernichten per Taste oder Knopf außerhalb des Kampfes.
3. Weg A: Splitter mit einer Aktionstaste mitnehmen, außerhalb und im Kampf.
4. Weg B: dasselbe per Makro mit `/click`.
5. Ob Aktionstasten über Blizzards Code laufen (`UseAction`, `ActionButtonDown`) oder direkt im Spiel, sonst greift Weg A nicht.

Ergebnis steht danach in `Peon_Ueberblick.md` bei den geschützten Aktionen.

**Ergebnis der Prüfung (14.11.2026, ein Mitspieler mit Hexenmeister, Build 70938, peon-fehler #38 bis #42):**

| Weg | kein Kampf | Kampf |
|---|---|---|
| ohne Tastendruck | gesperrt | gesperrt |
| Klick auf Knopf | geht | geht |
| Makro `/click` | geht | geht |
| Aktionstaste (nach `UseAction`) | geht | einmal Aufnehmen gescheitert |

- Ohne Tastendruck sperrt das Spiel `DeleteCursorItem` (ADDON_ACTION_BLOCKED, Berichte #37 und #40 kamen vom Test selbst). Also nie aus einem Ereignis oder Zeitgeber.
- Im Kampf ist das Vernichten erlaubt, Klick und Makro gingen dort.
- Aktionstasten laufen in Forever über `UseAction`. `ActionButtonDown` und `PostClick` kamen nicht. Weg A hängt sich also an `UseAction`.
- Im Kampf gab es mit der Aktionstaste nur einen Versuch, und da scheiterte schon das Aufnehmen. Die Prüfung versucht je Zustand nur einmal. Der Fehlertext fehlt im Bericht. Kein Zauber mit Zielkreis (Auskunft des Mitspielers). Wahrscheinlicher: Der Splitter war noch gesperrt (`isLocked`), weil kurz davor ein Splitter per Klick oder Makro vernichtet wurde oder der Test ohne Tastendruck beim Kampfbeginn ihn aufgenommen und zurückgelegt hatte. Die Prüfung sucht Splitter, ohne gesperrte Plätze zu überspringen. Da Klick und Makro im Kampf gehen, ist es kein grundsätzliches Verbot.
- Taschen: Die Seelentasche liegt bei ihm auf Platz 5 und meldet Taschentyp 4, der Splitter hat Familie 4. Die Erkennung aus 4.1 passt.
- Zwei Berichte kamen doppelt (#38 und #39, #41 und #42, jeweils gleiche Zeit). Vermutlich zweimal auf „Ergebnis senden“ geklickt. Der Knopf sollte nach dem Senden gesperrt sein.

**Folgerung (abgestimmt mit KarloDerBaer, umgesetzt in 0.2.0):** Weg A über `UseAction` als Standard. Gesperrte Plätze (`isLocked`) werden übersprungen. Scheitert ein Versuch, versucht ClassBuddy es beim nächsten Zauber einfach wieder, ohne Meldung, und schreibt den Grund ins Debug-Log. Zauber, die den Mauszeiger brauchen, werden übersprungen (4.4). Dazu immer der Makro-Knopf `PeonClassBuddyShard` als sicherer Rückfall und eine Tastenbelegung. Eine zweite Prüfung ist nicht nötig. Ob die Aktionstaste im Kampf zuverlässig geht, zeigt der Alltag, Fehlversuche landen im Debug-Log.

### 4.4 Sicherheit

- Nur Gegenstand 6265, niemals etwas anderes. Nach dem Aufnehmen wird geprüft, dass genau dieser Gegenstand am Mauszeiger hängt. Sonst wird er zurückgelegt und nichts vernichtet.
- Hat der Spieler schon etwas am Mauszeiger, wird nichts aufgenommen.
- Zauber, die den Mauszeiger brauchen (Zielkreis auf dem Boden), werden übergangen, damit der Splitter nicht am Zeiger hängen bleibt.
- Peon_Ledger zeichnet das Vernichten schon heute mit auf (Hook auf `DeleteCursorItem`). Seelensplitter haben keinen Wert, das Buch ändert sich also nicht.

## 5. Schurke: Combo-Punkte

Verhalten und Optionen bleiben genau wie in Peon_ComboPoints 3.5.1. Nur die Einstellungen ziehen nach `rogue` um. Der Code wird verschoben, nicht neu geschrieben, die Tests aus `test_cp.lua` ziehen nach `test_classbuddy.lua` um.

## 6. Tests

- Klasse wird erkannt, nur der passende Teil startet, Übernahme aus `PeonComboPointsDB`.
- Seelensplitter mit nachgebauten Taschen: beide Regeln, mit und ohne Seelentasche, Seelentasche voll und nicht voll.
- Auslösen: genau ein Splitter je Zauber, nichts ohne Überschuss, nichts bei belegtem Mauszeiger, falscher Gegenstand am Mauszeiger wird zurückgelegt, Fehler beim Vernichten stört den Zauber nicht.
- Combo-Punkte: bisherige Tests umziehen.

## 7. Ideen für später (nur Vorschläge, nichts davon ist beschlossen)

- Hexenmeister: Splitter auf dem Spielerrahmen oder der Panel-Leiste, Warnung bei wenigen Splittern.
- Jäger: Munition und Zufriedenheit des Tiers.
- Schamane, Magier, Priester: fehlende Reagenzien (Ankh, Arkanes Pulver, heilige Kerze) melden.

## 8. Abgestimmt mit KarloDerBaer (14.11.2026)

1. Name im Code `Peon_ClassBuddy`, angezeigt „Klassenbuddy“.
2. ClassBuddy ersetzt Peon_ComboPoints.
3. Regel für Seelensplitter einstellbar, Standard „Seelentasche voll“.
4. Vernichten wird nicht automatisch gehen, schon gar nicht im Kampf. Es soll zusammen mit dem Auslösen eines Zaubers laufen (Abschnitt 4.3).

## 9. Reihenfolge

1. Prüfbefehl (4.3), Ergebnis mit KarloDerBaer ansehen. Erledigt am 14.11.2026, Ergebnis in 4.3.
2. Modul mit Combo-Punkten (Umzug, Übernahme der Einstellungen), letzte Version von Peon_ComboPoints.
3. Seelensplitter mit dem Weg, den die Prüfung erlaubt.

Schritte 2 und 3 umgesetzt in ClassBuddy 0.2.0 und Peon_ComboPoints 3.6.0 (14.11.2026). Offen: Prüfung im Spiel, später Peon_ComboPoints entfernen.
