-- Material Dumper using on_find_material hook
-- Dumps all materials in "World textures" group

local dump_dir = "C:\\Materials"
local dump_file = dump_dir .. "\\world_textures_dump.txt"
local materials_found = {}
local material_count = 0

function on_find_material(material_name, texture_group)
    if texture_group and string.find(texture_group, "World textures") then
        if not materials_found[material_name] then
            materials_found[material_name] = texture_group
            material_count = material_count + 1
            
            if material_count % 100 == 0 then
                client.print("[Material Dumper] Found " .. material_count .. " World textures materials...")
            end
            
            if material_count == 1 then
                if file.create_directory then
                    file.create_directory(dump_dir)
                end
            end
            
            local output = "=== WORLD TEXTURES MATERIALS DUMP ===\n"
            output = output .. "Generated: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
            output = output .. "==========================================\n\n"
            
            local count = 0
            for mat_name, tex_group in pairs(materials_found) do
                count = count + 1
                output = output .. string.format("[%d] Material: %s\n", count, mat_name)
                output = output .. string.format("    Group: %s\n\n", tex_group)
            end
            
            output = output .. "==========================================\n"
            output = output .. string.format("Total World textures materials found: %d\n", count)
            
            if file.write then
                file.write(dump_file, output)
            end
        end
    end
    
    return nil
end

client.print("[Material Dumper] Script loaded - will collect World textures materials on map load")
client.print("[Material Dumper] Join a game to start collecting materials...")
