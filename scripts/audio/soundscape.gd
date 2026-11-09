class_name Soundscape
extends Node
## Звуки мира, синтезированные кодом: никаких записей и никакой музыки.
## Во тьме мир почти беззвучен: ветер, треск фитиля, шаги.

const RATE := 22050

var _rng := RandomNumberGenerator.new()
var _wind: AudioStreamPlayer
var _whistle: AudioStreamPlayer
var _hiss: AudioStreamPlayer
var _wind_bus := -1
var _whistle_bus := -1
var _steps := {} # поверхность → массив вариантов
var _crackles: Array[AudioStreamWAV] = []
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _t := 0.0
var _next_crackle := 0.0
var _master := 0.0 # плавное нарастание громкости после старта
var started := false


func build() -> void:
	name = "Soundscape"
	_rng.seed = 3
	_wind_bus = _make_bus("Wind", [_bandpass(400.0, 0.6), AudioEffectPanner.new()])
	_whistle_bus = _make_bus("Whistle", [_bandpass(1100.0, 0.9)])
	var hiss_bus := _make_bus("Hiss", [_highpass(3500.0)])
	_wind = _loop_player(_noise(4.0, true), "Wind")
	_whistle = _loop_player(_noise(3.0, false), "Whistle")
	_hiss = _loop_player(_noise(2.0, false), "Hiss")
	_hiss.volume_db = linear_to_db(0.012)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	# заранее «записываем» несколько вариантов каждого шага и треска
	for s in ["grass", "dirt", "rock", "water"]:
		var arr: Array[AudioStreamWAV] = []
		for v in 5:
			arr.append(_make_step(s))
		_steps[s] = arr
	for i in 8:
		_crackles.append(_make_crackle())
	AudioServer.set_bus_volume_db(0, linear_to_db(0.0001))


func start() -> void:
	started = true
	_wind.play(_rng.randf() * 3.0)
	_whistle.play(_rng.randf() * 2.0)
	_hiss.play(_rng.randf())


# ── шины и плееры ───────────────────────────────────────────

func _make_bus(bus_name: String, effects: Array) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
		for e in effects:
			AudioServer.add_bus_effect(idx, e)
	return idx


func _bandpass(hz: float, res: float) -> AudioEffectBandPassFilter:
	var f := AudioEffectBandPassFilter.new()
	f.cutoff_hz = hz
	f.resonance = res
	return f


func _highpass(hz: float) -> AudioEffectHighPassFilter:
	var f := AudioEffectHighPassFilter.new()
	f.cutoff_hz = hz
	return f


func _loop_player(stream: AudioStreamWAV, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


# ── синтез ──────────────────────────────────────────────────

func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
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


## Белый или «коричневый» (низкий, гудящий) шум; конец плавно сведён с началом
func _noise(seconds: float, brown: bool) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var s := PackedFloat32Array()
	s.resize(n)
	var last := 0.0
	for i in n:
		var w := _rng.randf() * 2.0 - 1.0
		if brown:
			last = (last + 0.02 * w) / 1.02
			s[i] = last * 3.5
		else:
			s[i] = w * 0.5
	var fade := int(RATE * 0.08)
	for i in fade:
		var k := float(i) / fade
		s[n - fade + i] = s[n - fade + i] * (1.0 - k) + s[i] * k
	return _wav(s, true)


## Фильтр (biquad) для синтеза: "lp" | "hp" | "bp"
func _filter(x: PackedFloat32Array, type: String, hz: float, q: float) -> PackedFloat32Array:
	var w0 := TAU * hz / RATE
	var al := sin(w0) / (2.0 * q)
	var cw := cos(w0)
	var b0 := 0.0; var b1 := 0.0; var b2 := 0.0
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
	var x1 := 0.0; var x2 := 0.0; var y1 := 0.0; var y2 := 0.0
	for i in x.size():
		var v := (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1; x1 = x[i]; y2 = y1; y1 = v
		y[i] = v
	return y


## Короткий всплеск шума с фильтром и затуханием
func _burst(dur: float, type: String, hz: float, q: float, gain: float, attack: float, sweep_to := 0.0) -> PackedFloat32Array:
	var n := int(RATE * (dur + attack + 0.02))
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = _rng.randf() * 2.0 - 1.0
	var y: PackedFloat32Array
	if sweep_to > 0.0:
		# «всплеск» воды: две половины с разной частотой
		var a := _filter(x, type, hz, q)
		var b := _filter(x, type, sweep_to, q)
		y = PackedFloat32Array()
		y.resize(n)
		for i in n:
			var k := float(i) / n
			y[i] = a[i] * (1.0 - k) + b[i] * k
	else:
		y = _filter(x, type, hz, q)
	for i in n:
		var t := float(i) / RATE
		var env := t / attack if t < attack else exp(-(t - attack) / (dur * 0.3))
		y[i] *= env * gain
	return y


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out


func _make_step(surface: String) -> AudioStreamWAV:
	var v := _rng.randf_range(0.85, 1.15)
	var s: PackedFloat32Array
	match surface:
		"grass": # шорох
			s = _mix(_burst(0.14 * v, "bp", 3200.0 * v, 0.7, 0.9, 0.025), _burst(0.05, "lp", 500.0, 0.7, 0.9, 0.005))
		"dirt": # мягкий глухой шаг + хруст
			s = _mix(_burst(0.08 * v, "lp", 380.0 * v, 0.8, 2.6, 0.004), _burst(0.06, "bp", 1700.0 * v, 1.2, 0.5, 0.01))
		"rock": # твёрдый щелчок
			s = _mix(_burst(0.03 * v, "bp", 2400.0 * v, 2.5, 1.6, 0.002), _burst(0.05, "lp", 260.0, 0.7, 2.4, 0.002))
		_: # плеск
			s = _mix(_burst(0.22 * v, "bp", 600.0, 1.5, 1.4, 0.02, 2200.0), _burst(0.12, "lp", 300.0, 0.7, 1.4, 0.01))
	return _wav(s, false)


func _make_crackle() -> AudioStreamWAV:
	return _wav(_burst(_rng.randf_range(0.008, 0.028), "bp", _rng.randf_range(1800.0, 4800.0), 1.5, _rng.randf_range(0.5, 1.0), 0.001), false)


func _play(stream: AudioStreamWAV, volume: float, pitch := 1.0) -> void:
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.volume_db = linear_to_db(volume)
	p.pitch_scale = pitch
	p.play()


# ── каждый кадр ─────────────────────────────────────────────

func update_sound(dt: float) -> void:
	if not started:
		return
	_t += dt
	_master = minf(1.0, _master + dt / 4.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, _master * 0.9)))
	var t := _t
	var gust := 0.5 + 0.5 * sin(t * 0.11) * sin(t * 0.047 + 1.3)
	var g2 := maxf(0.0, sin(t * 0.07 + 2.0) * sin(t * 0.19))
	_wind.volume_db = linear_to_db(0.12 + gust * 0.32)
	(AudioServer.get_bus_effect(_wind_bus, 0) as AudioEffectBandPassFilter).cutoff_hz = 260.0 + gust * 520.0
	(AudioServer.get_bus_effect(_wind_bus, 1) as AudioEffectPanner).pan = sin(t * 0.05) * 0.6
	_whistle.volume_db = linear_to_db(maxf(0.0001, g2 * g2 * 0.05))
	(AudioServer.get_bus_effect(_whistle_bus, 0) as AudioEffectBandPassFilter).cutoff_hz = 900.0 + g2 * 700.0 + sin(t * 0.5) * 80.0
	if t > _next_crackle:
		_play(_crackles[_rng.randi() % _crackles.size()], _rng.randf_range(0.05, 0.12), _rng.randf_range(0.9, 1.2))
		_next_crackle = t + (_rng.randf_range(0.05, 0.17) if _rng.randf() < 0.25 else _rng.randf_range(0.4, 2.6))


func step(surface: String) -> void:
	if not started:
		return
	var arr: Array = _steps.get(surface, _steps["dirt"])
	_play(arr[_rng.randi() % arr.size()], 0.22 if surface != "grass" else 0.16, _rng.randf_range(0.9, 1.1))
