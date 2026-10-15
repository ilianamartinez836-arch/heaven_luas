function on_paint()

    local sw, sh = draw.get_screen_size()
    local cx, cy = math.floor(sw / 2), math.floor(sh / 2)
    
    local g, l = 2, 5
    local r, g_col, b, a = 1, 0, 0, 1
    local sr, sg, sb, sa = 0, 0, 0, 1

    local function draw_x_arm(dx, dy)
        local x1, y1 = cx + (dx * g), cy + (dy * g)
        local x2, y2 = cx + (dx * (g + l)), cy + (dy * (g + l))

        draw.line(x1 + 1, y1 + 1, x2 + 1, y2 + 1, sr, sg, sb, sa)
        draw.line(x1, y1, x2, y2, r, g_col, b, a)
        draw.line(x1 + 1, y1, x2 + 1, y2, r, g_col, b, a)
    end

    draw_x_arm(-1, -1)
    draw_x_arm(1, -1)
    draw_x_arm(-1, 1)
    draw_x_arm(1, 1)
end

