-- Bleed Exploit Improved (ByxStorm) → Heaven
-- Escribe choked en client_state+19024 + spoof netchan; restaura al desactivar

local cfg = {
    enabled = false,
    key     = keys.KEY_B,   -- toggle
    value   = 45,           -- Byx default; el paquete real topea en ~14/15
}

local state = {
    key_prev       = false,
    genuine_ack    = 0,
    genuine_choked = 0,
    has_genuine    = false,
}

local ENGINE_CS_OFF   = 4352236  -- engine → client_state raw
local CS_NETCHAN_OFF  = 24
local CS_CHOKED_OFF   = 19024    -- raw client_state + 19024
local NC_ACK_OFF      = 16       -- m_nOutSequenceNrAck
local NC_CHOKED_OFF   = 28       -- m_nChokedPackets

local function get_client_state_raw()
    local eng = modules.get_engine_base()
    if not eng or eng == 0 then return 0 end
    local ok, cs = pcall(memory.read_int, eng + ENGINE_CS_OFF)
    if not ok or not cs or cs == 0 then return 0 end
    return cs
end

local function get_netchan(cs)
    if cs == 0 then return 0 end
    local ok, nc = pcall(memory.read_int, cs + CS_NETCHAN_OFF)
    if not ok or not nc or nc == 0 then
        -- fallback Heaven API
        local ok2, ptr = pcall(function() return engine.get_netchan_ptr() end)
        if ok2 and ptr and ptr ~= 0 then return ptr end
        return 0
    end
    return nc
end

local function read_int(addr)
    local ok, v = pcall(memory.read_int, addr)
    if ok then return v end
    return nil
end

local function write_int(addr, val)
    pcall(memory.write_int, addr, val, false)
end

local function capture_genuine(nc)
    if nc == 0 then return end
    local ack = read_int(nc + NC_ACK_OFF)
    local ch  = read_int(nc + NC_CHOKED_OFF)
    if ack and ack ~= -1 then
        state.genuine_ack = ack
        state.genuine_choked = ch or 0
        state.has_genuine = true
    end
end

local function apply_bleed()
    local cs = get_client_state_raw()
    if cs == 0 then return end

    local nc = get_netchan(cs)
    capture_genuine(nc)

    -- campo real chokedcommands (raw + 19024)
    write_int(cs + CS_CHOKED_OFF, cfg.value)

    if nc ~= 0 then
        write_int(nc + NC_ACK_OFF, -1)
        write_int(nc + NC_CHOKED_OFF, 255)
    end
end

local function restore_netchan()
    local cs = get_client_state_raw()
    if cs == 0 then return end
    local nc = get_netchan(cs)
    if nc == 0 or not state.has_genuine then return end

    -- solo restaurar si sigue el spoof (regla Byx)
    local ack = read_int(nc + NC_ACK_OFF)
    local ch  = read_int(nc + NC_CHOKED_OFF)
    if ack == -1 then
        write_int(nc + NC_ACK_OFF, state.genuine_ack)
    end
    if ch == 255 then
        write_int(nc + NC_CHOKED_OFF, state.genuine_choked)
    end
end

function on_cl_move_pre()
    -- toggle rising-edge
    local down = input.is_key_down(cfg.key)
    if down and not state.key_prev then
        cfg.enabled = not cfg.enabled
        if not cfg.enabled then
            restore_netchan()
        end
    end
    state.key_prev = down

    if not cfg.enabled then return end
    if not engine.is_in_game() then return end

    apply_bleed()
end

function on_unload()
    if cfg.enabled then
        restore_netchan()
    end
    cfg.enabled = false
end

client.print("[Bleed Improved] KEY_B toggle | value=45 | restore on off")
