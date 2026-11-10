// Вода топи: тёмная, непрозрачная, мутно-зелёная; отражения (зонд отражений + блики),
// мелкая рябь, круги от капель и всплывающих пузырей. Над трясинами — ряска.
// После маяка вода светлеет и становится чище.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/include_map.gdshaderinc"
#include "res://shaders/restore.gdshaderinc"

global uniform vec3 lantern_pos;
uniform sampler2D ripple : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 bogs[4]; // x, z, радиус
uniform vec3 swamp = vec3(74.0, -12.0, 36.0);
uniform float rings_on = 1.0;

varying vec3 w_pos;

// круги на воде: в каждой клетке иногда расходится кольцо
vec2 rings(vec2 p, float t) {
	vec2 cell = floor(p);
	vec2 grad = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			float h = hash12(c);
			float period = 3.0 + h * 5.0;
			float age = mod(t + h * 17.0, period);
			if (h > 0.45 && age < 1.6) {
				vec2 center = c + vec2(hash12(c + 3.1), hash12(c + 7.7));
				vec2 d = p - center;
				float r = length(d);
				float ring = age * 0.7;
				float w = exp(-pow((r - ring) * 9.0, 2.0)) * (1.0 - age / 1.6);
				grad += normalize(d + 1e-4) * w * sin((r - ring) * 30.0);
			}
		}
	}
	return grad;
}

float wave_h(vec2 p) {
	float t = TIME;
	return vnoise(p * 1.3 + vec2(t * 0.15, t * 0.1)) * 0.05 + vnoise(p * 3.7 - vec2(t * 0.2, -t * 0.12)) * 0.025 + vnoise(p * 9.0 + t * 0.3) * 0.008;
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (distance(w_pos.xz, swamp.xy) > swamp.z) discard;
	vec2 uv = map_uv(w_pos.xz);
	float depth = -texture(height_map, uv).r; // >0 — под водой
	float rs = restore_at(w_pos);

	// ряска над трясиной
	float bog = 0.0;
	for (int i = 0; i < 4; i++) {
		bog = max(bog, 1.0 - smoothstep(bogs[i].z * 0.5, bogs[i].z * 1.05, distance(w_pos.xz, bogs[i].xy)));
	}
	float duck = smoothstep(0.35, 0.65, vnoise(w_pos.xz * 1.6) * 0.7 + vnoise(w_pos.xz * 6.0) * 0.3) * bog;

	vec3 murky = mix(vec3(0.03, 0.05, 0.025), vec3(0.06, 0.1, 0.08), rs);
	vec3 shallow = mix(vec3(0.07, 0.09, 0.04), vec3(0.14, 0.2, 0.12), rs);
	vec3 col = mix(shallow, murky, smoothstep(0.05, 0.9, depth));
	col = mix(col, vec3(0.12, 0.2, 0.05) * mix(0.8, 1.3, rs), duck * 0.9);

	// рябь: высоты из шума, нормаль — по разностям (без текстуры, без повторов)
	vec2 p = w_pos.xz;
	float e = 0.08;
	float h0 = wave_h(p);
	vec3 nm = normalize(vec3((h0 - wave_h(p + vec2(e, 0.0))) / e, (h0 - wave_h(p + vec2(0.0, e))) / e, 1.0));
	vec2 rg = rings(w_pos.xz * 0.9, TIME) * (1.0 - duck) * rings_on;
	nm.xy += rg * 0.6;
	NORMAL_MAP = normalize(nm) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = mix(0.22, 0.1, duck);

	ALBEDO = col;
	ROUGHNESS = mix(0.16, 0.7, duck);
	SPECULAR = 0.6;
	METALLIC = 0.0;

	// дрожащее отражение фонаря
	vec2 dl = w_pos.xz - lantern_pos.xz;
	// неровные бегущие блики (не шахматка)
	float shimmer = 0.65 + 0.35 * sin(dot(w_pos.xz, vec2(4.3, 2.1)) + TIME * 2.1 + vnoise(w_pos.xz * 1.7 + TIME * 0.4) * 5.0);
	EMISSION = vec3(1.0, 0.5, 0.18) * exp(-dot(dl, dl) * 0.3) * shimmer * 0.35 * (1.0 - duck);
	// у берегов/кочек вода «тает» в землю
	ALPHA = 1.0;
}
