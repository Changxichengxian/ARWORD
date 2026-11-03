shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform float water_time=0.0;
uniform float radius=11.62;
void vertex() {
    vec3 n=normalize(VERTEX);vec3 p=n*radius;
    float wave=.026*sin(dot(p,vec3(.78,.18,.60))*1.45-water_time*.85)+.014*sin(dot(p,vec3(-.32,.71,.63))*2.4+water_time*.65);
    VERTEX=n*(radius+wave+.012);
}
void fragment() {
    float phase=fract(water_time*.19+UV.x*.035);
    float line=exp(-pow((UV.y-phase)*13.0,2.0));
    float broken=smoothstep(-.10,.65,sin(UV.x*7.0+water_time*.37)+sin(UV.x*13.0-water_time*.20)*.38);
    float edges=smoothstep(0.0,.12,UV.y)*(1.0-smoothstep(.75,1.0,UV.y));
    ALBEDO=vec3(.71,.91,.87);
    ALPHA=line*broken*edges*.33;
}
