// Светящиеся грибы: бирюзовые шляпки мягко «дышат» светом; после рассвета светятся слабее.
shader_type spatial;

#include "res://shaders/include_map.gdshaderinc"
#include "res://shaders/restore.gdshaderinc"

uniform vec3 glow : source_color = vec3(0.35, 0.95, 0.85);
varying vec3 w_pos;
varying float cap;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	cap = COLOR.r; // 1 — шляпка, 0 — ножка
}

void fragment() {
	float ph = hash12(floor(w_pos.xz * 2.0)) * 6.28;
	float breathe = 0.65 + 0.35 * sin(TIME * 0.9 + ph);
	float rs = restore_at(w_pos);
	vec3 stem = vec3(0.75, 0.78, 0.72);
	ALBEDO = mix(stem * 0.6, glow * 0.5, cap);
	EMISSION = glow * cap * 2.2 * breathe * mix(1.0, 0.25, rs) + glow * (1.0 - cap) * 0.15;
	ROUGHNESS = 0.6;
}
