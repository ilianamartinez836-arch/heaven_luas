local keyboard = {
    enabled = true,
    x = 100,
    y = 100,
    key_size = 40,
    key_spacing = 4,
    active_color = {r = 0.85, g = 0.15, b = 0.15, a = 0.6},
    inactive_color = {r = 0.25, g = 0.25, b = 0.25, a = 0.5},
    text_color = {r = 0.6, g = 0.6, b = 0.6, a = 1},
    border_color = {r = 0, g = 0, b = 0, a = 0.1},
    transition_speed = 14.0,
    smooth = true,
    states = {}
}

local function define_layout()
    return {
        row1 = {"TAB", "Q", "W", "E", "R"},
        row2 = {"CAPSLOCK", "A", "S", "D", "F"},
        row3 = {"SHIFT", "Z", "X", "C"},
        row4 = {"CTRL", "SPACE"}
    }
end

local layout = define_layout()

for _, row in pairs(layout) do
    for _, key in ipairs(row) do
        keyboard.states[key:lower()] = 0.0
    end
end

local function update_state(key, pressed, dt)
    local target = pressed and 1.0 or 0.0
    local current = keyboard.states[key]
    local speed = keyboard.transition_speed * dt
    if keyboard.smooth then
        if current < target then
            current = math.min(current + speed, target)
        else
            current = math.max(current - speed, target)
        end
    else
        current = target
    end
    keyboard.states[key] = current
end

local function draw_key(x, y, w, h, label, active)
    local col = active and keyboard.active_color or keyboard.inactive_color
    draw.rect(x, y, w, h, col.r, col.g, col.b, col.a)
    draw.outlined_rect(x, y, w, h,
        keyboard.border_color.r,
        keyboard.border_color.g,
        keyboard.border_color.b,
        keyboard.border_color.a
    )
    draw.string(fonts.DEBUG, x + w / 2, y + h / 2 - 7,
        keyboard.text_color.r,
        keyboard.text_color.g,
        keyboard.text_color.b,
        keyboard.text_color.a,
        text_align.CENTERX,
        label
    )
end


local function get_inputs()
    return {
        tab = input.is_key_down(keys.TAB),
        capslock = input.is_key_down(keys.CAPSLOCK),
        q = input.is_key_down(keys.KEY_Q),
        w = input.is_key_down(keys.KEY_W),
        e = input.is_key_down(keys.KEY_E),
        r = input.is_key_down(keys.KEY_R),
        a = input.is_key_down(keys.KEY_A),
        s = input.is_key_down(keys.KEY_S),
        d = input.is_key_down(keys.KEY_D),
        f = input.is_key_down(keys.KEY_F),
        shift = input.is_key_down(keys.SHIFT),
        z = input.is_key_down(keys.KEY_Z),
        x = input.is_key_down(keys.KEY_X),
        c = input.is_key_down(keys.KEY_C),
        ctrl = input.is_key_down(keys.CTRL),
        space = input.is_key_down(keys.SPACE)
    }
end

function on_paint()
    if not keyboard.enabled then return end
    local dt = client.get_frame_time()
    local s, sp = keyboard.key_size, keyboard.key_spacing
    local x, y = keyboard.x, keyboard.y
    local states = get_inputs()

    for key, pressed in pairs(states) do
        update_state(key, pressed, dt)
    end

    local x1 = x
    for i, k in ipairs(layout.row1) do
        local w_key = (k == "TAB") and s * 1.3 or s
        draw_key(x1, y, w_key, s, k, states[k:lower()])
        x1 = x1 + w_key + sp
    end

    local row2_y = y + s + sp
    local x2 = x + (s * 0.1)
    for i, k in ipairs(layout.row2) do
        local w_key = (k == "CAPSLOCK") and s * 1.5 or s
        draw_key(x2, row2_y, w_key, s, k, states[k:lower()])
        x2 = x2 + w_key + sp
    end

    local row3_y = row2_y + s + sp
    local x3 = x + (s * 0.1)
    draw_key(x3, row3_y, s * 1.7, s, "SHIFT", states["shift"])
    x3 = x3 + s * 1.7 + sp
    for i, k in ipairs({"Z", "X", "C"}) do
        draw_key(x3 + (i - 1) * (s + sp), row3_y, s, s, k, states[k:lower()])
    end
    local row4_y = row3_y + s + sp
    local x4 = x 
    draw_key(x4, row4_y, s * 1.3, s, "CTRL", states["ctrl"])
    draw_key(x4 + s * 1.3 + sp, row4_y, s * 3.5, s, "SPACE", states["space"])
end

function on_create_move()
    if input.is_key_pressed(keys.F10) then
        keyboard.enabled = not keyboard.enabled
    end
end
