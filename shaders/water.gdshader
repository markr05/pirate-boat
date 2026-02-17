shader_type spatial;

render_mode depth_draw_always, blend_mix;

uniform float sync_time;

void vertex() {
  // Move the Y position (up/down) based on time and the X/Z position
  VERTEX.y += (sin(sync_time + VERTEX.x) * cos(sync_time + VERTEX.z)) * 0.5;
}

void fragment() {
	// Called for every pixel the material is visible on.
	ALBEDO = vec3(0.0, 0.4, 0.8);
	
	ALPHA = 0.99;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
