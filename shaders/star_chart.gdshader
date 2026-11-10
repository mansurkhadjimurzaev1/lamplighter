// Звёздная карта на пергаменте: круг небесной сферы, сетка, звёзды, созвездия, подписи-штрихи.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/include_map.gdshaderinc"

uniform float seed = 1.0;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 uv = UV;
	vec3 paper = vec3(0.86, 0.78, 0.6) * (0.9 + 0.1 * vnoise(uv * 40.0 + seed));
	vec3 ink = vec3(0.22, 0.14, 0.08);
	vec3 col = paper;
	vec2 c = uv - 0.5;
	float r = length(c);
	// края пергамента темнее
	col *= mix(0.7, 1.0, smoothstep(0.0, 0.08, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y))));
	// круг сферы и сетка
	float ring = smoothstep(0.006, 0.0, abs(r - 0.42)) + smoothstep(0.004, 0.0, abs(r - 0.3)) * 0.6 + smoothstep(0.004, 0.0, abs(r - 0.15)) * 0.5;
	float ang = atan(c.y, c.x);
	float spokes = smoothstep(0.012, 0.0, abs(sin(ang * 6.0)) * r) * step(r, 0.42) * 0.5;
	col = mix(col, ink, clamp(ring + spokes, 0.0, 1.0) * 0.7);
	// звёзды
	vec2 g = floor(uv * 26.0);
	float h = hash12(g + seed * 7.0);
	vec2 sp = (g + vec2(hash12(g + 3.0 + seed), hash12(g + 9.0 + seed))) / 26.0;
	float star = smoothstep(0.006 + h * 0.004, 0.0, distance(uv, sp)) * step(0.62, h) * step(r, 0.42);
	col = mix(col, vec3(0.45, 0.2, 0.08), star);
	// созвездие — ломаная линия
	vec2 p0 = vec2(0.3, 0.35) + vec2(hash12(vec2(seed, 1.0)), hash12(vec2(seed, 2.0))) * 0.1;
	vec2 p1 = p0 + vec2(0.12, 0.08);
	vec2 p2 = p1 + vec2(0.1, -0.12);
	vec2 p3 = p2 + vec2(0.08, 0.15);
	float l = min(min(seg(uv, p0, p1), seg(uv, p1, p2)), seg(uv, p2, p3));
	col = mix(col, vec3(0.5, 0.14, 0.06), smoothstep(0.003, 0.0, l) * 0.8);
	// строки «подписей» внизу
	float lines = step(0.86, uv.y) * step(uv.y, 0.95) * step(0.5, fract(uv.y * 60.0)) * step(0.1, uv.x) * step(uv.x, 0.9) * step(0.3, vnoise(vec2(uv.x * 40.0, floor(uv.y * 60.0))));
	col = mix(col, ink, lines * 0.35);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
