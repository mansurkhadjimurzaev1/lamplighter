// Жители: исходная текстура KayKit + замена цветов одежды (до трёх оттенков).
shader_type spatial;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 swap0_src = vec4(0.0, 0.0, 0.0, -1.0); // xyz — исходный цвет, w — допуск (<0 — выкл)
uniform vec3 swap0_dst : source_color = vec3(1.0);
uniform vec4 swap1_src = vec4(0.0, 0.0, 0.0, -1.0);
uniform vec3 swap1_dst : source_color = vec3(1.0);
uniform vec4 swap2_src = vec4(0.0, 0.0, 0.0, -1.0);
uniform vec3 swap2_dst : source_color = vec3(1.0);
uniform float dim = 1.0;

vec3 swap(vec3 c, vec4 src, vec3 dst) {
	if (src.w < 0.0) return c;
	float d = distance(pow(c, vec3(1.0 / 2.2)), src.rgb); // сравниваем в гамме текстуры (sRGB)
	float k = 1.0 - smoothstep(src.w * 0.6, src.w, d);
	// сохраняем светотень исходного цвета
	float l = dot(pow(c, vec3(1.0 / 2.2)), vec3(0.333)) / max(dot(src.rgb, vec3(0.333)), 0.01);
	return mix(c, dst * l, k);
}

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	c = swap(c, swap0_src, swap0_dst);
	c = swap(c, swap1_src, swap1_dst);
	c = swap(c, swap2_src, swap2_dst);
	ALBEDO = c * dim;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
