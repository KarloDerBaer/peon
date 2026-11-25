-- Peon_Broker - WatchPage.lua
-- Ab 0.82 (KarloDerBaer, 12.11.2026): eigener Reiter "Beobachten" (vorher besondere Liste in Einkaufen).
-- Passt zur Logik von Beobachtung und Fokus: je Gegenstand "Kaufen bis" (Grenze nach unten, Preisalarm) und
-- "Zielpreis" (der Preis, ab dem man verkaufen wuerde, Grenze nach oben, Meldung wenn der Preis darueber liegt).
-- Beides setzt man am einfachsten im Fokus und speichert es dort mit "Speichern".
--   Liste   Gegenstand, Preis (guenstigstes Angebot), Kaufen bis, Zielpreis, Ueblich, Rat (KAUFEN / VERKAUFEN)
--   Klick   waehlt (ab 0.83), Doppelklick in den Fokus mit den gespeicherten Werten (Art "Beobachten"), Rechtsklick Menue
--   unten   Haken Warnung (ab 0.83), Verkaufen (ab 0.83, sicherer Knopf), Im Markt zeigen (sicherer Knopf), Entfernen
-- Daten aus Watch.lua (PeonBrokerDB.watch: lim/pct = Kaufen bis, up = Zielpreis).
-- Ab 0.83 (KarloDerBaer, 12.11.2026): Am Auktionator fragt Broker alle Eintraege reihum laufend ab (Radar.lua,
-- R.NextWatch), solange der Reiter offen ist. Spalte "Stand", rechts oben "Aktualisiert laufend" mit wanderndem Punkt.
-- Eine Zeile leuchtet nur kurz auf, wenn sich ihr Rat aendert (jetzt KAUFEN oder VERKAUFEN). Haken unten links schaltet
-- die Warnung (Chat und Ton) ab (watchAlarm). Laufende Antworten tauschen die Daten der Liste nicht aus, sondern
-- fuellen die Zeilen neu: Ein Austausch zwischen Druecken und Loslassen der Maustaste verschluckte sonst den Klick.
-- Ab 0.106 (KarloDerBaer 19.11.2026): Spalte "Art" (Aufkauf oder Schnellkauf, zuletzt im Fokus gespeichert). Kaufen bis
-- zeigt den Wert dieser Art, der Zielpreis gilt nur im Aufkauf. Doppelklick oeffnet den Fokus in dieser Art. Die Spalte
-- "Stand" entfaellt, oben rechts steht ohne laufende Abfrage, wann zuletzt ein Gegenstand abgefragt wurde.
-- Ab 0.119 (Konzept Peon_Broker_Chancen_Schnellkauf.md, KarloDerBaer 19.11.2026): zwei Unterreiter statt der Spalte Art.
-- Ab 0.126 (KarloDerBaer 20.11.2026): Schnellkauf ohne Rat, Bewegung als Ampel (gespeichert), dazu Treffer und
-- Einbrueche im Zeitraum (quickStatDays) und der Tiefstpreis der letzten 24 Std. (QuickStats.lua).
-- Ab 0.128 (KarloDerBaer 20.11.2026, Konzept Peon_Broker_Marktvergleich.md 10.3): dritter Unterreiter Markttausch.
-- Ab 0.135 (U3, Konzept Peon_Broker_Schlank.md 6, KarloDerBaer 24.11.2026): eine Liste statt drei Unterreitern.
--   Gegenstand (bei Markttausch mit Hinweis Neutral), Guenstigster, Kaufen bis (des Einkaufens), Glocke,
--   Treffer 7 T. und Einbrueche 7 T. (je Stunde beobachteter Zeit, QuickStats.lua), Jetzt (Treffer seit Beginn der
--   Sitzung am Auktionshaus, Punkt gruen ueber und rot unter dem Wert der 7 Tage, grau unter 10 Min.).
-- Darunter, Bewegung, Tief 24 Std. und die Werte des Markttauschs stehen im Tooltip. Zielpreis und Rat VERKAUFEN gibt
-- es nur noch mit eingeschaltetem Aufkauf (focusBuyout). Laufend geprueft wird die ganze Liste mit der Pruefung der
-- Marktbewegung (QuickChances.lua, Quelle "watch"). Der Knopf Im Markt zeigen entfaellt (Rechtsklick-Menue).
-- Gespeicherte Werte je Modus (watch, qmax, mode, bon, qon, ton, watchTab) bleiben erhalten.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local P = {}
ns.WatchPage = P

local GREY, GREEN = "|cff999999", "|cff60e060"
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end
local function Now() return GetTime and GetTime() or time() end
local function BuyoutOn() return ns.Quick ~= nil and ns.Quick.BuyoutOn ~= nil and ns.Quick.BuyoutOn() end

-- ab 0.135 (U3): nur noch eine Liste. Bleibt fuer Aufrufer, die nach dem Unterreiter fragen.
function P.Tab() return "all" end

-- Reiter Beobachten zu sehen? (wie Focus.Shown)
function P.Shown()
    local T = ns.AHTabs
    if T and T.current == "watch" then return true end
    if T and T.host and T.host.watch == "ah" then return false end
    return W.IsOpen() and W.current == "watch"
end

-- Stand einer Zeile: Sekunden seit der letzten Antwort (nil = in dieser Sitzung nicht live abgefragt)
function P.Age(key)
    local at = ns.Radar and ns.Radar.watchAt and ns.Radar.watchAt[key]
    if not at then return nil end
    return math.max(0, Now() - at)
end

function P.AgeText(sec)
    if not Num(sec) then return GREY .. "-|r" end
    if sec < 3 then return GREEN .. L.WATCH_AGE_NOW .. "|r" end
    if sec < 60 then return L.WATCH_AGE_SEC:format(math.floor(sec)) end
    return L.AGE_MIN:format(math.floor(sec / 60))
end

-- Zeile rechts oben: laeuft die Pruefung? Die Punkte wandern (. .. ...) mit P.Tick
P.dots = 1
function P.LiveText()
    local R = ns.Radar
    local QC = ns.QuickChances
    if QC and QC.run and QC.Active() then
        local key = QC.run.key
        local name = ns.Data.ItemName(key, ns.Data.Lookup(key)) or tostring(key)
        return GREEN .. L.WATCH_QC_LIVE:format(name, QC.run.got, QC.Probes()) .. ("."):rep(P.dots) .. "|r"
    end
    if R and R.Watching and R.Watching() then
        return GREEN .. L.WATCH_LIVE .. ("."):rep(P.dots) .. "|r"
    end
    -- ab 0.106: juengste Einzelabfrage eines beobachteten Gegenstands (auch aus dem Einkaufen oder Chancen)
    local last
    for key in pairs(ns.Watch.Store()) do
        local a = P.Age(key)
        if a and (not last or a < last) then last = a end
    end
    if last then return GREY .. L.WATCH_LAST:format(R.ShortAge(last)) .. "|r" end
    return GREY .. L.WATCH_OFF .. "|r"
end

-- Takt fuer die Punkte, solange die Seite zu sehen ist
P.TICK = 0.4
function P.Tick()
    P.ticking = false
    if not (P.live and P.Shown()) then return end
    P.dots = P.dots % 3 + 1
    P.live:SetText(P.LiveText())
    P.StartTick()
end

function P.StartTick()
    if P.ticking or not (C_Timer and C_Timer.After) then return end
    P.ticking = true
    C_Timer.After(P.TICK, function() mod:Call("Beobachten", P.Tick) end)
end

-- Kurz aufleuchten, wenn sich der Rat einer Zeile aendert (neu KAUFEN oder VERKAUFEN)
P.FLASH = 1.5
P.flash, P.lastAdvice = {}, {}
function P.Flash(rows)
    local now = Now()
    for _, r in ipairs(rows) do
        local fk = r.key
        local before = P.lastAdvice[fk]
        if r.advice and before ~= nil and r.advice ~= before then P.flash[fk] = { untl = now + P.FLASH, kind = r.advice } end
        P.lastAdvice[fk] = r.advice or false
        local f = P.flash[fk]
        r.flash = f and f.untl > now and f.kind or nil
        if f and f.untl <= now then P.flash[fk] = nil end
    end
end

-- ab 0.92: Symbol der Warnung je Gegenstand (Blizzards Lautsprecher aus dem Sprachchat, Zweig forever)
P.BELL_ON = "|A:voicechat-icon-speaker:16:16|a"
P.BELL_OFF = "|A:voicechat-icon-speaker-mute:16:16|a"
P.BELL_W = 36
P.BELL_COL = { Down = 4 }   -- Platz der Spalte in der Tabelle (hinter Kaufen bis)

function P.BellColumn(dir)
    local f = "mute" .. dir
    return { key = f, title = P.BELL_ON, width = P.BELL_W, align = "CENTER",
             format = function(v) return v and P.BELL_OFF or P.BELL_ON end,
             sort = function(r) return r[f] and 1 or 0 end }
end

-- Ueber welcher Symbolspalte steht die Maus? "Down" oder nil. Die Tabelle meldet nur die Zeile, darum ueber
-- die Spaltenkoepfe.
function P.OverBell()
    if not GetCursorPosition then return nil end
    for dir, i in pairs(P.BELL_COL) do
        local h = P.list and P.list.heads and P.list.heads[i]
        local left, right = h and h.GetLeft and h:GetLeft(), h and h.GetRight and h:GetRight()
        local scale = h and h.GetEffectiveScale and h:GetEffectiveScale() or 1
        local x = GetCursorPosition()
        if left and right and x and scale > 0 and x / scale >= left and x / scale <= right then return dir end
    end
    return nil
end

-- Kaufen bis einer Zeile: der Wert des Einkaufens (qlim). Mit eingeschaltetem Aufkauf ohne qlim der Wert des Aufkaufs.
function P.Limit(key, w, e)
    if Num(w.qlim) then return w.qlim end
    if BuyoutOn() then return ns.Watch.Limit(key, e) end
    return nil
end

-- Zeilen der Liste: jeder beobachtete Gegenstand einmal (ab 0.135)
function P.Rows()
    local rows = {}
    for key, w in pairs(ns.Watch.Store()) do rows[#rows + 1] = P.Row(key, w) end
    return rows
end

function P.Row(key, w)
    local D = ns.Data
    local e = D.Lookup(key)
    local r = {
        key = key, name = w.name or D.ItemName(key, e) or tostring(key), quality = w.q or (type(e) == "table" and e.ql) or nil,
        icon = w.icon or ns.Buy.Icon(D.ItemID(key)), link = D.LinkFromKey and D.LinkFromKey(key) or nil,
        price = type(e) == "table" and not e.gone and Num(e.m) and e.m or nil,
        age = P.Age(key),
        muteDown = w.muteDown == true,
        neutral = w.ton == true,
    }
    r.limit = P.Limit(key, w, e)
    if r.price and r.limit and r.price <= r.limit then r.advice = "buy" end
    -- Zielpreis nur mit eingeschaltetem Aufkauf (ruht sonst, Konzept 6.2)
    r.target = Num(w.up) and w.up or nil
    if BuyoutOn() and not r.advice and r.price and r.target and r.price >= r.target then r.advice = "sell" end
    -- Treffer und Einbrueche je Stunde im Zeitraum, Jetzt seit Beginn der Sitzung
    local QS = ns.QuickStats
    local st = QS.Get(key)
    local lim = QS.Limit(key)
    r.sure = st ~= nil and st.sure or false
    r.dipsH = st and st.secs > 0 and st.perHour or nil
    r.hitsH = st and st.secs > 0 and lim and st.hitsPerHour or nil
    local n = QS.Now(key)
    r.nowHits = n and lim and n.hits or nil
    r.trend = QS.Trend(key)
    local QC = ns.QuickChances
    r.running = QC ~= nil and QC.run ~= nil and QC.run.key == key
    return r
end

-- Stueck unter Kaufen bis aus der letzten Abfrage (Tooltip)
function P.Under(key, limit)
    local live = ns.Buy.live[key]
    if not (limit and type(live) == "table" and type(live.rows) == "table") then return nil end
    local q = 0
    for _, l in ipairs(ns.Data.Available(live.rows)) do
        if Num(l.price) and l.price <= limit and Num(l.qty) then q = q + l.qty end
    end
    return q
end

-- ab 0.126: Zelle fuer Anzahlen: grau "-" ohne Wert, gruen ab 1
function P.CountCell(v)
    if not Num(v) then return GREY .. "-|r" end
    return (v > 0 and GREEN or GREY) .. tostring(v) .. "|r"
end

-- ab 0.135: Zelle je Stunde. Unter 30 Min. Beobachtung im Zeitraum (QS.SURE) grau, ohne Wert "-"
function P.RateCell(v, r)
    if not Num(v) then return GREY .. "-|r" end
    local t = ns.QuickStats.Rate(v)
    if not (r and r.sure) or v <= 0 then return GREY .. t .. "|r" end
    return t
end

-- ab 0.135: Zelle Jetzt: Treffer der Sitzung mit Punkt
function P.NowCell(v, r)
    local dot = ns.QuickStats.Dot(r and r.trend)
    if not Num(v) then return dot .. " " .. GREY .. "-|r" end
    return dot .. " " .. (v > 0 and tostring(v) or (GREY .. tostring(v) .. "|r"))
end

-- Zahl am Reiter: Gegenstaende mit Rat KAUFEN oder VERKAUFEN
-- ab 0.97: only = "buy" oder "sell" zaehlt nur diese Richtung
function P.Count(only)
    local n = 0
    for _, r in ipairs(P.Rows()) do if r.advice and (only == nil or r.advice == only) then n = n + 1 end end
    return n
end

function P.UpdateBadge()
    local T = ns.AHTabs
    if not (T and T.SetBadge and T.built) then return end
    local mode = T.BadgeMode and T.BadgeMode("watch") or "both"   -- ab 0.97 einstellbar
    if mode == "off" then T.SetBadge("watch", nil) return end
    T.SetBadge("watch", P.Count(mode ~= "both" and mode or nil), false)
end

-- Spalten der Liste (ab 0.135 eine fuer alle)
function P.Columns()
    local UI = Peon.UI
    local function Price(v) return Num(v) and Money(v) or (GREY .. "-|r") end
    local days = ns.QuickStats.Days()
    return {
        { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
          color = function(r) return UI.QualityColor(r.quality or 1) end,
          format = function(v, r) return (r and r.neutral) and (tostring(v) .. " " .. GREY .. L.WATCH_NEUTRAL .. "|r") or v end },
        { key = "price", title = L.QC_COL_MIN, width = 90, align = "RIGHT", format = Price },
        { key = "limit", title = L.FOCUS_R_LIMIT, width = 90, align = "RIGHT", format = Price },
        P.BellColumn("Down"),
        { key = "hitsH", title = L.WATCH_COL_HITS_D:format(days), width = 84, align = "RIGHT", format = P.RateCell,
          sort = function(r) return r.hitsH or -1 end },
        { key = "dipsH", title = L.WATCH_COL_DIPS_D:format(days), width = 100, align = "RIGHT", format = P.RateCell,
          sort = function(r) return r.dipsH or -1 end },
        { key = "nowHits", title = L.WATCH_COL_NOW, width = 64, align = "RIGHT", format = P.NowCell,
          sort = function(r) return r.nowHits or -1 end },
    }
end

function P.Build(c)
    local UI = Peon.UI
    P.frame = c
    P.hint = UI.Text(c, "small", GREY .. L.WATCH_HINT .. "|r", 380)
    P.hint:SetPoint("TOPLEFT", 4, -10)
    P.live = UI.Text(c, "small", "", 320)
    P.live:SetJustifyH("RIGHT")
    P.live:SetPoint("TOPRIGHT", -4, -10)
    local lp = UI.Panel(c, "list", true)
    lp:SetPoint("TOPLEFT", 0, -34)
    lp:SetPoint("BOTTOMRIGHT", 0, 34)
    P.panel = lp
    P.days = ns.QuickStats.Days()
    local list = UI.Table(lp, {
        columns = P.Columns(),
        sortKey = "name", icon = true, empty = L.WATCH_EMPTY,
        rowBg = function(r)   -- ab 0.83: kurz aufleuchten bei neuem Rat (Kern API 19)
            if r and r.flash == "buy" then return 0.38, 0.88, 0.38, 0.28 end
            if r and r.flash == "sell" then return 1, 0.82, 0, 0.28 end
            if r and r.running then return 1, 0.82, 0, 0.16 end   -- ab 0.119: Pruefung laeuft
        end,
        -- ab 0.83 (KarloDerBaer): Klick waehlt (fuer die Knoepfe unten), Doppelklick oeffnet das Einkaufen, Rechtsklick das Menue
        onClick = function(r, button)
            -- ab 0.92: Klick auf das Symbol schaltet die Warnung, sonst nichts
            local bell = button == "LeftButton" and P.OverBell() or nil
            if bell then
                P.clickKey = nil
                ns.Watch.ToggleMute(r.key, bell)
                r["mute" .. bell] = ns.Watch.Muted(r.key, bell)
                if P.list and P.list.list then P.list.list:Refresh() end
                return
            end
            P.selected = r
            P.UpdateButtons()
            if button == "RightButton" then P.clickKey = nil; ns.Go.Menu(r, P.panel); return end
            local now = GetTime and GetTime() or 0
            if P.clickKey == r.key and now - (P.clickT or 0) <= (ns.Go.DOUBLE or 0.4) then
                P.clickKey = nil
                -- ab 0.135 im Einkaufen, mit eingeschaltetem Aufkauf im zuletzt gespeicherten Modus
                local mode = BuyoutOn() and ns.Watch.Mode(r.key) or "quick"
                mod:Call("Sprung", ns.Go.Focus, { key = r.key, name = r.name, from = "watch", mode = mode })
                return
            end
            P.clickKey, P.clickT = r.key, now
        end,
        onEnter = function(row, r)
            if not r then return end
            local bell = P.OverBell()
            if bell and GameTooltip then
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                GameTooltip:SetText(r["mute" .. bell] and L.WATCH_BELL_OFF or L.WATCH_BELL_ON, 1, 0.82, 0)
                GameTooltip:AddLine(L["WATCH_BELL_TIP_" .. bell:upper()], 1, 1, 1, true)
                GameTooltip:Show()
                return
            end
            P.RowTooltip(row, r)
        end,
    })
    function list:GetItems() return self.items end
    P.list = list
    P.removeButton = UI.Button(c, L.WATCH_REMOVE, 130, function()
        if P.selected then ns.Watch.Remove(P.selected.key); P.selected = nil; P.Refresh() end
    end)
    P.removeButton:SetPoint("BOTTOMRIGHT", -2, 4)
    -- ab 0.83: Warnung (Chat und Ton) an oder aus
    P.alarmCheck = UI.Check(c, L.WATCH_ALARM_CHECK, mod.db.watchAlarm ~= false, function(on) mod.db.watchAlarm = on end,
        { L.WATCH_ALARM_CHECK, L.WATCH_ALARM_TIP })
    P.alarmCheck:SetPoint("BOTTOMLEFT", 0, 0)
    -- ab 0.91 (Fehlerbericht 20): Einstellungen der Warnung (Ton und Chat je Richtung). Ton je Gegenstand: Rechtsklick
    P.settingsButton = UI.Button(c, L.SETTINGS_BUTTON, 110, function()
        if ns.Settings then mod:Call("Einstellungen", ns.Settings.Toggle, "watch") end
    end)
    P.settingsButton:SetPoint("BOTTOMLEFT", 150, 4)
    UI.SetTooltip(P.settingsButton, { L.SET_WATCH_TITLE, L.SET_WATCH_BUTTON_TIP })
    -- ab 0.83: Verkaufen. Sicherer Knopf wie "Ins Verkaufsfenster legen" (Lots.lua): Makro "/click <Taschenplatz> RightButton",
    -- derselbe Klick wie der Rechtsklick in der Tasche. Blizzards Code wechselt auf Verkaufen und legt den Gegenstand hinein,
    -- Broker schaltet nichts selbst um (Fehlerberichte 10 und 11). Vorher blendet Broker seinen Reiter aus (eigene Flaeche).
    local sb = CreateFrame("Button", "PeonBrokerWatchSellButton", c, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    sb:SetSize(110, 22)
    sb:SetPoint("RIGHT", P.removeButton, "LEFT", -6, 0)
    if sb.RegisterForClicks then sb:RegisterForClicks("AnyUp", "AnyDown") end
    sb:SetText(L.WATCH_SELL)
    sb:HookScript("PreClick", function()
        local T = ns.AHTabs
        if T and T.current and T.Close then mod:Call("Verkaufen", T.Close) end
    end)
    UI.SetTooltip(sb, function() return { L.WATCH_SELL, P.sellWhy or L.WATCH_SELL_TIP } end)
    P.sellButton = sb
    P.Refresh()
end

-- ab 0.135: Tooltip einer Zeile: Gegenstand wie ueberall in Broker, darunter Jetzt (Treffer, Einbrueche), Darunter,
-- dann Bewegung mit Zufluss und Abfluss und die Werte des Zeitraums (QuickChances.TipLines mit QuickStats.TipLines),
-- bei Markttausch beide Haeuser
function P.RowTooltip(row, r)
    local w = ns.Watch.Store()[r.key] or {}
    local QS = ns.QuickStats
    W.ShowItemTooltip(row, r.key, function(GT)
        local lim = QS.Limit(r.key)
        GT:AddLine(L.WATCH_TIP_NOW_HEAD, 1, 0.82, 0)
        local n = QS.Now(r.key)
        if not n then
            GT:AddLine(L.WATCH_TIP_NOW_NONE, 0.7, 0.7, 0.7, true)
        else
            GT:AddLine(L.WATCH_TIP_NOW_TIME:format(QS.Span(n.secs)), 0.85, 0.85, 0.85, true)
            if lim then
                local v = QS.Get(r.key)
                GT:AddLine(L.WATCH_TIP_NOW_HITS:format(n.hits, QS.Rate(n.hitsPerHour), QS.Days(),
                    QS.Rate(v and v.hitsPerHour or 0)), 0.85, 0.85, 0.85, true)
            end
            GT:AddLine(L.WATCH_TIP_NOW_DIPS:format(n.dips, QS.Rate(n.perHour)), 0.85, 0.85, 0.85, true)
        end
        if not lim then GT:AddLine(L.WATCH_TIP_NO_LIMIT, 0.7, 0.7, 0.7, true) end
        GT:AddLine(L.WATCH_TIP_NOW_RULE:format(QS.Days()), 0.6, 0.6, 0.6, true)
        local under = P.Under(r.key, r.limit)
        if under then GT:AddLine(L.WATCH_TIP_UNDER:format(under), 0.85, 0.85, 0.85, true) end
        GT:AddLine(" ")
        if ns.QuickChances then ns.QuickChances.TipLines(GT, r.key) end
        if w.qskip then GT:AddLine(L.QUICK_SKIP, 0.85, 0.85, 0.85) end
        if w.qavg then GT:AddLine(L.WATCH_TIP_QAVG, 0.85, 0.85, 0.85) end
        if BuyoutOn() and r.target then GT:AddLine(L.WATCH_TIP_TARGET:format(Money(r.target)), 0.85, 0.85, 0.85) end
        if r.neutral and ns.Pages then P.TradeLines(GT, r.key) end
        GT:AddLine(L.WATCH_TIP_DOUBLE, 0.6, 0.6, 0.6)
    end)
end

-- ab 0.135: Werte des Markttauschs im Tooltip (vorher eigener Unterreiter): beide Haeuser, Richtung, Spanne, Absatz
-- im Ziel und Zustand am Haus hier
function P.TradeLines(GT, key)
    local D, G, T = ns.Data, ns.Pages, ns.Trade
    local hk, nk = ns.HomeMarketKey(), ns.NeutralMarketKey()
    local function Price(market)
        local m = D.Markets()[market]
        local e = type(m) == "table" and m.items and m.items[key]
        if type(e) ~= "table" or e.gone or not Num(e.m) or e.m <= 0 then return nil end
        return e.m
    end
    local home, neutral = Price(hk), Price(nk)
    GT:AddLine(" ")
    GT:AddLine(L.CH_TAB_TRADE, 1, 0.82, 0)
    for _, x in ipairs({ { hk, home }, { nk, neutral } }) do
        GT:AddDoubleLine(G.MarketLabel(x[1]), x[2] and Money(x[2]) or L.PG_MISSING, 0.85, 0.85, 0.85, 1, 1, 1)
    end
    if not (home and neutral and T) then return end
    local pct, dir = G.Spread(home, neutral, G.CutOf(hk), G.CutOf(nk))
    local d = dir == "neutral" and "n" or dir == "home" and "h" or nil
    if not d then return end
    GT:AddLine(L.WATCH_TIP_TRADE:format(T.DirText(d), tostring(pct), G.FmtSales(G.SalesPerDay(key, d == "n" and nk or hk))), 0.6, 0.9, 1, true)
    local _, text = T.State({ key = key, dir = d, buy = d == "n" and home or neutral, sell = d == "n" and neutral or home })
    if text then GT:AddLine(text, 0.85, 0.85, 0.85, true) end
end

local function InCombat() return InCombatLockdown and InCombatLockdown() or false end

-- Knopf Verkaufen auf den Taschenplatz des gewaehlten Gegenstands richten (nur ausserhalb des Kampfs)
function P.UpdateSell()
    local b = P.sellButton
    if not b or InCombat() then return end
    local LT, r = ns.Lots, P.selected
    local name, why
    if not r then why = L.WATCH_SELL_PICK
    elseif not (ns.Window.AtAH and ns.Window.AtAH()) then why = L.WATCH_SELL_AH
    else
        local bag, slot
        if LT then bag, slot = LT.FindBagSlot(r.key) end
        if not bag then why = L.WATCH_SELL_BAG
        else
            name = LT.FindButton(bag, slot)
            if not name then why = L.LOTS_NO_SLOT end
        end
    end
    if name then
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", "/click " .. name .. " RightButton")
        b:Enable()
    else
        b:SetAttribute("type", nil)
        b:SetAttribute("macrotext", nil)
        b:Disable()
    end
    P.sellWhy = why
end

function P.UpdateButtons()
    if not P.removeButton then return end
    if P.selected then P.removeButton:Enable() else P.removeButton:Disable() end
    P.UpdateSell()
end

function P.Refresh()
    P.UpdateBadge()
    if ns.Side and ns.Side.Tab() == "watch" then ns.Side.Refresh() end   -- ab 0.137 (U5)
    if not P.list then return end
    if P.Shown() and ns.Radar and ns.Radar.Wake then ns.Radar.Wake() end   -- ab 0.83: laufend abfragen
    if P.live then P.live:SetText(P.LiveText()) end
    if P.Shown() then P.StartTick() end
    if P.alarmCheck then P.alarmCheck:SetChecked(mod.db.watchAlarm ~= false) end
    -- Spaltenkoepfe folgen dem eingestellten Zeitraum
    local days = ns.QuickStats.Days()
    if P.days ~= days then
        P.days = days
        local cols, heads = P.list.o and P.list.o.columns, P.list.heads
        for i, f in pairs({ [5] = L.WATCH_COL_HITS_D, [6] = L.WATCH_COL_DIPS_D }) do
            if cols and cols[i] then cols[i].title = f:format(days) end
            local h = heads and heads[i]
            if h and h.SetText then h:SetText(f:format(days)) end
        end
    end
    local rows = P.Rows()
    P.Flash(rows)
    -- ab 0.83: gleiche Gegenstaende: Werte in die vorhandenen Zeilen, nur neu fuellen (kein Austausch, kein verlorener Klick)
    -- ab 0.119 ueber Window.FillTable. Neu sortiert wird, wenn eine Pruefung fertig ist.
    local resort = false
    if ns.QuickChances then
        resort = P.qStamp ~= ns.QuickChances.sortStamp
        P.qStamp = ns.QuickChances.sortStamp
    end
    rows = W.FillTable(P.list, rows, resort)
    -- Aufleuchten wieder ausblenden, auch ohne laufende Antworten
    local fl = false
    for _, r in ipairs(rows) do if r.flash then fl = true end end
    if fl and C_Timer and C_Timer.After and not P.flashTimer then
        P.flashTimer = true
        C_Timer.After(P.FLASH + 0.1, function() P.flashTimer = nil; mod:Call("Beobachten", P.Refresh) end)
    end
    local keep
    for _, r in ipairs(rows) do if P.selected and r.key == P.selected.key then keep = r end end
    P.selected = keep
    P.UpdateButtons()
end

W.pages.watch = {
    build = P.Build,
    refresh = function() P.Refresh() end,
}
