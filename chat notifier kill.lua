-- Kill Notifier
-- Shows "YourName killed VictimName with weapon" in chat

local config = {
    enabled = true,
    show_headshots = true,  -- Show (HEADSHOT) tag
    show_weapon = true,     -- Show weapon used
}

-- Register events
events.register("player_death")

function on_game_event(event_name, event)
    if not config.enabled then return end
    if event_name ~= "player_death" then return end
    
    local me = client.get_local_player()
    if not me then return end
    
    -- Get event data
    local attacker_id = event:get_int("attacker")
    local victim_id = event:get_int("userid")
    local weapon = event:get_string("weapon")
    local headshot = event:get_bool("headshot")
    
    -- Convert userid to entity index
    local attacker_index = engine.get_player_for_userid(attacker_id)
    local victim_index = engine.get_player_for_userid(victim_id)
    
    -- Check if I'm the attacker
    if attacker_index ~= me:get_index() then return end
    
    -- Get player names
    local attacker_info = engine.get_player_info(attacker_index)
    local victim_info = engine.get_player_info(victim_index)
    
    if not attacker_info or not victim_info then return end
    
    local my_name = attacker_info.name
    local victim_name = victim_info.name
    
    -- Build kill message
    local message = my_name .. " killed " .. victim_name
    
    if config.show_weapon then
        message = message .. " with " .. weapon
    end
    
    if config.show_headshots and headshot then
        message = message .. " (HEADSHOT)"
    end
    
    -- Print to chat
    chat.print(message)
    
    -- Also print to console
    client.print("[KILL] " .. message)
end

-- Menu
menu.add_main_tab("Kill Notifier", function()
    imgui.text("Kill Notifier Settings")
    imgui.separator()
    
    local changed, val = imgui.checkbox("Enable Kill Notifications", config.enabled)
    if changed then
        config.enabled = val
    end
    
    imgui.spacing()
    
    changed, val = imgui.checkbox("Show Weapon", config.show_weapon)
    if changed then
        config.show_weapon = val
    end
    
    changed, val = imgui.checkbox("Show Headshots", config.show_headshots)
    if changed then
        config.show_headshots = val
    end
    
    imgui.spacing()
    imgui.separator()
    imgui.spacing()
    
    imgui.text("Example outputs:")
    imgui.text("byx killed player with rifle_ak47")
    imgui.text("byx killed player with rifle_ak47 (HEADSHOT)")
    imgui.text("Rarita (mambaza) killed playeer with pistol")
end)

client.print("[Kill Notifier] Loaded!")
client.print("[Kill Notifier] Will show your kills in chat")

