shader_type canvas_item;

// Snow appearance parameters
uniform float spread : hint_range(0.0, 1.5) = 0.5;        // Snowflake spread
uniform float size : hint_range(0.01, 5.0) = 0.5;        // Snowflake size
uniform vec4 snow_color : source_color = vec4(1.0);      // Snow color
uniform float snow_transparency: hint_range(-0.5, 1.0) = 0.2;   // Intensity of the snow transparency

// Snow movement parameters
uniform float speed : hint_range(0.0, 10.0) = 0.5;
uniform float wind : hint_range(-2.0, 2.0) = 0.0;
uniform int num_of_layers = 12;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec3 snow_accumulation = vec3(0.0);
    for (int i = 0; i < num_of_layers; i++) {
        float fi = float(i);
        float layer = fi / max(1.0, float(num_of_layers - 1));
        vec2 uv = UV;
        uv.x += wind * TIME * (0.04 + layer * 0.12);
        uv.y += TIME * speed * (0.15 + layer * 0.35);

        vec2 cell = floor(uv * (4.0 + layer * 10.0));
        vec2 local = fract(uv * (4.0 + layer * 10.0)) - 0.5;
        float rnd = hash12(cell + fi);
        float flake = 1.0 - smoothstep(0.0, size * 0.22, length(local) - (rnd - 0.5) * spread * 0.25);
        snow_accumulation += snow_color.rgb * flake * (1.0 - layer * 0.55);
    }

    float snow_intensity = clamp(length(snow_accumulation), 0.0, 1.0);
    COLOR = vec4(snow_color.rgb * (1.0 + snow_transparency), snow_intensity * snow_color.a);
}
