local frame_counter = 0

local function get_screen_coords(world_pos)
    if not engine.world_to_screen_matrix then
        return nil
    end

    local mat_ptr = engine.world_to_screen_matrix()
    if not mat_ptr or mat_ptr == 0 then
        return nil
    end

    local function read_mat(idx)
        return memory.read_float(mat_ptr + (idx * 4))
    end

    local m00 = read_mat(0)  local m01 = read_mat(1)
    local m02 = read_mat(2)  local m03 = read_mat(3)
    local m10 = read_mat(4)  local m11 = read_mat(5)
    local m12 = read_mat(6)  local m13 = read_mat(7)
    local m30 = read_mat(12) local m31 = read_mat(13)
    local m32 = read_mat(14) local m33 = read_mat(15)

    local w = m30 * world_pos.x + m31 * world_pos.y + m32 * world_pos.z + m33
    if w < 0.001 then return nil end

    local inv_w = 1.0 / w
    local screen_x = (m00 * world_pos.x + m01 * world_pos.y + m02 * world_pos.z + m03) * inv_w
    local screen_y = (m10 * world_pos.x + m11 * world_pos.y + m12 * world_pos.z + m13) * inv_w

    local width, height = engine.get_screen_size()
    local x = (width / 2) + (screen_x * width / 2)
    local y = (height / 2) - (screen_y * height / 2)

    return { x = x, y = y }
end

local function draw_box(x, y, w, h, r, g, b, a)
    draw.outlined_rect(math.floor(x), math.floor(y), math.floor(w), math.floor(h), r, g, b, a)
end
function on_paint()
    frame_counter = frame_counter + 1

    if not engine.is_in_game() then return end

    local local_player = client.get_local_player()
    if not local_player or not local_player:is_alive() then return end

    local local_index = local_player:get_index()
    local local_team = local_player:get_team() or -1
    local max_ents = engine.get_max_clients()

    for i = 1, max_ents do
        local player = entity.get_by_index(i)
        if player and i ~= local_index and player:is_alive() then
            local origin = player:get_origin()
            local eye_pos = player:get_eye_position()

            if origin and eye_pos then
                local feet_screen = get_screen_coords(origin)
                local head_screen = get_screen_coords(eye_pos)

                if feet_screen and head_screen then
                    local box_h = math.abs(feet_screen.y - head_screen.y)
                    if box_h > 5 then
                        local box_w = box_h * 0.5
                        local box_x = head_screen.x - box_w / 2
                        local box_y = head_screen.y

                        local team = player:get_team() or -1
                        local r, g, b = 1.0, 0.2, 0.2
                        if team == local_team then
                            r, g, b = 0.0, 0.5, 1.0
                        end

                        draw.outlined_rect(
                            math.floor(box_x),
                            math.floor(box_y),
                            math.floor(box_w),
                            math.floor(box_h),
                            r, g, b, 1.0
                        )

                        local name = player.get_name and player:get_name() or ("Player " .. tostring(i))
                        local text_y = box_y - draw.get_font_height(fonts.ESP) - 2
                        draw.string(
                            fonts.ESP,
                            math.floor(head_screen.x),
                            math.floor(text_y),
                            1.0, 1.0, 1.0, 1.0,
                            text_align.CENTERX,
                            name
                        )

                        local health = player.get_health and player:get_health() or nil
                        local max_health = player.get_max_health and player:get_max_health() or 100

                        if health and max_health and max_health > 0 then
                            local hp_pct = health / max_health
                            if hp_pct < 0 then hp_pct = 0 end
                            if hp_pct > 1 then hp_pct = 1 end

                            local bar_w = 4
                            local bar_gap = 3
                            local bar_x = box_x - bar_w - bar_gap
                            local bar_y = box_y
                            local bar_h = box_h

                            draw.outlined_rect(
                                math.floor(bar_x),
                                math.floor(bar_y),
                                bar_w,
                                math.floor(bar_h),
                                0.0, 0.0, 0.0, 1.0
                            )

                            local fill_h = math.floor(bar_h * hp_pct)
                            local fill_y = math.floor(bar_y + (bar_h - fill_h))

                            local fill_r = 1.0 - hp_pct
                            local fill_g = hp_pct

                            draw.rect(
                                math.floor(bar_x + 1),
                                fill_y,
                                bar_w - 2,
                                fill_h,
                                fill_r, fill_g, 0.0, 1.0
                            )
                        end
                    end
                end
            end
        end
    end
end