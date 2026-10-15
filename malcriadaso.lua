local ffi = rawget(_G, "ffi")

local KEY_NAMES = {
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
    [keys.SPACE] = "SPACE", [keys.SHIFT] = "SHIFT", [keys.CTRL] = "CTRL", [keys.ALT] = "ALT",
    [keys.TAB] = "TAB", [keys.ENTER] = "ENTER", [keys.BACKSPACE] = "BKSP",
    [keys.ESCAPE] = "ESC", [keys.END] = "END",
    [keys.LEFT] = "LEFT", [keys.RIGHT] = "RIGHT", [keys.UP] = "UP", [keys.DOWN] = "DOWN",
}

local waiting_for_key = false
local keybind_target = nil
local keybind_target_field = nil

local function key_name(k)
    if not k or k == 0 then return "NONE" end
    return KEY_NAMES[k] or ("#" .. tostring(k))
end

local function keybind_button(label, store, field, default)
    local cur = store[field] or default or 0
    local name = (waiting_for_key and keybind_target == store and keybind_target_field == field)
        and "..." or key_name(cur)
    if imgui.button(name .. "##kb_" .. label) then
        waiting_for_key = true
        keybind_target = store
        keybind_target_field = field
    end
    imgui.same_line()
    imgui.text(label)
end

local function key_down(k)
    if not k or k == 0 then return false end
    return input.is_key_down(k)
end

local function rising_toggle(store, key_field, enabled_field, prev_field)
    local k = store[key_field]
    local down = key_down(k)
    if down and not store[prev_field] then
        store[enabled_field] = not store[enabled_field]
    end
    store[prev_field] = down
end

local ENGINE_CS_OFF = 4352236
local CS_NETCHAN_OFF = 24
local CS_CHOKED_OFF = 19024
local NC_ACK_OFF = 16
local NC_CHOKED_OFF = 28
local NC_CLEAR_OFF = 0xB8
local WEAPON_NEXT_PRIMARY = 2400
local ROLL_BITS_AS_FLOAT = 1.0179e37
local GET_ACTIVE_WEAPON_RVA = 0x12240

local net_snap = { has = false, ack = 0, choked = 0 }

local function get_engine_base()
    local ok, b = pcall(modules.get_engine_base)
    if ok and b and b ~= 0 then return b end
    return 0
end

local function get_client_base()
    local ok, b = pcall(modules.get_client_base)
    if ok and b and b ~= 0 then return b end
    return 0
end

local function read_i(addr)
    local ok, v = pcall(memory.read_int, addr)
    if ok and v then return v end
    return nil
end

local function write_i(addr, val)
    return pcall(memory.write_int, addr, val, false)
end

local function get_raw_clientstate()
    local eb = get_engine_base()
    if eb == 0 then return 0 end
    local cs = read_i(eb + ENGINE_CS_OFF)
    if not cs or cs == 0 then return 0 end
    return cs
end

local function get_netchan_from_cs(cs)
    if not cs or cs == 0 then return 0 end
    local nc = read_i(cs + CS_NETCHAN_OFF)
    if nc and nc ~= 0 then return nc end
    local ok, ptr = pcall(engine.get_netchan_ptr)
    if ok and ptr and ptr ~= 0 then return ptr end
    return 0
end

local function spoof_netchan(nc)
    if not nc or nc == 0 then return end
    if not net_snap.has then
        local a = read_i(nc + NC_ACK_OFF)
        local c = read_i(nc + NC_CHOKED_OFF)
        if a ~= nil and c ~= nil and a ~= -1 then
            net_snap.ack = a
            net_snap.choked = c
            net_snap.has = true
        end
    end
    write_i(nc + NC_ACK_OFF, -1)
    write_i(nc + NC_CHOKED_OFF, 255)
end

local function restore_netchan(nc)
    if not nc or nc == 0 or not net_snap.has then return end
    local a = read_i(nc + NC_ACK_OFF)
    local c = read_i(nc + NC_CHOKED_OFF)
    if a == -1 then write_i(nc + NC_ACK_OFF, net_snap.ack) end
    if c == 255 then write_i(nc + NC_CHOKED_OFF, net_snap.choked) end
    net_snap.has = false
end

local function write_choked_value(value)
    local cs = get_raw_clientstate()
    if cs == 0 then return false end
    write_i(cs + CS_CHOKED_OFF, value)
    local nc = get_netchan_from_cs(cs)
    if nc ~= 0 then spoof_netchan(nc) end
    return true
end

local function set_clear_time_block(nc, block)
    if not nc or nc == 0 then return end
    if block then
        pcall(memory.write_float, nc + NC_CLEAR_OFF, 999999.0, false)
    else
        pcall(memory.write_float, nc + NC_CLEAR_OFF, 0.0, false)
    end
end

local function get_active_weapon_ptr(lp)
    if not lp then return 0 end
    if lp.get_active_weapon then
        local ok, w = pcall(function() return lp:get_active_weapon() end)
        if ok and w then
            if type(w) == "number" then return w end
            if w.get_index then
                local ok2, idx = pcall(function() return w:get_index() end)
                if ok2 and idx then
                    local ok3, raw = pcall(entity.get_by_index_raw, idx)
                    if ok3 and raw and raw ~= 0 then return raw end
                end
            end
        end
    end
    local cb = get_client_base()
    if cb == 0 or not ffi then return 0 end
    local ok, raw = pcall(function()
        local idx = lp:get_index()
        local ent = entity.get_by_index_raw(idx)
        if not ent or ent == 0 then return 0 end
        local fn = ffi.cast("void*(__thiscall*)(void*)", cb + GET_ACTIVE_WEAPON_RVA)
        local w = fn(ffi.cast("void*", ent))
        return tonumber(ffi.cast("uintptr_t", w)) or 0
    end)
    if ok and raw then return raw end
    return 0
end

local function zero_weapon_cooldown(lp)
    local w = get_active_weapon_ptr(lp)
    if not w or w == 0 then return end
    pcall(memory.write_float, w + WEAPON_NEXT_PRIMARY, 0.0, false)
end

local fakelag = {
    enabled = false, always = false, key_toggle = 0, key_hold = 0,
    amount = 8, counter = 0, prev_toggle = false, active_toggle = false,
}
local choke1 = { enabled = false, key = keys.KEY_F, value = 45, prev = false }
local choke2 = { enabled = false, key = 0, value = 45, prev = false }
local bleed = { enabled = false, key = 0, value = 45, prev = false }
local bleed_imp = { enabled = false, key = 0, value = 45, prev = false }
local rf = { enabled = false, key = keys.KEY_F, value = 25 }
local rfplus = { enabled = false, key = 0, prev = false, active = false }
local roll = { enabled = false, key = keys.KEY_X }
local namebug = {
    enabled = false, mode = 0, key = keys.END, newline_count = 2,
    line1 = "A", line2 = "L", line3 = "I", line4 = "C", line5 = "E",
    byx_name = "\n\xAD\xAD\xAD\xAD",
}
local aimware = { enabled = false, key = keys.KEY_F, value = 666 }
local aim = {
    enabled = true, aimkey = keys.MOUSE5, fov = 180.0, smooth = 1.0,
    max_distance = 4096.0, target_head = true, silent_aim = false,
    vischeck = true, tank_auto_hit = false, m2_spam_all = false,
}

local locked_entity = nil
local click_phase = false
local IN_ATTACK = 1
local IN_ATTACK2 = 2048

local function normalizeAngle(a)
    while a > 180 do a = a - 360 end
    while a < -180 do a = a + 360 end
    return a
end

local function calcAngle(src, dst)
    local dx = dst.x - src.x
    local dy = dst.y - src.y
    local dz = dst.z - src.z
    local hyp = math.sqrt(dx * dx + dy * dy)
    if hyp < 0.001 then hyp = 0.001 end
    return vector.new(math.deg(math.atan2(-dz, hyp)), math.deg(math.atan2(dy, dx)), 0)
end

local function getFOV(view, aim_ang)
    local dx = normalizeAngle(aim_ang.x - view.x)
    local dy = normalizeAngle(aim_ang.y - view.y)
    return math.sqrt(dx * dx + dy * dy)
end

local function smoothAngles(cur, target, smooth)
    if not smooth or smooth <= 1.0 then return target end
    local f = 1.0 / smooth
    return vector.new(
        cur.x + normalizeAngle(target.x - cur.x) * f,
        cur.y + normalizeAngle(target.y - cur.y) * f,
        0
    )
end

local function is_visible(player)
    if not aim.vischeck then return true end
    local ok, raw = pcall(entity.get_by_index_raw, player:get_index())
    if not ok or not raw or raw == 0 then return true end
    local ok2, dorm = pcall(entity.is_dormant, raw)
    if not ok2 then return true end
    return not dorm
end

local function get_aim_pos(player)
    if aim.target_head then
        local ok, eye = pcall(function() return player:get_eye_position() end)
        if ok and eye and eye.x then return eye end
    end
    local ok2, o = pcall(function() return player:get_origin() end)
    if ok2 and o then return vector.new(o.x, o.y, o.z + 40.0) end
    return nil
end

local function is_valid_locked(ent, eye_pos)
    if not ent then return false end
    local ok_a, alive = pcall(function() return ent:is_alive() end)
    if not ok_a or not alive then return false end
    local ok_t, team = pcall(function() return ent:get_team() end)
    if not ok_t or team ~= 2 then return false end
    if ent.is_incapacitated then
        local ok_i, inc = pcall(function() return ent:is_incapacitated() end)
        if ok_i and inc then return false end
    end
    local ok_o, o = pcall(function() return ent:get_origin() end)
    if not ok_o or not o then return false end
    if vector.distance(eye_pos, o) > aim.max_distance then return false end
    if not is_visible(ent) then return false end
    return true
end

local function getBestTarget(local_player)
    local eye_pos = local_player:get_eye_position()
    if not eye_pos then return nil end
    local view_angs = local_player:get_eye_angles()
    if not view_angs then view_angs = vector.new(0, 0, 0) end
    local local_idx = local_player:get_index()
    local mc = engine.get_max_clients() or 32
    local best = nil
    local best_fov = aim.fov
    for i = 1, mc do
        local player = entity.get_by_index(i)
        if not player then goto continue end
        if i == local_idx then goto continue end
        local ok_a, alive = pcall(function() return player:is_alive() end)
        if not ok_a or not alive then goto continue end
        local ok_t, team = pcall(function() return player:get_team() end)
        if not ok_t or team ~= 2 then goto continue end
        if player.is_incapacitated then
            local ok_i, inc = pcall(function() return player:is_incapacitated() end)
            if ok_i and inc then goto continue end
        end
        if not is_visible(player) then goto continue end
        local aim_pos = get_aim_pos(player)
        if not aim_pos then goto continue end
        local dist = vector.distance(eye_pos, player:get_origin())
        if dist > aim.max_distance then goto continue end
        local aim_angle = calcAngle(eye_pos, aim_pos)
        local fov = getFOV(view_angs, aim_angle)
        if fov > best_fov then goto continue end
        best_fov = fov
        best = { player = player, aim_pos = aim_pos, aim_angle = aim_angle }
        ::continue::
    end
    return best
end

local function get_zombie_class(lp)
    if not lp or not lp.get_zombie_class then return 0 end
    local ok, zc = pcall(function() return lp:get_zombie_class() end)
    if ok and zc then return zc end
    return 0
end

local function is_tank(lp)
    local zc = get_zombie_class(lp)
    if zc == 8 then return true end
    if zombie_class and zombie_class.TANK and zc == zombie_class.TANK then return true end
    return false
end

local function apply_click_spam(cmd, local_player)
    local want_m1 = aim.tank_auto_hit and is_tank(local_player)
    local want_m2 = aim.m2_spam_all
    if not want_m1 and not want_m2 then return end
    click_phase = not click_phase
    local buttons = cmd:get_buttons()
    if want_m1 then
        if click_phase then buttons = buttons | IN_ATTACK else buttons = buttons & ~IN_ATTACK end
    end
    if want_m2 then
        if click_phase then buttons = buttons | IN_ATTACK2 else buttons = buttons & ~IN_ATTACK2 end
    end
    cmd:set_buttons(buttons)
end

local function build_name_message()
    if namebug.mode == 1 then
        return namebug.byx_name or "\n"
    end
    local nl = string.rep("\r", namebug.newline_count or 0)
    local parts = { namebug.line1 or "", namebug.line2 or "", namebug.line3 or "", namebug.line4 or "", namebug.line5 or "" }
    local out = nl
    for i = 1, #parts do
        if parts[i] ~= "" then out = out .. parts[i] .. nl end
    end
    return out
end

local function apply_aimware_choke()
    local val = math.floor(aimware.value or 0)
    if val < 0 then val = 0 end
    if val > 4096 then val = 4096 end
    write_choked_value(val)
end

local function sum_bleed_choke()
    local sum = 0
    if choke1.enabled then sum = sum + (choke1.value or 0) end
    if choke2.enabled then sum = sum + (choke2.value or 0) end
    if bleed.enabled then sum = sum + (bleed.value or 0) end
    if bleed_imp.enabled then sum = sum + (bleed_imp.value or 0) end
    return sum
end

function on_cl_move_pre()
    if waiting_for_key then return end

    rising_toggle(choke1, "key", "enabled", "prev")
    rising_toggle(choke2, "key", "enabled", "prev")
    rising_toggle(bleed, "key", "enabled", "prev")
    rising_toggle(bleed_imp, "key", "enabled", "prev")
    rising_toggle(rfplus, "key", "active", "prev")

    local ft = fakelag
    if ft.key_toggle and ft.key_toggle ~= 0 then
        local td = key_down(ft.key_toggle)
        if td and not ft.prev_toggle then
            ft.active_toggle = not ft.active_toggle
        end
        ft.prev_toggle = td
    end

    local lp = client.get_local_player()
    local need_choke = sum_bleed_choke()
    local rf_hold = rf.enabled and key_down(rf.key)
    local aw_hold = aimware.enabled and key_down(aimware.key)

    if aw_hold then
        apply_aimware_choke()
    elseif need_choke > 0 then
        write_choked_value(need_choke)
    end

    if rf_hold then
        local cs = get_raw_clientstate()
        local nc = get_netchan_from_cs(cs)
        if nc ~= 0 then spoof_netchan(nc) end
        pcall(client.set_extra_commands, math.floor(rf.value or 0))
    else
        pcall(client.set_extra_commands, 0)
    end

    local still_spoof = aw_hold or rf_hold or need_choke > 0
    if not still_spoof and net_snap.has then
        local allow_restore = bleed_imp.enabled or (not bleed.enabled and not choke1.enabled and not choke2.enabled)
        if allow_restore then
            local cs = get_raw_clientstate()
            restore_netchan(get_netchan_from_cs(cs))
        end
    end

    local fl_active = ft.enabled and (ft.always or ft.active_toggle or key_down(ft.key_hold))
    if fl_active then
        local n = math.floor(ft.amount or 1)
        if n < 1 then n = 1 end
        if n > 14 then n = 14 end
        if ft.counter < n then
            ft.counter = ft.counter + 1
            pcall(client.set_send_packet, false)
            local cs = get_raw_clientstate()
            set_clear_time_block(get_netchan_from_cs(cs), true)
        else
            ft.counter = 0
            pcall(client.set_send_packet, true)
            local cs = get_raw_clientstate()
            set_clear_time_block(get_netchan_from_cs(cs), false)
        end
    else
        ft.counter = 0
        pcall(client.set_send_packet, true)
    end

    if namebug.enabled and key_down(namebug.key) then
        local msg = build_name_message()
        if msg and msg ~= "" then
            pcall(client.execnormal, 'setinfo name "' .. msg .. '"')
        end
    end

    if rfplus.enabled and rfplus.active and lp then
        zero_weapon_cooldown(lp)
    end
end

function on_create_move(cmd, local_player)
    if not cmd then return end
    if waiting_for_key then return end

    if roll.enabled and key_down(roll.key) then
        local angles = cmd:get_viewangles()
        if angles then
            angles.z = ROLL_BITS_AS_FLOAT
            cmd:set_viewangles(angles)
        end
    end

    if rfplus.enabled and rfplus.active and local_player then
        zero_weapon_cooldown(local_player)
    end

    if not local_player or not local_player:is_alive() then
        locked_entity = nil
        return
    end
    if not engine.is_in_game() then
        locked_entity = nil
        return
    end
    if not aim.enabled then
        locked_entity = nil
        return
    end

    local team = local_player:get_team()
    if team ~= 3 then
        locked_entity = nil
        return
    end

    if not key_down(aim.aimkey) then
        locked_entity = nil
        return
    end

    local eye_pos = local_player:get_eye_position()
    if not eye_pos then return end

    if locked_entity and not is_valid_locked(locked_entity, eye_pos) then
        locked_entity = nil
    end

    if not locked_entity then
        local t = getBestTarget(local_player)
        if t then locked_entity = t.player end
    end

    if locked_entity then
        local aim_pos = get_aim_pos(locked_entity)
        if aim_pos then
            local aim_angle = calcAngle(eye_pos, aim_pos)
            local current = cmd:get_viewangles()
            local final
            if aim.smooth > 1.0 then
                final = smoothAngles(current, aim_angle, aim.smooth)
            else
                final = aim_angle
            end
            final.x = math.clamp(normalizeAngle(final.x), -89.0, 89.0)
            final.y = normalizeAngle(final.y)
            final.z = 0
            cmd:set_viewangles(final)
            if not aim.silent_aim then
                engine.set_view_angles(final)
            end
        else
            locked_entity = nil
        end
    end

    apply_click_spam(cmd, local_player)
end

local function draw_checkbox(label, store, field)
    local c, v = imgui.checkbox(label, store[field])
    if c then store[field] = v end
end

local function draw_slider_int(label, store, field, minv, maxv)
    local c, v = imgui.slider_int(label, store[field], minv, maxv)
    if c then store[field] = v end
end

local function draw_slider_float(label, store, field, minv, maxv)
    local c, v = imgui.slider_float(label, store[field], minv, maxv)
    if c then store[field] = v end
end

local function ui_exploits()
    imgui.text("Fakelag")
    draw_checkbox("Enable Fakelag", fakelag, "enabled")
    if fakelag.enabled then
        draw_checkbox("Always on", fakelag, "always")
        keybind_button("Toggle key", fakelag, "key_toggle", 0)
        keybind_button("Hold key", fakelag, "key_hold", 0)
        draw_slider_int("Amount", fakelag, "amount", 1, 14)
    end
    imgui.separator()
    imgui.text("Choke Exploit 1")
    draw_checkbox("Enable Choke 1", choke1, "enabled")
    keybind_button("Choke 1 key (toggle)", choke1, "key", keys.KEY_F)
    draw_slider_int("Choke 1 value", choke1, "value", 0, 500)
    imgui.separator()
    imgui.text("Choke Exploit 2")
    draw_checkbox("Enable Choke 2", choke2, "enabled")
    keybind_button("Choke 2 key (toggle)", choke2, "key", 0)
    draw_slider_int("Choke 2 value", choke2, "value", 0, 500)
    imgui.separator()
    imgui.text("Bleed")
    draw_checkbox("Enable Bleed", bleed, "enabled")
    keybind_button("Bleed key (toggle)", bleed, "key", 0)
    draw_slider_int("Bleed value", bleed, "value", 0, 500)
    imgui.separator()
    imgui.text("Bleed Improved")
    draw_checkbox("Enable Bleed Improved", bleed_imp, "enabled")
    keybind_button("Bleed Imp key (toggle)", bleed_imp, "key", 0)
    draw_slider_int("Bleed Imp value", bleed_imp, "value", 0, 500)
    imgui.separator()
    imgui.text("Rapid Fire")
    draw_checkbox("Enable Rapid Fire", rf, "enabled")
    keybind_button("RF key (hold)", rf, "key", keys.KEY_F)
    draw_slider_int("RF extra cmds", rf, "value", 1, 100)
    imgui.separator()
    imgui.text("Rapid Fire+")
    draw_checkbox("Enable RF+", rfplus, "enabled")
    keybind_button("RF+ key (toggle)", rfplus, "key", 0)
end

local function ui_misc()
    imgui.text("Roll / TP")
    draw_checkbox("Enable Roll", roll, "enabled")
    keybind_button("Roll key (hold)", roll, "key", keys.KEY_X)
    imgui.separator()
    imgui.text("NameBug")
    draw_checkbox("Enable NameBug", namebug, "enabled")
    keybind_button("NameBug key (hold)", namebug, "key", keys.END)
    local modes = { "Setinfo newlines", "Byx blank name" }
    local mc, mv = imgui.combo("NameBug mode", namebug.mode, modes)
    if mc then namebug.mode = mv end
    if namebug.mode == 0 then
        draw_slider_int("Newline count", namebug, "newline_count", 0, 8)
        local c, v
        c, v = imgui.input_text("Line 1", namebug.line1)
        if c then namebug.line1 = v end
        c, v = imgui.input_text("Line 2", namebug.line2)
        if c then namebug.line2 = v end
        c, v = imgui.input_text("Line 3", namebug.line3)
        if c then namebug.line3 = v end
        c, v = imgui.input_text("Line 4", namebug.line4)
        if c then namebug.line4 = v end
        c, v = imgui.input_text("Line 5", namebug.line5)
        if c then namebug.line5 = v end
    else
        local c, v = imgui.input_text("Byx name payload", namebug.byx_name)
        if c then namebug.byx_name = v end
    end
end

local function ui_aim_infected()
    imgui.text("Aim Infected")
    draw_checkbox("Enable", aim, "enabled")
    keybind_button("Aim key (hold)", aim, "aimkey", keys.MOUSE5)
    draw_slider_float("FOV", aim, "fov", 1.0, 180.0)
    draw_slider_float("Smooth (1=snap)", aim, "smooth", 1.0, 20.0)
    draw_slider_float("Max distance", aim, "max_distance", 200.0, 8192.0)
    draw_checkbox("Target head", aim, "target_head")
    draw_checkbox("Silent aim", aim, "silent_aim")
    draw_checkbox("Vischeck (dormant)", aim, "vischeck")
    imgui.separator()
    imgui.text("Click spam while aim key")
    draw_checkbox("Tank auto hit (M1)", aim, "tank_auto_hit")
    draw_checkbox("Infected m2 spam all (M2)", aim, "m2_spam_all")
end

local function ui_aimware()
    imgui.text("Aimware Choke")
    draw_checkbox("Enable Aimware Choke", aimware, "enabled")
    keybind_button("Choke key (hold)", aimware, "key", keys.KEY_F)
    draw_slider_int("Choke value", aimware, "value", 0, 4096)
end

pcall(function()
    menu.add_main_tab("Storm", function()
        imgui.text("Storm")
        imgui.separator()
        imgui.text("Subtabs: Exploits | Misc | Aim Infected | Aimware")
    end)
end)

pcall(function()
    menu.add_sub_tab("Storm", "Exploits", function()
        ui_exploits()
    end)
end)

pcall(function()
    menu.add_sub_tab("Storm", "Misc", function()
        ui_misc()
    end)
end)

pcall(function()
    menu.add_sub_tab("Storm", "Aim Infected", function()
        ui_aim_infected()
    end)
end)

pcall(function()
    menu.add_sub_tab("Storm", "Aimware", function()
        ui_aimware()
    end)
end)

function on_end_scene()
    if not waiting_for_key or not keybind_target or not keybind_target_field then
        return
    end
    if imgui.begin("Keybind", 0) then
        imgui.text("Press a key...")
        imgui.text("ESC cancel")
        imgui["end"]()
    end
    for k, _ in pairs(KEY_NAMES) do
        if input.is_key_pressed(k) then
            if k == keys.ESCAPE then
                waiting_for_key = false
                keybind_target = nil
                keybind_target_field = nil
            else
                keybind_target[keybind_target_field] = k
                waiting_for_key = false
                keybind_target = nil
                keybind_target_field = nil
            end
            break
        end
    end
end

function on_unload()
    pcall(client.set_extra_commands, 0)
    pcall(client.set_send_packet, true)
    local cs = get_raw_clientstate()
    local nc = get_netchan_from_cs(cs)
    restore_netchan(nc)
    set_clear_time_block(nc, false)
    locked_entity = nil
    fakelag.counter = 0
    net_snap.has = false
end
