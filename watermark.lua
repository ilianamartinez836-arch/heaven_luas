-- Watermark.lua
client.print("Watermark loaded")
local watermark_name = "Heaven-Hook.lua" 
local padding = 8

local function safe_call(fn, ...)
    local ok, res1, res2, res3 = pcall(fn, ...)
    return ok and { res1, res2, res3 } or nil
end

local function get_player_name()
    local local_player = client.get_local_player()
    if not local_player then return "Unknown" end
    
    local index = local_player:get_index()
    if not index or index <= 0 then return "Unknown" end
    
    local info = engine.get_player_info(index)
    if info and info.name then
        return info.name
    end
    
    return "Unknown"
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

local function draw_with_drawlist(text)
    if not pcall(imgui.get_background_draw_list) then
        return false
    end

    local bg = imgui.get_background_draw_list()
    if not bg or type(bg.add_text) ~= "function" then
        return false
    end

    -- Push custom font for Unicode support
	-- i disabled this after crash so, fuck it u can just delete it
	-- make sure to delete the pop font too
    if pcall(imgui.push_font) then
        imgui.push_font()
    end

    local text_size = { x = 0, y = 0 }
    if pcall(imgui.calc_text_size, text) then
        local ts = imgui.calc_text_size(text)
        if ts and ts.x and ts.y then
            text_size.x, text_size.y = ts.x, ts.y
        end
    end

    local screen_w, screen_h = 0, 0
    if pcall(imgui.get_io) then
        local io = imgui.get_io()
        if io and io.display_size then
            screen_w = io.display_size.x or 0
            screen_h = io.display_size.y or 0
        end
    end

    if screen_w == 0 then screen_w = 1920 end

    local pos_x = screen_w - text_size.x - padding
    local pos_y = padding

    local ok_color = pcall(imgui.get_color_u32, 0,0,0,180)
    local bg_col = ok_color and imgui.get_color_u32(0,0,0,180) or 4278190080

    if type(bg.add_rect_filled) == "function" then
        bg:add_rect_filled({ x = pos_x - 6, y = pos_y - 3 }, { x = pos_x + text_size.x + 6, y = pos_y + text_size.y + 3 }, bg_col, 6)
    end

    local txt_col = (pcall(imgui.get_color_u32, 255,255,255,255) and imgui.get_color_u32(255,255,255,255)) or 4294967295
    bg:add_text({ x = pos_x, y = pos_y }, txt_col, text)
    
    -- Pop font
    if pcall(imgui.pop_font) then
        imgui.pop_font()
    end
    
    return true
end

local function draw_with_window_pos(text)
    -- Push custom font
	-- no need, deleted in the api
    if pcall(imgui.push_font) then
        imgui.push_font()
    end
    
    local text_size = { x = 0, y = 0 }
    if pcall(imgui.calc_text_size, text) then
        local ts = imgui.calc_text_size(text)
        if ts and ts.x and ts.y then
            text_size.x, text_size.y = ts.x, ts.y
        end
    end

    local screen_w, screen_h = 0, 0
    if pcall(imgui.get_io) then
        local io = imgui.get_io()
        if io and io.display_size then
            screen_w = io.display_size.x or 0
            screen_h = io.display_size.y or 0
        end
    end
    if screen_w == 0 then screen_w = 1920 end

    local pos_x = screen_w - text_size.x - padding
    local pos_y = padding

    if pcall(imgui.set_next_window_pos, { x = pos_x, y = pos_y }) then
        imgui.set_next_window_pos({ x = pos_x, y = pos_y })
    end

    local flags = 0
    if imgui.ImGuiWindowFlags_AlwaysAutoResize then
        flags = flags + imgui.ImGuiWindowFlags_AlwaysAutoResize
    end
    if imgui.ImGuiWindowFlags_NoTitleBar then
        flags = flags + imgui.ImGuiWindowFlags_NoTitleBar
    end
    if imgui.ImGuiWindowFlags_NoResize then
        flags = flags + imgui.ImGuiWindowFlags_NoResize
    end
    if imgui.ImGuiWindowFlags_NoMove then
        flags = flags + imgui.ImGuiWindowFlags_NoMove
    end
    if imgui.ImGuiWindowFlags_NoScrollbar then
        flags = flags + imgui.ImGuiWindowFlags_NoScrollbar
    end

    local result = false
    if imgui.begin("Decisions of torment", flags) then
        imgui.text(text)
        imgui["end"]()
        result = true
    end
    
    -- Pop font
    if pcall(imgui.pop_font) then
        imgui.pop_font()
    end

    return result
end
local function draw_basic(text)
    if imgui.begin("Time Shit", 0) then
        imgui.text(text)
        imgui["end"]()
    end
    return false
end

function on_end_scene()
    local time = os.date("%H:%M:%S")
    local player_name = get_player_name()
    local map_name = get_map_name()
    
    -- Format: Heaven-Hook.lua | PlayerName | MapName | HH:MM:SS
	-- u can change whatever the f u want lel
    local text = string.format("%s | %s | %s | %s", watermark_name, player_name, map_name, time)

    if draw_with_drawlist(text) then
        return
    end

    if draw_with_window_pos(text) then
        return
    end

    draw_basic(text)
end

