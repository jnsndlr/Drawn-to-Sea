// Hand-inked plant drawings: cloud-lobed trees, bushes and palms, drawn in
// sprite space q (-1..1, y up). Baked once into an atlas by flora_atlas_bake.

#include "res://shaders/explorer_geography.gdshaderinc"

const vec3 INK = vec3(0.20, 0.15, 0.09);
const vec3 LEAF_DARK = vec3(0.31, 0.37, 0.20);
const vec3 LEAF_MID = vec3(0.50, 0.55, 0.33);
const vec3 LEAF_LIGHT = vec3(0.73, 0.75, 0.51);
const vec3 BLOSSOM = vec3(0.87, 0.85, 0.68);
const vec3 BARK = vec3(0.42, 0.31, 0.19);
const vec3 BARK_LIGHT = vec3(0.72, 0.58, 0.38);
const vec3 KEY_LIGHT = vec3(-0.45, 0.55, 0.70);

float h11(float x) {
	return fract(sin(x * 127.1 + 311.7) * 43758.5453);
}

// Atlas texels per screen pixel for a typical plant at the default zoom.
uniform float line_scale = 1.0;

float ink_line(float field, float width_px) {
	float w = max(fwidth(field), 1e-5);
	float width = width_px * line_scale;
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + 1.0, abs(field) / w);
}

float lobe_sdf(vec2 q, vec2 c, float r, float s) {
	vec2 rel = q - c;
	float a = atan(rel.y, rel.x);
	float bumps = 0.07 * r * sin(a * 7.0 + s * 20.0) + 0.045 * r * sin(a * 11.0 + s * 9.0);
	return length(rel) - r - bumps;
}

// Cloud-like crown of overlapping lobes, painted back to front.
// Returns the silhouette distance; writes colour into col.
float crown(vec2 q, vec2 center, float ring, float lobe_r, int lobes, float s, bool blossom, out vec3 col) {
	float sil = 1e3;
	float top = 1e3;
	vec2 top_c = center;
	float top_r = lobe_r;
	for (int pass = 0; pass < 2; pass++) {
		for (int i = 0; i < 9; i++) {
			if (i >= lobes) {
				break;
			}
			float fi = float(i);
			float a = fi / float(lobes) * TAU + s * TAU;
			bool back = sin(a) >= 0.0;
			if ((pass == 0) != back) {
				continue;
			}
			vec2 c = center + vec2(cos(a), sin(a) * 0.8) * ring * (0.85 + 0.3 * h11(s * 13.0 + fi));
			float r = lobe_r * (0.8 + 0.35 * h11(s * 7.0 + fi * 3.1));
			float dist = lobe_sdf(q, c, r, s + fi);
			sil = min(sil, dist);
			if (dist < 0.0) {
				top = dist;
				top_c = c;
				top_r = r;
			}
		}
	}
	// Central lobe sits on top of the ring.
	vec2 cc = center + vec2(0.0, 0.05) * ring;
	float cr = lobe_r * 1.05;
	float cd = lobe_sdf(q, cc, cr, s + 40.0);
	sil = min(sil, cd);
	if (cd < 0.0) {
		top = cd;
		top_c = cc;
		top_r = cr;
	}

	vec2 rel = (q - top_c) / top_r;
	float nz = sqrt(max(1.0 - dot(rel, rel), 0.0));
	float lit = dot(normalize(vec3(rel, nz)), normalize(KEY_LIGHT));
	col = mix(LEAF_DARK, LEAF_MID, smoothstep(-0.1, 0.5, lit));
	col = mix(col, LEAF_LIGHT, smoothstep(0.62, 0.95, lit) * 0.85);
	// Darken where one lobe tucks under the next, then ink the crease.
	col *= 0.8 + 0.2 * smoothstep(0.0, 0.14 * top_r, -top);
	float leaves = vnoise(q * 14.0 + s * 50.0);
	col = mix(col, LEAF_DARK, ink_line(leaves - 0.5, 0.8) * 0.25);
	col = mix(col, INK, ink_line(top, 1.0) * 0.4);
	if (blossom) {
		float dot_d = length(q - (cc + vec2(-0.25, 0.3) * cr)) - 0.16 * cr;
		col = mix(col, BLOSSOM, 1.0 - smoothstep(-0.01, 0.0, dot_d));
		col = mix(col, INK, ink_line(dot_d, 0.8) * 0.7);
	}
	return sil;
}

float palm(vec2 q, float s, out vec3 col) {
	float bend = (h11(s * 5.0) - 0.5) * 0.7;
	vec2 top = vec2(bend, 0.3);
	float t = (q.y + 0.97) / (top.y + 0.97);
	float trunk = abs(q.x - bend * t * t) - mix(0.075, 0.045, t);
	trunk = max(trunk, max(-t, t - 1.0) * 0.5);
	col = mix(BARK, BARK_LIGHT, smoothstep(0.0, 0.05, bend * t * t - q.x + 0.03));
	col = mix(col, INK, step(fract(t * 10.0), 0.14) * 0.5);
	float sil = trunk;

	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float a = mix(-0.35, 3.49, fi / 6.0) + (h11(s * 3.0 + fi) - 0.5) * 0.35;
		float len = 0.5 + 0.2 * h11(s * 9.0 + fi);
		vec2 dir = vec2(cos(a), sin(a));
		vec2 perp = vec2(-dir.y, dir.x);
		vec2 rel = q - top;
		float u0 = max(dot(rel, dir), 0.0);
		// Fronds droop under their own weight.
		rel += vec2(0.0, 0.7 * u0 * u0);
		float u = dot(rel, dir);
		float v = dot(rel, perp);
		float along = clamp(u / len, 0.0, 1.0);
		float width = 0.12 * pow(sin(3.14159 * along), 0.7) * (0.65 + 0.35 * abs(sin(u * 48.0)));
		float frond = max(abs(v) - width, max(-u, u - len));
		if (frond < 0.0) {
			col = mix(LEAF_DARK, LEAF_MID, v > 0.0 ? 1.0 : 0.45);
			col = mix(col, LEAF_LIGHT, smoothstep(0.3, 1.0, dir.y) * 0.4);
			col = mix(col, INK, ink_line(v, 0.3) * 0.45);
		}
		sil = min(sil, frond);
	}
	return sil;
}

// Kinds: 0 tree, 1 bush, 2 palm. Returns sRGB colour and coverage; trunk-only
// pixels get coverage TRUNK_ALPHA so the sprite can hide them from overhead.
const float TRUNK_ALPHA = 0.62;

vec4 draw_plant(vec2 q, int plant_kind, float s) {
	vec3 col;
	float sil;
	float trunk_only = 0.0;
	if (plant_kind == 2) {
		sil = palm(q, s, col);
	} else if (plant_kind == 1) {
		int lobes = 4 + int(h11(s * 17.0) * 3.0);
		sil = crown(q, vec2(0.0, -0.3), 0.3, 0.34, lobes, s, false, col);
	} else {
		int lobes = 6 + int(h11(s * 17.0) * 4.0);
		sil = crown(q, vec2(0.0, 0.02), 0.4, 0.36, lobes, s, h11(s * 23.0) > 0.35, col);
		// Short trunk peeking out under the crown.
		float lean = (h11(s * 29.0) - 0.5) * 0.1;
		float trunk = abs(q.x - lean * (q.y + 1.0)) - 0.07;
		trunk = max(trunk, max(-0.97 - q.y, q.y + 0.5));
		float crown_px = sil / max(fwidth(sil), 1e-5);
		if (trunk < 0.0 && sil > 0.0) {
			col = mix(BARK, BARK_LIGHT, step(q.x, lean * (q.y + 1.0)) * 0.6);
		}
		trunk_only = step(1.5 * line_scale, crown_px);
		sil = min(sil, trunk);
	}
	// Palm fronds are slender, so they take a finer outline.
	col = mix(col, INK, ink_line(sil, plant_kind == 2 ? 0.6 : 1.4));
	float px = sil / max(fwidth(sil), 1e-5);
	float coverage = 1.0 - smoothstep(0.5, 1.5, px);
	return vec4(col, coverage * mix(1.0, TRUNK_ALPHA, trunk_only));
}
