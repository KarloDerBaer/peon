-- Peon_Broker - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Broker (Bausteine aus dem Peon-Kern).
-- Stand 0.7: Minimap-Button, Broker-Fenster, Tooltip, Trend, Preisvorschlag (Rechenmodell), Preisdaten und Maerkte, Pruefung, Ereignis-Liste.

local ADDON_NAME, ns = ...
local L = ns.L

-- Nur einen Eintrag hinzufuegen. Die Tabelle selbst nie neu zuweisen (StaticPopupDialogs = ...):
-- das "verunreinigt" sie fuer Blizzard-Code, und ESC (Spielmenue) meldet dann ADDON_ACTION_FORBIDDEN.
StaticPopupDialogs["PEON_BROKER_DELETE_MARKET"] = {
    text = L.CONFIRM_DELETE,
    button1 = YES, button2 = NO,
    OnAccept = function(_, data) ns.DeleteMarket(data) end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

function ns.DeleteMarket(key)
    if type(key) ~= "string" then return end
    ns.Data.DeleteMarket(key)
    ns.mod:Print(L.MSG_MARKET_DELETED:format(key))
    if ns.mod.page then ns.mod.page:Refresh() end
end

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })

    local left = page:Column(16, -60)
    page:Add(left, page:Header(L.HDR_GENERAL), 6)
    page:Add(left, page:Check("minimapShow", L.MINIMAP_SHOW))
    page:Add(left, page:Button(L.BTN_WINDOW, function() ns.Window.Open() end), 16)
    -- ab 0.41: "Blizzard pur" (Notausgang, laedt neu)
    page:Add(left, page:Text(function() return ns.AHPlain() and L.AH_PLAIN_STATE_ON or L.AH_PLAIN_STATE_OFF end))
    page:Add(left, page:Button(L.BTN_AH_PLAIN, function() ns.AHTabs.AskPlain(not ns.AHPlain()) end, L.AH_PLAIN_HINT), 16)

    -- Preise im Tooltip
    page:Add(left, page:Header(L.HDR_TOOLTIP), 6)
    page:Add(left, page:Check("tooltipShow", L.OPT_TT_SHOW))
    -- ab 0.46 (Umbau U5): Bausteine frei einstellbar, ersetzt die Schalter 7 Tage, Haendler, Hinweise und Neutral
    local ttLayout = ns.TooltipOptions.Build(page, left)

    -- Berufsfenster (ab 0.39): gleiche Punkte wie im Zahnrad-Menue am Block
    ns.Craft.AddOptions(page, left)

    -- Trend
    page:Add(left, page:Header(L.HDR_TREND), 6)
    page:Add(left, page:Slider("trendNeutral", L.OPT_TREND_NEUTRAL, L.OPT_TREND_NEUTRAL_HINT, " %"))
    page:Add(left, page:Slider("trendStrong", L.OPT_TREND_STRONG, L.OPT_TREND_STRONG_HINT, " %"), 16)

    -- Preisvorschlag (Grundlage fuer den Erloes)
    page:Add(left, page:Header(L.HDR_PRICE), 6)
    local modes = { { "copper", L.UNDERCUT_COPPER }, { "percent", L.UNDERCUT_PERCENT } }
    page:Add(left, page:Dropdown("undercutMassMode", L.OPT_UB_MASS_MODE, modes, L.OPT_UB_MASS_HINT))
    page:Add(left, page:Slider("undercutMassValue", L.OPT_UB_MASS_VALUE, L.OPT_UNDERCUT_VALUE_HINT))
    page:Add(left, page:Dropdown("undercutMode", L.OPT_UB_ITEM_MODE, modes, L.OPT_UB_ITEM_HINT))
    page:Add(left, page:Slider("undercutValue", L.OPT_UB_ITEM_VALUE, L.OPT_UNDERCUT_VALUE_HINT))
    page:Add(left, page:Slider("dumpPct", L.OPT_DUMP, L.OPT_DUMP_HINT, " %"))
    page:Add(left, page:Dropdown("duration", L.OPT_DURATION,
        { { 2, L.DUR_2 }, { 8, L.DUR_8 }, { 24, L.DUR_24 } }, L.OPT_DURATION_HINT))

    -- Radar (Schnaeppchen)
    page:Add(left, page:Header(L.HDR_DEALS), 6)
    page:Add(left, page:Check("radarSound", L.OPT_RADAR_SOUND))
    local soundKey = page:Add(left, page:Dropdown("radarSoundKey", L.OPT_RADAR_SOUND_KEY, {
        { "raid", L.SOUND_RAID }, { "ready", L.SOUND_READY }, { "alarm", L.SOUND_ALARM }, { "tell", L.SOUND_TELL } }))
    local soundTest = page:Add(left, page:Button(L.BTN_SOUND_TEST, function() ns.Radar.PlayAlert() end))
    page:Add(left, page:Slider("radarFlash", L.OPT_RADAR_FLASH, nil, L.OPT_SEC_SUFFIX))
    -- Geldbetraege (ab 0.19): Mindestgewinn Haendler/Markt (auch im Reiter Radar) und Goldreserve
    local money = page:NewContainer(4 * 26 + 18)
    local rows = {
        { L.OPT_DEAL_VENDOR, function() return tonumber(mod.db.dealMinVendor) or 10 end,
          function(c) mod.db.dealMinVendor = math.max(0, math.floor(c)) end, 100 },
        { L.OPT_DEAL_MARKET, function() return (tonumber(mod.db.dealMinMarket) or 50) * 100 end,
          function(c) mod.db.dealMinMarket = math.max(0, math.floor(c / 100)) end, 100 },
        { L.OPT_RESERVE, function() return (tonumber(mod.db.radarReserve) or 0) * 10000 end,
          function(c) mod.db.radarReserve = math.max(0, math.floor(c / 10000)) end, 10000 },
    }
    money.boxes = {}
    for i, r in ipairs(rows) do
        local label = money:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 0, -(i - 1) * 26 - 4)
        label:SetText(r[1])
        local box = ns.MoneyBox(money, 90, r[2], function(c) r[3](c); if ns.Radar.Refresh then ns.Radar.Refresh() end end, r[4])
        box:SetPoint("TOPLEFT", 260, -(i - 1) * 26)
        money.boxes[i] = box
    end
    local mh = money:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    mh:SetPoint("TOPLEFT", 0, -3 * 26 - 2)
    mh:SetWidth(440)
    mh:SetJustifyH("LEFT")
    mh:SetText("|cff999999" .. L.OPT_MONEY_HINT .. " " .. L.OPT_MONEY_UNIT_S .. " (" .. L.OPT_RESERVE:match("^[^%(]+"):gsub("%s+$", "") .. ": " .. L.OPT_MONEY_UNIT_G .. ")|r")
    money.Refresh = function() for _, b in ipairs(money.boxes) do b.Reset() end end
    page:Add(left, money)
    -- ab 0.65 (Konzept 6.1): Einstellungen der frueheren Art "unter dem ueblichen Preis" (Marge, Tiefe, Halten, Scans,
    -- Tage) entfallen auf der Seite, die Werte bleiben gespeichert. Neu: hoechste Verkaufsdauer fuer den Aufkauf.
    page:Add(left, page:Slider("buyoutHours", L.OPT_BUYOUT_HOURS, L.OPT_BUYOUT_HOURS_HINT, L.OPT_HOURS_SUFFIX))
    page:Add(left, page:Slider("focusRate", L.OPT_FOCUS_EVERY, L.OPT_FOCUS_EVERY_HINT))
    page:Add(left, page:Slider("radarMaxAge", L.OPT_DEAL_AGE, L.OPT_DEAL_AGE_HINT, L.OPT_MIN_SUFFIX))
    page:Add(left, page:Check("radarShowExpensive", L.OPT_RADAR_EXPENSIVE), 16)

    -- Preisdaten und Maerkte
    page:Add(left, page:Header(L.HDR_SALES), 6)
    page:Add(left, page:Slider("salesWindow", L.OPT_SALES_WINDOW, L.OPT_SALES_WINDOW_HINT, L.OPT_HOURS_SUFFIX))
    page:Add(left, page:Slider("salesMidMin", L.OPT_SALES_MID, L.OPT_SALES_MID_HINT, L.OPT_MIN_SUFFIX))
    page:Add(left, page:Slider("salesSureMin", L.OPT_SALES_SURE, nil, L.OPT_MIN_SUFFIX))
    page:Add(left, page:Slider("salesCancelPct", L.OPT_SALES_CANCEL, L.OPT_SALES_CANCEL_HINT, L.OPT_PCT_SUFFIX), 16)

    page:Add(left, page:Header(L.HDR_DATA), 6)
    page:Add(left, page:Slider("dataDays", L.OPT_DAYS, L.OPT_DAYS_HINT, L.OPT_DAYS_SUFFIX), 12)
    local markets = page:Add(left, page:List({
        columns = {
            { key = "name",  title = L.COL_MARKET, width = 260 },
            { key = "items", title = L.COL_ITEMS, width = 90, align = "RIGHT" },
            { key = "last",  title = L.COL_LASTSCAN, width = 110, align = "RIGHT",
              format = function(v) return v and ns.Scan.Age(v) or "-" end },
        },
        rows = 4, sortKey = "last", sortDesc = true,
    }), 6)
    markets.Refresh = function()
        local items = {}
        local current = ns.MarketKey()
        for key, m in pairs(ns.Data.Markets()) do
            if type(m) == "table" then
                local n = 0
                if type(m.items) == "table" then for _ in pairs(m.items) do n = n + 1 end end
                items[#items + 1] = { key = key, name = key == current and (key .. " " .. L.CURRENT) or key,
                    items = n, last = m.lastScan }
            end
        end
        markets.list:SetData(items)
    end
    page:Add(left, page:Button(L.BTN_DELETE_MARKET, function()
        local sel = markets.list:GetSelected()
        if not sel then mod:Print(L.MSG_SELECT_MARKET); return end
        if StaticPopup_Show then
            StaticPopup_Show("PEON_BROKER_DELETE_MARKET", sel.key, nil, sel.key)
        else
            ns.DeleteMarket(sel.key)
        end
    end, L.BTN_DELETE_HINT), 16)

    -- Pruefung (Entwicklung)
    page:Add(left, page:Header(L.HDR_PROBE), 6)
    page:Add(left, page:Text(function()
        local r = mod.acc and mod.acc.probe
        if type(r) ~= "table" or not r.time then return L.NO_PROBE end
        local scan = L.NOT_TESTED
        if type(r.scan) == "table" then
            if r.scan.count then
                scan = L.MSG_SCAN_DONE:format(r.scan.count, r.scan.seconds or 0)
            elseif r.scan.error then
                scan = r.scan.error
            elseif r.scan.timeout then
                scan = L.MSG_SCAN_NONE:format(ns.Probe.SCAN_TIMEOUT)
            end
        end
        return L.LAST_PROBE:format(r.time, tostring(r.market), ns.Probe.AHText(r), ns.Probe.FeeText(r), scan)
    end), 10)
    page:Add(left, page:Button(L.BTN_PROBE, function() ns.Probe.Run() end, L.BTN_PROBE_HINT), 12)
    page:Add(left, page:Button(L.BTN_SCAN, function() ns.Probe.ScanTest() end, L.BTN_SCAN_HINT), 12)
    page:Add(left, page:Text(function() return L.SLASH_HINT end), 16)

    -- Ereignis-Liste (zeigt, welche Auktionshaus- und Post-Ereignisse der Client kennt und wie oft sie kamen)
    page:Add(left, page:Header(L.HDR_EVENTS), 6)
    local events = page:Add(left, page:List({
        columns = {
            { key = "name",  title = L.COL_EVENT, width = 330 },
            { key = "known", title = L.COL_KNOWN, width = 70, format = function(v) return v and L.YES or ("|cffff6060" .. L.NO .. "|r") end },
            { key = "count", title = L.COL_COUNT, width = 60, align = "RIGHT" },
        },
        rows = 10, sortKey = "count", sortDesc = true,
    }))
    events.Refresh = function()
        local items = {}
        local ev = mod.acc and mod.acc.probeEvents
        if type(ev) == "table" then
            for name, e in pairs(ev) do
                if type(e) == "table" then items[#items + 1] = { name = name, known = e.known, count = e.count or 0 } end
            end
        end
        events.list:SetData(items)
    end

    -- Tooltip-Unterpunkte ausgrauen, wenn die Tooltip-Preise aus sind
    page.onRefresh = function()
        local on = mod.db and mod.db.tooltipShow
        ttLayout:SetAlpha(on and 1 or 0.4)
        local snd = mod.db and mod.db.radarSound
        soundKey:SetAlpha(snd and 1 or 0.4); soundTest:SetAlpha(snd and 1 or 0.4)
    end

    page:Register()
end
