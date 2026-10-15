--=============================================================================
-- CONSTANTS
--=============================================================================

local IN_JUMP = 2
local IN_SPEED = 1024
local MOVETYPE_WALK = 2
local MOVETYPE_NOCLIP = 8
local MOVETYPE_LADDER = 9
local MOVETYPE_OBSERVER = 10

--=============================================================================
-- INITIALIZATION
--=============================================================================

if client.get_shared_bool("bhop_initialized", nil) == nil then
    client.set_shared_bool("bhop_initialized", true)
    client.set_shared_bool("bhop_enabled", false)
    client.set_shared_bool("strafe_enabled", false)
    client.set_shared_int("bhop_key", 32) -- Default to Space (0x20)
end

--=============================================================================
-- HELPER FUNCTIONS
--=============================================================================

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

local function is_key_down(k)
    if k == 0 then return false end
    local ok, res = pcall(function() return input.is_key_down(k) end)
    if ok then return res end
    ok, res = pcall(function() return client.is_key_down(k) end)
    if ok then return res end
    return false
end

--=============================================================================
-- SIMPLE BHOP
--=============================================================================

local function apply_bhop(cmd, local_player)
    local buttons = cmd:get_buttons()
    if (buttons & IN_JUMP) ~= 0 and not local_player:is_on_ground() then
        cmd:set_buttons(buttons & ~IN_JUMP)
    end
end

--=============================================================================
-- FULLSPEED STRAFER
--=============================================================================

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

--=============================================================================
-- CREATE MOVE HOOK
--=============================================================================

function on_create_move(cmd, local_player)
    if not cmd or not local_player or not local_player:is_alive() then return end

    if local_player:get_move_type() ~= MOVETYPE_WALK then return end

    local buttons = cmd:get_buttons()

    if client.get_shared_bool("bhop_enabled", false) then
        local bhop_key = client.get_shared_int("bhop_key", 0)
        local key_active = false

        if bhop_key == 0 then
            key_active = (buttons & IN_JUMP) ~= 0
        else
            key_active = is_key_down(bhop_key)
        end

        if key_active then
            -- Ensure IN_JUMP is set if a specific key is active
            if bhop_key ~= 0 then
                cmd:set_buttons(buttons | IN_JUMP)
            end
            apply_bhop(cmd, local_player)
        end
    end

    if client.get_shared_bool("strafe_enabled", false) then
        apply_strafe(cmd, local_player)
    end
end

--=============================================================================
-- MENU
--=============================================================================

function on_end_scene()
    if not menu.is_open() then return end

    if not imgui.begin("BunnyHop", 0) then
        imgui["end"]()
        return
    end

    -- Bhop checkbox
    local bhop_enabled = client.get_shared_bool("bhop_enabled", false)
    local changed, val = imgui.checkbox("Enable BunnyHop", bhop_enabled)
    if changed then
        client.set_shared_bool("bhop_enabled", val)
        bhop_enabled = val
        client.print("[Bhop] " .. (val and "enabled" or "disabled"))
    end

    -- Bhop keybind selector (Combo is safer and more compatible)
    local keys = {"Any (Jump Bound)", "Space", "Alt", "Shift", "V", "C"}
    local codes = {0, 32, 18, 16, 86, 67}
    local current_key = client.get_shared_int("bhop_key", 0)
    local current_idx = 0
    for i, v in ipairs(codes) do
        if v == current_key then
            current_idx = i - 1
            break
        end
    end

    local k_changed, k_val = imgui.combo("Bhop Key", current_idx, keys)
    if k_changed then
        client.set_shared_int("bhop_key", codes[k_val + 1])
        client.print("[Bhop] Key set to " .. keys[k_val + 1])
    end

    imgui.separator()

    -- Strafe checkbox
    local strafe_enabled = client.get_shared_bool("strafe_enabled", false)
    changed, val = imgui.checkbox("AutoStrafe", strafe_enabled)
    if changed then
        client.set_shared_bool("strafe_enabled", val)
        strafe_enabled = val
        client.print("[Bhop] Strafe " .. (val and "enabled" or "disabled"))
    end

    -- Inline child panel when strafe is enabled
    if strafe_enabled then
        if imgui.begin_child("strafe_panel", 0, 60, true) then
            imgui.text_colored(0.4, 0.8, 1.0, 1.0, "Mode: Full Speed Strafer")
            imgui.text_colored(0.7, 0.7, 0.7, 1.0, "• Physics-based optimal acceleration")
            imgui.text_colored(0.7, 0.7, 0.7, 1.0, "• Auto-corrects move angles per tick")
        end
        imgui.end_child()

        -- Live speed readout
        local lp = client.get_local_player()
        if lp and lp:is_alive() and not lp:is_on_ground() then
            local vel = lp:get_velocity()
            local sp = math.sqrt(vel.x^2 + vel.y^2)
            imgui.text_colored(0.7, 0.7, 0.7, 1.0, string.format("Speed: %.1f", sp))
        end
    end

    imgui.spacing()
    imgui.separator()

    imgui.text_colored(0.5, 0.5, 0.5, 1.0, "Hold jump to activate")
    if bhop_enabled then
        imgui.text_colored(0.0, 1.0, 0.0, 1.0, "● Active")
    else
        imgui.text_colored(1.0, 0.0, 0.0, 1.0, "○ Inactive")
    end

    imgui["end"]()
end

--=============================================================================
-- LOAD MESSAGE
--=============================================================================


