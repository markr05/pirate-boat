shader_type spatial;

render_mode blend_mix, diffuse_lambert, specular_schlick_ggx;

uniform vec3 deep_water_color : source_color = vec3(0.0, 0.2, 0.5);
uniform vec3 shallow_water_color : source_color = vec3(0.0, 0.6, 0.9);

// Controls
uniform float wave_height_scale : hint_range(0.0, 2.0) = 0.05; 
uniform float wave_speed : hint_range(0.0, 5.0) = 0.8;        
uniform float wave_frequency : hint_range(0.0, 10.0) = 4.0;

varying float v_height;

void vertex() {
    // 1. Get world position
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // 2. Calculate the wave height (Displacement)
    float time_speed = TIME * wave_speed;
    float wave_x = world_pos.x * wave_frequency;
    float wave_z = world_pos.z * wave_frequency;
    
    float height = sin(time_speed + wave_x) * cos(time_speed + wave_z) * wave_height_scale;
    
    // Move the vertex up/down
    VERTEX.y += height;
    v_height = height;

    // 3. THE OPTIMIZATION: Analytical Normals
    // Instead of sampling neighbors, we calculate the exact mathematical slope.
    // This is infinitely faster and removes the lag.
    float dx = cos(time_speed + wave_x) * cos(time_speed + wave_z) * wave_frequency * wave_height_scale;
    float dz = sin(time_speed + wave_x) * -sin(time_speed + wave_z) * wave_frequency * wave_height_scale;
    
    // Build the normal and convert it to View Space for Godot's lighting
    vec3 world_normal = normalize(vec3(-dx, 1.0, -dz));
    NORMAL = (VIEW_MATRIX * vec4(world_normal, 0.0)).xyz;
}

void fragment() {
    // Blend colors based on height
    float blend = clamp((v_height / wave_height_scale) * 0.5 + 0.5, 0.0, 1.0);
    ALBEDO = mix(deep_water_color, shallow_water_color, blend);
    
    // Water properties
    ROUGHNESS = 0.05;
    SPECULAR = 0.5;
    ALPHA = 0.95;
}