class_name SettingsPanel
extends Control
## Настройки: громкость, качество графики, язык. Используется в главном меню и в паузе.

signal closed
signal language_changed
signal quality_changed

var _note: Label


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.paper_box())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(560, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := UiStyle.label(Tr.t("Настройки"), 30, UiStyle.INK_RED, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	# громкость
	v.add_child(UiStyle.label(Tr.t("Громкость"), 22, UiStyle.INK, true))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.volume
	slider.custom_minimum_size = Vector2(0, 28)
	slider.value_changed.connect(func(val):
		Settings.volume = val
		Settings.save_settings())
	v.add_child(slider)

	# качество
	v.add_child(UiStyle.label(Tr.t("Качество графики"), 22, UiStyle.INK, true))
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 6)
	v.add_child(qrow)
	for q in [["", "Авто"], ["low", "Низкое"], ["medium", "Среднее"], ["high", "Высокое"]]:
		var b := _choice(Tr.t(q[1]), Settings.quality == q[0])
		var val: String = q[0]
		b.pressed.connect(func():
			Settings.quality = val
			Settings.save_settings()
			_refresh_group(qrow, b)
			_note.visible = true
			quality_changed.emit())
		qrow.add_child(b)
	_note = UiStyle.label(Tr.t("Трава и дальность обновятся после перезапуска."), 16, UiStyle.INK_SOFT, false, true)
	_note.visible = false
	v.add_child(_note)

	# язык
	v.add_child(UiStyle.label(Tr.t("Язык"), 22, UiStyle.INK, true))
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 6)
	v.add_child(lrow)
	for l in [["ru", "Русский"], ["en", "English"]]:
		var b := _choice(l[1], Settings.lang == l[0])
		var val: String = l[0]
		b.pressed.connect(func():
			if Settings.lang == val:
				return
			Settings.lang = val
			Settings.save_settings()
			language_changed.emit())
		lrow.add_child(b)

	var back := UiStyle.text_button(Tr.t("Назад"), 22)
	back.pressed.connect(func():
		visible = false
		closed.emit())
	v.add_child(back)
	visible = false


func _choice(text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UiStyle.font(true))
	b.add_theme_font_size_override("font_size", 19)
	b.custom_minimum_size = Vector2(118, 40)
	return b


func _refresh_group(row: HBoxContainer, active: Button) -> void:
	for c in row.get_children():
		(c as Button).button_pressed = c == active


func open() -> void:
	visible = true


func _input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE:
		visible = false
		closed.emit()
		get_viewport().set_input_as_handled()
