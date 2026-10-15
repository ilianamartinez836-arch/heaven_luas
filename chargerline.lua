local TEAM_INFECTED, ZC_CHARGER = 3, 6

local function opt(k, d) return client.get_shared_bool(k, d) end
local function num(k, d)
    local v = client.get_shared_int(k, d)
    return (type(v) == "number") and v or d
end

_G.hh_dispatch = _G.hh_dispatch or { cm = {}, cm_predict = {}, paint = {}, unload = {}, event = {} }
local function run_bucket(name, ...)
    local bucket = _G.hh_dispatch[name]
    if not bucket then return end
    local order = {}
    for _, slot in pairs(bucket) do order[#order + 1] = slot end
    table.sort(order, function(a, b) return a.priority < b.priority end)
    for _, slot in ipairs(order) do pcall(slot.fn, ...) end
end
if not _G.hh_dispatch_installed then
    _G.hh_dispatch_installed = true
    function on_create_move(cmd, lp)            run_bucket("cm", cmd, lp) end
    function on_create_move_prediction(cmd, lp) run_bucket("cm_predict", cmd, lp) end
    function on_paint()                         run_bucket("paint") end
    function on_unload()                        run_bucket("unload") end
    function on_game_event(name, ev)            run_bucket("event", name, ev) end
end

local function w2s_frame()
    if not engine.world_to_screen_matrix then return nil end
    local mat = engine.world_to_screen_matrix()
    if not mat or mat == 0 then return nil end
    local function rm(i) return memory.read_float(mat + i * 4) end
    local sw, sh = engine.get_screen_size()
    if not sw or sw <= 0 then return nil end
    return { m00 = rm(0), m01 = rm(1), m02 = rm(2), m03 = rm(3),
             m10 = rm(4), m11 = rm(5), m12 = rm(6), m13 = rm(7),
             m30 = rm(12), m31 = rm(13), m32 = rm(14), m33 = rm(15), sw = sw, sh = sh }
end
local function project(f, x, y, z)
    local w = f.m30 * x + f.m31 * y + f.m32 * z + f.m33
    if w < 0.001 then return nil end
    local inv = 1.0 / w
    return f.sw / 2 + (f.m00 * x + f.m01 * y + f.m02 * z + f.m03) * inv * f.sw / 2,
           f.sh / 2 - (f.m10 * x + f.m11 * y + f.m12 * z + f.m13) * inv * f.sh / 2
end

local function world_line(f, x1, y1, z, x2, y2, r, g, b, a)
    local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    local n = math.max(1, math.ceil(len / 40))
    local px, py = project(f, x1, y1, z)
    for i = 1, n do
        local t = i / n
        local qx, qy = project(f, x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, z)
        if px and qx then
            pcall(draw.line, math.floor(px), math.floor(py), math.floor(qx), math.floor(qy), r, g, b, a)
        end
        px, py = qx, qy
    end
end

local info = { found = 0, in_lane = false }

_G.hh_dispatch.paint["chargerline"] = { priority = 25, fn = function()
    info.found = 0
    if not opt("cl_on", false) then return end
    local in_game, lp = false, nil
    pcall(function() in_game = engine.is_in_game(); lp = client.get_local_player() end)
    if not in_game or not lp then return end
    local alive = false
    pcall(function() alive = lp:is_alive() end)
    if not alive then return end
    local f = w2s_frame()
    if not f then return end

    local me
    pcall(function() me = lp:get_origin() end)
    if not me then return end

    local reach = num("cl_len", 900)
    local half = num("cl_width", 20)
    local maxc = 32
    pcall(function() local m = engine.get_max_clients(); if type(m) == "number" and m > 0 and m < 64 then maxc = m end end)

    local danger_any, danger_who = false, nil
    for i = 1, maxc do
        local ok, e = pcall(entity.get_by_index, i)
        if ok and e then
            local d = nil
            pcall(function()
                if not (e:is_alive() and e:get_team() == TEAM_INFECTED and not e:is_ghost()
                        and e:get_zombie_class() == ZC_CHARGER) then return end
                local o, v = e:get_origin(), e:get_velocity()
                if not o then return end
                local dx, dy, charging = nil, nil, false
                if v and v.x then
                    local sp = math.sqrt(v.x * v.x + v.y * v.y)
                    if sp >= 250 then dx, dy, charging = v.x / sp, v.y / sp, true end
                end
                if not dx then
                    local ang = e:get_eye_angles()
                    if ang and type(ang.y) == "number" then
                        local yaw = math.rad(ang.y)
                        dx, dy = math.cos(yaw), math.sin(yaw)
                    end
                end
                if not dx then return end
                d = { o = o, dx = dx, dy = dy, charging = charging, i = i }
            end)
            if d then
                info.found = info.found + 1
                local o = d.o

                local rx, ry = me.x - o.x, me.y - o.y
                local along = rx * d.dx + ry * d.dy
                local lat = math.abs(rx * d.dy - ry * d.dx)
                local danger = along > -20 and along < reach and lat < (half + 18)
                if danger then danger_any = true; danger_who = d.charging and "CHARGING" or "aiming" end

                local r, g, b = 0.2, 1.0, 0.3
                if danger then r, g, b = 1.0, 0.15, 0.15 end
                local a = d.charging and 1.0 or 0.6
                local z = o.z + 8
                local ex, ey = o.x + d.dx * reach, o.y + d.dy * reach
                world_line(f, o.x, o.y, z, ex, ey, z, r, g, b, a)
                if opt("cl_edges", true) then
                    local nx, ny = -d.dy * half, d.dx * half
                    world_line(f, o.x + nx, o.y + ny, z, ex + nx, ey + ny, r, g, b, a * 0.6)
                    world_line(f, o.x - nx, o.y - ny, z, ex - nx, ey - ny, r, g, b, a * 0.6)
                end
            end
        end
    end
    info.in_lane = danger_any

    if danger_any and opt("cl_warn", true) then
        pcall(function()
            local txt = "CHARGER " .. (danger_who or "") .. " - MOVE SIDEWAYS"
            local tw = draw.get_text_width(fonts.ESP, txt)
            draw.string(fonts.ESP, math.floor((f.sw - tw) / 2), math.floor(f.sh * 0.30),
                1.0, 0.2, 0.2, 1.0, text_align.LEFT, txt)
        end)
    end
end }

if not _G.cl_menu then
    _G.cl_menu = true
    menu.add_sub_tab("Aimbot", "Charger Line", function()
        pcall(function()
            local ch, v
            ch, v = imgui.checkbox("Show charger line", opt("cl_on", false))
            if ch then client.set_shared_bool("cl_on", v) end
            ch, v = imgui.slider_int("Line length (units)", num("cl_len", 900), 200, 2500)
            if ch then client.set_shared_int("cl_len", v) end
            ch, v = imgui.slider_int("Lane half-width (units)", num("cl_width", 20), 8, 60)
            if ch then client.set_shared_int("cl_width", v) end
            ch, v = imgui.checkbox("Draw lane edges", opt("cl_edges", true))
            if ch then client.set_shared_bool("cl_edges", v) end
            ch, v = imgui.checkbox("Warning text when you are in the lane", opt("cl_warn", true))
            if ch then client.set_shared_bool("cl_warn", v) end
            imgui.text("  chargers seen: " .. info.found .. "   you in lane: " .. tostring(info.in_lane))
        end)
    end)
end

pcall(client.print, "[ChargerLine] loaded (off until you tick it in Aimbot > Charger Line)")
