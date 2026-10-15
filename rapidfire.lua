local uwusite = {
    extra_cmds = 50
}
local hold_key_active = false

function on_cl_move_pre()


   local local_player = client.get_local_player()
    if not local_player then
        return
    end
    hold_key_active = input.is_key_down(keys.KEY_F)
    
    if hold_key_active then
        local engine_base = modules.get_engine_base()

    local ptr1 = memory.read_int(engine_base + 4352236)

    local network_channel = memory.read_int(ptr1 + 24)

    memory.write_int(network_channel + 16, -1, false)
    memory.write_int(network_channel + 28, 255, false)

    client.set_extra_commands(uwusite.extra_cmds)
end

end
