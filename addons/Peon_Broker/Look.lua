-- Peon_Broker - Look.lua
-- Ab 0.56: Bausteine fuer Brokers Flaechen im Aufbau des Blizzard-Auktionshauses (KarloDerBaer): links eine Spalte mit
-- allen Einstellungen, rechts die Liste, oben eine Leiste wie Blizzards Suchleiste. Die Rahmen sind Blizzards
-- InsetFrameTemplate mit Blizzards eigenen Hintergruenden des Auktionshauses (ab 0.57: Kategorien links,
-- Ergebnisliste rechts, helle Grautoene wie im Original, vorher Marmor). Listen bekommen
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

-- ab 0.58 wie Blizzards Reiter Verkaufen (KarloDerBaer): links hellgrau mit Verlauf, rechts glattes Dunkelgrau.
-- 0.57 kopierte von Kategorien und Auktionsliste, die in WoW Forever die schwarze Marmor-Grafik zeigen.
U.ATLAS_LEFT = "auctionhouse-background-sell-left"
U.ATLAS_LIST = "auctionhouse-background-sell-right"

local function HasAtlas(name)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil
end

-- Blizzards Vorbild-Rahmen im geoeffneten Auktionshaus: Reiter Verkaufen, links das Verkaufsfenster, rechts dessen
-- Angebotsliste. Rueckgabe die Hintergrund-Grafik oder nil (dann gilt der Atlas-Name).
U.SOURCES = {
    [U.ATLAS_LEFT] = { "ItemSellFrame" },
    [U.ATLAS_LIST] = { "ItemSellList" },
}
function U.SourceBg(kind)
    local f = rawget(_G, "AuctionHouseFrame")
    local path = U.SOURCES[kind]
    if type(f) ~= "table" or not path then return nil end
    for _, k in ipairs(path) do
        f = type(f) == "table" and rawget(f, k) or nil
    end
    local bg = type(f) == "table" and rawget(f, "Background") or nil
    return type(bg) == "table" and bg or nil
end

-- Grafik von Blizzards Rahmen uebernehmen (nur lesen): Atlas oder Datei mit Ausschnitt
function U.CopyTexture(src, tex)
    if type(src) ~= "table" or type(tex) ~= "table" then return false end
    local okA, atlas = pcall(function() return src:GetAtlas() end)
    if okA and type(atlas) == "string" and atlas ~= "" and tex.SetAtlas and pcall(tex.SetAtlas, tex, atlas) then return true end
    local okT, file = pcall(function() return src:GetTexture() end)
    if okT and file ~= nil and file ~= "" and pcall(tex.SetTexture, tex, file) then
        local okC, a, b, c, d, e, g, h, i = pcall(function() return src:GetTexCoord() end)
        if okC and type(a) == "number" and tex.SetTexCoord then pcall(tex.SetTexCoord, tex, a, b, c, d, e, g, h, i) end
        return true
    end
    return false
end

-- Rahmen wie Blizzards Listen und Kategorien. atlas = Blizzards Hintergrund (U.ATLAS_LEFT, U.ATLAS_LIST)
function U.Panel(parent, atlas)
    local f = TryFrame("Frame", nil, parent, "InsetFrameTemplate") or CreateFrame("Frame", nil, parent)
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetPoint("TOPLEFT", 3, -3)
    bg:SetPoint("BOTTOMRIGHT", -3, 3)
    f.marble = bg
    atlas = atlas or U.ATLAS_LIST
    -- zuerst genau die Grafik, die Blizzards Reiter Verkaufen zeigt, sonst Blizzards Atlas nach Namen
    if U.CopyTexture(U.SourceBg(atlas), bg) then f.copied = true; return f end
    if bg.SetAtlas and HasAtlas(atlas) and pcall(bg.SetAtlas, bg, atlas) then
        f.atlas = atlas
        return f
    end
    local ok = pcall(bg.SetTexture, bg, U.MARBLE, "REPEAT", "REPEAT")
    if ok then
        if bg.SetHorizTile then bg:SetHorizTile(true) end
        if bg.SetVertTile then bg:SetVertTile(true) end
    else
        bg:SetColorTexture(0.12, 0.12, 0.12, 1)
    end
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
    local left = U.Panel(c, U.ATLAS_LEFT)
    left:SetPoint("TOPLEFT", 0, -(U.BAR_H + U.GAP))
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(U.LEFT_W)
    local right = U.Panel(c, U.ATLAS_LIST)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", U.GAP, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    return bar, left, right
end
