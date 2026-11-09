class_name TitleScreen
extends CanvasLayer
## Заставка с названием. Любая клавиша / клик / тап — начать.

signal started
signal new_game

var _root := Control.new()
var _hint: Label
var _ready_to_start := false
var _done := false
var _t := 0.0


func build() -> void:
	layer = 10
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.024, 0.06, 0.94)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cormorant Garamond", "Georgia", "Times New Roman", "serif"])
	var italic := SystemFont.new()
	italic.font_names = font.font_names
	italic.font_italic = true

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(box)

	var title := _label("Последний фонарщик", font, 64, Color(0.95, 0.84, 0.65))
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.55, 0.2, 0.18))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 6)
	box.add_child(title)
	box.add_child(_label("Небо закрыла Пелена. Остался один фонарь.", italic, 22, Color(0.95, 0.84, 0.65, 0.7)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	box.add_child(spacer)
	var touch := DisplayServer.is_touchscreen_available() and OS.has_feature("mobile")
	_hint = _label("Коснитесь, чтобы начать" if touch else "Нажмите любую клавишу", font, 20, Color(0.95, 0.84, 0.65, 0.0))
	box.add_child(_hint)

	var ctl := "Тап — идти  ·  долгое касание — поднять фонарь" if touch else "WASD / клик — идти  ·  пробел — поднять фонарь  ·  E — зажечь маяк  ·  F — fps  ·  Esc — выход"
	if SaveGame.has_save() and not touch:
		ctl += "\nN — начать заново"
	var controls := _label(ctl, font, 15, Color(0.95, 0.84, 0.65, 0.45))
	controls.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	controls.position.y -= 40
	controls.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.add_child(controls)


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func set_ready() -> void:
	_ready_to_start = true


func _process(dt: float) -> void:
	_t += dt
	if _ready_to_start and not _done:
		_hint.modulate.a = 1.0
		_hint.add_theme_color_override("font_color", Color(0.95, 0.84, 0.65, 0.35 + 0.55 * (0.5 + 0.5 * sin(_t * 1.8))))
	if _done:
		_root.modulate.a = maxf(0.0, _root.modulate.a - dt / 2.0)
		if _root.modulate.a <= 0.0:
			queue_free()


func _input(e: InputEvent) -> void:
	if not _ready_to_start or _done:
		return
	var pressed: bool = (e is InputEventKey and e.pressed) or (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if e is InputEventKey and e.pressed and e.physical_keycode == KEY_N and SaveGame.has_save():
		_done = true
		new_game.emit()
		get_viewport().set_input_as_handled()
		return
	if pressed:
		start()
		get_viewport().set_input_as_handled()


func start() -> void:
	if _done:
		return
	_done = true
	started.emit()
