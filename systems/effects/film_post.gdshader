shader_type canvas_item;

uniform float vignette : hint_range(0.0, 1.0) = 0.38;
uniform float grain : hint_range(0.0, 0.3) = 0.045;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, 0.85);
	float dark = smoothstep(0.2, 0.75, length(p)) * vignette * 1.6;
	float n = hash(FRAGCOORD.xy + fract(TIME) * 61.0) * 2.0 - 1.0;
	vec3 col = n > 0.0 ? vec3(1.0) : vec3(0.0);
	float a = clamp(dark + abs(n) * grain, 0.0, 1.0);
	COLOR = vec4(mix(col, vec3(0.0), dark / max(a, 0.001)), a);
}
