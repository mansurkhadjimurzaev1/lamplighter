// Каменная кладка маяка: настоящая текстура камня + швы между блоками + мох внизу.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/include_map.gdshaderinc"
#include "res://shaders/restore.gdshaderinc"

uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 center = vec3(0.0);
uniform float base_y = 0.0;
uniform float block_h = 0.38;
uniform float block_w = 0.62;
uniform float tint = 1.0;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 nn = normalize(w_nrm);
	vec3 bw = pow(abs(nn), vec3(4.0));
	bw /= bw.x + bw.y + bw.z;
	vec3 tc = texture(rock_tex, w_pos.zy * 0.5).rgb * bw.x + texture(rock_tex, w_pos.xz * 0.5).rgb * bw.y + texture(rock_tex, w_pos.xy * 0.5).rgb * bw.z;

	// блоки: ряды по высоте, в каждом ряду — по окружности, со сдвигом через ряд
	vec2 rel = w_pos.xz - center.xz;
	float r = length(rel);
	float row = floor((w_pos.y - base_y) / block_h);
	float u = atan(rel.y, rel.x) * r / block_w + mod(row, 2.0) * 0.5;
	vec2 cell = vec2(fract(u), fract((w_pos.y - base_y) / block_h));
	vec2 id = vec2(floor(u), row);
	float mortar = smoothstep(0.0, 0.05, cell.x) * smoothstep(1.0, 0.95, cell.x) * smoothstep(0.0, 0.07, cell.y) * smoothstep(1.0, 0.93, cell.y);
	if (abs(nn.y) > 0.7) mortar = 1.0; // верх/низ — без швов
	float block_var = mix(0.75, 1.15, hash12(id));
	vec3 col = tc * 0.85 * block_var * mix(0.35, 1.0, mortar) * tint;
	// мох у основания и в швах
	float moss = (1.0 - smoothstep(0.0, 1.4, w_pos.y - base_y)) * vnoise(w_pos.xz * 3.0 + w_pos.y);
	col = mix(col, vec3(0.05, 0.09, 0.03), clamp(moss * 1.2, 0.0, 0.8));

	float rs = restore_at(w_pos);
	vec3 night = mix(vec3(dot(col, vec3(0.33))), col, 0.7);
	ALBEDO = mix(night, col * vec3(1.12, 1.05, 0.95), rs);
	ROUGHNESS = mix(0.95, 0.75, mortar);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(nn * (mortar - 1.0) * 0.3, 0.0)).xyz);
}
