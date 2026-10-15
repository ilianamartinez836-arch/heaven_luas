local client_base = modules.get_client_base()

local _shootPosFn = ffi.cast("void(__thiscall*)(void*, float[3])", client_base + 108512)
local _shootBuf   = ffi.new("float[3]")
local function getShootPosition(rawPlayer)
    local ok, err = pcall(_shootPosFn, ffi.cast("void*", rawPlayer), _shootBuf)
    if not ok then
        client.print("[FBAim] getShootPosition crash: " .. tostring(err))
        return nil
    end
    return vector.new(_shootBuf[0], _shootBuf[1], _shootBuf[2])
end

if _G.__fb_aim_guard then
    client.print("[FBAim] Already loaded — duplicate blocked")
    return
end
_G.__fb_aim_guard = true

local CID = {
    CTerrorPlayer = 232,
    SurvivorBot   = 275,
    Smoker        = 270,
    Boomer        = 0,
    Hunter        = 263,
    Spitter       = 272,
    Jockey        = 265,
    Charger       = 99,
    Tank          = 276,
    Witch         = 277,
}

local CLASS_PRIORITY = {
    [CID.CTerrorPlayer] = 3,
    [CID.SurvivorBot]   = 3,
    [CID.Smoker]        = 2,
    [CID.Boomer]        = 2,
    [CID.Hunter]        = 2,
    [CID.Spitter]       = 2,
    [CID.Jockey]        = 2,
    [CID.Charger]       = 2,
    [CID.Tank]          = 2,
    [CID.Witch]         = 2,
}

local DEFAULTS = {
    { "fbaim_enabled",   "bool",  true  },
    { "fbaim_survivors", "bool",  true   },
    { "fbaim_smoker",    "bool",  true   },
    { "fbaim_boomer",    "bool",  true   },
    { "fbaim_hunter",    "bool",  true   },
    { "fbaim_spitter",   "bool",  true   },
    { "fbaim_jockey",    "bool",  true   },
    { "fbaim_charger",   "bool",  true   },
    { "fbaim_tank",      "bool",  true   },
    { "fbaim_witch",     "bool",  true   },
    { "fbaim_fov",       "float", 180.0  },
    { "fbaim_max_dist",  "float", 8192.0 },
    { "fbaim_aimkey",    "int",   0      }, -- 5 = MOUSE5; 0 = always-on
}

for _, d in ipairs(DEFAULTS) do
    local key, typ, val = d[1], d[2], d[3]
    client["set_shared_" .. typ](key, val)
end

local function cfg(key, typ)      return client["get_shared_" .. typ](key) end
local function setcfg(key, typ, v) client["set_shared_" .. typ](key, v)   end

local function normAngle(a)
    a = a % 360
    if a >  180 then a = a - 360 end
    if a < -180 then a = a + 360 end
    return a
end

local function calcAngle(src, dst)
    local dx = dst.x - src.x
    local dy = dst.y - src.y
    local dz = dst.z - src.z
    local hyp = math.sqrt(dx * dx + dy * dy)
    return vector.new(
        math.deg(math.atan2(-dz, hyp)),
        math.deg(math.atan2(dy, dx)),
        0
    )
end

local function getFov(va, aa)
    local dp = normAngle(aa.x - va.x)
    local dy = normAngle(aa.y - va.y)
    return math.sqrt(dp * dp + dy * dy)
end

local function isClassEnabled(cid)
    if cid == CID.CTerrorPlayer or
       cid == CID.SurvivorBot    then return cfg("fbaim_survivors", "bool") end
    if cid == CID.Smoker         then return cfg("fbaim_smoker",    "bool") end
    if cid == CID.Boomer         then return cfg("fbaim_boomer",    "bool") end
    if cid == CID.Hunter         then return cfg("fbaim_hunter",    "bool") end
    if cid == CID.Spitter        then return cfg("fbaim_spitter",   "bool") end
    if cid == CID.Jockey         then return cfg("fbaim_jockey",    "bool") end
    if cid == CID.Charger        then return cfg("fbaim_charger",   "bool") end
    if cid == CID.Tank           then return cfg("fbaim_tank",      "bool") end
    if cid == CID.Witch          then return cfg("fbaim_witch",     "bool") end
    return false
end
local function isVisible(eyePos, targetPos, entIdx, localIdx)
    local dx = targetPos.x - eyePos.x
    local dy = targetPos.y - eyePos.y
    local dz = targetPos.z - eyePos.z
    local len = math.sqrt(dx*dx + dy*dy + dz*dz)
    if len < 0.001 then return false end
    local inv = 1.0 / len

    local start_t = { x = eyePos.x,                  y = eyePos.y,                  z = eyePos.z }
    local end_t   = { x = targetPos.x + dx*inv*100,  y = targetPos.y + dy*inv*100,  z = targetPos.z + dz*inv*100 }

        local tr
        local ok, pcall_err = pcall(function()
            tr = trace.line(start_t, end_t)
        end)
        if not ok then
            client.print("[FBAim] trace.line CRASHED: " .. tostring(pcall_err))
            return false
        end

    -- Print EVERYTHING the trace returns so we know what to compare against
    client.print(string.format(
        "[FBAim] trace: fraction=%.3f did_hit=%s entity=%s entity_index=%s  looking_for_idx=%d",
        tr.fraction,
        tostring(tr.did_hit),
        tostring(tr.entity),
        tostring(tr.entity_index),
        entIdx
    ))

    if tr.entity_index and tr.entity_index == entIdx then
        client.print("[FBAim] VISIBLE via entity_index")
        return true
    end
    if tr.fraction > 0.97 then
        client.print("[FBAim] VISIBLE via fraction")
        return true
    end

    local targetRaw = entity.get_by_index_raw(entIdx)
    if tr.entity and targetRaw and tr.entity == targetRaw then
        client.print("[FBAim] VISIBLE via raw ptr match")
        return true
    end

    local tr2
    local ok2 = pcall(function() tr2 = trace.clip_ray_to_entity(start_t, end_t, entIdx) end)
    if ok2 and tr2 then
        client.print(string.format("[FBAim] clip_ray: fraction=%.3f did_hit=%s", tr2.fraction, tostring(tr2.did_hit)))
        if tr2.did_hit then return true end
    end

    return false
end
local function getBestVisibleHitbox(eyePos, ent, entIdx, localIdx, cid)
    local origin = ent:get_origin()

    local centerZ
    if     cid == CID.Tank                          then centerZ = origin.z + 45
    elseif cid == CID.Witch                         then centerZ = origin.z + 40
    elseif cid == CID.Hunter or cid == CID.Jockey  then centerZ = origin.z + 35
    else                                                 centerZ = origin.z + 45
    end

    --Wrong btw, u need to use the Hitbox index and bla bla bla

    local tryCenters = {
        { x = origin.x, y = origin.y, z = origin.z + 68 },
        { x = origin.x, y = origin.y, z = origin.z + 52 },
        { x = origin.x, y = origin.y, z = centerZ       },
        { x = origin.x, y = origin.y, z = origin.z + 20 },
    }

    local start_t = { x = eyePos.x, y = eyePos.y, z = eyePos.z }

    for _, aim in ipairs(tryCenters) do
        local tr
        local ok = pcall(function()
            tr = trace.clip_ray_to_entity(start_t, aim, entIdx)
        end)
        if ok and tr and tr.did_hit then
            return { x = tr.endpos.x, y = tr.endpos.y, z = tr.endpos.z }
        end

        local tr2
        local ok2 = pcall(function()
            tr2 = trace.line(start_t, aim)
        end)
        if ok2 and tr2 and tr2.fraction > 0.97 then
            return aim
        end
    end

    return nil
end
local g_sorted      = {}
local _debugTrace = (#g_sorted == 0)
local g_best_target = nil
local g_last_debug  = 0  -- throttle prints
local function buildSortedTargets(local_player)
    for i = #g_sorted, 1, -1 do g_sorted[i] = nil end
    g_best_target = nil

    local localIdx = local_player:get_index()
    local localRaw = entity.get_by_index_raw(localIdx)

    local eyePos
    if localRaw and localRaw ~= 0 then
        eyePos = getShootPosition(localRaw)
    end
    if not eyePos then
        local o = local_player:get_origin()
        eyePos = vector.new(o.x, o.y, o.z + 64)
    end

    local start_eye = { x = eyePos.x, y = eyePos.y, z = eyePos.z }
    local viewAngles = local_player:get_eye_angles()
    local maxDist    = cfg("fbaim_max_dist", "float")
    local fovLimit   = cfg("fbaim_fov",      "float")
    local maxEnts    = engine.get_max_clients()

    for i = 1, maxEnts do
        if i == localIdx then goto continue end

        local raw = entity.get_by_index_raw(i)
        if not raw or raw == 0 then goto continue end

        local cid = entity.get_class_id_from_ptr(raw)
        if not cid                 then goto continue end
        if not CLASS_PRIORITY[cid] then goto continue end
        if not isClassEnabled(cid) then goto continue end
        if entity.is_dormant(raw)  then goto continue end

        local ent = entity.get_by_index(i)
        if not ent or not ent:is_alive() then goto continue end

        local origin = ent:get_origin()
        local dist   = vector.distance(eyePos, origin)
        if dist > maxDist then goto continue end

        local aimPos
        pcall(function()
            aimPos = getBestVisibleHitbox(eyePos, ent, i, localIdx, cid)
        end)
        if not aimPos then goto continue end

        local aimAng = calcAngle(eyePos, aimPos)
        local fov    = getFov(viewAngles, aimAng)
        if fov > fovLimit then goto continue end

        table.insert(g_sorted, {
            cid      = cid,
            priority = CLASS_PRIORITY[cid],
            dist     = dist,
            aimPos   = aimPos,
            aimAngle = aimAng,
        })

        ::continue::
    end

    table.sort(g_sorted, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.dist < b.dist
    end)

    if #g_sorted > 0 then
        g_best_target = g_sorted[1]
    end
end
local client_base           = modules.get_client_base()
local FIREBULLETS_OFFSET    = 0x30C4C0
local hook_slot             = nil
local original_fire_bullets = nil

local function on_fire_bullets(this_ptr, a2)
    -- Always print so we know the hook fires regardless of target state
    --leave only if u want to debug adn etce tcetec
    client.print(string.format("[FBAim] on_fire_bullets called — enabled=%s  has_target=%s",
        tostring(cfg("fbaim_enabled", "bool")),
        tostring(g_best_target ~= nil)
    ))

    if cfg("fbaim_enabled", "bool") and g_best_target then
        local ang = g_best_target.aimAngle
        client.print(string.format("[FBAim] SNAPPING to pitch=%.2f yaw=%.2f", ang.x, ang.y))
        engine.set_view_angles(vector.new(
            normAngle(ang.x),
            normAngle(ang.y),
            0
        ))
    end
    return hooks.call_fn(original_fire_bullets, "thiscall", this_ptr, a2)
end
local ok, err = pcall(function()
    original_fire_bullets, hook_slot = hooks.create(
        client_base + FIREBULLETS_OFFSET,
        "void(__thiscall*)(void*, int)",
        on_fire_bullets
    )
end)

if ok and hook_slot then
    hooks.enable_slot(hook_slot)
    client.print("[FBAim] Hook installed at 0x" ..
        string.format("%08X", client_base + FIREBULLETS_OFFSET))
else
    client.print("[FBAim] Hook FAILED: " .. tostring(err))
end
function on_create_move(cmd, local_player)
    if not cfg("fbaim_enabled", "bool") then return end
    if not local_player or not local_player:is_alive() then return end
    if not engine.is_in_game() then return end

    local aimkey = cfg("fbaim_aimkey", "int")
    if aimkey ~= 0 and not input.is_key_down(aimkey) then
        g_best_target = nil
        return
    end

        buildSortedTargets(local_player)
    -- g_best_target stays from last build between rebuilds
end
function on_end_scene()
    if not menu.is_open() then return end
    if not imgui.begin("FB Aimbot", 0) then
        imgui["end"]()
        return
    end

    local ch, v

    ch, v = imgui.checkbox("Enable", cfg("fbaim_enabled", "bool"))
    if ch then setcfg("fbaim_enabled", "bool", v) end

    imgui.separator()

    imgui.text("Targets")

    ch, v = imgui.checkbox("Survivors / Bots", cfg("fbaim_survivors", "bool"))
    if ch then setcfg("fbaim_survivors", "bool", v) end

    imgui.separator()
    imgui.text("Special Infected")

    local SI = {
        { "Smoker",  "fbaim_smoker"  },
        { "Boomer",  "fbaim_boomer"  },
        { "Hunter",  "fbaim_hunter"  },
        { "Spitter", "fbaim_spitter" },
        { "Jockey",  "fbaim_jockey"  },
        { "Charger", "fbaim_charger" },
        { "Tank",    "fbaim_tank"    },
        { "Witch",   "fbaim_witch"   },
    }
    for _, e in ipairs(SI) do
        ch, v = imgui.checkbox(e[1], cfg(e[2], "bool"))
        if ch then setcfg(e[2], "bool", v) end
    end

    imgui.separator()

    ch, v = imgui.slider_float("FOV", cfg("fbaim_fov", "float"), 1.0, 180.0)
    if ch then setcfg("fbaim_fov", "float", v) end

    ch, v = imgui.slider_float("Max Distance", cfg("fbaim_max_dist", "float"), 200.0, 8192.0)
    if ch then setcfg("fbaim_max_dist", "float", v) end

    imgui["end"]()
end

function on_unload()
    if hook_slot then
        pcall(function() hooks.remove_slot(hook_slot) end)
    end
    _G.__fb_aim_guard = nil
    g_best_target = nil
    client.print("[FBAim] Unloaded")
end