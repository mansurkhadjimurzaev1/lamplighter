// Ковёр: геометрический орнамент (кайма, ромбы-медальоны), тёплые красные, синие, охра.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/include_map.gdshaderinc"
#include "res://shaders/restore.gdshaderinc"

uniform vec3 base_col : source_color = vec3(0.55, 0.08, 0.06);
uniform vec3 accent : source_color = vec3(0.1, 0.15, 0.4);
uniform vec3 light_col : source_color = vec3(0.85, 0.65, 0.3);
uniform vec2 size = vec2(2.0, 1.4);

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (UV - 0.5) * size; // метры от центра
	vec2 a = abs(p);
	vec2 inner = size * 0.5 - 0.18;
	vec3 col = base_col;
	// кайма с зубчиками
	float border = step(inner.x, a.x) + step(inner.y, a.y);
	float teeth = step(0.5, fract((p.x + p.y) * 6.0));
	if (border > 0.0) col = mix(accent, light_col, teeth * step(a.x, size.x * 0.5 - 0.05) * step(a.y, size.y * 0.5 - 0.05) * 0.6);
	else {
		// ромбы-медальоны по центру
		vec2 q = p / vec2(inner.x * 0.55, inner.y * 0.9);
		float d = abs(q.x) + abs(q.y);
		col = mix(col, accent, step(d, 0.9) * step(0.7, d));
		col = mix(col, light_col, step(d, 0.55) * step(0.42, d));
		col = mix(col, accent, step(d, 0.22));
		// мелкий узор по полю
		vec2 g = fract(p * 3.0) - 0.5;
		col = mix(col, light_col * 0.9, step(abs(g.x) + abs(g.y), 0.12) * step(0.9, d));
	}
	col *= 0.85 + 0.15 * vnoise(p * 40.0); // ворс
	float rs = restore_at(w_pos);
	ALBEDO = mix(mix(vec3(dot(col, vec3(0.33))), col, 0.7), col * 1.1, rs);
	ROUGHNESS = 1.0;
}
