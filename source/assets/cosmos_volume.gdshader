shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;

uniform sampler3D cloud_noise : filter_linear, repeat_enable;
uniform vec3 cloud_center = vec3(0.0,20.0,-110.0);
uniform vec3 cloud_radii = vec3(18.0,9.0,12.0);
uniform mat3 cloud_inverse;
uniform vec3 noise_phase = vec3(0.0);
uniform vec4 cold_color : source_color = vec4(.28,.53,.61,1.0);
uniform vec4 middle_color : source_color = vec4(.50,.44,.76,1.0);
uniform vec4 warm_color : source_color = vec4(.65,.45,.25,1.0);
uniform float drift = 0.0;
uniform float nebula_strength = 1.45;
uniform float color_strength = 1.3;
uniform float density_scale = 1.0;
uniform int ray_steps = 12;
uniform int structure = 0;
uniform float detail_view = 0.0;
varying vec3 world_point;
float pixel_random(vec2 p) {
	uvec2 q=uvec2(ivec2(p));uint n=q.x*1973u+q.y*9277u+89173u;n=(n<<13u)^n;
	return float((n*(n*n*15731u+789221u)+1376312589u)&16777215u)/16777215.0;
}

void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
float cloud_shape(vec3 p,float coarse) {
	vec3 q=p+vec3(sin(p.y*4.0),sin(p.z*3.0+p.x),cos(p.y*3.0))*(coarse-.5)*.20;
	if(structure==0) {
		// An incomplete cloud corridor: a hollow centre, two irregular curving arms.
		float ring=exp(-pow((length(q.xy*vec2(.94,1.0))-.51)/.22,2.0));
		float opening=smoothstep(-.05,.42,q.x+q.y*.55+coarse*.65);
		return ring*(.10+opening*.90)*exp(-q.z*q.z*2.6);
	} else if(structure==1) {
		vec3 left=q-vec3(-.31,.20,.13),right=q-vec3(.32,-.17,-.13);
		float lobes=exp(-dot(left*vec3(1.7,2.0,1.4),left*vec3(1.7,2.0,1.4))*2.0);
		lobes+=exp(-dot(right*vec3(1.9,1.6,1.5),right*vec3(1.9,1.6,1.5))*2.0);
		return lobes;
	}
	// Unequal towers of gas, with a cold dust cleft through the middle.
	float towers=exp(-pow((q.x+.31+q.y*.18)/.20,2.0))*exp(-pow((q.y+.05)/.70,4.0));
	towers+=exp(-pow((q.x-.24+sin(q.y*3.0)*.07)/.22,2.0))*exp(-pow((q.y-.16)/.57,4.0));
	return towers*exp(-q.z*q.z*3.7);
}
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
	for(int i=0;i<36;i++) {
		if(i>=ray_steps) { break; }
		vec3 p=origin+ray*(near_t+(float(i)+sample_offset)*step_size);
		float edge_fade=smoothstep(0.0,.36,1.0-dot(p,p));
		vec3 coord=p*.41+phase;
		float body=texture(cloud_noise,coord).r;
		float large=texture(cloud_noise,coord*.49+vec3(.37,.15,.69)).r;
		float fine=texture(cloud_noise,coord*3.1+vec3(.11,.42,.27)).r;
		if(detail_view>.5) { fine=mix(fine,texture(cloud_noise,coord*7.1+vec3(.31,.62,.09)).r,.26); }
		float shape=cloud_shape(p,large);
		float density=smoothstep(.33,.72,body*.61+large*.21+fine*.18)*shape*edge_fade;
		float lit=texture(cloud_noise,coord+vec3(-.031,.046,.025)).r;
		float thin_light=clamp((lit-body)*8.5,0.0,1.0);
		float strands=smoothstep(.52,.70,fine)*smoothstep(.07,.33,thin_light);
		// Dense dust absorbs background stars; coloured light lives around its thinner edges.
		float dust=smoothstep(.56,.78,large)*smoothstep(.39,.65,body)*shape*edge_fade;
		float violet=smoothstep(.30,.70,large+p.y*.18-p.x*.12);
		vec3 gas_color=mix(cold_color.rgb,middle_color.rgb,violet*.78);
		vec3 tint=gas_color*(.20+thin_light*.90+strands*(.65+detail_view*.9));
		float shape_rim=clamp((cloud_shape(p+vec3(-.09,.10,.04),large)-shape)*3.0,0.0,1.0);
		float gold=(pow(thin_light,3.8)*smoothstep(.50,.78,fine)*.16+pow(shape_rim,2.2)*.7)*(.30+float(structure==2)*.9);
		tint*=1.0-smoothstep(.035,.30,dust)*.82;
		tint+=warm_color.rgb*gold*1.35;
		tint*=1.0+detail_view*.32;
		if(detail_view>.5) {
			// Close observation resolves thin lit sheets around darker, absorbing cores.
			// Keep the distant-view density and lighting above unchanged.
			float folded=body*.64+fine*.36;
			float sheet=exp(-pow((folded-.515)/.048,2.0));
			float filaments=sheet*smoothstep(.12,.58,thin_light)*smoothstep(.39,.64,fine);
			float core=smoothstep(.53,.68,body)*smoothstep(.48,.66,large);
			density=smoothstep(.38,.65,folded)*shape*edge_fade;
			dust=max(dust,core*shape*edge_fade*1.8);
			float color_patch=smoothstep(.38,.67,large+p.y*.14-p.x*.09);
			vec3 violet_edge=mix(middle_color.rgb,vec3(.42,.16,.34),.24);
			gas_color=mix(cold_color.rgb,violet_edge,color_patch*.9);
			tint=gas_color*(.038+thin_light*.24+filaments*3.2);
			tint*=1.0-smoothstep(.04,.48,dust)*.94;
			// Gold is confined to the broken sunward skin, rather than broad yellow lobes.
			float warm_edge=filaments*pow(thin_light,2.2)*smoothstep(.15,.5,shape_rim);
			warm_edge*=.16+float(structure==2)*2.8;
			tint+=warm_color.rgb*warm_edge*2.1;
		}
		float alpha=1.0-exp(-(density+dust*.7)*step_size*.14*(1.0+detail_view*.5)*density_scale*(nebula_strength/1.45));
		float luma=dot(tint,vec3(.2126,.7152,.0722));
		tint=max(vec3(0.0),mix(vec3(luma),tint,color_strength/1.3));
		glow+=transmission*alpha*tint;
		transmission*=1.0-alpha;
	}
	float opacity=1.0-transmission;
	ALPHA=clamp(opacity+(pixel_random(FRAGCOORD.yx+17.0)-.5)*min(opacity,.003),0.0,.90);
	ALBEDO=glow/max(1.0-transmission,.00001);
}
