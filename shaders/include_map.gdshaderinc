// Общий код: чтение карты высот/весов острова по мировым координатам.
uniform sampler2D height_map : filter_linear, repeat_disable;
uniform sampler2D weight_map : filter_linear, repeat_disable;
uniform float map_size = 140.0; // метров
uniform float map_res = 257.0; // пикселей

vec2 map_uv(vec2 xz) {
	float stp = map_size / (map_res - 1.0);
	return ((xz + map_size * 0.5) / stp + 0.5) / map_res;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}
