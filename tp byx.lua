-- RollExploit / TP (ByxStorm) → Heaven
-- Hold KEY_X → escribe el magic roll 0x7CF4CF42 en viewangles.z

local KEY = keys.KEY_X
local MAGIC_INT = 2096152002  -- 0x7CF4CF42

local magic_roll = 1.017900337e37  -- fallback float

do
    local ok, ffi = pcall(require, "ffi")
    if ok and ffi then
        local buf = ffi.new("int32_t[1]", MAGIC_INT)
        magic_roll = ffi.cast("float*", buf)[0]
    end
end

function on_create_move(cmd, local_player)
    if not cmd then return end
    if not input.is_key_down(KEY) then return end

    local angles = cmd:get_viewangles()
    if not angles then return end

    angles.z = magic_roll
    cmd:set_viewangles(angles)
end