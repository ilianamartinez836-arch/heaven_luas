-- Movement ByxStorm → Heaven
-- Bhop + AutoStrafe (valores del src original) + AutoDuck

local IN_JUMP = 2
local IN_DUCK = 4

local MOVETYPE_NOCLIP   = 8
local MOVETYPE_LADDER   = 9
local MOVETYPE_OBSERVER = 10

local cfg = {
    bhop = true,
    strafe = true,
    autoduck = false,
    -- constantes del AutoStrafe.cpp de ByxStorm
    max_speed  = 1000.0,
    air_accel  = 1000.0,
    wish_speed = 1000.0,
    move_scale = 450.0,
    min_speed  = 2.0,
    show_speed = true
}

local function angle_normalize(a)
    while a > 180 do a = a - 360 end
    while a < -180 do a = a + 360 end
    return a
end

local function apply_bhop(cmd, lp)
    if not cfg.bhop then return end
    local buttons = cmd:get_buttons()
    if (buttons & IN_JUMP) == 0 then return end
    if not lp:is_on_ground() then
        cmd:set_buttons(buttons & ~IN_JUMP)
    end
end

local function apply_strafe(cmd, lp)
    if not cfg.strafe then return end
    if lp:is_on_ground() then return end

    local mt = 0
    pcall(function() mt = lp:get_move_type() end)
    if mt == MOVETYPE_NOCLIP or mt == MOVETYPE_LADDER or mt == MOVETYPE_OBSERVER then
        return
    end

    local vel = lp:get_velocity()
    if not vel then return end
    local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y)
    if speed < cfg.min_speed then return end

    -- term = (wishSpeed / airAccel) / maxSpeed * 400 / speed   [ByxStorm]
    local term = (cfg.wish_speed / cfg.air_accel) / cfg.max_speed * 400.0 / speed
    if term <= -1.0 or term >= 1.0 then return end

    local perfect_delta = math.acos(term)
    if perfect_delta == 0.0 then return end

    local angles = cmd:get_viewangles()
    local yaw_rad = angles.y * 0.017453292519943295

    local vel_dir = math.atan2(vel.y, vel.x) - yaw_rad
    local wish_ang = math.atan2(-cmd:get_sidemove(), cmd:get_forwardmove())

    local delta = angle_normalize((vel_dir - wish_ang) * 57.29577951308232)
    local move_dir
    if delta < 0.0 then
        move_dir = vel_dir + perfect_delta
    else
        move_dir = vel_dir - perfect_delta
    end

    cmd:set_forwardmove(math.cos(move_dir) * cfg.move_scale)
    cmd:set_sidemove(-math.sin(move_dir) * cfg.move_scale)
end

local function apply_autoduck(cmd)
    if not cfg.autoduck then return end
    local buttons = cmd:get_buttons()
    cmd:set_buttons(buttons | IN_DUCK)
end

function on_create_move(cmd, local_player)
    if not cmd or not local_player then return end
    if not local_player:is_alive() then return end

    -- Orden ByxStorm Copy_Command: AutoDuck → Bhop → Strafe
    apply_autoduck(cmd)
    apply_bhop(cmd, local_player)
    apply_strafe(cmd, local_player)
end

function on_paint()
    if not cfg.show_speed then return end
    local lp = client.get_local_player()
    if not lp or not lp:is_alive() then return end
    if lp:is_on_ground() then return end

    local vel = lp:get_velocity()
    if not vel then return end
    local sp = math.sqrt(vel.x * vel.x + vel.y * vel.y)

    local w, h = draw.get_screen_size()
    draw.string(
        fonts.ESP_NAME,
        math.floor(w / 2),
        math.floor(h / 2) + 48,
        0.85, 0.95, 1.0, 1.0,
        text_align.CENTERX,
        string.format("%.0f", sp)
    )
end

menu.add_main_tab("Movement", function()
    local ch, val

    ch, val = imgui.checkbox("Bunnyhop", cfg.bhop)
    if ch then cfg.bhop = val end

    ch, val = imgui.checkbox("AutoStrafe (Byx)", cfg.strafe)
    if ch then cfg.strafe = val end

    ch, val = imgui.checkbox("AutoDuck", cfg.autoduck)
    if ch then cfg.autoduck = val end

    ch, val = imgui.checkbox("Show air speed", cfg.show_speed)
    if ch then cfg.show_speed = val end

    imgui.separator()
    imgui.text_colored(0.55, 0.55, 0.55, 1.0, "Valores del AutoStrafe.cpp de ByxStorm")
    ch, val = imgui.slider_float("Max speed", cfg.max_speed, 250.0, 2000.0)
    if ch then cfg.max_speed = val end
    ch, val = imgui.slider_float("Air accel", cfg.air_accel, 250.0, 2000.0)
    if ch then cfg.air_accel = val end
    ch, val = imgui.slider_float("Wish speed", cfg.wish_speed, 250.0, 2000.0)
    if ch then cfg.wish_speed = val end
    ch, val = imgui.slider_float("Move scale", cfg.move_scale, 250.0, 450.0)
    if ch then cfg.move_scale = val end

    imgui.separator()
    imgui.text("Mantén espacio en el aire + mira para ganar velocidad")
    imgui["end"]()
end)

client.print("[Movement] ByxStorm port — Bhop + Strafe + Duck | tab Movement")