-- ============================================================================
-- L4D2 AUTOMATED CHARGER LEVELING ENGINE (ENGINE-SYNCED NETCODE)
-- ============================================================================

if client.get_shared_bool("autocut_enabled", nil) == nil then
    client.set_shared_bool("autocut_enabled", false)
    client.set_shared_bool("autocut_should_attack", false)
    
    -- Melee structural settings
    client.set_shared_float("autocut_base_delay", 0.15)   -- Melee attack trace windup constant (e.g., Fireaxe/Machete)
    client.set_shared_float("autocut_tongue_speed", 500.0) -- Base Charger movement speed profile (units per second)
    
    client.set_shared_float("autocut_last_attack_time", 0.0)
    client.set_shared_int("autocut_smoker_index", -1)
    client.set_shared_bool("autocut_debug", false)
end

function on_game_event(event_name, event)
    if not event then return end
    
    -- Detect when a Charger initiates its charge trajectory sequence
    if event_name == "ability_use" then
        local ability = event:get_string("ability")
        
        if ability == "ability_charge" then
            local enabled = client.get_shared_bool("autocut_enabled", false)
            if enabled then
                local user_id = event:get_int("userid")
                local charger_index = engine.get_player_for_userid(user_id)
                local gv = get_global_vars()
                
                client.set_shared_bool("autocut_should_attack", true)
                client.set_shared_int("autocut_smoker_index", charger_index) -- Maintain shared name slot for system safety
                
                if gv then
                    client.set_shared_float("autocut_last_attack_time", gv.curtime)
                end
                
                if client.get_shared_bool("autocut_debug", false) then
                    chat.print("[AutoLevel] Charger rush detected! Index: " .. charger_index, 0)
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
        if not gv then return end
        
        local current_time = gv.curtime
        local last_attack_time = client.get_shared_float("autocut_last_attack_time", 0.0)
        
        local swing_delay = client.get_shared_float("autocut_base_delay", 0.15)
        local charger_speed = client.get_shared_float("autocut_tongue_speed", 500.0)
        
        local calculated_delay = 0.1
        local charger_index = client.get_shared_int("autocut_smoker_index", -1)
        local distance = 0
        local time_since_event = current_time - last_attack_time

        if time_since_event > 5.0 or time_since_event < 0 then
             client.set_shared_bool("autocut_should_attack", false)
             return
        end
        
        if charger_index > 0 then
            local charger = entity.get_by_index(charger_index)
            if charger and charger:is_alive() then
                local eye_pos = local_player:get_eye_position()
                local charger_pos = charger:get_origin()
                distance = vector.distance(eye_pos, charger_pos)
                
                -- --- ADVANCED ENGINE LATEST PING COMPENSATION MATRIX ---
                local outgoing_latency = 0.0
                local incoming_latency = 0.0
                
                -- Interrogate the network engine channel directly for real-time traffic speeds
                local net_channel = engine.get_net_channel_info()
                if net_channel then
                    outgoing_latency = net_channel:get_latency(0) -- Outbound transmission travel time
                    incoming_latency = net_channel:get_latency(1) -- Inbound transmission travel time
                end
                
                -- Extract active client lerp buffer setting (cl_interp default fallback is 0.06s)
                local current_lerp = client.get_cvar_float("cl_interp") or 0.060
                
                -- Total network delay timeline footprint
                local total_network_latency = outgoing_latency + incoming_latency + current_lerp
                
                -- Total required timeline compensation window (Weapon Windup + Total Network Latency)
                local continuous_delay_target = swing_delay + total_network_latency
                
                -- Quantize timeline window to synchronize perfectly with server tick boundaries
                local tick_interval = gv.interval_per_tick or 0.01
                local quantized_ticks = math.floor((continuous_delay_target / tick_interval) + 0.5)
                local exact_engine_latency_compensation = quantized_ticks * tick_interval
                
                -- Determine physical distance to strike window threshold (100 units max melee reach)
                local distance_to_strike_zone = distance - 100.0
                if distance_to_strike_zone = calculated_delay then
            local current_buttons = cmd:get_buttons()
            cmd:set_buttons(current_buttons | buttons.IN_ATTACK)
            
            client.set_shared_bool("autocut_should_attack", false)
            client.set_shared_int("autocut_smoker_index", -1)
            
            if client.get_shared_bool("autocut_debug", false) then
                chat.print("[AutoLevel] LEVEL SWING EXECUTED AT " .. string.format("%.3f", time_since_event), 0)
            end
        end
    end
end

-- --- MENU INTERFACE LAYOUT STRUCTURE ---
menu.add_sub_tab("Aimbot", "Auto Level Charger", function()
    local changed, new_val
    
    imgui.separator()
    imgui.text_colored(1.0, 0.4, 0.4, 1.0, "Auto Level: Engine Prediction Mode")
    imgui.separator()
    
    changed, new_val = imgui.checkbox("Enable Auto Level", client.get_shared_bool("autocut_enabled", false))
    if changed then client.set_shared_bool("autocut_enabled", new_val) end
    
    changed, new_val = imgui.checkbox("Debug Engine Metrics", client.get_shared_bool("autocut_debug", false))
    if changed then client.set_shared_bool("autocut_debug", new_val) end
    
    imgui.spacing()
    imgui.text_colored(0.7, 0.7, 1.0, 1.0, "Physical Velocity & Animation Configurations")
    imgui.separator()
    
    changed, new_val = imgui.slider_float("Weapon Swing Windup (s)", client.get_shared_float("autocut_base_delay", 0.15), 0.0, 0.5)
    if changed then client.set_shared_float("autocut_base_delay", new_val) end

    changed, new_val = imgui.slider_float("Charger Speed (u/s)", client.get_shared_float("autocut_tongue_speed", 500.0), 300.0, 1000.0)
    if changed then client.set_shared_float("autocut_tongue_speed", new_val) end
    
    imgui.spacing()
    imgui.separator()
    
    imgui.text_colored(0.5, 0.5, 0.5, 1.0, "Engine Realtime Latency Diagnostics:")
    
    local net_channel = engine.get_net_channel_info()
    local out_p = net_channel and net_channel:get_latency(0) or 0.0
    local in_p = net_channel and net_channel:get_latency(1) or 0.0
    local lrp = client.get_cvar_float("cl_interp") or 0.060
    
    imgui.text_colored(0.7, 0.7, 0.7, 1.0, string.format("Outbound Latency (Ping): %.1f ms", out_p * 1000))
    imgui.text_colored(0.7, 0.7, 0.7, 1.0, string.format("Inbound Latency (Ping):  %.1f ms", in_p * 1000))
    imgui.text_colored(0.7, 0.7, 0.7, 1.0, string.format("Client Interpolation:    %.1f ms", lrp * 1000))
    
    imgui.spacing()
    imgui.text("Engine namespace automatically manages your network delay offsets dynamically.")
end)
