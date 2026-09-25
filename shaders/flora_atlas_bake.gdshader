// Bakes a grid of plant variants into one atlas the billboard sprites sample:
// row 0-1 trees, row 2 bushes, row 3 palms (ATLAS_COLUMNS each).
shader_type canvas_item;
render_mode blend_disabled;

#include "res://shaders/flora_draw.gdshaderinc"

const vec2 ATLAS_GRID = vec2(8.0, 4.0);
// Keep drawings off the cell border so mipmaps never bleed between variants.
const float CELL_PADDING = 1.06;

void fragment() {
	vec2 cell = floor(UV * ATLAS_GRID);
	vec2 local = fract(UV * ATLAS_GRID);
	vec2 q = vec2(local.x * 2.0 - 1.0, 1.0 - local.y * 2.0) * CELL_PADDING;
	int index = int(cell.y * ATLAS_GRID.x + cell.x);
	int plant_kind = cell.y < 2.0 ? 0 : (cell.y < 3.0 ? 1 : 2);
	COLOR = draw_plant(q, plant_kind, h11(float(index) * 7.31 + 1.0));
}
