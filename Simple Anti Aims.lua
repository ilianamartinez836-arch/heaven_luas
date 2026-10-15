client.print("=== Tickrate Test ===")

local function test_value(name, func)
    local ok, result = pcall(func)

    if ok then
        if result ~= nil then
            client.print(string.format("[OK] %s = %s", name, tostring(result)))
            return result
        else
            client.print(string.format("[NIL] %s", name))
        end
    else
        client.print(string.format("[ERROR] %s", name))
    end

    return nil
end

local function test_tickrate()
    client.print("Testing tickrate functions...")

    -- Test 1
    local interval = test_value(
        "engine.get_tick_interval()",
        function()
            return engine.get_tick_interval()
        end
    )

    if interval and interval > 0 then
        local tickrate = 1 / interval

        client.print(string.format(
            "[FOUND] Tick Interval: %.6f",
            interval
        ))

        client.print(string.format(
            "[FOUND] Tickrate: %.2f",
            tickrate
        ))
    end

    -- Test 2
    local interval2 = test_value(
        "engine.tick_interval",
        function()
            return engine.tick_interval
        end
    )

    if interval2 and interval2 > 0 then
        client.print(string.format(
            "[FOUND] engine.tick_interval: %.6f",
            interval2
        ))

        client.print(string.format(
            "[FOUND] Tickrate: %.2f",
            1 / interval2
        ))
    end

    -- Test 3
    local tickrate = test_value(
        "engine.get_tickrate()",
        function()
            return engine.get_tickrate()
        end
    )

    if tickrate and tickrate > 0 then
        client.print(string.format(
            "[FOUND] Direct Tickrate: %.2f",
            tickrate
        ))
    end

    client.print("=== Tickrate Test Finished ===")
end

test_tickrate()
