shader_type spatial;
uniform vec3 planet_center;
uniform float sea_radius=11.62;
varying float immersion;

void vertex() {
	immersion=sea_radius-distance(VERTEX,planet_center);
}

void fragment() {
	float fade=smoothstep(.08,1.28,immersion);
	// As the limb sinks into silt, reveal the ocean beneath it. Keep the
	// exposed coils in the opaque pass so their crossings occlude correctly.
	if (fade>0.0 && fract(52.9829189*fract(dot(FRAGCOORD.xy,vec2(.06711056,.00583715))))<fade) discard;
	ALBEDO=mix(COLOR.rgb,vec3(.012,.030,.044),smoothstep(0.0,1.05,immersion)*.82);
	ROUGHNESS=.43+fade*.35;
	METALLIC=.09*(1.0-fade);
}
