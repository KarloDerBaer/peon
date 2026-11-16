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

-- ab 0.4.0 (Reiter Verlauf): Haendlerpreis je Stueck, nil = unbekannt
function P.Vendor(id)
    local b = P.Broker()
    if not b then return nil end
    local ok, _, _, _, vp = pcall(b.BuyPrice, b, id)
    if ok and type(vp) == "number" and not Peon.IsSecret(vp) then return vp end
    return nil
end

-- ab 0.4.0: Verlauf im AH ueber Broker (aelteste zuerst, { day, week, min, median, ... }), leer ohne Broker 0.27
function P.History(id)
    local b = P.Broker()
    if not (b and type(b.History) == "function") then return {} end
    local ok, rows = pcall(b.History, b, id)
    return ok and type(rows) == "table" and rows or {}
end

-- ab 0.4.0: heutige Tagesnummer wie in Brokers Daten
function P.Today()
    local b = P.Broker()
    if b and type(b.DayOf) == "function" then
        local ok, d = pcall(b.DayOf, b)
        if ok and type(d) == "number" then return d end
    end
    local d = date("*t", time())
    return math.floor(time({ year = d.year, month = d.month, day = d.day, hour = 12 }) / 86400)
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
-- Rueckgabe: rows = { { id, per, need, have, own, others, missing, unit, src, cost } }, Summe, Zahl ohne Preis.
-- Ab 0.3.1 mit key: Zwischenprodukte, die der Beruf selbst herstellt, stehen mit src "craft" und ohne Preis,
-- ihr Material folgt als eigene Zeilen (Guide.Resolve).
function P.Rows(mats, crafts, key)
    local need, per, order = {}, {}, {}
    for _, m in ipairs(mats) do
        if not need[m.id] then order[#order + 1] = m.id end
        need[m.id] = (need[m.id] or 0) + m.q * (crafts or 1)
        per[m.id] = (per[m.id] or 0) + m.q
    end
    local base, made = need, {}
    if key and ns.Guide then base, made = ns.Guide.Resolve(key, need) end
    local extra = {}
    for id in pairs(base) do if not per[id] then extra[#extra + 1] = id end end
    table.sort(extra)
    for _, id in ipairs(extra) do order[#order + 1] = id end
    local rows, total, noPrice = {}, 0, 0
    for _, id in ipairs(order) do
        local have, own, others = P.Stock(id)
        local mk = made[id]
        if mk then
            rows[#rows + 1] = { id = id, per = per[id], need = mk.need, have = have, own = own, others = others,
                missing = math.max(0, mk.need - mk.have), src = "craft", craft = mk.crafts }
        end
        if base[id] then
            local n = base[id]
            local missing = math.max(0, n - have)
            local unit, src = P.Unit(id)
            local cost
            if missing > 0 then
                if unit then cost = unit * missing; total = total + cost else noPrice = noPrice + 1 end
            end
            rows[#rows + 1] = { id = id, per = per[id], need = n, have = have, own = own, others = others,
                missing = missing, unit = unit, src = src, cost = cost }
        end
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
