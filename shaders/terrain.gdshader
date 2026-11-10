// Земля: смешение текстур травы, земли и камня по весам (высота, наклон, шум).
shader_type spatial;
render_mode cull_back;

#include "res://shaders/restore.gdshaderinc"

uniform sampler2D grass_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pave_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pave_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec3 w_weights;
uniform vec3 forest = vec3(0.0, -66.0, 38.0); // центр (x, z) и радиус леса
uniform vec3 swamp = vec3(74.0, -12.0, 36.0);
uniform vec3 mountain = vec3(-78.0, 2.0, 38.0);
varying float w_pave;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	w_weights = COLOR.rgb;
	w_pave = COLOR.a;
}

float hash_t(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise_t(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_t(i), hash_t(i + vec2(1, 0)), f.x), mix(hash_t(i + vec2(0, 1)), hash_t(i + vec2(1, 1)), f.x), f.y); }

// две выборки разного масштаба — убирают заметный повтор текстуры
vec4 sample2(sampler2D t, vec2 p, float s) {
	vec2 q = vec2(p.x * 0.8 - p.y * 0.6, p.x * 0.6 + p.y * 0.8);
	return mix(texture(t, p * s), texture(t, q * s * 0.37 + 0.31), 0.35);
}

// переход с учётом «высоты» текстур — края естественнее
vec3 blend_w(vec3 w, vec3 hgt) {
	vec3 b = w + hgt * 0.35;
	float m = max(b.x, max(b.y, b.z)) - 0.22;
	vec3 r = max(b - m, 0.0);
	return r / (r.x + r.y + r.z + 1e-4);
}

void fragment() {
	vec2 wp = w_pos.xz;
	vec3 w = w_weights;
	vec4 cg = w.x > 0.004 ? sample2(grass_c, wp, 0.32) : vec4(0.0);
	vec4 cd = w.y > 0.004 ? sample2(dirt_c, wp, 0.28) : vec4(0.0);
	vec4 cr = w.z > 0.004 ? sample2(rock_c, wp, 0.2) : vec4(0.0);
	vec3 gw = blend_w(w, vec3(dot(cg.rgb, vec3(0.33)), dot(cd.rgb, vec3(0.33)), dot(cr.rgb, vec3(0.33))));
	vec3 col = cg.rgb * vec3(0.85, 1.0, 0.8) * gw.x + cd.rgb * gw.y + cr.rgb * gw.z;
	// в лесу: трава — мох (темнее, холоднее), земля — хвоя
	float fo = 1.0 - smoothstep(forest.z - 14.0, forest.z, distance(wp, forest.xy));
	col = mix(col, col * vec3(0.55, 0.85, 0.7) * gw.x + col * vec3(0.7, 0.62, 0.55) * (1.0 - gw.x), fo * 0.85);
	// топь: тёмный ил, бурый мох; под водой — ещё темнее
	float sw = 1.0 - smoothstep(swamp.z - 6.0, swamp.z + 4.0, distance(wp, swamp.xy));
	col = mix(col, col * vec3(0.55, 0.58, 0.4), sw);
	col *= mix(1.0, 0.45, sw * (1.0 - smoothstep(-0.5, 0.1, w_pos.y)));
	col *= mix(0.75, 1.15, texture(dirt_c, wp * 0.013).r); // крупные пятна
	// брусчатка: камни проступают сквозь землю по краям неровно
	float pv = 0.0;
	vec4 cp = vec4(0.0);
	if (w_pave > 0.01) {
		cp = texture(pave_c, wp * 0.42);
		pv = smoothstep(0.35, 0.65, w_pave + (dot(cp.rgb, vec3(0.33)) - 0.4) * 0.6);
		col = mix(col, cp.rgb * 0.95, pv);
	}
	// горы: снег на пологих местах выше снеговой линии; на крутом — голый камень с инеем
	float mt = 1.0 - smoothstep(mountain.z - 8.0, mountain.z + 2.0, distance(wp, mountain.xy));
	float flatness = smoothstep(0.75, 0.92, normalize(w_nrm).y);
	float snow_line = smoothstep(3.0, 6.0, w_pos.y + (vnoise_t(wp * 0.6) - 0.5) * 2.0);
	float snow = mt * snow_line * mix(0.25, 1.0, flatness) * (1.0 - pv * 0.7);
	vec3 snow_col = vec3(0.74, 0.78, 0.86) * mix(0.85, 1.05, vnoise_t(wp * 3.0));
	col = mix(col, snow_col, clamp(snow, 0.0, 1.0));
	// ночь под Пеленой — краски приглушены; ожившая земля — сочная и тёплая
	float rs = restore_at(w_pos);
	vec3 night = mix(vec3(dot(col, vec3(0.33))), col, 0.7);
	vec3 alive = col * mix(vec3(1.12, 1.05, 0.92), vec3(0.95, 1.45, 0.75), gw.x) * 1.15;
	ALBEDO = mix(night, alive, rs);
	EMISSION = vec3(1.0, 0.68, 0.32) * wave_edge(w_pos) * 0.9;
	ROUGHNESS = 0.95 - gw.z * 0.25 - pv * 0.15 - snow * 0.35;

	// рельеф поверхности: нормали текстур смешиваются и «наклоняют» нормаль земли
	vec3 nm = vec3(0.0);
	float nw = 0.0;
	if (gw.x > 0.01) { nm += texture(grass_n, wp * 0.32).xyz * gw.x; nw += gw.x; }
	if (gw.y > 0.01) { nm += texture(dirt_n, wp * 0.28).xyz * gw.y; nw += gw.y; }
	if (gw.z > 0.01) { nm += texture(rock_n, wp * 0.2).xyz * gw.z; nw += gw.z; }
	nm = nm / max(nw, 1e-3) * 2.0 - 1.0;
	if (pv > 0.01) nm = mix(nm, texture(pave_n, wp * 0.42).xyz * 2.0 - 1.0, pv);
	vec3 n = normalize(w_nrm + vec3(nm.x, 0.0, -nm.y) * 0.7);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
