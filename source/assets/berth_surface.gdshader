shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 glow : source_color = vec4(0.0);
uniform float glow_energy = 0.0;
uniform float surface_roughness = 0.8;
uniform float surface_metallic = 0.0;
uniform bool use_paint = false;

void fragment() {
	ALBEDO = tint.rgb * (use_paint ? COLOR.rgb : vec3(1.0));
	EMISSION = glow.rgb * glow_energy;
	ROUGHNESS = surface_roughness;
	METALLIC = surface_metallic;
}
#include "res://assets/berth_light.gdshaderinc"
