// Billboard plant sprites. Each samples one pre-drawn variant from the atlas
// baked by flora_atlas_bake.gdshader, so a sprite costs a single texture read.
// INSTANCE_CUSTOM: r = atlas cell index, b = size.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;

const vec2 ATLAS_GRID = vec2(8.0, 4.0);
// Must match flora_atlas_bake.gdshader and TRUNK_ALPHA in flora_draw.gdshaderinc.
const float CELL_PADDING = 1.06;
const float TRUNK_ALPHA = 0.62;

varying vec2 cell;
varying float plant_size;
varying vec2 crown_center;
varying vec2 crown_radius;
// 0 at the default oblique view, 1 looking straight down.
varying float overhead;

void vertex() {
	float index = INSTANCE_CUSTOM.r;
	cell = vec2(mod(index, ATLAS_GRID.x), floor(index / ATLAS_GRID.x));
	float size = INSTANCE_CUSTOM.b * CELL_PADDING;
	plant_size = INSTANCE_CUSTOM.b;
	// Match the drawing coordinates in flora_draw.gdshaderinc. Rounded depth
	// lets overlapping crowns meet gradually instead of swapping whole cards.
	crown_center = index < 16.0 ? vec2(0.0, 0.02) : (index < 24.0 ? vec2(0.0, -0.3) : vec2(0.0, 0.3));
	crown_radius = index < 24.0 ? vec2(0.8, 0.75) : vec2(0.85, 0.5);
	// Trees lose their trunks overhead, but palms retain theirs and must always
	// pivot around the drawn trunk base (q.y = -0.97 in flora_draw).
	overhead = smoothstep(0.8, 0.97, INV_VIEW_MATRIX[2].y);
	bool is_palm = index >= 24.0;
	float root_offset = 0.97 / (2.0 * CELL_PADDING);
	float pivot = is_palm ? root_offset : mix(root_offset, 0.0, overhead);
	float height = (VERTEX.y + pivot) * size;
	// Screen-up leans away from the camera into the terrain. Give the card
	// the depth of an upright plant while retaining its camera-facing silhouette.
	// Limit the slope near overhead, where an upright card would be edge-on.
	// Use the unshifted root height so recentered tree crowns stay above land too.
	float sin_pitch = clamp(INV_VIEW_MATRIX[2].y, 0.0, 1.0);
	float cos_pitch = max(length(INV_VIEW_MATRIX[2].xz), 0.25);
	float root_height = max((VERTEX.y + root_offset) * size, 0.0);
	float upright_depth = root_height * sin_pitch / cos_pitch;
	VERTEX = vec3(VERTEX.x * size, height, upright_depth + 0.005);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec4 plant = texture(atlas, (cell + UV) / ATLAS_GRID);
	// Coverage is a cutout, not translucent foliage. Keep surviving pixels in
	// the opaque depth pass so MultiMesh instance order cannot affect blending.
	float cutoff = overhead > 0.5 ? (TRUNK_ALPHA + 1.0) * 0.5 : 0.5;
	if (plant.a < cutoff) {
		discard;
	}
	ALBEDO = pow(plant.rgb, vec3(2.2));
	vec2 q = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0) * CELL_PADDING;
	vec2 crown = (q - crown_center) / crown_radius;
	float roundness = sqrt(max(1.0 - dot(crown, crown), 0.0));
	vec3 surface = VERTEX;
	surface.z += roundness * plant_size * 0.35;
	vec4 clip = PROJECTION_MATRIX * vec4(surface, 1.0);
	float ndc_depth = clip.z / clip.w;
	DEPTH = CLIP_SPACE_FAR == -1.0 ? ndc_depth * 0.5 + 0.5 : ndc_depth;
}
