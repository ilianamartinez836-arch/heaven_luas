--airstuck.lua
local uwusite = {
    enabled = true,
}
local hold_key_active = false

function on_create_move(cmd)
    if not uwusite.enabled then
        return
    end
    
    local local_player = client.get_local_player()
    if not local_player or not local_player:is_alive() then
        return
    end
    hold_key_active = input.is_key_down(keys.KEY_X)
    
    if hold_key_active then
       cmd:set_tickcount(0xFFFFFF)
	--ignore this shit, i was retarded, its from my own fucking api and still didnt called it correctly LO O LOLOLO LOL
	--	cmd:set_tickcount = 0xFFFFFF
	end
end
