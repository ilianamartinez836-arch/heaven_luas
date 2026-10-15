function on_get_fog_color(fog, color)
    fog.start = -1.0
    fog.max_density = 0.0 

    color[1] = 0.1
    color[2] = 0.1
    color[3] = 0.1

    return fog, color
end

