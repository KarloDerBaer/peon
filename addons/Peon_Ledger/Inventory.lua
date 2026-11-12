-- Peon_Ledger - Inventory.lua
-- Bestand aller Charaktere (Bauabschnitt L2, Konzept Abschnitt 4/5). Nur ereignisgesteuert, kein regelmaessiger Scan:
--   BAG_UPDATE (Tasche n)        -> nur merken "Tasche n geaendert"
--   BAG_UPDATE_DELAYED           -> nur die geaenderten Taschen neu lesen (im Kampf: erst danach)
--   PLAYER_MONEY                 -> Gold
--   PLAYER_EQUIPMENT_CHANGED     -> Ausruestung
--   Bank / Post / Auktionshaus   -> nur solange das Fenster offen ist
-- Gespeichert (PeonLedgerDB.realms[Realm]):
--   chars[Name] = { faction, class, level, money, moneyT, seen,
--                   places = { bags, bank, mail, auctions, equip } -> { t, items = { [itemID] = Stueck }, ... },
--                   start = { t, money, places = { [Ort] = { t, items } } } }   -- Inventur (Ist-Zustand), je Ort beim ersten Erfassen
--   account = { places = { warband = ... } }                                     -- Bank fuer alle Charaktere (falls es sie gibt)
-- PeonLedgerDB.items[itemID] = { n = Name, q = Qualitaet, i = Symbol }

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local I = {}
ns.Inventory = I

-- Orte, die zum Bestand zaehlen. Ab 0.7.2 (KarloDerBaer): Post gehoert erst beim Nehmen dazu - "mail" wird nur noch intern
-- gelesen (Briefe, Gruende der Bewegungen). Post an eigene Twinks steht bis zum Abholen beim Twink unter "transit".
I.PLACES = { "bags", "bank", "auctions", "equip", "transit" }
I.BANK_LOG_MAX = 5

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function C() return rawget(_G, "C_Container") end

---------------------------------------------------------------------------
-- Speicher
---------------------------------------------------------------------------
function I.RealmData(realm)
    local acc = mod.acc
    if type(acc.realms) ~= "table" then acc.realms = {} end
    realm = realm or ns.Realm()
    local r = acc.realms[realm]
    if type(r) ~= "table" then r = { chars = {}, account = { places = {} } }; acc.realms[realm] = r end
    if type(r.chars) ~= "table" then r.chars = {} end
    if type(r.account) ~= "table" then r.account = { places = {} } end
    if type(r.account.places) ~= "table" then r.account.places = {} end
    return r
end

function I.Char(name)
    local r = I.RealmData()
    name = name or ns.CharName()
    local c = r.chars[name]
    if type(c) ~= "table" then c = { places = {}, start = { places = {} } }; r.chars[name] = c end
    if type(c.places) ~= "table" then c.places = {} end
    if type(c.start) ~= "table" then c.start = { places = {} } end
    if type(c.start.places) ~= "table" then c.start.places = {} end
    return c
end

-- Name, Qualitaet und Symbol eines Gegenstands merken (fuer Anzeige ohne Nachladen)
function I.Remember(id, name, quality, icon)
    if not Num(id) then return end
    local acc = mod.acc
    if type(acc.items) ~= "table" then acc.items = {} end
    local it = acc.items[id]
    if type(it) ~= "table" then it = {}; acc.items[id] = it end
    if type(name) == "string" and name ~= "" and not Peon.IsSecret(name) then it.n = name end
    if Num(quality) then it.q = quality end
    if icon ~= nil and not Peon.IsSecret(icon) then it.i = icon end
end

-- Name/Qualitaet/Symbol eines Gegenstands (gemerkt oder vom Spiel)
function I.ItemInfo(id)
    local it = mod.acc and type(mod.acc.items) == "table" and mod.acc.items[id] or nil
    if type(it) == "table" and it.n then return it.n, it.q, it.i end
    local CI = rawget(_G, "C_Item")
    if CI and CI.GetItemInfo then
        local ok, name, _, quality, _, _, _, _, _, _, icon = pcall(CI.GetItemInfo, id)
        if ok and type(name) == "string" and not Peon.IsSecret(name) then
            I.Remember(id, name, quality, icon)
            return name, quality, icon
        end
        if CI.RequestLoadItemDataByID then pcall(CI.RequestLoadItemDataByID, id) end
    end
    return nil, nil, nil
end

-- Ort setzen; beim ersten Erfassen eines Ortes gehoert der Stand zur Inventur (Ist-Zustand)
function I.SetPlace(c, place, items, extra)
    local old = c.places[place]
    -- Bewegung melden (L3): nur eingeloggter Charakter, nicht beim ersten Erfassen und nicht beim Einloggen
    if ns.Moves and not I.IsQuiet() and type(old) == "table" and type(old.items) == "table" and c == I.Char() then
        mod:Call("Bewegungen", ns.Moves.OnPlace, place, old.items, items, extra and extra.moveInfo or nil)
    end
    if type(extra) == "table" then extra.moveInfo = nil end
    local p = { t = time(), items = items }
    if type(extra) == "table" then for k, v in pairs(extra) do p[k] = v end end
    c.places[place] = p
    if not c.start.places[place] then
        local copy = {}
        for id, n in pairs(items) do copy[id] = n end
        c.start.places[place] = { t = p.t, items = copy }
        if not c.start.t then c.start.t = p.t end
        mod:Dbg("Inventur " .. place)
    end
    I.Changed()
end

-- Gegenstand an einem Ort abziehen/dazuzaehlen ohne neues Lesen (Auktion kommt per Post zurueck, Post an Twinks)
function I.RemoveFromPlace(c, place, id, n)
    local p = c.places[place]
    if type(p) ~= "table" or type(p.items) ~= "table" or not p.items[id] then return 0 end
    local take = math.min(p.items[id], n)
    p.items[id] = p.items[id] - take
    if p.items[id] <= 0 then p.items[id] = nil end
    if place == "auctions" and Num(p.used) and take > 0 then p.used = math.max(0, p.used - 1) end
    I.Changed()
    return take
end

function I.AddToPlace(c, place, id, n)
    local p = c.places[place]
    if type(p) ~= "table" then p = { t = time(), items = {} }; c.places[place] = p end
    if type(p.items) ~= "table" then p.items = {} end
    p.items[id] = (p.items[id] or 0) + n
    if place == "mail" then p.used = (p.used or 0) + 1 end
    I.Changed()
end

-- Keine Bewegungen melden: beim Einloggen und in den ersten I.LOGIN_QUIET Sekunden danach. Das Spiel liefert
-- den Tascheninhalt nach dem Einloggen nach und nach (03.10.2026: 27 Gegenstaende kamen erst Sekunden spaeter
-- und standen als "sonstiger Zugang" im Verlauf).
I.LOGIN_QUIET = 20
function I.IsQuiet()
    if I.quiet then return true end
    local now = GetTime and GetTime() or 0
    return I.quietUntil ~= nil and now < I.quietUntil
end

-- Gegenstand nach Namen (Rechnungen nennen nur den Namen): aus den gemerkten Gegenstaenden
function I.FindItemID(name)
    if type(name) ~= "string" or Peon.IsSecret(name) then return nil end
    I.nameIndex = I.nameIndex or {}
    local id = I.nameIndex[name]
    if id then return id end
    for k, it in pairs(mod.acc.items or {}) do
        if type(it) == "table" and it.n == name then I.nameIndex[name] = k; return k end
    end
    return nil
end

-- Neu zeichnen (Fenster, Tooltip-Zwischenspeicher)
function I.Changed()
    I.cache = nil
    if ns.Window and ns.Window.OnData then ns.Window.OnData() end
end

---------------------------------------------------------------------------
-- Taschen und Bank
---------------------------------------------------------------------------
-- Taschen 0 bis letzte angelegte Tasche (Forever: 0-5, Tasche 5 = Reagenzientasche)
function I.BagIDs()
    local last = tonumber(rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS")) or tonumber(rawget(_G, "NUM_BAG_SLOTS")) or 4
    local ids = {}
    for b = 0, last do ids[#ids + 1] = b end
    return ids
end

-- Bank-Taschen: aus Enum.BagIndex (moderne Bank wie in Retail), sonst die klassische Belegung.
-- Rueckgabe: { char = { ids }, account = { ids } }
function I.BankIDs()
    if I.bankIDs then return I.bankIDs end
    local res = { char = {}, account = {} }
    local E = rawget(_G, "Enum")
    local bi = type(E) == "table" and E.BagIndex or nil
    if type(bi) == "table" then
        local seen = {}
        for name, id in pairs(bi) do
            if type(name) == "string" and Num(id) and name:lower():find("bank") and not seen[id] then
                seen[id] = true
                local lname = name:lower()
                if lname:find("account") or lname:find("warband") then res.account[#res.account + 1] = id
                else res.char[#res.char + 1] = id end
            end
        end
        table.sort(res.char); table.sort(res.account)
    end
    if #res.char == 0 then
        local first = (tonumber(rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS")) or 4) + 1
        res.char = { -1 }
        for b = first, first + 6 do res.char[#res.char + 1] = b end
        res.fallback = true
    end
    I.bankIDs = res
    return res
end

I.bagCache = {}   -- [Tasche] = { [itemID] = Stueck } (nur diese Sitzung, fuer die Summen und spaeter die Bewegungen)
I.boundCache = {} -- [Tasche] = { [itemID] = gebundene Stueck } (ab 0.7.3, fuer das Vermoegen: Gebundenes nur Haendlerpreis)

-- Eine Tasche lesen
function I.ReadBag(bag)
    local Ct = C()
    local items, slots, used, bound = {}, 0, 0, {}
    if not Ct then return items, 0, 0, bound end
    local okn, n = pcall(Ct.GetContainerNumSlots, bag)
    slots = okn and tonumber(n) or 0
    for slot = 1, slots do
        local ok, info = pcall(Ct.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" and Num(info.itemID) then
            used = used + 1
            local count = Num(info.stackCount) and info.stackCount or 1
            items[info.itemID] = (items[info.itemID] or 0) + count
            if info.isBound == true then bound[info.itemID] = (bound[info.itemID] or 0) + count end
            I.Remember(info.itemID, info.itemName, info.quality, info.iconFileID)
        end
    end
    I.bagSlots[bag] = { slots, used }
    I.boundCache[bag] = bound
    return items, slots, used, bound
end

I.bagSlots = {}   -- [Tasche] = { Plaetze, belegt } (diese Sitzung)

-- Plaetze ueber mehrere Taschen: gesamt, belegt
local function Slots(ids)
    local all, used = 0, 0
    for _, b in ipairs(ids) do
        local s = I.bagSlots[b]
        if s then all, used = all + s[1], used + s[2] end
    end
    return { slots = all, used = used }
end
I.Slots = Slots

local function Sum(ids)
    local items = {}
    for _, b in ipairs(ids) do
        for id, n in pairs(I.bagCache[b] or {}) do items[id] = (items[id] or 0) + n end
    end
    return items
end

-- gebundene Stueck ueber mehrere Taschen (ab 0.7.3)
local function SumBound(ids)
    local items = {}
    for _, b in ipairs(ids) do
        for id, n in pairs(I.boundCache[b] or {}) do items[id] = (items[id] or 0) + n end
    end
    return items
end

-- gebundene Stueck eines Gegenstands an einem Ort: Angelegtes ist immer gebunden (ab 0.7.3)
function I.BoundIn(p, place, id, n)
    if place == "equip" then return n end
    local b = type(p) == "table" and type(p.bound) == "table" and tonumber(p.bound[id]) or 0
    return math.max(0, math.min(b, n))
end

local function WithBound(t, ids) t.bound = SumBound(ids); return t end

local function IsIn(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

function I.ScanBags(list)
    for _, b in ipairs(list or I.BagIDs()) do I.bagCache[b] = (I.ReadBag(b)) end
    I.SetPlace(I.Char(), "bags", Sum(I.BagIDs()), WithBound(Slots(I.BagIDs()), I.BagIDs()))
end

function I.ScanBank(list)
    local ids = I.BankIDs()
    local slotsChar, slotsAcc = 0, 0
    local log = {}
    for _, b in ipairs(list or ids.char) do
        local items, slots = I.ReadBag(b)
        I.bagCache[b] = items
        slotsChar = slotsChar + slots
        log[#log + 1] = b .. ":" .. slots
    end
    if not list then
        for _, b in ipairs(ids.account) do
            local items, slots = I.ReadBag(b)
            I.bagCache[b] = items
            slotsAcc = slotsAcc + slots
            log[#log + 1] = "A" .. b .. ":" .. slots
        end
    end
    I.SetPlace(I.Char(), "bank", Sum(ids.char), WithBound(Slots(ids.char), ids.char))
    if #ids.account > 0 and (slotsAcc > 0 or list) then
        local r = I.RealmData()
        r.account.places.warband = { t = time(), items = Sum(ids.account), bound = SumBound(ids.account) }
    end
    -- Protokoll der ersten Bankbesuche (Fehlersuche: welche Taschen hat die Bank?)
    if not list then
        local acc = mod.acc
        if type(acc.bankLog) ~= "table" then acc.bankLog = {} end
        if #acc.bankLog < I.BANK_LOG_MAX then
            acc.bankLog[#acc.bankLog + 1] = ("%s %s: %s%s"):format(date("%Y-%m-%d %H:%M"), ns.CharName(), table.concat(log, " "),
                ids.fallback and " (klassische Belegung)" or "")
        end
    end
end

---------------------------------------------------------------------------
-- Ausruestung, Gold, Post, Auktionen
---------------------------------------------------------------------------
function I.ScanEquip(retry)
    local items = {}
    local first = tonumber(rawget(_G, "INVSLOT_FIRST_EQUIPPED")) or 1
    local last = tonumber(rawget(_G, "INVSLOT_LAST_EQUIPPED")) or 19
    local fn = rawget(_G, "GetInventoryItemID")
    if type(fn) ~= "function" then return end
    local n = 0
    for slot = first, last do
        local ok, id = pcall(fn, "player", slot)
        if ok and Num(id) then
            items[id] = (items[id] or 0) + 1
            n = n + 1
            I.ItemInfo(id)
        end
    end
    -- direkt nach dem Einloggen liefert das Spiel die Ausruestung oft noch nicht:
    -- leer nicht speichern, sondern spaeter noch einmal lesen (nach 3 Versuchen gilt "leer")
    if n == 0 and (retry or 0) < 3 and C_Timer then
        C_Timer.After(3, function() if not I.InCombat() then I.ScanEquip((retry or 0) + 1) else I.equipDirty = true end end)
        return
    end
    local c = I.Char()
    local quiet = not I.equipSeen
    I.equipSeen = true
    -- alte Inventur ohne Ausruestung (Fehler bis 0.2.0) durch die erste echte ersetzen
    local st = c.start.places.equip
    if n > 0 and type(st) == "table" and type(st.items) == "table" and next(st.items) == nil then c.start.places.equip = nil end
    local was = I.quiet
    if quiet then I.quiet = true end
    I.SetPlace(c, "equip", items)
    I.quiet = was
end

function I.ScanMoney()
    local ok, m = pcall(GetMoney)
    if not ok or not Num(m) then return end
    local c = I.Char()
    if ns.Moves and not I.IsQuiet() and Num(c.money) and m ~= c.money then mod:Call("Bewegungen", ns.Moves.OnMoney, m - c.money) end
    c.money, c.moneyT = m, time()
    if not c.start.money then c.start.money = m; c.start.t = c.start.t or time() end
    I.Changed()
end

-- Absender "Auktionshaus" (deutsch/englisch, auch in anderen Sprachen ueber den Text des Spiels)
function I.IsAHSender(sender)
    if type(sender) ~= "string" then return false end
    local s = sender:lower()
    if s:find("auktionshaus", 1, true) or s:find("auction house", 1, true) then return true end
    local g = rawget(_G, "AUCTION_HOUSE_MAIL_SENDER") or rawget(_G, "BUTTON_LAG_AUCTIONHOUSE")
    return type(g) == "string" and s == g:lower()
end

-- Protokoll der ersten Briefe (Fehlersuche: Betreff und Rechnung je Art); Anhaenge werden danach ergaenzt
I.MAIL_LOG_MAX = 40
function I.LogLetter(letter, i)
    local acc = mod.acc
    if type(acc.mailLog) ~= "table" then acc.mailLog = {} end
    if #acc.mailLog >= I.MAIL_LOG_MAX then return end
    I.mailLogSeen = I.mailLogSeen or {}
    local key = tostring(letter.sender) .. "|" .. tostring(letter.subject) .. "|" .. tostring(letter.money)
    if I.mailLogSeen[key] then return end
    I.mailLogSeen[key] = true
    local inv = letter.invoice
    acc.mailLog[#acc.mailLog + 1] = ("%s #%d %s | %s | Gold %s | Rechnung %s"):format(date("%Y-%m-%d %H:%M"), i,
        tostring(letter.sender), tostring(letter.subject), tostring(letter.money),
        inv and (tostring(inv.kind) .. " " .. tostring(inv.item) .. " x" .. tostring(inv.count)) or "-")
end

-- Postfach (nur offen): Anhaenge und Gold in den Briefen (Nachnahme zaehlt nicht)
I.ATTACH_MAX = 16
function I.ScanMail()
    local numFn = rawget(_G, "GetInboxNumItems")
    if type(numFn) ~= "function" then return end
    local ok, shown, total = pcall(numFn)
    if not ok or not Num(shown) then return end
    local items, money, letters, used = {}, 0, 0, 0
    local header, item = rawget(_G, "GetInboxHeaderInfo"), rawget(_G, "GetInboxItem")
    local invoiceFn = rawget(_G, "GetInboxInvoiceInfo")
    I.letters = {}   -- je Brief: Absender, Betreff, Gold, Anhaenge, Rechnung (fuer die Gruende der Bewegungen)
    local loading = false
    local waiting = rawget(_G, "RETRIEVING_DATA")
    for i = 1, shown do
        letters = letters + 1
        local okh, icon, _, sender, subject, m, cod, days, count, wasRead, wasReturned = pcall(header, i)
        local letter = { items = {}, index = i }
        I.letters[i] = letter
        if okh then
            letter.sender = type(sender) == "string" and not Peon.IsSecret(sender) and sender or nil
            letter.subject = type(subject) == "string" and not Peon.IsSecret(subject) and subject or nil
            letter.money = Num(m) and m or 0
            letter.cod = Num(cod) and cod > 0 and cod or nil   -- Nachnahme (ab 0.7, Kosten des Erhaltenen)
            letter.days = Num(days) and days or nil            -- Tage bis zum Ablauf (ab 0.14)
            letter.icon = (icon ~= nil and not Peon.IsSecret(icon)) and icon or nil
            letter.read = wasRead and true or nil
            letter.returned = wasReturned and true or nil
            letter.count = Num(count) and count or 0
        end
        -- ab 0.14: noch nicht geladen (Betreff "Rufe Daten ab" oder ohne Absender) -> spaeter noch einmal lesen
        if okh and type(waiting) == "string" and letter.subject == waiting then
            letter.loading = true
            loading = true
        end
        if type(invoiceFn) == "function" then
            local oki, kind, itemName, player, bid, buyout, deposit, cut, _, _, _, qty = pcall(invoiceFn, i)
            if oki and type(kind) == "string" and not Peon.IsSecret(kind) then
                letter.invoice = { kind = kind, item = type(itemName) == "string" and not Peon.IsSecret(itemName) and itemName or nil,
                    player = type(player) == "string" and not Peon.IsSecret(player) and player or nil,
                    buyout = Num(buyout) and buyout or nil, deposit = Num(deposit) and deposit or nil, cut = Num(cut) and cut or nil,
                    count = Num(qty) and qty or nil }
            end
        end
        letter.ah = letter.invoice ~= nil or I.IsAHSender(letter.sender)
        I.LogLetter(letter, i)
        if okh and Num(m) then money = money + m end
        if okh and Num(count) and count > 0 and type(item) == "function" then
            for a = 1, (tonumber(rawget(_G, "ATTACHMENTS_MAX_RECEIVE")) or I.ATTACH_MAX) do
                local oki, name, id, icon, n, quality = pcall(item, i, a)
                if oki and Num(id) then
                    used = used + 1
                    local k = Num(n) and n or 1
                    items[id] = (items[id] or 0) + k
                    letter.items[id] = (letter.items[id] or 0) + k
                    I.Remember(id, name, quality, icon)
                end
            end
        end
    end
    -- je Brief ein kurzer Stand fuer die Post aller Charaktere (ab 0.14): Gold, Anhaenge, Ablauf als Zeitpunkt
    local list = {}
    for _, l in ipairs(I.letters) do
        list[#list + 1] = { m = l.money ~= 0 and l.money or nil, n = l.count ~= 0 and l.count or nil,
            exp = l.days and (time() + math.floor(l.days * 86400)) or nil, ah = l.ah or nil, cod = l.cod }
    end
    I.SetPlace(I.Char(), "mail", items, { money = money, letters = letters, total = Num(total) and total or letters, used = used, list = list })
    if not loading then I.mailTries = 0 end
    if loading and not I.mailRetry and (I.mailTries or 0) < 10 then
        I.mailRetry = true
        I.mailTries = (I.mailTries or 0) + 1
        local CT = rawget(_G, "C_Timer")
        if CT and CT.After then
            CT.After(0.5, function() I.mailRetry = nil; if I.open.mail then mod:Call("Bestand", I.ScanMail) end end)
        else
            I.mailRetry = nil
        end
    end
    if ns.Mail and ns.Mail.OnInbox then mod:Call("Post", ns.Mail.OnInbox) end
end

-- Briefe, die bald ablaufen, und Gold in der Post je Charakter (ab 0.14, letzter gesehener Stand)
-- Rueckgabe { letters, money, ah, next = Zeitpunkt des naechsten Ablaufs } oder nil (Postfach nie gesehen)
function I.MailInfo(c)
    local p = c and c.places and c.places.mail
    if type(p) ~= "table" then return nil end
    local res = { letters = p.letters or 0, money = p.money or 0, ah = 0, t = p.t }
    for _, l in ipairs(type(p.list) == "table" and p.list or {}) do
        if l.ah then res.ah = res.ah + 1 end
        if l.exp and (not res.next or l.exp < res.next) then res.next = l.exp end
    end
    return res
end

-- Eigene Auktionen (wenn das Spiel sie meldet): laufende als Bestand, verkaufte nur gezaehlt
function I.ScanAuctions()
    local ah = rawget(_G, "C_AuctionHouse")
    if not ah or not ah.GetNumOwnedAuctions then return end
    local ok, n = pcall(ah.GetNumOwnedAuctions)
    if not ok or not Num(n) then return end
    local items, active, sold, soldItems, soldGross = {}, 0, 0, {}, {}
    I.auctionItems = I.auctionItems or {}   -- auctionID -> itemID (ab 0.7: Abbruchkosten dem Gegenstand zurechnen)
    for i = 1, n do
        local oki, a = pcall(ah.GetOwnedAuctionInfo, i)
        if oki and type(a) == "table" and type(a.itemKey) == "table" and Num(a.itemKey.itemID) then
            if Num(a.auctionID) then I.auctionItems[a.auctionID] = a.itemKey.itemID end
            if a.status == 1 then
                sold = sold + 1
                local id = a.itemKey.itemID
                soldItems[id] = (soldItems[id] or 0) + (Num(a.quantity) and a.quantity or 1)
                -- Preis fuer die spaetere Zuordnung des Erloeses (ab 0.6): buyoutAmount je Stueck
                if Num(a.buyoutAmount) then soldGross[id] = (soldGross[id] or 0) + a.buyoutAmount * (Num(a.quantity) and a.quantity or 1) end
            else
                active = active + 1
                local id = a.itemKey.itemID
                items[id] = (items[id] or 0) + (Num(a.quantity) and a.quantity or 1)
                I.ItemInfo(id)
            end
        end
    end
    local c = I.Char()
    local oldSold = type(c.places.auctions) == "table" and c.places.auctions.soldItems or {}
    I.SetPlace(c, "auctions", items, { active = active, sold = sold, used = active, soldItems = soldItems,
        moveInfo = { soldItems = soldItems, oldSold = oldSold, soldGross = soldGross } })
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
I.dirty = {}
I.open = {}

-- Fenster-Typen (Enum.PlayerInteractionType; Werte aus Retail als Rueckfall)
local function PIT(name, fallback)
    local E = rawget(_G, "Enum")
    local t = type(E) == "table" and E.PlayerInteractionType or nil
    return type(t) == "table" and t[name] or fallback
end

function I.InCombat() return Peon.InCombat and Peon.InCombat() or false end

-- geaenderte Taschen lesen (im Kampf erst danach, Ledger.lua ruft Flush bei COMBAT_END)
function I.Flush()
    if I.InCombat() then return end
    local bags, bank = {}, {}
    local bankIDs = I.BankIDs()
    for b in pairs(I.dirty) do
        if IsIn(I.BagIDs(), b) then bags[#bags + 1] = b
        elseif I.open.bank and (IsIn(bankIDs.char, b) or IsIn(bankIDs.account, b)) then bank[#bank + 1] = b end
    end
    I.dirty = {}
    if #bags > 0 then
        I.ScanBags(bags)
        -- Ausruestung mitlesen (19 Plaetze, kaum Aufwand): falls PLAYER_EQUIPMENT_CHANGED nicht kommt (in Forever
        -- bisher nie gesehen), waere Anlegen sonst ein Abgang aus den Taschen
        if I.equipSeen then I.ScanEquip() end
    end
    if #bank > 0 then
        for _, b in ipairs(bank) do I.bagCache[b] = (I.ReadBag(b)) end
        I.SetPlace(I.Char(), "bank", Sum(bankIDs.char), Slots(bankIDs.char))
        if #bankIDs.account > 0 then I.RealmData().account.places.warband = { t = time(), items = Sum(bankIDs.account) } end
    end
end

function I.OnLogin()
    local c = I.Char()
    local _, class = UnitClass("player")
    if type(class) == "string" and not Peon.IsSecret(class) then c.class = class end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if type(faction) == "string" and not Peon.IsSecret(faction) then c.faction = faction end
    local okl, level = pcall(UnitLevel, "player")
    if okl and Num(level) then c.level = level end
    c.seen = time()
    -- beim Einloggen keine Bewegungen (Stand wie beim Ausloggen; Unterschiede waeren Altlasten)
    I.quietUntil = (GetTime and GetTime() or 0) + I.LOGIN_QUIET
    I.quiet = true
    I.ScanMoney()
    I.ScanBags()
    I.ScanEquip()
    I.quiet = nil
end

function I.OnBankOpen()
    I.open.bank = true
    if C_Timer then C_Timer.After(0.3, function() mod:Call("Bestand", I.ScanBank) end) else I.ScanBank() end
end

function I.OnMailOpen()
    if not I.open.mail then I.letters = {}; I.mailTries = 0 end   -- ab 0.14: Briefe des letzten Besuchs gelten nicht mehr
    I.open.mail = true
end

function I.Init()
    I.RealmData()
    mod:RegisterEvent("BAG_UPDATE", function(_, bag) if Num(bag) then I.dirty[bag] = true end end)
    mod:RegisterEvent("BAG_UPDATE_DELAYED", function() I.Flush() end)
    mod:RegisterEvent("PLAYER_MONEY", function()
        I.ScanMoney()
        if mod.launcher then mod.launcher:Refresh() end
    end)
    mod:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() if not I.InCombat() then I.ScanEquip() else I.equipDirty = true end end)
    mod:On("COMBAT_END", function() if I.equipDirty then I.equipDirty = nil; I.ScanEquip() end end)
    pcall(mod.RegisterEvent, mod, "PLAYERBANKSLOTS_CHANGED", function()
        if I.open.bank then for _, b in ipairs(I.BankIDs().char) do I.dirty[b] = true end; I.Flush() end
    end)
    -- Bank und Post: alte Ereignisse und die allgemeine Meldung (in Forever kam z. B. MAIL_CLOSED nicht)
    pcall(mod.RegisterEvent, mod, "BANKFRAME_OPENED", function() I.OnBankOpen() end)
    pcall(mod.RegisterEvent, mod, "BANKFRAME_CLOSED", function() I.open.bank = nil end)
    pcall(mod.RegisterEvent, mod, "MAIL_SHOW", function() I.OnMailOpen() end)
    pcall(mod.RegisterEvent, mod, "MAIL_CLOSED", function() I.open.mail = nil end)
    mod:RegisterEvent("MAIL_INBOX_UPDATE", function() if I.open.mail then I.ScanMail() end end)
    pcall(mod.RegisterEvent, mod, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
        if kind == PIT("Banker", 8) then I.OnBankOpen()
        elseif kind == PIT("MailInfo", 17) then I.OnMailOpen() end
    end)
    pcall(mod.RegisterEvent, mod, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, kind)
        if kind == PIT("Banker", 8) then I.open.bank = nil
        elseif kind == PIT("MailInfo", 17) then I.open.mail = nil end
    end)
    -- Auktionshaus: eigene Auktionen einmal abfragen (nur lesend), Ergebnis kommt als OWNED_AUCTIONS_UPDATED
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_SHOW", function()
        local ah = rawget(_G, "C_AuctionHouse")
        if ah and ah.QueryOwnedAuctions then pcall(ah.QueryOwnedAuctions, {}) end
    end)
    pcall(mod.RegisterEvent, mod, "OWNED_AUCTIONS_UPDATED", function() I.ScanAuctions() end)
end

---------------------------------------------------------------------------
-- Abfragen fuer Anzeige, Tooltip und (spaeter) Broker
---------------------------------------------------------------------------
-- Stueck eines Gegenstands je Charakter und Ort im aktuellen Realm:
-- { total, chars = { { name, total, places = { bags = n, ... } }, ... }, warband = n }
function I.Count(id)
    local r = I.RealmData()
    local res = { total = 0, chars = {} }
    for name, c in pairs(r.chars) do
        local ct, places = 0, {}
        for _, place in ipairs(I.PLACES) do
            local p = c.places[place]
            local n = type(p) == "table" and type(p.items) == "table" and p.items[id] or nil
            if Num(n) and n > 0 then places[place] = n; ct = ct + n end
        end
        if ct > 0 then res.chars[#res.chars + 1] = { name = name, total = ct, places = places }; res.total = res.total + ct end
    end
    local w = r.account.places.warband
    local wn = type(w) == "table" and type(w.items) == "table" and w.items[id] or nil
    if Num(wn) and wn > 0 then res.warband = wn; res.total = res.total + wn end
    local me = ns.CharName()
    table.sort(res.chars, function(a, b)
        if (a.name == me) ~= (b.name == me) then return a.name == me end
        if a.total ~= b.total then return a.total > b.total end
        return a.name < b.name
    end)
    return res
end

-- Gold aller Charaktere im Realm: Summe, Anzahl Charaktere
function I.TotalMoney()
    local total, n = 0, 0
    for _, c in pairs(I.RealmData().chars) do
        if Num(c.money) then total = total + c.money; n = n + 1 end
    end
    return total, n
end

-- Alle Gegenstaende im Realm: { [itemID] = { total, where = { [Name] = { bags = n, ... } } } } (zwischengespeichert)
function I.AllItems()
    if I.cache then return I.cache end
    local r = I.RealmData()
    local all = {}
    for name, c in pairs(r.chars) do
        for _, place in ipairs(I.PLACES) do
            local p = c.places[place]
            if type(p) == "table" and type(p.items) == "table" then
                for id, n in pairs(p.items) do
                    if Num(n) and n > 0 then
                        local e = all[id]
                        if not e then e = { total = 0, where = {} }; all[id] = e end
                        e.total = e.total + n
                        e.bound = (e.bound or 0) + I.BoundIn(p, place, id, n)
                        e.where[name] = e.where[name] or {}
                        e.where[name][place] = (e.where[name][place] or 0) + n
                    end
                end
            end
        end
    end
    local w = r.account.places.warband
    if type(w) == "table" and type(w.items) == "table" then
        for id, n in pairs(w.items) do
            if Num(n) and n > 0 then
                local e = all[id]
                if not e then e = { total = 0, where = {} }; all[id] = e end
                e.total = e.total + n
                e.bound = (e.bound or 0) + I.BoundIn(w, "warband", id, n)
                e.warband = (e.warband or 0) + n
            end
        end
    end
    I.cache = all
    return all
end

-- belegte Plaetze eines Ortes und (Taschen, Bank) alle Plaetze; nil = noch nicht erfasst.
-- Post: Anhaenge (je Anhang ein Platz), Auktionen: laufende Auktionen.
function I.PlaceSlots(c, place)
    local p = c.places[place]
    if type(p) ~= "table" then return nil end
    if Num(p.slots) and p.slots > 0 then return p.used or 0, p.slots end
    if Num(p.used) then return p.used, nil end
    if place == "auctions" and Num(p.active) then return p.active, nil end   -- Stand vor 0.2.2
    return nil
end

-- Summe der Stueck an einem Ort eines Charakters (Uebersicht); nil = noch nicht erfasst
function I.PlaceCount(c, place)
    local p = c.places[place]
    if type(p) ~= "table" or type(p.items) ~= "table" then return nil end
    local n = 0
    for _, x in pairs(p.items) do if Num(x) then n = n + x end end
    return n
end

-- Charakter loeschen (Optionen)
function I.DeleteChar(name)
    local r = I.RealmData()
    r.chars[name] = nil
    I.Changed()
end

function I.CharNames()
    local list = {}
    for name in pairs(I.RealmData().chars) do list[#list + 1] = name end
    table.sort(list)
    return list
end
