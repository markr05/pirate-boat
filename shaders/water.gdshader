shader_type spatial;

render_mode depth_draw_always, blend_mix;

uniform float sync_time;

// 1. Add color uniforms so you can tweak them directly in the Godot Inspector
uniform vec3 deep_water_color : source_color = vec3(0.0, 0.2, 0.5);
uniform vec3 shallow_water_color : source_color = vec3(0.0, 0.6, 0.9);

// 2. Create a varying variable to pass the height data
varying float wave_height;

void vertex() {
    // Calculate the wave displacement separately
    float displacement = (sin(sync_time + VERTEX.x) * cos(sync_time + VERTEX.z)) * 0.5;
    
    // Apply the displacement to the Y axis
    VERTEX.y += displacement;
    
    // 3. Store the displacement in our varying variable
    wave_height = displacement;
}

void fragment() {
    // 4. Normalize the wave_height. 
    // Your displacement goes from roughly -0.5 (lowest) to 0.5 (highest).
    // Adding 0.5 shifts this math to a 0.0 to 1.0 range, which is perfect for blending colors.
    float blend_factor = wave_height + 0.5;
    
    // 5. Use the mix() function to blend the two colors based on the height
    ALBEDO = mix(deep_water_color, shallow_water_color, blend_factor);
    
    ALPHA = 0.90;
}