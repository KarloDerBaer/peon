-- Peon_Broker - Buy.lua
-- Reiter "Einkaufsliste" (Bauabschnitt 7, abgestimmt 30.09.2026, Peon_Broker_Einkaufen.md, Rechenmodell Kap. 5):
--   Einkaufslisten (ab 0.34 accountweit und abgeglichen mit dem Peon Manager, Shop.lua; Rabatt x % unter dem Median je Liste,
--   Wunschmenge und optionaler eigener Hoechstpreis je Gegenstand).
--   Schnaeppchen: ab 0.14 eigener Reiter "Radar" (Radar.lua); B.Deals/B.ScanFresh/B.live werden dort genutzt.
-- Anklicken: Live-Abfrage und Anzeige in Blizzards Kaufen-Ansicht. "Kaufen": Rueckfrage mit Preis, dann kaufen.
-- Ab 0.136 (U4, Konzept Peon_Broker_Schlank.md 7, KarloDerBaer 24./25.11.2026): Reiter Listen schlank.
--   Spalten Gegenstand, Brauche, Fehlt, Hoechstpreis, Guenstigstes (mit Hinweis Haendler), x (Zeile loeschen).
--   Jeder Kauf zaehlt sofort, ob aus Brokers Einkaufen oder aus Blizzards Kaufen: Broker liest Gegenstand und Menge
--   beim Bestaetigen des Spiels mit (B.HookPurchases) und merkt sie als "unterwegs" (it.way, nur im Spiel), bis die
--   Ware in Taschen oder Bank ist. Fehlt = Brauche minus Vorrat minus unterwegs (KarloDerBaer 25.11.2026, so bleiben
--   die Listen aus Peon_Profession richtig). Erledigtes wird grau und bleibt stehen, ein Regler setzt Brauche neu.
--   Die Kaufzeile unter der Liste entfaellt, Doppelklick oeffnet das Einkaufen mit der Menge, die noch fehlt.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local B = {}
ns.Buy = B

B.LIVE_WAIT = 4
local GREY, ORANGE, GREEN, RED = "|cff999999", "|cffff9933", "|cff60e060", "|cffff4040"
B.ADVICE_COLOR = { buy = "|cff60e060", part = "|cffffd100", expensive = "|cffff4040", check = "|cff999999", done = "|cff999999",
                   vendor = "|cff66bbff", sell = "|cff60e0e0" }   -- ab 0.68: HAENDLER, VERKAUFEN
B.ADVICE_ORDER = { sell = 0, buy = 1, part = 2, vendor = 2.5, check = 3, expensive = 4, done = 5 }
local function Money(v) return ns.Tooltip.Money(v) end
local function AHApi() return rawget(_G, "C_AuctionHouse") end
local function AHOpen() return ns.Scan.ahOpen and AHApi() ~= nil end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Call(obj, name, ...)
    if type(obj) ~= "table" or type(obj[name]) ~= "function" then return false end
    return pcall(obj[name], obj, ...)
end

---------------------------------------------------------------------------
-- Einkaufslisten (accountweit, ab 0.34): acc.lists = { { id, name, pct, u, items = { [Schluessel] = { wish, max, name, q, icon, u } } } },
-- acc.listsGone = Loeschmarken (Shop.lua). Gewaehlte Liste je Charakter (char.listSel).
---------------------------------------------------------------------------
local function Shop() return ns.Shop end

function B.NewId()
    return ("g%.0f_%d"):format(time(), math.random(1, 1000000))
end

function B.Gone()
    local a = mod.acc
    if type(a.listsGone) ~= "table" then a.listsGone = {} end
    local g = a.listsGone
    if type(g.lists) ~= "table" then g.lists = {} end
    if type(g.items) ~= "table" then g.items = {} end
    return g
end

-- Listen dieses Charakters (bis 0.33) einmalig uebernehmen. Gleicher Name: in die vorhandene Liste, nichts geht verloren.
function B.TakeCharLists(lists)
    local c = mod.char
    if type(c) ~= "table" or type(c.lists) ~= "table" then return end
    local now = time()
    for _, old in ipairs(c.lists) do
        if type(old) == "table" then
            local into
            for _, l in ipairs(lists) do if l.name == old.name then into = l end end
            if not into then
                into = { id = B.NewId() .. "_" .. #lists, name = old.name, pct = old.pct or 10, u = now, items = {} }
                lists[#lists + 1] = into
            end
            for key, it in pairs(type(old.items) == "table" and old.items or {}) do
                if not into.items[key] and type(it) == "table" then
                    it.u = now
                    into.items[key] = it
                end
            end
        end
    end
    c.lists = nil
end

function B.Lists()
    local a = mod.acc
    if type(a) ~= "table" then return {} end
    if type(a.lists) ~= "table" then a.lists = {} end
    B.TakeCharLists(a.lists)
    return a.lists
end

function B.CurrentList()
    -- ab 0.49 (U8): Beobachtung als eigene Liste
    -- ab 0.82 hat die Beobachtung einen eigenen Reiter (WatchPage.lua), Einkaufen zeigt nur noch Einkaufslisten
    local lists = B.Lists()
    local i = tonumber(mod.char and mod.char.listSel) or 1
    return lists[i] or lists[1], lists[i] and i or 1
end

function B.NewList(name)
    local lists = B.Lists()
    lists[#lists + 1] = { id = B.NewId(), name = name or L.BUY_LIST_DEFAULT:format(#lists + 1), pct = 10, u = time(), items = {} }
    mod.char.listSel = #lists
    return lists[#lists]
end

function B.DeleteList(i)
    if i == "watch" then return end
    local lists = B.Lists()
    if not lists[i] then return end
    if lists[i].id then B.Gone().lists[lists[i].id] = Shop().NextU(time(), lists[i].u) end
    table.remove(lists, i)
    mod.char.listSel = math.max(1, math.min(i, #lists))
end

function B.AddItem(key, info)
    if key == nil then return false end
    local list = B.CurrentList() or B.NewList()
    if list.watch then return ns.Watch.Add(key, info) end
    local e = list.items[key]
    if not e then
        local gk = tostring(list.id) .. "|" .. tostring(key)
        e = { u = Shop().NextU(time(), B.Gone().items[gk]) }
        B.Gone().items[gk] = nil
    end
    if type(info) == "table" then
        e.name = info.name or e.name
        e.q = info.quality or info.q or e.q
        e.icon = info.icon or e.icon
    end
    list.items[key] = e
    mod:Print(L.BUY_ADDED:format(e.name or tostring(key), list.name))
    if B.view then B.Refresh() end
    return true
end

function B.RemoveItem(list, key)
    if not (list and list.items[key]) then return end
    if list.watch then ns.Watch.Remove(key); return end
    if list.id then B.Gone().items[tostring(list.id) .. "|" .. tostring(key)] = Shop().NextU(time(), list.items[key].u) end
    list.items[key] = nil
end

-- Material aus dem Berufsfenster (ab 0.68, H4, Konzept 6.5): fehlendes Material fuer n Herstellungen auf die Liste
-- "Material" (wird bei Bedarf angelegt). mats = { { id, q (je Herstellung), have (Vorrat), vendor, ah } }.
-- Ziel = q x n, "Fehlt" rechnet die Liste selbst gegen den Vorrat. Was der Haendler guenstiger hat, wird als
-- Haendlerware markiert (v = true, Rat HAENDLER). Rueckgabe: Zahl der Eintraege, Liste
function B.AddMaterials(mats, n)
    n = math.max(1, math.floor(tonumber(n) or 1))
    local lists = B.Lists()
    local list
    for _, l in ipairs(lists) do if l.name == L.CRAFT_LIST_NAME then list = l end end
    if not list then
        list = { id = B.NewId(), name = L.CRAFT_LIST_NAME, pct = 10, u = time(), items = {} }
        lists[#lists + 1] = list
    end
    local added = 0
    for _, m in ipairs(mats or {}) do
        local need = (tonumber(m.q) or 0) * n
        if m.id and need - (tonumber(m.have) or 0) > 0 then
            local e = list.items[m.id]
            if not e then
                local gk = tostring(list.id) .. "|" .. tostring(m.id)
                e = { u = Shop().NextU(time(), B.Gone().items[gk]) }
                B.Gone().items[gk] = nil
            end
            e.name = e.name or ns.GetItemInfo(m.id)
            e.icon = e.icon or B.Icon(m.id)
            e.wish = math.max(tonumber(e.wish) or 0, need)
            e.v = (m.vendor and (not m.ah or m.vendor <= m.ah)) and true or nil
            B.Touch(e, "wish")
            list.items[m.id] = e
            added = added + 1
        end
    end
    if added > 0 then mod:Print(L.CRAFT_LIST_ADDED:format(added, list.name, n)) else mod:Print(L.CRAFT_LIST_NOTHING) end
    if B.view then B.Refresh() end
    return added, list
end

-- Ab 0.94 (fuer Peon_Profession, mod:AddToList): Material auf eine Liste mit festem Namen. mats = { { id, n } }.
-- Die Wunschmenge wird auf n gesetzt (nicht addiert), damit ein erneutes Uebernehmen den Stand ersetzt.
-- Ab 0.95 keepMax (Material aus dem Berufsfenster): Wunschmenge wird nicht kleiner, v markiert Haendlerware.
function B.AddToNamed(name, mats, keepMax)
    local lists = B.Lists()
    local list
    for _, l in ipairs(lists) do if l.name == name then list = l end end
    if not list then
        list = { id = B.NewId(), name = name, pct = 10, u = time(), items = {} }
        lists[#lists + 1] = list
    end
    local added = 0
    for _, m in ipairs(mats) do
        local id, n = tonumber(m.id), math.floor(tonumber(m.n) or 0)
        if id and n > 0 then
            local e = list.items[id]
            if not e then
                local gk = tostring(list.id) .. "|" .. tostring(id)
                e = { u = Shop().NextU(time(), B.Gone().items[gk]) }
                B.Gone().items[gk] = nil
            end
            e.name = e.name or ns.GetItemInfo(id)
            e.icon = e.icon or B.Icon(id)
            if keepMax then
                n = math.max(tonumber(e.wish) or 0, n)
                e.v = m.v and true or nil
            end
            if e.wish ~= n then e.wish = n; B.Touch(e, "wish") end
            list.items[id] = e
            added = added + 1
        end
    end
    if B.view then B.Refresh() end
    return added, list
end

-- Aenderung an einer Liste oder einem Eintrag vermerken (Abgleich mit dem Manager).
-- Ab 0.89 je Wert: f = "name" oder "pct" (Liste), "wish" oder "max" (Eintrag)
function B.Touch(obj, f)
    if not obj then return end
    if f == nil then obj.u = Shop().NextU(time(), obj.u); return end   -- ganzer Eintrag wie bis 0.88
    local spec = (f == "name" or f == "pct") and Shop().LIST_SPEC or Shop().ITEM_SPEC
    Shop().Stamp(obj, spec, f, time())
end

-- Listen aus dem Manager einmischen, die Bridge ruft das beim Laden auf (Data.lua). Rueckgabe: true bei Aenderung
function mod:MergeShop(data)
    local lists = B.Lists()
    local gone = B.Gone()
    Shop().Purge(gone, time())
    local changed = Shop().Merge(lists, gone, data)
    for _, l in ipairs(lists) do
        for key, it in pairs(l.items) do
            if not it.icon then it.icon = B.Icon(ns.Data.ItemID(key)) end
        end
    end
    if changed and B.view then mod:Call("Einkaufsliste", B.Refresh) end
    return changed
end

function B.AddFromLink(link)
    local key = ns.Data.KeyFromLink(link)
    if key == nil then return false end
    local e = ns.Data.Lookup(key)
    return B.AddItem(key, { name = type(link) == "string" and link:match("%[(.-)%]") or ns.Data.ItemName(key, e),
        quality = type(e) == "table" and e.ql or nil, icon = B.Icon(ns.Data.ItemID(key)) })
end

-- Suche nach Namen in den Scan-Daten: exakter Treffer oder erster (alphabetisch), der den Text enthaelt
function B.AddByName(text)
    text = ns.Window.Lower(strtrim and strtrim(text or "") or (text or ""))
    if text == "" then return false end
    local market = ns.Data.Market()
    if not market then mod:Print(L.BUY_NOT_FOUND:format(text)); return false end
    local exact, first
    for key, e in pairs(market.items) do
        local name = type(e) == "table" and e.nm
        if name then
            local ln = ns.Window.Lower(name)
            if ln == text then exact = { key, e } end
            if ln:find(text, 1, true) and (not first or ln < ns.Window.Lower(first[2].nm)) then first = { key, e } end
        end
    end
    local hit = exact or first
    if not hit then mod:Print(L.BUY_NOT_FOUND:format(text)); return false end
    return B.AddItem(hit[1], { name = hit[2].nm, quality = hit[2].ql, icon = B.Icon(ns.Data.ItemID(hit[1])) })
end

function B.Icon(id)
    if id and C_Item and C_Item.GetItemIconByID then
        local ok, i = pcall(C_Item.GetItemIconByID, id)
        if ok and i then return i end
    end
    return nil
end

---------------------------------------------------------------------------
-- ab 0.136 (U4): Gekauftes zaehlt sofort ("unterwegs" bis Taschen oder Bank)
---------------------------------------------------------------------------
B.WAY_DAYS = 30   -- so lange gilt Gekauftes als unterwegs, danach zaehlt nur der Vorrat (Post laeuft nach 30 Tagen ab)

-- Vorrat eines Gegenstands (Taschen, Bank, mit Haken auch die anderen Charaktere)
function B.Stock(key)
    local _, _, total = ns.Stock.Counts(ns.Data.ItemID(key), nil)
    return total or 0
end

-- Gekauft, aber noch nicht im Vorrat. it.way = { q = Menge, base = Vorrat beim ersten Kauf, t = Zeit }. Angekommen ist,
-- was der Vorrat seitdem zugelegt hat. Ist alles angekommen oder zu alt, faellt way weg.
function B.Way(it, key, stock)
    local w = type(it) == "table" and it.way or nil
    if w == nil then return 0 end
    if type(w) ~= "table" or not Num(w.q) then it.way = nil; return 0 end
    stock = stock or B.Stock(key)
    local left = w.q - math.max(0, stock - (tonumber(w.base) or 0))
    if left <= 0 or time() - (tonumber(w.t) or 0) > B.WAY_DAYS * 86400 then it.way = nil; return 0 end
    return left
end

-- Was noch fehlt: Brauche minus Vorrat minus unterwegs (nil ohne Brauche)
function B.Need(it, key, stock)
    if type(it) ~= "table" or not Num(it.wish) then return nil end
    stock = stock or B.Stock(key)
    return math.max(0, it.wish - stock - B.Way(it, key, stock))
end

-- Fehlt fuer einen Gegenstand einer Liste (id der Liste), nil wenn er dort nicht steht
function B.NeedFor(key, listId)
    for _, l in ipairs(B.Lists()) do
        if l.id == listId and l.items[key] then return B.Need(l.items[key], key) end
    end
    return nil
end

-- Kauf von id (Gegenstandsnummer) in Menge qty auf die Listen verteilen, die ihn noch brauchen. Die gewaehlte Liste
-- zuerst, jede bekommt hoechstens, was ihr fehlt. Rueckgabe: verbuchte Menge
function B.OnPurchase(id, qty)
    if not (Num(id) and Num(qty) and qty > 0) then return 0 end
    local D = ns.Data
    local cur = B.CurrentList()
    local order = { cur }
    for _, l in ipairs(B.Lists()) do if l ~= cur then order[#order + 1] = l end end
    local left, booked = qty, 0
    for _, l in ipairs(order) do
        for key, it in pairs(type(l) == "table" and l.items or {}) do
            if left > 0 and D.ItemID(key) == id then
                local stock = B.Stock(key)
                local need = B.Need(it, key, stock)
                if need and need > 0 then
                    local n = math.min(need, left)
                    if type(it.way) == "table" then it.way.q, it.way.t = it.way.q + n, time()
                    else it.way = { q = n, base = stock, t = time() } end
                    left, booked = left - n, booked + n
                end
            end
        end
    end
    if booked > 0 then
        if B.view then B.Refresh() else B.UpdateBadge(); if ns.Side then ns.Side.Refresh() end end
    end
    return booked
end

-- Gegenstand einer Auktion, auf die geboten wird (wie Peon_Ledger M.BidItem)
function B.BidItem(auctionID)
    local ah = AHApi()
    if ah and type(ah.GetAuctionInfoByID) == "function" and Num(auctionID) then
        local ok, info = pcall(ah.GetAuctionInfoByID, auctionID)
        if ok and type(info) == "table" and type(info.itemKey) == "table" and Num(info.itemKey.itemID) then return info.itemKey.itemID end
    end
    local f = rawget(_G, "AuctionHouseFrame")
    local buy = type(f) == "table" and rawget(f, "ItemBuyFrame") or nil
    if type(buy) == "table" then
        local k = rawget(buy, "itemKey")
        if type(k) ~= "table" and type(buy.GetItemKey) == "function" then
            local ok, x = pcall(buy.GetItemKey, buy)
            if ok then k = x end
        end
        if type(k) == "table" and Num(k.itemID) then return k.itemID end
    end
    return nil
end

-- Bestaetigen und Bieten mitlesen (Brokers eigene Kaeufe und Blizzards Kaufen gehen beide hier durch)
B.PEND_SEC = 60
function B.HookPurchases()
    local ah = AHApi()
    if B.hooked or not (hooksecurefunc and type(ah) == "table") then return false end
    if type(ah.ConfirmCommoditiesPurchase) ~= "function" or type(ah.PlaceBid) ~= "function" then return false end
    local ok = pcall(function()
        hooksecurefunc(ah, "ConfirmCommoditiesPurchase", function(id, qty)
            B.pendBuy = { id = id, qty = qty, t = time() }
        end)
        hooksecurefunc(ah, "PlaceBid", function(auctionID)
            B.pendBid = { auctionID = auctionID, id = B.BidItem(auctionID), t = time() }
        end)
    end)
    B.hooked = ok
    return ok
end

-- kind "commodity" (Kauf von Massenware gelungen), "failed" (fehlgeschlagen), "item" (Auktion gekauft, arg = Nummer)
function B.OnPurchaseEvent(kind, arg)
    local now = time()
    if kind == "commodity" then
        local p = B.pendBuy
        B.pendBuy = nil
        if p and now - p.t <= B.PEND_SEC then B.OnPurchase(p.id, p.qty) end
    elseif kind == "failed" then
        B.pendBuy = nil
    elseif kind == "item" then
        local p = B.pendBid
        if p and now - p.t <= B.PEND_SEC and (arg == nil or p.auctionID == nil or p.auctionID == arg) then
            B.pendBid = nil
            B.OnPurchase(p.id, 1)
        end
    end
end

-- Zeilen der aktuellen Liste (F28-F30 mit Scan-Daten bzw. letzter Live-Abfrage)
-- Rat je Zeile (ab 0.49, U8): "buy" genug unter dem Hoechstpreis, "part" nur ein Teil, "expensive" nichts
-- darunter, "check" ohne Stand, "done" Ziel erreicht
function B.Advice(r)
    -- ab 0.68 (H4, Konzept 6.6): Beobachtung mit Grenze nach oben, guenstigstes Angebot darueber
    local now = r.cheapest or r.marketMin
    if r.up and now and now >= r.up then return "sell" end
    if r.need == 0 then return "done" end
    -- ab 0.68 (H4, Konzept 6.4): Haendler hat es guenstiger als das Auktionshaus (oder nur er)
    if r.vendorP and (not r.cheapest or r.vendorP < r.cheapest) then return "vendor" end
    if not r.cheapest and not r.hits then return "check" end
    if (r.hits or 0) <= 0 then return r.cheapest and "expensive" or "check" end
    if r.need and r.hits < r.need then return "part" end
    return "buy"
end

-- ab 0.140: Hoechstpreis eines Eintrags: der Wert in der Liste (aus dem Einkaufen uebernommen), sonst Kaufen bis
-- des Einkaufens aus Beobachten. Der Rabatt der Liste (pct) zaehlt nicht mehr, er bleibt gespeichert.
function B.LimitOf(key, it)
    local v = it and tonumber(it.max)
    if Num(v) and v > 0 then return v end
    local Wt = ns.Watch
    local w = Wt and Wt.Is(key) and Wt.Store()[key]
    if w and Num(w.qlim) and w.qlim > 0 then return w.qlim end
    return nil
end

-- ab 0.140: Listen, in denen key steht (fuer das Einkaufen)
function B.ListsWith(key)
    local out = {}
    if key == nil then return out end
    for _, l in ipairs(B.Lists()) do if type(l.items) == "table" and l.items[key] then out[#out + 1] = l end end
    return out
end

-- ab 0.140: Kaufen bis aus dem Einkaufen in alle Listen mit diesem Gegenstand (nil = leeren)
function B.SetMaxFromShop(key, price)
    local n = 0
    price = (Num(price) and price > 0) and math.floor(price) or nil
    for _, l in ipairs(B.ListsWith(key)) do
        local it = l.items[key]
        if it.max ~= price then it.max = price; B.Touch(it, "max"); n = n + 1 end
    end
    if n > 0 and B.view then B.Refresh() end
    return n
end

-- ab 0.140: Hoechstpreis fuer das Einkaufen: aus der Liste listId (sonst der ersten mit dem Gegenstand)
function B.MaxForShop(key, listId)
    local best
    for _, l in ipairs(B.ListsWith(key)) do
        local v = tonumber(l.items[key].max)
        if Num(v) and v > 0 then
            if l.id == listId then return v end
            best = best or v
        end
    end
    return best
end

function B.ListRows(list)
    list = list or B.CurrentList()
    local rows = {}
    if not list then return rows end
    for key, it in pairs(list.items) do
        local e = ns.Data.Lookup(key)
        -- ab 0.140 (KarloDerBaer 26.11.2026): nur noch der Hoechstpreis aus dem Einkaufen (Kaufen bis), ohne Rabatt
        local limit = B.LimitOf(key, it)
        local live = B.live[key]
        local levels = live and live.rows or ns.Data.ParseLevels(type(e) == "table" and e.lv)
        local cheapest
        for _, r in ipairs(levels) do
            if (r.qty - math.min(r.own or 0, r.qty)) > 0 and (not cheapest or r.price < cheapest) then cheapest = r.price end
        end
        local hitQty = limit and ns.Data.BelowLimit(levels, limit) or 0
        -- Vorrat (ab 0.24): Taschen + Bank, mit Umschalter "Vorrat aller Charaktere" auch die Twinks (Ledger)
        local stock = B.Stock(key)
        local way = B.Way(it, key, stock)   -- ab 0.136: gekauft, noch nicht im Vorrat
        local need = B.Need(it, key, stock)   -- ab 0.49: Ziel minus Vorrat, ab 0.136 auch minus unterwegs
        local r = { key = key, name = it.name or ns.Data.ItemName(key, e) or tostring(key), quality = it.q,
            icon = it.icon, wish = it.wish, limit = limit, cheapest = cheapest, hits = hitQty, stock = stock, need = need,
            live = live ~= nil, lname = W.Lower(it.name or ""), list = list.name, watch = list.watch, way = way }
        if not cheapest and type(e) ~= "table" then r.hits = nil end
        r.up = it.up
        r.marketMin = type(e) == "table" and not e.gone and tonumber(e.m) or nil   -- ohne Preisstufen der Stand aus Scan/Live
        if ns.Merchant and not list.watch then
            local vp, vsrc = ns.Merchant.Price(ns.Data.ItemID(key))
            if vp then r.vendorP, r.vendorSrc = vp, vsrc end
        end
        r.advice = B.Advice(r)
        r.done = r.advice == "done"   -- ab 0.136: erledigt, grau
        -- ab 0.136: Guenstigstes mit Hinweis Haendler, wenn ein Haendler guenstiger ist
        r.best, r.bestVendor = cheapest, false
        if r.vendorP and (not cheapest or r.vendorP < cheapest) then r.best, r.bestVendor = r.vendorP, true end
        rows[#rows + 1] = r
    end
    return rows
end

-- Zahl am Reiter Einkaufen (ab 0.49, U8): alle Zeilen aus Einkaufslisten und Beobachtung mit Rat Kaufen oder
-- Teilweise, ohne Blinken
function B.CountBuyable(onlyBuy)
    local n = 0
    local lists = {}
    for _, l in ipairs(B.Lists()) do lists[#lists + 1] = l end
    for _, l in ipairs(lists) do
        for _, r in ipairs(B.ListRows(l)) do
            if r.advice == "buy" or (r.advice == "part" and not onlyBuy) then n = n + 1 end
        end
    end
    return n
end

function B.UpdateBadge()
    local T = ns.AHTabs
    if not (T and T.SetBadge and T.built) then return end
    local mode = T.BadgeMode and T.BadgeMode("buy") or "buypart"   -- ab 0.97 einstellbar
    T.SetBadge("buy", mode ~= "off" and B.CountBuyable(mode == "buy") or nil, false)
end

-- Reiter gerade zu sehen (Broker-Fenster oder Auktionshaus)
function B.Shown()
    local T = ns.AHTabs
    if T and T.current == "buy" then return true end
    if T and T.host and T.host.buy == "ah" then return false end
    return W.IsOpen() and W.current == "buy"
end

---------------------------------------------------------------------------
-- Schnaeppchen (F31-F34)
---------------------------------------------------------------------------
function B.ScanFresh()
    local market = ns.Data.Market()
    if not market or not market.lastScan then return false, nil end
    local age = time() - market.lastScan
    local m = tonumber(mod.db.radarMaxAge) or 60
    return m <= 0 or age <= m * 60, age
end

function B.Deals()
    local rows = {}
    local market = ns.Data.Market()
    if not market or not B.ScanFresh() then return rows end
    local D, db = ns.Data, mod.db
    local today = D.Day()
    local dg = (tonumber(db.dumpPct) or 30) / 100
    for key, e in pairs(market.items) do
        if type(e) == "table" and e.lv and not e.gone and e.m then
            local hp = ns.VendorPrice(D.ItemID(key))
            -- schneller Vorfilter: nur, wenn das guenstigste Angebot unter Haendler- oder Dump-Grenze liegt
            if (hp and e.m < hp) or (e.md and e.m < e.md * (1 - dg)) then
                local live = B.live[key]
                local levels = live and live.rows or D.ParseLevels(e.lv)
                local deal = D.Deal(e, levels, hp, db, today, key)
                if deal then
                    deal.key, deal.e = key, e
                    deal.name = e.nm or D.ItemName(key, e) or tostring(key)
                    deal.quality = e.ql
                    deal.icon = B.Icon(D.ItemID(key))
                    deal.scans = D.ScanCount(e, tonumber(db.dealDays) or 7, today)
                    deal.live = live ~= nil
                    rows[#rows + 1] = deal
                end
            end
        end
    end
    return rows
end

---------------------------------------------------------------------------
-- Live-Abfrage (eine Abfrage zur Zeit; Ergebnis ohne eigene Angebote)
---------------------------------------------------------------------------
B.live = {}   -- [Schluessel] = { rows, t }

---------------------------------------------------------------------------
-- Ersatz-Schluessel (ab 0.24, Feedback #5): Gegenstaende mit Zusatz ("... des Wolfs") fand die Suche mit dem
-- Schluessel aus MakeItemKey(itemID) nicht (0 Angebote, vollstaendig) - der Radar meldete "weg", obwohl die
-- Auktion im Blizzard-Fenster stand. Dann sucht Broker den Gegenstand ueber die Browse-Suche (wie das
-- Suchfeld des Auktionshauses) und merkt sich den Schluessel des Spiels: PeonBrokerDB.itemKeys[itemID] = "Stufe:Zusatz".
-- Protokoll: PeonBrokerDB.keyLog (letzte 30).
---------------------------------------------------------------------------
B.KEY_WAIT = 3   -- Sekunden auf die Browse-Ergebnisse warten

function B.AltKeys()
    local acc = mod.acc
    if type(acc.itemKeys) ~= "table" then acc.itemKeys = {} end
    return acc.itemKeys
end

function B.ForgetKey(key)
    if type(mod.acc.itemKeys) ~= "table" then return end
    if ns.Data.IsVariantKey(key) then mod.acc.itemKeys[key] = nil; return end   -- ab 0.28: Schluessel je Variante
    local id = ns.Data.ItemID(key)
    if id then mod.acc.itemKeys[id] = nil end
end

---------------------------------------------------------------------------
-- Suchschluessel je Variante (ab 0.28): Ausruestung mit Zusatz hat im Spiel je Variante einen eigenen Schluessel
-- (itemSuffix, z. B. 14309). Broker lernt ihn nebenbei: beim Verkaufen (Gegenstand in den Taschen), aus eigenen
-- Auktionen, aus jedem Suchergebnis (auch beim Stoebern im Blizzard-Fenster) und aus der Browse-Suche.
-- PeonBrokerDB.itemKeys["itemID:voller Name"] = "Stufe:Zusatz"
---------------------------------------------------------------------------
function B.LearnKey(key, itemKey)
    if not ns.Data.IsVariantKey(key) or type(itemKey) ~= "table" then return end
    local lvl, suf = itemKey.itemLevel, itemKey.itemSuffix
    if not Num(lvl) or not Num(suf) then return end
    local text = ("%d:%d"):format(lvl, suf)
    local keys = B.AltKeys()
    if keys[key] ~= text then keys[key] = text; mod:Dbg("Schluessel gelernt: " .. tostring(key) .. " = " .. text) end
end

-- Kann Broker den Gegenstand gezielt abfragen? Varianten nur mit gelerntem Schluessel
function B.KnownKey(key)
    if not ns.Data.IsVariantKey(key) then return true end
    return type(mod.acc.itemKeys) == "table" and type(mod.acc.itemKeys[key]) == "string"
end

-- Suchergebnisse eines Gegenstands mit Varianten lesen und die Schluessel lernen (Ereignis des Spiels)
function B.LearnFromResults(itemKey)
    if type(itemKey) ~= "table" or not ns.Data.HasVariants(itemKey.itemID) then return end
    local ah = AHApi()
    if not (ah and ah.GetNumItemSearchResults and ah.GetItemSearchResultInfo) then return end
    local ok, n = pcall(ah.GetNumItemSearchResults, itemKey)
    for i = 1, math.min(ok and tonumber(n) or 0, 50) do
        local okr, r = pcall(ah.GetItemSearchResultInfo, itemKey, i)
        if okr and type(r) == "table" and r.itemLink then
            B.LearnKey(ns.Data.KeyFromLink(r.itemLink), type(r.itemKey) == "table" and r.itemKey or itemKey)
        end
    end
end

local function KeyLog(text)
    mod:Dbg("Schluessel: " .. text)
    if not mod:IsDebug() then return end   -- ab 0.28 nur mit /broker debug
    local acc = mod.acc
    if type(acc.keyLog) ~= "table" then acc.keyLog = {} end
    acc.keyLog[#acc.keyLog + 1] = (date and date("%d.%m. %H:%M:%S ") or "") .. text
    while #acc.keyLog > 30 do table.remove(acc.keyLog, 1) end
end

-- Browse-Suche nach dem Namen; done(gefunden, Liste { itemKey, min, qty }) kommt immer (spaetestens nach KEY_WAIT)
function B.FindKey(key, done)
    local ah = AHApi()
    local id = ns.Data.ItemID(key)
    -- Grundname ohne Zusatz (findet alle Varianten), sonst der Name aus dem Scan
    local name = id and ns.GetItemInfo(id)
    if type(name) ~= "string" or Peon.IsSecret(name) then name = ns.Data.ItemName(key, (ns.Data.Lookup(key))) end
    if not (AHOpen() and ah.SendBrowseQuery and ah.GetBrowseResults and id) then return false end
    if type(name) ~= "string" or name == "" or name == tostring(key) then return false end
    local job = { key = key, itemID = id, name = name, done = done }
    B.keyJob = job
    local order = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0
    local ok = pcall(ah.SendBrowseQuery, { searchString = name, sorts = { { sortOrder = order, reverseSort = false } },
                                           filters = {}, itemClassFilters = {} })
    if not ok then B.keyJob = nil; return false end
    if C_Timer then C_Timer.After(B.KEY_WAIT, function() if B.keyJob == job then B.FinishKey(job) end end) end
    return true
end

function B.OnBrowseResults()
    local job = B.keyJob
    if not job then return end
    local ok, list = pcall(AHApi().GetBrowseResults)
    if not ok or type(list) ~= "table" then return end
    local found = {}
    for _, r in ipairs(list) do
        local k = type(r) == "table" and r.itemKey
        if type(k) == "table" and k.itemID == job.itemID and Num(r.totalQuantity) and r.totalQuantity > 0 then
            found[#found + 1] = { itemKey = k, min = Num(r.minPrice) and r.minPrice or nil, qty = r.totalQuantity }
        end
    end
    if #found > 0 then B.FinishKey(job, found) end   -- sonst auf weitere Ergebnisse warten (bis KEY_WAIT)
end

function B.FinishKey(job, found)
    if B.keyJob == job then B.keyJob = nil end
    local best, parts = nil, {}
    for _, f in ipairs(found or {}) do
        parts[#parts + 1] = ("%s/%s %sx%s"):format(tostring(f.itemKey.itemLevel), tostring(f.itemKey.itemSuffix), tostring(f.min), tostring(f.qty))
        if not best or (f.min or math.huge) < (best.min or math.huge) then best = f end
    end
    local std = ""
    local ah = AHApi()
    if ah and ah.MakeItemKey then
        local ok, k = pcall(ah.MakeItemKey, job.itemID)
        if ok and type(k) == "table" then std = (" (Standard %s/%s)"):format(tostring(k.itemLevel), tostring(k.itemSuffix)) end
    end
    KeyLog(("%s %s%s: %s"):format(tostring(job.itemID), job.name, std, best and table.concat(parts, ", ") or "nichts gefunden"))
    local ok = best ~= nil
    if ns.Data.HasVariants(job.itemID) or ns.Data.IsVariantKey(job.key) then   -- ab 0.102.0 auch fuer Chancen mit Varianten-Schluessel
        -- ab 0.28: Varianten - Name je Schluessel vom Spiel (GetItemKeyInfo), so lernt Broker alle auf einmal
        local ah2 = AHApi()
        for _, f in ipairs(found or {}) do
            local okI, info = pcall(ah2.GetItemKeyInfo, f.itemKey)
            local name = okI and type(info) == "table" and info.itemName
            if type(name) == "string" and name ~= "" and not Peon.IsSecret(name) then
                B.LearnKey(ns.Data.VariantKey(job.itemID, name), f.itemKey)
            end
        end
        ok = not ns.Data.IsVariantKey(job.key) or B.KnownKey(job.key)
    elseif best then
        B.AltKeys()[job.itemID] = ("%d:%d"):format(tonumber(best.itemKey.itemLevel) or 0, tonumber(best.itemKey.itemSuffix) or 0)
    end
    if job.done then job.done(ok, found or {}) end
end

function B.ItemKeyFor(key)
    local ah = AHApi()
    local id = ns.Data.ItemID(key)
    local keys = type(mod.acc.itemKeys) == "table" and mod.acc.itemKeys or {}
    local alt
    if ns.Data.IsVariantKey(key) then alt = keys[key] else alt = id and keys[id] end   -- ab 0.28: Schluessel je Variante
    if type(alt) == "string" then
        local lvl, suf = alt:match("^(%-?%d+):(%-?%d+)$")
        if lvl then return { itemID = id, itemLevel = tonumber(lvl), itemSuffix = tonumber(suf), battlePetSpeciesID = 0 } end
    end
    if ah and ah.MakeItemKey then
        local ok, k = pcall(ah.MakeItemKey, id)
        if ok and type(k) == "table" then return k end
    end
    return { itemID = id, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
end

function B.Query(key, done)
    local ah = AHApi()
    if not AHOpen() or not (ah.SendSearchQuery or ah.SendSellSearchQuery) then return false end
    if (ns.Buying and ns.Buying()) or (ah.IsThrottledMessageSystemReady and not ah.IsThrottledMessageSystemReady()) then   -- ab 0.74: nicht waehrend eines Kaufs
        if C_Timer then C_Timer.After(0.5, function() B.Query(key, done) end) end
        return true
    end
    local itemKey = B.ItemKeyFor(key)
    local p = { key = key, itemID = itemKey.itemID, itemKey = itemKey, done = done }
    B.pending = p
    local order = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0
    local ok = pcall(ah.SendSearchQuery or ah.SendSellSearchQuery, itemKey, { { sortOrder = order, reverseSort = false } }, true)
    mod:Dbg(("Einkaufen: Live %s gesendet %s"):format(tostring(key), tostring(ok)))
    if C_Timer then
        C_Timer.After(B.LIVE_WAIT, function()
            if B.pending == p then B.pending = nil; if p.done then p.done(false) end; B.UpdateView() end
        end)
    end
    B.UpdateView()
    return ok
end

-- Einzelgegenstaende: je Preisstufe die Auktionsnummern merken (zum Kaufen); nur passender Zusatz
function B.ReadItemRows(itemKey, key)
    local ah = AHApi()
    local rows, byPrice = { offers = {}, commodity = false }, {}   -- offers: einzelne Angebote fuer den Absatz (ab 0.23)
    local ok, n = pcall(ah.GetNumItemSearchResults, itemKey)
    local want = type(itemKey) == "table" and itemKey.itemID or nil
    for i = 1, (ok and tonumber(n) or 0) do
        local okr, r = pcall(ah.GetItemSearchResultInfo, itemKey, i)
        if okr and ns.Probe and ns.Probe.Field then ns.Probe.Field("item", r) end
        if okr and type(r) == "table" and ns.Live.Foreign(r, want) then
            rows.foreign = (rows.foreign or 0) + 1   -- Ergebnis eines anderen Gegenstands (ab 0.21.1)
        elseif okr and type(r) == "table" and Num(r.buyoutAmount) then
            local k = r.itemLink and ns.Data.KeyFromLink(r.itemLink)
            if k ~= nil and type(r.itemKey) == "table" then B.LearnKey(k, r.itemKey) end   -- ab 0.28
            if k == key and ns.Data.IsVariantKey(key) then rows.link = rows.link or r.itemLink end
            if k == nil or k == key or type(key) ~= "string" then
                local qty = Num(r.quantity) and r.quantity > 0 and r.quantity or 1
                local row = byPrice[r.buyoutAmount]
                if not row then
                    row = { price = r.buyoutAmount, qty = 0, own = 0, ids = {} }
                    byPrice[r.buyoutAmount] = row
                    rows[#rows + 1] = row
                end
                row.qty = row.qty + qty
                if Num(r.auctionID) then
                    rows.offers[#rows.offers + 1] = { id = r.auctionID, q = qty, p = r.buyoutAmount / qty, secs = r.timeLeftSeconds, band = r.timeLeft }
                end
                if r.containsOwnerItem then row.own = row.own + qty
                elseif r.auctionID then row.ids[#row.ids + 1] = r.auctionID end
            end
        end
    end
    table.sort(rows, function(a, b) return a.price < b.price end)
    if not ns.Live.IsFull(false, itemKey) then rows.partial = true end
    return rows
end

local function OnResults(commodity, arg)
    local p = B.pending
    if not p then return end
    local id = commodity and arg or (type(arg) == "table" and arg.itemID)
    if id ~= p.itemID then return end
    local rows = commodity and ns.Live.ReadCommodity(p.itemID) or B.ReadItemRows(type(arg) == "table" and arg or p.itemKey, p.key)
    if #rows == 0 and (rows.partial or rows.foreign) then return end   -- Spiel laedt noch: weiter warten (ab 0.20.1)
    B.pending = nil
    B.live[p.key] = { rows = rows, t = time(), commodity = commodity }
    ns.Data.ApplyLive(p.key, rows, time())   -- aktueller Stand in die Datenbank (ab 0.15)
    if p.done then p.done(true) end
    B.UpdateView()
end

-- Liste nacheinander live abfragen
function B.SearchList()
    local rows = B.ListRows()
    if #rows == 0 or not AHOpen() or B.run then return end
    B.run = { rows = rows, i = 0 }
    B.NextSearch()
end

function B.NextSearch()
    local run = B.run
    if not run then return end
    run.i = run.i + 1
    local r = run.rows[run.i]
    if not r or not AHOpen() or not B.Shown() then
        B.run = nil
        B.nextScan = (GetTime and GetTime() or time()) + B.SCAN_PAUSE   -- ab 0.140
        B.Refresh()
        return
    end
    B.Query(r.key, function() B.NextSearch() end)
end

-- ab 0.140 (KarloDerBaer 26.11.2026): Solange Listen am Auktionshaus offen ist, fragt Broker die offene Liste reihum
-- ab, jeden Gegenstand einmal, nach jeder Runde B.SCAN_PAUSE Sekunden Pause. Der Knopf "Liste durchsuchen" entfaellt.
B.SCAN_PAUSE = 30
B.TICK = 2
function B.Tick()
    B.ticking = false
    if not (B.view and B.Shown()) then return end
    local now = GetTime and GetTime() or time()
    if AHOpen() and not B.run and now >= (B.nextScan or 0) then B.SearchList() end
    B.StartTick()
end

function B.StartTick()
    if B.ticking or not (C_Timer and C_Timer.After) then return end
    B.ticking = true
    C_Timer.After(B.TICK, function() mod:Call("Einkaufsliste", B.Tick) end)
end

-- ab 0.140: andere Liste gewaehlt: gleich die neue abfragen
function B.RescanSoon()
    B.run = nil
    B.nextScan = 0
end

---------------------------------------------------------------------------
-- Auswahl, Anzeige im Auktionshaus, Kaufplan
---------------------------------------------------------------------------
-- Gegenstand in Blizzards Markt zeigen (ab 0.64.1, Fehlerberichte 10 und 11 in peon-fehler).
-- Bis 0.64 rief Broker Blizzards SelectBrowseResult (und damit SetDisplayMode) auf und leerte Blizzards Liste. Danach
-- galt Blizzards Wert displayMode als von Broker beruehrt: Ein Rechtsklick auf einen nicht verkaufbaren Gegenstand in
-- der Tasche lief ueber IsListingAuctions und dann UseContainerItem, und das Spiel blockierte ihn
-- (ADDON_ACTION_FORBIDDEN, nachgelesen in ContainerFrame.lua, Zweig forever).
-- Jetzt fasst Broker nichts davon an: Der Name kommt als Text in Blizzards Suchfeld, die Suche geht ueber die
-- Spiel-API (C_AuctionHouse.SendBrowseQuery). Blizzards Liste fuellt sich mit dem Ergebnis selbst (eigenes Ereignis
-- AUCTION_HOUSE_BROWSE_RESULTS_UPDATED), ein Klick auf die Zeile zeigt die Angebote. Umschalten auf "Markt" darf nur
-- Blizzard selbst (Klick auf den Reiter), darum steht sonst ein Hinweis da.
-- row: { key, ... }. Rueckgabe: true = Suche geschickt
function B.SearchName(key)
    local id = ns.Data.ItemID(key)
    local name = id and ns.GetItemInfo(id)   -- Grundname ohne Zusatz findet alle Varianten
    if type(name) ~= "string" or Peon.IsSecret(name) or name == "" then name = ns.Data.ItemName(key, (ns.Data.Lookup(key))) end
    if type(name) ~= "string" or name == "" or name == tostring(key) then return nil end
    return name
end

-- Zeigt Blizzard gerade die Liste der Suchergebnisse (Ansicht Markt ohne gewaehlten Gegenstand)? Liest nur.
function B.InBrowse(f)
    local modes = rawget(_G, "AuctionHouseFrameDisplayMode")
    if type(f) ~= "table" or type(f.GetDisplayMode) ~= "function" or type(modes) ~= "table" then return true end
    local ok, m = pcall(f.GetDisplayMode, f)
    return ok and m == modes.Buy
end

-- Hinweis oben am Bildschirm: Die Treffer stehen im Markt, Umschalten per Klick
function B.HintMarket()
    local ef = rawget(_G, "UIErrorsFrame")
    if type(ef) == "table" and ef.AddMessage then pcall(ef.AddMessage, ef, L.GO_AH_HINT, 1, 0.82, 0) end
    mod:Print(L.GO_AH_HINT)
end

function B.ShowInAH(row)
    local f = rawget(_G, "AuctionHouseFrame")
    if not AHOpen() or type(f) ~= "table" or not row then return false end
    if not ns.AHTouch() then return false end   -- ab 0.41: "Blizzard pur"
    if ns.AHTabs and ns.AHTabs.current then return false end   -- Broker-Reiter offen: erst die Flaeche schliessen
    local name = B.SearchName(row.key)
    local ah = AHApi()
    if not name or not ah.SendBrowseQuery then return false end
    local bar = rawget(f, "SearchBar")
    local box = type(bar) == "table" and rawget(bar, "SearchBox") or nil
    if type(box) == "table" and box.SetText then pcall(box.SetText, box, name) end   -- nur sichtbarer Text
    local order = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0
    local ok = pcall(ah.SendBrowseQuery, { searchString = name, sorts = { { sortOrder = order, reverseSort = false } },
                                           filters = {}, itemClassFilters = {} })
    B.shown = { key = row.key, name = name, t = time and time() or 0 }
    if ok and not B.InBrowse(f) then B.HintMarket() end
    mod:Dbg("Im Markt gesucht: " .. tostring(row.key) .. " " .. tostring(ok))
    return ok and true or false
end

-- Laeuft gerade eine eigene Abfrage von Broker? (ab 0.21.1: Anzeige wartet, sonst ueberholen sich die Suchen)
function B.QueryBusy()
    local R, S, A = ns.Radar, ns.Live, ns.Auctions
    if R and R.pending and not R.pending.viaAH then return true end
    if B.pending or B.keyJob or (S and S.pending) then return true end
    if A and A.liveRun and A.liveRun.pending then return true end
    return false
end

-- Protokoll der Anzeige im Blizzard-Fenster (ab 0.21.1): PeonBrokerDB.showLog, die letzten 40 Zeilen
function B.ShowLog(text)
    mod:Dbg("Anzeige: " .. text)
    if not mod:IsDebug() then return end   -- ab 0.28 nur mit /broker debug
    local acc = mod.acc
    if type(acc.showLog) ~= "table" then acc.showLog = {} end
    local l = acc.showLog
    l[#l + 1] = (date and date("%H:%M:%S ") or "") .. text
    while #l > 40 do table.remove(l, 1) end
end

function B.Select(row)
    B.selected = row
    if row then
        B.ShowInAH(row)
        B.Query(row.key, function() B.Refresh() end)
    end
    B.UpdateView()
end

-- Was wuerde "Kaufen" tun? { qty, cost, limit, commodity, auctionID, price }
function B.Plan(row)
    if not row then return nil end
    local live = B.live[row.key]
    if not live then return nil end
    local limit = row.limit
    if not limit then return nil end
    local qty, cost = ns.Data.BelowLimit(live.rows, limit)
    if row.wish then
        local cur = B.CurrentList()
        local it = cur and cur.items[row.key] or { wish = row.wish }
        qty = math.min(qty, B.Need(it, row.key) or 0)   -- ab 0.136 mit unterwegs
        -- Kosten fuer die begrenzte Menge neu rechnen (guenstigste zuerst)
        cost = 0
        local left = qty
        for _, r in ipairs(live.rows) do
            local q = math.min(left, r.qty - math.min(r.own or 0, r.qty))
            if r.price <= limit and q > 0 then cost = cost + q * r.price; left = left - q end
        end
    end
    local plan = { qty = qty, cost = cost, limit = limit, commodity = live.commodity }
    if not live.commodity then
        for _, r in ipairs(live.rows) do
            if r.price <= limit and r.ids and r.ids[1] then plan.auctionID, plan.price, plan.qty, plan.cost = r.ids[1], r.price, 1, r.price; break end
        end
        if not plan.auctionID then plan.qty = 0 end
    end
    return plan
end

---------------------------------------------------------------------------
-- Kaufen
---------------------------------------------------------------------------
StaticPopupDialogs["PEON_BROKER_CONFIRM_BUY"] = {
    text = "%s",
    button1 = YES, button2 = NO,
    OnAccept = function(_, data) if type(data) == "table" and data.yes then data.yes() end end,
    OnCancel = function(_, data) if type(data) == "table" and data.no then data.no() end end,
    timeout = 0, whileDead = false, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

local function Ask(text, yes, no)
    if StaticPopup_Show then StaticPopup_Show("PEON_BROKER_CONFIRM_BUY", text, nil, { yes = yes, no = no }) end
end

function B.Buy()
    local row = B.selected
    if not row or B.buying or not AHOpen() then return end
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.SELL_COMBAT); return end
    local plan = B.Plan(row)
    if not plan or plan.qty < 1 then mod:Print(L.BUY_NOTHING); return end
    local ah = AHApi()
    local id = ns.Data.ItemID(row.key)
    if plan.commodity then
        local ok = pcall(ah.StartCommoditiesPurchase, id, plan.qty)
        if not ok then mod:Print(L.BUY_FAILED); return end
        B.buying = { kind = "commodity", id = id, qty = plan.qty, limit = plan.limit, name = row.name, key = row.key, t = time() }
    else
        B.buying = { kind = "item", auctionID = plan.auctionID, price = plan.price, name = row.name, key = row.key, t = time() }
        Ask(L.BUY_ASK_ITEM:format(row.name, Money(plan.price)), function()
            local ok = pcall(ah.PlaceBid, plan.auctionID, plan.price)
            if not ok then B.buying = nil; mod:Print(L.BUY_FAILED) end
        end, function() B.buying = nil; B.UpdateView() end)
    end
    B.UpdateView()
    if C_Timer then
        local job = B.buying
        C_Timer.After(30, function() if B.buying == job then B.buying = nil; B.UpdateView() end end)
    end
end

-- Massenware: das Spiel nennt den genauen Preis, dann Rueckfrage
function B.OnPriceUpdated(unitPrice, totalPrice)
    local job = B.buying
    if not job or job.kind ~= "commodity" or not Num(totalPrice) then return end
    local ah = AHApi()
    local text = L.BUY_ASK_COMMODITY:format(job.qty, job.name, Money(totalPrice), Money(unitPrice or 0))
    if Num(unitPrice) and job.limit and unitPrice > job.limit then
        text = text .. "\n" .. RED .. L.BUY_ABOVE_LIMIT:format(Money(job.limit)) .. "|r"
    end
    job.total = totalPrice
    Ask(text, function()
        local ok = pcall(ah.ConfirmCommoditiesPurchase, job.id, job.qty)
        if not ok then B.buying = nil; mod:Print(L.BUY_FAILED); B.UpdateView() end
    end, function()
        pcall(ah.CancelCommoditiesPurchase)
        if ns.Radar then ns.Radar.buyUntil = nil end   -- ab 0.74: abgebrochen, Abfragen wieder frei
        B.buying = nil
        B.UpdateView()
    end)
end

function B.OnBought(ok)
    if ns.Radar then ns.Radar.buyUntil = nil end   -- ab 0.74: Kauf vorbei, Abfragen wieder frei (vor B.Query)
    local job = B.buying
    if not job then return end
    B.buying = nil
    if ok then
        local qty = job.qty or 1
        local cost = job.total or job.price
        mod:Print(L.BUY_DONE:format(qty, job.name, cost and Money(cost) or "?"))
        B.live[job.key] = nil
        if B.selected and B.selected.key == job.key then B.Query(job.key, function() B.Refresh() end) end
    else
        mod:Print(L.BUY_FAILED)
    end
    B.Refresh()
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
function B.Refresh()
    if ns.Side and ns.Side.Tab() == "list" then ns.Side.Refresh() end   -- ab 0.137 (U5)
    if not B.view then return end
    local names = {}
    for i, l in ipairs(B.Lists()) do
        local n = { index = i, name = l.name, count = 0, pos = i }
        for _ in pairs(l.items) do n.count = n.count + 1 end
        names[#names + 1] = n
    end
    B.listList.sortKey = "pos"
    B.listList:SetData(names)
    local _, ci = B.CurrentList()
    for _, n in ipairs(names) do if n.index == ci then B.listList:Select(n) end end
    B.itemList:SetData(B.ListRows())
    B.UpdateBadge()
    if B.allChars then
        local has = ns.Stock.Ledger() ~= nil
        B.allChars:SetShown(has)
        B.allChars:SetChecked(mod.db.keepAllChars == true)
    end
    -- Auswahl in der neuen Liste wiederfinden
    if B.selected then
        local found
        for _, r in ipairs(B.itemList:GetItems()) do if r.key == B.selected.key then found = r end end
        B.selected = found
        if found then B.itemList:Select(found) end
    end
    B.UpdateView()
end

function B.UpdateView()
    if not B.view then return end
    local cur = B.CurrentList()
    -- Listen-Einstellungen
    -- ab 0.91: nicht ueberschreiben, waehrend man tippt. Jede Antwort des Auktionators fuellte die Felder neu, der
    -- getippte Name ging verloren und beim Verlassen wurde der alte gespeichert (Fehlerbericht 18).
    -- ab 0.140: Name, Neu und Loeschen nur noch ueber den Rechtsklick auf eine Liste, der Rabatt entfaellt
    -- Gewaehlter Gegenstand (ab 0.136 ohne Kaufzeile, gekauft wird im Einkaufen)
    local row = B.selected
    if row then
        B.itemBar:Show()
        B.filling = true
        local it = cur and cur.items[row.key]
        B.wishBox:SetText(it and it.wish and tostring(it.wish) or "")
        if B.wishRow then B.wishRow:SetShown(not (cur and cur.watch)) end
        B.wishBox:SetShown(not (cur and cur.watch))
        local isWatch = cur and cur.watch and true or false
        if B.upRow then B.upRow:SetShown(isWatch) end
        if B.upBox then
            B.upBox:SetShown(isWatch)
            B.upBox:SetText(isWatch and it and it.up and tostring(it.up / 10000) or "")
        end
        B.SyncWishSlider(it)
        B.filling = false
    else
        B.itemBar:Hide()
    end
    B.StartTick()   -- ab 0.140: laufende Abfrage statt Knopf
    if B.run then B.listStatus:SetText(GREY .. L.BUY_SEARCHING:format(B.run.i, #B.run.rows) .. "|r")
    else B.listStatus:SetText("") end
end

-- ab 0.136 (U4): Regler fuer Brauche. Bereich 1 bis doppelt so viel wie jetzt, mindestens B.WISH_MIN_MAX
B.WISH_MIN_MAX = 20
function B.WishMax(wish)
    local v = math.max(B.WISH_MIN_MAX, (tonumber(wish) or 0) * 2)
    local step = v > 1000 and 100 or v > 200 and 20 or 10
    return math.ceil(v / step) * step
end

function B.SyncWishSlider(it)
    local s = B.wishSlider
    if not s then return end
    local wish = it and Num(it.wish) and it.wish or 1
    local hi = (s.peonMax and wish <= s.peonMax and s.peonMax >= B.WishMax(wish) / 2) and s.peonMax or B.WishMax(wish)
    if s.peonMax ~= hi or s.peonVal ~= wish then
        B.wishSync = true
        if type(s.Slider) == "table" and type(s.Init) == "function" then
            local mix = rawget(_G, "MinimalSliderWithSteppersMixin")
            local right = mix and mix.Label and mix.Label.Right
            pcall(s.Init, s, wish, 1, hi, math.max(1, hi - 1), right and { [right] = function() return "" end } or nil)
            if type(s.RightText) == "table" and s.RightText.Hide then s.RightText:Hide() end
        else
            if s.SetMinMaxValues then s:SetMinMaxValues(1, hi) end
            if s.SetValue then s:SetValue(wish) end
        end
        B.wishSync = false
        s.peonMax, s.peonVal = hi, wish
    end
    s:SetShown(it ~= nil)
end

-- Brauche setzen (Feld oder Regler). Ein neuer Wert macht eine erledigte Zeile wieder aktiv, wenn wieder etwas fehlt.
function B.SetWish(v)
    local cur = B.CurrentList()
    if B.filling or B.wishSync or not cur or not B.selected then return end
    local it = cur.items[B.selected.key]
    if not it then return end
    v = tonumber(v)
    if v then v = math.floor(v + 0.5) end
    if v and v < 1 then v = nil end
    if v ~= it.wish then it.wish = v; B.Touch(it, "wish") end
    B.Refresh()
end

-- ab 0.136: Zeile loeschen (x in der Liste)
function B.DeleteRow(r)
    local cur = B.CurrentList()
    if not (cur and r and cur.items[r.key]) then return end
    B.RemoveItem(cur, r.key)
    if B.selected and B.selected.key == r.key then B.selected = nil end
    B.Refresh()
end

---------------------------------------------------------------------------
-- ab 0.140 (KarloDerBaer 26.11.2026): Listen nur ueber den Rechtsklick verwalten. Auf einer Liste: Neu, Umbenennen,
-- Loeschen. In der leeren Flaeche: Neu. Eine neue Liste beginnt gleich mit dem Umbenennen.
---------------------------------------------------------------------------
function B.ListMenu(r, owner)
    local mu = rawget(_G, "MenuUtil")
    if not (mu and mu.CreateContextMenu) then return false end
    mu.CreateContextMenu(owner, function(_, root)
        if r then root:CreateTitle(r.name or "") end
        root:CreateButton(L.BUY_MENU_NEW, function() mod:Call("Einkaufsliste", B.MenuNew) end)
        if r then
            root:CreateButton(L.BUY_MENU_RENAME, function() mod:Call("Einkaufsliste", B.StartRename, r.index) end)
            root:CreateButton(L.BUY_MENU_DELETE, function() mod:Call("Einkaufsliste", B.AskDelete, r.index) end)
        end
    end)
    return true
end

function B.MenuNew()
    B.NewList()
    B.selected = nil
    B.RescanSoon()
    B.Refresh()
    B.StartRename(mod.char.listSel)
end

function B.AskDelete(i)
    local l = B.Lists()[i]
    if not l then return end
    Peon.UI.Confirm(L.BUY_DELETE_ASK:format(l.name or ""), L.BUY_DELETE, CANCEL or "Cancel", function()
        mod:Call("Einkaufsliste", function()
            B.DeleteList(i); B.selected = nil; B.RescanSoon(); B.Refresh()
        end)
    end)
end

function B.ShowRename(on)
    if B.nameBox then B.nameBox:SetShown(on) end
    if B.nameRow and B.nameRow.SetShown then B.nameRow:SetShown(on) end
end

function B.StartRename(i)
    local l = B.Lists()[i]
    if not (l and B.nameBox) then return end
    B.renaming = l.id or i
    mod.char.listSel = i
    B.ShowRename(true)
    B.nameBox:SetText(l.name or "")
    if B.nameBox.SetFocus then B.nameBox:SetFocus() end
    if B.nameBox.HighlightText then B.nameBox:HighlightText() end
end

-- text = nil: abbrechen
function B.FinishRename(text)
    local id = B.renaming
    if id == nil then return end
    B.renaming = nil
    if text then
        text = tostring(text):gsub("^%s+", ""):gsub("%s+$", "")
        for i, l in ipairs(B.Lists()) do
            if (l.id or i) == id and text ~= "" and l.name ~= text then l.name = text; B.Touch(l, "name") end
        end
    end
    B.ShowRename(false)
    if B.nameBox and B.nameBox.ClearFocus then B.nameBox:ClearFocus() end
    B.Refresh()
end

-- ab 0.136: Doppelklick: im Einkaufen oeffnen, die Menge steht auf dem, was in dieser Liste noch fehlt
function B.ToShop(r)
    local cur = B.CurrentList()
    if not (r and cur) then return false end
    return ns.Go.Focus({ key = r.key, name = r.name, from = "list", list = cur.id })
end

-- Ueber der Spalte x? Die Tabelle meldet nur die Zeile, darum ueber den Spaltenkopf (wie Beobachten)
B.DEL_COL = 6
function B.OverDelete()
    if not GetCursorPosition then return false end
    local h = B.itemList and B.itemList.heads and B.itemList.heads[B.DEL_COL]
    local left, right = h and h.GetLeft and h:GetLeft(), h and h.GetRight and h:GetRight()
    local scale = h and h.GetEffectiveScale and h:GetEffectiveScale() or 1
    local x = GetCursorPosition()
    return left ~= nil and right ~= nil and x ~= nil and scale > 0 and x / scale >= left and x / scale <= right
end

B.DEL_ICON = "|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:14:14|t"

-- Tooltip einer Zeile: Gegenstand, darunter Vorrat, unterwegs, Haendler
function B.RowTooltip(row, r)
    W.ShowItemTooltip(row, r.key, function(GT)
        if Num(r.stock) then GT:AddLine(L.BUY_TIP_STOCK:format(r.stock), 0.85, 0.85, 0.85) end
        if Num(r.way) and r.way > 0 then GT:AddLine(L.BUY_TIP_WAY:format(r.way), 0.6, 0.9, 1, true) end
        if r.vendorP then GT:AddLine(L.BUY_TIP_VENDOR:format(Money(r.vendorP)), 0.4, 0.73, 1) end
        if r.done then GT:AddLine(L.BUY_TIP_DONE, 0.7, 0.7, 0.7, true) end
        GT:AddLine(L.BUY_TIP_DOUBLE, 0.6, 0.6, 0.6, true)
    end)
end

---------------------------------------------------------------------------
-- Aufbau
---------------------------------------------------------------------------
-- Neuaufbau N4 (ab 0.62, Konzept Peon_Broker_Neuaufbau.md, Abschnitt 4.3): Seite Einkaufen mit Peon.UI.
--   oben    Gegenstand hinzufuegen (Name oder Link, Eingabetaste), "Liste pruefen" (Live-Abfrage aller Gegenstaende)
--   links   die Listen (Beobachtung immer oben), darunter Einstellungen der Liste und des gewaehlten Gegenstands
--   rechts  Gegenstaende der Liste: Gegenstand, Ziel, Fehlt, Hoechstpreis, Guenstigstes, Rat
--   unten   Kaufzeile: was der Klick kauft, "Im Markt zeigen", Gold-Knopf "Kaufen"
-- Linksklick waehlt, Doppelklick zeigt im Markt, Rechtsklick oeffnet das Gegenstandsmenue (Go.Click).
B.LEFT_W = 240
B.FORM_X = 30   -- ab 0.74: Formularzeilen etwas eingerueckt, damit die grauen Zusaetze nicht ueber den Rand ragen

-- Peon.UI-Tabelle mit den Aufrufen, die B.Refresh nutzt
local function Adapt(t)
    function t:GetItems() return self.items end
    function t:Select(item)
        self.selected = item
        self.list:Refresh()
    end
    return t
end

-- ab 0.136: Text einer erledigten Zeile grau (grey = auch ohne erledigt grau, etwa ein alter Preis)
function B.Dim(text, r, grey)
    if (r and r.done) or grey then return GREY .. text .. "|r" end
    return text
end

local function Gold(text)
    local gold = tonumber((tostring(text or ""):gsub(",", ".")))
    if gold and gold > 0 then return math.floor(gold * 10000 + 0.5) end
    return nil
end

function B.Build(c)
    local UI = Peon.UI
    B.view = c
    B.listsView = c

    -- Obere Leiste (neben dem runden Bild): hinzufuegen und pruefen
    B.searchBox = UI.SearchBox(c, 240)
    B.searchBox:SetPoint("TOPLEFT", B.LEFT_W + 6, -4)
    B.searchBox:SetScript("OnEnterPressed", function(self)
        if B.AddByName(self:GetText()) then self:SetText("") end
        self:ClearFocus()
    end)
    UI.SetTooltip(B.searchBox, { L.BUY_ADD_TITLE, L.BUY_ADD_TIP })
    -- ab 0.140 ohne Knopf "Liste durchsuchen" (B.Tick fragt reihum ab), der Stand steht oben rechts
    B.listStatus = UI.Text(c, "small", "")
    B.listStatus:SetPoint("TOPRIGHT", -4, -10)

    -- Links oben: die Listen
    local lp = UI.Panel(c, "list", true)
    lp:SetPoint("TOPLEFT", 0, -34)
    lp:SetSize(B.LEFT_W, 170)
    B.listList = Adapt(UI.Table(lp, {
        columns = { { key = "name", title = L.BUY_LISTS },
                    { key = "count", title = "", width = 44, align = "RIGHT" } },
        empty = L.BUY_NO_LISTS,
        -- ab 0.140 (KarloDerBaer 26.11.2026): Rechtsklick auf eine Liste: Neu, Umbenennen, Loeschen
        onClick = function(r, button)
            if button == "RightButton" then mod:Call("Einkaufsliste", B.ListMenu, r, lp); return end
            mod.char.listSel = r.index; B.selected = nil; B.RescanSoon(); B.Refresh()
        end,
    }))
    -- ab 0.140: Rechtsklick in die leere Flaeche der Listen: Neu
    if lp.EnableMouse then lp:EnableMouse(true) end
    local function EmptyClick(_, button)
        if button == "RightButton" then mod:Call("Einkaufsliste", B.ListMenu, nil, lp) end
    end
    lp:HookScript("OnMouseUp", EmptyClick)
    if B.listList.list and B.listList.list.box and B.listList.list.box.HookScript then
        B.listList.list.box:HookScript("OnMouseUp", EmptyClick)
    end

    -- Links unten: gewaehlter Gegenstand (ab 0.140 ohne Einstellungen der Liste, die stehen im Rechtsklick)
    local left = UI.Panel(c, "left")
    left:SetPoint("TOPLEFT", lp, "BOTTOMLEFT", 0, -2)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(B.LEFT_W)
    -- Umbenennen (ab 0.140): Feld nur waehrend des Umbenennens, Eingabe speichert, Escape bricht ab
    B.nameBox = UI.Input(left, 120)
    B.nameRow = UI.FormRow(left, L.BUY_F_NAME, B.nameBox, B.FORM_X, -12)
    B.nameBox:SetScript("OnEnterPressed", function(self) B.FinishRename(self:GetText()) end)
    B.nameBox:SetScript("OnEscapePressed", function() B.FinishRename(nil) end)
    B.nameBox:SetScript("OnEditFocusLost", function(self) if B.renaming then B.FinishRename(self:GetText()) end end)
    B.ShowRename(false)

    -- gewaehlter Gegenstand: Brauche mit Regler (ab 0.140 ohne Hoechstpreis, der kommt aus dem Einkaufen)
    local ib = CreateFrame("Frame", nil, left)
    ib:SetPoint("TOPLEFT", 0, -44)
    ib:SetPoint("RIGHT", left, "RIGHT", 0, 0)
    ib:SetHeight(120)
    B.itemBar = ib
    local div = UI.Divider(ib, B.LEFT_W - 24)
    div:SetPoint("TOPLEFT", 12, 0)
    local il = UI.Text(ib, "heading", L.BUY_ITEM_HEAD)
    il:SetPoint("TOPLEFT", 14, -10)
    B.wishBox = UI.Input(ib, 80, { numeric = true })
    B.wishRow = UI.FormRow(ib, L.BUY_F_WISH, B.wishBox, B.FORM_X, -34, L.BUY_F_WISH_SUB)
    B.wishBox:SetScript("OnEditFocusLost", function(self) B.SetWish(self:GetText() or "") end)
    -- ab 0.68 (H4, Konzept 6.6): Beobachtung mit Grenze nach oben ("verkaufen ab"), an der Stelle des Ziels
    B.upBox = UI.Input(ib, 80)
    B.upRow = UI.FormRow(ib, L.BUY_F_UP, B.upBox, B.FORM_X, -34, L.BUY_F_UP_SUB)
    B.upBox:SetScript("OnEditFocusLost", function(self)
        local cur = B.CurrentList()
        if B.filling or not cur or not cur.watch or not B.selected then return end
        ns.Watch.SetUp(B.selected.key, Gold(self:GetText()))
        B.Refresh()
    end)
    -- ab 0.136 (U4): Regler fuer Brauche statt Knopf Entfernen (Loeschen ueber das x in der Liste)
    B.wishSlider = UI.Slider(ib, B.LEFT_W - 40, 1, B.WISH_MIN_MAX, 1, 1, function(v)
        if B.wishSync or not Num(v) then return end
        B.SetWish(v)
    end)
    B.wishSlider:SetPoint("TOPLEFT", 20, -72)
    UI.SetTooltip(B.wishSlider, { L.BUY_COL_WISH, L.BUY_WISH_TIP })

    -- Vorrat aller Charaktere (nur mit Peon_Ledger)
    B.allChars = UI.Check(left, L.BUY_F_ALLCHARS, mod.db.keepAllChars == true, function(on)
        mod.db.keepAllChars = on
        mod:Call("Einkaufsliste", B.Refresh)
    end, { L.KEEP_ALL_CHARS, L.BUY_ALL_CHARS_HINT })
    -- ab 0.74 oben neben dem runden Bild (unten lag der Haken unter "Entfernen")
    B.allChars:SetPoint("TOPLEFT", c, "TOPLEFT", 66, 0)

    -- Rechts: Gegenstaende der Liste
    local right = UI.Panel(c, "list", true)
    right:SetPoint("TOPLEFT", lp, "TOPRIGHT", 2, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)   -- ab 0.136 ohne Kaufzeile
    B.panel = right
    B.itemList = Adapt(UI.Table(right, {
        columns = {
            -- ab 0.136: erledigte Zeilen grau (bleiben stehen, bis man sie mit x loescht)
            { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
              color = function(r)
                  if r.done then return 0.5, 0.5, 0.5 end
                  return UI.QualityColor(r.quality or 1)
              end },
            { key = "wish", title = L.BUY_COL_WISH, width = 64, align = "RIGHT",
              format = function(v, r) return B.Dim(v and tostring(v) or "–", r) end },
            { key = "need", title = L.BUY_COL_NEED, width = 60, align = "RIGHT",
              format = function(v, r)
                  if v == nil then return "–" end
                  local t = tostring(v) .. ((Num(r.way) and r.way > 0) and ("|cff66bbff+|r") or "")
                  return v == 0 and (GREY .. "0|r") or t
              end },
            { key = "limit", title = L.BUY_COL_LIMIT, width = 100, align = "RIGHT",
              format = function(v, r) return B.Dim(v and Money(v) or "–", r) end },
            { key = "best", title = L.BUY_COL_BEST, width = 130, align = "RIGHT",
              format = function(v, r)
                  if not v then return "–" end
                  if r.bestVendor then return "|cff66bbff" .. L.BUY_VENDOR_HINT .. "|r " .. Money(v) end
                  return B.Dim(Money(v), r, not r.live)
              end,
              sort = function(r) return r.best or math.huge end },
            { key = "del", title = "", width = 30, align = "CENTER", nosort = true,
              format = function() return B.DEL_ICON end },
        },
        sortKey = "name", icon = true, empty = L.BUY_LIST_EMPTY,
        -- ab 0.136: Klick waehlt, Klick auf x loescht, Doppelklick oeffnet das Einkaufen, Rechtsklick das Menue
        onClick = function(r, button)
            if button == "RightButton" then ns.Go.Menu(r, B.panel); return end
            if B.OverDelete() then B.clickKey = nil; mod:Call("Einkaufsliste", B.DeleteRow, r); return end
            local now = GetTime and GetTime() or 0
            if B.clickKey == r.key and now - (B.clickT or 0) <= (ns.Go.DOUBLE or 0.4) then
                B.clickKey = nil
                mod:Call("Sprung", B.ToShop, r)
                return
            end
            B.clickKey, B.clickT = r.key, now
            mod:Call("Einkaufen", B.Select, r)
        end,
        onEnter = function(row, r)
            if not r then return end
            if B.OverDelete() and GameTooltip then
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.BUY_DEL_TIP, 1, 0.82, 0)
                GameTooltip:Show()
                return
            end
            B.RowTooltip(row, r)
        end,
    }))

    B.Refresh()
end

function B.Init()
    mod:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, itemID) OnResults(true, itemID) end)
    mod:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey) OnResults(false, itemKey) end)
    pcall(mod.RegisterEvent, mod, "COMMODITY_SEARCH_RESULTS_ADDED", function(_, itemID) OnResults(true, itemID) end)
    pcall(mod.RegisterEvent, mod, "ITEM_SEARCH_RESULTS_ADDED", function(_, itemKey) OnResults(false, itemKey) end)
    mod:RegisterEvent("COMMODITY_PRICE_UPDATED", function(_, unit, total) B.OnPriceUpdated(unit, total) end)
    mod:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED", function() B.OnBought(true) end)
    mod:RegisterEvent("COMMODITY_PURCHASE_FAILED", function() B.OnBought(false) end)
    mod:RegisterEvent("AUCTION_HOUSE_PURCHASE_COMPLETED", function() B.OnBought(true) end)
    -- ab 0.136 (U4): jeder Kauf zaehlt sofort in den Einkaufslisten
    B.HookPurchases()
    mod:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED", function() mod:Call("Einkaufsliste", B.OnPurchaseEvent, "commodity") end)
    mod:RegisterEvent("COMMODITY_PURCHASE_FAILED", function() B.OnPurchaseEvent("failed") end)
    mod:RegisterEvent("AUCTION_HOUSE_PURCHASE_COMPLETED", function(_, auctionID) mod:Call("Einkaufsliste", B.OnPurchaseEvent, "item", auctionID) end)
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function() B.HookPurchases() end)
    mod:RegisterEvent("AUCTION_HOUSE_CLOSED", function() B.run, B.pending, B.buying, B.keyJob = nil, nil, nil, nil end)
    -- ab 0.28: Suchschluessel der Varianten aus jedem Suchergebnis lernen (auch beim Stoebern im Blizzard-Fenster)
    mod:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey) mod:Call("Schluessel", B.LearnFromResults, itemKey) end)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function() B.OnBrowseResults() end)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function() B.OnBrowseResults() end)
    mod:On("SCAN_DONE", function()
        if B.Shown() then B.Refresh() else mod:Call("Einkaufsliste", B.UpdateBadge) end
    end)
end

W.pages.buy = {
    build = B.Build,
    refresh = B.Refresh,
}
