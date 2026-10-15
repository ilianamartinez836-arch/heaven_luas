local config_spectators = {
    enabled = true,
    always_show = true,
    x_offset = 20,
    y_offset = 100,
    box_width = 220,
    item_height = 18,
    padding = 8,
    header_height = 24
}

local spectator_start_times = {}

local colors = {
    bg_primary = {0.063, 0.063, 0.075, 0.94},
    bg_secondary = {0.086, 0.086, 0.102, 0.94},
    border_main = {0.349, 0.467, 0.584, 1.0},
    accent = {0.349, 0.584, 0.510, 1.0},
    border_outline = {0.0, 0.0, 0.0, 0.63},
    text_white = {1.0, 1.0, 1.0, 1.0},
    text_gray = {0.549, 0.549, 0.588, 1.0},
    text_muted = {0.471, 0.471, 0.510, 1.0},
    text_dead = {1.0, 0.471, 0.471, 1.0},
    gradient_top = {1.0, 1.0, 1.0, 0.024},
    overlay_alt = {1.0, 1.0, 1.0, 0.024}
}

local function get_my_spectators()
    local spectators = {}
    
    if not engine.is_in_game() then
        return spectators
    end
    
    local local_player = client.get_local_player()
    if not local_player then
        return spectators
    end
    
    local local_index = local_player:get_index()
    local current_tick = client.get_tick_count()
    local current_time = current_tick * client.get_frame_time()
    
    local current_spectators = {}

    for i = 1, engine.get_max_clients() do
        if i ~= local_index then
            local player = entity.get_by_index(i)
            
            if player then
                local player_info = engine.get_player_info(i)
                
                if player_info then
                    local is_dead = not player:is_alive()
                    local observer_mode = player:get_observer_mode()
                    local observer_target = player:get_observer_target()
                    local team_num = player:get_team()
                    
                    local is_spectating = false
                    local is_spectating_me = false
                    
                    if observer_mode >= 4 and observer_mode <= 6 then
                        is_spectating = true
                    elseif is_dead and observer_mode > 0 then
                        is_spectating = true
                    end

                    if team_num == team.SPECTATOR then
                        is_spectating = true
                    end

                    if is_spectating and observer_target then
                        local target_index = observer_target:get_index()
                        if target_index == local_index then
                            is_spectating_me = true
                        end
                    end
                    
                    if is_spectating_me then
                        if not spectator_start_times[i] then
                            spectator_start_times[i] = current_time
                        end
                        
                        local spectate_time = current_time - spectator_start_times[i]
                        local minutes = math.floor(spectate_time / 60)
                        local seconds = math.floor(spectate_time % 60)

                        local spec_name = player_info.name
                        local time_str = string.format(" (%02d:%02d)", minutes, seconds)
                    --    local full_name = spec_name .. time_str
                    local full_name = spec_name
                        
                        if is_dead then
                            full_name = full_name .. " [DEAD]"
                        end
                        
                        table.insert(spectators, {
                            name = full_name,
                            is_dead = is_dead
                        })
                        
                        current_spectators[i] = true
                    end
                end
            end
        end
    end

    for idx, _ in pairs(spectator_start_times) do
        if not current_spectators[idx] then
            spectator_start_times[idx] = nil
        end
    end
    
    return spectators
end

local function draw_rounded_rect(x, y, w, h, color)
    draw.rect(x, y, w, h, color[1], color[2], color[3], color[4])
end

local function draw_rect_outline(x, y, w, h, color, thickness)
    thickness = thickness or 1
    draw.rect(x, y, w, thickness, color[1], color[2], color[3], color[4])
    draw.rect(x, y + h - thickness, w, thickness, color[1], color[2], color[3], color[4])
    draw.rect(x, y, thickness, h, color[1], color[2], color[3], color[4])
    draw.rect(x + w - thickness, y, thickness, h, color[1], color[2], color[3], color[4])
end

function on_end_scene()
    if not config_spectators.enabled then
        return
    end

    local spectators = get_my_spectators()

    if #spectators == 0 and not config_spectators.always_show then
        return
    end

    imgui.begin("##spectator_list", 0)
    -- Header
  --  local header_text = string.format("SPECTATORS [%d]", #spectators)
  --  imgui.text(header_text)
 --   imgui.separator()

    if #spectators == 0 then
        imgui.text_disabled("No spectators")
    else
        for i, spec in ipairs(spectators) do
            if i > 1 then
                imgui.spacing()
            end

            if spec.is_dead then
                imgui.text_colored(
                    colors.text_dead[1], colors.text_dead[2],
                    colors.text_dead[3], colors.text_dead[4],
                    spec.name
                )
            else
                imgui.text(spec.name)
            end
        end
    end

    imgui["end"]()
end


--function on_unload()
--    spectator_start_times = {}
--    client.print("Spectator List unloaded")
--end