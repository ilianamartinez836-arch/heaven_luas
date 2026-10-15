local uwusite = {
    enabled = true,
}
local hold_key_active = false

function on_create_move(cmd, local_player)
    if not uwusite.enabled then
        return
    end
    
    local local_player = client.get_local_player()
    if not local_player or not local_player:is_alive() then
        return
    end
    hold_key_active = input.is_key_down(keys.KEY_X)
    
    if hold_key_active then
		local angles = cmd:get_viewangles()
		angles.z = 1e+37
		cmd:set_viewangles(angles)
	end
end


