-- Vergleich JS gegen Broker: laedt Peon_Broker/Sales.lua mit Minimal-Stubs und rechnet S.Compare fuer Faelle aus stdin.
-- Eingabe je Zeile: tA tB commodity withIds cap cancel | A-Angebote | B-Angebote ; Angebot = id,q,p,lo,hi
local dir = arg[1]
Peon = { IsSecret = function() return false end }
local ns = { L = {}, mod = { db = {} }, Data = {} }
local f = assert(loadfile(dir .. "/Sales.lua"))
f("Peon_Broker", ns)
local S = ns.Sales
local function list(s)
  local out = {}
  for id, q, p, lo, hi in s:gmatch("(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)") do
    out[#out + 1] = { id = tonumber(id), q = tonumber(q), p = tonumber(p), lo = tonumber(lo), hi = tonumber(hi) }
  end
  return out
end
for line in io.lines() do
  local head, a, b = line:match("^([^|]*)|([^|]*)|([^|]*)$")
  local tA, tB, c, w, cap, pct = head:match("(%d+) (%d+) (%d) (%d) (%d+) ([%d%.]+)")
  local so, ex, ca = S.Compare(list(a), list(b), tonumber(tA), tonumber(tB), tonumber(cap), c == "1", w == "1", tonumber(pct))
  print(("%.4f %.4f %.4f"):format(so, ex, ca))
end
