shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D bed_depth : filter_linear, repeat_disable;
uniform float water_time = 0.0;
uniform float radius = 11.62;
uniform float max_depth = 4.0;
uniform vec3 berth_normal = vec3(0.0,-1.0,0.0);
uniform vec4 ripples[4];
uniform vec4 ripple_strength = vec4(0.0);
varying vec3 radial;

float depth_at(vec3 n) {
    vec2 uv = vec2(atan(n.z, n.x) / TAU + 0.5, acos(clamp(n.y,-1.0,1.0)) / PI);
    uv = (uv * vec2(128.0,64.0) + 0.5) / vec2(129.0,65.0);
    return texture(bed_depth,uv).r * max_depth;
}

float swell(vec3 n) {
    vec3 p = n * radius;
    return 0.026 * sin(dot(p, vec3(0.78, 0.18, 0.60)) * 1.45 - water_time * 0.85)
         + 0.014 * sin(dot(p, vec3(-0.32, 0.71, 0.63)) * 2.4 + water_time * 0.65);
}
void vertex() {
    radial = normalize(VERTEX);
    VERTEX = radial * (radius + swell(radial));
    NORMAL = radial;
}
void fragment() {
    vec3 n = normalize(radial);
    vec3 p = n * radius;
    vec3 a = vec3(0.78, 0.18, 0.60);
    vec3 b = vec3(-0.32, 0.71, 0.63);
    vec3 c = vec3(0.80, 0.11, -0.59);
    vec3 d = vec3(0.22, 0.89, 0.40);
    float pa = dot(p, a) * 1.45 - water_time * 0.85;
    float pb = dot(p, b) * 2.4 + water_time * 0.65;
    float pc = dot(p, c) * 7.0 + water_time * 1.6 + sin(dot(p,a)*1.2+water_time*.18)*2.3 + sin(pb*.55)*1.1;
    float pd = dot(p, d) * 10.0 - water_time * 1.15 + sin(dot(p,b)*1.6-water_time*.21)*2.6;
    vec3 slope = a * (0.026 * 1.45 * cos(pa)) + b * (0.014 * 2.4 * cos(pb));
    slope += c * (0.0045 * 7.0 * cos(pc)) + d * (0.003 * 10.0 * cos(pd));
    float wake = 0.0;
    for (int i=0; i<4; i++) {
        float age = water_time - ripples[i].w;
        if (age >= 0.0 && age < 4.0) {
            float distance = radius * sqrt(max(0.0, 2.0 - 2.0 * dot(n, ripples[i].xyz)));
            float envelope = exp(-pow((distance - age * 0.85) * 2.8, 2.0)) * (1.0 - age / 4.0) * ripple_strength[i];
            vec3 along = normalize(n - ripples[i].xyz + vec3(0.00001));
            slope += along * sin(distance * 15.0 - age * 7.0) * envelope * 0.22;
            wake += envelope * 0.18;
        }
    }
    slope -= n * dot(n, slope);
    vec3 smooth_view_normal=normalize(mat3(VIEW_MATRIX)*mat3(MODEL_MATRIX)*n);
    float surface_angle=max(0.0,dot(VIEW,smooth_view_normal));
    // At the globe silhouette, normal waves otherwise collapse into repeated
    // bright circular bands. Keep their strongest relief on the facing water.
    float wave_relief=mix(0.20,1.45,smoothstep(0.08,0.50,surface_angle));
    vec3 liquid_normal = normalize(n - slope * wave_relief);
    NORMAL = normalize(mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * liquid_normal);

    float radial_depth = depth_at(n);
    float trench = smoothstep(.68,.94,dot(n,berth_normal)+.014*sin(p.x*1.1)*sin(p.z*.9));
    // The seabed uses this same radial depth map. Hardware blends water over
    // opaque fish and sand, and depth-tests it against the dry shore.
    float thickness=radial_depth/max(.18,surface_angle);
    float absorption = 1.0-exp(-thickness*mix(.70,2.65,trench));
    vec3 shallow = vec3(0.045,0.56,0.60);
    vec3 deep = vec3(0.003,0.025,0.080);
    shallow=mix(shallow,vec3(.009,.051,.067),trench);
    deep=mix(deep,vec3(.001,.005,.016),trench);
    float incidence=max(0.40,surface_angle);
    vec3 water_color = mix(shallow,deep,1.0-exp(-radial_depth*0.64/incidence));
    float fresnel = pow(1.0-surface_angle,4.0);
    float crests = smoothstep(0.96,1.0,sin(pc)*sin(pd)) * 0.010;
    vec3 surface_color = water_color + vec3(0.38,0.61,0.66) * (crests+wake);
    ROUGHNESS = 0.32 + (1.0-absorption)*0.08 + .19*trench;
    SPECULAR = .36*(1.0-smoothstep(.25,.85,trench));
    METALLIC = 0.02;
	float opacity=mix(.22+.52*absorption,.24+.29*absorption,trench);
    ALBEDO=surface_color;
    EMISSION=vec3(.09,.22,.31)*fresnel*.045;
    ALPHA=mix(opacity,1.0,1.0-smoothstep(.12,.52,surface_angle));
}
