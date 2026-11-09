// Тень: тёмный силуэт с размытыми, «дымными» краями. Края колышутся,
// при страхе фигура дрожит, при рассеивании — растворяется в дым.
shader_type spatial;
render_mode unshaded, cull_back, depth_prepass_alpha, shadows_disabled, blend_mix;

#include "res://shaders/include_map.gdshaderinc"

uniform float fade = 1.0; // 1 — видна, 0 — рассеялась
uniform float fear = 0.0; // 0..1 — дрожь от света
uniform float seed = 0.0;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = vnoise(wp.xz * 3.0 + wp.y * 2.0 + TIME * 1.3 + seed) - 0.5;
	VERTEX += NORMAL * (n * 0.08 + 0.03 + (1.0 - fade) * 0.15);
	float tr = sin(TIME * 43.0 + seed * 7.0) * cos(TIME * 37.0 + wp.y * 5.0);
	VERTEX += vec3(tr, 0.0, -tr) * fear * 0.03;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fres = 1.0 - abs(dot(NORMAL, VIEW));
	float n = vnoise(wp.xy * 4.0 + vec2(seed, -TIME * 0.8)) * 0.6 + vnoise(wp.zy * 9.0 + vec2(TIME * 0.4, -TIME * 1.3)) * 0.4;
	// края — «дым»
	float edge = smoothstep(0.3, 0.95, fres + (n - 0.5) * 0.6);
	// ноги растворяются в земле
	float feet = smoothstep(0.0, 0.5, wp.y - texture(height_map, map_uv(wp.xz)).r + (n - 0.5) * 0.3);
	float a = (1.0 - edge) * feet;
	// рассеивание: шумовое растворение
	a *= smoothstep(1.0 - fade, 1.0 - fade + 0.3, n);
	// внутри — глубокая тьма; на краях — холодная сизая дымка
	float rim = smoothstep(0.2, 0.75, fres) * (1.0 - edge);
	ALBEDO = mix(vec3(0.008, 0.007, 0.018), vec3(0.16, 0.17, 0.3), rim * (0.6 + 0.4 * n));
	ALPHA = clamp(a * 1.15, 0.0, 1.0) * fade;
}
