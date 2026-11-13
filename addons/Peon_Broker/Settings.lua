-- Peon_Broker - Settings.lua
-- Ab 0.70 (Wunsch KarloDerBaer, 12.11.2026): Fenster "Einstellungen" fuer Fokus und Radar mit Peon.UI.
-- Ab 0.74 so gross wie das Broker-Fenster, ueber dem Auktionshaus, mit OK und Abbrechen (vorher klein, Teile lagen
-- uebereinander). Zwei Spalten, jede Zeile hat Beschriftung links und das Feld rechts auf derselben Hoehe.
-- Jedes Fenster wird aus einer Liste von Zeilen gebaut (S.SPECS[art]):
--   { "col" }                                          ab hier zweite Spalte
--   { "head", Text }                                   Ueberschrift
--   { "note", Text }                                   grauer Hinweis
--   { "check", Schluessel, Text, Tooltip, off = fn }   Haken (off = gesperrt, z. B. "kommt spaeter")
--   { "slider", Schluessel, Text, min, max, Schritt, Anzeige = fn, off = fn }
--   { "money", Schluessel, Text, Faktor, off = fn }    Geld eingeben, gespeichert in Einheiten von Faktor Kupfer
--   { "choice", Schluessel, Text, Liste, test = fn }   Auswahlliste (ab 0.91), Liste = { { Wert, Text } } oder Funktion,
--                                                      test(wert) spielt die Auswahl ab (z. B. Ton)
-- Aenderungen gelten erst mit OK (S.tmp), dann schreibt das Fenster in mod.db und ruft S.changed[art].

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local S = {}
ns.Settings = S

S.WIDTH, S.HEIGHT = 800, 538
S.COL_W = 360          -- Breite einer Spalte
S.LABEL_W = 178        -- Beschriftung links
S.SLIDER_W = 96
S.frames = {}
S.SPECS = {}
S.changed = {}
S.tmp = {}

local function Dec(v)
    local t = ("%.1f"):format(v or 0):gsub("%.0$", "")
    return (t:gsub("%.", L.DEC_SEP or "."))
end
S.Dec = Dec

-- Wert waehrend des Bearbeitens (noch nicht mit OK uebernommen)
function S.Get(kind, key)
    local t = S.tmp[kind]
    if t and t[key] ~= nil then return t[key] end
    return mod.db[key]
end

function S.Set(kind, key, v)
    S.tmp[kind] = S.tmp[kind] or {}
    S.tmp[kind][key] = v
end

-- Fokus: Abfragen je Minute und die Grenzen fuer das Urteil (Measure.lua)
S.SPECS.focus = {
    title = "SET_FOCUS_TITLE",
    { "head", "SET_FOCUS_QUERY" },
    { "slider", "focusRate", "SET_FOCUS_RATE", 2, 90, 1, function(v) return L.SET_RATE_FMT:format(v, Dec(60 / v)) end },
    { "note", "SET_FOCUS_RATE_NOTE" },
    { "head", "SET_FOCUS_BUY" },
    { "slider", "focusPriceTol", "SET_FOCUS_TOL", 0, 10, 1, function(v) return L.SET_PCT_FMT:format(v) end },
    { "check", "relistDefault", "SET_FOCUS_RELIST", "SET_FOCUS_RELIST_TIP" },   -- ab 0.91
    { "col" },
    { "head", "SET_FOCUS_VERDICT" },
    { "slider", "focusWindow", "SET_FOCUS_WINDOW", 2, 30, 1, function(v) return L.SET_MIN_FMT:format(v) end },
    { "slider", "focusFirst", "SET_FOCUS_FIRST", 10, 120, 5, function(v) return L.SET_SEC_FMT:format(v) end },
    { "slider", "focusSure", "SET_FOCUS_SURE", 30, 600, 10, function(v) return L.SET_SEC_FMT:format(v) end },
    { "slider", "focusMore", "SET_FOCUS_MORE", 0, 100, 5, function(v) return L.SET_PCT_FMT:format(v) end },
    { "slider", "focusGrow", "SET_FOCUS_GROW", 1, 50, 1, function(v) return L.SET_PCT_FMT:format(v) end },
}
-- Radar: welche Moeglichkeiten mit ihren Grenzen, Erneuern, Radar-Scan (ab 0.71)
local function VendorOff() return S.Get("radar", "radarVendorOn") == false end
local function BuyoutOff() return S.Get("radar", "radarBuyoutOn") == false end
local function RenewOff() return S.Get("radar", "radarRenew") == false end
S.SPECS.radar = {
    title = "SET_RADAR_TITLE",
    { "head", "SET_RADAR_KINDS" },
    { "check", "radarVendorOn", "SET_RADAR_VENDOR", "SET_RADAR_VENDOR_TIP" },
    { "money", "dealMinVendor", "SET_RADAR_MIN_GAIN", 1, off = VendorOff },
    { "check", "radarBuyoutOn", "SET_RADAR_BUYOUT", "SET_RADAR_BUYOUT_TIP" },
    { "money", "dealMinMarket", "SET_RADAR_MIN_GAIN", 100, off = BuyoutOff },
    { "slider", "buyoutHours", "SET_RADAR_HOURS", 1, 24, 1, function(v) return L.SET_HOURS_FMT:format(v) end, off = BuyoutOff },
    { "slider", "buyoutTargetPct", "SET_RADAR_TARGET_PCT", 0, 100, 5, function(v) return L.SET_PCT_FMT:format(v) end, off = BuyoutOff },
    { "slider", "buyoutMinQty", "SET_RADAR_MIN_QTY", 0, 5000, 50, function(v) return L.SET_QTY_FMT:format(v) end, off = BuyoutOff },
    { "slider", "buyoutMinLevels", "SET_RADAR_MIN_LEVELS", 2, 12, 1, function(v) return tostring(v) end, off = BuyoutOff },
    { "slider", "buyoutMinSales", "SET_RADAR_MIN_SALES", 0, 2000, 10, function(v) return L.SET_QTY_FMT:format(v) end, off = BuyoutOff },
    { "check", "radarSpecOn", "SET_RADAR_SPEC", "SET_RADAR_SPEC_TIP", off = function() return true end },
    { "col" },
    { "head", "SET_RADAR_GENERAL" },
    { "money", "radarReserve", "SET_RADAR_RESERVE", 10000 },
    { "check", "radarSound", "SET_RADAR_SOUND" },
    { "head", "SET_RADAR_UPDATE" },
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

-- Beobachten (ab 0.91, Fehlerbericht 20): Warnton und Chatnachricht je Richtung
local function Sounds()
    local out = {}
    for _, v in ipairs(ns.Watch and ns.Watch.SOUND_CHOICES or { "off" }) do out[#out + 1] = { v, ns.Watch.SoundName(v) } end
    return out
end
local function TestSound(v) if v ~= "off" and ns.Radar and ns.Radar.PlayAlert then pcall(ns.Radar.PlayAlert, v) end end
S.SPECS.watch = {
    title = "SET_WATCH_TITLE",
    { "head", "SET_WATCH_DOWN" },
    { "choice", "watchSoundDown", "SET_WATCH_SOUND", Sounds, test = TestSound },
    { "check", "watchChatDown", "SET_WATCH_CHAT" },
    { "col" },
    { "head", "SET_WATCH_UP" },
    { "choice", "watchSoundUp", "SET_WATCH_SOUND", Sounds, test = TestSound },
    { "check", "watchChatUp", "SET_WATCH_CHAT" },
    { "note", "SET_WATCH_NOTE" },
}

S.changed.focus = function() if ns.Focus then ns.Focus.chartN = nil; ns.Focus.Update() end end

local function Disabled(row)
    local f = row.off
    return type(f) == "function" and f() or false
end

-- Zeilenhoehen
S.STEP = { head = 26, note = 34, check = 30, slider = 30, money = 34, choice = 34 }

-- Fenster einer Art bauen
function S.Build(kind)
    local spec = S.SPECS[kind]
    local UI = Peon.UI
    if not (spec and UI) then return nil end
    local f = UI.Window("PeonBroker" .. (kind:gsub("^%l", string.upper)) .. "Settings",
        { title = L[spec.title] or spec.title, icon = "Interface\\Icons\\INV_Misc_Gear_01", width = S.WIDTH, height = S.HEIGHT })
    f:SetFrameStrata("DIALOG")
    f.controls = {}
    f:SetScript("OnHide", function() S.tmp[kind] = nil end)   -- ESC oder Schliessen = Abbrechen
    local x0, y0 = 30, -70
    local x, y = x0, y0
    local function Label(text, row)
        local t = UI.Text(f, "text", L[text] or text, S.LABEL_W)
        t:SetPoint("LEFT", f, "TOPLEFT", x + 6, y - 12)
        t:SetJustifyH("LEFT")
        return t
    end
    for _, row in ipairs(spec) do
        local typ = row[1]
        if typ == "col" then
            x, y = x0 + S.COL_W + 40, y0
        elseif typ == "head" then
            local t = UI.Text(f, "label", L[row[2]] or row[2])
            t:SetPoint("TOPLEFT", x, y)
            y = y - S.STEP.head
        elseif typ == "note" then
            local t = UI.Text(f, "small", "|cff999999" .. (L[row[2]] or row[2]) .. "|r", S.COL_W - 10)
            t:SetPoint("TOPLEFT", x + 6, y)
            y = y - S.STEP.note
        elseif typ == "check" then
            local key = row[2]
            local cb = UI.Check(f, L[row[3]] or row[3], S.Get(kind, key) and true or false, function(on)
                S.Set(kind, key, on)
                S.Refresh(kind)
            end, row[4] and { L[row[3]] or row[3], L[row[4]] or row[4] } or nil)
            cb:SetPoint("LEFT", f, "TOPLEFT", x, y - 12)
            f.controls[#f.controls + 1] = { row = row, frame = cb, kind = "check" }
            y = y - S.STEP.check
        elseif typ == "slider" then
            local key, fmt = row[2], row[7]
            local label = Label(row[3], row)
            local value = UI.Text(f, "text", "")
            value:SetPoint("RIGHT", f, "TOPLEFT", x + S.COL_W, y - 12)
            value:SetJustifyH("RIGHT")
            local cur = tonumber(S.Get(kind, key)) or row[4]
            value:SetText(fmt and fmt(cur) or tostring(cur))
            local sl = UI.Slider(f, S.SLIDER_W, row[4], row[5], row[6], cur, function(v)
                v = math.floor(v / row[6] + 0.5) * row[6]
                S.Set(kind, key, v)
                value:SetText(fmt and fmt(v) or tostring(v))
            end, nil, function() return "" end)
            sl:SetPoint("RIGHT", f, "TOPLEFT", x + S.COL_W - 82, y - 12)
            f.controls[#f.controls + 1] = { row = row, frame = sl, kind = "slider", value = value, label = label, fmt = fmt }
            y = y - S.STEP.slider
        elseif typ == "money" then
            local key, factor = row[2], row[4] or 1
            local label = Label(row[3], row)
            local m = UI.MoneyInput(f, function(amount)
                S.Set(kind, key, math.max(0, math.floor((amount or 0) / factor)))
            end)
            if m.SetScale then m:SetScale(0.85) end
            m:SetPoint("RIGHT", f, "TOPLEFT", (x + S.COL_W) / 0.85, (y - 12) / 0.85)
            m:SetAmount((tonumber(S.Get(kind, key)) or 0) * factor)
            f.controls[#f.controls + 1] = { row = row, frame = m, kind = "money", label = label, factor = factor }
            y = y - S.STEP.money
        elseif typ == "choice" then
            local key = row[2]
            local label = Label(row[3], row)
            local dd = UI.Dropdown(f, 150, row[4], function() return S.Get(kind, key) end, function(v)
                S.Set(kind, key, v)
                if row.test then row.test(v) end
                if f.Update then f:Update() end
            end)
            dd:SetPoint("RIGHT", f, "TOPLEFT", x + S.COL_W, y - 12)
            f.controls[#f.controls + 1] = { row = row, frame = dd, kind = "choice", label = label }
            y = y - S.STEP.choice
        end
    end
    -- unten: OK und Abbrechen
    f.ok = UI.Button(f, OKAY or "OK", 120, function() S.Apply(kind) end, "gold")
    f.ok:SetPoint("BOTTOMRIGHT", -14, 14)
    f.cancel = UI.Button(f, CANCEL or L.SET_CANCEL, 120, function() S.Hide(kind) end)
    f.cancel:SetPoint("RIGHT", f.ok, "LEFT", -6, 0)
    S.frames[kind] = f
    return f
end

-- Werte aus mod.db in die Felder (beim Oeffnen, nach Abbrechen)
function S.Load(kind)
    local f = S.frames[kind]
    if not f then return end
    S.tmp[kind] = nil
    for _, c in ipairs(f.controls) do
        local key = c.row[2]
        local v = mod.db[key]
        if c.kind == "check" then
            c.frame:SetChecked(v and true or false)
        elseif c.kind == "slider" then
            v = tonumber(v) or c.row[4]
            if c.frame.SetValue then pcall(c.frame.SetValue, c.frame, v) end
            c.value:SetText(c.fmt and c.fmt(v) or tostring(v))
        elseif c.kind == "money" then
            c.frame:SetAmount((tonumber(v) or 0) * c.factor)
        elseif c.kind == "choice" then
            S.tmp[kind] = nil
            if c.frame.GenerateMenu then pcall(c.frame.GenerateMenu, c.frame) end   -- gewaehlten Eintrag neu zeigen
        end
    end
    S.tmp[kind] = nil   -- SetValue meldet sich als Aenderung, das gilt nicht
end

-- OK: Aenderungen uebernehmen
function S.Apply(kind)
    local t = S.tmp[kind]
    if t then
        for k, v in pairs(t) do mod.db[k] = v end
    end
    S.tmp[kind] = nil
    if t and next(t) ~= nil and S.changed[kind] then mod:Call("Einstellungen", S.changed[kind]) end
    S.Hide(kind)
end

-- Gesperrte Zeilen grau (z. B. Werte einer abgeschalteten Art)
function S.Refresh(kind)
    local f = S.frames[kind]
    if not f then return end
    for _, c in ipairs(f.controls) do
        local off = Disabled(c.row)
        local col = off and 0.5 or 1
        if c.kind == "check" then
            if off then c.frame:Disable() else c.frame:Enable() end
        elseif c.kind == "slider" then
            if c.frame.SetEnabled then c.frame:SetEnabled(not off)
            elseif off and c.frame.Disable then c.frame:Disable() elseif c.frame.Enable then c.frame:Enable() end
            c.label:SetTextColor(col, col, col)
            c.value:SetTextColor(col, col, col)
        elseif c.kind == "money" then
            c.label:SetTextColor(col, col, col)
            for _, part in ipairs({ "gold", "silver", "copper" }) do
                local e = c.frame[part]
                if e and e.SetEnabled then e:SetEnabled(not off) end
            end
        end
    end
end

-- Fenster genau ueber dem Auktionshaus bzw. dem Broker-Fenster
local function Place(f)
    local top = (ns.Scan.ahOpen and rawget(_G, "AuctionHouseFrame")) or (ns.Window and ns.Window.frame)
    f:ClearAllPoints()
    if type(top) == "table" and top.IsShown and top:IsShown() then f:SetPoint("TOPLEFT", top, "TOPLEFT", 0, 0)
    else f:SetPoint("CENTER") end
end

function S.Show(kind)
    local f = S.frames[kind] or S.Build(kind)
    if not f then return end
    Place(f)
    S.Load(kind)
    S.Refresh(kind)
    f:Show()
end

function S.Hide(kind)
    local f = S.frames[kind]
    S.tmp[kind] = nil
    if f and f:IsShown() then f:Hide() end
end

function S.Toggle(kind)
    local f = S.frames[kind]
    if f and f:IsShown() then S.Hide(kind) else S.Show(kind) end
end

function S.IsShown(kind)
    local f = S.frames[kind]
    return f ~= nil and f:IsShown()
end
