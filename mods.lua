ffi.cdef[[
    void* GetModuleHandleA(const char* lpModuleName);
    int   VirtualProtect(void* lpAddress, size_t dwSize, uint32_t flNewProtect, uint32_t* lpflOldProtect);
]]

local PAGE_EXECUTE_READWRITE = 0x40
local PATCH_OFFSET = 0x5596C

local function to_num(v)
    if v == nil then return 0 end
    if type(v) == "number" then return v end
    local n = tonumber(v)
    if n then return n end
    local ok, n2 = pcall(function()
        return tonumber(ffi.cast("uintptr_t", v))
    end)
    if ok and n2 then return n2 end
    return 0
end

local engine_base = 0
if modules and modules.get_engine_base then
    engine_base = to_num(modules.get_engine_base())
end
if engine_base == 0 then
    local ok, h = pcall(function()
        return ffi.C.GetModuleHandleA("engine.dll")
    end)
    if ok and h ~= nil then
        engine_base = to_num(ffi.cast("uintptr_t", h))
    end
end

if engine_base == 0 then
    client.print("[VANILLA] engine.dll no encontrado")
    return
end

client.print(string.format("[VANILLA] engine base: 0x%X", engine_base))

local patch_addr = ffi.cast("uint8_t*", engine_base + PATCH_OFFSET)
local b0 = tonumber(patch_addr[0]) or 0
local b1 = tonumber(patch_addr[1]) or 0
local b2 = tonumber(patch_addr[2]) or 0
local b3 = tonumber(patch_addr[3]) or 0
client.print(string.format("[VANILLA] bytes: %02X %02X %02X %02X", b0, b1, b2, b3))

if b0 ~= 0x0F or b1 ~= 0xB6 or b2 ~= 0x4F or b3 ~= 0x5D then
    client.print("[VANILLA] firma distinta (esperado 0F B6 4F 5D)")
    return
end

client.print("[VANILLA] firma OK")

local orig_bytes = ffi.new("uint8_t[4]")
for i = 0, 3 do orig_bytes[i] = patch_addr[i] end

local old = ffi.new("uint32_t[1]")
if ffi.C.VirtualProtect(patch_addr, 4, PAGE_EXECUTE_READWRITE, old) == 0 then
    client.print("[VANILLA] VirtualProtect fallo")
    return
end

patch_addr[0] = 0x31
patch_addr[1] = 0xC9
patch_addr[2] = 0x90
patch_addr[3] = 0x90

ffi.C.VirtualProtect(patch_addr, 4, old[0], old)

client.print("[VANILLA] patch aplicado")
_G.vanilla_GC = { addr = patch_addr, orig = orig_bytes }

function on_unload()
    local g = _G.vanilla_GC
    if not g then return end
    local o2 = ffi.new("uint32_t[1]")
    pcall(function()
        ffi.C.VirtualProtect(g.addr, 4, PAGE_EXECUTE_READWRITE, o2)
        for i = 0, 3 do g.addr[i] = g.orig[i] end
        ffi.C.VirtualProtect(g.addr, 4, o2[0], o2)
    end)
    _G.vanilla_GC = nil
    client.print("[VANILLA] unload — restaurado")
end
