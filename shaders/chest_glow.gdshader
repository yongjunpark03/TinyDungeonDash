shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.88, 0.25, 1.0);
uniform float pulse_speed : hint_range(0.5, 10.0) = 4.0;
uniform float shimmer_strength : hint_range(0.0, 0.6) = 0.22;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	if (tex_color.a > 0.1) {
		vec3 lit_rgb = mix(tex_color.rgb, glow_color.rgb, pulse * shimmer_strength);
		COLOR = vec4(lit_rgb, tex_color.a) * COLOR;
	} else {
		float n_alpha = 0.0;
		n_alpha = max(n_alpha, texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a);
		n_alpha = max(n_alpha, texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a);
		n_alpha = max(n_alpha, texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);
		n_alpha = max(n_alpha, texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);
		COLOR = vec4(glow_color.rgb, n_alpha * (0.35 + 0.45 * pulse));
	}
}
