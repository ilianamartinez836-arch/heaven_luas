-- language: Lua, file: lowres.lua, target: Heaven Hook (L4D2)
-- Togglea mat_showlowresimage con la tecla K.
-- Modo debug del engine: renderiza el mundo en texturas de bajisima calidad.
-- Restaura el valor original en unload.

local KEY = keys.KEY_K

local cvar_ptr     = nil
local original_val = 0
local prev_down    = false
local enabled      = false

local function init()
    local ok, ptr = pcall(cvar.find, "mat_showlowresimage")
    if not ok or not ptr or ptr == 0 then
        client.print("[lowres] mat_showlowresimage no encontrada")
        return false
    end
    cvar_ptr = ptr
    local ok2, val = pcall(cvar.get_int, cvar_ptr)
    if ok2 and val then
        original_val = val
        enabled = (val ~= 0)
    end
    client.print("[lowres] original = " .. tostring(original_val) .. " | K para toggle")
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
        enabled = not enabled
        apply(enabled and 1 or 0)
        pcall(client.print, "[lowres] " .. (enabled and "ON" or "OFF"))
    end
    prev_down = down
end

function on_unload()
    if cvar_ptr and cvar_ptr ~= 0 then
        apply(original_val)
        pcall(client.print, "[lowres] restaurado a " .. tostring(original_val))
    end
end

init()
