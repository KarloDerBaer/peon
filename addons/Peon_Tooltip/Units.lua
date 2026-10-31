-- Peon_Tooltip - Units.lua
-- Spieler-Tooltips: Name in Klassenfarbe, Klasse in der Spielerzeile, Gildenzeile.

local ADDON_NAME, ns = ...
local IsSecret = ns.IsSecret
local floor, format, ipairs = math.floor, string.format, ipairs

-- " (Player)" bzw. " (Spieler)" - lokalisiert ueber die Blizzard-Konstante PLAYER
local PLAYER_TAGS = {}
do
    local seen = {}
    for _, word in ipairs({ PLAYER, "Player" }) do
        if type(word) == "string" and word ~= "" and not seen[word] then
            seen[word] = true
            PLAYER_TAGS[#PLAYER_TAGS + 1] = " (" .. word .. ")"
        end
    end
end

local function Hex(c)
    return format("%02x%02x%02x", floor(c.r * 255 + 0.5), floor(c.g * 255 + 0.5), floor(c.b * 255 + 0.5))
end

local function StripColor(text)
    text = text:gsub("^|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r$", "")
    return text
end

local function GetLine(ttName, side, i)
    return _G[ttName .. side .. i]
end

-- Zeile `index` entfernen, indem alle folgenden Zeilen eine nach oben ruecken
local function RemoveLine(ttName, index, n)
    -- erst pruefen, ob irgendein Text geheim ist - dann gar nichts anfassen
    for j = index + 1, n do
        for _, side in ipairs({ "TextLeft", "TextRight" }) do
            local fs = GetLine(ttName, side, j)
            if fs and IsSecret(fs:GetText()) then return false end
        end
    end
    for j = index, n - 1 do
        for _, side in ipairs({ "TextLeft", "TextRight" }) do
            local cur, nxt = GetLine(ttName, side, j), GetLine(ttName, side, j + 1)
            if cur and nxt then
                cur:SetText(nxt:GetText())
                cur:SetTextColor(nxt:GetTextColor())
            end
        end
    end
    for _, side in ipairs({ "TextLeft", "TextRight" }) do
        local last = GetLine(ttName, side, n)
        if last then last:SetText(nil) end
    end
    return true
end

local function ProcessPlayer(tooltip)
    local _, unit = tooltip:GetUnit()
    if IsSecret(unit) or not unit then return end
    local isPlayer = UnitIsPlayer(unit)
    if IsSecret(isPlayer) or not isPlayer then return end

    local className, class = UnitClass(unit)
    if IsSecret(className) or IsSecret(class) or not className then return end
    local color = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
    local ttName = tooltip:GetName()
    if not color or not ttName then return end

    local hex = Hex(color)
    local n = tooltip:NumLines()
    local changed = false

    -- 1) Name in Klassenfarbe
    local line1 = GetLine(ttName, "TextLeft", 1)
    local text1 = line1 and line1:GetText()
    if not IsSecret(text1) and text1 then
        line1:SetText("|cff" .. hex .. StripColor(text1) .. "|r")
        changed = true
    end

    -- 2) Klasse vor "(Spieler)" einfuegen
    local classShown = false
    for i = 2, n do
        local fs = GetLine(ttName, "TextLeft", i)
        local text = fs and fs:GetText()
        if not IsSecret(text) and text then
            for _, tag in ipairs(PLAYER_TAGS) do
                local pos = text:find(tag, 1, true)
                if pos then
                    if not text:find(className, 1, true) then
                        fs:SetText(text:sub(1, pos - 1) .. " |cff" .. hex .. className .. "|r" .. text:sub(pos))
                        changed = true
                    end
                    classShown = true
                    break
                end
            end
        end
        if classShown then break end
    end

    -- 3) eigene Klassenzeile entfernen - nur wenn die Klasse jetzt oben steht
    if classShown then
        for i = 2, n do
            local fs = GetLine(ttName, "TextLeft", i)
            local text = fs and fs:GetText()
            if not IsSecret(text) and text == className then
                if RemoveLine(ttName, i, n) then changed = true end
                break
            end
        end
    end

    -- 4) Gildenzeile als <Gilde>
    local guild = GetGuildInfo(unit)
    if not IsSecret(guild) and guild and guild ~= "" then
        local wanted = "<" .. guild .. ">"
        for i = 2, tooltip:NumLines() do
            local fs = GetLine(ttName, "TextLeft", i)
            local text = fs and fs:GetText()
            if not IsSecret(text) and text and text:find(guild, 1, true) then
                if text ~= wanted then
                    fs:SetText(wanted)
                    changed = true
                end
                break
            end
        end
    end

    if changed then tooltip:Show() end   -- Groesse neu berechnen
end

local function OnUnitTooltip(tooltip)
    if tooltip ~= GameTooltip and not (ns.IsMainTip and ns.IsMainTip(tooltip)) then return end
    local db = ns.GetDB()
    if not db or not db.playerInfo then return end
    local ok, err = pcall(ProcessPlayer, tooltip)
    if not ok then ns.ReportError("Units", err) end
    -- Zeilen wurden evtl. umgebaut und neu angezeigt: Rahmen & Co. sicherheitshalber erneut setzen
    if ns.ApplyStyle then ns.ApplyStyle(tooltip) end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
else
    GameTooltip:HookScript("OnTooltipSetUnit", OnUnitTooltip)
end
