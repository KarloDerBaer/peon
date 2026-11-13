-- Einkaufslisten: Faelle aus umbau2.test.js mit Brokers Shop.lua mischen, je Fall eine Zeile (wie im Test in JavaScript).
-- Aufruf: lua5.1 shop_compare.lua <Ordner Peon_Broker> <Datei mit CASES>
local dir, file = arg[1], arg[2]
local ns = {}
assert(loadfile(dir .. "/Shop.lua"))("Peon_Broker", ns)
dofile(file)

local function V(v) if v == nil then return "-" end if type(v) == "number" then return ("%.0f"):format(v) end return tostring(v) end
local function T(o, f) return type(o.t) == "table" and o.t[f] or nil end
local function Sorted(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = tostring(k) end
    table.sort(out)
    return out
end

for _, c in ipairs(CASES) do
    local lists, gone = c.a.lists, c.a.gone
    ns.Shop.Merge(lists, gone, c.b)
    local parts = {}
    table.sort(lists, function(x, y) return x.id < y.id end)
    for _, l in ipairs(lists) do
        local items = {}
        local byText = {}
        for k, it in pairs(l.items) do byText[tostring(k)] = it end
        for _, k in ipairs(Sorted(byText)) do
            local it = byText[k]
            items[#items + 1] = k .. ":" .. V(it.wish) .. ":" .. V(it.max) .. ":" .. V(it.u) .. ":" .. V(T(it, "wish")) .. ":" .. V(T(it, "max")) .. ":" .. V(it.name)
        end
        parts[#parts + 1] = l.id .. "=" .. tostring(l.name) .. "," .. V(l.pct) .. "," .. V(l.u) .. "," .. V(T(l, "name")) .. "," .. V(T(l, "pct")) .. "[" .. table.concat(items, " ") .. "]"
    end
    local g = {}
    for _, k in ipairs(Sorted(gone.lists)) do g[#g + 1] = "L" .. k .. "=" .. V(gone.lists[k]) end
    for _, k in ipairs(Sorted(gone.items)) do g[#g + 1] = "I" .. k .. "=" .. V(gone.items[k]) end
    print(table.concat(parts, ";") .. "#" .. table.concat(g, ";"))
end
