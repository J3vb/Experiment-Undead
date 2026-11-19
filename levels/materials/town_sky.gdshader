// Lantern Post night sky: dark gradient, stars, a green aurora and three snowy mountain ranges on the
// horizon (far, middle, near), all from the view direction. No textures; the ranges are drawn here so fog
// never hides them. Each range has soft edges, moonlit and shadowed faces, snow gullies and haze at its foot.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.012, 0.018, 0.04);
uniform vec3 horizon_color : source_color = vec3(0.07, 0.09, 0.14);
uniform vec3 aurora_color : source_color = vec3(0.25, 1.0, 0.45);
uniform vec3 aurora_top_color : source_color = vec3(0.1, 0.55, 0.6);
uniform float aurora_strength = 0.7;
uniform vec3 rock_color : source_color = vec3(0.035, 0.045, 0.06);
uniform vec3 snow_color : source_color = vec3(0.34, 0.4, 0.5);
uniform float star_density : hint_range(0.0, 1.0) = 0.12;
uniform vec3 haze_color : source_color = vec3(0.09, 0.11, 0.16);
// Moon azimuth (radians, 0 = north): the faces that turn towards it catch more light.
uniform float moon_azimuth = 2.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash(vec2(i, 0.0)), hash(vec2(i + 1.0, 0.0)), u);
}

// A range of separate peaks round the horizon: `cells` peaks per full turn (wraps, no seam). Returns the
// height (0..~1) at azimuth `az` and which face of the winning peak this is (-1 west of its summit, +1 east).
vec2 peaks(float az, float cells, float seed) {
	float x = (az / TAU + 0.5) * cells;
	float i = floor(x);
	vec2 best = vec2(0.0, 1.0);
	for (int k = -2; k <= 2; k++) {
		float c = i + float(k);
		float id = mod(c, cells);
		float centre = c + hash(vec2(id, seed));
		float height = 0.3 + 0.7 * hash(vec2(id, seed + 1.0));
		float half_width = 0.8 + 1.3 * hash(vec2(id, seed + 2.0));
		float t = 1.0 - abs(x - centre) / half_width;
		float h = height * pow(max(t, 0.0), 1.15);
		if (h > best.x) {
			best = vec2(h, sign(x - centre));
		}
	}
	float crag = (noise1(x * 7.0 + seed) - 0.5) * 0.05 + (noise1(x * 19.0 + seed) - 0.5) * 0.02;
	best.x += crag * smoothstep(0.0, 0.2, best.x);
	return best;
}

// One range in front of the sky colour `back`: soft silhouette, moonlit and shadowed faces, a snow cap
// with fingers running down the gullies, rock streaks, and haze that thickens with distance and at the foot.
vec3 mountain(vec3 back, float az, float elev, float cells, float seed, float base, float scale, float haze) {
	vec2 pk = peaks(az, cells, seed);
	float top = base + pk.x * scale;
	float cover = 1.0 - smoothstep(top - 0.002, top + 0.002, elev);
	if (cover <= 0.0) {
		return back;
	}
	float face = 0.5 + 0.5 * cos(az + pk.y * PI * 0.5 - moon_azimuth);
	float light = mix(0.35, 1.15, face);
	float x = (az / TAU + 0.5) * cells;
	float depth = (top - elev) / max(pk.x * scale, 0.001);
	float fingers = noise1(x * 23.0 + seed) * 0.6 + noise1(x * 61.0 + seed) * 0.4;
	float cap = 0.22 + 0.25 * noise1(x * 3.0 + seed) + 0.35 * fingers * fingers;
	float snowy = 1.0 - smoothstep(cap - 0.03, cap + 0.03, depth);
	float streak = noise1(x * 40.0 + depth * pk.y * 9.0 + seed);
	vec3 rock = rock_color * (0.8 + 0.5 * streak);
	vec3 col = mix(rock, snow_color, snowy) * light;
	col *= mix(1.0, 0.75, smoothstep(0.0, 1.0, depth));
	float foot = smoothstep(0.55, 1.0, depth);
	col = mix(col, haze_color, clamp(haze + foot * 0.5, 0.0, 1.0));
	return mix(back, col, cover);
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
	// Three ranges, far to near; all of them taller to the north, behind the Deploy gate.
	float north = smoothstep(0.3, -1.0, dir.z);
	if (elev < 0.55) {
		col = mountain(col, az, elev, 22.0, 11.0, 0.02, 0.12 + 0.36 * north, 0.45);
		col = mountain(col, az, elev, 34.0, 37.0, 0.012, 0.08 + 0.2 * north, 0.22);
		col = mountain(col, az, elev, 52.0, 71.0, 0.006, 0.05 + 0.09 * north, 0.04);
	}
	COLOR = col;
}
