// Character and gear finishes share object-space detail, with no textures.
// COLOR.r carries baked AO; round(COLOR.a * 3) selects glow, trim, accent, main.
// Like gun_finish, convex screen-space curvature puts plate wear on bevels.
shader_type spatial;

const int FABRIC = 0;
const int WEBBING = 1;
const int PLATE = 2;
const int POLYMER = 3;
const int RUBBER = 4;
const int KNIT = 5;
const int LENS = 6;

uniform vec3 albedo : source_color = vec3(0.2);
uniform int finish : hint_range(0, 6) = 0;

instance uniform vec4 dye_main : source_color = vec4(1.0);
instance uniform vec4 dye_accent : source_color = vec4(1.0);
instance uniform vec4 trim_color : source_color = vec4(0.85098, 0.85098, 0.82353, 1.0);
instance uniform vec4 glow_color : source_color = vec4(0.85098, 0.85098, 0.82353, 1.0);
instance uniform float glow_strength : hint_range(0.0, 2.0) = 0.0;
instance uniform float pulse_seconds : hint_range(0.0, 10.0) = 0.0;
instance uniform bool flicker = false;

varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
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
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z
	);
}

float fbm(vec3 p) {
	return noise(p) * 0.5 + noise(p * 2.03) * 0.25 + noise(p * 4.01) * 0.25;
}

vec2 surface_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	return a.x > a.y && a.x > a.z ? p.zy : (a.y > a.z ? p.xz : p.xy);
}

// Convex curvature in 1/m, measured before adding the fine normal detail.
float curvature(vec3 n, vec3 pos) {
	vec3 dx = dFdx(pos);
	vec3 dy = dFdy(pos);
	return dot(dFdx(n), dx) / max(dot(dx, dx), 1e-12) + dot(dFdy(n), dy) / max(dot(dy, dy), 1e-12);
}

// Height in metres perturbs the view-space normal without needing tangents.
vec3 bump(vec3 n, vec3 pos, float h) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	return normalize(abs(det) * n - grad);
}

float glow_motion() {
	float strength = 1.0;
	if (pulse_seconds > 0.0) {
		strength *= mix(0.6, 1.0, 0.5 + 0.5 * sin(TIME * TAU / pulse_seconds));
	}
	if (flicker) {
		float tick = floor(TIME * 11.0);
		float jitter = hash(vec3(tick, 1.7, 9.2));
		strength *= mix(0.3, 1.0, jitter) * mix(0.7, 1.0, noise(vec3(TIME * 2.3)));
	}
	return strength;
}

void fragment() {
	vec3 p = obj_pos;
	vec2 uv = surface_uv(p, obj_normal);
	int zone = int(round(COLOR.a * 3.0));
	vec3 color = albedo;
	if (zone == 3) {
		color *= dye_main.rgb;
	} else if (zone == 2) {
		color *= dye_accent.rgb;
	} else if (zone == 1) {
		color = trim_color.rgb;
	} else {
		color = glow_color.rgb;
	}

	float blotch = fbm(p * 28.0);
	color *= mix(0.94, 1.06, blotch);
	float rough = 0.85;
	float metal = 0.0;
	float height = 0.0;
	float fuzz = 0.0;
	// Fade unresolved threads/grain to their average to avoid shimmer at distance.
	float pitch = finish == KNIT ? 0.004 : 0.0016;
	float detail = clamp(1.0 - length(fwidth(p)) / pitch, 0.0, 1.0);
	float grain = noise(p * 1600.0);

	if (finish == FABRIC || finish == WEBBING || finish == KNIT) {
		vec2 thread = uv / pitch;
		float warp = sin(thread.x * TAU);
		float weft = sin(thread.y * TAU);
		float weave = warp * weft;
		rough = 0.9;
		fuzz = 0.12;
		if (finish == WEBBING) {
			weave = sin(thread.y * TAU) * 0.75 + warp * 0.25;
			rough = 0.82;
			fuzz = 0.04;
		} else if (finish == KNIT) {
			float loop = sin(thread.y * TAU + sin(thread.x * TAU) * 1.8);
			weave = loop * 0.6 + warp * 0.4;
			fuzz = 0.22;
			rough = 0.96;
		}
		color *= 1.0 + weave * 0.09 * detail;
		height = (weave * 0.00009 + grain * 0.000035) * detail;
		rough += weave * 0.035 * detail;
	} else if (finish == PLATE) {
		float edge = clamp(curvature(NORMAL, VERTEX) / 160.0, 0.0, 1.5);
		float chips = fbm(p * 140.0);
		float worn = smoothstep(0.55, 0.62, edge * 0.8 + (chips - 0.5) * 0.7);
		color = mix(color, vec3(0.42, 0.43, 0.44), worn);
		metal = mix(0.05, 0.9, worn);
		rough = mix(0.64 + (blotch - 0.5) * 0.16, 0.3, worn);
		height = (grain * 0.00004 - worn * 0.00003) * detail;
	} else if (finish == POLYMER) {
		rough = 0.72 + (grain - 0.5) * 0.12 * detail;
		height = grain * 0.00007 * detail;
		color *= mix(1.0, 0.96 + grain * 0.08, detail);
	} else if (finish == RUBBER) {
		rough = 0.95 + (grain - 0.5) * 0.04 * detail;
		height = grain * 0.000025 * detail;
	} else if (finish == LENS) {
		rough = 0.12 + grain * 0.025 * detail;
		metal = 0.15;
		height = grain * 0.000002 * detail;
	}

	ALBEDO = color * COLOR.r;
	ROUGHNESS = clamp(rough + (1.0 - COLOR.r) * 0.08, 0.05, 1.0);
	METALLIC = metal;
	SPECULAR = finish == LENS ? 0.65 : 0.5;
	RIM = fuzz;
	RIM_TINT = 0.65;
	NORMAL = bump(NORMAL, VERTEX, height);
	EMISSION = zone == 0 ? glow_color.rgb * clamp(glow_strength, 0.0, 2.0) * glow_motion() : vec3(0.0);
}
