-- Peon_Bridge - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Bridge und Knopf "An Manager" am Auktionshaus.

local ADDON_NAME, ns = ...
local L = ns.L

StaticPopupDialogs["PEON_BRIDGE_CLEAR"] = {
    text = "%s", button1 = YES or "Ja", button2 = NO or "Nein",
    OnAccept = function()
        ns.mod.acc.queue = {}
        ns.mod:Print(L.CLEARED)
        if ns.mod.page then ns.mod.page:Refresh() end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC })

    local left = page:Column(16, -60)
    page:Add(left, page:Header(L.HDR_STATUS), 6)
    page:Add(left, page:Text(function() return table.concat(ns.StatusLines(), "\n") end), 12)
    page:Add(left, page:Header(L.HDR_HANDOVER), 6)
    page:Add(left, page:Slider("queueMax", L.QUEUE_MAX, L.QUEUE_MAX_HINT))
    page:Add(left, page:Slider("liveMax", L.LIVE_MAX, L.LIVE_MAX_HINT))
    page:Add(left, page:Check("offerButton", L.OFFER_BUTTON, L.OFFER_BUTTON_HINT), 20)
    page:Add(left, page:Button(L.SEND, function() ns.Send() end, L.SEND_HINT))
    page:Add(left, page:Button(L.CLEAR, function()
        local n = #(mod.acc.queue or {})
        if n == 0 then return end
        if StaticPopup_Show then StaticPopup_Show("PEON_BRIDGE_CLEAR", L.CLEAR_CONFIRM:format(n)) end
    end, L.CLEAR_HINT))
    page:Add(left, page:Header(L.HDR_VALUES), 6)
    page:Add(left, page:Slider("freshDays", L.FRESH_DAYS, L.FRESH_DAYS_HINT))

    page:AddResetButton(L.SLASH_HINT, left)
    page:Register()
end

-- Knopf "An Manager" unter Brokers Scan-Knopf, nach einem Komplettscan (bis zum Schliessen des Auktionshauses)
function ns.ShowButton()
    local mod = ns.mod
    if not mod.db.offerButton then return end
    local anchor = rawget(_G, "PeonBrokerScanButton")
    if not anchor then return end
    local b = ns.button
    if not b then
        b = CreateFrame("Button", "PeonBridgeSendButton", anchor, "UIPanelButtonTemplate")
        b:SetSize(130, 22)
        -- ab 0.9.1: Brokers Scan-Knopf sitzt ab Broker 0.59.1 in der Titelleiste des Auktionshauses, darunter laege
        -- der Knopf ueber Blizzards Suchleiste. Darum oben rechts ueber dem Fenster, ohne Auktionshaus wie bisher.
        local ah = rawget(_G, "AuctionHouseFrame")
        if type(ah) == "table" and ah.GetObjectType then
            b:SetPoint("BOTTOMRIGHT", ah, "TOPRIGHT", -2, 2)
        else
            b:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
        end
        b:SetText(L.BTN_SEND)
        b:SetScript("OnClick", function() ns.Send() end)
        b:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(("|c%sPeon|r %s"):format(Peon.COLOR, L.BTN_SEND_TIP))
            GameTooltip:AddLine(L.BTN_SEND_TIP2, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        ns.button = b
        mod:RegisterEvent("AUCTION_HOUSE_CLOSED", function() if ns.button then ns.button:Hide() end end)
    end
    b:Show()
end
