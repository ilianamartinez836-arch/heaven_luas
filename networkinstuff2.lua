client.print("Network Overlay Loaded")

local netdata = {
    last_update = 0,
    cached_stats = {}
}

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

    netdata.cached_stats = {
     --   string.format("Server: %s (%s)", serverName, serverAddress),
		string.format("Server: %s",  serverAddress),
        string.format("Latency Out/In: %.1f / %.1f ms", net.latency_out * 1000, net.latency_in * 1000),
        string.format("Loss: %.2f%% | Choke: %.2f%%", net.loss_out * 100, net.choke_out * 100),
        string.format("Rate: %.1f KB/s Out | %.1f KB/s In", net.data_out / 1024, net.data_in / 1024),
        string.format("Packets: %.1f/s Out | %.1f/s In", net.packets_out, net.packets_in),
        string.format("Total Data: %.2f MB Out | %.2f MB In", net.total_data_out / 1024 / 1024, net.total_data_in / 1024 / 1024),
        string.format("Connected: %.1fs", net.time_connected),
        string.format("Timeout: %.1fs | Timing Out: %s", net.timeout_seconds, tostring(net.is_timing_out))
    }
end

function on_end_scene()
    local now = os.clock()
    if now - netdata.last_update > 1.0 then
        update_network_stats()
        netdata.last_update = now
    end

    if imgui.begin("Network Info", 0) then
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



