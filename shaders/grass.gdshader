shader_type spatial;
render_mode cull_disabled;

uniform vec3 grass_color : source_color = vec3(0.5, 0.6, 0.2);
uniform vec3 tint_color : source_color = vec3(0.4, 0.5, 0.1); // The "alternative" grass color
uniform float variation_amount : hint_range(0.0, 1.0) = 0.3; // How much to mix the tint
uniform float wind_speed = 1.5;
uniform float wind_strength = 0.1;

// A simple hash function to generate a random-ish value from a position
float hash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

varying float v_noise; // Pass a value from vertex to fragment

void vertex() {
    float height_factor = max(0.0, VERTEX.y);
    
    // Calculate a unique random value for this specific grass instance
    v_noise = hash(NODE_POSITION_WORLD);
    
    // We use v_noise to offset the wind wave too, so they don't all sway in sync!
    float wave = sin(TIME * wind_speed + (NODE_POSITION_WORLD.x + NODE_POSITION_WORLD.z) + v_noise * 10.0);
    
    VERTEX.x += wave * wind_strength * height_factor;
    VERTEX.z += wave * wind_strength * height_factor * 0.5;
}

void fragment() {
    // Mix between the base color and the tint color based on the instance noise
    vec3 final_color = mix(grass_color, tint_color, v_noise * variation_amount);
    
    ALBEDO = final_color;
    
    // Maintain the bottom-darkening effect
    ALBEDO *= mix(0.5, 1.0, clamp(VERTEX.y, 0.0, 1.0));
}