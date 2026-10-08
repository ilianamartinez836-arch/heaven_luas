
local function get_team_prefix(player)
    if not player then return "(Unknown) " end
    local team = player:get_team()
    if team == 3 then return "(Infected) "
    elseif team == 2 then return "(Survivor) "
    elseif team == 1 then return "(Spectator) "
    else return "(Unknown) " end
end
local last_processed_votes = {}
function on_game_event(event_name, event)
    if not event then return end
    local local_player = client.get_local_player()
    if not local_player then return end
    local local_index = local_player:get_index()
    if event_name == "player_death" then
        local userid = event:get_int("userid")
        local attacker = event:get_int("attacker")
        local weapon = event:get_string("weapon")
        local headshot = event:get_bool("headshot")
        local victim_idx = engine.get_player_for_userid(userid)
        local attacker_idx = engine.get_player_for_userid(attacker)
        local victim_name = "Unknown"
        local attacker_name = "Unknown"
        if victim_idx and victim_idx > 0 then
            local victim_info = engine.get_player_info(victim_idx)
            if victim_info then
                victim_name = victim_info.name
            end
        end
        if attacker_idx and attacker_idx > 0 then
            local attacker_info = engine.get_player_info(attacker_idx)
            if attacker_info then
                attacker_name = attacker_info.name
            end
        end
        local victim = entity.get_by_index(victim_idx)
        local attacker_entity = entity.get_by_index(attacker_idx)
        local victim_prefix = get_team_prefix(victim)
        local attacker_prefix = get_team_prefix(attacker_entity)
        local msg = attacker_name .. " killed " .. victim_name .. " with " .. weapon
        if headshot then
            msg = msg .. " (HEADSHOT)"
        end
        chat.print(msg, 0)
    end
end
events.register("player_death")
events.register("infected_death")


-- Consistency Bypass (original)
local sv_consistency = cvar.find("sv_consistency")
local sv_pure = cvar.find("sv_pure")
local function apply_bypass()
    -- Forzado a true para que siempre pase el check inicial
    local enabled = true
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
-- Se ejecuta inmediatamente al cargar
apply_bypass()

client.print("Kill Notifier + Consistency Bypass cargados!")


