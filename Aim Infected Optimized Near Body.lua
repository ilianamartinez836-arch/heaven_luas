
local config = {
    enabled = true,
    aimkey = keys.MOUSE5,
    max_distance = 8192,
    smooth = 1.0,
    silent_aim = false,
}

-- Cache por tick
local cache = {
    eye_pos = nil,
    view_angles = nil,
    local_index = 0,
    local_team = 0,
    last_tick = 0
}

local function calcAngle(src, dst)
    local dx = dst.x - src.x
    local dy = dst.y - src.y
    local dz = dst.z - src.z
    local hyp = math.sqrt(dx*dx + dy*dy)
    if hyp < 0.001 then hyp = 0.001 end
    return vector.new(
        math.deg(math.atan2(-dz, hyp)),
        math.deg(math.atan2(dy, dx)),
        0
    )
end

local function normalizeAngle(angle)
    while angle > 180 do angle = angle - 360 end
    while angle < -180 do angle = angle + 360 end
    return angle
end

local function smoothAngles(current, target, smooth)
    if smooth <= 0 then return target end
    local dx = normalizeAngle(target.x - current.x)
    local dy = normalizeAngle(target.y - current.y)
    local factor = 1.0 / smooth
    return vector.new(
        normalizeAngle(current.x + dx * factor),
        normalizeAngle(current.y + dy * factor),
        0
    )
end

local function getBestTarget(local_player)
    if not local_player then return nil end

    local current_tick = client.get_tick_count()
    if cache.last_tick ~= current_tick then
        cache.eye_pos = local_player:get_eye_position()
        cache.view_angles = local_player:get_eye_angles()
        cache.local_index = local_player:get_index()
        cache.local_team = local_player:get_team()
        cache.last_tick = current_tick
    end

    local bestTarget = nil
    local bestDistance = config.max_distance

    for i = 1, engine.get_max_clients() do
        if i == cache.local_index then goto continue end

        local player = entity.get_by_index(i)
        if not player or not player:is_alive() then goto continue end
        if player:get_team() ~= 2 then goto continue end
        if player:is_incapacitated() then goto continue end

        local origin = player:get_origin()
        local distance = vector.distance(cache.eye_pos, origin)

        if distance < bestDistance then
            -- Apuntar al PECHO (ajustado)
            local aimPos = vector.new(origin.x, origin.y, origin.z + 48)  -- Pecho

            local aimAngle = calcAngle(cache.eye_pos, aimPos)

            bestDistance = distance
            bestTarget = {
                aimAngle = aimAngle,
                distance = distance
            }
        end

        ::continue::
    end

    return bestTarget
end

function on_create_move(cmd, local_player)
    if not config.enabled then return end
    if not local_player or not local_player:is_alive() then return end
    if not engine.is_in_game() then return end
    if local_player:get_team() ~= 3 then return end

    if not input.is_key_down(config.aimkey) then return end

    local target = getBestTarget(local_player)
    if not target then return end

    local currentAngles = cmd:get_viewangles()
    local finalAngles = config.smooth > 0 
        and smoothAngles(currentAngles, target.aimAngle, config.smooth) 
        or target.aimAngle

    finalAngles.x = normalizeAngle(finalAngles.x)
    finalAngles.y = normalizeAngle(finalAngles.y)

    cmd:set_viewangles(finalAngles)

    if not config.silent_aim then
        engine.set_view_angles(finalAngles)
    end
end
