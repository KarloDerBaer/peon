-- Peon-Kern: Pruefbefehl fuer das UI-Design (UIProbe.lua, ab 0.18.0).
-- Nachgebaute Rahmen mit Grafiken, Schriften und Kindern. Prueft: Atlas/Datei/Ausschnitt/Farbe werden gelesen,
-- Namen relativ zum Fenster, Tiefe und Zeilengrenze, Pfad aufloesen, Maus, fehlende Vorlagen, Speichern in PeonDB,
-- Leeren, Slash ueber /peon ui, keine Aenderung an den geprueften Rahmen.
-- Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
local out = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, " "); io.write("  > ", out[#out], "\n") end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return os.getenv("LOC") or "deDE" end
function GetTime() return 1 end
date, time = os.date, os.time
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
function GetBuildInfo() return "1.60.1", "70888", "Nov 10 2026", 16001 end
SlashCmdList = {}

local function fail(msg) print("FEHLER: " .. msg); os.exit(1) end
local function check(c, msg) if not c then fail(msg) end end
local function find(lines, pat) for _, l in ipairs(lines) do if l:find(pat, 1, true) then return l end end end

local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon") }
C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
  IsAddOnLoaded = function() return true end, GetNumAddOns = function() return 1 end,
  GetAddOnInfo = function(i) return ({ "Peon" })[i] end }

-- Rahmen, Grafiken und Schriften nachgebaut (nur was UIProbe liest)
local writes = 0
local function Region(kind, name, data)
  local r = data or {}
  r.kind, r.name = kind, name
  function r.GetObjectType(s) return s.kind end
  function r.GetDebugName(s) return s.name end
  function r.GetName(s) return s.name end
  function r.GetSize(s) return s.w or 0, s.h or 0 end
  function r.IsShown(s) return s.shown ~= false end
  function r.GetNumPoints(s) return s.point and 1 or 0 end
  function r.GetPoint(s) return s.point[1], s.point[2], s.point[3], s.point[4], s.point[5] end
  function r.GetDrawLayer(s) return s.layer or "ARTWORK", 0 end
  function r.GetAtlas(s) return s.atlas end
  function r.GetTexture(s) return s.file end
  function r.GetTexCoord(s) if s.tc then return unpack(s.tc) end return 0, 0, 0, 1, 1, 0, 1, 1 end
  function r.GetVertexColor(s) if s.col then return unpack(s.col) end return 1, 1, 1, 1 end
  function r.GetAlpha(s) return s.alpha or 1 end
  function r.GetBlendMode(s) return s.blend or "BLEND" end
  function r.GetFont(s) return s.font and s.font[1], s.font and s.font[2], s.font and s.font[3] end
  function r.GetFontObject(s) return s.fontObj end
  function r.GetTextColor(s) if s.tcol then return unpack(s.tcol) end return 1, 1, 1, 1 end
  function r.GetShadowOffset(s) return 1, -1 end
  function r.GetJustifyH(s) return s.justify or "CENTER" end
  function r.GetText(s) return s.text end
  -- Schreibzugriffe zaehlen: die Pruefung darf Blizzards Rahmen nie aendern
  function r.SetAtlas() writes = writes + 1 end
  function r.SetTexture() writes = writes + 1 end
  function r.SetPoint() writes = writes + 1 end
  return r
end
local function Frame(name, data, regions, children)
  local f = Region("Frame", name, data)
  f.regions, f.children = regions or {}, children or {}
  function f.GetRegions(s) return unpack(s.regions) end
  function f.GetChildren(s) return unpack(s.children) end
  function f.GetFrameStrata() return "HIGH" end
  function f.GetFrameLevel() return 5 end
  function f.GetScale() return 1 end
  function f.IsVisible(s) return s.shown ~= false end
  function f.GetParent(s) return s.parent end
  for _, c in ipairs(f.children) do c.parent = f end
  return f
end

local fontObj = { GetName = function() return "Number14FontWhite" end }
local catBg = Region("Texture", "AuctionHouseFrame.CategoriesList.Background",
  { atlas = "auctionhouse-background-categories", file = 5353150, w = 138, h = 434, layer = "BACKGROUND", point = { "TOPLEFT", nil, "TOPLEFT", 3, -3 } })
local marble = Region("Texture", "AuctionHouseFrame.ItemList.Background",
  { file = "Interface\\FrameGeneral\\UI-Background-Marble", tc = { 0, 0, 0, 0.5, 1, 0, 1, 0.5 }, col = { 0.5, 0.5, 0.5, 1 } })
local title = Region("FontString", "AuctionHouseFrame.TitleText",
  { font = { "Fonts\\FRIZQT__.TTF", 12, "" }, tcol = { 1, 0.82, 0, 1 }, text = "Auktionshaus", fontObj = fontObj, justify = "LEFT" })
local cats = Frame("AuctionHouseFrame.CategoriesList", { w = 160, h = 450, layoutType = "InsetFrameTemplate", backgroundAtlas = "auctionhouse-background-categories" }, { catBg })
local list = Frame("AuctionHouseFrame.ItemList", { w = 600, h = 400 }, { marble })
-- tiefe Kette fuer die Tiefengrenze
local deep = Frame("AuctionHouseFrame.D1.D2.D3.D4.D5.D6.D7.D8.D9.D10")
for i = 9, 1, -1 do deep = Frame("AuctionHouseFrame.D" .. i, nil, nil, { deep }) end
AuctionHouseFrame = Frame("AuctionHouseFrame", { w = 800, h = 538 }, { title }, { cats, list, deep })
AuctionHouseFrame.CategoriesList = cats
AuctionHouseFrame.ItemList = list
local hiddenWin = Frame("ProfessionsFrame", { shown = false })
ProfessionsFrame = hiddenWin

C_Texture = { GetAtlasInfo = function(name)
  if name == "auctionhouse-background-categories" then
    return { file = 5353150, filename = "Interface/AuctionFrame/AuctionHouseBackgrounds", width = 138, height = 434,
             leftTexCoord = 0, rightTexCoord = 0.25, topTexCoord = 0, bottomTexCoord = 0.5, tilesHorizontally = false }
  end
  if name == "_UI-Frame-Metal-EdgeTop" then error("kaputt") end
  return nil end }
GameFontNormal = { GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end, GetTextColor = function() return 1, 0.82, 0, 1 end,
  GetShadowOffset = function() return 1, -1 end, GetShadowColor = function() return 0, 0, 0, 1 end }

-- CreateFrame: eigene Vorlagen-Rahmen, unbekannte Vorlagen werfen wie im Spiel einen Fehler
local created = {}
UIParent = Frame("UIParent")
function CreateFrame(kind, name, parent, tmpl)
  if tmpl == "SettingsCheckboxTemplate" then error("Couldn't find inherited node \"" .. tmpl .. "\"") end
  local f = Frame(name or "?", { w = 100, h = 22 })
  f.kind = kind
  function f.SetSize() end
  function f.SetPoint() end
  function f.Hide(s) s.shown = false end
  function f.CreateTexture() return Region("Texture", "t") end
  if tmpl == "UIPanelButtonTemplate" then
    local n = Region("Texture", (name or "?") .. ".Left", { atlas = "128-RedButton-Left" })
    function f.GetNormalTexture() return n end
    function f.GetFontString() return Region("FontString", (name or "?") .. ".Text", { text = "OK", font = { "Fonts\\FRIZQT__.TTF", 12, "" } }) end
    function f.GetNormalFontObject() return { GetName = function() return "GameFontNormal" end } end
  end
  if name then _G[name] = f end
  created[#created + 1] = f
  -- uebrige Methoden (Ereignisse, Skripte) tun nichts
  return setmetatable(f, { __index = function(_, k) if type(k) == "string" and k:match("^%u") then return function() end end end })
end

-- Kern laden
local function load(dir, files)
  local ns = {}
  for _, f in ipairs(files) do
    local chunk, err = loadfile(dir .. "/" .. f)
    if not chunk then fail(err) end
    chunk(dir, ns)
  end
  return ns
end
local ns = load("Peon", { "Locales.lua", "Core.lua", "Module.lua", "Options.lua", "UIProbe.lua", "Slash.lua" })
check(ns.UIProbe, "UIProbe fehlt")
check(meta.Peon.Version == "0.19.0", "Version 0.19.0 in der TOC")
local toc = io.open("Peon/Peon.toc"):read("*a")
check(toc:find("UIProbe.lua\r?\nSlash.lua"), "UIProbe.lua vor Slash.lua in der TOC")
PeonDB = {}
Peon.db = PeonDB
local P = ns.UIProbe

-- 1. Beschreibung eines Fensters
local lines = P.Frame("AuctionHouseFrame")
local l = find(lines, "TEX .CategoriesList.Background")
check(l, "Hintergrund der Kategorien fehlt")
check(l:find("atlas=auctionhouse%-background%-categories") and l:find("file=5353150") and l:find("138x434"), "Atlas, Datei, Groesse: " .. l)
check(l:find("layer=BACKGROUND:0"), "Ebene: " .. l)
check(l:find("@TOPLEFT>%-:TOPLEFT%(3,%-3%)"), "Anker: " .. l)
l = find(lines, "TEX .ItemList.Background")
check(l:find("Marble") and l:find("tc=0,0,0,0.5,1,0,1,0.5") and l:find("col=0.5,0.5,0.5"), "Datei mit Ausschnitt und Farbe: " .. l)
l = find(lines, "FONT .TitleText")
check(l:find("obj=Number14FontWhite") and l:find("font=Fonts\\FRIZQT__.TTF/12/") and l:find("col=1,0.82,0") and l:find("j=LEFT") and l:find('text="Auktionshaus"'), "Schrift: " .. l)
l = find(lines, "FRAME .CategoriesList")
check(l:find("layout=InsetFrameTemplate") and l:find("bgAtlas=auctionhouse%-background%-categories"), "Rahmen mit Vorlage: " .. l)
check(lines[1]:find("strata=HIGH:5"), "Ebene des Fensters: " .. lines[1])
check(find(lines, "FRAME .D9"), "Tiefe 9 erreicht")
check(not find(lines, "FRAME .D9.D10"), "Tiefe begrenzt")
check(writes == 0, "Pruefung hat Blizzards Rahmen veraendert")

-- 2. Zeilengrenze
P.MAX_LINES = 5
lines = P.Frame("AuctionHouseFrame")
check(#lines <= 6 and lines[#lines] == "…", "Zeilengrenze: " .. #lines .. " " .. tostring(lines[#lines]))
P.MAX_LINES = 2500

-- 3. Pfad aufloesen
check(P.Resolve("AuctionHouseFrame.CategoriesList") == cats, "Pfad")
check(P.Resolve("AuctionHouseFrame.Gibtsnicht") == nil and P.Resolve("") == nil and P.Resolve(nil) == nil, "falscher Pfad")

-- 4. Atlanten: vorhanden, fehlt, Fehler im Spiel
local at, missing = P.Atlases()
l = find(at, "auctionhouse-background-categories ")
check(l and l:find("name=Interface/AuctionFrame/AuctionHouseBackgrounds") and l:find("tc=0,0.25,0,0.5"), "Atlas-Info: " .. tostring(l))
check(find(at, "_UI-Frame-Metal-EdgeTop FEHLT"), "Fehler beim Abfragen = fehlt")
check(missing == #P.ATLASES - 1, "Zahl der fehlenden Atlanten")

-- 5. Schriften
local fonts = P.Fonts()
l = find(fonts, "GameFontNormal ")
check(l and l:find("col=1,0.82,0") and l:find("shadow=1,%-1"), "Schrift-Objekt: " .. tostring(l))
check(find(fonts, "Number14FontWhite FEHLT"), "fehlendes Schrift-Objekt")

-- 6. Vorlagen: angelegt, fehlende ohne Abbruch, zweiter Lauf legt nichts doppelt an
local tl = P.Templates()
check(find(tl, "### UIPanelButtonTemplate (Button)"), "Vorlage Knopf")
check((find(tl, "TEX NormalTexture") or ""):find("atlas=128-RedButton-Left", 1, true), "Knopf-Grafik")
check(find(tl, 'FontString') and find(tl, "normalFont=GameFontNormal"), "Knopf-Schrift")
check(find(tl, "### SettingsCheckboxTemplate FEHLT"), "fehlende Vorlage")
local n1 = #created
P.Templates()
check(#created == n1, "Vorlagen doppelt angelegt")

-- 7. Befehl ueber /peon ui pruefen: alles, nur sichtbare Fenster
out = {}
SlashCmdList.PEON("ui pruefen")
local s = PeonDB.uiProbe
check(s and s.build == "70888" and s.toc == 16001 and s.peon == "0.19.0", "Kopf der Pruefung")
check(#s.atlas == #P.ATLASES and #s.fonts == #P.FONTS and #s.templates > 0, "Atlanten, Schriften, Vorlagen gespeichert")
check(s.frames.AuctionHouseFrame and #s.frames.AuctionHouseFrame.lines > 5, "offenes Fenster gespeichert")
check(not s.frames.ProfessionsFrame, "verstecktes Fenster nicht gespeichert")
check(find(out, "AuctionHouseFrame") and find(out, "/reload"), "Chat-Ausgabe")

-- 8. einzelner Pfad, unbekannter Pfad
SlashCmdList.PEON("ui pruefen AuctionHouseFrame.CategoriesList")
check(s.frames["AuctionHouseFrame.CategoriesList"], "Pfad gespeichert")
out = {}
SlashCmdList.PEON("ui pruefen Gibts.Nicht")
check(find(out, "nicht gefunden"), "unbekannter Rahmen")

-- 9. Maus: Kette der Eltern, hoechstens 10 Eintraege
GetMouseFoci = function() return { cats } end
for i = 1, 12 do SlashCmdList.PEON("ui pruefen maus") end
check(#s.mouse == 10, "hoechstens 10 Maus-Pruefungen")
check(s.mouse[1].name == "AuctionHouseFrame.CategoriesList", "Maus-Name")
check(s.mouse[1].lines[2]:find("in AuctionHouseFrame"), "Kette der Eltern")
GetMouseFoci = function() return {} end
out = {}
SlashCmdList.PEON("ui pruefen maus")
check(find(out, "kein Rahmen"), "nichts unter der Maus")

-- 10. Hilfe und Leeren
out = {}
SlashCmdList.PEON("ui hilfe")
check(find(out, "/peon ui pruefen maus"), "Hilfe")
SlashCmdList.PEON("ui pruefen leeren")
check(PeonDB.uiProbe == nil, "Leeren")
out = {}
SlashCmdList.PEON("hilfe")
check(find(out, "/peon ui pruefen"), "Hilfe von /peon nennt ui pruefen")

print("ALLE TESTS OK")
