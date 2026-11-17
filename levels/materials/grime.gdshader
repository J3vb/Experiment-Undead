// Painted or concrete surface with world-space grime: vertical drip streaks,
// a dirt band near the floor and blotchy stains on ceilings. Works on any mesh
// without UVs, so modular kit pieces never show a repeating pattern.
// Optional texture sets (tools/assets/surface_textures.py) add surface detail,
// mapped in world space too: albedo_map tints base_color, orm_map packs
// occlusion, roughness and a metal mask. Without them the surface looks as before.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.37, 0.43, 0.41);
uniform float roughness : hint_range(0.0, 1.0) = 0.75;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.12;
uniform float streaks : hint_range(0.0, 1.0) = 0.5;
uniform float floor_dirt : hint_range(0.0, 1.0) = 0.5;
uniform float stains : hint_range(0.0, 1.0) = 0.4;
uniform float ceiling_height = 3.0;
uniform sampler2D albedo_map : source_color, hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float texel_scale = 2.0;
uniform float map_normal_strength : hint_range(0.0, 2.0) = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float facing_up = abs(world_normal.y);
	float along = world_pos.x + world_pos.z;
	vec2 wall_uv = vec2(along, world_pos.y);

	float drip = texture(noise, vec2(along * 0.9, world_pos.y * 0.06)).r;
	float drip_length = texture(noise, vec2(along * 0.25 + 0.5, 0.3)).r;
	float from_top = clamp((ceiling_height - world_pos.y) / (ceiling_height * drip_length + 0.01), 0.0, 1.0);
	float streak = smoothstep(0.42, 0.6, drip) * (1.0 - from_top) * streaks;

	float blotch = texture(noise, wall_uv * 0.11 + vec2(0.31, 0.17)).r;
	float dirt = smoothstep(0.7, 0.0, world_pos.y) * mix(0.5, 1.0, blotch) * floor_dirt;

	float stain_noise = texture(noise, world_pos.xz * 0.09 + vec2(0.7, 0.2)).r;
	float stain = smoothstep(0.42, 0.62, stain_noise) * stains;
	float stain_ring = smoothstep(0.4, 0.44, stain_noise) - smoothstep(0.44, 0.5, stain_noise);

	float wall_grime = max(streak, dirt);
	float grime = mix(wall_grime, stain + stain_ring * stains * 0.6, step(0.5, facing_up));
	float variation = mix(0.88, 1.08, blotch);

	vec2 map_uv = mix(vec2(along, -world_pos.y), world_pos.xz, step(0.5, facing_up)) / texel_scale;
	vec3 orm = texture(orm_map, map_uv).rgb;

	ALBEDO = base_color * COLOR.rgb * texture(albedo_map, map_uv).rgb * variation * (1.0 - grime * 0.75);
	ROUGHNESS = clamp(roughness * orm.g + grime * 0.2 - streak * 0.35, 0.0, 1.0);
	METALLIC = metallic * orm.b;
	AO = orm.r;
	vec2 detail_uv = mix(wall_uv, world_pos.xz, step(0.5, facing_up)) * 0.6;
	// Only x and y are read: compressed normal maps carry two channels.
	vec2 detail = (texture(detail_normal, detail_uv).rg * 2.0 - 1.0) * normal_strength;
	vec2 surface = (texture(normal_map, map_uv).rg * 2.0 - 1.0) * map_normal_strength;
	vec2 bent = detail + surface;
	NORMAL_MAP = vec3(bent * 0.5 + 0.5, 1.0);
}
