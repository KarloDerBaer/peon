-- Peon_Warhorn - Placeholders.lua
-- Ab 0.5.0 (Wunsch KarloDerBaer): eigenes kleines Fenster "Platzhalter", geoeffnet ueber den Knopf
-- Platzhalter auf der Seite Einstellungen.
--   * Woerter fuer {rolle}: je Rolle (Tank, Heiler, Schaden) ein eigenes Wort, z. B. DD. Leer = Wort des Spiels.
--   * Eigene Platzhalter: anlegen, aendern, loeschen. Name nur aus Buchstaben a-z und Ziffern, im Text gehen die festen.
-- Gespeichert in PeonWarhornDB.whisper.roleWords und .vars (Whisper.lua).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local Ph = {}
ns.Placeholders = Ph

Ph.WIDTH, Ph.HEIGHT = 460, 380
Ph.MAX_TEXT = 120

local function W() return mod.db.whisper end

---------------------------------------------------------------------------
-- Daten
---------------------------------------------------------------------------
function Ph.SetRoleWord(key, text)
    ns.Whisper.InitDefaults()
    text = type(text) == "string" and strtrim(text) or ""
    W().roleWords[key] = text ~= "" and text or nil
end

-- freier Name eigenN
local function FreeName()
    local used = {}
    for _, v in ipairs(ns.Whisper.Vars()) do used[v.name] = true end
    local i = #ns.Whisper.Vars() + 1
    while used[ns.Whisper.CleanVarName(L.PH_NEW_NAME:format(i))] do i = i + 1 end
    return ns.Whisper.CleanVarName(L.PH_NEW_NAME:format(i))
end

function Ph.NewVar()
    ns.Whisper.InitDefaults()
    local vars = W().vars
    vars[#vars + 1] = { name = FreeName(), text = "" }
    Ph.Select(#vars)
end

function Ph.DeleteVar()
    local vars = ns.Whisper.Vars()
    local i = Ph.sel or 0
    if not vars[i] then return end
    table.remove(vars, i)
    Ph.Select(math.min(i, #vars))
end

-- Name pruefen: nur a-z und Ziffern, nicht leer, nicht fest, nicht doppelt. Gibt den gespeicherten Namen zurueck.
function Ph.RenameVar(i, name)
    local vars = ns.Whisper.Vars()
    local v = vars[i]
    if not v then return nil end
    local n = ns.Whisper.CleanVarName(name)
    if not n or n == "" or ns.Whisper.FIXED[n] then return v.name end
    for j, o in ipairs(vars) do if j ~= i and o.name == n then return v.name end end
    v.name = n
    return n
end

function Ph.SetVarText(i, text)
    local v = ns.Whisper.Vars()[i]
    if v then v.text = (type(text) == "string" and text or ""):sub(1, Ph.MAX_TEXT) end
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
function Ph.Select(i)
    local vars = ns.Whisper.Vars()
    if #vars == 0 then i = 0 else i = math.max(1, math.min(#vars, i or 1)) end
    Ph.sel = i
    local v = vars[i]
    if Ph.nameInput then Ph.nameInput:SetText(v and v.name or "") end
    if Ph.textInput then Ph.textInput:SetText(v and v.text or "") end
    Ph.SyncControls()
end

function Ph.SyncControls()
    if Ph.varDD and Ph.varDD.GenerateMenu then pcall(Ph.varDD.GenerateMenu, Ph.varDD) end
    local has = ns.Whisper.Vars()[Ph.sel or 0] ~= nil
    for _, c in ipairs({ Ph.delBtn, Ph.nameInput, Ph.textInput }) do
        if c and c.Enable then if has then c:Enable() else c:Disable() end end
    end
    if Ph.fixedText then
        local parts = {}
        for _, d in ipairs(ns.Whisper.FIXED_LIST) do parts[#parts + 1] = "{" .. d[1] .. "} " .. L[d[2]] end
        Ph.fixedText:SetText(table.concat(parts, "\n"))
    end
end

function Ph.Create()
    if Ph.frame then return Ph.frame end
    local UI = Peon.UI
    local f = UI.Window("PeonWarhornPlaceholders", { title = L.PH_TITLE, width = Ph.WIDTH, height = Ph.HEIGHT, icon = "Interface\\Icons\\INV_Misc_Horn_01" })
    Ph.frame = f

    -- Woerter fuer {rolle}
    local h1 = UI.Text(f, "heading", L.PH_ROLES)
    h1:SetPoint("TOPLEFT", 62, -36)
    Ph.roleInputs = {}
    for n, key in ipairs(ns.Whisper.ROLE_KEYS) do
        local lbl = UI.Text(f, "label", L[ns.Whisper.ROLE_LOCALE[key]])
        lbl:SetPoint("TOPLEFT", 24 + (n - 1) * 140, -66)
        local e = UI.Input(f, 110, { maxLetters = 20, instructions = ns.Whisper.RoleDefault(key) })
        e:SetPoint("TOPLEFT", 24 + (n - 1) * 140, -82)
        e:HookScript("OnTextChanged", function(self, user) if user then Ph.SetRoleWord(key, self:GetText()) end end)
        UI.SetTooltip(e, { L.PH_ROLES, L.PH_ROLES_TIP })
        Ph.roleInputs[key] = e
    end

    -- eigene Platzhalter
    local h2 = UI.Text(f, "heading", L.PH_OWN)
    h2:SetPoint("TOPLEFT", 24, -122)
    local dd = UI.Dropdown(f, 180, function()
        local out = {}
        for i, v in ipairs(ns.Whisper.Vars()) do out[#out + 1] = { i, "{" .. v.name .. "}" } end
        if #out == 0 then out[1] = { 0, L.PH_NONE } end
        return out
    end, function() return Ph.sel or 0 end, function(v) Ph.Select(v) end)
    dd:SetPoint("TOPLEFT", 24, -142)
    Ph.varDD = dd
    local new = UI.Button(f, L.PH_NEW, 80, Ph.NewVar)
    new:SetPoint("LEFT", dd, "RIGHT", 10, 0)
    local del = UI.Button(f, L.PH_DELETE, 80, Ph.DeleteVar)
    del:SetPoint("LEFT", new, "RIGHT", 4, 0)
    Ph.delBtn = del

    local nl = UI.Text(f, "label", L.PH_NAME)
    nl:SetPoint("TOPLEFT", 24, -180)
    local name = UI.Input(f, 160, { maxLetters = 20 })
    name:SetPoint("TOPLEFT", 80, -174)
    -- Name erst beim Verlassen des Feldes pruefen, sonst springt er beim Tippen
    local function SaveName(self)
        local saved = Ph.RenameVar(Ph.sel or 0, self:GetText())
        if saved then self:SetText(saved) end
        Ph.SyncControls()
    end
    name:HookScript("OnEditFocusLost", SaveName)
    name:HookScript("OnEnterPressed", SaveName)
    Ph.nameInput = name

    local tl = UI.Text(f, "label", L.PH_TEXT)
    tl:SetPoint("TOPLEFT", 24, -212)
    local text = UI.Input(f, Ph.WIDTH - 110, { maxLetters = Ph.MAX_TEXT })
    text:SetPoint("TOPLEFT", 80, -206)
    text:HookScript("OnTextChanged", function(self, user) if user then Ph.SetVarText(Ph.sel or 0, self:GetText()) end end)
    Ph.textInput = text

    local hint = UI.Text(f, "sub", L.PH_HINT, Ph.WIDTH - 48)
    hint:SetPoint("TOPLEFT", 24, -240)

    local h3 = UI.Text(f, "heading", L.PH_FIXED)
    h3:SetPoint("TOPLEFT", 24, -276)
    local fixed = UI.Text(f, "sub", "", Ph.WIDTH - 48)
    fixed:SetPoint("TOPLEFT", 24, -296)
    if fixed.SetJustifyH then fixed:SetJustifyH("LEFT") end
    Ph.fixedText = fixed
    return f
end

function Ph.Open()
    ns.Whisper.InitDefaults()
    Ph.Create()
    for key, e in pairs(Ph.roleInputs) do e:SetText(W().roleWords[key] or "") end
    Ph.Select(Ph.sel or 1)
    if ns.Overlay and ns.Overlay.AboveWarhorn then ns.Overlay.AboveWarhorn(Ph.frame) end
    Ph.frame:Show()
end
