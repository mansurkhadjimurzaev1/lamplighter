class_name RegionAudio
extends Node
## «Мир возвращает голос»: у каждой области свои слои звуков жизни.
## Слой звучит там, где область ожила после маяка (громкость = насколько ожило место вокруг героя).
## Сейчас готовы: птицы, кузнечики. Остальные слои — заготовки (появятся с областями).

## Описание областей (5 из библии + тестовый остров). layers — имена слоёв.
const REGIONS := {
	"island": {name = "Остров (тест)", beacon = 0, layers = ["birds", "crickets"]},
	"village": {name = "Тихий Брод", beacon = -1, layers = ["roosters", "voices", "well", "sheep"]},
	"forest": {name = "Шепчущий лес", beacon = -1, layers = ["birds", "rustle", "woodpecker"]},
	"swamp": {name = "Топь", beacon = -1, layers = ["frogs", "water", "dragonflies"]},
	"mountains": {name = "Горная обсерватория", beacon = -1, layers = ["wind_high", "eagles", "waterfall"]},
	"castle": {name = "Руины замка", beacon = -1, layers = ["all"]},
}

var _players := {} # слой → массив плееров (несколько голосов с разной панорамой)
var _levels := {} # слой → текущая громкость 0..1


func build() -> void:
	name = "RegionAudio"
	_add_layer("birds", [Synth.birds(14.0, 1.0, 11), Synth.birds(11.0, 0.7, 23)], [-0.5, 0.5], 0.55)
	_add_layer("crickets", [Synth.crickets(8.0, 5, 31), Synth.crickets(6.0, 4, 37)], [-0.35, 0.35], 0.35)


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
		p.stream = Synth.wav(loops[i], true)
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
