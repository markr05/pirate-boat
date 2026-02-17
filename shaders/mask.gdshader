shader_type spatial;
// 'render_priority' ensures the mask is calculated BEFORE the water
// 'depth_test_disabled' is usually False, we want it to check depth!
render_mode unshaded, depth_draw_always;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;

void fragment() {
    // Grabs what is ALREADY drawn (the boat floor/walls) 
    // and paints it onto the "hole" in the water.
    vec3 screen_color = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;
    ALBEDO = screen_color;
}