--made by aika
-- this shit took some time because uhhhh. yes
-- it can be done better but il let u do that urself
local EXPLOIT_THRESHOLD = 560.0
local SEQUENCE_SHIFT = 90000

function on_create_move(cmd, pLocal)
    if not pLocal or not pLocal:is_alive() then return end

    local pAddr = entity.get_by_index_raw(pLocal:get_index())
    
    local eb = modules.get_engine_base()
    local ptr1 = memory.read_int(eb + 4352236)
    local netChannel = (ptr1 ~= 0) and memory.read_int(ptr1 + 24) or 0

    if pAddr == 0 or netChannel == 0 then return end

    local tickbase = memory.read_float(pAddr + 0x11FC)
    local cond1 = memory.read_int(pAddr + 0x1F84)

    if (tickbase > EXPLOIT_THRESHOLD) or (cond1 ~= 0) then
        
        local currentSeq = memory.read_int(netChannel + 8)
        memory.write_int(netChannel + 8, currentSeq + SEQUENCE_SHIFT, false)
    end
end
