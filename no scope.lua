-- language: Lua, file: noscope.lua, target: Heaven Hook (L4D2)
-- Port de aimware a Heaven.
-- Hookea ISurface::DrawSetColor (vtable slot 11) y el Paint del scope
-- (tabla en client.dll + 0x5A39E4) para:
--   1) recolorear el overlay del scope con un color custom
--   2) opcionalmente desactivarlo por completo (no dibuja nada)
-- Sin menu. Teclas:
--   K     -> toggle scope enabled (on/off)
--   J     -> toggle scope color enabled (recolor on/off)
-- Color fijo: rojo puro. Editable en SCOPE_COLOR.

ffi.cdef[[
    void* GetModuleHandleA(const char* lpModuleName);
    int   VirtualProtect(void* lpAddress, size_t dwSize, uint32_t flNewProtect, uint32_t* lpflOldProtect);
]]

-- offsets (mismos que el lua original de aimware)
local ISURFACE_OFFSET  = 0x88B8F4  -- client.dll -> puntero a ISurface
local PAINT_ENTRY_OFF  = 0x5A39E4  -- client.dll -> slot con puntero a Paint del scope

-- keybinds
local KEY_TOGGLE_ENABLE = keys.KEY_K
local KEY_TOGGLE_COLOR  = keys.KEY_J

-- color del scope (r, g, b en 0-255)
local SCOPE_COLOR = { 255, 0, 0 }

-- estado
local scope_enabled = true
local color_enabled = false
local prev_k = false
local prev_j = false

-- helpers
local function log(s) pcall(client.print, "[noscope] " .. tostring(s)) end

local function get_client_base()
    local b
    pcall(function() b = modules.get_client_base() end)
    if not b or b == 0 then return 0 end
    local n
    pcall(function() n = tonumber(ffi.cast("uintptr_t", b)) end)
    if not n then pcall(function() n = tonumber(b) end) end
    return n or 0
end

-- recoleccion de punteros
local base = get_client_base()
if base == 0 then log("client.dll no encontrada"); return end

local surf_holder = ffi.cast("void***", base + ISURFACE_OFFSET)
local pSurface = surf_holder[0]
if pSurface == nil then log("ISurface nil"); return end

local surf_vtbl = ffi.cast("void***", pSurface)[0]
if surf_vtbl == nil then log("surf_vtbl nil"); return end

local orig_setcolor_slot = surf_vtbl[11]
if orig_setcolor_slot == nil then log("slot 11 vacio"); return end

local scope_paint_entry = ffi.cast("void***", base + PAINT_ENTRY_OFF)
local orig_paint = scope_paint_entry[0]
if orig_paint == nil then log("Paint entry nil — offset 0x5A39E4 no sirve"); return end

log(string.format("ISurface=%s  slot11=%s  paint=%s",
    tostring(ffi.cast("uintptr_t", pSurface)),
    tostring(ffi.cast("uintptr_t", orig_setcolor_slot)),
    tostring(ffi.cast("uintptr_t", orig_paint))))

-- tipos
local SetColor_t = ffi.typeof("void*(__fastcall*)(void*, void*, int, int, int, int)")
local PaintFn_t  = ffi.typeof("void*(__fastcall*)(void*, void*)")

local orig_setcolor = ffi.cast(SetColor_t, orig_setcolor_slot)
local orig_paint_fn = ffi.cast(PaintFn_t, orig_paint)

-- flag: estamos dentro del Paint del scope?
local in_scope_paint = false

-- hook: DrawSetColor
local hk_setcolor = ffi.cast(SetColor_t, function(this, dummy, r, g, b, a)
    if in_scope_paint and color_enabled then
        return orig_setcolor(this, nil, SCOPE_COLOR[1], SCOPE_COLOR[2], SCOPE_COLOR[3], a)
    end
    return orig_setcolor(this, nil, r, g, b, a)
end)

-- hook: Paint del scope
local hk_paint = ffi.cast(PaintFn_t, function(this, dummy)
    if not scope_enabled then
        -- no llamamos al original: no dibuja el scope
        return nil
    end
    in_scope_paint = true
    local result = orig_paint_fn(this, nil)
    in_scope_paint = false
    return result
end)

-- instalar hooks (parcheando la vtable y la tabla de punteros)
local old1 = ffi.new("uint32_t[1]")
ffi.C.VirtualProtect(ffi.cast("void*", surf_vtbl + 11 * 4), 4, 0x40, old1)
surf_vtbl[11] = ffi.cast("void*", hk_setcolor)
ffi.C.VirtualProtect(ffi.cast("void*", surf_vtbl + 11 * 4), 4, old1[0], old1)

local old2 = ffi.new("uint32_t[1]")
ffi.C.VirtualProtect(ffi.cast("void*", scope_paint_entry), 4, 0x40, old2)
scope_paint_entry[0] = ffi.cast("void*", hk_paint)
ffi.C.VirtualProtect(ffi.cast("void*", scope_paint_entry), 4, old2[0], old2)

log("hooks instalados — K=on/off  J=color")

-- actualizar keys en cada tick
function on_create_move(cmd, local_player)
    local k_down = false
    pcall(function() k_down = input.is_key_down(KEY_TOGGLE_ENABLE) end)
    if k_down and not prev_k then
        scope_enabled = not scope_enabled
        log("scope " .. (scope_enabled and "ON" or "OFF"))
    end
    prev_k = k_down

    local j_down = false
    pcall(function() j_down = input.is_key_down(KEY_TOGGLE_COLOR) end)
    if j_down and not prev_j then
        color_enabled = not color_enabled
        log("color " .. (color_enabled and "ON" or "OFF"))
    end
    prev_j = j_down
end

-- restore en unload
function on_unload()
    local r1 = ffi.new("uint32_t[1]")
    pcall(function()
        ffi.C.VirtualProtect(ffi.cast("void*", surf_vtbl + 11 * 4), 4, 0x40, r1)
        surf_vtbl[11] = orig_setcolor_slot
        ffi.C.VirtualProtect(ffi.cast("void*", surf_vtbl + 11 * 4), 4, r1[0], r1)
    end)

    local r2 = ffi.new("uint32_t[1]")
    pcall(function()
        ffi.C.VirtualProtect(ffi.cast("void*", scope_paint_entry), 4, 0x40, r2)
        scope_paint_entry[0] = orig_paint
        ffi.C.VirtualProtect(ffi.cast("void*", scope_paint_entry), 4, r2[0], r2)
    end)

    log("hooks removidos")
end
