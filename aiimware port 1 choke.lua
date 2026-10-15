local ffi = rawget(_G, "ffi")
if not ffi then return end

local function p(msg)
    pcall(function() client.print(tostring(msg) .. "\n") end)
end

local function band(a, b)
    local res, bitval = 0, 1
    a, b = a or 0, b or 0
    for _ = 0, 31 do
        if (a % 2 == 1) and (b % 2 == 1) then res = res + bitval end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bitval = bitval * 2
        if a == 0 and b == 0 then break end
    end
    return res
end

local function r32(addr)
    local ok, v = pcall(memory.read_int, addr)
    if ok then return v end
    return nil
end

local function read_cstr(addr, n)
    n = n or 32
    if not addr or addr == 0 then return nil end
    local t = {}
    for i = 0, n - 1 do
        local w = r32(addr + i)
        if not w then break end
        local b = band(w, 0xFF)
        if b == 0 then break end
        if b < 32 or b > 126 then break end
        t[#t + 1] = string.char(b)
    end
    if #t == 0 then return nil end
    return table.concat(t)
end

p("[last] start")

local client_base = modules.get_client_base()
if not client_base or client_base == 0 then
    p("no client_base")
    return
end
p("client_base = " .. tostring(client_base))

-- buscar string "VClient016"
local str_addr = nil
local start = client_base + 0x1000
local finish = client_base + 0xA00000
for addr = start, finish, 4 do
    local s = read_cstr(addr, 12)
    if s == "VClient016" then
        str_addr = addr
        break
    end
end

if not str_addr then
    p("string VClient016 NOT found")
    p("[last] done")
    return
end
p("string @ " .. tostring(str_addr))

-- buscar puntero a ese string (InterfaceReg.m_pName)
local reg = nil
for addr = start, finish, 4 do
    local v = r32(addr)
    if v == str_addr then
        -- posible m_pName; createfn suele estar en addr-4, next en addr+4
        local createfn = r32(addr - 4)
        local nextptr = r32(addr + 4)
        p(string.format("xref @ %s createfn=%s next=%s", tostring(addr), tostring(createfn), tostring(nextptr)))
        if createfn and createfn > client_base and createfn < client_base + 0xA00000 then
            reg = { name_ptr = addr, createfn = createfn, nextptr = nextptr }
            break
        end
    end
end

if not reg then
    p("InterfaceReg not found")
    p("[last] done")
    return
end

p("calling createfn...")
local ok, ptr = pcall(function()
    local fn = ffi.cast("void*(__cdecl*)()", reg.createfn)
    return fn()
end)

local abs = 0
if ok and ptr then
    abs = tonumber(ffi.cast("uintptr_t", ptr)) or 0
end
p("createfn ok=" .. tostring(ok) .. " abs=" .. tostring(abs))

if abs ~= 0 then
    local okv, vt = pcall(function()
        return ffi.cast("uintptr_t**", ptr)[0]
    end)
    if okv and vt then
        for i = 20, 24 do
            local ok2, f = pcall(function()
                return tonumber(ffi.cast("uintptr_t", vt[i]))
            end)
            p(string.format("vtable[%d]=0x%X", i, (ok2 and f) or 0))
        end
    end
end

p("[last] done")
