-- language: Lua, file: nofall.lua, target: Heaven Hook (L4D2)
-- Port de aimware: suma 20000 al out sequence number mientras mantenes la tecla.
-- Desincroniza el server -> ignora el daño por caída al aterrizar.
-- Sin menu. Tecla fija: K. Si querés otra, cambiala en KEY_* abajo.

-- offsets (mismos que usan los otros luas de netchan)
local ENGINE_CS_OFF  = 4352236
local CS_NETCHAN_OFF = 24
local NC_SEQ_OFF     = 8

-- keybind: K por default (keyboxes de aimware usan VK codes; K = 0x4B)
local KEY = keys.KEY_K

-- cantidad a sumar por tick
local SEQ_ADD = 20000

local function get_engine_base()
    local ok, b = pcall(modules.get_engine_base)
    if ok and b and b ~= 0 then return b end
    return 0
end

local function ri(addr)
    local ok, v = pcall(memory.read_int, addr)
    if ok then return v end
    return nil
end

local function wi(addr, val)
    pcall(memory.write_int, addr, val, false)
end

local function get_nc()
    local eb = get_engine_base()
    if eb == 0 then return 0 end
    local cs = ri(eb + ENGINE_CS_OFF)
    if not cs or cs == 0 then return 0 end
    local nc = ri(cs + CS_NETCHAN_OFF)
    if nc and nc ~= 0 then return nc end
    local ok, ptr = pcall(engine.get_netchan_ptr)
    if ok and ptr and ptr ~= 0 then return ptr end
    return 0
end

local function add_out_seq(nc, amount)
    if nc == 0 then return false end
    local cur = ri(nc + NC_SEQ_OFF)
    if not cur then return false end
    wi(nc + NC_SEQ_OFF, cur + amount)
    return true
end

function on_create_move(cmd, local_player)
    if not cmd or not local_player then return end
    if not local_player:is_alive() then return end

    local down = false
    pcall(function() down = input.is_key_down(KEY) end)
    if not down then return end

    local nc = get_nc()
    if nc == 0 then return end

    add_out_seq(nc, SEQ_ADD)
end

client.print("[nofall] cargado — mantene K en el aire para evitar daño por caida")
