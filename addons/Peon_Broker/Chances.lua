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

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local C = {}
ns.Chances = C

C.checked = {}   -- [Schluessel] = { t = Zeit der Pruefung (GetTime), ok = noch da, gain, offer }
C.notified = {}  -- [Schluessel .. Fenster] = true: Meldung zum Fenster schon gegeben (diese Sitzung)
C.KIND_SETTING = { s = "chancesShowS", l = "chancesShowL", b = "chancesShowB", m = "chancesShowM" }

local GREY, ORANGE, GREEN, GOLD = "|cff999999", "|cffff9933", "|cff60e060", "|cffffd100"
local function Money(v) return ns.Tooltip.Money(v) end
local function Now() return GetTime and GetTime() or time() end

-- Art an? (Einstellungen)
function C.KindOn(mk)
    local k = C.KIND_SETTING[mk]
    return k ~= nil and mod.db[k] ~= false
end

function C.Shown()
    local T = ns.AHTabs
    if T and T.current == "chances" then return true end
    if T and T.host and T.host.chances == "ah" then return false end
    return W.IsOpen() and W.current == "chances"
end

-- Schluessel der gezeigten Arten, hoechster Gewinn zuerst (fuer Erneuern und "Alle pruefen")
function C.Keys()
    local Sp = ns.Spec
    if not Sp then return {} end
    local all, keys = Sp.All(), {}
    for key, x in pairs(all) do
        if C.KindOn(x.mk) and ns.Buy.KnownKey(key) then keys[#keys + 1] = key end
    end
    table.sort(keys, function(a, b) return (all[a].gain or 0) > (all[b].gain or 0) end)
    return keys
end

-- Antwort einer Live-Abfrage (Radar.lua R.Apply): Zustand merken, wenn der Gegenstand eine Chance des Managers ist
function C.Note(key, d, rows)
    if not (ns.Spec and ns.Spec.Get(key)) then return end
    local lv = ns.Data.Available(rows or {})
    C.checked[key] = { t = Now(), ok = d ~= nil, gain = d and (d.showGain or d.gain) or nil, offer = lv[1] and lv[1].price or nil }
    if C.Shown() then C.Refresh() end
    C.UpdateBadge()
end

-- Zahl am Reiter (ab 0.97, einstellbar, Standard aus): ok = live bestaetigt, all = alle gezeigten.
-- Muster zaehlen nur im guenstigen Zeitfenster.
function C.BadgeCount(mode)
    local n = 0
    for _, r in ipairs(C.Rows()) do
        local now = not (r.mk == "m" and r.x.buyWin and not r.inWindow)
        if now and (mode == "all" and r.state ~= "gone" or r.state == "ok") then n = n + 1 end
    end
    return n
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
    T.SetBadge("chances", C.BadgeCount(mode), false)
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

-- Zeilen fuer die Liste
function C.Rows()
    local Sp, D, R = ns.Spec, ns.Data, ns.Radar
    local rows = {}
    if not Sp then return rows end
    local market = D.Market()
    local now = Now()
    for key, x in pairs(Sp.All()) do
        if C.KindOn(x.mk) then
            local e = market and market.items[key]
            local r = { key = key, mk = x.mk, x = x, limit = x.limit, target = x.target, qty = x.qty, say = x.say }
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
            rows[#rows + 1] = r
        end
    end
    return rows
end

function C.StateText(r)
    if r.mk == "m" and r.x.buyWin and not r.inWindow then
        return GREY .. L.CH_STATE_FROM:format(C.WindowText(r.x.buyWin)) .. "|r"
    end
    if r.state == "gone" then return ORANGE .. L.CH_STATE_GONE .. "|r" end
    if r.state == "ok" then return GREEN .. L.CH_STATE_OK:format(ns.Radar.ShortAge(Now() - r.checked.t)) .. "|r" end
    return GREY .. L.CH_STATE_NEW .. "|r"
end

function C.RowTooltip(row, r)
    local GT = GameTooltip
    if not GT then return end
    GT:SetOwner(row, "ANCHOR_RIGHT")
    GT:AddLine(r.name or tostring(r.key), 1, 1, 1)
    GT:AddLine(L["CH_KIND_" .. r.mk:upper()] or r.mk, 1, 0.82, 0)
    local focus = ns.Spec.FocusText(r.key)
    if focus then GT:AddLine(focus, 0.85, 0.85, 0.85, true) end
    GT:AddLine(L.CH_TIP_PRICES:format(Money(r.limit or 0), Money(r.target or 0), r.qty or 1), 1, 1, 1)
    if r.x.buyWin then GT:AddLine(L.CH_TIP_WINDOW:format(C.WindowText(r.x.buyWin), C.WindowText(r.x.sellWin)), 0.6, 1, 0.6, true) end
    if r.checked and r.checked.offer then GT:AddLine(L.CH_TIP_OFFER:format(Money(r.checked.offer)), 0.85, 0.85, 0.85) end
    GT:AddLine(L.CH_TIP_CLICK, 0.6, 0.6, 0.6)
    GT:Show()
end

---------------------------------------------------------------------------
-- Seite
---------------------------------------------------------------------------
function C.CheckAll()
    local R = ns.Radar
    if R.running then R.Stop(); return end
    R.forceMode = "mgronly"
    R.search = nil
    R.Start()
end

function C.Build(c)
    local UI = Peon.UI
    C.checkButton = UI.Button(c, L.CH_CHECK_ALL, 150, function() mod:Call("Chancen", C.CheckAll) end)
    C.checkButton:SetPoint("TOPRIGHT", -2, -2)
    UI.SetTooltip(C.checkButton, { L.CH_CHECK_ALL, L.CH_CHECK_ALL_TIP })
    C.settingsButton = UI.Button(c, L.SETTINGS_BUTTON, 110, function()
        if ns.Settings then mod:Call("Einstellungen", ns.Settings.Toggle, "chances") end
    end)
    C.settingsButton:SetPoint("RIGHT", C.checkButton, "LEFT", -6, 0)
    C.status = UI.Text(c, "small", "")
    C.status:SetPoint("TOPLEFT", 8, -8)
    C.status:SetPoint("RIGHT", C.settingsButton, "LEFT", -12, 0)
    if C.status.SetWordWrap then C.status:SetWordWrap(false) end
    local p = UI.Panel(c, "list", true)
    p:SetPoint("TOPLEFT", 0, -30)
    p:SetPoint("BOTTOMRIGHT", 0, 0)
    C.panel = p
    C.list = UI.Table(p, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
              color = function(r)
                  if r.state == "gone" then return 0.5, 0.5, 0.5 end
                  return UI.QualityColor(r.quality or 1)
              end },
            { key = "mk", title = L.RADAR_COL_KIND, width = 100, align = "RIGHT",
              format = function(v) return L["CH_KIND_" .. tostring(v):upper()] or tostring(v) end },
            { key = "gain", title = L.RADAR_COL_GAIN, width = 110, align = "RIGHT",
              format = function(v, r) return ((r.state == "gone") and GREY or GREEN) .. Money(math.floor((v or 0) + 0.5)) .. "|r" end,
              sort = function(r) return -r.rank * 1e13 + (r.gain or 0) end },
            { key = "limit", title = L.CH_COL_LIMIT, width = 100, align = "RIGHT",
              format = function(v) return v and Money(v) or "" end },
            { key = "state", title = L.CH_COL_STATE, width = 150, align = "RIGHT",
              format = function(_, r) return C.StateText(r) end,
              sort = function(r) return r.rank end },
        },
        sortKey = "gain", sortDesc = true, icon = true, empty = L.CH_EMPTY,
        onClick = function(r)
            mod:Call("Sprung", ns.Go.Focus, { key = r.key, name = r.name, from = "chances" })
        end,
        onEnter = function(row, r) if r then C.RowTooltip(row, r) end end,
    })
    C.Open()
end

function C.StatusText()
    local Sp, R = ns.Spec, ns.Radar
    local _, t = Sp.All()
    local st
    if not t then
        st = ORANGE .. L.CH_NO_MANAGER .. "|r"
    else
        local age = math.max(0, time() - t)
        st = GREY .. L.CH_STAND:format(age < 3600 and L.SPEC_MIN:format(math.max(1, math.floor(age / 60))) or L.SPEC_HOURS:format(math.floor(age / 3600))) .. "|r"
    end
    if R.running and R.forceMode == "mgronly" then
        local sc = R.search
        st = GREEN .. L.CH_CHECKING:format(sc and sc.done or 0, sc and #sc.keys or 0) .. "|r"
    end
    if not (ns.Scan.ahOpen and rawget(_G, "C_AuctionHouse")) then st = st .. "  " .. ORANGE .. L.ST_NOT_LIVE .. "|r" end
    return st
end

function C.UpdateView()
    if not C.list then return end
    local R = ns.Radar
    C.status:SetText(C.StatusText())
    C.checkButton:SetText((R.running and R.forceMode == "mgronly") and L.RADAR_STOP or L.CH_CHECK_ALL)
    if ns.Scan.ahOpen and not ns.Scan.state and not (R.running and R.forceMode ~= "mgronly") then C.checkButton:Enable() else C.checkButton:Disable() end
end

function C.Refresh()
    if C.list and C.Shown() then C.list:SetData(C.Rows()) end
    C.UpdateView()
end

function C.Open()
    if ns.Radar then ns.Radar.LoadIfStale() end
    C.Refresh()
    if ns.Radar then ns.Radar.Wake() end
end

---------------------------------------------------------------------------
-- Hinweise: beim Oeffnen des Auktionshauses und wenn ein guenstiges Fenster beginnt
---------------------------------------------------------------------------
function C.OnAHShow()
    C.UpdateBadge()
    if mod.db.chancesAhNote == false then return end
    local n = #C.Keys()
    if n > 0 then mod:Print(L.CH_AH_NOTE:format(n)) end
end

function C.Tick()
    C.UpdateBadge()   -- Muster: Zeitfenster beginnt oder endet
    if mod.db.chancesNotify == false or not C.KindOn("m") or not ns.Spec then return end
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
    leave = function() if ns.Radar then ns.Radar.Halt() end end,
}
