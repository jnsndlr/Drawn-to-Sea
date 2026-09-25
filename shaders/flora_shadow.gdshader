// Soft painted ground shadow under a plant, multiplied onto the chart.
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled;

const vec3 SHADOW = vec3(0.66, 0.61, 0.47);

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float strength = (1.0 - smoothstep(0.25, 1.0, length(q))) * 0.6;
	ALBEDO = pow(mix(vec3(1.0), SHADOW, strength), vec3(2.2));
}
