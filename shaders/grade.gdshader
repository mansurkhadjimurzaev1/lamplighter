// Финальная обработка кадра: сине-янтарная цветокоррекция, виньетка, плёночное зерно, затемнение.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float fade = 0.0;
uniform float dawn = 0.0; // 0 — ночь под Пеленой, 1 — ожившая область вокруг героя

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 c0 = c;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	// тени — в глубокий синий/фиолетовый, светлое — в тёплый янтарь
	vec3 shadow_tint = vec3(0.045, 0.05, 0.13);
	vec3 warm = c * vec3(1.08, 0.97, 0.82);
	c = mix(c + shadow_tint * (1.0 - smoothstep(0.0, 0.25, l)), warm, smoothstep(0.08, 0.6, l));
	c = mix(vec3(l), c, mix(0.75, 1.1, smoothstep(0.02, 0.4, l)));
	// рассвет: мягкие тёплые пастельные тона, тени светлеют
	vec3 d = pow(max(c0, 0.0), vec3(0.88)) * vec3(1.06, 1.0, 0.93) + vec3(0.025, 0.018, 0.028);
	c = mix(c, d, dawn);
	// виньетка (на рассвете мягче)
	vec2 q = SCREEN_UV - 0.5;
	q.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float vig = 1.0 - smoothstep(0.25, 1.05, length(q));
	c *= mix(mix(0.25, 0.6, dawn), 1.0, vig);
	// зерно
	float g = hash(SCREEN_UV / SCREEN_PIXEL_SIZE + fract(TIME * 7.13) * 100.0) - 0.5;
	c += g * 0.035 * (1.0 - l * 0.6);
	COLOR = vec4(c * fade, 1.0);
}
