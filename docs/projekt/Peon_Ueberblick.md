# Peon – Überblick für neue Arbeiten

Stand: 25.10.2026. Addon-Sammlung von KarloDerBaer für **WoW Forever** (bis 23.10. Beta, ab 25.10. Ordner der Release-Version `_forever_`), Client 1.60.1 (70009), **Interface 16001**, deutscher Client (deDE, Texte zusätzlich enUS).

## Wo alles liegt

Das Repo ist öffentlich. Statt echter Pfade stehen hier Platzhalter: `<Repo>`, `<Archiv>`, `<WoW-Ordner>`, `<WoW-Beta-Ordner>`, `<Programmordner>`, `<alter Programmordner>`. Die echten Pfade stehen in `CLAUDE.local.md` (nur auf dem Rechner von KarloDerBaer, nicht im Repo).

- **Repo (ab 31.10.2026):** `<Repo>\` ist ein Git-Repo und die maßgebliche Quelle für Code und Doku:
  - `addons\` Addon-Code (maßgeblich). Im AddOns-Ordner des Spiels steht jeder Peon-Ordner auf einer von zwei Arten (`scripts\junctions.cmd`, siehe „Arbeitsweise“): Manager (echter Ordner, Normalzustand ab 06.11.2026) oder Entwicklung (Junction auf `addons\<Modul>`). Code nur in `addons\` ändern.
  - `manager\` Quellcode des Programms (bisher `client\`, Anleitung in `manager\README.md`)
  - `docs\` Doku, Inhaltsverzeichnis in `docs\README.md`: `projekt\` (Überblick, Stand, Entscheidungen, Vorlage), `konzepte\<modul>\` (Konzepte und Designs), `changelog\<Modul>.md` (Verlauf der Versionen, neueste oben), `archiv\` (abgelöste Konzepte)
  - `tests\` (Testdateien, `run_tests.cmd` für Windows, `run_tests.sh` für Git Bash und Linux, beide laufen auf `addons\`), `tools\` (Lua 5.1), `vorlage\` (Vorlage für neue Module), `scripts\` (Junctions, Release-Bau)
  - `CLAUDE.md` Arbeitsregeln für Claude Code
- Archiv außerhalb des Repos: `<Archiv>\` (alte Lieferungen `eingang\`, `Claude outputs\`, Peon_Feedback 0.2.0, Sicherungen)
- AddOns-Ordner des Spiels: `<WoW-Ordner>\Interface\AddOns\` (ab 25.10.2026)
- Einstellungen: `<WoW-Ordner>\WTF\Account\<Konto>\SavedVariables\` (accountweit) und `...\<Realm-Nummer>\<Charakter-Realm>\SavedVariables\` (pro Charakter, z. B. `93\<Charakter-Realm>`). Unter `WTF\Account` liegen bei KarloDerBaer mehrere Kontoordner, gespielt wird im Ordner mit Buchstaben-Namen (Stand 31.10.2026). Echte Konto- und Charakternamen stehen nicht im Repo, weil es öffentlich ist. Release-Server sind EU (`portal "EU"`, Stresstest 21.10.2026).
- Beta (beendet, nur noch zum Nachsehen): `<WoW-Beta-Ordner>\`. Dort sind einige Dateien schreibgeschützt, nicht mehr hineinschreiben.
- Programm Peon Manager (bis 0.5.0 Peon Client): `<Programmordner>\Runtime\PeonManager.exe`, Daten in `<Programmordner>\DB\`. Der alte Ordner `<alter Programmordner>` (Runtime 0.5.0, DB, DB_beta) bleibt als Sicherung.
- In `addons\` liegt nur Addon-Code (keine Notizen, Kopien oder Testdateien). Ausnahme: `Peon_Bridge\Data.lua`, die der Peon Manager schreibt (nicht im Repo).
- Gearbeitet wird mit **Claude Code** direkt im Repo auf KarloDerBaers PC. Zusätzlich freigeben: `<WoW-Ordner>` (AddOns, WTF) und `<Programmordner>`.
- Die Doku liegt nur noch im Repo. Das Claude-Projekt „Peon - WOW Forever Addon“ wird nicht mehr mitgepflegt, einzelne Dokumente lädt KarloDerBaer bei Bedarf für Gespräche im Chat hoch.

## Aufbau

- **Peon** ist das Kern-Addon (Name ohne „_Core“), Module heißen `Peon_<Funktion>`.
- Module sind eigene Addons mit `## Dependencies: Peon` und `## Group: Peon` (in Forever getestet: Module stehen eingerückt unter Peon in der Addonliste).
- TOC-Titel: `|cff8ccf4dPeon|r <Name>` (Peon-Grün 8ccf4d), eigenes `## IconTexture:`.
- Einstellungen: Einstellungen > AddOns > **Peon** (Übersicht aller Module) mit Unterseiten je Modul.
- Chat: `/peon` (Optionen), `/peon list`, `/peon debug <modul>`, `/peon <modul> [befehl]`.

| Addon | Version | SavedVariables | Befehl |
|---|---|---|---|
| Peon | 0.16.1 | `PeonDB` | /peon |
| Peon_Tooltip (früher TooltipPlus) | 0.7.4 | `PeonTooltipDB` | /ttp |
| Peon_ComboPoints (früher Combo Point Display) | 3.5.1 | `PeonComboPointsDB` | /peon combopoints |
| Peon_Fishing (früher FishingPlus) | 1.6.0 | `PeonFishingDB`, `PeonFishingCharDB` (pro Charakter) | /fp |
| Peon_Broker (neu, Auktionshaus) | 0.53.1 | `PeonBrokerDB`, `PeonBrokerCharDB` (pro Charakter) | /broker |
| Peon_Bridge (bis 0.3.0 Peon_Client, Verbindung zum Peon Manager) | 0.9.0 | `PeonBridgeDB` | /peon bridge |
| Peon_Feedback | 0.4.0 | `PeonFeedbackDB` | /feedback |
| Peon_Mover (neu, Fenster verschieben) | 0.1.0 | `PeonMoverDB` | /peon mover |
| Peon_Ledger (neu, Bestand und Buch) | 0.13.0 | `PeonLedgerDB` | /ledger |
| Peon_Bags (neu, Taschen, Bank, Gildenbank) | 0.4.0 | `PeonBagsDB` | /peon bags |
| Peon_Panel (neu, Leiste und Panel) | 0.4.0 | `PeonPanelDB` | /peon panel |

**Peon_Bridge und Peon Manager (ab 31.10.2026):** Die Bridge ist die Verbindung zwischen Spiel und Manager. Inhalte melden sich in der Bridge als Kanal an (`ns.RegisterChannel`, intern im Addon, nicht Teil der Kern-API), der erste ist `broker`. Der Manager schaltet Kanäle über `Data.lua` frei (`PeonBridgeData.fmt = 2`, `channels = { broker = true }`). Ohne Freischaltung zeichnet die Bridge nichts auf und liefert Broker keine Werte, Broker rechnet dann selbst. Format und Plan: `docs\konzepte\manager\Peon_GitHub_Design.md`.

## Kern-API (Peon.API = 16)

Die API wird nur erweitert, nie geändert (sonst brechen alle Module). Bei neuen Funktionen `Peon.API` erhöhen.

**Global `Peon`:** `version`, `API`, `L`, `NewLocale()`, `Print`, `IsSecret(v)`, `S(v)` (sicherer Text), `InCombat()`, `CopyTable`, `Clamp(wert, {min,max,schritt})`, `GetMetadata`, `IsAddOnLoaded`, `GetModule(key)`, `OpenOptions()`, `POSITIONS` / `POSITION_SET` (3×3-Raster mit "none" in der Mitte).

**Modul anlegen** (erste Code-Datei des Moduls):
```lua
local ADDON_NAME, ns = ...
local mod = Peon:NewModule(ADDON_NAME, {
    key = "beispiel", title = "Beispiel",
    db = "PeonBeispielDB", charDB = nil, charKeys = nil,
    oldDB = nil, oldCharDB = nil,                 -- alter Variablenname: Inhalt wird einmalig übernommen
    defaults = { ... },
    ranges   = { size = { 8, 32, 1 } },          -- Zahl: min, max, Schritt
    choices  = { mode = { a = true, b = true } }, -- erlaubte Werte
    validate = { x = function(v) return ... end },-- statt Typvergleich (z. B. Text ODER Zahl)
    migrate  = function(mod, acc, char) end,      -- vor den Standardwerten
    keepOnReset = { mode = true },                -- bleibt bei „Standardwerte“ erhalten (API 5)
    slash = { "/xy" }, onSlash = function(mod, cmd, rest) end,
})
mod:On("INIT", function() ... end)   -- SavedVariables bereit (ADDON_LOADED)
```
- Modul: `mod.db` (Sicht auf Account- und Charakterwerte), `acc`, `char`, `Print`, `Error`, `ReportError` (einmal pro Sitzung), `Call(wo, fn, ...)` (geschützt), `On/Fire` mit INIT, LOGIN, COMBAT_START, COMBAT_END, RESET, CHANGED, `RegisterEvent(event, fn)`, `ResetDefaults(ausnahmen)`, `Dbg` / `ToggleDebug` (Log in `acc.debugLog`, max. 2000 Zeilen, aus = gelöscht), `RegisterOptions(panel)`, `OpenOptions`.
- Standardwerte: Werte mit falschem Typ oder außerhalb von choices werden ersetzt, Zahlen auf ranges geklemmt, Tabellen kopiert.
- **Optionsseite** mit den Kern-Bausteinen (Widgets.lua):
```lua
local page = mod:NewOptionsPage({ desc = L.DESC })
local left = page:Column(16, -60)
page:Add(left, page:Header(L.HDR))
page:Add(left, page:Slider("size", L.SIZE, hint, "%", divisor))
page:Add(left, page:Check("enabled", L.ENABLED))
page:Add(left, page:Check("clickMode", L.CLICK, hint, { "double", "off" }))  -- API 5: Hinweis, eigene an/aus-Werte
page:Add(left, page:Dropdown("mode", L.MODE, { { "a", "A" }, { "b", "B" } }, hint))  -- API 6: Auswahlliste
page:Add(left, page:Dropdown("set", L.SET, ListeFn, nil, { get = fn, set = fn, empty = "…" }))  -- Liste per Funktion, eigene Lese-/Schreibfunktion
page:Add(left, page:Choice("corner", L.CORNER, { { "TOPLEFT", "…" }, … }, 2, 138))  -- Knopfreihe, nur für Positionen
page:Add(left, page:PositionGrid("icon", L.ICON))
page:Add(left, page:Color("fill", L.FILL, true))   -- true = mit Deckkraft
page:Add(left, page:Button(L.SAVE, function(page) ... end, hint))   -- API 5
page:Add(left, page:Text(function() return "..." end))            -- API 5: Text, der sich beim Anzeigen neu füllt
page:Add(left, eigenerContainer)   -- page:NewContainer(höhe) + c.Refresh = function() ... end
page:AddResetButton(L.SLASH_HINT, left, right)    -- unter der tiefsten der genannten Spalten
page.onRefresh = function() ... end               -- z. B. Abhängiges ausgrauen
page:Register()
-- Untertabs (API 11):
page:Tabs({ { "general", L.TAB_GENERAL }, { "items", L.TAB_ITEMS } }, -62)   -- Reiterleiste oben
local col = page:Column(16, -100, "general")       -- Spalte gehört zum Reiter (ohne = immer sichtbar)
page.onTab = function(page, key) end; page:SelectTab("items"); page:GetTab()
```
  Änderungen schreiben in `mod.db` und feuern `CHANGED`. **Die Seite muss spätestens bei INIT angemeldet werden**, denn der Kern hängt Unterseiten bei PLAYER_LOGIN ein; später angemeldete Seiten bekommen einen eigenen Eintrag.
  **Regel (KarloDerBaer):** Auswahl aus mehreren Möglichkeiten immer als Auswahlliste (`Dropdown`). Knopfreihen (`Choice`/`PositionGrid`) nur für Positionen, weil man dort die Lage sofort sieht.
  Ab API 5 ordnet `page:Refresh()` die Spalten neu an: Ändert ein Baustein seine Höhe (Text, eigener Container), rutscht alles darunter samt Reset-Knopf mit. Die Seite hat immer einen Bildlauf.
- **Liste (API 7, List.lua):** Spalten, Sortierung per Klick auf den Kopf (nochmal klicken = umgekehrt, leere Werte immer unten), Bildlauf mit Regler und Mausrad, Zeilen anklickbar.
```lua
local list = Peon.NewList(parent, {
    columns = { { key = "name", title = "Name", width = 160 },
                { key = "price", title = "Preis", width = 90, align = "RIGHT", format = function(v, item) ... end, sortValue = function(item) ... end } },
    rows = 10, rowHeight = 18, sortKey = "name", sortDesc = false, selectable = true,
    onClick = function(list, item, button) end, onEnter = function(list, item, row) end, onLeave = fn, emptyText = "…",
    rowColor = function(item) return r, g, b, a end })   -- API 8: Hintergrundfarbe je Zeile (nil = keine)
list.frame:SetPoint(...); list:SetData(items); list:Refresh(); list:Sort(key, desc); list:Select(item); list:GetSelected(); list:GetItems(); list:UpdateColors() -- API 8: nur Zeilenfarben (z. B. jedes Bild zum Pulsieren)
page:Add(left, page:List(opts))   -- auf Optionsseiten; Container hat .list, eigene Daten über container.Refresh = function() ... end
```
- **Minimap-Button (API 7, Minimap.lua):** wie der Fishing-Button, verschiebbar, Winkel und Sichtbarkeit in den Moduleinstellungen (Standardnamen `minimapAngle`, `minimapShow`; müssen in `defaults` stehen), aktualisiert sich bei CHANGED und RESET.
```lua
mod:NewMinimapButton({ icon = "Interface\\Icons\\…", name = "PeonXyMinimapButton",
    onClick = function(mod, button) end, onTooltip = function(mod, tooltip) tooltip:AddLine("…") end, hint = "Linksklick: …" })
```
- **Starter (API 14, Launcher.lua):** Eintrag eines Moduls für Peon_Panel, `mod:NewMinimapButton` legt ihn selbst an. Wählbare Texte über `texts`, eigene Menüeinträge über `menu`. Nach einer Änderung `mod.launcher:Refresh()`. Für knappe Texte `Peon.ShortNumber(n)` und `Peon.ShortGold(kupfer)`.
```lua
mod:NewLauncher({ icon = "...", showKey = "minimapShow", onClick = function(mod, button, owner) end,
    onTooltip = function(mod, tooltip) end, update = function(mod, iconTexture) end, menu = function(mod, root) end,
    texts = { { key = "free", label = "Freie Plätze", get = function(mod) return "23 frei" end } }, defaultText = "free" })
mod:AddLauncher({ key = "uhr", ... })   -- API 15: weiterer Starter eines Moduls, key ist Pflicht
-- API 15, neue Felder: onWheel = function(mod, delta, owner) end, available = function(mod) return true end
```
- **Gegenstandsmenü (API 16, ItemMenu.lua):** Strg+Rechtsklick (einstellbar, `PeonDB.itemMenuClick`) auf einen Gegenstand öffnet ein Menü. Module hängen Einträge an, zwischen Modulen eine Trennlinie. Tastenbelegung `PEON_ITEM_MENU`.
```lua
if Peon.AddItemMenu then Peon.AddItemMenu(ADDON_NAME, function(root, item)   -- item = { id, link, name }
    root:CreateButton("Info", function() ... end)
end, 10) end                                                                     -- order: kleiner zuerst
Peon.OpenItemMenu(item, owner)   -- z. B. aus eigenen Listen
```
- **Bereiche für Rückmeldungen (API 9, Feedback.lua):** Jedes Modul meldet seine Bereiche für Peon_Feedback und den Peon Manager (ab API 13 in `PeonDB.feedbackAreas`) mit einer Zeile (am Ende der ersten Code-Datei). Das `if` hält das Modul mit älterem Kern lauffähig; „Sonstiges“ hängt Feedback selbst an.
```lua
if Peon.SetFeedbackAreas then Peon.SetFeedbackAreas(ADDON_NAME, { "Bereich 1", "Bereich 2", "Optionen" }) end
Peon.GetFeedbackAreas(addonName)   -- Kopie der Liste, leer wenn nichts gemeldet
```
  Neue Module sollten ihre Bereiche mitmelden (in `vorlage\Peon_Beispiel` noch nicht enthalten).
- **Fehlerspeicher (API 12, Core.lua):** `mod:ReportError(where, err)` und `mod:Call` speichern abgefangene Fehler automatisch in `PeonDB.errors` und nennen sie einmal pro Sitzung kurz im Chat. Den Text zeigen `/peon fehler` und der Reiter Rückmeldungen im Peon Manager, der sie einliest und im Spiel löschen lässt.
```lua
Peon.RecordError(addonName, where, err, version)   -- speichern ohne Chat-Ausgabe, gleiche Fehler zaehlen hoch
Peon.ClearErrors(upTo)                             -- bis Zeitpunkt loeschen, ohne Angabe alle. Rueckgabe: Anzahl
```
- **Diagramm (API 10, Chart.lua):** zwei Achsen, Linien/Stufen/Flächen/Balken/Punkte/Markierungen, Mauslinie, Legende, verknüpfte Diagramme.
```lua
local ch = Peon.NewChart(parent, { width = 480, height = 130, left = 46, right = 46, grid = 2,
    leftFormat = function(v) return v .. "c" end, rightFormat = function(v) return v .. " St." end,
    onHover = function(chart, index) end, onLeave = function(chart) end })
ch:SetData(n, {   -- n Punkte; nil = Lücke; hidden = true = anfangs aus; gleicher key = gemeinsam an/aus
    { key = "md", kind = "line", axis = "left", values = {...}, color = { r, g, b, a }, width = 2, dash = 4, connect = true, label = "Median" },
    { key = "cost", kind = "step", values = {...} },
    { key = "zone", kind = "zone", values = a, values2 = b, color = gut, colorBelow = schlecht },   -- auch "band"
    { key = "st", kind = "bar", axis = "right", values = {...}, colorBelow = rot },
    { key = "p", kind = "points", shape = "circle" | "square", values = {...} },
    { key = "ev", kind = "marks", values = { [i] = true } }, { key = "h", kind = "hline", value = 33 } })
ch:SetRange("left", lo, hi); ch:GetRange("left"); ch:SetSize(w, h); ch:Draw(); ch:SetShown(key, bool); ch:SetHover(i)
ch:CreateLegend(parent, { "md", "cost" }, function(key, on) end)   -- Knöpfe an/aus, .frame zum Platzieren
Peon.LinkCharts({ ch1, ch2 }, { shareLeft = true })                -- gemeinsame Mauslinie, gleicher Bereich links
Peon.NiceRange(lo, hi, schritte)
```
- Ereignisse mit `RegisterUnitEvent` kann der Kern noch nicht; dafür hat ComboPoints einen eigenen Rahmen.
- Diagramm-Legende (ab 0.11): mehrere Reihen mit gleichem `key` → die Reihe mit `label` bestimmt Name und Farbe.

## Wichtige Erkenntnisse zu WoW Forever

- **Geheime Werte (Secret Values, aus Retail 12.x):** Sie werden bei Kampf-, Encounter- oder PvP-Einschränkungen geheim; in Instanzen sind Name, GUID und ID von NPCs immer geheim; UnitName von Nicht-Spielern ist im Kampf geheim. Erlaubt ist speichern, weiterreichen, `type()` und an Widgets übergeben (Text, Farbe, StatusBar). Verboten ist vergleichen, rechnen, boolesch prüfen oder als Tabellenschlüssel nutzen. Immer zuerst `Peon.IsSecret()` prüfen; `issecrettable` für Tooltip-Daten.
- **Auch `debugstack()` kann einen geheimen Text liefern** (Kampf, Instanz, Tooltip mit geheimen Daten; BugGrabber zeigt dann „debugstack() returned secrets“). `type()` meldet weiter „string“, aber `:find`/`:gmatch` brechen ab. Vor dem Durchsuchen immer `Peon.IsSecret(st)` prüfen (Tooltip 0.7.2, Bags 0.2.1).
- **Combo-Punkte** hängen am Gegner, nur einer trägt sie gleichzeitig. Der Trick: je Punkt eine StatusBar mit `SetMinMaxValues(i-1, i)`, alle bekommen denselben geheimen Wert. Der Träger wird über den Nameplate-Rahmen erkannt, nicht über GUID oder UnitIsUnit (die können geheim sein).
- **Tooltip:** `GameTooltip_UnitColor` liefert für Spieler nur Weiß; `UnitSelectionColor(unit, true)` gibt die richtige Haltungsfarbe. Verlässt die Maus ein Objekt in der Welt, ruft Blizzards `SetWorldCursor` erst `GameTooltip_SetDefaultAnchor` und dann `FadeOut` auf; Letzteres lässt sich mitlesen (Tooltip 0.7.4).
- **Angeln:** Der Schwimmer (GameObject 35591) wird über Soft Targeting erkannt (SoftTargetInteract 3, Arc 2, Reichweite einstellbar); etwa 25 % der Würfe werden nicht erkannt, deshalb Warnton und neu auswerfen. Fischschwärme sind nur über den Tooltip unter dem Mauszeiger erkennbar. Unterzonen melden teils englische Namen. Waffenwechsel mit Angel im Wasser geht nur per Makro mit `/stopcasting` über einen sicheren Button.
- **Klick mit Taste:** Alt+Klick auf Gegenstände gehört ab 06.10.2026 Peon_Ledger (Gegenstand zeigen); im Spiel belegt sind Umschalt+Klick (Link/Stapel teilen), Strg+Klick (Anprobe), Rechtsklick (benutzen); auf Aktionsleisten löst Alt+Klick zusätzlich die Taste aus.
- Geschützte Aktionen (Köder anlegen, auswerfen) nie automatisch, nur per Tastendruck oder Klick des Spielers.
- **Kein globales `GetItemInfo`** im Forever-Client, nur `C_Item.GetItemInfo` (gleiche Rückgabewerte, Händlerpreis = 11. Wert).
- **Blizzard-Tabellen nie neu zuweisen** (z. B. `StaticPopupDialogs = StaticPopupDialogs or {}`), nur Einträge hinzufügen (`StaticPopupDialogs["PEON_..."] = {...}`). Sonst ist die Tabelle für Blizzard-Code „verunreinigt“ (Taint), und z. B. ESC meldet ADDON_ACTION_FORBIDDEN für `SpellStopCasting()` (so passiert in Broker 0.4.0).
- `## Group`, `## IconTexture` und `Settings.RegisterCanvasLayoutSubcategory` funktionieren im Forever-Client.
- **Datei in der TOC, die fehlt:** Das Spiel lädt das Addon, meldet aber `LUA_WARNING: <Addon>.toc:<Zeile> Error loading <Datei>` (Peon_Client 0.1.0). Deshalb liegt für vom Programm erzeugte Dateien ein leerer Platzhalter im Ordner.
- **Sonderzeichen wie ● kennt die Spielschrift nicht** (erscheinen als Viereck). Symbole als eigene TGA-Datei (32×32, Alphakanal) und per `|T…|t` einbinden – wie die Trend-Symbole von Broker.
- **Charaktere haben Vor- und Nachnamen.** `UnitName("player")` liefert als zweiten Wert den Nachnamen (z. B. „Mirel“, „Dorna“), nicht den Realm. `GetRealmName()` liefert den Regelsatz („Classic Beta PvE“).
- **Auktionshaus:** modern wie in Retail (`C_AuctionHouse`, `AuctionHouseFrame`), keine alten Classic-Funktionen. Ein Markt je Regelsatz und Fraktion. Komplettscan (`ReplicateItems`) liefert rund 70.000 Angebote in etwa 10 Sekunden (Beta, 29.09.2026). Einzelheiten in `Peon_Stand.md` unter Peon_Broker.
- **Such-Ergebnisse kommen in Teilen** (wie in Retail): `C_AuctionHouse.HasFullCommoditySearchResults(itemID)` / `HasFullItemSearchResults(itemKey)` sagen, ob alles da ist; Blizzards Liste lädt mit `RequestMore…SearchResults` nach. Wer nur den ersten Teil liest, bekommt die günstigsten Angebote richtig, aber Median und Menge zu niedrig (Broker bis 0.19). Bei Einzelgegenständen kann das erste Ergebnis-Ereignis sogar leer und unvollständig sein (lädt noch) – dann auf weitere Ereignisse (`…_SEARCH_RESULTS_ADDED`/`…_UPDATED`) warten, nicht als „keine Angebote“ werten (Broker 0.20.1).
- **Blizzard-Kaufansicht öffnen:** `AuctionHouseFrame:SelectBrowseResult({ itemKey, … })` tut nichts, solange `C_AuctionHouse.GetItemKeyInfo(itemKey)` nil liefert (Daten nicht geladen) – dann auf `ITEM_KEY_ITEM_INFO_RECEIVED` warten. Ansicht umschalten mit `AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy / .Auctions / .ItemSell …)`, das stellt auch Blizzards Reiter um. Jede eigene Suche (`SendSearchQuery`) ersetzt die Ergebnisse, die Blizzards Fenster gerade zeigt. Hat das Spiel für einen Gegenstand schon Ergebnisse, schickt es eine neue Suche oft nicht ab; `C_AuctionHouse.RefreshItemSearchResults(itemKey)` / `RefreshCommoditySearchResults(itemID)` laden wie Blizzards Knopf „Neu laden“ (Broker 0.20.2). Selbst wenn die Ergebnisse für den Gegenstand ankommen, frischt Blizzards Kaufliste nach `SelectBrowseResult` nicht immer auf; Broker leert sie deshalb danach einmal (`ItemBuyFrame/CommoditiesBuyFrame.ItemList:Reset()`) und lädt neu (Broker 0.21.1).
- **Verkaufs-Suche** (`C_AuctionHouse.SendSellSearchQuery`): laut Wiki nur für Ausrüstungsvarianten, Schlüssel mit Stufe 0. In Forever lieferte sie für Broker nichts (Massenware nicht abgeschickt, Ausrüstung ohne lesbare Einträge); `MakeItemKey(itemID)` füllt in Forever die Stufe selbst aus. Broker nutzt ab 0.9.3 die normale Suche `SendSearchQuery(itemKey aus GetItemKeyFromItem, sorts, true)` – im Spiel bestätigt, Antwort nach etwa 0,3 Sek. über `COMMODITY_SEARCH_RESULTS_UPDATED(itemID)` bzw. `ITEM_SEARCH_RESULTS_UPDATED(itemKey)`.
- **Verkaufsfenster des Auktionshauses** (Blizzard_AuctionHouseSellFrame.lua): `AuctionHouseFrame:SetPostItem(itemLocation)`; `AuctionHouseFrame.CommoditiesSellFrame` / `.ItemSellFrame` mit `PriceInput:SetAmount/GetAmount`, `QuantityInput:SetQuantity/GetQuantity`, `Duration:SetDuration(index)`, `:GetDuration()`, `PostButton`. Im Spiel bestätigt (Broker 0.10–0.12). Blizzards `PostButton` wird bei zu schnellem Einstellen gesperrt (Tooltip „Ihr macht das zu schnell“); ein Klick darauf bewirkt dann nichts. Solange ein Gegenstand im Verkaufsfenster liegt, ist sein Taschenplatz gesperrt (`isLocked`) – wer gesperrte Plätze überspringt, „verliert“ ihn (Broker bis 0.21.1). Nie einen Gegenstand ins Verkaufsfenster legen, dessen Taschenplatz gesperrt ist (gerade eingestellt) – sonst Lua-Fehler in `ItemSellFrame:UpdateNoneAvailableEntry`.
- **Gegenstände mit Zusatz** („… des Wolfs“): Forever-Links haben den Zusatz nicht im Link-Feld 7, sondern als Bonus-Nummer (z. B. `item:6611::::::::20:1488:::1:12731:…`); im Suchschlüssel des Auktionshauses steht er als `itemSuffix` (14299–14340, andere Nummern). Scan-Name (`GetReplicateItemInfo`), Taschen (`itemName`) und Link-Text enthalten den vollen Namen mit Zusatz, `C_Item.GetItemInfo(itemID)` den Grundnamen. Die Suche mit `MakeItemKey(itemID)` liefert für sie vollständig 0 Angebote; die Browse-Suche (`SendBrowseQuery` mit dem Grundnamen) liefert je Variante einen Schlüssel. Broker trennt Varianten ab 0.28 nach vollem Namen und lernt die Schlüssel je Variante.
- **Massenware kaufen:** `StartCommoditiesPurchase(itemID, Menge)` → `COMMODITY_PRICE_UPDATED(Stückpreis, Gesamt)` → `ConfirmCommoditiesPurchase(itemID, Menge)` (per Klick). `StartCommoditiesPurchase` und `PlaceBid` gehen nur direkt aus einem Klick (`HasRestrictions` in Blizzards Doku), sonst `ADDON_ACTION_BLOCKED`, das `pcall` nicht abfängt. Einen Preis vorab holen geht deshalb nicht (Broker 0.33.1). `ConfirmCommoditiesPurchase` ist laut Doku nicht eingeschränkt.
- **Links mit neuem Farbformat:** Gegenstandslinks beginnen in Forever mit `|cnIQ<Qualität>:` statt `|cffxxxxxx` (Prüfung Ledger 02.10.2026) – Qualität deshalb aus `C_Item.GetItemInfo` bzw. `GetContainerItemInfo().quality` nehmen, nicht aus der Linkfarbe.
- **Accountbank / Gildenbank (Recherche 06.10.2026):** Eine Accountbank (Kriegsmeutenbank) gibt es in Forever vermutlich nicht – Reiter und Taschen-Nummern kommen aus der Retail-Oberfläche, die Taschen haben keine Plätze. Die Gildenbank gibt es (Beta, 100 Gold zum Freischalten); Ledger erfasst sie noch nicht.
- **Eigene Taschenfenster (Peon_Bags):** Plätze als `ContainerFrameItemButtonTemplate` in einem Rahmen je Tasche (Rahmen-ID = Tasche, Knopf-ID = Platz, `SetBagID`); deren Skripte `OnEvent`/`OnShow` abschalten. Blizzards Taschenfenster in einen versteckten Rahmen umhängen; Bank- und Gildenbank-Fenster dagegen in einen winzigen sichtbaren Rahmen (Verstecken würde `OnHide` auslösen und die Bank schließen). Öffnen über `hooksecurefunc` auf `ToggleAllBags`/`ToggleBackpack`/`ToggleBag`, interne Weiterleitungen über `debugstack` erkennen.
- **Taschen/Bank:** 6 Taschen (0–5, Tasche 5 vermutlich Reagenzientasche). `BANK_CONTAINER`, `NUM_BANKBAGSLOTS`, `GetNumBankSlots` gibt es nicht – Bank über `Enum.BagIndex`/`C_Bank`.
- **Post-Rechnungen:** `GetInboxInvoiceInfo(i)` = Art („buyer“/„seller“), Name, Spieler, Gebot, Sofortkauf, Einzahlung, Anteil, …, Menge. Verkaufsbrief: Gold = Sofortkauf − Anteil + Einzahlung.
- **Berufe nur modern:** `C_TradeSkillUI.GetAllRecipeIDs/GetRecipeInfo/GetRecipeSchematic/CraftRecipe`; alte `GetTradeSkill*`/`GetCraft*` fehlen. Händlerwaren über `C_MerchantFrame` (`GetMerchantItemInfo` fehlt).
- **Fenster auf/zu:** zuverlässig über `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` (Typ: 3 Flugmeister, 5 Händler, 17 Post …); `MAIL_CLOSED` kam nicht.
- **Forever hat keine Realms:** Je Region gibt es ein Auktionshaus je Regelsatz und Fraktion, dazu neutrale Häuser (laut API „Auktionshaus der Schwarzmeerräuber“, wenige Angebote). `GetRealmName()` liefert trotzdem einen internen Namen wie „CAMWOW EU4 Realm 3 PvE“. Er gehört zum Schlüssel von Broker, angezeigt wird im Manager nur „PvE Allianz“.
- **Genaue Werte eines Gegenstands mit Zusatz** nennt nur das Spiel, die Blizzard-API nicht. `C_TooltipInfo.GetHyperlink("item:3192::::::::20:1488:::1:12723")` geht auch ohne echten Gegenstand (Feld 13 Anzahl der Boni, dahinter die Nummern), vorher `C_Item.RequestLoadItemDataByID` und kurz warten (im Spiel bestätigt 06.11.2026).
- **Bank-Menge ohne offene Bank:** `C_Item.GetItemCount(itemID, true, false, true)` (mit Bank und Materiallager) minus `C_Item.GetItemCount(itemID)` – so zählt auch BagBrother für den eingeloggten Charakter. Andere Charaktere kennt das Spiel nicht. Höchstens 100 Abfragen pro Minute; nicht per `/run` aufrufbar. Bei Einzelgegenständen ist `buyoutAmount` schon der Preis je Stück, `quantity` die Anzahl gleicher Angebote.

- **Verankerte Menüs:** `MenuUtil.CreateContextMenu` öffnet immer am Mauszeiger. Für eine feste Stelle: `MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())`, `Menu.PopulateDescription(generator, owner, desc)`, `Menu.GetManager():OpenMenu(owner, desc, AnchorUtil.CreateAnchor(...))`. Nachgelesen in `Blizzard_Menu`, im Spiel mit Peon_Panel 0.1.0 noch zu bestätigen. Blizzard klappt das Menü bei Platzmangel um und hält es im Bild.

- **Blizzard-Code der Forever-Version** liegt öffentlich auf GitHub: `Gethe/wow-ui-source`, Zweig **`forever`** (Stand 1.60.1.70245). Damit lassen sich Abläufe nachlesen statt raten (z. B. `TooltipComparisonManager.lua`, `ContainerFrame.lua`, `SharedUIPanelTemplates.xml`). Mainline-Dateien (`…/Mainline/…`) sind die, die Forever nutzt.
- **`%d` in `string.format` nur bis 2^31** (2.147.483.647, also etwa 214.748 Gold in Kupfer): darüber bricht Forever-Lua mit „integer overflow attempting to store …“ ab. Angebote zum Höchstpreis (fast 5 Mio. Gold) kommen im Auktionshaus vor, Auktionsnummern können ebenfalls groß werden. Geldbeträge und Nummern immer mit `%.0f` oder `tostring` schreiben (Broker 0.30.2). Die Tests bauen die Grenze nach (`test_client.lua`).
- **Nie `pcall` (oder `xpcall`) um eine Funktion mit sehr vielen Rückgabewerten** (z. B. `{ pcall(UIParent.GetChildren, UIParent) }`): Forever-Lua stürzt dann mit „Assertion failure! L->top < L->ci->top (lapi.c)“ ab (Broker 0.28.0, Berufsfenster). Direkt aufrufen: `{ frame:GetChildren() }`.
- **Vergleichs-Tooltips:** Blizzard baut Gegenstands- und Vergleichs-Tooltip alle 0,2 Sek. neu auf und hängt die Vergleichszeilen („Wenn Ihr diesen Gegenstand ersetzt …“) nach allen Nachläufen an, dann `SetShown(true)`. Wer Zeilen umsortiert, muss das im selben Bild tun (`hooksecurefunc(tt, "Show"/"SetShown")`), sonst flackert es.
- **Breite Vergleichs-Tooltips schieben den Gegenstands-Tooltip:** Passt der Vergleich nicht neben den Tooltip, verschiebt Blizzard den Gegenstands-Tooltip (`AnchorShoppingTooltips`). Im Auktionshaus (Neuaufbau alle 0,2 Sek. mit `GameTooltip_Hide`) sieht das wie Flackern aus. Umgeschriebene Zeilen verlieren Blizzards Umbruch; Peon_Tooltip bricht deshalb ab 0.7.1 selbst um (Tooltip 0.7.1).
- **Fenster im Blizzard-Stil:** Taschen `PortraitFrameFlatTemplate` (+ `SetBorder("HeldBagLayout")` für den kleinen Ring, ohne ihn bleibt der große, `SetPortraitToAsset`, `SetPortraitTextureSizeAndOffset(36, -4, 1)`, `SetTitleOffsets(35)`, `PortraitContainer.CircleMask` genau auf das Bild legen wie Blizzards `Camelot\ContainerFrame.lua`), Bank `PortraitFrameTemplate` (`SetPortraitToUnit("npc")`), Broker/Ledger `ButtonFrameTemplate`, Gildenbank `BasicFrameTemplate`; Reiter oben `PanelTopTabButtonTemplate`, unten `PanelTabButtonTemplate`.

## Start einer neuen Sitzung

1. `CLAUDE.md`, `docs\projekt\Peon_Ueberblick.md`, `Peon_Stand.md` und `Peon_Entscheidungen.md` lesen.
2. Prüfen, ob die Versionen in den TOC-Dateien unter `addons\` zu `Peon_Stand.md` passen (KarloDerBaer kann zwischendurch selbst geändert haben). `git status` zeigt Änderungen seit dem letzten Commit.
3. Tests: `tests\run_tests.cmd` (Windows) oder `sh tests/run_tests.sh` (Git Bash). Alle müssen „OK“ melden, bevor etwas geändert wird. Beide laufen auf `addons\` im Repo (anderer Ordner: `PEON_ADDONS`), test_fish nimmt die feste Kopie `tests\fixtures\wtf`.
4. Neues Modul: von `vorlage\` ausgehen (siehe `vorlage\README.md`).

## Arbeitsweise, die sich bewährt hat

- **Testen:** lua5.1 mit einem kleinen WoW-Stub (nachgebaute API), bei Datenänderungen mit einer Kopie der echten SavedVariables. Lua liegt in `tools\`.
- **Neue Dateien oder ein neuer Addon-Ordner:** `/reload` reicht, ein Neustart von WoW ist nicht nötig (KarloDerBaer, 07.11.2026, zuletzt mit dem neuen Addon Peon_Panel).
- **Umbenennen eines Addons:** Die Datei in WTF auf den neuen Ordnernamen kopieren (Account und alle Charaktere). Neue Variablennamen über `oldDB` / `oldCharDB` übernehmen; der alte Name steht dafür eine Version lang zusätzlich in der TOC (`## SavedVariables: NeuDB, AltDB`) und entfällt danach wieder.
- **Tastenbelegungen umbenennen:** Die alten Namen eine Version lang versteckt (`hidden="true"`) in Bindings.xml behalten und beim Login per `GetBindingKey(alt)` → `SetBinding(taste, neu)` → `SaveBindings(GetCurrentBindingSet())` umlegen (nicht im Kampf). Erfahrung: Tastatur-Tasten zogen so um, Gamepad-Tasten (PAD1, PAD4) nicht; die wurden bei beendetem WoW direkt in `WTF\Account\<Konto>\bindings-cache.wtf` umbenannt. Danach die versteckten Einträge wieder entfernen. Belegungen von Peon_Fishing: `PEON_FISHING_TOGGLE`, `PEON_FISHING_ACTION`, `CLICK PeonFishingWeaponButton:LeftButton`.
- **Beta beendet (25.10.2026):** KarloDerBaer fand die gesperrten Broker-Dateien im Beta-Ordner als schreibgeschützt markiert. Ob das von Battle.net nach dem Ende der Beta kommt, ist offen. Gearbeitet wird nur noch in `_forever_`.
- **Windows kann Schreiben im AddOns-Ordner verweigern** („Permission denied“ bzw. „Windows denied access“, 23.10.2026 bei 7 Broker-Dateien, die übrigen gingen): Dateien vermutlich geöffnet oder Ordnerschutz (Windows-Sicherheit, überwachter Ordnerzugriff). Nach jedem Übertragen die Prüfsummen kontrollieren, nie davon ausgehen, dass alles geschrieben wurde.
- Fehler, die ein Modul mit `mod:Call` abfängt, landen nur im Chat und nicht im BugGrabber. Broker merkt Scan-Fehler in `PeonBrokerDB.lastScanError`, Peon_Bridge in `PeonBridgeDB.errors` (bis 0.3.0 Peon_Client in `PeonClientDB.errors`).
- Debug-Logs landen in den SavedVariables und können direkt aus WTF gelesen werden (z. B. `Peon_Fishing.lua` → `PeonFishingDB.debugLog`).
- Vor größeren Änderungen die Entscheidungen mit KarloDerBaer abstimmen; Texte deutsch und ohne Fachjargon.
- **Release-Pakete bauen:** `node scripts/build_release.js` (Zips, Manifest, Text), Einstellungen in `scripts
elease.json`. Ein neues Addon muss dort eingetragen werden, sonst bricht der Bau ab. Jede Version in einer TOC braucht einen Abschnitt `## <Version>` im Changelog.
- **Manager oder Entwicklung (auch bei laufendem WoW, danach `/reload`):** `scripts\junctions.cmd` zeigt den Zustand. `junctions.cmd manager [Module]` macht aus Junctions echte Ordner, der Peon Manager aktualisiert sie dann wie bei allen anderen. `junctions.cmd entwicklung [Module]` macht aus echten Ordnern Junctions, Änderungen im Repo sind dann nach `/reload` im Spiel, der Manager lässt diese Addons in Ruhe. Der echte Ordner wandert dabei ins Archiv.
- **Release in zwei Schritten:** Erst ein Tag `vJJJJ.MM.TT-test` (Vorabversion, nur Kanal Test). KarloDerBaer aktualisiert im Manager und prüft. Danach derselbe Stand als `vJJJJ.MM.TT`. Vorabversionen sind öffentlich sichtbar, das Repo ist öffentlich. Veröffentlicht wird nur nach Rücksprache.
- **Nach jeder Arbeit:** Version in der TOC erhöhen, `docs\changelog\<Modul>.md`, `Peon_Stand.md` und bei Bedarf `Peon_Entscheidungen.md` aktualisieren, Tests, Commit.

## Früher: Übertragen aus der Cloud (bis 31.10.2026)

Bis zum Umzug ins Git-Repo hat Claude in der Cloud gearbeitet und Lieferungen auf den PC übertragen. Diese Regeln gelten nur noch zum Verständnis des Archivs (`<Archiv>\eingang\`).

- **Testen vor dem Übertragen:** lua5.1 mit einem kleinen WoW-Stub (nachgebaute API), zuerst an der Arbeitskopie in der Cloud; bei Datenänderungen mit einer Kopie der echten SavedVariables. Nach dem Übertragen die Tests zusätzlich lokal auf den echten Dateien laufen lassen (`run_tests.sh`, Lua liegt in `tools\`).
- **Nach jedem Übertragen die Prüfsumme auf dem PC kontrollieren.** Einmal meldete die Übertragung „geschrieben“, obwohl die alte Datei blieb. Jede Lieferung in einem neuen Staging-Ordner.
- **Entpacken in freigegebene Ordner:** `tar` überschreibt vorhandene Dateien nur mit `--overwrite` (sonst müsste es löschen, und Löschen ist ohne Freigabe gesperrt). Programmordner des Peon Client nicht überschreiben, sondern neu entpacken und tauschen (`mv`).
- **Neue Programmversion klein übertragen:** Ändert sich nur der Programmcode, unterscheiden sich nur `resources\app.asar` und wenige Bytes der exe (Prüfsumme der asar). Dann reicht ein Paket mit app.asar und einer Liste der geänderten Bytes; auf dem PC `Runtime` nach `_neu` kopieren, beides einspielen, Prüfsummen aller Dateien mit dem Bau vergleichen, tauschen (Programm 0.3.0). Eine Datei gleichen Namens erneut zu übertragen kann die alte liefern: neuen Namen nehmen und die Prüfsumme kontrollieren.
- **Dateien über 20 MB** lehnt die Übertragung ab (28 MB scheiterte, 20 MB ging): große Pakete in Stücke zu 15 MB teilen, auf dem PC mit `cat` zusammensetzen und Prüfsummen von Stücken, Ganzem und jeder Datei kontrollieren (Peon Client 0.1.0).
- **Übertragen größerer Lieferungen:** Paket (`.tgz` mit `PRUEFSUMMEN.md5`) nach `eingang\` legen, auf dem PC in einen Zwischenordner entpacken, Prüfsummen prüfen, dann übernehmen und erneut prüfen; vorher kontrollieren, dass die zu ersetzenden Dateien noch dem Ausgangsstand entsprechen. Dateien vom PC in die Cloud holen: `device_stage_files`.
