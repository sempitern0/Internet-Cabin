shader_type canvas_item;
// Original restrained CC0-inspired VHS treatment: screen sampling, scanlines,
// luminance-sensitive chroma noise and rare tracking instability.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.18;
uniform float tracking : hint_range(0.0, 1.0) = 0.08;
uniform float time_speed : hint_range(0.0, 3.0) = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
    float t = TIME * time_speed;
    vec2 uv = SCREEN_UV;
    float disturbance = sin(uv.y * 145.0 + t * 0.65) * tracking * 0.00055;
    uv.x += disturbance;
    vec3 c = texture(screen_texture, uv).rgb;
    float stripe = sin(FRAGCOORD.y * 1.8) * 0.022 * intensity;
    float n = hash(floor(FRAGCOORD.xy * 0.65) + floor(t * 13.0));
    float shadow = 1.0 - dot(c, vec3(0.2126, 0.7152, 0.0722));
    c += (n - 0.5) * 0.075 * intensity * shadow;
    c -= stripe;
    COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
