-- Peon_Profession - Prices.lua
-- Preise, Vorrat und Einkaufsliste ueber Peon_Broker und Peon_Ledger (Konzept Abschnitt 5). Ohne die beiden
-- fallen Preise und Twink-Vorrat weg, der Guide laeuft trotzdem.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local P = {}
ns.Prices = P

local function Module(key)
    if not (Peon and Peon.GetModule) then return nil end
    local m = Peon:GetModule(key)
    return type(m) == "table" and m or nil
end

function P.Broker()
    local b = Module("broker")
    if b and type(b.BuyPrice) == "function" then return b end
    return nil
end

function P.Ledger()
    local l = Module("ledger")
    if l and type(l.StockOthers) == "function" then return l end
    return nil
end

-- Kaufpreis je Stueck (Haendler oder AH) und Quelle ("vendor", "ah"), nil ohne Broker oder Preis
function P.Unit(id)
    local b = P.Broker()
    if not b then return nil end
    local ok, p, src = pcall(b.BuyPrice, b, id)
    if ok and type(p) == "number" and not Peon.IsSecret(p) then return p, src end
    return nil
end

-- Vorrat: eigener Charakter (Taschen, Bank, Materiallager) und andere Charaktere laut Ledger
function P.Stock(id)
    local own = 0
    local CI = rawget(_G, "C_Item")
    if CI and CI.GetItemCount then
        local ok, n = pcall(CI.GetItemCount, id, true, false, true)
        if ok and type(n) == "number" and not Peon.IsSecret(n) then own = n end
    end
    local others = 0
    local l = P.Ledger()
    if l then
        local ok, n = pcall(l.StockOthers, l, id)
        if ok and type(n) == "number" then others = n end
    end
    return own + others, own, others
end

-- Tabelle fuer das Material: Bedarf { [itemID] = Stueck } bzw. Liste { { id, q } } mit crafts.
-- Rueckgabe: rows = { { id, per, need, have, own, others, missing, unit, src, cost } }, Summe, Zahl ohne Preis
function P.Rows(mats, crafts)
    local rows, total, noPrice = {}, 0, 0
    for _, m in ipairs(mats) do
        local need = m.q * (crafts or 1)
        local have, own, others = P.Stock(m.id)
        local missing = math.max(0, need - have)
        local unit, src = P.Unit(m.id)
        local cost
        if missing > 0 then
            if unit then cost = unit * missing; total = total + cost else noPrice = noPrice + 1 end
        end
        rows[#rows + 1] = { id = m.id, per = m.q, need = need, have = have, own = own, others = others,
            missing = missing, unit = unit, src = src, cost = cost }
    end
    return rows, total, noPrice
end

-- Bedarf { [itemID] = Stueck } -> Kosten fuer das, was fehlt
function P.NeedCost(need)
    local total, noPrice = 0, 0
    for id, n in pairs(need) do
        local missing = math.max(0, n - (P.Stock(id)))
        if missing > 0 then
            local unit = P.Unit(id)
            if unit then total = total + unit * missing else noPrice = noPrice + 1 end
        end
    end
    return total, noPrice
end

-- Fehlendes Material auf die Einkaufsliste "Beruf: <Name>". Wunschmenge = ganzer Bedarf, "Fehlt" rechnet Broker.
function P.ToList(key, need)
    local b = Module("broker")
    if not (b and type(b.AddToList) == "function") then mod:Print(L.LIST_NO_BROKER); return 0 end
    local mats = {}
    for id, n in pairs(need) do
        if n - (P.Stock(id)) > 0 then mats[#mats + 1] = { id = id, n = n } end
    end
    table.sort(mats, function(a, b2) return a.id < b2.id end)
    if #mats == 0 then mod:Print(L.LIST_NOTHING); return 0 end
    local name = L.LIST_NAME:format(ns.ProfName(key))
    local ok, added = pcall(b.AddToList, b, name, mats)
    added = ok and tonumber(added) or 0
    mod:Print(L.LIST_ADDED:format(added, name))
    return added
end
