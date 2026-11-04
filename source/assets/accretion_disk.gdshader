shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, fog_disabled;

uniform sampler2D null_orbits : filter_linear, repeat_disable;
uniform sampler2D orbital_gas : filter_linear_mipmap, repeat_enable;
uniform float flow_time;
uniform bool close_view=false;
varying vec3 surface_pos;
varying vec3 eye;

void vertex() {
	surface_pos = VERTEX;
	eye = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz;
}

// Each annulus carries its own gas. Blend the overlapping speeds so that
// filaments remain coherent even when the app has been running for hours.
vec3 flow(vec3 hit, float radius) {
	float angle=atan(hit.z,hit.x)/TAU;
	float radial=(radius-5.5)/19.;
	float shell=clamp(log(max(radius,5.5)/5.5)*3.,0.,4.8);
	float lane=floor(shell);
	float u=angle+.19*radial;
	float phase=flow_time*.122;
	float speed=exp(-lane*.47);
	vec2 a=vec2(u+.213*lane-phase*speed,radial+.153*lane);
	vec2 b=vec2(u+.213*(lane+1.)-phase*speed*exp(-.47),radial+.153*(lane+1.));
	return mix(texture(orbital_gas,a).rgb,texture(orbital_gas,b).rgb,smoothstep(.0,1.,fract(shell)));
}

vec4 layer(vec3 from,vec3 side,float impact,float phi,float veil,float bearing) {
	vec2 coord=(vec2(clamp((impact-.05)/25.95,0.,1.)*1023.,phi/TAU*511.)+.5)/vec2(1024.,512.);
	float inv_r=dot(texture(null_orbits,coord).rg,vec2(65280.,255.))/131070.;
	float radius=1./max(inv_r,.032);
	if(radius<4.25 || radius>24.8) { return vec4(0.); }
	vec3 hit=from*cos(phi)+side*sin(phi);
	vec3 gas=flow(hit,radius);
	// Across the magnified arc we also see the high-altitude gas crossing the
	// line of sight. Its long, broken streaks soften the image of the thin midplane.
	float radial=(radius-5.5)/19.;
	vec2 trail=vec2(bearing/TAU-flow_time*.043+.11*radial,radial);
	vec3 haze=texture(orbital_gas,trail).rgb;
	float waviness=(haze.b-.5)*2.1+(gas.r-.5)*.55;
	radius+=waviness;
	float window=smoothstep(4.25,6.55,radius)*(1.-smoothstep(13.5,24.8,radius));
	float cloud=smoothstep(.17,.84,mix(gas.r,haze.r,.53)+.08*haze.g);
	float cover=window*mix(.22,.96,cloud)*(1.-veil*.40);
	float lane=.5+.5*sin(1.82*radius+3.6*(haze.b-.5)+.65*hit.x);
	float heat=.35+.64*cloud+.19*lane+.37*haze.g+.13*gas.g;
	float dust=smoothstep(.47,.83,haze.b)*smoothstep(.28,.73,gas.r);
	heat*=1.-.31*dust;
	float boost=.93+.17*dot(cross(vec3(0.,1.,0.),hit),from);
	float thermal=exp(-.041*max(0.,radius-7.0));
	vec3 color=mix(vec3(.58,.31,.23),vec3(1.12,.95,.79),smoothstep(.39,1.38,heat));
	return vec4(color*heat*boost*thermal,cover);
}
vec4 over(vec4 front,vec4 back){
	return front+(1.-front.a)*back;
}
vec4 disk(vec3 from,vec3 side,float b,float phi,float thickness,float bearing){
	// Three vertical samples give the near sheet a turbulent, wispy edge
	// and join it continuously to its lensed image along the two shoulders.
	vec4 mid=layer(from,side,b,phi,0.,bearing);
	if(!close_view)return vec4(mid.rgb*mid.a,mid.a);
	vec4 upper=layer(from,side,b,clamp(phi-thickness,.0,TAU),1.,bearing-.022);
	vec4 lower=layer(from,side,b,clamp(phi+thickness,.0,TAU),1.,bearing+.022);
	vec3 mist=(upper.rgb*upper.a+lower.rgb*lower.a)*.26;
	float density=(upper.a+lower.a)*.26;
	return vec4(mid.rgb*mid.a+mist*(1.-mid.a*.65),mid.a+density*(1.-mid.a));
}
// Integrate the wispy gas above the near face. At grazing incidence the
// observer looks through several streams at once, with gaps between them.
vec4 atmosphere(vec3 from,vec3 side,float impact) {
	vec4 sum=vec4(0.);
	int samples=close_view ? 7 : 3;
	for(int i=0;i<7;i++){
		if(i>=samples)break;
		float s=1.+(float(i)+.36)*19./float(samples);
		vec3 p=side*impact+from*s;
		float r=length(p.xz);
		float window=smoothstep(4.6,7.4,r)*(1.-smoothstep(14.,23.,r));
		if(abs(p.y)>1.7 || window<.001)continue;
		float az=atan(p.z,p.x)/TAU;
		vec2 uv=vec2(az-flow_time*.071,r*.083);
		vec3 drift=texture(orbital_gas,uv).rgb;
		float height=p.y-.54*(drift.b-.5);
		vec3 curls=texture(orbital_gas,vec2(az*2.-flow_time*.09+.03*height,r*.063+height*.45+.03*drift.b)).rgb;
		float width=.16+.62*curls.r;
		float plume=exp(-height*height/(width*width))*
			smoothstep(.22,.83,curls.r+.13*curls.g)*window;
		float a=min(.85,plume*2.87/float(samples));
		vec3 light=mix(vec3(.32,.21,.17),vec3(1.32,1.12,.92),smoothstep(.24,.82,curls.r+.19*curls.g));
		sum+=vec4(light*a,a)*(1.-sum.a);
	}
	return sum;
}
void fragment() {
	vec3 ray=normalize(surface_pos-eye);
	vec3 lateral=eye-ray*dot(eye,ray);
	float b=length(lateral)/.42;
	vec3 side=lateral/max(length(lateral),.0001);
	vec3 from=-ray;
	float start=asin(clamp(length(lateral)/length(eye),0.,1.));
	float phi=mod(atan(-from.y,side.y)+PI,PI);
	if(phi<start){phi+=PI;}
	float tilt=length(vec2(from.y,side.y));
	float h=min(.52,.019/max(tilt,.013));
	vec3 right=normalize(cross(vec3(0.,1.,0.),from));
	float bearing=atan(side.y,dot(side,right));
	vec4 near_disk=disk(from,side,b,phi,h,bearing);
	vec4 far_disk=disk(from,side,b,min(phi+PI,TAU),h,bearing+PI);
	far_disk.rgb*=.86;
	float aa=clamp(fwidth(b),.009,.18);
	float shadow=1.-smoothstep(5.196-aa,5.196+aa,b);
	// A cool, low-level scatter around the shadow separates the hot gas
	// from the black sky. The pencil-thin rim stays resolved at small sizes.
	float ring=exp(-abs(b-5.21)/max(.021,aa*.74))*min(1.,.055/max(.021,aa*.74));
	float halo=exp(-abs(b-6.6)*.24)*(1.-smoothstep(17.,25.,b));
	vec3 air=vec3(.015,.034,.053)*(.66*halo+.34*exp(-b*.11));
	float dither=(fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453)-.5)/1050.;
	vec4 light=over(near_disk,far_disk);
	if(abs(side.y*b)<3.+abs(from.y)*22.) light=over(atmosphere(from,side,b),light);
	float alpha=light.a+(1.-light.a)*max(shadow,.78*halo);
	vec3 color=light.rgb+(1.-light.a)*(air+vec3(1.03,.72,.48)*ring*.59);
	if(alpha<.002)discard;
	ALBEDO=max(vec3(0.),color/max(alpha,.001)+vec3(dither));ALPHA=alpha;
}
