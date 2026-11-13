-- Peon_Broker - Pack.lua
-- Paketvergleich im Tooltip (ab 0.87): Gegenstaende wie "Abgefangene Kiste" listen Pakete zur Auswahl, z. B.
--   - 16 Handvoll Kupferbolzen
--   - 16 Kupferrohre
--   - 4 Kupfermodulatoren
-- Broker liest diese Zeilen, sucht die Teile ueber den Namen und zeigt, was jedes Paket kostet. Was schon in den
-- Taschen liegt, kostet nichts, es zaehlt nur der fehlende Rest. Das guenstigste Paket ist markiert.
--   Broker · Pakete (Kosten)
--     4× Kupfermodulatoren        1s 10c  ←
--     16× Kupferrohre             vorhanden
--     16× Handvoll Kupferbolzen   kein Preis
-- Preis je Stueck wie im Berufsfenster: guenstigster Kaufpreis (Haendler oder AH, Heimatmarkt).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local P = {}
ns.Pack = P

local GREY, GREEN = "|cff999999", "|cff60e060"
P.MIN_LINES = 2                 -- erst ab zwei Paketen ist es eine Auswahl
P.INDEX_AGE = 60                -- Namensverzeichnis spaetestens nach so vielen Sekunden neu aufbauen
-- Mehrzahl im Tooltip, Einzahl im Namen: "Kupferrohre" -> "Kupferrohr", "Kupfermodulatoren" -> "Kupfermodulator",
-- "Copper Tubes" -> "Copper Tube". Laengste Endung zuerst.
P.ENDINGS = { "en", "er", "es", "e", "n", "s" }

local function Plain(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Eine Zeile "- 16 Kupferrohre" -> 16, "Kupferrohre" (sonst nil)
function P.ParseLine(text)
    if type(text) ~= "string" or Peon.IsSecret(text) then return nil end
    local n, name = Plain(text):match("^%s*%-%s*(%d+)%s*[xX]?%s+(.-)%s*$")
    n = tonumber(n)
    if not n or n < 1 or not name or name == "" then return nil end
    return n, name
end

-- Pakete aus Tooltip-Zeilen (Liste von Texten): { { n, name }, ... } oder nil, wenn es weniger als zwei sind
function P.Parse(texts)
    local list = {}
    for _, t in ipairs(texts or {}) do
        local n, name = P.ParseLine(t)
        if n then list[#list + 1] = { n = n, name = name } end
    end
    if #list < P.MIN_LINES then return nil end
    return list
end

-- Linke Texte des Tooltips: aus den Tooltip-Daten, sonst aus den Textzeilen des Rahmens
function P.TooltipTexts(tooltip, data)
    local texts = {}
    if type(data) == "table" and not Peon.IsSecret(data) and type(data.lines) == "table" then
        for _, l in ipairs(data.lines) do
            if type(l) == "table" and type(l.leftText) == "string" then texts[#texts + 1] = l.leftText end
        end
        if #texts > 0 then return texts end
    end
    local name = tooltip and tooltip.GetName and tooltip:GetName()
    local count = tooltip and tooltip.NumLines and tooltip:NumLines() or 0
    if not name then return texts end
    for i = 1, count do
        local fs = rawget(_G, name .. "TextLeft" .. i)
        local t = fs and fs.GetText and fs:GetText()
        if type(t) == "string" then texts[#texts + 1] = t end
    end
    return texts
end

---------------------------------------------------------------------------
-- Name -> Gegenstand
---------------------------------------------------------------------------
-- Verzeichnis kleingeschriebener Name -> Schluessel aus den Scan-Daten des Heimatmarkts. Reine Nummern gehen vor
-- Schluesseln mit Zusatz (Varianten), weil die Paketliste nur den Grundnamen nennt.
function P.BuildIndexHome()
    local market = ns.Data.Market()
    local idx = {}
    if not market or type(market.items) ~= "table" then return idx, market end
    for key, e in pairs(market.items) do
        if type(e) == "table" and type(e.nm) == "string" then
            local k = e.nm:lower()
            if idx[k] == nil or (type(key) == "number" and type(idx[k]) ~= "number") then idx[k] = key end
        end
    end
    return idx, market
end

function P.Index()
    local now = GetTime and GetTime() or 0
    local c = P.cache
    local market = ns.WithHome(ns.Data.Market)
    local sig = tostring(market) .. "|" .. tostring(market and market.lastScan)
    if not c or c.sig ~= sig or now - c.at > P.INDEX_AGE then
        c = { idx = (ns.WithHome(P.BuildIndexHome)), sig = sig, at = now }
        P.cache = c
    end
    return c.idx
end

-- Moegliche Namen: wie geschrieben, dann ohne Mehrzahl-Endung
function P.Candidates(name)
    local out = { name }
    for _, e in ipairs(P.ENDINGS) do
        if #name > #e + 2 and name:sub(-#e) == e then out[#out + 1] = name:sub(1, -#e - 1) end
    end
    return out
end

-- Gegenstandsnummer zu einem Namen aus dem Tooltip (nil = unbekannt)
function P.Find(name)
    local idx = P.Index()
    local cands = P.Candidates(name)
    for _, c in ipairs(cands) do
        local key = idx[c:lower()]
        if key ~= nil then return ns.Data.ItemID(key) end
    end
    -- nicht gescannt: das Spiel kennt den Namen, wenn der Gegenstand schon einmal geladen war
    for _, c in ipairs(cands) do
        local _, link = ns.GetItemInfo(c)
        local id = type(link) == "string" and not Peon.IsSecret(link) and tonumber(link:match("item:(%d+)"))
        if id then return id end
    end
    return nil
end

---------------------------------------------------------------------------
-- Rechnung
---------------------------------------------------------------------------
-- Je Paket: id, have (Taschen), need (fehlt), unit (Kaufpreis je Stueck), cost (nil = kein Preis), best
function P.Calc(list)
    local best
    for i, p in ipairs(list) do
        p.i = i
        p.id = P.Find(p.name)
        p.have, p.need, p.unit, p.cost = 0, p.n, nil, nil
        if p.id then
            local _, bags = ns.Craft.Stock(p.id)
            p.have = bags or 0
            p.need = math.max(0, p.n - p.have)
            p.unit = ns.Craft.BuyPrice(p.id)
            if p.need == 0 then p.cost = 0
            elseif p.unit then p.cost = p.unit * p.need end
        end
        if p.cost and (not best or p.cost < best) then best = p.cost end
    end
    for _, p in ipairs(list) do p.best = best ~= nil and p.cost == best end
    -- guenstigstes zuerst, ohne Preis ans Ende, sonst Reihenfolge des Tooltips
    table.sort(list, function(a, b)
        if (a.cost ~= nil) ~= (b.cost ~= nil) then return a.cost ~= nil end
        if a.cost and a.cost ~= b.cost then return a.cost < b.cost end
        return a.i < b.i
    end)
    return list
end

function P.RightText(p)
    local text
    if p.cost == 0 then text = L.PACK_HAVE
    elseif p.cost then
        text = ns.Tooltip.Money(p.cost)
        if p.have > 0 then text = text .. " " .. GREY .. L.PACK_MISSING:format(p.need) .. "|r" end
    else
        text = GREY .. L.PACK_NO_PRICE .. "|r"
        if p.have > 0 then text = text .. " " .. GREY .. L.PACK_HAVE_N:format(p.have) .. "|r" end
    end
    if p.best then text = GREEN .. text .. "|r " .. GREEN .. "←|r" end
    return text
end

-- Pakete fuer einen Tooltip lesen (vor dem Anfuegen eigener Zeilen) und rechnen, nil = keine Paketliste
function P.FromTooltip(tooltip, data)
    local db = mod.db
    if not db or not db.tooltipShow or db.tooltipPacks == false then return nil end
    local list = P.Parse(P.TooltipTexts(tooltip, data))
    if not list then return nil end
    P.Calc(list)
    local known = false
    for _, p in ipairs(list) do if p.id then known = true end end
    if not known then return nil end
    return list
end

-- Block ausgeben. Rueckgabe true, wenn etwas dazukam
function P.Render(tooltip, list)
    if not list then return false end
    tooltip:AddLine(" ")
    tooltip:AddLine(("|c%sBroker|r · %s"):format(Peon.COLOR, L.PACK_TITLE), 1, 1, 1)
    for _, p in ipairs(list) do
        tooltip:AddDoubleLine("  " .. p.n .. "× " .. p.name, P.RightText(p), 0.75, 0.75, 0.75, 1, 1, 1)
    end
    return true
end
