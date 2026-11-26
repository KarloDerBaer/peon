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
S.GRIP_W, S.GRIP_H = 32, 84   -- ab 0.148 etwas groesser, mit Holzrahmen, ab 0.150 noch groesser
S.GRIP_TUCK = 16              -- ab 0.149: so weit steckt der Griff hinter der Leiste oder dem Fenster, ab 0.164 16 statt 8
S.GRIP_BAR = 5                -- ab 0.164: so viel Holz zeigt die rechte Kante etwa, der Pfeil steht links davon
S.TABS_LINE_Y = -34           -- ab 0.148: Trennlinie unter den Reitern
S.LIST_TOP, S.LIST_TOP_DROP, S.DROP_Y = -42, -70, -40
S.ROW_H = 22
-- ab 0.146 (Board KarloDerBaer): kuerzer als das Fenster, oben und unten frei, damit sie wie eine Schublade wirkt
S.TOP = 70      -- Abstand vom oberen Rand des Fensters
S.BOTTOM = 44   -- Abstand vom unteren Rand
S.WOOD = 3      -- ab 0.145: so weit ragt der Holzrahmen oben, rechts und unten ueber die Leiste (ab 0.147 eng)
S.WOOD_IN = 24  -- ab 0.147: so weit beginnt der Rahmen links hinter dem Fenster (die Leiste liegt dahinter)
S.UNDER = 4     -- ab 0.147: so weit beginnt die Leiste selbst hinter dem Fensterrand (kein Spalt)

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
    -- ab 0.145 (Board KarloDerBaer): Hintergrund wie die Leiste im Markt
    local panel = UI.Panel(f, "categories")
    panel:SetAllPoints(f)
    S.panel = panel

    -- Griff: am Rand des Fensters, auch bei zugeklappter Leiste zu sehen
    local g = CreateFrame("Button", "PeonBrokerSideGrip", UIParent)
    g:SetSize(S.GRIP_W, S.GRIP_H)
    local tex = g:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(g)
    tex:SetColorTexture(0.13, 0.1, 0.07, 1)
    g.bg = tex
    local arrow = g:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    -- ab 0.149 in der Mitte des sichtbaren Teils, ab 0.164 zwischen Leiste und rechter Kante (Wunsch KarloDerBaer:
    -- Griff halb so breit sichtbar, der Pfeil gerade noch zu sehen)
    arrow:SetPoint("CENTER", (S.GRIP_TUCK + S.GRIP_W - S.GRIP_BAR) / 2 - S.GRIP_W / 2, 0)
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
    -- ab 0.148 (Bild von KarloDerBaer): Trennlinie zwischen den Reitern und der Liste
    S.tabsLine = UI.Divider(f, S.WIDTH - 12)
    S.tabsLine:SetPoint("TOPLEFT", f, "TOPLEFT", 6, S.TABS_LINE_Y)

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
    S.listDrop:SetPoint("TOPLEFT", f, "TOPLEFT", 8, S.DROP_Y)

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
    S.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 10, S.LIST_TOP_DROP - 6)
    S.empty:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    if S.empty.SetWordWrap then S.empty:SetWordWrap(true) end
    S.empty:Hide()
    return f
end

-- 0.145 hatte eine hellere Bildlaufleiste (WowClassicScrollBar). Forever kennt deren Bilder nicht (Warnung beim Laden,
-- Board KarloDerBaer), ab 0.146 wieder MinimalScrollBar wie Blizzards Leiste im Markt.

-- ab 0.145 (Board KarloDerBaer): Holzrahmen wie am Auktionshaus oben, rechts und unten. Die linke Seite fehlt, die
-- Kanten laufen unter dem Fenster heraus, so wirkt die Leiste wie eine Schublade.
-- ab 0.147 (Bild von KarloDerBaer): Die obere Kante des Fensterrahmens ist die dicke Titelleiste. Oben steht jetzt die
-- untere Kante gespiegelt, rechts oben die gespiegelte Ecke unten rechts. Rahmen eng an der Liste.
S.WOOD_LAYOUT = "ButtonFrameTemplateNoPortrait"

-- Textur aus einem Atlas, senkrecht gespiegelt (oben und unten getauscht)
local function FlippedAtlas(parent, atlas)
    local CT = rawget(_G, "C_Texture")
    if not (CT and CT.GetAtlasInfo) then return nil end
    local ok, info = pcall(CT.GetAtlasInfo, atlas)
    if not (ok and type(info) == "table" and info.file) then return nil end
    local t = parent:CreateTexture(nil, "OVERLAY")
    if not pcall(t.SetTexture, t, info.file) then return nil end
    t:SetTexCoord(info.leftTexCoord or 0, info.rightTexCoord or 1, info.bottomTexCoord or 1, info.topTexCoord or 0)
    t:SetSize(info.width or 16, info.height or 16)
    return t, info
end

local function Offset(piece)
    if not (piece and piece.GetPoint) then return 0, 0 end
    local ok, _, _, _, x, y = pcall(piece.GetPoint, piece, 1)
    if not ok then return 0, 0 end
    return tonumber(x) or 0, tonumber(y) or 0
end

-- Holzrahmen ohne linke Seite auf einen NineSlice-Rahmen d legen: Layout des Fensters, oben die untere Kante und Ecke
-- gespiegelt (die obere Kante des Layouts ist die dicke Titelleiste), rechts die Kante von Ecke zu Ecke.
function S.ApplyWood(d)
    local NSU = rawget(_G, "NineSliceUtil")
    if not (d and NSU and NSU.ApplyLayoutByName) then return false end
    if d.EnableMouse then d:EnableMouse(false) end
    if not pcall(NSU.ApplyLayoutByName, d, S.WOOD_LAYOUT) then d:Hide(); return false end
    for _, k in ipairs({ "TopLeftCorner", "LeftEdge", "BottomLeftCorner", "Center", "TopEdge", "TopRightCorner" }) do
        local t = rawget(d, k)
        if type(t) == "table" and t.Hide then t:Hide() end
    end
    local be, br = rawget(d, "BottomEdge"), rawget(d, "BottomRightCorner")
    if not (be and br) then return false end
    local bx, by = Offset(br)
    be:ClearAllPoints()
    be:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, by)
    be:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
    -- oben: Ecke und Kante von unten, gespiegelt
    local tr = FlippedAtlas(d, "UI-Frame-Metal-CornerBottomRight")
    local te, info = FlippedAtlas(d, "_UI-Frame-Metal-EdgeBottom")
    if tr and te then
        tr:SetPoint("TOPRIGHT", d, "TOPRIGHT", bx, -by)
        te:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -by)
        te:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)
        te:SetHeight((info and info.height) or 16)
        d.woodTop = { tr, te }
    end
    -- rechte Kante von Ecke zu Ecke
    local re = rawget(d, "RightEdge")
    if re and tr then
        re:ClearAllPoints()
        re:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0)
        re:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
    end
    return true
end

function S.BuildWood(host)
    local f = S.frame
    if not f or S.wood then return end
    local d = Peon.UI.TryFrame("Frame", nil, f, "NineSlicePanelTemplate")
    if not d then return end
    S.wood = d
    d:SetPoint("TOPLEFT", f, "TOPLEFT", -S.WOOD_IN, S.WOOD)
    d:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", S.WOOD, -S.WOOD)
    if d.SetFrameLevel and f.GetFrameLevel then d:SetFrameLevel((f:GetFrameLevel() or 1) + 8) end
    S.ApplyWood(d)
end

-- ab 0.148 (Bild von KarloDerBaer): Griff im Holzlook. Ab 0.161 nur das Holzband aus dem Kantenbild: Das Bild
-- "_UI-Frame-Metal-EdgeBottom" ist ein Streifen, in dem das Holz nur einen Teil der Hoehe einnimmt, der Rest ist
-- durchsichtig. Bis 0.160 lag dadurch das Holz je nach Lage mit Spalt, eingerueckt oder ueberstehend. Jetzt wird nur
-- das Band mit dem Holz gezeigt (S.GRIP_BAND, Anteil der Bildhoehe von oben, geschaetzt aus den Bildern von
-- KarloDerBaer). So sitzt das Holz genau dort, wo der Streifen liegt: im Griff an seinem Rand, oben und unten ueber
-- die ganze Breite, rechts ueber die ganze Hoehe, die Ecken ueberschneiden sich. Links offen, dort steckt der Griff
-- hinter der Leiste. Grund ist ein Ausschnitt aus dem Hintergrund der Leiste.
S.GRIP_ATLAS = "_UI-Frame-Metal-EdgeBottom"
-- ab 0.163: oben und unten 8 bis 91 Prozent, im Spiel mit /broker griff gefunden (KarloDerBaer)
S.GRIP_BAND = { 0.08, 0.91 }
-- ab 0.163: rechte Kante mit eigenem Band und eigener Richtung (S.GRIP_R_FLIP: Bild andersherum gedreht), ab 0.164
-- fest 8 bis 91 wie oben und unten (im Spiel mit KarloDerBaer gefunden).
S.GRIP_BAND_R = { 0.08, 0.91 }
S.GRIP_R_FLIP = true

-- Holzband als Textur. side: "top" (wie im Bild), "bottom" (gespiegelt), "right" (senkrecht, wie bis 0.160).
-- Rueckgabe Textur, Staerke des Bands in Punkten
function S.WoodBand(parent, side)
    local CT = rawget(_G, "C_Texture")
    if not (CT and CT.GetAtlasInfo) then return nil end
    local ok, info = pcall(CT.GetAtlasInfo, S.GRIP_ATLAS)
    if not (ok and type(info) == "table" and info.file) then return nil end
    local t = parent:CreateTexture(nil, "OVERLAY")
    if not pcall(t.SetTexture, t, info.file) then return nil end
    t.side, t.info = side, info
    return t, S.ApplyBand(t)
end

-- Ausschnitt des Bands auf eine Textur legen, Rueckgabe Staerke in Punkten
function S.ApplyBand(t)
    local info, side = t.info or {}, t.side
    local l, r, tp, b = info.leftTexCoord or 0, info.rightTexCoord or 1, info.topTexCoord or 0, info.bottomTexCoord or 1
    local band = side == "right" and S.GRIP_BAND_R or S.GRIP_BAND
    local v0, v1 = band[1], band[2]
    local vt, vb = tp + (b - tp) * v0, tp + (b - tp) * v1
    if side == "bottom" then t:SetTexCoord(l, r, vb, vt)
    elseif side == "right" and S.GRIP_R_FLIP then t:SetTexCoord(l, vt, r, vt, l, vb, r, vb)
    elseif side == "right" then t:SetTexCoord(l, vb, r, vb, l, vt, r, vt)
    else t:SetTexCoord(l, r, vt, vb) end
    local h = (info.height or 16) * (v1 - v0)
    return math.max(1, math.floor(h + 0.5))
end

-- 0.162 und 0.163 hatten vorlaeufig /broker griff zum Einstellen der Baender im Spiel. Ab 0.164 sind die Werte fest
-- eingetragen, der Befehl entfaellt wie verabredet.

function S.BuildGripWood()
    local g = S.grip
    if not g or g.wood then return end
    local def = Peon.UI.BG and Peon.UI.BG.categories
    local CT = rawget(_G, "C_Texture")
    if def and CT and CT.GetAtlasInfo and g.bg then
        local ok, info = pcall(CT.GetAtlasInfo, def[1])
        if ok and type(info) == "table" and info.file and pcall(g.bg.SetTexture, g.bg, info.file) then
            local l, r, t, b = info.leftTexCoord or 0, info.rightTexCoord or 1, info.topTexCoord or 0, info.bottomTexCoord or 1
            local cw = math.min(1, S.GRIP_W / def[2])
            local ch = math.min(1, S.GRIP_H / def[3])
            g.bg:SetTexCoord(l, l + (r - l) * cw, t, t + (b - t) * ch)
        end
    end
    local te, h = S.WoodBand(g, "top")
    local be = S.WoodBand(g, "bottom")
    local re = S.WoodBand(g, "right")
    if not (te and be and re) then
        for _, t in ipairs({ te, be, re }) do if t then t:Hide() end end
        return
    end
    te:SetPoint("TOPLEFT", g, "TOPLEFT", 0, 0)
    te:SetPoint("TOPRIGHT", g, "TOPRIGHT", 0, 0)
    te:SetHeight(h)
    be:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, 0)
    be:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 0, 0)
    be:SetHeight(h)
    re:SetPoint("TOPRIGHT", g, "TOPRIGHT", 0, 0)
    re:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 0, 0)
    re:SetWidth(h)
    g.wood = { te, be, re }
    g.woodH = h
end

-- ab 0.149 (KarloDerBaer): Griff hinter Leiste, Rahmen und Fenster. Er bekommt die Schicht der Leiste und eine Ebene
-- unter ihr, so liegen Liste und Holzrahmen ueber seinem linken Ende.
function S.GripLayer()
    local f, g = S.frame, S.grip
    if not (f and g) then return end
    if g.SetFrameStrata and f.GetFrameStrata then g:SetFrameStrata(f:GetFrameStrata()) end
    local lv = f.GetFrameLevel and f:GetFrameLevel() or 1
    if g.SetFrameLevel then g:SetFrameLevel(math.max(0, lv - 1)) end
    local w = g.wood
    if type(w) == "table" and w.SetFrameLevel then w:SetFrameLevel(math.max(0, lv - 1) + 2) end
end

-- ab 0.147 (KarloDerBaer): Die Leiste liegt hinter dem Fenster, eine Schicht tiefer. Der Griff bleibt davor.
S.STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
function S.BehindHost(host)
    local f = S.frame
    if not (f and f.SetFrameStrata and host and host.GetFrameStrata) then return false end
    local hs = host:GetFrameStrata()
    for i, s in ipairs(S.STRATA) do
        if s == hs and i > 1 then f:SetFrameStrata(S.STRATA[i - 1]); return true end
    end
    return false
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
    -- ab 0.149 (KarloDerBaer): Griff in der Schicht der Leiste, unter Leiste und Rahmen (S.GripLayer nach BehindHost)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", host, "TOPRIGHT", -S.UNDER, -S.TOP)
    f:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", -S.UNDER, S.BOTTOM)
    S.BehindHost(host)
    S.BuildWood(host)
    S.BuildGripWood()
    S.GripLayer()
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
    -- ab 0.145 rechts neben dem Holzrahmen, ab 0.148 direkt daran (Bild von KarloDerBaer: war zu weit rechts)
    local edge = S.wood and S.wood:IsShown() and S.WOOD or 0
    -- ab 0.149 steckt der Griff ein Stueck hinter Leiste oder Fenster
    if open then g:SetPoint("LEFT", f, "RIGHT", edge - S.GRIP_TUCK, 0) else g:SetPoint("LEFT", host, "RIGHT", -S.GRIP_TUCK, 0) end
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
    S.list.box:SetPoint("TOPLEFT", S.frame, "TOPLEFT", 6, isList and S.LIST_TOP_DROP or S.LIST_TOP)
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
