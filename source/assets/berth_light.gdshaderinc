// GLES applies the sun to every visible layer. Only the local moon and
// pier lamps should contribute direct light to the far-side island.
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
void light() {
	if (!LIGHT_IS_DIRECTIONAL) {
		float incidence = max(dot(NORMAL, LIGHT), 0.0);
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * incidence / PI;
		vec3 halfway = normalize(LIGHT + VIEW);
		float exponent = mix(64.0, 4.0, ROUGHNESS);
		float highlight = pow(max(dot(NORMAL, halfway), 0.0), exponent);
		SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * incidence * highlight * (1.0 - ROUGHNESS) * 0.16;
	}
}
#endif
