-- made by aika, important things are commented
-- you can add lag compensation Fully by using the engine namespace
-- for reading the user ping and etc
if client.get_shared_bool("autocut_enabled", nil) == nil then
    client.set_shared_bool("autocut_enabled", false)
    client.set_shared_bool("autocut_should_attack", false)
    
    client.set_shared_float("autocut_base_delay", 0.05)   -- Constant reaction time (lag compensation)
    client.set_shared_float("autocut_tongue_speed", 1000.0)
    
    client.set_shared_float("autocut_last_attack_time", 0.0)
    client.set_shared_int("autocut_smoker_index", -1)
    client.set_shared_bool("autocut_debug", false)
end

function on_game_event(event_name, event)
    if not event then return end
    
    if event_name == "ability_use" then
        local ability = event:get_string("ability")
        
        if ability == "ability_tongue" then
            local enabled = client.get_shared_bool("autocut_enabled", false)
            if enabled then
                local user_id = event:get_int("userid")
                local smoker_index = engine.get_player_for_userid(user_id)
                local gv = get_global_vars()
                
                client.set_shared_bool("autocut_should_attack", true)
                client.set_shared_int("autocut_smoker_index", smoker_index)
                
                if gv then
                    client.set_shared_float("autocut_last_attack_time", gv.curtime)
                end
                
                if client.get_shared_bool("autocut_debug", false) then
                    chat.print("[AutoCut] Tongue detected! Index: " .. smoker_index, 0)
                end
            end
        end
    end
end

function on_create_move_prediction(cmd, local_player)
    if not cmd or not local_player then return end
    if not local_player:is_alive() then return end
    if not engine.is_in_game() then return end
    if local_player:get_team() ~= 2 then return end
    
    local enabled = client.get_shared_bool("autocut_enabled", false)
    if not enabled then return end
    
    local should_attack = client.get_shared_bool("autocut_should_attack", false)
    
    if should_attack then
        local gv = get_global_vars()
        local current_time = gv.curtime
        local last_attack_time = client.get_shared_float("autocut_last_attack_time", 0.0)
        
        local base_delay = client.get_shared_float("autocut_base_delay", 0.05)
        local tongue_speed = client.get_shared_float("autocut_tongue_speed", 1000.0)
        
        local calculated_delay = 0.5 -- Safe default
        local smoker_index = client.get_shared_int("autocut_smoker_index", -1)
        local distance = 0
        local time_since_event = current_time - last_attack_time

        -- Sanity Check, can remove but i dont recommend
        if time_since_event > 5.0 or time_since_event < 0 then
             client.set_shared_bool("autocut_should_attack", false)
             return
        end
        
        if smoker_index > 0 then
            local smoker = entity.get_by_index(smoker_index)
            if smoker and smoker:is_alive() then
                local eye_pos = local_player:get_eye_position()
                local smoker_pos = smoker:get_origin()
                distance = vector.distance(eye_pos, smoker_pos)
                
                -- Base Reaction + (Distance / Speed)
                -- Example: 478 dist / 1000 speed = 0.478s travel time.
                calculated_delay = base_delay + (distance / tongue_speed)
            else
                client.set_shared_bool("autocut_should_attack", false)
                return
            end
        end
        
        if client.get_shared_bool("autocut_debug", false) then
             -- Only print debug every few frames to reduce spam, or just before shooting
            if math.abs(time_since_event - calculated_delay) < 0.05 then
                chat.print(string.format("[AutoCut] Dist: %.0f | Calc Delay: %.3fs (Travel: %.2f)", distance, calculated_delay, (distance/tongue_speed)), 0)
            end
        end
        
        if time_since_event >= calculated_delay then
            local current_buttons = cmd:get_buttons()
            cmd:set_buttons(current_buttons | buttons.IN_ATTACK)
            
            client.set_shared_bool("autocut_should_attack", false)
            client.set_shared_int("autocut_smoker_index", -1)
            
            if client.get_shared_bool("autocut_debug", false) then
                chat.print("[AutoCut] SHOT FIRED at " .. string.format("%.3f", time_since_event), 0)
            end
        end
    end
end

menu.add_sub_tab("Aimbot", "Auto Cut Tongue", function()
    local changed, new_val
    
    imgui.separator()
    imgui.text_colored(1.0, 0.4, 0.4, 1.0, "Auto Cut: Velocity Mode")
    imgui.separator()
    
    changed, new_val = imgui.checkbox("Enable Auto Cut", client.get_shared_bool("autocut_enabled", false))
    if changed then client.set_shared_bool("autocut_enabled", new_val) end
    
    changed, new_val = imgui.checkbox("Debug Mode", client.get_shared_bool("autocut_debug", false))
    if changed then client.set_shared_bool("autocut_debug", new_val) end
    
    imgui.spacing()
    imgui.text_colored(0.7, 0.7, 1.0, 1.0, "Physics Settings")
    imgui.separator()
    
    changed, new_val = imgui.slider_float("Base Reaction (s)", client.get_shared_float("autocut_base_delay", 0.05), 0.0, 0.5)
    if changed then client.set_shared_float("autocut_base_delay", new_val) end

    changed, new_val = imgui.slider_float("Tongue Speed (u/s)", client.get_shared_float("autocut_tongue_speed", 1000.0), 500.0, 2000.0)
    if changed then client.set_shared_float("autocut_tongue_speed", new_val) end
    
    imgui.spacing()
    imgui.separator()
    
    imgui.text_colored(0.5, 0.5, 0.5, 1.0, "Calculated Delays:")
    local base = client.get_shared_float("autocut_base_delay", 0.05)
    local speed = client.get_shared_float("autocut_tongue_speed", 1000.0)
    
    local function calc(dist)
        return base + (dist / speed)
    end
    
    imgui.text_colored(0.7, 0.7, 0.7, 1.0, string.format("280 units: %.3fs (Your close range)", calc(280)))
    imgui.text_colored(0.7, 0.7, 0.7, 1.0, string.format("478 units: %.3fs (Your far range)", calc(478)))
    imgui.text_colored(0.7, 0.7, 0.7, 1.0, string.format("750 units: %.3fs (Max range)", calc(750)))
    
    imgui.spacing()
    imgui.text("If shots are too FAST (early), INCREASE Base Reaction.")
    imgui.text("If shots are too SLOW (late), DECREASE Base Reaction.")
end)

events.register("ability_use")
