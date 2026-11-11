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
