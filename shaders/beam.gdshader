// Лунный луч сквозь кроны: вытянутая светлая полоса, всегда повёрнута к камере,
// мягко гаснет к краям и к земле, чуть «дышит». Днём (после маяка) исчезает.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/include_map.gdshaderinc"
#include "res://shaders/restore.gdshaderinc"

uniform float strength = 0.15;
varying vec3 w_base;

void vertex() {
	// поворот вокруг своей (наклонённой) оси к камере
	vec3 axis = normalize(MODEL_MATRIX[1].xyz);
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - origin);
	vec3 side = normalize(cross(axis, to_cam));
	float h = length(MODEL_MATRIX[1].xyz);
	float w = length(MODEL_MATRIX[0].xyz);
	vec3 wp = origin + side * VERTEX.x * w + axis * VERTEX.y * h;
	w_base = origin;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	float edge = 1.0 - pow(abs(UV.x - 0.5) * 2.0, 1.6);
	float vert = smoothstep(0.0, 0.25, 1.0 - UV.y) * smoothstep(0.0, 0.5, UV.y); // UV.y: 0 — верх
	float n = vnoise(vec2(UV.x * 6.0, UV.y * 2.0 - TIME * 0.05) + w_base.xz);
	float pulse = 0.75 + 0.25 * sin(TIME * 0.4 + w_base.x);
	float a = edge * vert * (0.6 + 0.4 * n) * pulse * strength * (1.0 - restore_at(w_base));
	ALBEDO = vec3(0.6, 0.72, 1.0) * a;
}
