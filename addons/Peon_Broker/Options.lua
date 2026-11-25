-- Peon_Broker - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Broker (Bausteine aus dem Peon-Kern).
-- Ab 0.139 (U7, Konzept Peon_Broker_Schlank.md 10, Leitfaden Peon_Einstellungen_Leitfaden.md, KarloDerBaer 25.11.2026):
--   Allgemein  Fenster oeffnen, Minimap-Knopf, Preise im Tooltip, Angebotsdauer
--   Anzeige    Tooltip (Buendel, Bausteine), Zahl am Reiter, Tonwahl und Aufleuchten des Radars
--   Erweitert  Preisvorschlag, Lockangebote, Trend, Verkaufsrate, Radar, Preisdaten mit Maerkten, Blizzard pur
-- Hinweise stehen als Tooltip (tipHints, Kern-API 29). Was in Brokers eigenen Einstellungsfenstern steht (Mindestgewinn,
-- Goldreserve, Aufkauf, Abfragen je Minute, Ton beim Radar) und die Pruefung (/broker check) stehen nicht mehr hier.
-- Die Werte bleiben gespeichert.

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
    local page = mod:NewOptionsPage({ desc = L.DESC, tipHints = true })   -- Hinweise als Tooltip (Kern-API 29)
    page:Tabs({ { "general", L.TAB_GENERAL }, { "display", L.TAB_DISPLAY }, { "advanced", L.TAB_ADVANCED } }, -58)

    -- Allgemein
    local left = page:Column(16, -96, "general")
    page:Add(left, page:Button(L.BTN_WINDOW, function() ns.Window.Open() end, L.BTN_WINDOW_HINT), 16)
    page:Add(left, page:Header(L.HDR_GENERAL), 6)
    page:Add(left, page:Check("minimapShow", L.MINIMAP_SHOW, L.MINIMAP_SHOW_HINT))
    page:Add(left, page:Check("tooltipShow", L.OPT_TT_SHOW, L.OPT_TT_SHOW_HINT), 12)
    page:Add(left, page:Dropdown("duration", L.OPT_DURATION,
        { { 2, L.DUR_2 }, { 8, L.DUR_8 }, { 24, L.DUR_24 } }, L.OPT_DURATION_HINT))

    -- Anzeige: Tooltip und Zahl am Reiter
    local look = page:Column(16, -96, "display")
    page:Add(look, page:Header(L.HDR_TOOLTIP), 6)
    page:Add(look, page:Check("tooltipPacks", L.OPT_TT_PACKS, L.OPT_TT_PACKS_HINT))   -- ab 0.87
    -- ab 0.46 (Umbau U5): Bausteine frei einstellbar
    local ttLayout = ns.TooltipOptions.Build(page, look)
    page:Add(look, page:Header(L.HDR_BADGES), 6)   -- ab 0.97: Zahl am Reiter, je Reiter ob und wann
    local T = ns.AHTabs
    for i, key in ipairs(T.BADGE_ORDER) do
        local d = T.BADGE_MODES[key]
        local opts = {}
        for _, m in ipairs(d.modes) do opts[#opts + 1] = { m, L["BADGE_" .. key:upper() .. "_" .. m:upper()] or L["BADGE_" .. m:upper()] } end
        page:Add(look, page:Dropdown(d.db, L[d.label], opts, L["BADGE_" .. key:upper() .. "_HINT"]), i == #T.BADGE_ORDER and 16 or nil)
    end
    -- Radar: Ton und Aufleuchten (an und aus steht im Fenster Chancen). Hoerprobe beim Waehlen (ohne Testknopf)
    local lookRight = page:Column(330, -96, "display")
    page:Add(lookRight, page:Header(L.HDR_DEALS), 6)
    page:Add(lookRight, page:Dropdown("radarSoundKey", L.OPT_RADAR_SOUND_KEY, ns.Radar.SoundChoices(), L.OPT_RADAR_SOUND_KEY_HINT))
    page:Add(lookRight, page:Slider("radarFlash", L.OPT_RADAR_FLASH, L.OPT_RADAR_FLASH_HINT, L.OPT_SEC_SUFFIX))

    -- Erweitert
    local adv = page:Column(16, -96, "advanced")
    page:Add(adv, page:Text(function() return L.ADVANCED_NOTE end), 12)
    page:Add(adv, page:Header(L.HDR_PRICE), 6)
    local modes = { { "copper", L.UNDERCUT_COPPER }, { "percent", L.UNDERCUT_PERCENT } }
    page:Add(adv, page:Dropdown("undercutMassMode", L.OPT_UB_MASS_MODE, modes, L.OPT_UB_MASS_HINT))
    page:Add(adv, page:Slider("undercutMassValue", L.OPT_UB_MASS_VALUE, L.OPT_UNDERCUT_VALUE_HINT))
    page:Add(adv, page:Dropdown("undercutMode", L.OPT_UB_ITEM_MODE, modes, L.OPT_UB_ITEM_HINT))
    page:Add(adv, page:Slider("undercutValue", L.OPT_UB_ITEM_VALUE, L.OPT_UNDERCUT_VALUE_HINT))
    page:Add(adv, page:Slider("dumpPct", L.OPT_DUMP, L.OPT_DUMP_HINT, " %"))
    -- ab 0.104: Lockangebote erkennen (Data.SkipBait)
    page:Add(adv, page:Slider("baitQty", L.OPT_BAIT_QTY, L.OPT_BAIT_QTY_HINT))
    page:Add(adv, page:Slider("baitPct", L.OPT_BAIT_PCT, L.OPT_BAIT_PCT_HINT, " %"))
    page:Add(adv, page:Slider("baitGap", L.OPT_BAIT_GAP, L.OPT_BAIT_GAP_HINT, " %"), 16)
    page:Add(adv, page:Header(L.HDR_TREND), 6)
    page:Add(adv, page:Slider("trendNeutral", L.OPT_TREND_NEUTRAL, L.OPT_TREND_NEUTRAL_HINT, " %"))
    page:Add(adv, page:Slider("trendStrong", L.OPT_TREND_STRONG, L.OPT_TREND_STRONG_HINT, " %"), 16)

    local advRight = page:Column(330, -96, "advanced")
    page:Add(advRight, page:Header(L.HDR_SALES), 6)
    page:Add(advRight, page:Slider("salesWindow", L.OPT_SALES_WINDOW, L.OPT_SALES_WINDOW_HINT, L.OPT_HOURS_SUFFIX))
    page:Add(advRight, page:Slider("salesMidMin", L.OPT_SALES_MID, L.OPT_SALES_MID_HINT, L.OPT_MIN_SUFFIX))
    page:Add(advRight, page:Slider("salesSureMin", L.OPT_SALES_SURE, L.OPT_SALES_SURE_HINT, L.OPT_MIN_SUFFIX))
    page:Add(advRight, page:Slider("salesCancelPct", L.OPT_SALES_CANCEL, L.OPT_SALES_CANCEL_HINT, L.OPT_PCT_SUFFIX), 16)
    page:Add(advRight, page:Header(L.HDR_DEALS), 6)
    page:Add(advRight, page:Slider("radarMaxAge", L.OPT_DEAL_AGE, L.OPT_DEAL_AGE_HINT, L.OPT_MIN_SUFFIX))
    page:Add(advRight, page:Check("radarShowExpensive", L.OPT_RADAR_EXPENSIVE, L.OPT_RADAR_EXPENSIVE_HINT), 16)
    page:Add(advRight, page:Header(L.HDR_DATA), 6)
    page:Add(advRight, page:Slider("dataDays", L.OPT_DAYS, L.OPT_DAYS_HINT, L.OPT_DAYS_SUFFIX), 12)
    local markets = page:Add(advRight, page:List({
        columns = {
            { key = "name",  title = L.COL_MARKET, width = 170 },
            { key = "items", title = L.COL_ITEMS, width = 60, align = "RIGHT" },
            { key = "last",  title = L.COL_LASTSCAN, width = 70, align = "RIGHT",
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
    page:Add(advRight, page:Button(L.BTN_DELETE_MARKET, function()
        local sel = markets.list:GetSelected()
        if not sel then mod:Print(L.MSG_SELECT_MARKET); return end
        if StaticPopup_Show then
            StaticPopup_Show("PEON_BROKER_DELETE_MARKET", sel.key, nil, sel.key)
        else
            ns.DeleteMarket(sel.key)
        end
    end, L.BTN_DELETE_HINT), 16)
    -- ab 0.41: "Blizzard pur" (Notausgang, laedt neu)
    page:Add(advRight, page:Header(L.HDR_AH_PLAIN), 6)
    page:Add(advRight, page:Text(function() return ns.AHPlain() and L.AH_PLAIN_STATE_ON or L.AH_PLAIN_STATE_OFF end))
    page:Add(advRight, page:Button(L.BTN_AH_PLAIN, function() ns.AHTabs.AskPlain(not ns.AHPlain()) end, L.AH_PLAIN_HINT))

    page:AddResetButton(L.SLASH_HINT, left, look, lookRight, adv, advRight)

    -- Tooltip-Unterpunkte ausgrauen, wenn die Tooltip-Preise aus sind
    page.onRefresh = function()
        local on = mod.db and mod.db.tooltipShow
        ttLayout:SetAlpha(on and 1 or 0.4)
    end

    page:Register()
end

-- ab 0.139: Hoerprobe beim Waehlen des Tons (statt Testknopf, Leitfaden Regel 4)
ns.mod:On("CHANGED", function(key)
    if key == "radarSoundKey" and ns.Radar and ns.Radar.PlayAlert then pcall(ns.Radar.PlayAlert) end
end)
