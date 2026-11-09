// Тёмная вода: прозрачное мелководье у берега, тонкая кромка прибоя,
// мелкая рябь и дрожащее отражение фонаря.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

#include "res://shaders/include_map.gdshaderinc"

global uniform vec3 lantern_pos;
uniform sampler2D ripple : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = map_uv(w_pos.xz);
	bool inside = uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0;
	float depth = inside ? -texture(height_map, uv).r : 4.0;

	ALBEDO = vec3(0.004, 0.008, 0.022);
	ROUGHNESS = 0.32;
	SPECULAR = 0.5;
	vec3 n1 = texture(ripple, w_pos.xz * 0.11 + vec2(TIME * 0.012, TIME * 0.008)).xyz;
	vec3 n2 = texture(ripple, w_pos.xz * 0.23 - vec2(TIME * 0.01, -TIME * 0.014)).xyz;
	NORMAL_MAP = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.35;

	float alpha = smoothstep(0.0, 0.55, depth) * 0.94;
	float edge = (1.0 - smoothstep(0.0, 0.12, abs(depth - 0.06))) * (0.6 + 0.4 * sin(TIME * 1.3 + w_pos.x * 2.0 + w_pos.z * 1.7));
	vec3 emit = vec3(0.05, 0.07, 0.12) * edge;

	vec2 dl = w_pos.xz - lantern_pos.xz;
	float shimmer = 0.55 + 0.45 * sin(w_pos.x * 7.0 + TIME * 2.1) * sin(w_pos.z * 6.0 - TIME * 1.7);
	float glow = exp(-dot(dl, dl) * 0.35) * shimmer;
	emit += vec3(1.0, 0.5, 0.18) * glow * 0.45;
	EMISSION = emit;
	ALPHA = max(alpha, glow * 0.6 * smoothstep(0.0, 0.3, depth));
}
