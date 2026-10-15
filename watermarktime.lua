client.print("Watermark loaded")

local bShowMenu = menu.is_open

function on_end_scene()
    local time_str = os.date("%H:%M:%S")
    local date_str = os.date("%b %d, %Y")
    
    local clockFlags = imgui.ImGuiWindowFlags_NoTitleBar +
                      imgui.ImGuiWindowFlags_AlwaysAutoResize +
                      imgui.ImGuiWindowFlags_NoBackground

    if not bShowMenu then
        clockFlags = clockFlags + imgui.ImGuiWindowFlags_NoInputs + imgui.ImGuiWindowFlags_NoMove
    end
    
    if imgui.begin("##ClockOverlay", clockFlags) then
        imgui.push_style_color(imgui.ImGuiCol_Text, 1.0, 1.0, 1.0, 1.0)

        imgui.set_window_font_scale(1.5)
        imgui.text(time_str)

        imgui.set_window_font_scale(1.0)
        imgui.text(date_str)
        
        imgui.pop_style_color(1)
        imgui["end"]()
    end
end