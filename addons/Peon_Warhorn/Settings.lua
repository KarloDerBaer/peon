-- Peon_Warhorn - Settings.lua
-- Seite Einstellungen (ab 0.3.0, Konzept Abschnitt 13), erreichbar ueber den eigenen Reiter rechts am Fenster:
--   * Seiten: je Seite (Suchen, Eintragen, Wer-Liste) Warhorn oder Blizzard
--   * Spalten: sichtbare Spalten je Liste (die erste Spalte bleibt immer)
--   * Farben: neue Eintraege und der eigene Eintrag
--   * Fluestervorlagen: anlegen, aendern, loeschen, Standard fuer Gruppen und fuer Mitspieler
--   * ab 0.5.0: Knopf Platzhalter (Placeholders.lua) und "Anfragen merken" (Dauer, Contacts.lua)

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local St = {}
ns.Settings = St

St.PAGES = { { "search", "PAGE_SEARCH" }, { "listing", "PAGE_LISTING" }, { "who", "PAGE_WHO" } }
St.LISTS = { { "groups", "TAB_GROUPS" }, { "players", "TAB_PLAYERS" }, { "who", "PAGE_WHO" } }

-- Spalten einer Liste (Schluessel, Titel); die erste ist fest
function St.Columns(kind)
    local W = ns.Window
    local cols
    if kind == "groups" then cols = W.GroupColumns()
    elseif kind == "players" then cols = W.PlayerColumns()
    else cols = ns.Who.Columns() end
    local out = {}
    for i = 2, #cols do out[#out + 1] = { cols[i].key, cols[i].title } end
    return out
end

function St.IsHidden(kind, key)
    local h = mod.db.hideCols
    return type(h) == "table" and type(h[kind]) == "table" and h[kind][key] == true
end

function St.SetHidden(kind, key, hide)
    if type(mod.db.hideCols) ~= "table" then mod.db.hideCols = {} end
    if type(mod.db.hideCols[kind]) ~= "table" then mod.db.hideCols[kind] = {} end
    mod.db.hideCols[kind][key] = hide and true or nil
    ns.Window.RebuildTable(kind)
end

---------------------------------------------------------------------------
-- Farben
---------------------------------------------------------------------------
function St.SetColor(key, r, g, b, a)
    if type(mod.db.colors) ~= "table" then mod.db.colors = {} end
    mod.db.colors[key] = { r, g, b, a }
    St.UpdateSwatches()
    ns.Window.Update()
end

function St.ResetColors()
    mod.db.colors = {}
    St.UpdateSwatches()
    ns.Window.Update()
end

local function PickColor(key)
    local r, g, b, a = ns.Window.Color(key)
    local cp = rawget(_G, "ColorPickerFrame")
    if not (cp and cp.SetupColorPickerAndShow) then return end
    local function Apply()
        local nr, ng, nb = cp:GetColorRGB()
        local na = cp.GetColorAlpha and cp:GetColorAlpha() or a
        St.SetColor(key, nr, ng, nb, na)
    end
    pcall(cp.SetupColorPickerAndShow, cp, {
        r = r, g = g, b = b, opacity = a, hasOpacity = true,
        swatchFunc = Apply, opacityFunc = Apply,
        cancelFunc = function() St.SetColor(key, r, g, b, a) end,
    })
end

local function Swatch(parent, key, label)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(24, 24)
    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.8, 0.8, 0.8, 1)
    local back = btn:CreateTexture(nil, "BORDER")
    back:SetPoint("TOPLEFT", 2, -2)
    back:SetPoint("BOTTOMRIGHT", -2, 2)
    back:SetColorTexture(0.12, 0.12, 0.12, 1)
    local sw = btn:CreateTexture(nil, "ARTWORK")
    sw:SetPoint("TOPLEFT", 2, -2)
    sw:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.swatch, btn.key = sw, key
    btn:SetScript("OnClick", function() PickColor(key) end)
    local fs = Peon.UI.Text(parent, "label", label)
    fs:SetPoint("LEFT", btn, "RIGHT", 8, 0)
    return btn
end

function St.UpdateSwatches()
    for _, b in ipairs(St.swatches or {}) do
        local r, g, bl, a = ns.Window.Color(b.key)
        -- Deckkraft zum Sehen verstaerkt: die Farbe liegt in der Liste nur leicht ueber dem Grund
        b.swatch:SetColorTexture(r, g, bl, math.min(1, (a or 1) * 3))
    end
end

---------------------------------------------------------------------------
-- Fluestervorlagen
---------------------------------------------------------------------------
function St.Templates() return ns.Whisper.Templates() end

function St.SelectTemplate(i)
    local list = St.Templates()
    if #list == 0 then i = 0 else i = math.max(1, math.min(#list, i or 1)) end
    St.tpl = i
    local t = list[i]
    if St.nameInput then St.nameInput:SetText(t and t.name or "") end
    if St.textInput then St.textInput:SetText(t and t.text or "") end
    St.SyncTemplateControls()
end

function St.NewTemplate()
    local list = St.Templates()
    list[#list + 1] = { name = L.TPL_NEW_NAME:format(#list + 1), text = "" }
    St.SelectTemplate(#list)
end

function St.DeleteTemplate()
    local list = St.Templates()
    local i = St.tpl or 0
    if not list[i] then return end
    table.remove(list, i)
    local w = mod.db.whisper
    for _, k in ipairs({ "groupTpl", "playerTpl" }) do
        if w[k] == i then w[k] = 0 elseif (w[k] or 0) > i then w[k] = w[k] - 1 end
    end
    St.SelectTemplate(math.min(i, #list))
end

local function SaveField(field, value)
    local t = St.Templates()[St.tpl or 0]
    if not t then return end
    t[field] = value or ""
    if field == "name" then St.SyncTemplateControls() end
end
St.SaveField = SaveField

function St.SyncTemplateControls()
    for _, dd in ipairs({ St.tplDD, St.groupDD, St.playerDD }) do
        if dd and dd.GenerateMenu then pcall(dd.GenerateMenu, dd) end
    end
    local has = St.Templates()[St.tpl or 0] ~= nil
    if St.delBtn then if has then St.delBtn:Enable() else St.delBtn:Disable() end end
end

local function TemplateItems(withNone)
    return function()
        local out = {}
        if withNone then out[1] = { 0, L.WHISPER_NO_TEMPLATE } end
        for i, t in ipairs(St.Templates()) do out[#out + 1] = { i, t.name } end
        return out
    end
end

---------------------------------------------------------------------------
-- Seite
---------------------------------------------------------------------------
function St.Create(page)
    local UI = Peon.UI
    St.page = page
    local X1, X2, X3, X4 = 24, 190, 356, 520

    -- Seiten
    -- ab 0.3.3 Beschriftung vor den Haken in derselben Zeile (oben links lag die Ueberschrift unter dem runden Bild)
    local h1 = UI.Text(page, "heading", L.SET_PAGES)
    h1:SetPoint("TOPLEFT", X1, -64)
    St.pageChecks = {}
    local prev
    for _, def in ipairs(St.PAGES) do
        local key = def[1]
        local cb = UI.Check(page, L[def[2]], true, function(on) ns.Overlay.SetReplace(key, on) end)
        if prev then cb:SetPoint("LEFT", prev, "RIGHT", 120, 0) else cb:SetPoint("LEFT", h1, "RIGHT", 12, 0) end
        UI.SetTooltip(cb, { L[def[2]], L.SET_PAGES_TIP })
        St.pageChecks[key] = cb
        prev = cb
    end

    -- Spalten
    local h2 = UI.Text(page, "heading", L.SET_COLUMNS)
    h2:SetPoint("TOPLEFT", X1, -96)
    St.colChecks = {}
    for i, def in ipairs(St.LISTS) do
        local kind = def[1]
        local x = ({ X1, X2, X3 })[i]
        local t = UI.Text(page, "label", L[def[2]])
        t:SetPoint("TOPLEFT", x, -116)
        St.colChecks[kind] = {}
        for j, c in ipairs(St.Columns(kind)) do
            local key = c[1]
            local cb = UI.Check(page, c[2], true, function(on) St.SetHidden(kind, key, not on) end)
            cb:SetPoint("TOPLEFT", x - 4, -130 - (j - 1) * 24)
            St.colChecks[kind][key] = cb
        end
    end

    -- Farben
    local h3 = UI.Text(page, "heading", L.SET_COLORS)
    h3:SetPoint("TOPLEFT", X4, -96)
    St.swatches = {}
    local s1 = Swatch(page, "new", L.SET_COLOR_NEW)
    s1:SetPoint("TOPLEFT", X4, -120)
    local s2 = Swatch(page, "own", L.SET_COLOR_OWN)
    s2:SetPoint("TOPLEFT", X4, -150)
    St.swatches = { s1, s2 }
    local cr = UI.Button(page, L.SET_COLOR_RESET, 120, St.ResetColors)
    cr:SetPoint("TOPLEFT", X4, -182)

    -- ab 0.5.0: Anfragen merken
    local kl = UI.Text(page, "label", L.SET_CONTACTS)
    kl:SetPoint("TOPLEFT", X4, -214)
    local C = ns.Contacts
    local kdd = UI.Dropdown(page, 140, function()
        local out = {}
        for _, m in ipairs(C.KEEP_CHOICES) do out[#out + 1] = { m, C.KeepText(m) } end
        return out
    end, function() return C.KeepMinutes() end, function(v) C.SetKeep(v) end)
    kdd:SetPoint("TOPLEFT", X4, -230)
    UI.SetTooltip(kdd, { L.SET_CONTACTS, L.SET_CONTACTS_TIP })
    St.keepDD = kdd

    -- Fluestervorlagen
    local h4 = UI.Text(page, "heading", L.SET_WHISPER)
    h4:SetPoint("TOPLEFT", X1, -262)
    local dd = UI.Dropdown(page, 200, TemplateItems(false), function() return St.tpl end, function(v) St.SelectTemplate(v) end)
    dd:SetPoint("TOPLEFT", X1, -282)
    St.tplDD = dd
    local new = UI.Button(page, L.SET_TPL_NEW, 90, St.NewTemplate)
    new:SetPoint("LEFT", dd, "RIGHT", 10, 0)
    local del = UI.Button(page, L.SET_TPL_DELETE, 90, St.DeleteTemplate)
    del:SetPoint("LEFT", new, "RIGHT", 4, 0)
    St.delBtn = del
    -- ab 0.5.0: Platzhalter bearbeiten (eigenes Fenster)
    local ph = UI.Button(page, L.SET_PLACEHOLDERS, 110, function() ns.Placeholders.Open() end)
    ph:SetPoint("LEFT", del, "RIGHT", 16, 0)
    UI.SetTooltip(ph, { L.SET_PLACEHOLDERS, L.SET_PLACEHOLDERS_TIP })
    St.phBtn = ph

    local nl = UI.Text(page, "label", L.SET_TPL_NAME)
    nl:SetPoint("TOPLEFT", X1, -320)
    local name = UI.Input(page, 200, { maxLetters = 40 })
    name:SetPoint("LEFT", nl, "RIGHT", 12, 0)
    name:HookScript("OnTextChanged", function(self, user) if user then SaveField("name", self:GetText()) end end)
    St.nameInput = name

    local box = UI.TryFrame("ScrollFrame", nil, page, "InputScrollFrameTemplate")
    local text
    if box and box.EditBox then
        box:SetPoint("TOPLEFT", X1 + 4, -346)
        box:SetPoint("BOTTOMRIGHT", -30, 92)
        text = box.EditBox
        if text.SetWidth then text:SetWidth(ns.Window.WIDTH - 70) end
        if box.CharCount then box.CharCount:Hide() end
    else
        text = UI.Input(page, ns.Window.WIDTH - 60)
        text:SetPoint("TOPLEFT", X1, -350)
    end
    if text.SetMaxLetters then text:SetMaxLetters(ns.Whisper.MAX) end
    text:HookScript("OnTextChanged", function(self, user) if user then SaveField("text", self:GetText()) end end)
    St.textInput = text

    local hint = UI.Text(page, "sub", L.SET_TPL_HINT)
    hint:SetPoint("BOTTOMLEFT", X1, 70)
    local gl = UI.Text(page, "label", L.SET_TPL_GROUP)
    gl:SetPoint("BOTTOMLEFT", X1, 40)
    local gdd = UI.Dropdown(page, 170, TemplateItems(true), function() return mod.db.whisper.groupTpl end, function(v) mod.db.whisper.groupTpl = v end)
    gdd:SetPoint("LEFT", gl, "RIGHT", 10, 0)
    St.groupDD = gdd
    local pl = UI.Text(page, "label", L.SET_TPL_PLAYER)
    pl:SetPoint("LEFT", gdd, "RIGHT", 24, 0)
    local pdd = UI.Dropdown(page, 170, TemplateItems(true), function() return mod.db.whisper.playerTpl end, function(v) mod.db.whisper.playerTpl = v end)
    pdd:SetPoint("LEFT", pl, "RIGHT", 10, 0)
    St.playerDD = pdd

    page:HookScript("OnShow", St.Update)
end

function St.Update()
    if not (St.page and mod.db) then return end
    ns.Whisper.InitDefaults()
    for key, cb in pairs(St.pageChecks) do cb:SetChecked(ns.Overlay.IsReplaced(key)) end
    for kind, checks in pairs(St.colChecks) do
        for key, cb in pairs(checks) do cb:SetChecked(not St.IsHidden(kind, key)) end
    end
    St.UpdateSwatches()
    if St.keepDD and St.keepDD.GenerateMenu then pcall(St.keepDD.GenerateMenu, St.keepDD) end
    St.SelectTemplate(St.tpl or 1)
end
