-- Aim Infected con Prioridad + Opción para incapacitados

local PRIORITY_NAME = "Rochelle"   -- <<<=== Cambia esto por el nombre que quieres priorizar

local config = {
    enabled = true,
    aimkey = keys.MOUSE5,
    smooth = 1.0,
    target_head = true,
    silent_aim = false,
    target_incapacitated = false,   -- <<<=== Cambia a false si NO quieres apuntar a incapacitados
}

local function calcAngle(src, dst)
    local delta = vector.new(dst.x - src.x, dst.y - src.y, dst.z - src.z)
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

local function smoothAngles(current, target, smooth)
    local delta = vector.new(normalizeAngle(target.x - current.x), normalizeAngle(target.y - current.y), 0)
    local smoothFactor = 1.0 / smooth
    return vector.new(current.x + delta.x * smoothFactor, current.y + delta.y * smoothFactor, 0)
end

function on_create_move(cmd, local_player)
    if not config.enabled or not local_player or not local_player:is_alive() then return end
    if not engine.is_in_game() or local_player:get_team() ~= 3 then return end
    if not input.is_key_down(config.aimkey) then return end

    local eyePos = local_player:get_eye_position()
    local bestTarget = nil

    -- 1. Primero intentamos apuntar al target prioritario
    for i = 1, engine.get_max_clients() do
        local player = entity.get_by_index(i)
        if not player or i == local_player:get_index() or not player:is_alive() then goto continue end
        if player:get_team() ~= 2 then goto continue end

        -- Solo consideramos al prioritario
        if player:get_name() == PRIORITY_NAME then
            -- Si no queremos apuntar a incapacitados y está down → lo saltamos
            if not config.target_incapacitated and player:is_incapacitated() then
                goto continue
            end

            local aimPos = config.target_head and player:get_eye_position() or player:get_origin()
            local aimAngle = calcAngle(eyePos, aimPos)

            bestTarget = { aimAngle = aimAngle }
            goto found_priority
        end

        ::continue::
    end

    ::found_priority::

    -- 2. Si no encontramos al prioritario (o está incapacitado y no queremos apuntarle), apuntamos al más cercano
    if not bestTarget then
        local bestDistance = 99999

        for i = 1, engine.get_max_clients() do
            local player = entity.get_by_index(i)
            if not player or i == local_player:get_index() or not player:is_alive() then goto continue2 end
            if player:get_team() ~= 2 then goto continue2 end

            local targetPos = player:get_origin()
            local distance = vector.distance(eyePos, targetPos)

            if distance < bestDistance then
                local aimPos = config.target_head and player:get_eye_position() or targetPos
                local aimAngle = calcAngle(eyePos, aimPos)

                bestDistance = distance
                bestTarget = { aimAngle = aimAngle }
            end

            ::continue2::
        end
    end

    if not bestTarget then return end

    local currentAngles = cmd:get_viewangles()
    local targetAngles = bestTarget.aimAngle
    local finalAngles = config.smooth > 0 and smoothAngles(currentAngles, targetAngles, config.smooth) or targetAngles

    finalAngles.x = normalizeAngle(finalAngles.x)
    finalAngles.y = normalizeAngle(finalAngles.y)

    cmd:set_viewangles(finalAngles)
    if not config.silent_aim then
        engine.set_view_angles(finalAngles)
    end
end

client.print("🔥 Aim Infected con Prioridad Cargado - Prioridad: " .. PRIORITY_NAME)





