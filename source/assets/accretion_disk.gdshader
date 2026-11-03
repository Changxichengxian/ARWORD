shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

// Data, not color artwork: the two lookup maps store the emitting disk
// coordinate hit by each bent ray, its weight, optical scatter and shadow.
uniform sampler2D disk_orbits : filter_linear, repeat_disable;
uniform sampler2D disk_light : filter_linear, repeat_disable;
float grain(vec2 p){
	vec2 cell=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);
	vec4 h=fract(sin(dot(cell,vec2(127.1,311.7))+vec4(0.,127.1,311.7,438.8))*43758.54);
	return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}
void fragment(){
	vec3 source=texture(disk_light,UV).rgb;
	if(source.r+source.g+source.b<.002)discard;
	vec3 orbit=texture(disk_orbits,UV).rgb;
	float radius=mix(5.8,21.6,orbit.r);
	vec2 az=orbit.gb*2.-1.;
	float a=TIME*.076*pow(5.8/radius,1.5);
	vec2 flow=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*az;
	float swirls=grain(flow*2.6+radius*.14);
	float warped_radius=radius*(.95+.10*swirls)+.47*flow.y;
	float crease=grain(vec2(warped_radius*1.7+2.7*swirls,flow.x*4.1+flow.y*1.2));
	float splits=grain(vec2(warped_radius*5.4+swirls*4.8,flow.y*4.7-flow.x));
	float matter=source.r*(.45+.62*crease+.25*splits);
	vec2 border=min(UV,1.-UV);
	float bloom=source.g*source.g*smoothstep(0.,.08,border.x)*smoothstep(0.,.11,border.y);
	// An ivory core within a cooler amber veil; preserve a genuinely dark
	// central shadow and a soft luminous foot along its upper silhouette.
	vec3 emission=vec3(.95,.67,.54)*bloom*.55;
	emission+=mix(vec3(.74,.37,.235),vec3(1.13,1.00,.88),smoothstep(.05,.70,matter))*(1.48*matter);
	emission+=vec3(.91,.91,.88)*smoothstep(.53,1.09,matter)*.20;
	float alpha=clamp(source.b+source.r*4.4+bloom*1.85,0.,1.);
	ALBEDO=emission/max(alpha,.001);ALPHA=alpha;
}
