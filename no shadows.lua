-- language: Lua, file: no_shadows.lua, target: Heaven Hook (L4D2)
-- Port de aimware: apaga sombras dinamicas y flash de linterna.
-- Tecla K toggle. Sin menu. Restore al valor original en unload.

local KEY = keys.KEY_K

local cvar_ptr     = nil
local original_val = 1
local prev_down    = false
local disabled     = false

local function init()
    local ok, ptr = pcall(cvar.find, "r_shadows")
    if not ok or not ptr or ptr == 0 then
        client.print("[shadows] r_shadows no encontrada")
        return false
    end
    cvar_ptr = ptr
    local ok2, val = pcall(cvar.get_int, cvar_ptr)
    if ok2 and val then
        original_val = val
        disabled = (val == 0)
    end
    client.print("[shadows] original = " .. tostring(original_val) ..
                 " | K para toggle")
    return true
end

local function apply(v)
    if cvar_ptr and cvar_ptr ~= 0 then
        pcall(cvar.set_int, cvar_ptr, v)
    end
end

function on_create_move(cmd, local_player)
    if not cvar_ptr then return end

    local down = false
    pcall(function() down = input.is_key_down(KEY) end)

    if down and not prev_down then
        disabled = not disabled
        apply(disabled and 0 or 1)
        pcall(client.print, "[shadows] " .. (disabled and "OFF" or "ON"))
    end
    prev_down = down
end

function on_unload()
    if cvar_ptr and cvar_ptr ~= 0 then
        apply(original_val)
        pcall(client.print, "[shadows] restaurado a " .. tostring(original_val))
    end
end

init()
