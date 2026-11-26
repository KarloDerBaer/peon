-- Peon_Broker - Chances.lua
-- Ab 0.96 (Konzept Peon_Chancen_Reiter_Muster.md, Abschnitt 3, KarloDerBaer 15.11.2026): Reiter "Chancen" rechts neben
-- dem Radar. Hier stehen die Chancen des Peon Managers (Beobachtungen ueber Tage), das Radar zeigt nur noch, was ein
-- Scan im Spiel gerade findet (Haendler, Aufkauf).
--   Liste     alle gueltigen Eintraege aus Data.lua (Spec.lua): Art, Gewinn, Kaufen bis, Zustand
--   Zustand   ungeprueft, bestaetigt (Alter der Pruefung) oder weg. Am Auktionator prueft Broker die Zeilen nacheinander
--             live (wie das Erneuern im Radar, Radar.lua R.NextRenew)
--   Alle pruefen  fragt alle Kandidaten einmal ab (Radar-Scan mit der Auswahl "mgronly", ersetzt "Vom Manager")
--   Muster    liegt die Uhrzeit im guenstigen Fenster, ist die Zeile gruen, sonst steht dort "ab 21 Uhr"
--   Einstellungen  Arten an oder aus, Hinweis beim Oeffnen des Auktionshauses, Meldung beim Beginn eines Fensters
-- Klick auf eine Zeile oeffnet den Fokus, gekauft wird dort wie bisher.
-- Ab 0.101 (Wunsch KarloDerBaer 17.11.2026): Was beim Pruefen weg war, merkt sich Broker mit dem Stand des Managers, aus
-- dem die Chance kam (C.Forget). Bis ein neuerer Stand sie wieder bringt, steht sie nicht mehr in der Liste. Der Manager
-- liest die Liste aus Peon_Broker.lua und blendet sie ebenfalls aus.
-- Ab 0.102 (Rueckmeldung KarloDerBaer 17.11.2026): Chancen mit Varianten ohne gelernten Suchschluessel lernt Broker
-- zuerst ueber die Browse-Suche (C.NextLearn, Radar.lua R.LearnChance), sonst blieben sie "ungeprueft".
-- Ab 0.105 (KarloDerBaer 19.11.2026): Das Radar hat keinen eigenen Reiter mehr. Eine Liste fuer beides:
--   Chancen des Managers wie bisher. Die Live-Pruefung aktualisiert sie, auch wenn das Radar fuer denselben
--     Gegenstand etwas findet (keine doppelten Zeilen).
--   Treffer des Radars (Haendler, Aufkauf), die keine Chance des Managers sind, mit Risiko und Alter. Weggefallene
--     bleiben wie im Radar R.GONE_TIME Sekunden grau stehen, verworfene Chancen des Managers wie bisher ausgeblendet.
--   Scan-Knopf mit Auswahl: Manager-Chancen (eine Runde, frueher "Alle pruefen"), Beobachten, Massenware, Alles.
--   Zahl am Reiter: alle Zeilen zusammen. Nach einem Komplettscan mit neuen Treffern blinkt sie bis zum Oeffnen.
--   Einstellungen: ein Fenster mit Chancen und Radar.
-- Ab 0.119 (Konzept Peon_Broker_Chancen_Schnellkauf.md, KarloDerBaer 19.11.2026): drei Unterreiter
--   Spekulation  Chancen des Managers der Arten Spekulation, Langzeit und Muster, Knopf "Alle pruefen"
--   Aufkauf      Chancen des Managers der Art Aufkauf, Treffer des Radars (Aufkauf, Haendler), Scan mit Auswahl
--   Schnellkauf  Vorschlaege fuer den Schnellkauf mit Pruefung der Marktbewegung (QuickChances.lua)
--   Laufend geprueft wird nur der offene Unterreiter, gemerkt in chancesTab. Unterreiter ohne eingeschaltete Art
--   verschwinden. Die Zahl am Reiter zaehlt alle Listen (Schnellkauf: lebhafte), die Unterreiter zeigen die Aufteilung.
-- Ab 0.127 (Konzept Peon_Broker_Marktvergleich.md, KarloDerBaer 20.11.2026): vierter Unterreiter Markttausch (Trade.lua),
--   Fraktion und Neutral, Liste vom Manager oder ohne ihn nach Preisunterschied, "Alle pruefen" fuer das Haus hier.
-- Ab 0.138 (U6, Konzept Peon_Broker_Schlank.md 8, KarloDerBaer 24.11.2026): Sichtbar ist nur Schnellkauf, ohne
--   Unterreiterleiste. Der Schalter "Weitere Chancen" (chancesMore, Vorgabe aus, Einstellungen Chancen unter Erweitert)
--   bringt Spekulation, Aufkauf, Markttausch und Pakete zurueck. Solange er aus ist, laeuft dafuer nichts: keine
--   Abfragen, kein Radar-Scan, keine Hinweise und keine Zahl am Reiter fuer diese Arten.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local C = {}
ns.Chances = C

C.checked = {}   -- [Schluessel] = { t = Zeit der Pruefung (GetTime), ok = noch da, gain, offer }
C.blink = false  -- ab 0.105: neue Treffer nach einem Komplettscan, Zahl blinkt bis zum Oeffnen
C.notified = {}  -- [Schluessel .. Fenster] = true: Meldung zum Fenster schon gegeben (diese Sitzung)
C.KIND_SETTING = { s = "chancesShowS", l = "chancesShowL", b = "chancesShowB", m = "chancesShowM" }
-- ab 0.119: Unterreiter
-- ab 0.140 (KarloDerBaer 26.11.2026): alle Unterreiter von Anfang an, Reihenfolge Schnellkauf, Aufkauf, Spekulation,
-- Markttausch, Pakete. Jeder Unterreiter einzeln abschaltbar (C.TAB_SETTING, Einstellungen der Chancen).
C.TABS = { "quick", "buyout", "spec", "trade", "pkg" }
C.TAB_SETTING = { quick = "chancesShowQ", buyout = "chancesTabBuyout", spec = "chancesTabSpec", trade = "tradeOn", pkg = "chancesTabPkg" }
C.TAB_OF_MK = { s = "spec", l = "spec", m = "spec", b = "buyout" }
C.TAB_OF_KIND = { buyout = "buyout", vendor = "buyout" }

local GREY, ORANGE, GREEN, GOLD = "|cff999999", "|cffff9933", "|cff60e060", "|cffffd100"
local function Money(v) return ns.Tooltip.Money(v) end
local function Now() return GetTime and GetTime() or time() end

-- Art an? (Einstellungen)
function C.KindOn(mk)
    local k = C.KIND_SETTING[mk]
    return k ~= nil and mod.db[k] ~= false
end

-- ab 0.138 (U6): Weitere Chancen eingeschaltet? Ab 0.140 ohne eigenen Schalter: an, sobald ein Unterreiter ausser
-- Schnellkauf an ist (chancesMore bleibt gespeichert, ungenutzt)
function C.More()
    return C.TabOn("buyout") or C.TabOn("spec") or C.TabOn("trade") or C.TabOn("pkg")
end

-- ab 0.140: Unterreiter in den Einstellungen eingeschaltet? (Vorgabe an, Markttausch ueber tradeOn)
function C.TabWanted(tab)
    local k = C.TAB_SETTING[tab]
    if k == "tradeOn" then return mod.db.tradeOn == true end
    return k ~= nil and mod.db[k] ~= false
end

-- ab 0.119: Unterreiter an? (mindestens eine Art eingeschaltet). ab 0.140 jeder Unterreiter mit eigenem Schalter
function C.TabOn(tab)
    if not C.TabWanted(tab) then return false end
    if tab == "spec" then return C.KindOn("s") or C.KindOn("l") or C.KindOn("m") end
    if tab == "buyout" then
        local R = ns.Radar
        return C.KindOn("b") or (R ~= nil and (R.KIND_ON.vendor or R.KIND_ON.buyout)) or false
    end
    if tab == "quick" then return true end
    if tab == "trade" then return ns.Trade ~= nil and ns.Trade.On() end   -- ab 0.127
    if tab == "pkg" then return ns.Packages ~= nil and ns.Packages.On() end   -- ab 0.129
    return false
end

-- Offener Unterreiter: der gemerkte, wenn er an ist, sonst der erste eingeschaltete
function C.Tab()
    local t = mod.db.chancesTab
    if t ~= "spec" and t ~= "buyout" and t ~= "quick" and t ~= "trade" and t ~= "pkg" then t = "quick" end
    if C.TabOn(t) then return t end
    for _, k in ipairs(C.TABS) do if C.TabOn(k) then return k end end
    return t
end

-- Unterreiter eines Treffers des Radars (Art "spec" sind Chancen des Managers, die das Radar live gerechnet hat)
function C.EntryTab(d)
    if type(d) ~= "table" then return nil end
    if d.kind == "spec" then return C.TAB_OF_MK[d.mk] or "spec" end
    return C.TAB_OF_KIND[d.kind]
end

function C.Shown()
    local T = ns.AHTabs
    if T and T.current == "chances" then return true end
    if T and T.host and T.host.chances == "ah" then return false end
    return W.IsOpen() and W.current == "chances"
end

---------------------------------------------------------------------------
-- Verworfene Chancen (ab 0.101), accountweit je Markt:
--   PeonBrokerDB.chancesGone[Markt][Schluessel] = "Stand:Zeit:Angebot"
--   Stand = Zeit des Manager-Stands (t aus Data.lua), Zeit = time() der Pruefung, Angebot = guenstigstes Angebot
--   in Kupfer (0 = keine Angebote mehr). Kommt ein neuerer Stand, gilt der Eintrag nicht mehr und wird entfernt.
-- C.goneNow: in dieser Sitzung verworfen, solange der Reiter offen ist. Diese Zeilen bleiben als "weg" stehen.
---------------------------------------------------------------------------
C.GONE_KEEP = 3 * 86400   -- Eintraege ohne neueren Stand fallen nach 3 Tagen weg
C.goneNow = {}

function C.GoneStore(create)
    local acc, market = mod.acc, ns.MarketKey()
    if type(acc) ~= "table" or type(market) ~= "string" then return nil end
    if type(acc.chancesGone) ~= "table" then
        if not create then return nil end
        acc.chancesGone = {}
    end
    local s = acc.chancesGone[market]
    if type(s) ~= "table" then
        if not create then return nil end
        s = {}
        acc.chancesGone[market] = s
    end
    return s
end

function C.ParseGone(v)
    if type(v) ~= "string" then return nil end
    local s, t, o = v:match("^(%d+):(%d+):(%d+)$")
    if not s then return nil end
    return { stand = tonumber(s), t = tonumber(t), offer = tonumber(o) }
end

-- Verworfen zu diesem Stand des Managers (oder einem neueren)?
function C.GoneAt(key, stand)
    local s = C.GoneStore(false)
    local g = s and C.ParseGone(s[key])
    return g ~= nil and type(stand) == "number" and g.stand >= stand
end

-- Nicht zeigen: verworfen und nicht gerade erst (dann steht die Zeile noch als "weg" da)
function C.Hidden(key, x)
    if C.goneNow[key] then return false end
    return C.GoneAt(key, x and x.t)
end

-- Ergebnis der Pruefung merken. Ohne Stand des Managers nichts. Aufkauf prueft Broker mit den Regeln des Radars,
-- ist die Art dort aus, sagt die Pruefung nichts.
function C.Forget(key, x, offer)
    if not (x and type(x.t) == "number") then return end
    if x.mk == "b" and ns.Radar and not ns.Radar.KIND_ON.buyout then return end
    local s = C.GoneStore(true)
    if not s then return end
    s[key] = ("%d:%d:%d"):format(x.t, time(), math.max(0, math.floor(tonumber(offer) or 0)))
    C.goneNow[key] = true
end

function C.Unforget(key)
    local s = C.GoneStore(false)
    if s then s[key] = nil end
    C.goneNow[key] = nil
end

-- Aufraeumen: im aktuellen Markt alles zu einem aelteren Stand, ueberall alles nach C.GONE_KEEP
function C.Prune()
    local acc = mod.acc
    if type(acc) ~= "table" or type(acc.chancesGone) ~= "table" then return end
    local market, now = ns.MarketKey(), time()
    local stand
    if ns.Spec and market then stand = select(2, ns.Spec.All()) end
    for m, s in pairs(acc.chancesGone) do
        if type(s) == "table" then
            for key, v in pairs(s) do
                local g = C.ParseGone(v)
                if not g or now - g.t > C.GONE_KEEP or (m == market and type(stand) == "number" and g.stand < stand) then s[key] = nil end
            end
            if next(s) == nil then acc.chancesGone[m] = nil end
        else
            acc.chancesGone[m] = nil
        end
    end
    if next(acc.chancesGone) == nil then acc.chancesGone = nil end
end

-- Wie viele Chancen sind gerade verworfen und ausgeblendet?
function C.HiddenCount()
    local n = 0
    if not ns.Spec then return 0 end
    for key, x in pairs(ns.Spec.All()) do
        if C.KindOn(x.mk) and C.Hidden(key, x) then n = n + 1 end
    end
    return n
end

-- Schluessel der gezeigten Arten, hoechster Gewinn zuerst (fuer Erneuern und "Alle pruefen").
-- ab 0.119: tab = Unterreiter (ohne: der offene, "all" = alle)
function C.Keys(tab)
    local Sp = ns.Spec
    if not Sp then return {} end
    tab = tab or C.Tab()
    local all, keys = Sp.All(), {}
    for key, x in pairs(all) do
        if C.KindOn(x.mk) and (tab == "all" or C.TAB_OF_MK[x.mk] == tab) and not C.Hidden(key, x) and ns.Buy.KnownKey(key) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b) return (all[a].gain or 0) > (all[b].gain or 0) end)
    return keys
end

-- ab 0.102.0: Chancen mit Varianten, deren Suchschluessel Broker noch nicht kennt (Radar.lua R.LearnChance).
-- Hoechster Gewinn zuerst, je Chance hoechstens LEARN_TRIES Versuche im Abstand von LEARN_AGAIN Sekunden.
C.LEARN_TRIES = 3
C.LEARN_AGAIN = 30
C.learnAt, C.learnTries = {}, {}

function C.NextLearn()
    local Sp = ns.Spec
    if not Sp then return nil end
    local now, best, bestGain = Now(), nil, nil
    local tab = C.Tab()
    for key, x in pairs(Sp.All()) do
        if C.KindOn(x.mk) and C.TAB_OF_MK[x.mk] == tab and not C.Hidden(key, x) and ns.Data.IsVariantKey(key) and not ns.Buy.KnownKey(key)
            and not C.checked[key] and (C.learnTries[key] or 0) < C.LEARN_TRIES
            and now - (C.learnAt[key] or -1e9) >= C.LEARN_AGAIN then
            local g = x.gain or 0
            if bestGain == nil or g > bestGain then best, bestGain = key, g end
        end
    end
    return best
end

-- Haben alle gefundenen Varianten einen Namen vom Spiel? Erst dann heisst "nicht dabei" auch "weg".
function C.AllNamed(found)
    local ah = rawget(_G, "C_AuctionHouse")
    if not (ah and ah.GetItemKeyInfo) then return false end
    for _, f in ipairs(found) do
        local ok, info = pcall(ah.GetItemKeyInfo, f.itemKey)
        local name = ok and type(info) == "table" and info.itemName
        if type(name) ~= "string" or name == "" or Peon.IsSecret(name) then return false end
    end
    return true
end

-- Antwort einer Live-Abfrage (Radar.lua R.Apply): Zustand merken, wenn der Gegenstand eine Chance des Managers ist
function C.Note(key, d, rows)
    local x = ns.Spec and ns.Spec.Get(key)
    if not x then return end
    local lv = ns.Data.Available(rows or {})
    C.checked[key] = { t = Now(), ok = d ~= nil, gain = d and (d.showGain or d.gain) or nil, offer = lv[1] and lv[1].price or nil }
    -- ab 0.101: weg merken (mit dem Stand des Managers), wieder da: vergessen
    if d then C.Unforget(key) else C.Forget(key, x, lv[1] and lv[1].price) end
    if C.Shown() then C.Refresh() end
    C.UpdateBadge()
end

-- Zahl am Reiter (ab 0.97, einstellbar, Standard aus): ok = live bestaetigt, all = alle gezeigten.
-- Muster zaehlen nur im guenstigen Zeitfenster.
-- ab 0.119: tab = nur dieser Unterreiter. Schnellkauf zaehlt die lebhaften Vorschlaege.
function C.BadgeCount(mode, tab)
    local n = 0
    if not C.More() then   -- ab 0.138: nur Schnellkauf zaehlt
        if (tab == nil or tab == "quick") and ns.QuickChances then n = ns.QuickChances.LivelyCount() end
        return n
    end
    for _, r in ipairs(C.Rows()) do
        local now = not (r.mk == "m" and r.x.buyWin and not r.inWindow)
        if (tab == nil or r.tab == tab) and now and (mode == "all" and r.state ~= "gone" or r.state == "ok") then n = n + 1 end
    end
    if (tab == nil or tab == "quick") and ns.QuickChances then n = n + ns.QuickChances.LivelyCount() end
    if (tab == nil or tab == "trade") and ns.Trade then n = n + ns.Trade.Count() end   -- ab 0.127: gruene Eintraege
    if (tab == nil or tab == "pkg") and ns.Packages then n = n + ns.Packages.Count() end   -- ab 0.129: Kaufen oder Verkaufen moeglich
    return n
end

-- ab 0.119: Zahlen an den Unterreitern (alle gezeigten Zeilen, Schnellkauf: lebhafte)
function C.UpdateTabBadges()
    if not C.tabs then return end
    for _, t in ipairs(C.tabs) do
        if t.SetBadge then t:SetBadge(C.BadgeCount("all", t.key)) end
    end
end

function C.UpdateBadge()
    local T = ns.AHTabs
    if not (T and T.SetBadge and T.built and T.BadgeMode) then return end
    local mode = T.BadgeMode("chances")
    if mode == "off" then
        if T.badges.chances then T.SetBadge("chances", nil) end
        return
    end
    if T.current == "chances" then return end   -- offen: keine Zahl, wie bei den anderen Reitern
    local n = C.BadgeCount(mode)
    T.SetBadge("chances", n, C.blink and n > 0)
end

-- ab 0.105: nach einem Komplettscan (AHTabs.OnScanDone): neue Treffer des Radars lassen die Zahl blinken
function C.OnScanDone(hits)
    C.blink = (hits or 0) > 0 and not C.Shown()
    C.UpdateBadge()
end

-- Fenster als Text: "0 bis 3 Uhr", "Samstag", "Samstag 18 bis 21 Uhr"
function C.WindowText(w)
    if not w then return nil end
    local day
    if w.mask ~= 127 then
        local names = {}
        for i = 0, 6 do if math.floor(w.mask / 2 ^ i) % 2 == 1 then names[#names + 1] = L["CH_WD_" .. i] end end
        day = table.concat(names, ", ")
    end
    local slot = w.slot >= 0 and L.CH_SLOT:format(w.slot * 3, w.slot * 3 + 3) or nil
    if day and slot then return day .. " " .. slot end
    return day or slot or L.CH_ANYTIME
end

-- Liegt die Zeit (time()) im Fenster? Wochentage als Bits, Montag = 1
function C.InWindow(w, t)
    if not w then return true end
    local d = date("*t", t or time())
    local wd = (d.wday + 5) % 7   -- wday 1 = Sonntag -> Montag = 0
    if math.floor(w.mask / 2 ^ wd) % 2 ~= 1 then return false end
    if w.slot >= 0 and math.floor(d.hour / 3) ~= w.slot then return false end
    return true
end

-- Zeilen fuer die Liste: Chancen des Managers, dazu (ab 0.105) die Treffer des Radars ohne Chance des Managers
function C.Rows()
    local Sp, D, R = ns.Spec, ns.Data, ns.Radar
    local rows, seen = {}, {}
    local market = D.Market()
    for key, x in pairs(Sp and Sp.All() or {}) do
        if C.KindOn(x.mk) then seen[key] = true end   -- auch verworfene: das Radar zeigt sie nicht doppelt
        if C.KindOn(x.mk) and not C.Hidden(key, x) then
            local e = market and market.items[key]
            local r = { key = key, mk = x.mk, x = x, limit = x.limit, target = x.target, qty = x.qty, say = x.say, tab = C.TAB_OF_MK[x.mk] }
            r.kindText = L["CH_KIND_" .. tostring(x.mk):upper()] or tostring(x.mk)
            r.name = (type(e) == "table" and e.nm) or D.ItemName(key, e)
            if not r.name then r.name, r.noName = tostring(key), true; if R then R.RequestName(D.ItemID(key)) end end
            r.quality = type(e) == "table" and e.ql or nil
            r.icon = ns.Buy.Icon(D.ItemID(key))
            local c = C.checked[key]
            r.checked = c
            r.gain = (c and c.ok and c.gain) or x.gain or 0
            r.inWindow = C.InWindow(x.buyWin)
            if c and not c.ok then r.state, r.rank = "gone", 3
            elseif c then r.state, r.rank = "ok", 0
            else r.state, r.rank = "new", 1 end
            if x.mk == "m" and not r.inWindow then r.rank = r.rank + 0.5 end
            -- Risiko aus der Live-Pruefung, wenn das Radar dabei eine Chance gerechnet hat
            local d = R and R.entries[key]
            if c and c.ok and d and d.risk then r.risk = d.risk end
            rows[#rows + 1] = r
        end
    end
    if not R then return rows end
    for _, d in ipairs(R.Rows()) do
        if not seen[d.key] then
            local r = { key = d.key, d = d, radar = true, name = d.name, quality = d.quality, icon = d.icon, limit = d.limit,
                        gain = d.showGain or d.gain or 0, risk = not d.gone and d.risk or nil, newUntil = d.newUntil, tab = C.EntryTab(d) }
            r.kindText = L["RADAR_KIND_" .. tostring(d.kind):upper()] or tostring(d.kind)
            if d.gone then r.state, r.rank = "gone", 3
            elseif d.live and d.checked then r.state, r.rank = "ok", 0
            else r.state, r.rank = "new", 1 end
            if d.cant then r.rank = r.rank + 1.5 end
            if d.risk == "high" then r.rank = r.rank + 0.5 end
            rows[#rows + 1] = r
        end
    end
    return rows
end

-- ab 0.119: Zeilen eines Unterreiters
function C.TabRows(tab)
    local out = {}
    for _, r in ipairs(C.Rows()) do if r.tab == tab then out[#out + 1] = r end end
    return out
end

function C.StateText(r)
    if r.radar then
        local d = r.d
        if r.state == "gone" then return ORANGE .. L.CH_STATE_GONE .. "|r" end
        if r.state == "ok" then return GREEN .. L.CH_STATE_OK:format(ns.Radar.ShortAge(Now() - d.checked)) .. "|r" end
        return GREY .. L.CH_STATE_SCAN:format(ns.Radar.ShortAge(d.seenT and (time() - d.seenT))) .. "|r"
    end
    if r.mk == "m" and r.x.buyWin and not r.inWindow then
        return GREY .. L.CH_STATE_FROM:format(C.WindowText(r.x.buyWin)) .. "|r"
    end
    if r.state == "gone" then return ORANGE .. L.CH_STATE_GONE .. "|r" end
    if r.state == "ok" then return GREEN .. L.CH_STATE_OK:format(ns.Radar.ShortAge(Now() - r.checked.t)) .. "|r" end
    return GREY .. L.CH_STATE_NEW .. "|r"
end

-- ab 0.131: Tooltip des Gegenstands wie ueberall in Broker, die Angaben der Chance darunter
function C.RowTooltip(row, r)
    W.ShowItemTooltip(row, r.key, function(GT)
        GT:AddLine(L["CH_KIND_" .. r.mk:upper()] or r.mk, 1, 0.82, 0)
        local focus = ns.Spec.FocusText(r.key)
        if focus then GT:AddLine(focus, 0.85, 0.85, 0.85, true) end
        GT:AddLine(L.CH_TIP_PRICES:format(Money(r.limit or 0), Money(r.target or 0), r.qty or 1), 1, 1, 1)
        if r.x.buyWin then GT:AddLine(L.CH_TIP_WINDOW:format(C.WindowText(r.x.buyWin), C.WindowText(r.x.sellWin)), 0.6, 1, 0.6, true) end
        if r.checked and r.checked.offer then GT:AddLine(L.CH_TIP_OFFER:format(Money(r.checked.offer)), 0.85, 0.85, 0.85) end
        GT:AddLine(L.CH_TIP_CLICK, 0.6, 0.6, 0.6)
    end)
end

---------------------------------------------------------------------------
-- Seite
---------------------------------------------------------------------------
-- ab 0.105: Auswahl des Scans (mgr = Chancen des Managers, eine Runde) und Knopf Start/Stopp
function C.MODES()
    return { { "mgr", L.CH_SCAN_MGR }, { "watch", L.RADAR_MODE_WATCH }, { "mass", L.RADAR_MODE_MASS }, { "all", L.RADAR_MODE_ALL } }
end

-- ab 0.119: Auswahl nur im Unterreiter Aufkauf, Spekulation prueft immer die Chancen des Managers
function C.Mode()
    if C.Tab() == "spec" or C.Tab() == "trade" or C.Tab() == "pkg" then return "mgr" end
    local v = mod.db.chancesScan
    for _, m in ipairs(C.MODES()) do if m[1] == v then return v end end
    return "mgr"
end

function C.ModeText()
    for _, m in ipairs(C.MODES()) do if m[1] == C.Mode() then return m[2] end end
    return L.CH_SCAN_MGR
end

function C.SetMode(v)
    mod.db.chancesScan = v
    local R = ns.Radar
    if R.running then R.Stop() end
    R.search = nil
    if C.modeDrop and C.modeDrop.fallback then C.modeDrop:SetText(C.ModeText()) end
    C.UpdateView()
end

-- Rueckfall ohne Blizzards Auswahlliste: Klick schaltet weiter
function C.NextMode()
    local list, cur = C.MODES(), C.Mode()
    for i, m in ipairs(list) do
        if m[1] == cur then C.SetMode(list[(i % #list) + 1][1]); return end
    end
end

-- Knopf: Scan starten oder anhalten
function C.CheckAll()
    local R = ns.Radar
    if C.Tab() == "quick" then   -- ab 0.119: "Neu vorschlagen"
        if ns.QuickChances then ns.QuickChances.Renew() end
        if R then R.Wake() end
        return
    end
    if C.Tab() == "trade" then   -- ab 0.127: eine Runde fuer das Haus, an dem man steht
        if ns.Trade then ns.Trade.CheckAll() end
        return
    end
    if C.Tab() == "pkg" then   -- ab 0.129: Zeilen der Pakete fuer das Haus hier
        if R.running then R.Stop(); return end
        R.forceMode = "pkgcheck"
        R.search = nil
        R.Start()
        return
    end
    if R.running then R.Stop(); return end
    local mode = C.Mode()
    if mode == "mgr" then
        R.forceMode = "mgronly"
    else
        R.forceMode = nil
        mod.db.radarScanMode = mode
    end
    R.search = nil
    R.Start()
end

function C.Build(c)
    local UI = Peon.UI
    local QC = ns.QuickChances
    C.checkButton = UI.Button(c, L.CH_CHECK_ALL, 130, function() mod:Call("Chancen", C.CheckAll) end)
    C.checkButton:SetPoint("TOPRIGHT", -2, -2)
    UI.SetTooltip(C.checkButton, function()
        if C.Tab() == "quick" then return { L.QC_RENEW, L.QC_RENEW_TIP } end
        if C.Tab() == "trade" or C.Tab() == "pkg" then return { L.CH_CHECK_ALL, L.TR_CHECK_TIP } end
        return { C.Tab() == "spec" and L.CH_CHECK_ALL or L.RADAR_START, L.CH_SCAN_TIP }
    end)
    C.modeDrop = UI.Dropdown(c, 140, C.MODES(), function() return C.Mode() end, function(v) C.SetMode(v) end)
    C.modeDrop:SetPoint("RIGHT", C.checkButton, "LEFT", -6, 0)
    if C.modeDrop.fallback then
        C.modeDrop:SetText(C.ModeText())
        C.modeDrop:SetScript("OnClick", function() C.NextMode() end)
    end
    -- ab 0.119: Schnellkauf: Pruefung anhalten und weiter (an der Stelle der Auswahl)
    C.pauseButton = UI.Button(c, L.QC_PAUSE, 140, function()
        if QC then mod:Call("Chancen", QC.SetPaused, not QC.paused) end
    end)
    C.pauseButton:SetPoint("RIGHT", C.checkButton, "LEFT", -6, 0)
    UI.SetTooltip(C.pauseButton, { L.QC_PAUSE, L.QC_PAUSE_TIP })
    C.settingsButton = UI.Button(c, L.SETTINGS_BUTTON, 110, function()
        if ns.Settings then mod:Call("Einstellungen", ns.Settings.Toggle, "chances") end
    end)
    C.settingsButton:SetPoint("RIGHT", C.modeDrop, "LEFT", -6, 0)
    -- ab 0.119: ausgeblendete Vorschlaege zurueckholen (nur zu sehen, wenn es welche gibt)
    C.unhideButton = UI.Button(c, L.QC_UNHIDE, 130, function()
        if QC then mod:Call("Chancen", QC.Unhide) end
    end)
    C.unhideButton:SetPoint("RIGHT", C.settingsButton, "LEFT", -6, 0)
    UI.SetTooltip(C.unhideButton, { L.QC_UNHIDE, L.QC_UNHIDE_TIP })
    C.status = UI.Text(c, "small", "")
    C.status:SetPoint("TOPLEFT", 8, -8)
    C.status:SetPoint("RIGHT", C.settingsButton, "LEFT", -12, 0)
    if C.status.SetWordWrap then C.status:SetWordWrap(false) end
    local p = UI.Panel(c, "list", true)
    p:SetPoint("TOPLEFT", 0, -62)
    p:SetPoint("BOTTOMRIGHT", 0, 0)
    C.panel = p
    local R = ns.Radar
    C.list = UI.Table(p, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
              format = function(v, r)
                  local isNew = r.newUntil and Now() < r.newUntil   -- ab 0.105: neue Treffer des Radars mit Punkt
                  return (isNew and ("|T" .. R.DOT .. ":10:10:0:0|t ") or "") .. tostring(v)
              end,
              color = function(r)
                  if r.state == "gone" or (r.d and r.d.cant) then return 0.5, 0.5, 0.5 end
                  return UI.QualityColor(r.quality or 1)
              end },
            -- ab 0.120 ohne Spalte Art (die Art steht im Tooltip)
            { key = "gain", title = L.RADAR_COL_GAIN, width = 160, align = "RIGHT",
              format = function(v, r) return ((r.state == "gone" or (r.d and r.d.cant)) and GREY or GREEN) .. Money(math.floor((v or 0) + 0.5)) .. "|r" end,
              sort = function(r) return -r.rank * 1e13 + (r.gain or 0) end },
            { key = "limit", title = L.CH_COL_LIMIT, width = 100, align = "RIGHT",
              format = function(v) return v and Money(v) or "" end },
            { key = "risk", title = L.RADAR_COL_RISK, width = 80, align = "RIGHT",
              format = function(v) return v and ((R.RISK_COLOR[v] or "") .. (L["RADAR_RISK_" .. v:upper()] or v) .. "|r") or "" end,
              sort = function(r) return ({ low = 1, mid = 2, high = 3 })[r.risk] or 9 end },
            { key = "state", title = L.CH_COL_STATE, width = 140, align = "RIGHT",
              format = function(_, r) return C.StateText(r) end,
              sort = function(r) return r.rank end },
        },
        sortKey = "gain", sortDesc = true, icon = true, empty = L.CH_EMPTY,
        onClick = function(r, button)
            if r.radar then
                if button == "RightButton" then ns.Go.Menu(r.d, C.panel) else mod:Call("Sprung", ns.Go.Focus, r.d) end
                return
            end
            mod:Call("Sprung", ns.Go.Focus, { key = r.key, name = r.name, from = "chances" })
        end,
        onEnter = function(row, r)
            if not r then return end
            if r.radar then R.RowTooltip(row, r.d) else C.RowTooltip(row, r) end
        end,
    })
    -- ab 0.119: Liste Schnellkauf (eigene Spalten)
    local qp = UI.Panel(c, "list", true)
    qp:SetPoint("TOPLEFT", 0, -62)
    qp:SetPoint("BOTTOMRIGHT", 0, 0)
    C.qpanel = qp
    C.qlist = UI.Table(qp, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
              color = function(r)
                  if r.class == "low" then return 0.5, 0.5, 0.5 end
                  return UI.QualityColor(r.quality or 1)
              end },
            { key = "min", title = L.QC_COL_MIN, width = 90, align = "RIGHT", format = function(v) return v and Money(v) or "" end },
            { key = "qty", title = L.QC_COL_QTY, width = 66, align = "RIGHT", format = function(v) return v and tostring(v) or "" end },
            { key = "flow", title = L.QC_COL_FLOW, width = 92, align = "RIGHT",
              format = function(_, r)
                  if not r.v then return GREY .. "-|r" end
                  return QC.Rate(r.v.inPerMin) .. " / " .. QC.Rate(r.v.outPerMin)
              end,
              sort = function(r) return r.v and (r.v.inPerMin + r.v.outPerMin) or -1 end },
            { key = "move", title = L.QC_COL_MOVE, width = 90, align = "RIGHT",
              format = function(_, r) return QC.MoveText(r.v) end,
              -- ab 0.122: bei gleicher Bewegung mehr Einbrueche je Std. weiter oben
              sort = function(r) return r.rank * 1e6 - (r.dips or 0) * 1e3 - (r.ev or 0) end },
            -- ab 0.122: Gelegenheiten langfristig (QuickStats.lua)
            { key = "dips", title = L.QS_COL, width = 74, align = "RIGHT",
              format = function(_, r) return ns.QuickStats.Cell(r.key) end },
            { key = "baits", title = L.QC_COL_BAITS, width = 80, align = "RIGHT",
              format = function(v) return (v and v > 0) and (GOLD .. tostring(v) .. "|r") or "" end },
            { key = "state", title = L.CH_COL_STATE, width = 110, align = "RIGHT",
              format = function(_, r) return QC.StateText(r.key) end,
              sort = function(r) return QC.QueuePos(r.key) or 99 end },
        },
        sortKey = "move", icon = true, empty = L.QC_EMPTY,
        rowBg = function(r) if r and r.running then return 1, 0.82, 0, 0.16 end end,
        onClick = function(r, button)
            if button == "RightButton" then ns.Go.Menu(r, C.qpanel); return end
            mod:Call("Sprung", ns.Go.Focus, { key = r.key, name = r.name, from = "chances", mode = "quick" })
        end,
        onEnter = function(row, r)   -- ab 0.131 der gemeinsame Weg (W.ShowItemTooltip)
            if not r then return end
            W.ShowItemTooltip(row, r.key, function(GT)
                GT:AddLine(L.CH_TAB_QUICK, 1, 0.82, 0)
                QC.TipLines(GT, r.key)
                GT:AddLine(QC.SourceText(), 0.6, 0.6, 0.6)
                GT:AddLine(L.QC_TIP_CLICK, 0.6, 0.6, 0.6)
            end)
        end,
    })
    -- ab 0.127: Liste Markttausch (Trade.lua)
    if ns.Trade then C.tpanel = ns.Trade.BuildList(c, -62) end
    if ns.Packages then C.kpanel = ns.Packages.BuildList(c, -62) end   -- ab 0.129
    -- ab 0.119: Unterreiter ueber der Liste
    local defs = { { "quick", L.CH_TAB_QUICK }, { "buyout", L.CH_TAB_BUYOUT }, { "spec", L.CH_TAB_SPEC }, { "trade", L.CH_TAB_TRADE }, { "pkg", L.CH_TAB_PKG } }   -- ab 0.140 Reihenfolge
    C.tabs = UI.TopTabs(c, defs, function(key) mod:Call("Chancen", C.SelectTab, key) end)
    C.LayoutTabs()
    C.tabs:Select(C.Tab())
end

-- ab 0.119: nur die eingeschalteten Unterreiter zeigen, nebeneinander ueber der Liste
-- ab 0.138: ist nur einer an (ohne Weitere Chancen nur Schnellkauf), entfaellt die Leiste ganz
function C.LayoutTabs()
    if not C.tabs then return end
    local prev, on = nil, 0
    for _, t in ipairs(C.tabs) do if C.TabOn(t.key) then on = on + 1 end end
    for _, t in ipairs(C.tabs) do
        t:ClearAllPoints()
        if on > 1 and C.TabOn(t.key) then
            if prev then t:SetPoint("LEFT", prev, "RIGHT", Peon.UI.TAB_GAP or 3, 0)
            else t:SetPoint("BOTTOMLEFT", C.panel, "TOPLEFT", 10, -2) end
            t:Show()
            prev = t
        else
            t:Hide()
        end
    end
end

-- ab 0.119: Unterreiter waehlen (Klick oder beim Aufbau)
function C.SelectTab(key)
    local changed = mod.db.chancesTab ~= key
    mod.db.chancesTab = key
    local R = ns.Radar
    if changed and R then
        if R.running then R.Stop() end
        R.search = nil
    end
    local tab = C.Tab()
    if C.panel then C.panel:SetShown(tab ~= "quick" and tab ~= "trade" and tab ~= "pkg") end
    if C.kpanel then C.kpanel:SetShown(tab == "pkg") end   -- ab 0.129
    if ns.Packages and ns.Packages.sellButton and tab ~= "pkg" and not (InCombatLockdown and InCombatLockdown()) then ns.Packages.sellButton:Hide() end
    if C.qpanel then C.qpanel:SetShown(tab == "quick") end
    if C.tpanel then C.tpanel:SetShown(tab == "trade") end   -- ab 0.127
    C.Refresh()
    if R and C.Shown() then R.Wake() end
end

function C.StatusText()
    local Sp, R = ns.Spec, ns.Radar
    local tab = C.Tab()
    local st
    if tab == "quick" then   -- ab 0.119
        local QC = ns.QuickChances
        local cur, total = QC.Progress()
        if QC.paused then st = ORANGE .. L.QC_PAUSED .. "|r"
        elseif cur and QC.Active() then
            local key = QC.run.key
            local name = ns.Data.ItemName(key, ns.Data.Lookup(key)) or tostring(key)
            st = GREEN .. L.QC_CHECKING:format(cur, total, name) .. "|r"
        else st = QC.SourceText() end
        local hidden = QC.HiddenCount()
        if hidden > 0 then st = st .. GREY .. L.CH_HIDDEN:format(hidden) .. "|r" end
        if not (ns.Scan.ahOpen and rawget(_G, "C_AuctionHouse")) then st = st .. "  " .. ORANGE .. L.ST_NOT_LIVE .. "|r" end
        return st
    end
    if tab == "trade" and ns.Trade then return ns.Trade.StatusText() end   -- ab 0.127
    if tab == "pkg" and ns.Packages then return ns.Packages.StatusText() end   -- ab 0.129
    local _, t = Sp.All()
    if tab == "buyout" and not (R.running and R.forceMode == "mgronly") and (R.running or ns.Scan.state) then
        return R.StatusText()   -- ab 0.105: Scan des Radars (enthaelt Erneuern und "nicht live")
    end
    if not t then
        st = ORANGE .. L.CH_NO_MANAGER .. "|r"
    else
        local age = math.max(0, time() - t)
        st = GREY .. L.CH_STAND:format(age < 3600 and L.SPEC_MIN:format(math.max(1, math.floor(age / 60))) or L.SPEC_HOURS:format(math.floor(age / 3600))) .. "|r"
        local hidden = C.HiddenCount()   -- ab 0.101
        if hidden > 0 then st = st .. GREY .. L.CH_HIDDEN:format(hidden) .. "|r" end
    end
    if R.running and R.forceMode == "mgronly" then
        local sc = R.search
        st = GREEN .. L.CH_CHECKING:format(sc and sc.done or 0, sc and #sc.keys or 0) .. "|r"
    elseif tab == "buyout" then
        -- ab 0.105: Stand der Treffer des Radars (letzter Komplettscan)
        local market = ns.Data.Market()
        local at = market and ns.Data.DataAt(market)
        if at then st = st .. "  " .. GREY .. L.RADAR_STAND:format(ns.Scan.Age(at)) .. "|r" end
    end
    if not (ns.Scan.ahOpen and rawget(_G, "C_AuctionHouse")) then st = st .. "  " .. ORANGE .. L.ST_NOT_LIVE .. "|r" end
    return st
end

function C.UpdateView()
    if not C.list then return end
    local R, QC = ns.Radar, ns.QuickChances
    local tab = C.Tab()
    C.status:SetText(C.StatusText())
    -- ab 0.105: ein Knopf fuer jede Auswahl, "Alle pruefen" fuer die Chancen des Managers, sonst "Radar-Scan"
    -- ab 0.119: je Unterreiter: Spekulation "Alle pruefen", Aufkauf mit Auswahl, Schnellkauf "Neu vorschlagen"
    local text
    if tab == "quick" then text = L.QC_RENEW
    elseif tab == "trade" then text = (R.running and R.forceMode == "trade") and L.RADAR_STOP or L.CH_CHECK_ALL   -- ab 0.127
    elseif tab == "pkg" then text = (R.running and R.forceMode == "pkgcheck") and L.RADAR_STOP or L.CH_CHECK_ALL   -- ab 0.129
    elseif R.running then text = L.RADAR_STOP
    else text = C.Mode() == "mgr" and L.CH_CHECK_ALL or L.RADAR_START end
    C.checkButton:SetText(text)
    if tab == "quick" or (ns.Scan.ahOpen and not ns.Scan.state) then C.checkButton:Enable() else C.checkButton:Disable() end
    C.modeDrop:SetShown(tab == "buyout")
    C.pauseButton:SetShown(tab == "quick")
    C.pauseButton:SetText(QC and QC.paused and L.QC_RESUME or L.QC_PAUSE)
    local hidden = tab == "quick" and QC and QC.HiddenCount() or 0
    C.unhideButton:SetShown(hidden > 0)
    if hidden > 0 then C.unhideButton:SetText(L.QC_UNHIDE_N:format(hidden)) end
    -- Statuszeile endet vor dem ersten sichtbaren Knopf
    C.settingsButton:ClearAllPoints()
    C.settingsButton:SetPoint("RIGHT", (tab == "spec" or tab == "trade" or tab == "pkg") and C.checkButton or C.modeDrop, "LEFT", -6, 0)
    C.status:ClearAllPoints()
    C.status:SetPoint("TOPLEFT", 8, -8)
    C.status:SetPoint("RIGHT", hidden > 0 and C.unhideButton or C.settingsButton, "LEFT", -12, 0)
end

function C.Refresh()
    if C.list and C.Shown() then
        local tab = C.Tab()
        if tab == "quick" then
            local QC = ns.QuickChances
            -- neu sortieren nur nach einer fertigen Pruefung, sonst springen die Zeilen unter der Maus
            local resort = C.qStamp ~= QC.sortStamp
            C.qStamp = QC.sortStamp
            W.FillTable(C.qlist, QC.Rows(), resort)
        elseif tab == "pkg" then   -- ab 0.129
            if ns.Packages then ns.Packages.Refresh() end
        elseif tab == "trade" then   -- ab 0.127
            if ns.Trade then ns.Trade.Refresh(C.tStamp ~= ns.Trade.stamp) end
            C.tStamp = ns.Trade and ns.Trade.stamp
        else
            C.list:SetData(C.TabRows(tab))
        end
    end
    C.UpdateView()
    C.UpdateTabBadges()
end

-- ab 0.101: gerade Verworfenes steht beim naechsten Oeffnen nicht mehr da (Reiter verlassen, Auktionshaus neu offen)
function C.Leave()
    C.goneNow = {}
    C.Prune()
end

function C.Open()
    C.blink = false   -- ab 0.105: geoeffnet, die Zahl blinkt nicht mehr
    if ns.Radar then ns.Radar.LoadIfStale() end
    C.LayoutTabs()
    if C.tabs and C.tabs.selected ~= C.Tab() then C.tabs:Select(C.Tab()); return end
    C.Refresh()
    if ns.Radar then ns.Radar.Wake() end
end

---------------------------------------------------------------------------
-- Hinweise: beim Oeffnen des Auktionshauses und wenn ein guenstiges Fenster beginnt
---------------------------------------------------------------------------
function C.OnAHShow()
    C.Leave()
    C.UpdateBadge()
    if mod.db.chancesAhNote == false or not C.More() then return end   -- ab 0.138 nur mit Weitere Chancen
    local n = #C.Keys("all")
    if n > 0 then mod:Print(L.CH_AH_NOTE:format(n)) end
end

function C.Tick()
    C.UpdateBadge()   -- Muster: Zeitfenster beginnt oder endet
    if mod.db.chancesNotify == false or not C.More() or not C.KindOn("m") or not ns.Spec then return end
    local D = ns.Data
    local d = date("*t")
    local stamp = ("%d-%d-%d-%d"):format(d.year, d.month, d.day, math.floor(d.hour / 3))
    for key, x in pairs(ns.Spec.All()) do
        if x.mk == "m" and x.buyWin and C.InWindow(x.buyWin) and not C.notified[tostring(key) .. stamp] then
            C.notified[tostring(key) .. stamp] = true
            local name = D.ItemName(key, D.Market() and D.Market().items[key]) or tostring(key)
            mod:Print(L.CH_WINDOW_NOTE:format(name, Money(x.limit or 0), C.WindowText(x.sellWin)))
        end
    end
end

function C.Init()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function() mod:Call("Chancen", C.OnAHShow) end)
    mod:On("CHANGED", function(key)   -- ab 0.97: Zahl am Reiter umgestellt (Optionen)
        if type(key) == "string" and key:sub(1, 5) == "badge" and ns.AHTabs then mod:Call("Zahl am Reiter", ns.AHTabs.RefreshBadges) end
    end)
    if C_Timer and C_Timer.NewTicker then
        C.ticker = C_Timer.NewTicker(60, function() mod:Call("Chancen", C.Tick) end)
    end
end

W.pages.chances = {
    build = C.Build,
    refresh = function() C.Open() end,
    leave = function()
        C.Leave()
        if ns.Radar then ns.Radar.Halt() end
    end,
}
