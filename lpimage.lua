ffi.cdef[[
    void DrawESP(uintptr_t clientBase, uintptr_t engineBase);
    bool GetLocalPlayerBBox(uintptr_t clientBase, uintptr_t engineBase,
        float* outX, float* outY, float* outW, float* outH);
]]

local ok, esp = pcall(ffi.load, "BoundingBox.dll")
if not ok then client.print("[ESP] Failed: " .. tostring(esp)) end

local client_base = modules.get_client_base()
local engine_base = modules.get_engine_base()

local settings = {
    esp_enabled   = false,
    image_enabled = true,
    image_anchor  = "top_left",
    offset_x      = 0,
    offset_y      = -10,
    scale         = 0.2,
    padding       = 8,
}

local anchors = {
    { id = "top_left",     label = "Top Left"     },
    { id = "top_center",   label = "Top Center"   },
    { id = "top_right",    label = "Top Right"    },
    { id = "left",         label = "Left Middle"  },
    { id = "right",        label = "Right Middle" },
    { id = "bottom_left",  label = "Bottom Left"  },
    { id = "bottom_center",label = "Bottom Center"},
    { id = "bottom_right", label = "Bottom Right" },
    { id = "center",       label = "Center"       },
}

local img_data = {
    loaded  = false,
    name    = "local_player_img",
    width   = 0,
    height  = 0,
}

local function get_anchor_index()
    for i, a in ipairs(anchors) do
        if a.id == settings.image_anchor then return i end
    end
    return 1
end

local function compute_image_pos(box, img_w, img_h)
    local a = settings.image_anchor
    local p = settings.padding
    local bx, by, bw, bh = box.x, box.y, box.w, box.h
    local x, y

    if a == "top_left" then
        x = bx - img_w - p
        y = by
    elseif a == "top_center" then
        x = bx + bw / 2 - img_w / 2
        y = by - img_h - p
    elseif a == "top_right" then
        x = bx + bw + p
        y = by
    elseif a == "left" then
        x = bx - img_w - p
        y = by + bh / 2 - img_h / 2
    elseif a == "right" then
        x = bx + bw + p
        y = by + bh / 2 - img_h / 2
    elseif a == "bottom_left" then
        x = bx - img_w - p
        y = by + bh - img_h
    elseif a == "bottom_center" then
        x = bx + bw / 2 - img_w / 2
        y = by + bh + p
    elseif a == "bottom_right" then
        x = bx + bw + p
        y = by + bh - img_h
    elseif a == "center" then
        x = bx + bw / 2 - img_w / 2
        y = by + bh / 2 - img_h / 2
    else
        x = bx - img_w - p
        y = by + bh - img_h
    end

    return math.floor(x + settings.offset_x),
           math.floor(y + settings.offset_y)
end

function on_paint()
    if not settings.esp_enabled then return end
    if not engine.is_in_game() then return end
    if not ok or not esp then return end
    esp.DrawESP(client_base, engine_base)
end

function on_end_scene()
    if not engine.is_in_game() then return end
    if not ok or not esp then return end
    if not settings.image_enabled then return end

    if not img_data.loaded then
        local success, w, h = image.load("C:/luaimages/41d-pk2B_400x400.png", img_data.name)
        if success then
            img_data.loaded = true
            img_data.width  = w
            img_data.height = h
        else
            return
        end
    end

    local bx = ffi.new("float[1]")
    local by = ffi.new("float[1]")
    local bw = ffi.new("float[1]")
    local bh = ffi.new("float[1]")

    if not esp.GetLocalPlayerBBox(client_base, engine_base, bx, by, bw, bh) then
        return
    end

    local box = {
        x = math.floor(bx[0]),
        y = math.floor(by[0]),
        w = math.floor(bw[0]),
        h = math.floor(bh[0])
    }

    local img_w = img_data.width  * settings.scale
    local img_h = img_data.height * settings.scale

    local tx, ty = compute_image_pos(box, img_w, img_h)

    local flags = imgui.ImGuiWindowFlags_NoTitleBar        +
                  imgui.ImGuiWindowFlags_AlwaysAutoResize  +
                  imgui.ImGuiWindowFlags_NoBackground      +
                  imgui.ImGuiWindowFlags_NoInputs          +
                  imgui.ImGuiWindowFlags_NoMove            +
                  imgui.ImGuiWindowFlags_NoSavedSettings

    imgui.set_next_window_pos(tx, ty)
    if imgui.begin("##LocalImg", flags) then
        imgui.image(img_data.name, img_w, img_h)
        imgui["end"]()
    end
end

function on_unload()
    if img_data.loaded and image.unload then
        image.unload(img_data.name)
    end
end

menu.add_main_tab("Self Image", function()
    imgui.text("ESP")
    imgui.separator()

    local c0, v0 = imgui.checkbox("Enable ESP boxes", settings.esp_enabled)
    if c0 then settings.esp_enabled = v0 end

    imgui.text("")
    imgui.text("Image")
    imgui.separator()

    local c1, v1 = imgui.checkbox("Show image", settings.image_enabled)
    if c1 then settings.image_enabled = v1 end

    imgui.text("")
    imgui.text("Anchor position")

    for _, a in ipairs(anchors) do
        local is_selected = settings.image_anchor == a.id
        if is_selected then
            imgui.text("> " .. a.label)
        else
            if imgui.button(a.label) then
                settings.image_anchor = a.id
            end
        end
    end

    imgui.text("")
    imgui.text("Fine tuning")
    imgui.separator()

    local c2, v2 = imgui.slider_float("Scale",     settings.scale,    0.1, 3.0)
    if c2 then settings.scale = v2 end

    local c3, v3 = imgui.slider_int("Padding",     settings.padding,  0,   100)
    if c3 then settings.padding = v3 end

    local c4, v4 = imgui.slider_int("Offset X",    settings.offset_x, -200, 200)
    if c4 then settings.offset_x = v4 end

    local c5, v5 = imgui.slider_int("Offset Y",    settings.offset_y, -200, 200)
    if c5 then settings.offset_y = v5 end

    imgui["end"]()
end)
