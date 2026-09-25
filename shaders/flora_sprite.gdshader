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
// 0 at the default oblique view, 1 looking straight down.
varying float overhead;

void vertex() {
	float index = INSTANCE_CUSTOM.r;
	cell = vec2(mod(index, ATLAS_GRID.x), floor(index / ATLAS_GRID.x));
	float size = INSTANCE_CUSTOM.b * CELL_PADDING;
	// Looking down from above, a plant should sit centred over its root rather than stand on it.
	overhead = smoothstep(0.8, 0.97, INV_VIEW_MATRIX[2].y);
	// The QuadMesh spans -0.5..0.5: stand it on its bottom edge, nudged toward the camera.
	VERTEX = vec3(VERTEX.x * size, (VERTEX.y + mix(0.5, 0.0, overhead)) * size, 0.05);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec4 plant = texture(atlas, (cell + UV) / ATLAS_GRID);
	ALBEDO = pow(plant.rgb, vec3(2.2));
	ALPHA = plant.a;
	// Trunks are stored at a lower coverage: raising the cut-off hides them from overhead.
	ALPHA_SCISSOR_THRESHOLD = overhead > 0.5 ? (TRUNK_ALPHA + 1.0) * 0.5 : 0.5;
}
