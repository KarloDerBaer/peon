-- Peon_Mover - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Mover: Sperre und Fensterliste.

local ADDON_NAME, ns = ...
local L = ns.L

-- nur einen Eintrag hinzufuegen, die Tabelle nie neu zuweisen (Taint, siehe Broker 0.4.1)
StaticPopupDialogs["PEON_MOVER_RESET_ALL"] = {
    text = L.CONFIRM_RESET_ALL,
    button1 = YES, button2 = NO,
    OnAccept = function()
        ns.ResetAll()
        ns.mod:Print(L.MSG_RESET_ALL)
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

-- Eintraege der Fensterliste: gefundene Fenster und gespeicherte, die noch nicht geladen sind
function ns.ListItems()
    local items, seen = {}, {}
    local frames = ns.mod.db and ns.mod.db.frames or {}
    local function Add(name, w)
        if seen[name] then return end
        seen[name] = true
        local s = frames[name]
        local state
        if s and s.off then
            state = L.STATE_OFF
        else
            local parts = {}
            if s and s.x then parts[#parts + 1] = L.STATE_MOVED end
            if s and s.s then parts[#parts + 1] = L.STATE_SCALE:format(math.floor(s.s * 100 + 0.5)) end
            state = #parts > 0 and table.concat(parts, ", ") or L.STATE_DEFAULT
        end
        items[#items + 1] = {
            name = name, title = ns.DisplayName(name), state = state,
            on = not (s and s.off), loaded = w ~= nil, auto = w and w.auto or false,
        }
    end
    for name, w in pairs(ns.win) do Add(name, w) end
    for name in pairs(frames) do Add(name, nil) end
    return items
end

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC, colW = 560 })

    local left = page:Column(16, -86)
    page:Add(left, page:Header(L.HDR_MAIN), 6)
    page:Add(left, page:Check("enabled", L.ENABLED, L.ENABLED_HINT), 14)
    page:Add(left, page:Header(L.HDR_LIST), 6)
    page:Add(left, page:Text(function() return L.LIST_HINT end), 6)

    local box = page:List({
        columns = {
            { key = "title", title = L.COL_NAME, width = 260,
              format = function(v, item) return item.loaded and v or ("|cff888888" .. v .. "|r") end },
            { key = "state", title = L.COL_STATE, width = 190 },
            { key = "on", title = L.COL_ON, width = 50,
              format = function(v) return v and L.YES or ("|cffff6060" .. L.NO .. "|r") end,
              sortValue = function(item) return item.on and 1 or 0 end },
        },
        rows = 12, sortKey = "title", selectable = true, emptyText = L.LIST_EMPTY,
        onClick = function(list, item, button)
            if button == "RightButton" and item then ns.Toggle(item.name) end
            ns.UpdateButtons()
        end,
        onEnter = function(list, item, row)
            if not item or not GameTooltip then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:AddLine(item.title)
            GameTooltip:AddLine(item.name, 0.6, 0.6, 0.6)
            GameTooltip:AddLine(item.auto and L.TIP_SOURCE_AUTO or L.TIP_SOURCE_LIST, 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
    })
    page:Add(left, box, 8)
    local list = box.list
    ns.list = list

    -- Knopfreihe unter der Liste
    local row = page:NewContainer(26)
    local function Btn(text, x, w, fn)
        local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        b:SetSize(w, 24)
        b:SetPoint("TOPLEFT", x, 0)
        b:SetText(text)
        b:SetScript("OnClick", function() mod:Call("Knopf", fn) end)
        return b
    end
    local bToggle = Btn(L.BTN_TOGGLE, 0, 120, function()
        local item = list:GetSelected()
        if item then ns.Toggle(item.name) end
    end)
    local bReset = Btn(L.BTN_RESET, 126, 120, function()
        local item = list:GetSelected()
        if item then ns.Reset(item.name) end
    end)
    Btn(L.BTN_RESET_ALL, 300, 200, function()
        if StaticPopup_Show then StaticPopup_Show("PEON_MOVER_RESET_ALL") else ns.ResetAll() end
    end)
    page:Add(left, row, 14)

    function ns.UpdateButtons()
        local item = list:GetSelected()
        if item then bToggle:Enable(); bReset:Enable() else bToggle:Disable(); bReset:Disable() end
    end

    -- Liste neu fuellen; die Auswahl bleibt beim selben Fenster
    function ns.RefreshList()
        local sel = list:GetSelected()
        local items = ns.ListItems()
        list:SetData(items)
        list:Refresh()
        if sel then
            for _, it in ipairs(items) do if it.name == sel.name then list:Select(it) end end
        end
        ns.UpdateButtons()
    end
    box.Refresh = ns.RefreshList

    page:AddResetButton(L.SLASH_HINT, left)
    page:Register()
end
