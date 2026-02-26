shader_type spatial;
render_mode cull_disabled; // Ensures you can see the back of the flat triangle

uniform vec3 grass_color : source_color = vec3(0.5, 0.6, 0.2);
uniform float wind_speed = 1.5;
uniform float wind_strength = 0.1; // Keep this low so the triangle doesn't warp too much

void vertex() {
    // We use the local Y position of the vertex to calculate the sway weight.
    // Assuming the base of your triangle is at Y=0, this keeps the roots totally still.
    // max() ensures that if any part of the mesh dips below 0, it doesn't sway backward.
    float height_factor = max(0.0, VERTEX.y);
    
    // Create a smooth wind wave using time and the object's world position.
    // NODE_POSITION_WORLD ensures that different patches of grass sway at slightly different times.
    float wave = sin(TIME * wind_speed + NODE_POSITION_WORLD.x + NODE_POSITION_WORLD.z);
    
    // Apply the movement to X and Z axes, multiplied by how high up the vertex is.
    VERTEX.x += wave * wind_strength * height_factor;
    VERTEX.z += wave * wind_strength * height_factor * 0.5; // Offset the Z slightly for a natural diagonal breeze
}

void fragment() {
    ALBEDO = grass_color;
    
    // Optional: Make the bottom of the grass slightly darker for fake ambient occlusion
     ALBEDO *= mix(0.5, 1.0, clamp(VERTEX.y, 0.0, 1.0));
}