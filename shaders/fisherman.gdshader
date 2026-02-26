shader_type spatial;

uniform float speed : hint_range(0.0, 5.0) = 0.4;
uniform float frequency : hint_range(0.0, 5.0) = 1.0;

// Helper function to convert Hue to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    // 1. Calculate the hue based on time and the mesh's UV coordinates
    // Adding 'UV.x' makes the rainbow stretch across the surface
    float hue = fract(TIME * speed + UV.x * frequency);
    
    // 2. Convert that hue to a full Saturation (1.0) and Value (1.0) RGB color
    vec3 rainbow = hsv2rgb(vec3(hue, 1.0, 1.0));
    
    // 3. Assign to Albedo
    ALBEDO = rainbow;
    
    // Optional: Make it glow!
    EMISSION = rainbow * 0.5;
}