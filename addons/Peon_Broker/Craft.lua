-- Peon_Broker - Craft.lua
-- Preise und Vorrat fuer Berufe. Die Anzeige im Berufsfenster (Block unter den Reagenzien, Gewinn in der Rezeptliste,
-- Zahnrad, Einstellungen) ist ab Broker 0.95 nach Peon_Profession 0.2.0 umgezogen (Konzept
-- Peon_Profession_Konzept.md Abschnitt 8, Zustimmung KarloDerBaer 14.11.2026). Hier bleibt, was andere Teile von
-- Broker brauchen (Pack.lua, Merchant.lua, Tooltip.lua) und was Peon_Profession ueber die Schnittstelle abfragt
-- (mod:BuyPrice, mod:AhPrice in Broker.lua).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local C = {}
ns.Craft = C

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

-- Kosten je Stueck eines Materials: guenstigstes Angebot (aktueller Stand), nil = unbekannt
function C.UnitCostHome(id)
    local e = ns.Data.Lookup(id)
    if type(e) == "table" and Num(e.m) and not e.gone then return e.m end
    return nil
end
-- ab 0.42 (Umbau U1): Materialpreise immer aus dem Heimatmarkt, auch am neutralen Auktionshaus
function C.UnitCost(id) return ns.WithHome(C.UnitCostHome, id) end

-- Kaufpreis je Stueck: Preis, Quelle ("vendor", "ah", "none"), AH-Preis, Haendlerpreis, Herkunft des Haendlerpreises, Haendler
function C.BuyPrice(id)
    local ah = C.UnitCost(id)
    local vp, vsrc, vwho
    if ns.Merchant then vp, vsrc, vwho = ns.Merchant.Price(id) end
    if vp and (not ah or vp <= ah) then return vp, "vendor", ah, vp, vsrc, vwho end
    if ah then return ah, "ah", ah, vp, vsrc, vwho end
    return nil, "none", ah, vp, vsrc, vwho
end

-- Peon_Ledger (wenn geladen, nur lesend)
function C.Ledger()
    if not Peon.GetModule then return nil end
    local ok, l = pcall(Peon.GetModule, Peon, "ledger")
    if ok and type(l) == "table" then return l end
    return nil
end

-- Vorrat wie im Reiter Behalten: gesamt, Taschen, Bank, andere Charaktere (nur mit Haken "Twinks mitzaehlen")
function C.Stock(id)
    local K = ns.Stock
    if K and K.Counts then
        local ok, bags, bank, total, others = pcall(K.Counts, id)
        if ok and Num(total) then return total, bags or 0, bank or 0, others or 0 end
    end
    return 0, 0, 0, 0
end

-- Tooltip (mit Umschalt): "Herstellen: Material 1g 20s · Gewinn +35s". Kommt ab 0.95 von Peon_Profession.
function C.TooltipText(key)
    local id = ns.Data.ItemID(key)
    if not id or not Peon.GetModule then return nil end
    local p = Peon:GetModule("profession")
    if type(p) ~= "table" or type(p.CraftTooltip) ~= "function" then return nil end
    local ok, t = pcall(p.CraftTooltip, p, id)
    if ok and type(t) == "string" then return t end
    return nil
end

-- /broker pruefen beruf: Hinweis auf den Umzug
function C.Probe() mod:Print(L.CRAFT_MOVED) end
