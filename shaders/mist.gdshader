// Зелёная дымка над топью: большие мягкие клубы низко над водой, медленно плывут.
// После маяка редеют и становятся тёплыми, утренними.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/include_map.gdshaderinc"
#include "res://shaders/restore.gdshaderinc"

global uniform vec3 hero_pos;
varying float fade;
varying vec3 wpos;

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec4 c = INSTANCE_CUSTOM;
	base += vec3(sin(TIME * 0.05 + c.x) * 3.0, sin(TIME * 0.11 + c.x * 2.0) * 0.15, cos(TIME * 0.04 + c.x) * 3.0);
	wpos = base;
	// у героя дымка расступается, чтобы не закрывать его
	fade = smoothstep(2.5, 7.0, distance(base.xz, hero_pos.xz));
	vec4 vp = VIEW_MATRIX * vec4(base, 1.0);
	vp.xy += VERTEX.xy * s;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	vec2 q = UV - 0.5;
	float d = length(q) * 2.0;
	// мягкий клуб без мелкого шума (шум давал заметную «клетку» в свете фонаря)
	float wob = 0.5 + 0.25 * sin(atan(q.y, q.x) * 3.0 + TIME * 0.2 + wpos.x) + 0.25 * sin(atan(q.y, q.x) * 5.0 - TIME * 0.15 + wpos.z);
	float a = 1.0 - smoothstep(0.15, 1.0, d + (wob - 0.5) * 0.25);
	a *= a;
	float rs = restore_at(wpos);
	ALBEDO = mix(vec3(0.16, 0.24, 0.12), vec3(0.6, 0.55, 0.45), rs);
	ALPHA = a * 0.16 * fade * mix(1.0, 0.35, rs);
}
