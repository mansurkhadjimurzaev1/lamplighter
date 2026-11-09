// Светящиеся частицы (огонь, искры, пыльца): всегда лицом к камере, складываются со светом.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float intensity = 3.0;
uniform float softness = 1.0; // 1 — мягкое пятно, 0 — резкая точка

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float m = 1.0 - smoothstep(0.0, 1.0, d);
	m = mix(step(d, 0.5), m * m, softness);
	ALBEDO = COLOR.rgb * intensity * m;
	ALPHA = COLOR.a * m;
}
