-- Beobachtung: Faelle aus umbau2.test.js mit Brokers Wt.Merge (Watch.lua) mischen, je Fall eine Zeile (wie im Test in JavaScript).
-- Aufruf: lua5.1 watch_compare.lua <Ordner Peon_Broker> <Datei mit CASES>
local dir, file = arg[1], arg[2]
Peon = { IsSecret = function() return false end }
local ns = { L = {}, mod = { db = {} } }
assert(loadfile(dir .. "/Shop.lua"))("Peon_Broker", ns)
assert(loadfile(dir .. "/Watch.lua"))("Peon_Broker", ns)
dofile(file)

local function V(v) if v == nil then return "-" end if type(v) == "number" then return ("%.0f"):format(v) end return tostring(v) end
local function Sorted(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = tostring(k) end
    table.sort(out)
    return out
end

for _, c in ipairs(CASES) do
    local st, gone = {}, {}
    -- Seite a so anlegen, wie Broker sie speichert (Zahlen als Schluessel)
    for k, w in pairs(c.a.items or {}) do st[tonumber(k) or k] = w end
    for k, u in pairs(c.a.gone or {}) do gone[tonumber(k) or k] = u end
    ns.Watch.Merge(st, gone, c.b)
    local byText, goneText = {}, {}
    for k, w in pairs(st) do byText[tostring(k)] = w end
    for k, u in pairs(gone) do goneText[tostring(k)] = u end
    local parts = {}
    for _, k in ipairs(Sorted(byText)) do
        local w = byText[k]
        local t = type(w.t) == "table" and w.t or {}
        parts[#parts + 1] = k .. ":" .. V(w.u) .. ":" .. V(w.lim) .. ":" .. V(w.pct) .. ":" .. V(w.up) .. ":" .. V(t.buy) .. ":" .. V(t.up) .. ":" .. V(w.name)
    end
    local g = {}
    for _, k in ipairs(Sorted(goneText)) do g[#g + 1] = k .. "=" .. V(goneText[k]) end
    print(table.concat(parts, ";") .. "#" .. table.concat(g, ";"))
end
