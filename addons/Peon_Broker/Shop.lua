-- Peon_Broker - Shop.lua
-- Abgleich der Einkaufslisten mit dem Peon Manager. Beide Seiten koennen aendern.
-- Aufbau: lists = { { id, name, pct, u, t, items = { [Schluessel] = { wish, max, name, q, icon, u, t } } } },
--         gone = { lists = { [id] = Zeit }, items = { ["id|Schluessel"] = Zeit } } (Loeschmarken).
-- u = letzte Aenderung des ganzen Eintrags (Anlegen, Loeschen), t = Zeit je Wert.
-- Ab 0.89 (Manager-Angleichung A2, Peon_Manager_Angleichung.md 3.2): Abgleich je Wert. Jeder Wert (Name und Rabatt
-- einer Liste, Menge und Hoechstpreis eines Eintrags) traegt seine eigene Zeit in t, die neuere gewinnt. Ohne t
-- (Daten von vor 0.89) gilt u fuer alle Werte. Name, Qualitaet und Symbol eines Gegenstands sind nur Anzeige und
-- werden ergaenzt, wo sie fehlen. Bei gleicher Zeit bleibt der eigene Stand.
-- Die Regeln muessen gleich bleiben wie in manager/src/core/shopping.js (Test: umbau2.test.js, shop_compare.lua).

local ADDON_NAME, ns = ...

local S = {}
ns.Shop = S

S.GONE_DAYS = 365   -- so lange bleiben Loeschmarken stehen (bis 0.88 60 Tage)

-- Werte mit eigener Zeit: f = Name der Zeit in t, keys = Felder, die zusammen diesen Wert bilden,
-- reset = Merker, der bei einem neuen Wert aus dem Abgleich wegfaellt
S.LIST_SPEC = { { f = "name", keys = { "name" } }, { f = "pct", keys = { "pct" } } }
S.ITEM_SPEC = { { f = "wish", keys = { "wish" } }, { f = "max", keys = { "max" } } }

local function Num(v) return tonumber(v) or 0 end

function S.Find(lists, id)
    for i, l in ipairs(lists) do
        if l.id == id then return l, i end
    end
    return nil
end

-- Schluessel aus einer Loeschmarke: Zahl wie in den Listen, sonst Text
local function KeyOf(text)
    return tonumber(text) or text
end

-- Zeit eines Werts: eigene Zeit, sonst die Zeit des ganzen Eintrags
function S.FieldT(obj, f)
    local t = type(obj.t) == "table" and obj.t[f]
    if type(t) == "number" then return t end
    return Num(obj.u)
end

-- Felder, die nicht als Anzeige ergaenzt werden: u, t, die Werte mit Zeit und extra
function S.Skip(spec, extra)
    local skip = { u = true, t = true }
    for _, s in ipairs(spec) do for _, k in ipairs(s.keys) do skip[k] = true end end
    for _, k in ipairs(extra or {}) do skip[k] = true end
    return skip
end
S.LIST_SKIP = S.Skip(S.LIST_SPEC, { "id", "items" })
S.ITEM_SKIP = S.Skip(S.ITEM_SPEC)

-- Fehlende Zeiten aus u eintragen, bevor sich u aendert
function S.Fill(obj, spec)
    if type(obj.t) ~= "table" then obj.t = {} end
    for _, s in ipairs(spec) do
        if type(obj.t[s.f]) ~= "number" then obj.t[s.f] = Num(obj.u) end
    end
end

-- Eigene Aenderung eines Werts vermerken: u und die Zeit des Werts neu (immer spaeter als vorher)
function S.Stamp(obj, spec, f, now)
    S.Fill(obj, spec)
    obj.u = S.NextU(now, obj.u, obj.t[f])
    obj.t[f] = obj.u
    return obj.u
end

-- Neuer Eintrag aus dem Abgleich: Kopie ohne Tabellen, Zeiten je Wert eingetragen
function S.NewFrom(inc, spec)
    local c = {}
    for k, v in pairs(inc) do if type(v) ~= "table" and k ~= "m" then c[k] = v end end
    c.u = Num(inc.u)
    c.t = {}
    for _, s in ipairs(spec) do c.t[s.f] = S.FieldT(inc, s.f) end
    return c
end

-- inc in einen vorhandenen Eintrag cur einmischen: je Wert die neuere Zeit, Anzeige nur, wo sie fehlt, u = die neuere.
-- Rueckgabe: true, wenn sich etwas geaendert hat
function S.MergeFields(cur, inc, spec, skip)
    local changed = false
    S.Fill(cur, spec)
    for _, s in ipairs(spec) do
        local ti = S.FieldT(inc, s.f)
        if ti > cur.t[s.f] then
            for _, k in ipairs(s.keys) do cur[k] = inc[k] end
            if s.reset then cur[s.reset] = nil end
            cur.t[s.f] = ti
            changed = true
        end
    end
    for k, v in pairs(inc) do
        if not skip[k] and k ~= "m" and cur[k] == nil and type(v) ~= "table" then cur[k] = v; changed = true end
    end
    if Num(inc.u) > Num(cur.u) then cur.u = Num(inc.u); changed = true end
    return changed
end

-- inc = { lists, gone } einmischen. Rueckgabe: true, wenn sich etwas geaendert hat
function S.Merge(lists, gone, inc)
    if type(inc) ~= "table" then return false end
    local changed = false
    for _, il in ipairs(type(inc.lists) == "table" and inc.lists or {}) do
        if type(il) == "table" and type(il.id) == "string" then
            local iu = Num(il.u)
            local goneL = Num(gone.lists[il.id])
            local l = S.Find(lists, il.id)
            local skip = false
            if not l then
                if goneL >= iu then
                    skip = true
                else
                    l = S.NewFrom(il, S.LIST_SPEC)
                    l.items = {}
                    lists[#lists + 1] = l
                    gone.lists[il.id] = nil
                    changed = true
                end
            elseif S.MergeFields(l, il, S.LIST_SPEC, S.LIST_SKIP) then
                changed = true
            end
            if not skip then
                for key, it in pairs(type(il.items) == "table" and il.items or {}) do
                    if type(it) == "table" then
                        local u = Num(it.u)
                        local gk = il.id .. "|" .. tostring(key)
                        local cur = l.items[key]
                        if cur then
                            if S.MergeFields(cur, it, S.ITEM_SPEC, S.ITEM_SKIP) then changed = true end
                        elseif u > Num(gone.items[gk]) then
                            l.items[key] = S.NewFrom(it, S.ITEM_SPEC)
                            gone.items[gk] = nil
                            changed = true
                        end
                    end
                end
            end
        end
    end
    local g = type(inc.gone) == "table" and inc.gone or {}
    for id, t in pairs(type(g.lists) == "table" and g.lists or {}) do
        local when = Num(t)
        local l, at = S.Find(lists, id)
        if l and when >= Num(l.u) then
            table.remove(lists, at)
            l = nil
            changed = true
        end
        if not l and when > Num(gone.lists[id]) then
            gone.lists[id] = when
            changed = true
        end
    end
    for gk, t in pairs(type(g.items) == "table" and g.items or {}) do
        local when = Num(t)
        local id, text = tostring(gk):match("^(.-)|(.*)$")
        if id then
            local key = KeyOf(text)
            local l = S.Find(lists, id)
            local cur = l and l.items[key]
            if cur and when >= Num(cur.u) then
                l.items[key] = nil
                cur = nil
                changed = true
            end
            if not cur and when > Num(gone.items[gk]) then
                gone.items[gk] = when
                changed = true
            end
        end
    end
    return changed
end

-- Alte Loeschmarken entfernen
function S.Purge(gone, now)
    local limit = now - S.GONE_DAYS * 86400
    for _, part in ipairs({ gone.lists, gone.items }) do
        for k, t in pairs(part) do
            if Num(t) < limit then part[k] = nil end
        end
    end
end

-- Zeit fuer eine Aenderung: immer spaeter als die letzte, auch innerhalb einer Sekunde
function S.NextU(now, ...)
    local u = now
    for i = 1, select("#", ...) do
        local old = select(i, ...)
        if old and Num(old) + 1 > u then u = Num(old) + 1 end
    end
    return u
end
