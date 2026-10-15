----------------------------
-- Advanced Anti-Aim (L4D2 Heaven API)
-- Ported from cs2 Aiware Lua REPO
----------------------------
local function normalize_angle(angle)
    while angle > 180 do angle = angle - 360 end
    while angle < -180 do angle = angle + 360 end
    return angle
end

if client.get_shared_bool("aa2_initialized", nil) == nil then
    client.set_shared_bool("aa2_initialized", true)
    client.set_shared_bool("aa2_enabled", false)
    client.set_shared_bool("aa2_pitch_jitter", false)
    client.set_shared_int("aa2_pitch_jitter_speed", 8)
    client.set_shared_bool("aa2_yaw_jitter", false)
    client.set_shared_int("aa2_yaw_left", 45)
    client.set_shared_int("aa2_yaw_right", 45)
    client.set_shared_int("aa2_yaw_jitter_speed", 8)
    client.set_shared_bool("aa2_yaw_backward", false)
    client.set_shared_bool("aa2_spin", false)
    client.set_shared_int("aa2_spin_speed", 16)
    client.set_shared_bool("aa2_random_yaw", false)
    client.set_shared_int("aa2_random_yaw_range", 90)
    client.set_shared_bool("aa2_random_yaw_backward", false)
    client.set_shared_int("aa2_random_yaw_speed", 8)
    client.set_shared_bool("aa2_fake_flick_pitch", false)
    client.set_shared_int("aa2_flick_period_pitch", 16)
    client.set_shared_bool("aa2_invert_pitch", false)
    client.set_shared_bool("aa2_fake_flick_yaw", false)
    client.set_shared_int("aa2_flick_period_yaw", 64)
    client.set_shared_bool("aa2_invert_flick_yaw", false)
    client.set_shared_bool("aa2_manual_right", false)
    client.set_shared_bool("aa2_manual_left", false)
    client.set_shared_int("aa2_default_yaw", 0)
end

local aa2_lastPitchChange = 0
local aa2_pitchState = false
local aa2_lastYawJitter = 0
local aa2_jitterDir = true
local aa2_lastRandomYaw = 0
local aa2_lastSpinChange = 0
local aa2_currentYaw = 0
local aa2_lastFFPitchTick = 0
local aa2_lastFFYawTick = 0

menu.add_main_tab("Advanced-AA", function()
    imgui.text("Advanced Anti-Aim - Flick, Jitter, Spin, Randomized Yaw")
    imgui.separator()

    local changed, en = imgui.checkbox("Enable AA", client.get_shared_bool("aa2_enabled", false))
    if changed then client.set_shared_bool("aa2_enabled", en) end
    if not en then imgui["end"]() return end
    imgui.separator()

    local changed_pj, en_pj = imgui.checkbox("Pitch Jitter", client.get_shared_bool("aa2_pitch_jitter", false))
    if changed_pj then client.set_shared_bool("aa2_pitch_jitter", en_pj) end

    local changed_pjs, val_pjs = imgui.slider_int("Pitch Jitter Speed (Ticks)", client.get_shared_int("aa2_pitch_jitter_speed", 8), 1, 32)
    if changed_pjs then client.set_shared_int("aa2_pitch_jitter_speed", val_pjs) end
    imgui.separator()

    local changed_yj, en_yj = imgui.checkbox("Yaw Jitter", client.get_shared_bool("aa2_yaw_jitter", false))
    if changed_yj then client.set_shared_bool("aa2_yaw_jitter", en_yj) end

    local changed_yjl, val_yjl = imgui.slider_int("Yaw Jitter Left", client.get_shared_int("aa2_yaw_left", 45), 0, 90)
    if changed_yjl then client.set_shared_int("aa2_yaw_left", val_yjl) end

    local changed_yjr, val_yjr = imgui.slider_int("Yaw Jitter Right", client.get_shared_int("aa2_yaw_right", 45), 0, 90)
    if changed_yjr then client.set_shared_int("aa2_yaw_right", val_yjr) end

    local changed_yjb, en_yjb = imgui.checkbox("Yaw Jitter Backward", client.get_shared_bool("aa2_yaw_backward", false))
    if changed_yjb then client.set_shared_bool("aa2_yaw_backward", en_yjb) end

    local changed_yjs, val_yjs = imgui.slider_int("Yaw Jitter Speed (Ticks)", client.get_shared_int("aa2_yaw_jitter_speed", 8), 1, 32)
    if changed_yjs then client.set_shared_int("aa2_yaw_jitter_speed", val_yjs) end
    imgui.separator()

    local changed_sp, en_sp = imgui.checkbox("Spin Enable", client.get_shared_bool("aa2_spin", false))
    if changed_sp then client.set_shared_bool("aa2_spin", en_sp) end

    local changed_ss, val_ss = imgui.slider_int("Spin Speed (Ticks)", client.get_shared_int("aa2_spin_speed", 16), 1, 64)
    if changed_ss then client.set_shared_int("aa2_spin_speed", val_ss) end
    imgui.separator()

    local changed_ry, en_ry = imgui.checkbox("Random Yaw Enable", client.get_shared_bool("aa2_random_yaw", false))
    if changed_ry then client.set_shared_bool("aa2_random_yaw", en_ry) end

    local changed_ryr, val_ryr = imgui.slider_int("Random Yaw Range", client.get_shared_int("aa2_random_yaw_range", 90), 0, 180)
    if changed_ryr then client.set_shared_int("aa2_random_yaw_range", val_ryr) end

    local changed_ryb, en_ryb = imgui.checkbox("Random Yaw Backward", client.get_shared_bool("aa2_random_yaw_backward", false))
    if changed_ryb then client.set_shared_bool("aa2_random_yaw_backward", en_ryb) end

    local changed_rys, val_rys = imgui.slider_int("Random Yaw Speed (Ticks)", client.get_shared_int("aa2_random_yaw_speed", 8), 1, 32)
    if changed_rys then client.set_shared_int("aa2_random_yaw_speed", val_rys) end
    imgui.separator()

    local changed_ffp, en_ffp = imgui.checkbox("Fake Flick Pitch", client.get_shared_bool("aa2_fake_flick_pitch", false))
    if changed_ffp then client.set_shared_bool("aa2_fake_flick_pitch", en_ffp) end

    local changed_ffps, val_ffps = imgui.slider_int("Flick Period Pitch", client.get_shared_int("aa2_flick_period_pitch", 16), 1, 128)
    if changed_ffps then client.set_shared_int("aa2_flick_period_pitch", val_ffps) end

    local changed_ffpi, en_ffpi = imgui.checkbox("Invert Pitch Flick", client.get_shared_bool("aa2_invert_pitch", false))
    if changed_ffpi then client.set_shared_bool("aa2_invert_pitch", en_ffpi) end
    imgui.separator()

    local changed_ffy, en_ffy = imgui.checkbox("Fake Flick Yaw", client.get_shared_bool("aa2_fake_flick_yaw", false))
    if changed_ffy then client.set_shared_bool("aa2_fake_flick_yaw", en_ffy) end

    local changed_ffys, val_ffys = imgui.slider_int("Flick Period Yaw", client.get_shared_int("aa2_flick_period_yaw", 64), 1, 128)
    if changed_ffys then client.set_shared_int("aa2_flick_period_yaw", val_ffys) end

    local changed_ffyi, en_ffyi = imgui.checkbox("Invert Flick Yaw", client.get_shared_bool("aa2_invert_flick_yaw", false))
    if changed_ffyi then client.set_shared_bool("aa2_invert_flick_yaw", en_ffyi) end

    local changed_mr, en_mr = imgui.checkbox("Manual Right", client.get_shared_bool("aa2_manual_right", false))
    if changed_mr then client.set_shared_bool("aa2_manual_right", en_mr) end

    local changed_ml, en_ml = imgui.checkbox("Manual Left", client.get_shared_bool("aa2_manual_left", false))
    if changed_ml then client.set_shared_bool("aa2_manual_left", en_ml) end

    local changed_dy, val_dy = imgui.slider_int("Default Yaw", client.get_shared_int("aa2_default_yaw", 0), -180, 180)
    if changed_dy then client.set_shared_int("aa2_default_yaw", val_dy) end

    imgui["end"]()
end)

function on_create_move(cmd, local_player)

    if not client.get_shared_bool("aa2_enabled", false) or not local_player or not local_player:is_alive() then
        client.set_send_packet(true)
        return
    end
    local move_type = local_player:get_move_type()
    local buttons = cmd:get_buttons()
    local IN_USE = 32
    local IN_ATTACK = 1
    local IN_ATTACK2 = 2048
    
    if move_type == 9 or (buttons & (IN_USE | IN_ATTACK | IN_ATTACK2)) ~= 0 then
        client.set_send_packet(true)
        return
    end
    local tick = client.get_tick_count()
    local angles = cmd:get_viewangles()
    local base_yaw = angles.y

    local pitch_jitter = client.get_shared_bool("aa2_pitch_jitter", false)
    local pitch_jitter_speed = client.get_shared_int("aa2_pitch_jitter_speed", 8)
    if pitch_jitter then
        if tick - aa2_lastPitchChange > pitch_jitter_speed then
            angles.x = aa2_pitchState and 89 or -89
            aa2_pitchState = not aa2_pitchState
            aa2_lastPitchChange = tick
        end
    end

    local yaw_jitter = client.get_shared_bool("aa2_yaw_jitter", false)
    local yaw_jitter_left = client.get_shared_int("aa2_yaw_left", 45)
    local yaw_jitter_right = client.get_shared_int("aa2_yaw_right", 45)
    local yaw_jitter_speed = client.get_shared_int("aa2_yaw_jitter_speed", 8)
    local yaw_jitter_backward = client.get_shared_bool("aa2_yaw_backward", false)
    if yaw_jitter then
        if tick - aa2_lastYawJitter > yaw_jitter_speed then
            local left_val = yaw_jitter_backward and -(180 - yaw_jitter_left) or -yaw_jitter_left
            local right_val = yaw_jitter_backward and (180 - yaw_jitter_right) or yaw_jitter_right
            local jitter_val = aa2_jitterDir and right_val or left_val
            angles.y = normalize_angle(base_yaw + jitter_val)
            aa2_jitterDir = not aa2_jitterDir
            aa2_lastYawJitter = tick
        end
    end

    local spin_enable = client.get_shared_bool("aa2_spin", false)
    local spin_speed = client.get_shared_int("aa2_spin_speed", 16)
    if spin_enable then
        if tick - aa2_lastSpinChange > spin_speed then
            aa2_currentYaw = normalize_angle((aa2_currentYaw or 0) + 10)
            angles.y = aa2_currentYaw
            aa2_lastSpinChange = tick
        end
    end

    local rand_enable = client.get_shared_bool("aa2_random_yaw", false)
    local rand_range = client.get_shared_int("aa2_random_yaw_range", 90)
    local rand_back = client.get_shared_bool("aa2_random_yaw_backward", false)
    local rand_speed = client.get_shared_int("aa2_random_yaw_speed", 8)
    if rand_enable then
        if tick - aa2_lastRandomYaw > rand_speed then
            local yawMin = rand_back and (180 - rand_range) or -rand_range
            local yawMax = rand_back and (180 + rand_range) or rand_range
            angles.y = math.random(yawMin, yawMax)
            if angles.y > 180 then angles.y = angles.y - 360 end
            if angles.y < -179 then angles.y = angles.y + 360 end
            aa2_lastRandomYaw = tick
        end
    end

    local ffp_enable = client.get_shared_bool("aa2_fake_flick_pitch", false)
    local ffp_period = client.get_shared_int("aa2_flick_period_pitch", 16)
    local ffp_invert = client.get_shared_bool("aa2_invert_pitch", false)
    if ffp_enable then
        if tick % ffp_period < 1 then
            angles.x = ffp_invert and 89 or -89
            if aa2_lastFFPitchTick ~= tick then
                aa2_lastFFPitchTick = tick
            end
        else
            angles.x = ffp_invert and -89 or 89
            if aa2_lastFFPitchTick ~= tick then
                aa2_lastFFPitchTick = tick
            end
        end
    end

    local ffy_enable = client.get_shared_bool("aa2_fake_flick_yaw", false)
    local ffy_period = client.get_shared_int("aa2_flick_period_yaw", 64)
    local ffy_invert = client.get_shared_bool("aa2_invert_flick_yaw", false)
    local man_right = client.get_shared_bool("aa2_manual_right", false)
    local man_left = client.get_shared_bool("aa2_manual_left", false)
    local default_yaw = client.get_shared_int("aa2_default_yaw", 0)
    if ffy_enable then
        if man_right then
            angles.y = -90
        elseif man_left then
            angles.y = 90
        else
            angles.y = default_yaw or angles.y
        end
        if ffy_invert and tick % ffy_period < 1 then
            angles.y = -angles.y
        end
    end

    cmd:set_viewangles(angles)

    client.set_send_packet(tick % 2 ~= 0)
end



