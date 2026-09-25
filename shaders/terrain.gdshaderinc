// Relief and ink treatment share the same coast functions as the ocean.
float cliff_start(vec2 p) {
	// The south-facing cove has a wider beach and a gentler ascent.
	float beach = exp(-pow((p.x + 3.4) * 0.95, 2.0) - pow((p.y - 0.5) * 1.6, 2.0));
	return 0.13 + beach * 0.32;
}
float land_height(vec2 p) {
	float inland = -island_distance(p);
	float beach_width = cliff_start(p);
	float terrace = smoothstep(beach_width, beach_width + 0.22, inland);
	float rise = 0.62 + noise(p * 1.4) * 0.30 + noise(p * 4.2) * 0.025;
	float beach = smoothstep(0.0, beach_width, inland) * 0.055;
	float plateau = terrace * rise + beach;
	float rock = smoothstep(0.0, 0.28, -rock_distance(p)) * (0.5 + noise(p * 5.0) * 0.3);
	return max(plateau, rock);
}
vec3 illustrated_terrain(vec3 position, vec3 normal, float coast_distance, vec3 paper) {
	vec2 p = position.xz;
	float steep = 1.0 - smoothstep(0.45, 0.86, normal.y);
	vec3 stone = vec3(0.65, 0.55, 0.37);
	float light = dot(normal, normalize(vec3(-0.55, 0.85, -0.4)));
	float tone = light > 0.7 ? 1.0 : (light > 0.3 ? 0.87 : 0.7);
	vec3 base = mix(paper, stone, steep * 0.65) * tone;
	base += (noise(p * 18.0 + position.y * 3.0) - 0.5) * 0.045;
	// Sparse mossy washes on the plateau, leaving most parchment exposed.
	float moss = smoothstep(0.57, 0.8, noise(p * 2.0)) * smoothstep(0.5, 0.7, position.y) * (1.0 - steep);
	base = mix(base, vec3(0.48, 0.49, 0.30), moss * 0.38);
	// Draw the irregular cliff lip, without exposing every mesh triangle.
	float lip_distance = -island_distance(p) - cliff_start(p) - 0.22;
	float lip_aa = max(fwidth(lip_distance), 0.003);
	float lip = 1.0 - smoothstep(0.013, 0.013 + lip_aa, abs(lip_distance));
	// Vertical fractures and broken diagonal hatching articulate rock faces.
	float fracture_phase = (p.x + p.y * 0.73) * 8.0 + noise(p * 3.0) * 1.5 + position.y * 0.6;
	float fracture = abs(sin(fracture_phase));
	float cracks = (1.0 - smoothstep(0.045, 0.045 + fwidth(fracture_phase), fracture)) * steep;
	float hatch_phase = (p.x - p.y) * 48.0 + position.y * 35.0;
	float hatch = 1.0 - smoothstep(0.08, 0.08 + fwidth(hatch_phase), abs(sin(hatch_phase)));
	hatch *= steep * (1.0 - smoothstep(0.3, 0.7, light)) * smoothstep(0.4, 0.7, noise(p * 12.0));
	float edge = 1.0 - smoothstep(0.01, 0.01 + max(fwidth(coast_distance), 0.003), abs(coast_distance));
	float ink = clamp(lip * 0.65 + cracks * 0.55 + hatch * 0.18 + edge * 0.7, 0.0, 0.85);
	return mix(base, ink_color.rgb, ink * shore_ink_strength);
}
