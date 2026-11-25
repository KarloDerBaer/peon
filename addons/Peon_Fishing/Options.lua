-- Peon_Fishing - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Fishing (Bausteine aus dem Peon-Kern, API 6).
-- Auswahl aus mehreren Moeglichkeiten per Auswahlliste (Dropdown, Kern-API 6).

local ADDON_NAME, ns = ...
local L = ns.L

local page

---------------------------------------------------------------------------
-- Angel-Set-Auswahl: Auswahlliste mit den vorhandenen Sets (ohne das Rueckkehr-Set)
---------------------------------------------------------------------------
local function SetOptions()
    local db = ns.GetDB()
    local list = {}
    for _, name in ipairs(ns.SetNames()) do
        if not db or name ~= db.returnSetName then list[#list + 1] = { name, name } end
    end
    return list
end

local function CurrentSetName()
    local fish = ns.SetInfo(ns.GetDB().fishingSetID)
    return fish and fish.name
end

local function KeyText()
    local keys = { GetBindingKey("PEON_FISHING_ACTION") }
    local w = { GetBindingKey("CLICK PeonFishingWeaponButton:LeftButton") }
    local i = { GetBindingKey("INTERACTTARGET") }
    return L.OPT_KEY_INFO:format(#keys > 0 and table.concat(keys, ", ") or L.OPT_NOT_BOUND,
        #w > 0 and table.concat(w, ", ") or L.OPT_NOT_BOUND,
        #i > 0 and table.concat(i, ", ") or L.OPT_NOT_BOUND)
end

---------------------------------------------------------------------------
-- Seite (ab 1.9.0 mit den Reitern Allgemein, Anzeige, Erweitert nach dem Leitfaden fuer Einstellungen)
---------------------------------------------------------------------------
function ns.CreateOptions()
    local mod = ns.mod
    if page then return end
    page = mod:NewOptionsPage({ desc = L.OPT_DESC, tipHints = true })   -- Hinweise als Tooltip (Kern-API 29)
    page:Tabs({ { "general", L.TAB_GENERAL }, { "display", L.TAB_DISPLAY }, { "advanced", L.TAB_ADVANCED } }, -58)

    -- Allgemein links: Fang-Uebersicht, Ausruestung, Kampf
    local left = page:Column(16, -96, "general")
    page:Add(left, page:Button(L.OPT_OPEN_OVERVIEW, function() ns.ToggleOverview() end, L.OPT_OPEN_OVERVIEW_HINT), 16)
    page:Add(left, page:Header(L.HDR_EQUIPMENT), 6)
    page:Add(left, page:Dropdown("fishingSet", L.OPT_FISHING_SET, SetOptions, L.OPT_FISHING_SET_HINT, {
        get = CurrentSetName, set = function(name) ns.ChooseFishingSet(name) end,
        empty = function() return #SetOptions() == 0 and L.OPT_NO_SETS or L.NONE end,
    }), 6)
    page:Add(left, page:Button(L.OPT_SAVE_SET, function() ns.SaveFishingSet() end, L.OPT_SAVE_SET_HINT), 6)
    page:Add(left, page:Text(function() return L.OPT_RETURN_SET:format(ns.GetDB().returnSetName) end), 20)
    page:Add(left, page:Header(L.HDR_COMBAT), 6)
    page:Add(left, page:Check("combatWeaponTry", L.OPT_WEAPON_TRY, L.OPT_WEAPON_TRY_HINT), 8)
    page:Add(left, page:Dropdown("afterCombat", L.OPT_AFTER_COMBAT, {
        { "stay", L.OPT_AFTER_OFF }, { "leave", L.OPT_AFTER_ON }, { "ask", L.OPT_AFTER_ASK },
    }, L.OPT_AFTER_HINT))

    -- Allgemein rechts: Steuerung, Ton, Fangliste, Minimap
    local right = page:Column(330, -96, "general")
    page:Add(right, page:Header(L.HDR_CONTROL), 6)
    page:Add(right, page:Text(KeyText), 8)
    page:Add(right, page:Check("clickMode", L.OPT_DOUBLE_CLICK, L.OPT_DOUBLE_CLICK_HINT, { "double", "off" }), 4)
    page:Add(right, page:Check("soundEnabled", L.OPT_SOUND, L.OPT_SOUND_HINT), 4)
    page:Add(right, page:Check("showCatchList", L.OPT_CATCH_LIST, L.OPT_CATCH_LIST_HINT), 4)
    page:Add(right, page:Check("showMinimap", L.OPT_MINIMAP, L.OPT_MINIMAP_HINT))

    -- Anzeige: Schwimmer und Ton
    local look = page:Column(16, -96, "display")
    page:Add(look, page:Header(L.HDR_BOBBER), 6)
    page:Add(look, page:Dropdown("bobberMarker", L.OPT_MARKER, {
        { "off", L.OPT_MARKER_OFF }, { "icon", L.OPT_MARKER_ICON }, { "text", L.OPT_MARKER_TEXT },
    }, L.OPT_MARKER_HINT))
    do
        local opts = { { "off", L.OPT_SOUND_OFF } }
        for _, s in ipairs(ns.LOST_SOUNDS) do opts[#opts + 1] = { s.key, L["SOUND_" .. s.key] } end
        page:Add(look, page:Dropdown("lostSound", L.OPT_LOST_SOUND, opts, L.OPT_LOST_SOUND_HINT))
    end
    page:Add(look, page:Check("interactSound", L.OPT_INTERACT_SOUND, L.OPT_INTERACT_SOUND_HINT), 4)
    page:Add(look, page:Check("soundParticles", L.OPT_PARTICLES, L.OPT_PARTICLES_HINT))

    local lookRight = page:Column(330, -96, "display")
    page:Add(lookRight, page:Header(L.HDR_SOUND), 6)
    -- diese Einstellungen wirken nur mit eingeschaltetem Tonmix (werden sonst ausgegraut)
    local soundCtl = {
        page:Add(lookRight, page:Slider("soundMusic", L.OPT_SOUND_MUSIC, L.OPT_SOUND_LEVEL_HINT, "%")),
        page:Add(lookRight, page:Slider("soundAmbience", L.OPT_SOUND_AMBIENCE, L.OPT_SOUND_LEVEL_HINT, "%")),
        page:Add(lookRight, page:Slider("soundSFX", L.OPT_SOUND_SFX, L.OPT_SOUND_LEVEL_HINT, "%")),
        page:Add(lookRight, page:Check("soundQuiet", L.OPT_SOUND_QUIET, L.OPT_SOUND_QUIET_HINT), 4),
        page:Add(lookRight, page:Check("soundBackground", L.OPT_SOUND_BG, L.OPT_SOUND_BG_HINT)),
    }

    -- Erweitert: Erkennung, Zeiten, Daten
    local adv = page:Column(16, -96, "advanced")
    page:Add(adv, page:Text(function() return L.ADVANCED_NOTE end), 12)
    page:Add(adv, page:Header(L.HDR_BOBBER), 6)
    page:Add(adv, page:Slider("interactRange", L.OPT_RANGE, L.OPT_RANGE_HINT, " m"))
    page:Add(adv, page:Check("recastOnLost", L.OPT_RECAST, L.OPT_RECAST_HINT), 20)
    page:Add(adv, page:Header(L.HDR_SOUND), 6)
    soundCtl[#soundCtl + 1] = page:Add(adv, page:Slider("soundDelay", L.OPT_SOUND_DELAY, L.OPT_SOUND_DELAY_HINT, " s"))
    page:Add(adv, page:Check("soundChannels", L.OPT_CHANNELS, L.OPT_CHANNELS_HINT), 20)
    page:Add(adv, page:Header(L.HDR_CATCHES), 6)
    page:Add(adv, page:Button(L.OPT_RESET_CATCHES, function() StaticPopup_Show("PEON_FISHING_RESET_CATCHES") end,
        L.OPT_RESET_CATCHES_HINT))

    page:AddResetButton(L.SLASH_HINT, left, right, look, lookRight, adv)

    -- abhaengige Einstellungen ausgrauen
    page.onRefresh = function()
        local db = mod.db
        if not db then return end
        for _, ctl in ipairs(soundCtl) do ctl:SetAlpha(db.soundEnabled and 1 or 0.4) end
    end

    page:Register()
    ns.page = page
end

function ns.RefreshOptions()
    if page and page.panel:IsVisible() then page:Refresh() end
end

function ns.OpenOptions()
    ns.mod:OpenOptions()
end

-- Hoerprobe beim Waehlen des Warntons
ns.mod:On("CHANGED", function(key)
    local db = ns.GetDB()
    if key == "lostSound" and db and db.lostSound ~= "off" then ns.PlayLostSound(db.lostSound) end
end)

-- Offenes Menue aktuell halten (Angelmodus, Sets, Tastenbelegungen)
table.insert(ns.onModeChanged, ns.RefreshOptions)
ns.mod:RegisterEvent("EQUIPMENT_SETS_CHANGED", ns.RefreshOptions)
ns.mod:RegisterEvent("UPDATE_BINDINGS", ns.RefreshOptions)

-- schon bei ADDON_LOADED bauen, damit der Kern die Seite bei PLAYER_LOGIN unter "Peon" einhaengt
ns.mod:On("INIT", function() ns.mod:Call("Options", ns.CreateOptions) end)
