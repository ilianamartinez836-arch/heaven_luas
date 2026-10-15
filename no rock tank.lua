-- =============================================
-- Hide Tank Rock FINAL (class 13 + FFI/memory NODRAW)
-- =============================================

local ROCK_CLASS_ID = 13
local enabled = true

local EF_NODRAW = 32
local kRenderNone = 10

-- offsets candidatos (se prueban todos; si uno pega, la roca se oculta)
local OFFSETS_EFFECTS = { 0x88, 0x8C, 0x90, 0xA0, 0xAC, 0xB0, 0xBC, 0xC0, 0xE4, 0xF0 }
local OFFSETS_RENDERMODE = { 0x7C, 0x80, 0x84, 0x94, 0x98, 0xA4, 0xA8, 0xB4, 0xB8, 0xD8 }

local function get_raw(index)
    local ok, ptr = pcall(function()
        return entity.get_by_index_raw(index)
    end)
    if ok and ptr and ptr ~= 0 then
        return ptr
    end
    return nil
end

local function get_class_id_raw(ptr)
    if not ptr then return nil end
    if entity.get_class_id_from_ptr then
        local ok, id = pcall(function()
            return entity.get_class_id_from_ptr(ptr)
        end)
        if ok then return id end
    end
    return nil
end

local function get_class_id_ent(ent)
    if not ent or not ent.get_class_id then return nil end
    local ok, id = pcall(function() return ent:get_class_id() end)
    if ok then return id end
    return nil
end

local function force_nodraw(ptr)
    if not ptr or ptr == 0 then return end

    for _, off in ipairs(OFFSETS_EFFECTS) do
        pcall(function()
            local cur = memory.read_int(ptr + off)
            if cur then
                memory.write_int(ptr + off, bit.bor(cur, EF_NODRAW), true)
            else
                memory.write_int(ptr + off, EF_NODRAW, true)
            end
        end)
    end

    for _, off in ipairs(OFFSETS_RENDERMODE) do
        pcall(function()
            memory.write_int(ptr + off, kRenderNone, true)
        end)
    end
end

local function process_rocks()
    if not enabled then return end
    if not engine.is_in_game() then return end

    local max_ents = 2048
    if entity.get_highest_index then
        local ok, v = pcall(function() return entity.get_highest_index() end)
        if ok and v and v > 0 then max_ents = v end
    elseif entity.get_player_count then
        max_ents = 4096
    end

    for i = 1, max_ents do
        local ent = entity.get_by_index(i)
        local id = get_class_id_ent(ent)

        local ptr = get_raw(i)
        if not id then
            id = get_class_id_raw(ptr)
        end

        if id == ROCK_CLASS_ID then
            if ptr then
                force_nodraw(ptr)
            end

            if ent then
                if ent.set_render_mode then
                    pcall(function() ent:set_render_mode(kRenderNone) end)
                end
                if ent.set_effects then
                    pcall(function() ent:set_effects(EF_NODRAW) end)
                end
            end
        end
    end
end

function on_draw_model_execute(model_info)
    if not enabled then return end

    local idx = nil
    if model_info then
        idx = model_info.entity_index or model_info.index or model_info.ent_index
    end

    if (not idx) and render and render.get_current_model_info then
        local ok, info = pcall(function() return render.get_current_model_info() end)
        if ok and info then
            idx = info.entity_index or info.index
        end
    end

    if idx and idx > 0 then
        local ent = entity.get_by_index(idx)
        local id = get_class_id_ent(ent)
        local ptr = get_raw(idx)
        if not id then id = get_class_id_raw(ptr) end

        if id == ROCK_CLASS_ID then
            if ptr then force_nodraw(ptr) end
            return -- no dibujar
        end
    end
end

function on_paint()
    process_rocks()
end

function on_create_move(cmd, local_player)
    process_rocks()
end

menu.add_main_tab("Hide Tank Rocks", function()
    local ch, val = imgui.checkbox("Hide Tank Rocks (ID 13)", enabled)
    if ch then enabled = val end
    imgui.text_colored(0.7, 0.7, 0.7, 1.0, "Metodo final: memory NODRAW + skip draw")
end)

client.print("[Hide Tank Rocks] FINAL cargado")
