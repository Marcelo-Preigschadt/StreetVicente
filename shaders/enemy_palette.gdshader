shader_type canvas_item;
render_mode unshaded;
uniform vec4 armor_tint : source_color = vec4(0.33, 0.61, 0.52, 1.0);
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float green_armor = smoothstep(0.025, 0.10, pixel.g - max(pixel.r, pixel.b));
	float luminance = dot(pixel.rgb, vec3(0.25, 0.6, 0.15));
	pixel.rgb = mix(pixel.rgb, armor_tint.rgb * luminance * 2.0, green_armor * 0.9);
	COLOR = pixel * vertex_tint;
}
