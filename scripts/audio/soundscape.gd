class_name Soundscape
extends Node
## Базовые звуки мира: ветер, треск фитиля, шаги, события (вздох, флакон, огонь, Тень).
## Звуки областей (птицы, кузнечики и т.д.) — в RegionAudio.

var _rng := RandomNumberGenerator.new()
var _wind: AudioStreamPlayer
var _whistle: AudioStreamPlayer
var _hiss: AudioStreamPlayer
var _wind_bus := -1
var _whistle_bus := -1
var _steps := {}
var _crackles: Array[AudioStreamWAV] = []
var _sfx := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _t := 0.0
var _next_crackle := 0.0
var _master := 0.0
var started := false
## 0..1 — насколько вокруг героя ожил мир (ветер стихает)
var calm := 0.0
## 0..1 — громкость фитиля (зависит от масла)
var wick := 1.0
## 0..1 — насколько герой в горах (ледяной ветер)
var mountain := 0.0


func build() -> void:
	name = "Soundscape"
	_rng.seed = 3
	Synth.rng.seed = 3
	_wind_bus = _make_bus("Wind", [_bandpass(400.0, 0.6), AudioEffectPanner.new()])
	_whistle_bus = _make_bus("Whistle", [_bandpass(1100.0, 0.9)])
	_make_bus("Hiss", [_highpass(3500.0)])
	_wind = _loop_player(Synth.wav(Synth.noise(4.0, true), true), "Wind")
	_whistle = _loop_player(Synth.wav(Synth.noise(3.0, false), true), "Whistle")
	_hiss = _loop_player(Synth.wav(Synth.noise(2.0, false), true), "Hiss")
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for s in ["grass", "dirt", "rock", "water", "wood"]:
		var arr: Array[AudioStreamWAV] = []
		for v in 5:
			arr.append(Synth.wav(_make_step(s), false))
		_steps[s] = arr
	for i in 8:
		_crackles.append(Synth.wav(Synth.burst(_rng.randf_range(0.008, 0.028), "bp", _rng.randf_range(1800.0, 4800.0), 1.5, _rng.randf_range(0.5, 1.0), 0.001), false))
	_sfx.sigh = Synth.wav(Synth.sigh(), false)
	_sfx.clink = Synth.wav(Synth.clink(), false)
	_sfx.ignite = Synth.wav(Synth.ignite(), false)
	_sfx.disperse = Synth.wav(Synth.disperse(), false)
	AudioServer.set_bus_volume_db(0, linear_to_db(0.0001))


func start() -> void:
	started = true
	_wind.play(_rng.randf() * 3.0)
	_whistle.play(_rng.randf() * 2.0)
	_hiss.play(_rng.randf())


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


func _make_step(surface: String) -> PackedFloat32Array:
	var v := _rng.randf_range(0.85, 1.15)
	match surface:
		"grass":
			return Synth.mix(Synth.burst(0.14 * v, "bp", 3200.0 * v, 0.7, 0.9, 0.025), Synth.burst(0.05, "lp", 500.0, 0.7, 0.9, 0.005))
		"dirt":
			return Synth.mix(Synth.burst(0.08 * v, "lp", 380.0 * v, 0.8, 2.6, 0.004), Synth.burst(0.06, "bp", 1700.0 * v, 1.2, 0.5, 0.01))
		"rock":
			return Synth.mix(Synth.burst(0.03 * v, "bp", 2400.0 * v, 2.5, 1.6, 0.002), Synth.burst(0.05, "lp", 260.0, 0.7, 2.4, 0.002))
		"wood": # гулкий шаг по доскам, с лёгким скрипом
			return Synth.mix(Synth.burst(0.06 * v, "bp", 520.0 * v, 2.5, 2.0, 0.002), Synth.burst(0.1, "lp", 170.0, 0.9, 2.0, 0.002))
		_:
			return Synth.mix(Synth.burst(0.22 * v, "bp", 600.0, 1.5, 1.4, 0.02, 2200.0), Synth.burst(0.12, "lp", 300.0, 0.7, 1.4, 0.01))


func play(stream: AudioStreamWAV, volume: float, pitch := 1.0) -> void:
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.volume_db = linear_to_db(maxf(volume, 0.0001))
	p.pitch_scale = pitch
	p.play()


func sfx(id: String, volume := 0.5, pitch := 1.0) -> void:
	if started and _sfx.has(id):
		play(_sfx[id], volume, pitch)


func update_sound(dt: float) -> void:
	if not started:
		return
	_t += dt
	_master = minf(1.0, _master + dt / 4.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, _master * 0.9 * Settings.volume)))
	var t := _t
	var gust := 0.5 + 0.5 * sin(t * 0.11) * sin(t * 0.047 + 1.3)
	var g2 := maxf(0.0, sin(t * 0.07 + 2.0) * sin(t * 0.19))
	var still := 1.0 - calm * 0.65 # в ожившей области ветер стихает
	_wind.volume_db = linear_to_db((0.12 + gust * 0.32) * still * (1.0 + mountain * 0.9))
	(AudioServer.get_bus_effect(_wind_bus, 0) as AudioEffectBandPassFilter).cutoff_hz = 260.0 + gust * 520.0
	(AudioServer.get_bus_effect(_wind_bus, 1) as AudioEffectPanner).pan = sin(t * 0.05) * 0.6
	_whistle.volume_db = linear_to_db(maxf(0.0001, (g2 * g2 * 0.05 + mountain * (0.02 + gust * 0.04)) * still))
	(AudioServer.get_bus_effect(_whistle_bus, 0) as AudioEffectBandPassFilter).cutoff_hz = 900.0 + g2 * 700.0 + sin(t * 0.5) * 80.0
	_hiss.volume_db = linear_to_db(maxf(0.0001, 0.012 * wick))
	if t > _next_crackle and wick > 0.05:
		play(_crackles[_rng.randi() % _crackles.size()], _rng.randf_range(0.05, 0.12) * wick, _rng.randf_range(0.9, 1.2))
		_next_crackle = t + (_rng.randf_range(0.05, 0.17) if _rng.randf() < 0.25 else _rng.randf_range(0.4, 2.6))


func step(surface: String) -> void:
	if not started:
		return
	var arr: Array = _steps.get(surface, _steps["dirt"])
	play(arr[_rng.randi() % arr.size()], 0.22 if surface != "grass" else 0.16, _rng.randf_range(0.9, 1.1))
