local function PrintChat(msg)
    chat.print(msg)
end

local function get_player_name(idx)
    if not idx or idx <= 0 then return "Sconosciuto" end
    local info = engine.get_player_info(idx)
    if info then return info.name end
    return "Sconosciuto"
end

function on_game_event(event_name, event)
    if not event then return end

    if event_name == "player_death" then
        local victim_idx   = engine.get_player_for_userid(event:get_int("userid"))
        local attacker_idx = engine.get_player_for_userid(event:get_int("attacker"))
        local weapon       = event:get_string("weapon")
        local headshot     = event:get_bool("headshot")

        local victim_name   = get_player_name(victim_idx)
        local attacker_name = get_player_name(attacker_idx)

        local msg
        if headshot then
            msg = "\x04" .. attacker_name ..
                  "\x01 ha ucciso " ..
                  "\x03" .. victim_name ..
                  "\x01 con " ..
                  "\x05" .. weapon ..
                  "\x04 (HEADSHOT)"
        else
            msg = "\x04" .. attacker_name ..
                  "\x01 ha ucciso " ..
                  "\x03" .. victim_name ..
                  "\x01 con " ..
                  "\x05" .. weapon
        end

        PrintChat(msg)
    end
end

events.register("player_death")
events.register("infected_death")
