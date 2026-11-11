shader_type spatial;
// Стена интерьера: внизу каменный цоколь, выше — побелка с пятнами и копотью к потолку.

uniform vec4 plaster : source_color = vec4(0.6, 0.5, 0.4, 1.0);
uniform vec4 stone_tint : source_color = vec4(0.55, 0.5, 0.46, 1.0);
uniform sampler2D stone_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float base_y = 0.0; // уровень пола
uniform float plinth = 0.7; // высота цоколя
uniform float height = 2.8;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float h = wpos.y - base_y;
	vec2 uv = abs(wnorm.x) > 0.5 ? wpos.zy : wpos.xy;
	float n = noise(uv * 3.0) * 0.6 + noise(uv * 11.0) * 0.4;
	vec3 c = plaster.rgb * (0.88 + 0.16 * n);
	// пятна сырости и копоть под потолком
	c *= 1.0 - 0.18 * smoothstep(0.55, 0.85, noise(uv * 0.9 + 7.0));
	c *= 1.0 - 0.35 * smoothstep(height * 0.6, height, h);
	// каменный цоколь
	vec3 st = texture(stone_tex, uv * 0.6).rgb * stone_tint.rgb * 1.6;
	float edge = plinth + (noise(uv * 4.0) - 0.5) * 0.12;
	float m = 1.0 - smoothstep(edge - 0.03, edge + 0.03, h);
	c = mix(c, st, m);
	ALBEDO = c;
	ROUGHNESS = mix(0.92, 0.8, m);
	SPECULAR = 0.2;
}
