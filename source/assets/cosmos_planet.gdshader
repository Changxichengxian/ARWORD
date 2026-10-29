shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec4 base_color : source_color = vec4(.12,.4,.4,1.0);
uniform vec4 accent_color : source_color = vec4(.5,.9,.8,1.0);
uniform int kind = 0;
varying vec3 local_point;
void vertex() { local_point=VERTEX; }
void fragment() {
	vec3 p=normalize(local_point);
	float waves=sin(p.y*22.0+sin(p.x*6.0)*1.4+cos(p.z*8.0)*.8);
	float veins=sin(p.x*13.0+cos(p.y*17.0)+sin(p.z*11.0));
	float mix_value=smoothstep(-.5,.5,waves)*.52;
	if(kind==1) { mix_value=smoothstep(.14,.48,abs(p.y))*.55+step(.4,veins)*.16; }
	if(kind==2) { mix_value=smoothstep(.82,.97,veins)*.75; EMISSION=accent_color.rgb*mix_value*.25; }
	ALBEDO=mix(base_color.rgb,accent_color.rgb,mix_value);
	ROUGHNESS=.88;
}
