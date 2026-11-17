-- Peon_Warhorn - Whisper.lua
-- Fluesterfenster mit Vorlagen (ab 0.3.0, Wunsch KarloDerBaer): Empfaenger, Auswahl der Vorlage, Textfeld,
-- Knopf Senden. Platzhalter {name} {rolle} {klasse} {stufe} {aktivitaet} werden beim Waehlen eingesetzt.
-- Abgeschickt wird nur mit dem Knopf Senden (oder Eingabetaste im Textfeld), nie von selbst.
-- Vorlagen in PeonWarhornDB.whisper: templates = { { name, text }, ... }, groupTpl, playerTpl (Nummern).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local Wh = {}
ns.Whisper = Wh

Wh.MAX = 255          -- laengste Fluesternachricht
Wh.WIDTH, Wh.HEIGHT = 440, 250

---------------------------------------------------------------------------
-- Vorlagen
---------------------------------------------------------------------------
function Wh.DefaultTemplates()
    return {
        { name = L.TPL_GROUP_NAME, text = L.TPL_GROUP_TEXT },
        { name = L.TPL_PLAYER_NAME, text = L.TPL_PLAYER_TEXT },
    }
end

-- Fehlende oder kaputte Einstellungen ergaenzen (beim Start und nach Standardwerte)
function Wh.InitDefaults()
    local db = mod.db
    if not db then return end
    local w = type(db.whisper) == "table" and db.whisper or {}
    if type(w.templates) ~= "table" then w.templates = {} end
    local clean = {}
    for _, t in ipairs(w.templates) do
        if type(t) == "table" and type(t.text) == "string" then
            clean[#clean + 1] = { name = type(t.name) == "string" and t.name or "?", text = t.text }
        end
    end
    if not w.init then
        if #clean == 0 then clean = Wh.DefaultTemplates() end
        w.groupTpl, w.playerTpl = 1, math.min(2, #clean)
        w.init = true
    end
    w.templates = clean
    local n = #clean
    w.groupTpl = math.max(0, math.min(n, tonumber(w.groupTpl) or 0))
    w.playerTpl = math.max(0, math.min(n, tonumber(w.playerTpl) or 0))
    db.whisper = w
end

function Wh.Templates()
    return mod.db and mod.db.whisper and mod.db.whisper.templates or {}
end

-- Rollen aus Blizzards Rollenwahl als Text, z. B. "Heiler/Schaden"
function Wh.MyRolesText()
    local r = ns.Filter.MyRoles()
    local parts = {}
    if r.tank then parts[#parts + 1] = L.ROLE_TANK end
    if r.healer then parts[#parts + 1] = L.ROLE_HEALER end
    if r.dps then parts[#parts + 1] = L.ROLE_DPS end
    return table.concat(parts, "/")
end

local function Short(name)
    if type(name) ~= "string" then return "" end
    return (name:match("^([^%-]+)") or name)
end

-- Platzhalter einsetzen. ctx: { name, activity }
function Wh.Fill(text, ctx)
    ctx = ctx or {}
    local _, cls = UnitClass("player")
    local values = {
        name = Short(ctx.name),
        rolle = Wh.MyRolesText(),
        klasse = ns.Window.ClassName(cls),
        stufe = tostring(UnitLevel and UnitLevel("player") or ""),
        aktivitaet = ctx.activity or "",
    }
    values.role, values.class, values.level, values.activity = values.rolle, values.klasse, values.stufe, values.aktivitaet
    local out = (text or ""):gsub("{(%a+)}", function(k)
        local v = values[k:lower()]
        if v == nil then return "{" .. k .. "}" end
        return v
    end)
    return out
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local function SetText(t)
    local e = Wh.edit
    if not e then return end
    e:SetText((t or ""):sub(1, Wh.MAX))
    Wh.UpdateCount()
end

function Wh.UpdateCount()
    if not (Wh.edit and Wh.count) then return end
    local n = #(Wh.edit:GetText() or "")
    Wh.count:SetText(("%d/%d"):format(n, Wh.MAX))
    if Wh.sendBtn then
        if n > 0 then Wh.sendBtn:Enable() else Wh.sendBtn:Disable() end
    end
end

function Wh.UseTemplate(i)
    local t = Wh.Templates()[i]
    Wh.tpl = t and i or 0
    SetText(t and Wh.Fill(t.text, Wh.ctx) or "")
    if Wh.tplDD and Wh.tplDD.GenerateMenu then pcall(Wh.tplDD.GenerateMenu, Wh.tplDD) end
end

function Wh.Create()
    if Wh.frame then return Wh.frame end
    local UI = Peon.UI
    local f = UI.Window("PeonWarhornWhisper", { title = L.WHISPER_TITLE, width = Wh.WIDTH, height = Wh.HEIGHT, icon = "Interface\\Icons\\INV_Misc_Horn_01" })
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    Wh.frame = f

    local to = UI.Text(f, "label", "")
    to:SetPoint("TOPLEFT", 62, -34)
    Wh.toText = to

    local tplLabel = UI.Text(f, "label", L.WHISPER_TEMPLATE)
    tplLabel:SetPoint("TOPLEFT", 18, -66)
    local dd = UI.Dropdown(f, 220, function()
        local out = { { 0, L.WHISPER_NO_TEMPLATE } }
        for i, t in ipairs(Wh.Templates()) do out[#out + 1] = { i, t.name } end
        return out
    end, function() return Wh.tpl or 0 end, function(v) Wh.UseTemplate(v) end)
    dd:SetPoint("LEFT", tplLabel, "RIGHT", 10, 0)
    Wh.tplDD = dd

    -- Textfeld ueber mehrere Zeilen (Blizzards InputScrollFrameTemplate), sonst eine Zeile
    local box = UI.TryFrame("ScrollFrame", nil, f, "InputScrollFrameTemplate")
    local edit
    if box and box.EditBox then
        box:SetPoint("TOPLEFT", 22, -100)
        box:SetPoint("BOTTOMRIGHT", -28, 60)
        edit = box.EditBox
        if edit.SetWidth then edit:SetWidth(Wh.WIDTH - 60) end
        if box.CharCount then box.CharCount:Hide() end
    else
        edit = UI.Input(f, Wh.WIDTH - 50)
        edit:SetPoint("TOPLEFT", 22, -100)
    end
    if edit.SetMaxLetters then edit:SetMaxLetters(Wh.MAX) end
    edit:HookScript("OnTextChanged", function() Wh.UpdateCount() end)
    edit:SetScript("OnEnterPressed", function() Wh.Send() end)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    Wh.edit = edit

    local count = UI.Text(f, "sub", "")
    count:SetPoint("BOTTOMRIGHT", -26, 44)
    Wh.count = count

    local send = UI.Button(f, L.WHISPER_SEND, 110, function() Wh.Send() end, "gold")
    send:SetPoint("BOTTOMRIGHT", -18, 12)
    Wh.sendBtn = send
    local cancel = UI.Button(f, L.WHISPER_CANCEL, 100, function() f:Hide() end)
    cancel:SetPoint("RIGHT", send, "LEFT", -8, 0)
    local hint = UI.Text(f, "sub", L.WHISPER_HINT)
    hint:SetPoint("BOTTOMLEFT", 20, 20)
    return f
end

-- kind: "group" (Anfuehrer einer Gruppe), "player" (Einzelspieler oder Wer-Liste)
function Wh.Open(name, ctx, kind)
    if type(name) ~= "string" or name == "" or Peon.IsSecret(name) then return end
    Wh.InitDefaults()
    Wh.Create()
    Wh.target = name
    Wh.ctx = ctx or {}
    Wh.ctx.name = name
    Wh.toText:SetText(L.WHISPER_TO:format(name))
    local w = mod.db.whisper
    Wh.UseTemplate(kind == "group" and w.groupTpl or w.playerTpl)
    -- ab 0.3.4 immer ueber Warhorn, auch wenn Warhorn nach dem Dungeon-Journal hoeher liegt
    local O = ns.Overlay
    if Wh.frame.SetFrameStrata and O and O.strata and O.Above then
        local s = O.Above(O.strata)
        Wh.frame:SetFrameStrata((O.STRATA_RANK[s] or 0) > O.STRATA_RANK.DIALOG and s or "DIALOG")
    end
    Wh.frame:Show()
    if Wh.edit.SetFocus then Wh.edit:SetFocus() end
end

-- Senden nur aus Klick oder Eingabetaste
function Wh.Send()
    local text = Wh.edit and Wh.edit:GetText() or ""
    if text == "" or not Wh.target then return false end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if type(send) ~= "function" then return false end
    local ok, err = pcall(send, text, "WHISPER", nil, Wh.target)
    if not ok then
        mod:Dbg("Fluestern Fehler: " .. tostring(err))
        return false
    end
    Wh.last = { to = Wh.target, text = text }
    Wh.frame:Hide()
    return true
end
