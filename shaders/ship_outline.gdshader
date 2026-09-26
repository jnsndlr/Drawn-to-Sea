// Inverted-hull ink outline for the ship. Vertices are pushed out along smoothed
// normals in clip space so the line keeps a constant pixel width at every zoom.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

#include "res://shaders/explorer_palette.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float outline_pixels = 1.4;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = mat3(MODELVIEW_MATRIX) * NORMAL;
	vec2 direction = length(view_normal.xy) > 0.0001 ? normalize(view_normal.xy) : vec2(0.0);
	clip.xy += direction * outline_pixels * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	if (texture(albedo_texture, UV).a < 0.5) {
		discard;
	}
	ALBEDO = SEPIA * 0.8;
}
