-- Spotify Overlay Script - With Config System
-- REQUIRES INSECURE LUA SCRIPTING ENABLED.
-- Fixed REWIND = 50 and FAST_FORWARD = 49
-- Added File I/O for C:\SpotifyTest
-- This is like, a poc
-- so people can make their own shit and etc
-- this is quite over complicated
-- and is not the normal flow that i use for coding 
-- but i hope it helps a bit
--only important things are commented
-- or at least that are kinda key 
overlay = overlay or {}
overlay.spotify_hwnd = nil
overlay.last_update = 0
overlay.update_interval = 0.5
overlay.cached_song = ""
overlay.cached_artist = ""
overlay.cached_playing = false
overlay.is_paused = false

-- Config Defaults
overlay.config_dir = "C:\\SpotifyTest"
overlay.config_file = overlay.config_dir .. "\\config.dat"

overlay.settings = {
    custom_artist_name = "", 
    enable_custom_artist = false,
    text_r = 1.0, 
    text_g = 1.0, 
    text_b = 1.0
}

-- Debounce tracking for buttons
-- Context: this thing was skipping 2 songs instead of 1, added cooldown rn
overlay.last_button_press = {}
overlay.button_cooldown = 0.2 

-- Helper: Split string for config parsing
function string:split(delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(self, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(self, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(self, delimiter, from)
    end
    table.insert(result, string.sub(self, from))
    return result
end

-- CONFIG FUNCTIONS

function overlay:save_config()
    -- 1. Create Directory
    if file.create_directory then
        file.create_directory(self.config_dir)
    end

    -- 2. Serialize settings to string (Key=Value format)
    local content = ""
    content = content .. "custom_artist_name=" .. tostring(self.settings.custom_artist_name) .. "\n"
    content = content .. "enable_custom_artist=" .. tostring(self.settings.enable_custom_artist) .. "\n"
    content = content .. "text_r=" .. tostring(self.settings.text_r) .. "\n"
    content = content .. "text_g=" .. tostring(self.settings.text_g) .. "\n"
    content = content .. "text_b=" .. tostring(self.settings.text_b) .. "\n"

    -- 3. Write to file
    if file.write then
        local success = file.write(self.config_file, content)
        if success then
            client.print("[Spotify] Config saved to " .. self.config_file)
        else
            client.print("[Spotify] Failed to save config")
        end
    else
        client.print("[Spotify] File API not available")
    end
end

function overlay:load_config()
    if not file.exists or not file.read then return end

    if not file.exists(self.config_file) then 
        client.print("[Spotify] No config file found")
        return 
    end

    local content = file.read(self.config_file)
    if not content then return end

    local lines = content:split("\n")
    for _, line in pairs(lines) do
        local pair = line:split("=")
        if #pair == 2 then
            local key = pair[1]
            local value = pair[2]

            if key == "custom_artist_name" then
                self.settings.custom_artist_name = value
            elseif key == "enable_custom_artist" then
                self.settings.enable_custom_artist = (value == "true")
            elseif key == "text_r" then
                self.settings.text_r = tonumber(value) or 1.0
            elseif key == "text_g" then
                self.settings.text_g = tonumber(value) or 1.0
            elseif key == "text_b" then
                self.settings.text_b = tonumber(value) or 1.0
            end
        end
    end
    client.print("[Spotify] Config loaded")
end

-- SPOTIFY LOGIC
function overlay:find_spotify()
    local pid = windows.get_process_id_by_name("Spotify.exe")
    if not pid then
        self.spotify_hwnd = nil
        return false
    end
    
    local current_hwnd = nil
    local last_visible_hwnd = nil
    local found_playing = false
    
    repeat
        current_hwnd = windows.find_window_ex(nil, current_hwnd, nil, nil)
        
        if current_hwnd then
            local window_pid = windows.get_window_pid(current_hwnd)
            
            if window_pid == pid then
                if windows.is_window_visible(current_hwnd) then
                    last_visible_hwnd = current_hwnd
                    
                    local title = windows.get_window_text(current_hwnd) or ""
                    
                    if title:find(" %- ") or title:find(" – ") then
                        self.spotify_hwnd = current_hwnd
                        found_playing = true
                        break
                    end
                end
            end
        end
    until not current_hwnd
    
    if not found_playing and last_visible_hwnd then
        self.spotify_hwnd = last_visible_hwnd
    end
    
    return self.spotify_hwnd ~= nil
end

function overlay:get_current_track()
    if not self.spotify_hwnd then
        if not self:find_spotify() then
            return "Spotify not running", "", false
        end
    end
    
    local title = windows.get_window_text(self.spotify_hwnd) or ""
    
    if #title == 0 then
        self.spotify_hwnd = nil
        return "Spotify not running", "", false
    end
    
    local sep_pos = title:find(" %- ")
    if not sep_pos then
        sep_pos = title:find(" – ")
    end
    
    if sep_pos and #title > 0 then
        local part1 = title:sub(1, sep_pos - 1):match("^%s*(.-)%s*$") or ""
        local part2 = title:sub(sep_pos + 3):match("^%s*(.-)%s*$") or ""
        
        local song = part2 
        local artist = part1
        return song, artist, true
    else
        self.is_paused = true
        return "Paused", "", false
    end
end

function overlay:update()
    local current_time = os.clock()
    if current_time - self.last_update >= self.update_interval then
        local prev_playing = self.cached_playing
        self.cached_song, self.cached_artist, self.cached_playing = self:get_current_track()
        
        if prev_playing and not self.cached_playing then
            self.is_paused = true
        elseif not prev_playing and self.cached_playing then
            self.is_paused = false
        end
        
        self.last_update = current_time
    end
end

-- Check if enough time has passed since last button press
function overlay:can_press_button(button_name)
    local current_time = os.clock()
    local last_press = self.last_button_press[button_name] or 0
    
    if current_time - last_press >= self.button_cooldown then
        self.last_button_press[button_name] = current_time
        return true
    end
    
    return false
end

-- Send media command
function overlay:send_media_command(command)
    if not self.spotify_hwnd then
        if not self:find_spotify() then
            return false
        end
    end
    
    local WM_APPCOMMAND = 0x0319
    
    windows.send_message(
        self.spotify_hwnd,
        WM_APPCOMMAND,
        self.spotify_hwnd,
        command * 65536
    )
    
    return true
end

function overlay:play()
    if not self:can_press_button("play") then return end
    self:send_media_command(46)
    self.is_paused = false
end
-- if you are wondering, hey aika WTF is send media command 46?
--is just a window function to call up shit from the minw lib if im not wrong, winuser shit
-- the 46 is APPCOMMAND_MEDIA_PLAY
-- you can see more in: https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-appcommand
function overlay:pause()
    if not self:can_press_button("pause") then return end
    self:send_media_command(47) --APPCOMMAND_MEDIA_PAUSE
    self.is_paused = true
end

function overlay:play_pause()
    if not self:can_press_button("play_pause") then return end
    self:send_media_command(14) --APPCOMMAND_MEDIA_PLAY_PAUSE
    self.is_paused = not self.is_paused
end

function overlay:next_track()
    if not self:can_press_button("next") then return end
    self:send_media_command(11) --APPCOMMAND_MEDIA_NEXTTRACK
end

function overlay:previous_track()
    if not self:can_press_button("previous") then return end
    self:send_media_command(12) -- APPCOMMAND_MEDIA_PREVIOUSTRACK
end

function overlay:stop()
    if not self:can_press_button("stop") then return end
    self:send_media_command(13) --APPCOMMAND_MEDIA_STOP
    self.is_paused = true
end

function overlay:rewind()
    if not self:can_press_button("rewind") then return end
    self:send_media_command(50) --APPCOMMAND_MEDIA_REWIND
end

function overlay:fast_forward()
    if not self:can_press_button("fast_forward") then return end
    self:send_media_command(49) --APPCOMMAND_MEDIA_FAST_FORWARD
end

function on_end_scene()
    overlay:update()
    
    menu.add_main_tab("Spotify", function()
        
        if imgui.begin_child("ConfigPanel", 0, 180, true, 0) then
            imgui.text("Settings & Customization")
            imgui.separator()
            
            local changed_text, new_text = imgui.input_text("Custom Artist Text", overlay.settings.custom_artist_name, 64)
            if changed_text then
                overlay.settings.custom_artist_name = new_text
            end
            
            local changed_toggle, new_val = imgui.checkbox("Override Artist Name", overlay.settings.enable_custom_artist)
            if changed_toggle then
                overlay.settings.enable_custom_artist = new_val
            end

            imgui.spacing()

            imgui.text("Artist Text Color")
            local changed_r, new_r = imgui.slider_float("Red", overlay.settings.text_r, 0.0, 1.0)
            if changed_r then overlay.settings.text_r = new_r end

            local changed_g, new_g = imgui.slider_float("Green", overlay.settings.text_g, 0.0, 1.0)
            if changed_g then overlay.settings.text_g = new_g end

            local changed_b, new_b = imgui.slider_float("Blue", overlay.settings.text_b, 0.0, 1.0)
            if changed_b then overlay.settings.text_b = new_b end

            imgui.spacing()
            imgui.separator()

            --Save / Load Buttons
            --u dumb bitch
            if imgui.button("Save Config (C:\\SpotifyTest)") then
                overlay:save_config()
            end

            imgui.same_line()

            if imgui.button("Load Config") then
                overlay:load_config()
            end
            
            imgui.end_child()
        end

        imgui.spacing()
        imgui.separator()
        imgui.spacing()

        imgui.text("Playback Controls:")
        
        if imgui.button("Previous Track") then overlay:previous_track() end
        imgui.same_line()
        
        if overlay.cached_playing and not overlay.is_paused then
            if imgui.button("Pause") then overlay:pause() end
        else
            if imgui.button("Play") then overlay:play() end
        end
        
        imgui.same_line()
        if imgui.button("Next Track") then overlay:next_track() end
        imgui.same_line()
        if imgui.button("Stop") then overlay:stop() end
        
        imgui.spacing()
        
        if imgui.button("Rewind") then overlay:rewind() end
        imgui.same_line()
        if imgui.button("Fast Forward") then overlay:fast_forward() end
        
        imgui.spacing()
        imgui.separator()
        imgui.spacing()

        if overlay.cached_playing then
            imgui.text("Now Playing:")
            imgui.spacing()
            
            imgui.text("Song:   " .. overlay.cached_song)
            
            local display_artist = overlay.cached_artist
            if overlay.settings.enable_custom_artist and overlay.settings.custom_artist_name ~= "" then
                display_artist = overlay.settings.custom_artist_name
            end
            
            imgui.text("Artist: " .. display_artist)
            
        else
            if overlay.is_paused then
                imgui.text_colored(1, 1, 0, 1, "Paused")
            else
                imgui.text_colored(0.7, 0.7, 0.7, 1, overlay.cached_song)
            end
        end
        
        imgui.spacing()
        imgui.separator()
        
        if overlay.spotify_hwnd then
            imgui.text_colored(0, 1, 0, 1, "Connected")
        else
            imgui.text_colored(1, 0, 0, 1, "Not connected")
            if imgui.button("Refresh Connection") then
                overlay:find_spotify()
            end
        end
    end)
    
    if imgui.begin("Spotify Overlay") then
        if overlay.cached_playing then
            local display_artist = overlay.cached_artist
            if overlay.settings.enable_custom_artist and overlay.settings.custom_artist_name ~= "" then
                display_artist = overlay.settings.custom_artist_name
            end

            imgui.text_colored(
                overlay.settings.text_r, 
                overlay.settings.text_g, 
                overlay.settings.text_b, 
                1.0, 
                display_artist
            )

            imgui.text(overlay.cached_song)
            
            if imgui.button("<<") then overlay:previous_track() end
            imgui.same_line()
            if imgui.button(overlay.is_paused and ">" or "||") then overlay:play_pause() end
            imgui.same_line()
            if imgui.button(">>") then overlay:next_track() end
        else
            imgui.text(overlay.is_paused and "Paused" or overlay.cached_song)
        end
        imgui["end"]()
    end
end

overlay:find_spotify()
overlay:load_config()
