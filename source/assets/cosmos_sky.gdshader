shader_type canvas_item;
render_mode unshaded;

uniform float drift = 0.0;
uniform float twinkle_time = 0.0;
uniform float aspect = .5625;
uniform float nebula_strength : hint_range(0.0,2.5) = 1.45;
uniform float color_strength : hint_range(0.0,2.0) = 1.3;
uniform float band_width : hint_range(.4,2.0) = 1.15;
uniform float star_density : hint_range(.3,2.0) = 1.1;
float hash21(vec2 p) {
	// Integer lattice hashes stay identical on both sides of a cloud cell, including negative cells.
	uvec2 q=uvec2(ivec2(floor(p)));
	uint n=q.x*1973u+q.y*9277u+89173u;
	n=(n<<13u)^n;
	uint bits=n*(n*n*15731u+789221u)+1376312589u;
	return float(bits&16777215u)/16777215.0;
}
float noise(vec2 p) {
	vec2 cell=floor(p);
	vec2 local=p-cell;
	vec2 weight=smoothstep(vec2(0.0),vec2(1.0),local);
	float a=hash21(cell);
	float b=hash21(cell+vec2(1.0,0.0));
	float c=hash21(cell+vec2(0.0,1.0));
	float d=hash21(cell+vec2(1.0,1.0));
	return ((1.0-weight.x)*a+weight.x*b)*(1.0-weight.y)+((1.0-weight.x)*c+weight.x*d)*weight.y;
}
float cloud(vec2 p) { return noise(p)*.56+noise(p*2.07+13.7)*.29+noise(p*4.13-9.8)*.15; }
float stars(vec2 uv,float density,float cutoff) {
	vec2 g=uv*density,cell=floor(g);float h=hash21(cell);
	vec2 center=vec2(hash21(cell+31.3),hash21(cell+81.8))*.72+.14;
	float dist=length(fract(g)-center);float point=1.0-smoothstep(.012,.105*(.8+.2*sqrt(star_density)),dist);
	return point*step(cutoff,h)*(.35+hash21(cell+13.1)*.65);
}
void fragment() {
	// Continuous camera-plane coordinates avoid equirectangular and cubemap seams entirely.
	vec2 view=vec2((UV.x-.5)*aspect,.5-UV.y)*.808;
	vec2 uv=vec2(atan(view.x)/6.2831853+.5,atan(view.y)/3.14159265+.5);
	vec2 flow=view*9.0+vec2(drift*.0040,-drift*.0024);
	float along=view.x-view.y*.65;
	float bend=(noise(vec2(along*8.0,1.3+drift*.0009))-.5)*.055;
	float axis=view.y+view.x*.76-.225+bend;
	float broad=exp(-pow(axis/(.079*band_width),2.0));
	float spine=exp(-pow((axis+.011)/(.028*band_width),2.0));
	float gas=cloud(flow);
	float fine=cloud(flow*2.6+vec2(8.2,-12.7));
	float dust=smoothstep(.43,.68,fine)*exp(-pow((axis-.009)/(.039*band_width),2.0));
	float strands=smoothstep(.29,.76,gas)*(broad*.55+spine*.45);
	float folded=cloud(flow*3.4+vec2(gas*2.8,fine*2.8));
	float filaments=pow(max(0.0,1.0-abs(folded-.53)*7.0),3.0);
	vec3 violet=vec3(.16,.018,.40);
	vec3 blue=vec3(.008,.12,.36);
	vec3 teal=vec3(.008,.28,.17);
	vec3 rose=vec3(.38,.045,.16);
	vec3 ion=mix(violet,blue,smoothstep(.28,.75,noise(flow*.54+8.1)));
	ion=mix(ion,teal,smoothstep(.51,.78,noise(flow*.83-18.4))*.8);
	ion=mix(ion,rose,smoothstep(.61,.83,noise(flow*.71+31.2))*.72);
	vec3 galaxy=ion*strands*(.58+fine*.7+filaments*.50)*(1.0-dust*.965);
	galaxy+=vec3(.025,.028,.037)*spine*pow(smoothstep(.28,.75,fine),2.0)*(1.0-dust*.98);
	vec2 cloud_a_pos=(view-vec2(-.16,.345))/(vec2(.11,.075)*sqrt(band_width));
	vec2 cloud_b_pos=(view-vec2(.17,.12))/(vec2(.075,.095)*sqrt(band_width));
	float cloud_a=exp(-dot(cloud_a_pos,cloud_a_pos));
	float cloud_b=exp(-dot(cloud_b_pos,cloud_b_pos));
	galaxy+=rose*cloud_a*smoothstep(.38,.76,gas)*.46;
	galaxy+=teal*cloud_b*smoothstep(.37,.73,fine)*.40;
	float luminance=dot(galaxy,vec3(.2126,.7152,.0722));
	galaxy=max(vec3(0.0),mix(vec3(luminance),galaxy,color_strength))*nebula_strength;
	// Empty space stays almost black. Starlight gathers around the galactic band.
	vec3 base=vec3(.000075,.000105,.00019);
	float stars_in_cloud=clamp(broad*.7+cloud_a*.18+cloud_b*.1,0.0,1.0);
	float small=stars(uv,1050.0,1.0-(.016+stars_in_cloud*.085)*star_density)*.35;
	float middle=stars(uv+1.73,390.0,1.0-(.012+stars_in_cloud*.022)*star_density)*.72;
	float bright=stars(uv+2.41,140.0,1.0-.007*star_density);
	float twinkle=.87+.13*sin(twinkle_time*.38+uv.x*122.0+uv.y*87.0);
	float star_gain=.35+star_density*.65;
	vec3 linear_light=base+galaxy+star_gain*(vec3(.60,.74,1.0)*(small+middle)*(1.0-dust*.58*min(nebula_strength,1.0))+vec3(1.0,.91,.78)*bright*twinkle);
	// This non-HDR canvas stores display-referred colour. Encode the dim light before its 8-bit target.
	vec3 display_light=pow(max(linear_light,vec3(0.0)),vec3(.454545));
	float dither=(hash21(FRAGCOORD.xy)-.5)/255.0;
	COLOR=vec4(display_light+vec3(dither),1.0);
}
