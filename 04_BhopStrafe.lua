-- language: Lua, file: rage_strafer.lua, target: Heaven Hook (L4D2)
-- Versión agresiva pero estable. Sin extra_commands, sin speed_bonus, sin overcorrect.
-- Primero confirmamos que esto no crashea, después subimos.

local IN_JUMP          = 2
local MOVETYPE_WALK    = 2
local MOVETYPE_NOCLIP  = 8
local MOVETYPE_LADDER  = 9
local MOVETYPE_OBSERVER = 10

local MAX_SPEED  = 250.0
local AIR_ACCEL  = 300.0
local WISH_SPEED = 300.0
local MAXMOVE    = 450.0

local function norm_rad(a)
    a = a % (2 * math.pi)
    if a >  math.pi then a = a - 2 * math.pi end
    if a < -math.pi then a = a + 2 * math.pi end
    return a
end
local function angle_diff_rad(a1, a2) return norm_rad(a1 - a2) end

local function apply_bhop(cmd, lp)
    local b = cmd:get_buttons()
    if (b & IN_JUMP) ~= 0 and not lp:is_on_ground() then
        cmd:set_buttons(b & ~IN_JUMP)
    end
end

local function apply_strafe(cmd, lp)
    local mt = lp:get_move_type()
    if mt == MOVETYPE_NOCLIP or mt == MOVETYPE_LADDER or mt == MOVETYPE_OBSERVER then return end
    if lp:is_on_ground() then return end

    local vel = lp:get_velocity()
    if not vel then return end
    local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y)
    if speed < 2.0 then return end

    local term = (WISH_SPEED / AIR_ACCEL) / MAX_SPEED * 100.0 / speed
    local perfect_delta = 0.0
    if term > -1.0 and term < 1.0 then
        perfect_delta = math.acos(term)
    else
        return   -- fuera de rango: no aplicamos strafe este tick
    end

    local va = cmd:get_viewangles()
    if not va then return end

    local yaw_rad = math.rad(va.y)
    local vel_dir  = math.atan2(vel.y, vel.x) - yaw_rad
    local wish_ang = math.atan2(-cmd:get_sidemove(), cmd:get_forwardmove())
    local delta    = angle_diff_rad(vel_dir, wish_ang)
    local move_dir = delta < 0.0 and (vel_dir + perfect_delta) or (vel_dir - perfect_delta)

    -- si move_dir no es finito, skip
    if move_dir ~= move_dir or move_dir == math.huge or move_dir == -math.huge then return end

    cmd:set_forwardmove(math.cos(move_dir) * MAXMOVE)
    cmd:set_sidemove(-math.sin(move_dir) * MAXMOVE)
end

function on_create_move(cmd, local_player)
    if not cmd or not local_player then return end
    if not local_player:is_alive() then return end
    if local_player:get_move_type() ~= MOVETYPE_WALK then return end

    local b = cmd:get_buttons()
    if (b & IN_JUMP) ~= 0 then
        apply_bhop(cmd, local_player)
        apply_strafe(cmd, local_player)
    end
end
