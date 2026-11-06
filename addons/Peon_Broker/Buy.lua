-- Peon_Broker - Buy.lua
-- Reiter "Einkaufsliste" (Bauabschnitt 7, abgestimmt 30.09.2026, Peon_Broker_Einkaufen.md, Rechenmodell Kap. 5):
--   Einkaufslisten (ab 0.34 accountweit und abgeglichen mit dem Peon Manager, Shop.lua; Rabatt x % unter dem Median je Liste,
--   Wunschmenge und optionaler eigener Hoechstpreis je Gegenstand).
--   Schnaeppchen: ab 0.14 eigener Reiter "Radar" (Radar.lua); B.Deals/B.ScanFresh/B.live werden dort genutzt.
-- Anklicken: Live-Abfrage und Anzeige in Blizzards Kaufen-Ansicht. "Kaufen": Rueckfrage mit Preis, dann kaufen.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local B = {}
ns.Buy = B

B.LIVE_WAIT = 4
local GREY, ORANGE, GREEN, RED = "|cff999999", "|cffff9933", "|cff60e060", "|cffff4040"
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
    local lists = B.Lists()
    if not lists[i] then return end
    if lists[i].id then B.Gone().lists[lists[i].id] = Shop().NextU(time(), lists[i].u) end
    table.remove(lists, i)
    mod.char.listSel = math.max(1, math.min(i, #lists))
end

function B.AddItem(key, info)
    if key == nil then return false end
    local list = B.CurrentList() or B.NewList()
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
    if list.id then B.Gone().items[tostring(list.id) .. "|" .. tostring(key)] = Shop().NextU(time(), list.items[key].u) end
    list.items[key] = nil
end

-- Aenderung an einer Liste oder einem Eintrag vermerken (Abgleich mit dem Manager)
function B.Touch(obj)
    if obj then obj.u = Shop().NextU(time(), obj.u) end
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

-- Zeilen der aktuellen Liste (F28-F30 mit Scan-Daten bzw. letzter Live-Abfrage)
function B.ListRows()
    local list = B.CurrentList()
    local rows = {}
    if not list then return rows end
    for key, it in pairs(list.items) do
        local e = ns.Data.Lookup(key)
        local limit = tonumber(it.max) or ns.Data.MaxBuyPrice(e, list.pct)   -- eigener Hoechstpreis geht vor (ab 0.34)
        local live = B.live[key]
        local levels = live and live.rows or ns.Data.ParseLevels(type(e) == "table" and e.lv)
        local cheapest
        for _, r in ipairs(levels) do
            if (r.qty - math.min(r.own or 0, r.qty)) > 0 and (not cheapest or r.price < cheapest) then cheapest = r.price end
        end
        local hitQty = limit and ns.Data.BelowLimit(levels, limit) or 0
        -- Vorrat (ab 0.24): Taschen + Bank, mit Umschalter "Vorrat aller Charaktere" auch die Twinks (Ledger)
        local _, _, stock = ns.Keep.Counts(ns.Data.ItemID(key), nil)
        rows[#rows + 1] = { key = key, name = it.name or ns.Data.ItemName(key, e) or tostring(key), quality = it.q,
            icon = it.icon, wish = it.wish, limit = limit, cheapest = cheapest, hits = hitQty, stock = stock,
            live = live ~= nil, lname = W.Lower(it.name or "") }
    end
    return rows
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
    if ns.Data.HasVariants(job.itemID) then
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
    if ah.IsThrottledMessageSystemReady and not ah.IsThrottledMessageSystemReady() then
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
        if okr and type(r) == "table" and ns.Sell.Foreign(r, want) then
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
    if not ns.Sell.IsFull(false, itemKey) then rows.partial = true end
    return rows
end

local function OnResults(commodity, arg)
    B.GuardSeen(commodity, arg)
    local p = B.pending
    if not p then return end
    local id = commodity and arg or (type(arg) == "table" and arg.itemID)
    if id ~= p.itemID then return end
    local rows = commodity and ns.Sell.ReadCommodity(p.itemID) or B.ReadItemRows(type(arg) == "table" and arg or p.itemKey, p.key)
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
    if not r or not AHOpen() then B.run = nil; B.Refresh(); return end
    B.Query(r.key, function() B.NextSearch() end)
end

---------------------------------------------------------------------------
-- Auswahl, Anzeige im Auktionshaus, Kaufplan
---------------------------------------------------------------------------
-- Gegenstand in Blizzards Kaufen-Ansicht zeigen. Ab 0.20 verlaesslich: Blizzards SelectBrowseResult tut nichts,
-- solange das Spiel die Daten zum Gegenstand noch nicht hat (GetItemKeyInfo liefert nil) - dann blieb das Fenster
-- beim alten Gegenstand stehen. Broker wartet jetzt darauf (Ereignis ITEM_KEY_ITEM_INFO_RECEIVED bzw. alle 0,3 Sek.).
-- row: { key, itemKey (optional, z. B. aus der eigenen Auktion), offer/cheapest, qty }
-- Rueckgabe: true = jetzt gezeigt; false = nicht moeglich oder wird nachgeholt
B.SHOW_RETRY, B.SHOW_TRIES = 0.3, 15
B.GUARD_WAIT = 0.8   -- Sekunden: kommt bis dahin kein Ergebnis fuer den gezeigten Gegenstand, Blizzards Liste neu laden (ab 0.20.2)
function B.ShowInAH(row, tries)
    local f = rawget(_G, "AuctionHouseFrame")
    if not AHOpen() or type(f) ~= "table" or not row then return false end
    local ah = AHApi()
    local itemKey = type(row.itemKey) == "table" and row.itemKey or B.ItemKeyFor(row.key)
    if tries == nil then B.showToken = (B.showToken or 0) + 1 end
    local token = B.showToken
    local info
    if ah.GetItemKeyInfo then
        local ok
        ok, info = pcall(ah.GetItemKeyInfo, itemKey)
        if not ok then info = nil end
    end
    -- Daten nicht geladen oder das Spiel nimmt gerade keine Abfrage an (ab 0.20.2): kurz warten,
    -- sonst schaltet Blizzard um, laedt aber keine Angebote (Liste zeigte den vorherigen Gegenstand)
    local notReady = (ah.IsThrottledMessageSystemReady and not ah.IsThrottledMessageSystemReady()) or B.QueryBusy()
    local noInfo = ah.GetItemKeyInfo and type(info) ~= "table"
    if noInfo or notReady then
        tries = (tries or 0) + 1
        if tries <= B.SHOW_TRIES and C_Timer then
            B.showWait = { row = row, tries = tries, token = token }
            C_Timer.After(B.SHOW_RETRY, function()
                if B.showToken == token and B.showWait and B.showWait.token == token then B.ShowInAH(row, tries) end
            end)
            mod:Dbg(("Im Auktionshaus zeigen: %s - %s (Versuch %d)"):format(tostring(row.key),
                noInfo and "Daten noch nicht geladen" or "Spiel noch nicht bereit", tries))
            return false
        end
        B.showWait = nil
        if noInfo then return false end   -- ohne Daten schaltet Blizzard nicht um; nach langem Warten trotzdem zeigen
    end
    B.showWait = nil
    local ok = Call(f, "SelectBrowseResult", { itemKey = itemKey, minPrice = row.cheapest or row.offer or 0,
        totalQuantity = row.qty or row.hits or 0, containsOwnerItem = row.own and true or false })
    if ok then
        local commodity = type(info) == "table" and info.isCommodity
        if commodity == nil then commodity = ns.Data.IsCommodity(row.key) end
        B.StartGuard(itemKey, commodity and true or false, token, row)
    end
    -- Hat das Fenster wirklich umgeschaltet?
    local modes = rawget(_G, "AuctionHouseFrameDisplayMode")
    if ok and type(modes) == "table" and type(f.GetDisplayMode) == "function" then
        local okm, m = pcall(f.GetDisplayMode, f)
        if okm and m ~= nil and m ~= modes.CommoditiesBuy and m ~= modes.ItemBuy then ok = false end
    end
    mod:Dbg("Im Auktionshaus gezeigt: " .. tostring(row.key) .. " " .. tostring(ok))
    return ok
end

-- Laeuft gerade eine eigene Abfrage von Broker? (ab 0.21.1: Anzeige wartet, sonst ueberholen sich die Suchen)
function B.QueryBusy()
    local R, S, A = ns.Radar, ns.Sell, ns.Auctions
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

-- Gehoeren die Ergebnisse des Spiels zum gezeigten Gegenstand? "ok", "empty" (noch nichts / laedt), "foreign"
function B.CheckShown(g)
    local ah = AHApi()
    if g.commodity then
        local ok, n = pcall(ah.GetNumCommoditySearchResults, g.itemID)
        n = ok and tonumber(n) or 0
        if n == 0 then return ns.Sell.IsFull(true, g.itemID) and g.answered and "ok" or "empty", 0 end
        local okr, r = pcall(ah.GetCommoditySearchResultInfo, g.itemID, 1)
        if okr and type(r) == "table" and Num(r.itemID) and r.itemID ~= g.itemID then return "foreign", n end
        return "ok", n
    end
    local rows = ns.Sell.ReadItems(g.itemKey)
    if #rows > 0 then return "ok", #rows end
    if rows.foreign then return "foreign", rows.foreign end
    return (ns.Sell.IsFull(false, g.itemKey) and g.answered) and "ok" or "empty", 0
end

-- Nachsehen (ab 0.20.2, ueberarbeitet 0.21.1; KarloDerBaer: Titel richtig, Liste darunter noch vom vorherigen Gegenstand):
-- nach dem Umschalten pruefen, ob die Ergebnisse zum Gegenstand passen; sonst bis zu 3 Versuche:
-- 1. wie Blizzards "Neu laden" (Refresh...SearchResults), 2. eigene Suche, 3. Gegenstand nochmal zeigen.
B.GUARD_TRIES = 3
B.GUARD_FORCE = 0.3   -- Sekunden nach dem Umschalten: einmal neu laden (ab 0.21.1)

-- Wie Blizzards Knopf "Neu laden": Liste im Blizzard-Fenster leeren (Reset) und die Suche neu schicken
function B.ReloadBlizzardList(itemKey, commodity)
    local f = rawget(_G, "AuctionHouseFrame")
    local frame = type(f) == "table" and (commodity and f.CommoditiesBuyFrame or f.ItemBuyFrame) or nil
    local list = type(frame) == "table" and frame.ItemList or nil
    if type(list) == "table" then Call(list, "Reset") end
    local ah = AHApi()
    local fn = commodity and ah.RefreshCommoditySearchResults or ah.RefreshItemSearchResults
    local ok = false
    if fn then ok = pcall(fn, commodity and itemKey.itemID or itemKey) end
    if not ok and ah.SendSearchQuery then
        local order = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0
        ok = pcall(ah.SendSearchQuery, itemKey, { { sortOrder = order, reverseSort = false } }, true)
    end
    return ok
end

function B.StartGuard(itemKey, commodity, token, row)
    local g = { itemID = itemKey.itemID, itemKey = itemKey, commodity = commodity, token = token, tries = 0, row = row, t0 = GetTime and GetTime() or 0 }
    B.showGuard = g
    if not C_Timer then return end
    local function Elapsed() return math.floor(((GetTime and GetTime() or 0) - g.t0) * 10 + 0.5) / 10 end
    local Check
    local function Again(sec) C_Timer.After(sec, function() Check() end) end
    Check = function()
        if B.showGuard ~= g or B.showToken ~= token or not AHOpen() then return end
        -- Schritt 0 (ab 0.21.1, Protokoll von KarloDerBaer: Ergebnisse waren da, Blizzards Liste blieb trotzdem alt):
        -- nach dem Umschalten einmal wie Blizzards Knopf "Neu laden" - Liste leeren und neu abfragen
        if not g.forced then
            local ah = AHApi()
            if (ah.IsThrottledMessageSystemReady and not ah.IsThrottledMessageSystemReady()) or B.QueryBusy() then
                g.waits = (g.waits or 0) + 1
                if g.waits <= 20 then Again(0.3) end
                return
            end
            g.forced, g.answered = true, false
            local ok = B.ReloadBlizzardList(itemKey, commodity)
            B.ShowLog(("%s gezeigt, neu geladen nach %s s (%s)"):format(tostring(g.itemID), Elapsed(), tostring(ok)))
            Again(B.GUARD_WAIT)
            return
        end
        local state, n = B.CheckShown(g)
        if state == "ok" then
            B.showGuard = nil
            B.ShowLog(("%s ok nach %s s (%s Ergebnisse, %d Versuche)"):format(tostring(g.itemID), Elapsed(), tostring(n), g.tries))
            return
        end
        if g.tries >= B.GUARD_TRIES then
            B.showGuard = nil
            B.ShowLog(("%s aufgegeben nach %s s: %s"):format(tostring(g.itemID), Elapsed(), state))
            return
        end
        local ah = AHApi()
        if (ah.IsThrottledMessageSystemReady and not ah.IsThrottledMessageSystemReady()) or B.QueryBusy() then
            g.waits = (g.waits or 0) + 1
            if g.waits <= 20 then Again(0.3) end
            return
        end
        g.tries = g.tries + 1
        local how, ok = "?", false
        if g.tries == 1 then
            how = "neu laden"
            ok = B.ReloadBlizzardList(itemKey, commodity)
        elseif g.tries == 2 then
            local order = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0
            how = "eigene Suche"
            if ah.SendSearchQuery then ok = pcall(ah.SendSearchQuery, itemKey, { { sortOrder = order, reverseSort = false } }, true) end
        else
            how = "nochmal zeigen"
            local f = rawget(_G, "AuctionHouseFrame")
            ok = Call(f, "SelectBrowseResult", { itemKey = itemKey, minPrice = (row and (row.cheapest or row.offer)) or 0,
                totalQuantity = (row and (row.qty or row.hits)) or 0, containsOwnerItem = row and row.own and true or false })
        end
        B.guardRefreshes = (B.guardRefreshes or 0) + 1
        B.ShowLog(("%s %s nach %s s: Versuch %d %s (%s)"):format(tostring(g.itemID), state, Elapsed(), g.tries, how, tostring(ok)))
        Again(1.2)
    end
    g.check = Check
    Again(B.GUARD_FORCE)
end

-- Ergebnis-Ereignis: gehoert es zum gezeigten Gegenstand, gleich nachsehen (statt auf die Wartezeit)
function B.GuardSeen(commodity, arg)
    local g = B.showGuard
    local id = commodity and arg or (type(arg) == "table" and arg.itemID)
    if g and id == g.itemID then
        g.answered = true
        if C_Timer and g.check then C_Timer.After(0.1, g.check) end
    end
end

-- Spiel hat Daten zu einem Gegenstand nachgeladen: wartende Anzeige gleich nachholen
function B.OnItemKeyInfo()
    local w = B.showWait
    if w and w.token == B.showToken then B.ShowInAH(w.row, w.tries) end
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
        local _, _, total = ns.Keep.Counts(ns.Data.ItemID(row.key), nil)
        qty = math.min(qty, math.max(0, row.wish - (total or 0)))
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
        B.buying = nil
        B.UpdateView()
    end)
end

function B.OnBought(ok)
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
    if not B.view then return end
    local names = {}
    for i, l in ipairs(B.Lists()) do names[#names + 1] = { index = i, name = l.name, count = 0 } end
    for _, n in ipairs(names) do for _ in pairs(B.Lists()[n.index].items) do n.count = n.count + 1 end end
    B.listList:SetData(names)
    local _, ci = B.CurrentList()
    for _, n in ipairs(names) do if n.index == ci then B.listList:Select(n) end end
    B.itemList:SetData(B.ListRows())
    if B.allChars then
        local has = ns.Keep.Ledger() ~= nil
        B.allChars:SetShown(has); B.allChars.label:SetShown(has)
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
    B.filling = true
    B.nameBox:SetText(cur and cur.name or "")
    B.pctBox:SetText(cur and tostring(cur.pct or 0) or "")
    B.filling = false
    if cur then B.deleteButton:Enable() else B.deleteButton:Disable() end
    -- Gewaehlter Gegenstand
    local row = B.selected
    local plan = B.Plan(row)
    local text
    if not row then
        text = GREY .. L.BUY_PICK .. "|r"
    elseif B.pending and B.pending.key == row.key then
        text = W.Colored(row.name, row.quality) .. "  " .. GREY .. L.SELL_LIVE_WAIT .. "|r"
    elseif plan and plan.qty > 0 then
        text = W.Colored(row.name, row.quality) .. "  " .. GREEN .. L.BUY_PLAN:format(plan.qty, Money(plan.cost)) .. "|r"
    elseif plan then
        text = W.Colored(row.name, row.quality) .. "  " .. ORANGE .. L.BUY_NOTHING .. "|r"
    else
        text = W.Colored(row.name, row.quality)
    end
    B.selText:SetText(text)
    if row then
        B.itemBar:Show()
        B.filling = true
        local it = cur and cur.items[row.key]
        B.wishBox:SetText(it and it.wish and tostring(it.wish) or "")
        B.maxBox:SetText(it and it.max and tostring(it.max / 10000) or "")
        B.filling = false
    else
        B.itemBar:Hide()
    end
    local can = AHOpen() and plan and plan.qty > 0 and not B.buying
    if can then B.buyButton:Enable() else B.buyButton:Disable() end
    if AHOpen() and not B.run and cur and next(cur.items) then B.searchButton:Enable() else B.searchButton:Disable() end
    if B.run then B.listStatus:SetText(GREY .. L.BUY_SEARCHING:format(B.run.i, #B.run.rows) .. "|r")
    else B.listStatus:SetText("") end
end

---------------------------------------------------------------------------
-- Aufbau
---------------------------------------------------------------------------
local function Btn(parent, text, w, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", fn)
    return b
end

local function Box(parent, w, numeric)
    local b = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    b:SetSize(w, 20)
    b:SetAutoFocus(false)
    if numeric and b.SetNumeric then b:SetNumeric(true) end
    b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return b
end

local function Label(parent, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetText(text)
    return fs
end

local function NameCol(width)
    return { key = "name", title = L.COL_ITEM, width = width,
        format = function(v, r)
            return "|T" .. tostring(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":16:16:0:0|t " .. W.Colored(v, r.quality)
        end,
        sortValue = function(r) return W.Lower(r.name) end }
end

function B.Build(c)
    B.view = c
    B.mode = "lists"
    local total = W.WIDTH - 24

    -- Einkaufslisten
    local lv = CreateFrame("Frame", nil, c)
    lv:SetPoint("TOPLEFT", 0, 0)
    lv:SetPoint("BOTTOMRIGHT", 0, 0)
    B.listsView = lv
    local leftW = 170
    local left = W.Inset(lv)
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(leftW)
    B.listList = Peon.NewList(left, {
        columns = { { key = "name", title = L.BUY_LISTS, width = leftW - 8 - 24 - 30 },
                    { key = "count", title = "", width = 30, align = "RIGHT" } },
        rows = 9, sortKey = nil,
        onClick = function(list, r) mod.char.listSel = r.index; B.selected = nil; B.Refresh() end,
        emptyText = L.BUY_NO_LISTS,
    })
    B.listList.frame:SetPoint("TOPLEFT", 4, -4)
    local y = -(B.listList:GetHeight() + 10)
    B.newButton = Btn(left, L.BUY_NEW, 74, function() B.NewList(); B.Refresh() end)
    B.newButton:SetPoint("TOPLEFT", 6, y)
    B.deleteButton = Btn(left, L.BUY_DELETE, 74, function()
        local _, i = B.CurrentList()
        B.DeleteList(i); B.selected = nil; B.Refresh()
    end)
    B.deleteButton:SetPoint("LEFT", B.newButton, "RIGHT", 6, 0)
    local nl = Label(left, L.BUY_NAME); nl:SetPoint("TOPLEFT", 8, y - 34)
    B.nameBox = Box(left, leftW - 24)
    B.nameBox:SetPoint("TOPLEFT", 12, y - 48)
    B.nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    B.nameBox:SetScript("OnEditFocusLost", function(self)
        local cur = B.CurrentList()
        if cur and not B.filling and (self:GetText() or "") ~= "" and cur.name ~= self:GetText() then cur.name = self:GetText(); B.Touch(cur); B.Refresh() end
    end)
    -- Umschalter "Vorrat aller Charaktere" (ab 0.24, gleiche Einstellung wie im Reiter Behalten)
    local cb = CreateFrame("CheckButton", nil, left, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("BOTTOMLEFT", 4, 6)
    local cbl = left:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cbl:SetWidth(leftW - 34)
    cbl:SetJustifyH("LEFT")
    cbl:SetText(L.KEEP_ALL_CHARS)
    cb.label = cbl
    cb:SetScript("OnClick", function(self)
        mod.db.keepAllChars = self:GetChecked() and true or false
        mod:Call("Einkaufsliste", B.Refresh)
    end)
    cb:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.KEEP_ALL_CHARS, 1, 1, 1)
        GameTooltip:AddLine(L.BUY_ALL_CHARS_HINT, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    B.allChars = cb
    local pl = Label(left, L.BUY_MAXPRICE); pl:SetPoint("TOPLEFT", 8, y - 76)
    B.pctBox = Box(left, 36, true)
    B.pctBox:SetPoint("TOPLEFT", 12, y - 90)
    local pl2 = left:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    pl2:SetPoint("LEFT", B.pctBox, "RIGHT", 6, 0)
    pl2:SetText(L.BUY_PCT_UNDER)
    local function SetPct(self)
        local cur = B.CurrentList()
        if cur and not B.filling then
            local v = math.max(0, math.min(90, tonumber(self:GetText() or "") or 0))
            if v ~= cur.pct then cur.pct = v; B.Touch(cur) end
            B.Refresh()
        end
    end
    B.pctBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    B.pctBox:SetScript("OnEditFocusLost", SetPct)

    local right = W.Inset(lv)
    right:SetPoint("TOPLEFT", leftW + 8, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    local rw = total - leftW - 8 - 8 - 24
    local fixed = 84 + 50 + 50 + 84 + 50
    B.itemList = Peon.NewList(right, {
        columns = {
            NameCol(rw - fixed),
            { key = "limit", title = L.BUY_COL_LIMIT, width = 84, align = "RIGHT", format = function(v) return v and Money(v) or "–" end },
            { key = "wish", title = L.BUY_COL_WISH, width = 50, align = "RIGHT", format = function(v) return v and tostring(v) or "–" end },
            { key = "stock", title = L.BUY_COL_STOCK, width = 50, align = "RIGHT",
              format = function(v, r)
                  if not v then return "–" end
                  if r.wish and v >= r.wish then return GREY .. v .. "|r" end   -- Wunschmenge erreicht
                  return tostring(v)
              end },
            { key = "cheapest", title = L.BUY_COL_CHEAPEST, width = 84, align = "RIGHT",
              format = function(v, r) if not v then return "–" end return (r.live and "" or GREY) .. Money(v) .. (r.live and "" or "|r") end },
            { key = "hits", title = L.BUY_COL_HITS, width = 50, align = "RIGHT",
              format = function(v) return (v and v > 0) and (GREEN .. v .. "|r") or "–" end },
        },
        rows = 12, rowHeight = 19, sortKey = "name",
        onClick = function(list, r) B.Select(r) end,
        onEnter = function(list, r, row) W.ShowItemTooltip(row, r.key) end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
        emptyText = L.BUY_LIST_EMPTY,
    })
    B.itemList.frame:SetPoint("TOPLEFT", 4, -4)
    y = -(B.itemList:GetHeight() + 10)
    local al = Label(right, L.BUY_ADD); al:SetPoint("TOPLEFT", 10, y - 4)
    B.searchBox = Box(right, 180)
    B.searchBox:SetPoint("LEFT", al, "RIGHT", 10, 0)
    B.searchBox:SetScript("OnEnterPressed", function(self)
        if B.AddByName(self:GetText()) then self:SetText("") end
        self:ClearFocus()
    end)
    B.selText = right:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    B.selText:SetPoint("TOPLEFT", 10, y - 30)
    B.selText:SetJustifyH("LEFT")
    local bar = CreateFrame("Frame", nil, right)
    bar:SetSize(330, 24)
    bar:SetPoint("TOPRIGHT", -8, y - 26)
    B.itemBar = bar
    B.removeButton = Btn(bar, L.BUY_REMOVE, 90, function()
        local cur = B.CurrentList()
        if cur and B.selected then B.RemoveItem(cur, B.selected.key); B.selected = nil; B.Refresh() end
    end)
    B.removeButton:SetPoint("RIGHT", 0, 0)
    B.wishBox = Box(bar, 50, true)
    B.wishBox:SetPoint("RIGHT", B.removeButton, "LEFT", -10, 0)
    local function SetWish(self)
        local cur = B.CurrentList()
        if B.filling or not cur or not B.selected then return end
        local it = cur.items[B.selected.key]
        if it then
            local v = tonumber(self:GetText() or "")
            if v and v < 1 then v = nil end
            if v ~= it.wish then it.wish = v; B.Touch(it) end
            B.Refresh()
        end
    end
    B.wishBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    B.wishBox:SetScript("OnEditFocusLost", SetWish)
    local wl = Label(bar, L.BUY_WISH); wl:SetPoint("RIGHT", B.wishBox, "LEFT", -8, 0)
    -- Eigener Hoechstpreis in Gold (ab 0.34), leer = Wert der Liste
    B.maxBox = Box(bar, 50)
    B.maxBox:SetPoint("RIGHT", wl, "LEFT", -12, 0)
    local function SetMax(self)
        local cur = B.CurrentList()
        if B.filling or not cur or not B.selected then return end
        local it = cur.items[B.selected.key]
        if it then
            local gold = tonumber((tostring(self:GetText() or ""):gsub(",", ".")))
            local v = (gold and gold > 0) and math.floor(gold * 10000 + 0.5) or nil
            if v ~= it.max then it.max = v; B.Touch(it) end
            B.Refresh()
        end
    end
    B.maxBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    B.maxBox:SetScript("OnEditFocusLost", SetMax)
    local ml = Label(bar, L.BUY_MAX); ml:SetPoint("RIGHT", B.maxBox, "LEFT", -8, 0)
    B.listStatus = right:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    B.listStatus:SetPoint("BOTTOMLEFT", 10, 14)
    B.buyButton = Btn(right, L.BUY_BUY, 110, function() mod:Call("Einkaufen", B.Buy) end)
    B.buyButton:SetPoint("BOTTOMRIGHT", -8, 8)
    B.searchButton = Btn(right, L.BUY_SEARCH, 140, function() mod:Call("Einkaufen", B.SearchList) end)
    B.searchButton:SetPoint("RIGHT", B.buyButton, "LEFT", -6, 0)

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
    mod:RegisterEvent("AUCTION_HOUSE_CLOSED", function() B.run, B.pending, B.buying, B.showWait, B.showGuard, B.keyJob = nil, nil, nil, nil, nil, nil end)
    pcall(mod.RegisterEvent, mod, "ITEM_KEY_ITEM_INFO_RECEIVED", function() B.OnItemKeyInfo() end)
    -- ab 0.28: Suchschluessel der Varianten aus jedem Suchergebnis lernen (auch beim Stoebern im Blizzard-Fenster)
    mod:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey) mod:Call("Schluessel", B.LearnFromResults, itemKey) end)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function() B.OnBrowseResults() end)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function() B.OnBrowseResults() end)
    mod:On("SCAN_DONE", function() if W.IsOpen() and W.current == "buy" then B.Refresh() end end)
end

W.pages.buy = {
    build = B.Build,
    refresh = B.Refresh,
    -- Reiter gewaehlt (ab 0.20): Blizzard-Fenster passend umschalten
    enter = function()
        if B.selected then B.ShowInAH(B.selected) else W.SetAHMode("Buy") end
    end,
}
