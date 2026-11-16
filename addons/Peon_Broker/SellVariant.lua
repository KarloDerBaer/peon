-- Peon_Broker - SellVariant.lua
-- ab 0.98.0 (Wunsch KarloDerBaer 16.11.2026): Im Verkaufen zeigt Blizzards Liste bei Gegenstaenden mit Zusatz
-- ("... des Baeren", "... des Banditen") die Angebote aller Varianten. Broker legt dann eine eigene Liste darueber,
-- die nur die Angebote genau dieser Variante zeigt (gleicher Weg wie "Zum Einstellen" in Lots.lua: eigene Flaeche,
-- Blizzards Liste bleibt darunter unberuehrt). Ein Klick auf eine Zeile traegt ihren Preis ein (wie ein Klick in
-- Blizzards Liste, ueber Lots.FillTarget). Der Knopf ueber der Liste schaltet zwischen "nur diese Variante" und
-- Blizzards Liste mit allen Varianten um (Einstellung sellVariantOnly).
-- Die Angebote liest Advice.lua aus Blizzards Ergebnissen (A.var, gefiltert mit Live.ReadItems). Liefert das Spiel
-- die Ergebnisse in Teilen, fordert Broker den Rest an wie Blizzards Liste beim Blaettern (hoechstens Live.MORE_MAX).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local VS = {}
ns.SellVariant = VS

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function AHF() local f = rawget(_G, "AuctionHouseFrame"); return type(f) == "table" and f or nil end

-- Blizzards Liste rechts beim Verkaufen eines Einzelgegenstands, wenn sie zu sehen ist
function VS.ItemList()
    local f = AHF()
    local l = f and rawget(f, "ItemSellList")
    if type(l) == "table" and l.IsShown and l:IsShown() then return l end
    return nil
end

-- Soll die Liste gerade zu sehen sein? Rueckgabe: Blizzards Liste, Varianten-Stand (A.var)
function VS.Wanted()
    if not ns.AHTouch() then return nil end
    if ns.AHTabs and ns.AHTabs.current then return nil end
    local A = ns.Advice
    local v, it = A and A.var, A and A.current
    if not (v and it and v.key == it.key and (v.other or 0) > 0) then return nil end
    local list = VS.ItemList()
    if not list then return nil end
    return list, v
end

function VS.Build()
    if VS.panel or not ns.AHTouch() then return end
    local f, UI = AHF(), Peon.UI
    if not (f and UI) then return end
    -- Umschalter ueber Blizzards Liste links (rechts steht "Zum Einstellen")
    local t = UI.Button(f, L.SVAR_SHOW_ALL, 170, function()
        mod.db.sellVariantOnly = not (mod.db.sellVariantOnly ~= false)
        VS.Refresh()
    end)
    t:SetFrameLevel(520)
    UI.SetTooltip(t, { L.SVAR_TITLE, L.SVAR_TIP })
    t:Hide()
    VS.toggle = t
    -- Flaeche ueber Blizzards Liste, unter der Flaeche "Zum Einstellen" (370)
    local p = CreateFrame("Frame", "PeonBrokerSellVariantPanel", f)
    p:SetFrameLevel(360)
    p:EnableMouse(true)
    local under = p:CreateTexture(nil, "BACKGROUND", nil, -8)
    under:SetAllPoints(p)
    under:SetColorTexture(0.05, 0.05, 0.05, 1)
    p:Hide()
    VS.panel = p
    local lp = UI.Panel(p, "list", true)
    lp:SetPoint("TOPLEFT", 0, 0)
    lp:SetPoint("BOTTOMRIGHT", 0, 24)
    VS.list = UI.Table(lp, {
        columns = {
            { key = "price", title = L.SVAR_COL_PRICE, align = "RIGHT", format = function(v) return ns.Tooltip.Money(v) end },
            { key = "qty", title = L.FOCUS_R_QTY, width = 70, align = "RIGHT" },
            { key = "own", title = L.SVAR_COL_OWN, width = 70, align = "RIGHT",
              format = function(v) return (v or 0) > 0 and ("|cff66ccff" .. L.SVAR_OWN .. "|r") or "" end },
        },
        sortKey = "price", empty = L.SVAR_EMPTY,
        onClick = function(r) mod:Call("Varianten", VS.Pick, r) end,
    })
    function VS.list:GetItems() return self.items end
    VS.hint = UI.Text(p, "small", "", 400)
    VS.hint:SetPoint("BOTTOMLEFT", 6, 6)
    VS.Refresh()
end

-- Zeile gewaehlt: ihren Preis in Blizzards Preisfeld schreiben
function VS.Pick(r)
    if not (r and Num(r.price)) or not ns.Lots or not ns.Lots.CanFill() then return false end
    local f = AHF()
    local sf = f and rawget(f, "ItemSellFrame")
    if type(sf) ~= "table" then return false end
    return ns.Lots.FillTarget(sf, { target = r.price })
end

-- Rest der Ergebnisse anfordern, wenn das Spiel sie in Teilen liefert (je Gegenstand hoechstens Live.MORE_MAX mal)
function VS.MaybeMore(v)
    if not (v and v.partial and type(v.itemKey) == "table" and ns.Live and ns.Live.RequestMore) then return end
    VS.more = VS.more or {}
    local n = VS.more[v.key] or 0
    if n >= (ns.Live.MORE_MAX or 5) then return end
    VS.more[v.key] = n + 1
    ns.Live.RequestMore({ itemKey = v.itemKey }, false)
end

function VS.Refresh()
    if not VS.panel then return end
    local list, v = VS.Wanted()
    if not list then
        VS.toggle:Hide()
        VS.panel:Hide()
        return
    end
    local only = mod.db.sellVariantOnly ~= false
    VS.toggle:ClearAllPoints()
    VS.toggle:SetPoint("BOTTOMLEFT", list, "TOPLEFT", 0, 4)
    VS.toggle:SetText(only and L.SVAR_SHOW_ALL or L.SVAR_SHOW_ONLY)
    VS.toggle:Show()
    if not only then VS.panel:Hide(); return end
    VS.panel:ClearAllPoints()
    VS.panel:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
    VS.panel:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)
    VS.panel:Show()
    local rows = {}
    for i, r in ipairs(v.rows or {}) do rows[i] = { price = r.price, qty = r.qty, own = r.own } end
    VS.list:SetData(rows)
    VS.hint:SetText(L.SVAR_HINT:format(v.other or 0) .. (v.partial and (" " .. L.SVAR_PARTIAL) or ""))
    VS.MaybeMore(v)
end

function VS.Init()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function()
        mod:Call("Varianten", function()
            VS.Build()
            local f = AHF()
            if VS.hooked or not f then return end
            for _, name in ipairs({ "ItemSellFrame", "ItemSellList", "CommoditiesSellFrame" }) do
                local sf = rawget(f, name)
                if type(sf) == "table" and sf.HookScript then
                    sf:HookScript("OnShow", function() mod:Call("Varianten", VS.Refresh) end)
                    sf:HookScript("OnHide", function() mod:Call("Varianten", VS.Refresh) end)
                    VS.hooked = true
                end
            end
        end)
    end)
    mod:RegisterEvent("AUCTION_HOUSE_CLOSED", function() VS.more = nil; if VS.panel then VS.panel:Hide(); VS.toggle:Hide() end end)
end
