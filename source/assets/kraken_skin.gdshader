shader_type spatial;
#include "res://assets/scene_color.gdshaderinc"
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
	vec3 silt=vec3(.022,.070,.089);
	vec3 skin=mix(COLOR.rgb,OUTPUT_IS_SRGB ? display_color(silt) : silt,smoothstep(0.0,4.3,immersion)*.78);
	vec3 glint=vec3(.018,.052,.066)*smoothstep(.12,1.15,immersion)*(1.-fade);
	ALBEDO=skin;
	EMISSION=OUTPUT_IS_SRGB ? display_color(glint) : glint;
	ROUGHNESS=.43+fade*.35;
	METALLIC=.09*(1.0-fade);
}
#include "res://assets/berth_light.gdshaderinc"
