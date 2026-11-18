// Lantern Post night sky: dark gradient, stars, a green aurora and a snowy mountain ridge on the
// horizon, all from the view direction. No textures; the ridge is drawn here so fog never hides it.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.012, 0.018, 0.04);
uniform vec3 horizon_color : source_color = vec3(0.07, 0.09, 0.14);
uniform vec3 aurora_color : source_color = vec3(0.25, 1.0, 0.45);
uniform vec3 aurora_top_color : source_color = vec3(0.1, 0.55, 0.6);
uniform float aurora_strength = 0.7;
uniform vec3 rock_color : source_color = vec3(0.035, 0.045, 0.06);
uniform vec3 snow_color : source_color = vec3(0.3, 0.36, 0.45);
uniform float star_density : hint_range(0.0, 1.0) = 0.12;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash(vec2(i, 0.0)), hash(vec2(i + 1.0, 0.0)), u);
}

float ridge(float az, float seed) {
	float h = 0.0;
	float amp = 0.5;
	float freq = 3.0;
	for (int i = 0; i < 5; i++) {
		h += (1.0 - abs(noise1(az * freq + seed) * 2.0 - 1.0)) * amp;
		amp *= 0.5;
		freq *= 2.1;
	}
	return h;
}

vec3 aurora(vec3 dir, float elev, float az) {
	if (elev < 0.05) {
		return vec3(0.0);
	}
	// Strongest to the north (-Z), behind the Deploy gate.
	float north = smoothstep(0.1, -0.9, dir.z);
	float wave = sin(az * 2.3 + 0.6) * 0.16 + (noise1(az * 4.0) - 0.5) * 0.14;
	float base = 0.5 + wave;
	float band = smoothstep(base - 0.08, base + 0.02, elev) * exp(-max(elev - base, 0.0) * 8.0);
	float curtains = (0.35 + 0.65 * smoothstep(0.2, 0.9, noise1(az * 3.0 + 3.0))) * (0.45 + 0.55 * noise1(az * 55.0));
	float shape = band * curtains * north * smoothstep(0.05, 0.2, elev);
	vec3 col = mix(aurora_color, aurora_top_color, smoothstep(base, base + 0.4, elev));
	return col * shape * aurora_strength;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float elev = asin(clamp(dir.y, -1.0, 1.0));
	// Azimuth 0 points north (-Z); the seam at +-PI is south, behind the town wall, where the aurora is off.
	float az = atan(dir.x, -dir.z);
	vec3 col = mix(horizon_color, zenith_color, smoothstep(0.0, 0.9, elev));
	vec2 cell = floor(vec2(az * 260.0, elev * 260.0));
	float star = step(1.0 - star_density * 0.1, hash(cell)) * smoothstep(0.08, 0.3, elev);
	col += vec3(0.8, 0.85, 1.0) * star * hash(cell + 7.0);
	col += aurora(dir, elev, az);
	float north = smoothstep(0.3, -1.0, dir.z);
	float far_h = 0.04 + ridge(az, 11.0) * (0.05 + 0.32 * north);
	float near_h = 0.03 + ridge(az * 1.3, 37.0) * (0.04 + 0.16 * north);
	if (elev < far_h) {
		float snow = smoothstep(far_h - 0.05, far_h - 0.01, elev);
		col = mix(rock_color * 1.4, snow_color * 1.1, snow) + horizon_color * 0.6;
	}
	if (elev < near_h) {
		float snow = smoothstep(near_h - 0.04, near_h - 0.005, elev) * step(0.5, noise1(az * 60.0) + 0.3);
		col = mix(rock_color, snow_color, snow);
	}
	COLOR = col;
}
