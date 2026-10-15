-- language: Lua, file: fase13_vtable.lua, target: Heaven Hook (L4D2)
-- ============================================================
-- FASE 13. Analisis de vtables via ffi.
-- ============================================================

if _G.__F13 then return end
_G.__F13 = true

local OUT = "C:\\Heaven-L4D2\\fase13.txt"
local lines = {}
local function L(s) lines[#lines+1] = tostring(s) end
local function write_now()
    pcall(function()
        local f = io.open(OUT, "w")
        if f then f:write(table.concat(lines, "\n")); f:close() end
    end)
end

L("=== FASE 13 VTABLE ===")
L("Fecha: " .. (os.date and os.date("%Y-%m-%d %H:%M:%S") or "?"))

local ffi = _G.ffi
if not ffi then L("no ffi"); write_now(); return end

local function num(v, default)
    if v == nil then return default or 0 end
    local ok, n = pcall(tonumber, v)
    if ok and n then return n end
    local ok2, n2 = pcall(function() return tonumber(ffi.cast("uintptr_t", v)) end)
    if ok2 and n2 then return n2 end
    return default or 0
end

-- ============================================================
-- cdef
-- ============================================================
pcall(function()
    ffi.cdef[[
        int VirtualProtect(void* lpAddress, size_t dwSize, uint32_t flNewProtect, uint32_t* lpflOldProtect);
    ]]
end)

-- ============================================================
-- 1. obtener direcciones base
-- ============================================================
L("")
L("--- 1. direcciones base ---")

local client_base = num(modules.get_client_base(), 0)
local engine_base = num(modules.get_engine_base(), 0)
L(string.format("client_base = 0x%X", client_base))
L(string.format("engine_base = 0x%X", engine_base))

-- ============================================================
-- 2. obtener ptr de la entidad 1
-- ============================================================
L("")
L("--- 2. ptr de la entidad 1 ---")

local e1_raw = entity.get_by_index_raw(1)
local e1_ptr = num(e1_raw, 0)
L(string.format("entity.get_by_index_raw(1) = 0x%X", e1_ptr))

-- ============================================================
-- 3. leer el primer campo de la entidad (vtable ptr)
-- ============================================================
L("")
L("--- 3. vtable ptr de la entidad 1 ---")

local vtable_ptr = 0
if e1_ptr ~= 0 then
    local ok, v = pcall(memory.read_int, e1_ptr)
    if ok then
        vtable_ptr = v or 0
    end
end
L(string.format("vtable ptr = 0x%X", vtable_ptr))

-- ============================================================
-- 4. leer los primeros 30 slots de la vtable
-- ============================================================
L("")
L("--- 4. primeros 30 slots de la vtable ---")

if vtable_ptr ~= 0 then
    for i = 0, 30 do
        local slot_addr = vtable_ptr + i * 4
        local slot_val = 0
        local ok, v = pcall(memory.read_int, slot_addr)
        if ok then slot_val = v or 0 end

        -- identificar en que modulo cae
        local module = "?"
        if slot_val >= client_base and slot_val < client_base + 0x1000000 then
            module = "client.dll+" .. string.format("0x%X", slot_val - client_base)
        elseif slot_val >= engine_base and slot_val < engine_base + 0x1000000 then
            module = "engine.dll+" .. string.format("0x%X", slot_val - engine_base)
        end

        L(string.format("  slot[%2d] @ 0x%X = 0x%X  (%s)", i, slot_addr, slot_val, module))
    end
end

-- ============================================================
-- 5. comparar con el ptr de la entidad 2
-- ============================================================
L("")
L("--- 5. comparar vtables de entidad 1 y 2 ---")

local e2_raw = entity.get_by_index_raw(2)
local e2_ptr = num(e2_raw, 0)
local vtable2 = 0
if e2_ptr ~= 0 then
    local ok, v = pcall(memory.read_int, e2_ptr)
    if ok then vtable2 = v or 0 end
end
L(string.format("entidad 2 vtable = 0x%X", vtable2))
if vtable_ptr == vtable2 then
    L("  ✓ MISMA VTABLE (son del mismo tipo)")
else
    L("  ✗ VTABLES DISTINTAS (distintos tipos)")
end

-- ============================================================
-- 6. comportamiento del cast de ffi sobre userdata
-- ============================================================
L("")
L("--- 6. comportamiento de ffi.cast sobre userdata de Lua ---")

local lp = client.get_local_player()
if lp then
    -- intentar cast de userdata a void*
    local ok1, p1 = pcall(function()
        return ffi.cast("void*", lp)
    end)
    L(string.format("  ffi.cast('void*', lp) -> ok=%s p=%s", tostring(ok1), tostring(p1)))
    if ok1 and p1 then
        L(string.format("    ptr = 0x%X", num(p1, 0)))
    end

    -- intentar cast de userdata a void***
    local ok2, p2 = pcall(function()
        return ffi.cast("void***", lp)
    end)
    L(string.format("  ffi.cast('void***', lp) -> ok=%s p=%s", tostring(ok2), tostring(p2)))
    if ok2 and p2 then
        L(string.format("    ptr = 0x%X", num(p2, 0)))
        -- intentar leer vtable
        local ok3, vt = pcall(function()
            return p2[0]
        end)
        if ok3 and vt then
            L(string.format("    vtable = 0x%X", num(vt, 0)))
        end
    end
end

-- ============================================================
-- 7. probar call de un slot (con cuidado)
-- ============================================================
L("")
L("--- 7. call a un slot de la vtable ---")
L("  (probamos leer los bytes del slot 0 para ver si es un prologue valido)")

if vtable_ptr ~= 0 then
    local slot0 = 0
    pcall(function() slot0 = memory.read_int(vtable_ptr) end)
    if slot0 ~= 0 then
        L(string.format("  slot[0] = 0x%X", slot0))
        -- leer los primeros bytes
        local bytes = {}
        for i = 0, 15 do
            local ok, b = pcall(memory.read_byte, slot0 + i)
            bytes[#bytes+1] = string.format("%02X", (ok and b) or 0)
        end
        L("  bytes: " .. table.concat(bytes, " "))
    end
end

-- ============================================================
-- 8. intentar escribir a la vtable (con restore)
-- ============================================================
L("")
L("--- 8. intentar ESCRITURA en la vtable con VirtualProtect ---")

if vtable_ptr ~= 0 then
    -- leer slot 30 (alguno que no se use)
    local slot30_addr = vtable_ptr + 30 * 4
    local orig_slot30 = 0
    pcall(function() orig_slot30 = memory.read_int(slot30_addr) end)
    L(string.format("  slot[30] original = 0x%X", orig_slot30))

    -- probar VirtualProtect en un rango pequeño
    local old_prot = ffi.new("uint32_t[1]")
    local PAGE_READWRITE = 0x04
    local PAGE_EXECUTE_READWRITE = 0x40

    local ok_vp, ret_vp = pcall(function()
        return ffi.C.VirtualProtect(ffi.cast("void*", slot30_addr), 4, PAGE_EXECUTE_READWRITE, old_prot)
    end)
    L(string.format("  VirtualProtect -> ok=%s ret=%s", tostring(ok_vp), tostring(ret_vp)))

    if ok_vp and ret_vp == 1 then
        -- escribir un valor cualquiera (no un hook real, solo test)
        -- NO escribimos basura porque podria crashear. Solo verificamos que VirtualProtect funciona.
        L("  ✓ VirtualProtect funciona (no escribimos para no crashear)")

        -- restaurar proteccion
        pcall(function()
            ffi.C.VirtualProtect(ffi.cast("void*", slot30_addr), 4, old_prot[0], old_prot)
        end)
    end
end

-- ============================================================
-- FIN
-- ============================================================
L("")
L("=== FIN ===")

-- limpiar
write_now()
pcall(client.print, "[fase13] listo")
