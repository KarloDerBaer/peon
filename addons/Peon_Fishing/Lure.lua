-- Peon_Fishing - Lure.lua
-- Koeder: Auswahl (Automatisch = hoechster Bonus / Kein Koeder / bestimmter Koeder), Anlegen per
-- Angel-Taste bzw. Doppelklick (geschuetzte Aktion, braucht den Tastendruck des Spielers),
-- Erneuern bei weniger als 30 s Restzeit, Warnung wenn kein Koeder aktiv und keiner verfuegbar ist.
--
-- Erkennung: Liste bekannter Koeder, sonst Tooltip ("Benutzen: ... Angel... um 75").
-- Aktiver Koeder: GetWeaponEnchantInfo() auf der Waffenhand (Angel).

local ADDON_NAME, ns = ...
local L = ns.L
local IsSecret = ns.IsSecret

local RENEW_SECONDS = 30
-- Bekannte Koeder (itemID -> Bonus). Weitere werden ueber den Tooltip erkannt.
local KNOWN = {
    [6529] = 25,   -- Glaenzender Tand / Shiny Bauble
    [6530] = 50,   -- Nachtkriecher / Nightcrawlers
    [6811] = 50,   -- Aquadynamische Fischlinse / Aquadynamic Fish Lens
    [6532] = 75,   -- Helle Tandbaubles / Bright Baubles
    [7307] = 75,   -- Fleischfressender Wurm / Flesh Eating Worm
    [6533] = 100,  -- Aquadynamischer Fischanlocker / Aquadynamic Fish Attractor
    [34861] = 100, -- Geschaerfter Angelhaken / Sharpened Fish Hook
    [46006] = 100, -- Gluehwurm / Glow Worm
}

local cache = {}          -- itemID -> Bonus oder false
local lures, byID = {}, {}
local warned = false
local lureBtn

---------------------------------------------------------------------------
-- Erkennung
---------------------------------------------------------------------------
local function ParseBonus(bag, slot, itemID)
    if cache[itemID] ~= nil then return cache[itemID] end
    local bonus = KNOWN[itemID] or false
    if not bonus and C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
        if ok and type(data) == "table" and not (issecrettable and issecrettable(data)) and type(data.lines) == "table" then
            for _, line in ipairs(data.lines) do
                local t = line.leftText
                if type(t) == "string" and not IsSecret(t) then
                    local lt = t:lower()
                    if (lt:find("angel") or lt:find("fishing")) and (lt:find("benutzen") or lt:find("use:")) then
                        local n = t:match("um (%d+)") or t:match("by (%d+)") or t:match("%+(%d+)")
                        if n then bonus = tonumber(n) break end
                    end
                end
            end
        end
    end
    cache[itemID] = bonus
    return bonus
end

local function IsUsable(itemID)
    local fn = (C_Item and C_Item.IsUsableItem) or IsUsableItem
    if not fn then return true end
    local ok, usable = pcall(fn, itemID)
    return ok and usable == true
end

local function ItemName(itemID)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if not name and GetItemInfo then name = GetItemInfo(itemID) end
    return name or ("item:" .. itemID)
end

-- Koeder in den Taschen; sortiert nach Bonus (hoechster zuerst)
function ns.ScanLures()
    wipe(lures); wipe(byID)
    if not (C_Container and C_Container.GetContainerNumSlots) then return lures end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not IsSecret(id) then
                local bonus = ParseBonus(bag, slot, id)
                if bonus then
                    local e = byID[id]
                    if not e then
                        e = { id = id, bonus = bonus, count = 0, icon = info.iconFileID }
                        byID[id] = e
                        lures[#lures + 1] = e
                    end
                    e.count = e.count + (info.stackCount or 1)
                end
            end
        end
    end
    for _, e in ipairs(lures) do
        e.name = ItemName(e.id)
        e.usable = IsUsable(e.id)
    end
    table.sort(lures, function(a, b)
        if a.bonus ~= b.bonus then return a.bonus > b.bonus end
        return a.id < b.id
    end)
    return lures
end

-- Aktiver Koeder auf der Angel: aktiv, Restsekunden
function ns.LureActive()
    if not GetWeaponEnchantInfo then return false, 0 end
    local ok, has, expMs = pcall(GetWeaponEnchantInfo)
    if not ok or IsSecret(has) or IsSecret(expMs) or not has then return false, 0 end
    return true, (tonumber(expMs) or 0) / 1000
end

-- Welcher Koeder soll jetzt angelegt werden? itemID oder nil
function ns.LureToApply()
    local db = ns.GetDB()
    if not db or db.mode ~= "fishing" or db.lure == "none" then return nil end
    if ns.IsFishingChannel() then return nil end
    local active, left = ns.LureActive()
    if active and left >= RENEW_SECONDS then
        warned = false
        return nil
    end
    local pick
    if db.lure == "auto" then
        for _, e in ipairs(lures) do
            if e.usable then pick = e break end
        end
    elseif type(db.lure) == "number" then
        local e = byID[db.lure]
        if e and e.usable then pick = e end
    end
    if pick then
        warned = false
        return pick.id
    end
    -- Kein Koeder verfuegbar: warnen, sobald keiner mehr aktiv ist (einmal pro Ablauf)
    if not active and not warned then
        warned = true
        if db.lure == "auto" then
            ns.Error(L.LURE_NONE_AUTO)
        else
            ns.Error(L.LURE_NONE_SPECIFIC:format(ItemName(db.lure)))
        end
    end
    return nil
end

-- Sicheren Koeder-Button fuer itemID vorbereiten (nur ausserhalb des Kampfes)
function ns.PrepareLureButton(itemID)
    if InCombatLockdown() or not itemID then return false end
    if not lureBtn then
        lureBtn = CreateFrame("Button", "PeonFishingLureButton", UIParent, "SecureActionButtonTemplate")
        lureBtn:RegisterForClicks("AnyUp", "AnyDown")
        lureBtn:HookScript("PostClick", function(_, _, down)
            if down then ns.Dbg("Koeder anlegen gedrueckt") end
        end)
    end
    lureBtn:SetAttribute("type", "item")
    lureBtn:SetAttribute("item", "item:" .. itemID)
    lureBtn:SetAttribute("target-slot", INVSLOT_MAINHAND or 16)
    return true
end

---------------------------------------------------------------------------
-- Auswahl
---------------------------------------------------------------------------
function ns.SetLureChoice(v)
    local db = ns.GetDB()
    db.lure = v
    warned = false
    local text = v == "auto" and L.LURE_AUTO or v == "none" and L.LURE_NONE_CHOICE or ItemName(v)
    ns.Print(L.LURE_CHOSEN:format(text))
    if ns.RefreshKeys then ns.RefreshKeys("Koeder gewaehlt") end
end

function ns.LureStatusText()
    local active, left = ns.LureActive()
    if not active then return L.LURE_STATUS_NONE end
    return L.LURE_STATUS_ACTIVE:format(math.floor(left / 60), math.floor(left % 60))
end

function ns.PrintLures()
    ns.ScanLures()
    ns.Print(ns.LureStatusText())
    if #lures == 0 then ns.Print(L.LURE_NONE_IN_BAGS) end
    for _, e in ipairs(lures) do
        ns.Print(("%s +%d x%d%s"):format(e.name, e.bonus, e.count, e.usable and "" or " |cffff6060(" .. L.LURE_NOT_USABLE .. ")|r"))
    end
end

function ns.GetLures() return lures end

---------------------------------------------------------------------------
-- Aktualisieren: Taschen, Verzauberung, Restzeit (1 s Takt im Angelmodus)
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
f:SetScript("OnEvent", function()
    ns.ScanLures()
    if ns.RefreshKeys then ns.RefreshKeys("Taschen/Koeder") end
end)

local acc = 0
f:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 1 then return end
    acc = 0
    if ns.IsFishing() and not InCombatLockdown() and ns.RefreshKeys then ns.RefreshKeys("Takt") end
end)

table.insert(ns.onLogin, function() ns.ScanLures() end)
