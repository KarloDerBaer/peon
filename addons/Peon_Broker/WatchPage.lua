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
--   Aufkauf      Preis, Kaufen bis, Glocke, Zielpreis, Glocke, Rat (Werte des Aufkaufs)
--   Schnellkauf  Guenstigster, Kaufen bis, Glocke, darunter (Stueck unter Kaufen bis), Bewegung, Gekauft, Rat
-- Ein Gegenstand steht in jeder Liste, fuer die er Werte hat (Watch.InQuick, Watch.InBuyout). Laufend abgefragt wird
-- nur die offene Liste: Aufkauf wie bisher reihum (R.NextWatch), Schnellkauf mit der Pruefung der Marktbewegung
-- (QuickChances.lua). Doppelklick oeffnet den Fokus im Modus der Liste. Gemerkt wird der Unterreiter in watchTab.
-- Ab 0.126 (KarloDerBaer 20.11.2026): Schnellkauf ohne Rat, Bewegung als Ampel (gespeichert), dazu Treffer und
-- Einbrueche im Zeitraum (quickStatDays) und der Tiefstpreis der letzten 24 Std. (QuickStats.lua). Gekauft im Tooltip
-- ueber den Zeitraum statt nur fuer die Sitzung. Der Rat zaehlt weiter fuer die Zahl am Reiter und das Aufleuchten.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local P = {}
ns.WatchPage = P

local GREY, GREEN, GOLD = "|cff999999", "|cff60e060", "|cffffd100"
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end
local function Now() return GetTime and GetTime() or time() end

-- ab 0.119: offener Unterreiter ("buyout" oder "quick")
function P.Tab()
    return mod.db.watchTab == "quick" and "quick" or "buyout"
end

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

-- Zeile rechts oben: laeuft die Aktualisierung? Die Punkte wandern (. .. ...) mit P.Tick
P.dots = 1
function P.LiveText()
    local R = ns.Radar
    -- ab 0.119: Schnellkauf: Fortschritt der Pruefung
    local QC = ns.QuickChances
    if P.Tab() == "quick" and QC and QC.run and QC.Active() then
        local key = QC.run.key
        local name = ns.Data.ItemName(key, ns.Data.Lookup(key)) or tostring(key)
        return GREEN .. L.WATCH_QC_LIVE:format(name, QC.run.got, QC.Probes()) .. ("."):rep(P.dots) .. "|r"
    end
    if R and R.Watching and R.Watching() then
        return GREEN .. L.WATCH_LIVE .. ("."):rep(P.dots) .. "|r"
    end
    -- ab 0.106: juengste Einzelabfrage eines beobachteten Gegenstands (auch aus Fokus oder Chancen)
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
        local fk = tostring(r.mode) .. ":" .. tostring(r.key)   -- ab 0.119 je Unterreiter
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
P.BELL_COL = { Down = 4, Up = 6 }   -- Platz der Spalten in der Tabelle (hinter Kaufen bis und Zielpreis)
P.BELL_COLS = { buyout = P.BELL_COL, quick = { Down = 4 } }   -- ab 0.119 je Unterreiter

function P.BellColumn(dir)
    local f = "mute" .. dir
    return { key = f, title = P.BELL_ON, width = P.BELL_W, align = "CENTER",
             format = function(v) return v and P.BELL_OFF or P.BELL_ON end,
             sort = function(r) return r[f] and 1 or 0 end }
end

-- Ueber welcher Symbolspalte steht die Maus? "Down", "Up" oder nil. Die Tabelle meldet nur die Zeile, darum ueber
-- die Spaltenkoepfe.
function P.OverBell()
    if not GetCursorPosition then return nil end
    for dir, i in pairs(P.BELL_COLS[P.Tab()] or P.BELL_COL) do
        local h = P.list and P.list.heads and P.list.heads[i]
        local left, right = h and h.GetLeft and h:GetLeft(), h and h.GetRight and h:GetRight()
        local scale = h and h.GetEffectiveScale and h:GetEffectiveScale() or 1
        local x = GetCursorPosition()
        if left and right and x and scale > 0 and x / scale >= left and x / scale <= right then return dir end
    end
    return nil
end

-- Zeilen der Liste
-- Zeilen der Liste. ab 0.119: tab = "buyout" oder "quick" (ohne: der offene Unterreiter), "active" = jeder Gegenstand
-- einmal mit den Werten des zuletzt gespeicherten Modus (Zahl am Reiter, wie der Preisalarm)
function P.Rows(tab)
    local Wt, D = ns.Watch, ns.Data
    tab = tab or P.Tab()
    local rows = {}
    for key, w in pairs(Wt.Store()) do
        local mode
        if tab == "active" then mode = Wt.Mode(key)   -- ab 0.106
        elseif tab == "quick" then mode = Wt.InQuick(key) and "quick" or nil
        else mode = Wt.InBuyout(key) and "buyout" or nil end
        if mode then rows[#rows + 1] = mode == "quick" and P.QuickRow(key, w) or P.BuyoutRow(key, w) end
    end
    return rows
end

local function BaseRow(key, w, e)
    local D = ns.Data
    return {
        key = key, name = w.name or D.ItemName(key, e) or tostring(key), quality = w.q or (type(e) == "table" and e.ql) or nil,
        icon = w.icon or ns.Buy.Icon(D.ItemID(key)), link = D.LinkFromKey and D.LinkFromKey(key) or nil,
        price = type(e) == "table" and not e.gone and Num(e.m) and e.m or nil,
        age = P.Age(key),
        muteDown = w.muteDown == true,
        muteUp = w.muteUp == true,
    }
end

function P.BuyoutRow(key, w)
    local e = ns.Data.Lookup(key)
    local r = BaseRow(key, w, e)
    r.mode = "buyout"
    r.limit = ns.Watch.Limit(key, e)
    r.target = Num(w.up) and w.up or nil
    if r.price and r.limit and r.price <= r.limit then r.advice = "buy"
    elseif r.price and r.target and r.price >= r.target then r.advice = "sell" end
    local band = type(e) == "table" and e.m and ns.Buyout.Context(e, key).band or nil
    r.bandLow = type(band) == "table" and Num(band.low) and band.low or nil
    r.bandHigh = type(band) == "table" and Num(band.high) and band.high or nil
    return r
end

-- ab 0.119: Zeile der Liste Schnellkauf
function P.QuickRow(key, w)
    local e = ns.Data.Lookup(key)
    local r = BaseRow(key, w, e)
    r.mode = "quick"
    r.limit = Num(w.qlim) and w.qlim or nil
    r.muteUp = nil
    if r.price and r.limit and r.price <= r.limit then r.advice = "buy" end
    -- Stueck unter Kaufen bis aus der letzten Abfrage
    local live = ns.Buy.live[key]
    if r.limit and type(live) == "table" and type(live.rows) == "table" then
        local q = 0
        for _, l in ipairs(ns.Data.Available(live.rows)) do
            if Num(l.price) and l.price <= r.limit and Num(l.qty) then q = q + l.qty end
        end
        r.under = q
    end
    local QC = ns.QuickChances
    r.v = QC and QC.Result(key) or nil
    r.rank = QC and QC.Rank(r.v) or 2
    r.ev = r.v and r.v.ev or 0
    r.running = QC ~= nil and QC.run ~= nil and QC.run.key == key
    local s = ns.Quick and ns.Quick.sessions[key]
    r.bought = s and s.bought > 0 and s.bought or nil
    r.cost = s and s.cost or nil
    -- ab 0.126: Zaehlwerte im Zeitraum und Tiefstpreis 24 Std. (gespeichert)
    local QS = ns.QuickStats
    local st = QS and QS.Get(key) or nil
    r.stats = st
    r.dips = st and st.dips or nil
    r.hits = st and r.limit and st.hits or nil
    r.low24 = QS and QS.Low24(key) or nil
    return r
end

-- ab 0.126: Zelle fuer Anzahlen (Treffer, Einbrueche): grau "-" ohne Wert, gruen ab 1
function P.CountCell(v)
    if not Num(v) then return GREY .. "-|r" end
    return (v > 0 and GREEN or GREY) .. tostring(v) .. "|r"
end

-- Zahl am Reiter: Gegenstaende mit Rat KAUFEN oder VERKAUFEN
-- ab 0.97: only = "buy" oder "sell" zaehlt nur diese Richtung
function P.Count(only)
    local n = 0
    for _, r in ipairs(P.Rows("active")) do if r.advice and (only == nil or r.advice == only) then n = n + 1 end end
    return n
end

function P.UpdateBadge()
    local T = ns.AHTabs
    if not (T and T.SetBadge and T.built) then return end
    local mode = T.BadgeMode and T.BadgeMode("watch") or "both"   -- ab 0.97 einstellbar
    if mode == "off" then T.SetBadge("watch", nil) return end
    T.SetBadge("watch", P.Count(mode ~= "both" and mode or nil), false)
end

function P.Build(c)
    local UI = Peon.UI
    P.frame = c
    P.hint = UI.Text(c, "small", GREY .. L.WATCH_HINT .. "|r", 380)
    P.hint:SetPoint("TOPLEFT", 70, -10)
    P.live = UI.Text(c, "small", "", 320)
    P.live:SetJustifyH("RIGHT")
    P.live:SetPoint("TOPRIGHT", -4, -10)
    local function Price(v) return Num(v) and Money(v) or (GREY .. "-|r") end
    local adviceCol = { key = "advice", title = L.WATCH_COL_ADVICE, width = 96, align = "RIGHT",
        format = function(v)
            if v == "buy" then return GREEN .. L.WATCH_ADV_BUY .. "|r" end
            if v == "sell" then return GOLD .. L.WATCH_ADV_SELL .. "|r" end
            return ""
        end,
        sort = function(r) return r.advice == "buy" and 1 or r.advice == "sell" and 2 or 3 end }
    local nameCol = { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
        color = function(r) return UI.QualityColor(r.quality or 1) end }
    -- ab 0.119: zwei Unterreiter mit eigenen Spalten
    local COLS = {
        buyout = {
            nameCol,
            { key = "price", title = L.WATCH_COL_PRICE, width = 100, align = "RIGHT", format = Price },
            { key = "limit", title = L.FOCUS_R_LIMIT, width = 100, align = "RIGHT", format = Price },
            -- ab 0.92 statt "Ueblich": Symbol der Warnung hinter jeder Grenze, Klick schaltet an und aus
            P.BellColumn("Down"),
            { key = "target", title = L.FOCUS_R_TARGET, width = 100, align = "RIGHT", format = Price },
            P.BellColumn("Up"),
            adviceCol,
        },
        quick = {
            nameCol,
            { key = "price", title = L.QC_COL_MIN, width = 90, align = "RIGHT", format = Price },
            { key = "limit", title = L.FOCUS_R_LIMIT, width = 90, align = "RIGHT", format = Price },
            P.BellColumn("Down"),
            { key = "under", title = L.WATCH_COL_UNDER, width = 80, align = "RIGHT",
              format = function(v) return Num(v) and (v > 0 and GREEN or GREY) .. tostring(v) .. "|r" or (GREY .. "-|r") end },
            -- ab 0.126: Ampel statt Wort
            { key = "move", title = L.QC_COL_MOVE, width = 76, align = "CENTER",
              format = function(_, r) return ns.QuickChances.Light(r.v) end,
              sort = function(r) return (r.rank or 2) * 1e6 - (r.ev or 0) end },
            -- ab 0.126: Treffer und Einbrueche im Zeitraum, Tiefstpreis 24 Std. (statt Einbr./Std. und Rat)
            { key = "hits", title = L.WATCH_COL_HITS, width = 60, align = "RIGHT", format = P.CountCell,
              sort = function(r) return r.hits or -1 end },
            { key = "dips", title = L.WATCH_COL_DIPS, width = 72, align = "RIGHT", format = P.CountCell,
              sort = function(r) return r.dips or -1 end },
            { key = "low24", title = L.WATCH_COL_LOW24, width = 96, align = "RIGHT",
              format = function(v, r)
                  if not Num(v) then return GREY .. "-|r" end
                  return (r.limit and v <= r.limit) and (GREEN .. Money(v) .. "|r") or Money(v)
              end,
              sort = function(r) return r.low24 or math.huge end },
        },
    }
    P.panels, P.lists = {}, {}
    for _, tab in ipairs({ "buyout", "quick" }) do
        local lp = UI.Panel(c, "list", true)
        lp:SetPoint("TOPLEFT", 0, -62)
        lp:SetPoint("BOTTOMRIGHT", 0, 34)
        P.panels[tab] = lp
        local list = UI.Table(lp, {
            columns = COLS[tab],
            sortKey = "name", icon = true, empty = tab == "quick" and L.WATCH_EMPTY_QUICK or L.WATCH_EMPTY,
            rowBg = function(r)   -- ab 0.83: kurz aufleuchten bei neuem Rat (Kern API 19)
                if r and r.flash == "buy" then return 0.38, 0.88, 0.38, 0.28 end
                if r and r.flash == "sell" then return 1, 0.82, 0, 0.28 end
                if r and r.running then return 1, 0.82, 0, 0.16 end   -- ab 0.119: Pruefung laeuft
            end,
            -- ab 0.83 (KarloDerBaer): Klick waehlt (fuer die Knoepfe unten), Doppelklick oeffnet den Fokus, Rechtsklick das Menue
            onClick = function(r, button)
                -- ab 0.92: Klick auf ein Symbol schaltet die Warnung dieser Grenze, sonst nichts
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
                    -- ab 0.119: im Modus der Liste
                    mod:Call("Sprung", ns.Go.Focus, { key = r.key, name = r.name, from = "watch", mode = P.Tab() })
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
                if r.mode == "quick" and GameTooltip then P.QuickTooltip(row, r); return end
                W.ShowItemTooltip(row, r.key)
            end,
        })
        function list:GetItems() return self.items end
        P.lists[tab] = list
    end
    P.panel, P.list = P.panels[P.Tab()], P.lists[P.Tab()]
    P.tabs = UI.TopTabs(c, { { "buyout", L.FOCUS_MODE_BUYOUT }, { "quick", L.FOCUS_MODE_QUICK } }, function(key)
        mod:Call("Beobachten", P.SelectTab, key)
    end)
    if P.tabs[1] then P.tabs[1]:SetPoint("BOTTOMLEFT", P.panels.buyout, "TOPLEFT", 10, -2) end
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
    P.marketButton = ns.Go.MarketButton(c, 150, function() return P.selected and { key = P.selected.key, name = P.selected.name } or nil end)
    P.marketButton:SetPoint("RIGHT", P.removeButton, "LEFT", -6, 0)
    -- ab 0.83: Verkaufen. Sicherer Knopf wie "Ins Verkaufsfenster legen" (Lots.lua): Makro "/click <Taschenplatz> RightButton",
    -- derselbe Klick wie der Rechtsklick in der Tasche. Blizzards Code wechselt auf Verkaufen und legt den Gegenstand hinein,
    -- Broker schaltet nichts selbst um (Fehlerberichte 10 und 11). Vorher blendet Broker seinen Reiter aus (eigene Flaeche).
    local sb = CreateFrame("Button", "PeonBrokerWatchSellButton", c, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    sb:SetSize(110, 22)
    sb:SetPoint("RIGHT", P.marketButton, "LEFT", -6, 0)
    if sb.RegisterForClicks then sb:RegisterForClicks("AnyUp", "AnyDown") end
    sb:SetText(L.WATCH_SELL)
    sb:HookScript("PreClick", function()
        local T = ns.AHTabs
        if T and T.current and T.Close then mod:Call("Verkaufen", T.Close) end
    end)
    UI.SetTooltip(sb, function() return { L.WATCH_SELL, P.sellWhy or L.WATCH_SELL_TIP } end)
    P.sellButton = sb
    P.tabs:Select(P.Tab())   -- zeigt die Liste (P.SelectTab)
end

-- ab 0.119: Unterreiter waehlen (Klick oder beim Aufbau)
function P.SelectTab(key)
    mod.db.watchTab = key == "quick" and "quick" or "buyout"
    local tab = P.Tab()
    for k, panel in pairs(P.panels or {}) do panel:SetShown(k == tab) end
    P.panel, P.list = P.panels[tab], P.lists[tab]
    P.selected, P.clickKey = nil, nil
    P.Refresh()
end

-- ab 0.119: Tooltip einer Zeile im Schnellkauf: Bewegung, Werte des Schnellkaufs, Bilanz der Sitzung
function P.QuickTooltip(row, r)
    local GT = GameTooltip
    local w = ns.Watch.Store()[r.key] or {}
    GT:SetOwner(row, "ANCHOR_RIGHT")
    GT:AddLine(r.name or tostring(r.key), 1, 1, 1)
    GT:AddLine(L.FOCUS_MODE_QUICK, 1, 0.82, 0)
    if ns.QuickChances then ns.QuickChances.TipLines(GT, r.key) end
    if Num(w.qgold) and w.qgold > 0 then GT:AddLine(L.WATCH_TIP_QGOLD:format(Money(w.qgold)), 0.85, 0.85, 0.85) end
    if w.qskip then GT:AddLine(L.QUICK_SKIP, 0.85, 0.85, 0.85) end
    if w.qavg then GT:AddLine(L.WATCH_TIP_QAVG, 0.85, 0.85, 0.85) end
    if ns.Quick then GT:AddLine(ns.Quick.BalanceText(r.key), 0.85, 0.85, 0.85, true) end
    GT:AddLine(L.WATCH_TIP_DOUBLE, 0.6, 0.6, 0.6)
    GT:Show()
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
    if P.selected then P.removeButton:Enable(); P.marketButton:Enable() else P.removeButton:Disable(); P.marketButton:Disable() end
    P.UpdateSell()
end

function P.Refresh()
    P.UpdateBadge()
    if not P.list then return end
    if P.Shown() and ns.Radar and ns.Radar.Wake then ns.Radar.Wake() end   -- ab 0.83: laufend abfragen
    if P.live then P.live:SetText(P.LiveText()) end
    if P.Shown() then P.StartTick() end
    if P.alarmCheck then P.alarmCheck:SetChecked(mod.db.watchAlarm ~= false) end
    local rows = P.Rows()
    P.Flash(rows)
    -- ab 0.83: gleiche Gegenstaende: Werte in die vorhandenen Zeilen, nur neu fuellen (kein Austausch, kein verlorener Klick)
    -- ab 0.119 ueber Window.FillTable. Schnellkauf sortiert neu, wenn eine Pruefung fertig ist.
    local resort = false
    if P.Tab() == "quick" and ns.QuickChances then
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
