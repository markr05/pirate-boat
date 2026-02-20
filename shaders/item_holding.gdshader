shader_type spatial;
render_mode unshaded, depth_test_disabled; // This is the magic line

uniform sampler2D albedo_texture : source_color;

void fragment() {
    vec4 tex = texture(albedo_texture, UV);
    ALBEDO = tex.rgb;
    ALPHA = tex.a;
}
//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
