-- ============================================================
-- Clean Aimbot Script for Left 4 Dead 2
-- ============================================================
-- What this script does:
--   - Automatically aims at nearby players/zombies
--   - Works when you hold a chosen key (default: MOUSE5)
--   - Has a menu so you can tweak every setting in-game
--
-- How to use:
--   1. Load this script through your cheat's script loader
--   2. Open the menu and go to the "Clean Aimbot" tab
--   3. Enable the aimbot, configure your settings, hold your key
-- ============================================================

-- ============================================================
-- TEAM & ZOMBIE CLASS CONSTANTS
-- ============================================================
-- These numbers match the game's internal team and zombie IDs.
-- We store them in tables so we can write readable names
-- (e.g. TEAM.SURVIVORS) instead of magic numbers like "2".
local TEAM = { SURVIVORS = 2, INFECTED = 3 }
local ZOMBIE = {
    SMOKER  = 1, BOOMER = 2, HUNTER = 3,
    SPITTER = 4, JOCKEY = 5, CHARGER = 6, TANK = 8
}

-- ============================================================
-- SHARED SETTINGS INITIALIZATION
-- ============================================================
-- "Shared" values are a way to store settings that persist
-- between script reloads and can be read/written from anywhere
-- (including the menu and the aimbot logic).
--
-- We only set defaults the VERY FIRST TIME the script loads.
-- The check below prevents overwriting your saved settings
-- every time the script is reloaded.
if client.get_shared_bool("aimbot_initialized", nil) == nil then
    -- Master switch: aimbot is OFF by default
    client.set_shared_bool("aimbot_enabled", false)

    -- Silent Aim: moves the aim server-side only (other players
    -- won't see your crosshair snap to a target)
    client.set_shared_bool("aimbot_silent", true)

    -- Perfect Silent: a stricter silent mode; generally more
    -- detectable but more accurate
    client.set_shared_bool("aimbot_psilent", false)

    -- Auto Shoot: automatically fires when a target is locked
    client.set_shared_bool("aimbot_autoshoot", true)

    -- Draw FOV: shows a circle on screen representing the
    -- aimbot's field-of-view cone
    client.set_shared_bool("aimbot_draw_fov", false)

    -- Friendly Fire: if false, never aim at teammates
    client.set_shared_bool("aimbot_friendly_fire", false)

    -- Which enemy types to target (all enabled by default)
    client.set_shared_bool("aimbot_target_survivors", true)
    client.set_shared_bool("aimbot_target_smoker",    true)
    client.set_shared_bool("aimbot_target_boomer",    true)
    client.set_shared_bool("aimbot_target_hunter",    true)
    client.set_shared_bool("aimbot_target_spitter",   true)
    client.set_shared_bool("aimbot_target_jockey",    true)
    client.set_shared_bool("aimbot_target_charger",   true)
    client.set_shared_bool("aimbot_target_tank",      true)

    -- The key you must HOLD to activate the aimbot
    client.set_shared_int("aimbot_key", keys.MOUSE5)

    -- Priority mode:
    --   1 = Crosshair (target whoever is closest to your crosshair)
    --   2 = Distance  (target whoever is physically nearest to you)
    client.set_shared_int("aimbot_priority", 1)

    -- FOV (field of view): only targets within this angle from
    -- your crosshair will be considered. 180 = entire screen.
    client.set_shared_int("aimbot_fov", 180)

    -- Max Distance: targets farther than this (in game units)
    -- are ignored. 8192 ≈ the far edge of most maps.
    client.set_shared_float("aimbot_max_distance", 8192.0)

    -- Smooth: how fast the aim snaps. Higher = slower/smoother.
    -- 1.0 = instant snap. 5.0 = gradual, human-like movement.
    client.set_shared_float("aimbot_smooth", 5.0)

    -- Target Lock: once a target is selected, keep aiming at
    -- them for a short time before allowing a target switch.
    client.set_shared_bool("aimbot_target_lock", true)

    -- Lock Duration: how many seconds to stay locked before
    -- the aimbot is allowed to switch to a better target.
    client.set_shared_float("aimbot_lock_time", 0.5)

    -- Mark settings as initialized so we don't reset them again
    client.set_shared_bool("aimbot_initialized", true)
end

-- ============================================================
-- KEY NAME LOOKUP TABLE
-- ============================================================
-- Maps key codes (numbers the engine uses internally) to human-
-- readable strings like "MOUSE5" or "A". Used in the keybind
-- button so the menu can show "MOUSE5" instead of "173".
local key_names = {
    [keys.MOUSE1]="MOUSE1",[keys.MOUSE2]="MOUSE2",[keys.MOUSE3]="MOUSE3",
    [keys.MOUSE4]="MOUSE4",[keys.MOUSE5]="MOUSE5",
    [keys.KEY_A]="A",[keys.KEY_B]="B",[keys.KEY_C]="C",[keys.KEY_D]="D",
    [keys.KEY_E]="E",[keys.KEY_F]="F",[keys.KEY_G]="G",[keys.KEY_H]="H",
    [keys.KEY_I]="I",[keys.KEY_J]="J",[keys.KEY_K]="K",[keys.KEY_L]="L",
    [keys.KEY_M]="M",[keys.KEY_N]="N",[keys.KEY_O]="O",[keys.KEY_P]="P",
    [keys.KEY_Q]="Q",[keys.KEY_R]="R",[keys.KEY_S]="S",[keys.KEY_T]="T",
    [keys.KEY_U]="U",[keys.KEY_V]="V",[keys.KEY_W]="W",[keys.KEY_X]="X",
    [keys.KEY_Y]="Y",[keys.KEY_Z]="Z",
    [keys.SPACE]="SPACE",[keys.SHIFT]="SHIFT",[keys.CTRL]="CTRL",[keys.ALT]="ALT",
    [keys.ESCAPE]="ESC"
}

-- ============================================================
-- STATE VARIABLES
-- ============================================================
-- These variables track temporary runtime state. Unlike shared
-- values, they reset every time the script is loaded.

local waiting_for_key  = false   -- true when the menu is listening for a new keybind
local keybind_target   = nil     -- which setting we're rebinding (e.g. "aimbot_key")
local current_target_idx = nil   -- entity index of the currently locked target
local lock_expire_time = 0       -- tick count at which the target lock expires

-- ============================================================
-- MATH HELPERS
-- ============================================================

-- calc_angle: given two 3D positions (src and dst), returns
-- the pitch/yaw angle you would need to look from src to hit dst.
--
-- Pitch = up/down angle (X)   Yaw = left/right angle (Y)
local function calc_angle(src, dst)
    -- Delta between the two points on each axis
    local dx, dy, dz = dst.x - src.x, dst.y - src.y, dst.z - src.z

    -- Horizontal distance (ignoring Z so we can compute pitch correctly)
    local hyp = math.sqrt(dx*dx + dy*dy)

    -- Edge case: target is directly above or below us.
    -- atan2(dz, 0) would divide by zero, so clamp hyp to a tiny value.
    if hyp < 0.001 then
        return vector.new(
            math.deg(math.atan2(-dz, 0.001)),
            0,
            0
        )
    end

    return vector.new(
        math.deg(math.atan2(-dz, hyp)),   -- Pitch: negative because +Z is down in Source
        math.deg(math.atan2(dy, dx)),      -- Yaw
        0                                  -- Roll (always 0)
    )
end

-- get_fov: returns the angular distance (in degrees) between
-- the player's current view angle (va) and a target angle (ta).
-- A small number means the crosshair is close to the target.
local function get_fov(va, ta)
    -- math.angle_diff handles the wrap-around (e.g. 359° vs 1°)
    local dx = math.angle_diff(ta.x, va.x)   -- pitch difference
    local dy = math.angle_diff(ta.y, va.y)   -- yaw difference
    -- Euclidean distance in angle-space
    return math.sqrt(dx*dx + dy*dy)
end

-- smooth_angles: blends the current view angle toward the target
-- angle by a fraction (1/factor) each call. Called every tick,
-- this creates a gradual, human-looking aim movement.
--
--   factor = 1  → instant snap to target
--   factor = 5  → moves 1/5 of the remaining gap each tick (smooth)
--   factor = 20 → very slow, barely noticeable
local function smooth_angles(cur, tar, factor)
    if factor <= 0 then return tar end    -- safety: avoid division by zero
    local dx = math.angle_diff(tar.x, cur.x)
    local dy = math.angle_diff(tar.y, cur.y)
    local s = 1.0 / factor
    return vector.new(
        math.normalize_angle(cur.x + dx * s),   -- new pitch
        math.normalize_angle(cur.y + dy * s),   -- new yaw
        0
    )
end

-- vector_distance: wraps the built-in vector.distance function.
-- Returns the straight-line distance between two 3D points.
local function vector_distance(v1, v2)
    return vector.distance(v1, v2)
end

-- ============================================================
-- TARGET VALIDATION
-- ============================================================

-- is_target_allowed: decides whether a given entity (ent) is a
-- valid target for the aimbot based on current settings.
-- Returns true if we should aim at them, false if we should skip.
local function is_target_allowed(ent, local_player)
    -- Skip dead or invalid entities immediately
    if not ent or not ent:is_alive() then return false end

    local local_team = local_player:get_team()
    local team       = ent:get_team()

    -- Skip teammates unless Friendly Fire is enabled
    if team == local_team and not client.get_shared_bool("aimbot_friendly_fire", false) then
        return false
    end

    -- Get the zombie class (0 for survivors / non-special infected)
    local z_class = ent:get_zombie_class() or 0

    -- Check the appropriate per-type toggle
    if team == TEAM.SURVIVORS then
        return client.get_shared_bool("aimbot_target_survivors", true)
    elseif team == TEAM.INFECTED then
        if     z_class == ZOMBIE.SMOKER  then return client.get_shared_bool("aimbot_target_smoker",  true)
        elseif z_class == ZOMBIE.BOOMER  then return client.get_shared_bool("aimbot_target_boomer",  true)
        elseif z_class == ZOMBIE.HUNTER  then return client.get_shared_bool("aimbot_target_hunter",  true)
        elseif z_class == ZOMBIE.SPITTER then return client.get_shared_bool("aimbot_target_spitter", true)
        elseif z_class == ZOMBIE.JOCKEY  then return client.get_shared_bool("aimbot_target_jockey",  true)
        elseif z_class == ZOMBIE.CHARGER then return client.get_shared_bool("aimbot_target_charger", true)
        elseif z_class == ZOMBIE.TANK    then return client.get_shared_bool("aimbot_target_tank",    true)
        end
    end

    -- Unknown team or zombie class → don't target
    return false
end

-- ============================================================
-- AIM POSITION
-- ============================================================

-- get_aim_position: returns the 3D world position we want to
-- aim at on a given entity. Currently aims at the eye position
-- (roughly the head). In the future this could be replaced with
-- proper hitbox sampling for better accuracy.
local function get_aim_position(ent)
    return ent:get_eye_position()
end

-- ============================================================
-- TARGET SELECTION
-- ============================================================

-- find_best_target: scans all players/zombies and picks the
-- best one to aim at based on the current priority setting.
-- Returns a table: { entity, angle, pos, idx }  or  nil.
local function find_best_target(local_player)
    local eye       = local_player:get_eye_position()   -- where our eyes are in 3D space
    local va        = local_player:get_eye_angles()      -- our current look direction
    local local_idx = local_player:get_index()           -- our own entity index (to skip ourselves)

    -- Read all relevant settings once (faster than reading each per-entity)
    local max_fov   = client.get_shared_int("aimbot_fov", 180)
    local max_dist  = client.get_shared_float("aimbot_max_distance", 8192)
    local priority  = client.get_shared_int("aimbot_priority", 1)
    local use_lock  = client.get_shared_bool("aimbot_target_lock", true)
    local lock_time = client.get_shared_float("aimbot_lock_time", 0.5)
    local current_tick = client.get_tick_count()
    local frame_time   = client.get_frame_time()   -- seconds per frame, used to convert lock_time to ticks

    -- ── Target Lock: keep the current target if it's still valid ──
    -- This prevents the aimbot from rapidly flickering between targets.
    if current_target_idx then
        local ent = entity.get_by_index(current_target_idx)
        if ent and ent:is_alive() and is_target_allowed(ent, local_player) then
            -- Target is still alive and valid → keep aiming at it
            local pos = get_aim_position(ent)
            local ang = calc_angle(eye, pos)
            return { entity = ent, angle = ang, pos = pos, idx = current_target_idx }
        else
            -- Target died or left → clear the lock so we scan for a new one
            current_target_idx = nil
        end
    end

    -- ── Scan: loop every player slot and find the best new target ──
    local best, best_val = nil, nil

    for i = 1, engine.get_max_clients() do
        if i ~= local_idx then   -- never target ourselves
            local ent = entity.get_by_index(i)
            if ent and is_target_allowed(ent, local_player) then
                local pos  = get_aim_position(ent)
                local dist = vector_distance(eye, pos)

                if dist <= max_dist then   -- within range?
                    local ang = calc_angle(eye, pos)
                    local fov = get_fov(va, ang)   -- degrees from crosshair to target

                    if fov <= max_fov then   -- within our FOV cone?
                        -- "val" is what we compare to find the BEST target.
                        -- Lower is better: smallest FOV (closest to crosshair)
                        -- or smallest distance, depending on priority setting.
                        local val = (priority == 1) and fov or dist

                        if best_val == nil or val < best_val then
                            best_val = val
                            best = { entity = ent, angle = ang, pos = pos, idx = i }
                        end
                    end
                end
            end
        end
    end

    -- Lock onto the newly found target and set when the lock expires
    if best then
        current_target_idx = best.idx
        if use_lock then
            -- Convert lock_time (seconds) → ticks by dividing by frame_time
            lock_expire_time = current_tick + (lock_time / frame_time)
        end
    end

    return best   -- nil if no valid target found
end

-- ============================================================
-- KEYBIND HANDLER  (called every frame by the renderer)
-- ============================================================
-- When the user clicks the keybind button in the menu, we set
-- waiting_for_key = true. This function then shows a small
-- overlay window and polls every key until one is pressed.
function on_end_scene()
    if waiting_for_key and keybind_target then
        -- Show a small floating window in the top-left corner
        if not imgui.begin("Keybind", 0) then
            -- If the window couldn't be created, abort the rebind
            waiting_for_key = false
            keybind_target  = nil
            return
        end

        imgui.text("Press any key for " .. keybind_target .. "...")
        imgui.text("Press ESC to cancel")
        imgui["end"]()   -- must always call end() after begin()

        -- Poll every key in our name table
        for key, name in pairs(key_names) do
            if input.is_key_pressed(key) then
                if key == keys.ESCAPE then
                    -- User cancelled → do nothing, just close the listener
                    waiting_for_key = false
                    keybind_target  = nil
                else
                    -- Save the new key and confirm it in the console
                    client.set_shared_int(keybind_target, key)
                    client.print("Set " .. keybind_target .. " to " .. name)
                    waiting_for_key = false
                    keybind_target  = nil
                end
                break   -- stop checking after first pressed key
            end
        end
    end
end

-- ============================================================
-- MAIN AIMBOT  (called every game tick via on_create_move)
-- ============================================================
-- on_create_move runs before every outgoing game packet.
-- "cmd" lets us modify what the game sends (viewangles, buttons).
-- "lp"  is the local player entity.
function on_create_move(cmd, lp)
    -- Safety checks: bail early if anything is in a bad state
    if not cmd or not lp or not lp:is_alive() or not engine.is_in_game() then return end
    -- Don't interfere while the user is setting a new keybind
    if waiting_for_key then return end

    -- Master enable check
    if not client.get_shared_bool("aimbot_enabled", false) then
        current_target_idx = nil   -- clear any stale lock when disabled
        return
    end

    -- Only run while the hotkey is held down
    local key = client.get_shared_int("aimbot_key", keys.MOUSE5)
    if not input.is_key_down(key) then
        current_target_idx = nil   -- release the lock when key is let go
        return
    end

    -- ── Lock expiry check ──
    -- If the lock timer has run out, clear the current target.
    -- find_best_target will then pick a fresh (potentially better) one.
    if client.get_shared_bool("aimbot_target_lock", true) and current_target_idx then
        local current_tick = client.get_tick_count()
        if current_tick >= lock_expire_time then
            current_target_idx = nil   -- lock expired → allow re-evaluation
        end
    end

    -- Find the best target this tick
    local target = find_best_target(lp)
    if not target then return end   -- no valid target → nothing to do

    -- ── Smoothing ──
    -- Blend from the current view angle toward the target angle.
    local final_ang = target.angle
    local smooth    = client.get_shared_float("aimbot_smooth", 5.0)
    if smooth > 0 then
        local cur  = cmd:get_viewangles()              -- current angle from the command
        final_ang  = smooth_angles(cur, final_ang, smooth)
    end

    -- ── Apply the angle ──
    -- The three modes differ in whether the server and/or the client
    -- see the new angle.
    local silent  = client.get_shared_bool("aimbot_silent",  true)
    local psilent = client.get_shared_bool("aimbot_psilent", false)

    if psilent then
        -- Perfect Silent: only the server-bound packet is modified.
        -- Your in-game crosshair stays in place visually.
        cmd:set_viewangles(final_ang)
    elseif silent then
        -- Regular Silent: also only modifies the packet.
        -- (Same effect here; psilent could add extra steps in a more advanced script.)
        cmd:set_viewangles(final_ang)
    else
        -- Non-silent: update BOTH the packet AND the client camera.
        -- You'll visibly see your crosshair snap to the target.
        cmd:set_viewangles(final_ang)
        engine.set_view_angles(final_ang)
    end

    -- ── Auto Shoot ──
    -- Inject the IN_ATTACK button into the command so the game fires
    -- as if you pressed the mouse button yourself.
    if client.get_shared_bool("aimbot_autoshoot", true) then
        local but = cmd:get_buttons()
        cmd:set_buttons(but | buttons.IN_ATTACK)   -- bitwise OR to add the flag without removing others
    end
end

-- ============================================================
-- VISUALS  (called every frame after the 3D world is drawn)
-- ============================================================
-- Draws a FOV circle on the HUD so you can see the aimbot's
-- targeting cone at a glance.
function on_paint()
    if client.get_shared_bool("aimbot_draw_fov", false) then
        local lp = client.get_local_player()
        if lp and lp:is_alive() then
            local w, h  = draw.get_screen_size()
            local fov   = client.get_shared_int("aimbot_fov", 180)
            -- Scale the circle so 180° FOV = half screen height, etc.
            local radius = math.max(5, (fov / 180) * (h / 2))
            -- Outer ring (semi-transparent white)
            draw.outlined_circle(w/2, h/2, radius, 64, 1, 1, 1, 0.5)
            -- Center dot
            draw.circle(w/2, h/2, 2, 16, 1, 1, 1, 0.8)
        end
    end
end

-- ============================================================
-- MENU
-- ============================================================
-- Adds a tab called "Clean Aimbot" to the cheat's main menu.
-- All imgui.* calls draw UI widgets. "changed" is true when
-- the user interacted with a widget; "val" holds the new value.
menu.add_main_tab("Clean Aimbot", function()
    local changed, val

    -- Section header
    imgui.text_colored(1, 0.5, 0, 1, "Clean Aimbot")
    imgui.separator()

    -- ── Master Toggle ──
    changed, val = imgui.checkbox("Enable Aimbot", client.get_shared_bool("aimbot_enabled", false))
    if changed then client.set_shared_bool("aimbot_enabled", val) end

    -- ── Keybind Button ──
    -- Shows the current key name. Clicking it starts the key-listener.
    local cur_key  = client.get_shared_int("aimbot_key", keys.MOUSE5)
    local key_name = key_names[cur_key] or "NONE"
    local btn_txt  = (waiting_for_key and keybind_target == "aimbot_key") and "Press any key..." or key_name
    if imgui.button(btn_txt) then
        waiting_for_key = true
        keybind_target  = "aimbot_key"
    end
    imgui.same_line()
    imgui.text("Aimbot Key")

    imgui.spacing()
    imgui.separator()
    imgui.spacing()

    -- ── Aimbot Settings ──
    imgui.text("Aimbot Settings")

    -- Priority: index 1 = Distance, index 2 = Crosshair (FOV)
    local priority = client.get_shared_int("aimbot_priority", 1)
    changed, val = imgui.combo("Priority", priority, {"Distance", "Crosshair (FOV)"})
    if changed then client.set_shared_int("aimbot_priority", val) end

    -- FOV slider: 1–360 degrees
    local fov = client.get_shared_int("aimbot_fov", 180)
    changed, val = imgui.slider_int("FOV", fov, 1, 360)
    if changed then client.set_shared_int("aimbot_fov", val) end

    -- Smooth slider: 1 = instant snap, 20 = very gradual
    changed, val = imgui.slider_float("Smooth", client.get_shared_float("aimbot_smooth", 5.0), 1.0, 20.0)
    if changed then client.set_shared_float("aimbot_smooth", val) end

    -- Max Distance slider: in Source engine units (~1 unit ≈ 1.9 cm)
    changed, val = imgui.slider_float("Max Distance", client.get_shared_float("aimbot_max_distance", 8192), 100, 10000)
    if changed then client.set_shared_float("aimbot_max_distance", val) end

    imgui.spacing()
    imgui.separator()
    imgui.spacing()

    -- ── Target Lock Settings ──
    imgui.text("Target Lock")

    changed, val = imgui.checkbox("Enable Lock Timer", client.get_shared_bool("aimbot_target_lock", true))
    if changed then client.set_shared_bool("aimbot_target_lock", val) end

    -- Only show the duration slider if locking is enabled
    if client.get_shared_bool("aimbot_target_lock", true) then
        changed, val = imgui.slider_float("Lock Duration (s)", client.get_shared_float("aimbot_lock_time", 0.5), 0.1, 2.0)
        if changed then client.set_shared_float("aimbot_lock_time", val) end
        imgui.text_colored(0.7, 0.7, 0.7, 1, "After lock expires, may switch to a better target")
    end

    imgui.spacing()
    imgui.separator()
    imgui.spacing()

    -- ── Target Type Toggles ──
    imgui.text("Target Selection")

    changed, val = imgui.checkbox("Friendly Fire (allow teammates)", client.get_shared_bool("aimbot_friendly_fire", false))
    if changed then client.set_shared_bool("aimbot_friendly_fire", val) end

    -- Individual entity type checkboxes
    changed, val = imgui.checkbox("Survivors", client.get_shared_bool("aimbot_target_survivors", true))
    if changed then client.set_shared_bool("aimbot_target_survivors", val) end

    changed, val = imgui.checkbox("Smoker",   client.get_shared_bool("aimbot_target_smoker",  true))
    if changed then client.set_shared_bool("aimbot_target_smoker", val) end

    changed, val = imgui.checkbox("Boomer",   client.get_shared_bool("aimbot_target_boomer",  true))
    if changed then client.set_shared_bool("aimbot_target_boomer", val) end

    changed, val = imgui.checkbox("Hunter",   client.get_shared_bool("aimbot_target_hunter",  true))
    if changed then client.set_shared_bool("aimbot_target_hunter", val) end

    changed, val = imgui.checkbox("Spitter",  client.get_shared_bool("aimbot_target_spitter", true))
    if changed then client.set_shared_bool("aimbot_target_spitter", val) end

    changed, val = imgui.checkbox("Jockey",   client.get_shared_bool("aimbot_target_jockey",  true))
    if changed then client.set_shared_bool("aimbot_target_jockey", val) end

    changed, val = imgui.checkbox("Charger",  client.get_shared_bool("aimbot_target_charger", true))
    if changed then client.set_shared_bool("aimbot_target_charger", val) end

    changed, val = imgui.checkbox("Tank",     client.get_shared_bool("aimbot_target_tank",    true))
    if changed then client.set_shared_bool("aimbot_target_tank", val) end

    imgui.spacing()
    imgui.separator()
    imgui.spacing()

    -- ── Feature Flags ──
    imgui.text("Features")

    -- Silent Aim: your crosshair doesn't visually move on your screen
    changed, val = imgui.checkbox("Silent Aim",    client.get_shared_bool("aimbot_silent",     true))
    if changed then client.set_shared_bool("aimbot_silent", val) end

    -- Perfect Silent: stricter server-side-only angle injection
    changed, val = imgui.checkbox("Perfect Silent", client.get_shared_bool("aimbot_psilent",   false))
    if changed then client.set_shared_bool("aimbot_psilent", val) end

    -- Auto Shoot: fires automatically when a target is within FOV
    changed, val = imgui.checkbox("Auto Shoot",    client.get_shared_bool("aimbot_autoshoot",  true))
    if changed then client.set_shared_bool("aimbot_autoshoot", val) end

    -- Draw FOV: shows the targeting cone as a circle overlay
    changed, val = imgui.checkbox("Draw FOV",      client.get_shared_bool("aimbot_draw_fov",   false))
    if changed then client.set_shared_bool("aimbot_draw_fov", val) end
end)

-- Print a confirmation message to the console when the script loads
client.print("[Clean Aimbot] Loaded ")