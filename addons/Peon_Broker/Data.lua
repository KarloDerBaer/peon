-- Peon_Broker - Data.lua
-- Preisdatenbank und Rechenmodell (siehe Peon_Broker_Rechenmodell.md im Projektordner, F1-F20).
-- Strikt getrennt nach Markt (Realm-Name / Fraktion).
--
-- PeonBrokerDB.dataVersion = 2
-- PeonBrokerDB.markets["Classic Beta PvE / Alliance"] = {
--     lastScan, prevScan, scans, lastListings, lastItems, compactDay, compactDays,
--     items = {
--         [2770] = {
--             m = AHmin, md = AHmedian, q = AHmenge, n = AHanz, t = ZEIT,   -- letzter Scan (je Stueck)
--             pm, pmd, pq, pt = dieselben Werte vom vorherigen Scan (_vor, fuer den Trend),
--             gone = Zeitpunkt, falls der Gegenstand im letzten Scan fehlte,
--             d = "Tag:SummeMin:SummeMedian:SummeMenge:AnzahlScans;...",     -- Tageswerte (F7)
--             w = "Woche:Min:Median:Menge:Tage;...",                         -- Wochenwerte (aeltere Tage)
--         },
--         nm = Name, ql = Qualitaet (ab 0.7, fuer die Suche im Broker-Fenster),
--         lv = "Preis:Menge;..." guenstigste 5 Preisstufen des letzten Scans (ab 0.13, Schnaeppchen),
--         ["12345:1047"] = { ... },   -- Ausruestung mit Zusatz ("... des Baeren"): itemID:suffixID
--     },
-- }
-- PeonBrokerDB.commodity[key] = true/false   -- Warenart, vom Spiel bei geoeffnetem Auktionshaus

local ADDON_NAME, ns = ...
local mod = ns.mod

local D = {}
ns.Data = D

D.VERSION  = 2
D.CUT      = 0.05                              -- ANTEIL (aus den Rechnungen bestaetigt, 30.09.2026)
D.EG_SATZ  = { [2] = 0.05, [8] = 0.20, [24] = 0.60 }   -- Gebuehrensatz je Laufzeit (Stunden), nur zur Anzeige
D.EG_FAKTOR = { [2] = 1, [8] = 4, [24] = 12 }  -- Einstellgebuehr = 2-Std.-Gebuehr (5 %, abgerundet) x Faktor
D.DUR_INDEX = { [2] = 1, [8] = 2, [24] = 3 }   -- Laufzeit -> Index fuer die Gebuehr-Funktionen des Spiels
D.WEEKS    = 26                                -- Wochenwerte so lange aufbewahren
D.FEW      = 3                                 -- "Wenig Angebote": weniger als 3 Angebote

---------------------------------------------------------------------------
-- Grundlagen
---------------------------------------------------------------------------
-- Tagesnummer nach der Uhr des PCs (Mitternacht bis Mitternacht)
function D.Day(t)
    local d = date("*t", t or time())
    return math.floor(time({ year = d.year, month = d.month, day = d.day, hour = 12 }) / 86400)
end

function D.Markets()
    local acc = mod.acc
    if type(acc.markets) ~= "table" then acc.markets = {} end
    return acc.markets
end

-- Markt holen (Standard: aktueller Markt); create = anlegen, falls nicht vorhanden
function D.Market(key, create)
    key = key or ns.MarketKey()
    local markets = D.Markets()
    local m = markets[key]
    if type(m) ~= "table" then
        if not create then return nil, key end
        m = { items = {}, scans = 0 }
        markets[key] = m
    end
    if type(m.items) ~= "table" then m.items = {} end
    return m, key
end

function D.DeleteMarket(key)
    D.Markets()[key] = nil
end

-- Neues Speicherformat: alte Preisdaten einmalig loeschen (mit KarloDerBaer abgestimmt, 30.09.2026)
function D.Migrate(acc)
    if acc.dataVersion ~= D.VERSION then
        acc.markets = {}
        acc.deposits = nil
        acc.dataVersion = D.VERSION
        acc.migrated = true
    end
    acc.tooltipSales = nil   -- Einstellung entfaellt (Abverkauf gestrichen)
    -- ab 0.28 (Aufraeumen, mit KarloDerBaer abgestimmt 06.10.2026): alte Listen fuers Buch (Buch ist in Peon_Ledger),
    -- entfallene Einstellungen und der erledigte Abgleich der Einstellgebuehr
    acc.posted, acc.cancelled, acc.bought = nil, nil, nil
    acc.buyMode, acc.dealMaxAge, acc.depositCheck = nil, nil, nil
    -- Fehlersuch-Protokolle nur behalten, solange /broker debug an ist
    if acc.debug ~= true then
        acc.radarLog, acc.keyLog, acc.showLog, acc.aucLog, acc.radarStats = nil, nil, nil, nil, nil
    end
end

---------------------------------------------------------------------------
-- Ausruestung mit Zusatz (ab 0.28, mit KarloDerBaer abgestimmt 06.10.2026)
-- Forever legt den Zusatz nicht im Link-Feld 7 ab (sondern als Bonus-Nummer), Scan, Taschen und Links liefern aber
-- den vollen Namen ("Gleissendes Claymore der Willenskraft"). Hat ein Gegenstand Varianten (market.variants[itemID]),
-- ist der Schluessel "itemID:voller Name"; sonst wie bisher die itemID. Der Scan erkennt Varianten (mehrere Namen,
-- Name weicht vom Grundnamen ab oder der Link hat Bonus-Nummern) und loescht dann den alten, gemischten Eintrag.
---------------------------------------------------------------------------
function D.HasVariants(id)
    if not (mod and type(mod.acc) == "table") or type(id) ~= "number" then return false end
    local m = D.Market()
    return m ~= nil and type(m.variants) == "table" and m.variants[id] == true
end

-- Name aus einem Link ("[...]"), nil bei geheimen Werten
function D.LinkName(link)
    if type(link) ~= "string" or Peon.IsSecret(link) then return nil end
    local name = link:match("|h%[(.-)%]|h") or link:match("%[(.-)%]")
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

-- Hat der Link Bonus-Nummern? (Feld 13 = Anzahl, wie in Retail; in Forever stehen dort die Zusaetze)
function D.LinkHasBonus(link)
    if type(link) ~= "string" or Peon.IsSecret(link) then return false end
    local body = link:match("item:([%-%d:]+)")
    if not body then return false end
    local f = {}
    for v in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
    return (tonumber(f[13]) or 0) > 0
end

-- Schluessel einer Variante (voller Name)
function D.VariantKey(id, name) return id .. ":" .. name end

-- Ist der Schluessel eine Variante nach Namen? (nicht die alte Form "itemID:Zusatznummer")
function D.IsVariantKey(key)
    return type(key) == "string" and key:match("^%d+:%-?%d+$") == nil and key:match("^%d+:") ~= nil
end

-- Alle Varianten-Schluessel eines Gegenstands im aktuellen Markt (zwischengespeichert, neu bei neuen Eintraegen)
function D.VariantKeys(id)
    local m = D.Market()
    if not m or not D.HasVariants(id) then return {} end
    local idx = D.vIndex
    if not idx or idx.market ~= m then
        idx = { market = m, map = {} }
        for key in pairs(m.items) do
            if D.IsVariantKey(key) then
                local vid = D.ItemID(key)
                idx.map[vid] = idx.map[vid] or {}
                table.insert(idx.map[vid], key)
            end
        end
        D.vIndex = idx
    end
    return idx.map[id] or {}
end

-- Schluessel aus einem Gegenstandslink: itemID (Zahl), "itemID:suffixID" bei Zusatz im Link-Feld 7 (alte Form)
-- oder ab 0.28 "itemID:voller Name" bei Gegenstaenden mit Varianten
function D.KeyFromLink(link)
    if type(link) ~= "string" or Peon.IsSecret(link) then return nil end
    local body = link:match("item:([%-%d:]+)")
    if not body then return nil end
    local f = {}
    for v in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
    local id = tonumber(f[1])
    if not id then return nil end
    local suffix = tonumber(f[7])
    if suffix and suffix ~= 0 then return id .. ":" .. suffix, id end
    if D.HasVariants(id) then
        local name = D.LinkName(link)
        if name then return D.VariantKey(id, name), id end
    end
    return id, id
end

function D.Lookup(key)
    local market = D.Market()
    if not market or key == nil then return nil, market end
    return market.items[key], market
end

---------------------------------------------------------------------------
-- Beim Scan: Angebote eines Gegenstands (flache Liste { A_EP, A_MENGE, ... }) auswerten (F2-F5)
---------------------------------------------------------------------------
function D.Summarize(list)
    local n = math.floor(#list / 2)
    if n < 1 then return nil end
    local idx, qty = {}, 0
    for i = 1, n do
        idx[i] = i * 2 - 1
        qty = qty + list[i * 2]
    end
    table.sort(idx, function(a, b) return list[a] < list[b] end)
    local min = list[idx[1]]
    -- Preis des Stuecks Nr. k (Stueck fuer Stueck durchgezaehlt)
    local function PriceAt(k)
        local seen = 0
        for _, i in ipairs(idx) do
            seen = seen + list[i + 1]
            if seen >= k then return list[i] end
        end
        return list[idx[#idx]]
    end
    local median
    if qty % 2 == 1 then
        median = PriceAt((qty + 1) / 2)
    else
        median = (PriceAt(qty / 2) + PriceAt(qty / 2 + 1)) / 2
    end
    return min, median, qty, n
end

---------------------------------------------------------------------------
-- Verlauf als Text
---------------------------------------------------------------------------
function D.ParseDays(s)
    local list = {}
    if type(s) ~= "string" or s == "" then return list end
    for part in s:gmatch("[^;]+") do
        local day, a, b, c, n = part:match("^(%-?%d+):([%d%.]+):([%d%.]+):([%d%.]+):(%d+)$")
        if day then list[#list + 1] = { tonumber(day), tonumber(a), tonumber(b), tonumber(c), tonumber(n) } end
    end
    return list
end

-- Ganze Zahlen mit %.0f: %d geht im Forever-Lua nur bis 2^31 (Fehler "integer overflow" bei Angeboten
-- zum Hoechstpreis von fast 5 Mio. Gold, gefunden 22.10.2026)
local function Num(x)
    if x == math.floor(x) then return ("%.0f"):format(x) end
    return ("%.2f"):format(x)
end

function D.JoinDays(list)
    local parts = {}
    for _, e in ipairs(list) do
        parts[#parts + 1] = ("%d:%s:%s:%s:%d"):format(e[1], Num(e[2]), Num(e[3]), Num(e[4]), e[5])
    end
    return table.concat(parts, ";")
end

-- Ergebnis eines Scans eintragen (F6, F7); name und quality (ab 0.7) fuer die Suche im Broker-Fenster
function D.Record(market, key, min, median, qty, n, t, name, quality)
    local e = market.items[key]
    if type(e) ~= "table" then e = {}; market.items[key] = e end
    if e.t and e.t ~= t then
        e.pm, e.pmd, e.pq, e.pt = e.m, e.md, e.q, e.t
    end
    e.m, e.md, e.q, e.n, e.t, e.gone = min, median, qty, n, t, nil
    if type(name) == "string" and name ~= "" and not Peon.IsSecret(name) then e.nm = name end
    if type(quality) == "number" and not Peon.IsSecret(quality) then e.ql = quality end
    local day = D.Day(t)
    local d = D.ParseDays(e.d)
    local last = d[#d]
    if last and last[1] == day then
        last[2], last[3], last[4], last[5] = last[2] + min, last[3] + median, last[4] + qty, last[5] + 1
    else
        d[#d + 1] = { day, min, median, qty, 1 }
    end
    e.d = D.JoinDays(d)
    return e
end

-- Gegenstaende, die beim vorherigen Scan da waren und jetzt fehlen: keine Angebote mehr
-- (ab 0.15 auch solche, die nur eine Live-Abfrage seitdem gesehen hat)
function D.MarkGone(market, prevScan, t)
    if not prevScan or prevScan == t then return 0 end
    local count = 0
    for _, e in pairs(market.items) do
        if type(e) == "table" and not e.gone and e.t ~= t and (e.t == prevScan or (e.lt and e.lt > (e.t or 0))) then
            e.pm, e.pmd, e.pq, e.pt = e.m, e.md, e.q, e.t
            e.q, e.n, e.gone, e.lv = 0, 0, t, nil
            count = count + 1
        end
    end
    return count
end

---------------------------------------------------------------------------
-- Live-Ergebnis in den aktuellen Stand schreiben (ab 0.15, mit KarloDerBaer abgestimmt 30.09.2026)
--   Aktueller Stand (m, md, q, lv, gone) kommt aus der Live-Abfrage, Zeit in e.lt.
--   Verlauf (d, w), Zahl der Scans, Vorwerte fuer den Trend (pm, pmd, pq, pt) und e.t bleiben reine Scan-Werte.
--   rows = { { price, qty, own }, ... } (Preis je Stueck, eigene Angebote in qty enthalten)
---------------------------------------------------------------------------
function D.ApplyLive(key, rows, t, name, quality)
    local market = D.Market()
    if not market or key == nil or type(rows) ~= "table" then return nil end
    t = t or time()
    D.liveStamp = (D.liveStamp or 0) + 1
    if ns.HasListeners and ns.HasListeners() and not rows.foreign then   -- ab 0.30: fuer Peon_Client
        ns.Notify("live", key, rows, t, { market = ns.MarketKey(), commodity = rows.commodity and true or D.IsCommodity(key), partial = rows.partial and true or false })
    end
    local e = market.items[key]
    local flat = {}
    for _, r in ipairs(rows) do
        if type(r.price) == "number" and type(r.qty) == "number" and r.qty > 0 then
            flat[#flat + 1] = r.price; flat[#flat + 1] = r.qty
        end
    end
    if #flat == 0 then
        if rows.partial or rows.foreign then return e end   -- Spiel laedt noch / fremde Ergebnisse: keine Aussage (ab 0.20.1)
        -- keine Angebote mehr: wie beim Scan "weg", letzte Preise bleiben
        if type(e) == "table" and not e.gone then
            e.q, e.n, e.lv, e.gone = 0, 0, nil, t
        end
        if type(e) == "table" and ns.Sales then ns.Sales.OnLive(e, rows, t) end   -- Absatz: alles weg (ab 0.23)
        return e
    end
    if type(e) ~= "table" then e = {}; market.items[key] = e; D.vIndex = nil end
    local min, median, qty = D.Summarize(flat)
    if rows.partial and e.md then
        -- nur ein Teil der Angebote (ab 0.20): Minimum und guenstigste Stufen stimmen, Median und Menge nicht ->
        -- die bisherigen Werte behalten (sonst faellt der Median und Schnaeppchen/Vorschlag werden falsch)
        e.m, e.gone, e.lt = min, nil, t
        if not e.q or e.q < qty then e.q = qty end
    else
        e.m, e.md, e.q, e.gone, e.lt = min, median, qty, nil, t
    end
    e.lv = D.Levels(flat)
    if e.n == nil or e.n == 0 then e.n = #rows end
    if type(name) == "string" and name ~= "" and not Peon.IsSecret(name) and not e.nm then e.nm = name end
    if type(quality) == "number" and not Peon.IsSecret(quality) and not e.ql then e.ql = quality end
    if type(rows.link) == "string" and not e.lk and D.IsVariantKey(key) then e.lk = rows.link end   -- ab 0.28
    if ns.Sales then ns.Sales.OnLive(e, rows, t) end   -- Absatz: mit der vorigen Abfrage vergleichen (ab 0.23)
    return e
end

---------------------------------------------------------------------------
-- Neuerer Stand vom Peon Manager (ab 0.36, Wunsch KarloDerBaer 07.11.2026)
--   Der Manager schickt ueber Peon_Bridge die Preise seines neuesten vollstaendigen Stands (Blizzard-API oder Scan).
--   Ist er neuer als Scan und Live-Abfrage eines Gegenstands, gilt er wie eine Live-Abfrage: aktueller Stand
--   (m, md, q, n, gone), Zeit in e.lt. Verlauf, Trend und e.t bleiben reine Scan-Werte. Die guenstigsten Stufen (lv)
--   kennt der Manager nicht, sie fallen weg, damit keine alten Schnaeppchen gemeldet werden.
--   market.mgrAt, mgrSrc, mgrItems: Zeit, Herkunft und Zahl der Gegenstaende fuer die Anzeige.
---------------------------------------------------------------------------
function D.ManagerState(key)
    local c = Peon:GetModule("bridge")
    if not c or type(c.Current) ~= "function" then return nil end
    local ok, t, src, items = pcall(c.Current, c, key or ns.MarketKey())
    if ok and type(t) == "number" and type(items) == "table" then return t, src, items end
    return nil
end

local function Seen(e) return math.max(e.t or 0, e.lt or 0) end

-- Rueckgabe: Zahl der Gegenstaende, deren aktueller Stand neu ist. key = Markt (ohne: der aktuelle)
function D.ApplyManager(key)
    local t, src, items = D.ManagerState(key)
    if not t then return 0 end
    local market = D.Market(key, true)
    if market.mgrAt and market.mgrAt >= t then return 0 end   -- schon eingetragen
    local cur, total, count = {}, 0, 0
    for key, s in pairs(items) do
        if type(key) == "string" and key:match("^%d+$") then key = tonumber(key) end
        local mi, md, q, n
        if type(s) == "string" then mi, md, q, n = s:match("^(%d+):(%d+):(%d+):(%d+)$") end
        if mi and tonumber(q) > 0 then
            cur[key] = true
            total = total + 1
            local e = market.items[key]
            if type(e) ~= "table" then e = {}; market.items[key] = e; D.vIndex = nil end
            if Seen(e) < t then
                e.m, e.md, e.q, e.n, e.gone, e.lt, e.lv = tonumber(mi), tonumber(md), tonumber(q), tonumber(n), nil, t, nil
                count = count + 1
            end
        end
    end
    -- Nicht mehr im Stand: keine Angebote mehr, letzte Preise bleiben (wie beim Scan)
    for key, e in pairs(market.items) do
        if type(e) == "table" and not cur[key] and not e.gone and e.m and Seen(e) < t then
            e.q, e.n, e.lv, e.gone = 0, 0, nil, t
        end
    end
    market.mgrAt, market.mgrSrc, market.mgrItems = t, src, total
    D.liveStamp = (D.liveStamp or 0) + 1
    return count
end

-- ab 0.80 (KarloDerBaer 12.11.2026): beim Anmelden Heimatmarkt und neutralen Markt. Vorher nur der Markt, in dem
-- man gerade stand (beim Anmelden praktisch immer die Heimat), die Preise des neutralen Markts aus der Blizzard-API
-- kamen so nie an. Der neutrale Markt entsteht nur, wenn der Manager Werte fuer ihn hat.
function D.ApplyManagerAll()
    local n, seen = 0, {}
    for _, key in ipairs({ ns.HomeMarketKey(), ns.NeutralMarketKey(), ns.MarketKey() }) do
        if key and not seen[key] then
            seen[key] = true
            n = n + D.ApplyManager(key)
        end
    end
    return n
end

-- Zeit der neuesten Preise dieses Markts: eigener Scan oder Stand vom Manager
function D.DataAt(market)
    if type(market) ~= "table" then return nil end
    local a, b = market.lastScan, market.mgrAt
    if a and b then return math.max(a, b) end
    return a or b
end

-- Zuletzt mit Angeboten gesehen (Scan oder live)
function D.Seen(e)
    if type(e) ~= "table" then return nil end
    local t = e.t
    if e.lt and (not t or e.lt > t) then t = e.lt end
    return t
end

-- Alte Tageswerte zu Wochenwerten verdichten, sehr alte Werte und leere Eintraege loeschen
function D.CompactItem(e, keepDays, today)
    local d = D.ParseDays(e.d)
    local w = D.ParseDays(e.w)
    local keep = {}
    for _, x in ipairs(d) do
        if x[1] > today - keepDays then
            keep[#keep + 1] = x
        else
            -- Tagesmittel in die Woche einrechnen (Mittel der Tagesmittel)
            local week = math.floor(x[1] / 7)
            local mn, md, q = x[2] / x[5], x[3] / x[5], x[4] / x[5]
            local found
            for _, y in ipairs(w) do if y[1] == week then found = y end end
            if found then
                local c = found[5]
                found[2] = (found[2] * c + mn) / (c + 1)
                found[3] = (found[3] * c + md) / (c + 1)
                found[4] = (found[4] * c + q) / (c + 1)
                found[5] = c + 1
            else
                w[#w + 1] = { week, mn, md, q, 1 }
                table.sort(w, function(a, b) return a[1] < b[1] end)
            end
        end
    end
    local wkeep = {}
    for _, y in ipairs(w) do if y[1] > math.floor(today / 7) - D.WEEKS then wkeep[#wkeep + 1] = y end end
    e.d = #keep > 0 and D.JoinDays(keep) or nil
    e.w = #wkeep > 0 and D.JoinDays(wkeep) or nil
    return e.d ~= nil or e.w ~= nil
end

function D.Compact(market, keepDays, today)
    today = today or D.Day()
    local drop = {}
    local now = time()
    for key, e in pairs(market.items) do
        if type(e) ~= "table" or not D.CompactItem(e, keepDays, today) then drop[#drop + 1] = key
        elseif ns.Sales and ns.Sales.Prune then ns.Sales.Prune(e, now) end   -- ab 0.28: alte Absatz-Momentaufnahmen weg
    end
    for _, key in ipairs(drop) do market.items[key] = nil end
    return #drop
end

---------------------------------------------------------------------------
-- Verlauf bei Anzeige (F8, F9)
---------------------------------------------------------------------------
-- Mittel der Tagesmittel in (fromDay, toDay]; Rueckgabe min, median, menge, anzahl Tage
local function Window(d, fromDay, toDay)
    local sm, smd, sq, n = 0, 0, 0, 0
    for _, x in ipairs(d) do
        if x[1] > fromDay and x[1] <= toDay then
            sm, smd, sq, n = sm + x[2] / x[5], smd + x[3] / x[5], sq + x[4] / x[5], n + 1
        end
    end
    if n == 0 then return nil, nil, nil, 0 end
    return sm / n, smd / n, sq / n, n
end

-- W7: heute und die 6 Tage davor; W7_vortag: gestern und die 6 Tage davor
function D.Week(e, today)
    today = today or D.Day()
    local d = D.ParseDays(type(e) == "table" and e.d)
    local r = {}
    r.min, r.median, r.qty, r.days = Window(d, today - 7, today)
    r.pmin, r.pmedian, r.pqty, r.pdays = Window(d, today - 8, today - 1)
    return r
end

---------------------------------------------------------------------------
-- Fuer das Broker-Fenster: Name, Link, Datum, Verlauf
---------------------------------------------------------------------------
-- Link zum Anzeigen im Tooltip (auch fuer Ausruestung mit Zusatz "itemID:suffixID")
function D.LinkFromKey(key)
    if type(key) == "number" then return "item:" .. key end
    local id, suffix = tostring(key):match("^(%d+):(%-?%d+)$")
    if id then return ("item:%s::::::%s"):format(id, suffix) end
    -- Variante (ab 0.28): gemerkter Link aus Scan/Taschen, sonst der Grundgegenstand
    local e = D.Lookup(key)
    if type(e) == "table" and type(e.lk) == "string" then return e.lk end
    id = tostring(key):match("^(%d+):")
    if id then return "item:" .. id end
    return nil
end

function D.ItemID(key)
    if type(key) == "number" then return key end
    return tonumber(tostring(key):match("^(%d+)"))
end

-- Name: aus dem Scan (ab 0.7), sonst vom Spiel (wenn schon geladen), sonst "Gegenstand 1234"
function D.ItemName(key, e)
    if type(e) == "table" and type(e.nm) == "string" then return e.nm end
    local name = ns.GetItemInfo(D.LinkFromKey(key) or key)
    if type(name) == "string" and not Peon.IsSecret(name) then return name end
    return nil
end

-- Tagesnummer -> Datum "30.09." (Mittag, damit die Zeitzone nicht stoert)
function D.DayLabel(day)
    return date("%d.%m.", day * 86400 + 43200)
end

-- Verlauf: Tageswerte (neueste zuerst), danach Wochenwerte; je Eintrag { sort, label, min, median, qty, scans }
function D.History(e)
    local rows = {}
    if type(e) ~= "table" then return rows end
    for _, x in ipairs(D.ParseDays(e.d)) do
        rows[#rows + 1] = { sort = x[1], day = x[1], label = D.DayLabel(x[1]),
            min = x[2] / x[5], median = x[3] / x[5], qty = x[4] / x[5], scans = x[5] }
    end
    for _, y in ipairs(D.ParseDays(e.w)) do
        rows[#rows + 1] = { sort = y[1] * 7, week = y[1], label = D.DayLabel(y[1] * 7),
            min = y[2], median = y[3], qty = y[4], days = y[5] }
    end
    table.sort(rows, function(a, b) return a.sort > b.sort end)
    return rows
end

---------------------------------------------------------------------------
-- Warenart und Einstellgebuehr
---------------------------------------------------------------------------
-- true = Massenware, false = Einzelgegenstand
function D.IsCommodity(key)
    local c = mod.acc and mod.acc.commodity
    if type(c) == "table" and c[key] ~= nil then return c[key] end
    if type(key) == "string" then return false end         -- Ausruestung mit Zusatz
    local stack = select(8, ns.GetItemInfo(key))
    return type(stack) == "number" and stack > 1              -- Faustregel: stapelbar = Massenware
end

function D.Duration(db)
    local lz = tonumber(db and db.duration) or 8
    if not D.EG_SATZ[lz] then lz = 8 end
    return lz
end

-- F18: Einstellgebuehr fuer eine Menge (kommt bei Verkauf zurueck).
-- So rechnet das Spiel (aus depositCheck, 17 Beispiele, 30.09.2026): erst die Gebuehr fuer 2 Std.
-- = 5 % vom Haendlerwert des Stapels, abgerundet; dann mal 4 (8 Std.) bzw. mal 12 (24 Std.).
-- Beispiel Wollstoff: 11 x 33c = 363c, 5 % = 18,15c -> 18c, x 4 = 72c.
function D.Deposit(hp, count, db)
    if type(hp) ~= "number" then return nil end
    local base = math.floor(hp * (count or 1) * 5 / 100)
    return base * D.EG_FAKTOR[D.Duration(db)]
end

---------------------------------------------------------------------------
-- Richtwert und ueblicher Bereich (Rechenmodell Kapitel 7, F35-F39, abgestimmt 02.10.2026)
---------------------------------------------------------------------------
D.BAND_DAYS     = 14      -- Tageswerte der letzten 14 Tage (heute eingeschlossen)
D.BAND_MIN_DAYS = 3       -- darunter kein Bereich (Rueckfall F12-F15)
D.BAND_HALF     = 3       -- Halbwertszeit in Tagen (gleitender Mittelwert LANG)
D.BAND_MIN_SCHW = 0.05    -- Schwankung mindestens 5 %
-- ab 0.38 (F37a, KarloDerBaer 08.11.2026): nach unten erst bei mindestens 25 % Schwankung kuerzen, sonst schneidet die
-- Kuerzung bei wenigen gleichen Tagen einen echten Preissturz ab (gleich wie Peon Manager longterm.js)
D.BAND_CLIP_LOW_SCHW = 0.25
D.BAND_HEUTE    = 3       -- HEUTE zaehlt ab so vielen Scans heute

local function Median(list)
    local s = {}
    for i, v in ipairs(list) do s[i] = v end
    table.sort(s)
    local n = #s
    if n == 0 then return nil end
    if n % 2 == 1 then return s[(n + 1) / 2] end
    return (s[n / 2] + s[n / 2 + 1]) / 2
end
D.Median = Median

-- ab 0.31 (Rechenmodell Kapitel 8, F43): Langzeit-Teil (MITTE, SCHW, LANG, Tage) vom Peon Client, wenn frisch.
-- nil ohne Peon_Bridge (oder Kanal broker nicht freigeschaltet), ohne Werte, bei alten Werten oder bei jedem Fehler -> Broker rechnet selbst.
function D.ClientBand(key)
    if key == nil then return nil end
    local c = Peon:GetModule("bridge")
    if not c or type(c.LongTerm) ~= "function" then return nil end
    local ok, v = pcall(c.LongTerm, c, key, ns.MarketKey())
    if ok and type(v) == "table" and type(v.mitte) == "number" and v.mitte > 0 and type(v.schw) == "number"
        and type(v.lang) == "number" and v.lang > 0 and type(v.days) == "number" then return v end
    return nil
end

-- jetzt = aktueller Median (JETZT), vor = Median der Messung davor (VOR); Standard e.md / e.pmd
-- key (ab 0.31): Schluessel des Gegenstands, damit der Langzeit-Teil vom Client kommen kann (F43)
-- Rueckgabe { days, mitte, schw, lang, heute, basis, trend ("calm"/"down"/"up"), rw, low, high, src } oder nil
function D.Band(e, jetzt, vor, today, key)
    if type(e) ~= "table" then return nil end
    today = today or D.Day()
    local xs, ages, heute = {}, {}, nil
    for _, x in ipairs(D.ParseDays(e.d)) do
        if x[1] > today - D.BAND_DAYS and x[1] <= today and x[5] > 0 then
            local md = x[3] / x[5]
            xs[#xs + 1], ages[#ages + 1] = md, today - x[1]
            if x[1] == today and x[5] >= D.BAND_HEUTE then heute = md end
        end
    end
    local mitte, schw, lang, days, src
    local cv = D.ClientBand(key)
    if cv then                                                                        -- F43: vom Peon Client
        mitte, schw, lang, days, src = cv.mitte, math.max(cv.schw, D.BAND_MIN_SCHW), cv.lang, cv.days, "client"
    else
        if #xs < D.BAND_MIN_DAYS then return nil end
        mitte = Median(xs)                                                            -- F35
        if not mitte or mitte <= 0 then return nil end
        local dev = {}
        for i, x in ipairs(xs) do dev[i] = math.abs(x - mitte) end
        schw = math.max(1.4826 * Median(dev) / mitte, D.BAND_MIN_SCHW)                -- F36
        local sw, sx = 0, 0                                                           -- F37
        local lo, hi = math.max(0, mitte * (1 - 3 * math.max(schw, D.BAND_CLIP_LOW_SCHW))), mitte * (1 + 3 * schw)   -- F37a
        for i, x in ipairs(xs) do
            local w = 0.5 ^ (ages[i] / D.BAND_HALF)
            sw, sx = sw + w, sx + w * math.max(lo, math.min(hi, x))
        end
        lang, days, src = sx / sw, #xs, "own"
    end
    if type(jetzt) ~= "number" then jetzt = e.md end
    if type(vor) ~= "number" then vor = e.pmd end
    local basis                                                                       -- F38
    if type(jetzt) ~= "number" then basis = heute and (heute + lang) / 2 or lang
    elseif heute then basis = Median({ jetzt, heute, lang })
    else basis = (jetzt + lang) / 2 end
    local trend = "calm"
    if type(jetzt) == "number" and type(vor) == "number" then
        if jetzt < basis * (1 - schw) and vor < basis * (1 - schw) then trend = "down"
        elseif jetzt > basis * (1 + schw) and vor > basis * (1 + schw) then trend = "up" end
    end
    local rw = trend == "calm" and basis or jetzt
    return { days = days, mitte = mitte, schw = schw, lang = lang, heute = heute, basis = basis, trend = trend, rw = rw,
             low = math.floor(rw * (1 - schw)), high = math.floor(rw * (1 + schw)), src = src }      -- F39
end

---------------------------------------------------------------------------
-- Preisvorschlag, Erloes, Empfehlung (F12-F20); Preise je Stueck
---------------------------------------------------------------------------
function D.UndercutFor(key, db)
    if D.IsCommodity(key) then
        return db.undercutMassMode or "copper", tonumber(db.undercutMassValue) or 0
    end
    return db.undercutMode or "copper", tonumber(db.undercutValue) or 1
end

-- Preis minus Unterbieten (F15), mindestens 1c
function D.Undercut(basis, key, db)
    local mode, value = D.UndercutFor(key, db)
    local vp
    if mode == "percent" then vp = math.floor(basis * (1 - value / 100)) else vp = math.floor(basis - value) end
    if vp < 1 then vp = 1 end
    return vp
end

-- Rueckgabe: VP, Basis, DUMP, Bereich (Kapitel 7; nil = zu wenig Tage)
-- e, vor (ab 0.21): Eintrag fuer den ueblichen Bereich und Median der Messung davor (VOR)
function D.Suggest(min, median, key, db, e, vor)
    if type(min) ~= "number" then return nil end
    local band = e and D.Band(e, median, vor, nil, key) or nil
    if band then                                                                    -- F40
        local dump, basis = false, min
        if min < band.low and band.trend ~= "down" then dump, basis = true, band.low end
        return D.Undercut(basis, key, db), basis, dump, band
    end
    local ref = type(median) == "number" and median or min                         -- F12
    local dg = (tonumber(db.dumpPct) or 30) / 100
    local dump = min < ref * (1 - dg)                                               -- F13
    local basis = dump and ref * (1 - dg / 2) or min                                -- F14
    local mode, value = D.UndercutFor(key, db)
    local vp
    if mode == "percent" then vp = math.floor(basis * (1 - value / 100))            -- F15
    else vp = math.floor(basis - value) end
    if vp < 1 then vp = 1 end
    return vp, basis, dump
end

function D.Proceeds(vp, count)                                                       -- F16
    return vp * (count or 1) * (1 - D.Cut())
end

-- Alles fuer die Anzeige eines Gegenstands; count = Stapelgroesse, hp = Haendlerpreis je Stueck
-- Ab 0.21 (KarloDerBaer 02.10.2026): Zeile 1 / Erloes = guenstigstes Angebot minus Unterbieten (so wird eingestellt, F41),
-- v.state = "good" (gruen), "falling" (orange, Markt faellt) oder "dump" (rot); v.vp bleibt der Vorschlag (F40)
function D.Evaluate(e, key, count, hp, db)
    count = count or 1
    local v = { count = count }
    v.vp, v.basis, v.dump, v.band = D.Suggest(e.m, e.md, key, db, e, e.pmd)
    v.entry = D.Undercut(e.m, key, db)
    v.erl = D.Proceeds(v.entry, count)
    v.state = (v.band and v.band.trend == "down") and "falling" or (v.dump and "dump" or "good")
    if e.pm then v.erlVor = D.Proceeds(D.Undercut(e.pm, key, db), count) end
    v.hw = hp and hp * count or nil                                                   -- F17
    v.eg = D.Deposit(hp, count, db)                                                   -- F18
    v.ah = not (v.hw and v.hw > 0) or v.erl > v.hw                                    -- F20
    v.week = D.Week(e)
    return v
end

---------------------------------------------------------------------------
-- Live-Daten (Rechenmodell Kapitel 4, F21-F22)
---------------------------------------------------------------------------
-- Live-Angebote { { price, qty, own }, ... } (je Stueck, own = eigene Menge dieser Stufe)
-- F21: AHmin_live = guenstigstes Angebot anderer Verkaeufer; F22: Median ueber alle Angebote
-- Rueckgabe: min (andere), median, menge, eigenes guenstigstes, Anzahl Stufen
function D.LiveValues(rows)
    if type(rows) ~= "table" or #rows == 0 then return nil end
    local flat, min, ownMin = {}, nil, nil
    for _, r in ipairs(rows) do
        local own = math.min(r.own or 0, r.qty)
        if r.qty - own > 0 and (not min or r.price < min) then min = r.price end
        if own > 0 and (not ownMin or r.price < ownMin) then ownMin = r.price end
        flat[#flat + 1] = r.price
        flat[#flat + 1] = r.qty
    end
    local _, median, qty = D.Summarize(flat)
    return min, median, qty, ownMin, #rows
end

---------------------------------------------------------------------------
-- Einkaufen und Schnaeppchen (Rechenmodell Kapitel 5, F28-F34)
---------------------------------------------------------------------------
D.LEVELS = 12  -- guenstigste Preisstufen je Gegenstand (Scan/live); ab 0.17 12 statt 5 (Wiederverkauf gegen das naechste Angebot)

-- flache Liste { Preis, Menge, ... } -> "Preis:Menge;..." (guenstigste D.LEVELS Stufen)
function D.Levels(list, max)
    max = max or D.LEVELS
    local byPrice, prices = {}, {}
    for i = 1, #list - 1, 2 do
        local p, q = math.floor(list[i] + 0.5), list[i + 1]
        if not byPrice[p] then byPrice[p] = 0; prices[#prices + 1] = p end
        byPrice[p] = byPrice[p] + q
    end
    table.sort(prices)
    local parts = {}
    for i = 1, math.min(max, #prices) do parts[#parts + 1] = prices[i] .. ":" .. byPrice[prices[i]] end
    return table.concat(parts, ";")
end

function D.ParseLevels(s)
    local rows = {}
    if type(s) ~= "string" then return rows end
    for p, q in s:gmatch("(%d+):(%d+)") do rows[#rows + 1] = { price = tonumber(p), qty = tonumber(q), own = 0 } end
    return rows
end

-- Anzahl Scans in den letzten `days` Tagen (heute eingeschlossen)
function D.ScanCount(e, days, today)
    today = today or D.Day()
    local n = 0
    for _, x in ipairs(D.ParseDays(type(e) == "table" and e.d)) do
        if x[1] > today - days then n = n + x[5] end
    end
    return n
end

-- F28: Vergleichspreis fuer Einkaufslisten
function D.RefBuy(e)
    if type(e) ~= "table" then return nil end
    local w = D.Week(e)
    if w.days and w.days >= 2 and w.median then return w.median end
    return e.md
end

-- F29: Hoechstpreis = REF_kauf x (1 - Rabatt)
function D.MaxBuyPrice(e, pct)
    local ref = D.RefBuy(e)
    if not ref then return nil end
    return math.floor(ref * (1 - (tonumber(pct) or 0) / 100))
end

-- Angebote (Stufen, ohne eigene) bis zum Grenzpreis: Menge und Kosten
function D.BelowLimit(rows, limit)
    local qty, cost = 0, 0
    for _, r in ipairs(rows or {}) do
        local q = r.qty - math.min(r.own or 0, r.qty)
        if r.price <= limit and q > 0 then qty = qty + q; cost = cost + r.price * q end
    end
    return qty, cost
end

-- verfuegbare Stufen (ohne eigene Angebote), aufsteigend nach Preis
function D.Available(rows)
    local out = {}
    for _, r in ipairs(rows or {}) do
        local q = r.qty - math.min(r.own or 0, r.qty)
        if q > 0 then out[#out + 1] = { price = r.price, qty = q } end
    end
    table.sort(out, function(a, b) return a.price < b.price end)
    return out
end

-- Kosten der n guenstigsten Stueck und Preis des n-ten Stuecks (ab 0.17: Kauf je Stueck oder Stapel)
function D.CostOf(rows, n)
    local cost, got, last = 0, 0, nil
    for _, l in ipairs(D.Available(rows)) do
        local take = math.min(l.qty, n - got)
        if take <= 0 then break end
        cost, got, last = cost + take * l.price, got + take, l.price
    end
    return cost, got, last
end

-- Gewinn, wenn ich nur die n guenstigsten Stueck eines Schnaeppchens kaufe (ab 0.18):
-- Haendler: HP je Stueck; Markt: Wiederverkauf gegen das naechste Angebot nach diesem Kauf (hoechstens REF)
-- Rueckgabe: gewinn, kosten, stueck
function D.ProfitOf(d, n)
    local rows = d.rows or {}
    local cost, got = D.CostOf(rows, n)
    if got < 1 then return nil, 0, 0 end
    if d.kind == "vendor" then return math.floor(d.net * got - cost), cost, got end
    local lv = D.Available(rows)
    local taken, nextP = 0, nil
    for i, l in ipairs(lv) do
        if taken + l.qty > got then nextP = l.price; break end          -- Rest dieser Stufe bleibt Konkurrenz
        taken = taken + l.qty
        if taken == got then
            if lv[i + 1] then nextP = lv[i + 1].price
            elseif (d.all or 0) > (d.listed or 0) then nextP = l.price
            else nextP = d.refMedian end
            break
        end
    end
    local ref = d.refMedian or nextP or 0
    local sell = math.min(ref, nextP or ref)
    return math.floor(sell * (1 - D.Cut()) * got - cost), cost, got
end

-- F31/F33 (ab 0.17 neu, mit KarloDerBaer abgestimmt 30.09.2026): Schnaeppchen aus Preisstufen
-- Rueckgabe { kind, gain, qty, offer, ref, limit, net, unitGain } oder nil
--   net  = Erloes je Stueck beim Wiederverkauf (Haendler: HP; Markt: naechstes Angebot nach dem Kauf, hoechstens REF, minus Anteil)
--   ref  = Vergleichspreis in der Anzeige (Haendler: HP; Markt: Wiederverkaufspreis vor dem Anteil)
--   limit = Preis des teuersten Stuecks, das zum Schnaeppchen gehoert
-- db.radarKind: "both" (Standard), "vendor" oder "market"
function D.Deal(e, rows, hp, db, today, key)
    local lv = D.Available(rows)
    if #lv == 0 then return nil end
    local kinds = db.radarKind or "both"
    local vendor, market
    -- Haendler (F31): alles unter dem Haendlerpreis
    if kinds ~= "market" and type(hp) == "number" and hp > 0 and lv[1].price < hp then
        local gain, qty, limit = 0, 0, nil
        for _, l in ipairs(lv) do
            if l.price < hp then gain = gain + (hp - l.price) * l.qty; qty = qty + l.qty; limit = l.price end
        end
        if gain >= (tonumber(db.dealMinVendor) or 10) then
            vendor = { kind = "vendor", gain = gain, qty = qty, offer = lv[1].price, ref = hp, limit = limit, net = hp }
        end
    end
    -- Markt (F33): nur bei guter Datenlage und wenn das guenstigste Angebot unter der Dumping-Grenze liegt
    if kinds ~= "vendor" and type(e) == "table" and e.md
        and D.ScanCount(e, tonumber(db.dealDays) or 7, today) >= (tonumber(db.dealScans) or 10) then
        -- ab 0.21 (Kapitel 7, KarloDerBaer 02.10.2026): Richtwert und ueblicher Bereich; faellt der Markt, kein Markt-Schnaeppchen
        local band = D.Band(e, e.md, e.pmd, today, key)
        local ref, isDump
        if band then
            ref = band.rw
            isDump = lv[1].price < band.low and band.trend ~= "down"
        else
            local w = D.Week(e, today)
            ref = e.md
            if w.median and w.median < ref then ref = w.median end
            isDump = lv[1].price < ref * (1 - (tonumber(db.dumpPct) or 30) / 100)
        end
        if isDump then
            local listed = 0
            for _, r in ipairs(rows) do listed = listed + r.qty end
            local all = math.max(listed, tonumber(e.q) or 0)
            local maxQty = math.max(1, math.floor(all * (tonumber(db.dealDepth) or 20) / 100))
            local margin = (tonumber(db.dealMargin) or 20) / 100
            -- ab 0.26 (KarloDerBaer 03.10.2026): Wiederverkauf hoechstens zur Untergrenze des ueblichen Bereichs (= Preis, den
            -- Verkaufen bei Dumping vorschlaegt, F40); ohne Bereich Mitte zwischen Dumping-Grenze und Vergleichspreis (F14)
            local cap = band and band.low or math.floor(ref * (1 - (tonumber(db.dumpPct) or 30) / 200))
            if cap < ref then ref = cap end
            -- ab 0.26: hoechstens so viel, wie sich in dealHold Stunden verkauft (Absatz je Std., erst ab gelbem Zeichen)
            local sr = ns.Sales and ns.Sales.Stats(e, nil, key)
            local sales, salesCap
            if sr and (sr.level or 1) >= 2 then
                sales = sr
                salesCap = math.floor(sr.perHour * (tonumber(db.dealHold) or 48))
                if salesCap < maxQty then maxQty = salesCap end
            end
            if maxQty < 1 then maxQty = 0 end
            local bought, cost, best = 0, 0, nil
            for i, l in ipairs(lv) do
                local take = math.min(l.qty, maxQty - bought)
                if take <= 0 then break end
                bought, cost = bought + take, cost + take * l.price
                -- naechstes Angebot nach dem Kauf
                local nextP
                if take < l.qty then nextP = l.price
                elseif lv[i + 1] then nextP = lv[i + 1].price
                elseif all > listed then nextP = l.price     -- weitere Stufen unbekannt (nur gespeicherte Stufen): vorsichtig
                else nextP = ref end                         -- sonst nichts im Angebot
                local sell = math.min(ref, nextP)
                local net = sell * (1 - D.Cut())
                if net >= l.price * (1 + margin) then
                    local gain = math.floor(net * bought - cost)
                    if not best or gain > best.gain then
                        best = { kind = "market", gain = gain, qty = bought, offer = lv[1].price, ref = sell, limit = l.price, net = net,
                                 refMedian = ref, all = all, listed = listed, sales = sales, salesCap = salesCap,
                                 salesUnknown = not sales }
                    end
                end
                if take < l.qty then break end
            end
            if best and best.gain >= (tonumber(db.dealMinMarket) or 50) * 100 then market = best end
        end
    end
    if vendor then vendor.unitGain = vendor.gain / vendor.qty end
    if market then market.unitGain = market.gain / market.qty end
    if vendor and market then
        if market.unitGain > vendor.unitGain then return market end
        return vendor
    end
    return vendor or market
end

---------------------------------------------------------------------------
-- Bei geoeffnetem Auktionshaus: Warenart merken und Einstellgebuehr mit dem Spiel abgleichen
---------------------------------------------------------------------------
function D.CheckBags()
    local ah, C = rawget(_G, "C_AuctionHouse"), rawget(_G, "C_Container")
    if not ah or not C or not ItemLocation or not ItemLocation.CreateFromBagAndSlot then return 0 end
    local acc = mod.acc
    if type(acc.commodity) ~= "table" then acc.commodity = {} end
    -- ab 0.28: nur noch die Warenart (der Abgleich der Einstellgebuehr mit dem Spiel ist erledigt, Formel bestaetigt);
    -- bekannte Gegenstaende werden nicht erneut gefragt
    local n = 0
    local lastBag = tonumber(rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS")) or tonumber(rawget(_G, "NUM_BAG_SLOTS")) or 4
    for bag = 0, lastBag do   -- ab 0.28 mit Reagenzientasche (wie der Reiter Verkaufen)
        local ok, slots = pcall(C.GetContainerNumSlots, bag)
        for slot = 1, (ok and tonumber(slots) or 0) do
            local ok2, info = pcall(C.GetContainerItemInfo, bag, slot)
            if ok2 and type(info) == "table" and info.hyperlink and not Peon.IsSecret(info.hyperlink) then
                local key = D.KeyFromLink(info.hyperlink)
                if key ~= nil and acc.commodity[key] == nil then
                    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                    local okv, valid = pcall(ah.IsSellItemValid, loc, false)
                    if okv and valid == true then
                        local oks, status = pcall(ah.GetItemCommodityStatus, loc)
                        local isComm = oks and Enum and Enum.ItemCommodityStatus and status == Enum.ItemCommodityStatus.Commodity
                        if oks and status and status ~= 0 then acc.commodity[key] = isComm and true or false; n = n + 1 end
                    end
                end
            end
        end
    end
    return n
end
