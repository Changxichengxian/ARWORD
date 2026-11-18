shader_type sky;
render_mode disable_fog;

uniform sampler2D solar_view : source_color, filter_linear, repeat_disable;
uniform float reveal : hint_range(0,1) = 1.0;

void sky() {
	COLOR = vec3(0.0);
	if (!AT_CUBEMAP_PASS) {
		COLOR = texture(solar_view, SCREEN_UV).rgb * reveal;
	}
}
