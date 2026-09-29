// Full-screen felt grain, multiplied over everything below it.
shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec3 tint : source_color = vec3(0.45, 0.35, 0.25);
uniform float strength = 0.2;
uniform float scale = 1.0;

void fragment() {
	float n = texture(noise, FRAGCOORD.xy * scale / 256.0).r;
	COLOR = vec4(mix(vec3(1.0), tint, n * strength), 1.0);
}
