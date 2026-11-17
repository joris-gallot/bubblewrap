shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;

// One spark per producer unit on the globe. Instance custom data: (tier, seed, born time, unused).
global uniform float pop_clock;

const float INTRO_TIME = 0.6;

varying float v_flash;
varying float v_tier;

void vertex() {
	float tier = INSTANCE_CUSTOM.x;
	float age = pop_clock - INSTANCE_CUSTOM.z;
	float intro = clamp(age / INTRO_TIME, 0.0, 1.0);
	// A spark flashes like a burst of pops, faster for bigger producers.
	float phase = fract(pop_clock * (1.2 + tier * 0.5) + INSTANCE_CUSTOM.y);
	float flash = pow(1.0 - phase, 5.0);
	// New sparks overshoot when they appear, so a new tier reads at a glance.
	float overshoot = 1.0 + 2.5 * sin(intro * PI);
	VERTEX *= (0.3 + flash) * intro * overshoot;
	v_flash = flash;
	v_tier = tier;
}

void fragment() {
	vec3 hue = mix(vec3(1.0, 0.92, 0.7), vec3(0.55, 0.85, 1.0), v_tier / 6.0);
	ALBEDO = hue * (0.6 + 2.5 * v_flash);
}
