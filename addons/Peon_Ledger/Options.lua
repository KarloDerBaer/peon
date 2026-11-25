-- Peon_Ledger - Options.lua
-- Optionsseite unter Einstellungen > AddOns > Peon > Ledger.
-- Stand 0.2: Anzeige (Minimap-Button, Tooltip, Fenster), Charaktere (Liste, loeschen), Pruefung.
-- Ab 0.3.2: Buch zuruecksetzen (Verlauf loeschen, aktueller Stand = neuer Anfangsbestand).
-- Ab 0.18 drei Reiter nach dem Leitfaden: Allgemein (Fenster, Minimap, Tooltip, Postfenster), Anzeige (Bausteine im
-- Tooltip), Erweitert (Charaktere loeschen, Kosten, Inventur, Buch, Kontrollrechnung). Die Pruefung laeuft ueber
-- /ledger pruefen.

local ADDON_NAME, ns = ...
local L = ns.L

-- Nur einen Eintrag hinzufuegen, die Tabelle nie neu zuweisen (sonst Taint, siehe Peon_Ueberblick.md)
StaticPopupDialogs["PEON_LEDGER_DELETE_CHAR"] = {
    text = L.CONFIRM_DELETE_CHAR,
    button1 = YES, button2 = NO,
    OnAccept = function(_, data) ns.DeleteChar(data) end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

StaticPopupDialogs["PEON_LEDGER_RECOUNT"] = {
    text = L.CONFIRM_RECOUNT,
    button1 = YES, button2 = NO,
    OnAccept = function() ns.Recount() end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

function ns.Recount()
    local ok, n = pcall(ns.Moves.Recount)
    if ok then ns.mod:Print(L.MSG_RECOUNT:format(ns.CharName(), n or 0)) else ns.mod:ReportError("Inventur", n) end
    if ns.mod.page then ns.mod.page:Refresh() end
end

StaticPopupDialogs["PEON_LEDGER_RESET_BOOK"] = {
    text = L.CONFIRM_RESET_BOOK,
    button1 = YES, button2 = NO,
    OnAccept = function() ns.ResetBook() end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

function ns.ResetBook()
    ns.mod:Call("Bewegungen", ns.Moves.ResetBook)
    ns.mod:Print(L.MSG_BOOK_RESET:format(ns.Realm()))
    if ns.mod.page then ns.mod.page:Refresh() end
end

function ns.DeleteChar(name)
    if type(name) ~= "string" then return end
    ns.Inventory.DeleteChar(name)
    ns.mod:Print(L.MSG_CHAR_DELETED:format(name))
    if ns.mod.page then ns.mod.page:Refresh() end
end

function ns.CreateOptions()
    local mod = ns.mod
    if mod.page then return end
    local page = mod:NewOptionsPage({ desc = L.DESC, tipHints = true })   -- Hinweise als Tooltip (Kern-API 29)
    -- ab 0.18 nach dem Leitfaden (docs/konzepte/Peon_Einstellungen_Leitfaden.md): drei Reiter, ohne Block Pruefung
    -- (/ledger pruefen bleibt)
    page:Tabs({ { "general", L.OPT_TAB_GENERAL }, { "show", L.OPT_TAB_SHOW }, { "advanced", L.OPT_TAB_ADVANCED } }, -62)

    -- Allgemein
    local general = page:Column(16, -100, "general")
    page:Add(general, page:Button(L.BTN_WINDOW, function() ns.Window.Toggle() end, L.BTN_WINDOW_HINT), 12)
    page:Add(general, page:Check("minimapShow", L.OPT_MINIMAP, L.OPT_MINIMAP_HINT), 4)
    page:Add(general, page:Check("tooltipShow", L.OPT_TOOLTIP, L.OPT_TOOLTIP_HINT), 4)
    page:Add(general, page:Check("mailWindow", L.OPT_MAIL, L.OPT_MAIL_HINT), 4)

    -- Anzeige: Bausteine im Tooltip (ab 0.14.2, wie bei Broker)
    local show = page:Column(16, -100, "show")
    page:Add(show, page:Header(L.HDR_TOOLTIP), 6)
    ns.Tooltip.BuildOptions(page, show)

    -- Erweitert
    local left = page:Column(16, -100, "advanced")
    page:Add(left, page:Text(function() return L.OPT_ADVANCED_HINT end), 10)
    page:Add(left, page:Header(L.HDR_CHARS), 6)
    local chars = page:Add(left, page:List({
        columns = {
            { key = "name", title = L.COL_CHAR, width = 220 },
            { key = "money", title = L.COL_GOLD, width = 120, align = "RIGHT", format = function(v) return v and ns.Money(v, true) or "–" end },
            { key = "seen", title = L.COL_SEEN, width = 100, align = "RIGHT", format = function(v) return ns.Age(v) end },
        },
        rows = 5, sortKey = "name",
    }), 6)
    chars.Refresh = function()
        local items = {}
        for name, c in pairs(ns.Inventory.RealmData().chars) do
            items[#items + 1] = { name = name, money = c.money, seen = c.seen }
        end
        chars.list:SetData(items)
    end
    page:Add(left, page:Button(L.BTN_DELETE_CHAR, function()
        local sel = chars.list:GetSelected()
        if not sel then mod:Print(L.MSG_SELECT_CHAR); return end
        if sel.name == ns.CharName() then mod:Print(L.MSG_NOT_SELF); return end
        if StaticPopup_Show then StaticPopup_Show("PEON_LEDGER_DELETE_CHAR", sel.name, nil, sel.name) else ns.DeleteChar(sel.name) end
    end, L.BTN_DELETE_CHAR_HINT), 16)

    -- Buch
    page:Add(left, page:Header(L.HDR_BOOK), 6)
    page:Add(left, page:Dropdown("costOrder", L.OPT_COST_ORDER, { { "lifo", L.COST_LIFO }, { "fifo", L.COST_FIFO } }, L.OPT_COST_ORDER_HINT), 8)
    page:Add(left, page:Button(L.BTN_COST_RECALC, function()
        ns.Cost.Invalidate()
        local ok = pcall(ns.Cost.State)
        mod:Print(ok and L.MSG_COST_RECALC:format(ns.Money(math.floor(ns.Cost.TotalValue() + 0.5))) or "?")
    end, L.BTN_COST_RECALC_HINT), 4)
    page:Add(left, page:Button(L.BTN_RECOUNT, function()
        if StaticPopup_Show then StaticPopup_Show("PEON_LEDGER_RECOUNT", ns.CharName()) else ns.Recount() end
    end, L.BTN_RECOUNT_HINT), 4)
    page:Add(left, page:Button(L.BTN_RESET_BOOK, function()
        if StaticPopup_Show then StaticPopup_Show("PEON_LEDGER_RESET_BOOK", ns.Realm()) else ns.ResetBook() end
    end, L.BTN_RESET_BOOK_HINT), 4)
    page:Add(left, page:Button(L.BTN_CHECK, function()
        local n = ns.Check.Run().n
        mod:Print(n == 0 and L.CHECK_OK or ns.Plural(n, "CHECK_OPEN"))
    end, L.BTN_CHECK_HINT), 4)
    page:Add(left, page:Text(function() return L.BOOK_INFO:format(#ns.Moves.List()) end), 16)

    page:AddResetButton(L.SLASH_HINT, general, show, left)
    page:Register()
end
