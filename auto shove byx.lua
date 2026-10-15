-- AutoShove ByxStorm → Heaven
-- Shove automático en rango + cono; aim al target con corrección de movimiento

local IN_ATTACK2 = 2048  -- 1 << 11

local cfg = {
    enabled        = true,
    key            = 0,          -- 0 = siempre si enabled
    hold_mode      = true,
    range          = 75.0,
    cone           = 90.0,       -- medio-ángulo
    aim_at_target  = true,
    vis_check      = false,      -- true si tienes trace.line fiable
    target_specials  = true,
    target_commons   = false,    -- limitado en pure Lua (ver nota)
    target_tank      = false,
    target_witch     = false,
    target_survivors = false,
}

local stats = { shoves = 0, last_dist = 0.0 }

local CID = {
    CTerrorPlayer = 232,
    SurvivorBot   = 275,
    Hunter = 263, Smoker = 270, Boomer = 0,
    Spitter = 272, Jockey = 265, Charger = 99,
    Tank = 276, Witch = 277, Infected = 264,
}

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
    return vector.new(
        math.deg(math.atan2(-dz, hyp)),
        math.deg(math.atan2(dy, dx)),
        0
    )
end

local function angle_forward(angles)
    local p = math.rad(angles.x)
    local y = math.rad(angles.y)
    local cp, sp = math.cos(p), math.sin(p)
    local cy, sy = math.cos(y), math.sin(y)
    return vector.new(cp * cy, cp * sy, -sp)
end

local function get_class_id(ent)
    local ok, id = pcall(function() return ent:get_class_id() end)
    if ok and id then return id end
    return -1
end

local function get_zombie_class(ent)
    local ok, z = pcall(function() return ent:get_zombie_class() end)
    if ok and z then return z end
    return -1
end

-- Centro aprox: origen + 36z (torso) — Byx usa mins/maxs; aquí no siempre hay netvars
local function collision_center(ent)
    local o = ent:get_origin()
    if not o then return nil end
    return vector.new(o.x, o.y, o.z + 36.0)
end

local function want_shove(ent, local_team)
    if not ent or not ent:is_alive() then return false end
    local team = ent:get_team()
    if team == local_team then return false end

    local cid = get_class_id(ent)
    local zc  = get_zombie_class(ent)

    -- Jugadores / bots
    if cid == CID.CTerrorPlayer or cid == CID.SurvivorBot or cid == -1 then
        if team == 2 then
            return cfg.target_survivors
        end
        if team == 3 then
            if zc == 8 or cid == CID.Tank then
                return cfg.target_tank
            end
            return cfg.target_specials
        end
    end

    if cid == CID.Hunter or cid == CID.Smoker or cid == CID.Boomer
        or cid == CID.Spitter or cid == CID.Jockey or cid == CID.Charger then
        return cfg.target_specials
    end
    if cid == CID.Tank then return cfg.target_tank end
    if cid == CID.Witch then return cfg.target_witch end
    if cid == CID.Infected then return cfg.target_commons end

    -- Fallback por team si class_id no viene
    if team == 2 then return cfg.target_survivors end
    if team == 3 then
        if zc == 8 then return cfg.target_tank end
        return cfg.target_specials
    end
    return false
end

local function is_visible(eye, pos, target_idx)
    if not cfg.vis_check then return true end
    local ok, result = pcall(function()
        if type(trace) == "table" and type(trace.line) == "function" then
            return trace.line(eye, pos)
        end
        return nil
    end)
    if not ok or result == nil then return true end
    if type(result) == "number" then return result >= 0.97 end
    if type(result) == "table" then
        local frac = result.fraction or result.frac
        if frac and frac < 0.97 then
            local hit = result.entity_index or result.index
            if hit and hit == target_idx then return true end
            return false
        end
    end
    return true
end

local function key_ok()
    if cfg.key == 0 then return true end
    if not cfg.hold_mode then return true end
    -- key como número de tecla Heaven: usar keys.* si el usuario pone 0 o MOUSE5
    if type(cfg.key) == "number" and cfg.key ~= 0 then
        return input.is_key_down(cfg.key)
    end
    return input.is_key_down(keys.MOUSE5)
end

function on_create_move(cmd, local_player)
    if not cfg.enabled or not cmd or not local_player then return end
    if not local_player:is_alive() then return end
    if not key_ok() then return end

    local eye = local_player:get_eye_position()
    if not eye then return end

    local view = cmd:get_viewangles()
    local forward = angle_forward(view)
    local local_team = local_player:get_team()
    local local_idx  = local_player:get_index()

    local cos_cone = math.cos(math.rad(math.min(cfg.cone, 179.0)))

    local best_ent, best_pos, best_dist, best_idx = nil, nil, cfg.range, nil

    local max_c = engine.get_max_clients() or 32
    -- Si commons/witch: intentar más índices (best-effort)
    local n_end = max_c
    if cfg.target_commons or cfg.target_witch then
        n_end = math.max(max_c, 256)
    end

    for i = 1, n_end do
        local ent = entity.get_by_index(i)
        if ent and i ~= local_idx and want_shove(ent, local_team) then
            local pos = collision_center(ent)
            if pos then
                local dx = pos.x - eye.x
                local dy = pos.y - eye.y
                local dz = pos.z - eye.z
                local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
                if dist > 0 and dist < best_dist then
                    local inv = 1.0 / dist
                    local dot = (dx * inv) * forward.x
                              + (dy * inv) * forward.y
                              + (dz * inv) * forward.z
                    if dot >= cos_cone then
                        best_ent  = ent
                        best_pos  = pos
                        best_dist = dist
                        best_idx  = i
                    end
                end
            end
        end
    end

    if not best_ent then return end
    if not is_visible(eye, best_pos, best_idx) then return end

    if cfg.aim_at_target then
        local ang = calc_angle(eye, best_pos)
        ang.x = clamp_pitch(ang.x)
        ang.y = normalize_angle(ang.y)

        -- Silent move fix (Byx): re-proyectar forward/side respecto al nuevo yaw
        local fm = cmd:get_forwardmove()
        local sm = cmd:get_sidemove()
        if fm ~= 0 or sm ~= 0 then
            local yd = math.rad(ang.y - view.y)
            local c, s = math.cos(yd), math.sin(yd)
            cmd:set_forwardmove(fm * c - sm * s)
            cmd:set_sidemove(fm * s + sm * c)
        end

        cmd:set_viewangles(ang)
        -- No engine.set_view_angles → silent shove (cámara no salta)
    end

    local buttons = cmd:get_buttons()
    cmd:set_buttons(buttons | IN_ATTACK2)

    stats.shoves = stats.shoves + 1
    stats.last_dist = best_dist
end

menu.add_main_tab("AutoShove", function()
    local ch, val

    ch, val = imgui.checkbox("Enabled", cfg.enabled)
    if ch then cfg.enabled = val end

    ch, val = imgui.checkbox("Hold mode (key)", cfg.hold_mode)
    if ch then cfg.hold_mode = val end

    imgui.text_colored(0.55, 0.55, 0.55, 1.0, "key=0 siempre | usa MOUSE5 si hold y key!=0")
    -- Simplificado: toggle hold con MOUSE5 cuando hold_mode y queremos tecla
    ch, val = imgui.checkbox("Use MOUSE5 as key", cfg.key ~= 0)
    if ch then cfg.key = val and keys.MOUSE5 or 0 end

    ch, val = imgui.slider_float("Range", cfg.range, 40.0, 120.0)
    if ch then cfg.range = val end

    ch, val = imgui.slider_float("Cone (half deg)", cfg.cone, 15.0, 180.0)
    if ch then cfg.cone = val end

    ch, val = imgui.checkbox("Aim at target (silent)", cfg.aim_at_target)
    if ch then cfg.aim_at_target = val end

    ch, val = imgui.checkbox("Vis check", cfg.vis_check)
    if ch then cfg.vis_check = val end

    imgui.separator()
    imgui.text("Targets")
    ch, val = imgui.checkbox("Specials", cfg.target_specials)
    if ch then cfg.target_specials = val end
    ch, val = imgui.checkbox("Commons", cfg.target_commons)
    if ch then cfg.target_commons = val end
    ch, val = imgui.checkbox("Tank", cfg.target_tank)
    if ch then cfg.target_tank = val end
    ch, val = imgui.checkbox("Witch", cfg.target_witch)
    if ch then cfg.target_witch = val end
    ch, val = imgui.checkbox("Survivors", cfg.target_survivors)
    if ch then cfg.target_survivors = val end

    imgui.separator()
    imgui.text(string.format("Shoves: %d | Last dist: %.1f", stats.shoves, stats.last_dist))
    imgui["end"]()
end)

client.print("[AutoShove] ByxStorm port — range/cone/aim | tab AutoShove")