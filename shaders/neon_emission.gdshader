shader_type canvas_item;
render_mode unshaded;

// COLOR already contains the texture and node tint in HDR's linear color space.
// Boost only authored neon details; ordinary UI and dark bodies keep their colors.
uniform float emission_strength : hint_range(1.0, 5.0, 0.1) = 2.5;

// A separate impact envelope leaves the baseline and Reduced effects independent.
uniform float impact_boost : hint_range(0.0, 3.0, 0.1) = 0.0;

void fragment() {
	COLOR.rgb *= emission_strength * (1.0 + impact_boost);
}
