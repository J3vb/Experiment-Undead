// Downed and death screen: desaturation, red edge vignette, white flash, fade to black.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float black : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.765, 0.125, 0.106, 1.0);

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(grey), col, saturation);
	vec2 p = UV - 0.5;
	float edge = smoothstep(0.3, 0.75, length(p * vec2(1.0, 0.8)));
	col = mix(col, tint.rgb, edge * vignette);
	col = mix(col, vec3(1.0), flash);
	col = mix(col, vec3(0.0), black);
	COLOR = vec4(col, 1.0);
}
