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

local net_snap = { has = false, ack = 0, choked = 0 }

local function get_engine_base()
    local ok, b = pcall(modules.get_engine_base)
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

local choke1 = { enabled = false, key = keys.KEY_F, value = 45, prev = false }
local choke2 = { enabled = false, key = 0, value = 45, prev = false }
local bleed = { enabled = false, key = 0, value = 45, prev = false }
local bleed_imp = { enabled = false, key = 0, value = 45, prev = false }
local aimware = { enabled = false, key = keys.KEY_F, value = 666 }

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

    local need_choke = sum_bleed_choke()
    local aw_hold = aimware.enabled and key_down(aimware.key)

    if aw_hold then
        apply_aimware_choke()
    elseif need_choke > 0 then
        write_choked_value(need_choke)
    end

    local still_spoof = aw_hold or need_choke > 0
    if not still_spoof and net_snap.has then
        local allow_restore = bleed_imp.enabled or (not bleed.enabled and not choke1.enabled and not choke2.enabled)
        if allow_restore then
            local cs = get_raw_clientstate()
            restore_netchan(get_netchan_from_cs(cs))
        end
    end
end

local function draw_checkbox(label, store, field)
    local c, v = imgui.checkbox(label, store[field])
    if c then store[field] = v end
end

local function draw_slider_int(label, store, field, minv, maxv)
    local c, v = imgui.slider_int(label, store[field], minv, maxv)
    if c then store[field] = v end
end

local function ui_chokes()
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
end

local function ui_aimware()
    imgui.text("Aimware Choke")
    draw_checkbox("Enable Aimware Choke", aimware, "enabled")
    keybind_button("Choke key (hold)", aimware, "key", keys.KEY_F)
    draw_slider_int("Choke value", aimware, "value", 0, 4096)
end

pcall(function()
    menu.add_sub_tab("Aimbot", "Chokes", function()
        ui_chokes()
    end)
end)

pcall(function()
    menu.add_sub_tab("Aimbot", "Aimware Choke", function()
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
    local cs = get_raw_clientstate()
    local nc = get_netchan_from_cs(cs)
    restore_netchan(nc)
    net_snap.has = false
end
