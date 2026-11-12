-- Peon_Broker - Settings.lua
-- Ab 0.70 (Wunsch KarloDerBaer, 12.11.2026): kleine Fenster "Einstellungen" fuer Fokus und Radar mit Peon.UI.
-- Jedes Fenster wird aus einer Liste von Zeilen gebaut (S.SPECS[art]):
--   { "head", Text }                                   Ueberschrift
--   { "note", Text }                                   grauer Hinweis
--   { "check", Schluessel, Text, Tooltip, aus = fn }   Haken (aus = gesperrt, z. B. "kommt spaeter")
--   { "slider", Schluessel, Text, min, max, Schritt, Anzeige = fn, aus = fn }
--   { "money", Schluessel, Text, Faktor }              Geld eingeben, gespeichert in Einheiten von Faktor Kupfer
-- Aenderungen schreiben in mod.db und rufen S.changed[art] (Seite neu zeichnen). Die Werte stehen auch auf der
-- Optionsseite, wo es sie schon gab.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local S = {}
ns.Settings = S

S.WIDTH = 420
S.frames = {}
S.SPECS = {}
S.changed = {}

local function Dec(v)
    local t = ("%.1f"):format(v or 0):gsub("%.0$", "")
    return (t:gsub("%.", L.DEC_SEP or "."))
end
S.Dec = Dec

-- Fokus: Abfragen je Minute und die Grenzen fuer das Urteil (Measure.lua)
S.SPECS.focus = {
    title = "SET_FOCUS_TITLE",
    { "head", "SET_FOCUS_QUERY" },
    { "slider", "focusRate", "SET_FOCUS_RATE", 2, 90, 1, function(v) return L.SET_RATE_FMT:format(v, Dec(60 / v)) end },
    { "note", "SET_FOCUS_RATE_NOTE" },
    { "head", "SET_FOCUS_VERDICT" },
    { "slider", "focusWindow", "SET_FOCUS_WINDOW", 2, 30, 1, function(v) return L.SET_MIN_FMT:format(v) end },
    { "slider", "focusFirst", "SET_FOCUS_FIRST", 10, 120, 5, function(v) return L.SET_SEC_FMT:format(v) end },
    { "slider", "focusSure", "SET_FOCUS_SURE", 30, 600, 10, function(v) return L.SET_SEC_FMT:format(v) end },
    { "slider", "focusMore", "SET_FOCUS_MORE", 0, 100, 5, function(v) return L.SET_PCT_FMT:format(v) end },
    { "slider", "focusGrow", "SET_FOCUS_GROW", 1, 50, 1, function(v) return L.SET_PCT_FMT:format(v) end },
    { "head", "SET_FOCUS_BUY" },
    { "slider", "focusPriceTol", "SET_FOCUS_TOL", 0, 10, 1, function(v) return L.SET_PCT_FMT:format(v) end },
}
-- Radar: welche Moeglichkeiten mit ihren Grenzen, Erneuern, Radar-Scan (ab 0.71)
local function VendorOff() return mod.db.radarVendorOn == false end
local function BuyoutOff() return mod.db.radarBuyoutOn == false end
local function RenewOff() return mod.db.radarRenew == false end
S.SPECS.radar = {
    title = "SET_RADAR_TITLE",
    { "head", "SET_RADAR_KINDS" },
    { "check", "radarVendorOn", "SET_RADAR_VENDOR", "SET_RADAR_VENDOR_TIP" },
    { "money", "dealMinVendor", "SET_RADAR_MIN_GAIN", 1, off = VendorOff },
    { "check", "radarBuyoutOn", "SET_RADAR_BUYOUT", "SET_RADAR_BUYOUT_TIP" },
    { "money", "dealMinMarket", "SET_RADAR_MIN_GAIN", 100, off = BuyoutOff },
    { "slider", "buyoutHours", "SET_RADAR_HOURS", 1, 24, 1, function(v) return L.SET_HOURS_FMT:format(v) end, off = BuyoutOff },
    { "slider", "buyoutMinQty", "SET_RADAR_MIN_QTY", 0, 5000, 50, function(v) return L.SET_QTY_FMT:format(v) end, off = BuyoutOff },
    { "slider", "buyoutMinLevels", "SET_RADAR_MIN_LEVELS", 2, 12, 1, function(v) return tostring(v) end, off = BuyoutOff },
    { "slider", "buyoutMinSales", "SET_RADAR_MIN_SALES", 0, 2000, 10, function(v) return L.SET_QTY_FMT:format(v) end, off = BuyoutOff },
    { "check", "radarSpecOn", "SET_RADAR_SPEC", "SET_RADAR_SPEC_TIP", off = function() return true end },
    { "head", "SET_RADAR_GENERAL" },
    { "money", "radarReserve", "SET_RADAR_RESERVE", 10000 },
    { "check", "radarSound", "SET_RADAR_SOUND" },
    { "check", "radarRenew", "SET_RADAR_RENEW", "SET_RADAR_RENEW_TIP" },
    { "slider", "radarRenewSec", "SET_RADAR_RENEW_SEC", 15, 600, 15, function(v) return L.SET_SEC_FMT:format(v) end, off = RenewOff },
    { "slider", "radarRenewMax", "SET_RADAR_RENEW_MAX", 30, 1200, 30, function(v) return L.SET_SEC_FMT:format(v) end, off = RenewOff },
    { "slider", "radarSearchPct", "SET_RADAR_SEARCH_PCT", 0, 80, 5, function(v) return L.SET_PCT_FMT:format(v) end },
}
S.changed.radar = function()
    local R = ns.Radar
    if not R then return end
    R.loaded = nil   -- Grenzen geaendert: Chancen aus der Datenbank neu rechnen
    if R.Shown() then R.Open(); R.Wake() end
end

S.changed.focus = function() if ns.Focus then ns.Focus.chartN = nil; ns.Focus.Update() end end

local function Disabled(row)
    local f = row.off
    return type(f) == "function" and f() or false
end

-- Fenster einer Art bauen
function S.Build(kind)
    local spec = S.SPECS[kind]
    local UI = Peon.UI
    if not (spec and UI) then return nil end
    local f = UI.Window("PeonBroker" .. (kind:gsub("^%l", string.upper)) .. "Settings",
        { title = L[spec.title] or spec.title, icon = "Interface\\Icons\\INV_Misc_Gear_01", width = S.WIDTH, height = 200 })
    f:SetFrameStrata("DIALOG")
    f.controls = {}
    local y = -66
    local x, w = 22, S.WIDTH - 44
    for _, row in ipairs(spec) do
        local typ = row[1]
        if typ == "head" then
            local t = UI.Text(f, "label", L[row[2]] or row[2])
            t:SetPoint("TOPLEFT", x, y)
            y = y - 22
        elseif typ == "note" then
            local t = UI.Text(f, "small", "|cff999999" .. (L[row[2]] or row[2]) .. "|r", w)
            t:SetPoint("TOPLEFT", x + 4, y)
            y = y - 30
        elseif typ == "check" then
            local key = row[2]
            local cb = UI.Check(f, L[row[3]] or row[3], mod.db[key] and true or false, function(on)
                mod.db[key] = on
                if S.changed[kind] then mod:Call("Einstellungen", S.changed[kind]) end
                S.Refresh(kind)
            end, row[4] and { L[row[3]] or row[3], L[row[4]] or row[4] } or nil)
            cb:SetPoint("TOPLEFT", x - 4, y + 4)
            f.controls[#f.controls + 1] = { row = row, frame = cb, kind = "check" }
            y = y - 28
        elseif typ == "slider" then
            local key, fmt = row[2], row[7]
            local label = UI.Text(f, "text", L[row[3]] or row[3])
            label:SetPoint("TOPLEFT", x + 4, y)
            local value = UI.Text(f, "text", "")
            value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -x, y)
            local cur = tonumber(mod.db[key]) or row[4]
            value:SetText(fmt and fmt(cur) or tostring(cur))
            local sl = UI.Slider(f, w - 8, row[4], row[5], row[6], cur, function(v)
                v = math.floor(v / row[6] + 0.5) * row[6]
                if mod.db[key] == v then return end
                mod.db[key] = v
                value:SetText(fmt and fmt(v) or tostring(v))
                if S.changed[kind] then mod:Call("Einstellungen", S.changed[kind]) end
            end, nil, function() return "" end)
            sl:SetPoint("TOPLEFT", x, y - 16)
            f.controls[#f.controls + 1] = { row = row, frame = sl, kind = "slider", value = value, label = label }
            y = y - 44
        elseif typ == "money" then
            local key, factor = row[2], row[4] or 1
            local label = UI.Text(f, "text", L[row[3]] or row[3])
            label:SetPoint("TOPLEFT", x + 4, y - 10)
            local m = UI.MoneyInput(f, function(amount)
                mod.db[key] = math.max(0, math.floor((amount or 0) / factor))
                if S.changed[kind] then mod:Call("Einstellungen", S.changed[kind]) end
            end)
            m:SetPoint("TOPRIGHT", f, "TOPRIGHT", -x, y)
            if m.SetScale then m:SetScale(0.85) end
            m:SetAmount((tonumber(mod.db[key]) or 0) * factor)
            f.controls[#f.controls + 1] = { row = row, frame = m, kind = "money", label = label }
            y = y - 36
        end
    end
    f:SetHeight(-y + 16)
    S.frames[kind] = f
    return f
end

-- Gesperrte Zeilen grau (z. B. Werte einer abgeschalteten Art)
function S.Refresh(kind)
    local f = S.frames[kind]
    if not f then return end
    for _, c in ipairs(f.controls) do
        local off = Disabled(c.row)
        if c.kind == "check" then
            if off then c.frame:Disable() else c.frame:Enable() end
        elseif c.kind == "slider" then
            if c.frame.SetEnabled then c.frame:SetEnabled(not off)
            elseif off and c.frame.Disable then c.frame:Disable() elseif c.frame.Enable then c.frame:Enable() end
            local col = off and 0.5 or 1
            c.label:SetTextColor(col, col, col)
        elseif c.kind == "money" then
            local col = off and 0.5 or 1
            c.label:SetTextColor(col, col, col)
        end
    end
end

-- Fenster neben dem Auktionshaus bzw. dem Broker-Fenster
local function Place(f)
    local top = (ns.Scan.ahOpen and rawget(_G, "AuctionHouseFrame")) or (ns.Window and ns.Window.frame)
    f:ClearAllPoints()
    if type(top) == "table" and top.IsShown and top:IsShown() then f:SetPoint("TOPLEFT", top, "TOPRIGHT", 6, 0)
    else f:SetPoint("CENTER") end
end

function S.Show(kind)
    local f = S.frames[kind] or S.Build(kind)
    if not f then return end
    Place(f)
    S.Refresh(kind)
    f:Show()
end

function S.Hide(kind)
    local f = S.frames[kind]
    if f and f:IsShown() then f:Hide() end
end

function S.Toggle(kind)
    local f = S.frames[kind]
    if f and f:IsShown() then f:Hide() else S.Show(kind) end
end

function S.IsShown(kind)
    local f = S.frames[kind]
    return f ~= nil and f:IsShown()
end
