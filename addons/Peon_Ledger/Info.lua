-- Peon_Ledger - Info.lua
-- Reiter "Info" (ab 0.14.5, Wunsch KarloDerBaer): links die Begriffe zum Nachlesen (L.INFO_TERMS), rechts die
-- Abweichungen der Kontrollrechnung aufgeschluesselt: offen jetzt (eingeloggter Charakter) und verbucht.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local IN = {}
ns.Info = IN

IN.DAYS = 30   -- verbuchte Abweichungen der letzten Tage

-- Liste mit Bildlauf (Blizzards ScrollFrame), Inhalt: Begriffe untereinander
local function TermList(panel, width)
    local U = Peon.UI
    local sf = U.TryFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
        or U.TryFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        or CreateFrame("ScrollFrame", nil, panel)
    sf:SetPoint("TOPLEFT", 10, -36)
    sf:SetPoint("BOTTOMRIGHT", -28, 8)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(width, 10)
    if sf.SetScrollChild then sf:SetScrollChild(child) end
    local y = 0
    IN.terms = {}
    for _, t in ipairs(L.INFO_TERMS or {}) do
        local h = child:CreateFontString(nil, "ARTWORK", U.FONT.label)
        h:SetPoint("TOPLEFT", 4, -y)
        h:SetJustifyH("LEFT")
        h:SetText(t[1])
        local b = child:CreateFontString(nil, "ARTWORK", U.FONT.text)
        b:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -3)
        b:SetWidth(width - 12)
        b:SetJustifyH("LEFT")
        if b.SetWordWrap then b:SetWordWrap(true) end
        b:SetText(t[2])
        y = y + (h:GetStringHeight() or 12) + 3 + (b:GetStringHeight() or 12) + 12
        IN.terms[#IN.terms + 1] = { term = t[1], text = t[2] }
    end
    child:SetHeight(math.max(10, y))
    return sf
end

-- Offene Abweichungen als Zeilen: { left, right }
function IN.OpenLines()
    local res = ns.Check.Run()
    local out = {}
    if res.gold ~= 0 then out[#out + 1] = { L.TR_GOLD, W.Signed(res.gold) } end
    for id, d in pairs(res.items) do
        local name, q = ns.Inventory.ItemInfo(id)
        out[#out + 1] = { W.Colored(name or ("#" .. id), q), (d > 0 and (W.GREEN .. "+") or (W.RED .. "")) .. d .. "|r" }
    end
    table.sort(out, function(a, b) return a[1] < b[1] end)
    return out, res
end

-- Verbuchte Abweichungen der letzten Tage (alle Charaktere)
function IN.BookedRows(now)
    now = now or time()
    local from = now - IN.DAYS * 86400
    local rows = {}
    for _, e in ipairs(ns.Moves.List()) do
        if e.k == "diff" and (e.t or 0) >= from then
            local name, q, icon
            if e.id then name, q, icon = ns.Inventory.ItemInfo(e.id) end
            rows[#rows + 1] = { e = e, t = e.t or 0, c = e.c, id = e.id, name = e.id and (name or ("#" .. e.id)) or L.TR_GOLD,
                quality = q, icon = icon, n = e.n, m = e.m }
        end
    end
    return rows
end

function IN.Refresh()
    if not IN.table then return end
    local lines, res = IN.OpenLines()
    local txt = {}
    if #lines == 0 then
        txt[1] = W.GREEN .. L.INFO_DEV_NONE .. "|r"
    else
        txt[1] = L.INFO_DEV_OPEN:format(ns.CharName())
        for i, l in ipairs(lines) do
            if i > 8 then txt[#txt + 1] = W.GREY .. L.HIST_MORE:format(#lines - 8) .. "|r"; break end
            txt[#txt + 1] = "  " .. l[1] .. "   " .. l[2]
        end
    end
    IN.open:SetText(table.concat(txt, "\n"))
    IN.openLines = lines
    IN.table:SetData(IN.BookedRows())
end

function IN.Status() return L.INFO_STATUS end

function IN.Build(c)
    local U = Peon.UI
    local a = W.Area()
    local lw = 420
    local left = U.Panel(c, "left")
    left:SetPoint("TOPLEFT", a.left, -a.top)
    left:SetPoint("BOTTOMLEFT", a.left, a.bottom)
    left:SetWidth(lw)
    local h1 = left:CreateFontString(nil, "ARTWORK", U.FONT.heading)
    h1:SetPoint("TOPLEFT", 14, -12)
    h1:SetText(L.INFO_TERMS_HEAD)
    IN.scroll = TermList(left, lw - 46)
    local right = U.Panel(c, "right")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 0)
    right:SetPoint("BOTTOMRIGHT", -a.right, a.bottom)
    local h2 = right:CreateFontString(nil, "ARTWORK", U.FONT.heading)
    h2:SetPoint("TOPLEFT", 14, -12)
    h2:SetText(L.INFO_DEV_HEAD)
    local expl = U.Text(right, "small", L.INFO_DEV_TEXT, 330)
    expl:SetPoint("TOPLEFT", 14, -34)
    IN.open = U.Text(right, "text", "", 330)
    IN.open:SetPoint("TOPLEFT", expl, "BOTTOMLEFT", 0, -10)
    local tp = U.Panel(right, "list", true)
    tp:SetPoint("BOTTOMLEFT", 6, 6)
    tp:SetPoint("BOTTOMRIGHT", -6, 6)
    tp:SetHeight(200)
    local cap = right:CreateFontString(nil, "ARTWORK", U.FONT.label)
    cap:SetPoint("BOTTOMLEFT", tp, "TOPLEFT", 8, 4)
    cap:SetText(L.INFO_DEV_BOOKED:format(IN.DAYS))
    IN.table = U.Table(tp, {
        icon = true,
        columns = {
            { key = "name", title = L.COL_ITEM, format = function(v, r) return r.id and W.Colored(v, r.quality) or v end },
            { key = "t", title = L.COL_TIME, width = 84, format = function(v) return date("%d.%m. %H:%M", v) end },
            { key = "n", title = L.INFO_COL_DIFF, width = 90, align = "RIGHT",
              format = function(v, r)
                  if r.m and r.m ~= 0 then return W.Signed(r.m) end
                  if v then return (v > 0 and (W.GREEN .. "+") or W.RED) .. v .. "|r" end
                  return ""
              end },
        },
        sortKey = "t", sortDesc = true,
        empty = L.INFO_DEV_EMPTY,
    })
end

W.pages.info = { build = IN.Build, refresh = IN.Refresh, status = IN.Status }
