shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0,.55,.18,.24);
void fragment() {
	float r=length(UV-.5)*2.0;
	float halo=pow(max(0.0,1.0-r),3.0);
	ALBEDO=tint.rgb;ALPHA=halo*tint.a;
}
