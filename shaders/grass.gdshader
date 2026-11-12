// Трава: тысячи травинок. Высоту и «травянистость» каждая травинка берёт из карты острова
// прямо на видеокарте; ветер и расступание вокруг героя — тоже здесь.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

#include "res://shaders/include_map.gdshaderinc"
#include "res://shaders/restore.gdshaderinc"

global uniform vec3 hero_pos;
global uniform float wind_strength; // 1 — обычно, в горах — ледяной ветер сильнее

varying float tip;
varying vec3 tint;
varying float rs;
varying float edge;
varying float side;
varying float dry;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz; // основание травинки в мире
	vec2 uv = map_uv(root.xz);
	float h = texture(height_map, uv).r;
	float g = texture(weight_map, uv).r;
	float r = hash12(root.xz * 1.37);
	float keep = step(r, g * g * 1.1) * step(0.25, h); // трава только на «травяной» земле и выше воды

	rs = restore_at(vec3(root.x, h, root.z));
	edge = wave_edge(vec3(root.x, h, root.z));
	vec3 local = (VERTEX - root) * keep * (0.65 + 0.6 * g) * (1.0 + rs * 0.2);
	tip = UV.y;
	float k = tip * tip; // гнётся верхушка, корень на месте

	// ветер: медленные порывы + мелкая дрожь
	vec2 wp = root.xz;
	float gust = sin(TIME * 0.35 + wp.x * 0.05 + wp.y * 0.03) * 0.5 + 0.5;
	float wv = sin(TIME * 1.6 + wp.x * 0.45 + wp.y * 0.25) * 0.6 + sin(TIME * 2.7 + wp.x * 0.9 - wp.y * 0.7) * 0.25;
	vec2 wind_dir = normalize(vec2(1.0, 0.35));
	vec2 off = wind_dir * (wv * (0.06 + gust * 0.14) + gust * 0.12) * k * wind_strength;

	// расступается вокруг героя
	vec2 d = wp - hero_pos.xz;
	float dist = length(d);
	float push = (1.0 - smoothstep(0.15, 0.85, dist)) * k;
	off += (d / max(dist, 0.001)) * push * 0.35;
	// фронт волны оживания проходит по траве, как тёплый порыв
	vec2 from_b = wp - beacon_wave.xz;
	off += normalize(from_b + 0.001) * edge * 0.35 * k;

	VERTEX = vec3(root.x, h - 0.02, root.z) + local + vec3(off.x, -push * 0.25, off.y) * keep;
	NORMAL = vec3(0.0, 1.0, 0.0);

	// оттенки: от сухой оливковой до сочной зелени
	float hue = hash12(root.xz * 3.1);
	vec3 night = mix(vec3(0.16, 0.2, 0.07), vec3(0.09, 0.2, 0.06), hue);
	night = mix(vec3(dot(night, vec3(0.33))), night, 0.7);
	vec3 alive = mix(vec3(0.16, 0.42, 0.06), vec3(0.08, 0.36, 0.08), hue);
	tint = mix(night, alive, rs) * mix(0.8, 1.25, hash12(root.xz * 7.7));
	// изредка — сухие соломенные травинки
	dry = step(0.9, hash12(root.xz * 5.3));
	side = UV.x;
}

void fragment() {
	vec3 straw = vec3(0.32, 0.27, 0.13) * (0.7 + 0.6 * rs);
	vec3 c = mix(tint, straw, dry * 0.8);
	// у корня темно, к кончику светлее и чуть желтее
	c *= mix(0.35, 1.0, smoothstep(0.0, 0.7, tip));
	c = mix(c, c * vec3(1.15, 1.12, 0.8), smoothstep(0.7, 1.0, tip) * 0.6);
	// середина травинки (жилка) чуть светлее краёв
	c *= 0.85 + 0.3 * (1.0 - abs(side - 0.5) * 2.0);
	ALBEDO = c;
	BACKLIGHT = c * 0.6;
	EMISSION = vec3(1.0, 0.7, 0.3) * edge * tip * 0.8;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	// обе стороны травинки освещаются одинаково, как «газон»
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
