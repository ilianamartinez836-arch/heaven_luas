function on_paint()
    local nightIntensity = 70
    local v = (100.0 - nightIntensity) / 100.0
    local skyIntensity = 90
    local vSky = (100.0 - skyIntensity) / 100.0

    local materialsCache = materials.get_all()
    for _, matEntry in pairs(materialsCache) do
        local matPtr = matEntry.ptr
        if matPtr ~= 0 then
            local group = materials.get_texture_group(matPtr)
            if group and string.find(group, "World") then
                materials.color_modulate(matPtr, v, v, v)
            end
        end
    end
    
    for _, matEntry in pairs(materialsCache) do
        local name = matEntry.name
        local matPtr = matEntry.ptr
        if matPtr ~= 0 and name and string.match(name, "skybox/") then
            materials.color_modulate(matPtr, vSky, vSky, vSky)
            materials.alpha_modulate(matPtr, 1.0)
        end
    end
end
