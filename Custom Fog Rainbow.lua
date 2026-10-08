-- =============================================
-- Fog Custom Avanzado + Rainbow Mode
-- =============================================

local fog = {
    enabled = true,
    
    -- Color normal (cuando rainbow está desactivado)
    red = 25,
    green = 45,
    blue = 160,
    
    -- Rainbow
    rainbow = false,
    rainbow_speed = 2.5,
    
    -- Distancia y densidad
    start_dist = 150,
    end_dist = 1600,
    density = 0.65
}

local hue = 0
local last_time = 0

-- =============================================
-- Hook principal
-- =============================================
function on_get_fog_color(fog_data, color)
    if not fog.enabled then
        return fog_data, color
    end

    local r, g, b = fog.red, fog.green, fog.blue

    -- Rainbow Logic
    if fog.rainbow then
        local now = os.clock()
        hue = hue + (fog.rainbow_speed * (now - last_time))
        last_time = now

        local h = hue % 360
        local c = (1 - math.abs((h / 60) % 2 - 1)) * 255
        local x = c * (1 - math.abs(((h / 60) % 2) - 1))
        local m = 0

        if h < 60 then
            r, g, b = 255, c, m
        elseif h < 120 then
            r, g, b = x, 255, m
        elseif h < 180 then
            r, g, b = m, 255, c
        elseif h < 240 then
            r, g, b = m, x, 255
        elseif h < 300 then
            r, g, b = c, m, 255
        else
            r, g, b = 255, m, x
        end
    end

    fog_data.start = fog.start_dist
    fog_data.end_dist = fog.end_dist
    fog_data.max_density = fog.density

    color[1] = r / 255
    color[2] = g / 255
    color[3] = b / 255

    return fog_data, color
end

-- =============================================
-- Menú
-- =============================================
menu.inject_into_subtab("World", "World", function()
    imgui.text("Fog Custom Avanzado")
    imgui.separator()

    local ch, val = imgui.checkbox("Enable Fog", fog.enabled)
    if ch then fog.enabled = val end

    if fog.enabled then
        -- Rainbow
        ch, val = imgui.checkbox("Rainbow Mode", fog.rainbow)
        if ch then fog.rainbow = val end

        if fog.rainbow then
            ch, val = imgui.slider_float("Rainbow Speed", fog.rainbow_speed, 0.5, 12.0)
            if ch then fog.rainbow_speed = val end
        else
            imgui.text("Color")
            ch, val = imgui.slider_int("Red", fog.red, 0, 255)
            if ch then fog.red = val end
            ch, val = imgui.slider_int("Green", fog.green, 0, 255)
            if ch then fog.green = val end
            ch, val = imgui.slider_int("Blue", fog.blue, 0, 255)
            if ch then fog.blue = val end
        end

        imgui.separator()
        imgui.text("Distance")
        ch, val = imgui.slider_int("Start Distance", fog.start_dist, -500, 2000)
        if ch then fog.start_dist = val end

        ch, val = imgui.slider_int("End Distance", fog.end_dist, 500, 5000)
        if ch then fog.end_dist = val end

        imgui.separator()
        imgui.text("Density")
        ch, val = imgui.slider_float("Fog Density", fog.density, 0.0, 1.0)
        if ch then fog.density = val end

        imgui.separator()
        imgui.text_colored(0.6, 0.6, 0.6, 1.0, "Menor End Distance + Mayor Density = Niebla más fuerte")
    end

    imgui["end"]()
end)

-- =============================================
-- Load Message
-- =============================================
client.print("§6Fog Custom Avanzado + Rainbow cargado")
client.print("§7Menú disponible en World > World")