// Деревья, камни, кусты: исходный цвет модели + детали:
// затемнение у земли (как AO), пятна оттенка, кора с волокнами,
// камень с настоящей текстурой и мхом сверху, лёгкое покачивание крон.
// Всё, что стоит между камерой и героем, растворяется «сеточкой».
shader_type spatial;
render_mode cull_back;

#include "res://shaders/include_map.gdshaderinc"

global uniform vec3 hero_pos;

uniform vec3 albedo : source_color = vec3(0.5);
uniform int kind = 0; // 0 — листва/прочее, 1 — камень, 2 — дерево (кора)
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;

varying vec3 w_pos;
varying vec3 w_nrm;
varying float ly; // 0 — у земли, 1 — верхушка

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// INSTANCE_CUSTOM: x — высота основания, y — высота модели
	ly = clamp((wp.y - INSTANCE_CUSTOM.x) / max(INSTANCE_CUSTOM.y, 0.01), 0.0, 1.0);
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (kind != 1) {
		// кроны чуть качаются на ветру
		float sway = sin(TIME * 0.9 + wp.x * 0.3 + wp.z * 0.2) * 0.5 + sin(TIME * 1.7 + wp.x * 0.7) * 0.2;
		vec3 off = vec3(sway, 0.0, sway * 0.4) * ly * ly * 0.08 * INSTANCE_CUSTOM.y * 0.25;
		VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
		wp += off;
	}
	w_pos = wp;
}

void fragment() {
	// растворение загораживающих героя объектов
	vec3 hv = (VIEW_MATRIX * vec4(hero_pos + vec3(0.0, 0.8, 0.0), 1.0)).xyz;
	if (VERTEX.z > hv.z + 0.6) {
		vec2 a = VERTEX.xy / -VERTEX.z;
		vec2 b = hv.xy / -hv.z;
		float hide = 1.0 - smoothstep(0.12, 0.24, length(a - b));
		if (hide > 0.0 && hash12(floor(FRAGCOORD.xy)) < hide * 0.85) discard;
	}

	float ao = mix(0.35, 1.0, smoothstep(0.0, 0.35, ly));
	float n = vnoise(w_pos.xz * 1.7 + w_pos.y * 0.9) * 0.6 + vnoise(w_pos.xz * 6.0 + w_pos.y * 4.0) * 0.4;
	vec3 col = albedo * ao * mix(0.78, 1.18, n);
	float rough = 0.9;

	if (kind == 1) {
		vec3 nn = normalize(w_nrm);
		vec3 bw = pow(abs(nn), vec3(4.0));
		bw /= bw.x + bw.y + bw.z;
		vec3 tc = texture(rock_tex, w_pos.zy * 0.45).rgb * bw.x + texture(rock_tex, w_pos.xz * 0.45).rgb * bw.y + texture(rock_tex, w_pos.xy * 0.45).rgb * bw.z;
		col = mix(col, tc * 0.75 * ao, 0.85);
		float moss = smoothstep(0.55, 0.9, nn.y + (n - 0.5) * 0.5);
		col = mix(col, vec3(0.06, 0.1, 0.035) * mix(0.7, 1.3, n), moss * 0.7);
		rough = 0.8;
	} else if (kind == 2) {
		float fib = vnoise(vec2(atan(w_nrm.z, w_nrm.x) * 6.0, w_pos.y * 0.8)) * 0.5 + vnoise(w_pos.xz * 30.0 + w_pos.y * 2.0) * 0.5;
		col *= mix(0.6, 1.25, fib);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
