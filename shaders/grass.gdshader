// Трава: тысячи травинок. Высоту и «травянистость» каждая травинка берёт из карты острова
// прямо на видеокарте; ветер и расступание вокруг героя — тоже здесь.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

#include "res://shaders/include_map.gdshaderinc"

global uniform vec3 hero_pos;

varying float tip;
varying vec3 tint;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz; // основание травинки в мире
	vec2 uv = map_uv(root.xz);
	float h = texture(height_map, uv).r;
	float g = texture(weight_map, uv).r;
	float r = hash12(root.xz * 1.37);
	float keep = step(r, g * g * 1.1) * step(0.25, h); // трава только на «травяной» земле и выше воды

	vec3 local = (VERTEX - root) * keep * (0.65 + 0.6 * g);
	tip = UV.y;
	float k = tip * tip; // гнётся верхушка, корень на месте

	// ветер: медленные порывы + мелкая дрожь
	vec2 wp = root.xz;
	float gust = sin(TIME * 0.35 + wp.x * 0.05 + wp.y * 0.03) * 0.5 + 0.5;
	float wv = sin(TIME * 1.6 + wp.x * 0.45 + wp.y * 0.25) * 0.6 + sin(TIME * 2.7 + wp.x * 0.9 - wp.y * 0.7) * 0.25;
	vec2 wind_dir = normalize(vec2(1.0, 0.35));
	vec2 off = wind_dir * (wv * (0.06 + gust * 0.14) + gust * 0.12) * k;

	// расступается вокруг героя
	vec2 d = wp - hero_pos.xz;
	float dist = length(d);
	float push = (1.0 - smoothstep(0.15, 0.85, dist)) * k;
	off += (d / max(dist, 0.001)) * push * 0.35;

	VERTEX = vec3(root.x, h - 0.02, root.z) + local + vec3(off.x, -push * 0.25, off.y) * keep;
	NORMAL = vec3(0.0, 1.0, 0.0);

	// оттенки: от сухой оливковой до сочной зелени
	float hue = hash12(root.xz * 3.1);
	tint = mix(vec3(0.16, 0.2, 0.07), vec3(0.09, 0.2, 0.06), hue) * mix(0.8, 1.25, hash12(root.xz * 7.7));
}

void fragment() {
	ALBEDO = tint * mix(0.5, 1.0, tip);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	// обе стороны травинки освещаются одинаково, как «газон»
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
