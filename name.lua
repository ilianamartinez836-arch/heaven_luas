local NAME_LENGTH = 8

local last_map = ""
local change_count = 0
local target_name = nil
local is_changing = false

local numpad4_was_pressed = false

math.randomseed(os.time())

local function generate_random_name(length)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local name = ""
    for i = 1, length do
        local rand = math.random(1, #chars)
        name = name .. string.sub(chars, rand, rand)
    end
    return name
end

local function get_map_name()
    if not engine.is_in_game() then
        return "Menu"
    end
    
    local map = engine.get_level_name_short()
    if map and map ~= "" then
        return map
    end
    
    return "Unknown"
end

function on_paint()
    local numpad4_is_pressed = input.is_key_pressed(keys.NUMPAD4)
    
    if numpad4_is_pressed and not numpad4_was_pressed then
        last_map = ""
        change_count = 0
        target_name = nil
        is_changing = false
    end
    numpad4_was_pressed = numpad4_is_pressed
    if not engine.is_in_game() then
        last_map = ""
        change_count = 0
        target_name = nil
        is_changing = false
        return
    end

    local local_player = client.get_local_player()
    if not local_player then return end

    local my_name = local_player:get_name()
    if not my_name or my_name == "" or my_name == "unknown" then return end

    local current_map = get_map_name()
    if current_map ~= last_map then
        last_map = current_map
        change_count = 0
        target_name = nil
        is_changing = false
    end

    if change_count >= 2 then
        return
    end

    if is_changing then
        if my_name == target_name then
            change_count = change_count + 1
            is_changing = false
        end
        return 
    end

    target_name = generate_random_name(NAME_LENGTH)
    is_changing = true
    
    client.execnormal('setinfo name "' .. target_name .. '"')
end
