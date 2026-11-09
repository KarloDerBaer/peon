-- Peon_Broker - Cut.lua
-- Umbau U2 (ab 0.43, Konzept Peon_Broker_Umbau.md, Abschnitt 5.3): Anteil des Auktionshauses je Markt.
-- Bisher rechnete Broker ueberall mit 5 % (D.CUT, 30.09.2026 an Rechnungen des Fraktionshauses bestaetigt).
-- Das neutrale Haus nahm im klassischen Spiel mehr. Broker misst den Anteil jetzt selbst aus den
-- Verkaufsrechnungen in der Post (GetInboxInvoiceInfo, Art "seller": Gebot/Sofortkauf und Anteil).
--
-- Welches Haus? Am Absender des Briefs (im Spiel gesehen: "Auktionshaus der Allianz"):
--   enthaelt "Allianz"/"Alliance" -> Alliance, "Horde" -> Horde, sonst Neutral.
-- Gespeichert in PeonBrokerDB.cut[Fraktion] = { r = Anteil (Median), n = Rechnungen, t, s = letzte Anteile }.
-- D.Cut(markt) liefert den gemessenen Anteil, sonst 5 %. D.CutSure(markt) sagt, ob er gemessen ist.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local D = ns.Data

local C = {}
ns.Cut = C

C.DEFAULT = D.CUT     -- 5 %
C.KEEP = 10           -- so viele Anteile je Haus merken
C.MIN_PRICE = 2000    -- kleinere Verkaeufe (unter 20 Silber) nicht messen, die Rundung verfaelscht sie
C.seen = {}           -- schon gezaehlte Rechnungen dieser Sitzung (Absender|Betreff|Preis|Anteil)

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

-- Fraktion des Hauses aus dem Absender, nil wenn es kein Auktionshaus ist
function C.FactionOfSender(sender)
    if type(sender) ~= "string" or Peon.IsSecret(sender) then return nil end
    local s = sender:lower()
    if s:find("allianz", 1, true) or s:find("alliance", 1, true) then return "Alliance" end
    if s:find("horde", 1, true) then return "Horde" end
    if s:find("auktionshaus", 1, true) or s:find("auction house", 1, true) then return "Neutral" end
    return nil
end

-- Fraktion eines Markts ("Realm / Fraktion")
function C.FactionOfMarket(key)
    if type(key) ~= "string" then return nil end
    return key:match(" / ([^/]+)$")
end

local function Store()
    local acc = mod.acc
    if type(acc) ~= "table" then return {} end
    if type(acc.cut) ~= "table" then acc.cut = {} end
    return acc.cut
end

local function Median(list)
    local s = {}
    for i, v in ipairs(list) do s[i] = v end
    table.sort(s)
    local n = #s
    if n == 0 then return nil end
    if n % 2 == 1 then return s[(n + 1) / 2] end
    return (s[n / 2] + s[n / 2 + 1]) / 2
end

-- Eine Rechnung zaehlen. Rueckgabe: true, wenn gezaehlt
function C.Record(faction, price, cut, id)
    if not faction or not Num(price) or not Num(cut) or price < C.MIN_PRICE or cut < 0 or cut >= price then return false end
    if id then
        if C.seen[id] then return false end
        C.seen[id] = true
    end
    local st = Store()
    local e = st[faction]
    if type(e) ~= "table" then e = { n = 0, s = {} }; st[faction] = e end
    if type(e.s) ~= "table" then e.s = {} end
    table.insert(e.s, cut / price)
    while #e.s > C.KEEP do table.remove(e.s, 1) end
    e.n = (e.n or 0) + 1
    e.r = Median(e.s)
    e.t = time and time() or 0
    mod:Dbg(("Anteil %s: %.1f %% (%d Rechnungen)"):format(faction, e.r * 100, e.n))
    return true
end

-- Alle Verkaufsrechnungen im Briefkasten lesen (nur lesen, nichts oeffnen)
function C.ReadInbox()
    local count = rawget(_G, "GetInboxNumItems")
    local header = rawget(_G, "GetInboxHeaderInfo")
    local invoice = rawget(_G, "GetInboxInvoiceInfo")
    if type(count) ~= "function" or type(header) ~= "function" or type(invoice) ~= "function" then return 0 end
    local ok, n = pcall(count)
    if not ok or not Num(n) then return 0 end
    local got = 0
    for i = 1, n do
        local okh, _, _, sender, subject = pcall(header, i)
        local faction = okh and C.FactionOfSender(sender)
        if faction then
            local oki, kind, _, _, bid, buyout, _, consignment = pcall(invoice, i)
            if oki and kind == "seller" then
                local price = (Num(bid) and bid > 0) and bid or buyout
                local id = ("%s|%s|%s|%s"):format(tostring(sender), tostring(subject), tostring(price), tostring(consignment))
                if C.Record(faction, price, consignment, id) then got = got + 1 end
            end
        end
    end
    return got
end

-- Anteil eines Markts (Standard: Markt, in dem gerade gerechnet wird)
function D.Cut(market)
    local f = C.FactionOfMarket(market or ns.MarketKey())
    local e = f and Store()[f]
    if type(e) == "table" and Num(e.r) and e.r > 0 and e.r < 0.5 then return e.r end
    return C.DEFAULT
end

-- Ist der Anteil gemessen? Fraktionshaeuser gelten seit 30.09.2026 als bestaetigt (5 %)
function D.CutSure(market)
    local f = C.FactionOfMarket(market or ns.MarketKey())
    local e = f and Store()[f]
    if type(e) == "table" and Num(e.r) then return true end
    return f ~= "Neutral"
end

-- Text fuer Pruefung und Quellen: "Allianz 5,0 % (12 Rechnungen) · Neutral nicht gemessen"
function C.Report()
    local st = Store()
    local parts = {}
    for _, f in ipairs({ "Alliance", "Horde", "Neutral" }) do
        local e = st[f]
        if type(e) == "table" and Num(e.r) then
            parts[#parts + 1] = L.CUT_MEASURED:format(L["CUT_" .. f:upper()] or f, ("%.1f"):format(e.r * 100):gsub("%.", ","), e.n or 0)
        end
    end
    if not (type(st.Neutral) == "table" and Num(st.Neutral.r)) then parts[#parts + 1] = L.CUT_NEUTRAL_UNKNOWN end
    return table.concat(parts, " · ")
end

function C.Init()
    mod:RegisterEvent("MAIL_INBOX_UPDATE", function() mod:Call("Anteil", C.ReadInbox) end)
end
