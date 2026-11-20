// Tripo-baked zombie (albedo, normal, ORM) whose green veins glow bio-green: only texels where green beats red
// and blue light up, so the grey skin stays dark. One shared material per model, made by zombie_import.gd.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap;
uniform vec3 glow_color : source_color = vec3(0.553, 1.0, 0.227);
uniform float glow_strength : hint_range(0.0, 8.0) = 2.0;

void fragment() {
	vec3 color = texture(albedo_tex, UV).rgb;
	vec3 orm = texture(orm_tex, UV).rgb;
	ALBEDO = color;
	AO = orm.r;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	float vein = smoothstep(0.04, 0.15, color.g - max(color.r, color.b));
	EMISSION = glow_color * vein * glow_strength;
}
