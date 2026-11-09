// Земля: смешение текстур травы, земли и камня по весам (высота, наклон, шум).
shader_type spatial;
render_mode cull_back;

uniform sampler2D grass_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec3 w_weights;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	w_weights = COLOR.rgb;
}

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
	col *= mix(0.75, 1.15, texture(dirt_c, wp * 0.013).r); // крупные пятна
	ALBEDO = col;
	ROUGHNESS = 0.95 - gw.z * 0.25;

	// рельеф поверхности: нормали текстур смешиваются и «наклоняют» нормаль земли
	vec3 nm = vec3(0.0);
	float nw = 0.0;
	if (gw.x > 0.01) { nm += texture(grass_n, wp * 0.32).xyz * gw.x; nw += gw.x; }
	if (gw.y > 0.01) { nm += texture(dirt_n, wp * 0.28).xyz * gw.y; nw += gw.y; }
	if (gw.z > 0.01) { nm += texture(rock_n, wp * 0.2).xyz * gw.z; nw += gw.z; }
	nm = nm / max(nw, 1e-3) * 2.0 - 1.0;
	vec3 n = normalize(w_nrm + vec3(nm.x, 0.0, -nm.y) * 0.7);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
