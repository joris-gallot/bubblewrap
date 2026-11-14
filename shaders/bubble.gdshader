shader_type spatial;
render_mode blend_mix, cull_back, specular_schlick_ggx;

// Script-driven clock: TIME is not readable from GDScript, and pops store their start time.
global uniform float pop_clock;
// xy = center on the ground (x, z), z = radius of the tool highlight (negative = none).
global uniform vec3 pop_hover;

const float SQUASH_TIME = 0.07;

varying float v_popped;
varying float v_hover;
varying vec3 v_local;
varying float v_seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_seed = hash(world.xz);
	float k = INSTANCE_CUSTOM.x > 0.5 ? clamp((pop_clock - INSTANCE_CUSTOM.y) / SQUASH_TIME, 0.0, 1.0) : 0.0;
	v_local = VERTEX;
	// Bulge a little before collapsing, so the pop reads even when tiny on screen.
	float bulge = sin(k * PI) * 0.2;
	// A popped bubble shrinks into an uneven crumpled patch, not a clean disc.
	float angle = atan(VERTEX.z, VERTEX.x);
	float ragged = 1.0 - k * (0.12 + 0.1 * sin(angle * 3.0 + v_seed * 20.0) + 0.06 * sin(angle * 7.0 + v_seed * 9.0));
	VERTEX.xz *= (1.0 + bulge) * ragged;
	VERTEX.y *= mix(1.0 + bulge, 0.08, k);
	VERTEX.y += k * 0.02;
	v_popped = k;
	float d = distance(world.xz, pop_hover.xy);
	v_hover = pop_hover.z < 0.0 ? 0.0 : 1.0 - smoothstep(pop_hover.z, pop_hover.z + 0.35, d);
}

void fragment() {
	// Crinkles on popped plastic: bend the normal with a few crossing waves.
	vec2 p = v_local.xz * 24.0 + v_seed * 31.0;
	vec3 crinkle = vec3(sin(p.x) * cos(p.y * 1.3), 0.0, cos(p.x * 0.7 + p.y)) * 0.9;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(crinkle, 0.0)).xyz * v_popped);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(vec3(0.92, 0.97, 1.0), vec3(0.78, 0.76, 0.72), v_popped);
	ROUGHNESS = mix(0.04, 0.3, v_popped);
	SPECULAR = mix(0.9, 0.6, v_popped);
	ALPHA = mix(0.1 + 0.8 * fresnel, 0.32, v_popped);
	EMISSION = vec3(0.4, 0.8, 1.0) * v_hover * 0.7 * (1.0 - v_popped);
}
