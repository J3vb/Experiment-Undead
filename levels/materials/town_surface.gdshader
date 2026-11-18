// Lantern Post surfaces from world position, so grey-box blocks of any size
// get stone courses, planks, slate or cobbles without UVs or texture files.
// pattern: 0 stone wall, 1 planks, 2 slate roof, 3 cobbles, 4 snow, 5 plaster with timber beams,
// 6 wet mud road with wheel ruts, puddles and slush at the edges, 7 round-log grain (lodge models).
// Code-built models also multiply in their baked AO vertex colour (COLOR is white on plain blocks).
shader_type spatial;

uniform int pattern = 0;
uniform vec3 base_color : source_color = vec3(0.5, 0.5, 0.5);
uniform vec3 joint_color : source_color = vec3(0.2, 0.18, 0.16);
uniform float scale = 1.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;
uniform float snow_on_top : hint_range(0.0, 1.0) = 0.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise : hint_default_white, repeat_enable, filter_linear_mipmap;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 face_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y > a.x && a.y > a.z) {
		return p.xz;
	}
	return a.x > a.z ? vec2(p.z, p.y) : vec2(p.x, p.y);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// x: joint mask (1 = joint), y: per-cell tint.
vec2 courses(vec2 uv, vec2 cell, float joint) {
	float row = floor(uv.y / cell.y);
	uv.x += mod(row, 2.0) * cell.x * 0.5 + hash(vec2(row, 3.0)) * cell.x;
	vec2 id = floor(uv / cell);
	vec2 f = fract(uv / cell) * cell;
	vec2 d = min(f, cell - f);
	float j = 1.0 - smoothstep(0.0, joint, min(d.x, d.y));
	return vec2(j, hash(id));
}

void fragment() {
	vec2 uv = face_uv(world_pos, world_normal) * scale;
	float up = world_normal.y;
	float grain = texture(noise, uv * 0.35).r;
	float fine = texture(noise, uv * 2.3 + vec2(0.37, 0.71)).r;
	vec3 color = base_color;
	float joint = 0.0;
	float rough = roughness_value;
	if (pattern == 0) {
		vec2 c = courses(uv, vec2(0.62, 0.3), 0.035);
		joint = c.x;
		color *= mix(0.72, 1.18, c.y) * mix(0.85, 1.1, fine);
	} else if (pattern == 1) {
		float board = floor(uv.x / 0.22);
		float f = fract(uv.x / 0.22);
		joint = 1.0 - smoothstep(0.0, 0.07, min(f, 1.0 - f));
		float streak = texture(noise, vec2(board * 0.37, uv.y * 0.08)).r;
		color *= mix(0.7, 1.15, hash(vec2(board, 1.0))) * mix(0.8, 1.15, streak);
	} else if (pattern == 2) {
		vec2 c = courses(uv * vec2(1.0, 1.0), vec2(0.34, 0.2), 0.025);
		joint = c.x;
		color *= mix(0.75, 1.2, c.y) * mix(0.9, 1.08, fine);
	} else if (pattern == 3) {
		vec2 c = courses(uv, vec2(0.28, 0.24), 0.05);
		joint = c.x;
		color *= mix(0.7, 1.2, c.y) * mix(0.85, 1.1, grain);
		rough = mix(roughness_value, 0.12, wetness * smoothstep(0.45, 0.65, grain) + joint * wetness * 0.6);
	} else if (pattern == 6) {
		float ruts = 1.0 - smoothstep(0.0, 0.5, abs(abs(world_pos.x) - 1.1));
		float puddle = smoothstep(0.6, 0.66, texture(noise, uv * 0.11 + vec2(0.5, 0.2)).r + ruts * 0.08);
		float edge = world_pos.z < -1.0 ? abs(world_pos.x) : abs(world_pos.x) * 0.36;
		float slush = smoothstep(2.4, 3.9, edge + (texture(noise, uv * 0.12).r - 0.5) * 2.0);
		slush *= 1.0 - puddle;
		color *= mix(0.75, 1.15, fine) * mix(1.0, 0.7, ruts);
		color = mix(color, vec3(0.58, 0.62, 0.68) * mix(0.85, 1.0, fine), slush * 0.85);
		color = mix(color, color * 0.4, puddle);
		rough = mix(mix(roughness_value, 0.5, wetness), 0.03, puddle);
		rough = mix(rough, 0.7, slush);
	} else if (pattern == 7) {
		float streak = texture(noise, vec2(uv.x * 0.12, uv.y * 3.5)).r;
		float knot = smoothstep(0.78, 0.86, texture(noise, uv * 0.9 + vec2(0.13, 0.57)).r);
		color *= mix(0.65, 1.2, streak) * mix(0.9, 1.05, fine) * (1.0 - knot * 0.35);
	} else if (pattern == 4) {
		color *= mix(0.86, 1.04, grain) * mix(0.95, 1.03, fine);
	} else {
		vec2 g = fract(uv / vec2(1.4, 1.25));
		float beam = 1.0 - smoothstep(0.0, 0.07, min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y)) * 1.4);
		float diag = abs(fract((uv.x + uv.y) / 1.4) - 0.5) < 0.035 && hash(floor(uv / vec2(1.4, 1.25))) > 0.6 ? 1.0 : 0.0;
		beam = max(beam, diag);
		color = mix(base_color * mix(0.85, 1.05, grain), joint_color * mix(0.7, 1.1, fine), beam);
		joint = 0.0;
	}
	color = mix(color, joint_color, joint * 0.85);
	float dirt = smoothstep(0.9, 0.0, world_pos.y) * (1.0 - abs(up)) * 0.35;
	color *= 1.0 - dirt;
	float snow = snow_on_top * smoothstep(0.35, 0.75, up + (grain - 0.5) * 0.4);
	color = mix(color, vec3(0.86, 0.9, 0.95) * mix(0.9, 1.0, fine), snow);
	ALBEDO = color * COLOR.rgb;
	ROUGHNESS = mix(rough + joint * 0.1, 0.75, snow);
	NORMAL_MAP = normalize(vec3((fine - 0.5) * 0.35, (grain - 0.5) * 0.25, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = (1.0 + joint * 2.0) * (rough < 0.1 ? 0.1 : 1.0);
}
