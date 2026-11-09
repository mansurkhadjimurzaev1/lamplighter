// Светлячки: светящиеся точки, плавают и мигают (долго гаснут, коротко вспыхивают).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

varying float alpha;
varying vec3 col;

void vertex() {
	vec4 c = INSTANCE_CUSTOM; // x — сдвиг фазы, y — скорость, z — оттенок
	vec3 base = MODEL_MATRIX[3].xyz;
	float t = TIME * 0.25 * c.y + c.x;
	vec3 p = base + vec3(sin(t * 1.3) * 1.2 + sin(t * 3.1) * 0.25, sin(t * 1.7) * 0.35, cos(t * 1.1) * 1.2 + cos(t * 2.3) * 0.25);
	float blink = pow(max(0.0, sin(TIME * (0.6 + c.z * 0.8) + c.x * 7.0)), 6.0);
	alpha = blink * 1.6 + 0.04;
	col = mix(vec3(1.0, 0.85, 0.35), vec3(0.75, 1.0, 0.45), c.z) * 3.0;
	float size = 0.2 + blink * 0.12;
	vec4 vp = VIEW_MATRIX * vec4(p, 1.0);
	vp.xy += VERTEX.xy * size;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float d = length(UV - 0.5);
	float a = 1.0 - smoothstep(0.0, 0.5, d);
	ALBEDO = col * a * a * alpha;
}
