client.set_shared_bool("consistency_bypass_enabled", false)

local sv_consistency = cvar.find("sv_consistency")
local sv_pure = cvar.find("sv_pure")

local function apply_bypass()
    local enabled = client.get_shared_bool("consistency_bypass_enabled", false)
    if not enabled then return end

    if sv_consistency ~= 0 then
        cvar.remove_flags(sv_consistency, cvar_flags.PROTECTED)
        cvar.remove_flags(sv_consistency, cvar_flags.CHEAT)
        cvar.set_int(sv_consistency, 0)
    end

    if sv_pure ~= 0 then
        cvar.remove_flags(sv_pure, cvar_flags.PROTECTED)
        cvar.remove_flags(sv_pure, cvar_flags.CHEAT)
        cvar.set_int(sv_pure, 0)
    end
end

function on_create_move(cmd, local_player)
    apply_bypass()
end

apply_bypass()

menu.add_sub_tab("Exploits", "ConsistencyBypass", function()
    imgui.text("Consistency Bypass")

    local current_state = client.get_shared_bool("consistency_bypass_enabled", false)
    local changed, val = imgui.checkbox("Enabled Consistency bypass", current_state)
    
    if changed then
        client.set_shared_bool("consistency_bypass_enabled", val)
        apply_bypass()
    end

    imgui.separator()

    imgui.text("Current values:")
    if sv_consistency ~= 0 then
        imgui.text("sv_consistency: " .. cvar.get_int(sv_consistency))
    end
    if sv_pure ~= 0 then
        imgui.text("sv_pure: " .. cvar.get_int(sv_pure))
    end

    imgui["end"]()
end)
