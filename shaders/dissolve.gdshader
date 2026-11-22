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
	float alpha = tex.a;
	vec3 rgb = mix(tex.rgb, vec3(1.0), flash_amount);

	if (dissolve_amount > 0.0) {
		if (noise < dissolve_amount) {
			alpha = 0.0;
		} else if (noise < dissolve_amount + 0.15) {
			rgb = edge_color.rgb;
		}
	}

	COLOR = vec4(rgb, alpha);
}
