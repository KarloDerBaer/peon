-- Peon_Bags - Saved.lua
-- Gespeicherte Ansicht (ab 0.8, Konzept docs/konzepte/ledger/Peon_Ledger_Schlank.md Abschnitt 3.3):
--   * speichert Taschen (mit Reagenzientasche und Schluesselbund) und Bank je Charakter platzgenau
--     (PeonBagsSaved[Realm][Charakter], eigene SavedVariable, gehoert nicht zu Profilen oder Standardwerten)
--   * zeigt den Stand eines Charakters im Taschenfenster nur zum Ansehen, mit Knoepfen Taschen, Bank, Gildenbank
--   * Auswahl des Charakters im Taschenfenster: der eingeloggte Charakter zeigt die echten Taschen
--   * Schnittstelle fuer andere Module: bags:ShowSaved(name, ort), bags:HasSaved(name, ort), bags:SavedChars()
-- Die Gildenbank wird erst gespeichert, wenn sie im Spiel geprueft ist (Abschnitt S6), bis dahin ist ihr Knopf grau.
--
-- Ein Platz ist ein Text "Gegenstand,Stueck,Qualitaet" (Gegenstand = Nummer, bei Varianten der Inhalt des Links
-- nach "item:", dann folgt noch ",Name"). Freie Plaetze stehen nicht drin, nur die Zahl der Plaetze je Tasche.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

local ORTE = { bags = true, bank = true, guild = true }
local view = { char = nil, ort = "bags" }   -- char = nil: echte Taschen
ns.savedView = view

---------------------------------------------------------------------------
-- Speicher
---------------------------------------------------------------------------
local function Store()
    if type(rawget(_G, "PeonBagsSaved")) ~= "table" then PeonBagsSaved = {} end
    local s = PeonBagsSaved
    if type(s.realms) ~= "table" then s.realms = {} end
    s.v = 1
    return s
end

-- Charakter mit Vor- und Nachname (Forever: zweiter Wert von UnitName ist der Nachname), wie Ledger
function ns.CharName()
    local first, last = UnitName("player")
    if type(first) ~= "string" or Peon.IsSecret(first) or first == "" then return nil end
    if type(last) == "string" and last ~= "" and not Peon.IsSecret(last) then return first .. " " .. last end
    return first
end

function ns.RealmKey()
    local r = (Peon.RealmName and Peon.RealmName()) or (GetRealmName and GetRealmName()) or nil
    if type(r) ~= "string" or Peon.IsSecret(r) or r == "" then return "?" end
    return r
end

local function Realm(create)
    local s = Store()
    local key = ns.RealmKey()
    if create and type(s.realms[key]) ~= "table" then s.realms[key] = {} end
    return s.realms[key]
end

local function CharData(name, create)
    local realm = Realm(create)
    if not realm or not name then return nil end
    if create and type(realm[name]) ~= "table" then realm[name] = {} end
    return realm[name]
end
ns.SavedChar = CharData

-- Platz als Text
local function Encode(info)
    local id = info.itemID
    if not ns.Num(id) then return nil end
    local body = type(info.hyperlink) == "string" and not Peon.IsSecret(info.hyperlink) and info.hyperlink:match("item:([^|]*)") or nil
    local q = ns.Num(info.quality) and info.quality or ""
    local count = ns.Num(info.stackCount) and info.stackCount or 1
    if body then
        local key = ns.ItemKey(id, info.hyperlink)
        if type(key) == "string" then   -- Variante ("... des Wolfs"): Link-Inhalt und Name behalten
            local name = info.hyperlink:match("%[(.-)%]") or ""
            return body .. "," .. count .. "," .. q .. "," .. name:gsub(",", " ")
        end
    end
    return id .. "," .. count .. "," .. q
end

-- Text zurueck in eine Tabelle wie C_Container.GetContainerItemInfo
function ns.DecodeSlot(s)
    if type(s) ~= "string" then return nil end
    local item, count, q, name = s:match("^([^,]+),(%d+),(%-?%d*),?(.*)$")
    if not item then return nil end
    local id = tonumber(item:match("^(%d+)"))
    if not id then return nil end
    local info = { itemID = id, stackCount = tonumber(count) or 1, quality = tonumber(q) }
    if name ~= "" then
        info.hyperlink = "|Hitem:" .. item .. "|h[" .. name .. "]|h"
    elseif item:find(":") then
        info.hyperlink = "|Hitem:" .. item .. "|h|h"
    end
    info.itemString = "item:" .. item
    local CI = rawget(_G, "C_Item")
    local fn = CI and CI.GetItemInfoInstant or rawget(_G, "GetItemInfoInstant")
    local r = { ns.Try(fn, id) }
    info.iconFileID = r[5]
    if info.quality == nil then
        local g = { ns.Try(CI and CI.GetItemInfo or rawget(_G, "GetItemInfo"), id) }
        info.quality = g[3]
    end
    return info
end

-- eine Tasche lesen: { n = Plaetze, f = Taschenart, [Platz] = Text }
local function ReadBag(bag)
    local n = ns.NumSlots(bag)
    if n <= 0 then return nil end
    local t = { n = n }
    local fam = ns.BagFamily(bag)
    if fam ~= 0 then t.f = fam end
    for s = 1, n do
        local info = ns.ItemInfo(bag, s)
        if info then t[s] = Encode(info) end
    end
    return t
end

local function Now() local f = rawget(_G, "time") return type(f) == "function" and f() or 0 end

local function SaveHeader(d)
    local _, class = ns.Try(rawget(_G, "UnitClass"), "player")
    d.class = class or d.class
    d.level = ns.Try(rawget(_G, "UnitLevel"), "player") or d.level
    local g = ns.Try(rawget(_G, "GetGuildInfo"), "player")
    d.guild = (type(g) == "string" and not Peon.IsSecret(g) and g ~= "") and g or nil
    local m = ns.Try(rawget(_G, "GetMoney"))
    if ns.Num(m) then d.money = m end
end

-- Taschen des eingeloggten Charakters speichern
function ns.SaveBags()
    local name = ns.CharName()
    if not name or not mod.db then return false end
    local d = CharData(name, true)
    SaveHeader(d)
    local bags = { t = Now(), list = {} }
    local ids = ns.BagIDs()
    local rb, kb = ns.ReagentBagID(), ns.KeyringID()
    if rb then ids[#ids + 1] = rb end
    if kb then ids[#ids + 1] = kb end
    local any = false
    for _, bag in ipairs(ids) do
        local t = ReadBag(bag)
        if t then
            t.id = bag
            t.kind = (bag == rb and "reagent") or (bag == kb and "keyring") or nil
            bags.list[#bags.list + 1] = t
            any = true
        end
    end
    if any then d.bags = bags end
    return any
end

-- Bank speichern (nur bei offener Bank, sonst meldet das Spiel keine Plaetze). Accountbank gehoert keinem Charakter.
function ns.SaveBank()
    local name = ns.CharName()
    if not name or not mod.db or not ns.bankOpen then return false end
    local bank = { t = Now(), list = {} }
    for _, b in ipairs(ns.BankBags()) do
        if b.kind ~= "account" then
            local t = ReadBag(b.id)
            if t then
                t.id, t.kind = b.id, b.kind ~= "bank" and b.kind or nil
                bank.list[#bank.list + 1] = t
            end
        end
    end
    if #bank.list == 0 then return false end
    local d = CharData(name, true)
    SaveHeader(d)
    d.bank = bank
    return true
end

---------------------------------------------------------------------------
-- Schnittstelle
---------------------------------------------------------------------------
-- Charaktere dieses Realms mit gespeichertem Stand: { { name, level, class, bags, bank, guild }, ... }
-- nach Name sortiert, der eingeloggte Charakter zuerst
function mod:SavedChars()
    local res, me = {}, ns.CharName()
    for name, d in pairs(Realm(false) or {}) do
        if type(d) == "table" then
            res[#res + 1] = { name = name, level = d.level, class = d.class, me = name == me,
                              bags = d.bags and d.bags.t, bank = d.bank and d.bank.t, guild = d.guild }
        end
    end
    if me and not (Realm(false) or {})[me] then res[#res + 1] = { name = me, me = true } end
    table.sort(res, function(a, b)
        if a.me ~= b.me then return a.me end
        return a.name < b.name
    end)
    return res
end

-- Gibt es einen Stand? ort = "bags" | "bank" | "guild". Der eingeloggte Charakter hat seine Taschen immer.
function mod:HasSaved(name, ort)
    ort = ort or "bags"
    if ort == "guild" then return false end   -- Gildenbank erst mit S6
    if ort == "bags" and name ~= nil and name == ns.CharName() then return true end
    local d = CharData(name, false)
    return type(d) == "table" and type(d[ort]) == "table" and true or false
end

-- Taschenfenster mit dem Stand eines Charakters oeffnen (nur ansehen). Rueckgabe true, wenn gezeigt.
function mod:ShowSaved(name, ort)
    ort = ORTE[ort or "bags"] and (ort or "bags") or "bags"
    local w = ns.windows and ns.windows.bag
    if not w then return false end
    if name == nil then name = ns.CharName() end
    if not self:HasSaved(name, ort) then
        mod:Print(ort == "guild" and L.SAVED_GUILD_LATER or L.SAVED_NONE:format(tostring(name)))
        return false
    end
    return ns.SetView(name, ort)
end

---------------------------------------------------------------------------
-- Ansicht im Taschenfenster
---------------------------------------------------------------------------
local function Bag() return ns.windows and ns.windows.bag end

-- aktiv, wenn ein gespeicherter Stand gezeigt wird (anderer Charakter oder Bank unterwegs)
function ns.SavedActive()
    return view.char ~= nil
end

local function LiveFrames(show)
    for bag, f in pairs(ns.bagFrames) do
        if ns.IsInventoryBag(bag) and f:GetParent() == (Bag() and Bag().content) then f:SetShown(show) end
    end
end

-- Alter eines Stands als kurzer Text, ab 7 Tagen gelb
function ns.AgeText(t)
    local now = Now()
    if not ns.Num(t) or t <= 0 or now <= 0 then return "?" end
    local d = math.max(0, now - t)
    local s
    if d < 60 then s = L.AGE_NOW
    elseif d < 3600 then s = L.AGE_MIN:format(math.floor(d / 60))
    elseif d < 86400 then s = L.AGE_HOUR:format(math.floor(d / 3600))
    else s = L.AGE_DAY:format(math.floor(d / 86400)) end
    if d >= 7 * 86400 then s = "|cffffd100" .. s .. "|r" end
    return s
end

-- Knopf fuer einen gespeicherten Platz (kein Taschenknopf, nicht geschuetzt, nur ansehen)
local function ViewButton(w, i)
    w.viewButtons = w.viewButtons or {}
    local b = w.viewButtons[i]
    if b then return b end
    local ok = pcall(function() b = CreateFrame("ItemButton", nil, w.content) end)
    if not ok or not b then ok = pcall(function() b = CreateFrame("Button", nil, w.content, "ItemButtonTemplate") end) end
    if not ok or not b then
        b = CreateFrame("Button", nil, w.content)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
    end
    b:SetSize(ns.SLOT, ns.SLOT)
    b:RegisterForClicks("AnyUp")
    b:SetScript("OnEnter", function(self)
        local info = self.peonInfo
        if not info then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetHyperlink then pcall(GameTooltip.SetHyperlink, GameTooltip, info.itemString) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Umschalt-Klick: Link in den Chat usw. (Blizzards Funktion), sonst nichts
    b:SetScript("OnClick", function(self)
        local info = self.peonInfo
        if not info then return end
        local CI = rawget(_G, "C_Item")
        local g = { ns.Try(CI and CI.GetItemInfo or rawget(_G, "GetItemInfo"), info.itemString) }
        local link = g[2]
        local h = rawget(_G, "HandleModifiedItemClick")
        if type(link) == "string" and type(h) == "function" then pcall(h, link) end
    end)
    b.peonView = true
    w.viewButtons[i] = b
    return b
end

local EMPTY_TEX = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local function FillButton(b, info, bag, slot, fam)
    b.peonInfo, b.peonBag, b.peonSlot, b.peonFam = info, bag, slot, fam or 0
    b.peonQuest, b.peonIsNew, b.peonFree = false, false, nil
    local f = rawget(_G, "SetItemButtonTexture")
    if f then pcall(f, b, info and info.iconFileID or EMPTY_TEX) elseif b.icon then b.icon:SetTexture(info and info.iconFileID or EMPTY_TEX) end
    f = rawget(_G, "SetItemButtonCount")
    if f then pcall(f, b, info and info.stackCount or 0) end
    f = rawget(_G, "SetItemButtonQuality")
    if f then pcall(f, b, mod.db.quality and info and info.quality or nil, info and info.hyperlink) end
    local junk = info and info.quality == 0
    f = rawget(_G, "SetItemButtonTextureVertexColor")
    if f then pcall(f, b, (mod.db.junk and junk) and 0.6 or 1, (mod.db.junk and junk) and 0.6 or 1, (mod.db.junk and junk) and 0.6 or 1) end
    ns.UpdateMatch(b)
end

-- Plaetze eines gespeicherten Orts als Knoepfe: main, extra (wie Inventory/Bank), alle Knoepfe, belegt, gesamt
local EXTRA_TITLE = { reagent = "SEC_REAGENT", keyring = "SEC_KEYRING", reagent_bank = "SEC_REAGENTBANK" }
local function BuildButtons(w, data, ort)
    local main, all, extras, byKind = {}, {}, {}, {}
    local used, total, i = 0, 0, 0
    for _, bag in ipairs(data.list or {}) do
        local list = main
        if bag.kind then
            local key = (ort == "bank" and bag.kind == "reagent") and "reagent_bank" or bag.kind
            if not byKind[key] then
                byKind[key] = { title = L[EXTRA_TITLE[key] or "SEC_OTHER"], items = {},
                                key = key == "reagent_bank" and "reagentbank" or key }
                extras[#extras + 1] = byKind[key]
            end
            list = byKind[key].items
        end
        for s = 1, bag.n or 0 do
            i = i + 1
            local b = ViewButton(w, i)
            local info = ns.DecodeSlot(bag[s])
            FillButton(b, info, bag.id or 0, s, bag.f)
            list[#list + 1] = b
            all[#all + 1] = b
            if not bag.kind then
                total = total + 1
                if info then used = used + 1 end
            end
        end
    end
    for k = i + 1, #(w.viewButtons or {}) do all[#all + 1] = w.viewButtons[k] end
    return main, extras, all, used, total
end

local function OrtButtons(w)
    local d = CharData(view.char, false) or {}
    for _, b in ipairs(w.ortBtns or {}) do
        local has = mod:HasSaved(view.char, b.ort)
        if b.ort == "bags" and view.char == ns.CharName() then has = true end
        if has then b:Enable() else b:Disable() end
        ns.SetButtonOn(b, b.ort == view.ort)
        b.peonHas = has
    end
    return d
end

-- gespeicherten Stand zeigen (wird aus Inventory.Refresh aufgerufen, solange die Ansicht aktiv ist)
function ns.RefreshSaved()
    local w = Bag()
    if not w or not view.char then return end
    local d = OrtButtons(w)
    local data = d[view.ort]
    w.cfgKey = view.ort == "bank" and "bank" or nil   -- Bank im Taschenfenster mit den Einstellungen der Bank
    LiveFrames(false)
    local main, extras, all, used, total = BuildButtons(w, type(data) == "table" and data or {}, view.ort)
    local cfg = w:SectionConfig()
    cfg.keepNew, cfg.dragging = nil, false
    local sections = ns.BuildSections(cfg, main, extras)
    for _, sec in ipairs(sections) do sec.target, sec.dropSlot = nil, nil end   -- nur ansehen
    w:Arrange(sections, all)
    local title = view.ort == "bank" and L.SAVED_TITLE_BANK or L.SAVED_TITLE_BAGS
    w.title:SetText(title:format(view.char, ns.AgeText(type(data) == "table" and data.t)))
    w:SetFooter(L.SAVED_FOOT:format(used, total, total - used), d.money and ns.Money(d.money) or "")
end

local function ApplyMode(w)
    local saved = view.char ~= nil
    if w.sortBtn then w.sortBtn:SetShown(not saved) end
    if w.ortBar then w.ortBar:SetShown(saved) end
    w.bar:SetShown(not saved and mod.db.bagBar and true or false)
    w.minW = saved and 400 or w.liveMinW
    if w.sortBtn and w.charDD then w:ArrangeButtons({ w.sortBtn, w.charDD }) end
    if not saved then
        w.cfgKey = nil
        LiveFrames(true)
        for _, b in ipairs(w.viewButtons or {}) do b:Hide() end
        local name = ns.CharName()
        w.title:SetText(name and (name .. " – " .. L.TITLE_BAGS) or L.TITLE_BAGS)
    end
    if w.charDD and w.charDD.Update then w.charDD:Update() end
end

-- Ansicht wechseln: name = Charakter (nil oder eigener Name mit "bags" = echte Taschen), ort = bags | bank | guild
function ns.SetView(name, ort)
    local w = Bag()
    if not w then return false end
    ort = ORTE[ort or "bags"] and (ort or "bags") or "bags"
    local live = name == nil or (name == ns.CharName() and ort == "bags")
    if InCombatLockdown() then
        -- die echten Taschenknoepfe lassen sich im Kampf nicht aus- und einblenden
        mod:Print(L.MSG_COMBAT)
        ns.Defer("bags:view", function() ns.SetView(name, ort) end)
        return false
    end
    if live then
        view.char, view.ort = nil, "bags"
        ns.SaveBags()   -- eigener Stand fuer die Ansicht spaeter
    else
        if name == ns.CharName() then ns.SaveBags() end
        view.char, view.ort = name, ort
    end
    ApplyMode(w)
    if not w:IsShown() then w:Show() end
    if w.Refresh then w.Refresh() end
    return true
end

---------------------------------------------------------------------------
-- Bedienelemente im Taschenfenster
---------------------------------------------------------------------------
local function CharLabel(c)
    if c.me then return L.SAVED_ME:format(c.name) end
    return c.level and L.SAVED_CHAR_LEVEL:format(c.name, c.level) or c.name
end

local function Current()
    return view.char or ns.CharName()
end

-- Auswahl des Charakters: neue Menue-API, sonst ein Knopf, der die Charaktere der Reihe nach durchgeht
local function BuildCharDropdown(w, width)
    local function Choose(name)
        local ort = view.ort
        if name == ns.CharName() and ort == "bags" then ns.SetView(nil) return end
        if not mod:HasSaved(name, ort) then ort = mod:HasSaved(name, "bags") and "bags" or "bank" end
        if name == ns.CharName() and ort == "bags" then ns.SetView(nil) return end
        ns.SetView(name, ort)
    end
    local ok, dd = pcall(CreateFrame, "DropdownButton", nil, w.buttons, "WowStyle1DropdownTemplate")
    if ok and dd and dd.SetupMenu then
        dd:SetWidth(width)
        dd:SetupMenu(function(_, root)
            for _, c in ipairs(mod:SavedChars()) do
                root:CreateRadio(CharLabel(c), function() return Current() == c.name end,
                    function() mod:Call("Charakter", Choose, c.name) end)
            end
        end)
        dd.Update = function(self)
            if self.GenerateMenu then pcall(self.GenerateMenu, self) end
        end
    else
        dd = ns.SmallButton(w.buttons, "", width, nil, function()
            local list, cur = mod:SavedChars(), Current()
            local nextName = list[1] and list[1].name
            for i, c in ipairs(list) do
                if c.name == cur then nextName = list[i % #list + 1].name end
            end
            if nextName then Choose(nextName) end
        end)
        dd.Update = function(self) self:SetText(Current() or "") end
    end
    -- Tooltip auch fuer die Menue-Variante
    if dd.HookScript then
        dd:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L.SAVED_CHOOSE, 1, 1, 1)
            GameTooltip:AddLine(L.SAVED_CHOOSE_TIP, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        dd:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    dd.Choose = Choose
    dd:Update()
    return dd
end

-- Knoepfe Taschen, Bank, Gildenbank in der Zeile der Taschenleiste (nur in der gespeicherten Ansicht)
local ORT_LIST = { { "bags", "SAVED_BTN_BAGS" }, { "bank", "SAVED_BTN_BANK" }, { "guild", "SAVED_BTN_GUILD" } }
local function BuildOrtBar(w)
    local bar = CreateFrame("Frame", nil, w.frame)
    bar:SetPoint("TOPLEFT", w.bar, "TOPLEFT", 0, 0)
    bar:SetSize(3 * 70, 22)
    w.ortBar, w.ortBtns = bar, {}
    for i, o in ipairs(ORT_LIST) do
        local b = ns.SmallButton(bar, L[o[2]], 66, nil, function()
            if view.char then ns.SetView(view.char, o[1]) end
        end)
        b:SetPoint("LEFT", bar, "LEFT", (i - 1) * 70, 0)
        b.ort = o[1]
        b:SetMotionScriptsWhileDisabled(true)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L[o[2]], 1, 1, 1)
            local tip
            if self.ort == "guild" then tip = L.SAVED_GUILD_LATER
            elseif not self.peonHas then tip = self.ort == "bank" and L.SAVED_NO_BANK or L.SAVED_NO_BAGS
            else
                local d = CharData(view.char, false) or {}
                tip = L.SAVED_FROM:format(ns.AgeText(d[self.ort] and d[self.ort].t))
            end
            GameTooltip:AddLine(tip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        w.ortBtns[i] = b
    end
    bar:Hide()
end

-- aus Inventory.InitInventory: Auswahl und Knoepfe anlegen
function ns.InitSavedView(w)
    w.liveMinW = w.minW
    w.charDD = BuildCharDropdown(w, 130)
    w.charDD:SetPoint("LEFT", w.buttons, "LEFT", w.btnX, 0)
    w.btnX = w.btnX + 134
    BuildOrtBar(w)
    return w.charDD
end

-- beim Schliessen des Fensters wieder die echten Taschen
function ns.ResetView()
    if not view.char then return end
    if InCombatLockdown() then ns.Defer("bags:reset", ns.ResetView) return end
    view.char, view.ort = nil, "bags"
    local w = Bag()
    if w then ApplyMode(w) end
end

---------------------------------------------------------------------------
-- Wann gespeichert wird
---------------------------------------------------------------------------
mod:On("LOGIN", function()
    Store()
    local CT = rawget(_G, "C_Timer")
    if CT and type(CT.After) == "function" then
        CT.After(5, function() mod:Call("Speichern", ns.SaveBags) end)
    end
    -- Abmelden und /reload: Taschen sichern
    pcall(mod.RegisterEvent, mod, "PLAYER_LOGOUT", function() pcall(ns.SaveBags) end)
    -- Bank: beim Oeffnen (kurz danach, wenn die Plaetze da sind) und bei jeder Aenderung, solange sie offen ist
    local banker = ns.PIT("Banker", 8)
    local function SaveBankSoon()
        if CT and type(CT.After) == "function" then
            CT.After(0.5, function() mod:Call("Bank speichern", ns.SaveBank) end)
        else
            mod:Call("Bank speichern", ns.SaveBank)
        end
    end
    pcall(mod.RegisterEvent, mod, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
        if kind == banker then SaveBankSoon() end
    end)
    pcall(mod.RegisterEvent, mod, "BANKFRAME_OPENED", SaveBankSoon)
    mod:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if ns.bankOpen then mod:Call("Bank speichern", ns.SaveBank) end
    end)
    for _, e in ipairs({ "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED" }) do
        pcall(mod.RegisterEvent, mod, e, function() if ns.bankOpen then mod:Call("Bank speichern", ns.SaveBank) end end)
    end
end)

-- Rueckfrage vor dem Loeschen (nur Eintrag in StaticPopupDialogs hinzufuegen)
if type(rawget(_G, "StaticPopupDialogs")) == "table" then
    StaticPopupDialogs.PEON_BAGS_SAVED_DELETE = {
        text = L.SAVED_DELETE_Q, button1 = rawget(_G, "YES") or "Yes", button2 = rawget(_G, "NO") or "No",
        timeout = 0, whileDead = 1, hideOnEscape = 1,
        OnAccept = function(_, name)
            if ns.DeleteSaved(name) then
                mod:Print(L.MSG_SAVED_DELETED:format(name))
                if ns.OnSavedChanged then mod:Call("Optionen", ns.OnSavedChanged) end
            end
        end,
    }
end

-- Gespeicherten Stand eines Charakters loeschen (Optionen)
function ns.DeleteSaved(name)
    local realm = Realm(false)
    if not realm or not realm[name] then return false end
    realm[name] = nil
    if view.char == name then ns.SetView(nil) end
    return true
end
