ffi.cdef [[
    struct Global_Variables_Structure {
        char Additional_Bytes_1[12];
        float Time;
        float Frame_Time;
        char Additional_Bytes_2[8];
        float Interval_Per_Tick;
    };

    typedef void(__thiscall* Set_Color_Fn)(void* ecx, unsigned char red, unsigned char green, unsigned char blue, unsigned char alpha);
    typedef void(__thiscall* Draw_Circle_Fn)(void* ecx, int x, int y, int radius, int segments);
    typedef int(__cdecl* Get_Screen_Size_Fn)(int* width, int* height);
    typedef void*(__cdecl* Get_Display_Fn)();
]]

local INTERFACE_STORM_ROTATION_RADIUS = 24
local INTERFACE_STORM_RADIUS = 8
local INTERFACE_STORM_SEGMENTS = 12
local INTERFACE_STORM_ITERATIONS = 16
local INTERFACE_STORM_SPEED = 512

local Rotation_Angle = 0.0

function on_crosshair_hook()
    local Client_Module = modules.get_client_base()
    if not Client_Module or Client_Module == 0 then return false end
-- LOTS of ptr checks, i got it crashed once, i dont want it to crash again.
    local Get_Screen_Size = ffi.cast("Get_Screen_Size_Fn", Client_Module + 1780352)
    local screen_width_ptr  = ffi.new("int[1]")
    local screen_height_ptr = ffi.new("int[1]")
    Get_Screen_Size(screen_width_ptr, screen_height_ptr)
    local cx = screen_width_ptr[0]  / 2
    local cy = screen_height_ptr[0] / 2

    local surface_pp = ffi.cast("uintptr_t*", Client_Module + 8960244)
    if surface_pp == nil then return false end
    local surface_addr = surface_pp[0]
    if surface_addr == 0 then return false end
    local Surface = ffi.cast("void*", surface_addr)

    local vtable_addr = ffi.cast("uintptr_t*", surface_addr)[0]
    if vtable_addr == 0 then return false end

    local set_color_addr  = ffi.cast("uintptr_t*", vtable_addr + 44)[0]
    local draw_circle_addr = ffi.cast("uintptr_t*", vtable_addr + 384)[0]
    if set_color_addr == 0 or draw_circle_addr == 0 then return false end

    local Set_Color  = ffi.cast("Set_Color_Fn",  set_color_addr)
    local Draw_Circle = ffi.cast("Draw_Circle_Fn", draw_circle_addr)

    local Get_Display = ffi.cast("Get_Display_Fn", Client_Module + 2930128)
    local display_ptr = Get_Display()
    if display_ptr ~= nil then
        local display_addr = ffi.cast("uintptr_t", display_ptr)
        if display_addr ~= 0 then
            ffi.cast("int*", ffi.cast("uint8_t*", display_ptr) + 400)[0] = 0
        end
    end

    local function Draw_Storm(x, y, extra_angle)
        local angle_rad = math.rad((Rotation_Angle + extra_angle) % 360)
        local px = math.floor(x + INTERFACE_STORM_ROTATION_RADIUS * math.cos(angle_rad))
        local py = math.floor(y + INTERFACE_STORM_ROTATION_RADIUS * math.sin(angle_rad))

        Set_Color(Surface, 0, 0, 0, 255)
        Draw_Circle(Surface, px - 1, py,     INTERFACE_STORM_RADIUS, INTERFACE_STORM_SEGMENTS)
        Draw_Circle(Surface, px,     py - 1, INTERFACE_STORM_RADIUS, INTERFACE_STORM_SEGMENTS)
        Draw_Circle(Surface, px + 1, py,     INTERFACE_STORM_RADIUS, INTERFACE_STORM_SEGMENTS)
        Draw_Circle(Surface, px,     py + 1, INTERFACE_STORM_RADIUS, INTERFACE_STORM_SEGMENTS)
        Draw_Circle(Surface, px - 1, py - 1, INTERFACE_STORM_RADIUS, INTERFACE_STORM_SEGMENTS)
        Draw_Circle(Surface, px + 1, py - 1, INTERFACE_STORM_RADIUS, INTERFACE_STORM_SEGMENTS)
        Draw_Circle(Surface, px - 1, py + 1, INTERFACE_STORM_RADIUS, INTERFACE_STORM_SEGMENTS)
        Draw_Circle(Surface, px + 1, py + 1, INTERFACE_STORM_RADIUS, INTERFACE_STORM_SEGMENTS)

        Set_Color(Surface, 0, 128, 255, 255)
        Draw_Circle(Surface, px, py, INTERFACE_STORM_RADIUS, INTERFACE_STORM_SEGMENTS)
    end

    for i = 0, INTERFACE_STORM_ITERATIONS - 1 do
        Draw_Storm(cx, cy, i * 360 / INTERFACE_STORM_ITERATIONS)
    end

    local gv_pp = ffi.cast("struct Global_Variables_Structure**", Client_Module + 7096744)
    if gv_pp ~= nil then
        local gv_addr = ffi.cast("uintptr_t*", gv_pp)[0]
        if gv_addr ~= 0 then
            local gv = ffi.cast("struct Global_Variables_Structure*", gv_addr)
            Rotation_Angle = (Rotation_Angle + gv.Frame_Time * INTERFACE_STORM_SPEED) % 360
        end
    end

    return true  --tells C++ to suppress the original crosshair btw
end