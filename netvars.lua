-- language: Lua, file: fase24_trace.lua, target: Heaven Hook (L4D2)
-- ============================================================
-- FASE 24. Analisis completo de trace.
-- ============================================================

if _G.__FASE24_RUN then return end
_G.__FASE24_RUN = true

local OUT = "C:\\Heaven-L4D2\\fase24_trace.txt"
local fh = nil
pcall(function() fh = io.open(OUT, "w") end)

local function L(s)
    if fh then pcall(function() fh:write(tostring(s) .. "\n"); fh:flush() end) end
end
local function S(t) L(""); L("--- " .. t) end

L("=== FASE 24 — TRACE ===")
L("Fecha: " .. (os.date and os.date("%Y-%m-%d %H:%M:%S") or "?"))

local function safe_val(v, depth)
    depth = depth or 0
    if depth > 2 then return "..." end
    if v == nil then return "nil" end
    local t = type(v)
    if t == "string" then
        if #v > 60 then return "'" .. v:sub(1, 60) .. "...'" end
        return "'" .. v .. "'"
    end
    if t == "number" then
        if v ~= v then return "nan" end
        return string.format("%.4f", v)
    end
    if t == "boolean" then return tostring(v) end
    if t == "table" then
        local parts = {}
        for k, v2 in pairs(v) do
            parts[#parts+1] = tostring(k) .. "=" .. safe_val(v2, depth + 1)
            if #parts > 8 then parts[#parts+1] = "..."; break end
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    if t == "userdata" then return "<userdata>" end
    return "<" .. t .. ">"
end

local function dump_table(tbl, prefix)
    prefix = prefix or "  "
    if type(tbl) ~= "table" then
        L(prefix .. "(no table, es " .. type(tbl) .. ")")
        return
    end
    for k, v in pairs(tbl) do
        L(string.format("%s%-25s = %s (%s)", prefix, tostring(k), safe_val(v), type(v)))
    end
end

-- ============================================================
-- esperar a tener local player
-- ============================================================
function on_create_move(cmd, lp)
    if _G.__FASE24_DONE then return end
    if not lp then return end
    if not lp:is_alive() then return end

    _G.__FASE24_DONE = true

    L("")
    L("local_player obtenido")

    local eye = lp:get_eye_position()
    local origin = lp:get_origin()
    L(string.format("  eye = (%.1f, %.1f, %.1f)", eye.x, eye.y, eye.z))
    L(string.format("  origin = (%.1f, %.1f, %.1f)", origin.x, origin.y, origin.z))

    -- ============================================================
    S("1. trace.line(from, to) — args minimos")

    -- definir 3 puntos: eye, un punto cercano al suelo, un punto lejano
    local near_pt = vector.new(eye.x, eye.y, eye.z - 50)
    local far_pt = vector.new(eye.x + 500, eye.y, eye.z)
    local down_pt = vector.new(eye.x, eye.y, eye.z - 500)

    -- trace al suelo (deberia golpear)
    local tr1 = nil
    local ok1 = pcall(function() tr1 = trace.line(eye, down_pt) end)
    L(string.format("  trace.line(eye, down) -> ok=%s", tostring(ok1)))
    if ok1 and tr1 then
        dump_table(tr1, "    ")
    end

    -- ============================================================
    S("2. trace.line(from, to, mask) — con mascara")

    -- mascara MASK_SHOT = 0x46004003 o MASK_PLAYERSOLID = 0x0200600B
    local masks = {
        { name = "MASK_SOLID",        val = 0x1 },
        { name = "MASK_PLAYERSOLID",  val = 0x0200600B },
        { name = "MASK_SHOT",         val = 0x46004003 },
        { name = "MASK_VISIBLE",      val = 0x1FFFFFF },
        { name = "MASK_ALL",          val = 0xFFFFFFFF },
    }
    for _, m in ipairs(masks) do
        local tr = nil
        local ok = pcall(function() tr = trace.line(eye, down_pt, m.val) end)
        if ok and tr then
            L(string.format("  mask=%-20s 0x%X  did_hit=%s  fraction=%.4f  entity_index=%s",
                m.name, m.val, tostring(tr.did_hit), tr.fraction or 0, tostring(tr.entity_index)))
        else
            L(string.format("  mask=%-20s 0x%X -> fallo", m.name, m.val))
        end
    end

    -- ============================================================
    S("3. trace.hull(from, to, mins, maxs)")

    local mins = vector.new(-16, -16, -16)
    local maxs = vector.new(16, 16, 16)
    local tr_hull = nil
    local ok_hull = pcall(function() tr_hull = trace.hull(eye, down_pt, mins, maxs) end)
    L(string.format("  trace.hull(eye, down, mins, maxs) -> ok=%s", tostring(ok_hull)))
    if ok_hull and tr_hull then
        L("  hit fields: did_hit=" .. tostring(tr_hull.did_hit) ..
          " fraction=" .. tostring(tr_hull.fraction) ..
          " entity_index=" .. tostring(tr_hull.entity_index))
    else
        L("  retorno: " .. tostring(tr_hull))
    end

    -- ============================================================
    S("4. trace.get_point_contents")

    -- probar con 4 args: x, y, z, mask
    local contents = nil
    local ok_c1 = pcall(function() contents = trace.get_point_contents(eye.x, eye.y, eye.z) end)
    L(string.format("  trace.get_point_contents(x, y, z) -> ok=%s ret=%s",
        tostring(ok_c1), tostring(contents)))

    -- probar con vector + mask
    local ok_c2, res2 = pcall(function() return trace.get_point_contents(eye, 0x1FFFFFF) end)
    L(string.format("  trace.get_point_contents(vec, mask) -> ok=%s ret=%s",
        tostring(ok_c2), tostring(res2)))

    -- probar con vector solo
    local ok_c3, res3 = pcall(function() return trace.get_point_contents(eye) end)
    L(string.format("  trace.get_point_contents(vec) -> ok=%s ret=%s",
        tostring(ok_c3), tostring(res3)))

    -- ============================================================
    S("5. trace.world_only")

    local tr_world = nil
    local ok_w = pcall(function() tr_world = trace.world_only(eye, down_pt) end)
    L(string.format("  trace.world_only(eye, down) -> ok=%s", tostring(ok_w)))
    if ok_w and tr_world then
        L("  hit fields: did_hit=" .. tostring(tr_world.did_hit) ..
          " fraction=" .. tostring(tr_world.fraction))
    end

    -- ============================================================
    S("6. trace.clip_ray_to_entity")

    -- buscar una entidad (el local player o el primero que encontremos)
    local target_ent = nil
    local target_idx = nil
    for i = 1, 32 do
        local e = nil
        pcall(function() e = entity.get_by_index(i) end)
        if e then
            local idx = nil
            pcall(function() idx = e:get_index() end)
            if idx and idx ~= lp:get_index() then
                local alive = false
                pcall(function() alive = e:is_alive() end)
                if alive then
                    target_ent = e
                    target_idx = idx
                    break
                end
            end
        end
    end

    if target_ent then
        local tgt_origin = nil
        pcall(function() tgt_origin = target_ent:get_origin() end)
        if tgt_origin then
            local tr_clip = nil
            local ok_clip = pcall(function() tr_clip = trace.clip_ray_to_entity(eye, tgt_origin, target_idx) end)
            L(string.format("  trace.clip_ray_to_entity(eye, target[%d], idx) -> ok=%s",
                target_idx, tostring(ok_clip)))
            if ok_clip and tr_clip then
                L("  hit fields: did_hit=" .. tostring(tr_clip.did_hit) ..
                  " fraction=" .. tostring(tr_clip.fraction) ..
                  " entity_index=" .. tostring(tr_clip.entity_index))
            end
        end
    else
        L("  no target encontrado")
    end

    -- ============================================================
    S("7. trace.point_outside_world")

    local outside1 = nil
    local ok_o1 = pcall(function() outside1 = trace.point_outside_world(eye) end)
    L(string.format("  trace.point_outside_world(eye) -> ok=%s ret=%s",
        tostring(ok_o1), tostring(outside1)))

    local outside2 = nil
    local ok_o2 = pcall(function() outside2 = trace.point_outside_world(vector.new(0, 0, -99999)) end)
    L(string.format("  trace.point_outside_world(lejos) -> ok=%s ret=%s",
        tostring(ok_o2), tostring(outside2)))

    -- ============================================================
    S("8. estructura completa de trace.line")
    L("(analizando todos los campos de un solo trace)")

    local tr_full = nil
    pcall(function() tr_full = trace.line(eye, down_pt) end)
    if tr_full and type(tr_full) == "table" then
        L("  total de campos: " .. (function()
            local n = 0
            for _ in pairs(tr_full) do n = n + 1 end
            return n
        end)())
        L("")
        for k, v in pairs(tr_full) do
            L(string.format("  %-25s type=%-10s value=%s",
                tostring(k), type(v), safe_val(v)))
        end
    end

    -- ============================================================
    S("9. como detectar si una entidad es visible? (patron comun)")
    L("  Idea: trace.line(eye, target.eye_pos). Si did_hit es true y")
    L("        fraction < 0.97, hay algo en medio (pared). Si fraction >= 0.97")
    L("        y entity_index == target_idx, es visible.")

    if target_ent then
        local tgt_eye = nil
        pcall(function() tgt_eye = target_ent:get_eye_position() end)
        if tgt_eye then
            local tr_vis = nil
            pcall(function() tr_vis = trace.line(eye, tgt_eye) end)
            if tr_vis then
                L(string.format("  trace.line(eye, target_eye):"))
                L(string.format("    did_hit       = %s", tostring(tr_vis.did_hit)))
                L(string.format("    fraction      = %s", tostring(tr_vis.fraction)))
                L(string.format("    entity_index  = %s", tostring(tr_vis.entity_index)))
                L(string.format("    hitgroup      = %s", tostring(tr_vis.hitgroup)))
                L(string.format("    hitbox        = %s", tostring(tr_vis.hitbox)))
                L(string.format("    target_idx    = %d", target_idx))
                L(string.format("    → visible?    %s",
                    tostring(tr_vis.did_hit and tr_vis.fraction and tr_vis.fraction > 0.97)))
            end
        end
    end

    L("")
    L("=== FIN ===")
    if fh then pcall(function() fh:close() end) end
    pcall(client.print, "[fase24] listo")
end
