-- Peon - test_globals.lua
-- Prueft alle Addon-Dateien auf globale Variablen, die versehentlich entstehen (fehlendes "local").
-- Ohne Zusatzwerkzeug: Lua 5.1 uebersetzt jede Datei (loadfile), string.dump liefert den Bytecode, darin stehen
-- Schreibzugriffe auf globale Namen als Befehl SETGLOBAL. Erlaubt sind die SavedVariables aus der TOC, Namen mit
-- Peon am Anfang, SLASH_* und BINDING_* sowie die Liste ALLOWED unten.
-- Laeuft wie alle Tests im Ordner addons\ (run_tests.cmd / run_tests.sh). Ab 18.11.2026.

local function check(c, m) if not c then error("FEHLER: " .. m, 2) end print("ok  " .. m) end

-- Globale Namen, die ein Addon absichtlich setzt (Name -> Grund)
local ALLOWED = {
}

---------------------------------------------------------------------------
-- Bytecode von Lua 5.1 lesen (Format wie luac, nur was fuer SETGLOBAL noetig ist)
---------------------------------------------------------------------------
local Reader = {}
Reader.__index = Reader

local function NewReader(s)
    local r = setmetatable({ s = s, pos = 1 }, Reader)
    assert(s:sub(1, 4) == "\27Lua" and s:byte(5) == 0x51, "kein Bytecode von Lua 5.1")
    r.little = s:byte(7) == 1
    r.sizeInt, r.sizeSize, r.sizeInstr, r.sizeNum = s:byte(8), s:byte(9), s:byte(10), s:byte(11)
    r.pos = 13
    return r
end

function Reader:Byte()
    local b = self.s:byte(self.pos)
    self.pos = self.pos + 1
    return b
end

function Reader:Uint(n)
    local v, mul = 0, 1
    local bytes = { self.s:byte(self.pos, self.pos + n - 1) }
    self.pos = self.pos + n
    if not self.little then
        local rev = {}
        for i = #bytes, 1, -1 do rev[#rev + 1] = bytes[i] end
        bytes = rev
    end
    for i = 1, n do v = v + bytes[i] * mul; mul = mul * 256 end
    return v
end

function Reader:Int() return self:Uint(self.sizeInt) end

function Reader:String()
    local n = self:Uint(self.sizeSize)
    if n == 0 then return nil end
    local v = self.s:sub(self.pos, self.pos + n - 2)   -- ohne Nullzeichen am Ende
    self.pos = self.pos + n
    return v
end

local OP_SETGLOBAL = 7

-- Liest eine Funktion samt inneren Funktionen. found(name, zeile) fuer jeden Schreibzugriff auf einen globalen Namen.
function Reader:Function(found)
    self:String()                        -- Quelle
    self:Int(); self:Int()               -- Zeilen
    self.pos = self.pos + 4              -- nups, numparams, is_vararg, maxstacksize
    local code = {}
    for i = 1, self:Int() do code[i] = self:Uint(self.sizeInstr) end
    local consts = {}
    for i = 1, self:Int() do
        local t = self:Byte()
        if t == 1 then self:Byte()
        elseif t == 3 then self.pos = self.pos + self.sizeNum
        elseif t == 4 then consts[i - 1] = self:String() end
    end
    for _ = 1, self:Int() do self:Function(found) end
    local lines = {}
    for i = 1, self:Int() do lines[i] = self:Int() end
    for _ = 1, self:Int() do self:String(); self:Int(); self:Int() end
    for _ = 1, self:Int() do self:String() end
    for i, ins in ipairs(code) do
        if ins % 64 == OP_SETGLOBAL then
            local bx = math.floor(ins / 16384)
            found(consts[bx], lines[i])
        end
    end
end

local function GlobalWritesOf(fn)
    local out = {}
    NewReader(string.dump(fn)):Function(function(name, line) out[#out + 1] = { name = name, line = line } end)
    return out
end

local function GlobalWrites(path)
    local fn, err = loadfile(path)
    if not fn then error("FEHLER: " .. tostring(err)) end
    return GlobalWritesOf(fn)
end

---------------------------------------------------------------------------
-- Addons durchgehen (Dateien aus der TOC)
---------------------------------------------------------------------------
local function Lines(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local t = {}
    for l in f:lines() do t[#t + 1] = (l:gsub("\r$", "")) end
    f:close()
    return t
end

local function Addons()
    local list = {}
    local p = io.popen(package.config:sub(1, 1) == "\\" and "dir /b /ad" or "ls -1")
    for name in p:lines() do
        name = name:gsub("\r$", "")
        if name:match("^Peon") and Lines(name .. "/" .. name .. ".toc") then list[#list + 1] = name end
    end
    p:close()
    table.sort(list)
    return list
end

local function Allowed(name, saved)
    if saved[name] or ALLOWED[name] then return true end
    if name:match("^Peon") or name:match("^SLASH_") or name:match("^BINDING_") then return true end
    return false
end

local addons = Addons()
check(#addons >= 10, "Addons gefunden: " .. #addons)
local files, bad = 0, {}
for _, addon in ipairs(addons) do
    local saved = {}
    local lua = {}
    for _, l in ipairs(Lines(addon .. "/" .. addon .. ".toc")) do
        local sv = l:match("^##%s*SavedVariables[%w]*:%s*(.+)$")
        if sv then for n in sv:gmatch("[%w_]+") do saved[n] = true end end
        if not l:match("^#") and l:match("%.lua%s*$") then lua[#lua + 1] = (l:gsub("%s+$", ""):gsub("\\", "/")) end
    end
    for _, f in ipairs(lua) do
        local path = addon .. "/" .. f
        if Lines(path) then
            files = files + 1
            for _, w in ipairs(GlobalWrites(path)) do
                if not Allowed(w.name, saved) then bad[#bad + 1] = ("%s:%s  %s"):format(path, tostring(w.line), w.name) end
            end
        end
    end
end
check(files >= 100, "Dateien geprueft: " .. files)
if #bad > 0 then
    for _, b in ipairs(bad) do print("  globale Variable: " .. b) end
end
check(#bad == 0, "keine unerwarteten globalen Variablen (" .. #bad .. " gefunden, fehlt ein local?)")

-- Die Pruefung selbst: findet sie einen Fehler? (ohne Datei, os.tmpname zeigt unter Windows auf den Laufwerksstamm)
local sample = assert(loadstring("local a = 1\nfunction Helfer() end\nlocal function f()\n  zaehler = (zaehler or 0) + 1\nend\nPeonTestDB = {}\n", "beispiel"))
local w = GlobalWritesOf(sample)
local names = {}
for _, x in ipairs(w) do names[#names + 1] = x.name .. "@" .. tostring(x.line) end
table.sort(names)
check(table.concat(names, ",") == "Helfer@2,PeonTestDB@6,zaehler@4", "Pruefung findet globale Funktion und Variable in innerer Funktion: " .. table.concat(names, ","))

print("ALLE TESTS OK")
