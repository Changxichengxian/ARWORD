shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
varying vec3 ring_point;
void vertex(){ring_point=VERTEX;}
void fragment(){
	float x=UV.x;
	float bands=.5+.5*sin(x*117.+.65*sin(x*22.));
	float gap=1.-.88*exp(-pow((x-.59)/.036,2.))-.48*exp(-pow((x-.83)/.016,2.));
	float edge=smoothstep(.0,.055,x)*(1.-smoothstep(.90,1.,x));
	float dust=(.38+.32*bands+.22*sin(x*8.)*sin(x*8.))*gap*edge;
	float shade=.48+.52*smoothstep(-.70,.30,normalize(ring_point).x);
	vec3 mineral=mix(vec3(.37,.43,.47),vec3(.83,.70,.50),.5+.4*sin(x*9.));
	ALBEDO=mineral*shade;
	ALPHA=dust;
}
