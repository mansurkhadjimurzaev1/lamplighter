// Гобелен: выцветшая ткань, кайма, эмблема (маяк с лучами — герб королевства), рваный низ, колышется.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/include_map.gdshaderinc"
#include "res://shaders/restore.gdshaderinc"

uniform vec3 cloth : source_color = vec3(0.45, 0.08, 0.08);
uniform vec3 trim : source_color = vec3(0.75, 0.6, 0.3);
uniform float seed = 0.0;

void vertex() {
	float k = 1.0 - UV.y; // низ качается сильнее
	VERTEX.z += sin(TIME * 0.7 + seed + VERTEX.x * 2.0) * 0.04 * (1.0 - k);
}

float box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }

void fragment() {
	vec2 uv = UV;
	// рваный низ
	float tear = vnoise(vec2(uv.x * 18.0, seed)) * 0.08 + vnoise(vec2(uv.x * 50.0, seed + 3.0)) * 0.04;
	if (uv.y > 0.9 - tear) discard;
	vec3 col = cloth * (0.75 + 0.25 * vnoise(uv * vec2(80.0, 120.0))); // ткань
	// кайма
	float border = step(min(min(uv.x, 1.0 - uv.x), uv.y), 0.06);
	col = mix(col, trim, border * (0.6 + 0.4 * step(0.5, fract((uv.x + uv.y) * 20.0))));
	// эмблема: башня маяка с огнём и лучами
	vec2 p = (uv - vec2(0.5, 0.45)) * vec2(1.0, 1.4);
	float tower = step(box(p - vec2(0.0, 0.08), vec2(0.06, 0.14)), 0.0);
	float flame = step(length(p - vec2(0.0, -0.1)), 0.05);
	float a = atan(p.y + 0.1, p.x);
	float rays = step(0.85, abs(sin(a * 6.0))) * step(length(p - vec2(0.0, -0.1)), 0.22) * step(0.08, length(p - vec2(0.0, -0.1)));
	col = mix(col, trim, max(max(tower, flame), rays) * 0.85);
	// выцветание и пятна
	col *= 0.7 + 0.3 * vnoise(uv * 6.0 + seed);
	col = mix(col, vec3(dot(col, vec3(0.33))), 0.35);
	ALBEDO = col * 0.8;
	ROUGHNESS = 1.0;
}
