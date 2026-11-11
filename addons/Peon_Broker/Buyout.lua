-- Peon_Broker - Buyout.lua
-- Stufe 2, H1 (ab 0.65, Konzept Peon_Broker_Neuaufbau.md, Abschnitt 6.1): Radar-Art "Aufkauf".
-- Vorgehen von KarloDerBaer: Massenware bis zu einer Preisstufe aufkaufen und zum Preis der naechsten Stufe wieder
-- einstellen. Bei gleichem Preis verkauft das Spiel die zuletzt eingestellte Ware zuerst, wer genau zum Preis der
-- naechsten Stufe einstellt, steht also vorn.
--
-- Fuer jede Stelle zwischen zwei Preisstufen: Kauf aller Stueck darunter (Menge, Einsatz), Zielpreis = Preis der
-- naechsten Stufe, Gewinn = Menge x Zielpreis nach Anteil des Hauses minus Einsatz. Eine Stelle zaehlt, wenn
--   1. aufkaufbar: Einsatz hoechstens Gold minus Goldreserve (radarReserve)
--   2. Gewinn mindestens dealMinMarket (Silber, Vorgabe 50s)
--   3. schnell wieder verkauft: Menge / Absatz je Stunde hoechstens buyoutHours (Vorgabe 2 Std.)
--   4. kein anhaltender Trend nach unten (D.Band: aktueller und vorheriger Median unter dem ueblichen Bereich)
-- Je Gegenstand zaehlt die Stelle mit dem hoechsten Gewinn. Einen Mindestsprung in Prozent gibt es nicht, der
-- uebliche Bereich filtert nicht. Nur Massenware (Einzelgegenstaende haben keine Preisstufen in diesem Sinn).
--
-- Risiko als Ampel aus Punkten (Startwerte, Entscheidungen 12.11.2026, mit echten Daten nachzuschaerfen):
--   Verkaufsdauer ueber 75 % der Grenze                        +1
--   viel Ware knapp ueber dem Ziel (bis 5 %), mehr als der
--     Absatz in der hoechsten Verkaufsdauer                    +1
--   duenne naechste Stufe (unter 5 Stueck oder unter 10 % meiner Menge)  +1
--   Einsatz mehr als die Haelfte des verfuegbaren Golds         +1
--   Stand aelter als 30 Min. +1, aelter als 2 Std. +2
--   wenig Absatzdaten (Sicherheit rot) oder kein ueblicher Bereich  +1
--   0 Punkte gruen, 1 bis 2 gelb, ab 3 rot

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local B = {}
ns.Buyout = B

B.RISK_HOURS_PART = 0.75
B.RISK_NEAR_PCT   = 0.05
B.RISK_THIN_MIN   = 5
B.RISK_THIN_PART  = 0.10
B.RISK_GOLD_PART  = 0.5
B.RISK_OLD        = 1800
B.RISK_VERY_OLD   = 7200
B.RISK_MID, B.RISK_HIGH = 1, 3

function B.MaxHours() return tonumber(mod.db.buyoutHours) or 2 end
function B.MinGain() return (tonumber(mod.db.dealMinMarket) or 50) * 100 end

-- Schnelle Vorauswahl beim Laden aus der Datenbank: Massenware mit mindestens zwei gespeicherten Preisstufen
function B.Candidate(e, key)
    if type(e) ~= "table" or type(e.lv) ~= "string" or not e.lv:find(";", 1, true) then return false end
    return ns.Data.IsCommodity(key) and true or false
end

-- Absatz und Trend eines Gegenstands (teuer, darum einmal je Bewertung): { sales, perHour, band }
function B.Context(e, key)
    local sales = ns.Sales and ns.Sales.Stats(e, nil, key) or nil
    local band = type(e) == "table" and ns.Data.Band(e, e.md, e.pmd, nil, key) or nil
    return { sales = sales, perHour = sales and tonumber(sales.perHour) or 0, band = band }
end

-- Beste Stelle fuer einen Aufkauf. rows = Preisstufen { price, qty, own } (Scan oder live), budget = Gold, das
-- ausgegeben werden darf (nil = unbekannt, dann ohne Grenze), commodity = Warenart (nil = aus der Datenbank),
-- ctx = B.Context (optional). Rueckgabe: Chance oder nil, Grund ("item", "levels", "gain", "gold", "sales", "trend", "slow")
function B.Find(e, rows, key, budget, commodity, ctx)
    local D = ns.Data
    if commodity == false or (commodity == nil and not D.IsCommodity(key)) then return nil, "item" end
    local lv = D.Available(rows)
    if #lv < 2 then return nil, "levels" end
    local cut, minGain = D.Cut(), B.MinGain()
    local cands, qty, cost, poor = {}, 0, 0, false
    for i = 1, #lv - 1 do
        qty, cost = qty + lv[i].qty, cost + lv[i].qty * lv[i].price
        if budget and cost > budget then poor = true; break end   -- teurer wird es nur noch
        local target = lv[i + 1].price
        local gain = math.floor(qty * target * (1 - cut) - cost)
        if gain >= minGain then cands[#cands + 1] = { i = i, qty = qty, cost = cost, target = target, gain = gain } end
    end
    if #cands == 0 then return nil, poor and "gold" or "gain" end
    ctx = ctx or B.Context(e, key)
    if not ctx.perHour or ctx.perHour <= 0 then return nil, "sales" end
    if ctx.band and ctx.band.trend == "down" then return nil, "trend" end
    local maxH, best = B.MaxHours(), nil
    for _, c in ipairs(cands) do
        c.hours = c.qty / ctx.perHour
        if c.hours <= maxH and (not best or c.gain > best.gain) then best = c end
    end
    if not best then return nil, "slow" end
    local near = 0
    for j = best.i + 1, #lv do
        if lv[j].price <= best.target * (1 + B.RISK_NEAR_PCT) then near = near + lv[j].qty end
    end
    return {
        kind = "buyout", gain = best.gain, qty = best.qty, cost = best.cost, offer = lv[1].price,
        limit = lv[best.i].price, ref = best.target, net = best.target * (1 - cut), hours = best.hours,
        perHour = ctx.perHour, sales = ctx.sales, band = ctx.band, nextQty = lv[best.i + 1].qty, nearQty = near,
        level = best.i, unitGain = best.gain / best.qty,
    }
end

-- Chance mit neuem Gold neu rechnen (Preisstufen, Absatz und Trend bleiben). Rueckgabe: true = gilt noch
function B.Refit(d, budget)
    local nd = B.Find(nil, d.rows, d.key, budget, d.commodity, { sales = d.sales, perHour = d.perHour, band = d.band })
    if not nd then return false end
    for _, k in ipairs({ "gain", "qty", "cost", "offer", "limit", "ref", "net", "hours", "nextQty", "nearQty", "level", "unitGain" }) do
        d[k] = nd[k]
    end
    return true
end

-- Risiko einer Aufkauf-Chance: "low", "mid" oder "high", Gruende (Texte), Punkte
-- age = Sekunden seit dem Stand der Preisstufen, budget = Gold, das ausgegeben werden darf
function B.Risk(d, age, budget)
    local pts, why = 0, {}
    local function Add(n, text) pts = pts + n; why[#why + 1] = text end
    local maxH = B.MaxHours()
    if d.hours and d.hours > maxH * B.RISK_HOURS_PART then Add(1, L.RISK_W_SLOW) end
    if d.perHour and d.nearQty and d.nearQty > d.perHour * maxH then Add(1, L.RISK_W_NEAR) end
    if d.nextQty and (d.nextQty < B.RISK_THIN_MIN or d.nextQty < (d.qty or 0) * B.RISK_THIN_PART) then Add(1, L.RISK_W_THIN) end
    if budget and budget > 0 and (d.cost or 0) > budget * B.RISK_GOLD_PART then Add(1, L.RISK_W_GOLD) end
    if age and age > B.RISK_VERY_OLD then Add(2, L.RISK_W_OLD)
    elseif age and age > B.RISK_OLD then Add(1, L.RISK_W_OLD) end
    if not d.sales or (d.sales.level or 1) < 2 or not d.band then Add(1, L.RISK_W_DATA) end
    local level = (pts >= B.RISK_HIGH and "high") or (pts >= B.RISK_MID and "mid") or "low"
    return level, why, pts
end

-- "etwa 40 Min.", "etwa 2 Std."
function B.HoursText(h)
    if type(h) ~= "number" or h ~= h or h == math.huge then return "?" end
    if h < 1 then return L.BUYOUT_MIN:format(math.max(1, math.floor(h * 60 + 0.5))) end
    return L.BUYOUT_HOURS:format(math.floor(h * 10 + 0.5) / 10)
end
