class_name GoalHud
extends CanvasLayer
## Строка «что сейчас» под мини-картой и метка цели на экране: тёплый ромбик над местом
## с расстоянием; если цель за краем экрана — стрелка у края. Вблизи цели метка гаснет.

var text := ""
var target: Variant = null # Vector3 или null
var urgent := false # волна Пелены — строка тревожнее
var cam: Camera3D
var hero_pos := Vector3.ZERO
var shown := true

var _label: Label
var _marker: Marker
var _alpha := 0.0
var _shown_text := ""
var _text_a := 0.0


class Marker extends Control:
	var screen := Vector2.ZERO
	var on_screen := true
	var dir := Vector2.UP
	var dist := 0.0
	var a := 0.0
	var urgent := false
	var t := 0.0
	var font: Font

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		if a < 0.01:
			return
		var col := Color(1.0, 0.45, 0.3, a) if urgent else Color(1.0, 0.8, 0.45, a)
		var pulse := 1.0 + 0.12 * sin(t * 3.0)
		if on_screen:
			var p := screen
			var s := 9.0 * pulse
			var pts := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.7, 0), p + Vector2(0, s), p + Vector2(-s * 0.7, 0)])
			draw_colored_polygon(pts, Color(col, a * 0.85))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.1, 0.06, 0.04, a * 0.8), 1.5, true)
			draw_circle(p, 22.0 * pulse, Color(col, a * 0.08))
			if font:
				var txt := "%d м" % int(dist) if Settings.lang != "en" else "%d m" % int(dist)
				var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
				draw_string_outline(font, p + Vector2(-w * 0.5, 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(0.04, 0.03, 0.06, a * 0.85))
				draw_string(font, p + Vector2(-w * 0.5, 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(col, a))
		else:
			# стрелка у края экрана
			var p := screen
			var d := dir.normalized()
			var n := Vector2(-d.y, d.x)
			var tip := p + d * 14.0 * pulse
			var pts := PackedVector2Array([tip, p - d * 6.0 + n * 9.0, p - d * 2.0, p - d * 6.0 - n * 9.0])
			draw_colored_polygon(pts, Color(col, a * 0.9))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.1, 0.06, 0.04, a * 0.8), 1.5, true)


func build() -> void:
	layer = 4
	var touch := OS.has_feature("mobile")
	_label = UiStyle.label("", 19, Color(1.0, 0.88, 0.66), false, true)
	_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_label.offset_top = (70.0 + 170.0 + 10.0) if touch else (18.0 + 210.0 + 10.0)
	_label.offset_right = -18.0
	_label.offset_left = -330.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.06, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_marker = Marker.new()
	_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.font = UiStyle.font(true)
	add_child(_marker)


func _process(dt: float) -> void:
	# строка: плавная смена текста
	if text != _shown_text:
		_text_a = move_toward(_text_a, 0.0, dt * 3.0)
		if _text_a <= 0.0:
			_shown_text = text
			_label.text = ("◆  " + text) if text != "" else ""
	else:
		_text_a = move_toward(_text_a, 1.0 if shown else 0.0, dt * 2.0)
	_label.modulate.a = _text_a
	_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.5) if urgent else Color(1.0, 0.88, 0.66))
	# метка
	var want := 0.0
	if shown and target != null and cam != null:
		var p: Vector3 = (target as Vector3) + Vector3(0, 2.2, 0)
		var dist := Vector2(p.x - hero_pos.x, p.z - hero_pos.z).length()
		want = Terrain.ss(3.0, 7.0, dist)
		_marker.dist = dist
		var rect := _marker.get_rect()
		var margin := 46.0
		var sp := cam.unproject_position(p)
		var behind := cam.is_position_behind(p)
		var inner := Rect2(rect.position + Vector2(margin, margin), rect.size - Vector2(margin, margin) * 2.0)
		if not behind and inner.has_point(sp):
			_marker.on_screen = true
			_marker.screen = sp
		else:
			# направление на цель в плоскости экрана
			var c := rect.size * 0.5
			var d := sp - c
			if behind:
				d = -d
			if d.length() < 1.0:
				d = Vector2.DOWN
			var k := minf(abs((inner.size.x * 0.5) / maxf(abs(d.x), 0.001)), abs((inner.size.y * 0.5) / maxf(abs(d.y), 0.001)))
			_marker.on_screen = false
			_marker.screen = c + d * k
			_marker.dir = d
	_alpha = move_toward(_alpha, want, dt * 2.0)
	_marker.a = _alpha * 0.9
	_marker.urgent = urgent
