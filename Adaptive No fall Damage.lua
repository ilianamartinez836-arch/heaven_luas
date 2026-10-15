-- =============================================
-- AUTO NO FALL DAMAGE MANAGER
-- Solo cambia según equipo - Sin feedback
-- =============================================

local nofall = {
    original_state = true,
    last_team = 0
}

function on_create_move(cmd, local_player)
    if not local_player then return end
    if not engine.is_in_game() then return end

    local current_team = local_player:get_team()
    
    if current_team == nofall.last_team then
        return
    end

    nofall.last_team = current_team

    if current_team == 3 then
        -- Infectado → Desactivar No Fall Damage
        nofall.original_state = cvar_vars.get_bool("vars_enable_no_fall")
        cvar_vars.set_bool("vars_enable_no_fall", false)
    elseif current_team == 2 then
        -- Survivor → Restaurar estado original
        cvar_vars.set_bool("vars_enable_no_fall", nofall.original_state)
    end
end

function on_unload()
    cvar_vars.set_bool("vars_enable_no_fall", nofall.original_state)
end