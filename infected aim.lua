

local config = {
    enabled      = true,
    aimkey       = keys.MOUSE4,
    fov          = 180.0,
    smooth       = 1.0,
    chest_blend  = 0.65,
    max_distance = 8192,
    silent_aim   = false,
    vischeck     = true,
}

local function load_cfg()
    config.enabled      = client.get_shared_bool("ab_enabled",      config.enabled)
    config.fov          = client.get_shared_float("ab_fov",         config.fov)
    config.smooth       = client.get_shared_float("ab_smooth",      config.smooth)
    config.chest_blend  = client.get_shared_float("ab_chest_blend", config.chest_blend)
    config.max_distance = client.get_shared_float("ab_max_dist",    config.max_distance)
    config.silent_aim   = client.get_shared_bool("ab_silent",       config.silent_aim)
    config.vischeck     = client.get_shared_bool("ab_vischeck",     config.vischeck)
end

local function save_cfg()
    client.set_shared_bool("ab_enabled",      config.enabled)
    client.set_shared_float("ab_fov",         config.fov)
    client.set_shared_float("ab_smooth",      config.smooth)
    client.set_shared_float("ab_chest_blend", config.chest_blend)
    client.set_shared_float("ab_max_dist",    config.max_distance)
    client.set_shared_bool("ab_silent",       config.silent_aim)
    client.set_shared_bool("ab_vischeck",     config.vischeck)
    client.set_shared_bool("ab_fov_circle",   true)
end

load_cfg()


local locked_entity    = nil
local prev_key_down    = false
local cached_lp_index  = -1 


local function calcAngle(src, dst)
    local dx  = dst.x - src.x
    local dy  = dst.y - src.y
    local dz  = dst.z - src.z
    local hyp = math.sqrt(dx*dx + dy*dy)
    return vector.new(
        math.deg(math.atan2(-dz, hyp)),
        math.deg(math.atan2(dy, dx)),
        0)
end

local function normalizeAngle(angle)
    while angle >  180 do angle = angle - 360 end
    while angle < -180 do angle = angle + 360 end
    return angle
end

local function getFOV(viewAngles, aimAngles)
    local dp = normalizeAngle(aimAngles.x - viewAngles.x)
    local dy = normalizeAngle(aimAngles.y - viewAngles.y)
    return math.sqrt(dp*dp + dy*dy)
end

local function smoothAngles(current, target, smooth)
    local dp = normalizeAngle(target.x - current.x)
    local dy = normalizeAngle(target.y - current.y)
    local f  = 1.0 / math.max(smooth, 1.0)
    return vector.new(
        current.x + dp * f,
        current.y + dy * f,
        0)
end

local function get_aim_pos(player)
    local origin = player:get_origin()
    local eye    = player:get_eye_position()
    if not origin or not eye then return nil end
    local t = config.chest_blend
    return vector.new(
        origin.x + (eye.x - origin.x) * t,
        origin.y + (eye.y - origin.y) * t,
        origin.z + (eye.z - origin.z) * t)
end

-- ─────────────────────────────────────────────
-- VISCHECK
-- ─────────────────────────────────────────────

local function is_visible(player)
    if not config.vischeck then return true end
    local raw = entity.get_by_index_raw(player:get_index())
    if not raw or raw == 0 then return true end
    return not entity.is_dormant(raw)
end


local function is_valid_locked(ent, eye_pos)
    if not ent then return false end
    if not ent:is_alive() then return false end
    if ent:get_team() ~= 2 then return false end
    if ent:is_incapacitated() then return false end
    local o = ent:get_origin()
    if not o then return false end
    if vector.distance(eye_pos, o) > config.max_distance then return false end
    if not is_visible(ent) then return false end
    return true
end

local function getBestTarget(local_player)
    local eye_pos   = local_player:get_eye_position()
    local view_angs = local_player:get_eye_angles()
    local local_idx = local_player:get_index()
    local mc        = engine.get_max_clients()

    local best     = nil
    local best_fov = config.fov

    for i = 1, mc do
        local player = entity.get_by_index(i)
        if not player                then goto continue end
        if i == local_idx            then goto continue end
        if not player:is_alive()     then goto continue end
        if player:get_team() ~= 2   then goto continue end
        if player:is_incapacitated() then goto continue end
        if not is_visible(player)    then goto continue end

        local aim_pos = get_aim_pos(player)
        if not aim_pos then goto continue end

        local dist = vector.distance(eye_pos, player:get_origin())
        if dist > config.max_distance then goto continue end

        local aim_angle = calcAngle(eye_pos, aim_pos)
        local fov       = getFOV(view_angs, aim_angle)
        if fov > best_fov then goto continue end

        best_fov = fov
        best = { player = player, aim_pos = aim_pos, aim_angle = aim_angle }

        ::continue::
    end

    return best
end



function on_create_move(cmd, local_player)
    if not local_player or not local_player:is_alive() then return end
    if not engine.is_in_game() then return end

    -- Cache index every tick so on_paint can retrieve the local player
    cached_lp_index = local_player:get_index()

    if not config.enabled then return end

    -- Yield to tank rock script
    if client.get_shared_bool("tank_active", false) then
        locked_entity = nil
        return
    end

    local team = local_player:get_team()

    -- Only run aimbot on infected, skip tank
    if team ~= 3 then return end
    if local_player:get_zombie_class() == zombie_class.TANK then return end

    local key_down = input.is_key_down(config.aimkey)

    if not key_down then
        locked_entity = nil
        prev_key_down = false
        return
    end

    local eye_pos = local_player:get_eye_position()
    if not eye_pos then return end

    if locked_entity and not is_valid_locked(locked_entity, eye_pos) then
        locked_entity = nil
    end

    if not locked_entity then
        local t = getBestTarget(local_player)
        if not t then return end
        locked_entity = t.player
    end

    local aim_pos = get_aim_pos(locked_entity)
    if not aim_pos then locked_entity = nil; return end

    local aim_angle = calcAngle(eye_pos, aim_pos)
    local current   = cmd:get_viewangles()
    local final

    if config.smooth > 1.0 then
        final = smoothAngles(current, aim_angle, config.smooth)
    else
        final = aim_angle
    end

    final.x = math.clamp(normalizeAngle(final.x), -89.0, 89.0)
    final.y = normalizeAngle(final.y)

    cmd:set_viewangles(final)
    if not config.silent_aim then
        engine.set_view_angles(final)
    end

    prev_key_down = key_down
end

-- ─────────────────────────────────────────────
-- FOV CIRCLE
-- ─────────────────────────────────────────────

function on_paint()
    if not engine.is_in_game() then return end
    if not config.enabled then return end
    if not client.get_shared_bool("ab_fov_circle", true) then return end

    pcall(function()
        -- Retrieve local player via cached index — local_player is not a
        -- global in Heaven-Hook, only a parameter in on_create_move.
        if cached_lp_index < 0 then return end
        local lp = entity.get_by_index(cached_lp_index)
        if not lp or not lp:is_alive() then return end

        -- Circle only shows on infected team (team 3)
        if lp:get_team() ~= 3 then return end

        local sw, sh = draw.get_screen_size()
        if not sw or sw == 0 then return end

        local cx     = math.floor(sw / 2)
        local cy     = math.floor(sh / 2)
        local radius = math.min(
            math.floor((config.fov / 180.0) * (sh * 0.5)),
            math.floor(sh * 0.48))
        if radius <= 0 then return end

        local r, g, b = 1.0, 1.0, 1.0   -- default: white = idle

        local zc = lp:get_zombie_class()
        if zc == zombie_class.TANK then
            -- Tank punch range indicator
            local my_origin = lp:get_origin()
            local mc        = engine.get_max_clients()
            local closest   = math.huge

            if my_origin then
                for i = 1, mc do
                    local p = entity.get_by_index(i)
                    if p and p ~= lp and p:is_alive()
                       and p:get_team() == 2 and not p:is_incapacitated()
                    then
                        local o = p:get_origin()
                        if o then
                            local d = vector.distance(my_origin, o)
                            if d < closest then closest = d end
                        end
                    end
                end
            end

            if closest <= 150 then
                r, g, b = 0.2, 1.0, 0.3   -- green = survivor in punch range
            else
                r, g, b = 1.0, 0.2, 0.2   -- red = nobody in punch range
            end
        else
            -- Non-tank infected colors
            if locked_entity then
                r, g, b = 0.2, 1.0, 0.3   -- green = locked
            elseif input.is_key_down(config.aimkey) then
                r, g, b = 1.0, 0.2, 0.2   -- red = searching, no target
            end
            -- else white stays (idle)
        end

        draw.outlined_circle(cx, cy, radius, 64, r, g, b, 0.8)
    end)
end

-- ─────────────────────────────────────────────
-- MENU
-- ─────────────────────────────────────────────

if not _G.ab_menu_registered then
    _G.ab_menu_registered = true

    menu.add_sub_tab("Aimbot", "Aimbot", function()
        local ok, err = pcall(function()
            local c, v

            imgui.separator()
            imgui.text_colored(1.0, 0.4, 0.4, 1.0, "Aimbot v2.2")
            imgui.separator()

            c, v = imgui.checkbox("Enable", config.enabled)
            if c then config.enabled = v; save_cfg() end
            imgui.same_line()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0,
                "(infected team only — hold aimkey to activate)")

            if locked_entity then
                imgui.text_colored(0.2, 1.0, 0.3, 1.0, "  LOCKED onto target")
            else
                imgui.text_colored(0.5, 0.5, 0.5, 1.0, "  No target locked")
            end

            imgui.spacing()
            imgui.text_colored(0.7, 0.7, 1.0, 1.0, "Vischeck")
            imgui.separator()

            c, v = imgui.checkbox("Vischeck", config.vischeck)
            if c then config.vischeck = v; save_cfg() end
            imgui.same_line()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(skip dormant/hidden survivors)")

            imgui.spacing()
            imgui.text_colored(0.7, 0.7, 1.0, 1.0, "Aim")
            imgui.separator()

            c, v = imgui.slider_float("Chest Blend", config.chest_blend, 0.0, 1.0)
            if c then config.chest_blend = v; save_cfg() end
            imgui.same_line()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0,
                "(0=feet  0.5=mid  0.65=chest/neck  1.0=eyes)")

            c, v = imgui.checkbox("Silent Aim", config.silent_aim)
            if c then config.silent_aim = v; save_cfg() end
            imgui.same_line()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(cmd only — camera never moves)")

            c, v = imgui.checkbox("FOV Circle",
                client.get_shared_bool("ab_fov_circle", true))
            if c then client.set_shared_bool("ab_fov_circle", v) end
            imgui.same_line()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0,
                "(white=idle  green=locked  red=searching  infected only)")

            c, v = imgui.slider_float("Smooth", config.smooth, 1.0, 20.0)
            if c then config.smooth = v; save_cfg() end
            imgui.same_line()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(1.0 = instant snap)")

            c, v = imgui.slider_float("FOV", config.fov, 1.0, 180.0)
            if c then config.fov = v; save_cfg() end
            imgui.same_line()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(cone for initial target acquisition)")

            c, v = imgui.slider_float("Max Distance", config.max_distance, 100.0, 8192.0)
            if c then config.max_distance = v; save_cfg() end
            imgui.same_line()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(units)")

            imgui.spacing()
            imgui.separator()
            imgui.text("Targets: survivors (team 2) only.")
            imgui.text("Tank: aimbot skipped, circle shows punch range (green=in range).")
            imgui.text("Circle only visible on infected team.")
            imgui.text("Lock: holds target — mouse movement won't switch.")
            imgui.text("Vischeck: lock drops if target goes dormant.")
        end)

        if not ok then
            imgui.text_colored(1.0, 0.3, 0.3, 1.0, "menu error: " .. tostring(err))
        end
    end)
end

