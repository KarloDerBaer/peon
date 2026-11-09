-- Peon_Broker - Stock.lua
-- Ab 0.55 (Umbau U12): Vorrat zaehlen. Bis 0.54 Teil von Keep.lua (Behalten), Behalten entfaellt.
-- Vorrat = Taschen + Bank (C_Item.GetItemCount mit Bank, geht auch bei geschlossener Bank). Mit dem Haken
-- "Vorrat aller Charaktere" (mod.db.keepAllChars, Name bleibt) zaehlen auch Taschen, Bank und Post der anderen
-- Charaktere und die Accountbank aus Peon_Ledger (nur wenn geladen).
-- Nutzen: Einkaufsliste (Fehlt), Info (Mein Bestand), Marktvergleich (Nur Bestand), Berufsfenster.

local ADDON_NAME, ns = ...
local mod = ns.mod

local K = {}
ns.Stock = K

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

local function ItemCount(id, bank)
    local fn = (C_Item and C_Item.GetItemCount) or rawget(_G, "GetItemCount")
    if not fn or not id then return nil end
    local ok, n
    if bank then ok, n = pcall(fn, id, true, false, true) else ok, n = pcall(fn, id) end
    if ok and Num(n) then return n end
    return nil
end

-- Peon_Ledger (wenn geladen, nur lesend)
function K.Ledger()
    if not Peon.GetModule then return nil end
    local ok, l = pcall(Peon.GetModule, Peon, "ledger")
    if ok and type(l) == "table" and type(l.StockOthers) == "function" then return l end
    return nil
end

function K.AllChars() return mod.db.keepAllChars == true and K.Ledger() ~= nil end

-- Vorrat der anderen Charaktere (Taschen, Bank, Post) und der Accountbank; 0 ohne Ledger oder Haken aus
function K.Others(id)
    if not id or not K.AllChars() then return 0 end
    local l = K.Ledger()
    local ok, n = pcall(l.StockOthers, l, id)
    if ok and Num(n) then return n end
    return 0
end

-- Taschen, Bank, Vorrat gesamt, andere Charaktere; bags = bereits gezaehlte Menge in den Taschen (sonst vom Spiel)
function K.Counts(id, bags)
    local carrying = ItemCount(id, false)
    bags = bags or carrying or 0
    local withBank = ItemCount(id, true)
    local bank = 0
    if withBank and carrying then bank = math.max(0, withBank - carrying) end
    local others = K.Others(id)
    return bags, bank, bags + bank + others, others
end
