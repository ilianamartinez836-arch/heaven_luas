local name_stealer = {
    names = {},
    current_index = 1,
    next_change_time = 0.0,
    spoof_init = false,
    was_enabled = false,
    was_in_game = false,
    mode = 3, -- 1 = Everyone, 2 = Enemies, 3 = Teammates
    enabled = false,
    cooldown = 2.0
}
local function get_curtime()
    return client.get_tick_count() * client.get_frame_time()
end

local function refresh_names(local_player)
    name_stealer.names = {}
    
    if not local_player then
        return
    end
    
    local local_team = local_player:get_team()
    local local_index = local_player:get_index()
    
    local max_clients = engine.get_max_clients()
    for i = 1, max_clients do
        local player = entity.get_by_index(i)
        
        if player and player:get_index() ~= local_index then
            local pname = player:get_name()
            
            if pname and pname ~= "" and pname ~= "unknown" then
                local other_team = player:get_team()
                
                local should_add = false
                if name_stealer.mode == 1 then
                    should_add = true
                elseif name_stealer.mode == 2 then
                    should_add = (local_team ~= other_team)
                elseif name_stealer.mode == 3 then
                    should_add = (local_team == other_team)
                end
                
                if should_add then
                    table.insert(name_stealer.names, pname)
                end
            end
        end
    end
end

function on_create_move(cmd, local_player)
    if not cmd or not local_player then
        return
    end
    
    name_stealer.enabled = client.get_shared_bool("namesteal_enabled", false)
    
    if not name_stealer.enabled then
        if name_stealer.was_enabled then
            name_stealer.names = {}
            name_stealer.current_index = 1
            name_stealer.next_change_time = 0.0
            name_stealer.spoof_init = false
            name_stealer.was_enabled = false
        end
        return
    end
    
    local in_game = engine.is_in_game()
    
    if not name_stealer.was_enabled or (name_stealer.was_in_game ~= in_game) then
        name_stealer.names = {}
        name_stealer.current_index = 1
        name_stealer.next_change_time = 0.0
        name_stealer.spoof_init = false
        name_stealer.was_enabled = true
        name_stealer.was_in_game = in_game
    end
    
    if not in_game then
        return
    end
        -- this thing is ported from hannibal so this is not needed
    if not name_stealer.spoof_init then
        client.execnormal("setinfo name \"​\"")
        name_stealer.spoof_init = true
        name_stealer.next_change_time = get_curtime() + 2.0
        return
    end
    if #name_stealer.names == 0 then
        refresh_names(local_player)
        if #name_stealer.names == 0 then
            return
        end
    end
    
    local current_time = get_curtime()
    
    if current_time >= name_stealer.next_change_time then
        if name_stealer.current_index > #name_stealer.names then
            name_stealer.current_index = 1
        end
        
        local new_name = name_stealer.names[name_stealer.current_index]
        
        local spoofed = "​" .. new_name
        
        client.execnormal('setinfo name "' .. spoofed .. '"')
        
        name_stealer.current_index = name_stealer.current_index + 1
        name_stealer.next_change_time = current_time + name_stealer.cooldown
    end
end

local function steal_once()
    if not engine.is_in_game() then
        return
    end
    
    local local_player = client.get_local_player()
    if not local_player or not local_player:is_alive() then
        return
    end
    
    local candidates = {}
    local local_team = local_player:get_team()
    local local_index = local_player:get_index()
    
    local max_clients = engine.get_max_clients()
    for i = 1, max_clients do
        if i ~= local_index then
            local player = entity.get_by_index(i)
            
            if player then
                local pname = player:get_name()
                
                if pname and pname ~= "" and pname ~= "unknown" then
                    local other_team = player:get_team()
                    
                    local should_add = false
                    if name_stealer.mode == 1 then
                        should_add = true
                    elseif name_stealer.mode == 2 then
                        should_add = (local_team ~= other_team)
                    elseif name_stealer.mode == 3 then
                        should_add = (local_team == other_team)
                    end
                    
                    if should_add then
                        table.insert(candidates, pname)
                    end
                end
            end
        end
    end
    
    if #candidates > 0 then
        local random_name = candidates[math.random(1, #candidates)]
        local spoofed = "​" .. random_name
        client.execnormal('setinfo name "' .. spoofed .. '"')
    else
    end
end


function on_create_move(cmd, local_player)
    if input.is_key_pressed(keys.HOME) then
        name_stealer.enabled = not name_stealer.enabled
        client.set_shared_bool("namesteal_enabled", name_stealer.enabled)
        client.print("[Name Stealer] " .. (name_stealer.enabled and "Enabled" or "Disabled"))
    end
    
    if input.is_key_pressed(keys.END) then
        steal_once()
    end
    
    if not cmd or not local_player or not local_player:is_alive() then
        return
    end
    
    name_stealer.enabled = client.get_shared_bool("namesteal_enabled", false)
    
    if not name_stealer.enabled then
        if name_stealer.was_enabled then
            name_stealer.names = {}
            name_stealer.current_index = 1
            name_stealer.next_change_time = 0.0
            name_stealer.spoof_init = false
            name_stealer.was_enabled = false
        end
        return
    end
    
    local in_game = engine.is_in_game()
    
    if not name_stealer.was_enabled or (name_stealer.was_in_game ~= in_game) then
        name_stealer.names = {}
        name_stealer.current_index = 1
        name_stealer.next_change_time = 0.0
        name_stealer.spoof_init = false
        name_stealer.was_enabled = true
        name_stealer.was_in_game = in_game
    end
    
    if not in_game then
        return
    end
    -- is it my idea or is createmove repeated, idk it works so if it works dont touch it
    if not name_stealer.spoof_init then
      --  client.execnormal("setinfo name \"​\"")
        name_stealer.spoof_init = true
        name_stealer.next_change_time = get_curtime() + 2.0
        return
    end
    
    if #name_stealer.names == 0 then
        refresh_names(local_player)
        if #name_stealer.names == 0 then
            return
        end
    end
    
    local current_time = get_curtime()
    
    if current_time >= name_stealer.next_change_time then
        if name_stealer.current_index > #name_stealer.names then
            name_stealer.current_index = 1
        end
        
        local new_name = name_stealer.names[name_stealer.current_index]
        local spoofed = "​" .. new_name
        
        client.execnormal('setinfo name "' .. spoofed .. '"')
        
        name_stealer.current_index = name_stealer.current_index + 1
        name_stealer.next_change_time = current_time + name_stealer.cooldown
    end
end

client.print("[Name Stealer] Script loaded!")
client.print("[Name Stealer] Press HOME to toggle | END to steal once")


