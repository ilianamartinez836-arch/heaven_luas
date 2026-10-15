-- language: Lua, file: spinbot.lua, target: Heaven Hook (L4D2)
-- Spinbot con correccion de movimiento. Tu personaje va hacia donde apuntas
-- con WASD, no hacia donde rota el spin.

local KEY = keys.KEY_K
local IN_ATTACK = 1

local cfg = {
    enabled      = false,
    spin_speed   = 15.0,
    pitch        = -89.0,
    fix_movement = true,   -- nueva opcion, ON por default
}

local spin_yaw  = 0.0
local prev_down = false

local function log(s) pcall(client.print, "[spinbot] " .. tostring(s)) end

local function norm_yaw(y)
    y = y % 360
    if y > 180 then y = y - 360 end
    if y < -180 then y = y + 360 end
    return y
end

-- rota el forward/side por -delta para compensar la rotacion del yaw
local function fix_movement(cmd, old_yaw, new_yaw)
    if not cfg.fix_movement then return end

    local delta_rad = math.rad(new_yaw - old_yaw)
    local c = math.cos(delta_rad)
    local s = math.sin(delta_rad)

    local fm, sm = 0, 0
    pcall(function()
        fm = cmd:get_forwardmove()
        sm = cmd:get_sidemove()
    end)

    if fm == 0 and sm == 0 then return end

    -- aplicar rotacion inversa
    local new_fm = fm * c - sm * s
    local new_sm = fm * s + sm * c

    pcall(function()
        cmd:set_forwardmove(new_fm)
        cmd:set_sidemove(new_sm)
    end)
end

function on_create_move(cmd, local_player)
    if not cmd then return end

    local down = false
    pcall(function() down = input.is_key_down(KEY) end)
    if down and not prev_down then
        cfg.enabled = not cfg.enabled
        log(cfg.enabled and "ON" or "OFF")
    end
    prev_down = down

    if not cfg.enabled then return end

    local buttons = 0
    pcall(function() buttons = cmd:get_buttons() end)
    if (buttons & IN_ATTACK) ~= 0 then return end

    -- guardar el yaw viejo antes de modificarlo
    local old_yaw = 0.0
    pcall(function()
        local va = cmd:get_viewangles()
        if va and va.y then old_yaw = va.y end
    end)

    -- avanzar spin
    spin_yaw = norm_yaw(spin_yaw + cfg.spin_speed)

    -- aplicar angulos nuevos
    pcall(function()
        cmd:set_viewangles(vector.new(cfg.pitch, spin_yaw, 0))
    end)

    -- corregir movimiento
    fix_movement(cmd, old_yaw, spin_yaw)
end

-- ============================================================
-- MENU
-- ============================================================
pcall(function()
    menu.add_main_tab("Spinbot", function()
        local c, v

        imgui.text_colored(1.0, 0.4, 0.4, 1.0, "Spinbot AA")
        imgui.text_colored(0.6, 0.6, 0.6, 1.0, "Keybind: K")
        imgui.separator()

        c, v = imgui.checkbox("Enable", cfg.enabled)
        if c then cfg.enabled = v end

        c, v = imgui.slider_float("Spin Speed", cfg.spin_speed, 5.0, 60.0)
        if c then cfg.spin_speed = v end
        imgui.same_line()
        imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(deg/tick)")

        c, v = imgui.slider_float("Pitch", cfg.pitch, -89.0, 89.0)
        if c then cfg.pitch = v end
        imgui.same_line()
        imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(-89 = down)")

        imgui.spacing()
        c, v = imgui.checkbox("Fix Movement", cfg.fix_movement)
        if c then cfg.fix_movement = v end
        imgui.same_line()
        imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(WASD sigue funcionando)")

        imgui.spacing()
        imgui.separator()
        imgui.text("yaw actual: " .. string.format("%.1f", spin_yaw))
    end)
end)

function on_unload()
    cfg.enabled = false
    spin_yaw = 0.0
    log("unloaded")
end

log("cargado — K para toggle")
