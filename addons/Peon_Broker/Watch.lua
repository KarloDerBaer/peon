-- Peon_Broker - Watch.lua
-- Umbau U8 (ab 0.49, Konzept Peon_Broker_Umbau.md, Abschnitt 8.7): Beobachtung (im Manager bisher Favoriten).
--   PeonBrokerDB.watch[Schluessel] = { u, name, q, icon, lim (Kupfer) oder pct (% unter dem Vergleichspreis), hit,
--                                      up (Grenze nach oben in Kupfer, ab 0.68), upHit }
--   PeonBrokerDB.watchGone[Schluessel] = Zeit (Loeschmarke, wie bei den Einkaufslisten)
-- Ab 0.89 (Manager-Angleichung A2, Peon_Manager_Angleichung.md 3.2): t = { buy, up } Zeit je Wert. "buy" ist Kaufen bis
-- (lim oder pct), "up" der Zielpreis. Der Abgleich mit dem Manager laeuft je Wert, beide Grenzen gehen mit.
-- Preisalarm: Liegt das guenstigste Angebot auf oder unter der Grenze, meldet Broker das einmal im Chat und mit
-- Ton (wie das Radar) und erst wieder, nachdem der Preis darueber lag. Geprueft nach jedem Komplettscan, nach
-- dem Stand vom Manager (Anmelden) und nach jeder Live-Abfrage.
-- Ab 0.82 eigener Reiter Beobachten (WatchPage.lua). up heisst dort "Zielpreis" (Preis, ab dem man verkaufen wuerde).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local Wt = {}
ns.Watch = Wt

Wt.PCTS = { 10, 20, 30 }   -- Vorschlaege im Menue: % unter dem Vergleichspreis

-- Werte mit eigener Zeit (ab 0.89, Regeln in Shop.lua): Kaufen bis und Zielpreis. hit und upHit sind Merker des Alarms
Wt.SPEC = { { f = "buy", keys = { "lim", "pct" }, reset = "hit" }, { f = "up", keys = { "up" }, reset = "upHit" } }
Wt.SKIP = { u = true, t = true, lim = true, pct = true, up = true, hit = true, upHit = true, sDown = true, sUp = true }
-- ab 0.91 (Fehlerberichte 20 und 21): Warnton je Richtung, einstellbar fuer alle (watchSoundDown, watchSoundUp, dazu
-- Chatnachricht watchChatDown, watchChatUp) und je Gegenstand (sDown, sUp: Ton oder "off", nil = wie eingestellt).
-- Die Werte je Gegenstand bleiben im Spiel, der Manager kennt sie nicht.
Wt.SOUND_CHOICES = { "off", "raid", "ready", "alarm", "tell" }

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
    ns.Shop.Stamp(w, Wt.SPEC, "buy", time and time() or 0)   -- ab 0.89 je Wert
    Wt.Check({ key })
    return true
end

-- Grenze nach oben (ab 0.68, H4, Konzept 6.6): "Melde, wenn der Preis ueber X liegt" fuer Dinge, die man spaeter
-- verkaufen will. value = Kupfer je Stueck oder nil (keine Grenze)
function Wt.SetUp(key, value)
    local w = Wt.Store()[key]
    if not w then return false end
    w.up, w.upHit = nil, nil
    if Num(value) and value > 0 then w.up = math.floor(value) end
    ns.Shop.Stamp(w, Wt.SPEC, "up", time and time() or 0)   -- ab 0.89 je Wert
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

-- Warnton fuer einen Gegenstand und eine Richtung ("Down" = Kaufen bis, "Up" = Zielpreis): Schluessel oder "off"
function Wt.Sound(key, dir)
    local w = Wt.Store()[key]
    local own = w and w["s" .. dir] or nil
    if own ~= nil then return own end
    local v = mod.db["watchSound" .. dir]
    if v == nil then return "raid" end
    return v
end

function Wt.SetSound(key, dir, v)
    local w = Wt.Store()[key]
    if not w then return end
    w["s" .. dir] = v
end

-- Meldung eines Alarms: Chat und Ton je nach Einstellung
function Wt.Alert(key, dir, text)
    if mod.db.watchAlarm == false then return end   -- ab 0.83: Haken unter Beobachten schaltet alles ab
    if mod.db["watchChat" .. dir] ~= false then mod:Print(text) end
    local snd = Wt.Sound(key, dir)
    if snd ~= "off" and ns.Radar and ns.Radar.PlayAlert then pcall(ns.Radar.PlayAlert, snd) end
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
                Wt.Alert(key, "Down", L.WATCH_ALARM:format(w.name or ns.Data.ItemName(key, e) or tostring(key), Money(e.m), Money(limit)))
            elseif not hit and w.hit and (type(e) ~= "table" or e.gone or (limit and Num(e.m) and e.m > limit)) then
                w.hit = nil
            end
            -- ab 0.68: Grenze nach oben, guenstigstes Angebot liegt darueber (guter Zeitpunkt zum Verkaufen)
            local up = Num(w.up) and w.up or nil
            local upHit = up and type(e) == "table" and not e.gone and Num(e.m) and e.m >= up
            if upHit and not w.upHit then
                w.upHit = true
                n = n + 1
                Wt.Alert(key, "Up", L.WATCH_ALARM_UP:format(w.name or ns.Data.ItemName(key, e) or tostring(key), Money(e.m), Money(up)))
            elseif not upHit and w.upHit and (type(e) ~= "table" or e.gone or (up and Num(e.m) and e.m < up) or not up) then
                w.upHit = nil
            end
        end
    end
    if n > 0 and ns.Buy and ns.Buy.UpdateBadge then pcall(ns.Buy.UpdateBadge) end
    if ns.WatchPage and ns.WatchPage.UpdateBadge then pcall(ns.WatchPage.UpdateBadge) end   -- ab 0.82
    return n
end

-- Pseudo-Liste fuer den Reiter Einkaufen (wie eine Einkaufsliste, aber ohne Abgleich und ohne Wunschmenge)
function Wt.PseudoList()
    local items = {}
    for key, w in pairs(Wt.Store()) do
        items[key] = { name = w.name, q = w.q, icon = w.icon, max = Wt.Limit(key), up = Num(w.up) and w.up or nil }
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
    -- ab 0.68: Grenze nach oben
    local upSub = root:CreateButton(L.MENU_WATCH_UP)
    if type(e) == "table" and Num(e.m) then
        upSub:CreateButton(L.MENU_WATCH_NOW:format(Money(e.m)), function() mod:Call("Beobachtung", Wt.SetUp, key, e.m) end)
        for _, p in ipairs(Wt.PCTS) do
            local v = math.floor(e.m * (1 + p / 100))
            upSub:CreateButton(L.MENU_WATCH_UP_PCT:format(p, Money(v)), function() mod:Call("Beobachtung", Wt.SetUp, key, v) end)
        end
    end
    upSub:CreateButton(L.MENU_WATCH_NONE, function() mod:Call("Beobachtung", Wt.SetUp, key, nil) end)
    -- ab 0.91: Warnton je Gegenstand (Rechtsklick in der Liste Beobachten oeffnet dieses Menue)
    for _, dir in ipairs({ "Down", "Up" }) do
        local sSub = root:CreateButton(L["MENU_WATCH_SOUND_" .. dir:upper()])
        local function Own() local w = Wt.Store()[key]; return w and w["s" .. dir] or nil end
        if sSub.CreateRadio then
            sSub:CreateRadio(L.WATCH_SOUND_DEFAULT, function() return Own() == nil end,
                function() mod:Call("Beobachtung", Wt.SetSound, key, dir, nil) end)
            for _, v in ipairs(Wt.SOUND_CHOICES) do
                sSub:CreateRadio(Wt.SoundName(v), function() return Own() == v end, function()
                    mod:Call("Beobachtung", Wt.SetSound, key, dir, v)
                    if v ~= "off" and ns.Radar and ns.Radar.PlayAlert then pcall(ns.Radar.PlayAlert, v) end
                end)
            end
        end
    end
end

-- Name eines Tons fuer Menues und Einstellungen
function Wt.SoundName(v)
    if v == "off" then return L.WATCH_SOUND_OFF end
    return L["SOUND_" .. tostring(v):upper()] or tostring(v)
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
-- data = { items = { [Schluessel] = Eintrag }, gone = { [Schluessel] = u } }. Ab 0.89 ist ein Eintrag
-- { u, lim, pct, up, t, name, q, icon } und der Abgleich laeuft je Wert (Wt.Merge). Ein Manager vor 0.30 schickt nur u
-- (Zahl), dann zaehlt nur, ob beobachtet wird. Rueckgabe: true bei Aenderung
function mod:MergeWatch(data)
    if type(data) ~= "table" then return false end
    local st = Wt.Store()
    local changed = Wt.Merge(st, Wt.Gone(), data)
    for key, w in pairs(st) do
        if w.name == nil and ns.Data and ns.Data.Lookup then w.name = ns.Data.ItemName(key, ns.Data.Lookup(key)) end
    end
    if changed then Wt.Check() end
    return changed
end

-- Reiner Abgleich ohne Spiel (gleiche Regeln wie manager/src/core/watching.js, Test umbau2.test.js, watch_compare.lua)
function Wt.Merge(st, gone, data)
    local S = ns.Shop
    local changed = false
    local function Key(k)
        if type(k) == "string" and k:match("^%d+$") then return tonumber(k) end
        return k
    end
    for k, raw in pairs(type(data.items) == "table" and data.items or {}) do
        local key = Key(k)
        local bare = type(raw) ~= "table"
        local inc = bare and { u = tonumber(raw) or 0 } or raw
        local uu = tonumber(inc.u) or 0
        local w = st[key]
        local localU = w and (tonumber(w.u) or 0) or (tonumber(gone[key]) or 0)
        if not w then
            if uu > localU or gone[key] == nil then
                -- ab 0.90: als Zahl ohne Grenzen, Werte unbekannt (Zeit 0), jede Grenze ist neuer (wie watching.js)
                st[key] = bare and { u = uu, t = { buy = 0, up = 0 } } or S.NewFrom(inc, Wt.SPEC)
                gone[key] = nil
                changed = true
            end
        elseif bare then
            if uu > (tonumber(w.u) or 0) then w.u = uu; changed = true end
        elseif S.MergeFields(w, inc, Wt.SPEC, Wt.SKIP) then
            changed = true
        end
    end
    for k, u in pairs(type(data.gone) == "table" and data.gone or {}) do
        local key, uu = Key(k), tonumber(u) or 0
        local w = st[key]
        if w and uu > (tonumber(w.u) or 0) then st[key] = nil; gone[key] = uu; changed = true
        elseif not w and uu > (tonumber(gone[key]) or 0) then gone[key] = uu; changed = true end
    end
    return changed
end
