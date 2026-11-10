// Светлячки-проводники: тёплые огоньки над верной тропой.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

varying float alpha;

void vertex() {
	alpha = INSTANCE_CUSTOM.r;
	float blink = 0.6 + 0.4 * sin(TIME * 4.0 + INSTANCE_CUSTOM.g * 20.0);
	alpha *= blink;
	vec4 vp = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	vp.xy += VERTEX.xy * (0.16 + 0.06 * blink);
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float m = 1.0 - smoothstep(0.0, 1.0, d);
	ALBEDO = vec3(1.0, 0.82, 0.4) * 4.0 * m * m * alpha;
}
