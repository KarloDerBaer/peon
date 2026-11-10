-- Peon_Broker - Look.lua
-- Ab 0.56: Bausteine fuer Brokers Flaechen im Aufbau des Blizzard-Auktionshauses (KarloDerBaer): links eine Spalte mit
-- allen Einstellungen, rechts die Liste, oben eine Leiste wie Blizzards Suchleiste. Die Rahmen sind Blizzards
-- InsetFrameTemplate mit dem Marmor-Hintergrund, den das Auktionshaus in WoW Forever nutzt. Listen bekommen
-- Peon.NewList mit style = "ah" (Kern-API 17) und passen sich der Groesse ihres Rahmens an.

local ADDON_NAME, ns = ...

local U = {}
ns.Look = U

U.LEFT_W = 210   -- Breite der linken Spalte (Blizzards Kategorien sind etwa so breit)
U.BAR_H = 30     -- Hoehe der oberen Leiste
U.GAP = 4        -- Abstand zwischen den Rahmen
U.MARBLE = "Interface\\FrameGeneral\\UI-Background-Marble"

local function TryFrame(kind, name, parent, template)
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then return f end
    return nil
end

-- Rahmen wie Blizzards Listen und Kategorien
function U.Panel(parent)
    local f = TryFrame("Frame", nil, parent, "InsetFrameTemplate") or CreateFrame("Frame", nil, parent)
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetPoint("TOPLEFT", 3, -3)
    bg:SetPoint("BOTTOMRIGHT", -3, 3)
    local ok = pcall(bg.SetTexture, bg, U.MARBLE, "REPEAT", "REPEAT")
    if ok then
        if bg.SetHorizTile then bg:SetHorizTile(true) end
        if bg.SetVertTile then bg:SetVertTile(true) end
    else
        bg:SetColorTexture(0.12, 0.12, 0.12, 1)
    end
    f.marble = bg
    return f
end

-- Ueberschrift in der linken Spalte (gelb wie Blizzards Beschriftungen)
function U.Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
    fs:SetJustifyH("LEFT")
    fs:SetText(text or "")
    return fs
end

-- Erklaerender Text (weiss, umbricht)
function U.Note(parent, width)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    if fs.SetJustifyV then fs:SetJustifyV("TOP") end
    if width then fs:SetWidth(width) end
    return fs
end

function U.Button(parent, text, w, fn, template)
    local b = CreateFrame("Button", nil, parent, template or "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text or "")
    if fn then b:SetScript("OnClick", fn) end
    return b
end

-- Liste fuellt ihren Rahmen: bei jeder Groessenaenderung neu einpassen.
-- inset = { left, top, right, bottom } Abstaende zum Rahmen
function U.Fit(list, holder, inset)
    inset = inset or {}
    local l, t, r, b = inset[1] or 4, inset[2] or 4, inset[3] or 4, inset[4] or 4
    list.frame:ClearAllPoints()
    list.frame:SetPoint("TOPLEFT", holder, "TOPLEFT", l, -t)
    local function Apply()
        local w, h = holder:GetWidth(), holder:GetHeight()
        if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return end
        if list.SetSize then list:SetSize(w - l - r, h - t - b) end
    end
    if holder.HookScript then holder:HookScript("OnSizeChanged", Apply) end
    Apply()
    return Apply
end

-- Grundaufbau: obere Leiste, linke Spalte, rechter Rahmen. Rueckgabe bar, left, right.
function U.Layout(c)
    local bar = CreateFrame("Frame", nil, c)
    bar:SetPoint("TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", 0, 0)
    bar:SetHeight(U.BAR_H)
    local left = U.Panel(c)
    left:SetPoint("TOPLEFT", 0, -(U.BAR_H + U.GAP))
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(U.LEFT_W)
    local right = U.Panel(c)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", U.GAP, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    return bar, left, right
end
