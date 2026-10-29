shader_type spatial;
render_mode unshaded, fog_disabled;
varying vec3 point;
void vertex() { point=VERTEX; }
void fragment() {
	vec3 p=normalize(point);
	float texture=sin(p.y*14.0+sin(p.x*7.0))*sin(p.z*11.0-p.x*8.0);
	float edge=pow(clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),.28);
	ALBEDO=mix(vec3(1.0,.50,.12),vec3(1.0,.88,.40),edge);
	ALBEDO*=.96+texture*.035;
}
