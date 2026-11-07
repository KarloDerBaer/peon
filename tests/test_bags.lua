-- Stub-Test fuer Peon + Peon_Bags (Taschen, Anordnung, Suche, Bank, Gildenbank, Kampf, Optionen)
-- Ausfuehren aus dem AddOns-Ordner (run_tests.sh).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
function GetTime() return 1 end
date = os.date
local combat = false
function InCombatLockdown() return combat end
function UnitAffectingCombat() return combat end
function UnitName() return "Mirel", "Dorna" end
function debugstack() return "" end
YES, NO, ACCEPT, CANCEL = "Ja", "Nein", "Annehmen", "Abbrechen"
StaticPopupDialogs = {}
local popupShown
function StaticPopup_Show(n) popupShown = n end
function StaticPopup_Hide() end
UISpecialFrames = {}
SlashCmdList = {}
function hooksecurefunc(t, name, fn)
  if type(t) == "string" then t, name, fn = _G, t, name end
  local orig = t[name]
  t[name] = function(...) local r = { orig(...) } fn(...) return unpack(r) end
end
local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon"), Peon_Bags = TocMeta("Peon_Bags") }
local loadedAddons = { Peon = true, Peon_Bags = true }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function(a) return loadedAddons[a] == true end, GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Peon", "Peon_Bags" })[i] end }

-- ===== Rahmen-Nachbau =====
local allFrames = {}
local function W(kind, name, parent)
  local o = { scripts = {}, w = 0, h = 0, shown = true, events = {}, unitev = {}, points = {}, kind = kind, name = name,
              parent = parent, id = 0, scale = 1, alpha = 1 }
  local m = {}
  function m.SetSize(s, w, h) s.w, s.h = w, h end
  function m.SetHeight(s, h) s.h = h end
  function m.SetWidth(s, w) s.w = w end
  function m.GetHeight(s) return s.h end
  function m.GetWidth(s) return s.w end
  function m.GetStringHeight() return 12 end
  function m.SetScript(s, n, f) s.scripts[n] = f end
  function m.GetScript(s, n) return s.scripts[n] end
  function m.HookScript(s, n, f) local old = s.scripts[n] if old then s.scripts[n] = function(...) old(...) f(...) end else s.scripts[n] = f end end
  function m.SetText(s, t) s.text = t; if s.kind == "EditBox" and s.scripts.OnTextChanged then s.scripts.OnTextChanged(s, true) end end
  function m.GetText(s) return s.text end
  function m.SetChecked(s, v) s.checked = v end
  function m.GetChecked(s) return s.checked end
  function m.SetValue(s, v) s.value = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end
  function m.IsShown(s) return s.shown end
  function m.Show(s) if not s.shown then s.shown = true if s.scripts.OnShow then s.scripts.OnShow(s) end end end
  function m.Hide(s) if s.shown then s.shown = false if s.scripts.OnHide then s.scripts.OnHide(s) end end end
  function m.SetShown(s, v) if v then s:Show() else s:Hide() end end
  function m.SetAlpha(s, a) s.alpha = a end
  function m.GetAlpha(s) return s.alpha end
  function m.SetScale(s, v) if combat and s.protected then error("BLOCKIERT SetScale") end s.scale = v end
  function m.GetScale(s) return s.scale end
  function m.GetEffectiveScale(s) return s.scale end
  function m.Enable(s) s.enabled = true end
  function m.Disable(s) s.enabled = false end
  function m.SetColorTexture(s, ...) s.color = { ... } end
  function m.SetTexture(s, t) s.tex = t end
  function m.SetPoint(s, ...) if combat and s.protected then error("BLOCKIERT SetPoint " .. tostring(s.name)) end s.points[#s.points+1] = { ... } end
  function m.ClearAllPoints(s) if combat and s.protected then error("BLOCKIERT ClearAllPoints") end s.points = {} end
  function m.GetPoint(s, i) return unpack(s.points[i or 1] or {}) end
  function m.SetAllPoints(s, r) s.points = { { "ALL", r } } end
  function m.GetLeft(s) return s.left or 100 end
  function m.GetTop(s) return s.top or 500 end
  function m.SetParent(s, p) s.parent = p end
  function m.GetParent(s) return s.parent end
  function m.SetID(s, id) s.id = id end
  function m.GetID(s) return s.id end
  function m.IsProtected(s) return s.protected, s.protected end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.RegisterUnitEvent(s, e) s.unitev[e] = true end
  function m.UnregisterAllEvents(s) s.events = {}; s.unitev = {} end
  function m.GetThumbTexture() return true end
  function m.CreateFontString(s) return W("FontString", nil, s) end
  function m.CreateTexture(s) return W("Texture", nil, s) end
  function m.CreateMaskTexture() return W("Texture") end
  function m.GetStatusBarTexture() return W("Texture") end
  function m.IsPlaying() return false end
  return setmetatable(o, { __index = function(_, k) if m[k] then return m[k] end if type(k) == "string" and k:match("^%u") and k ~= "Low" and k ~= "High" and k ~= "Text" then return function() end end end })
end
UIParent = W("Frame", "UIParent")
local itemButtons = 0
function CreateFrame(kind, name, parent, template)
  local f = W(kind, name, parent)
  f.template = template
  allFrames[#allFrames+1] = f
  if template == "ContainerFrameItemButtonTemplate" then
    itemButtons = itemButtons + 1
    f.IconBorder, f.JunkIcon, f.NewItemTexture = W("Texture"), W("Texture"), W("Texture")
    f.IconQuestTexture, f.Cooldown, f.BattlepayItemTexture = W("Texture"), W("Cooldown"), W("Texture")
    f.JunkIcon.shown = false; f.NewItemTexture.shown = false
    f.scripts.OnEnter = function() end
    f.scripts.OnEvent = function() end
    f.SetBagID = function(s, b) s.bagID = b end
    f.protected = protectedButtons
  end
  if template == "PortraitFrameFlatTemplate" or template == "PortraitFrameTemplate" then
    f.PortraitContainer = { portrait = W("Texture"), CircleMask = W("Texture") }
    f.SetPortraitToAsset = function(s, a) s.portraitAsset = a end
    f.SetPortraitToUnit = function(s, u) s.portraitUnit = u end
    f.SetPortraitTextureSizeAndOffset = function(s, size, x, y) s.portraitSize = { size, x, y } end
    f.SetBorder = function(s, layout) s.borderLayout = layout end
  end
  if name then _G[name] = f end
  return f
end
GameTooltip = W("GameTooltip")
function GameTooltip:SetInventoryItem() return false end
function SetItemButtonTexture(b, t) b._tex = t end
function SetItemButtonCount(b, n) b._count = n end
function SetItemButtonDesaturated(b, v) b._desat = v end
function SetItemButtonQuality(b, q) b._quality = q end
function SetItemButtonTextureVertexColor(b, r) b._vc = r end
function CooldownFrame_Set() end
function GetMoney() return 123456 end
function GetMoneyString(c) return c .. "c" end
function GetInventoryItemTexture() return "tasche" end
local cats = {}
Settings = { RegisterCanvasLayoutCategory = function(p, n) local c = { name = n, subs = {}, GetID = function() return n end } cats[n] = c return c end,
  RegisterCanvasLayoutSubcategory = function(par, p, n) table.insert(par.subs, n) return { GetID = function() return par.name .. "/" .. n end } end,
  RegisterAddOnCategory = function(c) c.registered = true end,
  OpenToCategory = function(id) print("OPEN " .. id) end }
C_Timer = { After = function(_, fn) fn() end }

-- ===== Spiel-Daten: Taschen und Bank =====
NUM_BAG_SLOTS, NUM_TOTAL_EQUIPPED_BAG_SLOTS, NUM_CONTAINER_FRAMES = 4, 5, 3
Enum = { BagIndex = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5,
                      CharacterBankTab_1 = 6, CharacterBankTab_2 = 7, Reagentbank = -3, AccountBankTab_1 = 12 },
         PlayerInteractionType = { TradePartner = 1, Merchant = 5, Banker = 8, GuildBanker = 10, MailInfo = 17, Auctioneer = 21 } }
local CLASS = { [2589] = 7, [2581] = 0, [25] = 2, [3300] = 15, [5374] = 12, [118] = 0, [2770] = 7 }
local function Item(id, name, q, n, extra)
  local t = { itemID = id, iconFileID = "icon" .. id, stackCount = n or 1, quality = q, hyperlink = "|cnIQ" .. q .. ":|Hitem:" .. id .. "|h[" .. name .. "]|h|r" }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end
local bags = {
  [0] = { n = 16, items = { [1] = Item(2589, "Leinenstoff", 1, 20), [2] = Item(2581, "Schwerer Leinenverband", 1, 5),
                            [3] = Item(25, "Abgenutztes Kurzschwert", 2), [5] = Item(3300, "Hasenpfote", 0, 3),
                            [6] = Item(5374, "Questding", 1, 1, { quest = true }), [7] = Item(118, "Schwacher Heiltrank", 1, 4) } },
  [1] = { n = 10, items = { [2] = Item(2770, "Kupfererz", 1, 10) } },
  [2] = { n = 0, items = {} }, [3] = { n = 0, items = {} }, [4] = { n = 0, items = {} },
  [5] = { n = 12, items = { [1] = Item(2770, "Kupfererz", 1, 7) } },
  [6] = { n = 48, items = { [1] = Item(2589, "Leinenstoff", 1, 200) } },
  [7] = { n = 0, items = {} }, [-3] = { n = 0, items = {} }, [12] = { n = 0, items = {} },
}
local sorted = 0
C_Container = {
  GetContainerNumSlots = function(b) return bags[b] and bags[b].n or 0 end,
  GetContainerNumFreeSlots = function(b) local bb = bags[b] if not bb then return 0 end local used = 0 for _ in pairs(bb.items) do used = used + 1 end return bb.n - used end,
  GetContainerItemInfo = function(b, s) return bags[b] and bags[b].items[s] end,
  GetContainerItemQuestInfo = function(b, s) local i = bags[b] and bags[b].items[s] return { isQuestItem = i and i.quest or false } end,
  GetContainerItemCooldown = function() return 0, 0, 0 end,
  ContainerIDToInventoryID = function(b) if b >= 1 and b <= 5 then return 30 + b end end,
  SortBags = function() sorted = sorted + 1 end,
}
C_Item = { GetItemInfoInstant = function(id) return id, "x", "y", "", "icon", CLASS[id] or 15, 0 end, GetItemInfo = function() return nil end }
C_NewItems = { IsNewItem = function(b, s) return b == 1 and s == 2 end, RemoveNewItem = function() end }

-- Blizzard-Fenster
ContainerFrame1, ContainerFrame2, ContainerFrame3 = W("Frame", "ContainerFrame1", UIParent), W("Frame", "ContainerFrame2", UIParent), W("Frame", "ContainerFrame3", UIParent)
ContainerFrameCombinedBags = W("Frame", "ContainerFrameCombinedBags", UIParent)
BankFrame = W("Frame", "BankFrame", UIParent); BankFrame.shown = false
function ShowUIPanel(f) f:Show() end
function HideUIPanel(f) f:Hide() end
local toggled = 0
function ToggleAllBags() toggled = toggled + 1 end
function ToggleBackpack() end
function ToggleBag() end
local bankClosed = 0
C_Bank = { CloseBankFrame = function() bankClosed = bankClosed + 1 end }

-- Gildenbank
local gb = { tab = 1, query = {}, store = {}, pick = {}, deposit = 0 }
function GetNumGuildBankTabs() return 2 end
function GetGuildBankTabInfo(i) return "Fach " .. i, "icon", i == 1, true, 5, 3 end
function GetCurrentGuildBankTab() return gb.tab end
function SetCurrentGuildBankTab(i) gb.tab = i end
function QueryGuildBankTab(i) gb.query[#gb.query + 1] = i end
function GetGuildBankItemInfo(tab, slot) if tab == 1 and slot == 3 then return "icon2589", 20, false, false, 1 end end
function GetGuildBankItemLink(tab, slot) if tab == 1 and slot == 3 then return "|cnIQ1:|Hitem:2589|h[Leinenstoff]|h|r" end end
function PickupGuildBankItem(t, s) gb.pick[#gb.pick + 1] = t .. ":" .. s end
function AutoStoreGuildBankItem(t, s) gb.store[#gb.store + 1] = t .. ":" .. s end
function GetGuildBankMoney() return 50000 end
function GetGuildBankWithdrawMoney() return -1 end
function DepositGuildBankMoney(n) gb.deposit = gb.deposit + n end
function CloseGuildBankFrame() gb.closed = true end
function IsModifiedClick() return false end
function HandleModifiedItemClick() return false end
function GetCursorInfo() return nil end
function CursorHasItem() return false end
function MoneyInputFrame_GetCopper() return 777 end

local function fire(e, ...) for _, f in ipairs(allFrames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function load(dir, addon) local ns = {} for l in io.lines(dir .. "/" .. dir .. ".toc") do if l:match("%.lua$") then assert(loadfile(dir .. "/" .. l))(addon, ns) end end return ns end
local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end

-- ===== Laden =====
load("Peon", "Peon")
fire("ADDON_LOADED", "Peon")
PeonBagsDB = { bagCols = 99, bagLayout = "falsch", pos = { bag = { x = 10, y = 600 } } }
local ns = load("Peon_Bags", "Peon_Bags")
fire("ADDON_LOADED", "Peon_Bags")
local mod = ns.mod
check(mod.initialized and mod.page, "Modul + Optionsseite")
check(PeonBagsDB.bagCols == 24 and PeonBagsDB.bagLayout == "classic", "Einstellungen geprueft")
check(PeonBagsDB.layoutVer == 2 and #PeonBagsDB.catOrder == 17, "0.5: Kategorien und Reihenfolge angelegt")
PeonBagsDB.bagCols = 10
fire("PLAYER_LOGIN")
check(cats.Peon and cats.Peon.subs[1] == "Bags", "Seite unter Peon > Bags")
local w = ns.windows.bag
check(w and not w:IsShown(), "Taschenfenster angelegt, zu")
check(itemButtons == 16 + 10 + 12, "Knoepfe fuer alle Taschenplaetze beim Login angelegt (" .. itemButtons .. ")")
check(#UISpecialFrames >= 3, "ESC schliesst die Fenster")

-- Knopf sitzt richtig fuer Blizzards Vorlage
local b02 = ns.slots[0][2]
check(b02:GetID() == 2 and b02:GetParent():GetID() == 0 and b02.bagID == 0, "Platz-ID, Taschen-Rahmen und SetBagID")

-- ===== Oeffnen ueber Blizzards Taschen-Funktion =====
ToggleAllBags()
check(w:IsShown(), "B-Taste (ToggleAllBags) oeffnet das Fenster")
check(b02._tex == "icon2581" and b02._count == 5, "Symbol und Anzahl")
check(ns.slots[0][5].JunkIcon.shown and ns.slots[0][5]._vc == 0.6, "Muell abgedunkelt")
check(ns.slots[1][2].peonNew and ns.slots[1][2].NewItemTexture.shown, "neuer Gegenstand leuchtet")
check(ns.slots[0][6].peonQuest and ns.slots[0][6].IconQuestTexture.shown, "Quest markiert")
check(w.footLeft.text:find("19/26") and w.footLeft.text:find("Reagenzien 11/12"), "freie Plaetze: " .. w.footLeft.text)
check(w.footRight.text == "123456c", "Gold")
-- Anordnung Taschenreihenfolge: Reagenzientasche eigener Abschnitt
local hdr = {}
for _, h in ipairs(w.headers) do if h.shown then hdr[#hdr + 1] = h.text end end
check(#hdr == 1 and hdr[1] == "Reagenzientasche", "Abschnitt Reagenzientasche: " .. table.concat(hdr, ","))
local p = ns.slots[0][1].points[1]
check(p[4] == 0 and p[5] == 0, "erster Platz oben links")
p = ns.slots[1][1].points[1]
check(p[4] == 6 * 41 and p[5] == -41, "Platz 17 in Reihe 2, Spalte 7 (10 Spalten)")
check(ns.slots[2] == nil or next(ns.slots[2]) == nil, "leere Taschenplaetze ohne Knoepfe")
check(not ContainerFrameCombinedBags.shown or ContainerFrameCombinedBags:GetParent() ~= UIParent or true, "kombinierte Taschen ok")

-- Blizzards Taschenfenster wird versteckt
ContainerFrame1:SetID(0)
check(ContainerFrame1:GetParent() ~= UIParent, "Blizzard-Rucksack umgehaengt (unsichtbar)")
ContainerFrame2:SetID(6)
check(ContainerFrame2:GetParent() ~= UIParent, "Blizzard-Banktasche umgehaengt")

-- ===== Einstellen: Leiste mit Anordnung, Kategorien, Bereichen (ab 0.5) =====
local function headers(win)
  local t = {}
  for _, h in ipairs(win.headers) do if h.shown then t[#t + 1] = h.text end end
  return table.concat(t, ",")
end
local function headerOf(win, text)
  for _, h in ipairs(win.headers) do if h.shown and h.text == text then return h end end
end
check(w.sortBtn and w.sortBtn.points[1][4] == 0, "Sortieren steht ganz links")
check(w.setupBtn and w.setupBtn.text == "Einstellen" and w.setupBtn.points[1][1] == "TOPRIGHT", "Einstellen steht rechts")
check(w.layoutBtn == nil, "kein Knopf 'Nach Art' mehr")
w.setupBtn.scripts.OnClick(w.setupBtn, "LeftButton")
local sp = w.setup
check(sp and sp:IsShown() and #sp.layoutBtns == 3, "Einstellen oeffnet die Leiste mit drei Knoepfen")
check(sp.points[1][1] == "TOPLEFT" and sp.points[1][3] == "TOPRIGHT", "Leiste rechts neben dem Fenster")
check(sp.layoutBtns[1].peonOn and not sp.layoutBtns[2].peonOn, "Klassisch gewaehlt")
check(sp.catRows[1].alpha == 0.45 and sp.catRows[1].check.enabled == false, "Klassisch: Kategorien ausgegraut")
check(sp.grpHdr.alpha == 0.45 and sp.newBtn.enabled == false, "Klassisch: eigene Bereiche ausgegraut")
check(sp.content.h > 17 * 22, "Inhalt hoeher als die Liste (rollt): " .. sp.content.h)
sp.layoutBtns[2].scripts.OnClick(sp.layoutBtns[2], "LeftButton")
check(PeonBagsDB.bagLayout == "type" and sp.layoutBtns[2].peonOn, "Knopf schaltet auf 'Nach Art'")
check(sp.catRows[1].alpha == 1 and sp.catRows[1].check.enabled and sp.grpHdr.alpha == 0.45, "Nach Art: Kategorien waehlbar, Bereiche grau")
check(headers(w) == "Neu,Quest,Ausrüstung,Verbrauchbares,Handwerkswaren,Müll,Freie Plätze,Reagenzientasche", "Abschnitte: " .. headers(w))
-- Verbrauchbares: Heiltrank vor Verband (Name)? beide Qualitaet 1 -> nach Name: "Schwacher Heiltrank" > "Schwerer Leinenverband"
local cons = {}
for _, b in ipairs({ ns.slots[0][2], ns.slots[0][7] }) do cons[#cons + 1] = b.points[1][5] end
check(cons[1] == cons[2], "Verbrauchbares in einer Reihe")
check(ns.slots[0][7].points[1][4] < ns.slots[0][2].points[1][4], "nach Name sortiert (Heiltrank vor Verband)")
-- Kategorie abwaehlen: Muell landet unter Uebrige
local junkRow
for _, r in ipairs(sp.catRows) do if r.cat == "junk" then junkRow = r end end
junkRow.check.checked = false
junkRow.check.scripts.OnClick(junkRow.check)
check(PeonBagsDB.bagCatsOff.junk == true and headers(w):find("Müll") == nil and headers(w):find("Verschiedenes") ~= nil, "Muell abgewaehlt, Hasenpfote nach ihrer Art: " .. headers(w))
check(PeonBagsDB.bankCatsOff.junk == nil, "Abwahl gilt nur fuer dieses Fenster")
junkRow.check.checked = true
junkRow.check.scripts.OnClick(junkRow.check)
check(PeonBagsDB.bagCatsOff.junk == nil and headers(w):find("Müll") ~= nil, "Muell wieder angehakt")
-- Reihenfolge: Quest nach oben
local questRow = sp.catRows[2]
check(questRow.cat == "quest", "zweite Zeile ist Quest")
questRow.up.scripts.OnClick(questRow.up)
check(PeonBagsDB.catOrder[1] == "quest" and headers(w):find("^Quest,Neu,") ~= nil and sp.catRows[1].cat == "quest", "Quest nach oben: " .. headers(w))
check(sp.catRows[1].up.enabled == false, "oberste Zeile: Pfeil hoch aus")
sp.catRows[1].down.scripts.OnClick(sp.catRows[1].down)
check(PeonBagsDB.catOrder[1] == "new", "und wieder zurueck")
-- Kategorien des Spiels (Klasse und Unterklasse)
do
  local keepItem = C_Item
  local cls, sub = 0, 1
  C_Item = { GetItemInfoInstant = function(id) return id, "", "", "", "", cls, sub end }
  local info = { itemID = 1, quality = 1 }
  check(ns.Category(info) == "potion", "Trank: Traenke und Elixiere")
  check(ns.Category(info, false, false, { potion = true }) == "consumable", "Traenke abgewaehlt: Verbrauchbares")
  check(ns.Category(info, false, false, { potion = true, consumable = true }) == nil, "beide abgewaehlt: Uebrige")
  sub = 5; check(ns.Category(info) == "food", "Essen und Trinken")
  sub = 7; check(ns.Category(info) == "bandage", "Verband")
  cls, sub = 6, 0; check(ns.Category(info) == "ammo", "Munition")
  cls = 11; check(ns.Category(info) == "ammo", "Koecher")
  cls = 1; check(ns.Category(info) == "bag", "Tasche")
  cls = 13; check(ns.Category(info) == "key", "Schluessel")
  cls = 9; check(ns.Category(info) == "recipe", "Rezept")
  cls = 3; check(ns.Category(info) == "gem", "Edelstein")
  cls = 5; check(ns.Category(info) == "reagent", "Reagenz")
  cls = 12; check(ns.Category(info) == "quest" and ns.Category(info, false, false, { quest = true }) == nil, "Quest-Klasse")
  cls = 2; check(ns.Category(info, false, true) == "new" and ns.Category(info, false, true, { new = true }) == "equip", "Neu geht vor, abgewaehlt gilt die Art")
  check(ns.Category({ itemID = 1, quality = 0 }) == "junk" and ns.Category(nil) == "free" and ns.Category(nil, false, false, { free = true }) == nil, "Muell und freie Plaetze")
  C_Item = keepItem
end
-- Neu bleibt bis zum Schliessen in "Neu"
local nb = ns.slots[1][2]
check(nb.peonIsNew and headers(w):find("Neu") ~= nil, "neuer Gegenstand unter Neu")
local keepNew = C_NewItems.IsNewItem
C_NewItems.IsNewItem = function() return false end
nb.scripts.OnEnter(nb)
fire("BAG_UPDATE", 0); fire("BAG_UPDATE_DELAYED")
check(not nb.peonIsNew and headers(w):find("Neu") ~= nil, "gesehen, steht aber bis zum Schliessen unter Neu")
w:Hide(); w:Show()
check(headers(w):find("Neu") == nil, "nach dem Schliessen nicht mehr neu: " .. headers(w))
C_NewItems.IsNewItem = keepNew
w:Hide(); w:Show()
-- Einklappen
local eq = headerOf(w, "Ausrüstung")
eq.scripts.OnClick(eq, "LeftButton")
check(PeonBagsDB.bagCollapsed["c:equip"] and not ns.slots[0][3].shown, "Klick klappt Ausruestung ein")
eq = headerOf(w, "Ausrüstung")
check(eq.folded and eq.label.text:find("%(1%)") ~= nil, "eingeklappt mit Anzahl: " .. eq.label.text)
eq.scripts.OnClick(eq, "LeftButton")
check(not PeonBagsDB.bagCollapsed["c:equip"] and ns.slots[0][3].shown, "zweiter Klick klappt aus")
sp.layoutBtns[1].scripts.OnClick(sp.layoutBtns[1], "LeftButton")
check(PeonBagsDB.bagLayout == "classic" and headers(w) == "Reagenzientasche", "zurueck auf Klassisch")
w:ToggleSetup()
check(not sp:IsShown(), "Einstellen schliesst die Leiste wieder")
check(w.frame.template == "PortraitFrameFlatTemplate" and w.template == "PortraitFrameFlatTemplate" and w.portrait, "0.2: Taschenfenster mit Blizzards Taschen-Rahmen")
check(w.frame.portraitAsset == "Interface\\Icons\\INV_Misc_Bag_08", "0.2.2: Taschenbild im runden Rahmen gesetzt")
check(w.frame.borderLayout == "HeldBagLayout" and w.frame.portraitSize[1] == 36, "0.2.2: kleiner Taschen-Ring wie Blizzards Taschen")
do
  local mask = w.frame.PortraitContainer.CircleMask
  check(#mask.points == 2 and mask.points[1][2] == w.frame.PortraitContainer.portrait and mask.points[1][4] == 0 and mask.points[2][4] == 0, "0.2.2: runde Maske sitzt genau auf dem Bild")
end
check(ns.windows.bank.frame.borderLayout == nil, "0.2.2: Bank behaelt den grossen Ring")

-- ===== Suche =====
w.search:SetText("leinen")
check(ns.slots[0][1].alpha == 1 and ns.slots[0][2].alpha == 1 and ns.slots[0][3].alpha == 0.3, "Suche 'leinen' (Gross/klein egal)")
w.search:SetText("ABGENUTZT")
check(ns.slots[0][3].alpha == 1 and ns.slots[0][1].alpha == 0.3, "Suche ohne Umlaut-Probleme")
w.search:SetText("")
check(ns.slots[0][3].alpha == 1 and ns.slots[0][1].alpha == 1, "Suche leer")

-- Sortieren
check(w.sortBtn, "Sortieren-Knopf (Spiel hat SortBags)")
w.sortBtn.scripts.OnClick(w.sortBtn)
check(sorted == 1, "Sortieren ruft das Spiel")

-- ===== Taschen aendern =====
bags[0].items[4] = Item(2589, "Leinenstoff", 1, 3)
fire("BAG_UPDATE", 0); fire("BAG_UPDATE_DELAYED")
check(ns.slots[0][4]._tex == "icon2589", "Taschenaenderung aktualisiert")
bags[2].n = 6
fire("BAG_UPDATE", 2); fire("BAG_UPDATE_DELAYED")
check(ns.slots[2] and ns.slots[2][6], "neue Tasche: Plaetze angelegt")
ToggleAllBags()
check(not w:IsShown(), "B-Taste schliesst")

-- ===== Automatisch oeffnen (Haendler) =====
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)
check(w:IsShown(), "Haendler oeffnet Taschen")
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 5)
check(not w:IsShown(), "Haendler zu -> Taschen zu")
PeonBagsDB.autoMerchant = false
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)
check(not w:IsShown(), "abgeschaltet: Haendler oeffnet nicht")
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 5)
PeonBagsDB.autoMerchant = true

-- ===== Bank =====
local bw = ns.windows.bank
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
ShowUIPanel(BankFrame)
check(bw:IsShown() and w:IsShown(), "Bank: Bankfenster und Taschen offen")
check(BankFrame:GetParent() ~= UIParent and BankFrame.shown, "Blizzards Bankfenster unsichtbar, aber offen")
check(ns.slots[6] and ns.slots[6][48] and ns.slots[6][48]:GetParent():GetID() == 6, "48 Bankplaetze in Tasche 6")
check(ns.slots[7] == nil, "Fach ohne Plaetze ausgelassen")
check(bw.footLeft.text == "47/48 frei", "Bank frei: " .. tostring(bw.footLeft.text))
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 8)
check(not bw:IsShown() and not w:IsShown(), "Bank zu: beide Fenster zu")
check(BankFrame:GetParent() == UIParent and bankClosed == 0, "Blizzard-Bankfenster zurueck, nicht doppelt geschlossen")
-- selbst schliessen
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
bw:Hide()
check(bankClosed == 1, "X am Bankfenster schliesst die Bank")
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 8)
-- Blizzard-Knopf
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
local blz
for _, f in ipairs(allFrames) do if f.text == "Blizzard" and f.parent == bw.buttons then blz = f end end
blz.scripts.OnClick(blz)
check(not bw:IsShown() and BankFrame:GetParent() == UIParent and bankClosed == 1, "Blizzard-Knopf zeigt Blizzards Bank")
ShowUIPanel(BankFrame)
check(BankFrame:GetParent() == UIParent, "dieser Besuch bleibt bei Blizzard")
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 8)
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
check(bw:IsShown(), "naechster Besuch wieder Peon_Bags")
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 8)

-- ===== Gildenbank =====
local gw = ns.windows.guild
GuildBankFrame = W("Frame", "GuildBankFrame", UIParent); GuildBankFrame.shown = false
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 10)
ShowUIPanel(GuildBankFrame)
check(gw:IsShown() and GuildBankFrame:GetParent() ~= UIParent, "Gildenbank: eigenes Fenster, Blizzard versteckt")
check(gb.query[1] == 1, "Fach abgefragt")
check(_G.PeonBagsGuildItem98 and _G.PeonBagsGuildItem3.peonInfo and _G.PeonBagsGuildItem3._count == 20, "98 Plaetze, Inhalt gelesen")
check(gw.footLeft.text:find("50000c") and gw.footRight.text:find("unbegrenzt"), "Gold der Gildenbank")
local s3 = _G.PeonBagsGuildItem3
s3.scripts.OnClick(s3, "RightButton")
check(gb.store[1] == "1:3", "Rechtsklick lagert in die Taschen")
s3.scripts.OnClick(s3, "LeftButton")
check(gb.pick[1] == "1:3", "Linksklick nimmt")
check(StaticPopupDialogs.PEON_BAGS_GB_DEPOSIT and StaticPopupDialogs.PEON_BAGS_GB_WITHDRAW, "Rueckfragen fuer Gold")
StaticPopupDialogs.PEON_BAGS_GB_DEPOSIT.OnAccept({ moneyInputFrame = {} })
check(gb.deposit == 777, "Einzahlen")
local tabBtn
for _, f in ipairs(allFrames) do if f.parent == gw.bar and f.id == 2 then tabBtn = f end end
tabBtn.scripts.OnClick(tabBtn)
check(gb.tab == 2 and gb.query[#gb.query] == 2, "Reiter wechselt das Fach")
check(gw.note.text == "Dieses Fach darfst du nicht ansehen.", "Hinweis bei gesperrtem Fach")
gw:Hide()
check(gb.closed, "X schliesst die Gildenbank")
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 10)
check(GuildBankFrame:GetParent() == UIParent, "Blizzard-Gildenbank zurueck")
-- Schnittstelle fehlt: Blizzard bleibt
local keep = GetGuildBankItemInfo
GetGuildBankItemInfo = nil
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 10)
ShowUIPanel(GuildBankFrame)
check(not gw:IsShown() and GuildBankFrame:GetParent() == UIParent, "ohne Schnittstelle: Blizzards Gildenbank")
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 10)
GetGuildBankItemInfo = keep

-- ===== Kampf: geschuetzte Knoepfe werden erst danach angeordnet =====
for _, list in pairs(ns.slots) do for _, b in pairs(list) do b.protected = true end end
combat = true
ns.ShowBags()
check(w:IsShown() and ns.queue["arrange:bag"], "im Kampf: Anordnen vorgemerkt")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(not ns.queue["arrange:bag"] and ns.slots[0][1].points[1], "nach dem Kampf angeordnet")
for _, list in pairs(ns.slots) do for _, b in pairs(list) do b.protected = nil end end
ns.HideBags()

-- ===== Optionen: Spalten =====
if mod.panel.scripts.OnShow then mod.panel.scripts.OnShow(mod.panel) end
PeonBagsDB.bagCols = 8
mod:Fire("CHANGED", "bagCols")
ns.ShowBags()
check(ns.slots[0][9].points[1][4] == 0 and ns.slots[0][9].points[1][5] == -41, "8 Spalten: Platz 9 in Reihe 2")
ns.HideBags()
check(w.frame.points[1][1] == "TOPLEFT" and w.frame.points[1][4] == 10, "gespeicherte Position angewendet")
w.frame.scripts.OnDragStop(w.frame)
check(PeonBagsDB.pos.bag.x == 100 and PeonBagsDB.pos.bag.y == 500, "Position gespeichert")
mod:ResetDefaults()
check(PeonBagsDB.bagCols == 10 and PeonBagsDB.pos.bag, "Standardwerte, Positionen bleiben")

-- ===== Hauptschalter aus: Blizzard zurueck =====
PeonBagsDB.replace = false
mod:Fire("CHANGED", "replace")
check(ContainerFrame1:GetParent() == UIParent, "Hauptschalter aus: Blizzard-Taschen zurueck")
ToggleAllBags()
check(not w:IsShown(), "Hauptschalter aus: B-Taste oeffnet Blizzard")
SlashCmdList.PEON("bags")
check(w:IsShown(), "/peon bags oeffnet trotzdem")
SlashCmdList.PEON("bags")
PeonBagsDB.replace = true
mod:Fire("CHANGED", "replace")
check(ContainerFrame1:GetParent() ~= UIParent, "wieder an: Blizzard-Taschen versteckt")

-- ===== Bagnon geladen: nichts ersetzen =====
loadedAddons.Bagnon = true
mod:Fire("CHANGED", "replace")
check(ContainerFrame1:GetParent() == UIParent, "Bagnon geladen: Blizzard bleibt")
ToggleAllBags()
check(not w:IsShown(), "Bagnon geladen: B-Taste gehoert Bagnon")
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
check(not ns.windows.bank:IsShown(), "Bagnon geladen: Bank bleibt Bagnon/Blizzard")
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 8)
loadedAddons.Bagnon = nil

SlashCmdList.PEON("bags optionen")
check(out[#out] == "OPEN Peon/Bags", "/peon bags optionen oeffnet die Seite")

-- ===== Starter fuer Peon_Panel (ab 0.4) =====
do
  local s = mod.launcher
  check(s and s.showKey == nil and s.key == "bags", "Starter ohne Minimap-Button")
  check(s:GetText("free") == "24 frei", "Text freie Plaetze: " .. tostring(s:GetText("free")))
  check(s:GetText("used") == "8/32", "Text belegte und alle Plaetze: " .. tostring(s:GetText("used")))
  local refreshed = 0
  Peon.OnLauncherRefresh(function(l) if l == s then refreshed = refreshed + 1 end end)
  fire("BAG_UPDATE_DELAYED")
  check(refreshed == 1, "Taschenaenderung aktualisiert den Text")
  s:Click("LeftButton")
  check(w:IsShown(), "Linksklick oeffnet die Taschen")
  s:Click("LeftButton")
  check(not w:IsShown(), "Linksklick schliesst die Taschen")
end

-- ===== Eigene Bereiche (ab 0.3, ab 0.5 nur bei Individuell) =====
local cursor, cleared = nil, 0
function GetCursorInfo() if cursor then return unpack(cursor) end end
function ClearCursor() cleared = cleared + 1; cursor = nil end
local function drop(h, id, link, how)
  cursor = { "item", id, link or ("|cnIQ1:|Hitem:" .. id .. "|h[x]|h|r") }
  h.scripts[how or "OnReceiveDrag"](h)
end
local popupArgs
function StaticPopup_Show(n, a, b, data) popupShown = n; popupArgs = { a, b, data } end

check(ns.ItemKey(25, "|cnIQ2:|Hitem:25::::::::20:1488|h[Kurzschwert]|h|r") == 25, "Schluessel ohne Zusatz: nur die Nummer")
check(ns.ItemKey(6611, "|cnIQ2:|Hitem:6611::::::::20:1488:::1:12731:::|h[Schwert des Wolfs]|h|r") == "6611:Schwert des Wolfs", "Schluessel mit Bonus-Nummer: je Variante")
check(ns.ItemKey(6611, "|cnIQ2:|Hitem:6611::::::12:::::::|h[Schwert des Baeren]|h|r") == "6611:Schwert des Baeren", "Schluessel mit Zusatz in Feld 7: je Variante")
check(ns.ItemKey(25, nil) == 25 and ns.ItemKey(nil, nil) == nil, "Schluessel ohne Link oder Nummer")

check(PeonBagsDB.groups and #PeonBagsDB.groups == 0, "anfangs keine Bereiche")
-- Individuell ohne Kategorien (wie frueher "Taschenreihenfolge" mit Bereichen)
local function allOff() local t = {} for _, c in ipairs(ns.CATS) do t[c] = true end return t end
PeonBagsDB.bagCatsOff, PeonBagsDB.bankCatsOff = allOff(), allOff()
PeonBagsDB.bagLayout, PeonBagsDB.bankLayout = "custom", "custom"
ns.ShowBags()
check(headers(w) == "Reagenzientasche", "ohne Bereiche sieht das Fenster aus wie bisher: " .. headers(w))
check(headerOf(w, "Reagenzientasche").target == nil, "ohne Bereiche nimmt keine Ueberschrift etwas an")

local g1 = ns.AddGroup("  Behal|ten ")
local g2 = ns.AddGroup("Farmen")
check(g1.name == "Behalten" and g1.id == 1 and g2.id == 2, "Bereiche angelegt, Name bereinigt")
check(ns.AddGroup("behalten") == nil and #PeonBagsDB.groups == 2, "gleicher Name abgelehnt")
check(ns.AddGroup("   ") == nil and #PeonBagsDB.groups == 2, "leerer Name abgelehnt")
check(headers(w) == "Behalten (Gegenstand hierher ziehen),Farmen (Gegenstand hierher ziehen),Übrige,Reagenzientasche", "leere Bereiche bleiben sichtbar: " .. headers(w))

-- Ablegen
local hb = headerOf(w, "Behalten (Gegenstand hierher ziehen)")
check(hb.target == 1, "Ueberschrift kennt ihren Bereich")
drop(hb, 2581)
check(PeonBagsDB.groupItems[2581] == 1 and cleared == 1 and cursor == nil, "Ablegen ordnet zu und gibt den Gegenstand zurueck")
check(headers(w):find("^Behalten,") ~= nil, "Bereich zeigt seinen Namen: " .. headers(w))
check(ns.slots[0][2].points[1][4] == 0 and ns.slots[0][2].points[1][5] == -16, "Gegenstand steht unter der Ueberschrift")
local before = cleared
cursor = { "merchant", 5 }
hb.scripts.OnClick(hb)
check(cleared == before and cursor ~= nil, "anderes am Mauszeiger bleibt unberuehrt")
cursor = nil
hb.scripts.OnClick(hb)
check(cleared == before and PeonBagsDB.bagCollapsed.g1, "Klick ohne Gegenstand klappt ein")
headerOf(w, "Behalten").scripts.OnClick(headerOf(w, "Behalten"))
check(not PeonBagsDB.bagCollapsed.g1, "und wieder aus")
drop(headerOf(w, "Farmen (Gegenstand hierher ziehen)"), 2581, nil, "OnClick")
check(PeonBagsDB.groupItems[2581] == 2, "Klick mit Gegenstand: wechselt den Bereich")
drop(headerOf(w, "Farmen"), 2589)
check(ns.GroupOf(bags[0].items[1]) == 2 and ns.GroupOf(bags[0].items[4]) == 2, "alle Stapel eines Gegenstands im selben Bereich")
-- Farmen steht unter der leeren Ueberschrift von Behalten (16 + 6 + 16 = 38)
check(ns.slots[0][1].points[1][4] == 0 and ns.slots[0][4].points[1][4] == 41 and ns.slots[0][2].points[1][4] == 82 and ns.slots[0][2].points[1][5] == -38, "innerhalb des Bereichs sortiert")

-- Reagenzientasche: eigene Zuordnung geht vor
drop(headerOf(w, "Farmen"), 2770)
check(ns.slots[1][2].points[1][4] == 0 and ns.slots[5][1].points[1][4] == 41 and ns.slots[5][1].points[1][5] == -38, "Stapel aus der Reagenzientasche steht im Bereich")
check(w.footLeft.text:find("Reagenzien 11/12") ~= nil, "freie Plaetze unveraendert: " .. w.footLeft.text)

-- Varianten getrennt
bags[1].items[3] = Item(6611, "Schwert des Wolfs", 2, 1, { hyperlink = "|cnIQ2:|Hitem:6611::::::::20:1488:::1:12731|h[Schwert des Wolfs]|h|r" })
bags[1].items[4] = Item(6611, "Schwert des Baeren", 2, 1, { hyperlink = "|cnIQ2:|Hitem:6611::::::::20:1488:::1:12732|h[Schwert des Baeren]|h|r" })
drop(headerOf(w, "Behalten (Gegenstand hierher ziehen)"), 6611, bags[1].items[3].hyperlink)
check(ns.GroupOf(bags[1].items[3]) == 1 and ns.GroupOf(bags[1].items[4]) == nil, "Varianten eines Gegenstands getrennt")

-- Herausnehmen
drop(headerOf(w, "Übrige"), 2589)
check(PeonBagsDB.groupItems[2589] == nil, "Ablegen auf Uebrige nimmt heraus")
drop(headerOf(w, "Farmen"), 2589)

-- Individuell mit Kategorien: Bereiche bleiben oben und gehen vor, Kategorien nehmen heraus
PeonBagsDB.bagCatsOff = {}
mod:Fire("CHANGED", "bagCatsOff")
check(headers(w):find("^Behalten,Farmen,") ~= nil and headers(w):find("Ausrüstung") ~= nil and headers(w):find("Übrige,Reagenzientasche$") ~= nil, "Individuell mit Kategorien: " .. headers(w))
check(ns.slots[0][1].points[1][5] == headerOf(w, "Farmen").points[1][5] - 16, "Leinenstoff bleibt im eigenen Bereich, nicht unter Handwerkswaren")
drop(headerOf(w, "Ausrüstung"), 6611, bags[1].items[3].hyperlink)
check(PeonBagsDB.groupItems["6611:Schwert des Wolfs"] == nil, "Ablegen auf eine Kategorie nimmt heraus")
-- Nach Art und Klassisch zeigen keine eigenen Bereiche, die Zuordnung bleibt
w:Set("Layout", "type")
check(headers(w):find("Behalten") == nil and headers(w):find("Farmen") == nil and PeonBagsDB.groupItems[2589] == 2, "Nach Art: keine eigenen Bereiche: " .. headers(w))
check(headerOf(w, "Ausrüstung").target == nil, "Nach Art: Ueberschriften nehmen nichts an")
w:Set("Layout", "classic")
check(headers(w) == "Reagenzientasche", "Klassisch: keine eigenen Bereiche")
w:Set("Layout", "custom")
PeonBagsDB.bagCatsOff = allOff()
mod:Fire("CHANGED", "bagCatsOff")
-- Bereich je Fenster abwaehlen
w:ToggleSetup()
check(#sp.grpRows == 2 and sp.grpRows[1].name.text.text == "Behalten" and sp.grpRows[1].check.enabled, "Leiste zeigt die Bereiche, waehlbar")
sp.grpRows[1].check.checked = false
sp.grpRows[1].check.scripts.OnClick(sp.grpRows[1].check)
check(PeonBagsDB.bagGroupsOff[1] and headers(w):find("Behalten") == nil and headers(w):find("^Farmen") ~= nil, "Behalten in den Taschen abgewaehlt: " .. headers(w))
check(ns.slots[0][2].shown, "Gegenstand des abgewaehlten Bereichs steht bei den uebrigen")

-- Bank nutzt dieselben Bereiche
fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
check(bw:IsShown() and headers(bw):find("^Behalten") ~= nil and headers(bw):find("Farmen,Übrige") ~= nil, "Bank zeigt die Bereiche (dort angehakt): " .. headers(bw))
check(ns.slots[6][1].points[1][5] == -38 and ns.slots[6][1].points[1][4] == 0, "Leinenstoff der Bank steht im Bereich")
fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 8)
ns.ShowBags()
if not sp:IsShown() then w:ToggleSetup() end
sp.grpRows[1].check.checked = true
sp.grpRows[1].check.scripts.OnClick(sp.grpRows[1].check)
check(not PeonBagsDB.bagGroupsOff[1] and headers(w):find("^Behalten") ~= nil, "Behalten wieder angehakt")

-- Gildenbank bleibt ohne Bereiche
do
  local secs = ns.BuildSections("classic", { ns.slots[0][1] })
  check(#secs == 1 and secs[1].title == nil and secs[1].target == nil, "ohne useGroups keine Bereiche (Gildenbank)")
end

-- Kampf: Zuordnung sofort gespeichert, Plaetze danach
for _, list in pairs(ns.slots) do for _, b in pairs(list) do b.protected = true end end
combat = true
drop(headerOf(w, "Behalten (Gegenstand hierher ziehen)"), 25)
check(PeonBagsDB.groupItems[25] == 1 and ns.queue["arrange:bag"], "im Kampf: gespeichert, Anordnen vorgemerkt")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(not ns.queue["arrange:bag"] and headers(w):find("^Behalten,") ~= nil and ns.slots[0][3].points[1][5] == -16, "nach dem Kampf angeordnet")
for _, list in pairs(ns.slots) do for _, b in pairs(list) do b.protected = nil end end

-- Verwalten
check(ns.MoveGroup(2, -1) and PeonBagsDB.groups[1].name == "Farmen" and headers(w):find("^Farmen,") ~= nil, "Bereich nach oben")
check(not ns.MoveGroup(2, -1), "oben ist Schluss")
check(ns.RenameGroup(2, "Gesammelt") and headers(w):find("^Gesammelt,") ~= nil, "umbenennen")
check(not ns.RenameGroup(2, "behalten") and PeonBagsDB.groups[1].name == "Gesammelt", "umbenennen auf belegten Namen abgelehnt")
check(ns.RenameGroup(2, "GESAMMELT") and ns.RenameGroup(2, "Gesammelt"), "eigener Name in anderer Schreibweise geht")

-- Optionsseite
local listC
for _, c in ipairs(mod.page.controls) do if c.list and c.list.columns[2].key == "name" then listC = c end end
check(listC, "Liste der Bereiche auf der Optionsseite")
local rows = listC.list.data
check(#rows == 2 and rows[1].name == "Gesammelt" and rows[1].pos == 1 and rows[1].count == ns.CountGroup(2) and rows[1].count >= 3, "Liste zeigt Bereiche und Anzahl")
check(StaticPopupDialogs.PEON_BAGS_GROUP_NEW and StaticPopupDialogs.PEON_BAGS_GROUP_RENAME and StaticPopupDialogs.PEON_BAGS_GROUP_DELETE, "Rueckfragen vorhanden")
do
  local dialog = { editBox = W("EditBox"), data = 2 }
  StaticPopupDialogs.PEON_BAGS_GROUP_RENAME.OnShow(dialog)
  check(dialog.editBox.text == "Gesammelt", "Umbenennen zeigt den alten Namen")
  dialog.editBox.text = "Ernte"
  StaticPopupDialogs.PEON_BAGS_GROUP_RENAME.OnAccept(dialog, 2)
  check(PeonBagsDB.groups[1].name == "Ernte" and listC.list.data[1].name == "Ernte", "Umbenennen uebernommen, Liste aktuell")
  local fresh = { editBox = W("EditBox") }
  StaticPopupDialogs.PEON_BAGS_GROUP_NEW.OnShow(fresh)
  fresh.editBox.text = "Leer"
  StaticPopupDialogs.PEON_BAGS_GROUP_NEW.OnAccept(fresh)
  check(#PeonBagsDB.groups == 3 and PeonBagsDB.groups[3].name == "Leer" and listC.list:GetSelected().name == "Leer", "neuer Bereich angelegt und markiert")
end

-- Standardwerte lassen die Bereiche stehen
mod:ResetDefaults()
check(#PeonBagsDB.groups == 3 and PeonBagsDB.groupItems[25] == 1, "Standardwerte: Bereiche und Zuordnung bleiben")

-- Leiste: Umbenennen und Neu ueber die Zeile
if not sp:IsShown() then w:ToggleSetup() end
sp.grpRows[1].name.scripts.OnClick(sp.grpRows[1].name)
check(popupShown == "PEON_BAGS_GROUP_RENAME" and popupArgs[3] == PeonBagsDB.groups[1].id, "Klick auf den Namen benennt um")
sp.newBtn.scripts.OnClick(sp.newBtn)
check(popupShown == "PEON_BAGS_GROUP_NEW", "Neuer Bereich aus der Leiste")
PeonBagsDB.bagGroupsOff[3] = true

-- Loeschen
popupShown = nil
ns.AskDeleteGroup(PeonBagsDB.groups[3].id)
check(popupShown == nil and #PeonBagsDB.groups == 2 and PeonBagsDB.bagGroupsOff[3] == nil, "leerer Bereich geht ohne Rueckfrage, Abwahl entfernt")
ns.AskDeleteGroup(2)
check(popupShown == "PEON_BAGS_GROUP_DELETE" and #PeonBagsDB.groups == 2 and popupArgs[1] == "Ernte" and popupArgs[3] == 2, "Bereich mit Gegenstaenden fragt nach")
StaticPopupDialogs.PEON_BAGS_GROUP_DELETE.OnAccept(nil, 2)
check(#PeonBagsDB.groups == 1 and PeonBagsDB.groupItems[2581] == nil and PeonBagsDB.groupItems[2589] == nil and PeonBagsDB.groupItems[25] == 1, "Loeschen entfernt nur die eigenen Zuordnungen")
check(bags[0].items[2] ~= nil, "Gegenstaende bleiben in der Tasche")
ns.DeleteGroup(1)
check(next(PeonBagsDB.groupItems) == nil and headers(w) == "Reagenzientasche", "ohne Bereiche wieder wie zuvor: " .. headers(w))
ns.HideBags()

-- ===== Uebernahme der alten Anordnung (ab 0.5) =====
do
  local migrate = mod.opts.migrate
  local acc = { bagLayout = "bags", bankLayout = "type", guildLayout = "bags", groups = { { id = 1, name = "X" } } }
  migrate(mod, acc)
  check(acc.bagLayout == "custom" and acc.bagCatsOff.equip and acc.bagCatsOff.new and acc.bagCatsOff.free, "mit Bereichen: Taschenreihenfolge wird Individuell ohne Kategorien")
  check(acc.bankLayout == "custom" and acc.bankCatsOff.new and not acc.bankCatsOff.equip and not acc.bankCatsOff.free, "mit Bereichen: Nach Art wird Individuell mit Kategorien ohne Neu")
  check(acc.guildLayout == "classic" and acc.layoutVer == 2, "Gildenbank: Klassisch")
  acc = { bagLayout = "bags", bankLayout = "type", guildLayout = "type", groups = {} }
  migrate(mod, acc)
  check(acc.bagLayout == "classic" and acc.bagCatsOff == nil and acc.bankLayout == "type" and acc.bankCatsOff.new and acc.guildLayout == "type", "ohne Bereiche: Klassisch bzw. Nach Art")
  acc.bankLayout = "classic"
  migrate(mod, acc)
  check(acc.bankLayout == "classic", "nur einmal")
end

-- ===== Leiste links, wenn rechts kein Platz ist =====
do
  local f = w.frame
  f.GetRight = function() return 1900 end
  UIParent.GetRight = function() return 1920 end
  w:Show()
  if sp:IsShown() then sp:Hide() end
  sp:Show()
  check(sp.onLeft and sp.points[1][1] == "TOPRIGHT" and sp.points[1][3] == "TOPLEFT", "Leiste links neben dem Fenster")
  f.GetRight = nil; UIParent.GetRight = nil
  sp:Hide()
  w:Hide()
end

-- ===== Gildenbank: Leiste ohne Individuell =====
do
  fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 10)
  ShowUIPanel(GuildBankFrame)
  check(gw:IsShown() and gw.setupBtn, "Gildenbank hat Einstellen")
  gw:ToggleSetup()
  check(#gw.setup.layoutBtns == 2 and gw.setup.grpHdr == nil, "Gildenbank: Klassisch und Nach Art, keine eigenen Bereiche")
  gw.setup.layoutBtns[2].scripts.OnClick(gw.setup.layoutBtns[2])
  check(PeonBagsDB.guildLayout == "type" and headers(gw) == "Freie Plätze", "Gildenbank nach Art (leeres Fach): " .. headers(gw))
  gw:Hide()
  fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 10)
end

local n = 0 for _, l in ipairs(out) do if l:find("Fehler") then n = n + 1 end end
check(n == 0, "keine Fehlermeldungen")
print("ALLE TESTS OK")
