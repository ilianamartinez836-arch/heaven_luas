if client.get_shared_bool("haymaker_enabled", nil) == nil then
    client.set_shared_bool("haymaker_enabled", false)
end

function on_create_move(cmd, local_player)
    if not cmd or not local_player then return end
    if not local_player:is_alive() then return end
    
    local enabled = client.get_shared_bool("haymaker_enabled", false)
    
    local is_tank = local_player:get_team() == 3 and local_player:get_zombie_class() == 8
    if not is_tank then return end
    
    if enabled and input.is_key_down(keys.MOUSE5) then
        local current_buttons = cmd:get_buttons()
        
        current_buttons = current_buttons | buttons.IN_ATTACK | buttons.IN_ATTACK2
        
        cmd:set_buttons(current_buttons)
    end
end

menu.add_sub_tab("Aimbot", "Hay-Maker", function()
    imgui.separator()

    local changed_enabled, val_enabled = imgui.checkbox("Haymaker Toggle", client.get_shared_bool("haymaker_enabled", false))
    if changed_enabled then client.set_shared_bool("haymaker_enabled", val_enabled) end

    imgui.separator()
    imgui.text("Bind: MOUSE5")
    
    imgui["end"]()
end)
