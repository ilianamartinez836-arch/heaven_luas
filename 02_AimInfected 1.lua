local config = {
    enabled = true,
    aimkey = keys.MOUSE5,
    fov = 180.0,
    smooth = 1.0,
    max_distance = 4096.0,
    target_head = true,
    silent_aim = false,
    vischeck = true,
    tank_auto_hit = false,
    m2_spam_all = false,
}

local locked_entity = nil
local click_phase = false

local IN_ATTACK = 1
local IN_ATTACK2 = 2048

local function normalizeAngle(a)
    while a > 180 do a = a - 360 end
    while a < -180 do a = a + 360 end
    return a
end

local function calcAngle(src, dst)
    local dx = dst.x - src.x
    local dy = dst.y - src.y
    local dz = dst.z - src.z
    local hyp = math.sqrt(dx * dx + dy * dy)
    if hyp < 0.001 then hyp = 0.001 end
    return vector.new(math.deg(math.atan2(-dz, hyp)), math.deg(math.atan2(dy, dx)), 0)
end

local function getFOV(view, aim)
    local dx = normalizeAngle(aim.x - view.x)
    local dy = normalizeAngle(aim.y - view.y)
    return math.sqrt(dx * dx + dy * dy)
end

local function smoothAngles(cur, target, smooth)
    if not smooth or smooth <= 1.0 then return target end
    local f = 1.0 / smooth
    return vector.new(
        cur.x + normalizeAngle(target.x - cur.x) * f,
        cur.y + normalizeAngle(target.y - cur.y) * f,
        0
    )
end

local function is_visible(player)
    if not config.vischeck then return true end
    local ok, raw = pcall(entity.get_by_index_raw, player:get_index())
    if not ok or not raw or raw == 0 then return true end
    local ok2, dorm = pcall(entity.is_dormant, raw)
    if not ok2 then return true end
    return not dorm
end

local function get_aim_pos(player)
    if config.target_head then
        local ok, eye = pcall(function() return player:get_eye_position() end)
        if ok and eye and eye.x then return eye end
    end
    local ok2, o = pcall(function() return player:get_origin() end)
    if ok2 and o then
        return vector.new(o.x, o.y, o.z + 40.0)
    end
    return nil
end

local function is_valid_locked(ent, eye_pos)
    if not ent then return false end
    local ok_a, alive = pcall(function() return ent:is_alive() end)
    if not ok_a or not alive then return false end
    local ok_t, team = pcall(function() return ent:get_team() end)
    if not ok_t or team ~= 2 then return false end
    if ent.is_incapacitated then
        local ok_i, inc = pcall(function() return ent:is_incapacitated() end)
        if ok_i and inc then return false end
    end
    local ok_o, o = pcall(function() return ent:get_origin() end)
    if not ok_o or not o then return false end
    if vector.distance(eye_pos, o) > config.max_distance then return false end
    if not is_visible(ent) then return false end
    return true
end

local function getBestTarget(local_player)
    local eye_pos = local_player:get_eye_position()
    if not eye_pos then return nil end
    local view_angs = local_player:get_eye_angles()
    if not view_angs then view_angs = vector.new(0, 0, 0) end
    local local_idx = local_player:get_index()
    local mc = engine.get_max_clients() or 32
    local best = nil
    local best_fov = config.fov

    for i = 1, mc do
        local player = entity.get_by_index(i)
        if not player then goto continue end
        if i == local_idx then goto continue end
        local ok_a, alive = pcall(function() return player:is_alive() end)
        if not ok_a or not alive then goto continue end
        local ok_t, team = pcall(function() return player:get_team() end)
        if not ok_t or team ~= 2 then goto continue end
        if player.is_incapacitated then
            local ok_i, inc = pcall(function() return player:is_incapacitated() end)
            if ok_i and inc then goto continue end
        end
        if not is_visible(player) then goto continue end

        local aim_pos = get_aim_pos(player)
        if not aim_pos then goto continue end
        local dist = vector.distance(eye_pos, player:get_origin())
        if dist > config.max_distance then goto continue end

        local aim_angle = calcAngle(eye_pos, aim_pos)
        local fov = getFOV(view_angs, aim_angle)
        if fov > best_fov then goto continue end

        best_fov = fov
        best = { player = player, aim_pos = aim_pos, aim_angle = aim_angle }
        ::continue::
    end
    return best
end

local function get_zombie_class(lp)
    if not lp or not lp.get_zombie_class then return 0 end
    local ok, zc = pcall(function() return lp:get_zombie_class() end)
    if ok and zc then return zc end
    return 0
end

local function is_tank(lp)
    local zc = get_zombie_class(lp)
    if zc == 8 then return true end
    if zombie_class and zombie_class.TANK and zc == zombie_class.TANK then return true end
    return false
end

local function apply_click_spam(cmd, local_player)
    local want_m1 = config.tank_auto_hit and is_tank(local_player)
    local want_m2 = config.m2_spam_all
    if not want_m1 and not want_m2 then return end

    click_phase = not click_phase
    local buttons = cmd:get_buttons()

    if want_m1 then
        if click_phase then
            buttons = buttons | IN_ATTACK
        else
            buttons = buttons & ~IN_ATTACK
        end
    end

    if want_m2 then
        if click_phase then
            buttons = buttons | IN_ATTACK2
        else
            buttons = buttons & ~IN_ATTACK2
        end
    end

    cmd:set_buttons(buttons)
end

function on_create_move(cmd, local_player)
    if not cmd or not local_player then return end
    if not local_player:is_alive() then return end
    if not engine.is_in_game() then return end
    if not config.enabled then
        locked_entity = nil
        return
    end

    if client.get_shared_bool then
        local ok, tank_active = pcall(client.get_shared_bool, "tank_active", false)
        if ok and tank_active then
            locked_entity = nil
            return
        end
    end

    local team = local_player:get_team()
    if team ~= 3 then
        locked_entity = nil
        return
    end

    if not input.is_key_down(config.aimkey) then
        locked_entity = nil
        return
    end

    local eye_pos = local_player:get_eye_position()
    if not eye_pos then return end

    if locked_entity and not is_valid_locked(locked_entity, eye_pos) then
        locked_entity = nil
    end

    if not locked_entity then
        local t = getBestTarget(local_player)
        if t then locked_entity = t.player end
    end

    if locked_entity then
        local aim_pos = get_aim_pos(locked_entity)
        if aim_pos then
            local aim_angle = calcAngle(eye_pos, aim_pos)
            local current = cmd:get_viewangles()
            local final
            if config.smooth > 1.0 then
                final = smoothAngles(current, aim_angle, config.smooth)
            else
                final = aim_angle
            end
            final.x = math.clamp(normalizeAngle(final.x), -89.0, 89.0)
            final.y = normalizeAngle(final.y)
            final.z = 0
            cmd:set_viewangles(final)
            if not config.silent_aim then
                engine.set_view_angles(final)
            end
        else
            locked_entity = nil
        end
    end

    apply_click_spam(cmd, local_player)
end

pcall(function()
    menu.add_sub_tab("Aimbot", "Aim Infected", function()
        imgui.text_colored(1.0, 0.4, 0.4, 1.0, "Aim Infected  |  HvH Rage")
        imgui.text_colored(0.5, 0.5, 0.5, 1.0, "Key: MOUSE5 hold")
        imgui.separator()
        local c, v = imgui.checkbox("Enable", config.enabled)
        if c then config.enabled = v end
        c, v = imgui.slider_float("FOV", config.fov, 1.0, 180.0)
        if c then config.fov = v end
        c, v = imgui.slider_float("Smooth (1=snap)", config.smooth, 1.0, 20.0)
        if c then config.smooth = v end
        c, v = imgui.slider_float("Max distance", config.max_distance, 200.0, 8192.0)
        if c then config.max_distance = v end
        c, v = imgui.checkbox("Target head", config.target_head)
        if c then config.target_head = v end
        c, v = imgui.checkbox("Silent aim", config.silent_aim)
        if c then config.silent_aim = v end
        c, v = imgui.checkbox("Vischeck (dormant)", config.vischeck)
        if c then config.vischeck = v end
        imgui.spacing()
        imgui.separator()
        imgui.text_colored(1.0, 0.75, 0.3, 1.0, "Click spam (while MOUSE5)")
        c, v = imgui.checkbox("Tank auto hit (M1)", config.tank_auto_hit)
        if c then config.tank_auto_hit = v end
        c, v = imgui.checkbox("Infected m2 spam all (M2)", config.m2_spam_all)
        if c then config.m2_spam_all = v end
    end)
end)

function on_unload()
    locked_entity = nil
    client.print("[AimInfected] unloaded")
end

client.print("[AimInfected] loaded — MOUSE5 | dormant | tank M1 / all M2 spam")
