shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

// --- Lethal Company Settings ---
uniform int pixel_size = 4;
uniform float color_levels = 8.0;
uniform float brightness = 1.1;

// --- Water Settings (Now part of the same shader!) ---
uniform vec4 blue_tint : source_color = vec4(0.0, 0.4, 0.8, 0.0); // Keep Alpha at 0.0 by default
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.02;

void fragment() {
    vec2 tex_size = vec2(textureSize(SCREEN_TEXTURE, 0));
    vec2 grid_uv = round(SCREEN_UV * (tex_size / float(pixel_size))) / (tex_size / float(pixel_size));
    
    // ONLY distort if alpha is actually being used
    if (blue_tint.a > 0.01) {
        grid_uv.x += sin(TIME * 2.0 + grid_uv.y * 10.0) * distortion_strength;
    }

    vec4 screen_color = texture(SCREEN_TEXTURE, grid_uv);
    
    // Posterization (Always active for that Lethal look)
    screen_color.rgb = floor(screen_color.rgb * color_levels) / color_levels;
    screen_color.rgb *= brightness;
    
    // ONLY tint if alpha is active
    if (blue_tint.a > 0.01) {
        vec3 water_blend = screen_color.rgb * blue_tint.rgb;
        screen_color.rgb = mix(screen_color.rgb, water_blend, blue_tint.a);
    }
    
    COLOR = screen_color;
}