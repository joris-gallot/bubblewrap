shader_type spatial;
render_mode unshaded, cull_back;

// The Earth under a film of bubble wrap. Unshaded with its own light: the scene sun is set up for the sheet.
uniform float popped = 0.0;
uniform vec3 light_dir = vec3(-0.55, 0.45, 0.7);
// Bubbles along the equator; huge on purpose, real ones would be invisible from orbit.
uniform float bubbles_around = 220.0;

const float ROW_STEP = 0.8660254;
const float BUBBLE_RADIUS = 0.42;

varying vec3 v_local;
varying vec3 v_world_normal;

void vertex() {
	v_local = normalize(VERTEX);
	v_world_normal = normalize((MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz);
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		total += noise(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

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
	vec3 n = v_local;
	float h = fbm(n * 1.7 + vec3(3.1, 0.0, 1.7));
	float land = smoothstep(0.5, 0.52, h);
	vec3 ocean = mix(vec3(0.03, 0.12, 0.33), vec3(0.06, 0.28, 0.52), smoothstep(0.32, 0.5, h));
	vec3 ground = mix(vec3(0.2, 0.42, 0.16), vec3(0.62, 0.53, 0.32), smoothstep(0.56, 0.7, h));
	vec3 color = mix(ocean, ground, land);
	color = mix(color, vec3(0.93, 0.95, 0.97), smoothstep(0.84, 0.9, abs(n.y)));

	// Bubble wrap in longitude / latitude, cells kept roughly square away from the poles.
	vec2 p = vec2(atan(n.z, n.x) / TAU * bubbles_around, asin(n.y) / PI * bubbles_around * 0.5);
	vec2 off = hex_offset(p);
	float d = length(off);
	float detail = 1.0 - smoothstep(0.2, 0.5, fwidth(p.x));
	float aa = max(fwidth(p.x), 0.02);
	float dome = (1.0 - smoothstep(BUBBLE_RADIUS - aa, BUBBLE_RADIUS + aa, d)) * detail;
	// Popped regions grow from noise patches as the counter climbs.
	float rank = smoothstep(0.3, 0.7, fbm(n * 5.0 + 11.0));
	float is_popped = step(rank, popped) * step(0.0, popped - 0.000001);
	dome *= 1.0 - is_popped;

	float lambert = max(dot(v_world_normal, normalize(light_dir)), 0.0);
	color *= 0.12 + 0.95 * lambert;
	// Milky film over everything, thicker on the domes, crinkled grey where popped.
	vec3 film = vec3(0.9, 0.94, 1.0) * (0.25 + 0.75 * lambert);
	color = mix(color, film, 0.07 + 0.16 * dome + 0.05 * (1.0 - detail));
	color = mix(color, vec3(0.62, 0.6, 0.58) * (0.2 + 0.8 * lambert), is_popped * 0.55);
	float spot = 1.0 - smoothstep(0.0, 0.14, length(off - vec2(-0.13, 0.13)));
	color += vec3(1.0) * spot * dome * lambert * 0.55;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	color += vec3(0.3, 0.55, 1.0) * fresnel * 0.9;
	ALBEDO = color;
}
