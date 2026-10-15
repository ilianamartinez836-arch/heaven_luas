cvar_vars.set_int("vars_movement_mode", 3)

local k_left_last = false
local k_right_last = false

local modes = { 1, 3, 4, 0 }
local mode_names = { 
    [1] = "BHOP", 
    [3] = "BHOP+STRAFER", 
    [4] = "STORM",
    [0] = "LUA CUSTOM" 
}

local function get_mode_index(current)
    for i, v in ipairs(modes) do
        if v == current then return i end
    end
    return 1
end

local IN_JUMP = 2
local MOVETYPE_WALK = 2
local MOVETYPE_NOCLIP = 8
local MOVETYPE_LADDER = 9
local MOVETYPE_OBSERVER = 10

if client.get_shared_bool("bhop_initialized", nil) == nil then
    client.set_shared_bool("bhop_initialized", true)
    client.set_shared_bool("bhop_enabled", false)
    client.set_shared_bool("strafe_enabled", false)
end

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
    if (buttons & IN_JUMP) ~= 0 and not local_player:is_on_ground() then
        cmd:set_buttons(buttons & ~IN_JUMP)
    end
end

local function apply_strafe(cmd, local_player)
    local move_type = local_player:get_move_type()
    if move_type == MOVETYPE_NOCLIP or move_type == MOVETYPE_LADDER or move_type == MOVETYPE_OBSERVER then return end
    if local_player:is_on_ground() then return end

    local velocity = local_player:get_velocity()
    local speed = math.sqrt(velocity.x^2 + velocity.y^2)
    if speed < 2 then return end

    local max_speed = 250
    local air_accel = 300
    local wish_speed = 300
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

        cmd:set_forwardmove(math.cos(move_dir) * 450)
        cmd:set_sidemove(-math.sin(move_dir) * 450)
    end
end

function on_copy_command_movement_pre(cmd, local_player)
    if not cmd or not local_player or not local_player:is_alive() then return end
    if local_player:get_move_type() ~= MOVETYPE_WALK then return end

    local buttons = cmd:get_buttons()

    if client.get_shared_bool("bhop_enabled", false) then
        if (buttons & IN_JUMP) ~= 0 then
            apply_bhop(cmd, local_player)
        end
    end

    if client.get_shared_bool("strafe_enabled", false) then
        apply_strafe(cmd, local_player)
    end
end

function on_paint()
    local k_left_now = input.is_key_down(keys.LEFT)
    local k_right_now = input.is_key_down(keys.RIGHT)

    local current = cvar_vars.get_int("vars_movement_mode")
    local idx = get_mode_index(current)

    if k_left_now and not k_left_last then
        idx = idx - 1
        if idx < 1 then idx = #modes end
        local new_mode = modes[idx]
        cvar_vars.set_int("vars_movement_mode", new_mode)

        if new_mode == 0 then
            client.set_shared_bool("bhop_enabled", true)
            client.set_shared_bool("strafe_enabled", true)
        else
            client.set_shared_bool("bhop_enabled", false)
            client.set_shared_bool("strafe_enabled", false)
        end
    end

    if k_right_now and not k_right_last then
        idx = idx + 1
        if idx > #modes then idx = 1 end
        local new_mode = modes[idx]
        cvar_vars.set_int("vars_movement_mode", new_mode)

        if new_mode == 0 then
            client.set_shared_bool("bhop_enabled", true)
            client.set_shared_bool("strafe_enabled", true)
        else
            client.set_shared_bool("bhop_enabled", false)
            client.set_shared_bool("strafe_enabled", false)
        end
    end

    k_left_last = k_left_now
    k_right_last = k_right_now

    local display = mode_names[cvar_vars.get_int("vars_movement_mode")] or "UNKNOWN"
    draw.string(fonts.ESP, 140, 120, 0.90, 0.9, 1.00, 1.00, text_align.LEFT, "Movement: " .. display)
end
