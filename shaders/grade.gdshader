// Финальная обработка кадра: сине-янтарная цветокоррекция, виньетка, плёночное зерно, затемнение.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float fade = 0.0;
uniform float dawn = 0.0; // 0 — ночь под Пеленой, 1 — ожившая область вокруг героя
uniform float frost = 0.0; // холод: иней ползёт с краёв экрана

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
	// иней: голубоватые кристаллы с краёв, чем холоднее — тем ближе к центру
	if (frost > 0.001) {
		// узор инея: «перистые» языки по краям (плавные синусы, без пиксельного шума)
		float edge = length(q * vec2(0.8, 1.0));
		float a = atan(q.y, q.x);
		float feather = 0.06 * sin(a * 9.0 + 1.3) + 0.04 * sin(a * 23.0 + 0.7) + 0.025 * sin(a * 47.0 + edge * 30.0);
		float f = smoothstep(0.78 - frost * 0.42, 0.98 - frost * 0.38, edge + feather);
		float sparkle = pow(max(0.0, sin(SCREEN_UV.x * 340.0 + SCREEN_UV.y * 190.0) * sin(SCREEN_UV.y * 410.0 - SCREEN_UV.x * 150.0)), 12.0);
		vec3 ice = vec3(0.78, 0.87, 0.97) * (0.55 + 0.45 * l) + sparkle * 0.25;
		c = mix(c, ice, f * frost * 0.8);
		c = mix(c, vec3(dot(c, vec3(0.33))) * vec3(0.88, 0.94, 1.05), frost * 0.2);
	}
	// зерно
	float g = hash(SCREEN_UV / SCREEN_PIXEL_SIZE + fract(TIME * 7.13) * 100.0) - 0.5;
	c += g * 0.035 * (1.0 - l * 0.6);
	COLOR = vec4(c * fade, 1.0);
}
