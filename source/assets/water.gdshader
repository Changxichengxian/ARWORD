shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 deep_color : source_color = vec4(0.055, 0.40, 0.57, 1.0);
uniform vec4 light_color : source_color = vec4(0.13, 0.65, 0.70, 1.0);
varying vec3 local_point;
void vertex() {
    local_point = VERTEX;
}
void fragment() {
    float broad = sin(local_point.x * 0.38 + local_point.z * 0.24) * 0.5 + 0.5;
    float wave = sin(local_point.x * 2.7 + local_point.z * 1.9 + TIME * 0.6);
    float cross_wave = sin(local_point.z * 3.1 - local_point.x * 0.9 - TIME * 0.42);
    float glint = smoothstep(0.985, 1.0, wave * cross_wave) * 0.10;
    ALBEDO = mix(deep_color.rgb, light_color.rgb, broad * 0.48) + vec3(glint);
    ROUGHNESS = 0.38;
    SPECULAR = 0.25;
}
