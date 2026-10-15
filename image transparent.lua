local img_data = {
    loaded = false,
    name = "scalable_img",
    width = 0,
    height = 0,
    scale = 1.0
}
local bShowMenu = menu.is_open

function on_end_scene()
    local bShowMenu = menu.is_open()

    if not img_data.loaded then
        local success, w, h, msg = image.load( "C:/Heaven-L4D2/background.png", img_data.name)
        if success then
            img_data.loaded = true
            img_data.width = w
            img_data.height = h
        else
            if imgui.begin("Error", 0) then
                imgui.text("Failed to load image!")
                imgui.text(msg or "Unknown error")
                imgui["end"]()
            end
            return
        end
    end

    local w = img_data.width * img_data.scale
    local h = img_data.height * img_data.scale

    local flags = imgui.ImGuiWindowFlags_NoTitleBar +
                  imgui.ImGuiWindowFlags_AlwaysAutoResize +
                  imgui.ImGuiWindowFlags_NoBackground

    if not bShowMenu then
        flags = flags + imgui.ImGuiWindowFlags_NoInputs + imgui.ImGuiWindowFlags_NoMove
    end

    if imgui.begin("##ImageOverlay", flags) then
        imgui.image(img_data.name, w, h)
        imgui["end"]()
    end

    if bShowMenu then
        if imgui.begin("##ImageControls", imgui.ImGuiWindowFlags_AlwaysAutoResize) then
            local changed, new_scale = imgui.slider_float("Scale", img_data.scale, 0.1, 3.0)
            if changed then
                img_data.scale = new_scale
            end
            imgui["end"]()
        end
    end
end


function on_unload()
    if img_data.loaded then
        image.unload(img_data.name)
    end
end
















