// Scope lens: shows the scope camera's zoomed picture, matched to the screen,
// with a thin crosshair and a centre dot.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D view : source_color, filter_linear;
uniform vec3 reticle_color : source_color = vec3(0.05, 0.05, 0.05);
uniform vec3 dot_color : source_color = vec3(1.0, 0.25, 0.1);

void fragment() {
	vec2 px = (SCREEN_UV - 0.5) * VIEWPORT_SIZE;
	vec3 color = texture(view, SCREEN_UV).rgb;
	float lines = step(abs(px.x), 1.0) + step(abs(px.y), 1.0);
	float gap = step(12.0, length(px));
	color = mix(color, reticle_color, clamp(lines * gap, 0.0, 1.0));
	color = mix(color, dot_color, step(length(px), 2.5));
	ALBEDO = color;
}
