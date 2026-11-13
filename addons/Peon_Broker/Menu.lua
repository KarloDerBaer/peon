-- Peon_Broker - Menu.lua
-- Umbau U4 (ab 0.45, Konzept Peon_Broker_Umbau.md, Abschnitt 9): Brokers Eintraege im Gegenstandsmenue des Kerns
-- (Peon.AddItemMenu, API 16; Strg+Rechtsklick auf einen Gegenstand).
--   Info               Gegenstand im Broker-Fenster zeigen (bis zum neuen Fenster U10 im Reiter Preise)
--   Auf Einkaufsliste  Untermenue mit allen Listen und "Neue Liste"
--   Beobachten         an/aus, Untermenue Preisgrenze (ab 0.49, U8)
-- Ohne Kern ab API 16 gibt es kein Menue, sonst aendert sich nichts.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local M = {}
ns.Menu = M

M.ORDER = 10   -- Broker zuerst

-- Gegenstand auf der Seite Gegenstand zeigen (im Auktionshaus als Reiter, sonst im Broker-Fenster)
function M.Info(item)
    local W, P = ns.Window, ns.Item
    if not W or not P then return end
    local key = item.key
    if key == nil then key = item.link and ns.Data.KeyFromLink(item.link) or item.id end
    W.Open("prices")
    P.Show(key)
end

-- Auf eine bestimmte Einkaufsliste (i = Nummer, nil = neue Liste)
function M.AddToList(i, item)
    local B = ns.Buy
    if not B then return false end
    if i == nil then
        B.NewList()
    else
        mod.char.listSel = i
    end
    if item.link then return B.AddFromLink(item.link) end
    return B.AddItem(item.id, { name = item.name })
end

function M.Build(root, item)
    -- ab 0.88: Kiste mit Paketliste, vorgeschlagenes Paket auf die Liste Handelsauftrag (Pack.lua)
    if ns.Pack then ns.Pack.AddMenu(root, item) end
    -- ab 0.59 (Neuaufbau N1): dieselben Spruenge wie in Brokers Listen (Go.lua)
    root:CreateButton(L.GO_MARKET, function() mod:Call("Menue", ns.Go.Market, item) end)
    root:CreateButton(L.MENU_INFO, function() mod:Call("Menue", ns.Go.Item, item) end)
    root:CreateButton(L.MENU_FOCUS, function() mod:Call("Menue", ns.Go.Focus, item) end)
    local B = ns.Buy
    if B and B.Lists then
        local sub = root:CreateButton(L.MENU_SHOP)
        for i, l in ipairs(B.Lists()) do
            local idx = i
            sub:CreateButton(l.name or ("#" .. i), function() mod:Call("Menue", M.AddToList, idx, item) end)
        end
        sub:CreateButton(L.MENU_SHOP_NEW, function() mod:Call("Menue", M.AddToList, nil, item) end)
    end
    if ns.Watch then
        local key = item.link and ns.Data.KeyFromLink(item.link) or item.id
        ns.Watch.AddMenu(root, item, key)
    end
    -- ab 0.91 (Fehlerbericht 17): Chance einschaetzen (Rating.lua)
    if ns.Rating then root:CreateButton(L.MENU_RATE, function() mod:Call("Einschaetzung", ns.Rating.Open, item) end) end
end

function M.Init()
    if not Peon.AddItemMenu then return end
    Peon.AddItemMenu(ADDON_NAME, function(root, item) M.Build(root, item) end, M.ORDER)
end
