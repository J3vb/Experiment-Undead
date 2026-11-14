shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.55, 0.0, 0.0, 1.0);

void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p * vec2(1.0, 0.8));
	float edge = smoothstep(0.25, 0.75, d);
	COLOR = vec4(tint.rgb, edge * intensity * 0.9);
}
