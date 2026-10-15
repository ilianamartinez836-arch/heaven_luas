local CHARGE_KEY = keys.KEY_C
local MAX_CHARGE = 120
local BURST_TICKS = 25
local BURST_BASE = 18
local BURST_PER_CHARGE = 0.35
local BURST_MAX = 55
local SPOOF_CHOKED = 80

local CS_OFF = 4352236
local CS_NETCHAN = 24
local NC_ACK = 16
local NC_CHOKED = 28

local charge = 0
local burst_left = 0
local burst_value = 0
local prev_charge_key = false
local last_extra = -1

local function get_nc()
    local eng = modules.get_engine_base()
    if not eng or eng == 0 then return 0 end
    local cs = memory.read_int(eng + CS_OFF) or 0
    if cs == 0 then return 0 end
    local nc = memory.read_int(cs + CS_NETCHAN) or 0
    if nc == 0 then nc = engine.get_netchan_ptr() or 0 end
    return nc or 0
end

local function start_burst()
    if charge <= 0 and burst_left > 0 then return end
    if charge <= 0 then return end
    local v = math.floor(BURST_BASE + charge * BURST_PER_CHARGE)
    if v > BURST_MAX then v = BURST_MAX end
    if v < 1 then v = 1 end
    burst_value = v
    burst_left = BURST_TICKS
    charge = 0
end

local function apply_burst()
    if burst_left <= 0 then return end
    local extra = client.get_extra_commands() or 0
    local use = burst_value
    if type(extra) == "number" and extra > 0 then
        use = extra + math.floor(burst_value * 0.5)
        if use > BURST_MAX + 20 then use = BURST_MAX + 20 end
    end
    pcall(function() client.set_extra_commands(use) end)
    local nc = get_nc()
    if nc ~= 0 then
        pcall(function()
            memory.write_int(nc + NC_ACK, -1, false)
            memory.write_int(nc + NC_CHOKED, SPOOF_CHOKED, false)
        end)
    end
    burst_left = burst_left - 1
    if burst_left <= 0 then
        burst_value = 0
    end
end

function on_cl_move_pre()
    if not engine.is_in_game() then return end

    local holding = input.is_key_down(CHARGE_KEY)
    local extra = client.get_extra_commands()
    if type(extra) ~= "number" then extra = -1 end

    if holding then
        if charge < MAX_CHARGE then
            charge = charge + 1
        end
    end

    if prev_charge_key and not holding then
        start_burst()
    end

    if not holding and charge > 0 and type(extra) == "number" and extra > 0 then
        if last_extra <= 0 or (extra > last_extra and last_extra >= 0) then
            start_burst()
        elseif last_extra <= 0 and extra > 0 then
            start_burst()
        end
    end

    if not holding and charge > 0 and last_extra <= 0 and extra > 0 then
        start_burst()
    end

    if burst_left > 0 then
        apply_burst()
    end

    last_extra = extra
    prev_charge_key = holding
end

function on_unload()
    pcall(function() client.set_extra_commands(0) end)
    charge = 0
    burst_left = 0
end

client.print("[CHARGE] C hold=carga silenciosa | suelta O usa RF/speed Heaven=burst")
