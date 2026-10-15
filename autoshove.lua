--made by aika
if client.get_shared_bool("autoshove_enabled", nil) == nil then
    client.set_shared_bool("autoshove_enabled", false)
    client.set_shared_float("autoshove_range", 120.0)
    client.set_shared_float("autoshove_delay", 0.0)
    client.set_shared_bool("autoshove_silent", true)
    client.set_shared_bool("autoshove_legit", false)

    client.set_shared_bool("autoshove_target_hunter", true)
    client.set_shared_bool("autoshove_target_jockey", true)
    client.set_shared_bool("autoshove_target_smoker", true)
    client.set_shared_bool("autoshove_target_spitter", true)
    client.set_shared_bool("autoshove_target_boomer", true)
end

local zombie_names = {
    [1] = "Smoker",
    [2] = "Boomer",
    [3] = "Hunter",
    [4] = "Spitter",
    [5] = "Jockey"
}

local last_shove_time = 0

local function calc_angle(src, dst)
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

local function normalize_angle(angle)
    while angle > 180 do angle = angle - 360 end
    while angle < -180 do angle = angle + 360 end
    return angle
end

local function is_entity_behind_player(local_player, entity)
    local local_angles = local_player:get_eye_angles()
    local eye_pos = local_player:get_eye_position()
    local target_pos = entity:get_origin()
    
    local to_target = calc_angle(eye_pos, target_pos)
    
    local yaw_diff = normalize_angle(to_target.y - local_angles.y)
    
    return math.abs(yaw_diff) > 90
end

local function can_shove_now()
    local gv = get_global_vars()
    local current_time = gv.curtime
    local delay = client.get_shared_float("autoshove_delay", 0.5)

    if current_time - last_shove_time >= delay then
        last_shove_time = current_time
        return true
    end
    
    return false
end

local function is_target_enabled(z_class)
    local name = zombie_names[z_class]
    if not name then return false end
    local key = "autoshove_target_" .. name:lower()
    return client.get_shared_bool(key, false)
end

function on_create_move_prediction(cmd, local_player)
    if not cmd or not local_player then return end
    if not local_player:is_alive() then return end
    if not engine.is_in_game() then return end
    if local_player:get_team() ~= 2 then return end

    local enabled = client.get_shared_bool("autoshove_enabled", false)
    if not enabled then return end

    if not can_shove_now() then return end

    local range = client.get_shared_float("autoshove_range", 150.0)
    local silent = client.get_shared_bool("autoshove_silent", true)
    local legit_mode = client.get_shared_bool("autoshove_legit", false)

    local eye_pos = local_player:get_eye_position()
    local max_clients = engine.get_max_clients()
    
    for i = 1, max_clients do
        local entity = entity.get_by_index(i)
        
        if entity and entity:is_alive() and entity:get_team() == 3 then
            if not entity:is_ghost() then
                local z_class = entity:get_zombie_class()
                
                if is_target_enabled(z_class) then
                    local target_pos = entity:get_origin()
                    local dist = vector.distance(eye_pos, target_pos)
                    
                    if dist <= range then
                        if legit_mode then
                            if is_entity_behind_player(local_player, entity) then
                                goto continue
                            end
                            
                            local current_buttons = cmd:get_buttons()
                            cmd:set_buttons(current_buttons | buttons.IN_ATTACK2)
                        else
                            local aim_angles = calc_angle(eye_pos, entity:get_eye_position())
                            
                            cmd:set_viewangles(aim_angles)
                            
                            if not silent then
                                engine.set_view_angles(aim_angles)
                            end
                            
                            local current_buttons = cmd:get_buttons()
                            cmd:set_buttons(current_buttons | buttons.IN_ATTACK2)
                        end
                        
                        return
                    end
                end
            end
        end
        
        ::continue::
    end
end

menu.add_sub_tab("Aimbot", "AutoShove++", function()
    local changed, new_val
    
    imgui.separator()
    imgui.text_colored(1.0, 0.4, 0.4, 1.0, "Made by twilight")
    imgui.separator()
    
    changed, new_val = imgui.checkbox("Enable Auto Shove", client.get_shared_bool("autoshove_enabled", false))
    if changed then client.set_shared_bool("autoshove_enabled", new_val) end
    
    imgui.spacing()
    imgui.text_colored(0.7, 0.7, 1.0, 1.0, "General Settings")
    imgui.separator()
    
    changed, new_val = imgui.slider_float("Shove Range (units)", client.get_shared_float("autoshove_range", 120.0), 50.0, 300.0)
    if changed then client.set_shared_float("autoshove_range", new_val) end
    
    changed, new_val = imgui.slider_float("Shove Delay (seconds)", client.get_shared_float("autoshove_delay", 0.0), 0.0, 2.0)
    if changed then client.set_shared_float("autoshove_delay", new_val) end
    
    imgui.spacing()
    imgui.text_colored(0.7, 1.0, 0.7, 1.0, "Mode Settings")
    imgui.separator()
    
    changed, new_val = imgui.checkbox("Silent Shove", client.get_shared_bool("autoshove_silent", true))
    if changed then client.set_shared_bool("autoshove_silent", new_val) end
    imgui.same_line()
    imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(Hides angle snap)")
    
    changed, new_val = imgui.checkbox("Legit Auto Shove", client.get_shared_bool("autoshove_legit", false))
    if changed then client.set_shared_bool("autoshove_legit", new_val) end
    imgui.same_line()
    imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(No angle snap, front targets only)")
    
    imgui.spacing()
    imgui.text_colored(1.0, 1.0, 0.7, 1.0, "Target Selection")
    imgui.separator()
    
    changed, new_val = imgui.checkbox("Hunter", client.get_shared_bool("autoshove_target_hunter", false))
    if changed then client.set_shared_bool("autoshove_target_hunter", new_val) end
    
    changed, new_val = imgui.checkbox("Jockey", client.get_shared_bool("autoshove_target_jockey", false))
    if changed then client.set_shared_bool("autoshove_target_jockey", new_val) end
    
    changed, new_val = imgui.checkbox("Smoker", client.get_shared_bool("autoshove_target_smoker", false))
    if changed then client.set_shared_bool("autoshove_target_smoker", new_val) end
    
    changed, new_val = imgui.checkbox("Spitter", client.get_shared_bool("autoshove_target_spitter", false))
    if changed then client.set_shared_bool("autoshove_target_spitter", new_val) end
    
    changed, new_val = imgui.checkbox("Boomer", client.get_shared_bool("autoshove_target_boomer", false))
    if changed then client.set_shared_bool("autoshove_target_boomer", new_val) end
    
    imgui.spacing()
    imgui.separator()
    imgui.text_colored(0.5, 0.5, 0.5, 1.0, "Active Targets:")
    local active_names = {}
    if client.get_shared_bool("autoshove_target_hunter", false) then table.insert(active_names, "Hunter") end
    if client.get_shared_bool("autoshove_target_jockey", false) then table.insert(active_names, "Jockey") end
    if client.get_shared_bool("autoshove_target_smoker", false) then table.insert(active_names, "Smoker") end
    if client.get_shared_bool("autoshove_target_spitter", false) then table.insert(active_names, "Spitter") end
    if client.get_shared_bool("autoshove_target_boomer", false) then table.insert(active_names, "Boomer") end
    
    if #active_names > 0 then
        imgui.text_colored(0.7, 0.7, 0.7, 1.0, table.concat(active_names, ", "))
    else
        imgui.text_colored(0.8, 0.3, 0.3, 1.0, "None selected")
    end
end)