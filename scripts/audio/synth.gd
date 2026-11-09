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
