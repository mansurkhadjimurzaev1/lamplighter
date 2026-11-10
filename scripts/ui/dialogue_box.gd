class_name DialogueBox
extends CanvasLayer
## Окно разговора: пергамент внизу экрана, имя, побуквенный текст, варианты ответа.

signal closed

const CHARS_PER_SEC := 38.0

var runner := DialogueRunner.new()
var _panel: PanelContainer
var _name: Label
var _text: Label
var _choices: VBoxContainer
var _hint: Label
var _shown := 0.0
var _open := false
var _alpha := 0.0
var _sound: Callable = func(): pass


func build(on_letter: Callable) -> void:
	layer = 15
	_sound = on_letter
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.paper_box())
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_bottom = -18
	root.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	_name = UiStyle.label("", 24, UiStyle.INK_RED, true)
	v.add_child(_name)
	_text = UiStyle.label("", 22, UiStyle.INK)
	_text.custom_minimum_size = Vector2(0, 60)
	v.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 2)
	v.add_child(_choices)
	_hint = UiStyle.label("", 14, UiStyle.INK_SOFT, false, true)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)
	_panel.gui_input.connect(_on_panel_input)
	visible = false


func is_open() -> bool:
	return _open


func open(npc: String) -> bool:
	if not runner.start(npc):
		return false
	_open = true
	visible = true
	_alpha = 0.0
	_refresh()
	return true


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var w := minf(vs.x - 32.0, 900.0)
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.offset_left = -w / 2.0
	_panel.offset_right = w / 2.0


func _refresh() -> void:
	_layout()
	_name.text = runner.speaker()
	_text.text = runner.current_text()
	_text.visible_characters = 0
	_shown = 0.0
	for c in _choices.get_children():
		c.queue_free()
	_choices.visible = false
	_hint.text = ""


func _show_choices() -> void:
	if not runner.is_last_page() or runner.choices.is_empty():
		var touch := OS.has_feature("mobile")
		_hint.text = "коснитесь, чтобы продолжить" if touch else "пробел / E — дальше"
		return
	_choices.visible = true
	for i in runner.choices.size():
		var b := UiStyle.text_button("%s" % runner.choices[i].text)
		var idx := i
		b.pressed.connect(func(): _pick(idx))
		_choices.add_child(b)
	_hint.text = "" if OS.has_feature("mobile") else "1–%d или мышь" % runner.choices.size()


func _pick(i: int) -> void:
	if runner.choose(i):
		_refresh()
	else:
		close()


func _next() -> void:
	if _text.visible_characters >= 0 and _text.visible_characters < _text.text.length():
		_text.visible_characters = -1 # показать сразу всё
		_shown = 9999.0
		_show_choices()
		return
	if runner.is_last_page() and not runner.choices.is_empty():
		return # ждём выбора
	if runner.advance():
		_refresh()
	else:
		close()


func close() -> void:
	_open = false
	visible = false
	closed.emit()


func _process(dt: float) -> void:
	if not _open:
		return
	_alpha = minf(1.0, _alpha + dt * 4.0)
	_panel.modulate.a = _alpha
	if _text.visible_characters >= 0:
		var before := int(_shown)
		_shown += dt * CHARS_PER_SEC
		var n := int(_shown)
		if n > before and n % 3 == 0:
			_sound.call()
		if n >= _text.text.length():
			_text.visible_characters = -1
			_show_choices()
		else:
			_text.visible_characters = n


func _on_panel_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		_next()


func _input(e: InputEvent) -> void:
	if not _open:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		if k in [KEY_SPACE, KEY_E, KEY_ENTER, KEY_KP_ENTER]:
			_next()
			get_viewport().set_input_as_handled()
		elif k >= KEY_1 and k <= KEY_9 and _choices.visible:
			_pick(k - KEY_1)
			get_viewport().set_input_as_handled()
	elif (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		if not _choices.visible:
			_next()
			get_viewport().set_input_as_handled()
