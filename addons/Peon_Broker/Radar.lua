-- Peon_Broker - Radar.lua
-- Neuaufbau N6 (ab 0.64, Konzept Peon_Broker_Neuaufbau.md, Abschnitte 4.4 und 6.1): Radar in der Grundform.
--   Seite Radar: schlanke Liste der Chancen (Gegenstand, Gewinn, Art, Risiko, Stand). Ein Klick oeffnet die Chance
--     auf der Seite Fokus (Focus.lua), dort stehen alle Angaben und der Kaufknopf.
--   Arten: "Haendler" (Angebote unter dem Haendlerpreis, sicherer Gewinn) und ab 0.65 (H1) "Aufkauf" (Massenware bis
--     zu einer Preisstufe kaufen, zum Preis der naechsten Stufe einstellen, Buyout.lua).
--   Chancen kommen aus der Datenbank (Komplettscan, Stand vom Manager, gespeicherte Live-Ergebnisse). Von selbst
--     wird nichts live nachgeprueft, jede Zeile zeigt das Alter ihres Stands.
--   Radar-Scan (Knopf, nur solange die Seite Radar offen ist): prueft reihum die gezeigten Chancen live.
--     Was weg ist, wird grau mit Grund und verschwindet nach R.GONE_TIME Sekunden.
--   Fokus: genau ein Gegenstand wird regelmaessig neu abgefragt (R.SetFocus), solange die Seite Fokus offen ist.
--   Kaufen (R.BuyStep): Massenware erst Preis vom Spiel, dann bestaetigen. Einzelgegenstaende je Klick eine Auktion.
-- Der Kern (Treffer rechnen, Abfragen, Kaufen) stammt aus dem Radar 0.14 bis 0.57.

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
-- ab 0.66 (H2): Abstand der Abfragen im Fokus aus der Einstellung focusEvery (Vorgabe 5, 3 bis 30 Sekunden)
function R.FocusEvery() return tonumber(mod.db.focusEvery) or 5 end
R.PRICE_TOL = 0.01   -- ab 0.66: Gesamtpreis des Spiels mehr als 1 % ueber dem erwarteten -> Warnung vor dem zweiten Klick
R.KIND_ON = { vendor = true, buyout = true }   -- Arten im Radar (N6 nur Haendler, ab 0.65 dazu Aufkauf)
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
    -- ab 0.65: aus D.Deal nur noch die Art Haendler (die alte Art "unter dem ueblichen Preis" entfaellt), dazu der
    -- Aufkauf. Je Gegenstand zaehlt die Chance mit dem hoeheren Gewinn.
    local deal = D.Deal(e, rows, hp, R.VendorOnly(), D.Day(), key)
    local bo = ns.Buyout and ns.Buyout.Find(e, rows, key, R.Budget(), commodity) or nil
    if bo and (not deal or bo.gain > deal.gain) then deal = bo end
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

-- Einstellungen fuer D.Deal nur mit der Art Haendler (ab 0.65)
function R.VendorOnly()
    if not R.vendorDb then
        R.vendorDb = setmetatable({ radarKind = "vendor" }, { __index = function(_, k) return mod.db[k] end })
    end
    return R.vendorDb
end

-- Beim Oeffnen: Treffer aus der Datenbank (Scan und gespeicherte Live-Ergebnisse), hoechstens radarMaxAge Min. alt
function R.MaxAge()
    local m = tonumber(mod.db.radarMaxAge) or 60
    if m <= 0 then return nil end
    return m * 60
end

function R.LoadFromScan()
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
                -- Vorauswahl: unter dem Haendlerpreis (genaue Pruefung in D.Deal) oder Massenware mit mehreren
                -- Preisstufen (Aufkauf, ab 0.65)
                if (hp and e.m < hp) or (ns.Buyout and ns.Buyout.Candidate(e, key)) then
                    local d = R.Evaluate(key, D.ParseLevels(e.lv), false, nil)
                    if d and R.KIND_ON[d.kind] then d.checked = nil; d.seenT = seen; R.entries[key] = d end
                end
            end
        end
    end
    -- was vorher in der Liste stand und jetzt fehlt: grau mit Grund (ab 0.20)
    for key, old in pairs(before) do
        if not R.entries[key] then R.MarkGone(old, L.RADAR_GONE_RELOAD) end
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
    if d.kind == "buyout" then
        -- Aufkauf (ab 0.65): ganze Stelle oder nichts, mit neuem Gold neu gerechnet
        local ok = d.gone or ns.Buyout.Refit(d, budget)
        d.best = { gain = d.gain, qty = ok and d.qty or 0, cost = d.cost }
        d.cant = not ok
        d.showGain = d.gain
        return d
    end
    d.best = R.Best(d, budget)
    d.cant = not d.best.gain or d.best.gain <= 0 or d.best.gain < R.MinGain(d.kind)
    d.showGain = d.best.gain or d.gain
    return d
end

-- Sichtbar: Art im Radar und, wenn nicht anders eingestellt, nur was sich mit meinem Gold lohnt
function R.Visible(d, budget)
    if not R.KIND_ON[d.kind] then return false end
    if budget == nil then budget = R.Budget() end
    R.Annotate(d, budget)
    if not mod.db.radarShowExpensive and d.cant then return false end
    return true
end

-- Risiko einer Chance fuer die Ampel in der Liste: "low", "mid", "high" (Grundform, die Regeln fuer den
-- Aufkauf kommen mit H1). Haendler-Chancen sind sicher, solange der Stand frisch ist.
R.RISK_OLD = 1800   -- Sekunden: aelterer, nie live gepruefter Stand gilt als mittleres Risiko
function R.Risk(d)
    if not d or d.gone then return nil end
    local seen = d.live and d.checked and (Now() - d.checked) or (d.seenT and (time() - d.seenT)) or nil
    if d.kind == "buyout" then
        local level, why = ns.Buyout.Risk(d, seen, R.Budget())
        d.riskWhy = why
        return level
    end
    d.riskWhy = nil
    if not seen or seen > R.RISK_OLD then return "mid" end
    return "low"
end

function R.Rows()
    local rows, budget, vis = {}, R.Budget(), {}
    for key, d in pairs(R.entries) do
        if R.Visible(d, budget) then
            d.risk = R.Risk(d)
            rows[#rows + 1] = d; vis[key] = true
        end
    end
    -- vorher sichtbar, jetzt nicht mehr (Gold/Mindestgewinn): grau mit Grund (ab 0.20)
    for key in pairs(R.lastVisible or {}) do
        local d = R.entries[key]
        if not vis[key] and d and not R.gone[key] then R.MarkGone(d, L.RADAR_GONE_GOLD) end
    end
    R.lastVisible = vis
    local now = Now()
    for key, g in pairs(R.gone) do
        -- die graue Zeile des Gegenstands im Fokus bleibt, solange er dort steht
        local keep = R.focus and R.focus.key == key
        if vis[key] or (now > (g.goneUntil or 0) and not keep) then R.gone[key] = nil else rows[#rows + 1] = g end
    end
    return rows
end

---------------------------------------------------------------------------
-- Radar-Scan
---------------------------------------------------------------------------
-- Runde des Radar-Scans (ab 0.64): nur die gezeigten Chancen, die am laengsten nicht gepruefte zuerst.
-- Neue Gegenstaende sucht der Radar-Scan nicht, sie kommen aus dem naechsten Komplettscan.
function R.BuildRound()
    local round, budget = {}, R.Budget()
    for key, d in pairs(R.entries) do
        if R.Visible(d, budget) and ns.Buy.KnownKey(key) then round[#round + 1] = key end
    end
    table.sort(round, function(a, b)
        local ca, cb = R.entries[a].checked or 0, R.entries[b].checked or 0
        if ca ~= cb then return ca < cb end
        return tostring(a) < tostring(b)
    end)
    return round
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

-- Treffer aus dem Scan, die noch nicht live geprueft sind (hoechstens 2 Versuche je Treffer). Nur waehrend des
-- Radar-Scans: von selbst wird nichts live nachgeprueft (ab 0.64).
function R.Unchecked()
    if not R.running then return nil end
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

function R.Start()
    if R.running or not AHOpen() or ns.Scan.state then return end
    R.running = true
    R.round = R.BuildRound()
    R.index = 0
    R.stats = NewStats()
    R.stats.started = date and date("%Y-%m-%d %H:%M:%S") or nil
    mod.acc.radarStats = mod:IsDebug() and R.stats or nil   -- ab 0.28 nur mit /broker debug gespeichert
    mod:Dbg(("Radar gestartet: %d Gegenstaende in der Runde"):format(#R.round))
    R.UpdateView()
    R.Wake()
end

-- Radar-Scan aus (Knopf); die Schnellpruefung der Scan-Treffer laeuft ggf. weiter
function R.Stop()
    if not R.running then return end
    R.running = false
    R.UpdateView()
end

-- Reiter verlassen oder Auktionshaus zu: alles anhalten
function R.Halt()
    R.running = false
    R.loop = false
    R.pending = nil
    if R.focus and ns.Measure then ns.Measure.Stop() end   -- ab 0.66: letzte Messung merken
    R.focus = nil
    R.UpdateView()
end

-- Voller Scan (Broker-Scan) gestartet (ab 0.19): Radar-Scan beenden, keine Abfragen waehrend des Scans
function R.OnFullScan()
    R.running = false
    R.loop = false
    R.pending = nil
    R.UpdateView()
end

-- Fokus (ab 0.64): genau ein Gegenstand wird regelmaessig neu abgefragt, solange die Seite Fokus offen ist.
-- key = nil beendet den Fokus. Der Gegenstand muss keine Chance sein.
function R.SetFocus(key)
    local M = ns.Measure
    if M then   -- ab 0.66: Messung fuer diesen Gegenstand, ein anderer beginnt neu, "Jetzt pruefen" misst weiter
        if key == nil then M.Stop()
        elseif not M.cur or M.cur.key ~= key then M.Start(key) end
    end
    R.focus = key ~= nil and { key = key, at = 0 } or nil
    R.Wake()
end

-- Abfrage fuer den Gegenstand im Fokus (wie Blizzards "Neu laden"); true = gesendet
function R.SendFocus()
    local f = R.focus
    f.at = Now() + R.FocusEvery()
    local ok = R.Send(f.key, nil, true)
    if ok and R.pending then R.pending.focus = true end   -- Antwort geht in die Messung (ab 0.66)
    return ok
end

function R.Schedule()
    if not (R.loop and C_Timer) then return end
    local gen = R.gen
    C_Timer.After(R.TICK, function() if R.gen == gen then R.Tick() end end)
end

-- Naechster Gegenstand des Radar-Scans: zuerst ungepruefte Scan-Treffer, dann reihum die gezeigten Chancen,
-- jede fruehestens nach R.RECHECK Sekunden wieder
function R.NextKey()
    -- zweite Pruefung nach "keine Angebote" (ab 0.20.1)
    local soon = R.soon
    if soon and R.entries[soon.key] and Now() >= soon.at then R.soon = nil; return soon.key end
    if soon and not R.entries[soon.key] then R.soon = nil end
    local first = R.Unchecked()
    if first ~= nil then return first end
    if not R.running then return nil end
    if not R.round or R.index >= #R.round then R.round = R.BuildRound(); R.index = 0 end
    while R.index < #R.round do
        R.index = R.index + 1
        local key = R.round[R.index]
        local d = R.entries[key]
        if d and not R.skip[key] and (not d.checked or Now() - d.checked >= R.RECHECK) and R.ItemReady(key) then return key end
    end
    return nil
end

function R.Tick()
    if not R.loop then return end
    if not (AHOpen() and R.Active()) then R.Halt(); return end
    if R.running and not R.Shown() then R.running = false end   -- der Radar-Scan laeuft nur auf der Seite Radar
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
    if not busy and due and ready and not R.job and R.focus and now >= R.focus.at and R.ItemReady(R.focus.key) then
        R.SendFocus()
    elseif not busy and due and ready and not R.job then
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
    -- ab 0.66 (H2): Antwort auf die Abfrage im Fokus in die Messung
    if p.focus and not cached and ns.Measure and R.focus and R.focus.key == p.key then ns.Measure.Add(p.key, rows, Now()) end
    local old = R.entries[p.key]
    local d = R.Evaluate(p.key, rows, true, commodity)
    if d and not R.KIND_ON[d.kind] then d = nil end   -- Art nicht im Radar
    local hidden = false
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
-- Menge fuer "Stapel": Stapelgroesse, hoechstens die Schnaeppchen-Menge
function R.StackQty(d)
    if not d or not d.commodity then return 1 end
    return math.min(d.stackQty or 1, d.qty or 1)
end

-- Menge je Art des Kaufs: "best" = was mit meinem Gold den hoechsten Gewinn bringt (Kaufknopf im Fokus),
-- "one" = 1 Stueck, "stack" = ab Gewinn bzw. bis ein Stapel, sonst alle des Schnaeppchens
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
function R.BuyStep(d, mode)
    mode = mode or "one"
    if not d or d.gone or not AHOpen() then return end
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.SELL_COMBAT); return end
    local ah = AHApi()
    local job = R.job
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
        local expect = ns.Data.CostOf(d.rows or {}, got)
        R.job = { key = d.key, id = id, qty = got, limit = lastPrice, name = d.name, stage = "quote", kind = d.kind, mode = mode, t = Now(), done = 0,
                  expect = expect, target = d.ref }
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
    -- ab 0.66: Gesamtpreis hoeher als erwartet -> Warnung vor dem zweiten Klick (Konzept 6.1)
    job.warn = (Num(totalPrice) and Num(job.expect) and job.expect > 0 and totalPrice > job.expect * (1 + R.PRICE_TOL)) or nil
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
    if R.list then R.list:SetData(R.Rows()) end
    R.UpdateView()
end

function R.SignedMoney(v)
    if not v then return "" end
    if v < 0 then return RED .. "−" .. Money(-v) .. "|r" end
    return GREEN .. "+" .. Money(v) .. "|r"
end

-- Text des Kaufknopfs, solange ein Kauf laeuft (Bestaetigen / Weiter)
function R.JobText(job)
    if job.stage == "confirm" then return L.RADAR_CONFIRM_SHORT end
    if job.stage == "next" then return L.RADAR_BTN_NEXT:format(#job.queue - job.idx) end
    return L.RADAR_BUYING
end

-- Stand in der oberen Zeile
function R.StatusText()
    local st
    if ns.Scan.state then
        st = ORANGE .. L.RADAR_FULLSCAN .. "|r"
    elseif R.running then
        local mins = math.max(1 / 60, (Now() - R.stats.t0) / 60)
        st = GREEN .. L.RADAR_RUNNING:format(math.floor(R.stats.sent / mins + 0.5), R.stats.sent) .. "|r"
    else
        local market = ns.Data.Market()
        local at = market and ns.Data.DataAt(market)
        if not at then st = ORANGE .. L.MM_NO_SCAN .. "|r"
        else st = GREY .. L.RADAR_STAND:format(ns.Scan.Age(at)) .. "|r" end
    end
    if not AHOpen() then st = st .. "  " .. ORANGE .. L.ST_NOT_LIVE .. "|r" end
    return st
end

function R.UpdateView()
    if ns.Focus and ns.Focus.Update then ns.Focus.Update() end
    if not R.list then return end
    R.status:SetText(R.StatusText())
    R.scanButton:SetText(R.running and L.RADAR_STOP or L.RADAR_START)
    if AHOpen() and not ns.Scan.state then R.scanButton:Enable() else R.scanButton:Disable() end
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
        local function Go() R.nameRefresh = nil; R.Refresh() end
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
    elseif r.kind == "buyout" then
        GameTooltip:AddLine(L.RADAR_TT_BUYOUT:format(Money(r.limit or 0), Money(r.ref or 0)), 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L.RADAR_TT_SELLS:format(ns.Buyout.HoursText(r.hours)), 0.7, 0.7, 0.7)
        for _, w in ipairs(r.riskWhy or {}) do GameTooltip:AddLine("- " .. w, 1, 0.82, 0) end
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

R.RISK_COLOR = { low = GREEN, mid = "|cffffd100", high = RED }

function R.Build(c)
    local UI = Peon.UI
    R.scanButton = UI.Button(c, L.RADAR_START, 170, function() if R.running then R.Stop() else mod:Call("Radar", R.Start) end end)
    R.scanButton:SetPoint("TOPRIGHT", -2, -2)
    UI.SetTooltip(R.scanButton, { L.RADAR_START, L.RADAR_SCAN_TIP })
    R.status = UI.Text(c, "small", "")
    R.status:SetPoint("TOPLEFT", 8, -8)
    R.status:SetPoint("RIGHT", R.scanButton, "LEFT", -12, 0)
    if R.status.SetWordWrap then R.status:SetWordWrap(false) end
    local p = UI.Panel(c, "list", true)
    p:SetPoint("TOPLEFT", 0, -30)
    p:SetPoint("BOTTOMRIGHT", 0, 0)
    R.panel = p
    R.list = UI.Table(p, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
              format = function(v, r)
                  local isNew = r.newUntil and Now() < r.newUntil
                  return (isNew and ("|T" .. R.DOT .. ":10:10:0:0|t ") or "") .. v
              end,
              color = function(r)
                  if r.gone or r.cant then return 0.5, 0.5, 0.5 end
                  return UI.QualityColor(r.quality or 1)
              end },
            { key = "showGain", title = L.RADAR_COL_GAIN, width = 130, align = "RIGHT",
              format = function(v, r)
                  if r.gone then return ORANGE .. L.RADAR_GONE_SHORT .. "|r" end
                  local text = Money(math.floor((v or 0) + 0.5))
                  return (r.cant and GREY or GREEN) .. text .. "|r"
              end,
              -- ab 0.65: Gewinn, rotes Risiko nach unten (Konzept 6.1)
              sort = function(r)
                  if r.gone then return -1e15 end
                  local g = r.showGain or 0
                  if r.risk == "high" then return g - 1e13 end
                  return g
              end },
            { key = "kind", title = L.RADAR_COL_KIND, width = 110, align = "RIGHT",
              format = function(v) return L["RADAR_KIND_" .. tostring(v):upper()] or tostring(v) end },
            { key = "risk", title = L.RADAR_COL_RISK, width = 100, align = "RIGHT",
              format = function(v) return v and ((R.RISK_COLOR[v] or "") .. (L["RADAR_RISK_" .. v:upper()] or v) .. "|r") or "" end,
              sort = function(r) return ({ low = 1, mid = 2, high = 3 })[r.risk] or 9 end },
            { key = "checked", title = L.MARKET_COL_AGE, width = 90, align = "RIGHT",
              format = function(v, r)
                  if not v then return GREY .. R.ShortAge(r.seenT and (time() - r.seenT)) .. "|r" end
                  return R.ShortAge(Now() - v)
              end,
              sort = function(r) return r.checked and -r.checked or 0 end },
        },
        sortKey = "showGain", sortDesc = true, icon = true, empty = L.RADAR_EMPTY2,
        onClick = function(r, button)
            if button == "RightButton" then ns.Go.Menu(r, R.panel) else mod:Call("Sprung", ns.Go.Focus, r) end
        end,
        onEnter = function(row, r) if r then R.RowTooltip(row, r) end end,
    })
    function R.list:GetItems() return self.items end
    R.Open()
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

-- Seite Radar geoeffnet: Chancen aus der Datenbank, ohne Live-Pruefung
function R.Open()
    R.LoadIfStale()
    R.Refresh()
end

function R.Init()
    -- "Nur Warnton" (0.16 bis 0.63) entfaellt. Nach einem Absturz gemerkte Tonwerte einmal zurueckstellen.
    local saved = mod.acc.radarMuteSaved
    if type(saved) == "table" then
        local cv = rawget(_G, "C_CVar")
        for name, value in pairs(saved) do
            if cv and cv.SetCVar then pcall(cv.SetCVar, name, value) elseif SetCVar then pcall(SetCVar, name, value) end
        end
        mod.acc.radarMuteSaved = nil
    end
    pcall(mod.RegisterEvent, mod, "GET_ITEM_INFO_RECEIVED", function(_, id) mod:Call("Radar", R.OnItemInfo, id) end)   -- ab 0.57
    mod:RegisterEvent("PLAYER_MONEY", function() if R.Active() then R.Refresh() end end)
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
        if R.Shown() then R.Open() elseif R.Active() then R.LoadIfStale(); R.Refresh() end
    end)
end

---------------------------------------------------------------------------
-- Die Seite Radar steht im Broker-Fenster oder als Reiter im Auktionshaus (AHTabs.lua haengt sie um).
-- R.Shown() = die Seite Radar ist zu sehen. R.Active() = Radar oder Fokus ist zu sehen (dann laufen Abfragen).
---------------------------------------------------------------------------
function R.Shown()
    local T = ns.AHTabs
    if T and T.current == "radar" then return true end
    if T and T.host and T.host.radar == "ah" then return false end
    return W.IsOpen() and W.current == "radar"
end

function R.Active()
    return R.Shown() or (ns.Focus ~= nil and ns.Focus.Shown())
end

-- Treffer, die das Radar gerade zeigen wuerde (fuer die Zahl am Reiter)
function R.CountHits()
    local n, budget = 0, R.Budget()
    for _, d in pairs(R.entries) do
        if R.Visible(d, budget) then n = n + 1 end
    end
    return n
end

-- Naechste Chance nach der im Fokus (hoechster Gewinn zuerst, am Ende wieder von vorn)
function R.NextChance(key)
    local rows, budget = {}, R.Budget()
    for _, d in pairs(R.entries) do
        if R.Visible(d, budget) and not d.cant then rows[#rows + 1] = d end
    end
    table.sort(rows, function(a, b)
        if (a.showGain or 0) ~= (b.showGain or 0) then return (a.showGain or 0) > (b.showGain or 0) end
        return tostring(a.key) < tostring(b.key)
    end)
    if #rows == 0 then return nil end
    for i, d in ipairs(rows) do
        if d.key == key then return rows[(i % #rows) + 1] end
    end
    return rows[1]
end

-- Tastenbelegungen (Bindings.xml): Chance im Fokus kaufen, naechste Chance in den Fokus
function PeonBroker_RadarBuy()
    local F = ns.Focus
    if not (F and F.Shown() and F.key ~= nil) then return end
    local d = R.entries[F.key]
    if d then mod:Call("Radar", R.BuyStep, d, "best") end
end

function PeonBroker_RadarNext()
    if not R.Active() then return end
    local d = R.NextChance(ns.Focus and ns.Focus.key)
    if d then mod:Call("Sprung", ns.Go.Focus, d) end
end

W.pages.radar = {
    build = R.Build,
    refresh = function() R.Open() end,
    leave = function() R.Halt() end,
}
