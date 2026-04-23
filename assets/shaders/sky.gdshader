shader_type sky;

uniform float coverage : hint_range(0.0, 1.0) = 0.23;     // Controls cloud coverage
uniform float thickness : hint_range(10.0, 100.0) = 55.0; // Controls cloud thickness
uniform float absorption : hint_range(0.1, 2.0) = 0.9;    // Controls light absorption in clouds
uniform vec3 sun_direction = vec3(0.0, 0.4, -1.0);       // Direction of the sun

const int MARCH_STEPS = 8; // Number of steps in ray marching


float hash(float n) {
    return fract(sin(n) * 1.0);
}

float noise(vec3 x) {
    vec3 p = floor(x);    // Integer part
    vec3 f = fract(x);    // Fractional part
    f = f * f * (3.0 - 2.0 * f);  // Smoothing function
    
    float n = p.x + p.y * 157.0 + 113.0 * p.z;
    return mix(
        mix(
            mix(hash(n + 0.0), hash(n + 1.0), f.x),
            mix(hash(n + 157.0), hash(n + 158.0), f.x),
            f.y
        ),
        mix(
            mix(hash(n + 113.0), hash(n + 114.0), f.x),
            mix(hash(n + 270.0), hash(n + 271.0), f.x),
            f.y
        ),
        f.z
    );
}


float fbm(vec3 pos, float lacunarity, float init_gain, float gain) {
    vec3 p = pos;
    float H = init_gain;
    float t = 0.0;
    
    for (int i = 0; i < 4; i++) {
        t += noise(p) * H;
        p *= lacunarity;
        H *= gain;
    }
    return t;
}

float fbm_clouds(vec3 pos, float lacunarity, float init_gain, float gain) {
    vec3 p = pos;
    float H = init_gain;
    float t = 0.0;
    
    for (int i = 0; i < 5; i++) {
        t += abs(noise(p)) * H;
        p *= lacunarity;
        H *= gain;
    }
    return t;
}


vec3 render_sky_color(vec3 eye_dir) {
    vec3 sun_color = vec3(4.8, 3.14, 3.15) * 0.65;
    float sun_amount = max(dot(eye_dir, normalize(sun_direction)), 0.0);
    
    vec3 sky = mix(vec3(0.0, 0.1, 0.4), vec3(0.3, 0.67, 0.8) * 0.9, 1.0 - eye_dir.y);
    sky += sun_color * min(pow(sun_amount, 355.0) * 6.0, 1.0);
    sky += sun_color * min(pow(sun_amount, 8.0) * 0.2, 1.0);
    
    return sky;
}


float density_func(vec3 pos, float h, float time) {
    vec3 p = pos * 0.001 + vec3(0.0, 0.0, -time * 0.11);
    float dens = fbm_clouds(p * 2.032, 2.6434, 0.5, 0.5);
    dens *= smoothstep(coverage, coverage + 0.035, dens);
    return dens;
}


vec4 render_clouds(vec3 eye_dir, vec3 pos, float time) {
    float march_step = thickness / float(MARCH_STEPS);
    vec3 projection = eye_dir / eye_dir.y;
    vec3 iter = projection * march_step;
    
    vec3 cloud_pos = pos + projection * 120.0;
    float alpha = 0.0;
    vec3 cloud_color = vec3(0.0);
    float T = 1.0;
    
    // Ray marching loop
    for (int i = 0; i < MARCH_STEPS; i++) {
        float height = (cloud_pos.y - pos.y) / thickness;
        float density = density_func(cloud_pos, height, time);
        
        float Ti = exp(-absorption * density * march_step);
        T *= Ti;
        
        cloud_color += T * exp(height) * density * march_step;
        alpha += (1.0 - Ti) * (1.0 - alpha);
        
        cloud_pos += iter;
        if (alpha > 0.99) break;
    }
    
    // Additional detail layers
    vec3 p = (cloud_pos * 0.001 + vec3(0.0, 0.0, -time * 0.11));
    float dens1 = fbm_clouds(p * 0.322, 2.2434, 0.55, 0.5);
    float dens2 = fbm_clouds(p * 0.2, 2.0, 0.5, 0.52);
    float dens3 = fbm_clouds(p * 0.2, 2.0, 0.52, 0.5);
    
    vec3 v3 = vec3(1.62);
    v3.g *= dens2 + 0.2;
    v3.b *= dens3 + 0.1;
    v3 = clamp(v3, vec3(0.0), vec3(1.0));
    
    return vec4(pow(cloud_color * v3, vec3(1.0, 0.9, 0.8)), alpha * 0.999);
}


void sky() {
    vec3 eye_dir = EYEDIR;
    
    // Render sky and clouds
    vec3 sky = render_sky_color(eye_dir);
    vec4 clouds = render_clouds(eye_dir, vec3(0.0, 2.0, 0.0), TIME);
    
    // Final color mixing
    lowp vec3 final_color = mix(sky, clouds.rgb, clouds.a);
    
    // Output to sky shader
    COLOR = final_color;
}


