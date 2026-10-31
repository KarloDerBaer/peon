-- Peon_Fishing - Sound.lua
-- Ton beim Angeln: Solange die Angel draussen ist, werden Musik, Umgebung und Stoergeraeusche
-- leiser und Effekte (dazu gehoert das Biss-Plaetschern) lauter. Nach dem Einholen kommen die
-- eigenen Werte nach einer Nachlaufzeit zurueck (bei Kampf sofort).
-- Ein Biss-Signal selbst gibt es nicht (Phase 0): kein Ereignis, Ton nicht abhoerbar, und das
-- Biss-Geraeusch laesst sich weder einzeln verstaerken noch ersetzen.
--
-- Partikeldichte und Tonkanaele gelten fuer den ganzen Angelmodus (Grafik-/Audioumbau pro Wurf
-- waere unruhig).
--
-- Alle vorherigen Werte liegen in der DB (soundBackup / modeBackup) und werden auch nach /reload,
-- Absturz oder Ausloggen wiederhergestellt.

local ADDON_NAME, ns = ...
local IsSecret = ns.IsSecret

local GetCV = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCV = (C_CVar and C_CVar.SetCVar) or SetCVar

local restoreToken = 0

local function CV(name)
    local ok, v = pcall(GetCV, name)
    if ok and v ~= nil and not IsSecret(v) then return v end
end

local function Pct(v) return ("%.2f"):format((tonumber(v) or 0) / 100) end

-- Gewuenschte Werte waehrend des Angelkanals
local function ChannelTargets()
    local db = ns.GetDB()
    local t = {
        Sound_MusicVolume    = Pct(db.soundMusic),
        Sound_AmbienceVolume = Pct(db.soundAmbience),
        Sound_SFXVolume      = Pct(db.soundSFX),
        Sound_EnableSFX      = "1",
    }
    if db.soundBackground then t.Sound_EnableSoundWhenGameIsInBG = "1" end
    if db.soundQuiet then
        t.Sound_DialogVolume      = "0"
        t.Sound_EnablePetSounds   = "0"
        t.Sound_EnableEmoteSounds = "0"
        t.Sound_EnableErrorSpeech = "0"
    end
    return t
end

local function ModeTargets()
    local db = ns.GetDB()
    local t = {}
    if db.soundParticles then t.graphicsParticleDensity = "5" end
    if db.soundChannels then t.Sound_NumChannels = "128" end
    return t
end

-- Werte setzen; die Sicherung enthaelt nur Werte, die vorher noch nicht gesichert waren
local function Apply(backupKey, targets)
    local db = ns.GetDB()
    db[backupKey] = type(db[backupKey]) == "table" and db[backupKey] or {}
    local backup = db[backupKey]
    for name, val in pairs(targets) do
        local cur = CV(name)
        if cur ~= nil then
            if backup[name] == nil then backup[name] = cur end
            if cur ~= val then pcall(SetCV, name, val) end
        end
    end
    -- Nicht mehr gewuenschte Werte (Option abgeschaltet) zuruecksetzen
    for name, val in pairs(backup) do
        if targets[name] == nil then
            pcall(SetCV, name, val)
            backup[name] = nil
        end
    end
end

local function Restore(backupKey, reason)
    local db = ns.GetDB()
    if not db or type(db[backupKey]) ~= "table" then return end
    for name, val in pairs(db[backupKey]) do pcall(SetCV, name, val) end
    db[backupKey] = nil
    ns.Dbg("Ton/Grafik zurueck (" .. backupKey .. ", " .. tostring(reason) .. ")")
end

local function RestoreChannel(reason)
    restoreToken = restoreToken + 1
    Restore("soundBackup", reason)
end

local function ApplyChannel()
    local db = ns.GetDB()
    restoreToken = restoreToken + 1          -- laufende Nachlaufzeit abbrechen
    if not db.soundEnabled then RestoreChannel("aus") return end
    Apply("soundBackup", ChannelTargets())
    ns.Dbg("Angel-Tonmix aktiv")
end

local function ApplyMode()
    local db = ns.GetDB()
    if db.mode == "fishing" then
        Apply("modeBackup", ModeTargets())
    else
        Restore("modeBackup", "Angelmodus aus")
    end
end

local f = CreateFrame("Frame")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function(_, event)
    local db = ns.GetDB()
    if not db then return end
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        if db.mode == "fishing" and ns.IsFishingChannel() then ApplyChannel() end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if type(db.soundBackup) ~= "table" then return end
        restoreToken = restoreToken + 1
        local my = restoreToken
        C_Timer.After(db.soundDelay or 5, function()
            if restoreToken == my and not ns.IsFishingChannel() then RestoreChannel("Nachlaufzeit") end
        end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        RestoreChannel("Kampf")
    elseif event == "PLAYER_LOGOUT" then
        -- CVars werden beim Ausloggen gespeichert: vorher zuruecksetzen
        RestoreChannel("Logout")
        Restore("modeBackup", "Logout")
    end
end)

table.insert(ns.onModeChanged, function(mode)
    local db = ns.GetDB()
    if mode ~= "fishing" then
        RestoreChannel("Angelmodus aus")
    elseif type(db.soundBackup) == "table" then
        -- Optionen geaendert, waehrend der Mix aktiv ist
        if db.soundEnabled then Apply("soundBackup", ChannelTargets()) else RestoreChannel("aus") end
    end
    ApplyMode()
end)

table.insert(ns.onLogin, function()
    -- Nach Absturz/Reload waehrend des Angelns: eigene Werte zurueck
    RestoreChannel("Login")
    ApplyMode()
end)
