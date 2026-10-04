shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 p = UV;
	float cyan = exp(-length((p - vec2(0.1, 0.9)) * vec2(1.1, 0.8)) * 5.0);
	float pink = exp(-length((p - vec2(0.9, 0.1)) * vec2(1.1, 0.8)) * 5.0);
	vec3 base = vec3(0.018, 0.029, 0.055);
	base += vec3(0.015, 0.15, 0.18) * cyan;
	base += vec3(0.16, 0.025, 0.085) * pink;
	// The authored palette is sRGB; HDR canvas shader output is linear.
	base = mix(base / 12.92, pow((base + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), base));
	COLOR = vec4(base, 1.0);
}
