shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

/* ------------ Controls (no hints) ------------ */
uniform bool  USE_TRIPLANAR = true;

/* Per-layer tiling */
uniform float uv_tile_grass = 8.0;
uniform float uv_tile_dirt  = 6.0;
uniform float uv_tile_rock  = 5.0;  // your “B” layer
uniform float uv_tile_path  = 7.0;  // your “A” layer
uniform float uv_tile_fifth = 5.0;  // extra layer

/* Surface */
uniform float normal_strength = 0.0;     // set >0 only if normal maps provided
uniform float base_ambient_occlusion = 0.1;

/* Albedo textures (assign in material) */
uniform sampler2D grass_tex;  // R
uniform sampler2D dirt_tex;   // G
uniform sampler2D rock_tex;   // B
uniform sampler2D path_tex;   // A

/* Optional normal maps (flat normal if none) */
uniform sampler2D grass_nrm;
uniform sampler2D dirt_nrm;
uniform sampler2D rock_nrm;
uniform sampler2D path_nrm;

/* Material params */
uniform float rough_grass = 0.4;
uniform float rough_dirt  = 0.9;
uniform float rough_rock  = 0.7;
uniform float rough_path  = 0.6;

uniform vec3 tint_grass = vec3(0.90, 1.00, 0.90);
uniform vec3 tint_dirt  = vec3(1.00, 0.95, 0.85);
uniform vec3 tint_rock  = vec3(1.00, 1.00, 1.00);
uniform vec3 tint_path  = vec3(1.00, 1.00, 1.00);

/* Fifth layer: 0=off, 1=procedural (slope/height), 2=leftover (1 - RGBA sum) */
uniform int   FIFTH_MODE = 1;
uniform sampler2D fifth_tex;
uniform sampler2D fifth_nrm;
uniform float rough_fifth = 0.8;
uniform vec3  tint_fifth  = vec3(0.90, 0.90, 0.90);

/* Procedural (for FIFTH_MODE=1) */
uniform bool  USE_SLOPE  = true;
uniform float slope_start = 0.55;   // begin blending
uniform float slope_end   = 0.80;   // full blend
uniform bool  USE_HEIGHT  = false;
uniform float height_start = 5.0;   // object-space Y
uniform float height_end   = 20.0;

/* ------------ Varyings (object-space) ------------ */
varying vec3 v_obj_pos;
varying vec3 v_obj_norm;

void vertex() {
    // Object-space pass-through (robust on any Godot 4 build; no WORLD/MODEL identifiers needed)
    v_obj_pos  = VERTEX;
    v_obj_norm = NORMAL;
}

/* ------------ Helpers ------------ */
vec3 unpack_normal(vec3 n) {
    // Expecting a standard tangent-space normal map in RGB (0..1)
    n = n * 2.0 - 1.0;
    n.xy *= max(0.0001, normal_strength);
    return normalize(n);
}

vec4 triplanar_texture(sampler2D tex, vec3 pos, vec3 nrm, float tile) {
    vec3 w = abs(normalize(nrm));
    w = max(w, vec3(0.0001));
    w /= (w.x + w.y + w.z);

    vec2 ux = pos.zy * tile;
    vec2 uy = pos.xz * tile;
    vec2 uz = pos.xy * tile;

    vec4 tx = texture(tex, ux);
    vec4 ty = texture(tex, uy);
    vec4 tz = texture(tex, uz);

    return tx * w.x + ty * w.y + tz * w.z;
}

vec3 triplanar_normal(sampler2D tex, vec3 pos, vec3 nrm, float tile) {
    vec3 w = abs(normalize(nrm));
    w = max(w, vec3(0.0001));
    w /= (w.x + w.y + w.z);

    vec2 ux = pos.zy * tile;
    vec2 uy = pos.xz * tile;
    vec2 uz = pos.xy * tile;

    vec3 nx = unpack_normal(texture(tex, ux).xyz);
    vec3 ny = unpack_normal(texture(tex, uy).xyz);
    vec3 nz = unpack_normal(texture(tex, uz).xyz);

    return normalize(nx * w.x + ny * w.y + nz * w.z);
}

/* ------------ Fragment ------------ */
void fragment() {
    // RGBA vertex-color mask from Blender
    vec4 mask = max(COLOR, vec4(0.0));
    float sum4 = max(0.0001, mask.r + mask.g + mask.b + mask.a);
    vec4  w4   = mask / sum4;

    // Sample 4 painted layers
    vec4 cR, cG, cB, cA; vec3 nR, nG, nB, nA;

    if (USE_TRIPLANAR) {
        cR = triplanar_texture(grass_tex, v_obj_pos, v_obj_norm, uv_tile_grass);
        cG = triplanar_texture(dirt_tex,  v_obj_pos, v_obj_norm, uv_tile_dirt);
        cB = triplanar_texture(rock_tex,  v_obj_pos, v_obj_norm, uv_tile_rock);
        cA = triplanar_texture(path_tex,  v_obj_pos, v_obj_norm, uv_tile_path);

        nR = triplanar_normal(grass_nrm, v_obj_pos, v_obj_norm, uv_tile_grass);
        nG = triplanar_normal(dirt_nrm,  v_obj_pos, v_obj_norm, uv_tile_dirt);
        nB = triplanar_normal(rock_nrm,  v_obj_pos, v_obj_norm, uv_tile_rock);
        nA = triplanar_normal(path_nrm,  v_obj_pos, v_obj_norm, uv_tile_path);
    } else {
        vec2 uR = UV * uv_tile_grass;
        vec2 uG = UV * uv_tile_dirt;
        vec2 uB = UV * uv_tile_rock;
        vec2 uA = UV * uv_tile_path;

        cR = texture(grass_tex, uR);
        cG = texture(dirt_tex,  uG);
        cB = texture(rock_tex,  uB);
        cA = texture(path_tex,  uA);

        nR = unpack_normal(texture(grass_nrm, uR).xyz);
        nG = unpack_normal(texture(dirt_nrm,  uG).xyz);
        nB = unpack_normal(texture(rock_nrm,  uB).xyz);
        nA = unpack_normal(texture(path_nrm,  uA).xyz);
    }

    // Tints
    cR.rgb *= tint_grass;
    cG.rgb *= tint_dirt;
    cB.rgb *= tint_rock;
    cA.rgb *= tint_path;

    // Blend 4 layers
    vec3 albedo4 = cR.rgb * w4.r + cG.rgb * w4.g + cB.rgb * w4.b + cA.rgb * w4.a;
    vec3 n4      = normalize(nR * w4.r + nG * w4.g + nB * w4.b + nA * w4.a);
    float rough4 = rough_grass * w4.r + rough_dirt * w4.g + rough_rock * w4.b + rough_path * w4.a;

    // Fifth weight
    float w5 = 0.0;
    if (FIFTH_MODE == 1) {
        // Procedural: slope/height in OBJECT space
        float slope = 1.0 - abs(dot(normalize(v_obj_norm), vec3(0.0, 1.0, 0.0))); // 0 flat, 1 steep
        float ws = USE_SLOPE ? smoothstep(slope_start, slope_end, slope) : 0.0;

        float h  = v_obj_pos.y;
        float wh = USE_HEIGHT ? smoothstep(height_start, height_end, h) : 0.0;

        w5 = max(ws, wh);
    } else if (FIFTH_MODE == 2) {
        // Leftover
        float total = clamp(mask.r + mask.g + mask.b + mask.a, 0.0, 1.0);
        w5 = max(0.0, 1.0 - total);
    }

    // Sample fifth layer
    vec4 c5; vec3 n5;
    if (USE_TRIPLANAR) {
        c5 = triplanar_texture(fifth_tex, v_obj_pos, v_obj_norm, uv_tile_fifth);
        n5 = triplanar_normal(fifth_nrm, v_obj_pos, v_obj_norm, uv_tile_fifth);
    } else {
        vec2 u5 = UV * uv_tile_fifth;
        c5 = texture(fifth_tex, u5);
        n5 = unpack_normal(texture(fifth_nrm, u5).xyz);
    }
    c5.rgb *= tint_fifth;

    // Apply fifth on top
    float w5c = clamp(w5, 0.0, 1.0);
    vec3  albedo = mix(albedo4, c5.rgb, w5c);
    vec3  n_tan  = normalize(mix(n4, n5, w5c));
    float rough  = mix(rough4, rough_fifth, w5c);

    // Outputs
    ALBEDO     = albedo;
    NORMAL_MAP = n_tan;
    ROUGHNESS  = clamp(rough, 0.0, 1.0);
    AO         = base_ambient_occlusion;
    SPECULAR   = 0.5;
    METALLIC   = 0.0;
    ALPHA      = 1.0;
}

