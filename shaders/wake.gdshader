shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D geography_map : filter_linear, repeat_disable;
varying vec2 map_position;
void vertex() {
	map_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec2 coast = texture(geography_map, map_position / vec2(18.0, 12.0) + 0.5).rg;
	float water = smoothstep(0.02, 0.16, min(coast.r, coast.g));
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * water;
}
