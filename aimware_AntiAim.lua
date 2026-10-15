local aa = {
    spin_speed = 10,
    jitter_range = 90,
    spin_angle = 0.0,
    tick_count = 0,
}
--this is just a lol anti aim btw
--you can set send packet to false to cause desync
-- but since this is made for hvh i have dediced to set it to true
-- have that in mind pls
if client.get_shared_bool("aa_enabled", nil) == nil then
    client.set_shared_bool("aa_enabled", false)
    client.set_shared_bool("aa_disable_on_ladder", true)
    client.set_shared_bool("aa_disable_on_use", true)
    client.set_shared_int("aa_pitch_mode", 0)
    client.set_shared_int("aa_yaw_mode", 0)
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
        client.set_send_packet(true)
        return
    end

    local enabled = client.get_shared_bool("aa_enabled", false)

    if not enabled then
        client.set_send_packet(true)
        return
    end

    local disable_on_ladder = client.get_shared_bool("aa_disable_on_ladder", true)
    local disable_on_use = client.get_shared_bool("aa_disable_on_use", true)
    local pitch_mode = client.get_shared_int("aa_pitch_mode", 0)
    local yaw_mode = client.get_shared_int("aa_yaw_mode", 0)

    local IN_USE = 32
    local IN_ATTACK = 1
    local IN_ATTACK2 = 2048
    local MOVETYPE_LADDER = 9

    local buttons = cmd:get_buttons()

    if disable_on_use and ((buttons & (IN_USE | IN_ATTACK | IN_ATTACK2)) ~= 0) then
        client.set_send_packet(true)
        return
    end

    if disable_on_ladder and local_player:get_move_type() == MOVETYPE_LADDER then
        client.set_send_packet(true)
        return
    end

    aa.tick_count = aa.tick_count + 1
	local send_packet = true
    if pitch_mode == 3 then
        send_packet = (aa.tick_count % 2 == 0)
    end
    local angles = cmd:get_viewangles()

	if pitch_mode ~= 0 then
        if pitch_mode == 1 then
            angles.x = 89.0
        elseif pitch_mode == 2 then
            angles.x = 89.0
        elseif pitch_mode == 3 then
    		angles.x = 2160.0 + 89.0 --Say thx nigger ;)
        end
    end

    if yaw_mode ~= 0 then
        local yaw_offset = 0.0
        local jitter_offset = 0.0
        local is_spin = false

        if yaw_mode == 1 then
            yaw_offset = 180.0
        elseif yaw_mode == 2 then
            yaw_offset = 90.0
        elseif yaw_mode == 3 then
            yaw_offset = -90.0
        elseif yaw_mode == 4 then
            is_spin = true
        elseif yaw_mode == 5 then
            yaw_offset = 180.0
            jitter_offset = math.random() * aa.jitter_range - (aa.jitter_range / 2.0)
        elseif yaw_mode == 6 then
            yaw_offset = 0.0
            jitter_offset = math.random() * aa.jitter_range - (aa.jitter_range / 2.0)
        elseif yaw_mode == 7 then
            local side = (aa.tick_count % 2 == 0) and 1 or -1
            yaw_offset = side * 90.0
            jitter_offset = math.random() * aa.jitter_range - (aa.jitter_range / 2.0)
        end

        if is_spin then
            aa.spin_angle = normalize_angle(aa.spin_angle + aa.spin_speed)
            angles.y = aa.spin_angle
        else
            angles.y = normalize_angle(angles.y + yaw_offset + jitter_offset)
        end
    end

    client.set_send_packet(true)
    cmd:set_viewangles(angles)
end

menu.add_main_tab("AntiAims", function()
    imgui.text("Anti-Aim Test Harness (Aimware-inspired)")
    imgui.separator()

    local changed, val = imgui.checkbox("Enabled", client.get_shared_bool("aa_enabled", false))
    if changed then client.set_shared_bool("aa_enabled", val) end

    imgui.separator()
    imgui.text("Advanced Section")
    imgui.separator()

    local changed, val = imgui.slider_int("Spinbot Speed", aa.spin_speed, 1, 20)
    if changed then aa.spin_speed = val end

    local changed, val = imgui.slider_int("Jitter Range", aa.jitter_range, 0, 180)
    if changed then aa.jitter_range = val end

    imgui.separator()

    local pitch_items = {"OFF", "Emotion", "Down", "Fake down"}
    local changed, idx = imgui.combo("Pitch", client.get_shared_int("aa_pitch_mode", 0), pitch_items)
    if changed then client.set_shared_int("aa_pitch_mode", idx) end

    imgui.separator()

    local yaw_items = {"OFF", "Backward", "Sideways left", "Sideways right", "Spinbot", "Jitter Backward", "Jitter Forward", "Jitter sideways"}
    local changed, idx = imgui.combo("Yaw", client.get_shared_int("aa_yaw_mode", 0), yaw_items)
    if changed then client.set_shared_int("aa_yaw_mode", idx) end

    imgui.separator()

    local changed, val = imgui.checkbox("Disable on Ladder", client.get_shared_bool("aa_disable_on_ladder", true))
    if changed then client.set_shared_bool("aa_disable_on_ladder", val) end

    local changed, val = imgui.checkbox("Disable on Use", client.get_shared_bool("aa_disable_on_use", true))
    if changed then client.set_shared_bool("aa_disable_on_use", val) end

    imgui.separator()

    imgui["end"]()
end)





