class_name Synth
extends RefCounted
## Синтез звуков кодом (без записей и без музыки): шум, фильтры, всплески,
## птицы, кузнечики. Всё готовится один раз при запуске.

const RATE := 22050

static var rng := RandomNumberGenerator.new()


static func wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func silence(seconds: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(RATE * seconds))
	return s


## Белый или «коричневый» шум; конец плавно сведён с началом (для петли)
static func noise(seconds: float, brown: bool) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var s := PackedFloat32Array()
	s.resize(n)
	var last := 0.0
	for i in n:
		var w := rng.randf() * 2.0 - 1.0
		if brown:
			last = (last + 0.02 * w) / 1.02
			s[i] = last * 3.5
		else:
			s[i] = w * 0.5
	var fade := int(RATE * 0.08)
	for i in fade:
		var k := float(i) / fade
		s[n - fade + i] = s[n - fade + i] * (1.0 - k) + s[i] * k
	return s


## Фильтр biquad: "lp" | "hp" | "bp"
static func filter(x: PackedFloat32Array, type: String, hz: float, q: float) -> PackedFloat32Array:
	var w0 := TAU * hz / RATE
	var al := sin(w0) / (2.0 * q)
	var cw := cos(w0)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	match type:
		"lp":
			b0 = (1.0 - cw) / 2.0; b1 = 1.0 - cw; b2 = b0
		"hp":
			b0 = (1.0 + cw) / 2.0; b1 = -(1.0 + cw); b2 = b0
		_:
			b0 = al; b1 = 0.0; b2 = -al
	var a0 := 1.0 + al
	var a1 := -2.0 * cw
	var a2 := 1.0 - al
	var y := PackedFloat32Array()
	y.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var v := (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1; x1 = x[i]; y2 = y1; y1 = v
		y[i] = v
	return y


## Всплеск шума с фильтром и затуханием. sweep_to — плавный переход к другой частоте.
static func burst(dur: float, type: String, hz: float, q: float, gain: float, attack: float, sweep_to := 0.0) -> PackedFloat32Array:
	var n := int(RATE * (dur + attack + 0.02))
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = rng.randf() * 2.0 - 1.0
	var y: PackedFloat32Array
	if sweep_to > 0.0:
		var a := filter(x, type, hz, q)
		var b := filter(x, type, sweep_to, q)
		y = PackedFloat32Array()
		y.resize(n)
		for i in n:
			var k := float(i) / n
			y[i] = a[i] * (1.0 - k) + b[i] * k
	else:
		y = filter(x, type, hz, q)
	for i in n:
		var t := float(i) / RATE
		var env := t / attack if t < attack else exp(-(t - attack) / (dur * 0.3))
		y[i] *= env * gain
	return y


static func mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, at := 0, gain := 1.0) -> void:
	for i in src.size():
		var j := (at + i) % dst.size()
		dst[j] += src[i] * gain


static func mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out


## Тихий вздох: дыхание через «гласную» (две полосы шума), вдох и долгий выдох
static func sigh() -> PackedFloat32Array:
	var n := int(RATE * 2.2)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = rng.randf() * 2.0 - 1.0
	var f1 := filter(x, "bp", 700.0, 2.5)
	var f2 := filter(x, "bp", 1250.0, 3.0)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		var t := float(i) / RATE
		var inhale := sstep(0.0, 0.35, t) * (1.0 - sstep(0.35, 0.55, t)) * 0.35
		var exhale := sstep(0.6, 0.8, t) * exp(-(t - 0.8) * 1.6) if t > 0.6 else 0.0
		y[i] = (f1[i] * 0.8 + f2[i] * 0.5) * (inhale + exhale) * 1.4
	return filter(y, "lp", 2200.0, 0.7)


## Звон стеклянного флакона: несколько негармоничных затухающих тонов
static func clink() -> PackedFloat32Array:
	var s := silence(0.6)
	var freqs := [2350.0, 3720.0, 5150.0]
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * freqs[k] * t) * exp(-t * (7.0 + k * 3.0)) / (k + 1.0)
		s[i] = v * 0.35 * minf(1.0, t * 800.0)
	return s


## Вспыхивание огня: нарастающий шорох + низкий «вдох» пламени
static func ignite() -> PackedFloat32Array:
	var a := burst(1.4, "bp", 300.0, 0.8, 1.2, 0.35, 2600.0)
	var b := burst(1.8, "lp", 160.0, 0.7, 2.2, 0.5)
	return mix(a, b)


## Тень рассеивается: мягкое «фффф» вниз по частоте
static func disperse() -> PackedFloat32Array:
	return burst(0.9, "bp", 1800.0, 1.2, 0.9, 0.08, 400.0)


## Петля птичьего пения: разные «виды» — трели, свисты, переливы
static func birds(seconds: float, density: float, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var s := silence(seconds)
	var t := rng.randf() * 0.5
	while t < seconds - 0.1:
		var species := rng.randi() % 4
		var base := rng.randf_range(2200.0, 4200.0)
		var notes := rng.randi_range(2, 7)
		var at := int(t * RATE)
		var gain := rng.randf_range(0.10, 0.22)
		for k in notes:
			var dur := 0.0
			var f0 := base
			var f1 := base
			match species:
				0: # быстрая трель
					dur = 0.045; f0 = base * 1.1; f1 = base * 0.9
				1: # свист с подъёмом
					dur = 0.18; f0 = base * 0.8; f1 = base * 1.25
				2: # перелив вниз
					dur = 0.09; f0 = base * (1.3 - k * 0.06); f1 = f0 * 0.8
				_: # короткое «цвик»
					dur = 0.035; f0 = base * 1.5; f1 = base * 0.7
			var n := int(dur * RATE)
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				var f := lerpf(f0, f1, u) * (1.0 + 0.02 * sin(u * 40.0))
				ph += TAU * f / RATE
				var env := sin(PI * u)
				var v := (sin(ph) + 0.25 * sin(ph * 2.0)) * env * env * gain
				var j := (at + i) % s.size()
				s[j] += v
			at += n + int(RATE * (0.015 if species == 0 else rng.randf_range(0.04, 0.12)))
		t += rng.randf_range(0.6, 2.8) / density
	return s


## Петля кузнечиков: высокий тон, пульсирующий короткими сериями
static func crickets(seconds: float, count: int, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var s := silence(seconds)
	for c in count:
		var freq := rng.randf_range(4200.0, 5600.0)
		var pulse_rate := rng.randf_range(28.0, 40.0) # щелчков в секунду внутри серии
		var series := rng.randi_range(5, 12) # серий за петлю (период кратен длине — петля бесшовная)
		var period := seconds / float(series)
		var chirp_len := rng.randf_range(0.18, 0.35)
		var offset := rng.randf() * period
		var gain := rng.randf_range(0.03, 0.06)
		var n := int(chirp_len * RATE)
		for k in series:
			var start := int((offset + k * period) * RATE)
			for i in n:
				var tp := float(i) / RATE
				var pulse := maxf(0.0, sin(PI * fmod(tp * pulse_rate, 1.0)))
				var env := sin(PI * tp / chirp_len)
				var j := (start + i) % s.size()
				s[j] += sin(TAU * freq * float(start + i) / RATE) * pulse * pulse * env * gain
	return s


static func sstep(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# ── кэш: долгие звуки считаем один раз и храним в user://cache ──

const CACHE_VERSION := 1

static func cached(key: String, fn: Callable, loop: bool) -> AudioStreamWAV:
	var path := "user://cache/%s_v%d.pcm" % [key, CACHE_VERSION]
	var samples: PackedFloat32Array
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		samples = f.get_buffer(f.get_length()).to_float32_array()
	else:
		samples = fn.call()
		DirAccess.make_dir_recursive_absolute("user://cache")
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(samples.to_byte_array())
	return wav(samples, loop)


## Тон с гармониками и «формантами» (окраской голоса)
static func _voiced(n: int, f0: Callable, amp: Callable, formants: Array, brightness := 1.0) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var u := float(i) / n
		var f: float = f0.call(u)
		ph += TAU * f / RATE
		var v := 0.0
		for h in range(1, 10):
			var fh := f * h
			if fh > RATE * 0.45:
				break
			var g := 0.0
			for fm in formants:
				var d: float = (fh - fm[0]) / fm[1]
				g += exp(-d * d) * fm[2]
			v += sin(ph * h) * (g + 0.08 * brightness / h)
		s[i] = v * float(amp.call(u))
	return s


## Петух: «ку-ка-ре-ку» — три коротких слога и долгий последний
static func rooster(seconds: float, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var out := silence(seconds)
	var crows := rng.randi_range(1, 2)
	for c in crows:
		var at := int(rng.randf_range(0.5, seconds - 3.0) * RATE)
		var base := rng.randf_range(520.0, 640.0)
		var sylls := [[0.11, 1.0, 1.08], [0.09, 1.08, 1.15], [0.12, 1.15, 1.25], [0.6, 1.25, 0.82]]
		for sy in sylls:
			var n := int(sy[0] * RATE)
			var a0: float = sy[1]
			var a1: float = sy[2]
			var seg := _voiced(n, func(u): return base * lerpf(a0, a1, u) * (1.0 + 0.012 * sin(u * 90.0)),
				func(u): return sin(PI * minf(1.0, u * 1.3)) * (0.75 if sy[0] > 0.3 else 1.0),
				[[1300.0, 380.0, 1.0], [2500.0, 500.0, 0.7]], 1.5)
			mix_into(out, seg, at, 0.16)
			at += n + int(0.025 * RATE)
	return filter(out, "lp", 4200.0, 0.7)


## Овца: «бе-е-е» с дрожащим голосом
static func sheep(seconds: float, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var out := silence(seconds)
	var count := rng.randi_range(2, 4)
	for c in count:
		var at := int(rng.randf_range(0.2, seconds - 1.5) * RATE)
		var dur := rng.randf_range(0.6, 1.0)
		var f := rng.randf_range(260.0, 380.0)
		var trem := rng.randf_range(6.5, 8.5)
		var seg := _voiced(int(dur * RATE), func(u): return f * (1.0 - 0.08 * u) * (1.0 + 0.03 * sin(u * dur * TAU * trem)),
			func(u): return minf(1.0, u * 12.0) * (1.0 - u) * (0.55 + 0.45 * sin(u * dur * TAU * trem)),
			[[750.0, 250.0, 1.0], [1900.0, 400.0, 0.6], [2900.0, 500.0, 0.3]])
		mix_into(out, seg, at, 0.2)
	return out


## Скрип колодезного ворота и плеск ведра
static func well(seconds: float) -> PackedFloat32Array:
	rng.seed = 91
	var out := silence(seconds)
	var at := int(1.0 * RATE)
	for k in 6:
		var dur := rng.randf_range(0.35, 0.55)
		var n := int(dur * RATE)
		var f0 := rng.randf_range(900.0, 1300.0)
		var ph := 0.0
		var seg := PackedFloat32Array()
		seg.resize(n)
		for i in n:
			var u := float(i) / n
			var f := f0 * (1.0 + 0.25 * sin(u * PI)) + rng.randf_range(-40.0, 40.0)
			ph += TAU * f / RATE
			var grain := maxf(0.0, sin(u * dur * TAU * 22.0)) # «зацепы» трения
			seg[i] = (fmod(ph / TAU, 1.0) * 2.0 - 1.0) * grain * sin(PI * u) * 0.5
		mix_into(out, filter(seg, "bp", f0 * 1.4, 2.0), at, 0.25)
		at += n + int(rng.randf_range(0.25, 0.45) * RATE)
	mix_into(out, burst(0.4, "lp", 500.0, 0.8, 1.6, 0.02, 0.0), at + int(0.6 * RATE), 0.5)
	return out


## Приглушённые голоса соседей (слов не разобрать)
static func voices(seconds: float, speakers: int, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var n := int(seconds * RATE)
	var out := silence(seconds)
	var vowels := [[700.0, 1200.0], [500.0, 900.0], [400.0, 2000.0], [300.0, 2300.0], [350.0, 800.0]]
	for sp in speakers:
		var base := rng.randf_range(105.0, 230.0)
		var t := rng.randf_range(0.0, 1.5)
		while t < seconds - 0.5:
			var phrase := rng.randf_range(1.0, 2.6)
			var end := minf(seconds - 0.2, t + phrase)
			var ph := 0.0
			var y1 := 0.0
			var y2 := 0.0
			var z1 := 0.0
			var z2 := 0.0
			while t < end:
				var syl := rng.randf_range(0.12, 0.24)
				var v: Array = vowels[rng.randi() % vowels.size()]
				var c1 := _reso(v[0], 80.0)
				var c2 := _reso(v[1], 120.0)
				var i0 := int(t * RATE)
				var cnt := int(syl * RATE)
				var pitch := base * rng.randf_range(0.92, 1.12)
				for i in cnt:
					var u := float(i) / cnt
					ph += TAU * pitch * (1.0 - 0.05 * u) / RATE
					var e := (1.0 if fmod(ph, TAU) < 0.6 else 0.0) + (rng.randf() - 0.5) * 0.3
					var a: float = e - c1[1] * y1 - c1[2] * y2
					y2 = y1; y1 = a
					var b: float = e - c2[1] * z1 - c2[2] * z2
					z2 = z1; z1 = b
					var env := sin(PI * u)
					var j := (i0 + i) % n
					out[j] += (a * c1[0] + b * c2[0] * 0.6) * env * 0.05
				t += syl + rng.randf_range(0.0, 0.05)
			t += rng.randf_range(0.6, 2.2)
	return filter(out, "lp", 1600.0, 0.7)


## Резонатор: [усиление, a1, a2]
static func _reso(f: float, bw: float) -> Array:
	var r := exp(-PI * bw / RATE)
	var a1 := -2.0 * r * cos(TAU * f / RATE)
	var a2 := r * r
	return [(1.0 - r) * 0.5, a1, a2]


## Тихий звук пера для побуквенного текста
static func quill() -> PackedFloat32Array:
	return burst(0.025, "bp", 3800.0, 1.5, 0.35, 0.002)



## Шелест листвы: шум в высоких частотах, накатывающий волнами
static func rustle(seconds: float, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var n := int(seconds * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = rng.randf() * 2.0 - 1.0
	var a := filter(x, "bp", 3200.0, 0.6)
	var b := filter(x, "bp", 6500.0, 0.8)
	var out := PackedFloat32Array()
	out.resize(n)
	var k1 := float(rng.randi_range(2, 4))
	var k2 := float(rng.randi_range(3, 6))
	for i in n:
		var u := float(i) / n
		# волны ветра в кронах (периоды кратны длине петли)
		var g := 0.5 + 0.5 * sin(u * TAU * k1) * sin(u * TAU * k2 + 1.3)
		g = g * g
		out[i] = (a[i] * 0.7 + b[i] * 0.3) * (0.15 + 0.85 * g) * 0.25
	var fade := int(RATE * 0.1)
	for i in fade:
		var k := float(i) / fade
		out[n - fade + i] = out[n - fade + i] * (1.0 - k) + out[i] * k
	return out


## Дятел: короткие серии быстрых стуков по дереву
static func woodpecker(seconds: float, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var out := silence(seconds)
	var t := rng.randf_range(1.0, 3.0)
	while t < seconds - 2.0:
		var knocks := rng.randi_range(10, 18)
		var rate := rng.randf_range(14.0, 19.0)
		var pitch := rng.randf_range(1100.0, 1700.0)
		for k in knocks:
			var at := int((t + k / rate) * RATE)
			var g := 0.5 + 0.5 * (1.0 - float(k) / knocks)
			mix_into(out, burst(0.012, "bp", pitch, 6.0, 1.4, 0.0008), at, g * 0.5)
			mix_into(out, burst(0.02, "lp", 380.0, 0.8, 1.2, 0.001), at, g * 0.35)
		t += knocks / rate + rng.randf_range(3.0, 7.0)
	return out


## Лягушки: хор «ква-а» — каждый крик из быстрых импульсов голосовой щели через резонатор
static func frogs(seconds: float, count: int, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var out := silence(seconds)
	for c in count:
		var f0 := rng.randf_range(140.0, 320.0) # частота импульсов
		var form := rng.randf_range(500.0, 1100.0) # «окраска» голоса
		var t := rng.randf_range(0.0, 2.0)
		var gap := rng.randf_range(0.9, 2.6)
		var gain := rng.randf_range(0.18, 0.32)
		var res := _reso(form, 160.0)
		while t < seconds - 0.6:
			var calls := rng.randi_range(1, 3)
			for k in calls:
				var dur := rng.randf_range(0.12, 0.22)
				var n := int(dur * RATE)
				var at := int(t * RATE)
				var y1 := 0.0
				var y2 := 0.0
				var ph := 0.0
				for i in n:
					var u := float(i) / n
					ph += f0 * (1.0 + 0.15 * (1.0 - u)) / RATE
					var e := 1.0 if fmod(ph, 1.0) < 0.12 else 0.0
					var v: float = e - res[1] * y1 - res[2] * y2
					y2 = y1
					y1 = v
					var env := sin(PI * u) * (0.7 + 0.3 * sin(u * 40.0))
					out[(at + i) % out.size()] += v * res[0] * env * gain * 3.0
				t += dur + rng.randf_range(0.06, 0.12)
			t += gap * rng.randf_range(0.7, 1.4)
	return out


## Журчание воды: множество коротких «бульков» поверх тихого шума
static func babble(seconds: float, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var n := int(seconds * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = rng.randf() * 2.0 - 1.0
	var out := filter(x, "bp", 900.0, 0.5)
	for i in n:
		out[i] *= 0.05
	var t := 0.0
	while t < seconds - 0.1:
		var dur := rng.randf_range(0.02, 0.07)
		var f0 := rng.randf_range(450.0, 1300.0)
		var cnt := int(dur * RATE)
		var at := int(t * RATE)
		var ph := 0.0
		for i in cnt:
			var u := float(i) / cnt
			ph += TAU * f0 * (1.0 + u * 0.8) / RATE # пузырёк: тон чуть поднимается
			out[(at + i) % n] += sin(ph) * sin(PI * u) * 0.09
		t += rng.randf_range(0.02, 0.18)
	return out


## Стрекозы: шуршащий гул крыльев, пролетающий мимо
static func dragonflies(seconds: float, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var out := silence(seconds)
	var t := rng.randf_range(0.5, 2.0)
	while t < seconds - 2.0:
		var dur := rng.randf_range(0.8, 1.8)
		var n := int(dur * RATE)
		var x := PackedFloat32Array()
		x.resize(n)
		var wing := rng.randf_range(28.0, 40.0)
		for i in n:
			x[i] = (rng.randf() * 2.0 - 1.0) * (0.5 + 0.5 * sin(TAU * wing * i / RATE))
		var y := filter(x, "bp", rng.randf_range(250.0, 420.0), 1.5)
		var at := int(t * RATE)
		for i in n:
			var u := float(i) / n
			out[(at + i) % out.size()] += y[i] * sin(PI * u) * sin(PI * u) * 0.5
		t += dur + rng.randf_range(1.5, 5.0)
	return out


## Высокогорный ветер: воющий свист в узкой полосе, медленно плывущий по высоте
static func howl(seconds: float, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var n := int(seconds * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = rng.randf() * 2.0 - 1.0
	var out := silence(seconds)
	# несколько полос, частота каждой медленно «гуляет» (по кускам)
	var chunk := int(RATE * 0.25)
	for band in 3:
		var f0 := rng.randf_range(500.0, 1100.0)
		var k1 := float(rng.randi_range(1, 3))
		var i := 0
		while i < n:
			var u := float(i) / n
			var f := f0 * (1.0 + 0.35 * sin(u * TAU * k1 + band))
			var piece := x.slice(i, mini(i + chunk + 400, n))
			var y := filter(piece, "bp", f, 12.0)
			var g := 0.5 + 0.5 * sin(u * TAU * (k1 + 1.0) + band * 2.0)
			for j in mini(chunk, y.size()):
				var fade := minf(1.0, float(j) / 200.0) # сглаживаем стыки
				out[i + j] += y[j] * g * 0.5 * fade
			i += chunk
	return out


## Орёл: протяжный нисходящий крик «кии-ээр»
static func eagles(seconds: float, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var out := silence(seconds)
	var t := rng.randf_range(1.0, 3.0)
	while t < seconds - 2.0:
		var dur := rng.randf_range(0.6, 1.1)
		var n := int(dur * RATE)
		var f0 := rng.randf_range(2300.0, 3000.0)
		var at := int(t * RATE)
		var ph := 0.0
		for i in n:
			var u := float(i) / n
			var f := f0 * (1.0 - 0.35 * u * u) * (1.0 + 0.02 * sin(u * 120.0))
			ph += TAU * f / RATE
			var env := minf(1.0, u * 15.0) * pow(1.0 - u, 1.5)
			var v := (sin(ph) + 0.4 * sin(ph * 2.0) + 0.15 * sin(ph * 3.0)) * env
			out[(at + i) % out.size()] += v * 0.12
		t += dur + rng.randf_range(4.0, 9.0)
	return filter(out, "hp", 900.0, 0.7)


## Водопад вдалеке: широкий шум, низы и ровный гул
static func waterfall(seconds: float, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var n := int(seconds * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var last := 0.0
	for i in n:
		var w := rng.randf() * 2.0 - 1.0
		last = last * 0.92 + w * 0.08 # «розовее» белого
		x[i] = w * 0.4 + last * 2.0
	var a := filter(x, "lp", 1800.0, 0.6)
	var b := filter(x, "bp", 350.0, 0.7)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var u := float(i) / n
		out[i] = (a[i] * 0.25 + b[i] * 0.35) * (0.85 + 0.15 * sin(u * TAU * 3.0))
	var fade := int(RATE * 0.1)
	for i in fade:
		var k := float(i) / fade
		out[n - fade + i] = out[n - fade + i] * (1.0 - k) + out[i] * k
	return out


## Капли в пустом зале: редкие «кап» с гулким эхом
static func drips(seconds: float, seed_value: int) -> PackedFloat32Array:
	rng.seed = seed_value
	var out := silence(seconds)
	var t := rng.randf_range(0.3, 1.5)
	while t < seconds - 1.0:
		var f0 := rng.randf_range(900.0, 1900.0)
		var dur := 0.05
		var n := int(dur * RATE)
		for echo in 4:
			var at := int((t + echo * 0.23) * RATE)
			var g := 0.18 * pow(0.45, echo)
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				ph += TAU * f0 * (1.0 + 0.6 * u) / RATE
				out[(at + i) % out.size()] += sin(ph) * exp(-u * 6.0) * g
		t += rng.randf_range(1.2, 4.5)
	return filter(out, "lp", 3500.0, 0.7)
