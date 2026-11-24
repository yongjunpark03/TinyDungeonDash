shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.15, 1.0);

float pixel_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 grid_uv = floor(UV * 16.0);
	float noise = pixel_hash(grid_uv);
	float vertex_flash = clamp(1.0 - COLOR.b, 0.0, 1.0);
	float vertex_dissolve = clamp(1.0 - COLOR.a, 0.0, 1.0);
	float active_flash = max(flash_amount, vertex_flash);
	float active_dissolve = max(dissolve_amount, vertex_dissolve);
	float alpha = tex.a;
	vec3 rgb = mix(tex.rgb, vec3(1.0), active_flash);

	if (active_dissolve > 0.0) {
		if (noise < active_dissolve) {
			alpha = 0.0;
		} else if (noise < active_dissolve + 0.15) {
			rgb = edge_color.rgb;
		}
	}

	COLOR = vec4(rgb, alpha);
}
