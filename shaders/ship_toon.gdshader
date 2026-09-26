// Cel-shaded ship: the model's textures only supply detail, the palette supplies
// colour. Lighting is quantised into three ink-wash bands around the chart sun,
// and the darkest band picks up screen-space hatching like the terrain cliffs.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://shaders/explorer_palette.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.55, 0.40, 0.25);
// Source textures are dark; this lifts their luminance into a usable detail range.
uniform float detail_gain = 3.0;
uniform float detail_strength = 0.45;
uniform float hatch_spacing = 5.0;

float band(float value, float edge) {
	float aa = max(fwidth(value), 0.001);
	return smoothstep(edge - aa, edge + aa, value);
}

void fragment() {
	if (texture(albedo_texture, UV).a < 0.5) {
		discard;
	}
	// A blurrier mip for detail: the fine plank stripes otherwise shimmer at map zoom.
	vec4 source = texture(albedo_texture, UV, 2.0);
	// Faceted normals from screen derivatives keep planes crisp and read like
	// drawn facets; flip toward the camera so two-sided sails light consistently.
	vec3 view_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(view_normal, -VERTEX) < 0.0) {
		view_normal = -view_normal;
	}
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(view_normal, 0.0)).xyz);
	float light = dot(normal, normalize(SUN_DIR));
	float lit = band(light, 0.45);
	float mid = band(light, -0.05);
	float shade = mix(0.58, mix(0.8, 1.0, lit), mid);

	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float detail = clamp(luminance * detail_gain, 0.0, 1.0);
	vec3 base = tint * mix(1.0 - detail_strength, 1.0 + detail_strength * 0.35, detail);
	// Shadows drift toward sepia ink rather than simply going grey.
	vec3 color = mix(SEPIA, base, shade);

	float hatch_phase = (FRAGCOORD.x + FRAGCOORD.y) / hatch_spacing;
	float hatch = 1.0 - smoothstep(0.18, 0.32, abs(fract(hatch_phase) - 0.5) * 2.0);
	hatch *= 1.0 - mid;
	color = mix(color, SEPIA, hatch * 0.55);
	ALBEDO = color;
}
