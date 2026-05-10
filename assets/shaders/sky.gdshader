shader_type sky;

uniform vec3 sun_direction = vec3(0.0, 0.4, -1.0);
uniform vec3 horizon_color = vec3(0.0, 0.1, 0.4);
uniform vec3 zenith_color = vec3(0.27, 0.6, 0.76);
uniform float cloud_speed = 0.02;
uniform float cloud_strength = 0.28;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float cloud_band(vec2 uv, float scale, float offset) {
	vec2 p = uv * scale + vec2(TIME * cloud_speed * offset, TIME * cloud_speed * 0.5);
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	float a = hash12(cell);
	float b = hash12(cell + vec2(1.0, 0.0));
	float c = hash12(cell + vec2(0.0, 1.0));
	float d = hash12(cell + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	float n = mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
	return smoothstep(0.45, 0.85, n);
}


void sky() {
    vec3 eye_dir = normalize(EYEDIR);
    float height = clamp(eye_dir.y * 0.5 + 0.5, 0.0, 1.0);
    vec3 sky = mix(horizon_color, zenith_color, height);

    float sun_amount = max(dot(eye_dir, normalize(sun_direction)), 0.0);
    sky += vec3(1.0, 0.82, 0.62) * pow(sun_amount, 180.0) * 1.2;

    vec2 cloud_uv = eye_dir.xz / max(0.2, eye_dir.y + 1.2);
    float clouds = cloud_band(cloud_uv, 1.2, 0.8);
    clouds += cloud_band(cloud_uv, 2.1, -0.6) * 0.5;
    clouds = clamp(clouds, 0.0, 1.0);

    COLOR = mix(sky, vec3(1.0), clouds * cloud_strength);
}

