local config = {
    enabled = true,
    key = keys.MOUSE5,      -- Mantener Mouse5
    range = 8192,         -- Máximo alcance
    target_bots = true,     -- Activado
    target_players = true,  -- Activado
    auto_hit = true,        -- Activado
    auto_hit_distance = 165
}

local function is_survivor_valid(local_player, player)
    if not player or not player:is_alive() then return false end
    if player:get_index() == local_player:get_index() then return false end
    if player:get_team() ~= 2 then return false end

    if player.is_incapacitated and player:is_incapacitated() then
        return false
    end

    local name = player:get_name() or ""
    local is_bot = name == "" or string.find(string.lower(name), "bot")

    if is_bot and not config.target_bots then return false end
    if not is_bot and not config.target_players then return false end

    return true
end

local function find_closest_survivor(local_player)
    if not local_player or not local_player:is_alive() then return nil, 0 end
    if local_player:get_team() ~= 3 then return nil, 0 end

    local eye_pos = local_player:get_eye_position()
    local best_target = nil
    local best_dist = config.range

    local max_clients = engine.get_max_clients()

    for i = 1, max_clients do
        local player = entity.get_by_index(i)

        if is_survivor_valid(local_player, player) then
            local origin = player:get_origin()
            local dist = vector.distance(eye_pos, origin)

            if dist < best_dist then
                best_dist = dist
                best_target = player
            end
        end
    end

    return best_target, best_dist
end

local function calc_angle(src, dst)
    local delta = vector.new(
        dst.x - src.x,
        dst.y - src.y,
        dst.z - src.z
    )

    local hyp = math.sqrt(delta.x * delta.x + delta.y * delta.y)
    if hyp < 0.001 then hyp = 0.001 end

    local pitch = math.deg(math.atan2(-delta.z, hyp))
    local yaw = math.deg(math.atan2(delta.y, delta.x))

    return vector.new(pitch, yaw, 0)
end

local function normalize_angle(angle)
    while angle > 180 do angle = angle - 360 end
    while angle < -180 do angle = angle + 360 end
    return angle
end

function on_create_move(cmd, local_player)
    if not config.enabled then return end
    if not local_player or not local_player:is_alive() then return end
    if not engine.is_in_game() then return end
    if local_player:get_team() ~= 3 then return end

    -- Mouse5 mantenido
    if not input.is_key_down(config.key) then
        return
    end

    local target, dist = find_closest_survivor(local_player)
    if not target then return end

    local eye_pos = local_player:get_eye_position()
    local target_pos = target:get_origin()

    target_pos = vector.new(
        target_pos.x,
        target_pos.y,
        target_pos.z + 45
    )

    local angles = calc_angle(eye_pos, target_pos)

    angles.x = normalize_angle(
        math.max(-89, math.min(89, angles.x))
    )

    angles.y = normalize_angle(angles.y)

    cmd:set_viewangles(angles)
    engine.set_view_angles(angles)

    if config.auto_hit and dist <= config.auto_hit_distance then
        local max_hp = local_player:get_max_health() or 0

        if max_hp >= 3000 then
            local buttons = cmd:get_buttons()
            cmd:set_buttons(buttons | buttons.IN_ATTACK)
        end
    end
end


