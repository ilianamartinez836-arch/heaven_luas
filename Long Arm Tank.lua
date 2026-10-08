
local tlerp = {
    key = keys.MOUSE4,
    last_state = false
}

function on_create_move(cmd, local_player)
    if not local_player or not local_player:is_alive() then return end
    if local_player:get_team() ~= 3 then return end
    if local_player:get_zombie_class() ~= 8 then return end  -- Solo Tank

    local is_holding = input.is_key_down(tlerp.key)

    if is_holding and not tlerp.last_state then
        -- Al presionar MOUSE4
        client.execnormal("cl_interp 0.5")
        cmd:set_buttons(cmd:get_buttons() | buttons.IN_ATTACK)
        
    elseif not is_holding and tlerp.last_state then
        -- Al soltar MOUSE4
        client.execnormal("cl_interp 0.007813")
    end

    tlerp.last_state = is_holding
end

function on_unload()
    client.execnormal("cl_interp 0.007813")
    client.print("[Tank Lerp] Restored default interp")
end

client.print("[Tank Lerp] Loaded - Hold MOUSE4 cuando seas Tank")