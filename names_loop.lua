local NAMES = {
    "Captain Price",
    "Ghost",
    "Soap",
    "Gaz",
    "Roach",
    "Nikolai",
    "Shepherd",
    "MacMillan",
    "Yuri",
    "Makarov"
}

local current_index = 1
local last_change_time = 0
local CHANGE_INTERVAL = 10.0

function on_paint()
    if not engine.is_in_game() then
        return
    end

    local local_player = client.get_local_player()
    if not local_player then
        return
    end

    local current_time = os.clock()

    if last_change_time == 0 then
        last_change_time = current_time
        return
    end

    if current_time - last_change_time >= CHANGE_INTERVAL then
        current_index = current_index + 1
        if current_index > #NAMES then
            current_index = 1
        end

        local new_name = NAMES[current_index]
        if new_name and new_name ~= "" then
            client.execnormal('setinfo name "' .. new_name .. '"')
        end

        last_change_time = current_time
    end
end


