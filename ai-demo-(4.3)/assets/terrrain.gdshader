shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// 3 grass-ish textures for low / mid / high
uniform sampler2D grass_low_tex;
uniform sampler2D grass_mid_tex;
uniform sampler2D grass_high_tex;

// Tiling for each texture
uniform float grass_low_tile  = 6.0;
uniform float grass_mid_tile  = 8.0;
uniform float grass_high_tile = 10.0;

// World-space height range of your terrain (in meters/units)
uniform float min_height = 0.0;   // lowest point of terrain in world Y
uniform float max_height = 10.0;  // highest point of terrain in world Y

// Thresholds in *normalized* height [0..1]
uniform float low_end     = 0.3;   // end of low layer band
uniform float high_start  = 0.7;   // start of high layer band
uniform float blend_width = 0.1;   // softness of transitions in 0..1

// Debug switches
uniform bool DEBUG_MASK   = false;  // show R/G/B weights
uniform bool DEBUG_HEIGHT = false;  // show grayscale height

// pass normalized height from vertex -> fragment
varying float v_h01;

void vertex() {
    // World-space Y so it still works if terrain is moved/rotated
    float world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;

    // Normalize to 0..1 based on min_height/max_height
    float h01 = (world_y - min_height) / max(0.0001, (max_height - min_height));
    v_h01 = clamp(h01, 0.0, 1.0);
}

void fragment() {
    float h = v_h01; // 0..1 height

    // --- compute blend weights from normalized height ---

    // low layer: strong at low heights, fades out near low_end
    float low_s = smoothstep(low_end - blend_width, low_end + blend_width, h);
    float w_low = 1.0 - low_s;

    // high layer: fades in near high_start
    float w_high = smoothstep(high_start - blend_width, high_start + blend_width, h);

    // mid layer: whatever is left between them
    float w_mid = 1.0 - w_low - w_high;

    // clamp + normalize
    w_low  = clamp(w_low,  0.0, 1.0);
    w_mid  = clamp(w_mid,  0.0, 1.0);
    w_high = clamp(w_high, 0.0, 1.0);

    float sum = max(w_low + w_mid + w_high, 0.0001);
    w_low  /= sum;
    w_mid  /= sum;
    w_high /= sum;

    vec3 albedo;

    // --- debug: show height as grayscale ---
    if (DEBUG_HEIGHT) {
        albedo = vec3(h);
    }
    // --- debug: show weights as RGB ---
    else if (DEBUG_MASK) {
        // R = low, G = mid, B = high
        albedo = vec3(w_low, w_mid, w_high);
    }
    // --- normal textured mode ---
    else {
        // sample the 3 textures
        vec2 uv_low  = UV * grass_low_tile;
        vec2 uv_mid  = UV * grass_mid_tile;
        vec2 uv_high = UV * grass_high_tile;

        vec3 col_low  = texture(grass_low_tex,  uv_low).rgb;
        vec3 col_mid  = texture(grass_mid_tex,  uv_mid).rgb;
        vec3 col_high = texture(grass_high_tex, uv_high).rgb;

        albedo = col_low * w_low + col_mid * w_mid + col_high * w_high;
    }

    ALBEDO    = albedo;
    ROUGHNESS = 1.0;
    METALLIC  = 0.0;
}

