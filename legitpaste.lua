client.print("Luv")

local IN_JUMP = 2
local IN_MOVELEFT = 512
local IN_MOVERIGHT = 1024

local MOVETYPE_WALK = 2

local bhop = {
    last_jump = false,
    should_fake = false,
}

if client.get_shared_bool("bhop_enabled", nil) == nil then
    client.set_shared_bool("bhop_enabled", false)
    client.set_shared_int("bhop_mode", 1)
    client.set_shared_int("strafe_mode", 0)
    client.set_shared_float("humanize_success_rate", 95.0)
end

local function normalize_yaw(yaw)
    yaw = yaw % 360
    if yaw > 180 then yaw = yaw - 360 end
    if yaw < -180 then yaw = yaw + 360 end
    return yaw
end

local function can_run_directional_strafe(local_player)
    return not local_player:is_on_ground()
end

local function apply_bhop(cmd, local_player, mode)
    local buttons = cmd:get_buttons()

    if mode == 1 then
        if not local_player:is_on_ground() and (buttons & IN_JUMP) ~= 0 then
            cmd:set_buttons(buttons & ~IN_JUMP)
        end

    elseif mode == 2 then
        if not bhop.last_jump and bhop.should_fake then
            bhop.should_fake = false
            cmd:set_buttons(buttons | IN_JUMP)
        elseif (buttons & IN_JUMP) ~= 0 then
            if local_player:is_on_ground() then
                bhop.last_jump = true
                bhop.should_fake = true
            else
                cmd:set_buttons(buttons & ~IN_JUMP)
                bhop.last_jump = false
            end
        else
            bhop.last_jump = false
            bhop.should_fake = false
        end

    elseif mode == 3 then
        if (buttons & IN_JUMP) ~= 0 and not local_player:is_on_ground() then
            cmd:set_buttons(buttons & ~IN_JUMP)
        end

    elseif mode == 4 then
        if not local_player:is_on_ground() and (buttons & IN_JUMP) ~= 0 then
            local success_rate = client.get_shared_float("humanize_success_rate", 95.0)
            if math.random(100) > success_rate then
                return
            end
            cmd:set_buttons(buttons & ~IN_JUMP)
        end
    end
end

local function apply_strafe(cmd, local_player, strafe_mode)
    if strafe_mode == 1 then
        if can_run_directional_strafe(local_player) then
            local dx = cmd:get_mousedx()
            cmd:set_sidemove(dx > 0 and 450 or -450)
        end
    elseif strafe_mode == 2 then
        if can_run_directional_strafe(local_player) then
            local dx = cmd:get_mousedx()
            cmd:set_sidemove(dx > 0 and -450 or 450)
        end
    elseif strafe_mode == 3 then
        if can_run_directional_strafe(local_player) then
            local dx = cmd:get_mousedx()
            cmd:set_forwardmove(dx > 0 and 450 or -450)
        end
    elseif strafe_mode == 4 then
        if can_run_directional_strafe(local_player) then
            local dx = cmd:get_mousedx()
            cmd:set_forwardmove(dx > 0 and -450 or 450)
        end
    elseif strafe_mode == 6 then
        if local_player:is_on_ground() then return end
        if cmd:get_forwardmove() ~= 0 or cmd:get_sidemove() ~= 0 or math.abs(cmd:get_mousedx()) > 2 then return end
        local vel = local_player:get_velocity()
        local speed2d = math.sqrt(vel.x^2 + vel.y^2)
        if speed2d < 10 then return end
        local yaw_vel = math.deg(math.atan2(vel.y, vel.x))
        local angles = cmd:get_viewangles()
        local diff = normalize_yaw(angles.y - yaw_vel)
        cmd:set_sidemove(diff > 0 and -450 or 450)
        angles.y = normalize_yaw(angles.y - diff)
        cmd:set_viewangles(angles)
    end
end

function on_create_move(cmd, local_player)
    if not cmd or not local_player or not local_player:is_alive() then return end

    if not client.get_shared_bool("bhop_enabled", false) then return end

    if local_player:get_move_type() ~= MOVETYPE_WALK then return end

    local buttons = cmd:get_buttons()
    local bhop_mode = client.get_shared_int("bhop_mode", 1)
    local strafe_mode = client.get_shared_int("strafe_mode", 0)

    if (buttons & IN_JUMP) ~= 0 then
        apply_bhop(cmd, local_player, bhop_mode)
        apply_strafe(cmd, local_player, strafe_mode)
    end
end

function on_end_scene()
    if not menu.is_open() then return end

    if not imgui.begin("Bhop", 0) then
        imgui["end"]()
        return
    end

    local changed, val = imgui.checkbox("Enable", client.get_shared_bool("bhop_enabled", false))
    if changed then client.set_shared_bool("bhop_enabled", val) end

    imgui.separator()

    local bhop_items = {"Disabled", "Normal", "SMAC-Safe", "LiAC-Safe", "Humanize"}
    changed, val = imgui.combo("AutoBhop", client.get_shared_int("bhop_mode", 1), bhop_items)
    if changed then client.set_shared_int("bhop_mode", val) end

    if client.get_shared_int("bhop_mode", 1) == 4 then
        changed, val = imgui.slider_float("Success Rate", client.get_shared_float("humanize_success_rate", 95.0), 0.0, 100.0)
        if changed then client.set_shared_float("humanize_success_rate", val) end
    end

    local strafe_items = {"Disabled", "Forward", "Back", "Left", "Right", "Don't turn", "Full Speed"}
    changed, val = imgui.combo("AutoStrafe", client.get_shared_int("strafe_mode", 0), strafe_items)
    if changed then client.set_shared_int("strafe_mode", val) end

    imgui["end"]()
end
