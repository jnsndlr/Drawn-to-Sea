// Bakes the chart geography into a texture the scene script can read back:
// R = land height, G = zone, B = grove density.
// Zones: 0 water, 0.25 sand, 0.5 plateau top, 1 cliff or rock.
shader_type canvas_item;

uniform vec2 chart_size = vec2(20.0, 13.5);

#include "res://shaders/explorer_geography.gdshaderinc"

float height_at(vec2 p) {
	float d;
	float shelf;
	float rockiness;
	land_field(p, d, shelf, rockiness);
	return d < 0.0 ? land_height(p, d, shelf, rockiness) : 0.0;
}

void fragment() {
	// Image row 0 is the far (-z) edge of the chart, matching the plane mesh.
	vec2 p = (UV - 0.5) * chart_size;
	float d;
	float shelf;
	float rockiness;
	land_field(p, d, shelf, rockiness);
	float h = height_at(p);
	float e = 0.03;
	float slope = length(vec2(height_at(p + vec2(e, 0.0)) - h, height_at(p + vec2(0.0, e)) - h)) / e;
	float inland = -d;
	float zone = 0.0;
	if (d < 0.0) {
		zone = 1.0;
		if (rockiness < 0.5 && slope < 0.8) {
			if (inland > shelf + 0.2) {
				zone = 0.5;
			} else if (inland > 0.04 && inland < shelf * 0.85) {
				zone = 0.25;
			}
		}
	}
	COLOR = vec4(h, zone, clamp(grove_field(p), 0.0, 1.0), 1.0);
}
