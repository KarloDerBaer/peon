# Peon_Bags: eigene Bereiche (abgestimmt)

Stand: 06.11.2026, mit KarloDerBaer abgestimmt. B1 bis B3 gebaut in Peon_Bags 0.3.0, im Spiel noch nicht geprüft, B4 offen. Anlass ist eine Idee von KarloDerBaer: bestimmte Gegenstände, zum Beispiel solche zum Behalten, in einem eigenen Bereich anzeigen.

## 1. Ziel

- Gegenstände, die man selbst auswählt, stehen in den Taschen und in der Bank in einem eigenen Bereich mit Überschrift.
- Man legt die Bereiche selbst an und gibt ihnen Namen, zum Beispiel „Behalten“, „Farmen“ oder „Für Twinks“.
- Einmal zugeordnet, bleibt ein Gegenstand dort. Neue Stapel desselben Gegenstands landen von selbst im selben Bereich.
- Die Bereiche ändern nur die Anzeige. Die Gegenstände bleiben im selben Taschenplatz, nichts wird verschoben oder verkauft.

**Nicht in diesem Schritt:** automatische Regeln (etwa „alles ab Qualität Episch“), einklappbare Bereiche, Bereiche in der Gildenbank.

## 2. Ausgangslage im Code

- Das Fenster kann schon Abschnitte mit Überschrift anzeigen (`Window:Arrange`). `ns.BuildSections` baut sie, Taschen und Bank nutzen beide diese Funktion, die Gildenbank ebenfalls.
- Die Anordnung „Nach Art“ teilt nach festen Kategorien auf (`ns.CATS`). Die Anordnung „Taschenreihenfolge“ hat bisher einen einzigen Abschnitt ohne Überschrift.
- Plätze werden im Kampf nicht bewegt, das Anordnen wird nachgeholt (`ns.Defer`). Das gilt dann auch für die Bereiche.
- `PeonBagsDB` gilt accountweit, Bags hat keinen Speicher je Charakter.
- Klicks auf Gegenstände sind belegt: Umschalt+Klick (Link, Stapel teilen), Strg+Klick (Anprobe), Rechtsklick (benutzen), Alt+Klick (Ledger).
- Am 07.10.2026 wurde festgelegt, dass Bags vorerst nichts von Broker und Ledger anzeigt (schlank). Eine Verbindung zu Brokers Behalten-Liste würde das ändern, siehe Abschnitt 6.

## 3. So sieht es aus

Eigene Bereiche stehen oben im Fenster, darunter alles andere. Das gilt in beiden Anordnungen, der Knopf „Nach Art“ betrifft nur den Rest.

```
Behalten
[x][x][x][x]
Farmen
(noch leer)
Übrige                     (bei „Taschenreihenfolge“, nur wenn es eigene Bereiche gibt)
[x][x][x][x][x][x][x][x]
Reagenzien
[x][x][x]
```

- Bei „Nach Art“ folgen statt „Übrige“ die gewohnten Abschnitte Ausrüstung, Verbrauchbares und so weiter.
- Ohne eigene Bereiche sieht das Fenster genauso aus wie heute.
- Leere Plätze und freie Plätze im Fuß bleiben unverändert. Ein leerer Platz gehört nie zu einem Bereich.
- Überschriften eigener Bereiche bleiben auch dann stehen, wenn der Bereich leer ist. Sonst gäbe es keine Stelle, an die man den ersten Gegenstand legen kann.
- Innerhalb eines Bereichs wird sortiert wie bei „Nach Art“: Qualität, dann Name.
- Ein Gegenstand aus der Reagenzientasche, den man zuordnet, steht im gewählten Bereich. Die eigene Zuordnung geht vor.

## 4. Bedienung

**Zuordnen per Ziehen:** Gegenstand aufnehmen und auf die Überschrift eines Bereichs legen. Er geht danach zurück in seinen Taschenplatz und erscheint im Bereich. Das braucht keine neue Tastenkombination und funktioniert wie das Ablegen auf der Taschenleiste (Ziehen oder Klick mit Gegenstand am Mauszeiger).

**Wieder herausnehmen:** Gegenstand auf „Übrige“ oder auf eine der festen Überschriften wie „Ausrüstung“ legen.

**Bereiche verwalten:** Auf der Optionsseite von Bags gibt es einen neuen Abschnitt mit einer Liste: anlegen, umbenennen, nach oben und unten schieben, löschen. Löschen entfernt nur die Zuordnungen, die Gegenstände bleiben natürlich in der Tasche. Vor dem Löschen eines Bereichs, der Gegenstände enthält, kommt eine Rückfrage.

**Hinweis für den Anfang:** Der Tooltip der Überschrift erklärt das Ziehen in einem Satz.

## 5. Was gespeichert wird

In `PeonBagsDB`, accountweit:

```lua
groups = { { id = 1, name = "Behalten" }, { id = 2, name = "Farmen" } },   -- Reihenfolge wie angezeigt
groupItems = { [6948] = 1, ["3192:Name des Gegenstands mit Zusatz"] = 2 }, -- Gegenstand zu Bereich
```

- Ein Gegenstand gehört zu höchstens einem Bereich. Legt man ihn woanders ab, wechselt er.
- **Gegenstände mit Zusatz** („… des Wolfs“) werden wie bei Broker je Variante getrennt, weil man oft nur eine davon behalten will: Schlüssel `itemID:voller Name`, sonst nur die `itemID`. Der Name hängt von der Sprache ab, das ist wie bei Broker unkritisch.
- Die Nummer eines neuen Bereichs ist die höchste vorhandene plus eins.
- `groups` und `groupItems` bleiben bei „Standardwerte“ erhalten (`keepOnReset`), damit eine Zuordnung nicht versehentlich verloren geht.
- Die Kern-API ändert sich nicht. Bags braucht ab 0.3.0 aber API 7 statt 6, weil die Optionsseite die Liste aus dem Kern nutzt.

## 6. Verbindung zu Brokers Behalten-Liste (zweiter Schritt)

Broker führt je Charakter eine Liste „Behalten“ (`PeonBrokerCharDB.keep`). Sie entscheidet, was im Reiter Verkaufen angeboten wird. Damit gäbe es zwei Bedeutungen von „behalten“, wenn man in Bags einen Bereich so nennt.

- In Bags lässt sich ein fester Bereich „Behalten (Broker)“ einschalten, Standard aus, nur sichtbar, wenn Broker geladen ist.
- Er liest Brokers Liste nur. Geändert wird sie weiter in Broker. Dafür bekommt Broker eine kleine Abfrage nach dem Muster von `mod:StockOthers` in Ledger, zum Beispiel `mod:IsKept(itemID, vollerName)`.
- Ist nur ein Teil behalten (20 von 50), steht trotzdem der ganze Stapel im Bereich. Ein Stapel lässt sich in der Anzeige nicht teilen.
- Die Liste gilt je Charakter, die eigenen Bereiche accountweit. Das bleibt so, weil Broker damit seine Verkaufsmengen rechnet.

Die erste Fassung funktioniert auch ohne diesen Schritt.

## 7. Technik und Risiken

1. **`ns.BuildSections`** bekommt die Bereiche vorangestellt und einen Abschnitt „Übrige“. Die Gildenbank ruft die Funktion weiter ohne Bereiche auf, ihre Knöpfe bleiben unverändert.
2. **Überschriften werden zu Rahmen.** Heute sind sie reine Schrift (`Header` in `Window.lua`). Damit sie etwas annehmen können, wird jede zu einem kleinen, nicht geschützten Rahmen mit `OnReceiveDrag` und `OnClick`, die sich auch im Kampf bewegen lassen.
3. **Ablegen:** `GetCursorInfo` liefert Art, Nummer und Link. Bei einem Gegenstand wird die Zuordnung gesetzt und mit `ClearCursor` der Gegenstand zurückgegeben. Das Taschenfenster wird danach neu angeordnet.
4. **Im Kampf** wird die Zuordnung sofort gespeichert. Die Plätze rücken nach dem Kampf an die neue Stelle, wie heute beim Umschalten der Anordnung.
5. **Fenstergröße:** Jeder Bereich kostet eine Zeile mehr. Viele Bereiche machen das Fenster höher, eine feste Obergrenze ist nicht vorgesehen.

**Testen:** Aufteilen in Bereiche, Sortierung, Varianten, Löschen, Standardwerte und Gildenbank ohne Änderung mit lua5.1 in `tests\`. Ziehen und Ablegen nur im Spiel.

## 8. Im Spiel prüfen

- Gegenstand auf eine Überschrift ziehen und auf sie klicken, wenn er am Mauszeiger hängt: Liegt er danach wieder im selben Platz, ohne Sperre und ohne Fehlermeldung?
- Zuordnen und Herausnehmen im Kampf: Rücken die Plätze danach richtig, bleiben Tränke im Kampf benutzbar?
- Mit einem aufgenommenen Teilstapel (Umschalt+Klick): Geht der Teil zurück auf den alten Stapel?
- Bank: Gilt die Zuordnung auch dort, und lassen sich Gegenstände aus der Bank ziehen?
- Reagenzientasche: Steht der zugeordnete Gegenstand im Bereich, stimmt der Fuß weiter?

## 9. Bauabschnitte

- **B1** Speicher, Aufteilung in `ns.BuildSections`, Anzeige in Taschen und Bank, Tests.
- **B2** Überschriften als Rahmen, Zuordnen und Herausnehmen per Ziehen.
- **B3** Verwaltung auf der Optionsseite, Rückfrage beim Löschen.
- **B4** Bereich „Behalten (Broker)“ und Abfrage in Broker (Abschnitt 6).

B1 bis B3 gehören zusammen und ergeben Bags 0.3.0. B4 kann folgen, sobald die erste Fassung im Spiel läuft.

## 10. Entschieden (KarloDerBaer, 06.11.2026)

1. **Eigene, frei benennbare Bereiche**, nicht nur ein fester Bereich.
2. **Verbindung zu Brokers Behalten-Liste als zweiter Schritt**, nur lesend und abschaltbar. Das lockert die Entscheidung vom 07.10.2026, dass Bags vorerst nichts von Broker anzeigt.
3. **Zuordnen per Ziehen** auf die Überschrift, kein Bearbeiten-Modus.
4. **Accountweit**, alle Charaktere teilen sich Bereiche und Zuordnung.
