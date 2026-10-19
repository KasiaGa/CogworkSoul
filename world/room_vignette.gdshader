shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float radius : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float softness : hint_range(0.01, 1.0, 0.01) = 0.5;

void fragment() {
	float distance_from_center = distance(SCREEN_UV, vec2(0.5, 0.5));
	float vignette = smoothstep(radius, radius + softness, distance_from_center);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * strength);
}