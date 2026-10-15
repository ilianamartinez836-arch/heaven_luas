local VALID_NAMES = {
    "chocoganpi."
}

local function has_value(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function on_paint()
    if not engine.is_in_game() then
        return
    end
    
    local local_player = client.get_local_player()
    if not local_player then
        return
    end
    
    local my_name = local_player:get_name()
    if not my_name or my_name == "" or my_name == "unknown" then
        return
    end
    
    if has_value(VALID_NAMES, my_name) then
        return
    end
    
    local new_name = VALID_NAMES[1]
    if new_name and new_name ~= "" then
        client.execnormal('setinfo name "' .. new_name .. '"')
    end
end






