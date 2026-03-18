shader_type spatial;
// Added diffuse_burley for softer, more natural light scattering on foliage
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Adjusted to slightly more natural, less "neon" greens
uniform vec3 grass_color : source_color = vec3(0.25, 0.65, 0.15); 
uniform vec3 tint_color : source_color = vec3(0.45, 0.85, 0.25);  
uniform float variation_amount : hint_range(0.0, 1.0) = 0.6;

// Wind controls
uniform float wind_speed = 1.5;
uniform float wind_strength = 0.15;

// Fake Subsurface Scattering: Makes grass glow slightly when backlit by the sun
uniform vec3 backlight_color : source_color = vec3(0.35, 0.75, 0.20);

// A simple hash function to generate a random-ish value from a position
float hash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

// Pass values from vertex to fragment
varying float v_noise; 
varying float v_height; // <--- The crucial fix for the darkness!

void vertex() {
    // Save the local Y height BEFORE we manipulate it, so the fragment shader can use it
    v_height = clamp(VERTEX.y, 0.0, 1.0);
    float height_factor = max(0.0, VERTEX.y);
    
    // Calculate a unique random value for this specific grass instance
    v_noise = hash(NODE_POSITION_WORLD);
    
    // We use v_noise to offset the wind wave too, so they don't all sway in sync
    float wave = sin(TIME * wind_speed + (NODE_POSITION_WORLD.x + NODE_POSITION_WORLD.z) + v_noise * 10.0);
    
    VERTEX.x += wave * wind_strength * height_factor;
    VERTEX.z += wave * wind_strength * height_factor * 0.5;
    
    // NEW: Push the grass down slightly as it bends so it doesn't look stretched
    VERTEX.y -= abs(wave) * wind_strength * height_factor * 0.5;
}

void fragment() {
    // Mix between the base color and the tint color based on the instance noise
    vec3 final_color = mix(grass_color, tint_color, v_noise * variation_amount);
    
    // Apply the bottom-darkening using our VARYING height, not the view-space VERTEX.y
    // I bumped the dark end from 0.5 up to 0.6 to keep it from getting too black
    final_color *= mix(0.6, 1.0, v_height);
    
    ALBEDO = final_color;
    
    // Foliage shouldn't look like shiny plastic; lower specular and raise roughness
    ROUGHNESS = 0.85;
    SPECULAR = 0.1;
    
    // Apply the backlight effect for that lush, sunlit look
    BACKLIGHT = backlight_color;
}