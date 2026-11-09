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
-- Abstand zum Heimatmarkt. Nur wenn es fuer den neutralen Markt Daten gibt. Ab 0.46 ein Baustein (tooltipLayout).
T.NEUTRAL_OLD = 86400   -- aelter als ein Tag: Alter dazuschreiben

function T.NeutralEntry(key)
    local nk = ns.NeutralMarketKey()
    if nk == ns.HomeMarketKey() then return nil end
    local e = ns.WithMarket(nk, ns.Data.Lookup, key)
    if type(e) ~= "table" or not e.m or e.gone then return nil end
    return e
end

-- Abstand in Prozent nach Gebuehr beider Haeuser (ab 0.43, U2). Ist der Anteil des neutralen Hauses noch nicht
-- gemessen, steht ein graues "?" dahinter.
function T.NeutralText(ne, homeMin)
    local text = T.Money(ne.m)
    if type(homeMin) == "number" and homeMin > 0 then
        local nk, hk = ns.NeutralMarketKey(), ns.HomeMarketKey()
        local netN = ne.m * (1 - ns.Data.Cut(nk))
        local netH = homeMin * (1 - ns.Data.Cut(hk))
        local pct = math.floor((netN - netH) / netH * 100 + 0.5)
        local color = pct > 0 and "|cff60e060" or (pct < 0 and "|cffff9933" or "|cffffffff")
        text = text .. " " .. color .. "(" .. (pct > 0 and "+" or "") .. pct .. " %)|r"
        if not ns.Data.CutSure(nk) then text = text .. " |cff999999?|r" end
    end
    local seen = ns.Data.Seen(ne)
    if seen and time() - seen > T.NEUTRAL_OLD then
        text = text .. " |cff999999" .. L.TT_SCAN_AGE:format(ns.Scan.Age(seen)) .. "|r"
    end
    return text
end

-- Ab 0.42 rechnet der Tooltip immer im Heimatmarkt, auch am neutralen Auktionshaus (KarloDerBaer)
function T.AddLines(tooltip, link, count)
    return ns.WithHome(T.AddLinesHome, tooltip, link, count)
end

---------------------------------------------------------------------------
-- Ab 0.46 (Umbau U5, Konzept Abschnitt 6): Tooltip aus Bausteinen, frei einstellbar.
-- Zeile 1 (Wert) steht immer oben, dahinter optional das Zeichen fuer Einkaufslisten und "(Umschalt)".
-- Die uebrigen Bausteine haben je Wann (immer / mit Umschalt / aus), Format und Reihenfolge.
-- Gespeichert in PeonBrokerDB.tooltipLayout = { value = fmt, mark = when, shifthint = when,
--   lines = { { key, when, fmt }, ... } }. Neue Bausteine spaeterer Versionen haengen sich hinten an (aus).
---------------------------------------------------------------------------
T.WHEN = { "always", "shift", "off" }
T.VALUE_FMT = { "both", "stack", "unit" }
-- Bausteine der Zeilen: key, Text, Formate (erstes = Standard), Vorgabe Wann
T.BLOCKS = {
    { key = "market",  fmts = { "min", "both" },                when = "shift" },
    { key = "range",   fmts = { "range", "mid", "midpct" },     when = "shift" },
    { key = "sales",   fmts = { "day", "hour" },                when = "shift" },
    { key = "sell",    fmts = { "net", "suggest", "deposit" },  when = "shift" },
    { key = "vendor",  fmts = { "unit", "stack" },              when = "shift" },
    { key = "merchant", fmts = nil,                              when = "shift" },   -- ab 0.52 (U11): Kaufpreis beim Haendler
    { key = "neutral", fmts = { "pct", "price" },               when = "shift" },
    { key = "craft",   fmts = nil,                               when = "shift" },
    { key = "own",     fmts = { "rate", "count" },              when = "shift" },
    { key = "chart",   fmts = { "d14", "d7", "d30" },           when = "shift" },   -- ab 0.47 (U6)
    { key = "hint",    fmts = nil,                               when = "shift" },
}
T.BLOCK = {}
for _, b in ipairs(T.BLOCKS) do T.BLOCK[b.key] = b end

-- Vorlagen
function T.Preset(name)
    local lay = { value = "both", mark = "always", shifthint = "off", lines = {} }
    for _, b in ipairs(T.BLOCKS) do
        local when, fmt = b.when, b.fmts and b.fmts[1] or nil
        if name == "slim" then when = "off"
        elseif name == "full" then
            when = "always"
            if b.key == "market" then fmt = "both" elseif b.key == "range" then fmt = "midpct" elseif b.key == "sell" then fmt = "deposit" end
        end
        lay.lines[#lay.lines + 1] = { key = b.key, when = when, fmt = fmt }
    end
    if name == "slim" then lay.value = "stack" end
    return lay
end

local function Valid(list, v)
    for _, x in ipairs(list or {}) do if x == v then return true end end
    return false
end

-- Einstellung pruefen und ergaenzen (fehlende Bausteine hinten an, aus; unbekannte weg)
function T.Normalize(lay)
    if type(lay) ~= "table" then lay = T.Preset("standard") end
    if not Valid(T.VALUE_FMT, lay.value) then lay.value = "both" end
    if not Valid(T.WHEN, lay.mark) then lay.mark = "always" end
    if not Valid(T.WHEN, lay.shifthint) then lay.shifthint = "off" end
    local seen, lines = {}, {}
    for _, l in ipairs(type(lay.lines) == "table" and lay.lines or {}) do
        local b = type(l) == "table" and T.BLOCK[l.key]
        if b and not seen[l.key] then
            seen[l.key] = true
            if not Valid(T.WHEN, l.when) then l.when = b.when end
            if b.fmts and not Valid(b.fmts, l.fmt) then l.fmt = b.fmts[1] end
            lines[#lines + 1] = l
        end
    end
    for _, b in ipairs(T.BLOCKS) do
        if not seen[b.key] then lines[#lines + 1] = { key = b.key, when = "off", fmt = b.fmts and b.fmts[1] or nil } end
    end
    lay.lines = lines
    return lay
end

-- Aktuelle Einstellung. Beim ersten Mal aus den alten Schaltern (tooltipVendor, tooltipHint, tooltipNeutral)
function T.Layout()
    local acc = mod.acc
    if type(acc) ~= "table" then return T.Preset("standard") end
    if type(acc.tooltipLayout) ~= "table" then
        local lay = T.Preset("standard")
        local db = mod.db or {}
        for _, l in ipairs(lay.lines) do
            if l.key == "vendor" and db.tooltipVendor == false then l.when = "off" end
            if l.key == "hint" and db.tooltipHint == false then l.when = "off" end
            if l.key == "neutral" and Valid(T.WHEN, db.tooltipNeutral) then l.when = db.tooltipNeutral end
        end
        acc.tooltipLayout = lay
    end
    acc.tooltipLayout = T.Normalize(acc.tooltipLayout)
    return acc.tooltipLayout
end

function T.SetPreset(name)
    if not mod.acc then return end
    mod.acc.tooltipLayout = T.Normalize(T.Preset(name))
end

-- Eintrag eines Bausteins in der Einstellung
function T.LayoutLine(key)
    for i, l in ipairs(T.Layout().lines) do if l.key == key then return l, i end end
    return nil
end

-- Baustein eine Stelle nach oben (-1) oder unten (+1)
function T.Move(key, dir)
    local lines = T.Layout().lines
    for i, l in ipairs(lines) do
        if l.key == key then
            local j = i + dir
            if j < 1 or j > #lines then return false end
            lines[i], lines[j] = lines[j], lines[i]
            return true
        end
    end
    return false
end

local function Shown(when, details)
    return when == "always" or (when == "shift" and details)
end

---------------------------------------------------------------------------
-- Daten eines Gegenstands fuer den Tooltip
---------------------------------------------------------------------------
-- Steht der Gegenstand auf einer Einkaufsliste?
function T.OnShopList(key)
    if ns.Watch and ns.Watch.Is(key) then return true end   -- ab 0.49: auch beobachtete Gegenstaende
    local B = ns.Buy
    if not B or not B.Lists then return false end
    local ok, lists = pcall(B.Lists)
    if not ok then return false end
    for _, l in ipairs(lists) do if type(l.items) == "table" and l.items[key] then return true end end
    return false
end

function T.Context(key, link, count)
    local db = mod.db
    local e, market = ns.Data.Lookup(key)
    local ctx = { key = key, count = (count and count > 1) and count or 1, hp = T.VendorPrice(link), market = market }
    if type(e) == "table" and e.m then
        ctx.e = e
        ctx.v = ns.Data.Evaluate(e, key, ctx.count, ctx.hp, db)
        ctx.band = ctx.v.band
        ctx.sr = ns.Sales and ns.Sales.Stats(e, nil, key)
        ctx.seen = ns.Data.Seen(e)
        ctx.cut = ns.Data.Cut()
        ctx.duration = ns.Data.Duration(db)
    end
    ctx.neutral = T.NeutralEntry(key)
    ctx.craft = ns.Craft and ns.Craft.TooltipText(key)
    local rate, sold, back = T.SellRate(ns.Data.ItemID(key))
    if sold then ctx.rate = { rate = rate, sold = sold, back = back } end
    ctx.onList = T.OnShopList(key)
    if ns.Vendors then ctx.merchant = ns.Vendors.TooltipText(ns.Data.ItemID(key)) end
    return ctx
end

---------------------------------------------------------------------------
-- Ausgabe
---------------------------------------------------------------------------
local SHOP_ICON = " |TInterface\\Icons\\INV_Misc_Bag_10:12:12:0:0|t"

-- Zeile 1: "18g 40s (20 x 95s) [Pfeil]" in der Farbe der Marktlage
function T.ValueText(ctx, fmt)
    local v, n = ctx.v, ctx.count
    if not v then return nil end
    local text
    if v.ah then
        local unit = v.entry
        if fmt == "unit" then
            text = T.Money(unit) .. " " .. L.TT_EACH
        else
            text = T.Money(v.erl)
            if fmt == "both" and n > 1 then text = text .. " |cffcccccc(" .. n .. " × " .. T.Money(unit) .. ")|r" end
        end
        text = T.StateColor(v.state) .. text .. "|r"
        local e = ctx.e
        if e.gone then text = text .. " |cff999999" .. L.TT_WORD_GONE .. "|r"
        elseif v.state == "falling" then text = text .. " |cffff9933" .. L.TT_WORD_FALLING .. "|r"
        elseif v.dump then text = text .. " |cffff4040" .. L.TT_WORD_DUMP .. "|r" end
        text = text .. T.Trend(v.erl, v.erlVor)
    else
        if fmt == "unit" then text = L.TT_BEST_VENDOR .. " " .. T.Money(ctx.hp) .. " " .. L.TT_EACH
        else
            text = L.TT_BEST_VENDOR .. " " .. T.Money(v.hw)
            if fmt == "both" and n > 1 then text = text .. " |cffcccccc(" .. n .. " × " .. T.Money(ctx.hp) .. ")|r" end
        end
    end
    return text
end

-- Text eines Bausteins (links, rechts) oder nil
function T.BlockText(key, fmt, ctx)
    local e, v = ctx.e, ctx.v
    if key == "market" then
        if not e then return nil end
        local parts = { (e.gone and L.TT_LAST or L.TT_FROM) .. " " .. T.Money(e.m) }
        if fmt == "both" and e.md then parts[#parts + 1] = L.TT_MEDIAN .. " " .. T.Money(e.md) end
        if not e.gone then parts[#parts + 1] = L.TT_PIECES:format(Peon.ShortNumber and Peon.ShortNumber(e.q or 0) or tostring(e.q or 0)) end
        if ctx.seen then parts[#parts + 1] = "|cff999999" .. ns.Scan.Age(ctx.seen) .. "|r" end
        return L.TT_MARKET, table.concat(parts, " · ")
    elseif key == "range" then
        local b = ctx.band
        if not b then return nil end
        if fmt == "mid" then return L.TT_USUAL, T.Money(b.rw) end
        if fmt == "midpct" and e and e.m and b.rw and b.rw > 0 then
            local pct = math.floor((e.m - b.rw) / b.rw * 100 + 0.5)
            return L.TT_USUAL, T.Money(b.rw) .. " |cff999999" .. L.TT_NOW_PCT:format((pct > 0 and "+" or "") .. pct) .. "|r"
        end
        return L.TT_USUAL, T.RangeText(b)
    elseif key == "sales" then
        local s = ctx.sr
        if not s then return nil end
        if fmt == "hour" or not s.perHour then return L.TT_SALES, ns.Sales.TooltipText(s) end
        local day = s.perHour * 24
        if day < 0.05 then return L.TT_SALES, L.TT_SALES_NONE end
        local txt = day >= 10 and tostring(math.floor(day + 0.5)) or ("%.1f"):format(day):gsub("%.", ",")
        return L.TT_SALES, L.TT_PER_DAY:format(txt)
    elseif key == "sell" then
        if not v or not v.vp then return nil end
        local txt = L.TT_PER_UNIT:format(T.Money(v.vp))
        if fmt ~= "suggest" then
            local net = v.vp * ctx.count * (1 - (ctx.cut or ns.Data.Cut()))
            txt = txt .. ", " .. L.TT_NET:format(T.Money(net), ctx.duration or 8)
        end
        if fmt == "deposit" and v.eg then txt = txt .. ", " .. L.TT_FEE:format(T.Money(v.eg)) end
        return L.TT_SELL, txt
    elseif key == "vendor" then
        if not ctx.hp or ctx.hp <= 0 then return nil end
        if fmt == "stack" then return L.TT_VENDOR, T.Money(ctx.hp * ctx.count) end
        return L.TT_VENDOR, L.TT_PER_UNIT:format(T.Money(ctx.hp))
    elseif key == "neutral" then
        local ne = ctx.neutral
        if not ne then return nil end
        if fmt == "price" then return L.TT_NEUTRAL, T.Money(ne.m) end
        local homeMin = e and not e.gone and e.m or nil
        return L.TT_NEUTRAL, T.NeutralText(ne, homeMin)
    elseif key == "merchant" then
        if not ctx.merchant then return nil end
        return L.TT_MERCHANT, ctx.merchant
    elseif key == "craft" then
        if not ctx.craft then return nil end
        return L.CRAFT_TT_LEFT, ctx.craft
    elseif key == "own" then
        local r = ctx.rate
        if not r then return nil end
        local txt = L.TT_SELLRATE_N:format(r.sold, r.sold + r.back)
        if fmt ~= "count" and r.rate then txt = txt .. " (" .. math.floor(r.rate * 100 + 0.5) .. " %)" end
        return L.TT_SELLRATE, txt
    end
    return nil
end

-- Wichtigster Hinweis (nur einer)
function T.HintText(ctx)
    local e, v = ctx.e, ctx.v
    if not e then return nil end
    if e.gone then return L.HINT_GONE:format(ns.Scan.Age(ctx.seen)) end
    if v and v.dump then return v.band and L.HINT_DUMP_RANGE or L.HINT_DUMP2 end
    if v and v.state == "falling" then return L.HINT_FALLING end
    if (e.n or 0) < ns.Data.FEW then return L.HINT_FEW2 end
    if ctx.seen and time() - ctx.seen > 3 * 86400 then return L.HINT_OLD end
    return nil
end

-- Alles ausgeben. Rueckgabe: true, wenn etwas dazukam
function T.Render(tooltip, ctx, details, lay)
    lay = lay or T.Layout()
    local any = false
    if ctx.v then
        local title = ("|c%sBroker|r"):format(Peon.COLOR)
        if not details and Shown(lay.shifthint, true) then title = title .. " |cff777777" .. L.TT_SHIFT_HINT .. "|r" end
        local right = T.ValueText(ctx, lay.value) or ""
        if ctx.onList and Shown(lay.mark, details) then right = right .. SHOP_ICON end
        Line(tooltip, title, right, { 1, 1, 1 })
        any = true
    elseif ctx.hp and ctx.hp > 0 and (not ctx.market or not ctx.market.lastScan) then
        tooltip:AddLine(("|c%sBroker|r %s"):format(Peon.COLOR, L.TT_NO_SCAN), GREY[1], GREY[2], GREY[3])
        any = true
    end
    -- ab 0.53 (U12): keine Zeile "Behalten" mehr (Behalten entfaellt)
    for _, l in ipairs(lay.lines) do
        if Shown(l.when, details) then
            if l.key == "hint" then
                local h = T.HintText(ctx)
                if h then Hint(tooltip, h); any = true end
            elseif l.key == "chart" then
                if T.ChartLines(tooltip, ctx, l.fmt) then any = true end
            else
                local left, right = T.BlockText(l.key, l.fmt, ctx)
                if left then Line(tooltip, left, right); any = true end
            end
        end
    end
    return any
end

---------------------------------------------------------------------------
-- Diagramm im Tooltip (ab 0.47, Umbau U6, Konzept 6.4): guenstigstes Angebot je Tag und der uebliche Bereich.
-- Wie Blizzards GameTooltip_InsertFrame, aber ohne in den Tooltip zu schreiben (insertedFrames waere dort eine
-- Aenderung an Blizzards Tabelle): Leerzeilen anfuegen, eigenen Rahmen an der ersten ausrichten, Mindestbreite
-- setzen. Beim Leeren oder Schliessen des Tooltips (sicherer Anhang) verschwindet der Rahmen wieder.
---------------------------------------------------------------------------
T.CHART_W, T.CHART_H = 210, 54
T.CHART_DAYS = { d7 = 7, d14 = 14, d30 = 30 }
T.charts = {}       -- Tooltip -> { frame, chart, sig, minSet }

-- Tageswerte der letzten n Tage, aelteste zuerst; Luecken = nil. Rueckgabe mins, Anzahl Tage mit Wert
function T.ChartSeries(e, days, today)
    today = today or ns.Data.Day()
    local mins, got = {}, 0
    local byDay = {}
    for _, r in ipairs(ns.Data.History(e)) do
        if r.day and not r.week then byDay[r.day] = r end
    end
    for i = 1, days do
        local d = today - days + i
        local r = byDay[d]
        if r and type(r.min) == "number" then mins[i] = r.min; got = got + 1 end
    end
    return mins, got
end

local function ChartFor(tooltip)
    local c = T.charts[tooltip]
    if c then return c end
    if not Peon.NewChart then return nil end
    local f = CreateFrame("Frame", nil, tooltip)
    f:SetSize(T.CHART_W, T.CHART_H)
    -- grid = 1: mit grid = 0 hing der Kern bis Peon 0.16.0 in einer Endlosschleife (Spiel fror ein, Broker 0.53.1)
    local ch = Peon.NewChart(f, { width = T.CHART_W, height = T.CHART_H, left = 2, right = 2, top = 4, bottom = 4, grid = 1 })
    if ch and ch.frame then ch.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0) end
    c = { frame = f, chart = ch }
    T.charts[tooltip] = c
    local function Clear()
        f:Hide()
        if c.minSet and tooltip.SetMinimumWidth then pcall(tooltip.SetMinimumWidth, tooltip, 0) end
        c.minSet = nil
    end
    if tooltip.HookScript then
        pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", Clear)
        pcall(tooltip.HookScript, tooltip, "OnHide", Clear)
    end
    f:Hide()
    return c
end

function T.ChartLines(tooltip, ctx, fmt)
    local days = T.CHART_DAYS[fmt] or 14
    if ctx.preview then
        tooltip:AddLine(L.TT_CHART_PREVIEW:format(days), 0.6, 0.6, 0.6)
        return true
    end
    if not ctx.e or (tooltip ~= GameTooltip and tooltip ~= rawget(_G, "ItemRefTooltip")) then return false end
    local mins, got = T.ChartSeries(ctx.e, days)
    if got < 2 then return false end
    local c = ChartFor(tooltip)
    if not c or not c.chart then return false end
    -- Platz schaffen: so viele Leerzeilen, wie das Diagramm hoch ist
    local name = tooltip.GetName and tooltip:GetName()
    local first = tooltip.NumLines and tooltip:NumLines() + 1 or nil
    tooltip:AddLine(L.TT_CHART_TITLE:format(days), 0.6, 0.6, 0.6)
    first = first and first + 1
    local need = math.ceil(T.CHART_H / 14)
    for _ = 1, need do tooltip:AddLine(" ") end
    local anchor = name and first and rawget(_G, name .. "TextLeft" .. first)
    if not anchor then return true end
    local f = c.frame
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    if tooltip.GetMinimumWidth and tooltip.SetMinimumWidth then
        local ok, w = pcall(tooltip.GetMinimumWidth, tooltip)
        if ok and type(w) == "number" and w < T.CHART_W + 20 then
            pcall(tooltip.SetMinimumWidth, tooltip, T.CHART_W + 20)
            c.minSet = true
        end
    end
    -- nur neu zeichnen, wenn sich Gegenstand, Zeitraum oder Werte geaendert haben
    local b = ctx.band
    local sig = tostring(ctx.key) .. "|" .. days .. "|" .. table.concat((function() local t = {} for i = 1, days do t[i] = tostring(mins[i]) end return t end)(), ",") .. "|" .. tostring(b and b.low) .. "|" .. tostring(b and b.high)
    if c.sig ~= sig then
        local series = {}
        if b then
            local hi, lo = {}, {}
            for i = 1, days do hi[i], lo[i] = b.high, b.low end
            series[#series + 1] = { key = "band", kind = "band", values = hi, values2 = lo, color = { 0.38, 0.88, 0.38, 0.18 } }
        end
        series[#series + 1] = { key = "min", kind = "line", values = mins, color = { 1, 0.82, 0.2, 1 }, width = 2, connect = true }
        c.chart:SetData(days, series)
        c.chart:Draw()
        c.sig = sig
    end
    f:Show()
    return true
end

function T.AddLinesHome(tooltip, link, count)
    local db = mod.db
    if not db or not db.tooltipShow then return false end
    local key = ns.Data.KeyFromLink(link)
    if key == nil then return false end
    local details = IsShiftKeyDown and IsShiftKeyDown() and true or false
    return T.Render(tooltip, T.Context(key, link, count), details)
end

---------------------------------------------------------------------------
-- Vorschau fuer die Optionsseite: Beispielwerte, gleiche Ausgabe
---------------------------------------------------------------------------
function T.SampleContext()
    local e = { m = 95, md = 102, q = 1240, n = 31, t = time and time() or 0 }
    local band = { low = 90, high = 105, rw = 98, trend = "calm", days = 14 }
    local v = { ah = true, erl = math.floor(95 * 20 * 0.95), entry = 95, vp = 95, eg = 20, state = "good", hw = 100, band = band }
    return { preview = true, count = 20, hp = 5, e = e, v = v, band = band, seen = e.t - 720, cut = 0.05, duration = 8,
        sr = { perHour = 12.5, rate = 0.7, level = 3 }, neutral = { m = 130, t = e.t }, craft = L.TT_SAMPLE_CRAFT,
        rate = { rate = 0.67, sold = 4, back = 2 }, onList = true, merchant = L.TT_SAMPLE_MERCHANT }
end

-- Zeilen der Vorschau als Text: "Links   Rechts"
function T.PreviewLines(details, lay)
    local out = {}
    local fake = {
        AddLine = function(_, text) out[#out + 1] = text end,
        AddDoubleLine = function(_, a, b) out[#out + 1] = a .. "  |cffffffff" .. tostring(b) .. "|r" end,
    }
    T.Render(fake, T.SampleContext(), details, lay)
    return out
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
