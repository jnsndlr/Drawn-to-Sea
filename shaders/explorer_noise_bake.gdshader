// Tileable gradient-noise slices for the chart's animated water. The runtime
// shader cross-fades the three slices in RGB over time, so shapes form and fade
// in place without any per-pixel 3D noise. One tile spans 10 chart units.
//   layer 0: RGB ripple-stroke field slices, A static stroke taper
//   layer 1: RGB stroke keep-mask / swell-noise slices
shader_type canvas_item;
render_mode blend_disabled;

uniform int layer = 0;

#include "res://shaders/explorer_geography.gdshaderinc"

const float TILE = 10.0;

vec3 lattice(vec3 i, float period) {
	return hash33(vec3(mod(i.xy, period), i.z));
}

// Gradient noise that repeats every `period` lattice cells in x and y.
float periodic_noise(vec3 p, float period) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(lattice(i, period), f);
	float b = dot(lattice(i + vec3(1, 0, 0), period), f - vec3(1, 0, 0));
	float c = dot(lattice(i + vec3(0, 1, 0), period), f - vec3(0, 1, 0));
	float d = dot(lattice(i + vec3(1, 1, 0), period), f - vec3(1, 1, 0));
	float e = dot(lattice(i + vec3(0, 0, 1), period), f - vec3(0, 0, 1));
	float g = dot(lattice(i + vec3(1, 0, 1), period), f - vec3(1, 0, 1));
	float h = dot(lattice(i + vec3(0, 1, 1), period), f - vec3(0, 1, 1));
	float k = dot(lattice(i + vec3(1, 1, 1), period), f - vec3(1, 1, 1));
	return mix(mix(mix(a, b, u.x), mix(c, d, u.x), u.y), mix(mix(e, g, u.x), mix(h, k, u.x), u.y), u.z);
}

// Frequencies are whole numbers of cells per tile so every octave wraps.
float stroke_field(vec2 q, float z) {
	return periodic_noise(vec3(q * 0.9, z), 9.0) * 0.8 + periodic_noise(vec3(q * 2.2, z + 5.0), 22.0) * 0.2;
}

float keep_field(vec2 q, float z) {
	return periodic_noise(vec3(q * 2.2, z + 20.0), 22.0);
}

void fragment() {
	vec2 q = UV * TILE;
	if (layer == 0) {
		COLOR = vec4(stroke_field(q, 0.0), stroke_field(q, 1.7), stroke_field(q, 3.4), periodic_noise(vec3(q * 4.0, 30.0), 40.0));
	} else {
		COLOR = vec4(keep_field(q, 0.0), keep_field(q, 1.7), keep_field(q, 3.4), 0.0);
	}
}
