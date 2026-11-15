// Wet tiled floor: square tiles with dark grout, per-tile tint, grime and
// mirror-smooth puddles (low roughness, no normal detail) for strong SSR.
shader_type spatial;

uniform vec3 tile_color : source_color = vec3(0.5, 0.56, 0.54);
uniform vec3 grout_color : source_color = vec3(0.12, 0.14, 0.14);
uniform float tile_size = 0.5;
uniform float grout_width = 0.012;
uniform sampler2D noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.45;
uniform float dry_roughness : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_pos;

float tile_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / tile_size;
	vec2 cell = floor(p);
	vec2 edge = min(fract(p), 1.0 - fract(p)) * tile_size;
	float grout = 1.0 - smoothstep(grout_width * 0.5, grout_width, min(edge.x, edge.y));

	float grime = texture(noise, world_pos.xz * 0.07).r;
	float fine = texture(noise, world_pos.xz * 0.6).r;
	float tint = mix(0.9, 1.08, tile_hash(cell));
	vec3 tile = tile_color * tint * mix(0.55, 1.0, smoothstep(0.3, 0.6, grime)) * mix(0.9, 1.05, fine);

	float wet = texture(noise, world_pos.xz * 0.045 + vec2(0.4, 0.1)).r;
	float puddle = smoothstep(1.0 - puddle_amount, 1.04 - puddle_amount, wet);

	vec3 albedo = mix(tile, grout_color, grout);
	ALBEDO = albedo * mix(1.0, 0.6, puddle);
	ROUGHNESS = mix(mix(dry_roughness + fine * 0.2, 0.9, grout), 0.02, puddle);
	SPECULAR = mix(0.5, 0.6, puddle);
	NORMAL_MAP = mix(texture(detail_normal, world_pos.xz * 0.5).rgb, vec3(0.5, 0.5, 1.0), puddle);
	NORMAL_MAP_DEPTH = 0.5;
}
