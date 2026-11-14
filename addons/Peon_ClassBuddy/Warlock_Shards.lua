-- Peon_ClassBuddy - Warlock_Shards.lua (Hexenmeister, ab 0.2.0)
-- Ueberzaehlige Seelensplitter vernichten (Konzept Abschnitt 4).
--
-- Was die Pruefung aus 0.1.0 gezeigt hat (14.11.2026, Build 70938):
--   * Ohne Tastendruck sperrt das Spiel DeleteCursorItem. Also nie aus einem Ereignis oder Zeitgeber.
--   * Per Klick und per Makro (/click) geht es, auch im Kampf.
--   * Aktionstasten laufen ueber UseAction. Ein Nachlauf (hooksecurefunc) darf im selben Tastendruck vernichten.
-- Darum: Mit jedem Zauber von der Aktionsleiste wird hoechstens EIN ueberzaehliger Splitter vernichtet.
-- Klappt es nicht, kommt der naechste Versuch beim naechsten Zauber, der Grund steht im Debug-Log.
-- Dazu der unsichtbare Knopf PeonClassBuddyShard fuer Makro (/click), Tastenbelegung und Panel-Leiste.
--
-- Sicherheit: nur Gegenstand 6265. Gesperrte Plaetze (gerade bewegt oder vernichtet) werden uebersprungen.
-- Haengt nach dem Aufnehmen etwas anderes am Mauszeiger, wird es zurueckgelegt. Nie, wenn der Spieler schon
-- etwas am Mauszeiger hat oder ein Zauber gerade ein Ziel sucht.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local S = {}
ns.Shards = S

local SHARD = 6265           -- Seelensplitter
local SOUL_FAMILY = 4        -- Taschentyp der Seelentasche (Bit 3), in Forever gemessen
local MACRO_NAME, MACRO_BODY = "PeonSplitter", "/click PeonClassBuddyShard"

local active = false
local hooked = false
local destroyed = 0          -- in dieser Sitzung vernichtet

local function Num(v) if v == nil or Peon.IsSecret(v) or type(v) ~= "number" then return nil end return v end

local function LastBag()
    return Num(rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS")) or Num(rawget(_G, "NUM_BAG_SLOTS")) or 4
end

local function IsSoulBag(family)
    if not family or family == 0 then return false end
    local band = (rawget(_G, "bit") and bit.band) or nil
    if band then return band(family, SOUL_FAMILY) ~= 0 end
    return family % (SOUL_FAMILY * 2) >= SOUL_FAMILY
end

local function SlotLocked(bag, slot)
    local fn = C_Container.GetContainerItemInfo
    if not fn then return false end
    local info = fn(bag, slot)
    if type(info) ~= "table" then return false end
    local locked = info.isLocked
    if Peon.IsSecret(locked) then return true end
    return locked == true
end

-- Alle Splitter: { bag, slot, soul, locked }, dazu Zahl der Seelentaschen und ob alle voll sind
function S.Scan()
    local shards, soulBags, soulFree = {}, 0, 0
    for bag = 0, LastBag() do
        local slots = Num(C_Container.GetContainerNumSlots(bag)) or 0
        if slots > 0 then
            local free, family = C_Container.GetContainerNumFreeSlots(bag)
            local soul = IsSoulBag(Num(family))
            if soul then soulBags = soulBags + 1; soulFree = soulFree + (Num(free) or 0) end
            for slot = 1, slots do
                if Num(C_Container.GetContainerItemID(bag, slot)) == SHARD then
                    shards[#shards + 1] = { bag = bag, slot = slot, soul = soul, locked = SlotLocked(bag, slot) }
                end
            end
        end
    end
    return shards, soulBags, soulFree
end

-- Ueberzaehlige Splitter in der Reihenfolge, in der sie vernichtet werden: zuerst ausserhalb der Seelentasche,
-- jeweils von hinten. Rueckgabe: Liste, Gesamtzahl, Grund (bag oder max)
function S.Surplus()
    local db = mod.db
    local shards, soulBags, soulFree = S.Scan()
    local outside, inside = {}, {}
    for i = #shards, 1, -1 do
        local s = shards[i]
        if s.soul then inside[#inside + 1] = s else outside[#outside + 1] = s end
    end
    local list, why = {}, "max"
    if db.shardRule == "bag" and soulBags > 0 then
        why = "bag"
        if soulFree == 0 then list = outside end
    else
        local over = #shards - db.shardMax
        for _, s in ipairs(outside) do if #list < over then list[#list + 1] = s end end
        for _, s in ipairs(inside) do if #list < over then list[#list + 1] = s end end
    end
    return list, #shards, why
end

local function CursorItemID()
    local kind, id = GetCursorInfo()
    if Peon.IsSecret(kind) or Peon.IsSecret(id) or kind ~= "item" then return nil end
    return Num(id)
end

local function Targeting()
    local fn = rawget(_G, "SpellIsTargeting")
    if not fn then return false end
    local on = fn()
    return Peon.IsSecret(on) or on == true
end

-- Einen ueberzaehligen Splitter vernichten. Nur aus einem Tastendruck oder Klick aufrufen.
-- Rueckgabe: true, wenn einer vernichtet wurde, sonst false und Grund
function S.DestroyOne(source)
    local db = mod.db
    if not (active and db and db.shardOn) then return false, "aus" end
    if CursorHasItem() then return false, "Mauszeiger belegt" end
    if Targeting() then return false, "Zauber sucht ein Ziel" end
    local list, _, why = S.Surplus()
    local pick
    for _, s in ipairs(list) do
        if not s.locked then pick = s; break end
    end
    if not pick then return false, (#list > 0) and "alle gesperrt" or "keiner zu viel" end

    local okPick, errPick = pcall(C_Container.PickupContainerItem, pick.bag, pick.slot)
    local onCursor = CursorItemID()
    if not okPick or onCursor ~= SHARD then
        if CursorHasItem() then ClearCursor() end
        return false, okPick and ("Aufnehmen: " .. tostring(onCursor)) or ("Aufnehmen: " .. Peon.S(errPick))
    end
    local okDel, errDel = pcall(DeleteCursorItem)
    if CursorHasItem() then
        ClearCursor()   -- nicht vernichtet: zurueck an seinen Platz
        return false, okDel and "nicht vernichtet" or ("Vernichten: " .. Peon.S(errDel))
    end
    destroyed = destroyed + 1
    mod:Dbg(("Splitter vernichtet (%s, %s, Tasche %d Platz %d)"):format(tostring(source), why, pick.bag, pick.slot))
    if db.shardMsg then
        mod:Print(why == "bag" and L.SH_DONE_BAG or L.SH_DONE_MAX:format(db.shardMax))
    end
    if ns.shardLauncher then ns.shardLauncher:Refresh() end
    return true
end

-- Aus einem Tastendruck: Fehlschlaege nur ins Debug-Log, der Zauber darf nie gestoert werden
local function Try(source)
    local ok, why = S.DestroyOne(source)
    if not ok and why ~= "keiner zu viel" and why ~= "aus" then mod:Dbg(("Nicht vernichtet (%s): %s"):format(tostring(source), tostring(why))) end
    return ok
end
S.Try = Try

local function OnAction()
    local db = mod.db
    if not (active and db and db.shardOn and db.shardAction) then return end
    Try("Aktionstaste")
end

local function InstallHook()
    if hooked or type(rawget(_G, "UseAction")) ~= "function" then return end
    hooked = true
    hooksecurefunc("UseAction", function() mod:Call("Seelensplitter", OnAction) end)
end

-- Unsichtbarer Knopf fuer Makro und Tastenbelegung (Bindings.xml: CLICK PeonClassBuddyShard:LeftButton)
local button = CreateFrame("Button", "PeonClassBuddyShard", UIParent)
button:Hide()
button:SetScript("OnClick", function()
    mod:Call("Seelensplitter", function()
        if not S.DestroyOne("Knopf") and mod.db and mod.db.shardMsg then
            local list = S.Surplus()
            if #list == 0 then mod:Print(L.SH_NONE) end
        end
    end)
end)

-- Makro anlegen und an den Mauszeiger haengen, damit es auf die Leiste gezogen werden kann
function S.MakeMacro()
    if Peon.InCombat() then return mod:Print(L.SH_MACRO_COMBAT) end
    local index = GetMacroIndexByName and GetMacroIndexByName(MACRO_NAME) or 0
    if not index or index == 0 then
        local ok, res = pcall(CreateMacro, MACRO_NAME, "INV_Misc_Gem_Amethyst_02", MACRO_BODY, true)
        if not ok or not res then return mod:Print(L.SH_MACRO_FAIL:format(MACRO_BODY)) end
        index = res
    end
    if PickupMacro then pcall(PickupMacro, index) end
    mod:Print(L.SH_MACRO_DONE)
end

-- /peon classbuddy splitter
function S.Report()
    if not active then return mod:Print(L.SH_NOT_WARLOCK) end
    local list, total = S.Surplus()
    mod:Print(L.SH_REPORT:format(total, #list, destroyed))
end

function S.IsActive() return active end
function S.Destroyed() return destroyed end

-- Eintrag fuer Peon_Panel: Zahl der Splitter, Klick vernichtet einen
local function AddLauncher()
    if not mod.AddLauncher then return end
    ns.shardLauncher = mod:AddLauncher({
        key = "shards", title = L.SH_TITLE, icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02",
        available = function() return active end,
        texts = { { key = "count", label = L.SH_TITLE, get = function()
            local list, total = S.Surplus()
            return #list > 0 and L.SH_TEXT_OVER:format(total, #list) or tostring(total)
        end } },
        defaultText = "count",
        onClick = function() Try("Panel") end,
        onTooltip = function(_, tt)
            local list, total = S.Surplus()
            tt:AddLine(L.SH_TIP_COUNT:format(total), 1, 1, 1)
            if #list > 0 then tt:AddLine(L.SH_TIP_OVER:format(#list), 1, 0.82, 0) end
            tt:AddLine(L.SH_TIP_CLICK, 0.6, 0.6, 0.6, true)
        end,
    })
end

mod:On("INIT", AddLauncher)
mod:On("LOGIN", function()
    if ns.PlayerClass() ~= "WARLOCK" then return end
    active = true
    InstallHook()
    mod:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if ns.shardLauncher then ns.shardLauncher:Refresh() end
    end)
    mod:Dbg("Hexenmeister: Seelensplitter aktiv")
end)

-- fuer Tests
S._SetActive = function(on) active = on; if on then InstallHook() end end
