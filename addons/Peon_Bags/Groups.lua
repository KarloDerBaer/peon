-- Peon_Bags - Groups.lua
-- Eigene Bereiche (ab 0.3): selbst benannte Abschnitte in Taschen und Bank, accountweit.
-- Konzept: Peon_Bags_Bereiche.md
--   PeonBagsDB.groups     = { { id = 1, name = "Behalten" }, ... }   Reihenfolge wie angezeigt
--   PeonBagsDB.groupItems = { [itemID oder "itemID:voller Name"] = Bereich-id }
-- Die Bereiche aendern nur die Anzeige, kein Gegenstand wird verschoben.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

ns.GROUP_NONE = "none"   -- Ablegen auf einer festen Ueberschrift: Gegenstand verlaesst seinen Bereich

function ns.Groups() return mod.db.groups end

function ns.GroupByID(id)
    for i, g in ipairs(ns.Groups()) do
        if g.id == id then return g, i end
    end
end

---------------------------------------------------------------------------
-- Schluessel eines Gegenstands: itemID, bei Zusatz ("... des Wolfs") je Variante "itemID:voller Name".
-- Ein Zusatz steht im Link in Feld 7 oder als Bonus-Nummer (Feld 13 = Anzahl der Boni).
---------------------------------------------------------------------------
function ns.ItemKey(itemID, link)
    if not ns.Num(itemID) then return nil end
    if type(link) ~= "string" or Peon.IsSecret(link) then return itemID end
    local body = link:match("item:([^|]*)")
    if not body then return itemID end
    local f = {}
    for part in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = part end
    local suffix, bonus = tonumber(f[7]), tonumber(f[13])
    if (suffix and suffix ~= 0) or (bonus and bonus > 0) then
        local name = link:match("%[(.-)%]")
        if name and name ~= "" then return itemID .. ":" .. name end
    end
    return itemID
end

-- Bereich-id eines Gegenstands (info wie C_Container.GetContainerItemInfo), nil = keiner
function ns.GroupOf(info)
    if not info then return nil end
    local key = ns.ItemKey(info.itemID, info.hyperlink)
    return key ~= nil and mod.db.groupItems[key] or nil
end

function ns.CountGroup(id)
    local n = 0
    for _, g in pairs(mod.db.groupItems) do
        if g == id then n = n + 1 end
    end
    return n
end

local function Changed() mod:Fire("CHANGED", "groups") end

---------------------------------------------------------------------------
-- Bereiche verwalten
---------------------------------------------------------------------------
-- Pipes entfernen, damit ein Name keine Farb- oder Link-Codes enthalten kann
local function CleanName(name)
    return strtrim((tostring(name or ""):gsub("|", "")))
end

local function NameTaken(name, exceptID)
    local fold = ns.Fold(name)
    for _, g in ipairs(ns.Groups()) do
        if g.id ~= exceptID and ns.Fold(g.name) == fold then return true end
    end
    return false
end

local function CheckName(name, exceptID)
    if name == "" then return false end
    if NameTaken(name, exceptID) then
        mod:Print(L.MSG_GROUP_EXISTS:format(name))
        return false
    end
    return true
end

-- Rueckgabe: neuer Bereich oder nil
function ns.AddGroup(name)
    name = CleanName(name)
    if not CheckName(name) then return nil end
    local id = 0
    for _, g in ipairs(ns.Groups()) do id = math.max(id, g.id) end
    local g = { id = id + 1, name = name }
    table.insert(ns.Groups(), g)
    Changed()
    return g
end

function ns.RenameGroup(id, name)
    local g = ns.GroupByID(id)
    name = CleanName(name)
    if not g or not CheckName(name, id) then return false end
    g.name = name
    Changed()
    return true
end

-- delta = -1 nach oben, 1 nach unten
function ns.MoveGroup(id, delta)
    local list = ns.Groups()
    local _, i = ns.GroupByID(id)
    local j = i and i + delta
    if not j or j < 1 or j > #list then return false end
    list[i], list[j] = list[j], list[i]
    Changed()
    return true
end

-- Entfernt den Bereich und seine Zuordnungen, die Gegenstaende bleiben in der Tasche
function ns.DeleteGroup(id)
    local _, i = ns.GroupByID(id)
    if not i then return false end
    table.remove(ns.Groups(), i)
    local items = mod.db.groupItems
    for key, g in pairs(items) do
        if g == id then items[key] = nil end
    end
    -- Die Nummer kann spaeter wieder vergeben werden: Abwahl und Einklappen je Fenster mit entfernen
    for _, k in ipairs({ "bagGroupsOff", "bankGroupsOff", "bagCollapsed", "bankCollapsed" }) do
        local t = mod.db[k]
        if type(t) == "table" then t[id] = nil; t["g" .. id] = nil end
    end
    Changed()
    return true
end

---------------------------------------------------------------------------
-- Ablegen auf einer Ueberschrift (per Ziehen oder Klick mit Gegenstand am Mauszeiger)
---------------------------------------------------------------------------
function ns.DropOnHeader(target)
    local cursor = rawget(_G, "GetCursorInfo")
    if type(cursor) ~= "function" then return end
    local kind, itemID, link = cursor()
    if kind ~= "item" then return end
    local key = ns.ItemKey(itemID, link)
    if key == nil then return end
    if target == ns.GROUP_NONE then
        mod.db.groupItems[key] = nil
    elseif ns.GroupByID(target) then
        mod.db.groupItems[key] = target
    else
        return
    end
    -- Der Gegenstand geht zurueck in seinen Platz
    if ClearCursor then ClearCursor() end
    Changed()
end

---------------------------------------------------------------------------
-- Rueckfragen (nur Eintraege in StaticPopupDialogs hinzufuegen)
---------------------------------------------------------------------------
local function PopupEditBox(dialog)
    return dialog.editBox or dialog.EditBox or (dialog.GetEditBox and dialog:GetEditBox())
end

local function NamePopup(key, text, prefill, accept)
    StaticPopupDialogs[key] = {
        text = text,
        button1 = rawget(_G, "ACCEPT") or "OK", button2 = rawget(_G, "CANCEL") or "Cancel",
        hasEditBox = true, maxLetters = 30,
        OnShow = function(self)
            local eb = PopupEditBox(self)
            if eb then
                eb:SetText(prefill(self.data))
                eb:HighlightText()
                eb:SetFocus()
            end
        end,
        OnAccept = function(self, data)
            local eb = PopupEditBox(self)
            if eb then mod:Call("Bereich", accept, eb:GetText(), data) end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            StaticPopupDialogs[key].OnAccept(parent, parent.data)
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end

-- neu angelegter Bereich: fuer die Optionsseite, damit er gleich markiert ist
NamePopup("PEON_BAGS_GROUP_NEW", L.GROUP_NEW_Q, function() return "" end, function(text)
    local g = ns.AddGroup(text)
    if g and ns.OnGroupAdded then ns.OnGroupAdded(g) end
end)

NamePopup("PEON_BAGS_GROUP_RENAME", L.GROUP_RENAME_Q, function(id)
    local g = ns.GroupByID(id)
    return g and g.name or ""
end, function(text, id)
    ns.RenameGroup(id, text)
end)

StaticPopupDialogs["PEON_BAGS_GROUP_DELETE"] = {
    text = L.GROUP_DELETE_Q,
    button1 = rawget(_G, "YES") or "Yes", button2 = rawget(_G, "NO") or "No",
    OnAccept = function(_, id) mod:Call("Bereich", ns.DeleteGroup, id) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- Loeschen: mit Gegenstaenden erst nachfragen, ein leerer Bereich geht sofort
function ns.AskDeleteGroup(id)
    local g = ns.GroupByID(id)
    if not g then return end
    local n = ns.CountGroup(id)
    if n > 0 then
        StaticPopup_Show("PEON_BAGS_GROUP_DELETE", g.name, n, id)
    else
        ns.DeleteGroup(id)
    end
end
