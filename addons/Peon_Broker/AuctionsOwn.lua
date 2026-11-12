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
    -- Liste
    local lp = UI.Panel(c, "list", true)
    lp:SetPoint("TOPLEFT", 0, -34)
    lp:SetPoint("BOTTOMRIGHT", 0, 32)
    O.listPanel = lp
    O.list = UI.Table(lp, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return ns.Window.Lower(r.name) end,
              color = function(r) return UI.QualityColor(r.quality or 1) end },
            { key = "qty", title = L.FOCUS_R_QTY, width = 70, align = "RIGHT" },
            { key = "price", title = L.AUCO_COL_PRICE, width = 120, align = "RIGHT", format = function(v) return Num(v) and Money(v) or "" end },
            { key = "kind", title = L.AUCX_COL, width = 190, format = function(_, r) return (COLORS[r.kind] or "") .. (r.statusText or "") .. "|r" end,
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
        onEnter = function(row, r) if r then ns.Window.ShowItemTooltip(row, r.key) end end,
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
    local n, under, value = ns.AuctionsAH.Summary(A and A.rows)
    local text = L.AUCX_HEAD:format(n, under > 0 and (COLORS.under .. under .. "|r") or "0", Money(value))
    if A and A.liveRun then text = text .. "  |cff999999" .. L.AUCX_CHECKING .. "|r" end
    local hidden = 0
    for _ in pairs(O.Hidden()) do hidden = hidden + 1 end
    if hidden > 0 then text = text .. "  |cff999999" .. L.AUCO_FILTERED:format(hidden) .. "|r" end
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
