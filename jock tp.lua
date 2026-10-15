-- language: Lua, file: airstuck_inf.lua, target: Heaven Hook (L4D2)
-- Port del airstuck con math.huge en 5 campos del UserCmd.
-- PELIGROSO: puede crashear el server o tu cliente. Usalo bajo tu responsabilidad.
-- Keybind: K (mantener apretado). Sin keybind si querés que corra siempre, cambiá FORCE_HOLD = false.

local KEY = keys.KEY_C
local FORCE_HOLD = true   -- true = solo mientras apretás K; false = siempre activo

local math_huge = 1 / 0   -- math.huge (inf)

local prev_down = false
local active    = false

local function log(s) pcall(client.print, "[airstuck] " .. tostring(s)) end

function on_create_move(cmd, local_player)
    if not cmd then return end

    if FORCE_HOLD then
        local down = false
        pcall(function() down = input.is_key_down(KEY) end)
        if down and not prev_down then
            active = true
            log("ON")
        elseif not down and prev_down then
            active = false
            log("OFF")
        end
        prev_down = down
        if not active then return end
    end

    -- escribir inf en los 5 campos del cmd
    pcall(function() cmd:set_sidemove(math_huge)    end)
    pcall(function() cmd:set_upmove(math_huge)      end)
    pcall(function() cmd:set_forwardmove(math_huge) end)

    pcall(function()
        cmd:set_viewangles(vector.new(math_huge, math_huge, math_huge))
    end)
end

function on_unload()
    active = false
    log("unloaded")
end

log("cargado — mantener K para activar")
