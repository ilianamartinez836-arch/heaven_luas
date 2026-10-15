-- language: Lua, file: spec_esp.lua, target: Heaven Hook (L4D2)
-- FIX: entity.get_all() devuelve TODO. Filtrar solo jugadores (index <= max_clients
-- y que tengan player_info valido).

local KEY = keys.KEY_K

local COL_R, COL_G, COL_B, COL_A = 0.78, 0.59, 1.0, 1.0

local FONT = fonts.ESP

local spec_cache  = {}
local last_scan   = 0.0
local SCAN_RATE   = 0.2

local prev_k = false
local enabled = false

-- world_to_screen
local function w2s(x, y, z)
    local ok, mat_ptr = pcall(engine.world_to_screen_matrix)
    if not ok or not mat_ptr or mat_ptr == 0 then return nil end
    local function rm(i)
        local ok2, v = pcall(memory.read_float, mat_ptr + i * 4)
        return ok2 and v or 0
    end
    local m00, m01, m02, m03 = rm(0), rm(1), rm(2), rm(3)
    local m10, m11, m12, m13 = rm(4), rm(5), rm(6), rm(7)
    local m30, m31, m32, m33 = rm(12), rm(13), rm(14), rm(15)
    local w = m30 * x + m31 * y + m32 * z + m33
    if w < 0.001 then return nil end
    local inv = 1.0 / w
    local sw, sh = 0, 0
    pcall(function() sw, sh = engine.get_screen_size() end)
    if not sw or sw == 0 then return nil end
    local sx = (m00 * x + m01 * y + m02 * z + m03) * inv
    local sy = (m10 * x + m11 * y + m12 * z + m13) * inv
    return math.floor(sw / 2 + sx * sw / 2),
           math.floor(sh / 2 - sy * sh / 2)
end

-- scan SOLO de jugadores
local function scan_specs()
    local now = os.clock()
    if now - last_scan < SCAN_RATE then return end
    last_scan = now

    spec_cache = {}
    local max_clients = 32
    pcall(function() max_clients = engine.get_max_clients() end)
    if not max_clients or max_clients <= 0 or max_clients > 64 then max_clients = 32 end

    -- iterar SOLO los slots de jugador (1..max_clients)
    for i = 1, max_clients do
        local e
        pcall(function() e = entity.get_by_index(i) end)
        if e then
            -- validar que sea un jugador real: existe player_info
            local info
            pcall(function() info = engine.get_player_info(i) end)
            if info and info.name and info.name ~= "" then
                local mode
                pcall(function() mode = e:get_observer_mode() end)
                if mode and mode > 0 then
                    table.insert(spec_cache, { ent = e, idx = i, name = info.name })
                end
            end
        end
    end
end

local function get_origin(ent)
    local o
    pcall(function() o = ent:get_origin() end)
    return o
end

local function draw_spec_esp()
    if not enabled then return end

    local me
    pcall(function() me = client.get_local_player() end)
    if not me then return end
    local my_idx
    pcall(function() my_idx = me:get_index() end)
    if not my_idx then return end

    local sw, sh = 0, 0
    pcall(function() sw, sh = engine.get_screen_size() end)
    if not sw or sw == 0 then return end

    scan_specs()

    local watching_me = {}
    local free_cam    = {}

    for _, entry in ipairs(spec_cache) do
        local e, idx, name = entry.ent, entry.idx, entry.name
        if idx ~= my_idx then
            local tgt
            pcall(function() tgt = e:get_observer_target() end)

            if tgt then
                local tgt_idx
                pcall(function() tgt_idx = tgt:get_index() end)
                if tgt_idx == my_idx then
                    table.insert(watching_me, name)
                elseif tgt_idx then
                    local tgt_origin = get_origin(tgt)
                    if tgt_origin then
                        local sx, sy = w2s(tgt_origin.x, tgt_origin.y, tgt_origin.z + 100)
                        if sx and sy then
                            local tgt_name = "?"
                            pcall(function()
                                local ti = engine.get_player_info(tgt_idx)
                                if ti and ti.name then tgt_name = ti.name end
                            end)
                            local txt = string.format("[SPEC] %s -> %s", name, tgt_name)
                            local tw = 0
                            pcall(function() tw = draw.get_text_width(FONT, txt) end)
                            pcall(function()
                                draw.string(FONT, sx - math.floor(tw/2) + 1, sy + 1,
                                    0, 0, 0, 0.8, text_align.LEFT, txt)
                            end)
                            pcall(function()
                                draw.string(FONT, sx - math.floor(tw/2), sy,
                                    COL_R, COL_G, COL_B, COL_A, text_align.LEFT, txt)
                            end)
                        end
                    end
                end
            else
                -- sin target = free cam
                local origin = get_origin(e)
                if origin then
                    table.insert(free_cam, {
                        name = name,
                        x = origin.x, y = origin.y, z = origin.z
                    })
                end
            end
        end
    end

    -- "watching me" arriba a la derecha
    if #watching_me > 0 then
        local y = 20
        for _, n in ipairs(watching_me) do
            local txt = "[!] " .. n .. " te esta mirando"
            local tw = 0
            pcall(function() tw = draw.get_text_width(FONT, txt) end)
            pcall(function()
                draw.string(FONT, sw - tw - 9, y + 1,
                    0, 0, 0, 0.8, text_align.LEFT, txt)
            end)
            pcall(function()
                draw.string(FONT, sw - tw - 10, y,
                    1.0, 0.31, 0.31, 1.0, text_align.LEFT, txt)
            end)
            y = y + 18
        end
    end

    for _, fc in ipairs(free_cam) do
        local sx, sy = w2s(fc.x, fc.y, fc.z)
        if sx and sy then
            local txt = "[SPEC] " .. fc.name
            local tw = 0
            pcall(function() tw = draw.get_text_width(FONT, txt) end)
            pcall(function()
                draw.string(FONT, sx - math.floor(tw/2) + 1, sy + 1,
                    0, 0, 0, 0.8, text_align.LEFT, txt)
            end)
            pcall(function()
                draw.string(FONT, sx - math.floor(tw/2), sy,
                    COL_R, COL_G, COL_B, COL_A, text_align.LEFT, txt)
            end)
            pcall(function()
                draw.circle(sx, sy, 4, 16, COL_R, COL_G, COL_B, COL_A)
            end)
        end
    end
end

function on_create_move(cmd, local_player)
    local down = false
    pcall(function() down = input.is_key_down(KEY) end)
    if down and not prev_k then
        enabled = not enabled
        pcall(client.print, "[spec_esp] " .. (enabled and "ON" or "OFF"))
    end
    prev_k = down
end

function on_paint()
    pcall(draw_spec_esp)
end

client.print("[spec_esp] cargado — K para toggle")
