shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, fog_disabled;

uniform sampler2D null_orbits : filter_linear, repeat_disable;
uniform sampler2D orbital_gas : filter_linear_mipmap, repeat_enable;
uniform float flow_time;
uniform bool close_view = false;
varying vec3 surface_pos;
varying vec3 eye;

void vertex() {
	surface_pos = VERTEX;
	eye = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz;
}

// The baked orbit starts at infinity. Each row advances along the same ray.
float inverse_radius(float column, float phi) {
	vec2 uv = (vec2(column, phi * (511.0 / TAU)) + 0.5) / vec2(1024.0, 512.0);
	return dot(textureLod(null_orbits, uv, 0.0).rg, vec2(65280.0, 255.0)) / 131070.0;
}

vec3 gas_at(vec3 p, float radius, float lod) {
	float radial = (radius - 5.5) / 19.0;
	float shell = clamp(log(max(radius, 5.5) / 5.5) * 3.0, 0.0, 4.8);
	float lane = floor(shell);
	float u = atan(p.z, p.x) / TAU + 0.19 * radial;
	float phase = flow_time * 0.105 * exp(-lane * 0.47);
	vec2 a = vec2(u + 0.213 * lane - phase, radial + 0.153 * lane);
	vec2 b = vec2(u + 0.213 * (lane + 1.0) - phase * exp(-0.47), radial + 0.153 * (lane + 1.0));
	return mix(textureLod(orbital_gas, a, lod).rgb, textureLod(orbital_gas, b, lod).rgb, smoothstep(0.0, 1.0, fract(shell)));
}

// Mean vertical density along a whole segment, including a thin sheet
// crossed between two samples. The formula has the same limit from either face.
float column_density(float a, float b) {
	if (abs(b - a) < 0.006) {
		float z = 0.5 * (a + b);
		return 0.75 * max(0.0, 1.0 - z*z);
	}
	return (smoothstep(-1.0, 1.0, b) - smoothstep(-1.0, 1.0, a)) / (b - a);
}

void fragment() {
	const float mass = 0.42;
	vec3 ray = normalize(surface_pos - eye);
	vec3 outward = normalize(eye);
	float distance_m = length(eye) / mass;
	float impact = length(cross(eye / mass, ray)) * inversesqrt(1.0 - 2.0 / distance_m);
	float aa = clamp(fwidth(impact), 0.012, 0.2);
	if (impact > 25.6) { discard; }
	float column = clamp((impact - 0.05) / 25.95, 0.0, 1.0) * 1023.0;
	vec3 tangent = ray - outward * dot(ray, outward);
	tangent /= max(length(tangent), 0.000001);
	float start = asin(clamp(impact / distance_m, 0.0, 0.999));
	// One Newton step aligns the observer with its finite radius on the baked ray.
	float slope = (inverse_radius(column, start + 0.006) - inverse_radius(column, start)) / 0.006;
	start -= clamp((inverse_radius(column, start) - 1.0 / distance_m) / max(slope, 0.002), -0.04, 0.04);
	float phi = max(start, asin(clamp(impact / 26.0, 0.0, 0.999)));
	float radius = 1.0 / max(inverse_radius(column, phi), 0.032);
	vec3 previous = radius * (outward * cos(phi-start) + tangent * sin(phi-start));
	vec3 light = vec3(0.0);
	float transmission = 1.0;
	float step_length = close_view ? 1.12 : 2.05;
	float lod = close_view ? 0.8 : 2.6;
	for (int i=0; i<80; i++) {
		float next_phi = min(TAU, phi + clamp(step_length * max(impact, 0.05) / (radius*radius), 0.00007, 0.26));
		float next_radius = 1.0 / max(inverse_radius(column, next_phi), 0.030);
		vec3 p = next_radius * (outward*cos(next_phi-start) + tangent*sin(next_phi-start));
		vec3 mid = 0.5*(p+previous);
		float cylindrical_r = length(mid.xz);
		float outer = smoothstep(11.0,16.0,cylindrical_r)*(1.0-smoothstep(20.0,24.8,cylindrical_r));
		if (outer>0.001 && abs(mid.y)<4.0) {
			// Cold material sits outside the hot annuli. Integrating its extinction
			// here also leaves light from material already in front of it intact.
			vec2 uv=vec2(atan(mid.z,mid.x)/TAU - flow_time*0.018, cylindrical_r*0.037);
			vec3 dust=textureLod(orbital_gas,uv,lod+1.0).rgb;
			float z=(mid.y - 1.9*(dust.b-0.5))/(0.6 + 1.9*dust.r);
			float clump=smoothstep(0.45,0.76,dust.r + 0.16*dust.g);
			float extinction=1.0-exp(-outer*clump*exp(-z*z)*length(p-previous)*0.20);
			float reflected=smoothstep(0.85,2.1,abs(z))*(1.0-smoothstep(15.0,23.0,cylindrical_r));
			light+=transmission*extinction*mix(vec3(0.009,0.006,0.005),vec3(0.15,0.065,0.031),reflected);
			transmission*=1.0-extinction;
		}
		float height = 0.22 + 0.022 * radius;
		float density = column_density(previous.y / height, p.y / height);
		float veil = column_density(previous.y / (2.8*height), p.y / (2.8*height));
		if (veil > 0.0001 && max(radius,next_radius)>4.6) {
			float dy = p.y - previous.y;
			float fraction = abs(dy)>0.001 ? clamp(-previous.y/dy, 0.0, 1.0) : 0.5;
			vec3 hit = mix(previous, p, mix(0.5, fraction, smoothstep(0.3, 1.0, abs(dy)/height)));
			float r = length(hit.xz);
			float window = smoothstep(4.7, 6.85, r) * (1.0-smoothstep(14.0, 24.6, r));
			if (window > 0.0001) {
				vec3 gas = gas_at(hit, r, lod);
				float filament = smoothstep(0.22,0.83,gas.r + 0.25*gas.g);
				float depth = length(p-previous) * window * (density + 0.085*veil) * mix(0.17,1.75,filament);
				float alpha = 1.0-exp(-depth);
				float heat = clamp((gas.r*0.80 + gas.g*0.44 + 0.12) * exp(-0.048*max(r-7.0,0.0)),0.0,1.2);
				vec3 velocity = vec3(-hit.z,0.0,hit.x)/max(r,0.01);
				float boost = 1.0 + 0.31*dot(velocity,normalize(previous-p));
				vec3 tint = mix(vec3(0.49,0.135,0.043),vec3(1.0,0.64,0.37),smoothstep(0.13,0.56,heat));
				tint = mix(tint,vec3(1.0,0.934,0.79),smoothstep(0.48,0.82,heat));
				float emission=0.10 + 0.60*heat*heat + 3.7*heat*heat*heat + 2.7*smoothstep(0.71,1.01,heat);
				light += transmission * alpha * tint * emission * boost*boost;
				transmission *= 1.0-alpha;
			}
		}
		if (next_radius<=2.015 || (next_radius>26.1 && next_radius>radius) || next_phi>=TAU || transmission<0.008) { break; }
		radius=next_radius; phi=next_phi; previous=p;
	}
	float shadow = 1.0-smoothstep(5.196-aa,5.196+aa,impact);
	float rim = exp(-abs(impact-5.205)/max(0.024,aa)) * min(1.0,0.048/aa);
	float alpha = 1.0-transmission*(1.0-max(shadow,rim*0.55));
	if (alpha<0.002) { discard; }
	ALBEDO = (light+transmission*rim*vec3(0.95,0.61,0.37))/alpha;
	ALPHA = alpha;
}
