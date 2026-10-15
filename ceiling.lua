-- language: Lua, file: hunter_aceil.lua, target: Heaven Hook (L4D2)
-- Port de aimware. Auto-clicker para Hunter con 3 modos:
--   F -> pitch max 8.0   (hitbox breaker bajo)
--   Q -> pitch max 12.0  (hitbox breaker medio)
--   G -> pitch fixed 41.75 (AUTO-CEILING)
-- Solo activo si sos Hunter (team 3, zombie class 3).

local KEY_F = keys.KEY_F
local KEY_G = keys.KEY_G
local KEY_Q = keys.KEY_Q

local MAX_PITCH_F      = 8.0
local MAX_PITCH_Q      = 12.0
local FIXED_PITCH_G    = 41.75

local IN_ATTACK        = 1

-- estado
local next_attack_time = 0.0

local function log(s) pcall(client.print, "[hunter_ac] " .. tostring(s)) end

-- normaliza pitch (evita valores fuera de rango)
local function clamp_pitch(p)
    if p > 89.0  then return 89.0  end
    if p < -89.0 then return -89.0 end
    return p
end

function on_create_move(cmd, local_player)
    if not cmd or not local_player then return end

    -- chequeos: vivo, hunter
    local alive = false
    pcall(function() alive = local_player:is_alive() end)
    if not alive then return end

    local team = 0
    pcall(function() team = local_player:get_team() end)
    if team ~= 3 then return end

    local zc = 0
    pcall(function() zc = local_player:get_zombie_class() end)
    if zc ~= 3 then return end   -- 3 = Hunter

    -- detectar que tecla esta apretada
    local f_down, q_down, g_down = false, false, false
    pcall(function() f_down = input.is_key_down(KEY_F) end)
    pcall(function() q_down = input.is_key_down(KEY_Q) end)
    pcall(function() g_down = input.is_key_down(KEY_G) end)

    local active = f_down or q_down or g_down

    -- ajustar pitch segun modo
    if active then
        local va
        pcall(function() va = cmd:get_viewangles() end)
        if va and va.x then
            local new_pitch = va.x

            if f_down then
                if va.x > MAX_PITCH_F then new_pitch = MAX_PITCH_F end
            elseif q_down then
                if va.x > MAX_PITCH_Q then new_pitch = MAX_PITCH_Q end
            elseif g_down then
                new_pitch = FIXED_PITCH_G
            end

            if new_pitch ~= va.x then
                local new_ang = vector.new(clamp_pitch(new_pitch), va.y, va.z or 0)
                pcall(function() cmd:set_viewangles(new_ang) end)
            end
        end
    end

    -- auto-clicker con delay aleatorio
    if active then
        local now = os.clock()
        local buttons = 0
        pcall(function() buttons = cmd:get_buttons() end)

        if now >= next_attack_time then
            buttons = buttons | IN_ATTACK
            pcall(function() cmd:set_buttons(buttons) end)
            local delay = math.random(40, 60) / 1000.0
            next_attack_time = now + delay
        else
            buttons = buttons & ~IN_ATTACK
            pcall(function() cmd:set_buttons(buttons) end)
        end
    end
end

log("cargado — F: hitbox bajo | Q: hitbox medio | G: auto-ceiling")
