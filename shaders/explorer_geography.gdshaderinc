// Explorer's chart geography: noise helpers and the island / rock distance
// field. Shared by the chart surface shader and the land-data bake so the
// painted map and the placed props always agree.

uniform float plateau_height = 0.55;

// ---------------------------------------------------------------- noise ----

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx) * 2.0 - 1.0;
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Gradient noise in 3D; the third axis is time so shapes evolve in place.
float gnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(hash33(i), f);
	float b = dot(hash33(i + vec3(1, 0, 0)), f - vec3(1, 0, 0));
	float c = dot(hash33(i + vec3(0, 1, 0)), f - vec3(0, 1, 0));
	float d = dot(hash33(i + vec3(1, 1, 0)), f - vec3(1, 1, 0));
	float e = dot(hash33(i + vec3(0, 0, 1)), f - vec3(0, 0, 1));
	float g = dot(hash33(i + vec3(1, 0, 1)), f - vec3(1, 0, 1));
	float h = dot(hash33(i + vec3(0, 1, 1)), f - vec3(0, 1, 1));
	float k = dot(hash33(i + vec3(1, 1, 1)), f - vec3(1, 1, 1));
	return mix(mix(mix(a, b, u.x), mix(c, d, u.x), u.y),
		mix(mix(e, g, u.x), mix(h, k, u.x), u.y), u.z);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	mat2 turn = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	for (int i = 0; i < 4; i++) {
		sum += amp * vnoise(p);
		p = turn * p;
		amp *= 0.5;
	}
	return sum / 0.9375;
}

// ------------------------------------------------------------ geography ----

float sd_ellipse(vec2 p, vec2 c, vec2 r) {
	return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float cove_field(vec2 p) {
	return sd_ellipse(p, vec2(-4.9, 4.55), vec2(1.45, 1.25));
}

float big_island(vec2 p) {
	float d = sd_ellipse(p, vec2(-5.2, 1.9), vec2(2.9, 1.9));
	d = smin(d, sd_ellipse(p, vec2(-3.1, 0.9), vec2(1.6, 1.2)), 0.8);
	d = smin(d, sd_ellipse(p, vec2(-7.0, 3.8), vec2(1.0, 1.15)), 0.7);
	d = smin(d, sd_ellipse(p, vec2(-3.1, 3.7), vec2(0.8, 1.0)), 0.6);
	d = -smin(-d, cove_field(p), 0.3);
	return d;
}

float small_island(vec2 p) {
	float d = sd_ellipse(p, vec2(5.0, -3.1), vec2(1.7, 1.2));
	d = smin(d, sd_ellipse(p, vec2(6.1, -2.3), vec2(0.9, 0.75)), 0.6);
	d = smin(d, sd_ellipse(p, vec2(3.9, -3.7), vec2(0.75, 0.55)), 0.5);
	return d;
}

float rock(vec2 p, vec2 c, float r, float turn) {
	vec2 q = p - c;
	float s = sin(turn);
	float co = cos(turn);
	q = mat2(vec2(co, s), vec2(-s, co)) * q;
	// Irregular faceted outline: intersection of a few skewed slabs.
	float d = max(abs(q.x * 0.95 + q.y * 0.30), abs(q.y * 1.10 - q.x * 0.25));
	d = max(d, abs(q.x * 0.70 - q.y * 0.80) * 1.05);
	d = max(d, abs(q.x * 0.55 + q.y * 0.85) * 0.98);
	return d - r + (vnoise(p * 11.0) - 0.5) * 0.07;
}

float rocks(vec2 p) {
	float d = rock(p, vec2(-0.6, 0.2), 0.36, 0.3);
	d = min(d, rock(p, vec2(0.9, -0.9), 0.26, 1.1));
	d = min(d, rock(p, vec2(1.7, 0.8), 0.21, 2.0));
	d = min(d, rock(p, vec2(7.2, 0.7), 0.31, 0.7));
	return d;
}

// d: signed distance to the coast (negative on land). shelf: sandy margin
// width. rockiness: 1 when the nearest land is an offshore rock.
void land_field(vec2 p, out float d, out float shelf, out float rockiness) {
	float warp = (fbm(p * 0.55 + 3.0) - 0.5) * 0.85 + (fbm(p * 2.4 + 17.0) - 0.5) * 0.2;
	float islands = min(big_island(p), small_island(p)) + warp;
	float r = rocks(p);
	d = min(islands, r);
	rockiness = step(r, islands);
	float cove_beach = 1.0 - smoothstep(-0.2, 1.0, cove_field(p));
	shelf = mix(0.13 + 0.08 * vnoise(p * 1.7), 0.55, cove_beach);
}

float rim_jitter(vec2 p) {
	return (vnoise(p * 5.0) - 0.5) * 0.10 + (vnoise(p * 14.0) - 0.5) * 0.04;
}

float land_height(vec2 p, float d, float shelf, float rockiness) {
	float inland = max(-d, 0.0);
	float jitter = rim_jitter(p);
	float sand = 0.04 * smoothstep(0.0, shelf, inland);
	float lower = smoothstep(shelf + jitter, shelf + jitter + 0.09, inland);
	float upper = smoothstep(shelf + 0.42 + jitter * 2.0, shelf + 0.52 + jitter * 2.0, inland);
	float top = plateau_height * (0.8 + 0.4 * fbm(p * 0.45));
	float island = sand + lower * top * 0.6 + upper * top * 0.4;
	float crag = 0.04 * smoothstep(0.0, 0.04, inland)
		+ smoothstep(0.04, 0.16, inland) * 0.42 * (0.75 + 0.6 * vnoise(p * 7.0));
	return mix(island, crag, rockiness);
}

// Woodland density; trees grow where this is high on the plateaus.
float grove_field(vec2 p) {
	return fbm(p * 0.9 + 60.0) + (vnoise(p * 3.0) - 0.5) * 0.2;
}
