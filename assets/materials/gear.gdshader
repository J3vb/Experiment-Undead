// Alpha stores paint zones; RGB retains the baked AO from the model builder.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.35, 0.40, 0.37, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform int finish = 0;
instance uniform vec4 main_color : source_color = vec4(0.373, 0.427, 0.408, 1.0);
instance uniform vec4 accent_color : source_color = vec4(0.184, 0.224, 0.231, 1.0);
instance uniform vec4 trim_color : source_color = vec4(0.851, 0.851, 0.824, 1.0);
instance uniform float glow_strength : hint_range(0.0, 2.0) = 0.0;
instance uniform float pulse_seconds = 0.0;
instance uniform bool flicker = false;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float main_zone = step(0.835, COLOR.a);
	float accent_zone = step(0.5, COLOR.a) * (1.0 - main_zone);
	float trim_zone = step(0.165, COLOR.a) * (1.0 - main_zone - accent_zone);
	float glow_zone = 1.0 - main_zone - accent_zone - trim_zone;
	vec3 dye = main_color.rgb * main_zone + accent_color.rgb * accent_zone;
	vec3 paint = dye + trim_color.rgb * (trim_zone + glow_zone);
	float weave = sin(local_position.x * 1800.0) * sin(local_position.y * 1800.0)
		* sin(local_position.z * 1800.0);
	float fabric = finish < 2 ? 1.0 : 0.0;
	ALBEDO = paint * mix(vec3(1.0), albedo.rgb, 0.14) * COLOR.rgb * (1.0 + weave * 0.025 * fabric);
	METALLIC = metallic * (1.0 - fabric);
	ROUGHNESS = clamp(roughness + weave * 0.035 * fabric - trim_zone * 0.12, 0.2, 1.0);
	float pulse = pulse_seconds > 0.0 ? 0.8 + 0.2 * sin(TIME * 6.283185 / pulse_seconds) : 1.0;
	float unstable = flicker ? 0.75 + 0.25 * sin(TIME * 23.0) * sin(TIME * 7.0) : 1.0;
	EMISSION = trim_color.rgb * glow_zone * glow_strength * pulse * unstable;
}
