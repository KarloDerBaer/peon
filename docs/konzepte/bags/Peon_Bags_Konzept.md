# Peon_Bags – Konzept (abgestimmt)

Stand: 07.10.2026, mit KarloDerBaer abgestimmt; T1–T4 umgesetzt in Peon_Bags 0.1.0. Neues Modul **Peon_Bags** für Taschen, Bank und Gildenbank. Es ersetzt Bagnon, Bagnon_Bank und Bagnon_GuildBank; BagBrother entfällt, weil Ledger die Bestände der Twinks schon zeigt.

## 1. Ziel

- Eigene Anzeige für Taschen, Bank und Gildenbank in Peon, die KarloDerBaer nach seinen Wünschen anpassen kann.
- **Schlank:** vorerst keine Broker- oder Ledger-Anzeigen im Fenster (Entscheidung KarloDerBaer). Einbindung später, wenn gewünscht – die Grundlage (eigener Code, Peon-Kern) macht das jederzeit möglich.
- **Twinks:** werden nicht in Peon_Bags aufgenommen; dafür reicht Ledger (Reiter Bestand, Tooltip).
- Später: Anmeldung beim Mover (M4).

## 2. Ausgangslage

- **Installiert:** Bagnon 12.1.5 mit BagBrother (rund 13.500 Zeilen Lua inkl. Bibliotheken), Bagnon_Bank, Bagnon_Config, Bagnon_GuildBank (Fassung „Mainline“ = Retail-Oberfläche, die Forever nutzt).
- **KarloDerBaers Bagnon-Einstellungen** sind fast Standard: Taschenfenster unten rechts mit sichtbarer Taschenleiste, Seitenleiste mit Filtern „alle / normale Taschen / Handwerk“; Bankfenster oben links. Keine eigenen Regeln, Farben oder Profile.
- **Forever (aus den Prüfungen von Ledger):**
  - 6 Taschen (0–5), Tasche 5 mit 12 Plätzen (vermutlich die Reagenzientasche), Schlüsselbund −1.
  - Bank: Tasche 6 mit 48 Plätzen, dazu 7–14 ohne Plätze (kaufbare Fächer oder Bank-Taschenplätze – im Spiel prüfen). Accountbank-Nummern ohne Plätze. `IsReagentBankUnlocked` fehlt.
  - Gildenbank gibt es (100 Gold); KarloDerBaer hat noch keine.
- **Bagnon ist „All Rights Reserved“.** Kein Code wird übernommen, nur das Wissen, wie Blizzards Schnittstellen funktionieren (wie beim Mover mit BlizzMove).

## 3. Taschen

- **Ein Fenster für alle Taschen** (0–4), **Reagenzientasche (5) als eigener Abschnitt** unten im Fenster mit eigener Überschrift (KarloDerBaer). Spaltenzahl und Größe einstellbar.
- **Anordnung umschaltbar** (KarloDerBaer) – Knopf im Fenster, Wahl wird gemerkt:
  - **Taschenreihenfolge:** Plätze wie im Spiel, Tasche für Tasche.
  - **Nach Art:** Abschnitte mit Überschrift, z. B. Ausrüstung, Verbrauchbares, Handwerk, Quest, Sonstiges, Müll; leere Plätze am Ende als eigener Abschnitt „Frei“. Die Art kommt aus `C_Item.GetItemInfoInstant` (Klasse des Gegenstands). Innerhalb eines Abschnitts nach Qualität, dann Name.
  - Die Plätze sind in beiden Ansichten dieselben Knöpfe, nur anders angeordnet – Benutzen, Ziehen usw. gehen in beiden gleich.
- **Taschenleiste** ein-/ausblendbar: Taschen tauschen und anlegen, beim Überfahren werden die Plätze dieser Tasche hervorgehoben.
- **Kopf:** Name des Charakters, Suchfeld, Knöpfe (Anordnung, Bank – nur bei offener Bank, Sortieren, Optionen). **Fuß:** freie Plätze („23/96 frei“), Gold.
- **Plätze:** Symbol, Anzahl, Abklingzeit, Rahmen in Qualitätsfarbe (einstellbar), Questgegenstände markiert, neue Gegenstände leuchten bis zum Überfahren, Müll (grau) abgedunkelt (einstellbar), gesperrte Plätze ausgegraut.
- **Bedienung wie bei Blizzard:** Rechtsklick benutzt, Ziehen, Umschalt+Klick verlinkt bzw. teilt Stapel, Strg+Klick Anprobe, Alt+Klick öffnet den Gegenstand in Ledger (über Ledgers vorhandenes Alt+Klick).
- **Suche:** Namensteil; Groß-/Kleinschreibung und Umlaute egal (wie Broker). Treffer hell, Rest abgedunkelt.
- **Öffnen:** B-Taste, Taschenknöpfe, `/peon bags`. Automatisch öffnen bei Händler, Bank, Post, Auktionshaus, Handel, Gildenbank – je Fenster einstellbar (Standard: alle an).
- **Sortieren:** Blizzards eigene Sortierung (`C_Container.SortBags` bzw. `SortBankBags`), falls Forever sie hat; sonst ist der Knopf nicht da.

## 4. Bank

- Eigenes Bankfenster, erscheint mit der Bank (Blizzards `BankFrame` wird dabei ausgeblendet). Aufbau wie die Taschen: Plätze, Anordnung umschaltbar (eigene Einstellung), Leiste mit Bank-Taschen bzw. Fächern, freie Plätze, Suche.
- Welche Taschennummern zur Bank gehören, nimmt Peon_Bags wie Ledger aus `Enum.BagIndex` (Namen mit „Bank“; Rückfall klassische Belegung); nur Taschen mit Plätzen werden gezeigt.
- Kaufen weiterer Bankplätze/Fächer: über Blizzards eigenen Knopf (im Spiel prüfen, ob er erreichbar bleibt; sonst Knopf in Peon_Bags, der Blizzards Kauf-Rückfrage öffnet).
- Ohne offene Bank gibt es kein Bankfenster (Bestand der Bank zeigt Ledger).

## 5. Gildenbank (vorbereitet, erst später testbar)

Gebaut nach Blizzards Retail-Schnittstelle, die Forever laut Bagnon_GuildBank „Mainline“ verwendet. Alles abgesichert: Fehlt eine Funktion, bleibt Blizzards Gildenbank-Fenster wie gehabt.

- **Öffnen/Schließen:** `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` mit Typ Gildenbank (`Enum.PlayerInteractionType.GuildBanker`), Blizzards `GuildBankFrame` wird ausgeblendet.
- **Fenster:** Reiter je Fach (`GetNumGuildBankTabs`, `GetGuildBankTabInfo`: Name, Symbol, sichtbar, Einzahlen/Abheben erlaubt, Abhebungen übrig), 98 Plätze je Fach (7 × 14 wie bei Blizzard), Fach anfordern mit `QueryGuildBankTab`, Inhalt über `GetGuildBankItemInfo` / `GetGuildBankItemLink`, Aktualisierung bei `GUILDBANKBAGSLOTS_CHANGED`, `GUILDBANK_UPDATE_TABS`, `GUILDBANK_UPDATE_MONEY`, `GUILDBANK_UPDATE_WITHDRAWMONEY`.
- **Bedienung:** Linksklick/Ziehen nimmt bzw. legt ab (`PickupGuildBankItem`), Rechtsklick in die Taschen (`AutoStoreGuildBankItem`), Umschalt+Klick teilt den Stapel (`SplitGuildBankItem`) bzw. verlinkt. Gildenbank-Funktionen sind nicht geschützt, deshalb eigene einfache Knöpfe statt Blizzard-Vorlage.
- **Fuß:** Gold der Gildenbank, „heute noch abhebbar“, Knöpfe Einzahlen/Abheben (Blizzards Rückfragen `GUILDBANK_DEPOSIT` / `GUILDBANK_WITHDRAW` aufrufen, nicht nachbauen).
- **Erst einmal nicht:** Protokoll (Log), Infotext je Fach, Fächer kaufen, Rechte bearbeiten – dafür Knopf „Blizzard-Fenster“, der Blizzards Gildenbank für diesen Besuch zeigt.
- Suche und Anordnung wie bei der Bank.
- **Hinweis Ledger:** Ein- und Auslagern in die Gildenbank erfasst Ledger weiterhin nicht (eigener Punkt, siehe Stand). Peon_Bags ändert daran nichts.

## 6. Mover und Tooltip

- Bis M4 merkt sich Peon_Bags die Position je Fenster selbst (Ziehen am Kopf), Größe in den Optionen. Mit M4 meldet es seine Fenster über `Peon.RegisterWindow` beim Mover an.
- Im Mover bleiben die Blizzard-Taschen ausgenommen.
- Tooltip: Die BagBrother-Zeilen entfallen, sobald BagBrother abgeschaltet ist; den Bestand zeigt Ledger. In Peon_Tooltip erscheint „BagBrother“ dann als nicht geladen (Entfernen-Knopf).

## 7. Optionsseite (Einstellungen > AddOns > Peon > Bags)

- **Allgemein:** „Blizzard-Taschen ersetzen“ (Hauptschalter, Standard an; wirkungslos, solange Bagnon geladen ist – Hinweis), Gildenbank ersetzen (an).
- **Taschen:** Spalten, Größe, Taschenleiste anzeigen, Anordnung (auch per Knopf im Fenster).
- **Bank / Gildenbank:** Spalten, Größe, Anordnung.
- **Plätze:** Qualitätsrahmen, neue Gegenstände leuchten, Müll abdunkeln.
- **Automatisch öffnen:** Händler, Bank, Post, Auktionshaus, Handel, Gildenbank.
- Knopf „Fensterpositionen zurücksetzen“, „Standardwerte“.

SavedVariables: `PeonBagsDB` (accountweit: Einstellungen, Fensterpositionen). Kein Speicher je Charakter nötig (keine Daten, nur Anzeige).

## 8. Technik und Risiken

1. **Blizzards Taschenknöpfe nutzen:** Jeder Taschen-/Bankplatz ist ein Knopf aus `ContainerFrameItemButtonTemplate` in einem kleinen Rahmen je Tasche (Rahmen-ID = Taschennummer, Knopf-ID = Platznummer). Blizzards eigener Code erledigt Klicks, Benutzen, Ziehen und Stapel teilen – auch im Kampf. Übliches Verfahren (so macht es auch Bagnon).
2. **Kampf:** Knöpfe werden vorab angelegt (Taschen beim Login, Bank beim ersten Öffnen). Wächst eine Tasche im Kampf, kommen neue Plätze nach dem Kampf dazu; Umordnen (Anordnung „nach Art“) im Kampf wird ebenfalls nachgeholt, falls das Spiel es verbietet.
3. **Blizzard-Fenster ausblenden ohne Ersetzen:** nur mitlesen (`hooksecurefunc` auf `ToggleAllBags`, `ToggleBackpack`, `ToggleBag`, `OpenAllBags`, `CloseAllBags`, `OpenBackpack`, `CloseBackpack`); Blizzards Taschenfenster werden beim Öffnen in einen unsichtbaren Rahmen umgehängt. Keine Blizzard-Funktion und keine Blizzard-Tabelle neu zuweisen (Lehre aus Broker 0.4.0). ESC schließt über `UISpecialFrames` (nur Eintrag hinzufügen).
4. **Aktualisieren nur über Ereignisse:** `BAG_UPDATE_DELAYED` (nur geänderte Taschen), `ITEM_LOCK_CHANGED`, `BAG_UPDATE_COOLDOWN`, `BAG_NEW_ITEMS_UPDATED`, `QUEST_ACCEPTED`/`QUEST_REMOVED`, `PLAYER_MONEY`, Bank über `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` und `PLAYERBANKSLOTS_CHANGED`. Kein Neuzeichnen in jedem Bild.
5. **Keine fremden Bibliotheken**, nur der Peon-Kern.
6. **Testen:** Daten, Anordnung, Suche, Öffnen/Schließen, Bank- und Gildenbank-Logik mit lua5.1 und nachgebauter API. Klicks und Taint nur im Spiel prüfbar – Testliste je Bauabschnitt.

## 9. Umstieg von Bagnon

- Bagnon bleibt installiert, bis Peon_Bags im Spiel stabil läuft.
- **Solange Bagnon geladen ist, ersetzt Peon_Bags nichts** (Hinweis in den Optionen); das Fenster öffnet nur mit `/peon bags`. So streiten sich die beiden nicht um B-Taste, Bank und Gildenbank.
- Wenn alles passt: Bagnon, Bagnon_Bank, Bagnon_Config, Bagnon_GuildBank und BagBrother abschalten, später löschen. Ihre Daten in WTF werden nicht übernommen.

## 10. Entschieden (KarloDerBaer, 07.10.2026)

1. Name **Peon_Bags**.
2. Reagenzientasche als **eigener Abschnitt**.
3. Anordnung **Taschenreihenfolge und nach Art**, umschaltbar per Knopf im Fenster.
4. Fenster **schlank**, vorerst keine Broker-/Ledger-Anzeigen (Wert, Markierungen, Filter, Müll verkaufen, Kosten).
5. **Twinks nicht in Peon_Bags**, Ledger reicht.
6. **Gildenbank vorbereiten** nach Blizzards Schnittstelle, Test erst, wenn KarloDerBaers Gilde eine hat.

## 11. Bauabschnitte

- **T1** Grundgerüst aus `vorlage\Peon_Beispiel`, Taschenfenster (Plätze, Reagenzien-Abschnitt, Taschenleiste, Gold, freie Plätze), Öffnen/Schließen, Blizzard-Taschen ausblenden, Hauptschalter und Bagnon-Erkennung.
- **T2** Plätze vollständig (Qualität, neu, Quest, Müll, Abklingzeit), Anordnung nach Art mit Umschaltknopf, Suche, Sortieren, automatisch öffnen, Optionsseite, Bereiche für Peon_Feedback.
- **T3** Bankfenster.
- **T4** Gildenbank (vorbereitet, ungetestet).
- **T5** Mover M4 (zusammen mit Kern API 11).

T1–T4 können zusammen geliefert werden; im Spiel zuerst Taschen und Bank testen.

## 12. Im Spiel prüfen

- Benutzen, Ziehen, Stapel teilen und Anlegen aus dem Fenster, auch im Kampf (Tränke) und in beiden Anordnungen. Keine Meldung „Aktion wegen AddOn blockiert“.
- B-Taste, Taschenknöpfe und ESC öffnen bzw. schließen richtig; Blizzards Taschen bleiben weg.
- Gibt es `C_Container.SortBags`? Was sind die Bank-Nummern 7–14, lassen sich Bankplätze kaufen?
- Später Gildenbank: Fächer, Nehmen/Ablegen, Gold, Rechte.
