-- Peon_Ledger - Pick.lua
-- Ab 0.9.1 (KarloDerBaer 06.10.2026): Gegenstand unter der Maus im Reiter "Gegenstand" zeigen.
--   Alt+Linksklick ueberall, wo ein Gegenstands-Tooltip erscheint (GLOBAL_MOUSE_DOWN + Tooltip), ausser auf
--   Aktionsleisten (dort loest das Spiel bei Alt+Klick zusaetzlich die Taste aus). Dazu Alt+Klick auf Links im Chat
--   und alles, was das Spiel als Klick mit Taste meldet (HandleModifiedItemClick).
--   Tastenbelegung PEON_LEDGER_ITEM (Bindings.xml): Gegenstand im Tooltip unter der Maus, auch auf Aktionsleisten.
-- Alt+Klick gehoerte bis Broker 0.27.0 dem Broker (Verkaufen, Einkaufsliste) - dort entfernt.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local P = {}
ns.Pick = P

P.DEDUP = 0.4   -- Sekunden: derselbe Klick kommt ueber zwei Wege (Maus + HandleModifiedItemClick)

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

function P.IDFromLink(link)
    if type(link) ~= "string" or Peon.IsSecret(link) then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- Aktionsleisten-Knopf? (dann bei Alt+Klick nichts tun)
function P.IsActionButton(owner)
    if type(owner) ~= "table" then return false end
    if rawget(owner, "action") ~= nil and type(owner.action) == "number" then return true end
    local name = owner.GetName and owner:GetName()
    if type(name) ~= "string" or Peon.IsSecret(name) then return false end
    return name:find("ActionButton", 1, true) or name:find("MultiBar", 1, true) or name:find("StanceButton", 1, true)
        or name:find("PetAction", 1, true) or name:find("PossessButton", 1, true) or name:find("OverrideActionBar", 1, true)
        or false
end

-- Gegenstand aus einem sichtbaren Tooltip: GameTooltip, sonst der Tooltip eines Chat-Links unter der Maus
function P.TooltipItem(skipActionBars)
    for _, tipName in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
        local tip = rawget(_G, tipName)
        if type(tip) == "table" and tip.IsShown and tip:IsShown() and tip.GetItem then
            local ok, _, link = pcall(tip.GetItem, tip)
            local id = ok and P.IDFromLink(link)
            if id then
                if tipName == "ItemRefTooltip" and not (tip.IsMouseOver and tip:IsMouseOver()) then id = nil end
                if id and skipActionBars and tip.GetOwner and P.IsActionButton(tip:GetOwner()) then return nil, true end
                if id then return id end
            end
        end
    end
    return nil
end

function P.Open(id)
    if not Num(id) then return false end
    local now = GetTime and GetTime() or 0
    if P.last == id and P.lastT and now - P.lastT < P.DEDUP then return true end
    P.last, P.lastT = id, now
    mod:ShowItem(id)
    return true
end

local function AltOnly()
    return IsAltKeyDown and IsAltKeyDown() and not (IsControlKeyDown and IsControlKeyDown()) and not (IsShiftKeyDown and IsShiftKeyDown())
end

function P.OnMouseDown(button)
    if button ~= "LeftButton" or not AltOnly() then return end
    local id = P.TooltipItem(true)
    if id then P.Open(id) end
end

function P.OnModifiedClick(link)
    if not AltOnly() then return end
    local id = P.IDFromLink(link)
    if id then P.Open(id) end
end

-- Tastenbelegung (Bindings.xml)
function PeonLedger_ShowHoverItem()
    local id = P.TooltipItem(false)
    if id then P.Open(id) else mod:Print(L.PICK_NONE) end
end

function P.Init()
    pcall(mod.RegisterEvent, mod, "GLOBAL_MOUSE_DOWN", function(_, button) mod:Call("Gegenstand", P.OnMouseDown, button) end)
    if hooksecurefunc and rawget(_G, "HandleModifiedItemClick") then
        hooksecurefunc("HandleModifiedItemClick", function(link) mod:Call("Gegenstand", P.OnModifiedClick, link) end)
    end
end
