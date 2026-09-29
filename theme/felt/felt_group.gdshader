// Felt finish for a CanvasGroup: frays the edges with noise displacement and
// lays loose fibers over the fill (Godot's SVG rasterizer has no filters).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform float fuzz_px = 1.4;
uniform float fuzz_scale = 1.0;
uniform float fiber_scale = 1.6;
uniform vec3 fiber_color : source_color = vec3(0.42, 0.26, 0.14);
uniform float fiber_gain = 0.6;
uniform float fiber_bias = 0.2;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 q = local_pos * fuzz_scale / 256.0;
	vec2 n = vec2(texture(noise, q).r, texture(noise, q + vec2(0.37, 0.71)).r) - 0.5;
	vec4 c = textureLod(screen_texture, SCREEN_UV + n * 2.0 * fuzz_px * SCREEN_PIXEL_SIZE, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	float f = texture(noise, local_pos * fiber_scale / 256.0 + vec2(0.13, 0.29)).r;
	c.rgb = mix(c.rgb, fiber_color, clamp(fiber_gain * f - fiber_bias, 0.0, 1.0));
	COLOR *= c;
}
