-- Peon_Broker - Merchant.lua
-- Kaufpreise beim Haendler (ab 0.39, KarloDerBaer 08.11.2026), fuer das Berufsfenster: Material beim Haendler
-- oder im AH kaufen, je nachdem wo es guenstiger ist. Das Spiel nennt den Haendlerpreis nur bei offenem
-- Haendlerfenster, darum drei Quellen, die beste zuerst:
--   1. "seen":   Broker merkt sich bei jedem Haendlerbesuch die Angebote (accountweit, PeonBrokerDB.merchant).
--   2. "ledger": letzter Kauf beim Haendler laut Peon_Ledger (mod:VendorBuy, ab Ledger 0.13.1).
--   3. "est":    Geschaetzt fuer bekannte Haendler-Reagenzien (Liste unten): Ankaufspreis des Haendlers x 4.
-- Gespeichert: PeonBrokerDB.merchant[itemID] = { p = Kupfer je Stueck, t = Zeit, w = Name des Haendlers }

local ADDON_NAME, ns = ...
local mod = ns.mod

local V = {}
ns.Merchant = V

V.EST_FACTOR = 4   -- Haendler verkaufen meist zum Vierfachen dessen, was sie selbst zahlen

-- Reagenzien, die Haendler fuehren (nur die Nummern, Preise kommen aus dem Spiel)
V.LIST = {
    [159] = true,   -- Erfrischendes Quellwasser
    [1179] = true,  -- Eisgekuehlte Milch
    [2320] = true, [2321] = true, [4291] = true, [8343] = true, [14341] = true,   -- Faeden
    [2324] = true, [2325] = true, [2604] = true, [4340] = true, [4341] = true, [4342] = true,
    [6260] = true, [6261] = true, [10290] = true,                                  -- Bleiche und Farbstoffe
    [2596] = true, [2894] = true,                                                  -- Zwergenstarkbier, Rhapsodiemalz
    [2665] = true, [2678] = true, [2692] = true, [3713] = true,                    -- Kraeuter und Gewuerze
    [2880] = true, [3466] = true, [3857] = true, [18567] = true,                   -- Flussmittel, Kohle
    [3371] = true, [3372] = true, [8925] = true, [18256] = true,                   -- Phiolen
    [4289] = true,                                                                 -- Salz
    [4399] = true, [4400] = true, [4470] = true, [6217] = true, [11291] = true,    -- Holz, Schaft, Rute
    [10647] = true, [10648] = true,                                                -- Tinte, Pergament
    [2928] = true, [2930] = true, [5173] = true, [8923] = true, [8924] = true,     -- Gifte
}

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

function V.Store()
    local acc = mod.acc
    if type(acc) ~= "table" then return {} end
    if type(acc.merchant) ~= "table" then acc.merchant = {} end
    return acc.merchant
end

-- Angebot i des offenen Haendlers: itemID, Preis je Stueck (nil = nicht mit Gold zu kaufen)
local function Offer(i)
    local id
    if GetMerchantItemID then
        local ok, x = pcall(GetMerchantItemID, i)
        if ok and Num(x) then id = x end
    end
    if not id and GetMerchantItemLink then
        local ok, link = pcall(GetMerchantItemLink, i)
        if ok and type(link) == "string" and not Peon.IsSecret(link) then id = tonumber(link:match("item:(%d+)")) end
    end
    if not id then return nil end
    local price, qty, ext
    local CM = rawget(_G, "C_MerchantFrame")
    if CM and CM.GetItemInfo then
        local ok, info = pcall(CM.GetItemInfo, i)
        if ok and type(info) == "table" then price, qty, ext = info.price, info.stackCount, info.hasExtendedCost end
    end
    if price == nil and GetMerchantItemInfo then
        local ok, _, _, p, q, _, _, _, e = pcall(GetMerchantItemInfo, i)
        if ok then price, qty, ext = p, q, e end
    end
    if not Num(price) or price <= 0 or ext then return id, nil end
    qty = (Num(qty) and qty > 0) and qty or 1
    return id, price / qty
end

-- Alle Angebote des offenen Haendlers merken
function V.Scan()
    if not GetMerchantNumItems then return 0 end
    local ok, n = pcall(GetMerchantNumItems)
    if not ok or not Num(n) then return 0 end
    local who = UnitName and UnitName("npc")
    if type(who) ~= "string" or Peon.IsSecret(who) then who = nil end
    local store, got, t = V.Store(), 0, time and time() or 0
    for i = 1, n do
        local id, unit = Offer(i)
        if id and unit then
            store[id] = { p = unit, t = t, w = who }
            got = got + 1
        end
    end
    if got > 0 and ns.Craft then ns.Craft.dirty = true end
    return got
end

-- Kaufpreis beim Haendler je Stueck: Preis, Quelle ("seen", "ledger", "est"), Name des Haendlers; nil = unbekannt
function V.Price(id)
    if not Num(id) then return nil end
    local e = V.Store()[id]
    if type(e) == "table" and Num(e.p) and e.p > 0 then return e.p, "seen", e.w end
    local l = ns.Craft and ns.Craft.Ledger and ns.Craft.Ledger()
    if l and type(l.VendorBuy) == "function" then
        local ok, p = pcall(l.VendorBuy, l, id)
        if ok and Num(p) and p > 0 then return p, "ledger" end
    end
    if V.LIST[id] then
        local s = ns.VendorPrice(id)
        if Num(s) and s > 0 then return s * V.EST_FACTOR, "est" end
    end
    return nil
end

function V.Init()
    local function OnMerchant() mod:Call("Haendler", V.Scan) end
    pcall(mod.RegisterEvent, mod, "MERCHANT_SHOW", OnMerchant)
    pcall(mod.RegisterEvent, mod, "MERCHANT_UPDATE", OnMerchant)
end
