-- Peon_Broker - Merchant.lua
-- Kaufpreise beim Haendler (ab 0.39, KarloDerBaer 08.11.2026), fuer das Berufsfenster: Material beim Haendler
-- oder im AH kaufen, je nachdem wo es guenstiger ist. Das Spiel nennt den Haendlerpreis nur bei offenem
-- Haendlerfenster, darum drei Quellen, die beste zuerst:
--   1. "seen":   bei einem Haendlerbesuch gesehen (ab 0.63 aus dem gemeinsamen Speicher PeonBrokerDB.vendors,
--                Vendors.lua liest die Angebote; der fruehere eigene Speicher merchant wird nur noch gelesen).
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

-- Kaufpreis beim Haendler je Stueck: Preis, Quelle ("seen", "ledger", "est"), Name des Haendlers; nil = unbekannt
function V.Price(id)
    if not Num(id) then return nil end
    -- 1. gesehen: guenstigster Haendler aus dem gemeinsamen Speicher (Vendors.lua, PeonBrokerDB.vendors)
    if ns.Vendors then
        for _, x in ipairs(ns.Vendors.For(id)) do
            if Num(x.e.p) and x.e.p > 0 then return x.e.p, "seen", x.v.n end
        end
    end
    -- bis 0.62 eigener Speicher PeonBrokerDB.merchant: wird nur noch gelesen, bis der Haendler wieder besucht wurde
    local old = type(mod.acc) == "table" and type(mod.acc.merchant) == "table" and mod.acc.merchant[id]
    if type(old) == "table" and Num(old.p) and old.p > 0 then return old.p, "seen", old.w end
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
