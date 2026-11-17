# Peon (Kern): Konzept Datenaustausch zwischen Peon-Nutzern (Peon.Comm)

Stand: 17.11.2026, Entwurf von Claude. Gewünscht von KarloDerBaer, Bau in einer eigenen Sitzung. Noch nicht freigegeben.

## 1. Idee

Peon-Nutzer tauschen Spieldaten untereinander aus, ohne dass jemand etwas davon sieht. Der Kern stellt dafür eine Schnittstelle bereit. Sie läuft nur, wenn mindestens ein Modul sie braucht. Erster Nutzer ist Peon_Profession mit den Sammelstellen, die Schnittstelle soll aber von Anfang an für weitere Daten taugen.

## 2. Was schon feststeht (KarloDerBaer, 17.11.2026)

- Der Austausch gehört in den Kern und wird nur genutzt, wenn ein Modul ihn braucht.
- Er ist von Anfang an an und lässt sich abschalten.
- Daten von anderen erscheinen sofort, aber als fremd erkennbar (anders gefärbt), bis zwei verschiedene Spieler sie melden oder man es selbst bestätigt.

## 3. Was auf Forever geht (Erkenntnis aus PLG)

Profession Leveling Guide (MIT, `Module\Netz.lua`, Version 2.6.8 und später) hat es auf dem Forever-Client getestet:

- **Addon-Nachrichten über einen Kanal (`CHANNEL`) kommen nicht an**, auch die eigenen nicht. Senden meldet keinen Fehler.
- **Unsichtbares Addon-Flüstern (`WHISPER`) geht.**
- PLG nutzt deshalb einen versteckten Kanal nur als Treffpunkt: Wer im Kanal ist, hat das Addon. Die Liste der Mitglieder liefert `C_ChatInfo.GetChannelRosterInfo`. Der Kanal wird aus allen Chatfenstern entfernt (`ChatFrame_RemoveChannel`).
- Die Daten gehen per Addon-Flüstern an wenige zufällige Mitspieler aus der Liste (eigene Nachricht an 3, weitergegebene an 2), die sie höchstens dreimal weitergeben. So verbreiten sie sich auch zwischen Spielern, die nie gleichzeitig online sind.
- Takt: höchstens etwa eine Flüsternachricht je 1,25 Sekunden (Blizzard drosselt bei etwa einer je Sekunde). Nachrichten höchstens 255 Zeichen.
- Jede Nachricht trägt einen Prüfwert des Urhebers und die Zahl der Sprünge. Doppelte Nachrichten werden 30 Minuten lang erkannt.
- Ausweichnamen für den Kanal, falls einer gesperrt ist.

Im Spiel selbst noch einmal bestätigen (erster Schritt der Sitzung): Kanal-Nachricht kommt nicht an, Flüstern kommt an, Mitgliederliste lesbar.

## 4. Vorschlag für die Schnittstelle (API 23, nur Erweiterung)

```lua
-- Ein Modul meldet einen Dienst an. Erst dann tritt Peon dem Kanal bei.
Peon.Comm.Register("nodes", {
    version = 1,
    onReceive = function(daten, info) end,   -- info.melder = Prüfwert, info.spruenge
})
Peon.Comm.Send("nodes", daten)              -- Tabelle oder Text, der Kern packt und teilt auf
Peon.Comm.IsOn()                            -- Austausch eingeschaltet?
Peon.Comm.Peers()                           -- Zahl der erreichbaren Peon-Nutzer
```

- Ein Präfix `PEON` für alle Dienste, der Dienst steht in der Nachricht.
- Der Kern kümmert sich um Kanal, Mitgliederliste, Warteschlange, Takt, Weitergabe, doppelte Nachrichten und Prüfwert.
- Die Module kümmern sich um ihre Daten: was gesendet wird, wie oft, und wie fremde Daten gespeichert werden.
- Nicht im Kampf und nicht in Instanzen senden. Geheime Werte vorher mit `Peon.IsSecret` prüfen.
- Keine Charakternamen speichern oder anzeigen. Namen nur im Speicher zum Zustellen.
- Abschalten in den Kern-Optionen („Daten mit anderen Peon-Nutzern teilen“). Dann verlässt Peon den Kanal und sendet nichts.
- Abschnitt im Überblick (`Peon_Ueberblick.md`) und Tests wie bei den anderen Kern-Teilen.

## 5. Mögliche Dienste

| Dienst | Modul | Daten |
|---|---|---|
| nodes | Profession | Sammelstellen: Karte, Ort gerundet, Vorkommen, Beute (Daten ab Profession 0.5.0 in `PeonProfessionDB.nodes`) |
| colors | Profession | gemessene Rezeptfarben (`PeonProfessionDB.colors`) |
| vendors, trainers | Profession | Rezepthändler und Lehrer mit Ort und Rezepten |
| fish | Fishing | Fänge je Gebiet |

Fremde Daten speichert jedes Modul getrennt von den eigenen, mit Zahl der Melder (höchstens 5 Prüfwerte je Eintrag).

## 6. Offene Fragen an KarloDerBaer

1. Welche Dienste kommen im ersten Schritt dazu (Vorschlag: nur nodes)?
2. Name des versteckten Kanals (Vorschlag: `PeonData` mit Ausweichnamen `PeonData2`, `PeonData3`)?
3. Soll Peon_Panel oder der Kern anzeigen, wie viele Peon-Nutzer erreichbar sind?
