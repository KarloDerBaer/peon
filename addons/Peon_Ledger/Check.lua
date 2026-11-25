-- Peon_Ledger - Check.lua
-- Kontrollrechnung (ab 0.14, Konzept Peon_Ledger_Neuaufbau.md Abschnitt 3.4, Bauabschnitt E1).
-- Ledger rechnet selbst nach, ob Gold und Bestand eines Charakters zu Anfangsbestand und Bewegungen passen:
--   Gold:      Anfangsgold + alle Goldbewegungen des Charakters  ->  verglichen mit dem gelesenen Gold
--   Bestand:   Anfangsbestand + alle Zu- und Abgaenge je Gegenstand, ohne die Ware im Auktionshaus  ->  verglichen
--              mit Taschen, Bank und Ausruestung (Post und "unterwegs" zaehlen nicht, dort liegt nichts, das schon
--              verbucht waere)
-- Ab 0.18.1 liest die Kontrollrechnung die Liste der eigenen Auktionen nicht mehr. Was im Auktionshaus liegt, folgt
-- aus den Bewegungen: eingestellt minus zurueck minus verkauft. Die Liste des Spiels kam teils zu spaet oder ohne
-- die gerade eingestellte Ware, dann buchte die Rechnung gekaufte Ware samt Kosten als fehlend aus, und der
-- spaetere Verkauf zaehlte als Beute statt als Handel.
-- Beim Einloggen (nach der Ruhezeit) wird eine Abweichung als eigene Zeile "Abweichung" verbucht (Art "diff",
-- zaehlt nicht als Gewinn). So stimmt die Rechnung danach wieder, und jede Luecke ist im Verlauf zu sehen.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local K = {}
ns.Check = K

K.PLACES = { "bags", "bank", "auctions", "equip" }   -- Anfangsbestand (alle Orte)
K.OUTSIDE = { "bags", "bank", "equip" }              -- ab 0.18.1: gelesener Stand ohne Auktionen
K.SKIP = { posted = true, ahback = true, ahreturn = true, aucfix = true }   -- nur Umbuchung zwischen Taschen und Auktionen
-- ab 0.18.1: Wirkung einer Bewegung auf die Ware im Auktionshaus (Faktor fuer n). Eingestellt (n minus) kommt
-- hinein, zurueck (n plus) und verkauft (n minus) gehen hinaus.
K.LISTED = { posted = -1, ahreturn = -1, ahback = -1, ahsold = 1 }
K.PAIR_DAYS = 3     -- ab 0.15: Abweichung minus bis so lange nach dem Einstellen gilt als nicht angekommene Auktion
K.DELAY = 25        -- Sekunden nach dem Einloggen (Inventory.LOGIN_QUIET ist 20)
K.DAYS = 7          -- Abweichungen der letzten Tage in der Anzeige

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

-- Erwarteter Stand eines Charakters ausserhalb des Auktionshauses: gold, items[id], listed[id]
-- (listed ab 0.18.1: Ware im Auktionshaus nach den Bewegungen)
function K.Expected(name)
    local r = ns.Inventory.RealmData()
    local c = r.chars[name]
    if type(c) ~= "table" then return nil end
    local start = type(c.start) == "table" and c.start or { places = {} }
    local gold = Num(start.money) and start.money or nil
    local items, listed = {}, {}
    for _, place in ipairs(K.PLACES) do
        local p = type(start.places) == "table" and start.places[place]
        if type(p) == "table" and type(p.items) == "table" then
            for id, n in pairs(p.items) do
                if Num(n) then
                    items[id] = (items[id] or 0) + n
                    if place == "auctions" then listed[id] = (listed[id] or 0) + n end
                end
            end
        end
    end
    local function Use(k, id, n, m)
        if Num(m) and gold then gold = gold + m end
        if id and Num(n) and n ~= 0 then
            if not K.SKIP[k] then items[id] = (items[id] or 0) + n end
            if K.LISTED[k] then listed[id] = (listed[id] or 0) + K.LISTED[k] * n end
        end
    end
    if type(r.weeks) == "table" then
        for _, w in pairs(r.weeks) do
            for key, sum in pairs(w) do
                local cc, k, id = key:match("^(.-)|(.-)|(.-)$")
                if cc == name then
                    id = tonumber(id)
                    Use(k, (id and id > 0) and id or nil, sum.n, sum.m)
                end
            end
        end
    end
    for _, e in ipairs(ns.Moves.List()) do
        if e.c == name then Use(e.k, e.id, e.n, e.m) end
    end
    -- Ware im Auktionshaus abziehen, zwischen null und dem ganzen Bestand. Unter null: Verkaeufe von Ware, deren
    -- Einstellen Ledger nicht kannte. Ueber dem Bestand: Ledger hat mehr eingestellt als gezaehlt (alte
    -- Abweichungen). Sonst buchte die Rechnung dafuer ein Plus ohne Kosten, und spaetere Verkaeufe wuerden Beute.
    for id, n in pairs(listed) do
        local v = math.max(0, math.min(n, math.max(0, items[id] or 0)))
        listed[id] = v > 0 and v or nil
        if v > 0 then items[id] = (items[id] or 0) - v end
    end
    return gold, items, listed
end

-- Gelesener Stand ohne Auktionen: gold, items[id]
function K.Actual(name)
    local c = ns.Inventory.RealmData().chars[name]
    if type(c) ~= "table" then return nil, {} end
    local items = {}
    for _, place in ipairs(K.OUTSIDE) do
        local p = c.places and c.places[place]
        if type(p) == "table" and type(p.items) == "table" then
            for id, n in pairs(p.items) do items[id] = (items[id] or 0) + n end
        end
    end
    return Num(c.money) and c.money or nil, items
end

-- Abweichungen: { gold = Kupfer (gelesen - erwartet), items = { [id] = Stueck }, n = Anzahl }
function K.Run(name)
    name = name or ns.CharName()
    local eg, ei = K.Expected(name)
    local ag, ai = K.Actual(name)
    local res = { gold = 0, items = {}, n = 0, name = name }
    if eg and ag and ag ~= eg then res.gold = ag - eg; res.n = res.n + 1 end
    local seen = {}
    for id, n in pairs(ai) do
        seen[id] = true
        local d = n - (ei and ei[id] or 0)
        if d ~= 0 then res.items[id] = d; res.n = res.n + 1 end
    end
    for id, n in pairs(ei or {}) do
        if not seen[id] and n ~= 0 then res.items[id] = -n; res.n = res.n + 1 end
    end
    return res
end

-- Abweichungen als Zeilen "Abweichung" verbuchen (nur eingeloggter Charakter). Rueckgabe: Anzahl Zeilen
function K.Book(name)
    name = name or ns.CharName()
    local M = ns.Moves
    if M.pending or next(M.draft or {}) then return 0 end
    local res = K.Run(name)
    if res.n == 0 then K.last = res; return 0 end
    local n = 0
    if res.gold ~= 0 then M.Add("diff", nil, nil, res.gold, L.MV_X_DIFF, name); n = n + 1 end
    for id, d in pairs(res.items) do
        -- ab 0.15: Mehr Ware, die beim Charakter unter "Unterwegs" liegt, ist abgeholte Twink-Post (Kosten wandern mit)
        local got = d > 0 and K.FromTransit(name, id, d) or 0
        if got > 0 then
            M.Add("twink", id, got, nil, nil, name)
            n = n + 1
        end
        if d - got ~= 0 then
            local e = M.Add("diff", id, d - got, nil, L.MV_X_DIFF, name)
            if e and d - got > 0 and ns.Cost then e.v = ns.Cost.MarketValue(id) or 0 end
            n = n + 1
        end
    end
    mod:Dbg(("Kontrollrechnung %s: %d Abweichungen verbucht"):format(name, n))
    K.last = K.Run(name)
    return n
end

-- Bis zu n Stueck aus "Unterwegs" des Charakters nehmen (ab 0.15). Rueckgabe: genommene Stueck
function K.FromTransit(name, id, n, realm)
    local r = realm or ns.Inventory.RealmData()
    local c = r.chars and r.chars[name]
    local p = type(c) == "table" and type(c.places) == "table" and c.places.transit
    if type(p) ~= "table" or type(p.items) ~= "table" or not Num(p.items[id]) or p.items[id] <= 0 then return 0 end
    local take = math.min(p.items[id], n)
    p.items[id] = p.items[id] - take
    if p.items[id] <= 0 then p.items[id] = nil end
    return take
end

-- Einmalige Reparatur (ab 0.15): Abweichungen mit mehr Ware, die zu "Unterwegs" desselben Charakters passen, waren
-- Twink-Post, die in der Ruhezeit nach dem Einloggen abgeholt wurde. Sie werden zu Twink-Post (mit den Kosten des
-- Absenders). Passt nur ein Teil, bleibt der Rest eine Abweichung. Alle Realms, gemerkt in fixTransit.
function K.RepairTransit()
    local db = mod.acc
    if type(db) ~= "table" or db.fixTransit then return 0 end
    local fixed = 0
    for _, r in pairs(type(db.realms) == "table" and db.realms or {}) do
        local list = type(r) == "table" and r.moves
        if type(list) == "table" then
            local i = 1
            while i <= #list do
                local e = list[i]
                if type(e) == "table" and e.k == "diff" and e.id and Num(e.n) and e.n > 0 and e.c then
                    local got = K.FromTransit(e.c, e.id, e.n, r)
                    if got > 0 then
                        if got < e.n then
                            local rest = {}
                            for k2, v in pairs(e) do rest[k2] = v end
                            rest.n = e.n - got
                            table.insert(list, i + 1, rest)
                        end
                        e.k, e.n, e.x, e.v, e.fixT = "twink", got, nil, nil, true
                        fixed = fixed + 1
                    end
                end
                i = i + 1
            end
        end
    end
    db.fixTransit = true
    if fixed > 0 then
        ns.Moves.Changed()
        mod:Print(L.MSG_FIX_TRANSIT:format(fixed))
    end
    return fixed
end

-- Abweichungen durch Einstellen paaren (ab 0.15): Bis 0.14.9 kam eingestellte Ware erst unter Auktionen an, wenn
-- man die eigenen Auktionen ansah. Die Kontrollrechnung buchte sie als fehlend (minus) und nach dem Verkauf wieder
-- als Zugang (plus). Beide nahmen und gaben Posten (Kosten weg, Startbestand mit Kosten 0 dazu). Ein Minus bis
-- K.PAIR_DAYS nach dem Einstellen desselben Gegenstands und ein spaeteres Plus werden gegeneinander aufgehoben:
-- Art "aucfix" (Umbuchung, zaehlt weder fuer Kosten noch fuer die Kontrollrechnung). Rest bleibt Abweichung.
function K.PairAuctionDiffs()
    local r = ns.Inventory.RealmData()
    local list = type(r.moves) == "table" and r.moves or {}
    local lastPost, neg, conv = {}, {}, {}
    local paired = 0
    for _, e in ipairs(list) do
        if type(e) == "table" and e.id and e.c then
            local key = e.c .. "|" .. tostring(e.id)
            if e.k == "posted" then
                lastPost[key] = e.t or 0
            elseif e.k == "diff" and Num(e.n) and e.n < 0 and lastPost[key] and (e.t or 0) - lastPost[key] <= K.PAIR_DAYS * 86400 then
                local q = neg[key]
                if not q then q = {}; neg[key] = q end
                q[#q + 1] = { e = e, rem = -e.n }
            elseif e.k == "diff" and Num(e.n) and e.n > 0 and neg[key] then
                local want = e.n
                local q = neg[key]
                while want > 0 and q[1] do
                    local x = q[1]
                    local k = math.min(want, x.rem)
                    x.rem, want = x.rem - k, want - k
                    conv[x.e] = (conv[x.e] or 0) + k
                    conv[e] = (conv[e] or 0) + k
                    if x.rem <= 0 then table.remove(q, 1) end
                end
                if not q[1] then neg[key] = nil end
            end
        end
    end
    if not next(conv) then return 0 end
    local out = {}
    for _, e in ipairs(list) do
        out[#out + 1] = e
        local k = conv[e]
        if k then
            local sign = e.n < 0 and -1 or 1
            if k >= math.abs(e.n) then
                e.k, e.x, e.v = "aucfix", nil, nil
            else
                local fix = {}
                for a, b in pairs(e) do fix[a] = b end
                fix.k, fix.n, fix.x, fix.v = "aucfix", sign * k, nil, nil
                e.n = e.n - sign * k
                out[#out + 1] = fix
            end
            paired = paired + 1
        end
    end
    for i = 1, math.max(#list, #out) do list[i] = out[i] end
    ns.Moves.Changed()
    mod:Dbg(("Kontrollrechnung: %d Abweichungen durch Einstellen gepaart"):format(paired))
    return paired
end

-- Einmalig (ab 0.18.1, gemerkt in fixSoldDiff): Abweichungen minus nach dem Einstellen, deren Ware danach verkauft
-- wurde, waren nie weg. Bis 0.18.0 las die Kontrollrechnung die Liste der eigenen Auktionen, die gerade
-- eingestellte Ware teils nicht enthielt. Sie buchte die Ware samt Kosten aus, der Verkauf zaehlte als Beute.
-- Jeder Verkauf (Zeile "Auktion verkauft" mit Abgang) hebt solche Abweichungen bis zu seiner Menge auf: Art
-- "aucfix" (Umbuchung). Die Kosten rechnet Ledger danach aus den Bewegungen neu. Alle Realms.
function K.RepairSoldDiffs()
    local db = mod.acc
    if type(db) ~= "table" or db.fixSoldDiff then return 0 end
    local total = 0
    local win = K.PAIR_DAYS * 86400
    for _, r in pairs(type(db.realms) == "table" and db.realms or {}) do
        local list = type(r) == "table" and type(r.moves) == "table" and r.moves or nil
        if list then
            local lastPost, neg, conv = {}, {}, {}
            for _, e in ipairs(list) do
                if type(e) == "table" and e.id and e.c and Num(e.n) then
                    local key = e.c .. "|" .. tostring(e.id)
                    local t = Num(e.t) and e.t or 0
                    if e.k == "posted" then
                        lastPost[key] = t
                    elseif e.k == "diff" and e.n < 0 and lastPost[key] and t - lastPost[key] <= win then
                        local q = neg[key]
                        if not q then q = {}; neg[key] = q end
                        q[#q + 1] = { e = e, rem = -e.n, t = t }
                    elseif e.k == "ahsold" and e.n < 0 and neg[key] then
                        local want = -e.n
                        local q = neg[key]
                        for i = #q, 1, -1 do   -- juengste Abweichung zuerst (wie ResolveListed)
                            if want <= 0 then break end
                            local x = q[i]
                            if t - x.t <= win and x.rem > 0 then
                                local k = math.min(want, x.rem)
                                x.rem, want = x.rem - k, want - k
                                conv[x.e] = (conv[x.e] or 0) + k
                            end
                        end
                        for i = #q, 1, -1 do if q[i].rem <= 0 or t - q[i].t > win then table.remove(q, i) end end
                        if not q[1] then neg[key] = nil end
                    end
                end
            end
            if next(conv) then
                local out = {}
                for _, e in ipairs(list) do
                    out[#out + 1] = e
                    local k = conv[e]
                    if k then
                        if k >= -e.n then
                            e.k, e.x, e.v = "aucfix", nil, nil
                        else
                            local fix = {}
                            for a, b in pairs(e) do fix[a] = b end
                            fix.k, fix.n, fix.x, fix.v = "aucfix", -k, nil, nil
                            e.n = e.n + k
                            out[#out + 1] = fix
                        end
                        total = total + k
                    end
                end
                for i = 1, math.max(#list, #out) do list[i] = out[i] end
            end
        end
    end
    db.fixSoldDiff = true
    if total > 0 then
        ns.Moves.Changed()
        mod:Print(L.MSG_FIX_SOLDDIFF:format(total))
    end
    return total
end

-- Neue Auktion in der Liste, die vorher fehlte (ab 0.15.1, aus Moves.OnAuctions): offene Abweichungen minus nach
-- dem Einstellen desselben Gegenstands werden zu "Auktion (korrigiert)", die Ware war nie weg. Rueckgabe: Stueck
function K.ResolveListed(name, id, n)
    local list = ns.Moves.List()
    local lastPost
    for _, e in ipairs(list) do
        if e.c == name and e.id == id and e.k == "posted" then lastPost = e.t or 0 end
    end
    if not lastPost then return 0 end
    local left, done = n, 0
    for i = #list, 1, -1 do
        if left <= 0 then break end
        local e = list[i]
        if e.c == name and e.id == id and e.k == "diff" and Num(e.n) and e.n < 0 and (e.t or 0) >= lastPost - K.PAIR_DAYS * 86400 then
            local k = math.min(left, -e.n)
            if k >= -e.n then
                e.k, e.x, e.v = "aucfix", nil, nil
            else
                local fix = {}
                for a, b in pairs(e) do fix[a] = b end
                fix.k, fix.n, fix.x, fix.v = "aucfix", -k, nil, nil
                e.n = e.n + k
                table.insert(list, i + 1, fix)
            end
            left, done = left - k, done + k
        end
    end
    if done > 0 then ns.Moves.Changed() end
    return done
end

-- Einmalig (ab 0.15.1, gemerkt in fixListed): Ware, die vor 0.15.1 eingestellt wurde und seitdem weder verkauft
-- noch zurueckgekommen ist, unter Auktionen nachtragen. Nur Einstellungen nach dem letzten Lesen der Auktionsliste
-- des Charakters (davor stimmt die Liste).
function K.RepairListed()
    local db = mod.acc
    if type(db) ~= "table" or db.fixListed then return 0 end
    local fixed = 0
    for _, r in pairs(type(db.realms) == "table" and db.realms or {}) do
        local open = {}
        for name, c in pairs(type(r) == "table" and type(r.chars) == "table" and r.chars or {}) do
            local p = type(c) == "table" and type(c.places) == "table" and c.places.auctions
            open[name] = { t = type(p) == "table" and p.t or 0, items = {} }
        end
        for _, e in ipairs(type(r.moves) == "table" and r.moves or {}) do
            local o = e.c and open[e.c]
            if o and e.id and Num(e.n) and (e.t or 0) > o.t then
                if e.k == "posted" and e.n < 0 and not e.pl then o.items[e.id] = (o.items[e.id] or 0) - e.n
                elseif (e.k == "ahreturn" and e.n > 0) or (e.k == "ahsold" and e.n < 0) then
                    o.items[e.id] = math.max(0, (o.items[e.id] or 0) - math.abs(e.n))
                end
            end
        end
        for name, o in pairs(open) do
            for id, n in pairs(o.items) do
                if n > 0 then
                    local c = r.chars[name]
                    if type(c.places.auctions) ~= "table" then c.places.auctions = { t = 0, items = {} } end
                    local p = c.places.auctions
                    if type(p.items) ~= "table" then p.items = {} end
                    p.items[id] = (p.items[id] or 0) + n
                    fixed = fixed + 1
                end
            end
        end
    end
    db.fixListed = true
    if fixed > 0 then ns.Moves.Changed() end
    return fixed
end

-- Zeilen "Abweichung" der letzten Tage (alle Charaktere des Realms)
function K.Recent(days, now)
    now = now or time()
    local from = now - (days or K.DAYS) * 86400
    local n = 0
    for _, e in ipairs(ns.Moves.List()) do
        if e.k == "diff" and (e.t or 0) >= from then n = n + 1 end
    end
    return n
end

-- Text fuer die Statuszeile
function K.StatusText()
    local open = K.Run().n
    local recent = K.Recent()
    if open == 0 and recent == 0 then return L.CHECK_OK end
    if open > 0 then return ns.Plural(open, "CHECK_OPEN") end
    return ns.Plural(recent, "CHECK_RECENT", K.DAYS)
end

function K.OnLogin()
    local CT = rawget(_G, "C_Timer")
    local function Go()
        mod:Call("Kontrollrechnung", K.RepairTransit)
        mod:Call("Kontrollrechnung", K.RepairListed)
        mod:Call("Kontrollrechnung", K.RepairSoldDiffs)
        mod:Call("Kontrollrechnung", K.Book)
        mod:Call("Kontrollrechnung", K.PairAuctionDiffs)
    end
    if CT and CT.After then CT.After(K.DELAY, Go) else Go() end
end
