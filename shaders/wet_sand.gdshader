shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// --- Uniforms (Tweak these in the Inspector) ---
uniform sampler2D sand_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float water_level = 10.0;           // The Y-level where water starts
uniform float wetness_fade = 3.0;           // How many meters it takes to reach maximum darkness
uniform float darkness_multiplier = 0.3;    // 1.0 is no change, 0.0 is pitch black

// --- Varyings (Passing data from Vertex to Fragment) ---
varying float v_world_y;

void vertex() {
	// Grab the absolute World Y position of the terrain vertex
	v_world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	// 1. Get the base color of your sand texture
	// (Multiplying UV by a number like 10.0 scales the texture so it isn't massive)
	vec4 base_color = texture(sand_texture, UV * 10.0);
	
	// 2. Calculate how far below the water level we are
	// If world_y is 8 and water is 10, depth is +2.
	// If world_y is 15 and water is 10, depth is -5.
	float depth = water_level - v_world_y;
	
	// 3. Create a mask from 0.0 (dry) to 1.0 (fully dark/underwater)
	// clamp() ensures the mask never goes below 0 or above 1
	float mask = clamp(depth / wetness_fade, 0.0, 1.0);
	
	// 4. Apply the darkening
	// mix() blends between normal brightness (1.0) and our darkness_multiplier
	ALBEDO = base_color.rgb * mix(1.0, darkness_multiplier, mask);
	
	// Optional: Make the wet sand look less rough/more shiny
	ROUGHNESS = mix(0.9, 0.3, mask);
	SPECULAR = mix(0.1, 0.5, mask);
}