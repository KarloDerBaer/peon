-- Peon_Broker - Live.lua
-- Ab 0.55 (Umbau U12): Lesen von Live-Ergebnissen des Auktionshauses. Bis 0.54 Teil von Sell.lua (Reiter Verkaufen),
-- der Reiter entfaellt, die Bausteine nutzen Rat beim Verkaufen, Einkaufen, Radar und Auktionen weiter.
--   L.ReadCommodity(itemID)   Massenware: Stufen { price, qty, own } guenstigste zuerst, offers, partial, foreign
--   L.ReadItems(itemKey, key) Einzelgegenstaende, bei Varianten nur genau diese Variante
--   L.IsFull(commodity, arg)  hat das Spiel alle Ergebnisse geliefert?
--   L.RequestMore(p, commodity), L.Foreign(r, itemID), L.LinkID(link), L.KeyText(itemKey)

local ADDON_NAME, ns = ...

local S = {}
ns.Live = S

local function AH() return rawget(_G, "C_AuctionHouse") end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

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

function S.KeyText(k)
    if type(k) ~= "table" then return tostring(k) end
    return ("%s/%s/%s/%s"):format(tostring(k.itemID), tostring(k.itemLevel), tostring(k.itemSuffix), tostring(k.battlePetSpeciesID))
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
