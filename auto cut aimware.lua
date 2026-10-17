local LOG_FILE = "aimware_autocut_log.txt"

local tab = gui.Tab(gui.Reference("Misc"), "ac.tab", "AutoCut")
local ref  = gui.Groupbox(tab, "AutoCut (smoker tongue)", 10, 10, 320, 0)
local m_on      = gui.Checkbox(ref, "ac.on",       "AutoCut (smoker tongue)", true)
local m_melee   = gui.Checkbox(ref, "ac.melee",    "  only cut with a melee out", true)
local m_switch  = gui.Checkbox(ref, "ac.switch",   "  swap to melee when a tongue comes", true)
local m_back    = gui.Checkbox(ref, "ac.back",     "  switch back to the gun afterwards", true)
local m_pre     = gui.Checkbox(ref, "ac.preswap",  "  pre-swap when a smoker aims at you", true)
local m_sight   = gui.Checkbox(ref, "ac.presight", "  pre-swap when a smoker sees you in range", true)
local m_vis     = gui.Checkbox(ref, "ac.vis",      "  only react to smokers that can see you", true)
local m_pitch   = gui.Checkbox(ref, "ac.pitch",    "  pitch-down cut (aim toward the smoker)", true)
local m_visible = gui.Checkbox(ref, "ac.visible",  "  show the cut aim on screen (off = silent)", false)
local m_log     = gui.Checkbox(ref, "ac.log",      "  log tongues to aimware_autocut_log.txt", false)
local m_visline = gui.Checkbox(ref, "ac.visline",  "  draw the see-check line (green = sees you, red = blocked)", false)
local m_status  = gui.Checkbox(ref, "ac.status",   "  status text on screen", false)

local LEAD_MS   = 150
local TILT_DEG  = 25
local TOL_DEG   = 10
local DEPLOY_MS = 500
local OFFSET_MS = 0

local IN_ATTACK = 1
local ZC_SMOKER = 1
local TICK = 1 / 30
local MELEE = { CTerrorMeleeWeapon = true, CChainsaw = true }

local function now() return globals.RealTime() end
local function log(s)
    print("[AutoCut] " .. s)
    if m_log:GetValue() then
        pcall(function()
            local f = file.Open(LOG_FILE, "a")
            if f then f:Write(string.format("%.2f  %s\n", now(), s)); f:Close() end
        end)
    end
end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
local function has(b, flag) return bit.band(b, flag) ~= 0 end
local function median(t)
    local c = {}
    for i = 1, #t do c[i] = t[i] end
    table.sort(c)
    local n = #c
    if n == 0 then return 0 end
    return (n % 2 == 1) and c[(n + 1) / 2] or (c[n / 2] + c[n / 2 + 1]) / 2
end
local function convar(name, d)
    local v
    pcall(function() v = tonumber(client.GetConVar(name)) end)
    return v or d
end

local function local_player()
    local lp
    pcall(function() lp = entities.GetLocalPlayer() end)
    return lp
end
local function ent_by_userid(uid)
    local e
    pcall(function() e = entities.GetByIndex(client.GetPlayerIndexByUserID(uid)) end)
    if not e then pcall(function() e = entities.GetByUserID(uid) end) end
    return e
end
local function is_smoker(e)
    if not e then return false end
    local r = false
    pcall(function() if e:GetClass() == "Smoker" then r = true end end)
    if not r then pcall(function() if e:GetPropInt("m_zombieClass") == ZC_SMOKER then r = true end end) end
    return r
end
local function is_ghost(e)
    if not e then return false end
    local ok, b = pcall(function() return e:GetPropBool("m_isGhost") end)
    if ok and type(b) == "boolean" then return b end
    local ok2, v = pcall(function() return e:GetPropInt("m_isGhost") end)
    if ok2 and type(v) == "number" then return bit.band(v, 0xFF) == 1 end
    return false
end
local function describe(e)
    if not e then return "no entity" end
    local c, z, tm, idx = "?", "?", "?", "?"
    pcall(function() c = e:GetClass() end)
    pcall(function() z = e:GetPropInt("m_zombieClass") end)
    pcall(function() tm = e:GetTeamNumber() end)
    pcall(function() idx = e:GetIndex() end)
    return string.format("idx %s class %s zombieClass %s team %s", tostring(idx), tostring(c), tostring(z), tostring(tm))
end
local function alive(e)
    local a = false
    pcall(function() a = e ~= nil and e:IsAlive() end)
    return a
end
local function eye_of(e, is_local)
    local p
    if is_local then pcall(function() p = e:GetEyePosition() end) end
    if p then return p end
    local o
    pcall(function() o = e:GetAbsOrigin() end)
    if not o then return nil end
    local z = 64
    pcall(function()
        local off = e:GetPropVector("m_vecViewOffset[0]")
        if off and type(off.z) == "number" and off.z > 20 and off.z < 100 then z = off.z end
    end)
    return Vector3(o.x, o.y, o.z + z)
end
local function smoker_victim(sm)
    local v
    pcall(function() v = sm:GetPropInt("m_tongueVictim") end)
    if type(v) ~= "number" or v <= 0 then return nil end
    local i = v % 2048
    if i >= 1 and i <= 64 then return i end
end
local function teammates(lp)
    local out = {}
    pcall(function()
        local me = lp:GetIndex()
        for _, sv in pairs(entities.FindByClass("CTerrorPlayer")) do
            if sv:GetTeamNumber() == 2 and sv:GetIndex() ~= me and alive(sv) then
                out[#out + 1] = { idx = sv:GetIndex(), o = sv:GetAbsOrigin() }
            end
        end
    end)
    return out
end
local function ping_s()
    local ms = 0
    pcall(function()
        local res = entities.FindByClass("CTerrorPlayerResource")
        local lp = entities.GetLocalPlayer()
        if res and res[1] and lp then ms = res[1]:GetPropInt("m_iPing", lp:GetIndex()) or 0 end
    end)
    return clamp(ms / 1000, 0, 0.6)
end
local function weapon_class(lp)
    local c
    pcall(function()
        local w = lp:GetPropEntity("m_hActiveWeapon")
        if w then c = w:GetClass() end
    end)
    return c
end

local AIM_SRC = {
    { "m_angEyeAngles[0]", "m_angEyeAngles[1]", "float2" },
    { "m_eyeAngles[0]",    "m_eyeAngles[1]",    "float2" },
    { "m_angEyeAngles",    nil,                 "vec" },
    { "m_angRotation",     nil,                 "vec" },
}
local aim_idx = nil
local aim_name = "unknown (nearest-survivor rule)"
local function read_aim(smoker)
    local function try(i)
        local s = AIM_SRC[i]
        local p, y
        pcall(function()
            if s[3] == "float2" then
                p, y = smoker:GetPropFloat(s[1]), smoker:GetPropFloat(s[2])
            else
                local v = smoker:GetPropVector(s[1]); p, y = v.x, v.y
            end
        end)
        if type(p) == "number" and type(y) == "number" and math.abs(p) <= 90.5 and math.abs(y) <= 360.5 and not (p == 0 and y == 0) then
            return p, y
        end
    end
    if aim_idx then return try(aim_idx) end
    for i = 1, #AIM_SRC do
        local p, y = try(i)
        if p then aim_idx = i; aim_name = AIM_SRC[i][1]; return p, y end
    end
end
local function aim_error(s_eye, pitch, yaw, target)
    local p, y = math.rad(pitch), math.rad(yaw)
    local fx, fy, fz = math.cos(p) * math.cos(y), math.cos(p) * math.sin(y), -math.sin(p)
    local dx, dy, dz = target.x - s_eye.x, target.y - s_eye.y, target.z - s_eye.z
    local l = math.sqrt(dx * dx + dy * dy + dz * dz)
    if l < 1 then return 0 end
    return math.deg(math.acos(clamp((fx * dx + fy * dy + fz * dz) / l, -1, 1)))
end

local VIS_MASK = 0x46004003
local CHAR = { CTerrorPlayer = true, SurvivorBot = true, Infected = true, CInfected = true, Witch = true,
               Smoker = true, Hunter = true, Boomer = true, Spitter = true, Jockey = true, Charger = true,
               Tank = true, CTank = true }
local vis_cache, vis_last, vis_draw = {}, {}, nil
local function is_character(e)
    if not e then return false end
    local ok, r = pcall(function()
        local i = e:GetIndex()
        if i and i >= 1 and i <= 64 then return true end
        return CHAR[e:GetClass()] == true
    end)
    return ok and r
end
local function ray_reaches(a, b, own_idx, hull)
    local from = a
    for _ = 1, 3 do
        local ok, tr = pcall(function()
            if hull then return engine.TraceHull(from, b, Vector3(-3, -3, -3), Vector3(3, 3, 3), VIS_MASK) end
            return engine.TraceLine(from, b, VIS_MASK)
        end)
        if not ok or not tr or type(tr.fraction) ~= "number" then return nil end
        if tr.fraction >= 0.97 then return true end
        local ent = tr.entity
        local idx
        pcall(function() idx = ent and ent:GetIndex() end)
        if idx and own_idx and idx == own_idx then
            local e = tr.endpos
            if not e then return nil end
            local d = b - e
            local l = d:Length()
            if l < 8 then return true end
            from = Vector3(e.x + d.x / l * 6, e.y + d.y / l * 6, e.z + d.z / l * 6)
        elseif is_character(ent) then
            return true
        else
            return false
        end
    end
    return nil
end
local function clear_view(smoker, lp)
    if not m_vis:GetValue() then return true end
    local idx = smoker:GetIndex()
    local c = vis_cache[idx]
    if c and now() - c.t < 0.1 then return c.v end
    local s_eye = eye_of(smoker, false)
    local o = lp:GetAbsOrigin()
    local names = { "eye", "chest", "hips" }
    local pts = { eye_of(lp, true), o + Vector3(0, 0, 36), o + Vector3(0, 0, 14) }
    local verdict, det, seen_to = nil, {}, nil
    if s_eye then
        verdict = false
        for i, tgt in ipairs(pts) do
            if tgt then
                local r = ray_reaches(s_eye, tgt, idx, false)
                if r == false then r = ray_reaches(s_eye, tgt, idx, true) end
                if r == nil then verdict = nil; det[#det + 1] = names[i] .. "=?"; break end
                det[#det + 1] = names[i] .. (r and "=clear" or "=BLOCKED")
                if r then verdict = true; seen_to = tgt; break end
            end
        end
    end
    local v = (verdict ~= false)
    vis_cache[idx] = { t = now(), v = v }
    if vis_last[idx] ~= verdict then
        vis_last[idx] = verdict
        log(string.format("see-check smoker %d: %s (%s)", idx, verdict == nil and "UNREADABLE - not blocking" or (verdict and "CAN SEE YOU" or "BLOCKED"), table.concat(det, " ")))
    end
    if s_eye then vis_draw = { t = now(), a = s_eye, b = seen_to or pts[2], v = v } end
    return v
end

local tongue = nil
local fire_queue = {}
local poll_tongue_tips
local corr = {}
local last_owner = nil
local stats = { cuts = 0, dragged = 0, missed = 0, tongues = 0, ignored = 0, last = "-" }
local swapped = false
local back_at = nil
local last_swap = -99
local override_until = 0
local pre_since, pre_block = nil, 0
local post_release = false
local last_ignored = "-"
local last_how = "?"
local smoker_block = {}
local was_melee = false

local function correction() return median(corr) end

local pre_loose = false
local function tongue_on_me(smoker, lp, tip)
    if not alive(smoker) then last_ignored = "smoker dead"; return false end
    if is_ghost(smoker) then last_ignored = "smoker is a ghost (not spawned)"; return false end
    local held = smoker_victim(smoker)
    if held and held ~= lp:GetIndex() then last_ignored = string.format("its tongue is already on a teammate (#%d)", held); return false end
    local s_eye, my_eye = eye_of(smoker, false), eye_of(lp, true)
    if not s_eye then last_ignored = "can't read the smoker's position"; return false end
    if not my_eye then last_ignored = "can't read your eye position"; return false end
    local d = (my_eye - s_eye):Length()
    local range = convar("tongue_range", 750)
    if d > range + 50 then last_ignored = string.format("out of range (%.0fu)", d); return false end
    local tol = TOL_DEG + math.deg(math.atan(24 / math.max(24, d))) + (pre_loose and 12 or 0)
    local o = lp:GetAbsOrigin()
    local my_pts = { my_eye, o + Vector3(0, 0, 36), o + Vector3(0, 0, 20) }
    local function dir_err(dx, dy, dz, target)
        local tx, ty, tz = target.x - s_eye.x, target.y - s_eye.y, target.z - s_eye.z
        local l1 = math.sqrt(dx * dx + dy * dy + dz * dz)
        local l2 = math.sqrt(tx * tx + ty * ty + tz * tz)
        if l1 < 1 or l2 < 1 then return 0 end
        return math.deg(math.acos(clamp((dx * tx + dy * ty + dz * tz) / (l1 * l2), -1, 1)))
    end
    local err_fn, how
    if tip then
        local dx, dy, dz = tip.x - s_eye.x, tip.y - s_eye.y, tip.z - s_eye.z
        err_fn = function(target) return dir_err(dx, dy, dz, target) end
        how = "tongue tip"
    else
        local pitch, yaw = read_aim(smoker)
        if pitch then
            err_fn = function(target) return aim_error(s_eye, pitch, yaw, target) end
            how = "eye angles (" .. aim_name .. ")"
        end
    end
    if err_fn then
        local e = math.huge
        for _, p in ipairs(my_pts) do e = math.min(e, err_fn(p)) end
        if e > tol then last_ignored = string.format("aimed %.0f deg away from you [%s]", e, how); return false end
        local margin = math.max(1.0, math.deg(math.atan(14 / math.max(1, d))))
        local mate = nil
        for _, sv in ipairs(teammates(lp)) do
            local so = sv.o
            local ok, se = pcall(function() return math.min(err_fn(so + Vector3(0, 0, 60)), err_fn(so + Vector3(0, 0, 36)), err_fn(so + Vector3(0, 0, 20))) end)
            if ok and se and (so - s_eye):Length() <= range + 50 and se + margin < e then mate = sv.idx; break end
        end
        if mate then last_ignored = string.format("aimed at a teammate (#%d) [%s]", mate, how); return false end
        last_how = how
    else
        for _, sv in ipairs(teammates(lp)) do
            if (sv.o + Vector3(0, 0, 36) - s_eye):Length() < d + 60 then
                last_ignored = string.format("a teammate (#%d) is as close or closer (aim unknown)", sv.idx); return false
            end
        end
        last_how = "nearest survivor (aim unknown)"
    end
    do
        local c = o + Vector3(0, 0, 36)
        local ax, ay, az = c.x - s_eye.x, c.y - s_eye.y, c.z - s_eye.z
        local al = math.sqrt(ax * ax + ay * ay + az * az)
        if al > 1 then
            ax, ay, az = ax / al, ay / al, az / al
            for _, sv in ipairs(teammates(lp)) do
                local m = sv.o + Vector3(0, 0, 36)
                local rx, ry, rz = m.x - s_eye.x, m.y - s_eye.y, m.z - s_eye.z
                local along = rx * ax + ry * ay + rz * az
                if along > 0 and along < al - 40 then
                    local px, py, pz = rx - ax * along, ry - ay * along, rz - az * along
                    if math.sqrt(px * px + py * py + pz * pz) < 14 then
                        last_ignored = string.format("a teammate (#%d) is in the tongue's path before you", sv.idx); return false
                    end
                end
            end
        end
    end
    if not clear_view(smoker, lp) then last_ignored = "no clear line to you (wall between)"; return false end
    return true, d
end

local function smoker_in_sight(lp)
    local found = false
    pcall(function()
        local range = convar("tongue_range", 750) + 100
        local me = eye_of(lp, true)
        if not me then return end
        local mates = teammates(lp)
        for _, p in pairs(entities.FindByClass("CTerrorPlayer")) do
            if is_smoker(p) and alive(p) and not is_ghost(p) then
                local se = eye_of(p, false)
                local held = smoker_victim(p)
                if se and not (held and held ~= lp:GetIndex()) then
                    local dme = (me - se):Length()
                    local mine = true
                    for _, sv in ipairs(mates) do
                        if (sv.o + Vector3(0, 0, 60) - se):Length() + 30 < dme then mine = false; break end
                    end
                    if mine and dme <= range and clear_view(p, lp) then found = true end
                end
            end
        end
    end)
    return found
end
local pre_diag_t = 0
local function smoker_aiming(lp)
    local found, seen = false, 0
    local why = {}
    pcall(function()
        for _, p in pairs(entities.FindByClass("CTerrorPlayer")) do
            if is_smoker(p) and alive(p) and not is_ghost(p) then
                seen = seen + 1
                local keep = last_ignored
                pre_loose = true
                local ok = tongue_on_me(p, lp)
                pre_loose = false
                if ok then found = true else why[#why + 1] = p:GetIndex() .. ": " .. tostring(last_ignored) end
                last_ignored = keep
            end
        end
    end)
    pre_loose = false
    if seen > 0 and not found and now() - pre_diag_t > 1.5 then
        pre_diag_t = now()
        log("pre-swap: smoker seen but not aiming at you - " .. table.concat(why, " | "))
    end
    return found
end

local swap_tries = 0
local sight_last = nil
local pre_mute = false
local nosight_since = nil
local sel = { idx = nil, untl = 0 }
local prev_weapon = nil
local slots_logged = false
local SWAP_CMDS = { "use weapon_melee", "slot2", "use weapon_melee" }
local function find_melee(lp)
    local found, list = nil, {}
    for slot = 0, 7 do
        pcall(function()
            local w = lp:GetPropEntity("m_hMyWeapons", slot)
            if w then
                local c = w:GetClass()
                list[#list + 1] = slot .. "=" .. tostring(c)
                if MELEE[c] and not found then found = w:GetIndex() end
            end
        end)
    end
    if not slots_logged then slots_logged = true; log("your weapon slots: " .. table.concat(list, " ") .. (found and ("  -> melee entity " .. found) or "  -> NO melee found")) end
    return found
end
local function active_index(lp)
    local i
    pcall(function() local w = lp:GetPropEntity("m_hActiveWeapon"); if w then i = w:GetIndex() end end)
    return i
end
local function swap_to_melee(t, lp)
    if t - last_swap < 0.3 then return end
    last_swap = t
    swap_tries = swap_tries + 1
    if lp then
        if not swapped then prev_weapon = active_index(lp) end
        local m = find_melee(lp)
        if m then sel.idx = m; sel.untl = t + 0.6 end
    end
    if swap_tries <= #SWAP_CMDS then
        local c = SWAP_CMDS[swap_tries]
        pcall(function() client.Command(c, true) end)
        log("swap to melee sent: " .. c .. " + usercmd select " .. tostring(sel.idx) .. " (try " .. swap_tries .. ")")
    end
    swapped = true
end
local function swap_back(t, lp)
    last_swap = t
    if prev_weapon and prev_weapon ~= active_index(lp or local_player()) then
        sel.idx = prev_weapon; sel.untl = t + 0.6
    else
        pcall(function() client.Command("lastinv", true) end)
    end
end
local function apply_select(cmd)
    if sel.idx and now() < sel.untl then
        pcall(function() cmd.weaponselect = sel.idx end)
        pcall(function() cmd:SetWeaponSelect(sel.idx) end)
    end
end

local function do_cut(cmd, lp, smoker)
    if m_pitch:GetValue() then
        pcall(function()
            local old = cmd:GetViewAngles()
            local p, y
            if smoker and alive(smoker) then
                local me, so = eye_of(lp, true), smoker:GetAbsOrigin()
                local dx, dy, dz = so.x - me.x, so.y - me.y, so.z - me.z
                p = math.deg(math.atan2(-dz, math.sqrt(dx * dx + dy * dy))) + TILT_DEG
                y = math.deg(math.atan2(dy, dx))
            else
                p, y = old.x + TILT_DEG, old.y
            end
            p = clamp(p, -89, 89)
            local ang = EulerAngles(p, y, 0)
            cmd:SetViewAngles(ang)
            if m_visible:GetValue() then engine.SetViewAngles(ang) end
            local fm, sm = cmd:GetForwardMove(), cmd:GetSideMove()
            local d = math.rad(y - old.y)
            local c, s = math.cos(d), math.sin(d)
            cmd:SetForwardMove(fm * c - sm * s)
            cmd:SetSideMove(fm * s + sm * c)
        end)
    end
    pcall(function() cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK)) end)
end

local function finish(result, t, back_delay)
    if not tongue then return end
    if result == "cut" then stats.cuts = stats.cuts + 1
    elseif result == "dragged" then stats.dragged = stats.dragged + 1
    elseif result == "missed you" then stats.missed = stats.missed + 1 end
    stats.last = string.upper(result)
    local tg = tongue
    log(string.format("tongue %-10s dist %s  predicted grab %s  actual grab %s  swings %d  corr %+.0fms",
        string.upper(result), tg.dist and string.format("%.0fu", tg.dist) or "?",
        tg.pred and string.format("%+.0fms", (tg.pred - (tg.fire_t or t)) * 1000) or "-",
        tg.grab_t and string.format("%+.0fms", (tg.grab_t - (tg.fire_t or t)) * 1000) or "not seen",
        tg.swings or 0, correction() * 1000))
    tongue = nil
    pre_block = math.max(pre_block, t + 1.5)
    pre_mute = true
    if swapped then back_at = t + (back_delay or 0.5); post_release = true end
end

local tip_seen = {}
local tip_prev = {}
local tip_diag = 0
function poll_tongue_tips(lp, t)
    local list
    pcall(function() list = entities.FindByClass("CTongue") end)
    if not list then return end
    for _, te in pairs(list) do
        local tip
        pcall(function() tip = te:GetPropVector("m_tipPosition") end)
        if tip and type(tip.x) == "number" and (tip.x ~= 0 or tip.y ~= 0 or tip.z ~= 0) then
            local sm
            pcall(function()
                local h = te:GetPropInt("m_hOwnerEntity")
                if h and h > 0 then
                    local e = entities.GetByIndex(h % 2048)
                    if is_smoker(e) then sm = e end
                end
            end)
            if not sm then
                local bd
                pcall(function()
                    for _, p in pairs(entities.FindByClass("CTerrorPlayer")) do
                        if p:GetTeamNumber() == 3 and is_smoker(p) and alive(p) and not is_ghost(p) then
                            local dd = (p:GetAbsOrigin() - tip):Length()
                            if not bd or dd < bd then bd, sm = dd, p end
                        end
                    end
                end)
            end
            if sm then
                local s_eye = eye_of(sm, false)
                local traveled = s_eye and (tip - s_eye):Length() or 0
                local idx = sm:GetIndex()
                local prev = tip_prev[idx]
                tip_prev[idx] = traveled
                if prev and traveled > prev + 5 and traveled > 40 and traveled < convar("tongue_range", 750) + 100
                   and (not tip_seen[idx] or t - tip_seen[idx] > 1.5) then
                    tip_seen[idx] = t
                    fire_queue[#fire_queue + 1] = { t = t - traveled / convar("tongue_fly_speed", 1000),
                                                    ent = sm, tip = tip, src = "tongue tip" }
                end
            end
        end
    end
end

for _, e in ipairs({ "ability_use", "tongue_grab", "tongue_release", "tongue_pull_stopped", "round_start", "player_death" }) do
    pcall(client.AllowListener, e)
end

callbacks.Register("FireGameEvent", "autocut_events", function(ev)
    local name = ev:GetName()
    local lp = local_player()
    if name == "ability_use" then
        if ev:GetString("ability") == "ability_tongue" then
            fire_queue[#fire_queue + 1] = { t = now(), uid = ev:GetInt("userid"), src = "event" }
        end
    elseif name == "tongue_grab" then
        local vic = ent_by_userid(ev:GetInt("victim"))
        if lp and vic and vic:GetIndex() ~= lp:GetIndex() and tongue and not tongue.grab_t then
            local sm = ent_by_userid(ev:GetInt("userid"))
            if sm and sm:GetIndex() == tongue.smoker then
                tongue.mate_grab = vic:GetIndex()
            end
        end
        if lp and vic and vic:GetIndex() == lp:GetIndex() then
            local sm = ent_by_userid(ev:GetInt("userid"))
            local t = now()
            if tongue and sm and tongue.smoker == sm:GetIndex() and tongue.fire_t and not tongue.grab_t then
                local c = t - (tongue.fire_t + (tongue.dist or 0) / convar("tongue_fly_speed", 1000))
                if c > -0.4 and c < 0.6 then corr[#corr + 1] = c; if #corr > 9 then table.remove(corr, 1) end end
            elseif not tongue and sm then
                tongue = { smoker = sm:GetIndex(), note = "(fire not seen)", pressed = 0 }
            end
            if tongue then tongue.grab_t = t end
        end
    elseif name == "tongue_release" or name == "tongue_pull_stopped" then
        if lp and tongue and tongue.grab_t then
            local v = ent_by_userid(ev:GetInt("victim"))
            if v and v:GetIndex() == lp:GetIndex() then
                local t = now()
                finish(t - tongue.grab_t < 1.5 and "cut" or "released", t)
            end
        end
    elseif name == "round_start" then
        tongue = nil; fire_queue = {}; swapped = false; back_at = nil; vis_cache = {}
    end
end)

callbacks.Register("CreateMove", "autocut_tick", function(cmd)
    local lp = local_player()
    if not m_on:GetValue() or not lp or not alive(lp) or lp:GetTeamNumber() ~= 2 then tongue = nil; fire_queue = {}; return end
    local t = now()
    apply_select(cmd)
    local cls = weapon_class(lp)
    local is_melee = cls ~= nil and MELEE[cls] == true
    local known = cls ~= nil
    if known then
        if swapped and was_melee and not is_melee and t - (tongue and tongue.melee_since or t - 1) > 0.15 then
            override_until = t + 4.0
            pre_mute = true; sel.idx = nil
            if tongue then tongue.override = true; log("TAKEOVER: you pulled your gun - AutoCut stands down") end
            swapped = false; back_at = nil
        end
        if is_melee and not was_melee and tongue then tongue.melee_since = t end
        was_melee = is_melee
        if is_melee then swap_tries = 0 end
    end

    if not tongue then poll_tongue_tips(lp, t) end

    if #fire_queue > 0 then
        local q = fire_queue; fire_queue = {}
        if not (tongue and tongue.grab_t) then
            local best, best_d, best_t, best_src
            for _, f in ipairs(q) do
                local sm = f.ent or ent_by_userid(f.uid)
                if not sm then
                    last_ignored = "event named a player I can't find (userid " .. tostring(f.uid) .. ")"
                elseif not is_smoker(sm) then
                    last_ignored = "not a smoker: " .. describe(sm)
                elseif (smoker_block[sm:GetIndex()] or 0) > t then
                    last_ignored = "that smoker's last tongue missed you (backoff)"
                else
                    vis_cache = {}
                    local on, d = tongue_on_me(sm, lp, f.tip)
                    if on and (not best_d or d < best_d) then best, best_d, best_t, best_src = sm, d, f.t, f.src end
                end
            end
            if best then
                local speed = convar("tongue_fly_speed", 1000)
                local rtt = ping_s()
                local lead = LEAD_MS / 1000
                local off = OFFSET_MS / 1000
                local land_seen = best_t + best_d / speed + correction()
                local pred = land_seen - rtt + off
                local ov = t < override_until
                tongue = { smoker = best:GetIndex(), fire_t = best_t, dist = best_d, pred = pred,
                           win_s = pred - lead, win_e = pred + 2 * TICK, override = ov, pressed = 0, swings = 0 }
                stats.tongues = stats.tongues + 1
                stats.last = "tongue coming"
                log(string.format("tongue from %d: AT ME  dist %.0fu  lands in %.2fs  (ping %.0fms, corr %+.0fms)  seen via %s, aim by %s%s",
                    tongue.smoker, best_d, pred - t, rtt * 1000, correction() * 1000, best_src or "event", last_how, ov and "  [you have the gun: standing down]" or ""))
            else
                stats.ignored = stats.ignored + 1
                log("tongue ignored - " .. last_ignored)
            end
        end
    end

    local owner
    pcall(function() owner = lp:GetPropInt("m_tongueOwner") % 2048 end)
    if owner and owner > 0 and owner ~= last_owner then
        if not tongue then tongue = { smoker = owner, note = "(fire not seen)", pressed = 0, swings = 0 } end
        tongue.grab_t = tongue.grab_t or t
    end
    if (not owner or owner == 0) and last_owner and last_owner > 0 and tongue and tongue.grab_t then
        finish(t - tongue.grab_t < 1.5 and "cut" or "released", t)
    end
    last_owner = owner

    if not tongue then
        local insight = false
        if m_sight:GetValue() or m_pre:GetValue() then insight = smoker_in_sight(lp) end
        if insight then nosight_since = nil else nosight_since = nosight_since or t end
        if pre_mute and nosight_since and t - nosight_since > 2.0 then pre_mute = false end
        local ok_state = m_switch:GetValue() and t >= override_until and t >= pre_block
        local aiming = ok_state and ((m_pre:GetValue() and smoker_aiming(lp)) or (m_sight:GetValue() and not pre_mute and insight))
        if aiming then pre_since = pre_since or t else pre_since = nil end
        if is_melee or not aiming then swap_tries = 0 end
        if aiming then
            sight_last = t
            if t - pre_since >= 0.1 then
                if not known then if t - pre_diag_t > 1.5 then pre_diag_t = t; log("pre-swap: can't read your weapon class") end end
                if known and not is_melee then swap_to_melee(t, lp) end
                back_at = nil
            end
        elseif swapped and sight_last and t - sight_last > 1.5 and not back_at then
            back_at = t
        end
        if post_release then
            if not is_melee then post_release = false
            else
                local b = 0
                pcall(function() b = cmd:GetButtons() end)
                if has(b, IN_ATTACK) then pcall(function() cmd:SetButtons(bit.band(b, bit.bnot(IN_ATTACK))) end)
                else post_release = false end
            end
        end
        if back_at and t >= back_at then
            back_at = nil
            if swapped and m_back:GetValue() and is_melee then swap_back(t, lp) end
            swapped = false
        end
        return
    end
    back_at = nil

    if tongue.grab_t and t - tongue.grab_t > 2.0 then finish("dragged", t); return end
    if not tongue.grab_t and tongue.win_e and t > tongue.win_e + 0.5 then finish("missed you", t); return end
    if tongue.override then stats.last = "hands off - you have the gun"; return end
    local smoker = nil
    pcall(function() smoker = entities.GetByIndex(tongue.smoker) end)
    if not tongue.grab_t and smoker and not alive(smoker) then log("smoker died before the grab - cancelled"); finish("smoker died", t, 0.1); return end
    if not tongue.grab_t then
        local mate = tongue.mate_grab
        if not mate and smoker then
            local held = smoker_victim(smoker)
            if held and held ~= lp:GetIndex() then mate = held end
        end
        if mate then
            log(string.format("tongue grabbed a teammate (#%d) - cancelled, no swing", mate))
            finish("teammate", t, 0.3); return
        end
    end
    if m_vis:GetValue() and not tongue.grab_t and smoker then
        if not clear_view(smoker, lp) then
            tongue.lost = (tongue.lost or 0) + 1
            if tongue.lost >= 3 then log("lost the line to the smoker - cancelled, no swing"); finish("lost sight", t, 1.0); return end
        else tongue.lost = 0 end
    end

    if known and not is_melee then
        local deploy = DEPLOY_MS / 1000
        if m_switch:GetValue() and not swapped and tongue.pred and not tongue.grab_t and t + deploy > tongue.pred + 0.04 then
            if not tongue.skipped then
                tongue.skipped = true
                log(string.format("swap skipped: melee needs %.2fs, tongue lands in %.2fs - gun stays out", deploy, tongue.pred - t))
            end
            stats.last = "too close for the melee - shoot it"
            return
        end
        if m_switch:GetValue() and tongue.fire_t and not tongue.grab_t then swap_to_melee(t, lp) end
        if m_melee:GetValue() then stats.last = "gun out - can't cut"; return end
    end

    if tongue.win_s and t >= tongue.win_s and t <= tongue.win_e then
        do_cut(cmd, lp, smoker)
        tongue.swings = (tongue.swings or 0) + 1
        stats.last = "swinging"
    elseif tongue.win_s and not tongue.grab_t and t < tongue.win_s then
        if is_melee then
            pcall(function()
                local b = cmd:GetButtons()
                if has(b, IN_ATTACK) then cmd:SetButtons(bit.band(b, bit.bnot(IN_ATTACK))) end
            end)
        end
        stats.last = string.format("swing in %.2fs", tongue.win_s - t)
    end
end)

local font = draw.CreateFont("Tahoma", 13, 600)
callbacks.Register("Draw", "autocut_status", function()
    if m_visline:GetValue() and vis_draw and now() - vis_draw.t < 0.6 then
        pcall(function()
            local x1, y1 = client.WorldToScreen(vis_draw.a)
            local x2, y2 = client.WorldToScreen(vis_draw.b)
            if x1 and x2 then
                if vis_draw.v then draw.Color(60, 255, 60, 230) else draw.Color(255, 60, 60, 230) end
                draw.Line(x1, y1, x2, y2)
            end
        end)
    end
    if not m_status:GetValue() then return end
    draw.SetFont(font)
    draw.Color(255, 255, 255, 230)
    local y = 200
    local lines = {
        string.format("AutoCut: %s", stats.last),
        string.format("cuts %d  dragged %d  missed %d  ignored %d", stats.cuts, stats.dragged, stats.missed, stats.ignored),
        string.format("timing correction %+.0f ms (%d grabs learned)   ping %.0f ms", correction() * 1000, #corr, ping_s() * 1000),
        "smoker aim from: " .. aim_name,
    }
    for _, l in ipairs(lines) do draw.Text(20, y, l); y = y + 15 end
end)

callbacks.Register("Unload", function()
    tongue = nil; fire_queue = {}
    pcall(function() tab:Remove() end)
end)

print("[AutoCut] loaded")
