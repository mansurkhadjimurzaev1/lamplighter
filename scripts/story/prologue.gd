class_name Prologue
extends Node
## Предыстория в начале новой игры: камера медленно облетает тёмный мир, внизу — строки
## рассказа. Горы с подземным огнём → погасшие маяки → замок → деревня за запертыми дверями →
## старый фонарщик. Esc / пробел / Enter — пропустить.

signal finished

const LINES_RU := [
	"Двадцать лет назад в горах загорелась сама земля. Подземный огонь поднял дым и пепел — Пелену, что закрыла небо.",
	"На холмах королевства стояли маяки. Их огонь и тёплый ветер гнали дым прочь.",
	"Но король поверил советнику, что свет приносит беду. Маяки погасли один за другим.",
	"Люди заперли двери. Из их страха и тоски родились Тени — они бродят во тьме и боятся только света.",
	"Из всех фонарщиков королевства остался один — старый, почти забытый. Этой ночью старейшина Тихого Брода позвал его к себе.",
]
const LINES_EN := [
	"Twenty years ago the very earth caught fire in the mountains. The fire underground raised smoke and ash — the Pall that covered the sky.",
	"Beacons stood on the hills of the kingdom. Their fire and warm wind drove the smoke away.",
	"But the king believed his advisor, who said that light brings misfortune. One by one, the beacons went out.",
	"People locked their doors. Their fear and longing gave birth to the Shades — they roam the dark and fear only light.",
	"Of all the lamplighters in the kingdom only one remained — old, almost forgotten. Tonight the elder of Quiet Ford has called for him.",
]

var main: Node
var cam: Camera3D
var _shots: Array = []
var _i := 0
var _st := 0.0
var _t := 0.0
var _lines: Array = []
var _layer: CanvasLayer
var _text: Label
var _title: Label
var _fade: ColorRect
var _hint: Label
var _ending := -1.0
var _done := false


func begin(main_node: Node, camera: Camera3D, hero_pos: Vector3) -> void:
	main = main_node
	cam = camera
	name = "Prologue"
	_lines = LINES_EN if Settings.lang == "en" else LINES_RU
	var mc := _g(MountainLayout.CENTER + Vector2(8, 4), 6.0)
	var b0: Vector3 = main.beacons[0].position
	var cc := _g(CastleLayout.CENTER, 3.0)
	var vc := _g(VillageLayout.CENTER, 1.0)
	_shots = [
		{pos = mc + Vector3(34, 16, 26), look = mc + Vector3(0, 4, 0), dur = 9.0, drift = Vector3(-6, 1, 3)},
		{pos = b0 + Vector3(9, 5, 12), look = b0 + Vector3(0, 1.5, 0), dur = 7.5, drift = Vector3(4, 0.5, -2)},
		{pos = _g(CastleLayout.GATE + Vector2(7, -16), 6.0), look = cc + Vector3(0, 2, 0), dur = 8.0, drift = Vector3(-5, 1, 2)},
		{pos = vc + Vector3(10, 7, 14), look = vc + Vector3(0, 0.5, 0), dur = 8.5, drift = Vector3(-5, -1, 2)},
		{pos = hero_pos + Vector3(2.6, 1.9, 3.4), look = hero_pos + Vector3(0, 1.0, 0), dur = 9.5, drift = Vector3(0.8, 0.3, 0.6)},
	]
	_build_overlay()


func _g(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.y) + lift, p.y)


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 30
	main.add_child(_layer)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 70)
		if not top:
			bar.offset_top = -70
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(bar)
	_text = UiStyle.label("", 29, Color(1.0, 0.92, 0.78), false, true)
	_text.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_text.offset_top = -200
	_text.offset_left = -580
	_text.offset_right = 580
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_text.add_theme_constant_override("outline_size", 8)
	_text.modulate.a = 0.0
	_layer.add_child(_text)
	_title = UiStyle.label(Tr.t("Последний фонарщик"), 64, Color(0.98, 0.84, 0.58))
	_title.add_theme_font_override("font", UiStyle.title_font())
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title.offset_left = -500
	_title.offset_right = 500
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_title.add_theme_constant_override("outline_size", 10)
	_title.modulate.a = 0.0
	_layer.add_child(_title)
	_hint = UiStyle.label(Tr.t("Пробел — пропустить"), 16, Color(0.95, 0.85, 0.7, 0.45))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -260
	_hint.offset_top = -52
	_hint.offset_right = -24
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_layer.add_child(_hint)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)


func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


func update(dt: float) -> void:
	if _done:
		return
	_t += dt
	# конец: название поверх последнего плана, затем затемнение и снова игра
	if _ending >= 0.0:
		_ending += dt
		_text.modulate.a = maxf(0.0, _text.modulate.a - dt * 1.5)
		_title.modulate.a = clampf(minf(_ending / 1.5, (4.6 - _ending) / 1.0), 0.0, 1.0)
		_fade.modulate.a = Terrain.ss(4.0, 5.2, _ending)
		_hold_camera(dt)
		if _ending > 5.4:
			_finish()
		return
	if _t < 2.0:
		_fade.modulate.a = 1.0 - Terrain.ss(0.2, 2.0, _t)
	_st += dt
	var s: Dictionary = _shots[_i]
	var u := clampf(_st / float(s.dur), 0.0, 1.0)
	_hold_camera(dt)
	_text.text = _lines[_i]
	_text.modulate.a = clampf(minf((_st - 0.8) / 1.0, (float(s.dur) - _st) / 0.9), 0.0, 1.0)
	# короткое затемнение между планами
	if _t > 2.0:
		_fade.modulate.a = maxf(1.0 - Terrain.ss(0.0, 0.7, _st), Terrain.ss(float(s.dur) - 0.7, float(s.dur), _st)) if _i < _shots.size() - 1 else 1.0 - Terrain.ss(0.0, 0.7, _st)
	if u >= 1.0:
		if _i < _shots.size() - 1:
			_i += 1
			_st = 0.0
		else:
			_ending = 0.0


func _hold_camera(_dt: float) -> void:
	var s: Dictionary = _shots[_i]
	var u := clampf(_st / float(s.dur), 0.0, 1.0)
	cam.global_position = (s.pos as Vector3) + (s.drift as Vector3) * _ease(u)
	cam.look_at(s.look, Vector3.UP)


func skip() -> void:
	if _ending < 0.0:
		_i = _shots.size() - 1
		_st = float(_shots[_i].dur)
		_ending = 3.9
	else:
		_ending = maxf(_ending, 3.9)


func _finish() -> void:
	_done = true
	_layer.queue_free()
	finished.emit()
