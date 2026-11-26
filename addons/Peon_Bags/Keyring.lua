-- Peon_Bags - Keyring.lua
-- Schluesselbund als eigenes kleines Fenster (ab 0.10, Wunsch KarloDerBaer): Der Knopf Schluesselbund des
-- Spiels und der Knopf in der Taschenleiste oeffnen es. Mit der Einstellung keyWithBags steht der Schluesselbund
-- stattdessen als Abschnitt im Taschenfenster (wie 0.8 und 0.9). Die Plaetze sind dieselben Taschenknoepfe,
-- das Fenster holt den Rahmen der Tasche zu sich (ns.BagFrame).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

local w
local COLS = 8
local ICON = "Interface\\Icons\\INV_Misc_Key_03"

-- eigenes Fenster statt Abschnitt im Taschenfenster?
function ns.KeyringSeparate()
    return ns.KeyringID() ~= nil and not mod.db.keyWithBags
end

local function Refresh()
    if not w or not w:IsShown() then return end
    local kb = ns.KeyringID()
    if not kb then return end
    -- Rahmen der Tasche umhaengen geht im Kampf nicht, wenn er geschuetzte Knoepfe hat
    local kf = ns.bagFrames[kb]
    if kf and kf:GetParent() ~= w.content and InCombatLockdown() then
        ns.Defer("key:refresh", Refresh)
        return
    end
    local items, all = {}, {}
    if not ns.CollectBagSlots(kb, w.content, items, all) then ns.Defer("key:refresh", Refresh) end
    w:Arrange({ { title = nil, items = items } }, all)
    local n = ns.NumSlots(kb)
    w:SetFooter(L.FREE_KEYRING:format(n - ns.FreeSlots(kb), n), "")
end

function ns.ToggleKeyring()
    if not w then return end
    if w:IsShown() then w:Hide() return end
    if not ns.KeyringSeparate() then return end
    w:Show()
end

function ns.InitKeyring()
    if not ns.KeyringID() then return end
    w = ns.NewWindow("key", {
        title = L.SEC_KEYRING, searchable = false, topH = 34, minWidth = 200,
        template = "PortraitFrameFlatTemplate", portrait = ICON, portraitSize = 36, border = "HeldBagLayout",
        point = { "BOTTOMRIGHT", -540, 100 },
        onShow = function() Refresh() end,
        onHide = function()
            -- Taschenfenster mit Schluesselbund: Plaetze dort wieder anordnen
            if mod.db.keyWithBags and ns.RefreshBags then ns.RefreshBags() end
        end,
    })
    -- feste Spaltenzahl, keine eigenen Einstellungen (keine Tabellen in PeonBagsDB)
    w.Cols = function() return COLS end
    w.Setting = function(_, name) if name == "Scale" then return mod.db.bagScale end return nil end
    w.Table = function() return {} end
    w.Refresh = Refresh
    w.Apply = function()
        w:ApplyPosition()
        if not ns.KeyringSeparate() then w:Hide() elseif w:IsShown() then Refresh() end
    end
    w.Apply()

    local kb = ns.KeyringID()
    mod:RegisterEvent("BAG_UPDATE", function(_, bag)
        if bag == kb and w:IsShown() then w.dirty = true end
    end)
    mod:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if w.dirty then w.dirty = nil; Refresh() end
    end)
    mod:RegisterEvent("ITEM_LOCK_CHANGED", function(_, bag, slot)
        if bag ~= kb or not w:IsShown() or not ns.Num(slot) then return end
        local b = ns.slots[kb] and ns.slots[kb][slot]
        if b then ns.UpdateSlot(b) end
    end)
end
