local config = {
    enabled = true,
    aimkey = keys.MOUSE5,
    fov = 180.0,
    smooth = 1.0,
    target_head = true,
   -- max_distance = 8192,
    max_distance = 8192,
    silent_aim = false,
}

local function calcAngle(src, dst)
    local delta = vector.new(
        dst.x - src.x,
        dst.y - src.y,
        dst.z - src.z
    )
    
    local hyp = math.sqrt(delta.x * delta.x + delta.y * delta.y)
    
    local pitch = math.deg(math.atan2(-delta.z, hyp))
    local yaw = math.deg(math.atan2(delta.y, delta.x))
    
    return vector.new(pitch, yaw, 0)
end

local function normalizeAngle(angle)
    while angle > 180 do angle = angle - 360 end
    while angle < -180 do angle = angle + 360 end
    return angle
end

local function getFOV(viewAngles, aimAngles)
    local delta = vector.new(
        normalizeAngle(aimAngles.x - viewAngles.x),
        normalizeAngle(aimAngles.y - viewAngles.y),
        0
    )
    
    return math.sqrt(delta.x * delta.x + delta.y * delta.y)
end

local function smoothAngles(current, target, smooth)
    local delta = vector.new(
        normalizeAngle(target.x - current.x),
        normalizeAngle(target.y - current.y),
        0
    )
    
    local smoothFactor = 1.0 / smooth
    
    return vector.new(
        current.x + delta.x * smoothFactor,
        current.y + delta.y * smoothFactor,
        0
    )
end

local function getBestTarget(localPlayer)
    local eyePos = localPlayer:get_eye_position()
    local viewAngles = localPlayer:get_eye_angles()
    
    local bestTarget = nil
    local bestFov = config.fov
    local localIndex = localPlayer:get_index()
    
    local maxEntities = engine.get_max_clients()
    
    for i = 1, maxEntities do
        local player = entity.get_by_index(i)
        
        if not player then
            goto continue
        end

        if i == localIndex then
            goto continue
        end
        if not player:is_alive() then
            goto continue
        end
        
        local team = player:get_team()
        
        if team ~= 2 then
            goto continue
        end
        
        if player:is_incapacitated() then
            goto continue
        end
        
        local targetPos = player:get_origin()
        local distance = vector.distance(eyePos, targetPos)
        if distance > config.max_distance then
            goto continue
        end
        
        local aimPos = targetPos
        if config.target_head then
            aimPos = player:get_eye_position()
        end
        
        local aimAngle = calcAngle(eyePos, aimPos)
        local fov = getFOV(viewAngles, aimAngle)

        if fov < bestFov then
            bestFov = fov
            bestTarget = {
                player = player,
                aimPos = aimPos,
                aimAngle = aimAngle,
                distance = distance,
                fov = fov
            }
        end
        
        ::continue::
    end
    
    return bestTarget
end

function on_create_move(cmd, local_player)
    if not config.enabled then return end
    if not local_player or not local_player:is_alive() then return end
    if not engine.is_in_game() then
    return
end

    local team = local_player:get_team()
    if team ~= 3 then return end
    
    if not input.is_key_down(config.aimkey) then return end
    
    local target = getBestTarget(local_player)
    if not target then return end
    
    local currentAngles = cmd:get_viewangles()
    local targetAngles = target.aimAngle
    
    local finalAngles = currentAngles
    if config.smooth > 0 then
        finalAngles = smoothAngles(currentAngles, targetAngles, config.smooth)
    else
        finalAngles = targetAngles
    end
    
    finalAngles.x = normalizeAngle(finalAngles.x)
    finalAngles.y = normalizeAngle(finalAngles.y)
    
    cmd:set_viewangles(finalAngles)
    
    if not config.silent_aim then
        engine.set_view_angles(finalAngles)
    end
end
