shader_type spatial;

uniform vec4 color_1 : source_color = vec4(1.0, 1.0, 1.0, 1.0); // White
uniform vec4 color_2 : source_color = vec4(0.0, 0.4, 0.8, 1.0); // Blue
uniform float count = 10.0; // Number of stripes
uniform float speed = 0.0;  // Scrolling speed (set to 0 for static)

void fragment() {
    // 1. Create a repeating pattern along the X-axis (or Y-axis)
    // Adding TIME * speed makes the stripes move
    float stripes = fract((UV.x * count) + (TIME * speed));
    
    // 2. Use a step function to create a sharp cutoff at the 50% mark
    float mask = step(0.5, stripes);
    
    // 3. Mix the two colors based on that mask
    vec3 final_color = mix(color_1.rgb, color_2.rgb, mask);
    
    ALBEDO = final_color;
}