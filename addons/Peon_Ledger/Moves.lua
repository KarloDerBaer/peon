-- Peon_Ledger - Moves.lua
-- Bewegungen von Gegenstaenden und Gold mit Grund (Bauabschnitt L3, Konzept Abschnitt 4). Nur ereignisgesteuert.
--
-- Zwei Bausteine:
--   1. Abgleich: Inventory meldet jede Aenderung eines Ortes (alt -> neu) an M.OnPlace, Gold an M.OnMoney.
--      Aenderungen werden kurz gesammelt (M.SETTLE Sekunden nach der letzten) und je Gegenstand verrechnet:
--      Taschen -1 und Bank +1 = Umbuchung (kein Eintrag), Post -1 und Taschen +1 = aus der Post geholt (kein Eintrag).
--   2. Zusammenhang: was gerade passiert (Fenster offen, Aufruf mitgelesen, Ereignis) -> Grund der Bewegung.
--      Passt nichts: "sonstiges" (Zugang) bzw. "verbraucht/sonstiges" (Abgang).
--
-- Gespeichert: PeonLedgerDB.realms[Realm].moves = { { t, c, k, id, n, m, x }, ... }  (aelteste zuerst)
--   t = Zeit, c = Charakter, k = Art (M.KINDS), id/n = Gegenstand und Stueck (+ Zugang, - Abgang),
--   m = Gold in Kupfer (+/-), x = Zusatz (Handelspartner, Absender, Rezept ...)
--   Beute und Benutzt werden je Tag, Charakter und Gegenstand zusammengefasst (d = Tag).
--   Eintraege aelter als M.KEEP_DAYS -> Wochensummen realms[Realm].weeks["JJJJ-WW"][c|k|id] = { n, m }.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local M = {}
ns.Moves = M

M.SETTLE = 1.0        -- Sekunden Ruhe, bevor gesammelte Aenderungen verbucht werden
M.WINDOW = 6          -- so lange (Sekunden) gilt ein Zusammenhang als "gerade eben"
M.KEEP_DAYS = 90
M.MERGE_LOOKBACK = 300

-- Arten: side = "in" (Zugang), "out" (Abgang), "move" (Umbuchung, zaehlt nicht), "both" (je nach Vorzeichen)
M.KINDS = {
    loot     = { side = "both", daily = true },
    use      = { side = "out", daily = true },
    quest    = { side = "both" },
    vendor   = { side = "both" },   -- Haendler: Gegenstand gekauft/verkauft, Gold
    buyback  = { side = "both" },
    repair   = { side = "out" },
    ahbuy    = { side = "both" },   -- Auktion gekauft: Gold -, Gegenstand + (kommt per Post)
    ahsold   = { side = "both" },   -- Auktion verkauft: Gegenstand -, Gold + (Rechnung)
    ahfee    = { side = "out" },    -- Einstellgebuehr / Abbruchkosten
    posted   = { side = "move" },   -- Auktion eingestellt (Taschen -> Auktionen)
    ahback   = { side = "move" },   -- (bis 0.3.2) Auktion verschwunden, nicht verkauft
    ahreturn = { side = "move" },   -- Auktion zurueck per Post (abgelaufen/abgebrochen), ab 0.4
    craft    = { side = "both" },   -- hergestellt (+) / Material (-)
    trade    = { side = "both" },
    mail     = { side = "both" },   -- Post von/an andere
    twink    = { side = "move" },   -- Post an/von eigenen Charakteren
    taxi     = { side = "out" },
    trainer  = { side = "out" },
    destroy  = { side = "out" },
    other    = { side = "both" },
    fix      = { side = "move" },   -- Korrektur aus "Inventur neu" (ab 0.6), zaehlt nicht als Gewinn
    diff     = { side = "move" },   -- Abweichung der Kontrollrechnung (ab 0.14, Check.lua), zaehlt nicht als Gewinn
}

-- Filter im Verlauf (ab 0.6): Gruppe -> Arten
M.GROUPS = {
    { key = "all" }, { key = "ah", kinds = { "ahsold", "ahbuy", "ahfee", "posted", "ahback", "ahreturn" } },
    { key = "vendor", kinds = { "vendor", "buyback", "repair" } }, { key = "loot", kinds = { "loot" } },
    { key = "use", kinds = { "use" } }, { key = "quest", kinds = { "quest" } }, { key = "craft", kinds = { "craft" } },
    { key = "trade", kinds = { "trade" } }, { key = "mail", kinds = { "mail", "twink" } },
    { key = "travel", kinds = { "taxi", "trainer" } }, { key = "destroy", kinds = { "destroy" } },
    { key = "fix", kinds = { "fix", "diff" } }, { key = "other", kinds = { "other" } },
}
function M.InGroup(k, group)
    if not group or group == "all" then return true end
    for _, g in ipairs(M.GROUPS) do
        if g.key == group then
            for _, kk in ipairs(g.kinds or {}) do if kk == k then return true end end
            return false
        end
    end
    return true
end

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Now() return GetTime and GetTime() or time() end
local function Str(v) if type(v) == "string" and not Peon.IsSecret(v) and v ~= "" then return v end return nil end

---------------------------------------------------------------------------
-- Speicher
---------------------------------------------------------------------------
function M.List(realm)
    local r = ns.Inventory.RealmData(realm)
    if type(r.moves) ~= "table" then r.moves = {} end
    return r.moves
end

local function Day(t) return date("%Y-%m-%d", t) end

-- Eintrag anlegen (oder zur Tagessumme addieren)
function M.Add(k, id, n, m, x, c)
    local kind = M.KINDS[k] or M.KINDS.other
    c = c or ns.CharName()
    local t = time()
    local list = M.List()
    if (n == nil or n == 0) and (m == nil or m == 0) then return end
    if kind.daily then
        local d = Day(t)
        local sign = (n and n ~= 0 and (n > 0 and 1 or -1)) or (m and (m > 0 and 1 or -1)) or 0
        for i = #list, math.max(1, #list - M.MERGE_LOOKBACK), -1 do
            local e = list[i]
            if e.d ~= nil and e.d ~= d then break end
            if e.d == d and e.c == c and e.k == k and e.id == id and e.s == sign then
                if n then e.n = (e.n or 0) + n end
                if m then e.m = (e.m or 0) + m end
                e.t = t
                e.cnt = (e.cnt or 1) + 1
                M.Changed()
                return e
            end
        end
        local e = { t = t, c = c, k = k, id = id, n = n, m = m, x = x, d = d, s = sign }
        list[#list + 1] = e
        M.Changed()
        return e
    end
    local e = { t = t, c = c, k = k, id = id, n = n, m = m, x = x }
    list[#list + 1] = e
    M.Changed()
    return e
end

function M.Changed()
    M.cache = nil
    if ns.Cost then ns.Cost.dirty = true end
    if ns.Last then ns.Last.dirty = true end
    if ns.Window and ns.Window.OnData then ns.Window.OnData() end
end

-- Alte Eintraege in Wochensummen ueberfuehren (beim Einloggen)
function M.Prune(now)
    now = now or time()
    local r = ns.Inventory.RealmData()
    local list = M.List()
    local limit = now - M.KEEP_DAYS * 86400
    if #list == 0 or (list[1].t or now) >= limit then return 0 end
    if type(r.weeks) ~= "table" then r.weeks = {} end
    local keep, moved = {}, 0
    for _, e in ipairs(list) do
        if (e.t or now) < limit then
            local wk = date("%Y-%W", e.t)
            local w = r.weeks[wk]
            if type(w) ~= "table" then w = {}; r.weeks[wk] = w end
            local key = tostring(e.c) .. "|" .. tostring(e.k) .. "|" .. tostring(e.id or 0)
            local s = w[key]
            if type(s) ~= "table" then s = {}; w[key] = s end
            if e.n then s.n = (s.n or 0) + e.n end
            if e.m then s.m = (s.m or 0) + e.m end
            moved = moved + 1
        else
            keep[#keep + 1] = e
        end
    end
    if ns.Last and moved > 0 then mod:Call("Zuletzt", ns.Last.Persist) end
    if ns.Cost and moved > 0 then
        local old = {}
        for _, e in ipairs(list) do if (e.t or now) < limit then old[#old + 1] = e end end
        mod:Call("Kosten", ns.Cost.Absorb, old, limit)
    end
    r.moves = keep
    M.Changed()
    return moved
end

---------------------------------------------------------------------------
-- Zusammenhang: was passiert gerade?
---------------------------------------------------------------------------
M.open = {}      -- [Fenster] = true (merchant, mail, bank, auction, trade, skill, loot, taxi, trainer, quest)
M.closed = {}    -- [Fenster] = Zeit des Schliessens (gilt noch M.WINDOW Sekunden)
M.ctx = {}       -- [Name] = { t = Zeit, ... } zuletzt mitgelesene Aufrufe / Ereignisse

function M.Open(win) M.open[win] = true; M.closed[win] = nil end
function M.Close(win) if M.open[win] then M.open[win] = nil; M.closed[win] = Now() end end

-- Fenster offen oder gerade geschlossen
function M.IsOpen(win)
    if M.open[win] then return true end
    local t = M.closed[win]
    return t ~= nil and Now() - t <= M.WINDOW
end

function M.Note(name, data)
    data = data or {}
    data.t = Now()
    M.ctx[name] = data
    return data
end

-- Zusammenhang "gerade eben" (innerhalb von window Sekunden)
function M.Recent(name, window)
    local c = M.ctx[name]
    if c and Now() - c.t <= (window or M.WINDOW) then return c end
    return nil
end

---------------------------------------------------------------------------
-- Gegenstaende: Aenderungen sammeln und verbuchen
---------------------------------------------------------------------------
M.pending = nil   -- { items = { [id] = { [Ort] = Differenz } }, money = { Differenzen }, gen = n }

local function Batch()
    if not M.pending then M.pending = { items = {}, money = {}, gen = 0 } end
    return M.pending
end

local function Schedule()
    local b = Batch()
    b.gen = b.gen + 1
    local gen = b.gen
    if C_Timer and C_Timer.After then
        C_Timer.After(M.SETTLE, function()
            if M.pending and M.pending.gen == gen then mod:Call("Bewegungen", M.Flush) end
        end)
    else
        M.Flush()
    end
end

-- von Inventory: Ort eines Charakters hat sich geaendert (nur eingeloggter Charakter, nicht beim ersten Erfassen)
function M.OnPlace(place, old, new, info)
    if M.paused then return end
    if place == "auctions" then return M.OnAuctions(old, new, info) end
    local b = Batch()
    local changed = false
    local seen = {}
    for id, n in pairs(new) do
        seen[id] = true
        local d = n - (old[id] or 0)
        if d ~= 0 then
            b.items[id] = b.items[id] or {}
            b.items[id][place] = (b.items[id][place] or 0) + d
            changed = true
        end
    end
    for id, n in pairs(old) do
        if not seen[id] and n ~= 0 then
            b.items[id] = b.items[id] or {}
            b.items[id][place] = (b.items[id][place] or 0) - n
            changed = true
        end
    end
    if changed then Schedule() end
end

-- Gold geaendert
function M.OnMoney(delta)
    if M.paused or not Num(delta) or delta == 0 then return end
    local b = Batch()
    b.money[#b.money + 1] = delta
    Schedule()
end

-- Eigene Charaktere des Realms nach Vor- oder vollem Namen (fuer Post an Twinks)
function M.OwnChar(name)
    name = Str(name)
    if not name then return nil end
    local lower = name:lower()
    for full in pairs(ns.Inventory.RealmData().chars) do
        if full:lower() == lower or (full:match("^(%S+)") or ""):lower() == lower then return full end
    end
    return nil
end

-- Brief aus der Post zu einem Gegenstand: zuerst Auktionshaus
local function LetterFor(id)
    local best
    for _, l in ipairs(ns.Inventory.letters or {}) do
        if l.items and l.items[id] then
            if l.ah then return l end
            best = best or l
        end
    end
    return best
end

-- Art eines Briefes vom Auktionshaus aus dem Betreff (deutsch und englisch)
function M.AHLetterKind(subject)
    local s = (Str(subject) or ""):lower()
    if s:find("gewonnen") or s:find("won") then return "won" end
    if s:find("abgelaufen") or s:find("expired") then return "expired" end
    if s:find("abgebrochen") or s:find("cancel") then return "cancelled" end
    if s:find("erfolgreich") or s:find("successful") or s:find("sold") then return "sold" end
    if s:find("ueberboten") or s:find("überboten") or s:find("outbid") then return "outbid" end
    return nil
end

-- Art eines Briefes: "won" (Auktion gekauft), "sold" (Erloes), "return" (Auktion zurueck), "outbid", "ah", "mail"
-- Zuerst die Rechnung (Forever: auch gekaufte Auktionen haben eine, Art "buyer"); ein Brief vom Auktionshaus
-- mit Gegenstand ohne Kaufrechnung ist eine zurueckgekommene Auktion (abgelaufen/abgebrochen).
-- Ab 0.14: Ist der Betreff noch nicht geladen ("Rufe Daten ab", ohne Rechnung), entscheidet ein offener Kauf
-- dieses Gegenstands (id, net): dann ist es ein Kauf, sonst eine zurueckgekommene Auktion.
function M.LetterKind(l, id, net)
    if type(l) ~= "table" then return nil end
    local inv = l.invoice and l.invoice.kind
    if inv == "buyer" then return "won" end
    if inv == "seller" then return "sold" end
    if l.ah then
        local k = M.AHLetterKind(l.subject)
        if k == "won" or k == "sold" or k == "outbid" then return k end
        if k == "expired" or k == "cancelled" then return "return" end
        if next(l.items or {}) then
            if id and M.FindPurchase(id, math.max(1, net or 1), l) then return "won" end
            return "return"
        end
        return "ah"
    end
    return "mail"
end

-- Aus der Post genommen (mitgelesen): Warteschlange, damit bei "Alle öffnen" jeder Betrag/Gegenstand
-- seinen eigenen Brief bekommt
M.takes = {}
M.TAKE_KEEP = 30
function M.PushTake(kind, letter)
    if type(letter) ~= "table" then return end
    M.takes[#M.takes + 1] = { t = Now(), kind = kind, letter = letter }
end

local function PurgeTakes()
    local keep = {}
    for _, e in ipairs(M.takes) do if Now() - e.t <= M.TAKE_KEEP then keep[#keep + 1] = e end end
    M.takes = keep
end

-- Gibt es einen genommenen Brief mit genau diesem Betrag?
function M.HasExactTake(m)
    for _, e in ipairs(M.takes) do
        if e.kind == "money" and e.letter.money == m then return true end
    end
    return false
end

-- Brief fuer einen Goldbetrag: gleicher Betrag zuerst, sonst der aelteste; wird verbraucht
function M.TakeMoney(m)
    PurgeTakes()
    local pick
    for i, e in ipairs(M.takes) do
        if e.kind == "money" and e.letter.money == m then pick = i; break end
    end
    if not pick then for i, e in ipairs(M.takes) do if e.kind == "money" then pick = i; break end end end
    if not pick then return nil end
    return table.remove(M.takes, pick).letter
end

-- Mehrere Briefe, deren Gold zusammen genau m ergibt (ab 0.5.1: "Alle öffnen" holte zwei Erloese so schnell,
-- dass das Spiel nur EINE Goldaenderung meldete - 167 + 3590 = 3757). Sucht unter den aeltesten 8 Briefen
-- Kombinationen aus 2 bis 4 Briefen; Treffer werden aus der Warteschlange genommen. Rueckgabe: Liste oder nil
M.SPLIT_MAX, M.SPLIT_LOOK = 4, 8
function M.TakeMoneySplit(m)
    PurgeTakes()
    local idx = {}
    for i, e in ipairs(M.takes) do
        if e.kind == "money" and Num(e.letter.money) and e.letter.money > 0 then idx[#idx + 1] = i end
        if #idx >= M.SPLIT_LOOK then break end
    end
    local found
    local function Try(start, left, chosen)
        if found then return end
        if left == 0 and #chosen >= 2 then found = { unpack(chosen) }; return end
        if #chosen >= M.SPLIT_MAX or left <= 0 then return end
        for j = start, #idx do
            local v = M.takes[idx[j]].letter.money
            if v <= left then
                chosen[#chosen + 1] = idx[j]
                Try(j + 1, left - v, chosen)
                chosen[#chosen] = nil
                if found then return end
            end
        end
    end
    Try(1, m, {})
    if not found then return nil end
    local letters = {}
    table.sort(found, function(a, b) return a > b end)
    for _, i in ipairs(found) do table.insert(letters, 1, table.remove(M.takes, i).letter) end
    return letters
end

-- Grund fuer Gold aus einem Brief: Art, Zusatz, Infos aus der Rechnung
function M.LetterMoney(l)
    local kind = M.LetterKind(l)
    if kind == "sold" then
        local inv = l.invoice
        local info = inv and { id = inv.item and ns.Inventory.FindItemID(inv.item), q = inv.count or 1, cut = inv.cut, gross = inv.gross } or nil
        if not inv then
            -- Rechnung noch nicht geladen (ab 0.6): Gegenstand aus dem Betreff ("Auktion erfolgreich: Name")
            local name = (Str(l.subject) or ""):match(":%s*(.-)%s*$")
            local id = name and name ~= "" and ns.Inventory.FindItemID(name) or nil
            if id then return "ahsold", name, { id = id, guess = true } end
        end
        return "ahsold", inv and inv.item and (inv.item .. ((inv.count or 1) > 1 and (" ×" .. inv.count) or "")) or nil, info
    end
    if kind == "outbid" then return "ahbuy", L.MV_X_OUTBID end
    if l.ah then return "ahsold" end
    local own = M.OwnChar(l.sender)
    if own and own ~= ns.CharName() then return "twink", own end
    return "mail", l.sender
end

-- Brief, aus dem ein Gegenstand genommen wurde (bleibt fuer weitere Gegenstaende desselben Briefes)
function M.TakeItem(id)
    PurgeTakes()
    for _, e in ipairs(M.takes) do
        if e.kind == "item" and e.letter.items and e.letter.items[id] then return e.letter end
    end
    return nil
end

-- (bis 0.7.1, ab 0.7.2 nicht mehr benutzt: Post zaehlt nicht zum Bestand) Unterwegs zwischen Postfach und Taschen:
-- n > 0 = aus der Post weg, noch nicht in den Taschen; n < 0 = in den Taschen, Post noch nicht weniger
M.transit = {}
M.TRANSIT_KEEP = 30

local function PurgeTransit()
    for id, tr in pairs(M.transit) do
        if Now() - tr.t > M.TRANSIT_KEEP or tr.n == 0 then
            -- in den Taschen angekommen, aber das Postfach wurde nicht mehr gelesen: dort abziehen
            if tr.n < 0 then ns.Inventory.RemoveFromPlace(ns.Inventory.Char(), "mail", id, -tr.n) end
            M.transit[id] = nil
        end
    end
end

-- Teil einer Bewegung, der nur zwischen Postfach und Taschen unterwegs ist; Rueckgabe: verbleibende Menge
function M.MailTransit(id, net, d)
    if not M.IsOpen("mail") then return net end
    local dm = d.mail or 0
    local tr = M.transit[id] or { n = 0 }
    local a = math.abs(net)
    if net < 0 and dm < 0 then
        if tr.n < 0 then local c = math.min(a, -tr.n); tr.n = tr.n + c; a = a - c end
        if a > 0 and M.TakeItem(id) then tr.n = tr.n + a; a = 0 end
        net = -a
    elseif net > 0 and dm <= 0 then
        if tr.n > 0 then local c = math.min(a, tr.n); tr.n = tr.n - c; a = a - c end
        local mailHas = ns.Inventory.Char().places.mail
        mailHas = type(mailHas) == "table" and type(mailHas.items) == "table" and (mailHas.items[id] or 0) or 0
        if a > 0 and M.TakeItem(id) and mailHas >= a then tr.n = tr.n - a; a = 0 end
        net = a
    else
        return net
    end
    tr.t = Now()
    M.transit[id] = tr.n ~= 0 and tr or nil
    return net
end

-- Hat der Gegenstand einen Benutzen-Effekt (Trank, Essen, Verband ...)?
local function Usable(id)
    local CI = rawget(_G, "C_Item")
    local fn = (CI and CI.GetItemSpell) or rawget(_G, "GetItemSpell")
    if type(fn) ~= "function" then return false end
    local ok, name = pcall(fn, id)
    return ok and name ~= nil
end

-- Grund fuer eine Gegenstands-Bewegung (net = Stueck, + Zugang, - Abgang; d = Differenzen je Ort)
function M.ItemReason(id, net, d)
    local R = M.Recent
    -- aus der Post (Brief war noch nicht bekannt) oder neue Post beim Oeffnen des Postfachs
    if net > 0 and (d.mail or 0) > 0 then
        local l = LetterFor(id)
        local kind = M.LetterKind(l, id, net)
        if kind == "won" then return "ahbuy", nil, l end
        if kind == "return" then return nil, "ahreturn", l end
        local own = l and M.OwnChar(l.sender)
        if own and own ~= ns.CharName() then return "twink", own end
        return "mail", l and l.sender, l
    end
    local del = R("delete", 10)
    if net < 0 and del and (del.id == nil or del.id == id) then return "destroy" end
    if M.IsOpen("merchant") then
        if net < 0 then return "vendor" end
        if R("buyback") then return "buyback" end
        return "vendor"
    end
    if M.IsOpen("trade") then return "trade", M.tradePartner end
    if M.IsOpen("mail") then
        local send = R("send", 10)
        if send and send.used then send = nil end   -- ab 0.14: Brief schon ueber den Entwurf verbucht
        if net < 0 and send then
            local own = M.OwnChar(send.to)
            if own and own ~= ns.CharName() then return "twink", own end
            return "mail", send.to
        end
        -- ab 0.14: an einen Brief gehaengt, noch nicht abgeschickt -> Briefentwurf (erst SendMail verbucht)
        local use = R("use", 10)
        if net < 0 and M.open.mail and not (use and (use.id == nil or use.id == id)) then return nil, "draft" end
        if net > 0 and (M.draft[id] or 0) > 0 then return nil, "undraft" end
        local l = net > 0 and (M.TakeItem(id) or LetterFor(id)) or nil
        if l then
            local kind = M.LetterKind(l, id, net)
            if kind == "won" then return "ahbuy", nil, l end
            if kind == "return" then return nil, "ahreturn", l end
            local own = M.OwnChar(l.sender)
            if own and own ~= ns.CharName() then return "twink", own end
            return "mail", l.sender, l
        end
    end
    if M.IsOpen("auction") then
        if net < 0 and R("posted", 15) then return "posted" end
        if net > 0 then return "ahbuy" end
    end
    if R("craft", 15) or (M.IsOpen("skill") and R("cast", 3)) then
        local c = R("craft", 15)
        return "craft", c and c.name
    end
    if R("quest", 5) or M.IsOpen("quest") then return "quest" end
    if net > 0 and (M.IsOpen("loot") or R("loot", 3)) then return "loot" end
    if net < 0 then
        local use = R("use", 10)
        if (use and (use.id == nil or use.id == id)) or Usable(id) then return "use" end
    end
    return "other"
end

-- Grund fuer eine Gold-Bewegung
function M.MoneyReason(m)
    local R = M.Recent
    if M.IsOpen("merchant") then
        if m > 0 then return "vendor" end
        if R("buyback") then return "buyback" end
        if R("buy") then return "vendor" end
        return "repair"
    end
    if M.IsOpen("auction") then
        if m < 0 then
            -- ab 0.14: das neueste Ereignis entscheidet (Kauf kurz nach dem Einstellen ist keine Gebuehr und
            -- umgekehrt), ein Kauf gilt nur fuer eine Goldaenderung
            local buy, post, cancel = R("ahpurchase", 10), R("posted", 15), R("cancel", 15)
            if buy and buy.used then buy = nil end
            if cancel and cancel.used then cancel = nil end
            local best, bt = nil, -math.huge
            if buy and buy.t >= bt then best, bt = "buy", buy.t end
            if post and post.t > bt then best, bt = "post", post.t end
            if cancel and cancel.t > bt then best, bt = "cancel", cancel.t end
            if best == "buy" then buy.used = true; return "ahbuy" end
            if best == "post" then return "ahfee" end
            if best == "cancel" then cancel.used = true; return "ahfee", L.MV_X_CANCEL end
            return "ahbuy"
        end
        return "other"
    end
    if M.IsOpen("mail") then
        local l = m > 0 and M.TakeMoney(m) or nil
        if l then return M.LetterMoney(l) end
        -- Nachnahme bezahlt (ab 0.7)
        if m < 0 then
            for _, t in ipairs(M.takes) do
                if t.kind == "item" and t.letter.cod == -m then return "mail", t.letter.sender, { cod = true } end
            end
        end
        local send = R("send", 10)
        if m < 0 and send then
            local own = M.OwnChar(send.to)
            if own and own ~= ns.CharName() and (send.money or 0) > 0 then return "twink", own end
            return "mail", send.to
        end
    end
    if M.IsOpen("trade") then return "trade", M.tradePartner end
    if M.IsOpen("taxi") or R("taxi", 10) then return "taxi" end
    if M.IsOpen("trainer") or R("trainer") then return "trainer" end
    if R("quest", 5) or M.IsOpen("quest") then return "quest" end
    if m > 0 and (M.IsOpen("loot") or R("loot", 3) or R("lootmoney", 3)) then return "loot" end
    return "other"
end

-- Verkaufspreis beim Haendler (Kupfer je Stueck) oder nil
local function SellPrice(id)
    local CI = rawget(_G, "C_Item")
    local fn = (CI and CI.GetItemInfo) or rawget(_G, "GetItemInfo")
    if type(fn) ~= "function" then return nil end
    local ok, _, _, _, _, _, _, _, _, _, _, price = pcall(fn, id)
    if ok and Num(price) and price > 0 then return price end
    return nil
end

M.SellPrice = SellPrice

-- Gold vom Haendler dem passenden Gegenstand zuordnen (gleicher Stapel: Betrag = Preis x Stueck)
local function AttachVendorMoney(list, m)
    if #list == 0 then return false end
    if m > 0 then
        for _, v in ipairs(list) do
            if v.out and v.price and v.left > 0 and m % v.price == 0 and m / v.price <= v.left then
                v.left = v.left - m / v.price
                v.e.m = (v.e.m or 0) + m
                return true
            end
        end
    end
    -- nur ein Gegenstand in passender Richtung: ganzer Betrag dazu
    local only, count = nil, 0
    for _, v in ipairs(list) do
        if v.out == (m > 0) then only = v; count = count + 1 end
    end
    if count == 1 then only.e.m = (only.e.m or 0) + m; return true end
    -- mehrere Gegenstaende (ab 0.6, z. B. mehrere Stapel gekauft): Betrag nach Haendlerwert aufteilen
    local parts, sum = {}, 0
    for _, v in ipairs(list) do
        if v.out == (m > 0) then
            local w = (SellPrice(v.e.id) or 1) * math.max(1, math.abs(v.e.n or 1))
            parts[#parts + 1] = { v = v, w = w }
            sum = sum + w
        end
    end
    if #parts < 2 or sum <= 0 then return false end
    local left, big = m, parts[1]
    for _, p in ipairs(parts) do
        local share = (m > 0 and math.floor or math.ceil)(m * p.w / sum)
        p.v.e.m = (p.v.e.m or 0) + share
        p.v.e.split = true
        left = left - share
        if p.w > big.w then big = p end
    end
    big.v.e.m = big.v.e.m + left   -- Rundungsrest
    return true
end

---------------------------------------------------------------------------
-- Zuordnen (ab 0.6, bekannte Luecken aus 0.5)
---------------------------------------------------------------------------
M.MATCH_DAYS = 7

-- Erloes ohne Gegenstand (Rechnung beim Holen noch nicht geladen): passenden Verkauf suchen - Eintrag
-- "Auktion verkauft" (Gegenstand weg, Preis je Stueck aus der Auktionsliste) desselben Charakters, noch ohne
-- Erloes, Betrag passt zu Preis x Stueck - 5 % (+ zurueckgezahlte Einstellgebuehr). id = nur dieser Gegenstand.
function M.MatchSale(e, id)
    if type(e) ~= "table" or not Num(e.m) or e.m <= 0 then return false end
    local list = M.List()
    local from = (e.t or time()) - M.MATCH_DAYS * 86400
    local best, bestDiff
    for i = #list, math.max(1, #list - M.MERGE_LOOKBACK), -1 do
        local s = list[i]
        if (s.t or 0) < from then break end
        if s ~= e and s.k == "ahsold" and s.c == e.c and s.id and (s.n or 0) < 0 and not s.paid and Num(s.p) and (not id or s.id == id) then
            local gross = s.p * -s.n
            local ratio = gross > 0 and e.m / (gross * 0.95) or 0
            if ratio >= 0.97 and ratio <= 1.5 then
                local diff = math.abs(ratio - 1)
                if not best or diff < bestDiff then best, bestDiff = s, diff end
            end
        end
    end
    if not best then
        -- nur der Name war bekannt: eintragen ohne Menge
        if id and not e.id then e.id = id; M.Changed(); return true end
        return false
    end
    best.paid = true
    e.id, e.q, e.gross, e.est = best.id, -best.n, math.floor(best.p * -best.n + 0.5), true
    e.cut = e.cut or math.floor(e.gross * 0.05 + 0.5)
    M.Changed()
    return true
end

-- Auktion gekauft: Gegenstand aus der Post an den Kauf (Gold beim Kauf) haengen statt eigener Zeile.
-- Kauf mit bekanntem Gegenstand (StartCommoditiesPurchase mitgelesen) oder Betrag = Rechnung des Briefes.
function M.FindPurchase(id, net, letter)
    local list = M.List()
    local now = time()
    local inv = type(letter) == "table" and letter.invoice or nil
    -- ab 0.14.1 der groessere Wert: Forever schreibt bei Massenware teils die Menge ins Feld Sofortkauf
    local paid = inv and math.max(inv.bid or 0, inv.buyout or 0) or nil
    if paid == 0 then paid = nil end
    for i = #list, math.max(1, #list - M.MERGE_LOOKBACK), -1 do
        local e = list[i]
        if (e.t or 0) < now - M.MATCH_DAYS * 86400 then break end
        if e.k == "ahbuy" and e.c == ns.CharName() and Num(e.m) and e.m < 0 then
            local room = not e.q or (e.n or 0) + net <= e.q
            if e.id == id and room and (e.n or 0) >= 0 then return e end
            if not e.id and not e.n and paid and -e.m == paid then return e end
        end
    end
    return nil
end

-- Verkauf aus der Rechnung (ab 0.14): Die Rechnung nennt Gegenstand und Menge, die Ware ist damit weg.
-- Hat die Auktionsliste den Verkauf schon als Abgang gemeldet (Zeile "Auktion verkauft" ohne Erloes), bleibt es
-- dabei. Sonst traegt die Zeile mit dem Erloes auch den Abgang (n), und der Ort "Auktionen" wird kleiner.
function M.SaleItems(e, id, q)
    if type(e) ~= "table" or not Num(q) or q <= 0 then return end
    local list = M.List()
    local from = (e.t or time()) - M.MATCH_DAYS * 86400
    for i = #list, math.max(1, #list - M.MERGE_LOOKBACK), -1 do
        local s = list[i]
        if (s.t or 0) < from then break end
        if s ~= e and s.k == "ahsold" and s.c == e.c and s.id == id and (s.n or 0) < 0 and not s.m and not s.paid then
            s.paid = true
            return
        end
    end
    e.n = -q
    if e.c == ns.CharName() then ns.Inventory.RemoveFromPlace(ns.Inventory.Char(), "auctions", id, q) end
    M.Changed()
end

-- Auktionsliste meldet einen Verkauf (ab 0.14): schon ueber die Rechnung verbucht? Rueckgabe: noch offene Menge
function M.ClaimSale(id, cnt)
    local list = M.List()
    local me = ns.CharName()
    local from = time() - M.MATCH_DAYS * 86400
    for i = #list, math.max(1, #list - M.MERGE_LOOKBACK), -1 do
        if cnt <= 0 then break end
        local s = list[i]
        if (s.t or 0) < from then break end
        if s.k == "ahsold" and s.c == me and s.id == id and (s.n or 0) < 0 and Num(s.m) and s.m > 0 then
            local free = -s.n - (s.claimed or 0)
            if free > 0 then
                local k = math.min(free, cnt)
                s.claimed = (s.claimed or 0) + k
                cnt = cnt - k
            end
        end
    end
    return cnt
end

-- Sondereinnahme (ab 0.14.2, Wunsch KarloDerBaer): Auktionen, die beim Neustart des Buchs schon liefen, und
-- Verkaufsbriefe, die schon im Briefkasten lagen, gehoeren zu keinem erfassten Einstellen. Ihr Erloes ist eine
-- Sondereinnahme wie eine Bestandsaufnahme (kein Handelsgewinn). Gemerkt beim Neustart in
-- realms[Realm].pre[Charakter] = { auctions = { [itemID] = Stueck }, sold = { [Name] = Stueck } }.
function M.PreOf(c)
    local r = ns.Inventory.RealmData()
    local p = type(r.pre) == "table" and r.pre[c or ns.CharName()]
    return type(p) == "table" and p or nil
end

-- Gehoert ein Verkauf zur Vormerkung? consume = abziehen. Rueckgabe true/false
function M.PreSale(c, id, name, q, consume)
    local p = M.PreOf(c)
    if not p then return false end
    q = q or 1
    if name and type(p.sold) == "table" and (p.sold[name] or 0) > 0 then
        if consume then p.sold[name] = math.max(0, p.sold[name] - q); if p.sold[name] == 0 then p.sold[name] = nil end end
        return true
    end
    if id and type(p.auctions) == "table" and (p.auctions[id] or 0) > 0 then
        if consume then p.auctions[id] = math.max(0, p.auctions[id] - q); if p.auctions[id] == 0 then p.auctions[id] = nil end end
        return true
    end
    return false
end

-- Auktion von vor dem Neustart kommt zurueck: Vormerkung abziehen (neu eingestellt zaehlt sie normal)
function M.PreReturn(id, n)
    local p = M.PreOf()
    if p and type(p.auctions) == "table" and id and (p.auctions[id] or 0) > 0 then
        p.auctions[id] = math.max(0, p.auctions[id] - n)
        if p.auctions[id] == 0 then p.auctions[id] = nil end
    end
end

-- Erloes pruefen und ggf. als Sondereinnahme markieren (e.sp)
function M.MarkSpecial(e, name)
    if type(e) ~= "table" or e.k ~= "ahsold" or not Num(e.m) or e.m <= 0 then return end
    if not e.id and not name then e.sp = true; return end   -- keinem Gegenstand zuzuordnen
    if M.PreSale(e.c, e.id, name, e.q or (e.n and -e.n) or 1, true) then e.sp = true end
end

-- Briefentwurf (ab 0.14): angehaengte Gegenstaende, noch nicht abgeschickt. [itemID] = Stueck
M.draft = {}

-- Abgeschickt: Entwurf verbuchen (an Twink = Umbuchung und beim Twink unterwegs, sonst Post an andere)
function M.SendDraft(to)
    local own = M.OwnChar(to)
    if own == ns.CharName() then own = nil end
    for id, n in pairs(M.draft) do
        if n > 0 then
            if own then
                M.Add("twink", id, -n, nil, own)
                ns.Inventory.AddToPlace(ns.Inventory.Char(own), "transit", id, n)
            else
                M.Add("mail", id, -n, nil, Str(to))
            end
        end
    end
    M.draft = {}
end

-- Postfach zu, Entwurf nicht abgeschickt und nicht zurueck: Abgang wie ohne Zusammenhang
function M.DropDraft()
    if M.pending then M.Flush() end
    for id, n in pairs(M.draft) do
        if n > 0 then M.Add(Usable(id) and "use" or "other", id, -n) end
    end
    M.draft = {}
end

-- Gesammelte Aenderungen verbuchen
function M.Flush()
    local b = M.pending
    M.pending = nil
    if not b then return end
    local vendorList = {}
    for id, d in pairs(b.items) do
        -- Post zaehlt nicht zum Bestand (ab 0.7.2): Aenderungen im Briefkasten sind keine Bewegung,
        -- erst das Nehmen (Taschen +) ist ein Zugang
        local net = 0
        for place, v in pairs(d) do if place ~= "mail" then net = net + v end end
        if net ~= 0 then
            local k, x, letter = M.ItemReason(id, net, d)
            if k == nil and x == "draft" then
                M.draft[id] = (M.draft[id] or 0) - net        -- an einen Brief gehaengt (ab 0.14)
            elseif k == nil and x == "undraft" then
                local back = math.min(net, M.draft[id] or 0)   -- vom Brief zurueck in die Tasche
                M.draft[id] = (M.draft[id] or 0) - back
                if M.draft[id] <= 0 then M.draft[id] = nil end
                if net - back > 0 then M.Add("other", id, net - back) end
            elseif k == nil and x == "ahreturn" then
                -- Auktion kommt per Post zurueck: Gegenstand war schon als "Auktion" im Bestand (Umbuchung);
                -- fuer die Verkaufsquote als "zurueck" vermerkt
                ns.Inventory.RemoveFromPlace(ns.Inventory.Char(), "auctions", id, net)
                M.PreReturn(id, net)
                local why = letter and M.AHLetterKind(letter.subject)
                M.Add("ahreturn", id, net, nil, why == "cancelled" and L.MV_X_CANCEL or (why == "expired" and L.MV_X_EXPIRED or nil))
            elseif k == "posted" then
                M.Add("posted", id, net)
                M.Note("postedItem", { id = id })   -- Einstellgebuehr diesem Gegenstand zurechnen (ab 0.7)
            elseif k == "twink" then
                M.Add("twink", id, net, nil, x)
                -- an einen Twink geschickt: bis zum Abholen bei ihm "unterwegs"; abgeholt: dort wieder weg
                if net < 0 and x then ns.Inventory.AddToPlace(ns.Inventory.Char(x), "transit", id, -net)
                elseif net > 0 then ns.Inventory.RemoveFromPlace(ns.Inventory.Char(), "transit", id, net) end
            elseif k == "ahbuy" and net > 0 and M.FindPurchase(id, net, letter) then
                local e = M.FindPurchase(id, net, letter)
                e.id, e.n = id, (e.n or 0) + net
                M.Changed()
            else
                local e = M.Add(k or "other", id, net, nil, x)
                -- Nachnahme: bezahlter Betrag sind die Kosten des Erhaltenen (ab 0.7)
                if e and k == "mail" and net > 0 and type(letter) == "table" and Num(letter.cod) then e.paid = letter.cod end
                if (k == "vendor" or k == "buyback") and e then
                    vendorList[#vendorList + 1] = { e = e, out = net < 0, left = math.abs(net), price = net < 0 and SellPrice(id) or nil }
                end
            end
            ns.Inventory.ItemInfo(id)
        end
    end
    for _, m in ipairs(b.money) do
        -- Gold aus mehreren Briefen auf einmal: je Brief ein Eintrag (ab 0.5.1)
        local split = m > 0 and M.IsOpen("mail") and not M.HasExactTake(m) and M.TakeMoneySplit(m) or nil
        if split then
            for _, l in ipairs(split) do
                local k, x, info = M.LetterMoney(l)
                local e = M.Add(k, info and info.id, nil, l.money, x)
                if e and info then e.q, e.cut, e.gross = info.q, info.cut, info.gross end
                if e and k == "ahsold" and (not info or info.guess) then M.MatchSale(e, info and info.id) end
                if e and k == "ahsold" then M.MarkSpecial(e, l.invoice and l.invoice.item) end
                if e and k == "ahsold" and info and info.id and not info.guess then M.SaleItems(e, info.id, info.q or 1) end
            end
            m = 0
        end
        local k, x, info
        if m ~= 0 then k, x, info = M.MoneyReason(m) end
        if m == 0 then
            -- schon je Brief verbucht
        elseif (k == "vendor" or k == "buyback") and AttachVendorMoney(vendorList, m) then
            M.Changed()
        else
            local e = M.Add(k, info and info.id, nil, m, x)
            -- Verkauf im Auktionshaus: Menge und Anteil aus der Rechnung (Buch, Verkaufsquote)
            if e and info then e.q, e.cut, e.gross = info.q, info.cut, info.gross end
            -- ohne Rechnung: Gegenstand und Menge aus dem passenden Verkauf (ab 0.6)
            if e and k == "ahsold" and m > 0 and (not info or info.guess) then M.MatchSale(e, info and info.id) end
            if e and k == "ahsold" and m > 0 then M.MarkSpecial(e, x and x:match("^(.-)%s*×") or x) end
            -- Rechnung mit Gegenstand und Menge (ab 0.14): die Ware ist damit sicher weg
            if e and k == "ahsold" and m > 0 and info and info.id and not info.guess then M.SaleItems(e, info.id, info.q or 1) end
            -- Einstellgebuehr / Abbruchkosten: Gegenstand dazu (ab 0.7, fuer Kosten und Handelsgewinn)
            if e and k == "ahfee" and not e.id then
                local src = (x == L.MV_X_CANCEL) and M.Recent("cancel", 15) or M.Recent("postedItem", 15)
                if src and Num(src.id) then e.id = src.id end
            end
            -- Auktion gekauft: Gegenstand des mitgelesenen Kaufs (ab 0.6), der Gegenstand aus der Post kommt dazu
            -- ab 0.14 nur einmal und hoechstens 60 Sekunden alt (vorher 120, konnte einem anderen Kauf zufallen)
            if e and k == "ahbuy" and m < 0 then
                local b = M.Recent("ahbuyitem", 60)
                if b and Num(b.id) and not b.used then
                    e.id, e.q = b.id, Num(b.qty) and b.qty or nil
                    b.used = true
                end
            end
        end
        if k == "twink" and m < 0 and x then
            local send = M.Recent("send", 10)
            local amount = send and send.money or 0
            if amount > 0 then
                local c = ns.Inventory.Char(x)
                local p = c.places.transit
                if type(p) ~= "table" then p = { t = time(), items = {} }; c.places.transit = p end
                p.money = (p.money or 0) + amount
            end
        elseif k == "twink" and m > 0 then
            -- Gold vom Twink abgeholt: nicht mehr unterwegs
            local p = ns.Inventory.Char().places.transit
            if type(p) == "table" and Num(p.money) then p.money = math.max(0, p.money - m) end
        end
    end
end

---------------------------------------------------------------------------
-- Auktionen: laufende weniger -> verkauft oder beendet (zurueck per Post); mehr -> eingestellt (kein Eintrag,
-- das wurde schon beim Abgang aus den Taschen als "Auktion eingestellt" verbucht)
---------------------------------------------------------------------------
function M.OnAuctions(old, new, info)
    local sold = info and info.soldItems or {}
    local oldSold = info and info.oldSold or {}
    for id, n in pairs(old) do
        local d = (new[id] or 0) - n
        if d < 0 then
            local s = (sold[id] or 0) - (oldSold[id] or 0)
            local soldNow = math.min(-d, math.max(0, s))
            if soldNow > 0 then soldNow = M.ClaimSale(id, soldNow) end   -- ab 0.14: Rechnung war schon da
            if soldNow > 0 then
                local e = M.Add("ahsold", id, -soldNow)
                local g = info and info.soldGross and info.soldGross[id]
                if e and Num(g) and (sold[id] or 0) > 0 then e.p = g / sold[id] end   -- Preis je Stueck (ab 0.6)
            end
            -- nicht verkauft (abgelaufen/abgebrochen): kein Eintrag, der Brief mit dem Gegenstand wird als
            -- "Auktion zurück" verbucht (ab 0.4; vorher "Auktion beendet")
        end
    end
end

---------------------------------------------------------------------------
-- Ereignisse und mitgelesene Aufrufe
---------------------------------------------------------------------------
M.hooked = {}
local function Hook(path, fn)
    if not hooksecurefunc then return false end
    if M.hooked[path] then return true end   -- ab 0.14: jeder Aufruf nur einmal mitgelesen (Init darf erneut laufen)
    local tblName, key = path:match("^([%w_]+)%.([%w_]+)$")
    local ok = pcall(function()
        if tblName then
            local t = rawget(_G, tblName)
            if type(t) == "table" and type(t[key]) == "function" then hooksecurefunc(t, key, fn) else error("fehlt") end
        else
            if type(rawget(_G, path)) ~= "function" then error("fehlt") end
            hooksecurefunc(path, fn)
        end
    end)
    if ok then M.hooked[path] = true end
    return ok
end
M.Hook = Hook

-- Gegenstand am Mauszeiger (fuer Zerstoeren)
local function CursorItem()
    local fn = rawget(_G, "GetCursorInfo")
    if type(fn) ~= "function" then return nil end
    local ok, kind, id = pcall(fn)
    if ok and kind == "item" and Num(id) then return id end
    return nil
end

local function ContainerItemID(bag, slot)
    local Ct = rawget(_G, "C_Container")
    if not Ct or not Ct.GetContainerItemInfo then return nil end
    local ok, info = pcall(Ct.GetContainerItemInfo, bag, slot)
    if ok and type(info) == "table" and Num(info.itemID) then return info.itemID end
    return nil
end

local function Ev(event, fn) pcall(mod.RegisterEvent, mod, event, function(...) mod:Call("Bewegungen", fn, ...) end) end

-- Fenster-Typen der allgemeinen Meldung (Enum.PlayerInteractionType, Werte wie in Retail als Rueckfall)
M.PIM = { Merchant = { 5, "merchant" }, MailInfo = { 17, "mail" }, Banker = { 8, "bank" }, Auctioneer = { 21, "auction" },
          TaxiNode = { 3, "taxi" }, Trainer = { 7, "trainer" }, TradePartner = { 1, "trade" } }

local function PimWindow(kind)
    local E = rawget(_G, "Enum")
    local t = type(E) == "table" and E.PlayerInteractionType or nil
    for name, v in pairs(M.PIM) do
        local id = type(t) == "table" and t[name] or v[1]
        if kind == id then return v[2] end
    end
    return nil
end

function M.Init()
    M.InitEvents()
    M.InitHooks()
end

-- Ereignisse nur einmal anmelden
function M.InitEvents()
    if M.eventsDone then return end
    M.eventsDone = true
    -- Fenster
    Ev("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind) local w = PimWindow(kind); if w then M.Open(w) end end)
    Ev("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, kind)
        local w = PimWindow(kind)
        if w == "mail" then M.CloseMail() elseif w then M.Close(w) end
    end)
    Ev("MERCHANT_SHOW", function() M.Open("merchant") end)
    Ev("MERCHANT_CLOSED", function() M.Close("merchant") end)
    Ev("MAIL_SHOW", function() M.Open("mail") end)
    Ev("MAIL_CLOSED", function() M.CloseMail() end)
    Ev("AUCTION_HOUSE_SHOW", function() M.Open("auction") end)
    Ev("AUCTION_HOUSE_CLOSED", function() M.Close("auction") end)
    Ev("TAXIMAP_OPENED", function() M.Open("taxi") end)
    Ev("TAXIMAP_CLOSED", function() M.Close("taxi") end)
    Ev("TRAINER_SHOW", function() M.Open("trainer") end)
    Ev("TRAINER_CLOSED", function() M.Close("trainer") end)
    Ev("TRADE_SKILL_SHOW", function() M.Open("skill") end)
    Ev("TRADE_SKILL_CLOSE", function() M.Close("skill") end)
    Ev("LOOT_OPENED", function() M.Open("loot") end)
    Ev("LOOT_CLOSED", function() M.Close("loot") end)
    Ev("QUEST_COMPLETE", function() M.Open("quest") end)
    Ev("QUEST_FINISHED", function() M.Close("quest") end)
    Ev("TRADE_SHOW", function()
        M.Open("trade")
        local ok, name = pcall(UnitName, "NPC")
        M.tradePartner = ok and Str(name) or nil
    end)
    Ev("TRADE_CLOSED", function() M.Close("trade") end)
    -- Ereignisse
    Ev("QUEST_TURNED_IN", function() M.Note("quest") end)
    Ev("AUCTION_HOUSE_AUCTION_CREATED", function() M.Note("posted") end)
    Ev("AUCTION_CANCELED", function(_, auctionID)
        local map = ns.Inventory.auctionItems
        M.Note("cancel", { id = map and Num(auctionID) and map[auctionID] or nil })
    end)
    Ev("COMMODITY_PURCHASE_SUCCEEDED", function() M.Note("ahpurchase") end)
    Ev("AUCTION_HOUSE_PURCHASE_COMPLETED", function() M.Note("ahpurchase") end)
    Ev("CHAT_MSG_LOOT", function(_, msg)
        msg = Str(msg)
        if not msg then return end
        local pat = rawget(_G, "LOOT_ITEM_SELF") or rawget(_G, "LOOT_ITEM_SELF_MULTIPLE")
        local prefix = type(pat) == "string" and pat:match("^(.-)%%") or nil
        if prefix and prefix ~= "" and msg:sub(1, #prefix) == prefix then M.Note("loot") end
    end)
    Ev("CHAT_MSG_MONEY", function() M.Note("lootmoney") end)
    Ev("UNIT_SPELLCAST_SUCCEEDED", function(_, unit)
        if unit ~= "player" then return end
        M.Note("cast")
        local c = M.ctx.craft
        if c and M.open.skill then c.t = Now() end   -- Herstellen laeuft noch (mehrere Stueck)
    end)
end

-- mitgelesene Aufrufe (hooksecurefunc: nach dem Aufruf, aendert nichts). Ab 0.14 erneut aufrufbar: Fehlende
-- Funktionen (z. B. aus spaet geladenen Teilen des Spiels) werden dann nachgeholt, vorhandene nicht doppelt.
function M.InitHooks()
    Hook("BuyMerchantItem", function() M.Note("buy") end)
    Hook("BuybackItem", function() M.Note("buyback") end)
    Hook("RepairAllItems", function() M.Note("repair") end)
    Hook("TakeTaxiNode", function() M.Note("taxi") end)
    Hook("BuyTrainerService", function() M.Note("trainer") end)
    Hook("C_Container.PickupContainerItem", function(bag, slot)
        local id = CursorItem()
        if id then M.Note("cursor", { id = id }) end
    end)
    Hook("DeleteCursorItem", function()
        local c = M.Recent("cursor", 60)
        M.Note("delete", { id = c and c.id })
    end)
    Hook("C_Container.UseContainerItem", function(bag, slot)
        local id = ContainerItemID(bag, slot)
        M.Note("use", { id = id })
    end)
    Hook("C_TradeSkillUI.CraftRecipe", function(recipeID, count)
        local name
        local TS = rawget(_G, "C_TradeSkillUI")
        if TS and TS.GetRecipeInfo and Num(recipeID) then
            local ok, info = pcall(TS.GetRecipeInfo, recipeID)
            if ok and type(info) == "table" then name = Str(info.name) end
        end
        M.Note("craft", { recipe = recipeID, count = count, name = name })
    end)
    Hook("SendMail", function(to)
        local money = 0
        local fn = rawget(_G, "GetSendMailMoney")
        if type(fn) == "function" then
            local ok, v = pcall(fn)
            if ok and Num(v) then money = v end
        end
        local note = M.Note("send", { to = Str(to), money = money })
        if M.pending then M.Flush() end
        -- ab 0.14: angehaengte Gegenstaende jetzt verbuchen. Danach gilt der Brief als erledigt, was jetzt noch die
        -- Tasche verlaesst, gehoert zum naechsten Brief (Entwurf).
        if next(M.draft) then M.SendDraft(to); note.used = true end
    end)
    -- Post nehmen: Brief merken (Index aus dem letzten Lesen des Postfachs). "Alle öffnen" ruft AutoLootMailItem
    -- (Gegenstaende und Gold eines Briefes) bzw. TakeInboxMoney je Brief auf.
    local function Letter(i) return Num(i) and ns.Inventory.letters and ns.Inventory.letters[i] or nil end
    Hook("TakeInboxItem", function(i) M.PushTake("item", Letter(i)) end)
    Hook("TakeInboxMoney", function(i) M.PushTake("money", Letter(i)) end)
    Hook("AutoLootMailItem", function(i)
        local l = Letter(i)
        if l and next(l.items or {}) then M.PushTake("item", l) end
        if l and (l.money or 0) > 0 then M.PushTake("money", l) end
    end)
    Hook("AcceptTrade", function() M.Note("tradeaccept") end)
    -- Kauf von Massenware: Gegenstand und Menge (ab 0.6, fuer "Auktion gekauft" in einer Zeile)
    Hook("C_AuctionHouse.StartCommoditiesPurchase", function(itemID, qty) M.Note("ahbuyitem", { id = itemID, qty = qty }) end)
    -- ab 0.14: Bestaetigen frischt den Kauf auf (zwischen Start und Bestaetigen koennen Sekunden liegen)
    Hook("C_AuctionHouse.ConfirmCommoditiesPurchase", function(itemID, qty) M.Note("ahbuyitem", { id = itemID, qty = qty }) end)
    -- ab 0.14: Einzelgegenstand gekauft (Sofortkauf oder Gebot): Gegenstand aus der Auktion bzw. Blizzards Kaufansicht
    Hook("C_AuctionHouse.PlaceBid", function(auctionID, amount)
        local id = M.BidItem(auctionID)
        M.Note("ahbuyitem", { id = id, qty = 1, amount = Num(amount) and amount or nil })
    end)
end

-- Gegenstand einer Auktion, auf die geboten oder die gekauft wird (ab 0.14). nil, wenn das Spiel ihn nicht nennt
function M.BidItem(auctionID)
    local ah = rawget(_G, "C_AuctionHouse")
    if ah and type(ah.GetAuctionInfoByID) == "function" and Num(auctionID) then
        local ok, info = pcall(ah.GetAuctionInfoByID, auctionID)
        if ok and type(info) == "table" and type(info.itemKey) == "table" and Num(info.itemKey.itemID) then return info.itemKey.itemID end
    end
    local f = rawget(_G, "AuctionHouseFrame")
    local buy = type(f) == "table" and rawget(f, "ItemBuyFrame") or nil
    if type(buy) == "table" then
        local key = rawget(buy, "itemKey")
        if type(key) ~= "table" and type(buy.GetItemKey) == "function" then
            local ok, k = pcall(buy.GetItemKey, buy)
            if ok then key = k end
        end
        if type(key) == "table" and Num(key.itemID) then return key.itemID end
    end
    return nil
end

-- Postfach zu (ab 0.14): Entwurf kurz danach aufloesen. Was zurueck in die Tasche kommt, gehoert nicht dazu
-- (Blizzard legt Anhaenge beim Schliessen zurueck), der Rest war kein Brief.
function M.CloseMail()
    M.Close("mail")
    if not next(M.draft) then return end
    local CT = rawget(_G, "C_Timer")
    if CT and CT.After then
        CT.After(M.WINDOW + 1, function() if not M.open.mail then mod:Call("Bewegungen", M.DropDraft) end end)
    else
        M.DropDraft()
    end
end

-- Buch zuruecksetzen (Optionen): Verlauf und Wochensummen dieses Realms loeschen, aktuellen Stand neu lesen
-- und als neue Inventur (Anfangsbestand) fuer alle Charaktere des Realms nehmen
function M.ResetBook()
    local I = ns.Inventory
    local r = I.RealmData()
    -- ab 0.14.1: Kosten und "zuletzt" aus dem bisherigen Verlauf behalten (vorher galt der ganze Bestand als zum
    -- heutigen Marktwert gekauft, das zeigte beim ersten Verkauf falsche Gewinne und Verluste)
    local carry
    if ns.Cost then
        ns.Cost.Invalidate()
        local ok, st = pcall(ns.Cost.State)
        if ok and type(st) == "table" then carry = st end
    end
    if ns.Last then pcall(ns.Last.Persist) end
    M.pending, M.transit, M.takes, M.draft = nil, {}, {}, {}
    I.quiet = true
    I.ScanMoney()
    I.ScanBags()
    I.ScanEquip()
    if I.open.bank then I.ScanBank() end
    if I.open.mail then I.ScanMail() end
    I.quiet = nil
    r.moves = {}
    r.weeks = nil
    r.lotBase = nil
    if ns.Last then ns.Last.dirty = true end   -- zuletzt gezahlt/verkauft bleibt (realms[Realm].last)
    local t = time()
    for _, c in pairs(r.chars) do
        local start = { t = t, money = c.money, places = {} }
        for place, p in pairs(c.places or {}) do
            if type(p) == "table" and type(p.items) == "table" then
                local copy = {}
                for id, n in pairs(p.items) do copy[id] = n end
                start.places[place] = { t = t, items = copy }
            end
        end
        c.start = start
    end
    if carry and ns.Cost then r.lotBase = ns.Cost.CarryOver(carry, t) end
    -- ab 0.14.2: laufende Auktionen und Verkaufsbriefe im Briefkasten merken (Sondereinnahme)
    r.pre = {}
    for name, c in pairs(r.chars) do
        local pa, ps = {}, {}
        local a = c.places and c.places.auctions
        if type(a) == "table" and type(a.items) == "table" then for id, n in pairs(a.items) do pa[id] = n end end
        local ml = c.places and c.places.mail
        for _, l in ipairs(type(ml) == "table" and type(ml.list) == "table" and ml.list or {}) do
            if l.sold then ps[l.sold] = (ps[l.sold] or 0) + (l.q or 1) end
        end
        if next(pa) or next(ps) then r.pre[name] = { auctions = pa, sold = ps } end
    end
    M.Changed()
    I.Changed()
end

-- Inventur neu (ab 0.6, nur eingeloggter Charakter - andere kann das Spiel nicht lesen): Taschen, Ausruestung,
-- Gold (und offene Bank/Post) neu lesen; Unterschiede zum gespeicherten Stand als "Korrektur" (zaehlt nicht).
-- Rueckgabe: Anzahl Korrekturen
function M.Recount()
    local I = ns.Inventory
    if M.pending then M.Flush() end
    local c = I.Char()
    local places = { "bags", "equip" }
    if I.open.bank then places[#places + 1] = "bank" end
    local function Totals()
        local t = {}
        for _, place in ipairs(places) do
            local p = c.places[place]
            if type(p) == "table" and type(p.items) == "table" then
                for id, n in pairs(p.items) do t[id] = (t[id] or 0) + n end
            end
        end
        return t
    end
    local before, money = Totals(), c.money
    I.quiet = true
    I.ScanMoney()
    I.ScanBags()
    I.ScanEquip()
    if I.open.bank then I.ScanBank() end
    if I.open.mail then I.ScanMail() end
    I.quiet = nil
    local after, n = Totals(), 0
    for id, v in pairs(after) do
        local d = v - (before[id] or 0)
        if d ~= 0 then
            local e = M.Add("fix", id, d, nil, L.MV_X_RECOUNT)
            if e and d > 0 and ns.Cost then e.v = ns.Cost.MarketValue(id) or 0 end   -- Kosten der Korrektur: Marktwert jetzt (ab 0.7)
            n = n + 1
        end
    end
    for id, v in pairs(before) do
        if after[id] == nil and v ~= 0 then M.Add("fix", id, -v, nil, L.MV_X_RECOUNT); n = n + 1 end
    end
    if Num(money) and Num(c.money) and c.money ~= money then M.Add("fix", nil, nil, c.money - money, L.MV_X_RECOUNT); n = n + 1 end
    M.Changed()
    I.Changed()
    return n
end

function M.OnLogin()
    M.Prune()
end

---------------------------------------------------------------------------
-- Abfragen (Verlauf)
---------------------------------------------------------------------------
-- Seite einer Bewegung: "in", "out" oder "move"
function M.Side(e)
    local kind = M.KINDS[e.k] or M.KINDS.other
    if kind.side ~= "both" then return kind.side end
    local v = e.n or e.m or 0
    if e.n and e.n ~= 0 then v = e.n end
    return v >= 0 and "in" or "out"
end

-- Bezeichnung einer Bewegung, z. B. "Händler verkauft"
-- Tausch gegen Gold: Gold geht in die andere Richtung als der Gegenstand (Gold - = gekauft)
M.EXCHANGE = { vendor = true, buyback = true }

function M.Label(e)
    if e.sp then return L.MV_SPECIAL end   -- ab 0.14.2
    local v = (e.n and e.n ~= 0) and e.n or (e.m or 0)
    if not (e.n and e.n ~= 0) and M.EXCHANGE[e.k] then v = -v end
    local dir = v >= 0 and "IN" or "OUT"
    local k = tostring(e.k):upper()
    return rawget(L, "MV_" .. k .. "_" .. dir) or rawget(L, "MV_" .. k) or L.MV_OTHER_IN and (v >= 0 and L.MV_OTHER_IN or L.MV_OTHER_OUT) or e.k
end
