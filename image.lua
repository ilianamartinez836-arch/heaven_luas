local img_data = {
    loaded = false,
    name = "scalable_img",
    width = 0,
    height = 0,
    scale = 1.0
}

function on_end_scene()
    if not img_data.loaded then
        local success, w, h, msg = image.load("C:/G71ZKAPaYAAxNef.png", img_data.name)
        if success then
            img_data.loaded = true
            img_data.width = w
            img_data.height = h
            client.print("Loaded: " .. w .. "x" .. h)
        else
            if imgui.begin("Error", 0) then
                imgui.text("Failed to load image!")
                imgui.text(msg or "Unknown error")
                imgui["end"]()
            end
            return
        end
    end
    
    if imgui.begin("Scalable Image", 0) then
        local w = img_data.width * img_data.scale
        local h = img_data.height * img_data.scale
        
        imgui.image(img_data.name, w, h)
        
        imgui.separator()
        
        local changed, new_scale = imgui.slider_float("##scale", img_data.scale, 0.1, 3.0)
        if changed then
            img_data.scale = new_scale
        end
        
        imgui.same_line()
        imgui.text("Scale")
        
        imgui.text(string.format("Display: %.0fx%.0f", w, h))
        
        imgui["end"]()
    end
end

function on_unload()
    if img_data.loaded then
        image.unload(img_data.name)
    end
end

