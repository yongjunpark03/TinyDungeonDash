shader_type canvas_item;

uniform vec2 light_uv = vec2(0.5, 0.5);
uniform float torch_radius : hint_range(0.1, 1.0) = 0.34;
uniform float darkness : hint_range(0.0, 0.9) = 0.52;
uniform float flicker_speed : hint_range(0.0, 20.0) = 7.5;
uniform vec4 torch_tint : source_color = vec4(1.0, 0.62, 0.22, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.03, 0.03, 0.08, 1.0);

void fragment() {
	vec2 aspect_delta = (UV - light_uv) * vec2(1.777, 1.0);
	float dist = length(aspect_delta);
	float flicker = sin(TIME * flicker_speed) * 0.014 + cos(TIME * (flicker_speed * 1.7)) * 0.009;
	float r = max(0.08, torch_radius + flicker);
	float vignette = smoothstep(r * 0.45, r * 1.65, dist);
	float warm_band = smoothstep(r * 0.15, r * 0.85, dist) * (1.0 - smoothstep(r * 0.85, r * 1.5, dist));
	vec3 rgb = mix(shadow_color.rgb, torch_tint.rgb, warm_band * 0.35);
	float alpha = clamp(vignette * darkness + warm_band * 0.08, 0.0, 0.85);
	COLOR = vec4(rgb, alpha);
}
