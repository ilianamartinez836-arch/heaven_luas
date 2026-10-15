-- language: Lua, file: nsl.lua, target: Heaven Hook (L4D2)
-- Port de aimware: 3 bytepatches en engine.dll.
-- FIX: memory.pattern_scan devuelve un number, no cdata. No castear a uintptr_t.

ffi.cdef[[
    bool VirtualProtect(void* lpAddress, uint32_t dwSize, uint32_t flNewProtect, uint32_t* lpflOldProtect);
]]

local function log(s) pcall(client.print, "[nsl] " .. tostring(s)) end

local patches = {
    {
        name  = "case1",
        pat   = "83 BB 84 00 00 00 01 0F 84 D9 00 00 00",
        off   = 7,
        bytes = {0xE9, 0xDA, 0x00, 0x00, 0x00, 0x90},
        check = 0x0F,  -- byte esperado en la posicion target (antes de parchear)
    },
    {
        name  = "case6",
        pat   = "83 BB 84 00 00 00 01 74 5E 8B 16",
        off   = 7,
        bytes = {0xEB},
        check = 0x74,
    },
    {
        name  = "case7/8",
        pat   = "83 BB 84 00 00 00 01 74 3E 8B 0E",
        off   = 7,
        bytes = {0xEB},
        check = 0x74,
    },
}

local originals = {}

-- pattern scan: la api de heaven devuelve un number directo
local function pattern_scan(module, sig)
    local fn = memory and memory.pattern_scan
    if not fn then return nil end
    local ok, result = pcall(fn, module, sig)
    if not ok or not result then return nil end
    -- ya es number. si por alguna razon es cdata, convertir.
    if type(result) == "number" then
        if result == 0 then return nil end
        return result
    end
    local n
    pcall(function() n = tonumber(ffi.cast("uintptr_t", result)) end)
    if n and n ~= 0 then return n end
    pcall(function() n = tonumber(result) end)
    if n and n ~= 0 then return n end
    return nil
end

local function read_bytes(addr_num, count)
    local ptr = ffi.cast("uint8_t*", addr_num)
    local out = {}
    for i = 0, count - 1 do
        out[#out + 1] = ptr[i]
    end
    return out
end

local function write_bytes(addr_num, bytes)
    local old = ffi.new("uint32_t[1]")
    if ffi.C.VirtualProtect(ffi.cast("void*", addr_num), #bytes, 0x40, old) == 0 then
        return false
    end
    local ptr = ffi.cast("uint8_t*", addr_num)
    for i, b in ipairs(bytes) do
        ptr[i - 1] = b
    end
    ffi.C.VirtualProtect(ffi.cast("void*", addr_num), #bytes, old[0], old)
    return true
end

local patched_count = 0

for _, p in ipairs(patches) do
    local found = pattern_scan("engine.dll", p.pat)
    if not found then
        log(p.name .. ": pattern no encontrado")
    else
        local target_num = found + p.off
        local cur = read_bytes(target_num, #p.bytes)

        if cur[1] ~= p.check then
            log(string.format("%s: byte actual 0x%02X != 0x%02X — skip",
                p.name, cur[1], p.check))
        else
            originals[p.name] = { addr = target_num, bytes = cur }
            if write_bytes(target_num, p.bytes) then
                patched_count = patched_count + 1
                log(string.format("%s: parcheado en 0x%X", p.name, target_num))
            else
                log(p.name .. ": VirtualProtect fallo")
            end
        end
    end
end

log(string.format("parcheados %d/%d", patched_count, #patches))

function on_unload()
    local restored = 0
    for name, info in pairs(originals) do
        if write_bytes(info.addr, info.bytes) then
            restored = restored + 1
        end
    end
    log(string.format("restaurados %d/%d", restored, patched_count))
end

log("cargado")
