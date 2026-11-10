// Тёмный дым (вокруг Теней): мягкие клубы, обычное смешивание.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/include_map.gdshaderinc"

uniform vec3 smoke_color = vec3(0.01, 0.008, 0.02); // тёмный — Тени; светлый — дым из труб
uniform float density = 0.85;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float n = vnoise(UV * 4.0 + vec2(TIME * 0.3, -TIME * 0.5) + COLOR.r * 10.0);
	float m = (1.0 - smoothstep(0.2, 1.0, d + (n - 0.5) * 0.5));
	ALBEDO = smoke_color;
	ALPHA = COLOR.a * m * density;
}
