-- Peon_Bridge - Channel_Broker.lua (bis Peon_Client 0.3.0 Export.lua und Teile von Client.lua)
-- Kanal "broker": Momentaufnahmen von Peon_Broker an den Manager und Werte des Managers fuer Broker zurueck.
-- Arbeitet nur, wenn der Manager den Kanal freischaltet (PeonBridgeData.channels.broker, Modul Peon Broker Client).
--
-- Momentaufnahmen im Format der Blizzard-API (Peon_Client_Design.md, Abschnitt 6.3).
-- Eine Zeile je Angebot, Felder durch ";" getrennt:
--   1 item  2 bonus  3 name  4 quantity  5 buyout  6 unit_price  7 bid  8 time_left  9 id  10 n
-- Voellig gleiche Angebote (Felder 1 bis 9 gleich) stehen als eine Zeile mit Zaehler n.
-- time_left: Stufe 1 (SHORT, bis 30 Min.) bis 4 (VERY_LONG, bis 48 Std.), leer = unbekannt.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local E = {}
ns.Export = E

E.LIVE_SAME = 60   -- gleiche Live-Abfrage desselben Gegenstands innerhalb 60 Sek. nicht nochmal ablegen
E.TIP_MAX = 400    -- genaue Werte je Komplettscan, der Rest kommt mit dem naechsten

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

local function Int(v)
    if not Num(v) or v ~= v then return "" end
    return ("%.0f"):format(v)
end

-- Text fuer ein Feld: ";" und Zeilenumbrueche gehoeren nicht hinein
local function Clean(s)
    if type(s) ~= "string" or Peon.IsSecret(s) then return "" end
    return (s:gsub("[;\r\n]", " "))
end
E.Clean = Clean

-- Bonus-Nummern aus einem Link (Feld 13 = Anzahl, danach die Nummern, wie in Retail)
function E.Bonus(link)
    if type(link) ~= "string" or Peon.IsSecret(link) then return "" end
    local body = link:match("item:([%-%d:]+)")
    if not body then return "" end
    local f = {}
    for v in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
    local n = tonumber(f[13]) or 0
    if n <= 0 then return "" end
    local out = {}
    for i = 14, 13 + n do
        local b = tonumber(f[i])
        if b then out[#out + 1] = tostring(b) end
    end
    return table.concat(out, ",")
end

-- Restzeit-Stufe 1-4; aus Sekunden (Live, Massenware) oder Stufe 0-3 (Live, Einzelgegenstand)
function E.BandFromSeconds(secs)
    if not Num(secs) then return nil end
    if secs <= 1800 then return 1 end
    if secs <= 7200 then return 2 end
    if secs <= 43200 then return 3 end
    return 4
end

function E.Line(item, bonus, name, qty, buyout, unit, bid, band, id)
    return table.concat({ Int(item), bonus or "", Clean(name), Int(qty), Int(buyout), Int(unit), Int(bid),
        (Num(band) and band >= 1 and band <= 4) and tostring(band) or "", Int(id) }, ";")
end

---------------------------------------------------------------------------
-- Genaue Werte eines Gegenstands (ab 0.6.0): Die Blizzard-API nennt die Werte eines Zusatzes nicht, der Tooltip des Spiels schon.
-- Je Zeile "links\trechts\tArt" (g gruen, y gelb, m grau), Zeilen durch \n getrennt, ohne die erste Zeile (Name).
---------------------------------------------------------------------------
local function TipColor(c)
    if type(c) ~= "table" or not Num(c.r) or not Num(c.g) or not Num(c.b) then return "" end
    if c.g > c.r + 0.3 and c.g > c.b + 0.3 then return "g" end
    if c.r > 0.8 and c.g > 0.6 and c.b < 0.3 then return "y" end
    if math.abs(c.r - c.g) < 0.1 and math.abs(c.g - c.b) < 0.1 and c.r < 0.7 then return "m" end
    return ""
end

local function TipPart(s)
    if type(s) ~= "string" or Peon.IsSecret(s) then return "" end
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\t\r\n]", " "))
end

-- Text fuer den Manager, nil wenn das Spiel die Werte nicht (oder noch nicht) nennt
function E.TipText(link)
    local ti = rawget(_G, "C_TooltipInfo")
    if type(link) ~= "string" or Peon.IsSecret(link) or not (ti and ti.GetHyperlink) then return nil end
    local ok, data = pcall(ti.GetHyperlink, link)
    if not ok or type(data) ~= "table" or Peon.IsSecret(data) or type(data.lines) ~= "table" or #data.lines < 2 then return nil end
    local out = {}
    local waiting = rawget(_G, "RETRIEVING_ITEM_INFO")
    for i = 2, math.min(#data.lines, 40) do
        local line = data.lines[i]
        if type(line) == "table" then
            local l, r = TipPart(line.leftText), TipPart(line.rightText)
            if waiting and l == waiting then return nil end
            if l ~= "" or r ~= "" then out[#out + 1] = l .. "\t" .. r .. "\t" .. TipColor(line.leftColor) end
        end
    end
    if #out == 0 then return nil end
    return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- Bestellte Werte (ab 0.6.0): Data.lua nennt in tipWant, was der Manager noch nicht kennt (Schluessel -> Link). Das Spiel fordert den
-- Gegenstand an, liest kurz danach den Tooltip und legt ihn in PeonBridgeDB.tipBox. Nur ausserhalb des Kampfes, wenige auf einmal.
-- Leerer Text: Das Spiel nennt nichts. Was der Manager nicht mehr bestellt, hat er bekommen und wird geloescht.
---------------------------------------------------------------------------
E.TIP_BATCH = 8      -- gleichzeitig angefordert
E.TIP_WAIT = 6       -- so viele Sekunden auf einen Gegenstand warten
E.TIP_EVERY = 0.5    -- Sekunden je Schritt
E.TIP_DELAY = 10     -- erst so lange nach dem Laden beginnen

function E.TipStart()
    local acc = mod.acc
    if type(acc.tipBox) ~= "table" then acc.tipBox = {} end
    local d = ns.ManagerData()
    local want = d and d.tipWant
    if type(want) ~= "table" then want = {} end
    for k in pairs(acc.tipBox) do
        if want[k] == nil then acc.tipBox[k] = nil end
    end
    E.tipQueue, E.tipBusy, E.tipBusyN = {}, {}, 0
    if not (rawget(_G, "C_TooltipInfo") and C_TooltipInfo.GetHyperlink) then return 0 end
    for k, link in pairs(want) do
        if acc.tipBox[k] == nil and type(link) == "string" then E.tipQueue[#E.tipQueue + 1] = { k = k, link = link } end
    end
    return #E.tipQueue
end

-- Ein Schritt. Rueckgabe: true, solange noch etwas zu tun ist
function E.TipStep()
    if not E.tipQueue then return false end
    if Peon.InCombat() then return true end
    local box = mod.acc.tipBox
    local now = GetTime()
    for k, b in pairs(E.tipBusy) do
        local text = E.TipText(b.link)
        if text or now - b.t >= E.TIP_WAIT then
            box[k] = text or ""
            E.tipBusy[k] = nil
            E.tipBusyN = E.tipBusyN - 1
        end
    end
    local CI = rawget(_G, "C_Item")
    while E.tipBusyN < E.TIP_BATCH and #E.tipQueue > 0 do
        local e = table.remove(E.tipQueue)
        local id = tonumber(e.link:match("item:(%d+)"))
        if CI and CI.RequestLoadItemDataByID and id then pcall(CI.RequestLoadItemDataByID, id) end
        E.tipBusy[e.k] = { link = e.link, t = now }
        E.tipBusyN = E.tipBusyN + 1
    end
    return E.tipBusyN > 0 or #E.tipQueue > 0
end

-- Im Hintergrund laufen lassen. Ein Fehler beendet nur diese Aufgabe, nie das Addon
function E.TipRun()
    local T = rawget(_G, "C_Timer")
    if E.TipStart() == 0 or not (T and T.After) then return end
    local function Tick()
        local ok, more = pcall(E.TipStep)
        if not ok then mod:ReportError("Genaue Werte", more); return end
        if more then T.After(E.TIP_EVERY, Tick) end
    end
    T.After(E.TIP_DELAY, Tick)
end

-- Zeilen sammeln: gleiche zaehlen, Reihenfolge des ersten Auftretens behalten
local function NewBag() return { order = {}, count = {}, offers = 0 } end

local function Put(bag, line)
    local c = bag.count[line]
    if c then bag.count[line] = c + 1
    else bag.count[line] = 1; bag.order[#bag.order + 1] = line end
    bag.offers = bag.offers + 1
end

local function Text(bag)
    local out = {}
    for i, line in ipairs(bag.order) do out[i] = line .. ";" .. bag.count[line] end
    return table.concat(out, "\n")
end

local function Head(kind, market, t)
    local acc = mod.acc
    acc.seq = (acc.seq or 0) + 1
    local e = { id = ("%s-%d"):format(Int(t), acc.seq), kind = kind, fmt = ns.FMT, market = market, t = t }
    local realm = GetRealmName and GetRealmName()
    if type(realm) == "string" and not Peon.IsSecret(realm) then e.realm = realm end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if type(faction) == "string" and not Peon.IsSecret(faction) then e.faction = faction end
    local gr = rawget(_G, "GetCurrentRegion")
    if gr then
        local ok, r = pcall(gr)
        if ok and Num(r) then e.region = r end
    end
    if UnitName then
        local first, last = UnitName("player")
        if type(first) == "string" and not Peon.IsSecret(first) then
            e.char = (type(last) == "string" and last ~= "" and not Peon.IsSecret(last)) and (first .. " " .. last) or first
        end
    end
    if GetBuildInfo then
        local v, b = GetBuildInfo()
        if v then e.build = tostring(v) .. (b and ("." .. tostring(b)) or "") end
    end
    local b = ns.Broker()
    if b then e.broker = b.version end
    return e
end

-- Neue Aufnahme hinten anhaengen, dann auf die eingestellte Zahl kuerzen (aelteste zuerst weg)
function E.Push(e)
    local q = mod.acc.queue
    q[#q + 1] = e
    local maxScan, maxLive = mod.db.queueMax or 10, mod.db.liveMax or 500
    local scans, live = 0, 0
    for _, x in ipairs(q) do if x.kind == "scan" then scans = scans + 1 else live = live + 1 end end
    if scans <= maxScan and live <= maxLive then return end
    local keep = {}
    for _, x in ipairs(q) do
        if x.kind == "scan" and scans > maxScan then scans = scans - 1
        elseif x.kind ~= "scan" and live > maxLive then live = live - 1
        else keep[#keep + 1] = x end
    end
    mod.acc.queue = keep
end

---------------------------------------------------------------------------
-- Komplettscan
---------------------------------------------------------------------------
function E.ScanStart(info)
    info = type(info) == "table" and info or {}
    E.cur = { bag = NewBag(), market = info.market, t = info.t or time(), total = info.total,
        variants = type(info.variants) == "table" and info.variants or {}, names = {}, tips = {}, tipN = 0 }
end

-- Haendlerpreis je Stueck (ueber Broker, sonst vom Spiel), nil = unbekannt
function E.Vendor(itemID)
    local b = ns.Broker()
    if b and type(b.VendorPrice) == "function" then
        local ok, v = pcall(b.VendorPrice, b, itemID)
        if ok then return Num(v) and v or nil end
    end
    local gi = (rawget(_G, "C_Item") and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo")
    if not gi then return nil end
    local ok, v = pcall(function() return select(11, gi(itemID)) end)
    return ok and Num(v) and v or nil
end

-- Warenart von Broker: "1" Massenware, "0" Einzelgegenstand, "" unbekannt
function E.Commodity(itemID)
    local b = ns.Broker()
    if not b or type(b.IsCommodity) ~= "function" then return "" end
    local ok, v = pcall(b.IsCommodity, b, itemID)
    if not ok or type(v) ~= "boolean" then return "" end
    return v and "1" or "0"
end

-- Name fuer den Manager: "Name|Qualitaet|Haendlerpreis|Massenware" (ab 0.3.0, vorher "Name|Qualitaet")
function E.NameInfo(itemID, name, quality)
    local hp = E.Vendor(itemID)
    return Clean(name) .. "|" .. (Num(quality) and Int(quality) or "") .. "|" .. (hp and Int(hp) or "") .. "|" .. E.Commodity(itemID)
end

function E.ScanRow(itemID, name, count, quality, buyout, minBid, bid, band, link)
    local cur = E.cur
    if not cur or not Num(itemID) or not Num(count) or count <= 0 then return end
    local bonus = E.Bonus(link)
    local full
    local named = type(name) == "string" and name ~= "" and not Peon.IsSecret(name)
    if Num(quality) and quality >= 2 and (bonus ~= "" or cur.variants[itemID]) then
        full = name   -- Gegenstand mit Zusatz: voller Name gehoert in die Zeile
    end
    -- Name, Haendlerpreis und Warenart einmal je Gegenstand (ab 0.3.0 auch fuer Gegenstaende mit Zusatz, wegen des Haendlerpreises)
    -- bei Gegenstaenden mit Zusatz ohne Namen (der steht in der Zeile und gilt nur fuer die Variante)
    if named and not mod.acc.nameIds[itemID] and not cur.names[itemID] then
        cur.names[itemID] = E.NameInfo(itemID, full and "" or name, quality)
    end
    -- Genaue Werte fuer Ausruestung und Gegenstaende mit Zusatz, einmal je Schluessel
    if Num(quality) and quality >= 2 and cur.tipN < E.TIP_MAX and link then
        local tk = full and (Int(itemID) .. ":" .. Clean(full)) or Int(itemID)
        if not cur.tips[tk] and not mod.acc.tipIds[tk] then
            local text = E.TipText(link)
            if text then cur.tips[tk] = text; cur.tipN = cur.tipN + 1 end
        end
    end
    local b = (Num(bid) and bid > 0) and bid or ((Num(minBid) and minBid > 0) and minBid or nil)
    local bo = Num(buyout) and buyout or 0
    Put(cur.bag, E.Line(itemID, bonus, full, count, bo, nil, b, band, nil))
end

function E.ScanEnd(info)
    local cur = E.cur
    E.cur = nil
    if not cur then return nil end
    info = type(info) == "table" and info or {}
    local e = Head("scan", cur.market or info.market, cur.t)
    e.total, e.offers, e.lines = cur.total, cur.bag.offers, #cur.bag.order
    e.partial = false
    e.rows = Text(cur.bag)
    if next(cur.names) then e.names = cur.names end
    if next(cur.tips) then e.tips = cur.tips end
    E.Push(e)
    mod:Dbg(L.MSG_SCAN_ADDED:format(e.offers, e.lines))
    if ns.ShowButton then mod:Call("Knopf", ns.ShowButton) end
    return e
end

---------------------------------------------------------------------------
-- Live-Abfrage (ein Gegenstand)
---------------------------------------------------------------------------
-- key: itemID oder "itemID:voller Name" (Variante) oder "itemID:Zusatznummer" (alte Form)
function E.Live(key, rows, t, info)
    if (mod.db.liveMax or 0) <= 0 or type(rows) ~= "table" then return nil end
    info = type(info) == "table" and info or {}
    local itemID = tonumber(key) or (type(key) == "string" and tonumber(key:match("^(%d+)")))
    if not itemID then return nil end
    local full
    if type(key) == "string" then
        local rest = key:match("^%d+:(.+)$")
        if rest and not rest:match("^%-?%d+$") then full = rest end
    end
    local bonus = E.Bonus(rows.link)
    local bag = NewBag()
    if type(rows.offers) == "table" and #rows.offers > 0 then
        for _, o in ipairs(rows.offers) do
            if Num(o.q) and o.q > 0 and Num(o.p) then
                local band = E.BandFromSeconds(o.secs) or (Num(o.band) and o.band + 1) or nil
                Put(bag, E.Line(itemID, bonus, full, o.q, nil, o.p, nil, band, o.id))
            end
        end
    else
        for _, r in ipairs(rows) do
            if Num(r.qty) and r.qty > 0 and Num(r.price) then
                Put(bag, E.Line(itemID, bonus, full, r.qty, nil, r.price, nil, nil, nil))
            end
        end
    end
    local partial = (info.partial or rows.partial) and true or false
    if bag.offers == 0 and partial then return nil end   -- Spiel laedt noch: keine Aussage
    t = Num(t) and t or time()
    local text = Text(bag)
    local k = tostring(key)
    E.lastLive = E.lastLive or {}
    local last = E.lastLive[k]
    if last and last.text == text and t - last.t < E.LIVE_SAME then return nil end
    E.lastLive[k] = { text = text, t = t }
    local e = Head("live", info.market, t)
    e.key, e.partial, e.commodity = k, partial, info.commodity and true or false
    e.offers, e.lines = bag.offers, #bag.order
    e.rows = text   -- leer = keine Angebote
    if rows.link and not mod.acc.tipIds[k] then
        local tip = E.TipText(rows.link)
        if tip then e.tips = { [k] = tip } end
    end
    E.Push(e)
    return e
end

local function Dispatch(kind, ...)
    if kind == "scan_row" then E.ScanRow(...)
    elseif kind == "scan_start" then E.ScanStart(...)
    elseif kind == "scan_end" then E.ScanEnd(...)
    elseif kind == "scan_abort" then E.cur = nil
    elseif kind == "live" then E.Live(...) end
end

-- Fehler merken (auch ohne Debug, hoechstens 10) und einmal melden; die laufende Aufnahme wird verworfen
function E.Fail(kind, err)
    local acc = mod.acc
    if type(acc.errors) ~= "table" then acc.errors = {} end
    acc.errors[#acc.errors + 1] = { t = time(), kind = tostring(kind), err = tostring(err), version = mod.version }
    while #acc.errors > 10 do table.remove(acc.errors, 1) end
    E.cur = nil
    mod:ReportError(kind, err)
end

-- Zuhoerer bei Broker (mod:AddSnapshotListener). Fehler bleiben hier, Broker scannt immer weiter.
function E.OnSnapshot(kind, ...)
    local ok, err = pcall(Dispatch, kind, ...)
    if not ok then E.Fail(kind, err) end
end

---------------------------------------------------------------------------
-- Werte des Managers fuer Broker (nur mit freigeschaltetem Kanal)
---------------------------------------------------------------------------
-- Name des Markts im Manager: Forever hat keine Realms, andere interne Namen desselben Markts stehen in aliases (ab 0.6.0)
function ns.MarketOf(d, market)
    return type(d.aliases) == "table" and d.aliases[market] or market
end

-- Markt des Managers, nil ohne Freischaltung, ohne Werte oder wenn aelter als freshDays
local function FreshMarket(market, field)
    if not ns.ChannelOn("broker") then return nil end
    local d = ns.ManagerData()
    local m = d and type(d.markets) == "table" and type(market) == "string" and d.markets[ns.MarketOf(d, market)]
    if type(m) ~= "table" or type(m[field]) ~= "table" then return nil end
    local t = tonumber(m.t) or tonumber(d.t)
    if not t or time() - t > (tonumber(mod.db and mod.db.freshDays) or 7) * 86400 then return nil end
    return m, t
end

local function Entry(list, key)
    local s = list[key]
    if s == nil and type(key) == "string" and key:match("^%d+$") then s = list[tonumber(key)] end
    if s == nil and type(key) == "number" then s = list[tostring(key)] end
    return s
end

-- Langzeit-Teil fuer Broker (Rechenmodell Kapitel 8, F43): { mitte, schw, lang, days, src, t, day } oder nil
-- key wie in Broker (Zahl oder "itemID:voller Name"), market = "Realm / Fraktion".
function mod:LongTerm(key, market)
    local m, t = FreshMarket(market, "items")
    if not m then return nil end
    local s = Entry(m.items, key)
    if type(s) ~= "string" then return nil end
    local mi, sc, la, dy, src = s:match("^(%d+):(%d+):(%d+):(%d+):(%a*)$")
    if not mi then return nil end
    mi, sc, la, dy = tonumber(mi), tonumber(sc), tonumber(la), tonumber(dy)
    if mi <= 0 or dy < 1 then return nil end
    return { mitte = mi, schw = sc / 10000, lang = la, days = dy, src = src, t = t, day = tonumber(m.day) }
end

-- Absatz fuer Broker (Rechenmodell 9.4, F49): { perDay, rate, minutes, t } oder nil (wie LongTerm)
function mod:Sales(key, market)
    local m, t = FreshMarket(market, "sales")
    if not m then return nil end
    local s = Entry(m.sales, key)
    if type(s) ~= "string" then return nil end
    local a, q, mi = s:match("^(%d+):(%-?%d+):(%d+)$")
    if not a then return nil end
    a, q, mi = tonumber(a), tonumber(q), tonumber(mi)
    if mi <= 0 then return nil end
    return { perDay = a / 10, rate = q >= 0 and q / 100 or nil, minutes = mi, t = t }
end

-- Wie viele Gegenstaende hat der Manager fuer einen Markt (Anzeige)
function ns.MarketCount(market)
    local d = ns.ManagerData()
    local m = d and type(d.markets) == "table" and d.markets[ns.MarketOf(d, market)]
    if type(m) ~= "table" or type(m.items) ~= "table" then return 0, nil, 0 end
    local n, s = 0, 0
    for _ in pairs(m.items) do n = n + 1 end
    if type(m.sales) == "table" then for _ in pairs(m.sales) do s = s + 1 end end
    return n, tonumber(m.t), s
end

function ns.DataInfo()
    local d = ns.ManagerData()
    if not d or type(d.markets) ~= "table" then return nil end
    local markets, items = 0, 0
    for _, m in pairs(d.markets) do
        markets = markets + 1
        if type(m) == "table" and type(m.items) == "table" then for _ in pairs(m.items) do items = items + 1 end end
    end
    return d.t, markets, items
end

function ns.Broker()
    return Peon:GetModule("broker")
end

-- Markt wie Broker (Realm / Fraktion)
function ns.MarketKeyOf()
    local realm = GetRealmName and GetRealmName() or nil
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    if type(realm) ~= "string" or Peon.IsSecret(realm) or realm == "" then return nil end
    if type(faction) ~= "string" or Peon.IsSecret(faction) or faction == "" then return nil end
    return realm .. " / " .. faction
end

-- Als Zuhoerer bei Broker anmelden (nur mit Freischaltung, sonst bleibt Broker ohne Zusatzarbeit)
function ns.Hook()
    if ns.hooked then return true end
    local b = ns.Broker()
    if not b or type(b.AddSnapshotListener) ~= "function" then return false end
    b:AddSnapshotListener(E.OnSnapshot)
    ns.hooked = true
    E.TipRun()
    -- Einkaufslisten aus dem Manager an Broker geben (ab 0.6.0)
    local d = ns.ManagerData()
    if d and type(d.shop) == "table" and type(b.MergeShop) == "function" then
        local ok, err = pcall(b.MergeShop, b, d.shop)
        if not ok then mod:ReportError("Einkaufslisten", err) end
    end
    return true
end

local function Status(on)
    local out = {}
    if not on then
        out[#out + 1] = L.ST_BROKER_OFF
        return out
    end
    local t, markets, items = ns.DataInfo()
    if t then out[#out + 1] = L.ST_DATA:format(ns.When(t), markets, items)
    else out[#out + 1] = L.ST_DATA_NONE end
    local mk = ns.Broker() and ns.MarketKeyOf()
    if t and mk then
        local n, mt, n2 = ns.MarketCount(mk)
        if n > 0 and mt and time() - mt > (mod.db.freshDays or 7) * 86400 then out[#out + 1] = L.ST_DATA_OLD:format(mod.db.freshDays or 7)
        elseif n > 0 then out[#out + 1] = L.ST_DATA_MARKET:format(mk, n, n2) end
    end
    if not ns.hooked then out[#out + 1] = L.ST_BROKER_NONE end
    return out
end

ns.RegisterChannel("broker", { title = "Broker", start = ns.Hook, status = Status })
