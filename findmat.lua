--heaven 1.0.3
--your vmt should be this shit:
--"UnlitGeneric"
--{
--    "$basetexture" "customsky/lain"
--}
-- all in materials/customsky
-- both vtf and vmt
-- u can change the path to whatever u want, but make sure is correct
function on_draw_model_execute(model_info)
    if string.find(model_info.model_name, "v_models") then
        local mat2 = materials.find("customsky/customMAT", "Model textures")
        if mat2 then
            mat2:add_ref() 
        end
    end
end

function on_find_material(material_name, texture_group)
    -- Replace skybox materials
    if string.find(material_name, "skybox/") then
       return "customsky/customMAT"
    end
    -- Replace world textures
    if texture_group and string.find(texture_group, "World textures") then
   --     return "dev/graygrid"
      return "customsky/customMAT"
    end
    
    -- Return nil to use original material uwu
    return nil
end



