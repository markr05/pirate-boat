// NOTE: Shader automatically converted from Godot Engine 4.6.stable's StandardMaterial3D.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Changed to a default leafy green
uniform vec4 albedo : source_color = vec4(0.15, 0.45, 0.15, 1.0); 

// --- NEW VARIANCE SETTINGS ---
// The secondary color to mix with your main albedo (e.g., a slightly more yellow green)
uniform vec4 albedo_variance : source_color = vec4(0.25, 0.55, 0.1, 1.0); 
varying vec3 instance_pos;
// -----------------------------

uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_enable;

// --- NOISE SETTINGS ---
uniform float noise_scale = 30.0;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.2;
// ----------------------

// --- PALM TREE WIND CONTROLS ---
uniform vec2 wind_direction = vec2(1.0, 0.5);
uniform float wind_speed : hint_range(0.0, 5.0) = 1.0;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.15;
// Set this to the approximate length of your leaf mesh in Godot units.
// It keeps the stem glued to the trunk while the tips blow in the wind.
uniform float leaf_length : hint_range(0.1, 10.0) = 2.0; 
// -------------------------

uniform float msdf_pixel_range : hint_range(1.0, 100.0, 1.0);
uniform float msdf_outline_size : hint_range(0.0, 250.0, 1.0);
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_nearest, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_nearest, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

uniform sampler2D texture_normal : hint_roughness_normal, filter_nearest, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0);

uniform vec4 transmittance_color : source_color;
uniform float transmittance_depth : hint_range(0.001, 8.0, 0.001);
uniform sampler2D texture_subsurface_transmittance : hint_default_white, filter_nearest, repeat_enable;
uniform float transmittance_boost : hint_range(0.0, 1.0, 0.01);

uniform vec4 backlight : source_color;
uniform sampler2D texture_backlight : hint_default_black, filter_nearest, repeat_enable;

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

// --- NOISE FUNCTIONS ---
// Generates a random value based on coordinates
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Generates smooth procedural value noise
float value_noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    
    // Smoothstep for softer transitions
    f = f * f * (3.0 - 2.0 * f); 
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
// -----------------------

void vertex() {
    UV = UV * uv1_scale.xy + uv1_offset.xy;
    
    // Save the mesh's origin position in the world to pass to the fragment shader
    instance_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    
    // 1. PIN THE STEM (Assuming the leaf's origin point is at the stem)
    float stiffness = clamp(length(VERTEX) / leaf_length, 0.0, 1.0);
    
    // 2. SYNC THE CANOPY
    float time = TIME * wind_speed;
    
    // 3. MACRO SWAY (The whole canopy bending)
    float sway_x = sin(time) * wind_strength;
    float sway_z = cos(time * 1.3) * wind_strength;
    
    // 4. MICRO FLUTTER (Gives the tips that chaotic, papery palm frond rustle)
    float flutter = sin(time * 3.0 + VERTEX.x * 3.0) * (wind_strength * 0.3);
    
    // 5. APPLY MOVEMENT (Multiplied by stiffness to protect the stems)
    VERTEX.x += (wind_direction.x * sway_x) * stiffness;
    VERTEX.z += (wind_direction.y * sway_z) * stiffness;
    
    // Palm fronds droop heavily downward under wind pressure
    VERTEX.y -= (abs(sway_x * 0.5) - flutter) * stiffness; 
}

float msdf_median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

void fragment() {
    vec2 base_uv = UV;

    vec4 albedo_tex = texture(texture_albedo, base_uv);

    {
        // Albedo Texture MSDF: Enabled
        if (!OUTPUT_IS_SRGB) {
            albedo_tex.rgb = mix(
                    vec3(1.0 + 0.055) * pow(albedo_tex.rgb, vec3(1.0 / 2.4)) - vec3(0.055),
                    vec3(12.92) * albedo_tex.rgb,
                    lessThan(albedo_tex.rgb, vec3(0.0031308)));
        }
        vec2 msdf_size = vec2(msdf_pixel_range) / vec2(albedo_texture_size);
        vec2 dest_size = vec2(1.0) / fwidth(base_uv);

        float px_size = max(0.5 * dot(msdf_size, dest_size), 1.0);
        float d = msdf_median(albedo_tex.r, albedo_tex.g, albedo_tex.b);
        if (msdf_outline_size > 0.0) {
            float cr = clamp(msdf_outline_size, 0.0, (msdf_pixel_range / 2.0) - 1.0) / msdf_pixel_range;
            d = min(d, albedo_tex.a);
            albedo_tex.a = clamp((d - 0.5 + cr) * px_size, 0.0, 1.0);
        } else {
            albedo_tex.a = clamp((d - 0.5) * px_size + 0.5, 0.0, 1.0);
        }
        albedo_tex.rgb = vec3(1.0);
    }
    
    // Generate a random float based on world position and mix the colors
    float random_val = fract(sin(dot(instance_pos.xz, vec2(12.9898, 78.233))) * 43758.5453);
    vec3 mixed_color = mix(albedo.rgb, albedo_variance.rgb, random_val);
    
    // Generate the procedural surface noise
    float surface_noise = value_noise(base_uv * noise_scale);
    
    // Combine the instance color with your base texture
    vec3 final_color = mixed_color * albedo_tex.rgb;
    
    // Apply the noise texture to the final color
    // We multiply surface_noise by 1.5 to make the lighter parts pop a bit more before mixing
    final_color = mix(final_color, final_color * surface_noise * 1.5, noise_strength);
    
    ALBEDO = final_color;

    float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
    METALLIC = metallic_tex * metallic;
    SPECULAR = specular;

    vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
    float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
    ROUGHNESS = roughness_tex * roughness;

    // Normal Map: Enabled
    NORMAL_MAP = texture(texture_normal, base_uv).rgb;
    NORMAL_MAP_DEPTH = normal_scale;

    // Subsurface Scattering Transmittance: Enabled
    vec4 trans_color_tex = texture(texture_subsurface_transmittance, base_uv);
    SSS_TRANSMITTANCE_COLOR = transmittance_color * trans_color_tex;
    SSS_TRANSMITTANCE_DEPTH = transmittance_depth;
    SSS_TRANSMITTANCE_BOOST = transmittance_boost;

    // Backlight: Enabled
    vec3 backlight_tex = texture(texture_backlight, base_uv).rgb;
    BACKLIGHT = (backlight.rgb + backlight_tex);
}