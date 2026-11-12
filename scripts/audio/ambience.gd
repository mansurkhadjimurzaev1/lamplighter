class_name Ambience
extends Node3D
## Звуки настроения (без музыки): редкие голоса ночи вокруг героя — сова, скрип стволов,
## хруст веток, пузыри болотного газа, треск льда, осыпь камней, шёпот Теней рядом —
## и тихие «постели» областей: сверчки на острове, шелест Шепчущего леса, плеск топи.
## Каждый звук звучит из точки в 8–25 м от героя (объёмно, с разных сторон).
## Скрип ручки фонаря — в такт шагам.

var _rng := RandomNumberGenerator.new()
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _snd := {}
var _next := 4.0
var _t := 0.0
var _beds := {} # имя → AudioStreamPlayer
var _squeak_at := 0.0
var _whisper_cd := 0.0

## Что вокруг (0..1), ставит main каждый кадр
var island := 1.0
var forest := 0.0
var swamp := 0.0
var mountains := 0.0
var castle := 0.0
var inside := 0.0
var alive := 0.0 # область ожила (маяк горит) — ночные звуки тише, живые громче
var shade_near := 99.0 # расстояние до ближайшей Тени


func build() -> void:
	name = "Ambience"
	_rng.randomize()
	_snd = {
		owl = Synth.cached("amb_owl", func(): return _norm(_owl()), false),
		owl2 = Synth.cached("amb_owl2", func(): return _norm(_owl(0.88, 3)), false),
		creak = Synth.cached("amb_creak", func(): return _norm(_creak(1.4, 31)), false),
		creak2 = Synth.cached("amb_creak2", func(): return _norm(_creak(0.9, 47)), false),
		twig = Synth.cached("amb_twig", func(): return _norm(_twig(5)), false),
		twig2 = Synth.cached("amb_twig2", func(): return _norm(_twig(9)), false),
		bubble = Synth.cached("amb_bubble", func(): return _norm(_bubble(1)), false),
		bubbles = Synth.cached("amb_bubbles", func(): return _norm(_bubble(3)), false),
		ice = Synth.cached("amb_ice", func(): return _norm(_ice()), false),
		pebbles = Synth.cached("amb_pebbles", func(): return _norm(_pebbles()), false),
		whisper = Synth.cached("amb_whisper", func(): return _norm(_whisper(7)), false),
		whisper2 = Synth.cached("amb_whisper2", func(): return _norm(_whisper(13)), false),
		stone = Synth.cached("amb_stone", func(): return _norm(_stone()), false),
		squeak = Synth.cached("amb_squeak", func(): return _norm(_squeak()), false),
	}
	for i in 5:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 9.0
		p.max_distance = 60.0
		p.attenuation_filter_cutoff_hz = 6000.0
		add_child(p)
		_pool.append(p)
	_bed("crickets", Synth.cached("amb_crickets", func(): return Synth.crickets(16.0, 5, 71), true))
	_bed("leaves", Synth.cached("amb_leaves", func(): return Synth.rustle(18.0, 83), true))
	_bed("lap", Synth.cached("amb_lap", func(): return _norm(_lapping(14.0)), true))


func _bed(id: String, stream: AudioStreamWAV) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -80.0
	add_child(p)
	_beds[id] = p


func _set_bed(id: String, vol: float) -> void:
	var p: AudioStreamPlayer = _beds[id]
	p.volume_db = linear_to_db(maxf(vol, 0.0001))
	if vol > 0.002 and not p.playing:
		p.play(_rng.randf() * p.stream.get_length())
	elif vol <= 0.002 and p.playing:
		p.stop()


func _play_at(id: String, hero: Vector3, vol: float, near := 8.0, far := 25.0, pitch := 1.0) -> void:
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(near, far)
	p.global_position = hero + Vector3(cos(a) * d, _rng.randf_range(0.5, 4.0), sin(a) * d)
	p.stream = _snd[id]
	p.volume_db = linear_to_db(maxf(vol, 0.0001))
	p.pitch_scale = pitch * _rng.randf_range(0.92, 1.08)
	p.play()


## walking — сколько герой прошёл (для скрипа фонаря), carrying — фонарь в руке
func update(dt: float, hero: Vector3, distance: float, carrying: bool, active: bool) -> void:
	_t += dt
	_whisper_cd -= dt
	var night := 1.0 - alive * 0.7
	var out := 1.0 - inside
	# постели областей
	_set_bed("crickets", 0.05 * island * (1.0 - forest) * (1.0 - mountains) * (1.0 - castle) * out * (0.6 + 0.4 * alive))
	_set_bed("leaves", 0.10 * forest * out)
	_set_bed("lap", 0.07 * swamp * out)
	if not active:
		return
	# скрип ручки фонаря на каждом втором шаге
	if carrying and distance >= _squeak_at:
		_squeak_at = distance + _rng.randf_range(1.2, 1.5)
		if _rng.randf() < 0.55:
			var p := _pool[_pool_i]
			_pool_i = (_pool_i + 1) % _pool.size()
			p.global_position = hero + Vector3(0.3, 0.9, 0)
			p.stream = _snd.squeak
			p.volume_db = linear_to_db(0.035)
			p.pitch_scale = _rng.randf_range(0.85, 1.15)
			p.play()
	# Тени рядом шепчут (без слов — дыхание, шорох «голоса»)
	if shade_near < 9.0 and _whisper_cd <= 0.0 and inside < 0.5:
		_whisper_cd = _rng.randf_range(5.0, 9.0)
		_play_at("whisper" if _rng.randf() < 0.5 else "whisper2", hero, 0.35 * (1.0 - shade_near / 9.0) + 0.08, 3.0, 7.0)
	if inside > 0.5:
		return
	if _t < _next:
		return
	_next = _t + _rng.randf_range(5.0, 13.0)
	# выбор звука по области
	var opts: Array = [] # [id, вес, громкость, ближе, дальше]
	opts.append(["owl", 1.2 * night * (island + forest * 1.5) * (1.0 - mountains) * (1.0 - castle), 0.22, 15.0, 30.0])
	opts.append(["owl2", 0.8 * night * forest, 0.18, 15.0, 30.0])
	opts.append(["creak", 1.0 * (forest + swamp * 0.8), 0.2, 6.0, 18.0])
	opts.append(["creak2", 0.6 * (forest + island * 0.3), 0.16, 6.0, 18.0])
	opts.append(["twig", 0.9 * (forest + island * 0.4) * night, 0.18, 5.0, 14.0])
	opts.append(["twig2", 0.6 * forest * night, 0.15, 5.0, 14.0])
	opts.append(["bubble", 1.6 * swamp, 0.2, 3.0, 12.0])
	opts.append(["bubbles", 1.0 * swamp, 0.18, 3.0, 12.0])
	opts.append(["ice", 1.2 * mountains, 0.16, 8.0, 22.0])
	opts.append(["pebbles", 0.9 * mountains, 0.2, 10.0, 25.0])
	opts.append(["stone", 1.4 * castle, 0.3, 6.0, 16.0])
	opts.append(["whisper", 0.5 * castle * night, 0.12, 8.0, 15.0])
	var total := 0.0
	for o in opts:
		total += maxf(0.0, o[1])
	if total < 0.05:
		return
	var r := _rng.randf() * total
	for o in opts:
		r -= maxf(0.0, o[1])
		if r <= 0.0:
			_play_at(o[0], hero, o[2], o[3], o[4])
			if o[0] == "bubble" or o[0] == "bubbles":
				_next = _t + _rng.randf_range(2.5, 7.0) # в топи пузыри чаще
			return


# ── синтез ───────────────────────────────────────────────────

## Выравниваем громкость: пик = 0.75
static func _norm(x: PackedFloat32Array, peak := 0.75) -> PackedFloat32Array:
	var pk := 0.0
	for v in x:
		pk = maxf(pk, absf(v))
	if pk < 0.0001:
		return x
	var k := peak / pk
	for i in x.size():
		x[i] *= k
	return x


const R := Synth.RATE


## Сова: «у-ху… у-ху-ху» — мягкий тон с придыханием, чуть вниз
func _owl(pitch := 1.0, seed_value := 1) -> PackedFloat32Array:
	Synth.rng.seed = seed_value
	var out := Synth.silence(2.6)
	var hoots := [[0.0, 0.42, 1.0], [0.75, 0.22, 0.85], [1.05, 0.5, 0.95]]
	for h in hoots:
		var at := int(h[0] * R)
		var n := int(h[1] * R)
		var ph := 0.0
		for i in n:
			var t := float(i) / n
			var f := (395.0 - 40.0 * t) * pitch * (1.0 + 0.012 * sin(t * 40.0))
			ph += TAU * f / R
			var env: float = sin(PI * pow(t, 0.6)) * h[2]
			var breath := (Synth.rng.randf() * 2.0 - 1.0) * 0.08
			if at + i < out.size():
				out[at + i] += (sin(ph) + 0.15 * sin(ph * 2.0) + breath) * env * 0.5
	return Synth.filter(out, "lp", 1400.0, 0.7)


## Скрип ствола: «трение» — частые щелчки с плавающей частотой через резонанс дерева
func _creak(dur: float, seed_value: int) -> PackedFloat32Array:
	Synth.rng.seed = seed_value
	var n := int(dur * R)
	var x := PackedFloat32Array()
	x.resize(n)
	var ph := 0.0
	var f0 := Synth.rng.randf_range(28.0, 45.0)
	for i in n:
		var t := float(i) / n
		var f := f0 * (1.0 + 0.5 * sin(t * PI * 1.3)) + Synth.rng.randf_range(-3.0, 3.0)
		ph += f / R
		if ph >= 1.0:
			ph -= 1.0
			x[i] = Synth.rng.randf_range(0.6, 1.0)
	var a := Synth.filter(x, "bp", 620.0, 6.0)
	var b := Synth.filter(x, "bp", 1350.0, 8.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / n
		out[i] = (a[i] * 1.6 + b[i] * 0.8) * sin(PI * t) * 2.2
	return out


## Хруст ветки: пара сухих щелчков
func _twig(seed_value: int) -> PackedFloat32Array:
	Synth.rng.seed = seed_value
	var out := Synth.silence(0.5)
	var k := 2 + Synth.rng.randi() % 3
	var at := 0
	for j in k:
		var c := Synth.burst(0.03 + Synth.rng.randf() * 0.03, "hp", 1800.0, 0.8, 1.1, 0.001)
		Synth.mix_into(out, c, at, 1.0 - j * 0.2)
		at += int(Synth.rng.randf_range(0.03, 0.12) * R)
	return Synth.filter(out, "lp", 6000.0, 0.7)


## Пузырь болотного газа: «блуп» с поднимающимся тоном
func _bubble(count: int) -> PackedFloat32Array:
	var out := Synth.silence(0.4 + count * 0.18)
	for j in count:
		var at := int((j * 0.17 + Synth.rng.randf() * 0.05) * R)
		var n := int(0.14 * R)
		var ph := 0.0
		var f0 := Synth.rng.randf_range(140.0, 220.0)
		for i in n:
			var t := float(i) / n
			ph += TAU * f0 * (1.0 + 1.6 * t * t) / R
			if at + i < out.size():
				out[at + i] += sin(ph) * exp(-t * 4.0) * (1.0 - exp(-t * 60.0)) * 0.7
	return Synth.filter(out, "lp", 900.0, 0.7)


## Треск льда: резкий щелчок и звенящий хвост
func _ice() -> PackedFloat32Array:
	var out := Synth.burst(0.08, "hp", 2500.0, 0.9, 1.0, 0.001)
	var tail := Synth.silence(1.2)
	for i in tail.size():
		var t := float(i) / R
		tail[i] = (sin(TAU * 1480.0 * t) * 0.5 + sin(TAU * 2210.0 * t) * 0.3 + sin(TAU * 3170.0 * t) * 0.2) * exp(-t * 5.0) * 0.25
	return Synth.mix(out, tail)


## Осыпь: несколько камешков катятся и стучат
func _pebbles() -> PackedFloat32Array:
	var out := Synth.silence(1.6)
	var t := 0.0
	var gap := 0.12
	while t < 1.4:
		var c := Synth.burst(0.02, "bp", Synth.rng.randf_range(1500.0, 3200.0), 2.0, 0.8 * (1.0 - t / 1.6), 0.001)
		Synth.mix_into(out, c, int(t * R))
		t += gap * Synth.rng.randf_range(0.4, 1.4)
		gap *= 0.93
	return out


## Шёпот Тени: дыхание через «гласные», слоги без слов
func _whisper(seed_value: int) -> PackedFloat32Array:
	Synth.rng.seed = seed_value
	var dur := 2.2
	var n := int(dur * R)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = Synth.rng.randf() * 2.0 - 1.0
	var f1 := Synth.filter(x, "bp", 900.0, 3.0)
	var f2 := Synth.filter(x, "bp", 2300.0, 4.0)
	var f3 := Synth.filter(x, "hp", 4000.0, 0.7) # «ш»
	var out := PackedFloat32Array()
	out.resize(n)
	var syl := []
	var t := 0.1
	while t < dur - 0.3:
		var l := Synth.rng.randf_range(0.12, 0.3)
		syl.append([t, l, Synth.rng.randf()])
		t += l + Synth.rng.randf_range(0.04, 0.2)
	for i in n:
		var tt := float(i) / R
		var e := 0.0
		var mixv := 0.5
		for s in syl:
			if tt >= s[0] and tt < s[0] + s[1]:
				e = sin(PI * (tt - s[0]) / s[1])
				mixv = s[2]
		out[i] = (f1[i] * mixv + f2[i] * (1.0 - mixv) * 0.7 + f3[i] * 0.25) * e * 1.2
	return Synth.filter(out, "lp", 5000.0, 0.7)


## Глухой стук осевшего камня в руинах + эхо
func _stone() -> PackedFloat32Array:
	var a := Synth.burst(0.25, "lp", 140.0, 0.9, 2.6, 0.003)
	var out := Synth.silence(1.6)
	Synth.mix_into(out, a, 0, 1.0)
	Synth.mix_into(out, a, int(0.31 * R), 0.35)
	Synth.mix_into(out, a, int(0.67 * R), 0.15)
	return out


## Скрип ручки фонаря: короткий металлический «уиик»
func _squeak() -> PackedFloat32Array:
	var n := int(0.16 * R)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		ph += TAU * (1700.0 + 500.0 * t) / R
		out[i] = (sin(ph) * 0.6 + sin(ph * 2.01) * 0.25 + sin(ph * 3.03) * 0.1) * sin(PI * t) * 0.5
	return out


## Тихий плеск воды о кочки и мостки
func _lapping(seconds: float) -> PackedFloat32Array:
	var out := Synth.silence(seconds)
	var t := 0.2
	while t < seconds - 0.6:
		var s := Synth.burst(Synth.rng.randf_range(0.15, 0.35), "bp", Synth.rng.randf_range(350.0, 700.0), 1.5, 0.6, 0.05, Synth.rng.randf_range(200.0, 400.0))
		Synth.mix_into(out, s, int(t * R), Synth.rng.randf_range(0.4, 1.0))
		t += Synth.rng.randf_range(0.4, 1.3)
	return out
