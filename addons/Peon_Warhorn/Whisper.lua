-- Peon_Warhorn - Whisper.lua
-- Fluesterfenster mit Vorlagen (ab 0.3.0, Wunsch KarloDerBaer): Empfaenger, Auswahl der Vorlage, Textfeld,
-- Knopf Senden. Platzhalter {name} {rolle} {klasse} {stufe} {aktivitaet} werden beim Waehlen eingesetzt.
-- Abgeschickt wird nur mit dem Knopf Senden (oder Eingabetaste im Textfeld), nie von selbst.
-- Vorlagen in PeonWarhornDB.whisper: templates = { { name, text }, ... }, groupTpl, playerTpl (Nummern).
-- Ab 0.5.0 (Wunsch KarloDerBaer): roleWords = { tank, healer, dps } (eigene Woerter fuer {rolle}, leer = Spiel),
-- vars = { { name, text }, ... } (eigene Platzhalter), schnell anfluestern ohne Fenster (Wh.QuickSend).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local Wh = {}
ns.Whisper = Wh

Wh.MAX = 255          -- laengste Fluesternachricht
Wh.ROLE_KEYS = { "tank", "healer", "dps" }
Wh.ROLE_LOCALE = { tank = "ROLE_TANK", healer = "ROLE_HEALER", dps = "ROLE_DPS" }
-- feste Platzhalter (deutsch und englisch), eigene duerfen nicht so heissen
Wh.FIXED = { name = true, rolle = true, klasse = true, stufe = true, aktivitaet = true, suchrolle = true,
    role = true, class = true, level = true, activity = true, searchrole = true }
Wh.FIXED_LIST = { { "name", "PH_DESC_NAME" }, { "rolle", "PH_DESC_ROLE" }, { "suchrolle", "PH_DESC_SEARCHROLE" },
    { "klasse", "PH_DESC_CLASS" }, { "stufe", "PH_DESC_LEVEL" }, { "aktivitaet", "PH_DESC_ACT" } }
-- ab 0.5.1: {suchrolle} ist noch offen (Rolle des Mitspielers unbekannt oder mehrere)
Wh.OPEN_ROLE = "{suchrolle}"
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
    -- ab 0.5.0: Rollenwoerter und eigene Platzhalter
    local rw = type(w.roleWords) == "table" and w.roleWords or {}
    for _, k in ipairs(Wh.ROLE_KEYS) do
        if type(rw[k]) ~= "string" then rw[k] = nil end
    end
    w.roleWords = rw
    local vars, seen = {}, {}
    for _, v in ipairs(type(w.vars) == "table" and w.vars or {}) do
        local n = type(v) == "table" and Wh.CleanVarName(v.name)
        if n and n ~= "" and not seen[n] and not Wh.FIXED[n] then
            seen[n] = true
            vars[#vars + 1] = { name = n, text = type(v.text) == "string" and v.text or "" }
        end
    end
    w.vars = vars
    local n = #clean
    w.groupTpl = math.max(0, math.min(n, tonumber(w.groupTpl) or 0))
    w.playerTpl = math.max(0, math.min(n, tonumber(w.playerTpl) or 0))
    db.whisper = w
end

function Wh.Templates()
    return mod.db and mod.db.whisper and mod.db.whisper.templates or {}
end

-- Wort fuer eine Rolle: eigenes aus den Platzhaltern (ab 0.5.0), sonst das des Spiels
function Wh.RoleWord(key)
    local w = mod.db and mod.db.whisper
    local own = type(w) == "table" and type(w.roleWords) == "table" and w.roleWords[key]
    if type(own) == "string" and strtrim(own) ~= "" then return strtrim(own) end
    return Wh.RoleDefault(key)
end

-- Vorgabe ohne eigenes Wort; ab 0.5.1 bei Schaden "DD" (Wunsch KarloDerBaer)
function Wh.RoleDefault(key)
    if key == "dps" then return L.PH_DPS_DEFAULT end
    return L[Wh.ROLE_LOCALE[key]]
end

-- Gesuchte Rolle von selbst: nur wenn der Mitspieler genau eine Rolle angegeben hat
function Wh.AutoSearchRole(roles)
    if type(roles) ~= "table" or Peon.IsSecret(roles) then return nil end
    local found
    for _, k in ipairs(Wh.ROLE_KEYS) do
        if roles[k] == true then
            if found then return nil end
            found = k
        end
    end
    return found
end

-- Rollen aus Blizzards Rollenwahl als Text, z. B. "Heiler/DD"
function Wh.MyRolesText()
    local r = ns.Filter.MyRoles()
    local parts = {}
    for _, k in ipairs(Wh.ROLE_KEYS) do
        if r[k] then parts[#parts + 1] = Wh.RoleWord(k) end
    end
    return table.concat(parts, "/")
end

-- Eigene Platzhalter: Name nur aus Buchstaben a-z und Ziffern, klein
function Wh.CleanVarName(n)
    if type(n) ~= "string" then return nil end
    return (n:gsub("[^%w]", ""):lower())
end

function Wh.Vars()
    local w = mod.db and mod.db.whisper
    return type(w) == "table" and type(w.vars) == "table" and w.vars or {}
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
        -- ohne gewaehlte Rolle bleibt {suchrolle} stehen, das Fenster fragt dann nach (ab 0.5.1)
        suchrolle = ctx.searchRole and Wh.RoleWord(ctx.searchRole) or nil,
    }
    values.role, values.class, values.level, values.activity = values.rolle, values.klasse, values.stufe, values.aktivitaet
    values.searchrole = values.suchrolle
    local function Fixed(t)
        return (t:gsub("{(%w+)}", function(k)
            local v = values[k:lower()]
            if v == nil and (k:lower() == "suchrolle" or k:lower() == "searchrole") then return Wh.OPEN_ROLE end
            if v == nil then return "{" .. k .. "}" end
            return v
        end))
    end
    -- eigene Platzhalter (ab 0.5.0); in ihrem Text gelten die festen, nicht aber andere eigene
    local own = {}
    for _, v in ipairs(Wh.Vars()) do
        if not Wh.FIXED[v.name] then own[v.name] = Fixed(v.text or "") end
    end
    for k, v in pairs(own) do values[k] = v end
    return Fixed(text or "")
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
    local text = Wh.edit:GetText() or ""
    local n = #text
    Wh.count:SetText(("%d/%d"):format(n, Wh.MAX))
    local open = Wh.HasOpenRole(text)
    if Wh.sendBtn then
        if n > 0 and not open then Wh.sendBtn:Enable() else Wh.sendBtn:Disable() end
    end
    if Wh.hint then Wh.hint:SetText(open and L.WHISPER_PICK_ROLE or L.WHISPER_HINT) end
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

    -- ab 0.5.1: gesuchte Rolle fuer {suchrolle}
    local rdd = UI.Dropdown(f, 110, function()
        local out = {}
        for _, k in ipairs(Wh.ROLE_KEYS) do out[#out + 1] = { k, Wh.RoleWord(k) } end
        return out
    end, function() return Wh.ctx and Wh.ctx.searchRole end, function(v) Wh.SetSearchRole(v) end)
    rdd:SetPoint("TOPRIGHT", -18, -28)
    UI.SetTooltip(rdd, { L.WHISPER_ROLE, L.WHISPER_ROLE_TIP })
    Wh.roleDD = rdd
    local rl = UI.Text(f, "label", L.WHISPER_ROLE)
    rl:SetPoint("RIGHT", rdd, "LEFT", -8, 0)
    Wh.roleLabel = rl

    local tplLabel = UI.Text(f, "label", L.WHISPER_TEMPLATE)
    tplLabel:SetPoint("TOPLEFT", 18, -66)
    local dd = UI.Dropdown(f, 220, function()
        local out = { { 0, L.WHISPER_NO_TEMPLATE } }
        for i, t in ipairs(Wh.Templates()) do out[#out + 1] = { i, t.name } end
        return out
    end, function() return Wh.tpl or 0 end, function(v) Wh.UseTemplate(v) end)
    dd:SetPoint("LEFT", tplLabel, "RIGHT", 10, 0)
    Wh.tplDD = dd
    -- ab 0.5.0: Platzhalter an der Schreibmarke einfuegen
    local ins = UI.FilterDropdown(f, L.WHISPER_INSERT, function(root)
        for _, it in ipairs(Wh.PlaceholderItems()) do
            local desc = it[2] and it[2] ~= "" and ("  |cff999999" .. it[2]:sub(1, 30) .. "|r") or ""
            root:CreateButton(it[1] .. desc, function() Wh.InsertPlaceholder(it[1]) end)
        end
    end)
    ins:SetPoint("LEFT", dd, "RIGHT", 8, 0)
    if ins.SetWidth then ins:SetWidth(110) end
    Wh.insDD = ins

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
    Wh.hint = hint
    return f
end

-- kind: "group" (Anfuehrer einer Gruppe), "player" (Einzelspieler oder Wer-Liste)
function Wh.Open(name, ctx, kind, tpl)
    if type(name) ~= "string" or name == "" or Peon.IsSecret(name) then return end
    Wh.InitDefaults()
    Wh.Create()
    Wh.target = name
    Wh.ctx = ctx or {}
    Wh.ctx.name = name
    Wh.ctx.searchRole = Wh.ctx.searchRole or Wh.AutoSearchRole(Wh.ctx.searchRoles)
    Wh.toText:SetText(L.WHISPER_TO:format(name))
    -- Auswahl der gesuchten Rolle nur beim Anfluestern von Spielern
    local isPlayer = kind ~= "group"
    if Wh.roleDD then Wh.roleDD:SetShown(isPlayer) end
    if Wh.roleLabel then Wh.roleLabel:SetShown(isPlayer) end
    if Wh.roleDD and Wh.roleDD.GenerateMenu then pcall(Wh.roleDD.GenerateMenu, Wh.roleDD) end
    local w = mod.db.whisper
    Wh.UseTemplate(tpl or (kind == "group" and w.groupTpl or w.playerTpl))
    -- ab 0.3.4 immer ueber Warhorn, auch wenn Warhorn nach dem Dungeon-Journal hoeher liegt
    if ns.Overlay and ns.Overlay.AboveWarhorn then ns.Overlay.AboveWarhorn(Wh.frame) end
    Wh.frame:Show()
    if Wh.edit.SetFocus then Wh.edit:SetFocus() end
end

function Wh.HasOpenRole(text)
    return type(text) == "string" and text:find(Wh.OPEN_ROLE, 1, true) ~= nil
end

-- Gesuchte Rolle im Fenster waehlen: Vorlage neu einsetzen, sonst nur {suchrolle} im Text ersetzen
function Wh.SetSearchRole(key)
    if not Wh.ctx then return end
    Wh.ctx.searchRole = key
    if (Wh.tpl or 0) > 0 then
        Wh.UseTemplate(Wh.tpl)
    elseif Wh.edit then
        local word = Wh.RoleWord(key)
        Wh.edit:SetText((Wh.edit:GetText() or ""):gsub("{[Ss][Uu][Cc][Hh][Rr][Oo][Ll][Ll][Ee]}", function() return word end))
        Wh.UpdateCount()
    end
    if Wh.roleDD and Wh.roleDD.GenerateMenu then pcall(Wh.roleDD.GenerateMenu, Wh.roleDD) end
end

-- Abschicken an einen Spieler (Fenster und schnell anfluestern)
function Wh.SendTo(target, text)
    if type(target) ~= "string" or target == "" or type(text) ~= "string" or text == "" then return false end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if type(send) ~= "function" then return false end
    local ok, err = pcall(send, text:sub(1, Wh.MAX), "WHISPER", nil, target)
    if not ok then
        mod:Dbg("Fluestern Fehler: " .. tostring(err))
        return false
    end
    Wh.last = { to = target, text = text }
    if ns.Contacts then ns.Contacts.Record(target, "whisper") end
    return true
end

-- Senden nur aus Klick oder Eingabetaste
function Wh.Send()
    local text = Wh.edit and Wh.edit:GetText() or ""
    if text == "" or not Wh.target then return false end
    if Wh.HasOpenRole(text) then return false end
    if not Wh.SendTo(Wh.target, text) then return false end
    Wh.frame:Hide()
    return true
end

-- Standardvorlage fuer Gruppen oder Spieler (Nummer, 0 = keine)
function Wh.DefaultTemplate(kind)
    Wh.InitDefaults()
    local w = mod.db.whisper
    local i = kind == "group" and w.groupTpl or w.playerTpl
    return Wh.Templates()[i or 0] and i or 0
end

-- ab 0.5.0: schnell anfluestern ohne Fenster (Untermenue, Shift+Doppelklick). Nur aus einem Klick des Spielers.
-- Ohne Vorlage oeffnet sich das Fenster wie bisher.
function Wh.QuickSend(name, ctx, kind, tpl)
    if type(name) ~= "string" or name == "" or Peon.IsSecret(name) then return false end
    Wh.InitDefaults()
    tpl = tpl or Wh.DefaultTemplate(kind)
    local t = Wh.Templates()[tpl or 0]
    if not t then
        Wh.Open(name, ctx, kind)
        return false
    end
    ctx = ctx or {}
    ctx.name = name
    ctx.searchRole = ctx.searchRole or Wh.AutoSearchRole(ctx.searchRoles)
    local text = Wh.Fill(t.text, ctx)
    -- Rolle des Mitspielers offen: erst im Fenster waehlen (ab 0.5.1)
    if Wh.HasOpenRole(text) then
        Wh.Open(name, ctx, kind, tpl)
        return false
    end
    return Wh.SendTo(name, text)
end

local function CopyCtx(ctx)
    local c = {}
    for k, v in pairs(ctx or {}) do c[k] = v end
    return c
end

-- Braucht die Vorlage eine gesuchte Rolle? (auch ueber eigene Platzhalter)
function Wh.NeedsSearchRole(text, name, ctx)
    local probe = CopyCtx(ctx)
    probe.name, probe.searchRole = name, nil
    return Wh.HasOpenRole(Wh.Fill(text, probe))
end

-- Untermenue "Schnell anfluestern" mit allen Vorlagen (Rechtsklick in den Listen)
-- Ab 0.5.2 (Wunsch KarloDerBaer): Vorlagen mit {suchrolle} bekommen beim Anfluestern von Spielern eine Ebene mit
-- den Rollen. Hat der Spieler Rollen angegeben, sind nur diese waehlbar, die anderen grau.
function Wh.AddQuickMenu(root, name, ctx, kind, enabled)
    Wh.InitDefaults()
    local sub = root:CreateButton(L.MENU_QUICK)
    if sub.SetEnabled then sub:SetEnabled(enabled and true or false) end
    local list = Wh.Templates()
    if #list == 0 then
        local none = sub:CreateButton(L.MENU_QUICK_NONE, function() end)
        if none.SetEnabled then none:SetEnabled(false) end
        return sub
    end
    local roles = ctx and type(ctx.searchRoles) == "table" and not Peon.IsSecret(ctx.searchRoles) and ctx.searchRoles or nil
    local given = false
    for _, k in ipairs(Wh.ROLE_KEYS) do if roles and roles[k] == true then given = true end end
    for i, t in ipairs(list) do
        if kind ~= "group" and Wh.NeedsSearchRole(t.text, name, ctx) then
            local tb = sub:CreateButton(t.name)
            for _, k in ipairs(Wh.ROLE_KEYS) do
                local rb = tb:CreateButton(Wh.RoleWord(k), function()
                    local c = CopyCtx(ctx)
                    c.searchRole = k
                    Wh.QuickSend(name, c, kind, i)
                end)
                if given and roles[k] ~= true and rb.SetEnabled then rb:SetEnabled(false) end
            end
        else
            sub:CreateButton(t.name, function() Wh.QuickSend(name, CopyCtx(ctx), kind, i) end)
        end
    end
    return sub
end

-- Platzhalter fuer das Menue "Platzhalter" im Fluesterfenster: { { "{name}", Beschreibung }, ... }
function Wh.PlaceholderItems()
    local out = {}
    for _, d in ipairs(Wh.FIXED_LIST) do out[#out + 1] = { "{" .. d[1] .. "}", L[d[2]] } end
    for _, v in ipairs(Wh.Vars()) do out[#out + 1] = { "{" .. v.name .. "}", v.text } end
    return out
end

function Wh.InsertPlaceholder(tag)
    local e = Wh.edit
    if not e then return end
    if type(e.Insert) == "function" then e:Insert(tag) else e:SetText((e:GetText() or "") .. tag) end
    Wh.UpdateCount()
end
