local IN_JUMP = 2
local MOVETYPE_WALK = 2
local IN_DUCK = 4
local MOVETYPE_NOCLIP = 8
local MOVETYPE_LADDER = 9
local MOVETYPE_OBSERVER = 10

local function normalize_rad(angle)
    angle = angle % (2 * math.pi)
    if angle > math.pi then
        angle = angle - 2 * math.pi
    elseif angle < -math.pi then
        angle = angle + 2 * math.pi
    end
    return angle
end

local function angle_diff_rad(a1, a2)
    return normalize_rad(a1 - a2)
end

local function apply_bhop(cmd, local_player)
    local buttons = cmd:get_buttons()
    if (buttons & IN_JUMP) ~= 0 then
        buttons = buttons | IN_DUCK
        if not local_player:is_on_ground() then
            buttons = buttons & ~IN_JUMP
        end
        cmd:set_buttons(buttons)
    end
end

local function apply_strafe(cmd, local_player)
    local move_type = local_player:get_move_type()
    if move_type == MOVETYPE_NOCLIP or move_type == MOVETYPE_LADDER or move_type == MOVETYPE_OBSERVER then
        return
    end
    if local_player:is_on_ground() then return end

    local velocity = local_player:get_velocity()
    if not velocity then return end

    local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
    if speed < 2 then return end

    local max_speed = 250
    local air_accel = 300
    local wish_speed = 300
    local term = (wish_speed / air_accel) / max_speed * 100.0 / speed
    local perfect_delta = 0.0
    if term > -1.0 and term < 1.0 then
        perfect_delta = math.acos(term)
    end
    if perfect_delta == 0.0 then return end

    local view_angles = cmd:get_viewangles()
    local yaw_rad = math.rad(view_angles.y)
    local vel_dir = math.atan2(velocity.y, velocity.x) - yaw_rad
    local wish_ang = math.atan2(-cmd:get_sidemove(), cmd:get_forwardmove())
    local delta = angle_diff_rad(vel_dir, wish_ang)
    local move_dir = delta < 0.0 and (vel_dir + perfect_delta) or (vel_dir - perfect_delta)

    cmd:set_forwardmove(math.cos(move_dir) * 450)
    cmd:set_sidemove(-math.sin(move_dir) * 450)
end

function on_copy_command_movement_pre(cmd, local_player)
    if not cmd or not local_player then return end
    if not local_player:is_alive() then return end
    if local_player:get_move_type() ~= MOVETYPE_WALK then return end

    apply_bhop(cmd, local_player)
    apply_strafe(cmd, local_player)
end


