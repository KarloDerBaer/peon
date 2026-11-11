-- Peon - UIDemo.lua
-- Ab 0.18.0: Beispielfenster /peon ui. Zeigt alle Bausteine aus UIKit.lua auf vier Seiten mit Testdaten und in
-- verschiedenen Zustaenden, damit KarloDerBaer den Look im Spiel pruefen kann. Nur Anzeige, nichts wird gespeichert
-- ausser der zuletzt gewaehlten Seite (PeonDB.uiDemoTab). Texte nur deutsch, weil es eine Arbeitsprobe ist.

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local UI = ns.UI

local D = {}
ns.UIDemo = D

D.PAGES = {
    { "basics", "Grundlagen" },
    { "controls", "Bedienelemente" },
    { "lists", "Listen" },
    { "layout", "Aufbau" },
}

-- Testdaten: erfundene Gegenstaende mit Blizzards Symbolen
local ICONS = {
    "Interface\\Icons\\INV_Ore_Copper_01", "Interface\\Icons\\INV_Fabric_Linen_01", "Interface\\Icons\\INV_Misc_Flower_02",
    "Interface\\Icons\\INV_Sword_04", "Interface\\Icons\\INV_Potion_51", "Interface\\Icons\\INV_Misc_Gem_Emerald_01",
    "Interface\\Icons\\INV_Ingot_03", "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", "Interface\\Icons\\INV_Chest_Cloth_21",
    "Interface\\Icons\\INV_Misc_Bag_08",
}
local NAMES = {
    { "Kupfererz", 1, "Handwerkswaren", "Metall und Stein" }, { "Leinenstoff", 1, "Handwerkswaren", "Stoff" },
    { "Friedensblume", 1, "Handwerkswaren", "Kräuter" }, { "Klinge des Wächters", 3, "Waffen", "Einhandschwerter" },
    { "Kleiner Heiltrank", 1, "Verbrauchbares", "Tränke" }, { "Smaragd des Waldes", 3, "Handwerkswaren", "Juwelen" },
    { "Bronzebarren", 1, "Handwerkswaren", "Metall und Stein" }, { "Wolfsfell", 1, "Handwerkswaren", "Leder" },
    { "Robe des Lehrlings", 2, "Rüstung", "Stoff" }, { "Reisetasche", 2, "Behälter", "Taschen" },
}

function D.Items(n)
    local items = {}
    for i = 1, n or 40 do
        local base = NAMES[(i - 1) % #NAMES + 1]
        local round = math.floor((i - 1) / #NAMES)
        items[i] = {
            name = base[1] .. (round > 0 and (" " .. (round + 1)) or ""),
            quality = (round > 1 and base[2] < 4) and base[2] + 1 or base[2],
            icon = ICONS[(i - 1) % #ICONS + 1],
            cat = base[3], sub = base[4],
            level = 5 + (i * 7) % 55,
            count = (i * 37) % 400 + 1,
            price = (i * 7919) % 2500000 + 50,
            new = (i % 13 == 0) or nil,
        }
    end
    -- leere Werte stehen beim Sortieren immer unten
    items[5].level = nil
    return items
end

local function MoneyText(copper)
    if GetCoinTextureString then
        local ok, s = pcall(GetCoinTextureString, copper)
        if ok and s then return s end
    end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    return (g > 0 and ("%.0fg "):format(g) or "") .. (s > 0 and (s .. "s ") or "") .. c .. "c"
end
D.MoneyText = MoneyText

local function ItemTooltip(row, item)
    UI.Tooltip(row, {
        item.name,
        "Kategorie: " .. item.cat .. " > " .. item.sub,
        "Stufe: " .. (item.level and tostring(item.level) or "unbekannt"),
        "Verfügbar: " .. item.count,
        "Preis: " .. MoneyText(item.price),
    })
end

local function ContextMenu(owner, item)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(item and item.name or "Kontextmenü")
        root:CreateButton("Auf Einkaufsliste", function() Peon.Print("Beispiel: auf Einkaufsliste") end)
        root:CreateButton("Info", function() Peon.Print("Beispiel: Info") end)
        root:CreateDivider()
        root:CreateCheckbox("Beobachten", function() return D.watch end, function() D.watch = not D.watch end)
    end)
end

local function Place(region, parent, x, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return region
end

---------------------------------------------------------------------------
-- Seite 1: Grundlagen (Text, Hinweise, Gegenstand, Geld, weitere Bausteine)
---------------------------------------------------------------------------
local function BuildBasics(page)
    local left = UI.Panel(page, "left")
    left:SetPoint("TOPLEFT", UI.EDGE, -UI.TOP)
    left:SetPoint("BOTTOMLEFT", UI.EDGE, UI.BOTTOM)
    left:SetWidth(UI.LEFT_W)
    UI.SectionTab(left, "Text und Hinweise")

    local header = Place(UI.ItemHeader(left, ICONS[6], "Smaragd des Waldes", 3), left, 11, -12)
    UI.SetTooltip(header, { "Gegenstand mit Rahmen", "Großes Symbol mit Qualitätsrahmen und Name in Qualitätsfarbe, wie im Verkaufsfenster." })

    local y = -96
    local function Line(role, text, step)
        local fs = Place(UI.Text(left, role, text, 335), left, 14, y)
        y = y - (step or 18)
        return fs
    end
    Line("big", "Große Überschrift", 22)
    Line("heading", "Überschrift eines Bereichs", 20)
    Line("label", "Beschriftung in Gold", 18)
    Line("text", "Normaler Text in Weiß für Erklärungen. Er bricht um, wenn die Zeile zu lang wird.", 32)
    Line("small", "Kleiner Text für Nebensachen und Spaltenköpfe", 15)
    Line("sub", "Grauer Zusatz, zum Beispiel „pro Gegenstand“", 18)
    Line("number", "Zahlen und Namen in Listen: 1.234 Stück", 22)
    Line("warn", "Warnung: Der Preis liegt weit unter dem Markt.", 18)
    Line("good", "Erfolg: 12 Auktionen eingestellt.", 18)
    Line("off", "Gesperrt: gerade nicht verfügbar", 24)

    local ml = Place(UI.Text(left, "label", "Geld"), left, 14, y)
    local money = UI.Money(left)
    money:SetPoint("LEFT", ml, "RIGHT", 18, 0)
    money:SetAmount(12345678)
    local money2 = UI.Money(left)
    money2:SetPoint("LEFT", money, "RIGHT", 24, 0)
    money2:SetAmount(4205, true)
    y = y - 28

    Place(UI.Text(left, "label", "Gegenstände"), left, 14, y)
    for q = 0, 5 do
        local ic = UI.ItemIcon(left, ICONS[q + 1], q)
        ic:SetPoint("TOPLEFT", left, "TOPLEFT", 120 + q * 24, y + 1)
        UI.SetTooltip(ic, { "Qualität " .. q, "Kleines Symbol 14×14 mit Rahmen in der Qualitätsfarbe, wie in Blizzards Listen." })
    end

    -- rechts: weitere Bausteine
    local right = UI.Panel(page, "right")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", UI.GAP, 0)
    right:SetPoint("BOTTOMRIGHT", -5, UI.BOTTOM)
    UI.SectionTab(right, "Weitere Bausteine")

    y = -16
    local body = UI.Text(right, "text", "Dieser Text lässt sich mit der Überschrift darüber ein- und ausklappen.", 360)
    local col = Place(UI.Collapse(right, "Einklappbarer Abschnitt", true, function(open) body:SetShown(open) end), right, 16, y)
    body:SetPoint("TOPLEFT", col, "BOTTOMLEFT", 18, -4)
    y = y - 62

    Place(UI.Text(right, "heading", "Trennlinie"), right, 16, y)
    Place(UI.Divider(right, 380), right, 16, y - 22)
    y = y - 40

    -- Fortschritt wie Blizzards Balken beim Herstellen: laufend, voll, und auf Knopfdruck abspielen
    Place(UI.Text(right, "heading", "Fortschritt"), right, 16, y)
    local prog = Place(UI.Progress(right, 208), right, 18, y - 26)
    prog:Set(0.6, "Scan 60 %")
    local done = Place(UI.Progress(right, 150), right, 240, y - 26)
    done:Set(1, "Fertig")
    local play = UI.Button(right, "Abspielen", 90, function(self)
        local t0 = GetTime()
        self:SetScript("OnUpdate", function(b)
            local v = (GetTime() - t0) / 3
            prog:Set(v, ("Scan %d %%"):format(math.floor(math.min(1, v) * 100)))
            if v >= 1 then b:SetScript("OnUpdate", nil) end
        end)
    end)
    play:SetPoint("TOPLEFT", right, "TOPLEFT", 18, y - 56)
    y = y - 88

    Place(UI.Text(right, "heading", "Zahl am Reiter"), right, 16, y)
    local x = 16
    for _, n in ipairs({ 3, 12, 120 }) do
        local b = UI.Badge(right)
        b:SetPoint("TOPLEFT", right, "TOPLEFT", x, y - 24)
        b:SetCount(n)
        x = x + 40
    end
    local plus = UI.Button(right, "Reiter Listen +1", 130, function()
        D.badge = (D.badge or 0) + 1
        if D.tabs then D.tabs[3]:SetBadge(D.badge) end
    end)
    Place(plus, right, 150, y - 20)
    local zero = UI.Button(right, "Auf 0", 70, function()
        D.badge = 0
        if D.tabs then D.tabs[3]:SetBadge(0) end
    end)
    zero:SetPoint("LEFT", plus, "RIGHT", 6, 0)
    y = y - 60

    Place(UI.Text(right, "heading", "Tooltip, Kontextmenü, Rückfrage"), right, 16, y)
    local tipB = Place(UI.Button(right, "Maus darüber", 120), right, 16, y - 24)
    UI.SetTooltip(tipB, { "Tooltip", "Erste Zeile gold, weitere Zeilen weiß und mit Umbruch. Blizzards GameTooltip." })
    local menuB = UI.Button(right, "Rechtsklick", 120)
    menuB:SetPoint("LEFT", tipB, "RIGHT", 8, 0)
    menuB:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    menuB:SetScript("OnClick", function(self) ContextMenu(self, nil) end)
    local askB = UI.Button(right, "Rückfrage", 120, function()
        UI.Confirm("Wirklich alle 12 Auktionen abbrechen? Die Einstellgebühr ist dann verloren.", "Abbrechen", "Behalten",
            function() Peon.Print("Beispiel: bestätigt") end)
    end)
    askB:SetPoint("LEFT", menuB, "RIGHT", 8, 0)
end

---------------------------------------------------------------------------
-- Seite 2: Bedienelemente (Eingaben, Auswahl, Haken, Regler, Knoepfe, Suche, Reiter oben)
---------------------------------------------------------------------------
local function BuildControls(page)
    local left = UI.Panel(page, "left")
    left:SetPoint("TOPLEFT", UI.EDGE, -UI.TOP)
    left:SetPoint("BOTTOMLEFT", UI.EDGE, UI.BOTTOM)
    left:SetWidth(UI.LEFT_W)
    UI.SectionTab(left, "Eingaben")

    local name = UI.Input(left, 200, { instructions = "Name eingeben" })
    UI.FormRow(left, "Text", name, 11, -20)

    local qty = UI.Input(left, 134, { numeric = true })
    qty:SetText("20")
    UI.FormRow(left, "Anzahl", qty, 11, -62)
    local max = UI.Button(left, "Maximum", 75, function() qty:SetText("200") end)
    max:SetPoint("LEFT", qty, "RIGHT", 6, 2)

    local price = UI.MoneyInput(left)
    price:SetAmount(123456)
    UI.FormRow(left, "Kaufpreis", price, 11, -104, "pro Gegenstand")

    D.duration = D.duration or 2
    local dur = UI.Dropdown(left, 115, { { 1, "2 Stunden" }, { 2, "8 Stunden" }, { 3, "24 Stunden" } },
        function() return D.duration end, function(v) D.duration = v end)
    UI.FormRow(left, "Dauer", dur, 11, -144)

    local filter = UI.FilterDropdown(left, "Filter", function(root)
        root:CreateCheckbox("Nur lohnende", function() return D.f1 end, function() D.f1 = not D.f1 end)
        root:CreateCheckbox("Mit Twinks", function() return D.f2 end, function() D.f2 = not D.f2 end)
    end)
    UI.FormRow(left, "Filter", filter, 11, -176)

    -- Regler: modern wie Blizzards Einstellungen (abgestimmt mit KarloDerBaer, 11.11.2026)
    local slider = UI.Slider(left, 200, 0, 100, 5, 30, nil, "minimal", function(v) return v .. " %" end)
    UI.FormRow(left, "Regler", slider, 11, -210)

    local c1 = Place(UI.Check(left, "Haken an", true, nil, { "Haken", "Wie „Sofortkaufmodus“ im Verkaufsfenster." }), left, 8, -250)
    local c2 = Place(UI.Check(left, "Haken aus", false), left, 8, -282)
    local c3 = Place(UI.Check(left, "Haken gesperrt", true), left, 8, -314)
    c3:Disable()
    local c4 = Place(UI.Check(left, "Gesperrt und aus", false), left, 180, -314)
    c4:Disable()

    -- rechts: Knoepfe, Suche, Reiter oben
    local right = UI.Panel(page, "right")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", UI.GAP, 0)
    right:SetPoint("BOTTOMRIGHT", -5, UI.BOTTOM)
    UI.SectionTab(right, "Knöpfe und Suche")

    local y = -16
    Place(UI.Text(right, "heading", "Knöpfe"), right, 16, y)
    local b1 = Place(UI.Button(right, "Suchen", 132), right, 16, y - 26)
    UI.SetTooltip(b1, { "Normaler Knopf", "UIPanelButtonTemplate, 22 hoch, wie „Suchen“ im Auktionshaus." })
    local b2 = UI.Button(right, "Auktion erstellen", 194)
    b2:SetPoint("LEFT", b1, "RIGHT", 10, 0)
    b2:Disable()
    local g1 = Place(UI.Button(right, "Kaufen", 160, nil, "gold"), right, 16, y - 58)
    UI.SetTooltip(g1, { "Hervorgehobener Knopf", "UIPanelGoldButtonTemplate, 32 hoch, für die wichtigste Aktion." })
    local g2 = UI.Button(right, "Alles kaufen", 160, nil, "gold")
    g2:SetPoint("LEFT", g1, "RIGHT", 10, 0)
    g2:Disable()
    y = y - 106

    Place(UI.Text(right, "heading", "Symbolknöpfe"), right, 16, y)
    local fav = Place(UI.IconButton(right, "auctionhouse-icon-favorite", nil, { "Favoriten", "Quadratischer Knopf mit Symbol." }), right, 16, y - 22)
    local ref = UI.RefreshButton(right, nil, { "Neu laden" })
    ref:SetPoint("LEFT", fav, "RIGHT", 8, 0)
    local favOff = UI.IconButton(right, "auctionhouse-icon-favorite-off")
    favOff:SetPoint("LEFT", ref, "RIGHT", 8, 0)
    favOff:Disable()
    y = y - 66

    Place(UI.Text(right, "heading", "Suchleiste"), right, 16, y)
    local search = Place(UI.SearchBox(right, 241), right, 22, y - 28)
    local found = UI.Text(right, "small", "")
    found:SetPoint("LEFT", search, "RIGHT", 10, 0)
    search:HookScript("OnTextChanged", function(self) local t = self:GetText() or "" found:SetText(t ~= "" and ("Suche nach „" .. t .. "“") or "") end)
    y = y - 70

    Place(UI.Text(right, "heading", "Reiter oben"), right, 16, y)
    local box = UI.Panel(right, "summary")
    box:SetPoint("TOPLEFT", right, "TOPLEFT", 16, y - 56)
    box:SetSize(380, 60)
    local info = UI.Text(box, "text", "", 340)
    info:SetPoint("TOPLEFT", 12, -12)
    local top = UI.TopTabs(right, { { "a", "Auktionen" }, { "b", "Gebote" }, { "c", "Verlauf" } }, function(key)
        info:SetText("Gewählt: " .. ({ a = "Auktionen", b = "Gebote", c = "Verlauf" })[key])
    end)
    top[1]:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 40, -2)
    top:Select("a")
end

---------------------------------------------------------------------------
-- Seite 3: Listen (Kopfzeile, Sortierung, Streifen, Auswahl, Bildlauf, leer, Laden)
---------------------------------------------------------------------------
local function ListColumns()
    return {
        { key = "name", title = "Name", color = function(item) return UI.QualityColor(item.quality) end },
        { key = "level", title = "Stufe", width = 60, align = "RIGHT" },
        { key = "count", title = "Verfügbar", width = 90, align = "RIGHT" },
        { key = "price", title = "Preis", width = 150, align = "RIGHT", format = function(v) return MoneyText(v or 0) end },
    }
end

local function BuildLists(page)
    local panel = UI.Panel(page, "list", true)
    panel:SetPoint("TOPLEFT", UI.EDGE, -UI.TOP)
    panel:SetPoint("BOTTOMRIGHT", -5, UI.BOTTOM)
    local t = UI.Table(panel, {
        columns = ListColumns(), sortKey = "price", icon = true,
        empty = "Keine Einträge. Hier steht in Gold, was man tun kann, zum Beispiel: Starte einen Scan im Auktionshaus.",
        loadingText = "Suche...",
        onEnter = ItemTooltip,
        onClick = function(item, button)
            if button == "RightButton" then ContextMenu(UIParent, item) end
            if D.status then D.status:SetText("Gewählt: " .. item.name) end
        end,
    })
    D.listTable = t
    local items = D.Items(40)

    -- Zustaende oben in der Leiste (Platz der Suchleiste)
    local bar = CreateFrame("Frame", nil, page)
    bar:SetPoint("TOPRIGHT", -12, -29)
    bar:SetSize(618, 40)
    local b1 = UI.Button(bar, "Mit Daten", 110, function() t:SetLoading(false); t:SetData(items) end)
    b1:SetPoint("LEFT", 0, 0)
    local b2 = UI.Button(bar, "Leere Liste", 110, function() t:SetLoading(false); t:SetData({}) end)
    b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)
    local b3 = UI.Button(bar, "Laden", 110, function() t:SetData({}); t:SetLoading(true, "Suche...") end)
    b3:SetPoint("LEFT", b2, "RIGHT", 8, 0)
    local note = UI.Text(bar, "small", "Kopf anklicken: sortieren. Zeile: auswählen. Rechtsklick: Menü.", 260)
    note:SetPoint("LEFT", b3, "RIGHT", 12, 0)
    t:SetData(items)
end

---------------------------------------------------------------------------
-- Seite 4: Aufbau wie das Auktionshaus (Suchleiste, Kategorien, Ergebnisse, Statuszeile)
---------------------------------------------------------------------------
local CATS = {
    { key = "Waffen", text = "Waffen", level = 1 },
    { key = "Waffen/Einhandschwerter", text = "Einhandschwerter", level = 2 },
    { key = "Rüstung", text = "Rüstung", level = 1 },
    { key = "Rüstung/Stoff", text = "Stoff", level = 2 },
    { key = "Behälter", text = "Behälter", level = 1 },
    { key = "Verbrauchbares", text = "Verbrauchbare Gegenstände", level = 1 },
    { key = "Verbrauchbares/Tränke", text = "Tränke", level = 2 },
    { key = "Handwerkswaren", text = "Handwerkswaren", level = 1 },
    { key = "Handwerkswaren/Metall und Stein", text = "Metall und Stein", level = 2 },
    { key = "Handwerkswaren/Metall und Stein/Erz", text = "Erz", level = 3 },
    { key = "Handwerkswaren/Metall und Stein/Barren", text = "Barren", level = 3 },
    { key = "Handwerkswaren/Stoff", text = "Stoff", level = 2 },
    { key = "Handwerkswaren/Kräuter", text = "Kräuter", level = 2 },
    { key = "Handwerkswaren/Leder", text = "Leder", level = 2 },
    { key = "Handwerkswaren/Juwelen", text = "Juwelen", level = 2 },
    { key = "Verschiedenes", text = "Verschiedenes", level = 1 },
}

local function BuildLayout(page)
    local items = D.Items(60)
    local filterCat, filterText = nil, ""
    local results

    local function Run()
        local out = {}
        for _, item in ipairs(items) do
            local okCat = not filterCat or filterCat == item.cat or filterCat == (item.cat .. "/" .. item.sub)
                or filterCat:find("^" .. item.cat .. "/" .. item.sub .. "/") ~= nil
            local okText = filterText == "" or item.name:lower():find(filterText:lower(), 1, true) ~= nil
            if okCat and okText then out[#out + 1] = item end
        end
        results:SetData({})
        results:SetLoading(true, "Suche...")
        local function Done()
            results:SetLoading(false)
            results:SetData(out)
            if D.status then D.status:SetText(#out .. " Ergebnisse" .. (filterCat and (" in " .. filterCat) or "")) end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.6, Done) else Done() end
    end

    -- Suchleiste wie im Auktionshaus (rechts oben, 618 breit)
    local bar = CreateFrame("Frame", nil, page)
    bar:SetPoint("TOPRIGHT", -12, -29)
    bar:SetSize(618, 40)
    local fav = UI.IconButton(bar, "auctionhouse-icon-favorite", function() filterCat, filterText = nil, ""; Run() end, { "Favoriten", "Zeigt im Beispiel alles." })
    fav:SetPoint("LEFT", 0, 0)
    local search = UI.SearchBox(bar, 241)
    search:SetPoint("LEFT", fav, "RIGHT", 9, 0)
    search:SetScript("OnEnterPressed", function(self) filterText = self:GetText() or ""; self:ClearFocus(); Run() end)
    local go = UI.Button(bar, "Suchen", 132, function() filterText = search:GetText() or ""; Run() end)
    go:SetPoint("RIGHT", 0, 0)
    local filter = UI.FilterDropdown(bar, "Filter", function(root)
        root:CreateCheckbox("Nur verfügbare", function() return D.f3 end, function() D.f3 = not D.f3 end)
    end)
    filter:SetPoint("RIGHT", go, "LEFT", -10, 0)

    local cats = UI.Panel(page, "categories")
    cats:SetPoint("TOPLEFT", UI.EDGE, -UI.TOP)
    cats:SetPoint("BOTTOMLEFT", UI.EDGE, UI.BOTTOM)
    cats:SetWidth(UI.CAT_W)
    UI.CategoryList(cats, CATS, function(key) filterCat = key; Run() end)

    local list = UI.Panel(page, "list", true)
    list:SetPoint("TOPLEFT", cats, "TOPRIGHT", 4, 0)
    list:SetPoint("BOTTOMRIGHT", -5, UI.BOTTOM)
    results = UI.Table(list, {
        columns = ListColumns(), sortKey = "price", icon = true,
        empty = "Wähle links eine Kategorie oder suche nach einem Namen.",
        onEnter = ItemTooltip,
        onClick = function(item, button) if button == "RightButton" then ContextMenu(UIParent, item) end end,
    })
    results:SetData({})
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local BUILDERS = { basics = BuildBasics, controls = BuildControls, lists = BuildLists, layout = BuildLayout }

function D.Create()
    if D.win then return D.win end
    local win = UI.Window("PeonUIDemoFrame", { title = "Peon: Beispiele für das UI-Design", icon = "Interface\\Icons\\INV_Pick_02" })
    D.win = win
    D.pages = {}
    for _, p in ipairs(D.PAGES) do
        local page = CreateFrame("Frame", nil, win)
        page:SetAllPoints()
        page:Hide()
        D.pages[p[1]] = page
        local ok, err = pcall(BUILDERS[p[1]], page)
        if not ok then Peon.ReportCoreError("UIDemo " .. p[1], err) end
    end
    D.status = UI.StatusBar(win)
    D.status:SetText("Statuszeile: Stand der Daten, Hinweise, Geld rechts")
    D.status.money:SetAmount((GetMoney and GetMoney()) or 0)
    D.tabs = UI.BottomTabs(win, D.PAGES, function(key)
        for k, page in pairs(D.pages) do page:SetShown(k == key) end
        if type(Peon.db) == "table" then Peon.db.uiDemoTab = key end
    end)
    D.badge = 3
    D.tabs[3]:SetBadge(D.badge)
    local start = type(Peon.db) == "table" and Peon.db.uiDemoTab
    if not BUILDERS[start or ""] then start = "basics" end
    D.tabs:Select(start)
    return win
end

function D.Toggle()
    if Peon.InCombat() then Peon.Print("Im Kampf nicht verfügbar.") return end
    local win = D.Create()
    win:SetShown(not win:IsShown())
end
