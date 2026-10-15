-- autoshove_creator_no_imgui.lua - Auto Shove sin menú + silent del primer Lua + delay real
-- Arreglado para no giro loco (delay con curtime, solo shove cuando pase tiempo)

local PI = 3.14159

-- Helpers del creador
local function normalize_angle(angle)
    while angle > 180 do angle = angle - 360 end
    while angle < -180 do angle = angle + 360 end
    return angle
end

local function calc_angle(src, dst)
    local delta = vector.new(dst.x - src.x, dst.y - src.y, dst.z - src.z)
    local hyp = math.sqrt(delta.x^2 + delta.y^2)
    local pitch = math.deg(math.atan2(-delta.z, hyp))
    local yaw = math.deg(math.atan2(delta.y, delta.x))
    return vector.new(pitch, yaw, 0)
end

local function get_fov(view_angles, aim_angles)
    local dx = normalize_angle(aim_angles.x - view_angles.x)
    local dy = normalize_angle(aim_angles.y - view_angles.y)
    return math.sqrt(dx*dx + dy*dy)
end

-- Configuraciones predeterminadas al cargar
if client.get_shared_bool("as_enable", nil) == nil then
    client.set_shared_bool("as_enable", true)
    client.set_shared_float("as_range", 90.500)
    client.set_shared_float("as_delay", 0.027) -- segundos reales
    client.set_shared_bool("as_silent", true)
    client.set_shared_bool("as_legit", false)
    client.set_shared_bool("as_hunter", true)
    client.set_shared_bool("as_jockey", true)
    client.set_shared_bool("as_smoker", true)
    client.set_shared_bool("as_spitter", true)
    client.set_shared_bool("as_boomer", true)
end

-- Variables para delay real (como el primer Lua)
local last_shove_time = 0.0

function on_create_move_prediction(cmd, local_player)
    local enabled = client.get_shared_bool("as_enable", true)
    if not enabled or not local_player or not local_player:is_alive() or local_player:get_team() ~= 2 then return end
    
    local curtime = get_global_vars().curtime
    local delay = client.get_shared_float("as_delay", 0.027)
    
    -- Delay real (solo shove si pasó el tiempo)
    if curtime - last_shove_time < delay then return end
    
    local range = client.get_shared_float("as_range", 90.500)
    local silent = client.get_shared_bool("as_silent", true)
    local legit = client.get_shared_bool("as_legit", false)
    local eye_pos = local_player:get_eye_position()
    local view_angles = local_player:get_eye_angles()
    local buttons = cmd:get_buttons()
    
    local best_fov = math.huge
    local best_target = nil
    local max_entities = math.max(engine.get_max_clients(), 64)
    
    for i = 1, max_entities do
        local ent = entity.get_by_index(i)
        if ent and ent:get_index() ~= local_player:get_index() then
            local zclass = ent:get_zombie_class()
            if ent:is_alive() and ent:get_team() == 3 and not ent:is_ghost() and
               ((zclass == 3 and client.get_shared_bool("as_hunter", true)) or
                (zclass == 5 and client.get_shared_bool("as_jockey", true)) or
                (zclass == 1 and client.get_shared_bool("as_smoker", true)) or
                (zclass == 4 and client.get_shared_bool("as_spitter", true)) or
                (zclass == 2 and client.get_shared_bool("as_boomer", true))) then
                local target_pos = vector.new(ent:get_origin().x, ent:get_origin().y, ent:get_origin().z + 55)
                local dist = vector.distance(eye_pos, target_pos)
                if dist <= range then
                    local aim_angles = calc_angle(eye_pos, target_pos)
                    local this_fov = legit and get_fov(view_angles, aim_angles) or 0
                    if this_fov < best_fov then
                        best_fov = this_fov
                        best_target = ent
                    end
                end
            end
        end
    end
    
    if best_target then
        cmd:set_buttons(buttons | 2048) -- IN_ATTACK2
        last_shove_time = curtime  -- reset delay real
        
        local target_pos = vector.new(best_target:get_origin().x, best_target:get_origin().y, best_target:get_origin().z + 55)
        local aim_angles = calc_angle(eye_pos, target_pos)
        
        if silent then
            cmd:set_viewangles(aim_angles) -- Snap solo server-side (como el primer Lua)
            -- NO engine.set_view_angles → tu cámara no gira
        else
            cmd:set_viewangles(aim_angles)
            engine.set_view_angles(aim_angles) -- Snap completo
        end
    end
end

client.print("💀 Auto Shove cargado! (Enable ON + Silent ON + Targets ON + Range 90.500 + Delay 0.027)")
