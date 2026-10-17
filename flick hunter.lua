local IN_ATTACK = 1
local HUNTER = 3
local INFECTED_TEAM = 3

local ref = gui.Reference("Misc")
local tab = gui.Tab(ref, "hflick.tab", "Hunter Flick")

local box = gui.Groupbox(tab, "Hunter Flick", 16, 16, 296, 0)
local enable    = gui.Checkbox(box, "hflick.enable", "Enable", false)
local mode      = gui.Combobox(box, "hflick.mode", "Trigger", "When I shoot", "Auto shoot on key")
local key       = gui.Keybox(box, "hflick.key", "Key (auto shoot / 0 = always)", 0)
local fov       = gui.Slider(box, "hflick.fov", "FOV", 25, 1, 180)
local hitbox    = gui.Combobox(box, "hflick.hitbox", "Aim at", "Head", "Body center")
local silent    = gui.Checkbox(box, "hflick.silent", "Silent (camera doesn't move)", false)
local use_sniper  = gui.Checkbox(box, "hflick.snipers", "Sniper rifles", true)
local use_shotgun = gui.Checkbox(box, "hflick.shotguns", "Shotguns", false)
local show_fov  = gui.Checkbox(box, "hflick.showfov", "Show FOV circle", true)
local fov_col   = gui.ColorPicker(box, "hflick.fovcol", "FOV circle color", 255, 255, 255, 120)
local ret_cam   = gui.Checkbox(box, "hflick.return", "Return camera after shot", true)
local ret_ticks = gui.Slider(box, "hflick.returnticks", "Return after (ticks)", 1, 1, 10)

local box2 = gui.Groupbox(tab, "Filters", 328, 16, 296, 0)
local pounce_only = gui.Checkbox(box2, "hflick.pounce", "Only Hunters in the air / pouncing", true)
local vis_only    = gui.Checkbox(box2, "hflick.vis", "Only visible Hunters", true)

local show_target = gui.Checkbox(box2, "hflick.draw", "Mark current target", true)
local pause_aw    = gui.Checkbox(box2, "hflick.pauseaw", "Pause Aimware aimbot while flicking", true)

local box3 = gui.Groupbox(tab, "Shotgun auto skeet", 328, 240, 296, 0)
local auto_skeet  = gui.Checkbox(box3, "hflick.autoskeet", "Auto skeet (shotguns)", false)
local skeet_range = gui.Slider(box3, "hflick.skeetrange", "Skeet distance", 160, 50, 400)
local skeet_fov   = gui.Slider(box3, "hflick.skeetfov", "Auto skeet FOV", 90, 1, 180)
local skeet_lead  = gui.Slider(box3, "hflick.skeetlead", "Fire early (ticks)", 1, 0, 4)
local debug_log   = gui.Checkbox(box3, "hflick.debug", "Debug messages in console", false)

local function yaw_norm(y)
    while y > 180 do y = y - 360 end
    while y < -180 do y = y + 360 end
    return y
end

local function calc_angle(src, dst)
    local dx, dy, dz = dst.x - src.x, dst.y - src.y, dst.z - src.z
    local hyp = math.sqrt(dx * dx + dy * dy)
    local pitch = math.deg(math.atan2(-dz, hyp))
    local yaw = math.deg(math.atan2(dy, dx))
    if pitch > 89 then pitch = 89 elseif pitch < -89 then pitch = -89 end
    return pitch, yaw
end

local function ang_fov(view, pitch, yaw)
    local dp = pitch - view.x
    local dy = yaw_norm(yaw - view.y)
    return math.sqrt(dp * dp + dy * dy)
end

local function prop_int(ent, name)
    local ok, v = pcall(function() return ent:GetPropInt(name) end)
    if ok and type(v) == "number" then return v end
    return nil
end

local function prop_float(ent, name)
    local ok, v = pcall(function() return ent:GetPropFloat(name) end)
    if ok and type(v) == "number" then return v end
    return nil
end

local function active_weapon(ply)
    local ok, wep = pcall(function() return ply:GetPropEntity("m_hActiveWeapon") end)
    if ok and wep ~= nil then return wep end
    local ok2, h = pcall(function() return ply:GetProp("m_hActiveWeapon") end)
    if ok2 and type(h) == "number" and h ~= 0 and h ~= -1 then
        return entities.GetByIndex(h % 2048)
    end
    return nil
end

local function weapon_class(wep)
    if not wep then return nil end
    local ok, cls = pcall(function() return wep:GetClass() end)
    if ok and type(cls) == "string" then return cls end
    return nil
end

local function is_shotgun(wep)
    local cls = weapon_class(wep)
    return cls ~= nil and cls:find("Shotgun") ~= nil
end

local function weapon_allowed(wep)
    if not wep then return false end
    local ok, cls = pcall(function() return wep:GetClass() end)
    if not ok or type(cls) ~= "string" then return false end
    if use_sniper:GetValue() and (cls:find("Sniper") or cls:find("AWP") or cls:find("Scout")) then return true end
    if use_shotgun:GetValue() and cls:find("Shotgun") then return true end
    return false
end

local TICK = 1 / 30
pcall(function()
    local t = globals.TickInterval and globals.TickInterval()
    if type(t) == "number" and t > 0 then TICK = t end
end)

local function server_time(me)
    local tb = prop_int(me, "m_nTickBase")
    if tb and tb > 0 then return tb * TICK end
    return globals.CurTime()
end

local function can_fire(wep, me)
    local clip = prop_int(wep, "m_iClip1")
    if clip ~= nil and clip <= 0 then return false end
    local nxt = prop_float(wep, "m_flNextPrimaryAttack")
    if nxt ~= nil and nxt > server_time(me) + TICK * 0.5 then return false end
    return true
end


local function in_air(ent)
    local ok, b = pcall(function() return ent:GetPropBool("m_isAttemptingToPounce") end)
    if ok and b == true then return true end
    if not (ok and type(b) == "boolean") then
        local p = prop_int(ent, "m_isAttemptingToPounce")
        if p and bit.band(p, 0xFF) == 1 then return true end
    end
    local flags = prop_int(ent, "m_fFlags")
    if flags == nil then return true end
    return flags % 2 == 0
end

local function is_ghost(ent)
    local ok, b = pcall(function() return ent:GetPropBool("m_isGhost") end)
    if ok and type(b) == "boolean" then return b end
    local g = prop_int(ent, "m_isGhost")
    return g ~= nil and bit.band(g, 0xFF) == 1
end

local function eye_pos(me)
    local ok, e = pcall(function() return me:GetEyePosition() end)
    if ok and e then return e end
    local o = me:GetAbsOrigin()
    local ok2, off = pcall(function() return me:GetPropVector("m_vecViewOffset[0]") end)
    if ok2 and off then return o + off end
    return o + Vector3(0, 0, 64)
end

local function aim_point(ent)
    if hitbox:GetValue() == 0 then
        local ok, a, b, c = pcall(function() return ent:GetHitboxPosition(10) end)
        if ok and a ~= nil then
            if type(a) == "number" then return Vector3(a, b, c) end
            return a
        end
    end
    local o = ent:GetAbsOrigin()
    local ok, mn, mx = pcall(function() return ent:GetMins(), ent:GetMaxs() end)
    if ok and mn and mx then
        return Vector3(o.x + (mn.x + mx.x) * 0.5, o.y + (mn.y + mx.y) * 0.5, o.z + (mn.z + mx.z) * 0.5)
    end
    return o + Vector3(0, 0, 24)
end

local function visible(from, to, ent)
    local ok, tr = pcall(function() return engine.TraceLine(from, to, 0x4600400B) end)
    if not ok or not tr then return true end
    local frac = tr.fraction
    if type(frac) ~= "number" then return true end
    if frac >= 0.97 then return true end
    local hit_ok, same = pcall(function()
        local e = tr.entity
        if e == nil then return false end
        if type(e) == "number" then return e == ent:GetIndex() end
        return e:GetIndex() == ent:GetIndex()
    end)
    if hit_ok and same then return true end
    local dist = (to - from):Length()
    return (1 - frac) * dist < 40
end

local track = {}

local function tracked_velocity(ent)
    local idx = ent:GetIndex()
    local pos = ent:GetAbsOrigin()
    local t = prop_float(ent, "m_flSimulationTime") or globals.CurTime()
    local rec = track[idx]
    if not rec then
        track[idx] = { pos = pos, t = t, vel = Vector3(0, 0, 0) }
        return track[idx].vel
    end
    local dt = t - rec.t
    if dt > 0.001 then
        if dt < 0.5 then
            rec.vel = Vector3((pos.x - rec.pos.x) / dt, (pos.y - rec.pos.y) / dt, (pos.z - rec.pos.z) / dt)
        else
            rec.vel = Vector3(0, 0, 0)
        end
        rec.pos, rec.t = pos, t
    end
    return rec.vel
end

local function own_velocity(me)
    local ok2, x, y, z = pcall(function()
        return me:GetPropFloat("localdata", "m_vecVelocity[0]"), me:GetPropFloat("localdata", "m_vecVelocity[1]"), me:GetPropFloat("localdata", "m_vecVelocity[2]")
    end)
    if ok2 and type(x) == "number" then return Vector3(x, y or 0, z or 0) end
    local ok, v = pcall(function() return me:GetPropVector("m_vecVelocity") end)
    if ok and v and type(v.x) == "number" then return v end
    return Vector3(0, 0, 0)
end

local last_dbg = 0
local function dbg(msg)
    if not debug_log:GetValue() then return end
    local now = globals.RealTime()
    if now - last_dbg < 0.25 then return end
    last_dbg = now
    print("[hunterflick] " .. msg)
end

local function skeet_ready(me, ent, eye)
    local hv = tracked_velocity(ent)
    if not in_air(ent) then return false end
    local hp = ent:GetAbsOrigin() + Vector3(0, 0, 32)
    local to_me = eye - hp
    local dist = to_me:Length()
    if dist <= 90 then dbg(string.format("skeet: point blank %.0f", dist)); return true end
    local mv = own_velocity(me)
    local rx, ry, rz = hv.x - mv.x, hv.y - mv.y, hv.z - mv.z
    local closing = (rx * to_me.x + ry * to_me.y + rz * to_me.z) / dist
    local t = TICK * (skeet_lead:GetValue() + 1)
    local pred = dist - math.max(closing, 0) * t
    if dist < skeet_range:GetValue() * 2.5 then
        dbg(string.format("hunter in air: dist %.0f closing %.0f u/s predicted %.0f (fires at %d)", dist, closing, pred, skeet_range:GetValue()))
    end
    if closing < 100 then return dist <= skeet_range:GetValue() * 0.6 end
    return pred <= skeet_range:GetValue()
end

local function find_target(me, view, max_fov, skeet)
    local eye = eye_pos(me)
    local best, best_p, best_y, best_pos, best_fov = nil, nil, nil, nil, max_fov or fov:GetValue()
    for _, ent in pairs(entities.FindByClass("CTerrorPlayer") or {}) do
        if ent:GetIndex() ~= me:GetIndex() and ent:IsAlive() and not ent:IsDormant()
            and ent:GetTeamNumber() == INFECTED_TEAM and prop_int(ent, "m_zombieClass") == HUNTER then
            local tag = "hunter #" .. ent:GetIndex()
            if is_ghost(ent) then
                dbg(tag .. " skipped: ghost")
            else
                local ok_air
                if skeet then ok_air = skeet_ready(me, ent, eye) else ok_air = not pounce_only:GetValue() or in_air(ent) end
                if not ok_air then
                    if not skeet then dbg(tag .. " skipped: not in the air") end
                else
                    local pos = aim_point(ent)
                    local p, y = calc_angle(eye, pos)
                    local f = ang_fov(view, p, y)
                    if f >= best_fov then
                        dbg(string.format("%s skipped: outside FOV (%.1f)", tag, f))
                    elseif vis_only:GetValue() and not visible(eye, pos, ent) then
                        dbg(tag .. " skipped: not visible")
                    else
                        best, best_p, best_y, best_pos, best_fov = ent, p, y, pos, f
                    end
                end
            end
        end
    end
    return best, best_p, best_y, best_pos
end

local function get_buttons(cmd)
    local ok, b = pcall(function() return cmd:GetButtons() end)
    if ok and type(b) == "number" then return b end
    return cmd.buttons or 0
end

local function set_buttons(cmd, b)
    if not pcall(function() cmd:SetButtons(b) end) then cmd.buttons = b end
end

local pending_return = nil

local function set_cmd_angles(cmd, a)
    if not pcall(function() cmd:SetViewAngles(a) end) then cmd.viewangles = a end
end

local AW_KEYS = { "lbot.aim.enable", "rbot.enable" }
local aw_saved = nil
local aw_pause_until = 0

local function aw_get(k)
    local ok, v = pcall(gui.GetValue, k)
    if ok then return v end
    return nil
end

local function aw_pause()
    if not pause_aw:GetValue() then return end
    aw_pause_until = globals.RealTime() + 0.3
    if aw_saved then return end
    aw_saved = {}
    for _, k in ipairs(AW_KEYS) do
        local v = aw_get(k)
        if v ~= nil then
            aw_saved[k] = v
            pcall(gui.SetValue, k, false)
        end
    end
end

local function aw_restore(force)
    if not aw_saved then return end
    if not force and globals.RealTime() < aw_pause_until then return end
    for k, v in pairs(aw_saved) do pcall(gui.SetValue, k, v) end
    aw_saved = nil
end

local skeet_was_on = false
local ret_saved = nil

local function sync_return_option()
    local on = auto_skeet:GetValue()
    if on and not skeet_was_on then
        ret_saved = ret_cam:GetValue()
        pcall(function() ret_cam:SetValue(false) end)
    elseif not on and skeet_was_on then
        if ret_saved ~= nil then pcall(function() ret_cam:SetValue(ret_saved) end) end
        ret_saved = nil
    end
    skeet_was_on = on
end

local function set_angles(cmd, p, y)
    local a = EulerAngles(p, y, 0)
    set_cmd_angles(cmd, a)
    if silent:GetValue() then return end
    local before = engine.GetViewAngles()
    engine.SetViewAngles(a)
    if ret_cam:GetValue() and not auto_skeet:GetValue() then
        if pending_return then before = pending_return.saved end
        pending_return = { saved = EulerAngles(before.x, before.y, 0), flick = EulerAngles(p, y, 0), ticks = ret_ticks:GetValue() }
    end
end

local function do_return(cmd)
    if not pending_return then return end
    pending_return.ticks = pending_return.ticks - 1
    if pending_return.ticks > 0 then return end
    local cur = engine.GetViewAngles()
    local s, f = pending_return.saved, pending_return.flick
    local px = s.x + (cur.x - f.x)
    local py = yaw_norm(s.y + yaw_norm(cur.y - f.y))
    if px > 89 then px = 89 elseif px < -89 then px = -89 end
    local a = EulerAngles(px, py, 0)
    engine.SetViewAngles(a)
    set_cmd_angles(cmd, a)
    pending_return = nil
end

local marked = nil
local sent_attack = false
local press_time = -1
local skeet_lock = nil
local last_props = 0

local function aim_at(cmd, me, ent)
    local pos = aim_point(ent)
    local p, y = calc_angle(eye_pos(me), pos)
    marked = pos
    set_angles(cmd, p, y)
end

local function ent_ok(ent)
    local ok, v = pcall(function() return ent:IsAlive() and not ent:IsDormant() end)
    return ok and v
end

local function finish(cmd, buttons, attack_on)
    if attack_on then
        buttons = bit.bor(buttons, IN_ATTACK)
    else
        buttons = bit.band(buttons, bit.bnot(IN_ATTACK))
    end
    set_buttons(cmd, buttons)
    sent_attack = attack_on
end

local function auto_fire(cmd, me, wep, buttons, ent)
    if sent_attack then
        finish(cmd, buttons, false)
        return
    end
    if not can_fire(wep, me) then return end
    aim_at(cmd, me, ent)
    finish(cmd, buttons, true)
end

local function flick_tick(cmd)
    marked = nil
    if not cmd then return end
    pcall(sync_return_option)
    pcall(do_return, cmd)
    if not enable:GetValue() then sent_attack, skeet_lock = false, nil; return end

    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then sent_attack, skeet_lock = false, nil; return end

    local wep = active_weapon(me)
    local skeet_on = auto_skeet:GetValue() and is_shotgun(wep)
    local flick_on = weapon_allowed(wep)
    if not skeet_on and not flick_on then sent_attack, skeet_lock = false, nil; return end

    for _, ent in pairs(entities.FindByClass("CTerrorPlayer") or {}) do
        if ent:GetTeamNumber() == INFECTED_TEAM and not ent:IsDormant() then pcall(tracked_velocity, ent) end
    end

    local buttons = get_buttons(cmd)
    local user_attack = bit.band(buttons, IN_ATTACK) ~= 0
    local now = globals.RealTime()

    if debug_log:GetValue() and now - last_props > 2 then
        last_props = now
        local clip, nxt = prop_int(wep, "m_iClip1"), prop_float(wep, "m_flNextPrimaryAttack")
        print(string.format("[hunterflick] weapon %s clip %s next_attack %s server_time %.2f can_fire %s",
            tostring(weapon_class(wep)), tostring(clip), tostring(nxt), server_time(me), tostring(can_fire(wep, me))))
    end

    local view = engine.GetViewAngles()

    if skeet_on then
        if skeet_lock and (not ent_ok(skeet_lock.ent) or now - skeet_lock.t > 0.35) then skeet_lock = nil end
        if not skeet_lock then
            local st = find_target(me, view, skeet_fov:GetValue(), true)
            if st then skeet_lock = { ent = st, t = now }; dbg("skeet: target locked") end
        end
        if skeet_lock then
            auto_fire(cmd, me, wep, buttons, skeet_lock.ent)
            return
        end
    end

    if not flick_on then
        if sent_attack and not user_attack then finish(cmd, buttons, false) end
        sent_attack = false
        return
    end

    local target, _, _, pos = find_target(me, view)
    if target then marked = pos end

    if mode:GetValue() == 0 then
        local pressed = user_attack and not sent_attack
        sent_attack = user_attack
        if pressed then press_time = now end
        if not target or not user_attack then return end
        local nxt = prop_float(wep, "m_flNextPrimaryAttack")
        local in_window = now - press_time <= 0.25
        if pressed or (in_window and nxt ~= nil and can_fire(wep, me)) then
            aim_at(cmd, me, target)
        end
        return
    end

    local k = key:GetValue()
    if not target or (k ~= 0 and not input.IsButtonDown(k)) then
        if sent_attack then finish(cmd, buttons, false) end
        return
    end
    auto_fire(cmd, me, wep, buttons, target)
end

callbacks.Register("CreateMove", "hunter_flick", function(cmd)
    local ok, err = pcall(flick_tick, cmd)
    if not ok then dbg("error: " .. tostring(err)) end
    if not pause_aw:GetValue() then
        aw_restore(true)
    elseif marked or skeet_lock then
        aw_pause()
    else
        aw_restore(false)
    end
end)

local function game_fov(me)
    local f = prop_int(me, "m_iFOV")
    if not f or f <= 0 then
        local ok, v = pcall(function() return tonumber(client.GetConVar("fov_desired")) end)
        f = (ok and v and v > 0) and v or 90
    end
    return f
end

local function draw_fov_circle()
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() or not weapon_allowed(active_weapon(me)) then return end
    local w, h = draw.GetScreenSize()
    local base = math.rad(game_fov(me)) / 2
    local hfov = math.atan(math.tan(base) * (w / h) / (4 / 3))
    local f = math.min(fov:GetValue(), 89)
    local r = math.tan(math.rad(f)) / math.tan(hfov) * (w / 2)
    r = math.min(r, math.sqrt(w * w + h * h) / 2)
    local cr, cg, cb, ca = fov_col:GetValue()
    draw.Color(cr, cg, cb, ca)
    draw.OutlinedCircle(math.floor(w / 2), math.floor(h / 2), math.floor(r))
end

callbacks.Register("Draw", "hunter_flick_draw", function()
    if not enable:GetValue() then return end
    if show_fov:GetValue() then pcall(draw_fov_circle) end
    if not show_target:GetValue() or not marked then return end
    local sx, sy = client.WorldToScreen(marked)
    if not sx or not sy then return end
    draw.Color(255, 60, 60, 255)
    draw.OutlinedCircle(sx, sy, 6)
    draw.Line(sx - 10, sy, sx - 4, sy)
    draw.Line(sx + 4, sy, sx + 10, sy)
end)

callbacks.Register("Unload", function()
    marked = nil
    skeet_lock = nil
    pending_return = nil
    aw_restore(true)
    if ret_saved ~= nil then pcall(function() ret_cam:SetValue(ret_saved) end) end
    pcall(function() tab:Remove() end)
end)
