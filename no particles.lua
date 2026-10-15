local particles_off = false

function on_create_move(cmd, local_player)
    if not input.is_key_pressed(keys.KEY_K) then
        return
    end

    particles_off = not particles_off

    local ptr = cvar.find("r_drawparticles")
    if ptr and ptr ~= 0 then
        cvar.set_int(ptr, particles_off and 0 or 1)
    else
        client.exec("r_drawparticles " .. (particles_off and "0" or "1"))
    end

    client.print("[Particles] " .. (particles_off and "OFF" or "ON"))
end

