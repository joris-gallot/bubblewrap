shader_type spatial;
render_mode cull_back;

// Cardboard under the sheet; with pattern = 1 it also paints the bubbles, for views too far for the MultiMesh chunks.
uniform float pattern = 0.0;
uniform vec3 cardboard : source_color = vec3(0.55, 0.38, 0.22);
// Seen from afar, a bubble over cardboard reads about this color.
uniform vec3 film : source_color = vec3(0.8, 0.68, 0.6);
// Same layout as SheetData: SPACING 1, ROW_STEP sqrt(3)/2, odd rows shifted half a bubble.
const float ROW_STEP = 0.8660254;
const float BUBBLE_RADIUS = 0.42;

varying vec2 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

// Offset from the nearest bubble center.
vec2 hex_offset(vec2 p) {
	float row = floor(p.y / ROW_STEP);
	vec2 best = vec2(10.0);
	for (float r = row; r <= row + 1.0; r += 1.0) {
		float shift = 0.5 * mod(r, 2.0);
		vec2 center = vec2(round(p.x - shift) + shift, r * ROW_STEP);
		vec2 d = p - center;
		if (dot(d, d) < dot(best, best)) {
			best = d;
		}
	}
	return best;
}

void fragment() {
	ALBEDO = cardboard;
	ROUGHNESS = 0.9;
	if (pattern > 0.0) {
		vec2 off = hex_offset(v_world);
		float d = length(off);
		// Far away a bubble is a few pixels: fade the domes into their average color.
		float detail = 1.0 - smoothstep(0.15, 0.45, fwidth(v_world.x));
		float aa = max(fwidth(v_world.x), 0.01);
		float dome = 1.0 - smoothstep(BUBBLE_RADIUS - aa, BUBBLE_RADIUS + aa, d);
		float coverage = 0.64;
		ALBEDO = mix(ALBEDO, mix(cardboard, film, coverage), pattern * (1.0 - detail));
		ALBEDO = mix(ALBEDO, film, pattern * detail * dome);
		// Dome normals so the lighting puts a highlight on every bubble, like the 3D ones.
		float h = sqrt(max(BUBBLE_RADIUS * BUBBLE_RADIUS - d * d, 0.0));
		vec3 dome_normal = normalize(vec3(off.x, h * 0.7 + 0.001, off.y));
		vec3 n = normalize(mix(vec3(0.0, 1.0, 0.0), dome_normal, pattern * detail * dome));
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
		ROUGHNESS = mix(0.9, 0.3, pattern * dome * detail);
		SPECULAR = mix(0.5, 0.6, pattern * dome * detail);
	}
}
