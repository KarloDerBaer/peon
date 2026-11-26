-- Peon_Broker - AuctionsOwn.lua
-- Ab 0.72 (KarloDerBaer, 12.11.2026): eigene Liste "Meine Auktionen" ueber Blizzards Ansicht Auktionen.
-- Blizzards Ansicht bleibt darunter offen und arbeitet weiter (wird nur verdeckt), Broker schreibt nichts hinein.
--   oben    Zusammenfassung, Filter (Status ausblenden, mehrfach waehlbar), Pruefen, Blizzard-Ansicht
--   Mitte   Liste mit Peon.UI: Gegenstand, Menge, Preis je Stueck, Broker (Status als echte Spalte), Restzeit
--   unten   Auktion abbrechen (gewaehlte), Unterbotene abbrechen (n), Im Markt zeigen
-- Abbrechen ruft C_AuctionHouse.CancelAuction aus dem Klick (wie "Unterbotene abbrechen" seit 0.67). Abgebrochenes
-- wird ein Posten zum Einstellen (Lots.lua). Gebote zeigt weiter Blizzard: Knopf "Blizzard-Ansicht", dort zurueck
-- mit "Broker-Liste". Bei "Blizzard pur" nichts davon.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local O = {}
ns.AuctionsOwn = O

O.STATUS = { "best", "equal", "under", "high", "sold" }   -- Reihenfolge im Filter und beim Sortieren
local COLORS = { best = "|cff60e060", equal = "|cffffd100", under = "|cffff9933", high = "|cffff4040", sold = "|cff999999" }

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end
local function On(b, v) if v then b:Enable() else b:Disable() end end

function O.Enabled() return mod.db.aucOwnList ~= false and ns.AHTouch() end

-- Ausgeblendete Status (Filter)
function O.Hidden()
    local h = mod.db.aucHide
    if type(h) ~= "table" then h = {}; mod.db.aucHide = h end
    return h
end

-- Restzeit als kurzer Text
function O.LeftText(r)
    if Num(r.left) and r.left > 0 then
        local h = r.left / 3600
        if h >= 1 then return L.AUCO_HOURS:format(math.floor(h + 0.5)) end
        return L.AUCO_MINS:format(math.max(1, math.floor(r.left / 60 + 0.5)))
    end
    local b = tonumber(r.band)
    if b then return L["AUCO_BAND_" .. b] or "" end
    return ""
end

-- ab 0.145: kurzer Status fuer die schmale Spalte Broker (wie im Filter), der lange mit Preis steht im Tooltip
O.STATUS_W = 104
function O.ShortStatus(r)
    local t = r and r.kind and L["AUCO_ST_" .. r.kind:upper()]
    return t or (r and r.statusText) or ""
end

-- Zeilen fuer die Liste: Status aus AuctionsAH (X.Status), Filter angewendet
function O.Rows()
    local X, hidden, out = ns.AuctionsAH, O.Hidden(), {}
    for _, r in ipairs(ns.Auctions and ns.Auctions.rows or {}) do
        local kind, text = X.Status(r)
        if not hidden[kind or ""] then
            out[#out + 1] = {
                row = r, id = r.id, key = r.key, name = r.name, link = r.link, icon = r.icon, quality = r.quality,
                qty = r.qty, price = r.price, kind = kind, statusText = text, left = r.left, band = r.band,
            }
        end
    end
    return out
end

function O.Build(af)
    if O.panel or not O.Enabled() then return end
    local UI, T, W = Peon.UI, ns.AHTabs, ns.Window
    local f = rawget(_G, "AuctionHouseFrame")
    if not (UI and af and f) then return end
    -- ab 0.74 wie Brokers eigene Reiter (AHTabs, T.page): ganze Flaeche ab der Titelleiste, undurchsichtig, mit
    -- Statuszeile. Vorher nur ueber Blizzards Ansicht Auktionen, da schienen Blizzards Reiter und Spalten durch.
    local p = CreateFrame("Frame", "PeonBrokerAuctionsPanel", f)
    p:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -22)
    p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    p:SetFrameLevel(T.PAGE_LEVEL or 370)
    p:EnableMouse(true)
    local under = p:CreateTexture(nil, "BACKGROUND", nil, -8)
    under:SetAllPoints(p)
    under:SetColorTexture(0.05, 0.05, 0.05, 1)
    local bg = p:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetAllPoints(p)
    if not (T.CopyFrameBg and T.CopyFrameBg(f, bg)) then bg:SetColorTexture(0.08, 0.08, 0.08, 1) end
    if W.NewStatus then
        local bar = W.NewStatus(p)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 2, 27)
        bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 3)
        if bar.SetFrameLevel then bar:SetFrameLevel((p:GetFrameLevel() or 1) + 6) end
        O.status = bar
    end
    p:SetScript("OnShow", function()
        if W.FillStatus then W.FillStatus(O.status) end
        if T.HideHighStrata then T.HideHighStrata(true) end
    end)
    p:SetScript("OnHide", function()
        if T.HideHighStrata and not (T.page and T.page:IsShown()) then T.HideHighStrata(false) end
    end)
    p:Hide()
    O.panel = p
    -- Inhalt wie Einkaufen: oben eine Leiste neben dem runden Bild, darunter die Liste, unten die Knoepfe
    local c = CreateFrame("Frame", nil, p)
    c:SetPoint("TOPLEFT", f, "TOPLEFT", W.SIDE, -(W.TOP_BAR or 30))
    c:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -W.SIDE, W.BOTTOM)
    O.content = c
    O.summary = UI.Text(c, "text", "")
    O.summary:SetPoint("TOPLEFT", 70, -10)
    O.blizz = UI.Button(c, L.AUCO_BLIZZARD, 140, function() O.SetOn(false) end)
    O.blizz:SetPoint("TOPRIGHT", -2, -4)
    UI.SetTooltip(O.blizz, { L.AUCO_BLIZZARD, L.AUCO_BLIZZARD_TIP })
    O.check = UI.Button(c, L.AUCX_CHECK, 90, function()
        if ns.Auctions then mod:Call("Auktionen", ns.Auctions.StartLive) end
        O.Update(true)
    end)
    O.check:SetPoint("RIGHT", O.blizz, "LEFT", -6, 0)
    UI.SetTooltip(O.check, { L.AUCX_CHECK, L.AUCX_CHECK_HINT })
    O.filter = UI.FilterDropdown(c, L.AUCO_FILTER, function(root)
        for _, k in ipairs(O.STATUS) do
            root:CreateCheckbox(L["AUCO_ST_" .. k:upper()], function() return not O.Hidden()[k] end,
                function() O.Hidden()[k] = not O.Hidden()[k] or nil; O.Update(true) end)
        end
    end)
    O.filter:SetPoint("RIGHT", O.check, "LEFT", -8, 0)
    if O.filter.SetWidth then O.filter:SetWidth(110) end
    -- ab 0.144 (Board KarloDerBaer): Spalte links statt der Zeile "n laufen" oben
    local s = O.BuildSide(c)
    O.sideObj, O.side, O.sideVal, O.sideParts = s, s.panel, s.val, s.parts
    -- Liste
    local lp = UI.Panel(c, "list", true)
    lp:SetPoint("TOPLEFT", O.side, "TOPRIGHT", UI.GAP or 6, 0)
    lp:SetPoint("BOTTOMRIGHT", 0, 32)
    O.listPanel = lp
    O.list = UI.Table(lp, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return ns.Window.Lower(r.name) end,
              color = function(r) return UI.QualityColor(r.quality or 1) end },
            { key = "qty", title = L.FOCUS_R_QTY, width = 70, align = "RIGHT" },
            { key = "price", title = L.AUCO_COL_PRICE, width = 120, align = "RIGHT", format = function(v) return Num(v) and Money(v) or "" end },
            -- ab 0.145 (Board KarloDerBaer): schmal mit kurzem Text, der ganze Text steht im Tooltip der Zeile. So bleibt
            -- der Spalte Gegenstand der meiste Platz.
            { key = "kind", title = L.AUCX_COL, width = O.STATUS_W, format = function(_, r) return (COLORS[r.kind] or "") .. O.ShortStatus(r) .. "|r" end,
              sort = function(r) for i, k in ipairs(O.STATUS) do if k == r.kind then return i end end return 99 end },
            { key = "left", title = L.AUCO_COL_LEFT, width = 90, align = "RIGHT", format = function(_, r) return O.LeftText(r) end,
              sort = function(r) return Num(r.left) and r.left or ((tonumber(r.band) or 9) * 100000) end },
        },
        sortKey = "kind", icon = true, empty = L.AUCO_EMPTY,
        onClick = function(r, button)
            O.sel = r
            if button == "RightButton" then ns.Go.Menu(r, O.listPanel) end
            O.UpdateButtons()
        end,
        onEnter = function(row, r)
            if not r then return end
            ns.Window.ShowItemTooltip(row, r.key)
            if GameTooltip and r.statusText and r.statusText ~= O.ShortStatus(r) then
                GameTooltip:AddLine(L.AUCX_COL .. ": " .. (COLORS[r.kind] or "") .. r.statusText .. "|r", 1, 0.82, 0)
                GameTooltip:Show()
            end
        end,
    })
    function O.list:GetItems() return self.items end
    -- unten
    O.cancelOne = UI.Button(c, L.AUCO_CANCEL, 150, function() O.CancelSelected() end)
    O.cancelOne:SetPoint("BOTTOMRIGHT", -2, 4)
    O.cancelUnder = UI.Button(c, L.AUCX_CANCEL_NONE, 190, function()
        if ns.Lots then mod:Call("Auktionen", ns.Lots.CancelNext) end
        O.Update(true)
    end)
    O.cancelUnder:SetPoint("RIGHT", O.cancelOne, "LEFT", -6, 0)
    UI.SetTooltip(O.cancelUnder, { L.AUCX_CANCEL_NONE:gsub(" %(0%)", ""), L.AUCX_CANCEL_HINT })
    O.market = ns.Go.MarketButton(c, 150, function() return O.sel and { key = O.sel.key, name = O.sel.name } or nil end)   -- ab 0.73 sicher
    O.market:SetPoint("BOTTOMLEFT", 0, 4)
    -- Sichtbar, solange Blizzards Ansicht Auktionen offen ist
    if af.HookScript then
        af:HookScript("OnShow", function() mod:Call("Auktionen", O.Place) end)
        af:HookScript("OnHide", function() mod:Call("Auktionen", O.Place) end)
    end
    O.Place()
end

---------------------------------------------------------------------------
-- ab 0.144 (Board KarloDerBaer 26.11.2026): Spalte links. Oben Laufende Auktionen (Anzahl, Unterboten, Wert), darunter
-- Beendete (Verkauft, Wert unterwegs: Erloes nach dem Anteil des Auktionshauses, kommt per Post).
-- ab 0.145 (Board KarloDerBaer): Hintergrund wie die Leiste im Markt, Ueberschriften in der Spalte, ein Wert, der neben
-- seiner Beschriftung keinen Platz hat, steht in der Zeile darunter. Dazu der Bereich Heute (Auktionen, Verkauft,
-- Abgebrochen, Gewinn) je Charakter.
---------------------------------------------------------------------------
O.SIDE_W = 200   -- ab 0.146 breiter, damit Betraege neben der Beschriftung stehen
O.SIDE_STEP = 18
O.SIDE_PAD = 10
O.SIDE_ROWS = {
    { "head", "AUCO_SIDE_RUNNING" },
    { "n", "AUCO_SIDE_COUNT" }, { "under", "AUCO_SIDE_UNDER" }, { "value", "AUCO_SIDE_VALUE" },
    { "line" },
    { "head", "AUCO_SIDE_DONE" },
    { "sold", "AUCO_SIDE_SOLD" }, { "soldValue", "AUCO_SIDE_ON_WAY" },
    { "line" },
    { "head", "AUCO_SIDE_TODAY" },
    { "dayPosted", "AUCO_SIDE_DAY_POSTED" }, { "daySold", "AUCO_SIDE_SOLD" }, { "dayCancelled", "AUCO_SIDE_DAY_CANCELLED" },
    { "dayGain", "AUCO_SIDE_DAY_GAIN" },
}

-- ab 0.166.0 auch unterwegs (Seite Auktionen im Broker-Fenster, Pages.lua): BuildSide gibt die Spalte zurueck
-- ({ panel, val, parts }), top und bottom sind die Abstaende im Inhalt. Die Spalte am Auktionshaus steht weiter in
-- O.side, O.sideVal und O.sideParts.
function O.BuildSide(c, top, bottom)
    local UI = Peon.UI
    local sp = UI.Panel(c, "categories")
    sp:SetPoint("TOPLEFT", 0, top or -34)
    sp:SetPoint("BOTTOMLEFT", 0, bottom or 32)
    sp:SetWidth(O.SIDE_W)
    local s = { panel = sp, val = {}, parts = {} }
    for _, def in ipairs(O.SIDE_ROWS) do
        local part = { kind = def[1] }
        if def[1] == "line" then
            part.line = UI.Divider(sp, O.SIDE_W - 2 * O.SIDE_PAD)
        elseif def[1] == "head" then
            part.label = UI.Text(sp, "label", L[def[2]])
            part.label:SetJustifyH("LEFT")
        else
            part.label = UI.Text(sp, "text", L[def[2]])
            part.label:SetJustifyH("LEFT")
            part.value = UI.Text(sp, "text", "")
            part.value:SetJustifyH("RIGHT")
            s.val[def[1]] = part.value
        end
        s.parts[#s.parts + 1] = part
    end
    O.LayoutSide(s)
    return s
end

-- Breite eines Textes (im Spiel gemessen, sonst geschaetzt)
local function TextW(fs)
    local w = fs.GetStringWidth and fs:GetStringWidth() or nil
    if Num(w) and w > 0 then return w end
    local t = (fs.GetText and fs:GetText() or "")
    t = t:gsub("|T.-|t", "00"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return #t * 7
end

-- Zeilen untereinander. Passt ein Wert nicht neben seine Beschriftung, kommt er in die naechste Zeile.
function O.LayoutSide(s)
    s = s or O.sideObj
    local sp = s and s.panel
    if not sp then return end
    local pad, w = O.SIDE_PAD, O.SIDE_W
    local y = -10
    for _, part in ipairs(s.parts) do
        if part.kind == "line" then
            part.line:ClearAllPoints()
            part.line:SetPoint("TOPLEFT", pad, y - 2)
            y = y - 12
        elseif part.kind == "head" then
            part.label:ClearAllPoints()
            part.label:SetPoint("TOPLEFT", pad, y)
            y = y - 22
        else
            part.label:ClearAllPoints()
            part.label:SetPoint("TOPLEFT", pad + 4, y)
            local wrap = TextW(part.label) + TextW(part.value) + 8 > w - 2 * pad - 4
            if wrap then y = y - O.SIDE_STEP end
            part.value:ClearAllPoints()
            part.value:SetPoint("TOPRIGHT", sp, "TOPRIGHT", -pad, y)
            part.wrapped = wrap
            y = y - O.SIDE_STEP
        end
    end
end

-- Tageswerte je Charakter (char.aucDay): eingestellt, verkauft, abgebrochen, Gewinn. Ein neuer Tag beginnt bei 0.
-- seen merkt sich verkaufte Auktionen (Kennung -> Zeit), damit jede nur einmal zaehlt.
O.SEEN_DAYS = 3
function O.Day()
    local c = mod.char
    if type(c) ~= "table" then return nil end
    local today = ns.Data.Day()
    local d = c.aucDay
    if type(d) ~= "table" or d.day ~= today then
        local seen = type(d) == "table" and type(d.seen) == "table" and d.seen or {}
        d = { day = today, posted = 0, sold = 0, cancelled = 0, gain = 0, seen = seen, v = 2 }
        c.aucDay = d
    end
    -- ab 0.166.0: Abgebrochen zaehlte jede Meldung AUCTION_CANCELED (auch verkaufte), der Gewinn den Erloes je Stapel mal
    -- Menge. Die Werte von heute aus 0.145 bis 0.165.1 beginnen deshalb einmal neu bei 0.
    if d.v ~= 2 then d.cancelled, d.gain, d.v = 0, 0, 2 end
    return d
end

local function Changed()
    if O.panel and O.panel:IsShown() then O.Update() end
    if ns.Pages and ns.Pages.RefreshAuctions then ns.Pages.RefreshAuctions() end
end

function O.OnPosted()
    local d = O.Day()
    if d then d.posted = d.posted + 1; Changed() end
end

-- ab 0.166.0: Das Spiel meldet AUCTION_CANCELED auch fuer verkaufte Auktionen (siehe Quick.OnCanceled). Gezaehlt wird
-- deshalb nur ein Abbruch, um den vorher gebeten wurde (C_AuctionHouse.CancelAuction, Brokers oder Blizzards Knopf),
-- und jede Auktion nur einmal.
O.asked = {}
function O.OnCancelAsked(id)
    if id ~= nil then O.asked[id] = true end
end

function O.OnCanceled(id)
    if id == nil or not O.asked[id] then return end
    O.asked[id] = nil
    local d = O.Day()
    if d then d.cancelled = d.cancelled + 1; Changed() end
end

-- Erloes einer verkauften Auktion vor dem Anteil des Auktionshauses (ab 0.166.0 der Betrag des ganzen Stapels)
function O.SoldGross(r)
    if Num(r.total) then return r.total end
    if Num(r.price) then return r.price * (r.qty or 1) end
    return nil
end

-- Neu verkaufte Auktionen zaehlen, Gewinn wie im Verkaufen (Erloes nach Anteil minus Einkauf, Advice.Profit)
function O.NoteSold(rows)
    local d = O.Day()
    if not d then return end
    local now = time()
    for id, t in pairs(d.seen) do if not Num(t) or now - t > O.SEEN_DAYS * 86400 then d.seen[id] = nil end end
    for _, r in ipairs(rows or {}) do
        if r.sold and r.id ~= nil and not d.seen[r.id] then
            d.seen[r.id] = now
            d.sold = d.sold + 1
            local gross = O.SoldGross(r)
            if gross then
                local qty = r.qty or 1
                local net = gross * (1 - ns.Data.Cut())
                local lot = ns.Lots and ns.Lots.ForKey(r.key) or nil
                local g = ns.Advice and ns.Advice.Profit({ net = net, qty = qty, key = r.key }, lot) or nil
                d.gain = d.gain + ((g and Num(g.gain)) and g.gain or math.floor(net + 0.5))
            end
        end
    end
end

function O.Init()
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_AUCTION_CREATED", function() mod:Call("Auktionen", O.OnPosted) end)
    pcall(mod.RegisterEvent, mod, "AUCTION_CANCELED", function(_, id) mod:Call("Auktionen", O.OnCanceled, id) end)
    local ah = rawget(_G, "C_AuctionHouse")
    if type(ah) == "table" and ah.CancelAuction and hooksecurefunc then
        pcall(hooksecurefunc, ah, "CancelAuction", function(id) O.OnCancelAsked(id) end)
    end
end

-- Werte der Spalte: laufend, beendet (verkauft, Erloes unterwegs) und heute
function O.SideValues(rows)
    local n, under, value = ns.AuctionsAH.Summary(rows)
    local sold, soldValue = 0, 0
    local cut = ns.Data.Cut()
    for _, r in ipairs(rows or {}) do
        if r.sold then
            sold = sold + 1
            local gross = O.SoldGross(r)
            if gross then soldValue = soldValue + gross * (1 - cut) end
        end
    end
    local d = O.Day() or {}
    return { n = n, under = under, value = value, sold = sold, soldValue = math.floor(soldValue + 0.5),
             dayPosted = d.posted or 0, daySold = d.sold or 0, dayCancelled = d.cancelled or 0, dayGain = d.gain or 0 }
end

function O.UpdateSide(rows, s)
    s = s or O.sideObj
    local sv = s and s.val
    if not sv then return end
    local v = O.SideValues(rows)
    sv.n:SetText(tostring(v.n))
    sv.under:SetText(v.under > 0 and (COLORS.under .. v.under .. "|r") or "0")
    sv.value:SetText(Money(v.value))
    sv.sold:SetText(tostring(v.sold))
    sv.soldValue:SetText(Money(v.soldValue))
    sv.dayPosted:SetText(tostring(v.dayPosted))
    sv.daySold:SetText(tostring(v.daySold))
    sv.dayCancelled:SetText(tostring(v.dayCancelled))
    local g = v.dayGain
    sv.dayGain:SetText((g < 0 and "|cffff6666" or "") .. ns.Radar.SignedMoney(g) .. (g < 0 and "|r" or ""))
    O.LayoutSide(s)
end

function O.Place()
    if not O.panel then return end
    local af = ns.AuctionsAH.Frame()
    local show = O.Enabled() and af ~= nil and af.IsShown and af:IsShown() and not (ns.AHTabs and ns.AHTabs.current) and true or false
    O.panel:SetShown(show)
    local h = ns.AuctionsAH.header
    if h and h.own then h.own:SetShown(not show and af ~= nil and ns.AHTouch()) end
    if show then
        if ns.Window.FillStatus then ns.Window.FillStatus(O.status) end
        O.Update(true)
    end
end

-- Broker-Liste an oder aus (Blizzard-Ansicht bleibt fuer Gebote)
function O.SetOn(on)
    mod.db.aucOwnList = on and true or false
    O.Place()
end

-- Unterschrift der Daten: nur neu fuellen, wenn sich etwas geaendert hat (die Uhr in AuctionsAH laeuft alle 0,3 Sek.)
local function Sig()
    local parts = {}
    for _, r in ipairs(ns.Auctions and ns.Auctions.rows or {}) do
        local kind = ns.AuctionsAH.Status(r)
        parts[#parts + 1] = tostring(r.id) .. ":" .. tostring(kind) .. ":" .. tostring(r.other) .. ":" .. tostring(r.sold)
    end
    return table.concat(parts, ",")
end

function O.Update(force)
    if not (O.panel and O.panel:IsShown()) then return end
    local sig = Sig()
    if force or sig ~= O.sig then
        O.sig = sig
        local rows = O.Rows()
        O.list:SetData(rows)
        local keep
        for _, r in ipairs(rows) do if O.sel and r.id == O.sel.id then keep = r end end
        O.sel = keep
    end
    local A = ns.Auctions
    local n = ns.AuctionsAH.Summary(A and A.rows)
    O.UpdateSide(A and A.rows)
    -- ab 0.144 stehen Anzahl, Unterboten und Wert in der Spalte links, oben nur Pruefung und Filter
    local text = ""
    if A and A.liveRun then text = text .. "|cff999999" .. L.AUCX_CHECKING .. "|r  " end
    local hidden = 0
    for _ in pairs(O.Hidden()) do hidden = hidden + 1 end
    if hidden > 0 then text = text .. "|cff999999" .. L.AUCO_FILTERED:format(hidden) .. "|r" end
    O.summary:SetText(text)
    On(O.check, A and not A.liveRun and n > 0)
    O.UpdateButtons()
end

function O.UpdateButtons()
    if not O.cancelOne then return end
    local LT = ns.Lots
    local r = O.sel
    On(O.cancelOne, r ~= nil and r.kind ~= "sold" and not (LT and LT.cancelling))
    On(O.market, r ~= nil)
    local nu = LT and LT.CountUndercut() or 0
    O.cancelUnder:SetText(nu > 0 and L.AUCX_CANCEL:format(nu) or L.AUCX_CANCEL_NONE)
    On(O.cancelUnder, nu > 0 and LT and not LT.cancelling)
end

-- Gewaehlte Auktion abbrechen (ein Klick, eine Auktion)
function O.CancelSelected()
    local r = O.sel and O.sel.row
    if not r or not ns.Lots then return end
    mod:Call("Auktionen", ns.Lots.CancelRow, r)
    O.Update(true)
end
