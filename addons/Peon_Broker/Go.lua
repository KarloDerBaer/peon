-- Peon_Broker - Go.lua
-- Neuaufbau N1 (ab 0.59, Konzept Peon_Broker_Neuaufbau.md, Abschnitt 5): Spruenge zwischen den Seiten, ueberall gleich.
--   Go.Market(item)  "Im Markt zeigen": am Auktionator Suche in Blizzards Markt (ab 0.64.1 ohne Blizzards Funktionen).
--                    Unterwegs die Marktseite aus Scandaten, nach diesem Gegenstand gesucht.
--   Go.Item(item)    Seite Gegenstand mit diesem Gegenstand
--   Go.Focus(item)   Seite Fokus mit diesem Gegenstand
--   Go.Back()        ein Schritt zurueck zur Seite, von der der Sprung kam (Knopf in der Titelleiste)
-- item = { key oder id oder link, name, offer, qty, itemKey }
-- Broker schliesst vor dem Sprung in Blizzards Kaufansicht seine eigene Flaeche (bis 0.58 war der Sprung gesperrt,
-- solange Einkaufen oder Radar offen war).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local Go = {}
ns.Go = Go

Go.back = nil   -- Schluessel der Seite, zu der "Zurueck" fuehrt

local function KeyOf(item)
    if type(item) ~= "table" then return nil end
    if item.key ~= nil then return item.key end
    if item.link and ns.Data.KeyFromLink then
        local k = ns.Data.KeyFromLink(item.link)
        if k ~= nil then return k end
    end
    return item.id
end

-- Seite, die gerade zu sehen ist (Reiter im Auktionshaus oder im Broker-Fenster), sonst nil
function Go.Here()
    local W, T = ns.Window, ns.AHTabs
    if W.AtAH() then return T.current end
    if W.IsOpen() then return W.current end
    return nil
end

function Go.UpdateBack()
    local W, T = ns.Window, ns.AHTabs
    local text = Go.back and L.GO_BACK:format(W.TabLabel(Go.back)) or nil
    for _, b in ipairs({ W.back, T and T.back }) do
        if b then
            if text then b:SetText(text) end
            b:SetShown(text ~= nil)
        end
    end
    if T and T.PlaceBack then T.PlaceBack() end
end

function Go.SetBack(from)
    Go.back = from
    Go.UpdateBack()
end

function Go.Clear()
    Go.back = nil
    Go.UpdateBack()
end

-- Ein Reiter wurde gewaehlt: Der Sprung ist damit vorbei. Spruenge setzen "Zurueck" erst nach dem Wechsel.
function Go.OnTab()
    if Go.jumping then return end
    if Go.back then Go.Clear() end
end

function Go.Back()
    local key = Go.back
    Go.Clear()
    if key then ns.Window.Open(key) end
end

function Go.Item(item, from)
    if type(item) ~= "table" then return false end
    if from == nil then from = Go.Here() end
    Go.jumping = true   -- der Reiterwechsel gehoert zum Sprung: ein frueheres "Zurueck" bleibt
    local ok, err = pcall(ns.Menu.Info, item)
    Go.jumping = false
    if not ok then error(err, 0) end
    if from and from ~= "prices" then Go.SetBack(from) else Go.UpdateBack() end
    return true
end

-- "In den Fokus": Seite Fokus mit genau diesem Gegenstand (ersetzt den bisherigen)
function Go.Focus(item)
    local key = KeyOf(item)
    if key == nil then
        mod:Print(L.GO_NONE)
        return false
    end
    -- ab 0.70: der Fokus arbeitet nur am Auktionshaus. Unterwegs merkt Broker den Gegenstand fuer den naechsten Besuch.
    if not ns.Window.AtAH() then
        ns.Focus.Set(key)
        mod:Print(L.FOCUS_LATER:format(tostring(item.name or ns.Data.ItemName(key) or key)))
        return true
    end
    local from = Go.Here()
    Go.jumping = true
    local ok, err = pcall(function()
        ns.Window.Open("focus")
        ns.Focus.Set(key)
    end)
    Go.jumping = false
    if not ok then error(err, 0) end
    if from and from ~= "focus" then Go.SetBack(from) else Go.UpdateBack() end
    return true
end

-- Menue eines Gegenstands (wie Strg+Rechtsklick ueberall im Spiel): Rechtsklick in Brokers Listen
function Go.Menu(item, owner)
    local key = KeyOf(item)
    if key == nil or not Peon.OpenItemMenu then return false end
    local D = ns.Data
    return Peon.OpenItemMenu({ id = D.ItemID(key), link = item.link or D.LinkFromKey(key),
        name = item.name or D.ItemName(key, D.Lookup(key)) }, owner)
end

-- Klick auf eine Zeile in Brokers Listen, ueberall gleich (Konzept Abschnitt 5): Linksklick waehlt (onSelect),
-- Doppelklick zeigt im Markt, Rechtsklick oeffnet das Menue.
Go.DOUBLE = 0.4   -- Sekunden
function Go.Click(item, button, owner, onSelect)
    if button == "RightButton" then return Go.Menu(item, owner) end
    local key = KeyOf(item)
    local now = GetTime and GetTime() or 0
    if key ~= nil and Go.clickKey == key and now - (Go.clickT or 0) <= Go.DOUBLE then
        Go.clickKey = nil
        return Go.Market(item)
    end
    Go.clickKey, Go.clickT = key, now
    if onSelect then onSelect(item) end
    return true
end

function Go.Market(item)
    local key = KeyOf(item)
    if key == nil then
        mod:Print(L.GO_NONE)
        return false
    end
    local W, T = ns.Window, ns.AHTabs
    local from = Go.Here()
    if W.AtAH() then
        T.Close()
        ns.Buy.ShowInAH({ key = key, itemKey = item.itemKey, offer = item.offer or item.cheapest, qty = item.qty })
        if from then Go.SetBack(from) end
        return true
    end
    -- unterwegs: Marktseite aus Scandaten, nach genau diesem Gegenstand gesucht
    local name = item.name or ns.Data.ItemName(key, ns.Data.Lookup(key))
    Go.jumping = true
    local ok, err = pcall(function()
        W.Open("browse")
        ns.Market.Find(name)
    end)
    Go.jumping = false
    if not ok then error(err, 0) end
    if from and from ~= "browse" then Go.SetBack(from) else Go.UpdateBack() end
    return true
end

---------------------------------------------------------------------------
-- Ab 0.73 (KarloDerBaer, 12.11.2026): "Im Markt zeigen" mit sicherem Knopf.
-- Broker darf Blizzards Ansicht nicht selbst umschalten (Fehlerberichte 10 und 11, Broker 0.64.1). Ein sicherer
-- Knopf (SecureActionButtonTemplate, Art "click") reicht aber den Klick des Spielers an Blizzards eigenen Knopf
-- weiter: Blizzard schaltet dann in seinem eigenen Code um, so als haette man selbst geklickt.
--   1. Klick: Steht der Gegenstand schon in Blizzards Ergebnisliste, klickt der Knopf diese Zeile an: die Angebote
--      gehen sofort auf. Sonst klickt er Blizzards Reiter "Markt", danach sucht Broker den Gegenstand
--      (SendBrowseQuery wie seit 0.64.1).
--   2. Klick (ab 0.75): selbst auf die Zeile in Blizzards Liste (der Knopf "Angebote" entfaellt).
-- Broker liest Blizzards Liste nur (ForEachFrame, rowData). Attribute nur ausserhalb des Kampfs, im Kampf und
-- unterwegs bleibt es beim bisherigen Weg (Go.Market).
---------------------------------------------------------------------------
Go.marketButtons = {}

local function AHF() local f = rawget(_G, "AuctionHouseFrame"); return type(f) == "table" and f or nil end
local function InCombat() return InCombatLockdown and InCombatLockdown() or false end

-- Wirkt dieser Teil des Klicks? Sichere Knoepfe sind fuer Druecken und Loslassen angemeldet, die Aktion laeuft je
-- nach Einstellung ActionButtonUseKeyDown nur bei einem davon.
function Go.Acts(down)
    local cv = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
    if cv == nil then return not down end
    return (down and true or false) == (cv and true or false)
end

-- Zeile in Blizzards Ergebnisliste des Markts fuer diesen Gegenstand (oder nil). Nur lesen.
function Go.BrowseRow(key)
    local f = AHF()
    local id = key ~= nil and ns.Data.ItemID(key)
    local brf = f and rawget(f, "BrowseResultsFrame")
    local list = type(brf) == "table" and rawget(brf, "ItemList")
    local box = type(list) == "table" and rawget(list, "ScrollBox")
    if not (id and type(box) == "table" and type(box.ForEachFrame) == "function") then return nil end
    local found
    pcall(box.ForEachFrame, box, function(row)
        if found then return end
        local d = rawget(row, "rowData")
        if d == nil and type(row.GetRowData) == "function" then local ok, x = pcall(row.GetRowData, row); if ok then d = x end end
        local ik = type(d) == "table" and d.itemKey
        if type(ik) == "table" and ik.itemID == id then found = row end
    end)
    return found
end

local function SetClick(b, target)
    if InCombat() then return false end
    if target then
        b:SetAttribute("type", "click")
        b:SetAttribute("clickbutton", target)
    else
        b:SetAttribute("type", nil)
        b:SetAttribute("clickbutton", nil)
    end
    return true
end

-- Vor dem sicheren Teil: Ziel des Klicks festlegen (Zeile mit dem Gegenstand oder Blizzards Reiter Markt)
function Go.PreMarket(b, down)
    if not Go.Acts(down) then return end
    b.stage = nil
    local item = b.getItem and b.getItem()
    if not item or InCombat() or not ns.Window.AtAH() then SetClick(b, nil); return end
    local key = KeyOf(item)
    local row = Go.BrowseRow(key)
    local f = AHF()
    if row then
        SetClick(b, row); b.stage = "row"
    elseif f and type(rawget(f, "BuyTab")) == "table" then
        SetClick(b, f.BuyTab); b.stage = "tab"
    else
        SetClick(b, nil)
    end
end

-- Nach dem sicheren Teil: suchen und den Knopf fuer die Angebote vorbereiten, unterwegs der bisherige Weg
function Go.PostMarket(b, down)
    if not Go.Acts(down) then return end
    local item = b.getItem and b.getItem()
    if not item then mod:Print(L.GO_NONE); return end
    if b.stage == "row" then return end
    if b.stage == "tab" then
        local from = Go.Here()
        if ns.AHTabs and ns.AHTabs.current then ns.AHTabs.Close() end
        ns.Buy.ShowInAH({ key = KeyOf(item), itemKey = item.itemKey })
        if from then Go.SetBack(from) end
        return
    end
    mod:Call("Sprung", Go.Market, item)   -- unterwegs, im Kampf oder ohne Blizzards Reiter
end

-- Knopf "Im Markt zeigen" (sicher). getItem() liefert den Gegenstand ({ key, name, ... }) oder nil.
function Go.MarketButton(parent, width, getItem)
    local UI = Peon.UI
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    if not ok or not b then
        return UI.Button(parent, L.GO_MARKET, width, function()
            local it = getItem()
            if it then mod:Call("Sprung", Go.Market, it) else mod:Print(L.GO_NONE) end
        end)
    end
    b:SetSize(width, 22)
    b:SetText(L.GO_MARKET)
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    b.getItem = getItem
    b:SetScript("PreClick", function(self, _, down) mod:Call("Sprung", Go.PreMarket, self, down) end)
    b:SetScript("PostClick", function(self, _, down) mod:Call("Sprung", Go.PostMarket, self, down) end)
    Go.marketButtons[#Go.marketButtons + 1] = b
    return b
end

-- Der Gold-Knopf "Angebote: <Name>" (0.73 bis 0.74) entfaellt (KarloDerBaer 12.11.2026: stoert, wird nicht gebraucht).
-- Nach dem Sprung auf Markt klickt man selbst auf die Zeile. Go.HideOffer bleibt, weil AHTabs es aufruft.
function Go.HideOffer() end

function Go.InitMarket()
    -- ab 0.75 nichts mehr zu tun (Knopf "Angebote" entfaellt)
end
