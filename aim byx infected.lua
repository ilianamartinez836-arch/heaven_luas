-- AimInfected ByxStorm → Heaven
-- Hold key, Survivor más cercano, head, vis-check, 1-tick eye advance, cámara visible

local cfg = {
    enabled   = true,
    key       = keys.MOUSE5,
    max_dist  = 4096.0,
    smooth    = 1.0,      -- 1 = instantáneo
    vis_check = true,
    head_z    = 64.0,     -- fallback si no hay hitbox API (altura cabeza aprox)
}

local TICK_INTERVAL = 1.0 / 30.0
local MAX_ADVANCE   = 16.0

local function normalize_angle(a)
    while a > 180 do a = a - 360 end
    while a < -180 do a = a + 360 end
    return a
end

local function clamp_pitch(p)
    if p > 89 then return 89 end
    if p < -89 then return -89 end
    return p
end

local function calc_angle(src, dst)
    local dx = dst.x - src.x
    local dy = dst.y - src.y
    local dz = dst.z - src.z
    local hyp = math.sqrt(dx * dx + dy * dy)
    local pitch = math.deg(math.atan2(-dz, hyp))
    local yaw   = math.deg(math.atan2(dy, dx))
    return vector.new(pitch, yaw, 0)
end

local function vec_length(v)
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

-- Avance 1 tick de velocidad, clamp 16u (igual Byx)
local function eye_advance(lp, eye_real)
    local vel = lp:get_velocity()
    if not vel then return eye_real end

    local ax = vel.x * TICK_INTERVAL
    local ay = vel.y * TICK_INTERVAL
    local az = vel.z * TICK_INTERVAL
    local len = math.sqrt(ax * ax + ay * ay + az * az)

    if len > MAX_ADVANCE and len > 0 then
        local s = MAX_ADVANCE / len
        ax, ay, az = ax * s, ay * s, az * s
    end

    return vector.new(eye_real.x + ax, eye_real.y + ay, eye_real.z + az)
end

-- Punto de cabeza: eye del survivor o origen + head_z
local function get_head_pos(ent)
    local ok, eye = pcall(function() return ent:get_eye_position() end)
    if ok and eye and (eye.x ~= 0 or eye.y ~= 0 or eye.z ~= 0) then
        return eye
    end
    local origin = ent:get_origin()
    if not origin then return nil end
    return vector.new(origin.x, origin.y, origin.z + cfg.head_z)
end

local function is_visible(eye_real, aim_pos, target_index)
    if not cfg.vis_check then return true end

    -- Heaven: trace.line si existe
    local ok, result = pcall(function()
        if type(trace) == "table" and type(trace.line) == "function" then
            return trace.line(eye_real, aim_pos)
        end
        return nil
    end)

    if not ok or result == nil then
        return true -- sin API de trace: no bloquear aim
    end

    if type(result) == "number" then
        return result >= 0.97
    end
    if type(result) == "table" then
        local frac = result.fraction or result.frac
        if frac and frac < 0.97 then
            local hit = result.entity_index or result.index
            if hit and hit == target_index then return true end
            return false
        end
        return true
    end
    return true
end

local function is_valid_survivor(ent, local_index, local_team)
    if not ent then return false end
    local idx = ent:get_index()
    if not idx or idx == local_index then return false end
    if not ent:is_alive() then return false end

    local team = ent:get_team()
    if team == local_team then return false end
    if team ~= 2 then return false end -- solo Survivors

    local ok_g, ghost = pcall(function() return ent:is_ghost() end)
    if ok_g and ghost then return false end

    local ok_i, incap = pcall(function() return ent:is_incapacitated() end)
    if ok_i and incap then return false end

    return true
end

local function find_best(lp, eye_real, eye_aim)
    local local_index = lp:get_index()
    local local_team  = lp:get_team()
    local max_c = engine.get_max_clients() or 32

    local best_dist = cfg.max_dist
    local best_aim  = nil

    for i = 1, max_c do
        local ent = entity.get_by_index(i)
        if is_valid_survivor(ent, local_index, local_team) then
            local aim_pos = get_head_pos(ent)
            if aim_pos then
                local dist = vector.distance(eye_aim, aim_pos)
                if dist < best_dist then
                    if is_visible(eye_real, aim_pos, i) then
                        best_dist = dist
                        best_aim  = aim_pos
                    end
                end
            end
        end
    end

    return best_aim
end

function on_create_move(cmd, local_player)
    if not cfg.enabled or not cmd or not local_player then return end
    if not local_player:is_alive() then return end
    if local_player:get_team() ~= 3 then return end -- Infected
    if not input.is_key_down(cfg.key) then return end

    local eye_real = local_player:get_eye_position()
    if not eye_real then return end

    local eye_aim = eye_advance(local_player, eye_real)
    local target  = find_best(local_player, eye_real, eye_aim)
    if not target then return end

    local view = cmd:get_viewangles()
    local ang  = calc_angle(eye_aim, target)

    local t = (cfg.smooth <= 1.0) and 1.0 or (1.0 / cfg.smooth)
    local dx = normalize_angle(ang.x - view.x)
    local dy = normalize_angle(ang.y - view.y)

    local final = vector.new(
        clamp_pitch(view.x + dx * t),
        normalize_angle(view.y + dy * t),
        0
    )

    -- Byx: NO silent — cámara real
    cmd:set_viewangles(final)
    engine.set_view_angles(final)
end

menu.add_main_tab("AimInfected", function()
    local ch, val

    ch, val = imgui.checkbox("Enabled", cfg.enabled)
    if ch then cfg.enabled = val end

    ch, val = imgui.slider_float("Max distance", cfg.max_dist, 500.0, 8192.0)
    if ch then cfg.max_dist = val end

    ch, val = imgui.slider_float("Smooth (1=snap)", cfg.smooth, 1.0, 20.0)
    if ch then cfg.smooth = val end

    ch, val = imgui.checkbox("Visibility check", cfg.vis_check)
    if ch then cfg.vis_check = val end

    ch, val = imgui.slider_float("Head Z fallback", cfg.head_z, 40.0, 80.0)
    if ch then cfg.head_z = val end

    imgui.separator()
    imgui.text("Hold MOUSE5 | Infected only | visible camera")
    imgui.text_colored(0.5, 0.5, 0.5, 1.0, "Logica Byx: dist + head + vis + eye advance")
    imgui["end"]()
end)

client.print("[AimInfected] ByxStorm port — hold M5, head, vis, 1-tick advance")