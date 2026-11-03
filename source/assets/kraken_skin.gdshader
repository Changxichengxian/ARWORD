shader_type spatial;
uniform vec3 planet_center;
uniform float sea_radius=11.62;
varying float immersion;

void vertex() {
	immersion=sea_radius-distance(VERTEX,planet_center);
}

void fragment() {
	float fade=smoothstep(3.1,4.8,immersion);
	// As the limb sinks into silt, reveal the ocean beneath it. Keep the
	// exposed coils in the opaque pass so their crossings occlude correctly.
	if (fade>0.0 && fract(52.9829189*fract(dot(FRAGCOORD.xy,vec2(.06711056,.00583715))))<fade) discard;
	ALBEDO=mix(COLOR.rgb,vec3(.022,.070,.089),smoothstep(0.0,4.3,immersion)*.78);
	EMISSION=vec3(.018,.052,.066)*smoothstep(.12,1.15,immersion)*(1.-fade);
	ROUGHNESS=.43+fade*.35;
	METALLIC=.09*(1.0-fade);
}
