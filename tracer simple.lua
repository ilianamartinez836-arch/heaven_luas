local CONFIG = {
    local_enabled  = true,
    team_enabled   = false,
    enemy_enabled  = false,

    tracer_type    = 5,
    tracer_duration  = 1.5,
    tracer_thickness = 2.5,
    tracer_r = 1.0,
    tracer_g = 0.2,
    tracer_b = 0.2,
    tracer_a = 1.0,
    tracer_rainbow = false,
    tracer_rspeed  = 2.0,

    effect_type    = 2,
    effect_size    = 24.0,
    effect_duration = 1.5,
    effect_r = 1.0,
    effect_g = 0.2,
    effect_b = 0.2,
    effect_a = 1.0,
    effect_rainbow = false,
    effect_rspeed  = 2.0,

    fade_style  = 0,
    max_impacts = 128,
}

local impacts = {}

local function get_screen_coords(world_pos)
    if not engine.world_to_screen_matrix then return nil end
    local mat_ptr = engine.world_to_screen_matrix()
    if not mat_ptr or mat_ptr == 0 then return nil end
    local function read_mat(idx)
        return memory.read_float(mat_ptr + (idx * 4))
    end
    local ok, m00 = pcall(read_mat, 0)
    if not ok then return nil end
    local m01 = read_mat(1); local m02 = read_mat(2); local m03 = read_mat(3)
    local m10 = read_mat(4); local m11 = read_mat(5); local m12 = read_mat(6); local m13 = read_mat(7)
    local m30 = read_mat(12); local m31 = read_mat(13); local m32 = read_mat(14); local m33 = read_mat(15)
    local w = m30 * world_pos.x + m31 * world_pos.y + m32 * world_pos.z + m33
    if w < 0.001 then return nil end
    local inv_w = 1.0 / w
    local screen_x = (m00 * world_pos.x + m01 * world_pos.y + m02 * world_pos.z + m03) * inv_w
    local screen_y = (m10 * world_pos.x + m11 * world_pos.y + m12 * world_pos.z + m13) * inv_w
    local width, height = engine.get_screen_size()
    return {
        x = math.floor((width / 2) + (screen_x * width / 2)),
        y = math.floor((height / 2) - (screen_y * height / 2))
    }
end

local function compute_fade(elapsed, duration)
    local t = math.max(0, math.min(1, 1 - elapsed / duration))
    if CONFIG.fade_style == 0 then return t * t end
    if CONFIG.fade_style == 1 then return t end
    return t > 0.3 and 1.0 or (t / 0.3)
end

local function drand(seed, i)
    local v = math.sin(seed * 127.1 + i * 311.7) * 43758.5453
    return v - math.floor(v)
end

local function get_rainbow_color(speed)
    local time = os.clock() * (speed or 2.0)
    return (math.sin(time) * 0.5) + 0.5,
           (math.sin(time + 2.09439) * 0.5) + 0.5,
           (math.sin(time + 4.18879) * 0.5) + 0.5
end

local function safe_line(x1, y1, x2, y2, r, g, b, a)
    pcall(function()
        draw.line(math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2), r, g, b, a)
    end)
end

local function safe_circle(x, y, rad, segs, r, g, b, a)
    pcall(function()
        draw.circle(math.floor(x), math.floor(y), rad, segs, r, g, b, a)
    end)
end

local function safe_outlined_circle(x, y, rad, segs, r, g, b, a)
    pcall(function()
        draw.outlined_circle(math.floor(x), math.floor(y), rad, segs, r, g, b, a)
    end)
end

local function safe_thick_line(x1, y1, x2, y2, r, g, b, a, thickness)
    if thickness <= 1.0 then
        safe_line(x1, y1, x2, y2, r, g, b, a)
        return
    end
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return end
    local px = -dy / len
    local py = dx / len
    local half = thickness / 2
    for i = -half, half, 0.5 do
        safe_line(x1 + px * i, y1 + py * i, x2 + px * i, y2 + py * i, r, g, b, a)
    end
end

local function draw_tracer(ox, oy, dx, dy, elapsed, seed)
    local s = CONFIG.tracer_type
    local r, g, b = CONFIG.tracer_r, CONFIG.tracer_g, CONFIG.tracer_b
    if CONFIG.tracer_rainbow then
        r, g, b = get_rainbow_color(CONFIG.tracer_rspeed)
    end
    local a = compute_fade(elapsed, CONFIG.tracer_duration) * CONFIG.tracer_a
    local th = CONFIG.tracer_thickness

    if s == 1 then
        safe_thick_line(ox, oy, dx, dy, r, g, b, a, th)
    elseif s == 2 then
        safe_thick_line(ox, oy, dx, dy, r, g, b, a * 0.15, th * 2.5)
        safe_thick_line(ox, oy, dx, dy, r, g, b, a * 0.40, th * 1.5)
        safe_thick_line(ox, oy, dx, dy, r, g, b, a, th)
    elseif s == 3 then
        local segs = 14
        for i = 0, segs - 1, 2 do
            local t0 = i / segs
            local t1 = (i + 0.65) / segs
            safe_thick_line(
                ox + (dx - ox) * t0, oy + (dy - oy) * t0,
                ox + (dx - ox) * t1, oy + (dy - oy) * t1,
                r, g, b, a, th
            )
        end
    elseif s == 4 then
        local segs = 10
        local px = -(dy - oy)
        local py = (dx - ox)
        local plen = math.sqrt(px * px + py * py)
        if plen > 0 then px = px / plen; py = py / plen end
        local prev_x, prev_y = ox, oy
        for i = 1, segs do
            local t = i / segs
            local mx = ox + (dx - ox) * t
            local my = oy + (dy - oy) * t
            if i < segs then
                local off = (drand(seed, i) - 0.5) * 18
                mx = mx + px * off
                my = my + py * off
            end
            safe_thick_line(prev_x, prev_y, mx, my, r, g, b, a, th)
            prev_x, prev_y = mx, my
        end
    elseif s == 5 then
        safe_thick_line(ox, oy, dx, dy, r, g, b, a * 0.20, th * 3.5)
        safe_thick_line(ox, oy, dx, dy, r, g, b, a * 0.60, th * 1.5)
        safe_thick_line(ox, oy, dx, dy, 1, 1, 1, a, th * 0.5)
    end
end

local function draw_effect(dx, dy, elapsed)
    local s = CONFIG.effect_type
    if s <= 1 then return end
    local r, g, b = CONFIG.effect_r, CONFIG.effect_g, CONFIG.effect_b
    if CONFIG.effect_rainbow then
        r, g, b = get_rainbow_color(CONFIG.effect_rspeed)
    end
    local a = compute_fade(elapsed, CONFIG.effect_duration) * CONFIG.effect_a
    local sz = CONFIG.effect_size
    local pct = elapsed / CONFIG.effect_duration

    if s == 2 then
        safe_outlined_circle(dx, dy, sz * pct, 32, r, g, b, a)
    elseif s == 3 then
        local h = sz * 0.5
        safe_line(dx - h, dy - h, dx + h, dy + h, r, g, b, a)
        safe_line(dx + h, dy - h, dx - h, dy + h, r, g, b, a)
    elseif s == 4 then
        local rad = math.max(1, sz * 0.35 * (1 - pct))
        safe_circle(dx, dy, rad, 20, r, g, b, a)
    elseif s == 5 then
        local len = sz * pct
        for i = 0, 7 do
            local angle = (i / 8) * math.pi * 2
            safe_line(
                dx + math.cos(angle) * len * 0.25,
                dy + math.sin(angle) * len * 0.25,
                dx + math.cos(angle) * len,
                dy + math.sin(angle) * len,
                r, g, b, a
            )
        end
    elseif s == 6 then
        local outer = sz * pct
        safe_outlined_circle(dx, dy, outer, 48, r, g, b, a)
        safe_outlined_circle(dx, dy, outer * 0.6, 32, r, g, b, a * 0.4)
        if pct < 0.4 then
            safe_circle(dx, dy, sz * 0.15, 16, 1, 1, 1, a * (1 - pct / 0.4))
        end
    end
end

events.register("bullet_impact")

function on_game_event(name, event)
    if name ~= "bullet_impact" then return end
    local local_player = client.get_local_player()
    if not local_player then return end

    local userid = event:get_int("userid")
    local player_idx = engine.get_player_for_userid(userid)
    if not player_idx or player_idx == 0 then return end

    local my_idx = local_player:get_index()
    local allowed = false
    local is_local = (player_idx == my_idx)

    if is_local then
        allowed = CONFIG.local_enabled
    else
        local shooter = entity.get_by_index(player_idx)
        if shooter then
            if shooter:get_team() == local_player:get_team() then
                allowed = CONFIG.team_enabled
            else
                allowed = CONFIG.enemy_enabled
            end
        end
    end
    if not allowed then return end

    if #impacts >= CONFIG.max_impacts then
        table.remove(impacts, 1)
    end

    local start_pos
    if is_local then
        local eye_pos = local_player:get_eye_position()
        local angles = engine.get_view_angles()
        local fwd, right, up = utils.angle_vectors(angles)
        start_pos = vector.new(
            eye_pos.x + (fwd.x * 30) + (right.x * 8) - (up.x * 10),
            eye_pos.y + (fwd.y * 30) + (right.y * 8) - (up.y * 10),
            eye_pos.z + (fwd.z * 30) + (right.z * 8) - (up.z * 10)
        )
    else
        local shooter = entity.get_by_index(player_idx)
        if shooter then
            start_pos = shooter:get_eye_position()
        end
    end
    if not start_pos then return end

    table.insert(impacts, {
        target_pos = vector.new(event:get_float("x"), event:get_float("y"), event:get_float("z")),
        start_pos = start_pos,
        time = os.clock(),
        seed = math.random(1, 9999),
    })
end

function on_paint()
    if not engine.is_in_game() then return end
    if #impacts == 0 then return end

    local now = os.clock()
    local max_life = math.max(CONFIG.tracer_duration, CONFIG.effect_duration)

    for i = #impacts, 1, -1 do
        local impact = impacts[i]
        local elapsed = now - impact.time
        if elapsed > max_life then
            table.remove(impacts, i)
        else
            local target_2d = get_screen_coords(impact.target_pos)
            local start_2d = get_screen_coords(impact.start_pos)
            if target_2d and start_2d then
                if elapsed < CONFIG.tracer_duration then
                    draw_tracer(start_2d.x, start_2d.y, target_2d.x, target_2d.y, elapsed, impact.seed)
                end
                if elapsed < CONFIG.effect_duration then
                    draw_effect(target_2d.x, target_2d.y, elapsed)
                end
            end
        end
    end
end

function on_unload()
    impacts = {}
end

client.print("[Tracer] loaded | type 1=Line 2=Beam 3=Dashed 4=Electric 5=Rail | effect 1=None 2=Ring 3=Cross 4=Dot 5=Splash 6=Shockwave")
