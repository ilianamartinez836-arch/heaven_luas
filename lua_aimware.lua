local IN_ATTACK2 = 2048
local ZC_HUNTER  = 3
local ZC_JOCKEY  = 5
local VIS_MASK   = 0x46004003

local SWEEP_YAW_START = -45.0
local SWEEP_YAW_END   =  45.0
local SHOVE_HULL      =   3.0

local MARGIN      = 6
local BODY_R      = 8
local CONE_MARGIN = 5
local HOLD_EXTRA  = 2
local FIT_WINDOW  = 0.20
local HORIZON     = 0.30
local STEP        = 0.005

local PRESS_AT_FRAC = 0.3

local tab    = gui.Tab(gui.Reference("Misc"), "as5.tab", "AutoShove")
local box    = gui.Groupbox(tab, "AutoShove V5", 10, 10, 300, 0)
local m_on   = gui.Checkbox(box, "as5.on",    "Enable AutoShove", true)
local m_cone = gui.Checkbox(box, "as5.cone",  "Versus hunter cone (keep on in versus)", true)
local m_lag  = gui.Checkbox(box, "as5.lag",   "Server lag compensation (sv_unlag 1)", true)
local m_pin  = gui.Checkbox(box, "as5.pin",   "Pin lag comp to network record", true)
local m_stag = gui.Checkbox(box, "as5.stag",  "Skip staggered targets", true)
local m_csg  = gui.Checkbox(box, "as5.csg",   "Require 2-tick closing speed confirm", true)
local m_dbg  = gui.Checkbox(box, "as5.dbg",   "Show Debug Info", false)
local m_log  = gui.Checkbox(box, "as5.log",   "Log decisions to console", true)

local log_next = 0
local function dlog(force, fmt, ...)
    if not m_log:GetValue() then return end
    local t = globals.RealTime()
    if not force and t < log_next then return end
    log_next = t + 0.15
    local ok, s = pcall(string.format, fmt, ...)
    print("[AS5] " .. (ok and s or tostring(fmt)))
end

local function now()  return globals.RealTime() end
local function clamp(x, lo, hi) return x < lo and lo or (x > hi and hi or x) end

local function convar(name, default)
    local v; pcall(function() v = tonumber(client.GetConVar(name)) end)
    return v or default
end

local TICK = 1 / 30
local function refresh_tick()
    pcall(function()
        local v = globals.TickInterval()
        if type(v) == "number" and v > 0 then TICK = v end
    end)
end
refresh_tick()

local function local_player()
    local lp; pcall(function() lp = entities.GetLocalPlayer() end); return lp
end
local function alive(e)
    local ok, r = pcall(function() return e:IsAlive() end); return ok and r
end
local function dormant(e)
    local ok, r = pcall(function() return e:IsDormant() end); return ok and r == true
end
local function origin(e)
    local o; pcall(function() o = e:GetAbsOrigin() end); return o
end

local eye_method = nil
local function get_eye(e)
    local eye
    pcall(function() eye = e:GetEyePosition() end)
    if eye and type(eye.x) == "number" and type(eye.z) == "number" then
        eye_method = eye_method or "GetEyePosition"
        return eye
    end
    local o = origin(e)
    if not o then return nil end
    local vo
    pcall(function() vo = e:GetPropVector("m_vecViewOffset[0]") end)
    if vo and type(vo.z) == "number" and vo.z > 1 then
        eye_method = eye_method or "m_vecViewOffset"
        return Vector3(o.x + (vo.x or 0), o.y + (vo.y or 0), o.z + vo.z)
    end
    eye_method = eye_method or "origin+64"
    return Vector3(o.x, o.y, o.z + 64)
end

local function zclass(p)
    local z; pcall(function() z = p:GetPropInt("m_zombieClass") end); return z
end

local function prop_flag(p, name)
    local b
    local ok = pcall(function() b = p:GetPropBool(name) end)
    if ok and type(b) == "boolean" then return b end
    local v; pcall(function() v = p:GetPropInt(name) end)
    if type(v) == "number" then return bit.band(v, 0xFF) == 1 end
    return nil
end

local function is_ghost(p)
    local g = prop_flag(p, "m_isGhost")
    if g ~= nil then return g end
    local ok, r = pcall(function()
        local pr = entities.FindByClass("CTerrorPlayerResource")[1]
        if not pr then return false end
        local v = pr:GetPropInt("m_isGhost", p:GetIndex())
        return type(v) == "number" and bit.band(v, 0xFF) == 1
    end)
    return ok and r == true
end

local function on_ground(p)
    local f; pcall(function() f = p:GetPropInt("m_fFlags") end)
    if type(f) ~= "number" then return nil end
    return bit.band(f, 1) == 1
end

local function pinned(lp)
    for _, n in ipairs({"m_tongueOwner","m_pounceAttacker","m_jockeyAttacker","m_carryAttacker","m_pummelAttacker"}) do
        local v; pcall(function() v = lp:GetPropInt(n) end)
        if type(v) == "number" then
            local idx = v % 2048
            if idx >= 1 and idx <= 64 then return true end
        end
    end
    for _, n in ipairs({"m_isIncapacitated","m_isHangingFromLedge"}) do
        if prop_flag(lp, n) == true then return true end
    end
    return false
end

local function server_now(lp)
    local tb; pcall(function() tb = lp:GetPropInt("m_nTickBase") end)
    if type(tb) == "number" and tb > 0 then return tb * TICK end
    local c; pcall(function() c = globals.CurTime() end)
    return c
end

local function shove_ready(lp, sv_t)
    if type(sv_t) ~= "number" or sv_t <= 0 then return true, 0, 0 end
    local nsa, nst
    pcall(function()
        local w = lp:GetPropEntity("m_hActiveWeapon")
        nsa = w and w:GetPropFloat("m_flNextSecondaryAttack")
    end)
    pcall(function() nst = lp:GetPropFloat("m_flNextShoveTime") end)
    local ww = (type(nsa) == "number") and (nsa - sv_t) or 0
    local fw = (type(nst) == "number") and (nst - sv_t) or 0
    local tol = TICK * 0.5
    return ww <= tol and fw <= tol, ww, fw
end

local function shove_penalty(lp)
    local v; pcall(function() v = lp:GetPropInt("m_iShovePenalty") end)
    return type(v) == "number" and v or nil
end

local function get_local_ping()
    local ping = 0
    pcall(function()
        local pr = entities.FindByClass("CTerrorPlayerResource")[1]
        if pr then
            local lp = entities.GetLocalPlayer()
            if lp then
                local p = pr:GetPropInt("m_iPing", lp:GetIndex())
                if type(p) == "number" and p > 0 then ping = p end
            end
        end
    end)
    return ping
end

local function effective_lerp()
    local interp = convar("cl_interp", 0.1)
    local ratio  = convar("cl_interp_ratio", 2)
    local rate   = convar("cl_updaterate", 30)
    local rmin   = convar("sv_client_min_interp_ratio", 1)
    local rmax   = convar("sv_client_max_interp_ratio", 5)
    if rmin >= 0 and rmax >= rmin then ratio = clamp(ratio, rmin, rmax) end
    if rate <= 0 then rate = 30 end
    return math.max(interp, ratio / rate)
end

local function dist3(ax,ay,az, bx,by,bz)
    local dx,dy,dz = ax-bx, ay-by, az-bz
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function center_z(p)
    local zo = 36
    pcall(function()
        local mn, mx = p:GetMins(), p:GetMaxs()
        if mn and mx and type(mn.z) == "number" and type(mx.z) == "number" and mx.z > mn.z then
            zo = (mn.z + mx.z) * 0.5
        end
    end)
    return zo
end

local hist, srv = {}, {}

local function sample(idx, o, t, air_flag)
    local h = hist[idx]
    if not h then h = {}; hist[idx] = h end
    local last = h[#h]
    if not last or math.abs(last.x - o.x) + math.abs(last.y - o.y) + math.abs(last.z - o.z) > 0.01 then
        h[#h+1] = { t = t, x = o.x, y = o.y, z = o.z, air = air_flag }
    end
    while #h > 0 and t - h[1].t > 0.6 do table.remove(h, 1) end
end

local function sample_srv(p, idx)
    local st, o
    pcall(function() st = p:GetPropFloat("m_flSimulationTime") end)
    pcall(function() o = p:GetPropVector("m_vecOrigin") end)
    if type(st) ~= "number" or st <= 0 or not o or type(o.x) ~= "number"
       or (o.x == 0 and o.y == 0 and o.z == 0) then return false end

    local h = srv[idx]
    if not h then h = {}; srv[idx] = h end
    local last = h[#h]
    if last then
        if st < last.t - 1 then h = {}; srv[idx] = h; last = nil
        elseif st <= last.t then return true end
    end

    local g = on_ground(p)
    if last and (dist3(o.x,o.y,o.z, last.x,last.y,last.z) > 250 or (st - last.t) > 0.5) then
        h = {}; srv[idx] = h
    end
    h[#h+1] = { t = st, x = o.x, y = o.y, z = o.z, air = (g == false) }
    while #h > 0 and st - h[1].t > 0.6 do table.remove(h, 1) end
    return true
end

local function latest_record(idx)
    local h = srv[idx]
    return h and h[#h] or nil
end

local function record_tick(rec, lerp)
    return math.floor((rec.t + lerp) / TICK + 0.5)
end

local stagger_reader = nil
local stagger_method = "untested"
local stagger_tries  = 0
local function find_stagger_reader(p)
    stagger_tries = stagger_tries + 1
    local forms = {
        { "m_staggerTimer.m_timestamp", function(e) return e:GetPropFloat("m_staggerTimer", "m_timestamp") end },
        { "DT_TerrorPlayer/m_staggerTimer", function(e) return e:GetPropFloat("DT_TerrorPlayer", "m_staggerTimer", "m_timestamp") end },
        { "m_staggerTimer.m_timestamp (dotted)", function(e) return e:GetPropFloat("m_staggerTimer.m_timestamp") end },
    }
    for _, f in ipairs(forms) do
        local ok, v = pcall(f[2], p)
        if ok and type(v) == "number" then
            stagger_reader, stagger_method = f[2], f[1]
            return
        end
    end

    stagger_method = stagger_tries >= 20 and "unavailable" or "untested"
end

local function is_staggered(p, sv_t)
    if not m_stag:GetValue() or type(sv_t) ~= "number" then return false end
    if not stagger_reader and stagger_method == "untested" then find_stagger_reader(p) end
    if not stagger_reader then return false end
    local ok, v = pcall(stagger_reader, p)
    return ok and type(v) == "number" and v > sv_t
end

local function fit(h, airborne, grav, T0)
    if not h or #h < 2 then return nil end
    local n = #h
    if T0 - h[n].t > 0.40 then return nil end

    local start = n
    for i = n-1, 1, -1 do
        if h[n].t - h[i].t > FIT_WINDOW then break end
        if h[i].air ~= nil and h[n].air ~= nil and h[i].air ~= h[n].air then break end
        start = i
    end
    if start == n then
        if h[n].air ~= nil and h[n-1].air ~= nil and h[n-1].air ~= h[n].air then return nil end
        start = n - 1
    end

    local tref = h[n].t
    local gg = airborne and grav or 0

    local sw,st2,stt,sx,sy,sz,stx,sty,stz = 0,0,0,0,0,0,0,0,0
    for i = start, n do
        local p = h[i]
        local dt = p.t - tref
        local zc = p.z + 0.5 * gg * dt * dt
        sw  = sw + 1;  st2 = st2 + dt;  stt = stt + dt*dt
        sx  = sx + p.x;  sy = sy + p.y;  sz = sz + zc
        stx = stx + dt*p.x; sty = sty + dt*p.y; stz = stz + dt*zc
    end
    local den = sw * stt - st2 * st2
    if math.abs(den) < 1e-9 then return nil end
    local bx = (sw*stx - st2*sx) / den
    local by = (sw*sty - st2*sy) / den
    local bz = (sw*stz - st2*sz) / den

    if math.sqrt(bx*bx + by*by + bz*bz) > 3000 then return nil end

    return {
        ax = (sx - bx*st2) / sw,
        ay = (sy - by*st2) / sw,
        az = (sz - bz*st2) / sw,
        bx = bx, by = by, bz = bz,
        tref = tref, g = gg,
    }
end

local function traj_at(k, T)
    local dt = T - k.tref
    return k.ax + k.bx*dt, k.ay + k.by*dt, k.az + k.bz*dt - 0.5*k.g*dt*dt
end

local function traj_vel(k, T)
    return k.bx, k.by, k.bz - k.g * (T - k.tref)
end

local function mode_for(c, lagcomp, sv_t)
    if not lagcomp then return "srv" end
    local rec = latest_record(c.idx)
    if m_pin:GetValue() and c.s_ok and rec
       and (type(sv_t) ~= "number" or sv_t - rec.t <= 0.6) then
        return "pin"
    end
    return "seen"
end

local function track(c, grav, sv_t, t, mode)
    local k
    if mode == "pin" then
        local rec = latest_record(c.idx)
        k = fit(srv[c.idx], c.airborne, grav, rec.t)
        if k then return k, rec.t, "pin" end
        mode = "seen"
    end
    if mode == "seen" then
        k = fit(hist[c.idx], c.airborne, grav, t)
        if k then return k, t, "seen" end
    else
        if c.s_ok and sv_t then
            k = fit(srv[c.idx], c.airborne, grav, sv_t)
            if k then return k, sv_t, "srv" end
        end
        k = fit(hist[c.idx], c.airborne, grav, t)
        if k then
            return k, t + get_local_ping() / 1000 + effective_lerp(), "seen+lag"
        end
    end
    return nil, nil, "none"
end

local function target_point(c, grav, sv_t, t, mode)
    if mode == "pin" then
        local rec = latest_record(c.idx)

        if rec and (type(sv_t) ~= "number" or sv_t - rec.t <= 0.6) then
            return rec.x, rec.y, rec.z + c.zoff, record_tick(rec, effective_lerp())
        end
        mode = "seen"
    end
    if mode == "seen" then
        return c.o.x, c.o.y, c.o.z + c.zoff
    end
    local k, Tx = track(c, grav, sv_t, t, "srv")
    if k then
        local x, y, z = traj_at(k, Tx)
        return x, y, z + c.zoff
    end
    return c.o.x, c.o.y, c.o.z + c.zoff
end

local function entry_time(k, Tx, eye, mvx, mvy, mvz, reach, airborne, zoff)
    local tau = 0
    while tau <= HORIZON do
        local x, y, z = traj_at(k, Tx + tau)
        local d = dist3(x, y, z + zoff, eye.x + mvx*tau, eye.y + mvy*tau, eye.z + mvz*tau)
        if d <= reach then return tau, d end
        if airborne and z < eye.z - 110 then
            local _, _, vz = traj_vel(k, Tx + tau)
            if vz < 0 then break end
        end
        tau = tau + STEP
    end
    return nil
end

local CHAR_CLASSES = { CTerrorPlayer=true, SurvivorBot=true, Infected=true, CInfected=true, Witch=true }

local function clear_line(lp, tidx, tx, ty, tz)
    local eye = get_eye(lp)
    if not eye then return true end
    local from, to = eye, Vector3(tx, ty, tz)
    for _ = 1, 4 do
        local ok, tr = pcall(function() return engine.TraceLine(from, to, VIS_MASK) end)
        if not ok or not tr or type(tr.fraction) ~= "number" then return true end
        if tr.fraction >= 0.97 then return true end
        local ent, idx, cls = tr.entity, nil, nil
        pcall(function() idx = ent and ent:GetIndex() end)
        if idx == tidx then return true end
        pcall(function() cls = ent and ent:GetClass() end)
        if not ((idx and idx >= 1 and idx <= 64) or (cls and CHAR_CLASSES[cls])) then return false end
        local e = tr.endpos
        if not e then return true end
        local dv = to - e; local l = dv:Length()
        if l < 8 then return true end
        from = Vector3(e.x + dv.x/l*8, e.y + dv.y/l*8, e.z + dv.z/l*8)
    end
    return true
end

local SHOVE_MASK = 0x4600400b
local function ray_first_hit_is(from, to, tidx)
    local hit = false
    pcall(function()
        local tr = engine.TraceLine(from, to, SHOVE_MASK)
        if tr and tr.entity then
            local idx; pcall(function() idx = tr.entity:GetIndex() end)
            hit = (idx == tidx)
        end
    end)
    return hit
end

local function trace_hits_now(eye, tidx, tx, ty, tz, length)
    local dx, dy, dz = tx - eye.x, ty - eye.y, tz - eye.z
    local l = math.sqrt(dx*dx + dy*dy + dz*dz)
    if l < 1 then return true end
    local fx, fy, fz = dx / l, dy / l, dz / l

    local rx, ry = fy, -fx
    local rl = math.sqrt(rx*rx + ry*ry)
    if rl < 1e-4 then rx, ry, rl = 1, 0, 1 end
    rx, ry = rx / rl, ry / rl
    local ux, uy, uz = ry*fz, -rx*fz, rx*fy - ry*fx
    local h = SHOVE_HULL
    local offs = { {0,0,0}, {rx*h, ry*h, 0}, {-rx*h, -ry*h, 0}, {ux*h, uy*h, uz*h}, {-ux*h, -uy*h, -uz*h} }
    for _, o in ipairs(offs) do
        local from = Vector3(eye.x + o[1], eye.y + o[2], eye.z + o[3])
        local to   = Vector3(from.x + fx*length, from.y + fy*length, from.z + fz*length)
        if ray_first_hit_is(from, to, tidx) then return true end
    end
    return false
end

local function sweep_offset(ticks_since_press, swing_dur)
    local p = clamp(ticks_since_press * TICK / swing_dur, 0, 1)
    return SWEEP_YAW_START + (SWEEP_YAW_END - SWEEP_YAW_START) * p
end

local function max_yaw_in_cone(pitch_deg, cone_deg)
    local s2 = math.sin(math.rad(pitch_deg))^2
    local c2 = 1 - s2
    if c2 < 1e-6 then return 180 end
    local ca = (math.cos(math.rad(cone_deg)) - s2) / c2
    if ca <= -1 then return 180 end
    if ca >= 1 then return 0 end
    return math.deg(math.acos(ca))
end

local function aim_cmd(cmd, eye, tx, ty, tz, yaw_add)
    local dx, dy, dz = tx - eye.x, ty - eye.y, tz - eye.z
    local yaw = math.deg(math.atan2(dy, dx)) + (yaw_add or 0)
    local pit = math.deg(math.atan2(-dz, math.sqrt(dx*dx + dy*dy)))
    while yaw > 180 do yaw = yaw - 360 end
    while yaw < -180 do yaw = yaw + 360 end
    pcall(function()
        local old = cmd:GetViewAngles()
        cmd:SetViewAngles(EulerAngles(clamp(pit, -89, 89), yaw, 0))
        if old then
            local fm, sm = cmd:GetForwardMove(), cmd:GetSideMove()
            local r = math.rad(yaw - old.y)
            local c, s = math.cos(r), math.sin(r)
            cmd:SetForwardMove(fm*c - sm*s)
            cmd:SetSideMove(fm*s + sm*c)
        end
    end)
end

local function view_shift(k, swing_dur, eye, tx, ty, tz, is_hunter)
    local want = -sweep_offset(k, swing_dur)
    if not (is_hunter and m_cone:GetValue()) then return want end
    local fov  = convar("versus_shove_hunter_fov_pouncing", 45)
    local cone = math.max(0, fov * 0.5 - CONE_MARGIN)
    local dx, dy, dz = tx - eye.x, ty - eye.y, tz - eye.z
    local pit = math.deg(math.atan2(-dz, math.sqrt(dx*dx + dy*dy)))
    local A = max_yaw_in_cone(pit, cone)
    return clamp(want, -A, A)
end

local function pin_tick_count(cmd, tick)
    if not tick then return false end
    local ok = pcall(function() cmd.tick_count = tick end)
    return ok
end

local function press_attack2(cmd)
    pcall(function() cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK2)) end)
end

local function own_velocity(lp)
    local ok, x, y, z = pcall(function()
        return lp:GetPropFloat("localdata","m_vecVelocity[0]"),
               lp:GetPropFloat("localdata","m_vecVelocity[1]"),
               lp:GetPropFloat("localdata","m_vecVelocity[2]")
    end)
    if ok and type(x) == "number" and type(y) == "number" then return x, y, z or 0 end
    return 0, 0, 0
end

local air = {}
local last_press = -99
local hold = nil
local dbg_info = {}

local cs_streak = {}

for _, n in ipairs({"ability_use","round_start"}) do
    pcall(function() client.AllowListener(n) end)
end

local function ent_by_userid(uid)
    local e; pcall(function()
        local i = client.GetPlayerIndexByUserID(uid)
        if i and i > 0 then e = entities.GetByIndex(i) end
    end); return e
end

callbacks.Register("FireGameEvent", "as5_events", function(ev)
    local name = ev:GetName()
    if name == "ability_use" then
        local a = ev:GetString("ability")
        if a == "ability_lunge" or a == "ability_leap" then
            local e = ent_by_userid(ev:GetInt("userid"))
            if e then air[e:GetIndex()] = now() end
        end
    elseif name == "round_start" then
        hist = {}; srv = {}; air = {}; hold = nil; last_press = -99; dbg_info = {}
        cs_streak = {}
    end
end)

local api_checked = false
local function api_check(lp)
    if api_checked then return end
    api_checked = true
    local function try(f)
        local ok, v = pcall(f)
        if not ok then return "ERR" end
        if v == nil then return "nil" end
        if type(v) == "table" or type(v) == "userdata" then
            local okx, x = pcall(function() return v.x end)
            if okx and type(x) == "number" then
                return string.format("(%.0f,%.0f,%.0f)", v.x, v.y or 0, v.z or 0)
            end
            return type(v)
        end
        return tostring(v)
    end
    local eye = get_eye(lp)
    print(string.format("[AS5] api check: eye via %s %s | tickbase %s | tick %.4f",
        tostring(eye_method), try(function() return eye end),
        try(function() return lp:GetPropInt("m_nTickBase") end), TICK))
    print(string.format("[AS5] api check: weapon next2nd %s | m_flNextShoveTime %s | m_iShovePenalty %s",
        try(function() return lp:GetPropEntity("m_hActiveWeapon"):GetPropFloat("m_flNextSecondaryAttack") end),
        try(function() return lp:GetPropFloat("m_flNextShoveTime") end),
        try(function() return lp:GetPropInt("m_iShovePenalty") end)))
    print(string.format("[AS5] api check: GetMins %s | GetMaxs %s | ping %s | eff lerp %.3f",
        try(function() return lp:GetMins() end), try(function() return lp:GetMaxs() end),
        try(get_local_ping), effective_lerp()))
    if not stagger_reader and stagger_method == "untested" then find_stagger_reader(lp) end
    print(string.format("[AS5] api check: stagger timer via %s | m_flSimulationTime %s",
        stagger_reader and stagger_method or "not found yet (retrying on targets)",
        try(function() return lp:GetPropFloat("m_flSimulationTime") end)))
end

local tick_checked = false
local function tick_count_check(cmd)
    if tick_checked then return end
    tick_checked = true
    local ok, v = pcall(function() return cmd.tick_count end)
    local okw = ok and type(v) == "number" and pcall(function() cmd.tick_count = v end)
    print(string.format("[AS5] api check: cmd.tick_count read %s (%s) write %s",
        ok and "ok" or "ERR", tostring(v), okw and "ok" or "ERR"))
end

local function tick(cmd)
    local lp = local_player()
    if not m_on:GetValue() or not lp or not alive(lp) or lp:GetTeamNumber() ~= 2 then
        hold = nil; return
    end

    local t = now()
    local me = origin(lp)
    if not me then return end
    local eye = get_eye(lp)
    refresh_tick()
    api_check(lp)
    tick_count_check(cmd)

    local cands = {}
    pcall(function()
        for _, p in pairs(entities.FindByClass("CTerrorPlayer")) do
            if p:GetTeamNumber() == 3 then
                local idx = p:GetIndex()
                if not alive(p) or dormant(p) or is_ghost(p) then
                    hist[idx] = nil; air[idx] = nil; srv[idx] = nil; cs_streak[idx] = nil
                else
                    local z = zclass(p)
                    if z == ZC_HUNTER or z == ZC_JOCKEY then
                        local o = origin(p)
                        if o then
                            local flying   = air[idx] and (t - air[idx] < 1.6)
                            local airborne = flying or on_ground(p) == false
                            sample(idx, o, t, airborne)
                            local s_ok = sample_srv(p, idx)
                            cands[#cands+1] = { p = p, idx = idx, z = z, o = o, zoff = center_z(p),
                                                flying = flying, airborne = airborne, s_ok = s_ok }
                        end
                    end
                end
            end
        end
    end)

    if pinned(lp) then hold = nil; return end

    local swing_dur = convar("z_gun_swing_duration", 0.2)
    if swing_dur <= 0 then swing_dur = 0.2 end
    local grav    = convar("sv_gravity", 800)
    local sv_t    = server_now(lp)
    local lagcomp = m_lag:GetValue()

    if hold then
        hold.k = hold.k + 1
        if hold.k <= hold.ticks then
            for _, cc in ipairs(cands) do
                if cc.idx == hold.idx then
                    local mode = mode_for(cc, lagcomp, sv_t)
                    local ax, ay, az, ptick = target_point(cc, grav, sv_t, t, mode)
                    hold.ax, hold.ay, hold.az, hold.ptick = ax, ay, az, ptick
                end
            end
            local shift = view_shift(hold.k, swing_dur, eye, hold.ax, hold.ay, hold.az, hold.hunter)
            aim_cmd(cmd, eye, hold.ax, hold.ay, hold.az, shift)
            press_attack2(cmd)
            pin_tick_count(cmd, hold.ptick)
            return
        end
        hold = nil
    end

    if #cands == 0 then return end

    local near_d = math.huge
    for _, c in ipairs(cands) do
        local dd = dist3(c.o.x, c.o.y, c.o.z + c.zoff, eye.x, eye.y, eye.z)
        if dd < near_d then near_d = dd end
    end
    local near = near_d < 400

    local interval = convar("z_gun_swing_interval", 0.7)
    if t - last_press < interval * 0.9 then
        if near then dlog(false, "cooldown (%.2fs since last press)", t - last_press) end
        return
    end
    local ready, ww, fw = shove_ready(lp, sv_t)
    dbg_info.wait_w, dbg_info.wait_f = ww, fw
    if not ready then
        if near then dlog(false, "not ready: weapon wait %.2fs, fatigue wait %.2fs (sv_t %.2f)", ww, fw, sv_t or -1) end
        return
    end

    local mvx, mvy, mvz = own_velocity(lp)
    local reach     = convar("z_gun_range", 75) + SHOVE_HULL + BODY_R - MARGIN
    local trace_len = convar("z_gun_range", 75) + SHOVE_HULL

    local press_at  = swing_dur * PRESS_AT_FRAC

    local tracked_now = {}

    local best, best_d = nil, math.huge
    for _, c in ipairs(cands) do
        tracked_now[c.idx] = true
        local mode = mode_for(c, lagcomp, sv_t)
        local k, Tx, path = track(c, grav, sv_t, t, mode)
        local cx, cy, cz, ptick = target_point(c, grav, sv_t, t, mode)
        local d = dist3(cx, cy, cz, eye.x, eye.y, eye.z)

        local should, e, why, cs = false, nil, nil, nil
        local staggered = is_staggered(c.p, sv_t)

        local now_hit = false
        local rx0, ry0, rz0 = c.o.x, c.o.y, c.o.z + c.zoff
        if not staggered and dist3(rx0, ry0, rz0, eye.x, eye.y, eye.z) <= trace_len + 24 then
            now_hit = trace_hits_now(eye, c.idx, rx0, ry0, rz0, trace_len)
        end
        if staggered then
            why = "already staggered, skipping"
            cs_streak[c.idx] = nil
        elseif k then
            local vx, vy, vz = traj_vel(k, Tx)
            local rx, ry, rz = vx - mvx, vy - mvy, vz - mvz
            local dx, dy, dz = eye.x - cx, eye.y - cy, eye.z - cz
            local dl = math.max(1, math.sqrt(dx*dx + dy*dy + dz*dz))
            cs = (rx*dx + ry*dy + rz*dz) / dl

            local min_cs
            if c.flying then min_cs = 80
            elseif c.z == ZC_HUNTER then min_cs = 180
            else min_cs = 140 end

            if now_hit and (cs > 30 or c.flying) then
                should, e, path = true, 0, path .. "+trace"
                cs_streak[c.idx] = nil
            elseif d <= reach and (cs > 30 or c.flying) then
                should, e = true, 0
                cs_streak[c.idx] = nil
            elseif d <= reach then
                why = string.format("in reach but not closing (cs %.0f)", cs)
                cs_streak[c.idx] = nil
            elseif cs >= min_cs then

                cs_streak[c.idx] = (cs_streak[c.idx] or 0) + 1
                local confirmed = (not m_csg:GetValue()) or cs_streak[c.idx] >= 2

                if not confirmed then
                    why = string.format("cs %.0f >= %.0f but unconfirmed (streak %d/2)",
                        cs, min_cs, cs_streak[c.idx])
                else
                    e = entry_time(k, Tx, eye, mvx, mvy, mvz, reach, c.airborne, c.zoff)
                    if e and e <= press_at then should = true
                    elseif e then why = string.format("entry %.3fs > %.3fs, waiting", e, press_at)
                    else why = "no entry within horizon" end
                end
            else
                why = string.format("closing %.0f < %.0f", cs, min_cs)
                cs_streak[c.idx] = nil
            end
        elseif c.flying and (d <= reach or now_hit) then
            should, e = true, 0
            cs_streak[c.idx] = nil
        else
            why = why or "no track yet"
            cs_streak[c.idx] = nil
        end

        if should and not clear_line(lp, c.idx, cx, cy, cz) then
            should, why = false, "line of sight blocked"
        end

        if d < 400 and not should then
            dlog(false, "%s d=%.0f reach=%.0f track=%s fly=%s: %s",
                c.z == ZC_HUNTER and "hunter" or "jockey", d, reach, path,
                tostring(c.flying), why or "?")
        end

        if should and d < best_d then
            best = { c = c, ax = cx, ay = cy, az = cz, ptick = ptick }
            best_d = d
            dbg_info.dist, dbg_info.entry, dbg_info.path = d, e, path
            dbg_info.flying = c.flying
        end
    end

    for idx in pairs(cs_streak) do
        if not tracked_now[idx] then cs_streak[idx] = nil end
    end

    if not best then return end

    local hunter = best.c.z == ZC_HUNTER
    local shift = view_shift(0, swing_dur, eye, best.ax, best.ay, best.az, hunter)
    aim_cmd(cmd, eye, best.ax, best.ay, best.az, shift)
    press_attack2(cmd)
    local pinned_ok = pin_tick_count(cmd, best.ptick)
    last_press = t
    cs_streak[best.c.idx] = nil
    hold = { idx = best.c.idx, hunter = hunter, k = 0,
             ticks = math.ceil(swing_dur / TICK) + HOLD_EXTRA,
             ax = best.ax, ay = best.ay, az = best.az, ptick = best.ptick }
    dbg_info.presses = (dbg_info.presses or 0) + 1
    dbg_info.ptick = best.ptick
    dlog(true, "PRESS #%d at d=%.0f entry=%s track=%s shift=%.1f pin=%s",
        dbg_info.presses, best_d, dbg_info.entry and string.format("%.3f", dbg_info.entry) or "-",
        tostring(dbg_info.path), shift,
        best.ptick and (pinned_ok and tostring(best.ptick) or "FAILED") or "off")
end

local last_err = -99
callbacks.Register("CreateMove", "as5_tick", function(cmd)
    local ok, err = pcall(tick, cmd)
    if not ok then
        local t = globals.RealTime()
        if t - last_err > 2 then
            last_err = t
            print("[AS5] ERROR in tick: " .. tostring(err))
        end
    end
end)

local dbg_font = nil
local function draw_dbg()
    if not m_on:GetValue() or not m_dbg:GetValue() then return end
    if not dbg_font then dbg_font = draw.CreateFont("Tahoma", 12, 600) end
    draw.SetFont(dbg_font)

    local _, sh = draw.GetScreenSize()
    local x, y = 10, sh - 188
    draw.Color(0, 0, 0, 160)
    draw.FilledRect(x, y, x + 340, y + 178)
    draw.Color(255, 255, 255, 255)

    local lp = local_player()
    local swing_dur = convar("z_gun_swing_duration", 0.2)
    local pen = lp and shove_penalty(lp)
    local fov = convar("versus_shove_hunter_fov_pouncing", 45)

    draw.Text(x+4, y+4,  "AutoShove V5")
    draw.Text(x+4, y+20, string.format("Ping %dms  eff. lerp %.3fs  tick %.4f  lagcomp %s",
        get_local_ping(), effective_lerp(), TICK, m_lag:GetValue() and "on" or "off"))
    draw.Text(x+4, y+36, string.format("Swing %.2fs = %d ticks, press when entry <= %.3fs (%.0f%% of swing)",
        swing_dur, math.ceil(swing_dur / TICK), swing_dur * PRESS_AT_FRAC, PRESS_AT_FRAC * 100))
    draw.Text(x+4, y+52, string.format("Reach eye->center %.0f   hunter cone %s (%.1f deg)",
        convar("z_gun_range", 75) + SHOVE_HULL + BODY_R - MARGIN,
        m_cone:GetValue() and "on" or "off", math.max(0, fov * 0.5 - CONE_MARGIN)))
    draw.Text(x+4, y+68, string.format("Wait: weapon %.2fs  fatigue %.2fs  penalty %s",
        math.max(0, dbg_info.wait_w or 0), math.max(0, dbg_info.wait_f or 0), pen and tostring(pen) or "?"))
    draw.Text(x+4, y+84, hold and string.format("HOLDING tick %d/%d (%s)", hold.k, hold.ticks,
        hold.hunter and "hunter" or "jockey") or "idle")
    draw.Text(x+4, y+100, string.format("CS confirm gate %s  (hunter min 180, jockey min 140/80 flying)",
        m_csg:GetValue() and "on (2-tick)" or "off"))

    if dbg_info.dist then
        draw.Color(0, 255, 100, 255)
        draw.Text(x+4, y+116, string.format("Last press #%d: d=%.0f entry=%s",
            dbg_info.presses or 0, dbg_info.dist,
            dbg_info.entry and string.format("%.3fs", dbg_info.entry) or "-"))
        draw.Text(x+4, y+132, string.format("  track=%s flying=%s pin=%s", tostring(dbg_info.path),
            tostring(dbg_info.flying), dbg_info.ptick and tostring(dbg_info.ptick) or "off"))
    end
    draw.Color(255, 255, 255, 255)
    draw.Text(x+4, y+148, string.format("Pin record %s   stagger skip %s (%s)",
        m_pin:GetValue() and "on" or "off", m_stag:GetValue() and "on" or "off", stagger_method))
end

local last_draw_err = -99
callbacks.Register("Draw", "as5_dbg", function()
    local ok, err = pcall(draw_dbg)
    if not ok then
        local t = globals.RealTime()
        if t - last_draw_err > 2 then
            last_draw_err = t
            print("[AS5] ERROR in draw: " .. tostring(err))
        end
    end
end)

callbacks.Register("Unload", "as5_unload", function()
    callbacks.Unregister("CreateMove", "as5_tick")
    callbacks.Unregister("FireGameEvent", "as5_events")
    callbacks.Unregister("Draw", "as5_dbg")
end)

print("[AutoShove V5] loaded - cs-confirm gate, tighter press window, higher jockey threshold, record pinning, stagger skip, hull check, sweep hold, versus cone, fatigue-aware")
