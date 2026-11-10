class_name RegionAudio
extends Node
## «Мир возвращает голос»: у каждой области свои слои звуков жизни.
## Слой звучит там, где область ожила после маяка (громкость = насколько ожило место вокруг героя).
## Сейчас готовы: птицы, кузнечики. Остальные слои — заготовки (появятся с областями).

## Описание областей (5 из библии + тестовый остров). layers — имена слоёв.
const REGIONS := {
	"village": {name = "Тихий Брод", beacon = 0, layers = ["birds", "crickets"]}, # + петухи, голоса, колодец, овцы — звучат с мест (Village)
	"forest": {name = "Шепчущий лес", beacon = 1, layers = ["birds", "rustle", "woodpecker"]},
	"swamp": {name = "Топь", beacon = 2, layers = ["frogs", "water", "dragonflies"]},
	"mountains": {name = "Горная обсерватория", beacon = 3, layers = ["wind_high", "eagles", "waterfall"]},
	"castle": {name = "Руины замка", beacon = -1, layers = ["all"]},
}

var _players := {} # слой → массив плееров (несколько голосов с разной панорамой)
var _levels := {} # слой → текущая громкость 0..1


func build() -> void:
	name = "RegionAudio"
	var c := func(key: String, fn: Callable) -> AudioStreamWAV: return Synth.cached(key, fn, true)
	_add_layer("birds", [c.call("birds_a", func(): return Synth.birds(14.0, 1.0, 11)), c.call("birds_b", func(): return Synth.birds(11.0, 0.7, 23))], [-0.5, 0.5], 0.55)
	_add_layer("crickets", [c.call("crickets_a", func(): return Synth.crickets(8.0, 5, 31)), c.call("crickets_b", func(): return Synth.crickets(6.0, 4, 37))], [-0.35, 0.35], 0.35)
	_add_layer("rustle", [c.call("rustle_a", func(): return Synth.rustle(12.0, 41)), c.call("rustle_b", func(): return Synth.rustle(9.0, 43))], [-0.6, 0.6], 0.5)
	_add_layer("woodpecker", [c.call("woodpecker", func(): return Synth.woodpecker(23.0, 47))], [0.4], 0.5)
	_add_layer("wind_high", [c.call("howl_a", func(): return Synth.howl(12.0, 71))], [0.3], 0.35)
	_add_layer("eagles", [c.call("eagles_a", func(): return Synth.eagles(21.0, 73)), c.call("eagles_b", func(): return Synth.eagles(17.0, 79))], [-0.5, 0.5], 0.45)
	_add_layer("waterfall", [c.call("waterfall_a", func(): return Synth.waterfall(8.0, 83))], [-0.6], 0.4)
	_add_layer("frogs", [c.call("frogs_a", func(): return Synth.frogs(13.0, 5, 51)), c.call("frogs_b", func(): return Synth.frogs(17.0, 4, 53))], [-0.55, 0.55], 0.55)
	_add_layer("water", [c.call("babble_a", func(): return Synth.babble(9.0, 57))], [0.0], 0.45)
	_add_layer("dragonflies", [c.call("dragonflies_a", func(): return Synth.dragonflies(15.0, 59)), c.call("dragonflies_b", func(): return Synth.dragonflies(11.0, 61))], [-0.4, 0.4], 0.45)


func _add_layer(id: String, loops: Array, pans: Array, volume: float) -> void:
	var arr := []
	for i in loops.size():
		var bus_name := "%s_%d" % [id, i]
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
			var pan := AudioEffectPanner.new()
			pan.pan = pans[i]
			AudioServer.add_bus_effect(idx, pan)
		var p := AudioStreamPlayer.new()
		p.stream = loops[i]
		p.bus = bus_name
		p.volume_db = -80.0
		add_child(p)
		arr.append({player = p, volume = volume})
	_players[id] = arr
	_levels[id] = 0.0


## life — насколько ожило место вокруг героя по каждой области: { "island": 0..1, ... }
func update_layers(dt: float, life: Dictionary) -> void:
	var want := {}
	for region_id in REGIONS:
		var r: Dictionary = REGIONS[region_id]
		var v: float = life.get(region_id, 0.0)
		for layer in r.layers:
			want[layer] = maxf(want.get(layer, 0.0), v)
	for layer in _players:
		var target: float = want.get(layer, 0.0)
		_levels[layer] = move_toward(_levels[layer], target, dt * 0.25) # звуки нарастают плавно
		for voice in _players[layer]:
			var p: AudioStreamPlayer = voice.player
			var lv: float = _levels[layer] * voice.volume
			if lv > 0.001 and not p.playing:
				p.play(randf() * p.stream.get_length())
			elif lv <= 0.001 and p.playing:
				p.stop()
			p.volume_db = linear_to_db(maxf(lv, 0.0001))
