-- Peon_Fishing - Click.lua
-- Angeln im Angelmodus: Doppelklick (Standard rechts) wirft immer aus, auch waehrend des
-- Angelkanals. Eingeholt wird mit einfachem Rechtsklick auf den Schwimmer (Spiel-Standard).
--
-- Ablauf (Phase 0 geprueft): Ein kurzer Klick auf die Spielwelt geht normal durch. Danach ist die
-- Maustaste fuer 0,4 s per Override auf den sicheren Wurf-Button (bzw. Koeder-Button) gelegt. Der
-- zweite Klick loest das aus. Gedrueckt halten (Kamera drehen) schaltet nie scharf.
-- Bei Kampfbeginn (PLAYER_REGEN_DISABLED, Sperre noch nicht aktiv) werden alle Belegungen geleert.

local ADDON_NAME, ns = ...
local L = ns.L
local IsSecret = ns.IsSecret

local GetCV = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCV = (C_CVar and C_CVar.SetCVar) or SetCVar

local FISHING_ICON = 136245
local FISHING_CANDIDATES = { 7620, 7731, 7732, 18248, 33095, 51294, 88868, 110410, 131474, 158743, 271990 }
local TAP_MAX       = 0.3   -- laenger gedrueckt = Kamera drehen, kein Doppelklick
local DOUBLE_WINDOW = 0.4
local MOUSE_KEYS = { RightButton = "BUTTON2", MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local fishingID, fishingName
local castBtn
local owner = CreateFrame("Frame", "PeonFishingBindingOwner")
ns.bindingOwner = owner
local click = { state = "idle" }
local armToken = 0

---------------------------------------------------------------------------
-- Angelzauber ueber das Zauberbuch finden (Name nicht hartcodiert)
---------------------------------------------------------------------------
local function Known(id)
    for _, fn in ipairs({ IsPlayerSpell, C_SpellBook and C_SpellBook.IsSpellKnown, IsSpellKnown }) do
        if type(fn) == "function" then
            local ok, r = pcall(fn, id)
            if ok and r == true then return true end
        end
    end
    return false
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

function ns.FindFishingSpell()
    local found
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo and bank then
        local misses = 0
        for slot = 1, 1000 do
            local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
            if ok and type(info) == "table" and info.iconID ~= nil and not IsSecret(info.iconID) then
                misses = 0
                if info.iconID == FISHING_ICON and not info.isPassive
                    and type(info.spellID) == "number" and not IsSecret(info.spellID) then
                    found = info.spellID
                    break
                end
            else
                misses = misses + 1
                if misses > 30 then break end
            end
        end
    end
    if not found then
        for _, id in ipairs(FISHING_CANDIDATES) do
            if Known(id) then found = id break end
        end
    end
    fishingID = found
    fishingName = found and SpellName(found) or nil
    ns.Dbg("Angelzauber: " .. tostring(found) .. " (" .. tostring(fishingName) .. ")")
    return found
end

local function EnsureCastButton()
    if InCombatLockdown() then return castBtn ~= nil end
    if not fishingID and not ns.FindFishingSpell() then return false end
    if not castBtn then
        castBtn = CreateFrame("Button", "PeonFishingCastButton", UIParent, "SecureActionButtonTemplate")
        castBtn:RegisterForClicks("AnyUp", "AnyDown")
        castBtn:HookScript("PostClick", function(_, _, down)
            -- Wurf per Doppelklick oder per Angel-Taste? (Warnung nur bei der Taste)
            if down then ns.lastCastMouse = ns.mouseFiring and true or false end
            if down and ns.OnCastPressed then ns.OnCastPressed() end
        end)
    end
    castBtn:SetAttribute("type", "spell")
    castBtn:SetAttribute("spell", fishingID)
    return true
end
ns.EnsureCastButton = EnsureCastButton

function ns.IsFishingChannel()
    local name, _, _, _, _, _, _, spellID = UnitChannelInfo("player")
    if not name or IsSecret(name) or IsSecret(spellID) then return false end
    return (fishingID ~= nil and spellID == fishingID) or (fishingName ~= nil and name == fishingName)
end

---------------------------------------------------------------------------
-- CVars fuer das Soft-Interact-Ziel: seit 0.8.0 fuer den ganzen Angelmodus (nicht mehr pro Wurf).
-- Log 29.09.: Das Umschalten genau beim Auswerfen (Schwimmer entsteht ~0,1 s nach Kanalstart)
-- fuehrte oft dazu, dass der Schwimmer nie als Ziel erkannt wurde. Zurueckgesetzt wird bei
-- Angelmodus aus, Kampfbeginn, Login und Logout.
---------------------------------------------------------------------------
local INTERACT_ARC = "2"
-- Anzeige ueber dem erkannten Schwimmer: Symbol, Text (Namensplakette) oder nichts
local MARKER_GUARD = {
    off  = { SoftTargetIconGameObject = "0", SoftTargetIconInteract = "0", SoftTargetNameplateInteract = "0" },
    icon = { SoftTargetIconGameObject = "1", SoftTargetIconInteract = "1", SoftTargetNameplateInteract = "0" },
    text = { SoftTargetIconGameObject = "0", SoftTargetIconInteract = "0", SoftTargetNameplateInteract = "1" },
}

-- Warnton, wenn der Schwimmer nicht erkannt wurde (Kanal "Master", damit der Angel-Tonmix ihn nicht daempft)
ns.LOST_SOUNDS = {
    { key = "raid",  kit = "RAID_WARNING",          id = 8959 },
    { key = "ready", kit = "READY_CHECK",           id = 8960 },
    { key = "alarm", kit = "ALARM_CLOCK_WARNING_3", id = 12889 },
    { key = "tell",  kit = "TELL_MESSAGE",          id = 3081 },
}
function ns.PlayLostSound(key)
    for _, s in ipairs(ns.LOST_SOUNDS) do
        if s.key == key then
            local id = (SOUNDKIT and SOUNDKIT[s.kit]) or s.id
            pcall(PlaySound, id, "Master")
            return
        end
    end
end
local BOBBER_ENTRY = "35591"   -- GameObject-Eintrag des Schwimmers (aus dem Log)

local function CV(name)
    local ok, v = pcall(GetCV, name)
    if ok and v ~= nil and not IsSecret(v) then return v end
end

-- Soft-Interact-Ziel zuruecksetzen: kurz 0, dann 3 (Maus und Controller)
local function ResetSoftInteract()
    pcall(SetCV, "SoftTargetInteract", "0")
    C_Timer.After(0.05, function()
        local db = ns.GetDB()
        if db and db.cvarBackup then pcall(SetCV, "SoftTargetInteract", "3") end
    end)
end

function ns.CVarApply()
    local db = ns.GetDB()
    if type(db.cvarBackup) == "table" then return end
    local backup = {}
    local function guard(list)
        for name, val in pairs(list) do
            local cur = CV(name)
            if cur then
                backup[name] = cur
                pcall(SetCV, name, val)
            end
        end
    end
    guard({ SoftTargetInteractArc = INTERACT_ARC,
            SoftTargetInteractRange = tostring(db.interactRange or ns.defaults.interactRange) })
    db.cvarRange = db.interactRange
    -- Anzeige nur, solange die Angel draussen ist (sonst erscheinen Symbole ueber Erzen, Kraeutern usw.)
    guard(ns.IsFishingChannel() and (MARKER_GUARD[db.bobberMarker] or MARKER_GUARD.icon) or MARKER_GUARD.off)
    db.cvarMarker = db.bobberMarker
    local si = CV("SoftTargetInteract")
    if si then backup.SoftTargetInteract = si end
    db.cvarBackup = backup
    if si then ResetSoftInteract() end
    ns.Dbg("CVars gesetzt, Sicherung: " .. (si or "?"))
end

-- Schwimmer-Anzeige an (im Angelkanal) bzw. aus (sonst). Aendert nur die Anzeige, nicht die Zielerkennung.
local function SetMarker(on)
    local db = ns.GetDB()
    if not db or type(db.cvarBackup) ~= "table" then return end
    local list = on and (MARKER_GUARD[db.bobberMarker] or MARKER_GUARD.icon) or MARKER_GUARD.off
    for name, val in pairs(list) do
        if db.cvarBackup[name] ~= nil and CV(name) ~= val then pcall(SetCV, name, val) end
    end
end

function ns.CVarRestore(reason)
    local db = ns.GetDB()
    if not db or type(db.cvarBackup) ~= "table" then return end
    for name, val in pairs(db.cvarBackup) do pcall(SetCV, name, val) end
    db.cvarBackup = nil
    ns.Dbg("CVars wiederhergestellt (" .. tostring(reason) .. ")")
end

-- Ist das Soft-Interact-Ziel der Schwimmer (und nicht ein anderes Objekt in der Naehe)?
local function TargetIsBobber()
    local guid = UnitGUID("softinteract")
    if guid == nil or IsSecret(guid) then return false end
    return guid:find("-" .. BOBBER_ENTRY .. "-", 1, true) ~= nil
end
ns.TargetIsBobber = TargetIsBobber

-- Selbstheilung: Nach dem Auswerfen pruefen, ob der Schwimmer als Ziel erkannt wurde.
-- Pruefung 1: Reset. Letzte Pruefung: Hinweis und (Option) Angel-Taste wirft neu aus.
ns.bobberLost = false
local castToken = 0
local function CheckSoftTarget(try, token, last)
    if token ~= castToken or not ns.IsFishingChannel() then return end
    -- Kampf: CVars sind zurueckgesetzt, die Pruefung waere falsch (Log 0.9.7)
    if InCombatLockdown() or UnitAffectingCombat("player") then return end
    if TargetIsBobber() then
        if ns.bobberLost then
            ns.bobberLost = false
            if ns.RefreshKeys then ns.RefreshKeys("Schwimmer doch erkannt") end
        end
        ns.Dbg("Schwimmer als Ziel erkannt (Pruefung " .. try .. ")")
        return
    end
    ns.Dbg("Schwimmer nicht als Ziel erkannt - Pruefung " .. try .. ", Ziel=" .. ns.S(UnitGUID("softinteract"))
        .. ", Range=" .. tostring(CV("SoftTargetInteractRange")) .. ", Arc=" .. tostring(CV("SoftTargetInteractArc")))
    if last then
        ns.bobberLost = true
        local db = ns.GetDB()
        db.bobberMisses = (db.bobberMisses or 0) + 1
        if ns.lastCastMouse then
            ns.Dbg("Wurf per Maus: keine Warnung")
        else
            ns.Error(db.recastOnLost and L.MSG_BOBBER_LOST_RECAST or L.MSG_BOBBER_LOST)
            if db.lostSound ~= "off" then ns.PlayLostSound(db.lostSound) end
        end
        -- Weiter pruefen: wird der Schwimmer doch noch erkannt, holt die Taste wieder ein
        local function Watch()
            if token ~= castToken or not ns.bobberLost or not ns.IsFishingChannel() then return end
            if TargetIsBobber() then
                ns.bobberLost = false
                ns.Dbg("Schwimmer spaeter doch erkannt")
                if ns.RefreshKeys then ns.RefreshKeys("Schwimmer spaeter erkannt") end
                return
            end
            C_Timer.After(0.5, Watch)
        end
        C_Timer.After(0.5, Watch)
        if ns.RefreshKeys then ns.RefreshKeys("Schwimmer nicht erkannt") end
    elseif ns.GetDB().cvarBackup then
        ResetSoftInteract()
    end
end

---------------------------------------------------------------------------
-- Doppelklick
---------------------------------------------------------------------------
local function ClickActive()
    local db = ns.GetDB()
    return db and db.mode == "fishing" and db.clickMode == "double" and not InCombatLockdown()
end

local function Disarm(reason)
    ns.mouseFiring = false
    if click.state == "idle" then return end
    click.state = "idle"
    if not InCombatLockdown() then ClearOverrideBindings(owner) end
    if ns.ReapplyKeys then ns.ReapplyKeys() end   -- Angel-Taste wieder setzen
    ns.Dbg("Doppelklick entschaerft (" .. reason .. ")")
end

local function Arm()
    if click.state ~= "idle" or not ClickActive() then return end
    if not EnsureCastButton() then return end
    local key = MOUSE_KEYS[ns.GetDB().clickButton] or "BUTTON2"
    local lure = ns.LureToApply and ns.LureToApply()
    -- Doppelklick wirft immer aus (auch bei draussen haengender Angel); Einholen macht der
    -- einfache Rechtsklick auf den Schwimmer (Wunsch KarloDerBaer, 0.9.6)
    if lure and ns.PrepareLureButton(lure) then
        SetOverrideBindingClick(owner, true, key, "PeonFishingLureButton", "LeftButton")
    else
        SetOverrideBindingClick(owner, true, key, "PeonFishingCastButton", "LeftButton")
    end
    click.state = "armed"
    ns.Dbg(("Doppelklick scharf: %s -> %s | Kanal=%s | Ziel=%s %s | SoftTargetInteract=%s"):format(
        key, tostring(GetBindingAction(key, true)), tostring(ns.IsFishingChannel()),
        ns.S(UnitGUID("softinteract")), ns.S(UnitName("softinteract")), tostring(CV("SoftTargetInteract"))))
    armToken = armToken + 1
    local my = armToken
    C_Timer.After(DOUBLE_WINDOW, function()
        if armToken == my and click.state == "armed" then Disarm("Zeit") end
    end)
end

local function MouseOnWorld()
    local top
    if GetMouseFoci then
        local foci = GetMouseFoci()
        top = foci and foci[1]
    elseif GetMouseFocus then
        top = GetMouseFocus()
    end
    return top == nil or top == WorldFrame
end

local function OnMouse(event, button)
    local db = ns.GetDB()
    if not db or button ~= db.clickButton then return end
    local now = GetTime()
    if event == "GLOBAL_MOUSE_DOWN" then
        if click.state == "armed" then
            click.state = "firing"
            ns.mouseFiring = true
            ns.Dbg("2. Klick -> " .. tostring(GetBindingAction(MOUSE_KEYS[db.clickButton] or "BUTTON2", true))
                .. " | Ziel=" .. ns.S(UnitGUID("softinteract")))
            C_Timer.After(3, function() if click.state == "firing" then Disarm("Sicherheit") end end)
        else
            click.downT = now
            click.downWorld = MouseOnWorld()
        end
    else
        if click.state == "firing" then
            C_Timer.After(0, function() Disarm("ausgeloest") end)
        elseif click.state == "idle" and click.downT and click.downWorld and now - click.downT < TAP_MAX
            and ClickActive() then
            C_Timer.After(0, Arm)   -- erst im naechsten Frame, damit der erste Klick normal durchgeht
        end
        click.downT = nil
    end
end


---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("GLOBAL_MOUSE_DOWN")
f:RegisterEvent("GLOBAL_MOUSE_UP")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("SPELLS_CHANGED")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "GLOBAL_MOUSE_DOWN" or event == "GLOBAL_MOUSE_UP" then
        if ns.IsFishing() then
            OnMouse(event, arg1)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        if ns.IsFishing() and ns.IsFishingChannel() and not InCombatLockdown() then
            ns.CVarApply()                 -- nur falls noch nicht aktiv (z. B. nach Kampf)
            SetMarker(true)
            ns.bobberLost = false
            castToken = castToken + 1
            local my = castToken
            local db = ns.GetDB()
            db.bobberCasts = (db.bobberCasts or 0) + 1
            C_Timer.After(0.6, function() CheckSoftTarget(1, my) end)
            C_Timer.After(1.5, function() CheckSoftTarget(2, my, true) end)
        end
        if ns.OnChannel then ns.OnChannel(true) end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        SetMarker(false)
        ns.bobberLost = false
        castToken = castToken + 1
        if ns.OnChannel then ns.OnChannel(false) end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Sperre ist hier noch nicht aktiv: alle Belegungen leeren, CVars zuruecksetzen
        click.state = "idle"
        ns.mouseFiring = false
        ClearOverrideBindings(owner)
        ns.CVarRestore("Kampf")
        if ns.OnCombatStart then ns.OnCombatStart() end
    elseif event == "PLAYER_LOGOUT" then
        ns.CVarRestore("Logout")
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.IsFishing() then C_Timer.After(0, function() if not InCombatLockdown() then ns.CVarApply() end end) end
    elseif event == "SPELLS_CHANGED" then
        if not InCombatLockdown() then
            local old = fishingID
            ns.FindFishingSpell()
            if castBtn and fishingID and fishingID ~= old then castBtn:SetAttribute("spell", fishingID) end
        end
    end
end)

table.insert(ns.onModeChanged, function(mode)
    if mode ~= "fishing" and not InCombatLockdown() then
        click.state = "idle"
        ns.mouseFiring = false
        ClearOverrideBindings(owner)
        ns.CVarRestore("Angelmodus aus")
    elseif mode == "fishing" and not InCombatLockdown() then
        -- Einstellungen (z. B. Symbol) geaendert: neu setzen
        local db = ns.GetDB()
        if type(db.cvarBackup) == "table" and (db.cvarMarker ~= db.bobberMarker or db.cvarRange ~= db.interactRange) then
            ns.CVarRestore("Optionen")
        end
        ns.CVarApply()
    end
end)

table.insert(ns.onLogin, function()
    ns.CVarRestore("Login")   -- falls /reload oder Absturz im Angelmodus
    EnsureCastButton()
    if ns.IsFishing() then ns.CVarApply() end
end)
