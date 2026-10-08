local config = {
    update_interval = 1.0
}

local netdata = {
    last_update = 0,
    cached_stats = {}
}

local function get_player_name()
    local local_player = client.get_local_player()
    if not local_player then return "Unknown" end

    local index = local_player:get_index()
    if not index or index <= 0 then return "Unknown" end

    local info = engine.get_player_info(index)
    if info and info.name then
        return info.name
    end

    return "Unknown"
end

local function get_map_name()
    if not engine.is_in_game() then
        return "Menu"
    end

    local map = engine.get_level_name_short()
    if map and map ~= "" then
        return map
    end

    return "Unknown"
end

local function get_map_full()
    if not engine.is_in_game() then
        return "Not in game"
    end

    local map = engine.get_level_name()
    if map and map ~= "" then
        return map
    end

    return "Unknown"
end

local function update_network_stats()
    if not engine.is_connected() then
        netdata.cached_stats = { "Not connected to a server" }
        return
    end

    local net = engine.get_net_channel_info()
    if not net then
        netdata.cached_stats = { "No net channel info" }
        return
    end

    local serverAddress = net.address or "Unknown"
    local player_name = get_player_name()
    local map_short = get_map_name()
    local map_full = get_map_full()
    local time_str = os.date("%H:%M:%S")
    local date_str = os.date("%d/%m/%Y")

    netdata.cached_stats = {
        string.format("Player: %s", player_name),
        string.format("Map: %s", map_short),
        string.format("Full Map: %s", map_full),
        string.format("Time: %s  |  Date: %s", time_str, date_str),
        "-----------------------------",
        string.format("Server: %s", serverAddress),
        string.format("Latency Out/In: %.1f / %.1f ms", net.latency_out * 1000, net.latency_in * 1000),
        string.format("Loss: %.2f%%  |  Choke: %.2f%%", net.loss_out * 100, net.choke_out * 100),
        string.format("Rate: %.1f KB/s Out | %.1f KB/s In", net.data_out / 1024, net.data_in / 1024),
        string.format("Packets: %.1f/s Out | %.1f/s In", net.packets_out, net.packets_in),
        string.format("Total Data: %.2f MB Out | %.2f MB In", net.total_data_out / 1024 / 1024, net.total_data_in / 1024 / 1024),
        string.format("Connected: %.1fs", net.time_connected),
        string.format("Timeout: %.1fs  |  Timing Out: %s", net.timeout_seconds, tostring(net.is_timing_out))
    }
end

function on_end_scene()
    local now = os.clock()

    if now - netdata.last_update > config.update_interval then
        update_network_stats()
        netdata.last_update = now
    end

    local flags = imgui.ImGuiWindowFlags_NoTitleBar +
                  imgui.ImGuiWindowFlags_AlwaysAutoResize +
                  imgui.ImGuiWindowFlags_NoScrollbar

    if not menu.is_open() then
        flags = flags + imgui.ImGuiWindowFlags_NoInputs +
                        imgui.ImGuiWindowFlags_NoMove
    end

    if imgui.begin("##NetworkOverlay", flags) then

        if netdata.cached_stats and #netdata.cached_stats > 0 then
            for _, line in ipairs(netdata.cached_stats) do
                imgui.text(line)
            end
        else
            imgui.text("Waiting for data...")
        end

        imgui["end"]()
    end
end

