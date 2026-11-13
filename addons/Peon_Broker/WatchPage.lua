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
    if R and R.Watching and R.Watching() then
        return GREEN .. L.WATCH_LIVE .. ("."):rep(P.dots) .. "|r"
    end
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
        local before = P.lastAdvice[r.key]
        if r.advice and before ~= nil and r.advice ~= before then P.flash[r.key] = { untl = now + P.FLASH, kind = r.advice } end
        P.lastAdvice[r.key] = r.advice or false
        local f = P.flash[r.key]
        r.flash = f and f.untl > now and f.kind or nil
        if f and f.untl <= now then P.flash[r.key] = nil end
    end
end

-- ab 0.92: Symbol der Warnung je Gegenstand (Blizzards Lautsprecher aus dem Sprachchat, Zweig forever)
P.BELL_ON = "|A:voicechat-icon-speaker:16:16|a"
P.BELL_OFF = "|A:voicechat-icon-speaker-mute:16:16|a"
P.BELL_W = 36
P.BELL_COL = { Down = 4, Up = 6 }   -- Platz der Spalten in der Tabelle (hinter Kaufen bis und Zielpreis)

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
    for dir, i in pairs(P.BELL_COL) do
        local h = P.list and P.list.heads and P.list.heads[i]
        local left, right = h and h.GetLeft and h:GetLeft(), h and h.GetRight and h:GetRight()
        local scale = h and h.GetEffectiveScale and h:GetEffectiveScale() or 1
        local x = GetCursorPosition()
        if left and right and x and scale > 0 and x / scale >= left and x / scale <= right then return dir end
    end
    return nil
end

-- Zeilen der Liste
function P.Rows()
    local Wt, D = ns.Watch, ns.Data
    local rows = {}
    for key, w in pairs(Wt.Store()) do
        local e = D.Lookup(key)
        local price = type(e) == "table" and not e.gone and Num(e.m) and e.m or nil
        local limit = Wt.Limit(key, e)
        local target = Num(w.up) and w.up or nil
        local advice
        if price and limit and price <= limit then advice = "buy"
        elseif price and target and price >= target then advice = "sell" end
        local band = type(e) == "table" and e.m and ns.Buyout.Context(e, key).band or nil
        rows[#rows + 1] = {
            key = key, name = w.name or D.ItemName(key, e) or tostring(key), quality = w.q or (type(e) == "table" and e.ql) or nil,
            icon = w.icon or ns.Buy.Icon(D.ItemID(key)), link = D.LinkFromKey and D.LinkFromKey(key) or nil,
            price = price, limit = limit, target = target, advice = advice,
            bandLow = type(band) == "table" and Num(band.low) and band.low or nil,
            bandHigh = type(band) == "table" and Num(band.high) and band.high or nil,
            age = P.Age(key),
            muteDown = w.muteDown == true,
            muteUp = w.muteUp == true,
        }
    end
    return rows
end

-- Zahl am Reiter: Gegenstaende mit Rat KAUFEN oder VERKAUFEN
function P.Count()
    local n = 0
    for _, r in ipairs(P.Rows()) do if r.advice then n = n + 1 end end
    return n
end

function P.UpdateBadge()
    local T = ns.AHTabs
    if T and T.SetBadge and T.built then T.SetBadge("watch", P.Count(), false) end
end

function P.Build(c)
    local UI = Peon.UI
    P.frame = c
    local lp = UI.Panel(c, "list", true)
    lp:SetPoint("TOPLEFT", 0, -30)
    lp:SetPoint("BOTTOMRIGHT", 0, 34)
    P.panel = lp
    P.hint = UI.Text(c, "small", GREY .. L.WATCH_HINT .. "|r", 380)
    P.hint:SetPoint("TOPLEFT", 70, -10)
    P.live = UI.Text(c, "small", "", 320)
    P.live:SetJustifyH("RIGHT")
    P.live:SetPoint("TOPRIGHT", -4, -10)
    P.list = UI.Table(lp, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
              color = function(r) return UI.QualityColor(r.quality or 1) end },
            { key = "price", title = L.WATCH_COL_PRICE, width = 100, align = "RIGHT", format = function(v) return Num(v) and Money(v) or (GREY .. "-|r") end },
            { key = "limit", title = L.FOCUS_R_LIMIT, width = 100, align = "RIGHT", format = function(v) return Num(v) and Money(v) or (GREY .. "-|r") end },
            -- ab 0.92 statt "Ueblich": Symbol der Warnung hinter jeder Grenze, Klick schaltet an und aus
            P.BellColumn("Down"),
            { key = "target", title = L.FOCUS_R_TARGET, width = 100, align = "RIGHT", format = function(v) return Num(v) and Money(v) or (GREY .. "-|r") end },
            P.BellColumn("Up"),
            { key = "age", title = L.WATCH_COL_AGE, width = 70, align = "RIGHT", format = function(v) return P.AgeText(v) end,
              sort = function(r) return r.age or 1e9 end },
            { key = "advice", title = L.WATCH_COL_ADVICE, width = 96, align = "RIGHT",
              format = function(v)
                  if v == "buy" then return GREEN .. L.WATCH_ADV_BUY .. "|r" end
                  if v == "sell" then return GOLD .. L.WATCH_ADV_SELL .. "|r" end
                  return ""
              end,
              sort = function(r) return r.advice == "buy" and 1 or r.advice == "sell" and 2 or 3 end },
        },
        sortKey = "name", icon = true, empty = L.WATCH_EMPTY,
        rowBg = function(r)   -- ab 0.83: kurz aufleuchten bei neuem Rat (Kern API 19)
            if r and r.flash == "buy" then return 0.38, 0.88, 0.38, 0.28 end
            if r and r.flash == "sell" then return 1, 0.82, 0, 0.28 end
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
                mod:Call("Sprung", ns.Go.Focus, { key = r.key, name = r.name, from = "watch" })
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
            W.ShowItemTooltip(row, r.key)
        end,
    })
    function P.list:GetItems() return self.items end
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
    P.Refresh()
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
    local old = P.list.items
    local same = type(old) == "table" and #old == #rows and #rows > 0
    local byKey = {}
    if same then
        for _, it in ipairs(old) do byKey[it.key] = it end
        for _, r in ipairs(rows) do if not byKey[r.key] then same = false end end
    end
    if same then
        for _, r in ipairs(rows) do
            local it = byKey[r.key]
            for k in pairs(it) do if k ~= "__index" and r[k] == nil then it[k] = nil end end
            for k, v in pairs(r) do it[k] = v end
        end
        P.list.list:Refresh()
        rows = old
    else
        P.list:SetData(rows)
    end
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
