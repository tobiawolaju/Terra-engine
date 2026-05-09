shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 base_tint : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 loss_color : source_color = vec4(1.0, 0.15, 0.15, 1.0);
uniform vec4 gain_color : source_color = vec4(0.25, 1.0, 0.45, 1.0);
uniform float base_opacity : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale : hint_range(1.0, 40.0) = 12.0;
uniform float oxygen_level : hint_range(0.0, 1.0) = 1.0;
uniform bool loss_active = false;
uniform float loss_amount : hint_range(0.0, 1.0) = 0.0;
uniform bool gain_active = false;
uniform float gain_amount : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);
	float angle = atan(centered.x, centered.y);
	float swirl = sin(angle * 8.0 - TIME * 4.0) * 0.5 + 0.5;
	float noise = hash21(floor(uv * noise_scale + TIME * 2.0));
	float edge_mask = pow(1.0 - abs(uv.y * 2.0 - 1.0), 1.6);

	vec3 color = base_tint.rgb;
	float alpha = base_opacity * base_tint.a;

	if (loss_active) {
		float warning_band = smoothstep(0.0, 0.2, uv.y) * (1.0 - smoothstep(0.75, 1.0, uv.y));
		float pulse = sin(TIME * (5.0 + loss_amount * 4.0) - uv.y * 18.0) * 0.5 + 0.5;
		float crackle = mix(swirl, noise, 0.35);
		float loss_glow = warning_band * pulse * crackle * edge_mask * max(loss_amount, 0.15);
		color += loss_color.rgb * loss_glow * 2.5;
		alpha += loss_glow * loss_color.a;
	}

	if (gain_active) {
		float sweep_head = fract(TIME * 0.45 + gain_amount * 0.35);
		float sweep = 1.0 - smoothstep(0.0, 0.22, abs(uv.y - sweep_head));
		float shimmer = sin((angle + TIME * 3.0) * 10.0) * 0.5 + 0.5;
		float gain_glow = sweep * mix(0.65, 1.0, shimmer) * edge_mask * max(gain_amount, 0.2);
		color += gain_color.rgb * gain_glow * 2.2;
		alpha += gain_glow * gain_color.a;
	}

	ALBEDO = color;
	EMISSION = color;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
