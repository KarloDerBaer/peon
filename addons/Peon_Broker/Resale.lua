-- Peon_Broker - Resale.lua
-- Ab 0.56 (Wunsch von KarloDerBaer): Im Blizzard-Kauffenster fuer Massenware steht unter "Kaufen", was man verdienen
-- koennte, wenn man die gewaehlte Menge kauft und zum naechsten Preis wieder einstellt.
--   * Naechster Preis = guenstigstes Angebot, das nach dem Kauf noch uebrig ist (meist die naechst hoehere Preisstufe).
--   * Erloes = Menge x naechster Preis abzueglich des Anteils des Hauses (gemessen je Markt, Cut.lua).
--   * Kosten = Gesamtpreis aus Blizzards Fenster.
-- Technik: sicherer Anhang an SetPrice der Kaufanzeige (Blizzard ruft das bei jeder Mengenaenderung). Broker liest
-- Gegenstand, Menge und Gesamtpreis nur aus und die Angebote, die Blizzard fuer das Fenster ohnehin geladen hat.
-- Bei "Blizzard pur" gibt es weder Anhang noch Zeile.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local R = {}
ns.Resale = R

local GREY = "|cff999999"

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end

-- Reine Rechnung. rows = Preisstufen { price, qty } guenstigste zuerst, qty = Menge, cost = Gesamtpreis (nil = aus
-- den Stufen), cut = Anteil des Hauses. Rueckgabe { next, cost, net, profit } oder nil (zu wenig Angebote, nichts danach)
function R.Calc(rows, qty, cost, cut)
    if type(rows) ~= "table" or not Num(qty) or qty <= 0 then return nil end
    local left, sum, nextPrice = qty, 0, nil
    for i, r in ipairs(rows) do
        if Num(r.price) and Num(r.qty) and r.qty > 0 then
            if left > 0 then
                local take = math.min(left, r.qty)
                sum = sum + take * r.price
                left = left - take
                if left == 0 and r.qty > take then nextPrice = r.price; break end
            else
                nextPrice = r.price
                break
            end
        end
    end
    if left > 0 or not nextPrice then return nil end
    cost = Num(cost) and cost > 0 and cost or sum
    local net = math.floor(qty * nextPrice * (1 - (cut or 0.05)))
    return { next = nextPrice, cost = cost, net = net, profit = net - cost }
end

local function AHFrame()
    local f = rawget(_G, "AuctionHouseFrame")
    return type(f) == "table" and f or nil
end

local function Display()
    local f = AHFrame()
    local bf = f and rawget(f, "CommoditiesBuyFrame")
    local d = type(bf) == "table" and rawget(bf, "BuyDisplay") or nil
    return type(d) == "table" and d or nil
end

local function Call(obj, name, ...)
    if type(obj) ~= "table" or type(obj[name]) ~= "function" then return nil end
    local ok, v = pcall(obj[name], obj, ...)
    if ok and not Peon.IsSecret(v) then return v end
    return nil
end

local function Line(d)
    if R.line then return R.line end
    local anchor = rawget(d, "BuyButton")
    local fs = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if type(anchor) == "table" then fs:SetPoint("TOP", anchor, "BOTTOM", 0, -14)
    else fs:SetPoint("BOTTOM", d, "BOTTOM", 0, 90) end
    fs:SetWidth(330)
    fs:SetJustifyH("CENTER")
    local sub = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOP", fs, "BOTTOM", 0, -4)
    sub:SetWidth(330)
    sub:SetJustifyH("CENTER")
    fs.sub = sub
    R.line = fs
    return fs
end

function R.Hide()
    if R.line then R.line:Hide(); R.line.sub:Hide() end
end

-- Neu rechnen (nach SetPrice oder neuen Angeboten)
function R.Update()
    if not ns.AHTouch() then return end
    local d = Display()
    if not d or not (d.IsShown and d:IsShown()) then R.Hide(); return end
    local id = Call(d, "GetItemID")
    local qty = d.QuantityInput and Call(d.QuantityInput, "GetQuantity")
    local total = d.TotalPrice and Call(d.TotalPrice, "GetAmount")
    if not Num(id) or not Num(qty) or qty <= 0 or not ns.Live then R.Hide(); return end
    local rows = ns.Live.ReadCommodity(id)
    if type(rows) ~= "table" or rows.foreign then R.Hide(); return end
    local r = R.Calc(rows, qty, total, ns.Data.Cut())
    local fs = Line(d)
    if not r then
        fs:SetText(GREY .. L.RESALE_NONE .. "|r")
        fs.sub:SetText("")
    else
        local color = r.profit > 0 and "|cff60e060" or "|cffff5050"
        local sign = r.profit >= 0 and "+" or "−"
        fs:SetText(L.RESALE_LINE:format(Money(r.next), color .. sign .. Money(math.abs(r.profit)) .. "|r"))
        fs.sub:SetText(L.RESALE_SUB:format(math.floor(ns.Data.Cut() * 100 + 0.5)))
    end
    fs:Show(); fs.sub:Show()
    R.last = r
end

function R.Hook()
    if R.hooked or not ns.AHTouch() or not hooksecurefunc then return end
    local d = Display()
    if not d or type(d.SetPrice) ~= "function" then return end
    hooksecurefunc(d, "SetPrice", function() mod:Call("Weiterverkauf", R.Update) end)
    if d.HookScript then d:HookScript("OnHide", function() R.Hide() end) end
    R.hooked = true
end

function R.Init()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function() mod:Call("Weiterverkauf", R.Hook) end)
    mod:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", function() mod:Call("Weiterverkauf", R.Update) end)
end
