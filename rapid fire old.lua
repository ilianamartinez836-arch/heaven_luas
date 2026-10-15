ffi.cdef[[
    void* GetModuleHandleA(const char* lpModuleName);
    int VirtualProtect(void* lpAddress, size_t dwSize, uint32_t flNewProtect, uint32_t* lpflOldProtect);
]]

local PAGE_EXECUTE_READWRITE = 0x40
local CS_OFFSET = 4352236
local CS_NETCHAN = 24
local CS_CHOKED = 19024
local NC_CHOKED = 28

local client_state = nil
local net_channel = nil
local kernel32 = ffi.load("kernel32")

local function to_num(v)
    if v == nil then return 0 end
    if type(v) == "number" then return v end
    local n = tonumber(v)
    if n then return n end
    local ok, n2 = pcall(function() return tonumber(ffi.cast("uintptr_t", v)) end)
    if ok and n2 then return n2 end
    return 0
end

local function BytePatch(address, byte, length)
    local addr = to_num(address)
    if addr == 0 then
        client.print("[CHOKED] Invalid patch address")
        return
    end
    local oldProtect = ffi.new("uint32_t[1]")
    local address_ptr = ffi.cast("void*", addr)
    if kernel32.VirtualProtect(address_ptr, length, PAGE_EXECUTE_READWRITE, oldProtect) == 0 then
        client.print("[CHOKED] VirtualProtect failed")
        return
    end
    local byte_ptr = ffi.cast("uint8_t*", address_ptr)
    for i = 0, length - 1 do
        byte_ptr[i] = byte
    end
    kernel32.VirtualProtect(address_ptr, length, oldProtect[0], oldProtect)
    client.print(string.format("[CHOKED] Byte patch at 0x%X", addr))
end

local function get_engine_base()
    if modules and modules.get_engine_base then
        local b = to_num(modules.get_engine_base())
        if b ~= 0 then return b end
    end
    local ok, h = pcall(function() return ffi.C.GetModuleHandleA("engine.dll") end)
    if ok and h ~= nil then
        return to_num(ffi.cast("uintptr_t", h))
    end
    return 0
end

local function InitializeAddresses()
    local eng = get_engine_base()
    if eng == 0 then
        client.print("[CHOKED] engine.dll not found")
        return false
    end
    local ok, cs = pcall(function()
        return ffi.cast("uintptr_t*", eng + CS_OFFSET)[0]
    end)
    if not ok or not cs or to_num(cs) == 0 then
        client.print("[CHOKED] client_state invalid")
        return false
    end
    client_state = to_num(cs)
    local ok2, nc = pcall(function()
        return ffi.cast("uintptr_t*", client_state + CS_NETCHAN)[0]
    end)
    if not ok2 or not nc or to_num(nc) == 0 then
        client.print("[CHOKED] net_channel invalid")
        return false
    end
    net_channel = to_num(nc)
    client.print(string.format("[CHOKED] client_state=0x%X netchan=0x%X", client_state, net_channel))
    return true
end

function on_create_move(cmd, local_player)
    if not cmd then return end
    if client_state == nil or net_channel == nil then
        if not InitializeAddresses() then return end
    end
    if input.is_key_down(keys.KEY_F) then
        pcall(function()
            ffi.cast("int*", client_state + CS_CHOKED)[0] = 8000
        end)
    end
    if input.is_key_down(keys.KEY_X) then
        pcall(function()
            ffi.cast("int*", net_channel + NC_CHOKED)[0] = 700
        end)
    end
end

client.print("[CHOKED] loaded — hold F=chokedcmds 8000 | hold X=choked packets 700")
