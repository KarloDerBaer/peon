# Peon_Bags: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 0.3.0

Kurz: In Taschen und Bank kannst du jetzt eigene Bereiche anlegen und Gegenstände per Ziehen auf die Überschrift zuordnen, zum Beispiel alles, was du behalten willst.

- 0.3.0 (06.11.2026, Idee von KarloDerBaer, Konzept `Peon_Bags_Bereiche.md`, Bauabschnitte B1 bis B3):
  - **Eigene Bereiche:** frei benennbar, oben im Fenster von Taschen und Bank, in beiden Anordnungen, accountweit. Bei „Taschenreihenfolge“ steht der Rest unter „Übrige“. Ohne Bereiche sieht das Fenster aus wie bisher. Die Gildenbank bleibt unverändert.
  - **Zuordnen:** Gegenstand auf die Überschrift ziehen oder mit dem Gegenstand am Mauszeiger darauf klicken. Er geht zurück in seinen Platz und steht im Bereich, auch weitere Stapel und Stapel aus der Reagenzientasche. Auf „Übrige“ oder eine feste Überschrift gelegt, verlässt er den Bereich. Gegenstände mit Zusatz werden je Variante getrennt.
  - **Verwalten:** Abschnitt „Eigene Bereiche“ auf der Optionsseite: neu, umbenennen, löschen (Rückfrage, wenn Gegenstände zugeordnet sind), nach oben und unten. „Standardwerte“ lässt Bereiche und Zuordnung stehen.
  - Braucht jetzt Peon API 7 (Liste auf der Optionsseite). Neue Datei `Groups.lua`, deshalb WoW neu starten.
  - **Im Spiel prüfen:** Ablegen per Ziehen und per Klick (Gegenstand wieder im selben Platz, ohne Sperre und ohne Fehlermeldung), Teilstapel nach Umschalt+Klick, Zuordnen im Kampf (Plätze rücken danach, Tränke bleiben benutzbar), Bank, Reagenzientasche, Gegenstände mit Zusatz, Fenster ziehen an einer Überschrift, Eingabefelder der Rückfragen.

## 0.2.2

Kurz: Das Taschenbild wird wieder angezeigt und der Ring verdeckt die Taschenleiste nicht mehr.

- 0.2.2 (05.11.2026, Fehler von KarloDerBaer beim ersten Test in Forever):
  - **Taschenbild fehlte:** Das runde Feld oben links war leer und durchsichtig, weil das Bild gesetzt wurde, bevor das Fenster seinen Rahmen kannte. Die Bank war nicht betroffen, sie setzt ihr Bild beim Öffnen erneut.
  - **Ring zu groß:** Das Fenster hatte den großen Ring von Blizzards Vorlage, der in die erste Schaltfläche der Taschenleiste ragte. Jetzt der kleine Ring von Blizzards Taschen (`HeldBagLayout`), die runde Maske liegt genau auf dem Bild.
  - **Im Spiel prüfen:** Taschenbild rund und mittig im Ring, Taschenleiste frei.

## 0.2.1

- 0.2.1 (23.10.2026, vorbeugend nach dem Tooltip-Fehler): Beim Öffnen der Taschen liest Peon_Bags die Aufrufkette (`debugstack`), um interne Weiterleitungen von Blizzard zu erkennen. Ist sie geheim, wird sie nicht mehr durchsucht (sonst derselbe Lua-Fehler wie in Tooltip 0.7.1), sondern als leer behandelt.

## 0.2.0

- 0.2.0 (07.10.2026, Wünsche KarloDerBaer nach dem ersten Test):
  - **Knopf „Nach Art“** als Umschalter statt „Anordnung: Taschenreihenfolge“ (Text war zu lang): grau = Taschenreihenfolge, farbig = nach Art. Taschen, Bank und Gildenbank.
  - **Rahmen wie Blizzards Fenster:** Taschen mit Blizzards Taschen-Vorlage (`PortraitFrameFlatTemplate`, brauner Rahmen, kleines rundes Taschenbild wie Blizzards kombinierte Taschen), Bank mit Blizzards Bank-Vorlage (`PortraitFrameTemplate`, Bild des Bankiers), Gildenbank wie bisher (`BasicFrameTemplateWithInset`, Blizzards Gildenbank ist ebenfalls schlicht). Rückfall wie bisher. Taschenleiste und Knöpfe rücken neben das runde Bild.
  - **Im Spiel prüfen:** Aussehen (Titel, Bild, Abstände), Knopf grau/farbig gut unterscheidbar.

## 0.1.0

- 0.1.0 (07.10.2026, Bauabschnitte T1–T4):
  - **Taschenfenster:** alle Taschen (0–4) in einem Raster, **Reagenzientasche als eigener Abschnitt**; Kopf mit Name, Taschenleiste (Taschen tauschen per Klick/Ziehen, Überfahren hebt die Plätze der Tasche hervor), Suchfeld; Knöpfe „Anordnung: …“ und „Sortieren“ (nur wenn das Spiel `C_Container.SortBags` hat); Fuß mit freien Plätzen („19/26 frei   Reagenzien 11/12“) und Gold. Ziehen am Fenster verschiebt, Position gemerkt; ESC schließt.
  - **Anordnung** per Knopf umschaltbar (gemerkt): Taschenreihenfolge oder **nach Art** mit Abschnitten Ausrüstung, Verbrauchbares, Handwerk, Quest, Sonstiges, Müll, Frei (Art aus `C_Item.GetItemInfoInstant`, darin nach Qualität, Name, Anzahl). Die Reagenzientasche bleibt eigener Abschnitt.
  - **Plätze** = Blizzards Taschenknöpfe (`ContainerFrameItemButtonTemplate`, Rahmen-ID = Tasche, Knopf-ID = Platz, dazu `SetBagID`): Benutzen, Ziehen, Stapel teilen, Verkaufen am Händler, Tooltip macht Blizzards Code. Angezeigt: Symbol, Anzahl, Qualitätsrahmen, Questgegenstände, neue Gegenstände leuchten (bis Überfahren), Müll abgedunkelt mit Münzsymbol, Abklingzeit, gesperrt grau. Alle Knöpfe werden beim Einloggen angelegt; im Kampf neu dazugekommene Plätze und Anordnen geschützter Knöpfe werden nach dem Kampf nachgeholt.
  - **Suche:** Namensteil, Groß/klein und Umlaute egal; Treffer hell, Rest blass; gilt in allen drei Fenstern.
  - **Öffnen:** B-Taste und Taschenknöpfe (Blizzards `ToggleAllBags`/`ToggleBackpack`/`ToggleBag` nur mitgelesen), automatisch an Händler, Bank, Briefkasten, Auktionshaus, Handel, Gildenbank (je abschaltbar; schließt mit dem Fenster des Spiels, wenn es automatisch aufging). Blizzards Taschenfenster werden in einen versteckten Rahmen umgehängt.
  - **Bank:** eigenes Fenster mit der Bank; Blizzards Bankfenster wird in einen winzigen, unsichtbaren Rahmen umgehängt (bleibt offen, damit die Bank nicht schließt). Bank-Taschen aus `Enum.BagIndex` (Namen mit „bank“), nur Taschen mit Plätzen; Materiallager und Accountbank als eigene Abschnitte, falls sie Plätze haben. Knöpfe Anordnung, Sortieren (`SortBankBags`), „Blizzard“ (zeigt für diesen Besuch Blizzards Fenster, z. B. zum Kaufen von Plätzen). X/ESC schließt die Bank (`C_Bank.CloseBankFrame`).
  - **Gildenbank (vorbereitet, ungetestet):** Reiter je Fach (Symbol, grau ohne Rechte, Tooltip mit übrigen Abhebungen), 98 Plätze, Linksklick/Ziehen nimmt bzw. legt ab, Rechtsklick in die Taschen, Umschalt teilt Stapel, Gold und „heute noch abhebbar“, Einzahlen/Abheben mit eigener Rückfrage (Geld-Eingabe), Knopf „Blizzard“ (Protokoll, Rechte, Fächer kaufen). Nur wenn alle nötigen Funktionen da sind und Bagnon_GuildBank nicht geladen ist.
  - **Bagnon geladen:** Peon_Bags ersetzt nichts (Hinweis im Chat und in den Optionen), `/peon bags` öffnet trotzdem.
  - **Optionsseite:** Hauptschalter, Gildenbank ersetzen, Status; je Fenster Spalten, Größe, Anordnung; Taschenleiste; Qualitätsrahmen, Neu-Leuchten, Müll; automatisch öffnen (6 Haken); „Fensterpositionen zurücksetzen“, „Standardwerte“.
  - Bereiche für Peon_Feedback: Taschen, Bank, Gildenbank, Anordnung, Suche, Plätze, Öffnen/Schließen, Taschenleiste, Optionen.
- **Nächster Schritt:** Test im Spiel (**WoW komplett neu starten** – neuer Addon-Ordner). Dafür **Bagnon und BagBrother in der Addonliste abschalten** (sonst bleibt Peon_Bags passiv). Prüfen:
  - Benutzen, Ziehen, Stapel teilen, Anlegen, Verkaufen am Händler aus dem Fenster – auch im Kampf (Tränke), in beiden Anordnungen; keine Meldung „Aktion wegen AddOn blockiert“.
  - B-Taste, Taschenknöpfe, ESC; Blizzards Taschen bleiben weg; Taschenleiste (Tasche tauschen).
  - Bank: Rechtsklick legt in die Bank bzw. holt heraus; Bank schließt mit X; Knopf „Blizzard“; Was sind Taschen 7–14? Gibt es `SortBags`/`SortBankBags`?
  - Alt+Klick öffnet Ledger; Tooltip-Teile (Peon_Tooltip) unverändert.
  - Später Gildenbank: Fächer, Nehmen/Ablegen, Gold, Rechte, Blizzard-Knopf. Bagnon hat bei 12.1 eine Besonderheit beim Verstecken des Gildenbank-Fensters – falls das Fenster zuckt oder schließt, hier ansetzen.
