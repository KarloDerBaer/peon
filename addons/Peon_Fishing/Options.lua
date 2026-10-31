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
    return L.OPT_KEY_INFO:format(#keys > 0 and table.concat(keys, ", ") or L.OPT_NOT_BOUND,
        #w > 0 and table.concat(w, ", ") or L.OPT_NOT_BOUND)
end

---------------------------------------------------------------------------
-- Seite
---------------------------------------------------------------------------
function ns.CreateOptions()
    local mod = ns.mod
    if page then return end
    page = mod:NewOptionsPage({ desc = L.OPT_DESC })

    -- linke Spalte: Ausruestung, Steuerung, Schwimmer-Erkennung, Faenge
    local left = page:Column(16, -60)
    page:Add(left, page:Header(L.HDR_EQUIPMENT), 6)
    page:Add(left, page:Dropdown("fishingSet", L.OPT_FISHING_SET, SetOptions, nil, {
        get = CurrentSetName, set = function(name) ns.ChooseFishingSet(name) end,
        empty = function() return #SetOptions() == 0 and L.OPT_NO_SETS or L.NONE end,
    }), 6)
    page:Add(left, page:Button(L.OPT_SAVE_SET, function() ns.SaveFishingSet() end, L.OPT_SAVE_SET_HINT), 6)
    page:Add(left, page:Text(function() return L.OPT_RETURN_SET:format(ns.GetDB().returnSetName) end), 20)

    page:Add(left, page:Header(L.HDR_CONTROL), 6)
    page:Add(left, page:Text(KeyText), 8)
    page:Add(left, page:Check("clickMode", L.OPT_DOUBLE_CLICK, L.OPT_DOUBLE_CLICK_HINT, { "double", "off" }), 20)

    page:Add(left, page:Header(L.HDR_BOBBER), 6)
    page:Add(left, page:Slider("interactRange", L.OPT_RANGE, nil, " m"))
    page:Add(left, page:Dropdown("bobberMarker", L.OPT_MARKER, {
        { "off", L.OPT_MARKER_OFF }, { "icon", L.OPT_MARKER_ICON }, { "text", L.OPT_MARKER_TEXT },
    }))
    page:Add(left, page:Check("recastOnLost", L.OPT_RECAST), 6)
    do
        local opts = { { "off", L.OPT_SOUND_OFF } }
        for _, s in ipairs(ns.LOST_SOUNDS) do opts[#opts + 1] = { s.key, L["SOUND_" .. s.key] } end
        page:Add(left, page:Dropdown("lostSound", L.OPT_LOST_SOUND, opts), 20)
    end

    page:Add(left, page:Header(L.HDR_CATCHES), 6)
    page:Add(left, page:Check("showCatchList", L.OPT_CATCH_LIST), 6)
    page:Add(left, page:Button(L.MENU_OVERVIEW, function() ns.ToggleOverview() end), 4)
    page:Add(left, page:Button(L.OPT_RESET_CATCHES, function() StaticPopup_Show("PEON_FISHING_RESET_CATCHES") end,
        L.OPT_RESET_CATCHES_HINT))

    -- rechte Spalte: Ton, Kampf, Anzeige
    local right = page:Column(330, -60)
    page:Add(right, page:Header(L.HDR_SOUND), 6)
    page:Add(right, page:Check("soundEnabled", L.OPT_SOUND, L.OPT_SOUND_HINT), 6)
    -- diese Einstellungen wirken nur mit eingeschaltetem Tonmix (werden sonst ausgegraut)
    local soundCtl = {
        page:Add(right, page:Slider("soundMusic", L.OPT_SOUND_MUSIC, nil, "%")),
        page:Add(right, page:Slider("soundAmbience", L.OPT_SOUND_AMBIENCE, nil, "%")),
        page:Add(right, page:Slider("soundSFX", L.OPT_SOUND_SFX, nil, "%")),
        page:Add(right, page:Check("soundQuiet", L.OPT_SOUND_QUIET), 4),
        page:Add(right, page:Check("soundBackground", L.OPT_SOUND_BG), 6),
        page:Add(right, page:Slider("soundDelay", L.OPT_SOUND_DELAY, nil, " s")),
    }
    page:Add(right, page:Check("soundParticles", L.OPT_PARTICLES), 4)
    page:Add(right, page:Check("soundChannels", L.OPT_CHANNELS, L.OPT_MODE_WIDE_HINT), 20)

    page:Add(right, page:Header(L.HDR_COMBAT), 6)
    page:Add(right, page:Check("combatWeaponTry", L.OPT_WEAPON_TRY, L.OPT_WEAPON_TRY_HINT), 8)
    page:Add(right, page:Dropdown("afterCombat", L.OPT_AFTER_COMBAT, {
        { "stay", L.OPT_AFTER_OFF }, { "leave", L.OPT_AFTER_ON }, { "ask", L.OPT_AFTER_ASK },
    }, L.OPT_AFTER_HINT), 20)

    page:Add(right, page:Header(L.HDR_DISPLAY), 6)
    page:Add(right, page:Check("showMinimap", L.OPT_MINIMAP), 4)
    page:Add(right, page:Check("debug", L.OPT_DEBUG))

    page:AddResetButton(L.SLASH_HINT, left, right)

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
