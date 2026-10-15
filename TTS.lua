ffi.cdef[[
    void tts_speak(const char* text);
    void tts_stop(void);
]]

local ok, tts = pcall(ffi.load, "tts_dll")
if not ok then
    client.print("[TTS] Failed to load tts_dll.dll: " .. tostring(tts))
    return
end

client.print("[TTS] ready")

function on_game_event(event_name, event)
    if event_name ~= "player_say" then return end

    local user_id    = event:get_int("userid")
    local text       = event:get_string("text")
    local entity_idx = engine.get_player_for_userid(user_id)
    if entity_idx <= 0 then return end

    local info = engine.get_player_info(entity_idx)
    if not info then return end

    local spoken = info.name .. " says " .. text
    client.print("[TTS] >> " .. spoken)
    pcall(function() tts.tts_speak(spoken) end)
end

function on_unload()
    pcall(function() tts.tts_stop() end)
    client.print("[TTS] unloaded")
end

events.register("player_say")