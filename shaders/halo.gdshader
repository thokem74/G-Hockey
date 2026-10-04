shader_type canvas_item;
render_mode unshaded;

uniform float intensity = 0.6;

void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	float glow = pow(max(0.0, 1.0 - radius), 2.5);
	COLOR = vec4(COLOR.rgb, COLOR.a * glow * intensity);
}
