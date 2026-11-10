class_name Minimap
extends CanvasLayer
## Мини-карта (круг в углу, повёрнута как камера) и большая карта мира (M / тап по мини-карте).
## Метки: герой (стрелка), маяки, жители с новостями, примерные места целей заданий.

signal toggled(open: bool)

const MINI_RADIUS_M := 30.0

var markers: Array = [] # {pos: Vector2, kind: String, r: float}
var labels: Array = [] # {pos: Vector2, text: String}
var hero := Vector2.ZERO
var facing := 0.0 # угол взгляда героя (как rotation.y)
var fwd := Vector2(0, -1) # «вверх по экрану» в мире

var _mini: ColorRect
var _mini_mat: ShaderMaterial
var _mini_marks: Control
var _full_root: Control
var _full: ColorRect
var _full_mat: ShaderMaterial
var _full_marks: Control
var _open := false
var _size := 180.0
var _alpha := 1.0
var _shown := true


func build() -> void:
	layer = 6
	var touch := OS.has_feature("mobile")
	_size = 170.0 if touch else 210.0
	_mini_mat = _make_mat(0)
	_mini = ColorRect.new()
	_mini.material = _mini_mat
	_mini.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mini.offset_left = -_size - 18.0
	_mini.offset_right = -18.0
	_mini.offset_top = 70.0 if touch else 18.0
	_mini.offset_bottom = _mini.offset_top + _size
	_mini.mouse_filter = Control.MOUSE_FILTER_STOP
	_mini.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			toggle_full())
	add_child(_mini)
	_mini_marks = Control.new()
	_mini_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mini_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_marks.draw.connect(_draw_mini)
	_mini.add_child(_mini_marks)

	# большая карта
	_full_root = Control.new()
	_full_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_full_root.visible = false
	add_child(_full_root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.03, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			toggle_full())
	_full_root.add_child(dim)
	_full_mat = _make_mat(1)
	_full = ColorRect.new()
	_full.material = _full_mat
	_full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full_root.add_child(_full)
	_full_marks = Control.new()
	_full_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full_marks.draw.connect(_draw_full)
	_full.add_child(_full_marks)


func _make_mat(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/map.gdshader")
	m.set_shader_parameter("base_tex", MapData.base_tex)
	m.set_shader_parameter("fog_tex", MapData.fog_tex)
	m.set_shader_parameter("world_min", Terrain.MIN)
	m.set_shader_parameter("world_size", Terrain.MAX - Terrain.MIN)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("view_radius", MINI_RADIUS_M)
	return m


func is_open() -> bool:
	return _open


func toggle_full() -> void:
	_open = not _open
	_full_root.visible = _open
	if _open:
		_layout_full()
	toggled.emit(_open)


func set_shown(on: bool) -> void:
	_shown = on


func _layout_full() -> void:
	var vs := get_viewport().get_visible_rect().size
	var world := Terrain.MAX - Terrain.MIN
	var s := minf((vs.x - 40.0) / world.x, (vs.y - 80.0) / world.y)
	var size := world * s
	_full.position = (vs - size) / 2.0 + Vector2(0, 14)
	_full.size = size
	_full_marks.size = size


func update_map(beacons: Array) -> void:
	_mini_mat.set_shader_parameter("center", hero)
	_mini_mat.set_shader_parameter("fwd", fwd)
	_mini_mat.set_shader_parameter("beacons", beacons)
	_full_mat.set_shader_parameter("beacons", beacons)
	_alpha = move_toward(_alpha, 1.0 if _shown else 0.0, get_process_delta_time() * 4.0)
	_mini.modulate.a = _alpha
	_mini.visible = _alpha > 0.01
	_mini_marks.queue_redraw()
	if _open:
		_full_marks.queue_redraw()


# ── мини-карта: мир → точка на круге ────────────────────────

func _to_mini(p: Vector2) -> Vector2:
	var d := (p - hero) / MINI_RADIUS_M
	var right := Vector2(-fwd.y, fwd.x)
	var l := Vector2(d.dot(right), -d.dot(fwd)) # в долях радиуса
	return Vector2(_size, _size) * 0.5 + l * _size * 0.5


func _draw_mini() -> void:
	var c := Vector2(_size, _size) * 0.5
	for m in markers:
		var p := _to_mini(m.pos)
		var inside := p.distance_to(c) < _size * 0.46
		if m.kind == "target":
			var rp: float = m.r / MINI_RADIUS_M * _size * 0.5
			if p.distance_to(c) + rp * 0.5 < _size * 0.45:
				# примерное место цели рядом — пунктирный круг «где-то здесь»
				_dashed_circle(_mini_marks, p, minf(rp, _size * 0.3), Color(0.55, 0.16, 0.08, 0.85))
			else:
				# цель далеко — указатель на краю карты в её сторону
				var d := (p - c).normalized()
				var tip := c + d * _size * 0.47
				var side := Vector2(-d.y, d.x)
				_mini_marks.draw_colored_polygon(PackedVector2Array([tip, tip - d * 10.0 + side * 6.0, tip - d * 10.0 - side * 6.0]), Color(0.55, 0.16, 0.08, 0.9))
			continue
		if not inside:
			continue
		_mark(_mini_marks, p, m.kind, 1.0)
	_arrow(_mini_marks, c, 1.0)


func _draw_full() -> void:
	var world := Terrain.MAX - Terrain.MIN
	var s := _full.size.x / world.x
	var to := func(p: Vector2) -> Vector2: return (p - Terrain.MIN) * s
	for l in labels:
		if MapData.explored(l.pos):
			var font := UiStyle.font(true)
			var ts := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
			_full_marks.draw_string(font, to.call(l.pos) - Vector2(ts.x / 2.0, 0), l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.3, 0.18, 0.09, 0.9))
	for m in markers:
		if m.kind == "target":
			_dashed_circle(_full_marks, to.call(m.pos), m.r * s, Color(0.55, 0.16, 0.08, 0.85))
		else:
			_mark(_full_marks, to.call(m.pos), m.kind, 1.25)
	# стрелка героя: на большой карте север — вверх
	_arrow(_full_marks, to.call(hero), 1.3, true)
	var font := UiStyle.font(true)
	_full_marks.draw_string(font, Vector2(16, 34), "Карта", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.45, 0.14, 0.07))
	var hint := "коснитесь, чтобы закрыть" if OS.has_feature("mobile") else "M — закрыть"
	_full_marks.draw_string(UiStyle.font(false, true), Vector2(16, _full.size.y - 16), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.35, 0.25, 0.15))


func _mark(ci: Control, p: Vector2, kind: String, k: float) -> void:
	var ink := Color(0.25, 0.16, 0.09)
	match kind:
		"beacon", "beacon_lit":
			if kind == "beacon_lit":
				ci.draw_circle(p + Vector2(0, -9) * k, 9.0 * k, Color(1.0, 0.62, 0.2, 0.35))
				ci.draw_circle(p + Vector2(0, -9) * k, 4.0 * k, Color(1.0, 0.7, 0.3))
			var tower := PackedVector2Array([p + Vector2(-4, 4) * k, p + Vector2(4, 4) * k, p + Vector2(3, -6) * k, p + Vector2(-3, -6) * k])
			ci.draw_colored_polygon(tower, ink)
		"wisp":
			# болотный огонь на карте похож на маяк — только без башни
			ci.draw_circle(p + Vector2(0, -9) * k, 9.0 * k, Color(1.0, 0.62, 0.2, 0.35))
			ci.draw_circle(p + Vector2(0, -9) * k, 4.0 * k, Color(1.0, 0.7, 0.3))
		"npc":
			ci.draw_circle(p, 6.0 * k, Color(1.0, 0.7, 0.3, 0.35))
			ci.draw_circle(p, 3.0 * k, Color(0.85, 0.45, 0.12))


func _arrow(ci: Control, p: Vector2, k: float, north_up := false) -> void:
	# направление взгляда героя на карте
	var dir_world := Vector2(sin(facing), cos(facing))
	var d: Vector2
	if north_up:
		d = dir_world
	else:
		var right := Vector2(-fwd.y, fwd.x)
		d = Vector2(dir_world.dot(right), -dir_world.dot(fwd))
	d = d.normalized()
	var side := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([p + d * 9.0 * k, p - d * 6.0 * k + side * 6.0 * k, p - d * 3.0 * k, p - d * 6.0 * k - side * 6.0 * k])
	ci.draw_colored_polygon(pts, Color(0.62, 0.16, 0.08))
	ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.2, 0.08, 0.04), 1.2, true)


func _dashed_circle(ci: Control, c: Vector2, r: float, col: Color) -> void:
	var n := 24
	for i in n:
		if i % 2 == 1:
			continue
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		ci.draw_line(c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r, col, 2.0, true)


func _input(e: InputEvent) -> void:
	if _open and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_M, KEY_ESCAPE]:
		toggle_full()
		get_viewport().set_input_as_handled()
