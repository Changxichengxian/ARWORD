shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec4 tint:source_color=vec4(.64,.82,1.,1.);
void vertex(){
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment(){
	vec2 p=UV*2.-1.;
	float d=length(p);
	float core=exp(-d*d*2000.);
	float halo=exp(-d*9.);
	float rays=exp(-abs(p.x)*147.-abs(p.y)*6.)+exp(-abs(p.y)*147.-abs(p.x)*6.);
	float light=core+halo*.61+rays*.48;
	ALBEDO=mix(tint.rgb,vec3(1.),core*.86);
	ALPHA=clamp(light*(1.-smoothstep(.72,1.,d)),0.,1.);
}
