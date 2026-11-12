extends SceneTree
## Пики и громкость синтезированных звуков настроения (проверка без прослушивания)
func _initialize() -> void:
	var a := Ambience.new()
	var list := {owl = a._owl(), creak = a._creak(1.4, 31), twig = a._twig(5), bubble = a._bubble(3), ice = a._ice(), pebbles = a._pebbles(), whisper = a._whisper(7), stone = a._stone(), squeak = a._squeak(), lap = a._lapping(6.0)}
	for k in list:
		var x: PackedFloat32Array = list[k]
		var pk := 0.0
		var ss := 0.0
		for v in x:
			pk = maxf(pk, absf(v))
			ss += v * v
		print("%-8s len=%.2fs peak=%.2f rms=%.3f" % [k, x.size() / float(Synth.RATE), pk, sqrt(ss / maxf(x.size(), 1))])
	a.free()
	quit()
