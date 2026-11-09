class_name FpsMeter
extends CanvasLayer
## Счётчик кадров (клавиша F)

var label := Label.new()
var extra: Callable = func(): return ""
var _acc := 0.0
var _frames := 0


func build() -> void:
	layer = 20
	label.position = Vector2(12, 10)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.63))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.1))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	visible = Args.has("fps")


func toggle() -> void:
	visible = not visible


func _process(dt: float) -> void:
	_frames += 1
	_acc += dt
	if _acc >= 0.5:
		label.text = "%d fps\n%s" % [roundi(_frames / _acc), extra.call()]
		_frames = 0
		_acc = 0.0
