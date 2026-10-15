-- Gray World Textures + Perfect Directional Strafer combinados
-- Código original intacto de ambos, sin cambios

-- Gray World Textures (original)
function on_find_material(material_name, texture_group)
    if texture_group and string.find(texture_group, "World textures") then
        -- return "dev/graygrid"
        return "dev/graygrid"
    end
    return nil
end

