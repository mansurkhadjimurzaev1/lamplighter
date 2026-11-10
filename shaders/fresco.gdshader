// Фреска на стене: выцветшая роспись, проступает из темноты в свете фонаря.
// picture: 0 — маяки и солнце, 1 — рудник и дым, 2 — король у пустого трона, 3 — погасшие маяки.
shader_type spatial;

#include "res://shaders/include_map.gdshaderinc"

global uniform vec3 lantern_pos;
uniform int picture = 0;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float circle(vec2 p, vec2 c, float r) { return step(length(p - c), r); }
float rect(vec2 p, vec2 c, vec2 h) { vec2 d = abs(p - c); return step(d.x, h.x) * step(d.y, h.y); }
float tri(vec2 p, vec2 base, float w, float h) { // треугольник-гора вершиной вверх
	float y = (base.y - p.y) / h;
	return step(0.0, y) * step(y, 1.0) * step(abs(p.x - base.x), w * (1.0 - y));
}

void fragment() {
	vec2 p = vec2(UV.x, UV.y); // y вниз
	vec3 plaster = vec3(0.72, 0.64, 0.5);
	vec3 col = plaster;
	vec3 ochre = vec3(0.78, 0.55, 0.22);
	vec3 red = vec3(0.6, 0.2, 0.12);
	vec3 blue = vec3(0.22, 0.32, 0.5);
	vec3 dark = vec3(0.15, 0.12, 0.12);
	vec3 green = vec3(0.3, 0.42, 0.25);
	// земля
	col = mix(col, green, step(0.78, p.y));
	if (picture == 0) {
		col = mix(col, vec3(0.55, 0.68, 0.85), step(p.y, 0.5) * 0.6); // светлое небо
		col = mix(col, ochre, circle(p, vec2(0.75, 0.18), 0.09)); // солнце
		for (int i = 0; i < 5; i++) {
			float x = 0.12 + float(i) * 0.19;
			col = mix(col, dark * 1.8, rect(p, vec2(x, 0.68), vec2(0.025, 0.1)));
			col = mix(col, red, circle(p, vec2(x, 0.55), 0.035));
		}
		col = mix(col, dark, step(abs(p.y - 0.82 - sin(p.x * 30.0) * 0.01), 0.008)); // люди-штрихи
	} else if (picture == 1) {
		col = mix(col, vec3(0.45, 0.42, 0.4), step(p.y, 0.6) * 0.5);
		col = mix(col, vec3(0.5, 0.48, 0.45), tri(p, vec2(0.45, 0.8), 0.35, 0.55)); // гора
		col = mix(col, dark, rect(p, vec2(0.45, 0.72), vec2(0.06, 0.06))); // вход в рудник
		col = mix(col, red, circle(p, vec2(0.45, 0.72), 0.03)); // огонь внутри
		for (int i = 0; i < 6; i++) { // клубы дыма
			col = mix(col, vec3(0.25, 0.24, 0.26), circle(p, vec2(0.4 + float(i) * 0.06, 0.4 - float(i) * 0.06), 0.06 + float(i) * 0.01) * 0.8);
		}
		col = mix(col, dark, rect(p, vec2(0.8, 0.68), vec2(0.035, 0.12))); // фигура в тёмном плаще
		col = mix(col, vec3(0.82, 0.82, 0.86), circle(p, vec2(0.86, 0.66), 0.025)); // серебро в руке
	} else if (picture == 2) {
		col = mix(col, blue * 1.4, step(p.y, 0.78) * 0.4); // зал
		col = mix(col, ochre, rect(p, vec2(0.35, 0.62), vec2(0.07, 0.16))); // трон короля
		col = mix(col, ochre * 0.7, rect(p, vec2(0.62, 0.62), vec2(0.07, 0.16))); // пустой трон
		col = mix(col, red, rect(p, vec2(0.35, 0.62), vec2(0.04, 0.09))); // король
		col = mix(col, ochre, circle(p, vec2(0.35, 0.5), 0.03)); // корона
		col = mix(col, dark, rect(p, vec2(0.2, 0.6), vec2(0.03, 0.15))); // советник за спиной
		col = mix(col, vec3(0.9, 0.88, 0.8), circle(p, vec2(0.62, 0.48), 0.015)); // свеча у пустого трона
	} else {
		col = mix(col, vec3(0.1, 0.1, 0.14), step(p.y, 0.78) * 0.75); // тьма
		for (int i = 0; i < 5; i++) {
			float x = 0.12 + float(i) * 0.19;
			col = mix(col, dark, rect(p, vec2(x, 0.68), vec2(0.025, 0.1)));
		}
		for (int i = 0; i < 3; i++) { // дома с закрытыми ставнями
			float x = 0.25 + float(i) * 0.25;
			col = mix(col, ochre * 0.6, rect(p, vec2(x, 0.85), vec2(0.07, 0.05)));
			col = mix(col, dark, rect(p, vec2(x, 0.85), vec2(0.02, 0.03)));
		}
		col = mix(col, vec3(0.05), rect(p, vec2(0.85, 0.7), vec2(0.03, 0.11)) * 0.9); // тень
	}
	// выцветшая штукатурка, трещины, осыпь
	col = mix(col, plaster, 0.25 + 0.25 * vnoise(p * 9.0));
	float crack = smoothstep(0.03, 0.0, abs(vnoise(p * vec2(6.0, 14.0)) - 0.5));
	col *= 1.0 - crack * 0.35;
	float chip = step(0.82, vnoise(p * 22.0));
	col = mix(col, vec3(0.42, 0.38, 0.34), chip);
	// края рамки
	vec2 e = min(p, 1.0 - p);
	col *= mix(0.55, 1.0, smoothstep(0.0, 0.04, min(e.x, e.y)));
	// в свете фонаря роспись проступает ярче
	float near = 1.0 - smoothstep(1.5, 5.5, distance(w_pos, lantern_pos));
	ALBEDO = col * mix(0.35, 1.0, near);
	EMISSION = col * near * 0.08;
	ROUGHNESS = 0.95;
}
