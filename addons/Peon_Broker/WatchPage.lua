-- Peon_Broker - WatchPage.lua
-- Ab 0.82 (KarloDerBaer, 12.11.2026): eigener Reiter "Beobachten" (vorher besondere Liste in Einkaufen).
-- Passt zur Logik von Beobachtung und Fokus: je Gegenstand "Kaufen bis" (Grenze nach unten, Preisalarm) und
-- "Zielpreis" (der Preis, ab dem man verkaufen wuerde, Grenze nach oben, Meldung wenn der Preis darueber liegt).
-- Beides setzt man am einfachsten im Fokus und speichert es dort mit "Speichern".
--   Liste   Gegenstand, Preis (guenstigstes Angebot), Kaufen bis, Zielpreis, Ueblich, Rat (KAUFEN / VERKAUFEN)
--   Klick   in den Fokus, mit den gespeicherten Werten (Art "Beobachten")
--   unten   Im Markt zeigen (sicherer Knopf), Entfernen
-- Daten aus Watch.lua (PeonBrokerDB.watch: lim/pct = Kaufen bis, up = Zielpreis).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local P = {}
ns.WatchPage = P

local GREY, GREEN, GOLD = "|cff999999", "|cff60e060", "|cffffd100"
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end

-- Zeilen der Liste
function P.Rows()
    local Wt, D = ns.Watch, ns.Data
    local rows = {}
    for key, w in pairs(Wt.Store()) do
        local e = D.Lookup(key)
        local price = type(e) == "table" and not e.gone and Num(e.m) and e.m or nil
        local limit = Wt.Limit(key, e)
        local target = Num(w.up) and w.up or nil
        local advice
        if price and limit and price <= limit then advice = "buy"
        elseif price and target and price >= target then advice = "sell" end
        local band = type(e) == "table" and e.m and ns.Buyout.Context(e, key).band or nil
        rows[#rows + 1] = {
            key = key, name = w.name or D.ItemName(key, e) or tostring(key), quality = w.q or (type(e) == "table" and e.ql) or nil,
            icon = w.icon or ns.Buy.Icon(D.ItemID(key)), link = D.LinkFromKey and D.LinkFromKey(key) or nil,
            price = price, limit = limit, target = target, advice = advice,
            bandLow = type(band) == "table" and Num(band.low) and band.low or nil,
            bandHigh = type(band) == "table" and Num(band.high) and band.high or nil,
        }
    end
    return rows
end

-- Zahl am Reiter: Gegenstaende mit Rat KAUFEN oder VERKAUFEN
function P.Count()
    local n = 0
    for _, r in ipairs(P.Rows()) do if r.advice then n = n + 1 end end
    return n
end

function P.UpdateBadge()
    local T = ns.AHTabs
    if T and T.SetBadge and T.built then T.SetBadge("watch", P.Count(), false) end
end

function P.Build(c)
    local UI = Peon.UI
    P.frame = c
    local lp = UI.Panel(c, "list", true)
    lp:SetPoint("TOPLEFT", 0, -30)
    lp:SetPoint("BOTTOMRIGHT", 0, 34)
    P.panel = lp
    P.hint = UI.Text(c, "small", GREY .. L.WATCH_HINT .. "|r", 520)
    P.hint:SetPoint("TOPLEFT", 70, -10)
    P.list = UI.Table(lp, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
              color = function(r) return UI.QualityColor(r.quality or 1) end },
            { key = "price", title = L.WATCH_COL_PRICE, width = 100, align = "RIGHT", format = function(v) return Num(v) and Money(v) or (GREY .. "-|r") end },
            { key = "limit", title = L.FOCUS_R_LIMIT, width = 100, align = "RIGHT", format = function(v) return Num(v) and Money(v) or (GREY .. "-|r") end },
            { key = "target", title = L.FOCUS_R_TARGET, width = 100, align = "RIGHT", format = function(v) return Num(v) and Money(v) or (GREY .. "-|r") end },
            { key = "bandLow", title = L.FOCUS_R_BAND, width = 140, align = "RIGHT",
              format = function(_, r)
                  if not (r.bandLow and r.bandHigh) then return GREY .. "-|r" end
                  return L.FOCUS_BAND:format(Money(math.floor(r.bandLow + 0.5)), Money(math.floor(r.bandHigh + 0.5)))
              end },
            { key = "advice", title = L.WATCH_COL_ADVICE, width = 96, align = "RIGHT",
              format = function(v)
                  if v == "buy" then return GREEN .. L.WATCH_ADV_BUY .. "|r" end
                  if v == "sell" then return GOLD .. L.WATCH_ADV_SELL .. "|r" end
                  return ""
              end,
              sort = function(r) return r.advice == "buy" and 1 or r.advice == "sell" and 2 or 3 end },
        },
        sortKey = "name", icon = true, empty = L.WATCH_EMPTY,
        onClick = function(r, button)
            P.selected = r
            if button == "RightButton" then ns.Go.Menu(r, P.panel); P.UpdateButtons(); return end
            -- Klick: in den Fokus mit den gespeicherten Werten
            mod:Call("Sprung", ns.Go.Focus, { key = r.key, name = r.name, from = "watch" })
        end,
        onEnter = function(row, r) if r then W.ShowItemTooltip(row, r.key) end end,
    })
    function P.list:GetItems() return self.items end
    P.removeButton = UI.Button(c, L.WATCH_REMOVE, 130, function()
        if P.selected then ns.Watch.Remove(P.selected.key); P.selected = nil; P.Refresh() end
    end)
    P.removeButton:SetPoint("BOTTOMRIGHT", -2, 4)
    P.marketButton = ns.Go.MarketButton(c, 150, function() return P.selected and { key = P.selected.key, name = P.selected.name } or nil end)
    P.marketButton:SetPoint("RIGHT", P.removeButton, "LEFT", -6, 0)
    P.Refresh()
end

function P.UpdateButtons()
    if not P.removeButton then return end
    if P.selected then P.removeButton:Enable(); P.marketButton:Enable() else P.removeButton:Disable(); P.marketButton:Disable() end
end

function P.Refresh()
    P.UpdateBadge()
    if not P.list then return end
    local rows = P.Rows()
    P.list:SetData(rows)
    local keep
    for _, r in ipairs(rows) do if P.selected and r.key == P.selected.key then keep = r end end
    P.selected = keep
    P.UpdateButtons()
end

W.pages.watch = {
    build = P.Build,
    refresh = function() P.Refresh() end,
}
