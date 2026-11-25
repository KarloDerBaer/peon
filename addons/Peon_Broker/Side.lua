-- Peon_Broker - Side.lua
-- Ab 0.137 (U5, Konzept Peon_Broker_Schlank.md 5, KarloDerBaer 24./25.11.2026): Seitenleiste rechts aussen am Fenster.
--   Haengt am Broker-Fenster (unterwegs) und immer am Auktionshaus (auch in Blizzards Kaufen, Verkaufen und Auktionen).
--   Ein Griff klappt sie auf und zu, der Zustand bleibt gemerkt (sideOpen, Vorgabe offen).
--   Oben zwei kleine Reiter Beobachten und Liste (sideTab), unter Liste die Auswahl der Einkaufsliste (dieselbe wie im
--   Reiter Listen, char.listSel). Je Zeile nur Symbol und Name. Der Gegenstand im Einkaufen ist hervorgehoben,
--   Erledigtes aus der Einkaufsliste grau.
--   Klick setzt den Gegenstand ins Einkaufen (aus der Liste mit der Menge, die noch fehlt, wie der Doppelklick in
--   Listen), Rechtsklick oeffnet das uebliche Menue.
-- Eigener Rahmen aus Peon.UI (Panel, ScrollList), Blizzards Fenster wird nicht veraendert.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local S = {}
ns.Side = S

S.WIDTH = 180
S.GRIP_W, S.GRIP_H = 16, 64
S.ROW_H = 22
S.TOP = 22      -- Abstand vom oberen Rand des Fensters (unter der Titelleiste)
S.BOTTOM = 4

local GREY = "|cff999999"
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

function S.IsOpen() return mod.db.sideOpen ~= false end
function S.Tab() return mod.db.sideTab == "list" and "list" or "watch" end

---------------------------------------------------------------------------
-- Zeilen
---------------------------------------------------------------------------
local function ByName(a, b)
    local la, lb = ns.Window.Lower(a.name), ns.Window.Lower(b.name)
    if la ~= lb then return la < lb end
    return tostring(a.key) < tostring(b.key)
end

-- Beobachten: jeder beobachtete Gegenstand
function S.WatchRows()
    local D, rows = ns.Data, {}
    for key, w in pairs(ns.Watch.Store()) do
        local e = D.Lookup(key)
        rows[#rows + 1] = { key = key, name = w.name or D.ItemName(key, e) or tostring(key),
            quality = w.q or (type(e) == "table" and e.ql) or nil, icon = w.icon or ns.Buy.Icon(D.ItemID(key)) }
    end
    table.sort(rows, ByName)
    return rows
end

-- Liste: Gegenstaende der gewaehlten Einkaufsliste, Erledigtes grau (done)
function S.ListRows()
    local B, D, rows = ns.Buy, ns.Data, {}
    local list = B.CurrentList()
    if not list then return rows end
    for key, it in pairs(list.items) do
        local e = D.Lookup(key)
        local need = B.Need(it, key)
        rows[#rows + 1] = { key = key, name = it.name or D.ItemName(key, e) or tostring(key), quality = it.q,
            icon = it.icon or B.Icon(D.ItemID(key)), done = need == 0, list = list.id }
    end
    table.sort(rows, ByName)
    return rows
end

function S.Rows()
    if S.Tab() == "list" then return S.ListRows() end
    return S.WatchRows()
end

---------------------------------------------------------------------------
-- Klick
---------------------------------------------------------------------------
function S.OnClick(r, button, owner)
    if not r then return end
    if button == "RightButton" then ns.Go.Menu(r, owner or S.panel); return end
    if r.list then
        mod:Call("Sprung", ns.Buy.ToShop, r)
    else
        mod:Call("Sprung", ns.Go.Focus, { key = r.key, name = r.name, from = "watch" })
    end
    S.Refresh()
end

---------------------------------------------------------------------------
-- Aufbau
---------------------------------------------------------------------------
function S.Build()
    if S.frame then return S.frame end
    local UI = Peon.UI
    local f = CreateFrame("Frame", "PeonBrokerSide", UIParent)
    f:SetWidth(S.WIDTH)
    if f.EnableMouse then f:EnableMouse(true) end
    f:Hide()
    S.frame = f
    local panel = UI.Panel(f, "list")
    panel:SetAllPoints(f)
    S.panel = panel

    -- Griff: am Rand des Fensters, auch bei zugeklappter Leiste zu sehen
    local g = CreateFrame("Button", "PeonBrokerSideGrip", UIParent)
    g:SetSize(S.GRIP_W, S.GRIP_H)
    local tex = g:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(g)
    tex:SetColorTexture(0.12, 0.1, 0.06, 0.9)
    g.bg = tex
    local arrow = g:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("CENTER")
    g.arrow = arrow
    g:SetScript("OnClick", function() mod:Call("Seitenleiste", S.Toggle) end)
    UI.SetTooltip(g, function() return { L.SIDE_TITLE, S.IsOpen() and L.SIDE_GRIP_CLOSE or L.SIDE_GRIP_OPEN } end)
    g:Hide()
    S.grip = g

    -- Reiter Beobachten und Liste
    S.tabs = UI.TopTabs(f, { { "watch", L.NTAB_WATCH }, { "list", L.SIDE_TAB_LIST } }, function(key)
        mod.db.sideTab = key
        S.Refresh()
    end)
    if S.tabs[1] then S.tabs[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -4) end

    -- Auswahl der Einkaufsliste (nur unter Liste)
    S.listDrop = UI.Dropdown(f, S.WIDTH - 16, function()
        local items = {}
        for i, l in ipairs(ns.Buy.Lists()) do items[#items + 1] = { i, l.name or "?" } end
        return items
    end, function() return tonumber(mod.char.listSel) or 1 end, function(i)
        mod.char.listSel = i
        if ns.Buy.view then mod:Call("Einkaufsliste", ns.Buy.Refresh) end
        S.Refresh()
    end)
    S.listDrop:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -34)

    S.list = UI.ScrollList(f, {
        extent = S.ROW_H,
        create = function(row)
            row.hl = row:CreateTexture(nil, "BACKGROUND")
            row.hl:SetAllPoints()
            row.hl:SetColorTexture(1, 0.82, 0, 0.18)
            row.hl:Hide()
            row.icon = UI.ItemIcon(row)
            row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row, "LEFT", 26, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.text:SetJustifyH("LEFT")
            if row.text.SetWordWrap then row.text:SetWordWrap(false) end
            row:SetScript("OnEnter", function(self)
                if self.data and ns.Window.ShowItemTooltip then ns.Window.ShowItemTooltip(self, self.data.key) end
            end)
            row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        end,
        init = function(row, r)
            if not r then return end
            if row.SetWidth then row:SetWidth(S.WIDTH - 26) end
            row.icon:Set(r.icon, r.quality)
            row.text:SetText(r.name or "")
            if r.done then row.text:SetTextColor(0.5, 0.5, 0.5)
            else row.text:SetTextColor(Peon.UI.QualityColor(r.quality or 1)) end
            row.hl:SetShown(S.IsCurrent(r))
        end,
        onClick = function(r, button) S.OnClick(r, button) end,
    })
    S.list.box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 6)
    if S.list.bar then
        S.list.bar:SetPoint("TOPLEFT", S.list.box, "TOPRIGHT", 4, 0)
        S.list.bar:SetPoint("BOTTOMLEFT", S.list.box, "BOTTOMRIGHT", 4, 0)
    end
    S.empty = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    S.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -70)
    S.empty:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    if S.empty.SetWordWrap then S.empty:SetWordWrap(true) end
    S.empty:Hide()
    return f
end

-- Gegenstand gerade im Einkaufen?
function S.IsCurrent(r)
    local F = ns.Focus
    return r ~= nil and F ~= nil and F.key ~= nil and F.key == r.key
end

---------------------------------------------------------------------------
-- Anhaengen und Auf- und Zuklappen
---------------------------------------------------------------------------
-- host = Rahmen, an dem die Leiste haengt (Broker-Fenster oder Blizzards Auktionshaus)
function S.Attach(host)
    if not host then return end
    S.Build()
    S.host = host
    local f, g = S.frame, S.grip
    if f.SetParent then f:SetParent(host) end
    if g.SetParent then g:SetParent(host) end
    local level = host.GetFrameLevel and host:GetFrameLevel() or 1
    if f.SetFrameLevel then f:SetFrameLevel(level + 20) end
    if g.SetFrameLevel then g:SetFrameLevel(level + 21) end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", host, "TOPRIGHT", 0, -S.TOP)
    f:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", 0, S.BOTTOM)
    S.Layout()
end

-- Leiste und Griff nach dem Zustand zeigen. Der Griff sitzt am rechten Rand der Leiste oder, zugeklappt, des Fensters.
function S.Layout()
    local f, g, host = S.frame, S.grip, S.host
    if not (f and g and host) then return end
    local shown = not host.IsShown or host:IsShown()
    local open = S.IsOpen()
    f:SetShown(shown and open)
    g:ClearAllPoints()
    if open then g:SetPoint("LEFT", f, "RIGHT", -2, 0) else g:SetPoint("LEFT", host, "RIGHT", -2, 0) end
    g:SetShown(shown)
    -- Pfeil zeigt, wohin der Klick klappt
    local atlas = open and "common-icon-backarrow" or "common-icon-forwardarrow"
    if not Peon.UI.SetAtlas(g.arrow, atlas, false) then g.arrow:SetColorTexture(1, 0.82, 0, 0.8) end
    if shown and open then S.Refresh() end
end

function S.Toggle()
    mod.db.sideOpen = not S.IsOpen()
    S.Layout()
end

-- Host schliesst: Leiste weg (haengt als Kind ohnehin am Host)
function S.Detach(host)
    if host ~= nil and S.host ~= host then return end
    if S.frame then S.frame:Hide() end
    if S.grip then S.grip:Hide() end
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
function S.Shown() return S.frame ~= nil and S.frame:IsShown() end

function S.Refresh()
    if not S.frame then return end
    if not S.Shown() then return end
    local tab = S.Tab()
    if S.tabs and S.tabs.selected ~= tab then
        S.tabs.selected = tab   -- ohne erneuten Aufruf von onSelect
        for _, t in ipairs(S.tabs) do
            if t.key == tab and PanelTemplates_SelectTab then pcall(PanelTemplates_SelectTab, t)
            elseif t.key ~= tab and PanelTemplates_DeselectTab then pcall(PanelTemplates_DeselectTab, t) end
        end
    end
    local isList = tab == "list"
    S.listDrop:SetShown(isList)
    if S.listDrop.fallback then
        local cur = ns.Buy.CurrentList()
        S.listDrop:SetText(cur and cur.name or L.BUY_NO_LISTS)
    elseif S.listDrop.GenerateMenu then
        pcall(S.listDrop.GenerateMenu, S.listDrop)
    end
    S.list.box:ClearAllPoints()
    S.list.box:SetPoint("TOPLEFT", S.frame, "TOPLEFT", 6, isList and -64 or -36)
    S.list.box:SetPoint("BOTTOMRIGHT", S.frame, "BOTTOMRIGHT", -20, 6)
    local rows = S.Rows()
    S.rows = rows
    S.list:SetData(rows)
    local empty
    if #rows == 0 then
        if isList then empty = #ns.Buy.Lists() == 0 and L.BUY_NO_LISTS or L.BUY_LIST_EMPTY
        else empty = L.SIDE_WATCH_EMPTY end
    end
    S.empty:SetText(empty and (GREY .. empty .. "|r") or "")
    S.empty:SetShown(empty ~= nil)
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
local function AHFrame() return rawget(_G, "AuctionHouseFrame") end

function S.OnAHShow()
    if ns.AHPlain and ns.AHPlain() then return end
    local f = AHFrame()
    if type(f) ~= "table" then return end
    S.Attach(f)   -- zu: AHTabs.OnAHHide ruft S.OnHostHide
end

-- Broker-Fenster unterwegs (Window.lua ruft das beim Zeigen)
function S.OnWindowShow(win)
    local f = AHFrame()
    if type(f) == "table" and f.IsShown and f:IsShown() and S.host == f then return end
    S.Attach(win)
end

-- Host zu (Window.lua beim Schliessen des Fensters, AHTabs.OnAHHide beim Schliessen des Auktionshauses):
-- am anderen Fenster weitermachen, wenn es offen ist
function S.OnHostHide(host)
    if host == nil or S.host ~= host then return end
    S.Detach(host)
    local W = ns.Window
    if W and W.frame and W.frame ~= host and W.frame:IsShown() then S.Attach(W.frame) end
end

function S.Init()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function() mod:Call("Seitenleiste", S.OnAHShow) end)
end
