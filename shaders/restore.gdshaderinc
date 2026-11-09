// «Оживание» мира вокруг зажжённых маяков.
// beacon_N: xyz — позиция маяка, w — текущий радиус ожившей области (0 — не зажжён).
// beacon_wave: xyz — маяк, чья волна сейчас расходится, w — радиус фронта (<0 — волны нет).
global uniform vec4 beacon_0;
global uniform vec4 beacon_1;
global uniform vec4 beacon_2;
global uniform vec4 beacon_3;
global uniform vec4 beacon_4;
global uniform vec4 beacon_wave;

float restore_one(vec4 b, vec3 p) {
	if (b.w <= 0.01) return 0.0;
	float d = distance(p.xz, b.xz);
	return 1.0 - smoothstep(b.w - 6.0, b.w, d);
}

// 0 — ночь под Пеленой, 1 — ожившая земля
float restore_at(vec3 p) {
	return max(max(max(restore_one(beacon_0, p), restore_one(beacon_1, p)), max(restore_one(beacon_2, p), restore_one(beacon_3, p))), restore_one(beacon_4, p));
}

// светящийся фронт волны (тонкое золотое кольцо)
float wave_edge(vec3 p) {
	if (beacon_wave.w < 0.0) return 0.0;
	float d = distance(p.xz, beacon_wave.xz);
	float x = (d - beacon_wave.w) / 1.4;
	return exp(-x * x) * (1.0 - smoothstep(22.0, 28.0, beacon_wave.w));
}
