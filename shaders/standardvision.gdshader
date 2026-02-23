shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

// Pixelation
uniform int pixel_size = 4; // Higher = more "crunchy"

// Color Grading
uniform float color_levels = 8.0; // Fewer levels = more retro banding
uniform float brightness = 1.1;

void fragment() {
    // We use 1.0 / SCREEN_PIXEL_SIZE to get the actual resolution (e.g., 1920, 1080)
    vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
    
    // Calculate the size of the "big" pixels
    vec2 grid_uv = floor(SCREEN_UV * res / float(pixel_size)) / (res / float(pixel_size));
    
    // Use the grid_uv to sample the screen
    vec4 screen_color = texture(SCREEN_TEXTURE, grid_uv);
    
    // Posterization & Brightness
    screen_color.rgb = floor(screen_color.rgb * color_levels) / color_levels;
    screen_color.rgb *= brightness;
    
    COLOR = screen_color;
}