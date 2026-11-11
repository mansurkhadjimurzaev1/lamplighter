class_name PauseMenu
extends CanvasLayer
## Меню паузы (Esc): продолжить, начать заново (с подтверждением), выйти.

signal resume
signal new_game
signal quit_game
signal language_changed
signal quality_changed

var _open := false
var _box: VBoxContainer
var _confirm := false
var _new_btn: Button


func build() -> void:
	layer = 18
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.03, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.paper_box())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(420, 0)
	add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	panel.add_child(_box)
	var title := UiStyle.label(Tr.t("Пауза"), 30, UiStyle.INK_RED, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	var b1 := UiStyle.text_button(Tr.t("Продолжить"), 22)
	b1.pressed.connect(close)
	_box.add_child(b1)
	var bs := UiStyle.text_button(Tr.t("Настройки"), 22)
	bs.pressed.connect(func(): _settings.open())
	_box.add_child(bs)
	_new_btn = UiStyle.text_button(Tr.t("Начать заново"), 22)
	_new_btn.pressed.connect(_on_new)
	_box.add_child(_new_btn)
	if not OS.has_feature("mobile"):
		var b3 := UiStyle.text_button(Tr.t("Выйти из игры"), 22)
		b3.pressed.connect(func(): quit_game.emit())
		_box.add_child(b3)
	_settings = SettingsPanel.new()
	_settings.build()
	add_child(_settings)
	_settings.language_changed.connect(func(): language_changed.emit())
	_settings.quality_changed.connect(func(): quality_changed.emit())
	visible = false


var _settings: SettingsPanel


func is_open() -> bool:
	return _open


func open() -> void:
	_open = true
	_confirm = false
	_new_btn.text = "›  " + Tr.t("Начать заново")
	visible = true


func close() -> void:
	_open = false
	visible = false
	resume.emit()


func _on_new() -> void:
	if not _confirm:
		# второй щелчок — подтверждение: весь прогресс сотрётся
		_confirm = true
		_new_btn.text = "›  " + Tr.t("Точно? Весь путь сотрётся — нажми ещё раз")
		return
	new_game.emit()


func _input(e: InputEvent) -> void:
	if _settings.visible:
		return
	if _open and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
