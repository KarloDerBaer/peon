-- Peon_Broker - Radar.lua
-- Reiter "Radar" (ab 0.14, mit KarloDerBaer abgestimmt 30.09.2026): Schnaeppchen (Haendler und Markt/Dump).
--   Beim Oeffnen: Treffer aus der Datenbank (voller Scan und, ab 0.15, gespeicherte Live-Ergebnisse), hoechstens
--     radarMaxAge Minuten alt (0 = unbegrenzt); sie werden gleich einmal live geprueft (auch ohne Radar-Scan).
--     Das Live-Ergebnis steht danach in der Datenbank (D.ApplyLive): was weg ist, kommt nicht wieder.
--   Radar-Scan (nur solange der Reiter offen ist): laufend Live-Abfragen knapp unter der Grenze des Spiels,
--     Reihenfolge: Treffer (oefter nachgeprueft), Einkaufslisten, Gegenstaende mit den besten Chancen.
--   Neue Treffer: Ton (waehlbar, abschaltbar), Zeile pulsiert gruen (radarFlash Sek.), Punkt vor dem Namen (60 Sek.).
--   Gewinn (ab 0.19): eine Spalte, hoechster Gewinn mit meinem Gold (abzueglich Goldreserve); danach Sortierung und Mindestgewinn.
--   Gewaehlter Treffer (ab 0.19): wird gleich im Auktionshaus gezeigt und, solange er gewaehlt ist, alle R.FOCUS_EVERY Sek. neu abgefragt.
--   Kaufen: Kaufzeile (1 Stueck / bis Gewinn bzw. Stapel / alle) und Knopf "Haendler: Bestes kaufen" (alles, was ich mir leisten kann).
--     Massenware: Preis vom Spiel, dann Bestaetigen. Einzelgegenstaende: frische Pruefung, dann je Klick eine Auktion.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local R = {}
ns.Radar = R

R.INTERVAL  = 0.65   -- Sekunden zwischen zwei Abfragen (~92 pro Minute, Grenze des Spiels: 100)
R.TICK      = 0.1    -- Sekunden: so oft nachsehen, ob die naechste Abfrage raus kann (ab 0.15)
R.SKIP_AFTER = 2     -- Gegenstand nach so vielen Abfragen ohne Antwort in Folge fuer diese Sitzung auslassen
R.WAIT      = 1      -- Sekunden: so lange auf eine Antwort warten (Antworten kommen nach ~0,2 s; ab 0.14.5 1 statt 2)
R.RECHECK   = 15     -- Sekunden: Treffer spaetestens so oft nachpruefen
R.FRESH     = 10     -- Sekunden: so alt darf die Pruefung vor einem Kauf sein (Einzelgegenstand)
R.NEW_TIME  = 60     -- Sekunden: so lange gilt ein Treffer als "neu" (gruen)
R.CANDIDATES = 400   -- so viele Gegenstaende mit den besten Chancen kommen in die Runde
R.FOCUS_EVERY = math.huge  -- gewaehlten Treffer nicht mehr regelmaessig neu abfragen (ab 0.21.1: lud das Blizzard-Fenster
                           -- alle 5 Sek. neu); geprueft wird beim Anklicken, nach einem Kauf und vor dem Kauf
R.GONE_TIME = 30     -- Sekunden: so lange bleibt ein weggefallener Treffer grau mit Grund in der Liste (ab 0.20)
R.LOG_MAX   = 200    -- so viele weggefallene Treffer merkt sich das Radar-Protokoll (PeonBrokerDB.radarLog)
R.CONFIRM_AFTER = 3  -- Sekunden: "keine Angebote" nach so langer Zeit nochmal pruefen, erst dann weg (ab 0.20.1)
R.DOT = "Interface\\AddOns\\Peon_Broker\\Media\\dot_new"   -- Punkt vor neuen Treffern (ab 0.19, eigene Datei)
-- Warnton bei neuen Treffern (ab 0.19 waehlbar; wie Peon_Fishing, Kanal "Master")
R.SOUNDS = {
    { key = "raid",  kit = "RAID_WARNING",          id = 8959 },
    { key = "ready", kit = "READY_CHECK",           id = 8960 },
    { key = "alarm", kit = "ALARM_CLOCK_WARNING_3", id = 12889 },
    { key = "tell",  kit = "TELL_MESSAGE",          id = 3081 },
}

local GREY, ORANGE, GREEN, RED, GOLD = "|cff999999", "|cffff9933", "|cff60e060", "|cffff5555", "|cffffd100"
local function Money(v) return ns.Tooltip.Money(v) end
local function AHApi() return rawget(_G, "C_AuctionHouse") end
local function AHOpen() return ns.Scan.ahOpen and AHApi() ~= nil end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Now() return GetTime and GetTime() or time() end

R.entries = {}    -- [Schluessel] = Treffer
R.misses = {}     -- [Schluessel] = Abfragen ohne Antwort in Folge (diese Sitzung)
R.skip = {}       -- [Schluessel] = true: in dieser Sitzung auslassen
R.later = {}      -- Gegenstaende, deren Daten das Spiel erst laden muss
R.gone = {}       -- [Schluessel] = weggefallener Treffer (grau, mit Grund; ab 0.20)
-- Zaehler fuer die Anzeige und zur Fehlersuche (auch in PeonBrokerDB.radarStats, nach /reload lesbar)
local function NewStats()
    return { sent = 0, gameSent = 0, answered = 0, ansTime = 0, timeouts = 0, notReady = 0, dropped = 0, queued = 0, errors = 0,
             cached = 0, waitReady = 0, skipped = 0, t0 = Now(), lastTimeouts = {}, timeoutLog = {}, log = {} }
end
R.stats = NewStats()

---------------------------------------------------------------------------
-- Treffer
---------------------------------------------------------------------------
local function Cost(rows, limit)
    local _, cost = ns.Data.BelowLimit(rows, limit)
    return cost
end

-- Treffer aus Preisstufen bauen (Scan oder live); nil, wenn kein Schnaeppchen (mehr)
function R.Evaluate(key, rows, live, commodity)
    local D = ns.Data
    local market = D.Market()
    local e = market and market.items[key]
    local hp = ns.VendorPrice(D.ItemID(key))
    local deal = D.Deal(e, rows, hp, mod.db, D.Day(), key)
    if not deal then return nil end
    deal.key = key
    deal.name = (type(e) == "table" and e.nm) or D.ItemName(key, e)
    deal.quality = type(e) == "table" and e.ql or nil
    -- ab 0.57: Name noch nicht im Spiel geladen: Nummer zeigen, Daten anfordern, Name kommt mit GET_ITEM_INFO_RECEIVED
    if not deal.name then
        deal.name, deal.noName = tostring(key), true
        R.RequestName(D.ItemID(key))
    end
    deal.icon = ns.Buy.Icon(D.ItemID(key))
    deal.scans = type(e) == "table" and D.ScanCount(e, tonumber(mod.db.dealDays) or 7) or 0
    deal.cost = D.CostOf(rows, deal.qty)
    deal.rows = rows
    deal.live = live
    deal.commodity = commodity
    if commodity == nil then deal.commodity = D.IsCommodity(key) end
    if deal.commodity then
        -- Stapel (ab 0.17): Stapelgroesse des Spiels, hoechstens die Menge des Schnaeppchens
        local stack = select(8, ns.GetItemInfo(D.ItemID(key)))
        stack = (type(stack) == "number" and stack > 1) and stack or 20
        deal.stackQty = math.min(stack, deal.qty)
        if deal.stackQty > 1 then deal.stackGain = math.floor(deal.net * deal.stackQty - D.CostOf(rows, deal.stackQty)) end
    else
        for _, r in ipairs(rows) do
            if r.price <= deal.limit and r.ids and r.ids[1] then deal.auctionID, deal.price = r.ids[1], r.price; break end
        end
    end
    return deal
end

-- Beim Oeffnen: Treffer aus der Datenbank (Scan und gespeicherte Live-Ergebnisse), hoechstens radarMaxAge Min. alt
function R.MaxAge()
    local m = tonumber(mod.db.radarMaxAge) or 60
    if m <= 0 then return nil end
    return m * 60
end

function R.LoadFromScan()
    R.CheckHidden()
    local keep, before = {}, R.entries
    -- live gepruefte Treffer bleiben so lange wie die Treffer aus der Datenbank (ab 0.20; vorher nur 5 Min.)
    local keepAge = R.MaxAge() or math.huge
    for key, d in pairs(R.entries) do
        if d.live and d.checked and Now() - d.checked <= keepAge then keep[key] = d end
    end
    R.entries = keep
    local D, db = ns.Data, mod.db
    local market = D.Market()
    R.loaded = { market = market, scan = market and market.lastScan, age = R.MaxAge(), t = Now() }   -- ab 0.56: fuer R.LoadIfStale
    if not market then return end
    local maxAge = R.MaxAge()
    local now = time()
    for key, e in pairs(market.items) do
        -- ab 0.28: Varianten (Ausruestung mit Zusatz) nur mit gelerntem Suchschluessel, sonst waeren sie nicht pruefbar
        if not R.entries[key] and type(e) == "table" and e.lv and not e.gone and e.m and ns.Buy.KnownKey(key) then
            local seen = D.Seen(e)
            if seen and (not maxAge or now - seen <= maxAge) then
                local hp = ns.VendorPrice(D.ItemID(key))
                -- Vorauswahl: unter dem Haendlerpreis oder unter dem Median (genaue Pruefung mit Bereich in D.Deal, ab 0.21)
                if (hp and e.m < hp) or (e.md and e.m < e.md) then
                    local d = R.Evaluate(key, D.ParseLevels(e.lv), false, nil)
                    if d and not R.HiddenSeen(key, d) then d.checked = nil; d.seenT = seen; R.entries[key] = d end
                end
            end
        end
    end
    -- was vorher in der Liste stand und jetzt fehlt: grau mit Grund (ab 0.20)
    for key, old in pairs(before) do
        if not R.entries[key] and not R.IsHidden(key) then R.MarkGone(old, L.RADAR_GONE_RELOAD) end
    end
end

---------------------------------------------------------------------------
-- Weggefallene Treffer (ab 0.20, Wunsch von KarloDerBaer 02.10.2026): nicht mehr stillschweigend entfernen,
-- sondern R.GONE_TIME Sek. grau mit Grund zeigen und im Radar-Protokoll (PeonBrokerDB.radarLog) vermerken.
---------------------------------------------------------------------------
function R.Log(key, name, why, extra)
    if not mod:IsDebug() then return end   -- ab 0.28 nur mit /broker debug
    local acc = mod.acc
    if type(acc.radarLog) ~= "table" then acc.radarLog = {} end
    local log = acc.radarLog
    log[#log + 1] = { t = time(), key = key, name = name, why = why, extra = extra }
    while #log > R.LOG_MAX do table.remove(log, 1) end
end

function R.MarkGone(old, why, extra)
    if type(old) ~= "table" or old.key == nil then return end
    local g = {}
    for k, v in pairs(old) do g[k] = v end
    g.gone, g.goneWhy, g.goneUntil, g.flashUntil, g.newUntil = true, why, Now() + R.GONE_TIME, nil, nil
    R.gone[old.key] = g
    R.Log(old.key, old.name, why, extra)
    mod:Dbg(("Radar: weg %s - %s %s"):format(tostring(old.key), tostring(why), tostring(extra or "")))
    if R.selected and R.selected.key == old.key then R.selected = g; R.focus = nil end
end

-- Grund, warum ein Treffer nach einer Live-Pruefung kein Schnaeppchen mehr ist
function R.GoneReason(old, rows)
    local lv = ns.Data.Available(rows or {})
    if #lv == 0 then return L.RADAR_GONE_EMPTY end
    local cheapest = lv[1].price
    if old.kind == "vendor" then
        if cheapest >= (old.ref or 0) then return L.RADAR_GONE_SOLD:format(Money(cheapest)) end
        return L.RADAR_GONE_SMALL
    end
    if old.limit and cheapest > old.limit then return L.RADAR_GONE_SOLD:format(Money(cheapest)) end
    return L.RADAR_GONE_MARGIN
end

-- Gold des Charakters; kann ich mir mindestens ein Stueck leisten? (ab 0.17)
function R.Money()
    local ok, m = pcall(GetMoney)
    if ok and Num(m) then return m end
    return nil
end

-- Gold, das der Radar ausgeben darf: Gold minus Goldreserve (ab 0.19); nil = unbekannt (dann ohne Grenze)
function R.Budget(money)
    money = money or R.Money()
    if not money then return nil end
    local reserve = (tonumber(mod.db.radarReserve) or 0) * 10000
    return math.max(0, money - reserve)
end

function R.Affordable(d, budget)
    if budget == nil then budget = R.Budget() end
    return not budget or (d.price or d.offer or 0) <= budget
end

-- So viele Stueck des Schnaeppchens bekomme ich fuer budget (guenstigste zuerst)
function R.QtyFor(d, budget)
    local want = d.qty or 1
    if not budget then return want end
    local got, cost = 0, 0
    for _, l in ipairs(ns.Data.Available(d.rows or {})) do
        if got >= want then break end
        local take = math.min(l.qty, want - got)
        local can = l.price > 0 and math.floor((budget - cost) / l.price) or take
        local t = math.max(0, math.min(take, can))
        got, cost = got + t, cost + t * l.price
        if t < take then break end
    end
    return got
end

-- Mindestgewinn je Art (Haendler in Kupfer, Markt in Silber gespeichert)
function R.MinGain(kind)
    if kind == "vendor" then return tonumber(mod.db.dealMinVendor) or 10 end
    return (tonumber(mod.db.dealMinMarket) or 50) * 100
end

-- Hoechster Gewinn mit meinem Gold (ab 0.19): { gain, qty, cost }. Zwischen zwei Preisstufen ist der Gewinn
-- eine Gerade, deshalb genuegen als Kandidaten: 1 Stueck, jedes Stufenende und die Menge, die das Gold hergibt.
function R.Best(d, budget)
    local cap = R.QtyFor(d, budget)
    if cap < 1 then return { qty = 0, cost = 0 } end
    local cands, n = { 1, cap }, 0
    for _, l in ipairs(ns.Data.Available(d.rows or {})) do
        n = n + l.qty
        if n >= cap then break end
        cands[#cands + 1] = n
    end
    local best
    for _, q in ipairs(cands) do
        local g, c, got = ns.Data.ProfitOf(d, q)
        if g and (not best or g > best.gain or (g == best.gain and got < best.qty)) then best = { gain = g, qty = got, cost = c } end
    end
    return best or { qty = 0, cost = 0 }
end

-- Gewinn mit meinem Gold berechnen und merken; cant = lohnt sich mit meinem Gold nicht (unter dem Mindestgewinn)
function R.Annotate(d, budget)
    d.best = R.Best(d, budget)
    d.cant = not d.best.gain or d.best.gain <= 0 or d.best.gain < R.MinGain(d.kind)
    d.showGain = d.best.gain or d.gain
    return d
end

-- Sichtbar: gewaehlte Art (Haendler/AH) und, wenn nicht anders eingestellt, nur was sich mit meinem Gold lohnt
function R.Visible(d, budget)
    local kinds = mod.db.radarKind or "both"
    if kinds ~= "both" and d.kind ~= kinds then return false end
    if budget == nil then budget = R.Budget() end
    R.Annotate(d, budget)
    if not mod.db.radarShowExpensive and d.cant then return false end
    return true
end

---------------------------------------------------------------------------
-- Ausgeblendet (ab 0.18, Rechtsklick; mit KarloDerBaer abgestimmt 30.09.2026): mein Marktwissen zaehlt.
-- Fuer alle Charaktere, je Markt (PeonBrokerDB.radarHidden[Markt][Schluessel] = { t, name, q }).
-- Bleibt ausgeblendet, bis eine Pruefung (Scan oder live) zeigt, dass es kein Schnaeppchen mehr ist;
-- wird es danach wieder eins, erscheint es wieder. Wird weiter abgefragt (sonst merkt Broker das nicht).
---------------------------------------------------------------------------
function R.HiddenList(create)
    local acc = mod.acc
    if type(acc.radarHidden) ~= "table" then
        if not create then return nil end
        acc.radarHidden = {}
    end
    local mk = ns.MarketKey()
    local t = acc.radarHidden[mk]
    if type(t) ~= "table" then
        if not create then return nil end
        t = {}; acc.radarHidden[mk] = t
    end
    return t
end

function R.IsHidden(key)
    local t = R.HiddenList(false)
    return t ~= nil and t[key] ~= nil
end

function R.Hide(key, noRefresh)
    local d = R.entries[key]
    local t = R.HiddenList(true)
    t[key] = { t = time(), name = d and d.name or ns.Data.ItemName(key), q = d and d.quality or nil }
    R.entries[key] = nil
    R.gone[key] = nil
    if R.selected and R.selected.key == key then R.selected, R.focus = nil, nil end
    if not noRefresh then R.Refresh() end
end

-- Alle sichtbaren Treffer ausblenden (ab 0.19)
function R.HideAll()
    for _, d in ipairs(R.Rows()) do if not d.gone then R.Hide(d.key, true) end end
    R.Refresh()
end

-- Alle ausgeblendeten wieder zeigen (ab 0.19)
function R.ShowAllHidden()
    local t = R.HiddenList(false)
    if t then for key in pairs(t) do t[key] = nil end end
    R.FillHiddenPanel()
    R.LoadFromScan()
    R.Wake()
    R.Refresh()
end

function R.Unhide(key)
    local t = R.HiddenList(false)
    if t then t[key] = nil end
end

function R.HiddenCount()
    local n = 0
    for _ in pairs(R.HiddenList(false) or {}) do n = n + 1 end
    return n
end

-- Ergebnis einer Pruefung fuer einen ausgeblendeten Gegenstand: kein Schnaeppchen mehr -> wieder frei
function R.HiddenSeen(key, deal)
    if not R.IsHidden(key) then return false end
    if not deal then R.Unhide(key); return false end
    return true   -- noch Schnaeppchen: bleibt ausgeblendet
end

-- Nach einem vollen Scan / beim Oeffnen: ausgeblendete aus der Datenbank neu bewerten
function R.CheckHidden()
    local t = R.HiddenList(false)
    if not t then return end
    local D = ns.Data
    for key in pairs(t) do
        local e = D.Lookup(key)
        local deal = nil
        if type(e) == "table" and not e.gone and e.lv then deal = R.Evaluate(key, D.ParseLevels(e.lv), false, nil) end
        if not deal then t[key] = nil end
    end
end

function R.Rows()
    local rows, budget, vis = {}, R.Budget(), {}
    for key, d in pairs(R.entries) do
        if R.Visible(d, budget) then rows[#rows + 1] = d; vis[key] = true end
    end
    -- vorher sichtbar, jetzt nicht mehr (Gold/Mindestgewinn): grau mit Grund (ab 0.20)
    for key in pairs(R.lastVisible or {}) do
        local d = R.entries[key]
        if not vis[key] and d and not R.gone[key] then R.MarkGone(d, L.RADAR_GONE_GOLD) end
    end
    R.lastVisible = vis
    local now = Now()
    for key, g in pairs(R.gone) do
        -- gewaehlte graue Zeile bleibt, solange sie gewaehlt ist (ab 0.24)
        local keep = R.goneSel == key and R.selected and R.selected.key == key
        if vis[key] or (now > (g.goneUntil or 0) and not keep) then R.gone[key] = nil else rows[#rows + 1] = g end
    end
    return rows
end

---------------------------------------------------------------------------
-- Radar-Scan
---------------------------------------------------------------------------
-- Runde: Einkaufslisten, dann Gegenstaende mit den besten Chancen (Wert x Menge, gute Datenlage)
-- Reihenfolge der Gegenstaende (ab 0.16, im Reiter waehlbar): Einkaufslisten immer zuerst, dann je nach Auswahl
R.ORDERS = { "smart", "random", "commodity", "high", "low" }

function R.BuildRound()
    local D, db = ns.Data, mod.db
    local order = db.radarOrder or "smart"
    local round, seen = {}, {}
    for _, list in ipairs(ns.Buy.Lists()) do
        for key in pairs(list.items) do
            if not seen[key] and ns.Buy.KnownKey(key) then seen[key] = true; round[#round + 1] = key end   -- ab 0.28: Varianten nur mit Schluessel
        end
    end
    local market = D.Market()
    local cands = {}
    if market then
        local minScans = tonumber(db.dealScans) or 10
        for key, e in pairs(market.items) do
            if not seen[key] and type(e) == "table" and e.md and not e.gone and ns.Buy.KnownKey(key) then
                local hp = ns.VendorPrice(D.ItemID(key))
                local kinds = db.radarKind or "both"
                local vendorOk = kinds ~= "market" and hp and hp > 0
                local marketOk = kinds ~= "vendor" and D.ScanCount(e, tonumber(db.dealDays) or 7) >= minScans
                local good = vendorOk or marketOk
                if good then
                    cands[#cands + 1] = { key = key, score = e.md * math.min(e.q or 1, 200), price = e.md }
                end
            end
        end
    end
    local limit = #cands
    if order == "random" then
        for i = #cands, 2, -1 do
            local j = math.random(i)
            cands[i], cands[j] = cands[j], cands[i]
        end
    elseif order == "high" then
        table.sort(cands, function(a, b) return a.price > b.price end)
    elseif order == "low" then
        table.sort(cands, function(a, b) return a.price < b.price end)
    elseif order == "commodity" then
        for _, c in ipairs(cands) do c.com = D.IsCommodity(c.key) and 1 or 0 end
        table.sort(cands, function(a, b) if a.com ~= b.com then return a.com > b.com end return a.score > b.score end)
    else
        -- smart: Wert x Menge, nur die besten R.CANDIDATES
        table.sort(cands, function(a, b) return a.score > b.score end)
        limit = math.min(R.CANDIDATES, #cands)
    end
    for i = 1, limit do round[#round + 1] = cands[i].key end
    return round
end

function R.SetOrder(v)
    mod.db.radarOrder = v
    if R.running then R.round = R.BuildRound(); R.index = 0 end
    R.UpdateView()
end

-- Anzeige und Scan: Haendler, AH oder beides (ab 0.17); Treffer neu bewerten
function R.SetKind(v)
    mod.db.radarKind = v
    R.lastVisible = nil   -- eigene Auswahl: nicht als "weggefallen" zeigen
    if R.running then R.round = R.BuildRound(); R.index = 0 end
    for key, d in pairs(R.entries) do
        local nd = R.Evaluate(key, d.rows or {}, d.live, d.commodity)
        if nd then
            nd.checked, nd.seenT, nd.newUntil, nd.tries = d.checked, d.seenT, d.newUntil, d.tries
            R.entries[key] = nd
        else
            R.entries[key] = nil
        end
    end
    R.LoadFromScan()
    R.Refresh()
end

-- Gegenstandsdaten im Spiel geladen? Sonst anfordern (Vermutung 0.16: sonst schickt das Spiel die Abfrage nicht ab)
function R.ItemReady(key)
    local ci = rawget(_G, "C_Item")
    if not (ci and ci.IsItemDataCachedByID) then return true end
    local id = ns.Data.ItemID(key)
    local ok, cached = pcall(ci.IsItemDataCachedByID, id)
    if not ok or cached then return true end
    if ci.RequestLoadItemDataByID then pcall(ci.RequestLoadItemDataByID, id) end
    return false
end

-- Treffer aus dem Scan, die noch nicht live geprueft sind (hoechstens 2 Versuche je Treffer)
function R.Unchecked()
    local best
    for key, d in pairs(R.entries) do
        if not d.live and (d.tries or 0) < 2 and (d.loadWait or 0) < 30 and (not best or d.gain > R.entries[best].gain) then best = key end
    end
    return best
end

-- Abfrage-Schleife: laeuft beim Radar-Scan und, auch ohne ihn, bis alle Scan-Treffer einmal geprueft sind
function R.Wake()
    if R.loop or not AHOpen() or ns.Scan.state then return end
    if not (R.running or R.focus or R.soon or R.Unchecked() ~= nil) then return end
    R.loop = true
    R.gen = (R.gen or 0) + 1
    R.Schedule()
end

---------------------------------------------------------------------------
-- Nur Warnton (ab 0.16, abschaltbar, Standard an): waehrend des Radar-Scans alle Tonkanaele ausser "Gesamt"
-- (dort spielt der Warnton) auf 0 und Ton auch im Hintergrund. Zurueck beim Stoppen, Verlassen des Reiters,
-- Schliessen des Auktionshauses und beim Ausloggen/Reload; alte Werte stehen solange in PeonBrokerDB.radarMuteSaved.
---------------------------------------------------------------------------
R.MUTE_CVARS = {
    Sound_SFXVolume = "0", Sound_MusicVolume = "0", Sound_AmbienceVolume = "0", Sound_DialogVolume = "0",
    Sound_EnableSoundWhenGameIsInBG = "1", Sound_EnableAllSound = "1",
}

local function GetCV(name)
    local cv = rawget(_G, "C_CVar")
    local ok, v
    if cv and cv.GetCVar then ok, v = pcall(cv.GetCVar, name) elseif GetCVar then ok, v = pcall(GetCVar, name) end
    if ok then return v end
    return nil
end

local function SetCV(name, value)
    local cv = rawget(_G, "C_CVar")
    if cv and cv.SetCVar then return pcall(cv.SetCVar, name, value) end
    if SetCVar then return pcall(SetCVar, name, value) end
    return false
end

function R.MuteOn()
    if mod.acc.radarMuteSaved or not (mod.db.radarMute and mod.db.radarSound) then return end
    local saved = {}
    for name, value in pairs(R.MUTE_CVARS) do
        local old = GetCV(name)
        if old ~= nil then saved[name] = tostring(old); SetCV(name, value) end
    end
    mod.acc.radarMuteSaved = saved
end

function R.MuteOff()
    local saved = mod.acc and mod.acc.radarMuteSaved
    if type(saved) ~= "table" then return end
    for name, value in pairs(saved) do SetCV(name, value) end
    mod.acc.radarMuteSaved = nil
end

function R.SetMute(on)
    mod.db.radarMute = on and true or false
    if on and R.running then R.MuteOn() else R.MuteOff() end
end

function R.Start()
    if R.running or not AHOpen() or ns.Scan.state then return end
    R.running = true
    R.round = R.BuildRound()
    R.index = 0
    R.tick = 0
    R.stats = NewStats()
    R.stats.started = date and date("%Y-%m-%d %H:%M:%S") or nil
    mod.acc.radarStats = mod:IsDebug() and R.stats or nil   -- ab 0.28 nur mit /broker debug gespeichert
    mod:Dbg(("Radar gestartet: %d Gegenstaende in der Runde"):format(#R.round))
    R.MuteOn()
    R.UpdateView()
    R.Wake()
end

-- Radar-Scan aus (Knopf); die Schnellpruefung der Scan-Treffer laeuft ggf. weiter
function R.Stop()
    R.MuteOff()
    if not R.running then return end
    R.running = false
    R.UpdateView()
end

-- Reiter verlassen oder Auktionshaus zu: alles anhalten
function R.Halt()
    R.CancelPre()
    R.MuteOff()
    R.running = false
    R.loop = false
    R.pending = nil
    R.focus = nil
    R.UpdateView()
end

-- Voller Scan (Broker-Scan) gestartet (ab 0.19): Radar-Scan beenden, keine Abfragen waehrend des Scans
function R.OnFullScan()
    R.MuteOff()
    R.running = false
    R.loop = false
    R.pending = nil
    R.UpdateView()
end

-- Treffer gewaehlt (ab 0.19): im Auktionshaus zeigen und solange er gewaehlt ist regelmaessig neu abfragen.
-- Die erste Abfrage macht das Auktionshaus selbst (Anzeige des Gegenstands); Broker wartet vorher, bis keine
-- eigene Abfrage mehr unterwegs ist, damit sich beide nicht in die Quere kommen (Blizzard-Fenster blieb sonst alt).
function R.SelectRow(r)
    R.selected = r
    R.focus = (r and not r.gone) and { key = r.key, at = 0, show = true } or nil
    -- weggefallene (graue) Zeile (ab 0.24, Feedback #7): trotzdem im Blizzard-Fenster zeigen; Radar pausiert
    -- solange, damit die Anzeige stehen bleibt
    R.goneSel = (r and r.gone) and r.key or nil
    if r and r.gone and AHOpen() then ns.Buy.ShowInAH({ key = r.key, offer = r.offer, qty = r.qty }) end
    R.Wake()
    R.UpdateView()
end

-- Abfrage fuer den gewaehlten Treffer; true = gesendet
function R.SendFocus()
    local f = R.focus
    local d = R.entries[f.key]
    if not d then R.focus = nil; return false end
    f.at = Now() + R.FOCUS_EVERY
    if f.show then
        f.show = false
        local itemKey = ns.Buy.ItemKeyFor(f.key)
        R.pending = { key = f.key, itemID = itemKey.itemID, itemKey = itemKey, sent = Now(), ev = {}, viaAH = true }
        R.lastSend = Now()
        R.lastKey = f.key
        if ns.Buy.ShowInAH({ key = d.key, offer = d.offer, qty = d.qty }) then return true end
        R.pending = nil
    end
    return R.Send(f.key, nil, true)
end

function R.Schedule()
    if not (R.loop and C_Timer) then return end
    local gen = R.gen
    C_Timer.After(R.TICK, function() if R.gen == gen then R.Tick() end end)
end

-- Naechster Gegenstand: zuerst ungepruefte Scan-Treffer, dann jeder dritte Schritt den am laengsten
-- nicht geprueften Treffer, sonst die Runde
function R.NextKey()
    -- zweite Pruefung nach "keine Angebote" (ab 0.20.1)
    local soon = R.soon
    if soon and R.entries[soon.key] and Now() >= soon.at then R.soon = nil; return soon.key end
    if soon and not R.entries[soon.key] then R.soon = nil end
    local first = R.Unchecked()
    if first ~= nil then return first end
    if not R.running then return nil end
    R.tick = R.tick + 1
    if R.tick % 3 == 0 then
        local oldest
        for key, d in pairs(R.entries) do
            if (not d.checked or Now() - d.checked >= R.RECHECK) and (d.loadWait or 0) < 30 then
                if not oldest or (d.checked or 0) < (R.entries[oldest].checked or 0) then oldest = key end
            end
        end
        if oldest ~= nil then return oldest end
    end
    -- Gegenstaende, deren Daten erst geladen werden mussten
    for i, key in ipairs(R.later) do
        if R.ItemReady(key) then table.remove(R.later, i); return key end
    end
    if #R.round == 0 then return nil end
    for _ = 1, #R.round do
        if R.index >= #R.round then R.round = R.BuildRound(); R.index = 0 end   -- neue Runde mit frischen Daten
        R.index = R.index + 1
        local key = R.round[R.index]
        if key ~= nil and not R.skip[key] then
            if R.ItemReady(key) then return key end
            if #R.later < 50 then R.later[#R.later + 1] = key end
            R.stats.notCached = (R.stats.notCached or 0) + 1
        end
    end
    return nil
end

function R.Tick()
    if not R.loop then return end
    if not (AHOpen() and R.Shown()) then R.Halt(); return end
    if ns.Scan.state then R.OnFullScan(); return end
    local ah = AHApi()
    local st = R.stats
    if R.pending and R.pending.browse and Now() - R.pending.sent >= ns.Buy.KEY_WAIT + 3 then R.pending = nil end   -- Sicherung
    if R.pending and not R.pending.browse and Now() - R.pending.sent >= R.WAIT then
        -- keine Antwort. Beobachtet (0.14.4): das Spiel schickt manche Abfragen gar nicht ab oder meldet kein
        -- neues Ergebnis, vermutlich weil es fuer den Gegenstand schon Ergebnisse hat. Dann diese lesen.
        local p = R.pending
        R.pending = nil
        if not p.forBuy and R.FromCache(p) then
            st.cached = (st.cached or 0) + 1
        else
            st.timeouts = st.timeouts + 1
            table.insert(st.lastTimeouts, tostring(p.key))
            while #st.lastTimeouts > 20 do table.remove(st.lastTimeouts, 1) end
            if #st.timeoutLog < 30 then
                st.timeoutLog[#st.timeoutLog + 1] = tostring(p.key) .. (p.notCached and " ungeladen " or " ") .. table.concat(p.ev or {}, ",")
            end
            -- wiederholt ohne Antwort: fuer diese Sitzung auslassen
            R.misses[p.key] = (R.misses[p.key] or 0) + 1
            if R.misses[p.key] >= R.SKIP_AFTER and not R.skip[p.key] then
                R.skip[p.key] = true
                st.skipped = (st.skipped or 0) + 1
            end
        end
    end
    local busy = R.pending ~= nil
    local now = Now()
    local due = now - (R.lastSend or 0) >= R.INTERVAL
    local ready = not ah.IsThrottledMessageSystemReady or ah.IsThrottledMessageSystemReady()
    if not busy and due and not ready then st.waitReady = (st.waitReady or 0) + (now - (R.lastTick or now)) end
    R.lastTick = now
    if R.focus and not R.entries[R.focus.key] then R.focus = nil end
    if R.goneSel and not (R.selected and R.selected.key == R.goneSel and R.selected.gone) then R.goneSel = nil end
    if not busy and due and ready and not R.job and R.focus and now >= R.focus.at and R.ItemReady(R.focus.key) then
        R.SendFocus()
    elseif not busy and due and ready and not R.job and not R.focus and not R.goneSel then
        -- solange ein Treffer gewaehlt ist, pausiert der Radar-Scan (ab 0.20): jede fremde Abfrage
        -- veraendert sonst die Anzeige im Blizzard-Fenster
        local key = R.NextKey()
        if key ~= nil and not R.ItemReady(key) then
            -- Daten erst laden (Treffer: hoechstens ~3 s lang, dann uebersprungen)
            local d = R.entries[key]
            if d then d.loadWait = (d.loadWait or 0) + 1 end
            R.stats.notCached = (R.stats.notCached or 0) + 1
        elseif key ~= nil then
            R.Send(key)
        elseif not R.running and not R.focus and not R.soon then
            R.loop = false
            R.UpdateView()
            return
        end
    end
    R.Schedule()
end

-- refresh = true (ab 0.20.2, gewaehlter Treffer): wie Blizzards "Neu laden" (Refresh...SearchResults); eine normale
-- Suche schickt das Spiel nicht ab, wenn es fuer den Gegenstand schon Ergebnisse hat - Blizzard-Fenster blieb dann alt
function R.Send(key, forBuy, refresh)
    local ah = AHApi()
    local itemKey = ns.Buy.ItemKeyFor(key)
    local order = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0
    R.pending = { key = key, itemID = itemKey.itemID, itemKey = itemKey, sent = Now(), forBuy = forBuy, ev = {} }
    local ci = rawget(_G, "C_Item")
    if ci and ci.IsItemDataCachedByID then
        local okc, c = pcall(ci.IsItemDataCachedByID, itemKey.itemID)
        if okc and not c then R.pending.notCached = true end
    end
    R.lastSend = Now()
    local d = R.entries[key]
    if d and not d.live then d.tries = (d.tries or 0) + 1 end
    local ok
    local refreshFn = refresh and (ns.Data.IsCommodity(key) and ah.RefreshCommoditySearchResults or ah.RefreshItemSearchResults)
    if refreshFn then
        ok = pcall(refreshFn, ns.Data.IsCommodity(key) and itemKey.itemID or itemKey)
    end
    if not ok then
        ok = pcall(ah.SendSearchQuery or ah.SendSellSearchQuery, itemKey, { { sortOrder = order, reverseSort = false } }, true)
    end
    R.stats.sent = R.stats.sent + 1
    R.lastKey = key
    -- Protokoll der ersten 30 Abfragen (Fehlersuche 0.14.4)
    local log = R.stats.log
    if log and #log < 30 then
        local f = rawget(_G, "AuctionHouseFrame")
        local mode = type(f) == "table" and f.GetDisplayMode and select(2, pcall(f.GetDisplayMode, f)) or nil
        R.lastLog = { key = tostring(key), t = math.floor((Now() - R.stats.t0) * 10) / 10, ok = ok,
            ready = ah.IsThrottledMessageSystemReady and ah.IsThrottledMessageSystemReady() or false,
            mode = type(mode) == "table" and "table" or tostring(mode), sent = false, answered = false }
        log[#log + 1] = R.lastLog
    else
        R.lastLog = nil
    end
    if not ok then R.pending = nil end
    return ok
end

local function OnResults(commodity, arg)
    local p = R.pending
    if not p or p.browse then return end
    local id = commodity and arg or (type(arg) == "table" and arg.itemID)
    if id ~= p.itemID then return end
    local rows = commodity and ns.Live.ReadCommodity(p.itemID) or ns.Buy.ReadItemRows(type(arg) == "table" and arg or p.itemKey, p.key)
    -- leer, aber das Spiel laedt noch (nicht vollstaendig): weiter warten (ab 0.20.1; KarloDerBaer 02.10.2026:
    -- Ausruestung stand als "weg", obwohl das Angebot noch da war)
    if #rows == 0 and (rows.partial or rows.foreign) then
        p.loading = (p.loading or 0) + 1
        R.stats.loading = (R.stats.loading or 0) + 1
        return
    end
    R.pending = nil
    R.misses[p.key] = nil
    R.stats.answered = R.stats.answered + 1
    if R.lastLog and R.lastLog.key == tostring(p.key) then R.lastLog.answered = true end
    R.stats.ansTime = R.stats.ansTime + (Now() - p.sent)
    p.evKey = type(arg) == "table" and ns.Live.KeyText(arg) or tostring(arg)
    R.Apply(p, rows, commodity)
end

-- Ohne Antwort: vorhandene Ergebnisse des Spiels lesen (nur wenn es welche gibt)
function R.FromCache(p)
    -- beide Arten versuchen (unsere Vermutung zur Warenart kann falsch sein)
    for _, commodity in ipairs({ true, false }) do
        local ok, rows = pcall(function()
            if commodity then return ns.Live.ReadCommodity(p.itemID) end
            return ns.Buy.ReadItemRows(p.itemKey, p.key)
        end)
        if ok and type(rows) == "table" and #rows > 0 then
            R.misses[p.key] = nil
            R.Apply(p, rows, commodity, true)
            return true
        end
    end
    return false
end

-- Ergebnis auswerten: Treffer neu, bestaetigt oder weg
-- cached = Ergebnisse, die das Spiel schon hatte (ohne Antwort auf unsere Abfrage, ab 0.20): koennen alt sein,
-- deshalb nicht in die Datenbank und kein Grund, einen Treffer zu entfernen
function R.Apply(p, rows, commodity, cached)
    if not cached then
        ns.Buy.live[p.key] = { rows = rows, t = time(), commodity = commodity }
        ns.Data.ApplyLive(p.key, rows, time())
    end
    if rows.partial then R.stats.partial = (R.stats.partial or 0) + 1 end
    local old = R.entries[p.key]
    local d = R.Evaluate(p.key, rows, true, commodity)
    local hidden = R.HiddenSeen(p.key, d)
    if hidden then d = nil end   -- ausgeblendet und noch Schnaeppchen: nicht zeigen
    if not d and cached then R.Refresh(); return end
    -- keine Angebote mehr: erst nach einer zweiten Pruefung glauben (ab 0.20.1)
    if not d and not hidden and old and not old.emptySeen and #ns.Data.Available(rows) == 0 then
        old.emptySeen = true
        R.soon = { key = p.key, at = Now() + R.CONFIRM_AFTER }
        R.stats.emptyOnce = (R.stats.emptyOnce or 0) + 1
        R.Wake()
        R.Refresh()
        return
    end
    if d then
        d.checked = Now()
        if old then d.newUntil, d.flashUntil = old.newUntil, old.flashUntil end
        if not old and R.Visible(d) then
            d.newUntil = Now() + R.NEW_TIME
            d.flashUntil = Now() + (tonumber(mod.db.radarFlash) or 5)
            if mod.db.radarSound then R.PlayAlert() end
            mod:Dbg("Radar: neuer Treffer " .. tostring(p.key))
        end
        R.entries[p.key] = d
        R.gone[p.key] = nil
    else
        -- keine Angebote, Einzelgegenstand: erst mit dem Schluessel des Spiels nochmal suchen (ab 0.24, Feedback #5)
        if old and not hidden and not commodity and not rows.partial and #ns.Data.Available(rows) == 0 and R.TryOtherKey(p, old, rows) then
            R.Refresh()
            return
        end
        if old and not hidden then
            local lv = ns.Data.Available(rows)
            R.MarkGone(old, R.GoneReason(old, rows), ("vorher %s x%s, jetzt %s%s, %d Stufen, Schluessel %s"):format(tostring(old.offer), tostring(old.qty),
                tostring(lv[1] and lv[1].price or "-"), rows.partial and " (Teil)" or "", #rows, tostring(p.evKey or "-")))
        end
        R.entries[p.key] = nil
    end
    if p.forBuy then R.lastChecked = p.key end
    R.Refresh()
end

-- Einzelgegenstand ohne Angebote: Schluessel ueber die Browse-Suche finden (je Gegenstand einmal je Sitzung).
-- Gefunden: gleich nochmal mit diesem Schluessel pruefen; sonst wie bisher "weg".
R.keyTries = {}
function R.TryOtherKey(p, old, rows)
    if (R.keyTries[p.key] or 0) >= 1 then return false end
    R.keyTries[p.key] = (R.keyTries[p.key] or 0) + 1
    ns.Buy.ForgetKey(p.key)   -- ein frueher gemerkter Schluessel hat nichts geliefert
    local job = { key = p.key, itemID = p.itemID, sent = Now(), ev = {}, browse = true }
    R.pending = job
    R.lastSend = Now()
    local started = ns.Buy.FindKey(p.key, function(found)
        if R.pending == job then R.pending = nil end
        local d = R.entries[p.key]
        if found and d then
            d.emptySeen = nil
            R.soon = { key = p.key, at = Now() }
            R.stats.altKeys = (R.stats.altKeys or 0) + 1
            R.Wake()
        elseif d then
            R.MarkGone(d, R.GoneReason(d, rows), ("vorher %s x%s, auch ueber die Suche nichts gefunden"):format(tostring(d.offer), tostring(d.qty)))
            R.entries[p.key] = nil
        end
        R.Refresh()
    end)
    if not started then
        if R.pending == job then R.pending = nil end
        return false
    end
    return true
end

-- Warnton (ab 0.19 waehlbar, Kanal "Master" - hoerbar auch bei "Nur Warnton")
function R.PlayAlert(key)
    key = key or mod.db.radarSoundKey or "raid"
    if not PlaySound then return end
    for _, s in ipairs(R.SOUNDS) do
        if s.key == key then
            local id = (SOUNDKIT and SOUNDKIT[s.kit]) or s.id
            pcall(PlaySound, id, "Master")
            return
        end
    end
end

---------------------------------------------------------------------------
-- Kaufen
---------------------------------------------------------------------------
-- Bestes Haendler-Schnaeppchen (ab 0.19): hoechster Gewinn mit meinem Gold, nur sichtbare, die sich lohnen
function R.Top(kind)
    local best, budget = nil, R.Budget()
    for _, d in pairs(R.entries) do
        if (kind == nil or d.kind == kind) and R.Visible(d, budget) and not d.cant and d.best.qty > 0
            and (not best or d.best.gain > best.best.gain) then best = d end
    end
    return best
end

-- Menge fuer "Stapel": Stapelgroesse, hoechstens die Schnaeppchen-Menge
function R.StackQty(d)
    if not d or not d.commodity then return 1 end
    return math.min(d.stackQty or 1, d.qty or 1)
end

-- Menge je Knopf: 1 Stueck; Mitte = ab Gewinn (wenn erst ab n Stueck), sonst bis ein Stapel (Massenware);
-- alle des Schnaeppchens; "best" = was mit meinem Gold den hoechsten Gewinn bringt (Schnellkauf, ab 0.19)
function R.ModeQty(d, mode)
    if not d or d.gone then return 0 end
    if mode == "one" then return 1 end
    if mode == "best" then return (d.best and d.best.qty) or 0 end
    if mode == "stack" then
        local minQ = R.MinProfitQty(d)
        if minQ and minQ > 1 then return minQ end
        if d.commodity then return R.StackQty(d) end
        return 0
    end
    return d.qty or 1
end

-- kleinste Menge mit Gewinn (Markt: sonst verkauft das naechste Angebot billiger als ich gekauft habe)
function R.MinProfitQty(d)
    if not d then return nil end
    for n = 1, d.qty or 1 do
        local g = ns.Data.ProfitOf(d, n)
        if g and g > 0 then return n end
    end
    return nil
end

-- Auktionen fuer n Einzelgegenstaende, guenstigste zuerst: { { id, price }, ... }
function R.AuctionQueue(d, n)
    local q, rows = {}, {}
    for _, r in ipairs(d.rows or {}) do rows[#rows + 1] = r end
    table.sort(rows, function(a, b) return a.price < b.price end)
    for _, r in ipairs(rows) do
        for _, id in ipairs(r.ids or {}) do
            if #q >= n then return q end
            q[#q + 1] = { id = id, price = r.price }
        end
    end
    return q
end

local function JobTimer(job, sec)
    job.stamp = (job.stamp or 0) + 1
    local stamp = job.stamp
    if C_Timer then
        C_Timer.After(sec, function() if R.job == job and job.stamp == stamp then R.FinishJob(job.done and job.done > 0) end end)
    end
end

-- Ein Klick: je nach Stand pruefen, Kauf starten oder bestaetigen
---------------------------------------------------------------------------
-- Schnellkauf mit einem Klick (ab 0.24, Feedback #6): Fuer das beste Haendler-Schnaeppchen (Massenware) holt
-- Broker den Preis schon vorher beim Spiel (StartCommoditiesPurchase). Der Klick bestaetigt dann sofort.
-- Die Anfrage wird alle PRE_TTL Sek. erneuert; kommt zweimal keine Antwort, bleibt es fuer die Sitzung bei
-- zwei Klicks (das Spiel hat die Anfrage dann wohl nicht angenommen).
-- Ab 0.33.1 aus: StartCommoditiesPurchase geht nur direkt aus einem Klick, sonst meldet das Spiel
-- ADDON_ACTION_BLOCKED (pcall faengt das nicht ab). Der Schnellkauf braucht deshalb zwei Klicks.
---------------------------------------------------------------------------
R.preOff = true
R.PRE_TTL = 15      -- Sekunden, so lange gilt ein vorab geholter Preis
R.PRE_WAIT = 5      -- Sekunden auf die Antwort warten
R.PRE_EVERY = 3     -- hoechstens so oft eine neue Anfrage

-- Blizzards Kaufansicht fuer Massenware offen? (ab 0.28) Dann gehoert eine Preisantwort des Spiels womoeglich zu
-- Blizzards eigenem Kauf - Broker holt dann keinen Preis vorab und bricht nie einen Kauf ab.
function R.BlizzardBuying()
    local f = rawget(_G, "AuctionHouseFrame")
    if type(f) ~= "table" then return false end
    local cb = rawget(f, "CommoditiesBuyFrame")
    if type(cb) == "table" and cb.IsShown then
        local ok, shown = pcall(cb.IsShown, cb)
        if ok and shown then return true end
    end
    local modes = rawget(_G, "AuctionHouseFrameDisplayMode")
    if type(modes) == "table" and modes.CommoditiesBuy ~= nil and type(f.GetDisplayMode) == "function" then
        local ok, m = pcall(f.GetDisplayMode, f)
        if ok and m == modes.CommoditiesBuy then return true end
    end
    return false
end

function R.CancelPre()
    local pre = R.pre
    R.pre = nil
    -- nicht abbrechen, waehrend Blizzards Kaufansicht offen ist: das koennte deren Kauf treffen (ab 0.28)
    if pre and not R.BlizzardBuying() then pcall(AHApi().CancelCommoditiesPurchase) end
end

function R.Prequote()
    if R.preOff or R.job or not AHOpen() or not R.Shown() or ns.Scan.state then return end
    local ah = AHApi()
    if not ah.StartCommoditiesPurchase then return end
    -- ab 0.28: kein Vorab-Preis, solange ein Treffer gewaehlt ist oder Blizzards Kaufansicht offen ist
    -- (sonst koennte Broker Blizzards Preisantwort fuer seine halten); offene Anfrage still verwerfen
    if R.selected or R.BlizzardBuying() then R.pre = nil; return end
    local top = R.quickTarget
    local pre = R.pre
    local now = Now()
    if pre and pre.stage == "quote" and now - pre.t >= R.PRE_WAIT then
        R.pre = nil
        R.preMiss = (R.preMiss or 0) + 1
        if R.preMiss >= 2 then R.preOff = true; mod:Dbg("Schnellkauf: Preis vorab kommt nicht - zwei Klicks"); return end
        pre = nil
    end
    if not top or not top.commodity then if pre then R.CancelPre() end return end
    local _, got, lastPrice = ns.Data.CostOf(top.rows or {}, R.ModeQty(top, "best"))
    if got < 1 then if pre then R.CancelPre() end return end
    if pre and pre.key == top.key and pre.qty == got then
        if pre.stage == "quote" or now - pre.at < R.PRE_TTL then return end   -- unterwegs bzw. noch gueltig
    end
    if now - (R.preAt or 0) < R.PRE_EVERY then return end
    if ah.IsThrottledMessageSystemReady and not ah.IsThrottledMessageSystemReady() then return end
    if pre then R.CancelPre() end
    R.preAt = now
    local ok = pcall(ah.StartCommoditiesPurchase, ns.Data.ItemID(top.key), got)
    if ok then
        local p = { key = top.key, id = ns.Data.ItemID(top.key), qty = got, limit = lastPrice, stage = "quote", t = now }
        R.pre = p
        if C_Timer then C_Timer.After(R.PRE_WAIT + 0.1, function() if R.pre == p then R.UpdateView() end end) end
    end
end

function R.BuyStep(d, mode)
    mode = mode or "one"
    if not d or d.gone or not AHOpen() then return end
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.SELL_COMBAT); return end
    local ah = AHApi()
    local job = R.job
    -- Schnellkauf mit vorab geholtem Preis: gleich bestaetigen (ab 0.24)
    local pre = R.pre
    if not job and mode == "best" and pre and pre.stage == "ready" and pre.key == d.key and Now() - pre.at < R.PRE_TTL then
        R.pre = nil
        R.job = { key = d.key, id = pre.id, qty = pre.qty, limit = pre.limit, name = d.name, stage = "wait", kind = d.kind,
                  mode = mode, t = Now(), done = 0, total = pre.total, unit = pre.unit }
        local ok = pcall(ah.ConfirmCommoditiesPurchase, pre.id, pre.qty)
        if not ok then R.job = nil; mod:Print(L.BUY_FAILED) else JobTimer(R.job, 20) end
        R.UpdateView()
        return
    end
    if not job and d.commodity then R.pre = nil end   -- eigener Kauf ersetzt die Anfrage
    -- Massenware: zweiter Klick bestaetigt
    if job and job.stage == "confirm" and job.key == d.key and job.mode == mode then
        job.stage = "wait"
        local ok = pcall(ah.ConfirmCommoditiesPurchase, job.id, job.qty)
        if not ok then R.job = nil; mod:Print(L.BUY_FAILED) end
        R.UpdateView()
        return
    end
    -- Einzelgegenstaende: naechste Auktion (ein Klick je Auktion, ab 0.19)
    if job and job.stage == "next" and job.key == d.key and job.mode == mode then
        job.idx = job.idx + 1
        local a = job.queue[job.idx]
        job.stage = "wait"
        local ok = pcall(ah.PlaceBid, a.id, a.price)
        if not ok then R.FinishJob(job.done > 0); mod:Print(L.BUY_FAILED); return end
        JobTimer(job, 20)
        R.UpdateView()
        return
    end
    if job then return end
    local id = ns.Data.ItemID(d.key)
    local qty = R.ModeQty(d, mode)
    if qty < 1 then return end
    if d.commodity then
        -- Der Preis vom Spiel ist die Pruefung, ob das guenstige Angebot noch da ist; Grenze = Preis des teuersten Stuecks
        local _, got, lastPrice = ns.Data.CostOf(d.rows or {}, qty)
        if got < 1 then R.MarkGone(d, L.RADAR_GONE_EMPTY); R.entries[d.key] = nil; R.Refresh(); return end
        local ok = pcall(ah.StartCommoditiesPurchase, id, got)
        if not ok then mod:Print(L.BUY_FAILED); return end
        R.job = { key = d.key, id = id, qty = got, limit = lastPrice, name = d.name, stage = "quote", kind = d.kind, mode = mode, t = Now(), done = 0 }
    else
        -- Einzelgegenstand: nur mit frischer Pruefung kaufen, sonst erst pruefen
        if not d.live or not d.checked or Now() - d.checked > R.FRESH then
            R.Send(d.key, true)
            R.checking = d.key
            R.UpdateView()
            return
        end
        local queue = R.AuctionQueue(d, qty)
        if #queue == 0 then R.Send(d.key, true); R.UpdateView(); return end
        local ok = pcall(ah.PlaceBid, queue[1].id, queue[1].price)
        if not ok then mod:Print(L.BUY_FAILED); return end
        R.job = { key = d.key, items = true, queue = queue, idx = 1, qty = #queue, done = 0, cost = 0, name = d.name,
                  stage = "wait", kind = d.kind, mode = mode, t = Now() }
    end
    JobTimer(R.job, 20)
    R.UpdateView()
end

function R.OnPriceUpdated(unitPrice, totalPrice)
    local job = R.job
    -- Preis vorab fuer den Schnellkauf (ab 0.24)
    local pre = R.pre
    if (not job or job.stage ~= "quote") and pre and pre.stage == "quote" then
        -- Blizzards Kaufansicht offen: Antwort gehoert womoeglich zu Blizzards Kauf - nichts tun, nichts abbrechen (ab 0.28)
        if R.BlizzardBuying() then R.pre = nil; R.UpdateView(); return end
        R.preMiss = 0
        if Num(unitPrice) and unitPrice > pre.limit then
            R.CancelPre()
            local d = R.entries[pre.key]
            if d then d.live, d.tries, d.checked = false, 0, nil; R.Wake() end   -- nicht mehr so guenstig: neu pruefen
        else
            pre.stage, pre.total, pre.unit, pre.at = "ready", totalPrice, unitPrice, Now()
            if C_Timer then C_Timer.After(R.PRE_TTL + 0.1, function() if R.pre == pre then R.UpdateView() end end) end   -- erneuern
        end
        R.UpdateView()
        return
    end
    if not job or job.stage ~= "quote" then return end
    if Num(unitPrice) and unitPrice > job.limit then
        -- nicht mehr so guenstig: abbrechen, Treffer neu pruefen lassen
        pcall(AHApi().CancelCommoditiesPurchase)
        mod:Print(L.RADAR_GONE:format(job.name))
        R.MarkGone(R.entries[job.key], L.RADAR_GONE_PRICE:format(Money(unitPrice)))
        R.entries[job.key] = nil
        R.job = nil
        R.Refresh()
        return
    end
    job.total, job.unit = totalPrice, unitPrice
    job.stage = "confirm"
    R.UpdateView()
end

-- Kauf fertig (oder abgebrochen): fuers Buch vermerken, Haendlerware merken, Rest neu pruefen lassen
function R.FinishJob(ok)
    local job = R.job
    if not job then return end
    R.job = nil
    local n = job.items and job.done or (ok and job.qty or 0)
    local cost = job.items and job.cost or (job.total or job.price)
    if n > 0 then
        mod:Print(L.BUY_DONE:format(n, job.name, cost and Money(cost) or "?"))
    end
    -- Rest pruefen lassen: Treffer bleibt, bis die naechste Abfrage zeigt, was noch da ist
    local d = R.entries[job.key]
    if n > 0 and d and (d.qty or 0) > n then
        d.qty, d.live, d.tries, d.checked = d.qty - n, false, 0, nil
        if R.focus and R.focus.key == job.key then R.focus.at = 0 end
        R.Wake()
    elseif n > 0 or not ok then
        if d and not ok then d.live, d.tries, d.checked = false, 0, nil; R.Wake()
        else
            if d and n > 0 then R.MarkGone(d, L.RADAR_GONE_BOUGHT) end
            R.entries[job.key] = nil
        end
    end
    R.Refresh()
end

-- Massenware gekauft / fehlgeschlagen; Einzelgegenstand: eine Auktion gekauft (auctionID)
function R.OnBought(ok, auctionID)
    local job = R.job
    if not job then return end
    if job.items then
        if not ok then R.FinishJob(false); mod:Print(L.BUY_FAILED); return end
        local a = job.queue[job.idx]
        if job.stage ~= "wait" or (auctionID ~= nil and a and a.id ~= auctionID) then return end   -- nicht unsere Auktion
        job.done, job.cost = job.done + 1, job.cost + (a and a.price or 0)
        -- gekaufte Auktion aus den Stufen nehmen, damit Kosten und Gewinn der Knoepfe stimmen
        local d = R.entries[job.key]
        if d and a then
            for _, r in ipairs(d.rows or {}) do
                for i, id in ipairs(r.ids or {}) do
                    if id == a.id then table.remove(r.ids, i); r.qty = math.max(0, r.qty - 1); break end
                end
            end
        end
        if job.idx < #job.queue then
            job.stage = "next"
            JobTimer(job, 60)
            R.Refresh()
        else
            R.FinishJob(true)
        end
        return
    end
    if not ok then mod:Print(L.BUY_FAILED) end
    R.FinishJob(ok)
end

function R.OnError()
    if R.job then
        local job = R.job
        R.FinishJob(job.items and job.done > 0)
        mod:Print(L.BUY_FAILED)
        R.Refresh()
    end
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
function R.Refresh()
    if not R.list then return end
    R.list:SetData(R.Rows())
    if R.selected then
        local d = R.entries[R.selected.key]
        if not d then d = R.gone[R.selected.key]; R.focus = nil end   -- weggefallen: grau mit Grund (ab 0.20)
        R.selected = d
        if d then R.list:Select(d) end
    end
    R.UpdateView()
end

-- Was der naechste Klick kostet: Massenware qty Stueck, Einzelgegenstand eine Auktion
function R.OfferCost(d, qty)
    if d.commodity then return (ns.Data.CostOf(d.rows or {}, qty or 1)) end
    return d.price or d.offer or 0
end

-- Zweite Zeile beim Radar-Scan: was mit den Abfragen passiert
function R.DiagText()
    local s = R.stats
    local avg = s.answered > 0 and s.ansTime / s.answered or 0
    return L.RADAR_DIAG:format(s.gameSent or 0, s.answered + (s.cached or 0), s.timeouts, math.floor((s.waitReady or 0) + 0.5), s.skipped or 0, avg)
end

local function SignedMoney(v)
    if not v then return "" end
    if v < 0 then return RED .. "−" .. Money(-v) .. "|r" end
    return GREEN .. "+" .. Money(v) .. "|r"
end

-- Text eines Kaufknopfs, solange ein Kauf laeuft (Bestaetigen / Weiter)
local function JobButtonText(job)
    if job.stage == "confirm" then return L.RADAR_CONFIRM_SHORT end
    if job.stage == "next" then return L.RADAR_BTN_NEXT:format(#job.queue - job.idx) end
    return L.RADAR_BUYING
end

function R.UpdateView()
    if not R.list then return end
    local job = R.job
    -- Stand (unten)
    local st
    if ns.Scan.state then
        st = ORANGE .. L.RADAR_FULLSCAN .. "|r"
    elseif R.loop and not R.running then
        local n = 0
        for _, d in pairs(R.entries) do if not d.live and (d.tries or 0) < 2 then n = n + 1 end end
        st = n > 0 and (GREEN .. L.RADAR_QUICK:format(n) .. "|r") or (GREEN .. L.RADAR_FOCUS .. "|r")
    elseif R.running and (R.focus or R.goneSel) then
        st = ORANGE .. L.RADAR_PAUSED .. "|r"
    elseif R.running then
        local mins = math.max(1 / 60, (Now() - R.stats.t0) / 60)
        st = GREEN .. L.RADAR_RUNNING:format(math.floor(R.stats.sent / mins + 0.5), R.stats.sent) .. "|r"
    else
        local market = ns.Data.Market()
        if not market or not market.lastScan then st = ORANGE .. L.MM_NO_SCAN .. "|r"
        else st = GREY .. L.BUY_DEALS_AGE:format(ns.Scan.Age(market.lastScan)) .. "|r" end
    end
    if not AHOpen() then st = st .. "  " .. ORANGE .. L.AUC_NEED_AH .. "|r" end
    R.status:SetText(st)
    R.nowText:SetText((R.loop or R.running) and R.CurrentText():gsub("^\n", "") or "")
    R.scanButton:SetText(R.running and L.RADAR_STOP or L.RADAR_START)
    if AHOpen() and not ns.Scan.state then R.scanButton:Enable() else R.scanButton:Disable() end
    if R.muteCheck then R.muteCheck:SetChecked(mod.db.radarMute and true or false) end
    if R.orderBox and R.orderBox.Refresh then R.orderBox.Refresh() end
    if R.kindBox and R.kindBox.Refresh then R.kindBox.Refresh() end
    R.hiddenButton:SetText(L.RADAR_HIDDEN_BTN:format(R.HiddenCount()))
    if #R.list:GetItems() > 0 then R.hideAllButton:Enable() else R.hideAllButton:Disable() end
    for _, box in ipairs(R.moneyBoxes or {}) do if not (box.HasFocus and box:HasFocus()) then box.Reset() end end
    local budget = R.Budget()
    -- Schnellkauf: bestes Haendler-Schnaeppchen, alles was ich mir leisten kann (ab 0.19)
    local top = (job and job.mode == "best" and R.entries[job.key]) or R.Top("vendor")
    R.quickTarget = top
    if top then
        local jobHere = job and job.mode == "best" and job.key == top.key
        local preReady = not job and R.pre and R.pre.stage == "ready" and R.pre.key == top.key
        R.quickButton:SetText(jobHere and JobButtonText(job) or (preReady and L.RADAR_QUICK_NOW) or L.RADAR_QUICK_BTN)
        local q = top.best and top.best.qty or 0
        R.quickInfo:SetText(W.Colored(top.name, top.quality) .. GREY .. " ×" .. q .. "  " .. Money(top.best and top.best.cost or 0) .. "|r  "
            .. SignedMoney(top.best and top.best.gain))
        if AHOpen() and (not job or (jobHere and job.stage ~= "wait" and job.stage ~= "quote")) then R.quickButton:Enable() else R.quickButton:Disable() end
    else
        R.quickButton:SetText(L.RADAR_QUICK_BTN)
        R.quickInfo:SetText(GREY .. L.RADAR_QUICK_NONE .. "|r")
        R.quickButton:Disable()
    end
    R.Prequote()
    -- Kaufzeile (unter der Liste): gewaehlter Treffer, 1 Stueck / ab Gewinn bzw. bis ein Stapel / alle, je Kosten und Gewinn
    local d = R.selected
    if d and d.gone then
        R.selText:SetText(GREY .. d.name .. "|r\n" .. ORANGE .. tostring(d.goneWhy) .. "|r")
    elseif d then
        local minQ = R.MinProfitQty(d)
        local hint
        if not minQ then hint = RED .. L.RADAR_NO_PROFIT .. "|r"
        elseif minQ > 1 then hint = ORANGE .. L.RADAR_MIN_QTY:format(minQ) .. "|r"
        else hint = "" end
        R.selText:SetText(W.Colored(d.name, d.quality) .. "\n" .. GREY .. L.RADAR_SEL_QTY:format(d.qty or 0) .. "|r  " .. hint)
    else
        R.selText:SetText(GREY .. L.RADAR_PICK .. "|r")
    end
    for _, mode in ipairs({ "one", "stack", "all" }) do
        local b, info = R.modeButtons[mode], R.modeInfo[mode]
        local qty = R.ModeQty(d, mode)
        local show = d and qty >= 1 and (mode == "one" or (qty > 1 and (mode == "all" or qty < (d.qty or 0))))
        if show then
            local profit, cost, got = ns.Data.ProfitOf(d, qty)
            local jobHere = job and job.key == d.key and job.mode == mode
            if jobHere then
                b:SetText(JobButtonText(job))
                info:SetText(job.stage == "confirm" and Money(job.total or 0) or (job.items and (Money(job.cost or 0) .. "\n" .. GREY .. job.done .. "/" .. job.qty .. "|r") or ""))
            else
                b:SetText(mode == "one" and L.RADAR_BTN_ONE or (mode == "stack" and L.RADAR_BTN_N:format(got) or L.RADAR_BTN_ALL:format(got)))
                info:SetText(Money(cost or 0) .. "\n" .. SignedMoney(profit))
            end
            local affordable = not budget or (cost or 0) <= budget
            local ready = jobHere and (job.stage == "confirm" or job.stage == "next")
            local ok = AHOpen() and (affordable or jobHere) and (not job or ready)
            if ok then b:Enable() else b:Disable() end
            if not affordable and not jobHere then info:SetText(GREY .. Money(cost or 0) .. "|r\n" .. GREY .. L.RADAR_TT_CANT .. "|r") end
            b:Show(); info:Show()
        else
            b:Hide(); info:Hide()
        end
    end
end

-- Zweite Zeile: welcher Gegenstand gerade abgefragt wird
function R.CurrentText()
    local key = R.pending and R.pending.key or R.lastKey
    if key == nil then return "" end
    local D = ns.Data
    local e = D.Lookup(key)
    local name = D.ItemName(key, e) or tostring(key)
    local icon = ns.Buy.Icon(D.ItemID(key)) or "Interface\\Icons\\INV_Misc_QuestionMark"
    return "\n" .. GREY .. L.RADAR_NOW .. "|r |T" .. tostring(icon) .. ":14:14:0:0|t " .. W.Colored(name, type(e) == "table" and e.ql or nil)
end

-- kurze Altersangabe fuer die Spalte "Gesehen": "12 s", "40 Min.", "3 Std.", "2 T."
function R.ShortAge(sec)
    if type(sec) ~= "number" then return L.RADAR_SCAN end
    sec = math.max(0, math.floor(sec))
    if sec < 60 then return L.RADAR_AGO:format(sec) end
    if sec < 3600 then return L.RADAR_AGO_MIN:format(math.floor(sec / 60)) end
    if sec < 48 * 3600 then return L.RADAR_AGO_H:format(math.floor(sec / 3600)) end
    return L.RADAR_AGO_D:format(math.floor(sec / 86400))
end

-- Auswahllisten im Reiter (wie Peons page:Dropdown: neue Menue-API, sonst UIDropDownMenu, sonst Umschaltknopf)
function R.OrderText(v)
    return L["RADAR_ORDER_" .. string.upper(v or "smart")] or tostring(v)
end

R.KINDS = { "both", "vendor", "market" }
function R.KindText(v)
    return L["RADAR_SHOW_" .. string.upper(v or "both")] or tostring(v)
end

function R.Dropdown(parent, width, values, get, set, textOf)
    local ok, dd = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    if ok and dd and dd.SetupMenu then
        dd:SetSize(width, 22)
        dd:SetupMenu(function(_, root)
            for _, v in ipairs(values) do
                root:CreateRadio(textOf(v), function() return get() == v end, function() mod:Call("Radar", set, v) end)
            end
        end)
        dd.Refresh = function() if dd.GenerateMenu then dd:GenerateMenu() end end
        return dd
    end
    ok, dd = pcall(CreateFrame, "Frame", nil, parent, "UIDropDownMenuTemplate")
    if ok and dd and UIDropDownMenu_Initialize then
        UIDropDownMenu_SetWidth(dd, width - 30)
        UIDropDownMenu_Initialize(dd, function()
            for _, v in ipairs(values) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = textOf(v)
                info.checked = get() == v
                info.func = function() mod:Call("Radar", set, v) end
                UIDropDownMenu_AddButton(info)
            end
        end)
        dd.Refresh = function() UIDropDownMenu_SetText(dd, textOf(get())) end
        return dd
    end
    -- Rueckfall: Knopf schaltet weiter
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetScript("OnClick", function()
        local cur = get()
        for i, v in ipairs(values) do
            if v == cur then mod:Call("Radar", set, values[i % #values + 1]); break end
        end
    end)
    b.Refresh = function() b:SetText(textOf(get())) end
    return b
end

function R.OrderDropdown(parent)
    return R.Dropdown(parent, 140, R.ORDERS, function() return mod.db.radarOrder or "smart" end, R.SetOrder, R.OrderText)
end

function R.KindDropdown(parent)
    return R.Dropdown(parent, 120, R.KINDS, function() return mod.db.radarKind or "both" end, R.SetKind, R.KindText)
end

-- Tooltip einer Zeile: Gegenstand plus Datenlage und Rechnung
-- Namen nachladen (ab 0.57): Das Spiel kennt Namen erst, wenn der Gegenstand einmal geladen wurde.
function R.RequestName(id)
    if not id or not (C_Item and C_Item.RequestLoadItemDataByID) then return end
    R.nameWait = R.nameWait or {}
    if R.nameWait[id] then return end
    R.nameWait[id] = true
    pcall(C_Item.RequestLoadItemDataByID, id)
end

function R.OnItemInfo(id)
    if not R.nameWait or not R.nameWait[id] then return end
    R.nameWait[id] = nil
    local D, changed = ns.Data, false
    for _, tbl in ipairs({ R.entries, R.gone }) do
        for key, d in pairs(tbl or {}) do
            if d.noName and D.ItemID(key) == id then
                local name = D.ItemName(key, D.Lookup(key))
                if name then
                    d.name, d.noName = name, nil
                    if not d.quality and C_Item and C_Item.GetItemQualityByID then
                        local ok, q = pcall(C_Item.GetItemQualityByID, id)
                        if ok and type(q) == "number" then d.quality = q end
                    end
                    d.icon = d.icon or ns.Buy.Icon(id)
                    changed = true
                end
            end
        end
    end
    if changed and R.list and not R.nameRefresh then
        -- mehrere Namen kommen meist kurz nacheinander: einmal gesammelt auffrischen
        R.nameRefresh = true
        local function Go() R.nameRefresh = nil; if R.list then R.list:Refresh() end end
        if C_Timer and C_Timer.After then C_Timer.After(0.2, Go) else Go() end
    end
end

-- Tooltip einer Zeile (ab 0.57): Blizzards normaler Tooltip mit Brokers Zeilen (Umschalt fuer mehr), darunter die
-- Angaben des Radars. Die Radar-Zeilen haengt Tooltip.lua bei jedem Neuaufbau unten an (T.SetExtra), auch nach Umschalt.
function R.RowTooltip(row, r)
    local T = ns.Tooltip
    local extra = { done = false }
    if T and T.SetExtra then
        extra = T.SetExtra(row, function(tt) R.TipLines(tt, r) end)
    end
    W.ShowItemTooltip(row, r.key)
    if not GameTooltip then return end
    -- ohne Neuaufbau durch das Spiel (aeltere Fassung, Test): Zeilen direkt anhaengen
    if not extra.done then
        GameTooltip:AddLine(" ")
        R.TipLines(GameTooltip, r)
        GameTooltip:Show()
    end
end

function R.TipLines(GameTooltip, r)
    if r.kind == "market" then
        GameTooltip:AddLine(L.RADAR_TT_DATA:format(r.scans or 0, tonumber(mod.db.dealDays) or 7), 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L.RADAR_TT_RESALE2:format(Money(r.ref or 0)), 0.7, 0.7, 0.7)
        -- Absatz (ab 0.26): Menge hoechstens Absatz je Std. x dealHold
        if r.sales and r.salesCap then
            GameTooltip:AddLine(L.RADAR_TT_SALES:format(ns.Sales.PerHourText(r.sales), r.salesCap, tonumber(mod.db.dealHold) or 48), 0.7, 0.7, 0.7)
        elseif r.salesUnknown then
            GameTooltip:AddLine(L.RADAR_TT_NOSALES, 1, 0.6, 0.2)
        end
    else
        GameTooltip:AddLine(L.RADAR_TT_VENDOR:format(Money(r.ref or 0)), 0.7, 0.7, 0.7)
    end
    if r.best and r.best.qty > 0 and r.best.qty < (r.qty or 0) then
        GameTooltip:AddLine(L.RADAR_TT_MINE:format(r.best.qty, Money(r.best.cost or 0), Money(r.best.gain or 0)), 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine(L.RADAR_TT_TOTAL:format(r.qty or 0, Money(r.cost or 0), Money(r.gain or 0)), 0.7, 0.7, 0.7)
    if r.cant then GameTooltip:AddLine(L.RADAR_TT_CANT2, 1, 0.5, 0.2) end
    if r.gone then GameTooltip:AddLine(L.RADAR_TT_GONE:format(tostring(r.goneWhy)), 1, 0.6, 0.2, true) end
end

-- Zeilenfarbe (Peon API 8): neue Treffer pulsieren gruen, Haendler-Schnaeppchen dezent gold
function R.RowColor(r)
    if r.gone then return 0.5, 0.5, 0.5, 0.15 end
    local now = Now()
    if r.flashUntil and now < r.flashUntil then
        return 0.3, 0.9, 0.3, 0.2 + 0.3 * (0.5 + 0.5 * math.sin(now * math.pi * 3))
    end
    if r.kind == "vendor" then return 1, 0.82, 0, 0.10 end
    return nil
end

local function Hint(frame, text)
    frame:SetScript("OnEnter", function(self)
        if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(text, 1, 1, 1, 1, true); GameTooltip:Show() end
    end)
    frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function R.Build(c)
    -- ab 0.56: Aufbau wie Blizzards Auktionshaus (Look.lua): oben Scan-Knopf und Stand, links alle Einstellungen,
    -- rechts die Treffer und darunter die Kaufzeile
    local U = ns.Look
    local bar, left, right = U.Layout(c)
    local inset = right
    local function Dim(r, text) if r.cant or r.gone then return GREY .. text .. "|r" end return text end
    R.list = Peon.NewList(right, {
        columns = {
            { key = "name", title = L.COL_ITEM, width = 200,
              format = function(v, r)
                  local isNew = r.newUntil and Now() < r.newUntil
                  local mark = isNew and ("|T" .. R.DOT .. ":10:10:0:0|t ") or ""
                  local name = (r.cant or r.gone) and (GREY .. v .. "|r") or W.Colored(v, r.quality)
                  return mark .. "|T" .. tostring(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":16:16:0:0|t " .. name
              end,
              sortValue = function(r) return W.Lower(r.name) end },
            { key = "kind", title = L.BUY_COL_KIND, width = 34,
              format = function(v) return v == "vendor" and (GOLD .. L.RADAR_KIND_SHORT_VENDOR .. "|r") or L.RADAR_KIND_SHORT_MARKET end },
            { key = "offer", title = L.BUY_COL_OFFER, width = 74, align = "RIGHT", format = function(v, r) return Dim(r, Money(v)) end },
            { key = "ref", title = L.RADAR_COL_RESALE, width = 74, align = "RIGHT", format = function(v, r) return Dim(r, Money(v)) end },
            { key = "qty", title = L.AUC_COL_QTY, width = 56, align = "RIGHT",
              format = function(v, r)
                  local mine = r.best and r.best.qty
                  if mine and mine > 0 and mine < (v or 0) then return Dim(r, mine .. GREY .. "/" .. v .. "|r") end
                  return Dim(r, tostring(v or 0))
              end },
            { key = "showGain", title = L.RADAR_COL_GAIN, width = 84, align = "RIGHT",
              format = function(v, r)
                  if r.gone then return ORANGE .. L.RADAR_GONE_SHORT .. "|r" end
                  if r.cant then return GREY .. Money(math.floor((v or 0) + 0.5)) .. "|r" end
                  return (r.kind == "vendor" and GOLD or GREEN) .. Money(math.floor((v or 0) + 0.5)) .. "|r"
              end,
              sortValue = function(r) return r.showGain or 0 end },
            { key = "checked", title = L.RADAR_COL_SEEN, width = 52, align = "RIGHT",
              format = function(v, r)
                  if not v then return GREY .. R.ShortAge(r.seenT and (time() - r.seenT)) .. "|r" end
                  return R.ShortAge(Now() - v)
              end,
              sortValue = function(r) return r.checked and -r.checked or 0 end },
        },
        rows = 14, rowHeight = 20, sortKey = "showGain", sortDesc = true, style = "ah", flex = "name",
        rowColor = R.RowColor,
        onClick = function(list, r, button)
            if button == "RightButton" then
                if r.gone then R.gone[r.key] = nil; R.Refresh(); return end   -- weggefallen: nur aus der Liste nehmen
                mod:Call("Radar", R.Hide, r.key); return
            end
            -- gewaehlte Zeile nochmal anklicken: Auswahl aufheben, Radar-Scan laeuft weiter (ab 0.20)
            if R.selected and R.selected.key == r.key then mod:Call("Radar", R.SelectRow, nil); R.list:Select(nil); return end
            mod:Call("Radar", R.SelectRow, r)
        end,
        onEnter = function(list, r, row) R.RowTooltip(row, r) end,
        onLeave = function()
            if ns.Tooltip.SetExtra then ns.Tooltip.SetExtra(nil) end
            if GameTooltip then GameTooltip:Hide() end
        end,
        emptyText = L.BUY_NO_DEALS,
    })
    local BUY_H = 62   -- Kaufzeile unter der Liste
    U.Fit(R.list, right, { 4, 4, 4, BUY_H })

    -- Obere Leiste: Stand links neben dem Scan-Knopf (wie Blizzards Suchleiste mit "Suchen")
    R.scanButton = U.Button(bar, L.RADAR_START, 160, function() if R.running then R.Stop() else mod:Call("Radar", R.Start) end end)
    R.scanButton:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    R.status = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    -- ab 0.59 (Neuaufbau N1): Sprung in Blizzards Kaufansicht mit dem gewaehlten Treffer
    R.goMarketButton = U.Button(bar, L.GO_MARKET, 130, function()
        if R.selected then mod:Call("Sprung", ns.Go.Market, R.selected) else mod:Print(L.GO_NONE) end
    end)
    R.goMarketButton:SetPoint("RIGHT", R.scanButton, "LEFT", -6, 0)
    R.status:SetPoint("RIGHT", R.goMarketButton, "LEFT", -12, 0)
    R.status:SetPoint("LEFT", bar, "LEFT", U.LEFT_W + 8, 0)
    R.status:SetJustifyH("RIGHT")
    if R.status.SetWordWrap then R.status:SetWordWrap(false) end

    -- Kaufzeile: Auswahl links, Knoepfe 1 Stueck / ab Gewinn bzw. Stapel / alle mit Kosten und Gewinn
    R.selText = U.Note(right)
    R.selText:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 10, 12)
    R.selText:SetPoint("RIGHT", right, "RIGHT", -(3 * 112 + 16), 0)
    if R.selText.SetSpacing then R.selText:SetSpacing(3) end
    R.modeButtons, R.modeInfo = {}, {}
    for i, mode in ipairs({ "one", "stack", "all" }) do
        local b = U.Button(right, "", 106, function() mod:Call("Radar", R.BuyStep, R.selected, mode) end)
        b:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -8 - (3 - i) * 112, 32)
        local info = right:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        info:SetPoint("TOP", b, "BOTTOM", 0, -2)
        info:SetWidth(106)
        info:SetJustifyH("CENTER")
        R.modeButtons[mode], R.modeInfo[mode] = b, info
    end
    R.buyButton, R.buyStackButton, R.buyAllButton = R.modeButtons.one, R.modeButtons.stack, R.modeButtons.all

    -- Linke Spalte: Einstellungen von oben nach unten
    local x, w = 12, U.LEFT_W - 24
    local lKind = U.Label(left, L.RADAR_LBL_SHOW)
    lKind:SetPoint("TOPLEFT", x, -12)
    R.kindBox = R.KindDropdown(left)
    R.kindBox:SetPoint("TOPLEFT", lKind, "BOTTOMLEFT", 0, -6)
    local lOrder = U.Label(left, L.RADAR_LBL_ORDER)
    lOrder:SetPoint("TOPLEFT", R.kindBox, "BOTTOMLEFT", 0, -12)
    R.orderBox = R.OrderDropdown(left)
    R.orderBox:SetPoint("TOPLEFT", lOrder, "BOTTOMLEFT", 0, -6)
    -- Mindestgewinn je Art (Geldbetrag: "50s", "1g 20s", "10c"; Zahl ohne Einheit = Silber)
    local lMin = U.Label(left, L.RADAR_MIN_GAIN)
    lMin:SetPoint("TOPLEFT", R.orderBox, "BOTTOMLEFT", 0, -14)
    local lH = left:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lH:SetText(GOLD .. L.RADAR_KIND_VENDOR_LONG .. "|r")
    lH:SetPoint("TOPLEFT", lMin, "BOTTOMLEFT", 0, -10)
    R.minVendorBox = ns.MoneyBox(left, 70, function() return R.MinGain("vendor") end,
        function(v) mod.db.dealMinVendor = math.max(0, math.floor(v)); R.Refresh() end, 100)
    R.minVendorBox:SetPoint("RIGHT", left, "TOPRIGHT", -14, 0)
    R.minVendorBox:SetPoint("TOP", lH, "TOP", 0, 4)
    local lAH = left:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lAH:SetText(L.RADAR_KIND_MARKET_LONG)
    lAH:SetPoint("TOPLEFT", lH, "BOTTOMLEFT", 0, -14)
    R.minMarketBox = ns.MoneyBox(left, 70, function() return R.MinGain("market") end,
        function(v) mod.db.dealMinMarket = math.max(0, math.floor(v / 100)); R.Refresh() end, 100)
    R.minMarketBox:SetPoint("RIGHT", left, "TOPRIGHT", -14, 0)
    R.minMarketBox:SetPoint("TOP", lAH, "TOP", 0, 4)
    R.moneyBoxes = { R.minVendorBox, R.minMarketBox }
    Hint(R.minVendorBox, L.RADAR_MIN_GAIN_HINT)
    Hint(R.minMarketBox, L.RADAR_MIN_GAIN_HINT)
    R.muteCheck = CreateFrame("CheckButton", nil, left, "UICheckButtonTemplate")
    R.muteCheck:SetSize(24, 24)
    R.muteCheck:SetPoint("TOPLEFT", lAH, "BOTTOMLEFT", -4, -12)
    R.muteCheck:SetScript("OnClick", function(self) mod:Call("Radar", R.SetMute, self:GetChecked()) end)
    Hint(R.muteCheck, L.RADAR_MUTE_HINT)
    R.muteLabel = left:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    R.muteLabel:SetText(L.RADAR_MUTE)
    R.muteLabel:SetPoint("LEFT", R.muteCheck, "RIGHT", 2, 0)
    -- Ausblenden
    local lHide = U.Label(left, L.RADAR_LBL_HIDE)
    lHide:SetPoint("TOPLEFT", R.muteCheck, "BOTTOMLEFT", 4, -12)
    R.hideAllButton = U.Button(left, L.RADAR_HIDE_ALL, w, function() mod:Call("Radar", R.HideAll) end)
    R.hideAllButton:SetPoint("TOPLEFT", lHide, "BOTTOMLEFT", 0, -6)
    Hint(R.hideAllButton, L.RADAR_HIDE_ALL_HINT)
    R.hiddenButton = U.Button(left, "", w, function() mod:Call("Radar", R.ToggleHiddenPanel) end)
    R.hiddenButton:SetPoint("TOPLEFT", R.hideAllButton, "BOTTOMLEFT", 0, -4)
    Hint(R.hiddenButton, L.RADAR_HIDDEN_HINT)
    -- unten: Schnellkauf beim Haendler und was gerade geprueft wird
    R.nowText = U.Note(left, w)
    R.nowText:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", x, 12)
    if R.nowText.SetWordWrap then R.nowText:SetWordWrap(false) end
    R.quickInfo = U.Note(left, w)
    R.quickInfo:SetPoint("BOTTOMLEFT", R.nowText, "TOPLEFT", 0, 10)
    R.quickButton = U.Button(left, L.RADAR_QUICK_BTN, w, function() mod:Call("Radar", R.BuyStep, R.quickTarget, "best") end)
    R.quickButton:SetPoint("BOTTOMLEFT", R.quickInfo, "TOPLEFT", 0, 6)
    Hint(R.quickButton, L.RADAR_QUICK_HINT)
    local lQuick = U.Label(left, L.RADAR_LBL_QUICK)
    lQuick:SetPoint("BOTTOMLEFT", R.quickButton, "TOPLEFT", 0, 6)
    R.inset = right
    -- Anzeige der Zeiten jede Sekunde auffrischen, pulsierende Zeilen jedes Bild
    local acc = 0
    c:SetScript("OnUpdate", function(_, dt)
        acc = acc + (dt or 0)
        if acc >= 1 then
            acc = 0
            if R.list then
                local now, expired = Now(), false
                for _, g in pairs(R.gone) do if now > (g.goneUntil or 0) then expired = true end end
                if expired then R.Refresh() else R.list:Update(); R.UpdateView() end
            end
            return
        end
        if R.list then
            local now = Now()
            for _, r in ipairs(R.list:GetItems()) do
                if r.flashUntil and now < r.flashUntil + 0.2 then R.list:UpdateColors(); break end
            end
        end
    end)
end

-- Liste der ausgeblendeten Gegenstaende (Knopf "Ausgeblendet (n)"): Klick = wieder zeigen
function R.ToggleHiddenPanel()
    local p = R.hiddenPanel
    if not p then
        p = CreateFrame("Frame", nil, R.inset, BackdropTemplateMixin and "BackdropTemplate" or nil)
        p:SetSize(320, 270)
        p:SetPoint("BOTTOMLEFT", R.hiddenButton, "BOTTOMRIGHT", 12, 0)
        p:SetFrameStrata("DIALOG")
        if p.SetBackdrop then
            p:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        end
        local title = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOPLEFT", 10, -10)
        title:SetText(L.RADAR_HIDDEN_TITLE)
        p.list = Peon.NewList(p, {
            columns = {
                { key = "name", title = L.COL_ITEM, width = 200, format = function(v, it) return W.Colored(v, it.q) end },
                { key = "t", title = L.RADAR_HIDDEN_SINCE, width = 80, align = "RIGHT", format = function(v) return ns.Scan.Age(v) end },
            },
            rows = 8, sortKey = "t", sortDesc = true,
            onClick = function(list, it) mod:Call("Radar", R.ShowAgain, it.key) end,
            emptyText = L.RADAR_HIDDEN_EMPTY,
        })
        p.list.frame:SetPoint("TOPLEFT", 8, -30)
        local close = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        close:SetSize(90, 22)
        close:SetPoint("BOTTOMRIGHT", -8, 8)
        close:SetText(L.CLOSE or "OK")
        close:SetScript("OnClick", function() p:Hide() end)
        local all = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        all:SetSize(130, 22)
        all:SetPoint("RIGHT", close, "LEFT", -6, 0)
        all:SetText(L.RADAR_SHOW_ALL)
        all:SetScript("OnClick", function() mod:Call("Radar", R.ShowAllHidden) end)
        local hint = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        hint:SetPoint("BOTTOMLEFT", 10, 36)
        hint:SetText(GREY .. L.RADAR_HIDDEN_CLICK .. "|r")
        R.hiddenPanel = p
        p:Hide()
    end
    if p:IsShown() then p:Hide(); return end
    R.FillHiddenPanel()
    p:Show()
end

function R.FillHiddenPanel()
    local p = R.hiddenPanel
    if not p then return end
    local items = {}
    for key, h in pairs(R.HiddenList(false) or {}) do
        items[#items + 1] = { key = key, name = h.name or tostring(key), q = h.q, t = h.t }
    end
    p.list:SetData(items)
end

function R.ShowAgain(key)
    R.Unhide(key)
    R.FillHiddenPanel()
    R.LoadFromScan()
    R.Wake()
    R.Refresh()
end

-- Reiter geoeffnet: Treffer aus dem Scan laden und gleich einmal live pruefen
-- Ab 0.56: Treffer nur neu aus der Datenbank laden, wenn es einen neuen Scan gibt (oder Markt bzw. Altersgrenze
-- gewechselt haben). Das Laden geht alle Gegenstaende des Marktes durch und liess den Wechsel auf den Reiter haengen.
-- Bis 0.56 zusaetzlich alle 2 Minuten, ab 0.57 nur noch nach einem Scan (KarloDerBaer). Live gepruefte Treffer
-- aktualisiert der Radar-Scan ohnehin selbst.
function R.LoadIfStale()
    local market = ns.Data.Market()
    local l = R.loaded
    if l and l.market == market and l.scan == (market and market.lastScan) and l.age == R.MaxAge() then return false end
    R.LoadFromScan()
    return true
end

function R.Open()
    R.LoadIfStale()
    if R.selected and R.entries[R.selected.key] then R.focus = { key = R.selected.key, at = 0, show = true } end
    R.Wake()
    R.Refresh()
end

function R.Init()
    R.MuteOff()   -- nach Absturz/Reload waehrend des Radar-Scans: Tonkanaele zurueck
    mod:RegisterEvent("PLAYER_LOGOUT", function() R.MuteOff() end)
    pcall(mod.RegisterEvent, mod, "GET_ITEM_INFO_RECEIVED", function(_, id) mod:Call("Radar", R.OnItemInfo, id) end)   -- ab 0.57
    mod:RegisterEvent("PLAYER_MONEY", function() if R.list and R.Shown() then R.Refresh() end end)
    mod:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, itemID) OnResults(true, itemID) end)
    mod:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey) OnResults(false, itemKey) end)
    -- weitere Teile der Ergebnisse (ab 0.20.1)
    pcall(mod.RegisterEvent, mod, "COMMODITY_SEARCH_RESULTS_ADDED", function(_, itemID) OnResults(true, itemID) end)
    pcall(mod.RegisterEvent, mod, "ITEM_SEARCH_RESULTS_ADDED", function(_, itemKey) OnResults(false, itemKey) end)
    mod:RegisterEvent("COMMODITY_PRICE_UPDATED", function(_, unit, total) R.OnPriceUpdated(unit, total) end)
    mod:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED", function() R.OnBought(true) end)
    mod:RegisterEvent("COMMODITY_PURCHASE_FAILED", function() R.OnBought(false) end)
    mod:RegisterEvent("AUCTION_HOUSE_PURCHASE_COMPLETED", function(_, auctionID) R.OnBought(true, auctionID) end)
    mod:RegisterEvent("AUCTION_HOUSE_SHOW_ERROR", function() R.stats.errors = R.stats.errors + 1; R.OnError() end)
    -- Bremse des Spiels (aus dem modernen Auktionshaus; in Forever unbekannt, deshalb geschuetzt)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED", function()
        R.stats.dropped = R.stats.dropped + 1
        if R.pending then R.pending = nil end
    end)
    -- Fehlersuche: welche Ereignisse kamen waehrend einer Abfrage (landet bei "ohne Antwort" in radarStats.timeoutLog)
    local short = { AUCTION_HOUSE_THROTTLED_MESSAGE_SENT = "S", AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED = "R",
        AUCTION_HOUSE_THROTTLED_SYSTEM_READY = "B", AUCTION_HOUSE_NEW_RESULTS_RECEIVED = "N",
        COMMODITY_SEARCH_RESULTS_UPDATED = "C", ITEM_SEARCH_RESULTS_UPDATED = "I",
        COMMODITY_SEARCH_RESULTS_ADDED = "CA", ITEM_SEARCH_RESULTS_ADDED = "IA" }
    for ev, tag in pairs(short) do
        pcall(mod.RegisterEvent, mod, ev, function(_, arg)
            local p = R.pending
            if not p or #p.ev >= 12 then return end
            local id = type(arg) == "table" and arg.itemID or arg
            p.ev[#p.ev + 1] = id ~= nil and (tag .. ":" .. tostring(id)) or tag
            -- neues Ergebnis fuer genau diesen Gegenstand, aber kein ..._RESULTS_UPDATED: nachsehen
            if tag == "N" and id == p.itemID and C_Timer then
                C_Timer.After(0.2, function() if R.pending == p and not p.forBuy and R.FromCache(p) then
                    R.pending = nil; R.stats.cached = (R.stats.cached or 0) + 1 end end)
            end
        end)
    end
    mod:RegisterEvent("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT", function()
        if R.pending then
            R.stats.gameSent = (R.stats.gameSent or 0) + 1
            if R.lastLog then R.lastLog.sent = true end
        end
    end)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED", function() R.stats.queued = R.stats.queued + 1 end)
    mod:RegisterEvent("AUCTION_HOUSE_CLOSED", function() R.Halt(); R.job = nil end)
    mod:On("SCAN_DONE", function()
        R.CheckHidden()
        if R.Shown() then R.Open() end
    end)
end

---------------------------------------------------------------------------
-- Ab 0.48 (Umbau U7): Das Radar kann im Broker-Fenster oder im eigenen Reiter des Auktionshauses stehen
-- (AHTabs.lua haengt die Flaeche um). R.Shown() = Radar ist gerade zu sehen.
---------------------------------------------------------------------------
function R.Shown()
    local T = ns.AHTabs
    if T and T.current == "radar" then return true end
    if T and T.host and T.host.radar == "ah" then return false end
    return W.IsOpen() and W.current == "radar"
end

-- Treffer, die das Radar gerade zeigen wuerde (fuer die Zahl am Reiter)
function R.CountHits()
    local n, budget = 0, R.Budget()
    for _, d in pairs(R.entries) do
        if R.Visible(d, budget) then n = n + 1 end
    end
    return n
end

-- Tastenbelegungen (Bindings.xml): gewaehlten Treffer kaufen, naechsten Treffer waehlen
function R.SelectNext()
    if not R.list then return false end
    local rows = R.list:GetItems()
    local start = 0
    for i, r in ipairs(rows) do if R.selected and r.key == R.selected.key then start = i end end
    for k = 1, #rows do
        local r = rows[((start + k - 1) % #rows) + 1]
        if r and not r.gone then
            R.list:Select(r)
            R.SelectRow(r)
            return true
        end
    end
    return false
end

function PeonBroker_RadarBuy()
    if not R.Shown() or not R.selected then return end
    mod:Call("Radar", R.BuyStep, R.selected, "stack")
end

function PeonBroker_RadarNext()
    if not R.Shown() then return end
    mod:Call("Radar", R.SelectNext)
end

W.pages.radar = {
    build = R.Build,
    refresh = function() R.Open() end,
    leave = function() R.Halt() end,
    -- Reiter gewaehlt (ab 0.20): ohne gewaehlten Treffer Blizzards Kaufen-Seite (mit Treffer zeigt R.Open ihn)
    enter = function()
        if not (R.selected and R.entries[R.selected.key]) then W.SetAHMode("Buy") end
    end,
}
