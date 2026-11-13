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
-- Haken hinter dem guenstigsten Paket (0.87.2: die Schrift des Spiels kennt keinen Pfeil "←", es kam ein Kasten)
P.BEST_ICON = " |TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t"
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

-- Text anfuegen, mehrzeilige Texte (0.87.1: "Benutzen: ... Liste:\n- 16 ...\n- 4 ..." steht in einer Tooltip-Zeile)
-- in einzelne Zeilen geteilt
local function AddText(texts, t)
    if type(t) ~= "string" or Peon.IsSecret(t) then return end
    for part in (t .. "\n"):gmatch("(.-)\r?\n") do texts[#texts + 1] = part end
end

-- Linke Texte des Tooltips: aus den Tooltip-Daten, sonst aus den Textzeilen des Rahmens
function P.TooltipTexts(tooltip, data)
    local texts = {}
    if type(data) == "table" and not Peon.IsSecret(data) and type(data.lines) == "table" then
        for _, l in ipairs(data.lines) do
            if type(l) == "table" then AddText(texts, l.leftText) end
        end
        if P.Parse(texts) then return texts end
    end
    -- sonst (oder wenn die Daten keine Paketliste ergeben) die Textzeilen des Rahmens
    texts = {}
    local name = tooltip and tooltip.GetName and tooltip:GetName()
    local count = tooltip and tooltip.NumLines and tooltip:NumLines() or 0
    if not name then return texts end
    for i = 1, count do
        local fs = rawget(_G, name .. "TextLeft" .. i)
        AddText(texts, fs and fs.GetText and fs:GetText())
    end
    return texts
end

---------------------------------------------------------------------------
-- Name -> Gegenstand
---------------------------------------------------------------------------
-- Name zum Vergleichen: klein, ohne Artikel vorne, jedes Wort ohne Endung, dann ohne Leerzeichen zusammen.
-- 0.87.1: "Handvoll Kupferbolzen" (Liste) passt zu "Eine Hand voll Kupferbolzen" (Scan).
-- 0.87.2: auch gebeugte Woerter, "kleine leuchtende Splitter" passt zu "Kleiner leuchtender Splitter",
-- "große Astralessenzen" zu "Große Astralessenz".
P.ARTICLES = { "eine ", "einen ", "ein ", "a ", "an " }
local UPPER = { ["Ä"] = "ä", ["Ö"] = "ö", ["Ü"] = "ü" }

function P.Stem(word)
    for _, e in ipairs(P.ENDINGS) do
        if #word > #e + 2 and word:sub(-#e) == e then return word:sub(1, -#e - 1) end
    end
    return word
end

function P.Norm(name)
    local s = name:lower():gsub("\195[\132\150\156]", UPPER)
    for _, a in ipairs(P.ARTICLES) do
        if s:sub(1, #a) == a then s = s:sub(#a + 1); break end
    end
    local out = {}
    for w in s:gmatch("[^%s%-]+") do out[#out + 1] = P.Stem(w) end
    return table.concat(out)
end

local function Put(idx, name, key)
    local k = P.Norm(name)
    -- reine Nummern gehen vor Schluesseln mit Zusatz (Varianten), die Paketliste nennt nur den Grundnamen
    if idx[k] == nil or (type(key) == "number" and type(idx[k]) ~= "number") then idx[k] = key end
end

-- Verzeichnis Name (P.Norm) -> Schluessel. 0.87.3: aus den Namen aller Maerkte, nicht nur des Heimatmarkts.
-- Gegenstandsnummern gelten ueberall, der Preis kommt danach aus dem Heimatmarkt. Viele Eintraege (etwa aus dem
-- Peon Manager) haben keinen Namen, der steht dann oft in einem anderen Markt.
function P.BuildIndex()
    local idx = {}
    for _, market in pairs(ns.Data.Markets()) do
        if type(market) == "table" and type(market.items) == "table" then
            for key, e in pairs(market.items) do
                if type(e) == "table" and type(e.nm) == "string" then Put(idx, e.nm, key) end
            end
        end
    end
    return idx
end

-- Eintraege des Heimatmarkts ohne Namen: Namen beim Spiel nachfragen (nur bei einem Fehlgriff, je Gegenstand
-- hoechstens zweimal je Sitzung, beim ersten Mal laedt das Spiel den Gegenstand oft erst). Gefundene Namen
-- bleiben im Eintrag (nm), wie beim Scan.
P.tried = {}
function P.FillHome(idx)
    local market = ns.Data.Market()
    if not market or type(market.items) ~= "table" then return 0 end
    local got = 0
    for key, e in pairs(market.items) do
        if type(e) == "table" and e.nm == nil and (P.tried[key] or 0) < 2 then
            P.tried[key] = (P.tried[key] or 0) + 1
            local name = ns.GetItemInfo(ns.Data.LinkFromKey(key) or ns.Data.ItemID(key))
            if type(name) == "string" and name ~= "" and not Peon.IsSecret(name) then
                e.nm = name
                Put(idx, name, key)
                got = got + 1
            end
        end
    end
    return got
end

function P.Index()
    local now = GetTime and GetTime() or 0
    local c = P.cache
    local market = ns.WithHome(ns.Data.Market)
    local sig = tostring(market) .. "|" .. tostring(market and market.lastScan)
    if not c or c.sig ~= sig or now - c.at > P.INDEX_AGE then
        c = { idx = P.BuildIndex(), sig = sig, at = now }
        P.cache = c
    end
    return c.idx, c
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
    local idx, cache = P.Index()
    local cands = P.Candidates(name)
    local function Look()
        for _, c in ipairs(cands) do
            local key = idx[P.Norm(c)]
            if key ~= nil then return ns.Data.ItemID(key) end
        end
    end
    local id = Look()
    if id then return id end
    -- 0.87.3: einmal je Verzeichnis die Eintraege ohne Namen nachfragen
    if cache and not cache.filled then
        cache.filled = true
        if ns.WithHome(P.FillHome, idx) > 0 then
            id = Look()
            if id then return id end
        end
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
    if p.best then text = GREEN .. text .. "|r" .. P.BEST_ICON end
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
    if not known then
        mod:Dbg("Pakete: " .. #list .. " gelesen, kein Teil gefunden")
        return nil
    end
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
    if P.Best(list) and Peon.AddItemMenu then tooltip:AddLine(L.PACK_HINT, 0.6, 0.6, 0.6) end
    return true
end

---------------------------------------------------------------------------
-- Auf die Einkaufsliste (ab 0.88): im Peon-Gegenstandsmenue (Strg+Rechtsklick, Menu.lua) steht bei Kisten mit
-- Paketliste oben "Auf „Handelsauftrag“: 16× Kupferrohre". Ein einfacher Rechtsklick benutzt die Kiste, darum das
-- Menue (abgestimmt mit KarloDerBaer 13.11.2026).
---------------------------------------------------------------------------
-- Pakete des zuletzt gezeigten Tooltips, damit das Menue sie ohne neues Lesen kennt
function P.Remember(link, list)
    P.last = list and { id = tonumber(type(link) == "string" and link:match("item:(%d+)")), list = list } or nil
end

function P.ForItem(item)
    local l = P.last
    if type(item) ~= "table" or not l or l.id == nil or l.id ~= item.id then return nil end
    return l.list
end

-- Vorgeschlagenes Paket: das guenstigste, wenn noch etwas fehlt (nil = alles da oder kein Preis)
function P.Best(list)
    for _, p in ipairs(list or {}) do
        if p.best and p.id and p.need > 0 then return p end
    end
    return nil
end

-- Paket auf die Liste "Handelsauftrag" (wird bei Bedarf angelegt). Wunschmenge = Menge des Pakets, "Fehlt"
-- rechnet die Liste selbst gegen den Vorrat, wie bei den Materialien aus dem Berufsfenster.
function P.ToList(p)
    local B = ns.Buy
    if not B or not B.Lists or type(p) ~= "table" or not p.id then return false end
    local lists = B.Lists()
    local list
    for _, l in ipairs(lists) do if l.name == L.PACK_LIST_NAME then list = l end end
    if not list then
        list = { id = B.NewId(), name = L.PACK_LIST_NAME, pct = 10, u = time(), items = {} }
        lists[#lists + 1] = list
    end
    local e = list.items[p.id]
    if not e then
        local gk = tostring(list.id) .. "|" .. tostring(p.id)
        e = { u = ns.Shop.NextU(time(), B.Gone().items[gk]) }
        B.Gone().items[gk] = nil
    end
    e.name = e.name or ns.GetItemInfo(p.id) or p.name
    e.icon = e.icon or B.Icon(p.id)
    e.wish = math.max(tonumber(e.wish) or 0, p.n)
    B.Touch(e, "wish")
    list.items[p.id] = e
    mod:Print(L.PACK_LIST_ADDED:format(p.n, e.name, list.name))
    if B.view then B.Refresh() end
    return true, list
end

-- Eintrag im Gegenstandsmenue (Menu.lua ruft das zuerst auf)
function P.AddMenu(root, item)
    local p = P.Best(P.ForItem(item))
    if not p then return false end
    root:CreateButton(L.PACK_MENU:format(L.PACK_LIST_NAME, p.n, p.name), function() mod:Call("Menue", P.ToList, p) end)
    if root.CreateDivider then root:CreateDivider() end
    return true
end
