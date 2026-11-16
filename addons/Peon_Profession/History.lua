-- Peon_Profession - History.lua
-- ab 0.4.0 (Wunsch von KarloDerBaer, 16.11.2026): Reiter "Verlauf". Was das Material von der Stufe bis zum Ziel an
-- jedem Tag gekostet haette, nach den Preisen im Auktionshaus laut Peon_Broker (mod:History). Ohne Vorrat gerechnet,
-- damit nur die Preise die Linie bewegen. Darunter je Material: Preis am Anfang des Zeitraums, heute und die Aenderung.
--   Preis eines Tages: guenstigstes Angebot im AH (Tageswert, aeltere Tage als Wochenwert), hoechstens der
--   Haendlerpreis. Heute zaehlt der aktuelle Kaufpreis wie im Reiter Material. Tage ohne Wert nehmen den letzten
--   bekannten, Tage davor den ersten bekannten.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local H = {}
ns.History = H

H.PERIODS = { 7, 14, 30, 90 }
H.DEFAULT = 30

local GOLD, GREY, RED, GREEN = "|cffffd100", "|cff999999", "|cffff6060", "|cff60e060"

local function Num(v) return type(v) == "number" and v == v and not Peon.IsSecret(v) end
local function P() return ns.Prices end
local function G() return ns.Guide end

function H.Period()
    local d = tonumber(mod.db.histDays)
    for _, p in ipairs(H.PERIODS) do if p == d then return d end end
    return H.DEFAULT
end

function H.DayLabel(day) return date("%d.%m.", day * 86400 + 43200) end

-- Preis je Stueck fuer days Tage bis heute (Index 1 = aeltester Tag). Rueckgabe: Liste oder nil ohne jeden Preis,
-- dazu { [Index] = true } fuer Tage mit echtem Wert aus dem AH
function H.Prices(id, days, today)
    local byDay = {}
    local hist = P().History(id)
    for _, r in ipairs(hist) do
        if not r.week and Num(r.day) and Num(r.min) then byDay[r.day] = r.min end
    end
    for _, r in ipairs(hist) do
        if r.week and Num(r.min) then
            for d = r.week * 7, r.week * 7 + 6 do if byDay[d] == nil then byDay[d] = r.min end end
        end
    end
    local vp = P().Vendor(id)
    local out, real = {}, {}
    for i = 1, days do
        local v = byDay[today - days + i]
        if v then real[i] = true end
        if vp and (v == nil or vp < v) then v = vp end
        out[i] = v
    end
    local now = P().Unit(id)
    if now then out[days] = now end
    local last, first
    for i = 1, days do
        if out[i] then last = out[i]; first = first or out[i] else out[i] = last end
    end
    if not first then return nil, real end
    for i = 1, days do
        if out[i] == nil then out[i] = first else break end
    end
    return out, real
end

-- Kosten je Tag fuer die Plan-Zeilen. Rueckgabe: { days, today, total = { je Tag }, mats = { Zeilen }, noPrice,
-- real = Zahl der Tage mit echten Werten }
function H.Compute(key, rows, days)
    days = days or H.Period()
    local today = P().Today()
    local need = G().Need(key, rows or {})
    local r = { days = days, today = today, total = {}, mats = {}, noPrice = 0, real = 0 }
    for i = 1, days do r.total[i] = 0 end
    local realDay = {}
    for id, n in pairs(need) do
        local s, real = H.Prices(id, days, today)
        if s then
            for i = 1, days do r.total[i] = r.total[i] + s[i] * n end
            for i in pairs(real) do realDay[i] = true end
            local first, now = s[1], s[days]
            local name, q = ns.ItemName(id)
            r.mats[#r.mats + 1] = { id = id, name = name or ("#" .. id), quality = q, icon = ns.ItemIcon(id), need = n,
                first = first, now = now, cost = now * n, delta = (now - first) * n,
                change = first > 0 and (now - first) / first or nil }
        else
            r.noPrice = r.noPrice + 1
        end
    end
    for _ in pairs(realDay) do r.real = r.real + 1 end
    r.any = next(need) ~= nil
    return r
end

---------------------------------------------------------------------------
-- Anzeige im Fenster
---------------------------------------------------------------------------
local W = ns.Window

local function AxisMoney(v)
    if not Num(v) then return "" end
    if v >= 10000 then return ("%.1fg"):format(v / 10000) end
    if v >= 100 then return ("%.1fs"):format(v / 100) end
    return ("%.0fc"):format(v)
end

-- Betrag mit Vorzeichen, teurer rot, billiger gruen
function H.Signed(v)
    if not Num(v) then return GREY .. "–|r" end
    if math.abs(v) < 0.5 then return GREY .. "±0|r" end
    if v > 0 then return RED .. "+|r" .. ns.Money(v) end
    return GREEN .. "-|r" .. ns.Money(-v)
end

function H.Percent(v)
    if not Num(v) then return GREY .. "–|r" end
    local p = v * 100
    if math.abs(p) < 0.5 then return GREY .. "±0 %|r" end
    return (p > 0 and RED or GREEN) .. ("%+.0f %%"):format(p) .. "|r"
end

local function MoneyOrDash(v)
    if not Num(v) then return GREY .. "–|r" end
    return ns.Money(v)
end

function W.BuildHistory(c)
    local U = Peon.UI
    local cw = U.WINDOW_W - W.x0 - U.EDGE - 1
    local cp = U.Panel(c, "right")
    cp:SetPoint("TOPLEFT", c, "TOPLEFT", W.x0, -U.TOP)
    cp:SetPoint("TOPRIGHT", c, "TOPRIGHT", -U.EDGE - 1, -U.TOP)
    cp:SetHeight(196)
    W.histHead = U.Text(cp, "small", "", cw - 220)
    W.histHead:SetPoint("TOPLEFT", 12, -10)
    W.histButtons = {}
    local prev
    for i = #H.PERIODS, 1, -1 do
        local days = H.PERIODS[i]
        local b = U.Button(cp, tostring(days), 34, function() mod.db.histDays = days; mod:Call("Verlauf", W.Refresh) end)
        if prev then b:SetPoint("RIGHT", prev, "LEFT", -2, 0) else b:SetPoint("TOPRIGHT", -8, -6) end
        W.histButtons[days] = b
        prev = b
    end
    local dl = U.Text(cp, "small", L.HIST_DAYS)
    dl:SetPoint("RIGHT", prev, "LEFT", -6, 0)
    if Peon.NewChart then
        W.histChart = Peon.NewChart(cp, { width = cw - 12, height = 150, left = 50, right = 12, top = 8, bottom = 8, grid = 2,
            leftFormat = AxisMoney,
            onHover = function(_, i) H.Hover(i) end,
            onLeave = function() if GameTooltip then GameTooltip:Hide() end end })
        if W.histChart and W.histChart.frame then W.histChart.frame:SetPoint("TOPLEFT", cp, "TOPLEFT", 6, -36) end
    end
    W.histEmpty = U.Text(cp, "hint", "", cw - 40)
    W.histEmpty:SetPoint("CENTER", 0, -10)
    W.histPanel = cp

    local lp = U.Panel(c, "list", true)
    lp:SetPoint("TOPLEFT", cp, "BOTTOMLEFT", 0, -U.GAP)
    lp:SetPoint("TOPRIGHT", cp, "BOTTOMRIGHT", 0, -U.GAP)
    lp:SetPoint("BOTTOM", c, "BOTTOM", 0, U.BOTTOM + 22)
    W.histTable = U.Table(lp, { icon = true, sortKey = "delta", sortDesc = true, empty = L.LIST_NOTHING,
        columns = {
            { key = "name", title = L.COL_MAT },
            { key = "need", title = L.COL_TOTAL, width = 55, align = "RIGHT" },
            { key = "first", title = L.HIST_COL_FIRST, width = 90, align = "RIGHT", format = function(v) return MoneyOrDash(v) end },
            { key = "now", title = L.HIST_COL_NOW, width = 90, align = "RIGHT", format = function(v) return MoneyOrDash(v) end },
            { key = "change", title = L.HIST_COL_CHANGE, width = 70, align = "RIGHT", format = function(v) return H.Percent(v) end },
            { key = "delta", title = L.HIST_COL_DELTA, width = 100, align = "RIGHT", format = function(v) return H.Signed(v) end },
        },
        onEnter = function(row, item) W.ItemTip(row, item) end })
    W.histNote = U.Text(c, "small", "")
    W.histNote:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", W.x0 + 8, U.BOTTOM + 6)
end

function H.Hover(i)
    local r = W.histData
    if not (r and GameTooltip and W.histChart and W.histChart.frame and r.total[i]) then return end
    GameTooltip:SetOwner(W.histChart.frame, "ANCHOR_CURSOR")
    GameTooltip:SetText(H.DayLabel(r.today - r.days + i), 1, 0.82, 0)
    GameTooltip:AddLine(L.HIST_TIP:format(W.goal or 0, ns.Money(r.total[i])), 1, 1, 1)
    GameTooltip:Show()
end

-- Reiter Verlauf fuellen. prof = nil: leer mit Text
function W.FillHistory(prof, text)
    for days, b in pairs(W.histButtons or {}) do
        if days == H.Period() then b:Disable() else b:Enable() end
    end
    local function Empty(msg)
        W.histData = nil
        if W.histChart and W.histChart.frame then W.histChart.frame:Hide() end
        W.histEmpty:SetText(msg or "")
        W.histEmpty:Show()
        W.histHead:SetText("")
        W.histTable:SetData({})
        W.histNote:SetText("")
    end
    if not prof then Empty(text); return end
    if not P().Broker() then Empty(L.PRICES_NONE); return end
    local r = H.Compute(prof.key, W.planRows, H.Period())
    if not r.any then Empty(L.HIST_NO_MATS); return end
    W.histData = r
    local first, now = r.total[1], r.total[r.days]
    local head = GOLD .. L.HIST_HEAD:format(math.max(1, prof.skill), W.goal or prof.max) .. "|r   "
        .. L.HIST_SUM:format(ns.Money(now), r.days, ns.Money(first), H.Percent(first > 0 and (now - first) / first or nil))
    W.histHead:SetText(head)
    W.histTable:SetData(r.mats)
    local note = GREY .. L.HIST_NOTE .. "|r"
    if r.noPrice > 0 then note = note .. "   " .. GREY .. L.COST_PART:format(r.noPrice) .. "|r" end
    W.histNote:SetText(note)
    local show = r.real >= 2 and W.histChart ~= nil
    if W.histChart and W.histChart.frame then W.histChart.frame:SetShown(show) end
    W.histEmpty:SetText(L.HIST_EMPTY)
    W.histEmpty:SetShown(not show)
    if not show then return end
    W.histChart:SetData(r.days, {
        { key = "total", kind = "line", values = r.total, color = { 1, 0.82, 0.2, 1 }, width = 2, connect = true },
    })
    W.histChart:Draw()
end
