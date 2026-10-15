-- Initialize default key
if client.get_shared_bool("example_initialized", nil) == nil then
    client.set_shared_int("my_key", keys.KEY_E)
    client.set_shared_bool("example_initialized", true)
end

-- Key names for display
local key_names = {
    [keys.MOUSE1]="MOUSE1",[keys.MOUSE2]="MOUSE2",[keys.MOUSE3]="MOUSE3",
    [keys.MOUSE4]="MOUSE4",[keys.MOUSE5]="MOUSE5",
    [keys.KEY_A]="A",[keys.KEY_B]="B",[keys.KEY_C]="C",[keys.KEY_D]="D",
    [keys.KEY_E]="E",[keys.KEY_F]="F",[keys.KEY_G]="G",[keys.KEY_H]="H",
    [keys.KEY_I]="I",[keys.KEY_J]="J",[keys.KEY_K]="K",[keys.KEY_L]="L",
    [keys.KEY_M]="M",[keys.KEY_N]="N",[keys.KEY_O]="O",[keys.KEY_P]="P",
    [keys.KEY_Q]="Q",[keys.KEY_R]="R",[keys.KEY_S]="S",[keys.KEY_T]="T",
    [keys.KEY_U]="U",[keys.KEY_V]="V",[keys.KEY_W]="W",[keys.KEY_X]="X",
    [keys.KEY_Y]="Y",[keys.KEY_Z]="Z",
    [keys.SPACE]="SPACE",[keys.SHIFT]="SHIFT",[keys.CTRL]="CTRL",[keys.ALT]="ALT",
    [keys.ESCAPE]="ESC"
}

local waiting_for_key = false
local keybind_target = nil

-- Handles the popup window and key capture
function on_end_scene()
    if waiting_for_key and keybind_target then
        if not imgui.begin("Keybind", 0) then
            waiting_for_key = false
            keybind_target = nil
            return
        end
        imgui.text("Press any key for " .. keybind_target .. "...")
        imgui.text("Press ESC to cancel")
        imgui["end"]()

        for key, name in pairs(key_names) do
            if input.is_key_pressed(key) then
                if key == keys.ESCAPE then
                    waiting_for_key = false
                    keybind_target = nil
                else
                    client.set_shared_int(keybind_target, key)
                    client.print("Bound " .. keybind_target .. " to " .. name)
                    waiting_for_key = false
                    keybind_target = nil
                end
                break
            end
        end
    end
end

-- Example: do something when the bound key is held
function on_create_move(cmd, lp)
    if not cmd or not lp or not lp:is_alive() then return end
    if waiting_for_key then return end

    local my_key = client.get_shared_int("my_key", keys.KEY_E)

    if input.is_key_down(my_key) then
        client.print("Key is held!")
        -- your logic here
    end
end

-- Menu with keybind button
menu.add_main_tab("Example", function()
    local cur_key = client.get_shared_int("my_key", keys.KEY_E)
    local key_name = key_names[cur_key] or "NONE"

    -- Button label changes while waiting for input
    local btn_label = (waiting_for_key and keybind_target == "my_key") and "Press any key..." or key_name

    if imgui.button(btn_label .. "##my_key") then
        waiting_for_key = true
        keybind_target = "my_key"
    end
    imgui.same_line()
    imgui.text("My Key (hold)")
end)