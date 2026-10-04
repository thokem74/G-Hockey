shader_type canvas_item;
render_mode unshaded;

// COLOR already contains the texture and node tint in HDR's linear color space.
// Boost only authored neon details; ordinary UI and dark bodies keep their colors.
uniform float emission_strength : hint_range(1.0, 5.0, 0.1) = 2.5;

void fragment() {
	COLOR.rgb *= emission_strength;
}
