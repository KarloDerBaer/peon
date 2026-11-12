-- Peon_Ledger - Pick.lua
-- Tastenbelegung PEON_LEDGER_ITEM (Bindings.xml): Gegenstand im Tooltip unter der Maus zeigen, auch auf
-- Aktionsleisten. Ab 0.14 oeffnet sie die Seite Gegenstand in Broker (mod:ShowItem). Alt+Klick entfaellt
-- (entschieden: Gegenstandsmenue des Kerns mit Strg+Rechtsklick, Neuaufbau Abschnitt 7).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local P = {}
ns.Pick = P

function P.IDFromLink(link)
    if type(link) ~= "string" or Peon.IsSecret(link) then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- Gegenstand aus einem sichtbaren Tooltip: GameTooltip, sonst der Tooltip eines Chat-Links unter der Maus
function P.TooltipItem()
    for _, tipName in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
        local tip = rawget(_G, tipName)
        if type(tip) == "table" and tip.IsShown and tip:IsShown() and tip.GetItem then
            local ok, _, link = pcall(tip.GetItem, tip)
            local id = ok and P.IDFromLink(link)
            if id and tipName == "ItemRefTooltip" and not (tip.IsMouseOver and tip:IsMouseOver()) then id = nil end
            if id then return id end
        end
    end
    return nil
end

function PeonLedger_ShowHoverItem()
    local id = P.TooltipItem()
    if id then mod:ShowItem(id) else mod:Print(L.PICK_NONE) end
end
