local fov_ptr = nil
local viewmodel_ptr = nil

local original_fov = 0
local original_viewmodel = 0
local original_vm_x = 0
local original_vm_y = 0
local original_vm_z = 0

local current_fov_val = 0
local current_viewmodel_val = 78

function init()
    fov_ptr = cvar.find("fov_desired")
    viewmodel_ptr = cvar.find("cl_viewmodelfovsurvivor")
    
    if fov_ptr == 0 or viewmodel_ptr == 0 then
        return false
    end

    original_fov = cvar.get_int(fov_ptr)
    original_viewmodel = cvar.get_int(viewmodel_ptr)
    
    original_vm_x = cvar_vars.get_intf_float("viewmodel_x")
    original_vm_y = cvar_vars.get_intf_float("viewmodel_y")
    original_vm_z = cvar_vars.get_intf_float("viewmodel_z")

    current_fov_val = original_fov
    current_viewmodel_val = 78

    cvar.set_int(viewmodel_ptr, 78)

    return true
end

menu.inject_into_subtab("World", "World", function()
    local changed_fov, new_fov = imgui.slider_int("Field of View", current_fov_val, 75, 120)
    if changed_fov then
        current_fov_val = new_fov
    end

    local changed_vm, new_vm = imgui.slider_int("Viewmodel FOV", current_viewmodel_val, 50, 180)
    if changed_vm then
        current_viewmodel_val = new_vm
    end

    imgui["end"]()
end)

function on_override_view()
    local local_player = client.get_local_player()
    if fov_ptr ~= 0 then
        if cvar.get_int(fov_ptr) ~= current_fov_val then
            cvar.set_int(fov_ptr, current_fov_val)
        end
    end

    if viewmodel_ptr ~= 0 then
        if cvar.get_int(viewmodel_ptr) ~= current_viewmodel_val then
            cvar.set_int(viewmodel_ptr, current_viewmodel_val)
        end
    end

    if local_player and local_player:is_alive() and local_player:get_team() == 2 then
        cvar_vars.set_intf_float("viewmodel_x", 10.0)
        cvar_vars.set_intf_float("viewmodel_y", 10.0)
        cvar_vars.set_intf_float("viewmodel_z", -7.0)
    else
        cvar_vars.set_intf_float("viewmodel_x", 0.0)
        cvar_vars.set_intf_float("viewmodel_y", 0.0)
        cvar_vars.set_intf_float("viewmodel_z", 0.0)
    end
end

function on_unload()
    if fov_ptr ~= 0 then
        cvar.set_int(fov_ptr, original_fov)
    end
    
    if viewmodel_ptr ~= 0 then
        cvar.set_int(viewmodel_ptr, original_viewmodel)
    end

    cvar_vars.set_intf_float("viewmodel_x", original_vm_x)
    cvar_vars.set_intf_float("viewmodel_y", original_vm_y)
    cvar_vars.set_intf_float("viewmodel_z", original_vm_z)
end

init()
