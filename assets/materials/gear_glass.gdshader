// Clear specimen and optical glass. The separate transparent pass leaves opaque gear unchanged.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

// #CDEEE8 fluorescent tint from the Cold Containment palette.
uniform vec3 albedo : source_color = vec3(0.80392, 0.93333, 0.90980);

// Match the shared gear shader's instance slots on meshes with both finishes.
instance uniform vec4 dye_main : source_color = vec4(1.0);
instance uniform vec4 dye_accent : source_color = vec4(1.0);
instance uniform vec4 trim_color : source_color = vec4(0.85098, 0.85098, 0.82353, 1.0);
instance uniform vec4 glow_color : source_color = vec4(0.85098, 0.85098, 0.82353, 1.0);
instance uniform float glow_strength : hint_range(0.0, 2.0) = 0.0;
instance uniform float pulse_seconds : hint_range(0.0, 10.0) = 0.0;
instance uniform bool flicker = false;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float edge = pow(1.0 - facing, 4.0);
	float polish = fract(sin(dot(floor(obj_pos * 1800.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	int zone = int(round(COLOR.a * 3.0));
	vec3 tint = albedo * (zone == 3 ? dye_main.rgb : dye_accent.rgb);
	ALBEDO = tint * mix(0.90, 1.0, COLOR.r);
	ROUGHNESS = 0.085 + polish * 0.025;
	METALLIC = 0.0;
	SPECULAR = 0.65;
	ALPHA = mix(0.12, 0.52, edge);
}
