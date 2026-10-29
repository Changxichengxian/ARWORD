shader_type canvas_item;
render_mode unshaded;

uniform float drift = 0.0;
uniform float twinkle_time = 0.0;
uniform float sky_seed = 0.0;
uniform float aspect = .5625;
uniform float nebula_strength = 1.45;
uniform float color_strength = 1.3;
uniform float band_width = 1.15;
uniform float star_density : hint_range(.3,2.0) = 1.1;
float hash21(vec2 p) {
	uvec2 q=uvec2(ivec2(floor(p)));
	uint n=q.x*1973u+q.y*9277u+89173u;
	n=(n<<13u)^n;
	return float((n*(n*n*15731u+789221u)+1376312589u)&16777215u)/16777215.0;
}
float stars(vec2 uv,float density,float cutoff,float glint) {
	vec2 g=uv*density,cell=floor(g)+vec2(sky_seed,sky_seed*.31);
	vec2 center=vec2(hash21(cell+31.3),hash21(cell+81.8))*.72+.14;
	vec2 offset=fract(g)-center;
	float point=1.0-smoothstep(.008,.09*(.8+.2*sqrt(star_density)),length(offset));
	float rays=exp(-abs(offset.x)*115.0-abs(offset.y)*17.0)+exp(-abs(offset.y)*115.0-abs(offset.x)*17.0);
	return (point+rays*glint)*step(cutoff,hash21(cell))*(.35+hash21(cell+13.1)*.65);
}
void fragment() {
	vec2 view=vec2((UV.x-.5)*aspect,.5-UV.y)*.808;
	vec2 uv=vec2(atan(view.x)/6.2831853+.5,atan(view.y)/3.14159265+.5);
	float small=stars(uv,1250.0,1.0-.026*star_density,0.0)*.22;
	float middle=stars(uv+1.73,430.0,1.0-.016*star_density,0.0)*.58;
	float bright=stars(uv+2.41,145.0,1.0-.008*star_density,.12);
	float twinkle=.93+.07*sin(twinkle_time*.38+uv.x*122.0+uv.y*87.0);
	vec3 starlight=(.35+star_density*.65)*(vec3(.66,.81,1.0)*(small+middle)+vec3(1.0,.90,.75)*bright*twinkle);
	vec3 light=vec3(.000008,.000012,.000025)+starlight;
	float dither=(hash21(FRAGCOORD.xy)-.5)/255.0;
	COLOR=vec4(pow(light,vec3(.454545))+vec3(dither),1.0);
}
