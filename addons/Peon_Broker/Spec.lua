-- Peon_Broker - Spec.lua
-- Ab 0.93 (Konzept Peon_Manager_Chancen.md, Abschnitt 9.2): Kandidaten vom Peon Manager.
-- Der Manager rechnet mit den stuendlichen Staenden der Blizzard-API Chancen aus (Spekulation schnell und langfristig,
-- Aufkauf, Haendler) und schreibt je Markt eine Liste in Data.lua. Peon_Bridge gibt sie ueber mod:Chances(market):
--   list[Schluessel] = "Art:KaufenBis:Zielpreis:GueltigBis:Gewinn:Risiko[:Menge[:Kaufen:Verkaufen]]"
--                      Art s, l, b, ab 0.96 m (Muster), Haendler (v) nur noch im Radar; Risiko 0, 1, 2.
--                      Kaufen und Verkaufen (nur Muster): Zeitfenster "Wochentage/Abschnitt", Wochentage als 7 Bits
--                      (Montag = 1, alle = 127), Abschnitt 0 bis 7 zu je 3 Std., -1 = ganzer Tag
--   say[Schluessel]  = Satz, warum der Manager ihn vorschlaegt
-- Ab 0.96 zeigt sie der Reiter Chancen (Chances.lua), nicht mehr das Radar. Die Live-Pruefung macht weiter der Radar-Teil
-- (Art "spec" in R.entries), "Alle pruefen" ersetzt den Radar-Scan "Vom Manager".
-- Abgelaufene Eintraege (GueltigBis) ignoriert Broker. Das Urteil faellt live: Was nicht mehr stimmt, wird "weg".

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local Sp = {}
ns.Spec = Sp

Sp.KINDS = { s = true, l = true, b = true, m = true }

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

-- Eintrag aus Data.lua lesen
function Sp.Parse(s)
    if type(s) ~= "string" then return nil end
    local k, lim, tg, untilT, gain, risk, qty = s:match("^(%a):(%d+):(%d+):(%d+):(%d+):(%d)(.*)$")
    if not k or not Sp.KINDS[k] then return nil end
    local q, more = qty:match("^:(%d+)(.*)$")
    local x = { mk = k, limit = tonumber(lim), target = tonumber(tg), untilT = tonumber(untilT), gain = tonumber(gain),
             risk = ({ [0] = "low", [1] = "mid", [2] = "high" })[tonumber(risk)] or "mid", qty = q and tonumber(q) or nil }
    -- ab 0.96: Zeitfenster der Muster
    local bm, bs, sm, ss = (more or ""):match("^:(%d+)/(%-?%d+):(%d+)/(%-?%d+)")
    if bm then
        x.buyWin = { mask = tonumber(bm), slot = tonumber(bs) }
        x.sellWin = { mask = tonumber(sm), slot = tonumber(ss) }
    end
    return x
end

-- Alle gueltigen Kandidaten des aktuellen Markts: { [key] = Eintrag }, t = Stand des Managers. Einmal je Stand gelesen.
function Sp.All()
    local b = Peon:GetModule("bridge")
    if not b or type(b.Chances) ~= "function" then return {}, nil end
    local ok, t, list, say = pcall(b.Chances, b, ns.MarketKey())
    if not ok or type(list) ~= "table" then return {}, nil end
    if Sp.cache and Sp.cache.list == list and Sp.cache.t == t then return Sp.cache.out, t end
    local out, now = {}, time()
    for key, s in pairs(list) do
        local x = Sp.Parse(s)
        if x and (x.untilT or 0) > now then
            local k = tonumber(key) or key
            x.key = k
            x.say = type(say) == "table" and type(say[key]) == "string" and say[key] or nil
            x.t = t
            out[k] = x
        end
    end
    Sp.cache = { list = list, t = t, out = out }
    return out, t
end

function Sp.Get(key)
    local all = Sp.All()
    local x = all[key]
    if x == nil and type(key) == "string" and key:match("^%d+$") then x = all[tonumber(key)] end
    if x and (x.untilT or 0) <= time() then return nil end
    return x
end

-- Schluessel fuer den Radar-Scan "Vom Manager": hoechster Gewinn zuerst
function Sp.Keys()
    local keys, all = {}, Sp.All()
    for key in pairs(all) do if ns.Buy.KnownKey(key) then keys[#keys + 1] = key end end
    table.sort(keys, function(a, b) return (all[a].gain or 0) > (all[b].gain or 0) end)
    return keys
end

-- Chance "Spekulation" aus den Preisstufen (Scan oder live): kaufen bis KaufenBis, verkaufen zum Zielpreis.
-- Arten s, l und ab 0.96 m (Muster), den Aufkauf prueft Broker mit seinen eigenen Regeln.
Sp.FIND = { s = true, l = true, m = true }
function Sp.Find(e, rows, key)
    local x = Sp.Get(key)
    if not x or not Sp.FIND[x.mk] then return nil end
    local D = ns.Data
    local lv = D.Available(rows or {})
    if #lv == 0 then return nil end
    local cut = D.Cut()
    local net = math.floor(x.target * (1 - cut))
    local qty, cost, limit = 0, 0, nil
    for _, l in ipairs(lv) do
        if l.price > x.limit then break end
        qty, cost, limit = qty + l.qty, cost + l.qty * l.price, l.price
    end
    if qty < 1 then return nil end
    local gain = math.floor(net * qty - cost)
    if gain <= 0 then return nil end
    return { kind = "spec", mk = x.mk, gain = gain, qty = qty, cost = cost, offer = lv[1].price, ref = x.target, refMedian = x.target,
             limit = limit, net = net, mgr = x, mgrRisk = x.risk }
end

-- Eintrag ohne Preisstufen (der Manager kennt ihn, Brokers eigener Scan nicht): Werte des Managers, bis Erneuern prueft
function Sp.FromManager(key, x)
    local qty = x.qty or 1
    return { kind = "spec", mk = x.mk, gain = x.gain, qty = qty, cost = x.limit * qty, offer = x.limit, ref = x.target, refMedian = x.target,
             limit = x.limit, net = math.floor(x.target * (1 - ns.Data.Cut())), mgr = x, mgrRisk = x.risk, mgrOnly = true, rows = {} }
end

-- Satz und Alter fuer den Fokus (9.2): "Liegt 40 % unter ... Vom Manager, Stand vor 3 Std."
function Sp.FocusText(key)
    local x = Sp.Get(key)
    if not x then return nil end
    local age = x.t and math.max(0, time() - x.t) or nil
    local stand = age and L.SPEC_FROM_MGR:format(age < 3600 and L.SPEC_MIN:format(math.max(1, math.floor(age / 60))) or L.SPEC_HOURS:format(math.floor(age / 3600))) or L.SPEC_FROM_MGR_NOAGE
    return (x.say and (x.say .. " ") or "") .. stand
end
