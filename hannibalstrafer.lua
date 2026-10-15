--i doubt this is like, the same shit
-- but is as close as it gets
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

function on_create_move(cmd, local_player)
    if not cmd or not local_player or not local_player:is_alive() then return end

    local move_type = local_player:get_move_type()
    if move_type == MOVETYPE_NOCLIP or move_type == MOVETYPE_LADDER or move_type == MOVETYPE_OBSERVER then return end

    if local_player:is_on_ground() then return end

    local velocity = local_player:get_velocity()
    local speed = math.sqrt(velocity.x^2 + velocity.y^2)

    if speed < 2.0 then return end

    local max_speed = 250.0
    local air_accel = 300.0
    local wish_speed = 300.0

    local term = (wish_speed / air_accel) / max_speed * 100.0 / speed

    local perfect_delta = 0.0
    if term > -1.0 and term < 1.0 then
        perfect_delta = math.acos(term)
    end

    if perfect_delta ~= 0.0 then
        local view_angles = cmd:get_viewangles()
        local yaw_rad = math.rad(view_angles.y)
        
        local vel_dir = math.atan2(velocity.y, velocity.x) - yaw_rad
        local wish_ang = math.atan2(-cmd:get_sidemove(), cmd:get_forwardmove())
        
        local delta = angle_diff_rad(vel_dir, wish_ang)
        local move_dir = delta < 0.0 and (vel_dir + perfect_delta) or (vel_dir - perfect_delta)

        cmd:set_forwardmove(math.cos(move_dir) * 450.0)
        cmd:set_sidemove(-math.sin(move_dir) * 450.0)
    end
end
