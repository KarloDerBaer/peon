# Peon (Kern): Konzept Datenaustausch zwischen Peon-Nutzern (Peon.Comm)

Stand: 17.11.2026, Entwurf von Claude, Fragen mit KarloDerBaer geklärt (Abschnitt 6). Gebaut in Peon 0.23.0 (API 23) als erster Schritt ohne Dienste der Module.

## 1. Idee

Peon-Nutzer tauschen Spieldaten untereinander aus, ohne dass jemand etwas davon sieht. Der Kern stellt dafür eine Schnittstelle bereit. Sie läuft nur, wenn mindestens ein Modul sie braucht. Erster Nutzer ist Peon_Profession mit den Sammelstellen, die Schnittstelle soll aber von Anfang an für weitere Daten taugen.

## 2. Was schon feststeht (KarloDerBaer, 17.11.2026)

- Der Austausch gehört in den Kern und wird nur genutzt, wenn ein Modul ihn braucht.
- Er ist von Anfang an an und lässt sich abschalten.
- Daten von anderen erscheinen sofort, aber als fremd erkennbar (anders gefärbt), bis zwei verschiedene Spieler sie melden oder man es selbst bestätigt.

## 3. Was auf Forever geht (Erkenntnis aus PLG)

Profession Leveling Guide (MIT, `Module\Netz.lua`, Version 2.6.8 und später) hat es auf dem Forever-Client getestet:

- **Addon-Nachrichten über einen Kanal (`CHANNEL`) kommen nicht an**, auch die eigenen nicht. Senden meldet keinen Fehler. *Eigene Prüfung am 17.11.2026 (Abschnitt 7): Die eigene Kanal-Nachricht kam zurück, Flüstern an sich selbst nicht. Der Fund gilt deshalb als unsicher, bis zwei Spieler geprüft haben.*
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

## 6. Fragen an KarloDerBaer (geklärt 17.11.2026)

1. Welche Dienste kommen im ersten Schritt dazu? **Noch keine.** Über das nächste Release erst testen, ob der Austausch funktioniert. Dafür lernen sich die Peon-Nutzer unsichtbar kennen (Dienst `hello` des Kerns), das Ergebnis lässt sich danach in `PeonDB.comm` ansehen.
2. Name des versteckten Kanals? **`PeonNet`**, Ausweichnamen `PeonNet2` und `PeonNet3`.
3. Wer zeigt an, wie viele Peon-Nutzer erreichbar sind? **Der Kern**, in den Peon-Einstellungen unter dem Schalter, dazu `/peon teilen`.
4. Wie wird im Spiel geprüft? **An sich selbst:** `/peon teilen pruefen` schickt eine Kanal-Nachricht und ein Addon-Flüstern an den eigenen Charakter und liest die Mitgliederliste.

## 7. Umsetzung in Peon 0.23.0

- Datei `addons/Peon/Comm.lua`, Tests `tests/test_comm.lua`.
- Nachricht: `1^dienst^urheber^sprünge^flags^nummer^teil^teile^daten`, höchstens 255 Zeichen. Flag `d` = direkt, nicht weitergeben. Daten in einem eigenen Format verpackt (kein Lua-Code), `^`, `|`, `~` und Nullzeichen maskiert. Bis zu acht Teile je Nachricht.
- Begrüßung 30 Sekunden nach dem Betreten der Welt an drei Mitglieder, danach alle 30 Minuten. Ist dann noch niemand im Kanal, holt der Wächter (jede Minute) sie nach. Wer eine direkte Begrüßung bekommt, antwortet einmal (höchstens alle 10 Minuten je Urheber). Neue Mitglieder im Kanal werden direkt begrüßt.
- `PeonDB.comm.peers[Prüfwert] = { first, last, n, hops, v, a }`, höchstens 200.
- Nächster Schritt nach dem Test: Dienst `nodes` in Peon_Profession, fremde Stellen getrennt von den eigenen mit höchstens 5 Prüfwerten je Stelle.

### 7.1 Prüfung im Spiel allein (17.11.2026)

Von KarloDerBaer mit `/peon teilen pruefen` ausgeführt (Build 70938), Ergebnis aus `PeonDB.comm.probe`:

| Punkt | Ergebnis |
|---|---|
| Kanal `PeonNet` betreten | ja |
| Kanal-Nachricht gesendet / zurückgekommen | ja / **ja** |
| Flüstern an sich selbst gesendet / zurückgekommen | ja / **nein** |
| Mitgliederliste | 1 Eintrag (der eigene), gemeldete Anzahl 0 |

Das Flüstern scheiterte, weil Peon nur den Vornamen nahm. Im Chat stand „nicht online“ mit dem Vornamen. Forever-Charaktere haben Vor- und Nachnamen (`UnitName` liefert den Nachnamen als zweiten Wert). Seitdem nimmt Peon den vollen Namen, und „Vorname Nachname“ und „Vorname-Nachname“ gelten als derselbe Spieler. Die Prüfung flüstert in beiden Schreibweisen und merkt sich, welche ankommt, dazu die Form der Namen aus Mitgliederliste, Spieler-ID und Absender.

**Zweite Prüfung mit vollem Namen (17.11.2026):** Kanal-Nachricht zurück: ja. Flüstern an sich selbst: ja, als „Vorname Nachname“ und als „Vorname-Nachname“. Namen aus Mitgliederliste, Spieler-ID und Absender kommen alle als „Vorname Nachname“ mit Leerzeichen. Allein ist damit alles geprüft. Offen bleibt nur, was zwischen zwei Spielern ankommt. Ebenso ist offen, ob die Kanal-Nachricht nur an den Absender zurückgeht oder alle Mitglieder erreicht. Klären lässt sich das nur mit zwei Spielern im Kanal.

### 7.2 Test über den Kanal im Release (KarloDerBaer, 17.11.2026)

- Die Begrüßung geht zusätzlich höchstens alle 30 Minuten einmal als Addon-Nachricht in den Kanal (Flag `d`, keine Weitergabe), auch wenn die Mitgliederliste sonst niemanden zeigt. Direkte Begrüßungen an neue Mitglieder bleiben Flüstern.
- Wer sie bekommt, antwortet per Flüstern. So prüft dieselbe Begrüßung beide Wege zwischen zwei Spielern.
- `PeonDB.comm.peers[Prüfwert]` zählt je Nutzer `w` (per Flüstern angekommen) und `c` (über den Kanal angekommen), dazu `chanSent` und `chanRecv`.
- Auswertung nach dem Release: Stehen bei fremden Nutzern `c`-Werte, erreicht der Kanal andere Mitglieder. Stehen `w`-Werte, geht Flüstern zwischen Spielern.

### 7.3 Peon_Debug (privat)

Privates Werkzeug von KarloDerBaer im Ordner `privat/` (steht in `.gitignore`, liegt also nicht im Repo und kommt in kein Release). Zwei Schalter, getrennt für Kanal und Flüstern: Der Kanal bleibt im Chatfenster und jede Peon-Nachricht im Kanal erscheint lesbar im Chat. Jedes Peon-Flüstern erscheint im Chat, die Meldung „nicht online“ wird nicht ausgeblendet. Dafür hat der Kern `Peon.Comm.Listen` und `Peon.Comm.SetShow`. Befehl `/pdebug kanal`, `/pdebug fluestern`, `/pdebug hallo` (Begrüßung sofort senden), Einstellungen unter Peon > Debug. Im Spiel bestätigt (17.11.2026): Die Kanal-Begrüßung geht raus und kommt beim Absender lesbar zurück (Dienst `hello`, Sprung 0, Flag `d`, Version und Kern-API).
