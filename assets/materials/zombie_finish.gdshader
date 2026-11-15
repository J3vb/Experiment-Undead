// Infected skin, institutional cloth and rubber use their source palette and AO.
// No rarity or dye inputs: the shared eye/belly material has one instance flag.
shader_type spatial;

const int CLOTH = 8;
const int SHOE = 9;
const int GLOW = 10;

uniform vec3 albedo : source_color = vec3(0.2);
uniform int finish : hint_range(7, 10) = 7;
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
uniform bool pale_head = false;
uniform bool decay = false;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_strength : hint_range(0.0, 2.0) = 0.0;
instance uniform bool belly = false;

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

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z
	);
}

vec3 bump(vec3 n, vec3 pos, float height) {
	vec3 dx = dFdx(pos);
	vec3 dy = dFdy(pos);
	vec3 across = cross(dy, n);
	vec3 along = cross(n, dx);
	float determinant = dot(dx, across);
	vec3 gradient = sign(determinant) * (dFdx(height) * across + dFdy(height) * along);
	return normalize(max(abs(determinant), 1e-12) * n - gradient);
}

void fragment() {
	vec3 p = obj_pos;
	float broad = noise(p * 9.0);
	float fleck = noise(p * 43.0);
	float detail = 1.0 - smoothstep(0.0005, 0.002, length(fwidth(p)));
	float strength = pale_head ? 0.25 : 1.0;
	float shade = 1.0 - (0.10 * broad + 0.05 * fleck) * strength;
	float rough = clamp(roughness + 0.28, 0.65, 0.8) + (broad - 0.5) * 0.07;
	float height = (fleck - 0.5) * 0.000035 * detail;
	vec3 emission = vec3(0.0);
	if (finish == CLOTH) {
		float stain = smoothstep(0.45, 0.8, noise(p * vec3(15.0, 3.5, 15.0)));
		float hem = 1.0 - smoothstep(0.65, 1.2, p.y);
		vec3 n = abs(obj_normal);
		vec2 uv = n.z > n.x && n.z > n.y ? p.xy : (n.x > n.y ? p.zy : p.xz);
		float weave = sin(uv.x * 2200.0) * sin(uv.y * 2200.0) * detail;
		shade = 1.0 - (0.14 + 0.16 * hem) * stain - 0.045 * broad - 0.018 * abs(weave);
		rough = clamp(roughness, 0.88, 0.98) + weave * 0.02;
		height = weave * 0.00004;
	} else if (finish == SHOE) {
		shade = 1.0 - 0.15 * broad - 0.06 * fleck;
		rough = 0.82 + fleck * 0.10;
	} else if (finish == GLOW) {
		shade = 1.0;
		rough = 0.6;
		emission = emission_color * clamp(emission_strength, 0.0, 2.0);
		if (belly) {
			float line = sin((p.x + p.y) * 40.0 + broad * 5.0) * sin((p.z - p.x) * 31.0 + fleck * 3.0);
			float footprint = max(fwidth(line), 0.015);
			float veins = 1.0 - smoothstep(0.04 - footprint, 0.04 + footprint, abs(line));
			veins = mix(0.12, veins, 1.0 - smoothstep(0.15, 0.8, footprint));
			shade = 0.18 + veins * 0.035;
			emission *= 0.04 + veins * 0.10;
		}
	} else if (decay) {
		shade = 0.30 + broad * 0.10;
		rough = 0.65 - smoothstep(0.65, 0.9, fleck) * 0.10;
	}
	ALBEDO = albedo * clamp(shade, 0.0, 1.0) * COLOR.r;
	ROUGHNESS = clamp(rough + (1.0 - COLOR.r) * 0.06, 0.25, 1.0);
	SPECULAR = decay ? 0.4 : 0.3;
	METALLIC = 0.0;
	NORMAL = bump(NORMAL, VERTEX, height * strength);
	EMISSION = emission;
}
