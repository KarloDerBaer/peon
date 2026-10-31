-- Peon_Fishing - Keys.lua
-- Angel-Taste (Tastenbelegung "Angeln (Auswerfen / Einholen)", Tastatur oder Controller):
-- Im Angelmodus wirft ein Druck aus, waehrend des Angelkanals holt derselbe Druck ein.
-- Ausserhalb des Angelmodus schaltet die Taste den Angelmodus ein.
--
-- Umsetzung: Die Taste(n) der Belegung PEON_FISHING_ACTION werden im Angelmodus per Override
-- auf den sicheren Wurf-Button bzw. INTERACTTARGET gelegt (nur ausserhalb des Kampfes).
-- Bei Kampfbeginn (PLAYER_REGEN_DISABLED, Sperre noch nicht aktiv) wird alles freigegeben.

local ADDON_NAME, ns = ...
local L = ns.L

local keyOwner = CreateFrame("Frame", "PeonFishingKeyOwner")
local applied = ""        -- zuletzt gesetzter Zustand, um unnoetige Aenderungen zu vermeiden
local castPending = 0

local function Keys()
    return { GetBindingKey("PEON_FISHING_ACTION") }
end

-- state: "cast" | "reel" | nil (freigeben)
local function Apply(state, reason)
    if InCombatLockdown() then return end
    local db = ns.GetDB()
    if not db or db.mode ~= "fishing" then state = nil end
    local keys = Keys()
    -- Koeder fehlt oder laeuft bald ab: erst Koeder anlegen, dann auswerfen
    local lure
    if state == "cast" and ns.LureToApply then lure = ns.LureToApply() end
    if lure then state = "lure" end
    local sig = tostring(state) .. (lure and (":" .. lure) or "") .. ":" .. table.concat(keys, ",")
    if sig == applied then return end
    ClearOverrideBindings(keyOwner)
    if state and #keys > 0 then
        if state == "cast" and not ns.EnsureCastButton() then
            ns.ReportError("Keys", L.ERR_NO_FISHING_SPELL)
            state = nil
        else
            if state == "lure" and not ns.PrepareLureButton(lure) then state = "cast" end
            for _, key in ipairs(keys) do
                if state == "reel" then
                    SetOverrideBinding(keyOwner, true, key, "INTERACTTARGET")
                elseif state == "lure" then
                    SetOverrideBindingClick(keyOwner, true, key, "PeonFishingLureButton", "LeftButton")
                else
                    SetOverrideBindingClick(keyOwner, true, key, "PeonFishingCastButton", "LeftButton")
                end
            end
        end
    end
    applied = sig
    ns.Dbg(("Angel-Taste %s -> %s (%s)"):format(table.concat(keys, ", "), tostring(state), tostring(reason)))
end

local function Current()
    if ns.IsFishingChannel() then
        -- Schwimmer nicht als Ziel erkannt: Einholen ginge ins Leere, also neu auswerfen (Option)
        if ns.bobberLost and ns.GetDB().recastOnLost then return "cast" end
        return "reel"
    end
    return "cast"
end

-- Neu bewerten ohne Zwang (setzt nur, wenn sich etwas geaendert hat)
function ns.RefreshKeys(reason)
    Apply(Current(), reason)
end

function ns.ReapplyKeys()
    applied = ""
    Apply(Current(), "neu")
end

-- Direkt nach dem Druck auf "Auswerfen" auf Einholen umstellen, damit ein zweiter Druck
-- vor dem Kanalstart nicht neu auswirft. Kommt kein Kanal, nach 1,5 s zurueck.
function ns.OnCastPressed()
    if InCombatLockdown() then return end
    Apply("reel", "Wurf gedrueckt")
    castPending = castPending + 1
    local my = castPending
    C_Timer.After(1.5, function()
        if castPending == my and not ns.IsFishingChannel() then Apply("cast", "kein Kanal") end
    end)
end

function ns.OnChannel(started)
    if started then
        Apply(Current(), "Kanal Start")
    else
        C_Timer.After(0, function() Apply(Current(), "Kanal Ende") end)
    end
end

-- Bindings.xml: Taste ausserhalb des Angelmodus (sonst ist sie per Override umgelegt)
function PeonFishing_Action()
    if not ns.GetDB() then return end
    if ns.IsFishing() then
        -- Nur im Kampf erreichbar (Override freigegeben): nichts tun
        ns.Print(L.MSG_KEY_IN_COMBAT)
    else
        ns.Toggle()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("UPDATE_BINDINGS")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- Sperre noch nicht aktiv: Taste sofort freigeben
        ClearOverrideBindings(keyOwner)
        applied = "nil:"
    elseif event == "PLAYER_REGEN_ENABLED" or event == "UPDATE_BINDINGS" then
        C_Timer.After(0, function() Apply(Current(), event) end)
    end
end)

table.insert(ns.onModeChanged, function(mode)
    Apply(mode == "fishing" and Current() or nil, "Modus " .. tostring(mode))
end)

table.insert(ns.onLogin, function()
    C_Timer.After(0, function() Apply(Current(), "Login") end)
end)
