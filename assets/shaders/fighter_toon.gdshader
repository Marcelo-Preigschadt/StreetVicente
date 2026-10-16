shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 base_color : source_color = vec4(0.12, 0.14, 0.17, 1.0);
uniform sampler2D identity_texture : source_color, filter_linear_mipmap;
uniform bool use_identity = false;
uniform float hit_flash = 0.0;
uniform bool cloth = false;
varying vec3 model_normal;
void vertex() {
    model_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec3 n = normalize(model_normal);
    float light = dot(n, normalize(vec3(-0.35, 0.8, 0.7)));
    float band = light > 0.58 ? 1.40 : (light > 0.14 ? 1.02 : (light > -0.32 ? 0.67 : 0.35));
    vec3 color = base_color.rgb * band;
    if (use_identity) {
        // The approved face is sampled directly: no generated replacement.
        color = texture(identity_texture, UV).rgb;
    } else {
        // Fine material modulation breaks flat polygons without texture downloads.
        if (cloth) {
            float fold = sin(UV.y * 15.0 + sin(UV.x * 18.84) * 1.7);
            float crease = smoothstep(0.94, 0.995, fold) * sin(UV.x * 3.14159);
            color *= 1.0 - crease * 0.13;
        }
        float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 4.0);
        color += vec3(0.06, 0.085, 0.095) * rim;
    }
    ALBEDO = mix(color, vec3(1.0, 0.96, 0.83), hit_flash);
}
