shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, fog_disabled;

uniform sampler2D null_orbits : filter_linear, repeat_disable;
uniform float flow_time;
varying vec3 surface_pos;
varying vec3 eye;

void vertex() {
	surface_pos = VERTEX;
	eye = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz;
}

float grain(vec2 p){
	vec2 cell=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);
	vec4 h=fract(sin(dot(cell,vec2(127.1,311.7))+vec4(0.,127.1,311.7,438.8))*43758.54);
	return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}

// Locate the emitting gas where the ray crosses the plane of the disk.
// Both visible images sample the same orbiting material.
vec4 disk_crossing(vec3 from, vec3 side, float impact, float phi) {
	vec2 coord = (vec2(clamp((impact-.05)/25.95, 0., 1.)*1023., phi/TAU*511.)+.5)/vec2(1024., 512.);
	float inv_radius = dot(texture(null_orbits, coord).rg, vec2(65280.,255.))/131070.;
	float radius = 1./max(inv_radius,.03);
	float density = smoothstep(5.75,6.45,radius)*(1.-smoothstep(15.,22.,radius));
	vec3 hit = from*cos(phi)+side*sin(phi);
	float az = atan(hit.z,hit.x);
	// Adjacent annuli shear at different rates. Each pattern is periodic around the orbit.
	float drift = az-flow_time*.90*pow(6./max(radius,5.8),1.5);
	float swirl = sin(drift*2.+radius*.57)+.48*sin(drift*3.-radius*.91);
	vec2 orbit = vec2(cos(drift),sin(drift));
	float eddies = grain(orbit*3.6+radius*.43)+.50*grain(orbit*9.-radius*.65);
	float stream = .5+.5*cos(radius*3.2+swirl*1.4+drift*2.+3.5*eddies);
	float knot = pow(.5+.5*cos(drift*3.+radius*.62+swirl*.46),3.);
	float fine = .5+.5*cos(radius*7.4+swirl*2.3+5.*eddies);
	float heat = (.28+.40*stream+.93*knot+.14*fine)*(.54+.74*eddies)*exp(-.050*max(radius-7.,0.));
	float boost = .80+.27*dot(cross(vec3(0.,1.,0.),hit),from);
	vec3 tint = mix(vec3(.94,.29,.075), vec3(1.30,1.08,.85), smoothstep(.22,1.15,heat));
	return vec4(tint*heat*boost,density);
}
void fragment() {
	vec3 ray=normalize(surface_pos-eye);
	vec3 lateral=eye-ray*dot(eye,ray);
	float impact=length(lateral)/.42;
	vec3 side=lateral/max(length(lateral),.0001);
	vec3 from=-ray;
	// A distant observer. Correct the intersection angle for the finite camera distance.
	float start=asin(clamp(length(lateral)/length(eye),0.,1.));
	float phi=mod(atan(-from.y,side.y)+PI,PI);
	if (phi<start) {phi+=PI;}
	vec4 front=disk_crossing(from,side,impact,phi);
	vec4 rear=disk_crossing(from,side,impact,min(phi+PI,TAU));
	float aa=clamp(fwidth(impact),.015,.22);
	float shadow=1.-smoothstep(5.196-aa,5.196+aa,impact);
	float rim=exp(-abs(impact-5.26)/max(.058,aa))*.10;
	rear.rgb*=.44;
	float alpha=front.a+(1.-front.a)*(rear.a+(1.-rear.a)*shadow);
	vec3 color=front.rgb*front.a+(1.-front.a)*rear.rgb*rear.a;
	color+=vec3(1.,.63,.33)*rim;alpha=max(alpha,rim);
	if(alpha<.002)discard;
	ALBEDO=color/max(.001,alpha);ALPHA=alpha;
}
