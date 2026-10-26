shader_type canvas_item;
// Restrained analog video degradation applied only to the cabin image.
// Designed for Nucleus BACKBUFFER: the screen was drawn before this overlay.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.45;
uniform float tracking : hint_range(0.0, 1.0) = 0.18;
uniform float time_speed : hint_range(0.0, 3.0) = 1.0;

float noise21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float t = TIME * time_speed;
	vec2 uv = SCREEN_UV;
	float tear = step(0.993, noise21(vec2(floor(t * 1.2), floor(uv.y * 9.0))));
	uv.x += sin(uv.y * 180.0 + t * 0.75) * tracking * intensity * 0.0014;
	uv.x += tear * tracking * intensity * 0.0018;
	vec2 separation = vec2(0.0008 * intensity, 0.0);
	float r = texture(screen_texture, uv + separation).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - separation).b;
	vec3 color = vec3(r, g, b);
	float scan = 0.5 + 0.5 * sin(FRAGCOORD.y * 1.6);
	color *= 1.0 - scan * (0.045 * intensity);
	float grain = noise21(floor(FRAGCOORD.xy * 0.8) + floor(t * 19.0));
	float shadows = 1.0 - dot(color, vec3(0.2126, 0.7152, 0.0722));
	color += (grain - 0.5) * shadows * intensity * 0.12;
	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
