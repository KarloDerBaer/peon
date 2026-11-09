-- Peon_Broker - Sell.lua
-- Reiter "Verkaufen" im Broker-Fenster (Entwurf: Peon_Broker_Verkaufen.md, Rechenmodell Kapitel 4).
-- Ab 0.10: Der gewaehlte Gegenstand wird ins Verkaufsfenster des Auktionshauses gelegt und Brokers
-- Werte (Preis, Menge, Dauer) werden dort eingetragen; eingestellt wird mit den Werten, die dort stehen.
-- Links schmal: Gegenstand, Vorschlag, Erloes, Hinweise, Knoepfe (nicht verkaufen, einstellen);
-- rechts die Taschen mit Symbol, Wert und Trend. Rechtsklick = nicht verkaufen (je Charakter).
-- Eingestellt wird nur per Klick, nie automatisch und nie im Kampf.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local S = {}
ns.Sell = S

S.POST_TIMEOUT = 10      -- Sekunden bis "keine Rueckmeldung"
S.POST_TIMEOUT_AH = 20   -- ueber das Blizzard-Fenster (es kann selbst nachfragen)
S.FILL_DELAYS = { 0.3, 1 } -- Sekunden: Werte nach der Suche des Auktionshauses nochmal eintragen
S.POLL = { 0.5, 1.5, 3 } -- Sekunden: nachsehen, ob Live-Ergebnisse da sind
S.LIVE_TIMEOUT = 6       -- Sekunden bis "keine Antwort"

local GREY, ORANGE, RED, GREEN = "|cff999999", "|cffff9933", "|cffff4040", "|cff60e060"

local function Money(v) return ns.Tooltip.Money(v) end
local function AH() return rawget(_G, "C_AuctionHouse") end
local function AHOpen() return ns.Scan.ahOpen and AH() ~= nil end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

---------------------------------------------------------------------------
-- Taschen
---------------------------------------------------------------------------
local function BagRange()
    local last = tonumber(rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS")) or tonumber(rawget(_G, "NUM_BAG_SLOTS")) or 4
    return 0, last
end

local function Location(bag, slot)
    if ItemLocation and ItemLocation.CreateFromBagAndSlot then
        return ItemLocation:CreateFromBagAndSlot(bag, slot)
    end
    return nil
end

-- Alle verkaufbaren Gegenstaende, zusammengefasst nach Schluessel
-- light (ab 0.28): ohne Bewertung (nur Plaetze, Mengen, Behalten) - z. B. beim Einstellen
function S.ScanBags(light)
    local C = rawget(_G, "C_Container")
    if not C then return {} end
    local D, ah, open = ns.Data, AH(), AHOpen()
    local byKey, list = {}, {}
    local first, last = BagRange()
    for bag = first, last do
        local ok, slots = pcall(C.GetContainerNumSlots, bag)
        for slot = 1, (ok and tonumber(slots) or 0) do
            local ok2, info = pcall(C.GetContainerItemInfo, bag, slot)
            local link = ok2 and type(info) == "table" and info.hyperlink
            -- gesperrte Plaetze (z. B. gerade eingestellt) ueberspringen: sonst landet ein Gegenstand im
            -- Verkaufsfenster, der gleich verschwindet (Fehler in Blizzards ItemSellFrame, 30.09.2026)
            if link and not Peon.IsSecret(link) and not info.isLocked then
                local key = D.KeyFromLink(link)
                local loc = Location(bag, slot)
                local sellable = not info.isBound
                if open and loc and ah.IsSellItemValid then
                    local okv, valid = pcall(ah.IsSellItemValid, loc, false)
                    sellable = okv and valid == true
                end
                if key ~= nil and sellable then
                    local it = byKey[key]
                    if not it then
                        it = { key = key, id = info.itemID or D.ItemID(key), link = link, count = 0, locs = {},
                               name = link:match("%[(.-)%]") or tostring(key), quality = info.quality,
                               icon = info.iconFileID }
                        byKey[key] = it
                        list[#list + 1] = it
                    end
                    it.count = it.count + (tonumber(info.stackCount) or 1)
                    it.locs[#it.locs + 1] = { loc = loc, bag = bag, slot = slot }
                end
            end
        end
    end
    -- Behalten (je Charakter) und Wert je Gegenstand (wie Zeile 1 im Tooltip, fuer die verkaufbare Menge)
    local K = ns.Keep
    for _, it in ipairs(list) do
        it.bagCount = it.count
        it.keepEntry = K and K.Get(it.key) or nil
        it.keep = it.keepEntry ~= nil and it.keepEntry.n == nil          -- alles behalten
        it.keepN = it.keepEntry and it.keepEntry.n or nil
        if it.keepN then it.count = K.Sellable(it.key, it.id, it.bagCount) end
        local e = D.Lookup(it.key)
        it.e = e
        it.hp = ns.VendorPrice(it.id)
        it.hw = it.hp and it.hp * math.max(it.count, 1) or nil
        if not light then
            local v   -- ab 0.28 nur einmal bewertet (vorher zweimal fuer den Trend)
            if type(e) == "table" and e.m then
                v = D.Evaluate(e, it.key, math.max(it.count, 1), it.hp, mod.db)
                it.erl, it.ah, it.state = v.erl, v.ah, v.state
                it.value = v.ah and v.erl or (v.hw or 0)
            else
                it.ah = not (it.hw and it.hw > 0)     -- ohne Vergleich: nicht als "Haendler besser" einstufen
                it.value = it.hw
            end
            it.worth = it.ah
            -- Trend wie Zeile 1 im Tooltip: Erloes gegenueber dem vorherigen Scan
            it.trend, it.trendText = nil, nil
            if v and e.pm then
                it.trend = ns.Tooltip.TrendLevel(v.erl, v.erlVor)
                it.trendText = ns.Tooltip.Trend(v.erl, v.erlVor)
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Live-Angebote
---------------------------------------------------------------------------
local function AddRow(rows, price, qty, own)
    if not Num(price) or not Num(qty) or price <= 0 or qty <= 0 then return end
    for _, r in ipairs(rows) do
        if r.price == price then r.qty = r.qty + qty; r.own = r.own + (own or 0); return end
    end
    rows[#rows + 1] = { price = price, qty = qty, own = own or 0 }
end

-- Hat das Spiel alle Ergebnisse geliefert? Das Auktionshaus liefert grosse Ergebnislisten in Teilen
-- (wie Blizzards Liste: HasFull... / RequestMore...). Ohne die Funktion gilt: vollstaendig.
-- Gefunden 02.10.2026: Broker las bis 0.19 nur den ersten Teil -> Median und Menge zu niedrig.
function S.IsFull(commodity, arg)
    local ah = AH()
    local fn = ah and (commodity and ah.HasFullCommoditySearchResults or ah.HasFullItemSearchResults)
    if not fn then return true end
    local ok, full = pcall(fn, arg)
    if not ok or full == nil or Peon.IsSecret(full) then return true end
    return full and true or false
end

-- rows.partial = true, wenn das Spiel nur einen Teil geliefert hat (die guenstigsten Angebote sind
-- trotzdem vollstaendig, weil nach Preis sortiert abgefragt wird; Median und Menge sind es nicht)
-- Ergebnisse eines anderen Gegenstands werden uebersprungen (ab 0.21.1; rows.foreign = Anzahl):
-- Verdacht, dass das Spiel zeitweise die Ergebnisse der vorherigen Suche liefert
function S.ReadCommodity(itemID)
    local ah = AH()
    local rows = { offers = {}, commodity = true }   -- offers: einzelne Angebote fuer den Absatz (ab 0.23)
    local ok, n = pcall(ah.GetNumCommoditySearchResults, itemID)
    for i = 1, (ok and tonumber(n) or 0) do
        local okr, r = pcall(ah.GetCommoditySearchResultInfo, itemID, i)
        if okr and ns.Probe and ns.Probe.Field then ns.Probe.Field("commodity", r) end
        if okr and type(r) == "table" and Num(r.itemID) and r.itemID ~= itemID then
            rows.foreign = (rows.foreign or 0) + 1
        elseif okr and type(r) == "table" then
            local own = 0
            if r.containsOwnerItem then own = Num(r.numOwnerItems) and r.numOwnerItems or r.quantity end
            AddRow(rows, r.unitPrice, r.quantity, own)
            if Num(r.auctionID) then
                rows.offers[#rows.offers + 1] = { id = r.auctionID, q = r.quantity, p = r.unitPrice, secs = r.timeLeftSeconds, band = r.timeLeft }
            end
        end
    end
    table.sort(rows, function(a, b) return a.price < b.price end)
    if not S.IsFull(true, itemID) then rows.partial = true end
    return rows
end

-- Itemnummer aus einem Link (ab 0.21.1)
function S.LinkID(link)
    if type(link) ~= "string" or Peon.IsSecret(link) then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- Gehoert ein Ergebnis zu einem anderen Gegenstand? (Link oder itemKey des Ergebnisses)
function S.Foreign(r, itemID)
    if type(itemID) ~= "number" then return false end
    local id = S.LinkID(r.itemLink)
    if not id and type(r.itemKey) == "table" and Num(r.itemKey.itemID) then id = r.itemKey.itemID end
    return id ~= nil and id ~= itemID
end

-- key (ab 0.28): bei Varianten nur Ergebnisse genau dieser Variante (voller Name im Link)
function S.ReadItems(itemKey, key)
    local ah = AH()
    local rows = {}
    local want = type(itemKey) == "table" and itemKey.itemID or nil
    local variant = ns.Data.IsVariantKey(key)
    local ok, n = pcall(ah.GetNumItemSearchResults, itemKey)
    for i = 1, (ok and tonumber(n) or 0) do
        local okr, r = pcall(ah.GetItemSearchResultInfo, itemKey, i)
        if okr and ns.Probe and ns.Probe.Field then ns.Probe.Field("item", r) end
        if okr and type(r) == "table" and S.Foreign(r, want) then
            rows.foreign = (rows.foreign or 0) + 1
        elseif okr and type(r) == "table" and variant and r.itemLink and ns.Data.KeyFromLink(r.itemLink) ~= key then
            rows.other = (rows.other or 0) + 1   -- andere Variante (ab 0.28)
        elseif okr and type(r) == "table" and Num(r.buyoutAmount) then
            if variant and r.itemLink then rows.link = rows.link or r.itemLink end
            local qty = Num(r.quantity) and r.quantity > 0 and r.quantity or 1
            -- buyoutAmount ist schon der Preis je Stueck; quantity = Anzahl gleicher Angebote (im Spiel getestet, 0.8.1)
            AddRow(rows, r.buyoutAmount, qty, r.containsOwnerItem and qty or 0)
        end
    end
    table.sort(rows, function(a, b) return a.price < b.price end)
    if not S.IsFull(false, itemKey) then rows.partial = true end
    return rows
end

local function KeyText(k)
    if type(k) ~= "table" then return tostring(k) end
    return ("%s/%s/%s/%s"):format(tostring(k.itemID), tostring(k.itemLevel), tostring(k.itemSuffix), tostring(k.battlePetSpeciesID))
end
S.KeyText = KeyText

-- Live-Abfrage. Seit 0.9.3 die normale Suche (SendSearchQuery) mit dem Schluessel des Gegenstands,
-- wie sie das Auktionshaus beim Anklicken nutzt. Die Verkaufs-Suche (SendSellSearchQuery) ist nur
-- fuer Ausruestungsvarianten gedacht und lieferte in Forever nichts (Debug-Logs 30.09.2026).
function S.Query(it)
    local ah = AH()
    local send = ah and (ah.SendSearchQuery or ah.SendSellSearchQuery)
    if not it or not AHOpen() or not send or not ah.GetItemKeyFromItem then return false end
    local loc = it.locs[1] and it.locs[1].loc
    if not loc then return false end
    local ok, itemKey = pcall(ah.GetItemKeyFromItem, loc)
    if not ok or type(itemKey) ~= "table" then return false end
    local itemID = itemKey.itemID or it.id
    if ns.Data.IsVariantKey(it.key) and ns.Buy and ns.Buy.LearnKey then ns.Buy.LearnKey(it.key, itemKey) end   -- ab 0.28
    if ah.IsThrottledMessageSystemReady and not ah.IsThrottledMessageSystemReady() then
        S.retry = (S.retry or 0) + 1
        if S.retry <= 10 and C_Timer then
            C_Timer.After(0.5, function() if S.item == it then S.Query(it) end end)
        end
        return false
    end
    S.retry = 0
    local order = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0
    -- Weitere Schluessel zum Nachsehen (falls das Spiel die Ergebnisse anders ablegt)
    local keys = { itemKey, { itemID = itemID, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 } }
    local p = { key = it.key, itemID = itemID, itemKey = itemKey, keys = keys, commodity = ns.Data.IsCommodity(it.key) }
    S.pending = p
    S.liveState = "wait"
    local okq, err = pcall(send, itemKey, { { sortOrder = order, reverseSort = false } }, true)
    mod:Dbg(("Live-Abfrage %s (itemKey %s, Massenware %s, bereit danach %s): %s"):format(tostring(it.key), KeyText(itemKey),
        tostring(p.commodity), tostring(ah.IsThrottledMessageSystemReady and ah.IsThrottledMessageSystemReady()),
        okq and "gesendet" or ("Fehler " .. tostring(err))))
    if not okq then S.pending, S.liveState = nil, "error" end
    S.UpdatePanel()
    -- Nicht jede Abfrage loest ein Ereignis aus (z. B. wenn das Spiel die Ergebnisse schon hat):
    -- deshalb zusaetzlich nachsehen und nach S.LIVE_TIMEOUT aufgeben.
    if okq and C_Timer then
        for _, d in ipairs(S.POLL) do C_Timer.After(d, function() S.Poll(p) end) end
        C_Timer.After(S.LIVE_TIMEOUT, function()
            if S.pending == p and p.partialRows and S.item and S.item.key == p.key then
                S.Finish(p, p.partialRows)   -- ab 0.28: Rest kam nicht - mit dem Teil weiter
            elseif S.pending == p then
                S.pending, S.liveState = nil, "timeout"
                mod:Dbg("Live-Abfrage ohne Antwort: " .. tostring(p.key))
                S.UpdatePanel()
            end
        end)
    end
    return okq
end

-- Rest einer grossen Ergebnisliste beim Spiel anfordern (ab 0.28, wie Blizzards Liste beim Blaettern).
-- Rueckgabe: "wait" (angefordert, Ereignis ...ADDED folgt), "full" (Spiel hat schon alles) oder nil (geht nicht)
S.MORE_MAX = 5
function S.RequestMore(p, commodity)
    local ah = AH()
    local fn = ah and (commodity and ah.RequestMoreCommoditySearchResults or ah.RequestMoreItemSearchResults)
    if type(fn) ~= "function" then return nil end
    local ok, full = pcall(fn, commodity and p.itemID or p.itemKey)
    if not ok then return nil end
    if full == true and not Peon.IsSecret(full) then return "full" end
    return "wait"
end

-- Ergebnisse uebernehmen (commodity = aus welcher Liste gelesen wird)
function S.TakeResults(p, commodity)
    if not S.item or S.item.key ~= p.key then S.pending = nil; return end
    local rows = commodity and S.ReadCommodity(p.itemID) or S.ReadItems(p.itemKey, p.key)
    if #rows == 0 and (rows.partial or rows.foreign) then return end   -- Spiel laedt noch: weiter warten (ab 0.20.1)
    -- ab 0.28: nur ein Teil geliefert - Rest nachladen, damit Median und Menge stimmen; der Teil gilt, falls nichts mehr kommt
    if rows.partial and not rows.foreign and (p.more or 0) < S.MORE_MAX then
        p.more = (p.more or 0) + 1
        local r = S.RequestMore(p, commodity)
        if r == "wait" then
            p.partialRows, p.partialCommodity = rows, commodity
            mod:Dbg(("Live-Ergebnis %s: Teil (%d Stufen), Rest angefordert"):format(tostring(p.key), #rows))
            return
        elseif r == "full" then
            local again = commodity and S.ReadCommodity(p.itemID) or S.ReadItems(p.itemKey, p.key)
            if #again > 0 then rows = again end
        end
    end
    S.Finish(p, rows)
end

function S.Finish(p, rows)
    S.pending = nil
    S.live = rows
    S.liveAt = time()
    -- aktueller Stand in die Datenbank (ab 0.15); ab 0.28 auch Varianten (Ergebnisse sind nach Variante gefiltert)
    ns.Data.ApplyLive(p.key, S.live, S.liveAt)
    S.liveState = "done"
    mod:Dbg(("Live-Ergebnis %s: %d Preisstufen"):format(tostring(p.key), #S.live))
    S.Suggest(true)
end

-- Ereignis vom Spiel; die Warenart kommt aus dem Ereignis, nicht aus unserer Vermutung
local function OnResults(commodity, arg)
    local p = S.pending
    local id = commodity and arg or (type(arg) == "table" and arg.itemID)
    mod:Dbg(("Ereignis %s fuer itemID %s (erwartet %s)"):format(commodity and "Massenware" or "Gegenstand",
        tostring(id), p and tostring(p.itemID) or "-"))
    if not p or id ~= p.itemID then return end
    if not commodity then p.itemKey = type(arg) == "table" and arg or p.itemKey end
    S.TakeResults(p, commodity)
end

-- Nachsehen, ob das Spiel schon Ergebnisse hat
function S.Poll(p)
    if S.pending ~= p then return end
    local ah = AH()
    local okc, nc = pcall(ah.GetNumCommoditySearchResults, p.itemID)
    local parts = { ("Massenware %s/%s"):format(tostring(okc), tostring(nc)) }
    if okc and Num(nc) and nc > 0 then mod:Dbg("Nachsehen " .. tostring(p.key) .. ": " .. parts[1]); S.TakeResults(p, true); return end
    for _, k in ipairs(p.keys or { p.itemKey }) do
        local oki, ni = pcall(ah.GetNumItemSearchResults, k)
        parts[#parts + 1] = ("Gegenstand %s: %s/%s"):format(KeyText(k), tostring(oki), tostring(ni))
        if oki and Num(ni) and ni > 0 then
            mod:Dbg("Nachsehen " .. tostring(p.key) .. ": " .. table.concat(parts, ", "))
            p.itemKey = k
            S.TakeResults(p, false)
            return
        end
    end
    local okb, br = pcall(ah.GetBrowseResults)
    parts[#parts + 1] = ("Browse %s/%s"):format(tostring(okb), type(br) == "table" and #br or tostring(br))
    mod:Dbg("Nachsehen " .. tostring(p.key) .. ": " .. table.concat(parts, ", "))
end

---------------------------------------------------------------------------
-- Vorschlag, Menge, Laufzeit
---------------------------------------------------------------------------
local function Memory(key)
    local acc = mod.acc
    if type(acc.sellMem) ~= "table" then acc.sellMem = {} end
    return acc.sellMem[key]
end

local function SetMemory(key, field, value)
    Memory(key)
    local m = mod.acc.sellMem[key]
    if not m then m = {}; mod.acc.sellMem[key] = m end
    m[field] = value
end

function S.Available(it)
    if not it then return 0 end
    local ah = AH()
    if AHOpen() and ah.GetAvailablePostCount and it.locs[1] and it.locs[1].loc then
        local ok, n = pcall(ah.GetAvailablePostCount, it.locs[1].loc)
        if ok and Num(n) and n > 0 then return n end
    end
    return it.count
end

---------------------------------------------------------------------------
-- Blizzard-Verkaufsfenster (ab 0.10): Gegenstand hineinlegen, Werte eintragen und auslesen.
-- Feldnamen aus Blizzard_AuctionHouseSellFrame.lua: PriceInput (SetAmount/GetAmount),
-- QuantityInput (SetQuantity/GetQuantity), Duration (SetDuration/GetDuration), PostButton.
---------------------------------------------------------------------------
local function BlizzAH()
    local f = rawget(_G, "AuctionHouseFrame")
    if type(f) == "table" then return f end
    return nil
end

function S.SellFrameFor(commodity)
    local f = BlizzAH()
    if not f then return nil end
    local sf = commodity and f.CommoditiesSellFrame or f.ItemSellFrame
    if type(sf) == "table" then return sf end
    return nil
end

-- Gegenstand ins Verkaufsfenster des Auktionshauses legen (wie Rechtsklick in den Taschen)
function S.PutIntoAH(it)
    S.inAH = nil
    if not AHOpen() or not it or not it.locs[1] or not it.locs[1].loc then return false end
    if not ns.AHTouch() then return false end   -- ab 0.41: "Blizzard pur"
    local f = BlizzAH()
    if not f then return false end
    local loc = it.locs[1].loc
    local ok = false
    if type(f.SetPostItem) == "function" then ok = pcall(f.SetPostItem, f, loc) end
    if not ok then
        local commodity = ns.Data.IsCommodity(it.key)
        local sf = S.SellFrameFor(commodity)
        if sf and type(sf.SetItem) == "function" then
            local modes = rawget(_G, "AuctionHouseFrameDisplayMode")
            if type(f.SetDisplayMode) == "function" and type(modes) == "table" then
                pcall(f.SetDisplayMode, f, commodity and modes.CommoditiesSell or modes.ItemSell)
            end
            ok = pcall(sf.SetItem, sf, loc)
        end
    end
    if ok then S.inAH = it.key end
    mod:Dbg("Ins Auktionshaus gelegt: " .. tostring(it.key) .. " " .. tostring(ok))
    return ok
end

-- Gegenstand aus dem Verkaufsfenster nehmen (er ist nicht mehr in den Taschen)
function S.ClearAH()
    if not S.inAH or not AHOpen() then return end
    for _, c in ipairs({ true, false }) do
        local sf = S.SellFrameFor(c)
        if sf and type(sf.SetItem) == "function" then pcall(sf.SetItem, sf, nil) end
    end
    S.inAH = nil
end

-- Das Blizzard-Verkaufsfenster, in dem unser Gegenstand liegt
function S.ActiveSellFrame()
    if not S.item or S.inAH ~= S.item.key or not AHOpen() then return nil end
    local commodity = ns.Data.IsCommodity(S.item.key)
    for _, c in ipairs({ commodity, not commodity }) do
        local sf = S.SellFrameFor(c)
        if sf and (not sf.IsShown or sf:IsShown()) then return sf end
    end
    return nil
end

local function Call(obj, name, ...)
    if type(obj) ~= "table" or type(obj[name]) ~= "function" then return false end
    return pcall(obj[name], obj, ...)
end

-- Werte von Broker eintragen (Preis, Menge, Dauer)
function S.FillAH()
    local sf = S.ActiveSellFrame()
    if not sf then S.filled = false; return false end
    local okP = S.price and Call(sf.PriceInput, "SetAmount", S.price)
    local okQ = S.qtyPlan and Call(sf.QuantityInput, "SetQuantity", S.qtyPlan)
    local okD = S.duration and Call(sf.Duration, "SetDuration", ns.Data.DUR_INDEX[S.duration])
    for _, fn in ipairs({ "UpdatePostState", "UpdateDeposit", "UpdateTotalPrice" }) do Call(sf, fn) end
    S.filled = okP and true or false
    mod:Dbg(("Werte eingetragen: Preis %s, Menge %s, Dauer %s"):format(tostring(okP), tostring(okQ), tostring(okD)))
    return S.filled
end

-- Nach dem Eintragen noch einmal, falls das Auktionshaus nach seiner eigenen Suche selbst einen Preis setzt
function S.FillLater()
    if not C_Timer then return end
    local item = S.item
    for _, d in ipairs(S.FILL_DELAYS) do
        C_Timer.After(d, function() if S.item == item and not S.busy then S.FillAH(); S.UpdatePanel() end end)
    end
end

-- Werte aus dem Blizzard-Fenster lesen (das zaehlt beim Einstellen)
function S.ReadAH()
    local sf = S.ActiveSellFrame()
    if not sf then return nil end
    local r = { frame = sf }
    local ok, v = Call(sf.PriceInput, "GetAmount")
    if ok and Num(v) and v > 0 then r.price = v end
    ok, v = Call(sf.QuantityInput, "GetQuantity")
    if ok and Num(v) and v > 0 then r.qty = v end
    ok, v = Call(sf, "GetDuration")
    if ok and Num(v) then
        for h, i in pairs(ns.Data.DUR_INDEX) do if i == v then r.dur = h end end
    end
    return r
end

function S.GetPrice()
    local a = S.ReadAH()
    return (a and a.price) or S.price
end

function S.GetQty()
    local a = S.ReadAH()
    return (a and a.qty) or S.qtyPlan or 0
end

function S.GetDuration()
    local a = S.ReadAH()
    return (a and a.dur) or S.duration or 8
end

-- Neuer Vorschlag aus Live-Daten (bzw. Scan)
function S.Suggest()
    local it = S.item
    if not it then return end
    local db = mod.db
    S.sugg = ns.Data.SuggestSell(S.live, it.e, it.key, it.hp, db)
    -- ab 0.20: eingetragen wird das guenstigste Angebot (minus Unterbieten), der Vorschlag bleibt Richtwert
    S.price, S.entryWhy = ns.Data.EntryPrice(S.sugg, it.e, it.key, it.hp, db)
    if not S.price then S.price, S.entryWhy = S.sugg.vp, nil end
    S.entry = S.price
    local offers = (type(it.e) == "table" and it.e.n) or (S.live and #S.live) or 0
    S.duration, S.durWhy = ns.Data.SellDuration(it.key, offers, db, Memory(it.key))
    S.qtyPlan = S.Available(it)
    if it.keepN then S.qtyPlan = math.min(S.qtyPlan, it.count) end   -- Behalten-Menge abziehen
    S.FillAH()
    S.FillLater()
    S.UpdatePanel()
end

-- Gegenstand waehlen: ins Auktionshaus legen, Vorschlag, Live-Abfrage
function S.Select(it)
    S.item = it
    S.live, S.liveAt, S.liveState, S.pending, S.filled = nil, nil, nil, nil, nil
    S.selectedKey = it and it.key or nil
    if S.list then
        if it and not it.keep and it.count > 0 then S.list:Select(it) else S.list.selected = nil; S.list:Update() end
    end
    if not it then S.inAH = nil; S.UpdatePanel(); return end
    S.PutIntoAH(it)
    S.Suggest()
    if not S.Query(it) then S.UpdatePanel() end
end

---------------------------------------------------------------------------
-- Nicht verkaufen / Behalten (je Charakter, Speicher in Keep.lua)
---------------------------------------------------------------------------
function S.SetKept(it, on)
    if not it then return end
    if on then
        ns.Keep.Set(it.key, nil, it)
    else
        ns.Keep.Remove(it.key)
    end
    mod:Print((on and L.SELL_KEPT_MSG or L.SELL_UNKEPT_MSG):format(it.name))
    local keepItem = S.item
    S.Refresh()
    -- Auswahl behalten (Rechtsklick auf eine andere Zeile soll sie nicht aendern)
    if keepItem and keepItem.key ~= it.key and S.item and S.item.key == keepItem.key then S.list:Select(S.item) end
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
function S.Hints()
    local it, sg, db = S.item, S.sugg or {}, mod.db
    local out = {}
    local price, qty = S.GetPrice(), S.GetQty()
    if it.keep then out[#out + 1] = GREY .. L.SELL_HINT_KEPT .. "|r" end
    if not AHOpen() then out[#out + 1] = GREY .. L.SELL_NEED_AH .. "|r"
    elseif S.filled == false then out[#out + 1] = ORANGE .. L.SELL_HINT_FILL .. "|r" end
    -- Haendler zahlt mehr - oder der Markt liegt so tief, dass Broker auf den Mindestpreis angehoben hat (ab 0.20)
    if price and it.hp and it.hp > 0 and (price * (1 - ns.Data.CUT) <= it.hp or (S.entryWhy == "min" and price == S.entry)) then
        out[#out + 1] = ORANGE .. L.SELL_HINT_VENDOR2:format(Money(it.hp * math.max(qty, 1))) .. "|r"
    end
    -- ueblicher Bereich und Marktlage (Kapitel 7, ab 0.21)
    if sg.band then
        out[#out + 1] = GREY .. (sg.band.src == "client" and L.SELL_HINT_RANGE_CLIENT or L.SELL_HINT_RANGE):format(Money(sg.band.low), Money(sg.band.high), sg.band.days) .. "|r"
        if sg.band.trend == "down" then out[#out + 1] = ORANGE .. L.HINT_FALLING .. "|r"
        elseif sg.band.trend == "up" then out[#out + 1] = GREEN .. L.HINT_RISING .. "|r" end
        if sg.min and sg.min > sg.band.high then out[#out + 1] = GREEN .. L.SELL_HINT_HIGH .. "|r" end
    end
    -- unter dem Vorschlag (ab 0.20): Hinweis mit Vorschlag und Abstand; stark darunter in Rot
    if price and sg.vp and price < sg.vp then
        local pct = math.floor((1 - price / sg.vp) * 100 + 0.5)
        local color = ns.Data.IsLowPrice(price, sg.vp, db) and RED or ORANGE
        out[#out + 1] = color .. L.SELL_HINT_BELOW:format(Money(sg.vp), pct) .. "|r"
        if sg.dump then out[#out + 1] = GREY .. (sg.band and L.HINT_DUMP_RANGE or L.SELL_HINT_DUMP3) .. "|r" end
    end
    if (S.liveState == "done" or S.liveState == "timeout") and (not S.live or #S.live == 0) then out[#out + 1] = GREY .. L.SELL_HINT_NOLIVE .. "|r" end
    -- Absatz des Marktes (ab 0.23): schnell weg / Markt voll / laeuft oft ab
    local sr = ns.Sales and type(it.e) == "table" and ns.Sales.Stats(it.e, nil, it.key)
    if sr then
        out[#out + 1] = GREY .. L.SELL_HINT_SALES:format(ns.Sales.SellText(sr)) .. "|r"
        local speed = ns.Sales.Speed(sr)   -- erst ab gelb
        if speed == "slow" then out[#out + 1] = ORANGE .. L.SELL_HINT_SLOW .. "|r"
        elseif speed == "fast" then out[#out + 1] = GREEN .. L.SELL_HINT_FAST .. "|r" end
        if sr.rate and sr.rate < 0.5 and sr.level >= 2 then out[#out + 1] = ORANGE .. L.SELL_HINT_EXPIRES .. "|r" end
    end
    -- Eigene Kosten aus Peon_Ledger (ab 0.25, Zuordnen): Erloes je Stueck unter den Kosten des naechsten Stuecks
    local lg = ns.Tooltip.Ledger and ns.Tooltip.Ledger()
    if lg and type(lg.Cost) == "function" and price and price > 0 then
        local okc, nxt = pcall(lg.Cost, lg, ns.Data.ItemID(it.key))
        if okc and type(nxt) == "number" and nxt > 0 and price * (1 - ns.Data.CUT) < nxt then
            out[#out + 1] = ORANGE .. L.SELL_HINT_COST:format(Money(math.floor(nxt + 0.5))) .. "|r"
        end
    end
    -- Eigene Verkaufsquote aus Peon_Ledger (ab 0.24): "Deine Verkäufe (30 T.): 3 von 4 verkauft (75 %)"
    local rate, sold, back = ns.Tooltip.SellRate(ns.Data.ItemID(it.key))
    if sold then
        local txt = L.TT_SELLRATE .. ": " .. L.TT_SELLRATE_N:format(sold, sold + back)
        if rate then txt = txt .. " (" .. math.floor(rate * 100 + 0.5) .. " %)" end
        out[#out + 1] = ((rate and rate < 0.5) and ORANGE or GREY) .. txt .. "|r"
    end
    local e = it.e
    if sg.source == "live" and type(e) == "table" and e.m and sg.min then
        local lv = ns.Tooltip.TrendLevel(sg.min, e.m)
        if lv == 2 or lv == -2 then out[#out + 1] = GREY .. L.SELL_HINT_DIFF:format(Money(e.m)) .. "|r" end
    end
    local mem = Memory(it.key)
    if type(mem) == "table" and mem.last then
        out[#out + 1] = GREY .. L.SELL_LAST:format(Money(mem.last), ns.Scan.Age(mem.lastT)) .. "|r"
    end
    if qty > S.Available(it) then out[#out + 1] = RED .. L.SELL_HINT_QTY:format(S.Available(it)) .. "|r"
    elseif it.keepN and qty > it.count then out[#out + 1] = ORANGE .. L.SELL_HINT_KEEPN:format(it.keepN) .. "|r" end
    if it.keepN then out[#out + 1] = GREY .. L.KEEP_TT_N:format(it.keepN, it.count) .. "|r" end
    return out
end

-- Stichwort unter dem Preis und ausfuehrlicher Text fuer den Tooltip
function S.ReasonText()
    local sg = S.sugg or {}
    if sg.source == "own" then return L.SELL_KEY_OWN, L.SELL_WHY_OWN end
    if S.entryWhy == "min" then return L.SELL_KEY_MIN, L.SELL_WHY_MIN end
    if sg.source == "live" then
        local key, long
        if S.price == sg.min then key, long = L.SELL_KEY_LIVE, L.SELL_WHY_EQUAL:format(Money(sg.min))
        else key, long = L.SELL_KEY_UNDERCUT, L.SELL_WHY_LIVE:format(Money(sg.min)) end
        if sg.vp and S.price and S.price < sg.vp then
            long = long .. "\n" .. L.SELL_WHY_SUGG:format(Money(sg.vp)) .. (sg.dump and (" " .. L.SELL_WHY_DUMP) or "")
        end
        return key, long
    end
    if sg.source == "scan" then return L.SELL_KEY_SCAN, L.SELL_WHY_SCAN end
    if sg.source == "vendor" then return L.SELL_KEY_VENDOR, L.SELL_WHY_VENDOR end
    return L.SELL_KEY_NONE, L.SELL_WHY_NONE
end

function S.LiveStatus()
    if S.liveState == "wait" then return L.SELL_LIVE_WAIT end
    if S.liveState == "done" then return L.SELL_LIVE_AGE:format(math.max(0, time() - (S.liveAt or time()))) end
    if S.liveState == "error" then return L.SELL_LIVE_ERROR end
    if S.liveState == "timeout" then return L.SELL_LIVE_TIMEOUT end
    return AHOpen() and L.SELL_LIVE_NONE or L.SELL_LIVE_NOAH
end

-- Ist Blizzards Knopf "Auktion erstellen" gerade gesperrt (z. B. "Ihr macht das zu schnell")?
function S.AHButtonBlocked()
    local sf = S.ActiveSellFrame()
    local b = sf and sf.PostButton
    if type(b) ~= "table" or type(b.IsEnabled) ~= "function" then return false end
    local ok, en = pcall(b.IsEnabled, b)
    return ok and en == false
end

-- Knoepfe und Sperr-Hinweis aktualisieren (auch laufend, solange das Auktionshaus sperrt)
function S.UpdateButtons()
    local it = S.item
    if not it or not S.post then return end
    local price, qty = S.GetPrice(), S.GetQty()
    local blocked = S.AHButtonBlocked()
    local can = AHOpen() and price and qty > 0 and qty <= S.Available(it) and not S.busy and not it.keep
        and it.count > 0 and not blocked
    if can then S.post:Enable(); S.postNext:Enable() else S.post:Disable(); S.postNext:Disable() end
    S.blockedText:SetText(blocked and (ORANGE .. L.SELL_THROTTLED .. "|r") or "")
    S.wasBlocked = blocked
end

function S.UpdatePanel()
    if not S.panel then return end
    local it = S.item
    if not it then
        S.panel:Hide(); S.pick:Show()
        return
    end
    S.panel:Show(); S.pick:Hide()
    S.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    S.title:SetText(W.Colored(it.name, it.quality))
    S.have:SetText(L.SELL_IN_BAGS:format(it.bagCount or it.count))
    S.liveText:SetText(GREY .. L.SELL_LIVE .. " " .. S.LiveStatus() .. "|r")
    if AHOpen() then S.refresh:Enable() else S.refresh:Disable() end
    local key, long = S.ReasonText()
    S.priceValue:SetText(S.price and Money(S.price) or (GREY .. "–|r"))
    S.why:SetText(GREY .. key .. "|r")
    S.whyLong = long
    -- Erloes fuer die Menge im Auktionshaus (bzw. alles)
    local price, qty = S.GetPrice(), S.GetQty()
    if price and qty > 0 then
        local erl = price * qty * (1 - ns.Data.CUT)
        local hw = it.hp and it.hp * qty or nil
        local vendorBetter = (hw and erl <= hw) or (S.entryWhy == "min" and price == S.entry)
        S.proceedsValue:SetText((vendorBetter and ORANGE or GREEN) .. Money(erl) .. "|r")
        S.proceedsFor:SetText(GREY .. L.SELL_FOR_QTY:format(qty, S.GetDuration()) .. "|r")
    else
        S.proceedsValue:SetText(""); S.proceedsFor:SetText("")
    end
    S.hints:SetText(table.concat(S.Hints(), "\n"))
    S.keepButton:SetText(it.keep and L.SELL_UNKEEP or L.SELL_KEEP)
    S.UpdateButtons()
end

-- Taschenliste neu aufbauen (Auswahl bleibt, wenn der Gegenstand noch da ist)
function S.Refresh()
    if not S.list then return end
    local all = S.ScanBags()
    local items = {}
    local selected
    for _, it in ipairs(all) do
        if S.selectedKey ~= nil and it.key == S.selectedKey then selected = it end
        if not it.keep and it.count > 0 and (not mod.db.sellOnlyProfitable or it.worth) then items[#items + 1] = it end
    end
    S.list:SetData(items)
    S.onlyCheck:SetChecked(mod.db.sellOnlyProfitable and true or false)
    if selected then
        -- gleicher Gegenstand: nur Daten erneuern (auch wenn er gerade als "nicht verkaufen" markiert wurde)
        S.item = selected
        if not selected.keep and selected.count > 0 then S.list:Select(selected) else S.list.selected = nil; S.list:Update() end
    elseif S.item then
        S.ClearAH()
        S.item, S.selectedKey, S.inAH = nil, nil, nil
    end
    S.UpdatePanel()
end

---------------------------------------------------------------------------
-- Einstellen
---------------------------------------------------------------------------
StaticPopupDialogs["PEON_BROKER_CONFIRM_POST"] = {
    text = "%s",
    button1 = YES, button2 = NO,
    OnAccept = function(_, data) if type(data) == "function" then data() end end,
    timeout = 0, whileDead = false, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

local function Ask(text, fn)
    if StaticPopup_Show then
        StaticPopup_Show("PEON_BROKER_CONFIRM_POST", text, nil, fn)
    end
end

-- Aktuelle Taschen-Position des gewaehlten Gegenstands (Taschen koennen sich geaendert haben)
-- Feedback KarloDerBaer (02.10.2026, Broker 0.20.2): "Der Gegenstand ist nicht mehr in den Taschen", obwohl er da war.
-- Ursache: die Taschenliste ueberspringt gesperrte Plaetze - und ein Platz ist gesperrt, solange der Gegenstand im
-- Verkaufsfenster des Auktionshauses liegt (oder gerade eingestellt wird). Ab 0.21.2 eigene Suche: freie Plaetze
-- zuerst, sonst auch gesperrte; ohne Pruefung "verkaufbar" (das Spiel prueft beim Einstellen ohnehin).
-- Rueckgabe: loc, Eintrag (wie aus der Taschenliste, falls dort vorhanden), Stueck in den Taschen
local function CurrentLocation(key)
    local fresh
    for _, it in ipairs(S.ScanBags(true)) do
        if it.key == key then fresh = it end
    end
    if fresh and fresh.locs[1] then return fresh.locs[1].loc, fresh, fresh.count end
    local C = rawget(_G, "C_Container")
    if not C then return nil end
    local first, last = BagRange()
    local lockedLoc, count = nil, 0
    for bag = first, last do
        local ok, slots = pcall(C.GetContainerNumSlots, bag)
        for slot = 1, (ok and tonumber(slots) or 0) do
            local ok2, info = pcall(C.GetContainerItemInfo, bag, slot)
            local link = ok2 and type(info) == "table" and info.hyperlink
            if link and not Peon.IsSecret(link) and ns.Data.KeyFromLink(link) == key then
                count = count + (tonumber(info.stackCount) or 1)
                if not lockedLoc then lockedLoc = Location(bag, slot) end
            end
        end
    end
    if not lockedLoc then return nil end
    return lockedLoc, fresh, count
end
S.CurrentLocation = CurrentLocation

function S.IndexOf(key)
    for i, it in ipairs(S.list:GetItems()) do if it.key == key then return i end end
    return 1
end

-- Einstellen mit den Werten aus dem Blizzard-Fenster (dort sichtbar und aenderbar);
-- ohne Blizzard-Fenster mit den Werten von Broker
function S.Post(goNext)
    local it = S.item
    if not it or S.busy or it.keep or it.count <= 0 then return end
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.SELL_COMBAT); return end
    if not AHOpen() then mod:Print(L.SELL_NEED_AH); return end
    local a = S.ReadAH()
    local price = (a and a.price) or S.price
    local qty = (a and a.qty) or S.qtyPlan
    local dur = (a and a.dur) or S.duration or 8
    if not price or not qty or qty < 1 then return end
    local loc, fresh, inBags = CurrentLocation(it.key)
    -- Ueber das Blizzard-Fenster stellt das Spiel den Gegenstand ein, der dort liegt; dann reicht es, dass er da ist
    if not loc and not (a and a.frame) then mod:Print(L.SELL_GONE); S.Refresh(); return end
    local avail = fresh and S.Available(fresh) or inBags or (a and a.qty) or 0
    if qty > avail then mod:Print(L.SELL_HINT_QTY:format(avail)); return end
    local job = { key = it.key, name = it.name, qty = qty, price = price, dur = dur, planned = S.duration, next = goNext,
                  commodity = ns.Data.IsCommodity(it.key), loc = loc, id = it.id, index = S.IndexOf(it.key),
                  frame = a and a.frame }
    local function Go()
        if job.frame and S.AHButtonBlocked() then
            mod:Print(L.SELL_THROTTLED)
            S.UpdatePanel()
            return
        end
        if job.frame and job.frame.PostButton and Call(job.frame.PostButton, "Click") then
            job.blizzard = true
            mod:Dbg("Einstellen ueber das Auktionshaus-Fenster")
            S.Wait(job)
        else
            S.DoPost(job)
        end
    end
    -- Rueckfrage nur, wenn von Hand noch tiefer als der eingetragene Preis und stark unter dem Vorschlag (ab 0.20)
    if (not S.entry or price < S.entry) and ns.Data.IsLowPrice(price, S.sugg and S.sugg.vp, mod.db) then
        Ask(L.SELL_ASK_LOW:format(Money(price), Money(S.sugg.vp)), Go)
    else
        Go()
    end
end

function S.DoPost(job)
    local ah = AH()
    local durIdx = ns.Data.DUR_INDEX[job.dur]
    local ok, needConfirm
    if job.commodity then
        ok, needConfirm = pcall(ah.PostCommodity, job.loc, durIdx, job.qty, job.price)
    else
        ok, needConfirm = pcall(ah.PostItem, job.loc, durIdx, job.qty, nil, job.price)
    end
    if not ok then mod:Print(L.SELL_FAILED:format(tostring(needConfirm))); return end
    if needConfirm == true then
        Ask(L.SELL_ASK_GAME, function()
            local okc
            if job.commodity then
                okc = pcall(ah.ConfirmPostCommodity, job.loc, durIdx, job.qty, job.price)
            else
                okc = pcall(ah.ConfirmPostItem, job.loc, durIdx, job.qty, nil, job.price)
            end
            if okc then S.Wait(job) end
        end)
        return
    end
    S.Wait(job)
end

-- Auf die Rueckmeldung des Spiels warten (ueber das Blizzard-Fenster laenger: es kann selbst nachfragen)
function S.Wait(job)
    S.busy = job
    job.t = time()
    S.UpdatePanel()
    if C_Timer then
        C_Timer.After(job.blizzard and S.POST_TIMEOUT_AH or S.POST_TIMEOUT, function()
            if S.busy == job then
                S.busy = nil
                if not job.blizzard then mod:Print(L.SELL_NO_ANSWER) end
                S.UpdatePanel()
            end
        end)
    end
end

function S.OnCreated()
    local job = S.busy
    if not job then return end
    S.busy = nil
    SetMemory(job.key, "last", job.price)
    SetMemory(job.key, "lastT", time())
    if job.planned and job.dur ~= job.planned then SetMemory(job.key, "dur", job.dur) end   -- Dauer im Auktionshaus geaendert
    mod:Print(L.SELL_DONE:format(job.qty, job.name, Money(job.price), job.dur))
    S.Refresh()
    if job.next then
        local view = S.list:GetItems()
        local nxt = view[job.index]
        if nxt and nxt.key == job.key then nxt = view[job.index + 1] end
        if nxt then S.Select(nxt) else S.Select(nil) end
    elseif S.item then
        -- Rest desselben Gegenstands: erst nach dem Taschen-Update wieder ins Auktionshaus legen
        S.reselectKey = job.key
        S.UpdatePanel()
    end
end

function S.OnError()
    if not S.busy then return end
    S.busy = nil
    mod:Print(L.SELL_ERROR)
    S.UpdatePanel()
end

---------------------------------------------------------------------------
-- Aufbau
---------------------------------------------------------------------------
local function Text(parent, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    return fs
end

S.LEFT_W = 200   -- linke Spalte (Gegenstand, Vorschlag, Erloes, Knoepfe); rechts die Taschen

local function Button(parent, text, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(S.LEFT_W - 16, 24)
    b:SetText(text)
    b:SetScript("OnClick", fn)
    return b
end

function S.Build(c)
    local total = W.WIDTH - 24
    local rightX = S.LEFT_W + 8
    local rightW = total - rightX

    -- rechts: Taschen (Symbol, Name, Anzahl, Wert, Trend); Rechtsklick = nicht verkaufen
    local inset = W.Inset(c)
    inset:SetPoint("TOPLEFT", rightX, 0)
    inset:SetPoint("BOTTOMRIGHT", 0, 0)
    local nameW = rightW - 24 - 36 - 80 - 36 - 8
    S.list = Peon.NewList(inset, {
        columns = {
            { key = "name", title = L.COL_ITEM, width = nameW,
              format = function(v, it)
                  return "|T" .. tostring(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":16:16:0:0|t " .. W.Colored(v, it.quality)
              end,
              sortValue = function(it) return W.Lower(it.name) end },
            { key = "count", title = L.COL_COUNT_SHORT, width = 36, align = "RIGHT" },
            { key = "value", title = L.COL_VALUE, width = 80, align = "RIGHT",
              format = function(v, it)
                  if v == nil then return GREY .. "?" .. "|r" end
                  if it.ah and it.erl then return ns.Tooltip.StateColor(it.state) .. Money(v) .. "|r" end   -- Farbe wie Zeile 1 (ab 0.21)
                  return GREY .. Money(v) .. "|r"
              end },
            { key = "trend", title = L.COL_TREND, width = 36, align = "CENTER",
              format = function(v, it) return it.trendText or "" end },
        },
        rows = 20, rowHeight = 19, sortKey = "value", sortDesc = true,
        onClick = function(list, it, button)
            if button == "RightButton" then S.SetKept(it, true) else S.Select(it) end
        end,
        onEnter = function(list, it, row) W.ShowItemTooltip(row, it.key) end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
        emptyText = L.SELL_EMPTY,
    })
    S.list.frame:SetPoint("TOPLEFT", 4, -4)
    local only = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    only:SetSize(22, 22)
    only:SetPoint("BOTTOMLEFT", 4, 4)
    only:SetScript("OnClick", function(self)
        mod.db.sellOnlyProfitable = self:GetChecked() and true or false
        S.Refresh()
    end)
    local ol = Text(inset)
    ol:SetPoint("LEFT", only, "RIGHT", 2, 0)
    ol:SetText(L.SELL_ONLY_SHORT)
    S.onlyCheck = only
    local rc = Text(inset, "GameFontDisableSmall")
    rc:SetPoint("BOTTOMRIGHT", -8, 9)
    rc:SetJustifyH("RIGHT")
    rc:SetText(L.SELL_RIGHTCLICK)

    -- links: gewaehlter Gegenstand
    local left = W.Inset(c)
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(S.LEFT_W)

    local pick = Text(left, "GameFontDisable")
    pick:SetPoint("TOPLEFT", 12, -40)
    pick:SetWidth(S.LEFT_W - 24)
    pick:SetText(L.SELL_PICK)
    S.pick = pick

    local p = CreateFrame("Frame", nil, left)
    p:SetAllPoints()
    S.panel = p
    local w = S.LEFT_W - 20

    S.icon = p:CreateTexture(nil, "ARTWORK")
    S.icon:SetSize(36, 36)
    S.icon:SetPoint("TOPLEFT", 10, -10)
    S.title = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    S.title:SetPoint("TOPLEFT", S.icon, "TOPRIGHT", 6, 0)
    S.title:SetWidth(S.LEFT_W - 60)
    S.title:SetJustifyH("LEFT")
    S.have = Text(p)
    S.have:SetPoint("TOPLEFT", S.icon, "BOTTOMLEFT", 0, -6)
    S.liveText = Text(p)
    S.liveText:SetPoint("TOPLEFT", S.have, "BOTTOMLEFT", 0, -3)
    S.refresh = CreateFrame("Button", nil, p)
    S.refresh:SetSize(18, 18)
    S.refresh:SetPoint("TOPRIGHT", -8, -48)
    S.refresh:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
    S.refresh:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    S.refresh:SetScript("OnClick", function() if S.item then S.Query(S.item) end end)
    S.refresh:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L.SELL_REFRESH_HINT, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    S.refresh:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Vorschlag je Stueck (Stichwort, ausfuehrlich beim Ueberfahren)
    local y = -96
    local pl = Text(p, "GameFontNormalSmall")
    pl:SetPoint("TOPLEFT", 10, y)
    pl:SetText(L.SELL_PRICE)
    S.priceValue = Text(p, "GameFontHighlightLarge")
    S.priceValue:SetPoint("TOPLEFT", 10, y - 16)
    local whyF = CreateFrame("Frame", nil, p)
    whyF:SetPoint("TOPLEFT", 10, y - 38)
    whyF:SetSize(w, 14)
    whyF:EnableMouse(true)
    S.why = Text(whyF)
    S.why:SetPoint("LEFT", 0, 0)
    whyF:SetScript("OnEnter", function(self)
        if not GameTooltip or not S.whyLong then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.SELL_PRICE, 1, 1, 1)
        GameTooltip:AddLine(S.whyLong, 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    whyF:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    S.whyFrame = whyF

    -- Erloes
    y = y - 62
    local el = Text(p, "GameFontNormalSmall")
    el:SetPoint("TOPLEFT", 10, y)
    el:SetText(L.SELL_PROCEEDS_LABEL)
    S.proceedsValue = Text(p, "GameFontHighlightLarge")
    S.proceedsValue:SetPoint("TOPLEFT", 10, y - 16)
    S.proceedsFor = Text(p)
    S.proceedsFor:SetPoint("TOPLEFT", 10, y - 38)

    -- Hinweise
    S.hints = Text(p)
    S.hints:SetPoint("TOPLEFT", 10, y - 60)
    S.hints:SetWidth(w)
    if S.hints.SetSpacing then S.hints:SetSpacing(2) end

    -- Knoepfe uebereinander
    S.postNext = Button(p, L.SELL_POST_NEXT, function() mod:Call("Verkaufen", S.Post, true) end)
    S.postNext:SetPoint("BOTTOM", 0, 10)
    S.post = Button(p, L.SELL_POST, function() mod:Call("Verkaufen", S.Post, false) end)
    S.post:SetPoint("BOTTOM", S.postNext, "TOP", 0, 4)
    S.keepButton = Button(p, L.SELL_KEEP, function()
        if S.item then mod:Call("Verkaufen", S.SetKept, S.item, not S.item.keep) end
    end)
    S.keepButton:SetPoint("BOTTOM", S.post, "TOP", 0, 12)
    S.blockedText = Text(p)
    S.blockedText:SetPoint("BOTTOM", S.keepButton, "TOP", 0, 6)
    S.blockedText:SetWidth(S.LEFT_W - 20)
    -- solange das Auktionshaus sperrt: alle 0,3 Sek. nachsehen, ob es wieder geht
    local acc = 0
    p:SetScript("OnUpdate", function(_, dt)
        acc = acc + (dt or 0)
        if acc < 0.3 then return end
        acc = 0
        if S.wasBlocked then S.UpdateButtons() end
    end)

    p:Hide()
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
-- Gegenstand per Link im Reiter "Verkaufen" auswaehlen (bis 0.27.0 per Alt+Klick in den Taschen; ab 0.27.1 gehoert
-- Alt+Klick Peon_Ledger, KarloDerBaer 06.10.2026 - die Funktion bleibt fuer andere Aufrufer)
function S.SelectLink(link)
    if type(link) ~= "string" or Peon.IsSecret(link) then return end
    if not AHOpen() and not W.IsOpen() then return end
    local key = ns.Data.KeyFromLink(link)
    if key == nil then return end
    -- im Reiter "Einkaufen" (Listen): zur aktuellen Einkaufsliste hinzufuegen
    if W.IsOpen() and W.current == "buy" and ns.Buy and ns.Buy.mode == "lists" then
        ns.Buy.AddFromLink(link)
        return
    end
    if not W.IsOpen() or W.current ~= "sell" then W.Open("sell") end
    for _, it in ipairs(S.list:GetItems()) do
        if it.key == key then S.Select(it); return end
    end
    -- nicht in der Liste (z. B. "nur lohnende" aktiv): trotzdem auswaehlen
    for _, it in ipairs(S.ScanBags()) do
        if it.key == key then S.Select(it); return end
    end
end

function S.Init()
    mod:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, itemID) OnResults(true, itemID) end)
    mod:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey) OnResults(false, itemKey) end)
    pcall(mod.RegisterEvent, mod, "COMMODITY_SEARCH_RESULTS_ADDED", function(_, itemID) OnResults(true, itemID) end)
    pcall(mod.RegisterEvent, mod, "ITEM_SEARCH_RESULTS_ADDED", function(_, itemKey) OnResults(false, itemKey) end)
    mod:RegisterEvent("AUCTION_HOUSE_NEW_RESULTS_RECEIVED", function(_, itemKey)
        if S.pending then
            mod:Dbg("Neue Ergebnisse fuer " .. KeyText(itemKey))
            if type(itemKey) == "table" and itemKey.itemID == S.pending.itemID then
                table.insert(S.pending.keys, 1, itemKey)
                S.Poll(S.pending)
            end
        end
    end)
    mod:RegisterEvent("AUCTION_HOUSE_AUCTION_CREATED", function() S.OnCreated() end)
    mod:RegisterEvent("AUCTION_HOUSE_SHOW_ERROR", function() S.OnError() end)
    mod:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if not (W.IsOpen() and W.current == "sell") or S.busy then return end
        S.Refresh()
        local key = S.reselectKey
        S.reselectKey = nil
        if key ~= nil and S.item and S.item.key == key and S.item.count > 0 then S.Select(S.item) end
    end)
    -- Sperre des Auktionshauses ("zu schnell") vorbei: Knoepfe neu pruefen
    for _, e in ipairs({ "AUCTION_HOUSE_THROTTLED_SYSTEM_READY", "AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED" }) do
        mod:RegisterEvent(e, function() if S.panel and S.panel:IsShown() then S.UpdateButtons() end end)
    end
end

W.pages.sell = {
    build = S.Build,
    refresh = S.Refresh,
    -- Reiter gewaehlt (ab 0.20): gewaehlten Gegenstand wieder ins Verkaufsfenster legen (Blizzard zeigte sonst die alte Seite)
    enter = function()
        if S.item and not S.busy and S.item.count > 0 and AHOpen() then
            if S.PutIntoAH(S.item) then S.FillAH(); S.FillLater() end
            S.UpdatePanel()
        end
    end,
}
