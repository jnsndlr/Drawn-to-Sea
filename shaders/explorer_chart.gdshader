// Antique explorer's chart: the per-frame surface. Everything that never moves
// (land painting, paper, coast distance, boulders) is baked once by
// explorer_static_bake.gdshader; this shader samples those textures and only
// animates the sea on top: swell relief, ripple strokes, surf and coastal rings.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec2 chart_size = vec2(20.0, 13.5);
uniform float time_scale = 1.0;
// Sea conditions, driven by the chart's control panel.
uniform float wave_clock = 0.0;
uniform float wave_height = 1.0;
uniform float wave_length = 1.0;
uniform float chop = 1.0;
uniform float noise_amount = 1.0;
uniform float wind_angle = 0.0;

// Baked by explorer_static_bake.gdshader (see its header for channels).
uniform sampler2D geometry_tex : filter_linear, repeat_disable;
uniform sampler2D coast_tex : filter_linear, repeat_disable;
uniform sampler2D paint_tex : filter_linear_mipmap, repeat_disable;
// Baked by explorer_noise_bake.gdshader: three time slices each, tiling every NOISE_TILE units.
uniform sampler2D stroke_noise : filter_linear, repeat_enable;
uniform sampler2D keep_noise : filter_linear, repeat_enable;

#include "res://shaders/explorer_palette.gdshaderinc"

const float NOISE_TILE = 10.0;

varying vec2 chart_p;
varying vec3 water_normal;

vec2 chart_uv(vec2 p) {
	return p / chart_size + 0.5;
}

// Cross-fade weights for the three baked noise slices, normalised so the blend
// keeps the same contrast all the way around the cycle.
vec3 slice_weights(float phase) {
	vec3 w = 0.5 + 0.5 * cos(phase - vec3(0.0, 2.0944, 4.1888));
	return w / length(w);
}

// Pixel-width ink line along the zero set of a field, given the field's
// screen-space rate of change (taken outside any branch: derivatives are
// undefined inside divergent control flow).
float ink_line_fw(float field, float fw, float width_px) {
	return 1.0 - smoothstep(width_px * 0.5, width_px * 0.5 + 1.0, abs(field) / max(fw, 1e-5));
}

float ink_line(float field, float width_px) {
	return ink_line_fw(field, fwidth(field), width_px);
}

// ----------------------------------------------------------------- water ---

float swell(vec2 p, vec2 dir, float freq, float speed, float phase, float t) {
	return sin(dot(p, normalize(dir)) * freq - t * speed + phase);
}

// t is the wave clock: the script advances it by speed so speed changes never jump.
float water_height(vec2 p, float t) {
	float s = sin(wind_angle);
	float c = cos(wind_angle);
	p = mat2(vec2(c, s), vec2(-s, c)) * p / max(wave_length, 0.05);
	// Long overlapping swells.
	float h = 0.040 * swell(p, vec2(0.8, 0.6), 0.85, 0.50, 0.0, t);
	h += 0.030 * swell(p, vec2(0.45, -0.9), 1.25, 0.62, 1.3, t);
	// Smaller wind waves and cross-chop.
	float wind = 0.014 * swell(p, vec2(-0.9, 0.35), 3.0, 1.20, 2.1, t);
	wind += 0.010 * swell(p, vec2(0.25, 1.0), 4.6, 1.55, 0.4, t);
	wind += 0.006 * swell(p, vec2(1.0, -0.2), 7.3, 2.10, 4.2, t);
	h += wind * chop;
	// Organic noise swell so the surface never reads as pure sine bands.
	// keep_noise has 2.2 cells per unit, so scale lookups to the wanted frequency.
	vec3 w = slice_weights(t * 0.3);
	float n = 0.022 * dot(textureLod(keep_noise, p * (0.9 / 2.2) / NOISE_TILE, 0.0).rgb, w);
	n += 0.012 * dot(textureLod(keep_noise, (p * (2.3 / 2.2) + 11.0) / NOISE_TILE, 0.0).rgb, w);
	h += n * noise_amount;
	return h * wave_height;
}

// Many fine, broken ripple strokes that form and fade in place.
float ripple_lines(vec2 p, float t) {
	vec2 q = vec2(p.x * 0.3 + p.y * 0.08, p.y * 2.4 - p.x * 0.08);
	float n = dot(texture(stroke_noise, q / NOISE_TILE).rgb, slice_weights(t * 0.3));
	float line = ink_line(fract(n * 6.0 + 0.5) - 0.5, 0.7);
	float keep = dot(texture(keep_noise, (p + 4.1) / NOISE_TILE).rgb, slice_weights(t * 0.7 + 1.0));
	line *= smoothstep(0.0, 0.12, keep);
	float taper = texture(stroke_noise, p / NOISE_TILE).a;
	line *= 0.5 + 0.5 * smoothstep(-0.2, 0.3, taper);
	return line;
}

// Breathing coastal rings, each a pale foam line with a thin dark edge outside it.
// x = foam, y = ink.
vec2 shore_rings(vec2 p, float d, float fw_d, float t, vec4 coast) {
	float dw = d + (coast.r - 0.5) * 0.1;
	float phase = coast.g * 2.5;
	vec2 rings = vec2(0.0);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float offset = 0.09 + fi * 0.11 + fi * fi * 0.025;
		float breath = (0.025 + fi * 0.01) * sin(t * 0.85 - fi * 0.75 + phase);
		float r = dw - offset - breath;
		float gap_noise = texture(keep_noise, (p * ((2.6 + fi * 0.8) / 2.2) + fi * 7.3 + vec2(0.0, t * 0.04)) / NOISE_TILE).r;
		float gaps = smoothstep(-0.25, -0.1, gap_noise);
		float keep = mix(1.0, gaps, 0.1 + fi * 0.3) * (1.0 - fi * 0.2);
		rings.x = max(rings.x, ink_line_fw(r, fw_d, 1.8) * keep);
		rings.y = max(rings.y, ink_line_fw(r - 0.028, fw_d, 0.8) * keep);
	}
	return rings;
}

// ---------------------------------------------------------------- stages ---

void vertex() {
	chart_p = VERTEX.xz;
	vec4 geometry = textureLod(geometry_tex, chart_uv(chart_p), 0.0);
	float d = geometry.r;
	float sea = smoothstep(0.0, 0.7, d);
	// Swell lighting is low-frequency, so its normal is computed per vertex.
	float e = 0.05;
	float h = water_height(chart_p, wave_clock);
	float hx = water_height(chart_p + vec2(e, 0.0), wave_clock);
	float hz = water_height(chart_p + vec2(0.0, e), wave_clock);
	water_normal = normalize(vec3((h - hx) * sea, e, (h - hz) * sea));
	VERTEX.y = d < 0.0 ? geometry.g : h * sea;
}

void fragment() {
	vec2 p = chart_p;
	vec2 uv = chart_uv(p);
	float t = TIME * time_scale;

	vec4 coast = texture(coast_tex, uv);
	float wear = coast.a * 1.25;
	if (wear > 1.0) {
		discard;
	}
	vec4 geometry = texture(geometry_tex, uv);
	float d = geometry.r;
	vec4 paint = texture(paint_tex, uv);
	vec3 col = paint.rgb;

	// Derivatives first, outside every branch.
	float fw_d = fwidth(d);
	float boulder_ring = geometry.b;
	float fw_boulder = fwidth(boulder_ring);
	float ripples = ripple_lines(p, t);

	// Everything below animates the sea; land pixels keep their baked paint.
	if (d > -0.05) {
		vec3 sea = paint.rgb;
		// Soft-compress swell lighting so tall seas stay graded instead of clipping into blotches.
		vec3 l = normalize(SUN_DIR);
		float relief = (dot(normalize(water_normal), l) - l.y) * 4.0;
		sea *= 1.0 + relief / (1.0 + abs(relief)) * 0.16;
		sea = mix(sea, WAVE_INK, ripples * 0.3 * smoothstep(0.35, 0.9, d));

		if (d < 0.9) {
			// White surf hugging the coast, breathing in and out.
			float surf_reach = 0.05 + 0.025 * sin(t * 0.85 + coast.g * 2.5) + (coast.b - 0.5) * 0.03;
			float surf = 1.0 - smoothstep(surf_reach - 0.01, surf_reach + 0.01, d);
			sea = mix(sea, FOAM, surf * 0.85);
			sea = mix(sea, WAVE_INK, ink_line_fw(d - surf_reach - 0.012, fw_d, 0.8) * 0.7);

			vec2 rings = shore_rings(p, d, fw_d, t, coast);
			sea = mix(sea, FOAM, rings.x * 0.85);
			sea = mix(sea, WAVE_INK, rings.y * 0.65);
		}

		// Boulders scattered in the shallows, each with its own foam ring.
		if (boulder_ring < 0.3) {
			sea = mix(sea, FOAM, ink_line_fw(boulder_ring - 0.08, fw_boulder, 1.6) * 0.8);
			sea = mix(sea, WAVE_INK, ink_line_fw(boulder_ring - 0.13, fw_boulder, 0.8) * 0.55);
			vec3 boulder_col = mix(STONE * 0.7, STONE_LIGHT, geometry.a);
			sea = mix(sea, boulder_col, 1.0 - smoothstep(-0.02, 0.0, boulder_ring));
			sea = mix(sea, SEPIA, ink_line_fw(boulder_ring, fw_boulder, 1.2));
		}

		// Crisp, stable coastline in sepia.
		float land_cover = 1.0 - smoothstep(-0.5, 0.5, d / max(fw_d, 1e-5));
		col = mix(sea, paint.rgb, land_cover);
		col = mix(col, SEPIA, ink_line_fw(d, fw_d, 1.8) * 0.95);
	}

	// Faded, darkened chart edges.
	float fade = smoothstep(0.84, 0.99, wear);
	col = mix(col, PAPER * paint.a * 1.3 * EDGE_TINT, fade * 0.6);
	col = mix(col, SEPIA, smoothstep(0.97, 1.0, wear) * 0.7);

	// Palette is authored in sRGB; ALBEDO expects linear.
	ALBEDO = pow(col, vec3(2.2));
}
