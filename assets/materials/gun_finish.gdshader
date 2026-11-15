// One finish shader for every code-built gun. No textures: all detail comes from
// object-space noise, so it never swims while the viewmodel moves.
// Vertex RGB from tools/assets/finish.py is baked AO/cavity; alpha marks the
// thin inlay (0), Prototype glow (1/3) and ordinary surfaces (1), never transparency. Edge wear
// follows convex curvature measured from how fast the normal bends on screen,
// so it sits on bevels and rims, not on flat faces.
// `finish` picks the surface: 0 bare metal, 1 black coating, 2 polymer, 3 wood.
shader_type spatial;

const int METAL = 0;
const int COATED = 1;
const int POLYMER = 2;
const int WOOD = 3;

uniform vec3 albedo : source_color = vec3(0.2);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
uniform int finish : hint_range(0, 3) = 0;
uniform bool knurled = false;
uniform float wear : hint_range(0.0, 1.0) = 1.0;
uniform vec3 bare_metal : source_color = vec3(0.541176, 0.568627, 0.549020); // #8A918C
uniform float knurl_pitch = 0.0012;
uniform float edge_curvature = 160.0; // 1/m: bends sharper than this count as worn edges
instance uniform vec4 rarity_color : source_color = vec4(0.850980, 0.850980, 0.823529, 1.0); // #D9D9D2

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
	return noise(p) * 0.5 + noise(p * 2.03) * 0.25 + noise(p * 4.01) * 0.125 + noise(p * 8.05) * 0.125;
}

// Diamond knurl height (0..1) on the plane the surface faces most.
float knurl(vec3 p, vec3 n) {
	vec3 a = abs(n);
	vec2 uv = a.x > a.y && a.x > a.z ? p.zy : (a.y > a.z ? p.xz : p.xy);
	float u = (uv.x + uv.y) / knurl_pitch;
	float v = (uv.x - uv.y) / knurl_pitch;
	return min(abs(fract(u) - 0.5), abs(fract(v) - 0.5)) * 2.0;
}

// Convex curvature (1/m) of the surface at this pixel; negative in creases.
float curvature(vec3 n, vec3 pos) {
	vec3 dx = dFdx(pos);
	vec3 dy = dFdy(pos);
	return dot(dFdx(n), dx) / max(dot(dx, dx), 1e-12) + dot(dFdy(n), dy) / max(dot(dy, dy), 1e-12);
}

// Bumps the view-space normal by a height (metres) without tangents.
vec3 bump(vec3 n, vec3 pos, float h) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	return normalize(abs(det) * n - grad);
}

void fragment() {
	vec3 p = obj_pos;
	float ao = COLOR.r;
	float blotch = fbm(p * 28.0);
	float chips = fbm(p * 140.0);
	// Fade sub-millimetre detail out with distance so it never shimmers.
	float detail = clamp(1.0 - length(fwidth(p)) / 0.0015, 0.0, 1.0);

	float edge = clamp(curvature(NORMAL, VERTEX) / edge_curvature, 0.0, 1.0) * wear;
	float worn = smoothstep(0.4, 0.9, edge) * smoothstep(0.35, 0.7, chips) * ao;
	vec3 color = albedo * mix(0.96, 1.04, blotch);
	float rough = roughness + (blotch - 0.5) * 0.1;
	float metal = metallic;
	float height = 0.0;

	if (finish == METAL) {
		float brushed = noise(vec3(p.x * 900.0, p.y * 900.0, p.z * 12.0));
		rough += (brushed - 0.5) * 0.065 * detail;
		color = mix(color, bare_metal, worn * 0.6);
		rough = mix(rough, 0.28, worn);
	} else if (finish == COATED) {
		color = mix(color, bare_metal * 0.8, worn);
		metal = mix(metal, 0.9, worn);
		rough = mix(rough, 0.32, worn);
		height = noise(p * 2200.0) * 0.00004 * detail;
	} else if (finish == POLYMER) {
		color = mix(color, color * 1.45 + 0.02, worn * 0.7);
		rough = mix(rough, rough + 0.08, worn);
		height = noise(p * 1600.0) * 0.00008 * detail;
	} else {
		float rings = length(p.xy + vec2(0.0, 0.35)) * 180.0 + fbm(p * vec3(40.0, 40.0, 3.0)) * 8.0;
		float grain = smoothstep(0.6, 1.0, abs(fract(rings) - 0.5) * 2.0) * mix(0.4, 1.0, blotch);
		float pores = mix(0.5, noise(vec3(p.x * 1400.0, p.y * 1400.0, p.z * 60.0)), detail);
		color *= mix(1.1, 0.72, grain) * mix(0.94, 1.04, pores);
		rough += grain * 0.12;
		color = mix(color, color * 1.6, worn * 0.6);
		rough = mix(rough, 0.85, worn);
		height = -grain * 0.00006 * detail;
	}

	if (knurled) {
		float k = knurl(p, obj_normal);
		height += k * 0.00025 * detail;
		color *= mix(1.0, mix(0.7, 1.15, k), detail);
		rough -= k * 0.12 * detail;
	}

	float inlay = 1.0 - step(0.15, COLOR.a);
	float glow = step(0.15, COLOR.a) * (1.0 - step(0.5, COLOR.a));
	color = mix(color, rarity_color.rgb, inlay);
	metal = mix(metal, 0.3, inlay);
	rough = mix(rough, 0.42, inlay);
	height *= 1.0 - inlay;
	EMISSION = albedo * glow * 1.5;
	ALBEDO = color * ao;
	METALLIC = metal;
	ROUGHNESS = clamp(rough + (1.0 - ao) * 0.15, 0.05, 1.0);
	NORMAL = bump(NORMAL, VERTEX, height);
}
