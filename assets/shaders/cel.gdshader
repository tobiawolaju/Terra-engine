shader_type spatial;
render_mode unshaded;
uniform vec4 colour :source_color;
uniform sampler2D albedo_texture : source_color;
uniform bool use_albedo_texture = false;
uniform vec3 light_direction;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.2;
uniform float shadow_darkness : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec4 tex_col = colour;
	if (use_albedo_texture) {
		tex_col *= texture(albedo_texture, UV);
	}

	vec3 result = tex_col.rgb;

	vec3 world_normals = normalize((INV_VIEW_MATRIX * vec4(NORMAL.xyz, 0.0)).xyz);
	float shading = dot(world_normals, normalize(light_direction));
	float cel = smoothstep(shadow_threshold, shadow_threshold + 0.05, shading);
	cel = clamp(cel + shadow_darkness, 0.0, 1.0);
	result *= cel;

	ALBEDO = result;
}
