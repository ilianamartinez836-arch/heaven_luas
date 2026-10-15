local fov_ptr = nil
local viewmodel_ptr = nil
local original_fov = 0
local original_viewmodel = 0
function init()
    fov_ptr = cvar.find("fov_desired")
    viewmodel_ptr = cvar.find("cl_viewmodelfovsurvivor")
    if fov_ptr == 0 or viewmodel_ptr == 0 then
        client.print("Error: Could not find FOV CVars.")
        return false
    end
    original_fov = cvar.get_int(fov_ptr)
    client.set_shared_int("fov_value", original_fov)
    original_viewmodel = cvar.get_int(viewmodel_ptr)
    client.set_shared_int("viewmodel_value", original_viewmodel)
    return true
end
menu.add_main_tab("Fov changer", function()
    local current_fov = client.get_shared_int("fov_value")
    local changed_fov, new_fov = imgui.slider_int("Field of View", current_fov, 75, 120)
    
    if changed_fov then
        client.set_shared_int("fov_value", new_fov)
        if fov_ptr ~= 0 then
            cvar.set_int(fov_ptr, new_fov)
        end
    end
    local current_vm = client.get_shared_int("viewmodel_value")
    local changed_vm, new_vm = imgui.slider_int("Viewmodel FOV", current_vm, 50, 180)
    
    if changed_vm then
        client.set_shared_int("viewmodel_value", new_vm)
        if viewmodel_ptr ~= 0 then
            cvar.set_int(viewmodel_ptr, new_vm)
        end
    end
    imgui["end"]()
end)
function on_override_view()
    if fov_ptr and fov_ptr ~= 0 then
        local target_fov = client.get_shared_int("fov_value")
        if cvar.get_int(fov_ptr) ~= target_fov then
            cvar.set_int(fov_ptr, target_fov)
        end
    end
    if viewmodel_ptr and viewmodel_ptr ~= 0 then
        local target_vm = client.get_shared_int("viewmodel_value")
        if cvar.get_int(viewmodel_ptr) ~= target_vm then
            cvar.set_int(viewmodel_ptr, target_vm)
        end
    end
end
function on_unload()
    if fov_ptr and fov_ptr ~= 0 then
        cvar.set_int(fov_ptr, original_fov)
    end
    
    if viewmodel_ptr and viewmodel_ptr ~= 0 then
        cvar.set_int(viewmodel_ptr, original_viewmodel)
    end
end
init()
