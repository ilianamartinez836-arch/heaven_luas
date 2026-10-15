local function PrintChat(msg)
    client.print(msg)
    chat.print(msg)
end

local function get_player_name(idx)
    client.print("get_player_name() idx=" .. tostring(idx))

    if not idx or idx <= 0 then
        client.print("get_player_name() -> Unknown (invalid idx)")
        return "Unknown"
    end

    local info = engine.get_player_info(idx)
    client.print("get_player_name() engine.get_player_info(" .. tostring(idx) .. ") = " .. tostring(info ~= nil))

    if info then
        client.print("get_player_name() -> " .. tostring(info.name))
        return info.name
    end

    client.print("get_player_name() -> Unknown (no info)")
    return "Unknown"
end

function on_game_event(event_name, event)
    client.print("on_game_event() called, event_name=" .. tostring(event_name))

    if not event then
        client.print("on_game_event() -> event is nil")
        return
    end

    local local_player = client.get_local_player()
    client.print("on_game_event() local_player=" .. tostring(local_player ~= nil))

    if not local_player then
        client.print("on_game_event() -> no local player")
        return
    end

    local local_idx = local_player:get_index()
    client.print("on_game_event() local_idx=" .. tostring(local_idx))

    if event_name ~= "player_death" then
        client.print("on_game_event() -> ignoring non-player_death event")
        return
    end

    local attacker_userid = event:get_int("attacker")
    client.print("on_game_event() attacker_userid=" .. tostring(attacker_userid))

    local attacker_idx = engine.get_player_for_userid(attacker_userid)
    client.print("on_game_event() attacker_idx=" .. tostring(attacker_idx))

    if not attacker_idx or attacker_idx <= 0 then
        client.print("on_game_event() -> invalid attacker index")
        return
    end

    if attacker_idx ~= local_idx then
        client.print("on_game_event() -> not our kill, ignoring")
        return
    end

    local victim_userid = event:get_int("userid")
    client.print("on_game_event() victim_userid=" .. tostring(victim_userid))

    local victim_idx = engine.get_player_for_userid(victim_userid)
    client.print("on_game_event() victim_idx=" .. tostring(victim_idx))

    local victim_name = get_player_name(victim_idx)
    local attacker_name = get_player_name(attacker_idx)

    local weapon = event:get_string("weapon")
    client.print("on_game_event() weapon=" .. tostring(weapon))

    local headshot = event:get_bool("headshot")
    client.print("on_game_event() headshot=" .. tostring(headshot))

    local msg
    if headshot then
        msg = "\x04" .. attacker_name ..
              "\x01 killed " ..
              "\x03" .. victim_name ..
              "\x01 with " ..
              "\x05" .. weapon ..
              "\x04 (HEADSHOT)"
    else
        msg = "\x04" .. attacker_name ..
              "\x01 killed " ..
              "\x03" .. victim_name ..
              "\x01 with " ..
              "\x05" .. weapon
    end

    client.print("on_game_event() final msg=" .. tostring(msg))
    PrintChat(msg)
end

events.register("player_death")