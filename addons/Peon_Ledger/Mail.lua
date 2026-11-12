-- Peon_Ledger - Mail.lua
-- Eigenes Postfenster "Peon Post" (ab 0.14, Konzept Peon_Ledger_Neuaufbau.md Abschnitt 5, Bauabschnitte E5 und E7).
-- Am Briefkasten erscheint statt Blizzards Postfach ein Fenster mit Peon.UI. Blizzards Postfach bleibt offen, aber
-- unsichtbar in einem winzigen Rahmen (wie Peon_Bags mit der Bank): Versteckt man es, schliesst das Spiel den
-- Briefkasten (MailMixin:OnHide ruft CloseMail, nachgelesen im Zweig forever).
--   Eingang: links Summen (Briefe, Verkaeufe mit Gewinn, Kaeufe, Zurueck, bald ablaufend) und zwei Knoepfe
--            "Auktionshaus-Post einsammeln" und "Alles einsammeln" (nie Nachnahme, Brief fuer Brief wie Blizzards
--            "Alle oeffnen": 0,15 Sek. Abstand und C_Mail.IsCommandPending). Rechts die Briefe. Klick nimmt einen Brief.
--   Senden:  eigene Seite mit Empfaenger (Liste der Twinks), Betreff, Text, Gold oder Nachnahme, zwoelf Anhaenge
--            (aus der Tasche ziehen oder Rechtsklick in der Tasche: SetSendMailShowing(true) wie Blizzards Seite).
-- Ledger erfasst alles wie bisher ueber die mitgelesenen Aufrufe (TakeInboxMoney, TakeInboxItem, AutoLootMailItem,
-- SendMail). Eine Einstellung (mailWindow) schaltet zurueck auf Blizzards Postfach, der Knopf "Blizzard" fuer einen Besuch.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local MA = {}
ns.Mail = MA

MA.DELAY = 0.15        -- wie OPEN_ALL_MAIL_MIN_DELAY in Blizzards MailFrame.lua
MA.MAX_TRIES = 3       -- so oft wird ein Brief versucht, danach uebersprungen
MA.SOON_DAYS = 3       -- "laeuft bald ab"
MA.SLOTS = 12          -- Anhaenge beim Senden (ATTACHMENTS_MAX_SEND)
MA.RECENT_MAX = 10

local GREY, GREEN, RED, YELLOW = W.GREY, W.GREEN, W.RED, W.YELLOW
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function G(name) return rawget(_G, name) end

---------------------------------------------------------------------------
-- Blizzards Postfach unsichtbar machen, ohne es zu schliessen
---------------------------------------------------------------------------
local tiny
function MA.Tiny()
    if not tiny then
        tiny = CreateFrame("Frame", nil, UIParent)
        tiny:SetSize(1, 1)
        tiny:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        tiny:SetScale(0.001)
        tiny:SetAlpha(0)
        tiny:EnableMouse(false)
    end
    return tiny
end

function MA.Tuck()
    local f = G("MailFrame")
    if not f or f:GetParent() == MA.Tiny() then return end
    f.peonParent = f:GetParent()
    f:SetParent(MA.Tiny())
end

-- Texte neu messen lassen (im winzigen Rahmen misst das Spiel sie riesig, Erfahrung aus Peon_Bags 0.6.1)
local function Remeasure(frame, depth)
    if depth > 8 or not frame.GetRegions then return end
    for _, r in ipairs({ frame:GetRegions() }) do
        if type(r) == "table" and r.GetObjectType and r:GetObjectType() == "FontString" then
            local t = r:GetText()
            if type(t) == "string" and not Peon.IsSecret(t) and t ~= "" then r:SetText(""); r:SetText(t) end
        end
    end
    for _, c in ipairs({ frame:GetChildren() }) do
        if type(c) == "table" then Remeasure(c, depth + 1) end
    end
end

function MA.Untuck()
    local f = G("MailFrame")
    if not f or f:GetParent() ~= MA.Tiny() then return end
    f:SetParent(f.peonParent or UIParent)
    pcall(Remeasure, f, 0)
end

---------------------------------------------------------------------------
-- Briefe
---------------------------------------------------------------------------
-- Art eines Briefes fuer die Anzeige: sale, buy, return, outbid, twink, player, system
function MA.Kind(l)
    local k = ns.Moves.LetterKind(l)
    if k == "sold" then return "sale" end
    if k == "won" then return "buy" end
    if k == "return" then return "return" end
    if k == "outbid" then return "outbid" end
    if l.ah then return "system" end
    local own = ns.Moves.OwnChar(l.sender)
    if own and own ~= ns.CharName() then return "twink" end
    if type(l.sender) == "string" and l.sender:find(" ", 1, true) then return "player" end
    return "system"
end

MA.FILTER = { all = true, sale = { sale = true }, buy = { buy = true, outbid = true }, ["return"] = { ["return"] = true },
              other = { twink = true, player = true, system = true } }

-- Erste Anhaenge eines Briefes: Liste { id, n, name }
local function Attachments(i)
    local fn = G("GetInboxItem")
    local out = {}
    if type(fn) ~= "function" then return out end
    for a = 1, (tonumber(G("ATTACHMENTS_MAX_RECEIVE")) or 16) do
        local ok, name, id, _, n = pcall(fn, i, a)
        if ok and Num(id) then out[#out + 1] = { id = id, n = Num(n) and n or 1, name = name, slot = a } end
    end
    return out
end

function MA.Rows()
    local rows = {}
    for i, l in ipairs(ns.Inventory.letters or {}) do
        local kind = MA.Kind(l)
        local r = { index = i, letter = l, kind = kind, label = L["MAIL_K_" .. kind:upper()] or kind,
            money = (l.money or 0) > 0 and l.money or nil, cod = l.cod, days = l.days, sender = l.sender, subject = l.subject }
        -- Inhalt: Anhaenge, sonst Rechnung (verkaufter Gegenstand x Menge), sonst Betreff
        local inv = l.invoice
        local att = Attachments(i)
        local id, n
        if att[1] then
            id, n = att[1].id, att[1].n
            local name = att[1].name or (ns.Inventory.ItemInfo(id)) or ("#" .. id)
            r.content = name .. (n > 1 and (" ×" .. n) or "") .. (#att > 1 and (GREY .. "  " .. L.MAIL_MORE:format(#att - 1) .. "|r") or "")
        elseif inv and inv.item then
            id = ns.Inventory.FindItemID(inv.item)
            n = inv.count or 1
            r.content = inv.item .. (n > 1 and (" ×" .. n) or "")
        else
            r.content = l.subject or ""
        end
        r.id, r.n = id, n
        if id then
            local _, q, icon = ns.Inventory.ItemInfo(id)
            r.quality, r.icon = q, icon
        else
            r.icon = l.icon
        end
        -- ab 0.14.2: Auktion von vor dem Neustart des Buchs -> Sondereinnahme, kein Gewinn
        if kind == "sale" and ns.Moves.PreSale(nil, id, inv and inv.item, n, false) then
            r.special = true
            r.label = L.MAIL_K_SPECIAL
        -- Gewinn eines Verkaufs (ungefaehr): Erloes - Kosten der Stuecke laut Ledger (naechstes Stueck)
        elseif kind == "sale" and id and r.money then
            local info = ns.Cost and ns.Cost.Info(id)
            r.profit = r.money - (n or 1) * ((info and info.next) or 0)
            r.profitEst = info == nil
        end
        rows[#rows + 1] = r
    end
    return rows
end

function MA.Summary(rows)
    local s = { letters = #rows, money = 0, sale = 0, saleMoney = 0, profit = 0, buy = 0, ["return"] = 0, soon = 0, cod = 0,
                ah = 0, ahMoney = 0, other = 0 }
    for _, r in ipairs(rows) do
        s.money = s.money + (r.money or 0)
        if r.kind == "sale" then s.sale = s.sale + 1; s.saleMoney = s.saleMoney + (r.money or 0); s.profit = s.profit + (r.profit or 0) end
        if r.kind == "buy" then s.buy = s.buy + 1 end
        if r.kind == "return" then s["return"] = s["return"] + 1 end
        if r.days and r.days < MA.SOON_DAYS then s.soon = s.soon + 1 end
        if r.cod then s.cod = s.cod + 1 end
        if r.letter.ah and not r.cod then s.ah = s.ah + 1; s.ahMoney = s.ahMoney + (r.money or 0) end
        if not r.letter.ah then s.other = s.other + 1 end
    end
    return s
end

---------------------------------------------------------------------------
-- Nehmen und Einsammeln
---------------------------------------------------------------------------
function MA.FreeSlots()
    local Ct = G("C_Container")
    if Ct and type(Ct.CalculateTotalNumberOfFreeBagSlots) == "function" then
        local ok, n = pcall(Ct.CalculateTotalNumberOfFreeBagSlots)
        if ok and Num(n) then return n end
    end
    local free = 0
    if Ct and Ct.GetContainerNumFreeSlots then
        for _, b in ipairs(ns.Inventory.BagIDs()) do
            local ok, n = pcall(Ct.GetContainerNumFreeSlots, b)
            if ok and Num(n) then free = free + n end
        end
    end
    return free
end

local function Pending()
    local CM = G("C_Mail")
    if CM and type(CM.IsCommandPending) == "function" then
        local ok, p = pcall(CM.IsCommandPending)
        return ok and p and true or false
    end
    return false
end

local function After(sec, fn)
    local CT = G("C_Timer")
    if CT and CT.After then CT.After(sec, function() mod:Call("Post", fn) end) else fn() end
end

-- Einen Brief nehmen (Klick auf die Zeile). Nachnahme nur nach Rueckfrage.
function MA.Take(r)
    if not r or not ns.Inventory.open.mail then return end
    local i = r.index
    if r.cod then
        local att = Attachments(i)
        Peon.UI.Confirm(L.MAIL_COD_CONFIRM:format(ns.Money(r.cod)), L.MAIL_COD_YES, nil, function()
            if att[1] and type(G("TakeInboxItem")) == "function" then TakeInboxItem(i, att[1].slot) end
        end)
        return
    end
    if type(G("AutoLootMailItem")) == "function" and (r.letter.count or 0) > 0 then
        AutoLootMailItem(i)
    elseif (r.money or 0) > 0 and type(G("TakeInboxMoney")) == "function" then
        TakeInboxMoney(i)
    end
end

-- naechster Brief fuer das Einsammeln: Index, Kopf
function MA.NextLetter(run)
    local numFn, header = G("GetInboxNumItems"), G("GetInboxHeaderInfo")
    if type(numFn) ~= "function" or type(header) ~= "function" then return nil end
    local ok, n = pcall(numFn)
    if not ok or not Num(n) then return nil end
    local free = MA.FreeSlots()
    local invoiceFn = G("GetInboxInvoiceInfo")
    for i = 1, n do
        local okh, _, _, sender, subject, money, cod, _, count = pcall(header, i)
        if okh then
            local key = tostring(sender) .. "|" .. tostring(subject) .. "|" .. tostring(money) .. "|" .. tostring(count)
            local isAH = ns.Inventory.IsAHSender(sender)
            if not isAH and type(invoiceFn) == "function" then
                local oki, kind = pcall(invoiceFn, i)
                isAH = oki and type(kind) == "string" and not Peon.IsSecret(kind)
            end
            local wanted = (run.mode == "all" or isAH) and not (Num(cod) and cod > 0)
            local hasMoney = Num(money) and money > 0
            local hasItems = Num(count) and count > 0 and free > 0
            if wanted and (hasMoney or hasItems) and (run.tries[key] or 0) < MA.MAX_TRIES then
                return i, { key = key, money = hasMoney, items = hasItems }
            end
        end
    end
    return nil
end

function MA.Collect(mode)
    if MA.run then MA.Stop(); return end
    if not ns.Inventory.open.mail then return end
    MA.run = { mode = mode, tries = {}, done = 0 }
    MA.UpdateButtons()
    MA.Step()
end

function MA.Stop(reason)
    local run = MA.run
    MA.run = nil
    if run and reason then mod:Print(reason:format(run.done)) end
    MA.UpdateButtons()
end

function MA.Step()
    local run = MA.run
    if not run then return end
    if not ns.Inventory.open.mail then MA.Stop(); return end
    if Peon.InCombat and Peon.InCombat() then MA.Stop(L.MAIL_STOP_COMBAT); return end
    if Pending() then After(MA.DELAY, MA.Step); return end
    local i, h = MA.NextLetter(run)
    if not i then
        local full = MA.FreeSlots() == 0
        MA.Stop(full and L.MAIL_STOP_FULL or L.MAIL_STOP_DONE)
        return
    end
    run.tries[h.key] = (run.tries[h.key] or 0) + 1
    if h.money then
        TakeInboxMoney(i)
    else
        local att = Attachments(i)
        if not att[1] then After(MA.DELAY, MA.Step); return end   -- Anhang noch nicht lesbar: gleich noch einmal
        TakeInboxItem(i, att[1].slot)
    end
    run.done = run.done + 1
    MA.UpdateButtons()
    After(MA.DELAY, MA.Step)
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
function MA.Create()
    if MA.win then return MA.win end
    local U = Peon.UI
    local f = U.Window("PeonLedgerMailFrame", { title = L.MAIL_TITLE, icon = "Interface\\Icons\\INV_Letter_15" })
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    f:SetScript("OnHide", function() MA.OnWindowHide() end)
    MA.win = f
    MA.tabs = U.BottomTabs(f, { { "inbox", L.MAIL_TAB_INBOX }, { "send", L.MAIL_TAB_SEND } }, function(key) MA.SelectTab(key) end)
    MA.status = U.StatusBar(f)
    MA.blizz = U.Button(f, L.MAIL_BLIZZARD, 90, function() MA.ShowBlizzard() end)
    MA.blizz:SetPoint("TOPRIGHT", -30, -30)
    U.SetTooltip(MA.blizz, { L.MAIL_BLIZZARD, L.MAIL_BLIZZARD_TIP })
    MA.pages = {}
    MA.BuildInbox()
    MA.BuildSend()
    MA.tabs:Select("inbox")
    return f
end

function MA.SelectTab(key)
    MA.CloseReader()
    MA.tab = key
    for k, p in pairs(MA.pages or {}) do p:SetShown(k == key) end
    -- Rechtsklick in der Tasche haengt an, solange die Seite Senden offen ist (wie Blizzards Seite)
    local fn = G("SetSendMailShowing")
    if type(fn) == "function" then pcall(fn, key == "send") end
    MA.Refresh()
end

function MA.BuildInbox()
    local U = Peon.UI
    local a = W.Area()
    local c = CreateFrame("Frame", nil, MA.win)
    c:SetAllPoints()
    MA.pages.inbox = c
    local lw = 260
    local left = U.Panel(c, "left")
    left:SetPoint("TOPLEFT", a.left, -a.top)
    left:SetPoint("BOTTOMLEFT", a.left, a.bottom)
    left:SetWidth(lw)
    local head = left:CreateFontString(nil, "ARTWORK", U.FONT.heading)
    head:SetPoint("TOPLEFT", 14, -12)
    head:SetText(L.MAIL_HEAD)
    MA.lines = {}
    local keys = { "letters", "sale", "profit", "buy", "return", "soon", "cod" }
    local y = -38
    for _, k in ipairs(keys) do
        MA.lines[k] = W.ValueLine(left, y)
        y = y - 22
    end
    MA.filter = U.Dropdown(left, lw - 28, {
        { "all", L.MAIL_F_ALL }, { "sale", L.MAIL_F_SALE }, { "buy", L.MAIL_F_BUY }, { "return", L.MAIL_F_RETURN }, { "other", L.MAIL_F_OTHER },
    }, function() return mod.db.mailFilter or "all" end, function(v) mod.db.mailFilter = v; MA.Refresh() end)
    MA.filter:SetPoint("TOPLEFT", 14, y - 8)
    MA.btnAH = U.Button(left, "", lw - 28, function() MA.Collect("ah") end, "gold")
    MA.btnAH:SetPoint("BOTTOMLEFT", 14, 44)
    MA.btnAll = U.Button(left, "", lw - 28, function() MA.Collect("all") end)
    MA.btnAll:SetPoint("BOTTOMLEFT", 14, 14)
    U.SetTooltip(MA.btnAll, { L.MAIL_ALL, L.MAIL_ALL_TIP })
    U.SetTooltip(MA.btnAH, { L.MAIL_AH, L.MAIL_AH_TIP })
    local panel = U.Panel(c, "list", true)
    panel:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 0)
    panel:SetPoint("BOTTOMRIGHT", -a.right, a.bottom)
    MA.listPanel = panel
    MA.table = U.Table(panel, {
        icon = true,
        columns = {
            { key = "content", title = L.MAIL_COL_CONTENT, format = function(v, r) return r.id and W.Colored(v, r.quality) or v end },
            { key = "label", title = L.COL_KIND, width = 90, format = function(v, r) return (r.kind == "sale" and GREEN or (r.kind == "buy" and YELLOW or "")) .. v .. "|r" end },
            { key = "money", title = L.COL_GOLD, width = 100, align = "RIGHT",
              format = function(v, r) if r.cod then return RED .. "-" .. ns.Money(r.cod) .. "|r" end return v and ns.Money(v) or (GREY .. "–|r") end },
            { key = "profit", title = L.MAIL_COL_PROFIT, width = 90, align = "RIGHT", format = function(v, r) return v and ((r.profitEst and "≈" or "") .. W.Signed(v)) or "" end },
            { key = "days", title = L.MAIL_COL_EXP, width = 64, align = "RIGHT", format = function(v) return v and MA.DaysText(v) or "" end },
        },
        sortKey = "days",
        empty = L.MAIL_EMPTY,
        rowBg = function(r) if r.cod then return 1, 0.2, 0.2, 0.12 end end,
        onEnter = function(row, r) MA.RowTooltip(row, r) end,
        onClick = function(r, button)
            -- ab 0.14.1: Brief ohne Gold und Anhang wird gelesen, Rechtsklick liest jeden Brief
            if button == "RightButton" or MA.TextOnly(r) then MA.Read(r) elseif button == "LeftButton" then MA.Take(r) end
        end,
    })
    MA.BuildReader(c, panel)
end

-- Brief ohne Gold und ohne Anhang (nur Text)
function MA.TextOnly(r) return not r.cod and (r.money or 0) == 0 and (r.letter.count or 0) == 0 end

-- Lesen (ab 0.14.1): Betreff, Absender, Text. Antworten, Loeschen (leere Briefe) bzw. Zurueckschicken.
function MA.BuildReader(c, panel)
    local U = Peon.UI
    local f = U.Panel(c, "list")
    f:SetAllPoints(panel)
    f:SetFrameLevel((panel:GetFrameLevel() or 1) + 20)
    f:EnableMouse(true)
    f:Hide()
    f.subject = U.Text(f, "heading", "", 460)
    f.subject:SetPoint("TOPLEFT", 16, -14)
    f.from = U.Text(f, "sub", "", 460)
    f.from:SetPoint("TOPLEFT", f.subject, "BOTTOMLEFT", 0, -4)
    f.body = U.Text(f, "text", "", 460)
    f.body:SetPoint("TOPLEFT", f.from, "BOTTOMLEFT", 0, -14)
    f.back = U.Button(f, L.MAIL_READ_BACK, 100, function() MA.CloseReader() end)
    f.back:SetPoint("BOTTOMLEFT", 14, 12)
    f.reply = U.Button(f, L.MAIL_READ_REPLY, 110, function() MA.Reply() end)
    f.reply:SetPoint("LEFT", f.back, "RIGHT", 8, 0)
    f.del = U.Button(f, L.MAIL_READ_DELETE, 120, function() MA.DeleteOrReturn() end)
    f.del:SetPoint("BOTTOMRIGHT", -14, 12)
    MA.reader = f
end

function MA.Read(r)
    if not r or not MA.reader then return end
    local f = MA.reader
    local body
    local fn = G("GetInboxText")
    if type(fn) == "function" then
        local ok, text = pcall(fn, r.index)
        if ok and type(text) == "string" and not Peon.IsSecret(text) then body = text end
    end
    MA.reading = r
    f.subject:SetText(r.subject or r.content or "")
    f.from:SetText(r.sender and (L.MAIL_TT_FROM .. ": " .. r.sender) or "")
    f.body:SetText((body and body ~= "") and body or (GREY .. L.MAIL_READ_EMPTY .. "|r"))
    local canDelete = false
    local cd = G("InboxItemCanDelete")
    if type(cd) == "function" then local ok, v = pcall(cd, r.index); canDelete = ok and v and true or false end
    f.canDelete = canDelete
    f.del:SetText(canDelete and L.MAIL_READ_DELETE or L.MAIL_READ_RETURN)
    if MA.TextOnly(r) then f.del:Enable() else f.del:SetShown(canDelete or (r.kind == "player")) end
    f.reply:SetShown(r.kind == "player" or r.kind == "twink")
    f:Show()
end

function MA.CloseReader()
    MA.reading = nil
    if MA.reader then MA.reader:Hide() end
end

function MA.Reply()
    local r = MA.reading
    if not r or not r.sender then return end
    MA.CloseReader()
    MA.tabs:Select("send")
    MA.send.to:SetText(r.sender:match("^(%S+)") or r.sender)
    local subj = r.subject or ""
    MA.send.subject:SetText(subj ~= "" and L.MAIL_READ_RE:format(subj) or "")
    MA.RefreshSend()
end

function MA.DeleteOrReturn()
    local r = MA.reading
    if not r then return end
    local f = MA.reader
    local i = r.index
    if f.canDelete then
        Peon.UI.Confirm(L.MAIL_READ_DELETE_Q, L.MAIL_READ_DELETE, nil, function()
            local fn = G("DeleteInboxItem")
            if type(fn) == "function" then pcall(fn, i) end
            MA.CloseReader()
        end)
    else
        local fn = G("ReturnInboxItem")
        if type(fn) == "function" then pcall(fn, i) end
        MA.CloseReader()
    end
end

function MA.DaysText(d)
    local txt = d >= 1 and L.AGE_DAYS:format(math.floor(d)) or L.AGE_HOURS:format(math.max(0, math.floor(d * 24)))
    if d < 1 then return RED .. txt .. "|r" end
    if d < MA.SOON_DAYS then return YELLOW .. txt .. "|r" end
    return txt
end

function MA.RowTooltip(row, r)
    if not GameTooltip then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(r.subject or r.content or "", 1, 0.82, 0, true)
    if r.sender then GameTooltip:AddDoubleLine(L.MAIL_TT_FROM, r.sender, 0.8, 0.8, 0.8, 1, 1, 1) end
    local inv = r.letter.invoice
    if inv and inv.kind == "seller" then
        if inv.gross then
            local q = inv.count or 1
            local each = q > 1 and ("  " .. GREY .. L.MAIL_TT_EACH:format(ns.Money(math.floor(inv.gross / q + 0.5))) .. "|r") or ""
            GameTooltip:AddDoubleLine(L.MAIL_TT_GROSS, ns.Money(inv.gross) .. each, 0.8, 0.8, 0.8, 1, 1, 1)
        end
        if inv.cut then GameTooltip:AddDoubleLine(L.MAIL_TT_CUT, "-" .. ns.Money(inv.cut), 0.8, 0.8, 0.8, 1, 1, 1) end
        if inv.deposit and inv.deposit > 0 then GameTooltip:AddDoubleLine(L.MAIL_TT_DEPOSIT, "+" .. ns.Money(inv.deposit), 0.8, 0.8, 0.8, 1, 1, 1) end
    elseif inv and inv.kind == "buyer" and math.max(inv.bid or 0, inv.buyout or 0) > 0 then
        GameTooltip:AddDoubleLine(L.MAIL_TT_PAID, ns.Money(math.max(inv.bid or 0, inv.buyout or 0)), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    if r.money then GameTooltip:AddDoubleLine(L.MAIL_TT_MONEY, ns.Money(r.money), 0.8, 0.8, 0.8, 1, 1, 1) end
    if r.profit then
        local info = r.id and ns.Cost and ns.Cost.Info(r.id)
        GameTooltip:AddDoubleLine(L.MAIL_TT_COST, ns.Money(math.floor((r.n or 1) * ((info and info.next) or 0) + 0.5)), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.MAIL_TT_PROFIT, W.Signed(r.profit), 1, 0.82, 0, 1, 1, 1)
    end
    if r.special then GameTooltip:AddLine(L.MAIL_TT_SPECIAL, 1, 0.82, 0, true) end
    if r.cod then GameTooltip:AddLine(L.MAIL_TT_COD:format(ns.Money(r.cod)), 1, 0.3, 0.3, true) end
    if r.letter.loading then GameTooltip:AddLine(L.MAIL_TT_LOADING, 0.6, 0.6, 0.6, true) end
    if MA.TextOnly(r) then
        GameTooltip:AddLine(L.MAIL_TT_CLICK_READ, 0.6, 0.6, 0.6, true)
    else
        GameTooltip:AddLine(r.cod and L.MAIL_TT_CLICK_COD or L.MAIL_TT_CLICK, 0.6, 0.6, 0.6, true)
        GameTooltip:AddLine(L.MAIL_TT_RIGHT_READ, 0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
end

function MA.UpdateButtons()
    if not MA.btnAH then return end
    local s = MA.sum or { ah = 0, ahMoney = 0, letters = 0 }
    local run = MA.run
    if run then
        local txt = L.MAIL_RUNNING:format(run.done)
        MA.btnAH:SetText(run.mode == "ah" and txt or L.MAIL_AH_SHORT)
        MA.btnAll:SetText(run.mode == "all" and txt or L.MAIL_ALL)
    else
        MA.btnAH:SetText(s.ahMoney > 0 and L.MAIL_AH_BTN:format(ns.Money(s.ahMoney, true)) or L.MAIL_AH_SHORT)
        MA.btnAll:SetText(L.MAIL_ALL)
    end
    local function En(b, on) if on then b:Enable() else b:Disable() end end
    En(MA.btnAH, (run and run.mode == "ah") or (not run and s.ah > 0))
    En(MA.btnAll, (run and run.mode == "all") or (not run and s.letters > 0))
end

function MA.Refresh()
    if not MA.win or not MA.win:IsShown() then return end
    if MA.tab == "send" then MA.RefreshSend() else MA.RefreshInbox() end
end

function MA.RefreshInbox()
    if not MA.table then return end
    local rows = MA.Rows()
    local s = MA.Summary(rows)
    MA.sum = s
    local f = MA.FILTER[mod.db.mailFilter or "all"]
    local shown = {}
    for _, r in ipairs(rows) do if f == true or (f and f[r.kind]) then shown[#shown + 1] = r end end
    MA.table:SetData(shown)
    local ln = MA.lines
    ln.letters:Set(ns.Plural(s.letters, "MAIL_L_LETTERS"), ns.Money(s.money))
    ln.sale:Set(L.MAIL_L_SALE:format(s.sale), ns.Money(s.saleMoney))
    ln.profit:Set(L.MAIL_L_PROFIT, s.sale > 0 and W.Signed(s.profit) or (GREY .. "–|r"))
    ln.buy:Set(L.MAIL_L_BUY, tostring(s.buy))
    ln["return"]:Set(L.MAIL_L_RETURN, tostring(s["return"]))
    ln.soon:Set(L.MAIL_L_SOON, s.soon > 0 and (YELLOW .. s.soon .. "|r") or "0")
    ln.cod:Set(L.MAIL_L_COD, s.cod > 0 and (RED .. s.cod .. "|r") or "0")
    MA.UpdateButtons()
    local shownN, total = s.letters, s.letters
    local numFn = G("GetInboxNumItems")
    if type(numFn) == "function" then
        local ok, a, b = pcall(numFn)
        if ok and Num(a) then shownN, total = a, Num(b) and b or a end
    end
    local txt = L.MAIL_FREE:format(MA.FreeSlots())
    if total > shownN then txt = txt .. "   ·   " .. L.MAIL_MORE_THAN:format(shownN, total) end
    MA.statusText = txt
    MA.status:SetText(txt)
    if MA.status.money then MA.status.money:SetAmount(math.max(0, GetMoney())) end
end

---------------------------------------------------------------------------
-- Seite Senden (E7)
---------------------------------------------------------------------------
function MA.Recipients()
    local items, seen = {}, {}
    local me = ns.CharName()
    for _, name in ipairs(ns.Inventory.CharNames()) do
        if name ~= me then
            local first = name:match("^(%S+)") or name
            items[#items + 1] = { first, name .. GREY .. "  " .. L.MAIL_TWINK .. "|r" }
            seen[first:lower()] = true
        end
    end
    for _, n in ipairs(mod.db.mailRecent or {}) do
        if not seen[n:lower()] then items[#items + 1] = { n, n }; seen[n:lower()] = true end
    end
    if #items == 0 then items[1] = { "", L.MAIL_NO_RECIPIENTS } end
    return items
end

function MA.BuildSend()
    local U = Peon.UI
    local a = W.Area()
    local c = CreateFrame("Frame", nil, MA.win)
    c:SetAllPoints()
    MA.pages.send = c
    local left = U.Panel(c, "left")
    left:SetPoint("TOPLEFT", a.left, -a.top)
    left:SetPoint("BOTTOMLEFT", a.left, a.bottom)
    left:SetWidth(U.LEFT_W)
    U.SectionTab(left, L.MAIL_SEND_HEAD)
    local S = {}
    MA.send = S
    S.to = U.Input(left, 150, { instructions = L.MAIL_TO_HINT })
    U.FormRow(left, L.MAIL_TO, S.to, 4, -14)
    S.toDD = U.Dropdown(left, 70, MA.Recipients, function() return S.to:GetText() end,
        function(v) S.to:SetText(v or ""); MA.RefreshSend() end)
    S.toDD:SetPoint("LEFT", S.to, "RIGHT", 4, 0)
    S.to:HookScript("OnTextChanged", function() MA.RefreshSend() end)
    S.subject = U.Input(left, 228, { instructions = L.MAIL_SUBJECT_HINT })
    U.FormRow(left, L.MAIL_SUBJECT, S.subject, 4, -14 - U.FORM_STEP - 14)
    S.body = U.Input(left, 228, { instructions = L.MAIL_BODY_HINT })
    U.FormRow(left, L.MAIL_BODY, S.body, 4, -14 - 2 * (U.FORM_STEP + 14))
    S.money = U.MoneyInput(left, function() MA.RefreshSend() end)
    U.FormRow(left, L.MAIL_MONEY, S.money, 4, -14 - 3 * (U.FORM_STEP + 14))
    S.cod = U.Check(left, L.MAIL_COD, false, function() MA.RefreshSend() end, { L.MAIL_COD, L.MAIL_COD_TIP })
    S.cod:SetPoint("TOPLEFT", U.LABEL_W + 18, -14 - 4 * (U.FORM_STEP + 14) + 4)
    S.cost = U.Text(left, "small", "", U.LEFT_W - 40)
    S.cost:SetPoint("TOPLEFT", 20, -14 - 5 * (U.FORM_STEP + 14) - 4)
    S.sendBtn = U.Button(left, L.MAIL_SEND_BTN, 160, function() MA.Send() end, "gold")
    S.sendBtn:SetPoint("BOTTOM", 0, 14)
    -- rechts die Anhaenge
    local right = U.Panel(c, "right")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 0)
    right:SetPoint("BOTTOMRIGHT", -a.right, a.bottom)
    U.SectionTab(right, L.MAIL_ATTACH_HEAD)
    S.slots = {}
    local size, gap = 46, 8
    for i = 1, MA.SLOTS do
        local col, row = (i - 1) % 6, math.floor((i - 1) / 6)
        local b = CreateFrame("Button", nil, right)
        b:SetSize(size, size)
        b:SetPoint("TOPLEFT", 20 + col * (size + gap), -20 - row * (size + gap))
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        if not U.SetAtlas(b.bg, "auctionhouse-itemicon-empty", false) then b.bg:SetColorTexture(0, 0, 0, 0.4) end
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 3, -3)
        b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        b.count:SetPoint("BOTTOMRIGHT", -4, 4)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")
        b.slot = i
        b:SetScript("OnClick", function(self, button) MA.ClickSlot(self.slot, button) end)
        b:SetScript("OnReceiveDrag", function(self) MA.ClickSlot(self.slot, "LeftButton") end)
        b:SetScript("OnDragStart", function(self) MA.ClickSlot(self.slot, "LeftButton") end)
        b:SetScript("OnEnter", function(self)
            if GameTooltip and self.has then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if GameTooltip.SetSendMailItem then pcall(GameTooltip.SetSendMailItem, GameTooltip, self.slot) end
                GameTooltip:AddLine(L.MAIL_SLOT_TT, 0.6, 0.6, 0.6, true)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        S.slots[i] = b
    end
    S.attachHint = U.Text(right, "sub", L.MAIL_ATTACH_HINT, 360)
    S.attachHint:SetPoint("TOPLEFT", 20, -20 - 2 * (size + gap) - 6)
    S.attachValue = U.Text(right, "text", "", 360)
    S.attachValue:SetPoint("TOPLEFT", S.attachHint, "BOTTOMLEFT", 0, -12)
end

function MA.ClickSlot(slot, button)
    local fn = G("ClickSendMailItemButton")
    if type(fn) ~= "function" then return end
    if button == "RightButton" then pcall(fn, slot, true) else pcall(fn, slot) end
    MA.RefreshSend()
end

-- Anhaenge: Liste { slot, id, n, name }
function MA.SendItems()
    local fn = G("GetSendMailItem")
    local out = {}
    if type(fn) ~= "function" then return out end
    for i = 1, MA.SLOTS do
        local ok, name, id, icon, n, quality = pcall(fn, i)
        if ok and (name or Num(id)) then out[#out + 1] = { slot = i, id = Num(id) and id or nil, name = name, icon = icon, n = Num(n) and n or 1, quality = quality } end
    end
    return out
end

function MA.RefreshSend()
    local S = MA.send
    if not S or not MA.win or not MA.win:IsShown() or MA.tab ~= "send" then return end
    local items = MA.SendItems()
    local by = {}
    for _, it in ipairs(items) do by[it.slot] = it end
    local value = 0
    for i, b in ipairs(S.slots) do
        local it = by[i]
        b.has = it ~= nil
        if it then
            pcall(b.icon.SetTexture, b.icon, it.icon)
            b.icon:Show()
            b.count:SetText((it.n or 1) > 1 and tostring(it.n) or "")
            local info = it.id and ns.Cost and ns.Cost.Info(it.id)
            value = value + (it.n or 1) * ((info and info.next) or 0)
        else
            b.icon:Hide()
            b.count:SetText("")
        end
    end
    local to = S.to:GetText() or ""
    local own = ns.Moves.OwnChar(to)
    local twink = own and own ~= ns.CharName()
    local lines = {}
    if #items > 0 then lines[#lines + 1] = ns.Plural(#items, "MAIL_ATTACH_VALUE", ns.Money(math.floor(value + 0.5))) end
    if twink then lines[#lines + 1] = GREEN .. L.MAIL_TWINK_HINT:format(own) .. "|r" end
    S.attachValue:SetText(table.concat(lines, "\n"))
    local priceFn = G("GetSendMailPrice")
    local postage = 0
    if type(priceFn) == "function" then
        local ok, p = pcall(priceFn)
        if ok and Num(p) then postage = p end
    end
    local amount = S.money:GetAmount()
    local cost = L.MAIL_POSTAGE:format(ns.Money(postage))
    if amount > 0 and not S.cod:GetChecked() then cost = cost .. "   ·   " .. L.MAIL_TOTAL:format(ns.Money(amount + postage)) end
    if amount > 0 and S.cod:GetChecked() then cost = cost .. "   ·   " .. L.MAIL_COD_AMOUNT:format(ns.Money(amount)) end
    S.cost:SetText(cost)
    if to ~= "" and (#items > 0 or amount > 0 or (S.subject:GetText() or "") ~= "") then S.sendBtn:Enable() else S.sendBtn:Disable() end
    MA.statusText = L.MAIL_FREE:format(MA.FreeSlots())
    MA.status:SetText(MA.statusText)
    if MA.status.money then MA.status.money:SetAmount(math.max(0, GetMoney())) end
end

function MA.Send()
    local S = MA.send
    local to = strtrim and strtrim(S.to:GetText() or "") or (S.to:GetText() or "")
    if to == "" then mod:Print(L.MAIL_NEED_TO); return end
    local items = MA.SendItems()
    local subject = S.subject:GetText() or ""
    if subject == "" then
        subject = (items[1] and items[1].name) or L.MAIL_SUBJECT_GOLD
        if items[1] and (items[1].n or 1) > 1 then subject = subject .. " (" .. items[1].n .. ")" end
    end
    local amount = S.money:GetAmount()
    local cod = S.cod:GetChecked() and amount > 0
    if cod and #items == 0 then mod:Print(L.MAIL_COD_NEEDS_ITEM); return end
    local setMoney, setCod = G("SetSendMailMoney"), G("SetSendMailCOD")
    if type(setCod) == "function" then pcall(setCod, cod and amount or 0) end
    if type(setMoney) == "function" then
        local ok, res = pcall(setMoney, cod and 0 or amount)
        if not cod and amount > 0 and ok and res == false then mod:Print(L.MAIL_NO_MONEY); return end
    end
    MA.lastTo = to
    SendMail(to, subject, S.body:GetText() or "")
end

function MA.OnSendSuccess()
    local S = MA.send
    if not S then return end
    local to = MA.lastTo
    if to then
        local recent = mod.db.mailRecent or {}
        local keep = { to }
        for _, n in ipairs(recent) do if n:lower() ~= to:lower() and #keep < MA.RECENT_MAX then keep[#keep + 1] = n end end
        mod.db.mailRecent = keep
        mod:Print(L.MAIL_SENT:format(to))
    end
    S.subject:SetText("")
    S.body:SetText("")
    S.money:SetAmount(0)
    S.cod:SetChecked(false)
    MA.RefreshSend()
end

---------------------------------------------------------------------------
-- Ablauf am Briefkasten
---------------------------------------------------------------------------
function MA.Replacing() return mod.db.mailWindow ~= false and not MA.blizzVisit end

function MA.OnMailShow()
    if MA.open then return end
    MA.open = true
    if not MA.Replacing() then return end
    if Peon.InCombat and Peon.InCombat() then return end
    MA.Create()
    MA.Tuck()
    MA.win:Show()
    MA.tabs:Select("inbox")
end

function MA.OnMailClosed()
    if not MA.open then return end
    MA.open = false
    MA.Stop()
    MA.closing = true
    if MA.win and MA.win:IsShown() then MA.win:Hide() end
    MA.closing = false
    MA.Untuck()
    MA.blizzVisit = false
    local fn = G("SetSendMailShowing")
    if type(fn) == "function" then pcall(fn, false) end
end

-- Eigenes Fenster zu (ESC, Schliessen): Briefkasten schliessen, ausser es geht zu Blizzards Postfach
function MA.OnWindowHide()
    MA.Stop()
    if MA.closing or MA.toBlizzard then return end
    if MA.open then
        local fn = G("CloseMail")
        if type(fn) == "function" then pcall(fn) end
    end
end

function MA.ShowBlizzard()
    MA.blizzVisit = true
    MA.toBlizzard = true
    if MA.win then MA.win:Hide() end
    MA.toBlizzard = false
    MA.Untuck()
    local f = G("MailFrame")
    if f and not f:IsShown() and type(G("ShowUIPanel")) == "function" then pcall(ShowUIPanel, f) end
end

-- neue Briefe gelesen (Inventory.ScanMail)
function MA.OnInbox()
    if MA.reading and not (ns.Inventory.letters or {})[MA.reading.index] then MA.CloseReader() end
    if MA.win and MA.win:IsShown() and MA.tab ~= "send" then MA.RefreshInbox() end
end

function MA.Init()
    local function Ev(e, fn) pcall(mod.RegisterEvent, mod, e, function(...) mod:Call("Post", fn, ...) end) end
    Ev("MAIL_SHOW", MA.OnMailShow)
    Ev("MAIL_CLOSED", MA.OnMailClosed)
    Ev("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind) if kind == ((Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.MailInfo) or 17) then MA.OnMailShow() end end)
    Ev("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, kind) if kind == ((Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.MailInfo) or 17) then MA.OnMailClosed() end end)
    Ev("MAIL_SEND_SUCCESS", MA.OnSendSuccess)
    Ev("MAIL_SEND_INFO_UPDATE", MA.RefreshSend)
    Ev("MAIL_FAILED", function() if MA.win and MA.win:IsShown() then MA.Refresh() end end)
    Ev("BAG_UPDATE_DELAYED", function() if MA.win and MA.win:IsShown() then MA.Refresh() end end)
    -- Blizzards Postfach erscheint (auch nach "Blizzard" wieder ausblenden): sofort unsichtbar machen
    local function Hook()
        local f = G("MailFrame")
        if not f or MA.hooked then return end
        MA.hooked = true
        f:HookScript("OnShow", function() if MA.open and MA.Replacing() then MA.Tuck() end end)
    end
    Hook()
    Ev("ADDON_LOADED", function(_, name) if name == "Blizzard_MailFrame" then Hook() end end)
end
