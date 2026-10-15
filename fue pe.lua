-- Jockey Free Ride (Heaven)
-- Cuando TÚ eres Jockey y estás cabalgando: control total de movimiento
-- (la resistencia del survivor se neutraliza lo máximo posible en cliente)

local JOCKEY_CLASS = 5
local TEAM_INFECTED = 3
local IN_FORWARD = 8
local IN_BACK = 16
local IN_MOVELEFT = 512
local IN_MOVERIGHT = 1024
local IN_SPEED = 131072

-- offsets candidatos de victim handle (validar en tu build si falla detección)
local VICTIM_HANDLE_OFFSETS = { 10060, 10056, 10064, 10052, 16020, 16024 }

local function is_jockey(lp)
    if not lp or not lp:is_alive() then return false end
    if lp:get_team() ~= TEAM_INFECTED then return false end
    if lp:is_ghost and lp:is_ghost() then return false end
    return lp:get_zombie_class() == JOCKEY_CLASS
end

local function handle_valid(h)
    if not h or h == 0 or h == -1 then return false end
    -- handles Source suelen ser serializados; índice bajo en low bits
    local idx = h % 65536
    return idx > 0 and idx < 2048
end

local function is_riding(lp)
    -- 1) sequence name
    local ok, seq = pcall(function()
        local s = lp:get_sequence_name and lp:get_sequence_name(lp:get_solid_flags and 0 or 0)
        return s
    end)
    -- mejor: intentar get_sequence si existe vía raw
    local raw = entity.get_by_index_raw(lp:get_index())
    if raw and raw ~= 0 then
        local ok2, seq_id = pcall(entity.get_sequence_from_ptr, raw)
        if ok2 and seq_id then
            local ok3, name = pcall(function() return lp:get_sequence_name(seq_id) end)
            if ok3 and name then
                local n = string.lower(name)
                if string.find(n, "jockey", 1, true)
                    or string.find(n, "ride", 1, true)
                    or string.find(n, "leap", 1, true) then
                    -- leap solo no basta; ride/jockey sí
                    if string.find(n, "ride", 1, true) or string.find(n, "jockey", 1, true) then
                        return true
                    end
                end
            end
        end

        -- 2) victim handle en memoria
        for _, off in ipairs(VICTIM_HANDLE_OFFSETS) do
            local okh, h = pcall(memory.read_int, raw + off)
            if okh and handle_valid(h) then
                local idx = h % 65536
                local vic = entity.get_by_index(idx)
                if vic and vic:is_alive() and vic:get_team() == 2 then
                    return true
                end
            end
        end
    end

    -- 3) fallback: move_type / flags raros mientras jockey (menos fiable)
    return false
end

local function force_full_move(cmd)
    local buttons = cmd:get_buttons()
    local fm = 0.0
    local sm = 0.0

    -- lee input real
    if (buttons & IN_FORWARD) ~= 0 then fm = fm + 1 end
    if (buttons & IN_BACK) ~= 0 then fm = fm - 1 end
    if (buttons & IN_MOVERIGHT) ~= 0 then sm = sm + 1 end
    if (buttons & IN_MOVELEFT) ~= 0 then sm = sm - 1 end

    -- también respeta analog stick de cmd si el jugador ya movió
    local cf = cmd:get_forwardmove()
    local cs = cmd:get_sidemove()
    if math.abs(cf) > 1 then fm = (cf > 0) and 1 or -1 end
    if math.abs(cs) > 1 then sm = (cs > 0) and 1 or -1 end

    -- si no hay input, empuja siempre adelante (control total tipo zonemod)
    if fm == 0 and sm == 0 then
        fm = 1
    end

    -- normaliza a máximo wish speed
    local len = math.sqrt(fm * fm + sm * sm)
    if len > 0 then
        fm = (fm / len) * 450.0
        sm = (sm / len) * 450.0
    end

    cmd:set_forwardmove(fm)
    cmd:set_sidemove(sm)

    -- limpia back implícito: solo deja flags coherentes
    local nb = buttons
    if fm > 0 then
        nb = (nb | IN_FORWARD) & ~IN_BACK
    elseif fm < 0 then
        nb = (nb | IN_BACK) & ~IN_FORWARD
    end
    if sm > 0 then
        nb = (nb | IN_MOVERIGHT) & ~IN_MOVELEFT
    elseif sm < 0 then
        nb = (nb | IN_MOVELEFT) & ~IN_MOVERIGHT
    end
    cmd:set_buttons(nb)
end

function on_create_move(cmd, local_player)
    if not cmd or not local_player then return end
    if not engine.is_in_game() then return end
    if not is_jockey(local_player) then return end
    if not is_riding(local_player) then return end

    force_full_move(cmd)
end

-- refuerzo en prediction (misma lógica)
function on_create_move_prediction(cmd, local_player)
    if not cmd or not local_player then return end
    if not is_jockey(local_player) then return end
    if not is_riding(local_player) then return end
    force_full_move(cmd)
end

function on_paint()
    local lp = client.get_local_player()
    if not lp or not is_jockey(lp) then return end
    if not is_riding(lp) then return end
    draw.string(fonts.DEBUG, 10, 100, 0.3, 1.0, 0.4, 1.0, text_align.LEFT, "JOCKEY FREE RIDE")
end

client.print("[Jockey Free Ride] loaded — solo actúa mientras cabalgas")