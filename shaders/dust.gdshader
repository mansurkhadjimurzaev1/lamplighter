// Пылинки, видимые только в свете фонаря. Они «заворачиваются» в куб вокруг фонаря.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec3 lantern_pos;
uniform float box = 5.0;

varying float alpha;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	vec3 base = MODEL_MATRIX[3].xyz;
	vec3 drift = vec3(sin(TIME * 0.2 + c.x) * 0.3 + TIME * 0.05, sin(TIME * 0.13 + c.x * 2.0) * 0.25 + TIME * 0.02, cos(TIME * 0.17 + c.x) * 0.3);
	vec3 p = mod(base + drift - lantern_pos + box * 0.5, box) - box * 0.5 + lantern_pos;
	float d = distance(p, lantern_pos);
	float lit = 1.0 - smoothstep(0.3, 2.3, d);
	float tw = 0.6 + 0.4 * sin(TIME * (1.0 + c.y * 2.0) + c.x * 5.0);
	alpha = lit * tw;
	vec4 vp = VIEW_MATRIX * vec4(p, 1.0);
	vp.xy += VERTEX.xy * (0.03 + c.z * 0.03);
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float d = length(UV - 0.5);
	float a = 1.0 - smoothstep(0.0, 0.5, d);
	ALBEDO = vec3(1.0, 0.72, 0.42) * 1.6 * a * a * alpha;
}
