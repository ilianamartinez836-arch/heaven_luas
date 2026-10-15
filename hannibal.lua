-- ============================================================
-- Byx Exploits Pack  |  Heaven Hook (L4D2)
-- Exploits + Misc inject + Aimbot subtabs  |  Aika
-- ============================================================

local P = "bxp_"

local function init_bool(n, d)
    if client.get_shared_bool(P .. n, nil) == nil then client.set_shared_bool(P .. n, d) end
end
local function init_int(n, d)
    if client.get_shared_int(P .. n, nil) == nil then client.set_shared_int(P .. n, d) end
end
local function init_float(n, d)
    if client.get_shared_float(P .. n, nil) == nil then client.set_shared_float(P .. n, d) end
end
local function sb(n, d) return client.get_shared_bool(P .. n, d) end
local function si(n, d) return client.get_shared_int(P .. n, d) end
local function sf(n, d) return client.get_shared_float(P .. n, d) end
local function setb(n, v) client.set_shared_bool(P .. n, v) end
local function seti(n, v) client.set_shared_int(P .. n, v) end
local function setf(n, v) client.set_shared_float(P .. n, v) end

-- Aim Infected
init_bool("aim_en", false)
init_int("aim_key", keys.MOUSE5)
init_float("aim_fov", 180.0)
init_float("aim_smooth", 1.0)
init_float("aim_maxdist", 4096.0)
init_bool("aim_head", true)
init_bool("aim_silent", false)

-- Auto Shove
init_bool("shove_en", false)
init_float("shove_range", 85.0)
init_float("shove_cone", 0.55)
init_bool("shove_silent", true)
init_bool("shove_specials", true)
init_bool("shove_commons", true)
init_bool("shove_tank", false)
init_bool("shove_witch", false)
init_bool("shove_surv", false)

-- Movement (Misc inject)
init_bool("bhop_en", true)
init_bool("strafe_en", true)
init_float("strafe_scale", 450.0)
init_float("strafe_air", 300.0)
init_float("strafe_wish", 300.0)
init_float("strafe_max", 250.0)
init_bool("duck_en", false)

-- Exploits
init_bool("choke1_en", false)
init_int("choke1_key", keys.KEY_C)
init_int("choke1_val", 45)
init_bool("choke2_en", false)
init_int("choke2_key", keys.KEY_V)
init_int("choke2_val", 45)
init_bool("bleed_en", false)
init_int("bleed_key", keys.KEY_B)
init_int("bleed_val", 45)
init_bool("bleedi_en", false)
init_int("bleedi_key", keys.KEY_N)
init_int("bleedi_val", 45)
init_bool("flag_en", false)
init_bool("flag_always", false)
init_int("flag_tkey", keys.KEY_F)
init_int("flag_hkey", 0)
init_int("flag_amt", 8)
init_bool("roll_en", false)
init_int("roll_key", keys.KEY_X)
init_bool("rfp_en", false)
init_int("rfp_key", keys.MOUSE5)
init_bool("rfp_hold", true)
init_bool("_boot", true)

-- ------------------------------------------------------------
-- Key system
-- ------------------------------------------------------------
local key_names = {
    [keys.MOUSE1] = "MOUSE1", [keys.MOUSE2] = "MOUSE2", [keys.MOUSE3] = "MOUSE3",
    [keys.MOUSE4] = "MOUSE4", [keys.MOUSE5] = "MOUSE5",
    [keys.KEY_0] = "0", [keys.KEY_1] = "1", [keys.KEY_2] = "2", [keys.KEY_3] = "3",
    [keys.KEY_4] = "4", [keys.KEY_5] = "5", [keys.KEY_6] = "6", [keys.KEY_7] = "7",
    [keys.KEY_8] = "8", [keys.KEY_9] = "9",
    [keys.KEY_A] = "A", [keys.KEY_B] = "B", [keys.KEY_C] = "C", [keys.KEY_D] = "D",
    [keys.KEY_E] = "E", [keys.KEY_F] = "F", [keys.KEY_G] = "G", [keys.KEY_H] = "H",
    [keys.KEY_I] = "I", [keys.KEY_J] = "J", [keys.KEY_K] = "K", [keys.KEY_L] = "L",
    [keys.KEY_M] = "M", [keys.KEY_N] = "N", [keys.KEY_O] = "O", [keys.KEY_P] = "P",
    [keys.KEY_Q] = "Q", [keys.KEY_R] = "R", [keys.KEY_S] = "S", [keys.KEY_T] = "T",
    [keys.KEY_U] = "U", [keys.KEY_V] = "V", [keys.KEY_W] = "W", [keys.KEY_X] = "X",
    [keys.KEY_Y] = "Y", [keys.KEY_Z] = "Z",
    [keys.F1] = "F1", [keys.F2] = "F2", [keys.F3] = "F3", [keys.F4] = "F4",
    [keys.F5] = "F5", [keys.F6] = "F6", [keys.F7] = "F7", [keys.F8] = "F8",
    [keys.F9] = "F9", [keys.F10] = "F10", [keys.F11] = "F11", [keys.F12] = "F12",
    [keys.SPACE] = "SPACE", [keys.SHIFT] = "SHIFT", [keys.CTRL] = "CTRL", [keys.ALT] = "ALT",
    [keys.ESCAPE] = "ESC", [keys.TAB] = "TAB", [keys.ENTER] = "ENTER",
    [keys.LEFT] = "LEFT", [keys.RIGHT] = "RIGHT", [keys.UP] = "UP", [keys.DOWN] = "DOWN",
}

local waiting_for_key = false
local keybind_target = nil

local function keybind_button(shared_name, label, default_key)
    local cur = si(shared_name, default_key)
    local name = key_names[cur] or ("KEY:" .. tostring(cur))
    local btn = (waiting_for_key and keybind_target == shared_name) and "..." or name
    if imgui.button(btn .. "##" .. shared_name) then
        waiting_for_key = true
        keybind_target = shared_name
    end
    imgui.same_line()
    imgui.text(label)
end

local function key_down_shared(shared_name, default_key)
    local k = si(shared_name, default_key)
    if not k or k == 0 then return false end
    return input.is_key_down(k)
end

local toggle_prev = {}
local toggle_state = {
    choke1 = false, choke2 = false, bleed = false, bleedi = false, flag = false, rfp = false,
}

local function rising_toggle(id, is_down)
    local prev = toggle_prev[id] or false
    local edge = is_down and not prev
    toggle_prev[id] = is_down
    if edge then toggle_state[id] = not toggle_state[id] end
    return toggle_state[id]
end

-- ------------------------------------------------------------
-- Memory / net
-- ------------------------------------------------------------
local ENGINE_CS = 4352236
local CS_NETCHAN = 24
local CS_CHOKED = 19024
local NC_ACK = 16
local NC_CHOKED = 28
local NC_CLEARTIME = 0xB8
local WEAPON_NEXT = 0x960
local GET_WPN = 0x12240
local ROLL_FLOAT = 1.017900337e37

local ffi_ok, ffi = pcall(require, "ffi")
local get_wpn_fn = nil
if ffi_ok and ffi then
    pcall(function()
        local base = modules.get_client_base()
        if base and base ~= 0 then
            get_wpn_fn = ffi.cast("void*(__thiscall*)(void*)", base + GET_WPN)
        end
    end)
end

local function get_cs()
    local eng = modules.get_engine_base()
    if not eng or eng == 0 then return 0 end
    local ok, cs = pcall(memory.read_int, eng + ENGINE_CS)
    if ok and cs and cs ~= 0 then return cs end
    return 0
end

local function get_nc(cs)
    if cs and cs ~= 0 then
        local ok, nc = pcall(memory.read_int, cs + CS_NETCHAN)
        if ok and nc and nc ~= 0 then return nc end
    end
    local ok2, ptr = pcall(function() return engine.get_netchan_ptr() end)
    if ok2 and ptr and ptr ~= 0 then return ptr end
    return 0
end

local function ri(a)
    local ok, v = pcall(memory.read_int, a)
    return ok and v or nil
end
local function wi(a, v) pcall(memory.write_int, a, v, false) end
local function wf(a, v) pcall(memory.write_float, a, v, false) end

local net_genuine = { ack = 0, choked = 0, has = false }

local function capture_genuine(nc)
    if nc == 0 then return end
    local ack = ri(nc + NC_ACK)
    local ch = ri(nc + NC_CHOKED)
    if ack and ack ~= -1 then
        net_genuine.ack = ack
        net_genuine.choked = ch or 0
        net_genuine.has = true
    end
end

local function spoof_netchan(nc)
    if nc == 0 then return end
    wi(nc + NC_ACK, -1)
    wi(nc + NC_CHOKED, 255)
end

local function restore_netchan()
    local nc = get_nc(get_cs())
    if nc == 0 or not net_genuine.has then return end
    if ri(nc + NC_ACK) == -1 then wi(nc + NC_ACK, net_genuine.ack) end
    if ri(nc + NC_CHOKED) == 255 then wi(nc + NC_CHOKED, net_genuine.choked) end
end

local function write_choked(value)
    local cs = get_cs()
    if cs == 0 then return end
    local nc = get_nc(cs)
    capture_genuine(nc)
    wi(cs + CS_CHOKED, value)
    spoof_netchan(nc)
end

local function get_weapon_ptr(lp)
    if not lp then return 0 end
    local ok, wep = pcall(function() return lp:get_active_weapon() end)
    if ok and wep then
        if type(wep) == "number" and wep ~= 0 then return wep end
        local ok2, idx = pcall(function() return wep:get_index() end)
        if ok2 and idx and idx > 0 then
            local ok3, raw = pcall(entity.get_by_index_raw, idx)
            if ok3 and raw and raw ~= 0 then return raw end
        end
    end
    if get_wpn_fn then
        local okp, raw = pcall(entity.get_by_index_raw, lp:get_index())
        if okp and raw and raw ~= 0 then
            local okw, wptr = pcall(function()
                return get_wpn_fn(ffi.cast("void*", raw))
            end)
            if okw and wptr then
                local addr = tonumber(ffi.cast("uintptr_t", wptr))
                if addr and addr ~= 0 then return addr end
            end
        end
    end
    return 0
end

-- ------------------------------------------------------------
-- Math
-- ------------------------------------------------------------
local function normalize_angle(a)
    while a > 180 do a = a - 360 end
    while a < -180 do a = a + 360 end
    return a
end

local function normalize_rad(a)
    a = a % (2 * math.pi)
    if a > math.pi then a = a - 2 * math.pi
    elseif a < -math.pi then a = a + 2 * math.pi end
    return a
end

local function angle_diff_rad(a1, a2)
    return normalize_rad(a1 - a2)
end

local function calc_angle(src, dst)
    local dx = dst.x - src.x
    local dy = dst.y - src.y
    local dz = dst.z - src.z
    local hyp = math.sqrt(dx * dx + dy * dy)
    if hyp < 0.001 then hyp = 0.001 end
    local pitch = math.deg(math.atan2(-dz, hyp))
    local yaw = math.deg(math.atan2(dy, dx))
    return vector.new(pitch, yaw, 0)
end

local function get_fov(view, aim)
    local dx = normalize_angle(aim.x - view.x)
    local dy = normalize_angle(aim.y - view.y)
    return math.sqrt(dx * dx + dy * dy)
end

local function smooth_angles(cur, target, smooth)
    if not smooth or smooth <= 1.0 then return target end
    local f = 1.0 / smooth
    return vector.new(
        cur.x + normalize_angle(target.x - cur.x) * f,
        cur.y + normalize_angle(target.y - cur.y) * f,
        0
    )
end

local IN_JUMP = 2
local IN_DUCK = 4
local IN_ATTACK2 = 2048
local MOVETYPE_NOCLIP = 8
local MOVETYPE_LADDER = 9
local MOVETYPE_OBSERVER = 10

local flag_counter = 0
local last_bleedi = false
local last_choke_any = false

-- ------------------------------------------------------------
-- Aim Infected (rehecho)
-- ------------------------------------------------------------
local function is_valid_survivor(lp, ent)
    if not ent then return false end
    local ok_alive, alive = pcall(function() return ent:is_alive() end)
    if not ok_alive or not alive then return false end
    local ok_idx, idx = pcall(function() return ent:get_index() end)
    local ok_my, my = pcall(function() return lp:get_index() end)
    if ok_idx and ok_my and idx == my then return false end
    local ok_team, team = pcall(function() return ent:get_team() end)
    if not ok_team or team ~= 2 then return false end
    if ent.is_incapacitated then
        local ok_inc, inc = pcall(function() return ent:is_incapacitated() end)
        if ok_inc and inc then return false end
    end
    return true
end

local function get_aim_pos(ent, use_head)
    if use_head then
        local ok, eye = pcall(function() return ent:get_eye_position() end)
        if ok and eye and eye.x then return eye end
    end
    local ok2, org = pcall(function() return ent:get_origin() end)
    if ok2 and org then
        return vector.new(org.x, org.y, org.z + 40.0)
    end
    return nil
end

local function apply_aim_infected(cmd, lp)
    if not sb("aim_en", false) then return end
    if waiting_for_key then return end
    if not key_down_shared("aim_key", keys.MOUSE5) then return end

    local ok_team, my_team = pcall(function() return lp:get_team() end)
    if not ok_team or my_team ~= 3 then return end

    if lp.is_ghost then
        local ok_g, ghost = pcall(function() return lp:is_ghost() end)
        if ok_g and ghost then return end
    end

    local ok_eye, eye = pcall(function() return lp:get_eye_position() end)
    if not ok_eye or not eye then return end

    local view = cmd:get_viewangles()
    local max_dist = sf("aim_maxdist", 4096.0)
    local max_fov = sf("aim_fov", 180.0)
    local use_head = sb("aim_head", true)

    local best_ang = nil
    local best_dist = max_dist
    local maxc = engine.get_max_clients() or 32

    for i = 1, maxc do
        local ent = entity.get_by_index(i)
        if not is_valid_survivor(lp, ent) then goto cont end
        local aim_pos = get_aim_pos(ent, use_head)
        if not aim_pos then goto cont end
        local dist = vector.distance(eye, aim_pos)
        if dist > max_dist or dist >= best_dist then goto cont end
        local ang = calc_angle(eye, aim_pos)
        local fov = get_fov(view, ang)
        if fov > max_fov then goto cont end
        best_dist = dist
        best_ang = ang
        ::cont::
    end

    if not best_ang then return end

    local smooth = sf("aim_smooth", 1.0)
    local final = smooth_angles(view, best_ang, smooth)
    final.x = normalize_angle(final.x)
    final.y = normalize_angle(final.y)
    final.z = 0
    cmd:set_viewangles(final)
    if not sb("aim_silent", false) then
        engine.set_view_angles(final)
    end
end

-- ------------------------------------------------------------
-- Auto Shove
-- ------------------------------------------------------------
local function want_shove(ent)
    if not ent then return false end
    local ok_a, alive = pcall(function() return ent:is_alive() end)
    if not ok_a or not alive then return false end
    local ok_t, team = pcall(function() return ent:get_team() end)
    if not ok_t then return false end
    if team == 3 then
        if ent.is_zombie then
            local ok_z, z = pcall(function() return ent:is_zombie() end)
            if ok_z and z and ent.get_zombie_class then
                local ok_c, zc = pcall(function() return ent:get_zombie_class() end)
                if ok_c and zc == 8 then return sb("shove_tank", false) end
            end
        end
        return sb("shove_specials", true)
    end
    if team == 2 then return sb("shove_surv", false) end
    return sb("shove_commons", true)
end

local function apply_shove(cmd, lp)
    if not sb("shove_en", false) then return end
    local ok_t, team = pcall(function() return lp:get_team() end)
    if not ok_t or team ~= 2 then return end

    local eye = lp:get_eye_position()
    local origin = lp:get_origin()
    local range = sf("shove_range", 85.0)
    local cone = sf("shove_cone", 0.55)
    local view = cmd:get_viewangles()
    local fwd = nil
    if utils.angle_vectors then
        local okf, f = pcall(function() return select(1, utils.angle_vectors(view)) end)
        if okf then fwd = f end
    end

    local best, best_d = nil, range
    local maxc = engine.get_max_clients() or 32
    for i = 1, maxc do
        local ent = entity.get_by_index(i)
        if not ent then goto cont end
        local ok_i, idx = pcall(function() return ent:get_index() end)
        local ok_m, my = pcall(function() return lp:get_index() end)
        if ok_i and ok_m and idx == my then goto cont end
        if not want_shove(ent) then goto cont end
        local pos = ent:get_origin()
        local center = vector.new(pos.x, pos.y, pos.z + 36)
        local d = vector.distance(origin, center)
        if d > range or d >= best_d then goto cont end
        if fwd then
            local dx = center.x - eye.x
            local dy = center.y - eye.y
            local dz = center.z - eye.z
            local len = math.sqrt(dx * dx + dy * dy + dz * dz)
            if len > 0.001 then
                local dot = (fwd.x * dx + fwd.y * dy + fwd.z * dz) / len
                if dot < cone then goto cont end
            end
        end
        best_d = d
        best = center
        ::cont::
    end
    if not best then return end

    local ang = calc_angle(eye, best)
    ang.z = 0
    if sb("shove_silent", true) then
        local cur = cmd:get_viewangles()
        local dyaw = math.rad(normalize_angle(ang.y - cur.y))
        local f = cmd:get_forwardmove()
        local s = cmd:get_sidemove()
        cmd:set_forwardmove(f * math.cos(dyaw) + s * math.sin(dyaw))
        cmd:set_sidemove(s * math.cos(dyaw) - f * math.sin(dyaw))
        cmd:set_viewangles(ang)
    else
        cmd:set_viewangles(ang)
        engine.set_view_angles(ang)
    end
    cmd:set_buttons(cmd:get_buttons() | IN_ATTACK2)
end

-- ------------------------------------------------------------
-- Movement / roll / rfp
-- ------------------------------------------------------------
local function apply_bhop(cmd, lp)
    if not sb("bhop_en", true) then return end
    local b = cmd:get_buttons()
    if (b & IN_JUMP) ~= 0 and not lp:is_on_ground() then
        cmd:set_buttons(b & ~IN_JUMP)
    end
end

local function apply_strafe(cmd, lp)
    if not sb("strafe_en", true) then return end
    local mt = lp:get_move_type()
    if mt == MOVETYPE_NOCLIP or mt == MOVETYPE_LADDER or mt == MOVETYPE_OBSERVER then return end
    if lp:is_on_ground() then return end
    local vel = lp:get_velocity()
    local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y)
    if speed < 2.0 then return end
    local max_speed = sf("strafe_max", 250.0)
    local air_accel = sf("strafe_air", 300.0)
    local wish_speed = sf("strafe_wish", 300.0)
    local move_scale = sf("strafe_scale", 450.0)
    local term = (wish_speed / air_accel) / max_speed * 100.0 / speed
    local perfect_delta = 0.0
    if term > -1.0 and term < 1.0 then perfect_delta = math.acos(term) end
    if perfect_delta == 0.0 then return end
    local view = cmd:get_viewangles()
    local yaw_rad = math.rad(view.y)
    local vel_dir = math.atan2(vel.y, vel.x) - yaw_rad
    local wish_ang = math.atan2(-cmd:get_sidemove(), cmd:get_forwardmove())
    local delta = angle_diff_rad(vel_dir, wish_ang)
    local move_dir = delta < 0.0 and (vel_dir + perfect_delta) or (vel_dir - perfect_delta)
    cmd:set_forwardmove(math.cos(move_dir) * move_scale)
    cmd:set_sidemove(-math.sin(move_dir) * move_scale)
end

local function apply_duck(cmd, lp)
    if not sb("duck_en", false) then return end
    if lp:is_on_ground() then return end
    cmd:set_buttons(cmd:get_buttons() | IN_DUCK)
end

local function apply_roll(cmd)
    if not sb("roll_en", false) then return end
    if not key_down_shared("roll_key", keys.KEY_X) then return end
    local a = cmd:get_viewangles()
    a.z = ROLL_FLOAT
    cmd:set_viewangles(a)
end

local function apply_rfp(lp)
    if not sb("rfp_en", false) then return end
    local hold = sb("rfp_hold", true)
    local down = key_down_shared("rfp_key", keys.MOUSE5)
    local active
    if hold then
        active = down
    else
        active = rising_toggle("rfp", down)
    end
    if not active then return end
    local wpn = get_weapon_ptr(lp)
    if wpn ~= 0 then wf(wpn + WEAPON_NEXT, 0.0) end
end

-- ------------------------------------------------------------
-- Hooks
-- ------------------------------------------------------------
function on_cl_move_pre()
    if waiting_for_key then return end
    local choke_val = 0

    if sb("choke1_en", false) then
        if rising_toggle("choke1", key_down_shared("choke1_key", keys.KEY_C)) then
            choke_val = choke_val + si("choke1_val", 45)
        end
    else
        toggle_state.choke1 = false
    end

    if sb("choke2_en", false) then
        if rising_toggle("choke2", key_down_shared("choke2_key", keys.KEY_V)) then
            choke_val = choke_val + si("choke2_val", 45)
        end
    else
        toggle_state.choke2 = false
    end

    if sb("bleed_en", false) then
        if rising_toggle("bleed", key_down_shared("bleed_key", keys.KEY_B)) then
            write_choked(si("bleed_val", 45))
        end
    else
        toggle_state.bleed = false
    end

    if sb("bleedi_en", false) then
        local on = rising_toggle("bleedi", key_down_shared("bleedi_key", keys.KEY_N))
        if on then
            write_choked(si("bleedi_val", 45))
        elseif last_bleedi then
            restore_netchan()
        end
        last_bleedi = on
    else
        if last_bleedi then restore_netchan() end
        last_bleedi = false
        toggle_state.bleedi = false
    end

    if choke_val > 0 then write_choked(choke_val) end

    local choke_any = toggle_state.choke1 or toggle_state.choke2
    if last_choke_any and not choke_any and not toggle_state.bleedi and not toggle_state.bleed then
        restore_netchan()
    end
    last_choke_any = choke_any

    if sb("flag_en", false) then
        local always = sb("flag_always", false)
        local tkey = si("flag_tkey", keys.KEY_F)
        local hkey = si("flag_hkey", 0)
        if tkey ~= 0 then rising_toggle("flag", input.is_key_down(tkey)) end
        local hold = (hkey ~= 0) and input.is_key_down(hkey)
        local active = always or toggle_state.flag or hold
        if active then
            local amount = si("flag_amt", 8)
            if amount < 1 then amount = 1 end
            if amount > 14 then amount = 14 end
            if flag_counter < amount then
                flag_counter = flag_counter + 1
                local nc = get_nc(get_cs())
                if nc ~= 0 then wf(nc + NC_CLEARTIME, 999999.0) end
            else
                flag_counter = 0
            end
        else
            flag_counter = 0
        end
    end
end

function on_create_move(cmd, local_player)
    if not cmd or not local_player then return end
    if waiting_for_key then return end
    if not local_player:is_alive() then return end
    if not engine.is_in_game() then return end

    local mt = local_player:get_move_type()
    if mt ~= MOVETYPE_NOCLIP and mt ~= MOVETYPE_LADDER and mt ~= MOVETYPE_OBSERVER then
        apply_bhop(cmd, local_player)
        apply_strafe(cmd, local_player)
        apply_duck(cmd, local_player)
    end

    apply_aim_infected(cmd, local_player)
    apply_shove(cmd, local_player)
    apply_roll(cmd)
    apply_rfp(local_player)

    if sb("flag_en", false) then
        local always = sb("flag_always", false)
        local hkey = si("flag_hkey", 0)
        local hold = (hkey ~= 0) and input.is_key_down(hkey)
        local active = always or toggle_state.flag or hold
        if active then
            local amount = si("flag_amt", 8)
            if amount < 1 then amount = 1 end
            if amount > 14 then amount = 14 end
            if flag_counter > 0 and flag_counter <= amount then
                pcall(function() client.set_send_packet(false) end)
            else
                pcall(function() client.set_send_packet(true) end)
            end
        else
            pcall(function() client.set_send_packet(true) end)
        end
    end
end

function on_end_scene()
    if not waiting_for_key or not keybind_target then return end
    if imgui.begin("Byx Keybind", 0) then
        imgui.text("Tecla para: " .. tostring(keybind_target))
        imgui.text("ESC = cancelar")
        imgui["end"]()
    end
    for key, name in pairs(key_names) do
        if input.is_key_pressed(key) then
            if key == keys.ESCAPE then
                waiting_for_key = false
                keybind_target = nil
            else
                seti(keybind_target, key)
                client.print("[Byx] " .. keybind_target .. " = " .. name)
                waiting_for_key = false
                keybind_target = nil
            end
            break
        end
    end
end

-- ------------------------------------------------------------
-- UI
-- ------------------------------------------------------------
local function checkbox_s(label, name, default)
    local cur = sb(name, default)
    local ch, val = imgui.checkbox(label, cur)
    if ch then setb(name, val) end
end

local function slider_i(label, name, default, a, b)
    local cur = si(name, default)
    local ch, val = imgui.slider_int(label, cur, a, b)
    if ch then seti(name, val) end
end

local function slider_f(label, name, default, a, b)
    local cur = sf(name, default)
    local ch, val = imgui.slider_float(label, cur, a, b)
    if ch then setf(name, val) end
end

local function feature_box(id, title, height, draw_fn)
    if imgui.begin_child(id, 0, height, true) then
        imgui.text_colored(0.85, 0.75, 1.0, 1.0, title)
        imgui.separator()
        draw_fn()
        imgui.end_child()
    end
end

local STORM_ASCII = {
    "  ____  _                       ",
    " / ___|| |_ ___  _ __ _ __ ___  ",
    " \\___ \\| __/ _ \\| '__| '_ ` _ \\ ",
    "  ___) | || (_) | |  | | | | | |",
    " |____/ \\__\\___/|_|  |_| |_| |_|",
    "        BYX  x  HEAVEN          ",
}

local function draw_exploits_panel()
    imgui.text_colored(0.7, 0.85, 1.0, 1.0, "Byx Exploits Pack")
    imgui.text_colored(0.5, 0.5, 0.5, 1.0, "Cajas independientes  |  misma tecla = ambas activas")
    imgui.spacing()

    imgui.columns(2, "bxp_r1", true)
    feature_box("##c1", "Choke Exploit 1", 120, function()
        checkbox_s("Enable##c1", "choke1_en", false)
        keybind_button("choke1_key", "Key (toggle)", keys.KEY_C)
        slider_i("Value##c1", "choke1_val", 45, 1, 200)
        imgui.text_colored(0.5, 0.5, 0.5, 1.0, toggle_state.choke1 and "ON" or "off")
    end)
    imgui.next_column()
    feature_box("##c2", "Choke Exploit 2", 120, function()
        checkbox_s("Enable##c2", "choke2_en", false)
        keybind_button("choke2_key", "Key (toggle)", keys.KEY_V)
        slider_i("Value##c2", "choke2_val", 45, 1, 200)
        imgui.text_colored(0.5, 0.5, 0.5, 1.0, toggle_state.choke2 and "ON" or "off")
    end)
    imgui.columns(1)
    imgui.spacing()

    imgui.columns(2, "bxp_r2", true)
    feature_box("##bl", "Bleed (raw)", 120, function()
        checkbox_s("Enable##bl", "bleed_en", false)
        keybind_button("bleed_key", "Key (toggle)", keys.KEY_B)
        slider_i("Value##bl", "bleed_val", 45, 1, 200)
        imgui.text_colored(0.7, 0.4, 0.4, 1.0, "SIN restore")
    end)
    imgui.next_column()
    feature_box("##bli", "Bleed Improved", 120, function()
        checkbox_s("Enable##bli", "bleedi_en", false)
        keybind_button("bleedi_key", "Key (toggle)", keys.KEY_N)
        slider_i("Value##bli", "bleedi_val", 45, 1, 200)
        imgui.text_colored(0.4, 0.75, 0.4, 1.0, "CON restore al off")
    end)
    imgui.columns(1)
    imgui.spacing()

    imgui.columns(2, "bxp_r3", true)
    feature_box("##fl", "Fakelag (Byx)", 150, function()
        checkbox_s("Enable##fl", "flag_en", false)
        checkbox_s("Always##fl", "flag_always", false)
        keybind_button("flag_tkey", "Toggle key", keys.KEY_F)
        keybind_button("flag_hkey", "Hold key (0=none)", 0)
        slider_i("Amount 1-14", "flag_amt", 8, 1, 14)
    end)
    imgui.next_column()
    feature_box("##rl", "Roll / TP", 150, function()
        checkbox_s("Enable##rl", "roll_en", false)
        keybind_button("roll_key", "Key (hold)", keys.KEY_X)
        imgui.text_colored(0.5, 0.5, 0.5, 1.0, "viewangles.z magic")
    end)
    imgui.columns(1)
    imgui.spacing()

    feature_box("##rfp", "Rapid Fire+", 105, function()
        checkbox_s("Enable RF+", "rfp_en", false)
        keybind_button("rfp_key", "Key", keys.MOUSE5)
        checkbox_s("Hold mode (off=toggle)", "rfp_hold", true)
        imgui.text_colored(0.5, 0.5, 0.5, 1.0, "weapon+0x960=0  |  sin extra cmds")
    end)
end

pcall(function()
    menu.inject_into_subtab("Exploits", "Exploits", function()
        draw_exploits_panel()
    end)
end)

pcall(function()
    menu.add_sub_tab("Exploits", "Info", function()
        for i = 1, #STORM_ASCII do
            imgui.text_colored(0.65, 0.8, 1.0, 1.0, STORM_ASCII[i])
        end
        imgui.separator()
        imgui.text_colored(0.75, 0.85, 1.0, 1.0, "Byx Exploits Pack  |  Autor: Aika")
        imgui.text_colored(0.5, 0.5, 0.5, 1.0, "Ports ByxStorm → Heaven  |  sin Speed/Custom/RF cmds")
        imgui.spacing()
        imgui.text_wrapped("Choke1+Choke2 suman en el mismo campo. Bleed raw no restaura; Improved si.")
        imgui.text_wrapped("Fakelag amount 6-8 moderado, 12-14 muy notable (techo 14). Roll = hold TP. RF+ solo cooldown arma.")
        imgui.text_wrapped("Movement en Misc (inject). Aim Infected y Auto Shove en Aimbot (subtabs).")
        imgui.text_wrapped("Misma tecla en 2 features = las dos activas.")
    end)
end)

pcall(function()
    menu.inject_into_subtab("Exploits", "Misc", function()
        imgui.text_colored(0.4, 0.9, 0.65, 1.0, "Byx Movement")
        imgui.separator()
        checkbox_s("Bunnyhop", "bhop_en", true)
        checkbox_s("Auto Strafe", "strafe_en", true)
        if sb("strafe_en", true) then
            slider_f("Move Scale", "strafe_scale", 450.0, 100.0, 1000.0)
            slider_f("Air Accel", "strafe_air", 300.0, 50.0, 1000.0)
            slider_f("Wish Speed", "strafe_wish", 300.0, 50.0, 1000.0)
            slider_f("Max Speed term", "strafe_max", 250.0, 50.0, 1000.0)
        end
        checkbox_s("Auto Duck (air)", "duck_en", false)
        imgui.separator()
        imgui.text_colored(0.5, 0.5, 0.5, 1.0, "Auto Shove y Aim Infected estan en Aimbot")
    end)
end)

pcall(function()
    menu.add_sub_tab("Aimbot", "Aim Infected", function()
        imgui.text_colored(1.0, 0.45, 0.45, 1.0, "Aim Infected")
        imgui.text_colored(0.5, 0.5, 0.5, 1.0, "Team Infected (3) → Survivors (2)  |  hold key")
        imgui.separator()
        checkbox_s("Enable Aim Infected", "aim_en", false)
        keybind_button("aim_key", "Aim Key (hold)", keys.MOUSE5)
        slider_f("FOV", "aim_fov", 180.0, 1.0, 180.0)
        slider_f("Smooth (1=snap)", "aim_smooth", 1.0, 1.0, 20.0)
        slider_f("Max Distance", "aim_maxdist", 4096.0, 200.0, 8192.0)
        checkbox_s("Target head (off = chest)", "aim_head", true)
        checkbox_s("Silent (no engine view)", "aim_silent", false)
        imgui.spacing()
        imgui.text_colored(0.5, 0.5, 0.5, 1.0, "Survivor mas cercano dentro de FOV/dist.")
    end)
end)

pcall(function()
    menu.add_sub_tab("Aimbot", "Auto Shove", function()
        imgui.text_colored(1.0, 0.7, 0.35, 1.0, "Auto Shove")
        imgui.text_colored(0.5, 0.5, 0.5, 1.0, "Solo como Survivor (team 2)")
        imgui.separator()
        checkbox_s("Enable Auto Shove", "shove_en", false)
        slider_f("Range", "shove_range", 85.0, 40.0, 150.0)
        slider_f("Cone (dot)", "shove_cone", 0.55, 0.0, 1.0)
        checkbox_s("Silent + move fix", "shove_silent", true)
        imgui.spacing()
        imgui.text("Targets")
        checkbox_s("Specials", "shove_specials", true)
        checkbox_s("Commons", "shove_commons", true)
        checkbox_s("Tank", "shove_tank", false)
        checkbox_s("Witch", "shove_witch", false)
        checkbox_s("Survivors", "shove_surv", false)
    end)
end)

function on_unload()
    pcall(function() client.set_send_packet(true) end)
    restore_netchan()
    waiting_for_key = false
    keybind_target = nil
    client.print("[Byx Pack] unloaded")
end

client.print("[Byx Pack] loaded — Exploits | Misc inject | Aimbot: Aim Infected + Auto Shove")


