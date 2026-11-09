-- Peon_Broker - Watch.lua
-- Umbau U8 (ab 0.49, Konzept Peon_Broker_Umbau.md, Abschnitt 8.7): Beobachtung (im Manager bisher Favoriten).
--   PeonBrokerDB.watch[Schluessel] = { u, name, q, icon, lim (Kupfer) oder pct (% unter dem Vergleichspreis), hit }
--   PeonBrokerDB.watchGone[Schluessel] = Zeit (Loeschmarke, wie bei den Einkaufslisten)
-- Preisalarm: Liegt das guenstigste Angebot auf oder unter der Grenze, meldet Broker das einmal im Chat und mit
-- Ton (wie das Radar) und erst wieder, nachdem der Preis darueber lag. Geprueft nach jedem Komplettscan, nach
-- dem Stand vom Manager (Anmelden) und nach jeder Live-Abfrage.
-- Im Auktionshaus steht die Beobachtung als eigene Liste im Reiter Einkaufen (Buy.lua, Pseudo-Liste "watch").

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local Wt = {}
ns.Watch = Wt

Wt.PCTS = { 10, 20, 30 }   -- Vorschlaege im Menue: % unter dem Vergleichspreis

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end

function Wt.Store()
    local acc = mod.acc
    if type(acc) ~= "table" then return {} end
    if type(acc.watch) ~= "table" then acc.watch = {} end
    return acc.watch
end

function Wt.Gone()
    local acc = mod.acc
    if type(acc) ~= "table" then return {} end
    if type(acc.watchGone) ~= "table" then acc.watchGone = {} end
    return acc.watchGone
end

local function NextU(old)
    local t = time and time() or 0
    if Num(old) and old >= t then return old + 1 end
    return t
end

function Wt.Is(key) return key ~= nil and Wt.Store()[key] ~= nil end

function Wt.Add(key, info)
    if key == nil then return false end
    local st = Wt.Store()
    local w = st[key] or {}
    info = type(info) == "table" and info or {}
    w.name = info.name or w.name
    w.q = info.quality or info.q or w.q
    w.icon = info.icon or w.icon
    w.u = NextU(math.max(w.u or 0, Wt.Gone()[key] or 0))
    Wt.Gone()[key] = nil
    st[key] = w
    mod:Print(L.WATCH_ADDED:format(w.name or tostring(key)))
    Wt.Check({ key })
    return true
end

function Wt.Remove(key)
    local st = Wt.Store()
    if not st[key] then return false end
    Wt.Gone()[key] = NextU(st[key].u)
    st[key] = nil
    return true
end

function Wt.Toggle(key, info)
    if Wt.Is(key) then Wt.Remove(key); return false end
    Wt.Add(key, info)
    return true
end

-- Grenze setzen: kind "pct" (value % unter dem Vergleichspreis), "abs" (value Kupfer), nil = keine Grenze
function Wt.SetLimit(key, kind, value)
    local w = Wt.Store()[key]
    if not w then return false end
    w.lim, w.pct, w.hit = nil, nil, nil
    if kind == "pct" and Num(value) then w.pct = value
    elseif kind == "abs" and Num(value) and value > 0 then w.lim = math.floor(value) end
    w.u = NextU(w.u)
    Wt.Check({ key })
    return true
end

-- Grenze in Kupfer (je Stueck) oder nil
function Wt.Limit(key, e)
    local w = Wt.Store()[key]
    if not w then return nil end
    if Num(w.lim) then return w.lim end
    if Num(w.pct) then return ns.Data.MaxBuyPrice(e or ns.Data.Lookup(key), w.pct) end
    return nil
end

-- Text der Grenze fuer Listen und Menue
function Wt.LimitText(key)
    local w = Wt.Store()[key]
    if not w then return nil end
    if Num(w.lim) then return Money(w.lim) end
    if Num(w.pct) then return L.WATCH_PCT:format(w.pct) end
    return nil
end

-- Preisalarm pruefen (keys = Liste von Schluesseln oder nil = alle). Rueckgabe: Zahl neuer Alarme
function Wt.Check(keys)
    local st = Wt.Store()
    local list = keys
    if not list then list = {}; for k in pairs(st) do list[#list + 1] = k end end
    local n = 0
    for _, key in ipairs(list) do
        local w = st[key]
        if w then
            local e = ns.Data.Lookup(key)
            local limit = Wt.Limit(key, e)
            local hit = limit and type(e) == "table" and not e.gone and Num(e.m) and e.m <= limit
            if hit and not w.hit then
                w.hit = true
                n = n + 1
                mod:Print(L.WATCH_ALARM:format(w.name or ns.Data.ItemName(key, e) or tostring(key), Money(e.m), Money(limit)))
                if mod.db.radarSound and ns.Radar and ns.Radar.PlayAlert then pcall(ns.Radar.PlayAlert) end
            elseif not hit and w.hit and (type(e) ~= "table" or e.gone or (limit and Num(e.m) and e.m > limit)) then
                w.hit = nil
            end
        end
    end
    if n > 0 and ns.Buy and ns.Buy.UpdateBadge then pcall(ns.Buy.UpdateBadge) end
    return n
end

-- Pseudo-Liste fuer den Reiter Einkaufen (wie eine Einkaufsliste, aber ohne Abgleich und ohne Wunschmenge)
function Wt.PseudoList()
    local items = {}
    for key, w in pairs(Wt.Store()) do
        items[key] = { name = w.name, q = w.q, icon = w.icon, max = Wt.Limit(key) }
    end
    return { id = "watch", name = L.WATCH_LIST, pct = 0, items = items, watch = true }
end

-- Gegenstandsmenue: "Beobachten" (Haken) und Untermenue "Preisgrenze"
function Wt.AddMenu(root, item, key)
    local on = Wt.Is(key)
    if root.CreateCheckbox then
        root:CreateCheckbox(L.MENU_WATCH, function() return Wt.Is(key) end,
            function() mod:Call("Beobachtung", Wt.Toggle, key, { name = item.name }) end)
    else
        root:CreateButton(on and L.MENU_UNWATCH or L.MENU_WATCH, function() mod:Call("Beobachtung", Wt.Toggle, key, { name = item.name }) end)
    end
    if not on then return end
    local sub = root:CreateButton(L.MENU_WATCH_LIMIT)
    for _, p in ipairs(Wt.PCTS) do
        sub:CreateButton(L.WATCH_PCT:format(p), function() mod:Call("Beobachtung", Wt.SetLimit, key, "pct", p) end)
    end
    local e = ns.Data.Lookup(key)
    if type(e) == "table" and Num(e.m) then
        sub:CreateButton(L.MENU_WATCH_NOW:format(Money(e.m)), function() mod:Call("Beobachtung", Wt.SetLimit, key, "abs", e.m) end)
    end
    sub:CreateButton(L.MENU_WATCH_NONE, function() mod:Call("Beobachtung", Wt.SetLimit, key, nil) end)
end

function Wt.Init()
    mod:On("SCAN_DONE", function() mod:Call("Beobachtung", Wt.Check) end)
    -- nach jeder Live-Abfrage den Gegenstand pruefen
    local D = ns.Data
    local orig = D.ApplyLive
    D.ApplyLive = function(key, ...)
        local a, b, c = orig(key, ...)
        if key ~= nil and Wt.Store()[key] then mod:Call("Beobachtung", Wt.Check, { key }) end
        return a, b, c
    end
end

-- Beobachtung aus dem Peon Manager einmischen (ab 0.49, ueber Peon_Bridge 0.9.0, Data.lua "watch").
-- data = { items = { [Schluessel] = u }, gone = { [Schluessel] = u } }. Je Gegenstand gewinnt die neuere Aenderung.
-- Preisgrenzen bleiben im Spiel (der Manager kennt keine). Rueckgabe: true bei Aenderung
function mod:MergeWatch(data)
    if type(data) ~= "table" then return false end
    local st, gone = Wt.Store(), Wt.Gone()
    local changed = false
    local function Key(k)
        if type(k) == "string" and k:match("^%d+$") then return tonumber(k) end
        return k
    end
    for k, u in pairs(type(data.items) == "table" and data.items or {}) do
        local key, uu = Key(k), tonumber(u) or 0
        local w = st[key]
        local localU = w and (w.u or 0) or (gone[key] or 0)
        if not w and (uu > localU or gone[key] == nil) then
            local e = ns.Data.Lookup(key)
            st[key] = { u = uu, name = ns.Data.ItemName(key, e) }
            gone[key] = nil
            changed = true
        elseif w and uu > (w.u or 0) then
            w.u = uu
            changed = true
        end
    end
    for k, u in pairs(type(data.gone) == "table" and data.gone or {}) do
        local key, uu = Key(k), tonumber(u) or 0
        local w = st[key]
        if w and uu > (w.u or 0) then st[key] = nil; gone[key] = uu; changed = true
        elseif not w and uu > (gone[key] or 0) then gone[key] = uu; changed = true end
    end
    if changed then Wt.Check() end
    return changed
end
