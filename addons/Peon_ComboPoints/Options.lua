-- Peon_ComboPoints - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > ComboPoints, mit Vorschau.

local ADDON_NAME, ns = ...

local L = Peon.NewLocale()
L.DESC         = "Round combo points above the enemy nameplate (rogues only). Changes apply immediately."
L.HDR_LAYOUT   = "Size and position"
L.HDR_COLORS   = "Colours"
L.HDR_PREVIEW  = "Preview (3 of 5 points)"
L.SIZE         = "Point size"
L.GAP          = "Gap between points"
L.Y_OFFSET     = "Height above the health bar"
L.Y_OFFSET_HINT = "Negative values move the points down onto the health bar."
L.RING_PAD     = "Border thickness"
L.SHOW_SOCKETS = "Show empty points on the target"
L.SOCKETS_HINT = "Off: only filled points are shown, without empty sockets and border."
L.FILL         = "Filled point"
L.SOCKET       = "Empty point (with opacity)"
L.RING         = "Border (with opacity)"
L.SLASH_HINT   = "Chat: /peon combopoints opens this panel."

if GetLocale() == "deDE" then
    L.DESC         = "Runde Combo-Punkte über dem Nameplate des Gegners (nur Schurken). Änderungen wirken sofort."
    L.HDR_LAYOUT   = "Größe und Lage"
    L.HDR_COLORS   = "Farben"
    L.HDR_PREVIEW  = "Vorschau (3 von 5 Punkten)"
    L.SIZE         = "Punktgröße"
    L.GAP          = "Abstand zwischen den Punkten"
    L.Y_OFFSET     = "Höhe über dem Lebensbalken"
    L.Y_OFFSET_HINT = "Negative Werte schieben die Punkte nach unten auf den Lebensbalken."
    L.RING_PAD     = "Randstärke"
    L.SHOW_SOCKETS = "Leere Punkte am Ziel zeigen"
    L.SOCKETS_HINT = "Aus: Es erscheinen nur gefüllte Punkte, ohne leere Fassungen und Rand."
    L.FILL         = "Gefüllter Punkt"
    L.SOCKET       = "Leerer Punkt (mit Deckkraft)"
    L.RING         = "Rand (mit Deckkraft)"
    L.SLASH_HINT   = "Chat: /peon combopoints öffnet dieses Menü."
end

local previewRow

function ns.UpdatePreview()
    if not previewRow or not ns.mod.db then return end
    ns.StyleRow(previewRow, 5)
    local alpha = ns.mod.db.showSockets and 1 or 0
    for _, pip in ipairs(previewRow.pips) do
        pip.socket:SetAlpha(alpha)
        pip.ring:SetAlpha(alpha)
    end
end

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })

    local left = page:Column(16, -60)
    page:Add(left, page:Header(L.HDR_LAYOUT), 6)
    page:Add(left, page:Slider("size", L.SIZE))
    page:Add(left, page:Slider("gap", L.GAP))
    page:Add(left, page:Slider("yOffset", L.Y_OFFSET, L.Y_OFFSET_HINT))
    page:Add(left, page:Slider("ringPad", L.RING_PAD))
    page:Add(left, page:Check("showSockets", L.SHOW_SOCKETS), 2)
    local hint = page:NewContainer(14)
    page:AddHint(hint, L.SOCKETS_HINT, 0)
    page:Add(left, hint)

    local right = page:Column(330, -60)
    page:Add(right, page:Header(L.HDR_COLORS), 6)
    page:Add(right, page:Color("fillColor", L.FILL, false), 6)
    page:Add(right, page:Color("socketColor", L.SOCKET, true), 6)
    page:Add(right, page:Color("ringColor", L.RING, true), 20)

    -- Vorschau: dieselben Punkte wie am Nameplate, alle mit Wert 3
    page:Add(right, page:Header(L.HDR_PREVIEW), 10)
    local box = page:NewContainer(48)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
    previewRow = CreateFrame("Frame", nil, box)
    previewRow:SetPoint("LEFT", box, "LEFT", 12, 0)
    previewRow.pips = {}
    for i = 1, 5 do
        previewRow.pips[i] = ns.CreatePip(previewRow, i)
        previewRow.pips[i]:SetValue(3)
    end
    box.Refresh = ns.UpdatePreview
    page:Add(right, box)

    page:AddResetButton(L.SLASH_HINT, left, right)
    page:Register()
    ns.UpdatePreview()
end
