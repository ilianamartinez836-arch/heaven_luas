local IN_ATTACK2 = 1 << 11
local static_tick_count = 0

function on_create_move(cmd)
    if not cmd then return end
    
    local local_player = client.get_local_player()
    if not local_player or not local_player:is_alive() then return end
    
    if local_player:get_team() ~= 3 then return end
    if local_player:get_zombie_class() ~= 8 then return end
--if local_player:get_zombie_class() ~= zombie_class.TANK then return end
    local current_buttons = cmd:get_buttons()

    if input.is_key_down(keys.MOUSE2) then
        static_tick_count = static_tick_count + 1

        if static_tick_count % 2 == 0 then
            cmd:set_buttons(current_buttons & ~IN_ATTACK2)
        else
            cmd:set_buttons(current_buttons | IN_ATTACK2)
        end
    else
        static_tick_count = 0
    end
end

