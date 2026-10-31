-- Peon_Fishing - Combat.lua
-- Kampfverhalten im Angelmodus (Variante D, einstellbar).
--
-- Hintergrund (Phase 0 / Blizzard): Im Kampf darf Addon-Code weder Sets noch einzelne Gegenstaende
-- anlegen. Ein sicherer Makro-Button (/equipslot) darf es aber, wenn der Spieler ihn per Taste
-- ausloest. PLAYER_REGEN_DISABLED kommt noch vor der Kampfsperre, dort lassen sich Belegungen setzen.
--
-- Ablauf:
--  - Ausserhalb des Kampfes wird der Waffen-Button mit den Waffen des Rueckkehr-Sets vorbereitet.
--  - Kampfbeginn im Angelmodus: automatischer Versuch, die Waffen anzulegen (optional), dann die
--    Angel-Taste auf den Waffen-Button legen und Warnung zeigen.
--  - Hing die Angel bei Kampfbeginn im Wasser, scheitert der automatische Versuch ("Das geht jetzt
--    nicht"). Dann liegt zusaetzlich die Doppelklick-Maustaste einmalig auf dem Waffen-Button; ein
--    gesicherter Handler gibt sie nach dem ersten Klick auch im Kampf wieder frei.
--  - Kampfende: Belegung freigeben, dann je nach Einstellung fragen / verlassen / weiter angeln.

local ADDON_NAME, ns = ...
local L = ns.L
local IsSecret = ns.IsSecret

local E = C_EquipmentSet
local weaponOwner = CreateFrame("Frame", "PeonFishingWeaponOwner")
local fought = false           -- Kampf fand im Angelmodus statt

-- Sicherer Makro-Button; Bindings.xml belegt ihn direkt ("CLICK PeonFishingWeaponButton:LeftButton")
local weaponBtn = CreateFrame("Button", "PeonFishingWeaponButton", UIParent, "SecureActionButtonTemplate")
weaponBtn:RegisterForClicks("AnyUp", "AnyDown")

-- Einmal-Belegung der Maustaste: Eigentuemer ist ein gesicherter Handler, der sie beim Klick
-- (auch in der Kampfsperre) wieder loescht.
local mouseOwner = CreateFrame("Frame", "PeonFishingWeaponMouseOwner", UIParent, "SecureHandlerBaseTemplate")
local mouseOnce = SecureHandlerWrapScript and pcall(SecureHandlerWrapScript, weaponBtn, "OnClick", mouseOwner,
    [[ owner:ClearBindings() ]])
local MOUSE_KEYS = { RightButton = "BUTTON2", MiddleButton = "BUTTON3",
    Button4 = "BUTTON4", Button5 = "BUTTON5" }
weaponBtn:SetAttribute("type", "macro")

local function ItemIDFromLink(link)
    if type(link) ~= "string" or IsSecret(link) then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- Waffen, zu denen zurueckgekehrt wird: aus dem Rueckkehr-Set, sonst aus der gemerkten Liste
local function ReturnWeapons()
    local db = ns.GetDB()
    local mh, oh
    if ns.SetInfo(db.returnSetID) then
        local items = E.GetItemIDs(db.returnSetID)
        if type(items) == "table" then
            mh, oh = items[16], items[17]
        end
    end
    if (type(mh) ~= "number" or mh <= 1) and type(db.snapshot) == "table" then
        mh = ItemIDFromLink(db.snapshot[16])
        oh = ItemIDFromLink(db.snapshot[17])
    end
    if type(mh) ~= "number" or mh <= 1 then mh = nil end
    if type(oh) ~= "number" or oh <= 1 then oh = nil end
    return mh, oh
end

local function UpdateWeaponButton()
    if InCombatLockdown() then return end
    local mh, oh = ReturnWeapons()
    local lines = {}
    if mh then
        lines[#lines + 1] = "/stopcasting"          -- ausgeworfene Angel einholen, sonst scheitert der Wechsel
        lines[#lines + 1] = "/equipslot 16 item:" .. mh
    end
    if oh then lines[#lines + 1] = "/equipslot 17 item:" .. oh end
    weaponBtn:SetAttribute("macrotext", table.concat(lines, "\n"))
    ns.Dbg("Waffen-Button: " .. (#lines > 0 and table.concat(lines, " | ") or "leer"))
end
ns.UpdateWeaponButton = UpdateWeaponButton

-- Traegt der Spieler gerade die Angel (Waffe des Angel-Sets)?
local function WearingFishingWeapon()
    local db = ns.GetDB()
    if not ns.SetInfo(db.fishingSetID) then return false end
    local items = E.GetItemIDs(db.fishingSetID)
    local want = type(items) == "table" and items[16]
    local cur = GetInventoryItemID("player", 16)
    if IsSecret(cur) or type(want) ~= "number" or want <= 1 then return false end
    return cur == want
end

local function OnCombatStart()
    local db = ns.GetDB()
    if not db or db.mode ~= "fishing" then return end
    fought = true
    if not WearingFishingWeapon() then return end
    local mh, oh = ReturnWeapons()
    if not mh then
        ns.Error(L.MSG_COMBAT_NO_WEAPONS)
        return
    end
    -- 1. Automatischer Versuch (Kampfsperre ist hier noch nicht aktiv)
    if db.combatWeaponTry then
        local equip = (C_Item and C_Item.EquipItemByName) or EquipItemByName
        local ok1 = pcall(equip, mh, 16)
        local ok2 = true
        if oh then ok2 = pcall(equip, oh, 17) end
        ns.Dbg(("Kampfbeginn: automatischer Waffenwechsel (Lockdown=%s) %s/%s")
            :format(tostring(InCombatLockdown()), tostring(ok1), tostring(ok2)))
    end
    -- 2. Angel-Taste auf den Waffen-Button legen
    local keys = { GetBindingKey("PEON_FISHING_ACTION") }
    if not InCombatLockdown() then
        for _, key in ipairs(keys) do
            SetOverrideBindingClick(weaponOwner, true, key, "PeonFishingWeaponButton", "LeftButton")
        end
    end
    -- 2b. Angel im Wasser: der automatische Versuch scheitert. Maustaste (Doppelklick-Modus)
    --     einmalig auf den Waffen-Button legen.
    local mouseKey
    if mouseOnce and db.clickMode == "double" and ns.IsFishingChannel and ns.IsFishingChannel() and not InCombatLockdown() then
        mouseKey = MOUSE_KEYS[db.clickButton] or "BUTTON2"
        SetOverrideBindingClick(mouseOwner, true, mouseKey, "PeonFishingWeaponButton", "LeftButton")
        ns.Dbg("Kampfbeginn mit Angel im Wasser: " .. mouseKey .. " -> Waffen-Button (einmalig)")
    end
    -- 3. Warnung
    local hint = #keys > 0 and L.MSG_COMBAT_KEY:format(table.concat(keys, ", ")) or L.MSG_COMBAT_BIND
    if mouseKey then hint = hint .. " " .. L.MSG_COMBAT_MOUSE end
    ns.Error(L.MSG_COMBAT_WARN .. " " .. hint)
    -- Nach kurzer Zeit melden, ob der automatische Versuch geklappt hat
    C_Timer.After(1.5, function()
        if GetInventoryItemID("player", 16) == mh then ns.Print(L.MSG_COMBAT_WEAPONS_ON) end
    end)
end
ns.OnCombatStart = OnCombatStart

local function ReequipFishing()
    local db = ns.GetDB()
    if db.mode ~= "fishing" or not ns.SetInfo(db.fishingSetID) then return end
    local info = ns.SetInfo(db.fishingSetID)
    if info.equipped then return end
    local ok, res = pcall(E.UseEquipmentSet, db.fishingSetID)
    if ok and res ~= false then ns.Print(L.MSG_COMBAT_BACK_FISHING) end
end

StaticPopupDialogs["PEON_FISHING_AFTER_COMBAT"] = {
    text = L.POPUP_AFTER_COMBAT,
    button1 = L.BTN_LEAVE, button2 = L.BTN_STAY,
    OnAccept = function() ns.Leave() end,
    OnCancel = function(_, _, reason)
        if reason == "clicked" then ReequipFishing() end
    end,
    timeout = 0, whileDead = false, hideOnEscape = true, preferredIndex = 3,
}

local function OnCombatEnd()
    if not InCombatLockdown() then
        ClearOverrideBindings(weaponOwner)
        ClearOverrideBindings(mouseOwner)
    end
    local db = ns.GetDB()
    if not fought then return end
    fought = false
    if db.mode ~= "fishing" or db.pending ~= "" then return end   -- vorgemerkter Wechsel hat Vorrang
    if WearingFishingWeapon() then return end                      -- nichts gewechselt: weiter angeln
    if db.afterCombat == "leave" then
        ns.Leave()
    elseif db.afterCombat == "stay" then
        ReequipFishing()
    else
        StaticPopup_Show("PEON_FISHING_AFTER_COMBAT")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("EQUIPMENT_SETS_CHANGED")
f:SetScript("OnEvent", function()
    C_Timer.After(0, UpdateWeaponButton)
end)

-- Vor dem Nachholen vorgemerkter Wechsel (Sets.lua) laufen, damit "pending" noch sichtbar ist
table.insert(ns.onCombatEnd, 1, function()
    OnCombatEnd()
    UpdateWeaponButton()
end)
table.insert(ns.onModeChanged, function() UpdateWeaponButton() end)
table.insert(ns.onLogin, function() UpdateWeaponButton() end)
