# Peon: UI-Design für alle Fenster

Stand: 11.11.2026, **von KarloDerBaer freigegeben** (nach drei Tests im Spiel). Grundlage für alle Fenster aller Peon-Addons, zuerst für den Umbau von Peon_Broker. Bestehende Fenster bleiben vorerst, wie sie sind.

Beispielfenster im Spiel: `/peon ui` (Peon 0.18.0, Bausteine in `addons\Peon\UIKit.lua`, Beispielseiten in `UIDemo.lua`). Die Bausteine sind seit Kern-API 18 als `Peon.UI` für alle Module da (intern `ns.UI`). Wie die ganze Kern-API wird `Peon.UI` nur erweitert, nie geändert.

## 1. Ziel und Vorbild

Ein einheitlicher Look nach Blizzards modernem Auktionshaus in WoW Forever: Metallrahmen mit rundem Bild oben links, dunkle Bereiche mit feinem Rahmen, goldene Beschriftungen, weiße Werte, Reiter unten.

Abgestimmt mit KarloDerBaer (11.11.2026):

1. Fenster mit rundem Bild oben links, darin das Symbol des Moduls.
2. Hintergründe gemischt wie im Auktionshaus: links hellere Bereiche für Einstellungen und Formulare, rechts dunklere für Listen.
3. Haken mit gelbem Häkchen wie „Sofortkaufmodus“.
4. Hervorgehobener Knopf: Blizzards Gold-Knopf.
5. Feste Fenstergröße wie bei Blizzard. Stelle und Größe regelt Peon_Mover.
6. Zahl am Reiter: eigene kleine, runde Grafik aus Blizzards Kreismaske.
7. Vier Beispielseiten: Grundlagen, Bedienelemente, Listen, Aufbau.
8. Zusätzliche Bausteine: Gegenstand mit Qualitätsrahmen, Geldanzeige, Rückfrage, Kontextmenü, Fortschrittsbalken, Trennlinie, einklappbare Überschrift.
9. Schieberegler modern (schlank mit Pfeilen, wie Blizzards Einstellungen), nicht klassisch.
10. Fortschrittsbalken wie Blizzards Balken beim Herstellen.
11. Kategorien klappen auf und zu wie im Auktionshaus.

Nach dem zweiten Test (11.11.2026) passen laut KarloDerBaer Grundlagen, Bedienelemente, Listen, Reiter, Zahl am Reiter und Rückfrage.

## 2. Woher die Werte kommen

**Nie raten.** Alle Werte hier sind im Spiel gemessen (`/peon ui pruefen`, 11.11.2026, Client 1.60.1.70888) und mit Blizzards Code im Zweig `forever` von `Gethe/wow-ui-source` abgeglichen.

- Forever heißt in Blizzards Code „camelot“. Es lädt die Mainline-Fassung und ersetzt einzelne Teile. Unter denselben Atlas-Namen wie in Retail liegen teils eigene Grafiken. Beispiele aus der Messung: Metallrahmen der Fenster (Dateien 8069114 bis 8069118), Reiter (8168849), Schließen-Knopf (8107305), Bildlaufleiste (8069100 bis 8069104), Auswahlliste (8069110).
- Die Hintergründe des Auktionshauses kommen aus Blizzards gewohnter Datei (3054898), die Zeilen, Kategorien und Eingabefelder aus 3046538.
- Blizzard zeigt die Hintergründe in Originalgröße, nur oben links verankert (Versatz 3,-3, bei Listen 3,-22). Seine Bereiche sind etwa so groß wie die Bilder.
- **Peon passt den Hintergrund dem Bereich an** (nach dem ersten Test von KarloDerBaer): Ist der Bereich kleiner als das Bild, wird das Bild abgeschnitten, sonst ragt es über den Rand hinaus. Ist der Bereich größer, wird es gedehnt, sonst endet das Grau mitten im Bereich. Innen bleiben 3 Punkte Rand, bei Listen oben 22 für den Kopf und rechts 25 für die Leiste, bei Kategorien rechts 27. **Hinter jeder Bildlaufleiste liegt kein Hintergrundbild**, dort scheint wie bei Blizzard das hellere Grau des Fensters durch (gemessen an der Kategorieliste: Bild 138 breit im 168 breiten Bereich). Broker 0.56 bis 0.58 hatte das Bild ohne Rücksicht auf den Ausschnitt auf den ganzen Rahmen gezogen.
- Die Ordner `…/Classic/…` (Marmor, Pergament) gelten nicht für Forever.

Neue Grafiken immer erst mit `/peon ui pruefen` (oder `maus`, `<Pfad>`) im Spiel prüfen, dann verwenden.

## 3. Maße

| Was | Wert | Vorbild |
|---|---|---|
| Fenster | 800 × 538 | Auktionshaus |
| Titelleiste | 21 hoch, Titel mittig, `GameFontNormal` | `PortraitFrameTemplate` |
| Schließen | 28 × 28 oben rechts (0, 3) | Camelot `UIPanelCloseButtonDefaultAnchors` |
| Suchleiste | 618 × 40, oben rechts (-12, -29) | Auktionshaus |
| Bereiche oben | 69 unter der Oberkante | Verkaufsfenster |
| Bereiche unten | 29 über der Unterkante (Platz für die Statuszeile) | Geldanzeige |
| Abstand zum Rand | links 4, rechts 5 | Auktionshaus |
| Abstand zwischen Bereichen | 1 (Formular und Liste), 4 (Kategorien und Liste) | Verkaufen, Kaufen |
| Linker Bereich | 363 breit | Verkaufsfenster |
| Kategorieliste | 168 breit, Knöpfe 21 hoch | Kaufen |
| Liste | Kopf 19 hoch, Zeilen 20 hoch, Leiste rechts außerhalb des Rahmens | Auktionen |
| Formular | Beschriftung 93 breit rechtsbündig, 18 Abstand zum Feld, Zeilen 27 bis 45 auseinander | Verkaufsfenster |
| Eingabefeld | 33 hoch | `LargeInputBoxTemplate` |
| Knopf | 22 hoch, Gold-Knopf 32 hoch | `UIPanelButtonTemplate`, `UIPanelGoldButtonTemplate` |
| Reiter unten | erster bei (20, -28) unter dem Fenster, dann je 3 Abstand, Breite Text + 40, mit Zahl am Reiter breiter | Auktionshaus |
| Zahl am Reiter | rund, mindestens 16 hoch, rechts neben dem Text im Reiter | eigene Grafik mit Kreismaske |
| Sortierpfeil | zeigt bei aufsteigender Sortierung nach oben | `auctionhouse-ui-sortarrow` |
| Kategorieliste innen | 3 vom linken Rand | `SetPadding` wie Blizzard |
| Beschriftung über einem Bereich | 23 hoch, 42 vom linken Rand | „Auktion erstellen“ |
| Statuszeile | 24 hoch, unten von 3 bis 27 | Geldanzeige |

## 4. Schriften

Alle Schriften sind FRIZQT (Text) oder ARIALN (Zahlen), mit Schatten 1,-1.

| Rolle | Schrift-Objekt | Größe, Farbe |
|---|---|---|
| Fenstertitel, Beschriftung, Knopf | `GameFontNormal` | 12, gold (1, 0.82, 0) |
| Große Überschrift | `GameFontNormalLarge` | 16, gold |
| Überschrift eines Bereichs | `GameFontNormalMed2` | 14, gold |
| Normaler Text | `GameFontHighlight` | 12, weiß |
| Kleiner Text, Spaltenkopf | `GameFontHighlightSmall` | 10, weiß |
| Reiter, Kategorie | `GameFontNormalSmall` | 10, gold |
| Zusatz unter Beschriftung | `GameFontNormalSmall` grau (0.5) | 10 |
| Hinweis im leeren Feld | `GameFontDisableSmall` | 10, grau (0.35) |
| Gesperrt | `GameFontDisable` | 12, grau (0.5) |
| Zahlen und Namen in Listen | `Number14FontWhite` | Arial 14, weiß |
| Geld | `PriceFont` | Arial 14 |
| Hinweis bei leerer Liste | `GameFontNormal` mittig | 12, gold |
| Warnung, Erfolg | `GameFontRed`, `GameFontGreen` | 12 |
| Ladeanzeige | `GameFontNormalHuge` | 20, gold |

## 5. Bausteine

| Baustein | Umsetzung (`Peon.UI`) | Blizzard-Vorlage oder Grafik |
|---|---|---|
| Fenster mit Bild, Titel, Schließen | `UI.Window(name, { title, icon })` | `PortraitFrameTemplate`, `SetPortraitToAsset` |
| Reiter unten mit Zahl | `UI.BottomTabs(win, defs, onSelect)`, `tab:SetBadge(n)` | `PanelTabButtonTemplate`, Kreismaske 130924 |
| Reiter oben | `UI.TopTabs(parent, defs, onSelect)` | `PanelTopTabButtonTemplate` |
| Beschriftung über einem Bereich | `UI.SectionTab(panel, text)` | `auctionhouse-selltab-*` |
| Bereich mit Rahmen und Hintergrund | `UI.Panel(parent, bg, header)` | Rahmen aus `InsetFrameTemplate`, Hintergrund `UI.BG` |
| Text | `UI.Text(parent, rolle, text, breite)` | Schriften aus Abschnitt 4 |
| Trennlinie | `UI.Divider(parent, breite)` | `Options_HorizontalDivider` |
| Knopf normal, hervorgehoben, gesperrt | `UI.Button(parent, text, breite, fn, "gold")`, `:Disable()` | `UIPanelButtonTemplate`, `UIPanelGoldButtonTemplate` |
| Symbolknopf, Neu laden | `UI.IconButton`, `UI.RefreshButton` | `SquareIconButtonTemplate`, `RefreshButtonTemplate` |
| Eingabe Text und Zahl | `UI.Input(parent, breite, { numeric, instructions })` | `LargeInputBoxTemplate` |
| Geld eingeben | `UI.MoneyInput(parent, fn)`, `:SetAmount`, `:GetAmount` | drei Felder wie im Verkaufsfenster, `Coin-Gold/Silver/Copper` |
| Geld anzeigen | `UI.Money(parent)`, `:SetAmount(kupfer, grau)` | `PriceFont`, Münzen 12 × 14 |
| Suchleiste | `UI.SearchBox(parent, breite, fn)` | `SearchBoxTemplate` |
| Auswahlliste, Filter | `UI.Dropdown`, `UI.FilterDropdown` | `WowStyle1DropdownTemplate`, `WowStyle1FilterDropdownTemplate` |
| Haken | `UI.Check(parent, text, an, fn, tooltip)` | `UICheckButtonTemplate`, Text `GameFontNormal` |
| Schieberegler | `UI.Slider(parent, breite, min, max, schritt, wert, fn)` | `MinimalSliderWithSteppersTemplate` (Wert rechts daneben). `"classic"` nur noch als Rückfall |
| Formularzeile | `UI.FormRow(parent, text, feld, x, y, zusatz)` | Verkaufsfenster |
| Liste mit Kopf, Sortierung, Streifen, Auswahl, Bildlauf | `UI.Table(panel, { columns, sortKey, icon, empty })` | `ColumnDisplayButtonShortTemplate`, `auctionhouse-rowstripe-1/2`, `-row-highlight`, `-row-select`, `-ui-sortarrow`, `WowScrollBoxList`, `MinimalScrollBar` |
| Leere Liste, Ladeanzeige | `t:SetData({})`, `t:SetLoading(true, text)` | goldener Hinweis wie „Tipp:“, `SpinnerTemplate` |
| Kategorieliste (3 Stufen, auf- und zuklappbar) | `UI.CategoryList(panel, nodes, fn)`, Schlüssel wie `"Handwerkswaren/Stoff"` oder `parent` | `auctionhouse-nav-button`, `-secondary`, `-tertiary-filterline` |
| Statuszeile | `UI.StatusBar(win)`, `:SetText`, `.money` | `InsetFrameTemplate` 24 hoch |
| Gegenstand klein | `UI.ItemIcon(parent, icon, qualität)` | `auctionhouse-itemicon-small-border` |
| Gegenstand groß | `UI.ItemHeader(parent, icon, name, qualität)` | `auctionhouse-itemheaderframe`, `-itemicon-empty`, `-itemicon-border-white` |
| Tooltip | `UI.SetTooltip(rahmen, zeilen)` | `GameTooltip`, erste Zeile gold |
| Kontextmenü | Blizzards `MenuUtil.CreateContextMenu` | neue Menü-API |
| Rückfrage | `UI.Confirm(text, ja, nein, fn)` | eigenes Fenster mit `DialogBorderDarkTemplate` |
| Fortschritt | `UI.Progress(parent, breite)`, `:Set(0..1, text)`, 208 × 11, Text darunter | wie Herstellen: `ui-castingbar-background`, `-filling-applyingcrafting`, `-full-applyingcrafting`, `-frame`, Funke `-pip` 8 × 20 |
| Einklappbare Überschrift | `UI.Collapse(parent, text, offen, fn)` | Plus und Minus aus `Interface\Buttons`, Vorschlag |

## 6. Verhalten

- **Fenster:** feste Größe, mit der Titelleiste verschiebbar, ESC schließt (Name in `UISpecialFrames`, wie alle Peon-Fenster bisher), im Kampf nicht öffnen.
- **Reiter:** der gewählte Reiter wird gemerkt. Zahl am Reiter ab 1, ab 100 „99+“, bei 0 ausgeblendet.
- **Kategorien:** Klick öffnet eine Kategorie mit ihren Unterpunkten und wählt sie, erneuter Klick klappt sie zu und wählt die Kategorie darüber. Andere Kategorien bleiben zu.
- **Listen:** Klick auf den Kopf sortiert, nochmal klicken dreht die Richtung. Leere Werte stehen immer unten. Pfeil nach oben heißt aufsteigend. Linksklick wählt eine Zeile, Rechtsklick öffnet das Kontextmenü, Maus darüber zeigt den Tooltip. Streifen abwechselnd. Zahlen rechtsbündig.
- **Leere Liste:** goldener Hinweis oben mittig, der sagt, was man tun kann. **Laden:** Ring mit „Suche...“ statt der Liste.
- **Formulare:** Beschriftung gold und rechtsbündig, Werte weiß. Gesperrtes grau.
- **Wichtigste Aktion** mit dem Gold-Knopf, höchstens einer je Bereich.
- Texte kurz, deutsch, ohne Fachjargon.

## 7. Blizzards Fenster anpassen (wie in Broker)

Peon darf Blizzards Fenster **sichtbar und von außen** ergänzen:

- eigene Rahmen und Texte, die über oder neben Blizzards Rahmen liegen
- Anker und Beschriftungen von Blizzards Rahmen ändern (zum Beispiel Reiter neu verankern, Text „Markt“ statt „Kaufen“)
- sichere Anhänge mit `hooksecurefunc` und `HookScript`

**Nicht ohne Abstimmung mit KarloDerBaer:** Werte oder Funktionen in Blizzards Tabellen schreiben (zum Beispiel Einträge in `AuctionHouseFrame.Tabs`, `StaticPopupDialogs`, Mixins überschreiben). Vorher prüfen, ob das Taint auslöst (Beispiel Broker 0.4.0: neu zugewiesene `StaticPopupDialogs`, ESC meldete danach `ADDON_ACTION_FORBIDDEN`). Ausnahme mit langer Erfahrung: eigene Fensternamen in `UISpecialFrames` für ESC.

## 8. Beispiele im Code

```lua
local UI = Peon.UI   -- Kern-API 18
local win = UI.Window("PeonBeispielFrame", { title = "Peon Beispiel", icon = "Interface\\Icons\\INV_Misc_Note_01" })

local left = UI.Panel(win, "left")
left:SetPoint("TOPLEFT", UI.EDGE, -UI.TOP)
left:SetPoint("BOTTOMLEFT", UI.EDGE, UI.BOTTOM)
left:SetWidth(UI.LEFT_W)
UI.SectionTab(left, "Einstellungen")
local qty = UI.Input(left, 134, { numeric = true })
UI.FormRow(left, "Anzahl", qty, 11, -20)

local right = UI.Panel(win, "list", true)
right:SetPoint("TOPLEFT", left, "TOPRIGHT", UI.GAP, 0)
right:SetPoint("BOTTOMRIGHT", -5, UI.BOTTOM)
local t = UI.Table(right, {
    columns = { { key = "name", title = "Name" }, { key = "count", title = "Anzahl", width = 90, align = "RIGHT" } },
    sortKey = "name", icon = true, empty = "Noch keine Einträge.",
})
t:SetData(items)

local status = UI.StatusBar(win)
status:SetText("Stand: heute, 14:32")
UI.BottomTabs(win, { { "a", "Übersicht" }, { "b", "Liste" } }, function(key) end):Select("a")
```

## 9. Noch offen

- Hellgrau hinter der Leiste der Kategorien im Spiel prüfen (dritter Test). Fortschrittsbalken passt (KarloDerBaer).
- **Zahl am Reiter:** Größe, Farbe und Stelle am Reiter.
- Erledigt: Bausteine als `Peon.UI` in der Kern-API 18, Doku im Überblick und in der Vorlage.
- Nächster Schritt: Umbau von Peon_Broker mit diesen Bausteinen. Bestehende Fenster der anderen Addons bleiben vorerst, wie sie sind.
