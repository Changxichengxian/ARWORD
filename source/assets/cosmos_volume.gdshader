shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;

uniform sampler3D cloud_noise : filter_linear, repeat_enable;
uniform vec3 cloud_center = vec3(0.0,20.0,-110.0);
uniform vec3 cloud_radii = vec3(18.0,9.0,12.0);
uniform mat3 cloud_inverse;
uniform vec3 noise_phase = vec3(0.0);
uniform vec4 cold_color : source_color = vec4(.28,.53,.61,1.0);
uniform vec4 warm_color : source_color = vec4(.65,.45,.25,1.0);
uniform float drift = 0.0;
uniform float nebula_strength = 1.45;
uniform float color_strength = 1.3;
uniform float density_scale = 1.0;
uniform int ray_steps = 12;
varying vec3 world_point;
float pixel_random(vec2 p) {
	uvec2 q=uvec2(ivec2(p));uint n=q.x*1973u+q.y*9277u+89173u;n=(n<<13u)^n;
	return float((n*(n*n*15731u+789221u)+1376312589u)&16777215u)/16777215.0;
}

void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 direction=normalize(world_point-CAMERA_POSITION_WORLD);
	vec3 origin=(cloud_inverse*(CAMERA_POSITION_WORLD-cloud_center))/cloud_radii;
	vec3 ray=(cloud_inverse*direction)/cloud_radii;
	float a=dot(ray,ray),b=dot(origin,ray),c=dot(origin,origin)-1.0;
	float discriminant=b*b-a*c;
	if(discriminant<=0.0 || nebula_strength<=0.0) { discard; }
	float near_t=max(0.0,(-b-sqrt(discriminant))/a);
	float far_t=(-b+sqrt(discriminant))/a;
	float step_size=(far_t-near_t)/float(ray_steps);
	vec3 phase=noise_phase+vec3(drift*.0011,-drift*.0007,drift*.0005);
	vec3 glow=vec3(0.0);
	float transmission=1.0;
	float sample_offset=.2+pixel_random(FRAGCOORD.xy)*.6;
	for(int i=0;i<12;i++) {
		if(i>=ray_steps) { break; }
		vec3 p=origin+ray*(near_t+(float(i)+sample_offset)*step_size);
		float edge_fade=smoothstep(0.0,.42,1.0-dot(p,p));
		vec3 coord=p*.32+phase;
		float body=texture(cloud_noise,coord).r;
		float large=texture(cloud_noise,coord*.53+vec3(.37,.15,.69)).r;
		float density=smoothstep(.46,.77,body*.76+large*.24)*edge_fade;
		float lit=texture(cloud_noise,coord+vec3(-.035,.055,.018)).r;
		float thin_light=clamp((lit-body)*7.0,0.0,1.0);
		float alpha=1.0-exp(-density*step_size*.070*density_scale*(nebula_strength/1.45));
		vec3 tint=cold_color.rgb*(.23+thin_light*.66)+warm_color.rgb*pow(thin_light,4.0)*.65;
		float luma=dot(tint,vec3(.2126,.7152,.0722));
		tint=max(vec3(0.0),mix(vec3(luma),tint,color_strength/1.3));
		glow+=transmission*alpha*tint;
		transmission*=1.0-alpha;
	}
	float opacity=1.0-transmission;
	ALPHA=clamp(opacity+(pixel_random(FRAGCOORD.yx+17.0)-.5)*min(opacity,.004),0.0,.65);
	ALBEDO=glow/max(1.0-transmission,.00001);
}
