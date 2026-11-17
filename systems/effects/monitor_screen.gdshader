// Old terminal screen: rows of text-like bars, scanlines, a slow rolling band
// and flicker. "powered" is an instance uniform set by Atmosphere: at 0 the
// screen is dark with faint bursts of static (emergency power only).
shader_type spatial;
render_mode unshaded, cull_back;

instance uniform float powered = 0.0;
uniform vec3 text_color : source_color = vec3(0.804, 0.933, 0.91);
uniform vec3 back_color : source_color = vec3(0.039, 0.078, 0.086);
uniform float rows = 14.0;
uniform float brightness : hint_range(0.0, 1.0) = 0.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float row = floor(uv.y * rows);
	float page = floor(t / 3.0);
	float length_ = 0.15 + 0.75 * hash(vec2(row, page));
	float in_row = step(0.25, fract(uv.y * rows)) * step(fract(uv.y * rows), 0.75);
	float bar = in_row * step(0.06, uv.x) * step(uv.x, 0.06 + length_ * 0.88);
	float blink = step(0.5, fract(t * 1.5)) * step(row, 0.5);
	float scan = 0.75 + 0.25 * sin(uv.y * 240.0);
	float roll = 1.0 + 0.25 * smoothstep(0.0, 0.1, 0.1 - abs(fract(uv.y - t * 0.12) - 0.5));
	float flick = 0.9 + 0.1 * sin(t * 37.0) * sin(t * 13.0);
	vec3 lit = mix(back_color, text_color, max(bar * 0.85, blink)) * scan * roll * flick * brightness;
	float burst = step(0.97, hash(vec2(floor(t * 8.0), 1.0)));
	vec3 dark = vec3(hash(uv * 400.0 + fract(t)) * 0.12 * burst);
	ALBEDO = mix(dark, lit, powered);
}
