-- Peon_Broker - Tooltip.lua
-- Preiszeilen im Gegenstands-Tooltip nach dem Rechenmodell, Kapitel 3 (nur Daten des aktuellen Markts).
-- Ohne Umschalt nur Zeile 1, mit Umschalt alle Zeilen:
--   Broker (Umschalt)                         AH: 22s 80c ↗     (Stapel; oder "Händler: 1s")
--   Behalten: 20 (1 zu verkaufen)                               (nur wenn markiert, aktueller Charakter, ab 0.11)
--   Angebote: 120 (4) ↘                     (Scan vor 5 Min.)
--   AH                       Min 1s 20c ↘     Median 1s 60c ▬  (je Stueck)
--   7 Tage (4)               Min 1s 25c ▬     Median 1s 58c ↗  (je Stueck, Trend gegenueber Vortag)
--   Vorschlag                                 1s 20c je Stück
--   Einstellgebühr (8 Std.)                   20c             (Stapel, kommt bei Verkauf zurueck)
--   Händler                                   5c je Stück     (ab 0.19 immer, je Stueck zum Vergleich mit Min/Median)
--   Wenig Angebote.                                           (Hinweise)

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local T = {}
ns.Tooltip = T

local GREY = { 0.75, 0.75, 0.75 }
local HINT = { 1, 0.6, 0.3 }

local MEDIA = "Interface\\AddOns\\Peon_Broker\\Media\\"
T.TREND_FILES = { [2] = "trend_up2", [1] = "trend_up1", [0] = "trend_flat", [-1] = "trend_down1", [-2] = "trend_down2" }

local GOLD   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

-- Geld mit Muenzsymbolen, z. B. "1[G] 20[S]"; Nullwerte werden weggelassen
function T.Money(c)
    if type(c) ~= "number" then return "?" end
    local neg = c < 0
    c = math.floor(math.abs(c) + 0.5)
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. GOLD end
    if s > 0 then parts[#parts + 1] = s .. SILVER end
    if k > 0 or #parts == 0 then parts[#parts + 1] = k .. COPPER end
    return (neg and "-" or "") .. table.concat(parts, " ")
end

-- Trendstufe: 2 stark gestiegen, 1 gestiegen, 0 gleich, -1 gefallen, -2 stark gefallen (nil = kein Vergleich)
function T.TrendLevel(cur, prev)
    if type(cur) ~= "number" or type(prev) ~= "number" then return nil end
    local db = mod.db or {}
    local n = tonumber(db.trendNeutral) or 5
    local s = tonumber(db.trendStrong) or 20
    if s <= n then s = n + 1 end
    if prev == 0 then
        if cur == 0 then return 0 end
        return 2
    end
    local pct = (cur - prev) / math.abs(prev) * 100
    if pct >= s then return 2 end
    if pct > n then return 1 end
    if pct <= -s then return -2 end
    if pct < -n then return -1 end
    return 0
end

function T.Trend(cur, prev)
    local lv = T.TrendLevel(cur, prev)
    if lv == nil then return "" end
    return " |T" .. MEDIA .. T.TREND_FILES[lv] .. ":12:12:0:0|t"
end

function T.VendorPrice(link)
    return ns.VendorPrice(link)
end

-- Stapelgroesse des Gegenstands unter der Maus (nur wenn das Spiel sie liefert)
function T.StackCount(data)
    if type(data) ~= "table" or Peon.IsSecret(data) then return nil end
    local guid = data.guid
    if guid == nil or Peon.IsSecret(guid) then return nil end
    if C_Item and C_Item.GetItemLocation and C_Item.GetStackCount then
        local ok, loc = pcall(C_Item.GetItemLocation, guid)
        if ok and loc then
            local ok2, n = pcall(C_Item.GetStackCount, loc)
            if ok2 and type(n) == "number" and not Peon.IsSecret(n) then return n end
        end
    end
    return nil
end

local function Line(tooltip, left, right, lc, rc)
    lc, rc = lc or GREY, rc or { 1, 1, 1 }
    tooltip:AddDoubleLine(left, right, lc[1], lc[2], lc[3], rc[1], rc[2], rc[3])
end

local function Hint(tooltip, text)
    tooltip:AddLine(text, HINT[1], HINT[2], HINT[3])
end

-- "Min X ↘   Median Y ▬" (je Stueck)
local function MinMedian(min, median, pmin, pmedian)
    return ("%s %s%s   %s %s%s"):format(L.TT_MIN, T.Money(min), T.Trend(min, pmin),
        L.TT_MEDIAN, T.Money(median), T.Trend(median, pmedian))
end

-- Farbe der Marktlage (ab 0.21): gruen = guter Preis, orange = Markt faellt, rot = Dumping
T.STATE_COLORS = { good = "|cff60e060", falling = "|cffff9933", dump = "|cffff4040" }
function T.StateColor(state) return T.STATE_COLORS[state or "good"] or T.STATE_COLORS.good end

-- "74c – 1s 03c" plus Marktlage (faellt/steigt)
function T.RangeText(band)
    if not band then return "" end
    local text = T.Money(band.low) .. " – " .. T.Money(band.high)
    if band.trend == "down" then text = text .. " |cffff9933" .. L.RANGE_DOWN .. "|r"
    elseif band.trend == "up" then text = text .. " |cff60e060" .. L.RANGE_UP .. "|r" end
    return text
end

-- Zeile "Behalten" (nur aktueller Charakter), dezent hellblau
local KEEP = { 0.55, 0.78, 1 }
function T.KeepLine(tooltip, key)
    local K = ns.Keep
    if not K then return false end
    local text = K.TooltipText(key, ns.Data.ItemID(key))
    if not text then return false end
    tooltip:AddLine(text, KEEP[1], KEEP[2], KEEP[3])
    return true
end

-- Peon_Ledger (wenn geladen)
function T.Ledger()
    if not Peon.GetModule then return nil end
    local ok, l = pcall(Peon.GetModule, Peon, "ledger")
    if ok and type(l) == "table" then return l end
    return nil
end

-- Verkaufsquote aus Peon_Ledger (nur wenn geladen und es eigene Auktionen gab)
function T.SellRate(id)
    if type(id) ~= "number" or not Peon.GetModule then return nil end
    local ok, l = pcall(Peon.GetModule, Peon, "ledger")
    if not ok or type(l) ~= "table" or type(l.SellRate) ~= "function" then return nil end
    local ok2, rate, sold, back = pcall(l.SellRate, l, id)
    if not ok2 or type(sold) ~= "number" or type(back) ~= "number" or sold + back == 0 then return nil end
    return rate, sold, back
end

function T.SellRateLine(tooltip, key)
    local id = ns.Data.ItemID(key)
    local rate, sold, back = T.SellRate(id)
    if not sold then return false end
    local right = L.TT_SELLRATE_N:format(sold, sold + back)
    if rate then right = right .. " (" .. math.floor(rate * 100 + 0.5) .. " %)" end
    Line(tooltip, L.TT_SELLRATE, right)
    return true
end

-- Zeile "Neutral" (ab 0.42, Umbau U1, Konzept 5.2): guenstigstes Angebot im neutralen Auktionshaus je Stueck und
-- Abstand zum Heimatmarkt. Nur wenn es fuer den neutralen Markt Daten gibt. Einstellung tooltipNeutral:
-- "always" (auch ohne Umschalt), "shift" (Standard, nur erweitert), "off".
T.NEUTRAL_OLD = 86400   -- aelter als ein Tag: Alter dazuschreiben

function T.NeutralEntry(key)
    local nk = ns.NeutralMarketKey()
    if nk == ns.HomeMarketKey() then return nil end
    local e = ns.WithMarket(nk, ns.Data.Lookup, key)
    if type(e) ~= "table" or not e.m or e.gone then return nil end
    return e
end

function T.NeutralText(ne, homeMin)
    local text = T.Money(ne.m)
    if type(homeMin) == "number" and homeMin > 0 then
        local pct = math.floor((ne.m - homeMin) / homeMin * 100 + 0.5)
        local color = pct > 0 and "|cff60e060" or (pct < 0 and "|cffff9933" or "|cffffffff")
        text = text .. " " .. color .. "(" .. (pct > 0 and "+" or "") .. pct .. " %)|r"
    end
    local seen = ns.Data.Seen(ne)
    if seen and time() - seen > T.NEUTRAL_OLD then
        text = text .. " |cff999999" .. L.TT_SCAN_AGE:format(ns.Scan.Age(seen)) .. "|r"
    end
    return text
end

function T.NeutralLine(tooltip, key, homeEntry, details)
    local mode = mod.db and mod.db.tooltipNeutral or "shift"
    if mode == "off" or (mode == "shift" and not details) then return false end
    local ne = T.NeutralEntry(key)
    if not ne then return false end
    local homeMin = type(homeEntry) == "table" and not homeEntry.gone and homeEntry.m or nil
    Line(tooltip, L.TT_NEUTRAL, T.NeutralText(ne, homeMin))
    return true
end

-- Ab 0.42 rechnet der Tooltip immer im Heimatmarkt, auch am neutralen Auktionshaus (KarloDerBaer)
function T.AddLines(tooltip, link, count)
    return ns.WithHome(T.AddLinesHome, tooltip, link, count)
end

function T.AddLinesHome(tooltip, link, count)
    local db = mod.db
    if not db or not db.tooltipShow then return false end
    local key = ns.Data.KeyFromLink(link)
    if key == nil then return false end
    local e, market = ns.Data.Lookup(key)
    local hp = T.VendorPrice(link)
    local details = IsShiftKeyDown and IsShiftKeyDown() and true or false
    if not market or not market.lastScan or type(e) ~= "table" or not e.m then
        -- Heimatmarkt ohne Preis: Hinweis bei verkaufbaren Gegenstaenden, Behalten, Neutral (falls vorhanden)
        local shown = false
        if (not market or not market.lastScan) and hp and hp > 0 then
            tooltip:AddLine(("|c%sBroker|r %s"):format(Peon.COLOR, L.TT_NO_SCAN), GREY[1], GREY[2], GREY[3])
            shown = true
        end
        if T.KeepLine(tooltip, key) then shown = true end
        if T.NeutralLine(tooltip, key, nil, details) then shown = true end
        return shown
    end

    count = (count and count > 1) and count or 1
    local v = ns.Data.Evaluate(e, key, count, hp, db)

    -- Z1: der bessere Wert fuer den Stapel
    local title = ("|c%sBroker|r"):format(Peon.COLOR)
    if not details then title = title .. " |cff777777" .. L.TT_SHIFT_HINT .. "|r" end
    local right
    if v.ah then
        -- ab 0.21: guenstigstes Angebot (so wird eingestellt), Farbe = Marktlage: gruen gut, orange faellt, rot Dumping
        right = L.TT_BEST_AH .. " " .. T.StateColor(v.state) .. T.Money(v.erl) .. "|r" .. T.Trend(v.erl, v.erlVor)
    else
        right = L.TT_BEST_VENDOR .. " " .. T.Money(v.hw)
    end
    Line(tooltip, title, right, { 1, 1, 1 })
    T.KeepLine(tooltip, key)
    if not details then
        T.NeutralLine(tooltip, key, e, false)
        return true
    end

    -- Z2: Angebote
    Line(tooltip, L.TT_OFFERS2:format(e.q or 0, e.n or 0) .. T.Trend(e.q, e.pq),
        "|cff999999" .. L.TT_SCAN_AGE:format(ns.Scan.Age(market.lastScan)) .. "|r", { 1, 1, 1 })
    -- Z3: AH je Stueck (bei "keine Angebote": zuletzt gesehen, grau)
    Line(tooltip, e.gone and L.TT_AH_LAST or L.TT_AH, MinMedian(e.m, e.md, e.pm, e.pmd), nil, e.gone and GREY or nil)
    -- Z4: 7 Tage je Stueck, ab 2 Tageswerten, Trend gegenueber Vortag
    local w = v.week
    if db.tooltipAvg and w.days >= 2 then
        Line(tooltip, L.TT_7D_N:format(w.days), MinMedian(w.min, w.median, w.pmin, w.pmedian))
    end
    -- Ueblicher Bereich (Kapitel 7, ab 0.21)
    if v.band then Line(tooltip, (v.band.src == "client" and L.TT_RANGE_CLIENT or L.TT_RANGE):format(v.band.days), T.RangeText(v.band)) end
    -- Absatz des Marktes (ab 0.23.1): "Absatz (6 Std.)  ≈ 30/Std. · 70 % verkauft"
    local sr = ns.Sales and ns.Sales.Stats(e, nil, key)
    if sr then Line(tooltip, sr.src == "client" and L.TT_SALES_CLIENT or L.TT_SALES_NOW:format(tonumber(db.salesWindow) or 6), ns.Sales.TooltipText(sr)) end
    -- Eigene Verkaufsquote aus Peon_Ledger (ab 0.22): "Deine Verkäufe (30 T.): 4 von 6 (67 %)"
    T.SellRateLine(tooltip, key)
    -- Herstellen (ab 0.24, Berufe): Materialkosten und Gewinn, wenn ein erlerntes Rezept das herstellt
    local craft = ns.Craft and ns.Craft.TooltipText(key)
    if craft then Line(tooltip, L.CRAFT_TT_LEFT, craft) end
    -- Z5, Z6: Vorschlag je Stueck, Einstellgebuehr fuer den Stapel
    Line(tooltip, L.TT_SUGGEST, L.TT_PER_UNIT:format(T.Money(v.vp)))
    if v.eg then Line(tooltip, L.TT_DEPOSIT:format(ns.Data.Duration(db)), T.Money(v.eg)) end
    -- Z7: Haendler je Stueck (ab 0.19 immer, auch wenn Zeile 1 den Haendler zeigt)
    if db.tooltipVendor and hp and hp > 0 then Line(tooltip, L.TT_VENDOR, L.TT_PER_UNIT:format(T.Money(hp))) end
    -- Neutrales Auktionshaus (ab 0.42)
    T.NeutralLine(tooltip, key, e, true)
    -- Hinweise
    if db.tooltipHint then
        if e.gone then
            Hint(tooltip, L.HINT_GONE:format(ns.Scan.Age(ns.Data.Seen(e))))
        else
            if v.state == "falling" then Hint(tooltip, L.HINT_FALLING)
            elseif v.dump then Hint(tooltip, v.band and L.HINT_DUMP_RANGE or L.HINT_DUMP2) end
            if (e.n or 0) < ns.Data.FEW then Hint(tooltip, L.HINT_FEW2) end
            local seen = ns.Data.Seen(e)
            if seen and time() - seen > 3 * 86400 then Hint(tooltip, L.HINT_OLD) end
        end
    end
    return true
end

function T.OnItem(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= rawget(_G, "ItemRefTooltip") then return end
    if not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    if link == nil or Peon.IsSecret(link) then return end
    if T.AddLines(tooltip, link, T.StackCount(data)) and tooltip.Show then tooltip:Show() end
end

-- Umschalt gedrueckt/losgelassen, waehrend ein Gegenstands-Tooltip offen ist: neu aufbauen
function T.OnModifier(key)
    if type(key) ~= "string" or not key:find("SHIFT") then return end
    local tt = GameTooltip
    if not tt or not tt.IsShown or not tt:IsShown() or not tt.GetItem then return end
    local _, link = tt:GetItem()
    if link == nil then return end
    if tt.RefreshData then tt:RefreshData() end
end

function T.Init()
    if T.hooked then return end
    T.hooked = true
    mod:RegisterEvent("MODIFIER_STATE_CHANGED", function(_, key) T.OnModifier(key) end)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            mod:Call("Tooltip", T.OnItem, tooltip, data)
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", function(self)
            mod:Call("Tooltip", T.OnItem, self)
        end)
    end
end
