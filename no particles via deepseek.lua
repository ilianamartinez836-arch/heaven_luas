-- language: Lua, file: particles_toggle.lua, target: Heaven Hook (L4D2)

local KEY = keys.KEY_K

local cvar_ptr     = nil
local original_val = 1
local prev_down    = false
local enabled      = nil

local function init()
    cvar_ptr = cvar.find("r_drawparticles")
    if not cvar_ptr or cvar_ptr == 0 then
        client.print("[particles] r_drawparticles no encontrada")
        return false
    end
    original_val = cvar.get_int(cvar_ptr)
    enabled      = (original_val ~= 0)
    client.print("[particles] original = " .. tostring(original_val) ..
                 " | K para toggle")
    return true
end

local function apply(v)
    if cvar_ptr and cvar_ptr ~= 0 then
        cvar.set_int(cvar_ptr, v)
    end
end

function on_create_move(cmd, local_player)
    if not cvar_ptr then return end

    local down = input.is_key_down(KEY)
    if down and not prev_down then
        enabled = not enabled
        apply(enabled and 1 or 0)
        client.print("[particles] " .. (enabled and "ON" or "OFF"))
    end
    prev_down = down
end

function on_unload()
    if cvar_ptr and cvar_ptr ~= 0 then
        cvar.set_int(cvar_ptr, original_val)
        client.print("[particles] restaurado a " .. tostring(original_val))
    end
end

if not init() then return end
