// Стрекозы над ожившей водой: носятся рывками, крылья поблёскивают.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/include_map.gdshaderinc"
#include "res://shaders/restore.gdshaderinc"

varying float vis;
varying float wing;

void vertex() {
	vec3 home = MODEL_MATRIX[3].xyz;
	float s = INSTANCE_CUSTOM.x * 10.0;
	float t = TIME * (0.6 + INSTANCE_CUSTOM.y);
	// рывки: позиция «перескакивает» между точками, быстро скользя
	float k = floor(t);
	float f = fract(t);
	f = smoothstep(0.0, 0.25, f);
	vec2 a = vec2(hash12(vec2(k, s)), hash12(vec2(k, s + 1.0))) - 0.5;
	vec2 b = vec2(hash12(vec2(k + 1.0, s)), hash12(vec2(k + 1.0, s + 1.0))) - 0.5;
	vec2 off = mix(a, b, f) * 5.0;
	vec3 p = home + vec3(off.x, 0.6 + 0.3 * sin(t * 3.0 + s), off.y);
	vis = restore_at(home);
	wing = 0.5 + 0.5 * sin(TIME * 60.0 + s);
	vec4 vp = VIEW_MATRIX * vec4(p, 1.0);
	vp.xy += VERTEX.xy * vec2(0.22, 0.08);
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	vec2 q = (UV - 0.5) * vec2(1.0, 2.6);
	float body = 1.0 - smoothstep(0.04, 0.09, abs(q.y)) ;
	body *= 1.0 - smoothstep(0.3, 0.5, abs(q.x));
	float wings = (1.0 - smoothstep(0.0, 0.35, length(vec2(abs(q.x) - 0.12, q.y * 0.6)))) * wing;
	ALBEDO = (vec3(0.1, 0.55, 0.65) * body * 2.0 + vec3(0.7, 0.85, 1.0) * wings * 0.6) * vis;
}
