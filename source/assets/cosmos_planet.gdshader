shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec4 base_color : source_color = vec4(.12,.4,.4,1.0);
uniform vec4 accent_color : source_color = vec4(.5,.9,.8,1.0);
uniform int kind = 0;
varying vec3 local_point;
float hash3(vec3 p) {
	uvec3 q=uvec3(ivec3(floor(p)));
	uint n=q.x*1973u+q.y*9277u+q.z*26699u+89173u;
	n=(n<<13u)^n;
	return float((n*(n*n*15731u+789221u)+1376312589u)&16777215u)/16777215.0;
}
float cloud3(vec3 p) {
	vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	float a=mix(hash3(i),hash3(i+vec3(1,0,0)),f.x);
	float b=mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x);
	float c=mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x);
	float d=mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x);
	return mix(mix(a,b,f.y),mix(c,d,f.y),f.z);
}
void vertex() { local_point=VERTEX; }
void fragment() {
	vec3 p=normalize(local_point);
	float cloud=cloud3(p*4.0);
	float broad=cloud3(p*2.2+vec3(3.7));
	float bands=.5+.5*sin(p.y*26.0+cloud*1.8);
	float mix_value=smoothstep(.14,.82,bands)*.72;
	if(kind==0){
		float layers=p.y*13.5+(cloud-.5)*1.15+.23*sin(p.x*7.+p.z*2.);
		mix_value=.37+.23*sin(layers)+.13*sin(layers*2.37)+.10*broad;
	}
	if(kind==1) { mix_value=smoothstep(.22,.67,abs(p.y)+cloud*.25)*.80+smoothstep(.55,.72,broad)*.16; }
	if(kind==2) {
		mix_value=smoothstep(.61,.70,cloud)*.80;
		EMISSION=accent_color.rgb*mix_value*.16;
	}
	if(kind==3) { mix_value=smoothstep(.43,.55,broad)*.78; }
	ALBEDO=mix(base_color.rgb,accent_color.rgb,clamp(mix_value,0.0,1.0));
	ALBEDO*=.93+cloud*.12;
	float limb=pow(1.0-max(0.0,dot(normalize(NORMAL),normalize(VIEW))),3.0);
	EMISSION+=vec3(.10,.20,.27)*limb*.14;
	ROUGHNESS=.82;
}
