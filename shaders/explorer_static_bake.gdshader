// Renders everything on the chart that never moves, once, into textures the
// per-frame chart shader samples. The image covers the whole chart; row 0 is
// the far (-z) edge, matching the plane mesh.
//   layer 0 (half float): R coast distance, G land height, B boulder distance, A boulder light
//   layer 1 (8-bit):      R ring wobble, G breath phase, B surf jitter, A edge wear
//   layer 2 (8-bit):      RGB painted colour (land, or paper under the sea), A paper brightness
shader_type canvas_item;
// Raw values, not colours: never blend with the clear colour.
render_mode blend_disabled;

uniform int layer = 0;
uniform vec2 chart_size = vec2(20.0, 13.5);
// Bake texels per screen pixel at the default zoom, so baked ink keeps its weight.
uniform float line_scale = 1.0;

#include "res://shaders/explorer_geography.gdshaderinc"
#include "res://shaders/explorer_palette.gdshaderinc"

float paint_line(float field, float width_px) {
	float w = max(fwidth(field), 1e-5);
	float width = width_px * line_scale;
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + 1.0, abs(field) / w);
}

// Cellular noise. f1: distance to the nearest feature point. edge: distance to
// the border between the two nearest cells. to_feature: offset from p to that
// point. cell: integer id of its cell. All in cell units.
void voronoi(vec2 p, out float f1, out float edge, out vec2 to_feature, out vec2 cell) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash12(i + g), hash12(i + g + 17.31));
			vec2 r = g + o - f;
			float dd = dot(r, r);
			if (dd < best) {
				best = dd;
				to_feature = r;
				cell = i + g;
			}
		}
	}
	f1 = sqrt(best);
	edge = 8.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash12(i + g), hash12(i + g + 17.31));
			vec2 r = g + o - f;
			vec2 diff = r - to_feature;
			if (dot(diff, diff) > 1e-5) {
				edge = min(edge, dot(0.5 * (to_feature + r), normalize(diff)));
			}
		}
	}
}

vec3 parchment(vec2 p) {
	vec3 c = PAPER;
	float mottle = fbm(p * 0.35 + 3.1);
	c *= 0.9 + 0.16 * mottle;
	float stain_field = fbm(p * 0.21 + 11.0);
	float stain = smoothstep(0.56, 0.72, stain_field);
	float tide_mark = 1.0 - smoothstep(0.0, 0.015, abs(stain_field - 0.58));
	c = mix(c, vec3(0.72, 0.60, 0.43), stain * 0.22 + tide_mark * 0.12);
	vec2 fiber_p = mat2(vec2(0.94, 0.34), vec2(-0.34, 0.94)) * p;
	float fibers = vnoise(fiber_p * vec2(1.4, 34.0)) * vnoise(fiber_p * vec2(3.0, 9.0));
	c *= 0.98 + 0.04 * fibers;
	float grain = vnoise(p * 95.0) * 0.6 + vnoise(p * 40.0) * 0.4;
	c *= 0.95 + 0.08 * grain;
	return c;
}

// Craquelure: a warped cell network of fine cracks across the old paper.
float paper_cracks(vec2 p) {
	vec2 warped = p + vec2(fbm(p * 0.8 + 70.0), fbm(p * 0.8 + 90.0)) * 0.9;
	float f1;
	float edge;
	vec2 to_feature;
	vec2 cell;
	voronoi(warped * 0.9, f1, edge, to_feature, cell);
	float big = paint_line(edge, 0.9);
	voronoi(warped * 2.3 + 5.0, f1, edge, to_feature, cell);
	float small = paint_line(edge, 0.7) * smoothstep(0.45, 0.6, vnoise(p * 1.5 + 30.0));
	return max(big * 0.8, small * 0.5) * (0.5 + 0.5 * vnoise(p * 4.0));
}

float edge_wear(vec2 p) {
	vec2 e = abs(p) / (chart_size * 0.5);
	float edge = pow(pow(e.x, 6.0) + pow(e.y, 6.0), 1.0 / 6.0);
	return edge + (fbm(p * 1.3 + 40.0) - 0.5) * 0.10 + (vnoise(p * 9.0) - 0.5) * 0.02;
}

float height_at(vec2 p) {
	float d;
	float shelf;
	float rockiness;
	land_field(p, d, shelf, rockiness);
	return d < 0.0 ? land_height(p, d, shelf, rockiness) : 0.0;
}

// Distance (in boulder-cell units) to the nearest boulder scattered in the
// shallows, taking every neighbouring cell into account so rings are never clipped.
float boulder_field(vec2 p, out float lit) {
	vec2 cp = p * 3.2;
	vec2 i = floor(cp);
	vec2 f = fract(cp);
	float best = 1.0;
	lit = 0.6;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 cell = i + g;
			vec2 o = vec2(hash12(cell), hash12(cell + 17.31));
			vec2 center = (cell + o) / 3.2;
			float bd;
			float bshelf;
			float brock;
			land_field(center, bd, bshelf, brock);
			float near_coast = 1.0 - smoothstep(0.1, 0.5 + brock * 0.5, bd);
			float cluster = smoothstep(0.45, 0.65, fbm(center * 1.1 + 80.0)) + brock * 0.6;
			float chance = hash12(cell + 41.0);
			if (bd < 0.12 || chance < 1.0 - near_coast * clamp(cluster, 0.0, 1.0) * 0.8) {
				continue;
			}
			vec2 r = g + o - f;
			float radius = 0.1 + 0.2 * hash12(cell + 7.0) * hash12(cell + 9.0) * 1.6;
			// Lumpy outline instead of a clean disc.
			float lump = (vnoise(cp * 6.0 + cell * 3.1) - 0.5) * 0.35 * radius;
			float ring = length(r) - radius + lump;
			if (ring < best) {
				best = ring;
				vec2 bn = -r / radius;
				lit = clamp(0.7 + dot(bn, vec2(-0.6, -0.7)) * 0.4, 0.3, 1.1) * (0.9 + 0.2 * hash12(cell));
			}
		}
	}
	return best;
}

vec4 bake_geometry(vec2 p) {
	float d;
	float shelf;
	float rockiness;
	land_field(p, d, shelf, rockiness);
	float lit;
	float boulders = boulder_field(p, lit);
	return vec4(d, height_at(p), boulders, lit);
}

vec4 bake_coast_fields(vec2 p) {
	float wobble = (vnoise(p * 2.6) - 0.5) * 0.06 + (vnoise(p * 9.0) - 0.5) * 0.015;
	return vec4(wobble / 0.1 + 0.5, vnoise(p * 0.4), vnoise(p * 5.0), clamp(edge_wear(p) / 1.25, 0.0, 1.0));
}

vec4 bake_paint(vec2 p) {
	float d;
	float shelf;
	float rockiness;
	land_field(p, d, shelf, rockiness);
	vec3 paper = parchment(p);
	float cracks = paper_cracks(p);
	float brightness = paper.g / PAPER.g;

	if (d > 0.0) {
		// Clear blue wash over the paper, pooled deeper away from shore.
		float depth = smoothstep(0.0, 3.0, d + (fbm(p * 0.7 + 5.0) - 0.5) * 1.1);
		vec3 pigment = mix(SHALLOWS, DEEP_WATER, depth);
		float bloom = fbm(p * 0.55 + 20.0);
		float pooling = 1.0 - smoothstep(0.0, 0.035, abs(bloom - 0.52));
		float density = mix(0.5, 0.8, depth) * (0.85 + 0.3 * bloom) + pooling * 0.08;
		density *= 0.93 + 0.14 * vnoise(p * 6.0);
		vec3 sea = mix(paper, pigment * (0.88 + 0.2 * paper), clamp(density, 0.0, 0.88));
		sea = mix(sea, SEPIA, cracks * 0.08);
		return vec4(sea, brightness / 1.3);
	}

	float e = 0.02;
	float h0 = height_at(p);
	vec3 n = normalize(vec3(h0 - height_at(p + vec2(e, 0.0)), e, h0 - height_at(p + vec2(0.0, e))));
	vec3 l = normalize(SUN_DIR);
	float lambert = dot(n, l);
	float flat_lambert = l.y;

	// Pale parchment with sand, boulder cliffs and a darker woodland floor.
	float inland = -d;
	float jitter = rim_jitter(p);
	float slope = 1.0 - n.y;
	vec3 land = paper * 1.02;
	land = mix(land, SEPIA, cracks * 0.3);
	float sand_band = 1.0 - smoothstep(shelf * 0.8, shelf + 0.1, inland);
	float stipple = step(0.86, hash12(floor(p * 90.0))) * 0.25;
	land = mix(land, SAND * (0.95 + 0.1 * paper) * (1.0 - stipple), sand_band * 0.7 * (1.0 - rockiness));

	// Cliffs and rocks broken into chunky, outlined boulders.
	float cliff = smoothstep(0.22, 0.45, slope);
	float stone_mix = max(cliff, rockiness * smoothstep(0.03, 0.1, inland));
	float cf1;
	float cedge;
	vec2 cto;
	vec2 ccell;
	voronoi(p * 7.0 + vec2(0.0, h0 * 6.0), cf1, cedge, cto, ccell);
	float steps = floor(clamp(lambert, 0.0, 1.0) * 3.0 + 0.5) / 3.0;
	float chunk_lit = clamp(steps * 0.7 + 0.35 + (hash12(ccell) - 0.5) * 0.3 - cf1 * 0.25, 0.0, 1.0);
	vec3 stone_col = mix(STONE * 0.68, STONE_LIGHT, chunk_lit);
	land = mix(land, stone_col, stone_mix);
	land = mix(land, SEPIA, paint_line(cedge, 1.0) * stone_mix * 0.75);
	// Diagonal hatching, 5 screen pixels apart at the default zoom.
	float hatch_lines = abs(fract((p.x + p.y) / 0.08) - 0.5) * 5.0;
	float hatch = (1.0 - smoothstep(0.5, 1.2, hatch_lines)) * smoothstep(0.35, 0.55, vnoise(p * 6.0 + 3.0));
	land = mix(land, SEPIA, hatch * stone_mix * (1.0 - smoothstep(0.2, 0.6, lambert)) * 0.18);

	// Soft ground shading on the tops.
	land *= mix(0.95 + 0.12 * (lambert - flat_lambert), 1.0, stone_mix);

	// Darker woodland floor; the tree sprites (chart_flora.gd) stand on top of it.
	float plateau = smoothstep(shelf + 0.1, shelf + 0.25, inland + jitter) * (1.0 - rockiness);
	float grove_floor = smoothstep(0.43, 0.49, grove_field(p)) * plateau;
	land = mix(land, CANOPY_DARK * 1.25, grove_floor * 0.45 * (1.0 - stone_mix));

	// Sepia rim and cliff-foot outlines.
	float rim = paint_line(inland - (shelf + jitter + 0.09), 1.4) * (1.0 - rockiness);
	float foot = paint_line(inland - (shelf + jitter), 1.0) * (1.0 - rockiness) * 0.6;
	float upper_rim = paint_line(inland - (shelf + 0.52 + jitter * 2.0), 1.2) * (1.0 - rockiness) * 0.8;
	land = mix(land, SEPIA, max(max(rim, foot), upper_rim) * 0.85);
	return vec4(land, brightness / 1.3);
}

void fragment() {
	vec2 p = (UV - 0.5) * chart_size;
	if (layer == 0) {
		COLOR = bake_geometry(p);
	} else if (layer == 1) {
		COLOR = bake_coast_fields(p);
	} else {
		COLOR = bake_paint(p);
	}
}
