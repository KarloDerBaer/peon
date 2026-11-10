-- Peon_Broker - AuctionsAH.lua
-- Umbau U9 (ab 0.50, Konzept Peon_Broker_Umbau.md, Abschnitt 7.3): Blizzards Reiter "Auktionen" ergaenzt.
--   Kopfzeile ueber der Liste: "12 laufen · 3 unterboten · Wert 140g" und Knopf "Pruefen" (Live-Pruefung aller
--   eigenen Gegenstaende, Auctions.lua A.StartLive).
--   Je Zeile rechts in der Gegenstandsspalte ein Status: Guenstigstes, gleichauf, unterboten: X, zu teuer, verkauft.
-- Technik: Broker schreibt nichts in Blizzards Liste. Eine eigene Uhr (OnUpdate eines eigenen Rahmens) liest
-- alle 0,3 Sek. die sichtbaren Zeilen (ScrollBox:ForEachFrame, rowData.auctionID) und setzt eigene Texte, die in
-- einer eigenen Tabelle (X.labels) haengen. Die Daten kommen aus Auctions.lua (A.Read, A.Evaluate, A.live).
-- Bei "Blizzard pur" nichts davon.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local X = {}
ns.AuctionsAH = X

X.TICK = 0.3
X.TOO_HIGH = 1.0   -- "zu teuer": Preis ueber dem oberen Rand des ueblichen Bereichs
X.labels = {}      -- Zeile -> FontString
X.COL_W = 150      -- ab 0.57: Breite der Spalte "Broker" am rechten Ende der Gegenstandsspalte
X.REREAD = 1       -- ab 0.57: hoechstens so oft (Sek.) neu lesen, wenn eine sichtbare Auktion fehlt

local COLORS = { best = "|cff60e060", equal = "|cffffd100", under = "|cffff9933", high = "|cffff4040", sold = "|cff999999" }

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end

function X.Frame()
    local f = rawget(_G, "AuctionHouseFrame")
    local af = type(f) == "table" and rawget(f, "AuctionsFrame")
    return type(af) == "table" and af or nil
end

function X.List()
    local af = X.Frame()
    local l = af and rawget(af, "AllAuctionsList")
    return type(l) == "table" and l or nil
end

-- Status einer eigenen Auktion (Zeile aus A.rows): kind, Text
function X.Status(r)
    if type(r) ~= "table" then return nil end
    if r.sold then return "sold", L.AUCX_SOLD end
    if r.status == "under" and r.other then return "under", L.AUCX_UNDER:format(Money(r.other)) end
    if r.status == "equal" then return "equal", L.AUCX_EQUAL end
    -- zu teuer: ueber dem ueblichen Bereich
    local e = ns.Data.Lookup(r.key)
    if type(e) == "table" and e.m and Num(r.price) then
        local ok, v = pcall(ns.Data.Evaluate, e, r.key, 1, ns.VendorPrice(r.itemID), mod.db)
        local b = ok and type(v) == "table" and v.band
        if b and r.price > b.high * X.TOO_HIGH then return "high", L.AUCX_HIGH:format(Money(b.rw or b.high)) end
    end
    return "best", L.AUCX_BEST
end

-- Zusammenfassung: laufend, unterboten, Wert (Sofortkauf der laufenden)
function X.Summary(rows)
    local n, under, value = 0, 0, 0
    for _, r in ipairs(rows or {}) do
        if not r.sold then
            n = n + 1
            if r.status == "under" then under = under + 1 end
            if Num(r.price) then value = value + r.price * (r.qty or 1) end
        end
    end
    return n, under, value
end

function X.ByID()
    local map = {}
    for _, r in ipairs(ns.Auctions and ns.Auctions.rows or {}) do if r.id then map[r.id] = r end end
    return map
end

local function RowData(row)
    local d = rawget(row, "rowData")
    if d == nil and type(row.GetRowData) == "function" then
        local ok, x = pcall(row.GetRowData, row)
        if ok then d = x end
    end
    return type(d) == "table" and d or nil
end

local function LabelFor(row)
    local fs = X.labels[row]
    if fs then return fs end
    fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local cells = rawget(row, "cells")
    local nameCell = type(cells) == "table" and cells[1]
    -- ab 0.57 als eigene Spalte: linksbuendig ab festem Abstand vor dem Ende der Gegenstandsspalte
    if type(nameCell) == "table" then fs:SetPoint("LEFT", nameCell, "RIGHT", -X.COL_W, 0)
    else fs:SetPoint("LEFT", row, "RIGHT", -300 - X.COL_W, 0) end
    fs:SetWidth(X.COL_W - 6)
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    X.nameCell = type(nameCell) == "table" and nameCell or X.nameCell
    X.labels[row] = fs
    return fs
end

-- Sichtbare Zeilen beschriften
function X.UpdateRows()
    local list = X.List()
    local box = list and rawget(list, "ScrollBox")
    if type(box) ~= "table" or type(box.ForEachFrame) ~= "function" then return 0 end
    local map, n, missing = X.ByID(), 0, false
    pcall(box.ForEachFrame, box, function(row)
        local d = RowData(row)
        local r = d and Num(d.auctionID) and map[d.auctionID]
        -- ab 0.57: nur wenn der Gegenstand passt (ein Status stand sonst beim falschen Gegenstand)
        local dk = d and type(d.itemKey) == "table" and d.itemKey.itemID
        if r and Num(dk) and r.itemID and dk ~= r.itemID then r = nil end
        if d and Num(d.auctionID) and not r then missing = true end
        local fs = LabelFor(row)
        if r then
            local kind, text = X.Status(r)
            fs:SetText((COLORS[kind] or "") .. (text or "") .. "|r")
            fs:Show()
            n = n + 1
        else
            fs:SetText("")
        end
    end)
    -- ab 0.57: sichtbare Auktion fehlt in Brokers Liste (neu eingestellt, Liste veraltet): neu lesen
    local now = GetTime and GetTime() or 0
    if missing and ns.Auctions and now - (X.lastReread or -99) >= X.REREAD then
        X.lastReread = now
        pcall(ns.Auctions.Read)
    end
    X.PlaceColumnHead(list)
    return n
end

-- Kopf der Spalte "Broker" ueber der Gegenstandsspalte (ab 0.57). Eigene Schrift, Blizzards Kopf bleibt unveraendert.
function X.PlaceColumnHead(list)
    local hc = list and rawget(list, "HeaderContainer")
    local cell = X.nameCell
    if type(hc) ~= "table" or type(cell) ~= "table" then return end
    if not X.colHead then
        local fs = hc:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetText(L.AUCX_COL)
        X.colHead = fs
        local line = hc:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 1, 1, 0.15)
        line:SetWidth(1)
        X.colLine = line
    end
    local r, l = cell.GetRight and cell:GetRight(), hc.GetLeft and hc:GetLeft()
    if type(r) ~= "number" or type(l) ~= "number" then return end
    local x = r - l - X.COL_W
    X.colHead:ClearAllPoints()
    X.colHead:SetPoint("LEFT", hc, "LEFT", x, 0)
    X.colLine:ClearAllPoints()
    X.colLine:SetPoint("TOP", hc, "TOPLEFT", x - 8, -3)
    X.colLine:SetPoint("BOTTOM", hc, "BOTTOMLEFT", x - 8, 3)
end

function X.UpdateHeader()
    local h = X.header
    if not h then return end
    local A = ns.Auctions
    local n, under, value = X.Summary(A and A.rows)
    local text = L.AUCX_HEAD:format(n, under > 0 and (COLORS.under .. under .. "|r") or "0", Money(value))
    if A and A.liveRun then text = text .. "  |cff999999" .. L.AUCX_CHECKING .. "|r" end
    h.text:SetText(text)
    if A and not A.liveRun and n > 0 then h.check:Enable() else h.check:Disable() end
end

function X.Update()
    if not ns.AHTouch() then return end
    X.UpdateHeader()
    X.UpdateRows()
end

-- Eigene Auktionen neu lesen (Blizzard fragt sie beim Oeffnen des Reiters selbst ab)
function X.OnOwned()
    local A = ns.Auctions
    if not A or not ns.AHTouch() then return end
    local af = X.Frame()
    if not (af and af.IsShown and af:IsShown()) then return end
    pcall(A.Read)
    X.Update()
end

function X.Build()
    if X.header or not ns.AHTouch() then return false end
    local af, list = X.Frame(), X.List()
    if not af or not list then return false end
    local h = CreateFrame("Frame", "PeonBrokerAuctionsHeader", af)
    h:SetSize(420, 20)
    h:SetPoint("BOTTOMRIGHT", list, "TOPRIGHT", -40, 10)
    local text = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("RIGHT", h, "RIGHT", -96, 0)
    text:SetJustifyH("RIGHT")
    h.text = text
    local b = CreateFrame("Button", nil, h, "UIPanelButtonTemplate")
    b:SetSize(90, 20)
    b:SetPoint("RIGHT", h, "RIGHT", 0, 0)
    b:SetText(L.AUCX_CHECK)
    b:SetScript("OnClick", function()
        local A = ns.Auctions
        if A then mod:Call("Auktionen", A.StartLive) end
        X.Update()
    end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(("|c%sPeon|r Broker"):format(Peon.COLOR))
        GameTooltip:AddLine(L.AUCX_CHECK_HINT, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    h.check = b
    -- eigene Uhr: nur solange der Reiter zu sehen ist
    local elapsed = 0
    h:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + (dt or 0)
        if elapsed < X.TICK then return end
        elapsed = 0
        mod:Call("Auktionen", X.Update)
    end)
    h:SetScript("OnShow", function() mod:Call("Auktionen", X.OnOwned) end)
    X.header = h
    return true
end

function X.Init()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function() mod:Call("Auktionen", X.Build) end)
    mod:RegisterEvent("OWNED_AUCTIONS_UPDATED", function() mod:Call("Auktionen", X.OnOwned) end)
end
