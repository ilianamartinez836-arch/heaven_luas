local RF_KEY = keys.KEY_F
local SEQ_KEY = keys.KEY_X

local RF_VALUE = 22
local RF_VALUE_COMBO = 14
local SEQ_ADD = 80
local SEQ_ADD_COMBO = 40
local SPOOF_CHOKED = 64

local CS_OFF = 4352236
local CS_NETCHAN = 24
local NC_SEQ = 8
local NC_ACK = 16
local NC_CHOKED = 28

local function get_nc()
    local eng = modules.get_engine_base()
    if not eng or eng == 0 then return 0 end
    local cs = memory.read_int(eng + CS_OFF) or 0
    if cs == 0 then return 0 end
    local nc = memory.read_int(cs + CS_NETCHAN) or 0
    if nc == 0 then nc = engine.get_netchan_ptr() or 0 end
    return nc or 0
end

function on_cl_move_pre()
    if not engine.is_in_game() then return end

    local rf = input.is_key_down(RF_KEY)
    local seq = input.is_key_down(SEQ_KEY)
    local nc = get_nc()
    local combo = rf and seq

    if rf then
        local v = combo and RF_VALUE_COMBO or RF_VALUE
        pcall(function() client.set_extra_commands(v) end)
        if nc ~= 0 then
            pcall(function()
                memory.write_int(nc + NC_ACK, -1, false)
                memory.write_int(nc + NC_CHOKED, SPOOF_CHOKED, false)
            end)
        end
    else
        pcall(function() client.set_extra_commands(0) end)
    end

    if seq and nc ~= 0 then
        local add = combo and SEQ_ADD_COMBO or SEQ_ADD
        pcall(function()
            local s = memory.read_int(nc + NC_SEQ) or 0
            memory.write_int(nc + NC_SEQ, s + add, true)
        end)
    end
end

function on_unload()
    pcall(function() client.set_extra_commands(0) end)
end

client.print("[TEST] F=RF | X=seq(nc+8) | F+X=combo suave")
