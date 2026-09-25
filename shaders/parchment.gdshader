shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float wave_time = 0.0;
uniform float wave_height : hint_range(0.0, 0.5) = 0.035;
uniform float crest_width : hint_range(0.005, 0.08) = 0.012;
uniform vec4 water_color : source_color = vec4(0.48, 0.63, 0.60, 1.0);
uniform vec4 water_ink : source_color = vec4(0.24, 0.36, 0.34, 1.0);
uniform float wave_speed : hint_range(0.0, 2.0) = 0.22;
uniform float line_visibility : hint_range(0.0, 1.0) = 0.48;
uniform float shore_motion : hint_range(0.0, 0.1) = 0.045;
uniform float cell_size : hint_range(0.5, 2.5) = 1.0;
varying vec2 map_position;
varying vec3 terrain_position;
uniform float terrain_height : hint_range(0.0, 2.0) = 1.0;

uniform float wave_ink_strength : hint_range(0.0, 1.0) = 0.65;
uniform float shore_ink_strength : hint_range(0.0, 1.0) = 0.65;
uniform vec4 paper_color : source_color = vec4(0.82, 0.73, 0.53, 1.0);
uniform vec4 ink_color : source_color = vec4(0.22, 0.14, 0.075, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
// CPU collision and GPU terrain sample the identical baked coastline field.
uniform sampler2D geography_map : filter_linear, repeat_disable;
float rock_distance(vec2 p) {
	return texture(geography_map, p / vec2(18.0, 12.0) + 0.5).g;
}
float island_distance(vec2 p) {
	return texture(geography_map, p / vec2(18.0, 12.0) + 0.5).r;
}
float coast(vec2 p) {
	return min(island_distance(p), rock_distance(p));
}
#include "res://shaders/terrain.gdshaderinc"
// Both stages use the original mesh position, never UV orientation, for the mask.
float water_mask(vec2 p) {
	float shore_mask = smoothstep(0.18, 0.75, coast(p));
	vec2 margin = vec2(9.0, 6.0) - abs(p);
	return shore_mask * smoothstep(0.7, 1.2, min(margin.x, margin.y));
}
// A small directional ocean spectrum: long swell, wind waves and cross chop.
// Gravity dispersion gives each wavelength its own speed. Fixed seeds preserve
// a coherent moving surface rather than changing random noise every frame.
// Returns height, horizontal gradient, and curvature along the prevailing wind.
vec4 ocean(vec2 p) {
	vec4 field = vec4(0.0);
	vec2 wind = normalize(vec2(0.4, 1.0));
	for (int i = 0; i < 14; i++) {
		float seed = float(i);
		float frequency = 1.1 * pow(1.22, seed);
		float angle = seed * 2.399963 + (hash(vec2(seed, 7.0)) - 0.5) * 0.4;
		vec2 direction = vec2(cos(angle), sin(angle));
		float amplitude = pow(frequency, -1.15) * 0.32;
		float phase = dot(direction, p) * frequency
			- sqrt(9.81 * frequency) * wave_time * wave_speed
			+ hash(vec2(seed, 19.0)) * 6.283185;
		// A second harmonic produces steeper crests and broader troughs.
		float h = sin(phase) - 0.18 * cos(2.0 * phase);
		float slope = cos(phase) + 0.36 * sin(2.0 * phase);
		float curvature = -sin(phase) + 0.72 * cos(2.0 * phase);
		float along_wind = dot(direction, wind) * frequency;
		field.x += amplitude * h;
		field.yz += amplitude * frequency * direction * slope;
		field.w += amplitude * along_wind * along_wind * curvature;
	}
	return field;
}
// Smooth space-time value noise. Time is a third coordinate: features evolve
// locally, rather than translating a static 2D texture across the map.
float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	// Quintic interpolation keeps first and second derivatives continuous.
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(
		mix(mix(hash3(cell), hash3(cell + vec3(1,0,0)), u.x),
			mix(hash3(cell + vec3(0,1,0)), hash3(cell + vec3(1,1,0)), u.x), u.y),
		mix(mix(hash3(cell + vec3(0,0,1)), hash3(cell + vec3(1,0,1)), u.x),
			mix(hash3(cell + vec3(0,1,1)), hash3(cell + vec3(1,1,1)), u.x), u.y), u.z);
}
float wave_cells(vec2 position) {
	vec2 p = position / cell_size;
	float t = wave_time * wave_speed;
	// Independent warps bend the cells in different directions. Rotated octaves
	// avoid an obvious lattice, with less amplitude at finer scales.
	vec2 warp = vec2(noise3(vec3(p * 0.55, t * 0.19)),
		noise3(vec3(p * 0.55 + vec2(19.1, 7.3), -t * 0.16))) - 0.5;
	vec2 q = p * vec2(0.85, 1.8) + warp * 0.85;
	mat2 rotation = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float field = noise3(vec3(q, t * 0.23)) * 0.64;
	q = rotation * q * 2.03 + vec2(5.2, 13.7);
	field += noise3(vec3(q, -t * 0.31 + 9.4)) * 0.25;
	q = rotation * q * 2.01 + vec2(8.3, 2.8);
	field += noise3(vec3(q, t * 0.4 + 21.1)) * 0.11;
	return field;
}
void vertex() {
	map_position = VERTEX.xz;
	float height = ocean(map_position).x * 0.5 + (wave_cells(map_position) - 0.5);
	VERTEX.y += water_mask(map_position) * wave_height * height;
	VERTEX.y += land_height(map_position) * terrain_height;
	terrain_position = VERTEX;
}
float drawn_waves(vec2 p) {
	float field = wave_cells(p);
	// Isolines can join and split as the continuous field crosses a saddle.
	// Pixel derivatives keep fine ink lines smooth at different zoom levels.
	float band = abs(fract(field * 5.0 + 0.15) - 0.5) / 5.0;
	float aa = max(fwidth(field), 0.0008);
	float width = crest_width * 0.24;
	float line = 1.0 - smoothstep(width, width + aa, band);
	float t = wave_time * wave_speed;
	float visibility = noise3(vec3(p * 1.75 + vec2(4.8, 17.2), t * 0.21 + 8.0));
	float fragments = smoothstep(1.0 - line_visibility, 1.18 - line_visibility, visibility);
	return line * fragments * smoothstep(0.0, 0.05, line_visibility);
}
void fragment() {
	vec2 p = map_position;
	float d = coast(p);
	float grain = noise(p * 120.0);
	float mottling = noise(p * 0.7) * 0.65 + noise(p * 3.0) * 0.35;
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float aging = 0.83 + 0.17 * smoothstep(0.0, 0.09, edge + noise(p * 4.0) * 0.015);
	vec3 paper = paper_color.rgb + (mottling - 0.5) * 0.13 + (grain - 0.5) * 0.065;
	// Transparent, uneven watercolor pigment lets the parchment show through.
	float wet_edge = d + (noise(p * 6.0) - 0.5) * 0.08;
	float sea = smoothstep(0.015, 0.13, wet_edge);
	float depth = smoothstep(0.05, 1.8, d);
	float pigment = 0.42 + depth * 0.3 + (noise(p * 0.55) - 0.5) * 0.28;
	pigment += (noise(p * 5.0) - 0.5) * 0.1;
	float paper_margin = smoothstep(0.03, 0.13, edge + (noise(p * 1.4) - 0.5) * 0.035);
	vec3 wash = water_color.rgb + (mottling - 0.5) * 0.12 + (grain - 0.5) * 0.06;
	vec3 color = mix(paper, wash, sea * pigment * paper_margin);
	// The land outline stays fixed. Water-side contours gently advance and recede.
	float aa = max(fwidth(d), 0.003);
	float shore = 1.0 - smoothstep(0.012, 0.012 + aa, abs(d));
	float rings = 0.0;
	for (int i = 0; i < 4; i++) {
		float index = float(i);
		float time = wave_time * wave_speed;
		float local_phase = (noise(p * 0.55) - 0.5) * 1.5;
		float breath = sin(time * 1.1 - index * 0.65 + local_phase);
		float offset = 0.13 + index * 0.145 + shore_motion * breath;
		float wobble = (noise(p * (5.0 + index)) - 0.5) * 0.035;
		float ring = 1.0 - smoothstep(0.008, 0.008 + aa, abs(d - offset + wobble));
		float fade = 0.72 + 0.28 * sin(time * 0.85 - index * 0.8 + local_phase);
		rings += ring * (0.65 - index * 0.1) * fade;
	}
	float pressure = 0.5 + 0.5 * noise(p * 8.0);
	float marks = drawn_waves(p);
	marks *= smoothstep(0.4, 0.9, d) * paper_margin;
	float wave_ink = marks * 0.65 * wave_ink_strength;
	float shore_ink = rings * pressure * 0.65 * shore_ink_strength;
	color = mix(color, water_ink.rgb, clamp(wave_ink + shore_ink, 0.0, 1.0));
	// Occasional pale shoreline accents, as if left unpainted by the brush.
	float foam = (1.0 - smoothstep(0.008, 0.008 + aa, abs(d - (0.085 + 0.018 * sin(wave_time * wave_speed * 1.1 + (noise(p * 0.55) - 0.5) * 1.5))))) * smoothstep(0.35, 0.6, noise(p * 3.0));
	color = mix(color, paper_color.rgb + vec3(0.08), foam * 0.6);
	color = mix(color, ink_color.rgb, shore * pressure * shore_ink_strength);
	float border = 1.0 - smoothstep(0.0006, 0.0015, abs(edge - 0.035));
	color = mix(color, ink_color.rgb, border * 0.25);
	// Geometry-derived normals shade the actual raised surface, keeping pigment
	// anchored in object space while orbiting the camera.
	float land_mask = 1.0 - smoothstep(-0.025, 0.015, d);
	vec3 face_normal = normalize(cross(dFdx(terrain_position), dFdy(terrain_position)));
	if (face_normal.y < 0.0) { face_normal = -face_normal; }
	vec3 land_color = illustrated_terrain(terrain_position, face_normal, d, paper);
	color = mix(color, land_color, land_mask);
	ALBEDO = color * aging;
}
