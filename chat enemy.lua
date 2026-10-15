-- Enemy Team Leak (Heaven)
-- Reenvía chat del team enemigo a global (sale con TU nombre)
-- Menú para disimular: newlines, delay, cooldown, formato

local cfg = {
    enabled = true,
    only_teamonly = true,       -- solo chat de equipo enemigo
    only_enemies = true,        -- siempre true en práctica
    show_team_prefix = true,    -- (Infected) / (Survivor)
    show_name = true,
    soft_prefix = false,        -- añade "· " al inicio del texto
    newline_count = 2,          -- \r al inicio (0 = nada)
    newline_after = 0,          -- \r al final
    delay_min = 1.6,            -- segundos antes de publicar
    delay_max = 3.8,
    cooldown = 2.5,             -- mínimo entre un say y el siguiente
    max_msg_len = 120,
    skip_empty = true
}

local team_label = {
    [0] = "Unknown",
    [1] = "Spectator",
    [2] = "Survivor",
    [3] = "Infected"
}

local pending = {}   -- { when, text, sig }
local last_sent_at = 0
local last_sig = ""
local stats = { captured = 0, sent = 0, skipped = 0 }

local function now()
    return os.clock()
end

local function clamp_str(s, max_len)
    if not s then return "" end
    s = tostring(s)
    if #s > max_len then
        s = string.sub(s, 1, max_len - 3) .. "..."
    end
    return s
end

local function sanitize(s)
    s = clamp_str(s, cfg.max_msg_len)
    s = s:gsub('"', "'")
    s = s:gsub("[\n\r]", " ")
    return s
end

local function build_payload(team_num, player_name, text)
    local parts = {}

    if cfg.soft_prefix then
        parts[#parts + 1] = "· "
    end

    if cfg.show_team_prefix then
        parts[#parts + 1] = "(" .. (team_label[team_num] or "Unknown") .. ") "
    end

    if cfg.show_name then
        parts[#parts + 1] = tostring(player_name or "?") .. ": "
    end

    parts[#parts + 1] = text
    return table.concat(parts)
end

local function decorate(msg)
    local pre = string.rep("\r", math.max(0, cfg.newline_count))
    local post = string.rep("\r", math.max(0, cfg.newline_after))
    return pre .. msg .. post
end

local function enqueue(text, sig)
    if not cfg.enabled then return end
    if cfg.skip_empty and (not text or text == "") then return end
    if sig and sig == last_sig then
        stats.skipped = stats.skipped + 1
        return
    end

    for i = 1, #pending do
        if pending[i].sig == sig then
            stats.skipped = stats.skipped + 1
            return
        end
    end

    local dmin = math.min(cfg.delay_min, cfg.delay_max)
    local dmax = math.max(cfg.delay_min, cfg.delay_max)
    local delay = dmin + math.random() * (dmax - dmin)

    pending[#pending + 1] = {
        when = now() + delay,
        text = text,
        sig = sig or text
    }
    stats.captured = stats.captured + 1
end

local function flush()
    if not cfg.enabled then return end
    if #pending == 0 then return end

    local t = now()
    if t - last_sent_at < cfg.cooldown then return end

    -- el más antiguo que ya cumplió delay
    local idx = nil
    for i = 1, #pending do
        if pending[i].when <= t then
            idx = i
            break
        end
    end
    if not idx then return end

    local item = table.remove(pending, idx)
    last_sent_at = t
    last_sig = item.sig
    stats.sent = stats.sent + 1

    local final_msg = decorate(item.text)
    client.execnormal('say "' .. final_msg .. '"')
end

local function on_player_say(event)
    if not cfg.enabled then return end
    if not engine.is_in_game() then return end

    local local_player = client.get_local_player()
    if not local_player then return end

    local user_id = event:get_int("userid")
    local text = event:get_string("text")
    local team_only = false
    pcall(function() team_only = event:get_bool("teamonly") end)

    if cfg.skip_empty and (not text or text == "") then return end
    if cfg.only_teamonly and not team_only then
        stats.skipped = stats.skipped + 1
        return
    end

    local entity_idx = engine.get_player_for_userid(user_id)
    if not entity_idx or entity_idx <= 0 then return end

    local local_idx = local_player:get_index()
    if entity_idx == local_idx then return end

    local local_team = local_player:get_team()
    local player = entity.get_by_index(entity_idx)
    if not player then return end

    local team_num = player:get_team()
    if cfg.only_enemies and team_num == local_team then
        stats.skipped = stats.skipped + 1
        return
    end

    -- no filtrar specs como "enemigo útil"
    if team_num ~= 2 and team_num ~= 3 then
        stats.skipped = stats.skipped + 1
        return
    end

    local player_name = "?"
    local info = engine.get_player_info(entity_idx)
    if info and info.name and info.name ~= "" then
        player_name = info.name
    else
        pcall(function()
            local n = player:get_name()
            if n and n ~= "" then player_name = n end
        end)
    end

    local clean = sanitize(text)
    local payload = build_payload(team_num, player_name, clean)
    local sig = tostring(user_id) .. "|" .. tostring(team_only) .. "|" .. clean
    enqueue(payload, sig)
end

events.register("player_say")

function on_game_event(event_name, event)
    if event_name == "player_say" and event then
        on_player_say(event)
    end
end

function on_create_move(cmd, local_player)
    flush()
end

menu.add_main_tab("Enemy Leak", function()
    local ch, val

    ch, val = imgui.checkbox("Enable", cfg.enabled)
    if ch then cfg.enabled = val end

    imgui.separator()
    imgui.text("Filtros")
    ch, val = imgui.checkbox("Only team chat (teamonly)", cfg.only_teamonly)
    if ch then cfg.only_teamonly = val end
    ch, val = imgui.checkbox("Only enemy team", cfg.only_enemies)
    if ch then cfg.only_enemies = val end

    imgui.separator()
    imgui.text("Formato")
    ch, val = imgui.checkbox("Team prefix (Infected/Survivor)", cfg.show_team_prefix)
    if ch then cfg.show_team_prefix = val end
    ch, val = imgui.checkbox("Show enemy name", cfg.show_name)
    if ch then cfg.show_name = val end
    ch, val = imgui.checkbox("Soft prefix (·)", cfg.soft_prefix)
    if ch then cfg.soft_prefix = val end

    imgui.separator()
    imgui.text("Newlines (disimulo visual)")
    ch, val = imgui.slider_int("Newlines before", cfg.newline_count, 0, 6)
    if ch then cfg.newline_count = val end
    ch, val = imgui.slider_int("Newlines after", cfg.newline_after, 0, 4)
    if ch then cfg.newline_after = val end

    imgui.separator()
    imgui.text("Timing")
    ch, val = imgui.slider_float("Delay min (s)", cfg.delay_min, 0.0, 8.0)
    if ch then cfg.delay_min = val end
    ch, val = imgui.slider_float("Delay max (s)", cfg.delay_max, 0.0, 10.0)
    if ch then cfg.delay_max = val end
    ch, val = imgui.slider_float("Cooldown (s)", cfg.cooldown, 0.5, 10.0)
    if ch then cfg.cooldown = val end

    imgui.separator()
    imgui.text_colored(0.7, 0.7, 0.7, 1.0,
        string.format("Captured:%d  Sent:%d  Skipped:%d  Queue:%d",
            stats.captured, stats.sent, stats.skipped, #pending))

    imgui.text_colored(0.55, 0.55, 0.55, 1.0, "El say siempre sale con TU nombre")
    imgui.text_colored(0.55, 0.55, 0.55, 1.0, "Recomendado disimulo: nl=2, delay 2-4, cd=3, solo teamonly")

    if imgui.button("Clear queue") then
        pending = {}
    end

    imgui["end"]()
end)

function on_unload()
    pending = {}
end

client.print("[Enemy Leak] loaded — tab Enemy Leak")