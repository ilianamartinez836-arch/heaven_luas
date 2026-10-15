--Made by Rarita (Lucky\Aika\Mambo)
--Heaven version: 1.0.2
local aa = {
    spin_speed = 130.0, 
    spin_angle = 0.0,
    pitch_value = 89.0, 
    flip_interval = 20, 
    tick_count = 0,
    do_desync_on_next = false,
}

if client.get_shared_bool("aa_enabled", nil) == nil then
    client.set_shared_bool("aa_enabled", false)
    client.set_shared_bool("aa_spin_enabled", true)
    client.set_shared_bool("aa_pitch_up", false)
    client.set_shared_int("aa_spin_speed", 130)
    client.set_shared_int("aa_pitch_value", 89)
    client.set_shared_int("aa_flip_interval", 20)
end

local function normalize_angle(a)
    while a > 180 do a = a - 360 end
    while a < -180 do a = a + 360 end
    return a
end

function on_create_move_prediction(cmd, local_player)
    if not cmd or not local_player then
        client.set_send_packet(true)
        return
    end

    if not local_player:is_alive() then
        aa.tick_count = 0
        aa.do_desync_on_next = false
        client.set_send_packet(true)
        return
    end

    local enabled = client.get_shared_bool("aa_enabled", false)
    local spin_enabled = client.get_shared_bool("aa_spin_enabled", true)
    local pitch_up = client.get_shared_bool("aa_pitch_up", false)
    
 
    local spin_speed = client.get_shared_int("aa_spin_speed", 130)
    local pitch_value = client.get_shared_int("aa_pitch_value", 89)
    local flip_interval = client.get_shared_int("aa_flip_interval", 20)

    local IN_USE = 32
    local IN_ATTACK = 1
    local IN_ATTACK2 = 2048
    local MOVETYPE_LADDER = 9
    
    local move_type = local_player:get_move_type()
    local on_ladder = (move_type == MOVETYPE_LADDER)
    local buttons = cmd:get_buttons()

    if (not enabled)
       or ((buttons & (IN_USE | IN_ATTACK | IN_ATTACK2)) ~= 0)
       or on_ladder then
        client.set_send_packet(true)
        return
    end

    aa.tick_count = aa.tick_count + 1

    if spin_enabled and spin_speed ~= 0 then
        aa.spin_angle = aa.spin_angle + spin_speed
        aa.spin_angle = normalize_angle(aa.spin_angle)
    end

    if enabled then
        if (aa.tick_count % flip_interval) == 0 then
            aa.do_desync_on_next = true
        end
    else
        aa.do_desync_on_next = false
    end

    local angles = cmd:get_viewangles()

    if pitch_up then
        angles.x = pitch_value
    end

    if aa.do_desync_on_next then
        angles.y = normalize_angle(angles.y + 120.0)
        client.set_send_packet(false)
        aa.do_desync_on_next = false
    else
        if spin_enabled then
            angles.y = aa.spin_angle
        end
        client.set_send_packet(true)
    end

    cmd:set_viewangles(angles)
end


menu.add_main_tab("AntiAims", function()
    imgui.text("Anti-Aim Test (single-tick desync)")
    imgui.separator()

    local changed, val = imgui.checkbox("Enabled", client.get_shared_bool("aa_enabled", false))
    if changed then client.set_shared_bool("aa_enabled", val) end

    imgui.separator()
    local changed, val = imgui.checkbox("Spin Enabled", client.get_shared_bool("aa_spin_enabled", true))
    if changed then client.set_shared_bool("aa_spin_enabled", val) end

    local current_speed = client.get_shared_int("aa_spin_speed", 130)
    local _, int_speed = imgui.slider_int("Spin Speed (deg/tick)", current_speed, 0, 180)
    if int_speed ~= current_speed then
        client.set_shared_int("aa_spin_speed", int_speed)
    end

    imgui.separator()
    local changed, val = imgui.checkbox("Pitch Enable", client.get_shared_bool("aa_pitch_up", false))
    if changed then client.set_shared_bool("aa_pitch_up", val) end

    local current_pitch = client.get_shared_int("aa_pitch_value", 89)
    local changed, new_pitch = imgui.slider_int("Pitch Value", current_pitch, -89, 89)
    if changed then
        client.set_shared_int("aa_pitch_value", new_pitch)
    end

    imgui.separator()
    local current_interval = client.get_shared_int("aa_flip_interval", 20)
    local _, new_interval = imgui.slider_int("Flip Interval (ticks)", current_interval, 1, 60)
    if new_interval ~= current_interval then
        client.set_shared_int("aa_flip_interval", new_interval)
    end


    imgui["end"]()
end)