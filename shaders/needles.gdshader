// Хвоя ели: ветка-«карточка» с веточкой посередине и иголками в стороны (рисуются прямо в шейдере).
// UV.x — от ствола к кончику ветки, UV.y — поперёк. Альфа-срез, двусторонняя.
// Как и foliage: качается на ветру, растворяется перед героем, оживает в свете маяка.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/include_map.gdshaderinc"
#include "res://shaders/restore.gdshaderinc"

global uniform vec3 hero_pos;
global uniform float wind_strength;

uniform vec3 albedo : source_color = vec3(0.1, 0.2, 0.1);
uniform float snow = 0.0; // 0..1 — снег на ветках (горы)

varying vec3 w_pos;
varying float ly;
varying float tint;
varying vec3 w_up;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 bh = INSTANCE_CUSTOM.xy;
	ly = clamp((wp.y - bh.x) / max(bh.y, 0.01), 0.0, 1.0);
	tint = INSTANCE_CUSTOM.z;
	// дерево качается целиком (сильнее к верхушке) + кончики веток дрожат
	float sway = sin(TIME * 0.9 + wp.x * 0.3 + wp.z * 0.2) * 0.5 + sin(TIME * 1.7 + wp.x * 0.7) * 0.2;
	vec3 off = vec3(sway, 0.0, sway * 0.4) * ly * ly * 0.08 * bh.y * 0.25 * wind_strength;
	float flutter = sin(TIME * 3.1 + wp.x * 2.3 + wp.z * 1.9 + wp.y * 3.0) * 0.035 * UV.x * UV.x * wind_strength;
	off += vec3(flutter * 0.5, flutter, flutter * 0.3);
	// ветки отгибаются от проходящего героя (гибкие концы сильнее)
	vec2 dh = wp.xz - hero_pos.xz;
	float dist = length(dh);
	float bend = (1.0 - smoothstep(0.5, 2.0, dist)) * (1.0 - smoothstep(hero_pos.y + 1.6, hero_pos.y + 2.8, wp.y)) * (0.35 + 0.65 * UV.x);
	off.xz += dh / max(dist, 0.001) * bend * 1.1;
	off.y += bend * 0.35;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
	wp += off;
	w_pos = wp;
	w_up = normalize((MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void fragment() {
	// растворение загораживающих героя веток и всего, что вплотную к камере сверху
	vec3 hv = (VIEW_MATRIX * vec4(hero_pos + vec3(0.0, 0.8, 0.0), 1.0)).xyz;
	float hide = 0.0;
	if (VERTEX.z > hv.z + 0.6) {
		vec2 a = VERTEX.xy / -VERTEX.z;
		vec2 b = hv.xy / -hv.z;
		hide = 1.0 - smoothstep(0.16, 0.34, length(a - b));
		hide = max(hide, 1.0 - smoothstep(-hv.z * 0.45, -hv.z * 0.8, -VERTEX.z));
	}

	vec2 uv = UV;
	float across = abs(uv.y - 0.5) * 2.0; // 0 — веточка, 1 — край
	// контур ветки: широкая у основания, острый кончик, рваный край
	float reach = (1.0 - pow(uv.x, 3.0)) * (0.8 + 0.2 * smoothstep(0.0, 0.2, uv.x));
	float ragged = vnoise(vec2(uv.x * 22.0, floor(uv.y * 2.0) * 7.0)) * 0.35;
	// мягкий пушистый силуэт ветки: волнистые лопасти + мелкие зубчики-иголки по краю
	float lobes = vnoise(vec2(uv.x * 9.0, floor(uv.y * 2.0) * 13.0));
	float teeth = vnoise(vec2(uv.x * 140.0, uv.y * 25.0));
	float edge = reach * (0.78 + 0.32 * lobes) - teeth * 0.14;
	float a = step(across, edge);
	// просветы между пучками
	float holes = vnoise(vec2(uv.x * 26.0, uv.y * 7.0 + 3.0));
	a *= step(0.22, holes + (1.0 - across) * 0.55);
	float twig = 1.0 - smoothstep(0.02, 0.045, across);
	// иголки — штрихами оттенка, не дырками
	float fine = fract(uv.x * 120.0 - across * 3.0 + teeth * 0.6);
	fine = smoothstep(0.0, 0.5, fine) * smoothstep(1.0, 0.5, fine);
	if (a < 0.5) discard;
	// вид от первого лица: ветки вплотную к глазам растворяются, а не закрывают весь экран
	hide = max(hide, 1.0 - smoothstep(0.35, 0.8, -VERTEX.z));
	if (hide > 0.0 && hash12(floor(FRAGCOORD.xy)) < hide * 0.9) discard;

	// цвет: тёмная середина, светлые молодые кончики, пятна оттенка по деревьям
	float n = vnoise(w_pos.xz * 2.1 + w_pos.y * 1.3);
	vec3 col = albedo * mix(0.75, 1.2, tint) * mix(0.8, 1.15, n) * mix(0.9, 1.06, fine);
	col *= mix(0.45, 1.0, uv.x); // у ствола тень
	col = mix(col, col * vec3(1.25, 1.45, 0.9), smoothstep(0.75, 1.0, uv.x) * 0.6); // свежие кончики
	col *= mix(0.55, 1.0, smoothstep(0.0, 0.45, ly)); // внизу темнее
	col = mix(col * vec3(0.55, 0.38, 0.25), col, 1.0 - twig); // веточка — коричневая
	// снег лежит на верхней стороне веток
	float up_side = FRONT_FACING ? 1.0 : 0.0;
	col = mix(col, vec3(0.85, 0.9, 1.0), snow * up_side * smoothstep(0.3, 0.7, n + uv.x * 0.3));

	float rs = restore_at(w_pos);
	vec3 night = mix(vec3(dot(col, vec3(0.33))), col, 0.75);
	vec3 alive = col * vec3(1.05, 1.35, 0.9) * 1.25;
	ALBEDO = mix(night, alive, rs);
	EMISSION = vec3(1.0, 0.68, 0.32) * wave_edge(w_pos) * 0.5;
	// мягкое освещение: нормаль ближе к «вверх», чтобы крона светилась объёмом, а не плоскостями
	vec3 nv = (VIEW_MATRIX * vec4(w_up, 0.0)).xyz;
	NORMAL = normalize(mix(FRONT_FACING ? NORMAL : -NORMAL, nv, 0.55));
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.25, 0.35, 0.15);
}
