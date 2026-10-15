local chat_log = {}
local MAX_CHAT_ENTRIES = 50
local CHAT_DISPLAY_TIME = 15.0
local last_cleanup = 0

local config = {
    show_team_prefix = true,
    show_vote_messages = true,
    show_chat_messages = true,
    show_timestamps = true
}

local team_names = {
    [0] = "Unknown",
    [1] = "Spectator",
    [2] = "Survivor",
    [3] = "Infected"
}

local function get_team_prefix_colored(team_num)
    if not config.show_team_prefix then
        return "", 1, 1, 1, 1
    end
    
    if team_num == 3 then
        return "(Infected) ", 1.0, 0.3, 0.3, 1.0
    elseif team_num == 2 then
        return "(Survivor) ", 0.3, 0.8, 1.0, 1.0
    elseif team_num == 1 then
        return "(Spectator) ", 0.7, 0.7, 0.7, 1.0
    else
        return "(Unknown) ", 0.5, 0.5, 0.5, 1.0
    end
end

local function get_timestamp()
    if not config.show_timestamps then
        return ""
    end
    return "[" .. os.date("%H:%M:%S") .. "] "
end

local function add_chat_message(player_name, team_num, message, is_vote)
    local prefix, r, g, b, a = get_team_prefix_colored(team_num)
    local timestamp = get_timestamp()
    
    local entry = {
        timestamp = timestamp,
        prefix = prefix,
        player_name = player_name,
        message = message,
        team_color = {r, g, b, a},
        is_vote = is_vote,
        time_added = client.get_tick_count() / 66.0
    }
    
    table.insert(chat_log, 1, entry)
    
    while #chat_log > MAX_CHAT_ENTRIES do
        table.remove(chat_log)
    end
end

local function get_player_team(entity_idx)
    local player = entity.get_by_index(entity_idx)
    if not player then return 0 end
    return player:get_team()
end

local function on_player_say(event_name, event)
    if not config.show_chat_messages then return end
    
    local user_id = event:get_int("userid")
    local text = event:get_string("text")
    local team_only = event:get_bool("teamonly")
    local entity_idx = engine.get_player_for_userid(user_id)
    
    if entity_idx <= 0 then return end
    
    local local_player = client.get_local_player()
    if not local_player then return end
    
    local local_idx = local_player:get_index()
    local local_team = local_player:get_team()
    
    if entity_idx == local_idx then return end
    
    local player_info = engine.get_player_info(entity_idx)
    if not player_info then return end
    
    local player_name = player_info.name
    local team_num = get_player_team(entity_idx)
    
    if team_num == local_team then return end
    
    local final_message = text
    if team_only then
        final_message = "(TEAM) " .. text
    end
    
    add_chat_message(player_name, team_num, final_message, false)
end

local function on_vote_cast(event_name, event)
    if not config.show_vote_messages then return end
    
    local entity_id = event:get_int("entityid")
    if entity_id <= 0 then return end
    
    local local_player = client.get_local_player()
    if not local_player then return end
    
    local local_idx = local_player:get_index()
    if entity_id == local_idx then return end
    
    local player_info = engine.get_player_info(entity_id)
    if not player_info then return end
    
    local player_name = player_info.name
    local team_num = get_player_team(entity_id)
    
    local vote_text = "Unknown"
    if event_name == "vote_cast_yes" then
        vote_text = "Yes"
    elseif event_name == "vote_cast_no" then
        vote_text = "No"
    end
    
    local message = "Voted: " .. vote_text
    add_chat_message(player_name, team_num, message, true)
end

local function render_chat_window()
    imgui.begin("Enemy Chat & Votes", 0)
    
    imgui.text(string.format("Messages: %d", #chat_log))
    
    imgui.separator()
    
    local changed, new_val
    
 --   changed, new_val = imgui.checkbox("Show Team Prefix", config.show_team_prefix)
    if changed then config.show_team_prefix = new_val end
    
    --changed, new_val = imgui.checkbox("Show Vote Messages", config.show_vote_messages)
    if changed then config.show_vote_messages = new_val end
    
--    changed, new_val = imgui.checkbox("Show Chat Messages", config.show_chat_messages)
    if changed then config.show_chat_messages = new_val end
    
--    changed, new_val = imgui.checkbox("Show Timestamps", config.show_timestamps)
    if changed then config.show_timestamps = new_val end
    
    if imgui.button("Clear Chat") then
        chat_log = {}
    end
    
    imgui.separator()
    
    imgui.begin_child("chat_log", 0, 300, true, 0)
    
    local current_time = client.get_tick_count() / 66.0
    
    if #chat_log == 0 then
        imgui.text("No messages yet...")
    end
    
    for i = #chat_log, 1, -1 do
        local entry = chat_log[i]
        local age = current_time - entry.time_added
        
        local alpha = 1.0
        if age > CHAT_DISPLAY_TIME then
            alpha = math.max(0, 1.0 - ((age - CHAT_DISPLAY_TIME) / 2.0))
            if alpha <= 0 then
                goto continue
            end
        end
        
        local full_text = entry.timestamp .. entry.prefix .. entry.player_name .. ": " .. entry.message
        local r, g, b, _ = table.unpack(entry.team_color)
        
        if entry.is_vote then
            imgui.text_colored(1.0, 1.0, 0.3, alpha, full_text)
        else
            imgui.text_colored(r, g, b, alpha, full_text)
        end
        
        ::continue::
    end
    
    imgui.end_child()
    imgui["end"]()
end

local function cleanup_old_messages()
    local current_time = client.get_tick_count() / 66.0
    
    if current_time - last_cleanup < 5.0 then return end
    last_cleanup = current_time
    
    local max_age = CHAT_DISPLAY_TIME + 2.0
    
    for i = #chat_log, 1, -1 do
        local age = current_time - chat_log[i].time_added
        if age > max_age then
            table.remove(chat_log, i)
        end
    end
end

function on_game_event(event_name, event)
    if event_name == "player_say" then
        on_player_say(event_name, event)
    elseif event_name == "vote_cast_yes" or event_name == "vote_cast_no" then
        on_vote_cast(event_name, event)
    end
end

function on_end_scene()
    render_chat_window()
    cleanup_old_messages()
end

events.register("player_say")
events.register("vote_cast_yes")
events.register("vote_cast_no")

client.print("Enemy Chat & Votes loaded")
