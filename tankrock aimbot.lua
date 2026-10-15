

local cfg = {
    enabled       = true,
    activation    = keys.MOUSE4,    -- hold to activate
    fov           = 90.0,           -- FOV cone for target acquisition
    max_distance  = 3000.0,         -- max range to target survivors
    silent        = true,           -- silent aim (camera doesn't move)
    auto_throw    = true,           -- auto inject IN_ATTACK2 when arc is clean
}

local function load_cfg()
    cfg.enabled      = client.get_shared_bool("tr_enabled",     cfg.enabled)
    cfg.fov          = client.get_shared_float("tr_fov",        cfg.fov)
    cfg.max_distance = client.get_shared_float("tr_maxdist",    cfg.max_distance)
    cfg.silent       = client.get_shared_bool("tr_silent",      cfg.silent)
    cfg.auto_throw   = client.get_shared_bool("tr_auto_throw",  cfg.auto_throw)
end

local function save_cfg()
    client.set_shared_bool("tr_enabled",    cfg.enabled)
    client.set_shared_float("tr_fov",       cfg.fov)
    client.set_shared_float("tr_maxdist",   cfg.max_distance)
    client.set_shared_bool("tr_silent",     cfg.silent)
    client.set_shared_bool("tr_auto_throw", cfg.auto_throw)
end

load_cfg()

-- ─────────────────────────────────────────────
-- CONSTANTS
-- ─────────────────────────────────────────────

local TEAM_SURVIVORS   = 2
local TEAM_INFECTED    = 3
local CLASS_TANK       = zombie_class.TANK

-- Rock physics — tune empirically if arc is off
-- ROCK_SPEED: projectile launch speed in units/s (~1000 from L4D2 source)
-- ROCK_GRAV_SCALE: gravity multiplier on the projectile (0.5 = half gravity)
-- LAUNCH_OFFSET_Z: how far above eye the rock spawns
local ROCK_SPEED       = 1000.0
local ROCK_GRAV_SCALE  = 0.5
local LAUNCH_OFFSET_Z  = 16.0

-- Safety timer — if arc hasn't resolved in this many ticks, don't throw
-- Prevents throwing into geometry or at unreachable targets
local MAX_THROW_TICKS  = 3

-- ─────────────────────────────────────────────
-- STATE
-- ─────────────────────────────────────────────

local locked_target    = nil
local throw_ready_tick = 0   -- tick when arc became clean, for settle window
local tr_ps_owns       = false

local cached_gravity   = 800.0   -- updated live from sv_gravity

-- ─────────────────────────────────────────────
-- PERFECTSILENT
-- ─────────────────────────────────────────────

local function ps_begin()
    if not cfg.silent then return end
    tr_ps_owns = true
    pcall(function()
        cvar_vars.set_bool("perfectsilent_should_silent",       true)
        cvar_vars.set_bool("perfectsilent_initiated_by_aimbot", true)
        cvar_vars.set_bool("perfectsilent_aimbot_has_target",   true)
    end)
end

local function ps_clear()
    if not tr_ps_owns then return end
    tr_ps_owns = false
    pcall(function()
        cvar_vars.set_bool("perfectsilent_should_silent",       false)
        cvar_vars.set_bool("perfectsilent_initiated_by_aimbot", false)
        cvar_vars.set_bool("perfectsilent_aimbot_has_target",   false)
    end)
end

-- ─────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────

local function norm(a)
    return math.normalize_angle(a)
end

local function calc_angle(src, dst)
    local dx  = dst.x - src.x
    local dy  = dst.y - src.y
    local dz  = dst.z - src.z
    local hyp = math.sqrt(dx * dx + dy * dy)
    return vector.new(
        math.deg(math.atan2(-dz, hyp)),
        math.deg(math.atan2(dy,  dx)),
        0)
end

local function get_fov(view_angs, aim_angs)
    local dp = norm(aim_angs.x - view_angs.x)
    local dy = norm(aim_angs.y - view_angs.y)
    return math.sqrt(dp * dp + dy * dy)
end

local function refresh_gravity()
    pcall(function()
        local ptr = cvar.find("sv_gravity")
        if ptr and ptr ~= 0 then
            local g = cvar.get_float(ptr)
            if g and g > 0 then cached_gravity = g end
        end
    end)
end

-- ─────────────────────────────────────────────
-- ARC COMPENSATION
-- Calculates the launch pitch angle needed to land the rock on the target.
-- Uses standard projectile physics: range / speed gives time of flight,
-- then solve for the upward angle needed to counteract gravity drop.
--
-- Two solutions exist for any target (high arc and low arc).
-- We use the LOW arc (direct throw) — shorter flight time, harder to dodge.
--
-- Formula: pitch = atan((v^2 ± sqrt(v^4 - g*(g*x^2 + 2*y*v^2))) / (g*x))
-- where x = horizontal distance, y = vertical distance, v = rock speed,
-- g = effective gravity (sv_gravity * ROCK_GRAV_SCALE)
-- ─────────────────────────────────────────────

local function calc_arc_pitch(launch_pos, target_pos)
    local dx   = target_pos.x - launch_pos.x
    local dy   = target_pos.y - launch_pos.y
    local dz   = target_pos.z - launch_pos.z

    local horiz = math.sqrt(dx * dx + dy * dy)   -- horizontal distance
    if horiz < 1.0 then return nil end            -- too close, no arc needed

    local g    = cached_gravity * ROCK_GRAV_SCALE
    local v    = ROCK_SPEED
    local v2   = v * v
    local v4   = v2 * v2

    -- Discriminant — if negative, target is out of range for this rock speed
    local disc = v4 - g * (g * horiz * horiz + 2.0 * dz * v2)
    if disc < 0 then return nil end   -- unreachable

    local sqrt_disc = math.sqrt(disc)

    -- Low arc solution (direct, faster, preferred)
    local pitch_low  = math.atan2(v2 - sqrt_disc, g * horiz)
    -- High arc solution (lobbed) — fallback if low arc is blocked
    local pitch_high = math.atan2(v2 + sqrt_disc, g * horiz)

    -- Return low arc as primary, converted to degrees (negative = aim up in Source)
    return -math.deg(pitch_low), -math.deg(pitch_high)
end

-- ─────────────────────────────────────────────
-- LEAD PREDICTION
-- Predicts where the survivor will be when the rock arrives.
-- Time of flight estimated from horizontal distance / rock speed.
-- ─────────────────────────────────────────────

local function predict_target(origin, vel, launch_pos)
    local dx   = origin.x - launch_pos.x
    local dy   = origin.y - launch_pos.y
    local horiz = math.sqrt(dx * dx + dy * dy)

    -- Rough time of flight estimate (actual flight time is slightly longer
    -- due to arc but this is close enough for lead compensation)
    local tof  = horiz / ROCK_SPEED
    if tof <= 0 then return origin end

    return vector.new(
        origin.x + vel.x * tof,
        origin.y + vel.y * tof,
        origin.z)   -- don't predict vertical — survivors rarely jump predictably
end

-- ─────────────────────────────────────────────
-- TARGET ACQUISITION
-- Closest to crosshair within FOV cone, alive, not incapped, team survivors.
-- ─────────────────────────────────────────────

local function get_best_target(local_player)
    local eye_pos   = local_player:get_eye_position()
    local view_angs = local_player:get_eye_angles()
    local local_idx = local_player:get_index()
    local mc        = engine.get_max_clients()

    if not eye_pos or not view_angs then return nil end

    -- Launch point is slightly above eye (where rock actually spawns)
    local launch_pos = vector.new(eye_pos.x, eye_pos.y, eye_pos.z + LAUNCH_OFFSET_Z)

    local best     = nil
    local best_fov = cfg.fov

    for i = 1, mc do
        local player = entity.get_by_index(i)
        if not player                then goto continue end
        if i == local_idx            then goto continue end
        if not player:is_alive()     then goto continue end
        if player:get_team() ~= TEAM_SURVIVORS then goto continue end
        if player:is_incapacitated() then goto continue end

        local origin = player:get_origin()
        if not origin then goto continue end

        local dist = vector.distance(eye_pos, origin)
        if dist > cfg.max_distance then goto continue end

        -- Lead the target based on their velocity
        local vel = player:get_velocity()
        if not vel then vel = vector.new(0, 0, 0) end
        local pred_pos = predict_target(origin, vel, launch_pos)

        -- Aim at upper chest of predicted position
        local aim_target = vector.new(pred_pos.x, pred_pos.y, pred_pos.z + 40.0)

        local direct_angle = calc_angle(launch_pos, aim_target)
        local fov_val      = get_fov(view_angs, direct_angle)
        if fov_val > best_fov then goto continue end

        -- Check arc is solvable (target reachable)
        local pitch_low = calc_arc_pitch(launch_pos, aim_target)
        if not pitch_low then goto continue end   -- unreachable, skip

        best_fov = fov_val
        best = {
            player     = player,
            pred_pos   = aim_target,
            direct_ang = direct_angle,
            dist       = dist,
        }

        ::continue::
    end

    return best
end

-- ─────────────────────────────────────────────
-- MAIN HOOK
-- ─────────────────────────────────────────────

function on_create_move(cmd, local_player)
    -- Always clear shared bool first so aimbot doesn't get stuck yielding
    client.set_shared_bool("tank_active", false)

    if not cfg.enabled then return end
    if not local_player or not local_player:is_alive() then return end
    if not engine.is_in_game() then return end
    if local_player:get_team() ~= TEAM_INFECTED then return end
    if local_player:get_zombie_class() ~= CLASS_TANK then
        ps_clear()
        locked_target = nil
        return
    end

    local key_down = input.is_key_down(cfg.activation)

    if not key_down then
        -- Key released — clear everything, yield back to aimbot
        client.set_shared_bool("tank_active", false)
        ps_clear()
        locked_target    = nil
        throw_ready_tick = 0
        return
    end

    -- Key held — signal aimbot to yield
    client.set_shared_bool("tank_active", true)

    local eye_pos = local_player:get_eye_position()
    if not eye_pos then return end

    local launch_pos = vector.new(eye_pos.x, eye_pos.y, eye_pos.z + LAUNCH_OFFSET_Z)

    -- Refresh gravity periodically
    refresh_gravity()

    -- Validate existing lock
    if locked_target then
        local ent = locked_target.player
        if not ent or not ent:is_alive()
           or ent:get_team() ~= TEAM_SURVIVORS
           or ent:is_incapacitated()
        then
            locked_target = nil
        end
    end

    -- Acquire new target if none
    if not locked_target then
        local t = get_best_target(local_player)
        if not t then
            ps_clear()
            return
        end
        locked_target    = t
        throw_ready_tick = 0
    end

    -- Recompute predicted position every tick (target keeps moving)
    local origin = locked_target.player:get_origin()
    if not origin then locked_target = nil; ps_clear(); return end

    local vel = locked_target.player:get_velocity()
    if not vel then vel = vector.new(0, 0, 0) end

    local pred_pos  = predict_target(origin, vel, launch_pos)
    local aim_target = vector.new(pred_pos.x, pred_pos.y, pred_pos.z + 40.0)

    -- Calculate arc pitch for this position
    local pitch_low, pitch_high = calc_arc_pitch(launch_pos, aim_target)
    if not pitch_low then
        -- Target unreachable this tick — don't throw
        ps_clear()
        return
    end

    -- Build final aim angles:
    -- Yaw = direct angle to target (horizontal)
    -- Pitch = arc-compensated angle (angled up for gravity)
    local direct = calc_angle(launch_pos, aim_target)
    local final_angles = vector.new(
        math.clamp(pitch_low, -89.0, 89.0),
        norm(direct.y),
        0)

    -- Apply angles
    cmd:set_viewangles(final_angles)
    if not cfg.silent then
        engine.set_view_angles(final_angles)
    end

    -- Claim perfectsilent so weapon fires along corrected angles
    ps_begin()

    -- Auto throw gate:
    -- Only inject IN_ATTACK2 if auto_throw is on and arc has been
    -- stable for at least 1 tick (avoid throwing on acquisition frame)
    if cfg.auto_throw then
        local cur_tick = client.get_tick_count()

        if throw_ready_tick == 0 then
            -- First tick arc is clean — start settle counter
            throw_ready_tick = cur_tick
        elseif cur_tick - throw_ready_tick >= 1 then
            -- Arc has been clean for at least 1 tick — throw
            cmd:set_buttons(cmd:get_buttons() | buttons.IN_ATTACK2)
            -- Reset after throw so next activation re-acquires
            locked_target    = nil
            throw_ready_tick = 0
        end
    end
end

-- ─────────────────────────────────────────────
-- HUD
-- ─────────────────────────────────────────────

function on_paint()
    if not engine.is_in_game() then return end
    if not cfg.enabled then return end

    pcall(function()
        local me = client.get_local_player()
        if not me or not me:is_alive() then return end
        if me:get_team() ~= TEAM_INFECTED then return end
        if me:get_zombie_class() ~= CLASS_TANK then return end

        local sw, sh = draw.get_screen_size()
        if not sw or sw == 0 then return end

        local key_held = input.is_key_down(cfg.activation)

        local label
        local r, g, b

        if not key_held then
            label = "Tank Rock: STANDBY"
            r, g, b = 0.6, 0.6, 0.6
        elseif locked_target then
            label = "Tank Rock: LOCKED"
            r, g, b = 1.0, 0.5, 0.1
        else
            label = "Tank Rock: SEARCHING"
            r, g, b = 0.2, 1.0, 0.3
        end

        local tw  = draw.get_text_width(fonts.ESP, label)
        local fh  = draw.get_font_height(fonts.ESP)
        local pad = 4
        local x   = math.floor((sw - tw) / 2)
        local y   = 80   -- below autoshove HUD at y=55

        draw.rect(x-pad, y-pad, tw+pad*2, fh+pad*2, 0, 0, 0, 0.6)
        draw.outlined_rect(x-pad, y-pad, tw+pad*2, fh+pad*2, r, g, b, 1.0)
        draw.string(fonts.ESP, x, y, r, g, b, 1.0, text_align.LEFT, label)
    end)
end

-- ─────────────────────────────────────────────
-- MENU
-- ─────────────────────────────────────────────

if not _G.tr_menu_registered then
    _G.tr_menu_registered = true

    menu.add_sub_tab("Aimbot", "Tank Rock", function()
        local ok, err = pcall(function()
            local c, v

            imgui.separator()
            imgui.text_colored(1.0, 0.3, 0.3, 1.0, "Tank Rock Aimbot v1.0")
            imgui.separator()

            c, v = imgui.checkbox("Enable", cfg.enabled)
            if c then cfg.enabled = v; save_cfg() end
            imgui.same_line()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(tank only)")

            -- Status
            if locked_target then
                imgui.text_colored(1.0, 0.5, 0.1, 1.0, "  LOCKED onto target")
            elseif input.is_key_down(cfg.activation) then
                imgui.text_colored(0.2, 1.0, 0.3, 1.0, "  Searching...")
            else
                imgui.text_colored(0.5, 0.5, 0.5, 1.0, "  Standby — hold activation key")
            end

            imgui.spacing()
            imgui.text_colored(0.7, 0.7, 1.0, 1.0, "Behavior")
            imgui.separator()

            c, v = imgui.checkbox("Auto Throw", cfg.auto_throw)
            if c then cfg.auto_throw = v; save_cfg() end
            imgui.same_line()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0,
                "(inject IN_ATTACK2 when arc is clean)")

            c, v = imgui.checkbox("Silent", cfg.silent)
            if c then cfg.silent = v; save_cfg() end
            imgui.same_line()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(camera doesn't move)")

            imgui.spacing()
            imgui.text_colored(0.7, 0.7, 1.0, 1.0, "Targeting")
            imgui.separator()

            c, v = imgui.slider_float("FOV", cfg.fov, 1.0, 180.0)
            if c then cfg.fov = v; save_cfg() end
            imgui.same_line()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(acquisition cone)")

            c, v = imgui.slider_float("Max Distance", cfg.max_distance, 500.0, 6000.0)
            if c then cfg.max_distance = v; save_cfg() end
            imgui.same_line()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0, "(units)")

            imgui.spacing()
            imgui.text_colored(1.0, 0.9, 0.5, 1.0, "Physics Tuning")
            imgui.separator()
            imgui.text_colored(0.6, 0.6, 0.6, 1.0,
                string.format("  Rock speed:    %.0f u/s", ROCK_SPEED))
            imgui.text_colored(0.6, 0.6, 0.6, 1.0,
                string.format("  Grav scale:    %.2f", ROCK_GRAV_SCALE))
            imgui.text_colored(0.6, 0.6, 0.6, 1.0,
                string.format("  sv_gravity:    %.0f (live)", cached_gravity))
            imgui.text_colored(0.5, 0.8, 1.0, 1.0,
                "  If arc overshoots: reduce ROCK_SPEED in source")
            imgui.text_colored(0.5, 0.8, 1.0, 1.0,
                "  If arc undershoots: increase ROCK_SPEED in source")

            imgui.spacing()
            imgui.separator()
            imgui.text("Hold activation key to lock + auto throw.")
            imgui.text("Release key to cancel at any time.")
            imgui.text("Aimbot (aimv2) yields automatically while active.")
            imgui.text("Add to aimv2 after team check:")
            imgui.text_colored(0.5, 1.0, 0.7, 1.0,
                '  if client.get_shared_bool("tank_active", false) then return end')
        end)

        if not ok then
            imgui.text_colored(1.0, 0.3, 0.3, 1.0, "menu error: " .. tostring(err))
        end
    end)
end

function on_unload()
    _G.tr_menu_registered = nil
    client.set_shared_bool("tank_active", false)
    ps_clear()
end

