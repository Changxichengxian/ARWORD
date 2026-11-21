// Procedural materials calculate light in linear space. The compatibility
// renderer accepts display-encoded material colors and blends in that space.
vec3 display_color(vec3 linear_color) {
	return mix(12.92 * linear_color, 1.055 * pow(max(linear_color, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055,
			step(vec3(0.0031308), linear_color));
}

vec3 linear_color(vec3 display_value) {
	return mix(display_value / 12.92, pow((display_value + 0.055) / 1.055, vec3(2.4)),
			step(vec3(0.04045), display_value));
}

vec4 volume_color(vec3 radiance, float opacity, bool display_blend) {
	if (!display_blend) {
		return vec4(radiance, opacity);
	}
	// Encode the light that actually reaches the viewer, including its coverage.
	// This preserves faint luminous edges against space and leaves opaque dust opaque.
	vec3 light = display_color(radiance * opacity);
	float coverage = clamp(max(opacity, max(light.r, max(light.g, light.b))), 0.0, 1.0);
	return vec4(light / max(coverage, 0.00001), coverage);
}
