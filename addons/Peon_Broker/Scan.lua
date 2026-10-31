-- Peon_Broker - Scan.lua
-- Komplettscan des Auktionshauses (C_AuctionHouse.ReplicateItems, geht alle 15 Minuten) und
-- Auswertung in kleinen Portionen, damit das Spiel nicht stockt. Knopf "Broker-Scan" unter dem
-- Auktionshausfenster, dazu /broker scan.
--
-- Ablauf: Start -> REPLICATE_ITEM_LIST_UPDATE -> "read" (Angebote lesen, je Bild S.CHUNK Stueck)
--         -> "sum" (je Gegenstand niedrigster und typischer Preis) -> Data.Record -> Data.Compact

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local S = {}
ns.Scan = S

S.COOLDOWN  = 15 * 60   -- Sekunden zwischen zwei Komplettscans (Vorgabe des Spiels)
S.CHUNK     = 1500      -- Angebote je Bild
S.SUM_CHUNK = 300       -- Gegenstaende je Bild
S.TIMEOUT   = 90        -- Sekunden ohne Antwort -> abbrechen
S.ahOpen    = false

local function AH() return rawget(_G, "C_AuctionHouse") end

function S.Remaining()
    local last = mod.acc and mod.acc.lastScanAt
    if type(last) ~= "number" then return 0 end
    return math.max(0, last + S.COOLDOWN - time())
end

function S.FormatTime(sec)
    sec = math.max(0, math.floor(sec))
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

-- "vor 5 Min." / "vor 3 Std." / "vor 2 Tagen"
function S.Age(t)
    if type(t) ~= "number" then return "" end
    local d = math.max(0, time() - t)
    if d < 3600 then return L.AGE_MIN:format(math.max(1, math.floor(d / 60))) end
    if d < 48 * 3600 then return L.AGE_HOURS:format(math.floor(d / 3600)) end
    return L.AGE_DAYS:format(math.floor(d / 86400))
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
function S.Start()
    if S.state then mod:Print(L.SCAN_BUSY); return false end
    if not S.ahOpen then mod:Print(L.SCAN_NEED_AH); return false end
    local ah = AH()
    if not ah or type(ah.ReplicateItems) ~= "function" then mod:Print(L.MSG_SCAN_NO_API); return false end
    local rem = S.Remaining()
    if rem > 0 then mod:Print(L.SCAN_WAIT:format(S.FormatTime(rem))); return false end

    local ok, err = pcall(ah.ReplicateItems)
    if not ok then mod:Print(L.MSG_SCAN_ERROR:format(tostring(err))); return false end
    mod.acc.lastScanAt = time()
    local state = { phase = "wait", market = ns.MarketKey(), t0 = GetTime(), started = time() }
    S.state = state
    if ns.Radar and ns.Radar.OnFullScan then mod:Call("Radar", ns.Radar.OnFullScan) end   -- ab 0.19: Radar-Scan beenden
    mod:Print(L.SCAN_STARTED)
    mod:Dbg("Scan angefordert, Markt " .. state.market)
    S.UpdateButton()
    if C_Timer and C_Timer.After then
        C_Timer.After(S.TIMEOUT, function()
            if S.state == state and state.phase == "wait" then
                S.state = nil
                mod:Print(L.SCAN_TIMEOUT:format(S.TIMEOUT))
                S.UpdateButton()
            end
        end)
    end
    return true
end

-- Fehler in einem Arbeitsschritt (ab 0.30.1): Scan sauber beenden statt jedes Bild erneut zu scheitern,
-- Meldung in PeonBrokerDB.lastScanError merken (auch ohne Debug)
function S.Fail(err)
    local st = S.state
    mod.acc.lastScanError = { t = time(), err = tostring(err), version = mod.version,
        phase = st and st.phase, index = st and st.index, total = st and st.total, sum = st and st.sumIndex }
    S.Abort(L.SCAN_FAILED)
end

function S.Abort(msg)
    local st = S.state
    if st and st.notify then ns.Notify("scan_abort", { market = st.market, t = st.readAt }) end
    S.state = nil
    if S.driver then S.driver:Hide() end
    if msg then mod:Print(msg) end
    S.UpdateButton()
end

---------------------------------------------------------------------------
-- Auswertung in Portionen
---------------------------------------------------------------------------
function S.OnReplicate()
    local st = S.state
    if not st or st.phase ~= "wait" then return end
    local ah = AH()
    local total = ah.GetNumReplicateItems() or 0
    st.phase, st.total, st.index = "read", total, 0
    st.collect, st.keys, st.names, st.quals, st.bands = {}, {}, {}, {}, {}
    st.groups, st.links = {}, {}   -- ab 0.28: Varianten nach Namen (itemID -> { keys, bonus }), Link je Variante
    st.listings, st.skipped = 0, 0
    st.readAt = time()
    if ns.HasListeners and ns.HasListeners() then   -- ab 0.30: Momentaufnahme fuer Peon_Client
        st.notify = true
        local m = ns.Data.Market(st.market, true)
        ns.Notify("scan_start", { market = st.market, t = st.readAt, total = total, variants = m and m.variants })
    end
    mod:Dbg(("Scan-Daten da: %d Angebote"):format(total))
    S.RunDriver()
end

function S.RunDriver()
    if not S.driver then
        S.driver = CreateFrame("Frame")
        S.driver:SetScript("OnUpdate", function()
            local ok, err = mod:Call("Scan", S.Step)
            if not ok then S.Fail(err) end
        end)
    end
    S.driver:Show()
end

local function ReadChunk(st)
    local ah = AH()
    local info, getLink = ah.GetReplicateItemInfo, ah.GetReplicateItemLink
    local getLeft = ah.GetReplicateItemTimeLeft   -- Restzeit-Stufe je Angebot (ab 0.23, fuer den Absatz)
    local collect, keys, names, quals = st.collect, st.keys, st.names, st.quals
    local last = math.min(st.total, st.index + S.CHUNK) - 1
    for i = st.index, last do
        local name, _, count, quality, _, _, _, minBid, _, buyout, bidAmount, _, _, _, _, _, itemID = info(i)
        local link, band
        if type(itemID) == "number" and type(buyout) == "number" and buyout > 0
            and type(count) == "number" and count > 0 then
            local key = itemID
            if type(quality) == "number" and quality >= 2 and getLink then
                link = getLink(i)
                local k = ns.Data.KeyFromLink(link)
                if type(k) == "string" and not ns.Data.IsVariantKey(k) then
                    key = k                                   -- alte Form: Zusatz im Link-Feld 7
                elseif type(name) == "string" and name ~= "" and not Peon.IsSecret(name) then
                    -- ab 0.28: vorlaeufig je vollem Namen sammeln; nach dem Lesen entscheidet S.Group, ob es Varianten sind
                    key = ns.Data.VariantKey(itemID, name)
                    local g = st.groups[itemID]
                    if not g then g = { keys = {} }; st.groups[itemID] = g end
                    if not collect[key] then g.keys[#g.keys + 1] = key end
                    if ns.Data.LinkHasBonus(link) then g.bonus = true end
                end
            end
            local c = collect[key]
            if not c then
                c = {}; collect[key] = c; keys[#keys + 1] = key
                names[key], quals[key] = name, quality   -- Name fuer die Suche im Broker-Fenster
                if link and not Peon.IsSecret(link) then st.links[key] = link end
            end
            c[#c + 1] = buyout / count
            c[#c + 1] = count
            band = -1
            if getLeft then
                local okb, b = pcall(getLeft, i)
                if okb and type(b) == "number" and not Peon.IsSecret(b) then band = b end
            end
            local bl = st.bands[key]
            if not bl then bl = {}; st.bands[key] = bl end
            bl[#bl + 1] = band
            st.listings = st.listings + 1
        else
            st.skipped = st.skipped + 1   -- nur Gebot, Daten fehlen
        end
        if st.notify and type(itemID) == "number" and type(count) == "number" and count > 0 then
            if band == nil then
                band = -1
                if getLeft then
                    local okb, b = pcall(getLeft, i)
                    if okb and type(b) == "number" and not Peon.IsSecret(b) then band = b end
                end
            end
            local l = link
            if l == nil and type(quality) == "number" and quality >= 2 and getLink then l = getLink(i) end
            if l ~= nil and Peon.IsSecret(l) then l = nil end
            ns.Notify("scan_row", itemID, name, count, quality, buyout, minBid, bidAmount, band, l)
        end
    end
    st.index = last + 1
    if st.index >= st.total then
        S.Group(st)
        st.phase, st.sumIndex = "sum", 0
        st.now = time()
        st.market = st.market or ns.MarketKey()
    end
end

-- Ab 0.28: Varianten entscheiden. Ein Gegenstand hat Varianten, wenn er schon bekannt ist, mehrere Namen im Scan hat,
-- sein Link Bonus-Nummern traegt oder der Name vom Grundnamen abweicht. Sonst kommt alles unter die itemID.
-- Neu erkannte Varianten: alter, gemischter Eintrag und gemerkter Suchschluessel werden geloescht.
function S.Group(st)
    local D = ns.Data
    local market = D.Market(st.market, true)
    if type(market.variants) ~= "table" then market.variants = {} end
    local rename = {}
    st.newVariants = 0
    for id, g in pairs(st.groups or {}) do
        local variant = market.variants[id] == true or #g.keys >= 2 or g.bonus
        if not variant then
            local base = ns.GetItemInfo(id)
            if type(base) == "string" and not Peon.IsSecret(base) then
                variant = base ~= st.names[g.keys[1]]
            else
                local ci = rawget(_G, "C_Item")   -- Grundname noch nicht geladen: anfordern, naechster Scan entscheidet
                if ci and ci.RequestLoadItemDataByID then pcall(ci.RequestLoadItemDataByID, id) end
            end
        end
        if variant then
            if not market.variants[id] then
                market.variants[id] = true
                market.items[id] = nil                                   -- gemischte Daten aller Varianten
                if type(mod.acc.itemKeys) == "table" then mod.acc.itemKeys[id] = nil end
                st.newVariants = st.newVariants + 1
            end
        else
            for _, k in ipairs(g.keys) do rename[k] = id end
        end
    end
    if next(rename) == nil then return end
    local keys, seen = {}, {}
    for _, k in ipairs(st.keys) do
        local final = rename[k] or k
        if final ~= k then
            local c = st.collect[final]
            if not c then
                st.collect[final], st.bands[final] = st.collect[k], st.bands[k]
                st.names[final], st.quals[final] = st.names[k], st.quals[k]
            else
                for _, v in ipairs(st.collect[k]) do c[#c + 1] = v end
                local b = st.bands[final]
                for _, v in ipairs(st.bands[k] or {}) do b[#b + 1] = v end
            end
            st.collect[k], st.bands[k], st.names[k], st.quals[k], st.links[k] = nil, nil, nil, nil, nil
        end
        if not seen[final] then seen[final] = true; keys[#keys + 1] = final end
    end
    st.keys = keys
end

local function SumChunk(st)
    local D = ns.Data
    local market = D.Market(st.market, true)
    local keys, collect = st.keys, st.collect
    local last = math.min(#keys, st.sumIndex + S.SUM_CHUNK)
    for i = st.sumIndex + 1, last do
        local key = keys[i]
        local min, median, qty, n = D.Summarize(collect[key])
        if min then
            local e = D.Record(market, key, min, median, qty, n, st.now, st.names[key], st.quals[key])
            e.lv = D.Levels(collect[key])   -- guenstigste Preisstufen fuer Schnaeppchen (ab 0.13)
            if st.links[key] and D.IsVariantKey(key) then e.lk = st.links[key] end   -- Link je Variante (ab 0.28)
            -- Absatz (ab 0.23): Angebote mit Restzeit-Stufe, mit dem vorigen Scan vergleichen
            if ns.Sales then
                local list, bands, flat = collect[key], st.bands[key] or {}, {}
                for j = 1, #list - 1, 2 do
                    flat[#flat + 1] = list[j]; flat[#flat + 1] = list[j + 1]; flat[#flat + 1] = bands[(j + 1) / 2] or -1
                end
                ns.Sales.OnScan(e, key, flat, st.now)
            end
        end
        collect[key], st.names[key], st.quals[key], st.bands[key], st.links[key] = nil, nil, nil, nil, nil
    end
    st.sumIndex = last
    if st.sumIndex >= #keys then
        local gone = D.MarkGone(market, market.lastScan, st.now)
        market.prevScan = market.lastScan
        market.lastScan = st.now
        market.scans = (tonumber(market.scans) or 0) + 1
        market.lastListings = st.listings
        market.lastItems = #keys
        -- Verdichten nur einmal am Tag (kostet bei vielen Gegenstaenden etwas Zeit)
        local dropped = 0
        local today = D.Day(st.now)
        if market.compactDay ~= today or market.compactDays ~= mod.db.dataDays then
            dropped = D.Compact(market, mod.db.dataDays or 30, today)
            market.compactDay, market.compactDays = today, mod.db.dataDays
        end
        D.vIndex = nil   -- Varianten-Verzeichnis neu aufbauen (ab 0.28)
        local secs = math.floor(GetTime() - st.t0 + 0.5)
        S.state = nil
        if S.driver then S.driver:Hide() end
        if st.notify then
            ns.Notify("scan_end", { market = st.market, t = st.readAt, listings = st.listings, skipped = st.skipped, items = #keys })
        end
        mod:Print(L.SCAN_DONE:format(st.listings, #keys, secs, st.market))
        mod:Dbg(("Scan fertig: %d Angebote, %d ohne Sofortkauf, %d Gegenstaende, %d nicht mehr da, %d alte entfernt, %d neue mit Varianten")
            :format(st.listings, st.skipped, #keys, gone, dropped, st.newVariants or 0))
        mod:Fire("SCAN_DONE", st.market)
        if mod.page and mod.page.panel:IsShown() then mod.page:Refresh() end
    end
end

-- Ein Arbeitsschritt je Bild (auch fuer Tests direkt aufrufbar)
function S.Step()
    local st = S.state
    if not st or st.phase == "wait" then
        if S.driver then S.driver:Hide() end
        return
    end
    if st.phase == "read" then ReadChunk(st) else SumChunk(st) end
    S.UpdateButton()
end

---------------------------------------------------------------------------
-- Knopf unter dem Auktionshausfenster
---------------------------------------------------------------------------
function S.StatusText()
    local st = S.state
    if st then
        if st.phase == "wait" then return L.SCAN_STATUS_WAIT end
        if st.phase == "read" then
            return L.SCAN_STATUS_READ:format(st.total > 0 and math.floor(st.index * 100 / st.total) or 0)
        end
        return L.SCAN_STATUS_SUM:format(#st.keys > 0 and math.floor(st.sumIndex * 100 / #st.keys) or 0)
    end
    local rem = S.Remaining()
    if rem > 0 then return L.SCAN_STATUS_COOLDOWN:format(S.FormatTime(rem)) end
    local market = ns.Data.Market()
    if market and market.lastScan then return L.SCAN_STATUS_LAST:format(S.Age(market.lastScan)) end
    return L.SCAN_STATUS_NEVER
end

function S.UpdateButton()
    local b = S.button
    if not b then return end
    b.status:SetText(S.StatusText())
    if S.state or S.Remaining() > 0 then b:Disable() else b:Enable() end
end

function S.CreateButton()
    if S.button then return end
    local parent = rawget(_G, "AuctionHouseFrame")
    if not parent then return end
    local b = CreateFrame("Button", "PeonBrokerScanButton", parent, "UIPanelButtonTemplate")
    b:SetSize(130, 22)
    b:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", -2, -2)
    b:SetText(L.SCAN_BUTTON)
    local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("RIGHT", b, "LEFT", -8, 0)
    fs:SetJustifyH("RIGHT")
    b.status = fs
    b:SetScript("OnClick", function() mod:Call("Scan", S.Start) end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(("|c%sPeon|r Broker"):format(Peon.COLOR))
        GameTooltip:AddLine(L.SCAN_BUTTON_HINT, 1, 1, 1, true)
        GameTooltip:AddLine(L.MM_MARKET:format(ns.MarketKey()), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    local elapsed = 0
    b:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + (dt or 0)
        if elapsed >= 1 then elapsed = 0; S.UpdateButton() end
    end)
    S.button = b
    S.UpdateButton()
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
function S.Init()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function()
        S.ahOpen = true
        S.CreateButton()
        S.UpdateButton()
        mod:Call("Taschen", ns.Data.CheckBags)
    end)
    -- neue Gegenstaende in den Taschen, waehrend das Auktionshaus offen ist
    mod:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if S.ahOpen then mod:Call("Taschen", ns.Data.CheckBags) end
    end)
    mod:RegisterEvent("AUCTION_HOUSE_CLOSED", function()
        S.ahOpen = false
        local st = S.state
        if st and (st.phase == "wait" or st.phase == "read") then S.Abort(L.SCAN_ABORT_CLOSED) end
    end)
    mod:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE", S.OnReplicate)
end
