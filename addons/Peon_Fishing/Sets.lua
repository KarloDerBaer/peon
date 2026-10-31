-- Peon_Fishing - Sets.lua
-- Ausruestungswechsel: Betreten (aktuelle Ausruestung ins Rueckkehr-Set speichern, Angel-Set anlegen)
-- und Verlassen (Rueckkehr-Set anlegen). Im Kampf wird der Wunsch vorgemerkt.
--
-- Ergebnisse Phase 0 (Forever 1.60.1):
-- - C_EquipmentSet.UseEquipmentSet ist im Kampf gesperrt (liefert false), C_Item.EquipItemByName ebenso.
-- - CreateEquipmentSet speichert sofort die getragene Ausruestung.
-- - EQUIPMENT_SWAP_FINISHED(ok, setID) kommt nach dem Wechsel.
-- - isEquipped kann fuer mehrere Sets gleichzeitig true sein, deshalb kein "aktives Set" raten.

local ADDON_NAME, ns = ...
local L = ns.L
local IsSecret = ns.IsSecret

local E = C_EquipmentSet
local NUM_SLOTS = 19
local DEFAULT_ICON = 134400  -- Fragezeichen, falls die Waffe kein Symbol liefert

local swap        -- laufender Wechsel: { kind = "enter"|"leave", id = setID, token = n }
local swapToken = 0

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
-- Set-Infos als Tabelle, nil wenn das Set nicht existiert
function ns.SetInfo(id)
    if not E or type(id) ~= "number" or id < 0 then return nil end
    local ok, name, icon, setID, isEquipped, numItems, numEquipped, numInInventory, numLost =
        pcall(E.GetEquipmentSetInfo, id)
    if not ok or type(name) ~= "string" or IsSecret(name) then return nil end
    return {
        name = name, icon = icon, id = setID, equipped = isEquipped == true,
        items = numItems or 0, inBags = numInInventory or 0, lost = numLost or 0,
    }
end
local SetInfo = ns.SetInfo

function ns.SetNames()
    local names = {}
    local ids = E and E.GetEquipmentSetIDs() or {}
    for _, id in ipairs(ids) do
        local info = SetInfo(id)
        if info then names[#names + 1] = info.name end
    end
    table.sort(names)
    return names
end

local function SetMode(mode)
    local db = ns.GetDB()
    if db.mode == mode then return end
    db.mode = mode
    ns.Dbg("Modus: " .. mode)
    ns.FireModeChanged()
end

-- Sicherheitsnetz: Slot -> Gegenstandslink vor dem Wechsel
local function TakeSnapshot()
    local snap = {}
    for slot = 1, NUM_SLOTS do
        local link = GetInventoryItemLink("player", slot)
        if link and not IsSecret(link) then snap[slot] = link end
    end
    return snap
end

local function RestoreSnapshot(snap)
    local equip = (C_Item and C_Item.EquipItemByName) or EquipItemByName
    local count = 0
    for slot = 1, NUM_SLOTS do
        local link = snap[slot]
        if link and GetInventoryItemLink("player", slot) ~= link then
            local ok = pcall(equip, link, slot)
            if ok then count = count + 1 end
        end
    end
    return count
end

-- Aktuelle Ausruestung in das Set <name> speichern (anlegen, falls es fehlt). Rueckgabe: setID oder nil
local function SaveIntoSet(name)
    local id = E.GetEquipmentSetID(name)
    E.ClearIgnoredSlotsForSave()
    if id then
        -- Vom Spieler ignorierte Slots des Sets beibehalten
        local ignored = E.GetIgnoredSlots(id)
        if type(ignored) == "table" then
            for slot, isIgnored in pairs(ignored) do
                if isIgnored == true then E.IgnoreSlotForSave(slot) end
            end
        end
        local info = SetInfo(id)
        E.SaveEquipmentSet(id, info and info.icon or nil)
        ns.Dbg("Set gespeichert: " .. name .. " (ID " .. id .. ")")
    else
        E.CreateEquipmentSet(name, GetInventoryItemTexture("player", INVSLOT_MAINHAND or 16) or DEFAULT_ICON)
        id = E.GetEquipmentSetID(name)
        if id then ns.Print(L.MSG_SET_CREATED:format(name)) end
    end
    E.ClearIgnoredSlotsForSave()
    return id
end

local function SaveReturnSet()
    return SaveIntoSet(ns.GetDB().returnSetName)
end

local function FinishSwap(result)
    local s = swap
    if not s then return end
    swap = nil
    local db = ns.GetDB()
    local info = SetInfo(s.id)
    local success = result == true or (info and info.equipped)
    ns.Dbg(("Wechsel %s beendet: result=%s, equipped=%s"):format(s.kind, tostring(result), tostring(info and info.equipped)))
    if s.kind == "enter" then
        if success then
            SetMode("fishing")
            ns.Print(L.MSG_ENTERED)
        else
            ns.Error(L.ERR_ENTER_FAILED:format(info and info.name or "?", info and info.lost or 0))
            ns.Print(L.MSG_RETURN_SAVED:format(db.returnSetName))
            ns.FireModeChanged()
        end
    else
        if success then
            db.snapshot = nil
            SetMode("normal")
            ns.Print(L.MSG_LEFT)
        else
            ns.Error(L.ERR_LEAVE_FAILED:format(info and info.name or "?"))
            ns.FireModeChanged()
        end
    end
end

local function StartSwap(kind, id)
    local ok, res = pcall(E.UseEquipmentSet, id)
    if not ok or res == false then
        ns.Dbg("UseEquipmentSet(" .. tostring(id) .. ") -> " .. tostring(ok) .. ", " .. tostring(res))
        return false
    end
    swapToken = swapToken + 1
    local my = swapToken
    swap = { kind = kind, id = id, token = my }
    -- Falls EQUIPMENT_SWAP_FINISHED ausbleibt: nach 5 s selbst pruefen
    C_Timer.After(5, function()
        if swap and swap.token == my then FinishSwap(nil) end
    end)
    ns.FireModeChanged()
    return true
end

function ns.IsSwapping()
    return swap ~= nil
end

---------------------------------------------------------------------------
-- Betreten / Verlassen
---------------------------------------------------------------------------
function ns.Enter()
    local db = ns.GetDB()
    if db.mode == "fishing" then return end
    if not E then ns.Error(L.ERR_NO_API) return end
    local fish = SetInfo(db.fishingSetID)
    if not fish then
        ns.Error(L.ERR_NO_FISHING_SET)
        return
    end
    if ns.InCombat() then
        db.pending = "enter"
        ns.Print(L.MSG_PENDING_ENTER)
        ns.FireModeChanged()
        return
    end
    if swap then ns.Print(L.MSG_SWAP_BUSY) return end
    if fish.lost > 0 then
        ns.Error(L.ERR_ITEMS_MISSING:format(fish.name, fish.lost))
        return
    end
    db.pending = ""

    if fish.equipped then
        -- Angel-Set ist schon angelegt: nichts speichern, damit es nicht ueberschrieben wird
        if not SetInfo(db.returnSetID) then
            db.returnSetID = E.GetEquipmentSetID(db.returnSetName) or -1
        end
        SetMode("fishing")
        ns.Print(L.MSG_ALREADY_EQUIPPED)
        return
    end

    db.snapshot = TakeSnapshot()
    local ok, id = pcall(SaveReturnSet)
    if not ok or type(id) ~= "number" then
        ns.Error(L.ERR_SAVE_FAILED:format(db.returnSetName, ok and "?" or tostring(id)))
        return
    end
    if id == db.fishingSetID then
        ns.Error(L.ERR_SAME_SET)
        return
    end
    db.returnSetID = id
    if not StartSwap("enter", db.fishingSetID) then
        ns.Error(L.ERR_ENTER_FAILED:format(fish.name, fish.lost))
    end
end

function ns.Leave()
    local db = ns.GetDB()
    if db.mode ~= "fishing" then return end
    if ns.InCombat() then
        db.pending = "leave"
        ns.Print(L.MSG_PENDING_LEAVE)
        ns.FireModeChanged()
        return
    end
    if swap then ns.Print(L.MSG_SWAP_BUSY) return end
    db.pending = ""

    local ret = SetInfo(db.returnSetID)
    if ret then
        if ret.equipped then
            db.snapshot = nil
            SetMode("normal")
            ns.Print(L.MSG_LEFT)
        elseif not StartSwap("leave", db.returnSetID) then
            ns.Error(L.ERR_LEAVE_FAILED:format(ret.name))
        end
        return
    end
    -- Rueckkehr-Set fehlt (geloescht?): Sicherheitsnetz
    if type(db.snapshot) == "table" and next(db.snapshot) then
        local n = RestoreSnapshot(db.snapshot)
        ns.Print(L.MSG_SNAPSHOT_RESTORED:format(n))
        db.snapshot = nil
    else
        ns.Error(L.ERR_NO_RETURN)
    end
    SetMode("normal")
end

function ns.Toggle()
    local db = ns.GetDB()
    if not db then return end
    if db.pending ~= "" then
        -- Vorgemerkten Wechsel zuruecknehmen
        db.pending = ""
        ns.Print(L.MSG_PENDING_CANCELLED)
        ns.FireModeChanged()
        return
    end
    if db.mode == "fishing" then ns.Leave() else ns.Enter() end
end

---------------------------------------------------------------------------
-- Angel-Set waehlen (/fp set <Name> oder Optionsmenue)
---------------------------------------------------------------------------
function ns.ChooseFishingSet(name)
    local db = ns.GetDB()
    name = strtrim(name or "")
    if name == "" then
        local cur = SetInfo(db.fishingSetID)
        ns.Print(L.MSG_FISHING_SET_IS:format(cur and cur.name or L.NONE))
        ns.Print(L.MSG_SETS_AVAILABLE:format(table.concat(ns.SetNames(), ", ")))
        return
    end
    local id = E and E.GetEquipmentSetID(name)
    if not id then
        ns.Error(L.ERR_SET_NOT_FOUND:format(name))
        ns.Print(L.MSG_SETS_AVAILABLE:format(table.concat(ns.SetNames(), ", ")))
        return
    end
    if name == db.returnSetName then
        ns.Error(L.ERR_SAME_SET)
        return
    end
    db.fishingSetID = id
    ns.Print(L.MSG_FISHING_SET_IS:format(name))
    ns.FireModeChanged()
end

function ns.PrintStatus()
    local db = ns.GetDB()
    local fish, ret = SetInfo(db.fishingSetID), SetInfo(db.returnSetID)
    local n = 0
    if type(db.snapshot) == "table" then for _ in pairs(db.snapshot) do n = n + 1 end end
    ns.Print(L.MSG_STATUS:format(
        db.mode == "fishing" and L.MODE_FISHING or L.MODE_NORMAL,
        db.pending ~= "" and L["PENDING_" .. db.pending] or "-",
        fish and fish.name or L.NONE,
        ret and ret.name or db.returnSetName,
        n))
end

---------------------------------------------------------------------------
-- Angel-Set speichern (/fp saveset oder Button im Optionsmenue)
---------------------------------------------------------------------------
local function DoSaveFishingSet(name)
    local db = ns.GetDB()
    name = strtrim(name or "")
    if name == "" then return end
    if ns.InCombat() then ns.Error(L.ERR_SAVE_COMBAT) return end
    if name == db.returnSetName then ns.Error(L.ERR_SAME_SET) return end
    local ok, id = pcall(SaveIntoSet, name)
    if not ok or type(id) ~= "number" then
        ns.Error(L.ERR_SAVE_FAILED:format(name, ok and "?" or tostring(id)))
        return
    end
    db.fishingSetID = id
    ns.Print(L.MSG_FISHING_SET_SAVED:format(name))
    ns.FireModeChanged()
end

StaticPopupDialogs["PEON_FISHING_CONFIRM_SAVE"] = {
    text = L.POPUP_CONFIRM_SAVE,
    button1 = YES, button2 = NO,
    OnAccept = function(_, data) DoSaveFishingSet(data) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function PopupEditBox(self)
    return self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
end

StaticPopupDialogs["PEON_FISHING_NAME_SET"] = {
    text = L.POPUP_NAME_SET,
    button1 = ACCEPT, button2 = CANCEL,
    hasEditBox = true, maxLetters = 16,
    OnShow = function(self)
        local eb = PopupEditBox(self)
        if eb then eb:SetText(L.DEFAULT_FISHING_SET_NAME); eb:HighlightText(); eb:SetFocus() end
    end,
    OnAccept = function(self, data)
        local eb = PopupEditBox(self)
        local name = eb and eb:GetText() or ""
        if data == "confirm" then
            StaticPopup_Show("PEON_FISHING_CONFIRM_SAVE", name, nil, name)
        else
            DoSaveFishingSet(name)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local accept = StaticPopupDialogs["PEON_FISHING_NAME_SET"].OnAccept
        accept(parent, parent.data)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- Speichert die getragene Ausruestung ins Angel-Set. Ausserhalb des Angelmodus nur mit Bestaetigung,
-- fehlt das Angel-Set, wird vorher nach dem Namen gefragt.
function ns.SaveFishingSet()
    local db = ns.GetDB()
    if ns.InCombat() then ns.Error(L.ERR_SAVE_COMBAT) return end
    local fish = SetInfo(db.fishingSetID)
    local needConfirm = db.mode ~= "fishing"
    if not fish then
        StaticPopup_Show("PEON_FISHING_NAME_SET", nil, nil, needConfirm and "confirm" or nil)
    elseif needConfirm then
        StaticPopup_Show("PEON_FISHING_CONFIRM_SAVE", fish.name, nil, fish.name)
    else
        DoSaveFishingSet(fish.name)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
f:SetScript("OnEvent", function(_, event, result, setID)
    if event == "EQUIPMENT_SWAP_FINISHED" and swap and setID == swap.id then
        FinishSwap(result)
    end
end)

-- Nach dem Kampf vorgemerkten Wechsel ausfuehren
table.insert(ns.onCombatEnd, function()
    local db = ns.GetDB()
    if db.pending == "enter" then
        db.pending = ""
        ns.Enter()
    elseif db.pending == "leave" then
        db.pending = ""
        ns.Leave()
    end
end)

table.insert(ns.onLogin, function()
    local db = ns.GetDB()
    if db.mode == "fishing" then
        ns.Print(L.MSG_STILL_FISHING)
    end
    ns.FireModeChanged()
end)
